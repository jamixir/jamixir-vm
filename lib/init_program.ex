defmodule PVM.InitProgram do
  alias PVM.{Memory, Registers}
  require Logger

  # Formula (4.25) v0.6.1
  @zp 0x1000
  # Formula (A.35) v0.6.1
  @zz 0x1_0000
  @zi 0x100_0000
  # 2^32
  @max_addr 0x1_0000_0000

  def zp, do: @zp
  def zz, do: @zz
  def zi, do: @zi
  def max_addr, do: @max_addr

  # Formula (A.34) v0.6.1
  def parse_program_segments(binary) when byte_size(binary) >= 15 do
    try do
      <<o_size::24-little, w_size::24-little, z::16-little, s::24-little, o::binary-size(o_size),
        w::binary-size(w_size), c_size::32-little, c::binary-size(c_size)>> = binary

      {:ok, {o_size, o, w_size, w, z, s, c}}
    rescue
      _ -> {:error, :invalid_format}
    end
  end

  def parse_program_segments(_), do: {:error, :insufficient_bytes}

  def initialize_program(program, a) do
    with {:ok, {o_size, o, w_size, w, z, s, c}} <- parse_program_segments(program) do
      # Verify condition A.37
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

  # Formula (A.36) v0.6.1
  def z(x), do: ceil(x / @zz) * @zz
  def p(x), do: ceil(x / @zp) * @zp

  # Formula (A.37) v0.6.1
  def verify_size_constraint(o_size, w_size, z, s) do
    z(o_size) + z(w_size + z * @zp) + z(s) <= 0x1_0000_0000 - 5 * @zz - @zi
  end

  # Formula (A.39) v0.6.1
  def initialize_registers(a) do
    %Registers{r0: 0xFFFF_0000, r1: 0xFEFE_0000, r7: 0xFEFF_0000, r8: byte_size(a)}
  end

  # Formula (A.38) v0.6.1
  @spec construct_memory(binary(), binary(), binary(), integer(), integer()) :: Memory.t()
  def construct_memory(o, w, a, z, s) do
    o_size = byte_size(o)
    w_size = byte_size(w)
    a_size = byte_size(a)

    regions = [
      # Program text region: [Zz, Zz + |o|] => R
      {@zz, @zz + o_size, o, :read},
      # Program text padding: [Zz + |o|, Zz + P(|o|)] => R
      {@zz + o_size, @zz + p(o_size), nil, :read},

      # Data region: [2Zz + Z(|o|), 2Zz + Z(|o|) + |w|] => W
      {2 * @zz + z(o_size), 2 * @zz + z(o_size) + w_size, w, :write},
      # Data padding: [2Zz + Z(|o|) + |w|, 2Zz + Z(|o|) + P(|w|) + zZp] => W
      {2 * @zz + z(o_size) + w_size, 2 * @zz + z(o_size) + p(w_size) + z * @zp, nil, :write},

      # Stack region: [2^32 - 2Zz - Zi - P(s), 2^32 - 2Zz - Zi] => W
      {@max_addr - 2 * @zz - @zi - p(s), @max_addr - 2 * @zz - @zi, nil, :write},

      # Args region: [2^32 - Zz - Zi, 2^32 - Zz - Zi + |a|] => R
      {@max_addr - @zz - @zi, @max_addr - @zz - @zi + a_size, a, :read},
      # Args padding: [2^32 - Zz - Zi + |a|, 2^32 - Zz - Zi + P(|a|)] => R
      {@max_addr - @zz - @zi + a_size, @max_addr - @zz - @zi + p(a_size), nil, :read}
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
