defmodule PVM.Instructions.RegImmediate do
  use PVM.{Decoder, Encoder, Utils, Math}
  alias PVM.Registers
  alias PVM.{Instructions.Executor}
  import PVM.Memory.Util

  @two_to_8 0x100
  @two_to_16 0x1_0000
  @two_to_32 0x1_0000_0000

  # Section (A.5.3) v0.7.0
  def execute(:load_imm_64, program, _bitmask, _jump_table, _start_set, state) do
    # Formula (A.21) v0.7.0
    register_index =
      min(12, mod(binary_part_safe(program, state.counter + 1, 1) |> :binary.first(), 16))

    <<value::64-little>> = binary_part_safe(program, state.counter + 2, 8)
    Registers.put_elem(state.registers.r, register_index, value)
    {:continue, state}
  end

  # Section (A.5.6) v0.7.0
  def execute(:jump_ind, program, bitmask, jump_table, start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    register_value = state.registers[register_index]
    target = mod(register_value + addr, 0x1_0000_0000)

    {exit_status, counter} =
      Executor.djump(
        target,
        state.counter,
        jump_table,
        start_set
      )

    {exit_status, %{state | counter: counter}}
  end

  def execute(:load_imm, program, bitmask, _jump_table, _start_set, state) do
    {register_index, value} = get_params(program, bitmask, state.counter)

    Registers.put_elem(state.registers.r, register_index, value)

    {:continue, state}
  end

  def execute(:load_u8, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(
      state,
      addr,
      1,
      fn n ->
        Registers.put_elem(state.registers.r, register_index, :binary.first(n))
        state
      end
    )
  end

  def execute(:load_i8, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 1, fn <<value>> ->
      signed_value = to_64bit(value, 1)
      Registers.put_elem(state.registers.r, register_index, signed_value)
      state
    end)
  end

  def execute(:load_u16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 2, fn <<v::16-little>> ->
      Registers.put_elem(state.registers.r, register_index, v)
      state
    end)
  end

  def execute(:load_i16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 2, fn <<value::16-little>> ->
      Registers.put_elem(state.registers.r, register_index, to_64bit(value, 2))
      state
    end)
  end

  def execute(:load_u32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 4, fn <<v::32-little>> ->
      Registers.put_elem(state.registers.r, register_index, v)
      state
    end)
  end

  def execute(:load_i32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 4, fn <<value::32-little>> ->
      Registers.put_elem(state.registers.r, register_index, to_64bit(value, 4))
      state
    end)
  end

  def execute(:load_u64, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 8, fn <<v::64-little>> ->
      Registers.put_elem(state.registers.r, register_index, v)
      state
    end)
  end

  def execute(:store_u8, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = state.registers[register_index]
    stored_value = mod(value, @two_to_8)

    write_memory(state, addr, <<stored_value>>)
  end

  def execute(:store_u16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = state.registers[register_index]
    stored_value = mod(value, @two_to_16)

    write_memory(state, addr, <<stored_value::16-little>>)
  end

  def execute(:store_u32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = state.registers[register_index]
    stored_value = mod(value, @two_to_32)

    write_memory(state, addr, <<stored_value::32-little>>)
  end

  def execute(:store_u64, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = state.registers[register_index]

    write_memory(state, addr, <<value::64-little>>)
  end

  # Formula (A.24) v0.7.0
  defp get_params(program, bitmask, counter) do
    register_index =
      min(12, mod(binary_part_safe(program, counter + 1, 1) |> :binary.first(), 16))

    l_x = min(4, skip(counter, bitmask) - 1)
    addr = decode_and_extend(program, counter + 2, l_x)

    {register_index, addr}
  end
end
