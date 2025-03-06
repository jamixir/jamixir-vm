defmodule Instructions.TwoImmediatesTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoImmediates, Memory, State, InitProgram, Registers}

  setup_all do
    memory = InitProgram.construct_memory("code", "data", "args", 1, 1)
    stack_addr = InitProgram.boundaries(4, 4, 4, 1, 1).stack_start
    state = %State{memory: memory, registers: %Registers{r2: stack_addr}}
    {:ok, %{memory: memory, stack_addr: stack_addr, state: state}}
  end

  describe "store immediate operations" do
    test "store_imm_u8 writes byte value", %{state: state, stack_addr: stack_addr} do
      program = <<op(:store_imm_u8), 4, stack_addr::little-size(32), 42>>
      bitmask = <<64::7>>

      {_, state} = TwoImmediates.execute(:store_imm_u8, program, bitmask, state)
      assert Memory.read(state.memory, stack_addr, 1) == {:ok, <<42>>}
    end

    test "store_imm_u16 writes 16-bit value", %{state: state, stack_addr: stack_addr} do
      program = <<op(:store_imm_u16), 4, stack_addr::little-size(32), 0x34, 0x12>>
      bitmask = <<256::9>>

      {_, state} = TwoImmediates.execute(:store_imm_u16, program, bitmask, state)
      assert Memory.read(state.memory, stack_addr, 2) == {:ok, <<0x34, 0x12>>}
    end

    test "store_imm_u32 writes 32-bit value", %{state: state, stack_addr: stack_addr} do
      program = <<op(:store_imm_u32), 4, stack_addr::little-size(32), 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<512::10>>

      {_, state} = TwoImmediates.execute(:store_imm_u32, program, bitmask, state)
      assert Memory.read(state.memory, stack_addr, 4) == {:ok, <<0x78, 0x56, 0x34, 0x12>>}
    end

    test "store_imm_u64 writes 64-bit value", %{state: state, stack_addr: stack_addr} do
      program = <<op(:store_imm_u64), 4, stack_addr::little-size(32), 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1024::11>>

      {_, state} = TwoImmediates.execute(:store_imm_u64, program, bitmask, state)

      assert Memory.read(state.memory, stack_addr, 8) ==
               {:ok, <<0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0>>}
    end
  end
end
