//! R10AB downward-foot loaded-rise geometry kernel. Not a native route or task gate.
//! Virtual poses are planning variables only; output consists of joint targets.
use super::*;

const IDS: [&str; 4] = [
    "front_left_foot",
    "front_right_foot",
    "rear_left_foot",
    "rear_right_foot",
];
const SPEED: f64 = 4.0;
const TRANSLATION_SPEED: f64 = 0.1;
const LEVEL_BLEND_RATE: f64 = 0.6;
const SCALES: [f64; 5] = [1.0, 0.5, 0.25, 0.125, 0.0625];
const MAX_LATERAL_RESIDUAL: f64 = 0.0005;
type V = [f64; 3];

fn need(ok: bool, code: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10ab_downward_geometry_{code}")))
    }
}
fn add(a: V, b: V) -> V {
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
}
fn sub(a: V, b: V) -> V {
    [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
}
fn inverse(q: Quaternion) -> Quaternion {
    Quaternion {
        x: -q.x,
        y: -q.y,
        z: -q.z,
        w: q.w,
    }
}
fn rotate(q: Quaternion, v: V) -> V {
    let Quaternion { x, y, z, w } = q;
    [
        (1.0 - 2.0 * (y * y + z * z)) * v[0]
            + 2.0 * (x * y - z * w) * v[1]
            + 2.0 * (x * z + y * w) * v[2],
        2.0 * (x * y + z * w) * v[0]
            + (1.0 - 2.0 * (x * x + z * z)) * v[1]
            + 2.0 * (y * z - x * w) * v[2],
        2.0 * (x * z - y * w) * v[0]
            + 2.0 * (y * z + x * w) * v[1]
            + (1.0 - 2.0 * (x * x + y * y)) * v[2],
    ]
}
fn blend(q: Quaternion, mut end: Quaternion, fraction: f64) -> Quaternion {
    if q.x * end.x + q.y * end.y + q.z * end.z + q.w * end.w < 0.0 {
        end = Quaternion {
            x: -end.x,
            y: -end.y,
            z: -end.z,
            w: -end.w,
        };
    }
    let mut out = Quaternion {
        x: q.x + (end.x - q.x) * fraction,
        y: q.y + (end.y - q.y) * fraction,
        z: q.z + (end.z - q.z) * fraction,
        w: q.w + (end.w - q.w) * fraction,
    };
    let n = (out.x * out.x + out.y * out.y + out.z * out.z + out.w * out.w).sqrt();
    out.x /= n;
    out.y /= n;
    out.z /= n;
    out.w /= n;
    out
}
fn vec(v: crate::schema::Vec3) -> V {
    [v.x, v.y, v.z]
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GeometryPlan {
    pub downward_feasible_candidate_count: u32,
    pub selected_fixed_torso_foot_delta_y_m: Option<[f64; 4]>,
    pub schema_version: String,
    pub ordered_target_positions_rad: [f64; 8],
    pub hold_reason: Option<String>,
    pub candidate_count: u32,
    pub feasible_candidate_count: u32,
    pub bearing_reference_count: u32,
    pub measured_joint_boundary_return_count: u32,
    pub seeking_contact: [bool; 4],
    /// Estimated from modeled feet with native bearing flags; not native floor data.
    pub modeled_support_plane_world_y_m: Option<f64>,
    pub selected_virtual_translation_world_m: V,
    pub selected_virtual_level_blend: f64,
    pub selected_candidate_scale: Option<f64>,
    pub maximum_unactuated_lateral_residual_m: f64,
    pub initial_model_cost: Option<f64>,
    pub selected_model_cost: Option<f64>,
    pub source_observation_sha256: String,
    pub native_source_validation_performed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
}

struct Geometry {
    upper: f64,
    lower: f64,
    radius: f64,
    span: f64,
}
impl Geometry {
    fn hip(&self, i: usize) -> V {
        [
            (if i < 2 { 0.2 } else { -0.2 }) * self.span,
            0.0,
            (if i % 2 == 0 { -0.18 } else { 0.18 }) * self.span,
        ]
    }
    fn foot(&self, i: usize, joints: &[f64; 8]) -> V {
        let h = joints[2 * i];
        let k = joints[2 * i + 1];
        add(
            self.hip(i),
            [
                self.upper * h.sin() + self.lower * (h + k).sin(),
                -self.upper * h.cos() - self.lower * (h + k).cos(),
                0.0,
            ],
        )
    }
    fn solve(
        &self,
        feet: &[V; 4],
        p: V,
        q: Quaternion,
        measured: &[f64; 8],
    ) -> Option<([f64; 8], f64)> {
        let mut result = [0.0; 8];
        let mut residual = 0.0_f64;
        for i in 0..4 {
            let local = sub(rotate(inverse(q), sub(feet[i], p)), self.hip(i));
            residual = residual.max(local[2].abs());
            if residual > MAX_LATERAL_RESIDUAL {
                return None;
            }
            let cosine = (local[0] * local[0] + local[1] * local[1]
                - self.upper * self.upper
                - self.lower * self.lower)
                / (2.0 * self.upper * self.lower);
            if !(-1.0..=1.0).contains(&cosine) {
                return None;
            }
            let angle = cosine.acos();
            let mut best: Option<(f64, f64, f64)> = None;
            // Consider both IK branches and choose the closest admissible one.
            // The motion bound prevents a discontinuous branch jump.
            for knee in [angle, -angle] {
                let hip = local[0].atan2(-local[1])
                    - (self.lower * knee.sin()).atan2(self.upper + self.lower * knee.cos());
                if hip.abs() > 1.6 || knee.abs() > 1.1 {
                    continue;
                }
                let dh = hip - measured[2 * i];
                let dk = knee - measured[2 * i + 1];
                if dh.abs().max(dk.abs()) > SPEED * RECOVERY_OUTER_STEP_DURATION_S {
                    continue;
                }
                let distance = dh * dh + dk * dk;
                if best.is_none_or(|old| distance < old.0) {
                    best = Some((distance, hip, knee));
                }
            }
            let (_, hip, knee) = best?;
            result[2 * i] = hip;
            result[2 * i + 1] = knee;
        }
        Some((result, residual))
    }
}

/// Geometry validation only. The future route must first validate exact native
/// source, ownership, energy, phase and morphology authority through its collector.
pub fn downward_geometry(
    descriptor: &BoundedQuadrupedDescriptor,
    o: &RecoveryObservationV3,
) -> Result<GeometryPlan> {
    crate::quadruped::validate_bounded_quadruped_descriptor(descriptor)?;
    need(
        digest_serializable(descriptor)? == R23D60_SELECTED_S169_DESCRIPTOR_SHA256,
        "descriptor",
    )?;
    need(
        o.schema_version == RECOVERY_OBSERVATION_V3_VERSION
            && o.semantic_step == o.state.semantic_step
            && o.outer_step_duration_s == RECOVERY_OUTER_STEP_DURATION_S,
        "observation_clock",
    )?;
    let q = o.state.base_pose_world.orientation_xyzw;
    q.validate("r10ab_downward_geometry_pose")?;
    let p = vec(o.state.base_pose_world.position_m);
    let com = vec(o.center_of_mass.position_world_m);
    need(
        p.into_iter().chain(com).all(f64::is_finite) && o.center_of_mass.source_measurement,
        "pose_com",
    )?;
    let joints = &o.state.ordered_joint_observations;
    need(joints.len() == 8, "joint_count")?;
    let mut measured = [0.0; 8];
    for (i, j) in joints.iter().enumerate() {
        let position = j
            .position_rad
            .ok_or_else(|| CoreError::Frame("r10ab_downward_geometry_joint_missing".to_owned()))?;
        let limit = if i % 2 == 0 { 1.6 } else { 1.1 };
        // Keep the source angle exact, including real solver overshoot. An
        // admissible command must still fit BOTH the authored target limits
        // and the one-step displacement bound from that actual source value.
        need(
            j.joint_id == ORDERED_JOINT_IDS[i]
                && j.validity.position
                && position.is_finite()
                && position.abs() <= limit + SPEED * RECOVERY_OUTER_STEP_DURATION_S,
            "joint",
        )?;
        measured[i] = position;
    }
    need(
        o.state.ordered_contact_observations.len() == 4
            && o.ordered_foot_bearing_observations.len() == 4,
        "contact_count",
    )?;
    let g = Geometry {
        upper: 0.35 * descriptor.upper_length_fraction,
        lower: 0.35 * (1.0 - descriptor.upper_length_fraction),
        radius: 0.04 * descriptor.foot_radius_scale,
        span: descriptor.hip_span_scale,
    };
    let feet = std::array::from_fn(|i| add(p, rotate(q, g.foot(i, &measured))));
    let mut bearing = [false; 4];
    let mut floors = Vec::new();
    for i in 0..4 {
        let c = &o.state.ordered_contact_observations[i];
        let load = &o.ordered_foot_bearing_observations[i];
        need(
            c.contact_site_id == IDS[i]
                && load.contact_site_id == IDS[i]
                && c.presence.is_some()
                && c.bears_support.is_some()
                && load.source_measurement
                && load.bearing_normal_impulse_ns.is_finite()
                && load.bearing_normal_impulse_ns >= 0.0,
            "contact",
        )?;
        bearing[i] = c.presence == Some(true)
            && c.bears_support == Some(true)
            && load.ordinary_unilateral_contact
            && load.bearing_normal_impulse_ns > 0.0;
        if bearing[i] {
            floors.push(feet[i][1] - g.radius);
        }
    }
    let bounded_hold = std::array::from_fn(|i| {
        let limit = if i % 2 == 0 { 1.6 } else { 1.1 };
        measured[i].clamp(-limit, limit)
    });
    let mut out = GeometryPlan {
        downward_feasible_candidate_count: 0,
        selected_fixed_torso_foot_delta_y_m: None,
        schema_version: "sporespore_r10ab_downward_rise_geometry_plan_v1".to_owned(),
        ordered_target_positions_rad: bounded_hold,
        hold_reason: None,
        candidate_count: 0,
        feasible_candidate_count: 0,
        bearing_reference_count: floors.len() as u32,
        seeking_contact: bearing.map(|b| !b),
        measured_joint_boundary_return_count: (0..8)
            .filter(|i| bounded_hold[*i] != measured[*i])
            .count() as u32,
        modeled_support_plane_world_y_m: None,
        selected_virtual_translation_world_m: [0.0; 3],
        selected_virtual_level_blend: 0.0,
        selected_candidate_scale: None,
        maximum_unactuated_lateral_residual_m: 0.0,
        initial_model_cost: None,
        selected_model_cost: None,
        source_observation_sha256: digest_serializable(o)?,
        native_source_validation_performed: false,
        physical_acceptance_authority: false,
        release_authority: false,
        world_build_count: 0,
        solver_step_count: 0,
    };
    if floors.is_empty() {
        out.hold_reason = Some("no_bearing_reference".to_owned());
        return Ok(out);
    }
    floors.sort_by(f64::total_cmp);
    let floor = (floors[(floors.len() - 1) / 2] + floors[floors.len() / 2]) * 0.5;
    out.modeled_support_plane_world_y_m = Some(floor);
    let forward = rotate(q, [1.0, 0.0, 0.0]);
    let horizontal = forward[0].hypot(forward[2]);
    if horizontal < 1e-12 {
        out.hold_reason = Some("undefined_horizontal_heading".to_owned());
        return Ok(out);
    }
    let yaw = (-forward[2]).atan2(forward[0]);
    let flat = Quaternion {
        x: 0.0,
        y: (yaw * 0.5).sin(),
        z: 0.0,
        w: (yaw * 0.5).cos(),
    };
    let com_local = rotate(inverse(q), sub(com, p));
    let center = [
        feet.iter().map(|f| f[0]).sum::<f64>() / 4.0,
        0.0,
        feet.iter().map(|f| f[2]).sum::<f64>() / 4.0,
    ];
    let goal_height = floor + 0.92 * (g.upper + g.lower) + g.radius;
    let cost = |position: V, rotation: Quaternion, targets: &[V; 4]| {
        let predicted_com = add(position, rotate(rotation, com_local));
        let tilt = rotate(rotation, [0.0, 1.0, 0.0])[1].clamp(-1.0, 1.0).acos();
        (predicted_com[0] - center[0]).powi(2)
            + (predicted_com[2] - center[2]).powi(2)
            + (position[1] - goal_height).powi(2)
            + 0.04 * tilt * tilt
            + (0..4)
                .filter(|i| !bearing[*i])
                .map(|i| (targets[i][1] - floor - g.radius).max(0.0).powi(2))
                .sum::<f64>()
    };
    let initial = cost(p, q, &feet);
    let mut best = initial;
    out.initial_model_cost = Some(initial);
    out.selected_model_cost = Some(initial);
    for scale in SCALES {
        let distance = TRANSLATION_SPEED * RECOVERY_OUTER_STEP_DURATION_S * scale;
        for dx in [-distance, 0.0, distance] {
            for dy in [-distance, 0.0, distance] {
                for fraction in [-1.0, 0.0, 1.0]
                    .map(|sign| sign * LEVEL_BLEND_RATE * RECOVERY_OUTER_STEP_DURATION_S * scale)
                {
                    out.candidate_count += 1;
                    let delta = [dx * yaw.cos(), dy, -dx * yaw.sin()];
                    let position = add(p, delta);
                    let rotation = blend(q, flat, fraction);
                    let mut targets = feet;
                    for i in 0..4 {
                        if !bearing[i] && targets[i][1] > floor + g.radius {
                            targets[i][1] = (targets[i][1] - distance).max(floor + g.radius);
                        }
                    }
                    let Some((planned, residual)) =
                        g.solve(&targets, position, rotation, &measured)
                    else {
                        continue;
                    };
                    out.feasible_candidate_count += 1;
                    // The torso stays at its measured pose for this direction
                    // check. A virtual rise must command every foot downward;
                    // virtual leveling alone must not lift a supporting foot.
                    let foot_dy: [f64; 4] = std::array::from_fn(|i| {
                        rotate(q, sub(g.foot(i, &planned), g.foot(i, &measured)))[1]
                    });
                    if dy <= 0.0 || foot_dy.iter().any(|y| *y > -0.25 * dy + 1e-12) {
                        continue;
                    }
                    out.downward_feasible_candidate_count += 1;
                    let value = cost(position, rotation, &targets);
                    if value < best - 1e-12 {
                        best = value;
                        out.ordered_target_positions_rad = planned;
                        out.selected_fixed_torso_foot_delta_y_m = Some(foot_dy);
                        out.selected_candidate_scale = Some(scale);
                        out.selected_virtual_translation_world_m = delta;
                        out.selected_virtual_level_blend = fraction;
                        out.maximum_unactuated_lateral_residual_m = residual;
                        out.selected_model_cost = Some(value);
                    }
                }
            }
        }
    }
    if best == initial {
        out.hold_reason = Some("no_feasible_downward_cost_decreasing_candidate".to_owned());
    }
    Ok(out)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DownwardRisePlan {
    pub schema_version: String,
    pub phase: RecoveryPhaseV1,
    pub mode: String,
    pub ordered_target_positions_rad: [f64; 8],
    pub qualified_support: [bool; 4],
    pub load_deficit_fraction: [f64; 4],
    pub candidate_count: u32,
    pub feasible_candidate_count: u32,
    pub selected_scale: Option<f64>,
    pub virtual_translation_world_m: V,
    pub virtual_level_blend: f64,
    pub maximum_unactuated_lateral_residual_m: f64,
    pub hold_reason: Option<String>,
    pub rise_geometry: Option<GeometryPlan>,
    pub source_observation_sha256: String,
    pub native_source_validation_performed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
}

/// Preserve the predecessor's exact validation, support phase, and weak-load
/// fallback. Only fully native-qualified RaiseBody inputs reach the new search.
/// The work bound is 270 candidates for loaded rise (135 validation + 135 new),
/// and at most 195 for the unchanged weak-load fallback. No physics runs here.
pub fn reference(
    descriptor: &BoundedQuadrupedDescriptor,
    observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
) -> Result<DownwardRisePlan> {
    let prior = super::partial_load_seeking_control::reference(descriptor, observation, phase)?;
    let mut result = DownwardRisePlan {
        schema_version: "sporespore_r10ab_downward_rise_plan_v1".to_owned(),
        phase: prior.phase,
        mode: prior.mode,
        ordered_target_positions_rad: prior.ordered_target_positions_rad,
        qualified_support: prior.qualified_support,
        load_deficit_fraction: prior.load_deficit_fraction,
        candidate_count: prior.candidate_count,
        feasible_candidate_count: prior.feasible_candidate_count,
        selected_scale: prior.selected_scale,
        virtual_translation_world_m: prior.virtual_translation_world_m,
        virtual_level_blend: prior.virtual_level_blend,
        maximum_unactuated_lateral_residual_m: prior.maximum_unactuated_lateral_residual_m,
        hold_reason: prior.hold_reason,
        rise_geometry: None,
        source_observation_sha256: prior.source_observation_sha256,
        native_source_validation_performed: prior.native_source_validation_performed,
        physical_acceptance_authority: prior.physical_acceptance_authority,
        release_authority: prior.release_authority,
        world_build_count: prior.world_build_count,
        solver_step_count: prior.solver_step_count,
    };
    if phase == RecoveryPhaseV1::RaiseBody && result.qualified_support.into_iter().all(|b| b) {
        let geometry = downward_geometry(descriptor, observation)?;
        result.mode = "loaded_downward_rise".to_owned();
        result.ordered_target_positions_rad = geometry.ordered_target_positions_rad;
        result.candidate_count = geometry.candidate_count;
        result.feasible_candidate_count = geometry.downward_feasible_candidate_count;
        result.selected_scale = geometry.selected_candidate_scale;
        result.virtual_translation_world_m = geometry.selected_virtual_translation_world_m;
        result.virtual_level_blend = geometry.selected_virtual_level_blend;
        result.maximum_unactuated_lateral_residual_m =
            geometry.maximum_unactuated_lateral_residual_m;
        result.hold_reason = geometry.hold_reason.clone();
        result.rise_geometry = Some(geometry);
    }
    Ok(result)
}

#[cfg(test)]
#[path = "tests/partial_downward_rise_control_tests.rs"]
mod tests;
