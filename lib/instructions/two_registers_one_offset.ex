defmodule PVM.Instructions.TwoRegistersOneOffset do
  use PVM.Utils
  alias PVM.{Instructions.Executor, Registers}
  use PVM.Math

  def execute(instruction, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)

    comparison_result = instruction_to_op(instruction, w_a, w_b)

    {exit_status, counter} = Executor.branch(v_x, comparison_result, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  defp instruction_to_op(instruction, w_a, w_b) do
    case instruction do
      :branch_eq -> w_a == w_b
      :branch_ne -> w_a != w_b
      :branch_lt_u -> w_a < w_b
      :branch_lt_s -> u2i(w_a, 8) < u2i(w_b, 8)
      :branch_ge_u -> w_a >= w_b
      :branch_ge_s -> u2i(w_a, 8) >= u2i(w_b, 8)
    end
  end

  # Formula (A.24)
  defp get_params(program, bitmask, state) do
    r_a =
      binary_part_safe(program, state.counter + 1, 1)
      |> :binary.first()
      |> mod(16)
      |> min(12)

    r_b =
      binary_part_safe(program, state.counter + 1, 1)
      |> :binary.first()
      |> Bitwise.bsr(4)
      |> min(12)

    l_x = min(4, max(0, skip(state.counter, bitmask) - 1))
    signed_immediate = decode_bytes(program, state.counter + 2, l_x) |> u2i(l_x)
    v_x = state.counter + signed_immediate
    w_a = Registers.get(state.registers, r_a)
    w_b = Registers.get(state.registers, r_b)

    {w_a, w_b, v_x}
  end
end
