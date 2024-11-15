defmodule PVM.Utils do
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
    x_bytes = binary_part(program, counter + 2, l_x)
    x_value = x_bytes |> de_le(l_x) |> sign_extend(l_x)
    {x_value, l_x}
  end

  def parse_second_immediate(program, counter, l_x, bitmask) do
    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))
    y_bytes = binary_part(program, counter + 2 + l_x, l_y)
    y_value = y_bytes |> de_le(l_y) |> sign_extend(l_y)
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
end
