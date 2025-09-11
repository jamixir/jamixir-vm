defmodule PVM.Memory.Util do
  import Bitwise
  alias PVM.Math
  @mask64 0xFFFF_FFFF_FFFF_FFFF

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

  def wrap_address(%{size: size}, address) when size == 0x1_0000_0000 do
    address &&& 0xFFFFFFFF
  end

  def wrap_address(%{size: size}, address) do
    rem(rem(address, size) + size, size)
  end

  defguard start_of_page(address, page_size) when (address &&& page_size - 1) == 0

  def write_to_sparse(%{data: nil} = memory, address, value),
    do:
      write_to_sparse(
        %{memory | data: :ets.new(:ets_binary_lazy, [:set, :public])},
        address,
        value
      )

  # case when address is page-aligned and value is at least a full page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when start_of_page(address, page_size) and byte_size(value) >= page_size do
    <<p1_value::binary-size(page_size), rest_value::binary>> = value
    page_num = div(address, page_size)
    ref = ensure_page_atomix(memory.data, page_num, page_size)
    write_full_page_atomix(ref, p1_value, page_size)
    write_to_sparse(memory, address + page_size, rest_value)
  end

  # last chunk which is less than a full page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when start_of_page(address, page_size) and byte_size(value) < page_size do
    page_num = address >>> 12
    ref = ensure_page_atomix(memory.data, page_num, page_size)
    write_bytes_atomix(ref, 0, value)
    memory.data
  end

  # case when address is not page-aligned and ends on the first page
  def write_to_sparse(%{page_size: page_size} = memory, address, value)
      when not start_of_page(address, page_size) do
    page_num = address >>> 12
    end_page_num = (address + byte_size(value) - 1) >>> 12

    if page_num == end_page_num do
      offset = Math.mod(address, page_size)
      ref = ensure_page_atomix(memory.data, page_num, page_size)
      write_bytes_atomix(ref, offset, value)
      memory.data
    else
      # case when address is not page-aligned and ends after first page
      offset = Math.mod(address, page_size)
      ref = ensure_page_atomix(memory.data, page_num, page_size)
      <<first_chunk::binary-size(page_size - offset), rest::binary>> = value
      write_bytes_atomix(ref, offset, first_chunk)
      write_to_sparse(memory, address - offset + page_size, rest)
    end
  end

  def get_page_range(%{page_size: _page_size} = memory, start_address, length) do
    start_page = start_address >>> 12
    end_address = wrap_address(memory, start_address + max(0, length - 1))
    end_page = end_address >>> 12

    {start_page, end_page}
  end

  def page_address(address),
    do: {address >>> 12, address &&& 0xFFF}

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

  # Internal helpers to store pages as :atomics in ETS
  defp ensure_page_atomix(ets, page_num, page_size) do
    case :ets.lookup(ets, page_num) do
      [{_, ref}] ->
        ref

      [] ->
        words = div(page_size, 8)
        ref = :atomics.new(words, signed: false)
        :ets.insert(ets, {page_num, ref})
        ref
    end
  end

  defp write_full_page_atomix(ref, page_binary, _page_size) do
    write_words_stream(ref, 1, page_binary)
  end

  defp write_words_stream(_ref, _idx, <<>>), do: :ok

  defp write_words_stream(ref, idx, <<w::little-unsigned-integer-size(64), rest::binary>>) do
    :atomics.put(ref, idx, w)
    write_words_stream(ref, idx + 1, rest)
  end

  defp write_bytes_atomix(ref, offset, value) do
    len = byte_size(value)
    start_word = div(offset, 8) + 1
    start_in_word = offset &&& 7

    if len == 8 and start_in_word == 0 do
      # Full 8-byte aligned overwrite: no read-modify needed
      <<ival::little-unsigned-integer-size(64)>> = value
      :atomics.put(ref, start_word, ival)
      :ok
    else if start_in_word + len <= 8 do
      <<ival::little-unsigned-integer-size(len * 8)>> = value
      word = :atomics.get(ref, start_word)
      shift = start_in_word * 8
      mask = ((1 <<< (len * 8)) - 1) <<< shift
      new_word = (word &&& bnot(mask)) ||| ival <<< shift
      :atomics.put(ref, start_word, new_word &&& @mask64)
      :ok
    else
      # First partial
      bytes_in_first = 8 - start_in_word
      <<first::binary-size(bytes_in_first), rest::binary>> = value
      <<first_val::little-unsigned-integer-size(bytes_in_first * 8)>> = first
      word0 = :atomics.get(ref, start_word)
      shift0 = start_in_word * 8
      mask0 = ((1 <<< (bytes_in_first * 8)) - 1) <<< shift0
      new0 = (word0 &&& bnot(mask0)) ||| first_val <<< shift0
      :atomics.put(ref, start_word, new0 &&& @mask64)

      # Middle full words
      full_words = div(byte_size(rest), 8)
      rem_tail = rem(byte_size(rest), 8)
      write_full_words(ref, start_word + 1, rest, full_words)

      # Last partial
      if rem_tail > 0 do
        base = full_words * 8
        <<_::binary-size(base), last::binary-size(rem_tail)>> = rest
        <<last_val::little-unsigned-integer-size(rem_tail * 8)>> = last
        last_word = :atomics.get(ref, start_word + full_words + 1)
        mask_last = (1 <<< (rem_tail * 8)) - 1
        new_last = (last_word &&& bnot(mask_last)) ||| last_val
        :atomics.put(ref, start_word + full_words + 1, new_last &&& @mask64)
      end

      :ok
  end
  end
  end

  defp write_full_words(_ref, _start_idx, _bin, 0), do: :ok

  defp write_full_words(ref, start_idx, <<w::little-unsigned-integer-size(64), rest::binary>>, n) do
    :atomics.put(ref, start_idx, w)
    write_full_words(ref, start_idx + 1, rest, n - 1)
  end

  # no conversion needed; using unsigned atomics
end
