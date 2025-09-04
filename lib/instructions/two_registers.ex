defmodule PVM.Instructions.TwoRegisters do
  alias PVM.Registers
  alias PVM.Memory
  use PVM.Math
  use PVM.{Encoder, Decoder, Utils}
  import Bitwise, only: [&&&: 2, bsr: 2]

  # Section (A.5.9) v0.7.0
  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    Registers.put_elem(state.registers.r, r_d, w_a)
    {:continue, state}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    size = state.registers[r_a]

    handle_sbrk(size, r_d, state)
  end

  def execute(:count_set_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    bits_sum = count_set_bits(w_a)
    Registers.put_elem(state.registers.r, r_d, bits_sum)
    {:continue, state}
  end

  def execute(:count_set_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    bits_sum = count_set_bits(w_a &&& 0xFFFFFFFF)
    Registers.put_elem(state.registers.r, r_d, bits_sum)
    {:continue, state}
  end

  def execute(:leading_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    leading_zero_bits = leading_zeros(w_a, 8)
    Registers.put_elem(state.registers.r, r_d, leading_zero_bits)
    {:continue, state}
  end

  def execute(:leading_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    leading_zero_bits = leading_zeros(w_a, 4)

    Registers.put_elem(state.registers.r, r_d, leading_zero_bits)
    {:continue, state}
  end

  def execute(:trailing_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    trailing_zero_bits = count_trailing_zeros(w_a, 64)
    Registers.put_elem(state.registers.r, r_d, trailing_zero_bits)
    {:continue, state}
  end

  def execute(:trailing_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a] &&& 0xFFFFFFFF

    trailing_zero_bits = count_trailing_zeros(w_a, 32)

    Registers.put_elem(state.registers.r, r_d, trailing_zero_bits)
    {:continue, state}
  end

  def execute(:sign_extend_8, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    sign_extended = w_a |> mod(0x100) |> u2i(1) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, sign_extended)
    {:continue, state}
  end

  def execute(:sign_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    sign_extended = w_a |> mod(0x10000) |> u2i(2) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, sign_extended)
    {:continue, state}
  end

  def execute(:zero_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    zero_extended = w_a |> mod(0x10000)
    Registers.put_elem(state.registers.r, r_d, zero_extended)
    {:continue, state}
  end

  def execute(:reverse_bytes, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    value = <<w_a::64-little>>

    <<reversed::64-little>> =
      value
      |> :binary.bin_to_list()
      |> Enum.reverse()
      |> :binary.list_to_bin()

    Registers.put_elem(state.registers.r, r_d, reversed)
    {:continue, state}
  end

  # Handle sbrk with pattern matching for size == 0 (query heap pointer)
  defp handle_sbrk(0, r_d, state) do
    # The guest wants to know the current heap pointer
    Registers.put_elem(state.registers.r, r_d, state.memory.current_heap_pointer)
    {:continue, state}
  end

  # Handle sbrk for size > 0 (allocate memory)
  defp handle_sbrk(size, r_d, state) when size > 0 do
    new_heap_pointer = state.memory.current_heap_pointer + size

    handle_allocation(
      new_heap_pointer > state.memory.max_heap_pointer,
      size,
      r_d,
      state,
      new_heap_pointer
    )
  end

  defp handle_allocation(true, _size, r_d, state, _new_heap_pointer) do
    # Allocation failed
    Registers. put_elem(state.registers.r, r_d, 0)
    {:continue, state}
  end

  defp handle_allocation(false, size, r_d, state, new_heap_pointer) do
    old_heap_pointer = state.memory.current_heap_pointer
    is_writable = Memory.check_range_access?(state.memory, old_heap_pointer, size, :write)

    updated_memory = ensure_writable_memory(is_writable, state.memory, old_heap_pointer, size)
    updated_memory = %{updated_memory | current_heap_pointer: new_heap_pointer}
    Registers.put_elem(state.registers.r, r_d, old_heap_pointer)
    {:continue, %{state | memory: updated_memory}}
  end

  defp ensure_writable_memory(true, memory, _old_heap_pointer, _size), do: memory

  defp ensure_writable_memory(false, memory, old_heap_pointer, size) do
    Memory.set_access(memory, old_heap_pointer, size, :write)
  end

  # Formula (A.27) v0.7.0
  defp get_params(program, counter) do
    <<byte>> = binary_part_safe(program, counter + 1, 1)
    {mod(byte, 16) |> min(12), bsr(byte, 4) |> min(12)}
  end

  def count_trailing_zeros(0, bits), do: bits
  def count_trailing_zeros(n, _bits), do: trunc(:math.log2(n &&& -n))

  defp count_set_bits(0), do: 0

  defp count_set_bits(n) do
    count_set_bits(n &&& n - 1) + 1
  end
end
