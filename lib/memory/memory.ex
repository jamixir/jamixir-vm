defmodule PVM.Memory do
  import PVM.Memory.{Constants, Util}
  alias PVM.Memory.RangeManager
  import Bitwise

  @type t :: %__MODULE__{
          data: :ets.tid() | nil,
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

  # Compile-time zero binaries for common lengths (1-32)
  @zero_binaries for(i <- 1..32, do: :binary.copy(<<0>>, i)) |> List.to_tuple()
  @words_per_page div(@page_size, 8)
  @mask64 0xFFFF_FFFF_FFFF_FFFF
  @signbit64 0x8000_0000_0000_0000
  @wrap64 0x1_0000_0000_0000_0000

  def new, do: %__MODULE__{data: :ets.new(:ets_binary_lazy, [:set, :public])}

  # Fast zero lookup with compile-time binaries
  def get_zero_binary(0), do: <<>>
  def get_zero_binary(length) when length > 32, do: <<0::size(8 * length)>>
  def get_zero_binary(length), do: elem(@zero_binaries, length - 1)

  # PUBLIC FUNCTIONS
  def number_of_pages(%__MODULE__{} = memory)
      when memory.page_size == @page_size and memory.size == @size do
    @number_of_pages
  end

  def number_of_pages(%__MODULE__{} = memory) do
    div(memory.size, memory.page_size)
  end

  ## Read/Write functions

  def read(_, _, 0), do: {:ok, <<>>}

  def read(%{data: nil}, _, length), do: {:ok, get_zero_binary(length)}

  # 1-byte read - fast path (always single page, no page boundary checks needed)
  def read(%__MODULE__{} = memory, address, 1) do
    wrapped_address = wrap_address(memory, address)
    do_read(memory, wrapped_address, 1)
  end

  #  length is always, 2,4,8
  def read(%__MODULE__{} = memory, address, length) do
    wrapped_address = wrap_address(memory, address)
    do_read(memory, wrapped_address, length)
  end

  def read!(%__MODULE__{} = memory, address, length) do
    case read(memory, address, length) do
      {:ok, data} -> data
      {:error, reason} -> raise PVM.MemoryFaultError, reason: reason
    end
  end

  defp do_read(_mem, wrapped_address, _length) when wrapped_address < @min_allowed_address do
    {:error, :panic}
  end

  defp do_read(memory, wrapped_address, 1) do
    {start_page, start_offset} = page_address(wrapped_address)
    single_page_read(memory, start_page, start_offset, 1)
  end

  defp do_read(memory, wrapped_address, length) do
    {start_page, start_offset} = page_address(wrapped_address)
    end_address = wrapped_address + length - 1
    end_page = end_address >>> 12
    do_read_by_page_span(memory, start_page, end_page, start_offset, length)
  end

  defp do_read_by_page_span(memory, page, page, start_offset, length) do
    single_page_read(memory, page, start_offset, length)
  end

  defp do_read_by_page_span(memory, start_page, _end_page, start_offset, length) do
    two_page_read(memory, start_page, start_offset, length)
  end

  def single_page_read(%__MODULE__{} = memory, page, offset, length) do
    case check_single_page_permission(memory, page, :read) do
      :ok -> {:ok, get_page_data(memory.data, page, offset, length)}
      {:error, page_addr} -> {:error, {:fault, page_addr}}
    end
  end

  defp get_page_data(data, page, offset, length) do
    case :ets.lookup(data, page) do
      [] -> get_zero_binary(length)
      [{_, ref}] -> read_from_atomix(ref, offset, length)
    end
  end

  def two_page_read(%__MODULE__{} = memory, start_page, start_offset, length) do
    case check_two_page_permission(memory, start_page, start_page + 1, :read) do
      :ok -> {:ok, get_two_page_data(memory, start_page, start_offset, length)}
      {:error, page_addr} -> {:error, {:fault, page_addr}}
    end
  end

  defp get_two_page_data(%__MODULE__{} = memory, start_page, start_offset, length) do
    bytes_from_first_page = memory.page_size - start_offset
    bytes_from_second_page = length - bytes_from_first_page

    first_page_data = get_page_data(memory.data, start_page, start_offset, bytes_from_first_page)
    second_page_data = get_page_data(memory.data, start_page + 1, 0, bytes_from_second_page)

    first_page_data <> second_page_data
  end

  def write(%__MODULE__{} = memory, _, <<>>), do: {:ok, memory}

  def write(%__MODULE__{data: nil} = memory, address, value) do
    write(%{memory | data: new().data}, address, value)
  end

  def write(%__MODULE__{} = memory, address, value) do
    wrapped_address = wrap_address(memory, address)
    do_write(memory, wrapped_address, value)
  end

  def write!(%__MODULE__{} = memory, address, value) do
    case write(memory, address, value) do
      {:ok, memory} -> memory
      {:error, reason} -> raise PVM.MemoryFaultError, reason: reason
    end
  end

  defp do_write(_memory, wrapped_address, _value) when wrapped_address < @min_allowed_address do
    {:error, :panic}
  end

  defp do_write(memory, wrapped_address, value) when byte_size(value) == 1 do
    {page, offset} = page_address(wrapped_address)
    single_page_write(memory, page, offset, value)
  end

  defp do_write(memory, wrapped_address, value) do
    {start_page, start_offset} = page_address(wrapped_address)
    end_address = wrapped_address + byte_size(value) - 1
    end_page = end_address >>> 12
    do_write_by_page_span(memory, start_page, end_page, start_offset, value)
  end

  defp do_write_by_page_span(memory, page, page, start_offset, value) do
    single_page_write(memory, page, start_offset, value)
  end

  defp do_write_by_page_span(memory, start_page, end_page, start_offset, value)
       when end_page == start_page + 1 do
    two_page_write(memory, start_page, start_offset, value)
  end

  # efficency is less critical here, this is not used by "regular" opcodes (they can only write values of up to 8 bytes)
  #  it is only used by sbrk and by init program
  defp do_write_by_page_span(memory, start_page, end_page, start_offset, value) do
    # Multi-page write: first partial page + full middle pages + last partial page
    bytes_in_first_page = memory.page_size - start_offset
    total_middle_pages = end_page - start_page - 1
    bytes_in_middle_pages = total_middle_pages * memory.page_size
    bytes_in_last_page = byte_size(value) - bytes_in_first_page - bytes_in_middle_pages

    # Split the value into parts
    <<first_part::binary-size(bytes_in_first_page),
      middle_part::binary-size(bytes_in_middle_pages),
      last_part::binary-size(bytes_in_last_page)>> = value

    # Check permissions for all pages first
    case check_multi_page_permission(memory, start_page, end_page, :write) do
      :ok ->
        memory_ =
          write_to_page(memory, start_page, start_offset, first_part)
          |> write_full_pages(start_page + 1, middle_part)
          |> write_to_page(end_page, 0, last_part)

        {:ok, memory_}

      {:error, page_addr} ->
        {:error, {:fault, page_addr}}
    end
  end

  def single_page_write(%__MODULE__{} = memory, page, offset, value) do
    case check_single_page_permission(memory, page, :write) do
      :ok -> {:ok, write_to_page(memory, page, offset, value)}
      {:error, page_addr} -> {:error, {:fault, page_addr}}
    end
  end

  defp two_page_write(%__MODULE__{} = memory, start_page, start_offset, value) do
    case check_two_page_permission(memory, start_page, start_page + 1, :write) do
      :ok ->
        bytes_in_first_page = memory.page_size - start_offset
        bytes_in_second_page = byte_size(value) - bytes_in_first_page

        <<first_part::binary-size(bytes_in_first_page),
          second_part::binary-size(bytes_in_second_page)>> = value

        memory_ =
          write_to_page(memory, start_page, start_offset, first_part)
          |> write_to_page(start_page + 1, 0, second_part)

        {:ok, memory_}

      {:error, page_addr} ->
        {:error, {:fault, page_addr}}
    end
  end

  # Write bytes to a page stored as :atomics; creates the page if missing
  defp write_to_page(%__MODULE__{} = memory, page, offset, value) do
    ref = ensure_page_atomix(memory.data, page)
    write_to_atomix(ref, offset, value)
    memory
  end

  defp write_full_pages(%__MODULE__{} = memory, _start_page, <<>>), do: memory

  defp write_full_pages(%__MODULE__{} = memory, start_page, pages_data) do
    <<page_data::binary-size(memory.page_size), remaining::binary>> = pages_data
    ref = ensure_page_atomix(memory.data, start_page)
    write_full_page_atomix(ref, page_data)
    write_full_pages(memory, start_page + 1, remaining)
  end

  # Check permissions for multiple pages
  defp check_multi_page_permission(memory, start_page, end_page, required_access) do
    page_range = start_page..end_page

    Enum.find_value(page_range, :ok, fn page ->
      case check_single_page_permission(memory, page, required_access) do
        :ok -> nil
        {:error, page_addr} -> {:error, page_addr}
      end
    end)
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

  defp check_single_page_permission(memory, page, :read) do
    case find_access_for_page(memory.access_ranges, page) do
      access when access == :read or access == :write -> :ok
      _ -> {:error, page * memory.page_size}
    end
  end

  defp check_single_page_permission(memory, page, :write) do
    case find_access_for_page(memory.access_ranges, page) do
      :write -> :ok
      _ -> {:error, page * memory.page_size}
    end
  end

  def check_two_page_permission(memory, start_page, end_page, required_access) do
    with :ok <- check_single_page_permission(memory, start_page, required_access),
         :ok <- check_single_page_permission(memory, end_page, required_access) do
      :ok
    else
      {:error, page_addr} -> {:error, page_addr}
    end
  end

  def check_pages_access?(%__MODULE__{} = _memory, _start_page, 0, _required_access), do: true

  def check_pages_access?(%__MODULE__{} = memory, start_page, num_pages, required_access) do
    total_pages = number_of_pages(memory)
    start_page = rem(start_page, total_pages)
    end_page = rem(start_page - 1 + num_pages, total_pages)

    check_permissions(memory, start_page, end_page, required_access) == :ok
  end

  ## Private functions

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

  ## Internal helpers: atomics-backed pages

  # Ensure a page exists as :atomics in ETS and return its ref
  defp ensure_page_atomix(ets, page) do
    case :ets.lookup(ets, page) do
      [{_, ref}] ->
        ref

      [] ->
        ref = :atomics.new(@words_per_page, [])
        :ets.insert(ets, {page, ref})
        ref
    end
  end

  # Read `length` bytes starting from `offset` from a page atomics (64-bit words)
  defp read_from_atomix(ref, offset, length) do
    start_word = div(offset, 8) + 1
    start_in_word = offset &&& 7
    last_word = div(offset + length - 1, 8) + 1

    # Read each required 64-bit word once
    iodata =
      for i <- start_word..last_word do
        w = :atomics.get(ref, i) &&& @mask64
        <<w::little-unsigned-integer-size(64)>>
      end

    big = :erlang.iolist_to_binary(iodata)
    <<_skip::binary-size(start_in_word), needed::binary-size(length), _::binary>> = big
    needed
  end

  # Write bytes into the :atomics page at offset (64-bit words), minimizing get/put
  defp write_to_atomix(ref, offset, value) do
    len = byte_size(value)
    start_word = div(offset, 8) + 1
    start_in_word = offset &&& 7

    # Single word fast path
    if start_in_word + len <= 8 do
      <<ival::little-unsigned-integer-size(len * 8)>> = value
      word = :atomics.get(ref, start_word) &&& @mask64
      shift = start_in_word * 8
      mask = ((1 <<< (len * 8)) - 1) <<< shift
      new_word = (word &&& bnot(mask)) ||| ival <<< shift
      :atomics.put(ref, start_word, to_signed64(new_word))
      :ok
    else
      # First partial
      bytes_in_first = 8 - start_in_word
      <<first::binary-size(bytes_in_first), rest::binary>> = value
      <<first_val::little-unsigned-integer-size(bytes_in_first * 8)>> = first
      word0 = :atomics.get(ref, start_word) &&& @mask64
      shift0 = start_in_word * 8
      mask0 = ((1 <<< (bytes_in_first * 8)) - 1) <<< shift0
      new0 = (word0 &&& bnot(mask0)) ||| first_val <<< shift0
      :atomics.put(ref, start_word, to_signed64(new0))

      # Middle full words
      full_words = div(byte_size(rest), 8)
      rem_tail = rem(byte_size(rest), 8)

      if full_words > 0 do
        write_full_words(ref, start_word + 1, rest, full_words)
      end

      # Last partial
      if rem_tail > 0 do
        base = full_words * 8
        <<_::binary-size(base), last::binary-size(rem_tail)>> = rest
        <<last_val::little-unsigned-integer-size(rem_tail * 8)>> = last
        last_word = :atomics.get(ref, start_word + full_words + 1) &&& @mask64
        mask_last = (1 <<< (rem_tail * 8)) - 1
        new_last = (last_word &&& bnot(mask_last)) ||| last_val
        :atomics.put(ref, start_word + full_words + 1, to_signed64(new_last))
      end

      :ok
    end
  end

  # Write a full 4096-byte page into atomics efficiently word-by-word (little-endian 8 bytes per word)
  defp write_full_page_atomix(ref, page_binary) do
    write_words_stream(ref, 1, page_binary)
  end

  defp write_words_stream(_ref, _idx, <<>>), do: :ok

  defp write_words_stream(ref, idx, <<w::little-unsigned-integer-size(64), rest::binary>>) do
    :atomics.put(ref, idx, to_signed64(w))
    write_words_stream(ref, idx + 1, rest)
  end

  defp write_full_words(ref, start_idx, bin, count) do
    write_full_words(ref, start_idx, bin, 0, count)
  end

  defp write_full_words(_ref, _idx, _bin, i, count) when i >= count, do: :ok

  defp write_full_words(ref, idx, <<w::little-unsigned-integer-size(64), rest::binary>>, i, count) do
    :atomics.put(ref, idx, to_signed64(w))
    write_full_words(ref, idx + 1, rest, i + 1, count)
  end

  defp to_signed64(n) do
    n = n &&& @mask64
    if n >= @signbit64, do: n - @wrap64, else: n
  end
end
