defmodule PVM.Instructions.ThreeRegisters do
  use PVM.Utils
  use PVM.Math
  alias PVM.{Registers, Trace}
  import Bitwise
  @two_32 0x1_0000_0000
  @two_64 0x1_0000_0000_0000_0000
  @max_64 0xFFFF_FFFF_FFFF_FFFF

  # Helper to format trace message
  defp trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes) do
    op_symbol =
      case instruction do
        :add_32 -> "+"
        :add_64 -> "+"
        :sub_32 -> "-"
        :sub_64 -> "-"
        :mul_32 -> "*"
        :mul_64 -> "*"
        :div_u_32 -> "/"
        :div_u_64 -> "/"
        :div_s_32 -> "/s"
        :div_s_64 -> "/s"
        :rem_u_32 -> "%"
        :rem_u_64 -> "%"
        :rem_s_32 -> "%s"
        :rem_s_64 -> "%s"
        :shlo_l_32 -> "<<"
        :shlo_l_64 -> "<<"
        :shlo_r_32 -> ">>"
        :shlo_r_64 -> ">>"
        :shar_r_32 -> ">>s"
        :shar_r_64 -> ">>s"
        :and -> "&"
        :or -> "|"
        :xor -> "^"
        :and_inv -> "&~"
        :or_inv -> "|~"
        :xnor -> "XNOR"
        :set_lt_u -> "<"
        :set_lt_s -> "<s"
        _ -> "#{instruction}"
      end

    bytes_list = :binary.bin_to_list(raw_bytes)
    bytes_string = "<<#{Enum.join(bytes_list, ", ")}>>"

    Trace.instruction(
      state.counter,
      "#{instruction}",
      "bytes=#{bytes_string}\nw#{r_d} = w#{r_a}(#{w_a}) #{op_symbol} w#{r_b}(#{w_b}) = #{result}"
    )
  end

  # Section A.5.12 v0.6.1

  # 32-bit arithmetic operations
  def execute(instruction, program, state)
      when instruction in [:add_32, :sub_32, :mul_32] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :add_32 -> w_a + w_b
        :sub_32 -> w_a + @two_32 - mod(w_b, @two_32)
        :mul_32 -> w_a * w_b
      end
      |> mod(@two_32)
      |> to_64bit(4)

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # 32-bit division operations
  def execute(instruction, program, state)
      when instruction in [:div_u_32, :div_s_32, :rem_u_32, :rem_s_32] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :div_u_32 ->
          if mod(w_b, @two_32) == 0,
            do: @max_64,
            else: div(mod(w_a, @two_32), mod(w_b, @two_32)) |> to_64bit(4)

        :div_s_32 ->
          a = u2i(mod(w_a, @two_32), 4)
          b = u2i(mod(w_b, @two_32), 4)

          cond do
            b == 0 -> @max_64
            b == -1 and a == -1 * (1 <<< 31) -> i2u(a, 8)
            true -> i2u(div(a, b), 8)
          end

        :rem_u_32 ->
          if mod(w_b, @two_32) == 0,
            do: mod(w_a, @two_32) |> to_64bit(4),
            else: mod(mod(w_a, @two_32), mod(w_b, @two_32)) |> to_64bit(4)

        :rem_s_32 ->
          a = u2i(mod(w_a, @two_32), 4)
          b = u2i(mod(w_b, @two_32), 4)

          if b == -1 and a == -1 * (1 <<< 31), do: 0, else: i2u(srem(a, b), 8)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # 32-bit shift operations
  def execute(instruction, program, state)
      when instruction in [:shlo_l_32, :shlo_r_32, :shar_r_32] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)
    shift = mod(w_b, 32)

    result =
      case instruction do
        :shlo_l_32 -> mod(w_a * (1 <<< shift), @two_32) |> to_64bit(4)
        :shlo_r_32 -> mod(w_a, @two_32) >>> shift |> to_64bit(4)
        :shar_r_32 -> mod(w_a, @two_32) |> u2i(4) |> Bitwise.bsr(shift) |> i2u(8)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # 64-bit arithmetic operations
  def execute(instruction, program, state)
      when instruction in [:add_64, :sub_64, :mul_64] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :add_64 -> w_a + w_b
        :sub_64 -> w_a - w_b + @two_64
        :mul_64 -> w_a * w_b
      end
      |> mod(@two_64)

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # 64-bit division operations
  def execute(instruction, program, state)
      when instruction in [:div_u_64, :div_s_64, :rem_u_64, :rem_s_64] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :div_u_64 ->
          if mod(w_b, @two_64) == 0,
            do: @max_64,
            else: div(w_a, w_b)

        :div_s_64 ->
          cond do
            w_b == 0 -> @max_64
            u2i(w_b, 8) == -1 and u2i(w_a, 8) == -1 * (1 <<< 63) -> w_a
            true -> i2u(div(u2i(w_a, 8), u2i(w_b, 8)), 8)
          end

        :rem_u_64 ->
          if w_b == 0, do: w_a, else: mod(w_a, w_b)

        :rem_s_64 ->
          if u2i(w_b, 8) == -1 and u2i(w_a, 8) == -1 * (1 <<< 63),
            do: 0,
            else: srem(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # 64-bit shift operations
  def execute(instruction, program, state)
      when instruction in [:shlo_l_64, :shlo_r_64, :shar_r_64] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)
    shift = mod(w_b, 64)

    result =
      case instruction do
        :shlo_l_64 -> mod(w_a * (1 <<< shift), @two_64)
        :shlo_r_64 -> w_a >>> shift
        :shar_r_64 -> u2i(w_a, 8) >>> shift |> i2u(8)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Bitwise operations
  def execute(instruction, program, state)
      when instruction in [:and, :xor, :or] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    operation =
      case instruction do
        :and -> &(&1 &&& &2)
        :xor -> &bxor(&1, &2)
        :or -> &bor(&1, &2)
      end

    result = b2u(Enum.zip_with(u2b(w_a, 8), u2b(w_b, 8), operation))

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Bitwise operations with inversion
  def execute(instruction, program, state)
      when instruction in [:and_inv, :or_inv, :xnor] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    operation =
      case instruction do
        :and_inv -> fn x, y -> x &&& 1 - y end
        :or_inv -> fn x, y -> x ||| 1 - y end
        # NOT XOR = 1 - (x XOR y)
        :xnor -> fn x, y -> 1 - bxor(x, y) end
      end

    result = b2u(Enum.zip_with(u2b(w_a, 8), u2b(w_b, 8), operation))

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Upper multiplication operations
  def execute(instruction, program, state)
      when instruction in [:mul_upper_s_s, :mul_upper_u_u, :mul_upper_s_u] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :mul_upper_s_s ->
          (u2i(w_a, 8) * u2i(w_b, 8)) |> Bitwise.bsr(64) |> i2u(8)

        :mul_upper_u_u ->
          (w_a * w_b) >>> 64

        :mul_upper_s_u ->
          (u2i(w_a, 8) * w_b) |> Bitwise.bsr(64) |> i2u(8)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Comparison operations
  def execute(instruction, program, state)
      when instruction in [:set_lt_u, :set_lt_s] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        :set_lt_u -> if(w_a < w_b, do: 1, else: 0)
        :set_lt_s -> if(u2i(w_a, 8) < u2i(w_b, 8), do: 1, else: 0)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Conditional move operations
  def execute(instruction, program, state)
      when instruction in [:cmov_iz, :cmov_nz] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)
    w_d = Registers.get(state.registers, r_d)

    result =
      case instruction do
        :cmov_iz -> if(w_b == 0, do: w_a, else: w_d)
        :cmov_nz -> if(w_b != 0, do: w_a, else: w_d)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Rotation operations
  def execute(instruction, program, state)
      when instruction in [:rot_l_64, :rot_l_32, :rot_r_64, :rot_r_32] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    {bits, direction} =
      case instruction do
        :rot_l_64 -> {64, :left}
        :rot_l_32 -> {32, :left}
        :rot_r_64 -> {64, :right}
        :rot_r_32 -> {32, :right}
      end

    result = rotate(w_a, w_b, bits, direction)
    result = if bits == 32, do: to_64bit(result, 4), else: result

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Min/Max operations
  def execute(instruction, program, state)
      when instruction in [:max, :max_u, :min, :min_u] do
    {w_a, w_b, r_d, r_a, r_b, raw_bytes} = get_params(program, state)

    result =
      case instruction do
        # signed max
        :max -> max(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)
        # unsigned max
        :max_u -> max(w_a, w_b)
        # signed min
        :min -> min(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)
        # unsigned min
        :min_u -> min(w_a, w_b)
      end

    trace_op(state, instruction, r_a, w_a, r_b, w_b, r_d, result, raw_bytes)
    state = %{state | registers: Registers.set(state.registers, r_d, result)}
    {:continue, state}
  end

  # Formula (A.30) v0.6.1
  defp get_params(program, state) do
    byte1 = binary_part_safe(program, state.counter + 1, 1)
    byte2 = binary_part_safe(program, state.counter + 2, 1)
    raw_bytes = byte1 <> byte2

    r_a = min(12, mod(:binary.first(byte1), 16))
    r_b = min(12, :binary.first(byte1) >>> 4)
    r_d = min(12, :binary.first(byte2))

    w_a = Registers.get(state.registers, r_a)
    w_b = Registers.get(state.registers, r_b)

    {w_a, w_b, r_d, r_a, r_b, raw_bytes}
  end
end
