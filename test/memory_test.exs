defmodule MemoryTest do
  use ExUnit.Case
  import Bitwise

  # Constants matching Memory module
  @page_size 1 <<< 12      # 4KB pages
  @memory_size 1 <<< 32    # 4GB total size

  describe "basic operations" do
    test "writes and reads a single byte" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<42>>)
      assert Memory.read(memory, 0, 1) == {:ok,<<42>>}
    end

    test "writes and reads multiple bytes" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 10, <<1, 2, 3, 4>>)
      assert Memory.read(memory, 10, 4) == {:ok,<<1, 2, 3, 4>>}
    end

    test "unwritten memory reads as zero" do
      memory = %Memory{}
      assert Memory.read(memory, 0, 4) == {:ok,<<0, 0, 0, 0>>}
    end
  end

  describe "cross-page operations" do
    test "writes across page boundary" do
      memory = %Memory{}
      # Write 8 bytes starting at last 4 bytes of first page
      start_addr = @page_size - 4
      {:ok, memory} = Memory.write(memory, start_addr, <<1, 2, 3, 4, 5, 6, 7, 8>>)

      # Check first page
      assert Memory.read(memory, start_addr, 4) == {:ok,<<1, 2, 3, 4>>}
      # Check second page
      assert Memory.read(memory, @page_size, 4) == {:ok,<<5, 6, 7, 8>>}
      # Check continuous read across pages
      assert Memory.read(memory, start_addr, 8) == {:ok,<<1, 2, 3, 4, 5, 6, 7, 8>>}
    end

    test "reads across page boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, @page_size - 2, <<1, 2>>)
      {:ok, memory} = Memory.write(memory, @page_size, <<3, 4>>)
      assert Memory.read(memory, @page_size - 2, 4) == {:ok,<<1, 2, 3, 4>>}
    end

    test "handles multi-byte read wrapping at 32-bit boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      assert Memory.read(memory, 0, 4) == {:ok,<<1, 2, 3, 4>>}

      # Read starting at (2^32 - 2), should wrap back to start
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == {:ok,<<0, 0, 1, 2>>}
    end

    test "handles large reads across 32-bit boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      # Start at last byte before wrap, read 4 bytes
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == {:ok,<<0, 0, 1, 2>>}
    end

    test "handles reads starting beyond memory size" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2>>)

      # Read from index 3 (beyond memory size) should return zeros
      assert Memory.read(memory, 3, 2) == {:ok,<<0, 0>>}
    end

    test "handles sparse memory writes" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2>>)
      far_index = 100 * 1024 * 1024  # 100MB offset
      {:ok, memory} = Memory.write(memory, far_index, <<3, 4, 5>>)

      assert Memory.read(memory, 0, 2) == {:ok,<<1, 2>>}
      assert Memory.read(memory, far_index, 3) == {:ok,<<3, 4, 5>>}
      # Verify space between is zero-filled
      assert Memory.read(memory, 1000, 2) == {:ok,<<0, 0>>}
    end
  end

  describe "memory wrapping" do
    test "writes wrap at 4GB boundary" do
      memory = %Memory{}
      wrap_addr = @memory_size - 2  # Last two bytes of memory
      {:ok, memory} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)

      # Check end of memory
      assert Memory.read(memory, wrap_addr, 2) == {:ok,<<1, 2>>}
      # Check wrapped to start
      assert Memory.read(memory, 0, 2) == {:ok,<<3, 4>>}
      # Read across wrap boundary
      assert Memory.read(memory, wrap_addr, 4) == {:ok,<<1, 2, 3, 4>>}
    end

    test "large addresses wrap correctly" do
      memory = %Memory{}
      addr = @memory_size + 10  # Should wrap to address 10
      {:ok, memory} = Memory.write(memory, addr, <<42>>)
      assert Memory.read(memory, 10, 1) == {:ok,<<42>>}
    end
  end

  describe "permissions and faults" do
    test "write fault returns page address" do
      memory = %Memory{}
      |> Memory.set_access(@page_size, @page_size, :read)  # Make second page read-only

      result = Memory.write(memory, @page_size + 10, <<42>>)
      assert result == {:error, {:fault, 1}}  # Should return page-aligned address
    end

    test "read fault returns page address" do
      memory = %Memory{}
      |> Memory.set_access(@page_size, @page_size, nil)  # Make second page inaccessible

      result = Memory.read(memory, @page_size + 10, 1)
      assert result == {:error, {:fault, @page_size}}  # Should return page-aligned address
    end

    test "cross-page operation fails if any page lacks permission" do
      memory = %Memory{}
      |> Memory.set_access(@page_size, @page_size, nil)  # Make second page inaccessible

      # Write spanning pages 0 and 1
      result = Memory.write(memory, @page_size - 2, <<1, 2, 3, 4>>)
      assert result == {:error, {:fault, 1}}
    end
  end

  describe "memory indices" do
    test "readable_indices returns correct pages" do
      memory = %Memory{}
      |> Memory.set_access(0, @page_size, :read)
      |> Memory.set_access(@page_size * 2, @page_size, :write)
      |> Memory.set_access(@page_size * 3, @page_size, :read)

      readable = Memory.readable_indices(memory)
      assert MapSet.size(readable) == 3
      assert MapSet.member?(readable, 0)
      assert MapSet.member?(readable, 2)
      assert MapSet.member?(readable, 3)
    end

    test "writeable_indices returns only writable pages" do
      memory = %Memory{}
      |> Memory.set_access(0, @page_size, :read)
      |> Memory.set_access(@page_size * 2, @page_size, :write)
      |> Memory.set_access(@page_size * 3, @page_size, :write)

      writeable = Memory.writeable_indices(memory)
      assert MapSet.size(writeable) == 2
      assert MapSet.member?(writeable, 2)
      assert MapSet.member?(writeable, 3)
      refute MapSet.member?(writeable, 0)
    end

    test "indices handle nil permissions correctly" do
      memory = %Memory{}
      |> Memory.set_access(0, @page_size, nil)
      |> Memory.set_access(@page_size, @page_size, :write)

      readable = Memory.readable_indices(memory)
      writeable = Memory.writeable_indices(memory)

      assert MapSet.size(readable) == 1
      assert MapSet.size(writeable) == 1
      assert MapSet.member?(writeable, 1)
      assert MapSet.member?(readable, 1)
      refute MapSet.member?(readable, 0)
      refute MapSet.member?(writeable, 0)
    end
  end
end
