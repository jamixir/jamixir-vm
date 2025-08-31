defmodule PVM.RegistersTest do
  use ExUnit.Case
  alias PVM.Registers

  describe "get/2" do
    test "get/2 with integer index" do
      registers = %PVM.Registers{r: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}}

      assert registers[0] == 1
      assert registers[1] == 2
      assert registers[12] == 13
    end

    test "get/2 with list of integers" do
      registers = %PVM.Registers{r: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}}

      assert Registers.get_3(registers, 0, 1, 2) == {1, 2, 3}
      assert Registers.get_3(registers, 12, 11, 10) == {13, 12, 11}
    end
  end

  describe "new/0 and new/1" do
    test "new/0 creates default registers" do
      registers = Registers.new()
      assert registers[0] == 0
      assert registers[12] == 0
    end

    test "new/1 with map" do
      registers = Registers.new(%{0 => 42, 5 => 100})
      assert registers[0] == 42
      assert registers[5] == 100
      # default
      assert registers[1] == 0
    end

    test "new/1 ignores invalid keys" do
      registers = Registers.new(%{0 => 42, 99 => 100})
      assert registers[0] == 42
      # Invalid key 99 should be ignored
      assert registers[1] == 0
    end
  end

  describe "from_list/1" do
    test "creates registers from list" do
      values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
      registers = Registers.from_list(values)

      assert registers[0] == 1
      assert registers[1] == 2
      assert registers[12] == 13
    end
  end

  describe "to_list/1" do
    test "converts registers to list" do
      registers = Registers.new(%{0 => 10, 1 => 20, 12 => 30})
      list = Registers.to_list(registers)

      assert length(list) == 13
      assert Enum.at(list, 0) == 10
      assert Enum.at(list, 1) == 20
      assert Enum.at(list, 12) == 30
      assert Enum.at(list, 2) == 0
    end
  end

  describe "Access behavior - zero-cost integer access" do
    test "fetch/2 works with integer keys" do
      registers = %PVM.Registers{r: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}}

      assert Access.fetch(registers, 0) == {:ok, 1}
      assert Access.fetch(registers, 1) == {:ok, 2}
      assert Access.fetch(registers, 12) == {:ok, 13}
      assert Access.fetch(registers, 99) == :error
    end

    test "bracket syntax works (registers[0])" do
      registers = %PVM.Registers{r: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}}

      assert registers[0] == 1
      assert registers[1] == 2
      assert registers[12] == 13
      # out of range
      assert registers[99] == nil
    end
  end
end
