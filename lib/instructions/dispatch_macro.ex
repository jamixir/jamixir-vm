defmodule PVM.Instructions.DispatchMacro do
  alias PVM.Instructions.{
    NoArgs,
    OneImmediate,
    ThreeRegisters,
    TwoImmediates,
    RegImmediate,
    RegTwoImm,
    RegImmediateOffset,
    TwoRegisters,
    TwoRegistersOneImmediate,
    TwoRegistersOneOffset,
    TwoRegistersTwoImmediates
  }

  defmacro no_args_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              _program,
              _bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          NoArgs.execute(unquote(instruction), state)
        end
      end
    end
  end

  defmacro one_immediate_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              start_set,
              state
            ) do
          OneImmediate.execute(unquote(instruction), program, bitmask, start_set, state)
        end
      end
    end
  end

  defmacro two_immediates_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          TwoImmediates.execute(unquote(instruction), program, bitmask, state)
        end
      end
    end
  end

  defmacro reg_immediate_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              jump_table,
              start_set,
              state
            ) do
          RegImmediate.execute(
            unquote(instruction),
            program,
            bitmask,
            jump_table,
            start_set,
            state
          )
        end
      end
    end
  end

  defmacro reg_two_imm_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          RegTwoImm.execute(unquote(instruction), program, bitmask, state)
        end
      end
    end
  end

  defmacro reg_immediate_offset_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              start_set,
              state
            ) do
          RegImmediateOffset.execute(unquote(instruction), program, bitmask, start_set, state)
        end
      end
    end
  end

  defmacro two_registers_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              _bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          TwoRegisters.execute(unquote(instruction), program, state)
        end
      end
    end
  end

  defmacro two_registers_one_immediate_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          TwoRegistersOneImmediate.execute(unquote(instruction), program, bitmask, state)
        end
      end
    end
  end

  defmacro two_registers_one_offset_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              _jump_table,
              start_set,
              state
            ) do
          TwoRegistersOneOffset.execute(unquote(instruction), program, bitmask, start_set, state)
        end
      end
    end
  end

  defmacro two_registers_two_immediates_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              bitmask,
              jump_table,
              start_set,
              state
            ) do
          TwoRegistersTwoImmediates.execute(
            unquote(instruction),
            program,
            bitmask,
            jump_table,
            start_set,
            state
          )
        end
      end
    end
  end

  defmacro three_registers_direct_dispatch(instructions) do
    for instruction <- instructions do
      quote do
        def execute_instruction(
              unquote(instruction),
              program,
              _bitmask,
              _jump_table,
              _start_set,
              state
            ) do
          ThreeRegisters.execute(unquote(instruction), program, state)
        end
      end
    end
  end
end
