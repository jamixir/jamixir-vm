defmodule Instructions.RegImmediate do
  alias PVM.Utils
  import Bitwise
  use PVM.{Decoder, Encoder}
  alias Instructions.{Common, Executor}

  # Section (A.5.5) v0.4.5
  def execute(:jump_ind, state, output) do
    {register_index, addr} = get_params(state)
    register_value = Enum.at(state.registers, register_index)
    start_set = Utils.basic_block_starts(state.program, state.bitmask)

    {exit_status, counter} =
      Executor.djump(
        rem(register_value + addr, 1 <<< 32),
        state.counter,
        state.jump_table,
        start_set
      )

    %StepOutput{output | exit_status: exit_status, counter: counter}
  end

  def execute(:load_imm, state, output) do
    {register_index, value} = get_params(state)
    Common.update_register(output, state.registers, register_index, value)
  end

  def execute(:load_u8, state, output) do
    {register_index, addr} = get_params(state)

    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      value ->
        Common.update_register(output, state.registers, register_index, :binary.first(value))
    end
  end

  def execute(:load_i8, state, output) do
    {register_index, addr} = get_params(state)

    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      value ->
        signed_value =
          value
          |> :binary.first()
          |> Transitions.z_n(1)
          |> Transitions.z_n_inverse(4)

        Common.update_register(output, state.registers, register_index, signed_value)
    end
  end

  def execute(:load_u16, state, output) do
    {register_index, addr} = get_params(state)

    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      value ->
        Common.update_register(output, state.registers, register_index, de_le(value, 2))
    end
  end

  def execute(:load_i16, state, output) do
    {register_index, addr} = get_params(state)

    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      value ->
        signed_value =
          value
          |> de_le(2)
          |> Transitions.z_n(2)
          |> Transitions.z_n_inverse(4)

        Common.update_register(output, state.registers, register_index, signed_value)
    end
  end

  def execute(:load_u32, state, output) do
    {register_index, addr} = get_params(state)

    case Memory.read(state.memory, addr, 4) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}

      value ->
        Common.update_register(output, state.registers, register_index, de_le(value, 4))
    end
  end

  def execute(:store_u8, state, output) do
    {register_index, addr} = get_params(state)
    value = Enum.at(state.registers, register_index)
    Common.do_write(output, addr, state.memory, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_u16, state, output) do
    {register_index, addr} = get_params(state)
    value = Enum.at(state.registers, register_index)
    Common.do_write(output, addr, state.memory, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_u32, state, output) do
    {register_index, addr} = get_params(state)
    value = Enum.at(state.registers, register_index)
    Common.do_write(output, addr, state.memory, e_le(value, 4))
  end

  # Helper functions
  defp get_params(state) do
    register_index =
      min(12, rem(binary_part(state.program, state.counter + 1, 1) |> :binary.first(), 16))

    l_x = min(4, Utils.skip(state.counter, state.bitmask) - 1)
    addr = Utils.decode_bytes_signed(state.program, state.counter + 2, l_x)

    {register_index, addr}
  end
end
