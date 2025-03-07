defmodule PVM.Types do
  @moduledoc """
  Common types used across the PVM implementation.
  """
  alias PVM.{Memory, Registers, State}

  @type exit_reason :: :continue | :halt | :panic | :out_of_gas
  @type vm_exit_reason :: exit_reason | fault_result() | ecall_result()

  @type fault_result :: {:fault, non_neg_integer()}
  @type ecall_result :: {:ecall, non_neg_integer()}

  @type context :: any()

  @type host_call_state :: %{
          gas: non_neg_integer(),
          registers: Registers.t(),
          memory: Memory.t()
        }

  @type host_fn :: (non_neg_integer(), host_call_state(), context() ->
                      {exit_reason(), State.t(), context()} | fault_result())
end
