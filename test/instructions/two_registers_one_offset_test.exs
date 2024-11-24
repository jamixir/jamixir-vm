defmodule Instructions.TwoRegistersOneOffsetTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.TwoRegistersOneOffset
  alias PVM.State

  describe "branch comparison operations" do
    test "branch_eq branches when values are equal" do
      program = <<op(:branch_eq), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, state)
      assert exit_status == :continue
    end

    test "branch_ne branches when values are not equal" do
      program = <<op(:branch_ne), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 43)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_ne, program, bitmask, state)
      assert exit_status == :continue
    end

    test "branch_lt_u branches on unsigned less than" do
      program = <<op(:branch_lt_u), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 0x7F)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFF)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_lt_u, program, bitmask, state)
      assert exit_status == :continue
    end

    test "branch_lt_s branches on signed less than" do
      program = <<op(:branch_lt_s), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFF_0000_0000_0001)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFF00_0000_0000_00002)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_lt_s, program, bitmask, state)
      assert exit_status == :continue
    end

    test "branch_ge_u branches on unsigned greater or equal" do
      program = <<op(:branch_ge_u), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x7F)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_ge_u, program, bitmask, state)
      assert exit_status == :continue
    end

    test "branch_ge_s branches on signed greater or equal" do
      program = <<op(:branch_ge_s), 0x21, 4, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 0xFF00_0000_0000_00002)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFF_0000_0000_0001)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_ge_s, program, bitmask, state)
      assert exit_status == :continue
    end
  end

  describe "parameter handling" do
    test "caps register indices to 12" do
      program = <<op(:branch_eq), 0xFD, 5, op(:fallthrough), op(:fallthrough), op(:fallthrough),
            op(:fallthrough), op(:fallthrough)>>
      bitmask = <<1, 0, 0, 1, 1, 1, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 12, 42)}
      state = %{state | registers: List.replace_at(state.registers, 12, 42)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, state)
      assert exit_status == :continue
    end

    test "handles multi-byte offset values" do
      program = <<op(:branch_eq), 0x21, 0x05, 0x00, 0x00, 0x00, op(:fallthrough)>>
      bitmask = <<1, 0, 0, 0, 0, 1>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, state)
      assert exit_status == :continue
    end

    test "fails branch when target is invalid" do
      program = <<op(:branch_eq), 0x21, 10, op(:fallthrough)>>
      bitmask = <<1, 0, 0>>

      state = %State{}

      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 42)}

      {exit_status, state} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, state)
      assert exit_status == :panic
    end
  end
end
