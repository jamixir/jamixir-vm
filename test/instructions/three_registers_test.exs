defmodule Instructions.ThreeRegistersTest do
  use ExUnit.Case
  use PVM.Instructions
  import Bitwise
  alias PVM.{Instructions.ThreeRegisters, Registers, State}

  describe "32-bit arithmetic operations" do
    test "add_32 performs addition" do
      program = <<op(:add_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 42, r2: 58}}

      {_, state} = ThreeRegisters.execute(:add_32, program, state)
      # 42 + 58 = 100
      assert state.registers.r3 == 100
    end

    test "sub_32 performs subtraction" do
      program = <<op(:sub_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 100, r2: 58}}

      {_, state} = ThreeRegisters.execute(:sub_32, program, state)
      # 100 - 58 = 42
      assert state.registers.r3 == 42
    end

    test "mul_32 performs multiplication" do
      program = <<op(:mul_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 6, r2: 7}}

      {_, state} = ThreeRegisters.execute(:mul_32, program, state)
      # 6 * 7 = 42
      assert state.registers.r3 == 42
    end
  end

  describe "32-bit division operations" do
    test "div_u_32 performs unsigned division" do
      program = <<op(:div_u_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 100, r2: 20}}

      {_, state} = ThreeRegisters.execute(:div_u_32, program, state)
      # 100 / 20 = 5
      assert state.registers.r3 == 5
    end

    test "div_u_32 - mod(w_b, 2^32) is 0" do
      program = <<op(:div_u_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 100, r2: 1 <<< 32}}

      {_, state} = ThreeRegisters.execute(:div_u_32, program, state)
      # 100 / 2^64 = 0
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFF
    end

    test "rem_u_32 performs unsigned remainder" do
      program = <<op(:rem_u_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 42, r2: 10}}

      {_, state} = ThreeRegisters.execute(:rem_u_32, program, state)
      # 42 % 10 = 2
      assert state.registers.r3 == 2
    end

    test "rem_u_32 - mod(w_b, 2^32) is 0" do
      program = <<op(:rem_u_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 42, r2: 1 <<< 32}}

      {_, state} = ThreeRegisters.execute(:rem_u_32, program, state)
      # 42 % 2^32 = 42
      assert state.registers.r3 == 0x0000_0000_0000_002A
    end

    test "div_s_32 performs signed division" do
      program = <<op(:div_s_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFF_FF9C, r2: 20}}

      {_, state} = ThreeRegisters.execute(:div_s_32, program, state)
      # -5 as unsigned 64-bit
      assert state.registers.r3 == 0xFFFF_FFFF_FFFF_FFFB
    end

    test "rem_s_32 performs signed remainder" do
      program = <<op(:rem_s_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFD6, r2: 10}}

      {_, state} = ThreeRegisters.execute(:rem_s_32, program, state)
      # -2 as unsigned 64-bit
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFE
    end
  end

  describe "bitwise operations" do
    test "and performs bitwise AND" do
      program = <<op(:and), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0b1100, r2: 0b1010}}

      {_, state} = ThreeRegisters.execute(:and, program, state)
      assert state.registers.r3 == 0b1000
    end

    test "or performs bitwise OR" do
      program = <<op(:or), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0b1100, r2: 0b1010}}

      {_, state} = ThreeRegisters.execute(:or, program, state)
      assert state.registers.r3 == 0b1110
    end

    test "xor performs bitwise XOR" do
      program = <<op(:xor), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0b1100, r2: 0b1010}}

      {_, state} = ThreeRegisters.execute(:xor, program, state)
      assert state.registers.r3 == 0b0110
    end
  end

  describe "comparison operations" do
    test "set_lt_u performs unsigned less than comparison" do
      program = <<op(:set_lt_u), 0x21, 3>>
      state = %State{registers: %Registers{r1: 5, r2: 10}}

      {_, state} = ThreeRegisters.execute(:set_lt_u, program, state)
      # 5 < 10 -> true (1)
      assert state.registers.r3 == 1
    end

    test "set_lt_s performs signed less than comparison" do
      program = <<op(:set_lt_s), 0x21, 3>>
      state = %State{registers: %Registers{r1: -5, r2: 10}}

      {_, state} = ThreeRegisters.execute(:set_lt_s, program, state)
      # -5 < 10 -> true (1)
      assert state.registers.r3 == 1
    end
  end

  describe "conditional move operations" do
    test "cmov_iz moves if zero" do
      program = <<op(:cmov_iz), 0x21, 3>>
      state = %State{registers: %Registers{r1: 42, r2: 0, r3: 100}}

      {_, state} = ThreeRegisters.execute(:cmov_iz, program, state)
      # Should move 42 since condition is zero
      assert state.registers.r3 == 42
    end

    test "cmov_nz moves if not zero" do
      program = <<op(:cmov_nz), 0x21, 3>>
        state = %State{registers: %Registers{r1: 42, r2: 1, r3: 100}}

      {_, state} = ThreeRegisters.execute(:cmov_nz, program, state)
      # Should move 42 since condition is not zero
      assert state.registers.r3 == 42
    end
  end

  describe "64-bit arithmetic operations" do
    test "add_64 performs addition" do
      program = <<op(:add_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFF00000000, r2: 0x00000000FFFFFFFF}}

      {_, state} = ThreeRegisters.execute(:add_64, program, state)
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFF
    end

    test "sub_64 performs subtraction" do
      program = <<op(:sub_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFFFFFFFFF, r2: 0x0000000000000001}}

      {_, state} = ThreeRegisters.execute(:sub_64, program, state)
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFE
    end

    test "mul_64 performs multiplication" do
      program = <<op(:mul_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x100000000, r2: 0x100000000}}

      {_, state} = ThreeRegisters.execute(:mul_64, program, state)
      # Overflow in 64-bit
      assert state.registers.r3 == 0x0000000000000000
    end
  end

  describe "64-bit division operations" do
    test "div_u_64 performs unsigned division" do
      program = <<op(:div_u_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFFFFFFFFF, r2: 2}}

      {_, state} = ThreeRegisters.execute(:div_u_64, program, state)
      assert state.registers.r3 == 0x7FFFFFFFFFFFFFFF
    end

    test "div_u_64 - mod(w_b, 2^64) is 0" do
      program = <<op(:div_u_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFFFFFFFFF, r2: 1 <<< 64}}

      {_, state} = ThreeRegisters.execute(:div_u_64, program, state)
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFF
    end

    test "div_s_64 performs signed division" do
      program = <<op(:div_s_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: -0x8000000000000000, r2: 2}}

      {_, state} = ThreeRegisters.execute(:div_s_64, program, state)
      assert state.registers.r3 == 0xC000000000000000
    end

    test "rem_u_64 performs unsigned remainder" do
      program = <<op(:rem_u_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFFFFFFFFF, r2: 3}}

      {_, state} = ThreeRegisters.execute(:rem_u_64, program, state)
      assert state.registers.r3 == 0
    end

    test "rem_s_64 performs signed remainder" do
      program = <<op(:rem_s_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: -0x8000000000000000, r2: 3}}

      {_, state} = ThreeRegisters.execute(:rem_s_64, program, state)
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFE
    end
  end

  describe "shift operations" do
    test "shlo_l_32 performs logical left shift" do
      program = <<op(:shlo_l_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x1234_5678, r2: 4}}

      {_, state} = ThreeRegisters.execute(:shlo_l_32, program, state)
      assert state.registers.r3 == 0x2345_6780
    end

    test "shlo_r_32 performs logical right shift" do
      program = <<op(:shlo_r_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x1234_5678, r2: 4}}

      {_, state} = ThreeRegisters.execute(:shlo_r_32, program, state)
      assert state.registers.r3 == 0x0123_4567
    end

    test "shar_r_32 performs arithmetic right shift" do
      program = <<op(:shar_r_32), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xF234_5678, r2: 4}}

      {_, state} = ThreeRegisters.execute(:shar_r_32, program, state)
      assert state.registers.r3 == 0xFFFF_FFFF_F234_567
    end

    test "shlo_l_64 performs logical left shift" do
      program = <<op(:shlo_l_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 1, r2: 63}}

      {_, state} = ThreeRegisters.execute(:shlo_l_64, program, state)
      assert state.registers.r3 == 0x8000000000000000
    end

    test "shlo_r_64 performs logical right shift" do
      program = <<op(:shlo_r_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x8000000000000000, r2: 63}}

      {_, state} = ThreeRegisters.execute(:shlo_r_64, program, state)
      assert state.registers.r3 == 1
    end

    test "shar_r_64 performs arithmetic right shift" do
      program = <<op(:shar_r_64), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xF234567890ABCDEF, r2: 4}}

      {_, state} = ThreeRegisters.execute(:shar_r_64, program, state)
      assert state.registers.r3 == 0xFF234567890ABCDF
    end
  end

  describe "upper multiplication operations" do
    test "mul_upper_s_s performs signed-signed upper multiplication" do
      program = <<op(:mul_upper_s_s), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x8000000000000000, r2: 0x8000000000000000}}

      {_, state} = ThreeRegisters.execute(:mul_upper_s_s, program, state)
      assert state.registers.r3 == 0x4000000000000000
    end

    test "mul_upper_u_u performs unsigned-unsigned upper multiplication" do
      program = <<op(:mul_upper_u_u), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0xFFFFFFFFFFFFFFFF, r2: 0xFFFFFFFFFFFFFFFF}}

      {_, state} = ThreeRegisters.execute(:mul_upper_u_u, program, state)
      assert state.registers.r3 == 0xFFFFFFFFFFFFFFFE
    end

    test "mul_upper_s_u performs signed-unsigned upper multiplication" do
      program = <<op(:mul_upper_s_u), 0x21, 3>>
      state = %State{registers: %Registers{r1: 0x8000000000000000, r2: 0xFFFFFFFFFFFFFFFF}}

      {_, state} = ThreeRegisters.execute(:mul_upper_s_u, program, state)
      assert state.registers.r3 == 0x8000000000000001
    end
  end
end
