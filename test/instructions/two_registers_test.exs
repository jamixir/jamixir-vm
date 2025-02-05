defmodule Instructions.TwoRegistersTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoRegisters, Memory, Registers, State}

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

  describe "count_writable_blocks" do
    test "empty list returns 0" do
      assert TwoRegisters.count_writable_blocks([]) == 0
    end

    test "single page returns 1" do
      assert TwoRegisters.count_writable_blocks([5]) == 1
    end

    test "contiguous pages count as one block" do
      assert TwoRegisters.count_writable_blocks([1, 2, 3, 4]) == 1
    end

    test "non-contiguous pages count as separate blocks" do
      assert TwoRegisters.count_writable_blocks([1, 2, 4, 5, 7]) == 3
    end

    test "single pages count as separate blocks" do
      assert TwoRegisters.count_writable_blocks([1, 3, 5, 7]) == 4
    end

    test "mixed contiguous and non-contiguous" do
      assert TwoRegisters.count_writable_blocks([1, 2, 3, 5, 6, 8]) == 3
    end
  end

  describe "find_first_gap_in_writable" do
    test "finds gap between two blocks" do
      pages = [1, 2, 5, 6]
      {start, end_} = TwoRegisters.find_first_gap_in_writable(pages)
      assert start == 3
      assert end_ == 4
    end

    test "finds gap after contiguous block" do
      pages = [0, 1, 2, 5]
      {start, end_} = TwoRegisters.find_first_gap_in_writable(pages)
      assert start == 3
      assert end_ == 4
    end

    test "finds gap with single pages" do
      pages = [1, 3, 5]
      {start, end_} = TwoRegisters.find_first_gap_in_writable(pages)
      assert start == 2
      assert end_ == 2
    end

    test "handles pages starting at 0" do
      pages = [0, 1, 3, 4]
      {start, end_} = TwoRegisters.find_first_gap_in_writable(pages)
      assert start == 2
      assert end_ == 2
    end
  end

  describe "find_non_readable_sequence" do
    test "finds first gap when starting at 0" do
      # Pages:     [0,1,2,3,4,5,6]
      # Readable:   _,R R,_,_,R R,
      # Result:    X           (start at 0, need 1 page)
      readable_pages = [1, 2, 5, 6]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 0, 6, 1) == 0
    end

    test "finds second gap when starting at 1" do
      # Pages:     [0,1,2,3,4,5,6]
      # Readable:   _,R R,_,_,R R,
      # Result:    X           (start at 0, need 1 page)
      readable_pages = [1, 2, 5, 6]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 1, 6, 1) == 3
    end

    test "finds second gap when 2 pages are needed" do
      # Pages:     [0,1,2,3,4,5,6]
      # Readable:   _,R R,_,_,R R,
      # Result:    X           (start at 0, need 1 page)
      readable_pages = [1, 2, 5, 6]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 0, 6, 2) == 3
    end

    test "finds gap after readable pages" do
      # Pages:     [0,1,2,3,4,5,6]
      # Readable:   _,R R,R,R,_ _,
      # Result:    X           (start at 0, need 1 page)
      readable_pages = [1, 2, 3, 4]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 0, 6, 2) == 5
    end

    test "returns nil when no gap big enough exists" do
      # Pages:     [0,1,2,3,4,5,6]
      # Readable:   _,R R,R,R,_,R,
      # Result:    X           (start at 0, need 1 page)
      readable_pages = [1, 2, 3, 4, 5]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 0, 6, 2) == nil
    end

    test "handles empty readable list" do
      # Pages:     [0,1,2]
      # Readable:  (none)
      # Start:     ^
      # Result:    X           (start at 0)
      assert TwoRegisters.find_non_readable_sequence([], 0, 2, 1) == 0
    end

    test "respects end page limit" do
      # Pages:     [0,1,2,3,4]
      # Readable:  R R   R
      # Start:         ^
      # End:            ^
      # Need:     2 pages (won't fit before end)
      readable_pages = [0, 1, 3]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 2, 4, 2) == nil
    end

    test "handles start point beyond readable pages" do
      # Pages:     [0,1,2,3,4]
      # Readable:  R R R
      # Start:           ^
      # Result:          X     (start at 3)
      readable_pages = [0, 1, 2]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 3, 4, 1) == 3
    end

    test "returns nil when gap exists but not after start point" do
      # Pages:     [0,1,2,3,4]
      # Readable:    R R R R
      # Start:           ^
      # Need:     2 pages (gap exists at start but not after start point)
      readable_pages = [1, 2, 3, 4]
      assert TwoRegisters.find_non_readable_sequence(readable_pages, 2, 4, 2) == nil
    end
  end

  describe "execute(:sbrk)" do
    test "allocates memory when no writable pages exist" do
      memory =
        %Memory{}
        # 16 bytes per page
        |> Memory.set_page_size(16)
        # No access by default
        |> Memory.set_default_access(nil)

      state = %State{
        memory: memory,
        # Request 32 bytes (2 pages)
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at beginning
      assert new_state.registers.r1 == 0
      # Verify pages 0 and 1 are now writable
      assert Memory.check_pages_access?(new_state.memory, 0, 2, :write)
    end

    test "allocates memory before first writable block" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Pages 3-4 are writable
        |> Memory.set_access(48, 32, :write)

      state = %State{
        memory: memory,
        # Request 1 page
        registers: %Registers{r2: 16}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at beginning
      assert new_state.registers.r1 == 0
      assert Memory.check_pages_access?(new_state.memory, 0, 1, :write)
    end

    test "allocates memory in gap between writable blocks" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Pages 0-1 writable
        |> Memory.set_access_by_page(0, 2, :write)
        # Pages 5-6 writable
        |> Memory.set_access_by_page(5, 2, :write)

      state = %State{
        memory: memory,
        # Request 2 pages
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 2
      assert new_state.registers.r1 == 32
      assert Memory.check_pages_access?(new_state.memory, 2, 2, :write)
    end

    test "handles case when readable pages block allocation" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Page 0 writable
        |> Memory.set_access_by_page(0, 1, :write)
        # Page 1 readable
        |> Memory.set_access_by_page(1, 1, :read)
        # Page 3 writable
        |> Memory.set_access_by_page(3, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should start at page 4
      assert new_state.registers.r1 == 64
      assert Memory.check_pages_access?(new_state.memory, 4, 2, :write)
    end

    test "handles request spanning multiple pages" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Pages 3-4 writable
        |> Memory.set_access_by_page(3, 2, :write)

      state = %State{
        memory: memory,
        # Request spans 3 pages (40 bytes)
        registers: %Registers{r2: 40}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      assert new_state.registers.r1 == 0
      assert Memory.check_pages_access?(new_state.memory, 0, 3, :write)
    end

    test "chooses first gap when multiple gaps exist" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Three writable blocks with gaps
        # Page 0
        |> Memory.set_access_by_page(0, 1, :write)
        # Page 3
        |> Memory.set_access_by_page(3, 1, :write)
        # Page 6
        |> Memory.set_access_by_page(6, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use first gap (pages 1-2)
      assert new_state.registers.r1 == 16
      assert Memory.check_pages_access?(new_state.memory, 1, 2, :write)
    end

    test "readable pages force allocation to later gap" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Page 0
        |> Memory.set_access_by_page(0, 1, :write)
        # Page 1 (blocks first gap)
        |> Memory.set_access_by_page(1, 1, :read)
        # Page 3
        |> Memory.set_access_by_page(3, 1, :write)
        # Page 6
        |> Memory.set_access_by_page(6, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use gap at pages 4-5
      assert new_state.registers.r1 == 64
      assert Memory.check_pages_access?(new_state.memory, 4, 2, :write)
    end

    test "readable pages in middle of gap prevent its use" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Page 0
        |> Memory.set_access_by_page(0, 1, :write)
        # Page 2 (splits 4-page gap)
        |> Memory.set_access_by_page(2, 1, :read)
        # Page 5
        |> Memory.set_access_by_page(5, 1, :write)

      state = %State{
        memory: memory,
        # Request 3 pages
        registers: %Registers{r2: 48}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use pages 6,7 after readable page
      assert new_state.registers.r1 == 6 * 16
      assert Memory.check_pages_access?(new_state.memory, 6, 2, :write)
    end

    test "complex mix of readable and writable forces specific gap choice" do
      memory =
        %Memory{}
        |> Memory.set_page_size(16)
        |> Memory.set_default_access(nil)
        # Complex pattern: W=writable, R=readable, -=none
        # W R - R W - - W (pages 0-7)
        # Page 0
        |> Memory.set_access_by_page(0, 1, :write)
        # Page 1
        |> Memory.set_access_by_page(1, 1, :read)
        # Page 3
        |> Memory.set_access_by_page(3, 1, :read)
        # Page 4
        |> Memory.set_access_by_page(4, 1, :write)
        # Page 7
        |> Memory.set_access_by_page(7, 1, :write)

      state = %State{
        memory: memory,
        # Request 2 pages
        registers: %Registers{r2: 32}
      }

      {status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      assert status == :continue
      # Should use pages 5-6
      assert new_state.registers.r1 == 80
      assert Memory.check_pages_access?(new_state.memory, 5, 2, :write)
    end

    test "original memory is not modified" do
      memory = %Memory{}
               |> Memory.set_page_size(16)
               |> Memory.set_size(7 * 16)
               # Set all pages to readable
               |> Memory.set_access_by_page(0, 7, :read)
               # Make 2 pages nil access
               |> Memory.set_access_by_page(2, 1, nil)
               |> Memory.set_access_by_page(5, 2, nil)

      state = %State{
        memory: memory,
        # Request 3 pages
        registers: %Registers{r2: 48}
      }

      # Execute sbrk
      {_status, new_state} = TwoRegisters.execute(:sbrk, <<op(:sbrk), 0x21>>, state)

      # Original memory should be unchanged
      assert new_state.memory.access == memory.access
    end
  end

  describe "count_set_bits_64" do
    test "counts all bits in a 64-bit number" do
      program = <<op(:count_set_bits_64), 0x21>>
      state = %State{registers: %Registers{r2: 0x0000_FFFF_0000_FFFF}}

      {status, new_state} = TwoRegisters.execute(:count_set_bits_64, program, state)

      assert status == :continue
      assert new_state.registers.r1 == 32  # Half the bits are 1s
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
end
