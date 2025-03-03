defmodule PVM.Memory do
  import PVM.Memory.Constants

  @type t :: %__MODULE__{
          data: %{non_neg_integer() => byte()},
          access_ranges: [{non_neg_integer(), non_neg_integer(), atom()}],
          page_size: pos_integer(),
          size: pos_integer()
        }

  defstruct data: %{},
            access_ranges: [],
            page_size: page_size(),
            size: memory_size()

  # PUBLIC FUNCTIONS
  def number_of_pages(%__MODULE__{} = memory) do
    div(memory.size, memory.page_size)
  end

  ## Read/Write functions

  def read(%__MODULE__{} = memory, address, length) do
    wrapped_address = wrap_address(memory, address)

    if wrapped_address < min_allowed_address() do
      {:error, :panic}
    else
      {start_page, end_page} = get_page_range(memory, wrapped_address, length)

      case check_permissions(memory, start_page, end_page, :read) do
        :ok ->
          data = read_from_sparse(memory, wrapped_address, length)
          {:ok, data}

        {:error, page} ->
          {:error, {:fault, page}}
      end
    end
  end

  def read!(%__MODULE__{} = memory, address, length) do
    case read(memory, address, length) do
      {:ok, data} -> data
      {:error, reason} -> raise PVM.MemoryFaultError, reason: reason
    end
  end

  def write(%__MODULE__{} = memory, address, value) when is_binary(value) do
    wrapped_address = wrap_address(memory, address)

    if wrapped_address < min_allowed_address() do
      {:error, :panic}
    else
      length = byte_size(value)

      {start_page, end_page} = get_page_range(memory, wrapped_address, length)

      case check_permissions(memory, start_page, end_page, :write) do
        :ok ->
          new_data = write_to_sparse(memory, wrapped_address, value)
          {:ok, %__MODULE__{memory | data: new_data}}

        {:error, page} ->
          {:error, {:fault, page}}
      end
    end
  end

  def write!(%__MODULE__{} = memory, address, value) do
    case write(memory, address, value) do
      {:ok, memory} -> memory
      {:error, reason} -> raise PVM.MemoryFaultError, reason: reason
    end
  end

  ## SET Access functions

  def set_access(%__MODULE__{} = memory, address, length, access_type) do
    {start_page, end_page} = get_page_range(memory, address, length)

    num_pages =
      if end_page >= start_page do
        end_page - start_page + 1
      else
        # wrapping around memory
        number_of_pages(memory) - start_page + end_page + 1
      end

    set_access_by_page(memory, start_page, num_pages, access_type)
  end

  def set_access_by_page(%__MODULE__{} = memory, start_page, num_pages, access_type) do
    total_pages = number_of_pages(memory)
    start_page = rem(start_page, total_pages)
    end_page = max(start_page, rem(start_page - 1 + num_pages, total_pages))

    new_ranges =
      add_range_to_access_ranges(memory.access_ranges, start_page, end_page, access_type)

    %__MODULE__{memory | access_ranges: new_ranges}
  end

  ## Check Access functions
  def check_range_access?(%__MODULE__{} = memory, address, length, required_access) do
    wrapped_address = wrap_address(memory, address)
    {start_page, end_page} = get_page_range(memory, wrapped_address, length)
    check_permissions(memory, start_page, end_page, required_access) == :ok
  end

  def check_pages_access?(%__MODULE__{} = memory, start_page, num_pages, required_access) do
    total_pages = number_of_pages(memory)
    start_page = rem(start_page, total_pages)
    end_page = rem(start_page - 1 + num_pages, total_pages)

    check_permissions(memory, start_page, end_page, required_access) == :ok
  end

  def find_free_memory(%__MODULE__{} = memory, pages_needed) do
    min_page = div(min_allowed_address(), memory.page_size)
    max_page = number_of_pages(memory) - 1

    occupied_ranges =
      memory.access_ranges
      |> Enum.filter(fn {_, _, access} -> access != nil end)
      |> Enum.map(fn {start, end_, _} -> {start, end_} end)
      |> Enum.sort_by(fn {start, _} -> start end)

    find_free_space_in_ranges(occupied_ranges, min_page, max_page, pages_needed)
  end

  ## Private functions
  defp wrap_address(%__MODULE__{size: size}, address) do
    rem(rem(address, size) + size, size)
  end

  defp read_from_sparse(%__MODULE__{data: data} = memory, address, length) do
    0..(length - 1)
    |> Enum.map(fn offset ->
      wrapped_addr = wrap_address(memory, address + offset)
      Map.get(data, wrapped_addr, 0)
    end)
    |> :binary.list_to_bin()
  end

  defp write_to_sparse(%__MODULE__{data: data} = memory, address, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(data, fn {byte, index}, acc ->
      wrapped_addr = wrap_address(memory, address + index)
      Map.put(acc, wrapped_addr, byte)
    end)
  end

  defp check_permissions(memory, start_page, end_page, required_access) do
    # Get all pages in the range
    page_range = get_sequential_pages(start_page, end_page, number_of_pages(memory))

    # Find the first page that doesn't have the required access
    Enum.find_value(page_range, :ok, fn page ->
      case find_access_for_page(memory.access_ranges, page) do
        access when required_access == :read and access in [:read, :write] -> nil
        access when required_access == :write and access == :write -> nil
        _ -> {:error, page * memory.page_size}
      end
    end)
  end

  defp find_access_for_page(access_ranges, page) do
    sorted_ranges = Enum.sort_by(access_ranges, fn {start, _, _} -> start end)
    {_, _, access} = binary_search_range(sorted_ranges, page, 0, length(sorted_ranges) - 1)
    access
  end

  defp binary_search_range(ranges, page, low, high) do
    mid = div(low + high, 2)

    {start, end_, _} = Enum.at(ranges, mid)

    cond do
      page >= start and page <= end_ ->
        # Found a range containing the page
        Enum.at(ranges, mid)

      page < start ->
        # Search in the lower half
        binary_search_range(ranges, page, low, mid - 1)

      true ->
        # Search in the upper half
        binary_search_range(ranges, page, mid + 1, high)
    end
  end

  defp get_page_range(%__MODULE__{page_size: page_size} = memory, start_address, length) do
    start_page = div(start_address, page_size)
    end_address = wrap_address(memory, start_address + max(0, length - 1))
    end_page = div(end_address, page_size)

    {start_page, end_page}
  end

  defp get_sequential_pages(start_page, end_page, total_pages) do
    if end_page >= start_page do
      start_page..end_page
    else
      Enum.to_list(start_page..(total_pages - 1)) ++ Enum.to_list(0..end_page)
    end
  end

  defp add_range_to_access_ranges(ranges, start_page, end_page, access_type) do
    new_range = {start_page, end_page, access_type}

    [new_range | ranges]
    |> merge_overlapping_ranges()
  end

  defp merge_overlapping_ranges(ranges) do
    sorted = Enum.sort_by(ranges, fn {start, _, _} -> start end)

    # Merge adjacent or overlapping ranges with the same access type
    Enum.reduce(sorted, [], fn
      range, [] ->
        [range]

      {start, end_, type}, [{prev_start, prev_end, prev_type} | rest] = acc ->
        if type == prev_type and start <= prev_end + 1 do
          [{prev_start, max(end_, prev_end), type} | rest]
        else
          [{start, end_, type} | acc]
        end
    end)
    |> Enum.reverse()
  end

  defp find_free_space_in_ranges([], min_page, max_page, pages_needed) do
    # No occupied ranges - entire memory is available
    if max_page - min_page + 1 >= pages_needed do
      min_page
    else
      nil
    end
  end

  defp find_free_space_in_ranges(occupied_ranges, min_page, max_page, pages_needed) do
    # Check for gap at beginning
    [{first_start, _} | _] = occupied_ranges

    if first_start > min_page && first_start - min_page >= pages_needed do
      min_page
    else
      # Check for gaps between ranges
      find_gap_between_ranges(occupied_ranges, pages_needed, max_page)
    end
  end

  defp find_gap_between_ranges(ranges, pages_needed, max_page) do
    # Pair consecutive ranges to find gaps
    Enum.chunk_every(ranges, 2, 1, :discard)
    |> Enum.find_value(nil, fn [{_, prev_end}, {next_start, _}] ->
      gap_size = next_start - (prev_end + 1)
      if gap_size >= pages_needed, do: prev_end + 1, else: nil
    end)
    |> case do
      nil ->
        # Check for gap after last range
        {_, last_end} = List.last(ranges)
        if max_page - last_end >= pages_needed, do: last_end + 1, else: nil

      result ->
        result
    end
  end
end
