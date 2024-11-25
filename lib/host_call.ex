defmodule PVM.HostCall do
  @moduledoc """
  Implements the host-call state machine (ΨH) as defined in formula A.27.
  """

  alias PVM.State
  use PVM.Utils
  alias PVM.Decoder

  @type host_call_state :: %{
          gas: non_neg_integer(),
          registers: list(integer()),
          memory: Memory.t()
        }

  @type exit_reason :: :continue | :halt | :panic | :out_of_gas
  @type fault_result :: {:fault, non_neg_integer()}
  @type host_fn :: (non_neg_integer(), host_call_state(), any() ->
                      {exit_reason, {State.t(), any()}} | fault_result)

  @type context :: any()

  @doc """
  Executes a host call state transition according to ΨH definition.
  """
  @spec execute(binary(), State.t(), host_fn(), context()) ::
          {exit_reason | :fault, State.t(), context()}
  def execute(program, state, host_fn, context) do
    case VM.execute(program, state) do
      {reason, state} when reason in [:panic, :halt, :out_of_gas] ->
        {reason, state, context}

      {{:fault, page}, state} ->
        {{:fault, page}, state, context}

      {{:ecall, host_data}, state} ->
        host_state = Map.drop(state, [:counter])
        handle_host_call(host_data, host_state, host_fn, context, program)
    end
  end

  @spec handle_host_call(non_neg_integer(), host_call_state(), host_fn(), context(), binary()) ::
          {exit_reason | {:fault, non_neg_integer()}, State.t(), context()}
  defp handle_host_call(host_data, state, host_fn, context, program) do
    case host_fn.(host_data, state, context) do
      {:fault, page} ->
        {{:fault, page}, state, context}

      {:continue, {new_state, new_context}} ->
        {_, bitmask, _} = Decoder.decode_program(program)
        skip = skip(state.counter, bitmask)
        next_counter = state.counter + 1 + skip
        execute(program, %{new_state | counter: next_counter}, host_fn, new_context)

      {reason, {final_state, final_context}} when reason in [:halt, :panic, :out_of_gas] ->
        {reason, %{final_state | counter: state.counter}, final_context}
    end
  end
end
