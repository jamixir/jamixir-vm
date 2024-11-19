# Formula (237) v0.4.5

defmodule PVM.State do
  defstruct program: <<>>,
            bitmask: <<>>,
            jump_table: [],
            counter: 0,
            gas: 100,
            registers: List.duplicate(0, 13),
            memory: %Memory{}

  def new(program, bitmask, jump_table, %StepOutput{} = output) do
    %__MODULE__{
      program: program,
      bitmask: bitmask,
      jump_table: jump_table,
      counter: output.counter,
      gas: output.gas,
      registers: output.registers,
      memory: output.memory
    }
  end

end
