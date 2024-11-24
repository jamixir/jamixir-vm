defmodule Instructions.ThreeRegistersTest do
  use ExUnit.Case
  use Instructions
  import Bitwise
  alias Instructions.ThreeRegisters

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

  describe "32-bit arithmetic operations" do
    test "add_32 performs addition" do
      state = create_test_state(<<op(:add_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 58)}

      output = ThreeRegisters.execute(:add_32, state, %StepOutput{})
      # 42 + 58 = 100
      assert Enum.at(output.registers, 3) == 100
    end

    test "sub_32 performs subtraction" do
      state = create_test_state(<<op(:sub_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 58)}

      output = ThreeRegisters.execute(:sub_32, state, %StepOutput{})
      # 100 - 58 = 42
      assert Enum.at(output.registers, 3) == 42
    end

    test "mul_32 performs multiplication" do
      state = create_test_state(<<op(:mul_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 6)}
      state = %{state | registers: List.replace_at(state.registers, 2, 7)}

      output = ThreeRegisters.execute(:mul_32, state, %StepOutput{})
      # 6 * 7 = 42
      assert Enum.at(output.registers, 3) == 42
    end
  end

  describe "32-bit division operations" do
    test "div_u_32 performs unsigned division" do
      state = create_test_state(<<op(:div_u_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 20)}

      output = ThreeRegisters.execute(:div_u_32, state, %StepOutput{})
      # 100 / 20 = 5
      assert Enum.at(output.registers, 3) == 5
    end

    test "div_u_32 - mod(w_b, 2^32) is 0" do
      state = create_test_state(<<op(:div_u_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 1 <<< 32)}

      output = ThreeRegisters.execute(:div_u_32, state, %StepOutput{})
      # 100 / 2^64 = 0
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFF
    end

    test "rem_u_32 performs unsigned remainder" do
      state = create_test_state(<<op(:rem_u_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}

      output = ThreeRegisters.execute(:rem_u_32, state, %StepOutput{})
      # 42 % 10 = 2
      assert Enum.at(output.registers, 3) == 2
    end

    test "rem_u_32 - mod(w_b, 2^32) is 0" do
      state = create_test_state(<<op(:rem_u_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 1 <<< 32)}

      output = ThreeRegisters.execute(:rem_u_32, state, %StepOutput{})
      # 42 % 2^32 = 42
      assert Enum.at(output.registers, 3) == 0x0000_0000_0000_002A
    end

    test "div_s_32 performs signed division" do
      state = create_test_state(<<op(:div_s_32), 0x21, 3>>, <<1, 0, 0>>)
      # -100 as unsigned 32-bit, sign-extended to 64-bit
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFF_FF9C)}
      state = %{state | registers: List.replace_at(state.registers, 2, 20)}

      output = ThreeRegisters.execute(:div_s_32, state, %StepOutput{})
      # -5 as unsigned 64-bit
      assert Enum.at(output.registers, 3) == 0xFFFF_FFFF_FFFF_FFFB
    end

    test "rem_s_32 performs signed remainder" do
      state = create_test_state(<<op(:rem_s_32), 0x21, 3>>, <<1, 0, 0>>)
      # -42 as unsigned 32-bit, sign-extended to 64-bit
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFD6)}
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}

      output = ThreeRegisters.execute(:rem_s_32, state, %StepOutput{})
      # -2 as unsigned 64-bit
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFE
    end
  end

  describe "bitwise operations" do
    test "and performs bitwise AND" do
      state = create_test_state(<<op(:and), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0b1100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1010)}

      output = ThreeRegisters.execute(:and, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0b1000
    end

    test "or performs bitwise OR" do
      state = create_test_state(<<op(:or), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0b1100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1010)}

      output = ThreeRegisters.execute(:or, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0b1110
    end

    test "xor performs bitwise XOR" do
      state = create_test_state(<<op(:xor), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0b1100)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0b1010)}

      output = ThreeRegisters.execute(:xor, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0b0110
    end
  end

  describe "comparison operations" do
    test "set_lt_u performs unsigned less than comparison" do
      state = create_test_state(<<op(:set_lt_u), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 5)}
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}

      output = ThreeRegisters.execute(:set_lt_u, state, %StepOutput{})
      # 5 < 10 -> true (1)
      assert Enum.at(output.registers, 3) == 1
    end

    test "set_lt_s performs signed less than comparison" do
      state = create_test_state(<<op(:set_lt_s), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, -5)}
      state = %{state | registers: List.replace_at(state.registers, 2, 10)}

      output = ThreeRegisters.execute(:set_lt_s, state, %StepOutput{})
      # -5 < 10 -> true (1)
      assert Enum.at(output.registers, 3) == 1
    end
  end

  describe "conditional move operations" do
    test "cmov_iz moves if zero" do
      state = create_test_state(<<op(:cmov_iz), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0)}
      state = %{state | registers: List.replace_at(state.registers, 3, 100)}

      output = ThreeRegisters.execute(:cmov_iz, state, %StepOutput{})
      # Should move 42 since condition is zero
      assert Enum.at(output.registers, 3) == 42
    end

    test "cmov_nz moves if not zero" do
      state = create_test_state(<<op(:cmov_nz), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 42)}
      state = %{state | registers: List.replace_at(state.registers, 2, 1)}
      state = %{state | registers: List.replace_at(state.registers, 3, 100)}

      output = ThreeRegisters.execute(:cmov_nz, state, %StepOutput{})
      # Should move 42 since condition is not zero
      assert Enum.at(output.registers, 3) == 42
    end
  end

  describe "64-bit arithmetic operations" do
    test "add_64 performs addition" do
      state = create_test_state(<<op(:add_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFF00000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x00000000FFFFFFFF)}

      output = ThreeRegisters.execute(:add_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFF
    end

    test "sub_64 performs subtraction" do
      state = create_test_state(<<op(:sub_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFFFFFFFFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x0000000000000001)}

      output = ThreeRegisters.execute(:sub_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFE
    end

    test "mul_64 performs multiplication" do
      state = create_test_state(<<op(:mul_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x100000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x100000000)}

      output = ThreeRegisters.execute(:mul_64, state, %StepOutput{})
      # Overflow in 64-bit
      assert Enum.at(output.registers, 3) == 0x0000000000000000
    end
  end

  describe "64-bit division operations" do
    test "div_u_64 performs unsigned division" do
      state = create_test_state(<<op(:div_u_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFFFFFFFFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 2)}

      output = ThreeRegisters.execute(:div_u_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x7FFFFFFFFFFFFFFF
    end

    test "div_u_64 - mod(w_b, 2^64) is 0" do
      state = create_test_state(<<op(:div_u_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFFFFFFFFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 1 <<< 64)}

      output = ThreeRegisters.execute(:div_u_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFF
    end

    test "div_s_64 performs signed division" do
      state = create_test_state(<<op(:div_s_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, -0x8000000000000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 2)}

      output = ThreeRegisters.execute(:div_s_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xC000000000000000
    end

    test "rem_u_64 performs unsigned remainder" do
      state = create_test_state(<<op(:rem_u_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFFFFFFFFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 3)}

      output = ThreeRegisters.execute(:rem_u_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0
    end

    test "rem_s_64 performs signed remainder" do
      state = create_test_state(<<op(:rem_s_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, -0x8000000000000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 3)}

      output = ThreeRegisters.execute(:rem_s_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFE  # -2 as unsigned
    end
  end

  describe "shift operations" do
    test "shlo_l_32 performs logical left shift" do
      state = create_test_state(<<op(:shlo_l_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x1234_5678)}
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}

      output = ThreeRegisters.execute(:shlo_l_32, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x2345_6780
    end

    test "shlo_r_32 performs logical right shift" do
      state = create_test_state(<<op(:shlo_r_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x1234_5678)}
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}

      output = ThreeRegisters.execute(:shlo_r_32, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x0123_4567
    end

    test "shar_r_32 performs arithmetic right shift" do
      state = create_test_state(<<op(:shar_r_32), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xF234_5678)}
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}

      output = ThreeRegisters.execute(:shar_r_32, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFF_FFFF_F234_567
    end

    test "shlo_l_64 performs logical left shift" do
      state = create_test_state(<<op(:shlo_l_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 1)}
      state = %{state | registers: List.replace_at(state.registers, 2, 63)}

      output = ThreeRegisters.execute(:shlo_l_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x8000000000000000
    end

    test "shlo_r_64 performs logical right shift" do
      state = create_test_state(<<op(:shlo_r_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x8000000000000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 63)}

      output = ThreeRegisters.execute(:shlo_r_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 1
    end
    test "shar_r_64 performs arithmetic right shift" do
      state = create_test_state(<<op(:shar_r_64), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xF234567890ABCDEF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 4)}

      output = ThreeRegisters.execute(:shar_r_64, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFF234567890ABCDF
    end
  end

  describe "upper multiplication operations" do
    test "mul_upper_s_s performs signed-signed upper multiplication" do
      state = create_test_state(<<op(:mul_upper_s_s), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x8000000000000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0x8000000000000000)}

      output = ThreeRegisters.execute(:mul_upper_s_s, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x4000000000000000
    end

    test "mul_upper_u_u performs unsigned-unsigned upper multiplication" do
      state = create_test_state(<<op(:mul_upper_u_u), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0xFFFFFFFFFFFFFFFF)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFFFFFFFFFFFFFF)}

      output = ThreeRegisters.execute(:mul_upper_u_u, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0xFFFFFFFFFFFFFFFE
    end
    test "mul_upper_s_u performs signed-unsigned upper multiplication" do
      state = create_test_state(<<op(:mul_upper_s_u), 0x21, 3>>, <<1, 0, 0>>)
      state = %{state | registers: List.replace_at(state.registers, 1, 0x8000000000000000)}
      state = %{state | registers: List.replace_at(state.registers, 2, 0xFFFFFFFFFFFFFFFF)}

      output = ThreeRegisters.execute(:mul_upper_s_u, state, %StepOutput{})
      assert Enum.at(output.registers, 3) == 0x8000000000000001
    end
  end
end
