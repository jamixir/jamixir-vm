defmodule PVM.Utils.JsonTestRunner do
  @moduledoc """
  Utility for running VM tests from JSON test cases.
  """

  alias PVM.{State, Memory, VM, Registers}
  use ExUnit.Case

  @doc """
  Macro that generates a test for each JSON file in the specified directory.
  Each test will be named after the JSON file's test name.
  """
  defmacro generate_json_tests(test_dir) do
    quote bind_quoted: [test_dir: test_dir] do
      test_files = Path.wildcard("#{test_dir}/*.json")

      for file_path <- test_files do
        test_name = Path.basename(file_path, ".json")

        file_path_string = "#{file_path}"

        @tag :test_vectors
        test "#{test_name}" do
          PVM.Utils.JsonTestRunner.run_json_test(unquote(file_path_string))
        end
      end
    end
  end

  defmacro generate_limited_json_tests(test_dir, test_files, max_tests) do
    quote bind_quoted: [test_dir: test_dir, test_files: test_files, max_tests: max_tests] do
      limited_files = Enum.take(test_files, max_tests)

      for file_name <- limited_files do
        test_name = Path.basename(file_name, ".json")
        file_path = Path.join(test_dir, file_name)

        @tag :test_vectors
        test "#{test_name}" do
          PVM.Utils.JsonTestRunner.run_json_test(unquote(file_path))
        end
      end
    end
  end

  @doc """
  Runs a test from a JSON file path.
  """
  def run_json_test(file_path) do
    # Load the test case
    test_case = file_path |> File.read!() |> Jason.decode!()

    # Set up initial state and program
    {state, program} = setup_initial_state(test_case)

    # Execute the program
    {exit_reason, final_state} = VM.execute(program, state)

    # Get expected values
    expected = get_expected_values(test_case)

    # Check exit reason
    case {exit_reason, expected.exit_reason} do
      {_e, ^exit_reason} ->
        :ok

      # We don't check the exact fault address
      {{:fault, _}, {:fault, _}} ->
        :ok

      # We don't check the exact ecall number
      {{:ecall, _}, {:ecall, _}} ->
        :ok

      _ ->
        flunk(
          "Exit reason: expected #{inspect(expected.exit_reason)}, got #{inspect(exit_reason)}"
        )
    end

    # Check PC (only if exit reason is not halt or panic)
    # in the gp, counter is set to 0, but the test vectors dont match this behavior
    # TODO: check again if/when the test vectors are updated (written in 05.03.2025, TestVecotr V0.4)
    unless exit_reason in [:halt, :panic] do
      assert final_state.counter == expected.pc,
             "PC: expected #{expected.pc}, got #{final_state.counter}"
    end

    # Check registers
    actual_regs = Enum.map(0..12, &Registers.get(final_state.registers, &1))

    if actual_regs != expected.regs do
      # Find which registers differ for better error messages
      diffs =
        Enum.with_index(Enum.zip(actual_regs, expected.regs))
        |> Enum.filter(fn {{actual, expected}, _} -> actual != expected end)
        |> Enum.map(fn {{actual, expected}, idx} ->
          "r#{idx}: expected #{expected}, got #{actual}"
        end)

      flunk("Registers differ:\n#{Enum.join(diffs, "\n")}")
    end

    # Check memory
    Enum.each(expected.memory, fn [address, expected_value, size] ->
      case Memory.read(final_state.memory, address, size) do
        {:ok, data} ->
          actual_value = value_from_binary(data, size)

          assert actual_value == expected_value,
                 "Memory at #{address}: expected #{expected_value}, got #{actual_value}"

        {:error, reason} ->
          flunk("Failed to read memory at #{address}: #{inspect(reason)}")
      end
    end)

    # Check gas
    assert final_state.gas == expected.gas,
           "Gas: expected #{expected.gas}, got #{final_state.gas}"
  end

  @doc """
  Sets up the initial state and program from a test case.
  Returns {state, program}.
  """
  def setup_initial_state(test_case) do
    # Extract test data
    initial_regs = test_case["initial-regs"]
    initial_pc = test_case["initial-pc"]
    initial_page_map = test_case["initial-page-map"] || []
    initial_memory_entries = test_case["initial-memory"] || []
    initial_gas = test_case["initial-gas"]
    program_bytes = test_case["program"]

    # Convert program to binary
    program = :binary.list_to_bin(program_bytes)

    # Set up initial state
    state = %State{
      counter: initial_pc,
      gas: initial_gas,
      registers: Registers.from_list(initial_regs),
      memory: setup_memory(initial_page_map, initial_memory_entries)
    }

    {state, program}
  end

  @doc """
  Extracts expected values from a test case.
  Returns a map with all expected values.
  """
  def get_expected_values(test_case) do
    expected_status = test_case["expected-status"]

    %{
      exit_reason: parse_expected_status(expected_status),
      pc: test_case["expected-pc"],
      regs: test_case["expected-regs"],
      memory: test_case["expected-memory"] || [],
      gas: test_case["expected-gas"]
    }
  end

  @doc """
  Returns true if test vectors mode is enabled.
  """
  def test_vectors_mode? do
    System.get_env("PVM_TEST_VECTORS") == "true"
  end

  @doc """
  Returns the gas cost map to use based on the current environment.
  When PVM_TEST_VECTORS=true, uses the test vector gas costs.
  """
  def get_gas_cost_map do
    if test_vectors_mode?() do
      # Special gas costs for test vectors
      %{
        trap: 0,
        fallthrough: 0,
        ecalli: 1,
        load_imm_64: 1,
        store_imm_u8: 1,
        store_imm_u16: 1,
        store_imm_u32: 1,
        store_imm_u64: 1,
        jump: 1,
        jump_ind: 1,
        load_imm: 1,
        load_u8: 1,
        load_i8: 1,
        load_u16: 1,
        load_i16: 1,
        load_u32: 1,
        load_i32: 1,
        load_u64: 1,
        store_u8: 1,
        store_u16: 1,
        store_u32: 1,
        store_u64: 1,
        store_imm_ind_u8: 1,
        store_imm_ind_u16: 1,
        store_imm_ind_u32: 1,
        store_imm_ind_u64: 1,
        load_imm_jump: 1,
        load_imm_jump_ind: 1,
        store_ind_u8: 1,
        store_ind_u16: 1,
        store_ind_u32: 1,
        store_ind_u64: 1,
        load_ind_u8: 1,
        load_ind_i8: 1,
        load_ind_u16: 1,
        load_ind_i16: 1,
        load_ind_u32: 1,
        load_ind_i32: 1,
        load_ind_u64: 1,
        add_imm_32: 1,
        and_imm: 1,
        xor_imm: 1,
        or_imm: 1,
        mul_imm_32: 1,
        set_lt_u_imm: 1,
        set_lt_s_imm: 1,
        shlo_l_imm_32: 1,
        shlo_r_imm_32: 1,
        shar_r_imm_32: 1,
        neg_add_imm_32: 1,
        set_gt_u_imm: 1,
        set_gt_s_imm: 1,
        shlo_l_imm_alt_32: 1,
        shlo_r_imm_alt_32: 1,
        shar_r_imm_alt_32: 1,
        cmov_iz_imm: 1,
        cmov_nz_imm: 1,
        add_imm_64: 1,
        mul_imm_64: 1,
        shlo_l_imm_64: 1,
        shlo_r_imm_64: 1,
        shar_r_imm_64: 1,
        neg_add_imm_64: 1,
        shlo_l_imm_alt_64: 1,
        shlo_r_imm_alt_64: 1,
        shar_r_imm_alt_64: 1,
        rot_r_64_imm: 1,
        rot_r_64_imm_alt: 1,
        rot_r_32_imm: 1,
        rot_r_32_imm_alt: 1,
        branch_eq: 1,
        branch_ne: 1,
        branch_ge_u: 1,
        branch_ge_s: 1,
        branch_lt_u: 1,
        branch_lt_s: 1,
        branch_eq_imm: 1,
        branch_ne_imm: 1,
        branch_lt_u_imm: 1,
        branch_lt_s_imm: 1,
        branch_le_u_imm: 1,
        branch_le_s_imm: 1,
        branch_ge_u_imm: 1,
        branch_ge_s_imm: 1,
        branch_gt_u_imm: 1,
        branch_gt_s_imm: 1,
        move_reg: 1,
        sbrk: 1,
        count_set_bits_64: 1,
        count_set_bits_32: 1,
        leading_zero_bits_64: 1,
        leading_zero_bits_32: 1,
        trailing_zero_bits_64: 1,
        trailing_zero_bits_32: 1,
        sign_extend_8: 1,
        sign_extend_16: 1,
        zero_extend_16: 1,
        reverse_bytes: 1,
        add_32: 1,
        sub_32: 1,
        mul_32: 1,
        div_u_32: 1,
        div_s_32: 1,
        rem_u_32: 1,
        rem_s_32: 1,
        shlo_l_32: 1,
        shlo_r_32: 1,
        shar_r_32: 1,
        add_64: 1,
        sub_64: 1,
        mul_64: 1,
        div_u_64: 1,
        div_s_64: 1,
        rem_u_64: 1,
        rem_s_64: 1,
        shlo_l_64: 1,
        shlo_r_64: 1,
        shar_r_64: 1,
        and: 1,
        xor: 1,
        or: 1,
        mul_upper_s_s: 1,
        mul_upper_u_u: 1,
        mul_upper_s_u: 1,
        set_lt_u: 1,
        set_lt_s: 1,
        cmov_iz: 1,
        cmov_nz: 1,
        rot_l_64: 1,
        rot_l_32: 1,
        rot_r_64: 1,
        rot_r_32: 1,
        and_inv: 1,
        or_inv: 1,
        xnor: 1,
        max: 1,
        max_u: 1,
        min: 1,
        min_u: 1
      }
    else
      # Use the default gas costs
      PVM.Instructions.gas_cost_map()
    end
  end

  # Private helper functions

  @doc false
  def setup_memory(page_map, memory_entries) do
    memory = %Memory{}

    # Set up page access permissions if any
    memory =
      if Enum.empty?(page_map) do
        memory
      else
        Enum.reduce(page_map, memory, fn entry, acc ->
          [page, access] = entry

          Memory.set_access(
            acc,
            page * memory.page_size,
            1,
            access_atom(access)
          )
        end)
      end

    # Set up initial memory values if any
    if Enum.empty?(memory_entries) do
      memory
    else
      Enum.reduce(memory_entries, memory, fn entry, acc ->
        [address, value, size] = entry

        {:ok, mem} =
          Memory.write(acc, address, binary_for_value(value, size))

        mem
      end)
    end
  end

  @doc false
  def binary_for_value(value, size) do
    case size do
      1 -> <<value::8>>
      2 -> <<value::little-16>>
      4 -> <<value::little-32>>
      8 -> <<value::little-64>>
    end
  end

  @doc false
  def access_atom(access_str) do
    case access_str do
      "read" -> :read
      "write" -> :write
      "none" -> nil
    end
  end

  @doc false
  def parse_expected_status(status) do
    case status do
      "panic" -> :panic
      "halt" -> :halt
      "out_of_gas" -> :out_of_gas
      # Placeholder, actual address will be checked separately
      "fault" -> {:fault, 0}
      # Placeholder, actual number will be checked separately
      "ecall" -> {:ecall, 0}
    end
  end

  @doc false
  def value_from_binary(binary, size) do
    case size do
      1 -> :binary.decode_unsigned(binary, :little)
      2 -> :binary.decode_unsigned(binary, :little)
      4 -> :binary.decode_unsigned(binary, :little)
      8 -> :binary.decode_unsigned(binary, :little)
    end
  end
end
