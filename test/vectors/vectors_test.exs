defmodule PVM.VectorsTest do
  use ExUnit.Case
  import PVM.Utils.JsonTestRunner

  @test_files_dir "../koute-pvm-test-vectors/pvm/programs"

  @test_files PVM.Vectors.test_files()

  # Set the maximum number of tests to run
  # You can adjust this value to control how many tests are executed
  @max_tests_to_run 8

  System.put_env("PVM_TEST_VECTORS", "true")


  generate_limited_json_tests(@test_files_dir, @test_files, @max_tests_to_run)

end
