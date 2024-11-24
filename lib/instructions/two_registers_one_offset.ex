defmodule Instructions.TwoRegistersOneOffset do
  use PVM.Utils
  alias Instructions.Executor
  use Transitions

  def execute(instruction, program, bitmask, state) do
    {w_a, w_b, v_x, start_set} = get_params(program, bitmask, state)

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
      binary_part(program, state.counter + 1, 1)
      |> :binary.first()
      |> rem(16)
      |> min(12)

    r_b =
      binary_part(program, state.counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> min(12)

    l_x = min(4, max(0, skip(state.counter, bitmask) - 1))
    v_x = decode_bytes_signed(program, state.counter + 2, l_x)
    w_a = Enum.at(state.registers, r_a)
    w_b = Enum.at(state.registers, r_b)
    start_set = basic_block_starts(program, bitmask)

    {w_a, w_b, v_x, start_set}
  end
end
