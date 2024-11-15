defmodule MemoryTest do
  use ExUnit.Case
  import Bitwise
  doctest Memory

  describe "Memory" do
    test "creates new empty memory" do
      assert Memory.new() == %Memory{data: <<>>, access: %{}}
    end

    test "writes and reads a single byte" do
      memory = Memory.new(1)
      memory = Memory.write(memory, 0, <<42>>)
      assert Memory.read(memory, 0, 1) == <<42>>
    end

    test "writes and reads multiple bytes" do
      memory = Memory.new(3)
      memory = Memory.write(memory, 0, <<1, 2, 3>>)
      assert Memory.read(memory, 0, 3) == <<1, 2, 3>>
    end

    test "writes to non-zero index" do
      memory = Memory.new(3)
      memory = Memory.write(memory, 2, <<42>>)
      assert Memory.read(memory, 0, 3) == <<0, 0, 42>>
    end

    test "handles reads beyond written memory" do
      memory = Memory.new(4)
      memory = Memory.write(memory, 0, <<1, 2>>)
      assert Memory.read(memory, 2, 2) == <<0, 0>>
    end

    test "handles index wrapping (32-bit)" do
      memory = Memory.new(6)
      big_index = 5 + (1 <<< 32)  # Should wrap to index 5
      memory = Memory.write(memory, big_index, <<42>>)
      assert Memory.read(memory, 5, 1) == <<42>>
    end

    test "overwrites existing data" do
      memory = Memory.new(3)
      memory = Memory.write(memory, 0, <<1, 2, 3>>)
      memory = Memory.write(memory, 1, <<99>>)
      assert Memory.read(memory, 0, 3) == <<1, 99, 3>>
    end
  end

  describe "Memory access permissions" do
    test "initializes memory with write permissions" do
      memory = Memory.new(3)
      assert Memory.valid_indices(memory) == [0, 1, 2]
      assert Memory.write_only_indices(memory) == [0, 1, 2]
    end

    test "set_access changes permissions correctly" do
      memory = Memory.new(4)
      |> Memory.set_access(1, 2, :read)

      assert Memory.write_only_indices(memory) == [0, 3]
      assert Memory.valid_indices(memory) == [0, 1, 2, 3]
    end

    test "write fails on read-only memory" do
      memory = Memory.new(3)
      |> Memory.set_access(1, 1, :read)

      assert Memory.write(memory, 1, <<42>>) == {:error, {:fault, 1}}
      assert Memory.write(memory, 0, <<42>>) != {:error, {:fault, 0}}
    end

    test "read succeeds with read or write permission" do
      memory = Memory.new(3)
      |> Memory.write(0, <<1, 2, 3>>)
      |> Memory.set_access(1, 1, :read)

      assert Memory.read(memory, 0, 3) == <<1, 2, 3>>
    end

    test "read fails on nil permission" do
      memory = Memory.new(3)
      |> Memory.write(0, <<1, 2, 3>>)
      |> Memory.set_access(1, 1, nil)

      assert Memory.read(memory, 1, 1) == {:error, {:fault, 1}}
    end
  end
end
