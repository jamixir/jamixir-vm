defmodule PVM.HostCallTest do
  use ExUnit.Case
  alias PVM.{HostCall, State, InitProgram, Registers}
  use PVM.Instructions

  def create_program(program, bitmask, jump_table \\ {}, z \\ 1) do
    PVM.Encoder.encode_program(program, bitmask, jump_table, z)
  end

  setup_all do
    memory = InitProgram.construct_memory("code", "data", "args", 1, 1)
    stack_addr = InitProgram.boundaries(4, 4, 4, 1, 1).stack_start
    state = %State{memory: memory, registers: Registers.new(%{r2: stack_addr})}
    {:ok, %{memory: memory, stack_addr: stack_addr, state: state}}
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

      {exit_reason, final_state, final_context} =
        HostCall.execute(p, State.new(), host_fn, initial_context)

      assert exit_reason == :halt
      assert final_state.counter == 0
      assert final_context == initial_context
    end

    test "handles :panic exit reason" do
      # Program that just executes trap
      program = <<op(:trap)>>
      bitmask = <<128>>
      p = create_program(program, bitmask)

      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}

      {exit_reason, final_state, final_context} =
        HostCall.execute(p, State.new(), host_fn, initial_context)

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
      # Set gas to 0
      initial_state = %State{gas: 0}

      {exit_reason, final_state, final_context} =
        HostCall.execute(p, initial_state, host_fn, initial_context)

      assert exit_reason == :out_of_gas
      assert final_state.gas == -1
      assert final_context == initial_context
    end

    test "handles fault exit reason", %{state: state} do
      # Program that attempts to write to invalid memory
      # Try to write to invalid memory address
      program = <<op(:store_imm_u8), 1, 0xFF, 0xFF, 42>>
      bitmask = <<1>>
      p = create_program(program, bitmask)

      host_fn = fn _data, _state, _context ->
        raise "Should not be called"
      end

      initial_context = %{test: :context}
      {exit_reason, state_, final_context} = HostCall.execute(p, state, host_fn, initial_context)

      assert match?({{:fault, _page}, _, _}, {exit_reason, state_, final_context})
      assert final_context == initial_context
    end
  end
end
