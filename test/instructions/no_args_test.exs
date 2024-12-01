defmodule Instructions.NoArgsTest do
  use ExUnit.Case
  alias PVM.{Instructions.NoArgs, Registers}

  describe "trap" do
    test "sets panic exit status" do
      {exit_reason, _} = NoArgs.execute(:trap, %PVM.State{})
      assert exit_reason == :panic
    end
  end

  describe "fallthrough" do
    test "keeps existing output unchanged" do
      initial_state = %PVM.State{
        counter: 1,
        gas: 100,
        registers: %Registers{r0: 0, r1: 1, r2: 2},
      }

      {exit_reason, state_} = NoArgs.execute(:fallthrough, initial_state)
      assert exit_reason == :continue
      assert state_ == initial_state
    end
  end
end
