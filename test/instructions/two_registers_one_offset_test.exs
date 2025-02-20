defmodule Instructions.TwoRegistersOneOffsetTest do
  use ExUnit.Case
  use PVM.{Instructions, Utils}
  alias PVM.{Instructions.TwoRegistersOneOffset, Registers, State}

  describe "branch comparison operations" do
    test "branch_eq branches when values are equal" do
      program = <<op(:branch_eq), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)

      state = %State{registers: %Registers{r1: 42, r2: 42}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "branch_ne branches when values are not equal" do
      program = <<op(:branch_ne), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 42, r2: 43}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_ne, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "branch_lt_u branches on unsigned less than" do
      program = <<op(:branch_lt_u), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 0x7F, r2: 0xFF}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_lt_u, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "branch_lt_s branches on signed less than" do
      program = <<op(:branch_lt_s), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 0xFFFF_0000_0000_0001, r2: 0xFF00_0000_0000_00002}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_lt_s, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "branch_ge_u branches on unsigned greater or equal" do
      program = <<op(:branch_ge_u), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 0xFF, r2: 0x7F}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_ge_u, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "branch_ge_s branches on signed greater or equal" do
      program = <<op(:branch_ge_s), 0x21, 4, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 0xFF00_0000_0000_00002, r2: 0xFFFF_0000_0000_0001}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_ge_s, program, bitmask, start_set, state)
      assert exit_status == :continue
    end
  end

  describe "parameter handling" do
    test "caps register indices to 12" do
      program =
        <<op(:branch_eq), 0xFD, 5, op(:fallthrough), op(:fallthrough), op(:fallthrough),
          op(:fallthrough), op(:fallthrough)>>

      bitmask = <<79::7>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r12: 42}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "handles multi-byte offset values" do
      program = <<op(:branch_eq), 0x21, 0x05, 0x00, 0x00, 0x00, op(:fallthrough)>>
      bitmask = <<33::6>>
      start_set = basic_block_starts(program, bitmask)
      state = %State{registers: %Registers{r1: 42, r2: 42}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, start_set, state)
      assert exit_status == :continue
    end

    test "fails branch when target is invalid" do
      program = <<op(:branch_eq), 0x21, 10, op(:fallthrough)>>
      bitmask = <<9::4>>
      start_set = basic_block_starts(program, bitmask)

      state = %State{registers: %Registers{r1: 42, r2: 42}}

      {exit_status, _} = TwoRegistersOneOffset.execute(:branch_eq, program, bitmask, start_set, state)
      assert exit_status == :panic
    end
  end
end
