//! Pure, explicitly selected recovery-walking development controller layer.
//!
//! The existing walking observation basis maps anatomical forward to body +Z,
//! up to +Y, and right to -X. This mode declares that mapping rather than
//! treating the historical walking quaternion as the anatomical quaternion.
//! All four nominal leg directions participate in the plane calculation, so
//! changing swing/stance membership does not change the geometric population.
//! Joint projection and reference slew are retained, not claims of contact.

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::protocol::{ActuationFrame, MotionCommand, StateFrame};
use crate::quadruped::CompiledQuadruped;
use crate::runtime::BalancedWaveControllerMemory;
use crate::schema::{CoreError, Result};

pub const MODE_ID: &str = "all_limb_bounded_plane_observation_z_forward_reference_slew_v1";
pub const MEMORY_VERSION: &str = "sporespore_balanced_wave_recovery_support_memory_v1";
const LIMBS: [&str; 4] = ["front_left", "front_right", "rear_left", "rear_right"];

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportReferenceMemory {
    pub previous_sample_time_s: Option<f64>,
    pub ordered_target_positions_rad: Vec<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub previous_wave: Option<WaveSnapshot>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ordered_stance_latches: Option<Vec<StanceReferenceLatch>>,
}

impl SupportReferenceMemory {
    pub fn initial() -> Self {
        Self {
            previous_sample_time_s: None,
            ordered_target_positions_rad: vec![0.0; 8],
            previous_wave: None,
            ordered_stance_latches: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StanceReferenceLatch {
    pub limb_id: String,
    pub upright_reference_latched: bool,
}

pub(crate) fn initial_stance_latches() -> Vec<StanceReferenceLatch> {
    LIMBS.iter().map(|limb| StanceReferenceLatch {
        limb_id: (*limb).to_owned(), upright_reference_latched: false,
    }).collect()
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WaveLimbSnapshot {
    pub limb_id: String,
    pub nominal_leg_direction_rad: f64,
    pub walking_knee_fraction: f64,
    pub scheduled_phase_step: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WaveSnapshot {
    pub active: bool,
    pub ordered_limbs: Vec<WaveLimbSnapshot>,
}

impl WaveSnapshot {
    fn validate(&self, compiled: &CompiledQuadruped) -> Result<()> {
        if self.ordered_limbs.len() != 4 {
            return Err(CoreError::Order("wave_velocity_limb_count".to_owned()));
        }
        for (i, (limb, saved)) in LIMBS.iter().zip(&self.ordered_limbs).enumerate() {
            let bound = &compiled.morphology.morphology_spec.actuators[2*i];
            if saved.limb_id != *limb || !saved.nominal_leg_direction_rad.is_finite()
                || saved.nominal_leg_direction_rad < bound.minimum_target_position_rad
                || saved.nominal_leg_direction_rad > bound.maximum_target_position_rad
                || !saved.walking_knee_fraction.is_finite()
                || !(0.0..=1.0).contains(&saved.walking_knee_fraction)
                || saved.scheduled_phase_step >= 360
                || (!self.active && (saved.nominal_leg_direction_rad != 0.0 || saved.walking_knee_fraction != 0.0))
            {
                return Err(CoreError::Frame("wave_velocity_snapshot_domain".to_owned()));
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WaveVelocityReceipt {
    pub previous_wave: Option<WaveSnapshot>,
    pub current_wave: WaveSnapshot,
    pub ordered_comparison_reference_rad: Vec<f64>,
    pub feedforward_active: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AirborneReferenceLimbReceipt {
    pub limb_id: String,
    pub scheduled_phase_step: u64,
    pub full_reference_rate_selected: bool,
    pub precommand_contact: crate::protocol::ContactObservation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AirborneReferenceReceipt {
    pub source_semantic_step: u64,
    pub source_sample_time_s: f64,
    pub source_adapter_capability_sha256: String,
    pub ordered_limbs: Vec<AirborneReferenceLimbReceipt>,
    pub ordered_full_reference_velocity_rad_s: Vec<f64>,
}

// Missing contact is never absence. State validation runs before this selector;
// the explicit Option tests also keep this small predicate conservative.
pub(crate) fn airborne_reference_selected(
    both_waves_active: bool, dt: f64, phase: u64,
    presence: Option<bool>, bears_support: Option<bool>,
) -> bool {
    both_waves_active && dt > 0.0 && phase <= crate::runtime::SWING_STEPS
        && presence == Some(false) && bears_support == Some(false)
}

// V40 extends only the eligible phases. Present or unknown contact still uses
// the existing fallback; a missed stance contact is not a force estimate.
pub(crate) fn absent_contact_reference_selected(
    both_waves_active: bool, dt: f64, phase: u64,
    presence: Option<bool>, bears_support: Option<bool>,
) -> bool {
    both_waves_active && dt > 0.0 && phase < 360
        && presence == Some(false) && bears_support == Some(false)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportPlaneLimbReceipt {
    pub limb_id: String,
    pub nominal_leg_direction_rad: f64,
    pub unrestricted_hip_rad: f64,
    pub unrestricted_knee_rad: f64,
    pub projected_support_hip_rad: f64,
    pub projected_support_knee_rad: f64,
    pub support_joint_projection_required: bool,
    pub projected_support_nominal_plane_residual_m: f64,
    pub walking_knee_fraction: f64,
    pub walking_knee_projection_required: bool,
    pub goal_hip_rad: f64,
    pub goal_knee_rad: f64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub requested_endpoint_distance_m: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub link_reach_projection_required: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_reference_torso_height_m: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scheduled_phase_step: Option<u64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportPlaneReceipt {
    pub schema_version: String,
    pub mode_id: String,
    pub observation_anatomical_axis_mapping: String,
    pub reference_step_duration_s: f64,
    pub first_step_holds_neutral_reference: bool,
    pub zero_amplitude_selects_neutral_goal: bool,
    pub proposed_torso_height_m: f64,
    pub unrestricted_plane_inside_joint_limits: bool,
    pub ordered_limb_proposals: Vec<SupportPlaneLimbReceipt>,
    pub reference_slew_limited_actuator_ids: Vec<String>,
    pub all_limb_contact_claim: bool,
    pub physical_acceptance_authority: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub floor_reference: Option<crate::recovery_floor_reference::FloorReference>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub feasible_support_plan: Option<crate::recovery_feasible_support::FeasibleSupportPlan>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub swing_lift_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reference_velocity_mode_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ordered_reference_velocity_rad_s: Option<Vec<f64>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wave_velocity: Option<WaveVelocityReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub airborne_reference: Option<AirborneReferenceReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub upright_stance: Option<UprightStanceReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stance_latch: Option<StanceLatchReceipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_progression: Option<crate::recovery_support_progression::Receipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub support_hold_posture: Option<crate::recovery_support_hold_posture::Receipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub measured_support_transfer: Option<crate::recovery_measured_support_transfer::Receipt>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub anchored_body_pose: Option<crate::recovery_anchored_body_pose::Receipt>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StanceLatchLimbReceipt {
    pub limb_id: String,
    pub incoming_upright_reference_latched: bool,
    pub previous_wave_active: bool,
    pub previous_scheduled_phase_step: Option<u64>,
    pub current_scheduled_phase_step: u64,
    pub previous_latch_carry_eligible: bool,
    pub precommand_contact: crate::protocol::ContactObservation,
    pub next_upright_reference_latched: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StanceLatchReceipt {
    pub schema_version: String,
    pub source_semantic_step: u64,
    pub ordered_limbs: Vec<StanceLatchLimbReceipt>,
}

pub(crate) fn stance_latch_carry(previous_active: bool, previous_phase: Option<u64>,
    latched: bool, phase: u64) -> bool {
    latched && previous_active && previous_phase.is_some_and(|p|
        p > crate::runtime::SWING_STEPS && p < 360 && phase >= p && phase < 360)
}

// This latches a reference choice, never contact truth. State validation rejects
// missing or contradictory contact observations before this layer executes.
#[allow(clippy::too_many_arguments)]
pub(crate) fn stance_latch_selected(active: bool, phase: u64,
    presence: Option<bool>, bearing: Option<bool>, previous_active: bool,
    previous_phase: Option<u64>, latched: bool) -> bool {
    active && phase > crate::runtime::SWING_STEPS && phase < 360
        && presence.is_some() && bearing.is_some()
        && !(presence == Some(false) && bearing == Some(true))
        && (stance_latch_carry(previous_active, previous_phase, latched, phase)
            || (presence == Some(true) && bearing == Some(true)))
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UprightStanceLimbReceipt {
    pub limb_id: String,
    pub scheduled_phase_step: u64,
    pub upright_reference_selected: bool,
    pub precommand_contact: crate::protocol::ContactObservation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct UprightStanceReceipt {
    pub source_semantic_step: u64,
    pub source_sample_time_s: f64,
    pub source_adapter_capability_sha256: String,
    pub source_floor_reference: crate::recovery_floor_reference::FloorReference,
    pub reference_geometry_role: String,
    pub reference_anatomical_vertical_projections: [f64; 3],
    pub ordered_limbs: Vec<UprightStanceLimbReceipt>,
    pub measured_pose_baseline_proposals: Vec<SupportPlaneLimbReceipt>,
    pub measured_pose_baseline_plan: Option<crate::recovery_feasible_support::FeasibleSupportPlan>,
    pub floor_upright_reference_proposals: Vec<SupportPlaneLimbReceipt>,
    pub floor_upright_reference_plan: Option<crate::recovery_feasible_support::FeasibleSupportPlan>,
    pub ordered_selected_goals_rad: Vec<f64>,
    pub comparison_uses_current_selector: bool,
    pub ordered_same_mask_comparison_goals_rad: Option<Vec<f64>>,
}

pub(crate) fn upright_stance_selected(
    active: bool, phase: u64, presence: Option<bool>, bearing: Option<bool>,
) -> bool {
    active && phase > crate::runtime::SWING_STEPS && phase < 360
        && presence == Some(true) && bearing == Some(true)
}

pub(crate) fn validate_memory(
    selected: bool,
    expected_memory_version: &str,
    memory: &BalancedWaveControllerMemory,
    state: &StateFrame,
    compiled: &CompiledQuadruped,
) -> Result<()> {
    let Some(reference) = memory.support_reference.as_ref() else {
        return if selected {
            Err(CoreError::Schema("support_reference_missing".to_owned()))
        } else {
            Ok(())
        };
    };
    if !selected || memory.schema_version != expected_memory_version {
        return Err(CoreError::Schema(
            "support_reference_crossed_policy".to_owned(),
        ));
    }
    if matches!(expected_memory_version, crate::runtime::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION
        | crate::runtime::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_MEMORY_VERSION
        | crate::runtime::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION
        | crate::runtime::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION
        | crate::runtime::BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION
        | crate::recovery_support_progression::MEMORY
        | crate::recovery_support_hold_posture::MEMORY
        | crate::recovery_measured_support_transfer::MEMORY
        | crate::recovery_measured_pose_support::MEMORY) {
        if reference.previous_sample_time_s.is_some() != reference.previous_wave.is_some() {
            return Err(CoreError::Schema("wave_velocity_snapshot_initialization".to_owned()));
        }
        if let Some(wave) = &reference.previous_wave { wave.validate(compiled)?; }
    } else if reference.previous_wave.is_some() {
        return Err(CoreError::Schema("wave_velocity_snapshot_crossed_policy".to_owned()));
    }
    if matches!(expected_memory_version, crate::runtime::BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION
        | crate::recovery_support_progression::MEMORY
        | crate::recovery_support_hold_posture::MEMORY
        | crate::recovery_measured_support_transfer::MEMORY) {
        let latches = reference.ordered_stance_latches.as_ref()
            .ok_or_else(|| CoreError::Schema("stance_latch_memory_missing".to_owned()))?;
        if latches.len() != 4 || LIMBS.iter().zip(latches).any(|(limb,latch)| *limb != latch.limb_id) {
            return Err(CoreError::Order("stance_latch_memory_limb_order".to_owned()));
        }
        if reference.previous_sample_time_s.is_none() && latches.iter().any(|l| l.upright_reference_latched) {
            return Err(CoreError::Schema("stance_latch_initial_memory".to_owned()));
        }
    } else if reference.ordered_stance_latches.is_some() {
        return Err(CoreError::Schema("stance_latch_memory_crossed_policy".to_owned()));
    }
    if reference.ordered_target_positions_rad.len() != 8
        || reference
            .ordered_target_positions_rad
            .iter()
            .zip(&compiled.morphology.morphology_spec.actuators)
            .any(|(value, actuator)| {
                !value.is_finite()
                    || *value < actuator.minimum_target_position_rad
                    || *value > actuator.maximum_target_position_rad
            })
    {
        return Err(CoreError::Frame("support_reference_targets".to_owned()));
    }
    match (memory.last_semantic_step, reference.previous_sample_time_s) {
        (None, None)
            if reference
                .ordered_target_positions_rad
                .iter()
                .all(|v| *v == 0.0) =>
        {
            Ok(())
        }
        (Some(_), Some(previous))
            if previous.is_finite()
                && previous >= 0.0
                && state.sample_time_s.is_finite()
                && state.sample_time_s > previous =>
        {
            Ok(())
        }
        _ => Err(CoreError::Time(
            "support_reference_clock_or_initialization".to_owned(),
        )),
    }
}

fn nominal_bottom(
    height: f64,
    anchor: f64,
    forward_y: f64,
    up_y: f64,
    hip: f64,
    knee: f64,
    upper: f64,
    lower: f64,
    radius: f64,
) -> f64 {
    let distal_angle = hip + knee;
    height + anchor + forward_y * (upper * hip.sin() + lower * 0.5 * distal_angle.sin())
        - up_y * (upper * hip.cos() + lower * 0.5 * distal_angle.cos())
        - (up_y * distal_angle.cos() - forward_y * distal_angle.sin()).abs() * lower * 0.5
        - radius
}

struct ComposedGoals {
    proposals: Vec<SupportPlaneLimbReceipt>,
    goals: Vec<f64>,
    proposed_height: f64,
    feasible_plan: Option<crate::recovery_feasible_support::FeasibleSupportPlan>,
}

fn compose_goals(
    state: &StateFrame,
    motion: &MotionCommand,
    compiled: &CompiledQuadruped,
    actuation: &ActuationFrame,
    floor: Option<&crate::recovery_floor_reference::FloorReference>,
    feasible_phases: Option<&[u64;4]>,
    wave_override: Option<&WaveSnapshot>,
    floor_upright_reference: bool,
    leg_direction_bias: Option<f64>,
) -> Result<ComposedGoals> {
    let override_phases = wave_override.map(|wave| std::array::from_fn(|i| wave.ordered_limbs[i].scheduled_phase_step));
    let feasible_phases = override_phases.as_ref().or(feasible_phases);
    let q = state.base_pose_world.orientation_xyzw;
    let norm = (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w).sqrt();
    let (x, y, z, w) = (q.x / norm, q.y / norm, q.z / norm, q.w / norm);
    // Anatomical +X = observation +Z; anatomical +Z = observation -X.
    let forward_y = 2.0 * (y * z - w * x);
    let up_y = 1.0 - 2.0 * (x * x + z * z);
    let side_y = -2.0 * (x * y + w * z);
    // A reference calculation, NEVER a replacement observation quaternion.
    // Leave the historical measured-pose arithmetic above byte-compatible.
    let (forward_y, up_y, side_y) = if floor_upright_reference {
        (0.0, 1.0, 0.0)
    } else {
        (forward_y, up_y, side_y)
    };
    let g = &compiled.geometry;
    let (upper, lower, radius) = (g.upper_length_m, g.lower_length_m, g.foot_radius_m);
    let mut rows = Vec::with_capacity(4);
    let mut proposed_height = f64::INFINITY;
    for (index, limb) in LIMBS.into_iter().enumerate() {
        let hip = &actuation.ordered_commands[2 * index];
        let knee = &actuation.ordered_commands[2 * index + 1];
        if hip.actuator_id != format!("{limb}_hip_motor")
            || knee.actuator_id != format!("{limb}_knee_motor")
        {
            return Err(CoreError::Order("support_plane_actuator_roles".to_owned()));
        }
        let raw_angle = wave_override.map_or(hip.requested_target_position_rad, |wave| wave.ordered_limbs[index].nominal_leg_direction_rad);
        let angle = leg_direction_bias.map_or(raw_angle, |bias| raw_angle+bias);
        let anchor = (if limb.starts_with("front") {
            g.front_hip_x_m
        } else {
            g.rear_hip_x_m
        }) * forward_y
            + (if limb.ends_with("left") {
                g.left_hip_z_m
            } else {
                g.right_hip_z_m
            }) * side_y;
        let downward = up_y * angle.cos() - forward_y * angle.sin();
        if !downward.is_finite() || downward <= 0.0 {
            return Err(CoreError::Frame(
                "support_plane_non_downward_direction".to_owned(),
            ));
        }
        proposed_height = proposed_height.min(radius - anchor + (upper + lower) * downward);
        rows.push((limb, angle, anchor, downward));
    }
    // New policy only: the supplied plane is in the same WORLD frame as
    // state.position. Body orientation keeps the declared historical mapping.
    // Retain relative torso height in the receipt, never assume world y=0.
    if let Some(plane) = floor {
        proposed_height = state.base_pose_world.position_m.y - plane.height_world_m;
        if !proposed_height.is_finite() {
            return Err(CoreError::NonFinite("floor_relative_torso_height".to_owned()));
        }
    }
    let mut proposals = Vec::with_capacity(4);
    let mut goals = Vec::with_capacity(8);
    let mut feasible_plan = if feasible_phases.is_some() {
        if floor.is_none() { return Err(CoreError::Frame("feasible_support_floor_missing".to_owned())); }
        let directions=rows.iter().enumerate().map(|(i,(limb,angle,anchor,downward))| {
            let hip=&compiled.morphology.morphology_spec.actuators[2*i];
            let knee=&compiled.morphology.morphology_spec.actuators[2*i+1];
            crate::recovery_feasible_support::Direction {limb,angle:*angle,anchor_y:*anchor,downward:*downward,
                hip_minimum:hip.minimum_target_position_rad,hip_maximum:hip.maximum_target_position_rad,
                knee_maximum:knee.maximum_target_position_rad}
        }).collect::<Vec<_>>();
        Some(crate::recovery_feasible_support::plan(proposed_height,upper,lower,radius,&directions)?)
    } else { None };
    for (index, (limb, angle, anchor, downward)) in rows.into_iter().enumerate() {
        let reference_height=if let (Some(plan),Some(phases))=(&mut feasible_plan,feasible_phases) {
            if phases[index]>crate::runtime::SWING_STEPS && plan.requested_lowering_m>0.0 {
                plan.ordered_lowering_participant_limb_ids.push(limb.to_owned());
                plan.requested_stance_torso_height_m
            } else { proposed_height }
        } else { proposed_height };
        let requested_length = (reference_height + anchor - radius) / downward;
        let length = if floor.is_some() {
            requested_length.clamp((upper - lower).abs(), upper + lower)
        } else {
            requested_length
        };
        let cosine = (length * length - upper * upper - lower * lower) / (2.0 * upper * lower);
        if (floor.is_none() && length <= 0.0) || !(-1.0 - 1e-12..=1.0 + 1e-12).contains(&cosine) {
            return Err(CoreError::Frame("support_plane_link_reach".to_owned()));
        }
        let unrestricted_knee = if floor.is_some() && requested_length >= upper + lower {
            0.0 // Exact full extension for the explicit out-of-reach branch.
        } else {
            cosine.clamp(-1.0, 1.0).acos()
        };
        let hip_for_knee =
            |knee: f64| angle - (lower * knee.sin()).atan2(upper + lower * knee.cos());
        let unrestricted_hip = hip_for_knee(unrestricted_knee);
        let hip_bound = &compiled.morphology.morphology_spec.actuators[2 * index];
        let knee_bound = &compiled.morphology.morphology_spec.actuators[2 * index + 1];
        let support_knee = unrestricted_knee.clamp(0.0, knee_bound.maximum_target_position_rad);
        // Recompute hip after knee projection to preserve the direction when
        // its own limit allows. Retain any remaining plane error explicitly.
        let support_hip = hip_for_knee(support_knee).clamp(
            hip_bound.minimum_target_position_rad,
            hip_bound.maximum_target_position_rad,
        );
        let raw_wave_knee = actuation.ordered_commands[2 * index + 1].requested_target_position_rad;
        let wave_knee = raw_wave_knee.clamp(0.0, knee_bound.maximum_target_position_rad);
        let fraction = wave_override.map_or(wave_knee / knee_bound.maximum_target_position_rad, |wave| wave.ordered_limbs[index].walking_knee_fraction);
        // Use the remaining knee range during swing, not an additive offset
        // that would exceed the limit. The support baseline persists through
        // the phase boundary; the following reference slew also covers changes
        // in measured pose, steering, and the old contact-clearance term.
        let (goal_hip, goal_knee) = if wave_override.map_or(motion.gait_amplitude == 0.0, |wave| !wave.active) {
            (0.0, 0.0)
        } else {
            (
                support_hip * (1.0 - fraction) + angle * fraction,
                support_knee + (knee_bound.maximum_target_position_rad - support_knee) * fraction,
            )
        };
        goals.extend([goal_hip, goal_knee]);
        proposals.push(SupportPlaneLimbReceipt {
            limb_id: limb.to_owned(),
            nominal_leg_direction_rad: angle,
            unrestricted_hip_rad: unrestricted_hip,
            unrestricted_knee_rad: unrestricted_knee,
            projected_support_hip_rad: support_hip,
            projected_support_knee_rad: support_knee,
            support_joint_projection_required: unrestricted_knee != support_knee
                || unrestricted_hip != support_hip,
            projected_support_nominal_plane_residual_m: nominal_bottom(
                proposed_height,
                anchor,
                forward_y,
                up_y,
                support_hip,
                support_knee,
                upper,
                lower,
                radius,
            ),
            walking_knee_fraction: fraction,
            walking_knee_projection_required: raw_wave_knee != wave_knee,
            goal_hip_rad: goal_hip,
            goal_knee_rad: goal_knee,
            requested_endpoint_distance_m: floor.map(|_| requested_length),
            link_reach_projection_required: floor.map(|_| length != requested_length),
            support_reference_torso_height_m: feasible_phases.map(|_|reference_height),
            scheduled_phase_step: feasible_phases.map(|p|p[index]),
        });
    }
    Ok(ComposedGoals {proposals, goals, proposed_height, feasible_plan})
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn apply(
    previous: &SupportReferenceMemory,
    state: &StateFrame,
    motion: &MotionCommand,
    compiled: &CompiledQuadruped,
    actuation: &mut ActuationFrame,
    maximum_controller_speed: f64,
    position_gain: f64,
    rate_damping: f64,
    motor_direction: f64,
    floor: Option<&crate::recovery_floor_reference::FloorReference>,
    feasible_phases: Option<&[u64;4]>,
    hold_posture: bool,
    leg_direction_bias: Option<f64>,
) -> Result<SupportReferenceMemory> {
    let ComposedGoals {mut proposals, mut goals, proposed_height, mut feasible_plan} =
        compose_goals(state, motion, compiled, actuation, floor, feasible_phases, None, false, leg_direction_bias)?;
    let latch_selected = matches!(actuation.receipt.policy_id.as_str(), crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID
        | crate::recovery_support_progression::POLICY
        | crate::recovery_support_hold_posture::POLICY
        | crate::recovery_measured_support_transfer::POLICY);
    let hold_posture_selected = matches!(actuation.receipt.policy_id.as_str(), crate::recovery_support_hold_posture::POLICY
        | crate::recovery_measured_support_transfer::POLICY | crate::recovery_measured_pose_support::POLICY);
    let measured_pose_selected = actuation.receipt.policy_id == crate::recovery_measured_pose_support::POLICY;
    if leg_direction_bias.is_some() != (measured_pose_selected || actuation.receipt.policy_id == crate::recovery_measured_support_transfer::POLICY)
        || leg_direction_bias.is_some_and(|bias| !bias.is_finite() || bias.abs()>crate::recovery_measured_support_transfer::MAX_BIAS) {
        return Err(CoreError::Schema("measured_support_transfer_bias_crossed_policy".to_owned()));
    }
    if hold_posture && !hold_posture_selected {
        return Err(CoreError::Schema("support_hold_posture_crossed_policy".to_owned()));
    }
    let upright_selected = latch_selected || actuation.receipt.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID;
    let absent_contact_selected = measured_pose_selected || upright_selected || actuation.receipt.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID;
    let airborne_selected = absent_contact_selected || actuation.receipt.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID;
    let wave_selected = airborne_selected || actuation.receipt.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID;
    let current_wave = if wave_selected {
        let wave = WaveSnapshot {active: motion.gait_amplitude != 0.0, ordered_limbs: proposals.iter().enumerate().map(|(i,p)| WaveLimbSnapshot {
            limb_id: p.limb_id.clone(), nominal_leg_direction_rad: if leg_direction_bias.is_some() {
                actuation.ordered_commands[2*i].requested_target_position_rad
            } else {p.nominal_leg_direction_rad},
            walking_knee_fraction: p.walking_knee_fraction,
            scheduled_phase_step: p.scheduled_phase_step.expect("wave policy requires feasible phases"),
        }).collect()};
        wave.validate(compiled)?;
        Some(wave)
    } else { None };
    let feedforward_active = wave_selected && current_wave.as_ref().is_some_and(|w|w.active)
        && previous.previous_wave.as_ref().is_some_and(|w|w.active);
    // One pose and one slew origin for both goal evaluations. No previous body
    // pose enters this calculation; old policies never enter the extra path.
    let mut comparison_goals = if feedforward_active {
        Some(compose_goals(state, motion, compiled, actuation, floor, feasible_phases, previous.previous_wave.as_ref(), false, leg_direction_bias)?.goals)
    } else { None };
    if measured_pose_selected && hold_posture {
        // V46 holds the same scheduler wave but removes lift using the actual
        // measured orientation. Apply this same current mode to both reference
        // evaluations so entering a hold cannot become gait feedforward.
        let held_wave = crate::recovery_support_hold_posture::without_lift(current_wave.as_ref().expect("selected wave"));
        let held = compose_goals(state, motion, compiled, actuation, floor, feasible_phases,
            Some(&held_wave), false, leg_direction_bias)?;
        proposals = held.proposals;
        goals = held.goals;
        feasible_plan = held.feasible_plan;
        if feedforward_active {
            let held_previous = crate::recovery_support_hold_posture::without_lift(previous.previous_wave.as_ref().expect("active prior wave"));
            comparison_goals = Some(compose_goals(state, motion, compiled, actuation, floor, feasible_phases,
                Some(&held_previous), false, leg_direction_bias)?.goals);
        }
    }
    let mut stance_latch = latch_selected.then(|| StanceLatchReceipt {
        schema_version: "sporespore_stance_reference_latch_receipt_v1".to_owned(),
        source_semantic_step: state.semantic_step, ordered_limbs: Vec::with_capacity(4),
    });
    let upright_stance = if upright_selected {
        let wave = current_wave.as_ref().expect("selected wave");
        // The saved wave remains the scheduler's wave. In BOTH reference
        // evaluations remove lift during the same current hold mode, so a
        // mode transition cannot masquerade as gait-wave feedforward.
        let hold_wave = hold_posture.then(|| crate::recovery_support_hold_posture::without_lift(wave));
        let hold_previous = if hold_posture {
            previous.previous_wave.as_ref().map(crate::recovery_support_hold_posture::without_lift)
        } else { None };
        let upright = compose_goals(state, motion, compiled, actuation, floor, feasible_phases, hold_wave.as_ref(), true, leg_direction_bias)?;
        let upright_comparison = if feedforward_active {
            Some(compose_goals(state, motion, compiled, actuation, floor, feasible_phases,
                hold_previous.as_ref().or(previous.previous_wave.as_ref()), true, leg_direction_bias)?.goals)
        } else { None };
        let measured_pose_baseline_proposals = proposals.clone();
        let mut ordered_limbs = Vec::with_capacity(4);
        for (i, limb) in LIMBS.iter().enumerate() {
            let contact = state.ordered_contact_observations.get(i)
                .ok_or_else(|| CoreError::Order("upright_stance_contact_count".to_owned()))?;
            if contact.contact_site_id != format!("{limb}_foot") {
                return Err(CoreError::Order("upright_stance_contact_order".to_owned()));
            }
            let phase = wave.ordered_limbs[i].scheduled_phase_step;
            let selected = if let Some(receipt) = &mut stance_latch {
                let incoming = previous.ordered_stance_latches.as_ref().expect("validated latch memory")[i].upright_reference_latched;
                let previous_active = previous.previous_wave.as_ref().is_some_and(|w| w.active);
                let previous_phase = previous.previous_wave.as_ref().map(|w| w.ordered_limbs[i].scheduled_phase_step);
                let chosen = stance_latch_selected(wave.active, phase, contact.presence, contact.bears_support,
                    previous_active, previous_phase, incoming);
                receipt.ordered_limbs.push(StanceLatchLimbReceipt {
                    limb_id: (*limb).to_owned(), incoming_upright_reference_latched: incoming,
                    previous_wave_active: previous_active, previous_scheduled_phase_step: previous_phase,
                    current_scheduled_phase_step: phase,
                    previous_latch_carry_eligible: stance_latch_carry(previous_active, previous_phase, incoming, phase),
                    precommand_contact: contact.clone(), next_upright_reference_latched: chosen,
                });
                chosen
            } else {
                upright_stance_selected(wave.active, phase, contact.presence, contact.bears_support)
            };
            // A support posture may select a swing limb too. Do not latch
            // fictitious contact: the stance-latch receipt above is untouched.
            let selected = selected || hold_posture;
            ordered_limbs.push(UprightStanceLimbReceipt {limb_id: (*limb).to_owned(),
                scheduled_phase_step: phase, upright_reference_selected: selected, precommand_contact: contact.clone()});
            if selected {
                // Top-level proposals describe the ACTUAL selected goals. The
                // two unmodified baselines and their plans are labeled below.
                proposals[i] = upright.proposals[i].clone();
                for joint in 2*i..2*i+2 {
                    goals[joint] = upright.goals[joint];
                    if let (Some(comparison), Some(reference)) = (&mut comparison_goals, &upright_comparison) {
                        comparison[joint] = reference[joint];
                    }
                }
            }
        }
        Some(UprightStanceReceipt {
            source_semantic_step: state.semantic_step, source_sample_time_s: state.sample_time_s,
            source_adapter_capability_sha256: state.adapter_capability_sha256.clone(),
            source_floor_reference: floor.ok_or_else(|| CoreError::Frame("upright_stance_floor_missing".to_owned()))?.clone(),
            reference_geometry_role: "controller_target_not_measured_pose_or_contact".to_owned(),
            reference_anatomical_vertical_projections: [0.0, 1.0, 0.0], ordered_limbs,
            measured_pose_baseline_proposals,
            // There is no single plan for mixed geometry. Retain BOTH plans
            // explicitly; do not label the old plan as a selected mixed plan.
            measured_pose_baseline_plan: feasible_plan.take(),
            floor_upright_reference_proposals: upright.proposals,
            floor_upright_reference_plan: upright.feasible_plan,
            ordered_selected_goals_rad: goals.clone(), comparison_uses_current_selector: true,
            ordered_same_mask_comparison_goals_rad: comparison_goals.clone(),
        })
    } else { None };
    let mut comparison_references = Vec::with_capacity(8);
    let dt = previous
        .previous_sample_time_s
        .map_or(0.0, |t| state.sample_time_s - t);
    let mut airborne_reference = if airborne_selected {
        let mut ordered_limbs = Vec::with_capacity(4);
        for (i, limb) in LIMBS.iter().enumerate() {
            let contact = state.ordered_contact_observations.get(i)
                .ok_or_else(|| CoreError::Order("airborne_reference_contact_count".to_owned()))?;
            if contact.contact_site_id != format!("{limb}_foot") {
                return Err(CoreError::Order("airborne_reference_contact_order".to_owned()));
            }
            let phase = current_wave.as_ref().expect("selected wave").ordered_limbs[i].scheduled_phase_step;
            ordered_limbs.push(AirborneReferenceLimbReceipt {
                limb_id: (*limb).to_owned(), scheduled_phase_step: phase,
                full_reference_rate_selected: if absent_contact_selected {
                    absent_contact_reference_selected(feedforward_active, dt, phase, contact.presence, contact.bears_support)
                } else {
                    airborne_reference_selected(feedforward_active, dt, phase, contact.presence, contact.bears_support)
                },
                precommand_contact: contact.clone(),
            });
        }
        Some(AirborneReferenceReceipt {
            source_semantic_step: state.semantic_step, source_sample_time_s: state.sample_time_s,
            source_adapter_capability_sha256: state.adapter_capability_sha256.clone(),
            ordered_limbs, ordered_full_reference_velocity_rad_s: Vec::with_capacity(8),
        })
    } else { None };
    let mut reference = SupportReferenceMemory {
        previous_sample_time_s: Some(state.sample_time_s),
        ordered_target_positions_rad: Vec::with_capacity(8),
        previous_wave: current_wave.clone(),
        ordered_stance_latches: stance_latch.as_ref().map(|r| r.ordered_limbs.iter().map(|l| StanceReferenceLatch {
            limb_id: l.limb_id.clone(), upright_reference_latched: l.next_upright_reference_latched,
        }).collect()),
    };
    let mut slew_limited = Vec::new();
    let reference_velocity_selected = actuation.receipt.policy_id
        == crate::controller::BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID;
    let mut reference_velocities = Vec::with_capacity(8);
    for (index, (command, goal)) in actuation.ordered_commands.iter_mut().zip(goals).enumerate() {
        let actuator = &compiled.morphology.morphology_spec.actuators[index];
        if !goal.is_finite()
            || goal < actuator.minimum_target_position_rad
            || goal > actuator.maximum_target_position_rad
        {
            return Err(CoreError::Actuation(
                "support_plane_composed_goal_bounds".to_owned(),
            ));
        }
        let old = previous.ordered_target_positions_rad[index];
        let maximum_delta = command.maximum_target_speed_rad_s * dt;
        let target = old + (goal - old).clamp(-maximum_delta, maximum_delta);
        let measured = &state.ordered_joint_observations[index];
        let mut raw_velocity = position_gain
            * (target - measured.position_rad.expect("validated position"))
            - rate_damping * measured.velocity_rad_s.expect("validated velocity");
        if wave_selected {
            let comparison = comparison_goals.as_ref().map_or(target, |g| old + (g[index]-old).clamp(-maximum_delta, maximum_delta));
            let mut rate = if feedforward_active && dt > 0.0 {
                ((target-comparison)/dt).clamp(-command.maximum_target_speed_rad_s, command.maximum_target_speed_rad_s)
            } else { 0.0 };
            if let Some(airborne) = &mut airborne_reference {
                // Full actual-reference speed only for the policy's declared
                // absence selector. The V38 fallback arithmetic is exact.
                let full_rate = if dt > 0.0 {
                    ((target-old)/dt).clamp(-command.maximum_target_speed_rad_s, command.maximum_target_speed_rad_s)
                } else { 0.0 };
                airborne.ordered_full_reference_velocity_rad_s.push(full_rate);
                if airborne.ordered_limbs[index/2].full_reference_rate_selected { rate = full_rate; }
            }
            raw_velocity += (1.0+rate_damping)*rate;
            reference_velocities.push(rate);
            comparison_references.push(comparison);
        } else if reference_velocity_selected {
            // Rate of the already bounded/slewed reference, not the unslewed
            // geometric goal. Initial dt=0 preserves the neutral first command.
            let rate = if dt > 0.0 {
                ((target - old) / dt).clamp(-command.maximum_target_speed_rad_s, command.maximum_target_speed_rad_s)
            } else { 0.0 };
            // Velocity-output servo: v_ref + Kp*error - Kd*(v_measured-v_ref).
            // Preserve the old-policy arithmetic path and all final clamps.
            raw_velocity += (1.0 + rate_damping) * rate;
            reference_velocities.push(rate);
        }
        let base_velocity = raw_velocity.clamp(-maximum_controller_speed, maximum_controller_speed)
            * motor_direction;
        let final_velocity = raw_velocity.clamp(
            -command.maximum_target_speed_rad_s,
            command.maximum_target_speed_rad_s,
        ) * motor_direction;
        command.requested_target_position_rad = target;
        command.clamped_target_position_rad = target;
        command.target_velocity_rad_s = final_velocity;
        command.position_saturated = false;
        command.velocity_saturated = raw_velocity.abs() > command.maximum_target_speed_rad_s;
        command.slew_limited = target != goal;
        command.safety_contribution_rad_s = final_velocity - base_velocity;
        if command.slew_limited {
            slew_limited.push(command.actuator_id.clone());
        }
        reference.ordered_target_positions_rad.push(target);
    }
    let smooth_swing = wave_selected || reference_velocity_selected
        || actuation.receipt.policy_id == crate::controller::BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID;
    actuation.receipt.schema_version = if latch_selected {
        "sporespore_recovery_stance_latched_upright_controller_step_receipt_v1"
    } else if upright_selected {
        "sporespore_recovery_upright_stance_controller_step_receipt_v1"
    } else if absent_contact_selected {
        "sporespore_recovery_absent_contact_reference_controller_step_receipt_v1"
    } else if airborne_selected {
        "sporespore_recovery_airborne_reference_controller_step_receipt_v1"
    } else if wave_selected {
        "sporespore_recovery_wave_velocity_controller_step_receipt_v1"
    } else if reference_velocity_selected {
        "sporespore_recovery_reference_velocity_controller_step_receipt_v1"
    } else if smooth_swing {
        "sporespore_recovery_smooth_swing_controller_step_receipt_v1"
    } else if feasible_phases.is_some() {
        "sporespore_recovery_feasible_support_controller_step_receipt_v1"
    } else if floor.is_some() {
        "sporespore_recovery_floor_support_controller_step_receipt_v1"
    } else {
        "sporespore_recovery_support_controller_step_receipt_v1"
    }.to_owned();
    actuation.receipt.recovery_support_plane = Some(SupportPlaneReceipt {
        schema_version: "sporespore_recovery_support_plane_receipt_v1".to_owned(),
        mode_id: if feasible_phases.is_some() { crate::recovery_feasible_support::MODE_ID }
            else if floor.is_some() { crate::recovery_floor_reference::MODE_ID } else { MODE_ID }.to_owned(),
        observation_anatomical_axis_mapping: "forward=body_z;up=body_y;right=-body_x".to_owned(),
        reference_step_duration_s: dt,
        first_step_holds_neutral_reference: previous.previous_sample_time_s.is_none(),
        zero_amplitude_selects_neutral_goal: motion.gait_amplitude == 0.0,
        proposed_torso_height_m: proposed_height,
        unrestricted_plane_inside_joint_limits: proposals
            .iter()
            .all(|p| !p.support_joint_projection_required),
        ordered_limb_proposals: proposals,
        reference_slew_limited_actuator_ids: slew_limited,
        all_limb_contact_claim: false,
        physical_acceptance_authority: false,
        floor_reference: floor.cloned(),
        feasible_support_plan: feasible_plan,
        swing_lift_mode_id: smooth_swing.then(|| crate::controller::PHASE_ONLY_LOADED_PEAK_SWING_LIFT_MODE_ID.to_owned()),
        reference_velocity_mode_id: if measured_pose_selected { Some(crate::recovery_measured_pose_support::MODE.to_owned()) }
            else if latch_selected { Some(crate::controller::STANCE_LATCHED_UPRIGHT_MODE_ID.to_owned()) }
            else if upright_selected { Some(crate::controller::CONTACT_SELECTED_UPRIGHT_STANCE_MODE_ID.to_owned()) }
            else if absent_contact_selected { Some(crate::controller::CONTACT_SELECTED_ABSENT_CONTACT_REFERENCE_MODE_ID.to_owned()) }
            else if airborne_selected { Some(crate::controller::CONTACT_SELECTED_AIRBORNE_REFERENCE_MODE_ID.to_owned()) }
            else if wave_selected { Some(crate::controller::BOUNDED_WAVE_VELOCITY_MODE_ID.to_owned()) }
            else { reference_velocity_selected.then(|| crate::controller::BOUNDED_REFERENCE_VELOCITY_MODE_ID.to_owned()) },
        ordered_reference_velocity_rad_s: (wave_selected || reference_velocity_selected).then_some(reference_velocities),
        wave_velocity: current_wave.map(|wave|WaveVelocityReceipt { previous_wave: previous.previous_wave.clone(),
            current_wave: wave, ordered_comparison_reference_rad: comparison_references, feedforward_active }),
        airborne_reference,
        upright_stance,
        stance_latch,
        support_progression: None,
        measured_support_transfer: None,
        anchored_body_pose: None,
        support_hold_posture: hold_posture_selected.then(|| crate::recovery_support_hold_posture::Receipt {
            schema_version: "sporespore_support_hold_posture_receipt_v1".to_owned(),
            mode_id: if measured_pose_selected {crate::recovery_measured_pose_support::HOLD_MODE}
                else {crate::recovery_support_hold_posture::MODE}.to_owned(),
            source_semantic_step: state.semantic_step, enabled: hold_posture,
            effective_reference_wave: if hold_posture {
                crate::recovery_support_hold_posture::without_lift(reference.previous_wave.as_ref().expect("selected wave"))
            } else { reference.previous_wave.as_ref().expect("selected wave").clone() },
            same_mode_comparison_wave: previous.previous_wave.as_ref().map(|wave| if hold_posture {
                crate::recovery_support_hold_posture::without_lift(wave)
            } else { wave.clone() }),
            scheduled_wave_memory_preserved: true, measured_pose_and_contact_preserved: true,
            physical_acceptance_authority: false,
        }),
    });
    actuation.receipt_sha256 = digest_serializable(&actuation.receipt)?;
    actuation.validate(&compiled.morphology)?;
    Ok(reference)
}
