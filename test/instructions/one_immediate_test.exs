defmodule Instructions.OneImmediateTest do
  use ExUnit.Case
  use Instructions
  
  alias Instructions.OneImmediate

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

  describe "ecalli" do
    test "sets ecall exit status with immediate value" do
      state = create_test_state(<<op(:ecalli), 42>>, <<1, 0>>)
      output = OneImmediate.execute(:ecalli, state, %StepOutput{})
      assert output.exit_status == {:ecall, 42}
    end

    test "handles multi-byte immediate" do
      state = create_test_state(<<op(:ecalli), 0x78, 0x56, 0x34, 0x12>>, <<1, 0, 0, 0, 0>>)
      output = OneImmediate.execute(:ecalli, state, %StepOutput{})
      assert output.exit_status == {:ecall, 0x12345678}
    end
  end

  describe "jump" do
    test "jumps forward to valid target" do
      state = create_test_state(<<op(:jump), 3, 0, op(:fallthrough)>>, <<1, 0, 0, 1>>)
      output = OneImmediate.execute(:jump, state, %StepOutput{})
      assert output.exit_status == :continue
      assert output.counter == 3
    end

    test "jumps backward to valid target" do
      state = create_test_state(<<op(:fallthrough), op(:jump), 255>>, <<1, 1, 0>>)
      state = %{state | counter: 1}
      output = OneImmediate.execute(:jump, state, %StepOutput{})
      assert output.exit_status == :continue
      assert output.counter == 0
    end

    test "panics on invalid target" do
      state = create_test_state(<<op(:jump), 1, op(:fallthrough)>>, <<1, 0, 1>>)
      output = OneImmediate.execute(:jump, state, %StepOutput{})
      assert output.exit_status == :panic
    end
  end
end
