defmodule Memory do
  import Bitwise

  @default_page_size 1 <<< 12  # 4KB per page
  @memory_size 1 <<< 32        # 4GB total memory

  def memory_size, do: @memory_size

  @type t :: %__MODULE__{
    data: %{non_neg_integer() => byte()},
    access: %{non_neg_integer() => atom()},
    default_access: atom(),
    page_size: pos_integer()
  }

  defstruct data: %{},
            access: %{},
            default_access: :write,
            page_size: @default_page_size

  def set_page_size(%__MODULE__{} = memory, size) do
    new_access = recompute_access_permissions(memory, size)
    %__MODULE__{memory | page_size: size, access: new_access}
  end

  defp wrap_address(address) do
    rem(address, memory_size())
  end

  def read(%__MODULE__{} = memory, address, length) do
    wrapped_address = wrap_address(address)

    {start_page, end_page} = get_page_range(wrapped_address, length, memory.page_size)

    case check_permissions(memory, start_page, end_page, :read) do
      :ok ->
        data = read_from_sparse(memory.data, wrapped_address, length)
        {:ok, data}

      {:error, page} ->
        {:error, {:fault, page}}
    end
  end

  def write(%__MODULE__{} = memory, address, value) when is_binary(value) do
    wrapped_address = wrap_address(address)
    length = byte_size(value)

    {start_page, end_page} = get_page_range(wrapped_address, length, memory.page_size)

    case check_permissions(memory, start_page, end_page, :write) do
      :ok ->
        new_data = write_to_sparse(memory.data, wrapped_address, value)
        {:ok, %__MODULE__{memory | data: new_data}}

      {:error, page} ->
        {:error, {:fault, page}}
    end
  end

  defp read_from_sparse(data, address, length) do
    0..(length - 1)
    |> Enum.map(fn offset ->
      wrapped_addr = wrap_address(address + offset)
      Map.get(data, wrapped_addr, 0)
    end)
    |> :binary.list_to_bin()
  end

  defp write_to_sparse(data, address, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(data, fn {byte, index}, acc ->
      wrapped_addr = wrap_address(address + index)
      Map.put(acc, wrapped_addr, byte)
    end)
  end

  defp check_permissions(memory, start_page, end_page, required_access) do
    page_range = get_sequential_pages(start_page, end_page, div(memory_size(), memory.page_size))

    Enum.reduce_while(page_range, :ok, fn page, _acc ->
      current_access = Map.get(memory.access, page, memory.default_access)

      cond do
        required_access == :read and current_access in [:read, :write] -> {:cont, :ok}
        required_access == :write and current_access == :write -> {:cont, :ok}
        true -> {:halt, {:error, page}}
      end
    end)
  end

  defp get_page_range(start_address, length, page_size) do
    start_page = div(start_address, page_size)
    end_page = div(start_address + max(0, length - 1), page_size)
    {start_page, end_page}
  end

  defp get_sequential_pages(start_page, end_page, total_pages) do
    if end_page >= start_page do
      start_page..end_page
    else
      Enum.to_list(start_page..(total_pages - 1)) ++ Enum.to_list(0..end_page)
    end
  end

  defp recompute_access_permissions(memory, new_page_size) do
    old_page_size = memory.page_size

    Enum.map(memory.access, fn {page, access} ->
      start_addr = page * old_page_size
      {start_addr, start_addr + old_page_size - 1, access}
    end)
    |> Enum.reduce(%{}, fn {start_addr, end_addr, access}, acc ->
      start_page = div(start_addr, new_page_size)
      end_page = div(end_addr, new_page_size)

      Enum.reduce(start_page..end_page, acc, fn page, inner_acc ->
        Map.put(inner_acc, page, access)
      end)
    end)
  end

  def set_access(%__MODULE__{} = memory, address, length, access_type) do
    {start_page, end_page} = get_page_range(address, length, memory.page_size)

    new_access =
      get_sequential_pages(start_page, end_page, div(memory_size(), memory.page_size))
      |> Enum.reduce(memory.access, fn page, acc ->
        Map.put(acc, page, access_type)
      end)

    %__MODULE__{memory | access: new_access}
  end

  def set_default_access(%__MODULE__{} = memory, access_type) do
    %__MODULE__{memory | default_access: access_type}
  end

  def readable_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn page ->
      access = Map.get(memory.access, page, memory.default_access)
      access != nil
    end)
    |> MapSet.new()
  end

  def writeable_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn page ->
      Map.get(memory.access, page, memory.default_access) == :write
    end)
    |> MapSet.new()
  end
end
