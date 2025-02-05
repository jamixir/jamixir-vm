defmodule TransitionsTest do
  use ExUnit.Case
  use PVM.Transitions
  doctest PVM.Transitions

  describe "z_n/2" do
    test "handles values below threshold" do
      assert u2i(100, 1) == 100  # 8-bit
      assert u2i(1000, 2) == 1000  # 16-bit
    end

    test "handles values above threshold" do
      # 8-bit (n=1) threshold is 2^7 = 128
      assert u2i(200, 1) == -56  # 200 - 256 = -56
      # 16-bit (n=2) threshold is 2^15 = 32768
      assert u2i(50000, 2) == -15536  # 50000 - 65536 = -15536
    end

    test "handles edge cases" do
      assert u2i(0, 1) == 0
      assert u2i(127, 1) == 127  # Last positive 8-bit
      assert u2i(128, 1) == -128  # First negative 8-bit
      assert u2i(255, 1) == -1  # Last 8-bit number
    end
  end

  describe "z_n_inverse/2" do
    test "converts negative numbers back to unsigned" do
      assert i2u(-56, 1) == 200
      assert i2u(-15536, 2) == 50000
    end

    test "preserves positive numbers" do
      assert i2u(100, 1) == 100
      assert i2u(1000, 2) == 1000
    end

    test "handles edge cases" do
      assert i2u(0, 1) == 0
      assert i2u(-128, 1) == 128
      assert i2u(-1, 1) == 255
    end
  end

  describe "b_n/2" do
    test "converts small numbers to binary" do
      assert u2b(5, 1) == [1, 0, 1, 0, 0, 0, 0, 0]
      assert u2b(10, 1) == [0, 1, 0, 1, 0, 0, 0, 0]
    end

    test "handles zero" do
      assert u2b(0, 1) == List.duplicate(0, 8)
      assert u2b(0, 2) == List.duplicate(0, 16)
    end

    test "pads to correct width" do
      # 42 in 8-bit binary should be [1,0,1,0,1,0,0,0]
      assert u2b(42, 1) == [0, 1, 0, 1, 0, 1, 0, 0]
      # Same number in 16-bit should have 8 more leading zeros
      assert u2b(42, 2) == [0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    end
  end

  describe "b_n_be/2" do
    test "converts small numbers to binary in big-endian" do
      assert u2b_be(5, 1) == [0,0,0,0,0,1,0,1]
      assert u2b_be(10, 1) == [0,0,0,0,1,0,1,0]
    end

    test "handles zero" do
      assert u2b_be(0, 1) == List.duplicate(0, 8)
      assert u2b_be(0, 2) == List.duplicate(0, 16)
    end

    test "pads to correct width" do
      # 42 in 8-bit binary should be [0,0,1,0,1,0,1,0]
      assert u2b_be(42, 1) == [0,0,1,0,1,0,1,0]
      # Same number in 16-bit should have 8 more leading zeros
      assert u2b_be(42, 2) == [0,0,0,0,0,0,0,0,0,0,1,0,1,0,1,0]
    end
  end

  describe "b_n_inverse/1" do
    test "converts binary back to numbers" do
      assert b2u([1, 0, 1, 0, 0, 0, 0, 0]) == 5
      assert b2u([0, 1, 0, 1, 0, 0, 0, 0]) == 10
    end

    test "handles all zeros" do
      assert b2u(List.duplicate(0, 8)) == 0
      assert b2u(List.duplicate(0, 16)) == 0
    end

    test "handles all ones" do
      assert b2u(List.duplicate(1, 8)) == 255
      assert b2u(List.duplicate(1, 16)) == 65535
    end

    test "roundtrip conversion" do
      original = 42
      assert original
             |> u2b(1)
             |> b2u() == original
    end
  end

  describe "b_n_be_inverse/1" do
    test "converts binary back to numbers" do
      assert b2u_be([0,0,0,0,0,1,0,1]) == 5
      assert b2u_be([0,0,0,0,1,0,1,0]) == 10
    end

    test "handles all zeros" do
      assert b2u_be(List.duplicate(0, 8)) == 0
      assert b2u_be(List.duplicate(0, 16)) == 0
    end

    test "handles all ones" do
      assert b2u_be(List.duplicate(1, 8)) == 255
      assert b2u_be(List.duplicate(1, 16)) == 65535
    end

    test "roundtrip conversion" do
      original = 42
      assert original
             |> u2b_be(1)
             |> b2u_be() == original
    end
  end

  test "full roundtrip conversions" do
    numbers = [0, 42, 127, 128, 200, 255]

    for n <- numbers do
      assert n
             |> u2i(1)
             |> i2u(1) == n

      assert n
             |> u2b(1)
             |> b2u() == n
    end
  end
end
