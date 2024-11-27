defmodule PVM.Instructions.TwoRegisters do
  def execute(:move_reg, program, _bitmask, _jump_table, state) do
    {r_d, r_a} = get_params(program, state.counter)
    w_a = Enum.at(state.registers, r_a)

    {:continue, %{state | registers: List.replace_at(state.registers, r_d, w_a)}}
  end

  def execute(:sbrk, program, _bitmask, _jump_table, state) do
    {_r_d, r_a} = get_params(program, state.counter)
    _w_a = Enum.at(state.registers, r_a)

    # TODO
    {:continue, state}
  end

  defp get_params(program, counter) do
    byte = binary_part(program, counter + 1, 1) |> :binary.first()
    {rem(byte, 16) |> min(12), div(byte, 16) |> min(12)}
  end
end
