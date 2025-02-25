defmodule PVM.Instructions.TwoRegistersOneImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils, Transitions}
  alias PVM.{Registers, Utils, Trace}
  import PVM.Memory.Util
  # Section (A.5.10) v0.6.1

  # Add this helper function at the top of the module
  defp format_bytes(bytes) do
    bytes_list = :binary.bin_to_list(bytes)
    "<<#{Enum.join(bytes_list, ", ")}>>"
  end

  # Store instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:store_ind_u8, :store_ind_u16, :store_ind_u32, :store_ind_u64] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    w_b = Registers.get(state.registers, r_b)

    {size, bits} =
      case instruction do
        :store_ind_u8 -> {1, 8}
        :store_ind_u16 -> {2, 16}
        :store_ind_u32 -> {4, 32}
        :store_ind_u64 -> {8, 64}
      end

    value = if instruction == :store_ind_u64, do: w_a, else: rem(w_a, 1 <<< bits)
    addr = w_b + v_x
    bytes = e_le(value, size)
    bytes_string = format_bytes(bytes)

    Trace.instruction(state.counter, "#{instruction}",
      "bytes=#{bytes_string}\nstore w#{r_a}(#{value}) to [w#{r_b}(#{w_b}) + #{v_x}] = #{addr}")
    write_memory(state, addr, bytes)
  end

  # Unsigned load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_u8, :load_ind_u16, :load_ind_u32, :load_ind_u64] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    addr = w_b + v_x

    size =
      case instruction do
        :load_ind_u8 -> 1
        :load_ind_u16 -> 2
        :load_ind_u32 -> 4
        :load_ind_u64 -> 8
      end

    Trace.instruction(state.counter, "#{instruction}",
      "bytes=#{format_bytes(raw_bytes)}\nload into w#{r_a} from [w#{r_b}(#{w_b}) + #{v_x}] = #{addr}")

    read_memory(state, addr, size, fn bytes ->
      Trace.instruction(state.counter, "memory_read",
        "address=#{addr}, contents=[#{format_bytes(bytes)}]")
      %{state | registers: Registers.set(state.registers, r_a, de_le(bytes, size))}
    end)
  end

  # Signed load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_i8, :load_ind_i16, :load_ind_i32] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    addr = w_b + v_x

    size =
      case instruction do
        :load_ind_i8 -> 1
        :load_ind_i16 -> 2
        :load_ind_i32 -> 4
      end

    Trace.instruction(state.counter, "#{instruction}",
      "bytes=#{format_bytes(raw_bytes)}\nload signed into w#{r_a} from [w#{r_b}(#{w_b}) + #{v_x}] = #{addr}")

    read_memory(
      state,
      addr,
      size,
      fn bytes ->
        Trace.instruction(state.counter, "memory_read",
          "address=#{addr}, contents=[#{format_bytes(bytes)}]")
        unsigned_8bit =
          bytes
          |> de_le(size)
          |> u2i(size)
          |> i2u(8)

        %{state | registers: Registers.set(state.registers, r_a, unsigned_8bit)}
      end
    )
  end

  # Arithmetic operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:add_imm_32, :mul_imm_32, :neg_add_imm_32] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    op_symbol = case instruction do
      :add_imm_32 -> "+"
      :mul_imm_32 -> "*"
      :neg_add_imm_32 -> "-"
    end

    result =
      case instruction do
        :add_imm_32 -> rem(w_b + v_x, 1 <<< 32)
        :mul_imm_32 -> rem(w_b * v_x, 1 <<< 32)
        :neg_add_imm_32 -> rem(v_x + (1 <<< 32) - w_b, 1 <<< 32)
      end
      |> to_64bit(4)

    expr = if instruction == :neg_add_imm_32, do: "#{v_x} - w#{r_b}(#{w_b})", else: "w#{r_b}(#{w_b}) #{op_symbol} #{v_x}"
    bytes_list = :binary.bin_to_list(raw_bytes)
    bytes_string = format_bytes(raw_bytes)

    Trace.instruction(state.counter, "#{instruction}",
      "bytes=#{bytes_string}\n#{expr} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Bitwise operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:and_imm, :xor_imm, :or_imm] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    op_symbol = case instruction do
      :and_imm -> "&"
      :xor_imm -> "^"
      :or_imm -> "|"
    end

    operation =
      case instruction do
        :and_imm -> &(&1 &&& &2)
        :xor_imm -> &bxor(&1, &2)
        :or_imm -> &bor(&1, &2)
      end

    result = b2u(Enum.zip_with(u2b(w_b, 8), u2b(v_x, 8), operation))
    Trace.instruction(state.counter, "#{instruction}", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = w#{r_b}(#{w_b}) #{op_symbol} #{v_x} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Comparison operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:set_lt_u_imm, :set_lt_s_imm, :set_gt_u_imm, :set_gt_s_imm] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    op_symbol = case instruction do
      :set_lt_u_imm -> "<"
      :set_lt_s_imm -> "<s"
      :set_gt_u_imm -> ">"
      :set_gt_s_imm -> ">s"
    end

    result =
      case instruction do
        :set_lt_u_imm -> if w_b < v_x, do: 1, else: 0
        :set_lt_s_imm -> if u2i(w_b, 8) < u2i(v_x, 8), do: 1, else: 0
        :set_gt_u_imm -> if w_b > v_x, do: 1, else: 0
        :set_gt_s_imm -> if u2i(w_b, 8) > u2i(v_x, 8), do: 1, else: 0
      end

    Trace.instruction(state.counter, "#{instruction}", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = w#{r_b}(#{w_b}) #{op_symbol} #{v_x} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Shift operations
  def execute(instruction, program, bitmask, state)
      when instruction in [
             :shlo_l_imm_32,
             :shlo_r_imm_32,
             :shar_r_imm_32,
             :shlo_l_imm_alt_32,
             :shlo_r_imm_alt_32,
             :shar_r_imm_alt_32
           ] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    {shift_val, shift_amt, op_symbol} = case instruction do
      :shlo_l_imm_32 -> {w_b, v_x, "<<"}
      :shlo_r_imm_32 -> {w_b, v_x, ">>"}
      :shar_r_imm_32 -> {w_b, v_x, ">>s"}
      :shlo_l_imm_alt_32 -> {v_x, w_b, "<<"}
      :shlo_r_imm_alt_32 -> {v_x, w_b, ">>"}
      :shar_r_imm_alt_32 -> {v_x, w_b, ">>s"}
    end

    result =
      case instruction do
        :shlo_l_imm_32 ->
          shift = rem(v_x, 32)
          rem(w_b * (1 <<< shift), 1 <<< 32) |> to_64bit(4)

        :shlo_r_imm_32 ->
          shift = rem(v_x, 32)
          div(rem(w_b, 1 <<< 32), 1 <<< shift) |> to_64bit(4)

        :shar_r_imm_32 ->
          shift = rem(v_x, 32)
          u2i(rem(w_b, 1 <<< 32), 4) |> div(1 <<< shift) |> i2u(8)

        :shlo_l_imm_alt_32 ->
          shift = rem(w_b, 32)
          rem(v_x * (1 <<< shift), 1 <<< 32) |> to_64bit(4)

        :shlo_r_imm_alt_32 ->
          shift = rem(w_b, 32)
          div(v_x, 1 <<< shift) |> to_64bit(4)

        :shar_r_imm_alt_32 ->
          shift = rem(w_b, 32)
          div(u2i(rem(v_x, 1 <<< 32), 4), 1 <<< shift) |> i2u(8)
      end

    shift = rem(shift_amt, 32)
    Trace.instruction(state.counter, "#{instruction}", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = #{shift_val} #{op_symbol} #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Conditional move operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:cmov_iz_imm, :cmov_nz_imm] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    w_a = Registers.get(state.registers, r_a)

    cond_desc = case instruction do
      :cmov_iz_imm -> "w#{r_b}(#{w_b}) == 0"
      :cmov_nz_imm -> "w#{r_b}(#{w_b}) != 0"
    end

    result =
      case instruction do
        :cmov_iz_imm -> if w_b == 0, do: v_x, else: w_a
        :cmov_nz_imm -> if w_b != 0, do: v_x, else: w_a
      end

    Trace.instruction(state.counter, "#{instruction}", "bytes=#{format_bytes(raw_bytes)}\n#{cond_desc} ? #{v_x} : #{w_a} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # 64-bit arithmetic operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:add_imm_64, :mul_imm_64, :neg_add_imm_64] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    op_symbol = case instruction do
      :add_imm_64 -> "+"
      :mul_imm_64 -> "*"
      :neg_add_imm_64 -> "-"
    end

    result =
      case instruction do
        :add_imm_64 -> rem(w_b + v_x, 1 <<< 64)
        :mul_imm_64 -> rem(w_b * v_x, 1 <<< 64)
        :neg_add_imm_64 -> rem(v_x + (1 <<< 64) - w_b, 1 <<< 64)
      end

    expr = if instruction == :neg_add_imm_64, do: "#{v_x} - w#{r_b}(#{w_b})", else: "w#{r_b}(#{w_b}) #{op_symbol} #{v_x}"
    bytes_list = :binary.bin_to_list(raw_bytes)
    bytes_string = format_bytes(raw_bytes)

    Trace.instruction(state.counter, "#{instruction}",
      "bytes=#{bytes_string}\n#{expr} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # 64-bit shift operations
  def execute(instruction, program, bitmask, state)
      when instruction in [
             :shlo_l_imm_64,
             :shlo_r_imm_64,
             :shar_r_imm_64,
             :shlo_l_imm_alt_64,
             :shlo_r_imm_alt_64,
             :shar_r_imm_alt_64
           ] do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    {shift_val, shift_amt, op_symbol} = case instruction do
      :shlo_l_imm_64 -> {w_b, v_x, "<<"}
      :shlo_r_imm_64 -> {w_b, v_x, ">>"}
      :shar_r_imm_64 -> {w_b, v_x, ">>s"}
      :shlo_l_imm_alt_64 -> {v_x, w_b, "<<"}
      :shlo_r_imm_alt_64 -> {v_x, w_b, ">>"}
      :shar_r_imm_alt_64 -> {v_x, w_b, ">>s"}
    end

    result =
      case instruction do
        :shlo_l_imm_64 ->
          shift = rem(v_x, 64)
          rem(w_b * (1 <<< shift), 1 <<< 64)

        :shlo_r_imm_64 ->
          shift = rem(v_x, 64)
          div(w_b, 1 <<< shift)

        :shar_r_imm_64 ->
          shift = rem(v_x, 64)
          div(u2i(w_b, 8), 1 <<< shift) |> i2u(8)

        :shlo_l_imm_alt_64 ->
          shift = rem(w_b, 64)
          rem(v_x * (1 <<< shift), 1 <<< 64)

        :shlo_r_imm_alt_64 ->
          shift = rem(w_b, 64)
          div(v_x, 1 <<< shift)

        :shar_r_imm_alt_64 ->
          shift = rem(w_b, 64)
          div(u2i(v_x, 8), 1 <<< shift) |> i2u(8)
      end

    shift = rem(shift_amt, 64)
    Trace.instruction(state.counter, "#{instruction}", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = #{shift_val} #{op_symbol} #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Rotation operations
  def execute(:rot_r_64_imm, program, bitmask, state) do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    number = Registers.get(state.registers, r_b)
    shift = rem(v_x, 64)
    result = rotate(number, shift, 64, :right)

    Trace.instruction(state.counter, "rot_r_64_imm", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = w#{r_b}(#{number}) ror #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_64_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    shift = rem(w_b, 64)
    result = rotate(v_x, shift, 64, :right)

    Trace.instruction(state.counter, "rot_r_64_imm_alt", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = #{v_x} ror #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_32_imm, program, bitmask, state) do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    shift = rem(v_x, 32)
    result = rotate(w_b, shift, 32, :right) |> Utils.extend_to_64bit(4)

    Trace.instruction(state.counter, "rot_r_32_imm", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = w#{r_b}(#{w_b}) ror #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_32_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x, raw_bytes} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    shift = rem(w_b, 32)
    result = rotate(v_x, shift, 32, :right) |> Utils.extend_to_64bit(4)

    Trace.instruction(state.counter, "rot_r_32_imm_alt", "bytes=#{format_bytes(raw_bytes)}\nw#{r_a} = #{v_x} ror #{shift} = #{result}")
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Formula (A.27) v0.6.1
  defp get_params(program, bitmask, counter) do

    byte1 = binary_part_safe(program, counter + 1, 1)
    r_a = min(12, rem(:binary.first(byte1), 16))
    r_b = min(12, div(:binary.first(byte1), 16))

    l_x = min(4, max(0, skip(counter, bitmask) - 1))
    imm_bytes = binary_part_safe(program, counter + 2, l_x)
    raw_bytes = byte1 <> imm_bytes

    v_x = decode_and_extend(program, counter + 2, l_x)

    {r_a, r_b, v_x, raw_bytes}
  end
end
