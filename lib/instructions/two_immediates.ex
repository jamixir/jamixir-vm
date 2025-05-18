defmodule PVM.Instructions.TwoImmediates do
  use PVM.{Encoder, Utils, Math}
  import PVM.Memory.Util
  # Section (A.22) v0.6.6

  @two_to_8 0x100
  @two_to_16 0x1_0000
  @two_to_32 0x1_0000_0000

  def execute(:store_imm_u8, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = mod(v_y, @two_to_8)
    write_memory(state, v_x, <<value>>)
  end

  def execute(:store_imm_u16, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = mod(v_y, @two_to_16)
    write_memory(state, v_x, <<value::16-little>>)
  end

  def execute(:store_imm_u32, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = mod(v_y, @two_to_32)
    write_memory(state, v_x, <<value::32-little>>)
  end

  def execute(:store_imm_u64, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    write_memory(state, v_x, <<v_y::64-little>>)
  end

  defp get_params(program, bitmask, counter) do
    l_x =
      binary_part_safe(program, counter + 1, 1)
      |> :binary.first()
      |> mod(8)
      |> min(4)

    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))

    v_x = decode_and_extend(program, counter + 2, l_x)
    v_y = decode_and_extend(program, counter + 2 + l_x, l_y)

    {v_x, v_y}
  end
end
