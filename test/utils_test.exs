defmodule UtilsTest do
  use ExUnit.Case
  import PVM.Utils

  # Helper function to convert binary pattern to bitmask binary
  defp bits_to_binary(pattern) do
    pattern
    |> Integer.to_string(2)
    |> String.pad_leading(8, "0")
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
    |> :binary.list_to_bin()
  end

  describe "skip/2" do
    test "basic patterns" do
      # Single instruction (1 byte)
      assert skip(0, bits_to_binary(0b11000000)) == 0

      # Two 1-byte instructions
      assert skip(0, bits_to_binary(0b10010000)) == 2

      # One 2-byte instruction
      assert skip(0, bits_to_binary(0b10000000)) == 7
    end

    test "complex instructions" do
      bitmask = bits_to_binary(0b10010100)
      # [3-byte inst][1-byte inst][2-byte inst]
      assert skip(0, bitmask) == 2  # First instruction is 3 bytes
      assert skip(3, bitmask) == 1  # Second instruction is 1 byte
      assert skip(5, bitmask) == 2  # Third instruction is 2 bytes
    end

    test "boundary conditions" do
      # At end of bitmask
      assert skip(7, bits_to_binary(0b10000000)) == 0

      # Beyond bitmask length
      assert skip(8, bits_to_binary(0b10000000)) == 0

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
      assert extend_to_64bit(0x40, 1) == 0x40        # 0b0100_0000
      assert extend_to_64bit(0x7F, 1) == 0x7F        # 0b0111_1111 (largest positive)

      # Negative numbers (MSB = 1)
      assert extend_to_64bit(0x80, 1) == 0xFFFF_FFFF_FFFF_FF80  # 0b1000_0000 (smallest negative)
      assert extend_to_64bit(0xC0, 1) == 0xFFFF_FFFF_FFFF_FFC0  # 0b1100_0000
    end

    test "2-byte values (n=2)" do
      # Positive numbers (MSB = 0)
      assert extend_to_64bit(0x4000, 2) == 0x4000        # 0b0100_0000_0000_0000
      assert extend_to_64bit(0x7FFF, 2) == 0x7FFF        # 0b0111_1111_1111_1111 (largest positive)

      # Negative numbers (MSB = 1)
      assert extend_to_64bit(0x8000, 2) == 0xFFFF_FFFF_FFFF_8000  # 0b1000_0000_0000_0000 (smallest negative)
      assert extend_to_64bit(0xC000, 2) == 0xFFFF_FFFF_FFFF_C000  # 0b1100_0000_0000_0000
    end

    test "edge cases" do
      assert extend_to_64bit(0x2A, 0) == 0x2A     # n=0 case
      assert extend_to_64bit(0x00, 1) == 0x00     # zero
      assert extend_to_64bit(0x00, 2) == 0x00     # zero
      assert extend_to_64bit(0xFF, 1) == 0xFFFF_FFFF_FFFF_FFFF  # all bits set
    end
  end


  describe "basic block analysis" do
    test "finds basic block starts with simple program" do
      program = <<
        0x00,         # trap
        0x11,         # fallthrough
        0x3E,         # store_imm_u8 (not termination)
        0x01, 0x05    # immediates
      >>
      bitmask = <<1, 1, 1, 0, 0>>
      # skip will be [0,0]
      #  n +1 + skip(n) -> 0+1+0, 1+1+0 = [1,2]
      #  add 0 -> [0,1,2]

      starts = basic_block_starts(program, bitmask)
      assert starts == [0, 1, 2]  # 0, after trap, after fallthrough (in program order)
    end

    test "handles jumps and branches" do
      program = <<
        0x05,         # jump
        0x01, 0x05,   # immediates
        0x24,         # branch_eq
        0x01, 0x0A    # immediates
      >>
      bitmask = <<1, 0, 0, 1, 0, 0>>

      starts = basic_block_starts(program, bitmask)
      assert starts == [0, 3, 6]  # 0, after jump, after branch_eq (in program order)
    end

    test "empty program has only 0" do
      starts = basic_block_starts(<<>>, <<>>)
      assert starts == [0]
    end

    test "no termination instructions only has 0" do
      program = <<0x3E, 0x01, 0x05>>  # just store_imm_u8
      bitmask = <<1, 0, 0>>

      starts = basic_block_starts(program, bitmask)
      assert starts == [0]
    end

    test "preserves order of termination instructions" do
      program = <<
        0x11,         # fallthrough
        0x00,         # trap
        0x05,         # jump
        0x01, 0x05    # immediates
      >>
      bitmask = <<1, 1, 1, 0, 0>>

      starts = basic_block_starts(program, bitmask)
      assert starts == [0,1, 2, 5]  # Order matches program order
    end
  end
end
