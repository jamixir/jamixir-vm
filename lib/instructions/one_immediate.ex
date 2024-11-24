defmodule Instructions.OneImmediate do
  use Transitions
  use PVM.Utils
  alias Instructions.Executor

  # Section (A.5.2) v0.4.5
  def execute(:ecalli, program, bitmask, state) do
    l_x = min(4, skip(state.counter, bitmask))
    value = decode_bytes_signed(program, state.counter + 1, l_x)
    {{:ecall, value}, state}
  end

  # Section (A.5.4) v0.4.5
  def execute(:jump, program, bitmask, state) do
    l_x = min(4, skip(state.counter, bitmask))

    shift_signed =
      decode_bytes(program, state.counter + 1, l_x) |> u2i(l_x)

    v_x = state.counter + shift_signed

    start_set = basic_block_starts(program, bitmask)
    {exit_reason, counter} = Executor.branch(v_x, true, state.counter, start_set)
    {exit_reason, %{state | counter: counter}}
  end
end
