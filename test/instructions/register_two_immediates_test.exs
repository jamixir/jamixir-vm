defmodule Instructions.RegTwoImmTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.RegTwoImm
  alias PVM.State

  describe "store_imm_ind operations" do
    test "store_imm_ind_u8 writes byte value at register-based address" do
      # Set up register 1 with base address 10
      program = <<op(:store_imm_ind_u8), 17, 2, 42>>
      bitmask = <<1, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 1) == {:ok, <<42>>}
    end

    test "store_imm_ind_u16 writes 16-bit value at register-based address" do
      program = <<op(:store_imm_ind_u16), 33, 2, 0, 34, 12>>
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u16, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 2) == {:ok, <<34, 12>>}
    end

    test "store_imm_ind_u32 writes 32-bit value at register-based address" do
      program = <<op(:store_imm_ind_u32), 33, 2, 0, 78, 56, 34, 12>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u32, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 4) == {:ok, <<78, 56, 34, 12>>}
    end

    test "store_imm_ind_u64 writes 64-bit value at register-based address" do
      program = <<op(:store_imm_ind_u64), 33, 2, 0, 78, 56, 34, 12, 0, 0, 0, 0>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u64, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 8) == {:ok, <<78, 56, 34, 12, 0, 0, 0, 0>>}
    end

    test "store_imm_ind_u8 handles value wrapping" do
      program = <<op(:store_imm_ind_u8), 0x11, 2, 300>>
      bitmask = <<1, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 1) == {:ok, <<44>>}
    end

    test "store_imm_ind_u16 handles value wrapping" do
      program = <<op(:store_imm_ind_u16), 0x11, 2, 0xFF, 0xFF>>
      bitmask = <<1, 0, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 1, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u16, program, bitmask, state)
      # Should write full 16-bit value
      assert Memory.read(state.memory, 12, 2) == {:ok, <<0xFF, 0xFF>>}
    end

    test "handles register index bounds" do
      # Test with register index > 12 (should be capped at 12)
      program = <<op(:store_imm_ind_u8), 0x1F, 2, 42>>
      bitmask = <<1, 0, 0, 0>>
      state = %State{registers: List.replace_at(%State{}.registers, 12, 10)}

      {exit_status, state} = RegTwoImm.execute(:store_imm_ind_u8, program, bitmask, state)
      # Should write at address register[1] + 2 = 12
      assert Memory.read(state.memory, 12, 1) == {:ok, <<42>>}
    end
  end
end
