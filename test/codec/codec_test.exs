defmodule PVM.CodecTest do
  use ExUnit.Case
  alias PVM.Encoder
  alias PVM.Decoder

  describe "program encoding/decoding" do
    test "encodes and decodes program with empty jump table" do
      program = <<60, 171, 142, 73, 61, 2, 3>>
      bitmask = <<1, 0, 0, 0, 1, 0, 0>>
      jump_table = [1, 2, 3, 100, 200]
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end

    test "encodes and decodes program with jump table" do
      program = <<1, 2, 3, 4>>
      bitmask = <<0xFF>>
      jump_table = [10, 20, 30]
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end

    test "handles larger z values" do
      program = <<1, 2, 3, 4>>
      bitmask = <<0xFF>>
      # Numbers requiring more than 1 byte
      jump_table = [256, 512, 1024]
      z = 2

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end
  end

  describe "decode_next_integer edge cases" do
    test "decodes zero-sized program" do
      # Program with zero length, empty jump table, empty bitmask
      program = <<>>
      bitmask = <<>>
      jump_table = []
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end

    test "decodes program with large size (8-byte encoding)" do
      # Create a large program that will force 8-byte encoding
      # 16MB program
      program = String.duplicate(<<1>>, 0x1_000_000)
      bitmask = <<0xFF>>
      jump_table = []
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end

    test "decodes program with medium size (128..254 encoding)" do
      # Create programs of various sizes that will use 128..254 encoding
      # Will use different l values
      sizes = [200, 1000, 10_000]

      for size <- sizes do
        program = String.duplicate(<<1>>, size)
        bitmask = <<0xFF>>
        jump_table = []
        z = 1

        encoded = Encoder.encode_program(program, bitmask, jump_table, z)
        {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

        assert decoded_program == program
        assert decoded_bitmask == bitmask
        assert decoded_jumps == jump_table
        assert byte_size(decoded_program) == size
      end
    end

    test "decodes zero-length jump table" do
      program = <<1, 2, 3>>
      bitmask = <<0xFF>>
      jump_table = []
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.decode_program(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == []
    end
  end
end
