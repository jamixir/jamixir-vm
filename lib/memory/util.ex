defmodule PVM.Memory.Util do
  def write_memory(state, addr, value) do
    case PVM.Memory.write(state.memory, addr, value) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:error, :panic} ->
        {:panic, state}

      {:ok, new_memory} ->
        {:continue, %{state | memory: new_memory}}
    end
  end



  def read_memory(state, addr, bytes, success_fn) do
    case PVM.Memory.read(state.memory, addr, bytes) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:error, :panic} ->
        {:panic, state}

      {:ok, value} ->
        state_ = success_fn.(value)
        {:continue, state_}
    end
  end
end
