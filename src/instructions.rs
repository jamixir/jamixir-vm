#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Opcode {
    Trap,
    Fallthrough,
    StoreImmU8,
}

pub type Gas = u32;

impl From<u8> for Opcode {
    fn from(byte: u8) -> Self {
        match byte {
            0 => Opcode::Trap,
            17 => Opcode::Fallthrough,
            62 => Opcode::StoreImmU8,
            _ => Opcode::Trap, // Default to trap for unknown opcodes
        }
    }
}

impl From<Opcode> for Gas {
    fn from(opcode: Opcode) -> Self {
        match opcode {
            Opcode::Trap => 0,
            Opcode::Fallthrough => 0,
            Opcode::StoreImmU8 => 0,
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_opcode_from_byte() {
        assert_eq!(Opcode::from(0), Opcode::Trap);
        assert_eq!(Opcode::from(17), Opcode::Fallthrough);
        assert_eq!(Opcode::from(62), Opcode::StoreImmU8);

        // Unknown opcodes should default to Trap
        assert_eq!(Opcode::from(255), Opcode::Trap);
        assert_eq!(Opcode::from(1), Opcode::Trap);
    }

    #[test]
    fn test_gas_from_opcode() {
        assert_eq!(Gas::from(Opcode::Trap), 0);
        assert_eq!(Gas::from(Opcode::Fallthrough), 0);
        assert_eq!(Gas::from(Opcode::StoreImmU8), 0);
    }
}
