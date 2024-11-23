defmodule Instructions do
  @moduledoc """
  Defines opcodes and gas costs for the PVM
  """

  defmacro __using__(_opts) do
    quote do
      def op(instruction) when is_atom(instruction),
        do: Instructions.to_byte(instruction)

      def op(byte) when is_integer(byte), do: Instructions.from_byte(byte)

      def gas_cost(instruction) when is_atom(instruction),
        do: Instructions.gas_cost(instruction)
    end
  end

  @type t ::
          :trap
          | :fallthrough
          # One immediate argument
          | :ecalli
          # Two immediate arguments
          | :store_imm_u8
          | :store_imm_u16
          | :store_imm_u32
          | :store_imm_u64
          # One offset argument
          | :jump
          # One register and one (extended) immediate argument
          | :load_imm_64
          # One register and one immediate argument
          | :jump_ind
          | :load_imm
          | :load_u8
          | :load_i8
          | :load_u16
          | :load_i16
          | :load_u32
          | :load_i32
          | :load_u64
          | :store_u8
          | :store_u16
          | :store_u32
          | :store_u64
          # Register and two immediates
          | :store_imm_ind_u8
          | :store_imm_ind_u16
          | :store_imm_ind_u32
          | :store_imm_ind_u64
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

          # Two registers
          | :move_reg
          | :sbrk

          # Two registers and one immediate argument
          | :store_ind_u8
          | :store_ind_u16
          | :store_ind_u32
          | :store_ind_u64
          | :load_ind_u8
          | :load_ind_i8
          | :load_ind_u16
          | :load_ind_i16
          | :load_ind_u32
          | :load_ind_i32
          | :load_ind_u64
          | :load_ind_i64
          | :add_imm_32
          | :mul_imm_32
          | :neg_add_imm_32
          | :set_lt_u_imm
          | :set_lt_s_imm
          | :set_gt_u_imm
          | :set_gt_s_imm
          | :shlo_l_imm_32
          | :shlo_r_imm_32
          | :shar_r_imm_32
          | :shlo_l_imm_alt_32
          | :shlo_r_imm_alt_32
          | :shar_r_imm_alt_32
          | :cmov_nz_imm
          | :cmov_iz_imm
          | :add_imm_64
          | :mul_imm_64
          | :neg_add_imm_64
          | :shlo_l_imm_64
          | :shlo_r_imm_64
          | :shar_r_imm_64
          | :shlo_l_imm_alt_64
          | :shlo_r_imm_alt_64
          | :shar_r_imm_alt_64
          # Two registers and one offset argument
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
    ecalli: 10,
    load_imm_64: 20,
    store_imm_u8: 30,
    store_imm_u16: 31,
    store_imm_u32: 32,
    store_imm_u64: 33,
    jump: 40,
    jump_ind: 50,
    load_imm: 51,
    load_u8: 52,
    load_i8: 53,
    load_u16: 54,
    load_i16: 55,
    load_u32: 56,
    load_i32: 57,
    load_u64: 58,
    store_u8: 59,
    store_u16: 60,
    store_u32: 61,
    store_u64: 62,
    store_imm_ind_u8: 70,
    store_imm_ind_u16: 71,
    store_imm_ind_u32: 72,
    store_imm_ind_u64: 73,
    load_imm_jump: 80,
    load_imm_jump_ind: 61,
    branch_eq_imm: 81,
    branch_ne_imm: 82,
    branch_lt_u_imm: 83,
    branch_le_u_imm: 84,
    branch_ge_u_imm: 85,
    branch_gt_u_imm: 86,
    branch_lt_s_imm: 87,
    branch_le_s_imm: 88,
    branch_ge_s_imm: 89,
    branch_gt_s_imm: 90,
    move_reg: 100,
    sbrk: 101,
    store_ind_u8: 110,
    store_ind_u16: 111,
    store_ind_u32: 112,
    store_ind_u64: 113,
    load_ind_u8: 114,
    load_ind_i8: 115,
    load_ind_u16: 116,
    load_ind_i16: 117,
    load_ind_u32: 118,
    load_ind_i32: 119,
    load_ind_u64: 120,
    add_imm_32: 121,
    and_imm: 122,
    xor_imm: 123,
    or_imm: 124,
    mul_imm_32: 125,
    set_lt_u_imm: 126,
    set_lt_s_imm: 127,
    shlo_l_imm_32: 128,
    shlo_r_imm_32: 129,
    shar_r_imm_32: 130,
    neg_add_imm_32: 131,
    set_gt_u_imm: 132,
    set_gt_s_imm: 133,
    shlo_l_imm_alt_32: 134,
    shlo_r_imm_alt_32: 135,
    shar_r_imm_alt_32: 136,
    cmov_iz_imm: 137,
    cmov_nz_imm: 138,
    add_imm_64: 139,
    mul_imm_64: 140,
    shlo_l_imm_64: 141,
    shlo_r_imm_64: 142,
    shar_r_imm_64: 143,
    neg_add_imm_64: 144,
    shlo_l_imm_alt_64: 145,
    shlo_r_imm_alt_64: 146,
    shar_r_imm_alt_64: 147,
    branch_eq: 150,
    branch_ne: 151,
    branch_lt_u: 152,
    branch_lt_s: 153,
    branch_ge_u: 154,
    branch_ge_s: 155
  }

  @gas_cost_map %{
    trap: 0,
    fallthrough: 0,
    ecalli: 0,
    load_imm_64: 0,
    store_imm_u8: 0,
    store_imm_u16: 0,
    store_imm_u32: 0,
    store_imm_u64: 0,
    jump: 0,
    jump_ind: 0,
    load_imm: 0,
    load_u8: 0,
    load_i8: 0,
    load_u16: 0,
    load_i16: 0,
    load_u32: 0,
    load_i32: 0,
    load_u64: 0,
    store_u8: 0,
    store_u16: 0,
    store_u32: 0,
    store_u64: 0,
    store_imm_ind_u8: 0,
    store_imm_ind_u16: 0,
    store_imm_ind_u32: 0,
    store_imm_ind_u64: 0,
    load_imm_jump: 0,
    load_imm_jump_ind: 0,
    store_ind_u8: 0,
    store_ind_u16: 0,
    store_ind_u32: 0,
    store_ind_u64: 0,
    load_ind_u8: 0,
    load_ind_i8: 0,
    load_ind_u16: 0,
    load_ind_i16: 0,
    load_ind_u32: 0,
    load_ind_i32: 0,
    load_ind_u64: 0,
    add_imm_32: 0,
    and_imm: 0,
    xor_imm: 0,
    or_imm: 0,
    mul_imm_32: 0,
    set_lt_u_imm: 0,
    set_lt_s_imm: 0,
    shlo_l_imm_32: 0,
    shlo_r_imm_32: 0,
    shar_r_imm_32: 0,
    neg_add_imm_32: 0,
    set_gt_u_imm: 0,
    set_gt_s_imm: 0,
    shlo_l_imm_alt_32: 0,
    shlo_r_imm_alt_32: 0,
    shar_r_imm_alt_32: 0,
    cmov_iz_imm: 0,
    cmov_nz_imm: 0,
    add_imm_64: 0,
    mul_imm_64: 0,
    shlo_l_imm_64: 0,
    shlo_r_imm_64: 0,
    shar_r_imm_64: 0,
    neg_add_imm_64: 0,
    shlo_l_imm_alt_64: 0,
    shlo_r_imm_alt_64: 0,
    shar_r_imm_alt_64: 0,
    branch_eq: 0,
    branch_ne: 0,
    branch_ge_u: 0,
    branch_ge_s: 0,
    branch_lt_u: 0,
    branch_lt_s: 0,
    branch_eq_imm: 0,
    branch_ne_imm: 0,
    branch_lt_u_imm: 0,
    branch_lt_s_imm: 0,
    branch_le_u_imm: 0,
    branch_le_s_imm: 0,
    branch_ge_u_imm: 0,
    branch_ge_s_imm: 0,
    branch_gt_u_imm: 0,
    branch_gt_s_imm: 0,
    move_reg: 0,
    sbrk: 0
  }

  @instruction_categories %{
    no_args: [:trap, :fallthrough],
    one_immediate: [:ecalli, :jump],
    two_immediates: [:store_imm_u8, :store_imm_u16, :store_imm_u32, :store_imm_u64],
    reg_immediate: [
      :jump_ind,
      :load_imm,
      :load_imm_64,
      :load_u8,
      :load_i8,
      :load_u16,
      :load_i16,
      :load_u32,
      :load_i32,
      :load_u64,
      :store_u8,
      :store_u16,
      :store_u32,
      :store_u64
    ],
    register_two_immediate: [
      :store_imm_ind_u8,
      :store_imm_ind_u16,
      :store_imm_ind_u32,
      :store_imm_ind_u64
    ],
    register_immediate_offset: [
      :load_imm_jump,
      :branch_eq_imm,
      :branch_ne_imm,
      :branch_lt_u_imm,
      :branch_le_u_imm,
      :branch_ge_u_imm,
      :branch_gt_u_imm,
      :branch_lt_s_imm,
      :branch_le_s_imm,
      :branch_ge_s_imm,
      :branch_gt_s_imm
    ],
    two_registers: [:move_reg, :sbrk],
    two_registers_one_immediate: [
      :store_ind_u8,
      :store_ind_u16,
      :store_ind_u32,
      :store_ind_u64,
      :load_ind_u8,
      :load_ind_i8,
      :load_ind_u16,
      :load_ind_i16,
      :load_ind_u32,
      :load_ind_i32,
      :load_ind_u64,
      :add_imm_32,
      :and_imm,
      :xor_imm,
      :or_imm,
      :mul_imm_32,
      :set_lt_u_imm,
      :set_lt_s_imm,
      :shlo_l_imm_32,
      :shlo_r_imm_32,
      :shar_r_imm_32,
      :neg_add_imm_32,
      :set_gt_u_imm,
      :set_gt_s_imm,
      :shlo_l_imm_alt_32,
      :shlo_r_imm_alt_32,
      :shar_r_imm_alt_32,
      :cmov_iz_imm,
      :cmov_nz_imm,
      :add_imm_64,
      :mul_imm_64,
      :shlo_l_imm_64,
      :shlo_r_imm_64,
      :shar_r_imm_64,
      :neg_add_imm_64,
      :shlo_l_imm_alt_64,
      :shlo_r_imm_alt_64,
      :shar_r_imm_alt_64
    ],
    two_registers_one_offset: [
      :branch_eq,
      :branch_ne,
      :branch_lt_u,
      :branch_lt_s,
      :branch_ge_u,
      :branch_ge_s
    ],
    two_registers_two_immediate: [
      :load_imm_jump_ind
    ]
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

  # Generate gas_cost/1 using the map
  for {instruction, cost} <- @gas_cost_map do
    def gas_cost(unquote(instruction)), do: unquote(cost)
  end

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

  def opcode_map do
    @opcode_map
  end

  def gas_cost_map do
    @gas_cost_map
  end

  def instruction_categories do
    @instruction_categories
  end

  # Add helper function to get instruction category
  def instruction_category(instruction) do
    Enum.find_value(@instruction_categories, fn {category, instructions} ->
      if instruction in instructions, do: category
    end)
  end
end
