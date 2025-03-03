defmodule Instructions.TwoRegistersTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoRegisters, Memory, Registers, State}
  import PVM.Memory.Constants

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
    test "allocates memory when no writable pages exist" do
      memory =
        %Memory{}
        # No access by default
        |> Memory.set_default_access(nil)

      # Request 2 pages worth of bytes
      request_size = 2 * page_size()

      state = %State{
        memory: memory,
        registers: %Registers{r2: request_size}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at beginning
      assert new_state.registers.r1 == min_allowed_address()
      # Verify pages 0 and 1 are now writable
      assert Memory.check_pages_access?(new_state.memory, 16, 2, :write)
    end

    test "allocates memory after first writable block" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Pages 16-17 are writable
        |> Memory.set_access(16 * page_size(), 2 * page_size(), :write)

      state = %State{
        memory: memory,
        # Request 1 page worth of bytes
        registers: %Registers{r2: page_size()}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at beginning
      assert new_state.registers.r1 == 18 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 18, 1, :write)
    end

    test "allocates memory in gap between writable blocks" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Pages 16-17 writable
        |> Memory.set_access_by_page(16, 2, :write)
        # Pages 20-21 writable
        |> Memory.set_access_by_page(20, 2, :write)

      state = %State{
        memory: memory,
        # Request 2 pages worth of bytes
        registers: %Registers{r2: 2 * page_size()}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 18
      assert new_state.registers.r1 == 18 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 16, 4, :write)
    end

    test "handles case when readable pages block allocation" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Page 16 writable
        |> Memory.set_access_by_page(16, 1, :write)
        # Page 17 readable
        |> Memory.set_access_by_page(17, 1, :read)
        # Page 19 writable
        |> Memory.set_access_by_page(19, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages worth of bytes
        registers: %Registers{r2: 2 * page_size()}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 20
      assert new_state.registers.r1 == 20 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 19, 3, :write)
    end

    test "handles request spanning multiple pages" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Pages 18-19 readable
        |> Memory.set_access_by_page(18, 2, :read)

      # Request spans 3 pages
      request_size = 2 * page_size() + 1

      state = %State{
        memory: memory,
        registers: %Registers{r2: request_size}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      assert new_state.registers.r1 == 20 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 20, 3, :write)
    end

    test "chooses first gap when multiple gaps exist" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Three writable blocks with gaps
        # Page 0
        |> Memory.set_access_by_page(16, 1, :write)
        # Page 3
        |> Memory.set_access_by_page(19, 1, :write)
        # Page 6
        |> Memory.set_access_by_page(22, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages worth of bytes
        registers: %Registers{r2: 2 * page_size()}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use first gap (pages 17-18)
      assert new_state.registers.r1 == 17 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 17, 2, :write)

      state = %State{
        memory: memory,
        # Request 3 pages worth of bytes
        registers: %Registers{r2: 3 * page_size()}
      }

      # Request 3 pages worth of bytes
      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      assert new_state.registers.r1 == 23 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 22, 4, :write)
    end

    test "complex mix of readable and writable forces specific gap choice" do
      memory =
        %Memory{}
        |> Memory.set_default_access(nil)
        # Complex pattern: W=writable, R=readable, -=none
        # W R - R W - - W (pages 0-7)
        # Page 0
        |> Memory.set_access_by_page(16, 1, :write)
        # Page 1
        |> Memory.set_access_by_page(17, 1, :read)
        # Page 3
        |> Memory.set_access_by_page(19, 1, :read)
        # Page 4
        |> Memory.set_access_by_page(20, 1, :write)
        # Page 7
        |> Memory.set_access_by_page(23, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages worth of bytes
        registers: %Registers{r2: 2 * page_size()}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use pages 21-22
      assert new_state.registers.r1 == 21 * page_size()
      assert Memory.check_pages_access?(new_state.memory, 20, 4, :write)
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
