defmodule PVM.Decoder do
  @moduledoc """
  A module for decoding binary data into data structures.
  """
  import Bitwise

  defp decode_little_endian(binary, l) do
    case binary do
      <<num::size(l)-unit(8)-little, _rest::binary>> -> num
      _ -> 0
    end
  end

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

  # Formula (A.2) v0.6.2
  def decode_program(bin) do
    try do
      {program, bitmask, jump_table} = decode_program!(bin)
      {:ok, {program, bitmask, jump_table}}
    rescue
      error ->
        {:error, error}
    end
  end

  def decode_program!(bin) do
    {jump_len, rest} = decode_next_integer(bin)
    {z, rest} = decode_next_le(rest, 1)
    {prog_len, rest} = decode_next_integer(rest)

    {jump_table, rest} = decode_jump_table(rest, jump_len, z)

    <<program::binary-size(prog_len), bitmask::bitstring>> = rest

    bitmask = reverse_bitmask(bitmask, byte_size(program))

    {program, bitmask, jump_table}
  end

  def reverse_bitmask(bitmask, program_length \\ nil) do
    # Simply reverse each byte in the bitmask
    reversed = reverse_each_byte(bitmask)

    if program_length do
      add_trap_bit(reversed, program_length + 1)
    else
      reversed
    end
  end

  # Add a trap bit at the specified position
  defp add_trap_bit(bitmask, trap_position) do
    # Calculate which byte and bit position we need to modify
    byte_index = div(trap_position - 1, 8)
    # 0-based position from MSB
    bit_position = 7 - rem(trap_position - 1, 8)

    bitmask_size = byte_size(bitmask)

    cond do
      # If the trap position is beyond the current bitmask size, extend it
      byte_index >= bitmask_size ->
        bytes_to_add = byte_index - bitmask_size + 1
        trap_byte = 1 <<< bit_position
        <<bitmask::binary, 0::size(8 * (bytes_to_add - 1)), trap_byte>>

      # The trap position is within the current bitmask
      true ->
        # Split the bitmask at the byte we need to modify
        <<prefix::binary-size(byte_index), byte, suffix::binary>> = bitmask
        # Set the bit at the correct position
        modified_byte = byte ||| 1 <<< bit_position
        # Reconstruct the bitmask
        <<prefix::binary, modified_byte, suffix::binary>>
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
