defmodule Instructions.RegTwoImm do
  alias PVM.Utils
  import Bitwise
  use PVM.{Decoder, Encoder}
  alias Instructions.Common

  # Section (A.20) v0.5

  def execute(:store_imm_ind_u8, state, output) do
    {r_a, v_x, v_y} = get_params(state)
    w_a = Enum.at(state.registers, r_a)
    Common.do_write(output, w_a + v_x, state.memory, <<rem(v_y, 1 <<< 8)>>)
  end

  def execute(:store_imm_ind_u16, state, output) do
    {r_a, v_x, v_y} = get_params(state)
    w_a = Enum.at(state.registers, r_a)
    Common.do_write(output, w_a + v_x, state.memory, e_le(rem(v_y, 1 <<< 16), 2))
  end

  def execute(:store_imm_ind_u32, state, output) do
    {r_a, v_x, v_y} = get_params(state)
    w_a = Enum.at(state.registers, r_a)
    Common.do_write(output, w_a + v_x, state.memory, e_le(v_y, 4))
  end

  def execute(:store_imm_ind_u64, state, output) do
    {r_a, v_x, v_y} = get_params(state)
    w_a = Enum.at(state.registers, r_a)
    Common.do_write(output, w_a + v_x, state.memory, e_le(v_y, 8))
  end

  # Formula (A.20) v0.5
  defp get_params(state) do
    r_a =
      binary_part(state.program, state.counter + 1, 1) |> :binary.first() |> rem(16) |> min(12)

    l_x =
      binary_part(state.program, state.counter + 1, 1)
      |> :binary.first()
      |> div(16)
      |> rem(8)
      |> min(4)

    l_y = (Utils.skip(state.counter, state.bitmask) - l_x - 1) |> max(0) |> min(4)

    v_x = Utils.decode_bytes_signed(state.program, state.counter + 2, l_x)

    v_y = Utils.decode_bytes_signed(state.program, state.counter + 2 + l_x, l_y)

    {r_a, v_x, v_y}
  end
end
