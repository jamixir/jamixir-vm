defmodule SingleStep do
  alias Instructions.Executor
  alias PVM.State
  use PVM.Utils
  use Instructions

  @type exit_reason ::
          :continue | :panic | :out_of_gas | {:fault, non_neg_integer()} | {:ecall, integer()}

  def run(program, bitmask, jump_table, %State{} = state) do
    if state.counter >= byte_size(program) do
      {:panic, state}
    else
      opcode =
        program |> binary_part(state.counter, 1) |> :binary.first() |> op()

      {exit_reason, state_} =
        Executor.execute_instruction(opcode, program, bitmask, jump_table, state)

      next_counter =
        next_counter(%{exit_reason: exit_reason, counter: state_.counter}, state.counter, bitmask)

      state_ = %{
        state_
        | counter: next_counter
      }

      case exit_reason do
        {:fault, page} ->
          {{:fault, page}, state}

        _ ->
          {exit_reason, %{state_ | gas: state.gas - Instructions.gas_cost(opcode)}}
      end
    end
  end
end
