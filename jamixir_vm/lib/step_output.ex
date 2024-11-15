defmodule StepOutput do
  defstruct exit_status: :continue,
            counter: 0,
            gas: 0,
            registers: List.duplicate(0, 13),
            memory: Memory.new()

  def new(opts \\ []) do
    %__MODULE__{
      exit_status: Keyword.get(opts, :exit_status, :continue),
      counter: Keyword.get(opts, :counter, 0),
      gas: Keyword.get(opts, :gas, 0),
      registers: Keyword.get(opts, :registers, List.duplicate(0, 13)),
      memory: Keyword.get(opts, :memory, Memory.new())
    }
  end

  def from_state(%PVM.State{} = state) do
    %__MODULE__{
      exit_status: :continue,
      counter: state.counter,
      gas: state.gas,
      registers: state.registers,
      memory: state.memory
    }
  end

  def with_exit_status(%__MODULE__{} = output, exit_status) do
    %{output | exit_status: exit_status}
  end

  def with_counter(%__MODULE__{} = output, counter) do
    %{output | counter: counter}
  end

  def with_gas(%__MODULE__{} = output, gas) do
    %{output | gas: gas}
  end

  def with_memory(%__MODULE__{} = output, memory) do
    %{output | memory: memory}
  end

  def with_registers(%__MODULE__{} = output, registers) do
    %{output | registers: registers}
  end

  # Helper to create a standard transition
  def standard_transition(%PVM.State{} = state, skip_amount, gas_cost) do
    %__MODULE__{
      exit_status: :continue,
      counter: state.counter + 1 + skip_amount,
      gas: state.gas - gas_cost,
      registers: state.registers,
      memory: state.memory
    }
  end
end
