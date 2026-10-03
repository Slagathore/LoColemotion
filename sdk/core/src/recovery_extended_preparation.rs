//! V56 adds one bounded second of the unchanged V55 preparation law.
//!
//! This is a policy-owned deadline, not a caller-supplied limit. The release
//! predicates, motor commands and outer finite walking horizon are unchanged.
pub const POLICY: &str = "sporespore_balanced_wave_recovery_extended_preparation_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_extended_preparation_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_extended_preparation_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_extended_preparation_controller_step_receipt_v1";
pub const MAX_PREPARATION: u32 = 360;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum PreparationBudget {
    Original,
    Extended,
}

impl PreparationBudget {
    pub(crate) fn maximum(self) -> u32 {
        match self {
            Self::Original => crate::recovery_measured_support_transfer::MAX_PREPARATION,
            Self::Extended => MAX_PREPARATION,
        }
    }

    /// Old receipts omit this field and retain their exact serialization.
    pub(crate) fn receipt_bound(self) -> Option<u32> {
        (self == Self::Extended).then_some(MAX_PREPARATION)
    }
}
