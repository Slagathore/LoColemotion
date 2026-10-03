//! V46: use actual body orientation for V45's support and finite-hold goals.
//! All transfer conditions, native contacts, motor bounds and timeouts persist.
pub const POLICY: &str = "sporespore_balanced_wave_recovery_measured_pose_support_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_measured_pose_support_profile_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_measured_pose_support_memory_v1";
pub const RECEIPT: &str = "sporespore_recovery_measured_pose_support_controller_step_receipt_v1";
pub const MODE: &str = "measured_pose_support_and_contact_selected_reference_velocity_v1";
pub const HOLD_MODE: &str = "finite_hold_measured_pose_support_without_swing_lift_v1";
