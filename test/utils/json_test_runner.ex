defmodule PVM.Utils.JsonTestRunner do


  alias PVM.{State, Memory, VM, Registers}
  import PVM.Memory.Constants
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


  @doc """
  Runs a test from a JSON file path.
  """
  def run_json_test(file_path) do
    test_case =
      file_path
      |> File.read!()
      |> Jason.decode!()
      |> keys_to_atoms()

    {state, program} = setup_initial_state(test_case)

    {exit_reason, final_state} = VM.execute(program, state)

    expected = get_expected_values(test_case)

    # Check exit reason
    case {exit_reason, expected.exit_reason} do
      {_e, ^exit_reason} ->
        :ok

      # don't check the exact fault address
      {{:fault, _}, {:fault, _}} ->
        :ok

      # don't check the exact ecall number
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
    Enum.each(expected.memory, fn %{address: address, contents: contents} ->
      expected_value = :binary.list_to_bin(contents)
      size = length(contents)

      case Memory.read(final_state.memory, address, size) do
        {:ok, data} ->
          assert data == expected_value,
                 "Memory at #{address}: expected #{expected_value}, got #{data}"

        {:error, reason} ->
          flunk("Failed to read memory at #{address}: #{inspect(reason)}")
      end
    end)

    # Check gas
    # TODO: check again if/when the test vectors are updated (written in 05.03.2025, TestVecotr V0.4)
    # gas model is not set in the gp the test vectors have their own, unkown gas model
    # assert final_state.gas == expected.gas,
    #        "Gas: expected #{expected.gas}, got #{final_state.gas}"
  end


  def setup_initial_state(test_case) do
    initial_regs = Map.get(test_case, :"initial-regs")
    initial_pc = Map.get(test_case, :"initial-pc")
    initial_page_map = Map.get(test_case, :"initial-page-map", [])
    initial_memory_entries = Map.get(test_case, :"initial-memory", [])
    initial_gas = Map.get(test_case, :"initial-gas")
    program_bytes = Map.get(test_case, :program)

    program = :binary.list_to_bin(program_bytes)

    state = %State{
      counter: initial_pc,
      gas: initial_gas,
      registers: Registers.from_list(initial_regs),
      memory: setup_memory(initial_page_map, initial_memory_entries)
    }

    {state, program}
  end

  def get_expected_values(test_case) do
    expected_status = Map.get(test_case, :"expected-status")

    %{
      exit_reason: parse_expected_status(expected_status),
      pc: Map.get(test_case, :"expected-pc"),
      regs: Map.get(test_case, :"expected-regs"),
      memory: Map.get(test_case, :"expected-memory", []),
      gas: Map.get(test_case, :"expected-gas")
    }
  end

  def setup_memory(page_map, memory_entries) do
    pre_memory =
      PVM.PreMemory.set_access(
        %PVM.PreMemory{},
        min_allowed_address(),
        memory_size() - min_allowed_address(),
        nil
      )

    # Set up page access permissions
    pre_memory =
      if Enum.empty?(page_map) do
        pre_memory
      else
        Enum.reduce(page_map, pre_memory, fn entry, acc ->
          address = entry.address
          length = entry.length
          # Only support is-writable for now
          access_type =
            if Map.get(entry, :"is-writable"),
              do: :write,
              else: :read

          PVM.PreMemory.set_access(acc, address, length, access_type)
        end)
      end

    # Write memory contents
    pre_memory =
      if Enum.empty?(memory_entries) do
        pre_memory
      else
        Enum.reduce(memory_entries, pre_memory, fn entry, acc ->
          address = entry.address
          contents = :binary.list_to_bin(entry.contents)

          PVM.PreMemory.write(acc, address, contents)
        end)
      end

    pre_memory = PVM.PreMemory.resolve_overlaps(pre_memory)
    PVM.PreMemory.finalize(pre_memory)
  end

  def binary_for_value(value, size) do
    case size do
      1 -> <<value::8>>
      2 -> <<value::little-16>>
      4 -> <<value::little-32>>
      8 -> <<value::little-64>>
    end
  end


  def parse_expected_status(status) do
    case status do
      "panic" -> :panic
      "halt" -> :halt
      "out_of_gas" -> :out_of_gas
      "page-fault" -> {:fault, 0}
      "ecall" -> {:ecall, 0}
    end
  end

  defp keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) ->
        {String.to_atom(key), keys_to_atoms(value)}

      {key, value} when is_list(value) ->
        {String.to_atom(key), Enum.map(value, &maybe_keys_to_atoms/1)}

      {key, value} ->
        {String.to_atom(key), value}
    end)
  end

  defp maybe_keys_to_atoms(value) when is_map(value), do: keys_to_atoms(value)
  defp maybe_keys_to_atoms(value), do: value
end
