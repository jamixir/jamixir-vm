defmodule PVM.InitProgram do
  alias PVM.{Decoder, Memory, Registers}
  import Bitwise
  require Logger

  # Constants from A.31
  @zp 0x4000
  @zq 0x10000
  @zi 0x1000000
  # 2^32
  @max_addr 0x100000000

  def zp, do: @zp
  def zq, do: @zq
  def zi, do: @zi
  def max_addr, do: @max_addr

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

  def q(x), do: ceil(x / @zq) * @zq
  def p(x), do: ceil(x / @zp) * @zp

  # Implements condition A.33: 5Zq + Q(|o|) + Q(|w| + zZp) + Q(s) + Zi ≤ 2^32
  def verify_size_constraint(o_size, w_size, z, s) do
    q(o_size) + q(w_size + z * @zp) + q(s) <= (1 <<< 32) - 5 * @zq - @zi
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

    regions = [
      # Program text region: [Zq, Zq + |o|] => R
      {@zq, @zq + o_size, o, :read},
      # Program text padding: [Zq + |o|, Zq + P(|o|)] => R
      {@zq + o_size, @zq + p(o_size), nil, :read},

      # Data region: [2Zq + Q(|o|), 2Zq + Q(|o|) + |w|] => W
      {2 * @zq + q(o_size), 2 * @zq + q(o_size) + w_size, w, :write},
      # Data padding: [2Zq + Q(|o|) + |w|, 2Zq + Q(|o|) + P(|w|) + zZp] => W
      {2 * @zq + q(o_size) + w_size, 2 * @zq + q(o_size) + p(w_size) + z * @zp, nil, :write},

      # Stack region: [2^32 - 2Zq - Zi - P(s), 2^32 - 2Zq - Zi] => W
      {@max_addr - 2 * @zq - @zi - p(s), @max_addr - 2 * @zq - @zi, nil, :write},

      # Args region: [2^32 - Zq - Zi, 2^32 - Zq - Zi + |a|] => R
      {@max_addr - @zq - @zi, @max_addr - @zq - @zi + a_size, a, :read},
      # Args padding: [2^32 - Zq - Zi + |a|, 2^32 - Zq - Zi + P(|a|)] => R
      {@max_addr - @zq - @zi + a_size, @max_addr - @zq - @zi + p(a_size), nil, :read}
    ]

    memory = Memory.set_page_size(%Memory{}, @zp)

    memory =
      Enum.reduce(regions, memory, fn
        {start, end_, nil, access}, mem ->
          Memory.set_access(mem, start, end_ - start, access)

        {start, _end, data, access}, mem ->
          {:ok, mem} = Memory.write(mem, start, data)
          Memory.set_access(mem, start, byte_size(data), access)
      end)

    memory
    |> Memory.reset_page_size()
    # Set remaining memory as inaccessible
    |> Memory.set_default_access(nil)
  end
end
