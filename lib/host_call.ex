defmodule PVM.HostCall do
  @moduledoc """
  Implements the host-call state machine (ΨH) as defined in formula A.27.
  """

  alias PVM.State
  use PVM.Utils

  @type host_call_function :: (any(), State.t(), any() ->
    {:continue, {State.t(), any()}} |
    {:fault, integer()} |
    {:halt, any()}
  )

  @type vm_exit_reason ::
    :continue | :panic | :out_of_gas | {:fault, integer()} | {:host_call, any()}

  @doc """
  Executes a host call state transition according to ΨH definition.
  """
  @spec execute(
    binary(),           # program
    State.t(),          # current state
    host_call_function, # host call implementation (f in the formula)
    any()              # additional context X
  ) :: {{vm_exit_reason(), State.t()}, any()}
  def execute(program, initial_state, host_fn, context) do
    # First execute the VM
    case VM.execute(program, initial_state) do
      # Terminal conditions - return as is with context
      {reason, state} when reason in [:panic, :halt, :out_of_gas] ->
        {{reason, state}, context}

      {{:fault, page}, state} ->
        {{:fault, page}, state, context}

      # Host call case
      {{:ecall, host_data}, state} ->
        case host_fn.(host_data, state, context) do
          # Fault during host call - return immediately
          {:fault, page} ->
            {{:fault, page}, state, context}

          # Continue case - recursive call with new state
          {:continue, {new_state, new_context}} ->
            # Move counter forward past the host call
            next_counter = state.counter + 1 + skip(state.counter, program)
            execute(program, %{new_state | counter: next_counter}, host_fn, new_context)

          # Host call completed with halt
          {reason, {final_state, final_context}} when reason in [:halt, :panic, :out_of_gas] ->
            {{reason, final_state}, final_context}
        end
    end
  end
end
