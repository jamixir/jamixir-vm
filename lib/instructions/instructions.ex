defmodule Instructions do
  @moduledoc """
  Defines opcodes and gas costs for the PVM
  """

  defmodule Opcode do
    defmacro __using__(_opts) do
      quote do
        def op(instruction) when is_atom(instruction), do: Instructions.Opcode.to_byte(instruction)
        def op(byte) when is_integer(byte), do: Instructions.Opcode.from_byte(byte)
      end
    end

    # No arguments
    @type t ::
            :trap
            | :fallthrough
            # One immediate argument
            | :ecalli
            # Two immediate arguments
            | :store_imm_u8
            | :store_imm_u16
            | :store_imm_u32
            # One offset argument
            | :jump
            # One register and one (extended) immediate argument
            | :load_imm_u64
            # One register and one immediate argument
            | :jump_ind
            | :load_imm
            | :load_u8
            | :load_i8
            | :load_u16
            | :load_i16
            | :load_u32
            | :store_u8
            | :store_u16
            | :store_u32
            # One register, one immediate and one offset argument
            | :load_imm_jump
            | :branch_eq_imm
            | :branch_ne_imm
            | :branch_lt_u_imm
            | :branch_le_u_imm
            | :branch_ge_u_imm
            | :branch_gt_u_imm
            | :branch_lt_s_imm
            | :branch_le_s_imm
            | :branch_ge_s_imm
            | :branch_gt_s_imm

            # Two registers and one immediate argument
            | :branch_eq
            | :branch_ne
            | :branch_lt_u
            | :branch_lt_s
            | :branch_ge_u
            | :branch_ge_s
            # Two registers and two immediate argument
            | :load_imm_jump_ind

    # Define a map for the two-way mapping
    @opcode_map %{
      trap: 0,
      fallthrough: 1,
      ecalli: 78,
      store_imm_u8: 62,
      store_imm_u16: 79,
      store_imm_u32: 38,
      jump: 5,
      load_imm_u64: 20,
      jump_ind: 19,
      load_imm_jump: 6,
      load_imm_jump_ind: 42,
      branch_eq: 24,
      branch_ne: 30,
      branch_ge_u: 41,
      branch_ge_s: 43,
      branch_lt_u: 47,
      branch_lt_s: 48,
      branch_eq_imm: 7,
      branch_ne_imm: 15,
      branch_lt_u_imm: 44,
      branch_lt_s_imm: 32,
      branch_le_u_imm: 59,
      branch_le_s_imm: 49,
      branch_ge_u_imm: 52,
      branch_ge_s_imm: 45,
      branch_gt_u_imm: 50,
      branch_gt_s_imm: 53,
      load_imm: 4,
      load_u8: 60,
      load_i8: 74,
      load_u16: 76,
      load_i16: 66,
      load_u32: 10,
      store_u8: 71,
      store_u16: 69,
      store_u32: 22
    }

    # Generate from_byte/1 using the map
    for {instruction, byte} <- @opcode_map do
      def from_byte(unquote(byte)), do: unquote(instruction)
    end
    def from_byte(_), do: :trap

    # Generate to_byte/1 using the map
    for {instruction, byte} <- @opcode_map do
      def to_byte(unquote(instruction)), do: unquote(byte)
    end
  end

  def gas_cost(:trap), do: 0
  def gas_cost(:fallthrough), do: 0
  def gas_cost(:ecalli), do: 0
  def gas_cost(:store_imm_u8), do: 0
  def gas_cost(:store_imm_u16), do: 0
  def gas_cost(:store_imm_u32), do: 0
  def gas_cost(:jump), do: 0
  def gas_cost(:jump_ind), do: 0
  def gas_cost(:load_imm), do: 0
  def gas_cost(:load_u8), do: 0
  def gas_cost(:load_i8), do: 0
  def gas_cost(:load_u16), do: 0
  def gas_cost(:load_i16), do: 0
  def gas_cost(:load_u32), do: 0
  def gas_cost(:store_u8), do: 0
  def gas_cost(:store_u16), do: 0
  def gas_cost(:store_u32), do: 0

  @doc """
  Returns true if the opcode is a termination instruction as defined in A.3
  """
  def termination_instruction?(opcode) do
    opcode in [
      # Trap and fallthrough
      :trap,
      :fallthrough,
      # Jumps
      :jump,
      :jump_ind,
      # Load-and-Jumps
      :load_imm_jump,
      :load_imm_jump_ind,
      # Branches
      :branch_eq,
      :branch_ne,
      :branch_ge_u,
      :branch_ge_s,
      :branch_lt_u,
      :branch_lt_s,
      :branch_eq_imm,
      :branch_ne_imm,
      # Immediate branches
      :branch_lt_u_imm,
      :branch_lt_s_imm,
      :branch_le_u_imm,
      :branch_le_s_imm,
      :branch_ge_u_imm,
      :branch_ge_s_imm,
      :branch_gt_u_imm,
      :branch_gt_s_imm
    ]
  end
end
