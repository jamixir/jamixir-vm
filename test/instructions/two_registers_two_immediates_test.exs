defmodule Instructions.TwoRegistersTwoImmediatesTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.TwoRegistersTwoImmediates

  def create_test_state(program, bitmask) do
    %PVM.State{
      program: program,
      bitmask: bitmask,
      counter: 0,
      gas: 100,
      registers: List.duplicate(0, 13),
      memory: %Memory{}
    }
  end

  describe "load_imm_jump_ind" do
    test "loads immediate value and performs valid indirect jump" do
      # Program:
      # load_imm_jump_ind r1, r2, imm1=42, imm2=2
      # padding bytes
      # fallthrough (target instruction at offset 10)
      program = <<
        op(:load_imm_jump_ind),
        0x21,
        1,
        42,
        1,
        op(:fallthrough)
      >>

      # Mark instruction starts
      bitmask = <<
        1,
        0,
        0,
        0,
        0,
        1
      >>

      # Set up register 2 with base address 8
      state = create_test_state(program, bitmask)
      state = %{state | registers: List.replace_at(state.registers, 2, 5)}
      state = %{state | jump_table: [2, 4, 6, 8, 10]}

      output = TwoRegistersTwoImmediates.execute(:load_imm_jump_ind, state, %StepOutput{})

      # Check immediate value was loaded
      assert Enum.at(output.registers, 1) == 42
      #  a will be 1 + 5 = 6
      # we will jimp to counter = jump_table[a / 2 -1] = jump_table[3 -1] = 6

      assert output.counter == 6
      assert output.exit_status == :continue
    end

    test "panics on unaligned jump address" do
      program = <<op(:load_imm_jump_ind), 0x21, 1, 42, 1>>
      bitmask = <<1, 0, 0, 0, 0>>

      state = create_test_state(program, bitmask)
      # Set register to create unaligned target (odd number)
      state = %{
        state
        | registers: List.replace_at(state.registers, 2, 2),
          jump_table: [2, 4, 6, 8, 10]
      }

      output = TwoRegistersTwoImmediates.execute(:load_imm_jump_ind, state, %StepOutput{})

      assert Enum.at(output.registers, 1) == 42
      assert output.exit_status == :panic
      assert output.counter == 0
    end
  end
end
