defmodule Instructions.RegImmediateOffset do
  alias PVM.Utils
  alias Instructions.{Common, Executor}

  @type comparison_op :: :eq | :ne | :lt_u | :le_u | :ge_u | :gt_u | :lt_s | :le_s | :ge_s | :gt_s

  def execute(:load_imm_jump, state, output) do
    {r_a, v_x, v_y, start_set} = get_params(state)
    output = Common.update_register(output, state.registers, r_a, v_x)
    {exit_status, counter} = Executor.branch(v_y, true, state.counter, start_set)
    %StepOutput{output | exit_status: exit_status, counter: counter}
  end

  def execute(instruction, state, output) do
    {r_a, v_x, v_y, start_set} = get_params(state)
    w_a = Enum.at(state.registers, r_a)

    comparison_result = compare(instruction_to_op(instruction), w_a, v_x)
    {exit_status, counter} = Executor.branch(v_y, comparison_result, state.counter, start_set)
    %StepOutput{output | exit_status: exit_status, counter: counter}
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
        w_a_signed = Transitions.z_n(w_a, 8)
        v_x_signed = Transitions.z_n(v_x, 8)

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
  defp get_params(state) do
    r_a =
      binary_part(state.program, state.counter + 1, 1)
      |> :binary.first()
      |> rem(16)
      |> min(12)

    l_x =
      binary_part(state.program, state.counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> rem(8)
      |> min(4)

    l_y =
      (Utils.skip(state.counter, state.bitmask) - l_x - 1)
      |> max(0)
      |> min(4)

    v_x = Utils.decode_bytes_signed(state.program, state.counter + 2, l_x)

    v_y =
      state.counter +
        (Utils.decode_bytes(state.program, state.counter + 2 + l_x, l_y)
         |> Transitions.z_n(l_y))

    start_set = Utils.basic_block_starts(state.program, state.bitmask)

    {r_a, v_x, v_y, start_set}
  end
end
