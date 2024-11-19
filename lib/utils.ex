defmodule PVM.Utils do
  alias Instructions.Opcode
  use Codec.Decoder

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

  def parse_immediate(program, counter) do
    l_x = min(4, rem(binary_part(program, counter + 1, 1) |> :binary.first(), 8))
    x_value = decode_bytes_signed(program, counter + 2, l_x)
    {x_value, l_x}
  end

  def parse_second_immediate(program, counter, l_x, bitmask) do
    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))
    y_value = decode_bytes_signed(program, counter + 2 + l_x, l_y)
    {y_value, l_y}
  end

  def parse_two_immediates(program, counter, bitmask) do
    {x_value, l_x} = parse_immediate(program, counter)
    {y_value, l_y} = parse_second_immediate(program, counter, l_x, bitmask)
    {x_value, y_value, 2 + l_x + l_y}
  end

  # Implements the N₂₈ₙ → N₂₃₂ formula from spec (241)
  def sign_extend(x, n) when n > 0 and n <= 4 do
    x +
      div(x, trunc(:math.pow(2, 8 * n - 1))) *
        (trunc(:math.pow(2, 32)) - trunc(:math.pow(2, 8 * n)))
  end

  def sign_extend(x, 0), do: x

  @doc """
  Builds the set of basic block start indices (ϖ).
  Returns [0] ++ [n + 1 + skip(n)] for each n where:
  - n is an index in the program
  - bitmask[n] = 1 (marks an opcode)
  - program[n] decodes to a termination instruction

  Indices are returned in order of appearance in the program.
  """

  def basic_block_starts(<<>>, <<>>), do: [0]

  def basic_block_starts(program, bitmask) when is_binary(program) and is_binary(bitmask) do
    # Always start with [0]
    # Check each program index in order
    [0] ++
      Enum.reduce(0..(byte_size(bitmask) - 1), [], fn i, acc ->
        case binary_part(bitmask, i, 1) do
          <<1>> ->
            # If it's an opcode, check if it's a termination instruction
            opcode = program |> binary_part(i, 1) |> :binary.first() |> Opcode.from_byte()

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

  def get_register_index(program, counter) do
    min(12, rem(binary_part(program, counter + 1, 1) |> :binary.first(), 16))
  end

  def parse_address(program, counter, bitmask) do
    l_x = min(4, skip(counter, bitmask) - 1)
    decode_bytes_signed(program, counter + 2, l_x)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes.
  Returns the decoded number.
  """
  def decode_bytes(program, start_index, count) when is_binary(program) and count > 0 do
    binary_part(program, start_index, count)
    |> de_le(count)
  end

  @doc """
  Decodes a little-endian number from a binary starting at start_index for count bytes,
  and applies sign extension.
  Returns the decoded and sign-extended number.
  """
  def decode_bytes_signed(program, start_index, count) when is_binary(program) and count > 0 do
    binary_part(program, start_index, count)
    |> de_le(count)
    |> sign_extend(count)
  end
end
