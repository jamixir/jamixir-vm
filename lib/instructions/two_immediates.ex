defmodule PVM.Instructions.TwoImmediates do
  import Bitwise
  use PVM.{Encoder, Utils}
  import PVM.Memory.Util
  alias PVM.Trace
  # Section (A.17) v0.5

  def execute(:store_imm_u8, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = rem(v_y, 1 <<< 8)
    Trace.instruction(state.counter, "store_imm_u8", "store #{value} to address #{v_x}")
    write_memory(state, v_x, <<value>>)
  end

  def execute(:store_imm_u16, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = rem(v_y, 1 <<< 16)
    Trace.instruction(state.counter, "store_imm_u16", "store #{value} to address #{v_x}")
    write_memory(state, v_x, e_le(value, 2))
  end

  def execute(:store_imm_u32, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    value = rem(v_y, 1 <<< 32)
    Trace.instruction(state.counter, "store_imm_u32", "store #{value} to address #{v_x}")
    write_memory(state, v_x, e_le(value, 4))
  end

  def execute(:store_imm_u64, program, bitmask, state) do
    {v_x, v_y} = get_params(program, bitmask, state.counter)
    Trace.instruction(state.counter, "store_imm_u64", "store #{v_y} to address #{v_x}")
    write_memory(state, v_x, e_le(v_y, 8))
  end

  defp get_params(program, bitmask, counter) do
    l_x =
      binary_part_safe(program, counter + 1, 1)
      |> :binary.first()
      |> rem(8)
      |> min(4)

    l = skip(counter, bitmask)
    l_y = min(4, max(0, l - l_x - 1))

    v_x = decode_and_extend(program, counter + 2, l_x)
    v_y = decode_and_extend(program, counter + 2 + l_x, l_y)

    {v_x, v_y}
  end
end
