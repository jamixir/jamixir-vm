defmodule InstructionsTest do
  use ExUnit.Case
  alias PVM.Instructions

  test "all instruction types are consistently defined across maps" do
    # Get instructions from opcode map
    opcode_instructions =
      Instructions.opcode_map()
      |> Map.keys()
      |> MapSet.new()

    # Get instructions from gas cost map
    gas_cost_instructions =
      Instructions.gas_cost_map()
      |> Map.keys()
      |> MapSet.new()

    # Get instructions from instruction categories
    category_instructions =
      Instructions.instruction_categories()
      |> Map.values()
      |> List.flatten()
      |> MapSet.new()

    # Compare all sets
    assert MapSet.equal?(opcode_instructions, gas_cost_instructions),
           "Mismatch between opcode map and gas cost map:\n" <>
             "In opcode but not gas cost: #{inspect(MapSet.difference(opcode_instructions, gas_cost_instructions))}\n" <>
             "In gas cost but not opcode: #{inspect(MapSet.difference(gas_cost_instructions, opcode_instructions))}"

    assert MapSet.equal?(opcode_instructions, category_instructions),
           "Mismatch between opcode map and instruction categories:\n" <>
             "In opcode but not categories: #{inspect(MapSet.difference(opcode_instructions, category_instructions))}\n" <>
             "In categories but not opcode: #{inspect(MapSet.difference(category_instructions, opcode_instructions))}"
  end
end
