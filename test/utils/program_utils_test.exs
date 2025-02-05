defmodule PVM.Utils.ProgramUtilsTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.Utils.ProgramUtils
  alias PVM.{Registers, State, VM}

  describe "halt helpers" do
    test "create_halt_program creates minimal halting program" do
      {program, bitmask} = ProgramUtils.create_halt_program()
      p = PVM.Encoder.encode_program(program, bitmask, [], 1)
      {exit_reason, state} = VM.execute(p, %State{})
      assert exit_reason == :halt
      assert state.counter == 0
    end

    test "append_halt makes a complex program halt cleanly" do
      # Program that sums even numbers up to 10
      base_program = <<
        op(:load_imm), 1, 0,           # sum = 0
        op(:load_imm), 2, 1,           # i = 1
        op(:load_imm), 3, 10,          # end = 10
        op(:load_imm), 5, 2,           # divisor = 2
        op(:fallthrough),
        op(:branch_gt_u_imm), 0x12, 10, 20,  # if i > end, exit loop
        op(:rem_u_32), 0x52, 4,         # remainder = i % 2
        op(:branch_ne_imm), 0x14, 0, 8,  # if remainder != 0, skip
        op(:add_32), 0x12, 1,           # sum += i
        op(:fallthrough),
        op(:add_imm_32), 0x22, 1,       # i++
        op(:jump), 238,                  # loop
        op(:store_u32), 1, 3, 0, 1            # store result
      >>

      base_bitmask = <<
        1, 0, 0,           # load_imm sum
        1, 0, 0,           # load_imm i
        1, 0, 0,           # load_imm end
        1, 0, 0,           # load_imm divisor
        1,                 # fallthrough
        1, 0, 0, 0,        # branch_gt_u_imm
        1, 0, 0,           # rem_u_32
        1, 0, 0, 0,        # branch_ne_imm
        1, 0, 0,          # add_32
        1,                 # fallthrough
        1, 0, 0,           # add_imm_32
        1, 0,              # jump
        1, 0, 0, 0, 0  # store_u32
      >>

      {program, bitmask} = ProgramUtils.append_halt(base_program, base_bitmask)
      p = PVM.Encoder.encode_program(program, bitmask, [], 1)
      {exit_reason, state} = VM.execute(p, %State{})

      # Should halt and have executed the original instructions
      assert exit_reason == :halt
      assert state.counter == 0
      assert Registers.get(state.registers, [1, 2, 3]) == [30, 11, 10]
    end
  end
end
