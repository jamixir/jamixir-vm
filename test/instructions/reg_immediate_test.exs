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
      memory: %Memory{}
    }
  end

  describe "load operations" do
    test "load_imm loads immediate value into register" do
      state = create_test_state(<<0x20, 0x01, 42>>, <<1, 0, 0>>)
      output = RegImmediate.execute(:load_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "load_u8 reads unsigned byte from memory" do
      memory = Memory.write(%Memory{}, 10, <<42>>)
      state = create_test_state(<<0x21, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "load_i8 reads signed byte from memory" do
      memory = Memory.write(%Memory{}, 10, <<255>>)
      state = create_test_state(<<0x22, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_i8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == (1 <<< 32) - 1
    end

    test "load_u16 reads unsigned 16-bit" do
      memory = Memory.write(%Memory{}, 10, <<0x34, 0x12>>)
      state = create_test_state(<<0x23, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x1234
    end

    test "load_i16 reads signed 16-bit" do
      memory = Memory.write(%Memory{}, 10, <<0xFF, 0xFF>>)
      state = create_test_state(<<0x24, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_i16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == (1 <<< 32) - 1
    end

    test "load_u32 reads unsigned 32-bit" do
      memory = Memory.write(%Memory{}, 10, <<0x78, 0x56, 0x34, 0x12>>)
      state = create_test_state(<<0x25, 0x01, 10>>, <<1, 0, 0>>)
      state = %{state | memory: memory}
      output = RegImmediate.execute(:load_u32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x12345678
    end

    test "load_imm_u64 loads 64-bit immediate value into register" do
      # Create program with load_imm_u64 instruction (0x26), register 1, and 64-bit value
      program = <<20>> <> <<0x02, 0x56, 0x34, 0x12, 0xFC, 0xDE, 0xBA, 0x98>>
      state = create_test_state(program, <<1>> <> <<0, 0, 0, 0, 0, 0, 0, 0>>)
      output = RegImmediate.execute(:load_imm_u64, state, %StepOutput{})
      assert Enum.at(output.registers, 2) == 0x98BADEFC12345602
    end

    test "load_imm_u64 handles register index greater than 12" do
      # Test with register index 15 (should be capped to 12)
      program = <<20>> <> <<0x0F, 0x56, 0x34, 0x12, 0xFC, 0xDE, 0xBA, 0x98>>
      state = create_test_state(program, <<1, 0, 0, 0, 0, 0, 0, 0,0>>)
      output = RegImmediate.execute(:load_imm_u64, state, %StepOutput{})
      assert Enum.at(output.registers, 12) == 0x98BADEFC1234560F
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

  describe "jump_ind operation" do
    test "successful jump to valid instruction address" do
      # Create a program with multiple instructions
      # 19 = jump_ind opcode
      # 01 = register 1
      # 00 = immediate value 0
      # 4 = load_imm opcode (at offset 10)
      # 2 = register 2
      # 42 = immediate value 66
      # jump_ind instruction
      # padding to reach offset 10
      # load_imm instruction at offset 10
      program =
        <<19, 1, 0>> <>
          :binary.copy(<<0>>, 7) <>
          <<42, 2, 42>>

      # Bitmask marking instruction starts at offset 0 and 10
      # mark jump_ind instruction
      # no instructions for 9 bytes
      # mark load_imm instruction at offset 10
      # padding
      bitmask =
        <<1>> <>
          :binary.copy(<<0>>, 9) <>
          <<1>> <>
          <<0>>

      state = create_test_state(program, bitmask)

      state = %{
        state
        | # register value = 10
          registers: List.replace_at(state.registers, 1, 10),
          # jump_table needs enough entries for index 5 (10 div 2)
          # index 5 maps to 10
          jump_table: [2, 4, 6, 8, 10],
          counter: 0
      }

      # Utils.basic_block_starts will generate start_set containing [0, 10]
      output = RegImmediate.execute(:jump_ind, state, %StepOutput{})
      assert output.exit_status == :continue
      # jumps to load_imm instruction
      assert output.counter == 10
    end

    test "halt on special address 0xFFFF0000" do
      state = create_test_state(<<0x19, 0x01, 0>>, <<1, 0, 0>>)

      state = %{
        state
        | registers: List.replace_at(state.registers, 1, 0xFFFF0000),
          jump_table: [10]
      }

      output = RegImmediate.execute(:jump_ind, state, %StepOutput{})
      assert output.exit_status == :halt
      assert output.counter == 0
    end

    test "panic on unaligned address" do
      state = create_test_state(<<0x19, 0x01, 0>>, <<1, 0, 0>>)

      state = %{
        state
        | # odd number, not aligned
          registers: List.replace_at(state.registers, 1, 3),
          jump_table: [10]
      }

      output = RegImmediate.execute(:jump_ind, state, %StepOutput{})
      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "panic on jump table index out of bounds" do
      state = create_test_state(<<0x19, 0x01, 0>>, <<1, 0, 0>>)

      state = %{
        state
        | # results in index 5
          registers: List.replace_at(state.registers, 1, 10),
          # only has one entry
          jump_table: [2],
          counter: 0
      }

      output = RegImmediate.execute(:jump_ind, state, %StepOutput{})
      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "panic on jump to non-instruction start" do
      program = :binary.copy(<<0>>, 12)
      # no instruction starts marked
      bitmask = :binary.copy(<<0>>, 12)

      state = create_test_state(program, bitmask)

      state = %{
        state
        | registers: List.replace_at(state.registers, 1, 8),
          # points to offset 10, but it's not an instruction start
          jump_table: [10],
          counter: 0
      }

      output = RegImmediate.execute(:jump_ind, state, %StepOutput{})
      assert output.exit_status == :panic
      assert output.counter == 0
    end
  end
end
