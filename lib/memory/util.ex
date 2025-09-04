defmodule PVM.Memory.Util do
  import Bitwise
  alias PVM.Math

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

  # rem twice handles negative numbers as well
  def wrap_address(%{size: size}, address) do
    rem(rem(address, size) + size, size)
  end

  defguard start_of_page(address, page_size) when (address &&& page_size - 1) == 0

  def write_to_sparse(%{data: nil} = memory, address, value), do:
    write_to_sparse(%{memory | data: :ets.new(:ets_binary_lazy, [:set, :public])}, address, value)

  def write_to_sparse(memory, _, <<>>), do: memory.data

  # case when address is page-aligned and value is at least a full page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when start_of_page(address, page_size) and byte_size(value) >= page_size do
    <<p1_value::binary-size(page_size), rest_value::binary>> = value
    :ets.insert(memory.data, {div(address, page_size), p1_value})
    write_to_sparse(memory, address + page_size, rest_value)
  end

  @empty_page <<0::size(8 * PVM.Memory.Constants.page_size)>>

  # last chunk which is less than a full page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when start_of_page(address, page_size) and byte_size(value) < page_size do
    page_num = address >>> 12

    current_page_value =
      case :ets.lookup(memory.data, page_num) do
        [] -> @empty_page
        [{_, v}] -> v
      end

    last_part = binary_slice(current_page_value, byte_size(value), page_size)
    new_page_value = value <> last_part
    :ets.insert(memory.data, {page_num, new_page_value})
    memory.data
  end

  # case when address is not page-aligned and ends on the first page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when not start_of_page(address, page_size) do
    page_num = address >>> 12
    end_page_num = (address + byte_size(value) - 1) >>> 12

    if page_num == end_page_num do
      offset = Math.mod(address, page_size)

      current_page_value =
        case :ets.lookup(memory.data, page_num) do
          [] -> @empty_page
          [{_, v}] -> v
        end

      first_part = binary_slice(current_page_value, 0, offset)
      last_part = binary_slice(current_page_value, offset + byte_size(value), page_size)
      new_page_value = first_part <> value <> last_part
      :ets.insert(memory.data, {page_num, new_page_value})
      memory.data
    else
      # case when address is not page-aligned and ends after first page
      offset = Math.mod(address, page_size)

      current_page_value =
        case :ets.lookup(memory.data, page_num) do
          [] -> @empty_page
          [{_, v}] -> v
        end

      first_part = binary_slice(current_page_value, 0, offset)
      <<last_part::binary-size(page_size - offset), rest::binary>> = value
      new_page_value = first_part <> last_part
      :ets.insert(memory.data, {page_num, new_page_value})
      write_to_sparse(memory, address - offset + page_size, rest)
    end
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
