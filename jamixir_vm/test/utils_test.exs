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

  describe "sign_extend/2" do
    test "1-byte values (n=1)" do
      # Positive numbers (MSB = 0)
      assert sign_extend(0x40, 1) == 0x40        # 0b0100_0000
      assert sign_extend(0x7F, 1) == 0x7F        # 0b0111_1111 (largest positive)

      # Negative numbers (MSB = 1)
      assert sign_extend(0x80, 1) == 0xFFFF_FF80 # 0b1000_0000 (smallest negative)
      assert sign_extend(0xC0, 1) == 0xFFFF_FFC0 # 0b1100_0000
    end

    test "2-byte values (n=2)" do
      # Positive numbers (MSB = 0)
      assert sign_extend(0x4000, 2) == 0x4000        # 0b0100_0000_0000_0000
      assert sign_extend(0x7FFF, 2) == 0x7FFF        # 0b0111_1111_1111_1111 (largest positive)

      # Negative numbers (MSB = 1)
      assert sign_extend(0x8000, 2) == 0xFFFF_8000   # 0b1000_0000_0000_0000 (smallest negative)
      assert sign_extend(0xC000, 2) == 0xFFFF_C000   # 0b1100_0000_0000_0000
    end

    test "edge cases" do
      assert sign_extend(0x2A, 0) == 0x2A     # n=0 case
      assert sign_extend(0x00, 1) == 0x00     # zero
      assert sign_extend(0x00, 2) == 0x00     # zero
      assert sign_extend(0xFF, 1) == 0xFFFF_FFFF  # all bits set
    end
  end
end
