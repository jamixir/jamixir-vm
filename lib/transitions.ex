defmodule PVM.Transitions do
  import Bitwise

  # Formula (A.7) v0.5
  @spec unsigned_to_signed(non_neg_integer(), non_neg_integer()) :: integer()
  def unsigned_to_signed(value, num_bytes) do
    # Calculate sign bit position
    threshold = 1 <<< (8 * num_bytes - 1)
    if value < threshold, do: value, else: value - (1 <<< (8 * num_bytes))
  end

  # Formula (A.8) v0.5
  @spec signed_to_unsigned(integer(), non_neg_integer()) :: non_neg_integer()
  def signed_to_unsigned(value, num_bytes) do
    modulus = 1 <<< (8 * num_bytes)
    rem(modulus + value, modulus)
  end

  # Formula (A.9) v0.5
  # Converts an integer to its binary representation as a list of bits
  # Example: int_to_bits(5, 1) returns [0,0,0,0,0,1,0,1]
  @spec int_to_bits(non_neg_integer(), non_neg_integer()) :: list(0 | 1)
  def int_to_bits(value, num_bytes) do
    value
    |> Integer.digits(2)
    |> pad_leading_zeros(8 * num_bytes)
  end

  defp pad_leading_zeros(digits, width) do
    padding = List.duplicate(0, width - length(digits))
    padding ++ digits
  end

  # Formula (A.10) v0.5
  # Converts a list of bits back to an integer
  # Example: bits_to_int([0,0,0,0,0,1,0,1]) returns 5
  @spec bits_to_int(list(0 | 1)) :: non_neg_integer()
  def bits_to_int(bits), do: Integer.undigits(bits, 2)

  defmacro __using__(_) do
    quote do
      def u2i(value, num_bytes), do: PVM.Transitions.unsigned_to_signed(value, num_bytes)
      def i2u(value, num_bytes), do: PVM.Transitions.signed_to_unsigned(value, num_bytes)
      def u2b(value, num_bytes), do: PVM.Transitions.int_to_bits(value, num_bytes)
      def b2u(bits), do: PVM.Transitions.bits_to_int(bits)
    end
  end
end
