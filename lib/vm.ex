defmodule PVM.VM do
  use PVM.{Encoder, Instructions, Utils}
  alias PVM.{State, SingleStep, Types, Decoder}

  # Formula (A.1) v0.6.6
  @spec execute(binary(), State.t()) :: State.t()
  @spec execute(any(), any()) ::
          {:halt | :panic | {:ecall, non_neg_integer()} | {:fault, non_neg_integer()}, any()}
  def execute(program, state) do
    case Decoder.deblob(program) do
      {:ok, {program, bitmask, jump_table}} ->
        start_set = basic_block_starts(program, bitmask)
        do_execute(program, bitmask, jump_table, start_set, state)

      {:error, _error} ->
        {:panic, state}
    end
  end

  @spec do_execute(binary(), String.t(), list(), list(), State.t()) ::
          {Types.vm_exit_reason(), State.t()}
  def do_execute(program, bitmask, jump_table, start_set, state) do
    {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)

    case exit_reason do
      :continue when state_.gas >= 0 ->
        :erlang.yield()
        do_execute(program, bitmask, jump_table, start_set, state_)

      :continue ->
        {:out_of_gas, state_}

      reason when reason in [:panic, :halt] ->
        {reason, %{state_ | counter: 0}}

      _ ->
        {exit_reason, state_}
    end
  end
end
