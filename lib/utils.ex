defmodule PVM.Utils do
  use PVM.{Decoder, Instructions}
  import Bitwise
  alias PVM.Instructions

  # Formula (A.2) v0.6.1
  def skip(i, bitmask) when is_binary(bitmask) do
    do_skip(i + 1, bitmask, 0)
  end

  defp do_skip(_current_pos, _bitmask, count) when count >= 24, do: 24
  defp do_skip(current_pos, bitmask, count) when current_pos >= byte_size(bitmask), do: count

  defp do_skip(current_pos, bitmask, count) do
    case binary_part(bitmask, current_pos, 1) do
      <<1>> -> count
      <<0>> -> do_skip(current_pos + 1, bitmask, count + 1)
    end
  end

  # Formula (A.15) v0.6.1
  def extend_to_64bit(x, n) when n > 0 and n in [0, 1, 2, 3, 4, 8],
    do: x + (x >>> (8 * n - 1)) * ((1 <<< 64) - (1 <<< (8 * n)))

  def extend_to_64bit(x, 0), do: x

  # Formula (A.4) v0.6.1
  def basic_block_starts(<<>>, <<>>), do: [0]

  def basic_block_starts(program, bitmask) when is_binary(program) and is_binary(bitmask) do
    [0] ++
      Enum.reduce(0..(byte_size(bitmask) - 1), [], fn i, acc ->
        case binary_part(bitmask, i, 1) do
          <<1>> ->
            # If it's an opcode, check if it's a termination instruction
            opcode = program |> binary_part(i, 1) |> :binary.first() |> op()

            if Instructions.termination_instruction?(opcode) do
              acc ++ [i + 1 + skip(i, bitmask)]
            else
              acc
            end

          _ ->
            acc
        end
      end)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes.
  Returns the decoded number.
  """
  def decode_bytes(program, start_index, count) when is_binary(program) do
    binary_part(program, start_index, count)
    |> de_le(count)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes,
  and applies sign extension.
  Returns the decoded and sign-extended number.
  """
  def decode_bytes_signed(program, start_index, count) when is_binary(program) do
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

  @doc """
  Rotates a value by the specified number of bits in the given direction.

  ## Parameters
    * `value` - The number to rotate
    * `shift` - The number of positions to rotate by
    * `bits` - The bit width of the number (e.g., 32 or 64)
    * `direction` - Either `:left` or `:right`

  ## Examples

      iex> number = 0b10110011
      iex> PVM.Instructions.ThreeRegisters.rotate(number, 2, 8, :right)
      0b11001110

      iex> number = 0b10110011
      iex> PVM.Instructions.ThreeRegisters.rotate(number, 2, 8, :left)
      0b11101100

  """
  def rotate(value, shift, bits, direction) do
    mask = (1 <<< bits) - 1
    shift = if direction == :right, do: shift, else: bits - shift |> rem(bits)
    shifted_part = value <<< shift
    wrapped_part = value >>> (bits - shift)
    (shifted_part ||| wrapped_part) &&& mask
  end

  defmacro __using__(_) do
    quote do
      def to_64bit(value, num_bytes), do: PVM.Utils.extend_to_64bit(value, num_bytes)

      def decode_bytes(program, start_index, count),
        do: PVM.Utils.decode_bytes(program, start_index, count)

      def decode_bytes_signed(program, start_index, count),
        do: PVM.Utils.decode_bytes_signed(program, start_index, count)

      def skip(counter, bitmask), do: PVM.Utils.skip(counter, bitmask)

      def next_counter(output, prev_counter, bitmask),
        do: PVM.Utils.next_counter(output, prev_counter, bitmask)

      def basic_block_starts(program, bitmask), do: PVM.Utils.basic_block_starts(program, bitmask)

      def rotate(value, shift, bits, direction), do: PVM.Utils.rotate(value, shift, bits, direction)
    end
  end
end
