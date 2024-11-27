defmodule Instructions.TwoImmediatesTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoImmediates, Memory, State}

  describe "store immediate operations" do
    test "store_imm_u8 writes byte value" do
      program = <<op(:store_imm_u8), 0x01, 10, 42>>
      bitmask = <<1, 0, 0, 0>>

      {_, state} = TwoImmediates.execute(:store_imm_u8, program, bitmask, %State{})
      assert Memory.read(state.memory, 10, 1) == {:ok, <<42>>}
    end

    test "store_imm_u16 writes 16-bit value" do
      program = <<op(:store_imm_u16), 0x01, 10, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0>>

      {_, state} = TwoImmediates.execute(:store_imm_u16, program, bitmask, %State{})
      assert Memory.read(state.memory, 10, 2) == {:ok, <<0x34, 0x12>>}
    end

    test "store_imm_u32 writes 32-bit value" do
      program = <<op(:store_imm_u32), 0x01, 10, 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0>>

      {_, state} = TwoImmediates.execute(:store_imm_u32, program, bitmask, %State{})
      assert Memory.read(state.memory, 10, 4) == {:ok, <<0x78, 0x56, 0x34, 0x12>>}
    end

    test "store_imm_u64 writes 64-bit value" do
      program = <<op(:store_imm_u64), 0x01, 10, 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0>>

      {_, state} = TwoImmediates.execute(:store_imm_u64, program, bitmask, %State{})
      assert Memory.read(state.memory, 10, 8) == {:ok, <<0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0>>}
    end
  end
end
