defmodule PVM.Instructions.TwoRegisters do
  alias PVM.{Registers, Memory, Trace}
  use PVM.Math
  use PVM.{Encoder, Decoder, Utils}
  # Section (A.5.9) v0.6.1

  def execute(:move_reg, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    Trace.instruction(state.counter, "move_reg", "w#{r_d} = w#{r_a}(#{w_a})")
    {:continue, %{state | registers: Registers.set(state.registers, r_d, w_a)}}
  end

  def execute(:sbrk, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    bytes_needed = Registers.get(state.registers, r_a)
    pages_needed = ceil(bytes_needed / state.memory.page_size)

    Trace.instruction(
      state.counter,
      "sbrk",
      "allocate #{bytes_needed} bytes (#{pages_needed} pages) requested by w#{r_a}"
    )

    case Memory.find_free_memory(state.memory, pages_needed) do
      nil ->
        Trace.instruction(state.counter, "sbrk", "allocation failed - no suitable space found")
        {:continue, state}

      start_page ->
        start_address = start_page * state.memory.page_size

        Trace.instruction(
          state.counter,
          "sbrk",
          "allocated at address #{start_address} (page #{start_page})"
        )

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
    bits_sum = w_a |> u2b(8) |> Enum.sum()

    Trace.instruction(
      state.counter,
      "count_set_bits_64",
      "w#{r_d} = popcount(w#{r_a}(#{w_a})) = #{bits_sum}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:count_set_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    bits_sum = w_a |> rem(0x1_0000_0000) |> u2b(4) |> Enum.sum()

    Trace.instruction(
      state.counter,
      "count_set_bits_32",
      "w#{r_d} = popcount32(w#{r_a}(#{w_a})) = #{bits_sum}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, bits_sum)}}
  end

  def execute(:leading_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    leading_zero_bits =
      w_a
      |> u2b(8)
      |> Enum.with_index()
      |> Enum.find_index(fn {bit, _index} -> bit == 1 end)

    Trace.instruction(
      state.counter,
      "leading_zero_bits_64",
      "w#{r_d} = count_leading_zeros(w#{r_a}(#{w_a})) = #{leading_zero_bits}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:leading_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    leading_zero_bits =
      w_a
      |> rem(0x1_0000_0000)
      |> u2b(4)
      |> Enum.with_index()
      |> Enum.find_index(fn {bit, _index} -> bit == 1 end)

    Trace.instruction(
      state.counter,
      "leading_zero_bits_32",
      "w#{r_d} = count_leading_zeros32(w#{r_a}(#{w_a})) = #{leading_zero_bits}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, leading_zero_bits)}}
  end

  def execute(:trailing_zero_bits_64, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)

    bits = w_a |> u2b(8)
    len = length(bits)

    trailing_zero_bits =
      Enum.find_index(0..(len - 1), fn i ->
        Enum.at(bits, len - 1 - i) == 1
      end)

    Trace.instruction(
      state.counter,
      "trailing_zero_bits_64",
      "w#{r_d} = count_trailing_zeros(w#{r_a}(#{w_a})) = #{trailing_zero_bits}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:trailing_zero_bits_32, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    bits = w_a |> rem(0x1_0000_0000) |> u2b(4)
    len = length(bits)

    trailing_zero_bits =
      Enum.find_index(0..(len - 1), fn i -> Enum.at(bits, len - 1 - i) == 1 end)

    Trace.instruction(
      state.counter,
      "trailing_zero_bits_32",
      "w#{r_d} = count_trailing_zeros32(w#{r_a}(#{w_a})) = #{trailing_zero_bits}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, trailing_zero_bits)}}
  end

  def execute(:sign_extend_8, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    sign_extended = w_a |> rem(0x100) |> u2i(1) |> i2u(8)

    Trace.instruction(
      state.counter,
      "sign_extend_8",
      "w#{r_d} = sign_extend_8(w#{r_a}(#{w_a})) = #{sign_extended}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:sign_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    sign_extended = w_a |> rem(0x10000) |> u2i(2) |> i2u(8)

    Trace.instruction(
      state.counter,
      "sign_extend_16",
      "w#{r_d} = sign_extend_16(w#{r_a}(#{w_a})) = #{sign_extended}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, sign_extended)}}
  end

  def execute(:zero_extend_16, program, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Registers.get(state.registers, r_a)
    zero_extended = w_a |> rem(0x10000)

    Trace.instruction(
      state.counter,
      "zero_extend_16",
      "w#{r_d} = zero_extend_16(w#{r_a}(#{w_a})) = #{zero_extended}"
    )

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

    Trace.instruction(
      state.counter,
      "reverse_bytes",
      "w#{r_d} = reverse_bytes(w#{r_a}(#{w_a})) = #{reversed}"
    )

    {:continue, %{state | registers: Registers.set(state.registers, r_d, reversed)}}
  end

  # Formula (A.26) v0.6.1
  defp get_params(program, counter) do
    byte = binary_part_safe(program, counter + 1, 1) |> :binary.first()
    {rem(byte, 16) |> min(12), div(byte, 16) |> min(12)}
  end
end
