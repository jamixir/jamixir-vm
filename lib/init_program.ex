defmodule PVM.InitProgram do
  alias PVM.PreMemory
  alias PVM.{Memory, Registers}
  require Logger
  import PVM.Memory.Constants

  # Formula (4.25) v0.6.1
  def zp, do: page_size()
  # Formula (A.35) v0.6.1
  def zz, do: min_allowed_address()
  # Formula (A.35) v0.6.1
  def zi, do: 0x100_0000
  def max_addr, do: memory_size()

  # Formula (A.37) v0.6.6
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

  # Formula (A.36) v0.6.6
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
  def z(x), do: ceil(x / zz()) * zz()
  def p(x), do: ceil(x / zp()) * zp()

  # Formula (A.37) v0.6.1
  def verify_size_constraint(o_size, w_size, z, s) do
    z(o_size) + z(w_size + z * zp()) + z(s) <= 0x1_0000_0000 - 5 * zz() - zi()
  end

  # Formula (A.39) v0.6.1
  def initialize_registers(a) do
    %Registers{
      r0: 0xFFFF_0000,
      r1: 0xFEFE_0000,
      r7: 0xFEFF_0000,
      r8: byte_size(a)
    }
  end

  def boundaries(o_size, w_size, a_size, z, s),
    do: %{
      # Program text region boundaries
      program_text_start: zz(),
      program_text_end: zz() + o_size,
      program_text_padding_end: zz() + p(o_size),

      # Data region boundaries
      data_start: 2 * zz() + z(o_size),
      data_end: 2 * zz() + z(o_size) + w_size,
      data_padding_end: 2 * zz() + z(o_size) + p(w_size) + z * zp(),

      # Stack region boundaries
      stack_start: max_addr() - 2 * zz() - zi() - p(s),
      stack_end: max_addr() - 2 * zz() - zi(),

      # Args region boundaries
      args_start: max_addr() - zz() - zi(),
      args_end: max_addr() - zz() - zi() + a_size,
      args_padding_end: max_addr() - zz() - zi() + p(a_size),

      # End of memory
      memory_end: max_addr()
    }

  def memory_regions(o, w, a, z, s) do
    o_size = byte_size(o)
    w_size = byte_size(w)
    a_size = byte_size(a)
    boundaries = boundaries(o_size, w_size, a_size, z, s)

    heap_start = boundaries.data_padding_end
    heap_end = boundaries.stack_start

    IO.puts("\n=== MEMORY REGIONS CALCULATION ===")
    IO.puts("Input sizes: o=#{o_size}, w=#{w_size}, a=#{a_size}, z=#{z}, s=#{s}")
    IO.puts("Calculated boundaries:")
    IO.puts("  Data padding end: #{boundaries.data_padding_end}")
    IO.puts("  Stack start: #{boundaries.stack_start}")
    IO.puts("  Heap start: #{heap_start}")
    IO.puts("  Heap end: #{heap_end}")

    IO.puts("Boundaries: #{inspect(boundaries)}")

    # notice that the nil access regions are filled in by `PreMemory.init_nil_memory()` in `construct_memory` function
    # comments below are places for easy reading

    regions = [
      # Program text region: [Zz, Zz + |o|] => R
      {boundaries.program_text_start, boundaries.program_text_end, o, :read},

      # Program text padding: [Zz + |o|, Zz + P(|o|)] => R
      {boundaries.program_text_end, boundaries.program_text_padding_end, nil, :read},

      # No access region between program text and data

      # Data region: [2Zz + Z(|o|), 2Zz + Z(|o|) + |w|] => W
      {boundaries.data_start, boundaries.data_end, w, :write},

      # Data padding: [2Zz + Z(|o|) + |w|, 2Zz + Z(|o|) + P(|w|) + zZp] => W
      {boundaries.data_end, boundaries.data_padding_end, nil, :write},

      # No access region between data and stack
      # This is the Heap area

      # Stack region: [2^32 - 2Zz - Zi - P(s), 2^32 - 2Zz - Zi] => W
      {boundaries.stack_start, boundaries.stack_end, nil, :write},

      # No access region between stack and args

      # Args region: [2^32 - Zz - Zi, 2^32 - Zz - Zi + |a|] => R
      {boundaries.args_start, boundaries.args_end, a, :read},

      # Args padding: [2^32 - Zz - Zi + |a|, 2^32 - Zz - Zi + P(|a|)] => R
      {boundaries.args_end, boundaries.args_padding_end, nil, :read}

      # No access region between args and end of memory
    ]

    {regions, %{heap_start: heap_start, heap_end: heap_end}}
  end

  # Formula (A.38) v0.6.1
  @spec construct_memory(binary(), binary(), binary(), integer(), integer()) :: Memory.t()
  def construct_memory(o, w, a, z, s) do
    {regions, heap_boundaries} = memory_regions(o, w, a, z, s)

    IO.puts("\n=== MEMORY CONSTRUCTION ===")
    IO.puts("Heap boundaries calculated:")
    IO.puts("  Heap start: #{heap_boundaries.heap_start}")
    IO.puts("  Heap end: #{heap_boundaries.heap_end}")
    IO.puts("  Heap size: #{heap_boundaries.heap_end - heap_boundaries.heap_start} bytes")

    pre_memory =
      Enum.reduce(regions, PreMemory.init_nil_memory(), fn
        {start, end_, nil, access}, mem ->
          PVM.PreMemory.set_access(mem, start, end_ - start, access)

        {start, _end, data, access}, mem ->
          mem
          |> PVM.PreMemory.write(start, data)
          |> PVM.PreMemory.set_access(start, byte_size(data), access)
      end)

    # Finalize to create the real Memory struct with optimized access ranges
    mem = PVM.PreMemory.finalize(pre_memory)

    memory = %{
      mem
      | current_heap_pointer: heap_boundaries.heap_start,
        max_heap_pointer: heap_boundaries.heap_end
    }

    IO.puts("Memory struct created with:")
    IO.puts("  Current heap pointer: #{memory.current_heap_pointer}")
    IO.puts("  Max heap pointer: #{memory.max_heap_pointer}")
    IO.puts("  Page size: #{memory.page_size}")
    IO.puts("=== MEMORY CONSTRUCTION END ===\n")

    memory
  end
end
