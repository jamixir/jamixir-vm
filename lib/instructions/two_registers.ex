defmodule PVM.Instructions.TwoRegisters do
  alias PVM.Registers
  alias PVM.Memory
  use PVM.Transitions
  use PVM.{Encoder, Decoder, Utils}
  # Section (A.5.9) v0.6.1

  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, w_a)}}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    bytes_needed = Registers.get(state.registers, r_a)

    pages_needed = ceil(bytes_needed / state.memory.page_size)
    end_page = Memory.number_of_pages(state.memory) - 1

    writable_pages = Memory.writeable_indices(state.memory) |> MapSet.to_list() |> Enum.sort()
    readable_pages = Memory.readable_indices(state.memory) |> MapSet.to_list() |> Enum.sort()

    # Determine where to start looking for space based on writable blocks
    start_search_at = case count_writable_blocks(writable_pages) do
      0 -> 0  # No writable pages, start from beginning
      1 -> 0  # Single block, start from beginning
      _ ->
        {start, _} = find_first_gap_in_writable(writable_pages)
        start  # Multiple blocks, start after first block
    end

    # Find first sequence of non-readable pages that's big enough
    case find_non_readable_sequence(readable_pages, start_search_at, end_page, pages_needed) do
      nil ->
        # No suitable space found
        {:continue, state}
      start_page ->
        # Set pages as writable and return starting address
        new_memory = Memory.set_access_by_page(state.memory, start_page, pages_needed, :write)
        start_address = start_page * state.memory.page_size
        {:continue, %{state |
          memory: new_memory,
          registers: Registers.set(state.registers, r_d, start_address)
        }}
    end
  end

  def execute(:count_set_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    bits_sum = Registers.get(state.registers, r_a) |> u2b(8) |> Enum.sum()
    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:count_set_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)

    bits_sum =
      Registers.get(state.registers, r_a) |> rem(0x1_0000_0000) |> u2b(4) |> Enum.sum()

    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:leading_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)

    leading_zero_bits =
      Registers.get(state.registers, r_a)
      |> u2b(8)
      |> Enum.with_index()
      |> Enum.find_index(fn {bit, _index} -> bit == 1 end)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:leading_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)

    leading_zero_bits =
      Registers.get(state.registers, r_a)
      |> rem(0x1_0000_0000)
      |> u2b(4)
      |> Enum.with_index()
      |> Enum.find_index(fn {bit, _index} -> bit == 1 end)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:trailing_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)

    bits = Registers.get(state.registers, r_a) |> u2b(8)
    len = length(bits)

    trailing_zero_bits =
      Enum.find_index(0..(len - 1), fn i ->
        Enum.at(bits, len - 1 - i) == 1
      end)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:trailing_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    bits = Registers.get(state.registers, r_a) |> rem(0x1_0000_0000) |> u2b(4)
    len = length(bits)

    trailing_zero_bits =
      Enum.find_index(0..(len - 1), fn i -> Enum.at(bits, len - 1 - i) == 1 end)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:sign_extend_8, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    sign_extended = Registers.get(state.registers, r_a) |> rem(0x100) |> u2i(1) |> i2u(8)
    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:sign_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    sign_extended = Registers.get(state.registers, r_a) |> rem(0x10000) |> u2i(2) |> i2u(8)
    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:zero_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    zero_extended = Registers.get(state.registers, r_a) |> rem(0x10000)
    {:continue, %{state | registers: Registers.set(state.registers, r_d, zero_extended)}}
  end

  def execute(:reverse_bytes, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    value = <<Registers.get(state.registers, r_a)::64-little>>

    <<reversed::64-little>> = value |> :binary.bin_to_list() |> Enum.reverse()
      |> :binary.list_to_bin()

    {:continue, %{state | registers: Registers.set(state.registers, r_d, reversed)}}
  end

  # Formula (A.26) v0.6.1
  defp get_params(program, counter) do
    byte = binary_part_safe(program, counter + 1, 1) |> :binary.first()
    {rem(byte, 16) |> min(12), div(byte, 16) |> min(12)}
  end

  # Count number of contiguous blocks in writable pages
  @spec count_writable_blocks(maybe_improper_list()) :: any()
  def count_writable_blocks([]), do: 0
  def count_writable_blocks(pages) do
    Enum.reduce(Enum.drop(pages, 1), {1, hd(pages)}, fn page, {blocks, prev} ->
      if page == prev + 1 do
        {blocks, page}
      else
        {blocks + 1, page}
      end
    end)
    |> elem(0)
  end

  # Find first gap between writable blocks
  def find_first_gap_in_writable([first | rest]) do
    {start, end_} = Enum.reduce_while(rest, {first, first}, fn page, {_start, prev} ->
      if page == prev + 1 do
        {:cont, {first, page}}
      else
        {:halt, {prev + 1, page - 1}}
      end
    end)
    {start, end_}
  end

  # Find first sequence of non-readable pages within range that's big enough
  def find_non_readable_sequence(readable_pages, start_at, end_page, pages_needed) do
    # Filter to only pages after our start point and before/at end_page
    readable_in_range = Enum.filter(readable_pages, &(&1 >= start_at and &1 <= end_page))

    case readable_in_range do
      [] ->
        # No readable pages in range, check if enough space to end
        if end_page + 1 - start_at >= pages_needed, do: start_at, else: nil
      [first | _] when first > start_at ->
        # Gap at start
        if first - start_at >= pages_needed, do: start_at, else: find_gap_after(readable_in_range, pages_needed, end_page + 1)
      _ ->
        find_gap_after(readable_in_range, pages_needed, end_page)
    end
  end

  defp find_gap_after([a, b | rest], pages_needed, total_pages) do
    if b - a - 1 >= pages_needed do
      a + 1
    else
      find_gap_after([b | rest], pages_needed, total_pages)
    end
  end
  defp find_gap_after([last], pages_needed, total_pages) do
    # Check space after last readable page to end of memory
    if total_pages - (last + 1) >= pages_needed do
      last + 1
    else
      nil
    end
  end
  defp find_gap_after([], pages_needed, total_pages) do
    # If no pages in range, check if enough space exists
    if total_pages >= pages_needed, do: 0, else: nil
  end
end
