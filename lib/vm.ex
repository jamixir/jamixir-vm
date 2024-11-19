defmodule VM do
  alias Instructions.{Opcode, Executor}
  use PVM.Encoder
  alias PVM.Utils
  alias PVM.State

  def execute(%State{} = state) do
    output = step(state)

    case output.exit_status do
      :continue ->
        # If Continue, recursively call with updated state
        execute(
          State.new(
            state.program,
            state.bitmask,
            state.jump_table,
            output
          )
        )

      # Otherwise return the final state
      _ ->
        output
    end
  end

  def step(%State{} = state) do
    if state.counter >= byte_size(state.program) do
      %StepOutput{StepOutput.from_state(state) | exit_status: :panic}
    else
      opcode =
        state.program |> binary_part(state.counter, 1) |> :binary.first() |> Opcode.from_byte()

      gas_cost = Instructions.gas_cost(opcode)
      skip_amount = Utils.skip(state.counter, state.bitmask)
      output = StepOutput.standard_transition(state, skip_amount, gas_cost)

      if state.gas < gas_cost do
        %StepOutput{output | exit_status: :out_of_gas}
      else
        Executor.execute_instruction(opcode, state, output)
      end
    end
  end
end

