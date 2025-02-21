defmodule PVM.Utils.ProgramUtils do
  use PVM.Instructions

  @doc """
  Appends halt sequence to a program and its bitmask.
  Uses jump_ind with register 12 (last register) to minimize conflicts.

  Returns {new_program, new_bitmask}.
  """
  def append_halt(program, bitmask) do
    halt_sequence = <<op(:jump_ind), 12, 0, 0, 0xFF, 0xFF, 0,0>>

    halt_bitmask = <<128>>

    {program <> halt_sequence, bitmask <> halt_bitmask}
  end

  @doc """
  Creates a minimal program that just halts.
  Returns {program, bitmask}.
  """
  def create_halt_program do
    append_halt(<<>>, <<>>)
  end
end
