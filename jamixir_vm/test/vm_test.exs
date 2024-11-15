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

      assert output.exit_status == :panic
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

  describe "multi-instruction programs" do
    test "executes sequence of store operations" do
      # Program that stores:
      # - u8(5) at address 1
      # - u16(1000) at address 10
      # - u32(100000) at address 20
      # - fallthrough
      state = create_test_state(
        <<
          0x3E, 0x01, 0x01, 0x05,           # store_imm_u8: 5 -> addr 1
          0x4F, 0x01, 0x0A, 0xE8, 0x03,     # store_imm_u16: 1000 -> addr 10
          0x26, 0x02, 0x14, 0x00, 0xA0, 0x86, 0x01, 0x00,  # store_imm_u32: 100000 -> addr 20
          0x11                               # fallthrough
        >>,
        <<1, 0, 0, 0,                       # store_imm_u8 mask
          1, 0, 0, 0, 0,                    # store_imm_u16 mask
          1, 0, 0, 0, 0, 0, 0, 0,          # store_imm_u32 mask
          1>>                               # fallthrough mask
      )

      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 18  # Total length of all instructions
      assert Memory.read(output.memory, 1, 1) == <<5>>
      assert Memory.read(output.memory, 10, 2) == <<232, 3>>  # 1000 in little-endian
      assert Memory.read(output.memory, 20, 4) == <<160, 134, 1, 0>>  # 100000 in little-endian
      assert output.gas == state.gas
    end

    test "executes until trap" do
      # Program that:
      # - stores u8(42) at address 5
      # - stores u16(513) at address 10
      # - trap
      # - stores u32(1000) at address 15 (should never execute)
      state = create_test_state(
        <<
          0x3E, 0x01, 0x05, 0x2A,           # store_imm_u8: 42 -> addr 5
          0x4F, 0x01, 0x0A, 0x01, 0x02,     # store_imm_u16: 513 -> addr 10
          0x00,                              # trap
          0x26, 0x01, 0x0F, 0xE8, 0x03      # store_imm_u32: 1000 -> addr 15 (never reached)
        >>,
        <<1, 0, 0, 0,                       # store_imm_u8 mask
          1, 0, 0, 0, 0,                    # store_imm_u16 mask
          1,                                # trap mask
          1, 0, 0, 0, 0>>                   # store_imm_u32 mask (never reached)
      )

      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 10  # Should stop at trap instruction
      assert Memory.read(output.memory, 5, 1) == <<42>>
      assert Memory.read(output.memory, 10, 2) == <<1, 2>>  # 513 in little-endian
      assert Memory.read(output.memory, 15, 4) == <<0, 0, 0, 0>>  # Should never be written
      assert output.gas == state.gas
    end
  end

  describe "memory fault handling" do
    test "store_imm_u8 fails on read-only memory" do
      state = create_test_state(
        <<
          0x3E, 0x01, 0x05, 0x2A  # store_imm_u8: 42 -> addr 5
        >>,
        <<1, 0, 0, 0>>
      )
      # Make address 5 read-only
      state = %{state | memory: Memory.set_access(state.memory, 5, 1, :read)}

      output = VM.execute(state)

      assert output.exit_status == {:fault, 5}
      assert output.counter == 4  # Should complete instruction decode
      assert Memory.read(output.memory, 5, 1) == <<0>>  # Memory should be unchanged
    end



    test "multi-instruction execution stops on memory fault" do
      state = create_test_state(
        <<
          0x3E, 0x01, 0x01, 0x05,           # store_imm_u8: 5 -> addr 1
          0x4F, 0x01, 0x0A, 0xE8, 0x03,     # store_imm_u16: 1000 -> addr 10 (should fail)
          0x26, 0x02, 0x14, 0x00, 0xA0, 0x86, 0x01, 0x00  # store_imm_u32 (never reached)
        >>,
        <<1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0>>
      )
      # First operation succeeds, second fails
      state = %{state | memory: Memory.set_access(state.memory, 11, 1, :read)}

      output = VM.execute(state)

      assert output.exit_status == {:fault, 11}
      assert output.counter == 9  # Should complete second instruction decode
      assert Memory.read(output.memory, 1, 1) == <<5>>  # First write succeeded
      assert Memory.read(output.memory, 10, 2) == <<0, 0>>  # Second write failed
      assert Memory.read(output.memory, 20, 4) == <<0, 0, 0, 0>>  # Third never attempted
    end
  end

  describe "ecalli instruction" do
    test "basic ecall with small value" do
      state = create_test_state(
        <<
          78,    # ecalli opcode
          0x01,  # Use 1 byte for value
          0x05   # Value: 5
        >>,
        <<1, 0, 0>>
      )

      output = VM.step(state)

      assert output.exit_status == {:ecall, 5}
      assert output.counter == 3  # opcode + length byte + value byte

      assert output.memory == state.memory  # Memory should be unchanged
    end


    test "ecall with multi-byte value" do
      state = create_test_state(
        <<
          78,    # ecalli opcode
          0x04,  # Use 4 bytes for value
          0x78, 0x56, 0x34, 0x12  # Value: 0x12345678
        >>,
        <<1, 0, 0, 0, 0, 0>>
      )

      output = VM.step(state)

      assert output.exit_status == {:ecall, 0x12345678}
      assert output.counter == 6  # opcode + length + 4 value bytes

    end

    test "ecall in multi-instruction sequence" do
      state = create_test_state(
        <<
          0x3E, 0x01, 0x01, 0x05,  # store_imm_u8: 5 -> addr 1
          78, 0x02, 0x42, 0x00,    # ecalli: 66
          0x11                      # fallthrough (never reached)
        >>,
        <<1, 0, 0, 0, 1, 0, 0, 0, 1>>
      )

      output = VM.execute(state)

      assert output.exit_status == {:ecall, 66}
      assert output.counter == 8  # Should stop at ecalli
      assert Memory.read(output.memory, 1, 1) == <<5>>  # First instruction executed
    end
  end
end
