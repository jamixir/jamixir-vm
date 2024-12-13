defmodule PVM.ArgInvoc do
  @moduledoc """
  Implements the PVM program-argument invocation function (ΨM) as defined in formula A.36.
  """

  alias PVM.{InitProgram, HostCall, State, Types, Memory}



  @spec execute(binary(), non_neg_integer(), non_neg_integer(), binary(), Types.host_fn(), Types.context()) ::
          {non_neg_integer(), binary() | :panic | :out_of_gas, Types.context()}
  def execute(program, counter, gas, args, host_fn, context) do
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
        transform_result(reason, final_state, final_context)
    end
  end

  # Transform results according to R function (A.37)
  defp transform_result(:halt, state, context) do
    start_addr = state.registers.r10
    end_addr = state.registers.r11

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
