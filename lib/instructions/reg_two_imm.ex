defmodule PVM.Instructions.RegTwoImm do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils}
  alias PVM.Memory
  # Section (A.20) v0.5

  def execute(:store_imm_ind_u8, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Enum.at(state.registers, r_a)
    Memory.Util.write(state, w_a + v_x, <<rem(v_y, 1 <<< 8)>>)
  end

  def execute(:store_imm_ind_u16, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Enum.at(state.registers, r_a)
    Memory.Util.write(state, w_a + v_x, e_le(rem(v_y, 1 <<< 16), 2))
  end

  def execute(:store_imm_ind_u32, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Enum.at(state.registers, r_a)
    Memory.Util.write(state, w_a + v_x, e_le(v_y, 4))
  end

  def execute(:store_imm_ind_u64, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Enum.at(state.registers, r_a)
    Memory.Util.write(state, w_a + v_x, e_le(v_y, 8))
  end

  # Formula (A.20) v0.5
  defp get_params(program, bitmask, counter) do
    r_a =
      binary_part(program, counter + 1, 1) |> :binary.first() |> rem(16) |> min(12)

    l_x =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> rem(8)
      |> min(4)

    l_y = (skip(counter, bitmask) - l_x - 1) |> max(0) |> min(4)

    v_x = decode_bytes_signed(program, counter + 2, l_x)

    v_y = decode_bytes_signed(program, counter + 2 + l_x, l_y)

    {r_a, v_x, v_y}
  end
end
