defmodule MemoryTest do
  use ExUnit.Case
  import Bitwise
  doctest Memory

  describe "Memory" do
    test "creates new empty memory" do
      assert Memory.new() == %Memory{data: <<>>, access: %{}}
    end

    test "writes and reads a single byte" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<42>>)
      assert Memory.read(memory, 0, 1) == <<42>>
    end

    test "writes and reads multiple bytes" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2, 3>>)
      assert Memory.read(memory, 0, 3) == <<1, 2, 3>>
    end

    test "writes to non-zero index" do
      memory = Memory.new()
      memory = Memory.write(memory, 2, <<42>>)
      assert Memory.read(memory, 0, 3) == <<0, 0, 42>>
    end

    test "handles reads beyond written memory" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2>>)
      assert Memory.read(memory, 2, 2) == <<0, 0>>
    end

    test "handles index wrapping (32-bit)" do
      memory = Memory.new()
      # Should wrap to index 5
      big_index = 5 + (1 <<< 32)
      memory = Memory.write(memory, big_index, <<42>>)
      assert Memory.read(memory, 5, 1) == <<42>>
    end

    test "overwrites existing data" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2, 3>>)
      memory = Memory.write(memory, 1, <<99>>)
      assert Memory.read(memory, 0, 3) == <<1, 99, 3>>
    end

    test "handles multi-byte read wrapping at 32-bit boundary" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      assert Memory.read(memory, 0, 4) == <<1, 2, 3, 4>>

      # Read starting at (2^32 - 2), should wrap back to start
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == <<0, 0, 1, 2>>
    end

    test "handles large reads across 32-bit boundary" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      # Start at last byte before wrap, read 4 bytes
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == <<0, 0, 1, 2>>
    end

    test "handles reads starting beyond memory size" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2>>)

      # Read from index 3 (beyond memory size) should return zeros
      assert Memory.read(memory, 3, 2) == <<0, 0>>
    end

    test "handles sparse memory writes" do
      memory = Memory.new()
      memory = Memory.write(memory, 0, <<1, 2>>)
      far_index = 100 * 1024 * 1024  # 100MB offset
      memory = Memory.write(memory, far_index, <<3, 4, 5>>)

      assert Memory.read(memory, 0, 2) == <<1, 2>>
      assert Memory.read(memory, far_index, 3) == <<3, 4, 5>>
      # Verify space between is zero-filled
      assert Memory.read(memory, 1000, 2) == <<0, 0>>
    end
  end

  describe "Memory access permissions" do


    test "write fails on read-only memory" do
      memory =
        Memory.new()
        |> Memory.set_access(1, 1, :read)

      assert Memory.write(memory, 1, <<42>>) == {:error, {:fault, 1}}
      assert Memory.write(memory, 0, <<42>>) != {:error, {:fault, 0}}
    end

    test "read succeeds with read or write permission" do
      memory =
        Memory.new()
        |> Memory.write(0, <<1, 2, 3>>)
        |> Memory.set_access(1, 1, :read)

      assert Memory.read(memory, 0, 3) == <<1, 2, 3>>
    end

    test "read fails on nil permission" do
      memory =
        Memory.new()
        |> Memory.write(0, <<1, 2, 3>>)
        |> Memory.set_access(1, 1, nil)

      assert Memory.read(memory, 1, 1) == {:error, {:fault, 1}}
    end
  end
end
