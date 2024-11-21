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
    output = StepOutput.from_state(state)

    if state.counter >= byte_size(state.program) do
      %{output | exit_status: :panic}
    else
      opcode =
        state.program |> binary_part(state.counter, 1) |> :binary.first() |> Opcode.from_byte()

      gas_cost = Instructions.gas_cost(opcode)

      if state.gas < gas_cost do
        %{output | exit_status: :out_of_gas}
      else
        output_ = Executor.execute_instruction(opcode, state, output)
        output_ = %{output_ | counter: Utils.next_counter(output_, state)}

        # Execute instruction first, before any state transition
        case output_.exit_status do
          # On fault, return without state transition
          {:fault, page} ->
            %{output | exit_status: {:fault, page}}

          # For all other cases (continue, panic, out_of_gas, ecall), apply state transition
          _ ->
            %{output_ | gas: output.gas - gas_cost}
        end
      end
    end
  end
end
