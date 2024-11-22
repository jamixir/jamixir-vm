defmodule Instructions.TwoRegisters do
  alias Instructions.Common

  def execute(:move_reg, state, output) do
    {r_d, r_a} = get_params(state)
    w_a = Enum.at(state.registers, r_a)

    Common.update_register(output, state.registers, r_d, w_a)
  end

  def execute(:sbrk, state, output) do
    {_r_d, r_a} = get_params(state)
    _w_a = Enum.at(state.registers, r_a)

    # TODO
    output
  end

  defp get_params(state) do
    byte = binary_part(state.program, state.counter + 1, 1) |> :binary.first()
    {rem(byte, 16) |> min(12), div(byte, 16) |> min(12)}
  end
end
