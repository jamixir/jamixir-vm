defmodule PVM.Registers do
  defstruct r: nil #:atomics.new(13, [])

  @type register :: 0..12
  @type t :: %__MODULE__{}

  # @spec new() :: t()
  def new(), do: %__MODULE__{r: :atomics.new(13, [signed: false])}

  @spec new(map()) :: t()
  def new(updates) when is_map(updates) do
    registers = new()
    for {k, v} <- updates, k <= 12, v >= 0, do: :atomics.put(registers.r, k + 1, v)
    for {k, v} <- updates, k <= 12, v < 0, do: :atomics.put(registers.r, k + 1, -rem(v, 0x1_0000_0000_0000_0000))
    registers
  end

  @spec from_list([integer()]) :: t()
  def from_list(values) when is_list(values) and length(values) == 13 do
    registers = new()
    for {v, k} <- Enum.with_index(values), do: :atomics.put(registers.r, k + 1, v)
    registers
  end

  @spec get(t(), [integer()]) :: [integer()]
  def get(%__MODULE__{r: r}, registers)
      when is_list(registers) and is_integer(hd(registers)) do
    for index <- registers, do: :atomics.get(r, index + 1)
  end

  # Fast multi-register getters
  @spec get_2(t(), integer(), integer()) :: {integer(), integer()}
  def get_2(%__MODULE__{r: r}, i1, i2) do
    {:atomics.get(r, i1 + 1), :atomics.get(r, i2 + 1)}
  end

  @spec get_3(t(), integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def get_3(%__MODULE__{r: r}, i1, i2, i3) do
    {:atomics.get(r, i1 + 1), :atomics.get(r, i2 + 1), :atomics.get(r, i3 + 1)}
  end

  @spec get_4(t(), integer(), integer(), integer(), integer()) ::
          {integer(), integer(), integer(), integer()}
  def get_4(%__MODULE__{r: r}, i1, i2, i3, i4) do
    {:atomics.get(r, i1+1), :atomics.get(r, i2+1), :atomics.get(r, i3+1), :atomics.get(r, i4+1)}
  end

  def put_elem(ref, k, v), do: :atomics.put(ref, k + 1, v)

  @spec get_5(t(), integer(), integer(), integer(), integer(), integer()) ::
          {integer(), integer(), integer(), integer(), integer()}
  def get_5(%__MODULE__{r: r}, i1, i2, i3, i4, i5) do
    {:atomics.get(r, i1+1), :atomics.get(r, i2+1), :atomics.get(r, i3+1), :atomics.get(r, i4+1), :atomics.get(r, i5+1)}
  end

  @spec to_list(t()) :: [integer()]
  def to_list(%__MODULE__{r: r}), do: for(i <- 1..13, do: :atomics.get(r, i))

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{r: r}, key) when is_integer(key) and key in 0..12 do
    {:ok, :atomics.get(r, key + 1)}
  end

  def fetch(%__MODULE__{}, _key), do: :error
end

defimpl Inspect, for: PVM.Registers do
  def inspect(%PVM.Registers{r: r}, _opts) do
    register_str =
      1..13
      |> Enum.map(&"#{&1}:#{:atomics.get(r, &1)}")
      |> Enum.join(" ")

    "[#{register_str}]"
  end
end
