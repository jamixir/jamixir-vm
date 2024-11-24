# Formula (A.5) v0.5

defmodule PVM.State do
  @type t :: %__MODULE__{
          counter: non_neg_integer(),
          gas: non_neg_integer(),
          registers: list(integer()),
          memory: Memory.t()
        }

  defstruct counter: 0,
            gas: 0,
            registers: List.duplicate(0, 13),
            memory: %Memory{}
end
