defmodule PVM.Memory do
  import PVM.Memory.{Constants, Util}
  alias PVM.Memory.RangeManager
  import Bitwise, only: [ >>>: 2 ]

  @type t :: %__MODULE__{
          # Page => {Offset => Byte}
          data: any(),
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


  @page_size page_size()
  @size memory_size()
  @number_of_pages @size >>> 12
  @min_allowed_address min_allowed_address()

  @empty_page :binary.copy(<<0>>, @page_size)



  # Compile-time zero binaries for common lengths (1-32)
  @zero_binaries (for i <- 1..32, into: %{} do
    {i, :binary.copy(<<0>>, i)}
  end)

  # Fast zero lookup with compile-time binaries
  def get_zero_binary(length) when length >= 1 and length <= 32 do
  Map.get(@zero_binaries, length)
  end

  def get_zero_binary(length), do: :binary.copy(<<0>>, length)


  # PUBLIC FUNCTIONS
  def number_of_pages(%__MODULE__{} = memory) when memory.page_size == @page_size and memory.size == @size do
    @number_of_pages
  end

  def number_of_pages(%__MODULE__{} = memory) do
    div(memory.size, memory.page_size)
  end

  ## Read/Write functions

  def read(_, _, 0), do: {:ok, <<>>}

  def read(%{data: nil}, _, length), do: {:ok, get_zero_binary(length)}

  def read(%__MODULE__{} = memory, address, length) do
    wrapped_address = wrap_address(memory, address)

    if wrapped_address < @min_allowed_address do
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

  def write(%__MODULE__{} = memory, _, <<>>), do: {:ok, memory}

  def write(%__MODULE__{} = memory, address, value) do
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
    end_page = max(start_page, rem(start_page + num_pages, total_pages))

    new_ranges =
      RangeManager.add_range(memory.access_ranges, start_page, end_page, access_type)

    %__MODULE__{memory | access_ranges: new_ranges}
  end

  def check_range_access?(%__MODULE__{} = _memory, _, 0, _required_access), do: true

  ## Check Access functions
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


  ## Private functions


  defp read_from_sparse(%__MODULE__{data: _data} = memory, address, length) do
    {start_page, start_offset} = page_address(memory, address)
    end_address = address + length - 1
    {end_page, _end_offset} = page_address(memory, end_address)


    do_read(memory, start_page, end_page, start_offset, length)
  end

# Single page read
  defp do_read(memory, start_page, end_page, start_offset, length) when start_page == end_page do
    case :ets.lookup(memory.data, start_page) do
      [] -> get_zero_binary(length)
      [{_, v}] -> binary_part(v, start_offset, length)
    end
  end

  # Two page read
  defp do_read(%{data: data, page_size: page_size} = memory, start_page, end_page, start_offset, length)
       when end_page == start_page + 1 do

    bytes_from_first_page = page_size - start_offset
    bytes_from_second_page = length - bytes_from_first_page

    # Get first page data
    first_page_data = case :ets.lookup(data, start_page) do
      [] -> get_zero_binary(bytes_from_first_page)
      [{_, v}] -> binary_part(v, start_offset, bytes_from_first_page)
    end

    # Get second page data
    second_page_data = case :ets.lookup(data, end_page) do
      [] -> get_zero_binary(bytes_from_second_page)
      [{_, v}] -> binary_part(v, 0, bytes_from_second_page)
    end

      # Combine them
      first_page_data <> second_page_data
  end

  # SLOW TRACK: Multi-page read - uses efficient whole page reads where possible
  # defp do_read(%{data: data, page_size: page_size} = memory, start_page, end_page, start_offset, length) do
  #   page_range = get_sequential_pages(start_page, end_page, number_of_pages(memory))

  #   {first_page | middle_pages_and_last} = page_range
  #   {middle_pages, [last_page]} = Enum.split(middle_pages_and_last, -1)

  #   # Handle first page (partial read from start_offset)
  #   first_page_data = get_page_data(data, first_page)
  #   first_page_bytes_needed = page_size - start_offset
  #   first_part = binary_part(first_page_data, start_offset, min(first_page_bytes_needed, length))

  #   remaining_length = length - byte_size(first_part)

  #   cond do
  #     # If we got everything from the first page
  #     remaining_length <= 0 ->
  #       first_part

  #     # If we have middle pages, read them whole + handle last page
  #     length(middle_pages) > 0 ->
  #       # Read all middle pages as whole pages (most efficient)
  #       middle_parts = Enum.map(middle_pages, &get_whole_page(data, &1))
  #       middle_binary = :erlang.iolist_to_binary(middle_parts)

  #       remaining_after_middle = remaining_length - byte_size(middle_binary)

  #       if remaining_after_middle > 0 do
  #         # Need bytes from last page
  #         last_page_data = get_page_data(data, last_page)
  #         last_part = binary_part(last_page_data, 0, remaining_after_middle)
  #         <<first_part::binary, middle_binary::binary, last_part::binary>>
  #       else
  #         # Middle pages provided enough
  #         needed_from_middle = remaining_length
  #         middle_part = binary_part(middle_binary, 0, needed_from_middle)
  #         <<first_part::binary, middle_part::binary>>
  #       end

  #     # No middle pages, just first and last
  #     true ->
  #       last_page_data = get_page_data(data, last_page)
  #       last_part = binary_part(last_page_data, 0, remaining_length)
  #       <<first_part::binary, last_part::binary>>
  #   end
  # end

  # Fast function to get whole page data (returns full page binary)
  defp get_whole_page(data, page_num) do
    case :ets.lookup(data, page_num) do
      [] -> @empty_page
      [{_, v}] -> v
    end
  end


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
end
