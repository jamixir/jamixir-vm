defmodule PVM.MemoryFaultError do
  defexception [:reason]

  def exception(opts), do: %__MODULE__{reason: Keyword.fetch!(opts, :reason)}

  def message(%__MODULE__{reason: {:fault, page}}), do: "Memory fault at page #{page}"
end
