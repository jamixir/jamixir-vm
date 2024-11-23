defmodule Instructions.TwoRegistersOneOffsetTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.TwoRegistersOneOffset

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

  describe "branch comparison operations" do
    test "branch_eq branches when values are equal" do
      state =
        create_test_state(
          <<op(:branch_eq), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      output = TwoRegistersOneOffset.execute(:branch_eq, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "branch_ne branches when values are not equal" do
      state =
        create_test_state(
          <<op(:branch_ne), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 43)}

      output = TwoRegistersOneOffset.execute(:branch_ne, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "branch_lt_u branches on unsigned less than" do
      state =
        create_test_state(
          <<op(:branch_lt_u), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0x7F)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFF)}

      output = TwoRegistersOneOffset.execute(:branch_lt_u, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "branch_lt_s branches on signed less than" do
      state =
        create_test_state(
          <<op(:branch_lt_s), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFF_0000_0000_0001)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFF00_0000_0000_00002)}

      output = TwoRegistersOneOffset.execute(:branch_lt_s, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "branch_ge_u branches on unsigned greater or equal" do
      state =
        create_test_state(
          <<op(:branch_ge_u), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x7F)}

      output = TwoRegistersOneOffset.execute(:branch_ge_u, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end

    test "branch_ge_s branches on signed greater or equal" do
      state =
        create_test_state(
          <<op(:branch_ge_s), 0x21, 4, op(:fallthrough)>>,
          <<1, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFF00_0000_0000_00002)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFF_0000_0000_0001)}

      output = TwoRegistersOneOffset.execute(:branch_ge_s, state, %StepOutput{})
      assert output.counter == 4
      assert output.exit_status == :continue
    end
  end

  describe "parameter handling" do
    test "caps register indices to 12" do
      state =
        create_test_state(
          <<op(:branch_eq), 0xFD, 5, op(:fallthrough), op(:fallthrough), op(:fallthrough),
            op(:fallthrough), op(:fallthrough)>>,
          <<1, 0, 0, 1, 1, 1, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 12, 42)}
      state = %{state | registers: List.replace_at(state.registers, 12, 42)}

      output = TwoRegistersOneOffset.execute(:branch_eq, state, %StepOutput{})
      assert output.counter == 5
      assert output.exit_status == :continue
    end

    test "handles multi-byte offset values" do
      state =
        create_test_state(
          <<op(:branch_eq), 0x21, 0x05, 0x00, 0x00, 0x00, op(:fallthrough)>>,
          <<1, 0, 0, 0, 0, 1>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      output = TwoRegistersOneOffset.execute(:branch_eq, state, %StepOutput{})
      assert output.counter == 0x05
      assert output.exit_status == :continue
    end

    test "fails branch when target is invalid" do
      state =
        create_test_state(
          <<op(:branch_eq), 0x21, 10, op(:fallthrough)>>,
          <<1, 0, 0>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      output = TwoRegistersOneOffset.execute(:branch_eq, state, %StepOutput{})
      assert output.exit_status == :panic
    end
  end
end
