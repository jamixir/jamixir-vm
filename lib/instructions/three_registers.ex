defmodule PVM.Instructions.ThreeRegisters do
  use PVM.Utils
  use PVM.Math
  alias PVM.Registers
  import Bitwise
  @two_32 0x1_0000_0000
  @two_64 0x1_0000_0000_0000_0000
  @max_64 0xFFFF_FFFF_FFFF_FFFF

  # Section A.5.13 v0.7.0

  def execute(:add_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a + w_b) |> mod(@two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:sub_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a + @two_32 - mod(w_b, @two_32)) |> mod(@two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:mul_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a * w_b) |> mod(@two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:div_u_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)

    result =
      if mod(w_b, @two_32) == 0,
        do: @max_64,
        else: div(mod(w_a, @two_32), mod(w_b, @two_32)) |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:div_s_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    a = u2i(mod(w_a, @two_32), 4)
    b = u2i(mod(w_b, @two_32), 4)

    result =
      cond do
        b == 0 -> @max_64
        b == -1 and a == -1 * (1 <<< 31) -> i2u(a, 8)
        true -> div(a, b) |> trunc() |> i2u(8)
      end

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rem_u_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)

    result =
      if mod(w_b, @two_32) == 0,
        do: mod(w_a, @two_32) |> to_64bit(4),
        else: mod(mod(w_a, @two_32), mod(w_b, @two_32)) |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rem_s_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    a = u2i(mod(w_a, @two_32), 4)
    b = u2i(mod(w_b, @two_32), 4)
    result = if b == -1 and a == -1 * (1 <<< 31), do: 0, else: i2u(srem(a, b), 8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shlo_l_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 32)
    result = mod(w_a * (1 <<< shift), @two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shlo_r_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 32)
    result = mod(w_a, @two_32) >>> shift |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shar_r_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 32)
    result = mod(w_a, @two_32) |> u2i(4) |> Bitwise.bsr(shift) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:add_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a + w_b) |> mod(@two_64)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:sub_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a - w_b + @two_64) |> mod(@two_64)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:mul_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a * w_b) |> mod(@two_64)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:div_u_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)

    result =
      if mod(w_b, @two_64) == 0,
        do: @max_64,
        else: div(w_a, w_b)

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:div_s_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)

    result =
      cond do
        w_b == 0 -> @max_64
        u2i(w_b, 8) == -1 and u2i(w_a, 8) == -1 * (1 <<< 63) -> w_a
        true -> div(u2i(w_a, 8), u2i(w_b, 8)) |> trunc() |> i2u(8)
      end

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rem_u_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = if w_b == 0, do: w_a, else: mod(w_a, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rem_s_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)

    result =
      if u2i(w_b, 8) == -1 and u2i(w_a, 8) == -1 * (1 <<< 63),
        do: 0,
        else: srem(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)

    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shlo_l_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 64)
    result = mod(w_a * (1 <<< shift), @two_64)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shlo_r_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 64)
    result = w_a >>> shift
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:shar_r_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    shift = mod(w_b, 64)
    result = u2i(w_a, 8) >>> shift |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:and, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = w_a &&& w_b
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:xor, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = bxor(w_a, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:or, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = w_a ||| w_b
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:and_inv, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = w_a &&& bxor(@max_64, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:or_inv, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = w_a ||| bxor(@max_64, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:xnor, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    # NOT XOR = 64-bit bitwise NOT of XOR
    result = bxor(@max_64, bxor(w_a, w_b))
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:mul_upper_s_s, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (u2i(w_a, 8) * u2i(w_b, 8)) |> Bitwise.bsr(64) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:mul_upper_u_u, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (w_a * w_b) >>> 64
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:mul_upper_s_u, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = (u2i(w_a, 8) * w_b) |> Bitwise.bsr(64) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:set_lt_u, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = if(w_a < w_b, do: 1, else: 0)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:set_lt_s, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = if(u2i(w_a, 8) < u2i(w_b, 8), do: 1, else: 0)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:cmov_iz, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    w_d = state.registers[r_d]
    result = if(w_b == 0, do: w_a, else: w_d)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:cmov_nz, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    w_d = state.registers[r_d]
    result = if(w_b != 0, do: w_a, else: w_d)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rot_l_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = rotate(w_a, w_b, 64, :left)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rot_l_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = rotate(w_a, w_b, 32, :left) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rot_r_64, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = rotate(w_a, w_b, 64, :right)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:rot_r_32, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    result = rotate(w_a, w_b, 32, :right) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:max, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    # signed max
    result = max(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:max_u, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    # unsigned max
    result = max(w_a, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:min, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    # signed min
    result = min(u2i(w_a, 8), u2i(w_b, 8)) |> i2u(8)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  def execute(:min_u, program, state) do
    {w_a, w_b, r_d} = get_params(program, state)
    # unsigned min
    result = min(w_a, w_b)
    Registers.put_elem(state.registers.r, r_d, result)
    {:continue, state}
  end

  # Formula (A.31) v0.7.0
  defp get_params(program, state) do
    <<byte1>> = binary_part_safe(program, state.counter + 1, 1)
    <<byte2>> = binary_part_safe(program, state.counter + 2, 1)

    r_a = min(12, mod(byte1, 16))
    r_b = min(12, byte1 >>> 4)
    r_d = min(12, byte2)

    {state.registers[r_a], state.registers[r_b], r_d}
  end
end
