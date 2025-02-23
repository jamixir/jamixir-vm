defmodule PVM.Instructions.NoArgs do
  alias PVM.Trace

  # Section (A.5.1) v0.6.1
  def execute(:trap, state) do
    Trace.instruction(state.counter, "trap", "action: panic")
    {:panic, state}
  end

  def execute(:fallthrough, state) do
    Trace.instruction(state.counter, "fallthrough", "action: continue to next instruction")
    {:continue, state}
  end
end
