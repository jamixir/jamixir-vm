defmodule PVM.Instructions.NoArgs do
  # Section (A.5.1) v0.7.0
  def execute(:trap, state) do
    {:panic, state}
  end

  def execute(:fallthrough, state) do
    {:continue, state}
  end
end
