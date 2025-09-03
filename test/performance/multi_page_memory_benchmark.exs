defmodule MultiPageMemoryBenchmark do
  import Bitwise
  @moduledoc """
  Benchee test comparing multi-page memory structures:
  Tests memory systems with 1,024 pages (4MB total) using different data structures:
  1. Map pages: %{page_num => %{offset => byte_value}}
  2. Binary pages (pre-allocated): %{page_num => <<4096-byte binary>>}
  3. Binary pages (lazy): %{page_num => binary | nil} - allocate on first write
  4. Atomics pages: %{page_num => :atomics.array()}
  5. Single Atomics: One :atomics.array() of size 4,194,304 (1 byte per atomic)
  6. Packed Atomics: One :atomics.array() of size 524,288 (8 bytes per atomic)

  This mirrors the real PVM.Memory structure more accurately.
  """

  @page_size 4096
  @num_pages 2048  # 4MB total memory (1,024 * 4KB)
  @read_percentage 0.569
  @write_percentage 0.431
  @avg_bytes_per_op 6.7

  # Compile-time constant for empty page (4096 zeros)
  @empty_page :binary.copy(<<0>>, @page_size)

  # BEAM VM word size detection (64-bit = 8 bytes per atomic)
  @word_size_bits :erlang.system_info(:wordsize) * 8
  @bytes_per_word :erlang.system_info(:wordsize)

  # Generate test data across multiple pages
  def generate_multi_page_operations(count) do
    read_count = round(count * @read_percentage)
    write_count = count - read_count

    reads =
      for _ <- 1..read_count do
        page = :rand.uniform(@num_pages) - 1
        offset = :rand.uniform(@page_size) - 1
        length = max(1, round(:rand.uniform(12) + 1))  # 1-13 bytes, avg ~7
        {:read, page, offset, length}
      end

    writes =
      for _ <- 1..write_count do
        page = :rand.uniform(@num_pages) - 1
        offset = :rand.uniform(@page_size) - 1
        length = max(1, round(:rand.uniform(12) + 1))  # 1-13 bytes, avg ~7
        data = :crypto.strong_rand_bytes(length)
        {:write, page, offset, data}
      end

    (reads ++ writes) |> Enum.shuffle()
  end

  # =============================================================================
  # MULTI-PAGE MAP IMPLEMENTATION (Current PVM.Memory style)
  # =============================================================================

  def create_map_memory() do
    # Start with empty structure: %{page_num => %{offset => byte}}
    %{}
  end

  def map_read(memory, page_num, offset, length) do
    page = Map.get(memory, page_num, %{})
    for i <- 0..(length - 1) do
      Map.get(page, offset + i, 0)
    end
    |> :binary.list_to_bin()
  end

  def map_write(memory, page_num, offset, data) do
    page = Map.get(memory, page_num, %{})

    updated_page =
      data
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.reduce(page, fn {byte, i}, acc ->
        Map.put(acc, offset + i, byte)
      end)

    Map.put(memory, page_num, updated_page)
  end

  def run_map_memory_operations(operations) do
    Enum.reduce(operations, create_map_memory(), fn op, memory ->
      case op do
        {:read, page, offset, length} ->
          _result = map_read(memory, page, offset, length)
          memory
        {:write, page, offset, data} ->
          map_write(memory, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # MULTI-PAGE BINARY IMPLEMENTATION
  # =============================================================================

  def create_binary_memory() do
    # Pre-create all pages as zero-filled binaries: %{page_num => binary}
    for page <- 0..(@num_pages - 1), into: %{} do
      {page, :binary.copy(<<0>>, @page_size)}
    end
  end

  def binary_read(memory, page_num, offset, length) do
    case Map.get(memory, page_num) do
      nil -> :binary.copy(<<0>>, length)
      page_binary ->
        safe_offset = min(offset, @page_size - 1)
        safe_length = min(length, @page_size - safe_offset)
        binary_part(page_binary, safe_offset, safe_length)
    end
  end

  def binary_write(memory, page_num, offset, data) when byte_size(data) > 0 do
    page_binary = Map.get(memory, page_num, :binary.copy(<<0>>, @page_size))
    data_size = byte_size(data)
    safe_offset = min(offset, @page_size - 1)
    safe_length = min(data_size, @page_size - safe_offset)

    if safe_length > 0 and safe_offset >= 0 do
      <<before::binary-size(safe_offset), _::binary-size(safe_length), rest::binary>> = page_binary
      safe_data = binary_part(data, 0, safe_length)
      updated_page = <<before::binary, safe_data::binary, rest::binary>>
      Map.put(memory, page_num, updated_page)
    else
      memory
    end
  end

  def binary_write(memory, _page_num, _offset, <<>>), do: memory

  def run_binary_memory_operations(operations) do
    Enum.reduce(operations, create_binary_memory(), fn op, memory ->
      case op do
        {:read, page, offset, length} ->
          _result = binary_read(memory, page, offset, length)
          memory
        {:write, page, offset, data} ->
          binary_write(memory, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # LAZY BINARY PAGES IMPLEMENTATION (Allocate on first write)
  # =============================================================================

  def create_lazy_binary_memory() do
    # Start with empty map: %{page_num => binary | nil}
    # Pages are nil until first write
    %{}
  end

  def lazy_binary_read(memory, page_num, offset, length) do
    case Map.get(memory, page_num) do
      nil ->
        # Return zeros for unallocated page using compile-time constant
        safe_offset = min(offset, @page_size - 1)
        safe_length = min(length, @page_size - safe_offset)
        binary_part(@empty_page, safe_offset, safe_length)
      page_binary ->
        safe_offset = min(offset, @page_size - 1)
        safe_length = min(length, @page_size - safe_offset)
        binary_part(page_binary, safe_offset, safe_length)
    end
  end

  def lazy_binary_write(memory, page_num, offset, data) when byte_size(data) > 0 do
    # Get existing page or create new one from empty template
    page_binary = Map.get(memory, page_num, @empty_page)

    data_size = byte_size(data)
    safe_offset = min(offset, @page_size - 1)
    safe_length = min(data_size, @page_size - safe_offset)

    if safe_length > 0 and safe_offset >= 0 do
      <<before::binary-size(safe_offset), _::binary-size(safe_length), rest::binary>> = page_binary
      safe_data = binary_part(data, 0, safe_length)
      updated_page = <<before::binary, safe_data::binary, rest::binary>>
      Map.put(memory, page_num, updated_page)
    else
      memory
    end
  end

  def lazy_binary_write(memory, _page_num, _offset, <<>>), do: memory

  def run_lazy_binary_memory_operations(operations) do
    Enum.reduce(operations, create_lazy_binary_memory(), fn op, memory ->
      case op do
        {:read, page, offset, length} ->
          _result = lazy_binary_read(memory, page, offset, length)
          memory
        {:write, page, offset, data} ->
          lazy_binary_write(memory, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # MULTI-PAGE ATOMICS IMPLEMENTATION
  # =============================================================================

  def create_atomics_memory() do
    # Pre-create all pages as atomics arrays: %{page_num => atomics}
    for page <- 0..(@num_pages - 1), into: %{} do
      {page, :atomics.new(@page_size, [])}
    end
  end

  def atomics_read(memory, page_num, offset, length) do
    case Map.get(memory, page_num) do
      nil -> :binary.copy(<<0>>, length)
      atomics ->
        for i <- 0..(length - 1) do
          pos = min(offset + i + 1, @page_size)  # atomics is 1-indexed
          :atomics.get(atomics, pos)
        end
        |> :binary.list_to_bin()
    end
  end

  def atomics_write(memory, page_num, offset, data) do
    atomics = Map.get(memory, page_num, :atomics.new(@page_size, []))

    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.each(fn {byte, i} ->
      pos = min(offset + i + 1, @page_size)  # atomics is 1-indexed
      :atomics.put(atomics, pos, byte)
    end)

    Map.put(memory, page_num, atomics)
  end

  def run_atomics_memory_operations(operations) do
    Enum.reduce(operations, create_atomics_memory(), fn op, memory ->
      case op do
        {:read, page, offset, length} ->
          _result = atomics_read(memory, page, offset, length)
          memory
        {:write, page, offset, data} ->
          atomics_write(memory, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # SINGLE LARGE ATOMICS IMPLEMENTATION (NO MAP OVERHEAD)
  # =============================================================================

  def create_single_atomics_memory() do
    # Single atomics array covering entire memory space: 50 * 4096 = 204,800 elements
    total_elements = @num_pages * @page_size
    :atomics.new(total_elements, [])
  end

  def single_atomics_read(atomics, page_num, offset, length) do
    base_addr = page_num * @page_size + offset
    for i <- 0..(length - 1) do
      pos = base_addr + i + 1  # atomics is 1-indexed
      if pos <= @num_pages * @page_size do
        :atomics.get(atomics, pos)
      else
        0  # Beyond memory bounds
      end
    end
    |> :binary.list_to_bin()
  end

  def single_atomics_write(atomics, page_num, offset, data) do
    base_addr = page_num * @page_size + offset

    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.each(fn {byte, i} ->
      pos = base_addr + i + 1  # atomics is 1-indexed
      if pos <= @num_pages * @page_size do
        :atomics.put(atomics, pos, byte)
      end
    end)

    atomics
  end

  def run_single_atomics_memory_operations(operations) do
    Enum.reduce(operations, create_single_atomics_memory(), fn op, atomics ->
      case op do
        {:read, page, offset, length} ->
          _result = single_atomics_read(atomics, page, offset, length)
          atomics
        {:write, page, offset, data} ->
          single_atomics_write(atomics, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # PACKED ATOMICS IMPLEMENTATION (Multiple bytes per atomic word)
  # =============================================================================

  def create_packed_atomics_memory() do
    # Calculate how many atomics we need: total_bytes ÷ bytes_per_word
    total_bytes = @num_pages * @page_size
    num_atomics = div(total_bytes + @bytes_per_word - 1, @bytes_per_word)  # Ceiling division
    :atomics.new(num_atomics, [])
  end

  def packed_atomics_read(atomics, page_num, offset, length) do
    base_addr = page_num * @page_size + offset
    packed_atomics_read_chunk(atomics, base_addr, length, [])
  end

  # Fast path: read complete atomic words when possible
  defp packed_atomics_read_chunk(atomics, base_addr, length, acc) when length >= @bytes_per_word do
    atomic_index = div(base_addr, @bytes_per_word) + 1
    byte_position = rem(base_addr, @bytes_per_word)

    if byte_position == 0 and atomic_index <= :atomics.info(atomics).size do
      # Fast path: aligned read of complete atomic
      atomic_value = :atomics.get(atomics, atomic_index)
      bytes = atomic_to_bytes(atomic_value, @bytes_per_word)
      packed_atomics_read_chunk(atomics, base_addr + @bytes_per_word, length - @bytes_per_word, [bytes | acc])
    else
      # Slow path: unaligned or partial read
      packed_atomics_read_slow(atomics, base_addr, length, acc)
    end
  end

  # Handle remaining bytes (< @bytes_per_word)
  defp packed_atomics_read_chunk(atomics, base_addr, length, acc) when length > 0 do
    atomic_index = div(base_addr, @bytes_per_word) + 1
    byte_position = rem(base_addr, @bytes_per_word)

    if atomic_index <= :atomics.info(atomics).size do
      atomic_value = :atomics.get(atomics, atomic_index)
      bytes = extract_bytes_from_atomic(atomic_value, byte_position, length)
      [bytes | acc]
    else
      [:binary.copy(<<0>>, length) | acc]
    end
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  # Base case: no more bytes to read
  defp packed_atomics_read_chunk(_atomics, _base_addr, 0, acc) do
    acc |> Enum.reverse() |> :binary.list_to_bin()
  end

  # Optimized slow path for unaligned reads - read multiple bytes per atomic
  defp packed_atomics_read_slow(atomics, base_addr, length, acc) do
    bytes = packed_atomics_read_by_atomic(atomics, base_addr, length, [])
    [bytes | acc] |> Enum.reverse() |> :binary.list_to_bin()
  end

  # Read bytes grouped by atomic to minimize :atomics.get calls
  defp packed_atomics_read_by_atomic(_atomics, _base_addr, 0, acc) do
    acc |> Enum.reverse() |> :binary.list_to_bin()
  end

  defp packed_atomics_read_by_atomic(atomics, base_addr, remaining_length, acc) do
    atomic_index = div(base_addr, @bytes_per_word) + 1
    byte_position = rem(base_addr, @bytes_per_word)

    # How many bytes can we read from this atomic?
    bytes_in_this_atomic = min(remaining_length, @bytes_per_word - byte_position)

    if atomic_index <= :atomics.info(atomics).size do
      atomic_value = :atomics.get(atomics, atomic_index)
      bytes = extract_bytes_from_atomic(atomic_value, byte_position, bytes_in_this_atomic)
      packed_atomics_read_by_atomic(atomics, base_addr + bytes_in_this_atomic,
                                   remaining_length - bytes_in_this_atomic, [bytes | acc])
    else
      # Beyond bounds, return zeros
      zeros = :binary.copy(<<0>>, remaining_length)
      [zeros | acc] |> Enum.reverse() |> :binary.list_to_bin()
    end
  end

  # Convert atomic value to bytes (little-endian)
  defp atomic_to_bytes(atomic_value, num_bytes) do
    for i <- 0..(num_bytes - 1) do
      (atomic_value >>> (i * 8)) &&& 0xFF
    end
    |> :binary.list_to_bin()
  end

  # Extract specific bytes from atomic value
  defp extract_bytes_from_atomic(atomic_value, start_pos, length) do
    for i <- 0..(length - 1) do
      bit_shift = (start_pos + i) * 8
      (atomic_value >>> bit_shift) &&& 0xFF
    end
    |> :binary.list_to_bin()
  end

  def packed_atomics_write(atomics, page_num, offset, data) do
    base_addr = page_num * @page_size + offset
    packed_atomics_write_chunk(atomics, base_addr, data)
    atomics
  end

  # Fast path: write complete atomic words when possible
  defp packed_atomics_write_chunk(atomics, base_addr, data) when byte_size(data) >= @bytes_per_word do
    max_addr = @num_pages * @page_size - 1

    if base_addr > max_addr do
      # Beyond memory bounds, stop
      :ok
    else
      atomic_index = div(base_addr, @bytes_per_word) + 1
      byte_position = rem(base_addr, @bytes_per_word)

      if byte_position == 0 and atomic_index <= :atomics.info(atomics).size do
        # Fast path: aligned write of complete atomic
        <<atomic_bytes::binary-size(@bytes_per_word), rest::binary>> = data
        atomic_value = bytes_to_atomic(atomic_bytes)
        :atomics.put(atomics, atomic_index, atomic_value)
        packed_atomics_write_chunk(atomics, base_addr + @bytes_per_word, rest)
      else
        # Slow path: unaligned write
        packed_atomics_write_slow(atomics, base_addr, data)
      end
    end
  end

  # Handle remaining bytes (< @bytes_per_word)
  defp packed_atomics_write_chunk(atomics, base_addr, data) when byte_size(data) > 0 do
    max_addr = @num_pages * @page_size - 1

    if base_addr > max_addr do
      # Beyond memory bounds, stop
      :ok
    else
      atomic_index = div(base_addr, @bytes_per_word) + 1
      byte_position = rem(base_addr, @bytes_per_word)

      if atomic_index <= :atomics.info(atomics).size do
        current_value = :atomics.get(atomics, atomic_index)
        # Truncate data if it goes beyond memory bounds
        safe_length = min(byte_size(data), max_addr - base_addr + 1)
        safe_data = binary_part(data, 0, safe_length)
        new_value = write_bytes_to_atomic(current_value, safe_data, byte_position)
        :atomics.put(atomics, atomic_index, new_value)
      end
    end
  end

  # Base case: no more data to write
  defp packed_atomics_write_chunk(_atomics, _base_addr, <<>>), do: :ok

  # Optimized slow path for unaligned writes - write multiple bytes per atomic
  defp packed_atomics_write_slow(atomics, base_addr, data) do
    max_addr = @num_pages * @page_size - 1
    packed_atomics_write_by_atomic(atomics, base_addr, data, max_addr)
  end

  # Write bytes grouped by atomic to minimize :atomics.get/:atomics.put calls
  defp packed_atomics_write_by_atomic(_atomics, _base_addr, <<>>, _max_addr), do: :ok

  defp packed_atomics_write_by_atomic(atomics, base_addr, data, max_addr) when base_addr <= max_addr do
    atomic_index = div(base_addr, @bytes_per_word) + 1
    byte_position = rem(base_addr, @bytes_per_word)

    # How many bytes can we write to this atomic?
    bytes_in_this_atomic = min(byte_size(data), @bytes_per_word - byte_position)
    bytes_in_this_atomic = min(bytes_in_this_atomic, max_addr - base_addr + 1)

    if atomic_index <= :atomics.info(atomics).size and bytes_in_this_atomic > 0 do
      <<chunk::binary-size(bytes_in_this_atomic), rest::binary>> = data

      # Read-modify-write the atomic
      current_value = :atomics.get(atomics, atomic_index)
      new_value = write_bytes_to_atomic(current_value, chunk, byte_position)

      # Keep within signed 64-bit range for atomics
      final_value = new_value &&& 0xFFFFFFFFFFFFFFFF |> to_signed_64()
      :atomics.put(atomics, atomic_index, final_value)
      packed_atomics_write_by_atomic(atomics, base_addr + bytes_in_this_atomic, rest, max_addr)
    end
  end

  defp packed_atomics_write_by_atomic(_atomics, _base_addr, _data, _max_addr), do: :ok

  # Convert unsigned 64-bit to signed 64-bit for atomics
  defp to_signed_64(value) when value > 0x7FFFFFFFFFFFFFFF do
    value - 0x10000000000000000
  end
  defp to_signed_64(value), do: value

  # Convert bytes to atomic value (little-endian) - keep within 64-bit range
  defp bytes_to_atomic(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {byte, i}, acc ->
      acc ||| (byte <<< (i * 8))
    end)
    |> (&(&1 &&& 0xFFFFFFFFFFFFFFFF)).()
    |> to_signed_64()
  end

  # Write bytes to specific position in atomic value
  defp write_bytes_to_atomic(current_value, data, start_pos) do
    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(current_value, fn {byte_value, i}, acc ->
      bit_shift = (start_pos + i) * 8
      byte_mask = 0xFF <<< bit_shift
      (acc &&& ~~~byte_mask) ||| (byte_value <<< bit_shift)
    end)
    |> (&(&1 &&& 0xFFFFFFFFFFFFFFFF)).()
    |> to_signed_64()
  end

  def run_packed_atomics_memory_operations(operations) do
    Enum.reduce(operations, create_packed_atomics_memory(), fn op, atomics ->
      case op do
        {:read, page, offset, length} ->
          _result = packed_atomics_read(atomics, page, offset, length)
          atomics
        {:write, page, offset, data} ->
          packed_atomics_write(atomics, page, offset, data)
      end
    end)
  end

  # =============================================================================
  # ETS-BASED IMPLEMENTATIONS (O(1) lookup, no GC pressure)
  # =============================================================================

  # ETS Binary Lazy - Store {page_num, binary | nil} in ETS table
  def create_ets_binary_lazy_memory() do
    table = :ets.new(:ets_binary_lazy, [:set, :public])
    # Start empty - pages allocated on first write
    table
  end

  def ets_binary_lazy_read(table, page_num, offset, length) do
    case :ets.lookup(table, page_num) do
      [] ->
        # Unallocated page - return zeros from compile-time constant
        safe_offset = min(offset, @page_size - 1)
        safe_length = min(length, @page_size - safe_offset)
        binary_part(@empty_page, safe_offset, safe_length)
      [{^page_num, page_binary}] ->
        safe_offset = min(offset, @page_size - 1)
        safe_length = min(length, @page_size - safe_offset)
        binary_part(page_binary, safe_offset, safe_length)
    end
  end

  def ets_binary_lazy_write(table, page_num, offset, data) when byte_size(data) > 0 do
    # Get existing page or create from empty template
    page_binary = case :ets.lookup(table, page_num) do
      [] -> @empty_page
      [{^page_num, existing}] -> existing
    end

    data_size = byte_size(data)
    safe_offset = min(offset, @page_size - 1)
    safe_length = min(data_size, @page_size - safe_offset)

    if safe_length > 0 and safe_offset >= 0 do
      <<before::binary-size(safe_offset), _::binary-size(safe_length), rest::binary>> = page_binary
      safe_data = binary_part(data, 0, safe_length)
      updated_page = <<before::binary, safe_data::binary, rest::binary>>
      :ets.insert(table, {page_num, updated_page})
    end

    table
  end

  def ets_binary_lazy_write(table, _page_num, _offset, <<>>), do: table

  def run_ets_binary_lazy_operations(operations) do
    table = create_ets_binary_lazy_memory()
    Enum.reduce(operations, table, fn op, table ->
      case op do
        {:read, page, offset, length} ->
          _result = ets_binary_lazy_read(table, page, offset, length)
          table
        {:write, page, offset, data} ->
          ets_binary_lazy_write(table, page, offset, data)
      end
    end)
    # Clean up
    :ets.delete(table)
    table
  end

  # ETS Map Sparse - Store {page_num, %{offset => byte}} in ETS table
  def create_ets_map_sparse_memory() do
    table = :ets.new(:ets_map_sparse, [:set, :public])
    # Start empty - pages/offsets allocated on first write
    table
  end

  def ets_map_sparse_read(table, page_num, offset, length) do
    page_map = case :ets.lookup(table, page_num) do
      [] -> %{}
      [{^page_num, page_data}] -> page_data
    end

    for i <- 0..(length - 1) do
      Map.get(page_map, offset + i, 0)
    end
    |> :binary.list_to_bin()
  end

  def ets_map_sparse_write(table, page_num, offset, data) do
    # Get existing page map or start with empty
    page_map = case :ets.lookup(table, page_num) do
      [] -> %{}
      [{^page_num, existing}] -> existing
    end

    updated_page =
      data
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.reduce(page_map, fn {byte, i}, acc ->
        Map.put(acc, offset + i, byte)
      end)

    :ets.insert(table, {page_num, updated_page})
    table
  end

  def run_ets_map_sparse_operations(operations) do
    table = create_ets_map_sparse_memory()
    Enum.reduce(operations, table, fn op, table ->
      case op do
        {:read, page, offset, length} ->
          _result = ets_map_sparse_read(table, page, offset, length)
          table
        {:write, page, offset, data} ->
          ets_map_sparse_write(table, page, offset, data)
      end
    end)
    # Clean up
    :ets.delete(table)
    table
  end

  # ETS Lazy Atomics - Store {page_num, :atomics.array() | nil} in ETS table
  def create_ets_lazy_atomics_memory() do
    table = :ets.new(:ets_lazy_atomics, [:set, :public])
    # Start empty - atomics arrays allocated on first write
    table
  end

  def ets_lazy_atomics_read(table, page_num, offset, length) do
    case :ets.lookup(table, page_num) do
      [] ->
        # Unallocated page - return zeros
        :binary.copy(<<0>>, length)
      [{^page_num, atomics}] ->
        for i <- 0..(length - 1) do
          pos = min(offset + i + 1, @page_size)  # atomics is 1-indexed
          :atomics.get(atomics, pos)
        end
        |> :binary.list_to_bin()
    end
  end

  def ets_lazy_atomics_write(table, page_num, offset, data) do
    # Get existing atomics or create new one
    atomics = case :ets.lookup(table, page_num) do
      [] ->
        new_atomics = :atomics.new(@page_size, [])
        :ets.insert(table, {page_num, new_atomics})
        new_atomics
      [{^page_num, existing}] ->
        existing
    end

    # Write data to atomics
    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.each(fn {byte, i} ->
      pos = min(offset + i + 1, @page_size)  # atomics is 1-indexed
      :atomics.put(atomics, pos, byte)
    end)

    table
  end

  def run_ets_lazy_atomics_operations(operations) do
    table = create_ets_lazy_atomics_memory()
    Enum.reduce(operations, table, fn op, table ->
      case op do
        {:read, page, offset, length} ->
          _result = ets_lazy_atomics_read(table, page, offset, length)
          table
        {:write, page, offset, data} ->
          ets_lazy_atomics_write(table, page, offset, data)
      end
    end)
    # Clean up
    :ets.delete(table)
    table
  end

  # ETS Atomics Lazy - Store {page_num, :atomics.array() | nil} in ETS table
  # Similar to ets_binary_lazy but with atomics instead of binaries
  def create_ets_atomics_lazy_memory() do
    :ets.new(:ets_atomics_lazy, [:set, :public])
  end

  def ets_atomics_lazy_read(table, page_num, offset, length) do
    case :ets.lookup(table, page_num) do
      [] ->
        # Unallocated page - return zeros
        :binary.copy(<<0>>, length)
      [{^page_num, atomics}] ->
        for i <- 0..(length - 1) do
          pos = offset + i + 1  # atomics is 1-indexed
          if pos <= @page_size do
            :atomics.get(atomics, pos)
          else
            0
          end
        end
        |> :binary.list_to_bin()
    end
  end

  def ets_atomics_lazy_write(table, page_num, offset, data) when byte_size(data) > 0 do
    # Get existing atomics or create new one on first write
    atomics = case :ets.lookup(table, page_num) do
      [] ->
        # First write to this page - create atomics array
        new_atomics = :atomics.new(@page_size, [])
        :ets.insert(table, {page_num, new_atomics})
        new_atomics
      [{^page_num, existing}] ->
        existing
    end

    # Write data to atomics
    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.each(fn {byte_value, i} ->
      pos = offset + i + 1  # atomics is 1-indexed
      if pos <= @page_size do
        :atomics.put(atomics, pos, byte_value)
      end
    end)

    table
  end

  def ets_atomics_lazy_write(table, _page_num, _offset, <<>>), do: table

  def run_ets_atomics_lazy_operations(operations) do
    table = create_ets_atomics_lazy_memory()

    result = Enum.reduce(operations, table, fn op, table ->
      case op do
        {:read, page, offset, length} ->
          _result = ets_atomics_lazy_read(table, page, offset, length)
          table
        {:write, page, offset, data} ->
          ets_atomics_lazy_write(table, page, offset, data)
      end
    end)

    # Clean up
    :ets.delete(table)
    result
  end

  # =============================================================================
  # BENCHMARK RUNNER
  # =============================================================================

  def run() do
    IO.puts("🚀 Starting Multi-Page Memory Structure Benchmark")
    IO.puts("📊 Workload Profile:")
    total_mb = div(@num_pages * @page_size, 1024 * 1024)
    IO.puts("   - Pages: #{@num_pages}")
    IO.puts("   - Page size: #{@page_size} bytes each")
    IO.puts("   - Total memory: #{@num_pages * @page_size} bytes (#{total_mb} MB)")
    IO.puts("   - Read/Write ratio: #{round(@read_percentage * 100)}%/#{round(@write_percentage * 100)}%")
    IO.puts("   - Average bytes per operation: #{@avg_bytes_per_op}")
                IO.puts("   - Testing 10 memory structures:")
    IO.puts("     1. Map pages (sparse)")
    IO.puts("     2. Binary pages (pre-allocated, dense)")
    IO.puts("     3. Binary pages (lazy allocation)")
    IO.puts("     4. Atomics pages (#{@num_pages} separate arrays)")
    IO.puts("     5. Single atomics (#{@num_pages * @page_size} elements, 1 byte/atomic)")

    packed_elements = div(@num_pages * @page_size + @bytes_per_word - 1, @bytes_per_word)
    IO.puts("     6. Packed atomics (#{packed_elements} elements, #{@bytes_per_word} bytes/atomic)")
    IO.puts("     7. ETS binary lazy (O(1) lookup, lazy allocation)")
    IO.puts("     8. ETS map sparse (O(1) lookup, sparse allocation)")
    IO.puts("     9. ETS lazy atomics (O(1) lookup + fast atomics, lazy allocation)")
    IO.puts("    10. ETS atomics lazy (O(1) lookup + lazy atomics arrays)")

    case Code.ensure_loaded(Benchee) do
      {:module, _} ->
        IO.puts("✅ Benchee loaded successfully!")
        run_with_benchee()
      {:error, reason} ->
        IO.puts("⚠️  Benchee not available (#{reason}), running simple benchmark...")
        run_simple_benchmark()
    end
  end

  defp run_with_benchee() do
    # Test with different operation counts
    test_sizes = [1_000, 10_000, 25_000]

    for op_count <- test_sizes do
      IO.puts("\n" <> String.duplicate("=", 70))
      IO.puts("📈 Testing #{@num_pages}-page memory with #{op_count} operations")
      IO.puts(String.duplicate("=", 70))

      operations = generate_multi_page_operations(op_count)

      Benchee.run(
        %{
          "map_pages_sparse" => fn -> run_map_memory_operations(operations) end,
          # "binary_pages_dense" => fn -> run_binary_memory_operations(operations) end,
          "binary_pages_lazy" => fn -> run_lazy_binary_memory_operations(operations) end,
          # "atomics_pages_concurrent" => fn -> run_atomics_memory_operations(operations) end,
          # "single_atomics_flat" => fn -> run_single_atomics_memory_operations(operations) end,
          # "packed_atomics_optimized" => fn -> run_packed_atomics_memory_operations(operations) end,
          "ets_binary_lazy" => fn -> run_ets_binary_lazy_operations(operations) end,
          "ets_map_sparse" => fn -> run_ets_map_sparse_operations(operations) end,
          # "ets_lazy_atomics" => fn -> run_ets_lazy_atomics_operations(operations) end,
          # "ets_atomics_lazy" => fn -> run_ets_atomics_lazy_operations(operations) end
        },
        time: 5,
        memory_time: 2,
        print: [
          benchmarking: true,
          fast_warning: false
        ],
        formatters: [
          Benchee.Formatters.Console,
          {Benchee.Formatters.HTML, file: "multi_page_benchmark_#{op_count}_ops.html"}
        ],
        pre_check: true,
        save: [path: "multi_page_memory_#{op_count}.benchee"]
      )

      # Memory analysis
      process_memory = :erlang.process_info(self(), :memory) |> elem(1)
      IO.puts("\n📋 Memory Analysis for #{op_count} operations across #{@num_pages} pages:")
      IO.puts("   Current process memory: #{div(process_memory, 1024)} KB")
      IO.puts("   Memory per page: ~#{div(process_memory, @num_pages * 1024)} KB")
    end

  end



  defp time_function(func) do
    {time_us, result} = :timer.tc(func)
    {time_us, result}
  end
end

# Run the benchmark
MultiPageMemoryBenchmark.run()
