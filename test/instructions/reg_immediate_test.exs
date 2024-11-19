defmodule Instructions.RegImmediateTest do
  use ExUnit.Case
  alias Instructions.RegImmediate
  import Bitwise

  def create_test_state(program, bitmask) do
    %PVM.State{
      program: program,
      bitmask: bitmask,
      counter: 0,
      gas: 100,
      registers: List.duplicate(0, 13),
      memory: Memory.new()
    }
  end

  describe "load operations" do
    test "load_imm loads immediate value into register" do
      state = create_test_state(<<0x20, 0x01, 42>>, <<1, 0, 0>>)
      output = RegImmediate.execute(:load_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "load_u8 reads unsigned byte from memory" do
      memory = Memory.write(Memory.new(), 10, <<42>>)
      state = create_test_state(<<0x21, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "load_i8 reads signed byte from memory" do
      memory = Memory.write(Memory.new(), 10, <<255>>)
      state = create_test_state(<<0x22, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_i8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == (1 <<< 32) -1
    end

    test "load_u16 reads unsigned 16-bit" do
      memory = Memory.write(Memory.new(), 10, <<0x34, 0x12>>)
      state = create_test_state(<<0x23, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x1234
    end

    test "load_i16 reads signed 16-bit" do
      memory = Memory.write(Memory.new(), 10, <<0xFF, 0xFF>>)
      state = create_test_state(<<0x24, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_i16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == (1 <<< 32) - 1
    end

    test "load_u32 reads unsigned 32-bit" do
      memory = Memory.write(Memory.new(), 10, <<0x78, 0x56, 0x34, 0x12>>)
      state = create_test_state(<<0x25, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x12345678
    end
  end

  describe "store operations" do
    test "store_u8 writes byte from register" do
      state = create_test_state(<<0x27, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      output = RegImmediate.execute(:store_u8, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 1) == <<42>>
    end

    test "store_u16 writes 16-bit from register" do
      state = create_test_state(<<0x28, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x1234)}
      output = RegImmediate.execute(:store_u16, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 2) == <<0x34, 0x12>>
    end

    test "store_u32 writes 32-bit from register" do
      state = create_test_state(<<0x29, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x12345678)}
      output = RegImmediate.execute(:store_u32, state, %StepOutput{})
      assert Memory.read(output.memory, 10, 4) == <<0x78, 0x56, 0x34, 0x12>>
    end
  end
end
