defmodule PVM.Instructions.OneImmediate do
  use PVM.Transitions
  use PVM.Utils
  alias PVM.Instructions.Executor

  # Section (A.5.2) v0.6.1
  def execute(:ecalli, program, bitmask, _start_set, state) do
    # Formula (A.19) v0.6.1
    l_x = min(4, skip(state.counter, bitmask))
    value = decode_bytes_signed(program, state.counter + 1, l_x)
    {{:ecall, value}, state}
  end

  # Section (A.5.5) v0.6.1
  def execute(:jump, program, bitmask, start_set, state) do
    # Formula (A.22) v0.6.1
    l_x = min(4, skip(state.counter, bitmask))

    shift_signed =
      decode_bytes(program, state.counter + 1, l_x) |> u2i(l_x)

    v_x = state.counter + shift_signed

    {exit_reason, counter} = Executor.branch(v_x, true, state.counter, start_set)
    {exit_reason, %{state | counter: counter}}
  end
end
