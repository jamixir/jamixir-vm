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

  def wrap_address(%{size: size}, address) do
    rem(rem(address, size) + size, size)
  end

  def write_to_sparse(memory, address, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(memory.data, fn {byte, index}, acc ->
      wrapped_addr = wrap_address(memory, address + index)
      page_num = div(wrapped_addr, memory.page_size)
      page_offset = rem(wrapped_addr, memory.page_size)

      # Get or create the page, then update it with the new byte
      page = Map.get(acc, page_num, %{})
      updated_page = Map.put(page, page_offset, byte)
      Map.put(acc, page_num, updated_page)
    end)
  end

  def get_page_range(%{page_size: page_size} = memory, start_address, length) do
    start_page = div(start_address, page_size)
    end_address = wrap_address(memory, start_address + max(0, length - 1))
    end_page = div(end_address, page_size)

    {start_page, end_page}
  end
end
