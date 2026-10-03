use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest_sha256};

const PREREGISTRATION_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_selected_configuration_validation_spv1_preregistration.json"
);
const SPD1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_force_based_solver_phase_development_spd1_closure.json");
const CARGO_LOCK_RAW: &str = include_str!("../../../Cargo.lock");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:9a4bbe4888efa6855e803d94b08c394667e617d4e71956e6d99e3fd9201c7172";
const SPD1_CLOSURE_RAW_SHA256: &str =
    "sha256:e39f8f2621cf55177342ea757dbd6b2262256393b3add65a8c62441cf5e36e52";
const CARGO_LOCK_RAW_SHA256: &str =
    "sha256:0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc";

const CAMPAIGN_ID: &str = "C6-RAPIER-FORCE-BASED-SELECTED-CONFIGURATION-VALIDATION";
const GATE_ID: &str = "C6-RAP-HC-SPV1";
const EXPECTED_WORLD_COUNT: u64 = 8;
const SOLVER_ITERATIONS: usize = 16;
const NUM_INTERNAL_PGS_ITERATIONS: usize = 3;
const NUM_INTERNAL_STABILIZATION_ITERATIONS: usize = 5;
const TOTAL_CONSTRAINT_PASSES: usize = 8;
const CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const CHILD_MASS_KG: f32 = 1.0;
const GRAVITY_M_S2: f32 = 9.8;
const POSITION_STIFFNESS_NM_PER_RAD: f32 = 40.0;
const MOTOR_DAMPING_NM_S_PER_RAD: f32 = 10.0;
const MAXIMUM_MOTOR_FORCE_NM: f32 = 6.0;
const POSITION_TARGETS_RAD: [f32; 2] = [-0.55, 0.55];
const POSITION_OBSERVATION_STEPS: usize = 240;
const MAXIMUM_RELATIVE_POSITION_ERROR: f32 = 0.01;
const MAXIMUM_POSITION_PAIR_ASYMMETRY: f32 = 0.005;
const VELOCITY_TARGETS_RAD_S: [f32; 2] = [-1.25, 1.25];
const VELOCITY_OBSERVATION_STEPS: usize = 120;
const VELOCITY_RESPONSE_MINIMUM: f32 = 0.98;
const VELOCITY_RESPONSE_MAXIMUM: f32 = 1.02;
const MAXIMUM_VELOCITY_PAIR_ASYMMETRY: f32 = 0.005;
const SIGNED_LEVER_ARMS_Z_M: [f32; 4] = [-0.10, 0.10, -0.50, 0.50];
const MAXIMUM_OBSERVATION_STEPS: usize = 1_440;
const MINIMUM_ACCEPTANCE_STEP: usize = 120;
const REQUIRED_CONSECUTIVE_STEPS: usize = 60;
const RESPONSE_MINIMUM: f32 = 0.98;
const RESPONSE_MAXIMUM: f32 = 1.02;
const MAXIMUM_STATIC_RESIDUAL: f32 = 0.01;
const MAXIMUM_DAMPING_LOAD_FRACTION: f32 = 0.005;
const MAXIMUM_FULL_PD_RESIDUAL: f32 = 0.005;
const MAXIMUM_ANCHOR_ERROR_M: f32 = 0.000_01;
const MAXIMUM_SIGNED_PAIR_RELATIVE_ASYMMETRY: f32 = 0.005;
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

fn approximately_eq(first: f64, second: f64) -> bool {
    (first - second).abs() <= 1.0e-6
}

fn preregistration() -> Result<Value, String> {
    check(
        raw_sha256(PREREGISTRATION_RAW) == PREREGISTRATION_RAW_SHA256,
        "C6_RAP_HC_SPV1_PREREGISTRATION_HASH",
    )?;
    check(
        raw_sha256(SPD1_CLOSURE_RAW) == SPD1_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_SPV1_SPD1_CLOSURE_HASH",
    )?;
    check(
        raw_sha256(CARGO_LOCK_RAW) == CARGO_LOCK_RAW_SHA256,
        "C6_RAP_HC_SPV1_CARGO_LOCK_HASH",
    )?;
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_HC_SPV1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        declaration["schema_version"]
            == "sporespore_rapier_c6_force_based_selected_configuration_validation_preregistration_v1"
            && declaration["campaign_id"] == CAMPAIGN_ID
            && declaration["gate_id"] == GATE_ID
            && declaration["status"] == "frozen_before_first_c6_rap_hc_spv1_physics_world"
            && declaration["study_class"] == "exact_finite_cell_independent_host_validation"
            && declaration["predecessor"]["selected_candidate_id"] == "SPD1-B"
            && declaration["predecessor"]["selected_num_internal_pgs_iterations"]
                == NUM_INTERNAL_PGS_ITERATIONS as u64
            && declaration["predecessor"]["selected_num_internal_stabilization_iterations"]
                == NUM_INTERNAL_STABILIZATION_ITERATIONS as u64
            && declaration["pinned_host_configuration"]["solver_iterations"]
                == SOLVER_ITERATIONS as u64
            && declaration["pinned_host_configuration"]["total_constraint_passes_per_small_step"]
                == TOTAL_CONSTRAINT_PASSES as u64
            && declaration["physical_grid"]["expected_world_count"] == EXPECTED_WORLD_COUNT
            && declaration["estimand"]["population_inference"] == false
            && declaration["estimand"]["development_selection"] == false
            && declaration["estimand"]["selector_present"] == false
            && declaration["preflight_contract"]["world_build_count"] == 0
            && declaration["preflight_contract"]["physics_state_modified"] == false,
        "C6_RAP_HC_SPV1_PREREGISTRATION_CONTRACT",
    )?;
    let declared_positions =
        declaration["physical_grid"]["unloaded_position_validation"]["target_positions_rad"]
            .as_array()
            .ok_or_else(|| "C6_RAP_HC_SPV1_POSITION_GRID_MISSING".to_owned())?;
    let declared_velocities =
        declaration["physical_grid"]["signed_velocity_validation"]["target_velocities_rad_s"]
            .as_array()
            .ok_or_else(|| "C6_RAP_HC_SPV1_VELOCITY_GRID_MISSING".to_owned())?;
    let declared_arms = declaration["physical_grid"]["gravity_loaded_convergence_validation"]
        ["signed_lever_arms_z_m"]
        .as_array()
        .ok_or_else(|| "C6_RAP_HC_SPV1_LOADED_GRID_MISSING".to_owned())?;
    check(
        declared_positions.len() == POSITION_TARGETS_RAD.len()
            && declared_positions
                .iter()
                .zip(POSITION_TARGETS_RAD)
                .all(|(declared, expected)| {
                    declared
                        .as_f64()
                        .is_some_and(|value| approximately_eq(value, expected as f64))
                })
            && declared_velocities.len() == VELOCITY_TARGETS_RAD_S.len()
            && declared_velocities.iter().zip(VELOCITY_TARGETS_RAD_S).all(
                |(declared, expected)| {
                    declared
                        .as_f64()
                        .is_some_and(|value| approximately_eq(value, expected as f64))
                },
            )
            && declared_arms.len() == SIGNED_LEVER_ARMS_Z_M.len()
            && declared_arms
                .iter()
                .zip(SIGNED_LEVER_ARMS_Z_M)
                .all(|(declared, expected)| {
                    declared
                        .as_f64()
                        .is_some_and(|value| approximately_eq(value, expected as f64))
                }),
        "C6_RAP_HC_SPV1_FRESH_GRID",
    )?;
    Ok(declaration)
}

fn configured_world(gravity: Vector) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = SOLVER_ITERATIONS;
    world.integration_parameters.num_internal_pgs_iterations = NUM_INTERNAL_PGS_ITERATIONS;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = NUM_INTERNAL_STABILIZATION_ITERATIONS;
    world
}

fn allocation_fields_valid(cell: &Value) -> bool {
    cell["solver_iterations"] == SOLVER_ITERATIONS as u64
        && cell["num_internal_pgs_iterations"] == NUM_INTERNAL_PGS_ITERATIONS as u64
        && cell["num_internal_stabilization_iterations"]
            == NUM_INTERNAL_STABILIZATION_ITERATIONS as u64
        && cell["total_constraint_passes_per_small_step"] == TOTAL_CONSTRAINT_PASSES as u64
        && cell["fixed_selected_allocation_readback_passed"] == true
}

fn small_step_impulse_limit_nms() -> f32 {
    MAXIMUM_MOTOR_FORCE_NM * RAPIER_DT_S / SOLVER_ITERATIONS as f32
}

fn shared_fixture(
    world: &mut PhysicsWorld,
    translation: Vector,
    target_position_rad: f32,
    target_velocity_rad_s: f32,
    stiffness_nm_per_rad: f32,
) -> (RigidBodyHandle, RigidBodyHandle, ImpulseJointHandle) {
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _) = world.insert(
        RigidBodyBuilder::dynamic()
            .translation(translation)
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
            .local_anchor2(-translation)
            .motor(
                target_position_rad,
                target_velocity_rad_s,
                stiffness_nm_per_rad,
                MOTOR_DAMPING_NM_S_PER_RAD,
            )
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(MAXIMUM_MOTOR_FORCE_NM),
    );
    (parent, child, joint)
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
        .ok_or_else(|| "C6_RAP_HC_SPV1_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_SPV1_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPV1_MOTOR_MISSING".to_owned())?;
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

fn position_cell_id(target_position_rad: f32) -> &'static str {
    if target_position_rad < 0.0 {
        "position_target_0.55_negative"
    } else {
        "position_target_0.55_positive"
    }
}

fn velocity_cell_id(target_velocity_rad_s: f32) -> &'static str {
    if target_velocity_rad_s < 0.0 {
        "velocity_target_1.25_negative"
    } else {
        "velocity_target_1.25_positive"
    }
}

fn loaded_cell_id(signed_lever_arm_z_m: f32) -> &'static str {
    match signed_lever_arm_z_m {
        value if approximately_eq(value as f64, -0.10) => "loaded_arm_0.10_negative",
        value if approximately_eq(value as f64, 0.10) => "loaded_arm_0.10_positive",
        value if approximately_eq(value as f64, -0.50) => "loaded_arm_0.50_negative",
        _ => "loaded_arm_0.50_positive",
    }
}

fn position_cell(target_position_rad: f32) -> Result<Value, String> {
    check(
        POSITION_TARGETS_RAD.contains(&target_position_rad),
        "C6_RAP_HC_SPV1_POSITION_TARGET",
    )?;
    let mut world = configured_world(Vector::ZERO);
    let (parent, child, joint) = shared_fixture(
        &mut world,
        Vector::ZERO,
        target_position_rad,
        0.0,
        POSITION_STIFFNESS_NM_PER_RAD,
    );
    let mut model_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_observed_impulse_nms = 0.0_f32;
    let mut terminal = current_step_observation(&world, parent, child, joint)?;
    for _ in 0..POSITION_OBSERVATION_STEPS {
        world.step();
        terminal = current_step_observation(&world, parent, child, joint)?;
        model_mismatches += u64::from(terminal.motor_model != MotorModel::ForceBased);
        impulse_violations += u64::from(
            terminal.motor_impulse_nms.abs()
                > small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS,
        );
        nonfinite_values += u64::from(
            !terminal.angle_rad.is_finite()
                || !terminal.angular_velocity_rad_s.is_finite()
                || !terminal.motor_impulse_nms.is_finite()
                || !terminal.anchor_error_m.is_finite(),
        );
        maximum_observed_impulse_nms =
            maximum_observed_impulse_nms.max(terminal.motor_impulse_nms.abs());
    }
    let final_error_rad = (terminal.angle_rad - target_position_rad).abs();
    let relative_error = final_error_rad / target_position_rad.abs();
    let sign_passed = same_nonzero_sign(target_position_rad, terminal.angle_rad);
    let finite_terminal_values = terminal.angle_rad.is_finite()
        && terminal.angular_velocity_rad_s.is_finite()
        && terminal.motor_impulse_nms.is_finite()
        && terminal.anchor_error_m.is_finite()
        && final_error_rad.is_finite()
        && relative_error.is_finite()
        && maximum_observed_impulse_nms.is_finite();
    let position_response_passed = relative_error <= MAXIMUM_RELATIVE_POSITION_ERROR && sign_passed;
    let force_limit_passed = impulse_violations == 0;
    let allocation_readback_passed = world.integration_parameters.num_solver_iterations
        == SOLVER_ITERATIONS
        && world.integration_parameters.num_internal_pgs_iterations == NUM_INTERNAL_PGS_ITERATIONS
        && world
            .integration_parameters
            .num_internal_stabilization_iterations
            == NUM_INTERNAL_STABILIZATION_ITERATIONS;
    let passed = allocation_readback_passed
        && terminal.motor_model == MotorModel::ForceBased
        && model_mismatches == 0
        && nonfinite_values == 0
        && force_limit_passed
        && finite_terminal_values
        && position_response_passed;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_position_validation_cell_v1",
        "cell_kind": "unloaded_position_validation",
        "cell_id": position_cell_id(target_position_rad),
        "ok": passed,
        "target_position_rad": target_position_rad,
        "target_velocity_rad_s": 0.0,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": allocation_readback_passed,
        "position_stiffness_nm_per_rad": POSITION_STIFFNESS_NM_PER_RAD,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "small_step_timestep_s": RAPIER_DT_S / SOLVER_ITERATIONS as f32,
        "small_step_impulse_limit_nms": small_step_impulse_limit_nms(),
        "motor_model_readback": motor_model_name(terminal.motor_model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_position_rad": terminal.angle_rad,
        "final_angular_velocity_rad_s": terminal.angular_velocity_rad_s,
        "final_absolute_position_error_rad": final_error_rad,
        "absolute_relative_position_error": relative_error,
        "maximum_absolute_relative_position_error":
            MAXIMUM_RELATIVE_POSITION_ERROR,
        "target_and_final_position_sign_match": sign_passed,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "step_impulse_limit_violation_count": impulse_violations,
        "force_limit_passed": force_limit_passed,
        "nonfinite_value_count": nonfinite_values,
        "finite_terminal_values": finite_terminal_values,
        "position_response_passed": position_response_passed,
        "observation_outer_steps": POSITION_OBSERVATION_STEPS,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "independent_validation_evidence": true,
        "validation_authority": passed,
        "physical_acceptance_authority": false,
    }))
}

fn velocity_cell(target_velocity_rad_s: f32) -> Result<Value, String> {
    check(
        VELOCITY_TARGETS_RAD_S.contains(&target_velocity_rad_s),
        "C6_RAP_HC_SPV1_VELOCITY_TARGET",
    )?;
    let mut world = configured_world(Vector::ZERO);
    let (parent, child, joint) =
        shared_fixture(&mut world, Vector::ZERO, 0.0, target_velocity_rad_s, 0.0);
    let mut model_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_observed_impulse_nms = 0.0_f32;
    let mut terminal = current_step_observation(&world, parent, child, joint)?;
    for _ in 0..VELOCITY_OBSERVATION_STEPS {
        world.step();
        terminal = current_step_observation(&world, parent, child, joint)?;
        model_mismatches += u64::from(terminal.motor_model != MotorModel::ForceBased);
        impulse_violations += u64::from(
            terminal.motor_impulse_nms.abs()
                > small_step_impulse_limit_nms() + STEP_IMPULSE_TOLERANCE_NMS,
        );
        nonfinite_values += u64::from(
            !terminal.angle_rad.is_finite()
                || !terminal.angular_velocity_rad_s.is_finite()
                || !terminal.motor_impulse_nms.is_finite()
                || !terminal.anchor_error_m.is_finite(),
        );
        maximum_observed_impulse_nms =
            maximum_observed_impulse_nms.max(terminal.motor_impulse_nms.abs());
    }
    let normalized_response = terminal.angular_velocity_rad_s.abs() / target_velocity_rad_s.abs();
    let signs_passed = same_nonzero_sign(target_velocity_rad_s, terminal.angle_rad)
        && same_nonzero_sign(target_velocity_rad_s, terminal.angular_velocity_rad_s);
    let finite_terminal_values = terminal.angle_rad.is_finite()
        && terminal.angular_velocity_rad_s.is_finite()
        && terminal.motor_impulse_nms.is_finite()
        && terminal.anchor_error_m.is_finite()
        && normalized_response.is_finite()
        && maximum_observed_impulse_nms.is_finite();
    let velocity_response_passed = (VELOCITY_RESPONSE_MINIMUM..=VELOCITY_RESPONSE_MAXIMUM)
        .contains(&normalized_response)
        && signs_passed;
    let force_limit_passed = impulse_violations == 0;
    let allocation_readback_passed = world.integration_parameters.num_solver_iterations
        == SOLVER_ITERATIONS
        && world.integration_parameters.num_internal_pgs_iterations == NUM_INTERNAL_PGS_ITERATIONS
        && world
            .integration_parameters
            .num_internal_stabilization_iterations
            == NUM_INTERNAL_STABILIZATION_ITERATIONS;
    let passed = allocation_readback_passed
        && terminal.motor_model == MotorModel::ForceBased
        && model_mismatches == 0
        && nonfinite_values == 0
        && force_limit_passed
        && finite_terminal_values
        && velocity_response_passed;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_velocity_validation_cell_v1",
        "cell_kind": "signed_velocity_validation",
        "cell_id": velocity_cell_id(target_velocity_rad_s),
        "ok": passed,
        "target_position_rad": 0.0,
        "target_velocity_rad_s": target_velocity_rad_s,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": allocation_readback_passed,
        "position_stiffness_nm_per_rad": 0.0,
        "damping_nm_s_per_rad": MOTOR_DAMPING_NM_S_PER_RAD,
        "maximum_motor_force_nm": MAXIMUM_MOTOR_FORCE_NM,
        "small_step_timestep_s": RAPIER_DT_S / SOLVER_ITERATIONS as f32,
        "small_step_impulse_limit_nms": small_step_impulse_limit_nms(),
        "motor_model_readback": motor_model_name(terminal.motor_model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_position_rad": terminal.angle_rad,
        "final_velocity_rad_s": terminal.angular_velocity_rad_s,
        "normalized_final_velocity_response": normalized_response,
        "normalized_final_velocity_response_minimum": VELOCITY_RESPONSE_MINIMUM,
        "normalized_final_velocity_response_maximum": VELOCITY_RESPONSE_MAXIMUM,
        "final_position_and_velocity_signs_match_target": signs_passed,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "step_impulse_limit_violation_count": impulse_violations,
        "force_limit_passed": force_limit_passed,
        "nonfinite_value_count": nonfinite_values,
        "finite_terminal_values": finite_terminal_values,
        "velocity_response_passed": velocity_response_passed,
        "observation_outer_steps": VELOCITY_OBSERVATION_STEPS,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "independent_validation_evidence": true,
        "validation_authority": passed,
        "physical_acceptance_authority": false,
    }))
}

fn gravity_torque_nm(signed_lever_arm_z_m: f32, angle_rad: f32) -> f32 {
    CHILD_MASS_KG * GRAVITY_M_S2 * signed_lever_arm_z_m.abs() * angle_rad.abs().cos()
}

fn expected_small_step_impulse_nms(signed_lever_arm_z_m: f32, angle_rad: f32) -> f32 {
    gravity_torque_nm(signed_lever_arm_z_m, angle_rad) * RAPIER_DT_S / SOLVER_ITERATIONS as f32
}

fn evaluate_loaded_step(signed_lever_arm_z_m: f32, observation: &StepObservation) -> StepMetrics {
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

fn summarize_loaded_trace(
    signed_lever_arm_z_m: f32,
    observations: &[StepObservation],
    world_attempt_count: u64,
    world_build_count: u64,
) -> Result<Value, String> {
    check(
        !observations.is_empty() && observations.len() <= MAXIMUM_OBSERVATION_STEPS,
        "C6_RAP_HC_SPV1_LOADED_TRACE_LENGTH",
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
    let mut terminal_metrics = evaluate_loaded_step(signed_lever_arm_z_m, &terminal);
    for (index, observation) in observations.iter().enumerate() {
        let step = index + 1;
        let metrics = evaluate_loaded_step(signed_lever_arm_z_m, observation);
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
    let passed = convergence_reached
        && model_mismatches == 0
        && impulse_limit_violations == 0
        && nonfinite_values == 0
        && terminal_metrics.convergence_predicates_passed;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_loaded_validation_cell_v1",
        "cell_kind": "gravity_loaded_convergence_validation",
        "cell_id": loaded_cell_id(signed_lever_arm_z_m),
        "ok": passed,
        "signed_lever_arm_z_m": signed_lever_arm_z_m,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": true,
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
        "full_pd_residual_passed": terminal_metrics.full_pd_residual_passed,
        "anchor_passed": terminal_metrics.anchor_passed,
        "force_limit_passed": terminal_metrics.force_limit_passed,
        "finite_terminal_values": terminal_metrics.finite_values,
        "convergence_predicates_passed_at_terminal":
            terminal_metrics.convergence_predicates_passed,
        "maximum_observed_motor_impulse_nms": maximum_impulse,
        "step_impulse_limit_violation_count": impulse_limit_violations,
        "nonfinite_value_count": nonfinite_values,
        "maximum_observation_outer_steps": MAXIMUM_OBSERVATION_STEPS,
        "minimum_acceptance_outer_step": MINIMUM_ACCEPTANCE_STEP,
        "required_consecutive_converged_outer_steps":
            REQUIRED_CONSECUTIVE_STEPS,
        "observation_outer_steps_executed": observation_steps_executed,
        "longest_consecutive_converged_outer_steps": longest,
        "convergence_window_reached": convergence_reached,
        "convergence_window_start_outer_step": convergence_start,
        "convergence_window_end_outer_step": convergence_end,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "independent_validation_evidence": true,
        "validation_authority": passed,
        "physical_acceptance_authority": false,
    }))
}

fn loaded_cell(signed_lever_arm_z_m: f32) -> Result<Value, String> {
    check(
        SIGNED_LEVER_ARMS_Z_M.contains(&signed_lever_arm_z_m),
        "C6_RAP_HC_SPV1_LOADED_ARM",
    )?;
    let mut world = configured_world(Vector::new(0.0, -GRAVITY_M_S2, 0.0));
    let (parent, child, joint) = shared_fixture(
        &mut world,
        Vector::new(0.0, 0.0, signed_lever_arm_z_m),
        0.0,
        0.0,
        POSITION_STIFFNESS_NM_PER_RAD,
    );
    let allocation_readback_passed = world.integration_parameters.num_solver_iterations
        == SOLVER_ITERATIONS
        && world.integration_parameters.num_internal_pgs_iterations == NUM_INTERNAL_PGS_ITERATIONS
        && world
            .integration_parameters
            .num_internal_stabilization_iterations
            == NUM_INTERNAL_STABILIZATION_ITERATIONS;
    check(
        allocation_readback_passed,
        "C6_RAP_HC_SPV1_LOADED_ALLOCATION_READBACK",
    )?;
    let mut observations = Vec::with_capacity(MAXIMUM_OBSERVATION_STEPS);
    let mut consecutive = 0_usize;
    for step in 1..=MAXIMUM_OBSERVATION_STEPS {
        world.step();
        let observation = current_step_observation(&world, parent, child, joint)?;
        let metrics = evaluate_loaded_step(signed_lever_arm_z_m, &observation);
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
    summarize_loaded_trace(signed_lever_arm_z_m, &observations, 1, 1)
}

fn value_sum(values: &[Value], field: &str) -> u64 {
    values
        .iter()
        .map(|value| value[field].as_u64().unwrap_or(0))
        .sum()
}

fn matching_target<'a>(cells: &'a [Value], field: &str, target: f32) -> Option<&'a Value> {
    cells.iter().find(|cell| {
        cell[field]
            .as_f64()
            .is_some_and(|value| approximately_eq(value, target as f64))
    })
}

fn individual_cell_passed(cell: &Value) -> bool {
    let shared = allocation_fields_valid(cell)
        && cell["motor_model_readback"] == "ForceBased"
        && cell["motor_model_readback_count"] == 1
        && cell["motor_model_mismatch_count"] == 0
        && cell["nonfinite_value_count"] == 0
        && cell["step_impulse_limit_violation_count"] == 0
        && cell["force_limit_passed"] == true
        && cell["finite_terminal_values"] == true
        && cell["world_attempt_count"] == 1
        && cell["world_build_count"] == 1
        && cell["independent_validation_evidence"] == true
        && cell["physical_acceptance_authority"] == false;
    if !shared {
        return false;
    }
    match cell["cell_kind"].as_str() {
        Some("unloaded_position_validation") => {
            cell["schema_version"]
                == "sporespore_rapier_force_based_selected_configuration_position_validation_cell_v1"
                && cell["target_and_final_position_sign_match"] == true
                && cell["position_response_passed"] == true
                && cell["absolute_relative_position_error"]
                    .as_f64()
                    .is_some_and(|value| value <= MAXIMUM_RELATIVE_POSITION_ERROR as f64)
        }
        Some("signed_velocity_validation") => {
            cell["schema_version"]
                == "sporespore_rapier_force_based_selected_configuration_velocity_validation_cell_v1"
                && cell["final_position_and_velocity_signs_match_target"] == true
                && cell["velocity_response_passed"] == true
                && cell["normalized_final_velocity_response"]
                    .as_f64()
                    .is_some_and(|value| {
                        (VELOCITY_RESPONSE_MINIMUM as f64..=VELOCITY_RESPONSE_MAXIMUM as f64)
                            .contains(&value)
                    })
        }
        Some("gravity_loaded_convergence_validation") => {
            cell["schema_version"]
                == "sporespore_rapier_force_based_selected_configuration_loaded_validation_cell_v1"
                && cell["convergence_window_reached"] == true
                && cell["longest_consecutive_converged_outer_steps"]
                    == REQUIRED_CONSECUTIVE_STEPS as u64
                && cell["response_passed"] == true
                && cell["static_residual_passed"] == true
                && cell["damping_fraction_passed"] == true
                && cell["full_pd_residual_passed"] == true
                && cell["signed_geometry_passed"] == true
                && cell["anchor_passed"] == true
                && cell["convergence_predicates_passed_at_terminal"] == true
        }
        _ => false,
    }
}

fn position_pair(cells: &[Value]) -> (bool, f64) {
    let Some(negative) = matching_target(cells, "target_position_rad", -0.55) else {
        return (false, f64::INFINITY);
    };
    let Some(positive) = matching_target(cells, "target_position_rad", 0.55) else {
        return (false, f64::INFINITY);
    };
    let Some(negative_error) = negative["absolute_relative_position_error"].as_f64() else {
        return (false, f64::INFINITY);
    };
    let Some(positive_error) = positive["absolute_relative_position_error"].as_f64() else {
        return (false, f64::INFINITY);
    };
    let asymmetry = relative_difference(negative_error, positive_error);
    (
        individual_cell_passed(negative)
            && individual_cell_passed(positive)
            && asymmetry <= MAXIMUM_POSITION_PAIR_ASYMMETRY as f64,
        asymmetry,
    )
}

fn velocity_pair(cells: &[Value]) -> (bool, f64) {
    let Some(negative) = matching_target(cells, "target_velocity_rad_s", -1.25) else {
        return (false, f64::INFINITY);
    };
    let Some(positive) = matching_target(cells, "target_velocity_rad_s", 1.25) else {
        return (false, f64::INFINITY);
    };
    let Some(negative_response) = negative["normalized_final_velocity_response"].as_f64() else {
        return (false, f64::INFINITY);
    };
    let Some(positive_response) = positive["normalized_final_velocity_response"].as_f64() else {
        return (false, f64::INFINITY);
    };
    let asymmetry = relative_difference(negative_response, positive_response);
    (
        individual_cell_passed(negative)
            && individual_cell_passed(positive)
            && asymmetry <= MAXIMUM_VELOCITY_PAIR_ASYMMETRY as f64,
        asymmetry,
    )
}

fn loaded_pair_symmetry(cells: &[Value]) -> (bool, f64) {
    let mut maximum_asymmetry = 0.0_f64;
    for arm_magnitude in [0.10_f32, 0.50_f32] {
        let Some(negative) = matching_target(cells, "signed_lever_arm_z_m", -arm_magnitude) else {
            return (false, f64::INFINITY);
        };
        let Some(positive) = matching_target(cells, "signed_lever_arm_z_m", arm_magnitude) else {
            return (false, f64::INFINITY);
        };
        if negative["convergence_window_end_outer_step"].as_u64()
            != positive["convergence_window_end_outer_step"].as_u64()
        {
            return (false, f64::INFINITY);
        }
        for field in [
            "final_angle_rad",
            "terminal_motor_impulse_nms",
            "normalized_terminal_impulse_response",
            "spring_only_static_residual",
            "damping_load_fraction",
            "full_pd_gravity_residual",
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
        let Some(lower) = matching_target(cells, "signed_lever_arm_z_m", sign * 0.10) else {
            return false;
        };
        let Some(higher) = matching_target(cells, "signed_lever_arm_z_m", sign * 0.50) else {
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

fn ordered_identity_passed(cells: &[Value]) -> bool {
    let expected = [
        (
            "position_target_0.55_negative",
            "unloaded_position_validation",
        ),
        (
            "position_target_0.55_positive",
            "unloaded_position_validation",
        ),
        (
            "velocity_target_1.25_negative",
            "signed_velocity_validation",
        ),
        (
            "velocity_target_1.25_positive",
            "signed_velocity_validation",
        ),
        (
            "loaded_arm_0.10_negative",
            "gravity_loaded_convergence_validation",
        ),
        (
            "loaded_arm_0.10_positive",
            "gravity_loaded_convergence_validation",
        ),
        (
            "loaded_arm_0.50_negative",
            "gravity_loaded_convergence_validation",
        ),
        (
            "loaded_arm_0.50_positive",
            "gravity_loaded_convergence_validation",
        ),
    ];
    cells.len() == expected.len()
        && cells
            .iter()
            .zip(expected)
            .all(|(cell, (cell_id, cell_kind))| {
                cell["cell_id"] == cell_id && cell["cell_kind"] == cell_kind
            })
}

fn aggregate_report(cells: &[Value]) -> Value {
    let passed_cell_count = cells
        .iter()
        .filter(|cell| individual_cell_passed(cell))
        .count() as u64;
    let position_cells: Vec<Value> = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "unloaded_position_validation")
        .cloned()
        .collect();
    let velocity_cells: Vec<Value> = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "signed_velocity_validation")
        .cloned()
        .collect();
    let loaded_cells: Vec<Value> = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "gravity_loaded_convergence_validation")
        .cloned()
        .collect();
    let (position_pair_passed, maximum_position_pair_asymmetry) = position_pair(&position_cells);
    let (velocity_pair_passed, maximum_velocity_pair_asymmetry) = velocity_pair(&velocity_cells);
    let (loaded_pair_symmetry_passed, maximum_loaded_pair_asymmetry) =
        loaded_pair_symmetry(&loaded_cells);
    let loaded_arm_ordering_passed = arm_magnitude_ordering(&loaded_cells);
    let gravity_loaded_convergence_grid_passed = loaded_cells.len() == 4
        && loaded_cells.iter().all(individual_cell_passed)
        && loaded_pair_symmetry_passed
        && loaded_arm_ordering_passed;
    let complete = ordered_identity_passed(cells)
        && value_sum(cells, "world_attempt_count") == EXPECTED_WORLD_COUNT
        && value_sum(cells, "world_build_count") == EXPECTED_WORLD_COUNT
        && passed_cell_count == EXPECTED_WORLD_COUNT
        && position_pair_passed
        && velocity_pair_passed
        && gravity_loaded_convergence_grid_passed;
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
        "ordered_cell_identity_passed": ordered_identity_passed(cells),
        "unloaded_position_pair_passed": position_pair_passed,
        "maximum_position_pair_relative_asymmetry":
            maximum_position_pair_asymmetry,
        "signed_velocity_pair_passed": velocity_pair_passed,
        "maximum_velocity_pair_relative_asymmetry":
            maximum_velocity_pair_asymmetry,
        "gravity_loaded_signed_pair_symmetry_passed":
            loaded_pair_symmetry_passed,
        "maximum_gravity_loaded_signed_pair_relative_asymmetry":
            maximum_loaded_pair_asymmetry,
        "gravity_loaded_arm_magnitude_ordering_passed":
            loaded_arm_ordering_passed,
        "gravity_loaded_convergence_grid_passed":
            gravity_loaded_convergence_grid_passed,
        "complete_eight_cell_validation_passed": complete,
    })
}

fn boundary_failures(aggregate: &Value) -> Vec<String> {
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
    ] {
        if aggregate[field].as_u64() != Some(expected) {
            failures.push(format!("C6_RAP_HC_SPV1_{field}_INVALID"));
        }
    }
    for field in [
        "ordered_cell_identity_passed",
        "unloaded_position_pair_passed",
        "signed_velocity_pair_passed",
        "gravity_loaded_signed_pair_symmetry_passed",
        "gravity_loaded_arm_magnitude_ordering_passed",
        "gravity_loaded_convergence_grid_passed",
        "complete_eight_cell_validation_passed",
    ] {
        if aggregate[field].as_bool() != Some(true) {
            failures.push(format!("C6_RAP_HC_SPV1_{field}_INVALID"));
        }
    }
    failures
}

fn build_report(cells: Vec<Value>) -> Value {
    let aggregate = aggregate_report(&cells);
    let failures = boundary_failures(&aggregate);
    let passed = failures.is_empty();
    json!({
        "cells": cells,
        "aggregate": aggregate,
        "boundary_failure_codes": failures,
        "ok": passed,
        "rapier_force_based_selected_configuration_validation": passed,
        "rapier_force_based_static_convergence_characterization": passed,
        "rapier_force_based_host_characterization": passed,
        "validation_authority": passed,
        "rapier_selected_policy_physical_authority": false,
        "rapier_locomotion_acceptance": false,
        "different_physics_engines": false,
        "cross_engine_c6": false,
        "friction_or_material_robustness": false,
        "walking_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    })
}

fn equilibrium_angle_abs(arm_magnitude_m: f32) -> f32 {
    let nominal_load = CHILD_MASS_KG * GRAVITY_M_S2 * arm_magnitude_m;
    let mut angle = nominal_load / POSITION_STIFFNESS_NM_PER_RAD;
    for _ in 0..32 {
        angle = nominal_load * angle.cos() / POSITION_STIFFNESS_NM_PER_RAD;
    }
    angle
}

fn synthetic_position_cell(target: f32) -> Value {
    let final_position = target * 0.999;
    let error = (target - final_position).abs();
    json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_position_validation_cell_v1",
        "cell_kind": "unloaded_position_validation",
        "cell_id": position_cell_id(target),
        "ok": true,
        "target_position_rad": target,
        "target_velocity_rad_s": 0.0,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": true,
        "motor_model_readback": "ForceBased",
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": 0,
        "final_position_rad": final_position,
        "final_angular_velocity_rad_s": 0.0,
        "final_absolute_position_error_rad": error,
        "absolute_relative_position_error": error / target.abs(),
        "target_and_final_position_sign_match": true,
        "maximum_observed_motor_impulse_nms": 0.0,
        "step_impulse_limit_violation_count": 0,
        "force_limit_passed": true,
        "nonfinite_value_count": 0,
        "finite_terminal_values": true,
        "position_response_passed": true,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "independent_validation_evidence": true,
        "validation_authority": true,
        "physical_acceptance_authority": false,
    })
}

fn synthetic_velocity_cell(target: f32) -> Value {
    json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_velocity_validation_cell_v1",
        "cell_kind": "signed_velocity_validation",
        "cell_id": velocity_cell_id(target),
        "ok": true,
        "target_position_rad": 0.0,
        "target_velocity_rad_s": target,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": true,
        "motor_model_readback": "ForceBased",
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": 0,
        "final_position_rad": target.signum(),
        "final_velocity_rad_s": target,
        "normalized_final_velocity_response": 1.0,
        "final_position_and_velocity_signs_match_target": true,
        "maximum_observed_motor_impulse_nms": 0.0,
        "step_impulse_limit_violation_count": 0,
        "force_limit_passed": true,
        "nonfinite_value_count": 0,
        "finite_terminal_values": true,
        "velocity_response_passed": true,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "independent_validation_evidence": true,
        "validation_authority": true,
        "physical_acceptance_authority": false,
    })
}

fn synthetic_loaded_trace(
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

fn synthetic_cells(gap: Option<(f32, usize)>) -> Result<Vec<Value>, String> {
    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for target in POSITION_TARGETS_RAD {
        cells.push(synthetic_position_cell(target));
    }
    for target in VELOCITY_TARGETS_RAD_S {
        cells.push(synthetic_velocity_cell(target));
    }
    for arm in SIGNED_LEVER_ARMS_Z_M {
        let end_step = if arm.abs() < 0.2 { 210 } else { 200 };
        let gap_step = gap.and_then(|(gap_arm, step)| {
            approximately_eq(gap_arm as f64, arm as f64).then_some(step)
        });
        cells.push(summarize_loaded_trace(
            arm,
            &synthetic_loaded_trace(arm, end_step, gap_step),
            1,
            1,
        )?);
    }
    Ok(cells)
}

pub fn run_force_based_selected_configuration_validation_preflight() -> Result<Value, String> {
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
        .ok_or_else(|| "C6_RAP_HC_SPV1_DEFAULT_MOTOR_MISSING".to_owned())?
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
        .ok_or_else(|| "C6_RAP_HC_SPV1_EXPLICIT_MOTOR_MISSING".to_owned())?
        .model;
    let mut mutable_update = RevoluteJoint::new(Vector::X);
    mutable_update.set_motor(
        0.1,
        0.0,
        POSITION_STIFFNESS_NM_PER_RAD,
        MOTOR_DAMPING_NM_S_PER_RAD,
    );
    mutable_update.set_motor_model(MotorModel::ForceBased);
    let mutable_update_model = mutable_update
        .motor()
        .ok_or_else(|| "C6_RAP_HC_SPV1_MUTABLE_MOTOR_MISSING".to_owned())?
        .model;
    let perfect = build_report(synthetic_cells(None)?);
    let perfect_passed = perfect["ok"] == true
        && perfect["rapier_force_based_selected_configuration_validation"] == true
        && perfect["rapier_force_based_host_characterization"] == true
        && perfect["validation_authority"] == true
        && perfect["physical_acceptance_authority"] == false;

    let mut missing_cells = synthetic_cells(None)?;
    missing_cells.pop();
    let missing = build_report(missing_cells);

    let mut wrong_allocation_cells = synthetic_cells(None)?;
    wrong_allocation_cells[0]["num_internal_pgs_iterations"] = json!(2);
    wrong_allocation_cells[0]["fixed_selected_allocation_readback_passed"] = json!(false);
    let wrong_allocation = build_report(wrong_allocation_cells);

    let mut position_error_cells = synthetic_cells(None)?;
    position_error_cells[0]["absolute_relative_position_error"] = json!(0.02);
    let position_error = build_report(position_error_cells);

    let mut velocity_response_cells = synthetic_cells(None)?;
    velocity_response_cells[2]["normalized_final_velocity_response"] = json!(0.90);
    let velocity_response = build_report(velocity_response_cells);

    let loaded_gap = build_report(synthetic_cells(Some((-0.10, 180)))?);

    let mut motor_mismatch_cells = synthetic_cells(None)?;
    motor_mismatch_cells[4]["motor_model_readback"] = json!("AccelerationBased");
    motor_mismatch_cells[4]["motor_model_mismatch_count"] = json!(1);
    let motor_mismatch = build_report(motor_mismatch_cells);

    let ok = default_model == MotorModel::AccelerationBased
        && explicit_builder_model == MotorModel::ForceBased
        && mutable_update_model == MotorModel::ForceBased
        && perfect_passed
        && missing["ok"] == false
        && wrong_allocation["ok"] == false
        && position_error["ok"] == false
        && velocity_response["ok"] == false
        && loaded_gap["ok"] == false
        && motor_mismatch["ok"] == false;
    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_selected_configuration_validation_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ok": ok,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "spd1_closure_raw_sha256": SPD1_CLOSURE_RAW_SHA256,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "rapier_version": rapier3d::VERSION,
        "default_model_canary": {
            "expected": "AccelerationBased",
            "observed": motor_model_name(default_model),
            "passed": default_model == MotorModel::AccelerationBased,
        },
        "explicit_builder_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(explicit_builder_model),
            "passed": explicit_builder_model == MotorModel::ForceBased,
        },
        "mutable_update_model": {
            "expected": "ForceBased",
            "observed": motor_model_name(mutable_update_model),
            "passed": mutable_update_model == MotorModel::ForceBased,
        },
        "perfect_eight_cell_result_passed_entire_gate": perfect_passed,
        "perfect_aggregate": perfect["aggregate"].clone(),
        "perfect_failure_codes": perfect["boundary_failure_codes"].clone(),
        "missing_cell_canary_rejected": missing["ok"] == false,
        "missing_cell_canary_failure_codes":
            missing["boundary_failure_codes"].clone(),
        "wrong_allocation_canary_rejected": wrong_allocation["ok"] == false,
        "wrong_allocation_canary_failure_codes":
            wrong_allocation["boundary_failure_codes"].clone(),
        "position_error_canary_rejected": position_error["ok"] == false,
        "position_error_canary_failure_codes":
            position_error["boundary_failure_codes"].clone(),
        "velocity_response_canary_rejected": velocity_response["ok"] == false,
        "velocity_response_canary_failure_codes":
            velocity_response["boundary_failure_codes"].clone(),
        "loaded_window_gap_canary_rejected": loaded_gap["ok"] == false,
        "loaded_window_gap_canary_failure_codes":
            loaded_gap["boundary_failure_codes"].clone(),
        "motor_model_mismatch_canary_rejected": motor_mismatch["ok"] == false,
        "motor_model_mismatch_canary_failure_codes":
            motor_mismatch["boundary_failure_codes"].clone(),
        "declaration_claims": declaration["declaration_claims"].clone(),
        "world_build_count": 0,
        "physics_state_modified": false,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    }))
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

fn failed_cell(cell_kind: &str, cell_id: &str, failure: String) -> Value {
    json!({
        "schema_version":
            "sporespore_rapier_force_based_selected_configuration_failed_cell_v1",
        "cell_kind": cell_kind,
        "cell_id": cell_id,
        "ok": false,
        "failure_code": failure,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "fixed_selected_allocation_readback_passed": false,
        "motor_model_readback_count": 0,
        "motor_model_mismatch_count": 1,
        "nonfinite_value_count": 0,
        "step_impulse_limit_violation_count": 0,
        "force_limit_passed": false,
        "finite_terminal_values": false,
        "world_attempt_count": 1,
        "world_build_count": 0,
        "independent_validation_evidence": true,
        "validation_authority": false,
        "physical_acceptance_authority": false,
    })
}

fn retained_cell(
    cell_kind: &str,
    cell_id: &str,
    operation: impl FnOnce() -> Result<Value, String>,
) -> Value {
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(cell)) => cell,
        Ok(Err(failure)) => failed_cell(cell_kind, cell_id, failure),
        Err(payload) => failed_cell(
            cell_kind,
            cell_id,
            format!("C6_RAP_HC_SPV1_PANIC:{}", panic_failure(payload)),
        ),
    }
}

pub fn run_force_based_selected_configuration_validation(
    source_commit: &str,
) -> Result<Value, String> {
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "C6_RAP_HC_SPV1_SOURCE_COMMIT_INVALID",
    )?;
    let declaration = preregistration()?;
    let preflight = run_force_based_selected_configuration_validation_preflight()?;
    check(preflight["ok"] == true, "C6_RAP_HC_SPV1_PREFLIGHT")?;
    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for target in POSITION_TARGETS_RAD {
        cells.push(retained_cell(
            "unloaded_position_validation",
            position_cell_id(target),
            || position_cell(target),
        ));
    }
    for target in VELOCITY_TARGETS_RAD_S {
        cells.push(retained_cell(
            "signed_velocity_validation",
            velocity_cell_id(target),
            || velocity_cell(target),
        ));
    }
    for arm in SIGNED_LEVER_ARMS_Z_M {
        cells.push(retained_cell(
            "gravity_loaded_convergence_validation",
            loaded_cell_id(arm),
            || loaded_cell(arm),
        ));
    }
    let evaluated = build_report(cells);
    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_selected_configuration_validation_report_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "exact_finite_cell_independent_host_validation",
        "source": {
            "commit": source_commit,
            "remote": "origin/main",
            "origin_main_commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "preregistration": {
            "path":
                "sdk/rapier_c6_force_based_selected_configuration_validation_spv1_preregistration.json",
            "raw_sha256": PREREGISTRATION_RAW_SHA256,
            "status": declaration["status"].clone(),
            "implementation_parent_commit":
                declaration["implementation_parent_commit"].clone(),
        },
        "predecessor": {
            "spd1_closure_raw_sha256": SPD1_CLOSURE_RAW_SHA256,
            "selected_candidate_id": "SPD1-B",
            "selector_reinvoked": false,
        },
        "preflight": preflight,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "cargo_lock_raw_sha256": CARGO_LOCK_RAW_SHA256,
        "motor_model": "ForceBased",
        "outer_timestep_s": RAPIER_DT_S,
        "solver_iterations": SOLVER_ITERATIONS,
        "num_internal_pgs_iterations": NUM_INTERNAL_PGS_ITERATIONS,
        "num_internal_stabilization_iterations":
            NUM_INTERNAL_STABILIZATION_ITERATIONS,
        "total_constraint_passes_per_small_step": TOTAL_CONSTRAINT_PASSES,
        "position_targets_rad": POSITION_TARGETS_RAD,
        "velocity_targets_rad_s": VELOCITY_TARGETS_RAD_S,
        "signed_lever_arms_z_m": SIGNED_LEVER_ARMS_Z_M,
        "cells": evaluated["cells"].clone(),
        "aggregate": evaluated["aggregate"].clone(),
        "boundary_failure_codes":
            evaluated["boundary_failure_codes"].clone(),
        "ok": evaluated["ok"].clone(),
        "rapier_force_based_selected_configuration_validation":
            evaluated["rapier_force_based_selected_configuration_validation"].clone(),
        "rapier_force_based_static_convergence_characterization":
            evaluated["rapier_force_based_static_convergence_characterization"].clone(),
        "rapier_force_based_host_characterization":
            evaluated["rapier_force_based_host_characterization"].clone(),
        "validation_authority": evaluated["validation_authority"].clone(),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_zero_world_validation_gate_and_canaries_pass() {
        let preflight =
            run_force_based_selected_configuration_validation_preflight().expect("SPV1 preflight");
        assert_eq!(preflight["ok"], true);
        assert_eq!(
            preflight["perfect_eight_cell_result_passed_entire_gate"],
            true
        );
        assert_eq!(preflight["missing_cell_canary_rejected"], true);
        assert_eq!(preflight["wrong_allocation_canary_rejected"], true);
        assert_eq!(preflight["position_error_canary_rejected"], true);
        assert_eq!(preflight["velocity_response_canary_rejected"], true);
        assert_eq!(preflight["loaded_window_gap_canary_rejected"], true);
        assert_eq!(preflight["motor_model_mismatch_canary_rejected"], true);
        assert_eq!(preflight["world_build_count"], 0);
        assert_eq!(preflight["physics_state_modified"], false);
        assert_eq!(preflight["validation_authority"], false);
    }

    #[test]
    fn perfect_synthetic_result_grants_only_bounded_host_validation() {
        let report = build_report(synthetic_cells(None).expect("synthetic SPV1 cells"));
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["rapier_force_based_selected_configuration_validation"],
            true
        );
        assert_eq!(report["rapier_force_based_host_characterization"], true);
        assert_eq!(report["validation_authority"], true);
        assert_eq!(report["rapier_selected_policy_physical_authority"], false);
        assert_eq!(report["physical_acceptance_authority"], false);
        assert_eq!(report["different_physics_engines"], false);
        assert_eq!(report["completed_engine_neutral_sdk"], false);
    }
}
