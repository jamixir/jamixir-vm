# defmodule MemoryTest do
#   use ExUnit.Case
#   alias PVM.Memory
#   import PVM.Memory.Constants

#   describe "basic operations" do
#     test "writes and reads a single byte" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address(), <<42>>)
#       assert Memory.read(memory, min_allowed_address(), 1) == {:ok, <<42>>}
#     end

#     test "writes and reads multiple bytes" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address() + 10, <<1, 2, 3, 4>>)
#       assert Memory.read(memory, min_allowed_address() + 10, 4) == {:ok, <<1, 2, 3, 4>>}
#     end

#     test "unwritten memory reads as zero" do
#       memory = %Memory{}
#       assert Memory.read(memory, min_allowed_address(), 4) == {:ok, <<0, 0, 0, 0>>}
#     end
#   end

#   describe "cross-page operations" do
#     test "writes across page boundary" do
#       memory = %Memory{}
#       # Write 8 bytes starting at last 4 bytes of first page
#       start_addr = page_size() - 4

#       {:ok, memory} =
#         Memory.write(memory, min_allowed_address() + start_addr, <<1, 2, 3, 4, 5, 6, 7, 8>>)

#       # Check first page
#       assert Memory.read(memory, min_allowed_address() + start_addr, 4) == {:ok, <<1, 2, 3, 4>>}
#       # Check second page
#       assert Memory.read(memory, min_allowed_address() + page_size(), 4) == {:ok, <<5, 6, 7, 8>>}
#       # Check continuous read across pages
#       assert Memory.read(memory, min_allowed_address() + start_addr, 8) ==
#                {:ok, <<1, 2, 3, 4, 5, 6, 7, 8>>}
#     end

#     test "reads across page boundary" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address() + page_size() - 2, <<1, 2>>)
#       {:ok, memory} = Memory.write(memory, min_allowed_address() + page_size(), <<3, 4>>)

#       assert Memory.read(memory, min_allowed_address() + page_size() - 2, 4) ==
#                {:ok, <<1, 2, 3, 4>>}
#     end

#     test "handles multi-byte read wrapping at 32-bit boundary" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address(), <<1, 2, 3, 4>>)

#       assert Memory.read(memory, min_allowed_address(), 4) == {:ok, <<1, 2, 3, 4>>}

#       # Read starting at (2^32 - 2), should wrap back to start
#       start_idx = memory_size() - 2
#       assert Memory.read(memory, min_allowed_address() + start_idx, 4) == {:error, :panic}
#     end

#     test "handles reads starting beyond memory size" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address(), <<1, 2>>)

#       # Read from index 3 (beyond memory size) should return zeros
#       assert Memory.read(memory, min_allowed_address() + 3, 2) == {:ok, <<0, 0>>}
#     end

#     test "handles sparse memory writes" do
#       memory = %Memory{}
#       {:ok, memory} = Memory.write(memory, min_allowed_address(), <<1, 2>>)
#       # 100MB offset
#       far_index = 100 * 1024 * 1024
#       {:ok, memory} = Memory.write(memory, min_allowed_address() + far_index, <<3, 4, 5>>)

#       assert Memory.read(memory, min_allowed_address(), 2) == {:ok, <<1, 2>>}
#       assert Memory.read(memory, min_allowed_address() + far_index, 3) == {:ok, <<3, 4, 5>>}
#       # Verify space between is zero-filled
#       assert Memory.read(memory, min_allowed_address() + 1000, 2) == {:ok, <<0, 0>>}
#     end
#   end

#   describe "permissions and faults" do
#     test "write fault returns page address" do
#       memory =
#         %Memory{}
#         # Make second page read-only
#         |> Memory.set_access(min_allowed_address() + page_size(), page_size(), :read)

#       write_addr = min_allowed_address() + page_size() + 10

#       result = Memory.write(memory, write_addr, <<42>>)
#       # Should return page-aligned address
#       zp = memory.page_size
#       assert result == {:error, {:fault, zp * div(write_addr, zp)}}
#     end

#     test "read fault returns page address" do
#       memory =
#         %Memory{}
#         # Make second page inaccessible
#         |> Memory.set_access(min_allowed_address() + page_size(), page_size(), nil)

#       read_addr = min_allowed_address() + page_size() + 10

#       result = Memory.read(memory, read_addr, 1)
#       # Should return page-aligned address
#       zp = memory.page_size
#       assert result == {:error, {:fault, zp * div(read_addr, zp)}}
#     end

#     test "cross-page operation fails if any page lacks permission" do
#       memory =
#         %Memory{}
#         # Make second page inaccessible
#         |> Memory.set_access(min_allowed_address() + page_size(), page_size(), nil)

#       # Write spanning pages 0 and 1
#       result = Memory.write(memory, min_allowed_address() + page_size() - 2, <<1, 2, 3, 4>>)
#       assert result == {:error, {:fault, min_allowed_address() + memory.page_size}}
#     end
#   end

#   describe "memory indices" do
#     # test "readable_indices returns correct pages" do
#     #   memory =
#     #     %Memory{}
#     #     |> Memory.set_access(0, page_size(), :read)
#     #     |> Memory.set_access(page_size() * 2, page_size(), :write)
#     #     |> Memory.set_access(page_size() * 3, page_size(), :read)

#     #   readable = Memory.readable_indices(memory)
#     #   assert MapSet.size(readable) == 3
#     #   assert MapSet.member?(readable, 0)
#     #   assert MapSet.member?(readable, 2)
#     #   assert MapSet.member?(readable, 3)
#     # end

#     # test "writeable_indices returns only writable pages" do
#     #   memory =
#     #     %Memory{}
#     #     |> Memory.set_access(0, page_size(), :read)
#     #     |> Memory.set_access(page_size() * 2, page_size(), :write)
#     #     |> Memory.set_access(page_size() * 3, page_size(), :write)

#     #   writeable = Memory.writeable_indices(memory)
#     #   assert MapSet.size(writeable) == 2
#     #   assert MapSet.member?(writeable, 2)
#     #   assert MapSet.member?(writeable, 3)
#     #   refute MapSet.member?(writeable, 0)
#     # end

#     # test "indices handle nil permissions correctly" do
#     #   memory =
#     #     %Memory{}
#     #     |> Memory.set_access(0, page_size(), nil)
#     #     |> Memory.set_access(page_size(), page_size(), :write)

#     #   readable = Memory.readable_indices(memory)
#     #   writeable = Memory.writeable_indices(memory)

#     #   assert MapSet.size(readable) == 1
#     #   assert MapSet.size(writeable) == 1
#     #   assert MapSet.member?(writeable, 1)
#     #   assert MapSet.member?(readable, 1)
#     #   refute MapSet.member?(readable, 0)
#     #   refute MapSet.member?(writeable, 0)
#     # end
#   end

#   describe "default permissions" do
#     test "changing default permission affects unset pages" do
#       memory =
#         %Memory{}
#         |> Memory.set_default_access(:read)

#       addr = min_allowed_address() + page_size() * 5

#       # Should succeed since default is now read
#       assert {:ok, _} = Memory.read(memory, addr, 4)

#       # Write should fail since default is read-only
#       assert {:error, {:fault, ^addr}} = Memory.write(memory, addr + 7, <<1, 2>>)

#       # Explicitly set pages should not be affected by default
#       memory = Memory.set_access(memory, min_allowed_address(), page_size(), :write)
#       assert {:ok, _} = Memory.write(memory, min_allowed_address(), <<1, 2>>)
#     end
#   end

#   describe "uninitialized memory" do
#     test "reading unwritten addresses returns zeros" do
#       memory = %Memory{}
#       addr = min_allowed_address() + div(page_size(), 2)

#       # Read from middle of first page
#       assert {:ok, <<0, 0, 0, 0>>} = Memory.read(memory, addr, 4)

#       # Read across unwritten pages
#       assert {:ok, <<0, 0, 0, 0>>} =
#                Memory.read(memory, min_allowed_address() + page_size() - 2, 4)
#     end
#   end

#   test "handles page permissions when access wraps memory" do
#     memory = %Memory{}
#     # Last two bytes of memory
#     wrap_addr = memory.size - 2

#     # Make last page read-only
#     memory = Memory.set_access(memory, wrap_addr, 1, :read)

#     # Try to write 4 bytes that wrap around (should fail due to read-only last page)
#     assert {:error, {:fault, fault_page}} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)
#     assert fault_page == page_size() * div(wrap_addr, page_size())

#     # Make first page read-only and last page writable
#     memory = Memory.set_access(memory, 0, 1, :read)
#     memory = Memory.set_access(memory, wrap_addr, 1, :write)

#     # Try to write 4 bytes that wrap around (should fail due to read-only first page)
#     assert {:error, {:fault, 0}} = Memory.write(memory, wrap_addr, <<1, 2, 3, 4>>)
#   end

#   describe "page-based operations" do
#     test "number_of_pages returns correct value" do
#       memory = %Memory{}
#       assert Memory.number_of_pages(memory) == div(memory_size(), page_size())
#     end

#     test "set_access_by_page handles basic case" do
#       min_page = div(min_allowed_address(), page_size())

#       memory =
#         %Memory{}
#         # Make first two pages read-only
#         |> Memory.set_access_by_page(min_page, 2, :read)

#       assert {:ok, _} = Memory.read(memory, min_allowed_address(), page_size() + 10)
#       assert {:error, {:fault, fault_addr}} = Memory.write(memory, min_allowed_address(), <<1>>)
#       assert fault_addr == min_page * page_size()

#       assert {:error, {:fault, fault_addr}} =
#                Memory.write(memory, min_allowed_address() + page_size() + 4, <<1>>)

#       assert fault_addr == (min_page + 1) * page_size()

#       # set just 1 page read-only
#       memory = %Memory{}
#       memory = Memory.set_access_by_page(memory, min_page, 1, :read)
#       assert {:ok, _} = Memory.read(memory, min_allowed_address(), 10)
#       assert {:ok, _} = Memory.write(memory, min_allowed_address() + page_size() + 4, <<1>>)
#       assert {:error, {:fault, fault_addr}} = Memory.write(memory, min_allowed_address(), <<1>>)
#       assert fault_addr == min_page * page_size()
#     end

#     test "check_pages_access validates permissions correctly" do
#       memory =
#         %Memory{}
#         # Make pages 1 and 2 read-only
#         |> Memory.set_access_by_page(1, 2, :read)

#       # Check single page
#       # Page 0 is writable
#       assert Memory.check_pages_access?(memory, 0, 1, :write)
#       # Page 1 is readable
#       assert Memory.check_pages_access?(memory, 1, 1, :read)
#       # Page 1 isn't writable
#       refute Memory.check_pages_access?(memory, 1, 1, :write)

#       # Check multiple pages
#       # Fails on page 1
#       refute Memory.check_pages_access?(memory, 0, 2, :write)
#     end

#   end

#   describe "bang (!) operations" do
#     test "write! and read! work for valid operations" do
#       memory = %Memory{}
#       memory = Memory.write!(memory, min_allowed_address(), <<42>>)
#       assert Memory.read!(memory, min_allowed_address(), 1) == <<42>>
#     end

#     test "write! raises error on fault" do
#       memory =
#         %Memory{}
#         |> Memory.set_access(min_allowed_address(), page_size(), :read)

#       error =
#         assert_raise(PVM.MemoryFaultError, fn ->
#           Memory.write!(memory, min_allowed_address(), <<42>>)
#         end)

#       assert %PVM.MemoryFaultError{reason: {:fault, page}} = error
#       assert page == min_allowed_address()
#     end

#     test "read! raises error on fault" do
#       memory =
#         %Memory{}
#         |> Memory.set_access(min_allowed_address(), page_size(), nil)

#       error =
#         assert_raise(PVM.MemoryFaultError, fn ->
#           Memory.read!(memory, min_allowed_address(), 1)
#         end)

#       assert %PVM.MemoryFaultError{reason: {:fault, page}} = error
#       assert page == min_allowed_address()
#     end
#   end
# end
