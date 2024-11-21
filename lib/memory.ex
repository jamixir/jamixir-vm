defmodule Memory do
  import Bitwise

  # Formula (35) v0.4.5
  @type t :: %__MODULE__{
          data: binary(),
          access: map()
        }

  defstruct data: <<>>,
            access: %{}

  def read(%__MODULE__{} = memory, index, length) do
    start_idx = rem(index, 1 <<< 32)

    case check_permissions(memory, start_idx, length, :read) do
      :ok ->
        0..(length - 1)
        |> Enum.map(fn offset ->
          idx = rem(start_idx + offset, 1 <<< 32)

          case memory.data do
            <<_::binary-size(idx), byte::8, _::binary>> -> byte
            _ -> 0
          end
        end)
        |> :binary.list_to_bin()

      {:error, addr} ->
        {:error, {:fault, addr}}
    end
  end

  def write(%__MODULE__{} = memory, index, value) when is_binary(value) do
    start_idx = rem(index, 1 <<< 32)

    case check_permissions(memory, start_idx, byte_size(value), :write) do
      :ok ->
        data =
          if start_idx > byte_size(memory.data) do
            # Pad with zeros up to the write position
            memory.data <> <<0::size((start_idx - byte_size(memory.data)) * 8)>>
          else
            memory.data
          end

        # Construct new data
        prefix = binary_part(data, 0, start_idx)
        suffix_start = min(start_idx + byte_size(value), byte_size(data))
        suffix_length = max(0, byte_size(data) - suffix_start)
        suffix = binary_part(data, suffix_start, suffix_length)

        %__MODULE__{memory | data: prefix <> value <> suffix}

      {:error, addr} ->
        {:error, {:fault, addr}}
    end
  end

  def set_access(%__MODULE__{} = memory, start_idx, length, access_type) do
    new_access =
      Enum.reduce(0..(length - 1), memory.access, fn offset, acc ->
        idx = rem(start_idx + offset, 1 <<< 32)
        Map.put(acc, idx, access_type)
      end)

    %__MODULE__{memory | access: new_access}
  end

  defp check_permissions(memory, start_idx, length, required_access) do
    result =
      Enum.reduce_while(0..(length - 1), :ok, fn offset, _acc ->
        idx = rem(start_idx + offset, 1 <<< 32)
        # Default :write for unmapped addresses
        current_access = Map.get(memory.access, idx, :write)

        cond do
          required_access == :read and current_access in [:read, :write] -> {:cont, :ok}
          required_access == :write and current_access == :write -> {:cont, :ok}
          true -> {:halt, {:error, idx}}
        end
      end)

    case result do
      :ok -> :ok
      {:error, idx} -> {:error, idx}
    end
  end

  # Formula (36) v0.4.5
  def valid_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn idx -> Map.get(memory.access, idx) != nil end)
    |> Enum.sort()
  end

  # Formula (36) v0.4.5
  def write_only_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn idx -> Map.get(memory.access, idx) == :write end)
    |> Enum.sort()
  end
end
