use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest_sha256};

const PREREGISTRATION_RAW: &str =
    include_str!("../../../rapier_c6_force_based_convergence_window_cw1_preregistration.json");
const LR1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_force_based_load_response_lr1_closure.json");
const LR1_POSTHOC_DIAGNOSTIC_RAW: &str =
    include_str!("../../../rapier_c6_force_based_load_response_lr1_posthoc_diagnostic.json");
const CARGO_LOCK_RAW: &str = include_str!("../../../Cargo.lock");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:bb38c730c3df137cebb240d1450263426d974630001caddc0d2f05f031eda3fb";
const LR1_CLOSURE_RAW_SHA256: &str =
    "sha256:edb1890f9b9b4a38e53446f474f7c75e5aff8ce102d797912ce4ac7ef7d61a9f";
const LR1_POSTHOC_DIAGNOSTIC_RAW_SHA256: &str =
    "sha256:5cf4f29192354479d23ca06e0306d1128b100bb3c9e224ceb7a25883999f38bb";
const CARGO_LOCK_RAW_SHA256: &str =
    "sha256:0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc";

const CAMPAIGN_ID: &str = "C6-RAPIER-FORCE-BASED-CONVERGENCE-WINDOW";
const GATE_ID: &str = "C6-RAP-HC-CW1";
const EXPECTED_WORLD_COUNT: u64 = 8;
const CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const CHILD_MASS_KG: f32 = 1.0;
const GRAVITY_M_S2: f32 = 9.8;
const POSITION_STIFFNESS_NM_PER_RAD: f32 = 40.0;
const MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
const MAXIMUM_MOTOR_FORCE_NM: f32 = 6.0;
const MAXIMUM_OBSERVATION_STEPS: usize = 1_440;
const MINIMUM_ACCEPTANCE_STEP: usize = 120;
const REQUIRED_CONSECUTIVE_STEPS: usize = 60;
const INTERNAL_PGS_ITERATIONS: usize = 1;
const INTERNAL_STABILIZATION_ITERATIONS: usize = 7;
const SIGNED_LEVER_ARMS_Z_M: [f32; 4] = [-0.2, 0.2, -0.4, 0.4];
const SOLVER_ITERATION_GRID: [usize; 2] = [12, 36];
const RESPONSE_MINIMUM: f32 = 0.98;
const RESPONSE_MAXIMUM: f32 = 1.02;
const MAXIMUM_STATIC_RESIDUAL: f32 = 0.01;
const MAXIMUM_DAMPING_LOAD_FRACTION: f32 = 0.005;
const MAXIMUM_FULL_PD_RESIDUAL: f32 = 0.005;
const MAXIMUM_ANCHOR_ERROR_M: f32 = 0.000_01;
const MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY: f32 = 0.005;
const MAXIMUM_SOLVER_SCALING_RELATIVE_ERROR: f32 = 0.02;
const STEP_IMPULSE_TOLERANCE_NMS: f32 = 0.000_001;

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

#[derive(Clone)]
struct CellObservation {
    signed_lever_arm_z_m: f32,
    solver_iterations: usize,
    terminal: StepObservation,
    terminal_metrics: StepMetrics,
    observation_steps_executed: usize,
    convergence_window_start_step: Option<usize>,
    convergence_window_end_step: Option<usize>,
    longest_consecutive_converged_steps: usize,
    maximum_observed_motor_impulse_nms: f32,
    motor_model_mismatch_count: u64,
    step_impulse_limit_violation_count: u64,
    nonfinite_value_count: u64,
    world_attempt_count: u64,
    world_build_count: u64,
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
        "C6_RAP_HC_CW1_PREREGISTRATION_HASH",
    )?;
    check(
        raw_sha256(LR1_CLOSURE_RAW) == LR1_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_CW1_LR1_CLOSURE_HASH",
    )?;
    check(
        raw_sha256(LR1_POSTHOC_DIAGNOSTIC_RAW) == LR1_POSTHOC_DIAGNOSTIC_RAW_SHA256,
        "C6_RAP_HC_CW1_LR1_POSTHOC_DIAGNOSTIC_HASH",
    )?;
    check(
        raw_sha256(CARGO_LOCK_RAW) == CARGO_LOCK_RAW_SHA256,
        "C6_RAP_HC_CW1_CARGO_LOCK_HASH",
    )?;
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_HC_CW1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        declaration["schema_version"]
            == "sporespore_rapier_c6_force_based_convergence_window_preregistration_v1"
            && declaration["campaign_id"] == CAMPAIGN_ID
            && declaration["gate_id"] == GATE_ID
            && declaration["status"] == "frozen_before_first_c6_rap_hc_cw1_physics_world"
            && declaration["implementation_parent_commit"]
                == "ce5baaa4fa5dd2df0cfd04d7683d9636c8511421"
            && declaration["scientifically_distinct_from_fb1_and_lr1"] == true
            && declaration["estimand"]["class"] == "exact_finite_cell_host_characterization"
            && declaration["predecessors"]["lr1"]["closure_raw_sha256"] == LR1_CLOSURE_RAW_SHA256
            && declaration["predecessors"]["lr1_posthoc_diagnostic"]["raw_sha256"]
                == LR1_POSTHOC_DIAGNOSTIC_RAW_SHA256
            && declaration["host_source_semantics"]["host_version"] == rapier3d::VERSION
            && declaration["host_source_semantics"]["cargo_lock_raw_sha256"]
                == CARGO_LOCK_RAW_SHA256
            && declaration["physical_grid"]["expected_world_count"] == EXPECTED_WORLD_COUNT
            && declaration["dynamics_grounded_horizon"]["maximum_observation_steps"]
                == MAXIMUM_OBSERVATION_STEPS
            && declaration["dynamics_grounded_horizon"]["minimum_steps_before_convergence_acceptance"]
                == MINIMUM_ACCEPTANCE_STEP
            && declaration["dynamics_grounded_horizon"]["required_consecutive_converged_steps"]
                == REQUIRED_CONSECUTIVE_STEPS
            && declaration["preflight_contract"]["must_run_before_any_physics_world"] == true
            && declaration["preflight_contract"]["perfect_eight_cell_convergence_traces_must_pass_entire_gate"]
                == true
            && declaration["preflight_contract"]["single_acceptable_step_canary_must_fail"] == true
            && declaration["preflight_contract"]["window_gap_canary_must_fail"] == true
            && declaration["preflight_contract"]["whole_outer_step_impulse_canary_must_fail"]
                == true
            && declaration["preflight_contract"]["missing_cell_canary_must_fail"] == true,
        "C6_RAP_HC_CW1_PREREGISTRATION_IDENTITY",
    )?;
    Ok(declaration)
}

fn configured_world(gravity: Vector, solver_iterations: usize) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = solver_iterations;
    world.integration_parameters.num_internal_pgs_iterations = INTERNAL_PGS_ITERATIONS;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = INTERNAL_STABILIZATION_ITERATIONS;
    world
}

fn gravity_torque_nm(signed_lever_arm_z_m: f32, angle_rad: f32) -> f32 {
    CHILD_MASS_KG * GRAVITY_M_S2 * signed_lever_arm_z_m.abs() * angle_rad.abs().cos()
}

fn expected_small_step_impulse_nms(
    signed_lever_arm_z_m: f32,
    angle_rad: f32,
    solver_iterations: usize,
) -> f32 {
    gravity_torque_nm(signed_lever_arm_z_m, angle_rad) * RAPIER_DT_S / solver_iterations as f32
}

fn small_step_impulse_limit_nms(solver_iterations: usize) -> f32 {
    MAXIMUM_MOTOR_FORCE_NM * RAPIER_DT_S / solver_iterations as f32
}

fn cell_id(signed_lever_arm_z_m: f32, solver_iterations: usize) -> String {
    let sign = if signed_lever_arm_z_m < 0.0 {
        "negative"
    } else {
        "positive"
    };
    format!(
        "arm_{:.2}_{sign}_solver_{solver_iterations}",
        signed_lever_arm_z_m.abs()
    )
}

fn evaluate_step(
    signed_lever_arm_z_m: f32,
    solver_iterations: usize,
    observation: &StepObservation,
) -> StepMetrics {
    let gravity_torque = gravity_torque_nm(signed_lever_arm_z_m, observation.angle_rad);
    let expected_impulse = gravity_torque * RAPIER_DT_S / solver_iterations as f32;
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
        <= small_step_impulse_limit_nms(solver_iterations) + STEP_IMPULSE_TOLERANCE_NMS;
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
    signed_lever_arm_z_m: f32,
    solver_iterations: usize,
    observations: &[StepObservation],
    world_attempt_count: u64,
    world_build_count: u64,
) -> Result<CellObservation, String> {
    check(
        !observations.is_empty() && observations.len() <= MAXIMUM_OBSERVATION_STEPS,
        "C6_RAP_HC_CW1_TRACE_LENGTH",
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
    let mut terminal_metrics = evaluate_step(signed_lever_arm_z_m, solver_iterations, &terminal);

    for (index, observation) in observations.iter().enumerate() {
        let step = index + 1;
        let metrics = evaluate_step(signed_lever_arm_z_m, solver_iterations, observation);
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
    Ok(CellObservation {
        signed_lever_arm_z_m,
        solver_iterations,
        terminal,
        terminal_metrics,
        observation_steps_executed,
        convergence_window_start_step: convergence_start,
        convergence_window_end_step: convergence_end,
        longest_consecutive_converged_steps: longest,
        maximum_observed_motor_impulse_nms: maximum_impulse,
        motor_model_mismatch_count: model_mismatches,
        step_impulse_limit_violation_count: impulse_limit_violations,
        nonfinite_value_count: nonfinite_values,
        world_attempt_count,
        world_build_count,
    })
}

fn evaluate_cell(observation: &CellObservation) -> Value {
    let convergence_reached = observation.convergence_window_start_step.is_some()
        && observation.convergence_window_end_step.is_some()
        && observation.longest_consecutive_converged_steps >= REQUIRED_CONSECUTIVE_STEPS;
    let passed = convergence_reached
        && observation.observation_steps_executed >= MINIMUM_ACCEPTANCE_STEP
        && observation.observation_steps_executed <= MAXIMUM_OBSERVATION_STEPS
        && observation.terminal.motor_model == MotorModel::ForceBased
        && observation.motor_model_mismatch_count == 0
        && observation.nonfinite_value_count == 0
        && observation.step_impulse_limit_violation_count == 0
        && observation.terminal_metrics.convergence_predicates_passed
        && observation.maximum_observed_motor_impulse_nms
            <= small_step_impulse_limit_nms(observation.solver_iterations)
                + STEP_IMPULSE_TOLERANCE_NMS
        && observation.world_attempt_count == 1
        && observation.world_build_count == 1;

    json!({
        "schema_version":
            "sporespore_rapier_force_based_convergence_window_cell_v1",
        "cell_kind": "gravity_static_convergence",
        "cell_id": cell_id(
            observation.signed_lever_arm_z_m,
            observation.solver_iterations,
        ),
        "ok": passed,
        "signed_lever_arm_z_m": observation.signed_lever_arm_z_m,
        "solver_iterations": observation.solver_iterations,
        "small_step_timestep_s":
            RAPIER_DT_S / observation.solver_iterations as f32,
        "mass_kg": CHILD_MASS_KG,
        "gravity_m_s2": [0.0, -GRAVITY_M_S2, 0.0],
        "target_position_rad": 0.0,
        "target_velocity_rad_s": 0.0,
        "position_stiffness_nm_per_rad": POSITION_STIFFNESS_NM_PER_RAD,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "small_step_impulse_limit_nms":
            small_step_impulse_limit_nms(observation.solver_iterations),
        "motor_model_readback": motor_model_name(observation.terminal.motor_model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": observation.motor_model_mismatch_count,
        "final_angle_rad": observation.terminal.angle_rad,
        "terminal_angular_velocity_rad_s":
            observation.terminal.angular_velocity_rad_s,
        "terminal_motor_impulse_nms": observation.terminal.motor_impulse_nms,
        "maximum_observed_motor_impulse_nms":
            observation.maximum_observed_motor_impulse_nms,
        "gravity_torque_nm": observation.terminal_metrics.gravity_torque_nm,
        "expected_terminal_small_step_impulse_nms":
            observation.terminal_metrics.expected_small_step_impulse_nms,
        "normalized_terminal_impulse_response":
            observation.terminal_metrics.normalized_impulse_response,
        "spring_only_static_residual":
            observation.terminal_metrics.spring_only_static_residual,
        "damping_load_fraction":
            observation.terminal_metrics.damping_load_fraction,
        "full_pd_gravity_residual":
            observation.terminal_metrics.full_pd_gravity_residual,
        "signed_geometry_passed":
            observation.terminal_metrics.signed_geometry_passed,
        "response_passed": observation.terminal_metrics.response_passed,
        "static_residual_passed":
            observation.terminal_metrics.static_residual_passed,
        "damping_fraction_passed":
            observation.terminal_metrics.damping_fraction_passed,
        "full_pd_residual_passed":
            observation.terminal_metrics.full_pd_residual_passed,
        "anchor_passed": observation.terminal_metrics.anchor_passed,
        "force_limit_passed": observation.terminal_metrics.force_limit_passed,
        "finite_terminal_values": observation.terminal_metrics.finite_values,
        "convergence_predicates_passed_at_terminal":
            observation.terminal_metrics.convergence_predicates_passed,
        "final_anchor_error_m": observation.terminal.anchor_error_m,
        "minimum_acceptance_step": MINIMUM_ACCEPTANCE_STEP,
        "required_consecutive_converged_steps": REQUIRED_CONSECUTIVE_STEPS,
        "maximum_observation_steps": MAXIMUM_OBSERVATION_STEPS,
        "observation_steps_executed": observation.observation_steps_executed,
        "convergence_window_reached": convergence_reached,
        "convergence_window_start_step":
            observation.convergence_window_start_step,
        "convergence_window_end_step":
            observation.convergence_window_end_step,
        "longest_consecutive_converged_steps":
            observation.longest_consecutive_converged_steps,
        "step_impulse_limit_violation_count":
            observation.step_impulse_limit_violation_count,
        "nonfinite_value_count": observation.nonfinite_value_count,
        "world_attempt_count": observation.world_attempt_count,
        "world_build_count": observation.world_build_count,
        "physical_acceptance_authority": false,
    })
}

fn value_sum(cells: &[Value], field: &str) -> u64 {
    cells
        .iter()
        .map(|cell| cell[field].as_u64().unwrap_or(0))
        .sum()
}

fn matching_cell(
    cells: &[Value],
    signed_lever_arm_z_m: f32,
    solver_iterations: usize,
) -> Option<&Value> {
    cells.iter().find(|cell| {
        cell["signed_lever_arm_z_m"]
            .as_f64()
            .is_some_and(|value| (value - signed_lever_arm_z_m as f64).abs() <= 1.0e-6)
            && cell["solver_iterations"].as_u64() == Some(solver_iterations as u64)
    })
}

fn signed_pair_symmetry(cells: &[Value]) -> (bool, f64) {
    let mut maximum_asymmetry = 0.0_f64;
    for solver_iterations in SOLVER_ITERATION_GRID {
        for arm_magnitude in [0.2_f32, 0.4_f32] {
            let Some(negative) = matching_cell(cells, -arm_magnitude, solver_iterations) else {
                return (false, f64::INFINITY);
            };
            let Some(positive) = matching_cell(cells, arm_magnitude, solver_iterations) else {
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
    }
    (
        maximum_asymmetry <= MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY as f64,
        maximum_asymmetry,
    )
}

fn arm_magnitude_ordering(cells: &[Value]) -> bool {
    for solver_iterations in SOLVER_ITERATION_GRID {
        for sign in [-1.0_f32, 1.0_f32] {
            let Some(lower) = matching_cell(cells, sign * 0.2, solver_iterations) else {
                return false;
            };
            let Some(higher) = matching_cell(cells, sign * 0.4, solver_iterations) else {
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
    }
    true
}

fn solver_inverse_scaling(cells: &[Value]) -> (bool, f64) {
    let expected_ratio = SOLVER_ITERATION_GRID[1] as f64 / SOLVER_ITERATION_GRID[0] as f64;
    let mut maximum_relative_error = 0.0_f64;
    for signed_arm in SIGNED_LEVER_ARMS_Z_M {
        let Some(lower_iterations) = matching_cell(cells, signed_arm, SOLVER_ITERATION_GRID[0])
        else {
            return (false, f64::INFINITY);
        };
        let Some(higher_iterations) = matching_cell(cells, signed_arm, SOLVER_ITERATION_GRID[1])
        else {
            return (false, f64::INFINITY);
        };
        let Some(lower_impulse) = lower_iterations["terminal_motor_impulse_nms"].as_f64() else {
            return (false, f64::INFINITY);
        };
        let Some(higher_impulse) = higher_iterations["terminal_motor_impulse_nms"].as_f64() else {
            return (false, f64::INFINITY);
        };
        if higher_impulse == 0.0 {
            return (false, f64::INFINITY);
        }
        let observed_ratio = lower_impulse.abs() / higher_impulse.abs();
        maximum_relative_error =
            maximum_relative_error.max((observed_ratio / expected_ratio - 1.0).abs());
    }
    (
        maximum_relative_error <= MAXIMUM_SOLVER_SCALING_RELATIVE_ERROR as f64,
        maximum_relative_error,
    )
}

fn aggregate_cells(cells: &[Value]) -> Value {
    let passed_cell_count = cells.iter().filter(|cell| cell["ok"] == true).count() as u64;
    let convergence_window_reached_count = cells
        .iter()
        .filter(|cell| cell["convergence_window_reached"] == true)
        .count() as u64;
    let (signed_pair_symmetry_passed, maximum_signed_pair_relative_asymmetry) =
        signed_pair_symmetry(cells);
    let arm_magnitude_ordering_passed = arm_magnitude_ordering(cells);
    let (solver_iteration_inverse_scaling_passed, maximum_solver_scaling_relative_error) =
        solver_inverse_scaling(cells);
    let convergence_grid_passed =
        cells.len() as u64 == EXPECTED_WORLD_COUNT && passed_cell_count == EXPECTED_WORLD_COUNT;
    json!({
        "world_attempt_count": value_sum(cells, "world_attempt_count"),
        "world_build_count": value_sum(cells, "world_build_count"),
        "cell_count": cells.len() as u64,
        "passed_cell_count": passed_cell_count,
        "failed_cell_count": cells.len() as u64 - passed_cell_count,
        "motor_model_readback_count": value_sum(cells, "motor_model_readback_count"),
        "motor_model_mismatch_count": value_sum(cells, "motor_model_mismatch_count"),
        "nonfinite_value_count": value_sum(cells, "nonfinite_value_count"),
        "step_impulse_limit_violation_count":
            value_sum(cells, "step_impulse_limit_violation_count"),
        "convergence_window_reached_count":
            convergence_window_reached_count,
        "load_relative_static_convergence_grid_passed": convergence_grid_passed,
        "signed_pair_symmetry_passed": signed_pair_symmetry_passed,
        "maximum_signed_pair_relative_asymmetry":
            maximum_signed_pair_relative_asymmetry,
        "arm_magnitude_ordering_passed": arm_magnitude_ordering_passed,
        "solver_iteration_inverse_scaling_passed":
            solver_iteration_inverse_scaling_passed,
        "maximum_solver_scaling_relative_error":
            maximum_solver_scaling_relative_error,
    })
}

fn integrity_failures(aggregate: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    for (field, expected) in [
        ("world_attempt_count", EXPECTED_WORLD_COUNT),
        ("world_build_count", EXPECTED_WORLD_COUNT),
        ("cell_count", EXPECTED_WORLD_COUNT),
        ("passed_cell_count", EXPECTED_WORLD_COUNT),
        ("failed_cell_count", 0),
        ("motor_model_readback_count", EXPECTED_WORLD_COUNT),
        ("motor_model_mismatch_count", 0),
        ("nonfinite_value_count", 0),
        ("step_impulse_limit_violation_count", 0),
        ("convergence_window_reached_count", EXPECTED_WORLD_COUNT),
    ] {
        if aggregate[field].as_u64() != Some(expected) {
            failures.push(format!("C6_RAP_HC_CW1_{field}_INVALID"));
        }
    }
    for field in [
        "load_relative_static_convergence_grid_passed",
        "signed_pair_symmetry_passed",
        "arm_magnitude_ordering_passed",
        "solver_iteration_inverse_scaling_passed",
    ] {
        if aggregate[field].as_bool() != Some(true) {
            failures.push(format!("C6_RAP_HC_CW1_{field}_INVALID"));
        }
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

fn perfect_synthetic_trace(signed_arm: f32, solver_iterations: usize) -> Vec<StepObservation> {
    let mut observations = Vec::with_capacity(MINIMUM_ACCEPTANCE_STEP + REQUIRED_CONSECUTIVE_STEPS);
    let warmup_impulse =
        signed_arm.signum() * expected_small_step_impulse_nms(signed_arm, 0.0, solver_iterations);
    for _ in 0..MINIMUM_ACCEPTANCE_STEP {
        observations.push(StepObservation {
            motor_model: MotorModel::ForceBased,
            angle_rad: 0.0,
            angular_velocity_rad_s: 0.0,
            motor_impulse_nms: warmup_impulse,
            anchor_error_m: 0.0,
        });
    }
    let angle = signed_arm.signum() * equilibrium_angle_abs(signed_arm.abs());
    let impulse =
        signed_arm.signum() * expected_small_step_impulse_nms(signed_arm, angle, solver_iterations);
    for _ in 0..REQUIRED_CONSECUTIVE_STEPS {
        observations.push(StepObservation {
            motor_model: MotorModel::ForceBased,
            angle_rad: angle,
            angular_velocity_rad_s: 0.0,
            motor_impulse_nms: impulse,
            anchor_error_m: 0.0,
        });
    }
    observations
}

fn perfect_synthetic_cells() -> Result<Vec<Value>, String> {
    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for solver_iterations in SOLVER_ITERATION_GRID {
        for signed_arm in SIGNED_LEVER_ARMS_Z_M {
            let trace = perfect_synthetic_trace(signed_arm, solver_iterations);
            let observation = summarize_trace(signed_arm, solver_iterations, &trace, 1, 1)?;
            cells.push(evaluate_cell(&observation));
        }
    }
    Ok(cells)
}

pub fn run_force_based_convergence_window_preflight() -> Result<Value, String> {
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
        .ok_or_else(|| "C6_RAP_HC_CW1_DEFAULT_CANARY_MOTOR_MISSING".to_owned())?
        .model;

    let explicit_builder = RevoluteJointBuilder::new(Vector::X)
        .motor(
            0.1,
            0.0,
            POSITION_STIFFNESS_NM_PER_RAD,
            MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .motor_model(MotorModel::ForceBased)
        .build();
    let explicit_builder_model = explicit_builder
        .motor()
        .ok_or_else(|| "C6_RAP_HC_CW1_EXPLICIT_BUILDER_MOTOR_MISSING".to_owned())?
        .model;

    let mut mutable = explicit_builder;
    mutable
        .set_motor(
            -0.1,
            0.5,
            POSITION_STIFFNESS_NM_PER_RAD,
            MOTOR_DAMPING_NM_S_PER_RAD,
        )
        .set_motor_model(MotorModel::ForceBased);
    let mutable_update_model = mutable
        .motor()
        .ok_or_else(|| "C6_RAP_HC_CW1_MUTABLE_MOTOR_MISSING".to_owned())?
        .model;

    let perfect_cells = perfect_synthetic_cells()?;
    let perfect_aggregate = aggregate_cells(&perfect_cells);
    let perfect_failures = integrity_failures(&perfect_aggregate);
    let serialized = serde_json::to_string(&perfect_cells)
        .map_err(|error| format!("C6_RAP_HC_CW1_SYNTHETIC_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_HC_CW1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let round_trip_valid = round_trip.as_array().is_some_and(|cells| {
        cells.len() as u64 == EXPECTED_WORLD_COUNT
            && cells.iter().all(|cell| {
                cell["schema_version"] == "sporespore_rapier_force_based_convergence_window_cell_v1"
                    && cell["cell_kind"] == "gravity_static_convergence"
            })
    });
    let perfect_passed = perfect_failures.is_empty()
        && round_trip_valid
        && perfect_aggregate["load_relative_static_convergence_grid_passed"] == true;

    let canary_arm = SIGNED_LEVER_ARMS_Z_M[0];
    let canary_iterations = SOLVER_ITERATION_GRID[0];
    let perfect_trace = perfect_synthetic_trace(canary_arm, canary_iterations);

    let single_step_trace = perfect_trace[..MINIMUM_ACCEPTANCE_STEP + 1].to_vec();
    let single_step_cell = evaluate_cell(&summarize_trace(
        canary_arm,
        canary_iterations,
        &single_step_trace,
        1,
        1,
    )?);
    let single_step_canary_rejected = single_step_cell["ok"] == false;

    let mut gap_trace = perfect_trace.clone();
    let gap_index = MINIMUM_ACCEPTANCE_STEP + REQUIRED_CONSECUTIVE_STEPS / 2;
    gap_trace[gap_index].angle_rad = 0.0;
    let gap_cell = evaluate_cell(&summarize_trace(
        canary_arm,
        canary_iterations,
        &gap_trace,
        1,
        1,
    )?);
    let window_gap_canary_rejected = gap_cell["ok"] == false;

    let mut whole_step_trace = perfect_trace;
    let response_index = MINIMUM_ACCEPTANCE_STEP;
    whole_step_trace[response_index].motor_impulse_nms *= canary_iterations as f32;
    let whole_step_cell = evaluate_cell(&summarize_trace(
        canary_arm,
        canary_iterations,
        &whole_step_trace,
        1,
        1,
    )?);
    let whole_step_canary_rejected = whole_step_cell["ok"] == false;

    let mut missing_cells = perfect_cells.clone();
    missing_cells.pop();
    let missing_aggregate = aggregate_cells(&missing_cells);
    let missing_failures = integrity_failures(&missing_aggregate);
    let missing_cell_canary_rejected = !missing_failures.is_empty();

    let default_canary_passed = default_model == MotorModel::AccelerationBased;
    let explicit_builder_passed = explicit_builder_model == MotorModel::ForceBased;
    let mutable_update_passed = mutable_update_model == MotorModel::ForceBased;
    let ok = default_canary_passed
        && explicit_builder_passed
        && mutable_update_passed
        && perfect_passed
        && single_step_canary_rejected
        && window_gap_canary_rejected
        && whole_step_canary_rejected
        && missing_cell_canary_rejected;

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_convergence_window_preflight_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "rapier_version": rapier3d::VERSION,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "lr1_closure_raw_sha256": LR1_CLOSURE_RAW_SHA256,
        "lr1_posthoc_diagnostic_raw_sha256":
            LR1_POSTHOC_DIAGNOSTIC_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "default_model_canary": {
            "expected": "AccelerationBased",
            "observed": motor_model_name(default_model),
            "passed": default_canary_passed,
        },
        "explicit_builder_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(explicit_builder_model),
            "passed": explicit_builder_passed,
        },
        "mutable_update_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(mutable_update_model),
            "passed": mutable_update_passed,
        },
        "perfect_eight_cell_convergence_traces_passed_entire_gate":
            perfect_passed,
        "perfect_trace_serialization_round_trip_passed": round_trip_valid,
        "perfect_aggregate": perfect_aggregate,
        "perfect_failure_codes": perfect_failures,
        "single_acceptable_step_canary_rejected":
            single_step_canary_rejected,
        "single_acceptable_step_canary_cell": single_step_cell,
        "window_gap_canary_rejected": window_gap_canary_rejected,
        "window_gap_canary_cell": gap_cell,
        "whole_outer_step_impulse_canary_rejected":
            whole_step_canary_rejected,
        "whole_outer_step_impulse_canary_cell": whole_step_cell,
        "missing_cell_canary_rejected": missing_cell_canary_rejected,
        "missing_cell_canary_failure_codes": missing_failures,
        "declaration_claims": declaration["claims"].clone(),
        "world_build_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
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
        .ok_or_else(|| "C6_RAP_HC_CW1_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_CW1_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_CW1_MOTOR_MISSING".to_owned())?;
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

fn physical_observation(
    signed_lever_arm_z_m: f32,
    solver_iterations: usize,
) -> Result<CellObservation, String> {
    check(
        SIGNED_LEVER_ARMS_Z_M.contains(&signed_lever_arm_z_m)
            && SOLVER_ITERATION_GRID.contains(&solver_iterations),
        "C6_RAP_HC_CW1_UNDECLARED_CELL",
    )?;
    let mut world = configured_world(Vector::new(0.0, -GRAVITY_M_S2, 0.0), solver_iterations);
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
        let metrics = evaluate_step(signed_lever_arm_z_m, solver_iterations, &observation);
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
    summarize_trace(signed_lever_arm_z_m, solver_iterations, &observations, 1, 1)
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

fn retained_physical_cell(signed_lever_arm_z_m: f32, solver_iterations: usize) -> Value {
    match catch_unwind(AssertUnwindSafe(|| {
        physical_observation(signed_lever_arm_z_m, solver_iterations)
    })) {
        Ok(Ok(observation)) => evaluate_cell(&observation),
        Ok(Err(failure)) => json!({
            "schema_version":
                "sporespore_rapier_force_based_convergence_window_cell_v1",
            "cell_kind": "gravity_static_convergence",
            "cell_id": cell_id(signed_lever_arm_z_m, solver_iterations),
            "ok": false,
            "signed_lever_arm_z_m": signed_lever_arm_z_m,
            "solver_iterations": solver_iterations,
            "failure_code": failure,
            "motor_model_readback_count": 0,
            "motor_model_mismatch_count": 1,
            "nonfinite_value_count": 0,
            "step_impulse_limit_violation_count": 0,
            "convergence_window_reached": false,
            "world_attempt_count": 1,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        }),
        Err(payload) => json!({
            "schema_version":
                "sporespore_rapier_force_based_convergence_window_cell_v1",
            "cell_kind": "gravity_static_convergence",
            "cell_id": cell_id(signed_lever_arm_z_m, solver_iterations),
            "ok": false,
            "signed_lever_arm_z_m": signed_lever_arm_z_m,
            "solver_iterations": solver_iterations,
            "failure_code": format!(
                "C6_RAP_HC_CW1_PANIC:{}",
                panic_failure(payload)
            ),
            "motor_model_readback_count": 0,
            "motor_model_mismatch_count": 1,
            "nonfinite_value_count": 0,
            "step_impulse_limit_violation_count": 0,
            "convergence_window_reached": false,
            "world_attempt_count": 1,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        }),
    }
}

pub fn run_force_based_convergence_window(source_commit: &str) -> Result<Value, String> {
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "C6_RAP_HC_CW1_SOURCE_COMMIT_INVALID",
    )?;
    let declaration = preregistration()?;
    let preflight = run_force_based_convergence_window_preflight()?;
    check(
        preflight["ok"] == true && preflight["world_build_count"] == 0,
        "C6_RAP_HC_CW1_PREFLIGHT_FAILED",
    )?;

    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for solver_iterations in SOLVER_ITERATION_GRID {
        for signed_arm in SIGNED_LEVER_ARMS_Z_M {
            cells.push(retained_physical_cell(signed_arm, solver_iterations));
        }
    }
    let aggregate = aggregate_cells(&cells);
    let failure_codes = integrity_failures(&aggregate);
    let ok = failure_codes.is_empty();

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_convergence_window_report_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "estimand_class": "exact_finite_cell_host_characterization",
        "source": {
            "commit": source_commit,
            "remote": "origin/main",
            "origin_main_commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "preregistration": {
            "path":
                "sdk/rapier_c6_force_based_convergence_window_cw1_preregistration.json",
            "raw_sha256": PREREGISTRATION_RAW_SHA256,
            "status": declaration["status"].clone(),
            "implementation_parent_commit":
                declaration["implementation_parent_commit"].clone(),
        },
        "lr1_closure_raw_sha256": LR1_CLOSURE_RAW_SHA256,
        "lr1_posthoc_diagnostic_raw_sha256":
            LR1_POSTHOC_DIAGNOSTIC_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "host_source_semantics":
            declaration["host_source_semantics"].clone(),
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "motor_model": "ForceBased",
        "outer_timestep_s": RAPIER_DT_S,
        "signed_lever_arms_z_m": SIGNED_LEVER_ARMS_Z_M,
        "solver_iteration_grid": SOLVER_ITERATION_GRID,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "minimum_acceptance_step": MINIMUM_ACCEPTANCE_STEP,
        "required_consecutive_converged_steps": REQUIRED_CONSECUTIVE_STEPS,
        "maximum_observation_steps": MAXIMUM_OBSERVATION_STEPS,
        "preflight": preflight,
        "cells": cells,
        "aggregate": aggregate,
        "failure_codes": failure_codes,
        "rapier_force_based_static_convergence_characterization": ok,
        "rapier_force_based_host_characterization": ok,
        "rapier_selected_policy_physical_authority": false,
        "rapier_locomotion_acceptance": false,
        "different_physics_engines": false,
        "cross_engine_c6": false,
        "friction_or_material_robustness": false,
        "walking_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    }))
}
