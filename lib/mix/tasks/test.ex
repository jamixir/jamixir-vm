defmodule Mix.Tasks.Test.Pvm do
  use Mix.Task

  @shortdoc "Runs tests with PVM tracing enabled"
  @preferred_cli_env [test: :test]

  @moduledoc """
  Runs tests with PVM tracing enabled.

  ## Usage

      mix test.pvm [test_files] [test_filters]

  All normal test options are supported. The PVM trace will be automatically enabled.
  """

  @impl true
  def run(args) do
    System.put_env("MIX_TEST_PVM_TRACE", "true")
    Mix.Task.run("test", args)
  end
end
