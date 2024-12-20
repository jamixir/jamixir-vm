defmodule Instructions.RegImmediateTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.RegImmediate, Memory, Registers, State}

  describe "load operations" do
    test "load_imm loads immediate value into register" do
      program = <<op(:load_imm), 0x01, 42>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {exit_status, state} = RegImmediate.execute(:load_imm, program, bitmask, jump_table, %State{})
      assert exit_status == :continue
      assert state.registers.r1 == 42
    end

    test "load_u8 reads unsigned byte from memory" do
      program = <<op(:load_u8), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<42>>)

      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_u8, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 42
    end

    test "load_i8 reads signed byte from memory" do
      program = <<op(:load_i8), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<255>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_i8, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFF
    end

    test "load_u16 reads unsigned 16-bit" do
      program = <<op(:load_u16), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<0x34, 0x12>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_u16, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0x1234
    end

    test "load_i16 reads signed 16-bit" do
      program = <<op(:load_i16), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<0xFF, 0xFF>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_i16, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFF
    end

    test "load_u32 reads unsigned 32-bit" do
      program = <<op(:load_u32), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<0x78, 0x56, 0x34, 0x12>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_u32, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0x12345678
    end

    test "load_i32 reads signed 32-bit" do
      program = <<op(:load_i32), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<0xFF, 0xFF, 0xFF, 0xFF>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_i32, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFF
    end

    test "load_u64 reads unsigned 64-bit" do
      program = <<op(:load_u64), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []
      {:ok, memory} = Memory.write(%Memory{}, 10, <<0x78, 0x56, 0x34, 0x12, 0xFC, 0xDE, 0xBA, 0x98>>)
      state = %State{memory: memory}
      {exit_status, state} = RegImmediate.execute(:load_u64, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0x98BADEFC12345678
    end

    test "load_imm_64 loads 64-bit immediate value into register" do
      # Create program with load_imm_64 instruction (0x26), register 1, and 64-bit value
      program = <<op(:load_imm_64), 1, 0x02, 0x56, 0x34, 0x12, 0xFC, 0xDE, 0xBA, 0x98>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 0, 0>>
      jump_table = []

      {exit_status, state} =
        RegImmediate.execute(:load_imm_64, program, bitmask, jump_table, %State{})

      assert exit_status == :continue
      assert state.registers.r1 == 0x98BADEFC12345602
    end

    test "load_imm_64 handles register index greater than 12" do
      # Test with register index 15 (should be capped to 12)
      program = <<op(:load_imm_64), 0x0F, 0x56, 0x34, 0x12, 0xFC, 0xDE, 0xBA, 0x98>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 0, 0>>
      jump_table = []

      {exit_status, state} =
        RegImmediate.execute(:load_imm_64, program, bitmask, jump_table, %State{})

      assert exit_status == :continue
      assert state.registers.r12 == 0x98BADEFC1234560F
    end
  end

  describe "store operations" do
    test "store_u8 writes byte from register" do
      program = <<op(:store_u8), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []

      state = %State{registers: %Registers{r1: 42}}
      {exit_status, state} = RegImmediate.execute(:store_u8, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert Memory.read(state.memory, 10, 1) == {:ok,<<42>>}
    end

    test "store_u16 writes 16-bit from register" do
      program = <<op(:store_u16), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []

      state = %State{registers: %Registers{r1: 0x1234}}
      {exit_status, state} = RegImmediate.execute(:store_u16, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert Memory.read(state.memory, 10, 2) == {:ok,<<0x34, 0x12>>}
    end

    test "store_u32 writes 32-bit from register" do
      program = <<op(:store_u32), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []

      state = %State{registers: %Registers{r1: 0x12345678}}
      {exit_status, state} = RegImmediate.execute(:store_u32, program, bitmask, jump_table, state)
      assert exit_status == :continue
      assert Memory.read(state.memory, 10, 4) == {:ok,<<0x78, 0x56, 0x34, 0x12>>}
    end

    test "store_u64 writes 64-bit from register" do
      program = <<op(:store_u64), 0x01, 10>>
      bitmask = <<1, 0, 0>>
      jump_table = []

      state = %State{registers: %Registers{r1: 0x123456789ABCDEF0}}
      {exit_status, state} = RegImmediate.execute(:store_u64, program, bitmask, jump_table, state)
      assert exit_status == :continue

      assert Memory.read(state.memory, 10, 8) ==
               {:ok,<<0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12>>}
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
        <<op(:jump_ind), 1, 0>> <>
          :binary.copy(<<0>>, 7) <>
          <<op(:load_imm), 2, 42>>

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

      jump_table = [2, 4, 6, 8, 10]

      state = %State{
        registers: %Registers{r1: 10}
      }

      # Utils.basic_block_starts will generate start_set containing [0, 10]
      {exit_status, state} = RegImmediate.execute(:jump_ind, program, bitmask, jump_table, state)
      assert exit_status == :continue
      # jumps to load_imm instruction
      assert state.counter == 10
    end

    test "halt on special address 0xFFFF0000" do
      program = <<op(:jump_ind), 0x01, 0>>
      bitmask = <<1, 0, 0>>
      jump_table = [10]

      state = %State{
        registers: %Registers{r1: 0xFFFF0000}
      }

      {exit_status, state} = RegImmediate.execute(:jump_ind, program, bitmask, jump_table, state)
      assert exit_status == :halt
      assert state.counter == 0
    end

    test "panic on unaligned address" do
      program = <<op(:jump_ind), 0x01, 0>>
      bitmask = <<1, 0, 0>>
      jump_table = [10]

      state = %State{
        registers: %Registers{r1: 3}
      }

      {exit_status, state} = RegImmediate.execute(:jump_ind, program, bitmask, jump_table, state)
      assert exit_status == :panic
      assert state.counter == 0
    end

    test "panic on jump table index out of bounds" do
      program = <<op(:jump_ind), 0x01, 0>>
      bitmask = <<1, 0, 0>>
      jump_table = [2]

      state = %State{
        registers: %Registers{r1: 10}
      }

      {exit_status, state} = RegImmediate.execute(:jump_ind, program, bitmask, jump_table, state)
      assert exit_status == :panic
      assert state.counter == 0
    end

    test "panic on jump to non-instruction start" do
      program = :binary.copy(<<0>>, 12)
      # no instruction starts marked
      bitmask = :binary.copy(<<0>>, 12)
      jump_table = [10]

      state = %State{
        registers: %Registers{r1: 8}
      }

      {exit_status, state} = RegImmediate.execute(:jump_ind, program, bitmask, jump_table, state)
      assert exit_status == :panic
      assert state.counter == 0
    end
  end
end
