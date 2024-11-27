defmodule PVM.Memory.Util do
  def write(state, addr, value) do
    case PVM.Memory.write(state.memory, addr, value) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}
      {:ok, new_memory} ->
        {:continue, %{state | memory: new_memory}}
    end
  end

  def read(state, addr, length) do
    case PVM.Memory.read(state.memory, addr, length) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}
      {:ok, data} ->
        {:continue, %{state | data: data}}
    end
  end
end
