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
      PVM.Trace.init_trace_file()
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
        transform_result(reason, final_state, final_context)
    end
  end

  # Formula (A.41) v0.6.1
  defp transform_result(:halt, state, context) do
    start_addr = state.registers.r7
    end_addr = state.registers.r8

    case Memory.read(state.memory, start_addr, end_addr - start_addr) do
      {:ok, data} -> {state.gas, data, context}
      {:error, _} -> {state.gas, <<>>, context}
    end
  end

  defp transform_result(:out_of_gas, state, context) do
    {state.gas, :out_of_gas, context}
  end

  defp transform_result(_reason, state, context) do
    {state.gas, :panic, context}
  end
end
