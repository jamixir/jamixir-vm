defmodule PVM.Instructions.RegImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils}
  alias PVM.{Instructions.Executor, Memory, Registers}

  # Section (A.19) v0.5
  def execute(:jump_ind, program, bitmask, jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    register_value = Registers.get(state.registers, register_index)
    start_set = basic_block_starts(program, bitmask)

    {exit_status, counter} =
      Executor.djump(
        rem(register_value + addr, 1 <<< 32),
        state.counter,
        jump_table,
        start_set
      )

    {exit_status, %{state | counter: counter}}
  end

  def execute(:load_imm, program, bitmask, _jump_table, state) do
    {register_index, value} = get_params(program, bitmask, state.counter)
    state = %{state | registers: Registers.set(state.registers, register_index, value)}
    {:continue, state}
  end

  def execute(:load_u8, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        state = %{
          state
          | registers: Registers.set(state.registers, register_index, :binary.first(value))
        }

        {:continue, state}
    end
  end

  def execute(:load_i8, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        signed_value =
          :binary.first(value)
          |> to_64bit(1)

        state = %{
          state
          | registers: Registers.set(state.registers, register_index, signed_value)
        }

        {:continue, state}
    end
  end

  def execute(:load_u16, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        state = %{
          state
          | registers: Registers.set(state.registers, register_index, de_le(value, 2))
        }

        {:continue, state}
    end
  end

  def execute(:load_i16, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        signed_value =
          value
          |> de_le(2)
          |> to_64bit(2)

        state = %{
          state
          | registers: Registers.set(state.registers, register_index, signed_value)
        }

        {:continue, state}
    end
  end

  def execute(:load_u32, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 4) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        state = %{
          state
          | registers: Registers.set(state.registers, register_index, de_le(value, 4))
        }

        {:continue, state}
    end
  end

  def execute(:load_i32, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 4) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        signed_value =
          value
          |> de_le(4)
          |> to_64bit(4)

        state = %{
          state
          | registers: Registers.set(state.registers, register_index, signed_value)
        }

        {:continue, state}
    end
  end

  def execute(:load_u64, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)

    case Memory.read(state.memory, addr, 8) do
      {:error, {:fault, fault_addr}} ->
        {{:fault, fault_addr}, state}

      {:ok, value} ->
        state = %{
          state
          | registers: Registers.set(state.registers, register_index, de_le(value, 8))
        }

        {:continue, state}
    end
  end

  def execute(:store_u8, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    Memory.Util.write(state, addr, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_u16, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    Memory.Util.write(state, addr, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_u32, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    Memory.Util.write(state, addr, e_le(rem(value, 1 <<< 32), 4))
  end

  def execute(:store_u64, program, bitmask, _jump_table, state) do
    {register_index, addr} = get_params(program, bitmask, state.counter)
    value = Registers.get(state.registers, register_index)
    Memory.Util.write(state, addr, e_le(value, 8))
  end

  def execute(:load_imm_64, program, _bitmask, _jump_table, state) do
    register_index =
      min(12, rem(binary_part(program, state.counter + 1, 1) |> :binary.first(), 16))

    value = de_le(binary_part(program, state.counter + 2, 8), 8)
    state = %{state | registers: Registers.set(state.registers, register_index, value)}
    {:continue, state}
  end

  defp get_params(program, bitmask, counter) do
    register_index =
      min(12, rem(binary_part(program, counter + 1, 1) |> :binary.first(), 16))

    l_x = min(4, skip(counter, bitmask) - 1)
    addr = decode_bytes_signed(program, counter + 2, l_x)

    {register_index, addr}
  end
end
