defmodule Instructions.ThreeRegisters do
  use PVM.Utils
  use Transitions
  import Bitwise
  alias Instructions.Common

  # 32-bit arithmetic operations
  def execute(instruction, state, output)
      when instruction in [:add_32, :sub_32, :mul_32] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :add_32 -> w_a + w_b
        :sub_32 -> w_a + (1 <<< 32) - rem(w_b, 1 <<< 32)
        :mul_32 -> w_a * w_b
      end
      |> rem(1 <<< 32)
      |> to_64bit(4)

    Common.update_register(output, state.registers, r_d, result)
  end

  # 32-bit division operations
  def execute(instruction, state, output)
      when instruction in [:div_u_32, :div_s_32, :rem_u_32, :rem_s_32] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :div_u_32 -> div(rem(w_a, 1 <<< 32), rem(w_b, 1 <<< 32))
        :div_s_32 -> div(u2i(w_a, 4), u2i(w_b, 4))
        :rem_u_32 -> rem(rem(w_a, 1 <<< 32), rem(w_b, 1 <<< 32))
        :rem_s_32 -> rem(u2i(w_a, 4), u2i(w_b, 4))
      end
      |> to_64bit(4)

    Common.update_register(output, state.registers, r_d, result)
  end

  # 32-bit shift operations
  def execute(instruction, state, output)
      when instruction in [:shlo_l_32, :shlo_r_32, :shar_r_32] do
    {w_a, w_b, r_d} = get_params(state)
    shift = rem(w_b, 32)

    result =
      case instruction do
        :shlo_l_32 -> rem(w_a * (1 <<< shift), 1 <<< 32)
        :shlo_r_32 -> div(rem(w_a, 1 <<< 32), 1 <<< shift)
        :shar_r_32 -> div(u2i(w_a, 4), 1 <<< shift)
      end
      |> to_64bit(4)

    Common.update_register(output, state.registers, r_d, result)
  end

  # 64-bit arithmetic operations
  def execute(instruction, state, output)
      when instruction in [:add_64, :sub_64, :mul_64] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :add_64 -> w_a + w_b
        :sub_64 -> w_a - w_b + (1 <<< 64)
        :mul_64 -> w_a * w_b
      end
      |> rem(1 <<< 64)

    Common.update_register(output, state.registers, r_d, result)
  end

  # 64-bit division operations
  def execute(instruction, state, output)
      when instruction in [:div_u_64, :div_s_64, :rem_u_64, :rem_s_64] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :div_u_64 -> div(w_a, w_b)
        :div_s_64 -> div(u2i(w_a, 8), u2i(w_b, 8))
        :rem_u_64 -> rem(w_a, w_b)
        :rem_s_64 -> rem(u2i(w_a, 8), u2i(w_b, 8))
      end
      |> i2u(8)

    Common.update_register(output, state.registers, r_d, result)
  end

  # 64-bit shift operations
  def execute(instruction, state, output)
      when instruction in [:shlo_l_64, :shlo_r_64, :shar_r_64] do
    {w_a, w_b, r_d} = get_params(state)
    shift = rem(w_b, 64)

    result =
      case instruction do
        :shlo_l_64 -> rem(w_a * (1 <<< shift), 1 <<< 64)
        :shlo_r_64 -> div(w_a, 1 <<< shift)
        :shar_r_64 -> div(u2i(w_a, 8), 1 <<< shift) |> i2u(8)
      end

    Common.update_register(output, state.registers, r_d, result)
  end

  # Bitwise operations
  def execute(instruction, state, output)
      when instruction in [:and, :xor, :or] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :and -> band(w_a, w_b)
        :xor -> bxor(w_a, w_b)
        :or -> bor(w_a, w_b)
      end

    Common.update_register(output, state.registers, r_d, result)
  end

  # Upper multiplication operations
  def execute(instruction, state, output)
      when instruction in [:mul_upper_s_s, :mul_upper_u_u, :mul_upper_s_u] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :mul_upper_s_s ->
          div(u2i(w_a, 8) * u2i(w_b, 8), 1 <<< 64) |> i2u(8)

        :mul_upper_u_u ->
          div(w_a * w_b, 1 <<< 64)

        :mul_upper_s_u ->
          div(u2i(w_a, 8) * w_b, 1 <<< 64) |> i2u(8)
      end

    Common.update_register(output, state.registers, r_d, result)
  end

  # Comparison operations
  def execute(instruction, state, output)
      when instruction in [:set_lt_u, :set_lt_s] do
    {w_a, w_b, r_d} = get_params(state)

    result =
      case instruction do
        :set_lt_u -> if(w_a < w_b, do: 1, else: 0)
        :set_lt_s -> if(u2i(w_a, 8) < u2i(w_b, 8), do: 1, else: 0)
      end

    Common.update_register(output, state.registers, r_d, result)
  end

  # Conditional move operations
  def execute(instruction, state, output)
      when instruction in [:cmov_iz, :cmov_nz] do
    {w_a, w_b, r_d} = get_params(state)
    w_d = Enum.at(state.registers, r_d)

    result =
      case instruction do
        :cmov_iz -> if(w_b == 0, do: w_a, else: w_d)
        :cmov_nz -> if(w_b != 0, do: w_a, else: w_d)
      end

    Common.update_register(output, state.registers, r_d, result)
  end

  # Formula (A.26)
  defp get_params(state) do
    byte1 = binary_part(state.program, state.counter + 1, 1) |> :binary.first()
    byte2 = binary_part(state.program, state.counter + 2, 1) |> :binary.first()

    r_a = min(12, rem(byte1, 16))
    w_a = Enum.at(state.registers, r_a)
    r_b = min(12, div(byte1, 16))
    w_b = Enum.at(state.registers, r_b)
    r_d = min(12, byte2)

    {w_a, w_b, r_d}
  end
end
