defmodule PVM.Instructions.TwoRegisters do
  alias PVM.Registers
  alias PVM.Memory
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

  # Formula (A.26) v0.6.1
  defp get_params(program, counter) do
    byte = binary_part(program, counter + 1, 1) |> :binary.first()
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
