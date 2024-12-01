# Formula (A.5) v0.5

defmodule PVM.State do
  alias PVM.Registers
  @type t :: %__MODULE__{
          counter: non_neg_integer(),
          gas: non_neg_integer(),
          registers: Registers.t(),
          memory: PVM.Memory.t()
        }

  defstruct counter: 0,
            gas: 0,
            registers: %Registers{},
            memory: %PVM.Memory{}
end
