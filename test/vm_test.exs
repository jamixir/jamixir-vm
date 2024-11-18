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
      # Beyond program length
      state = %{state | counter: 4}
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
      state =
        create_test_state(
          <<
            # StoreImmU8 opcode
            0x3E,
            # Use 1 byte each for address and value
            0x01,
            # Address: 1
            0x01,
            # Value: 5
            0x05
          >>,
          # Each byte is part of this instruction
          <<1, 0, 0, 0>>
        )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 1) == <<5>>
      assert output.counter == 4
    end

    test "store u8 value truncation" do
      state =
        create_test_state(
          <<62, 1, 1, 255>>,
          <<1, 0, 0, 0>>
        )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 1) == <<255>>
    end

    test "store u8 value truncation 257" do
      state =
        create_test_state(
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
      state =
        create_test_state(
          <<
            # StoreImmU16 opcode
            79,
            # Use 1 byte each for address and value
            0x01,
            # Address: 1
            0x01,
            # Value: 5
            0x05
          >>,
          <<1, 0, 0, 0>>
        )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 2) == <<5, 0>>
    end

    test "store max u16 value" do
      state =
        create_test_state(
          <<79, 2, 1, 0, 0xFF, 0xFF>>,
          <<1, 0, 0, 0, 0, 0>>
        )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 2) == <<255, 255>>
    end

    test "store u16 value truncation" do
      state =
        create_test_state(
          # Value: 65536
          <<79, 2, 1, 0, 0x00, 0x01, 0x00>>,
          <<1, 0, 0, 0, 0, 0, 0>>
        )

      output = VM.step(state)

      # Should truncate to 0
      assert Memory.read(output.memory, 1, 2) == <<0, 1>>
    end
  end

  describe "store_imm_u32 instruction" do
    test "store simple u32 value" do
      state =
        create_test_state(
          <<
            # StoreImmU32 opcode
            38,
            # Use 1 byte each for address and value
            0x01,
            # Address: 1
            0x01,
            # Value: 5
            0x05
          >>,
          <<1, 0, 0, 0>>
        )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert Memory.read(output.memory, 1, 4) == <<5, 0, 0, 0>>
    end

    test "store large u32 value" do
      state =
        create_test_state(
          # Value: 4294967295 (max u32)
          <<38, 2, 1, 0, 0xFF, 0xFF, 0xFF, 0xFF>>,
          <<1, 0, 0, 0, 0, 0, 0, 0>>
        )

      output = VM.step(state)

      assert Memory.read(output.memory, 1, 4) == <<255, 255, 255, 255>>
    end
  end

  describe "fallthrough instruction" do
    test "basic fallthrough" do
      # 1 is fallthrough opcode
      state = create_test_state(<<17>>, <<1>>)
      output = VM.step(state)

      assert output.exit_status == :continue
      assert output.counter == 1
      # Memory should be unchanged
      assert output.memory == state.memory
    end
  end

  describe "multi-instruction programs" do
    test "executes sequence of store operations" do
      # Program that stores:
      # - u8(5) at address 1
      # - u16(1000) at address 10
      # - u32(100000) at address 20
      # - fallthrough
      state =
        create_test_state(
          <<
            # store_imm_u8: 5 -> addr 1
            0x3E,
            0x01,
            0x01,
            0x05,
            # store_imm_u16: 1000 -> addr 10
            0x4F,
            0x01,
            0x0A,
            0xE8,
            0x03,
            # store_imm_u32: 100000 -> addr 20
            0x26,
            0x02,
            0x14,
            0x00,
            0xA0,
            0x86,
            0x01,
            0x00,
            # fallthrough
            0x11
          >>,
          # store_imm_u8 mask
          <<
            1,
            0,
            0,
            0,
            # store_imm_u16 mask
            1,
            0,
            0,
            0,
            0,
            # store_imm_u32 mask
            1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            # fallthrough mask
            1
          >>
        )

      output = VM.execute(state)

      assert output.exit_status == :panic
      # Total length of all instructions
      assert output.counter == 18
      assert Memory.read(output.memory, 1, 1) == <<5>>
      # 1000 in little-endian
      assert Memory.read(output.memory, 10, 2) == <<232, 3>>
      # 100000 in little-endian
      assert Memory.read(output.memory, 20, 4) == <<160, 134, 1, 0>>
      assert output.gas == state.gas
    end

    test "executes until trap" do
      # Program that:
      # - stores u8(42) at address 5
      # - stores u16(513) at address 10
      # - trap
      # - stores u32(1000) at address 15 (should never execute)
      state =
        create_test_state(
          <<
            # store_imm_u8: 42 -> addr 5
            0x3E,
            0x01,
            0x05,
            0x2A,
            # store_imm_u16: 513 -> addr 10
            0x4F,
            0x01,
            0x0A,
            0x01,
            0x02,
            # trap
            0x00,
            # store_imm_u32: 1000 -> addr 15 (never reached)
            0x26,
            0x01,
            0x0F,
            0xE8,
            0x03
          >>,
          # store_imm_u8 mask
          <<
            1,
            0,
            0,
            0,
            # store_imm_u16 mask
            1,
            0,
            0,
            0,
            0,
            # trap mask
            1,
            # store_imm_u32 mask (never reached)
            1,
            0,
            0,
            0,
            0
          >>
        )

      output = VM.execute(state)

      assert output.exit_status == :panic
      # Should stop at trap instruction
      assert output.counter == 10
      assert Memory.read(output.memory, 5, 1) == <<42>>
      # 513 in little-endian
      assert Memory.read(output.memory, 10, 2) == <<1, 2>>
      # Should never be written
      assert Memory.read(output.memory, 15, 4) == <<0, 0, 0, 0>>
      assert output.gas == state.gas
    end
  end

  describe "memory fault handling" do
    test "store_imm_u8 fails on read-only memory" do
      state =
        create_test_state(
          <<
            # store_imm_u8: 42 -> addr 5
            0x3E,
            0x01,
            0x05,
            0x2A
          >>,
          <<1, 0, 0, 0>>
        )

      # Make address 5 read-only
      state = %{state | memory: Memory.set_access(state.memory, 5, 1, :read)}

      output = VM.execute(state)

      assert output.exit_status == {:fault, 5}
      # Should complete instruction decode
      assert output.counter == 4
      # Memory should be unchanged
      assert Memory.read(output.memory, 5, 1) == <<0>>
    end

    test "multi-instruction execution stops on memory fault" do
      state =
        create_test_state(
          <<
            # store_imm_u8: 5 -> addr 1
            0x3E,
            0x01,
            0x01,
            0x05,
            # store_imm_u16: 1000 -> addr 10 (should fail)
            0x4F,
            0x01,
            0x0A,
            0xE8,
            0x03,
            # store_imm_u32 (never reached)
            0x26,
            0x02,
            0x14,
            0x00,
            0xA0,
            0x86,
            0x01,
            0x00
          >>,
          <<1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0>>
        )

      # First operation succeeds, second fails
      state = %{state | memory: Memory.set_access(state.memory, 11, 1, :read)}

      output = VM.execute(state)

      assert output.exit_status == {:fault, 11}
      # Should complete second instruction decode
      assert output.counter == 9
      # First write succeeded
      assert Memory.read(output.memory, 1, 1) == <<5>>
      # Second write failed
      assert Memory.read(output.memory, 10, 2) == <<0, 0>>
      # Third never attempted
      assert Memory.read(output.memory, 20, 4) == <<0, 0, 0, 0>>
    end
  end

  describe "ecalli instruction" do
    test "basic ecall with small value" do
      state =
        create_test_state(
          <<
            # ecalli opcode
            78,
            # Use 1 byte for value
            0x01,
            # Value: 5
            0x05
          >>,
          <<1, 0, 0>>
        )

      output = VM.step(state)

      assert output.exit_status == {:ecall, 5}
      # opcode + length byte + value byte
      assert output.counter == 3

      # Memory should be unchanged
      assert output.memory == state.memory
    end

    test "ecall with multi-byte value" do
      state =
        create_test_state(
          <<
            # ecalli opcode
            78,
            # Use 4 bytes for value
            0x04,
            # Value: 0x12345678
            0x78,
            0x56,
            0x34,
            0x12
          >>,
          <<1, 0, 0, 0, 0, 0>>
        )

      output = VM.step(state)

      assert output.exit_status == {:ecall, 0x12345678}
      # opcode + length + 4 value bytes
      assert output.counter == 6
    end

    test "ecall in multi-instruction sequence" do
      state =
        create_test_state(
          <<
            # store_imm_u8: 5 -> addr 1
            0x3E,
            0x01,
            0x01,
            0x05,
            # ecalli: 66
            78,
            0x02,
            0x42,
            0x00,
            # fallthrough (never reached)
            0x11
          >>,
          <<1, 0, 0, 0, 1, 0, 0, 0, 1>>
        )

      output = VM.execute(state)

      assert output.exit_status == {:ecall, 66}
      # Should stop at ecalli
      assert output.counter == 8
      # First instruction executed
      assert Memory.read(output.memory, 1, 1) == <<5>>
    end
  end

  describe "jump instruction" do
    test "basic forward jump" do
      state =
        create_test_state(
          <<
            # jump opcode
            5,
            # offset bytes (will read until next instruction)
            3,
            0,
            # fallthrough instruction (jump target)
            17
          >>,
          # Bitmask: instruction at 0 and 3, so l=2 bytes to read
          <<1, 0, 0, 1>>
        )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert output.counter == 3
    end

    test "backward jump" do
      state =
        create_test_state(
          <<
            # fallthrough
            17,
            # jump opcode
            5,
            # offset to jump back to start (-2 in two's complement)
            255,
            # padding
            0
          >>,
          # Instructions at 0, 1, and 3
          <<1, 1, 0, 1>>
        )

      # Start at jump instruction
      state = %{state | counter: 1}

      output = VM.step(state)

      assert output.exit_status == :continue
      assert output.counter == 0
    end

    test "jump to invalid target panics" do
      state =
        create_test_state(
          <<
            # jump opcode
            5,
            # offset to non-instruction start
            1,
            # fallthrough
            17
          >>,
          # Only positions 0 and 2 are valid starts
          <<1, 0, 1>>
        )

      output = VM.step(state)

      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "multi-byte jump offset" do
      state =
        create_test_state(
          <<5, 4, 0, 0, 17>>,

          # Instructions at 0 and 3
          <<1, 0, 0, 0, 1>>
        )

      output = VM.step(state)

      assert output.exit_status == :continue
      assert output.counter == 4
    end

    test "jump past end of program panics" do
      state =
        create_test_state(
          <<
            # jump opcode
            5,
            # 1 byte immediate
            5,
            # jump past end of program
            10
          >>,
          <<1, 0, 1>>
        )

      output = VM.step(state)

      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "jump in instruction sequence" do
      # Program laid out instruction by instruction:
      program = <<
        # Instruction 1: store_imm_u8 (addr=1, value=5)
        0x3E, 1, 1, 5,    # pos 0-3

        # Instruction 2: jump +8 (to reach pos 12)
        5, 8,             # pos 4-5

        # Instruction 3: trap (should be skipped)
        0,                # pos 6

        # Instruction 4: store_imm_u8 (addr=3, value=10)
        0x3E, 1, 3, 10,   # pos 7-10

        # Instruction 5: fallthrough
        17,            # pos 11
        # Instruction 6: store_imm_u8 (addr=2, value=7)
        0x3E, 1, 2, 7    # pos 12-15
      >>

      # Bitmask marking start of each instruction:
      bitmask = <<
        1, 0, 0, 0,    # store_imm_u8
        1, 0,          # jump
        1,             # trap
        1, 0, 0, 0,    # store_imm_u8
        1,              # fallthrough
        1, 0, 0, 0,    # store_imm_u8

      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic # an out-of-bounds
      assert output.counter == 16
      assert Memory.read(output.memory, 1, 1) == <<5>>
      assert Memory.read(output.memory, 2, 1) == <<7>>
      assert Memory.read(output.memory, 3, 1) == <<0>>  # skipped
    end
  end
end
