use std::{collections::BTreeMap, env, fs};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{
    CommandAuthority, MOTION_COMMAND_VERSION, MotionCommand, PhaseProgressionMode, Quaternion,
    SpeedClass,
};
use sporespore_locomotion_core::schema::Vec3;
use sporespore_locomotion_core::{
    BalancedWaveController, BalancedWaveControllerMemory, CanonicalVelocityResidualV1,
    RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID, SELECTED_BALANCED_WAVE_POLICY_ID,
    VelocityOnlyHostProfileV1, compile_bounded_quadruped,
};

use crate::{
    ADAPTER_ID, RAPIER_DT_S,
    bw19v_composition::map_bw19v_velocity_only_v4,
    capability_manifest_sha256,
    locomotion::{
        FootEvidence, HostRobot, build_bw19v_velocity_only_v4_robot_with_friction, descriptor,
        state_contains_nonfinite, synthetic_state_frame,
    },
};

const CONTRACT_RAW: &str = include_str!("../../../turning/physical_development_contract_v1.json");
const CAMPAIGN_ID: &str = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT";
const GATE_ID: &str = "QSDK-R23D1";
const ENGINE_ID: &str = "rapier_parry";
const POLICY_ID: &str = "sporespore_balanced_wave_bw5r_b_v1";
const POLICY_DIGEST: &str =
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f";
const MORPHOLOGY_ID: &str = "qsdk_r05_generated_s169";
const REPORT_SCHEMA: &str = "sporespore_qsdk_r23d1_engine_cell_report_v2";
const COMMAND_VALIDATION_SCHEMA: &str = "sporespore_qsdk_r23d1_command_validation_v1";
const NORMALIZED_VALIDATION_MODE: &str = "native_adapter_structure_and_receipts_v1";
const SOURCE_VALIDATION_MODE: &str =
    "rapier_force_based_velocity_only_structure_mapping_and_motor_readback_v1";
const SCHEDULE_ID: &str = "qsdk_r23d1_step_turn_return_v1";
const CAMPAIGN_SEED: u64 = 21_501;
const AUTHORED_FRICTION: f64 = 0.95;
const PHYSICS_HZ: u64 = 120;
const SETTLE_STEPS: u64 = 240;
const PHASE_OFFSET_ACTIVATION_STEP: u64 = 360;
const CONTACT_GATED_START_STEP: u64 = 472;
const CONTROLLER_STEPS: u64 = 2_992;
const TERMINAL_SETTLE_STEPS: u64 = 240;
const TURN_START_STEP: u64 = 600;
const TURN_END_STEP_EXCLUSIVE: u64 = 1_800;
const DECLARED_SCHEDULE_END_STEP_EXCLUSIVE: u64 = 2_400;
const MINIMUM_ABSOLUTE_TURN_PHASE_YAW_DELTA_RAD: f64 = 0.01;
const MINIMUM_FINAL_FORWARD_DISPLACEMENT_M: f64 = 0.030_123_046_875;
const MAXIMUM_TILT_RAD: f64 = 0.6;
const MINIMUM_TORSO_HEIGHT_M: f64 = 0.249_970_865_207_294_6;
const MINIMUM_CONTACT_CYCLES_PER_LIMB: u64 = 2;
const MAXIMUM_STEERING_FRACTION: f64 = 0.4;

const ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D1_ATTEMPT";
const AUTHORIZATION_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D1_TOKEN";
const CELL_ID_ENV: &str = "SPORESPORE_QSDK_R23D1_CELL";
const ENGINE_ID_ENV: &str = "SPORESPORE_QSDK_R23D1_ENGINE";
const PHYSICAL_IDENTITY_CLOSED: bool = true;

#[derive(Debug, Clone, Copy)]
struct InitialPerturbation {
    vertical_clearance_m: f64,
    yaw_rad: f64,
    linear_velocity_world_m_s: [f64; 3],
    torso_angular_velocity_world_rad_s: [f64; 3],
    gait_phase_offset_ticks: i64,
}

#[derive(Debug, Clone)]
struct HeadingCommandReceipt {
    segment_id: &'static str,
    command_role: &'static str,
    heading_offset_rad: f64,
    desired_heading_rad: f64,
    declared_segment: bool,
}

fn raw_sha256(bytes: &[u8]) -> String {
    format!("sha256:{:x}", Sha256::digest(bytes))
}

fn contract() -> Result<Value, String> {
    let value: Value = serde_json::from_str(CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R23D1_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let expected_descriptor = serde_json::to_value(descriptor())
        .map_err(|error| format!("QSDK_R23D1_RAP_DESCRIPTOR_JSON_INVALID:{error}"))?;
    let engine = value["engines"].as_array().and_then(|engines| {
        engines
            .iter()
            .find(|engine| engine["engine_id"] == ENGINE_ID)
    });
    let engine_ids_exact = value["engines"].as_array().is_some_and(|engines| {
        engines
            .iter()
            .filter_map(|engine| engine["engine_id"].as_str())
            .eq(["godot_jolt", "rapier_parry", "mujoco"])
    });
    if value["schema_version"] != "sporespore_qsdk_r23d1_physical_development_contract_v1"
        || value["campaign_id"] != CAMPAIGN_ID
        || value["gate_id"] != GATE_ID
        || value["source_contract"]["selected_policy_id"] != POLICY_ID
        || value["source_contract"]["selected_policy_digest"] != POLICY_DIGEST
        || value["fixture"]["morphology_id"] != MORPHOLOGY_ID
        || value["fixture"]["descriptor"] != expected_descriptor
        || value["fixture"]["initial_condition_seed"] != CAMPAIGN_SEED
        || value["fixture"]["initial_condition_policy"]
            != "physical_wave_gait_compile_seeded_initial_perturbation_v1"
        || value["fixture"]["physics_hz"] != PHYSICS_HZ
        || value["fixture"]["authored_sliding_friction"] != AUTHORED_FRICTION
        || value["required_normalized_report_schema"] != REPORT_SCHEMA
        || value["required_command_validation"]["schema_version"] != COMMAND_VALIDATION_SCHEMA
        || value["required_command_validation"]["normalized_validation_mode"]
            != NORMALIZED_VALIDATION_MODE
        || value["required_command_validation"]["heading_command_conditioned_entire_schedule"]
            != true
        || value["required_command_validation"]["legacy_command_parity_applicable"] != false
        || value["required_command_validation"]["legacy_command_parity_checked_step_count"] != 0
        || value["required_command_validation"]["legacy_command_parity_waived_step_count"] != 0
        || !engine_ids_exact
        || !engine.is_some_and(|engine| {
            engine["host_binding_status"] == "actual_route_zero_world_commissioned"
                && engine["actual_worker_path"]
                    == "sdk/adapters/rapier/src/bin/qsdk_r23d1_heading_response.rs"
                && engine["actual_route_preflight_path"]
                    == "sdk/run_qsdk_r23d1_rapier_worker_preflight.ps1"
                && engine["actual_route_zero_world_commissioned"] == true
        })
        || value["arms"]
            != json!([
                {
                    "arm_id": "reference_zero",
                    "turn_heading_offset_rad": 0.0,
                    "role": "zero_command_straight_walk_compatibility",
                },
                {
                    "arm_id": "positive_heading",
                    "turn_heading_offset_rad": 0.2,
                    "role": "positive_signed_heading_response",
                },
                {
                    "arm_id": "negative_heading",
                    "turn_heading_offset_rad": -0.2,
                    "role": "negative_signed_heading_response",
                },
            ])
        || value["cell_matrix"]["declared_cell_count"] != 9
        || value["cell_matrix"]["worlds_per_cell"] != 1
        || value["cell_matrix"]["execution_order"] != "engine_order_then_arm_order"
        || value["cell_matrix"]["parallel_execution_permitted"] != false
        || value["cell_matrix"]["replacement_or_selective_rerun_permitted"] != false
        || value["command_schedule"]["schedule_id"] != SCHEDULE_ID
        || value["command_schedule"]["domain"] != "controller_semantic_step"
        || value["command_schedule"]["minimum_required_controller_step_count"]
            != DECLARED_SCHEDULE_END_STEP_EXCLUSIVE
        || value["command_schedule"]["after_last_segment"] != "hold_reference_heading"
        || value["command_schedule"]["segments"]
            != json!([
                {
                    "segment_id": "reference_warmup",
                    "start_step_inclusive": 0,
                    "end_step_exclusive": TURN_START_STEP,
                    "heading_offset_source": "zero",
                },
                {
                    "segment_id": "commanded_turn",
                    "start_step_inclusive": TURN_START_STEP,
                    "end_step_exclusive": TURN_END_STEP_EXCLUSIVE,
                    "heading_offset_source": "arm.turn_heading_offset_rad",
                },
                {
                    "segment_id": "reference_recovery",
                    "start_step_inclusive": TURN_END_STEP_EXCLUSIVE,
                    "end_step_exclusive": DECLARED_SCHEDULE_END_STEP_EXCLUSIVE,
                    "heading_offset_source": "zero",
                },
            ])
        || value["command_schedule"]["expected_segment_sample_counts"]
            != json!({
                "reference_warmup": TURN_START_STEP,
                "commanded_turn": TURN_END_STEP_EXCLUSIVE - TURN_START_STEP,
                "reference_recovery":
                    DECLARED_SCHEDULE_END_STEP_EXCLUSIVE - TURN_END_STEP_EXCLUSIVE,
            })
        || value["development_detection_gates"]["maximum_absolute_requested_or_held_steering_fraction"]
            != MAXIMUM_STEERING_FRACTION
        || value["development_detection_gates"]["minimum_absolute_signed_turn_phase_yaw_delta_rad"]
            != MINIMUM_ABSOLUTE_TURN_PHASE_YAW_DELTA_RAD
        || value["development_detection_gates"]["minimum_final_forward_displacement_m"]
            != MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
        || value["development_detection_gates"]["maximum_tilt_rad"] != MAXIMUM_TILT_RAD
        || value["development_detection_gates"]["minimum_torso_height_m"] != MINIMUM_TORSO_HEIGHT_M
        || value["development_detection_gates"]["minimum_contact_cycles_per_limb"]
            != MINIMUM_CONTACT_CYCLES_PER_LIMB
        || value["development_detection_gates"]["zero_torso_ground_contact_required"] != true
        || value["development_detection_gates"]["zero_command_requires_engine_production_straight_walking_gate"]
            != true
        || value["development_detection_gates"]["turn_arms_require_forward_contact_and_stability_gates"]
            != true
        || value["development_detection_gates"]["recovery_heading_is_measured_but_not_thresholded"]
            != true
    {
        return Err("QSDK_R23D1_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(value)
}

fn initial_perturbation(contract: &Value) -> Result<InitialPerturbation, String> {
    let value = &contract["fixture"]["initial_perturbation"];
    let linear = exact_f64_array(value.get("initial_linear_velocity_world_m_s"), 3)?;
    let angular = exact_f64_array(value.get("initial_torso_angular_velocity_world_rad_s"), 3)?;
    let perturbation = InitialPerturbation {
        vertical_clearance_m: value["fixture_vertical_clearance_m"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D1_RAP_VERTICAL_CLEARANCE_INVALID".to_owned())?,
        yaw_rad: value["fixture_yaw_rad"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D1_RAP_FIXTURE_YAW_INVALID".to_owned())?,
        linear_velocity_world_m_s: [linear[0], linear[1], linear[2]],
        torso_angular_velocity_world_rad_s: [angular[0], angular[1], angular[2]],
        gait_phase_offset_ticks: value["gait_phase_offset_ticks"]
            .as_i64()
            .ok_or_else(|| "QSDK_R23D1_RAP_PHASE_OFFSET_INVALID".to_owned())?,
    };
    if value["campaign_seed"] != CAMPAIGN_SEED
        || !perturbation.vertical_clearance_m.is_finite()
        || perturbation.vertical_clearance_m < 0.0
        || !perturbation.yaw_rad.is_finite()
        || perturbation
            .linear_velocity_world_m_s
            .into_iter()
            .any(|item| !item.is_finite())
        || perturbation
            .torso_angular_velocity_world_rad_s
            .into_iter()
            .any(|item| !item.is_finite())
        || perturbation.gait_phase_offset_ticks.abs() > 3
    {
        return Err("QSDK_R23D1_RAP_INITIAL_PERTURBATION_INVALID".to_owned());
    }
    Ok(perturbation)
}

fn exact_f64_array(value: Option<&Value>, length: usize) -> Result<Vec<f64>, String> {
    let values = value
        .and_then(Value::as_array)
        .ok_or_else(|| "QSDK_R23D1_RAP_PERTURBATION_VECTOR_INVALID".to_owned())?;
    if values.len() != length {
        return Err("QSDK_R23D1_RAP_PERTURBATION_VECTOR_INVALID".to_owned());
    }
    values
        .iter()
        .map(|item| {
            item.as_f64()
                .filter(|number| number.is_finite())
                .ok_or_else(|| "QSDK_R23D1_RAP_PERTURBATION_VECTOR_INVALID".to_owned())
        })
        .collect()
}

fn arm_offset(contract: &Value, arm_id: &str) -> Result<f64, String> {
    contract["arms"]
        .as_array()
        .and_then(|arms| {
            arms.iter()
                .find(|arm| arm["arm_id"] == arm_id)
                .and_then(|arm| arm["turn_heading_offset_rad"].as_f64())
        })
        .ok_or_else(|| format!("QSDK_R23D1_RAP_ARM_UNKNOWN:{arm_id}"))
}

fn compile_boundary() -> Result<
    (
        sporespore_locomotion_core::CompiledQuadruped,
        BalancedWaveController,
    ),
    String,
> {
    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller =
        BalancedWaveController::new_for_policy(compiled.clone(), SELECTED_BALANCED_WAVE_POLICY_ID)
            .map_err(|error| error.to_string())?;
    if compiled.world_build_count != 0
        || compiled.morphology.world_build_count != 0
        || compiled.morphology_id != MORPHOLOGY_ID
        || controller.profile().policy_id != POLICY_ID
    {
        return Err("QSDK_R23D1_RAP_PORTABLE_BOUNDARY_INVALID".to_owned());
    }
    Ok((compiled, controller))
}

fn wrap_angle(value: f64) -> f64 {
    (value + std::f64::consts::PI).rem_euclid(std::f64::consts::TAU) - std::f64::consts::PI
}

fn heading_command_receipt(
    semantic_step: u64,
    reference_heading_rad: f64,
    turn_heading_offset_rad: f64,
) -> HeadingCommandReceipt {
    let (segment_id, command_role, offset, declared_segment) = match semantic_step {
        0..TURN_START_STEP => ("reference_warmup", "reference_heading", 0.0, true),
        TURN_START_STEP..TURN_END_STEP_EXCLUSIVE => (
            "commanded_turn",
            "turn_heading",
            turn_heading_offset_rad,
            true,
        ),
        TURN_END_STEP_EXCLUSIVE..DECLARED_SCHEDULE_END_STEP_EXCLUSIVE => {
            ("reference_recovery", "reference_heading", 0.0, true)
        }
        _ => ("after_schedule", "reference_heading", 0.0, false),
    };
    HeadingCommandReceipt {
        segment_id,
        command_role,
        heading_offset_rad: offset,
        desired_heading_rad: wrap_angle(reference_heading_rad + offset),
        declared_segment,
    }
}

fn motion_command(
    semantic_step: u64,
    phase_progression_mode: PhaseProgressionMode,
    receipt: &HeadingCommandReceipt,
) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("{SCHEDULE_ID}_{}", receipt.segment_id),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(receipt.desired_heading_rad),
        desired_yaw_rate_rad_s: None,
        gait_family_id: "lateral_wave".to_owned(),
        speed_class: SpeedClass::Walk,
        gait_amplitude: 1.0,
        phase_progression_mode,
        valid_from_step: semantic_step,
        valid_through_step: semantic_step,
        authority: CommandAuthority::TestFixture,
    }
}

fn zero_residuals(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Vec<CanonicalVelocityResidualV1> {
    compiled
        .morphology
        .ordered_actuator_ids
        .iter()
        .map(CanonicalVelocityResidualV1::exact_zero)
        .collect()
}

fn validate_native_step(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    semantic_step: u64,
    receipt: &HeadingCommandReceipt,
    output: &sporespore_locomotion_core::BalancedWaveControllerStepOutput,
) -> Result<sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1, String> {
    output
        .actuation
        .validate(&compiled.morphology)
        .map_err(|error| format!("QSDK_R23D1_RAP_ACTUATION_INVALID:{error}"))?;
    let controller_receipt = &output.actuation.receipt;
    if output.actuation.safe_no_actuation
        || !output.actuation.failure_codes.is_empty()
        || controller_receipt.controller_error.is_some()
        || controller_receipt.policy_id != POLICY_ID
        || controller_receipt.semantic_step != semantic_step
        || controller_receipt.command_id != format!("{SCHEDULE_ID}_{}", receipt.segment_id)
        || controller_receipt.world_build_count != 0
        || controller_receipt.physical_acceptance_authority
        || (controller_receipt.desired_heading_error_rad - receipt.heading_offset_rad).abs()
            > 1.0e-12
        || !controller_receipt.requested_steering_fraction.is_finite()
        || !controller_receipt.held_steering_fraction.is_finite()
        || controller_receipt.requested_steering_fraction.abs() > MAXIMUM_STEERING_FRACTION
        || controller_receipt.held_steering_fraction.abs() > MAXIMUM_STEERING_FRACTION
    {
        return Err("QSDK_R23D1_RAP_CONTROLLER_RECEIPT_INVALID".to_owned());
    }
    let (canonical, mapping) =
        map_bw19v_velocity_only_v4(compiled, &output.actuation, &zero_residuals(compiled))?;
    let profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    mapping
        .validate(&compiled.morphology, &canonical, &profile)
        .map_err(|error| format!("QSDK_R23D1_RAP_HOST_MAPPING_INVALID:{error}"))?;
    if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
        || mapping.semantic_step != semantic_step
        || mapping.independent_native_position_feedback_applied
        || mapping.native_position_stiffness != 0.0
        || mapping.ordered_commands.len() != 8
        || mapping
            .ordered_commands
            .iter()
            .any(|command| command.native_target_position_rad.is_some() || command.host_clamped)
    {
        return Err("QSDK_R23D1_RAP_NATIVE_MAPPING_BOUNDARY_INVALID".to_owned());
    }
    Ok(mapping)
}

fn json_initial_perturbation(value: InitialPerturbation) -> Value {
    json!({
        "campaign_seed": CAMPAIGN_SEED,
        "fixture_vertical_clearance_m": value.vertical_clearance_m,
        "fixture_yaw_rad": value.yaw_rad,
        "initial_linear_velocity_world_m_s": value.linear_velocity_world_m_s,
        "initial_torso_angular_velocity_world_rad_s":
            value.torso_angular_velocity_world_rad_s,
        "gait_phase_offset_ticks": value.gait_phase_offset_ticks,
    })
}

fn perfect_normalized_report(
    contract: &Value,
    arm_id: &str,
    turn_heading_offset_rad: f64,
) -> Value {
    let signed_yaw = if turn_heading_offset_rad == 0.0 {
        0.0
    } else {
        turn_heading_offset_rad.signum() * 0.02
    };
    let mean_turn = -1.3 * turn_heading_offset_rad;
    json!({
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "cell_id": format!("{ENGINE_ID}__{arm_id}"),
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "contract_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "source_commit": "0000000000000000000000000000000000000000",
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "validated_portable_command_count": CONTROLLER_STEPS * 8,
            "native_actuation_application_count": CONTROLLER_STEPS * 8,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
            "source_validation_mode": SOURCE_VALIDATION_MODE,
            "native_validation_step_count": CONTROLLER_STEPS,
            "heading_command_conditioned_step_count": CONTROLLER_STEPS,
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": false,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
        },
        "schedule": {
            "schedule_id": SCHEDULE_ID,
            "observed_segment_sample_counts": {
                "reference_warmup": 600,
                "commanded_turn": 1200,
                "reference_recovery": 600,
            },
            "turn_heading_offset_rad": turn_heading_offset_rad,
            "reference_heading_sample_count": 1200,
            "turn_heading_sample_count": 1200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction": mean_turn.abs(),
            "maximum_absolute_held_steering_fraction": mean_turn.abs(),
            "mean_turn_held_steering_fraction": mean_turn,
        },
        "physics": {
            "turn_phase_yaw_delta_rad": signed_yaw,
            "final_reference_heading_error_rad": 0.0,
            "final_forward_displacement_m": 0.1,
            "maximum_tilt_rad": 0.1,
            "minimum_torso_height_m": 0.3,
            "torso_ground_contact_step_count": 0,
            "contact_cycles_by_limb": {
                "front_left": 2,
                "front_right": 2,
                "rear_left": 2,
                "rear_right": 2,
            },
            "engine_production_straight_walking_gate_passed": true,
            "commanded_turn_walk_gate_passed": true,
        },
        "host": {
            "adapter_id": ADAPTER_ID,
            "adapter_capability_sha256": capability_manifest_sha256(),
            "engine_version": rapier3d::VERSION,
            "velocity_only_profile_id": RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID,
            "synthetic_preflight_only": true,
        },
        "claims": {
            "development_screen_only": true,
            "q_sdk_r23_satisfied": false,
            "command_conditioned_turning": false,
            "cross_engine_equivalence": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
        },
        "physical_acceptance_authority": false,
        "contract_physical_execution_authorized":
            contract["authorization"]["physical_execution_authorized"],
    })
}

pub fn run_qsdk_r23d1_rapier_preflight(arm_id: &str) -> Result<Value, String> {
    let contract = contract()?;
    let perturbation = initial_perturbation(&contract)?;
    let turn_heading_offset_rad = arm_offset(&contract, arm_id)?;
    let (compiled, controller) = compile_boundary()?;
    let reference_heading_rad = 0.17;
    let mut state = synthetic_state_frame(
        &compiled,
        Quaternion {
            x: 0.0,
            y: -(reference_heading_rad * 0.5).sin(),
            z: 0.0,
            w: (reference_heading_rad * 0.5).cos(),
        },
    );
    let semantic_step = if arm_id == "reference_zero" {
        0
    } else {
        TURN_START_STEP
    };
    state.semantic_step = semantic_step;
    state.sample_time_s = semantic_step as f64 / PHYSICS_HZ as f64;
    state.task_frame.reference_yaw_rad = reference_heading_rad;
    state.task_frame.forward_axis_world_unit = Vec3 {
        x: reference_heading_rad.cos(),
        y: 0.0,
        z: reference_heading_rad.sin(),
    };
    state.task_frame.lateral_axis_world_unit = Vec3 {
        x: -reference_heading_rad.sin(),
        y: 0.0,
        z: reference_heading_rad.cos(),
    };
    let heading = heading_command_receipt(
        semantic_step,
        reference_heading_rad,
        turn_heading_offset_rad,
    );
    let command = motion_command(semantic_step, PhaseProgressionMode::Clocked, &heading);
    let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
    let mapping = validate_native_step(&compiled, semantic_step, &heading, &output)?;
    let production_report = perfect_normalized_report(&contract, arm_id, turn_heading_offset_rad);
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d1_rapier_worker_preflight_v1",
        "ok": true,
        "failure_code": "",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "cell_id": format!("{ENGINE_ID}__{arm_id}"),
        "campaign_seed": CAMPAIGN_SEED,
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "contract_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "initial_perturbation": json_initial_perturbation(perturbation),
        "turn_heading_offset_rad": turn_heading_offset_rad,
        "native_heading_preflight": {
            "command_role": heading.command_role,
            "native_controller_step_passed": true,
            "native_controller_command_count": output.actuation.ordered_commands.len(),
            "native_controller_command_order_exact": output
                .actuation
                .ordered_commands
                .iter()
                .map(|command| command.actuator_id.as_str())
                .eq(compiled.morphology.ordered_actuator_ids.iter().map(String::as_str)),
            "native_next_memory_exact": output.next_memory.last_semantic_step == Some(semantic_step)
                && output.next_memory.held_path_steering_fraction.is_finite()
                && output.next_memory.ordered_limb_memory.iter()
                    .map(|memory| memory.limb_id.as_str())
                    .eq(["rear_left", "front_left", "rear_right", "front_right"]),
            "controller_receipt": output.actuation.receipt,
            "host_mapping": mapping,
            "command_validation_receipt": {
                "schema_version": "sporespore_balanced_wave_command_validation_receipt_v1",
                "ok": true,
                "enabled": true,
                "validation_mode": SOURCE_VALIDATION_MODE,
                "heading_command_conditioned": true,
                "legacy_command_parity_applicable": false,
                "legacy_command_parity_checked": false,
                "legacy_command_parity_waived": false,
                "world_build_count": 0,
                "physics_state_modified": false,
                "physical_acceptance_authority": false,
            },
            "actual_world_build_count": 0,
            "physics_state_modified": false,
            "locomotion_outcome_exposed": false,
            "physical_acceptance_authority": false,
        },
        "production_normalized_report": production_report,
        "entrypoint_control_flow_complete": true,
        "actual_world_build_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "physical_execution_authorized": false,
        "q_sdk_r23_satisfied": false,
        "physical_acceptance_authority": false,
    }))
}

fn yaw_rad(robot: &HostRobot) -> f64 {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let forward = torso.rotation() * Vector::X;
    (forward.z as f64).atan2(forward.x as f64)
}

fn apply_initial_perturbation(
    robot: &mut HostRobot,
    perturbation: InitialPerturbation,
) -> Result<(), String> {
    let rotation = Rotation::from_rotation_y(perturbation.yaw_rad as f32);
    let handles = robot.bodies.values().copied().collect::<Vec<_>>();
    for handle in handles {
        let body = &mut robot.world.bodies[handle];
        let rotated_translation = rotation * body.translation()
            + Vector::new(0.0, perturbation.vertical_clearance_m as f32, 0.0);
        let rotated_orientation = rotation * *body.rotation();
        body.set_translation(rotated_translation, true);
        body.set_rotation(rotated_orientation, true);
        body.set_linvel(
            Vector::new(
                perturbation.linear_velocity_world_m_s[0] as f32,
                perturbation.linear_velocity_world_m_s[1] as f32,
                perturbation.linear_velocity_world_m_s[2] as f32,
            ),
            true,
        );
    }
    let torso = robot
        .bodies
        .get("torso")
        .copied()
        .ok_or_else(|| "QSDK_R23D1_RAP_TORSO_HANDLE_MISSING".to_owned())?;
    robot.world.bodies[torso].set_angvel(
        Vector::new(
            perturbation.torso_angular_velocity_world_rad_s[0] as f32,
            perturbation.torso_angular_velocity_world_rad_s[1] as f32,
            perturbation.torso_angular_velocity_world_rad_s[2] as f32,
        ),
        true,
    );
    Ok(())
}

fn state_frame(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    semantic_step: u64,
    task_origin: Vector,
    reference_heading_rad: f64,
) -> Result<sporespore_locomotion_core::StateFrame, String> {
    let mut state = robot.state_frame(compiled, semantic_step, task_origin)?;
    state.task_frame.reference_yaw_rad = reference_heading_rad;
    state.task_frame.forward_axis_world_unit = Vec3 {
        x: reference_heading_rad.cos(),
        y: 0.0,
        z: reference_heading_rad.sin(),
    };
    state.task_frame.lateral_axis_world_unit = Vec3 {
        x: -reference_heading_rad.sin(),
        y: 0.0,
        z: reference_heading_rad.cos(),
    };
    Ok(state)
}

fn apply_phase_offset(
    memory: &mut BalancedWaveControllerMemory,
    requested_offset_ticks: i64,
) -> Result<Value, String> {
    if requested_offset_ticks.abs() > 3 || memory.ordered_limb_memory.len() != 4 {
        return Err("QSDK_R23D1_RAP_PHASE_OFFSET_INVALID".to_owned());
    }
    let minimum_raw = memory
        .ordered_limb_memory
        .iter()
        .map(|limb| limb.gait_step as i64 + requested_offset_ticks)
        .min()
        .ok_or_else(|| "QSDK_R23D1_RAP_PHASE_MEMORY_EMPTY".to_owned())?;
    let mut representation_shift_ticks = 0_i64;
    while minimum_raw + representation_shift_ticks < 0 {
        representation_shift_ticks += 360;
    }
    for limb in &mut memory.ordered_limb_memory {
        let updated = limb.gait_step as i64 + requested_offset_ticks + representation_shift_ticks;
        limb.gait_step = u64::try_from(updated)
            .map_err(|_| "QSDK_R23D1_RAP_PHASE_OFFSET_UNDERFLOW".to_owned())?;
    }
    Ok(json!({
        "schema_version": "sporespore_sdk_phase_offset_synchronization_receipt_v2",
        "scheduled": true,
        "requested_offset_ticks": requested_offset_ticks,
        "activation_semantic_step": PHASE_OFFSET_ACTIVATION_STEP,
        "application_count": 1,
        "synchronized_limb_count": 4,
        "gait_step_representation": "nonnegative_u64_cycle_epoch",
        "cycle_steps": 360,
        "common_representation_shift_ticks": representation_shift_ticks,
    }))
}

fn physical_authorization_exact(
    contract: &Value,
    arm_id: &str,
    source_commit: &str,
) -> Result<(), String> {
    if contract["authorization"]["physical_execution_authorized"] != true {
        return Err("QSDK_R23D1_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let attempt_path = env::var(ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(AUTHORIZATION_TOKEN_ENV).unwrap_or_default();
    let cell_id = format!("{ENGINE_ID}__{arm_id}");
    if attempt_path.is_empty()
        || !valid_lower_hex(&token, 32)
        || env::var(CELL_ID_ENV).unwrap_or_default() != cell_id
        || env::var(ENGINE_ID_ENV).unwrap_or_default() != ENGINE_ID
    {
        return Err("QSDK_R23D1_RAP_SUPERVISOR_AUTHORIZATION_INVALID".to_owned());
    }
    let attempt_raw = fs::read_to_string(&attempt_path)
        .map_err(|_| "QSDK_R23D1_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let attempt: Value = serde_json::from_str(&attempt_raw)
        .map_err(|_| "QSDK_R23D1_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let exact = attempt["schema_version"] == "sporespore_qsdk_r23d1_attempt_v1"
        && attempt["campaign_id"] == CAMPAIGN_ID
        && attempt["gate_id"] == GATE_ID
        && attempt["contract_sha256"] == raw_sha256(CONTRACT_RAW.as_bytes())
        && attempt["source_commit"] == source_commit
        && attempt["origin_main_commit"] == source_commit
        && attempt["live_main_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && attempt["ordered_cell_ids"]
            == json!([
                "godot_jolt__reference_zero",
                "godot_jolt__positive_heading",
                "godot_jolt__negative_heading",
                "rapier_parry__reference_zero",
                "rapier_parry__positive_heading",
                "rapier_parry__negative_heading",
                "mujoco__reference_zero",
                "mujoco__positive_heading",
                "mujoco__negative_heading",
            ]);
    if !exact {
        return Err("QSDK_R23D1_RAP_ATTEMPT_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(())
}

fn valid_lower_hex(value: &str, expected_length: usize) -> bool {
    value.len() == expected_length
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

pub fn run_qsdk_r23d1_rapier_physical(arm_id: &str, source_commit: &str) -> Result<Value, String> {
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D1_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    if PHYSICAL_IDENTITY_CLOSED {
        return Err("QSDK_R23D1_RAP_PHYSICAL_IDENTITY_CLOSED".to_owned());
    }
    let contract = contract()?;
    let turn_heading_offset_rad = arm_offset(&contract, arm_id)?;
    physical_authorization_exact(&contract, arm_id, source_commit)?;
    let perturbation = initial_perturbation(&contract)?;
    let preflight = run_qsdk_r23d1_rapier_preflight(arm_id)?;
    let (compiled, controller) = compile_boundary()?;
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)?;
    apply_initial_perturbation(&mut robot, perturbation)?;
    for _ in 0..SETTLE_STEPS {
        robot.hold_velocity_only_v4_zero_and_step()?;
    }
    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = robot.contacts(&compiled);
    let mut foot_evidence = BTreeMap::<String, FootEvidence>::new();
    for limb in &compiled.morphology.morphology_spec.limbs {
        let site_id = &limb.ordered_contact_site_ids[0];
        foot_evidence.insert(
            limb.limb_id.clone(),
            FootEvidence::new(*initial_contacts.get(site_id).unwrap_or(&false)),
        );
    }

    let mut memory = BalancedWaveControllerMemory::initial();
    let mut phase_offset_receipt = Value::Null;
    let mut controller_error_count = 0_u64;
    let mut safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut portable_command_count = 0_u64;
    let mut native_application_count = 0_u64;
    let mut native_validation_step_count = 0_u64;
    let mut heading_conditioned_step_count = 0_u64;
    let mut small_step_impulse_limit_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_anchor_error_m = 0.0_f64;
    let mut maximum_hinge_axis_error_rad = 0.0_f64;
    let mut maximum_absolute_requested_steering_fraction = 0.0_f64;
    let mut maximum_absolute_held_steering_fraction = 0.0_f64;
    let mut turn_held_steering_sum = 0.0_f64;
    let mut turn_held_steering_count = 0_u64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut segment_counts = BTreeMap::from([
        ("reference_warmup", 0_u64),
        ("commanded_turn", 0_u64),
        ("reference_recovery", 0_u64),
    ]);

    for semantic_step in 0..CONTROLLER_STEPS {
        if semantic_step == PHASE_OFFSET_ACTIVATION_STEP {
            phase_offset_receipt =
                apply_phase_offset(&mut memory, perturbation.gait_phase_offset_ticks)?;
        }
        if semantic_step == CONTACT_GATED_START_STEP {
            for limb in &mut memory.ordered_limb_memory {
                limb.evidence_gait_step_limit = Some(limb.gait_step + 1 + 1_440);
            }
        }
        let phase_mode = if semantic_step < CONTACT_GATED_START_STEP {
            PhaseProgressionMode::Clocked
        } else {
            PhaseProgressionMode::ContactGated
        };
        let state = state_frame(
            &robot,
            &compiled,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let heading = heading_command_receipt(
            semantic_step,
            reference_heading_rad,
            turn_heading_offset_rad,
        );
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        if heading.declared_segment {
            *segment_counts
                .get_mut(heading.segment_id)
                .ok_or_else(|| "QSDK_R23D1_RAP_SEGMENT_UNKNOWN".to_owned())? += 1;
        }
        let command = motion_command(semantic_step, phase_mode, &heading);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        let mapping = validate_native_step(&compiled, semantic_step, &heading, &output)?;
        let requested = output.actuation.receipt.requested_steering_fraction;
        let held = output.actuation.receipt.held_steering_fraction;
        maximum_absolute_requested_steering_fraction =
            maximum_absolute_requested_steering_fraction.max(requested.abs());
        maximum_absolute_held_steering_fraction =
            maximum_absolute_held_steering_fraction.max(held.abs());
        if (TURN_START_STEP..TURN_END_STEP_EXCLUSIVE).contains(&semantic_step) {
            turn_held_steering_sum += held;
            turn_held_steering_count += 1;
        }
        portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) =
            robot.apply_bw19v_velocity_only_v4_actuation(&mapping)?;
        native_application_count += applications;
        small_step_impulse_limit_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != 8);
        if applications == 8 && impulse_violations == 0 {
            native_validation_step_count += 1;
            heading_conditioned_step_count += 1;
        }
        memory = output.next_memory;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        let (anchor_error, axis_error) = robot.structural_metrics(&compiled)?;
        maximum_anchor_error_m = maximum_anchor_error_m.max(anchor_error);
        maximum_hinge_axis_error_rad = maximum_hinge_axis_error_rad.max(axis_error);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        if semantic_step >= CONTACT_GATED_START_STEP {
            for limb in &compiled.morphology.morphology_spec.limbs {
                let site = compiled
                    .morphology
                    .morphology_spec
                    .contact_sites
                    .iter()
                    .find(|site| site.contact_site_id == limb.ordered_contact_site_ids[0])
                    .ok_or_else(|| "QSDK_R23D1_RAP_CONTACT_SITE_MISSING".to_owned())?;
                foot_evidence
                    .get_mut(&limb.limb_id)
                    .ok_or_else(|| "QSDK_R23D1_RAP_FOOT_EVIDENCE_MISSING".to_owned())?
                    .observe(
                        robot.contact(&site.body_id),
                        robot.contact_site_position(site),
                    );
            }
        }
    }

    for _ in 0..TERMINAL_SETTLE_STEPS {
        robot.hold_velocity_only_v4_zero_and_step()?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let final_reference_heading_error_rad = wrap_angle(yaw_rad(&robot) - reference_heading_rad);
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .unwrap_or(f64::NAN);
    let mean_turn_held_steering_fraction = if turn_held_steering_count == 0 {
        f64::NAN
    } else {
        turn_held_steering_sum / turn_held_steering_count as f64
    };
    let contact_cycles_by_limb = foot_evidence
        .iter()
        .map(|(limb_id, evidence)| (limb_id.clone(), json!(evidence.contact_cycles)))
        .collect::<serde_json::Map<_, _>>();
    let contacts_pass = foot_evidence
        .values()
        .all(|evidence| evidence.contact_cycles >= MINIMUM_CONTACT_CYCLES_PER_LIMB);
    let integrity_pass = controller_error_count == 0
        && safe_no_actuation_count == 0
        && nonfinite_observation_count == 0
        && actuator_application_mismatch_count == 0
        && small_step_impulse_limit_violation_count == 0
        && portable_command_count == CONTROLLER_STEPS * 8
        && native_application_count == CONTROLLER_STEPS * 8
        && native_validation_step_count == CONTROLLER_STEPS
        && heading_conditioned_step_count == CONTROLLER_STEPS;
    let walking_gate = integrity_pass
        && torso_ground_contact_step_count == 0
        && maximum_tilt_rad <= MAXIMUM_TILT_RAD
        && minimum_torso_height_m >= MINIMUM_TORSO_HEIGHT_M
        && final_forward_displacement_m >= MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
        && contacts_pass;

    Ok(json!({
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "cell_id": format!("{ENGINE_ID}__{arm_id}"),
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "contract_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "source_commit": source_commit,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": controller_error_count,
            "safe_no_actuation_count": safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "validated_portable_command_count": portable_command_count,
            "native_actuation_application_count": native_application_count,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
            "source_validation_mode": SOURCE_VALIDATION_MODE,
            "native_validation_step_count": native_validation_step_count,
            "heading_command_conditioned_step_count": heading_conditioned_step_count,
            "unconditioned_step_count": CONTROLLER_STEPS - heading_conditioned_step_count,
            "legacy_command_parity_applicable": false,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
        },
        "schedule": {
            "schedule_id": SCHEDULE_ID,
            "observed_segment_sample_counts": segment_counts,
            "turn_heading_offset_rad": turn_heading_offset_rad,
            "reference_heading_sample_count": 1200,
            "turn_heading_sample_count": 1200,
            "phase_offset_synchronization_receipt": phase_offset_receipt,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction":
                maximum_absolute_requested_steering_fraction,
            "maximum_absolute_held_steering_fraction":
                maximum_absolute_held_steering_fraction,
            "mean_turn_held_steering_fraction": mean_turn_held_steering_fraction,
        },
        "physics": {
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "final_reference_heading_error_rad": final_reference_heading_error_rad,
            "final_forward_displacement_m": final_forward_displacement_m,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "maximum_anchor_error_m": maximum_anchor_error_m,
            "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "contact_cycles_by_limb": Value::Object(contact_cycles_by_limb),
            "engine_production_straight_walking_gate_passed": walking_gate,
            "commanded_turn_walk_gate_passed": walking_gate,
        },
        "host": {
            "adapter_id": ADAPTER_ID,
            "adapter_capability_sha256": capability_manifest_sha256(),
            "engine_version": rapier3d::VERSION,
            "physics_hz": PHYSICS_HZ,
            "outer_timestep_s": RAPIER_DT_S,
            "authored_friction": AUTHORED_FRICTION,
            "velocity_only_profile_id": RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID,
            "native_motor_model_id": "ForceBased",
            "native_position_target_application_count": 0,
            "small_step_impulse_limit_violation_count":
                small_step_impulse_limit_violation_count,
            "initial_perturbation": json_initial_perturbation(perturbation),
            "preflight": preflight,
        },
        "claims": {
            "development_screen_only": true,
            "q_sdk_r23_satisfied": false,
            "command_conditioned_turning": false,
            "cross_engine_equivalence": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
        },
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_arms_cross_native_zero_world_preflight() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let report = run_qsdk_r23d1_rapier_preflight(arm_id).unwrap();
            assert_eq!(report["ok"], true);
            assert_eq!(report["actual_world_build_count"], 0);
            assert_eq!(
                report["native_heading_preflight"]["host_mapping"]["host_profile_id"],
                RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
            );
            assert_eq!(
                report["native_heading_preflight"]["command_validation_receipt"]["legacy_command_parity_waived"],
                false
            );
            assert_eq!(
                report["production_normalized_report"]["schema_version"],
                REPORT_SCHEMA
            );
        }
    }

    #[test]
    fn unknown_arm_and_direct_physical_bypass_fail_closed() {
        assert!(run_qsdk_r23d1_rapier_preflight("unknown").is_err());
        let error = run_qsdk_r23d1_rapier_physical(
            "reference_zero",
            "0000000000000000000000000000000000000000",
        )
        .unwrap_err();
        assert_eq!(error, "QSDK_R23D1_RAP_PHYSICAL_IDENTITY_CLOSED");
    }
}
