defmodule Instructions.TwoRegistersTwoImmediatesTest do
  use ExUnit.Case
  use PVM.{Instructions, Utils}
  alias PVM.{Instructions.TwoRegistersTwoImmediates, Registers, State}

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
      bitmask = <<33::6>>
      start_set = basic_block_starts(program, bitmask)
      jump_table = [2, 4, 6, 8, 10]

      # Set up register 2 with base address 8
      state = %State{registers: %Registers{r2: 5}}

      {exit_status, state} =
        TwoRegistersTwoImmediates.execute(
          :load_imm_jump_ind,
          program,
          bitmask,
          jump_table,
          start_set,
          state
        )

      # Check immediate value was loaded
      assert state.registers.r1 == 42
      #  a will be 1 + 5 = 6
      # we will jimp to counter = jump_table[a / 2 -1] = jump_table[3 -1] = 6

      assert state.counter == 6
      assert exit_status == :continue
    end

    test "panics on unaligned jump address" do
      program = <<op(:load_imm_jump_ind), 0x21, 1, 42, 1>>
      bitmask = <<16::5>>
      start_set = basic_block_starts(program, bitmask)
      jump_table = [2, 4, 6, 8, 10]

      # Set register to create unaligned target (odd number)
      state = %State{registers: %Registers{r2: 2}}

      {exit_status, state} =
        TwoRegistersTwoImmediates.execute(
          :load_imm_jump_ind,
          program,
          bitmask,
          jump_table,
          start_set,
          state
        )

      assert state.registers.r1 == 42
      assert exit_status == :panic
      assert state.counter == 0
    end
  end
end
