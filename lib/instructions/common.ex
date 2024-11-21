defmodule Instructions.Common do
  use PVM.Encoder

  @doc """
  Handles writing bytes to memory and returns appropriate StepOutput
  """
  def do_write(output, addr, memory, bytes) do
    case Memory.write(memory, addr, bytes) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      new_memory ->
        %StepOutput{output | memory: new_memory}
    end
  end

  @doc """
  Updates a register at the given index with a new value
  """
  def update_register(output, registers, index, value) do
    %StepOutput{output | registers: List.replace_at(registers, index, value)}
  end
end
