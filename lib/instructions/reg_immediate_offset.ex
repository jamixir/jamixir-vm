defmodule PVM.Instructions.RegImmediateOffset do
  use PVM.Utils
  alias PVM.Instructions.Executor
  use PVM.Transitions
  alias PVM.Registers
  @type comparison_op :: :eq | :ne | :lt_u | :le_u | :ge_u | :gt_u | :lt_s | :le_s | :ge_s | :gt_s

  def execute(:load_imm_jump, program, bitmask,  state) do
    {r_a, v_x, v_y, start_set} = get_params(program, bitmask, state.counter)
    {exit_reason, counter} = Executor.branch(v_y, true, state.counter, start_set)

    {exit_reason,
     %{state | counter: counter, registers: Registers.set(state.registers, r_a, v_x)}}
  end

  def execute(instruction, program, bitmask, state) do
    {r_a, v_x, v_y, start_set} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)

    comparison_result = compare(instruction_to_op(instruction), w_a, v_x)
    {exit_status, counter} = Executor.branch(v_y, comparison_result, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  defp compare(op, w_a, v_x) do
    case op do
      :eq ->
        w_a == v_x

      :ne ->
        w_a != v_x

      :lt_u ->
        w_a < v_x

      :le_u ->
        w_a <= v_x

      :ge_u ->
        w_a >= v_x

      :gt_u ->
        w_a > v_x

      op when op in [:lt_s, :le_s, :ge_s, :gt_s] ->
        w_a_signed = u2i(w_a, 8)
        v_x_signed = u2i(v_x, 8)

        case op do
          :lt_s -> w_a_signed < v_x_signed
          :le_s -> w_a_signed <= v_x_signed
          :ge_s -> w_a_signed >= v_x_signed
          :gt_s -> w_a_signed > v_x_signed
        end
    end
  end

  defp instruction_to_op(instruction) do
    case instruction do
      :branch_eq_imm -> :eq
      :branch_ne_imm -> :ne
      :branch_lt_u_imm -> :lt_u
      :branch_le_u_imm -> :le_u
      :branch_ge_u_imm -> :ge_u
      :branch_gt_u_imm -> :gt_u
      :branch_lt_s_imm -> :lt_s
      :branch_le_s_imm -> :le_s
      :branch_ge_s_imm -> :ge_s
      :branch_gt_s_imm -> :gt_s
    end
  end

  # Formula (A.21) v0.5
  defp get_params(program, bitmask, counter) do
    r_a =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> rem(16)
      |> min(12)

    l_x =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> rem(8)
      |> min(4)

    l_y =
      (skip(counter, bitmask) - l_x - 1)
      |> max(0)
      |> min(4)

    v_x = decode_bytes_signed(program, counter + 2, l_x)

    v_y =
      counter +
        (decode_bytes(program, counter + 2 + l_x, l_y)
         |> u2i(l_y))

    start_set = basic_block_starts(program, bitmask)

    {r_a, v_x, v_y, start_set}
  end
end
