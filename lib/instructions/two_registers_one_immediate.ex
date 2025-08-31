defmodule PVM.Instructions.TwoRegistersOneImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils, Math}
  alias PVM.{Registers, Utils}
  import PVM.Memory.Util
  # Section (A.5.10) v0.7.0

  @two_32 0x1_0000_0000
  @two_64 0x1_0000_0000_0000_0000

  # Store instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:store_ind_u8, :store_ind_u16, :store_ind_u32, :store_ind_u64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    {size, bits} =
      case instruction do
        :store_ind_u8 -> {1, 8}
        :store_ind_u16 -> {2, 16}
        :store_ind_u32 -> {4, 32}
        :store_ind_u64 -> {8, 64}
      end

    value = if instruction == :store_ind_u64, do: w_a, else: mod(w_a, 1 <<< bits)

    write_memory(state, w_b + v_x, <<value::size*8-little>>)
  end

  # Unsigned load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_u8, :load_ind_u16, :load_ind_u32, :load_ind_u64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    size =
      case instruction do
        :load_ind_u8 -> 1
        :load_ind_u16 -> 2
        :load_ind_u32 -> 4
        :load_ind_u64 -> 8
      end

    read_memory(state, addr, size, fn bytes ->
      %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, de_le(bytes, size))}}
    end)
  end

  # Signed load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_i8, :load_ind_i16, :load_ind_i32] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    size =
      case instruction do
        :load_ind_i8 -> 1
        :load_ind_i16 -> 2
        :load_ind_i32 -> 4
      end

    read_memory(
      state,
      addr,
      size,
      fn bytes ->
        unsigned_8bit =
          bytes
          |> de_le(size)
          |> u2i(size)
          |> i2u(8)

        %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, unsigned_8bit)}}
      end
    )
  end

  # Arithmetic operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:add_imm_32, :mul_imm_32, :neg_add_imm_32] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :add_imm_32 -> mod(w_b + v_x, @two_32)
        :mul_imm_32 -> mod(w_b * v_x, @two_32)
        :neg_add_imm_32 -> Integer.mod(v_x + @two_32 - w_b, @two_32)
      end
      |> to_64bit(4)

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # Bitwise operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:and_imm, :xor_imm, :or_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :and_imm -> w_b &&& v_x
        :xor_imm -> bxor(w_b, v_x)
        :or_imm -> w_b ||| v_x
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # Comparison operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:set_lt_u_imm, :set_lt_s_imm, :set_gt_u_imm, :set_gt_s_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :set_lt_u_imm -> if w_b < v_x, do: 1, else: 0
        :set_lt_s_imm -> if u2i(w_b, 8) < u2i(v_x, 8), do: 1, else: 0
        :set_gt_u_imm -> if w_b > v_x, do: 1, else: 0
        :set_gt_s_imm -> if u2i(w_b, 8) > u2i(v_x, 8), do: 1, else: 0
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
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
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :shlo_l_imm_32 ->
          shift = mod(v_x, 32)
          mod(w_b * (1 <<< shift), @two_32) |> to_64bit(4)

        :shlo_r_imm_32 ->
          shift = mod(v_x, 32)
          mod(w_b, @two_32) >>> shift |> to_64bit(4)

        :shar_r_imm_32 ->
          shift = mod(v_x, 32)
          u2i(mod(w_b, @two_32), 4) |> Bitwise.bsr(shift) |> i2u(8)

        :shlo_l_imm_alt_32 ->
          shift = mod(w_b, 32)
          mod(v_x * (1 <<< shift), @two_32) |> to_64bit(4)

        :shlo_r_imm_alt_32 ->
          shift = mod(w_b, 32)
          mod(v_x, @two_32) >>> shift |> to_64bit(4)

        :shar_r_imm_alt_32 ->
          shift = mod(w_b, 32)
          u2i(mod(v_x, @two_32), 4) |> Bitwise.bsr(shift) |> i2u(8)
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # Conditional move operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:cmov_iz_imm, :cmov_nz_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    result =
      case instruction do
        :cmov_iz_imm -> if w_b == 0, do: v_x, else: w_a
        :cmov_nz_imm -> if w_b != 0, do: v_x, else: w_a
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # 64-bit arithmetic operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:add_imm_64, :mul_imm_64, :neg_add_imm_64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :add_imm_64 -> mod(w_b + v_x, @two_64)
        :mul_imm_64 -> mod(w_b * v_x, @two_64)
        :neg_add_imm_64 -> mod(v_x + @two_64 - w_b, @two_64)
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
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
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result =
      case instruction do
        :shlo_l_imm_64 ->
          shift = mod(v_x, 64)
          mod(w_b * (1 <<< shift), @two_64)

        :shlo_r_imm_64 ->
          shift = mod(v_x, 64)
          w_b >>> shift

        :shar_r_imm_64 ->
          shift = mod(v_x, 64)
          u2i(w_b, 8) >>> shift |> i2u(8)

        :shlo_l_imm_alt_64 ->
          shift = mod(w_b, 64)
          mod(v_x * (1 <<< shift), @two_64)

        :shlo_r_imm_alt_64 ->
          shift = mod(w_b, 64)
          v_x >>> shift

        :shar_r_imm_alt_64 ->
          shift = mod(w_b, 64)
          u2i(v_x, 8) >>> shift |> i2u(8)
      end

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # Rotation operations
  def execute(:rot_r_64_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    number = state.registers[r_b]

    shift = mod(v_x, 64)
    result = rotate(number, shift, 64, :right)

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  def execute(:rot_r_64_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 64)
    result = rotate(v_x, shift, 64, :right)

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  def execute(:rot_r_32_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 32)
    result = rotate(w_b, shift, 32, :right) |> Utils.extend_to_64bit(4)

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  def execute(:rot_r_32_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 32)
    result = rotate(v_x, shift, 32, :right) |> Utils.extend_to_64bit(4)

    state = %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, result)}}
    {:continue, state}
  end

  # Formula (A.28) v0.7.0
  defp get_params(program, bitmask, counter) do
    byte1 = binary_part_safe(program, counter + 1, 1)
    r_a = min(12, mod(:binary.first(byte1), 16))
    r_b = min(12, :binary.first(byte1) >>> 4)

    l_x = min(4, max(0, skip(counter, bitmask) - 1))

    v_x = decode_and_extend(program, counter + 2, l_x)

    {r_a, r_b, v_x}
  end
end
