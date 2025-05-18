defmodule PVM.Math do
  import Bitwise

  defguard is_power_of_2(x) when is_integer(x) and x > 0 and (x &&& x - 1) == 0

  # Formula (A.10) v0.6.6
  @spec unsigned_to_signed(non_neg_integer(), non_neg_integer()) :: integer()
  def unsigned_to_signed(value, num_bytes) do
    threshold = 1 <<< (8 * num_bytes - 1)
    if value < threshold, do: value, else: value - (1 <<< (8 * num_bytes))
  end

  # Formula (A.11) v0.6.6
  @spec signed_to_unsigned(integer(), non_neg_integer()) :: non_neg_integer()
  def signed_to_unsigned(value, num_bytes) do
    modulus = 1 <<< (8 * num_bytes)
    rem(modulus + value, modulus)
  end

  # Formula (A.12) v0.6.6
  # Converts an integer to its binary (little-endian) as list
  # Example: int_to_bits(10, 1) returns [0,1,0,1,0,0,0,0]
  @spec int_to_bits(non_neg_integer(), non_neg_integer()) :: list(0 | 1)
  def int_to_bits(value, num_bytes) do
    for i <- 0..(8 * num_bytes - 1), do: rem(value >>> i, 2)
  end

  # Formula (A.13) v0.6.6
  # Converts a list of bits back to an integer (from little-endian format)
  # Example: bits_to_int([1,0,1,0,0,0,0,0]) returns 5
  @spec bits_to_int(list(0 | 1)) :: non_neg_integer()
  def bits_to_int(bits) do
    bits
    |> Enum.with_index()
    |> Enum.reduce(0, fn {bit, i}, acc -> acc + bit * (1 <<< i) end)
  end

    # Formula (A.14) v0.6.6
    def leading_zeros(0, bytes), do: bytes * 8
    def leading_zeros(value, bytes) do
      bits = bytes * 8
      value = mod(value, 1 <<< bits)
      bits - length(Integer.digits(value, 2))
    end

  # Formula (A.32) v0.6.6
  @spec signed_remainder(integer(), integer()) :: integer()
  def signed_remainder(a, 0), do: a
  def signed_remainder(a, b), do: rem(a, b)

  # Efficient modulo operation using bitwise AND for powers of 2
  @spec mod(integer(), integer()) :: integer()
  # 2^8
  def mod(value, 0x100), do: value &&& 0xFF
  # 2^16
  def mod(value, 0x10000), do: value &&& 0xFFFF
  # 2^32
  def mod(value, 0x1_0000_0000), do: value &&& 0xFFFFFFFF
  # 2^64
  def mod(value, 0x1_0000_0000_0000_0000), do: value &&& 0xFFFF_FFFF_FFFF_FFFF

  # Handle other powers of 2
  def mod(value, divisor) when is_power_of_2(divisor), do: value &&& divisor - 1

  # Fall back to regular remainder for non-powers of 2
  def mod(value, divisor), do: rem(value, divisor)

  defmacro __using__(_) do
    quote do
      def u2i(value, num_bytes), do: PVM.Math.unsigned_to_signed(value, num_bytes)
      def i2u(value, num_bytes), do: PVM.Math.signed_to_unsigned(value, num_bytes)
      def u2b(value, num_bytes), do: PVM.Math.int_to_bits(value, num_bytes)
      def b2u(bits), do: PVM.Math.bits_to_int(bits)
      def srem(a, b), do: PVM.Math.signed_remainder(a, b)
      def mod(a, b), do: PVM.Math.mod(a, b)
      def leading_zeros(value, bytes), do: PVM.Math.leading_zeros(value, bytes)
    end
  end
end
