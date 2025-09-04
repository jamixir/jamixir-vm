defmodule PVM.Memory.EtsBinaryMemory do
  import PVM.Memory.{Constants, Util}
  alias PVM.Memory.RangeManager

  @type t :: %__MODULE__{
          # ETS table storing {page_num, binary | nil}
          data: :ets.tid(),
          access_ranges: [{non_neg_integer(), non_neg_integer(), atom()}],
          page_size: pos_integer(),
          size: pos_integer(),
          current_heap_pointer: pos_integer(),
          max_heap_pointer: pos_integer()
        }

  defstruct data: nil,
            access_ranges: [],
            page_size: page_size(),
            size: memory_size(),
            current_heap_pointer: 0,
            max_heap_pointer: 0

  # Compile-time constant for empty page
  @empty_page :binary.copy(<<0>>, page_size())

  # Compile-time zero binaries for common lengths (1-32)
  @zero_binaries (for i <- 1..32, into: %{} do
    {i, :binary.copy(<<0>>, i)}
  end)



  # Fast zero lookup with compile-time binaries
  defp get_zero_binary(length) when length >= 1 and length <= 32 do
    Map.get(@zero_binaries, length)
  end
  defp get_zero_binary(length), do: :binary.copy(<<0>>, length)

  # PUBLIC FUNCTIONS
  def new() do
    table = :ets.new(:memory_data, [:set, :private])
    %__MODULE__{data: table}
  end

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
          data = read_data(memory, wrapped_address, length, start_page, end_page)
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

  def write(%__MODULE__{} = memory, _, <<>>), do: {:ok, memory}

  def write(%__MODULE__{} = memory, address, value) when is_binary(value) do
    wrapped_address = wrap_address(memory, address)

    if wrapped_address < min_allowed_address() do
      {:error, :panic}
    else
      length = byte_size(value)
      {start_page, end_page} = get_page_range(memory, wrapped_address, length)

      case check_permissions(memory, start_page, end_page, :write) do
        :ok ->
          write_data(memory, wrapped_address, value, start_page, end_page)
          {:ok, memory}

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

  ## SET Access functions (unchanged from original)

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
    end_page = max(start_page, rem(start_page + num_pages, total_pages))

    new_ranges =
      RangeManager.add_range(memory.access_ranges, start_page, end_page, access_type)

    %__MODULE__{memory | access_ranges: new_ranges}
  end

  def check_range_access?(%__MODULE__{} = _memory, _, 0, _required_access), do: true

  ## Check Access functions (unchanged from original)
  def check_range_access?(%__MODULE__{} = memory, address, length, required_access) do
    wrapped_address = wrap_address(memory, address)
    {start_page, end_page} = get_page_range(memory, wrapped_address, length)

    check_permissions(memory, start_page, end_page, required_access) == :ok
  end

  def check_pages_access?(%__MODULE__{} = _memory, _start_page, 0, _required_access), do: true

  def check_pages_access?(%__MODULE__{} = memory, start_page, num_pages, required_access) do
    total_pages = number_of_pages(memory)
    start_page = rem(start_page, total_pages)
    end_page = rem(start_page - 1 + num_pages, total_pages)

    check_permissions(memory, start_page, end_page, required_access) == :ok
  end

  ## Private functions - ETS Binary Implementation

  # FAST TRACK: Single page read
  defp read_data(%__MODULE__{data: table, page_size: _page_size} = memory, address, length, start_page, end_page)
       when start_page == end_page do
    {_page_num, page_offset} = page_address(memory, address)

    case :ets.lookup(table, start_page) do
      [] ->
        # Page not allocated, return zeros using optimized function
        read_zeros(length)

      [{^start_page, page_binary}] ->
        read_from_page_binary(page_binary, page_offset, length)
    end
  end

  # Function argument matching for nil vs binary cases
  defp read_from_page_binary(nil, _page_offset, length) do
    read_zeros(length)
  end

  defp read_from_page_binary(page_binary, page_offset, length) when is_binary(page_binary) do
    binary_part(page_binary, page_offset, length)
  end

  # Optimized zero reading with compile-time binaries
  defp read_zeros(length) when length <= 32, do: get_zero_binary(length)
  defp read_zeros(length), do: :binary.copy(<<0>>, length)

  # SLOW TRACK: Multi-page read
  defp read_data(%__MODULE__{} = memory, address, length, _start_page, _end_page) do
    read_from_ets_multi_page(memory, address, length)
  end

  # Multi-page read implementation
  defp read_from_ets_multi_page(%__MODULE__{data: table} = memory, address, length) do
    0..(length - 1)
    |> Enum.map(fn offset ->
      {page_num, page_offset} = page_address(memory, address + offset)

      case :ets.lookup(table, page_num) do
        [] -> 0
        [{^page_num, page_binary}] -> read_byte_from_page_binary(page_binary, page_offset)
      end
    end)
    |> :binary.list_to_bin()
  end

  # Function argument matching for byte reads
  defp read_byte_from_page_binary(nil, _page_offset), do: 0

  defp read_byte_from_page_binary(page_binary, page_offset) when is_binary(page_binary) do
    if page_offset < byte_size(page_binary) do
      :binary.at(page_binary, page_offset)
    else
      0
    end
  end

  # FAST TRACK: Single page write
  defp write_data(%__MODULE__{data: table, page_size: page_size} = memory, address, value, start_page, end_page)
       when start_page == end_page do
    {_page_num, page_offset} = page_address(memory, address)
    value_length = byte_size(value)

    # Get or create the page binary using pattern matching
    page_binary = case :ets.lookup(table, start_page) do
      [] -> @empty_page
      [{^start_page, existing_page}] -> get_page_binary(existing_page)
    end

    # Update the page with new data
    new_page_binary = write_to_page_binary(page_binary, page_offset, value, value_length, page_size)

    # Store the updated page
    :ets.insert(table, {start_page, new_page_binary})
  end

  # Function argument matching for getting page binary
  defp get_page_binary(nil), do: @empty_page
  defp get_page_binary(existing) when is_binary(existing), do: existing

  # Function argument matching for different write scenarios
  defp write_to_page_binary(page_binary, page_offset, value, value_length, page_size) when page_offset + value_length <= page_size do
    # Simple case: write fits entirely within page
    <<prefix::binary-size(page_offset), _::binary-size(value_length), suffix::binary>> = page_binary
    <<prefix::binary, value::binary, suffix::binary>>
  end



  # SLOW TRACK: Multi-page write
  defp write_data(%__MODULE__{} = memory, address, value, _start_page, _end_page) do
    write_to_ets_multi_page(memory, address, value)
  end

  # Multi-page write implementation
  defp write_to_ets_multi_page(%__MODULE__{data: table} = memory, address, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.each(fn {byte_value, index} ->
      byte_address = address + index
      {page_num, page_offset} = page_address(memory, byte_address)

      # Get or create the page binary using pattern matching
      page_binary = case :ets.lookup(table, page_num) do
        [] -> @empty_page
        [{^page_num, existing_page}] -> get_page_binary(existing_page)
      end

      # Update single byte in the page
      new_page_binary = write_byte_to_page_binary(page_binary, page_offset, byte_value)

      # Store the updated page
      :ets.insert(table, {page_num, new_page_binary})
    end)
  end

  # Function for writing a single byte to page binary
  defp write_byte_to_page_binary(page_binary, page_offset, byte_value) do
    <<prefix::binary-size(page_offset), _::8, suffix::binary>> = page_binary
    <<prefix::binary, byte_value::8, suffix::binary>>
  end

  # Permission checking functions (unchanged from original)
  defp check_permissions(_, 0, 0, _), do: :ok

  # Formula (A.9) v0.7.0
  defp check_permissions(memory, start_page, end_page, required_access) do
    if start_page < 16 do
      {:error, start_page * memory.page_size}
    else
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
  end

  def find_access_for_page(access_ranges, page) do
    ranges_tuple = List.to_tuple(access_ranges)
    {_, _, access} =
      RangeManager.binary_search_range(ranges_tuple, page, 0, tuple_size(ranges_tuple) - 1)

    access
  end

  def get_sequential_pages(start_page, end_page, total_pages) do
    if end_page >= start_page do
      start_page..end_page
    else
      Enum.to_list(start_page..(total_pages - 1)) ++ Enum.to_list(0..end_page)
    end
  end

  # Cleanup function
  def cleanup(%__MODULE__{data: table}) do
    :ets.delete(table)
  end
end
