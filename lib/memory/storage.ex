defmodule Memory.Storage do
  @moduledoc false  # Internal implementation details

  defstruct data: <<>>,
            access: %{}

  def new do
    %__MODULE__{
      data: <<>>,
      access: %{}
    }
  end

  def read_byte(storage, idx) do
    case storage.data do
      <<_::binary-size(idx), byte::8, _rest::binary>> -> byte
      _ -> 0
    end
  end

  def write_bytes(storage, start_idx, value) when is_binary(value) do
    data =
      if start_idx > byte_size(storage.data) do
        storage.data <> <<0::size((start_idx - byte_size(storage.data)) * 8)>>
      else
        storage.data
      end

    prefix = binary_part(data, 0, start_idx)
    suffix =
      binary_part(
        data,
        min(start_idx + byte_size(value), byte_size(data)),
        max(0, byte_size(data) - (start_idx + byte_size(value)))
      )

    %__MODULE__{storage | data: prefix <> value <> suffix}
  end

  def get_access(storage, idx) do
    Map.get(storage.access, idx, :write)  # Default to write access
  end

  def set_access(storage, idx, access_type) do
    new_access =
      if access_type == :write do
        Map.delete(storage.access, idx)  # Don't store default permissions
      else
        Map.put(storage.access, idx, access_type)
      end
    %__MODULE__{storage | access: new_access}
  end
end 
