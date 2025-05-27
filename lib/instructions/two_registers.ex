defmodule PVM.Instructions.TwoRegisters do
  alias PVM.{Registers, Memory}
  use PVM.Math
  use PVM.{Encoder, Decoder, Utils}
  import Bitwise, only: [&&&: 2, bsr: 2]
  # Section (A.5.9) v0.6.1

  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, w_a)}}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    size = Registers.get(state.registers, r_a)

    IO.puts("\n=== SBRK EXECUTION ===")
    IO.puts("Register r_d: #{r_d}, Register r_a: #{r_a}")
    IO.puts("Requested size: #{size}")
    IO.puts("Current heap pointer: #{state.memory.current_heap_pointer}")
    IO.puts("Max heap pointer: #{state.memory.max_heap_pointer}")

    if size == 0 do
      IO.puts("Size is 0 - returning current heap pointer")
      IO.puts("Returning: #{state.memory.current_heap_pointer}")
      IO.puts("=== SBRK END (query) ===\n")

      # The guest wants to know the current heap pointer
      {:continue, %{state | registers: Registers.set(state.registers, r_d, state.memory.current_heap_pointer)}}
    else
      # The guest wants to allocate
      new_heap_pointer = state.memory.current_heap_pointer + size

      IO.puts("Attempting allocation of #{size} bytes")
      IO.puts("New heap pointer would be: #{new_heap_pointer}")

      if new_heap_pointer > state.memory.max_heap_pointer do
        IO.puts("ALLOCATION FAILED - exceeds max heap pointer")
        IO.puts("Max allowed: #{state.memory.max_heap_pointer}, requested: #{new_heap_pointer}")
        IO.puts("Returning: 0")
        IO.puts("=== SBRK END (failed) ===\n")

        # Allocation failed
        {:continue, %{state | registers: Registers.set(state.registers, r_d, 0)}}
      else
        # Allocation succeeded - return old heap pointer and update current pointer
        old_heap_pointer = state.memory.current_heap_pointer

        IO.puts("ALLOCATION SUCCEEDED")
        IO.puts("Old heap pointer (returning): #{old_heap_pointer}")

        # Calculate pages to mark as writable
        start_page = div(state.memory.current_heap_pointer, state.memory.page_size)
        end_page = div(new_heap_pointer - 1, state.memory.page_size)
        pages_needed = end_page - start_page + 1

        IO.puts("Page calculations:")
        IO.puts("  Page size: #{state.memory.page_size}")
        IO.puts("  Start address: #{state.memory.current_heap_pointer} -> Start page: #{start_page}")
        IO.puts("  End address: #{new_heap_pointer - 1} -> End page: #{end_page}")
        IO.puts("  Pages needed: #{pages_needed}")

        # Mark the allocated pages as writable
        new_memory = Memory.set_access_by_page(state.memory, start_page, pages_needed, :write)

        IO.puts("Marked pages #{start_page} to #{start_page + pages_needed - 1} as writable")

        # Update the heap pointer in the memory struct
        updated_memory = %{new_memory | current_heap_pointer: new_heap_pointer}

        IO.puts("Updated current heap pointer to: #{new_heap_pointer}")
        IO.puts("=== SBRK END (success) ===\n")

        {:continue, %{
          state
          | memory: updated_memory,
            registers: Registers.set(state.registers, r_d, old_heap_pointer)
        }}
      end
    end
  end

  def execute(:count_set_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    bits_sum = w_a |> Integer.digits(2) |> Enum.sum()

    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:count_set_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    bits_sum = (w_a &&& 0xFFFFFFFF) |> Integer.digits(2) |> Enum.sum()

    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:leading_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    binary_digits = Integer.digits(w_a, 2)
    leading_zero_bits = if w_a == 0, do: 64, else: 64 - length(binary_digits)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:leading_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    leading_zero_bits = if w_a == 0, do: 32, else: 32 - length(Integer.digits(w_a, 2))

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:trailing_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    trailing_zero_bits = count_trailing_zeros(w_a, 64)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:trailing_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a) &&& 0xFFFFFFFF

    trailing_zero_bits = count_trailing_zeros(w_a, 32)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:sign_extend_8, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    sign_extended = w_a |> mod(0x100) |> u2i(1) |> i2u(8)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:sign_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    sign_extended = w_a |> mod(0x10000) |> u2i(2) |> i2u(8)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:zero_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    zero_extended = w_a |> mod(0x10000)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, zero_extended)}}
  end

  def execute(:reverse_bytes, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    value = <<w_a::64-little>>

    <<reversed::64-little>> =
      value
      |> :binary.bin_to_list()
      |> Enum.reverse()
      |> :binary.list_to_bin()

    {:continue, %{state | registers: Registers.set(state.registers, r_d, reversed)}}
  end

  # Formula (A.26) v0.6.1
  defp get_params(program, counter) do
    byte = binary_part_safe(program, counter + 1, 1) |> :binary.first()
    {mod(byte, 16) |> min(12), bsr(byte, 4) |> min(12)}
  end

  def count_trailing_zeros(0, bits), do: bits
  def count_trailing_zeros(n, _bits), do: trunc(:math.log2(n &&& -n))
end
