use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::controller::{
    BALANCED_WAVE_BW2_B_POLICY_ID, BALANCED_WAVE_BW2_C_POLICY_ID, BALANCED_WAVE_BW2R_A_POLICY_ID,
    BALANCED_WAVE_BW2R_B_POLICY_ID, BALANCED_WAVE_BW2R_C_POLICY_ID, BALANCED_WAVE_BW4R_A_POLICY_ID,
    BALANCED_WAVE_BW4R_B_POLICY_ID, BALANCED_WAVE_BW5R_A_POLICY_ID, BALANCED_WAVE_BW5R_B_POLICY_ID,
    BALANCED_WAVE_BW5R_C_POLICY_ID, BALANCED_WAVE_BW7D_A_POLICY_ID, BALANCED_WAVE_BW7D_B_POLICY_ID,
    BALANCED_WAVE_BW7D_C_POLICY_ID, BALANCED_WAVE_BW7D_D_POLICY_ID, BALANCED_WAVE_BW8U_A_POLICY_ID,
    BALANCED_WAVE_BW8U_B_POLICY_ID, BALANCED_WAVE_BW8U_C_POLICY_ID, BALANCED_WAVE_BW8U_D_POLICY_ID,
    BALANCED_WAVE_BW14V_B_POLICY_ID, BALANCED_WAVE_BW15F_B_POLICY_ID,
    BALANCED_WAVE_BW15F_C_POLICY_ID, BALANCED_WAVE_BW15F_D_POLICY_ID,
    BALANCED_WAVE_BW21L_B_POLICY_ID, BALANCED_WAVE_BW21L_C_POLICY_ID,
    BALANCED_WAVE_BW21L_D_POLICY_ID, BALANCED_WAVE_BW23Y_B_POLICY_ID,
    BALANCED_WAVE_BW34Y_A_POLICY_ID, BALANCED_WAVE_POLICY_ID,
    BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
    BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID,
    BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BalancedWaveProfile, CANDIDATE35_POLICY_ID, COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID,
    BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID, SCHEDULED_SWING_END_RECONTACT_MODE_ID,
    DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
    FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID,
    MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
    PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID, RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID,
    RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID, TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    balanced_wave_profile_for_policy,
};
use crate::protocol::{
    ACTUATION_FRAME_VERSION, ActuationFrame, ActuatorCommand, ContactQuality,
    ControllerStepReceipt, ForwardVelocityFootPlacementLimbReceipt,
    ForwardVelocityFootPlacementReceipt, MotionCommand, PhaseProgressionMode,
    ReleaseGateUnweightingReceipt, SpeedClass, StateFrame, SteeringAuthorityGuardReceipt, dot,
    subtract,
};
use crate::quadruped::CompiledQuadruped;
use crate::schema::{CoreError, Result, Vec3};

pub const CANDIDATE35_RUNTIME_VERSION: &str = "sporespore_candidate35_runtime_v2";
pub const CANDIDATE35_MEMORY_VERSION: &str = "sporespore_candidate35_memory_v2";
pub const BALANCED_WAVE_RUNTIME_VERSION: &str = "sporespore_balanced_wave_runtime_v1";
pub const BALANCED_WAVE_MEMORY_VERSION: &str = "sporespore_balanced_wave_memory_v1";
pub const BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_persistent_predictive_guard_memory_v1";

const CYCLE_STEPS: u64 = 360;
pub(crate) const SWING_STEPS: u64 = 72;
const RELEASE_GATE_LOCAL_STEP: u64 = 54;
const RECONTACT_GATE_LOCAL_STEP: u64 = 144;
pub(crate) const MINIMUM_GATE_DWELL_STEPS: u32 = 3;
pub(crate) const MAXIMUM_GATE_HOLD_STEPS: u32 = 120;
const MAXIMUM_PHASE_SKEW_STEPS: u64 = 12;
const STEERING_UPDATE_INTERVAL_STEPS: u64 = 90;
const MAXIMUM_DESIRED_HEADING_ERROR_RAD: f64 = 0.25;
const MAXIMUM_STEERING_FRACTION: f64 = 0.40;
const MOTOR_POSITION_GAIN_PER_S: f64 = 8.0;
const MOTOR_RATE_DAMPING: f64 = 0.65;
const CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S: f64 = 3.5;
const MOTOR_DIRECTION_SIGN: f64 = -1.0;
const HIP_FORWARD_TARGET_RAD: f64 = 0.30;
const HIP_REAR_TARGET_RAD: f64 = -0.30;
const KNEE_SWING_FLEXION_RAD: f64 = 0.82;
const KNEE_FLEXION_SCALE: f64 = 1.75;
const CONTACT_CLEARANCE_ASSIST_RAD: f64 = 0.40;
pub const BALANCED_WAVE_RECOVERY_SMOOTH_SWING_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_smooth_swing_memory_v1";
pub const BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_reference_velocity_memory_v1";
pub const BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_wave_velocity_memory_v1";
pub const BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_airborne_reference_memory_v1";
pub const BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_absent_contact_reference_memory_v1";
pub const BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_upright_stance_memory_v1";
pub const BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION: &str =
    "sporespore_balanced_wave_recovery_stance_latched_upright_memory_v1";
const MAXIMUM_ANCHOR_ERROR_UPPER_LEG_FRACTION: f64 = 0.14;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LimbRuntimeMemory {
    pub limb_id: String,
    pub gait_step: u64,
    pub evidence_gait_step_limit: Option<u64>,
    pub current_gate_hold_steps: u32,
    pub current_gate_transition_dwell_steps: u32,
    pub release_hold_step_count: u64,
    pub recontact_hold_step_count: u64,
    pub gate_timeout_count: u64,
    pub phase_sync_hold_step_count: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Candidate35ControllerMemory {
    pub schema_version: String,
    pub last_semantic_step: Option<u64>,
    pub phase_progression_mode: Option<PhaseProgressionMode>,
    pub held_path_steering_fraction: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_floor_hold_steps_remaining: Option<u64>,
    pub ordered_limb_memory: Vec<LimbRuntimeMemory>,
}

impl Candidate35ControllerMemory {
    pub fn initial() -> Self {
        Self::initial_with_version(CANDIDATE35_MEMORY_VERSION)
    }

    fn initial_with_version(schema_version: &str) -> Self {
        Self {
            schema_version: schema_version.to_owned(),
            last_semantic_step: None,
            phase_progression_mode: None,
            held_path_steering_fraction: 0.0,
            steering_guard_floor_hold_steps_remaining: None,
            ordered_limb_memory: ["rear_left", "front_left", "rear_right", "front_right"]
                .into_iter()
                .map(|limb_id| LimbRuntimeMemory {
                    limb_id: limb_id.to_owned(),
                    gait_step: 0,
                    evidence_gait_step_limit: None,
                    current_gate_hold_steps: 0,
                    current_gate_transition_dwell_steps: 0,
                    release_hold_step_count: 0,
                    recontact_hold_step_count: 0,
                    gate_timeout_count: 0,
                    phase_sync_hold_step_count: 0,
                })
                .collect(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BalancedWaveControllerMemory {
    pub schema_version: String,
    pub last_semantic_step: Option<u64>,
    pub phase_progression_mode: Option<PhaseProgressionMode>,
    pub held_path_steering_fraction: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_reference: Option<crate::recovery_support_plane::SupportReferenceMemory>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_progression: Option<crate::recovery_support_progression::Memory>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub measured_support_transfer: Option<crate::recovery_measured_support_transfer::Memory>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub anchored_body_pose: Option<crate::recovery_anchored_body_pose::Memory>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub joint_pose_entry: Option<crate::joint_pose_entry::Memory>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_reference_sha256: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_floor_hold_steps_remaining: Option<u64>,
    pub ordered_limb_memory: Vec<LimbRuntimeMemory>,
}

impl BalancedWaveControllerMemory {
    pub fn initial() -> Self {
        Self::from_internal(Candidate35ControllerMemory::initial_with_version(
            BALANCED_WAVE_MEMORY_VERSION,
        ))
    }

    fn as_internal(&self) -> Candidate35ControllerMemory {
        Candidate35ControllerMemory {
            schema_version: self.schema_version.clone(),
            last_semantic_step: self.last_semantic_step,
            phase_progression_mode: self.phase_progression_mode,
            held_path_steering_fraction: self.held_path_steering_fraction,
            steering_guard_floor_hold_steps_remaining: self
                .steering_guard_floor_hold_steps_remaining,
            ordered_limb_memory: self.ordered_limb_memory.clone(),
        }
    }

    fn from_internal(memory: Candidate35ControllerMemory) -> Self {
        Self {
            schema_version: memory.schema_version,
            last_semantic_step: memory.last_semantic_step,
            phase_progression_mode: memory.phase_progression_mode,
            held_path_steering_fraction: memory.held_path_steering_fraction,
            support_reference: None,
            support_progression: None,
            measured_support_transfer: None,
            anchored_body_pose: None,
            joint_pose_entry: None,
            floor_reference_sha256: None,
            steering_guard_floor_hold_steps_remaining: memory
                .steering_guard_floor_hold_steps_remaining,
            ordered_limb_memory: memory.ordered_limb_memory,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ControllerStepOutput {
    pub schema_version: String,
    pub actuation: ActuationFrame,
    pub next_memory: Candidate35ControllerMemory,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BalancedWaveControllerStepOutput {
    pub schema_version: String,
    pub actuation: ActuationFrame,
    pub next_memory: BalancedWaveControllerMemory,
}

#[derive(Debug, Clone)]
struct WaveRuntimeProfile {
    cross_track_heading_gain_rad_per_m: f64,
    yaw_error_stride_gain_per_rad: f64,
    cross_track_velocity_heading_gain_rad_per_m_s: f64,
    steering_feedback_update_interval_steps: u64,
    maximum_steering_fraction_delta_per_step: Option<f64>,
    maximum_steering_fraction: f64,
    steering_authority_guard_mode_id: Option<String>,
    minimum_steering_fraction: Option<f64>,
    steering_guard_full_authority_maximum_tilt_rad: Option<f64>,
    steering_guard_minimum_authority_tilt_rad: Option<f64>,
    steering_guard_minimum_support_contact_count: Option<u32>,
    steering_guard_prediction_horizon_s: Option<f64>,
    steering_guard_floor_hold_steps: Option<u64>,
    steering_low_pass_time_constant_cycle_fraction: Option<f64>,
    steering_stride_transform_id: Option<String>,
    release_gate_unweighting_receipt_enabled: bool,
    release_gate_knee_target_mode_id: Option<String>,
    release_gate_hip_target_mode_id: Option<String>,
    forward_velocity_foot_placement_mode_id: Option<String>,
    maximum_forward_velocity_hip_target_correction_rad: Option<f64>,
    forward_velocity_error_orientation_id: Option<String>,
    cross_track_frame_mode_id: Option<String>,
    contact_loaded_swing_knee_activation_start_phase_step: u32,
    contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: f64,
    anchor_error_guard_activation_fraction: f64,
    anchor_error_guard_maximum_motor_target_speed_rad_s: f64,
    blend_anchor_guard_by_interaction_score: bool,
    recontact_gate_local_step: u64,
}

impl WaveRuntimeProfile {
    fn from_balanced(profile: &BalancedWaveProfile) -> Self {
        Self {
            cross_track_heading_gain_rad_per_m: profile.cross_track_heading_gain_rad_per_m,
            yaw_error_stride_gain_per_rad: profile.yaw_error_stride_gain_per_rad,
            cross_track_velocity_heading_gain_rad_per_m_s: profile
                .cross_track_velocity_heading_gain_rad_per_m_s,
            steering_feedback_update_interval_steps: profile
                .steering_feedback_update_interval_steps
                .unwrap_or(STEERING_UPDATE_INTERVAL_STEPS),
            maximum_steering_fraction_delta_per_step: profile
                .maximum_steering_fraction_delta_per_step,
            maximum_steering_fraction: profile
                .maximum_steering_fraction
                .unwrap_or(MAXIMUM_STEERING_FRACTION),
            steering_authority_guard_mode_id: profile.steering_authority_guard_mode_id.clone(),
            minimum_steering_fraction: profile.minimum_steering_fraction,
            steering_guard_full_authority_maximum_tilt_rad: profile
                .steering_guard_full_authority_maximum_tilt_rad,
            steering_guard_minimum_authority_tilt_rad: profile
                .steering_guard_minimum_authority_tilt_rad,
            steering_guard_minimum_support_contact_count: profile
                .steering_guard_minimum_support_contact_count,
            steering_guard_prediction_horizon_s: profile.steering_guard_prediction_horizon_s,
            steering_guard_floor_hold_steps: profile.steering_guard_floor_hold_steps,
            steering_low_pass_time_constant_cycle_fraction: profile
                .steering_low_pass_time_constant_cycle_fraction,
            steering_stride_transform_id: profile.steering_stride_transform_id.clone(),
            release_gate_unweighting_receipt_enabled: profile.schema_version
                == "sporespore_balanced_wave_release_gate_unweighting_profile_v1",
            release_gate_knee_target_mode_id: profile.release_gate_knee_target_mode_id.clone(),
            release_gate_hip_target_mode_id: profile.release_gate_hip_target_mode_id.clone(),
            forward_velocity_foot_placement_mode_id: profile
                .forward_velocity_foot_placement_mode_id
                .clone(),
            maximum_forward_velocity_hip_target_correction_rad: profile
                .maximum_forward_velocity_hip_target_correction_rad,
            forward_velocity_error_orientation_id: profile
                .forward_velocity_error_orientation_id
                .clone(),
            cross_track_frame_mode_id: profile.cross_track_frame_mode_id.clone(),
            contact_loaded_swing_knee_activation_start_phase_step: profile
                .contact_loaded_swing_knee_activation_start_phase_step,
            contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: profile
                .contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
            anchor_error_guard_activation_fraction: profile.anchor_error_guard_activation_fraction,
            anchor_error_guard_maximum_motor_target_speed_rad_s: profile
                .anchor_error_guard_maximum_motor_target_speed_rad_s,
            blend_anchor_guard_by_interaction_score: false,
            recontact_gate_local_step: if profile.recontact_gate_mode_id.as_deref()
                == Some(SCHEDULED_SWING_END_RECONTACT_MODE_ID)
            {
                SWING_STEPS
            } else {
                RECONTACT_GATE_LOCAL_STEP
            },
        }
    }
}

fn steering_authority_guard_receipt(
    profile: &WaveRuntimeProfile,
    state: &StateFrame,
) -> Result<Option<SteeringAuthorityGuardReceipt>> {
    let Some(mode_id) = profile.steering_authority_guard_mode_id.as_deref() else {
        if profile.minimum_steering_fraction.is_some()
            || profile
                .steering_guard_full_authority_maximum_tilt_rad
                .is_some()
            || profile.steering_guard_minimum_authority_tilt_rad.is_some()
            || profile
                .steering_guard_minimum_support_contact_count
                .is_some()
            || profile.steering_guard_prediction_horizon_s.is_some()
            || profile.steering_guard_floor_hold_steps.is_some()
        {
            return Err(CoreError::Identity(
                "balanced_wave_steering_guard_parameters_without_mode".to_owned(),
            ));
        }
        return Ok(None);
    };
    let predictive = match mode_id {
        TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID => false,
        PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID
        | PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID => true,
        _ => {
            return Err(CoreError::Identity(format!(
                "balanced_wave_steering_authority_guard_mode:{mode_id}"
            )));
        }
    };
    let baseline = profile.minimum_steering_fraction.ok_or_else(|| {
        CoreError::Identity("balanced_wave_steering_guard_minimum_missing".to_owned())
    })?;
    let full_tilt = profile
        .steering_guard_full_authority_maximum_tilt_rad
        .ok_or_else(|| {
            CoreError::Identity("balanced_wave_steering_guard_full_tilt_missing".to_owned())
        })?;
    let minimum_tilt = profile
        .steering_guard_minimum_authority_tilt_rad
        .ok_or_else(|| {
            CoreError::Identity("balanced_wave_steering_guard_minimum_tilt_missing".to_owned())
        })?;
    let minimum_contacts = profile
        .steering_guard_minimum_support_contact_count
        .ok_or_else(|| {
            CoreError::Identity("balanced_wave_steering_guard_contact_count_missing".to_owned())
        })?;
    let prediction_horizon_s = match (predictive, profile.steering_guard_prediction_horizon_s) {
        (false, None) => None,
        (true, Some(value)) if value.is_finite() && value > 0.0 => Some(value),
        _ => {
            return Err(CoreError::Identity(
                "balanced_wave_steering_guard_prediction_horizon_invalid".to_owned(),
            ));
        }
    };
    match (
        mode_id == PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
        profile.steering_guard_floor_hold_steps,
    ) {
        (false, None) => {}
        (true, Some(steps)) if steps > 0 && steps % SWING_STEPS == 0 => {}
        _ => {
            return Err(CoreError::Identity(
                "balanced_wave_steering_guard_floor_hold_invalid".to_owned(),
            ));
        }
    }
    if !baseline.is_finite()
        || !profile.maximum_steering_fraction.is_finite()
        || !full_tilt.is_finite()
        || !minimum_tilt.is_finite()
        || baseline <= 0.0
        || baseline > profile.maximum_steering_fraction
        || profile.maximum_steering_fraction > MAXIMUM_STEERING_FRACTION
        || full_tilt < 0.0
        || minimum_tilt <= full_tilt
        || minimum_contacts == 0
    {
        return Err(CoreError::Identity(
            "balanced_wave_steering_guard_parameters_invalid".to_owned(),
        ));
    }

    let orientation = state.base_pose_world.orientation_xyzw;
    let torso_up = Vec3 {
        x: 2.0 * (orientation.x * orientation.y - orientation.w * orientation.z),
        y: orientation.w * orientation.w - orientation.x * orientation.x
            + orientation.y * orientation.y
            - orientation.z * orientation.z,
        z: 2.0 * (orientation.y * orientation.z + orientation.w * orientation.x),
    };
    let gravity = state.gravity_world_m_s2;
    let gravity_magnitude =
        (gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z).sqrt();
    if !gravity_magnitude.is_finite() || gravity_magnitude <= 1.0e-12 {
        return Err(CoreError::Frame(
            "balanced_wave_steering_guard_gravity_invalid".to_owned(),
        ));
    }
    let gravity_up = Vec3 {
        x: -gravity.x / gravity_magnitude,
        y: -gravity.y / gravity_magnitude,
        z: -gravity.z / gravity_magnitude,
    };
    let torso_tilt_rad = dot(torso_up, gravity_up).clamp(-1.0, 1.0).acos();
    let (torso_tilt_rate_rad_s, worsening_torso_tilt_rate_rad_s, predicted_torso_tilt_rad) =
        if let Some(horizon_s) = prediction_horizon_s {
            let angular_velocity = state.base_twist_world.angular_velocity_rad_s;
            let torso_up_derivative = Vec3 {
                x: angular_velocity.y * torso_up.z - angular_velocity.z * torso_up.y,
                y: angular_velocity.z * torso_up.x - angular_velocity.x * torso_up.z,
                z: angular_velocity.x * torso_up.y - angular_velocity.y * torso_up.x,
            };
            let cosine = dot(torso_up, gravity_up).clamp(-1.0, 1.0);
            let sine = (1.0 - cosine * cosine).max(0.0).sqrt();
            let tilt_rate = if sine > 1.0e-9 {
                -dot(torso_up_derivative, gravity_up) / sine
            } else {
                (torso_up_derivative.x * torso_up_derivative.x
                    + torso_up_derivative.y * torso_up_derivative.y
                    + torso_up_derivative.z * torso_up_derivative.z)
                    .sqrt()
            };
            if !tilt_rate.is_finite() {
                return Err(CoreError::Frame(
                    "balanced_wave_predictive_steering_guard_tilt_rate_invalid".to_owned(),
                ));
            }
            let worsening_rate = tilt_rate.max(0.0);
            let predicted =
                (torso_tilt_rad + worsening_rate * horizon_s).clamp(0.0, std::f64::consts::PI);
            (Some(tilt_rate), Some(worsening_rate), Some(predicted))
        } else {
            (None, None, None)
        };
    let authority_tilt_rad = predicted_torso_tilt_rad.unwrap_or(torso_tilt_rad);

    let mut support_contact_count = 0_u32;
    let mut uses_presence_fallback = false;
    for contact in &state.ordered_contact_observations {
        let supports = match contact.bears_support {
            Some(value) => value,
            None => {
                uses_presence_fallback = true;
                contact.presence.unwrap_or(false)
            }
        };
        if supports {
            support_contact_count = support_contact_count.checked_add(1).ok_or_else(|| {
                CoreError::Frame("balanced_wave_steering_guard_contact_overflow".to_owned())
            })?;
        }
    }
    let contact_authority_permitted = support_contact_count >= minimum_contacts;
    let tilt_authority_fraction =
        if !contact_authority_permitted || authority_tilt_rad >= minimum_tilt {
            0.0
        } else if authority_tilt_rad <= full_tilt {
            1.0
        } else {
            (minimum_tilt - authority_tilt_rad) / (minimum_tilt - full_tilt)
        };
    let effective =
        baseline + tilt_authority_fraction * (profile.maximum_steering_fraction - baseline);
    Ok(Some(SteeringAuthorityGuardReceipt {
        schema_version: if predictive {
            "sporespore_steering_authority_guard_receipt_v2".to_owned()
        } else {
            "sporespore_steering_authority_guard_receipt_v1".to_owned()
        },
        mode_id: mode_id.to_owned(),
        torso_tilt_rad,
        torso_tilt_rate_rad_s,
        worsening_torso_tilt_rate_rad_s,
        prediction_horizon_s,
        prediction_horizon_scheduler_swing_steps: predictive.then_some(SWING_STEPS),
        predicted_torso_tilt_rad,
        tilt_rate_source_id: predictive
            .then(|| "state_frame_base_twist_world_angular_velocity_v1".to_owned()),
        prediction_horizon_basis_id: predictive
            .then(|| "one_balanced_wave_scheduler_swing_v1".to_owned()),
        support_contact_count,
        support_contact_count_uses_presence_fallback: uses_presence_fallback,
        minimum_support_contact_count: minimum_contacts,
        contact_authority_permitted,
        tilt_authority_fraction,
        baseline_maximum_steering_fraction: baseline,
        expanded_maximum_steering_fraction: profile.maximum_steering_fraction,
        effective_maximum_steering_fraction: effective,
        instantaneous_tilt_authority_fraction: None,
        instantaneous_effective_maximum_steering_fraction: None,
        floor_hold_duration_steps: None,
        floor_hold_scheduler_swing_count: None,
        floor_hold_steps_remaining_before_step: None,
        floor_hold_steps_remaining_after_step: None,
        floor_hold_triggered_this_step: None,
        floor_hold_active_this_step: None,
        floor_hold_basis_id: None,
        full_authority_maximum_tilt_rad: full_tilt,
        minimum_authority_tilt_rad: minimum_tilt,
        direction_neutral: true,
        engine_identity_input_count: 0,
        controller_parameter: true,
        turning_claim_authorized: false,
        physical_acceptance_authority: false,
    }))
}

fn apply_steering_floor_hold(
    profile: &WaveRuntimeProfile,
    memory: &Candidate35ControllerMemory,
    next_memory: &mut Candidate35ControllerMemory,
    receipt: &mut Option<SteeringAuthorityGuardReceipt>,
) -> Result<()> {
    let Some(duration_steps) = profile.steering_guard_floor_hold_steps else {
        if memory.steering_guard_floor_hold_steps_remaining.is_some() {
            return Err(CoreError::Schema(
                "balanced_wave_unexpected_steering_floor_hold_memory".to_owned(),
            ));
        }
        return Ok(());
    };
    let remaining_before = memory
        .steering_guard_floor_hold_steps_remaining
        .ok_or_else(|| {
            CoreError::Schema("balanced_wave_steering_floor_hold_memory_missing".to_owned())
        })?;
    if remaining_before > duration_steps || duration_steps % SWING_STEPS != 0 {
        return Err(CoreError::Frame(
            "balanced_wave_steering_floor_hold_memory_invalid".to_owned(),
        ));
    }
    let guard = receipt.as_mut().ok_or_else(|| {
        CoreError::Identity("balanced_wave_steering_floor_hold_guard_missing".to_owned())
    })?;
    if guard.mode_id != PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID {
        return Err(CoreError::Identity(
            "balanced_wave_steering_floor_hold_mode_invalid".to_owned(),
        ));
    }

    let instantaneous_fraction = guard.tilt_authority_fraction;
    let instantaneous_effective = guard.effective_maximum_steering_fraction;
    let triggered = instantaneous_effective <= guard.baseline_maximum_steering_fraction + 1.0e-12;
    let refreshed_remaining = if triggered {
        duration_steps
    } else {
        remaining_before
    };
    let active = refreshed_remaining > 0;
    let remaining_after = if active { refreshed_remaining - 1 } else { 0 };
    next_memory.steering_guard_floor_hold_steps_remaining = Some(remaining_after);

    guard.schema_version = "sporespore_steering_authority_guard_receipt_v3".to_owned();
    guard.instantaneous_tilt_authority_fraction = Some(instantaneous_fraction);
    guard.instantaneous_effective_maximum_steering_fraction = Some(instantaneous_effective);
    guard.floor_hold_duration_steps = Some(duration_steps);
    guard.floor_hold_scheduler_swing_count = Some(duration_steps / SWING_STEPS);
    guard.floor_hold_steps_remaining_before_step = Some(remaining_before);
    guard.floor_hold_steps_remaining_after_step = Some(remaining_after);
    guard.floor_hold_triggered_this_step = Some(triggered);
    guard.floor_hold_active_this_step = Some(active);
    guard.floor_hold_basis_id = Some("two_balanced_wave_scheduler_swings_v1".to_owned());
    if active {
        guard.tilt_authority_fraction = 0.0;
        guard.effective_maximum_steering_fraction = guard.baseline_maximum_steering_fraction;
    }
    Ok(())
}

#[derive(Debug, Clone)]
struct WaveControllerEngine {
    compiled: CompiledQuadruped,
    profile: WaveRuntimeProfile,
    policy_id: &'static str,
    runtime_version: &'static str,
    memory_version: &'static str,
    error_prefix: &'static str,
}

impl WaveControllerEngine {
    fn validate_topology(compiled: &CompiledQuadruped, error_prefix: &str) -> Result<()> {
        if compiled.morphology.ordered_limb_ids
            != ["front_left", "front_right", "rear_left", "rear_right"]
        {
            return Err(CoreError::Topology(format!(
                "{error_prefix}_requires_gq15_quadruped_roles"
            )));
        }
        Ok(())
    }

    fn candidate35(compiled: CompiledQuadruped) -> Result<Self> {
        Self::validate_topology(&compiled, "candidate35")?;
        let candidate = &compiled.candidate35_profile;
        Ok(Self {
            profile: WaveRuntimeProfile {
                cross_track_heading_gain_rad_per_m: candidate.cross_track_heading_gain_rad_per_m,
                yaw_error_stride_gain_per_rad: candidate.yaw_error_stride_gain_per_rad,
                cross_track_velocity_heading_gain_rad_per_m_s: candidate
                    .cross_track_velocity_heading_gain_rad_per_m_s,
                steering_feedback_update_interval_steps: STEERING_UPDATE_INTERVAL_STEPS,
                maximum_steering_fraction_delta_per_step: None,
                maximum_steering_fraction: MAXIMUM_STEERING_FRACTION,
                steering_authority_guard_mode_id: None,
                minimum_steering_fraction: None,
                steering_guard_full_authority_maximum_tilt_rad: None,
                steering_guard_minimum_authority_tilt_rad: None,
                steering_guard_minimum_support_contact_count: None,
                steering_guard_prediction_horizon_s: None,
                steering_guard_floor_hold_steps: None,
                steering_low_pass_time_constant_cycle_fraction: None,
                steering_stride_transform_id: None,
                release_gate_unweighting_receipt_enabled: false,
                release_gate_knee_target_mode_id: None,
                release_gate_hip_target_mode_id: None,
                forward_velocity_foot_placement_mode_id: None,
                maximum_forward_velocity_hip_target_correction_rad: None,
                forward_velocity_error_orientation_id: None,
                cross_track_frame_mode_id: None,
                contact_loaded_swing_knee_activation_start_phase_step: candidate
                    .contact_loaded_swing_knee_activation_start_phase_step,
                contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: candidate
                    .contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                anchor_error_guard_activation_fraction: candidate
                    .anchor_error_guard_activation_fraction,
                anchor_error_guard_maximum_motor_target_speed_rad_s: candidate
                    .anchor_error_guard_maximum_motor_target_speed_rad_s,
                blend_anchor_guard_by_interaction_score: true,
                recontact_gate_local_step: RECONTACT_GATE_LOCAL_STEP,
            },
            compiled,
            policy_id: CANDIDATE35_POLICY_ID,
            runtime_version: CANDIDATE35_RUNTIME_VERSION,
            memory_version: CANDIDATE35_MEMORY_VERSION,
            error_prefix: "candidate35",
        })
    }

    fn balanced_wave(
        compiled: CompiledQuadruped,
        requested_policy_id: &str,
    ) -> Result<(Self, BalancedWaveProfile)> {
        Self::validate_topology(&compiled, "balanced_wave")?;
        let policy_id = match requested_policy_id {
            crate::joint_pose_entry::POLICY => crate::joint_pose_entry::POLICY,
            crate::recovery_extended_preparation::POLICY => crate::recovery_extended_preparation::POLICY,
            crate::recovery_initialized_zero_brake::POLICY => crate::recovery_initialized_zero_brake::POLICY,
            crate::recovery_zero_velocity_brake::POLICY => crate::recovery_zero_velocity_brake::POLICY,
            crate::recovery_bounded_stop_velocity::POLICY => crate::recovery_bounded_stop_velocity::POLICY,
            crate::recovery_extended_support_transfer::POLICY => crate::recovery_extended_support_transfer::POLICY,
            crate::recovery_joint_feasible_height::POLICY => crate::recovery_joint_feasible_height::POLICY,
            crate::recovery_anchored_body_pose::STARTUP_POLICY => crate::recovery_anchored_body_pose::STARTUP_POLICY,
            crate::recovery_remaining_support_release::POLICY => crate::recovery_remaining_support_release::POLICY,
            crate::recovery_advancing_body_origin::POLICY => crate::recovery_advancing_body_origin::POLICY,
            crate::recovery_anchored_body_pose::POLICY => crate::recovery_anchored_body_pose::POLICY,
            crate::recovery_measured_pose_support::POLICY => crate::recovery_measured_pose_support::POLICY,
            crate::recovery_measured_support_transfer::POLICY => crate::recovery_measured_support_transfer::POLICY,
            crate::recovery_support_hold_posture::POLICY => crate::recovery_support_hold_posture::POLICY,
            crate::recovery_support_progression::POLICY => crate::recovery_support_progression::POLICY,
            crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID
            }
            crate::controller::BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID => {
                crate::controller::BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID
            }
            BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID => {
                BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID
            }
            BALANCED_WAVE_POLICY_ID => BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW2_B_POLICY_ID => BALANCED_WAVE_BW2_B_POLICY_ID,
            BALANCED_WAVE_BW2_C_POLICY_ID => BALANCED_WAVE_BW2_C_POLICY_ID,
            BALANCED_WAVE_BW2R_A_POLICY_ID => BALANCED_WAVE_BW2R_A_POLICY_ID,
            BALANCED_WAVE_BW2R_B_POLICY_ID => BALANCED_WAVE_BW2R_B_POLICY_ID,
            BALANCED_WAVE_BW2R_C_POLICY_ID => BALANCED_WAVE_BW2R_C_POLICY_ID,
            BALANCED_WAVE_BW4R_A_POLICY_ID => BALANCED_WAVE_BW4R_A_POLICY_ID,
            BALANCED_WAVE_BW4R_B_POLICY_ID => BALANCED_WAVE_BW4R_B_POLICY_ID,
            BALANCED_WAVE_BW5R_A_POLICY_ID => BALANCED_WAVE_BW5R_A_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID => BALANCED_WAVE_BW5R_B_POLICY_ID,
            BALANCED_WAVE_BW5R_C_POLICY_ID => BALANCED_WAVE_BW5R_C_POLICY_ID,
            BALANCED_WAVE_BW7D_A_POLICY_ID => BALANCED_WAVE_BW7D_A_POLICY_ID,
            BALANCED_WAVE_BW7D_B_POLICY_ID => BALANCED_WAVE_BW7D_B_POLICY_ID,
            BALANCED_WAVE_BW7D_C_POLICY_ID => BALANCED_WAVE_BW7D_C_POLICY_ID,
            BALANCED_WAVE_BW7D_D_POLICY_ID => BALANCED_WAVE_BW7D_D_POLICY_ID,
            BALANCED_WAVE_BW8U_A_POLICY_ID => BALANCED_WAVE_BW8U_A_POLICY_ID,
            BALANCED_WAVE_BW8U_B_POLICY_ID => BALANCED_WAVE_BW8U_B_POLICY_ID,
            BALANCED_WAVE_BW8U_C_POLICY_ID => BALANCED_WAVE_BW8U_C_POLICY_ID,
            BALANCED_WAVE_BW8U_D_POLICY_ID => BALANCED_WAVE_BW8U_D_POLICY_ID,
            BALANCED_WAVE_BW14V_B_POLICY_ID => BALANCED_WAVE_BW14V_B_POLICY_ID,
            BALANCED_WAVE_BW15F_B_POLICY_ID => BALANCED_WAVE_BW15F_B_POLICY_ID,
            BALANCED_WAVE_BW15F_C_POLICY_ID => BALANCED_WAVE_BW15F_C_POLICY_ID,
            BALANCED_WAVE_BW15F_D_POLICY_ID => BALANCED_WAVE_BW15F_D_POLICY_ID,
            BALANCED_WAVE_BW21L_B_POLICY_ID => BALANCED_WAVE_BW21L_B_POLICY_ID,
            BALANCED_WAVE_BW21L_C_POLICY_ID => BALANCED_WAVE_BW21L_C_POLICY_ID,
            BALANCED_WAVE_BW21L_D_POLICY_ID => BALANCED_WAVE_BW21L_D_POLICY_ID,
            BALANCED_WAVE_BW23Y_B_POLICY_ID => BALANCED_WAVE_BW23Y_B_POLICY_ID,
            BALANCED_WAVE_BW34Y_A_POLICY_ID => BALANCED_WAVE_BW34Y_A_POLICY_ID,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID => {
                BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID
            }
            BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID => {
                BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
            }
            BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID => {
                BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
            }
            BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID => {
                BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
            }
            BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID => {
                BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
            }
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => {
                BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID
            }
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            }
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            }
            _ => {
                return Err(CoreError::Identity(format!(
                    "balanced_wave_policy_id:{requested_policy_id}"
                )));
            }
        };
        let balanced = balanced_wave_profile_for_policy(&compiled.descriptor, policy_id)?;
        Ok((
            Self {
                profile: WaveRuntimeProfile::from_balanced(&balanced),
                compiled,
                policy_id,
                runtime_version: BALANCED_WAVE_RUNTIME_VERSION,
                memory_version: if policy_id == crate::joint_pose_entry::POLICY {
                    crate::joint_pose_entry::MEMORY
                } else if policy_id == crate::recovery_extended_preparation::POLICY {
                    crate::recovery_extended_preparation::MEMORY
                } else if policy_id == crate::recovery_initialized_zero_brake::POLICY {
                    crate::recovery_initialized_zero_brake::MEMORY
                } else if policy_id == crate::recovery_zero_velocity_brake::POLICY {
                    crate::recovery_zero_velocity_brake::MEMORY
                } else if policy_id == crate::recovery_bounded_stop_velocity::POLICY {
                    crate::recovery_bounded_stop_velocity::MEMORY
                } else if policy_id == crate::recovery_extended_support_transfer::POLICY {
                    crate::recovery_extended_support_transfer::MEMORY
                } else if policy_id == crate::recovery_joint_feasible_height::POLICY {
                    crate::recovery_joint_feasible_height::MEMORY
                } else if policy_id == crate::recovery_anchored_body_pose::STARTUP_POLICY {
                    crate::recovery_anchored_body_pose::STARTUP_MEMORY
                } else if policy_id == crate::recovery_remaining_support_release::POLICY {
                    crate::recovery_remaining_support_release::MEMORY
                } else if policy_id == crate::recovery_advancing_body_origin::POLICY {
                    crate::recovery_advancing_body_origin::MEMORY
                } else if policy_id == crate::recovery_anchored_body_pose::POLICY {
                    crate::recovery_anchored_body_pose::MEMORY
                } else if policy_id == crate::recovery_measured_pose_support::POLICY {
                    crate::recovery_measured_pose_support::MEMORY
                } else if policy_id == crate::recovery_measured_support_transfer::POLICY {
                    crate::recovery_measured_support_transfer::MEMORY
                } else if policy_id == crate::recovery_support_hold_posture::POLICY {
                    crate::recovery_support_hold_posture::MEMORY
                } else if policy_id == crate::recovery_support_progression::POLICY {
                    crate::recovery_support_progression::MEMORY
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID {
                    BALANCED_WAVE_RECOVERY_SMOOTH_SWING_MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID {
                    crate::recovery_feasible_support::MEMORY_VERSION
                } else if policy_id == crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID {
                    crate::recovery_floor_reference::MEMORY_VERSION
                } else if policy_id
                    == crate::controller::BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID
                {
                    crate::recovery_support_plane::MEMORY_VERSION
                } else if policy_id
                    == BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
                {
                    BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
                } else {
                    BALANCED_WAVE_MEMORY_VERSION
                },
                error_prefix: "balanced_wave",
            },
            balanced,
        ))
    }

    fn step(
        &self,
        memory: &Candidate35ControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
    ) -> ControllerStepOutput {
        match self.try_step(memory, state, command, false) {
            Ok(output) => output,
            Err(error) => self.safe_output(memory, state, command, error),
        }
    }

    fn try_step(
        &self,
        memory: &Candidate35ControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
        hold_phase: bool,
    ) -> Result<ControllerStepOutput> {
        self.validate_memory(memory, state.semantic_step)?;
        state.validate(&self.compiled.morphology)?;
        command.validate_for_step(state.semantic_step)?;
        if command.gait_family_id != "lateral_wave" {
            return Err(CoreError::Capability(format!(
                "{}_gait_family:{}",
                self.error_prefix, command.gait_family_id
            )));
        }
        if command.speed_class == SpeedClass::Run {
            return Err(CoreError::Capability(format!(
                "{}_running_not_supported",
                self.error_prefix
            )));
        }
        if command.desired_yaw_rate_rad_s.is_some() {
            return Err(CoreError::Capability(format!(
                "{}_yaw_rate_command",
                self.error_prefix
            )));
        }
        self.require_dynamic_observations(state)?;

        let mut next_memory = self.prospective_phase_memory(memory, state, command)?;
        if hold_phase {
            for (after,before) in next_memory.ordered_limb_memory.iter_mut().zip(&memory.ordered_limb_memory) {
                // Keep the parent's explicit evidence-limit mode transition;
                // restore only clocks/gate counters, never claim gate progress.
                let limit=after.evidence_gait_step_limit;
                *after=before.clone();after.evidence_gait_step_limit=limit;
            }
        }

        let requested_heading_error = command
            .desired_heading_rad
            .map(|heading| wrap_angle(heading - state.task_frame.reference_yaw_rad))
            .unwrap_or(0.0);
        let cross_track_lateral_axis_world_unit =
            match self.profile.cross_track_frame_mode_id.as_deref() {
                None => state.task_frame.lateral_axis_world_unit,
                Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID) => {
                    command_heading_aligned_lateral_axis(
                        state.task_frame.forward_axis_world_unit,
                        state.task_frame.lateral_axis_world_unit,
                        requested_heading_error,
                    )
                }
                Some(unknown) => {
                    return Err(CoreError::Identity(format!(
                        "balanced_wave_cross_track_frame_mode:{unknown}"
                    )));
                }
            };
        let displacement = subtract(
            state.base_pose_world.position_m,
            state.task_frame.origin_world_m,
        );
        let cross_track_error_m = dot(displacement, cross_track_lateral_axis_world_unit);
        let cross_track_velocity_m_s = dot(
            state.base_twist_world.linear_velocity_m_s,
            cross_track_lateral_axis_world_unit,
        );
        let measured_yaw_error_rad = wrap_angle(
            state
                .base_pose_world
                .orientation_xyzw
                .heading_x_forward_z_right_rad()
                - state.task_frame.reference_yaw_rad,
        );
        let desired_heading_error_rad = (requested_heading_error
            - self.profile.cross_track_heading_gain_rad_per_m * cross_track_error_m
            - self.profile.cross_track_velocity_heading_gain_rad_per_m_s
                * cross_track_velocity_m_s)
            .clamp(
                -MAXIMUM_DESIRED_HEADING_ERROR_RAD,
                MAXIMUM_DESIRED_HEADING_ERROR_RAD,
            );
        let yaw_tracking_error_rad = wrap_angle(measured_yaw_error_rad - desired_heading_error_rad);
        let previous_steering_fraction = next_memory.held_path_steering_fraction;
        let mut steering_authority_guard = steering_authority_guard_receipt(&self.profile, state)?;
        apply_steering_floor_hold(
            &self.profile,
            memory,
            &mut next_memory,
            &mut steering_authority_guard,
        )?;
        let effective_maximum_steering_fraction = steering_authority_guard
            .as_ref()
            .map(|receipt| receipt.effective_maximum_steering_fraction)
            .unwrap_or(self.profile.maximum_steering_fraction);
        let unclamped_requested_steering_fraction =
            self.profile.yaw_error_stride_gain_per_rad * yaw_tracking_error_rad;
        let requested_steering_fraction = unclamped_requested_steering_fraction.clamp(
            -effective_maximum_steering_fraction,
            effective_maximum_steering_fraction,
        );
        let steering_saturated =
            requested_steering_fraction != unclamped_requested_steering_fraction;
        let steering_feedback_updated = state
            .semantic_step
            .is_multiple_of(self.profile.steering_feedback_update_interval_steps);
        let steering_filter_alpha_per_step = self
            .profile
            .steering_low_pass_time_constant_cycle_fraction
            .map(|time_constant_cycle_fraction| {
                let time_constant_steps = time_constant_cycle_fraction * CYCLE_STEPS as f64;
                1.0 - (-1.0 / time_constant_steps).exp()
            });
        let mut steering_slew_limited = false;
        if steering_feedback_updated {
            next_memory.held_path_steering_fraction =
                if let Some(alpha) = steering_filter_alpha_per_step {
                    (previous_steering_fraction
                        + alpha * (requested_steering_fraction - previous_steering_fraction))
                        .clamp(
                            -effective_maximum_steering_fraction,
                            effective_maximum_steering_fraction,
                        )
                } else if let Some(maximum_delta) =
                    self.profile.maximum_steering_fraction_delta_per_step
                {
                    let unbounded_delta = requested_steering_fraction - previous_steering_fraction;
                    let bounded_delta = unbounded_delta.clamp(-maximum_delta, maximum_delta);
                    steering_slew_limited = bounded_delta != unbounded_delta;
                    (previous_steering_fraction + bounded_delta).clamp(
                        -effective_maximum_steering_fraction,
                        effective_maximum_steering_fraction,
                    )
                } else {
                    requested_steering_fraction
                };
        }
        let applied_steering_delta =
            next_memory.held_path_steering_fraction - previous_steering_fraction;

        let forward_velocity_mode = self
            .profile
            .forward_velocity_foot_placement_mode_id
            .as_deref();
        let maximum_forward_velocity_hip_target_correction_rad = match (
            forward_velocity_mode,
            self.profile
                .maximum_forward_velocity_hip_target_correction_rad,
        ) {
            (None, None) => None,
            (Some(FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID), Some(maximum))
                if maximum.is_finite() && maximum > 0.0 =>
            {
                Some(maximum)
            }
            (Some(unknown), _) if unknown != FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID => {
                return Err(CoreError::Identity(format!(
                    "balanced_wave_forward_velocity_foot_placement_mode:{unknown}"
                )));
            }
            _ => {
                return Err(CoreError::Schema(
                    "balanced_wave_forward_velocity_foot_placement_parameters".to_owned(),
                ));
            }
        };
        let explicit_forward_velocity_error_orientation_id = self
            .profile
            .forward_velocity_error_orientation_id
            .as_deref();
        let forward_velocity_error_orientation_id = match (
            maximum_forward_velocity_hip_target_correction_rad,
            explicit_forward_velocity_error_orientation_id,
        ) {
            (None, None) => None,
            (Some(_), None) => Some(DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID),
            (
                Some(_),
                Some(
                    DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID
                    | MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
                ),
            ) => explicit_forward_velocity_error_orientation_id,
            (None, Some(_)) => {
                return Err(CoreError::Schema(
                    "balanced_wave_forward_velocity_orientation_without_mechanism".to_owned(),
                ));
            }
            (Some(_), Some(unknown)) => {
                return Err(CoreError::Identity(format!(
                    "balanced_wave_forward_velocity_error_orientation:{unknown}"
                )));
            }
        };
        let desired_forward_velocity_task_m_s = command.desired_planar_velocity_task_m_s.x;
        let measured_forward_velocity_task_m_s = dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.forward_axis_world_unit,
        );
        let desired_minus_measured_forward_velocity_error =
            if maximum_forward_velocity_hip_target_correction_rad.is_some()
                && desired_forward_velocity_task_m_s.abs() > 1.0e-12
            {
                ((desired_forward_velocity_task_m_s - measured_forward_velocity_task_m_s)
                    / desired_forward_velocity_task_m_s.abs())
                .clamp(-1.0, 1.0)
            } else {
                0.0
            };
        let normalized_forward_velocity_error = match forward_velocity_error_orientation_id {
            Some(MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID) => {
                -desired_minus_measured_forward_velocity_error
            }
            Some(DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID) | None => {
                desired_minus_measured_forward_velocity_error
            }
            Some(_) => unreachable!("validated forward-velocity error orientation"),
        };

        let joint_by_id = state
            .ordered_joint_observations
            .iter()
            .map(|observation| (observation.joint_id.as_str(), observation))
            .collect::<HashMap<_, _>>();
        let contact_by_limb = self.contact_by_limb(state)?;
        let gait_step_by_limb = next_memory
            .ordered_limb_memory
            .iter()
            .map(|limb| (limb.limb_id.as_str(), limb.gait_step))
            .collect::<HashMap<_, _>>();
        let phase_index_by_limb = ["rear_left", "front_left", "rear_right", "front_right"]
            .into_iter()
            .enumerate()
            .map(|(index, limb_id)| (limb_id, index as u64))
            .collect::<HashMap<_, _>>();
        let mut ordered_commands =
            Vec::with_capacity(self.compiled.morphology.morphology_spec.actuators.len());
        let mut ordered_knee_override_limb_ids = Vec::new();
        let mut ordered_hip_override_limb_ids = Vec::new();
        let mut ordered_forward_velocity_limb_corrections = Vec::new();
        for actuator in &self.compiled.morphology.morphology_spec.actuators {
            let joint = joint_by_id
                .get(actuator.joint_id.as_str())
                .ok_or_else(|| CoreError::Order(format!("joint:{}", actuator.joint_id)))?;
            let limb_id = limb_id_for_joint(&actuator.joint_id, self.error_prefix)?;
            let phase_index = *phase_index_by_limb
                .get(limb_id)
                .ok_or_else(|| CoreError::Order(format!("limb:{limb_id}")))?;
            let gait_step = *gait_step_by_limb
                .get(limb_id)
                .ok_or_else(|| CoreError::Order(format!("gait_limb:{limb_id}")))?;
            let local_phase_step =
                (gait_step + CYCLE_STEPS - phase_index * (CYCLE_STEPS / 4)) % CYCLE_STEPS;
            let foot_bears_support = *contact_by_limb
                .get(limb_id)
                .ok_or_else(|| CoreError::Contact(format!("limb:{limb_id}")))?;
            let (mut hip_target, mut knee_target) =
                gait_joint_targets(local_phase_step, command.gait_amplitude, KNEE_FLEXION_SCALE);
            let release_gate_loaded = local_phase_step == RELEASE_GATE_LOCAL_STEP
                && command.gait_amplitude > 0.0
                && foot_bears_support;
            if release_gate_loaded
                && self.profile.release_gate_hip_target_mode_id.as_deref()
                    == Some(RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID)
            {
                hip_target = command.gait_amplitude
                    * lerp(HIP_REAR_TARGET_RAD, HIP_FORWARD_TARGET_RAD, smoothstep(0.5));
                if actuator.joint_id.ends_with("_hip") {
                    ordered_hip_override_limb_ids.push(limb_id.to_owned());
                }
            }
            if hip_target != 0.0 {
                let lateral_side_sign = if limb_id.ends_with("_right") {
                    1.0
                } else {
                    -1.0
                };
                hip_target *= steering_stride_scale(
                    self.profile.steering_stride_transform_id.as_deref(),
                    lateral_side_sign,
                    next_memory.held_path_steering_fraction,
                )?;
            }
            if let Some(maximum_correction_rad) = maximum_forward_velocity_hip_target_correction_rad
            {
                let cycle_envelope = forward_velocity_foot_placement_envelope(local_phase_step);
                let applied_correction_rad = command.gait_amplitude
                    * maximum_correction_rad
                    * normalized_forward_velocity_error
                    * cycle_envelope;
                hip_target += applied_correction_rad;
                if actuator.joint_id.ends_with("_hip") {
                    ordered_forward_velocity_limb_corrections.push(
                        ForwardVelocityFootPlacementLimbReceipt {
                            limb_id: limb_id.to_owned(),
                            local_phase_step,
                            cycle_envelope,
                            applied_hip_target_correction_rad: applied_correction_rad,
                        },
                    );
                }
            }
            if local_phase_step < SWING_STEPS && command.gait_amplitude > 0.0 && foot_bears_support
            {
                knee_target += command.gait_amplitude * CONTACT_CLEARANCE_ASSIST_RAD;
            }
            if release_gate_loaded
                && self.profile.release_gate_knee_target_mode_id.as_deref()
                    == Some(RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID)
            {
                knee_target = command.gait_amplitude
                    * (KNEE_SWING_FLEXION_RAD * KNEE_FLEXION_SCALE + CONTACT_CLEARANCE_ASSIST_RAD);
                if actuator.joint_id.ends_with("_knee") {
                    ordered_knee_override_limb_ids.push(limb_id.to_owned());
                }
            }
            if matches!(self.policy_id, crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID
                | crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID
                | crate::recovery_support_progression::POLICY
                | crate::recovery_support_hold_posture::POLICY
                | crate::recovery_measured_support_transfer::POLICY
                | crate::recovery_measured_pose_support::POLICY
                | crate::recovery_anchored_body_pose::POLICY
                | crate::recovery_advancing_body_origin::POLICY
                | crate::recovery_remaining_support_release::POLICY
                | crate::recovery_anchored_body_pose::STARTUP_POLICY
                | crate::recovery_extended_preparation::POLICY
                | crate::recovery_initialized_zero_brake::POLICY
                | crate::recovery_zero_velocity_brake::POLICY
                | crate::recovery_bounded_stop_velocity::POLICY
                | crate::recovery_extended_support_transfer::POLICY
                | crate::recovery_joint_feasible_height::POLICY) {
                // V36 and V37: native contact still controls gates and motor limits,
                // but it no longer switches the raw knee-lift curve at liftoff.
                // Support geometry, composition and slew are applied below.
                knee_target = smooth_swing_knee_target(local_phase_step, command.gait_amplitude);
            }
            let requested_target_position_rad = if actuator.joint_id.ends_with("_hip") {
                hip_target
            } else if actuator.joint_id.ends_with("_knee") {
                knee_target
            } else {
                return Err(CoreError::Topology(format!(
                    "{}_joint_role:{}",
                    self.error_prefix, actuator.joint_id
                )));
            };
            let clamped_target_position_rad = requested_target_position_rad.clamp(
                actuator.minimum_target_position_rad,
                actuator.maximum_target_position_rad,
            );
            let measured_position = joint.position_rad.ok_or_else(|| {
                CoreError::Frame(format!("joint_position_missing:{}", joint.joint_id))
            })?;
            let measured_velocity = joint.velocity_rad_s.ok_or_else(|| {
                CoreError::Frame(format!("joint_velocity_missing:{}", joint.joint_id))
            })?;
            let anchor_error_m = joint.anchor_error_m.ok_or_else(|| {
                CoreError::Frame(format!("anchor_error_missing:{}", joint.joint_id))
            })?;
            let mut maximum_target_speed_rad_s = CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S;
            if actuator.joint_id.ends_with("_knee")
                && local_phase_step
                    >= u64::from(
                        self.profile
                            .contact_loaded_swing_knee_activation_start_phase_step,
                    )
                && local_phase_step < SWING_STEPS
                && foot_bears_support
            {
                maximum_target_speed_rad_s = maximum_target_speed_rad_s.min(
                    self.profile
                        .contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                );
            }
            let guard_activation_fraction = self.profile.anchor_error_guard_activation_fraction;
            let maximum_anchor_error_m =
                MAXIMUM_ANCHOR_ERROR_UPPER_LEG_FRACTION * self.compiled.geometry.upper_length_m;
            let guard_threshold_m = maximum_anchor_error_m * guard_activation_fraction;
            let guard_progress = ((anchor_error_m / maximum_anchor_error_m
                - guard_activation_fraction)
                / (1.0 - guard_activation_fraction))
                .clamp(0.0, 1.0);
            let guard_speed_limit = lerp(
                CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S,
                self.profile
                    .anchor_error_guard_maximum_motor_target_speed_rad_s,
                if self.profile.blend_anchor_guard_by_interaction_score {
                    guard_progress * self.compiled.morphology_interaction_score
                } else {
                    guard_progress
                },
            );
            let guard_active = actuator.joint_id.ends_with("_knee")
                && local_phase_step < SWING_STEPS
                && foot_bears_support
                && anchor_error_m > guard_threshold_m
                && guard_speed_limit < maximum_target_speed_rad_s;
            if guard_active {
                maximum_target_speed_rad_s = guard_speed_limit;
            }
            let raw_unsigned_velocity = MOTOR_POSITION_GAIN_PER_S
                * (requested_target_position_rad - measured_position)
                - MOTOR_RATE_DAMPING * measured_velocity;
            let base_unsigned_velocity = raw_unsigned_velocity.clamp(
                -CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S,
                CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S,
            );
            let final_unsigned_velocity = raw_unsigned_velocity
                .clamp(-maximum_target_speed_rad_s, maximum_target_speed_rad_s);
            let target_velocity_rad_s = final_unsigned_velocity * MOTOR_DIRECTION_SIGN;
            let base_velocity_rad_s = base_unsigned_velocity * MOTOR_DIRECTION_SIGN;
            ordered_commands.push(ActuatorCommand {
                actuator_id: actuator.actuator_id.clone(),
                mode: actuator.mode,
                requested_target_position_rad,
                clamped_target_position_rad,
                target_velocity_rad_s,
                maximum_target_speed_rad_s,
                position_saturated: requested_target_position_rad != clamped_target_position_rad,
                velocity_saturated: raw_unsigned_velocity.abs() > maximum_target_speed_rad_s,
                slew_limited: false,
                residual_contribution_rad_s: 0.0,
                safety_contribution_rad_s: target_velocity_rad_s - base_velocity_rad_s,
                valid_through_step: state.semantic_step,
            });
        }

        next_memory.last_semantic_step = Some(state.semantic_step);
        let release_gate_unweighting =
            self.profile
                .release_gate_unweighting_receipt_enabled
                .then(|| ReleaseGateUnweightingReceipt {
                    schema_version: "sporespore_release_gate_unweighting_receipt_v1".to_owned(),
                    knee_target_mode_id: self.profile.release_gate_knee_target_mode_id.clone(),
                    hip_target_mode_id: self.profile.release_gate_hip_target_mode_id.clone(),
                    ordered_knee_override_limb_ids,
                    ordered_hip_override_limb_ids,
                    analytic_target_basis: "existing_lateral_wave_swing_apex_at_half_swing_v1"
                        .to_owned(),
                    morphology_branch_surface_count: 0,
                    controller_parameter: true,
                    walking_claim_authorized: false,
                    physical_acceptance_authority: false,
                });
        let forward_velocity_foot_placement = maximum_forward_velocity_hip_target_correction_rad
            .map(|maximum| ForwardVelocityFootPlacementReceipt {
                schema_version: if explicit_forward_velocity_error_orientation_id.is_some() {
                    "sporespore_forward_velocity_foot_placement_receipt_v2".to_owned()
                } else {
                    "sporespore_forward_velocity_foot_placement_receipt_v1".to_owned()
                },
                mode_id: FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID.to_owned(),
                velocity_error_orientation_id: explicit_forward_velocity_error_orientation_id
                    .map(str::to_owned),
                desired_forward_velocity_task_m_s,
                measured_forward_velocity_task_m_s,
                normalized_forward_velocity_error,
                maximum_hip_target_correction_rad: maximum,
                ordered_limb_corrections: ordered_forward_velocity_limb_corrections,
                morphology_branch_surface_count: 0,
                controller_parameter: true,
                walking_claim_authorized: false,
                physical_acceptance_authority: false,
            });
        let receipt = ControllerStepReceipt {
            schema_version: if steering_authority_guard.as_ref().is_some_and(|guard| {
                guard.schema_version == "sporespore_steering_authority_guard_receipt_v3"
            }) {
                "sporespore_controller_step_receipt_v8".to_owned()
            } else if steering_authority_guard.as_ref().is_some_and(|guard| {
                guard.schema_version == "sporespore_steering_authority_guard_receipt_v2"
            }) {
                "sporespore_controller_step_receipt_v7".to_owned()
            } else if steering_authority_guard.is_some() {
                "sporespore_controller_step_receipt_v6".to_owned()
            } else if explicit_forward_velocity_error_orientation_id.is_some() {
                "sporespore_controller_step_receipt_v5".to_owned()
            } else if forward_velocity_foot_placement.is_some() {
                "sporespore_controller_step_receipt_v4".to_owned()
            } else if release_gate_unweighting.is_some() {
                "sporespore_controller_step_receipt_v3".to_owned()
            } else {
                "sporespore_controller_step_receipt_v2".to_owned()
            },
            policy_id: self.policy_id.to_owned(),
            semantic_step: state.semantic_step,
            command_id: command.command_id.clone(),
            morphology_spec_sha256: self.compiled.morphology.morphology_spec_sha256.clone(),
            adapter_capability_sha256: state.adapter_capability_sha256.clone(),
            steering_feedback_updated,
            requested_steering_fraction,
            previous_steering_fraction,
            held_steering_fraction: next_memory.held_path_steering_fraction,
            applied_steering_delta,
            steering_saturated,
            steering_slew_limited,
            steering_filter_alpha_per_step,
            steering_filter_time_constant_cycle_fraction: self
                .profile
                .steering_low_pass_time_constant_cycle_fraction,
            cross_track_error_m,
            cross_track_velocity_m_s,
            measured_yaw_error_rad,
            desired_heading_error_rad,
            yaw_tracking_error_rad,
            steering_authority_guard,
            release_gate_unweighting,
            forward_velocity_foot_placement,
            recovery_support_plane: None,
            controller_error: None,
            world_build_count: 0,
            physical_acceptance_authority: false,
        };
        let receipt_sha256 = digest_serializable(&receipt)?;
        let actuation = ActuationFrame {
            schema_version: ACTUATION_FRAME_VERSION.to_owned(),
            semantic_step: state.semantic_step,
            ordered_commands,
            safe_no_actuation: false,
            failure_codes: vec![],
            receipt,
            receipt_sha256,
            world_build_count: 0,
            physical_acceptance_authority: false,
        };
        actuation.validate(&self.compiled.morphology)?;
        Ok(ControllerStepOutput {
            schema_version: self.runtime_version.to_owned(),
            actuation,
            next_memory,
        })
    }

    fn validate_memory(
        &self,
        memory: &Candidate35ControllerMemory,
        semantic_step: u64,
    ) -> Result<()> {
        if memory.schema_version != self.memory_version {
            return Err(CoreError::Schema(format!(
                "{}_memory_version",
                self.error_prefix
            )));
        }
        if !memory.held_path_steering_fraction.is_finite()
            || memory.held_path_steering_fraction.abs() > MAXIMUM_STEERING_FRACTION
        {
            return Err(CoreError::Frame("held_path_steering_fraction".to_owned()));
        }
        match (
            self.profile.steering_guard_floor_hold_steps,
            memory.steering_guard_floor_hold_steps_remaining,
        ) {
            (None, None) => {}
            (Some(duration), Some(remaining)) if remaining <= duration => {}
            _ => {
                return Err(CoreError::Schema(
                    "balanced_wave_steering_floor_hold_memory".to_owned(),
                ));
            }
        }
        let expected = ["rear_left", "front_left", "rear_right", "front_right"];
        if memory.ordered_limb_memory.len() != expected.len()
            || memory
                .ordered_limb_memory
                .iter()
                .zip(expected)
                .any(|(actual, expected_id)| actual.limb_id != expected_id)
        {
            return Err(CoreError::Order(format!(
                "{}_limb_memory",
                self.error_prefix
            )));
        }
        if memory.ordered_limb_memory.iter().any(|limb| {
            limb.evidence_gait_step_limit
                .is_some_and(|limit| limit < limb.gait_step)
        }) {
            return Err(CoreError::Time(format!(
                "{}_evidence_gait_step_limit",
                self.error_prefix
            )));
        }
        if let Some(last) = memory.last_semantic_step
            && semantic_step != last + 1
        {
            return Err(CoreError::Time(format!(
                "{}_step_sequence:{last}->{semantic_step}",
                self.error_prefix
            )));
        }
        Ok(())
    }

    fn require_dynamic_observations(&self, state: &StateFrame) -> Result<()> {
        for joint in &state.ordered_joint_observations {
            if !joint.validity.position || !joint.validity.velocity || !joint.validity.anchor_error
            {
                return Err(CoreError::Capability(format!(
                    "{}_joint_observation:{}",
                    self.error_prefix, joint.joint_id
                )));
            }
        }
        for contact in &state.ordered_contact_observations {
            if !matches!(
                contact.provenance.quality,
                ContactQuality::QualifiedBearing | ContactQuality::QualifiedLoad
            ) || contact.bears_support.is_none()
            {
                return Err(CoreError::Capability(format!(
                    "{}_contact_bearing:{}",
                    self.error_prefix, contact.contact_site_id
                )));
            }
        }
        Ok(())
    }

    fn contact_by_limb<'a>(&self, state: &'a StateFrame) -> Result<HashMap<&'a str, bool>> {
        state
            .ordered_contact_observations
            .iter()
            .map(|observation| {
                let limb_id = observation
                    .contact_site_id
                    .strip_suffix("_foot")
                    .ok_or_else(|| {
                        CoreError::Topology(format!(
                            "{}_contact_role:{}",
                            self.error_prefix, observation.contact_site_id
                        ))
                    })?;
                Ok((
                    limb_id,
                    observation.bears_support.ok_or_else(|| {
                        CoreError::Contact(format!(
                            "bearing_missing:{}",
                            observation.contact_site_id
                        ))
                    })?,
                ))
            })
            .collect()
    }

    fn prospective_phase_memory(&self, memory: &Candidate35ControllerMemory,
        state: &StateFrame, command: &MotionCommand) -> Result<Candidate35ControllerMemory> {
        let mut next = memory.clone();
        if memory.last_semantic_step.is_some() {
            match (memory.phase_progression_mode, command.phase_progression_mode) {
                (Some(PhaseProgressionMode::ContactGated), PhaseProgressionMode::Clocked)
                | (Some(PhaseProgressionMode::ContactGated), PhaseProgressionMode::ContactGated) =>
                    self.advance_contact_gated_memory(&mut next,state)?,
                _ => self.advance_clocked_memory(&mut next)?,
            }
        }
        if matches!((memory.phase_progression_mode,command.phase_progression_mode),
            (Some(PhaseProgressionMode::ContactGated),PhaseProgressionMode::Clocked)) {
            for limb in &mut next.ordered_limb_memory {limb.evidence_gait_step_limit=None;}
        }
        next.phase_progression_mode=Some(command.phase_progression_mode);
        Ok(next)
    }

    fn advance_contact_gated_memory(
        &self,
        memory: &mut Candidate35ControllerMemory,
        state: &StateFrame,
    ) -> Result<()> {
        let contacts = self.contact_by_limb(state)?;
        let minimum_gait_step = memory
            .ordered_limb_memory
            .iter()
            .map(|limb| limb.gait_step)
            .min()
            .ok_or_else(|| CoreError::Internal("empty_limb_memory".to_owned()))?;
        for (phase_index, limb) in memory.ordered_limb_memory.iter_mut().enumerate() {
            if limb
                .evidence_gait_step_limit
                .is_some_and(|limit| limb.gait_step >= limit)
            {
                continue;
            }
            let phase_offset = phase_index as u64 * (CYCLE_STEPS / 4);
            let local_phase_step = (limb.gait_step + CYCLE_STEPS - phase_offset) % CYCLE_STEPS;
            let bearing = *contacts
                .get(limb.limb_id.as_str())
                .ok_or_else(|| CoreError::Contact(format!("limb:{}", limb.limb_id)))?;
            let gate = if local_phase_step == RELEASE_GATE_LOCAL_STEP {
                Some((!bearing, true))
            } else if local_phase_step == self.profile.recontact_gate_local_step {
                Some((bearing, false))
            } else {
                None
            };
            if let Some((satisfied, release_gate)) = gate {
                if satisfied {
                    limb.current_gate_transition_dwell_steps += 1;
                } else {
                    limb.current_gate_transition_dwell_steps = 0;
                }
                let hold = !satisfied
                    || limb.current_gate_transition_dwell_steps < MINIMUM_GATE_DWELL_STEPS;
                if hold && limb.current_gate_hold_steps < MAXIMUM_GATE_HOLD_STEPS {
                    limb.current_gate_hold_steps += 1;
                    if release_gate {
                        limb.release_hold_step_count += 1;
                    } else {
                        limb.recontact_hold_step_count += 1;
                    }
                    continue;
                }
                if hold {
                    limb.gate_timeout_count += 1;
                }
            } else {
                limb.current_gate_transition_dwell_steps = 0;
            }
            let phase_lead = limb.gait_step - minimum_gait_step;
            if phase_lead >= MAXIMUM_PHASE_SKEW_STEPS {
                limb.phase_sync_hold_step_count += 1;
            } else {
                limb.gait_step += 1;
            }
            limb.current_gate_hold_steps = 0;
            limb.current_gate_transition_dwell_steps = 0;
        }
        Ok(())
    }

    fn advance_clocked_memory(&self, memory: &mut Candidate35ControllerMemory) -> Result<()> {
        for limb in &mut memory.ordered_limb_memory {
            if limb
                .evidence_gait_step_limit
                .is_some_and(|limit| limb.gait_step >= limit)
            {
                continue;
            }
            limb.gait_step = limb.gait_step.checked_add(1).ok_or_else(|| {
                CoreError::Time(format!("{}_gait_step_overflow", self.error_prefix))
            })?;
            limb.current_gate_hold_steps = 0;
            limb.current_gate_transition_dwell_steps = 0;
        }
        Ok(())
    }

    fn safe_output(
        &self,
        memory: &Candidate35ControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
        error: CoreError,
    ) -> ControllerStepOutput {
        let error_text = error.to_string();
        let failure_code = error_text
            .split_once(':')
            .map_or(error_text.as_str(), |(code, _)| code)
            .to_owned();
        let observation_by_joint = state
            .ordered_joint_observations
            .iter()
            .map(|observation| (observation.joint_id.as_str(), observation))
            .collect::<HashMap<_, _>>();
        let ordered_commands = self
            .compiled
            .morphology
            .morphology_spec
            .actuators
            .iter()
            .map(|actuator| {
                let requested = observation_by_joint
                    .get(actuator.joint_id.as_str())
                    .and_then(|observation| observation.position_rad)
                    .filter(|value| value.is_finite())
                    .unwrap_or(0.0);
                ActuatorCommand {
                    actuator_id: actuator.actuator_id.clone(),
                    mode: actuator.mode,
                    requested_target_position_rad: requested,
                    clamped_target_position_rad: requested.clamp(
                        actuator.minimum_target_position_rad,
                        actuator.maximum_target_position_rad,
                    ),
                    target_velocity_rad_s: 0.0,
                    maximum_target_speed_rad_s: actuator.maximum_target_speed_rad_s,
                    position_saturated: requested < actuator.minimum_target_position_rad
                        || requested > actuator.maximum_target_position_rad,
                    velocity_saturated: false,
                    slew_limited: false,
                    residual_contribution_rad_s: 0.0,
                    safety_contribution_rad_s: 0.0,
                    valid_through_step: state.semantic_step,
                }
            })
            .collect();
        let receipt = ControllerStepReceipt {
            schema_version: "sporespore_controller_step_receipt_v2".to_owned(),
            policy_id: self.policy_id.to_owned(),
            semantic_step: state.semantic_step,
            command_id: command.command_id.clone(),
            morphology_spec_sha256: self.compiled.morphology.morphology_spec_sha256.clone(),
            adapter_capability_sha256: state.adapter_capability_sha256.clone(),
            steering_feedback_updated: false,
            requested_steering_fraction: 0.0,
            previous_steering_fraction: 0.0,
            held_steering_fraction: 0.0,
            applied_steering_delta: 0.0,
            steering_saturated: false,
            steering_slew_limited: false,
            steering_filter_alpha_per_step: None,
            steering_filter_time_constant_cycle_fraction: None,
            cross_track_error_m: 0.0,
            cross_track_velocity_m_s: 0.0,
            measured_yaw_error_rad: 0.0,
            desired_heading_error_rad: 0.0,
            yaw_tracking_error_rad: 0.0,
            steering_authority_guard: None,
            release_gate_unweighting: None,
            forward_velocity_foot_placement: None,
            recovery_support_plane: None,
            controller_error: Some(error_text),
            world_build_count: 0,
            physical_acceptance_authority: false,
        };
        let receipt_sha256 = digest_serializable(&receipt).unwrap_or_else(|_| {
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_owned()
        });
        ControllerStepOutput {
            schema_version: self.runtime_version.to_owned(),
            actuation: ActuationFrame {
                schema_version: ACTUATION_FRAME_VERSION.to_owned(),
                semantic_step: state.semantic_step,
                ordered_commands,
                safe_no_actuation: true,
                failure_codes: vec![failure_code],
                receipt,
                receipt_sha256,
                world_build_count: 0,
                physical_acceptance_authority: false,
            },
            next_memory: memory.clone(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Candidate35Controller {
    engine: WaveControllerEngine,
}

impl Candidate35Controller {
    pub fn new(compiled: CompiledQuadruped) -> Result<Self> {
        Ok(Self {
            engine: WaveControllerEngine::candidate35(compiled)?,
        })
    }

    pub fn compiled(&self) -> &CompiledQuadruped {
        &self.engine.compiled
    }

    pub fn step(
        &self,
        memory: &Candidate35ControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
    ) -> ControllerStepOutput {
        self.engine.step(memory, state, command)
    }
}

#[derive(Debug, Clone)]
pub struct BalancedWaveController {
    engine: WaveControllerEngine,
    profile: BalancedWaveProfile,
}

impl BalancedWaveController {
    pub fn new(compiled: CompiledQuadruped) -> Result<Self> {
        Self::new_for_policy(compiled, BALANCED_WAVE_POLICY_ID)
    }

    pub fn new_for_policy(compiled: CompiledQuadruped, policy_id: &str) -> Result<Self> {
        let (engine, profile) = WaveControllerEngine::balanced_wave(compiled, policy_id)?;
        Ok(Self { engine, profile })
    }

    pub fn compiled(&self) -> &CompiledQuadruped {
        &self.engine.compiled
    }

    pub fn profile(&self) -> &BalancedWaveProfile {
        &self.profile
    }

    pub fn initial_memory(&self) -> BalancedWaveControllerMemory {
        let mut memory =
            Candidate35ControllerMemory::initial_with_version(self.engine.memory_version);
        if self.profile.steering_guard_floor_hold_steps.is_some() {
            memory.steering_guard_floor_hold_steps_remaining = Some(0);
        }
        let mut memory = BalancedWaveControllerMemory::from_internal(memory);
        if self.profile.stance_support_mode_id.is_some() {
            memory.support_reference = Some(crate::recovery_support_plane::SupportReferenceMemory::initial());
            if matches!(self.profile.policy_id.as_str(), crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID
                | crate::recovery_support_progression::POLICY
                | crate::recovery_support_hold_posture::POLICY
                | crate::recovery_measured_support_transfer::POLICY) {
                memory.support_reference.as_mut().expect("initialized reference").ordered_stance_latches =
                    Some(crate::recovery_support_plane::initial_stance_latches());
            }
        }
        if matches!(self.profile.policy_id.as_str(), crate::recovery_support_progression::POLICY
            | crate::recovery_support_hold_posture::POLICY
                | crate::recovery_measured_support_transfer::POLICY
                | crate::recovery_measured_pose_support::POLICY
                | crate::recovery_anchored_body_pose::POLICY
                | crate::recovery_advancing_body_origin::POLICY
                | crate::recovery_remaining_support_release::POLICY
                | crate::recovery_anchored_body_pose::STARTUP_POLICY
                | crate::recovery_extended_preparation::POLICY
                | crate::recovery_initialized_zero_brake::POLICY
                | crate::recovery_zero_velocity_brake::POLICY
                | crate::recovery_bounded_stop_velocity::POLICY
                | crate::recovery_extended_support_transfer::POLICY
                | crate::recovery_joint_feasible_height::POLICY) {
            memory.support_progression=Some(crate::recovery_support_progression::Memory::default());
        }
        if self.profile.measured_support_transfer_mode_id.is_some() {
            memory.measured_support_transfer=Some(crate::recovery_measured_support_transfer::Memory::default());
        }
        memory
    }

    pub fn step(
        &self,
        memory: &BalancedWaveControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
    ) -> BalancedWaveControllerStepOutput {
        self.step_with_floor(memory, state, command, None)
    }

    pub fn step_with_floor(
        &self,
        memory: &BalancedWaveControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
        floor: Option<&crate::recovery_floor_reference::FloorReference>,
    ) -> BalancedWaveControllerStepOutput {
        self.step_with_measured_body(memory, state, command, floor, None)
    }

    pub fn step_with_measured_body(
        &self,
        memory: &BalancedWaveControllerMemory,
        state: &StateFrame,
        command: &MotionCommand,
        floor: Option<&crate::recovery_floor_reference::FloorReference>,
        body_frame: Option<&crate::recovery_measured_support_transfer::MeasuredBodyFrame>,
    ) -> BalancedWaveControllerStepOutput {
        let selected = self.profile.stance_support_mode_id.is_some();
        let feasible_selected = matches!(self.profile.policy_id.as_str(),
            crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID
            | crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID
            | crate::recovery_support_progression::POLICY
            | crate::recovery_support_hold_posture::POLICY
                | crate::recovery_measured_support_transfer::POLICY
                | crate::recovery_measured_pose_support::POLICY
                | crate::recovery_anchored_body_pose::POLICY
                | crate::recovery_advancing_body_origin::POLICY
                | crate::recovery_remaining_support_release::POLICY
                | crate::recovery_anchored_body_pose::STARTUP_POLICY
                | crate::recovery_extended_preparation::POLICY
                | crate::recovery_initialized_zero_brake::POLICY
                | crate::recovery_zero_velocity_brake::POLICY
                | crate::recovery_bounded_stop_velocity::POLICY
                | crate::recovery_extended_support_transfer::POLICY
                | crate::recovery_joint_feasible_height::POLICY);
        let floor_selected = feasible_selected || self.profile.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID;
        let refuse = |error| {
            let output = self.engine.safe_output(&memory.as_internal(), state, command, error);
            BalancedWaveControllerStepOutput {
                schema_version: output.schema_version,
                actuation: output.actuation,
                next_memory: memory.clone(),
            }
        };
        let pose_entry = self.profile.policy_id == crate::joint_pose_entry::POLICY;
        if (!pose_entry && memory.joint_pose_entry.is_some())
            || (pose_entry && memory.joint_pose_entry.is_none() != memory.last_semantic_step.is_none()) {
            return refuse(CoreError::Schema("joint_pose_entry_memory_selection".to_owned()));
        }
        let floor_hash = match crate::recovery_floor_reference::validate_context(floor_selected, memory, floor) {
            Ok(hash) => hash,
            Err(error) => return refuse(error),
        };
        if let Err(error) = crate::recovery_support_plane::validate_memory(
            selected, self.engine.memory_version, memory, state, &self.engine.compiled,
        ) {
            return refuse(error);
        }
        let extended_preparation = self.profile.policy_id == crate::recovery_extended_preparation::POLICY;
        let initialized_brake = extended_preparation || self.profile.policy_id == crate::recovery_initialized_zero_brake::POLICY;
        let zero_brake = self.profile.policy_id == crate::recovery_zero_velocity_brake::POLICY;
        let bounded_stop = self.profile.policy_id == crate::recovery_bounded_stop_velocity::POLICY;
        let extended_transfer = initialized_brake || zero_brake || bounded_stop || self.profile.policy_id == crate::recovery_extended_support_transfer::POLICY;
        let reference_range = if extended_transfer {crate::recovery_extended_support_transfer::ReferenceRange::Extended}
            else {crate::recovery_extended_support_transfer::ReferenceRange::Original};
        let joint_feasible_height = extended_transfer || self.profile.policy_id == crate::recovery_joint_feasible_height::POLICY;
        let startup_ramped = joint_feasible_height || self.profile.policy_id == crate::recovery_anchored_body_pose::STARTUP_POLICY;
        let remaining_support = startup_ramped || self.profile.policy_id == crate::recovery_remaining_support_release::POLICY;
        let advancing = remaining_support || self.profile.policy_id == crate::recovery_advancing_body_origin::POLICY;
        let anchored = advancing || self.profile.policy_id == crate::recovery_anchored_body_pose::POLICY;
        if anchored {
            if let Err(error)=crate::recovery_anchored_body_pose::validate(memory.anchored_body_pose.as_ref(),memory.last_semantic_step.is_none(),
                memory.support_reference.as_ref().and_then(|r|r.previous_sample_time_s),floor.expect("validated floor"),self.engine.compiled.geometry.foot_radius_m,joint_feasible_height) {return refuse(error);}
        } else if memory.anchored_body_pose.is_some() {return refuse(CoreError::Schema("anchored_body_pose_crossed_policy".to_owned()));}
        let measured = if self.profile.measured_support_transfer_mode_id.is_some() {
            let Some(frame) = body_frame else {
                return refuse(CoreError::Frame("measured_support_transfer_body_frame_missing".to_owned()));
            };
            let Some(transfer_memory) = &memory.measured_support_transfer else {
                return refuse(CoreError::Schema("measured_support_transfer_memory_missing".to_owned()));
            };
            let validity=if extended_preparation {transfer_memory.validate_range_and_preparation(memory.last_semantic_step.is_none(),reference_range,crate::recovery_extended_preparation::PreparationBudget::Extended)}
                else if extended_transfer {transfer_memory.validate_range(memory.last_semantic_step.is_none(),reference_range)}
                else {transfer_memory.validate(memory.last_semantic_step.is_none())};
            if let Err(error) = validity { return refuse(error); }
            match crate::recovery_measured_support_transfer::measure(&self.engine.compiled, state, frame) {
                Ok(value) => Some(value), Err(error) => return refuse(error),
            }
        } else {
            if body_frame.is_some() || memory.measured_support_transfer.is_some() {
                return refuse(CoreError::Schema("measured_support_transfer_crossed_policy".to_owned()));
            }
            None
        };
        let internal=memory.as_internal();
        let mut transfer = None;
        let progression = if matches!(self.profile.policy_id.as_str(), crate::recovery_support_progression::POLICY
            | crate::recovery_support_hold_posture::POLICY | crate::recovery_measured_support_transfer::POLICY
                | crate::recovery_measured_pose_support::POLICY
                | crate::recovery_anchored_body_pose::POLICY
                | crate::recovery_advancing_body_origin::POLICY
                | crate::recovery_remaining_support_release::POLICY
                | crate::recovery_anchored_body_pose::STARTUP_POLICY
                | crate::recovery_extended_preparation::POLICY
                | crate::recovery_initialized_zero_brake::POLICY
                | crate::recovery_zero_velocity_brake::POLICY
                | crate::recovery_bounded_stop_velocity::POLICY
                | crate::recovery_extended_support_transfer::POLICY
                | crate::recovery_joint_feasible_height::POLICY) {
            let Some(guard) = &memory.support_progression else {
                return refuse(CoreError::Schema("support_progression_memory_missing".to_owned()));
            };
            let checked = self.engine.validate_memory(&internal,state.semantic_step)
                .and_then(|_|state.validate(&self.engine.compiled.morphology))
                .and_then(|_|command.validate_for_step(state.semantic_step))
                .and_then(|_|self.engine.require_dynamic_observations(state))
                .and_then(|_|self.engine.prospective_phase_memory(&internal,state,command));
            let proposed = match checked {Ok(value)=>value,Err(error)=>return refuse(error)};
            let receipt = match crate::recovery_support_progression::decide(guard,&internal,&proposed,
                state,command.gait_amplitude!=0.0) {Ok(value)=>value,Err(error)=>return refuse(error)};
            if let Some(measured) = measured {
                let dt = memory.support_reference.as_ref().and_then(|r|r.previous_sample_time_s)
                    .map_or(0.0, |previous|state.sample_time_s-previous);
                let g=&self.engine.compiled.geometry;
                let decide=if extended_preparation {crate::recovery_measured_support_transfer::decide_extended_preparation}
                    else if extended_transfer {crate::recovery_measured_support_transfer::decide_extended_remaining_support}
                    else if remaining_support {crate::recovery_measured_support_transfer::decide_remaining_support}
                    else {crate::recovery_measured_support_transfer::decide};
                transfer = match decide(
                    memory.measured_support_transfer.as_ref().expect("validated transfer memory"),
                    &internal,&proposed,state,measured,command.gait_amplitude!=0.0,dt,
                    g.upper_length_m+g.lower_length_m,receipt.clone()) {
                    Ok(value)=>Some(value),Err(error)=>return refuse(error),
                };
            }
            Some(receipt)
        } else {
            if memory.support_progression.is_some() {
                return refuse(CoreError::Schema("support_progression_memory_crossed_policy".to_owned()));
            }
            None
        };
        let output = if let Some(receipt) = &progression {
            match self.engine.try_step(&internal,state,command,transfer.as_ref().map_or(receipt.phase_progression_held,
                |r|r.effective_phase_progression_held)) {
                Ok(output)=>output,Err(error)=>return refuse(error),
            }
        } else {self.engine.step(&internal,state,command)};
        let mut result = BalancedWaveControllerStepOutput {
            schema_version: output.schema_version,
            actuation: output.actuation,
            next_memory: BalancedWaveControllerMemory::from_internal(output.next_memory),
        };
        if result.actuation.safe_no_actuation {
            result.next_memory = memory.clone();
            return result;
        }
        if pose_entry {
            match crate::joint_pose_entry::apply(memory.joint_pose_entry.as_ref(), state, command,
                &self.engine.compiled, &mut result.actuation, MOTOR_POSITION_GAIN_PER_S, MOTOR_RATE_DAMPING, MOTOR_DIRECTION_SIGN) {
                Ok(next) => result.next_memory.joint_pose_entry = Some(next),
                Err(error) => return refuse(error),
            }
        }
        if anchored {
            match crate::recovery_anchored_body_pose::apply(memory.anchored_body_pose.as_ref(),memory.support_reference.as_ref().expect("validated support memory"),
                state,command,&self.engine.compiled,floor.expect("validated floor"),transfer.as_ref().expect("selected transfer"),&mut result.actuation,
                CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S,MOTOR_POSITION_GAIN_PER_S,MOTOR_RATE_DAMPING,MOTOR_DIRECTION_SIGN,startup_ramped,joint_feasible_height) {
                Ok((pose,reference))=>{result.next_memory.anchored_body_pose=Some(pose);result.next_memory.support_reference=Some(reference);},
                Err(error)=>return refuse(error),
            }
        } else if selected {
            // Same post-gate phases that generated this command. At swing end
            // (including its hold), keep the landing leg referenced to the actual
            // floor. Only legs already in scheduled stance receive the crouch.
            let phases = if feasible_selected {
                let order = ["rear_left","front_left","rear_right","front_right"];
                Some(["front_left","front_right","rear_left","rear_right"].map(|id| {
                    let index=order.iter().position(|limb|*limb==id).expect("fixed limb role") as u64;
                    let clock=result.next_memory.ordered_limb_memory.iter().find(|m|m.limb_id==id).expect("validated limb memory").gait_step;
                    (clock+CYCLE_STEPS-index*(CYCLE_STEPS/4))%CYCLE_STEPS
                }))
            } else { None };
            match crate::recovery_support_plane::apply(
                memory.support_reference.as_ref().expect("validated support memory"),
                state, command, &self.engine.compiled, &mut result.actuation,
                CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S, MOTOR_POSITION_GAIN_PER_S,
                MOTOR_RATE_DAMPING, MOTOR_DIRECTION_SIGN,
                floor,
                phases.as_ref(),
                self.profile.support_hold_posture_mode_id.is_some()
                    && transfer.as_ref().map_or(progression.as_ref().is_some_and(|r|r.phase_progression_held),
                        |r|r.effective_phase_progression_held),
                transfer.as_ref().map(|r|r.next_memory.hip_bias_rad),
            ) {
                Ok(reference) => result.next_memory.support_reference = Some(reference),
                Err(error) => return refuse(error),
            }
        }
        result.next_memory.floor_reference_sha256 = floor_hash;
        if let Some(receipt) = progression {
            result.next_memory.support_progression=Some(receipt.next_memory.clone());
            if let Some(transfer) = transfer {
                result.next_memory.measured_support_transfer=Some(transfer.next_memory.clone());
                result.actuation.receipt.schema_version=if anchored {
                    crate::recovery_anchored_body_pose::RECEIPT
                } else if self.profile.policy_id == crate::recovery_measured_pose_support::POLICY {
                    crate::recovery_measured_pose_support::RECEIPT
                } else {crate::recovery_measured_support_transfer::RECEIPT}.to_owned();
                result.actuation.receipt.recovery_support_plane.as_mut().expect("selected support layer")
                    .measured_support_transfer=Some(transfer);
            } else {
                result.actuation.receipt.schema_version=if self.profile.policy_id == crate::recovery_support_hold_posture::POLICY {
                    crate::recovery_support_hold_posture::RECEIPT
                } else { crate::recovery_support_progression::RECEIPT }.to_owned();
                result.actuation.receipt.recovery_support_plane.as_mut().expect("selected support layer")
                    .support_progression=Some(receipt);
            }
            result.actuation.receipt_sha256=match digest_serializable(&result.actuation.receipt) {
                Ok(hash)=>hash,Err(error)=>return refuse(error),
            };
        }
        if advancing {
            let pose=result.next_memory.anchored_body_pose.as_mut().expect("selected body pose");
            let transfer=result.next_memory.measured_support_transfer.as_mut().expect("selected transfer");
            let g=&self.engine.compiled.geometry;
            let recenter=if extended_transfer {crate::recovery_advancing_body_origin::rebase_extended}
                else {crate::recovery_advancing_body_origin::rebase};
            let rebase=match recenter(memory.anchored_body_pose.as_ref(),pose,transfer,g.upper_length_m+g.lower_length_m) {
                Ok(value)=>value,Err(error)=>return refuse(error),
            };
            let receipt=result.actuation.receipt.recovery_support_plane.as_mut().expect("selected support").anchored_body_pose.as_mut().expect("selected body receipt");
            receipt.next_memory=pose.clone();receipt.origin_rebase=rebase;
            result.actuation.receipt.schema_version=if extended_preparation {crate::recovery_extended_preparation::RECEIPT}
                else if initialized_brake {crate::recovery_initialized_zero_brake::RECEIPT}
                else if zero_brake {crate::recovery_zero_velocity_brake::RECEIPT}
                else if bounded_stop {crate::recovery_bounded_stop_velocity::RECEIPT}
                else if extended_transfer {crate::recovery_extended_support_transfer::RECEIPT}
                else if joint_feasible_height {crate::recovery_joint_feasible_height::RECEIPT}
                else if startup_ramped {crate::recovery_anchored_body_pose::STARTUP_RECEIPT}
                else if remaining_support {crate::recovery_remaining_support_release::RECEIPT}
                else {crate::recovery_advancing_body_origin::RECEIPT}.to_owned();
            result.actuation.receipt_sha256=match digest_serializable(&result.actuation.receipt) {Ok(hash)=>hash,Err(error)=>return refuse(error)};
        }
        if initialized_brake && command.gait_amplitude == 0.0 {
            if let Err(error) = crate::recovery_initialized_zero_brake::apply(
                &mut result.actuation, &self.engine.compiled, memory.last_semantic_step.is_some()) {
                return refuse(error);
            }
        }
        if zero_brake && command.gait_amplitude == 0.0 {
            if let Err(error) = crate::recovery_zero_velocity_brake::apply(&mut result.actuation, &self.engine.compiled) {
                return refuse(error);
            }
        }
        if bounded_stop && command.gait_amplitude == 0.0 {
            if let Err(error) = crate::recovery_bounded_stop_velocity::apply(&mut result.actuation, &self.engine.compiled) {
                return refuse(error);
            }
        }
        result
    }
}

fn limb_id_for_joint<'a>(joint_id: &'a str, error_prefix: &str) -> Result<&'a str> {
    joint_id
        .strip_suffix("_hip")
        .or_else(|| joint_id.strip_suffix("_knee"))
        .ok_or_else(|| CoreError::Topology(format!("{error_prefix}_joint_id:{joint_id}")))
}

fn smooth_swing_knee_target(local_phase_step: u64, amplitude: f64) -> f64 {
    if local_phase_step >= SWING_STEPS {
        return 0.0; // Exact landing/stance endpoint, not sin(pi)'s rounding residue.
    }
    let peak = KNEE_SWING_FLEXION_RAD * KNEE_FLEXION_SCALE + CONTACT_CLEARANCE_ASSIST_RAD;
    amplitude * peak * (std::f64::consts::PI * local_phase_step as f64 / SWING_STEPS as f64).sin()
}

fn gait_joint_targets(local_phase_step: u64, amplitude: f64, knee_scale: f64) -> (f64, f64) {
    if local_phase_step < SWING_STEPS {
        let swing_fraction = local_phase_step as f64 / SWING_STEPS as f64;
        let hip = lerp(
            HIP_REAR_TARGET_RAD,
            HIP_FORWARD_TARGET_RAD,
            smoothstep(swing_fraction),
        );
        let knee =
            KNEE_SWING_FLEXION_RAD * knee_scale * (std::f64::consts::PI * swing_fraction).sin();
        (amplitude * hip, amplitude * knee)
    } else {
        let stance_fraction =
            (local_phase_step - SWING_STEPS) as f64 / (CYCLE_STEPS - SWING_STEPS) as f64;
        (
            amplitude
                * lerp(
                    HIP_FORWARD_TARGET_RAD,
                    HIP_REAR_TARGET_RAD,
                    smoothstep(stance_fraction),
                ),
            0.0,
        )
    }
}

fn forward_velocity_foot_placement_envelope(local_phase_step: u64) -> f64 {
    if local_phase_step < SWING_STEPS {
        smoothstep(local_phase_step as f64 / SWING_STEPS as f64)
    } else {
        let stance_fraction =
            (local_phase_step - SWING_STEPS) as f64 / (CYCLE_STEPS - SWING_STEPS) as f64;
        1.0 - smoothstep(stance_fraction)
    }
}

fn steering_stride_scale(
    transform_id: Option<&str>,
    lateral_side_sign: f64,
    held_steering_fraction: f64,
) -> Result<f64> {
    let signed_steering = lateral_side_sign * held_steering_fraction;
    match transform_id {
        None => Ok(1.0 + signed_steering),
        Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID) => {
            let denominator = 1.0 - signed_steering;
            if !denominator.is_finite() || denominator <= 0.0 {
                return Err(CoreError::Frame(
                    "balanced_wave_reciprocal_stride_denominator".to_owned(),
                ));
            }
            Ok(1.0 / denominator)
        }
        Some(unknown) => Err(CoreError::Identity(format!(
            "balanced_wave_steering_stride_transform:{unknown}"
        ))),
    }
}

fn command_heading_aligned_lateral_axis(
    task_forward_axis_world_unit: Vec3,
    task_lateral_axis_world_unit: Vec3,
    requested_heading_error_rad: f64,
) -> Vec3 {
    let (sin_heading, cos_heading) = requested_heading_error_rad.sin_cos();
    Vec3 {
        x: -sin_heading * task_forward_axis_world_unit.x
            + cos_heading * task_lateral_axis_world_unit.x,
        y: -sin_heading * task_forward_axis_world_unit.y
            + cos_heading * task_lateral_axis_world_unit.y,
        z: -sin_heading * task_forward_axis_world_unit.z
            + cos_heading * task_lateral_axis_world_unit.z,
    }
}

fn smoothstep(value: f64) -> f64 {
    let clamped = value.clamp(0.0, 1.0);
    clamped * clamped * (3.0 - 2.0 * clamped)
}

fn lerp(first: f64, second: f64, fraction: f64) -> f64 {
    first + (second - first) * fraction
}

fn wrap_angle(value: f64) -> f64 {
    let two_pi = 2.0 * std::f64::consts::PI;
    (value + std::f64::consts::PI).rem_euclid(two_pi) - std::f64::consts::PI
}

#[cfg(test)]
mod tests {
    use super::*;
    include!("recovery_swing_end_recontact_tests.rs");
    include!("recovery_bounded_support_tests.rs");
    include!("recovery_floor_support_tests.rs");
    include!("recovery_feasible_support_tests.rs");
    include!("recovery_smooth_swing_tests.rs");
    include!("recovery_reference_velocity_tests.rs");
    include!("recovery_wave_velocity_tests.rs");
    include!("recovery_airborne_reference_tests.rs");
    include!("recovery_absent_contact_reference_tests.rs");
    include!("recovery_upright_stance_tests.rs");
    include!("recovery_stance_latch_tests.rs");
    include!("recovery_support_progression_tests.rs");
    include!("recovery_support_hold_posture_tests.rs");
    include!("recovery_measured_support_transfer_tests.rs");
    include!("recovery_measured_pose_support_tests.rs");
    include!("recovery_remaining_support_release_tests.rs");
    include!("recovery_extended_preparation_tests.rs");
    include!("joint_pose_entry_tests.rs");
    use crate::protocol::{
        CommandAuthority, ContactObservation, ContactProvenance, JointObservation,
        JointValidityMask, MOTION_COMMAND_VERSION, Pose, Quaternion, STATE_FRAME_VERSION,
        TaskFrame, Twist,
    };
    use crate::quadruped::{BoundedQuadrupedDescriptor, compile_bounded_quadruped};
    use crate::schema::Vec3;

    fn controller() -> Candidate35Controller {
        Candidate35Controller::new(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
        )
        .unwrap()
    }

    fn balanced_controller() -> BalancedWaveController {
        BalancedWaveController::new(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
        )
        .unwrap()
    }

    fn controller_with_upper_fraction(
        morphology_id: &str,
        upper_length_fraction: f64,
    ) -> Candidate35Controller {
        let mut descriptor = BoundedQuadrupedDescriptor::reference(morphology_id);
        descriptor.torso_length_scale = 1.10;
        descriptor.upper_length_fraction = upper_length_fraction;
        Candidate35Controller::new(compile_bounded_quadruped(descriptor).unwrap()).unwrap()
    }

    fn state(controller: &Candidate35Controller, step: u64) -> StateFrame {
        let morphology = &controller.compiled().morphology;
        StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step: step,
            sample_time_s: step as f64 / 120.0,
            base_pose_world: Pose {
                position_m: Vec3 {
                    x: 0.0,
                    y: 0.44,
                    z: 0.0,
                },
                orientation_xyzw: Quaternion::IDENTITY,
            },
            base_twist_world: Twist {
                linear_velocity_m_s: Vec3::ZERO,
                angular_velocity_rad_s: Vec3::ZERO,
            },
            ordered_joint_observations: morphology
                .ordered_joint_ids
                .iter()
                .map(|joint_id| JointObservation {
                    joint_id: joint_id.clone(),
                    position_rad: Some(0.0),
                    velocity_rad_s: Some(0.0),
                    anchor_error_m: Some(0.0),
                    validity: JointValidityMask {
                        position: true,
                        velocity: true,
                        anchor_error: true,
                    },
                })
                .collect(),
            ordered_contact_observations: morphology
                .ordered_contact_site_ids
                .iter()
                .map(|contact_site_id| ContactObservation {
                    contact_site_id: contact_site_id.clone(),
                    presence: Some(true),
                    bears_support: Some(true),
                    normal_load_n: None,
                    provenance: ContactProvenance {
                        adapter_id: "runtime_test".to_owned(),
                        engine_contact_ids: vec![format!("{contact_site_id}_contact")],
                        aggregation_rule_id: "qualified_bearing_only".to_owned(),
                        quality: ContactQuality::QualifiedBearing,
                        impulse_source_profile_id: None,
                        impulse_source_kind: None,
                    },
                })
                .collect(),
            previous_applied_actuation: None,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.81,
                z: 0.0,
            },
            task_frame: TaskFrame {
                origin_world_m: Vec3::ZERO,
                forward_axis_world_unit: Vec3 {
                    x: 1.0,
                    y: 0.0,
                    z: 0.0,
                },
                lateral_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 0.0,
                    z: 1.0,
                },
                up_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 1.0,
                    z: 0.0,
                },
                reference_yaw_rad: 0.0,
            },
            adapter_capability_sha256:
                "sha256:1111111111111111111111111111111111111111111111111111111111111111".to_owned(),
        }
    }

    fn command(step: u64) -> MotionCommand {
        MotionCommand {
            schema_version: MOTION_COMMAND_VERSION.to_owned(),
            command_id: "runtime_walk".to_owned(),
            desired_planar_velocity_task_m_s: Vec3 {
                x: 0.2,
                y: 0.0,
                z: 0.0,
            },
            desired_heading_rad: Some(0.0),
            desired_yaw_rate_rad_s: None,
            gait_family_id: "lateral_wave".to_owned(),
            speed_class: SpeedClass::Walk,
            gait_amplitude: 1.0,
            phase_progression_mode: PhaseProgressionMode::ContactGated,
            valid_from_step: step,
            valid_through_step: step,
            authority: CommandAuthority::TestFixture,
        }
    }

    #[test]
    fn pure_step_emits_exact_ordered_finite_motor_commands() {
        let controller = controller();
        let output = controller.step(
            &Candidate35ControllerMemory::initial(),
            &state(&controller, 0),
            &command(0),
        );
        assert!(!output.actuation.safe_no_actuation);
        assert_eq!(output.actuation.ordered_commands.len(), 8);
        assert_eq!(
            output
                .actuation
                .ordered_commands
                .iter()
                .map(|command| command.actuator_id.as_str())
                .collect::<Vec<_>>(),
            controller.compiled().morphology.ordered_actuator_ids
        );
        assert!(
            output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| command.target_velocity_rad_s.is_finite()
                    && command.target_velocity_rad_s.abs() <= command.maximum_target_speed_rad_s)
        );
        assert_eq!(output.actuation.world_build_count, 0);
        assert!(!output.actuation.physical_acceptance_authority);
    }

    #[test]
    fn balanced_wave_step_has_distinct_identity_and_exact_order() {
        let legacy = controller();
        let controller = balanced_controller();
        let output = controller.step(
            &BalancedWaveControllerMemory::initial(),
            &state(&legacy, 0),
            &command(0),
        );
        assert_eq!(output.schema_version, BALANCED_WAVE_RUNTIME_VERSION);
        assert_eq!(
            output.next_memory.schema_version,
            BALANCED_WAVE_MEMORY_VERSION
        );
        assert_eq!(output.actuation.receipt.policy_id, BALANCED_WAVE_POLICY_ID);
        assert!(!output.actuation.safe_no_actuation);
        assert_eq!(output.actuation.ordered_commands.len(), 8);
        assert_eq!(
            output
                .actuation
                .ordered_commands
                .iter()
                .map(|command| command.actuator_id.as_str())
                .collect::<Vec<_>>(),
            controller.compiled().morphology.ordered_actuator_ids
        );
        assert_eq!(
            output
                .actuation
                .ordered_commands
                .iter()
                .filter(|command| {
                    command.maximum_target_speed_rad_s
                        == controller
                            .profile()
                            .contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
                })
                .count(),
            1
        );
    }

    #[test]
    fn frozen_bw2_policy_controllers_preserve_requested_identity() {
        let legacy = controller();
        for policy_id in [
            BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW2_B_POLICY_ID,
            BALANCED_WAVE_BW2_C_POLICY_ID,
            BALANCED_WAVE_BW2R_A_POLICY_ID,
            BALANCED_WAVE_BW2R_B_POLICY_ID,
            BALANCED_WAVE_BW2R_C_POLICY_ID,
            BALANCED_WAVE_BW4R_A_POLICY_ID,
            BALANCED_WAVE_BW4R_B_POLICY_ID,
            BALANCED_WAVE_BW5R_A_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID,
            BALANCED_WAVE_BW5R_C_POLICY_ID,
            BALANCED_WAVE_BW7D_A_POLICY_ID,
            BALANCED_WAVE_BW7D_B_POLICY_ID,
            BALANCED_WAVE_BW7D_C_POLICY_ID,
            BALANCED_WAVE_BW7D_D_POLICY_ID,
            BALANCED_WAVE_BW8U_A_POLICY_ID,
            BALANCED_WAVE_BW8U_B_POLICY_ID,
            BALANCED_WAVE_BW8U_C_POLICY_ID,
            BALANCED_WAVE_BW8U_D_POLICY_ID,
            BALANCED_WAVE_BW14V_B_POLICY_ID,
        ] {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference(policy_id))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let output = controller.step(
                &BalancedWaveControllerMemory::initial(),
                &state(&legacy, 0),
                &command(0),
            );
            assert_eq!(controller.profile().policy_id, policy_id);
            assert_eq!(output.actuation.receipt.policy_id, policy_id);
            assert!(!output.actuation.safe_no_actuation);
            assert_eq!(output.actuation.ordered_commands.len(), 8);
        }
        assert!(
            BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("unknown"))
                    .unwrap(),
                "unknown_balanced_wave",
            )
            .is_err()
        );
    }

    #[test]
    fn bw4r_feedback_is_per_step_and_optional_slew_is_exact() {
        let legacy = controller();
        let mut displaced = state(&legacy, 1);
        displaced.base_pose_world.position_m.z = 0.10;
        let requested = command(1);

        let parent = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW2R_C_POLICY_ID,
        )
        .unwrap();
        let direct = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW4R_A_POLICY_ID,
        )
        .unwrap();
        let slew = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW4R_B_POLICY_ID,
        )
        .unwrap();

        let initial = BalancedWaveControllerMemory::initial();
        let parent_output = parent.step(&initial, &displaced, &requested);
        let direct_output = direct.step(&initial, &displaced, &requested);
        let slew_output = slew.step(&initial, &displaced, &requested);

        assert_eq!(parent_output.next_memory.held_path_steering_fraction, 0.0);
        assert!((direct_output.next_memory.held_path_steering_fraction - 0.13).abs() <= 1.0e-12);
        assert_eq!(
            slew_output.next_memory.held_path_steering_fraction,
            0.80 / 90.0
        );
        assert!((direct_output.actuation.receipt.held_steering_fraction - 0.13).abs() <= 1.0e-12);
        assert_eq!(
            slew_output.actuation.receipt.held_steering_fraction,
            0.80 / 90.0
        );
        assert!(direct_output.actuation.receipt.steering_feedback_updated);
        assert!(
            (direct_output.actuation.receipt.requested_steering_fraction - 0.13).abs() <= 1.0e-12
        );
        assert_eq!(
            direct_output.actuation.receipt.previous_steering_fraction,
            0.0
        );
        assert!((direct_output.actuation.receipt.applied_steering_delta - 0.13).abs() <= 1.0e-12);
        assert!(!direct_output.actuation.receipt.steering_slew_limited);
        assert!(slew_output.actuation.receipt.steering_slew_limited);
        assert_eq!(
            direct_output
                .actuation
                .receipt
                .steering_filter_alpha_per_step,
            None
        );
    }

    #[test]
    fn bw5r_feedback_uses_exact_cycle_normalized_one_pole_filters() {
        let legacy = controller();
        let mut displaced = state(&legacy, 1);
        displaced.base_pose_world.position_m.z = 0.10;
        let requested = command(1);
        let initial = BalancedWaveControllerMemory::initial();

        for (policy_id, time_constant_cycle_fraction) in [
            (BALANCED_WAVE_BW5R_A_POLICY_ID, 1.0 / 32.0),
            (BALANCED_WAVE_BW5R_B_POLICY_ID, 1.0 / 16.0),
            (BALANCED_WAVE_BW5R_C_POLICY_ID, 1.0 / 8.0),
        ] {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime"))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let output = controller.step(&initial, &displaced, &requested);
            let time_constant_steps = time_constant_cycle_fraction * CYCLE_STEPS as f64;
            let expected_alpha = 1.0 - (-1.0 / time_constant_steps).exp();
            let expected_filtered = expected_alpha * 0.13;

            assert_eq!(
                output
                    .actuation
                    .receipt
                    .steering_filter_time_constant_cycle_fraction,
                Some(time_constant_cycle_fraction)
            );
            assert_eq!(
                output.actuation.receipt.steering_filter_alpha_per_step,
                Some(expected_alpha)
            );
            assert!(
                (output.next_memory.held_path_steering_fraction - expected_filtered).abs()
                    <= 1.0e-15
            );
            assert_eq!(
                output.actuation.receipt.applied_steering_delta,
                output.next_memory.held_path_steering_fraction
            );
            assert!(!output.actuation.receipt.steering_slew_limited);
        }
    }

    #[test]
    fn bw14v_forward_velocity_foot_placement_is_bounded_signed_and_fully_receipted() {
        let legacy = controller();
        let parent = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW5R_B_POLICY_ID,
        )
        .unwrap();
        let treatment = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW14V_B_POLICY_ID,
        )
        .unwrap();
        let initial = BalancedWaveControllerMemory::initial();
        let requested = command(0);

        let slow_state = state(&legacy, 0);
        let parent_output = parent.step(&initial, &slow_state, &requested);
        let slow_output = treatment.step(&initial, &slow_state, &requested);
        assert!(!slow_output.actuation.safe_no_actuation);
        assert_eq!(
            slow_output.actuation.receipt.schema_version,
            "sporespore_controller_step_receipt_v4"
        );
        let slow_receipt = slow_output
            .actuation
            .receipt
            .forward_velocity_foot_placement
            .as_ref()
            .unwrap();
        assert_eq!(
            slow_receipt.schema_version,
            "sporespore_forward_velocity_foot_placement_receipt_v1"
        );
        assert_eq!(slow_receipt.velocity_error_orientation_id, None);
        assert_eq!(
            slow_receipt.mode_id,
            FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID
        );
        assert_eq!(slow_receipt.desired_forward_velocity_task_m_s, 0.2);
        assert_eq!(slow_receipt.measured_forward_velocity_task_m_s, 0.0);
        assert_eq!(slow_receipt.normalized_forward_velocity_error, 1.0);
        assert_eq!(slow_receipt.maximum_hip_target_correction_rad, 0.30);
        assert_eq!(slow_receipt.ordered_limb_corrections.len(), 4);
        assert_eq!(slow_receipt.morphology_branch_surface_count, 0);
        assert!(slow_receipt.controller_parameter);
        assert!(!slow_receipt.walking_claim_authorized);
        assert!(!slow_receipt.physical_acceptance_authority);

        let parent_hips = parent_output
            .actuation
            .ordered_commands
            .iter()
            .filter(|command| command.actuator_id.ends_with("_hip_motor"))
            .collect::<Vec<_>>();
        let slow_hips = slow_output
            .actuation
            .ordered_commands
            .iter()
            .filter(|command| command.actuator_id.ends_with("_hip_motor"))
            .collect::<Vec<_>>();
        assert_eq!(parent_hips.len(), 4);
        assert_eq!(slow_hips.len(), 4);
        for ((parent_hip, slow_hip), correction) in parent_hips
            .iter()
            .zip(&slow_hips)
            .zip(&slow_receipt.ordered_limb_corrections)
        {
            assert!((0.0..=1.0).contains(&correction.cycle_envelope));
            assert!(
                correction.applied_hip_target_correction_rad >= 0.0
                    && correction.applied_hip_target_correction_rad <= 0.30
            );
            assert!(
                (slow_hip.requested_target_position_rad
                    - parent_hip.requested_target_position_rad
                    - correction.applied_hip_target_correction_rad)
                    .abs()
                    <= 1.0e-15
            );
        }

        let mut fast_state = state(&legacy, 0);
        fast_state.base_twist_world.linear_velocity_m_s.x = 0.4;
        let fast_output = treatment.step(&initial, &fast_state, &requested);
        let fast_receipt = fast_output
            .actuation
            .receipt
            .forward_velocity_foot_placement
            .as_ref()
            .unwrap();
        assert_eq!(fast_receipt.measured_forward_velocity_task_m_s, 0.4);
        assert_eq!(fast_receipt.normalized_forward_velocity_error, -1.0);
        for (slow, fast) in slow_receipt
            .ordered_limb_corrections
            .iter()
            .zip(&fast_receipt.ordered_limb_corrections)
        {
            assert_eq!(slow.limb_id, fast.limb_id);
            assert_eq!(slow.local_phase_step, fast.local_phase_step);
            assert_eq!(slow.cycle_envelope, fast.cycle_envelope);
            assert!(
                (slow.applied_hip_target_correction_rad + fast.applied_hip_target_correction_rad)
                    .abs()
                    <= 1.0e-15
            );
        }

        let mut on_target_state = state(&legacy, 0);
        on_target_state.base_twist_world.linear_velocity_m_s.x = 0.2;
        let on_target_output = treatment.step(&initial, &on_target_state, &requested);
        let on_target_receipt = on_target_output
            .actuation
            .receipt
            .forward_velocity_foot_placement
            .as_ref()
            .unwrap();
        assert_eq!(on_target_receipt.normalized_forward_velocity_error, 0.0);
        assert!(
            on_target_receipt
                .ordered_limb_corrections
                .iter()
                .all(|correction| correction.applied_hip_target_correction_rad == 0.0)
        );

        let mut zero_command = requested.clone();
        zero_command.desired_planar_velocity_task_m_s.x = 0.0;
        let zero_output = treatment.step(&initial, &fast_state, &zero_command);
        let zero_receipt = zero_output
            .actuation
            .receipt
            .forward_velocity_foot_placement
            .as_ref()
            .unwrap();
        assert_eq!(zero_receipt.normalized_forward_velocity_error, 0.0);
        assert!(
            zero_receipt
                .ordered_limb_corrections
                .iter()
                .all(|correction| correction.applied_hip_target_correction_rad == 0.0)
        );
    }

    #[test]
    fn bw15f_separates_global_error_orientation_and_small_gain_without_branches() {
        let legacy = controller();
        let initial = BalancedWaveControllerMemory::initial();
        let requested = command(0);
        let slow_state = state(&legacy, 0);
        let parent = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_BW5R_B_POLICY_ID,
        )
        .unwrap();
        let parent_output = parent.step(&initial, &slow_state, &requested);

        let cases = [
            (
                BALANCED_WAVE_BW15F_B_POLICY_ID,
                0.03,
                DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
                1.0,
            ),
            (
                BALANCED_WAVE_BW15F_C_POLICY_ID,
                0.03,
                MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
                -1.0,
            ),
            (
                BALANCED_WAVE_BW15F_D_POLICY_ID,
                0.06,
                MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
                -1.0,
            ),
        ];
        let mut corrections_by_policy = Vec::new();

        for (policy_id, maximum, orientation_id, expected_error) in cases {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime"))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let output = controller.step(&initial, &slow_state, &requested);
            assert!(!output.actuation.safe_no_actuation);
            assert_eq!(
                output.actuation.receipt.schema_version,
                "sporespore_controller_step_receipt_v5"
            );
            let receipt = output
                .actuation
                .receipt
                .forward_velocity_foot_placement
                .as_ref()
                .unwrap();
            assert_eq!(
                receipt.schema_version,
                "sporespore_forward_velocity_foot_placement_receipt_v2"
            );
            assert_eq!(
                receipt.velocity_error_orientation_id.as_deref(),
                Some(orientation_id)
            );
            assert_eq!(receipt.normalized_forward_velocity_error, expected_error);
            assert_eq!(receipt.maximum_hip_target_correction_rad, maximum);
            assert_eq!(receipt.ordered_limb_corrections.len(), 4);
            assert_eq!(receipt.morphology_branch_surface_count, 0);
            let parent_hips = parent_output
                .actuation
                .ordered_commands
                .iter()
                .filter(|command| command.actuator_id.ends_with("_hip_motor"));
            let treatment_hips = output
                .actuation
                .ordered_commands
                .iter()
                .filter(|command| command.actuator_id.ends_with("_hip_motor"));
            for ((parent_hip, treatment_hip), correction) in parent_hips
                .zip(treatment_hips)
                .zip(&receipt.ordered_limb_corrections)
            {
                assert!(correction.applied_hip_target_correction_rad.abs() <= maximum + 1.0e-15);
                assert!(
                    (treatment_hip.requested_target_position_rad
                        - parent_hip.requested_target_position_rad
                        - correction.applied_hip_target_correction_rad)
                        .abs()
                        <= 1.0e-15
                );
            }
            corrections_by_policy.push(
                receipt
                    .ordered_limb_corrections
                    .iter()
                    .map(|correction| correction.applied_hip_target_correction_rad)
                    .collect::<Vec<_>>(),
            );
        }

        for ((b_correction, c_correction), d_correction) in corrections_by_policy[0]
            .iter()
            .zip(&corrections_by_policy[1])
            .zip(&corrections_by_policy[2])
        {
            assert!((b_correction + c_correction).abs() <= 1.0e-15);
            assert!((d_correction - 2.0 * c_correction).abs() <= 1.0e-15);
        }

        let mut zero_command = requested;
        zero_command.desired_planar_velocity_task_m_s.x = 0.0;
        for policy_id in [
            BALANCED_WAVE_BW15F_B_POLICY_ID,
            BALANCED_WAVE_BW15F_C_POLICY_ID,
            BALANCED_WAVE_BW15F_D_POLICY_ID,
        ] {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime"))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let zero_output = controller.step(&initial, &slow_state, &zero_command);
            assert!(
                zero_output
                    .actuation
                    .receipt
                    .forward_velocity_foot_placement
                    .as_ref()
                    .unwrap()
                    .ordered_limb_corrections
                    .iter()
                    .all(|correction| correction.applied_hip_target_correction_rad == 0.0)
            );
        }
    }

    #[test]
    fn bw21l_changes_only_declared_cross_track_gains_in_the_live_step() {
        let legacy = controller();
        let initial = BalancedWaveControllerMemory::initial();
        let requested = command(0);
        let mut exposed_state = state(&legacy, 0);
        exposed_state.base_pose_world.position_m.z = 0.12;
        exposed_state.base_twist_world.linear_velocity_m_s.z = 0.05;
        let cases = [
            (BALANCED_WAVE_BW15F_B_POLICY_ID, 0.178_75),
            (BALANCED_WAVE_BW21L_B_POLICY_ID, 0.256_75),
            (BALANCED_WAVE_BW21L_C_POLICY_ID, 0.201_5),
            (BALANCED_WAVE_BW21L_D_POLICY_ID, 0.279_5),
            (BALANCED_WAVE_BW23Y_B_POLICY_ID, 0.137_5),
            (BALANCED_WAVE_BW34Y_A_POLICY_ID, 0.096_25),
        ];

        for (policy_id, expected_requested_steering) in cases {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime"))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let output = controller.step(&initial, &exposed_state, &requested);
            let receipt = &output.actuation.receipt;
            assert!(!output.actuation.safe_no_actuation);
            assert_eq!(receipt.policy_id, policy_id);
            assert_eq!(
                receipt.schema_version,
                "sporespore_controller_step_receipt_v5"
            );
            assert!(
                (receipt.requested_steering_fraction - expected_requested_steering).abs()
                    <= 1.0e-15
            );
            assert_eq!(
                receipt
                    .forward_velocity_foot_placement
                    .as_ref()
                    .unwrap()
                    .velocity_error_orientation_id
                    .as_deref(),
                Some(DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID)
            );
            assert!(controller.profile().branch_surfaces.is_empty());
        }
    }

    #[test]
    fn r23d19_projects_cross_track_onto_the_commanded_heading_frame() {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap();
        let parent = BalancedWaveController::new_for_policy(
            compiled.clone(),
            BALANCED_WAVE_BW15F_B_POLICY_ID,
        )
        .unwrap();
        let successor = BalancedWaveController::new_for_policy(
            compiled,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
        )
        .unwrap();
        let initial = BalancedWaveControllerMemory::initial();
        let mut positive_command = command(0);
        positive_command.desired_heading_rad = Some(0.2);
        let legacy = controller();
        let mut positive_ray_state = state(&legacy, 0);
        positive_ray_state.base_pose_world.position_m.x = 0.8;
        positive_ray_state.base_pose_world.position_m.z = 0.8 * 0.2_f64.tan();

        let parent_positive = parent.step(&initial, &positive_ray_state, &positive_command);
        let successor_positive = successor.step(&initial, &positive_ray_state, &positive_command);
        assert!(parent_positive.actuation.receipt.cross_track_error_m > 0.16);
        assert!(
            successor_positive
                .actuation
                .receipt
                .cross_track_error_m
                .abs()
                <= 1.0e-15
        );
        assert!(
            (successor_positive
                .actuation
                .receipt
                .desired_heading_error_rad
                - 0.2)
                .abs()
                <= 1.0e-15
        );
        assert!(
            (successor_positive
                .actuation
                .receipt
                .requested_steering_fraction
                + 0.26)
                .abs()
                <= 1.0e-15
        );

        let mut negative_command = command(0);
        negative_command.desired_heading_rad = Some(-0.2);
        let mut negative_ray_state = state(&legacy, 0);
        negative_ray_state.base_pose_world.position_m.x = 0.8;
        negative_ray_state.base_pose_world.position_m.z = -0.8 * 0.2_f64.tan();
        let successor_negative = successor.step(&initial, &negative_ray_state, &negative_command);
        assert!(
            successor_negative
                .actuation
                .receipt
                .cross_track_error_m
                .abs()
                <= 1.0e-15
        );
        assert!(
            (successor_negative
                .actuation
                .receipt
                .requested_steering_fraction
                - 0.26)
                .abs()
                <= 1.0e-15
        );

        let zero_command = command(0);
        let parent_zero = parent.step(&initial, &positive_ray_state, &zero_command);
        let successor_zero = successor.step(&initial, &positive_ray_state, &zero_command);
        assert_eq!(
            parent_zero.actuation.receipt.cross_track_error_m,
            successor_zero.actuation.receipt.cross_track_error_m
        );
        assert_eq!(
            parent_zero.actuation.receipt.cross_track_velocity_m_s,
            successor_zero.actuation.receipt.cross_track_velocity_m_s
        );
        assert_eq!(
            parent_zero.actuation.receipt.requested_steering_fraction,
            successor_zero.actuation.receipt.requested_steering_fraction
        );
    }

    #[test]
    fn r23d26_applies_each_profile_cap_without_changing_subcap_feedback() {
        let initial = BalancedWaveControllerMemory::initial();
        let legacy = controller();
        let exposed_state = state(&legacy, 0);
        let mut large_command = command(0);
        large_command.desired_heading_rad = Some(0.25);
        let zero_command = command(0);
        let parent = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
        )
        .unwrap();
        let parent_zero = parent.step(&initial, &exposed_state, &zero_command);
        let cases = [
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID, 0.10),
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID, 0.20),
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID, 0.30),
        ];

        for (policy_id, cap) in cases {
            let candidate = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime"))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let large = candidate.step(&initial, &exposed_state, &large_command);
            assert!(large.actuation.receipt.requested_steering_fraction.abs() <= cap);
            assert!(large.actuation.receipt.held_steering_fraction.abs() <= cap);
            assert_eq!(large.actuation.receipt.steering_saturated, cap < 0.25);

            let zero = candidate.step(&initial, &exposed_state, &zero_command);
            assert_eq!(
                zero.actuation.receipt.requested_steering_fraction,
                parent_zero.actuation.receipt.requested_steering_fraction
            );
            assert_eq!(
                zero.actuation.receipt.held_steering_fraction,
                parent_zero.actuation.receipt.held_steering_fraction
            );
        }
    }

    #[test]
    fn r23d27_guard_is_direction_neutral_and_falls_back_to_cap_0p20() {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap();
        let probe = Candidate35Controller::new(compiled.clone()).unwrap();
        let candidate = BalancedWaveController::new_for_policy(
            compiled,
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let mut positive = command(0);
        positive.desired_heading_rad = Some(0.35);
        let mut negative = positive.clone();
        negative.desired_heading_rad = Some(-0.35);
        let upright = state(&probe, 0);

        let positive_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &upright,
            &positive,
        );
        let negative_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &upright,
            &negative,
        );
        let positive_guard = positive_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        let negative_guard = negative_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert_eq!(
            positive_output.actuation.receipt.schema_version,
            "sporespore_controller_step_receipt_v6"
        );
        assert_eq!(positive_guard.effective_maximum_steering_fraction, 0.28);
        assert_eq!(negative_guard.effective_maximum_steering_fraction, 0.28);
        assert_eq!(positive_guard.torso_tilt_rad, negative_guard.torso_tilt_rad);
        assert_eq!(positive_guard.support_contact_count, 4);
        assert!(positive_guard.direction_neutral);
        assert_eq!(positive_guard.engine_identity_input_count, 0);
        assert_eq!(
            positive_output
                .actuation
                .receipt
                .requested_steering_fraction,
            -negative_output
                .actuation
                .receipt
                .requested_steering_fraction
        );

        let angle = 0.20_f64;
        let mut tilted = upright.clone();
        tilted.base_pose_world.orientation_xyzw = Quaternion {
            x: angle.sin(),
            y: 0.0,
            z: 0.0,
            w: angle.cos(),
        };
        let tilted_output =
            candidate.step(&BalancedWaveControllerMemory::initial(), &tilted, &positive);
        let tilted_guard = tilted_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert!((tilted_guard.torso_tilt_rad - 0.40).abs() <= 1.0e-12);
        assert_eq!(tilted_guard.tilt_authority_fraction, 0.0);
        assert_eq!(tilted_guard.effective_maximum_steering_fraction, 0.20);
        assert!(
            tilted_output
                .actuation
                .receipt
                .requested_steering_fraction
                .abs()
                <= 0.20
        );

        let mut low_support = upright;
        for contact in &mut low_support.ordered_contact_observations[1..] {
            contact.presence = Some(false);
            contact.bears_support = Some(false);
            contact.provenance.engine_contact_ids.clear();
        }
        let low_support_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &low_support,
            &positive,
        );
        let low_support_guard = low_support_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert_eq!(low_support_guard.support_contact_count, 1);
        assert!(!low_support_guard.contact_authority_permitted);
        assert_eq!(low_support_guard.effective_maximum_steering_fraction, 0.20);
    }

    #[test]
    fn r23d28_predicts_tilt_from_state_frame_rate_without_direction_or_engine_inputs() {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap();
        let probe = Candidate35Controller::new(compiled.clone()).unwrap();
        let candidate = BalancedWaveController::new_for_policy(
            compiled,
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let mut positive = command(0);
        positive.desired_heading_rad = Some(0.35);
        let mut negative = positive.clone();
        negative.desired_heading_rad = Some(-0.35);

        let angle = 0.05_f64;
        let mut worsening = state(&probe, 0);
        worsening.base_pose_world.orientation_xyzw = Quaternion {
            x: angle.sin(),
            y: 0.0,
            z: 0.0,
            w: angle.cos(),
        };
        worsening.base_twist_world.angular_velocity_rad_s = Vec3 {
            x: 0.10,
            y: 0.0,
            z: 0.0,
        };
        let positive_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &worsening,
            &positive,
        );
        let negative_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &worsening,
            &negative,
        );
        let guard = positive_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        let negative_guard = negative_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();

        assert_eq!(
            positive_output.actuation.receipt.schema_version,
            "sporespore_controller_step_receipt_v7"
        );
        assert_eq!(
            guard.schema_version,
            "sporespore_steering_authority_guard_receipt_v2"
        );
        assert!((guard.torso_tilt_rad - 0.10).abs() <= 1.0e-12);
        assert!((guard.torso_tilt_rate_rad_s.unwrap() - 0.10).abs() <= 1.0e-12);
        assert!((guard.worsening_torso_tilt_rate_rad_s.unwrap() - 0.10).abs() <= 1.0e-12);
        assert_eq!(guard.prediction_horizon_s, Some(0.6));
        assert_eq!(guard.prediction_horizon_scheduler_swing_steps, Some(72));
        assert!((guard.predicted_torso_tilt_rad.unwrap() - 0.16).abs() <= 1.0e-12);
        assert_eq!(
            guard.tilt_rate_source_id.as_deref(),
            Some("state_frame_base_twist_world_angular_velocity_v1")
        );
        assert_eq!(
            guard.prediction_horizon_basis_id.as_deref(),
            Some("one_balanced_wave_scheduler_swing_v1")
        );
        assert!((guard.tilt_authority_fraction - 0.40).abs() <= 1.0e-12);
        assert!((guard.effective_maximum_steering_fraction - 0.232).abs() <= 1.0e-12);
        assert_eq!(guard, negative_guard);
        assert!(guard.direction_neutral);
        assert_eq!(guard.engine_identity_input_count, 0);
        assert_eq!(
            positive_output
                .actuation
                .receipt
                .requested_steering_fraction,
            -negative_output
                .actuation
                .receipt
                .requested_steering_fraction
        );

        let mut recovering = worsening;
        recovering.base_twist_world.angular_velocity_rad_s.x = -0.10;
        let recovering_output = candidate.step(
            &BalancedWaveControllerMemory::initial(),
            &recovering,
            &positive,
        );
        let recovering_guard = recovering_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert!((recovering_guard.torso_tilt_rate_rad_s.unwrap() + 0.10).abs() <= 1.0e-12);
        assert_eq!(recovering_guard.worsening_torso_tilt_rate_rad_s, Some(0.0));
        assert!((recovering_guard.predicted_torso_tilt_rad.unwrap() - 0.10).abs() <= 1.0e-12);
        assert!((recovering_guard.effective_maximum_steering_fraction - 0.28).abs() <= 1.0e-12);

        let parent = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap(),
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let parent_output = parent.step(
            &BalancedWaveControllerMemory::initial(),
            &recovering,
            &positive,
        );
        let parent_guard = parent_output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert_eq!(
            parent_output.actuation.receipt.schema_version,
            "sporespore_controller_step_receipt_v6"
        );
        assert_eq!(
            parent_guard.schema_version,
            "sporespore_steering_authority_guard_receipt_v1"
        );
        assert_eq!(parent_guard.torso_tilt_rate_rad_s, None);
        assert_eq!(parent_guard.predicted_torso_tilt_rad, None);
        let serialized_parent_guard = serde_json::to_value(parent_guard).unwrap();
        assert!(
            serialized_parent_guard
                .get("torso_tilt_rate_rad_s")
                .is_none()
        );
        assert!(
            serialized_parent_guard
                .get("prediction_horizon_s")
                .is_none()
        );
    }

    #[test]
    fn r23d29_persists_a_reached_floor_for_two_complete_scheduler_swings() {
        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap();
        let probe = Candidate35Controller::new(compiled.clone()).unwrap();
        let candidate = BalancedWaveController::new_for_policy(
            compiled,
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let mut memory = candidate.initial_memory();
        assert_eq!(
            memory.schema_version,
            BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
        );
        assert_eq!(memory.steering_guard_floor_hold_steps_remaining, Some(0));
        // Begin above the prospective floor so this gate proves that the
        // one-step feedback cadence clamps physically held steering on the
        // same row that activates the persistent guard.
        memory.held_path_steering_fraction = 0.28;

        let angle = 0.05_f64;
        let mut worsening = state(&probe, 0);
        worsening.base_pose_world.orientation_xyzw = Quaternion {
            x: angle.sin(),
            y: 0.0,
            z: 0.0,
            w: angle.cos(),
        };
        worsening.base_twist_world.angular_velocity_rad_s = Vec3 {
            x: 0.20,
            y: 0.0,
            z: 0.0,
        };
        let mut first_command = command(0);
        first_command.desired_heading_rad = Some(0.35);
        let first = candidate.step(&memory, &worsening, &first_command);
        assert!(!first.actuation.safe_no_actuation);
        assert_eq!(
            first.actuation.receipt.schema_version,
            "sporespore_controller_step_receipt_v8"
        );
        let first_guard = first
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert_eq!(
            first_guard.schema_version,
            "sporespore_steering_authority_guard_receipt_v3"
        );
        assert_eq!(
            first_guard.mode_id,
            PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID
        );
        assert_eq!(first_guard.floor_hold_duration_steps, Some(144));
        assert_eq!(first_guard.floor_hold_scheduler_swing_count, Some(2));
        assert_eq!(first_guard.floor_hold_steps_remaining_before_step, Some(0));
        assert_eq!(first_guard.floor_hold_steps_remaining_after_step, Some(143));
        assert_eq!(first_guard.floor_hold_triggered_this_step, Some(true));
        assert_eq!(first_guard.floor_hold_active_this_step, Some(true));
        assert_eq!(first_guard.instantaneous_tilt_authority_fraction, Some(0.0));
        assert_eq!(
            first_guard.instantaneous_effective_maximum_steering_fraction,
            Some(0.20)
        );
        assert_eq!(first_guard.tilt_authority_fraction, 0.0);
        assert_eq!(first_guard.effective_maximum_steering_fraction, 0.20);
        assert_eq!(
            first.next_memory.steering_guard_floor_hold_steps_remaining,
            Some(143)
        );
        assert_eq!(first.next_memory.held_path_steering_fraction, 0.20);
        memory = first.next_memory;

        for semantic_step in 1..=143 {
            let safe_state = state(&probe, semantic_step);
            let mut safe_command = command(semantic_step);
            safe_command.desired_heading_rad = Some(0.35);
            let output = candidate.step(&memory, &safe_state, &safe_command);
            assert!(!output.actuation.safe_no_actuation);
            let guard = output
                .actuation
                .receipt
                .steering_authority_guard
                .as_ref()
                .unwrap();
            assert_eq!(
                guard.instantaneous_effective_maximum_steering_fraction,
                Some(0.28)
            );
            assert_eq!(guard.floor_hold_triggered_this_step, Some(false));
            assert_eq!(guard.floor_hold_active_this_step, Some(true));
            assert_eq!(guard.effective_maximum_steering_fraction, 0.20);
            assert_eq!(
                guard.floor_hold_steps_remaining_before_step,
                Some(144 - semantic_step)
            );
            assert_eq!(
                guard.floor_hold_steps_remaining_after_step,
                Some(143 - semantic_step)
            );
            assert!(output.next_memory.held_path_steering_fraction.abs() <= 0.20);
            memory = output.next_memory;
        }

        let safe_state = state(&probe, 144);
        let mut safe_command = command(144);
        safe_command.desired_heading_rad = Some(0.35);
        let expired = candidate.step(&memory, &safe_state, &safe_command);
        assert!(!expired.actuation.safe_no_actuation);
        let expired_guard = expired
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .unwrap();
        assert_eq!(
            expired_guard.floor_hold_steps_remaining_before_step,
            Some(0)
        );
        assert_eq!(expired_guard.floor_hold_steps_remaining_after_step, Some(0));
        assert_eq!(expired_guard.floor_hold_triggered_this_step, Some(false));
        assert_eq!(expired_guard.floor_hold_active_this_step, Some(false));
        assert_eq!(expired_guard.effective_maximum_steering_fraction, 0.28);

        let mut malformed = candidate.initial_memory();
        malformed.steering_guard_floor_hold_steps_remaining = Some(145);
        let malformed_output = candidate.step(&malformed, &state(&probe, 0), &command(0));
        assert!(malformed_output.actuation.safe_no_actuation);
        assert_eq!(malformed_output.actuation.failure_codes, ["SCHEMA_INVALID"]);
        assert!(
            malformed_output
                .actuation
                .receipt
                .controller_error
                .as_deref()
                .is_some_and(|error| error.contains("balanced_wave_steering_floor_hold_memory"))
        );
    }

    #[test]
    fn r23d19_heading_aligned_axis_is_symmetric_orthonormal_and_task_frame_neutral() {
        let forward = Vec3 {
            x: 0.0,
            y: 0.0,
            z: 1.0,
        };
        let lateral = Vec3 {
            x: -1.0,
            y: 0.0,
            z: 0.0,
        };
        let positive = command_heading_aligned_lateral_axis(forward, lateral, 0.2);
        let negative = command_heading_aligned_lateral_axis(forward, lateral, -0.2);
        let zero = command_heading_aligned_lateral_axis(forward, lateral, 0.0);
        let (sin_heading, cos_heading) = 0.2_f64.sin_cos();
        let positive_forward = Vec3 {
            x: cos_heading * forward.x + sin_heading * lateral.x,
            y: cos_heading * forward.y + sin_heading * lateral.y,
            z: cos_heading * forward.z + sin_heading * lateral.z,
        };

        assert_eq!(zero, lateral);
        assert!((dot(positive, positive) - 1.0).abs() <= 1.0e-15);
        assert!((dot(negative, negative) - 1.0).abs() <= 1.0e-15);
        assert!(dot(positive, positive_forward).abs() <= 1.0e-15);
        assert!((positive.x - negative.x).abs() <= 1.0e-15);
        assert!((positive.z + negative.z).abs() <= 1.0e-15);

        let compiled =
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference("runtime")).unwrap();
        let successor = BalancedWaveController::new_for_policy(
            compiled,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
        )
        .unwrap();
        let initial = BalancedWaveControllerMemory::initial();
        let legacy = controller();
        let mut rotated_state = state(&legacy, 0);
        rotated_state.task_frame.forward_axis_world_unit = forward;
        rotated_state.task_frame.lateral_axis_world_unit = lateral;
        rotated_state.task_frame.reference_yaw_rad = std::f64::consts::FRAC_PI_2;
        rotated_state.base_pose_world.position_m = Vec3 {
            x: 0.8 * positive_forward.x,
            y: 0.44,
            z: 0.8 * positive_forward.z,
        };
        let mut rotated_command = command(0);
        rotated_command.desired_heading_rad = Some(std::f64::consts::FRAC_PI_2 + 0.2);
        let output = successor.step(&initial, &rotated_state, &rotated_command);
        assert!(!output.actuation.safe_no_actuation);
        assert!(output.actuation.receipt.cross_track_error_m.abs() <= 1.0e-15);
    }

    #[test]
    fn bw7d_reciprocal_stride_transform_is_smooth_symmetric_and_noncollapsing() {
        for held in [-0.40, -0.25, 0.0, 0.25, 0.40] {
            let left =
                steering_stride_scale(Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID), -1.0, held)
                    .unwrap();
            let right =
                steering_stride_scale(Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID), 1.0, held)
                    .unwrap();
            let mirrored_left =
                steering_stride_scale(Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID), -1.0, -held)
                    .unwrap();
            let mirrored_right =
                steering_stride_scale(Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID), 1.0, -held)
                    .unwrap();
            assert!(left.is_finite() && right.is_finite());
            assert!(left >= 1.0 / 1.4 && right >= 1.0 / 1.4);
            assert!((left - mirrored_right).abs() <= 1.0e-15);
            assert!((right - mirrored_left).abs() <= 1.0e-15);
        }
        assert_eq!(steering_stride_scale(None, 1.0, 0.40).unwrap(), 1.40);
        assert!(
            steering_stride_scale(Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID), 1.0, 1.0,)
                .is_err()
        );
    }

    #[test]
    fn bw8u_release_gate_unweighting_is_an_exact_branch_free_two_by_two_mechanism() {
        let legacy = controller();
        let mut loaded_state = state(&legacy, 1);
        let mut loaded_memory = BalancedWaveControllerMemory::initial();
        loaded_memory.last_semantic_step = Some(0);
        loaded_memory.phase_progression_mode = Some(PhaseProgressionMode::ContactGated);
        loaded_memory.ordered_limb_memory[0].gait_step = RELEASE_GATE_LOCAL_STEP;

        let cases = [
            (BALANCED_WAVE_BW8U_A_POLICY_ID, false, false),
            (BALANCED_WAVE_BW8U_B_POLICY_ID, true, false),
            (BALANCED_WAVE_BW8U_C_POLICY_ID, false, true),
            (BALANCED_WAVE_BW8U_D_POLICY_ID, true, true),
        ];
        let mut loaded_outputs = Vec::new();
        for (policy_id, knee_enabled, hip_enabled) in cases {
            let controller = BalancedWaveController::new_for_policy(
                compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference(policy_id))
                    .unwrap(),
                policy_id,
            )
            .unwrap();
            let output = controller.step(&loaded_memory, &loaded_state, &command(1));
            assert!(!output.actuation.safe_no_actuation);
            assert_eq!(
                output.actuation.receipt.schema_version,
                "sporespore_controller_step_receipt_v3"
            );
            let receipt = output
                .actuation
                .receipt
                .release_gate_unweighting
                .as_ref()
                .expect("BW8U receipt");
            assert_eq!(
                receipt.schema_version,
                "sporespore_release_gate_unweighting_receipt_v1"
            );
            assert_eq!(
                receipt.knee_target_mode_id.as_deref(),
                knee_enabled.then_some(RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID)
            );
            assert_eq!(
                receipt.hip_target_mode_id.as_deref(),
                hip_enabled.then_some(RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID)
            );
            assert_eq!(
                receipt.ordered_knee_override_limb_ids,
                if knee_enabled {
                    vec!["rear_left".to_owned()]
                } else {
                    vec![]
                }
            );
            assert_eq!(
                receipt.ordered_hip_override_limb_ids,
                if hip_enabled {
                    vec!["rear_left".to_owned()]
                } else {
                    vec![]
                }
            );
            assert_eq!(
                receipt.analytic_target_basis,
                "existing_lateral_wave_swing_apex_at_half_swing_v1"
            );
            assert_eq!(receipt.morphology_branch_surface_count, 0);
            assert!(receipt.controller_parameter);
            assert!(!receipt.walking_claim_authorized);
            assert!(!receipt.physical_acceptance_authority);
            loaded_outputs.push(output);
        }

        let target = |output: &BalancedWaveControllerStepOutput, actuator_id: &str| {
            output
                .actuation
                .ordered_commands
                .iter()
                .find(|entry| entry.actuator_id == actuator_id)
                .expect("actuator")
                .requested_target_position_rad
        };
        let a_hip = target(&loaded_outputs[0], "rear_left_hip_motor");
        let a_knee = target(&loaded_outputs[0], "rear_left_knee_motor");
        let b_hip = target(&loaded_outputs[1], "rear_left_hip_motor");
        let b_knee = target(&loaded_outputs[1], "rear_left_knee_motor");
        let c_hip = target(&loaded_outputs[2], "rear_left_hip_motor");
        let c_knee = target(&loaded_outputs[2], "rear_left_knee_motor");
        let d_hip = target(&loaded_outputs[3], "rear_left_hip_motor");
        let d_knee = target(&loaded_outputs[3], "rear_left_knee_motor");
        let expected_hip_apex = lerp(HIP_REAR_TARGET_RAD, HIP_FORWARD_TARGET_RAD, smoothstep(0.5));
        let expected_knee_apex =
            KNEE_SWING_FLEXION_RAD * KNEE_FLEXION_SCALE + CONTACT_CLEARANCE_ASSIST_RAD;

        assert_eq!(a_hip, b_hip);
        assert_eq!(a_knee, c_knee);
        assert_eq!(b_knee, expected_knee_apex);
        assert_eq!(d_knee, expected_knee_apex);
        assert_eq!(c_hip, expected_hip_apex);
        assert_eq!(d_hip, expected_hip_apex);
        assert_ne!(a_knee, b_knee);
        assert_ne!(a_hip, c_hip);

        let rear_left_contact = loaded_state
            .ordered_contact_observations
            .iter_mut()
            .find(|entry| entry.contact_site_id == "rear_left_foot")
            .expect("rear-left contact");
        rear_left_contact.bears_support = Some(false);
        rear_left_contact.presence = Some(false);
        let d_controller = BalancedWaveController::new_for_policy(
            compile_bounded_quadruped(BoundedQuadrupedDescriptor::reference(
                BALANCED_WAVE_BW8U_D_POLICY_ID,
            ))
            .unwrap(),
            BALANCED_WAVE_BW8U_D_POLICY_ID,
        )
        .unwrap();
        let unloaded_output = d_controller.step(&loaded_memory, &loaded_state, &command(1));
        let unloaded_receipt = unloaded_output
            .actuation
            .receipt
            .release_gate_unweighting
            .as_ref()
            .expect("BW8U receipt");
        assert!(unloaded_receipt.ordered_knee_override_limb_ids.is_empty());
        assert!(unloaded_receipt.ordered_hip_override_limb_ids.is_empty());
        assert_eq!(target(&unloaded_output, "rear_left_hip_motor"), a_hip);
        assert_eq!(
            target(&unloaded_output, "rear_left_knee_motor"),
            a_knee - CONTACT_CLEARANCE_ASSIST_RAD
        );
    }

    #[test]
    fn balanced_wave_reference_anchor_guard_is_not_interaction_score_gated() {
        let legacy = controller();
        let balanced = balanced_controller();
        let mut current = state(&legacy, 0);
        for joint in &mut current.ordered_joint_observations {
            joint.anchor_error_m = Some(0.024);
        }

        let legacy_output = legacy.step(
            &Candidate35ControllerMemory::initial(),
            &current,
            &command(0),
        );
        let balanced_output = balanced.step(
            &BalancedWaveControllerMemory::initial(),
            &current,
            &command(0),
        );
        assert_eq!(legacy.compiled().morphology_interaction_score, 0.0);
        assert!(
            legacy_output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| {
                    command.maximum_target_speed_rad_s == CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S
                })
        );
        let guarded = balanced_output
            .actuation
            .ordered_commands
            .iter()
            .filter(|command| {
                command.maximum_target_speed_rad_s
                    < balanced
                        .profile()
                        .contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            })
            .collect::<Vec<_>>();
        assert_eq!(guarded.len(), 1);
        assert!(
            guarded[0].maximum_target_speed_rad_s
                >= balanced
                    .profile()
                    .anchor_error_guard_maximum_motor_target_speed_rad_s
        );
    }

    #[test]
    fn balanced_wave_wrong_memory_and_missing_observation_fail_closed() {
        let legacy = controller();
        let controller = balanced_controller();
        let mut wrong_memory = BalancedWaveControllerMemory::initial();
        wrong_memory.schema_version = CANDIDATE35_MEMORY_VERSION.to_owned();
        let wrong_output = controller.step(&wrong_memory, &state(&legacy, 0), &command(0));
        assert!(wrong_output.actuation.safe_no_actuation);
        assert_eq!(wrong_output.next_memory, wrong_memory);
        assert!(
            wrong_output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| command.target_velocity_rad_s == 0.0)
        );

        let memory = BalancedWaveControllerMemory::initial();
        let mut missing = state(&legacy, 0);
        missing.ordered_joint_observations[0].position_rad = None;
        missing.ordered_joint_observations[0].validity.position = false;
        let missing_output = controller.step(&memory, &missing, &command(0));
        assert!(missing_output.actuation.safe_no_actuation);
        assert_eq!(missing_output.next_memory, memory);
        assert!(
            missing_output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| command.target_velocity_rad_s == 0.0)
        );
    }

    #[test]
    fn balanced_wave_replay_is_byte_deterministic() {
        let legacy = controller();
        let controller = balanced_controller();
        let memory = BalancedWaveControllerMemory::initial();
        let current = state(&legacy, 0);
        let requested = command(0);
        let first = controller.step(&memory, &current, &requested);
        let second = controller.step(&memory, &current, &requested);
        assert_eq!(first, second);
        assert_eq!(
            serde_json::to_vec(&first).unwrap(),
            serde_json::to_vec(&second).unwrap()
        );
        assert_eq!(
            first.actuation.receipt_sha256,
            digest_serializable(&first.actuation.receipt).unwrap()
        );
    }

    #[test]
    fn anchor_guard_normalization_tracks_compiled_upper_leg_length() {
        let long = controller_with_upper_fraction("runtime_long_upper", 0.55);
        assert_eq!(
            MAXIMUM_ANCHOR_ERROR_UPPER_LEG_FRACTION * long.compiled().geometry.upper_length_m,
            0.14 * (0.35 * 0.55)
        );
        let mut long_state = state(&long, 0);
        for joint in &mut long_state.ordered_joint_observations {
            joint.anchor_error_m = Some(0.021);
        }
        let long_output = long.step(
            &Candidate35ControllerMemory::initial(),
            &long_state,
            &command(0),
        );
        assert!(
            long_output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| command.maximum_target_speed_rad_s == 3.5)
        );

        let short = controller_with_upper_fraction("runtime_short_upper", 0.48);
        let maximum_anchor_error_m =
            MAXIMUM_ANCHOR_ERROR_UPPER_LEG_FRACTION * short.compiled().geometry.upper_length_m;
        assert_eq!(maximum_anchor_error_m, 0.14 * (0.35 * 0.48));
        let mut short_state = state(&short, 0);
        for joint in &mut short_state.ordered_joint_observations {
            joint.anchor_error_m = Some(0.020);
        }
        let short_output = short.step(
            &Candidate35ControllerMemory::initial(),
            &short_state,
            &command(0),
        );
        let guard_progress = ((0.020 / maximum_anchor_error_m
            - short
                .compiled()
                .candidate35_profile
                .anchor_error_guard_activation_fraction)
            / (1.0
                - short
                    .compiled()
                    .candidate35_profile
                    .anchor_error_guard_activation_fraction))
            .clamp(0.0, 1.0);
        let expected_speed = lerp(
            CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S,
            short
                .compiled()
                .candidate35_profile
                .anchor_error_guard_maximum_motor_target_speed_rad_s,
            guard_progress * short.compiled().morphology_interaction_score,
        );
        let guarded_commands = short_output
            .actuation
            .ordered_commands
            .iter()
            .filter(|command| {
                command.maximum_target_speed_rad_s < CONTROLLER_MAXIMUM_TARGET_SPEED_RAD_S
            })
            .collect::<Vec<_>>();
        assert_eq!(guarded_commands.len(), 1);
        assert!((guarded_commands[0].maximum_target_speed_rad_s - expected_speed).abs() <= 1.0e-12);
    }

    #[test]
    fn invalid_or_missing_observation_returns_safe_ordered_zero_frame() {
        let controller = controller();
        let mut invalid_state = state(&controller, 0);
        invalid_state.ordered_joint_observations[0].position_rad = None;
        invalid_state.ordered_joint_observations[0]
            .validity
            .position = false;
        let output = controller.step(
            &Candidate35ControllerMemory::initial(),
            &invalid_state,
            &command(0),
        );
        assert!(output.actuation.safe_no_actuation);
        assert!(
            output
                .actuation
                .ordered_commands
                .iter()
                .all(|command| command.target_velocity_rad_s == 0.0)
        );
        assert_eq!(output.actuation.failure_codes, ["CAPABILITY_UNSUPPORTED"]);
    }

    #[test]
    fn expired_and_run_commands_fail_closed_without_advancing_memory() {
        let controller = controller();
        let memory = Candidate35ControllerMemory::initial();
        let mut expired = command(0);
        expired.valid_from_step = 0;
        expired.valid_through_step = 0;
        let expired_output = controller.step(&memory, &state(&controller, 1), &expired);
        assert!(expired_output.actuation.safe_no_actuation);
        assert_eq!(expired_output.next_memory, memory);

        let mut run = command(0);
        run.speed_class = SpeedClass::Run;
        let run_output = controller.step(&memory, &state(&controller, 0), &run);
        assert!(run_output.actuation.safe_no_actuation);
        assert_eq!(
            run_output.actuation.failure_codes,
            ["CAPABILITY_UNSUPPORTED"]
        );
    }

    #[test]
    fn contact_gate_holds_then_times_out_under_unsatisfied_bearing() {
        let controller = controller();
        let mut memory = Candidate35ControllerMemory::initial();
        memory.last_semantic_step = Some(53);
        memory.phase_progression_mode = Some(PhaseProgressionMode::ContactGated);
        memory.ordered_limb_memory[0].gait_step = 54;
        let mut current = state(&controller, 54);
        // rear_left is still bearing at its release gate, so its phase must hold.
        for _ in 0..3 {
            let output = controller.step(&memory, &current, &command(current.semantic_step));
            assert_eq!(output.next_memory.ordered_limb_memory[0].gait_step, 54);
            memory = output.next_memory;
            current.semantic_step += 1;
            current.sample_time_s = current.semantic_step as f64 / 120.0;
        }
        assert_eq!(memory.ordered_limb_memory[0].release_hold_step_count, 3);
    }

    #[test]
    fn clocked_warmup_advances_without_contact_gating_and_transitions_once() {
        let controller = controller();
        let mut memory = Candidate35ControllerMemory::initial();
        memory.last_semantic_step = Some(0);
        memory.phase_progression_mode = Some(PhaseProgressionMode::Clocked);
        for limb in &mut memory.ordered_limb_memory {
            limb.gait_step = 54;
        }
        let mut clocked_command = command(1);
        clocked_command.phase_progression_mode = PhaseProgressionMode::Clocked;

        let clocked = controller.step(&memory, &state(&controller, 1), &clocked_command);

        assert!(
            clocked
                .next_memory
                .ordered_limb_memory
                .iter()
                .all(|limb| limb.gait_step == 55)
        );
        let mut gated_command = command(2);
        gated_command.phase_progression_mode = PhaseProgressionMode::ContactGated;
        let transitioned =
            controller.step(&clocked.next_memory, &state(&controller, 2), &gated_command);
        assert!(
            transitioned
                .next_memory
                .ordered_limb_memory
                .iter()
                .all(|limb| limb.gait_step == 56)
        );
        assert_eq!(
            transitioned.next_memory.phase_progression_mode,
            Some(PhaseProgressionMode::ContactGated)
        );

        let mut exit_memory = transitioned.next_memory.clone();
        for limb in &mut exit_memory.ordered_limb_memory {
            limb.gait_step = RELEASE_GATE_LOCAL_STEP;
            limb.evidence_gait_step_limit = Some(RELEASE_GATE_LOCAL_STEP + 1);
        }
        exit_memory.ordered_limb_memory[0].evidence_gait_step_limit = Some(RELEASE_GATE_LOCAL_STEP);
        let mut cooldown_command = command(3);
        cooldown_command.phase_progression_mode = PhaseProgressionMode::Clocked;
        let cooldown_transition =
            controller.step(&exit_memory, &state(&controller, 3), &cooldown_command);
        assert_eq!(
            cooldown_transition
                .next_memory
                .ordered_limb_memory
                .iter()
                .map(|limb| limb.gait_step)
                .collect::<Vec<_>>(),
            vec![54, 55, 55, 54]
        );
        assert!(
            cooldown_transition
                .next_memory
                .ordered_limb_memory
                .iter()
                .all(|limb| limb.evidence_gait_step_limit.is_none())
        );
        assert_eq!(
            cooldown_transition.next_memory.phase_progression_mode,
            Some(PhaseProgressionMode::Clocked)
        );
    }

    #[test]
    fn completed_limb_freezes_at_its_explicit_evidence_horizon() {
        let controller = controller();
        let mut memory = Candidate35ControllerMemory::initial();
        memory.last_semantic_step = Some(0);
        for limb in &mut memory.ordered_limb_memory {
            limb.gait_step = 100;
        }
        memory.ordered_limb_memory[0].evidence_gait_step_limit = Some(100);

        let output = controller.step(&memory, &state(&controller, 1), &command(1));

        assert_eq!(output.next_memory.ordered_limb_memory[0].gait_step, 100);
        assert_eq!(output.next_memory.ordered_limb_memory[1].gait_step, 101);
    }
}
