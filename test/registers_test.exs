defmodule PVM.RegistersTest do
  use ExUnit.Case
  alias PVM.Registers

  describe "get/2" do
    setup do
      registers = %Registers{r0: 1, r1: 2, r2: 3, r3: 4}
      {:ok, registers: registers}
    end

    test "gets value using atom register name", %{registers: registers} do
      assert Registers.get(registers, :r0) == 1
      assert Registers.get(registers, :r1) == 2
    end

    test "gets value using integer register number", %{registers: registers} do
      assert Registers.get(registers, 0) == 1
      assert Registers.get(registers, 1) == 2
    end

    test "gets multiple values using list of atoms", %{registers: registers} do
      assert Registers.get(registers, [:r0, :r1, :r2]) == [1, 2, 3]
    end

    test "gets multiple values using list of integers", %{registers: registers} do
      assert Registers.get(registers, [0, 1, 2]) == [1, 2, 3]
    end
  end

  describe "set/3" do
    setup do
      {:ok, registers: %Registers{}}
    end

    test "sets value using atom register name", %{registers: registers} do
      updated = Registers.set(registers, :r0, 42)
      assert updated.r0 == 42
    end

    test "sets value using integer register number", %{registers: registers} do
      updated = Registers.set(registers, 0, 42)
      assert updated.r0 == 42
    end
  end

  describe "set/2 with map updates" do
    setup do
      {:ok, registers: %Registers{}}
    end

    test "sets multiple values using atom keys", %{registers: registers} do
      updated = Registers.set(registers, %{r0: 1, r1: 2, r2: 3})
      assert updated.r0 == 1
      assert updated.r1 == 2
      assert updated.r2 == 3
    end

    test "sets multiple values using integer keys", %{registers: registers} do
      updated = Registers.set(registers, %{0 => 1, 1 => 2, 2 => 3})
      assert updated.r0 == 1
      assert updated.r1 == 2
      assert updated.r2 == 3
    end

    test "returns unchanged registers when given empty map", %{registers: registers} do
      assert Registers.set(registers, %{}) == registers
    end

    test "raises error when mixing key types", %{registers: registers} do
      assert_raise ArgumentError, "Keys must be either all atoms or all integers", fn ->
        Registers.set(registers, %{1 => 2, r0: 3})
      end
    end

    test "raises error when keys are invalid atoms", %{registers: registers} do
      assert_raise KeyError, fn ->
        Registers.set(registers, %{r0: 1, invalid: 2})
      end
    end

    test "raises error when keys are invalid integers", %{registers: registers} do
      assert_raise KeyError, fn ->
        Registers.set(registers, %{0 => 1, 13 => 2})
      end
    end
  end
end
