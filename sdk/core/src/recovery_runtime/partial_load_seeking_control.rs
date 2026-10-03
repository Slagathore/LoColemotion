//! R10AA phase-specific load-seeking geometry. No native route or task authority.
//! Virtual poses are planning variables only; output consists of joint targets.
use super::*;

const SPEED: f64 = 4.0;
const TRANSLATION_SPEED: f64 = 0.1;
const LEVEL_BLEND_RATE: f64 = 0.6;
const SCALES: [f64; 5] = [1.0, 0.5, 0.25, 0.125, 0.0625];
const MAX_LATERAL_RESIDUAL: f64 = 0.0005;
const LOAD_THRESHOLD: f64 = 0.019293;
type V = [f64; 3];

fn need(ok: bool, code: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10aa_load_geometry_{code}")))
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

struct Geometry {
    upper: f64,
    lower: f64,
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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LoadSeekingPlan {
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
    pub rise_geometry: Option<super::partial_pose_geometry_control::GeometryPlan>,
    pub source_observation_sha256: String,
    pub native_source_validation_performed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
}

/// Task phase is supplied by the future validating composition, never inferred
/// from geometry. Native load is feedback, not a force applied by this kernel.
pub fn reference(
    descriptor: &BoundedQuadrupedDescriptor,
    observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
) -> Result<LoadSeekingPlan> {
    need(
        matches!(
            phase,
            RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody
        ),
        "phase",
    )?;
    // Preserve the reviewed descriptor/clock/joint/contact/COM checks, including
    // bounded returns from measured solver overshoot. Its old plan is not used
    // as a support command. The finite work bound includes its 135 candidates.
    let validated = super::partial_pose_geometry_control::reference(descriptor, observation)?;
    let measured = std::array::from_fn(|i| {
        observation.state.ordered_joint_observations[i]
            .position_rad
            .unwrap()
    });
    let qualified = std::array::from_fn(|i| {
        let c = &observation.state.ordered_contact_observations[i];
        let b = &observation.ordered_foot_bearing_observations[i];
        c.presence == Some(true)
            && c.bears_support == Some(true)
            && b.ordinary_unilateral_contact
            && b.bearing_normal_impulse_ns >= LOAD_THRESHOLD
    });
    let deficit: [f64; 4] = std::array::from_fn(|i| {
        let c = &observation.state.ordered_contact_observations[i];
        let b = &observation.ordered_foot_bearing_observations[i];
        let load = if c.presence == Some(true)
            && c.bears_support == Some(true)
            && b.ordinary_unilateral_contact
        {
            b.bearing_normal_impulse_ns
        } else {
            0.0
        };
        ((LOAD_THRESHOLD - load) / LOAD_THRESHOLD).clamp(0.0, 1.0)
    });
    let mut result = LoadSeekingPlan {
        schema_version: "sporespore_r10aa_load_seeking_plan_v1".to_owned(),
        phase,
        mode: "seek_distal_load".to_owned(),
        ordered_target_positions_rad: std::array::from_fn(|i| {
            measured[i].clamp(
                -if i % 2 == 0 { 1.6 } else { 1.1 },
                if i % 2 == 0 { 1.6 } else { 1.1 },
            )
        }),
        qualified_support: qualified,
        load_deficit_fraction: deficit,
        candidate_count: 0,
        feasible_candidate_count: 0,
        selected_scale: None,
        virtual_translation_world_m: [0.0; 3],
        virtual_level_blend: 0.0,
        maximum_unactuated_lateral_residual_m: 0.0,
        hold_reason: None,
        rise_geometry: None,
        source_observation_sha256: digest_serializable(observation)?,
        native_source_validation_performed: false,
        physical_acceptance_authority: false,
        release_authority: false,
        world_build_count: 0,
        solver_step_count: 0,
    };
    if qualified.into_iter().all(|b| b) {
        if phase == RecoveryPhaseV1::RaiseBody {
            result.mode = "loaded_geometry_rise".to_owned();
            result.ordered_target_positions_rad = validated.ordered_target_positions_rad;
            result.virtual_translation_world_m = validated.selected_virtual_translation_world_m;
            result.virtual_level_blend = validated.selected_virtual_level_blend;
            result.maximum_unactuated_lateral_residual_m =
                validated.maximum_unactuated_lateral_residual_m;
            result.hold_reason = validated.hold_reason.clone();
            result.rise_geometry = Some(validated);
        } else {
            result.mode = "hold_qualified_support".to_owned();
            result.hold_reason = Some("await_original_task_phase_transition".to_owned());
        }
        return Ok(result);
    }
    let p = vec(observation.state.base_pose_world.position_m);
    let q = observation.state.base_pose_world.orientation_xyzw;
    let forward = rotate(q, [1.0, 0.0, 0.0]);
    if forward[0].hypot(forward[2]) < 1e-12 {
        result.hold_reason = Some("undefined_horizontal_heading".to_owned());
        return Ok(result);
    }
    let yaw = (-forward[2]).atan2(forward[0]);
    let flat = Quaternion {
        x: 0.0,
        y: (yaw * 0.5).sin(),
        z: 0.0,
        w: (yaw * 0.5).cos(),
    };
    let g = Geometry {
        upper: 0.35 * descriptor.upper_length_fraction,
        lower: 0.35 * (1.0 - descriptor.upper_length_fraction),
        span: descriptor.hip_span_scale,
    };
    let feet: [V; 4] = std::array::from_fn(|i| add(p, rotate(q, g.foot(i, &measured))));
    let mut best: Option<(f64, f64)> = None;
    for scale in SCALES {
        let distance = TRANSLATION_SPEED * RECOVERY_OUTER_STEP_DURATION_S * scale;
        for dx in [-distance, 0.0, distance] {
            for dy in [0.0, -distance] {
                for fraction in [
                    0.0,
                    LEVEL_BLEND_RATE * RECOVERY_OUTER_STEP_DURATION_S * scale,
                ] {
                    result.candidate_count += 1;
                    let delta = [dx * yaw.cos(), dy, -dx * yaw.sin()];
                    let position = add(p, delta);
                    let rotation = blend(q, flat, fraction);
                    let mut targets = feet;
                    for i in 0..4 {
                        targets[i][1] -= distance * deficit[i];
                    }
                    let Some((planned, residual)) =
                        g.solve(&targets, position, rotation, &measured)
                    else {
                        continue;
                    };
                    result.feasible_candidate_count += 1;
                    let motion = dx * dx + dy * dy + 0.04 * fraction * fraction;
                    if best.is_none_or(|old| scale > old.0 || (scale == old.0 && motion < old.1)) {
                        best = Some((scale, motion));
                        result.ordered_target_positions_rad = planned;
                        result.selected_scale = Some(scale);
                        result.virtual_translation_world_m = delta;
                        result.virtual_level_blend = fraction;
                        result.maximum_unactuated_lateral_residual_m = residual;
                    }
                }
            }
        }
    }
    if best.is_none() {
        result.hold_reason = Some("no_feasible_load_seeking_candidate".to_owned());
    }
    Ok(result)
}

#[cfg(test)]
#[path = "tests/partial_load_seeking_control_tests.rs"]
mod tests;
