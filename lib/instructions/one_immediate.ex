defmodule Instructions.OneImmediate do
  alias PVM.Utils
  alias Instructions.Executor

  def execute(:ecalli, state, output) do
    {value, _} = Utils.parse_immediate(state.program, state.counter)
    %StepOutput{output | exit_status: {:ecall, value}}
  end

  def execute(:jump, state, output) do
    l_x = min(4, Utils.skip(state.counter, state.bitmask))
    x_bytes = binary_part(state.program, state.counter + 1, l_x)
    x_value = Utils.de_le(x_bytes, l_x)
    shift_signed = Transitions.z_n(x_value, l_x)
    v_x = state.counter + shift_signed

    start_set = Utils.basic_block_starts(state.program, state.bitmask)
    {exit_status, counter} = Executor.branch(v_x, true, state.counter, start_set)
    %StepOutput{output | exit_status: exit_status, counter: counter}
  end
end
