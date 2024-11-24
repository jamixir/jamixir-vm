defmodule Instructions.TwoImmediates do
  use PVM.Utils
  import Bitwise
  use PVM.Encoder
  # Section (A.17) v0.5

  def execute(:store_imm_u8, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    Memory.Util.write(state, v_x, <<rem(v_y, 1 <<< 8)>>)
  end

  def execute(:store_imm_u16, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    Memory.Util.write(state, v_x, e_le(rem(v_y, 1 <<< 16), 2))
  end

  def execute(:store_imm_u32, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    Memory.Util.write(state, v_x, e_le(rem(v_y, 1 <<< 32), 4))
  end

  def execute(:store_imm_u64, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    Memory.Util.write(state, v_x, e_le(v_y, 8))
  end

  defp get_params(program, bitmask, counter) do
    l_x =
      binary_part(program, counter + 1, 1)
      |> :binary.first()
      |> rem(8)
      |> min(4)

    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))

    v_x = decode_bytes_signed(program, counter + 2, l_x)
    v_y = decode_bytes_signed(program, counter + 2 + l_x, l_y)

    {v_x, v_y}
  end
end
