defmodule PVM.Encoder do
  @moduledoc """
  A module for encoding data structures into binary format.
  """

  # Formula (C.5) v0.7.0
  @spec encode_little_endian(integer(), integer()) :: binary()
  def encode_little_endian(_, 0), do: <<>>

  def encode_little_endian(x, l), do: <<x::l*8-little>>

  @spec encode_le(integer(), integer()) :: binary()
  def encode_le(x, l), do: encode_little_endian(x, l)

  defp exists_l_in_n8(x) do
    l = trunc(:math.log2(x) / 7)

    if l in 0..7 do
      l
    else
      nil
    end
  end

  # Formula (C.6) v0.7.0
  defp encode_integer(0), do: <<0>>

  defp encode_integer(x) do
    if x >= 2 ** 64, do: raise(ArgumentError, "Integer value is too large to encode")

    case exists_l_in_n8(x) do
      nil -> <<2 ** 8 - 1>> <> <<x::64-little>>
      l -> <<2 ** 8 - 2 ** (8 - l) + div(x, 2 ** (8 * l))>> <> encode_le(rem(x, 2 ** (8 * l)), l)
    end
  end

  # Encode full program blob according to p = E(|j|) ∘ E(z) ∘ E(|c|) ∘ E(j) ∘ E(c) ∘ E(k)
  def encode_program(program, bitmask, jump_table, z) do
    jump_table_list = Tuple.to_list(jump_table)

    # Encode jump table - each entry needs to be encoded as an integer
    encoded_jump = Enum.map(jump_table_list, fn v -> encode_le(v, z) end)

    bitmask = PVM.Decoder.reverse_bitmask(bitmask)

    # Concatenate in specified order: |j| ∘ z ∘ |c| ∘ j ∘ c ∘ k
    <<
      encode_integer(length(jump_table_list))::binary,
      encode_le(z, 1)::binary,
      encode_integer(byte_size(program))::binary,
      Enum.into(encoded_jump, <<>>)::binary,
      program::binary,
      bitmask::bitstring
    >>
  end

  defmacro __using__(_) do
    quote do
      def e_le(value, l), do: PVM.Encoder.encode_le(value, l)
    end
  end
end
