defmodule PVM.Memory.UtilTest do
  use ExUnit.Case
  alias PVM.Memory.Util

  # Test memory struct 
  defp test_memory(data, page_size \\ 4096) do
    %{data: data, page_size: page_size}
  end

  describe "get_page_binary/2" do
    test "empty page returns all zeros" do
      memory = test_memory(%{}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "page not in memory returns all zeros" do
      memory = test_memory(%{1 => %{0 => 42}}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "single byte in page" do
      memory = test_memory(%{5 => %{3 => 42}}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 0, 0, 42, 0, 0, 0, 0, 0, 0>>
    end

    test "multiple scattered bytes in page" do
      memory = test_memory(%{5 => %{0 => 1, 3 => 42, 9 => 255}}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<1, 0, 0, 42, 0, 0, 0, 0, 0, 255>>
    end

    test "consecutive bytes (chunk) in page" do
      memory = test_memory(%{5 => %{3 => 10, 4 => 20, 5 => 30}}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 0, 0, 10, 20, 30, 0, 0, 0, 0>>
    end

    test "multiple chunks in page" do
      memory =
        test_memory(
          %{
            5 => %{
              # Chunk 1
              1 => 1,
              2 => 2,
              # Chunk 2
              5 => 5,
              6 => 6,
              7 => 7,
              # Chunk 3
              9 => 9
            }
          },
          10
        )

      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 1, 2, 0, 0, 5, 6, 7, 0, 9>>
    end

    test "mostly full page (>75%)" do
      # Create a page with 8 out of 10 bytes filled (80%)
      page_data = Enum.into(0..7, %{}, fn i -> {i, i * 10} end)
      memory = test_memory(%{5 => page_data}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 10, 20, 30, 40, 50, 60, 70, 0, 0>>
    end

    test "completely full page" do
      # Create a fully populated page
      page_data = Enum.into(0..9, %{}, fn i -> {i, i} end)
      memory = test_memory(%{5 => page_data}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9>>
    end

    test "bytes at start and end only" do
      memory = test_memory(%{5 => %{0 => 42, 9 => 255}}, 10)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 10
      assert result == <<42, 0, 0, 0, 0, 0, 0, 0, 0, 255>>
    end

    test "works with larger page sizes" do
      # Create a sparse page with a few values in a large page
      large_page = %{0 => 1, 100 => 100, 4000 => 200, 4095 => 255}
      memory = test_memory(%{5 => large_page}, 4096)
      result = Util.get_page_binary(memory, 5)

      assert byte_size(result) == 4096
      assert binary_part(result, 0, 1) == <<1>>
      assert binary_part(result, 100, 1) == <<100>>
      assert binary_part(result, 4000, 1) == <<200>>
      assert binary_part(result, 4095, 1) == <<255>>

      # Check some zeros in between
      assert binary_part(result, 50, 1) == <<0>>
      assert binary_part(result, 2000, 1) == <<0>>
    end
  end

  describe "pages_with_data/1" do
    test "returns empty list for empty memory" do
      memory = test_memory(%{})
      assert Util.pages_with_data(memory) == []
    end

    test "returns pages with data only" do
      memory =
        test_memory(%{
          1 => %{0 => 42},
          # Empty page
          2 => %{},
          5 => %{3 => 10}
        })

      assert Util.pages_with_data(memory) == [1, 5]
    end

    test "returns sorted page numbers" do
      memory =
        test_memory(%{
          5 => %{3 => 10},
          1 => %{0 => 42},
          10 => %{5 => 99}
        })

      assert Util.pages_with_data(memory) == [1, 5, 10]
    end
  end

  describe "integration with full page size" do
    test "works with full page size (4096 bytes)" do
      memory = test_memory(%{}, 4096)

      data = %{
        16 => %{0 => 1, 100 => 2, 4095 => 3},
        17 => %{0 => 4, 2048 => 5, 4095 => 6},
        20 => %{1000 => 7, 2000 => 8, 3000 => 9}
      }

      memory = %{memory | data: data}

      assert Util.get_page_binary(memory, 16) ==
               create_expected_binary(4096, [{0, 1}, {100, 2}, {4095, 3}])

      assert Util.get_page_binary(memory, 17) ==
               create_expected_binary(4096, [{0, 4}, {2048, 5}, {4095, 6}])

      assert Util.get_page_binary(memory, 20) ==
               create_expected_binary(4096, [{1000, 7}, {2000, 8}, {3000, 9}])
    end

    test "handles large sequential data with full page size" do
      memory = test_memory(%{}, 4096)

      page_data = Enum.into(200..3000, %{}, fn i -> {i, rem(i, 256)} end)
      data = %{16 => page_data}
      memory = %{memory | data: data}

      zeros_before = :binary.copy(<<0>>, 200)
      data_bytes = :binary.list_to_bin(Enum.map(200..3000, fn i -> rem(i, 256) end))
      zeros_after = :binary.copy(<<0>>, 4096 - 200 - byte_size(data_bytes))
      expected_binary = <<zeros_before::binary, data_bytes::binary, zeros_after::binary>>

      assert Util.get_page_binary(memory, 16) == expected_binary
    end
  end

  defp create_expected_binary(size, positions) do
    binary = :binary.copy(<<0>>, size)

    Enum.reduce(positions, binary, fn {offset, value}, acc ->
      <<pre::binary-size(offset), _::8, post::binary>> = acc
      <<pre::binary, value::8, post::binary>>
    end)
  end
end
