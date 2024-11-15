defmodule Memory do
  import Bitwise

  @type access :: :write | :read | nil  # nil represents empty/inaccessible

  defstruct data: <<>>,
            access: %{}  # Map of index -> access type

  def new do
    %__MODULE__{
      data: <<>>,
      access: %{}
    }
  end

  # Initialize memory with write permissions for a range
  def new(size) when is_integer(size) and size >= 0 do
    access = Enum.reduce(0..(size - 1), %{}, fn idx, acc ->
      Map.put(acc, idx, :write)
    end)
    %__MODULE__{
      data: <<0::size(size * 8)>>,
      access: access
    }
  end

  # Utility function to check permissions for a range of memory
  def check_permission_range(memory, start_idx, length, required_access) do
    Enum.reduce_while(0..(length - 1), {:ok}, fn offset, _acc ->
      idx = start_idx + offset
      current_access = Map.get(memory.access, idx)

      cond do
        # For read operations, both read and write permissions are ok
        required_access == :read and current_access in [:read, :write] ->
          {:cont, {:ok}}
        # For write operations, only write permission is ok
        required_access == :write and current_access == :write ->
          {:cont, {:ok}}
        # Any other case is an error
        true ->
          {:halt, {:error, idx}}
      end
    end)
  end

  def write(%__MODULE__{} = memory, index, value) when is_binary(value) do
    start_idx = rem(index, 1 <<< 32)

    case check_permission_range(memory, start_idx, byte_size(value), :write) do
      {:ok} ->
        data = if start_idx > byte_size(memory.data) do
          memory.data <> <<0::size((start_idx - byte_size(memory.data)) * 8)>>
        else
          memory.data
        end

        prefix = binary_part(data, 0, start_idx)
        suffix = binary_part(data, min(start_idx + byte_size(value), byte_size(data)),
                           max(0, byte_size(data) - (start_idx + byte_size(value))))
        %__MODULE__{memory | data: prefix <> value <> suffix}

      {:error, addr} ->
        {:error, {:fault, addr}}
    end
  end

  def read(%__MODULE__{} = memory, index, length) do
    start_idx = rem(index, 1 <<< 32)

    case check_permission_range(memory, start_idx, length, :read) do
      {:ok} ->
        case memory.data do
          <<_::binary-size(start_idx), result::binary-size(length), _rest::binary>> ->
            result
          _ ->
            <<0::size(length * 8)>>
        end

      {:error, addr} ->
        {:error, {:fault, addr}}
    end
  end

  # Get all valid (accessible) memory indices
  def valid_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn idx -> Map.get(memory.access, idx) != nil end)
    |> Enum.sort()
  end

  # Get all write-only memory indices
  def write_only_indices(%__MODULE__{} = memory) do
    Map.keys(memory.access)
    |> Enum.filter(fn idx -> Map.get(memory.access, idx) == :write end)
    |> Enum.sort()
  end

  # Set access permission for a memory range
  def set_access(%__MODULE__{} = memory, start_idx, length, access_type) do
    new_access = Enum.reduce(0..(length - 1), memory.access, fn offset, acc ->
      Map.put(acc, start_idx + offset, access_type)
    end)
    %__MODULE__{memory | access: new_access}
  end
end
