defmodule PVM.PreMemory do
  import PVM.Memory.{Constants, Util}
  alias PVM.Memory

  @type t :: %__MODULE__{
          data: %{non_neg_integer() => byte()},
          # range is inclusive of start and exclusive of end i.e {16, 17, :read} means only 16 is readable
          access_ranges: [{non_neg_integer(), non_neg_integer(), atom()}],
          page_size: pos_integer(),
          size: pos_integer()
        }

  defstruct data: %{},
            access_ranges: [],
            page_size: page_size(),
            size: memory_size()

  def write(%__MODULE__{} = pre_memory, address, value) when is_binary(value) do
    new_data = write_to_sparse(pre_memory, address, value)
    %__MODULE__{pre_memory | data: new_data}
  end

  def set_access(%__MODULE__{} = pre_memory, address, length, access_type) do
    {start_page, end_page} = get_page_range(pre_memory, address, length)
    new_range = {start_page, end_page + 1, access_type}

    %__MODULE__{pre_memory | access_ranges: [new_range | pre_memory.access_ranges]}
  end

  def finalize(%__MODULE__{} = pre_memory) do
    optimized_ranges = optimize_access_ranges(pre_memory.access_ranges)

    # Create the real Memory struct
    %Memory{
      data: pre_memory.data,
      access_ranges: optimized_ranges,
      page_size: pre_memory.page_size,
      size: pre_memory.size
    }
  end

  defp optimize_access_ranges(ranges) do
    # First, handle overwrites by keeping only the last occurrence of ranges with same start/end
    unique_ranges =
      Enum.reduce(ranges, %{}, fn {start, end_, type}, acc ->
        Map.put(acc, {start, end_}, type)
      end)
      |> Enum.map(fn {{start, end_}, type} -> {start, end_, type} end)

    # Then sort and merge adjacent ranges of the same type
    sorted = Enum.sort_by(unique_ranges, fn {start, _, _} -> start end)

    Enum.reduce(sorted, [], fn
      range, [] ->
        [range]

      {start, end_, type}, [{prev_start, prev_end, prev_type} | rest] = acc ->
        if type == prev_type and start <= prev_end + 1 do
          # Merge adjacent ranges of same type
          [{prev_start, max(end_, prev_end), type} | rest]
        else
          # Different type or not adjacent, add as new range
          [{start, end_, type} | acc]
        end
    end)
    |> Enum.reverse()
  end
end
