//! V52: explicitly bounded additional fore/aft reference range over V51.
//!
//! This changes reference authority, not measured support requirements or joint
//! and motor limits. The original preparation deadline and V51 IK remain active.
pub const POLICY: &str = "sporespore_balanced_wave_recovery_extended_support_transfer_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_extended_support_transfer_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_extended_support_transfer_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_extended_support_transfer_controller_step_receipt_v1";
pub const MAX_BIAS: f64 = 0.30;

/// Internal policy selection, never a caller-supplied numeric override.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ReferenceRange {
    Original,
    Extended,
}

impl ReferenceRange {
    pub(crate) fn maximum_bias(self) -> f64 {
        match self {
            Self::Original => crate::recovery_measured_support_transfer::MAX_BIAS,
            Self::Extended => MAX_BIAS,
        }
    }

    /// Predecessor receipts omit this additive field to preserve exact bytes.
    pub(crate) fn receipt_bound(self) -> Option<f64> {
        (self == Self::Extended).then_some(MAX_BIAS)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::recovery_measured_support_transfer::Memory;

    #[test]
    fn extended_memory_has_explicit_finite_bounds_and_original_refuses_it() {
        for bias in [-0.30, -0.27, 0.27, 0.30] {
            let memory = Memory { hip_bias_rad: bias, ..Default::default() };
            assert!(memory.validate(false).is_err());
            assert!(memory.validate_range(false, ReferenceRange::Extended).is_ok());
            assert!(memory.validate_range(true, ReferenceRange::Extended).is_err());
        }
        for bias in [-0.30000001, 0.30000001, f64::NAN, f64::INFINITY] {
            let memory = Memory { hip_bias_rad: bias, ..Default::default() };
            assert!(memory.validate_range(false, ReferenceRange::Extended).is_err());
        }
        assert!(Memory::default().validate_range(true, ReferenceRange::Extended).is_ok());
        assert_eq!(None, ReferenceRange::Original.receipt_bound());
        assert_eq!(Some(0.30), ReferenceRange::Extended.receipt_bound());
    }
}
