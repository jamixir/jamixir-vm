defmodule Instructions.RegImmediate do
  alias PVM.Utils
  import Bitwise
  use PVM.Encoder

  def execute(:load_imm, state, output) do
    {register_index, value} = get_load_params(state)
    update_register(output, state.registers, register_index, value)
  end

  def execute(:load_u8, state, output) do
    {register_index, addr} = get_load_params(state)
    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      value ->
        update_register(output, state.registers, register_index, :binary.first(value))
    end
  end

  def execute(:load_i8, state, output) do
    {register_index, addr} = get_load_params(state)
    case Memory.read(state.memory, addr, 1) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      value ->
        signed_value = value
          |> :binary.first()
          |> Transitions.z_n(1)
          |> Transitions.z_n_inverse(4)
        update_register(output, state.registers, register_index, signed_value)
    end
  end

  def execute(:load_u16, state, output) do
    {register_index, addr} = get_load_params(state)
    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      value ->
        update_register(output, state.registers, register_index, Utils.de_le(value, 2))
    end
  end

  def execute(:load_i16, state, output) do
    {register_index, addr} = get_load_params(state)
    case Memory.read(state.memory, addr, 2) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      value ->
        signed_value = value
          |> Utils.de_le(2)
          |> Transitions.z_n(2)
          |> Transitions.z_n_inverse(4)
        update_register(output, state.registers, register_index, signed_value)
    end
  end

  def execute(:load_u32, state, output) do
    {register_index, addr} = get_load_params(state)
    case Memory.read(state.memory, addr, 4) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      value ->
        update_register(output, state.registers, register_index, Utils.de_le(value, 4))
    end
  end

  def execute(:store_u8, state, output) do
    {register_index, addr} = get_store_params(state)
    value = Enum.at(state.registers, register_index)
    do_write(output, addr, state.memory, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_u16, state, output) do
    {register_index, addr} = get_store_params(state)
    value = Enum.at(state.registers, register_index)
    do_write(output, addr, state.memory, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_u32, state, output) do
    {register_index, addr} = get_store_params(state)
    value = Enum.at(state.registers, register_index)
    do_write(output, addr, state.memory, e_le(value, 4))
  end

  # Helper functions
  defp get_load_params(state) do
    register_index = min(12, rem(binary_part(state.program, state.counter + 1, 1) |> :binary.first(), 16))
    addr = Utils.parse_address(state.program, state.counter, state.bitmask)
    {register_index, addr}
  end

  defp get_store_params(state) do
    register_index = Utils.get_register_index(state.program, state.counter)
    addr = Utils.parse_address(state.program, state.counter, state.bitmask)
    {register_index, addr}
  end

  defp update_register(output, registers, index, value) do
    %StepOutput{output | registers: List.replace_at(registers, index, value)}
  end

  defp do_write(output, addr, memory, bytes) do
    case Memory.write(memory, addr, bytes) do
      {:error, {:fault, fault_addr}} ->
        %StepOutput{output | exit_status: {:fault, fault_addr}}
      new_memory ->
        %StepOutput{output | memory: new_memory}
    end
  end
end
