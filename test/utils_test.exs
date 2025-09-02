defmodule UtilsTest do
  use ExUnit.Case
  import PVM.Utils

  describe "skip/2" do
    test "basic patterns" do
      # Single instruction (1 byte)
      assert skip(0, <<192>>) == 0

      # Two 1-byte instructions
      assert skip(0, <<144>>) == 2

      # One 2-byte instruction
      assert skip(0, <<128>>) == 7
    end

    test "complex instructions" do
      bitmask = <<148>>
      # [3-byte inst][1-byte inst][2-byte inst]
      # First instruction is 3 bytes
      assert skip(0, bitmask) == 2
      # Second instruction is 1 byte
      assert skip(3, bitmask) == 1
      # Third instruction is 2 bytes
      assert skip(5, bitmask) == 2
    end

    test "boundary conditions" do
      # At end of bitmask
      assert skip(7, <<128>>) == 0

      # Beyond bitmask length
      assert skip(8, <<128>>) == 0

      # Empty bitmask
      assert skip(0, <<>>) == 0
    end

    test "max length" do
      # Long sequence of zeros (should cap at 24)
      long_bitmask = :binary.list_to_bin(List.duplicate(0, 32))
      assert skip(0, long_bitmask) == 24
    end
  end

  describe "extend_to_64bit/2" do
    test "1-byte values (n=1)" do
      # Positive numbers (MSB = 0)
      # 0b0100_0000
      assert extend_to_64bit(0x40, 1) == 0x40
      # 0b0111_1111 (largest positive)
      assert extend_to_64bit(0x7F, 1) == 0x7F

      # Negative numbers (MSB = 1)
      # 0b1000_0000 (smallest negative)
      assert extend_to_64bit(0x80, 1) == 0xFFFF_FFFF_FFFF_FF80
      # 0b1100_0000
      assert extend_to_64bit(0xC0, 1) == 0xFFFF_FFFF_FFFF_FFC0
    end

    test "2-byte values (n=2)" do
      # Positive numbers (MSB = 0)
      # 0b0100_0000_0000_0000
      assert extend_to_64bit(0x4000, 2) == 0x4000
      # 0b0111_1111_1111_1111 (largest positive)
      assert extend_to_64bit(0x7FFF, 2) == 0x7FFF

      # Negative numbers (MSB = 1)
      # 0b1000_0000_0000_0000 (smallest negative)
      assert extend_to_64bit(0x8000, 2) == 0xFFFF_FFFF_FFFF_8000
      # 0b1100_0000_0000_0000
      assert extend_to_64bit(0xC000, 2) == 0xFFFF_FFFF_FFFF_C000
    end

    test "edge cases" do
      # n=0 case
      assert extend_to_64bit(0x2A, 0) == 0x2A
      # zero
      assert extend_to_64bit(0x00, 1) == 0x00
      # zero
      assert extend_to_64bit(0x00, 2) == 0x00
      # all bits set
      assert extend_to_64bit(0xFF, 1) == 0xFFFF_FFFF_FFFF_FFFF
    end
  end

  describe "basic block analysis" do
    test "finds basic block starts with simple program" do
      program = <<
        # trap
        0x00,
        # fallthrough
        0x11,
        # store_imm_u8 (not termination)
        0x3E,
        # immediates
        0x01,
        0x05
      >>

      bitmask = <<28::5>>
      # skip will be [0,0]
      #  n +1 + skip(n) -> 0+1+0, 1+1+0 = [1,2]
      #  add 0 -> [0,1,2]

      starts = basic_block_starts(program, bitmask)
      # 0, after trap, after fallthrough (in program order)
      assert starts == %{0 => nil, 1 => nil, 2 => nil}
    end

    test "handles jumps and branches" do
      program = <<
        # jump
        0x05,
        # immediates
        0x01,
        0x05,
        # branch_eq
        0x24,
        # immediates
        0x01,
        0x0A
      >>

      bitmask = <<36::6>>

      starts = basic_block_starts(program, bitmask)
      # 0, after jump, after branch_eq (in program order)
      assert starts == %{0 => nil, 3 => nil, 6 => nil}
    end

    test "empty program has only 0" do
      starts = basic_block_starts(<<>>, <<>>)
      assert starts == %{0 => nil}
    end

    test "no termination instructions only has 0" do
      # just store_imm_u8
      program = <<0x3E, 0x01, 0x05>>
      bitmask = <<4::3>>

      starts = basic_block_starts(program, bitmask)
      assert starts == %{0 => nil}
    end

    test "preserves order of termination instructions" do
      program = <<
        # fallthrough
        0x11,
        # trap
        0x00,
        # jump
        0x05,
        # immediates
        0x01,
        0x05
      >>

      bitmask = <<28::5>>

      starts = basic_block_starts(program, bitmask)
      # Order matches program order
      assert starts == %{0 => nil, 1 => nil, 2 => nil, 5 => nil}
    end
  end
end
