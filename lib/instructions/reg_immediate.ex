defmodule PVM.Instructions.RegImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils}
  alias PVM.{Instructions.Executor, Registers}
  import PVM.Memory.Util

  # Section (A.5.3) v0.6.1
  def execute(:load_imm_64, program, _bitmask, _jump_table, _start_set, state) do
    # Formula (A.20) v0.6.1
    register_index =
      min(12, rem(binary_part(program, state.counter + 1, 1) |> :binary.first(), 16))

    <<value::64-little>> = binary_part(program, state.counter + 2, 8)

    state = %{state | registers: Registers.set(state.registers, register_index, value)}
    {:continue, state}
  end

  # Section (A.5.6) v0.6.1
  def execute(:jump_ind, program, bitmask, jump_table, start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    register_value = Registers.get(state.registers, register_index)

    {exit_status, counter} =
      Executor.djump(
        rem(register_value + addr, 1 <<< 32),
        state.counter,
        jump_table,
        start_set
      )

    {exit_status, %{state | counter: counter}}
  end

  def execute(:load_imm, program, bitmask, _jump_table, _start_set, state) do
    {register_index, value} = get_params(program, bitmask, state.counter)
    state = %{state | registers: Registers.set(state.registers, register_index, value)}
    {:continue, state}
  end

  def execute(:load_u8, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 1, &%{
        state
        | registers: Registers.set(state.registers, register_index, :binary.first(&1))
      }
    )
  end

  def execute(:load_i8, program, bitmask, _jump_table, _start_set,  state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 1, fn value ->
      signed_value =
        :binary.first(value)
        |> to_64bit(1)

      %{
        state
        | registers: Registers.set(state.registers, register_index, signed_value)
      }
    end)
  end

  def execute(:load_u16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 2, fn <<v::16-little>> -> %{
        state
        | registers: Registers.set(state.registers, register_index, v)
      } end
    )
  end

  def execute(:load_i16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 2, fn <<value::16-little>> ->
      signed_value = to_64bit(value, 2)

      %{
        state
        | registers: Registers.set(state.registers, register_index, signed_value)
      }
    end)
  end

  def execute(:load_u32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 4, fn <<v::32-little>> -> %{
        state
        | registers: Registers.set(state.registers, register_index, v)
      } end
    )
  end

  def execute(:load_i32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 4, fn <<value::32-little>> ->
      signed_value = to_64bit(value,4)

      %{
        state
        | registers: Registers.set(state.registers, register_index, signed_value)
      }
    end)
  end

  def execute(:load_u64, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    read_memory(state, addr, 8, fn <<v::64-little>> -> %{
        state
        | registers: Registers.set(state.registers, register_index, v)
      } end
    )
  end

  def execute(:store_u8, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    write_memory(state, addr, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_u16, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    write_memory(state, addr, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_u32, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    write_memory(state, addr, e_le(rem(value, 1 <<< 32), 4))
  end

  def execute(:store_u64, program, bitmask, _jump_table, _start_set, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    write_memory(state, addr, e_le(value, 8))
  end

  # Formula (A.23) v0.6.1
  defp get_params(program, bitmask, counter) do
    register_index =
      min(12, rem(binary_part(program, counter + 1, 1) |> :binary.first(), 16))

    l_x = min(4, skip(counter, bitmask) - 1)
    addr = decode_bytes_signed(program, counter + 2, l_x)

    {register_index, addr}
  end
end
