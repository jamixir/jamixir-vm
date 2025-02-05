defmodule PVM.Instructions.RegTwoImm do
  use PVM.{Decoder, Encoder, Utils}
  alias PVM.Registers
  import PVM.Memory.Util
  # Section (A.5.7) v0.6.1

  def execute(:store_imm_ind_u8, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    write_memory(state, w_a + v_x, <<rem(v_y, 0x100)>>)
  end

  def execute(:store_imm_ind_u16, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    write_memory(state, w_a + v_x, e_le(rem(v_y, 0x1_0000), 2))
  end

  def execute(:store_imm_ind_u32, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    write_memory(state, w_a + v_x, e_le(rem(v_y, 0x1_0000_0000), 4))
  end

  def execute(:store_imm_ind_u64, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    write_memory(state, w_a + v_x, e_le(v_y, 8))
  end

  # Formula (A.24) v0.6.1
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
