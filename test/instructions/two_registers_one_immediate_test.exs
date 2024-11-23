defmodule Instructions.TwoRegistersOneImmediateTest do
  use ExUnit.Case
  use Instructions
  alias Instructions.TwoRegistersOneImmediate

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

  describe "store operations" do
    # 0x21 is 37 => r_a = 1, r_b = 2, v_x = 10
    # skip = 2
    # l_x = min(4, 2 - 1) = 1
    # v_x = decode_bytes_signed(program[2]..program[2 + l_x]) = 10

    # store puts w_a value in memory at address w_b + v_x => mem[100 + 10] = 42
    test "store_ind_u8 writes byte value" do
      state = create_test_state(<<op(:store_ind_u8), 0x21, 10>>, <<1, 0, 0>>)
      # w_a = 42
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      # w_b = 100
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}

      output = TwoRegistersOneImmediate.execute(:store_ind_u8, state, %StepOutput{})
      assert Memory.read(output.memory, 110, 1) == <<42>>
    end

    test "store_ind_u16 writes 16-bit value" do
      state = create_test_state(<<op(:store_ind_u16), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | registers: List.replace_at(state.registers, 1, 0x1234)}
      output = TwoRegistersOneImmediate.execute(:store_ind_u16, state, %StepOutput{})
      assert Memory.read(output.memory, 110, 2) == <<0x34, 0x12>>
    end

    test "store_ind_u32 writes 32-bit value" do
      state = create_test_state(<<op(:store_ind_u32), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | registers: List.replace_at(state.registers, 1, 0x12345678)}
      output = TwoRegistersOneImmediate.execute(:store_ind_u32, state, %StepOutput{})
      assert Memory.read(output.memory, 110, 4) == <<0x78, 0x56, 0x34, 0x12>>
    end

    test "store_ind_u64 writes 64-bit value" do
      state = create_test_state(<<op(:store_ind_u64), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      value = 0x123456789ABCDEF0
      state = %{state | registers: List.replace_at(state.registers, 1, value)}
      output = TwoRegistersOneImmediate.execute(:store_ind_u64, state, %StepOutput{})

      assert Memory.read(output.memory, 110, 8) ==
               <<0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12>>
    end
  end

  describe "unsigned load operations" do
    # r_a = 1, r_b = 2, v_x = 10
    # load_ind reads mem[w_b + v_x] and puts it in w_a
    test "load_ind_u8 reads byte value" do
      memory = Memory.write(%Memory{}, 110, <<42>>)
      state = create_test_state(<<op(:load_ind_u8), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_u8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "load_ind_u16 reads 16-bit value" do
      memory = Memory.write(%Memory{}, 110, <<0x34, 0x12>>)
      state = create_test_state(<<op(:load_ind_u16), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_u16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x1234
    end

    test "load_ind_u32 reads 32-bit value" do
      memory = Memory.write(%Memory{}, 110, <<0x78, 0x56, 0x34, 0x12>>)
      state = create_test_state(<<op(:load_ind_u32), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_u32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x12345678
    end

    test "load_ind_u64 reads 64-bit value" do
      memory = Memory.write(%Memory{}, 110, <<0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12>>)
      state = create_test_state(<<op(:load_ind_u64), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_u64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x123456789ABCDEF0
    end
  end

  describe "signed load operations" do
    test "load_ind_i8 reads signed byte value" do
      # -127 signed
      memory = Memory.write(%Memory{}, 110, <<0x80>>)
      state = create_test_state(<<op(:load_ind_i8), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_i8, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_FF80
    end

    test "load_ind_i16 reads signed 16-bit value" do
      memory = Memory.write(%Memory{}, 110, <<0x50, 0x80>>)
      state = create_test_state(<<op(:load_ind_i16), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_i16, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_8050
    end

    test "load_ind_i32 reads signed 32-bit value" do
      memory = Memory.write(%Memory{}, 110, <<0x03, 0x02, 0x01, 0x80>>)
      state = create_test_state(<<op(:load_ind_i32), 0x21, 10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 100)}
      state = %{state | memory: memory}
      output = TwoRegistersOneImmediate.execute(:load_ind_i32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_8001_0203
    end
  end

  describe "32-bit arithmetic operations" do
    # w_a = w_b (op) v_x
    test "add_imm_32 performs addition" do
      state = create_test_state(<<op(:add_imm_32), 0x21, 5>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}
      output = TwoRegistersOneImmediate.execute(:add_imm_32, state, %StepOutput{})
      # w_1 = w_2 + v_x = 10 + 5 = 15
      assert Enum.at(output.registers, 1) == 15
    end

    test "mul_imm_32 performs multiplication" do
      state = create_test_state(<<op(:mul_imm_32), 0x21, 5>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}
      output = TwoRegistersOneImmediate.execute(:mul_imm_32, state, %StepOutput{})
      # w_1 = w_2 * v_x = 10 * 5 = 50
      assert Enum.at(output.registers, 1) == 50
    end

    test "neg_add_imm_32 performs negated addition" do
      state = create_test_state(<<op(:neg_add_imm_32), 0x21, 5>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}
      output = TwoRegistersOneImmediate.execute(:neg_add_imm_32, state, %StepOutput{})
      # 5 + (2^32 - 10) mod 2^32
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_FFFB
    end
  end

  describe "bitwise operations" do
    test "and_imm performs bitwise AND" do
      state = create_test_state(<<op(:and_imm), 0x21, 0b0000_1011>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1011_1101)}
      output = TwoRegistersOneImmediate.execute(:and_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0b0000_1001
    end

    test "or_imm performs bitwise OR" do
      state = create_test_state(<<op(:or_imm), 0x21, 0b0000_1011>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1011_1101)}
      output = TwoRegistersOneImmediate.execute(:or_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0b1011_1111
    end

    test "xor_imm performs bitwise XOR" do
      state = create_test_state(<<op(:xor_imm), 0x21, 0b0010_1011>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1011_1101)}
      output = TwoRegistersOneImmediate.execute(:xor_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0b1001_0110
    end
  end

  describe "comparison operations" do
    test "set_lt_u_imm sets register when unsigned less than" do
      state = create_test_state(<<op(:set_lt_u_imm), 0x21, 0x10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x0F)}
      output = TwoRegistersOneImmediate.execute(:set_lt_u_imm, state, %StepOutput{})
      # 0x0F < 0x10
      assert Enum.at(output.registers, 1) == 1
    end

    test "set_lt_s_imm sets register when signed less than" do
      state = create_test_state(<<op(:set_lt_s_imm), 0x21, 0x79>>, <<1, 0, 0>>)
      # -128 in signed
      state = %{state | registers: List.replace_at(state.registers, 2, 0x78)}
      output = TwoRegistersOneImmediate.execute(:set_lt_s_imm, state, %StepOutput{})
      # -128 < 127
      assert Enum.at(output.registers, 1) == 1
    end

    test "set_gt_u_imm sets register when unsigned greater than" do
      state = create_test_state(<<op(:set_gt_u_imm), 0x21, 0x10>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x11)}
      output = TwoRegistersOneImmediate.execute(:set_gt_u_imm, state, %StepOutput{})
      # 0x11 > 0x10
      assert Enum.at(output.registers, 1) == 1
    end

    test "set_gt_s_imm sets register when signed greater than" do
      # -1 in signed
      state = create_test_state(<<op(:set_gt_s_imm), 0x21, 0xFF>>, <<1, 0, 0>>)
      # 127 in signed
      state = %{state | registers: List.replace_at(state.registers, 2, 0x7F)}
      output = TwoRegistersOneImmediate.execute(:set_gt_s_imm, state, %StepOutput{})
      # 127 > -1
      assert Enum.at(output.registers, 1) == 1
    end
  end

  describe "32-bit shift operations" do
    test "shlo_l_imm shifts left" do
      state = create_test_state(<<op(:shlo_l_imm_32), 0x21, 2>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 3)}
      output = TwoRegistersOneImmediate.execute(:shlo_l_imm_32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 12
    end

    test "shlo_r_imm shifts right" do
      state = create_test_state(<<op(:shlo_r_imm_32), 0x21, 1>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shlo_r_imm_32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 2
    end

    test "shar_r_imm performs arithmetic right shift" do
      state = create_test_state(<<op(:shar_r_imm_32), 0x21, 1>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFF_FFFC)}
      output = TwoRegistersOneImmediate.execute(:shar_r_imm_32, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_FFFE
    end
  end

  describe "32-bit alternative shift operations" do
    test "shlo_l_imm_alt_32 performs alternative left shift" do
      state = create_test_state(<<op(:shlo_l_imm_alt_32), 0x21, 0x78>>, <<1, 0, 0>>)
      # shift by 4
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shlo_l_imm_alt_32, state, %StepOutput{})
      # 0x78 << 4 = 0x780
      assert Enum.at(output.registers, 1) == 0x780
    end

    test "shlo_r_imm_alt_32 performs alternative right shift" do
      state = create_test_state(<<op(:shlo_r_imm_alt_32), 0x21, 0x78>>, <<1, 0, 0>>)
      # shift by 4
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shlo_r_imm_alt_32, state, %StepOutput{})
      # 0x78 >> 4 = 0x7
      assert Enum.at(output.registers, 1) == 0x7
    end

    test "shar_r_imm_alt_32 performs alternative arithmetic right shift" do
      state = create_test_state(<<op(:shar_r_imm_alt_32), 0x21, 0x78>>, <<1, 0, 0>>)
      # shift by 4
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shar_r_imm_alt_32, state, %StepOutput{})
      # 0xF8 >> 4 with sign extension
      assert Enum.at(output.registers, 1) == 0x7
    end
  end

  describe "conditional move operations" do
    test "cmov_iz_imm moves immediate when register is zero" do
      state = create_test_state(<<op(:cmov_iz_imm), 0x21, 42>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0)}
      output = TwoRegistersOneImmediate.execute(:cmov_iz_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end

    test "cmov_nz_imm moves immediate when register is non-zero" do
      state = create_test_state(<<op(:cmov_nz_imm), 0x21, 42>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 1)}
      output = TwoRegistersOneImmediate.execute(:cmov_nz_imm, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 42
    end
  end

  describe "64-bit arithmetic operations" do
    test "add_imm_64 performs 64-bit addition" do
      state = create_test_state(<<op(:add_imm_64), 0x21, 0x01, 0x02>>, <<1, 0, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFF_FFFF_0000_0000)}
      output = TwoRegistersOneImmediate.execute(:add_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_0000_0201
    end

    test "mul_imm_64 performs 64-bit multiplication" do
      state = create_test_state(<<op(:mul_imm_64), 0x21, 2>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x8000_0000_0000_0000)}
      output = TwoRegistersOneImmediate.execute(:mul_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0
    end

    test "neg_add_imm_64 performs 64-bit negated addition" do
      state = create_test_state(<<op(:neg_add_imm_64), 0x21, 5>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}
      output = TwoRegistersOneImmediate.execute(:neg_add_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_FFFB
    end
  end

  describe "64-bit shift operations" do
    test "shlo_l_imm_64 performs 64-bit left shift" do
      state = create_test_state(<<op(:shlo_l_imm_64), 0x21, 4>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x1234_5678_9ABC_DEF0)}
      output = TwoRegistersOneImmediate.execute(:shlo_l_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x2345_6789_ABCD_EF00
    end

    test "shlo_r_imm_64 performs 64-bit logical right shift" do
      state = create_test_state(<<op(:shlo_r_imm_64), 0x21, 4>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x1234_5678_9ABC_DEF0)}
      output = TwoRegistersOneImmediate.execute(:shlo_r_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x0123_4567_89AB_CDEF
    end

    test "shar_r_imm_64 performs 64-bit arithmetic right shift" do
      state = create_test_state(<<op(:shar_r_imm_64), 0x21, 4>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0xF234_5678_9ABC_DEF0)}
      output = TwoRegistersOneImmediate.execute(:shar_r_imm_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0xFF23_4567_89AB_CDEF
    end

    test "shift operations handle shift amount modulo 64" do
      state = create_test_state(<<op(:shlo_l_imm_64), 0x21, 68>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 2, 0x1234_5678_9ABC_DEF0)}
      output = TwoRegistersOneImmediate.execute(:shlo_l_imm_64, state, %StepOutput{})
      # 68 mod 64 = 4
      assert Enum.at(output.registers, 1) == 0x2345_6789_ABCD_EF00
    end
  end

  describe "64-bit alternative shift operations" do
    test "shlo_l_imm_alt_64 performs alternative left shift" do
      state =
        create_test_state(
          <<op(:shlo_l_imm_alt_64), 0x21, 0x78, 0x56, 0x34, 0x12>>,
          <<1, 0, 0, 0, 0, 0>>
        )

      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shlo_l_imm_alt_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x1234_56780
    end

    test "shlo_r_imm_alt_64 performs alternative right shift" do
      state =
        create_test_state(
          <<op(:shlo_r_imm_alt_64), 0x21, 0x78, 0x56, 0x34, 0x12>>,
          <<1, 0, 0, 0, 0, 0>>
        )

      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shlo_r_imm_alt_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x0123_4567
    end

    test "shar_r_imm_alt_64 performs alternative arithmetic right shift" do
      state =
        create_test_state(
          <<op(:shar_r_imm_alt_64), 0x21, 0xF2, 0x34, 0x56, 0x78>>,
          <<1, 0, 0, 0, 0, 0>>
        )

      state = %{state | registers: List.replace_at(state.registers, 2, 4)}
      output = TwoRegistersOneImmediate.execute(:shar_r_imm_alt_64, state, %StepOutput{})
      assert Enum.at(output.registers, 1) == 0x7856_34F
    end
  end
end
