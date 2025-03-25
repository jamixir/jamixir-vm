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

  def wrap_address(%{size: size}, address) do
    rem(rem(address, size) + size, size)
  end

  def write_to_sparse(memory, address, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(memory.data, fn {byte, index}, acc ->
      wrapped_addr = wrap_address(memory, address + index)
      {page_num, page_offset} = page_address(memory, wrapped_addr)

      updated_page = Map.get(acc, page_num, %{}) |> Map.put(page_offset, byte)
      Map.put(acc, page_num, updated_page)
    end)
  end

  def get_page_range(%{page_size: page_size} = memory, start_address, length) do
    start_page = div(start_address, page_size)
    end_address = wrap_address(memory, start_address + max(0, length - 1))
    end_page = div(end_address, page_size)

    {start_page, end_page}
  end

  def page_address(memory, address),
    do: {div(address, memory.page_size), rem(address, memory.page_size)}

  def pages_with_data(%{data: data}) do
    Map.keys(data)
    |> Enum.filter(&(map_size(Map.get(data, &1)) > 0))
  end

  def get_page_binary(%{data: data, page_size: page_size}, page_num) do
    page = Map.get(data, page_num, %{})

    # Sort offsets for sequential processing
    offsets = page |> Map.keys() |> Enum.sort()

    if offsets == [] do
      :binary.copy(<<0>>, page_size)
    else
      # Build the binary in chunks between data points
      {binary, last_pos} =
        Enum.reduce(offsets, {<<>>, 0}, fn offset, {acc, pos} ->
          zeros_needed = offset - pos
          zeros = if zeros_needed > 0, do: :binary.copy(<<0>>, zeros_needed), else: <<>>

          byte_val = Map.get(page, offset)
          {<<acc::binary, zeros::binary, byte_val::8>>, offset + 1}
        end)

      remaining = page_size - last_pos

      if remaining > 0 do
        <<binary::binary, 0::unit(8)-size(remaining)>>
      else
        binary
      end
    end
  end
end
