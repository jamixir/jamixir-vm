defmodule PVM.VectorsTest do
  use ExUnit.Case
  import PVM.Utils.JsonTestRunner

  System.put_env("PVM_TEST_VECTORS", "true")

  @test_files_dir "../koute-pvm-test-vectors/pvm/programs"
  @test_files PVM.Vectors.test_files()

  @max_tests_to_run 69
  # generate_limited_json_tests(@test_files_dir, @test_files, @max_tests_to_run)

  @tag :test_vectors
  # @tag :skip
  test "run specific test file" do
    test_name = "inst_load_i16"
    file_path = Path.join(@test_files_dir, "#{test_name}.json")

    run_json_test(test_name, file_path)
  end
end
