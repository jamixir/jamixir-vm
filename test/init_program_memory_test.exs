defmodule PVM.InitProgramMemoryTest do
  use ExUnit.Case
  alias PVM.{Memory, InitProgram}
  import PVM.Memory.Constants

  describe "memory initialization" do
    test "construct_memory creates a valid memory structure" do
      # Program text
      o = <<1, 2, 3, 4>>
      # Data
      w = <<5, 6>>
      # Args
      a = <<7, 8, 9>>
      z = 1
      # Stack size
      s = 1024

      memory = InitProgram.construct_memory(o, w, a, z, s)

      # can read from the program text region
      assert o == Memory.read!(memory, min_allowed_address(), 4)

      # can read from the args region
      args_start = memory_size() - min_allowed_address() - 0x100_0000
      assert a == Memory.read!(memory, args_start, 3)

      # can write to the data region
      data_start = 2 * min_allowed_address() + InitProgram.z(byte_size(o))
      assert {:ok, _} = Memory.write(memory, data_start, <<10, 11>>)

      # can't write to the program text region
      assert {:error, {:fault, _}} = Memory.write(memory, min_allowed_address(), <<10>>)
    end
  end
end
