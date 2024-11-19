defmodule Instructions.TwoImmediates do
  alias PVM.Utils
  import Bitwise
  use PVM.Encoder
  alias Instructions.Common
  # Section (A.5.3) v0.4.5

  def execute(:store_imm_u8, state, output) do
    {addr, value} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    Common.do_write(output, addr, state.memory, <<rem(value, 1 <<< 8)>>)
  end

  def execute(:store_imm_u16, state, output) do
    {addr, value} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    Common.do_write(output, addr, state.memory, e_le(rem(value, 1 <<< 16), 2))
  end

  def execute(:store_imm_u32, state, output) do
    {addr, value} = Utils.parse_two_immediates(state.program, state.counter, state.bitmask)
    Common.do_write(output, addr, state.memory, e_le(value, 4))
  end
end
