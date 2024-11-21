defmodule Instructions.NoArgs do
  # Section (A.5.1) v0.4.5
  def execute(:trap, output), do: %StepOutput{output | exit_status: :panic}
  def execute(:fallthrough, output), do: output
end
