defmodule PVM.ArgInvoc do
  # Formula (A.40) v0.6.1

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
        {gas, :panic, context}

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

  # Formula (A.43) v0.6.5
  defp transform_result(used_gas, :halt, state, context) do
    start_addr = state.registers.r7
    length = state.registers.r8

    case Memory.read(state.memory, start_addr, length) do
      {:ok, data} -> {used_gas, data, context}
      {:error, _} -> {used_gas, <<>>, context}
    end
  end

  defp transform_result(used_gas, :out_of_gas, _state, context) do
    {used_gas, :out_of_gas, context}
  end

  defp transform_result(used_gas, _reason, _state, context) do
    {used_gas, :panic, context}
  end
end
