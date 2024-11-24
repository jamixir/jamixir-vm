defmodule Instructions.RegImmediateOffsetTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.RegImmediateOffset
  alias PVM.State
  describe "load_imm_jump" do
    test "loads immediate value and jumps" do
      # Program: load_imm_jump r1, 42, target=10
      program = <<op(:load_imm_jump), 0x11, 42, 4>>
      bitmask = <<1, 0, 0, 0>>

      {exit_reason, state_} =
        RegImmediateOffset.execute(:load_imm_jump, program, bitmask, %State{})

      assert Enum.at(state_.registers, 1) == 42
      assert state_.counter == 4
      assert exit_reason == :continue
    end

    test "handles invalid jump target" do
      # Jump target not marked as instruction start
      program = <<op(:load_imm_jump), 0x11, 42, 10>>
      bitmask = <<1, 0, 0>>

      {exit_reason, state_} =
        RegImmediateOffset.execute(:load_imm_jump, program, bitmask, %State{})

      assert exit_reason == :panic
    end
  end

  describe "unsigned comparison branches" do
    test "branch_eq_imm compares equal values" do
      program =
        <<op(:branch_eq_imm), 0x11, 42, 9, op(:store_imm_u8), 0x01, 10, 5, op(:fallthrough)>>

      bitmask = <<1, 0, 0, 0, 1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 42)}
      {exit_reason, state_} = RegImmediateOffset.execute(:branch_eq_imm, program, bitmask, state)

      assert state_.counter == 9
      assert exit_reason == :continue
    end

    test "branch_ne_imm compares unequal values" do
      program =
        <<op(:branch_ne_imm), 0x11, 42, 10, op(:store_imm_u8), 0x01, 10, 5, op(:trap),
          op(:fallthrough)>>

      bitmask = <<1, 0, 0, 0, 1, 0, 0, 0, 1, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 43)}
      {exit_reason, state_} = RegImmediateOffset.execute(:branch_ne_imm, program, bitmask, state)

      assert state_.counter == 10
      assert exit_reason == :continue
    end

    test "branch_lt_u_imm compares unsigned values" do
      program = <<op(:branch_lt_u_imm), 0x11, 0xFF, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x7F)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_lt_u_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_le_u_imm handles equal values" do
      program = <<op(:branch_le_u_imm), 0x11, 0x80, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x80)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_le_u_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_ge_u_imm handles greater values" do
      program = <<op(:branch_ge_u_imm), 0x11, 0x7F, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x80)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_ge_u_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_gt_u_imm handles strictly greater values" do
      program = <<op(:branch_gt_u_imm), 0x11, 0x7F, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x80)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_gt_u_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end
  end

  describe "signed comparison branches" do
    test "branch_lt_s_imm compares signed values" do
      program = <<op(:branch_lt_s_imm), 0x11, 0x07, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x04)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_lt_s_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_le_s_imm handles equal signed values" do
      program = <<op(:branch_le_s_imm), 0x11, 0x08, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x08)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_le_s_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_ge_s_imm handles greater signed values" do
      program = <<op(:branch_ge_s_imm), 0x11, 0x0D, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x0F)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_ge_s_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end

    test "branch_gt_s_imm handles strictly greater signed values" do
      program = <<op(:branch_gt_s_imm), 0x11, 0x0C, 5, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x0D)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_gt_s_imm, program, bitmask, state)

      assert state_.counter == 5
      assert exit_reason == :continue
    end
  end

  describe "parameter extraction" do
    test "handles multi-byte immediate and offset values" do
      program = <<op(:branch_eq_imm), 0x21, 0xFF, 0x0F, 0x05, 0x00, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 0x0FFF)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_eq_imm, program, bitmask, state)

      assert state_.counter == 0x05
      assert exit_reason == :continue
    end

    test "caps register index to 12" do
      program = <<op(:branch_eq_imm), 0x5D, 0x2A, 0x00, 0x00, 0x00, 7, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 1>>
      state = %State{registers: List.replace_at(%State{}.registers, 12, 42)}

      {exit_reason, state_} =
        RegImmediateOffset.execute(:branch_eq_imm, program, bitmask, state)

      assert state_.counter == 7
      assert exit_reason == :continue
    end
  end
end
