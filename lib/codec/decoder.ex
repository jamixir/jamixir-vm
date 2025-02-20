defmodule PVM.Decoder do
  @moduledoc """
  A module for decoding binary data into data structures.
  """
  import Bitwise
  defp decode_little_endian(<<>>, _), do: 0

  defp decode_little_endian(<<byte::size(8), rest::binary>>, l),
    do: byte + decode_little_endian(rest, l - 1) * 256

  def decode_le(encoded, length), do: decode_little_endian(encoded, length)

  def decode_integer(<<0, _rest::binary>>), do: 0

  def decode_integer(<<byte0, _rest::binary>>) when byte0 in 1..127 do
    byte0
  end

  def decode_integer(<<255, value_bytes::binary-size(8), _rest::binary>>) do
    decode_little_endian(value_bytes, 8)
  end

  def decode_integer(<<byte0, rest::binary>>) when byte0 in 128..254 do
    {l, a_l} = determine_l_and_a_l(byte0)
    h = byte0 - a_l
    x_rest = decode_le(rest, l)
    x = h * :math.pow(256, l) + x_rest
    trunc(x)
  end

  defp determine_l_and_a_l(byte0) do
    cond do
      byte0 >= 254 ->
        {7, 254}

      byte0 >= 252 ->
        {6, 252}

      byte0 >= 248 ->
        {5, 248}

      byte0 >= 240 ->
        {4, 240}

      byte0 >= 224 ->
        {3, 224}

      byte0 >= 192 ->
        {2, 192}

      byte0 >= 128 ->
        {1, 128}
    end
  end

  # Decode program blob into components
  def decode_program(bin) do
    # Decode lengths sequentially
    {jump_len, rest} = decode_next_integer(bin)
    {z, rest} = decode_next_le(rest, 1)
    {prog_len, rest} = decode_next_integer(rest)

    # Decode jump table entries
    {jump_table, rest} = decode_jump_table(rest, jump_len, z)

    # Extract program and bitmask
    <<program::binary-size(prog_len), bitmask::bitstring>> = rest

    bitmask = reverse_bitmask(bitmask)

    {program, bitmask, jump_table}
  end

  def reverse_bitmask(bitmask) do
    bytes = byte_size(bitmask)
    bits = bit_size(bitmask)
    case bytes do
      0 -> bitmask
      1 ->
        # Single byte - check if it's full or partial
        case bits do
          8 ->
            <<n>> = bitmask
            <<reverse_bits(n, 8)::bitstring>>
          bits ->
            <<n>> = <<0::size(8 - bits), bitmask::bits>>
            <<reversed::bits>> = reverse_bits(n, 8)
            <<reversed::bitstring-size(bits)>>
        end

      n ->
        # Multiple bytes - check if last byte is full
        case bits do
          total_bits when rem(total_bits, 8) == 0 ->
            # All full bytes - simple case
            reverse_each_byte(bitmask)

          _total_bits ->
            # Last byte is partial
            <<all_but_last::binary-size(n - 1), last::bitstring>> = bitmask
            reversed_full = reverse_each_byte(all_but_last)
            bits_in_last = bit_size(last)
            <<n>> = <<0::size(8 - bits_in_last), last::bits>>
            <<reversed_last::bits>> = reverse_bits(n, 8)
            <<reversed_full::binary, reversed_last::bitstring-size(bits_in_last)>>
        end
    end
  end

  def reverse_each_byte(binary) do
    :binary.bin_to_list(binary)
    |> Enum.reduce(<<>>, fn byte, acc ->
      <<acc::bitstring, reverse_bits(byte, 8)::bitstring>>
    end)
  end

  # https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel
  def reverse_bits(n, bit_size) do
    n = (n >>> 1 &&& 0x55) ||| (n &&& 0x55) <<< 1
    n = (n >>> 2 &&& 0x33) ||| (n &&& 0x33) <<< 2
    n = (n >>> 4 &&& 0x0F) ||| (n &&& 0x0F) <<< 4
    <<n::size(bit_size)>>
  end

  defp decode_jump_table(binary, 0, _z), do: {[], binary}

  defp decode_jump_table(binary, remaining, z) do
    {value, rest} = decode_next_le(binary, z)
    {values, remaining_binary} = decode_jump_table(rest, remaining - 1, z)
    {[value | values], remaining_binary}
  end

  # Helper to decode next integer and return remaining binary
  defp decode_next_integer(<<0, rest::bitstring>>), do: {0, rest}

  defp decode_next_integer(<<byte0, rest::bitstring>>) when byte0 in 1..127 do
    {byte0, rest}
  end

  defp decode_next_integer(<<255, value_bytes::binary-size(8), rest::bitstring>>) do
    {decode_little_endian(value_bytes, 8), rest}
  end

  defp decode_next_integer(<<byte0, rest::bitstring>>) when byte0 in 128..254 do
    {l, _} = determine_l_and_a_l(byte0)
    <<value::binary-size(l), rest2::bitstring>> = rest
    {decode_integer(<<byte0, value::binary>>), rest2}
  end

  defp decode_next_le(binary, n) do
    <<value::binary-size(n), rest::bitstring>> = binary
    {decode_le(value, n), rest}
  end

  defmacro __using__(_) do
    quote do
      def de_le(value, l), do: PVM.Decoder.decode_le(value, l)
    end
  end
end
