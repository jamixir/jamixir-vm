defmodule PVM.PreMemoryTest do
  use ExUnit.Case
  alias PVM.{PreMemory, Memory}
  import PVM.Memory.Constants

  setup_all do
    min_page = min_page()
    max_page = max_page()

    {:ok, %{min_page: min_page, max_page: max_page}}
  end

  describe "basic operations" do
    test "initializes with empty data and access ranges" do
      pre_memory = %PreMemory{}
      assert pre_memory.data == %{}
      assert pre_memory.access_ranges == []
      assert pre_memory.page_size == page_size()
      assert pre_memory.size == memory_size()
    end

    test "init_nil_memory sets entire memory to nil access", %{
      min_page: min_page,
      max_page: max_page
    } do
      assert [{^min_page, ^max_page, nil}] = PreMemory.init_nil_memory().access_ranges
    end

    test "write adds data to the sparse memory structure" do
      pre_memory = %PreMemory{}
      address = min_allowed_address()
      value = <<1, 2, 3, 4>>

      updated = PreMemory.write(pre_memory, address, value)

      # Check that data was properly stored in the sparse structure
      page_num = div(address, page_size())
      assert Map.has_key?(updated.data, page_num)

      page = updated.data[page_num]
      assert :atomics.get(page,1) == 1
      assert :atomics.get(page,2) == 2
      assert :atomics.get(page,3) == 3
      assert :atomics.get(page,4) == 4
    end
  end

  describe "access ranges" do
    test "set_access handles single and multi-page ranges", %{min_page: min_page} do
      pre_memory = %PreMemory{}
      address = min_allowed_address()

      # Single page
      updated = PreMemory.set_access(pre_memory, address, page_size(), :read)
      end_ = min_page + 1
      assert [{^min_page, ^end_, :read}] = updated.access_ranges

      # Multi-page (span 4 pages)
      multi_updated = PreMemory.set_access(pre_memory, address, page_size() * 3 + 100, :write)
      multi_end = min_page + 4
      assert [{^min_page, ^multi_end, :write}] = multi_updated.access_ranges
    end

    test "multiple set_access calls accumulate ranges" do
      pre_memory =
        PreMemory.set_access(%PreMemory{}, min_allowed_address(), page_size(), :read)
        |> PreMemory.set_access(
          min_allowed_address() + page_size() * 2,
          page_size(),
          :write
        )

      assert [{18, 19, :write}, {16, 17, :read}] = pre_memory.access_ranges
    end
  end

  describe "overlapping ranges" do
    test "handles complex overlapping scenarios" do
      # Scenario 1: Adjacent ranges with same access type are merged
      memory1 =
        PreMemory.set_access(%PreMemory{}, min_allowed_address(), page_size(), :read)
        |> PreMemory.set_access(min_allowed_address() + page_size(), page_size(), :read)
        |> PreMemory.finalize()

      assert [{16, 18, :read}] = memory1.access_ranges

      # Scenario 2: Later calls override earlier ones for the same range
      memory2 =
        PreMemory.set_access(%PreMemory{}, min_allowed_address(), page_size(), :read)
        |> PreMemory.set_access(min_allowed_address(), page_size(), :write)
        |> PreMemory.finalize()

      assert [{16, 17, :write}] = memory2.access_ranges

      # Scenario 3: Complex overlapping with multiple ranges
      base_addr = min_allowed_address()
      ranges =
        %PreMemory{}
        |> PreMemory.set_access(base_addr, page_size() * 3, :read)
        |> PreMemory.set_access(base_addr + page_size(), page_size() * 3, :write)
        |> PreMemory.set_access(base_addr + page_size() * 2, page_size(), nil)
        |> PreMemory.finalize()
        |> Map.get(:access_ranges)

      assert [{16, 17, :read}, {17, 18, :write}, {18, 19, nil}, {19, 20, :write}] == ranges
    end
  end

  describe "integration with Memory module" do
    test "finalized PreMemory creates a valid Memory struct" do
      pre_memory = %PreMemory{}
      base_addr = min_allowed_address()

      # Set up some memory regions and data
      updated = PreMemory.write(pre_memory, base_addr, <<1, 2, 3, 4>>)
      updated = PreMemory.set_access(updated, base_addr, page_size(), :read)
      updated = PreMemory.set_access(updated, base_addr + page_size(), page_size(), :write)

      # Finalize to create Memory struct
      memory = PreMemory.finalize(updated)

      # Verify Memory struct
      assert %Memory{} = memory
      assert memory.data == updated.data
      assert length(memory.access_ranges) == 2

      # Try reading from the memory
      {:ok, data} = Memory.read(memory, base_addr, 4)
      assert data == <<1, 2, 3, 4>>

      # Try writing to read-only memory (should fail)
      result = Memory.write(memory, base_addr, <<5>>)
      assert {:error, {:fault, _}} = result

      # Try writing to writable memory (should succeed)
      {:ok, _} = Memory.write(memory, base_addr + page_size(), <<5>>)
    end
  end
end
