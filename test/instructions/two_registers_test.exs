defmodule Instructions.TwoRegistersTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoRegisters, Memory, Registers, State, InitProgram}
  import PVM.Memory.Constants

  setup_all do
    memory = InitProgram.construct_memory("code", "data", "args", 1, 1)
    stack_addr = InitProgram.boundaries(4, 4, 4, 1, 1).stack_start
    state = %State{memory: memory, registers: %Registers{r2: stack_addr}}
    {:ok, %{memory: memory, stack_addr: stack_addr, state: state}}
  end

  describe "move_reg" do
    test "copies value from one register to another" do
      program = <<op(:move_reg), 0x21>>
      state = %State{registers: %Registers{r2: 42}}

      {exit_status, state} = TwoRegisters.execute(:move_reg, program, state)

      assert exit_status == :continue
      assert state.registers.r1 == 42
    end

    test "handles register index greater than 12" do
      # Register 15 should be capped to 12
      program = <<op(:move_reg), 0x1F>>
      state = %State{registers: %Registers{r1: 42}}

      {exit_status, state} = TwoRegisters.execute(:move_reg, program, state)

      assert exit_status == :continue
      assert state.registers.r12 == 42
    end
  end

  describe "execute(:sbrk)" do
    test "allocates memory after program text region", %{state: state} do
      # Request 2 pages worth of bytes
      request_size = 2 * page_size()

      state = %{state | registers: %{state.registers | r2: request_size}}
      refute Memory.check_pages_access?(state.memory, 17, 2, :read)
      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # page 17
      assert new_state.registers.r1 == 0x11000
      # Verify pages 17, 18 are now writable
      assert Memory.check_pages_access?(new_state.memory, 17, 2, :write)
    end

    test "allocates 10 pages in the first available gap", %{state: state} do
      # Request 10 pages worth of bytes
      request_size = 10 * page_size()

      state = %{state | registers: %{state.registers | r2: request_size}}

      refute Memory.check_pages_access?(state.memory, 17, 10, :read)
      # Initial memory access ranges:
      # [{16, 17, :read}, {17, 48, nil}, {48, 50, :write}, ...]

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 17
      assert new_state.registers.r1 == 17 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 17, 10, :write)

      # Verify the next range is still nil (pages 27-47)
      assert Enum.at(new_state.memory.access_ranges, 1) == {17, 27, :write}
      assert Enum.at(new_state.memory.access_ranges, 2) == {27, 48, nil}
    end

    test "allocates 30 pages and merges with next writable block", %{state: state} do
      # Request 30 pages worth of bytes
      request_size = 31 * page_size()

      state = %{state | registers: %{state.registers | r2: request_size}}

      # Initial memory access ranges:
      # [{16, 17, :read}, {17, 48, nil}, {48, 50, :write}, ...]

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 17
      assert new_state.registers.r1 == 17 * page_size()
      assert Enum.at(new_state.memory.access_ranges, 1) == {17, 50, :write}
      assert length(new_state.memory.access_ranges) == length(state.memory.access_ranges) - 1
    end

    test "allocates large number of pages at expense of next nil block", %{state: state} do
      request_size = 1000 * page_size()

      state = %{state | registers: %{state.registers | r2: request_size}}
      # Initial memory access ranges:
      # [{16, 17, :read}, {17, 48, nil}, {48, 50, :write}, ...]

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 50 (after the writable block at 48-49)
      assert new_state.registers.r1 == 50 * page_size()
      # Verify pages 50-1049 are now writable
      assert Memory.check_pages_access?(new_state.memory, 50, 1000, :write)

      assert Enum.take(new_state.memory.access_ranges, 3) == [
               {16, 17, :read},
               {17, 48, nil},
               {48, 1050, :write}
             ]
    end
  end

  describe "count_set_bits_64" do
    test "counts all bits in a 64-bit number" do
      program = <<op(:count_set_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 0x0000_FFFF_0000_FFFF}}

      {status, new_state} = TwoRegisters.execute(:count_set_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 32
    end

    test "handles zero" do
      program = <<op(:count_set_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 0}}

      {status, new_state} = TwoRegisters.execute(:count_set_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
    end
  end

  describe "count_set_bits_32" do
    test "counts set bits in a 32-bit number" do
      program = <<op(:count_set_bits_32), 0x21>>
      state = %State{registers: %Registers{r2: 0x0000_FFFF}}

      {status, new_state} = TwoRegisters.execute(:count_set_bits_32, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 16
    end
  end

  describe "leading_zero_bits_64" do
    test "counts leading zeros" do
      program = <<op(:leading_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 10}}

      {status, new_state} = TwoRegisters.execute(:leading_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 1
    end

    test "handles no leading zeros" do
      program = <<op(:leading_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 1}}

      {status, new_state} = TwoRegisters.execute(:leading_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
    end
  end

  describe "leading_zero_bits_32" do
    test "counts leading zeros" do
      program = <<op(:leading_zero_bits_32), 0x21>>
      state = %State{registers: %Registers{r2: 10}}

      {status, new_state} = TwoRegisters.execute(:leading_zero_bits_32, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 1
    end
  end

  describe "trailing_zero_bits_64" do
    test "counts trailing zeros" do
      program = <<op(:trailing_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 5}}

      {status, new_state} = TwoRegisters.execute(:trailing_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 64 - 3
    end

    test "handles no trailing zeros" do
      program = <<op(:trailing_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 0xF000_0000_0000_0001}}

      {status, new_state} = TwoRegisters.execute(:trailing_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
    end
  end

  describe "trailing_zero_bits_32" do
    test "counts trailing zeros" do
      program = <<op(:trailing_zero_bits_32), 0x21>>
      state = %State{registers: %Registers{r2: 5}}

      {status, new_state} = TwoRegisters.execute(:trailing_zero_bits_32, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 32 - 3
    end
  end

  describe "sign_extend_8" do
    test "extends positive number" do
      program = <<op(:sign_extend_8), 0x21>>
      state = %State{registers: %Registers{r2: 0x007F}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_8, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_007F
    end

    test "extends negative number" do
      program = <<op(:sign_extend_8), 0x21>>
      state = %State{registers: %Registers{r2: 0x0082}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_8, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0xFFFF_FFFF_FFFF_FF82
    end

    test "handles larger input values" do
      program = <<op(:sign_extend_8), 0x21>>
      # Value larger than 16 bits should be truncated first
      state = %State{registers: %Registers{r2: 0x202}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_8, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_0002
    end
  end

  describe "sign_extend_16" do
    test "extends positive number" do
      program = <<op(:sign_extend_16), 0x21>>
      state = %State{registers: %Registers{r2: 0x0000_007F}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_16, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_007F
    end

    test "extends negative number" do
      program = <<op(:sign_extend_16), 0x21>>
      state = %State{registers: %Registers{r2: 0x8002}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_16, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0xFFFF_FFFF_FFFF_8002
    end

    test "handles larger input values" do
      program = <<op(:sign_extend_16), 0x21>>
      # Value larger than 16 bits should be truncated first
      state = %State{registers: %Registers{r2: 0x4003A}}

      {status, new_state} = TwoRegisters.execute(:sign_extend_16, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_0000_0000_003A
    end
  end

  describe "zero_extend_16" do
    test "extends overflowed number (rem)" do
      program = <<op(:zero_extend_16), 0x21>>
      state = %State{registers: %Registers{r2: 0x200EA}}

      {status, new_state} = TwoRegisters.execute(:zero_extend_16, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_00EA
    end

    test "extends to 16-bit number" do
      program = <<op(:zero_extend_16), 0x21>>
      state = %State{registers: %Registers{r2: 0x00F1}}

      {status, new_state} = TwoRegisters.execute(:zero_extend_16, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x0000_00F1
    end
  end

  describe "reverse_bytes" do
    test "reverses bytes in 64-bit value" do
      program = <<op(:reverse_bytes), 0x21>>
      state = %State{registers: %Registers{r2: 0x12A3_1234_5678_90AB}}

      {status, new_state} = TwoRegisters.execute(:reverse_bytes, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0xAB90_7856_3412_A312
    end

    test "handles symmetrical value" do
      program = <<op(:reverse_bytes), 0x21>>
      state = %State{registers: %Registers{r2: 0x1122_3344_4433_2211}}

      {status, new_state} = TwoRegisters.execute(:reverse_bytes, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0x1122_3344_4433_2211
    end

    test "handles zero" do
      program = <<op(:reverse_bytes), 0x21>>
      state = %State{registers: %Registers{r2: 0}}

      {status, new_state} = TwoRegisters.execute(:reverse_bytes, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
    end
  end
end
