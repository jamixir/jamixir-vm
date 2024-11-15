defmodule Instructions do
  @moduledoc """
  Defines opcodes and gas costs for the PVM
  """

  defmodule Opcode do
    @type t ::
            :trap
            | :fallthrough
            | :ecalli
            | :store_imm_u8
            | :store_imm_u16
            | :store_imm_u32
            | :jump
            | :jump_ind
            | :load_imm_jump
            | :load_imm_jump_ind
            | :branch_eq
            | :branch_ne
            | :branch_ge_u
            | :branch_ge_s
            | :branch_lt_u
            | :branch_lt_s
            | :branch_eq_imm
            | :branch_ne_imm
            | :branch_lt_u_imm
            | :branch_lt_s_imm
            | :branch_le_u_imm
            | :branch_le_s_imm
            | :branch_ge_u_imm
            | :branch_ge_s_imm
            | :branch_gt_u_imm
            | :branch_gt_s_imm

    def from_byte(0), do: :trap
    def from_byte(17), do: :fallthrough
    def from_byte(78), do: :ecalli
    def from_byte(62), do: :store_imm_u8
    def from_byte(79), do: :store_imm_u16
    def from_byte(38), do: :store_imm_u32
    def from_byte(5), do: :jump
    def from_byte(10), do: :jump_ind
    def from_byte(6), do: :load_imm_jump
    def from_byte(42), do: :load_imm_jump_ind
    def from_byte(24), do: :branch_eq
    def from_byte(30), do: :branch_ne
    def from_byte(41), do: :branch_ge_u
    def from_byte(43), do: :branch_ge_s
    def from_byte(47), do: :branch_lt_u
    def from_byte(48), do: :branch_lt_s
    def from_byte(7), do: :branch_eq_imm
    def from_byte(15), do: :branch_ne_imm
    def from_byte(44), do: :branch_lt_u_imm
    def from_byte(32), do: :branch_lt_s_imm
    def from_byte(59), do: :branch_le_u_imm
    def from_byte(49), do: :branch_le_s_imm
    def from_byte(52), do: :branch_ge_u_imm
    def from_byte(45), do: :branch_ge_s_imm
    def from_byte(50), do: :branch_gt_u_imm
    def from_byte(53), do: :branch_gt_s_imm
    def from_byte(_), do: :trap
  end

  def gas_cost(:trap), do: 0
  def gas_cost(:fallthrough), do: 0
  def gas_cost(:ecalli), do: 0
  def gas_cost(:store_imm_u8), do: 0
  def gas_cost(:store_imm_u16), do: 0
  def gas_cost(:store_imm_u32), do: 0
  def gas_cost(:jump), do: 0


    @doc """
  Returns true if the opcode is a termination instruction as defined in A.3
  """
  def termination_instruction?(opcode) do
    opcode in [
      # Trap and fallthrough
      :trap, :fallthrough,
      # Jumps
      :jump, :jump_ind,
      # Load-and-Jumps
      :load_imm_jump, :load_imm_jump_ind,
      # Branches
      :branch_eq, :branch_ne, :branch_ge_u, :branch_ge_s,
      :branch_lt_u, :branch_lt_s, :branch_eq_imm, :branch_ne_imm,
      # Immediate branches
      :branch_lt_u_imm, :branch_lt_s_imm, :branch_le_u_imm, :branch_le_s_imm,
      :branch_ge_u_imm, :branch_ge_s_imm, :branch_gt_u_imm, :branch_gt_s_imm
    ]
  end
end
