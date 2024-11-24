defmodule Memory do
  import Bitwise
  # Zp = 4096 octets per page (4KB)
  # Formula (4.25) v0.5
  @page_size 1 <<< 12
  # 4GB (2^32 bytes)
  # Formula (4.24) v0.5
  @memory_size 1 <<< 32
  # Number of pages
  # Formula (4.24) v0.5
  @page_count 1 <<< 20

  @type t :: %__MODULE__{
          # Map of page number to page data
          data: %{non_neg_integer() => binary()},
          # Map of page number to access permissions
          access: %{non_neg_integer() => atom()}
        }

  defstruct data: %{},
            access: %{}

  defp wrap_address(address) do
    rem(address, @memory_size)
  end

  defp wrap_page(page) do
    rem(page, @page_count)
  end

  defp page_range(start_page, end_page) do
    if end_page >= start_page do
      start_page..end_page
    else
      # When wrapping occurs, we need to go from start to max, then 0 to end
      Enum.to_list(start_page..(@page_count - 1)) ++ Enum.to_list(0..end_page)
    end
  end

  def read(%__MODULE__{} = memory, address, length) do
    wrapped_address = wrap_address(address)
    start_page = wrap_page(div(wrapped_address, @page_size))
    end_page = wrap_page(div(wrapped_address + length - 1, @page_size))

    case check_permissions(memory, page_range(start_page, end_page), :read) do
      :ok ->
        data =
          0..(length - 1)
          |> Enum.map(fn offset ->
            abs_addr = wrap_address(wrapped_address + offset)
            page_num = wrap_page(div(abs_addr, @page_size))
            page_offset = rem(abs_addr, @page_size)

            case Map.get(memory.data, page_num) do
              nil ->
                0

              page_data ->
                case page_data do
                  <<_::binary-size(page_offset), byte::8, _::binary>> -> byte
                  _ -> 0
                end
            end
          end)
          |> :binary.list_to_bin()

        {:ok, data}

      {:error, page} ->
        {:error, {:fault, page * @page_size}}
    end
  end

  def write(%__MODULE__{} = memory, address, value) when is_binary(value) do
    wrapped_address = wrap_address(address)
    start_page = wrap_page(div(wrapped_address, @page_size))
    end_page = wrap_page(div(wrapped_address + byte_size(value) - 1, @page_size))

    case check_permissions(memory, page_range(start_page, end_page), :write) do
      :ok ->
        start_offset = rem(wrapped_address, @page_size)

        new_data =
          Enum.reduce(page_range(start_page, end_page), {memory.data, 0}, fn page_num,
                                                                             {acc, bytes_written} ->
            page_offset = if page_num == start_page, do: start_offset, else: 0
            current_page = Map.get(acc, page_num, <<0::size(@page_size * 8)>>)

            # Calculate how many bytes go into this page
            bytes_remaining = byte_size(value) - bytes_written
            bytes_in_page = min(bytes_remaining, @page_size - page_offset)

            # Extract the portion of data for this page
            <<_::binary-size(bytes_written), page_data::binary-size(bytes_in_page), _::binary>> =
              value

            # Create new page with the correct portion of data
            new_page =
              case current_page do
                <<pre::binary-size(page_offset), _::binary-size(bytes_in_page), post::binary>> ->
                  pre <> page_data <> post

                _ ->
                  pad_pre = binary_part(current_page, 0, page_offset)
                  pad_pre <> page_data
              end

            {Map.put(acc, page_num, new_page), bytes_written + bytes_in_page}
          end)
          # Get just the map, discard bytes_written
          |> elem(0)

        {:ok, %__MODULE__{memory | data: new_data}}

      {:error, page} ->
        {:error, {:fault, page}}
    end
  end

  def set_access(%__MODULE__{} = memory, address, length, access_type) do
    start_page = wrap_page(div(address, @page_size))
    end_page = wrap_page(div(address + length - 1, @page_size))

    new_access =
      Enum.reduce(page_range(start_page, end_page), memory.access, fn page_num, acc ->
        Map.put(acc, page_num, access_type)
      end)

    %__MODULE__{memory | access: new_access}
  end

  defp check_permissions(memory, page_range, required_access) do
    result =
      Enum.reduce_while(page_range, :ok, fn page_num, _acc ->
        # Default :write for unmapped pages
        current_access = Map.get(memory.access, page_num, :write)

        cond do
          required_access == :read and current_access in [:read, :write] -> {:cont, :ok}
          required_access == :write and current_access == :write -> {:cont, :ok}
          true -> {:halt, {:error, page_num}}
        end
      end)

    case result do
      :ok -> :ok
      {:error, page} -> {:error, page}
    end
  end

  def readable_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn page -> Map.get(memory.access, page) != nil end)
    |> MapSet.new()
  end

  def writeable_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn page -> Map.get(memory.access, page) == :write end)
    |> MapSet.new()
  end

end
