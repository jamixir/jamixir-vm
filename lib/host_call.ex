defmodule PVM.HostCall do
# Formula (A.34) v 0.7.0
  alias PVM.{State, Types, VM, Decoder}
  use PVM.Utils


  @spec execute(binary(), State.t(), Types.host_fn(), Types.context()) ::
          {Types.exit_reason() | Types.fault_result(), State.t(), Types.context()}
  def execute(program, state, host_fn, context) do
    case Decoder.deblob(program) do
      {:ok, {program, bitmask, jump_table}} ->
        start_set = PVM.Utils.basic_block_starts(program, bitmask)
        do_execute(program, bitmask, jump_table, start_set, state, host_fn, context)

      {:error, _error} ->
        {:panic, state, context}
    end
  end

  @spec do_execute(
          binary(),
          String.t(),
          list(),
          list(),
          State.t(),
          Types.host_fn(),
          Types.context()
        ) ::
          {Types.exit_reason() | Types.fault_result(), State.t(), Types.context()}
  defp do_execute(program, bitmask, jump_table, start_set, state, host_fn, context) do
    case VM.do_execute(program, bitmask, jump_table, start_set, state) do
      {reason, state} when reason in [:panic, :halt, :out_of_gas] ->
        {reason, state, context}

      {{:fault, page}, state} ->
        {{:fault, page}, state, context}

      {{:ecall, call_id}, state} ->
        handle_host_call(
          call_id,
          state,
          host_fn,
          context,
          program,
          bitmask,
          jump_table,
          start_set
        )
    end
  end

  @spec handle_host_call(
          non_neg_integer(),
          State.t(),
          Types.host_fn(),
          Types.context(),
          binary(),
          String.t(),
          list(),
          list()
        ) ::
          {Types.exit_reason() | Types.fault_result(), State.t(), Types.context()}
  defp handle_host_call(call_id, state, host_fn, context, program, bitmask, jump_table, start_set) do
    case host_fn.(call_id, Map.drop(state, [:counter]), context) do
      {:fault, page} ->
        {{:fault, page}, state, context}

      {:continue, new_state, new_context} ->
        state_ = struct(State, Map.merge(new_state, %{counter: state.counter}))

        do_execute(program, bitmask, jump_table, start_set, state_, host_fn, new_context)

      {reason, final_state, final_context} when reason in [:halt, :panic, :out_of_gas] ->
        {reason, Map.put(final_state, :counter, state.counter), final_context}
    end
  end
end
