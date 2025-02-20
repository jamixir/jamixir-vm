defmodule Instructions.RegTwoImmTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.RegTwoImm, Memory, Registers, State}

  @min_memory_addr 0x10000
  @init_target_addr @min_memory_addr + 10
  @offset 2
  @final_target_addr @init_target_addr + @offset

  describe "store_imm_ind operations" do
    test "store_imm_ind_u8 writes byte value at register-based address" do
      # Set up register 1 with base address 10
      program = <<op(:store_imm_ind_u8), 17, @offset, 42>>
      bitmask = <<8::4>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      assert Memory.read(state.memory, @final_target_addr, 1) == {:ok, <<42>>}
    end

    test "store_imm_ind_u16 writes 16-bit value at register-based address" do
      program = <<op(:store_imm_ind_u16), 33, @offset, 0, 34, 12>>
      bitmask = <<64::6>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u16, program, bitmask, state)
      assert Memory.read(state.memory, @final_target_addr, 2) == {:ok, <<34, 12>>}
    end

    test "store_imm_ind_u32 writes 32-bit value at register-based address" do
      program = <<op(:store_imm_ind_u32), 33, @offset, 0, 78, 56, 34, 12>>
      bitmask = <<128>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u32, program, bitmask, state)
      assert Memory.read(state.memory, @final_target_addr, 4) == {:ok, <<78, 56, 34, 12>>}
    end

    test "store_imm_ind_u64 writes 64-bit value at register-based address" do
      program = <<op(:store_imm_ind_u64), 33, @offset, 0, 78, 56, 34, 12, 0, 0, 0, 0>>
      bitmask = <<128>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u64, program, bitmask, state)

      assert Memory.read(state.memory, @final_target_addr, 8) ==
               {:ok, <<78, 56, 34, 12, 0, 0, 0, 0>>}
    end

    test "store_imm_ind_u8 handles value wrapping" do
      program = <<op(:store_imm_ind_u8), 0x11, @offset, 300>>
      bitmask = <<8::4>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      assert Memory.read(state.memory, @final_target_addr, 1) == {:ok, <<44>>}
    end

    test "store_imm_ind_u16 handles value wrapping" do
      program = <<op(:store_imm_ind_u16), 0x11, @offset, 0xFF, 0xFF>>
      bitmask = <<16::5>>
      state = %State{registers: %Registers{r1: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u16, program, bitmask, state)
      # Should write full 16-bit value
      assert Memory.read(state.memory, @final_target_addr, 2) == {:ok, <<0xFF, 0xFF>>}
    end

    test "handles register index bounds" do
      # Test with register index > 12 (should be capped at 12)
      program = <<op(:store_imm_ind_u8), 0x1F, @offset, 42>>
      bitmask = <<8::4>>
      state = %State{registers: %Registers{r12: @init_target_addr}}

      {_, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      assert Memory.read(state.memory, @final_target_addr, 1) == {:ok, <<42>>}
    end
  end
end
