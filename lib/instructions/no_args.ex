defmodule PVM.Instructions.NoArgs do
  # Section (A.5.1) v0.6.1
  def execute(:trap, state),
    do: {:panic, state}

  def execute(:fallthrough, state),
    do: {:continue, state}
end
