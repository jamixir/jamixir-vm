defmodule Transitions do
  import Bitwise


  # Formula (A.7) v0.5
  @spec z_n(non_neg_integer(), non_neg_integer()) :: integer()
  def z_n(a, n) do
    threshold = 1 <<< (8 * n - 1)
    if a < threshold, do: a, else: a - (1 <<< (8 * n))
  end

  # Formula (A.8) v0.5
  @spec z_n_inverse(integer(), non_neg_integer()) :: non_neg_integer()
  def z_n_inverse(a, n) do
    modulus = 1 <<< (8 * n)
    rem(modulus + a, modulus)
  end

  # Formula (A.9) v0.5
  @spec b_n(non_neg_integer(), non_neg_integer()) :: list(0 | 1)
  def b_n(x, n) do
    x
    |> Integer.digits(2)
    |> pad_leading_zeros(8 * n)
  end

  defp pad_leading_zeros(digits, width) do
    padding = List.duplicate(0, width - length(digits))
    padding ++ digits
  end

  # Formula (A.10) v0.5
  @spec b_n_inverse(list(0 | 1)) :: non_neg_integer()
  def b_n_inverse(bits), do: Integer.undigits(bits, 2)
end
