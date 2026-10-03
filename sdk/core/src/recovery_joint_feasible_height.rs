//! V51 selects a common body height using all four actual leg targets.
//! This changes controller reference geometry only. Native measurements remain
//! the authority for contact, support, and physical state.
use serde::{Deserialize, Serialize};

use crate::quadruped::CompiledQuadruped;
use crate::recovery_anchored_body_pose::ik;
use crate::schema::{CoreError, Result, Vec3};

pub const POLICY: &str = "sporespore_balanced_wave_recovery_joint_feasible_height_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_joint_feasible_height_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_joint_feasible_height_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_joint_feasible_height_controller_step_receipt_v1";
pub const MAX_CORRECTION_M: f64 = 0.02;
pub const GRID_M: f64 = 0.00025;
pub const MAX_CORRECTION_RATE_M_S: f64 = 0.24;
pub const REACH_RESERVE_M: f64 = 0.001;
const GRID_STEPS: u32 = 80;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub nominal_body_height_world_m: f64,
    pub selected_body_height_world_m: f64,
    pub previous_correction_m: f64,
    pub selected_correction_m: f64,
    pub correction_interval_m: [f64; 2],
    pub required_reach_reserve_m: f64,
    pub ordered_reach_reserves_m: [f64; 4],
    pub evaluated_grid_candidates: u32,
    pub geometry_is_contact_authority: bool,
    pub physical_acceptance_authority: bool,
}

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("joint_feasible_height_{code}"))) }
}

pub(crate) fn validate_correction(value: f64) -> Result<()> {
    require(value.is_finite() && (-MAX_CORRECTION_M..=0.0).contains(&value), "memory_correction")
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn select(
    nominal: Vec3,
    forward: Vec3,
    targets: &[Vec3],
    compiled: &CompiledQuadruped,
    previous_correction: f64,
    dt: f64,
    startup_scale: f64,
) -> Result<Receipt> {
    validate_correction(previous_correction)?;
    require(dt.is_finite() && (dt - 1.0 / 120.0).abs() < 1e-9, "clock")?;
    require(startup_scale.is_finite() && (0.0..=1.0).contains(&startup_scale), "startup_scale")?;
    nominal.finite("joint_feasible_height_nominal")?;
    forward.finite("joint_feasible_height_forward")?;
    require(forward.y == 0.0 && (forward.x * forward.x + forward.z * forward.z - 1.0).abs() < 1e-12, "forward")?;
    require(targets.len() == 4, "target_population")?;
    for target in targets { target.finite("joint_feasible_height_target")?; }
    let minimum = (previous_correction - MAX_CORRECTION_RATE_M_S * dt).max(-MAX_CORRECTION_M);
    let maximum = (previous_correction + MAX_CORRECTION_RATE_M_S * dt).min(0.0);
    let reserve = REACH_RESERVE_M * startup_scale;
    let g = &compiled.geometry;
    let mut evaluated = 0;
    for index in 0..=GRID_STEPS {
        let correction = -(f64::from(index) * GRID_M);
        // Do not use an epsilon to enlarge a rate or geometry bound.
        if correction < minimum || correction > maximum { continue; }
        evaluated += 1;
        let height = nominal.y + correction;
        let mut reserves = [0.0; 4];
        let feasible = targets.iter().enumerate().all(|(i, target)| {
            let hip_x = if i < 2 { g.front_hip_x_m } else { g.rear_hip_x_m };
            let x = (target.x - nominal.x) * forward.x + (target.z - nominal.z) * forward.z - hip_x;
            let down = height - target.y;
            reserves[i] = g.upper_length_m + g.lower_length_m - x.hypot(down);
            if reserves[i] < reserve { return false; }
            let h = &compiled.morphology.morphology_spec.actuators[2 * i];
            let k = &compiled.morphology.morphology_spec.actuators[2 * i + 1];
            ik(x, down, g.upper_length_m, g.lower_length_m,
                h.minimum_target_position_rad, h.maximum_target_position_rad,
                k.maximum_target_position_rad)
                .is_ok_and(|(_, knee)| knee >= k.minimum_target_position_rad)
        });
        if feasible {
            return Ok(Receipt {
                schema_version: "sporespore_joint_feasible_height_receipt_v1".to_owned(),
                nominal_body_height_world_m: nominal.y,
                selected_body_height_world_m: height,
                previous_correction_m: previous_correction,
                selected_correction_m: correction,
                correction_interval_m: [minimum, maximum],
                required_reach_reserve_m: reserve,
                ordered_reach_reserves_m: reserves,
                evaluated_grid_candidates: evaluated,
                geometry_is_contact_authority: false,
                physical_acceptance_authority: false,
            });
        }
    }
    Err(CoreError::Frame("joint_feasible_height_no_permitted_pose".to_owned()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::actuator_profile::r23d60_selected_s169_descriptor;
    use crate::quadruped::compile_bounded_quadruped;

    fn fixture(xs: [f64; 4], lifts: [f64; 4]) -> (CompiledQuadruped, Vec<Vec3>) {
        let compiled = compile_bounded_quadruped(r23d60_selected_s169_descriptor()).unwrap();
        let g = &compiled.geometry;
        let targets = (0..4).map(|i| Vec3 {
            x: xs[i] + if i < 2 { g.front_hip_x_m } else { g.rear_hip_x_m },
            y: lifts[i], z: if i % 2 == 0 { g.left_hip_z_m } else { g.right_hip_z_m },
        }).collect();
        (compiled, targets)
    }

    fn choose(xs: [f64; 4], lifts: [f64; 4], previous: f64) -> Result<Receipt> {
        let (compiled, targets) = fixture(xs, lifts);
        select(Vec3 { x: 0.0, y: 0.33, z: 0.0 }, Vec3 { x: 1.0, y: 0.0, z: 0.0 },
            &targets, &compiled, previous, 1.0 / 120.0, 1.0)
    }

    #[test]
    fn measured_unreachable_endpoint_gets_a_joint_feasible_common_height() {
        let r = choose([0.0, 0.0, -0.11698917867310682, 0.0], [0.0; 4], 0.0).unwrap();
        assert!(r.selected_correction_m < 0.0 && r.selected_correction_m >= -0.002);
        assert!(r.ordered_reach_reserves_m.iter().all(|v| *v >= REACH_RESERVE_M));
        assert!(!r.geometry_is_contact_authority && !r.physical_acceptance_authority);
    }

    #[test]
    fn nominal_feasible_pose_is_unchanged_and_return_from_crouch_obeys_rate() {
        assert_eq!(0.0, choose([0.0; 4], [0.0; 4], 0.0).unwrap().selected_correction_m);
        let r = choose([0.0; 4], [0.0; 4], -0.01).unwrap();
        assert!(r.selected_correction_m <= -0.008 && r.selected_correction_m >= -0.012);
    }

    #[test]
    fn reach_cannot_override_another_limbs_hip_or_knee_bound() {
        // Leg zero demands crouching, while another lifted leg limits crouch.
        assert!(choose([-0.15, -0.08, 0.0, 0.0], [0.0, 0.02, 0.0, 0.0], -0.018).is_err());
        let (mut compiled, targets) = fixture([0.0; 4], [0.02; 4]);
        compiled.morphology.morphology_spec.actuators[7].maximum_target_position_rad = 0.1;
        assert!(select(Vec3 { x: 0.0, y: 0.33, z: 0.0 }, Vec3 { x: 1.0, y: 0.0, z: 0.0 },
            &targets, &compiled, 0.0, 1.0 / 120.0, 1.0).is_err());
    }

    #[test]
    fn impossible_population_rate_jump_and_invalid_memory_refuse() {
        assert!(choose([0.3; 4], [0.0; 4], 0.0).is_err());
        assert!(choose([-0.15, 0.0, 0.0, 0.0], [0.0; 4], 0.0).is_err());
        for prior in [f64::NAN, f64::INFINITY, 0.001, -0.021] {
            assert!(choose([0.0; 4], [0.0; 4], prior).is_err());
        }
    }
}
