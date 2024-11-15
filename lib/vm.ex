defmodule VM do
  alias Instructions.Opcode
  use PVM.Encoder
  alias PVM.Utils
  alias PVM.State

  def execute(%State{} = state) do
    output = step(state)

    case output.exit_status do
      :continue ->
        # If Continue, recursively call with updated state
        execute(
          State.new(
            state.program,
            state.bitmask,
            state.jump_table,
            output
          )
        )

      # Otherwise return the final state
      _ ->
        output
    end
  end

  def step(%State{} = state) do
    if state.counter >= byte_size(state.program) do
      # trap if we've run out of program
      StepOutput.from_state(state)
      |> StepOutput.with_exit_status(:panic)
    else
      opcode =
        state.program |> binary_part(state.counter, 1) |> :binary.first() |> Opcode.from_byte()

      gas_cost = Instructions.gas_cost(opcode)
      skip_amount = Utils.skip(state.counter, state.bitmask)

      output = StepOutput.standard_transition(state, skip_amount, gas_cost)

      if state.gas < gas_cost do
        StepOutput.with_exit_status(output, :out_of_gas)
      else
        execute_instruction(opcode, state, output)
      end
    end
  end

  defp execute_instruction(opcode, state, output) do
    case opcode do
      :trap ->
        StepOutput.with_exit_status(output, :panic)

      :fallthrough ->
        output

      :ecalli ->
        {value, _} = Utils.parse_immediate(state.program, state.counter)
        StepOutput.with_exit_status(output, {:ecall, value})

      :store_imm_u8 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)

        case Memory.write(state.memory, addr, <<rem(value, 256)>>) do
          {:error, {:fault, fault_addr}} ->
            StepOutput.with_exit_status(output, {:fault, fault_addr})

          new_memory ->
            StepOutput.with_memory(output, new_memory)
        end

      :store_imm_u16 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
        bytes = e_le(rem(value, 65536), 2)

        case Memory.write(state.memory, addr, bytes) do
          {:error, {:fault, fault_addr}} ->
            StepOutput.with_exit_status(output, {:fault, fault_addr})

          new_memory ->
            StepOutput.with_memory(output, new_memory)
        end

      :store_imm_u32 ->
        {addr, value, _} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
        bytes = e_le(value, 4)

        case Memory.write(state.memory, addr, bytes) do
          {:error, {:fault, fault_addr}} ->
            StepOutput.with_exit_status(output, {:fault, fault_addr})

          new_memory ->
            StepOutput.with_memory(output, new_memory)
        end

      :jump ->
        # Parse the immediate value for the jump target
        l = Utils.skip(state.counter, state.bitmask)
        l_x = min(4, l)
        x_bytes = binary_part(state.program, state.counter + 1, l_x)
        x_value = x_bytes |> Utils.de_le(l_x)
        v_x = state.counter + 1 + Transitions.z_n(x_value, l_x)

        start_set = Utils.basic_block_starts(state.program, state.bitmask)
        branch(v_x, true, state.counter, start_set)
    end
  end

  def branch(_value, false, counter, _start_set), do: {:continue, counter}

  def branch(value, true, counter, start_set),
    do: if(value in start_set, do: {:continue, value}, else: {:panic, counter})
end
