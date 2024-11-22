defmodule VMTest do
  use ExUnit.Case
  alias PVM.State
  use PVM.Decoder
  use Instructions
  def create_test_state(program, bitmask) do
    %State{
      program: program,
      bitmask: bitmask,
      jump_table: [],
      counter: 0,
      gas: 100,
      registers: List.duplicate(0, 13),
      memory: %Memory{}
    }
  end

  describe "VM.step basic functionality" do
    test "step trap instruction" do
      state = create_test_state(<<op(:trap)>>, <<1>>)
      output = VM.step(state)
      assert output.exit_status == :panic
      assert output.counter == 0
    end

    test "step out of bounds panics" do
      state = create_test_state(<<op(:trap)>>, <<1>>)
      state = %{state | counter: 4}
      output = VM.step(state)
      assert output.exit_status == :panic
      assert output.counter == 4
    end

    test "step fallthrough" do
      state = create_test_state(<<op(:fallthrough)>>, <<1>>)
      output = VM.step(state)
      assert output.exit_status == :continue
      assert output.counter == 1
    end
  end

  describe "VM.step instruction coverage" do
    test "steps all no-arg instructions" do
      # Test each no-arg instruction in sequence
      state = create_test_state(<<op(:trap), op(:fallthrough)>>, <<1, 1>>)

      output = VM.step(state)
      assert output.exit_status == :panic

      state = %{state | counter: 1}
      output = VM.step(state)
      assert output.exit_status == :continue
    end

    test "steps all one-immediate instructions" do
      state = create_test_state(
        <<
          op(:ecalli), 42,
          op(:jump), 2
        >>,
        <<1, 0, 1, 0>>
      )

      output = VM.step(state)
      assert output.exit_status == {:ecall, 42}

      state = %{state | counter: 2}
      output = VM.step(state)
      assert output.exit_status == :continue
      assert output.counter == 4
    end

    test "steps reg_immediate instructions" do
      state = create_test_state(
        <<
          op(:load_imm), 1, 42,
          op(:store_u8), 1, 10,
          op(:load_u8), 2, 10
        >>,
        <<1, 0, 0, 1, 0, 0, 1, 0, 0>>
      )

      # First instruction: load_imm
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Enum.at(output.registers, 1) == 42

      # Second instruction: store_u8
      state = %{state | counter: 3, registers: output.registers}
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 10, 1) == <<42>>

      # Third instruction: load_u8
      state = %{state | counter: 6, memory: output.memory}
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Enum.at(output.registers, 2) == 42
    end

    test "steps two_immediates instructions" do
      state = create_test_state(
        <<
          op(:store_imm_u8), 0x01, 10, 42,
          op(:store_imm_u16), 0x01, 20, 0x34, 0x12,
          op(:store_imm_u32), 0x01, 30, 0x78, 0x56, 0x34, 0x12
        >>,
        <<1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0>>
      )

      # First instruction: store_imm_u8
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 10, 1) == <<42>>

      # Second instruction: store_imm_u16
      state = %{state | counter: 4, memory: output.memory}
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 20, 2) == <<0x34, 0x12>>

      # Third instruction: store_imm_u32
      state = %{state | counter: 9, memory: output.memory}
      output = VM.step(state)
      assert output.exit_status == :continue
      assert Memory.read(output.memory, 30, 4) == <<0x78, 0x56, 0x34, 0x12>>
    end
  end

  describe "VM.execute program scenarios" do
    test "executes basic control flow with trap and fallthrough" do
      # Program:
      # fallthrough (17)
      # fallthrough (17)
      # trap (0)
      program = <<op(:fallthrough), op(:fallthrough), op(:trap)>>
      bitmask = <<1, 1, 1>>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 2
    end

    test "executes jump and jump_ind sequence skipping instructions" do
      # Program:
      # load_imm r1, 14        (4, 1, 14)      # offset 0
      # jump_ind r1           (19, 1, 0)       # offset 3
      # store_imm_u8 10, 42   (62, 1, 10, 42)  # offset 6 (skipped)
      # trap                  (0)               # offset 10 (skipped)
      # store_imm_u8 20, 99   (62, 1, 20, 99)  # offset 11 (skipped)
      # load_imm r2, 55       (4, 2, 55)       # offset 15 (jumped to)
      # fallthrough          (17)              # offset 18
      program = <<
        op(:load_imm), 1, 10,
        op(:jump_ind), 1, 0,
        op(:store_imm_u8), 1, 10, 42,
        op(:trap),
        op(:store_imm_u8), 1, 20, 99,
        op(:fallthrough),
        op(:load_imm), 2, 55,
        op(:fallthrough)
      >>

      # Mark instruction starts
      bitmask = <<
        1, 0, 0,             # load_imm
        1, 0, 0,             # jump_ind
        1, 0, 0, 0,          # store_imm_u8
        1,                   # trap
        1, 0, 0, 0,          # store_imm_u8
        1,                   # fallthrough
        1, 0, 0,             # load_imm
        1                    # fallthrough
      >>

      state = create_test_state(program, bitmask)
      state = %{state |
        jump_table: [2, 4, 6, 8, 16, 18], # 10 div 2 = 5, maps to offset 16 (fallthrough)
        counter: 0
      }

      output = VM.execute(state)
      assert output.exit_status == :panic
      assert output.counter == 20  # Ended after fallthrough
      assert Enum.at(output.registers, 1) == 10   # From first load_imm
      assert Enum.at(output.registers, 2) == 55   # From jumped-to load_imm

      # Verify skipped store_imm_u8 instructions didn't execute
      assert Memory.read(output.memory, 10, 1) == <<0>>
      assert Memory.read(output.memory, 20, 1) == <<0>>
    end

    test "executes memory operations sequence" do
      # Program:
      # store_imm_u8 addr=10, value=42  (62, 1, 10, 42)
      # load_u8 r1, 10                  (60, 1, 10)
      # store_u8 r1, 20                 (71, 1, 20)
      # load_u8 r2, 20                  (60, 2, 20)

      program = <<
        op(:store_imm_u8), 1, 10, 42,
        op(:load_u8), 1, 10,
        op(:store_u8), 1, 20,
        op(:load_u8), 2, 20
      >>
      bitmask = <<1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0>>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 13
      assert Enum.at(output.registers, 1) == 42
      assert Enum.at(output.registers, 2) == 42
      assert Memory.read(output.memory, 10, 1) == <<42>>
      assert Memory.read(output.memory, 20, 1) == <<42>>
    end

    test "executes complex load/store with different sizes" do
      # Program:
      # store_imm_u32 addr=10, value=0x12345678 (38, 1, 10, 78, 56, 34, 12)
      # load_u16 r1, 10                         (76, 1, 10)
      # load_u16 r2, 12                         (76, 2, 12)
      program = <<op(:store_imm_u32), 1, 10, 78, 56, 34, 12,
       op(:load_u16), 1, 10,
       op(:load_u16), 2, 12>>
      bitmask = <<1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0>>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 13
      assert Enum.at(output.registers, 1) == de_le(<<78, 56>>, 2)  # Lower 16 bits
      assert Enum.at(output.registers, 2) == de_le(<<34, 12>>, 2)  # Upper 16 bits
      assert Memory.read(output.memory, 10, 4) == <<78, 56, 34, 12>>
    end

    test "executes until trap with register operations" do
      # Program:
      # load_imm r1, 42                (4, 1, 42)
      # load_imm r2, 24                (4, 2, 24)
      # store_u8 r1, 100              (71, 1, 100)
      # store_u8 r2, 101              (71, 2, 101)
      # load_imm r3, 0xFFFF0000       (4, 3, 0, 0, 0xFF, 0xFF)  # Value that will cause halt
      # jump_ind r3                   (19, 3, 0)
      program = <<
        op(:load_imm), 1, 42,
        op(:load_imm), 2, 24,
        op(:store_u8), 1, 100,
        op(:store_u8), 2, 101,
        op(:load_imm), 3, 0, 0, 0xFF, 0xFF,
        op(:jump_ind), 3, 0>>
      bitmask = <<1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0>>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :halt
      # Stopped at jump_ind
      assert output.counter == 18
      assert Enum.at(output.registers, 1) == 42
      assert Enum.at(output.registers, 2) == 24
      assert Enum.at(output.registers, 3) == 0xFFFF_FFFF_FFFF_0000
      assert Memory.read(output.memory, 100, 1) == <<42>>
      assert Memory.read(output.memory, 101, 1) == <<24>>
    end


    test "executes 64-bit load and store operations" do
      # Program:
      # store_imm_u64 addr=16, value=0x12345678 (zero-extended to 64 bits)
      # load_imm_64 r1, 0xDCBA987654321001 (full 64-bit value)
      # store_u64 r1, 24
      program = <<
        op(:store_imm_u64), 1, 16, 0x78, 0x56, 0x34, 0x12,  # Only 32-bit immediate
        op(:load_imm_64), 0x01, 0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC,
        op(:store_u64), 1, 24
      >>

      bitmask = <<
        1, 0, 0, 0, 0, 0,0,              # store_imm_u64 (4-byte immediate)
        1, 0, 0, 0, 0, 0, 0, 0, 0,  # load_imm_64 (8-byte immediate)
        1, 0, 0                         # store_u64
      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic
      assert output.counter == 19
      # Verify the 64-bit immediate load worked
      assert Enum.at(output.registers, 1) == 0xDCBA987654321001
      # Verify memory contents:
      # First location should have zero-extended 32-bit value
      assert Memory.read(output.memory, 16, 8) == <<0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0>>
      # Second location should have full 64-bit value from register
      assert Memory.read(output.memory, 24, 8) == <<0x01,0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC>>
    end

    test "executes conditional branch sequence" do
      # Program:
      # load_imm r1, 42                (4, 1, 42)
      # branch_eq_imm r1, 42, target=9 (branch if r1 == 42)
      # trap                          (will be skipped)
      # store_imm_u8 20, 99          (target of branch)
      # fallthrough
      program = <<
        op(:load_imm), 1, 42,
        op(:branch_eq_imm), 0x11, 42, 5,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8), 1, 20, 99,
        op(:fallthrough)
      >>

      bitmask = <<
        1, 0, 0,           # load_imm
        1, 0, 0, 0,        # branch_eq_imm
        1,                 # trap
        1,                 # fallthrough
        1, 0, 0, 0,        # store_imm_u8
        1                  # fallthrough
      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic  # From final fallthrough
      assert output.counter == 14
      assert Enum.at(output.registers, 1) == 42
      assert Memory.read(output.memory, 20, 1) == <<99>>  # Verify branch was taken
    end
    test "not equel - no jump" do

      program = <<
        op(:load_imm), 1, 7,
        op(:branch_eq_imm), 0x11, 42, 5,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8), 1, 20, 99,
        op(:fallthrough)
      >>

      bitmask = <<
        1, 0, 0,           # load_imm
        1, 0, 0, 0,        # branch_eq_imm
        1,                 # trap
        1,                 # fallthrough
        1, 0, 0, 0,        # store_imm_u8
        1                  # fallthrough
      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic  # From final fallthrough
      assert output.counter == 7
      assert Enum.at(output.registers, 1) == 7
      assert Memory.read(output.memory, 20, 1) == <<0>>  # Verify branch was taken
    end

    test "executes load_imm_jump sequence" do
      # Program:
      # load_imm_jump r1, 42, target=8  (loads 42 into r1 and jumps)
      # trap                           (skipped)
      # store_imm_u8 10, 99           (target of jump)
      # fallthrough
      program = <<
        op(:load_imm_jump), 0x11, 42, 6,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8), 1, 10, 99,
        op(:fallthrough)
      >>

      bitmask = <<
        1, 0, 0, 0,        # load_imm_jump
        1,                 # trap
        1,                 # fallthrough
        1, 0, 0, 0,        # store_imm_u8
        1                  # fallthrough
      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic  # From final fallthrough
      assert output.counter == 11
      assert Enum.at(output.registers, 1) == 42
      assert Memory.read(output.memory, 10, 1) == <<99>>  # Verify jump was taken
    end

    test "executes signed comparison branch sequence" do
      # Program:
      # load_imm r1, 0xFF              (load -1 in two's complement)
      # branch_lt_s_imm r1, 0, target=9 (branch if r1 < 0 signed)
      # trap                           (will be skipped)
      # store_imm_u8 30, 77           (target of branch)
      # fallthrough
      program = <<
        op(:load_imm), 1, 0xFF,
        op(:branch_lt_s_imm), 0x11, 0, 6,
        op(:trap),
        op(:fallthrough),
        op(:store_imm_u8), 1, 30, 77,
        op(:fallthrough)
      >>

      bitmask = <<
        1, 0, 0,           # load_imm
        1, 0, 0, 0,        # branch_lt_s_imm
        1,                 # trap
        1,                 # fallthrough
        1, 0, 0, 0,        # store_imm_u8
        1                  # fallthrough
      >>

      state = create_test_state(program, bitmask)
      output = VM.execute(state)

      assert output.exit_status == :panic  # From final fallthrough
      assert output.counter == 14
      assert Enum.at(output.registers, 1) == 0xFFFF_FFFF_FFFF_FFFF
      assert Memory.read(output.memory, 30, 1) == <<77>>  # Verify branch was taken
    end
  end

  describe "VM.execute memory faults" do
    test "handles memory write fault correctly" do
      # Program:
      # store_imm_u8 addr=4096, value=42  (62, 2,0x00 10, 42)
      program = <<op(:store_imm_u8), 2, 0x00, 0x10, 42>>
      bitmask = <<1, 0, 0, 0, 0>>

      state = create_test_state(program, bitmask)

      # Mark page 1 (starting at 4096) as read-only
      state = %{state | memory: Memory.set_access(state.memory, 4096, 2, :read)}

      # Initial register state to verify no changes
      initial_registers = state.registers

      output = VM.execute(state)

      # Should return page-aligned address
      assert output.exit_status == {:fault, 1}
      # Counter should not advance
      assert output.counter == 0
      # Registers should be unchanged
      assert output.registers == initial_registers
      # Memory should be unchanged
      assert Memory.read(output.memory, 4096, 1) == <<0>>
    end
  end

  describe "VM.step two registers instructions" do
    test "move_reg copies value between registers" do
      # Program:
      # load_imm r1, 42    # First load a value into r1
      # move_reg r2, r1    # Then move it to r2 (encoded as 0x21 - r2 in low bits, r1 in high)
      program = <<
        op(:load_imm), 2, 42,
        op(:move_reg), 0x21
      >>

      bitmask = <<1, 0, 0, 1, 0>>

      state = create_test_state(program, bitmask)

      # First execute load_imm
      output = VM.step(state)
      assert Enum.at(output.registers, 2) == 42

      # Then execute move_reg
      state = State.new(state.program, state.bitmask, state.jump_table, output)
      output = VM.step(state)

      # rd = 1, ra = 2
      #w_d <- w_a

      assert output.exit_status == :continue
      assert Enum.at(output.registers, 1) == 42  # r1 should now have r2's value
      assert Enum.at(output.registers, 2) == 42  # r2 should be unchanged
      assert output.counter == 5  # Should advance past the move_reg instruction
    end
  end
end
