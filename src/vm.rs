use std::collections::HashMap;

use crate::instructions::*;
use crate::utils::*;

// Input state for a PVM step
#[derive(Debug, Clone)]
pub struct PVMState {
    program: Vec<u8>,         // c in spec
    bitmask: Vec<u8>,         // k in spec
    jump_table: Vec<u32>,     // j in spec
    counter: usize,           // ι in spec
    gas: Gas,                 // ϱ in spec
    registers: [u32; 13],     // ω in spec
    memory: HashMap<u32, u8>, // μ in spec
}

// Output state after a step
#[derive(Debug, Default)]
pub struct StepOutput {
    exit_status: StepResult,  // ε in spec
    counter: usize,           // ι' in spec
    gas: Gas,                 // ϱ' in spec
    registers: [u32; 13],     // ω' in spec
    memory: HashMap<u32, u8>, // μ' in spec
}

impl From<&PVMState> for StepOutput {
    fn from(state: &PVMState) -> Self {
        Self {
            exit_status: StepResult::default(),
            counter: state.counter,
            gas: state.gas,
            registers: state.registers,
            memory: state.memory.clone(),
        }
    }
}

impl StepOutput {
    pub fn with_exit_status(mut self, exit_status: StepResult) -> Self {
        self.exit_status = exit_status;
        self
    }

    // Builder-style methods
    fn with_memory(mut self, memory: HashMap<u32, u8>) -> Self {
        self.memory = memory;
        self
    }

    fn with_registers(mut self, registers: [u32; 13]) -> Self {
        self.registers = registers;
        self
    }

    // Helper to create a standard transition
    fn standard_transition(state: &PVMState, skip_amount: usize, gas_cost: Gas) -> Self {
        Self {
            exit_status: StepResult::Continue,
            counter: state.counter + 1 + skip_amount,
            gas: state.gas - gas_cost,
            registers: state.registers,
            memory: state.memory.clone(),
        }
    }

    // Helper to modify memory without cloning unless necessary
    fn modify_memory<F>(mut self, f: F) -> Self
    where
        F: FnOnce(&mut HashMap<u32, u8>),
    {
        let mut memory = self.memory;
        f(&mut memory);
        self.memory = memory;
        self
    }
}

#[derive(Debug, Default, PartialEq)]
pub enum StepResult {
    #[default]
    Continue, // ▶ in spec
    Halt,           // ▢ in spec
    Panic,          // ⚡ in spec
    OutOfGas,       // ∞ in spec
    HostCall(u32),  // h in spec
    PageFault(u32), // ∃ in spec
}

// Single-step transition function (Ψ₁)
pub fn step(state: &PVMState) -> StepOutput {
    // Early returns for gas and bounds checks
    if state.gas < 1 {
        return StepOutput::from(state).with_exit_status(StepResult::OutOfGas);
    }

    if state.counter >= state.program.len() {
        return StepOutput::from(state).with_exit_status(StepResult::Halt);
    }

    let opcode = Opcode::from(state.program[state.counter]);
    let gas_cost = Gas::from(opcode);
    let skip_amount = skip(state.counter, &state.bitmask);

    // Create base transition
    let output = StepOutput::standard_transition(state, skip_amount, gas_cost);

    // Each match arm now focuses only on its unique behavior
    match opcode {
        Opcode::Trap => output.with_exit_status(StepResult::Panic),
        Opcode::Fallthrough => output,
        Opcode::StoreImmU8 => {
            let address = state.registers[0];
            let value = state.program[state.counter + 1];

            output.modify_memory(|memory| {
                memory.insert(address, value);
            })
        }
    }
}

// Full PVM execution (Ψ)
pub fn execute(initial_state: &PVMState) -> StepOutput {
    let step_result = step(initial_state);

    match step_result.exit_status {
        // If Continue, recursively call with updated state
        StepResult::Continue => execute(&PVMState {
            program: initial_state.program.clone(),
            bitmask: initial_state.bitmask.clone(),
            jump_table: initial_state.jump_table.clone(),
            counter: step_result.counter,
            gas: step_result.gas,
            registers: step_result.registers,
            memory: step_result.memory,
        }),
        // Otherwise return the final state
        _ => step_result,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::instructions::*;

    fn create_trap_state() -> PVMState {
        PVMState {
            program: vec![0, 0, 0, 0], // All traps
            bitmask: vec![1, 1, 0, 0], // Each byte is an instruction
            jump_table: vec![],
            counter: 0,
            gas: 100,
            registers: [0; 13],
            memory: HashMap::new(),
        }
    }

    #[test]
    fn test_step_trap() {
        let state = create_trap_state();

        let output = step(&state);

        assert_eq!(output.exit_status, StepResult::Panic);
        assert_eq!(output.counter, state.counter); // Counter shouldn't advance
        assert_eq!(output.gas, state.gas); // No gas should be consumed
        assert_eq!(output.registers, state.registers); // Registers unchanged
        assert_eq!(output.memory, state.memory); // Memory unchanged
    }

    #[test]
    fn test_execute_trap() {
        let state = create_trap_state();

        let output = execute(&state);

        // Should immediately halt with Panic on first Trap
        assert_eq!(output.exit_status, StepResult::Panic);
        assert_eq!(output.counter, 0); // Counter should stay at 0
        assert_eq!(output.gas, 100); // Gas unchanged
        assert_eq!(output.registers, [0; 13]); // Registers unchanged
        assert!(output.memory.is_empty()); // Memory unchanged
    }

    #[test]
    fn test_step_trap_no_gas() {
        let mut state = create_trap_state();
        state.gas = 0;

        let output = step(&state);

        assert_eq!(output.exit_status, StepResult::OutOfGas);
        assert_eq!(output.counter, 0);
        assert_eq!(output.gas, 0);
        assert_eq!(output.registers, [0; 13]);
        assert!(output.memory.is_empty());
    }

    #[test]
    fn test_step_trap_out_of_bounds() {
        let mut state = create_trap_state();
        state.counter = 4; // Beyond program length

        let output = step(&state);

        assert_eq!(output.exit_status, StepResult::Halt);
        assert_eq!(output.counter, 4);
        assert_eq!(output.gas, 100);
        assert_eq!(output.registers, [0; 13]);
        assert!(output.memory.is_empty());
    }
}
