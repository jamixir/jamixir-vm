defmodule VM do
  alias Instructions.Opcode
  use PVM.Encoder
  alias PVM.Utils
  alias PVM.State

  def execute(%State{} = state) do
    output = step(state)

    case output.exit_status do
      :continue ->
        # If Continue, recursively call with updated state
        execute(State.new(
          state.program,
          state.bitmask,
          state.jump_table,
          output
        ))

      # Otherwise return the final state
      _ ->
        output
    end
  end

  def step(%State{} = state) do
    if state.counter >= byte_size(state.program) do
      # trap if we've run out of program
      StepOutput.from_state(state)
      |> StepOutput.with_exit_status(:panic)
    else
      opcode =
        state.program |> binary_part(state.counter, 1) |> :binary.first() |> Opcode.from_byte()

      gas_cost = Instructions.gas_cost(opcode)
      skip_amount = Utils.skip(state.counter, state.bitmask)

      output = StepOutput.standard_transition(state, skip_amount, gas_cost)

      if state.gas < gas_cost do
        StepOutput.with_exit_status(output, :out_of_gas)
      else
        execute_instruction(opcode, state, output)
      end
    end
  end

  defp execute_instruction(opcode, state, output) do
    case opcode do
      :trap ->
        StepOutput.with_exit_status(output, :panic)

      :fallthrough ->
        output

      :store_imm_u8 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
        new_memory = Memory.write(state.memory, addr, <<rem(value, 256)>>)
        StepOutput.with_memory(output, new_memory)

      :store_imm_u16 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
        bytes = e_le(rem(value, 65536), 2)
        new_memory = Memory.write(state.memory, addr, bytes)
        StepOutput.with_memory(output, new_memory)

      :store_imm_u32 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
        bytes = e_le(value, 4)
        new_memory = Memory.write(state.memory, addr, bytes)
        StepOutput.with_memory(output, new_memory)
    end
  end
end
