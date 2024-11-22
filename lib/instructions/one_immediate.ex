defmodule Instructions.OneImmediate do
  use Transitions
  alias PVM.Utils
  alias Instructions.Executor

  # Section (A.5.2) v0.4.5
  def execute(:ecalli, state, output) do
    l_x = min(4, Utils.skip(state.counter, state.bitmask))
    value = Utils.decode_bytes_signed(state.program, state.counter + 1, l_x)
    %StepOutput{output | exit_status: {:ecall, value}}
  end

  # Section (A.5.4) v0.4.5
  def execute(:jump, state, output) do
    l_x = min(4, Utils.skip(state.counter, state.bitmask))

    shift_signed =
      Utils.decode_bytes(state.program, state.counter + 1, l_x) |> u2i(l_x)

    v_x = state.counter + shift_signed

    start_set = Utils.basic_block_starts(state.program, state.bitmask)
    {exit_status, counter} = Executor.branch(v_x, true, state.counter, start_set)
    %StepOutput{output | exit_status: exit_status, counter: counter}
  end
end
