# Formula (A.5) v0.5

defmodule StepOutput do
  @type t :: %__MODULE__{
          exit_status:
            :continue | :panic | :out_of_gas | {:fault, non_neg_integer()} | {:ecall, integer()},
          counter: non_neg_integer(),
          gas: non_neg_integer(),
          registers: list(integer()),
          memory: Memory.t()
        }

  defstruct exit_status: :continue,
            counter: 0,
            gas: 0,
            registers: List.duplicate(0, 13),
            memory: %Memory{}

  def from_state(%PVM.State{} = state) do
    %__MODULE__{
      exit_status: :continue,
      counter: state.counter,
      gas: state.gas,
      registers: state.registers,
      memory: state.memory
    }
  end
end
