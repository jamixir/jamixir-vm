defmodule PVM.VectorsTest do
  use ExUnit.Case
  import PVM.Utils.JsonTestRunner

  System.put_env("PVM_TEST_VECTORS", "true")

  @test_files_dir "../koute-pvm-test-vectors/pvm/programs"
  # @test_files PVM.Vectors.test_files()

  generate_json_tests(@test_files_dir)

  @tag :test_vectors
   @tag :skip
  test "run specific test file" do
    test_name = "riscv_rv64uzbb_ctz"
    file_path = Path.join(@test_files_dir, "#{test_name}.json")

    run_json_test(file_path)
  end
end
