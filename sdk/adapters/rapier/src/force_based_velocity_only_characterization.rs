use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::active_configuration::new_active_world;
use crate::{
    ADAPTER_ID, RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
    RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS, RAPIER_ACTIVE_SOLVER_ITERATIONS, RAPIER_DT_S,
    capability_manifest_sha256,
};

const PREREGISTRATION_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json"
);
const CANONICAL_PROFILE_RAW: &str =
    include_str!("../../../canonical_velocity_actuation_profile_v1.json");
const SPV1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
);
const CARGO_LOCK_RAW: &str = include_str!("../../../Cargo.lock");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:a0f7bd5994da1df009e59fb75f13bd831db1d916b99a470001bd2f58aae1caf0";
const CANONICAL_PROFILE_RAW_SHA256: &str =
    "sha256:1240ad4bba89bc8d1c22fa270fa718c57ab5ee227d777434b3870b859001e6a3";
const SPV1_CLOSURE_RAW_SHA256: &str =
    "sha256:7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203";
const CARGO_LOCK_RAW_SHA256: &str =
    "sha256:0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc";

const CAMPAIGN_ID: &str = "C6-RAPIER-FORCE-BASED-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1";
const GATE_ID: &str = "C6-RAP-HC-VH1";
const CANONICAL_PROFILE_ID: &str = "sporespore_complete_closed_loop_canonical_velocity_v1";
const RAPIER_PROFILE_ID: &str = "rapier_force_based_velocity_only_v1";

const EXPECTED_WORLD_COUNT: u64 = 12;
const CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const CHILD_MASS_KG: f32 = 1.0;
const TARGET_POSITION_RAD: f32 = 0.0;
const POSITION_STIFFNESS_NM_PER_RAD: f32 = 0.0;
const MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
const MAXIMUM_MOTOR_FORCE_NM: f32 = 6.0;
const UNLOADED_TARGET_VELOCITIES_RAD_S: [f32; 4] = [-0.75, 0.75, -2.25, 2.25];
const LOADED_TARGET_VELOCITIES_RAD_S: [f32; 2] = [-1.5, 1.5];
const SIGNED_EXTERNAL_TORQUES_NM: [f32; 4] = [-0.75, 0.75, -2.25, 2.25];
const MINIMUM_ACCEPTANCE_OUTER_STEP: usize = 120;
const REQUIRED_CONSECUTIVE_ACCEPTABLE_STEPS: usize = 60;
const OBSERVATION_OUTER_STEPS: usize = 360;
const RESPONSE_MINIMUM: f32 = 0.98;
const RESPONSE_MAXIMUM: f32 = 1.02;
const MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY: f64 = 0.005;
const MAXIMUM_ANCHOR_ERROR_M: f32 = 0.000_01;
const STEP_IMPULSE_TOLERANCE_NMS: f32 = 0.000_001;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum CellKind {
    UnloadedVelocity,
    ConstantTorqueLoadedVelocity,
}

impl CellKind {
    fn name(self) -> &'static str {
        match self {
            Self::UnloadedVelocity => "unloaded_velocity",
            Self::ConstantTorqueLoadedVelocity => "constant_torque_loaded_velocity",
        }
    }
}

#[derive(Clone, Copy, Debug)]
struct CellSpec {
    kind: CellKind,
    target_velocity_rad_s: f32,
    external_torque_nm: f32,
}

#[derive(Clone)]
struct CellObservation {
    spec: CellSpec,
    motor_model: MotorModel,
    readback_target_position_rad: f32,
    readback_target_velocity_rad_s: f32,
    readback_stiffness_nm_per_rad: f32,
    readback_damping_nm_s_per_rad: f32,
    readback_maximum_force_nm: f32,
    terminal_velocity_rad_s: f32,
    terminal_motor_impulse_nms: f32,
    maximum_observed_motor_impulse_nms: f32,
    final_anchor_error_m: f32,
    longest_consecutive_acceptable_steps: usize,
    motor_update_readback_count: u64,
    motor_model_mismatch_count: u64,
    motor_field_mismatch_count: u64,
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

fn sign_label(value: f32) -> &'static str {
    if value < 0.0 { "negative" } else { "positive" }
}

fn magnitude_label(value: f32) -> String {
    format!("{:.2}", value.abs()).replace('.', "_")
}

fn cell_id(spec: CellSpec) -> String {
    match spec.kind {
        CellKind::UnloadedVelocity => format!(
            "unloaded_target_{}_{}",
            sign_label(spec.target_velocity_rad_s),
            magnitude_label(spec.target_velocity_rad_s)
        ),
        CellKind::ConstantTorqueLoadedVelocity => format!(
            "loaded_target_{}_{}_torque_{}_{}",
            sign_label(spec.target_velocity_rad_s),
            magnitude_label(spec.target_velocity_rad_s),
            sign_label(spec.external_torque_nm),
            magnitude_label(spec.external_torque_nm)
        ),
    }
}

fn declared_specs() -> Vec<CellSpec> {
    let mut specs = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for target_velocity_rad_s in UNLOADED_TARGET_VELOCITIES_RAD_S {
        specs.push(CellSpec {
            kind: CellKind::UnloadedVelocity,
            target_velocity_rad_s,
            external_torque_nm: 0.0,
        });
    }
    for target_velocity_rad_s in LOADED_TARGET_VELOCITIES_RAD_S {
        for external_torque_nm in SIGNED_EXTERNAL_TORQUES_NM {
            specs.push(CellSpec {
                kind: CellKind::ConstantTorqueLoadedVelocity,
                target_velocity_rad_s,
                external_torque_nm,
            });
        }
    }
    specs
}

fn expected_terminal_velocity(spec: CellSpec) -> f32 {
    spec.target_velocity_rad_s + spec.external_torque_nm / MOTOR_DAMPING_NM_S_PER_RAD
}

fn small_step_timestep_s() -> f32 {
    RAPIER_DT_S / RAPIER_ACTIVE_SOLVER_ITERATIONS as f32
}

fn expected_terminal_motor_impulse_nms(spec: CellSpec) -> f32 {
    spec.external_torque_nm * small_step_timestep_s()
}

fn small_step_impulse_limit_nms() -> f32 {
    MAXIMUM_MOTOR_FORCE_NM * small_step_timestep_s()
}

fn relative_difference(first: f64, second: f64) -> f64 {
    let scale = ((first.abs() + second.abs()) * 0.5).max(f64::EPSILON);
    (first.abs() - second.abs()).abs() / scale
}

fn same_nonzero_sign(first: f32, second: f32) -> bool {
    first != 0.0 && second != 0.0 && first.signum() == second.signum()
}

fn motor_fields_match(motor: &JointMotor, target_velocity_rad_s: f32) -> bool {
    motor.model == MotorModel::ForceBased
        && motor.target_pos == TARGET_POSITION_RAD
        && motor.target_vel == target_velocity_rad_s
        && motor.stiffness == POSITION_STIFFNESS_NM_PER_RAD
        && motor.damping == MOTOR_DAMPING_NM_S_PER_RAD
        && motor.max_force == MAXIMUM_MOTOR_FORCE_NM
}

fn response_metrics(
    spec: CellSpec,
    velocity_rad_s: f32,
    motor_impulse_nms: f32,
) -> (f32, Option<f32>, bool, bool, bool) {
    let target_sign_passed = same_nonzero_sign(spec.target_velocity_rad_s, velocity_rad_s);
    if spec.kind == CellKind::UnloadedVelocity {
        let velocity_response = velocity_rad_s.abs() / spec.target_velocity_rad_s.abs();
        let velocity_passed = (RESPONSE_MINIMUM..=RESPONSE_MAXIMUM).contains(&velocity_response);
        return (
            velocity_response,
            None,
            target_sign_passed,
            true,
            velocity_passed && target_sign_passed,
        );
    }

    let expected_offset = spec.external_torque_nm / MOTOR_DAMPING_NM_S_PER_RAD;
    let velocity_response = (velocity_rad_s - spec.target_velocity_rad_s) / expected_offset;
    let expected_impulse = expected_terminal_motor_impulse_nms(spec);
    let impulse_response = motor_impulse_nms / expected_impulse;
    let load_sign_passed = same_nonzero_sign(
        velocity_rad_s - spec.target_velocity_rad_s,
        spec.external_torque_nm,
    ) && same_nonzero_sign(motor_impulse_nms, spec.external_torque_nm);
    let velocity_passed = (RESPONSE_MINIMUM..=RESPONSE_MAXIMUM).contains(&velocity_response);
    let impulse_passed = (RESPONSE_MINIMUM..=RESPONSE_MAXIMUM).contains(&impulse_response);
    (
        velocity_response,
        Some(impulse_response),
        target_sign_passed,
        load_sign_passed,
        velocity_passed && impulse_passed && target_sign_passed && load_sign_passed,
    )
}

fn sample_acceptable(
    spec: CellSpec,
    motor: &JointMotor,
    velocity_rad_s: f32,
    anchor_error_m: f32,
) -> bool {
    let (_, _, _, _, response_passed) = response_metrics(spec, velocity_rad_s, motor.impulse);
    motor_fields_match(motor, spec.target_velocity_rad_s)
        && velocity_rad_s.is_finite()
        && motor.impulse.is_finite()
        && anchor_error_m.is_finite()
        && anchor_error_m <= MAXIMUM_ANCHOR_ERROR_M
        && motor.impulse.abs() <= small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS
        && response_passed
}

fn preregistration() -> Result<Value, String> {
    check(
        raw_sha256(PREREGISTRATION_RAW) == PREREGISTRATION_RAW_SHA256,
        "C6_RAP_HC_VH1_PREREGISTRATION_HASH",
    )?;
    check(
        raw_sha256(CANONICAL_PROFILE_RAW) == CANONICAL_PROFILE_RAW_SHA256,
        "C6_RAP_HC_VH1_CANONICAL_PROFILE_HASH",
    )?;
    check(
        raw_sha256(SPV1_CLOSURE_RAW) == SPV1_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_VH1_SPV1_CLOSURE_HASH",
    )?;
    check(
        raw_sha256(CARGO_LOCK_RAW) == CARGO_LOCK_RAW_SHA256,
        "C6_RAP_HC_VH1_CARGO_LOCK_HASH",
    )?;
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_HC_VH1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        declaration["schema_version"]
            == "sporespore_rapier_c6_force_based_velocity_only_host_characterization_preregistration_v1"
            && declaration["campaign_id"] == CAMPAIGN_ID
            && declaration["gate_id"] == GATE_ID
            && declaration["status"] == "frozen_before_first_c6_rap_hc_vh1_physics_world"
            && declaration["implementation_parent_commit"]
                == "0e77c47377fa721f99c4b5e1d484b6edd6ab8025"
            && declaration["study_class"]
                == "exact_finite_cell_velocity_only_host_characterization"
            && declaration["semantic_predecessor"]["profile_id"] == CANONICAL_PROFILE_ID
            && declaration["semantic_predecessor"]["profile_raw_sha256"]
                == CANONICAL_PROFILE_RAW_SHA256[7..]
            && declaration["semantic_predecessor"]["rapier_profile_id"] == RAPIER_PROFILE_ID
            && declaration["semantic_predecessor"]["position_target_role"]
                == "provenance_and_bounds_only"
            && declaration["semantic_predecessor"]["native_position_stiffness_required"] == 0.0
            && declaration["validated_host_predecessor"]["closure_raw_sha256"]
                == SPV1_CLOSURE_RAW_SHA256[7..]
            && declaration["host_source_semantics"]["host_version"] == rapier3d::VERSION
            && declaration["host_source_semantics"]["cargo_lock_raw_sha256"]
                == CARGO_LOCK_RAW_SHA256[7..]
            && declaration["pinned_host_configuration"]["solver_iterations"]
                == RAPIER_ACTIVE_SOLVER_ITERATIONS
            && declaration["pinned_host_configuration"]["num_internal_pgs_iterations"]
                == RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
            && declaration["pinned_host_configuration"]["num_internal_stabilization_iterations"]
                == RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS
            && declaration["pinned_host_configuration"]["position_stiffness_nm_per_rad"] == 0.0
            && declaration["pinned_host_configuration"]["damping_nm_s_per_rad"]
                == MOTOR_DAMPING_NM_S_PER_RAD
            && declaration["pinned_host_configuration"]["maximum_motor_force_nm"]
                == MAXIMUM_MOTOR_FORCE_NM
            && declaration["physical_grid"]["expected_world_count"] == EXPECTED_WORLD_COUNT
            && declaration["preflight_contract"]["must_run_before_any_physics_world"] == true
            && declaration["preflight_contract"]["perfect_synthetic_twelve_cell_result_must_pass_the_complete_real_gate"]
                == true
            && declaration["preflight_contract"]["world_build_count"] == 0
            && declaration["preflight_contract"]["physical_acceptance_authority"] == false,
        "C6_RAP_HC_VH1_PREREGISTRATION_IDENTITY",
    )?;
    Ok(declaration)
}

fn evaluate_cell(observation: &CellObservation) -> Value {
    let spec = observation.spec;
    let expected_velocity = expected_terminal_velocity(spec);
    let expected_impulse = expected_terminal_motor_impulse_nms(spec);
    let (
        velocity_response,
        impulse_response,
        target_sign_passed,
        load_sign_passed,
        response_passed,
    ) = response_metrics(
        spec,
        observation.terminal_velocity_rad_s,
        observation.terminal_motor_impulse_nms,
    );
    let readback_passed = observation.motor_model == MotorModel::ForceBased
        && observation.readback_target_position_rad == TARGET_POSITION_RAD
        && observation.readback_target_velocity_rad_s == spec.target_velocity_rad_s
        && observation.readback_stiffness_nm_per_rad == POSITION_STIFFNESS_NM_PER_RAD
        && observation.readback_damping_nm_s_per_rad == MOTOR_DAMPING_NM_S_PER_RAD
        && observation.readback_maximum_force_nm == MAXIMUM_MOTOR_FORCE_NM
        && observation.motor_update_readback_count == OBSERVATION_OUTER_STEPS as u64
        && observation.motor_model_mismatch_count == 0
        && observation.motor_field_mismatch_count == 0;
    let finite_passed = observation.nonfinite_value_count == 0
        && expected_velocity.is_finite()
        && expected_impulse.is_finite()
        && velocity_response.is_finite()
        && impulse_response.is_none_or(f32::is_finite);
    let convergence_passed =
        observation.longest_consecutive_acceptable_steps >= REQUIRED_CONSECUTIVE_ACCEPTABLE_STEPS;
    let anchor_passed = observation.final_anchor_error_m <= MAXIMUM_ANCHOR_ERROR_M;
    let force_limit_passed = observation.step_impulse_limit_violation_count == 0
        && observation.maximum_observed_motor_impulse_nms
            <= small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS;
    let passed = readback_passed
        && finite_passed
        && response_passed
        && convergence_passed
        && anchor_passed
        && force_limit_passed
        && observation.world_attempt_count == 1
        && observation.world_build_count == 1;

    json!({
        "schema_version":
            "sporespore_rapier_force_based_velocity_only_characterization_cell_v1",
        "cell_kind": spec.kind.name(),
        "cell_id": cell_id(spec),
        "ok": passed,
        "target_position_rad": TARGET_POSITION_RAD,
        "target_velocity_rad_s": spec.target_velocity_rad_s,
        "external_torque_nm": spec.external_torque_nm,
        "expected_terminal_velocity_rad_s": expected_velocity,
        "position_stiffness_nm_per_rad": POSITION_STIFFNESS_NM_PER_RAD,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "outer_timestep_s": RAPIER_DT_S,
        "small_step_timestep_s": small_step_timestep_s(),
        "small_step_impulse_limit_nms": small_step_impulse_limit_nms(),
        "expected_terminal_motor_impulse_nms": expected_impulse,
        "motor_model_readback": motor_model_name(observation.motor_model),
        "readback_target_position_rad": observation.readback_target_position_rad,
        "readback_target_velocity_rad_s": observation.readback_target_velocity_rad_s,
        "readback_stiffness_nm_per_rad": observation.readback_stiffness_nm_per_rad,
        "readback_damping_nm_s_per_rad": observation.readback_damping_nm_s_per_rad,
        "readback_maximum_force_nm": observation.readback_maximum_force_nm,
        "motor_update_readback_count": observation.motor_update_readback_count,
        "motor_model_mismatch_count": observation.motor_model_mismatch_count,
        "motor_field_mismatch_count": observation.motor_field_mismatch_count,
        "terminal_velocity_rad_s": observation.terminal_velocity_rad_s,
        "terminal_motor_impulse_nms": observation.terminal_motor_impulse_nms,
        "maximum_observed_motor_impulse_nms":
            observation.maximum_observed_motor_impulse_nms,
        "normalized_velocity_response": velocity_response,
        "normalized_motor_impulse_response": impulse_response,
        "target_and_terminal_velocity_signs_passed": target_sign_passed,
        "load_velocity_offset_and_impulse_signs_passed": load_sign_passed,
        "response_passed": response_passed,
        "minimum_acceptance_outer_step": MINIMUM_ACCEPTANCE_OUTER_STEP,
        "required_consecutive_acceptable_outer_steps":
            REQUIRED_CONSECUTIVE_ACCEPTABLE_STEPS,
        "observation_outer_steps": OBSERVATION_OUTER_STEPS,
        "longest_consecutive_acceptable_outer_steps":
            observation.longest_consecutive_acceptable_steps,
        "convergence_passed": convergence_passed,
        "final_anchor_error_m": observation.final_anchor_error_m,
        "anchor_passed": anchor_passed,
        "step_impulse_limit_violation_count":
            observation.step_impulse_limit_violation_count,
        "force_limit_passed": force_limit_passed,
        "nonfinite_value_count": observation.nonfinite_value_count,
        "readback_passed": readback_passed,
        "finite_passed": finite_passed,
        "world_attempt_count": observation.world_attempt_count,
        "world_build_count": observation.world_build_count,
        "physical_acceptance_authority": false,
    })
}

fn pair_cell(cells: &[Value], target: f32, load: f32) -> Option<&Value> {
    cells.iter().find(|cell| {
        cell["target_velocity_rad_s"].as_f64() == Some(target as f64)
            && cell["external_torque_nm"].as_f64() == Some(load as f64)
    })
}

fn aggregate_cells(cells: &[Value]) -> Value {
    let expected_ids: Vec<String> = declared_specs().into_iter().map(cell_id).collect();
    let observed_ids: Vec<&str> = cells
        .iter()
        .filter_map(|cell| cell["cell_id"].as_str())
        .collect();
    let ordered_cell_identity_passed = observed_ids.len() == expected_ids.len()
        && observed_ids
            .iter()
            .zip(&expected_ids)
            .all(|(observed, expected)| *observed == expected);
    let cell_count = cells.len() as u64;
    let passed_cell_count = cells.iter().filter(|cell| cell["ok"] == true).count() as u64;
    let failed_cell_count = cell_count - passed_cell_count;
    let world_attempt_count = cells
        .iter()
        .filter_map(|cell| cell["world_attempt_count"].as_u64())
        .sum::<u64>();
    let world_build_count = cells
        .iter()
        .filter_map(|cell| cell["world_build_count"].as_u64())
        .sum::<u64>();
    let motor_model_readback_count = cells
        .iter()
        .filter(|cell| cell["motor_model_readback"] == "ForceBased")
        .count() as u64;
    let motor_model_mismatch_count = cells
        .iter()
        .filter_map(|cell| cell["motor_model_mismatch_count"].as_u64())
        .sum::<u64>();
    let motor_field_mismatch_count = cells
        .iter()
        .filter_map(|cell| cell["motor_field_mismatch_count"].as_u64())
        .sum::<u64>();
    let nonfinite_value_count = cells
        .iter()
        .filter_map(|cell| cell["nonfinite_value_count"].as_u64())
        .sum::<u64>();
    let step_impulse_limit_violation_count = cells
        .iter()
        .filter_map(|cell| cell["step_impulse_limit_violation_count"].as_u64())
        .sum::<u64>();
    let unloaded_cells: Vec<&Value> = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == CellKind::UnloadedVelocity.name())
        .collect();
    let loaded_cells: Vec<&Value> = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == CellKind::ConstantTorqueLoadedVelocity.name())
        .collect();
    let unloaded_velocity_grid_passed =
        unloaded_cells.len() == 4 && unloaded_cells.iter().all(|cell| cell["ok"] == true);
    let loaded_affine_response_grid_passed =
        loaded_cells.len() == 8 && loaded_cells.iter().all(|cell| cell["ok"] == true);

    let mut maximum_pair_asymmetry = 0.0_f64;
    let mut pair_count = 0_u64;
    let mut pair_inputs_complete = true;
    for magnitude in [0.75_f32, 2.25] {
        let negative = pair_cell(cells, -magnitude, 0.0);
        let positive = pair_cell(cells, magnitude, 0.0);
        if let (Some(negative), Some(positive)) = (negative, positive) {
            maximum_pair_asymmetry = maximum_pair_asymmetry.max(relative_difference(
                negative["normalized_velocity_response"]
                    .as_f64()
                    .unwrap_or(f64::INFINITY),
                positive["normalized_velocity_response"]
                    .as_f64()
                    .unwrap_or(f64::INFINITY),
            ));
            pair_count += 1;
        } else {
            pair_inputs_complete = false;
        }
    }
    for target in LOADED_TARGET_VELOCITIES_RAD_S {
        for magnitude in [0.75_f32, 2.25] {
            let negative = pair_cell(cells, target, -magnitude);
            let positive = pair_cell(cells, target, magnitude);
            if let (Some(negative), Some(positive)) = (negative, positive) {
                for field in [
                    "normalized_velocity_response",
                    "normalized_motor_impulse_response",
                ] {
                    maximum_pair_asymmetry = maximum_pair_asymmetry.max(relative_difference(
                        negative[field].as_f64().unwrap_or(f64::INFINITY),
                        positive[field].as_f64().unwrap_or(f64::INFINITY),
                    ));
                }
                pair_count += 1;
            } else {
                pair_inputs_complete = false;
            }
        }
    }
    let signed_pair_symmetry_passed = pair_inputs_complete
        && pair_count == 6
        && maximum_pair_asymmetry <= MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY;
    let complete = ordered_cell_identity_passed
        && cell_count == EXPECTED_WORLD_COUNT
        && passed_cell_count == EXPECTED_WORLD_COUNT
        && failed_cell_count == 0
        && world_attempt_count == EXPECTED_WORLD_COUNT
        && world_build_count == EXPECTED_WORLD_COUNT
        && motor_model_readback_count == EXPECTED_WORLD_COUNT
        && motor_model_mismatch_count == 0
        && motor_field_mismatch_count == 0
        && nonfinite_value_count == 0
        && step_impulse_limit_violation_count == 0
        && unloaded_velocity_grid_passed
        && loaded_affine_response_grid_passed
        && signed_pair_symmetry_passed;

    json!({
        "cell_count": cell_count,
        "passed_cell_count": passed_cell_count,
        "failed_cell_count": failed_cell_count,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "motor_model_readback_count": motor_model_readback_count,
        "motor_model_mismatch_count": motor_model_mismatch_count,
        "motor_field_mismatch_count": motor_field_mismatch_count,
        "nonfinite_value_count": nonfinite_value_count,
        "step_impulse_limit_violation_count": step_impulse_limit_violation_count,
        "ordered_cell_identity_passed": ordered_cell_identity_passed,
        "unloaded_velocity_grid_passed": unloaded_velocity_grid_passed,
        "loaded_affine_response_grid_passed": loaded_affine_response_grid_passed,
        "signed_pair_count": pair_count,
        "maximum_signed_pair_relative_asymmetry": maximum_pair_asymmetry,
        "signed_pair_symmetry_passed": signed_pair_symmetry_passed,
        "complete_velocity_only_host_characterization_passed": complete,
    })
}

fn integrity_failures(aggregate: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    for (field, expected) in [
        ("cell_count", EXPECTED_WORLD_COUNT),
        ("passed_cell_count", EXPECTED_WORLD_COUNT),
        ("failed_cell_count", 0),
        ("world_attempt_count", EXPECTED_WORLD_COUNT),
        ("world_build_count", EXPECTED_WORLD_COUNT),
        ("motor_model_readback_count", EXPECTED_WORLD_COUNT),
        ("motor_model_mismatch_count", 0),
        ("motor_field_mismatch_count", 0),
        ("nonfinite_value_count", 0),
        ("step_impulse_limit_violation_count", 0),
    ] {
        if aggregate[field].as_u64() != Some(expected) {
            failures.push(format!("C6_RAP_HC_VH1_{}_INVALID", field.to_uppercase()));
        }
    }
    for field in [
        "ordered_cell_identity_passed",
        "unloaded_velocity_grid_passed",
        "loaded_affine_response_grid_passed",
        "signed_pair_symmetry_passed",
        "complete_velocity_only_host_characterization_passed",
    ] {
        if aggregate[field] != true {
            failures.push(format!("C6_RAP_HC_VH1_{}_INVALID", field.to_uppercase()));
        }
    }
    failures
}

fn perfect_synthetic_observations() -> Vec<CellObservation> {
    declared_specs()
        .into_iter()
        .map(|spec| CellObservation {
            spec,
            motor_model: MotorModel::ForceBased,
            readback_target_position_rad: TARGET_POSITION_RAD,
            readback_target_velocity_rad_s: spec.target_velocity_rad_s,
            readback_stiffness_nm_per_rad: POSITION_STIFFNESS_NM_PER_RAD,
            readback_damping_nm_s_per_rad: MOTOR_DAMPING_NM_S_PER_RAD,
            readback_maximum_force_nm: MAXIMUM_MOTOR_FORCE_NM,
            terminal_velocity_rad_s: expected_terminal_velocity(spec),
            terminal_motor_impulse_nms: expected_terminal_motor_impulse_nms(spec),
            maximum_observed_motor_impulse_nms: expected_terminal_motor_impulse_nms(spec).abs(),
            final_anchor_error_m: 0.0,
            longest_consecutive_acceptable_steps: REQUIRED_CONSECUTIVE_ACCEPTABLE_STEPS,
            motor_update_readback_count: OBSERVATION_OUTER_STEPS as u64,
            motor_model_mismatch_count: 0,
            motor_field_mismatch_count: 0,
            step_impulse_limit_violation_count: 0,
            nonfinite_value_count: 0,
            world_attempt_count: 1,
            world_build_count: 1,
        })
        .collect()
}

fn evaluate_observations(observations: &[CellObservation]) -> (Vec<Value>, Value, Vec<String>) {
    let cells: Vec<Value> = observations.iter().map(evaluate_cell).collect();
    let aggregate = aggregate_cells(&cells);
    let failures = integrity_failures(&aggregate);
    (cells, aggregate, failures)
}

fn preflight_boundary_valid(
    world_build_count: u64,
    scene_insertion_count: u64,
    physics_state_modified: bool,
    physical_acceptance_authority: bool,
) -> bool {
    world_build_count == 0
        && scene_insertion_count == 0
        && !physics_state_modified
        && !physical_acceptance_authority
}

pub fn run_force_based_velocity_only_characterization_preflight() -> Result<Value, String> {
    let declaration = preregistration()?;

    let mut default_canary = RevoluteJoint::new(Vector::X);
    default_canary
        .set_motor_velocity(0.75, MOTOR_DAMPING_NM_S_PER_RAD)
        .set_motor_max_force(MAXIMUM_MOTOR_FORCE_NM);
    let default_motor = *default_canary
        .motor()
        .ok_or_else(|| "C6_RAP_HC_VH1_DEFAULT_CANARY_MOTOR_MISSING".to_owned())?;

    let explicit_builder = RevoluteJointBuilder::new(Vector::X)
        .motor_velocity(0.75, MOTOR_DAMPING_NM_S_PER_RAD)
        .motor_model(MotorModel::ForceBased)
        .motor_max_force(MAXIMUM_MOTOR_FORCE_NM)
        .build();
    let explicit_builder_motor = *explicit_builder
        .motor()
        .ok_or_else(|| "C6_RAP_HC_VH1_BUILDER_MOTOR_MISSING".to_owned())?;

    let mut mutable = explicit_builder;
    mutable
        .set_motor_velocity(-1.5, MOTOR_DAMPING_NM_S_PER_RAD)
        .set_motor_model(MotorModel::ForceBased)
        .set_motor_max_force(MAXIMUM_MOTOR_FORCE_NM);
    let mutable_motor = *mutable
        .motor()
        .ok_or_else(|| "C6_RAP_HC_VH1_MUTABLE_MOTOR_MISSING".to_owned())?;

    let default_canary_passed =
        default_motor.model == MotorModel::AccelerationBased && default_motor.stiffness == 0.0;
    let explicit_builder_passed = motor_fields_match(&explicit_builder_motor, 0.75);
    let mutable_update_passed = motor_fields_match(&mutable_motor, -1.5);

    let perfect_observations = perfect_synthetic_observations();
    let (perfect_cells, perfect_aggregate, perfect_failures) =
        evaluate_observations(&perfect_observations);
    let serialized = serde_json::to_string(&perfect_cells)
        .map_err(|error| format!("C6_RAP_HC_VH1_SYNTHETIC_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_HC_VH1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let serialization_round_trip_passed = round_trip == Value::Array(perfect_cells.clone());
    let perfect_passed = perfect_failures.is_empty()
        && serialization_round_trip_passed
        && perfect_aggregate["complete_velocity_only_host_characterization_passed"] == true;

    let mut missing = perfect_observations.clone();
    missing.pop();
    let (_, _, missing_failures) = evaluate_observations(&missing);

    let mut wrong_model = perfect_observations.clone();
    wrong_model[0].motor_model = MotorModel::AccelerationBased;
    wrong_model[0].motor_model_mismatch_count = 1;
    let (_, _, wrong_model_failures) = evaluate_observations(&wrong_model);

    let mut nonzero_stiffness = perfect_observations.clone();
    nonzero_stiffness[0].readback_stiffness_nm_per_rad = 40.0;
    nonzero_stiffness[0].motor_field_mismatch_count = 1;
    let (_, _, nonzero_stiffness_failures) = evaluate_observations(&nonzero_stiffness);

    let mut wrong_target = perfect_observations.clone();
    wrong_target[0].readback_target_velocity_rad_s *= -1.0;
    wrong_target[0].motor_field_mismatch_count = 1;
    let (_, _, wrong_target_failures) = evaluate_observations(&wrong_target);

    let mut wrong_velocity = perfect_observations.clone();
    wrong_velocity[4].terminal_velocity_rad_s = wrong_velocity[4].spec.target_velocity_rad_s;
    wrong_velocity[4].longest_consecutive_acceptable_steps = 0;
    let (_, _, wrong_velocity_failures) = evaluate_observations(&wrong_velocity);

    let mut wrong_impulse = perfect_observations.clone();
    wrong_impulse[5].terminal_motor_impulse_nms = 0.0;
    wrong_impulse[5].longest_consecutive_acceptable_steps = 0;
    let (_, _, wrong_impulse_failures) = evaluate_observations(&wrong_impulse);

    let mut wrong_sign = perfect_observations.clone();
    wrong_sign[6].terminal_motor_impulse_nms *= -1.0;
    wrong_sign[6].longest_consecutive_acceptable_steps = 0;
    let (_, _, wrong_sign_failures) = evaluate_observations(&wrong_sign);

    let mut whole_step_impulse = perfect_observations.clone();
    whole_step_impulse[7].terminal_motor_impulse_nms *= RAPIER_ACTIVE_SOLVER_ITERATIONS as f32;
    whole_step_impulse[7].maximum_observed_motor_impulse_nms =
        whole_step_impulse[7].terminal_motor_impulse_nms.abs();
    whole_step_impulse[7].step_impulse_limit_violation_count = 1;
    whole_step_impulse[7].longest_consecutive_acceptable_steps = 0;
    let (_, _, whole_step_impulse_failures) = evaluate_observations(&whole_step_impulse);

    let missing_cell_canary_rejected = !missing_failures.is_empty();
    let wrong_model_canary_rejected = !wrong_model_failures.is_empty();
    let nonzero_stiffness_canary_rejected = !nonzero_stiffness_failures.is_empty();
    let wrong_target_canary_rejected = !wrong_target_failures.is_empty();
    let wrong_velocity_canary_rejected = !wrong_velocity_failures.is_empty();
    let wrong_impulse_canary_rejected = !wrong_impulse_failures.is_empty();
    let wrong_sign_canary_rejected = !wrong_sign_failures.is_empty();
    let whole_step_impulse_canary_rejected = !whole_step_impulse_failures.is_empty();
    let boundary_inflation_canary_rejected = !preflight_boundary_valid(1, 1, true, true);
    let actual_preflight_boundary_passed = preflight_boundary_valid(0, 0, false, false);

    let ok = default_canary_passed
        && explicit_builder_passed
        && mutable_update_passed
        && perfect_passed
        && missing_cell_canary_rejected
        && wrong_model_canary_rejected
        && nonzero_stiffness_canary_rejected
        && wrong_target_canary_rejected
        && wrong_velocity_canary_rejected
        && wrong_impulse_canary_rejected
        && wrong_sign_canary_rejected
        && whole_step_impulse_canary_rejected
        && boundary_inflation_canary_rejected
        && actual_preflight_boundary_passed;

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_velocity_only_host_characterization_preflight_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "rapier_version": rapier3d::VERSION,
        "canonical_profile_id": CANONICAL_PROFILE_ID,
        "rapier_host_profile_id": RAPIER_PROFILE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "spv1_closure_raw_sha256": SPV1_CLOSURE_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "default_model_canary": {
            "expected": "AccelerationBased",
            "observed": motor_model_name(default_motor.model),
            "stiffness": default_motor.stiffness,
            "passed": default_canary_passed,
        },
        "explicit_builder_readback": {
            "model": motor_model_name(explicit_builder_motor.model),
            "target_position_rad": explicit_builder_motor.target_pos,
            "target_velocity_rad_s": explicit_builder_motor.target_vel,
            "stiffness_nm_per_rad": explicit_builder_motor.stiffness,
            "damping_nm_s_per_rad": explicit_builder_motor.damping,
            "maximum_force_nm": explicit_builder_motor.max_force,
            "passed": explicit_builder_passed,
        },
        "mutable_update_readback": {
            "model": motor_model_name(mutable_motor.model),
            "target_position_rad": mutable_motor.target_pos,
            "target_velocity_rad_s": mutable_motor.target_vel,
            "stiffness_nm_per_rad": mutable_motor.stiffness,
            "damping_nm_s_per_rad": mutable_motor.damping,
            "maximum_force_nm": mutable_motor.max_force,
            "passed": mutable_update_passed,
        },
        "perfect_synthetic_twelve_cell_result_passed_complete_gate": perfect_passed,
        "perfect_synthetic_serialization_round_trip_passed":
            serialization_round_trip_passed,
        "perfect_synthetic_aggregate": perfect_aggregate,
        "perfect_synthetic_failure_codes": perfect_failures,
        "missing_cell_canary_rejected": missing_cell_canary_rejected,
        "missing_cell_canary_failure_codes": missing_failures,
        "wrong_model_canary_rejected": wrong_model_canary_rejected,
        "wrong_model_canary_failure_codes": wrong_model_failures,
        "nonzero_stiffness_canary_rejected": nonzero_stiffness_canary_rejected,
        "nonzero_stiffness_canary_failure_codes": nonzero_stiffness_failures,
        "wrong_target_velocity_readback_canary_rejected": wrong_target_canary_rejected,
        "wrong_target_velocity_readback_canary_failure_codes": wrong_target_failures,
        "wrong_velocity_response_canary_rejected": wrong_velocity_canary_rejected,
        "wrong_velocity_response_canary_failure_codes": wrong_velocity_failures,
        "wrong_impulse_response_canary_rejected": wrong_impulse_canary_rejected,
        "wrong_impulse_response_canary_failure_codes": wrong_impulse_failures,
        "wrong_signed_response_canary_rejected": wrong_sign_canary_rejected,
        "wrong_signed_response_canary_failure_codes": wrong_sign_failures,
        "whole_outer_step_impulse_canary_rejected": whole_step_impulse_canary_rejected,
        "whole_outer_step_impulse_canary_failure_codes": whole_step_impulse_failures,
        "world_count_and_physical_authority_inflation_canary_rejected":
            boundary_inflation_canary_rejected,
        "declaration_claims": declaration["claims"].clone(),
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    }))
}

fn physical_observation(spec: CellSpec) -> Result<CellObservation, String> {
    check(
        declared_specs().iter().any(|declared| {
            declared.kind == spec.kind
                && declared.target_velocity_rad_s == spec.target_velocity_rad_s
                && declared.external_torque_nm == spec.external_torque_nm
        }),
        "C6_RAP_HC_VH1_UNDECLARED_CELL",
    )?;
    let mut world = new_active_world(Vector::ZERO);
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _) = world.insert(
        RigidBodyBuilder::dynamic().can_sleep(false),
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
            .motor_velocity(0.0, MOTOR_DAMPING_NM_S_PER_RAD)
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(MAXIMUM_MOTOR_FORCE_NM),
    );

    let mut current_streak = 0_usize;
    let mut longest_streak = 0_usize;
    let mut model_mismatches = 0_u64;
    let mut field_mismatches = 0_u64;
    let mut update_readbacks = 0_u64;
    let mut impulse_limit_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_impulse = 0.0_f32;

    for step in 0..OBSERVATION_OUTER_STEPS {
        {
            let revolute = world
                .impulse_joints
                .get_mut(joint, true)
                .ok_or_else(|| "C6_RAP_HC_VH1_MUTABLE_JOINT_MISSING".to_owned())?
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_HC_VH1_MUTABLE_REVOLUTE_MISSING".to_owned())?;
            revolute
                .set_motor_velocity(spec.target_velocity_rad_s, MOTOR_DAMPING_NM_S_PER_RAD)
                .set_motor_model(MotorModel::ForceBased)
                .set_motor_max_force(MAXIMUM_MOTOR_FORCE_NM);
            let motor = revolute
                .motor()
                .ok_or_else(|| "C6_RAP_HC_VH1_MUTABLE_MOTOR_MISSING".to_owned())?;
            update_readbacks += 1;
            model_mismatches += u64::from(motor.model != MotorModel::ForceBased);
            field_mismatches += u64::from(!motor_fields_match(motor, spec.target_velocity_rad_s));
        }
        {
            let body = world
                .bodies
                .get_mut(child)
                .ok_or_else(|| "C6_RAP_HC_VH1_CHILD_BODY_MISSING".to_owned())?;
            body.reset_torques(false);
            if spec.external_torque_nm != 0.0 {
                body.add_torque(Vector::X * spec.external_torque_nm, true);
            }
        }
        world.step();

        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "C6_RAP_HC_VH1_POST_STEP_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "C6_RAP_HC_VH1_POST_STEP_REVOLUTE_MISSING".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "C6_RAP_HC_VH1_POST_STEP_MOTOR_MISSING".to_owned())?;
        let velocity = world.bodies[child]
            .angvel()
            .dot(world.bodies[parent].rotation() * Vector::X);
        let parent_anchor = world.bodies[parent]
            .position()
            .transform_point(revolute.local_anchor1());
        let child_anchor = world.bodies[child]
            .position()
            .transform_point(revolute.local_anchor2());
        let anchor_error = (parent_anchor - child_anchor).length();
        model_mismatches += u64::from(motor.model != MotorModel::ForceBased);
        field_mismatches += u64::from(!motor_fields_match(motor, spec.target_velocity_rad_s));
        nonfinite_values += u64::from(
            !velocity.is_finite() || !motor.impulse.is_finite() || !anchor_error.is_finite(),
        );
        maximum_impulse = maximum_impulse.max(motor.impulse.abs());
        impulse_limit_violations += u64::from(
            motor.impulse.abs() > small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS,
        );
        if step + 1 >= MINIMUM_ACCEPTANCE_OUTER_STEP
            && sample_acceptable(spec, motor, velocity, anchor_error)
        {
            current_streak += 1;
            longest_streak = longest_streak.max(current_streak);
        } else {
            current_streak = 0;
        }
    }

    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "C6_RAP_HC_VH1_TERMINAL_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_VH1_TERMINAL_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_VH1_TERMINAL_MOTOR_MISSING".to_owned())?;
    let terminal_velocity = world.bodies[child]
        .angvel()
        .dot(world.bodies[parent].rotation() * Vector::X);
    let parent_anchor = world.bodies[parent]
        .position()
        .transform_point(revolute.local_anchor1());
    let child_anchor = world.bodies[child]
        .position()
        .transform_point(revolute.local_anchor2());
    let final_anchor_error = (parent_anchor - child_anchor).length();
    nonfinite_values += u64::from(
        !terminal_velocity.is_finite()
            || !motor.impulse.is_finite()
            || !maximum_impulse.is_finite()
            || !final_anchor_error.is_finite(),
    );

    Ok(CellObservation {
        spec,
        motor_model: motor.model,
        readback_target_position_rad: motor.target_pos,
        readback_target_velocity_rad_s: motor.target_vel,
        readback_stiffness_nm_per_rad: motor.stiffness,
        readback_damping_nm_s_per_rad: motor.damping,
        readback_maximum_force_nm: motor.max_force,
        terminal_velocity_rad_s: terminal_velocity,
        terminal_motor_impulse_nms: motor.impulse,
        maximum_observed_motor_impulse_nms: maximum_impulse,
        final_anchor_error_m: final_anchor_error,
        longest_consecutive_acceptable_steps: longest_streak,
        motor_update_readback_count: update_readbacks,
        motor_model_mismatch_count: model_mismatches,
        motor_field_mismatch_count: field_mismatches,
        step_impulse_limit_violation_count: impulse_limit_violations,
        nonfinite_value_count: nonfinite_values,
        world_attempt_count: 1,
        world_build_count: 1,
    })
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

fn retained_physical_cell(spec: CellSpec) -> Value {
    match catch_unwind(AssertUnwindSafe(|| physical_observation(spec))) {
        Ok(Ok(observation)) => evaluate_cell(&observation),
        Ok(Err(failure)) => failed_cell(spec, failure),
        Err(payload) => failed_cell(
            spec,
            format!("C6_RAP_HC_VH1_PANIC:{}", panic_failure(payload)),
        ),
    }
}

fn failed_cell(spec: CellSpec, failure: String) -> Value {
    json!({
        "schema_version":
            "sporespore_rapier_force_based_velocity_only_characterization_cell_v1",
        "cell_kind": spec.kind.name(),
        "cell_id": cell_id(spec),
        "ok": false,
        "target_velocity_rad_s": spec.target_velocity_rad_s,
        "external_torque_nm": spec.external_torque_nm,
        "failure_code": failure,
        "motor_model_readback": "missing",
        "motor_model_mismatch_count": 1,
        "motor_field_mismatch_count": 1,
        "nonfinite_value_count": 0,
        "step_impulse_limit_violation_count": 0,
        "world_attempt_count": 1,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

pub fn run_force_based_velocity_only_characterization(
    source_commit: &str,
) -> Result<Value, String> {
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "C6_RAP_HC_VH1_SOURCE_COMMIT_INVALID",
    )?;
    let declaration = preregistration()?;
    let preflight = run_force_based_velocity_only_characterization_preflight()?;
    check(
        preflight["ok"] == true
            && preflight["world_build_count"] == 0
            && preflight["physics_state_modified"] == false,
        "C6_RAP_HC_VH1_PREFLIGHT_FAILED",
    )?;

    let cells: Vec<Value> = declared_specs()
        .into_iter()
        .map(retained_physical_cell)
        .collect();
    let aggregate = aggregate_cells(&cells);
    let failure_codes = integrity_failures(&aggregate);
    let ok = failure_codes.is_empty();

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_velocity_only_host_characterization_report_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "exact_finite_cell_velocity_only_host_characterization",
        "source": {
            "commit": source_commit,
            "remote": "origin/main",
            "origin_main_commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "preregistration": {
            "path":
                "sdk/rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json",
            "raw_sha256": PREREGISTRATION_RAW_SHA256,
            "status": declaration["status"].clone(),
            "implementation_parent_commit": declaration["implementation_parent_commit"].clone(),
        },
        "canonical_profile_id": CANONICAL_PROFILE_ID,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "rapier_host_profile_id": RAPIER_PROFILE_ID,
        "spv1_closure_raw_sha256": SPV1_CLOSURE_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "host_source_semantics": declaration["host_source_semantics"].clone(),
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "motor_model": "ForceBased",
        "actuation_mode": "velocity_only",
        "position_target_role": "provenance_and_bounds_only",
        "native_position_stiffness_nm_per_rad": POSITION_STIFFNESS_NM_PER_RAD,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "outer_timestep_s": RAPIER_DT_S,
        "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
        "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
        "internal_stabilization_iterations":
            RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
        "unloaded_target_velocities_rad_s": UNLOADED_TARGET_VELOCITIES_RAD_S,
        "loaded_target_velocities_rad_s": LOADED_TARGET_VELOCITIES_RAD_S,
        "signed_external_torques_nm": SIGNED_EXTERNAL_TORQUES_NM,
        "preflight": preflight,
        "cells": cells,
        "aggregate": aggregate,
        "failure_codes": failure_codes,
        "rapier_force_based_velocity_only_host_characterization": ok,
        "rapier_v4_live_adapter_integration": false,
        "rapier_selected_policy_physical_authority": false,
        "rapier_locomotion_acceptance": false,
        "cross_engine_selected_policy_equivalence": false,
        "different_physics_engines": false,
        "arbitrary_quadruped_coverage": false,
        "continuous_full_volume_coverage": false,
        "friction_or_material_robustness": false,
        "walking_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn velocity_only_characterization_preflight_is_complete_zero_world_and_fail_closed() {
        let report = run_force_based_velocity_only_characterization_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["perfect_synthetic_twelve_cell_result_passed_complete_gate"],
            true
        );
        assert_eq!(report["perfect_synthetic_aggregate"]["cell_count"], 12);
        assert_eq!(
            report["perfect_synthetic_aggregate"]["complete_velocity_only_host_characterization_passed"],
            true
        );
        for field in [
            "missing_cell_canary_rejected",
            "wrong_model_canary_rejected",
            "nonzero_stiffness_canary_rejected",
            "wrong_target_velocity_readback_canary_rejected",
            "wrong_velocity_response_canary_rejected",
            "wrong_impulse_response_canary_rejected",
            "wrong_signed_response_canary_rejected",
            "whole_outer_step_impulse_canary_rejected",
            "world_count_and_physical_authority_inflation_canary_rejected",
        ] {
            assert_eq!(report[field], true, "{field}");
        }
        assert_eq!(
            report["explicit_builder_readback"]["stiffness_nm_per_rad"],
            0.0
        );
        assert_eq!(
            report["mutable_update_readback"]["stiffness_nm_per_rad"],
            0.0
        );
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["scene_insertion_count"], 0);
        assert_eq!(report["physics_state_modified"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
    }
}
