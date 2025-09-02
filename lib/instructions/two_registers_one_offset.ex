defmodule PVM.Instructions.TwoRegistersOneOffset do
  use PVM.Utils
  alias PVM.{Instructions.Executor, Registers}
  use PVM.Math

  def execute(:branch_eq, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)
    {exit_status, counter} = Executor.branch(v_x, w_a == w_b, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ne, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)
    {exit_status, counter} = Executor.branch(v_x, w_a != w_b, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_lt_u, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)
    {exit_status, counter} = Executor.branch(v_x, w_a < w_b, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_lt_s, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)

    {exit_status, counter} =
      Executor.branch(v_x, u2i(w_a, 8) < u2i(w_b, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ge_u, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)
    {exit_status, counter} = Executor.branch(v_x, w_a >= w_b, state.counter, start_set)
    {exit_status, %{state | counter: counter}}
  end

  def execute(:branch_ge_s, program, bitmask, start_set, state) do
    {w_a, w_b, v_x} = get_params(program, bitmask, state)

    {exit_status, counter} =
      Executor.branch(v_x, u2i(w_a, 8) >= u2i(w_b, 8), state.counter, start_set)

    {exit_status, %{state | counter: counter}}
  end

  # Formula (A.24)
  defp get_params(program, bitmask, state) do
    <<r_a_byte>> =
      binary_part_safe(program, state.counter + 1, 1)

    r_a =
      r_a_byte
      |> mod(16)
      |> min(12)

    <<r_b_byte>> =
      binary_part_safe(program, state.counter + 1, 1)

    r_b =
      r_b_byte
      |> Bitwise.bsr(4)
      |> min(12)

    l_x = min(4, max(0, skip(state.counter, bitmask) - 1))
    signed_immediate = decode_bytes(program, state.counter + 2, l_x) |> u2i(l_x)
    v_x = state.counter + signed_immediate
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    {w_a, w_b, v_x}
  end
end
