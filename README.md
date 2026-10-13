# jamixir-vm

The Polkadot Virtual Machine (PVM) in Elixir, implemented from the
[JAM Gray Paper](https://graypaper.com). It was the first PVM in
[Jamixir](https://jamixir.org), an Elixir JAM client, before the node moved to the Rust
version ([jamixir/pvm-rust](https://github.com/jamixir/pvm-rust)) for speed. It is kept
here as a readable reference, with comments pointing to the Gray Paper formulas.

Written by Luke Fishman and Daniel Cukier.

## Example

```elixir
defmodule Example do
  use PVM.Instructions
  alias PVM.{Encoder, Registers, State, VM}

  def run do
    # load_imm r7, 42 ; trap
    program = <<op(:load_imm), 7, 42, op(:trap)>>
    # one bit per byte of code, set where an instruction starts (bytes 0 and 3)
    bitmask = <<0b10010000>>

    blob = Encoder.encode_program(program, bitmask, {}, 1)
    {exit_reason, state} = VM.execute(blob, %State{gas: 100})

    [r7] = Registers.get(state.registers, [7])
    {exit_reason, r7, state.gas}
  end
end

Example.run()
# => {:panic, 42, 98}
```

`VM.execute/2` returns `{exit_reason, state}`, where the exit reason is `:halt`, `:panic`,
`:out_of_gas`, `{:fault, address}` or `{:ecall, host_call_id}`. A `trap` instruction
ends in `:panic`.

## Layout

- `lib/codec`: program blob encoding and decoding
- `lib/instructions`: opcode table and dispatch, grouped by argument shape
- `lib/memory`: paged memory with access rights
- `lib/single_step.ex`, `lib/vm.ex`: the step function and the run loop
- `lib/init_program.ex`, `lib/arg_invoc.ex`, `lib/host_call.ex`: standard program
  initialisation, argument invocation and host calls
- `lib/trace`: execution traces as text or HTML

## Tests

```sh
git clone https://github.com/jamixir/jamtestvectors ../pvm-test-vectors
mix deps.get
mix test
```

The vector tests read the PVM test vectors from `../pvm-test-vectors/pvm/programs`.

## License

[Apache-2.0](LICENSE)
