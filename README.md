# JamixirVM

JamixirVM is an Elixir implementation of the Polkadot Virtual Machine (PVM).

## Installation

Add JamixirVM to your project's dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jamixir_vm, git: "https://github.com/jamixir/jamixir-vm.git"}
  ]
end
```

## Usage

Here's a basic example of how to use JamixirVM:

```elixir
alias PVM.State

# Create an initial state with default values
initial_state = State.new()

# Create your program (example: store value 42 at memory address 10)
program = <<
  # store_imm_u8 addr=10, value=42
  62, 1, 10, 42
>>
bitmask = <<1, 0, 0, 0>>  # Mark instruction start

# Encode the program
encoded_program = PVM.Encoder.encode_program(program, bitmask)

# Execute the program
{exit_reason, final_state} = VM.execute(encoded_program, initial_state)

# Handle the execution result
case exit_reason do
  :panic -> IO.puts "Program completed normally"
  :halt -> IO.puts "Program halted"
  {:fault, addr} -> IO.puts "Memory fault at address #{addr}"
  :out_of_gas -> IO.puts "Program ran out of gas"
end
```

## Exit Reasons

The VM can return the following exit reasons:

- `:panic` - Normal program termination (usually via fallthrough)
- `:halt` - Program explicitly halted
- `{:fault, addr}` - Memory access fault at specified address
- `:out_of_gas` - Program exceeded its gas allocation

## State Structure

The VM state contains:

- `counter` - Current instruction pointer
- `gas` - Remaining gas for execution
- `registers` - Array of 64-bit registers
- `memory` - Program memory space with access controls


## Testing

Run the test suite with:

```bash
mix test
```

See `test/vm_test.exs` for comprehensive examples of VM programs and usage.

