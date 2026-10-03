use serde::{Deserialize, Serialize};

use crate::quadruped::{
    BoundedQuadrupedDescriptor, interaction_score, validate_bounded_quadruped_descriptor,
};
use crate::schema::{CoreError, Result};

pub const CANDIDATE35_POLICY_ID: &str = "g4_gq15_candidate35_v5";
pub const BALANCED_WAVE_POLICY_ID: &str = "sporespore_balanced_wave_v1";
pub const BALANCED_WAVE_BW2_B_POLICY_ID: &str = "sporespore_balanced_wave_bw2_b_v1";
pub const BALANCED_WAVE_BW2_C_POLICY_ID: &str = "sporespore_balanced_wave_bw2_c_v1";
pub const BALANCED_WAVE_BW2R_A_POLICY_ID: &str = "sporespore_balanced_wave_bw2r_a_v1";
pub const BALANCED_WAVE_BW2R_B_POLICY_ID: &str = "sporespore_balanced_wave_bw2r_b_v1";
pub const BALANCED_WAVE_BW2R_C_POLICY_ID: &str = "sporespore_balanced_wave_bw2r_c_v1";
pub const BALANCED_WAVE_BW4R_A_POLICY_ID: &str = "sporespore_balanced_wave_bw4r_a_v1";
pub const BALANCED_WAVE_BW4R_B_POLICY_ID: &str = "sporespore_balanced_wave_bw4r_b_v1";
pub const BALANCED_WAVE_BW5R_A_POLICY_ID: &str = "sporespore_balanced_wave_bw5r_a_v1";
pub const BALANCED_WAVE_BW5R_B_POLICY_ID: &str = "sporespore_balanced_wave_bw5r_b_v1";
pub const BALANCED_WAVE_BW5R_C_POLICY_ID: &str = "sporespore_balanced_wave_bw5r_c_v1";
pub const BALANCED_WAVE_BW7D_A_POLICY_ID: &str = "sporespore_balanced_wave_bw7d_a_v1";
pub const BALANCED_WAVE_BW7D_B_POLICY_ID: &str = "sporespore_balanced_wave_bw7d_b_v1";
pub const BALANCED_WAVE_BW7D_C_POLICY_ID: &str = "sporespore_balanced_wave_bw7d_c_v1";
pub const BALANCED_WAVE_BW7D_D_POLICY_ID: &str = "sporespore_balanced_wave_bw7d_d_v1";
pub const BALANCED_WAVE_BW8U_A_POLICY_ID: &str = "sporespore_balanced_wave_bw8u_a_v1";
pub const BALANCED_WAVE_BW8U_B_POLICY_ID: &str = "sporespore_balanced_wave_bw8u_b_v1";
pub const BALANCED_WAVE_BW8U_C_POLICY_ID: &str = "sporespore_balanced_wave_bw8u_c_v1";
pub const BALANCED_WAVE_BW8U_D_POLICY_ID: &str = "sporespore_balanced_wave_bw8u_d_v1";
pub const BALANCED_WAVE_BW14V_B_POLICY_ID: &str = "sporespore_balanced_wave_bw14v_b_v1";
pub const BALANCED_WAVE_BW15F_B_POLICY_ID: &str = "sporespore_balanced_wave_bw15f_b_v1";
pub const BALANCED_WAVE_BW15F_C_POLICY_ID: &str = "sporespore_balanced_wave_bw15f_c_v1";
pub const BALANCED_WAVE_BW15F_D_POLICY_ID: &str = "sporespore_balanced_wave_bw15f_d_v1";
pub const BALANCED_WAVE_BW21L_B_POLICY_ID: &str = "sporespore_balanced_wave_bw21l_b_v1";
pub const BALANCED_WAVE_BW21L_C_POLICY_ID: &str = "sporespore_balanced_wave_bw21l_c_v1";
pub const BALANCED_WAVE_BW21L_D_POLICY_ID: &str = "sporespore_balanced_wave_bw21l_d_v1";
pub const BALANCED_WAVE_BW23Y_B_POLICY_ID: &str = "sporespore_balanced_wave_bw23y_b_v1";
pub const BALANCED_WAVE_BW34Y_A_POLICY_ID: &str = "sporespore_balanced_wave_bw34y_a_v1";
pub const BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d19_heading_aligned_path_v1";
pub const BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1";
pub const BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d26_steering_cap_0p10_v1";
pub const BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d26_steering_cap_0p20_v1";
pub const BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d26_steering_cap_0p30_v1";
pub const BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d27_stability_guarded_steering_v1";
pub const BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d28_predictive_stability_guarded_steering_v1";
pub const BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1";
pub const SELECTED_BALANCED_WAVE_CANDIDATE_ID: &str = "BW5R-B";
pub const SELECTED_BALANCED_WAVE_POLICY_ID: &str = BALANCED_WAVE_BW5R_B_POLICY_ID;
pub const BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_swing_end_recontact_v1";
pub const BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_swing_end_recontact_profile_v1";
pub const SCHEDULED_SWING_END_RECONTACT_MODE_ID: &str = "scheduled_swing_end_recontact_v1";
pub const BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_bounded_support_v1";
pub const BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_bounded_support_profile_v1";
pub const BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_floor_support_v1";
pub const BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_floor_support_profile_v1";
pub const BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_feasible_support_v1";
pub const BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_feasible_support_profile_v1";
pub const BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_smooth_swing_v1";
pub const BALANCED_WAVE_RECOVERY_SMOOTH_SWING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_smooth_swing_profile_v1";
pub const PHASE_ONLY_LOADED_PEAK_SWING_LIFT_MODE_ID: &str =
    "phase_only_existing_loaded_peak_swing_lift_v1";
pub const BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_reference_velocity_v1";
pub const BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_reference_velocity_profile_v1";
pub const BOUNDED_REFERENCE_VELOCITY_MODE_ID: &str =
    "bounded_slewed_reference_velocity_tracking_v1";
pub const BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_wave_velocity_v1";
pub const BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_wave_velocity_profile_v1";
pub const BOUNDED_WAVE_VELOCITY_MODE_ID: &str =
    "bounded_pose_separated_wave_velocity_tracking_v1";
pub const BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_airborne_reference_v1";
pub const BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_airborne_reference_profile_v1";
pub const CONTACT_SELECTED_AIRBORNE_REFERENCE_MODE_ID: &str =
    "contact_selected_airborne_reference_velocity_tracking_v1";
pub const BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_absent_contact_reference_v1";
pub const BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_absent_contact_reference_profile_v1";
pub const CONTACT_SELECTED_ABSENT_CONTACT_REFERENCE_MODE_ID: &str =
    "contact_selected_absent_contact_reference_velocity_tracking_v1";
pub const BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_upright_stance_v1";
pub const BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_upright_stance_profile_v1";
pub const CONTACT_SELECTED_UPRIGHT_STANCE_MODE_ID: &str =
    "contact_selected_upright_stance_reference_velocity_tracking_v1";
pub const BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID: &str =
    "sporespore_balanced_wave_recovery_stance_latched_upright_v1";
pub const BALANCED_WAVE_RECOVERY_STANCE_LATCH_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_recovery_stance_latched_upright_profile_v1";
pub const STANCE_LATCHED_UPRIGHT_MODE_ID: &str =
    "stance_latched_upright_reference_velocity_tracking_v1";
pub const BALANCED_WAVE_PROFILE_VERSION: &str = "sporespore_balanced_wave_profile_v1";
pub const BALANCED_WAVE_CONTINUOUS_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_continuous_profile_v1";
pub const BALANCED_WAVE_FILTERED_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_filtered_profile_v1";
pub const BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_release_progress_profile_v1";
pub const BALANCED_WAVE_RELEASE_GATE_UNWEIGHTING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_release_gate_unweighting_profile_v1";
pub const BALANCED_WAVE_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_forward_velocity_foot_placement_profile_v1";
pub const BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_signed_forward_velocity_foot_placement_profile_v1";
pub const BALANCED_WAVE_BOUNDED_STEERING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_bounded_steering_profile_v1";
pub const BALANCED_WAVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_stability_guarded_steering_profile_v1";
pub const BALANCED_WAVE_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_predictive_stability_guarded_steering_profile_v1";
pub const BALANCED_WAVE_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION: &str =
    "sporespore_balanced_wave_persistent_predictive_stability_guarded_steering_profile_v1";
pub const RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID: &str = "reciprocal_steering_stride_transform_v1";
pub const RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID: &str =
    "release_gate_knee_swing_apex_target_v1";
pub const RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID: &str =
    "release_gate_hip_swing_apex_target_v1";
pub const FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID: &str = "forward_velocity_foot_placement_v1";
pub const DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID: &str =
    "desired_minus_measured_forward_velocity_error_v1";
pub const MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID: &str =
    "measured_minus_desired_forward_velocity_error_v1";
pub const COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID: &str =
    "command_heading_aligned_task_frame_v1";
pub const TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID: &str =
    "tilt_and_contact_steering_authority_guard_v1";
pub const PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID: &str =
    "predicted_tilt_and_contact_steering_authority_guard_v1";
pub const PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID: &str =
    "persistent_predicted_tilt_and_contact_steering_authority_guard_v1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Candidate35Profile {
    pub schema_version: String,
    pub policy_id: String,
    pub morphology_interaction_score: f64,
    pub cross_track_heading_gain_rad_per_m: f64,
    pub yaw_error_stride_gain_per_rad: f64,
    pub cross_track_velocity_heading_gain_rad_per_m_s: f64,
    pub contact_loaded_swing_knee_activation_start_phase_step: u32,
    pub contact_loaded_swing_knee_full_speed_override_phase_step: Option<u32>,
    pub contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: f64,
    pub anchor_error_guard_activation_fraction: f64,
    pub anchor_error_guard_maximum_motor_target_speed_rad_s: f64,
    pub controller_authority: bool,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BalancedWaveProfile {
    pub schema_version: String,
    pub policy_id: String,
    pub torso_length_scale: f64,
    pub cross_track_heading_gain_rad_per_m: f64,
    pub yaw_error_stride_gain_per_rad: f64,
    pub cross_track_velocity_heading_gain_rad_per_m_s: f64,
    pub contact_loaded_swing_knee_activation_start_phase_step: u32,
    pub contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: f64,
    pub anchor_error_guard_activation_fraction: f64,
    pub anchor_error_guard_maximum_motor_target_speed_rad_s: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub steering_feedback_update_interval_steps: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub maximum_steering_fraction_delta_per_step: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub steering_low_pass_time_constant_cycle_fraction: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub steering_stride_transform_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub release_gate_knee_target_mode_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub release_gate_hip_target_mode_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub forward_velocity_foot_placement_mode_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub maximum_forward_velocity_hip_target_correction_rad: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub forward_velocity_error_orientation_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cross_track_frame_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub maximum_steering_fraction: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_authority_guard_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub minimum_steering_fraction: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_full_authority_maximum_tilt_rad: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_minimum_authority_tilt_rad: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_minimum_support_contact_count: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_prediction_horizon_s: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub steering_guard_floor_hold_steps: Option<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recontact_gate_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stance_support_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub swing_lift_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reference_velocity_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_progression_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_hold_posture_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub measured_support_transfer_mode_id: Option<String>,
    pub branch_surfaces: Vec<String>,
    pub controller_authority: bool,
    pub physical_acceptance_authority: bool,
}

fn clamp01(value: f64) -> f64 {
    value.clamp(0.0, 1.0)
}

pub fn candidate35_yaw_gain(
    score: f64,
    torso_length_scale: f64,
    foot_radius_scale: f64,
    hip_span_scale: f64,
) -> f64 {
    if foot_radius_scale < 0.985 {
        return if score >= 0.9 { 1.3 } else { 1.1 };
    }
    if score < 0.5 || foot_radius_scale > 1.025 {
        return 1.0;
    }
    if foot_radius_scale > 1.01 {
        return 1.3;
    }
    if (hip_span_scale - 1.0).abs() >= 0.02 {
        return if torso_length_scale > 1.02 { 1.1 } else { 1.0 };
    }
    1.0
}

pub fn candidate34_velocity_gain(
    score: f64,
    torso_length_scale: f64,
    torso_width_scale: f64,
    foot_radius_scale: f64,
    yaw_gain_per_rad: f64,
) -> f64 {
    if yaw_gain_per_rad > 1.0 {
        let long_wide_gain_fraction =
            clamp01((torso_length_scale - 1.0) / 0.07) * clamp01((torso_width_scale - 1.0) / 0.06);
        let long_large_foot_gain_fraction =
            clamp01((torso_length_scale - 1.0) / 0.05) * clamp01((foot_radius_scale - 1.01) / 0.02);
        return 0.25 + 0.05 * long_wide_gain_fraction.max(long_large_foot_gain_fraction);
    }
    if score < 0.15 {
        if torso_width_scale <= 1.0 {
            let long_small_foot_gain_fraction = clamp01((torso_length_scale - 1.0) / 0.01)
                * clamp01((1.01 - foot_radius_scale) / 0.01);
            return 0.275 + 0.075 * long_small_foot_gain_fraction;
        }
        return 0.40;
    }
    if score < 0.5 {
        return if torso_width_scale <= 1.0 { 0.75 } else { 0.25 };
    }
    if torso_width_scale > 1.0 && torso_length_scale < 1.0 {
        return 0.25 - 0.05 * clamp01((score - 0.5) / 0.5);
    }
    if torso_width_scale <= 1.0 && torso_length_scale < 0.95 {
        return 0.35 + 0.10 * clamp01((1.0 - score) / 0.40);
    }
    0.35
}

pub fn candidate35_velocity_gain(
    score: f64,
    torso_length_scale: f64,
    torso_width_scale: f64,
    foot_radius_scale: f64,
    yaw_gain_per_rad: f64,
) -> f64 {
    if yaw_gain_per_rad <= 1.0
        && score >= 0.5
        && torso_length_scale < 1.0
        && torso_width_scale > 1.0
    {
        let interaction_fraction = clamp01((score - 0.5) / 0.5);
        let wide_fraction = clamp01((torso_width_scale - 1.02) / 0.04);
        return 0.25 + 0.025 * interaction_fraction + 0.025 * interaction_fraction * wide_fraction;
    }
    candidate34_velocity_gain(
        score,
        torso_length_scale,
        torso_width_scale,
        foot_radius_scale,
        yaw_gain_per_rad,
    )
}

pub fn candidate35_motor_guard(
    score: f64,
    torso_length_scale: f64,
    torso_width_scale: f64,
) -> (f64, f64) {
    if score >= 0.5 && torso_length_scale > 1.04 && !(0.95..=1.0).contains(&torso_width_scale) {
        return (0.70, 1.75);
    }
    if score >= 0.5 {
        (0.80, 2.0)
    } else {
        (0.90, 2.5)
    }
}

pub fn candidate35_profile(descriptor: &BoundedQuadrupedDescriptor) -> Result<Candidate35Profile> {
    validate_bounded_quadruped_descriptor(descriptor)?;
    let score = interaction_score(descriptor)?;
    let yaw_gain = candidate35_yaw_gain(
        score,
        descriptor.torso_length_scale,
        descriptor.foot_radius_scale,
        descriptor.hip_span_scale,
    );
    let velocity_gain = candidate35_velocity_gain(
        score,
        descriptor.torso_length_scale,
        descriptor.torso_width_scale,
        descriptor.foot_radius_scale,
        yaw_gain,
    );
    let (activation_fraction, maximum_speed) = candidate35_motor_guard(
        score,
        descriptor.torso_length_scale,
        descriptor.torso_width_scale,
    );
    Ok(Candidate35Profile {
        schema_version: "sporespore_candidate35_profile_v1".to_owned(),
        policy_id: CANDIDATE35_POLICY_ID.to_owned(),
        morphology_interaction_score: score,
        cross_track_heading_gain_rad_per_m: if score < 0.5 { 1.0 } else { 0.75 },
        yaw_error_stride_gain_per_rad: yaw_gain,
        cross_track_velocity_heading_gain_rad_per_m_s: velocity_gain,
        contact_loaded_swing_knee_activation_start_phase_step: 0,
        contact_loaded_swing_knee_full_speed_override_phase_step: None,
        contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: 3.5,
        anchor_error_guard_activation_fraction: activation_fraction,
        anchor_error_guard_maximum_motor_target_speed_rad_s: maximum_speed,
        controller_authority: true,
        physical_acceptance_authority: false,
    })
}

pub fn balanced_wave_profile(
    descriptor: &BoundedQuadrupedDescriptor,
) -> Result<BalancedWaveProfile> {
    balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_POLICY_ID)
}

pub fn balanced_wave_profile_for_policy(
    descriptor: &BoundedQuadrupedDescriptor,
    policy_id: &str,
) -> Result<BalancedWaveProfile> {
    validate_bounded_quadruped_descriptor(descriptor)?;
    if policy_id == crate::joint_pose_entry::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_BW5R_B_POLICY_ID)?;
        profile.schema_version = crate::joint_pose_entry::PROFILE.to_owned();
        profile.policy_id = policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_extended_preparation::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_initialized_zero_brake::POLICY)?;
        profile.schema_version=crate::recovery_extended_preparation::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_initialized_zero_brake::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_extended_support_transfer::POLICY)?;
        profile.schema_version=crate::recovery_initialized_zero_brake::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_zero_velocity_brake::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_extended_support_transfer::POLICY)?;
        profile.schema_version=crate::recovery_zero_velocity_brake::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_bounded_stop_velocity::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_extended_support_transfer::POLICY)?;
        profile.schema_version=crate::recovery_bounded_stop_velocity::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_extended_support_transfer::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_joint_feasible_height::POLICY)?;
        profile.schema_version=crate::recovery_extended_support_transfer::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_joint_feasible_height::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_anchored_body_pose::STARTUP_POLICY)?;
        profile.schema_version=crate::recovery_joint_feasible_height::PROFILE.to_owned();
        profile.policy_id=policy_id.to_owned();
        return Ok(profile);
    }
    if policy_id == crate::recovery_anchored_body_pose::STARTUP_POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_remaining_support_release::POLICY)?;
        profile.schema_version=crate::recovery_anchored_body_pose::STARTUP_PROFILE.to_owned();profile.policy_id=policy_id.to_owned();
        profile.reference_velocity_mode_id=Some(crate::recovery_anchored_body_pose::STARTUP_MODE.to_owned());return Ok(profile);
    }
    if policy_id == crate::recovery_remaining_support_release::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_advancing_body_origin::POLICY)?;
        profile.schema_version=crate::recovery_remaining_support_release::PROFILE.to_owned();profile.policy_id=policy_id.to_owned();
        profile.measured_support_transfer_mode_id=Some(crate::recovery_remaining_support_release::MODE.to_owned());return Ok(profile);
    }
    if policy_id == crate::recovery_advancing_body_origin::POLICY {
        let mut profile=balanced_wave_profile_for_policy(descriptor,crate::recovery_anchored_body_pose::POLICY)?;
        profile.schema_version=crate::recovery_advancing_body_origin::PROFILE.to_owned();profile.policy_id=policy_id.to_owned();return Ok(profile);
    }
    if policy_id == crate::recovery_anchored_body_pose::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, crate::recovery_measured_pose_support::POLICY)?;
        profile.schema_version=crate::recovery_anchored_body_pose::PROFILE.to_owned();profile.policy_id=policy_id.to_owned();
        profile.stance_support_mode_id=Some(crate::recovery_anchored_body_pose::MODE.to_owned());
        profile.reference_velocity_mode_id=Some("bounded_independent_pose_full_reference_velocity_v1".to_owned());
        profile.support_hold_posture_mode_id=Some("held_world_endpoint_reference_v1".to_owned());
        return Ok(profile);
    }
    if policy_id == crate::recovery_measured_pose_support::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, crate::recovery_measured_support_transfer::POLICY)?;
        profile.schema_version = crate::recovery_measured_pose_support::PROFILE.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(crate::recovery_measured_pose_support::MODE.to_owned());
        profile.support_hold_posture_mode_id = Some(crate::recovery_measured_pose_support::HOLD_MODE.to_owned());
        return Ok(profile);
    }
    if policy_id == crate::recovery_measured_support_transfer::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, crate::recovery_support_hold_posture::POLICY)?;
        profile.schema_version = crate::recovery_measured_support_transfer::PROFILE.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.measured_support_transfer_mode_id = Some(crate::recovery_measured_support_transfer::MODE.to_owned());
        return Ok(profile);
    }
    if policy_id == crate::recovery_support_hold_posture::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, crate::recovery_support_progression::POLICY)?;
        profile.schema_version = crate::recovery_support_hold_posture::PROFILE.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.support_hold_posture_mode_id = Some(crate::recovery_support_hold_posture::MODE.to_owned());
        return Ok(profile);
    }
    if policy_id == crate::recovery_support_progression::POLICY {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID)?;
        profile.schema_version = crate::recovery_support_progression::PROFILE.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.support_progression_mode_id = Some(crate::recovery_support_progression::MODE.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_STANCE_LATCH_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(STANCE_LATCHED_UPRIGHT_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(CONTACT_SELECTED_UPRIGHT_STANCE_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(CONTACT_SELECTED_ABSENT_CONTACT_REFERENCE_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(CONTACT_SELECTED_AIRBORNE_REFERENCE_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(BOUNDED_WAVE_VELOCITY_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.reference_velocity_mode_id = Some(BOUNDED_REFERENCE_VELOCITY_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_SMOOTH_SWING_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.swing_lift_mode_id = Some(PHASE_ONLY_LOADED_PEAK_SWING_LIFT_MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.stance_support_mode_id = Some(crate::recovery_floor_reference::MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.stance_support_mode_id = Some(crate::recovery_feasible_support::MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID {
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.stance_support_mode_id = Some(crate::recovery_support_plane::MODE_ID.to_owned());
        return Ok(profile);
    }
    if policy_id == BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID {
        // A distinct development identity, not a change to selected BW5R-B.
        // The runtime derives the new checkpoint from its existing swing end.
        let mut profile = balanced_wave_profile_for_policy(descriptor, BALANCED_WAVE_BW5R_B_POLICY_ID)?;
        profile.schema_version = BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_PROFILE_VERSION.to_owned();
        profile.policy_id = policy_id.to_owned();
        profile.recontact_gate_mode_id = Some(SCHEDULED_SWING_END_RECONTACT_MODE_ID.to_owned());
        return Ok(profile);
    }
    let torso_length_scale = descriptor.torso_length_scale;
    let (
        schema_version,
        velocity_gain,
        yaw_gain,
        knee_cap,
        anchor_fraction,
        anchor_cap,
        steering_feedback_update_interval_steps,
        maximum_steering_fraction_delta_per_step,
        steering_low_pass_time_constant_cycle_fraction,
        steering_stride_transform_id,
    ) = match policy_id {
        BALANCED_WAVE_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.30,
            1.0,
            3.25,
            0.85,
            2.25,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW2_B_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.275,
            1.0,
            3.50,
            0.90,
            2.50,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW2_C_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW2R_A_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.35,
            1.1,
            3.00,
            0.80,
            2.00,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW2R_B_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.35,
            1.2,
            3.00,
            0.80,
            2.00,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW2R_C_POLICY_ID => (
            BALANCED_WAVE_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            None,
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW4R_A_POLICY_ID => (
            BALANCED_WAVE_CONTINUOUS_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            None,
            None,
        ),
        BALANCED_WAVE_BW4R_B_POLICY_ID => (
            BALANCED_WAVE_CONTINUOUS_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            // A full -0.40 to +0.40 reversal remains possible within the
            // legacy 90-step sample-and-hold interval.
            Some(0.80 / 90.0),
            None,
            None,
        ),
        BALANCED_WAVE_BW5R_A_POLICY_ID => (
            BALANCED_WAVE_FILTERED_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 32.0),
            None,
        ),
        BALANCED_WAVE_BW5R_B_POLICY_ID => (
            BALANCED_WAVE_FILTERED_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        BALANCED_WAVE_BW5R_C_POLICY_ID => (
            BALANCED_WAVE_FILTERED_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 8.0),
            None,
        ),
        BALANCED_WAVE_BW7D_A_POLICY_ID => (
            BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION,
            0.35,
            1.3,
            3.25,
            0.85,
            2.25,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        BALANCED_WAVE_BW7D_B_POLICY_ID => (
            BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION,
            0.35,
            1.3,
            3.50,
            0.90,
            2.50,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        BALANCED_WAVE_BW7D_C_POLICY_ID => (
            BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION,
            0.35,
            1.3,
            3.25,
            0.85,
            2.25,
            Some(1),
            None,
            Some(1.0 / 16.0),
            Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID),
        ),
        BALANCED_WAVE_BW7D_D_POLICY_ID => (
            BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION,
            0.35,
            1.3,
            3.50,
            0.90,
            2.50,
            Some(1),
            None,
            Some(1.0 / 16.0),
            Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID),
        ),
        BALANCED_WAVE_BW8U_A_POLICY_ID
        | BALANCED_WAVE_BW8U_B_POLICY_ID
        | BALANCED_WAVE_BW8U_C_POLICY_ID
        | BALANCED_WAVE_BW8U_D_POLICY_ID => (
            BALANCED_WAVE_RELEASE_GATE_UNWEIGHTING_PROFILE_VERSION,
            0.35,
            1.3,
            3.50,
            0.90,
            2.50,
            Some(1),
            None,
            Some(1.0 / 16.0),
            Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID),
        ),
        BALANCED_WAVE_BW14V_B_POLICY_ID => (
            BALANCED_WAVE_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        BALANCED_WAVE_BW15F_B_POLICY_ID
        | BALANCED_WAVE_BW15F_C_POLICY_ID
        | BALANCED_WAVE_BW15F_D_POLICY_ID
        | BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // R23D21 preserves R23D19's heading-aligned path semantics and changes
        // only yaw-error-to-stride authority. The 1.0 level is the existing
        // BW23Y level, reused after R23D20 exposed saturated, oscillatory
        // reference-path feedback at 1.3 in retained Godot/Jolt traces.
        BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // R23D26 is an outcome-exposed Rapier development screen. Its three
        // portable candidates preserve R23D21 exactly except for a per-profile
        // steering cap at one, two, or three quarters of the inherited 0.40
        // global bound. The levels are geometric contract fractions, not fits
        // to an observed winning physical outcome.
        BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
        | BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
        | BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID => (
            BALANCED_WAVE_BOUNDED_STEERING_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // R23D27 starts from R23D26 cap 0.20 and permits bounded additional
        // authority only while direction-neutral torso-tilt and support-contact
        // observations say the body remains inside the declared guard. The
        // expanded 0.28 ceiling remains below the observed 0.30 fall level.
        BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => (
            BALANCED_WAVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // R23D28 is a post-outcome development successor to R23D27. It keeps
        // the same authority bounds and physical thresholds, but evaluates
        // them against one scheduler-swing-ahead tilt projected from the
        // canonical StateFrame orientation and world angular velocity.
        BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => (
            BALANCED_WAVE_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // R23D29 is the post-outcome development successor to R23D28. It
        // preserves the predictor, thresholds, and authority bounds while a
        // versioned controller-memory countdown keeps a reached floor active
        // for two scheduler swings (144 steps).
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
            (
                BALANCED_WAVE_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION,
                0.35,
                1.0,
                3.00,
                0.80,
                2.00,
                Some(1),
                None,
                Some(1.0 / 16.0),
                None,
            )
        }
        BALANCED_WAVE_BW21L_B_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        BALANCED_WAVE_BW21L_C_POLICY_ID | BALANCED_WAVE_BW21L_D_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.70,
            1.3,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // BW23Y-B is a development-only saturation-relief hypothesis. It
        // preserves BW15F-B's path objective and every other controller field,
        // changing only the yaw-error-to-stride authority from 1.3 to 1.0.
        BALANCED_WAVE_BW23Y_B_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            1.0,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        // BW34Y-A is the one-step continuation of BW23Y-B's development-only
        // yaw-authority reduction. BW33N-C moved both failed rough cells to a
        // sole lateral-corridor violation, so this candidate changes only the
        // yaw-error-to-stride gain from 1.0 to the preregistered 0.7 level.
        BALANCED_WAVE_BW34Y_A_POLICY_ID => (
            BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
            0.35,
            0.7,
            3.00,
            0.80,
            2.00,
            Some(1),
            None,
            Some(1.0 / 16.0),
            None,
        ),
        _ => {
            return Err(CoreError::Identity(format!(
                "balanced_wave_policy_id:{policy_id}"
            )));
        }
    };
    Ok(BalancedWaveProfile {
        schema_version: schema_version.to_owned(),
        policy_id: policy_id.to_owned(),
        torso_length_scale,
        cross_track_heading_gain_rad_per_m: match policy_id {
            BALANCED_WAVE_BW21L_B_POLICY_ID | BALANCED_WAVE_BW21L_D_POLICY_ID => {
                1.5 / torso_length_scale
            }
            _ => 1.0 / torso_length_scale,
        },
        yaw_error_stride_gain_per_rad: yaw_gain,
        cross_track_velocity_heading_gain_rad_per_m_s: velocity_gain * torso_length_scale.sqrt(),
        contact_loaded_swing_knee_activation_start_phase_step: 0,
        contact_loaded_swing_knee_maximum_motor_target_speed_rad_s: knee_cap,
        anchor_error_guard_activation_fraction: anchor_fraction,
        anchor_error_guard_maximum_motor_target_speed_rad_s: anchor_cap,
        steering_feedback_update_interval_steps,
        maximum_steering_fraction_delta_per_step,
        steering_low_pass_time_constant_cycle_fraction,
        steering_stride_transform_id: steering_stride_transform_id.map(str::to_owned),
        release_gate_knee_target_mode_id: match policy_id {
            BALANCED_WAVE_BW8U_B_POLICY_ID | BALANCED_WAVE_BW8U_D_POLICY_ID => {
                Some(RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID.to_owned())
            }
            _ => None,
        },
        release_gate_hip_target_mode_id: match policy_id {
            BALANCED_WAVE_BW8U_C_POLICY_ID | BALANCED_WAVE_BW8U_D_POLICY_ID => {
                Some(RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID.to_owned())
            }
            _ => None,
        },
        forward_velocity_foot_placement_mode_id: match policy_id {
            BALANCED_WAVE_BW14V_B_POLICY_ID
            | BALANCED_WAVE_BW15F_B_POLICY_ID
            | BALANCED_WAVE_BW15F_C_POLICY_ID
            | BALANCED_WAVE_BW15F_D_POLICY_ID
            | BALANCED_WAVE_BW21L_B_POLICY_ID
            | BALANCED_WAVE_BW21L_C_POLICY_ID
            | BALANCED_WAVE_BW21L_D_POLICY_ID
            | BALANCED_WAVE_BW23Y_B_POLICY_ID
            | BALANCED_WAVE_BW34Y_A_POLICY_ID
            | BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID
            | BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
            | BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID.to_owned())
            }
            _ => None,
        },
        maximum_forward_velocity_hip_target_correction_rad: match policy_id {
            // This is the existing lateral-wave hip excursion, reused as a
            // dimensionless cap rather than fitted to an exposed morphology.
            BALANCED_WAVE_BW14V_B_POLICY_ID => Some(0.30),
            // BW15F tests global sign and gain only. The 0.03-rad arms are one
            // tenth of the falsified BW14V cap; D doubles that same prospective
            // small-gain unit without introducing a morphology branch.
            BALANCED_WAVE_BW15F_B_POLICY_ID | BALANCED_WAVE_BW15F_C_POLICY_ID => Some(0.03),
            BALANCED_WAVE_BW15F_D_POLICY_ID => Some(0.06),
            BALANCED_WAVE_BW21L_B_POLICY_ID
            | BALANCED_WAVE_BW21L_C_POLICY_ID
            | BALANCED_WAVE_BW21L_D_POLICY_ID
            | BALANCED_WAVE_BW23Y_B_POLICY_ID
            | BALANCED_WAVE_BW34Y_A_POLICY_ID
            | BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID
            | BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
            | BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.03)
            }
            _ => None,
        },
        forward_velocity_error_orientation_id: match policy_id {
            BALANCED_WAVE_BW15F_B_POLICY_ID => {
                Some(DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID.to_owned())
            }
            BALANCED_WAVE_BW21L_B_POLICY_ID
            | BALANCED_WAVE_BW21L_C_POLICY_ID
            | BALANCED_WAVE_BW21L_D_POLICY_ID
            | BALANCED_WAVE_BW23Y_B_POLICY_ID
            | BALANCED_WAVE_BW34Y_A_POLICY_ID
            | BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID
            | BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
            | BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID.to_owned())
            }
            BALANCED_WAVE_BW15F_C_POLICY_ID | BALANCED_WAVE_BW15F_D_POLICY_ID => {
                Some(MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID.to_owned())
            }
            _ => None,
        },
        cross_track_frame_mode_id: match policy_id {
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID
            | BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
            | BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
            | BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            | BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID.to_owned())
            }
            _ => None,
        },
        maximum_steering_fraction: match policy_id {
            BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID => Some(0.10),
            BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID => Some(0.20),
            BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID => Some(0.30),
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.28),
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.28),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.28)
            }
            _ => None,
        },
        steering_authority_guard_mode_id: match policy_id {
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID.to_owned())
            }
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID.to_owned())
            }
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(
                    PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID
                        .to_owned(),
                )
            }
            _ => None,
        },
        minimum_steering_fraction: match policy_id {
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.20),
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.20),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.20)
            }
            _ => None,
        },
        steering_guard_full_authority_maximum_tilt_rad: match policy_id {
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.10),
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.10),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.10)
            }
            _ => None,
        },
        steering_guard_minimum_authority_tilt_rad: match policy_id {
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.20),
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.20),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.20)
            }
            _ => None,
        },
        steering_guard_minimum_support_contact_count: match policy_id {
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID => Some(2),
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(2),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(2)
            }
            _ => None,
        },
        steering_guard_prediction_horizon_s: match policy_id {
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => Some(0.6),
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(0.6)
            }
            _ => None,
        },
        steering_guard_floor_hold_steps: match policy_id {
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID => {
                Some(144)
            }
            _ => None,
        },
        branch_surfaces: vec![],
        recontact_gate_mode_id: None,
        stance_support_mode_id: None,
        swing_lift_mode_id: None,
        reference_velocity_mode_id: None,
        support_progression_mode_id: None,
        support_hold_posture_mode_id: None,
        measured_support_transfer_mode_id: None,
        controller_authority: true,
        physical_acceptance_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::canonical::digest_serializable;
    use crate::quadruped::{BOUNDED_QUADRUPED_DESCRIPTOR_VERSION, REFERENCE_UPPER_LENGTH_FRACTION};
    use serde::Deserialize;

    #[derive(Deserialize)]
    struct GoldenFile {
        schema_version: String,
        oracle_source_commit: String,
        oracle_path: String,
        tolerance: f64,
        interaction_vectors: Vec<GoldenInteractionVector>,
        controller_vectors: Vec<GoldenControllerVector>,
    }

    #[derive(Deserialize)]
    struct GoldenInteractionVector {
        vector_id: String,
        scales: [f64; 6],
        expected_score: f64,
    }

    #[derive(Deserialize)]
    struct GoldenControllerVector {
        vector_id: String,
        score: f64,
        torso_length_scale: f64,
        torso_width_scale: f64,
        foot_radius_scale: f64,
        hip_span_scale: f64,
        expected: [f64; 5],
    }

    fn descriptor(
        length: f64,
        width: f64,
        upper: f64,
        hip: f64,
        foot: f64,
        mass: f64,
    ) -> BoundedQuadrupedDescriptor {
        BoundedQuadrupedDescriptor {
            schema_version: BOUNDED_QUADRUPED_DESCRIPTOR_VERSION.to_owned(),
            morphology_id: "controller_case".to_owned(),
            torso_length_scale: length,
            torso_width_scale: width,
            upper_length_fraction: upper,
            hip_span_scale: hip,
            foot_radius_scale: foot,
            front_limb_mass_scale: mass,
        }
    }

    #[test]
    fn reference_profile_matches_oracle() {
        let profile = candidate35_profile(&descriptor(
            1.0,
            1.0,
            REFERENCE_UPPER_LENGTH_FRACTION,
            1.0,
            1.0,
            1.0,
        ))
        .unwrap();
        assert_eq!(profile.morphology_interaction_score, 0.0);
        assert_eq!(profile.cross_track_heading_gain_rad_per_m, 1.0);
        assert_eq!(profile.yaw_error_stride_gain_per_rad, 1.0);
        assert_eq!(profile.cross_track_velocity_heading_gain_rad_per_m_s, 0.275);
        assert_eq!(
            (
                profile.anchor_error_guard_activation_fraction,
                profile.anchor_error_guard_maximum_motor_target_speed_rad_s
            ),
            (0.90, 2.5)
        );
    }

    #[test]
    fn balanced_wave_reference_and_domain_boundaries_are_exact() {
        let reference = balanced_wave_profile(&descriptor(
            1.0,
            1.0,
            REFERENCE_UPPER_LENGTH_FRACTION,
            1.0,
            1.0,
            1.0,
        ))
        .unwrap();
        assert_eq!(reference.schema_version, BALANCED_WAVE_PROFILE_VERSION);
        assert_eq!(reference.policy_id, BALANCED_WAVE_POLICY_ID);
        assert_eq!(reference.cross_track_heading_gain_rad_per_m, 1.0);
        assert_eq!(
            reference.cross_track_velocity_heading_gain_rad_per_m_s,
            0.30
        );
        assert_eq!(reference.yaw_error_stride_gain_per_rad, 1.0);
        assert_eq!(
            reference.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
            3.25
        );
        assert_eq!(reference.anchor_error_guard_activation_fraction, 0.85);
        assert_eq!(
            reference.anchor_error_guard_maximum_motor_target_speed_rad_s,
            2.25
        );
        assert!(reference.branch_surfaces.is_empty());
        assert!(reference.controller_authority);
        assert!(!reference.physical_acceptance_authority);

        let lower = balanced_wave_profile(&descriptor(
            0.90,
            1.0,
            REFERENCE_UPPER_LENGTH_FRACTION,
            1.0,
            1.0,
            1.0,
        ))
        .unwrap();
        let upper = balanced_wave_profile(&descriptor(
            1.10,
            1.0,
            REFERENCE_UPPER_LENGTH_FRACTION,
            1.0,
            1.0,
            1.0,
        ))
        .unwrap();
        assert_eq!(lower.cross_track_heading_gain_rad_per_m, 1.0 / 0.90);
        assert_eq!(upper.cross_track_heading_gain_rad_per_m, 1.0 / 1.10);
        assert_eq!(
            lower.cross_track_velocity_heading_gain_rad_per_m_s,
            0.30 * 0.90_f64.sqrt()
        );
        assert_eq!(
            upper.cross_track_velocity_heading_gain_rad_per_m_s,
            0.30 * 1.10_f64.sqrt()
        );
    }

    #[test]
    fn frozen_bw2_policy_profiles_are_exact_and_unknown_ids_fail_closed() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let cases = [
            (BALANCED_WAVE_POLICY_ID, 0.30, 1.0, 3.25, 0.85, 2.25),
            (BALANCED_WAVE_BW2_B_POLICY_ID, 0.275, 1.0, 3.50, 0.90, 2.50),
            (BALANCED_WAVE_BW2_C_POLICY_ID, 0.35, 1.0, 3.00, 0.80, 2.00),
            (BALANCED_WAVE_BW2R_A_POLICY_ID, 0.35, 1.1, 3.00, 0.80, 2.00),
            (BALANCED_WAVE_BW2R_B_POLICY_ID, 0.35, 1.2, 3.00, 0.80, 2.00),
            (BALANCED_WAVE_BW2R_C_POLICY_ID, 0.35, 1.3, 3.00, 0.80, 2.00),
        ];
        for (policy_id, velocity_gain, yaw_gain, knee_cap, anchor_fraction, anchor_cap) in cases {
            let profile = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(profile.policy_id, policy_id);
            assert_eq!(
                profile.cross_track_velocity_heading_gain_rad_per_m_s,
                velocity_gain
            );
            assert_eq!(profile.yaw_error_stride_gain_per_rad, yaw_gain);
            assert_eq!(
                profile.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                knee_cap
            );
            assert_eq!(
                profile.anchor_error_guard_activation_fraction,
                anchor_fraction
            );
            assert_eq!(
                profile.anchor_error_guard_maximum_motor_target_speed_rad_s,
                anchor_cap
            );
            assert_eq!(profile.schema_version, BALANCED_WAVE_PROFILE_VERSION);
            assert_eq!(profile.steering_feedback_update_interval_steps, None);
            assert_eq!(profile.maximum_steering_fraction_delta_per_step, None);
            assert_eq!(profile.steering_low_pass_time_constant_cycle_fraction, None);
            assert_eq!(profile.steering_stride_transform_id, None);
            assert!(profile.branch_surfaces.is_empty());
        }
        assert!(matches!(
            balanced_wave_profile_for_policy(&reference, "unknown_balanced_wave"),
            Err(CoreError::Identity(_))
        ));

        let selected: serde_json::Value =
            serde_json::from_str(include_str!("../../balanced_wave_selected_policy.json")).unwrap();
        assert_eq!(
            selected["schema_version"],
            "sporespore_balanced_wave_selected_policy_v1"
        );
        assert_eq!(
            selected["status"],
            "frozen_after_bw5r_development_before_new_validation"
        );
        assert_eq!(
            selected["selected_candidate_id"],
            SELECTED_BALANCED_WAVE_CANDIDATE_ID
        );
        assert_eq!(
            selected["selected_policy_id"],
            SELECTED_BALANCED_WAVE_POLICY_ID
        );
        assert_eq!(
            selected["selected_candidate_policy_digest"],
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        );
        assert_eq!(
            selected["selection_report"]["deciding_metric"],
            "all_opened_nonzero_material_treatment_nonwalk_count"
        );
        assert_eq!(selected["selection_report"]["early_stop_triggered"], false);
        assert_eq!(selected["claims"]["physical_acceptance_authority"], false);
    }

    #[test]
    fn frozen_bw4r_profiles_change_only_continuous_feedback_timing() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW2R_C_POLICY_ID).unwrap();
        let direct =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW4R_A_POLICY_ID).unwrap();
        let slew =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW4R_B_POLICY_ID).unwrap();

        for successor in [&direct, &slew] {
            assert_eq!(
                successor.schema_version,
                BALANCED_WAVE_CONTINUOUS_PROFILE_VERSION
            );
            assert_eq!(
                successor.cross_track_heading_gain_rad_per_m,
                parent.cross_track_heading_gain_rad_per_m
            );
            assert_eq!(
                successor.yaw_error_stride_gain_per_rad,
                parent.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                successor.cross_track_velocity_heading_gain_rad_per_m_s,
                parent.cross_track_velocity_heading_gain_rad_per_m_s
            );
            assert_eq!(
                successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                parent.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.anchor_error_guard_activation_fraction,
                parent.anchor_error_guard_activation_fraction
            );
            assert_eq!(
                successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
                parent.anchor_error_guard_maximum_motor_target_speed_rad_s
            );
            assert_eq!(successor.steering_feedback_update_interval_steps, Some(1));
            assert!(successor.branch_surfaces.is_empty());
        }
        assert_eq!(direct.maximum_steering_fraction_delta_per_step, None);
        assert_eq!(direct.steering_low_pass_time_constant_cycle_fraction, None);
        assert_eq!(
            slew.maximum_steering_fraction_delta_per_step,
            Some(0.80 / 90.0)
        );
        assert_eq!(slew.steering_low_pass_time_constant_cycle_fraction, None);
        assert_eq!(
            digest_serializable(&parent).unwrap(),
            "sha256:a626c6478b4ac3fa1fb214c3cd09e68b5033f939c276dfb2bae679faa3085f2a"
        );
        assert_ne!(
            digest_serializable(&direct).unwrap(),
            digest_serializable(&parent).unwrap()
        );
        assert_ne!(
            digest_serializable(&slew).unwrap(),
            digest_serializable(&direct).unwrap()
        );
    }

    #[test]
    fn frozen_bw5r_profiles_change_only_cycle_normalized_filter_time_constant() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW2R_C_POLICY_ID).unwrap();
        let cases = [
            (BALANCED_WAVE_BW5R_A_POLICY_ID, 1.0 / 32.0),
            (BALANCED_WAVE_BW5R_B_POLICY_ID, 1.0 / 16.0),
            (BALANCED_WAVE_BW5R_C_POLICY_ID, 1.0 / 8.0),
        ];

        for (policy_id, expected_time_constant) in cases {
            let successor = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(
                successor.schema_version,
                BALANCED_WAVE_FILTERED_PROFILE_VERSION
            );
            assert_eq!(
                successor.cross_track_heading_gain_rad_per_m,
                parent.cross_track_heading_gain_rad_per_m
            );
            assert_eq!(
                successor.yaw_error_stride_gain_per_rad,
                parent.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                successor.cross_track_velocity_heading_gain_rad_per_m_s,
                parent.cross_track_velocity_heading_gain_rad_per_m_s
            );
            assert_eq!(
                successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                parent.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.anchor_error_guard_activation_fraction,
                parent.anchor_error_guard_activation_fraction
            );
            assert_eq!(
                successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
                parent.anchor_error_guard_maximum_motor_target_speed_rad_s
            );
            assert_eq!(successor.steering_feedback_update_interval_steps, Some(1));
            assert_eq!(successor.maximum_steering_fraction_delta_per_step, None);
            assert_eq!(
                successor.steering_low_pass_time_constant_cycle_fraction,
                Some(expected_time_constant)
            );
            assert_eq!(successor.steering_stride_transform_id, None);
            assert!(successor.branch_surfaces.is_empty());
        }
    }

    #[test]
    fn prospective_bw7d_profiles_form_a_branch_free_two_by_two_mechanism_family() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW5R_B_POLICY_ID).unwrap();
        let cases = [
            (BALANCED_WAVE_BW7D_A_POLICY_ID, 3.25, 0.85, 2.25, None),
            (BALANCED_WAVE_BW7D_B_POLICY_ID, 3.50, 0.90, 2.50, None),
            (
                BALANCED_WAVE_BW7D_C_POLICY_ID,
                3.25,
                0.85,
                2.25,
                Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID),
            ),
            (
                BALANCED_WAVE_BW7D_D_POLICY_ID,
                3.50,
                0.90,
                2.50,
                Some(RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID),
            ),
        ];

        for (policy_id, knee_cap, anchor_fraction, anchor_cap, transform_id) in cases {
            let successor = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(
                successor.schema_version,
                BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION
            );
            assert_eq!(
                successor.cross_track_heading_gain_rad_per_m,
                parent.cross_track_heading_gain_rad_per_m
            );
            assert_eq!(
                successor.yaw_error_stride_gain_per_rad,
                parent.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                successor.cross_track_velocity_heading_gain_rad_per_m_s,
                parent.cross_track_velocity_heading_gain_rad_per_m_s
            );
            assert_eq!(
                successor.steering_low_pass_time_constant_cycle_fraction,
                parent.steering_low_pass_time_constant_cycle_fraction
            );
            assert_eq!(
                successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                knee_cap
            );
            assert_eq!(
                successor.anchor_error_guard_activation_fraction,
                anchor_fraction
            );
            assert_eq!(
                successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
                anchor_cap
            );
            assert_eq!(
                successor.steering_stride_transform_id.as_deref(),
                transform_id
            );
            assert!(successor.branch_surfaces.is_empty());
        }
    }

    #[test]
    fn prospective_bw8u_profiles_form_a_branch_free_two_by_two_unweighting_family() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW7D_D_POLICY_ID).unwrap();
        let cases = [
            (BALANCED_WAVE_BW8U_A_POLICY_ID, None, None),
            (
                BALANCED_WAVE_BW8U_B_POLICY_ID,
                Some(RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID),
                None,
            ),
            (
                BALANCED_WAVE_BW8U_C_POLICY_ID,
                None,
                Some(RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID),
            ),
            (
                BALANCED_WAVE_BW8U_D_POLICY_ID,
                Some(RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID),
                Some(RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID),
            ),
        ];

        for (policy_id, knee_mode_id, hip_mode_id) in cases {
            let successor = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(
                successor.schema_version,
                BALANCED_WAVE_RELEASE_GATE_UNWEIGHTING_PROFILE_VERSION
            );
            assert_eq!(
                successor.cross_track_heading_gain_rad_per_m,
                parent.cross_track_heading_gain_rad_per_m
            );
            assert_eq!(
                successor.yaw_error_stride_gain_per_rad,
                parent.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                successor.cross_track_velocity_heading_gain_rad_per_m_s,
                parent.cross_track_velocity_heading_gain_rad_per_m_s
            );
            assert_eq!(
                successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                parent.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.anchor_error_guard_activation_fraction,
                parent.anchor_error_guard_activation_fraction
            );
            assert_eq!(
                successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
                parent.anchor_error_guard_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.steering_feedback_update_interval_steps,
                parent.steering_feedback_update_interval_steps
            );
            assert_eq!(
                successor.maximum_steering_fraction_delta_per_step,
                parent.maximum_steering_fraction_delta_per_step
            );
            assert_eq!(
                successor.steering_low_pass_time_constant_cycle_fraction,
                parent.steering_low_pass_time_constant_cycle_fraction
            );
            assert_eq!(
                successor.steering_stride_transform_id,
                parent.steering_stride_transform_id
            );
            assert_eq!(
                successor.release_gate_knee_target_mode_id.as_deref(),
                knee_mode_id
            );
            assert_eq!(
                successor.release_gate_hip_target_mode_id.as_deref(),
                hip_mode_id
            );
            assert!(successor.branch_surfaces.is_empty());
            assert!(successor.controller_authority);
            assert!(!successor.physical_acceptance_authority);
        }
        assert_eq!(parent.release_gate_knee_target_mode_id, None);
        assert_eq!(parent.release_gate_hip_target_mode_id, None);
    }

    #[test]
    fn prospective_bw14v_b_changes_only_branch_free_forward_velocity_foot_placement() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW5R_B_POLICY_ID).unwrap();
        let successor =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW14V_B_POLICY_ID).unwrap();

        assert_eq!(
            successor.schema_version,
            BALANCED_WAVE_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION
        );
        assert_eq!(
            successor.cross_track_heading_gain_rad_per_m,
            parent.cross_track_heading_gain_rad_per_m
        );
        assert_eq!(
            successor.yaw_error_stride_gain_per_rad,
            parent.yaw_error_stride_gain_per_rad
        );
        assert_eq!(
            successor.cross_track_velocity_heading_gain_rad_per_m_s,
            parent.cross_track_velocity_heading_gain_rad_per_m_s
        );
        assert_eq!(
            successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
            parent.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
        );
        assert_eq!(
            successor.anchor_error_guard_activation_fraction,
            parent.anchor_error_guard_activation_fraction
        );
        assert_eq!(
            successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
            parent.anchor_error_guard_maximum_motor_target_speed_rad_s
        );
        assert_eq!(
            successor.steering_feedback_update_interval_steps,
            parent.steering_feedback_update_interval_steps
        );
        assert_eq!(
            successor.maximum_steering_fraction_delta_per_step,
            parent.maximum_steering_fraction_delta_per_step
        );
        assert_eq!(
            successor.steering_low_pass_time_constant_cycle_fraction,
            parent.steering_low_pass_time_constant_cycle_fraction
        );
        assert_eq!(
            successor.steering_stride_transform_id,
            parent.steering_stride_transform_id
        );
        assert_eq!(
            successor.forward_velocity_foot_placement_mode_id.as_deref(),
            Some(FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID)
        );
        assert_eq!(
            successor.maximum_forward_velocity_hip_target_correction_rad,
            Some(0.30)
        );
        assert_eq!(successor.forward_velocity_error_orientation_id, None);
        assert_eq!(successor.release_gate_knee_target_mode_id, None);
        assert_eq!(successor.release_gate_hip_target_mode_id, None);
        assert!(successor.branch_surfaces.is_empty());
        assert!(successor.controller_authority);
        assert!(!successor.physical_acceptance_authority);
    }

    #[test]
    fn prospective_bw15f_is_a_branch_free_global_sign_and_gain_factorial() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW5R_B_POLICY_ID).unwrap();
        let cases = [
            (
                BALANCED_WAVE_BW15F_B_POLICY_ID,
                0.03,
                DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
            ),
            (
                BALANCED_WAVE_BW15F_C_POLICY_ID,
                0.03,
                MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
            ),
            (
                BALANCED_WAVE_BW15F_D_POLICY_ID,
                0.06,
                MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
            ),
        ];

        for (policy_id, maximum_correction, orientation_id) in cases {
            let successor = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(
                successor.schema_version,
                BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION
            );
            assert_eq!(
                successor.cross_track_heading_gain_rad_per_m,
                parent.cross_track_heading_gain_rad_per_m
            );
            assert_eq!(
                successor.yaw_error_stride_gain_per_rad,
                parent.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                successor.cross_track_velocity_heading_gain_rad_per_m_s,
                parent.cross_track_velocity_heading_gain_rad_per_m_s
            );
            assert_eq!(
                successor.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                parent.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.anchor_error_guard_activation_fraction,
                parent.anchor_error_guard_activation_fraction
            );
            assert_eq!(
                successor.anchor_error_guard_maximum_motor_target_speed_rad_s,
                parent.anchor_error_guard_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                successor.steering_feedback_update_interval_steps,
                parent.steering_feedback_update_interval_steps
            );
            assert_eq!(
                successor.maximum_steering_fraction_delta_per_step,
                parent.maximum_steering_fraction_delta_per_step
            );
            assert_eq!(
                successor.steering_low_pass_time_constant_cycle_fraction,
                parent.steering_low_pass_time_constant_cycle_fraction
            );
            assert_eq!(
                successor.steering_stride_transform_id,
                parent.steering_stride_transform_id
            );
            assert_eq!(
                successor.forward_velocity_foot_placement_mode_id.as_deref(),
                Some(FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID)
            );
            assert_eq!(
                successor.maximum_forward_velocity_hip_target_correction_rad,
                Some(maximum_correction)
            );
            assert_eq!(
                successor.forward_velocity_error_orientation_id.as_deref(),
                Some(orientation_id)
            );
            assert_eq!(successor.release_gate_knee_target_mode_id, None);
            assert_eq!(successor.release_gate_hip_target_mode_id, None);
            assert!(successor.branch_surfaces.is_empty());
            assert!(successor.controller_authority);
            assert!(!successor.physical_acceptance_authority);
        }
    }

    #[test]
    fn prospective_bw21l_is_a_branch_free_cross_track_gain_factorial() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let baseline =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW15F_B_POLICY_ID).unwrap();
        let cases = [
            (BALANCED_WAVE_BW21L_B_POLICY_ID, 1.5, 0.35),
            (BALANCED_WAVE_BW21L_C_POLICY_ID, 1.0, 0.70),
            (BALANCED_WAVE_BW21L_D_POLICY_ID, 1.5, 0.70),
        ];

        for (policy_id, expected_heading_gain, expected_velocity_gain) in cases {
            let candidate = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            assert_eq!(
                candidate.schema_version,
                BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION
            );
            assert_eq!(
                candidate.cross_track_heading_gain_rad_per_m,
                expected_heading_gain
            );
            assert_eq!(
                candidate.cross_track_velocity_heading_gain_rad_per_m_s,
                expected_velocity_gain
            );
            assert_eq!(
                candidate.yaw_error_stride_gain_per_rad,
                baseline.yaw_error_stride_gain_per_rad
            );
            assert_eq!(
                candidate.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                baseline.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                candidate.anchor_error_guard_activation_fraction,
                baseline.anchor_error_guard_activation_fraction
            );
            assert_eq!(
                candidate.anchor_error_guard_maximum_motor_target_speed_rad_s,
                baseline.anchor_error_guard_maximum_motor_target_speed_rad_s
            );
            assert_eq!(
                candidate.steering_feedback_update_interval_steps,
                baseline.steering_feedback_update_interval_steps
            );
            assert_eq!(
                candidate.maximum_steering_fraction_delta_per_step,
                baseline.maximum_steering_fraction_delta_per_step
            );
            assert_eq!(
                candidate.steering_low_pass_time_constant_cycle_fraction,
                baseline.steering_low_pass_time_constant_cycle_fraction
            );
            assert_eq!(
                candidate.steering_stride_transform_id,
                baseline.steering_stride_transform_id
            );
            assert_eq!(
                candidate.forward_velocity_foot_placement_mode_id,
                baseline.forward_velocity_foot_placement_mode_id
            );
            assert_eq!(
                candidate.maximum_forward_velocity_hip_target_correction_rad,
                baseline.maximum_forward_velocity_hip_target_correction_rad
            );
            assert_eq!(
                candidate.forward_velocity_error_orientation_id,
                baseline.forward_velocity_error_orientation_id
            );
            assert_eq!(candidate.release_gate_knee_target_mode_id, None);
            assert_eq!(candidate.release_gate_hip_target_mode_id, None);
            assert!(candidate.branch_surfaces.is_empty());
            assert!(candidate.controller_authority);
            assert!(!candidate.physical_acceptance_authority);
        }
    }

    #[test]
    fn bw23y_b_changes_only_yaw_error_stride_authority_from_bw15f_b() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let baseline =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW15F_B_POLICY_ID).unwrap();
        let candidate =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW23Y_B_POLICY_ID).unwrap();

        let mut baseline_value = serde_json::to_value(&baseline).unwrap();
        let mut candidate_value = serde_json::to_value(&candidate).unwrap();
        let baseline_object = baseline_value.as_object_mut().unwrap();
        let candidate_object = candidate_value.as_object_mut().unwrap();
        assert_eq!(
            baseline_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_BW15F_B_POLICY_ID)
        );
        assert_eq!(
            candidate_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_BW23Y_B_POLICY_ID)
        );
        assert_eq!(
            baseline_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(1.3)
        );
        assert_eq!(
            candidate_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(1.0)
        );
        assert_eq!(
            baseline_value, candidate_value,
            "BW23Y-B must differ from BW15F-B only in policy identity and yaw-error stride authority"
        );

        assert_eq!(candidate.schema_version, baseline.schema_version);
        assert_eq!(
            candidate.cross_track_heading_gain_rad_per_m,
            baseline.cross_track_heading_gain_rad_per_m
        );
        assert_eq!(
            candidate.cross_track_velocity_heading_gain_rad_per_m_s,
            baseline.cross_track_velocity_heading_gain_rad_per_m_s
        );
        assert_eq!(candidate.yaw_error_stride_gain_per_rad, 1.0);
        assert_eq!(baseline.yaw_error_stride_gain_per_rad, 1.3);
        assert_eq!(
            candidate.contact_loaded_swing_knee_activation_start_phase_step,
            baseline.contact_loaded_swing_knee_activation_start_phase_step
        );
        assert_eq!(
            candidate.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
            baseline.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s
        );
        assert_eq!(
            candidate.anchor_error_guard_activation_fraction,
            baseline.anchor_error_guard_activation_fraction
        );
        assert_eq!(
            candidate.anchor_error_guard_maximum_motor_target_speed_rad_s,
            baseline.anchor_error_guard_maximum_motor_target_speed_rad_s
        );
        assert_eq!(
            candidate.steering_feedback_update_interval_steps,
            baseline.steering_feedback_update_interval_steps
        );
        assert_eq!(
            candidate.maximum_steering_fraction_delta_per_step,
            baseline.maximum_steering_fraction_delta_per_step
        );
        assert_eq!(
            candidate.steering_low_pass_time_constant_cycle_fraction,
            baseline.steering_low_pass_time_constant_cycle_fraction
        );
        assert_eq!(
            candidate.steering_stride_transform_id,
            baseline.steering_stride_transform_id
        );
        assert_eq!(
            candidate.release_gate_knee_target_mode_id,
            baseline.release_gate_knee_target_mode_id
        );
        assert_eq!(
            candidate.release_gate_hip_target_mode_id,
            baseline.release_gate_hip_target_mode_id
        );
        assert_eq!(
            candidate.forward_velocity_foot_placement_mode_id,
            baseline.forward_velocity_foot_placement_mode_id
        );
        assert_eq!(
            candidate.maximum_forward_velocity_hip_target_correction_rad,
            baseline.maximum_forward_velocity_hip_target_correction_rad
        );
        assert_eq!(
            candidate.forward_velocity_error_orientation_id,
            baseline.forward_velocity_error_orientation_id
        );
        assert!(candidate.branch_surfaces.is_empty());
        assert!(candidate.controller_authority);
        assert!(!candidate.physical_acceptance_authority);
    }

    #[test]
    fn bw34y_a_changes_only_yaw_error_stride_authority_from_bw23y_b() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let baseline =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW23Y_B_POLICY_ID).unwrap();
        let candidate =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW34Y_A_POLICY_ID).unwrap();

        let mut baseline_value = serde_json::to_value(&baseline).unwrap();
        let mut candidate_value = serde_json::to_value(&candidate).unwrap();
        let baseline_object = baseline_value.as_object_mut().unwrap();
        let candidate_object = candidate_value.as_object_mut().unwrap();
        assert_eq!(
            baseline_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_BW23Y_B_POLICY_ID)
        );
        assert_eq!(
            candidate_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_BW34Y_A_POLICY_ID)
        );
        assert_eq!(
            baseline_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(1.0)
        );
        assert_eq!(
            candidate_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(0.7)
        );
        assert_eq!(
            baseline_value, candidate_value,
            "BW34Y-A must differ from BW23Y-B only in policy identity and yaw-error stride authority"
        );
        assert!(candidate.controller_authority);
        assert!(!candidate.physical_acceptance_authority);
        assert!(candidate.branch_surfaces.is_empty());
    }

    #[test]
    fn r23d19_changes_only_the_cross_track_frame_mode_from_bw15f_b() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent =
            balanced_wave_profile_for_policy(&reference, BALANCED_WAVE_BW15F_B_POLICY_ID).unwrap();
        let successor = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
        )
        .unwrap();

        let mut parent_value = serde_json::to_value(&parent).unwrap();
        let mut successor_value = serde_json::to_value(&successor).unwrap();
        let parent_object = parent_value.as_object_mut().unwrap();
        let successor_object = successor_value.as_object_mut().unwrap();
        assert_eq!(
            parent_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_BW15F_B_POLICY_ID)
        );
        assert_eq!(
            successor_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID)
        );
        assert_eq!(parent_object.remove("cross_track_frame_mode_id"), None);
        assert_eq!(
            successor_object
                .remove("cross_track_frame_mode_id")
                .unwrap(),
            serde_json::json!(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID)
        );
        assert_eq!(parent_value, successor_value);
        assert!(successor.branch_surfaces.is_empty());
        assert!(successor.controller_authority);
        assert!(!successor.physical_acceptance_authority);
    }

    #[test]
    fn r23d21_changes_only_yaw_authority_from_r23d19() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
        )
        .unwrap();
        let successor = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
        )
        .unwrap();

        let mut parent_value = serde_json::to_value(&parent).unwrap();
        let mut successor_value = serde_json::to_value(&successor).unwrap();
        let parent_object = parent_value.as_object_mut().unwrap();
        let successor_object = successor_value.as_object_mut().unwrap();
        assert_eq!(
            parent_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID)
        );
        assert_eq!(
            successor_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID)
        );
        assert_eq!(
            parent_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(1.3)
        );
        assert_eq!(
            successor_object
                .remove("yaw_error_stride_gain_per_rad")
                .unwrap(),
            serde_json::json!(1.0)
        );
        assert_eq!(parent_value, successor_value);
        assert_eq!(
            successor.cross_track_frame_mode_id.as_deref(),
            Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID)
        );
        assert!(successor.branch_surfaces.is_empty());
        assert!(successor.controller_authority);
        assert!(!successor.physical_acceptance_authority);
    }

    #[test]
    fn r23d26_candidates_change_only_the_declared_portable_steering_cap() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
        )
        .unwrap();
        let cases = [
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID, 0.10),
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID, 0.20),
            (BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID, 0.30),
        ];

        for (policy_id, expected_cap) in cases {
            let candidate = balanced_wave_profile_for_policy(&reference, policy_id).unwrap();
            let mut parent_value = serde_json::to_value(&parent).unwrap();
            let mut candidate_value = serde_json::to_value(&candidate).unwrap();
            let parent_object = parent_value.as_object_mut().unwrap();
            let candidate_object = candidate_value.as_object_mut().unwrap();
            assert_eq!(
                parent_object.remove("policy_id").unwrap(),
                serde_json::json!(BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID)
            );
            assert_eq!(
                candidate_object.remove("policy_id").unwrap(),
                serde_json::json!(policy_id)
            );
            assert_eq!(
                parent_object.remove("schema_version").unwrap(),
                serde_json::json!(
                    BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION
                )
            );
            assert_eq!(
                candidate_object.remove("schema_version").unwrap(),
                serde_json::json!(BALANCED_WAVE_BOUNDED_STEERING_PROFILE_VERSION)
            );
            assert_eq!(parent_object.remove("maximum_steering_fraction"), None);
            assert_eq!(
                candidate_object
                    .remove("maximum_steering_fraction")
                    .unwrap(),
                serde_json::json!(expected_cap)
            );
            assert_eq!(parent_value, candidate_value);
            assert!(candidate.branch_surfaces.is_empty());
            assert!(candidate.controller_authority);
            assert!(!candidate.physical_acceptance_authority);
        }
    }

    #[test]
    fn r23d27_declares_one_direction_neutral_stability_guarded_policy() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID,
        )
        .unwrap();
        let successor = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();

        assert_eq!(
            successor.schema_version,
            BALANCED_WAVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION
        );
        assert_eq!(successor.maximum_steering_fraction, Some(0.28));
        assert_eq!(successor.minimum_steering_fraction, Some(0.20));
        assert_eq!(
            successor.steering_authority_guard_mode_id.as_deref(),
            Some(TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID)
        );
        assert_eq!(
            successor.steering_guard_full_authority_maximum_tilt_rad,
            Some(0.10)
        );
        assert_eq!(
            successor.steering_guard_minimum_authority_tilt_rad,
            Some(0.20)
        );
        assert_eq!(
            successor.steering_guard_minimum_support_contact_count,
            Some(2)
        );
        assert_eq!(
            successor.yaw_error_stride_gain_per_rad,
            parent.yaw_error_stride_gain_per_rad
        );
        assert_eq!(
            successor.cross_track_frame_mode_id,
            parent.cross_track_frame_mode_id
        );
        assert!(successor.branch_surfaces.is_empty());
        assert!(successor.controller_authority);
        assert!(!successor.physical_acceptance_authority);
    }

    #[test]
    fn r23d28_changes_only_the_guard_to_one_swing_predictive_evaluation() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let successor = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();

        assert_eq!(
            successor.schema_version,
            BALANCED_WAVE_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION
        );
        assert_eq!(
            successor.steering_authority_guard_mode_id.as_deref(),
            Some(PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID)
        );
        assert_eq!(successor.steering_guard_prediction_horizon_s, Some(0.6));
        assert_eq!(successor.maximum_steering_fraction, Some(0.28));
        assert_eq!(successor.minimum_steering_fraction, Some(0.20));
        assert_eq!(
            successor.steering_guard_full_authority_maximum_tilt_rad,
            Some(0.10)
        );
        assert_eq!(
            successor.steering_guard_minimum_authority_tilt_rad,
            Some(0.20)
        );
        assert_eq!(
            successor.steering_guard_minimum_support_contact_count,
            Some(2)
        );

        let mut parent_value = serde_json::to_value(parent).unwrap();
        let mut successor_value = serde_json::to_value(successor).unwrap();
        let parent_object = parent_value.as_object_mut().unwrap();
        let successor_object = successor_value.as_object_mut().unwrap();
        assert_eq!(
            successor_object.remove("schema_version").unwrap(),
            serde_json::json!(BALANCED_WAVE_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION)
        );
        assert_eq!(
            successor_object.remove("policy_id").unwrap(),
            serde_json::json!(BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID)
        );
        assert_eq!(
            successor_object
                .remove("steering_authority_guard_mode_id")
                .unwrap(),
            serde_json::json!(PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID)
        );
        assert_eq!(
            successor_object
                .remove("steering_guard_prediction_horizon_s")
                .unwrap(),
            serde_json::json!(0.6)
        );
        parent_object.remove("schema_version");
        parent_object.remove("policy_id");
        parent_object.remove("steering_authority_guard_mode_id");
        assert_eq!(parent_value, successor_value);
    }

    #[test]
    fn r23d29_changes_only_predictive_guard_persistence_and_declares_two_swings() {
        let reference = descriptor(1.0, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0);
        let parent = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();
        let successor = balanced_wave_profile_for_policy(
            &reference,
            BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
        )
        .unwrap();

        assert_eq!(
            successor.schema_version,
            BALANCED_WAVE_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION
        );
        assert_eq!(
            successor.steering_authority_guard_mode_id.as_deref(),
            Some(PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID)
        );
        assert_eq!(successor.steering_guard_prediction_horizon_s, Some(0.6));
        assert_eq!(successor.steering_guard_floor_hold_steps, Some(144));
        assert_eq!(successor.maximum_steering_fraction, Some(0.28));
        assert_eq!(successor.minimum_steering_fraction, Some(0.20));

        let mut parent_value = serde_json::to_value(parent).unwrap();
        let mut successor_value = serde_json::to_value(successor).unwrap();
        let parent_object = parent_value.as_object_mut().unwrap();
        let successor_object = successor_value.as_object_mut().unwrap();
        assert_eq!(
            successor_object.remove("schema_version").unwrap(),
            serde_json::json!(
                BALANCED_WAVE_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION
            )
        );
        assert_eq!(
            successor_object.remove("policy_id").unwrap(),
            serde_json::json!(
                BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            )
        );
        assert_eq!(
            successor_object
                .remove("steering_authority_guard_mode_id")
                .unwrap(),
            serde_json::json!(
                PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID
            )
        );
        assert_eq!(
            successor_object
                .remove("steering_guard_floor_hold_steps")
                .unwrap(),
            serde_json::json!(144)
        );
        parent_object.remove("schema_version");
        parent_object.remove("policy_id");
        parent_object.remove("steering_authority_guard_mode_id");
        assert_eq!(parent_value, successor_value);
    }

    #[test]
    fn balanced_wave_profile_is_finite_continuous_and_branch_free_over_domain() {
        const SAMPLE_COUNT: usize = 10_001;
        let step = (1.10 - 0.90) / (SAMPLE_COUNT - 1) as f64;
        // BW21L's prospective high proportional arm is 1.5 / length.
        let heading_derivative_bound = 1.5 / (0.90_f64 * 0.90);
        // BW21L's prospective high velocity arm is 0.70 * sqrt(length), whose
        // derivative is 0.70 / (2 * sqrt(length)).
        let velocity_derivative_bound = 0.35 / 0.90_f64.sqrt();
        let mut previous: Option<BalancedWaveProfile> = None;

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
            BALANCED_WAVE_BW15F_B_POLICY_ID,
            BALANCED_WAVE_BW15F_C_POLICY_ID,
            BALANCED_WAVE_BW15F_D_POLICY_ID,
            BALANCED_WAVE_BW21L_B_POLICY_ID,
            BALANCED_WAVE_BW21L_C_POLICY_ID,
            BALANCED_WAVE_BW21L_D_POLICY_ID,
            BALANCED_WAVE_BW23Y_B_POLICY_ID,
            BALANCED_WAVE_BW34Y_A_POLICY_ID,
            BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
            BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
        ] {
            for index in 0..SAMPLE_COUNT {
                let length = 0.90 + index as f64 * step;
                let profile = balanced_wave_profile_for_policy(
                    &descriptor(length, 1.0, REFERENCE_UPPER_LENGTH_FRACTION, 1.0, 1.0, 1.0),
                    policy_id,
                )
                .unwrap();
                let values = [
                    profile.cross_track_heading_gain_rad_per_m,
                    profile.yaw_error_stride_gain_per_rad,
                    profile.cross_track_velocity_heading_gain_rad_per_m_s,
                    profile.contact_loaded_swing_knee_maximum_motor_target_speed_rad_s,
                    profile.anchor_error_guard_activation_fraction,
                    profile.anchor_error_guard_maximum_motor_target_speed_rad_s,
                ];
                assert!(
                    values
                        .into_iter()
                        .all(|value| value.is_finite() && value > 0.0)
                );
                assert!(profile.branch_surfaces.is_empty());

                if let Some(previous) = previous {
                    assert!(
                        (profile.cross_track_heading_gain_rad_per_m
                            - previous.cross_track_heading_gain_rad_per_m)
                            .abs()
                            <= heading_derivative_bound * step + 1.0e-12
                    );
                    assert!(
                        (profile.cross_track_velocity_heading_gain_rad_per_m_s
                            - previous.cross_track_velocity_heading_gain_rad_per_m_s)
                            .abs()
                            <= velocity_derivative_bound * step + 1.0e-12
                    );
                }
                previous = Some(profile);
            }
            previous = None;
        }
    }

    #[test]
    fn candidate35_short_wide_branch_is_exact() {
        assert_eq!(candidate35_velocity_gain(0.5, 0.99, 1.02, 1.0, 1.0), 0.25);
        assert!((candidate35_velocity_gain(1.0, 0.99, 1.06, 1.0, 1.0) - 0.30).abs() < 1.0e-12);
        assert_eq!(candidate35_velocity_gain(1.0, 1.0, 1.06, 1.0, 1.0), 0.35);
        assert_eq!(candidate35_velocity_gain(1.0, 0.99, 1.06, 0.98, 1.1), 0.25);
    }

    #[test]
    fn strict_yaw_and_guard_boundaries_are_frozen() {
        assert_eq!(candidate35_yaw_gain(0.9, 1.0, 0.985, 1.0), 1.0);
        assert_eq!(candidate35_yaw_gain(0.9, 1.0, 0.984, 1.0), 1.3);
        assert_eq!(candidate35_yaw_gain(0.5, 1.0, 1.01, 1.0), 1.0);
        assert_eq!(candidate35_yaw_gain(0.5, 1.0, 1.011, 1.0), 1.3);
        assert_eq!(candidate35_motor_guard(0.5, 1.04, 0.94), (0.80, 2.0));
        assert_eq!(candidate35_motor_guard(0.5, 1.041, 0.95), (0.80, 2.0));
        assert_eq!(candidate35_motor_guard(0.5, 1.041, 0.949), (0.70, 1.75));
        assert_eq!(candidate35_motor_guard(0.5, 1.041, 1.0), (0.80, 2.0));
        assert_eq!(candidate35_motor_guard(0.5, 1.041, 1.001), (0.70, 1.75));
    }

    #[test]
    fn checked_in_gdscript_golden_vectors_match_rust() {
        let golden: GoldenFile = serde_json::from_str(include_str!(
            "../../conformance/golden/candidate35_gq15_v1.json"
        ))
        .unwrap();
        assert_eq!(
            golden.schema_version,
            "sporespore_candidate35_golden_vectors_v1"
        );
        assert_eq!(
            golden.oracle_source_commit,
            "52ce84d300dfac945096403250e429a183ebda4e"
        );
        assert_eq!(
            golden.oracle_path,
            "tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
        );
        for vector in golden.interaction_vectors {
            let descriptor = descriptor(
                vector.scales[0],
                vector.scales[1],
                vector.scales[2],
                vector.scales[3],
                vector.scales[4],
                vector.scales[5],
            );
            let actual = interaction_score(&descriptor).unwrap();
            assert!(
                (actual - vector.expected_score).abs() <= golden.tolerance,
                "{}: expected {}, got {}",
                vector.vector_id,
                vector.expected_score,
                actual
            );
        }
        for vector in golden.controller_vectors {
            let heading = if vector.score < 0.5 { 1.0 } else { 0.75 };
            let yaw = candidate35_yaw_gain(
                vector.score,
                vector.torso_length_scale,
                vector.foot_radius_scale,
                vector.hip_span_scale,
            );
            let velocity = candidate35_velocity_gain(
                vector.score,
                vector.torso_length_scale,
                vector.torso_width_scale,
                vector.foot_radius_scale,
                yaw,
            );
            let guard = candidate35_motor_guard(
                vector.score,
                vector.torso_length_scale,
                vector.torso_width_scale,
            );
            let actual = [heading, yaw, velocity, guard.0, guard.1];
            for (index, (actual_value, expected_value)) in
                actual.into_iter().zip(vector.expected).enumerate()
            {
                assert!(
                    (actual_value - expected_value).abs() <= golden.tolerance,
                    "{}[{}]: expected {}, got {}",
                    vector.vector_id,
                    index,
                    expected_value,
                    actual_value
                );
            }
        }
    }
}
