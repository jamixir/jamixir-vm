defmodule PVM.Utils do
  alias Instructions.Opcode
  use PVM.Decoder

  # Formula (250) v0.4.5
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

  # Formula (251) v0.4.5
  def parse_immediate(program, counter) do
    l_x =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> rem(8)
      |> min(4)

    x_value = decode_bytes_signed(program, counter + 2, l_x)
    {x_value, l_x}
  end

  # Formula (252) v0.4.5
  def parse_second_immediate(program, counter, l_x, bitmask) do
    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))
    decode_bytes_signed(program, counter + 2 + l_x, l_y)
  end

  # Formula (252) v0.4.5
  def parse_two_immediates(program, counter, bitmask) do
    {x_value, l_x} = parse_immediate(program, counter)
    y_value = parse_second_immediate(program, counter, l_x, bitmask)
    {x_value, y_value}
  end

  # Formula (247) v0.4.5
  def sign_extend(x, n) when n > 0 and n <= 4 do
    x +
      div(x, trunc(:math.pow(2, 8 * n - 1))) *
        (trunc(:math.pow(2, 32)) - trunc(:math.pow(2, 8 * n)))
  end

  def sign_extend(x, 0), do: x

  # Formula (240) v0.4.5
  def basic_block_starts(<<>>, <<>>), do: [0]

  def basic_block_starts(program, bitmask) when is_binary(program) and is_binary(bitmask) do

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
    decode_bytes(program, start_index, count)
    |> sign_extend(count)
  end
end
