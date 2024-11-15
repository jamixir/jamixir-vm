defmodule VMTest do
  use ExUnit.Case
  alias PVM.State

  def create_test_state(program, bitmask) do
    %State{
      program: program,
      bitmask: bitmask,
      jump_table: [],
      counter: 0,
      gas: 100,
      registers: List.duplicate(0, 13),
      memory: Memory.new(100)
    }
  end

  describe "trap instruction" do
    test "step trap instruction" do
      state = create_test_state(<<0, 0, 0, 0>>, <<1, 1, 0, 0>>)
      output = VM.step(state)

      assert output.exit_status == :panic
      assert output.counter == state.counter + 1
      assert output.gas == state.gas
      assert output.registers == state.registers
      assert output.memory == state.memory
    end

    test "execute trap" do
      state = create_test_state(<<0, 0, 0, 0>>, <<1, 1, 0, 0>>)
      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 1
      assert output.gas == 100
      assert output.registers == List.duplicate(0, 13)
      assert output.memory == Memory.new(100)
    end

    test "step trap out of bounds" do
      state = create_test_state(<<0, 0, 0, 0>>, <<1, 1, 0, 0>>)
      state = %{state | counter: 4}  # Beyond program length
      output = VM.step(state)

      assert output.exit_status == :halt
      assert output.counter == 4
      assert output.gas == 100
      assert output.registers == List.duplicate(0, 13)
      assert output.memory == Memory.new(100)
    end
  end

  describe "store_imm_u8 instruction" do
    test "store simple value" do
      state = create_test_state(
        <<
          0x3E,  # StoreImmU8 opcode
          0x01,  # Use 1 byte each for address and value
          0x01,  # Address: 1
          0x05   # Value: 5
        >>,
        <<1, 0, 0, 0>>  # Each byte is part of this instruction
      )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 1) == <<5>>
      assert output.counter == 4
    end

    test "store u8 value truncation" do
      state = create_test_state(
        <<62, 1, 1, 255>>,
        <<1, 0, 0, 0>>
      )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 1) == <<255>>
    end

    test "store u8 value truncation 257" do
      state = create_test_state(
        <<62, 2, 1, 0, 0x34, 0x82>>,
        <<1, 0, 0, 0, 0, 0>>
      )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 1) == <<52>>
    end

    test "store u8 imm negative" do
      state = create_test_state(<<62, 2, 1, 0, 255, 255>>, <<1, 0, 0, 0, 0, 0>>)
      output = VM.step(state)

      assert Memory.read(output.memory, 1, 1) == <<255>>
    end
  end

  describe "store_imm_u16 instruction" do
    test "store simple u16 value" do
      state = create_test_state(
        <<
          79,  # StoreImmU16 opcode
          0x01,  # Use 1 byte each for address and value
          0x01,  # Address: 1
          0x05   # Value: 5
        >>,
        <<1, 0, 0, 0>>
      )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 2) == <<5, 0>>
    end

    test "store max u16 value" do
      state = create_test_state(
        <<79, 2, 1, 0, 0xFF, 0xFF>>,
        <<1, 0, 0, 0, 0, 0>>
      )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 2) == <<255, 255>>
    end

    test "store u16 value truncation" do
      state = create_test_state(
        <<79, 2, 1, 0, 0x00, 0x01, 0x00>>,  # Value: 65536
        <<1, 0, 0, 0, 0, 0, 0>>
      )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 2) == <<0, 1>>  # Should truncate to 0
    end
  end

  describe "store_imm_u32 instruction" do
    test "store simple u32 value" do
      state = create_test_state(
        <<
          38,  # StoreImmU32 opcode
          0x01,  # Use 1 byte each for address and value
          0x01,  # Address: 1
          0x05   # Value: 5
        >>,
        <<1, 0, 0, 0>>
      )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 4) == <<5, 0, 0, 0>>
    end

    test "store large u32 value" do
      state = create_test_state(
        <<38, 2, 1, 0, 0xFF, 0xFF, 0xFF, 0xFF>>,  # Value: 4294967295 (max u32)
        <<1, 0, 0, 0, 0, 0, 0, 0>>
      )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 4) == <<255, 255, 255, 255>>
    end
  end

  describe "fallthrough instruction" do
    test "basic fallthrough" do
      state = create_test_state(<<17>>, <<1>>)  # 1 is fallthrough opcode
      output = VM.step(state)

      assert output.exit_status == :continue
      assert output.counter == 1
      assert output.memory == state.memory  # Memory should be unchanged
    end
  end
end
