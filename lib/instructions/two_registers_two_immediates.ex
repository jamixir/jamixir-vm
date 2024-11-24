defmodule Instructions.TwoRegistersTwoImmediates do
  use PVM.Utils
  alias Instructions.{Common, Executor}
  use Transitions
  import Bitwise

  def execute(:load_imm_jump_ind, state, output) do
    {r_a, r_b, v_x, v_y} = get_params(state)
    w_b = Enum.at(state.registers, r_b)

    # First update register r_a with immediate value v_x
    output = Common.update_register(output, state.registers, r_a, v_x)

    # Then perform indirect jump using register r_b and immediate v_y
    jump_addr = rem(w_b + v_y, 1 <<< 32)
    start_set = basic_block_starts(state.program, state.bitmask)

    {exit_status, counter} = Executor.djump(jump_addr, state.counter, state.jump_table, start_set)
    %StepOutput{output | exit_status: exit_status, counter: counter}
  end

  # Formula (A.25) from specification
  defp get_params(state) do
    r_a =
      binary_part(state.program, state.counter + 1, 1)
      |> :binary.first()
      |> rem(16)
      |> min(12)

    r_b =
      binary_part(state.program, state.counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> min(12)

    l_x =
      binary_part(state.program, state.counter + 2, 1)
      |> :binary.first()
      |> rem(8)
      |> min(4)

    l = skip(state.counter, state.bitmask)
    l_y = min(4, max(0, l - l_x - 2))

    v_x = decode_bytes_signed(state.program, state.counter + 3, l_x)
    v_y = decode_bytes_signed(state.program, state.counter + 3 + l_x, l_y)

    {r_a, r_b, v_x, v_y}
  end
end
