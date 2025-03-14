defmodule PVM.Memory.Constants do
  def page_size, do: 0x1000
  def memory_size, do: 0x1_0000_0000
  def min_allowed_address, do: 0x1_0000
  def min_page, do: 0x10
  def max_page, do: 0x10_0000
end
