defmodule PVM.VM do
  use PVM.{Encoder, Instructions, Utils}
  alias PVM.{State, SingleStep, Types, Decoder}

  # Formula (A.1) v0.6.1
  @spec execute(binary(), State.t()) :: State.t()
  def execute(program, state) do
    {program, bitmask, jump_table} = Decoder.decode_program(program)
    start_set = basic_block_starts(program, bitmask)
    do_execute(program, bitmask, jump_table, start_set, state)
  end

  @spec do_execute(binary(), String.t(), list(), list(), State.t()) ::
          {Types.vm_exit_reason(), State.t()}
  def do_execute(program, bitmask, jump_table, start_set, state) do
    {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)

    if state_.gas < 0 do
      {:out_of_gas, state_}
    else
      case exit_reason do
        :continue ->
          do_execute(program, bitmask, jump_table, start_set, state_)

        reason when reason in [:panic, :halt] ->
          {reason, %{state_ | counter: 0}}

        _ ->
          {exit_reason, state_}
      end
    end
  end
end
