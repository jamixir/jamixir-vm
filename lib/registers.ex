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

  @type register ::
          :r0 | :r1 | :r2 | :r3 | :r4 | :r5 | :r6 | :r7 | :r8 | :r9 | :r10 | :r11 | :r12 | 0..12
  @type t :: %__MODULE__{}

  @doc """
  Creates a new Registers struct from a list of values.
  The list should contain exactly 13 integers, one for each register (r0 to r12).
  """
  @spec from_list([integer()]) :: t()
  def from_list(values) when is_list(values) and length(values) == 13 do
    [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12] = values

    %__MODULE__{
      r0: r0,
      r1: r1,
      r2: r2,
      r3: r3,
      r4: r4,
      r5: r5,
      r6: r6,
      r7: r7,
      r8: r8,
      r9: r9,
      r10: r10,
      r11: r11,
      r12: r12
    }
  end

  @spec get(t(), register()) :: integer()
  def get(%__MODULE__{} = reg, register) when is_atom(register) do
    Map.get(reg, register)
  end

  @spec get(t(), [atom()]) :: [integer()]
  def get(%__MODULE__{} = reg, registers) when is_list(registers) and is_atom(hd(registers)) do
    Enum.map(registers, &Map.get(reg, &1))
  end

  @spec get(t(), [integer()]) :: [integer()]
  def get(%__MODULE__{} = reg, registers) when is_list(registers) and is_integer(hd(registers)) do
    registers
    |> Enum.map(&String.to_atom("r#{&1}"))
    |> Enum.map(&Map.get(reg, &1))
  end

  @spec get(t(), integer()) :: integer()
  def get(%__MODULE__{} = reg, register) when is_integer(register) and register in 0..12 do
    get(reg, String.to_atom("r#{register}"))
  end

  @spec set(t(), atom(), integer()) :: t()
  def set(%__MODULE__{} = reg, register, value) when is_atom(register) and is_integer(value) do
    %{reg | register => value}
  end

  @spec set(t(), integer(), integer()) :: t()
  def set(%__MODULE__{} = reg, register, value)
      when is_integer(register) and register in 0..12 and is_integer(value) do
    set(reg, String.to_atom("r#{register}"), value)
  end

  @spec set(t(), %{atom() => integer()}) :: t()
  def set(%__MODULE__{} = reg, updates) when is_map(updates) do
    case updates do
      %{} when map_size(updates) == 0 ->
        reg

      _ ->
        {key, _} = Enum.at(updates, 0)

        cond do
          is_atom(key) -> do_set_atom_keys(reg, updates)
          is_integer(key) -> do_set_integer_keys(reg, updates)
          true -> raise ArgumentError, "Keys must be either all atoms or all integers"
        end
    end
  end

  defp do_set_atom_keys(%__MODULE__{} = reg, updates) do
    if Enum.all?(Map.keys(updates), &is_atom/1) do
      struct!(reg, updates)
    else
      raise ArgumentError, "Keys must be either all atoms or all integers"
    end
  end

  defp do_set_integer_keys(%__MODULE__{} = reg, updates) do
    if Enum.all?(Map.keys(updates), &is_integer/1) do
      updates
      |> Enum.map(fn {reg_num, value} -> {String.to_atom("r#{reg_num}"), value} end)
      |> Map.new()
      |> then(fn updates -> struct!(reg, updates) end)
    else
      raise ArgumentError, "Keys must be either all atoms or all integers"
    end
  end

  def to_list(%__MODULE__{} = registers) do
    [
      registers.r0,
      registers.r1,
      registers.r2,
      registers.r3,
      registers.r4,
      registers.r5,
      registers.r6,
      registers.r7,
      registers.r8,
      registers.r9,
      registers.r10,
      registers.r11,
      registers.r12
    ]
  end
end

defimpl Inspect, for: PVM.Registers do
  def inspect(registers, _opts) do
    register_str =
      registers
      |> PVM.Registers.to_list()
      |> Enum.map(&to_string/1)
      |> Enum.join(" ")

    "\"[#{register_str}]\""
  end
end
