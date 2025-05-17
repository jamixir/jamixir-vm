defmodule PVM.CodecTest do
  use ExUnit.Case
  alias PVM.{Decoder, Encoder}

  describe "program encoding/decoding" do
    test "encodes and decodes program with empty jump table" do
      program = <<60, 171, 142, 73, 61, 2, 3>>
      bitmask = <<137>>
      jump_table = [1, 2, 3, 100, 200]
      z = 1
      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.deblob!(encoded)

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
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.deblob!(encoded)

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
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.deblob!(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == jump_table
    end
  end

  describe "decode_next_integer edge cases" do
    test "decodes zero-length jump table" do
      program = <<1, 2, 3>>
      bitmask = <<0xFF>>
      jump_table = []
      z = 1

      encoded = Encoder.encode_program(program, bitmask, jump_table, z)
      {decoded_program, decoded_bitmask, decoded_jumps} = Decoder.deblob!(encoded)

      assert decoded_program == program
      assert decoded_bitmask == bitmask
      assert decoded_jumps == []
    end
  end
end
