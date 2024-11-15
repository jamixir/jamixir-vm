defmodule PVM.Encoder do
  @moduledoc """
  A module for encoding data structures into binary format.
  """


  # Formula (300) v0.4.5
  @spec encode_little_endian(integer(), integer()) :: binary()
  def encode_little_endian(_, 0), do: <<>>

  def encode_little_endian(x, l) do
    <<rem(x, 256)>> <> encode_little_endian(div(x, 256), l - 1)
  end

  @spec encode_le(integer(), integer()) :: binary()
  def encode_le(x, l), do: encode_little_endian(x, l)



  defmacro __using__(_) do
    quote do
      def e_le(value, l), do: PVM.Encoder.encode_le(value, l)

    end
  end
end
