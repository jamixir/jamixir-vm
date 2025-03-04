defmodule SingleStepTest do
  use ExUnit.Case
  alias PVM.{State, SingleStep, Memory, Registers, InitProgram}
  use PVM.{Decoder, Utils, Instructions}
  setup_all do
    memory = InitProgram.construct_memory("code", "data", "args", 1, 1)
    stack_addr = InitProgram.boundaries(4, 4, 4, 1, 1).stack_start
    state = %State{memory: memory, registers: %Registers{r2: stack_addr}}
    {:ok, %{memory: memory, stack_addr: stack_addr, state: state}}
  end


  describe "SingleStep.run basic functionality" do
    test "step trap instruction" do
      program = <<op(:trap)>>
      bitmask = <<1::1>>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)
      state = %State{}
      {exit_reason,state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :panic
      assert state_.counter == 0
    end

    test "step out of bounds panics" do
      program = <<op(:trap)>>
      bitmask = <<1::1>>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)
      state = %State{counter: 4}
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :panic
      assert state_.counter == 4
    end

    test "step fallthrough" do
      program = <<op(:fallthrough)>>
      bitmask = <<1::1>>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)
      state = %State{}
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :continue
      assert state_.counter == 1
    end
  end

  describe "SingleStep.run instruction coverage" do
    test "steps all no-arg instructions" do
      # Test each no-arg instruction in sequence
      program = <<op(:trap), op(:fallthrough)>>
      bitmask = <<3::2>>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)

      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, %State{})
      assert exit_reason == :panic

      state_ = %{state_ | counter: 1}
      {exit_reason, _} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
    end

    test "steps all one-immediate instructions" do
      program = <<op(:ecalli),42, op(:jump), 2>>
      bitmask = <<10::4>>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, %State{})
      assert exit_reason == {:ecall, 42}

      state_ = %{state_ | counter: 2}
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
      assert state_.counter == 4
    end

    test "steps reg_immediate instructions", %{state: state, stack_addr: stack_addr} do

      program = <<op(:load_imm), 1, 42, op(:store_u8), 1, stack_addr::little-size(32), op(:load_u8), 2, stack_addr::little-size(32)>>
      bitmask = <<144, 0::1, 32::6 >>
      jump_table = []
      start_set = basic_block_starts(program, bitmask)

      # First instruction: load_imm
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :continue
      assert Registers.get(state_.registers, 1) == 42

      # Second instruction: store_u8
      # state_ = %{state_ | counter: 3, registers: state_.registers}
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok,<<42>>}

      # Third instruction: load_u8
      # state_ = %{state_ | counter: 6, memory: state_.memory}
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
      assert Registers.get(state_.registers, 2) == 42
    end

    test "steps two_immediates instructions", %{state: state, stack_addr: stack_addr} do
      program = <<
        op(:store_imm_u8), 4,   stack_addr::little-size(32), 42,
        op(:store_imm_u16), 4,  (stack_addr + 10)::little-size(32)  , 0x34, 0x12,
        op(:store_imm_u32), 4,  (stack_addr + 100)::little-size(32), 0x78, 0x56, 0x34, 0x12
       >>
      bitmask = <<129, 1, 0::9>> #10000001_00000001_000000000
      jump_table = []
      start_set = basic_block_starts(program, bitmask)
      # First instruction: store_imm_u8
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :continue
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok,<<42>>}

      # Second instruction: store_imm_u16
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
      assert Memory.read(state_.memory, stack_addr + 10, 2) == {:ok,<<0x34, 0x12>>}

      # Third instruction: store_imm_u32

      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)
      assert exit_reason == :continue
      assert Memory.read(state_.memory, stack_addr + 100, 4) == {:ok,<<0x78, 0x56, 0x34, 0x12>>}
    end
  end

  describe "SingleStep.run two registers instructions" do
    test "move_reg copies value between registers" do
      # Program:
      # load_imm r1, 42    # First load a value into r1
      # move_reg r2, r1    # Then move it to r2 (encoded as 0x21 - r2 in low bits, r1 in high)
      program = <<
        op(:load_imm),
        2,
        42,
        op(:move_reg),
        0x21
      >>

      bitmask = <<18::5>>
      start_set = basic_block_starts(program, bitmask)
      jump_table = []

      state = %State{}

      # First execute load_imm
      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state)
      assert exit_reason == :continue
      assert Registers.get(state_.registers, 2) == 42

      {exit_reason, state_} = SingleStep.run(program, bitmask, jump_table, start_set, state_)

      # rd = 1, ra = 2
      # w_d <- w_a

      assert exit_reason == :continue
      # r1 should now have r2's value
      assert Registers.get(state_.registers, 1) == 42
      # r2 should be unchanged
      assert Registers.get(state_.registers, 2) == 42
      # Should advance past the move_reg instruction
      assert state_.counter == 5
    end
  end
end
