defmodule Transitions do
  @moduledoc """
  Implements signed/unsigned transitions for various octet widths
  as defined in equations 243-246.
  """

  @doc """
  Implements transition Z_n (equation 243)
  Maps natural numbers to integers in range [-2^(8n-1)..2^(8n-1)-1]
  """
  @spec z_n(non_neg_integer(), non_neg_integer()) :: integer()
  def z_n(a, n) do
    threshold = :math.pow(2, 8 * n - 1) |> trunc()
    if a < threshold, do: a, else: a - trunc(:math.pow(2, 8 * n))
  end

  @doc """
  Implements transition Z_n^(-1) (equation 244)
  Maps integers back to natural numbers
  """
  @spec z_n_inverse(integer(), non_neg_integer()) :: non_neg_integer()
  def z_n_inverse(a, n) do
    modulus = trunc(:math.pow(2, 8 * n))
    rem(trunc(:math.pow(2, 8 * n)) + a, modulus)
  end

  @doc """
  Implements transition B_n (equation 245)
  Converts number to its binary representation
  """
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

  @doc """
  Implements transition B_n^(-1) (equation 246)
  Converts binary representation back to number
  """
  @spec b_n_inverse(list(0 | 1)) :: non_neg_integer()
  def b_n_inverse(bits), do: Integer.undigits(bits, 2)
end
