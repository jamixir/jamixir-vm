defmodule VMTest do
  use ExUnit.Case
  alias PVM.{State, Memory, VM, Registers, InitProgram}
  use PVM.{Decoder, Utils, Instructions}

  def create_program(program, bitmask, jump_table \\ {}, z \\ 1) do
    PVM.Encoder.encode_program(program, bitmask, jump_table, z)
  end

  setup_all do
    memory = InitProgram.construct_memory("code", "data", "args", 1, 1)
    stack_addr = InitProgram.boundaries(4, 4, 4, 1, 1).stack_start
    state = %State{memory: memory, registers: Registers.new(%{r2: stack_addr}), gas: 1000}
    {:ok, %{memory: memory, stack_addr: stack_addr, state: state}}
  end

  describe "VM.execute program scenarios" do
    test "executes basic control flow with trap and fallthrough" do
      # Program:
      # fallthrough (17)
      # fallthrough (17)
      # trap (0)
      program = <<op(:fallthrough), op(:fallthrough), op(:trap)>>
      bitmask = <<224>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, %State{gas: 1000})

      assert exit_reason == :panic
      assert state_.counter == 0
    end

    test "executes jump and jump_ind sequence skipping instructions", %{
      state: state,
      stack_addr: stack_addr
    } do
      # Program:
      # load_imm r1, 14        (4, 1, 14)      # offset 0
      # jump_ind r1           (19, 1, 0)       # offset 3
      # store_imm_u8 10, 42   (62, 1, 10, 42)  # offset 6 (skipped)
      # trap                  (0)               # offset 10 (skipped)
      # store_imm_u8 20, 99   (62, 1, 20, 99)  # offset 11 (skipped)
      # load_imm r2, 55       (4, 2, 55)       # offset 15 (jumped to)
      # fallthrough          (17)              # offset 18
      program = <<
        op(:load_imm),
        1,
        10,
        op(:jump_ind),
        1,
        0,
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        42,
        op(:trap),
        op(:store_imm_u8),
        4,
        stack_addr + 10::little-size(32),
        0,
        1,
        99,
        op(:fallthrough),
        op(:load_imm),
        2,
        55,
        op(:fallthrough)
      >>

      # Mark instruction starts
      # 10010010_00000110_00000001_1001
      bitmask = <<146, 6, 1, 144>>
      jump_table = {2, 4, 6, 8, 24, 1}

      p = create_program(program, bitmask, jump_table)
      {exit_reason, state_} = VM.execute(p, state)

      assert exit_reason == :panic
      # Ended after fallthrough
      assert state_.counter == 0
      # From first and jumped-to load_imm
      assert Registers.get_2(state_.registers, 1, 2) == {10, 55}

      # Verify skipped store_imm_u8 instructions didn't execute
      assert Memory.read(state_.memory, 0x1000A, 1) == {:ok, <<0>>}
      assert Memory.read(state_.memory, 0x10014, 1) == {:ok, <<0>>}
    end

    test "executes memory operations sequence", %{state: state, stack_addr: stack_addr} do
      # Program:
      # store_imm_u8 addr=10, value=42  (62, 1, 10, 42)
      # load_u8 r1, 10                  (60, 1, 10)
      # store_u8 r1, 20                 (71, 1, 20)
      # load_u8 r2, 20                  (60, 2, 20)

      program = <<
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        42,
        op(:load_u8),
        1,
        stack_addr::little-size(32),
        op(:store_u8),
        1,
        stack_addr + 10::little-size(32),
        op(:load_u8),
        2,
        stack_addr + 10::little-size(32)
      >>

      # 10000001_00000100_00010000_0
      bitmask = <<129, 4, 16, 0>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      assert exit_reason == :panic
      assert state_.counter == 0
      assert Registers.get_2(state_.registers, 1, 2) == {42, 42}
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok, <<42>>}
      assert Memory.read(state_.memory, stack_addr + 10, 1) == {:ok, <<42>>}
    end

    test "executes conditional branch sequence", %{state: state, stack_addr: stack_addr} do
      # Program:
      # load_imm r1, 42                (4, 1, 42)
      # branch_eq_imm r1, 42, target=9 (branch if r1 == 42)
      # trap                          (will be skipped)
      # store_imm_u8 20, 99          (target of branch)
      # fallthrough
      program = <<
        op(:load_imm),
        1,
        42,
        op(:branch_eq_imm),
        0x11,
        42,
        5,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        99,
        op(:fallthrough)
      >>

      bitmask = <<145, 192, 1>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      # From final fallthrough
      assert exit_reason == :panic
      assert state_.counter == 0
      assert state_.registers[1] == 42
      # Verify branch was taken
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok, <<99>>}
    end

    @tag :skip
    test "not equel - no jump", %{state: state, stack_addr: stack_addr} do
      program = <<
        op(:load_imm),
        1,
        7,
        op(:branch_eq_imm),
        0x11,
        42,
        5,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        99,
        op(:fallthrough)
      >>

      bitmask = <<
        # load_imm
        145,
        192,
        1
      >>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      # From final fallthrough
      assert exit_reason == :panic
      assert state_.counter == 0
      assert state_.registers[1] == 7
      # Verify branch was BOT taken
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok, <<0>>}
    end

    test "executes load_imm_jump sequence", %{state: state, stack_addr: stack_addr} do
      # Program:
      # load_imm_jump r1, 42, target=8  (loads 42 into r1 and jumps)
      # trap                           (skipped)
      # store_imm_u8 10, 99           (target of jump)
      # fallthrough
      program = <<
        op(:load_imm_jump),
        0x11,
        42,
        6,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        99,
        op(:fallthrough)
      >>

      bitmask = <<142, 1>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      # From final fallthrough
      assert exit_reason == :panic
      assert state_.counter == 0
      assert state_.registers[1] == 42
      # Verify jump was taken
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok, <<99>>}
    end

    test "executes signed comparison branch sequence", %{state: state, stack_addr: stack_addr} do
      # Program:
      # load_imm r1, 0xFF              (load -1 in two's complement)
      # branch_lt_s_imm r1, 0, target=9 (branch if r1 < 0 signed)
      # trap                           (will be skipped)
      # store_imm_u8 30, 77           (target of branch)
      # fallthrough
      program = <<
        op(:load_imm),
        1,
        0xFF,
        op(:branch_lt_s_imm),
        0x11,
        0,
        6,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8),
        4,
        stack_addr::little-size(32),
        77,
        op(:fallthrough)
      >>

      bitmask = <<
        145,
        192,
        1
      >>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      # From final fallthrough
      assert exit_reason == :panic
      assert state_.counter == 0
      assert state_.registers[1] == 0xFFFF_FFFF_FFFF_FFFF
      # Verify branch was taken
      assert Memory.read(state_.memory, stack_addr, 1) == {:ok, <<77>>}
    end

    test "calculates sum of even numbers from 1 to 10", %{state: state, stack_addr: stack_addr} do
      # Program:
      # sum = 0
      # i = 1
      # while i <= 10:
      #     if (i % 2) == 0:
      #         sum += i
      #     i += 1
      # store sum in memory at address 3

      # r1 = sum (initialized to 0)
      # r2 = i (counter, initialized to 1)
      # r3 = 10 (loop end condition)
      # r4 = temporary register for calculations
      # Memory address 100 = final result
      program = <<
        # Initialize registers (offset 0)
        # sum = 0
        op(:load_imm),
        1,
        0,
        # i = 1
        op(:load_imm),
        2,
        1,
        # end condition = 10
        op(:load_imm),
        3,
        10,
        # divisor = 2 (keep this constant)
        op(:load_imm),
        5,
        2,
        # Check if i <= 10
        op(:fallthrough),
        # Loop start (offset 13):
        # if i > 10, jump to end (offset 33) (13 + 20)
        op(:branch_gt_u_imm),
        0x12,
        10,
        20,
        # r4 = i % 2  (r_a=2, r_b=4, r_d=4)
        op(:rem_u_32),
        0x52,
        4,
        # (offset 20)
        # if remainder != 0, skip to load_imm 1 (offset 29)
        op(:branch_ne_imm),
        0x14,
        0,
        8,
        # sum += i
        op(:add_32),
        0x12,
        1,
        op(:fallthrough),
        # (offset 28)
        op(:add_imm_32),
        0x22,
        1,
        # (offset 31)
        # Jump back to loop start (offset 13) => 31 -18  => 31 + (255 - 17) = 31 + 238
        op(:jump),
        238,
        # Store result and exit (offset 38):
        # Store sum at memory address 0x10003
        op(:store_u32),
        1,
        stack_addr::little-size(32)
      >>

      # 10010010_01001100_01001000_10011001_0100_0000
      # = 146, 76, 72, 153, 64
      bitmask = <<146, 76, 72, 153, 64>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      # Normal termination after last instruction
      assert exit_reason == :panic
      # Read the result from memory - should be 2 + 4 + 6 + 8 + 10 = 30
      assert Memory.read(state_.memory, stack_addr, 4) == {:ok, <<30, 0, 0, 0>>}
      # Verify final register values
      # sum, final i value, loop end condition
      assert Registers.get_3(state_.registers, 1, 2, 3) == {30, 11, 10}
    end
  end

  describe "VM.execute memory faults" do
    test "handles memory write fault correctly" do
      # Program:
      # store_imm_u8 addr=0x100FF, value=42
      program = <<op(:store_imm_u8), 3, 0xFF, 0, 1, 42>>
      bitmask = <<128>>

      p = create_program(program, bitmask)

      # Mark page 1 (starting at 4096) as read-only
      state = %State{memory: Memory.set_access(State.new().memory, 0x10000, 2, :read)}

      # Initial register state to verify no changes
      initial_registers = state.registers

      {exit_reason, state_} = VM.execute(p, state)

      # Should return page-aligned address
      assert exit_reason == {:fault, 0x10000}
      # Counter should not advance
      assert state_.counter == 0
      # Registers should be unchanged
      assert state_.registers == initial_registers
      # Memory should be unchanged
      assert Memory.read(state_.memory, 0x10000, 1) == {:ok, <<0>>}
    end
  end

  describe "VM.execute instruction type coverage" do
    test "executes store_imm_ind instructions", %{state: state, stack_addr: stack_addr} do
      # Program:
      # load_imm r1, 100              # Base address in r1
      # store_imm_ind_u8 r1, 5, 42    # Store 42 at address r1+5
      # store_imm_ind_u16 r1, 10, 0x1234  # Store 0x1234 at address r1+10
      program = <<
        op(:load_imm),
        1,
        stack_addr::little-size(32),
        op(:store_imm_ind_u8),
        0x11,
        5,
        42,
        op(:store_imm_ind_u16),
        0x11,
        10,
        0x34,
        0x12
      >>

      # 10000010_0010000
      bitmask = <<130, 32>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, state)

      assert exit_reason == :panic
      # 100 + 5
      assert Memory.read(state_.memory, stack_addr + 5, 1) == {:ok, <<42>>}
      # 100 + 10
      assert Memory.read(state_.memory, stack_addr + 10, 2) == {:ok, <<0x34, 0x12>>}
    end

    test "executes two_registers_one_offset branch instructions" do
      # Program:
      # load_imm r1, 42
      # load_imm r2, 42
      # branch_eq r1, r2, target=11  # Should branch because equal
      # trap                         # Should be skipped
      # fallthrough                  # Target of branch
      program = <<
        op(:load_imm),
        1,
        42,
        op(:load_imm),
        2,
        42,
        # r2 in high bits, r1 in low bits
        op(:branch_eq),
        0x21,
        11,
        op(:trap),
        op(:fallthrough)
      >>

      bitmask = <<146, 96>>

      p = create_program(program, bitmask)
      {exit_reason, state_} = VM.execute(p, %State{gas: 1000})

      # From fallthrough
      assert exit_reason == :panic
      # Reached end of program
      assert state_.counter == 0
    end

    test "executes load_imm_jump_ind instruction" do
      # Program:
      # load_imm r1, 10          # Target address holder
      # load_imm_jump_ind r2, 42, r1, 2  # Load 42 into r2 and jump to r1+2
      # trap                     # Should be skipped
      # fallthrough             # Target of jump (offset 10)
      program = <<
        op(:load_imm),
        2,
        5,
        # r2 in high bits, r1 in low bits
        op(:load_imm_jump_ind),
        0x21,
        1,
        42,
        1,
        op(:trap),
        op(:fallthrough)
      >>

      bitmask = <<144, 192>>
      jump_table = {2, 4, 10}

      p = create_program(program, bitmask, jump_table)
      {exit_reason, state_} = VM.execute(p, %State{gas: 1000})

      # From fallthrough
      assert exit_reason == :panic
      # Reached fallthrough instruction
      assert state_.counter == 0
      # Verify immediate was loaded
      assert state_.registers[1] == 42
    end
  end
end
