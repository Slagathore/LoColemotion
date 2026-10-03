//! R10AM support-anchored joint-target search. No world or task authority.
use super::*;
const SCALES: [f64; 5] = [1.0, 0.5, 0.25, 0.125, 0.0625];
const DT: f64 = RECOVERY_OUTER_STEP_DURATION_S;
const LATERAL: f64 = 0.0005;
type V = [f64; 3];

fn need(ok: bool, code: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10am_geometry_{code}")))
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
pub struct AnchoredGeometry {
    pub schema_version: String,
    pub positive_bearing: [bool; 4],
    pub ordered_target_positions_rad: [f64; 8],
    pub candidate_count: u32,
    pub feasible_candidate_count: u32,
    pub selected_scale: Option<f64>,
    pub virtual_translation_world_m: V,
    pub virtual_level_blend: f64,
    pub initial_cost: Option<f64>,
    pub selected_cost: Option<f64>,
    pub hold_reason: Option<String>,
    pub maximum_anchor_error_m: f64,
}

struct Model {
    p: V,
    measured: [f64; 8],
    feet: [V; 4],
    bearing: [bool; 4],
    upper: f64,
    lower: f64,
    span: f64,
    radius: f64,
    floor: f64,
    com_local: V,
    center: V,
    goal_y: f64,
    yaw: f64,
    flat: Quaternion,
}
fn norm(v: V) -> f64 {
    v.into_iter().map(|x| x * x).sum::<f64>().sqrt()
}
fn within(source: [f64; 2], target: [f64; 2]) -> bool {
    source
        .into_iter()
        .zip(target)
        .zip([1.6, 1.1])
        .all(|((q, t), limit)| t.abs() <= limit && (t - q).abs() <= 4.0 * DT + 1e-12)
}
impl Model {
    fn hip(&self, i: usize) -> V {
        [
            if i < 2 {
                0.2 * self.span
            } else {
                -0.2 * self.span
            },
            0.0,
            if i % 2 == 0 {
                -0.18 * self.span
            } else {
                0.18 * self.span
            },
        ]
    }
    fn local(&self, joints: [f64; 2]) -> V {
        let [h, k] = joints;
        [
            self.upper * h.sin() + self.lower * (h + k).sin(),
            -self.upper * h.cos() - self.lower * (h + k).cos(),
            0.0,
        ]
    }
    fn endpoint(&self, i: usize, joints: [f64; 2], p: V, q: Quaternion) -> V {
        add(p, rotate(q, add(self.hip(i), self.local(joints))))
    }
    fn anchor(&self, i: usize, p: V, q: Quaternion) -> Option<[f64; 2]> {
        let local = sub(rotate(inverse(q), sub(self.feet[i], p)), self.hip(i));
        if local[2].abs() > LATERAL {
            return None;
        }
        let cosine = (local[0] * local[0] + local[1] * local[1]
            - self.upper * self.upper
            - self.lower * self.lower)
            / (2.0 * self.upper * self.lower);
        if !(-1.0..=1.0).contains(&cosine) {
            return None;
        }
        let source = [self.measured[2 * i], self.measured[2 * i + 1]];
        let mut best: Option<(f64, [f64; 2])> = None;
        for knee in [cosine.acos(), -cosine.acos()] {
            let hip = local[0].atan2(-local[1])
                - (self.lower * knee.sin()).atan2(self.upper + self.lower * knee.cos());
            let target = [hip, knee];
            if !within(source, target) {
                continue;
            }
            let rank = source
                .into_iter()
                .zip(target)
                .map(|(a, b)| (a - b) * (a - b))
                .sum();
            if best.is_none_or(|old| rank < old.0) {
                best = Some((rank, target));
            }
        }
        best.map(|x| x.1)
    }
    fn placement(&self, i: usize, p: V, q: Quaternion, distance: f64) -> Option<[f64; 2]> {
        let source = [self.measured[2 * i], self.measured[2 * i + 1]];
        let mut desired = self.feet[i];
        desired[1] -= distance;
        let target_local = sub(rotate(inverse(q), sub(desired, p)), self.hip(i));
        let start = self.local(source);
        let error = sub(target_local, start);
        let [h, k] = source;
        let j = [
            [
                self.upper * h.cos() + self.lower * (h + k).cos(),
                self.lower * (h + k).cos(),
            ],
            [
                self.upper * h.sin() + self.lower * (h + k).sin(),
                self.lower * (h + k).sin(),
            ],
        ];
        let a = j[0].into_iter().map(|x| x * x).sum::<f64>() + 1e-4;
        let b = j[0].into_iter().zip(j[1]).map(|(x, y)| x * y).sum::<f64>();
        let c = j[1].into_iter().map(|x| x * x).sum::<f64>() + 1e-4;
        let determinant = a * c - b * b;
        let solved = [
            (c * error[0] - b * error[1]) / determinant,
            (-b * error[0] + a * error[1]) / determinant,
        ];
        let mut delta: [f64; 2] =
            std::array::from_fn(|col| (0..2).map(|r| j[r][col] * solved[r]).sum());
        let size = delta[0].abs().max(delta[1].abs());
        if size > 4.0 * DT {
            delta = delta.map(|x| x * (4.0 * DT) / size);
        }
        let mut best: Option<(f64, [f64; 2])> = None;
        for scale in [1.0, 0.5, 0.25, 0.125, 0.0625, 0.0] {
            let target = std::array::from_fn(|j| {
                (source[j] + scale * delta[j]).clamp(-[1.6, 1.1][j], [1.6, 1.1][j])
            });
            if !within(source, target) || norm(sub(self.local(target), start)) > 0.1 * DT + 1e-12 {
                continue;
            }
            let endpoint = self.endpoint(i, target, p, q);
            if endpoint[1] > self.feet[i][1] + 1e-12 {
                continue;
            }
            let rank = sub(endpoint, desired).into_iter().map(|x| x * x).sum();
            if best.is_none_or(|old| rank < old.0) {
                best = Some((rank, target));
            }
        }
        best.map(|x| x.1)
    }
    fn cost(&self, p: V, q: Quaternion, feet: &[V; 4]) -> f64 {
        let com = add(p, rotate(q, self.com_local));
        let tilt = rotate(q, [0.0, 1.0, 0.0])[1].clamp(-1.0, 1.0).acos();
        let height = if self.bearing.into_iter().all(|b| b) {
            self.goal_y
        } else {
            self.p[1]
        };
        (com[0] - self.center[0]).powi(2)
            + (com[2] - self.center[2]).powi(2)
            + 0.04 * tilt * tilt
            + (p[1] - height).powi(2)
            + (0..4)
                .filter(|i| !self.bearing[*i])
                .map(|i| (feet[i][1] - self.floor - self.radius).max(0.0).powi(2))
                .sum::<f64>()
    }
}

fn geometry(d: &BoundedQuadrupedDescriptor, o: &RecoveryObservationV3) -> Result<AnchoredGeometry> {
    let p = vec(o.state.base_pose_world.position_m);
    let q = o.state.base_pose_world.orientation_xyzw;
    let measured =
        std::array::from_fn(|i| o.state.ordered_joint_observations[i].position_rad.unwrap());
    let bearing = std::array::from_fn(|i| {
        let c = &o.state.ordered_contact_observations[i];
        let b = &o.ordered_foot_bearing_observations[i];
        c.presence == Some(true)
            && c.bears_support == Some(true)
            && b.ordinary_unilateral_contact
            && b.bearing_normal_impulse_ns > 0.0
    });
    let mut out = AnchoredGeometry {
        schema_version: "sporespore_r10am_support_anchored_geometry_v1".to_owned(),
        positive_bearing: bearing,
        ordered_target_positions_rad: std::array::from_fn(|i| {
            measured[i].clamp(
                -if i % 2 == 0 { 1.6 } else { 1.1 },
                if i % 2 == 0 { 1.6 } else { 1.1 },
            )
        }),
        candidate_count: 0,
        feasible_candidate_count: 0,
        selected_scale: None,
        virtual_translation_world_m: [0.0; 3],
        virtual_level_blend: 0.0,
        initial_cost: None,
        selected_cost: None,
        hold_reason: None,
        maximum_anchor_error_m: 0.0,
    };
    let forward = rotate(q, [1.0, 0.0, 0.0]);
    let yaw = (-forward[2]).atan2(forward[0]);
    let flat = Quaternion {
        x: 0.0,
        y: (yaw * 0.5).sin(),
        z: 0.0,
        w: (yaw * 0.5).cos(),
    };
    let mut m = Model {
        p,
        measured,
        feet: [[0.0; 3]; 4],
        bearing,
        upper: 0.35 * d.upper_length_fraction,
        lower: 0.35 * (1.0 - d.upper_length_fraction),
        span: d.hip_span_scale,
        radius: 0.04 * d.foot_radius_scale,
        floor: 0.0,
        com_local: rotate(inverse(q), sub(vec(o.center_of_mass.position_world_m), p)),
        center: [0.0; 3],
        goal_y: 0.0,
        yaw,
        flat,
    };
    m.feet = std::array::from_fn(|i| m.endpoint(i, [measured[2 * i], measured[2 * i + 1]], p, q));
    let mut floors: Vec<f64> = (0..4)
        .filter(|i| bearing[*i])
        .map(|i| m.feet[i][1] - m.radius)
        .collect();
    if floors.is_empty() {
        out.hold_reason = Some("no_positive_bearing_plane".to_owned());
        return Ok(out);
    }
    if forward[0].hypot(forward[2]) < 1e-12 {
        out.hold_reason = Some("undefined_horizontal_heading".to_owned());
        return Ok(out);
    }
    floors.sort_by(f64::total_cmp);
    m.floor = (floors[(floors.len() - 1) / 2] + floors[floors.len() / 2]) * 0.5;
    m.goal_y = m.floor + 0.92 * (m.upper + m.lower) + m.radius;
    m.center = std::array::from_fn(|axis| m.feet.iter().map(|f| f[axis]).sum::<f64>() / 4.0);
    let initial = m.cost(p, q, &m.feet);
    let mut best = initial;
    out.initial_cost = Some(initial);
    out.selected_cost = Some(initial);
    for scale in SCALES {
        let distance = 0.1 * DT * scale;
        for dx in [-distance, 0.0, distance] {
            for dy in [-distance, 0.0, distance] {
                for fraction in [0.0, 0.6 * DT * scale] {
                    out.candidate_count += 1;
                    let delta = [dx * m.yaw.cos(), dy, -dx * m.yaw.sin()];
                    let position = add(p, delta);
                    let rotation = blend(q, m.flat, fraction);
                    if rotate(rotation, [0.0, 1.0, 0.0])[1] < rotate(q, [0.0, 1.0, 0.0])[1] - 1e-12
                    {
                        continue;
                    }
                    let mut targets = [0.0; 8];
                    let mut valid = true;
                    for i in 0..4 {
                        let plan = if bearing[i] {
                            m.anchor(i, position, rotation)
                        } else {
                            m.placement(i, position, rotation, distance)
                        };
                        let Some(t) = plan else {
                            valid = false;
                            break;
                        };
                        targets[2 * i] = t[0];
                        targets[2 * i + 1] = t[1];
                    }
                    if !valid {
                        continue;
                    }
                    let endpoints = std::array::from_fn(|i| {
                        m.endpoint(i, [targets[2 * i], targets[2 * i + 1]], position, rotation)
                    });
                    out.feasible_candidate_count += 1;
                    let value = m.cost(position, rotation, &endpoints);
                    if value < best - 1e-12 {
                        best = value;
                        out.ordered_target_positions_rad = targets;
                        out.selected_scale = Some(scale);
                        out.virtual_translation_world_m = delta;
                        out.virtual_level_blend = fraction;
                        out.selected_cost = Some(value);
                        out.maximum_anchor_error_m = (0..4)
                            .filter(|i| bearing[*i])
                            .map(|i| norm(sub(endpoints[i], m.feet[i])))
                            .fold(0.0, f64::max);
                        need(
                            out.maximum_anchor_error_m <= LATERAL + 1e-12,
                            "anchor_endpoint",
                        )?;
                    }
                }
            }
        }
    }
    if out.selected_scale.is_none() {
        out.hold_reason = Some(
            if out.feasible_candidate_count == 0 {
                "no_feasible_candidate"
            } else {
                "no_cost_decreasing_candidate"
            }
            .to_owned(),
        );
    }
    Ok(out)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupportAnchoredPlan {
    pub schema_version: String,
    pub phase: RecoveryPhaseV1,
    pub mode: String,
    pub ordered_target_positions_rad: [f64; 8],
    pub source_observation_sha256: String,
    pub baseline_reference: super::partial_concurrent_load_rise_control::ConcurrentLoadRisePlan,
    pub support_anchored_geometry: Option<AnchoredGeometry>,
    pub native_source_validation_performed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
}

/// Geometry only. A native composition must enforce source, ownership, phase,
/// energy and terminal admission before any returned command can be applied.
pub fn reference(
    d: &BoundedQuadrupedDescriptor,
    o: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
) -> Result<SupportAnchoredPlan> {
    let baseline = super::partial_concurrent_load_rise_control::reference(d, o, phase)?;
    let mut out = SupportAnchoredPlan {
        schema_version: "sporespore_r10am_support_anchored_plan_v1".to_owned(),
        phase,
        mode: "unchanged_support_reference".to_owned(),
        ordered_target_positions_rad: baseline.ordered_target_positions_rad,
        source_observation_sha256: digest_serializable(o)?,
        baseline_reference: baseline,
        support_anchored_geometry: None,
        native_source_validation_performed: false,
        physical_acceptance_authority: false,
        release_authority: false,
        world_build_count: 0,
        solver_step_count: 0,
    };
    if phase == RecoveryPhaseV1::RaiseBody {
        let plan = geometry(d, o)?;
        if plan.selected_scale.is_some() {
            out.mode = "support_anchored_leveling".to_owned();
            out.ordered_target_positions_rad = plan.ordered_target_positions_rad;
        } else {
            out.mode = "explicit_v23_fallback".to_owned();
            out.ordered_target_positions_rad = out
                .baseline_reference
                .baseline_reference
                .ordered_target_positions_rad;
        }
        out.support_anchored_geometry = Some(plan);
    }
    Ok(out)
}

#[cfg(test)]
#[path = "tests/partial_support_anchored_control_tests.rs"]
mod tests;
