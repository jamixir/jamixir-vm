defmodule PVM.Math do
  import Bitwise

  # Formula (A.9) v0.61
  @spec unsigned_to_signed(non_neg_integer(), non_neg_integer()) :: integer()
  def unsigned_to_signed(value, num_bytes) do
    threshold = 1 <<< (8 * num_bytes - 1)
    if value < threshold, do: value, else: value - (1 <<< (8 * num_bytes))
  end

  # Formula (A.10) v0.6.1
  @spec signed_to_unsigned(integer(), non_neg_integer()) :: non_neg_integer()
  def signed_to_unsigned(value, num_bytes) do
    modulus = 1 <<< (8 * num_bytes)
    rem(modulus + value, modulus)
  end

  # Formula (A.11) v0.6.1
  # Converts an integer to its binary (little-endian) as list
  # Example: int_to_bits(10, 1) returns [0,1,0,1,0,0,0,0]
  @spec int_to_bits(non_neg_integer(), non_neg_integer()) :: list(0 | 1)
  def int_to_bits(value, num_bytes) do
    for i <- 0..(8 * num_bytes - 1), do: rem(value >>> i, 2)
  end

  # Formula (A.12) v0.6.1
  # Converts a list of bits back to an integer (from little-endian format)
  # Example: bits_to_int([1,0,1,0,0,0,0,0]) returns 5
  @spec bits_to_int(list(0 | 1)) :: non_neg_integer()
  def bits_to_int(bits) do
    bits
    |> Enum.with_index()
    |> Enum.reduce(0, fn {bit, i}, acc -> acc + bit * (1 <<< i) end)
  end

  # Formula (A.13) v0.6.1
  # Converts an integer to its binary (big-endian) as list
  # Example: int_to_bits_be(5, 1) returns [0,0,0,0,0,1,0,1]
  @spec int_to_bits_be(non_neg_integer(), non_neg_integer()) :: list(0 | 1)
  def int_to_bits_be(value, num_bytes) do
    for i <- (8 * num_bytes - 1)..0, do: rem(value >>> i, 2)
  end

  # Formula (A.14) v0.6.1
  # Converts a list of bits in big-endian order back to an integer
  # Example: bits_to_int_be([1,0,1,0,0,0,0,0]) returns 5
  @spec bits_to_int_be(list(0 | 1)) :: non_neg_integer()
  def bits_to_int_be(bits) do
    bits_length = length(bits)

    0..(bits_length - 1)
    |> Enum.reduce(0, fn i, acc ->
      acc + Enum.at(bits, bits_length - 1 - i) * (1 <<< i)
    end)
  end

  defmacro __using__(_) do
    quote do
      def u2i(value, num_bytes), do: PVM.Math.unsigned_to_signed(value, num_bytes)
      def i2u(value, num_bytes), do: PVM.Math.signed_to_unsigned(value, num_bytes)
      def u2b(value, num_bytes), do: PVM.Math.int_to_bits(value, num_bytes)
      def b2u(bits), do: PVM.Math.bits_to_int(bits)
      def u2b_be(value, num_bytes), do: PVM.Math.int_to_bits_be(value, num_bytes)
      def b2u_be(bits), do: PVM.Math.bits_to_int_be(bits)
    end
  end
end
