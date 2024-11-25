defmodule PVM.InitProgram do
  alias PVM.Memory
  alias PVM.Decoder
  import Bitwise

  # Constants from A.31
  @zp 1 <<< 14
  @zq 1 <<< 16
  @zi 1 <<< 24

  def initialize_program(binary) do
    with {:ok, o_size, rest} <- read_size(binary, 3),
         {:ok, w_size, rest} <- read_size(rest, 3),
         {:ok, z, rest} <- read_size(rest, 2),
         {:ok, s, rest} <- read_size(rest, 3),
         {:ok, o, rest} <- read_bytes(rest, o_size),
         {:ok, w, rest} <- read_bytes(rest, w_size),
         {:ok, c_size, rest} <- read_size(rest, 4),
         {:ok, c} <- read_final_segment(rest, c_size) do
      # Verify condition A.33
      if verify_size_constraint(o_size, w_size, z,s) do
        registers = initialize_registers(o_size, z, s)
        memory = construct_memory(o, w, z, binary)
        {c, registers, memory}
      else
        nil
      end
    else
      _ -> nil
    end
  end

  # Helper functions
  defp read_size(binary, l) do
    case binary do
      <<size_bytes::binary-size(l), rest::binary>> ->
        {:ok, Decoder.decode_le(size_bytes, l), rest}

      _ ->
        :error
    end
  end

  defp read_bytes(binary, size) do
    case binary do
      <<bytes::binary-size(size), rest::binary>> -> {:ok, bytes, rest}
      _ -> :error
    end
  end

  defp read_final_segment(binary, size) when byte_size(binary) == size do
    {:ok, binary}
  end

  defp read_final_segment(_, _), do: :error

  defp q(x), do: ceil(x / @zq) * @zq
  defp p(x), do: ceil(x / @zp) * @zp

  # Implements condition A.33: 5Zq + Q(|o|) + Q(|w| + zZp) + Q(s) + Zi ≤ 2^32
  defp verify_size_constraint(o_size, w_size, z, s) do
    q(o_size) + q(w_size + z * @zp) + q(s) <= (1 <<< 32 )- (5 * @zq) - @zi
  end

  defp initialize_registers(a_size, z, s) do
    # Implements A.35 register initialization
    registers = List.duplicate(0, 13)

    registers
    |> List.replace_at(0, 1 <<< (32 - 1) <<< 16)
    |> List.replace_at(1, 1 <<< (32 - 2 * @zq - @zi))
    |> List.replace_at(7, 1 <<< (32 - @zq - @zi))
    |> List.replace_at(8, a_size)
  end

  defp construct_memory(o, w, z, a) do
    # Implements A.34 memory initialization
    # This is a simplified version - you'll need to implement the full memory layout
    Memory.new()
    |> Memory.write_segment(0, o)
    |> Memory.write_segment(@zq + byte_size(o), w)
    |> Memory.write_segment(1 <<< (32 - @zq - @zi), a)
  end
end
