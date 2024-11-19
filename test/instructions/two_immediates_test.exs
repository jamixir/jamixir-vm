defmodule Instructions.TwoImmediatesTest do
  use ExUnit.Case
  alias Instructions.TwoImmediates

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

  describe "store immediate operations" do
    test "store_imm_u8 writes byte value" do
      state = create_test_state(<<0x3E, 0x01, 10, 42>>, <<1, 0, 0, 0>>)
      output = TwoImmediates.execute(:store_imm_u8, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 1) == <<42>>
    end

    test "store_imm_u16 writes 16-bit value" do
      state = create_test_state(<<0x4F, 0x01, 10, 0x34, 0x12>>, <<1, 0, 0, 0, 0>>)
      output = TwoImmediates.execute(:store_imm_u16, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 2) == <<0x34, 0x12>>
    end

    test "store_imm_u32 writes 32-bit value" do
      state = create_test_state(
        <<0x26, 0x01, 10, 0x78, 0x56, 0x34, 0x12>>,
        <<1, 0, 0, 0, 0, 0, 0>>
      )
      output = TwoImmediates.execute(:store_imm_u32, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 4) == <<0x78, 0x56, 0x34, 0x12>>
    end
  end
end
