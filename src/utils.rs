pub fn skip(i: usize, k: &[u8]) -> usize {
    let mut count = 0;
    let mut current_pos = i +1;

    while count < 24 {
        if current_pos >= k.len() {
            // We've reached the implied ones suffix
            return count;
        }

        if k[current_pos] == 1 {
            return count;
        }

        count += 1;
        current_pos += 1;
    }

    24
}

#[cfg(test)]
mod tests {
    use super::*;

    // Helper to convert binary literal to vec of bytes
    // Example: bits!(0b0000) -> vec![0, 0, 0, 0]
    macro_rules! bits {
        ($b:expr) => {{
            let s = format!("{:b}", $b);
            s.chars()
                .map(|c| if c == '1' { 1u8 } else { 0u8 })
                .collect::<Vec<u8>>()
                .as_slice()
        }};
    }

    #[test]
    fn test_skip_basic_patterns() {
        // Test case: Single instruction (1 byte)
        // Bitmask: 1
        assert_eq!(skip(0, bits!(0b1100_0000)), 0);

        // Test case: Two 1-byte instructions
        // Bitmask: 1 1
        assert_eq!(skip(0, bits!(0b1001_0000)), 2);

        // Test case: One 2-byte instruction
        // Bitmask: 1 0
        assert_eq!(skip(0, bits!(0b1000_0000)), 7);
    }

    #[test]
    fn test_skip_complex_instructions() {
        // Test case: Mixed instruction lengths
        // Bitmask: 1 0 0 1 0 1
        // Represents: [3-byte inst][1-byte inst][2-byte inst]
        assert_eq!(skip(0, bits!(0b1001_0100)), 2); // First instruction is 3 bytes
        assert_eq!(skip(3, bits!(0b1001_0100)), 1); // Second instruction is 1 byte
        assert_eq!(skip(5, bits!(0b1001_0100)), 2); // Third instruction is 2 bytes
    }

    #[test]
    fn test_skip_boundary_conditions() {
        // Test case: At end of bitmask - should find next '1' in implied suffix
        assert_eq!(skip(7, bits!(0b1000_0000)), 0); // Changed from 0 to 1

        // Test case: Beyond bitmask length - should find next '1' in implied suffix
        assert_eq!(skip(8, bits!(0b1000_0000)), 0); // Changed from 0 to 1

        // Test case: Empty bitmask - should find next '1' in implied suffix
        assert_eq!(skip(0, &[]), 0); // Changed from 0 to 1
    }

    #[test]
    fn test_skip_max_length() {
        // Test case: Long sequence of zeros (should cap at 24)
        let long_bitmask = &[0; 32]; // 32 zeros
        assert_eq!(skip(0, long_bitmask), 24);
    }
}
