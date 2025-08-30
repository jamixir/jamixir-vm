defmodule PVM.Memory.RangeManager do
  @moduledoc """
  Handles memory access range management, including merging overlapping ranges
  and resolving access permissions.
  """

  @doc """
  Adds a new access range and resolves any overlaps with existing ranges.
  The newest range takes precedence in case of overlaps.
  used for setting access permissions
  """
  def add_range(ranges, start_page, end_page, access_type) do
    {before_parts, after_parts} =
      Enum.reduce(ranges, {[], []}, fn {r_start, r_end, r_type}, {before, after_} ->
        cond do
          # Range is completely before new range
          r_end <= start_page ->
            {[{r_start, r_end, r_type} | before], after_}

          # Range is completely after new range
          r_start >= end_page ->
            {before, [{r_start, r_end, r_type} | after_]}

          # Range overlaps with new range
          true ->
            # Keep non-overlapping parts
            before_part =
              if r_start < start_page, do: [{r_start, start_page, r_type}], else: []

            after_part = if r_end > end_page, do: [{end_page, r_end, r_type}], else: []

            {before_part ++ before, after_part ++ after_}
        end
      end)

    # Reverse the lists once to restore sort order
    sorted_before = Enum.reverse(before_parts)
    sorted_after = Enum.reverse(after_parts)

    # Combine in sorted order
    sorted_combined = sorted_before ++ [{start_page, end_page, access_type}] ++ sorted_after

    merge_adjacent_ranges(sorted_combined)
  end

  @doc """
  used for checking access permissions of a page
  """
  def binary_search_range(_ranges, _page, low, high) when low > high, do: nil

  def binary_search_range(ranges, page, low, high) do
    mid = div(low + high, 2)
    {start, end_, _} = elem(ranges, mid)

    cond do
      page >= start and page < end_ ->
        # Found a range containing the page
        elem(ranges, mid)

      page < start ->
        # Search in the lower half
        binary_search_range(ranges, page, low, mid - 1)

      true ->
        # Search in the upper half
        binary_search_range(ranges, page, mid + 1, high)
    end
  end

  def merge_adjacent_ranges(ranges) do
    merged_ranges =
      Enum.reduce(ranges, [], fn
        range, [] ->
          [range]

        {start, end_, type}, [{prev_start, prev_end, prev_type} | rest] ->
          if type == prev_type && start == prev_end do
            # Merge adjacent ranges with same access type (end is exclusive)
            [{prev_start, max(end_, prev_end), type} | rest]
          else
            # Different type or not adjacent
            [{start, end_, type} | [{prev_start, prev_end, prev_type} | rest]]
          end
      end)

    Enum.reverse(merged_ranges)
  end
end
