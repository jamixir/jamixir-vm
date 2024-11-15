defmodule Codec.Decoder do
  @moduledoc """
  A module for decoding binary data into data structures.
  """
  defp decode_little_endian(<<>>, _), do: 0

  defp decode_little_endian(<<byte::size(8), rest::binary>>, l),
    do: byte + decode_little_endian(rest, l - 1) * 256

  def decode_le(encoded, length), do: decode_little_endian(encoded, length)

  defmacro __using__(_) do
    quote do
      def de_le(value, l), do: Codec.Decoder.decode_le(value, l)
    end
  end
end
