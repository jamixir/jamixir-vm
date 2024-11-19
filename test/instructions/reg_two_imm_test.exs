defmodule Instructions.RegTwoImmTest do
  use ExUnit.Case
  alias Instructions.RegTwoImm

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

  describe "store_imm_ind operations" do
    test "store_imm_ind_u8 writes byte value at register-based address" do
      # Set up register 1 with base address 10
      state = create_test_state(<<26, 17, 2, 42>>, <<1, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u8, state, %StepOutput{})
      # Should write at address register[1] + 2 = 12
      assert Memory.read(output.memory, 12, 1) == <<42>>
    end

    test "store_imm_ind_u16 writes 16-bit value at register-based address" do
      state = create_test_state(<<54, 33, 2, 0, 34, 12>>, <<1, 0, 0, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u16, state, %StepOutput{})
      # Should write at address register[1] + 2 = 12
      assert Memory.read(output.memory, 12, 2) == <<34, 12>>
    end

    test "store_imm_ind_u32 writes 32-bit value at register-based address" do
      state =
        create_test_state(
          <<26, 33, 2, 0, 78, 56, 34, 12>>,
          <<1, 0, 0, 0, 0, 0, 0, 0>>
        )

      state = %{state | registers: List.replace_at(state.registers, 1, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u32, state, %StepOutput{})
      # Should write at address register[1] + 2 = 12
      assert Memory.read(output.memory, 12, 4) == <<78, 56, 34, 12>>
    end

    test "store_imm_ind_u8 handles value wrapping" do
      state = create_test_state(<<0x3E, 0x11, 2, 300>>, <<1, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u8, state, %StepOutput{})
      # 300 mod 256 = 44
      assert Memory.read(output.memory, 12, 1) == <<44>>
    end

    test "store_imm_ind_u16 handles value wrapping" do
      state = create_test_state(<<0x4F, 0x11, 2, 0xFF, 0xFF>>, <<1, 0, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u16, state, %StepOutput{})
      # Should write full 16-bit value
      assert Memory.read(output.memory, 12, 2) == <<0xFF, 0xFF>>
    end

    test "handles register index bounds" do
      # Test with register index > 12 (should be capped at 12)
      state = create_test_state(<<0x3E, 0xF1, 2, 42>>, <<1, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 12, 10)}

      output = RegTwoImm.execute(:store_imm_ind_u8, state, %StepOutput{})
      assert Memory.read(output.memory, 12, 1) == <<42>>
    end
  end
end
