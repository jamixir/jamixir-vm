defmodule Instructions do
  @moduledoc """
  Defines opcodes and gas costs for the PVM
  """

  defmodule Opcode do
    @type t :: :trap | :fallthrough | :store_imm_u8 | :store_imm_u16 | :store_imm_u32

    def from_byte(0), do: :trap
    def from_byte(17), do: :fallthrough
    def from_byte(62), do: :store_imm_u8
    def from_byte(79), do: :store_imm_u16
    def from_byte(38), do: :store_imm_u32
    def from_byte(_), do: :trap
  end

  def gas_cost(:trap), do: 0
  def gas_cost(:fallthrough), do: 0
  def gas_cost(:store_imm_u8), do: 0
  def gas_cost(:store_imm_u16), do: 0
  def gas_cost(:store_imm_u32), do: 0
end
