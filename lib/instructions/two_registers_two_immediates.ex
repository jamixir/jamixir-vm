defmodule PVM.Instructions.TwoRegistersTwoImmediates do
  use PVM.Utils
  alias PVM.{Instructions.Executor, Registers}
  use PVM.Transitions
  import Bitwise

  def execute(:load_imm_jump_ind, program, bitmask, jump_table, start_set, state) do
    {r_a, r_b, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_b = Registers.get(state.registers, r_b)

    jump_addr = rem(w_b + v_y, 1 <<< 32)

    {exit_status, counter} = Executor.djump(jump_addr, state.counter, jump_table, start_set)

    {exit_status,
     %{state | counter: counter, registers: Registers.set(state.registers, r_a, v_x)}}
  end

  # Formula (A.25) from specification
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

    l_x =
      binary_part(program, counter + 2, 1)
      |> :binary.first()
      |> rem(8)
      |> min(4)

    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 2))

    v_x = decode_and_extend(program, counter + 3, l_x)
    v_y = decode_and_extend(program, counter + 3 + l_x, l_y)

    {r_a, r_b, v_x, v_y}
  end
end
