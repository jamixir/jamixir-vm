defmodule PVM.Instructions do
  @moduledoc """
  Defines opcodes and gas costs for the PVM
  """

  defmacro __using__(_opts) do
    quote do
      def op(instruction) when is_atom(instruction),
        do: PVM.Instructions.to_byte(instruction)

      def op(byte) when is_integer(byte), do: PVM.Instructions.from_byte(byte)

      def gas_cost(instruction) when is_atom(instruction),
        do: PVM.Instructions.gas_cost(instruction)
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
          | :count_set_bits_64
          | :count_set_bits_32
          | :leading_zero_bits_64
          | :leading_zero_bits_32
          | :trailing_zero_bits_64
          | :trailing_zero_bits_32
          | :sign_extend_8
          | :sign_extend_16
          | :zero_extend_16
          | :reverse_bytes

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
          | :rot_r_64_imm
          | :rot_r_64_imm_alt
          | :rot_r_32_imm
          | :rot_r_32_imm_alt
          # Two registers and one offset argument
          | :branch_eq
          | :branch_ne
          | :branch_lt_u
          | :branch_lt_s
          | :branch_ge_u
          | :branch_ge_s
          # Two registers and two immediate argument
          | :load_imm_jump_ind
          # Three registers
          | :add_32
          | :sub_32
          | :mul_32
          | :div_u_32
          | :div_s_32
          | :rem_u_32
          | :rem_s_32
          | :shlo_l_32
          | :shlo_r_32
          | :shar_r_32
          | :add_64
          | :sub_64
          | :mul_64
          | :div_u_64
          | :div_s_64
          | :rem_u_64
          | :rem_s_64
          | :shlo_l_64
          | :shlo_r_64
          | :shar_r_64
          | :and
          | :xor
          | :or
          | :mul_upper_s_s
          | :mul_upper_u_u
          | :mul_upper_s_u
          | :set_lt_u
          | :set_lt_s
          | :cmov_iz
          | :cmov_nz
          | :rot_l_64
          | :rot_l_32
          | :rot_r_64
          | :rot_r_32
          | :and_inv
          | :or_inv
          | :xnor
          | :max
          | :max_u
          | :min
          | :min_u
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
    count_set_bits_64: 102,
    count_set_bits_32: 103,
    leading_zero_bits_64: 104,
    leading_zero_bits_32: 105,
    trailing_zero_bits_64: 106,
    trailing_zero_bits_32: 107,
    sign_extend_8: 108,
    sign_extend_16: 109,
    zero_extend_16: 110,
    reverse_bytes: 111,
    store_ind_u8: 120,
    store_ind_u16: 121,
    store_ind_u32: 122,
    store_ind_u64: 123,
    load_ind_u8: 124,
    load_ind_i8: 125,
    load_ind_u16: 126,
    load_ind_i16: 127,
    load_ind_u32: 128,
    load_ind_i32: 129,
    load_ind_u64: 130,
    add_imm_32: 131,
    and_imm: 132,
    xor_imm: 133,
    or_imm: 134,
    mul_imm_32: 135,
    set_lt_u_imm: 136,
    set_lt_s_imm: 137,
    shlo_l_imm_32: 138,
    shlo_r_imm_32: 139,
    shar_r_imm_32: 140,
    neg_add_imm_32: 141,
    set_gt_u_imm: 142,
    set_gt_s_imm: 143,
    shlo_l_imm_alt_32: 144,
    shlo_r_imm_alt_32: 145,
    shar_r_imm_alt_32: 146,
    cmov_iz_imm: 147,
    cmov_nz_imm: 148,
    add_imm_64: 149,
    mul_imm_64: 150,
    shlo_l_imm_64: 151,
    shlo_r_imm_64: 152,
    shar_r_imm_64: 153,
    neg_add_imm_64: 154,
    shlo_l_imm_alt_64: 155,
    shlo_r_imm_alt_64: 156,
    shar_r_imm_alt_64: 157,
    rot_r_64_imm: 158,
    rot_r_64_imm_alt: 159,
    rot_r_32_imm: 160,
    rot_r_32_imm_alt: 161,
    branch_eq: 170,
    branch_ne: 171,
    branch_lt_u: 172,
    branch_lt_s: 173,
    branch_ge_u: 174,
    branch_ge_s: 175,
    load_imm_jump_ind: 180,
    add_32: 190,
    sub_32: 191,
    mul_32: 192,
    div_u_32: 193,
    div_s_32: 194,
    rem_u_32: 195,
    rem_s_32: 196,
    shlo_l_32: 197,
    shlo_r_32: 198,
    shar_r_32: 199,
    add_64: 200,
    sub_64: 201,
    mul_64: 202,
    div_u_64: 203,
    div_s_64: 204,
    rem_u_64: 205,
    rem_s_64: 206,
    shlo_l_64: 207,
    shlo_r_64: 208,
    shar_r_64: 209,
    and: 210,
    xor: 211,
    or: 212,
    mul_upper_s_s: 213,
    mul_upper_u_u: 214,
    mul_upper_s_u: 215,
    set_lt_u: 216,
    set_lt_s: 217,
    cmov_iz: 218,
    cmov_nz: 219,
    rot_l_64: 220,
    rot_l_32: 221,
    rot_r_64: 222,
    rot_r_32: 223,
    and_inv: 224,
    or_inv: 225,
    xnor: 226,
    max: 227,
    max_u: 228,
    min: 229,
    min_u: 230
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
    rot_r_64_imm: 0,
    rot_r_64_imm_alt: 0,
    rot_r_32_imm: 0,
    rot_r_32_imm_alt: 0,
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
    sbrk: 0,
    count_set_bits_64: 0,
    count_set_bits_32: 0,
    leading_zero_bits_64: 0,
    leading_zero_bits_32: 0,
    trailing_zero_bits_64: 0,
    trailing_zero_bits_32: 0,
    sign_extend_8: 0,
    sign_extend_16: 0,
    zero_extend_16: 0,
    reverse_bytes: 0,
    add_32: 0,
    sub_32: 0,
    mul_32: 0,
    div_u_32: 0,
    div_s_32: 0,
    rem_u_32: 0,
    rem_s_32: 0,
    shlo_l_32: 0,
    shlo_r_32: 0,
    shar_r_32: 0,
    add_64: 0,
    sub_64: 0,
    mul_64: 0,
    div_u_64: 0,
    div_s_64: 0,
    rem_u_64: 0,
    rem_s_64: 0,
    shlo_l_64: 0,
    shlo_r_64: 0,
    shar_r_64: 0,
    and: 0,
    xor: 0,
    or: 0,
    mul_upper_s_s: 0,
    mul_upper_u_u: 0,
    mul_upper_s_u: 0,
    set_lt_u: 0,
    set_lt_s: 0,
    cmov_iz: 0,
    cmov_nz: 0,
    rot_l_64: 0,
    rot_l_32: 0,
    rot_r_64: 0,
    rot_r_32: 0,
    and_inv: 0,
    or_inv: 0,
    xnor: 0,
    max: 0,
    max_u: 0,
    min: 0,
    min_u: 0
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
    two_registers: [
      :move_reg,
      :sbrk,
      :count_set_bits_64,
      :count_set_bits_32,
      :leading_zero_bits_64,
      :leading_zero_bits_32,
      :trailing_zero_bits_64,
      :trailing_zero_bits_32,
      :sign_extend_8,
      :sign_extend_16,
      :zero_extend_16,
      :reverse_bytes
    ],
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
      :shar_r_imm_alt_64,
      :rot_r_64_imm,
      :rot_r_64_imm_alt,
      :rot_r_32_imm,
      :rot_r_32_imm_alt
    ],
    two_registers_one_offset: [
      :branch_eq,
      :branch_ne,
      :branch_lt_u,
      :branch_lt_s,
      :branch_ge_u,
      :branch_ge_s
    ],
    two_registers_two_immediates: [
      :load_imm_jump_ind
    ],
    three_registers: [
      :add_32,
      :sub_32,
      :mul_32,
      :div_u_32,
      :div_s_32,
      :rem_u_32,
      :rem_s_32,
      :shlo_l_32,
      :shlo_r_32,
      :shar_r_32,
      :add_64,
      :sub_64,
      :mul_64,
      :div_u_64,
      :div_s_64,
      :rem_u_64,
      :rem_s_64,
      :shlo_l_64,
      :shlo_r_64,
      :shar_r_64,
      :and,
      :xor,
      :or,
      :mul_upper_s_s,
      :mul_upper_u_u,
      :mul_upper_s_u,
      :set_lt_u,
      :set_lt_s,
      :cmov_iz,
      :cmov_nz,
      :rot_l_64,
      :rot_l_32,
      :rot_r_64,
      :rot_r_32,
      :and_inv,
      :or_inv,
      :xnor,
      :max,
      :max_u,
      :min,
      :min_u
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

  def gas_cost_map, do: @gas_cost_map

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
