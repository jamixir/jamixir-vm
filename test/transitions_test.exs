defmodule MathTest do
  use ExUnit.Case
  use PVM.Math
  doctest PVM.Math

  describe "z_n/2" do
    test "handles values below threshold" do
      # 8-bit
      assert u2i(100, 1) == 100
      # 16-bit
      assert u2i(1000, 2) == 1000
    end

    test "handles values above threshold" do
      # 8-bit (n=1) threshold is 2^7 = 128
      # 200 - 256 = -56
      assert u2i(200, 1) == -56
      # 16-bit (n=2) threshold is 2^15 = 32768
      # 50000 - 65536 = -15536
      assert u2i(50000, 2) == -15536
    end

    test "handles edge cases" do
      assert u2i(0, 1) == 0
      # Last positive 8-bit
      assert u2i(127, 1) == 127
      # First negative 8-bit
      assert u2i(128, 1) == -128
      # Last 8-bit number
      assert u2i(255, 1) == -1
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

  test "full roundtrip conversions" do
    numbers = [0, 42, 127, 128, 200, 255]

    for n <- numbers do
      assert n
             |> u2i(1)
             |> i2u(1) == n
    end
  end
end
