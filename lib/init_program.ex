defmodule PVM.InitProgram do
  alias PVM.{Decoder, Memory, Registers}
  import Bitwise

  # Constants from A.31
  def zp, do: 1 <<< 14
  def zq, do: 1 <<< 16
  def zi, do: 1 <<< 24

  def parse_program_segments(binary) when byte_size(binary) >= 15 do
    with {:ok, o_size, rest} <- read_size(binary, 3),
         {:ok, w_size, rest} <- read_size(rest, 3),
         {:ok, z, rest} <- read_size(rest, 2),
         {:ok, s, rest} <- read_size(rest, 3),
         {:ok, o, rest} <- read_bytes(rest, o_size),
         {:ok, w, rest} <- read_bytes(rest, w_size),
         {:ok, c_size, rest} <- read_size(rest, 4),
         {:ok, c} <- read_final_segment(rest, c_size) do
      {:ok, {o_size, o, w_size, w, z, s, c}}
    else
      _ -> {:error, :invalid_format}
    end
  end

  def parse_program_segments(_), do: {:error, :insufficient_bytes}

  def initialize_program(program, a) do
    with {:ok, {o_size, o, w_size, w, z, s, c}} <- parse_program_segments(program) do
      # Verify condition A.33
      if verify_size_constraint(o_size, w_size, z, s) do
        registers = initialize_registers(a)
        memory = construct_memory(o, w, a, z, s)
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

  def q(x), do: ceil(x / zq()) * zq()
  def p(x), do: ceil(x / zp()) * zp()

  # Implements condition A.33: 5Zq + Q(|o|) + Q(|w| + zZp) + Q(s) + Zi ≤ 2^32
  def verify_size_constraint(o_size, w_size, z, s) do
    q(o_size) + q(w_size + z * zp()) + q(s) <= (1 <<< 32) - 5 * zq() - zi()
  end

  def initialize_registers(a) do
    # Implements A.35 register initialization
    %Registers{r0: 0xFFFF_0000, r1: 0xFEFE_0000, r7: 0xFEFF_0000, r8: byte_size(a)}
  end

  @spec construct_memory(binary(), binary(), binary(), integer(), integer()) :: Memory.t()
  def construct_memory(o, w, a, z, s) do
    o_size = byte_size(o)
    w_size = byte_size(w)
    a_size = byte_size(a)
    memory = Memory.set_page_size(%Memory{}, zp())

    memory =
      memory
      |> write_with_access(zq(), o, :read)
      |> write_with_access(2 * zq() + q(o_size), w, :write)
      |> write_with_access(1 <<< (32 - zq() - zi()), a, :read)

    # Set access permissions for padding regions
    memory =
      memory
      |> Memory.set_access(zq() + o_size, p(o_size) - o_size, :read)
      |> Memory.set_access(2 * zq() + q(o_size) + w_size, p(w_size) + z * zp() - w_size, :write)
      # stack area
      |> Memory.set_access(1 <<< (32 - 2 * zq() - zi() - p(s)), p(s), :write)
      |> Memory.set_access(1 <<< (32 - zq() - zi() + a_size), p(a_size) - a_size, :read)

    memory = Memory.reset_page_size(memory)
    # Set remaining memory as inaccessible
    Memory.set_default_access(memory, nil)
  end

  @spec write_with_access(Memory.t(), integer(), binary(), :read | :write | nil) :: Memory.t()
  defp write_with_access(memory, address, data, access) do
    size = byte_size(data)
    {:ok, memory} = Memory.write(memory, address, data)
    Memory.set_access(memory, address, size, access)
  end
end
