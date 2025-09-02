defmodule PVM.Memory do
  import PVM.Memory.{Constants, Util}
  alias PVM.Memory.RangeManager

  @type t :: %__MODULE__{
          # Page => {Offset => Byte}
          data: %{non_neg_integer() => binary()},
          access_ranges: [{non_neg_integer(), non_neg_integer(), atom()}],
          page_size: pos_integer(),
          size: pos_integer(),
          current_heap_pointer: pos_integer(),
          max_heap_pointer: pos_integer()
        }

  defstruct data: %{},
            access_ranges: [],
            page_size: page_size(),
            size: memory_size(),
            current_heap_pointer: 0,
            max_heap_pointer: 0

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
  defp read_from_sparse(%__MODULE__{data: data, page_size: page_size} = memory, address, length) do
    {start_page, start_offset} = page_address(memory, address)
    end_address = address + length - 1
    {end_page, _end_offset} = page_address(memory, end_address)

    # Get all pages involved in the read
    page_range = get_sequential_pages(start_page, end_page, number_of_pages(memory))
    empty_page = <<0::size(8 * page_size)>>
    # Concatenate all page binaries
    full_binary =
      Enum.reduce(page_range, <<>>, fn page, acc -> acc <> Map.get(data, page, empty_page) end)

    # Extract the requested portion starting from start_offset with the requested length
    binary_part(full_binary, start_offset, length)
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
