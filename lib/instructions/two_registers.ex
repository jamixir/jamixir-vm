defmodule PVM.Instructions.TwoRegisters do
  alias PVM.{Registers, Memory}
  use PVM.Math
  use PVM.{Encoder, Decoder, Utils}
  import Bitwise, only: [&&&: 2, bsr: 2]
  # Section (A.5.9) v0.6.6

  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    {:continue, %{state | registers: Registers.set(state.registers, r_d, w_a)}}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    bytes_needed = Registers.get(state.registers, r_a)
    pages_needed = ceil(bytes_needed / state.memory.page_size)

    case Memory.find_free_memory(state.memory, pages_needed) do
      nil ->
        {:continue, state}

      start_page ->
        start_address = start_page * state.memory.page_size

        new_memory = Memory.set_access_by_page(state.memory, start_page, pages_needed, :write)

        {:continue,
         %{
           state
           | memory: new_memory,
             registers: Registers.set(state.registers, r_d, start_address)
         }}
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

  # Formula (A.27) v0.6.6
  defp get_params(program, counter) do
    byte = binary_part_safe(program, counter + 1, 1) |> :binary.first()
    {mod(byte, 16) |> min(12), bsr(byte, 4) |> min(12)}
  end

  def count_trailing_zeros(0, bits), do: bits
  def count_trailing_zeros(n, _bits), do: trunc(:math.log2(n &&& -n))
end
