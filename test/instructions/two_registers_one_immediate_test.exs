defmodule Instructions.TwoRegistersOneImmediateTest do
  use ExUnit.Case
  use PVM.Instructions
  alias PVM.{Instructions.TwoRegistersOneImmediate, Memory, Registers, State}

  @min_memory_addr 0x10000
  @init_target_addr @min_memory_addr + 100
  @offset 10
  @final_target_addr @init_target_addr + @offset

  # register 1 and 2
  @registers 2 * 0x10 + 1

  describe "store operations" do
    # 0x21 is 37 => r_a = 1, r_b = 2, v_x = 10
    # skip = 2
    # l_x = min(4, 2 - 1) = 1
    # v_x = decode_bytes_signed(program[2]..program[2 + l_x]) = 10

    # store puts w_a value in memory at address w_b + v_x => mem[100 + 10] = 42
    test "store_ind_u8 writes byte value" do
      program = <<op(:store_ind_u8), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r1: 42, r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:store_ind_u8, program, bitmask, state)

      assert exit_status == :continue
      assert Memory.read(state.memory, @final_target_addr, 1) == {:ok, <<42>>}
    end

    test "store_ind_u16 writes 16-bit value" do
      program = <<op(:store_ind_u16), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: @init_target_addr, r1: 0x1234}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:store_ind_u16, program, bitmask, state)

      assert exit_status == :continue
      assert Memory.read(state.memory, @final_target_addr, 2) == {:ok, <<0x34, 0x12>>}
    end

    test "store_ind_u32 writes 32-bit value" do
      program = <<op(:store_ind_u32), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: @init_target_addr, r1: 0x12345678}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:store_ind_u32, program, bitmask, state)

      assert exit_status == :continue
      assert Memory.read(state.memory, @final_target_addr, 4) == {:ok, <<0x78, 0x56, 0x34, 0x12>>}
    end

    test "store_ind_u64 writes 64-bit value" do
      program = <<op(:store_ind_u64), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: @init_target_addr, r1: 0x123456789ABCDEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:store_ind_u64, program, bitmask, state)

      assert exit_status == :continue

      assert Memory.read(state.memory, @final_target_addr, 8) ==
               {:ok, <<0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12>>}
    end
  end

  describe "unsigned load operations" do
    # r_a = 1, r_b = 2, v_x = 10
    # load_ind reads mem[w_b + v_x] and puts it in w_a
    test "load_ind_u8 reads byte value" do
      program = <<op(:load_ind_u8), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<42>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_u8, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 42
    end

    test "load_ind_u16 reads 16-bit value" do
      program = <<op(:load_ind_u16), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<0x34, 0x12>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_u16, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x1234
    end

    test "load_ind_u32 reads 32-bit value" do
      program = <<op(:load_ind_u32), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<0x78, 0x56, 0x34, 0x12>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_u32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x12345678
    end

    test "load_ind_u64 reads 64-bit value" do
      program = <<op(:load_ind_u64), @registers, @offset>>
      bitmask = <<1, 0, 0>>

      {:ok, memory} =
        Memory.write(
          %Memory{},
          @final_target_addr,
          <<0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12>>
        )

      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_u64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x123456789ABCDEF0
    end
  end

  describe "signed load operations" do
    test "load_ind_i8 reads signed byte value" do
      # -127 signed
      program = <<op(:load_ind_i8), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<0x80>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_i8, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FF80
    end

    test "load_ind_i16 reads signed 16-bit value" do
      program = <<op(:load_ind_i16), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<0x50, 0x80>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_i16, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_8050
    end

    test "load_ind_i32 reads signed 32-bit value" do
      program = <<op(:load_ind_i32), @registers, @offset>>
      bitmask = <<1, 0, 0>>
      {:ok, memory} = Memory.write(%Memory{}, @final_target_addr, <<0x03, 0x02, 0x01, 0x80>>)
      state = %State{memory: memory, registers: %Registers{r2: @init_target_addr}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:load_ind_i32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_8001_0203
    end
  end

  describe "32-bit arithmetic operations" do
    # w_a = w_b (op) v_x
    test "add_imm_32 performs addition" do
      program = <<op(:add_imm_32), @registers, 5>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 10}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:add_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 15
    end

    test "mul_imm_32 performs multiplication" do
      program = <<op(:mul_imm_32), @registers, 5>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 10}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:mul_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 50
    end

    test "neg_add_imm_32 performs negated addition" do
      program = <<op(:neg_add_imm_32), @registers, 5>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 10}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:neg_add_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFB
    end
  end

  describe "bitwise operations" do
    test "and_imm performs bitwise AND" do
      program = <<op(:and_imm), 0x21, 0b0000_1011>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0b1011_1101}}
      {exit_status, state} = TwoRegistersOneImmediate.execute(:and_imm, program, bitmask, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0b0000_1001
    end

    test "or_imm performs bitwise OR" do
      program = <<op(:or_imm), 0x21, 0b0000_1011>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0b1011_1101}}
      {exit_status, state} = TwoRegistersOneImmediate.execute(:or_imm, program, bitmask, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0b1011_1111
    end

    test "xor_imm performs bitwise XOR" do
      program = <<op(:xor_imm), 0x21, 0b0010_1011>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0b1011_1101}}
      {exit_status, state} = TwoRegistersOneImmediate.execute(:xor_imm, program, bitmask, state)
      assert exit_status == :continue
      assert state.registers.r1 == 0b1001_0110
    end
  end

  describe "comparison operations" do
    test "set_lt_u_imm sets register when unsigned less than" do
      program = <<op(:set_lt_u_imm), 0x21, 0x10>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x0F}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:set_lt_u_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 1
    end

    test "set_lt_s_imm sets register when signed less than" do
      program = <<op(:set_lt_s_imm), 0x21, 0x79>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x78}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:set_lt_s_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 1
    end

    test "set_gt_u_imm sets register when unsigned greater than" do
      program = <<op(:set_gt_u_imm), 0x21, 0x10>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x11}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:set_gt_u_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 1
    end

    test "set_gt_s_imm sets register when signed greater than" do
      program = <<op(:set_gt_s_imm), 0x21, 0xFF>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x7F}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:set_gt_s_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 1
    end
  end

  describe "32-bit shift operations" do
    test "shlo_l_imm shifts left" do
      program = <<op(:shlo_l_imm_32), 0x21, 2>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 3}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_l_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 12
    end

    test "shlo_r_imm shifts right" do
      program = <<op(:shlo_r_imm_32), 0x21, 1>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_r_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 2
    end

    test "shar_r_imm performs arithmetic right shift" do
      program = <<op(:shar_r_imm_32), 0x21, 1>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0xFFFF_FFFC}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shar_r_imm_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFE
    end
  end

  describe "32-bit alternative shift operations" do
    test "shlo_l_imm_alt_32 performs alternative left shift" do
      program = <<op(:shlo_l_imm_alt_32), 0x21, 0x78>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_l_imm_alt_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x780
    end

    test "shlo_r_imm_alt_32 performs alternative right shift" do
      program = <<op(:shlo_r_imm_alt_32), 0x21, 0x78>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_r_imm_alt_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x7
    end

    test "shar_r_imm_alt_32 performs alternative arithmetic right shift" do
      program = <<op(:shar_r_imm_alt_32), 0x21, 0x78>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shar_r_imm_alt_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x7
    end

    test "shar_r_imm_alt_32 modulo 2^32" do
      program = <<op(:shar_r_imm_alt_32), 0x21, 0x7_0000_0078>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shar_r_imm_alt_32, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x7
    end
  end

  describe "conditional move operations" do
    test "cmov_iz_imm moves immediate when register is zero" do
      program = <<op(:cmov_iz_imm), 0x21, 42>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:cmov_iz_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 42
    end

    test "cmov_nz_imm moves immediate when register is non-zero" do
      program = <<op(:cmov_nz_imm), 0x21, 42>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 1}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:cmov_nz_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 42
    end
  end

  describe "64-bit arithmetic operations" do
    test "add_imm_64 performs 64-bit addition" do
      program = <<op(:add_imm_64), 0x21, 0x01, 0x02>>
      bitmask = <<1, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 0xFFFF_FFFF_0000_0000}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:add_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_0000_0201
    end

    test "mul_imm_64 performs 64-bit multiplication" do
      program = <<op(:mul_imm_64), 0x21, 2>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x8000_0000_0000_0000}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:mul_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0
    end

    test "neg_add_imm_64 performs 64-bit negated addition" do
      program = <<op(:neg_add_imm_64), 0x21, 5>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 10}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:neg_add_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_FFFF_FFFB
    end
  end

  describe "64-bit shift operations" do
    test "shlo_l_imm_64 performs 64-bit left shift" do
      program = <<op(:shlo_l_imm_64), 0x21, 4>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x1234_5678_9ABC_DEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_l_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x2345_6789_ABCD_EF00
    end

    test "shlo_r_imm_64 performs 64-bit logical right shift" do
      program = <<op(:shlo_r_imm_64), 0x21, 4>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x1234_5678_9ABC_DEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_r_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x0123_4567_89AB_CDEF
    end

    test "shar_r_imm_64 performs 64-bit arithmetic right shift" do
      program = <<op(:shar_r_imm_64), 0x21, 4>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0xF234_5678_9ABC_DEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shar_r_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFF23_4567_89AB_CDEF
    end

    test "shift operations handle shift amount modulo 64" do
      program = <<op(:shlo_l_imm_64), 0x21, 68>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x1234_5678_9ABC_DEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_l_imm_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x2345_6789_ABCD_EF00
    end
  end

  describe "64-bit alternative shift operations" do
    test "shlo_l_imm_alt_64 performs alternative left shift" do
      program = <<op(:shlo_l_imm_alt_64), 0x21, 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_l_imm_alt_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x1234_56780
    end

    test "shlo_r_imm_alt_64 performs alternative right shift" do
      program = <<op(:shlo_r_imm_alt_64), 0x21, 0x78, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shlo_r_imm_alt_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x0123_4567
    end

    test "shar_r_imm_alt_64 performs alternative arithmetic right shift" do
      program = <<op(:shar_r_imm_alt_64), 0x21, 0xF2, 0x34, 0x56, 0x78>>
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:shar_r_imm_alt_64, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x7856_34F
    end
  end

  describe "rotation operations" do
    test "rot_r_64_imm performs 64-bit right rotation" do
      program = <<op(:rot_r_64_imm), @registers, 8>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x0000_1001_0000_0210}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:rot_r_64_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x0010_0100_0002_1000
    end

    test "rot_r_64_imm_alt performs alternative 64-bit right rotation" do
      program = <<op(:rot_r_64_imm_alt), @registers, 0x03, 0x02, 0, 0x01>> #0x0100_0203
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 48}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:rot_r_64_imm_alt, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x0203_0000_0000_0100
    end

    test "rot_r_32_imm performs 32-bit right rotation" do
      program = <<op(:rot_r_32_imm), @registers, 12>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0xABCD_1234}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:rot_r_32_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0xFFFF_FFFF_D123_4ABC

    end

    test "rot_r_32_imm_alt performs alternative 32-bit right rotation" do
      program = <<op(:rot_r_32_imm_alt), @registers, 0x80, 0x56, 0x34, 0x12>>
      bitmask = <<1, 0, 0, 0, 0, 0>>
      state = %State{registers: %Registers{r2: 4}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:rot_r_32_imm_alt, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x2345_6801
    end

    test "rotation operations handle rotation amount modulo bit width" do
      program = <<op(:rot_r_64_imm), @registers, 68>>
      bitmask = <<1, 0, 0>>
      state = %State{registers: %Registers{r2: 0x1234_5678_9ABC_DEF0}}

      {exit_status, state} =
        TwoRegistersOneImmediate.execute(:rot_r_64_imm, program, bitmask, state)

      assert exit_status == :continue
      assert state.registers.r1 == 0x2345_6789_ABCD_EF01
    end
  end
end
