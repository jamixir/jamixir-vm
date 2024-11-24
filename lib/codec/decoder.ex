defmodule PVM.Decoder do
  @moduledoc """
  A module for decoding binary data into data structures.
  """
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
    <<program::binary-size(prog_len), bitmask::binary>> = rest

    {program, bitmask, jump_table}
  end

  defp decode_jump_table(binary, 0, _z), do: {[], binary}

  defp decode_jump_table(binary, remaining, z) do
    {value, rest} = decode_next_le(binary, z)
    {values, remaining_binary} = decode_jump_table(rest, remaining - 1, z)
    {[value | values], remaining_binary}
  end

  # Helper to decode next integer and return remaining binary
  defp decode_next_integer(<<0, rest::binary>>), do: {0, rest}

  defp decode_next_integer(<<byte0, rest::binary>>) when byte0 in 1..127 do
    {byte0, rest}
  end

  defp decode_next_integer(<<255, value_bytes::binary-size(8), rest::binary>>) do
    {decode_little_endian(value_bytes, 8), rest}
  end

  defp decode_next_integer(<<byte0, rest::binary>>) when byte0 in 128..254 do
    {l, _} = determine_l_and_a_l(byte0)
    <<value::binary-size(l), rest2::binary>> = rest
    {decode_integer(<<byte0, value::binary>>), rest2}
  end

  defp decode_next_le(binary, n) do
    <<value::binary-size(n), rest::binary>> = binary
    {decode_le(value, n), rest}
  end

  defmacro __using__(_) do
    quote do
      def de_le(value, l), do: PVM.Decoder.decode_le(value, l)
    end
  end
end
