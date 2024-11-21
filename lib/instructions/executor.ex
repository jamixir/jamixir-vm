defmodule Instructions.Executor do
  alias Instructions.{NoArgs, OneImmediate, TwoImmediates, RegImmediate}

  def execute_instruction(opcode, state, output) do
    case opcode do
      # No arguments
      op when op in [:trap, :fallthrough] ->
        NoArgs.execute(op, output)

      # One immediate
      op when op in [:ecalli, :jump] ->
        OneImmediate.execute(op, state, output)

      # Two immediates
      op when op in [:store_imm_u8, :store_imm_u16, :store_imm_u32, :store_imm_u64] ->
        TwoImmediates.execute(op, state, output)

      # Register and immediate
      op
      when op in [
             :jump_ind,
             :load_imm,
             :load_imm_64,
             :load_u8,
             :load_i8,
             :load_u16,
             :load_i16,
             :load_u32,
             :store_u8,
             :store_u16,
             :store_u32
           ] ->
        RegImmediate.execute(op, state, output)
    end
  end

  # Formula (248) v0.4.5
  def branch(_value, false, counter, _start_set), do: {:continue, counter}

  def branch(value, true, counter, start_set),
    do: if(value in start_set, do: {:continue, value}, else: {:panic, counter})

  # Formula (249) v0.4.5
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
