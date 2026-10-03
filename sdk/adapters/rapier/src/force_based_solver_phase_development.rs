use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest_sha256};

const PREREGISTRATION_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_solver_phase_development_spd1_preregistration.json"
);
const SOLVER_PHASE_DIAGNOSTIC_RAW: &str =
    include_str!("../../../rapier_c6_force_based_cw1_solver_phase_diagnostic.json");
const CW1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_force_based_convergence_window_cw1_closure.json");
const CARGO_LOCK_RAW: &str = include_str!("../../../Cargo.lock");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:ccfa677c7f3e7ab1d43c0c61be304b7fedb669f6292d8c53486aee5fc4c5c014";
const SOLVER_PHASE_DIAGNOSTIC_RAW_SHA256: &str =
    "sha256:bcf35b8edd3d9340ff8680b3e85644dd8565841c000fb94e80a7ad54d9933594";
const CW1_CLOSURE_RAW_SHA256: &str =
    "sha256:df46f8a7982cabcd166a13c2b1f9e67fa606709b97484661d36aba1556e5747c";
const CARGO_LOCK_RAW_SHA256: &str =
    "sha256:0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc";

const CAMPAIGN_ID: &str = "C6-RAPIER-FORCE-BASED-SOLVER-PHASE-DEVELOPMENT";
const GATE_ID: &str = "C6-RAP-HC-SPD1";
const EXPECTED_CANDIDATE_COUNT: u64 = 4;
const EXPECTED_CELLS_PER_CANDIDATE: u64 = 4;
const EXPECTED_WORLD_COUNT: u64 = 16;
const SOLVER_ITERATIONS: usize = 16;
const TOTAL_CONSTRAINT_PASSES: usize = 8;
const CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const CHILD_MASS_KG: f32 = 1.0;
const GRAVITY_M_S2: f32 = 9.8;
const POSITION_STIFFNESS_NM_PER_RAD: f32 = 40.0;
const MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
const MAXIMUM_MOTOR_FORCE_NM: f32 = 6.0;
const MAXIMUM_OBSERVATION_STEPS: usize = 1_440;
const MINIMUM_ACCEPTANCE_STEP: usize = 120;
const REQUIRED_CONSECUTIVE_STEPS: usize = 60;
const SIGNED_LEVER_ARMS_Z_M: [f32; 4] = [-0.25, 0.25, -0.45, 0.45];
const RESPONSE_MINIMUM: f32 = 0.98;
const RESPONSE_MAXIMUM: f32 = 1.02;
const MAXIMUM_STATIC_RESIDUAL: f32 = 0.01;
const MAXIMUM_DAMPING_LOAD_FRACTION: f32 = 0.005;
const MAXIMUM_FULL_PD_RESIDUAL: f32 = 0.005;
const MAXIMUM_ANCHOR_ERROR_M: f32 = 0.000_01;
const MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY: f32 = 0.005;
const STEP_IMPULSE_TOLERANCE_NMS: f32 = 0.000_001;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct PhaseAllocation {
    candidate_id: &'static str,
    role: &'static str,
    internal_pgs_iterations: usize,
    internal_stabilization_iterations: usize,
    tie_break_rank: usize,
}

const PHASE_ALLOCATIONS: [PhaseAllocation; 4] = [
    PhaseAllocation {
        candidate_id: "SPD1-A",
        role: "legacy_phase_control",
        internal_pgs_iterations: 1,
        internal_stabilization_iterations: 7,
        tie_break_rank: 0,
    },
    PhaseAllocation {
        candidate_id: "SPD1-B",
        role: "post_heavy_intermediate",
        internal_pgs_iterations: 3,
        internal_stabilization_iterations: 5,
        tie_break_rank: 1,
    },
    PhaseAllocation {
        candidate_id: "SPD1-C",
        role: "pre_heavy_intermediate",
        internal_pgs_iterations: 5,
        internal_stabilization_iterations: 3,
        tie_break_rank: 2,
    },
    PhaseAllocation {
        candidate_id: "SPD1-D",
        role: "pre_heavy_default_stabilization",
        internal_pgs_iterations: 7,
        internal_stabilization_iterations: 1,
        tie_break_rank: 3,
    },
];

#[derive(Clone)]
struct StepObservation {
    motor_model: MotorModel,
    angle_rad: f32,
    angular_velocity_rad_s: f32,
    motor_impulse_nms: f32,
    anchor_error_m: f32,
}

#[derive(Clone)]
struct StepMetrics {
    gravity_torque_nm: f32,
    expected_small_step_impulse_nms: f32,
    normalized_impulse_response: f32,
    spring_only_static_residual: f32,
    damping_load_fraction: f32,
    full_pd_gravity_residual: f32,
    signed_geometry_passed: bool,
    response_passed: bool,
    static_residual_passed: bool,
    damping_fraction_passed: bool,
    full_pd_residual_passed: bool,
    anchor_passed: bool,
    force_limit_passed: bool,
    finite_values: bool,
    convergence_predicates_passed: bool,
}

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn check(condition: bool, failure_code: impl Into<String>) -> Result<(), String> {
    condition.then_some(()).ok_or_else(|| failure_code.into())
}

fn motor_model_name(model: MotorModel) -> &'static str {
    match model {
        MotorModel::AccelerationBased => "AccelerationBased",
        MotorModel::ForceBased => "ForceBased",
    }
}

fn same_nonzero_sign(first: f32, second: f32) -> bool {
    first != 0.0 && second != 0.0 && first.signum() == second.signum()
}

fn relative_difference(first: f64, second: f64) -> f64 {
    let scale = ((first.abs() + second.abs()) * 0.5).max(f64::EPSILON);
    (first.abs() - second.abs()).abs() / scale
}

fn preregistration() -> Result<Value, String> {
    check(
        raw_sha256(PREREGISTRATION_RAW) == PREREGISTRATION_RAW_SHA256,
        "C6_RAP_HC_SPD1_PREREGISTRATION_HASH",
    )?;
    check(
        raw_sha256(SOLVER_PHASE_DIAGNOSTIC_RAW) == SOLVER_PHASE_DIAGNOSTIC_RAW_SHA256,
        "C6_RAP_HC_SPD1_SOLVER_PHASE_DIAGNOSTIC_HASH",
    )?;
    check(
        raw_sha256(CW1_CLOSURE_RAW) == CW1_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_SPD1_CW1_CLOSURE_HASH",
    )?;
    check(
        raw_sha256(CARGO_LOCK_RAW) == CARGO_LOCK_RAW_SHA256,
        "C6_RAP_HC_SPD1_CARGO_LOCK_HASH",
    )?;
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_HC_SPD1_PREREGISTRATION_PARSE:{error}"))?;
    let declared_allocations =
        declaration["controlled_configuration"]["candidate_phase_allocations"]
            .as_array()
            .ok_or_else(|| "C6_RAP_HC_SPD1_DECLARED_ALLOCATIONS_MISSING".to_owned())?;
    let allocations_match = declared_allocations.len() == PHASE_ALLOCATIONS.len()
        && declared_allocations
            .iter()
            .zip(PHASE_ALLOCATIONS)
            .all(|(declared, expected)| {
                declared["candidate_id"] == expected.candidate_id
                    && declared["role"] == expected.role
                    && declared["num_internal_pgs_iterations"]
                        == expected.internal_pgs_iterations as u64
                    && declared["num_internal_stabilization_iterations"]
                        == expected.internal_stabilization_iterations as u64
                    && declared["predeclared_tie_break_rank"] == expected.tie_break_rank as u64
            });
    check(
        declaration["schema_version"]
            == "sporespore_rapier_c6_force_based_solver_phase_development_preregistration_v1"
            && declaration["campaign_id"] == CAMPAIGN_ID
            && declaration["gate_id"] == GATE_ID
            && declaration["status"] == "frozen_before_first_c6_rap_hc_spd1_physics_world"
            && declaration["implementation_parent_commit"]
                == "bd3ad00930792209c11ec057ca97213335fc331b"
            && declaration["study_classification"]["class"]
                == "exact_finite_cell_configuration_development_screen"
            && declaration["study_classification"]["development_screen"] == true
            && declaration["study_classification"]["superiority_study"] == false
            && declaration["study_classification"]["noninferiority_or_equivalence_study"] == false
            && declaration["predecessors"]["cw1_closure"]["raw_sha256"]
                == CW1_CLOSURE_RAW_SHA256.trim_start_matches("sha256:")
            && declaration["predecessors"]["solver_phase_diagnostic"]["raw_sha256"]
                == SOLVER_PHASE_DIAGNOSTIC_RAW_SHA256.trim_start_matches("sha256:")
            && declaration["host_source_semantics"]["host_version"] == rapier3d::VERSION
            && declaration["host_source_semantics"]["cargo_lock_raw_sha256"]
                == CARGO_LOCK_RAW_SHA256.trim_start_matches("sha256:")
            && declaration["freshness_contract"]["spd1_solver_iterations"]
                == SOLVER_ITERATIONS as u64
            && declaration["physical_grid"]["expected_world_count"] == EXPECTED_WORLD_COUNT
            && declaration["controlled_configuration"]["total_joint_constraint_passes_per_small_step"]
                == TOTAL_CONSTRAINT_PASSES as u64
            && declaration["per_cell_convergence_contract"]["threshold_change_from_cw1"] == false
            && declaration["preflight_contract"]["must_run_before_any_physics_world"] == true
            && declaration["preflight_contract"]["perfect_sixteen_cell_traces_must_pass_entire_gate"]
                == true
            && declaration["preflight_contract"]["known_fastest_candidate_must_be_selected"]
                == true
            && declaration["preflight_contract"]["no_eligible_candidate_canary_must_select_none"]
                == true
            && declaration["preflight_contract"]["missing_cell_canary_must_fail"] == true
            && declaration["preflight_contract"]["window_gap_canary_must_fail"] == true
            && declaration["preflight_contract"]["unequal_total_pass_canary_must_fail"] == true
            && declaration["preflight_contract"]["tie_break_canary_must_select_spd1_a"] == true
            && allocations_match,
        "C6_RAP_HC_SPD1_PREREGISTRATION_IDENTITY",
    )?;
    Ok(declaration)
}

fn configured_world(gravity: Vector, allocation: PhaseAllocation) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = SOLVER_ITERATIONS;
    world.integration_parameters.num_internal_pgs_iterations = allocation.internal_pgs_iterations;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = allocation.internal_stabilization_iterations;
    world
}

fn gravity_torque_nm(signed_lever_arm_z_m: f32, angle_rad: f32) -> f32 {
    CHILD_MASS_KG * GRAVITY_M_S2 * signed_lever_arm_z_m.abs() * angle_rad.abs().cos()
}

fn expected_small_step_impulse_nms(signed_lever_arm_z_m: f32, angle_rad: f32) -> f32 {
    gravity_torque_nm(signed_lever_arm_z_m, angle_rad) * RAPIER_DT_S / SOLVER_ITERATIONS as f32
}

fn small_step_impulse_limit_nms() -> f32 {
    MAXIMUM_MOTOR_FORCE_NM * RAPIER_DT_S / SOLVER_ITERATIONS as f32
}

fn cell_id(allocation: PhaseAllocation, signed_lever_arm_z_m: f32) -> String {
    let sign = if signed_lever_arm_z_m < 0.0 {
        "negative"
    } else {
        "positive"
    };
    format!(
        "{}_arm_{:.2}_{sign}_solver_{SOLVER_ITERATIONS}",
        allocation.candidate_id,
        signed_lever_arm_z_m.abs()
    )
}

fn evaluate_step(signed_lever_arm_z_m: f32, observation: &StepObservation) -> StepMetrics {
    let gravity_torque = gravity_torque_nm(signed_lever_arm_z_m, observation.angle_rad);
    let expected_impulse = gravity_torque * RAPIER_DT_S / SOLVER_ITERATIONS as f32;
    let normalized_response = observation.motor_impulse_nms.abs() / expected_impulse;
    let spring_torque = POSITION_STIFFNESS_NM_PER_RAD * observation.angle_rad.abs();
    let static_residual = (spring_torque - gravity_torque).abs() / gravity_torque;
    let damping_fraction =
        MOTOR_DAMPING_NM_S_PER_RAD * observation.angular_velocity_rad_s.abs() / gravity_torque;
    let full_pd_torque = (POSITION_STIFFNESS_NM_PER_RAD * observation.angle_rad
        + MOTOR_DAMPING_NM_S_PER_RAD * observation.angular_velocity_rad_s)
        .abs();
    let full_pd_residual = (full_pd_torque - gravity_torque).abs() / gravity_torque;
    let signed_geometry_passed = same_nonzero_sign(signed_lever_arm_z_m, observation.angle_rad)
        && same_nonzero_sign(signed_lever_arm_z_m, observation.motor_impulse_nms);
    let finite_values = observation.angle_rad.is_finite()
        && observation.angular_velocity_rad_s.is_finite()
        && observation.motor_impulse_nms.is_finite()
        && observation.anchor_error_m.is_finite()
        && gravity_torque.is_finite()
        && gravity_torque > 0.0
        && expected_impulse.is_finite()
        && expected_impulse > 0.0
        && normalized_response.is_finite()
        && static_residual.is_finite()
        && damping_fraction.is_finite()
        && full_pd_residual.is_finite();
    let response_passed = (RESPONSE_MINIMUM..=RESPONSE_MAXIMUM).contains(&normalized_response);
    let static_residual_passed = static_residual <= MAXIMUM_STATIC_RESIDUAL;
    let damping_fraction_passed = damping_fraction <= MAXIMUM_DAMPING_LOAD_FRACTION;
    let full_pd_residual_passed = full_pd_residual <= MAXIMUM_FULL_PD_RESIDUAL;
    let anchor_passed = observation.anchor_error_m <= MAXIMUM_ANCHOR_ERROR_M;
    let force_limit_passed = observation.motor_impulse_nms.abs()
        <= small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS;
    let convergence_predicates_passed = observation.motor_model == MotorModel::ForceBased
        && finite_values
        && signed_geometry_passed
        && response_passed
        && static_residual_passed
        && damping_fraction_passed
        && full_pd_residual_passed
        && anchor_passed
        && force_limit_passed;
    StepMetrics {
        gravity_torque_nm: gravity_torque,
        expected_small_step_impulse_nms: expected_impulse,
        normalized_impulse_response: normalized_response,
        spring_only_static_residual: static_residual,
        damping_load_fraction: damping_fraction,
        full_pd_gravity_residual: full_pd_residual,
        signed_geometry_passed,
        response_passed,
        static_residual_passed,
        damping_fraction_passed,
        full_pd_residual_passed,
        anchor_passed,
        force_limit_passed,
        finite_values,
        convergence_predicates_passed,
    }
}

fn summarize_trace(
    allocation: PhaseAllocation,
    signed_lever_arm_z_m: f32,
    observations: &[StepObservation],
    world_attempt_count: u64,
    world_build_count: u64,
) -> Result<Value, String> {
    check(
        !observations.is_empty() && observations.len() <= MAXIMUM_OBSERVATION_STEPS,
        "C6_RAP_HC_SPD1_TRACE_LENGTH",
    )?;
    let mut consecutive = 0_usize;
    let mut longest = 0_usize;
    let mut convergence_start = None;
    let mut convergence_end = None;
    let mut maximum_impulse = 0.0_f32;
    let mut model_mismatches = 0_u64;
    let mut impulse_limit_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut terminal = observations[0].clone();
    let mut terminal_metrics = evaluate_step(signed_lever_arm_z_m, &terminal);

    for (index, observation) in observations.iter().enumerate() {
        let step = index + 1;
        let metrics = evaluate_step(signed_lever_arm_z_m, observation);
        model_mismatches += u64::from(observation.motor_model != MotorModel::ForceBased);
        nonfinite_values += u64::from(!metrics.finite_values);
        maximum_impulse = maximum_impulse.max(observation.motor_impulse_nms.abs());
        impulse_limit_violations += u64::from(!metrics.force_limit_passed);
        if step >= MINIMUM_ACCEPTANCE_STEP && metrics.convergence_predicates_passed {
            consecutive += 1;
            longest = longest.max(consecutive);
            if consecutive == REQUIRED_CONSECUTIVE_STEPS {
                convergence_start = Some(step + 1 - REQUIRED_CONSECUTIVE_STEPS);
                convergence_end = Some(step);
            }
        } else {
            consecutive = 0;
        }
        terminal = observation.clone();
        terminal_metrics = metrics;
        if convergence_end.is_some() {
            break;
        }
    }

    let observation_steps_executed = convergence_end.unwrap_or(observations.len());
    let convergence_reached = convergence_start.is_some() && convergence_end.is_some();
    let allocation_valid = allocation.internal_pgs_iterations > 0
        && allocation.internal_stabilization_iterations > 0
        && allocation.internal_pgs_iterations + allocation.internal_stabilization_iterations
            == TOTAL_CONSTRAINT_PASSES;
    let passed = allocation_valid
        && convergence_reached
        && model_mismatches == 0
        && impulse_limit_violations == 0
        && nonfinite_values == 0
        && terminal_metrics.convergence_predicates_passed;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_force_based_solver_phase_development_cell_v1",
        "cell_kind": "gravity_static_convergence_development",
        "cell_id": cell_id(allocation, signed_lever_arm_z_m),
        "ok": passed,
        "candidate_id": allocation.candidate_id,
        "candidate_role": allocation.role,
        "predeclared_tie_break_rank": allocation.tie_break_rank,
        "signed_lever_arm_z_m": signed_lever_arm_z_m,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": allocation.internal_pgs_iterations,
        "num_internal_stabilization_iterations":
            allocation.internal_stabilization_iterations,
        "total_constraint_passes_per_small_step":
            allocation.internal_pgs_iterations +
            allocation.internal_stabilization_iterations,
        "equal_total_pass_contract_passed": allocation_valid,
        "mass_kg": CHILD_MASS_KG,
        "target_position_rad": 0.0,
        "target_velocity_rad_s": 0.0,
        "position_stiffness_nm_per_rad": POSITION_STIFFNESS_NM_PER_RAD,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "small_step_timestep_s": RAPIER_DT_S / SOLVER_ITERATIONS as f32,
        "small_step_impulse_limit_nms": small_step_impulse_limit_nms(),
        "motor_model_readback": motor_model_name(terminal.motor_model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_angle_rad": terminal.angle_rad,
        "terminal_angular_velocity_rad_s": terminal.angular_velocity_rad_s,
        "terminal_motor_impulse_nms": terminal.motor_impulse_nms,
        "final_anchor_error_m": terminal.anchor_error_m,
        "gravity_torque_nm": terminal_metrics.gravity_torque_nm,
        "expected_terminal_small_step_impulse_nms":
            terminal_metrics.expected_small_step_impulse_nms,
        "normalized_terminal_impulse_response":
            terminal_metrics.normalized_impulse_response,
        "spring_only_static_residual":
            terminal_metrics.spring_only_static_residual,
        "damping_load_fraction": terminal_metrics.damping_load_fraction,
        "full_pd_gravity_residual":
            terminal_metrics.full_pd_gravity_residual,
        "signed_geometry_passed": terminal_metrics.signed_geometry_passed,
        "response_passed": terminal_metrics.response_passed,
        "static_residual_passed": terminal_metrics.static_residual_passed,
        "damping_fraction_passed": terminal_metrics.damping_fraction_passed,
        "full_pd_residual_passed":
            terminal_metrics.full_pd_residual_passed,
        "anchor_passed": terminal_metrics.anchor_passed,
        "force_limit_passed": terminal_metrics.force_limit_passed,
        "finite_terminal_values": terminal_metrics.finite_values,
        "convergence_predicates_passed_at_terminal":
            terminal_metrics.convergence_predicates_passed,
        "maximum_observed_motor_impulse_nms": maximum_impulse,
        "step_impulse_limit_violation_count": impulse_limit_violations,
        "nonfinite_value_count": nonfinite_values,
        "maximum_observation_steps": MAXIMUM_OBSERVATION_STEPS,
        "minimum_acceptance_step": MINIMUM_ACCEPTANCE_STEP,
        "required_consecutive_converged_steps": REQUIRED_CONSECUTIVE_STEPS,
        "observation_steps_executed": observation_steps_executed,
        "longest_consecutive_converged_steps": longest,
        "convergence_window_reached": convergence_reached,
        "convergence_window_start_step": convergence_start,
        "convergence_window_end_step": convergence_end,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "development_screen_evidence": true,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    }))
}

fn value_sum(values: &[Value], field: &str) -> u64 {
    values
        .iter()
        .map(|value| value[field].as_u64().unwrap_or(0))
        .sum()
}

fn matching_cell(cells: &[Value], signed_lever_arm_z_m: f32) -> Option<&Value> {
    cells.iter().find(|cell| {
        cell["signed_lever_arm_z_m"]
            .as_f64()
            .is_some_and(|value| (value - signed_lever_arm_z_m as f64).abs() <= 1.0e-6)
    })
}

fn signed_pair_symmetry(cells: &[Value]) -> (bool, f64) {
    let mut maximum_asymmetry = 0.0_f64;
    for arm_magnitude in [0.25_f32, 0.45_f32] {
        let Some(negative) = matching_cell(cells, -arm_magnitude) else {
            return (false, f64::INFINITY);
        };
        let Some(positive) = matching_cell(cells, arm_magnitude) else {
            return (false, f64::INFINITY);
        };
        if negative["convergence_window_end_step"].as_u64()
            != positive["convergence_window_end_step"].as_u64()
        {
            return (false, f64::INFINITY);
        }
        for field in [
            "final_angle_rad",
            "terminal_motor_impulse_nms",
            "normalized_terminal_impulse_response",
            "spring_only_static_residual",
            "damping_load_fraction",
        ] {
            let Some(negative_value) = negative[field].as_f64() else {
                return (false, f64::INFINITY);
            };
            let Some(positive_value) = positive[field].as_f64() else {
                return (false, f64::INFINITY);
            };
            maximum_asymmetry =
                maximum_asymmetry.max(relative_difference(negative_value, positive_value));
        }
    }
    (
        maximum_asymmetry <= MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY as f64,
        maximum_asymmetry,
    )
}

fn arm_magnitude_ordering(cells: &[Value]) -> bool {
    for sign in [-1.0_f32, 1.0_f32] {
        let Some(lower) = matching_cell(cells, sign * 0.25) else {
            return false;
        };
        let Some(higher) = matching_cell(cells, sign * 0.45) else {
            return false;
        };
        let Some(lower_impulse) = lower["terminal_motor_impulse_nms"].as_f64() else {
            return false;
        };
        let Some(higher_impulse) = higher["terminal_motor_impulse_nms"].as_f64() else {
            return false;
        };
        if higher_impulse.abs() <= lower_impulse.abs() {
            return false;
        }
    }
    true
}

fn candidate_summary(allocation: PhaseAllocation, cells: &[Value]) -> Value {
    let identity_valid = cells.len() as u64 == EXPECTED_CELLS_PER_CANDIDATE
        && cells.iter().all(|cell| {
            cell["candidate_id"] == allocation.candidate_id
                && cell["solver_iterations"] == SOLVER_ITERATIONS as u64
                && cell["num_internal_pgs_iterations"] == allocation.internal_pgs_iterations as u64
                && cell["num_internal_stabilization_iterations"]
                    == allocation.internal_stabilization_iterations as u64
                && cell["total_constraint_passes_per_small_step"] == TOTAL_CONSTRAINT_PASSES as u64
                && cell["equal_total_pass_contract_passed"] == true
        })
        && SIGNED_LEVER_ARMS_Z_M
            .iter()
            .all(|arm| matching_cell(cells, *arm).is_some());
    let passed_cell_count = cells.iter().filter(|cell| cell["ok"] == true).count() as u64;
    let convergence_window_reached_count = cells
        .iter()
        .filter(|cell| cell["convergence_window_reached"] == true)
        .count() as u64;
    let (signed_pair_symmetry_passed, maximum_signed_pair_relative_asymmetry) =
        signed_pair_symmetry(cells);
    let arm_magnitude_ordering_passed = arm_magnitude_ordering(cells);
    let window_end_steps: Vec<u64> = cells
        .iter()
        .filter_map(|cell| cell["convergence_window_end_step"].as_u64())
        .collect();
    let maximum_window_end_step = window_end_steps.iter().max().copied();
    let sum_window_end_steps = if window_end_steps.len() == cells.len() {
        Some(window_end_steps.iter().sum::<u64>())
    } else {
        None
    };
    let eligible = identity_valid
        && passed_cell_count == EXPECTED_CELLS_PER_CANDIDATE
        && convergence_window_reached_count == EXPECTED_CELLS_PER_CANDIDATE
        && value_sum(cells, "world_attempt_count") == EXPECTED_CELLS_PER_CANDIDATE
        && value_sum(cells, "world_build_count") == EXPECTED_CELLS_PER_CANDIDATE
        && value_sum(cells, "motor_model_readback_count") == EXPECTED_CELLS_PER_CANDIDATE
        && value_sum(cells, "motor_model_mismatch_count") == 0
        && value_sum(cells, "nonfinite_value_count") == 0
        && value_sum(cells, "step_impulse_limit_violation_count") == 0
        && signed_pair_symmetry_passed
        && arm_magnitude_ordering_passed
        && maximum_window_end_step.is_some()
        && sum_window_end_steps.is_some();
    json!({
        "schema_version":
            "sporespore_rapier_force_based_solver_phase_candidate_summary_v1",
        "candidate_id": allocation.candidate_id,
        "candidate_role": allocation.role,
        "predeclared_tie_break_rank": allocation.tie_break_rank,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": allocation.internal_pgs_iterations,
        "num_internal_stabilization_iterations":
            allocation.internal_stabilization_iterations,
        "total_constraint_passes_per_small_step":
            allocation.internal_pgs_iterations +
            allocation.internal_stabilization_iterations,
        "identity_valid": identity_valid,
        "cell_count": cells.len() as u64,
        "passed_cell_count": passed_cell_count,
        "failed_cell_count": cells.len() as u64 - passed_cell_count,
        "convergence_window_reached_count": convergence_window_reached_count,
        "world_attempt_count": value_sum(cells, "world_attempt_count"),
        "world_build_count": value_sum(cells, "world_build_count"),
        "motor_model_readback_count": value_sum(cells, "motor_model_readback_count"),
        "motor_model_mismatch_count": value_sum(cells, "motor_model_mismatch_count"),
        "nonfinite_value_count": value_sum(cells, "nonfinite_value_count"),
        "step_impulse_limit_violation_count":
            value_sum(cells, "step_impulse_limit_violation_count"),
        "signed_pair_symmetry_passed": signed_pair_symmetry_passed,
        "maximum_signed_pair_relative_asymmetry":
            maximum_signed_pair_relative_asymmetry,
        "arm_magnitude_ordering_passed": arm_magnitude_ordering_passed,
        "maximum_convergence_window_end_step": maximum_window_end_step,
        "sum_convergence_window_end_steps": sum_window_end_steps,
        "eligible_for_development_selection": eligible,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    })
}

fn select_candidate(summaries: &[Value]) -> Value {
    let mut eligible: Vec<&Value> = summaries
        .iter()
        .filter(|summary| summary["eligible_for_development_selection"] == true)
        .collect();
    eligible.sort_by(|first, second| {
        let first_key = (
            first["maximum_convergence_window_end_step"]
                .as_u64()
                .unwrap_or(u64::MAX),
            first["sum_convergence_window_end_steps"]
                .as_u64()
                .unwrap_or(u64::MAX),
            first["predeclared_tie_break_rank"]
                .as_u64()
                .unwrap_or(u64::MAX),
        );
        let second_key = (
            second["maximum_convergence_window_end_step"]
                .as_u64()
                .unwrap_or(u64::MAX),
            second["sum_convergence_window_end_steps"]
                .as_u64()
                .unwrap_or(u64::MAX),
            second["predeclared_tie_break_rank"]
                .as_u64()
                .unwrap_or(u64::MAX),
        );
        first_key.cmp(&second_key)
    });
    let selected = eligible.first().copied();
    let status = if selected.is_some() {
        "development_configuration_selected_requires_fresh_independent_validation"
    } else {
        "development_family_rejected_no_eligible_configuration"
    };
    json!({
        "schema_version":
            "sporespore_rapier_force_based_solver_phase_development_selection_v1",
        "selector_invocation_count": 1,
        "status": status,
        "eligible_candidate_count": eligible.len() as u64,
        "eligible_candidate_ids": eligible
            .iter()
            .filter_map(|summary| summary["candidate_id"].as_str())
            .collect::<Vec<_>>(),
        "selected_candidate_id": selected
            .and_then(|summary| summary["candidate_id"].as_str()),
        "selected_num_internal_pgs_iterations": selected
            .and_then(|summary| summary["num_internal_pgs_iterations"].as_u64()),
        "selected_num_internal_stabilization_iterations": selected
            .and_then(|summary| {
                summary["num_internal_stabilization_iterations"].as_u64()
            }),
        "selected_maximum_convergence_window_end_step": selected
            .and_then(|summary| {
                summary["maximum_convergence_window_end_step"].as_u64()
            }),
        "selected_sum_convergence_window_end_steps": selected
            .and_then(|summary| summary["sum_convergence_window_end_steps"].as_u64()),
        "selection_is_development_only": true,
        "fresh_independent_validation_required": true,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    })
}

fn aggregate_report(cells: &[Value], candidate_summaries: &[Value], selection: &Value) -> Value {
    let passed_cell_count = cells.iter().filter(|cell| cell["ok"] == true).count() as u64;
    let eligible_candidate_count = candidate_summaries
        .iter()
        .filter(|summary| summary["eligible_for_development_selection"] == true)
        .count() as u64;
    json!({
        "world_attempt_count": value_sum(cells, "world_attempt_count"),
        "world_build_count": value_sum(cells, "world_build_count"),
        "cell_count": cells.len() as u64,
        "passed_cell_count": passed_cell_count,
        "failed_cell_count": cells.len() as u64 - passed_cell_count,
        "candidate_count": candidate_summaries.len() as u64,
        "eligible_candidate_count": eligible_candidate_count,
        "motor_model_readback_count": value_sum(cells, "motor_model_readback_count"),
        "motor_model_mismatch_count": value_sum(cells, "motor_model_mismatch_count"),
        "nonfinite_value_count": value_sum(cells, "nonfinite_value_count"),
        "step_impulse_limit_violation_count":
            value_sum(cells, "step_impulse_limit_violation_count"),
        "selector_invocation_count": selection["selector_invocation_count"].clone(),
        "selected_candidate_count": u64::from(
            selection["selected_candidate_id"].as_str().is_some()
        ),
        "complete_sixteen_cell_screen": cells.len() as u64 == EXPECTED_WORLD_COUNT
            && value_sum(cells, "world_attempt_count") == EXPECTED_WORLD_COUNT
            && value_sum(cells, "world_build_count") == EXPECTED_WORLD_COUNT
            && candidate_summaries.len() as u64 == EXPECTED_CANDIDATE_COUNT,
    })
}

fn boundary_failures(
    aggregate: &Value,
    candidate_summaries: &[Value],
    selection: &Value,
) -> Vec<String> {
    let mut failures = Vec::new();
    for (field, expected) in [
        ("world_attempt_count", EXPECTED_WORLD_COUNT),
        ("world_build_count", EXPECTED_WORLD_COUNT),
        ("cell_count", EXPECTED_WORLD_COUNT),
        ("candidate_count", EXPECTED_CANDIDATE_COUNT),
        ("motor_model_readback_count", EXPECTED_WORLD_COUNT),
        ("motor_model_mismatch_count", 0),
        ("nonfinite_value_count", 0),
        ("step_impulse_limit_violation_count", 0),
        ("selector_invocation_count", 1),
    ] {
        if aggregate[field].as_u64() != Some(expected) {
            failures.push(format!("C6_RAP_HC_SPD1_{field}_INVALID"));
        }
    }
    if aggregate["complete_sixteen_cell_screen"].as_bool() != Some(true) {
        failures.push("C6_RAP_HC_SPD1_complete_sixteen_cell_screen_INVALID".to_owned());
    }
    if candidate_summaries.len() != PHASE_ALLOCATIONS.len()
        || candidate_summaries
            .iter()
            .zip(PHASE_ALLOCATIONS)
            .any(|(summary, allocation)| {
                summary["candidate_id"] != allocation.candidate_id
                    || summary["identity_valid"] != true
            })
    {
        failures.push("C6_RAP_HC_SPD1_candidate_identity_INVALID".to_owned());
    }
    if selection["selected_candidate_id"].as_str().is_some()
        && selection["fresh_independent_validation_required"] != true
    {
        failures.push("C6_RAP_HC_SPD1_selection_validation_boundary_INVALID".to_owned());
    }
    failures
}

fn equilibrium_angle_abs(arm_magnitude_m: f32) -> f32 {
    let nominal_load = CHILD_MASS_KG * GRAVITY_M_S2 * arm_magnitude_m;
    let mut angle = nominal_load / POSITION_STIFFNESS_NM_PER_RAD;
    for _ in 0..32 {
        angle = nominal_load * angle.cos() / POSITION_STIFFNESS_NM_PER_RAD;
    }
    angle
}

fn synthetic_trace(
    signed_arm: f32,
    convergence_end_step: usize,
    gap_step: Option<usize>,
) -> Vec<StepObservation> {
    let mut observations = Vec::with_capacity(convergence_end_step);
    let angle = signed_arm.signum() * equilibrium_angle_abs(signed_arm.abs());
    let impulse = signed_arm.signum() * expected_small_step_impulse_nms(signed_arm, angle);
    let convergence_start = convergence_end_step + 1 - REQUIRED_CONSECUTIVE_STEPS;
    for step in 1..=convergence_end_step {
        let converged = step >= convergence_start && gap_step != Some(step);
        observations.push(StepObservation {
            motor_model: MotorModel::ForceBased,
            angle_rad: if converged { angle } else { 0.0 },
            angular_velocity_rad_s: 0.0,
            motor_impulse_nms: impulse,
            anchor_error_m: 0.0,
        });
    }
    observations
}

fn synthetic_cells(
    convergence_end_steps: [usize; 4],
    gap: Option<(&'static str, f32, usize)>,
    unequal_allocation: Option<PhaseAllocation>,
) -> Result<Vec<Value>, String> {
    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for (allocation_index, declared_allocation) in PHASE_ALLOCATIONS.iter().enumerate() {
        let allocation = if unequal_allocation
            .is_some_and(|candidate| candidate.candidate_id == declared_allocation.candidate_id)
        {
            unequal_allocation.expect("checked Some")
        } else {
            *declared_allocation
        };
        let end_step = convergence_end_steps[allocation_index];
        for signed_arm in SIGNED_LEVER_ARMS_Z_M {
            let gap_step = gap.and_then(|(candidate_id, arm, step)| {
                (candidate_id == allocation.candidate_id && (arm - signed_arm).abs() <= 1.0e-6)
                    .then_some(step)
            });
            let trace = synthetic_trace(signed_arm, end_step, gap_step);
            cells.push(summarize_trace(allocation, signed_arm, &trace, 1, 1)?);
        }
    }
    Ok(cells)
}

fn summarize_candidates(cells: &[Value]) -> Vec<Value> {
    PHASE_ALLOCATIONS
        .iter()
        .map(|allocation| {
            let candidate_cells: Vec<Value> = cells
                .iter()
                .filter(|cell| cell["candidate_id"] == allocation.candidate_id)
                .cloned()
                .collect();
            candidate_summary(*allocation, &candidate_cells)
        })
        .collect()
}

pub fn run_force_based_solver_phase_development_preflight() -> Result<Value, String> {
    let declaration = preregistration()?;
    let mut default_canary = RevoluteJoint::new(Vector::X);
    default_canary.set_motor(
        0.1,
        0.0,
        POSITION_STIFFNESS_NM_PER_RAD,
        MOTOR_DAMPING_NM_S_PER_RAD,
    );
    let default_model = default_canary
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPD1_DEFAULT_MOTOR_MISSING".to_owned())?
        .model;
    let mut explicit = RevoluteJoint::new(Vector::X);
    explicit
        .set_motor(
            0.1,
            0.0,
            POSITION_STIFFNESS_NM_PER_RAD,
            MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .set_motor_model(MotorModel::ForceBased);
    let explicit_model = explicit
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPD1_EXPLICIT_MOTOR_MISSING".to_owned())?
        .model;
    explicit
        .set_motor(
            -0.1,
            0.5,
            POSITION_STIFFNESS_NM_PER_RAD,
            MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .set_motor_model(MotorModel::ForceBased);
    let mutable_model = explicit
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPD1_MUTABLE_MOTOR_MISSING".to_owned())?
        .model;

    let perfect_cells = synthetic_cells([220, 210, 200, 190], None, None)?;
    let perfect_summaries = summarize_candidates(&perfect_cells);
    let perfect_selection = select_candidate(&perfect_summaries);
    let perfect_aggregate =
        aggregate_report(&perfect_cells, &perfect_summaries, &perfect_selection);
    let perfect_failures =
        boundary_failures(&perfect_aggregate, &perfect_summaries, &perfect_selection);
    let perfect_serialized = serde_json::to_string(&perfect_cells)
        .map_err(|error| format!("C6_RAP_HC_SPD1_SYNTHETIC_SERIALIZE:{error}"))?;
    let perfect_round_trip: Value = serde_json::from_str(&perfect_serialized)
        .map_err(|error| format!("C6_RAP_HC_SPD1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let perfect_passed = perfect_failures.is_empty()
        && perfect_round_trip == json!(perfect_cells)
        && perfect_selection["selected_candidate_id"] == "SPD1-D";

    let no_eligible_cells = synthetic_cells([150, 150, 150, 150], None, None)?
        .into_iter()
        .map(|mut cell| {
            cell["ok"] = json!(false);
            cell["convergence_window_reached"] = json!(false);
            cell["convergence_window_start_step"] = Value::Null;
            cell["convergence_window_end_step"] = Value::Null;
            cell
        })
        .collect::<Vec<_>>();
    let no_eligible_summaries = summarize_candidates(&no_eligible_cells);
    let no_eligible_selection = select_candidate(&no_eligible_summaries);
    let no_eligible_rejected = no_eligible_selection["selected_candidate_id"].is_null()
        && no_eligible_selection["eligible_candidate_count"] == 0;

    let mut missing_cells = synthetic_cells([220, 210, 200, 190], None, None)?;
    missing_cells.pop();
    let missing_summaries = summarize_candidates(&missing_cells);
    let missing_selection = select_candidate(&missing_summaries);
    let missing_aggregate =
        aggregate_report(&missing_cells, &missing_summaries, &missing_selection);
    let missing_failures =
        boundary_failures(&missing_aggregate, &missing_summaries, &missing_selection);
    let missing_cell_rejected = missing_failures
        .iter()
        .any(|failure| failure.contains("cell_count") || failure.contains("candidate_identity"));

    let gap_cells = synthetic_cells([180, 180, 180, 180], Some(("SPD1-A", -0.25, 150)), None)?;
    let gap_summaries = summarize_candidates(&gap_cells);
    let window_gap_rejected = gap_summaries[0]["eligible_for_development_selection"] == false
        && gap_summaries[0]["passed_cell_count"] == 3;

    let unequal = PhaseAllocation {
        candidate_id: "SPD1-B",
        role: "post_heavy_intermediate",
        internal_pgs_iterations: 4,
        internal_stabilization_iterations: 5,
        tie_break_rank: 1,
    };
    let unequal_cells = synthetic_cells([180, 180, 180, 180], None, Some(unequal))?;
    let unequal_summaries = summarize_candidates(&unequal_cells);
    let unequal_total_pass_rejected = unequal_summaries[1]["identity_valid"] == false
        && unequal_summaries[1]["eligible_for_development_selection"] == false;

    let tie_cells = synthetic_cells([200, 200, 200, 200], None, None)?;
    let tie_summaries = summarize_candidates(&tie_cells);
    let tie_selection = select_candidate(&tie_summaries);
    let tie_break_passed = tie_selection["selected_candidate_id"] == "SPD1-A";

    let default_canary_passed = default_model == MotorModel::AccelerationBased;
    let explicit_builder_passed = explicit_model == MotorModel::ForceBased;
    let mutable_update_passed = mutable_model == MotorModel::ForceBased;
    let ok = default_canary_passed
        && explicit_builder_passed
        && mutable_update_passed
        && perfect_passed
        && no_eligible_rejected
        && missing_cell_rejected
        && window_gap_rejected
        && unequal_total_pass_rejected
        && tie_break_passed;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_solver_phase_development_preflight_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "solver_phase_diagnostic_raw_sha256":
            SOLVER_PHASE_DIAGNOSTIC_RAW_SHA256,
        "cw1_closure_raw_sha256": CW1_CLOSURE_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "rapier_version": rapier3d::VERSION,
        "default_model_canary": {
            "expected": "AccelerationBased",
            "observed": motor_model_name(default_model),
            "passed": default_canary_passed,
        },
        "explicit_builder_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(explicit_model),
            "passed": explicit_builder_passed,
        },
        "mutable_update_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(mutable_model),
            "passed": mutable_update_passed,
        },
        "perfect_sixteen_cell_traces_passed_entire_gate": perfect_passed,
        "perfect_failure_codes": perfect_failures,
        "known_fastest_candidate_selected": perfect_selection,
        "no_eligible_candidate_canary_selected_none": no_eligible_rejected,
        "missing_cell_canary_rejected": missing_cell_rejected,
        "missing_cell_canary_failure_codes": missing_failures,
        "window_gap_canary_rejected": window_gap_rejected,
        "unequal_total_pass_canary_rejected": unequal_total_pass_rejected,
        "tie_break_canary_selected_spd1_a": tie_break_passed,
        "declaration_claims": declaration["claims"].clone(),
        "world_build_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    }))
}

fn current_step_observation(
    world: &PhysicsWorld,
    parent: RigidBodyHandle,
    child: RigidBodyHandle,
    joint: ImpulseJointHandle,
) -> Result<StepObservation, String> {
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "C6_RAP_HC_SPD1_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_SPD1_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPD1_MOTOR_MISSING".to_owned())?;
    let angle_rad = revolute.angle(
        world.bodies[parent].rotation(),
        world.bodies[child].rotation(),
    );
    let angular_velocity_rad_s = world.bodies[child]
        .angvel()
        .dot(world.bodies[parent].rotation() * Vector::X);
    let parent_anchor_world = world.bodies[parent]
        .position()
        .transform_point(revolute.local_anchor1());
    let child_anchor_world = world.bodies[child]
        .position()
        .transform_point(revolute.local_anchor2());
    Ok(StepObservation {
        motor_model: motor.model,
        angle_rad,
        angular_velocity_rad_s,
        motor_impulse_nms: motor.impulse,
        anchor_error_m: (parent_anchor_world - child_anchor_world).length(),
    })
}

fn physical_cell(allocation: PhaseAllocation, signed_lever_arm_z_m: f32) -> Result<Value, String> {
    check(
        PHASE_ALLOCATIONS.contains(&allocation)
            && SIGNED_LEVER_ARMS_Z_M.contains(&signed_lever_arm_z_m)
            && allocation.internal_pgs_iterations + allocation.internal_stabilization_iterations
                == TOTAL_CONSTRAINT_PASSES,
        "C6_RAP_HC_SPD1_UNDECLARED_CELL",
    )?;
    let mut world = configured_world(Vector::new(0.0, -GRAVITY_M_S2, 0.0), allocation);
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _) = world.insert(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, 0.0, signed_lever_arm_z_m))
            .can_sleep(false),
        ColliderBuilder::cuboid(
            CHILD_HALF_EXTENTS_M[0],
            CHILD_HALF_EXTENTS_M[1],
            CHILD_HALF_EXTENTS_M[2],
        )
        .mass(CHILD_MASS_KG),
    );
    let joint = world.insert_impulse_joint(
        parent,
        child,
        RevoluteJointBuilder::new(Vector::X)
            .local_anchor1(Vector::ZERO)
            .local_anchor2(Vector::new(0.0, 0.0, -signed_lever_arm_z_m))
            .motor(
                0.0,
                0.0,
                POSITION_STIFFNESS_NM_PER_RAD,
                MOTOR_DAMPING_NM_S_PER_RAD,
            )
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(MAXIMUM_MOTOR_FORCE_NM),
    );

    let mut observations = Vec::with_capacity(MAXIMUM_OBSERVATION_STEPS);
    let mut consecutive = 0_usize;
    for step in 1..=MAXIMUM_OBSERVATION_STEPS {
        world.step();
        let observation = current_step_observation(&world, parent, child, joint)?;
        let metrics = evaluate_step(signed_lever_arm_z_m, &observation);
        if step >= MINIMUM_ACCEPTANCE_STEP && metrics.convergence_predicates_passed {
            consecutive += 1;
        } else {
            consecutive = 0;
        }
        observations.push(observation);
        if consecutive >= REQUIRED_CONSECUTIVE_STEPS {
            break;
        }
    }
    summarize_trace(allocation, signed_lever_arm_z_m, &observations, 1, 1)
}

fn panic_failure(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_owned()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "non-string panic payload".to_owned()
    }
}

fn failed_cell(allocation: PhaseAllocation, signed_lever_arm_z_m: f32, failure: String) -> Value {
    json!({
        "schema_version":
            "sporespore_rapier_force_based_solver_phase_development_cell_v1",
        "cell_kind": "gravity_static_convergence_development",
        "cell_id": cell_id(allocation, signed_lever_arm_z_m),
        "ok": false,
        "candidate_id": allocation.candidate_id,
        "candidate_role": allocation.role,
        "predeclared_tie_break_rank": allocation.tie_break_rank,
        "signed_lever_arm_z_m": signed_lever_arm_z_m,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": allocation.internal_pgs_iterations,
        "num_internal_stabilization_iterations":
            allocation.internal_stabilization_iterations,
        "total_constraint_passes_per_small_step":
            allocation.internal_pgs_iterations +
            allocation.internal_stabilization_iterations,
        "equal_total_pass_contract_passed": true,
        "failure_code": failure,
        "motor_model_readback_count": 0,
        "motor_model_mismatch_count": 1,
        "nonfinite_value_count": 0,
        "step_impulse_limit_violation_count": 0,
        "convergence_window_reached": false,
        "world_attempt_count": 1,
        "world_build_count": 0,
        "development_screen_evidence": true,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    })
}

fn retained_physical_cell(allocation: PhaseAllocation, signed_lever_arm_z_m: f32) -> Value {
    match catch_unwind(AssertUnwindSafe(|| {
        physical_cell(allocation, signed_lever_arm_z_m)
    })) {
        Ok(Ok(cell)) => cell,
        Ok(Err(failure)) => failed_cell(allocation, signed_lever_arm_z_m, failure),
        Err(payload) => failed_cell(
            allocation,
            signed_lever_arm_z_m,
            format!("C6_RAP_HC_SPD1_PANIC:{}", panic_failure(payload)),
        ),
    }
}

pub fn run_force_based_solver_phase_development(source_commit: &str) -> Result<Value, String> {
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "C6_RAP_HC_SPD1_SOURCE_COMMIT_INVALID",
    )?;
    let declaration = preregistration()?;
    let preflight = run_force_based_solver_phase_development_preflight()?;
    check(
        preflight["ok"] == true && preflight["world_build_count"] == 0,
        "C6_RAP_HC_SPD1_PREFLIGHT_FAILED",
    )?;

    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for allocation in PHASE_ALLOCATIONS {
        for signed_arm in SIGNED_LEVER_ARMS_Z_M {
            cells.push(retained_physical_cell(allocation, signed_arm));
        }
    }
    let candidate_summaries = summarize_candidates(&cells);
    let selection = select_candidate(&candidate_summaries);
    let aggregate = aggregate_report(&cells, &candidate_summaries, &selection);
    let failure_codes = boundary_failures(&aggregate, &candidate_summaries, &selection);
    let screen_complete = failure_codes.is_empty();
    let selected = selection["selected_candidate_id"].as_str().is_some();
    let ok = screen_complete && selected;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_solver_phase_development_report_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class":
            "exact_finite_cell_configuration_development_screen",
        "source": {
            "commit": source_commit,
            "remote": "origin/main",
            "origin_main_commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "preregistration": {
            "path":
                "sdk/rapier_c6_force_based_solver_phase_development_spd1_preregistration.json",
            "raw_sha256": PREREGISTRATION_RAW_SHA256,
            "status": declaration["status"].clone(),
            "implementation_parent_commit":
                declaration["implementation_parent_commit"].clone(),
        },
        "solver_phase_diagnostic_raw_sha256":
            SOLVER_PHASE_DIAGNOSTIC_RAW_SHA256,
        "cw1_closure_raw_sha256": CW1_CLOSURE_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "motor_model": "ForceBased",
        "outer_timestep_s": RAPIER_DT_S,
        "solver_iterations": SOLVER_ITERATIONS,
        "total_constraint_passes_per_small_step":
            TOTAL_CONSTRAINT_PASSES,
        "signed_lever_arms_z_m": SIGNED_LEVER_ARMS_Z_M,
        "maximum_observation_steps": MAXIMUM_OBSERVATION_STEPS,
        "minimum_acceptance_step": MINIMUM_ACCEPTANCE_STEP,
        "required_consecutive_converged_steps":
            REQUIRED_CONSECUTIVE_STEPS,
        "preflight": preflight,
        "cells": cells,
        "candidate_summaries": candidate_summaries,
        "selection": selection,
        "aggregate": aggregate,
        "boundary_failure_codes": failure_codes,
        "rapier_force_based_solver_phase_development_complete":
            screen_complete,
        "development_configuration_selected": selected,
        "selected_configuration_requires_fresh_independent_validation":
            selected,
        "rapier_force_based_static_convergence_characterization": false,
        "rapier_force_based_host_characterization": false,
        "rapier_selected_policy_physical_authority": false,
        "rapier_locomotion_acceptance": false,
        "different_physics_engines": false,
        "cross_engine_c6": false,
        "friction_or_material_robustness": false,
        "walking_acceptance": false,
        "release_authorized": false,
        "validation_authority": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn selector_uses_worst_then_total_then_frozen_rank() {
        let fastest_cells = synthetic_cells([220, 210, 200, 190], None, None).unwrap();
        let fastest = select_candidate(&summarize_candidates(&fastest_cells));
        assert_eq!(fastest["selected_candidate_id"], "SPD1-D");

        let tied_cells = synthetic_cells([200, 200, 200, 200], None, None).unwrap();
        let tied = select_candidate(&summarize_candidates(&tied_cells));
        assert_eq!(tied["selected_candidate_id"], "SPD1-A");
        assert_eq!(tied["fresh_independent_validation_required"], true);
        assert_eq!(tied["physical_acceptance_authority"], false);
    }

    #[test]
    fn preflight_is_zero_world_and_rejects_declared_canaries() {
        let report = run_force_based_solver_phase_development_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["perfect_sixteen_cell_traces_passed_entire_gate"],
            true
        );
        assert_eq!(
            report["known_fastest_candidate_selected"]["selected_candidate_id"],
            "SPD1-D"
        );
        assert_eq!(report["no_eligible_candidate_canary_selected_none"], true);
        assert_eq!(report["missing_cell_canary_rejected"], true);
        assert_eq!(report["window_gap_canary_rejected"], true);
        assert_eq!(report["unequal_total_pass_canary_rejected"], true);
        assert_eq!(report["tie_break_canary_selected_spd1_a"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["validation_authority"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }
}
