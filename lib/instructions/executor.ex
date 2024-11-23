defmodule Instructions.Executor do
  alias Instructions.{
    NoArgs,
    OneImmediate,
    TwoImmediates,
    TwoRegisters,
    RegImmediate,
    RegImmediateOffset,
    TwoRegistersOneImmediate,
    TwoRegistersOneOffset
  }

  def execute_instruction(opcode, state, output) do
    case Instructions.instruction_category(opcode) do
      :no_args -> NoArgs.execute(opcode, output)
      :one_immediate -> OneImmediate.execute(opcode, state, output)
      :two_immediates -> TwoImmediates.execute(opcode, state, output)
      :reg_immediate -> RegImmediate.execute(opcode, state, output)
      :register_immediate_offset -> RegImmediateOffset.execute(opcode, state, output)
      :two_registers -> TwoRegisters.execute(opcode, state, output)
      :two_registers_one_immediate -> TwoRegistersOneImmediate.execute(opcode, state, output)
      :two_registers_one_offset -> TwoRegistersOneOffset.execute(opcode, state, output)
    end
  end

  # Formula (A.12) v0.5
  def branch(_value, false, counter, _start_set), do: {:continue, counter}

  def branch(value, true, counter, start_set),
    do: if(value in start_set, do: {:continue, value}, else: {:panic, counter})

  # Formula (A.13) v0.5
  def djump(a, counter, jump_table, start_set) do
    alignment_factor = 2
    {quotient, remainder} = {div(a, alignment_factor), rem(a, alignment_factor)}
    jump_to = Enum.at(jump_table, quotient - 1)

    case a do
      # 2^32 - 2^16
      0xFFFF0000 ->
        {:halt, counter}

      0 ->
        {:panic, counter}

      a when a > length(jump_table) * alignment_factor ->
        {:panic, counter}

      _ when remainder != 0 ->
        {:panic, counter}

      _ ->
        if jump_to in start_set do
          {:continue, jump_to}
        else
          {:panic, counter}
        end
    end
  end
end
