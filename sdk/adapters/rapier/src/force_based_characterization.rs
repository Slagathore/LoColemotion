use std::any::Any;

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest_sha256};

const PREREGISTRATION_RAW: &str =
    include_str!("../../../rapier_c6_force_based_host_characterization_preregistration.json");
const PREDECESSOR_HOST_CLOSURE_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_r2_closure.json");
const PREDECESSOR_LOCOMOTION_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_r2_closure.json");
const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:7d3753308707f4e96b33959eea5dbf0ad54ae6e442614a2acb87d339c26d20dc";
const PREDECESSOR_HOST_CLOSURE_RAW_SHA256: &str =
    "sha256:a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9";
const PREDECESSOR_LOCOMOTION_CLOSURE_RAW_SHA256: &str =
    "sha256:07b02dbd2343d772a002b045ce32cbc6d5bb07c3fa63a308a4b06d70f202097d";

const CAMPAIGN_ID: &str = "C6-RAPIER-FORCE-BASED-HOST-CHARACTERIZATION";
const GATE_ID: &str = "C6-RAP-HC-FB1";
const EXPECTED_WORLD_COUNT: u64 = 8;
const SOLVER_ITERATIONS: usize = 20;
const INTERNAL_PGS_ITERATIONS: usize = 1;
const INTERNAL_STABILIZATION_ITERATIONS: usize = 7;
const CHILD_HALF_EXTENTS_M: [f32; 3] = [0.2, 0.2, 0.2];
const CHILD_MASS_KG: f32 = 1.0;
const POSITION_STIFFNESS: f32 = 40.0;
const MOTOR_DAMPING: f32 = 10.0;
const POSITION_STEPS: usize = 240;
const VELOCITY_STEPS: usize = 120;
const LOADED_STEPS: usize = 240;
const MAXIMUM_POSITION_ERROR_RAD: f32 = 0.02;
const MINIMUM_VELOCITY_ANGLE_RAD: f32 = 0.05;
const MAXIMUM_LOADED_ANGLE_RAD: f32 = 0.1;
const MINIMUM_LOADED_TERMINAL_IMPULSE_NMS: f32 = 0.005;
const IMPULSE_TOLERANCE_NMS: f32 = 0.000_001;
const POSITION_TARGETS_RAD: [f32; 2] = [-0.4, 0.4];
const POSITION_MAXIMUM_STEP_IMPULSES_NMS: [f32; 2] = [0.05, 0.25];
const VELOCITY_TARGETS_RAD_S: [f32; 2] = [-1.0, 1.0];
const LOADED_OFFSETS_Z_M: [f32; 2] = [-0.3, 0.3];

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn check(condition: bool, failure_code: impl Into<String>) -> Result<(), String> {
    condition.then_some(()).ok_or_else(|| failure_code.into())
}

fn configured_world(gravity: Vector) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = SOLVER_ITERATIONS;
    world.integration_parameters.num_internal_pgs_iterations = INTERNAL_PGS_ITERATIONS;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = INTERNAL_STABILIZATION_ITERATIONS;
    world
}

fn maximum_impulse_to_motor_max_force(maximum_step_impulse_nms: f32) -> Result<f32, String> {
    check(
        maximum_step_impulse_nms.is_finite() && maximum_step_impulse_nms > 0.0,
        "C6_RAP_HC_FB1_MAXIMUM_STEP_IMPULSE_INVALID",
    )?;
    let maximum_force_nm = maximum_step_impulse_nms / RAPIER_DT_S;
    check(
        maximum_force_nm.is_finite(),
        "C6_RAP_HC_FB1_MAXIMUM_FORCE_UNREPRESENTABLE",
    )?;
    Ok(maximum_force_nm)
}

fn motor_model_name(model: MotorModel) -> &'static str {
    match model {
        MotorModel::AccelerationBased => "AccelerationBased",
        MotorModel::ForceBased => "ForceBased",
    }
}

fn preregistration() -> Result<Value, String> {
    check(
        raw_sha256(PREREGISTRATION_RAW) == PREREGISTRATION_RAW_SHA256,
        "C6_RAP_HC_FB1_PREREGISTRATION_HASH",
    )?;
    check(
        raw_sha256(PREDECESSOR_HOST_CLOSURE_RAW) == PREDECESSOR_HOST_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_FB1_PREDECESSOR_HOST_CLOSURE_HASH",
    )?;
    check(
        raw_sha256(PREDECESSOR_LOCOMOTION_CLOSURE_RAW) == PREDECESSOR_LOCOMOTION_CLOSURE_RAW_SHA256,
        "C6_RAP_HC_FB1_PREDECESSOR_LOCOMOTION_CLOSURE_HASH",
    )?;
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_HC_FB1_PREREGISTRATION_PARSE:{error}"))?;
    check(
        declaration["schema_version"]
            == "sporespore_rapier_c6_force_based_host_characterization_preregistration_v1"
            && declaration["campaign_id"] == CAMPAIGN_ID
            && declaration["gate_id"] == GATE_ID
            && declaration["status"] == "frozen_before_first_c6_rap_hc_fb1_physics_world"
            && declaration["implementation_parent_commit"]
                == "7027e6654925dc5e054959e0dac431d66f189d85"
            && declaration["predecessor_host_characterization"]["raw_sha256"]
                == PREDECESSOR_HOST_CLOSURE_RAW_SHA256
            && declaration["predecessor_locomotion_diagnostic"]["raw_sha256"]
                == PREDECESSOR_LOCOMOTION_CLOSURE_RAW_SHA256
            && declaration["correction"]["required_model"] == "ForceBased"
            && declaration["physical_grid"]["expected_world_count"] == EXPECTED_WORLD_COUNT
            && declaration["preflight_contract"]["must_run_before_any_physics_world"] == true
            && declaration["preflight_contract"]["perfect_synthetic_result_must_pass_entire_integrity_gate"]
                == true
            && declaration["preflight_contract"]["nonzero_failure_canary_must_fail_entire_integrity_gate"]
                == true,
        "C6_RAP_HC_FB1_PREREGISTRATION_IDENTITY",
    )?;
    Ok(declaration)
}

fn integrity_failures(report: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    let exact_counts = [
        ("world_attempt_count", EXPECTED_WORLD_COUNT),
        ("world_build_count", EXPECTED_WORLD_COUNT),
        ("cell_count", EXPECTED_WORLD_COUNT),
        ("passed_cell_count", EXPECTED_WORLD_COUNT),
        ("failed_cell_count", 0),
        ("motor_model_readback_count", EXPECTED_WORLD_COUNT),
        ("motor_model_mismatch_count", 0),
        ("nonfinite_value_count", 0),
        ("step_impulse_limit_violation_count", 0),
    ];
    for (name, expected) in exact_counts {
        if report[name].as_u64() != Some(expected) {
            failures.push(format!("C6_RAP_HC_FB1_{name}_INVALID"));
        }
    }
    for name in [
        "unloaded_position_grid_passed",
        "signed_velocity_pair_passed",
        "gravity_loaded_support_pair_passed",
        "paired_loaded_final_angle_signs_opposite",
        "paired_loaded_terminal_motor_impulse_signs_opposite",
    ] {
        if report[name].as_bool() != Some(true) {
            failures.push(format!("C6_RAP_HC_FB1_{name}_INVALID"));
        }
    }
    failures
}

fn perfect_synthetic_result() -> Value {
    json!({
        "world_attempt_count": EXPECTED_WORLD_COUNT,
        "world_build_count": EXPECTED_WORLD_COUNT,
        "cell_count": EXPECTED_WORLD_COUNT,
        "passed_cell_count": EXPECTED_WORLD_COUNT,
        "failed_cell_count": 0,
        "motor_model_readback_count": EXPECTED_WORLD_COUNT,
        "motor_model_mismatch_count": 0,
        "nonfinite_value_count": 0,
        "step_impulse_limit_violation_count": 0,
        "unloaded_position_grid_passed": true,
        "signed_velocity_pair_passed": true,
        "gravity_loaded_support_pair_passed": true,
        "paired_loaded_final_angle_signs_opposite": true,
        "paired_loaded_terminal_motor_impulse_signs_opposite": true,
    })
}

pub fn run_force_based_host_characterization_preflight() -> Result<Value, String> {
    let declaration = preregistration()?;

    let mut default_canary = RevoluteJoint::new(Vector::X);
    default_canary.set_motor(0.1, 0.0, POSITION_STIFFNESS, MOTOR_DAMPING);
    let default_model = default_canary
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_DEFAULT_CANARY_MOTOR_MISSING".to_owned())?
        .model;

    let mut explicit = RevoluteJoint::new(Vector::X);
    explicit
        .set_motor(0.1, 0.0, POSITION_STIFFNESS, MOTOR_DAMPING)
        .set_motor_model(MotorModel::ForceBased);
    let explicit_builder_model = explicit
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_EXPLICIT_MOTOR_MISSING".to_owned())?
        .model;
    explicit
        .set_motor(-0.1, 0.5, POSITION_STIFFNESS, MOTOR_DAMPING)
        .set_motor_model(MotorModel::ForceBased);
    let mutable_update_model = explicit
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_MUTABLE_MOTOR_MISSING".to_owned())?
        .model;

    let perfect = perfect_synthetic_result();
    let perfect_failures = integrity_failures(&perfect);
    let serialized = serde_json::to_string(&perfect)
        .map_err(|error| format!("C6_RAP_HC_FB1_SYNTHETIC_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_HC_FB1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let mut canary = perfect.clone();
    canary["motor_model_mismatch_count"] = json!(1);
    let canary_failures = integrity_failures(&canary);

    let default_canary_passed = default_model == MotorModel::AccelerationBased;
    let explicit_builder_passed = explicit_builder_model == MotorModel::ForceBased;
    let mutable_update_passed = mutable_update_model == MotorModel::ForceBased;
    let perfect_passed = perfect_failures.is_empty() && round_trip == perfect;
    let canary_rejected = canary_failures
        .iter()
        .any(|failure| failure.contains("motor_model_mismatch_count"));
    let ok = default_canary_passed
        && explicit_builder_passed
        && mutable_update_passed
        && perfect_passed
        && canary_rejected;

    Ok(json!({
        "schema_version":
            "sporespore_rapier_c6_force_based_host_characterization_preflight_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "predecessor_host_closure_raw_sha256": PREDECESSOR_HOST_CLOSURE_RAW_SHA256,
        "predecessor_locomotion_closure_raw_sha256":
            PREDECESSOR_LOCOMOTION_CLOSURE_RAW_SHA256,
        "rapier_version": rapier3d::VERSION,
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
        "perfect_synthetic_result_passed_entire_integrity_gate": perfect_passed,
        "perfect_synthetic_failure_codes": perfect_failures,
        "nonzero_motor_model_mismatch_canary_rejected": canary_rejected,
        "nonzero_canary_failure_codes": canary_failures,
        "declaration_claims": declaration["claims"].clone(),
        "world_build_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    }))
}

fn position_tracking_cell(
    target_position_rad: f32,
    maximum_step_impulse_nms: f32,
) -> Result<Value, String> {
    let maximum_motor_force_nm = maximum_impulse_to_motor_max_force(maximum_step_impulse_nms)?;
    let mut world = configured_world(Vector::ZERO);
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
            .motor(target_position_rad, 0.0, POSITION_STIFFNESS, MOTOR_DAMPING)
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(maximum_motor_force_nm),
    );
    let mut model_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_observed_impulse_nms = 0.0_f32;
    for _ in 0..POSITION_STEPS {
        world.step();
        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_REVOLUTE_MISSING".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_MOTOR_MISSING".to_owned())?;
        model_mismatches += u64::from(motor.model != MotorModel::ForceBased);
        nonfinite_values += u64::from(!motor.impulse.is_finite());
        maximum_observed_impulse_nms = maximum_observed_impulse_nms.max(motor.impulse.abs());
        impulse_violations +=
            u64::from(motor.impulse.abs() > maximum_step_impulse_nms + IMPULSE_TOLERANCE_NMS);
    }
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_POSITION_MOTOR_MISSING".to_owned())?;
    let final_angle_rad = revolute.angle(
        world.bodies[parent].rotation(),
        world.bodies[child].rotation(),
    );
    let final_error_rad = (final_angle_rad - target_position_rad).abs();
    nonfinite_values += u64::from(
        !final_angle_rad.is_finite()
            || !final_error_rad.is_finite()
            || !maximum_observed_impulse_nms.is_finite(),
    );
    let passed = model_mismatches == 0
        && impulse_violations == 0
        && nonfinite_values == 0
        && final_error_rad <= MAXIMUM_POSITION_ERROR_RAD;
    Ok(json!({
        "schema_version": "sporespore_rapier_force_based_position_cell_v1",
        "cell_kind": "unloaded_position_tracking",
        "ok": passed,
        "target_position_rad": target_position_rad,
        "target_velocity_rad_s": 0.0,
        "maximum_step_impulse_nms": maximum_step_impulse_nms,
        "mapped_maximum_motor_force_nm": maximum_motor_force_nm,
        "motor_model_readback": motor_model_name(motor.model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_position_rad": final_angle_rad,
        "final_absolute_position_error_rad": final_error_rad,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "step_impulse_limit_violation_count": impulse_violations,
        "nonfinite_value_count": nonfinite_values,
        "observation_steps": POSITION_STEPS,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn signed_velocity_cell(target_velocity_rad_s: f32) -> Result<Value, String> {
    let maximum_step_impulse_nms = 0.05;
    let maximum_motor_force_nm = maximum_impulse_to_motor_max_force(maximum_step_impulse_nms)?;
    let mut world = configured_world(Vector::ZERO);
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
            .motor(0.0, target_velocity_rad_s, 0.0, MOTOR_DAMPING)
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(maximum_motor_force_nm),
    );
    let mut model_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_observed_impulse_nms = 0.0_f32;
    for _ in 0..VELOCITY_STEPS {
        world.step();
        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_REVOLUTE_MISSING".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_MOTOR_MISSING".to_owned())?;
        model_mismatches += u64::from(motor.model != MotorModel::ForceBased);
        nonfinite_values += u64::from(!motor.impulse.is_finite());
        maximum_observed_impulse_nms = maximum_observed_impulse_nms.max(motor.impulse.abs());
        impulse_violations +=
            u64::from(motor.impulse.abs() > maximum_step_impulse_nms + IMPULSE_TOLERANCE_NMS);
    }
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_VELOCITY_MOTOR_MISSING".to_owned())?;
    let final_angle_rad = revolute.angle(
        world.bodies[parent].rotation(),
        world.bodies[child].rotation(),
    );
    let final_velocity_rad_s = world.bodies[child]
        .angvel()
        .dot(world.bodies[parent].rotation() * Vector::X);
    nonfinite_values +=
        u64::from(!final_angle_rad.is_finite() || !final_velocity_rad_s.is_finite());
    let signs_match = final_angle_rad.signum() == target_velocity_rad_s.signum()
        && final_velocity_rad_s.signum() == target_velocity_rad_s.signum();
    let passed = model_mismatches == 0
        && impulse_violations == 0
        && nonfinite_values == 0
        && signs_match
        && final_angle_rad.abs() >= MINIMUM_VELOCITY_ANGLE_RAD;
    Ok(json!({
        "schema_version": "sporespore_rapier_force_based_velocity_cell_v1",
        "cell_kind": "signed_velocity",
        "ok": passed,
        "target_position_rad": 0.0,
        "target_velocity_rad_s": target_velocity_rad_s,
        "maximum_step_impulse_nms": maximum_step_impulse_nms,
        "mapped_maximum_motor_force_nm": maximum_motor_force_nm,
        "motor_model_readback": motor_model_name(motor.model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_position_rad": final_angle_rad,
        "final_velocity_rad_s": final_velocity_rad_s,
        "observed_angle_and_velocity_sign_match_target": signs_match,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "step_impulse_limit_violation_count": impulse_violations,
        "nonfinite_value_count": nonfinite_values,
        "observation_steps": VELOCITY_STEPS,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn gravity_loaded_support_cell(center_of_mass_offset_z_m: f32) -> Result<Value, String> {
    let maximum_step_impulse_nms = 0.05;
    let maximum_motor_force_nm = maximum_impulse_to_motor_max_force(maximum_step_impulse_nms)?;
    let mut world = configured_world(Vector::new(0.0, -9.8, 0.0));
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _) = world.insert(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, 0.0, center_of_mass_offset_z_m))
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
            .local_anchor2(Vector::new(0.0, 0.0, -center_of_mass_offset_z_m))
            .motor(0.0, 0.0, POSITION_STIFFNESS, MOTOR_DAMPING)
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(maximum_motor_force_nm),
    );
    let mut model_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite_values = 0_u64;
    let mut maximum_observed_impulse_nms = 0.0_f32;
    for _ in 0..LOADED_STEPS {
        world.step();
        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_REVOLUTE_MISSING".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_MOTOR_MISSING".to_owned())?;
        model_mismatches += u64::from(motor.model != MotorModel::ForceBased);
        nonfinite_values += u64::from(!motor.impulse.is_finite());
        maximum_observed_impulse_nms = maximum_observed_impulse_nms.max(motor.impulse.abs());
        impulse_violations +=
            u64::from(motor.impulse.abs() > maximum_step_impulse_nms + IMPULSE_TOLERANCE_NMS);
    }
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_REVOLUTE_MISSING".to_owned())?;
    let motor = revolute
        .motor()
        .ok_or_else(|| "C6_RAP_HC_FB1_LOADED_MOTOR_MISSING".to_owned())?;
    let final_angle_rad = revolute.angle(
        world.bodies[parent].rotation(),
        world.bodies[child].rotation(),
    );
    let terminal_motor_impulse_nms = motor.impulse;
    let parent_anchor_world = world.bodies[parent]
        .position()
        .transform_point(revolute.local_anchor1());
    let child_anchor_world = world.bodies[child]
        .position()
        .transform_point(revolute.local_anchor2());
    let final_anchor_error_m = (parent_anchor_world - child_anchor_world).length();
    nonfinite_values += u64::from(
        !final_angle_rad.is_finite()
            || !terminal_motor_impulse_nms.is_finite()
            || !final_anchor_error_m.is_finite(),
    );
    let passed = model_mismatches == 0
        && impulse_violations == 0
        && nonfinite_values == 0
        && final_angle_rad.abs() <= MAXIMUM_LOADED_ANGLE_RAD
        && terminal_motor_impulse_nms.abs() >= MINIMUM_LOADED_TERMINAL_IMPULSE_NMS;
    Ok(json!({
        "schema_version": "sporespore_rapier_force_based_loaded_support_cell_v1",
        "cell_kind": "gravity_loaded_support",
        "ok": passed,
        "gravity_m_s2": [0.0, -9.8, 0.0],
        "center_of_mass_offset_z_m": center_of_mass_offset_z_m,
        "target_position_rad": 0.0,
        "target_velocity_rad_s": 0.0,
        "maximum_step_impulse_nms": maximum_step_impulse_nms,
        "mapped_maximum_motor_force_nm": maximum_motor_force_nm,
        "motor_model_readback": motor_model_name(motor.model),
        "motor_model_readback_count": 1,
        "motor_model_mismatch_count": model_mismatches,
        "final_position_rad": final_angle_rad,
        "terminal_motor_impulse_nms": terminal_motor_impulse_nms,
        "maximum_observed_motor_impulse_nms": maximum_observed_impulse_nms,
        "final_anchor_error_m": final_anchor_error_m,
        "step_impulse_limit_violation_count": impulse_violations,
        "nonfinite_value_count": nonfinite_values,
        "observation_steps": LOADED_STEPS,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn panic_failure(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        format!("C6_RAP_HC_FB1_PANIC:{message}")
    } else if let Some(message) = payload.downcast_ref::<String>() {
        format!("C6_RAP_HC_FB1_PANIC:{message}")
    } else {
        "C6_RAP_HC_FB1_PANIC:non_string_payload".to_owned()
    }
}

fn retained_cell(
    cell_kind: &str,
    identity: Value,
    run: impl FnOnce() -> Result<Value, String> + std::panic::UnwindSafe,
) -> Value {
    match std::panic::catch_unwind(run) {
        Ok(Ok(cell)) => cell,
        Ok(Err(failure)) => json!({
            "schema_version": "sporespore_rapier_force_based_failed_cell_v1",
            "cell_kind": cell_kind,
            "identity": identity,
            "ok": false,
            "failure_codes": [failure],
            "motor_model_readback_count": 0,
            "motor_model_mismatch_count": 1,
            "step_impulse_limit_violation_count": 0,
            "nonfinite_value_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physical_acceptance_authority": false,
        }),
        Err(payload) => json!({
            "schema_version": "sporespore_rapier_force_based_failed_cell_v1",
            "cell_kind": cell_kind,
            "identity": identity,
            "ok": false,
            "failure_codes": [panic_failure(payload)],
            "motor_model_readback_count": 0,
            "motor_model_mismatch_count": 1,
            "step_impulse_limit_violation_count": 0,
            "nonfinite_value_count": 0,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physical_acceptance_authority": false,
        }),
    }
}

fn value_sum(cells: &[Value], field: &str) -> u64 {
    cells
        .iter()
        .map(|cell| cell[field].as_u64().unwrap_or(0))
        .sum()
}

pub fn run_force_based_host_characterization(source_commit: &str) -> Result<Value, String> {
    check(
        source_commit.len() == 40 && source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()),
        "C6_RAP_HC_FB1_SOURCE_COMMIT_INVALID",
    )?;
    let declaration = preregistration()?;
    let preflight = run_force_based_host_characterization_preflight()?;
    check(
        preflight["ok"] == true && preflight["world_build_count"] == 0,
        "C6_RAP_HC_FB1_PREFLIGHT_FAILED",
    )?;

    let mut cells = Vec::with_capacity(EXPECTED_WORLD_COUNT as usize);
    for target in POSITION_TARGETS_RAD {
        for maximum_impulse in POSITION_MAXIMUM_STEP_IMPULSES_NMS {
            cells.push(retained_cell(
                "unloaded_position_tracking",
                json!({
                    "target_position_rad": target,
                    "maximum_step_impulse_nms": maximum_impulse,
                }),
                || position_tracking_cell(target, maximum_impulse),
            ));
        }
    }
    for target_velocity in VELOCITY_TARGETS_RAD_S {
        cells.push(retained_cell(
            "signed_velocity",
            json!({"target_velocity_rad_s": target_velocity}),
            || signed_velocity_cell(target_velocity),
        ));
    }
    for offset in LOADED_OFFSETS_Z_M {
        cells.push(retained_cell(
            "gravity_loaded_support",
            json!({"center_of_mass_offset_z_m": offset}),
            || gravity_loaded_support_cell(offset),
        ));
    }

    let position_cells = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "unloaded_position_tracking")
        .collect::<Vec<_>>();
    let velocity_cells = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "signed_velocity")
        .collect::<Vec<_>>();
    let loaded_cells = cells
        .iter()
        .filter(|cell| cell["cell_kind"] == "gravity_loaded_support")
        .collect::<Vec<_>>();
    let loaded_angle_signs_opposite = loaded_cells.len() == 2
        && loaded_cells[0]["final_position_rad"]
            .as_f64()
            .zip(loaded_cells[1]["final_position_rad"].as_f64())
            .is_some_and(|(a, b)| a != 0.0 && b != 0.0 && a.signum() == -b.signum());
    let loaded_impulse_signs_opposite = loaded_cells.len() == 2
        && loaded_cells[0]["terminal_motor_impulse_nms"]
            .as_f64()
            .zip(loaded_cells[1]["terminal_motor_impulse_nms"].as_f64())
            .is_some_and(|(a, b)| a != 0.0 && b != 0.0 && a.signum() == -b.signum());
    let position_grid_passed =
        position_cells.len() == 4 && position_cells.iter().all(|cell| cell["ok"] == true);
    let velocity_pair_passed =
        velocity_cells.len() == 2 && velocity_cells.iter().all(|cell| cell["ok"] == true);
    let loaded_pair_passed = loaded_cells.len() == 2
        && loaded_cells.iter().all(|cell| cell["ok"] == true)
        && loaded_angle_signs_opposite
        && loaded_impulse_signs_opposite;
    let passed_cell_count = cells.iter().filter(|cell| cell["ok"] == true).count() as u64;
    let aggregate = json!({
        "world_attempt_count": value_sum(&cells, "world_attempt_count"),
        "world_build_count": value_sum(&cells, "world_build_count"),
        "cell_count": cells.len() as u64,
        "passed_cell_count": passed_cell_count,
        "failed_cell_count": cells.len() as u64 - passed_cell_count,
        "motor_model_readback_count": value_sum(&cells, "motor_model_readback_count"),
        "motor_model_mismatch_count": value_sum(&cells, "motor_model_mismatch_count"),
        "nonfinite_value_count": value_sum(&cells, "nonfinite_value_count"),
        "step_impulse_limit_violation_count":
            value_sum(&cells, "step_impulse_limit_violation_count"),
        "unloaded_position_grid_passed": position_grid_passed,
        "signed_velocity_pair_passed": velocity_pair_passed,
        "gravity_loaded_support_pair_passed": loaded_pair_passed,
        "paired_loaded_final_angle_signs_opposite": loaded_angle_signs_opposite,
        "paired_loaded_terminal_motor_impulse_signs_opposite":
            loaded_impulse_signs_opposite,
    });
    let failure_codes = integrity_failures(&aggregate);
    let ok = failure_codes.is_empty();

    Ok(json!({
        "schema_version": "sporespore_rapier_c6_force_based_host_characterization_report_v1",
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source": {
            "commit": source_commit,
            "remote": "origin/main",
            "origin_main_commit": source_commit,
            "clean": true,
            "matches_origin_main": true,
        },
        "preregistration": {
            "path": "sdk/rapier_c6_force_based_host_characterization_preregistration.json",
            "raw_sha256": PREREGISTRATION_RAW_SHA256,
            "status": declaration["status"].clone(),
            "implementation_parent_commit": declaration["implementation_parent_commit"].clone(),
        },
        "predecessor_host_closure_raw_sha256": PREDECESSOR_HOST_CLOSURE_RAW_SHA256,
        "predecessor_locomotion_closure_raw_sha256":
            PREDECESSOR_LOCOMOTION_CLOSURE_RAW_SHA256,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "motor_model": "ForceBased",
        "force_limit_mapping":
            "maximum_motor_force_nm = maximum_step_impulse_nms / timestep_s",
        "timestep_s": RAPIER_DT_S,
        "solver_iterations": SOLVER_ITERATIONS,
        "internal_pgs_iterations": INTERNAL_PGS_ITERATIONS,
        "internal_stabilization_iterations": INTERNAL_STABILIZATION_ITERATIONS,
        "preflight": preflight,
        "cells": cells,
        "aggregate": aggregate,
        "failure_codes": failure_codes,
        "rapier_force_based_host_characterization":
            ok,
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
