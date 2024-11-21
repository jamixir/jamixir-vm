defmodule PVM.Utils do
  use Instructions
  use PVM.Decoder
  import Bitwise

  # Formula (A.2) v0.5
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

  # Formula (A.11) v0.5
  def sign_extend(x, n) when n > 0 and n <= 4,
    do: x + div(x, 1 <<< (8 * n - 1)) * ((1 <<< 64) - (1 <<< (8 * n)))

  def sign_extend(x, 0), do: x

  # Formula (A.4) v0.5
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

  @doc """
  Determines the next counter position based on execution output.
  For successful execution:
    - Uses instruction's counter if provided (jumps)
    - Otherwise advances by 1 + skip
  For halt/panic, keeps the original counter.
  """
  def next_counter(%{exit_status: status, counter: _counter}, state)
      when status in [:halt, :panic] do
    state.counter
  end

  def next_counter(%{counter: counter}, state) do
    if counter != state.counter do
      counter
    else
      state.counter + 1 + skip(state.counter, state.bitmask)
    end
  end
end
