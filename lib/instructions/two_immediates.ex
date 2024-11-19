defmodule Instructions.TwoImmediates do
  alias PVM.Utils
  import Bitwise
  use PVM.Encoder


  def execute(:store_imm_u8, state, output) do
    {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    do_write(output, addr, state.memory, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_imm_u16, state, output) do
    {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    do_write(output, addr, state.memory, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_imm_u32, state, output) do
    {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    do_write(output, addr, state.memory, e_le(value, 4))
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
