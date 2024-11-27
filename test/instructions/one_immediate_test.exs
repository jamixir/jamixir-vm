defmodule Instructions.OneImmediateTest do
  use ExUnit.Case
  use PVM.Instructions

  alias PVM.{State, Instructions.OneImmediate}

  describe "ecalli" do
    test "sets ecall exit status with immediate value" do
      program = <<op(:ecalli), 42>>
      bitmask = <<1, 0>>
      {exit_reason, _} = OneImmediate.execute(:ecalli, program, bitmask, %State{})
      assert exit_reason == {:ecall, 42}
    end

    test "handles multi-byte immediate" do
      program = <<op(:ecalli), 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0>>
      {exit_reason, _} = OneImmediate.execute(:ecalli, program, bitmask, %State{})
      assert exit_reason == {:ecall, 0x12345678}
    end
  end

  describe "jump" do
    test "jumps forward to valid target" do
      program = <<op(:jump), 3, 0, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>
      {exit_reason, state_} = OneImmediate.execute(:jump, program, bitmask, %State{})
      assert exit_reason == :continue
      assert state_.counter == 3
    end

    test "jumps backward to valid target" do
      program = <<op(:fallthrough), op(:jump), 255>>
      bitmask = <<1, 1, 0>>
      {exit_reason, state_} = OneImmediate.execute(:jump, program, bitmask, %State{counter: 1})
      assert exit_reason == :continue
      assert state_.counter == 0
    end

    test "panics on invalid target" do
      program = <<op(:jump), 1, op(:fallthrough)>>
      bitmask = <<1, 0, 1>>
      {exit_reason, _} = OneImmediate.execute(:jump, program, bitmask, %State{})
      assert exit_reason == :panic
    end
  end
end
