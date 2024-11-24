defmodule Instructions.NoArgs do
  # Section (A.5.1) v0.4.5
  def execute(:trap, _program, _bitmask, _jump_table, state),
    do: {:panic, state}

  def execute(:fallthrough, _program, _bitmask, _jump_table, state),
    do: {:continue, state}
end
