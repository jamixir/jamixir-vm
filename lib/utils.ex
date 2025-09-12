defmodule PVM.Utils do
  use PVM.{Decoder, Instructions}
  import Bitwise
  alias PVM.Instructions

  @bit_positions (for byte <- 0..255 do
                    cond do
                      (byte &&& 0x80) != 0 -> 0
                      (byte &&& 0x40) != 0 -> 1
                      (byte &&& 0x20) != 0 -> 2
                      (byte &&& 0x10) != 0 -> 3
                      (byte &&& 0x08) != 0 -> 4
                      (byte &&& 0x04) != 0 -> 5
                      (byte &&& 0x02) != 0 -> 6
                      (byte &&& 0x01) != 0 -> 7
                      # This shouldn't happen since we only call when byte != 0
                      true -> nil
                    end
                  end)
                 |> List.to_tuple()

  # Formula (A.3) v0.7.0
  def skip(i, bitmask) do
    l = bit_size(bitmask)
    start_pos = i + 1

    if start_pos >= l do
      0
    else
      <<_::size(start_pos), rest::bitstring>> = bitmask
      do_skip(rest, 0, min(24, bit_size(rest)))
    end
  end

  defp do_skip(<<>>, count, _max_count), do: count
  defp do_skip(_bits, count, max_count) when count >= max_count, do: max_count

  # process byte (8 bits) at a time
  defp do_skip(bits, count, max_count)
       when bit_size(bits) >= 8 and count + 8 <= max_count do
    <<byte::8, rest::bitstring>> = bits

    case byte do
      0 ->
        do_skip(rest, count + 8, max_count)

      _ ->
        # Found a 1 bit in this byte, find exactly which bit
        count + find_first_bit_in_byte(byte)
    end
  end

  # if less than 8 bits remain, fallback to bit-by-bit
  defp do_skip(<<1::1, _::bitstring>>, count, _max_count), do: count

  defp do_skip(<<0::1, rest::bitstring>>, count, max_count) do
    do_skip(rest, count + 1, max_count)
  end

  defp find_first_bit_in_byte(byte), do: elem(@bit_positions, byte)

  # Formula (A.16) v0.7.0
  def extend_to_64bit(x, n) when n in 1..4 or n == 8,
    do: x + (x >>> (8 * n - 1)) * ((1 <<< 64) - (1 <<< (8 * n)))

  def extend_to_64bit(x, 0), do: x

  # Formula (A.5) v0.7.0
  def basic_block_starts(<<>>, <<>>), do: %{0 => nil}

  def basic_block_starts(program, bitmask, batch_size \\ 512)
      when is_bitstring(program) and is_bitstring(bitmask) do
    initial_map = %{0 => nil}
    process_batches(program, bitmask, bit_size(bitmask), 0, batch_size, initial_map)
  end

  defp process_batches(_program, _bitmask, bitmask_size, pos, _batch_size, acc)
       when pos >= bitmask_size,
       do: acc

  defp process_batches(program, bitmask, bitmask_size, pos, batch_size, acc) do
    chunk_size = min(batch_size, bitmask_size - pos)
    <<_skip::size(pos), chunk::bitstring-size(chunk_size), _rest::bits>> = bitmask

    {new_pos, new_acc} = process_bits(program, bitmask, chunk, pos, acc)

    # Recurse into the next batch
    process_batches(program, bitmask, bitmask_size, new_pos, batch_size, new_acc)
  end

  defp process_bits(_program, _bitmask, <<>>, pos, acc), do: {pos, acc}

  defp process_bits(program, bitmask, <<1::1, rest::bitstring>>, pos, acc) do
    <<opcode_byte>> = program |> binary_part_safe(pos, 1)
    # Only check termination instructions when bit is 1
    opcode = op(opcode_byte)

    new_acc =
      if Instructions.termination_instruction?(opcode) do
        Map.put(acc, pos + 1 + skip(pos, bitmask), nil)
      else
        acc
      end

    process_bits(program, bitmask, rest, pos + 1, new_acc)
  end

  defp process_bits(program, bitmask, <<0::1, rest::bitstring>>, pos, acc) do
    process_bits(program, bitmask, rest, pos + 1, acc)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes.
  Returns the decoded number.
  """
  def decode_bytes(_, _, 0), do: 0

  def decode_bytes(program, start_index, 1) when start_index + 1 <= byte_size(program) do
    <<_::binary-size(start_index), v::little-integer-size(8), _::binary>> = program
    v
  end

  def decode_bytes(program, start_index, 2) when start_index + 2 <= byte_size(program) do
    <<_::binary-size(start_index), v::little-integer-size(16), _::binary>> = program
    v
  end

  def decode_bytes(program, start_index, 3) when start_index + 3 <= byte_size(program) do
    <<_::binary-size(start_index), v::little-integer-size(24), _::binary>> = program
    v
  end

  def decode_bytes(program, start_index, 4) when start_index + 4 <= byte_size(program) do
    <<_::binary-size(start_index), v::little-integer-size(32), _::binary>> = program
    v
  end

  def decode_bytes(program, start_index, count)
      when is_binary(program) and start_index + count <= byte_size(program) do
    <<_::binary-size(start_index), v::little-integer-size(8 * count), _::binary>> = program
    v
  end

  def decode_bytes(program, start_index, count) when is_binary(program), do:
    binary_part_safe(program, start_index, count) |> de_le(count)


  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes,
  and applies sign extension.
  Returns the decoded and sign-extended number.
  """
  def decode_and_extend(program, start_index, count) when is_binary(program) do
    decode_bytes(program, start_index, count)
    |> extend_to_64bit(count)
  end

  @doc """
  Determines the next counter position based on execution output.
  For successful execution:
    - Uses instruction's counter if provided (jumps)
    - Otherwise advances by 1 + skip
  For halt/panic, keeps the original counter.
  """
  def next_counter(%{exit_reason: reason, counter: _counter}, prev_counter, _bitmask)
      when reason in [:halt, :panic] do
    prev_counter
  end

  # Formula (A.7) v0.7.0
  def next_counter(%{counter: counter}, prev_counter, bitmask) do
    if counter != prev_counter do
      counter
    else
      prev_counter + 1 + skip(prev_counter, bitmask)
    end
  end

  def rotate(value, shift, bits, direction) do
    shift = rem(shift, bits)
    mask = (1 <<< bits) - 1

    value = value &&& mask

    case direction do
      :left ->
        left_part = value <<< shift &&& mask
        right_part = value >>> (bits - shift)
        left_part ||| right_part

      :right ->
        right_part = value >>> shift
        left_part = value <<< (bits - shift) &&& mask
        right_part ||| left_part
    end
  end

  def binary_part_safe(binary, n, count) when is_integer(n) and is_integer(count) do
    size = byte_size(binary)

    cond do
      n >= size ->
        <<0::size(count * 8)>>

      true ->
        remaining = size - n

        if remaining >= count do
          binary_part(binary, n, count)
        else
          part = binary_part(binary, n, remaining)
          pad_bits = (count - remaining) * 8
          part <> <<0::size(pad_bits)>>
        end
    end
  end

  @compile {:inline, bool_to_int: 1}
  @compile {:inline, binary_part_safe: 3}
  @compile {:inline, decode_bytes: 3}
  @compile {:inline, find_first_bit_in_byte: 1}
  def bool_to_int(true), do: 1
  def bool_to_int(false), do: 0

  defmacro __using__(_) do
    quote do
      def to_64bit(value, num_bytes), do: PVM.Utils.extend_to_64bit(value, num_bytes)

      def decode_bytes(program, start_index, count),
        do: PVM.Utils.decode_bytes(program, start_index, count)

      def decode_and_extend(program, start_index, count),
        do: PVM.Utils.decode_and_extend(program, start_index, count)

      def skip(counter, bitmask), do: PVM.Utils.skip(counter, bitmask)

      def next_counter(output, prev_counter, bitmask),
        do: PVM.Utils.next_counter(output, prev_counter, bitmask)

      def basic_block_starts(program, bitmask, batch_size \\ 512),
        do: PVM.Utils.basic_block_starts(program, bitmask, batch_size)

      def rotate(value, shift, bits, direction),
        do: PVM.Utils.rotate(value, shift, bits, direction)

      def binary_part_safe(binary, n, count),
        do: PVM.Utils.binary_part_safe(binary, n, count)
    end
  end
end
