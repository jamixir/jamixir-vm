defmodule PVM.HostCallTest do
  use ExUnit.Case
  alias PVM.{HostCall, State, VM}
  use PVM.Instructions

  def create_program(program, bitmask, jump_table \\ [], z \\ 1) do
    PVM.Encoder.encode_program(program, bitmask, jump_table, z)
  end

  describe "HostCall.execute basic exit conditions" do
    test "handles :halt exit reason" do
      # Using program_utils to create a halting program
      {program, bitmask} = PVM.Utils.ProgramUtils.create_halt_program()
      p = create_program(program, bitmask)

      # Mock host function that should never be called
      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}
      {exit_reason, final_state, final_context} = HostCall.execute(p, %State{}, host_fn, initial_context)

      assert exit_reason == :halt
      assert final_state.counter == 0
      assert final_context == initial_context
    end

    test "handles :panic exit reason" do
      # Program that just executes trap
      program = <<op(:trap)>>
      bitmask = <<1>>
      p = create_program(program, bitmask)

      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}
      {exit_reason, final_state, final_context} = HostCall.execute(p, %State{}, host_fn, initial_context)

      assert exit_reason == :panic
      assert final_state.counter == 0
      assert final_context == initial_context
    end

    test "handles :out_of_gas exit reason" do
      # Using a basic program but with zero gas
      program = <<op(:fallthrough)>>
      bitmask = <<1>>
      p = create_program(program, bitmask)

      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}
      initial_state = %State{gas: -1}  # Set gas to 0
      {exit_reason, final_state, final_context} = HostCall.execute(p, initial_state, host_fn, initial_context)

      assert exit_reason == :out_of_gas
      assert final_state.gas == -1
      assert final_context == initial_context
    end

    test "handles fault exit reason" do
      # Program that attempts to write to invalid memory
      program = <<op(:store_imm_u8), 1, 0xFF, 0xFF, 42>>  # Try to write to invalid memory address
      bitmask = <<1, 0, 0, 0, 0>>
      p = create_program(program, bitmask)

      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}
      # Set memory access to read-only for the target page
      initial_state = %State{
        memory: %PVM.Memory{} |> PVM.Memory.set_default_access(nil)
      }

      {exit_reason, final_state, final_context} = HostCall.execute(p, initial_state, host_fn, initial_context)

      assert match?({{:fault, _page}, _, _}, {exit_reason, final_state, final_context})
      assert final_context == initial_context
    end
  end
end
