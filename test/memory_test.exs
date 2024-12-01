defmodule MemoryTest do
  use ExUnit.Case
  import Bitwise
  alias PVM.Memory

  # Constants matching Memory module
  # 4KB pages
  @page_size 1 <<< 12
  # 4GB total size
  @memory_size 1 <<< 32

  describe "basic operations" do
    test "writes and reads a single byte" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<42>>)
      assert Memory.read(memory, 0, 1) == {:ok, <<42>>}
    end

    test "writes and reads multiple bytes" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 10, <<1, 2, 3, 4>>)
      assert Memory.read(memory, 10, 4) == {:ok, <<1, 2, 3, 4>>}
    end

    test "unwritten memory reads as zero" do
      memory = %Memory{}
      assert Memory.read(memory, 0, 4) == {:ok, <<0, 0, 0, 0>>}
    end
  end

  describe "cross-page operations" do
    test "writes across page boundary" do
      memory = %Memory{}
      # Write 8 bytes starting at last 4 bytes of first page
      start_addr = @page_size - 4
      {:ok, memory} = Memory.write(memory, start_addr, <<1, 2, 3, 4, 5, 6, 7, 8>>)

      # Check first page
      assert Memory.read(memory, start_addr, 4) == {:ok, <<1, 2, 3, 4>>}
      # Check second page
      assert Memory.read(memory, @page_size, 4) == {:ok, <<5, 6, 7, 8>>}
      # Check continuous read across pages
      assert Memory.read(memory, start_addr, 8) == {:ok, <<1, 2, 3, 4, 5, 6, 7, 8>>}
    end

    test "reads across page boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, @page_size - 2, <<1, 2>>)
      {:ok, memory} = Memory.write(memory, @page_size, <<3, 4>>)
      assert Memory.read(memory, @page_size - 2, 4) == {:ok, <<1, 2, 3, 4>>}
    end

    test "handles multi-byte read wrapping at 32-bit boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      assert Memory.read(memory, 0, 4) == {:ok, <<1, 2, 3, 4>>}

      # Read starting at (2^32 - 2), should wrap back to start
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == {:ok, <<0, 0, 1, 2>>}
    end

    test "handles large reads across 32-bit boundary" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2, 3, 4>>)

      # Start at last byte before wrap, read 4 bytes
      start_idx = (1 <<< 32) - 2
      assert Memory.read(memory, start_idx, 4) == {:ok, <<0, 0, 1, 2>>}
    end

    test "handles reads starting beyond memory size" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2>>)

      # Read from index 3 (beyond memory size) should return zeros
      assert Memory.read(memory, 3, 2) == {:ok, <<0, 0>>}
    end

    test "handles sparse memory writes" do
      memory = %Memory{}
      {:ok, memory} = Memory.write(memory, 0, <<1, 2>>)
      # 100MB offset
      far_index = 100 * 1024 * 1024
      {:ok, memory} = Memory.write(memory, far_index, <<3, 4, 5>>)

      assert Memory.read(memory, 0, 2) == {:ok, <<1, 2>>}
      assert Memory.read(memory, far_index, 3) == {:ok, <<3, 4, 5>>}
      # Verify space between is zero-filled
      assert Memory.read(memory, 1000, 2) == {:ok, <<0, 0>>}
    end
  end

  describe "memory wrapping" do
    test "writes wrap at 4GB boundary" do
      memory = %Memory{}
      # Last two bytes of memory
      wrap_addr = @memory_size - 2
      {:ok, memory} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)

      # Check end of memory
      assert Memory.read(memory, wrap_addr, 2) == {:ok, <<1, 2>>}
      # Check wrapped to start
      assert Memory.read(memory, 0, 2) == {:ok, <<3, 4>>}
      # Read across wrap boundary
      assert Memory.read(memory, wrap_addr, 4) == {:ok, <<1, 2, 3, 4>>}
    end

    test "large addresses wrap correctly" do
      memory = %Memory{}
      # Should wrap to address 10
      addr = @memory_size + 10
      {:ok, memory} = Memory.write(memory, addr, <<42>>)
      assert Memory.read(memory, 10, 1) == {:ok, <<42>>}
    end
  end

  describe "permissions and faults" do
    test "write fault returns page address" do
      memory =
        %Memory{}
        # Make second page read-only
        |> Memory.set_access(@page_size, @page_size, :read)

      result = Memory.write(memory, @page_size + 10, <<42>>)
      # Should return page-aligned address
      assert result == {:error, {:fault, 1}}
    end

    test "read fault returns page address" do
      memory =
        %Memory{}
        # Make second page inaccessible
        |> Memory.set_access(@page_size, @page_size, nil)

      result = Memory.read(memory, @page_size + 10, 1)
      # Should return page-aligned address
      assert result == {:error, {:fault, 1}}
    end

    test "cross-page operation fails if any page lacks permission" do
      memory =
        %Memory{}
        # Make second page inaccessible
        |> Memory.set_access(@page_size, @page_size, nil)

      # Write spanning pages 0 and 1
      result = Memory.write(memory, @page_size - 2, <<1, 2, 3, 4>>)
      assert result == {:error, {:fault, 1}}
    end
  end

  describe "memory indices" do
    test "readable_indices returns correct pages" do
      memory =
        %Memory{}
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
      memory =
        %Memory{}
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
      memory =
        %Memory{}
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

  describe "default permissions" do
    test "changing default permission affects unset pages" do
      memory =
        %Memory{}
        |> Memory.set_default_access(:read)

      # Should succeed since default is now read
      assert {:ok, _} = Memory.read(memory, @page_size * 5, 4)

      # Write should fail since default is read-only
      assert {:error, {:fault, 5}} = Memory.write(memory, @page_size * 5, <<1, 2>>)

      # Explicitly set pages should not be affected by default
      memory = Memory.set_access(memory, 0, @page_size, :write)
      assert {:ok, _} = Memory.write(memory, 0, <<1, 2>>)
    end
  end

  describe "uninitialized memory" do
    test "reading unwritten addresses returns zeros" do
      memory = %Memory{}

      # Read from middle of first page
      assert {:ok, <<0, 0, 0, 0>>} = Memory.read(memory, @page_size >>> 1, 4)

      # Read across unwritten pages
      assert {:ok, <<0, 0, 0, 0>>} = Memory.read(memory, @page_size - 2, 4)
    end
  end

  describe "page size changes" do
    test "changing page size preserves access permissions correctly" do
      original_page_size = @page_size
      double_page_size = @page_size * 2

      # Set up initial memory with double page size
      memory =
        %Memory{}
        |> Memory.set_page_size(double_page_size)
        # Make first two double-pages read-only
        |> Memory.set_access(0, double_page_size * 2, :read)

      # Change to original page size
      memory = Memory.set_page_size(memory, original_page_size)

      # Set middle page to no access and last page to write
      memory =
        memory
        |> Memory.set_access(original_page_size, original_page_size, nil)
        |> Memory.set_access(original_page_size * 2, original_page_size, :write)

      # Test boundaries
      # First page should be read-only
      assert {:ok, _} = Memory.read(memory, 0, 4)
      assert {:error, {:fault, 0}} = Memory.write(memory, 0, <<1>>)

      # Middle page should have no access
      assert {:error, {:fault, 1}} = Memory.read(memory, original_page_size + 4, 4)
      assert {:error, {:fault, 1}} = Memory.write(memory, original_page_size + 4, <<1>>)

      # Last page should be writable
      assert {:ok, _} = Memory.read(memory, original_page_size * 2 + 4, 4)
      assert {:ok, _} = Memory.write(memory, original_page_size * 2 + 4, <<1>>)
    end

    test "page size changes handle boundary conditions" do
      memory =
        %Memory{}
        # Start with double page size
        |> Memory.set_page_size(@page_size * 2)

      # Write some data across what will be a future page boundary
      {:ok, memory} = Memory.write(memory, @page_size - 2, <<1, 2, 3, 4>>)

      # Now change permissions to read-only
      memory =
        memory
        |> Memory.set_access(0, @page_size * 4, :read)

      # Change to smaller page size
      memory = Memory.set_page_size(memory, @page_size)

      # Verify permissions were correctly split
      # First page readable
      assert {:ok, _} = Memory.read(memory, 0, 4)
      # Second page readable
      assert {:ok, _} = Memory.read(memory, @page_size, 4)

      # Verify data remained intact across the boundary
      assert {:ok, <<1, 2, 3, 4>>} = Memory.read(memory, @page_size - 2, 4)

      # Verify we can't write to the pages anymore
      assert {:error, {:fault, 0}} = Memory.write(memory, 0, <<1>>)
      assert {:error, {:fault, 1}} = Memory.write(memory, @page_size, <<1>>)
    end
  end

  test "handles page permissions when access wraps memory" do
    memory = %Memory{}
    # Last two bytes of memory
    wrap_addr = Memory.memory_size() - 2

    # Make last page read-only
    memory = Memory.set_access(memory, wrap_addr, 1, :read)

    # Try to write 4 bytes that wrap around (should fail due to read-only last page)
    assert {:error, {:fault, fault_page}} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)
    assert fault_page == div(wrap_addr, @page_size)

    # Make first page read-only and last page writable
    memory = Memory.set_access(memory, 0, 1, :read)
    memory = Memory.set_access(memory, wrap_addr, 1, :write)

    # Try to write 4 bytes that wrap around (should fail due to read-only first page)
    assert {:error, {:fault, 0}} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)
  end

  describe "page-based operations" do
    test "number_of_pages returns correct value" do
      memory = %Memory{}
      assert Memory.number_of_pages(memory) == div(@memory_size, @page_size)

      # Test with modified page size
      memory = Memory.set_page_size(memory, @page_size * 2)
      assert Memory.number_of_pages(memory) == div(@memory_size, @page_size * 2)
    end

    test "set_access_by_page handles basic case" do
      memory =
        %Memory{}
        # Make first two pages read-only
        |> Memory.set_access_by_page(0, 2, :read)

      assert {:ok, _} = Memory.read(memory, 0, @page_size + 10)
      assert {:error, {:fault, 0}} = Memory.write(memory, 0, <<1>>)
      assert {:error, {:fault, 1}} = Memory.write(memory, @page_size + 4, <<1>>)

      # set just 1 page read-only
      memory = %Memory{}
      memory = Memory.set_access_by_page(memory, 0, 1, :read)
      assert {:ok, _} = Memory.read(memory, 0, 10)
      assert {:ok, _} = Memory.write(memory, @page_size + 4, <<1>>)
      assert {:error, {:fault, 0}} = Memory.write(memory, 0, <<1>>)
    end

    test "set_access_by_page handles wrapping" do
      memory = %Memory{}
      last_page = Memory.number_of_pages(memory) - 1

      # Set permissions wrapping from last page to first page
      memory = Memory.set_access_by_page(memory, last_page, 2, :read)

      # Check last page
      assert {:ok, _} = Memory.read(memory, @memory_size - @page_size, 4)

      assert {:error, {:fault, ^last_page}} =
               Memory.write(memory, @memory_size - @page_size, <<1>>)

      # Check wrapped to first page
      assert {:ok, _} = Memory.read(memory, 0, 4)
      assert {:error, {:fault, 0}} = Memory.write(memory, 0, <<1>>)
    end

    test "check_pages_access validates permissions correctly" do
      memory =
        %Memory{}
        # Make pages 1 and 2 read-only
        |> Memory.set_access_by_page(1, 2, :read)

      # Check single page
      # Page 0 is writable
      assert :ok = Memory.check_pages_access(memory, 0, 1, :write)
      # Page 1 is readable
      assert :ok = Memory.check_pages_access(memory, 1, 1, :read)
      # Page 1 isn't writable
      assert {:error, 1} = Memory.check_pages_access(memory, 1, 1, :write)

      # Check multiple pages
      # Fails on page 1
      assert {:error, 1} = Memory.check_pages_access(memory, 0, 2, :write)
    end

    test "check_pages_access handles wrapping" do
      memory = %Memory{}
      total_pages = Memory.number_of_pages(memory)
      last_page = total_pages - 1

      # Set last and first page read-only
      memory = Memory.set_access_by_page(memory, last_page, 2, :read)

      # Check wrap-around access
      assert {:error, last_page} =
               Memory.check_pages_access(memory, last_page, 2, :write)

      assert :ok = Memory.check_pages_access(memory, last_page, 2, :read)
    end

    test "set_access_by_page handles wrap of first page" do
      memory = %Memory{}
      total_pages = Memory.number_of_pages(memory)


      # should set pages 1,2,3 to read-only
      memory = Memory.set_access_by_page(memory, total_pages + 1, 3, :read)
      assert {:ok, _} = Memory.read(memory, @page_size, 10)
      assert {:error, {:fault, 1}} = Memory.write(memory, @page_size, <<1>>)
      assert {:ok, _} = Memory.read(memory, @page_size * 2, 10)
      assert {:error, {:fault, 2}} = Memory.write(memory, @page_size * 2, <<1>>)
      assert {:ok, _} = Memory.read(memory, @page_size * 3, 10)
      assert {:error, {:fault, 3}} = Memory.write(memory, @page_size * 3, <<1>>)
    end
  end
end
