defmodule PVM.Instructions.Executor do
  alias PVM.Instructions

  alias PVM.Instructions.{
    NoArgs,
    OneImmediate,
    TwoImmediates,
    TwoRegisters,
    RegImmediate,
    RegTwoImm,
    RegImmediateOffset,
    TwoRegistersOneImmediate,
    TwoRegistersOneOffset,
    TwoRegistersTwoImmediates,
    ThreeRegisters
  }

  def execute_instruction(opcode, program, bitmask, jump_table, start_set, state) do
    execute_inner(opcode, program, bitmask, jump_table, start_set, state)
  end

  defp execute_inner(opcode, program, bitmask, jump_table, start_set, state) do
    case Instructions.instruction_category(opcode) do
      :no_args ->
        NoArgs.execute(opcode, state)

      :one_immediate ->
        OneImmediate.execute(opcode, program, bitmask, start_set, state)

      :two_immediates ->
        TwoImmediates.execute(opcode, program, bitmask, state)

      :reg_immediate ->
        RegImmediate.execute(opcode, program, bitmask, jump_table, start_set, state)

      :register_two_immediate ->
        RegTwoImm.execute(opcode, program, bitmask, state)

      :register_immediate_offset ->
        RegImmediateOffset.execute(opcode, program, bitmask, start_set, state)

      :two_registers ->
        TwoRegisters.execute(opcode, program, state)

      :two_registers_one_immediate ->
        TwoRegistersOneImmediate.execute(opcode, program, bitmask, state)

      :two_registers_one_offset ->
        TwoRegistersOneOffset.execute(opcode, program, bitmask, start_set, state)

      :two_registers_two_immediates ->
        TwoRegistersTwoImmediates.execute(opcode, program, bitmask, jump_table, start_set, state)

      :three_registers ->
        ThreeRegisters.execute(opcode, program, state)
    end
  end

  # Formula (A.17) v0.7.0
  def branch(_value, false, counter, _start_set), do: {:continue, counter}

  def branch(value, true, counter, start_set) do
    if value in start_set do
      {:continue, value}
    else
      {:panic, counter}
    end
  end

  # Formula (A.18) v0.7.0
  def djump(a, counter, jump_table, start_set) do
    alignment_factor = 2
    {quotient, remainder} = {div(a, alignment_factor), rem(a, alignment_factor)}
    jump_to = get_jump_target(jump_table, quotient - 1)

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

  defp get_jump_target(jump_table, index) do
    if index >= 0 and index < tuple_size(jump_table) do
      elem(jump_table, index)
    else
      nil
    end
  end
end
