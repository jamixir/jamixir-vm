defmodule SingleStepTest do
  use ExUnit.Case
  alias PVM.State
  use PVM.Decoder
  use PVM.Utils
  use Instructions

  def create_test_state(program, bitmask) do
    %State{
      program: program,
      bitmask: bitmask,
      jump_table: [],
      counter: 0,
      gas: 100,
      registers: List.duplicate(0, 13),
      memory: %Memory{}
    }
  end

  describe "SingleStep.run basic functionality" do
    test "step trap instruction" do
      state = create_test_state(<<op(:trap)>>, <<1>>)
      output = SingleStep.run(state)
      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "step out of bounds panics" do
      state = create_test_state(<<op(:trap)>>, <<1>>)
      state = %{state | counter: 4}
      output = SingleStep.run(state)
      assert output.exit_status == :panic
      assert output.counter == 4
    end

    test "step fallthrough" do
      state = create_test_state(<<op(:fallthrough)>>, <<1>>)
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert output.counter == 1
    end
  end

  describe "SingleStep.run instruction coverage" do
    test "steps all no-arg instructions" do
      # Test each no-arg instruction in sequence
      state = create_test_state(<<op(:trap), op(:fallthrough)>>, <<1, 1>>)

      output = SingleStep.run(state)
      assert output.exit_status == :panic

      state = %{state | counter: 1}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
    end

    test "steps all one-immediate instructions" do
      state =
        create_test_state(
          <<
            op(:ecalli),
            42,
            op(:jump),
            2
          >>,
          <<1, 0, 1, 0>>
        )

      output = SingleStep.run(state)
      assert output.exit_status == {:ecall, 42}

      state = %{state | counter: 2}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert output.counter == 4
    end

    test "steps reg_immediate instructions" do
      state =
        create_test_state(
          <<
            op(:load_imm),
            1,
            42,
            op(:store_u8),
            1,
            10,
            op(:load_u8),
            2,
            10
          >>,
          <<1, 0, 0, 1, 0, 0, 1, 0, 0>>
        )

      # First instruction: load_imm
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Enum.at(output.registers, 1) == 42

      # Second instruction: store_u8
      state = %{state | counter: 3, registers: output.registers}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 10, 1) == <<42>>

      # Third instruction: load_u8
      state = %{state | counter: 6, memory: output.memory}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Enum.at(output.registers, 2) == 42
    end

    test "steps two_immediates instructions" do
      state =
        create_test_state(
          <<
            op(:store_imm_u8),
            0x01,
            10,
            42,
            op(:store_imm_u16),
            0x01,
            20,
            0x34,
            0x12,
            op(:store_imm_u32),
            0x01,
            30,
            0x78,
            0x56,
            0x34,
            0x12
          >>,
          <<1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0>>
        )

      # First instruction: store_imm_u8
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 10, 1) == <<42>>

      # Second instruction: store_imm_u16
      state = %{state | counter: 4, memory: output.memory}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 20, 2) == <<0x34, 0x12>>

      # Third instruction: store_imm_u32
      state = %{state | counter: 9, memory: output.memory}
      output = SingleStep.run(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 30, 4) == <<0x78, 0x56, 0x34, 0x12>>
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

      bitmask = <<1, 0, 0, 1, 0>>

      state = create_test_state(program, bitmask)

      # First execute load_imm
      output = SingleStep.run(state)
      assert Enum.at(output.registers, 2) == 42

      # Then execute move_reg
      state = State.new(state.program, state.bitmask, state.jump_table, output)
      output = SingleStep.run(state)

      # rd = 1, ra = 2
      # w_d <- w_a

      assert output.exit_status == :continue
      # r1 should now have r2's value
      assert Enum.at(output.registers, 1) == 42
      # r2 should be unchanged
      assert Enum.at(output.registers, 2) == 42
      # Should advance past the move_reg instruction
      assert output.counter == 5
    end
  end
end
