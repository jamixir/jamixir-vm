defmodule PVM.SingleStep do
  alias PVM.{State, Types, Utils, Instructions.Executor, Instructions}
  use Utils
  use PVM.Instructions

  @type exit_reason :: Types.vm_exit_reason()

  # Formula (A.6) v0.6.6
  @spec run(binary(), binary(), list(non_neg_integer()), list(non_neg_integer()), State.t()) ::
          {exit_reason(), State.t()}
  def run(program, bitmask, jump_table, start_set, %State{} = state) do
    # equivalent to Formula (A.4) v0.6.6
    if state.counter >= byte_size(program) do
      {:panic, state}
    else
      opcode =
        program |> binary_part_safe(state.counter, 1) |> :binary.first() |> op()

      {exit_reason, state_} =
        Executor.execute_instruction(opcode, program, bitmask, jump_table, start_set, state)

      next_counter =
        next_counter(%{exit_reason: exit_reason, counter: state_.counter}, state.counter, bitmask)

      gas_cost = Instructions.gas_cost(opcode)

      deduct_gas = %{
        state_
        | gas: state.gas - gas_cost
      }

      case exit_reason do
        {:fault, page} ->
          {{:fault, page}, deduct_gas}

        :panic ->
          {:panic, deduct_gas}

        _ ->
          {exit_reason, %{deduct_gas | counter: next_counter}}
      end
    end
  end
end
