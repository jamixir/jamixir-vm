defmodule PVM.Instructions.TwoRegistersOneImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils, Transitions}
  alias PVM.{Registers, Utils}
  import PVM.Memory.Util
  # Section (A.5.10) v0.6.1

  # Store instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:store_ind_u8, :store_ind_u16, :store_ind_u32, :store_ind_u64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
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
    write_memory(state, w_b + v_x, e_le(value, size))
  end

  # Unsigned load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_u8, :load_ind_u16, :load_ind_u32, :load_ind_u64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    size =
      case instruction do
        :load_ind_u8 -> 1
        :load_ind_u16 -> 2
        :load_ind_u32 -> 4
        :load_ind_u64 -> 8
      end

    read_memory(state, w_b + v_x, size, &%{state | registers: Registers.set(state.registers, r_a, de_le(&1, size))})
  end

  # Signed load instructions
  def execute(instruction, program, bitmask, state)
      when instruction in [:load_ind_i8, :load_ind_i16, :load_ind_i32] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    size =
      case instruction do
        :load_ind_i8 -> 1
        :load_ind_i16 -> 2
        :load_ind_i32 -> 4
      end

    read_memory(
      state,
      w_b + v_x,
      size,
      fn v ->
        unsigned_8bit =
          v
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
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    result =
      case instruction do
        :add_imm_32 -> rem(w_b + v_x, 1 <<< 32)
        :mul_imm_32 -> rem(w_b * v_x, 1 <<< 32)
        :neg_add_imm_32 -> rem(v_x + (1 <<< 32) - w_b, 1 <<< 32)
      end
      |> to_64bit(4)

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Bitwise operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:and_imm, :xor_imm, :or_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    operation =
      case instruction do
        :and_imm -> &(&1 &&& &2)
        :xor_imm -> &bxor(&1, &2)
        :or_imm -> &bor(&1, &2)
      end

    result = b2u(Enum.zip_with(u2b(w_b, 8), u2b(v_x, 8), operation))
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Comparison operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:set_lt_u_imm, :set_lt_s_imm, :set_gt_u_imm, :set_gt_s_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    result =
      case instruction do
        :set_lt_u_imm -> if w_b < v_x, do: 1, else: 0
        :set_lt_s_imm -> if u2i(w_b, 8) < u2i(v_x, 8), do: 1, else: 0
        :set_gt_u_imm -> if w_b > v_x, do: 1, else: 0
        :set_gt_s_imm -> if u2i(w_b, 8) > u2i(v_x, 8), do: 1, else: 0
      end

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
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

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

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Conditional move operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:cmov_iz_imm, :cmov_nz_imm] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    w_a = Registers.get(state.registers, r_a)

    result =
      case instruction do
        :cmov_iz_imm -> if w_b == 0, do: v_x, else: w_a
        :cmov_nz_imm -> if w_b != 0, do: v_x, else: w_a
      end

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # 64-bit arithmetic operations
  def execute(instruction, program, bitmask, state)
      when instruction in [:add_imm_64, :mul_imm_64, :neg_add_imm_64] do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    result =
      case instruction do
        :add_imm_64 -> rem(w_b + v_x, 1 <<< 64)
        :mul_imm_64 -> rem(w_b * v_x, 1 <<< 64)
        :neg_add_imm_64 -> rem(v_x + (1 <<< 64) - w_b, 1 <<< 64)
      end

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
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

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

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Rotation operations
  def execute(:rot_r_64_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    number = Registers.get(state.registers, r_b)
    shift = rem(v_x, 64)
    result = rotate(number, shift, 64, :right)

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_64_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    result = rotate(v_x, w_b, 64, :right)
    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_32_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    result = rotate(w_b, v_x, 32, :right) |> Utils.extend_to_64bit(4)

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  def execute(:rot_r_32_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)
    result = rotate(v_x, w_b, 32, :right) |> Utils.extend_to_64bit(4)

    state = %{state | registers: Registers.set(state.registers, r_a, result)}
    {:continue, state}
  end

  # Formula (A.27) v0.6.1
  defp get_params(program, bitmask, counter) do
    r_a =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> rem(16)
      |> min(12)

    r_b =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> min(12)

    l_x = min(4, max(0, skip(counter, bitmask) - 1))
    v_x = decode_and_extend(program, counter + 2, l_x)

    {r_a, r_b, v_x}
  end
end
