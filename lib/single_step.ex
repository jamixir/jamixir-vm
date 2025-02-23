defmodule PVM.SingleStep do
  alias PVM.{State, Types, Utils, Instructions.Executor, Instructions}
  use Utils
  use PVM.Instructions

  @type exit_reason :: Types.vm_exit_reason()

  # Formula (A.5) v0.6.1
  @spec run(binary(), binary(), list(non_neg_integer()), list(non_neg_integer()), State.t()) ::
          {exit_reason(), State.t()}
  def run(program, bitmask, jump_table, start_set, %State{} = state) do
    # equivalent to Formula (A.3) v0.6.1
    if state.counter >= byte_size(program) do
      {:panic, state}
    else
      opcode =
        program |> binary_part_safe(state.counter, 1) |> :binary.first() |> op()

      {exit_reason, state_} =
        Executor.execute_instruction(opcode, program, bitmask, jump_table, start_set, state)

      next_counter =
        next_counter(%{exit_reason: exit_reason, counter: state_.counter}, state.counter, bitmask)

      state_ = %{
        state_
        | counter: next_counter
      }

      case exit_reason do
        {:fault, page} ->
          {{:fault, page}, state}

        :panic ->
          {:panic, state}

        _ ->
          {exit_reason, %{state_ | gas: state.gas - Instructions.gas_cost(opcode)}}
      end
    end
  end
end
