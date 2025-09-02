defmodule PVM.Instructions.Executor do
  import PVM.Instructions.DispatchMacro

  no_args_direct_dispatch([
    :trap,
    :fallthrough
  ])

  one_immediate_direct_dispatch([
    :ecalli,
    :jump
  ])

  two_immediates_direct_dispatch([
    :store_imm_u8,
    :store_imm_u16,
    :store_imm_u32,
    :store_imm_u64
  ])

  reg_immediate_direct_dispatch([
    :load_imm_64,
    :jump_ind,
    :load_imm,
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
  ])

  reg_two_imm_direct_dispatch([
    :store_imm_ind_u8,
    :store_imm_ind_u16,
    :store_imm_ind_u32,
    :store_imm_ind_u64
  ])

  reg_immediate_offset_direct_dispatch([
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
  ])

  two_registers_direct_dispatch([
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
  ])

  two_registers_one_immediate_direct_dispatch([
    :store_ind_u8,
    :store_ind_u16,
    :store_ind_u32,
    :store_ind_u64,
    :load_ind_u8,
    :load_ind_u16,
    :load_ind_u32,
    :load_ind_u64,
    :load_ind_i8,
    :load_ind_i16,
    :load_ind_i32,
    :add_imm_32,
    :mul_imm_32,
    :neg_add_imm_32,
    :and_imm,
    :xor_imm,
    :or_imm,
    :set_lt_u_imm,
    :set_lt_s_imm,
    :set_gt_u_imm,
    :set_gt_s_imm,
    :shlo_l_imm_32,
    :shlo_r_imm_32,
    :shar_r_imm_32,
    :shlo_l_imm_alt_32,
    :shlo_r_imm_alt_32,
    :shar_r_imm_alt_32,
    :cmov_iz_imm,
    :cmov_nz_imm,
    :add_imm_64,
    :mul_imm_64,
    :neg_add_imm_64,
    :shlo_l_imm_64,
    :shlo_r_imm_64,
    :shar_r_imm_64,
    :shlo_l_imm_alt_64,
    :shlo_r_imm_alt_64,
    :shar_r_imm_alt_64,
    :rot_r_64_imm,
    :rot_r_64_imm_alt,
    :rot_r_32_imm,
    :rot_r_32_imm_alt
  ])

  two_registers_one_offset_direct_dispatch([
    :branch_eq,
    :branch_ne,
    :branch_lt_u,
    :branch_lt_s,
    :branch_ge_u,
    :branch_ge_s
  ])

  two_registers_two_immediates_direct_dispatch([
    :load_imm_jump_ind
  ])

  three_registers_direct_dispatch([
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
    :and_inv,
    :or_inv,
    :xnor,
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
    :max,
    :max_u,
    :min,
    :min_u
  ])

  # Formula (A.17) v0.7.0
  def branch(_value, false, counter, _start_set), do: {:continue, counter}

  def branch(value, true, counter, start_set) do
    if Map.has_key?(start_set, value) do
      {:continue, value}
    else
      {:panic, counter}
    end
  end

  # Formula (A.18) v0.7.0
  def djump(a, counter, jump_table, start_set) do
    alignment_factor = 2
    {quotient, remainder} = {div(a, alignment_factor), rem(a, alignment_factor)}
    jump_to = get_jump_target(jump_table, quotient - 1)

    case a do
      # 2^32 - 2^16
      0xFFFF0000 ->
        {:halt, counter}

      0 ->
        {:panic, counter}

      a when a > length(jump_table) * alignment_factor ->
        {:panic, counter}

      _ when remainder != 0 ->
        {:panic, counter}

      _ ->
        if Map.has_key?(start_set, jump_to) do
          {:continue, jump_to}
        else
          {:panic, counter}
        end
    end
  end

  defp get_jump_target(jump_table, index) do
    if index >= 0 and index < tuple_size(jump_table) do
      elem(jump_table, index)
    else
      nil
    end
  end
end
