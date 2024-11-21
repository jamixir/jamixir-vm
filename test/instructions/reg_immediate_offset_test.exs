defmodule Instructions.RegImmediateOffsetTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.RegImmediateOffset

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

  describe "load_imm_jump" do
    test "loads immediate value and jumps" do
      # Program: load_imm_jump r1, 42, target=10
      state = create_test_state(<<op(:load_imm_jump), 0x11, 42, 4>>, <<1, 0, 0, 0>>)
      output = RegImmediateOffset.execute(:load_imm_jump, state, %StepOutput{})

      assert Enum.at(output.registers, 1) == 42
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "handles invalid jump target" do
      # Jump target not marked as instruction start
      state = create_test_state(<<op(:load_imm_jump), 0x11, 42, 10>>, <<1, 0, 0>>)
      output = RegImmediateOffset.execute(:load_imm_jump, state, %StepOutput{})

      assert output.exit_status == :panic
    end
  end

  describe "unsigned comparison branches" do
    test "branch_eq_imm compares equal values" do
      state =
        create_test_state(
          <<op(:branch_eq_imm), 0x11, 42, 9, op(:store_imm_u8), 0x01, 10, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      output = RegImmediateOffset.execute(:branch_eq_imm, state, %StepOutput{})

      assert output.counter == 9
      assert output.exit_status == :continue
    end

    test "branch_ne_imm compares unequal values" do
      state =
        create_test_state(
          <<op(:branch_ne_imm), 0x11, 42, 10, op(:store_imm_u8), 0x01, 10, 5, op(:trap),
            op(:fallthrough)>>,
          <<1, 0, 0, 0, 1, 0, 0, 0, 1, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 43)}
      output = RegImmediateOffset.execute(:branch_ne_imm, state, %StepOutput{})

      assert output.counter == 10
      assert output.exit_status == :continue
    end

    test "branch_lt_u_imm compares unsigned values" do
      state =
        create_test_state(
          <<op(:branch_lt_u_imm), 0x11, 0xFF, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x7F)}
      output = RegImmediateOffset.execute(:branch_lt_u_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_le_u_imm handles equal values" do
      state =
        create_test_state(
          <<op(:branch_le_u_imm), 0x11, 0x80, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x80)}
      output = RegImmediateOffset.execute(:branch_le_u_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_ge_u_imm handles greater values" do
      state =
        create_test_state(
          <<op(:branch_ge_u_imm), 0x11, 0x7F, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFF)}
      output = RegImmediateOffset.execute(:branch_ge_u_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_gt_u_imm handles strictly greater values" do
      state =
        create_test_state(
          <<op(:branch_gt_u_imm), 0x11, 0x7F, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x80)}
      output = RegImmediateOffset.execute(:branch_gt_u_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end
  end

  describe "signed comparison branches" do
    test "branch_lt_s_imm compares signed values" do
      state =
        create_test_state(
          <<op(:branch_lt_s_imm), 0x11, 0x07, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x04)}
      output = RegImmediateOffset.execute(:branch_lt_s_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_le_s_imm handles equal signed values" do
      state =
        create_test_state(
          <<op(:branch_le_s_imm), 0x11, 0x08, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x08)}
      output = RegImmediateOffset.execute(:branch_le_s_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_ge_s_imm handles greater signed values" do
      state =
        create_test_state(
          <<op(:branch_ge_s_imm), 0x11, 0x0D, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x0F)}
      output = RegImmediateOffset.execute(:branch_ge_s_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "branch_gt_s_imm handles strictly greater signed values" do
      state =
        create_test_state(
          <<op(:branch_gt_s_imm), 0x11, 0x0C, 5, op(:fallthrough)>>,
          <<1, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x0D)}
      output = RegImmediateOffset.execute(:branch_gt_s_imm, state, %StepOutput{})

      assert output.counter == 5
      assert output.exit_status == :continue
    end
  end

  describe "parameter extraction" do
    test "handles multi-byte immediate and offset values" do
      state =
        create_test_state(
          <<op(:branch_eq_imm), 0x21, 0xFF, 0x0F, 0x05, 0x00, op(:fallthrough)>>,
          <<1, 0, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x0FFF)}
      output = RegImmediateOffset.execute(:branch_eq_imm, state, %StepOutput{})

      assert output.counter == 0x05
      assert output.exit_status == :continue
    end

    test "caps register index to 12" do
      state =
        create_test_state(
          <<op(:branch_eq_imm), 0x5D, 0x2A, 0x00, 0x00, 0x00,  7, op(:fallthrough)>>,
          <<1, 0, 0, 0, 0,0,0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 12, 42)}
      output = RegImmediateOffset.execute(:branch_eq_imm, state, %StepOutput{})

      assert output.counter == 7
      assert output.exit_status == :continue
    end
  end
end
