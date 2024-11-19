defmodule Instructions.NoArgsTest do
  use ExUnit.Case
  alias Instructions.NoArgs

  describe "trap" do
    test "sets panic exit status" do
      output = NoArgs.execute(:trap, %StepOutput{})
      assert output.exit_status == :panic
    end
  end

  describe "fallthrough" do
    test "keeps existing output unchanged" do
      initial_output = %StepOutput{
        exit_status: :continue,
        counter: 1,
        gas: 100,
        registers: [0,1,2],
        memory: Memory.new()
      }
      output = NoArgs.execute(:fallthrough, initial_output)
      assert output == initial_output
    end
  end
end 
