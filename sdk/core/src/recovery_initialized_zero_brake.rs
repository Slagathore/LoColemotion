//! V55 preserves bounded initialization feedback before enabled motor braking.
//! Initialization is native memory state, never a seed or role exception.
use crate::protocol::ActuationFrame;
use crate::quadruped::CompiledQuadruped;
use crate::schema::Result;

pub const POLICY: &str = "sporespore_balanced_wave_recovery_initialized_zero_brake_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_initialized_zero_brake_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_initialized_zero_brake_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_initialized_zero_brake_controller_step_receipt_v1";

/// Apply only after valid zero-amplitude reference generation. The validated
/// incoming memory determines whether a previous native sample exists.
pub(crate) fn apply(actuation: &mut ActuationFrame, compiled: &CompiledQuadruped,
    initialized: bool) -> Result<()> {
    if initialized {
        crate::recovery_zero_velocity_brake::apply(actuation, compiled)
    } else {
        crate::recovery_bounded_stop_velocity::apply(actuation, compiled)
    }
}
