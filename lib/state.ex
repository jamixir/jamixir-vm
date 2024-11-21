# Formula (A.5) v0.5

defmodule PVM.State do
  # 2^64 - 1
  @type u64 :: 0..18_446_744_073_709_551_615

  @type t :: %__MODULE__{
          program: binary(),
          bitmask: binary(),
          jump_table: list(non_neg_integer()),
          counter: non_neg_integer(),
          gas: non_neg_integer(),
          registers: list(u64),
          memory: Memory.t()
        }
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
