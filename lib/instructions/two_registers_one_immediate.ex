defmodule PVM.Instructions.TwoRegistersOneImmediate do
  import Bitwise
  use PVM.{Decoder, Encoder, Utils, Math}
  alias PVM.{Registers, Utils}
  import PVM.Memory.Util
  import PVM.Utils, only: [bool_to_int: 1]
  # Section (A.5.10) v0.7.0

  @two_32 0x1_0000_0000
  @two_64 0x1_0000_0000_0000_0000

  # Store instructions
  def execute(:store_ind_u8, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    write_memory(state, w_b + v_x, <<mod(w_a, 0x100)::8-little>>)
  end

  def execute(:store_ind_u16, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    write_memory(state, w_b + v_x, <<mod(w_a, 0x1_0000)::16-little>>)
  end

  def execute(:store_ind_u32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    write_memory(state, w_b + v_x, <<mod(w_a, @two_32)::32-little>>)
  end

  def execute(:store_ind_u64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)

    write_memory(state, w_b + v_x, <<w_a::64-little>>)
  end

  def execute(:load_ind_u8, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 1, fn <<v::8-little>> ->
      %{
        state
        | registers: %{
            state.registers
            | r: put_elem(state.registers.r, r_a, v)
          }
      }
    end)
  end

  def execute(:load_ind_u16, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 2, fn <<v::16-little>> ->
      %{
        state
        | registers: %{state.registers | r: put_elem(state.registers.r, r_a, v)}
      }
    end)
  end

  def execute(:load_ind_u32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 4, fn <<v::32-little>> ->
      %{
        state
        | registers: %{state.registers | r: put_elem(state.registers.r, r_a, v)}
      }
    end)
  end

  def execute(:load_ind_u64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 8, fn <<v::64-little>> ->
      %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, v)}}
    end)
  end

  def execute(:load_ind_i8, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 1, fn <<v::8-little>> ->
      val = v |> u2i(1) |> i2u(8)
      %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, val)}}
    end)
  end

  def execute(:load_ind_i16, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 2, fn <<v::16-little>> ->
      val = v |> u2i(2) |> i2u(8)
      %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, val)}}
    end)
  end

  def execute(:load_ind_i32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    addr = state.registers[r_b] + v_x

    read_memory(state, addr, 4, fn <<v::32-little>> ->
      val = v |> u2i(4) |> i2u(8)
      %{state | registers: %{state.registers | r: put_elem(state.registers.r, r_a, val)}}
    end)
  end

  def execute(:add_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result = mod(w_b + v_x, @two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:mul_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result = mod(w_b * v_x, @two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:neg_add_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    result = mod(v_x + @two_32 - w_b, @two_32) |> to_64bit(4)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:and_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    state = %{
      state
      | registers: %{state.registers | r: put_elem(state.registers.r, r_a, w_b &&& v_x)}
    }

    {:continue, state}
  end

  def execute(:xor_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    state = %{
      state
      | registers: %{state.registers | r: put_elem(state.registers.r, r_a, bxor(w_b, v_x))}
    }

    {:continue, state}
  end

  def execute(:or_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]

    state = %{
      state
      | registers: %{state.registers | r: put_elem(state.registers.r, r_a, w_b ||| v_x)}
    }

    {:continue, state}
  end

  def execute(:set_lt_u_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = bool_to_int(w_b < v_x)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:set_lt_s_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = bool_to_int(u2i(w_b, 8) < u2i(v_x, 8))

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:set_gt_u_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = bool_to_int(w_b > v_x)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:set_gt_s_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = bool_to_int(u2i(w_b, 8) > u2i(v_x, 8))

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_l_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 32)
    result = mod(w_b * (1 <<< shift), @two_32) |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_r_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 32)
    result = mod(w_b, @two_32) >>> shift |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shar_r_imm_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 32)
    result = u2i(mod(w_b, @two_32), 4) |> Bitwise.bsr(shift) |> i2u(8)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_l_imm_alt_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 32)
    result = mod(v_x * (1 <<< shift), @two_32) |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_r_imm_alt_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 32)
    result = mod(v_x, @two_32) >>> shift |> to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shar_r_imm_alt_32, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 32)
    result = u2i(mod(v_x, @two_32), 4) |> Bitwise.bsr(shift) |> i2u(8)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:cmov_iz_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)
    result = if w_b == 0, do: v_x, else: w_a

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:cmov_nz_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    {w_a, w_b} = Registers.get_2(state.registers, r_a, r_b)
    result = if w_b != 0, do: v_x, else: w_a

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:add_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = mod(w_b + v_x, @two_64)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:mul_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = mod(w_b * v_x, @two_64)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:neg_add_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    result = mod(v_x + @two_64 - w_b, @two_64)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_l_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 64)
    result = mod(w_b * (1 <<< shift), @two_64)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_r_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 64)
    result = w_b >>> shift
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shar_r_imm_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 64)
    result = u2i(w_b, 8) >>> shift |> i2u(8)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_l_imm_alt_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 64)
    result = mod(v_x * (1 <<< shift), @two_64)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shlo_r_imm_alt_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 64)
    result = v_x >>> shift
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:shar_r_imm_alt_64, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 64)
    result = u2i(v_x, 8) >>> shift |> i2u(8)
    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  # Rotation operations
  def execute(:rot_r_64_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    number = state.registers[r_b]

    shift = mod(v_x, 64)
    result = rotate(number, shift, 64, :right)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:rot_r_64_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 64)
    result = rotate(v_x, shift, 64, :right)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:rot_r_32_imm, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(v_x, 32)
    result = rotate(w_b, shift, 32, :right) |> Utils.extend_to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  def execute(:rot_r_32_imm_alt, program, bitmask, state) do
    {r_a, r_b, v_x} = get_params(program, bitmask, state.counter)
    w_b = state.registers[r_b]
    shift = mod(w_b, 32)
    result = rotate(v_x, shift, 32, :right) |> Utils.extend_to_64bit(4)

    Registers.put_elem(state.registers.r, r_a, result)
    {:continue, state}
  end

  # Formula (A.28) v0.7.0
  defp get_params(program, bitmask, counter) do
    <<byte1>> = binary_part_safe(program, counter + 1, 1)
    r_a = min(12, mod(byte1, 16))
    r_b = min(12, byte1 >>> 4)

    l_x = min(4, max(0, skip(counter, bitmask) - 1))

    v_x = decode_and_extend(program, counter + 2, l_x)

    {r_a, r_b, v_x}
  end
end
