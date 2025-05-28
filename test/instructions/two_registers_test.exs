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
    test "returns current heap pointer when size is 0", %{state: state} do
      # Set up registers: r1 = destination, r2 = size (0)
      state = %{state | registers: %{state.registers | r2: 0}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return current heap pointer
      assert new_state.registers.r1 == state.memory.current_heap_pointer
      # Heap pointer should not change
      assert new_state.memory.current_heap_pointer == state.memory.current_heap_pointer
    end

    test "allocates memory successfully within heap bounds", %{state: state} do
      # Request 100 bytes
      request_size = 100
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: request_size}}
      # asset memory is not writable
      assert Memory.check_pages_access?(state.memory, initial_heap_pointer, request_size, :write) == false

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return old heap pointer
      assert new_state.registers.r1 == initial_heap_pointer
      # Heap pointer should advance by request size
      assert new_state.memory.current_heap_pointer == initial_heap_pointer + request_size
      # Memory should be writable at the allocated address
      assert {:ok, _} = Memory.write(new_state.memory, initial_heap_pointer, <<1, 2, 3, 4>>)
    end

    test "allocates exactly one page size", %{state: state} do
      # Request exactly one page worth of bytes
      request_size = page_size()
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: request_size}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return old heap pointer
      assert new_state.registers.r1 == initial_heap_pointer
      # Heap pointer should advance by page size
      assert new_state.memory.current_heap_pointer == initial_heap_pointer + page_size()
      # Should be able to write to the entire allocated page
      data = :binary.copy(<<0xFF>>, page_size())
      assert {:ok, _} = Memory.write(new_state.memory, initial_heap_pointer, data)
    end

    test "allocates multiple pages", %{state: state} do
      # Request 3 pages worth of bytes
      request_size = 3 * page_size()
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: request_size}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return old heap pointer
      assert new_state.registers.r1 == initial_heap_pointer
      # Heap pointer should advance by request size
      assert new_state.memory.current_heap_pointer == initial_heap_pointer + request_size
      # Should be able to write across page boundaries
      data = :binary.copy(<<0xAB>>, request_size)
      assert {:ok, _} = Memory.write(new_state.memory, initial_heap_pointer, data)
    end

    test "allocates up to the maximum heap boundary", %{state: state} do
      # Calculate how much space is left in the heap
      available_space = state.memory.max_heap_pointer - state.memory.current_heap_pointer
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: available_space}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return old heap pointer
      assert new_state.registers.r1 == initial_heap_pointer
      # Heap pointer should reach the maximum
      assert new_state.memory.current_heap_pointer == state.memory.max_heap_pointer
      assert Memory.check_pages_access?(new_state.memory, initial_heap_pointer, available_space, :write) == true
    end

    test "fails when requesting 1 byte over the heap limit", %{state: state} do
      # Calculate how much space is left in the heap, then request 1 more byte
      available_space = state.memory.max_heap_pointer - state.memory.current_heap_pointer
      request_size = available_space + 1
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: request_size}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return 0 (allocation failed)
      assert new_state.registers.r1 == 0
      # Heap pointer should not change
      assert new_state.memory.current_heap_pointer == initial_heap_pointer
      assert Memory.check_pages_access?(new_state.memory, initial_heap_pointer, available_space, :write) == false
    end

    test "fails when requesting way more than available heap space", %{state: state} do
      # Request much more than available (more than the entire heap size)
      available_space = state.memory.max_heap_pointer - state.memory.current_heap_pointer
      huge_request = available_space + 1_000_000_000
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: huge_request}}

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should return 0 (allocation failed)
      assert new_state.registers.r1 == 0
      # Heap pointer should not change
      assert new_state.memory.current_heap_pointer == initial_heap_pointer
      assert Memory.check_pages_access?(new_state.memory, initial_heap_pointer, available_space, :write) == false
    end

    test "multiple allocations work correctly", %{state: state} do
      # First allocation
      first_request = 50
      initial_heap_pointer = state.memory.current_heap_pointer

      state = %{state | registers: %{state.registers | r2: first_request}}
      {status, state1} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      assert state1.registers.r1 == initial_heap_pointer
      assert state1.memory.current_heap_pointer == initial_heap_pointer + first_request
      assert Memory.check_range_access?(state1.memory, initial_heap_pointer, first_request, :write) == true

      # Second allocation
      second_request = 75 + page_size()
      state1 = %{state1 | registers: %{state1.registers | r2: second_request}}
      {status, state2} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state1)

      assert status == :continue
      assert state2.registers.r1 == initial_heap_pointer + first_request
      assert state2.memory.current_heap_pointer == initial_heap_pointer + first_request + second_request

      assert Memory.check_range_access?(state2.memory, initial_heap_pointer, first_request + second_request, :write) == true
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
      assert new_state.registers.r1 == 60
    end

    test "handles no leading zeros" do
      program = <<op(:leading_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 1}}

      {status, new_state} = TwoRegisters.execute(:leading_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 63
    end
  end

  describe "leading_zero_bits_32" do
    test "counts leading zeros" do
      program = <<op(:leading_zero_bits_32), 0x21>>
      state = %State{registers: %Registers{r2: 10}}

      {status, new_state} = TwoRegisters.execute(:leading_zero_bits_32, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 28
    end
  end

  describe "trailing_zero_bits_64" do
    test "counts trailing zeros" do
      program = <<op(:trailing_zero_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 5}}

      {status, new_state} = TwoRegisters.execute(:trailing_zero_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
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
      assert new_state.registers.r1 == 0
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
