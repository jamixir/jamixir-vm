# Formula (A.6) v0.7.0

defmodule PVM.State do
  alias PVM.Registers

  @type t :: %__MODULE__{
          # i
          counter: non_neg_integer(),
          # q
          gas: non_neg_integer(),
          # ω
          registers: Registers.t(),
          # µ
          memory: PVM.Memory.t()
        }

  defstruct counter: 0,
            gas: 0,
            registers: nil,
            memory: %PVM.Memory{}

  def new() do
    %__MODULE__{
      counter: 0,
      gas: 0,
      registers: Registers.new(),
      memory: %PVM.Memory{}
    }
  end
end
