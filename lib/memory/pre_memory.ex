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
    optimized_ranges = merge_adjacent_ranges(pre_memory.access_ranges)

    # Create the real Memory struct
    %Memory{
      data: pre_memory.data,
      access_ranges: optimized_ranges,
      page_size: pre_memory.page_size,
      size: pre_memory.size
    }
  end

  defp merge_adjacent_ranges(ranges) do
    # First, handle overwrites by keeping only the last occurrence of ranges with same start/end
    unique_ranges =
      Enum.reduce(ranges, %{}, fn {start, end_, type}, acc ->
        Map.put(acc, {start, end_}, type)
      end)
      |> Enum.map(fn {{start, end_}, type} -> {start, end_, type} end)

    Enum.reduce(unique_ranges, [], fn
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

  def resolve_overlaps(%__MODULE__{access_ranges: ranges} = pre_memory) do
    # Create events for range starts and ends with index for priority
    events = create_range_events(ranges)

    # Process events to build non-overlapping ranges
    {result, _active_ranges, _last_pos} =
      Enum.reduce(events, {[], [], nil}, fn
        {pos, event_type, type, idx}, {result, active, last_position} ->
          result_ = create_segment(last_position, pos, active, result)

          active_updated =
            case event_type do
              :start ->
                [{type, idx} | active]
                |> Enum.sort_by(fn {_, index} -> index end)

              :end ->
                Enum.reject(active, fn {_, i} -> i == idx end)
            end

          {result_, active_updated, pos}
      end)

    %{pre_memory | access_ranges: Enum.reverse(result)}
  end

  defp create_range_events(ranges) do
    ranges
    |> Enum.with_index()
    |> Enum.flat_map(fn {{start, end_, type}, idx} ->
      # Each range creates two events: start and end
      [
        {start, :start, type, idx},
        {end_, :end, type, idx}
      ]
    end)
    |> Enum.sort_by(fn {pos, event_type, _, idx} ->
      # Sort by position first, then by event type (:end before :start),
      # then by index (lower index => higher priority)
      {pos, if(event_type == :end, do: 0, else: 1), -idx}
    end)
  end

  # no segment should be created
  defp create_segment(nil, _current_position, _active_ranges, result), do: result
  defp create_segment([], _current_position, _active_ranges, result), do: result

  defp create_segment(last_position, current_position, _active_ranges, result)
       when current_position <= last_position,
       do: result

  # a segment should be created
  defp create_segment(last_position, current_position, active_ranges, result) do
    {active_type, _} = List.first(active_ranges)
    [{last_position, current_position, active_type} | result]
  end
end
