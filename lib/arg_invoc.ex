defmodule PVM.ArgInvoc do
  # Formula (A.43) v0.6.6

  alias PVM.{InitProgram, HostCall, State, Types, Memory}

  @spec execute(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          Types.host_fn(),
          Types.context(),
          keyword()
        ) ::
          {non_neg_integer(), binary() | :panic | :out_of_gas, Types.context()}
  def execute(program, counter, gas, args, host_fn, context, opts \\ []) do
    # If trace is enabled in opts, set it in config
    if opts[:trace] do
      Application.put_env(:pvm, :trace, true)
      PVM.Trace.init_trace_file(opts[:trace_name])
    end

    case InitProgram.initialize_program(program, args) do
      nil ->
        {0, :panic, context}

      {code, registers, memory} ->
        state = %State{
          counter: counter,
          gas: gas,
          registers: registers,
          memory: memory
        }

        {reason, final_state, final_context} = HostCall.execute(code, state, host_fn, context)
        PVM.Trace.close_trace_file()
        used_gas = gas - max(final_state.gas, 0)
        transform_result(used_gas, reason, final_state, final_context)
    end
  end

  # Formula (A.43) v0.6.6
  # R Function
  defp transform_result(used_gas, :halt, state_, context_) do
    start_addr = state_.registers.r7
    length = state_.registers.r8

    case Memory.read(state_.memory, start_addr, length) do
      {:ok, data} -> {used_gas, data, context_}
      {:error, _} -> {used_gas, <<>>, context_}
    end
  end

  defp transform_result(used_gas, :out_of_gas, _state, context_) do
    {used_gas, :out_of_gas, context_}
  end

  defp transform_result(used_gas, _reason, _state, context_) do
    {used_gas, :panic, context_}
  end
end
