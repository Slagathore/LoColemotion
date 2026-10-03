//! R10AJ weak-support hip placement kernel. No native admission or task authority.
use super::*;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HipRecenterGeometry {
    pub schema_version: String,
    pub ordered_target_positions_rad: [f64; 8],
    pub desired_hip_angles_rad: [Option<f64>; 4],
    pub hip_step_bounds_rad: [f64; 4],
    pub explicit_limit_return_joints: Vec<usize>,
    pub hold_reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HipRecenterPlan {
    pub schema_version: String,
    pub phase: RecoveryPhaseV1,
    pub mode: String,
    pub ordered_target_positions_rad: [f64; 8],
    pub qualified_support: [bool; 4],
    pub source_observation_sha256: String,
    pub baseline_reference: super::partial_concurrent_load_rise_control::ConcurrentLoadRisePlan,
    pub hip_recenter_geometry: Option<HipRecenterGeometry>,
    pub native_source_validation_performed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
}

fn recenter(
    descriptor: &BoundedQuadrupedDescriptor,
    observation: &RecoveryObservationV3,
) -> Result<HipRecenterGeometry> {
    // The original reference validates morphology, quaternion, clock, ordered
    // joints and source ranges before this function is called. Source angles
    // remain exact; any solver overshoot gets an explicit bounded return target.
    let measured: [f64; 8] = std::array::from_fn(|i| {
        observation.state.ordered_joint_observations[i]
            .position_rad
            .unwrap()
    });
    let mut targets = std::array::from_fn(|i| {
        let limit = if i % 2 == 0 { 1.6 } else { 1.1 };
        measured[i].clamp(-limit, limit)
    });
    let mut out = HipRecenterGeometry {
        schema_version: "sporespore_r10aj_hip_recenter_geometry_v1".to_owned(),
        ordered_target_positions_rad: targets,
        desired_hip_angles_rad: [None; 4],
        hip_step_bounds_rad: [0.0; 4],
        explicit_limit_return_joints: (0..8).filter(|i| targets[*i] != measured[*i]).collect(),
        hold_reason: None,
    };
    let q = observation.state.base_pose_world.orientation_xyzw;
    // World gravity transformed to the torso frame, projected into each
    // authored two-hinge sagittal plane. This is geometry, not a contact force.
    let down_x = -2.0 * (q.x * q.y + q.z * q.w);
    let down_y = -(1.0 - 2.0 * (q.x * q.x + q.z * q.z));
    if down_x.hypot(down_y) < 1e-12 {
        out.hold_reason = Some("gravity_normal_to_joint_plane".to_owned());
        return Ok(out);
    }
    let desired_leg_angle = down_x.atan2(-down_y);
    let upper = 0.35 * descriptor.upper_length_fraction;
    let lower = 0.35 - upper;
    for i in 0..4 {
        let knee = targets[2 * i + 1];
        let beta = (lower * knee.sin()).atan2(upper + lower * knee.cos());
        let raw = desired_leg_angle - beta;
        let mut goal = raw - std::f64::consts::TAU;
        for candidate in [raw, raw + std::f64::consts::TAU] {
            if (candidate - measured[2 * i]).abs() < (goal - measured[2 * i]).abs() {
                goal = candidate;
            }
        }
        goal = goal.clamp(-1.6, 1.6);
        let radius = (upper + lower * knee.cos()).hypot(lower * knee.sin());
        let bound = (4.0 * RECOVERY_OUTER_STEP_DURATION_S)
            .min(0.1 * RECOVERY_OUTER_STEP_DURATION_S / radius);
        let delta = (goal - measured[2 * i]).clamp(-bound, bound);
        targets[2 * i] = (measured[2 * i] + delta).clamp(-1.6, 1.6);
        out.desired_hip_angles_rad[i] = Some(goal);
        out.hip_step_bounds_rad[i] = bound;
    }
    if targets.iter().zip(measured).any(|(target, source)| {
        (target - source).abs() > 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-12
    }) {
        return Err(CoreError::Frame(
            "r10aj_geometry_joint_step_bound".to_owned(),
        ));
    }
    out.ordered_target_positions_rad = targets;
    Ok(out)
}

/// Mathematical reference only: a future composition must validate native
/// identity, ownership, energy, phase and termination before any application.
pub fn reference(
    descriptor: &BoundedQuadrupedDescriptor,
    observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
) -> Result<HipRecenterPlan> {
    let baseline =
        super::partial_concurrent_load_rise_control::reference(descriptor, observation, phase)?;
    let mut out = HipRecenterPlan {
        schema_version: "sporespore_r10aj_hip_recenter_plan_v1".to_owned(),
        phase,
        mode: "unchanged_v25_reference".to_owned(),
        ordered_target_positions_rad: baseline.ordered_target_positions_rad,
        qualified_support: baseline.qualified_support,
        source_observation_sha256: digest_serializable(observation)?,
        baseline_reference: baseline,
        hip_recenter_geometry: None,
        native_source_validation_performed: false,
        physical_acceptance_authority: false,
        release_authority: false,
        world_build_count: 0,
        solver_step_count: 0,
    };
    if phase == RecoveryPhaseV1::RaiseBody && !out.qualified_support.into_iter().all(|v| v) {
        let geometry = recenter(descriptor, observation)?;
        out.mode = if geometry.hold_reason.is_some() {
            "hip_recenter_explicit_hold"
        } else {
            "weak_support_hip_recenter"
        }
        .to_owned();
        out.ordered_target_positions_rad = geometry.ordered_target_positions_rad;
        out.hip_recenter_geometry = Some(geometry);
    }
    Ok(out)
}

#[cfg(test)]
#[path = "tests/partial_hip_recenter_control_tests.rs"]
mod tests;
