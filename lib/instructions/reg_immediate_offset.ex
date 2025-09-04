defmodule PVM.Instructions.RegImmediateOffset do
  use PVM.Utils
  alias PVM.Registers
  alias PVM.{Instructions.Executor}
  use PVM.Math
  @type comparison_op :: :eq | :ne | :lt_u | :le_u | :ge_u | :gt_u | :lt_s | :le_s | :ge_s | :gt_s
  # Section (A.5.8) v0.7.0
  def execute(:load_imm_jump, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)

    {exit_reason, counter} = Executor.branch(v_y, true, state.counter, start_set)

    Registers.put_elem(state.registers.r, r_a, v_x)
    {exit_reason,     %{       state| counter: counter,}}
  end

  def execute(:branch_eq_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a == v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ne_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a != v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_lt_u_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a < v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_le_u_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a <= v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ge_u_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a >= v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_gt_u_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]
    {exit_status, counter} = Executor.branch(v_y, w_a > v_x, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_lt_s_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]

    {exit_status, counter} =
      Executor.branch(v_y, u2i(w_a, 8) < u2i(v_x, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_le_s_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]

    {exit_status, counter} =
      Executor.branch(v_y, u2i(w_a, 8) <= u2i(v_x, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ge_s_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]

    {exit_status, counter} =
      Executor.branch(v_y, u2i(w_a, 8) >= u2i(v_x, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_gt_s_imm, program, bitmask, start_set, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = state.registers[r_a]

    {exit_status, counter} =
      Executor.branch(v_y, u2i(w_a, 8) > u2i(v_x, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  # Formula (A.29) v0.7.0
  defp get_params(program, bitmask, counter) do
    <<first_byte>> = binary_part_safe(program, counter + 1, 1)
    r_a = mod(first_byte, 16) |> min(12)
    l_x = first_byte |> div(16) |> mod(8) |> min(4)
    l_y = (skip(counter, bitmask) - l_x - 1) |> max(0) |> min(4)

    v_x = decode_and_extend(program, counter + 2, l_x)
    v_y = counter + (decode_bytes(program, counter + 2 + l_x, l_y) |> u2i(l_y))

    {r_a, v_x, v_y}
  end
end
