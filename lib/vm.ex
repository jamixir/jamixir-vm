defmodule VM do
  use PVM.Encoder
  use PVM.Utils
  alias PVM.Types
  alias PVM.State
  use Instructions

  # Main execution function with previous output state
  @spec execute(binary(), State.t()) :: {Types.vm_exit_reason(), State.t()}
  def execute(p, state) do
    # Decode the program blob into components
    {program, bitmask, jump_table} = PVM.Decoder.decode_program(p)

    # Execute according to Ψ function rules
    {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, state)

    if state_.gas < 0 do
      {:out_of_gas, state_}
    else
      case exit_reason do
        :continue ->
          # Recursive case: carry forward all state changes
          execute(p, state_)

        reason when reason in [:panic, :halt] ->
          {reason, %{state_ | counter: 0}}

        _ ->
          {exit_reason, state_}
      end
    end
  end
end
