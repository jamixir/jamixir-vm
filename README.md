# JamixirVM

JamixirVM is an elixir implementation of the Polkadot Virtual Machine (PVM)


## Installation

Add JamixirVM to your project's dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jamixir_vm, git: "https://github.com/jamixir/pvm.git"}
  ]
end
```

## Usage

Here's a basic example of how to use JamixirVM:

```elixir
alias PVM.State

# Create an initial state
state = %State{
  program: <<program_bytes>>,    # Your program bytecode
  bitmask: <<bitmask_bytes>>,    # Instruction start markers
  jump_table: [],
  counter: 0,
  gas: 100,                      # Initial gas allocation
  registers: List.duplicate(0, 13),
  memory: Memory.new(100)        # Initialize memory with size 100
}

# Execute the program
result = VM.execute(state)

# Handle the execution result
case result.exit_status do
  :continue -> IO.puts "Program completed successfully"
  :panic -> IO.puts "Program panicked"
  {:ecall, value} -> IO.puts "Program made external call with value #{value}"
  {:fault, addr} -> IO.puts "Memory fault at address #{addr}"
  :out_of_gas -> IO.puts "Program ran out of gas"
end
```

## Exit Status Types

- `:continue` - Program execution can continue
- `:panic` - Program encountered a trap or invalid jump
- `{:ecall, value}` - Program made an external call
- `{:fault, addr}` - Memory access fault at specified address
- `:out_of_gas` - Program exceeded its gas allocation

