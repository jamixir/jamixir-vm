defmodule PVM.Registers do
  defstruct r0: 0,
            r1: 0,
            r2: 0,
            r3: 0,
            r4: 0,
            r5: 0,
            r6: 0,
            r7: 0,
            r8: 0,
            r9: 0,
            r10: 0,
            r11: 0,
            r12: 0

  @type register :: :r0 | :r1 | :r2 | :r3 | :r4 | :r5 | :r6 | :r7 | :r8 | :r9 | :r10 | :r11 | :r12 | 0..12
  @type t :: %__MODULE__{}

  @spec get(t(), register() | [register()]) :: integer() | %{register() => integer()}
  def get(%__MODULE__{} = reg, register) when is_atom(register) do
    Map.get(reg, register)
  end

  def get(%__MODULE__{} = reg, registers) when is_list(registers) do
    registers
    |> Enum.map(fn
      reg_num when is_integer(reg_num) -> String.to_atom("r#{reg_num}")
      reg_atom -> reg_atom
    end)
    |> Enum.map(fn reg_name -> Map.get(reg, reg_name) end)
  end

  def get(%__MODULE__{} = reg, register) when is_integer(register) and register in 0..12 do
    get(reg, String.to_atom("r#{register}"))
  end

  @spec set(t(), register(), integer()) :: t()
  @spec set(t(), %{register() => integer()}) :: t()
  def set(%__MODULE__{} = reg, register, value) when is_atom(register) and is_integer(value) do
    %{reg | register => value}
  end

  def set(%__MODULE__{} = reg, updates) when is_map(updates) do
    updates
    |> Enum.map(fn
      {reg_num, value} when is_integer(reg_num) -> {String.to_atom("r#{reg_num}"), value}
      other -> other
    end)
    |> Map.new()
    |> then(fn updates -> struct!(reg, updates) end)
  end

  def set(%__MODULE__{} = reg, register, value) when is_integer(register) and register in 0..12 and is_integer(value) do
    set(reg, String.to_atom("r#{register}"), value)
  end
end
