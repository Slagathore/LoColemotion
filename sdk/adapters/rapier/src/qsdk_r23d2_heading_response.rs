use std::{collections::BTreeMap, env, fs};

use rapier3d::prelude::*;
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{
    ActuationFrame, CommandAuthority, ControllerStepReceipt, MOTION_COMMAND_VERSION, MotionCommand,
    PhaseProgressionMode, Quaternion, SpeedClass,
};
use sporespore_locomotion_core::schema::Vec3;
use sporespore_locomotion_core::{
    BalancedWaveController, BalancedWaveControllerMemory, BalancedWaveProfile,
    CanonicalVelocityResidualV1, RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID,
    SELECTED_BALANCED_WAVE_POLICY_ID, StateFrame, VelocityOnlyHostProfileV1,
    compile_bounded_quadruped,
};

use crate::{
    ADAPTER_ID,
    bw19v_composition::map_bw19v_velocity_only_v4,
    capability_manifest_sha256,
    locomotion::{
        FootEvidence, HostRobot, build_bw19v_velocity_only_v4_robot_with_friction, descriptor,
        state_contains_nonfinite, synthetic_state_frame,
    },
};

const ORACLE_RAW: &str = include_str!("../../../turning/r23d2_oracle_preregistration.json");
const WORKER_CONTRACT_RAW: &str =
    include_str!("../../../turning/r23d2_rapier_worker_contract_v1.json");
const DEVELOPMENT_CONTRACT_RAW: &str =
    include_str!("../../../turning/r23d2_development_contract_v1.json");
const CAMPAIGN_ID: &str = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT";
const GATE_ID: &str = "QSDK-R23D2-RAP";
const PARENT_GATE_ID: &str = "QSDK-R23D2";
const ENGINE_ID: &str = "rapier_parry";
// R23D2 consumed its sole shared aggregate identity. Keep the retained loop
// inspectable, but refuse before robot/world construction; new work is R23D3.
const PHYSICAL_IDENTITY_CLOSED: bool = true;
const POLICY_ID: &str = "sporespore_balanced_wave_bw5r_b_v1";
const POLICY_DIGEST: &str =
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f";
const MORPHOLOGY_ID: &str = "qsdk_r05_generated_s169";
const PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d2_rapier_worker_preflight_v1";
const REPORT_SCHEMA: &str = "sporespore_qsdk_r23d2_engine_cell_report_v1";
const WORKER_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d2_worker_failure_v1";
const COMMAND_VALIDATION_SCHEMA: &str = "sporespore_qsdk_r23d2_command_validation_v1";
const EXECUTION_STAGE_SCHEMA: &str = "sporespore_qsdk_r23d2_execution_stage_v1";
const NORMALIZED_VALIDATION_MODE: &str =
    "native_adapter_structure_receipts_and_independent_heading_oracle_v1";
const SOURCE_VALIDATION_MODE: &str =
    "rapier_force_based_velocity_only_mapping_receipt_and_independent_oracle_v1";
const SCHEDULE_ID: &str = "qsdk_r23d1_step_turn_return_v1";
const TOLERANCE: f64 = 1.0e-12;
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
const MINIMUM_FINAL_FORWARD_DISPLACEMENT_M: f64 = 0.030_123_046_875;
const MAXIMUM_TILT_RAD: f64 = 0.6;
const MINIMUM_TORSO_HEIGHT_M: f64 = 0.249_970_865_207_294_6;
const MINIMUM_CONTACT_CYCLES_PER_LIMB: u64 = 2;

const ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D2_ATTEMPT";
const AUTHORIZATION_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D2_TOKEN";
const CELL_ID_ENV: &str = "SPORESPORE_QSDK_R23D2_CELL";
const ENGINE_ID_ENV: &str = "SPORESPORE_QSDK_R23D2_ENGINE";

const RECEIPT_FIELDS: [&str; 5] = [
    "cross_track_error_m",
    "cross_track_velocity_m_s",
    "measured_yaw_error_rad",
    "desired_heading_error_rad",
    "yaw_tracking_error_rad",
];

#[derive(Debug, Clone, Copy)]
struct InitialPerturbation {
    vertical_clearance_m: f64,
    yaw_rad: f64,
    linear_velocity_world_m_s: [f64; 3],
    torso_angular_velocity_world_rad_s: [f64; 3],
    gait_phase_offset_ticks: i64,
}

#[derive(Debug, Clone)]
struct HeadingCommandSchedule {
    segment_id: &'static str,
    desired_heading_rad: f64,
    declared_segment: bool,
}

fn raw_sha256(bytes: &[u8]) -> String {
    format!("sha256:{:x}", Sha256::digest(bytes))
}

fn wrap_angle(value: f64) -> f64 {
    (value + std::f64::consts::PI).rem_euclid(std::f64::consts::TAU) - std::f64::consts::PI
}

fn f64_field(value: &Value, field: &str) -> Result<f64, String> {
    value[field]
        .as_f64()
        .filter(|number| number.is_finite())
        .ok_or_else(|| format!("QSDK_R23D2_RAP_{field}_INVALID"))
}

fn vec3_field(value: &Value, field: &str) -> Result<Vec3, String> {
    let array = value[field]
        .as_array()
        .filter(|array| array.len() == 3)
        .ok_or_else(|| format!("QSDK_R23D2_RAP_{field}_INVALID"))?;
    Ok(Vec3 {
        x: array[0]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| format!("QSDK_R23D2_RAP_{field}_INVALID"))?,
        y: array[1]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| format!("QSDK_R23D2_RAP_{field}_INVALID"))?,
        z: array[2]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| format!("QSDK_R23D2_RAP_{field}_INVALID"))?,
    })
}

fn dot(first: Vec3, second: Vec3) -> f64 {
    first.x * second.x + first.y * second.y + first.z * second.z
}

fn subtract(first: Vec3, second: Vec3) -> Vec3 {
    Vec3 {
        x: first.x - second.x,
        y: first.y - second.y,
        z: first.z - second.z,
    }
}

fn heading_quaternion(heading_rad: f64) -> Quaternion {
    Quaternion {
        x: 0.0,
        y: -(heading_rad * 0.5).sin(),
        z: 0.0,
        w: (heading_rad * 0.5).cos(),
    }
}

fn parse_contracts() -> Result<(Value, Value, Value), String> {
    let oracle: Value = serde_json::from_str(ORACLE_RAW)
        .map_err(|error| format!("QSDK_R23D2_RAP_ORACLE_JSON_INVALID:{error}"))?;
    let worker: Value = serde_json::from_str(WORKER_CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R23D2_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let development: Value = serde_json::from_str(DEVELOPMENT_CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R23D2_RAP_DEVELOPMENT_JSON_INVALID:{error}"))?;
    let development_engine = development["engines"].as_array().and_then(|engines| {
        engines
            .iter()
            .find(|engine| engine["engine_id"] == ENGINE_ID)
    });
    let exact = oracle["schema_version"] == "sporespore_qsdk_r23d2_oracle_preregistration_v1"
        && oracle["campaign_id"] == CAMPAIGN_ID
        && oracle["gate_id"] == PARENT_GATE_ID
        && oracle["authorization"]["physical_execution_authorized"] == false
        && oracle["oracle_canaries"]
            .as_array()
            .is_some_and(|values| values.len() == 7)
        && worker["schema_version"] == "sporespore_qsdk_r23d2_rapier_worker_contract_v1"
        && worker["status"] == "rapier_supervisor_only_physical_authorized"
        && worker["campaign_id"] == CAMPAIGN_ID
        && worker["gate_id"] == GATE_ID
        && worker["stage_zero_oracle"]["sha256"] == raw_sha256(ORACLE_RAW.as_bytes())
        && worker["engine"]["engine_id"] == ENGINE_ID
        && worker["engine"]["adapter_id"] == ADAPTER_ID
        && worker["engine"]["host_profile_id"] == RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
        && worker["worker"]["implementation_path"]
            == "sdk/adapters/rapier/src/qsdk_r23d2_heading_response.rs"
        && worker["worker"]["binary_path"]
            == "sdk/adapters/rapier/src/bin/qsdk_r23d2_heading_response.rs"
        && worker["worker"]["preflight_path"] == "sdk/run_qsdk_r23d2_rapier_worker_preflight.ps1"
        && worker["future_physical_requirements"]["physical_implementation_present"] == true
        && worker["future_physical_requirements"]["successful_report_canary_per_arm"] == true
        && worker["future_physical_requirements"]["all_six_failure_stage_canaries_per_arm"] == true
        && worker["authorization"]["physical_execution_authorized"] == true
        && worker["authorization"]["world_build_count"] == 0
        && development["schema_version"] == "sporespore_qsdk_r23d2_development_contract_v1"
        && development["status"]
            == "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation"
        && development["campaign_id"] == CAMPAIGN_ID
        && development["gate_id"] == PARENT_GATE_ID
        && development["source_contract"]["selected_policy_id"] == POLICY_ID
        && development["source_contract"]["selected_policy_digest"] == POLICY_DIGEST
        && development["fixture"]["morphology_id"] == MORPHOLOGY_ID
        && development["fixture"]["initial_condition_seed"] == CAMPAIGN_SEED
        && development["fixture"]["physics_hz"] == PHYSICS_HZ
        && development["fixture"]["authored_sliding_friction"] == AUTHORED_FRICTION
        && development_engine.is_some_and(|engine| {
            engine["worker_contract_sha256"] == raw_sha256(WORKER_CONTRACT_RAW.as_bytes())
                && engine["physical_implementation_present"] == true
        })
        && development["normalized_entry_contract"]["successful_report_schema_version"]
            == REPORT_SCHEMA
        && development["normalized_entry_contract"]["worker_failure_schema_version"]
            == WORKER_FAILURE_SCHEMA
        && development["normalized_entry_contract"]["command_validation_schema_version"]
            == COMMAND_VALIDATION_SCHEMA
        && development["normalized_entry_contract"]["execution_stage_schema_version"]
            == EXECUTION_STAGE_SCHEMA
        && development["normalized_entry_contract"]["normalized_validation_mode"]
            == NORMALIZED_VALIDATION_MODE
        && development["claim_boundary"]["physical_worker_implementation_count"] == 3
        && development["claim_boundary"]["physical_workers_complete"] == true
        && development["authorization"]["physical_execution_authorized"] == true;
    if !exact {
        return Err("QSDK_R23D2_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok((oracle, worker, development))
}

fn arm_offset(arm_id: &str) -> Result<f64, String> {
    match arm_id {
        "reference_zero" => Ok(0.0),
        "positive_heading" => Ok(0.2),
        "negative_heading" => Ok(-0.2),
        _ => Err(format!("QSDK_R23D2_RAP_ARM_UNKNOWN:{arm_id}")),
    }
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
        return Err("QSDK_R23D2_RAP_PORTABLE_BOUNDARY_INVALID".to_owned());
    }
    Ok((compiled, controller))
}

fn state_for_canary(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    canary: &Value,
) -> Result<StateFrame, String> {
    let measured_heading = f64_field(canary, "measured_heading_world_rad")?;
    let mut state = synthetic_state_frame(compiled, heading_quaternion(measured_heading));
    state.base_pose_world.position_m = vec3_field(canary, "base_position_world_m")?;
    state.base_twist_world.linear_velocity_m_s =
        vec3_field(canary, "base_linear_velocity_world_m_s")?;
    state.task_frame.origin_world_m = vec3_field(canary, "task_origin_world_m")?;
    state.task_frame.lateral_axis_world_unit = vec3_field(canary, "task_lateral_axis_world_unit")?;
    state.task_frame.reference_yaw_rad = f64_field(canary, "reference_yaw_rad")?;
    state
        .validate(&compiled.morphology)
        .map_err(|error| format!("QSDK_R23D2_RAP_STATE_INVALID:{error}"))?;
    Ok(state)
}

fn command_for_canary(canary_id: &str, canary: &Value) -> Result<MotionCommand, String> {
    Ok(MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("qsdk_r23d2_oracle_{canary_id}"),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(f64_field(canary, "desired_heading_rad")?),
        desired_yaw_rate_rad_s: None,
        gait_family_id: "lateral_wave".to_owned(),
        speed_class: SpeedClass::Walk,
        gait_amplitude: 1.0,
        phase_progression_mode: PhaseProgressionMode::Clocked,
        valid_from_step: 0,
        valid_through_step: 0,
        authority: CommandAuthority::TestFixture,
    })
}

fn command_for_arm_boundary(
    arm_id: &str,
    reference_yaw_rad: f64,
    arm_heading_offset_rad: f64,
) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("qsdk_r23d2_arm_boundary_{arm_id}"),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(reference_yaw_rad + arm_heading_offset_rad),
        desired_yaw_rate_rad_s: None,
        gait_family_id: "lateral_wave".to_owned(),
        speed_class: SpeedClass::Walk,
        gait_amplitude: 1.0,
        phase_progression_mode: PhaseProgressionMode::Clocked,
        valid_from_step: 0,
        valid_through_step: 0,
        authority: CommandAuthority::TestFixture,
    }
}

fn independent_oracle(
    state: &StateFrame,
    command: &MotionCommand,
    profile: &BalancedWaveProfile,
) -> Result<[f64; 5], String> {
    let displacement = subtract(
        state.base_pose_world.position_m,
        state.task_frame.origin_world_m,
    );
    let cross_track_error_m = dot(displacement, state.task_frame.lateral_axis_world_unit);
    let cross_track_velocity_m_s = dot(
        state.base_twist_world.linear_velocity_m_s,
        state.task_frame.lateral_axis_world_unit,
    );
    let measured_yaw_error_rad = wrap_angle(
        state
            .base_pose_world
            .orientation_xyzw
            .heading_x_forward_z_right_rad()
            - state.task_frame.reference_yaw_rad,
    );
    let requested_heading_error_rad = wrap_angle(
        command
            .desired_heading_rad
            .ok_or_else(|| "QSDK_R23D2_RAP_DESIRED_HEADING_MISSING".to_owned())?
            - state.task_frame.reference_yaw_rad,
    );
    let desired_heading_error_rad = (requested_heading_error_rad
        - profile.cross_track_heading_gain_rad_per_m * cross_track_error_m
        - profile.cross_track_velocity_heading_gain_rad_per_m_s * cross_track_velocity_m_s)
        .clamp(-0.25, 0.25);
    let yaw_tracking_error_rad = wrap_angle(measured_yaw_error_rad - desired_heading_error_rad);
    Ok([
        cross_track_error_m,
        cross_track_velocity_m_s,
        measured_yaw_error_rad,
        desired_heading_error_rad,
        yaw_tracking_error_rad,
    ])
}

fn receipt_values(receipt: &ControllerStepReceipt) -> [f64; 5] {
    [
        receipt.cross_track_error_m,
        receipt.cross_track_velocity_m_s,
        receipt.measured_yaw_error_rad,
        receipt.desired_heading_error_rad,
        receipt.yaw_tracking_error_rad,
    ]
}

fn predicate_failures(expected: [f64; 5], observed: [f64; 5]) -> Vec<String> {
    let mut failures = Vec::<String>::new();
    for ((field, expected), observed) in RECEIPT_FIELDS.iter().zip(expected).zip(observed) {
        if !observed.is_finite() || (observed - expected).abs() > TOLERANCE {
            failures.push(format!("{field}:mismatch"));
        }
    }
    failures
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

fn validate_controller_actuation(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    actuation: &ActuationFrame,
) -> Result<(), String> {
    actuation
        .validate(&compiled.morphology)
        .map_err(|error| format!("QSDK_R23D2_RAP_ACTUATION_INVALID:{error}"))?;
    if actuation.safe_no_actuation
        || !actuation.failure_codes.is_empty()
        || actuation.receipt.controller_error.is_some()
        || actuation.ordered_commands.len() != 8
    {
        return Err("QSDK_R23D2_RAP_CONTROLLER_OUTPUT_INVALID".to_owned());
    }
    Ok(())
}

fn validate_host_mapping(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    actuation: &ActuationFrame,
) -> Result<(String, u64), String> {
    let (canonical, mapping) =
        map_bw19v_velocity_only_v4(compiled, actuation, &zero_residuals(compiled))?;
    let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    mapping
        .validate(&compiled.morphology, &canonical, &host_profile)
        .map_err(|error| format!("QSDK_R23D2_RAP_HOST_MAPPING_INVALID:{error}"))?;
    if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
        || mapping.ordered_commands.len() != 8
        || mapping.independent_native_position_feedback_applied
        || mapping.native_position_stiffness != 0.0
        || mapping
            .ordered_commands
            .iter()
            .any(|command| command.native_target_position_rad.is_some() || command.host_clamped)
    {
        return Err("QSDK_R23D2_RAP_NATIVE_MAPPING_BOUNDARY_INVALID".to_owned());
    }
    let sha256 = raw_sha256(
        serde_json::to_vec(&mapping)
            .map_err(|error| error.to_string())?
            .as_slice(),
    );
    Ok((sha256, mapping.ordered_commands.len() as u64))
}

fn claims() -> Value {
    json!({
        "development_screen_only": true,
        "q_sdk_r23_satisfied": false,
        "command_conditioned_turning": false,
        "cross_engine_equivalence": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn vec3_json(value: Vec3) -> Value {
    json!([value.x, value.y, value.z])
}

fn oracle_state_projection(state: &StateFrame) -> Value {
    json!({
        "reference_yaw_rad": state.task_frame.reference_yaw_rad,
        "measured_heading_world_rad": state
            .base_pose_world
            .orientation_xyzw
            .heading_x_forward_z_right_rad(),
        "task_origin_world_m": vec3_json(state.task_frame.origin_world_m),
        "task_lateral_axis_world_unit": vec3_json(state.task_frame.lateral_axis_world_unit),
        "base_position_world_m": vec3_json(state.base_pose_world.position_m),
        "base_linear_velocity_world_m_s": vec3_json(
            state.base_twist_world.linear_velocity_m_s,
        ),
    })
}

fn receipt_projection(values: [f64; 5]) -> Value {
    json!({
        "cross_track_error_m": values[0],
        "cross_track_velocity_m_s": values[1],
        "measured_yaw_error_rad": values[2],
        "desired_heading_error_rad": values[3],
        "yaw_tracking_error_rad": values[4],
    })
}

fn oracle_evaluation(expected: [f64; 5], observed: [f64; 5]) -> Value {
    let failed_predicates = predicate_failures(expected, observed);
    json!({
        "schema_version": "sporespore_qsdk_r23d2_oracle_evaluation_v1",
        "ok": failed_predicates.is_empty(),
        "failed_predicates": failed_predicates,
        "expected_receipt": receipt_projection(expected),
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    })
}

fn worker_failure(
    arm_id: &str,
    source_commit: &str,
    stage_id: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    process_failure_code: &str,
    controller_failure: Option<(Value, Value, Value)>,
) -> Value {
    let (rejected_controller_projection, oracle_input, oracle_evaluation) = controller_failure
        .map(|(projection, input, evaluation)| (Some(projection), Some(input), Some(evaluation)))
        .unwrap_or((None, None, None));
    let payload_sha256 = rejected_controller_projection.as_ref().map(|projection| {
        raw_sha256(
            serde_json::to_vec(projection)
                .expect("finite controller projection serializes")
                .as_slice(),
        )
    });
    json!({
        "schema_version": WORKER_FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": PARENT_GATE_ID,
        "cell_id": format!("{ENGINE_ID}__{arm_id}"),
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "contract_sha256": raw_sha256(DEVELOPMENT_CONTRACT_RAW.as_bytes()),
        "stage_id": stage_id,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "process_failure_code": process_failure_code,
        "rejected_controller_projection": rejected_controller_projection,
        "oracle_input": oracle_input,
        "oracle_evaluation": oracle_evaluation,
        "rejected_projection_retention": {
            "schema_version": "sporespore_qsdk_r23d2_rejected_projection_retention_v1",
            "embedded_before_exit": payload_sha256.is_some(),
            "payload_sha256": payload_sha256,
            "content_addressed_by_supervisor_before_aggregation_required": true,
        },
        "claims": claims(),
    })
}

fn exact_f64_array(value: Option<&Value>, length: usize) -> Result<Vec<f64>, String> {
    value
        .and_then(Value::as_array)
        .filter(|values| values.len() == length)
        .ok_or_else(|| "QSDK_R23D2_RAP_INITIAL_VECTOR_INVALID".to_owned())?
        .iter()
        .map(|entry| {
            entry
                .as_f64()
                .filter(|number| number.is_finite())
                .ok_or_else(|| "QSDK_R23D2_RAP_INITIAL_VECTOR_NONFINITE".to_owned())
        })
        .collect()
}

fn initial_perturbation(development: &Value) -> Result<InitialPerturbation, String> {
    let value = &development["fixture"]["initial_perturbation"];
    let linear = exact_f64_array(value.get("initial_linear_velocity_world_m_s"), 3)?;
    let angular = exact_f64_array(value.get("initial_torso_angular_velocity_world_rad_s"), 3)?;
    let perturbation = InitialPerturbation {
        vertical_clearance_m: value["fixture_vertical_clearance_m"]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| "QSDK_R23D2_RAP_INITIAL_CLEARANCE_INVALID".to_owned())?,
        yaw_rad: value["fixture_yaw_rad"]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| "QSDK_R23D2_RAP_INITIAL_YAW_INVALID".to_owned())?,
        linear_velocity_world_m_s: [linear[0], linear[1], linear[2]],
        torso_angular_velocity_world_rad_s: [angular[0], angular[1], angular[2]],
        gait_phase_offset_ticks: value["gait_phase_offset_ticks"]
            .as_i64()
            .ok_or_else(|| "QSDK_R23D2_RAP_INITIAL_PHASE_INVALID".to_owned())?,
    };
    if value["campaign_seed"] != CAMPAIGN_SEED
        || perturbation.vertical_clearance_m < 0.0
        || perturbation.gait_phase_offset_ticks.abs() > 3
    {
        return Err("QSDK_R23D2_RAP_INITIAL_PERTURBATION_INVALID".to_owned());
    }
    Ok(perturbation)
}

fn heading_schedule(
    semantic_step: u64,
    reference_heading_rad: f64,
    turn_heading_offset_rad: f64,
) -> HeadingCommandSchedule {
    let (segment_id, heading_offset_rad, declared_segment) = if semantic_step < TURN_START_STEP {
        ("reference_warmup", 0.0, true)
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", turn_heading_offset_rad, true)
    } else if semantic_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", 0.0, true)
    } else {
        ("after_declared_schedule", 0.0, false)
    };
    HeadingCommandSchedule {
        segment_id,
        desired_heading_rad: reference_heading_rad + heading_offset_rad,
        declared_segment,
    }
}

fn physical_motion_command(
    semantic_step: u64,
    phase_progression_mode: PhaseProgressionMode,
    heading: &HeadingCommandSchedule,
) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("qsdk_r23d2_heading_{semantic_step}"),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(heading.desired_heading_rad),
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
        .ok_or_else(|| "QSDK_R23D2_RAP_TORSO_HANDLE_MISSING".to_owned())?;
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

fn physical_state_frame(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    semantic_step: u64,
    task_origin: Vector,
    reference_heading_rad: f64,
) -> Result<StateFrame, String> {
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
) -> Result<(), String> {
    if requested_offset_ticks.abs() > 3 || memory.ordered_limb_memory.len() != 4 {
        return Err("QSDK_R23D2_RAP_PHASE_OFFSET_INVALID".to_owned());
    }
    let minimum_raw = memory
        .ordered_limb_memory
        .iter()
        .map(|limb| limb.gait_step as i64 + requested_offset_ticks)
        .min()
        .ok_or_else(|| "QSDK_R23D2_RAP_PHASE_MEMORY_EMPTY".to_owned())?;
    let mut representation_shift_ticks = 0_i64;
    while minimum_raw + representation_shift_ticks < 0 {
        representation_shift_ticks += 360;
    }
    for limb in &mut memory.ordered_limb_memory {
        let updated = limb.gait_step as i64 + requested_offset_ticks + representation_shift_ticks;
        limb.gait_step = u64::try_from(updated)
            .map_err(|_| "QSDK_R23D2_RAP_PHASE_OFFSET_UNDERFLOW".to_owned())?;
    }
    Ok(())
}

fn valid_lower_hex(value: &str, expected_length: usize) -> bool {
    value.len() == expected_length
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

fn physical_authorization_exact(
    development: &Value,
    arm_id: &str,
    source_commit: &str,
) -> Result<(), String> {
    if development["authorization"]["physical_execution_authorized"] != true {
        return Err("QSDK_R23D2_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let attempt_path = env::var(ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(AUTHORIZATION_TOKEN_ENV).unwrap_or_default();
    let cell_id = format!("{ENGINE_ID}__{arm_id}");
    if attempt_path.is_empty()
        || !valid_lower_hex(&token, 32)
        || env::var(CELL_ID_ENV).unwrap_or_default() != cell_id
        || env::var(ENGINE_ID_ENV).unwrap_or_default() != ENGINE_ID
    {
        return Err("QSDK_R23D2_RAP_SUPERVISOR_AUTHORIZATION_INVALID".to_owned());
    }
    let attempt_raw = fs::read_to_string(&attempt_path)
        .map_err(|_| "QSDK_R23D2_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let attempt: Value = serde_json::from_str(&attempt_raw)
        .map_err(|_| "QSDK_R23D2_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let exact = attempt["schema_version"] == "sporespore_qsdk_r23d2_attempt_v1"
        && attempt["campaign_id"] == CAMPAIGN_ID
        && attempt["gate_id"] == PARENT_GATE_ID
        && attempt["contract_sha256"] == raw_sha256(DEVELOPMENT_CONTRACT_RAW.as_bytes())
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
        return Err("QSDK_R23D2_RAP_ATTEMPT_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(())
}

#[derive(Debug, Clone)]
struct PhysicalReportMetrics {
    controller_error_count: u64,
    safe_no_actuation_count: u64,
    nonfinite_observation_count: u64,
    actuator_application_mismatch_count: u64,
    controller_semantic_step_count: u64,
    validated_portable_command_count: u64,
    native_actuation_application_count: u64,
    observed_segment_sample_counts: BTreeMap<&'static str, u64>,
    maximum_absolute_requested_steering_fraction: f64,
    maximum_absolute_held_steering_fraction: f64,
    mean_turn_held_steering_fraction: f64,
    turn_phase_yaw_delta_rad: f64,
    final_reference_heading_error_rad: f64,
    final_forward_displacement_m: f64,
    maximum_tilt_rad: f64,
    minimum_torso_height_m: f64,
    torso_ground_contact_step_count: u64,
    contact_cycles_by_limb: Map<String, Value>,
    walking_gate_passed: bool,
}

fn compose_physical_report(
    arm_id: &str,
    source_commit: &str,
    turn_heading_offset_rad: f64,
    metrics: PhysicalReportMetrics,
) -> Value {
    json!({
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": PARENT_GATE_ID,
        "cell_id": format!("{ENGINE_ID}__{arm_id}"),
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "contract_sha256": raw_sha256(DEVELOPMENT_CONTRACT_RAW.as_bytes()),
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": metrics.controller_error_count,
            "safe_no_actuation_count": metrics.safe_no_actuation_count,
            "nonfinite_observation_count": metrics.nonfinite_observation_count,
            "actuator_application_mismatch_count": metrics.actuator_application_mismatch_count,
            "controller_semantic_step_count": metrics.controller_semantic_step_count,
            "validated_portable_command_count": metrics.validated_portable_command_count,
            "native_actuation_application_count": metrics.native_actuation_application_count,
        },
        "execution_stage": {
            "schema_version": EXECUTION_STAGE_SCHEMA,
            "stage_id": "cell_report_complete",
            "world_attempt_count": 1,
            "world_build_count": 1,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
            "source_validation_mode": SOURCE_VALIDATION_MODE,
            "native_validation_step_count": metrics.controller_semantic_step_count,
            "heading_command_conditioned_step_count": metrics.controller_semantic_step_count,
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": false,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
            "oracle_contract_sha256": raw_sha256(ORACLE_RAW.as_bytes()),
            "independent_oracle_validation_step_count": metrics.controller_semantic_step_count,
            "accepted_receipt_count": metrics.controller_semantic_step_count,
            "rejected_receipt_count": 0,
            "predicate_failure_count": 0,
            "raw_heading_offset_equality_used": false,
        },
        "schedule": {
            "schedule_id": SCHEDULE_ID,
            "turn_heading_offset_rad": turn_heading_offset_rad,
            "observed_segment_sample_counts": metrics.observed_segment_sample_counts,
            "reference_heading_sample_count": 1200,
            "turn_heading_sample_count": 1200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction":
                metrics.maximum_absolute_requested_steering_fraction,
            "maximum_absolute_held_steering_fraction":
                metrics.maximum_absolute_held_steering_fraction,
            "mean_turn_held_steering_fraction": metrics.mean_turn_held_steering_fraction,
        },
        "physics": {
            "turn_phase_yaw_delta_rad": metrics.turn_phase_yaw_delta_rad,
            "final_reference_heading_error_rad": metrics.final_reference_heading_error_rad,
            "final_forward_displacement_m": metrics.final_forward_displacement_m,
            "maximum_tilt_rad": metrics.maximum_tilt_rad,
            "minimum_torso_height_m": metrics.minimum_torso_height_m,
            "torso_ground_contact_step_count": metrics.torso_ground_contact_step_count,
            "contact_cycles_by_limb": metrics.contact_cycles_by_limb,
            "engine_production_straight_walking_gate_passed": metrics.walking_gate_passed,
            "commanded_turn_walk_gate_passed": metrics.walking_gate_passed,
        },
        "claims": claims(),
    })
}

fn synthetic_physical_report(arm_id: &str, turn_heading_offset_rad: f64) -> Value {
    let signed_controller = if turn_heading_offset_rad == 0.0 {
        0.0
    } else {
        -turn_heading_offset_rad.signum() * 0.2
    };
    let signed_yaw = if turn_heading_offset_rad == 0.0 {
        0.0
    } else {
        turn_heading_offset_rad.signum() * 0.1
    };
    compose_physical_report(
        arm_id,
        &"a".repeat(40),
        turn_heading_offset_rad,
        PhysicalReportMetrics {
            controller_error_count: 0,
            safe_no_actuation_count: 0,
            nonfinite_observation_count: 0,
            actuator_application_mismatch_count: 0,
            controller_semantic_step_count: CONTROLLER_STEPS,
            validated_portable_command_count: CONTROLLER_STEPS * 8,
            native_actuation_application_count: CONTROLLER_STEPS * 8,
            observed_segment_sample_counts: BTreeMap::from([
                ("reference_warmup", 600),
                ("commanded_turn", 1200),
                ("reference_recovery", 600),
            ]),
            maximum_absolute_requested_steering_fraction: 0.3,
            maximum_absolute_held_steering_fraction: 0.25,
            mean_turn_held_steering_fraction: signed_controller,
            turn_phase_yaw_delta_rad: signed_yaw,
            final_reference_heading_error_rad: 0.02,
            final_forward_displacement_m: 0.5,
            maximum_tilt_rad: 0.2,
            minimum_torso_height_m: 0.4,
            torso_ground_contact_step_count: 0,
            contact_cycles_by_limb: Map::from_iter([
                ("front_left".to_owned(), json!(3)),
                ("front_right".to_owned(), json!(3)),
                ("rear_left".to_owned(), json!(3)),
                ("rear_right".to_owned(), json!(3)),
            ]),
            walking_gate_passed: true,
        },
    )
}

fn synthetic_failure_receipts(
    arm_id: &str,
    oracle_contract: &Value,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    controller: &BalancedWaveController,
) -> Result<Vec<Value>, String> {
    let source_commit = "a".repeat(40);
    let mut receipts = Vec::<Value>::new();
    for (stage_id, attempts, builds) in [
        ("before_world", 0, 0),
        ("world_construction_failed", 1, 0),
        ("world_constructed", 1, 1),
        ("settlement_complete", 1, 1),
        ("cell_report_complete", 1, 1),
    ] {
        receipts.push(worker_failure(
            arm_id,
            &source_commit,
            stage_id,
            attempts,
            builds,
            &format!("QSDK_R23D2_RAP_SYNTHETIC_{}", stage_id.to_ascii_uppercase()),
            None,
        ));
    }

    let canary = &oracle_contract["oracle_canaries"][1];
    let canary_id = canary["canary_id"]
        .as_str()
        .ok_or_else(|| "QSDK_R23D2_RAP_FAILURE_CANARY_ID_INVALID".to_owned())?;
    let state = state_for_canary(compiled, canary)?;
    let command = command_for_canary(canary_id, canary)?;
    let expected = independent_oracle(&state, &command, controller.profile())?;
    let mut observed = expected;
    observed[3] += 1.0e-6;
    let projection = receipt_projection(observed);
    let input = json!({
        "state": oracle_state_projection(&state),
        "command": {"desired_heading_rad": command.desired_heading_rad},
        "profile": oracle_contract["selected_profile_oracle"].clone(),
    });
    let evaluation = oracle_evaluation(expected, observed);
    receipts.push(worker_failure(
        arm_id,
        &source_commit,
        "controller_validation_failed",
        1,
        1,
        "QSDK_R23D2_RAP_SYNTHETIC_CONTROLLER_VALIDATION_FAILED",
        Some((projection, input, evaluation)),
    ));
    Ok(receipts)
}

pub fn run_qsdk_r23d2_rapier_preflight(arm_id: &str) -> Result<Value, String> {
    let arm_heading_offset_rad = arm_offset(arm_id)?;
    let (oracle_contract, worker_contract, _) = parse_contracts()?;
    let (compiled, controller) = compile_boundary()?;
    let declared_profile = &oracle_contract["selected_profile_oracle"];
    if (controller.profile().cross_track_heading_gain_rad_per_m
        - f64_field(declared_profile, "cross_track_heading_gain_rad_per_m")?)
    .abs()
        > 1.0e-15
        || (controller
            .profile()
            .cross_track_velocity_heading_gain_rad_per_m_s
            - f64_field(
                declared_profile,
                "cross_track_velocity_heading_gain_rad_per_m_s",
            )?)
        .abs()
            > 1.0e-15
    {
        return Err("QSDK_R23D2_RAP_PROFILE_ORACLE_MISMATCH".to_owned());
    }

    let canaries = oracle_contract["oracle_canaries"]
        .as_array()
        .ok_or_else(|| "QSDK_R23D2_RAP_CANARIES_INVALID".to_owned())?;
    let mut results = Vec::<Value>::new();
    let mut nonzero_canary_count = 0_u64;
    let mut legacy_oracle_rejection_count = 0_u64;
    let mut predicate_negative_control_count = 0_u64;
    let mut native_command_count = 0_u64;
    for canary in canaries {
        let canary_id = canary["canary_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D2_RAP_CANARY_ID_INVALID".to_owned())?;
        let state = state_for_canary(&compiled, canary)?;
        let command = command_for_canary(canary_id, canary)?;
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        validate_controller_actuation(&compiled, &output.actuation)?;
        let expected = independent_oracle(&state, &command, controller.profile())?;
        let observed = receipt_values(&output.actuation.receipt);
        let failures = predicate_failures(expected, observed);
        if !failures.is_empty() {
            return Err(format!(
                "QSDK_R23D2_RAP_ORACLE_MISMATCH:{canary_id}:{}",
                failures.join(",")
            ));
        }
        if (expected[3] - f64_field(canary, "expected_desired_heading_error_rad")?).abs()
            > TOLERANCE
        {
            return Err(format!(
                "QSDK_R23D2_RAP_CANARY_EXPECTATION_INVALID:{canary_id}"
            ));
        }

        let nonzero = expected[0] != 0.0 || expected[1] != 0.0;
        if nonzero {
            nonzero_canary_count += 1;
            let requested_heading_error = wrap_angle(
                command.desired_heading_rad.expect("canary heading")
                    - state.task_frame.reference_yaw_rad,
            );
            let mut legacy = expected;
            legacy[3] = requested_heading_error;
            legacy[4] = wrap_angle(expected[2] - requested_heading_error);
            if predicate_failures(expected, legacy).is_empty() {
                return Err(format!("QSDK_R23D2_RAP_LEGACY_ORACLE_ACCEPTED:{canary_id}"));
            }
            legacy_oracle_rejection_count += 1;
        }
        for index in 0..RECEIPT_FIELDS.len() {
            let mut mutated = expected;
            mutated[index] += 1.0e-6;
            let mutation_failures = predicate_failures(expected, mutated);
            if mutation_failures != [format!("{}:mismatch", RECEIPT_FIELDS[index])] {
                return Err(format!(
                    "QSDK_R23D2_RAP_NEGATIVE_CONTROL_INVALID:{canary_id}:{}",
                    RECEIPT_FIELDS[index]
                ));
            }
            predicate_negative_control_count += 1;
        }

        let (host_mapping_sha256, mapped_command_count) =
            validate_host_mapping(&compiled, &output.actuation)?;
        native_command_count += mapped_command_count;
        results.push(json!({
            "canary_id": canary_id,
            "nonzero_cross_track": nonzero,
            "expected_receipt": {
                "cross_track_error_m": expected[0],
                "cross_track_velocity_m_s": expected[1],
                "measured_yaw_error_rad": expected[2],
                "desired_heading_error_rad": expected[3],
                "yaw_tracking_error_rad": expected[4],
            },
            "observed_receipt": {
                "cross_track_error_m": observed[0],
                "cross_track_velocity_m_s": observed[1],
                "measured_yaw_error_rad": observed[2],
                "desired_heading_error_rad": observed[3],
                "yaw_tracking_error_rad": observed[4],
            },
            "failed_predicates": failures,
            "host_mapping_sha256": host_mapping_sha256,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        }));
    }

    let arm_state = state_for_canary(&compiled, &canaries[0])?;
    let arm_command = command_for_arm_boundary(
        arm_id,
        arm_state.task_frame.reference_yaw_rad,
        arm_heading_offset_rad,
    );
    let arm_output = controller.step(
        &BalancedWaveControllerMemory::initial(),
        &arm_state,
        &arm_command,
    );
    validate_controller_actuation(&compiled, &arm_output.actuation)?;
    let arm_expected = independent_oracle(&arm_state, &arm_command, controller.profile())?;
    let arm_observed = receipt_values(&arm_output.actuation.receipt);
    let arm_failures = predicate_failures(arm_expected, arm_observed);
    if !arm_failures.is_empty() || (arm_expected[3] - arm_heading_offset_rad).abs() > TOLERANCE {
        return Err(format!(
            "QSDK_R23D2_RAP_ARM_COMMAND_BOUNDARY_INVALID:{arm_id}:{}",
            arm_failures.join(",")
        ));
    }
    let (arm_mapping_sha256, arm_command_count) =
        validate_host_mapping(&compiled, &arm_output.actuation)?;
    native_command_count += arm_command_count;

    if nonzero_canary_count != 6
        || legacy_oracle_rejection_count != 6
        || predicate_negative_control_count != 35
        || native_command_count != 64
    {
        return Err("QSDK_R23D2_RAP_PREFLIGHT_COUNTS_INVALID".to_owned());
    }
    let synthetic_report = synthetic_physical_report(arm_id, arm_heading_offset_rad);
    let synthetic_failures =
        synthetic_failure_receipts(arm_id, &oracle_contract, &compiled, &controller)?;

    Ok(json!({
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "arm_heading_offset_rad": arm_heading_offset_rad,
        "selected_policy_id": POLICY_ID,
        "morphology_id": MORPHOLOGY_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "oracle_contract_sha256": raw_sha256(ORACLE_RAW.as_bytes()),
        "worker_contract_sha256": raw_sha256(WORKER_CONTRACT_RAW.as_bytes()),
        "development_contract_sha256": raw_sha256(DEVELOPMENT_CONTRACT_RAW.as_bytes()),
        "worker_contract_status": worker_contract["status"],
        "canary_count": results.len(),
        "nonzero_cross_track_canary_count": nonzero_canary_count,
        "legacy_raw_offset_oracle_rejection_count": legacy_oracle_rejection_count,
        "predicate_negative_control_count": predicate_negative_control_count,
        "arm_command_boundary": {
            "desired_heading_error_rad": arm_expected[3],
            "observed_heading_error_rad": arm_observed[3],
            "failed_predicates": arm_failures,
            "host_mapping_sha256": arm_mapping_sha256,
            "native_command_count": arm_command_count,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        },
        "native_controller_step_count": results.len() + 1,
        "native_command_count": native_command_count,
        "host_mapping_validation_count": results.len() + 1,
        "canaries": results,
        "synthetic_physical_report": synthetic_report,
        "synthetic_failure_receipts": synthetic_failures,
        "physical_implementation_present": true,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": true,
        "q_sdk_r23_satisfied": false,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_qsdk_r23d2_rapier_physical(arm_id: &str, source_commit: &str) -> Result<Value, Value> {
    let before_world_failure =
        |code: String| worker_failure(arm_id, source_commit, "before_world", 0, 0, &code, None);
    if PHYSICAL_IDENTITY_CLOSED {
        return Err(before_world_failure(
            "QSDK_R23D2_RAP_PHYSICAL_IDENTITY_CLOSED".to_owned(),
        ));
    }
    let turn_heading_offset_rad = arm_offset(arm_id).map_err(&before_world_failure)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world_failure(
            "QSDK_R23D2_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let (oracle_contract, _, development) = parse_contracts().map_err(&before_world_failure)?;
    physical_authorization_exact(&development, arm_id, source_commit)
        .map_err(&before_world_failure)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world_failure)?;
    // Re-run the commissioned native/controller canaries before the attempt
    // boundary; the returned receipt is intentionally not physical evidence.
    let _preflight = run_qsdk_r23d2_rapier_preflight(arm_id).map_err(&before_world_failure)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world_failure)?;

    // The attempt boundary is immediately before the first native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                worker_failure(
                    arm_id,
                    source_commit,
                    "world_construction_failed",
                    1,
                    0,
                    &code,
                    None,
                )
            })?;
    let world_constructed_failure = |code: String| {
        worker_failure(
            arm_id,
            source_commit,
            "world_constructed",
            1,
            1,
            &code,
            None,
        )
    };
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed_failure)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed_failure)?;
    }

    let settled_failure = |code: String| {
        worker_failure(
            arm_id,
            source_commit,
            "settlement_complete",
            1,
            1,
            &code,
            None,
        )
    };
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
    let mut controller_error_count = 0_u64;
    let mut safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut portable_command_count = 0_u64;
    let mut native_application_count = 0_u64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_absolute_requested_steering_fraction = 0.0_f64;
    let mut maximum_absolute_held_steering_fraction = 0.0_f64;
    let mut turn_held_steering_sum = 0.0_f64;
    let mut turn_held_steering_count = 0_u64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut segment_counts = BTreeMap::from([
        ("reference_warmup", 0_u64),
        ("commanded_turn", 0_u64),
        ("reference_recovery", 0_u64),
    ]);

    for semantic_step in 0..CONTROLLER_STEPS {
        if semantic_step == PHASE_OFFSET_ACTIVATION_STEP {
            apply_phase_offset(&mut memory, perturbation.gait_phase_offset_ticks)
                .map_err(&settled_failure)?;
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
        let state = physical_state_frame(
            &robot,
            &compiled,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let heading = heading_schedule(
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
                .ok_or_else(|| settled_failure("QSDK_R23D2_RAP_SEGMENT_UNKNOWN".to_owned()))? += 1;
        }
        let command = physical_motion_command(semantic_step, phase_mode, &heading);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;

        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            let projection = receipt_projection(observed);
            let oracle_input = json!({
                "state": oracle_state_projection(&state),
                "command": {"desired_heading_rad": command.desired_heading_rad},
                "profile": oracle_contract["selected_profile_oracle"].clone(),
            });
            let evaluation = oracle_evaluation(expected, observed);
            return Err(worker_failure(
                arm_id,
                source_commit,
                "controller_validation_failed",
                1,
                1,
                &format!(
                    "QSDK_R23D2_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                Some((projection, oracle_input, evaluation)),
            ));
        }

        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D2_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
            || mapping.ordered_commands.len() != 8
            || mapping.independent_native_position_feedback_applied
            || mapping.native_position_stiffness != 0.0
            || mapping
                .ordered_commands
                .iter()
                .any(|entry| entry.native_target_position_rad.is_some() || entry.host_clamped)
        {
            return Err(settled_failure(
                "QSDK_R23D2_RAP_NATIVE_MAPPING_BOUNDARY_INVALID".to_owned(),
            ));
        }
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
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_application_count += applications;
        actuator_application_mismatch_count += u64::from(applications != 8);
        if impulse_violations != 0 {
            return Err(settled_failure(format!(
                "QSDK_R23D2_RAP_IMPULSE_LIMIT_VIOLATION:{impulse_violations}"
            )));
        }
        memory = output.next_memory;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        if semantic_step >= CONTACT_GATED_START_STEP {
            for limb in &compiled.morphology.morphology_spec.limbs {
                let site = compiled
                    .morphology
                    .morphology_spec
                    .contact_sites
                    .iter()
                    .find(|site| site.contact_site_id == limb.ordered_contact_site_ids[0])
                    .ok_or_else(|| {
                        settled_failure("QSDK_R23D2_RAP_CONTACT_SITE_MISSING".to_owned())
                    })?;
                foot_evidence
                    .get_mut(&limb.limb_id)
                    .ok_or_else(|| {
                        settled_failure("QSDK_R23D2_RAP_FOOT_EVIDENCE_MISSING".to_owned())
                    })?
                    .observe(
                        robot.contact(&site.body_id),
                        robot.contact_site_position(site),
                    );
            }
        }
    }

    for _ in 0..TERMINAL_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
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
        .ok_or_else(|| settled_failure("QSDK_R23D2_RAP_TURN_YAW_WINDOW_INCOMPLETE".to_owned()))?;
    let mean_turn_held_steering_fraction = if turn_held_steering_count == 0 {
        return Err(settled_failure(
            "QSDK_R23D2_RAP_TURN_STEERING_WINDOW_EMPTY".to_owned(),
        ));
    } else {
        turn_held_steering_sum / turn_held_steering_count as f64
    };
    let contact_cycles_by_limb = foot_evidence
        .iter()
        .map(|(limb_id, evidence)| (limb_id.clone(), json!(evidence.contact_cycles)))
        .collect::<Map<_, _>>();
    let contacts_pass = foot_evidence
        .values()
        .all(|evidence| evidence.contact_cycles >= MINIMUM_CONTACT_CYCLES_PER_LIMB);
    let walking_gate = controller_error_count == 0
        && safe_no_actuation_count == 0
        && nonfinite_observation_count == 0
        && actuator_application_mismatch_count == 0
        && portable_command_count == CONTROLLER_STEPS * 8
        && native_application_count == CONTROLLER_STEPS * 8
        && torso_ground_contact_step_count == 0
        && maximum_tilt_rad <= MAXIMUM_TILT_RAD
        && minimum_torso_height_m >= MINIMUM_TORSO_HEIGHT_M
        && final_forward_displacement_m >= MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
        && contacts_pass;

    Ok(compose_physical_report(
        arm_id,
        source_commit,
        turn_heading_offset_rad,
        PhysicalReportMetrics {
            controller_error_count,
            safe_no_actuation_count,
            nonfinite_observation_count,
            actuator_application_mismatch_count,
            controller_semantic_step_count: CONTROLLER_STEPS,
            validated_portable_command_count: portable_command_count,
            native_actuation_application_count: native_application_count,
            observed_segment_sample_counts: segment_counts,
            maximum_absolute_requested_steering_fraction,
            maximum_absolute_held_steering_fraction,
            mean_turn_held_steering_fraction,
            turn_phase_yaw_delta_rad,
            final_reference_heading_error_rad,
            final_forward_displacement_m,
            maximum_tilt_rad,
            minimum_torso_height_m,
            torso_ground_contact_step_count,
            contact_cycles_by_limb,
            walking_gate_passed: walking_gate,
        },
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_arm_runs_all_nonzero_oracle_and_native_mapping_canaries() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let report = run_qsdk_r23d2_rapier_preflight(arm_id).unwrap();
            assert_eq!(report["canary_count"], 7);
            assert_eq!(report["nonzero_cross_track_canary_count"], 6);
            assert_eq!(report["legacy_raw_offset_oracle_rejection_count"], 6);
            assert_eq!(report["predicate_negative_control_count"], 35);
            assert_eq!(report["native_controller_step_count"], 8);
            assert_eq!(report["native_command_count"], 64);
            assert_eq!(report["host_mapping_validation_count"], 8);
            assert_eq!(report["physical_implementation_present"], true);
            assert_eq!(
                report["synthetic_physical_report"]["schema_version"],
                REPORT_SCHEMA
            );
            assert_eq!(
                report["synthetic_failure_receipts"]
                    .as_array()
                    .expect("failure canaries")
                    .len(),
                6
            );
            assert!(
                (report["arm_command_boundary"]["desired_heading_error_rad"]
                    .as_f64()
                    .unwrap()
                    - report["arm_heading_offset_rad"].as_f64().unwrap())
                .abs()
                    <= TOLERANCE
            );
            assert_eq!(report["world_build_count"], 0);
        }
    }

    #[test]
    fn unknown_arm_and_direct_physical_bypass_fail_closed() {
        assert!(run_qsdk_r23d2_rapier_preflight("unknown").is_err());
        let failure = run_qsdk_r23d2_rapier_physical(
            "reference_zero",
            "0000000000000000000000000000000000000000",
        )
        .unwrap_err();
        assert_eq!(failure["schema_version"], WORKER_FAILURE_SCHEMA);
        assert_eq!(
            failure["process_failure_code"],
            "QSDK_R23D2_RAP_PHYSICAL_IDENTITY_CLOSED"
        );
        assert_eq!(failure["stage_id"], "before_world");
        assert_eq!(failure["world_attempt_count"], 0);
        assert_eq!(failure["world_build_count"], 0);
    }
}
