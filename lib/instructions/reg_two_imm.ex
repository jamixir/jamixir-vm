defmodule PVM.Instructions.RegTwoImm do
  use PVM.{Decoder, Encoder, Utils, Math}
  alias PVM.Registers
  import PVM.Memory.Util
  # Section (A.5.7) v0.7.0

  @two_to_8 0x100
  @two_to_16 0x1_0000
  @two_to_32 0x1_0000_0000

  def execute(:store_imm_ind_u8, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    stored_value = mod(v_y, @two_to_8)
    target_addr = w_a + v_x

    write_memory(state, target_addr, <<stored_value>>)
  end

  def execute(:store_imm_ind_u16, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    stored_value = mod(v_y, @two_to_16)
    target_addr = w_a + v_x

    write_memory(state, target_addr, <<stored_value::16-little>>)
  end

  def execute(:store_imm_ind_u32, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    stored_value = mod(v_y, @two_to_32)
    target_addr = w_a + v_x

    write_memory(state, target_addr, <<stored_value::32-little>>)
  end

  def execute(:store_imm_ind_u64, program, bitmask, state) do
    {r_a, v_x, v_y} = get_params(program, bitmask, state.counter)
    w_a = Registers.get(state.registers, r_a)
    target_addr = w_a + v_x

    write_memory(state, target_addr, <<v_y::64-little>>)
  end

  # Formula (A.25) v0.7.0
  defp get_params(program, bitmask, counter) do
    r_a =
      binary_part_safe(program, counter + 1, 1) |> :binary.first() |> mod(16) |> min(12)

    l_x =
      binary_part_safe(program, counter + 1, 1)
      |> :binary.first()
      |> Bitwise.bsr(4)
      |> mod(8)
      |> min(4)

    l_y = (skip(counter, bitmask) - l_x - 1) |> max(0) |> min(4)

    v_x = decode_and_extend(program, counter + 2, l_x)

    v_y = decode_and_extend(program, counter + 2 + l_x, l_y)

    {r_a, v_x, v_y}
  end
end
