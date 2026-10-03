//! V44: request support, not a frozen walking lift, during V43's finite hold.
//!
//! This is a reference posture. It never replaces measured orientation/contact,
//! advances the gait clock, extends the timeout, or estimates contact forces.
use serde::{Deserialize, Serialize};
use crate::recovery_support_plane::WaveSnapshot;

pub const POLICY: &str = "sporespore_balanced_wave_recovery_support_hold_posture_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_support_hold_posture_profile_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_support_hold_posture_memory_v1";
pub const MODE: &str = "finite_hold_all_limb_upright_support_without_swing_lift_v1";
pub const RECEIPT: &str = "sporespore_recovery_support_hold_posture_controller_step_receipt_v1";

pub(crate) fn without_lift(wave: &WaveSnapshot) -> WaveSnapshot {
    let mut reference = wave.clone();
    for limb in &mut reference.ordered_limbs { limb.walking_knee_fraction = 0.0; }
    reference
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub mode_id: String,
    pub source_semantic_step: u64,
    pub enabled: bool,
    pub effective_reference_wave: WaveSnapshot,
    pub same_mode_comparison_wave: Option<WaveSnapshot>,
    pub scheduled_wave_memory_preserved: bool,
    pub measured_pose_and_contact_preserved: bool,
    pub physical_acceptance_authority: bool,
}
