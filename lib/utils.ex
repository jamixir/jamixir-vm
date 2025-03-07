defmodule PVM.Utils do
  use PVM.{Decoder, Instructions}
  import Bitwise
  alias PVM.Instructions

  # Formula (A.2) v0.6.1
  def skip(i, bitmask) do
    l = bit_size(bitmask)
    do_skip(i + 1, bitmask, 0, l)
  end

  # Binary version
  defp do_skip(_current_pos, _bitmask, count, _l) when count >= 24, do: 24

  defp do_skip(current_pos, _bitmask, count, l) when current_pos >= l, do: count

  defp do_skip(current_pos, bitmask, count, l) do
    <<_::size(current_pos), bit::1, _::bits>> = bitmask

    case bit do
      1 -> count
      0 -> do_skip(current_pos + 1, bitmask, count + 1, l)
    end
  end

  # Formula (A.15) v0.6.1
  def extend_to_64bit(x, n) when n > 0 and n in [0, 1, 2, 3, 4, 8],
    do: x + (x >>> (8 * n - 1)) * ((1 <<< 64) - (1 <<< (8 * n)))

  def extend_to_64bit(x, 0), do: x

  # Formula (A.4) v0.6.1
  def basic_block_starts(<<>>, <<>>), do: [0]

  def basic_block_starts(program, bitmask) when is_bitstring(program) and is_bitstring(bitmask) do
    [0] ++
      Enum.reduce(0..(bit_size(bitmask) - 1), [], fn i, acc ->
        <<_::size(i), bit::1, _::bits>> = bitmask

        case bit do
          1 ->
            opcode = program |> binary_part_safe(i, 1) |> :binary.first() |> op()

            if Instructions.termination_instruction?(opcode) do
              acc ++ [i + 1 + skip(i, bitmask)]
            else
              acc
            end

          0 ->
            acc
        end
      end)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes.
  Returns the decoded number.
  """
  def decode_bytes(program, start_index, count) when is_binary(program) do
    binary_part_safe(program, start_index, count)
    |> de_le(count)
  end

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
    case binary do
      <<_prefix::binary-size(n), rest::binary>> = _full ->
        case byte_size(rest) do
          size when size >= count ->
            binary_part(rest, 0, count)

          remaining ->
            padding_size = count - remaining
            rest <> <<0::size(padding_size * 8)>>
        end

      _ ->
        <<0::size(count * 8)>>
    end
  end

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

      def basic_block_starts(program, bitmask), do: PVM.Utils.basic_block_starts(program, bitmask)

      def rotate(value, shift, bits, direction),
        do: PVM.Utils.rotate(value, shift, bits, direction)

      def binary_part_safe(binary, n, count),
        do: PVM.Utils.binary_part_safe(binary, n, count)
    end
  end
end
