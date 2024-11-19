defmodule Instructions.NoArgs do
  def execute(:trap, output), do: %StepOutput{output | exit_status: :panic}
  def execute(:fallthrough, output), do: output
end 
