defmodule PVM.Instructions.TwoRegisters do
  alias PVM.Memory
  use PVM.Math
  use PVM.{Encoder, Decoder, Utils}
  import Bitwise, only: [&&&: 2, bsr: 2]

  # Section (A.5.9) v0.7.0
  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, w_a)}}}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    size = state.registers[r_a]

    if size == 0 do
      # The guest wants to know the current heap pointer
      {:continue,
       %{
         state
         | registers: %{state.registers | r: put_elem(state.registers.r, r_d, state.memory.current_heap_pointer)}
       }}
    else
      # The guest wants to allocate
      new_heap_pointer = state.memory.current_heap_pointer + size

      if new_heap_pointer > state.memory.max_heap_pointer do
        # Allocation failed
        {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, 0)}}}
      else
        old_heap_pointer = state.memory.current_heap_pointer
        is_writable = Memory.check_range_access?(state.memory, old_heap_pointer, size, :write)

        updated_memory =
          if is_writable do
            state.memory
          else
            Memory.set_access(state.memory, old_heap_pointer, size, :write)
          end

        # Update the heap pointer in the memory struct
        updated_memory = %{updated_memory | current_heap_pointer: new_heap_pointer}

        {:continue,
         %{
           state
           | memory: updated_memory,
             registers: %{state.registers | r: put_elem(state.registers.r, r_d, old_heap_pointer)}
         }}
      end
    end
  end

  def execute(:count_set_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    bits_sum = count_set_bits(w_a)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, bits_sum)}}}
  end

  def execute(:count_set_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    bits_sum = count_set_bits(w_a &&& 0xFFFFFFFF)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, bits_sum)}}}
  end

  def execute(:leading_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    leading_zero_bits = leading_zeros(w_a, 8)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, leading_zero_bits)}}}
  end

  def execute(:leading_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    leading_zero_bits = leading_zeros(w_a, 4)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, leading_zero_bits)}}}
  end

  def execute(:trailing_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]

    trailing_zero_bits = count_trailing_zeros(w_a, 64)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, trailing_zero_bits)}}}
  end

  def execute(:trailing_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a] &&& 0xFFFFFFFF

    trailing_zero_bits = count_trailing_zeros(w_a, 32)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, trailing_zero_bits)}}}
  end

  def execute(:sign_extend_8, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    sign_extended = w_a |> mod(0x100) |> u2i(1) |> i2u(8)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, sign_extended)}}}
  end

  def execute(:sign_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    sign_extended = w_a |> mod(0x10000) |> u2i(2) |> i2u(8)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, sign_extended)}}}
  end

  def execute(:zero_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = state.registers[r_a]
    zero_extended = w_a |> mod(0x10000)

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, zero_extended)}}}
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

    {:continue, %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_d, reversed)}}}
  end

  # Formula (A.27) v0.7.0
  defp get_params(program, counter) do
    byte = binary_part_safe(program, counter + 1, 1) |> :binary.first()
    {mod(byte, 16) |> min(12), bsr(byte, 4) |> min(12)}
  end

  def count_trailing_zeros(0, bits), do: bits
  def count_trailing_zeros(n, _bits), do: trunc(:math.log2(n &&& -n))

  defp count_set_bits(0), do: 0
  defp count_set_bits(n) do
    count_set_bits(n &&& (n - 1)) + 1
  end
end
