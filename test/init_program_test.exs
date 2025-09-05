defmodule PVM.InitProgramTest do
  use ExUnit.Case
  alias PVM.{InitProgram, Memory, Registers}
  import Bitwise

  describe "parse_program_segments/1" do
    test "successfully parses valid program segments" do
      # Create a valid binary with:
      # o_size = 1, w_size = 1, z = 1, s = 1
      # o = "A", w = "B", c_size = 1, c = "C"
      binary = <<
        # o_size (3 bytes)
        1,
        0,
        0,
        # w_size (3 bytes)
        1,
        0,
        0,
        # z (2 bytes)
        1,
        0,
        # s (3 bytes)
        1,
        0,
        0,
        # o (1 byte)
        ?A,
        # w (1 byte)
        ?B,
        # c_size (4 bytes)
        1,
        0,
        0,
        0,
        # c (1 byte)
        ?C
      >>

      assert {:ok, {o_size, o, w_size, w, z, s, c}} = InitProgram.parse_program_segments(binary)
      assert o_size == 1
      assert o == "A"
      assert w_size == 1
      assert w == "B"
      assert z == 1
      assert s == 1
      assert c == "C"
    end

    test "fails when binary is too short (minimum 15 bytes required)" do
      binary = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14>>
      assert {:error, :insufficient_bytes} = InitProgram.parse_program_segments(binary)
    end

    test "fails when sizes don't match (too small, leftover binary)" do
      # Setting o_size = 1 but providing 2 bytes for o
      binary = <<
        # o_size (3 bytes)
        1,
        0,
        0,
        # w_size (3 bytes)
        1,
        0,
        0,
        # z (2 bytes)
        1,
        0,
        # s (3 bytes)
        1,
        0,
        0,
        # o (2 bytes, but size was 1)
        ?A,
        ?B,
        # w (1 byte)
        ?C,
        # c_size (4 bytes)
        1,
        0,
        0,
        0,
        # c (1 byte)
        ?D
      >>

      assert {:error, :invalid_format} = InitProgram.parse_program_segments(binary)
    end

    test "fails when sizes don't match (too big, runs out of binary)" do
      # Setting o_size = 2 but providing only 1 byte for o
      binary = <<
        # o_size (3 bytes)
        2,
        0,
        0,
        # w_size (3 bytes)
        1,
        0,
        0,
        # z (2 bytes)
        1,
        0,
        # s (3 bytes)
        1,
        0,
        0,
        # o (1 byte, but size was 2)
        ?A,
        # w (1 byte)
        ?B,
        # c_size (4 bytes)
        1,
        0,
        0,
        0,
        # c (1 byte)
        ?C
      >>

      assert {:error, :invalid_format} = InitProgram.parse_program_segments(binary)
    end

    test "succeeds when all sizes are 0 but still requires minimum binary length" do
      binary = <<
        # o_size
        0,
        0,
        0,
        # w_size
        0,
        0,
        0,
        # z
        0,
        0,
        # s
        0,
        0,
        0,
        # c_size
        0,
        0,
        0,
        0
      >>

      assert {:ok, {o_size, o, w_size, w, z, s, c}} = InitProgram.parse_program_segments(binary)
      assert o_size == 0
      assert o == ""
      assert w_size == 0
      assert w == ""
      assert z == 0
      assert s == 0
      assert c == ""
    end

    test "fails when o_size is larger than remaining binary" do
      binary = <<
        # o_size = 8 (too big)
        8,
        0,
        0,
        # w_size
        1,
        0,
        0,
        # z
        1,
        0,
        # s
        1,
        0,
        0,
        # o
        ?A,
        ?B,
        ?C,
        # w
        ?D,
        ?F,
        # c_size
        0,
        0,
        0,
        2,
        # c
        ?G,
        ?G
      >>

      assert {:error, :invalid_format} = InitProgram.parse_program_segments(binary)
    end
  end

  describe "verify_size_constraint/4" do
    test "accepts valid small sizes" do
      assert InitProgram.verify_size_constraint(1, 1, 1, 1) == true
    end

    test "accepts zero sizes" do
      assert InitProgram.verify_size_constraint(0, 0, 0, 0) == true
    end

    test "rejects when o_size is too large" do
      # Using a size close to 2^32 to force overflow
      huge_size = 1 <<< 32
      assert InitProgram.verify_size_constraint(huge_size, 1, 1, 1) == false
    end

    test "rejects when combined w_size and z calculation is too large" do
      # Make w_size + z * Zp overflow
      # Large z value
      z = 1 <<< 20
      # Large w_size
      w_size = 1 <<< 20
      assert InitProgram.verify_size_constraint(1, w_size, z, 1) == false
    end

    test "rejects when s is too large" do
      huge_s = 1 <<< 32
      assert InitProgram.verify_size_constraint(1, 1, 1, huge_s) == false
    end

    test "accepts values just under the limit" do
      # Calculate maximum allowed values that should still pass
      max_safe = (1 <<< 32) - 5 * (1 <<< 16) - (1 <<< 24)
      # Divide by 4 to split among components
      safe_size = max_safe >>> 2

      assert InitProgram.verify_size_constraint(
               # o_size
               safe_size,
               # w_size
               safe_size,
               # z (small to avoid multiplication overflow)
               1,
               # s
               safe_size
             ) == true
    end
  end

  describe "construct_memory/5" do
    test "correctly sets up basic memory layout" do
      # 4 bytes
      o = "code"
      # 4 bytes
      w = "data"
      # 4 bytes
      c = "args"
      z = 1
      s = 1

      memory = InitProgram.construct_memory(o, w, c, z, s)

      # Test o segment (read-only)
      assert {:ok, "code"} = Memory.read(memory, InitProgram.zz(), 4)
      assert {:error, {:fault, _}} = Memory.write(memory, InitProgram.zz(), "fail")

      # Test w segment (writable)
      w_start = 2 * InitProgram.zz() + InitProgram.z(byte_size(o))
      assert {:ok, "data"} = Memory.read(memory, w_start, 4)
      assert {:ok, _} = Memory.write(memory, w_start, "test")

      # Test arguments (read-only)
      args_start = InitProgram.max_addr() - InitProgram.zz() - InitProgram.zi()
      assert {:ok, "args"} = Memory.read(memory, args_start, 4)
      assert {:error, {:fault, _}} = Memory.write(memory, args_start, "fail")
    end

    test "correctly handles padding regions" do
      # 1 byte
      o = "a"
      # 1 byte
      w = "b"
      # 1 byte
      c = "c"
      z = 1
      s = 1

      memory = InitProgram.construct_memory(o, w, c, z, s)

      # Test padding after o (should be readable zeros)
      o_end = InitProgram.zz() + 1
      # p(1) minus the single byte
      padding_size = InitProgram.p(1) - 1
      assert {:ok, padding} = Memory.read(memory, o_end, padding_size)
      assert padding == :binary.copy(<<0>>, padding_size)
      assert {:error, {:fault, _}} = Memory.write(memory, o_end, "x")

      # Test padding after w (should be writable zeros)
      w_start = 2 * InitProgram.zz() + InitProgram.z(1)
      w_end = w_start + 1
      w_padding_size = InitProgram.p(1) - 1
      assert {:ok, w_padding} = Memory.read(memory, w_end, w_padding_size)
      assert w_padding == :binary.copy(<<0>>, w_padding_size)
      assert {:ok, _} = Memory.write(memory, w_end, <<0>>)
    end

    test "correctly sets up inaccessible regions" do
      o = "code"
      w = "data"
      c = "args"
      z = 1
      s = 1

      memory = InitProgram.construct_memory(o, w, c, z, s)

      # Test gap between segments (should be inaccessible)
      gap_start = InitProgram.zz() + InitProgram.p(byte_size(o))
      gap_end = 2 * InitProgram.zz() + InitProgram.z(byte_size(o))
      assert {:error, {:fault, _}} = Memory.read(memory, gap_start, gap_end - gap_start)
    end

    test "respects z parameter for work area size" do
      o = "a"
      w = "b"
      c = "c"
      # Request 2 pages of work area
      z = 2
      s = 1

      memory = InitProgram.construct_memory(o, w, c, z, s)

      # Calculate where work area starts
      w_start = 2 * InitProgram.zz() + InitProgram.z(1)

      # Should be able to write across the entire work area
      work_area_size = InitProgram.p(1) + 2 * InitProgram.zp()
      test_data = :binary.copy(<<1>>, work_area_size)
      assert {:ok, _} = Memory.write(memory, w_start, test_data)
    end
  end

  describe "initialize_registers/1" do
    test "initializes registers with correct values" do
      registers = InitProgram.initialize_registers(<<1, 2, 3, 4>>)

      # Check specific registers that should have predefined values (A.35)
      assert Registers.get(registers, [0, 1, 7, 8]) == [
               0xFFFF_0000,
               0xFEFE_0000,
               0xFEFF_0000,
               4
      ]

      # Check that other registers are initialized to 0
      assert Registers.get(registers, [2, 3, 4, 5, 6, 9, 10, 11, 12]) == [
               0,
               0,
               0,
               0,
               0,
               0,
               0,
               0,
               0
             ]
    end
  end

  describe "initialize_program/2" do
    test "successfully initializes program with valid input" do
      # Create a valid program binary (8KB segments)
      page_size = 4096
      # "A" repeated for 8KB
      test_pattern = :binary.copy(<<65>>, 2 * page_size)

      binary = <<
        # o_size (3 bytes)
        2 * page_size::little-size(24),
        # w_size (3 bytes)
        2 * page_size::little-size(24),
        # z (2 bytes)
        1::little-size(16),
        # s (3 bytes)
        1::little-size(24),
        # o (8KB)
        test_pattern::binary,
        # w (8KB)
        test_pattern::binary,
        # c_size (4 bytes)
        2 * page_size::little-size(32),
        # c (8KB)
        test_pattern::binary
      >>

      # "B" repeated for 8KB
      args = :binary.copy(<<66>>, 2 * page_size)

      assert {code, registers, memory} = InitProgram.initialize_program(binary, args)

      # Verify we got valid components back
      assert byte_size(code) == 2 * page_size
      assert %PVM.Registers{} = registers
      assert is_struct(memory, Memory)
    end

    test "returns nil for invalid program" do
      # Create an invalid program (sizes too large)
      binary = <<
        # o_size (too large)
        0xFF,
        0xFF,
        0xFF,
        # w_size
        1,
        0,
        0,
        # z
        1,
        0,
        # s
        1,
        0,
        0,
        # o
        65,
        # w
        66,
        # c_size
        1,
        0,
        0,
        0,
        # c
        67
      >>

      args = "test"
      assert InitProgram.initialize_program(binary, args) == nil
    end

    test "returns nil for invalid size constraints" do
      # Create a program that would violate A.33
      # Very large size that should violate constraints
      huge_size = 1 <<< 30

      binary = <<
        # o_size
        huge_size::little-size(24),
        # w_size
        1::little-size(24),
        # z
        1::little-size(16),
        # s
        1::little-size(24),
        # o
        65,
        # w
        66,
        # c_size
        1::little-size(32),
        # c
        67
      >>

      args = "test"
      assert InitProgram.initialize_program(binary, args) == nil
    end
  end
end
