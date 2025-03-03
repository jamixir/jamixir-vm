defmodule PVM.Memory.Util do
  alias PVM.Trace

  def write_memory(state, addr, value) do
    case PVM.Memory.write(state.memory, addr, value) do
      {:error, {:fault, fault_addr}} ->
        Trace.write_line("error", "Memory write fault at address #{fault_addr}")
        {{:fault, fault_addr}, state}

      {:error, :panic} ->
        Trace.write_line("error", "Memory write panic")
        {:panic, state}

      {:ok, new_memory} ->
        # Convert value to list of bytes for display
        bytes = :binary.bin_to_list(value)
        Trace.write_line("state", "Memory write: address=#{addr}, contents=#{inspect(bytes)}")
        {:continue, %{state | memory: new_memory}}
    end
  end

  def read_memory(state, addr, bytes, success_fn) do
    case PVM.Memory.read(state.memory, addr, bytes) do
      {:error, {:fault, fault_addr}} ->
        Trace.write_line("error", "Memory read fault at address #{fault_addr}")
        {{:fault, fault_addr}, state}

      {:error, :panic} ->
        Trace.write_line("error", "Memory read panic")
        {:panic, state}

      {:ok, value} ->
        # Convert value to list of bytes for display
        bytes = :binary.bin_to_list(value)
        Trace.write_line("state", "Memory read: address=#{addr}, contents=#{inspect(bytes)}")
        state_ = success_fn.(value)
        {:continue, state_}
    end
  end


  
end
