defmodule PVM.Instructions.TwoRegistersOneOffset do
  use PVM.Utils
  alias PVM.{Instructions.Executor, Registers, Trace}
  use PVM.Transitions

  def execute(instruction, program, bitmask, start_set, state) do
    {w_a, w_b, v_x, r_a, r_b} = get_params(program, bitmask, state)

    comparison_result = instruction_to_op(instruction, w_a, w_b)

    # Add trace showing the comparison operation and result
    trace_comparison(state, instruction, r_a, w_a, r_b, w_b, comparison_result, v_x)

    {exit_status, counter} = Executor.branch(v_x, comparison_result, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  defp trace_comparison(state, instruction, r_a, w_a, r_b, w_b, result, target) do
    op_symbol = case instruction do
      :branch_eq -> "=="
      :branch_ne -> "!="
      :branch_lt_u -> "<"
      :branch_lt_s -> "<s"
      :branch_ge_u -> ">="
      :branch_ge_s -> ">=s"
    end

    Trace.instruction(state.counter, "#{instruction}",
      "if w#{r_a}(#{w_a}) #{op_symbol} w#{r_b}(#{w_b}) then branch to #{target} [#{result}]")
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
      |> rem(16)
      |> min(12)

    r_b =
      binary_part_safe(program, state.counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> min(12)

    l_x = min(4, max(0, skip(state.counter, bitmask) - 1))
    v_x = state.counter + decode_bytes(program, state.counter + 2, l_x) |> u2i(l_x)
    w_a = Registers.get(state.registers, r_a)
    w_b = Registers.get(state.registers, r_b)

    {w_a, w_b, v_x, r_a, r_b}
  end
end
