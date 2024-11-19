defmodule PVM.State do
  defstruct program: <<>>,
            bitmask: <<>>,
            jump_table: [],
            counter: 0,
            gas: 100,
            registers: List.duplicate(0, 13),
            memory: Memory.new()  # 100 bytes

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

  def with_counter(%__MODULE__{} = state, counter) do
    %{state | counter: counter}
  end

  def with_gas(%__MODULE__{} = state, gas) do
    %{state | gas: gas}
  end

  def with_memory(%__MODULE__{} = state, memory) do
    %{state | memory: memory}
  end

  def with_registers(%__MODULE__{} = state, registers) do
    %{state | registers: registers}
  end
end
