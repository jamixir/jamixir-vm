defmodule TransitionsTest do
  use ExUnit.Case
  doctest Transitions

  describe "z_n/2" do
    test "handles values below threshold" do
      assert Transitions.z_n(100, 1) == 100  # 8-bit
      assert Transitions.z_n(1000, 2) == 1000  # 16-bit
    end

    test "handles values above threshold" do
      # 8-bit (n=1) threshold is 2^7 = 128
      assert Transitions.z_n(200, 1) == -56  # 200 - 256 = -56
      # 16-bit (n=2) threshold is 2^15 = 32768
      assert Transitions.z_n(50000, 2) == -15536  # 50000 - 65536 = -15536
    end

    test "handles edge cases" do
      assert Transitions.z_n(0, 1) == 0
      assert Transitions.z_n(127, 1) == 127  # Last positive 8-bit
      assert Transitions.z_n(128, 1) == -128  # First negative 8-bit
      assert Transitions.z_n(255, 1) == -1  # Last 8-bit number
    end
  end

  describe "z_n_inverse/2" do
    test "converts negative numbers back to unsigned" do
      assert Transitions.z_n_inverse(-56, 1) == 200
      assert Transitions.z_n_inverse(-15536, 2) == 50000
    end

    test "preserves positive numbers" do
      assert Transitions.z_n_inverse(100, 1) == 100
      assert Transitions.z_n_inverse(1000, 2) == 1000
    end

    test "handles edge cases" do
      assert Transitions.z_n_inverse(0, 1) == 0
      assert Transitions.z_n_inverse(-128, 1) == 128
      assert Transitions.z_n_inverse(-1, 1) == 255
    end
  end

  describe "b_n/2" do
    test "converts small numbers to binary" do
      assert Transitions.b_n(5, 1) == [0, 0, 0, 0, 0, 1, 0, 1]
      assert Transitions.b_n(10, 1) == [0, 0, 0, 0, 1, 0, 1, 0]
    end

    test "handles zero" do
      assert Transitions.b_n(0, 1) == List.duplicate(0, 8)
      assert Transitions.b_n(0, 2) == List.duplicate(0, 16)
    end

    test "pads to correct width" do
      # 42 in 8-bit binary should be [0,0,1,0,1,0,1,0]
      assert Transitions.b_n(42, 1) == [0, 0, 1, 0, 1, 0, 1, 0]
      # Same number in 16-bit should have 8 more leading zeros
      assert Transitions.b_n(42, 2) == [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0]
    end
  end

  describe "b_n_inverse/1" do
    test "converts binary back to numbers" do
      assert Transitions.b_n_inverse([0, 0, 0, 0, 0, 1, 0, 1]) == 5
      assert Transitions.b_n_inverse([0, 0, 0, 0, 1, 0, 1, 0]) == 10
    end

    test "handles all zeros" do
      assert Transitions.b_n_inverse(List.duplicate(0, 8)) == 0
      assert Transitions.b_n_inverse(List.duplicate(0, 16)) == 0
    end

    test "handles all ones" do
      assert Transitions.b_n_inverse(List.duplicate(1, 8)) == 255
      assert Transitions.b_n_inverse(List.duplicate(1, 16)) == 65535
    end

    test "roundtrip conversion" do
      original = 42
      assert original
             |> Transitions.b_n(1)
             |> Transitions.b_n_inverse() == original
    end
  end

  test "full roundtrip conversions" do
    numbers = [0, 42, 127, 128, 200, 255]

    for n <- numbers do
      assert n
             |> Transitions.z_n(1)
             |> Transitions.z_n_inverse(1) == n

      assert n
             |> Transitions.b_n(1)
             |> Transitions.b_n_inverse() == n
    end
  end
end 
