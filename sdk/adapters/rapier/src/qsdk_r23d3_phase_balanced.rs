//! QSDK-R23D3 Rapier worker.
//!
//! The first section is an exact inherited copy of the closed R23D2 Rapier
//! worker and supplies private, already-commissioned fixture/oracle helpers.
//! Its old physical entrypoint remains closed.  The distinct R23D3 entrypoints
//! at the end of this module add the new identity, onset schedule, complete
//! trace, CAS-before-terminal retention, and supervisor-only authorization.

#![allow(dead_code)]

pub(crate) mod r23d11_physical;
pub(crate) mod r23d12_physical;
pub(crate) mod r23d13_physical;
pub(crate) mod r23d14_physical;
pub(crate) mod r23d15_physical;
pub(crate) mod r23d16_physical;
pub(crate) mod r23d17_physical;
pub(crate) mod r23d18_physical;
pub(crate) mod r23d22_physical;
pub(crate) mod r23d23_physical;
pub(crate) mod r23d26_physical;
pub(crate) mod r23d27_physical;

use std::{collections::BTreeMap, env, fs, sync::OnceLock};

use rapier3d::prelude::*;
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{
    ActuationFrame, CommandAuthority, ControllerStepReceipt, MOTION_COMMAND_VERSION, MotionCommand,
    PhaseProgressionMode, Quaternion, SpeedClass,
};
use sporespore_locomotion_core::schema::Vec3;
use sporespore_locomotion_core::{
    BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION,
    BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID,
    BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BalancedWaveController, BalancedWaveControllerMemory, BalancedWaveProfile,
    COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID, CanonicalVelocityResidualV1,
    PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID, SELECTED_BALANCED_WAVE_POLICY_ID, StateFrame,
    TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID, VelocityOnlyHostProfileV1,
    compile_bounded_quadruped,
};

use crate::{
    ADAPTER_ID,
    bw19v_composition::map_bw19v_velocity_only_v4,
    bw19v_velocity_only_pose_hold_restoration_ph1::{
        QsdkContactRestorationComposition, QsdkPoseHoldRestorationMemory,
        compose_qsdk_contact_restoration,
        run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight,
    },
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
    compile_boundary_for_policy(SELECTED_BALANCED_WAVE_POLICY_ID)
}

fn compile_boundary_for_policy(
    policy_id: &str,
) -> Result<
    (
        sporespore_locomotion_core::CompiledQuadruped,
        BalancedWaveController,
    ),
    String,
> {
    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller = BalancedWaveController::new_for_policy(compiled.clone(), policy_id)
        .map_err(|error| error.to_string())?;
    if compiled.world_build_count != 0
        || compiled.morphology.world_build_count != 0
        || compiled.morphology_id != MORPHOLOGY_ID
        || controller.profile().policy_id != policy_id
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
    let requested_heading_error_rad = wrap_angle(
        command
            .desired_heading_rad
            .ok_or_else(|| "QSDK_R23D2_RAP_DESIRED_HEADING_MISSING".to_owned())?
            - state.task_frame.reference_yaw_rad,
    );
    let lateral_axis = match profile.cross_track_frame_mode_id.as_deref() {
        None => state.task_frame.lateral_axis_world_unit,
        Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID) => {
            let cosine = requested_heading_error_rad.cos();
            let sine = requested_heading_error_rad.sin();
            Vec3 {
                x: -sine * state.task_frame.forward_axis_world_unit.x
                    + cosine * state.task_frame.lateral_axis_world_unit.x,
                y: -sine * state.task_frame.forward_axis_world_unit.y
                    + cosine * state.task_frame.lateral_axis_world_unit.y,
                z: -sine * state.task_frame.forward_axis_world_unit.z
                    + cosine * state.task_frame.lateral_axis_world_unit.z,
            }
        }
        Some(mode_id) => {
            return Err(format!("QSDK_R23D2_RAP_CROSS_TRACK_FRAME_MODE:{mode_id}"));
        }
    };
    let cross_track_error_m = dot(displacement, lateral_axis);
    let cross_track_velocity_m_s = dot(state.base_twist_world.linear_velocity_m_s, lateral_axis);
    let measured_yaw_error_rad = wrap_angle(
        state
            .base_pose_world
            .orientation_xyzw
            .heading_x_forward_z_right_rad()
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

// -------------------------------------------------------------------------
// Distinct prospective R23D6 implementation. Nothing below changes or
// reinterprets R23D5. R23D6 keeps the frozen onset-600 turning controller and
// accepted PH1 terminal contact-restoration mechanism under a new identity,
// followed by a genuinely passive traced settle.

const R23D6_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d6_policy_compatible_restoration_preregistration_v1.json");
const R23D6_IMPLEMENTATION_RAW: &str =
    include_str!("../../../turning/r23d6_implementation_contract_v1.json");
const R23D6_CAMPAIGN_ID: &str =
    "QSDK-R23D6-POLICY-COMPATIBLE-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT";
const R23D6_GATE_ID: &str = "QSDK-R23D6";
const R23D6_ENGINE_ID: &str = "rapier_parry";
const R23D6_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d6_rapier_worker_preflight_v1";
const R23D6_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d6_engine_cell_report_v1";
const R23D6_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d6_worker_failure_v1";
const R23D6_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d4_turn_restore_settle_trace_row_v1";
const R23D6_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d6_trace_retention_v1";
const R23D6_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d6_physical_freeze_v1";
const R23D6_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d6_attempt_v1";
const R23D6_CLOSURE_PATH: &str = "sdk/turning/r23d6_physical_closure_v1.json";
const R23D6_STAGE_ID: &str = "three_engine_confirmation";
const R23D6_CONTROLLER_STEPS: u64 = 2_992;
const R23D6_RESTORATION_STEPS: u64 = 540;
const R23D6_CONTACT_ACQUISITION_STEPS: u64 = 180;
const R23D6_CONTACT_HOLD_STEPS: u64 = 360;
const R23D6_PASSIVE_SETTLE_STEPS: u64 = 240;
const R23D6_ACTIVE_STEPS: u64 = R23D6_CONTROLLER_STEPS + R23D6_RESTORATION_STEPS;
const R23D6_TOTAL_TRACE_STEPS: u64 = R23D6_ACTIVE_STEPS + R23D6_PASSIVE_SETTLE_STEPS;
const R23D6_RESTORATION_POLICY_ID: &str =
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1";
const R23D6_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S: f64 = 0.35;

static R23D6_RESTORATION_PREFLIGHT: OnceLock<Result<Value, String>> = OnceLock::new();

const R23D6_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D6_FREEZE";
const R23D6_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D6_ATTEMPT";
const R23D6_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D6_TOKEN";
const R23D6_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D6_STAGE";
const R23D6_CELL_ENV: &str = "SPORESPORE_QSDK_R23D6_CELL";
const R23D6_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D6_ENGINE";
const R23D6_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D6_ATTEMPT_ROOT";
const R23D6_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D6_PYTHON";
const R23D6_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D6_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D6Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

fn r23d6_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d6_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D6_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D6_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["frozen_schedule_and_gate_snapshot"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d6_policy_compatible_restoration_preregistration_v1"
        && contract["campaign_id"] == R23D6_CAMPAIGN_ID
        && contract["gate_id"] == R23D6_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && schedule["turning_controller_semantic_step_count"] == R23D6_CONTROLLER_STEPS
        && schedule["terminal_restoration_step_count"] == R23D6_RESTORATION_STEPS
        && schedule["maximum_four_contact_acquisition_steps"] == R23D6_CONTACT_ACQUISITION_STEPS
        && schedule["required_consecutive_all_four_contact_hold_steps"] == R23D6_CONTACT_HOLD_STEPS
        && schedule["passive_settle_step_count"] == R23D6_PASSIVE_SETTLE_STEPS
        && schedule["total_traced_step_count"] == R23D6_TOTAL_TRACE_STEPS
        && schedule["terminal_restoration_policy_id"] == R23D6_RESTORATION_POLICY_ID
        && schedule["maximum_absolute_restoration_joint_velocity_rad_s"]
            == R23D6_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S;
    if !exact {
        return Err("QSDK_R23D6_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d6_cell(stage_id: &str, arm_id: &str) -> Result<R23D6Cell, String> {
    if stage_id != R23D6_STAGE_ID {
        return Err(format!("QSDK_R23D6_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D6_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D6Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D6_ENGINE_ID}__onset_600__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d6_phase(trace_step: u64) -> (&'static str, Option<u64>, f64) {
    if trace_step < TURN_START_STEP {
        ("reference_warmup", Some(trace_step), 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", Some(trace_step), 1.0)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", Some(trace_step), 0.0)
    } else if trace_step < R23D6_CONTROLLER_STEPS {
        ("reference_continuation", Some(trace_step), 0.0)
    } else if trace_step < R23D6_CONTROLLER_STEPS + R23D6_CONTACT_ACQUISITION_STEPS {
        ("terminal_contact_acquisition", None, 0.0)
    } else if trace_step < R23D6_ACTIVE_STEPS {
        ("terminal_captured_pose_hold", None, 0.0)
    } else {
        ("passive_zero_actuation_settle", None, 0.0)
    }
}

fn r23d6_expected_phase_counts() -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("commanded_turn", 1_200),
        ("passive_zero_actuation_settle", R23D6_PASSIVE_SETTLE_STEPS),
        ("reference_continuation", 592),
        ("reference_recovery", 600),
        ("reference_warmup", 600),
        ("terminal_captured_pose_hold", R23D6_CONTACT_HOLD_STEPS),
        (
            "terminal_contact_acquisition",
            R23D6_CONTACT_ACQUISITION_STEPS,
        ),
    ])
}

pub fn run_qsdk_r23d6_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let _contract = r23d6_contract()?;
    let cell = r23d6_cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d3_rapier_preflight(R23D6_STAGE_ID, "onset_600", arm_id)?;
    let restoration = R23D6_RESTORATION_PREFLIGHT
        .get_or_init(run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight)
        .clone()?;
    let mut phase_counts = BTreeMap::<&'static str, u64>::new();
    for trace_step in 0..R23D6_TOTAL_TRACE_STEPS {
        *phase_counts.entry(r23d6_phase(trace_step).0).or_default() += 1;
    }
    if inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["inherited_predicate_negative_control_count"] != 35
        || inherited["inherited_native_mapping_canary_count"] != 7
        || restoration["ok"] != true
        || restoration["world_build_count"] != 0
        || restoration["all_negative_controls_rejected"] != true
        || phase_counts != r23d6_expected_phase_counts()
    {
        return Err("QSDK_R23D6_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D6_PREFLIGHT_SCHEMA,
        "campaign_id": R23D6_CAMPAIGN_ID,
        "gate_id": R23D6_GATE_ID,
        "engine_id": R23D6_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D6_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d3_native_mapping_canary_count":
            inherited["inherited_native_mapping_canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["inherited_predicate_negative_control_count"],
        "borrowed_ph1_restoration_negative_control_count": restoration["negative_control_count"],
        "borrowed_ph1_real_shaped_restoration_canary_passed": restoration["ok"],
        "fixed_controller_horizon_step_count": R23D6_CONTROLLER_STEPS,
        "fixed_terminal_restoration_step_count": R23D6_RESTORATION_STEPS,
        "fixed_passive_settle_step_count": R23D6_PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": R23D6_TOTAL_TRACE_STEPS,
        "trace_phase_counts": phase_counts,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d6_failure(
    cell: &R23D6Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D6_FAILURE_SCHEMA,
        "campaign_id": R23D6_CAMPAIGN_ID,
        "gate_id": R23D6_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D6_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": Value::Null,
        "godot_execution_predicates": Value::Null,

        "claims": r23d6_claims(),
    })
}

fn r23d6_source_bindings_exact(freeze: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let required_paths = [
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
        "sdk/adapters/rapier/src/bw19v_velocity_only_pose_hold_restoration_ph1.rs",
        "sdk/adapters/rapier/src/bin/qsdk_r23d6_policy_compatible.rs",
        "sdk/turning/r23d6_policy_compatible_restoration_preregistration_v1.json",
        "sdk/turning/r23d6_implementation_contract_v1.json",
        "sdk/turning/r23d6_physical_evaluator.py",
        "sdk/publish_qsdk_r23d6_trace.ps1",
    ];
    let Ok(implementation) = serde_json::from_str::<Value>(R23D6_IMPLEMENTATION_RAW) else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]["rapier_parry"]
            .as_array()
    else {
        return false;
    };
    if declared.len() != required_paths.len()
        || declared
            .iter()
            .zip(required_paths)
            .any(|(actual, expected)| actual.as_str() != Some(expected))
    {
        return false;
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    required_paths.iter().all(|path| {
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        let digest = raw_sha256(&bytes);
        bindings
            .iter()
            .any(|entry| entry["path"] == *path && entry["raw_sha256"] == digest)
    })
}

fn r23d6_physical_authorization(
    cell: &R23D6Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D6_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D6_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D6_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D6_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D6_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D6_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D6_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D6_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D6_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D6_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D6_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D6_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D6_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D6_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D6_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D6_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D6_CAMPAIGN_ID
        && freeze["gate_id"] == R23D6_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D6_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d6_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D6_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D6_CAMPAIGN_ID
        && attempt["gate_id"] == R23D6_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D6_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D6_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D6_ENGINE_ENV).unwrap_or_default() == R23D6_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D6_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

fn r23d6_retain_trace(
    cell: &R23D6Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D6_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D6_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D6_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d6_physical_evaluator.py");
    let python = env::var(R23D6_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D6_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D6_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D6_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D6_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D6_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D6_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D6_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d6_limb_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<BTreeMap<String, bool>, String> {
    let value = r23d3_foot_contacts(robot, compiled)?;
    let object = value
        .as_object()
        .ok_or_else(|| "QSDK_R23D6_RAP_CONTACT_PROJECTION_INVALID".to_owned())?;
    object
        .iter()
        .map(|(limb_id, contact)| {
            contact
                .as_bool()
                .map(|present| (limb_id.clone(), present))
                .ok_or_else(|| format!("QSDK_R23D6_RAP_CONTACT_VALUE_INVALID:{limb_id}"))
        })
        .collect()
}

fn r23d6_trace_row(
    cell: &R23D6Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_application_count: u64,
) -> Result<Value, String> {
    let (phase_id, controller_semantic_step, heading_multiplier) = r23d6_phase(trace_step);
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let contacts = r23d6_limb_contacts(robot, compiled)?;
    let passive = phase_id == "passive_zero_actuation_settle";
    let restoration = phase_id.starts_with("terminal_");
    Ok(json!({
        "schema_version": R23D6_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_semantic_step,
        "desired_heading_offset_rad":
            heading_multiplier * cell.turn_heading_offset_rad,
        "measured_yaw_rad": yaw_rad(robot),
        "torso_height_m": torso.translation().y as f64,
        "torso_tilt_rad": up.y.clamp(-1.0, 1.0).acos() as f64,

        "torso_ground_contact": robot.torso_ground_contact(),
        "ordered_foot_contacts": contacts,
        "actuator_command_count": if passive { 0 } else { R23D3_ACTUATOR_COUNT },
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": if passive {
            "passive_zero_actuation_v1"
        } else if restoration {
            R23D6_RESTORATION_POLICY_ID
        } else {
            "balanced_wave_turning_v1"
        },
        "restoration_receipt_present": restoration,
    }))
}

fn r23d6_validate_restoration_composition(
    composition: &QsdkContactRestorationComposition,
    pre_step_contacts: &BTreeMap<String, bool>,
    independent_pose_memory: &mut BTreeMap<String, f64>,
) -> Result<(u64, f64), String> {
    let receipt = &composition.receipt;
    if receipt["policy_id"] != R23D6_RESTORATION_POLICY_ID
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != 8.0
        || receipt["pose_hold_rate_damping"] != 0.65
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != R23D6_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || receipt["damped_least_squares_lambda_m"] != 0.04
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != R23D6_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
    {
        return Err("QSDK_R23D6_RAP_RESTORATION_RECEIPT_IDENTITY_INVALID".to_owned());
    }
    let limbs = receipt["ordered_limb_solutions"]
        .as_array()
        .filter(|rows| rows.len() == 4)
        .ok_or_else(|| "QSDK_R23D6_RAP_RESTORATION_LIMB_COUNT_INVALID".to_owned())?;
    let mut capture_count = 0_u64;
    let mut maximum_speed = 0.0_f64;
    let mut actuator_seen = BTreeMap::<String, bool>::new();
    for limb in limbs {
        let site_id = limb["contact_site_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D6_RAP_RESTORATION_SITE_ID_INVALID".to_owned())?;
        let contact = *pre_step_contacts
            .get(site_id)
            .ok_or_else(|| format!("QSDK_R23D6_RAP_RESTORATION_SITE_CONTACT_MISSING:{site_id}"))?;
        if limb["pre_step_contact"] != contact {
            return Err(format!(
                "QSDK_R23D6_RAP_RESTORATION_CONTACT_RECEIPT_INVALID:{site_id}"
            ));
        }
        let actuators = limb["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == 2)
            .ok_or_else(|| {
                format!("QSDK_R23D6_RAP_RESTORATION_ACTUATOR_COUNT_INVALID:{site_id}")
            })?;
        for actuator in actuators {
            let actuator_id = actuator["actuator_id"]
                .as_str()
                .ok_or_else(|| "QSDK_R23D6_RAP_RESTORATION_ACTUATOR_ID_INVALID".to_owned())?;
            if actuator_seen.insert(actuator_id.to_owned(), true).is_some() {
                return Err(format!(
                    "QSDK_R23D6_RAP_RESTORATION_ACTUATOR_DUPLICATE:{actuator_id}"
                ));
            }
            let desired_speed = actuator["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| format!("QSDK_R23D6_RAP_RESTORATION_SPEED_INVALID:{actuator_id}"))?;
            maximum_speed = maximum_speed.max(desired_speed.abs());
            if maximum_speed > R23D6_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S + TOLERANCE
                || !actuator["portable_heading_target_delta_rad"]
                    .as_f64()
                    .is_some_and(|value| value.is_finite())
            {
                return Err(format!(
                    "QSDK_R23D6_RAP_RESTORATION_COMMAND_INVALID:{actuator_id}"
                ));
            }
            let capture_activated =
                actuator["pose_capture_activated"]
                    .as_bool()
                    .ok_or_else(|| {
                        format!("QSDK_R23D6_RAP_RESTORATION_CAPTURE_INVALID:{actuator_id}")
                    })?;
            if contact {
                let neutral = actuator["neutral_joint_position_rad"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .ok_or_else(|| {
                        format!("QSDK_R23D6_RAP_RESTORATION_NEUTRAL_INVALID:{actuator_id}")
                    })?;
                let expected_capture = !independent_pose_memory.contains_key(actuator_id);
                if capture_activated != expected_capture {
                    return Err(format!(
                        "QSDK_R23D6_RAP_RESTORATION_CAPTURE_TRANSITION_INVALID:{actuator_id}"
                    ));
                }
                if expected_capture {
                    independent_pose_memory.insert(actuator_id.to_owned(), neutral);
                    capture_count += 1;
                } else if (independent_pose_memory[actuator_id] - neutral).abs() > TOLERANCE {
                    return Err(format!(
                        "QSDK_R23D6_RAP_RESTORATION_NEUTRAL_CHANGED:{actuator_id}"
                    ));
                }
            } else {
                if capture_activated || actuator["neutral_joint_position_rad"] != Value::Null {
                    return Err(format!(
                        "QSDK_R23D6_RAP_RESTORATION_MISSING_LIMB_CAPTURED:{actuator_id}"
                    ));
                }
                independent_pose_memory.remove(actuator_id);
            }
        }
    }
    if actuator_seen.len() != R23D3_ACTUATOR_COUNT as usize
        || receipt["pose_memory_actuator_count"] != independent_pose_memory.len() as u64
    {
        return Err("QSDK_R23D6_RAP_RESTORATION_MEMORY_COUNT_INVALID".to_owned());
    }
    Ok((capture_count, maximum_speed))
}

pub fn run_qsdk_r23d6_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d6_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D6_FAILURE_SCHEMA,
            "campaign_id": R23D6_CAMPAIGN_ID,
            "gate_id": R23D6_GATE_ID,
            "stage_id": stage_id,
            "engine_id": R23D6_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d6_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d6_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D6_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d6_contract().map_err(&before_world)?;
    let attempt_root = r23d6_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight = run_qsdk_r23d6_rapier_preflight(stage_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D6_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The attempt boundary is immediately before the one native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d6_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d6_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d6_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d6_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut restoration_memory = QsdkPoseHoldRestorationMemory::default();
    let mut independent_pose_memory = BTreeMap::<String, f64>::new();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D6_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;

    let mut native_actuation_application_count = 0_u64;
    let passive_native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut restoration_receipt_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut captured_pose_memory_transition_count = 0_u64;
    let captured_pose_memory_transition_failure_count = 0_u64;
    let mut heading_correction_receipt_count = 0_u64;
    let mut maximum_restoration_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut first_all_four_contact_restoration_step = None::<u64>;
    let mut consecutive_all_four_contact_hold_step_count = 0_u64;
    let mut maximum_consecutive_all_four_contact_hold_step_count = 0_u64;

    for semantic_step in 0..R23D6_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D6_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d6_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D6_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D6_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d6_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D6_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d6_trace_row(&cell, semantic_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for restoration_step in 0..R23D6_RESTORATION_STEPS {
        let trace_step = R23D6_CONTROLLER_STEPS + restoration_step;
        let state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
        let command =
            r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if output.actuation.receipt.semantic_step != trace_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
            || !oracle_failures.is_empty()
        {
            return Err(settled_failure(format!(
                "QSDK_R23D6_RAP_RESTORATION_CONTROLLER_INVALID:{}",
                oracle_failures.join(",")
            )));
        }
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let pre_step_contacts = robot.contacts(&compiled);
        let stability_state = robot
            .bw19v_stability_state(&compiled, trace_step)
            .map_err(&settled_failure)?;
        let kinematics = robot
            .bw19v_endpoint_kinematics(&compiled, &stability_state)
            .map_err(&settled_failure)?;
        let composition = compose_qsdk_contact_restoration(
            &compiled,
            &output.actuation,
            &state,
            &pre_step_contacts,
            &kinematics,
            &mut restoration_memory,
        )
        .map_err(&settled_failure)?;
        if composition.receipt["semantic_step"] != trace_step {
            return Err(settled_failure(
                "QSDK_R23D6_RAP_RESTORATION_STEP_INVALID".to_owned(),
            ));
        }
        let (capture_count, step_maximum_speed) = r23d6_validate_restoration_composition(
            &composition,
            &pre_step_contacts,
            &mut independent_pose_memory,
        )
        .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        composition
            .host_mapping
            .validate(
                &compiled.morphology,
                &composition.canonical_actuation,
                &host_profile,
            )
            .map_err(|error| {
                settled_failure(format!(
                    "QSDK_R23D6_RAP_RESTORATION_HOST_MAPPING_INVALID:{error}"
                ))
            })?;
        restoration_receipt_count += 1;
        heading_correction_receipt_count += 1;
        captured_pose_memory_transition_count += capture_count;
        maximum_restoration_joint_speed = maximum_restoration_joint_speed.max(step_maximum_speed);
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d6_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let all_four_contacts = contacts.values().all(|contact| *contact);
        if all_four_contacts && first_all_four_contact_restoration_step.is_none() {
            first_all_four_contact_restoration_step = Some(restoration_step);
        }
        if restoration_step >= R23D6_CONTACT_ACQUISITION_STEPS {
            if all_four_contacts {
                consecutive_all_four_contact_hold_step_count += 1;
                maximum_consecutive_all_four_contact_hold_step_count =
                    maximum_consecutive_all_four_contact_hold_step_count
                        .max(consecutive_all_four_contact_hold_step_count);
            } else {
                consecutive_all_four_contact_hold_step_count = 0;
            }
        }
        trace_rows.push(
            r23d6_trace_row(&cell, trace_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for passive_step in 0..R23D6_PASSIVE_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        let tilt = up.y.clamp(-1.0, 1.0).acos() as f64;
        let height = torso.translation().y as f64;
        let yaw = yaw_rad(&robot);
        nonfinite_observation_count +=
            u64::from(!tilt.is_finite() || !height.is_finite() || !yaw.is_finite());
        maximum_tilt_rad = maximum_tilt_rad.max(tilt);
        minimum_torso_height_m = minimum_torso_height_m.min(height);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        trace_rows.push(
            r23d6_trace_row(
                &cell,
                R23D6_ACTIVE_STEPS + passive_step,
                &robot,
                &compiled,
                0,
            )
            .map_err(&settled_failure)?,
        );
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D6_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d6_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D6_REPORT_SCHEMA,
        "campaign_id": R23D6_CAMPAIGN_ID,
        "gate_id": R23D6_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D6_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D6_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D6_RESTORATION_STEPS,
            "passive_settle_step_count": R23D6_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D6_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D6_RESTORATION_STEPS,
            "passive_settle_step_count": R23D6_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "restoration_receipt_count": restoration_receipt_count,
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "first_all_four_contact_restoration_step":
                first_all_four_contact_restoration_step
                    .unwrap_or(R23D6_CONTACT_ACQUISITION_STEPS),
            "consecutive_all_four_contact_hold_step_count":
                maximum_consecutive_all_four_contact_hold_step_count,
            "captured_pose_memory_transition_count": captured_pose_memory_transition_count,
            "captured_pose_memory_transition_failure_count":
                captured_pose_memory_transition_failure_count,
            "maximum_absolute_restoration_joint_velocity_rad_s":
                maximum_restoration_joint_speed,
            "heading_correction_receipt_count": heading_correction_receipt_count,
            "passive_settle_trace_row_count": R23D6_PASSIVE_SETTLE_STEPS,
        },
        "godot_execution_predicates": Value::Null,
        "claims": r23d6_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d6_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D6_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
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

// ---------------------------------------------------------------------------
// Distinct prospective R23D3 implementation.  Nothing below reopens R23D2.

const R23D3_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d3_phase_balanced_preregistration_v1.json");
const R23D3_CAMPAIGN_ID: &str = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT";
const R23D3_GATE_ID: &str = "QSDK-R23D3";
const R23D3_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d3_rapier_worker_preflight_v1";
const R23D3_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d3_engine_cell_report_v1";
const R23D3_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d3_worker_failure_v1";
const R23D3_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1";
const R23D3_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d3_trace_retention_v1";
const R23D3_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d3_physical_freeze_v1";
const R23D3_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d3_attempt_v1";
const R23D3_CLOSURE_PATH: &str = "sdk/turning/r23d3_physical_closure_v1.json";
const R23D3_ENGINE_ID: &str = "rapier_parry";
const R23D3_ACTUATOR_COUNT: u64 = 8;
const R23D3_TURN_DURATION_STEPS: u64 = 1_200;
const R23D3_RECOVERY_DURATION_STEPS: u64 = 600;

const R23D3_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D3_FREEZE";
const R23D3_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D3_ATTEMPT";
const R23D3_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D3_TOKEN";
const R23D3_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D3_STAGE";
const R23D3_CELL_ENV: &str = "SPORESPORE_QSDK_R23D3_CELL";
const R23D3_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D3_ENGINE";
const R23D3_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT";
const R23D3_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D3_PYTHON";
const R23D3_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D3_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D3Cell {
    stage_id: String,
    cell_id: String,
    onset_id: String,
    turn_start_semantic_step: u64,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

#[derive(Debug, Clone)]
struct R23D3Schedule {
    segment_id: &'static str,
    heading_offset_rad: f64,
    desired_heading_rad: f64,
}

fn r23d3_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d3_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D3_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D3_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1"
        && contract["campaign_id"] == R23D3_CAMPAIGN_ID
        && contract["gate_id"] == R23D3_GATE_ID
        && contract["fixture"]["morphology_id"] == MORPHOLOGY_ID
        && contract["fixture"]["selected_policy_id"] == POLICY_ID
        && contract["fixture"]["selected_policy_digest"] == POLICY_DIGEST
        && contract["fixture"]["campaign_seed"] == CAMPAIGN_SEED
        && contract["fixture"]["physics_hz"] == PHYSICS_HZ
        && contract["fixture"]["authored_sliding_friction"] == AUTHORED_FRICTION
        && contract["command_schedule"]["controller_semantic_step_count"] == CONTROLLER_STEPS
        && contract["command_schedule"]["turn_duration_steps"] == R23D3_TURN_DURATION_STEPS
        && contract["command_schedule"]["all_engine_physical_workers_must_execute_exact_fixed_controller_horizon"]
            == true
        && contract["authorization"]["physical_execution_authorized"] == false;
    if !exact {
        return Err("QSDK_R23D3_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d3_onset_step(onset_id: &str) -> Option<u64> {
    match onset_id {
        "onset_600" => Some(600),
        "onset_690" => Some(690),
        "onset_780" => Some(780),
        "onset_870" => Some(870),
        _ => None,
    }
}

fn r23d3_arm_offset(arm_id: &str) -> Option<f64> {
    match arm_id {
        "reference_zero" => Some(0.0),
        "positive_heading" => Some(0.2),
        "negative_heading" => Some(-0.2),
        _ => None,
    }
}

fn r23d3_cell(stage_id: &str, onset_id: &str, arm_id: &str) -> Result<R23D3Cell, String> {
    let onset_step = r23d3_onset_step(onset_id)
        .ok_or_else(|| format!("QSDK_R23D3_RAP_ONSET_UNKNOWN:{onset_id}"))?;
    let offset =
        r23d3_arm_offset(arm_id).ok_or_else(|| format!("QSDK_R23D3_RAP_ARM_UNKNOWN:{arm_id}"))?;
    let declared = match stage_id {
        "mujoco_onset_screen" => false,
        "three_engine_confirmation" => true,
        _ => false,
    };
    if !declared {
        return Err(format!(
            "QSDK_R23D3_RAP_CELL_IDENTITY_INVALID:{stage_id}:{onset_id}:{arm_id}"
        ));
    }
    Ok(R23D3Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D3_ENGINE_ID}__{onset_id}__{arm_id}"),
        onset_id: onset_id.to_owned(),
        turn_start_semantic_step: onset_step,
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad: offset,
    })
}

fn r23d3_schedule(
    cell: &R23D3Cell,
    semantic_step: u64,
    reference_heading_rad: f64,
) -> R23D3Schedule {
    let turn_end = cell.turn_start_semantic_step + R23D3_TURN_DURATION_STEPS;
    let recovery_end = turn_end + R23D3_RECOVERY_DURATION_STEPS;
    let (segment_id, offset) = if semantic_step < cell.turn_start_semantic_step {
        ("reference_warmup", 0.0)
    } else if semantic_step < turn_end {
        ("commanded_turn", cell.turn_heading_offset_rad)
    } else if semantic_step < recovery_end {
        ("reference_recovery", 0.0)
    } else {
        ("after_declared_schedule", 0.0)
    };
    R23D3Schedule {
        segment_id,
        heading_offset_rad: offset,
        desired_heading_rad: wrap_angle(reference_heading_rad + offset),
    }
}

fn r23d3_motion_command(
    semantic_step: u64,
    phase_progression_mode: PhaseProgressionMode,
    schedule: &R23D3Schedule,
) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("qsdk_r23d3_heading_{semantic_step}_{}", schedule.segment_id),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(schedule.desired_heading_rad),
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

fn r23d3_expected_segment_counts(cell: &R23D3Cell) -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("reference_warmup", cell.turn_start_semantic_step),
        ("commanded_turn", R23D3_TURN_DURATION_STEPS),
        ("reference_recovery", R23D3_RECOVERY_DURATION_STEPS),
        (
            "after_declared_schedule",
            CONTROLLER_STEPS
                - cell.turn_start_semantic_step
                - R23D3_TURN_DURATION_STEPS
                - R23D3_RECOVERY_DURATION_STEPS,
        ),
    ])
}

pub fn run_qsdk_r23d3_rapier_preflight(
    stage_id: &str,
    onset_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    let _contract = r23d3_contract()?;
    let cell = r23d3_cell(stage_id, onset_id, arm_id)?;
    let inherited = run_qsdk_r23d2_rapier_preflight(arm_id)?;
    let mut counts = BTreeMap::from([
        ("reference_warmup", 0_u64),
        ("commanded_turn", 0_u64),
        ("reference_recovery", 0_u64),
        ("after_declared_schedule", 0_u64),
    ]);
    for semantic_step in 0..CONTROLLER_STEPS {
        let schedule = r23d3_schedule(&cell, semantic_step, 0.0);
        *counts
            .get_mut(schedule.segment_id)
            .ok_or_else(|| "QSDK_R23D3_RAP_SEGMENT_UNKNOWN".to_owned())? += 1;
    }
    if counts != r23d3_expected_segment_counts(&cell)
        || inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["native_command_count"] != 64
        || inherited["predicate_negative_control_count"] != 35
    {
        return Err("QSDK_R23D3_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D3_PREFLIGHT_SCHEMA,
        "campaign_id": R23D3_CAMPAIGN_ID,
        "gate_id": R23D3_GATE_ID,
        "engine_id": R23D3_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D3_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d2_zero_world_boundary_sha256": raw_sha256(
            include_bytes!("qsdk_r23d2_heading_response.rs"),
        ),
        "inherited_native_mapping_canary_count": inherited["canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["predicate_negative_control_count"],
        "segment_counts": counts,
        "fixed_controller_horizon_step_count": CONTROLLER_STEPS,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d3_failure(
    cell: &R23D3Cell,
    source_commit: &str,
    failure_stage: &str,
    code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D3_FAILURE_SCHEMA,
        "campaign_id": R23D3_CAMPAIGN_ID,
        "gate_id": R23D3_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D3_ENGINE_ID,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": null,
        "godot_execution_predicates": null,
        "claims": r23d3_claims(),
    })
}

fn r23d3_repo_root() -> Result<std::path::PathBuf, String> {
    std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .map_err(|error| format!("QSDK_R23D3_RAP_REPO_ROOT_UNREADABLE:{error}"))
}

fn r23d3_source_bindings_exact(freeze: &Value) -> bool {
    let required = BTreeMap::from([
        (
            "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
            raw_sha256(include_bytes!("qsdk_r23d3_phase_balanced.rs")),
        ),
        (
            "sdk/adapters/rapier/src/qsdk_r23d2_heading_response.rs",
            raw_sha256(include_bytes!("qsdk_r23d2_heading_response.rs")),
        ),
        (
            "sdk/turning/r23d3_phase_balanced_preregistration_v1.json",
            raw_sha256(R23D3_PREREGISTRATION_RAW.as_bytes()),
        ),
        (
            "sdk/turning/r23d3_physical_evaluator.py",
            raw_sha256(include_bytes!(
                "../../../turning/r23d3_physical_evaluator.py"
            )),
        ),
        (
            "sdk/publish_qsdk_r23d3_trace.ps1",
            raw_sha256(include_bytes!("../../../publish_qsdk_r23d3_trace.ps1")),
        ),
    ]);
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    required.iter().all(|(path, digest)| {
        bindings
            .iter()
            .any(|binding| binding["path"] == *path && binding["raw_sha256"] == digest.as_str())
    })
}

fn r23d3_physical_authorization(
    cell: &R23D3Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D3_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D3_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D3_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D3_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D3_TOKEN_ENV).unwrap_or_default();
    let attempt_root_raw = env::var(R23D3_ATTEMPT_ROOT_ENV).unwrap_or_default();
    if freeze_path.is_empty()
        || attempt_path.is_empty()
        || attempt_root_raw.is_empty()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D3_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D3_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw = fs::read_to_string(&attempt_path)
        .map_err(|_| "QSDK_R23D3_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D3_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_str(&attempt_raw)
        .map_err(|_| "QSDK_R23D3_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let attempt_root = std::path::PathBuf::from(&attempt_root_raw)
        .canonicalize()
        .map_err(|_| "QSDK_R23D3_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D3_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence");
    if !attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D3_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_ids = if cell.stage_id == "mujoco_onset_screen" {
        &attempt["ordered_stage_a_cell_ids"]
    } else {
        &attempt["ordered_stage_b_cell_ids"]
    };
    let cell_declared = stage_ids
        .as_array()
        .is_some_and(|items| items.iter().any(|item| item == &cell.cell_id));
    let exact = freeze["schema_version"] == R23D3_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D3_CAMPAIGN_ID
        && freeze["gate_id"] == R23D3_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D3_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d3_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D3_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D3_CAMPAIGN_ID
        && attempt["gate_id"] == R23D3_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && attempt["attempt_root"] == attempt_root_raw
        && env::var(R23D3_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D3_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D3_ENGINE_ENV).unwrap_or_default() == R23D3_ENGINE_ID
        && cell_declared
        && (cell.stage_id != "three_engine_confirmation"
            || attempt["selected_onset_id"] == cell.onset_id);
    if !exact {
        return Err("QSDK_R23D3_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(attempt_root)
}

fn r23d3_limb_phase(memory: &BalancedWaveControllerMemory) -> Result<Value, String> {
    let expected = [
        ("rear_left", 0_u64),
        ("front_left", 90_u64),
        ("rear_right", 180_u64),
        ("front_right", 270_u64),
    ];
    if memory.ordered_limb_memory.len() != expected.len() {
        return Err("QSDK_R23D3_RAP_LIMB_MEMORY_COUNT_INVALID".to_owned());
    }
    let mut rows = Vec::<Value>::new();
    for (limb, (expected_id, phase_offset)) in memory.ordered_limb_memory.iter().zip(expected) {
        if limb.limb_id != expected_id {
            return Err("QSDK_R23D3_RAP_LIMB_MEMORY_ORDER_INVALID".to_owned());
        }
        rows.push(json!({
            "limb_id": expected_id,
            "gait_step": limb.gait_step,
            "local_phase_step": (limb.gait_step + 360 - phase_offset) % 360,
            "release_hold_step_count": limb.release_hold_step_count,
        }));
    }
    Ok(Value::Array(rows))
}

fn r23d3_foot_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<Value, String> {
    let mut contacts = Map::<String, Value>::new();
    for limb in &compiled.morphology.morphology_spec.limbs {
        let site_id = &limb.ordered_contact_site_ids[0];
        let site = compiled
            .morphology
            .morphology_spec
            .contact_sites
            .iter()
            .find(|site| site.contact_site_id == *site_id)
            .ok_or_else(|| "QSDK_R23D3_RAP_CONTACT_SITE_MISSING".to_owned())?;
        contacts.insert(limb.limb_id.clone(), json!(robot.contact(&site.body_id)));
    }
    Ok(Value::Object(contacts))
}

fn r23d3_retain_trace(
    cell: &R23D3Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D3_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D3_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D3_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d3_physical_evaluator.py");
    let python = env::var(R23D3_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D3_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D3_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D3_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D3_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D3_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D3_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D3_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

pub fn run_qsdk_r23d3_rapier_physical(
    stage_id: &str,
    onset_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d3_cell(stage_id, onset_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D3_FAILURE_SCHEMA,
            "campaign_id": R23D3_CAMPAIGN_ID,
            "gate_id": R23D3_GATE_ID,
            "engine_id": R23D3_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d3_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d3_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D3_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d3_contract().map_err(&before_world)?;
    let attempt_root = r23d3_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight =
        run_qsdk_r23d3_rapier_preflight(stage_id, onset_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;

    // This is the physical attempt boundary. Every check above opens zero
    // worlds; the attempt count increments immediately before construction.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d3_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d3_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }

    let settled_failure = |code: String| {
        r23d3_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
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
    let mut portable_impulse_violation_count = 0_u64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut trace_rows = Vec::<Value>::with_capacity(CONTROLLER_STEPS as usize);

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
        let schedule = r23d3_schedule(&cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        let limb_phase_before = r23d3_limb_phase(&memory).map_err(&settled_failure)?;
        let contacts_before = r23d3_foot_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let torso_before = &robot.world.bodies[robot.bodies["torso"]];
        let position_before = torso_before.translation();
        let up_before = torso_before.rotation() * Vector::Y;
        let tilt_before = up_before.y.clamp(-1.0, 1.0).acos() as f64;
        let yaw_before = yaw_rad(&robot);
        let torso_contact_before = robot.torso_ground_contact();
        if semantic_step == cell.turn_start_semantic_step {
            turn_start_yaw_rad = Some(yaw_before);
        }

        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D3_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d3_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D3_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D3_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
            || mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
            || mapping.independent_native_position_feedback_applied
            || mapping.native_position_stiffness != 0.0
            || mapping
                .ordered_commands
                .iter()
                .any(|entry| entry.native_target_position_rad.is_some() || entry.host_clamped)
        {
            return Err(settled_failure(
                "QSDK_R23D3_RAP_NATIVE_MAPPING_BOUNDARY_INVALID".to_owned(),
            ));
        }
        let requested = output.actuation.receipt.requested_steering_fraction;
        let held = output.actuation.receipt.held_steering_fraction;
        maximum_requested = maximum_requested.max(requested.abs());
        maximum_held = maximum_held.max(held.abs());
        portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;
        let contacts_after = r23d3_foot_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step + 1 == cell.turn_start_semantic_step + R23D3_TURN_DURATION_STEPS {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        let torso_after = &robot.world.bodies[robot.bodies["torso"]];
        let up_after = torso_after.rotation() * Vector::Y;
        let tilt_after = up_after.y.clamp(-1.0, 1.0).acos() as f64;
        maximum_tilt_rad = maximum_tilt_rad.max(tilt_after);
        minimum_torso_height_m = minimum_torso_height_m.min(torso_after.translation().y as f64);
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
                        settled_failure("QSDK_R23D3_RAP_CONTACT_SITE_MISSING".to_owned())
                    })?;
                foot_evidence
                    .get_mut(&limb.limb_id)
                    .ok_or_else(|| {
                        settled_failure("QSDK_R23D3_RAP_FOOT_EVIDENCE_MISSING".to_owned())
                    })?
                    .observe(
                        robot.contact(&site.body_id),
                        robot.contact_site_position(site),
                    );
            }
        }
        trace_rows.push(json!({
            "schema_version": R23D3_TRACE_ROW_SCHEMA,
            "cell_id": cell.cell_id,
            "semantic_step": semantic_step,
            "segment_id": schedule.segment_id,
            "desired_heading_offset_rad": schedule.heading_offset_rad,
            "measured_yaw_rad": yaw_before,
            "desired_heading_error_rad": output.actuation.receipt.desired_heading_error_rad,
            "yaw_tracking_error_rad": output.actuation.receipt.yaw_tracking_error_rad,
            "requested_steering_fraction": requested,
            "held_steering_fraction": held,
            "steering_saturated": requested.abs() >= 0.4 - TOLERANCE
                || held.abs() >= 0.4 - TOLERANCE,
            "torso_position_world_m": [
                position_before.x as f64,
                position_before.y as f64,
                position_before.z as f64,
            ],
            "torso_height_m": position_before.y as f64,
            "torso_tilt_rad": tilt_before,
            "torso_ground_contact": torso_contact_before,
            "ordered_limb_phase_before": limb_phase_before,
            "ordered_foot_contacts_before": contacts_before,
            "ordered_foot_contacts_after": contacts_after,
            "validated_portable_command_count": R23D3_ACTUATOR_COUNT,
            "native_actuation_application_count": applications,
            "oracle_passed": true,
        }));
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
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D3_RAP_TURN_YAW_WINDOW_INCOMPLETE".to_owned()))?;
    let contact_cycles_by_limb = foot_evidence
        .iter()
        .map(|(limb_id, evidence)| (limb_id.clone(), json!(evidence.contact_cycles)))
        .collect::<Map<_, _>>();
    let retention =
        r23d3_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D3_REPORT_SCHEMA,
        "campaign_id": R23D3_CAMPAIGN_ID,
        "gate_id": R23D3_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D3_ENGINE_ID,
        "onset_id": cell.onset_id,
        "turn_start_semantic_step": cell.turn_start_semantic_step,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": trace_rows.len() as u64,
            "validated_portable_command_count": portable_command_count,
            "native_actuation_application_count": native_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles_by_limb,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "safe_no_actuation_count": safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": trace_rows.len() as u64,
            "validated_portable_command_count": portable_command_count,
            "native_actuation_application_count": native_application_count,
        },
        "godot_execution_predicates": null,
        "claims": r23d3_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d3_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D3_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

// -------------------------------------------------------------------------
// Distinct prospective R23D4 implementation. Nothing below changes or
// reinterprets R23D3. R23D4 keeps the frozen onset-600 turning controller and
// adds the separately accepted PH1 terminal contact-restoration mechanism,
// followed by a genuinely passive traced settle.

const R23D4_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d4_terminal_stabilization_preregistration_v1.json");
const R23D4_CAMPAIGN_ID: &str = "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT";
const R23D4_GATE_ID: &str = "QSDK-R23D4";
const R23D4_ENGINE_ID: &str = "rapier_parry";
const R23D4_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d4_rapier_worker_preflight_v1";
const R23D4_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d4_engine_cell_report_v1";
const R23D4_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d4_worker_failure_v1";
const R23D4_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d4_turn_restore_settle_trace_row_v1";
const R23D4_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d4_trace_retention_v1";
const R23D4_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d4_physical_freeze_v1";
const R23D4_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d4_attempt_v1";
const R23D4_CLOSURE_PATH: &str = "sdk/turning/r23d4_physical_closure_v1.json";
const R23D4_STAGE_ID: &str = "three_engine_confirmation";
const R23D4_CONTROLLER_STEPS: u64 = 2_992;
const R23D4_RESTORATION_STEPS: u64 = 540;
const R23D4_CONTACT_ACQUISITION_STEPS: u64 = 180;
const R23D4_CONTACT_HOLD_STEPS: u64 = 360;
const R23D4_PASSIVE_SETTLE_STEPS: u64 = 240;
const R23D4_ACTIVE_STEPS: u64 = R23D4_CONTROLLER_STEPS + R23D4_RESTORATION_STEPS;
const R23D4_TOTAL_TRACE_STEPS: u64 = R23D4_ACTIVE_STEPS + R23D4_PASSIVE_SETTLE_STEPS;
const R23D4_RESTORATION_POLICY_ID: &str =
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1";
const R23D4_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S: f64 = 0.35;

static R23D4_RESTORATION_PREFLIGHT: OnceLock<Result<Value, String>> = OnceLock::new();

const R23D4_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D4_FREEZE";
const R23D4_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D4_ATTEMPT";
const R23D4_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D4_TOKEN";
const R23D4_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D4_STAGE";
const R23D4_CELL_ENV: &str = "SPORESPORE_QSDK_R23D4_CELL";
const R23D4_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D4_ENGINE";
const R23D4_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D4_ATTEMPT_ROOT";
const R23D4_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D4_PYTHON";
const R23D4_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D4_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D4Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

fn r23d4_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d4_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D4_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D4_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["command_and_terminal_schedule"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d4_terminal_stabilization_preregistration_v1"
        && contract["campaign_id"] == R23D4_CAMPAIGN_ID
        && contract["gate_id"] == R23D4_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && schedule["turning_controller_semantic_step_count"] == R23D4_CONTROLLER_STEPS
        && schedule["terminal_restoration_step_count"] == R23D4_RESTORATION_STEPS
        && schedule["maximum_four_contact_acquisition_steps"] == R23D4_CONTACT_ACQUISITION_STEPS
        && schedule["required_consecutive_all_four_contact_hold_steps"] == R23D4_CONTACT_HOLD_STEPS
        && schedule["passive_settle_step_count"] == R23D4_PASSIVE_SETTLE_STEPS
        && schedule["total_traced_step_count"] == R23D4_TOTAL_TRACE_STEPS
        && schedule["terminal_restoration_policy_id"] == R23D4_RESTORATION_POLICY_ID
        && schedule["maximum_absolute_restoration_joint_velocity_rad_s"]
            == R23D4_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S;
    if !exact {
        return Err("QSDK_R23D4_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d4_cell(stage_id: &str, arm_id: &str) -> Result<R23D4Cell, String> {
    if stage_id != R23D4_STAGE_ID {
        return Err(format!("QSDK_R23D4_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D4_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D4Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D4_ENGINE_ID}__onset_600__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d4_phase(trace_step: u64) -> (&'static str, Option<u64>, f64) {
    if trace_step < TURN_START_STEP {
        ("reference_warmup", Some(trace_step), 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", Some(trace_step), 1.0)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", Some(trace_step), 0.0)
    } else if trace_step < R23D4_CONTROLLER_STEPS {
        ("reference_continuation", Some(trace_step), 0.0)
    } else if trace_step < R23D4_CONTROLLER_STEPS + R23D4_CONTACT_ACQUISITION_STEPS {
        ("terminal_contact_acquisition", None, 0.0)
    } else if trace_step < R23D4_ACTIVE_STEPS {
        ("terminal_captured_pose_hold", None, 0.0)
    } else {
        ("passive_zero_actuation_settle", None, 0.0)
    }
}

fn r23d4_expected_phase_counts() -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("commanded_turn", 1_200),
        ("passive_zero_actuation_settle", R23D4_PASSIVE_SETTLE_STEPS),
        ("reference_continuation", 592),
        ("reference_recovery", 600),
        ("reference_warmup", 600),
        ("terminal_captured_pose_hold", R23D4_CONTACT_HOLD_STEPS),
        (
            "terminal_contact_acquisition",
            R23D4_CONTACT_ACQUISITION_STEPS,
        ),
    ])
}

pub fn run_qsdk_r23d4_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let _contract = r23d4_contract()?;
    let cell = r23d4_cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d3_rapier_preflight(R23D4_STAGE_ID, "onset_600", arm_id)?;
    let restoration = R23D4_RESTORATION_PREFLIGHT
        .get_or_init(run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight)
        .clone()?;
    let mut phase_counts = BTreeMap::<&'static str, u64>::new();
    for trace_step in 0..R23D4_TOTAL_TRACE_STEPS {
        *phase_counts.entry(r23d4_phase(trace_step).0).or_default() += 1;
    }
    if inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["inherited_predicate_negative_control_count"] != 35
        || inherited["inherited_native_mapping_canary_count"] != 7
        || restoration["ok"] != true
        || restoration["world_build_count"] != 0
        || restoration["all_negative_controls_rejected"] != true
        || phase_counts != r23d4_expected_phase_counts()
    {
        return Err("QSDK_R23D4_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D4_PREFLIGHT_SCHEMA,
        "campaign_id": R23D4_CAMPAIGN_ID,
        "gate_id": R23D4_GATE_ID,
        "engine_id": R23D4_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D4_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d3_native_mapping_canary_count":
            inherited["inherited_native_mapping_canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["inherited_predicate_negative_control_count"],
        "borrowed_ph1_restoration_negative_control_count": restoration["negative_control_count"],
        "borrowed_ph1_real_shaped_restoration_canary_passed": restoration["ok"],
        "fixed_controller_horizon_step_count": R23D4_CONTROLLER_STEPS,
        "fixed_terminal_restoration_step_count": R23D4_RESTORATION_STEPS,
        "fixed_passive_settle_step_count": R23D4_PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": R23D4_TOTAL_TRACE_STEPS,
        "trace_phase_counts": phase_counts,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d4_failure(
    cell: &R23D4Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D4_FAILURE_SCHEMA,
        "campaign_id": R23D4_CAMPAIGN_ID,
        "gate_id": R23D4_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D4_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": Value::Null,
        "godot_execution_predicates": Value::Null,
        "claims": r23d4_claims(),
    })
}

fn r23d4_source_bindings_exact(freeze: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let required_paths = [
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
        "sdk/adapters/rapier/src/bw19v_velocity_only_pose_hold_restoration_ph1.rs",
        "sdk/adapters/rapier/src/bin/qsdk_r23d4_terminal_stabilization.rs",
        "sdk/turning/r23d4_terminal_stabilization_preregistration_v1.json",
        "sdk/turning/r23d4_physical_evaluator.py",
        "sdk/publish_qsdk_r23d4_trace.ps1",
    ];
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    required_paths.iter().all(|path| {
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        let digest = raw_sha256(&bytes);
        bindings
            .iter()
            .any(|entry| entry["path"] == *path && entry["raw_sha256"] == digest)
    })
}

fn r23d4_physical_authorization(
    cell: &R23D4Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D4_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D4_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D4_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D4_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D4_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D4_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D4_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D4_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D4_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D4_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D4_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D4_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D4_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D4_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D4_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D4_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D4_CAMPAIGN_ID
        && freeze["gate_id"] == R23D4_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D4_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d4_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D4_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D4_CAMPAIGN_ID
        && attempt["gate_id"] == R23D4_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D4_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D4_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D4_ENGINE_ENV).unwrap_or_default() == R23D4_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D4_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

fn r23d4_retain_trace(
    cell: &R23D4Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D4_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D4_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D4_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d4_physical_evaluator.py");
    let python = env::var(R23D4_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D4_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D4_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D4_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D4_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D4_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D4_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D4_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d4_limb_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<BTreeMap<String, bool>, String> {
    let value = r23d3_foot_contacts(robot, compiled)?;
    let object = value
        .as_object()
        .ok_or_else(|| "QSDK_R23D4_RAP_CONTACT_PROJECTION_INVALID".to_owned())?;
    object
        .iter()
        .map(|(limb_id, contact)| {
            contact
                .as_bool()
                .map(|present| (limb_id.clone(), present))
                .ok_or_else(|| format!("QSDK_R23D4_RAP_CONTACT_VALUE_INVALID:{limb_id}"))
        })
        .collect()
}

fn r23d4_trace_row(
    cell: &R23D4Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_application_count: u64,
) -> Result<Value, String> {
    let (phase_id, controller_semantic_step, heading_multiplier) = r23d4_phase(trace_step);
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let contacts = r23d4_limb_contacts(robot, compiled)?;
    let passive = phase_id == "passive_zero_actuation_settle";
    let restoration = phase_id.starts_with("terminal_");
    Ok(json!({
        "schema_version": R23D4_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_semantic_step,
        "desired_heading_offset_rad":
            heading_multiplier * cell.turn_heading_offset_rad,
        "measured_yaw_rad": yaw_rad(robot),
        "torso_height_m": torso.translation().y as f64,
        "torso_tilt_rad": up.y.clamp(-1.0, 1.0).acos() as f64,
        "torso_ground_contact": robot.torso_ground_contact(),
        "ordered_foot_contacts": contacts,
        "actuator_command_count": if passive { 0 } else { R23D3_ACTUATOR_COUNT },
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": if passive {
            "passive_zero_actuation_v1"
        } else if restoration {
            R23D4_RESTORATION_POLICY_ID
        } else {
            "balanced_wave_turning_v1"
        },
        "restoration_receipt_present": restoration,
    }))
}

fn r23d4_validate_restoration_composition(
    composition: &QsdkContactRestorationComposition,
    pre_step_contacts: &BTreeMap<String, bool>,
    independent_pose_memory: &mut BTreeMap<String, f64>,
) -> Result<(u64, f64), String> {
    let receipt = &composition.receipt;
    if receipt["policy_id"] != R23D4_RESTORATION_POLICY_ID
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != 8.0
        || receipt["pose_hold_rate_damping"] != 0.65
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != R23D4_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || receipt["damped_least_squares_lambda_m"] != 0.04
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != R23D4_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
    {
        return Err("QSDK_R23D4_RAP_RESTORATION_RECEIPT_IDENTITY_INVALID".to_owned());
    }
    let limbs = receipt["ordered_limb_solutions"]
        .as_array()
        .filter(|rows| rows.len() == 4)
        .ok_or_else(|| "QSDK_R23D4_RAP_RESTORATION_LIMB_COUNT_INVALID".to_owned())?;
    let mut capture_count = 0_u64;
    let mut maximum_speed = 0.0_f64;
    let mut actuator_seen = BTreeMap::<String, bool>::new();
    for limb in limbs {
        let site_id = limb["contact_site_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D4_RAP_RESTORATION_SITE_ID_INVALID".to_owned())?;
        let contact = *pre_step_contacts
            .get(site_id)
            .ok_or_else(|| format!("QSDK_R23D4_RAP_RESTORATION_SITE_CONTACT_MISSING:{site_id}"))?;
        if limb["pre_step_contact"] != contact {
            return Err(format!(
                "QSDK_R23D4_RAP_RESTORATION_CONTACT_RECEIPT_INVALID:{site_id}"
            ));
        }
        let actuators = limb["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == 2)
            .ok_or_else(|| {
                format!("QSDK_R23D4_RAP_RESTORATION_ACTUATOR_COUNT_INVALID:{site_id}")
            })?;
        for actuator in actuators {
            let actuator_id = actuator["actuator_id"]
                .as_str()
                .ok_or_else(|| "QSDK_R23D4_RAP_RESTORATION_ACTUATOR_ID_INVALID".to_owned())?;
            if actuator_seen.insert(actuator_id.to_owned(), true).is_some() {
                return Err(format!(
                    "QSDK_R23D4_RAP_RESTORATION_ACTUATOR_DUPLICATE:{actuator_id}"
                ));
            }
            let desired_speed = actuator["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| format!("QSDK_R23D4_RAP_RESTORATION_SPEED_INVALID:{actuator_id}"))?;
            maximum_speed = maximum_speed.max(desired_speed.abs());
            if maximum_speed > R23D4_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S + TOLERANCE
                || !actuator["portable_heading_target_delta_rad"]
                    .as_f64()
                    .is_some_and(|value| value.is_finite())
            {
                return Err(format!(
                    "QSDK_R23D4_RAP_RESTORATION_COMMAND_INVALID:{actuator_id}"
                ));
            }
            let capture_activated =
                actuator["pose_capture_activated"]
                    .as_bool()
                    .ok_or_else(|| {
                        format!("QSDK_R23D4_RAP_RESTORATION_CAPTURE_INVALID:{actuator_id}")
                    })?;
            if contact {
                let neutral = actuator["neutral_joint_position_rad"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .ok_or_else(|| {
                        format!("QSDK_R23D4_RAP_RESTORATION_NEUTRAL_INVALID:{actuator_id}")
                    })?;
                let expected_capture = !independent_pose_memory.contains_key(actuator_id);
                if capture_activated != expected_capture {
                    return Err(format!(
                        "QSDK_R23D4_RAP_RESTORATION_CAPTURE_TRANSITION_INVALID:{actuator_id}"
                    ));
                }
                if expected_capture {
                    independent_pose_memory.insert(actuator_id.to_owned(), neutral);
                    capture_count += 1;
                } else if (independent_pose_memory[actuator_id] - neutral).abs() > TOLERANCE {
                    return Err(format!(
                        "QSDK_R23D4_RAP_RESTORATION_NEUTRAL_CHANGED:{actuator_id}"
                    ));
                }
            } else {
                if capture_activated || actuator["neutral_joint_position_rad"] != Value::Null {
                    return Err(format!(
                        "QSDK_R23D4_RAP_RESTORATION_MISSING_LIMB_CAPTURED:{actuator_id}"
                    ));
                }
                independent_pose_memory.remove(actuator_id);
            }
        }
    }
    if actuator_seen.len() != R23D3_ACTUATOR_COUNT as usize
        || receipt["pose_memory_actuator_count"] != independent_pose_memory.len() as u64
    {
        return Err("QSDK_R23D4_RAP_RESTORATION_MEMORY_COUNT_INVALID".to_owned());
    }
    Ok((capture_count, maximum_speed))
}

pub fn run_qsdk_r23d4_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d4_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D4_FAILURE_SCHEMA,
            "campaign_id": R23D4_CAMPAIGN_ID,
            "gate_id": R23D4_GATE_ID,
            "stage_id": stage_id,
            "engine_id": R23D4_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d4_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d4_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D4_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d4_contract().map_err(&before_world)?;
    let attempt_root = r23d4_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight = run_qsdk_r23d4_rapier_preflight(stage_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D4_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The attempt boundary is immediately before the one native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d4_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d4_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d4_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d4_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut restoration_memory = QsdkPoseHoldRestorationMemory::default();
    let mut independent_pose_memory = BTreeMap::<String, f64>::new();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D4_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_actuation_application_count = 0_u64;
    let passive_native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut restoration_receipt_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut captured_pose_memory_transition_count = 0_u64;
    let captured_pose_memory_transition_failure_count = 0_u64;
    let mut heading_correction_receipt_count = 0_u64;
    let mut maximum_restoration_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut first_all_four_contact_restoration_step = None::<u64>;
    let mut consecutive_all_four_contact_hold_step_count = 0_u64;
    let mut maximum_consecutive_all_four_contact_hold_step_count = 0_u64;

    for semantic_step in 0..R23D4_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D4_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d4_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D4_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D4_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d4_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D4_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d4_trace_row(&cell, semantic_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for restoration_step in 0..R23D4_RESTORATION_STEPS {
        let trace_step = R23D4_CONTROLLER_STEPS + restoration_step;
        let state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
        let command =
            r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if output.actuation.receipt.semantic_step != trace_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
            || !oracle_failures.is_empty()
        {
            return Err(settled_failure(format!(
                "QSDK_R23D4_RAP_RESTORATION_CONTROLLER_INVALID:{}",
                oracle_failures.join(",")
            )));
        }
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let pre_step_contacts = robot.contacts(&compiled);
        let stability_state = robot
            .bw19v_stability_state(&compiled, trace_step)
            .map_err(&settled_failure)?;
        let kinematics = robot
            .bw19v_endpoint_kinematics(&compiled, &stability_state)
            .map_err(&settled_failure)?;
        let composition = compose_qsdk_contact_restoration(
            &compiled,
            &output.actuation,
            &state,
            &pre_step_contacts,
            &kinematics,
            &mut restoration_memory,
        )
        .map_err(&settled_failure)?;
        if composition.receipt["semantic_step"] != trace_step {
            return Err(settled_failure(
                "QSDK_R23D4_RAP_RESTORATION_STEP_INVALID".to_owned(),
            ));
        }
        let (capture_count, step_maximum_speed) = r23d4_validate_restoration_composition(
            &composition,
            &pre_step_contacts,
            &mut independent_pose_memory,
        )
        .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        composition
            .host_mapping
            .validate(
                &compiled.morphology,
                &composition.canonical_actuation,
                &host_profile,
            )
            .map_err(|error| {
                settled_failure(format!(
                    "QSDK_R23D4_RAP_RESTORATION_HOST_MAPPING_INVALID:{error}"
                ))
            })?;
        restoration_receipt_count += 1;
        heading_correction_receipt_count += 1;
        captured_pose_memory_transition_count += capture_count;
        maximum_restoration_joint_speed = maximum_restoration_joint_speed.max(step_maximum_speed);
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d4_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let all_four_contacts = contacts.values().all(|contact| *contact);
        if all_four_contacts && first_all_four_contact_restoration_step.is_none() {
            first_all_four_contact_restoration_step = Some(restoration_step);
        }
        if restoration_step >= R23D4_CONTACT_ACQUISITION_STEPS {
            if all_four_contacts {
                consecutive_all_four_contact_hold_step_count += 1;
                maximum_consecutive_all_four_contact_hold_step_count =
                    maximum_consecutive_all_four_contact_hold_step_count
                        .max(consecutive_all_four_contact_hold_step_count);
            } else {
                consecutive_all_four_contact_hold_step_count = 0;
            }
        }
        trace_rows.push(
            r23d4_trace_row(&cell, trace_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for passive_step in 0..R23D4_PASSIVE_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        let tilt = up.y.clamp(-1.0, 1.0).acos() as f64;
        let height = torso.translation().y as f64;
        let yaw = yaw_rad(&robot);
        nonfinite_observation_count +=
            u64::from(!tilt.is_finite() || !height.is_finite() || !yaw.is_finite());
        maximum_tilt_rad = maximum_tilt_rad.max(tilt);
        minimum_torso_height_m = minimum_torso_height_m.min(height);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        trace_rows.push(
            r23d4_trace_row(
                &cell,
                R23D4_ACTIVE_STEPS + passive_step,
                &robot,
                &compiled,
                0,
            )
            .map_err(&settled_failure)?,
        );
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D4_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d4_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D4_REPORT_SCHEMA,
        "campaign_id": R23D4_CAMPAIGN_ID,
        "gate_id": R23D4_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D4_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D4_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D4_RESTORATION_STEPS,
            "passive_settle_step_count": R23D4_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D4_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D4_RESTORATION_STEPS,
            "passive_settle_step_count": R23D4_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "restoration_receipt_count": restoration_receipt_count,
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "first_all_four_contact_restoration_step":
                first_all_four_contact_restoration_step
                    .unwrap_or(R23D4_CONTACT_ACQUISITION_STEPS),
            "consecutive_all_four_contact_hold_step_count":
                maximum_consecutive_all_four_contact_hold_step_count,
            "captured_pose_memory_transition_count": captured_pose_memory_transition_count,
            "captured_pose_memory_transition_failure_count":
                captured_pose_memory_transition_failure_count,
            "maximum_absolute_restoration_joint_velocity_rad_s":
                maximum_restoration_joint_speed,
            "heading_correction_receipt_count": heading_correction_receipt_count,
            "passive_settle_trace_row_count": R23D4_PASSIVE_SETTLE_STEPS,
        },
        "godot_execution_predicates": Value::Null,
        "claims": r23d4_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d4_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D4_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

// -------------------------------------------------------------------------
// Distinct prospective R23D5 implementation. Nothing below changes or
// reinterprets R23D3. R23D5 keeps the frozen onset-600 turning controller and
// adds the separately accepted PH1 terminal contact-restoration mechanism,
// followed by a genuinely passive traced settle.

const R23D5_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d5_dependency_closed_preregistration_v1.json");
const R23D5_CAMPAIGN_ID: &str =
    "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT";
const R23D5_GATE_ID: &str = "QSDK-R23D5";
const R23D5_ENGINE_ID: &str = "rapier_parry";
const R23D5_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d5_rapier_worker_preflight_v1";
const R23D5_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d5_engine_cell_report_v1";
const R23D5_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d5_worker_failure_v1";
const R23D5_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d4_turn_restore_settle_trace_row_v1";
const R23D5_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d5_trace_retention_v1";
const R23D5_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d5_physical_freeze_v1";
const R23D5_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d5_attempt_v1";
const R23D5_CLOSURE_PATH: &str = "sdk/turning/r23d5_physical_closure_v1.json";
const R23D5_STAGE_ID: &str = "three_engine_confirmation";
const R23D5_CONTROLLER_STEPS: u64 = 2_992;
const R23D5_RESTORATION_STEPS: u64 = 540;
const R23D5_CONTACT_ACQUISITION_STEPS: u64 = 180;
const R23D5_CONTACT_HOLD_STEPS: u64 = 360;
const R23D5_PASSIVE_SETTLE_STEPS: u64 = 240;
const R23D5_ACTIVE_STEPS: u64 = R23D5_CONTROLLER_STEPS + R23D5_RESTORATION_STEPS;
const R23D5_TOTAL_TRACE_STEPS: u64 = R23D5_ACTIVE_STEPS + R23D5_PASSIVE_SETTLE_STEPS;
const R23D5_RESTORATION_POLICY_ID: &str =
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1";
const R23D5_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S: f64 = 0.35;

static R23D5_RESTORATION_PREFLIGHT: OnceLock<Result<Value, String>> = OnceLock::new();

const R23D5_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D5_FREEZE";
const R23D5_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D5_ATTEMPT";
const R23D5_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D5_TOKEN";
const R23D5_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D5_STAGE";
const R23D5_CELL_ENV: &str = "SPORESPORE_QSDK_R23D5_CELL";
const R23D5_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D5_ENGINE";
const R23D5_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D5_ATTEMPT_ROOT";
const R23D5_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D5_PYTHON";
const R23D5_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D5_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D5Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

fn r23d5_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d5_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D5_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D5_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["frozen_schedule_and_gate_snapshot"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d5_dependency_closed_preregistration_v1"
        && contract["campaign_id"] == R23D5_CAMPAIGN_ID
        && contract["gate_id"] == R23D5_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && schedule["turning_controller_semantic_step_count"] == R23D5_CONTROLLER_STEPS
        && schedule["terminal_restoration_step_count"] == R23D5_RESTORATION_STEPS
        && schedule["maximum_four_contact_acquisition_steps"] == R23D5_CONTACT_ACQUISITION_STEPS
        && schedule["required_consecutive_all_four_contact_hold_steps"] == R23D5_CONTACT_HOLD_STEPS
        && schedule["passive_settle_step_count"] == R23D5_PASSIVE_SETTLE_STEPS
        && schedule["total_traced_step_count"] == R23D5_TOTAL_TRACE_STEPS
        && schedule["terminal_restoration_policy_id"] == R23D5_RESTORATION_POLICY_ID
        && schedule["maximum_absolute_restoration_joint_velocity_rad_s"]
            == R23D5_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S;
    if !exact {
        return Err("QSDK_R23D5_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d5_cell(stage_id: &str, arm_id: &str) -> Result<R23D5Cell, String> {
    if stage_id != R23D5_STAGE_ID {
        return Err(format!("QSDK_R23D5_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D5_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D5Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D5_ENGINE_ID}__onset_600__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d5_phase(trace_step: u64) -> (&'static str, Option<u64>, f64) {
    if trace_step < TURN_START_STEP {
        ("reference_warmup", Some(trace_step), 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", Some(trace_step), 1.0)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", Some(trace_step), 0.0)
    } else if trace_step < R23D5_CONTROLLER_STEPS {
        ("reference_continuation", Some(trace_step), 0.0)
    } else if trace_step < R23D5_CONTROLLER_STEPS + R23D5_CONTACT_ACQUISITION_STEPS {
        ("terminal_contact_acquisition", None, 0.0)
    } else if trace_step < R23D5_ACTIVE_STEPS {
        ("terminal_captured_pose_hold", None, 0.0)
    } else {
        ("passive_zero_actuation_settle", None, 0.0)
    }
}

fn r23d5_expected_phase_counts() -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("commanded_turn", 1_200),
        ("passive_zero_actuation_settle", R23D5_PASSIVE_SETTLE_STEPS),
        ("reference_continuation", 592),
        ("reference_recovery", 600),
        ("reference_warmup", 600),
        ("terminal_captured_pose_hold", R23D5_CONTACT_HOLD_STEPS),
        (
            "terminal_contact_acquisition",
            R23D5_CONTACT_ACQUISITION_STEPS,
        ),
    ])
}

pub fn run_qsdk_r23d5_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let _contract = r23d5_contract()?;
    let cell = r23d5_cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d3_rapier_preflight(R23D5_STAGE_ID, "onset_600", arm_id)?;
    let restoration = R23D5_RESTORATION_PREFLIGHT
        .get_or_init(run_bw19v_velocity_only_pose_hold_restoration_ph1_preflight)
        .clone()?;
    let mut phase_counts = BTreeMap::<&'static str, u64>::new();
    for trace_step in 0..R23D5_TOTAL_TRACE_STEPS {
        *phase_counts.entry(r23d5_phase(trace_step).0).or_default() += 1;
    }
    if inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["inherited_predicate_negative_control_count"] != 35
        || inherited["inherited_native_mapping_canary_count"] != 7
        || restoration["ok"] != true
        || restoration["world_build_count"] != 0
        || restoration["all_negative_controls_rejected"] != true
        || phase_counts != r23d5_expected_phase_counts()
    {
        return Err("QSDK_R23D5_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D5_PREFLIGHT_SCHEMA,
        "campaign_id": R23D5_CAMPAIGN_ID,
        "gate_id": R23D5_GATE_ID,
        "engine_id": R23D5_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D5_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d3_native_mapping_canary_count":
            inherited["inherited_native_mapping_canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["inherited_predicate_negative_control_count"],
        "borrowed_ph1_restoration_negative_control_count": restoration["negative_control_count"],
        "borrowed_ph1_real_shaped_restoration_canary_passed": restoration["ok"],
        "fixed_controller_horizon_step_count": R23D5_CONTROLLER_STEPS,
        "fixed_terminal_restoration_step_count": R23D5_RESTORATION_STEPS,
        "fixed_passive_settle_step_count": R23D5_PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": R23D5_TOTAL_TRACE_STEPS,
        "trace_phase_counts": phase_counts,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d5_failure(
    cell: &R23D5Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D5_FAILURE_SCHEMA,
        "campaign_id": R23D5_CAMPAIGN_ID,
        "gate_id": R23D5_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D5_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": Value::Null,
        "godot_execution_predicates": Value::Null,

        "claims": r23d5_claims(),
    })
}

fn r23d5_source_bindings_exact(freeze: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let required_paths = [
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
        "sdk/adapters/rapier/src/bw19v_velocity_only_pose_hold_restoration_ph1.rs",
        "sdk/adapters/rapier/src/bin/qsdk_r23d5_dependency_closed.rs",
        "sdk/turning/r23d5_dependency_closed_preregistration_v1.json",
        "sdk/turning/r23d5_physical_evaluator.py",
        "sdk/publish_qsdk_r23d5_trace.ps1",
    ];
    let Ok(contract) = r23d5_contract() else {
        return false;
    };
    let Some(declared) = contract["worker_dependency_closure_contract"]
        ["required_dependency_paths_by_worker"]["rapier_parry"]
        .as_array()
    else {
        return false;
    };
    if declared.len() != required_paths.len()
        || declared
            .iter()
            .zip(required_paths)
            .any(|(actual, expected)| actual.as_str() != Some(expected))
    {
        return false;
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    required_paths.iter().all(|path| {
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        let digest = raw_sha256(&bytes);
        bindings
            .iter()
            .any(|entry| entry["path"] == *path && entry["raw_sha256"] == digest)
    })
}

fn r23d5_physical_authorization(
    cell: &R23D5Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D5_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D5_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D5_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D5_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D5_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D5_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D5_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D5_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D5_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D5_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D5_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D5_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D5_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D5_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D5_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D5_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D5_CAMPAIGN_ID
        && freeze["gate_id"] == R23D5_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D5_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d5_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D5_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D5_CAMPAIGN_ID
        && attempt["gate_id"] == R23D5_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D5_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D5_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D5_ENGINE_ENV).unwrap_or_default() == R23D5_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D5_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

fn r23d5_retain_trace(
    cell: &R23D5Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D5_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D5_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D5_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d5_physical_evaluator.py");
    let python = env::var(R23D5_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D5_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D5_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D5_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D5_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D5_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D5_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D5_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d5_limb_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<BTreeMap<String, bool>, String> {
    let value = r23d3_foot_contacts(robot, compiled)?;
    let object = value
        .as_object()
        .ok_or_else(|| "QSDK_R23D5_RAP_CONTACT_PROJECTION_INVALID".to_owned())?;
    object
        .iter()
        .map(|(limb_id, contact)| {
            contact
                .as_bool()
                .map(|present| (limb_id.clone(), present))
                .ok_or_else(|| format!("QSDK_R23D5_RAP_CONTACT_VALUE_INVALID:{limb_id}"))
        })
        .collect()
}

fn r23d5_trace_row(
    cell: &R23D5Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_application_count: u64,
) -> Result<Value, String> {
    let (phase_id, controller_semantic_step, heading_multiplier) = r23d5_phase(trace_step);
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let contacts = r23d5_limb_contacts(robot, compiled)?;
    let passive = phase_id == "passive_zero_actuation_settle";
    let restoration = phase_id.starts_with("terminal_");
    Ok(json!({
        "schema_version": R23D5_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_semantic_step,
        "desired_heading_offset_rad":
            heading_multiplier * cell.turn_heading_offset_rad,
        "measured_yaw_rad": yaw_rad(robot),
        "torso_height_m": torso.translation().y as f64,
        "torso_tilt_rad": up.y.clamp(-1.0, 1.0).acos() as f64,

        "torso_ground_contact": robot.torso_ground_contact(),
        "ordered_foot_contacts": contacts,
        "actuator_command_count": if passive { 0 } else { R23D3_ACTUATOR_COUNT },
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": if passive {
            "passive_zero_actuation_v1"
        } else if restoration {
            R23D5_RESTORATION_POLICY_ID
        } else {
            "balanced_wave_turning_v1"
        },
        "restoration_receipt_present": restoration,
    }))
}

fn r23d5_validate_restoration_composition(
    composition: &QsdkContactRestorationComposition,
    pre_step_contacts: &BTreeMap<String, bool>,
    independent_pose_memory: &mut BTreeMap<String, f64>,
) -> Result<(u64, f64), String> {
    let receipt = &composition.receipt;
    if receipt["policy_id"] != R23D5_RESTORATION_POLICY_ID
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != 8.0
        || receipt["pose_hold_rate_damping"] != 0.65
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != R23D5_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || receipt["damped_least_squares_lambda_m"] != 0.04
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != R23D5_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
    {
        return Err("QSDK_R23D5_RAP_RESTORATION_RECEIPT_IDENTITY_INVALID".to_owned());
    }
    let limbs = receipt["ordered_limb_solutions"]
        .as_array()
        .filter(|rows| rows.len() == 4)
        .ok_or_else(|| "QSDK_R23D5_RAP_RESTORATION_LIMB_COUNT_INVALID".to_owned())?;
    let mut capture_count = 0_u64;
    let mut maximum_speed = 0.0_f64;
    let mut actuator_seen = BTreeMap::<String, bool>::new();
    for limb in limbs {
        let site_id = limb["contact_site_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D5_RAP_RESTORATION_SITE_ID_INVALID".to_owned())?;
        let contact = *pre_step_contacts
            .get(site_id)
            .ok_or_else(|| format!("QSDK_R23D5_RAP_RESTORATION_SITE_CONTACT_MISSING:{site_id}"))?;
        if limb["pre_step_contact"] != contact {
            return Err(format!(
                "QSDK_R23D5_RAP_RESTORATION_CONTACT_RECEIPT_INVALID:{site_id}"
            ));
        }
        let actuators = limb["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == 2)
            .ok_or_else(|| {
                format!("QSDK_R23D5_RAP_RESTORATION_ACTUATOR_COUNT_INVALID:{site_id}")
            })?;
        for actuator in actuators {
            let actuator_id = actuator["actuator_id"]
                .as_str()
                .ok_or_else(|| "QSDK_R23D5_RAP_RESTORATION_ACTUATOR_ID_INVALID".to_owned())?;
            if actuator_seen.insert(actuator_id.to_owned(), true).is_some() {
                return Err(format!(
                    "QSDK_R23D5_RAP_RESTORATION_ACTUATOR_DUPLICATE:{actuator_id}"
                ));
            }
            let desired_speed = actuator["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| format!("QSDK_R23D5_RAP_RESTORATION_SPEED_INVALID:{actuator_id}"))?;
            maximum_speed = maximum_speed.max(desired_speed.abs());
            if maximum_speed > R23D5_MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S + TOLERANCE
                || !actuator["portable_heading_target_delta_rad"]
                    .as_f64()
                    .is_some_and(|value| value.is_finite())
            {
                return Err(format!(
                    "QSDK_R23D5_RAP_RESTORATION_COMMAND_INVALID:{actuator_id}"
                ));
            }
            let capture_activated =
                actuator["pose_capture_activated"]
                    .as_bool()
                    .ok_or_else(|| {
                        format!("QSDK_R23D5_RAP_RESTORATION_CAPTURE_INVALID:{actuator_id}")
                    })?;
            if contact {
                let neutral = actuator["neutral_joint_position_rad"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .ok_or_else(|| {
                        format!("QSDK_R23D5_RAP_RESTORATION_NEUTRAL_INVALID:{actuator_id}")
                    })?;
                let expected_capture = !independent_pose_memory.contains_key(actuator_id);
                if capture_activated != expected_capture {
                    return Err(format!(
                        "QSDK_R23D5_RAP_RESTORATION_CAPTURE_TRANSITION_INVALID:{actuator_id}"
                    ));
                }
                if expected_capture {
                    independent_pose_memory.insert(actuator_id.to_owned(), neutral);
                    capture_count += 1;
                } else if (independent_pose_memory[actuator_id] - neutral).abs() > TOLERANCE {
                    return Err(format!(
                        "QSDK_R23D5_RAP_RESTORATION_NEUTRAL_CHANGED:{actuator_id}"
                    ));
                }
            } else {
                if capture_activated || actuator["neutral_joint_position_rad"] != Value::Null {
                    return Err(format!(
                        "QSDK_R23D5_RAP_RESTORATION_MISSING_LIMB_CAPTURED:{actuator_id}"
                    ));
                }
                independent_pose_memory.remove(actuator_id);
            }
        }
    }
    if actuator_seen.len() != R23D3_ACTUATOR_COUNT as usize
        || receipt["pose_memory_actuator_count"] != independent_pose_memory.len() as u64
    {
        return Err("QSDK_R23D5_RAP_RESTORATION_MEMORY_COUNT_INVALID".to_owned());
    }
    Ok((capture_count, maximum_speed))
}

pub fn run_qsdk_r23d5_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d5_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D5_FAILURE_SCHEMA,
            "campaign_id": R23D5_CAMPAIGN_ID,
            "gate_id": R23D5_GATE_ID,
            "stage_id": stage_id,
            "engine_id": R23D5_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d5_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d5_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D5_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d5_contract().map_err(&before_world)?;
    let attempt_root = r23d5_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight = run_qsdk_r23d5_rapier_preflight(stage_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D5_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The attempt boundary is immediately before the one native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d5_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d5_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d5_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d5_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut restoration_memory = QsdkPoseHoldRestorationMemory::default();
    let mut independent_pose_memory = BTreeMap::<String, f64>::new();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D5_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;

    let mut native_actuation_application_count = 0_u64;
    let passive_native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut restoration_receipt_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut captured_pose_memory_transition_count = 0_u64;
    let captured_pose_memory_transition_failure_count = 0_u64;
    let mut heading_correction_receipt_count = 0_u64;
    let mut maximum_restoration_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut first_all_four_contact_restoration_step = None::<u64>;
    let mut consecutive_all_four_contact_hold_step_count = 0_u64;
    let mut maximum_consecutive_all_four_contact_hold_step_count = 0_u64;

    for semantic_step in 0..R23D5_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D5_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d5_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D5_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D5_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d5_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D5_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d5_trace_row(&cell, semantic_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for restoration_step in 0..R23D5_RESTORATION_STEPS {
        let trace_step = R23D5_CONTROLLER_STEPS + restoration_step;
        let state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
        let command =
            r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if output.actuation.receipt.semantic_step != trace_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
            || !oracle_failures.is_empty()
        {
            return Err(settled_failure(format!(
                "QSDK_R23D5_RAP_RESTORATION_CONTROLLER_INVALID:{}",
                oracle_failures.join(",")
            )));
        }
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let pre_step_contacts = robot.contacts(&compiled);
        let stability_state = robot
            .bw19v_stability_state(&compiled, trace_step)
            .map_err(&settled_failure)?;
        let kinematics = robot
            .bw19v_endpoint_kinematics(&compiled, &stability_state)
            .map_err(&settled_failure)?;
        let composition = compose_qsdk_contact_restoration(
            &compiled,
            &output.actuation,
            &state,
            &pre_step_contacts,
            &kinematics,
            &mut restoration_memory,
        )
        .map_err(&settled_failure)?;
        if composition.receipt["semantic_step"] != trace_step {
            return Err(settled_failure(
                "QSDK_R23D5_RAP_RESTORATION_STEP_INVALID".to_owned(),
            ));
        }
        let (capture_count, step_maximum_speed) = r23d5_validate_restoration_composition(
            &composition,
            &pre_step_contacts,
            &mut independent_pose_memory,
        )
        .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        composition
            .host_mapping
            .validate(
                &compiled.morphology,
                &composition.canonical_actuation,
                &host_profile,
            )
            .map_err(|error| {
                settled_failure(format!(
                    "QSDK_R23D5_RAP_RESTORATION_HOST_MAPPING_INVALID:{error}"
                ))
            })?;
        restoration_receipt_count += 1;
        heading_correction_receipt_count += 1;
        captured_pose_memory_transition_count += capture_count;
        maximum_restoration_joint_speed = maximum_restoration_joint_speed.max(step_maximum_speed);
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d5_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let all_four_contacts = contacts.values().all(|contact| *contact);
        if all_four_contacts && first_all_four_contact_restoration_step.is_none() {
            first_all_four_contact_restoration_step = Some(restoration_step);
        }
        if restoration_step >= R23D5_CONTACT_ACQUISITION_STEPS {
            if all_four_contacts {
                consecutive_all_four_contact_hold_step_count += 1;
                maximum_consecutive_all_four_contact_hold_step_count =
                    maximum_consecutive_all_four_contact_hold_step_count
                        .max(consecutive_all_four_contact_hold_step_count);
            } else {
                consecutive_all_four_contact_hold_step_count = 0;
            }
        }
        trace_rows.push(
            r23d5_trace_row(&cell, trace_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for passive_step in 0..R23D5_PASSIVE_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        let tilt = up.y.clamp(-1.0, 1.0).acos() as f64;
        let height = torso.translation().y as f64;
        let yaw = yaw_rad(&robot);
        nonfinite_observation_count +=
            u64::from(!tilt.is_finite() || !height.is_finite() || !yaw.is_finite());
        maximum_tilt_rad = maximum_tilt_rad.max(tilt);
        minimum_torso_height_m = minimum_torso_height_m.min(height);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        trace_rows.push(
            r23d5_trace_row(
                &cell,
                R23D5_ACTIVE_STEPS + passive_step,
                &robot,
                &compiled,
                0,
            )
            .map_err(&settled_failure)?,
        );
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D5_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d5_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D5_REPORT_SCHEMA,
        "campaign_id": R23D5_CAMPAIGN_ID,
        "gate_id": R23D5_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D5_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D5_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D5_RESTORATION_STEPS,
            "passive_settle_step_count": R23D5_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D5_CONTROLLER_STEPS,
            "terminal_restoration_step_count": R23D5_RESTORATION_STEPS,
            "passive_settle_step_count": R23D5_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "restoration_receipt_count": restoration_receipt_count,
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "first_all_four_contact_restoration_step":
                first_all_four_contact_restoration_step
                    .unwrap_or(R23D5_CONTACT_ACQUISITION_STEPS),
            "consecutive_all_four_contact_hold_step_count":
                maximum_consecutive_all_four_contact_hold_step_count,
            "captured_pose_memory_transition_count": captured_pose_memory_transition_count,
            "captured_pose_memory_transition_failure_count":
                captured_pose_memory_transition_failure_count,
            "maximum_absolute_restoration_joint_velocity_rad_s":
                maximum_restoration_joint_speed,
            "heading_correction_receipt_count": heading_correction_receipt_count,
            "passive_settle_trace_row_count": R23D5_PASSIVE_SETTLE_STEPS,
        },
        "godot_execution_predicates": Value::Null,
        "claims": r23d5_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d5_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D5_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}
#[cfg(test)]
mod r23d3_tests {
    use super::*;

    #[test]
    fn every_rapier_confirmation_identity_proves_fixed_horizon_without_world() {
        let mut count = 0_u64;
        for onset in ["onset_600", "onset_690", "onset_780", "onset_870"] {
            for arm in ["reference_zero", "positive_heading", "negative_heading"] {
                let receipt =
                    run_qsdk_r23d3_rapier_preflight("three_engine_confirmation", onset, arm)
                        .unwrap();
                assert_eq!(receipt["fixed_controller_horizon_step_count"], 2992);
                assert_eq!(
                    receipt["fixed_horizon_configuration_proved_before_fixture_insertion"],
                    true
                );
                assert_eq!(receipt["world_attempt_count"], 0);
                assert_eq!(receipt["world_build_count"], 0);
                assert_eq!(receipt["physical_execution_authorized"], false);
                count += 1;
            }
        }
        assert_eq!(count, 12);
    }

    #[test]
    fn stage_a_and_direct_physical_bypass_fail_before_world() {
        assert!(
            run_qsdk_r23d3_rapier_preflight("mujoco_onset_screen", "onset_600", "positive_heading")
                .is_err()
        );
        for name in [
            R23D3_FREEZE_PATH_ENV,
            R23D3_ATTEMPT_PATH_ENV,
            R23D3_TOKEN_ENV,
            R23D3_STAGE_ENV,
            R23D3_CELL_ENV,
            R23D3_ENGINE_ENV,
            R23D3_ATTEMPT_ROOT_ENV,
        ] {
            unsafe { env::remove_var(name) };
        }
        let failure = run_qsdk_r23d3_rapier_physical(
            "three_engine_confirmation",
            "onset_600",
            "reference_zero",
            "0000000000000000000000000000000000000000",
        )
        .unwrap_err();
        assert_eq!(failure["failure_code"], "QSDK_R23D3_RAP_CLOSED");
        assert_eq!(failure["failure_stage"], "before_world");
        assert_eq!(failure["world_attempt_count"], 0);
        assert_eq!(failure["world_build_count"], 0);
        assert_eq!(failure["trace_artifact"], Value::Null);
    }
}

#[cfg(test)]
mod r23d4_tests {
    use super::*;

    #[test]
    fn every_rapier_r23d4_identity_preflights_without_worlds() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt = run_qsdk_r23d4_rapier_preflight(R23D4_STAGE_ID, arm_id).unwrap();
            assert_eq!(receipt["fixed_controller_horizon_step_count"], 2_992);
            assert_eq!(receipt["fixed_terminal_restoration_step_count"], 540);
            assert_eq!(receipt["fixed_passive_settle_step_count"], 240);
            assert_eq!(receipt["fixed_total_trace_step_count"], 3_772);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
            assert_eq!(receipt["physical_acceptance_authority"], false);
        }
    }

    #[test]
    fn unknown_identity_and_direct_physical_bypass_refuse_before_world() {
        assert!(run_qsdk_r23d4_rapier_preflight(R23D4_STAGE_ID, "invented_arm").is_err());
        assert!(run_qsdk_r23d4_rapier_preflight("invented_stage", "reference_zero").is_err());
        for name in [
            R23D4_FREEZE_PATH_ENV,
            R23D4_ATTEMPT_PATH_ENV,
            R23D4_TOKEN_ENV,
            R23D4_STAGE_ENV,
            R23D4_CELL_ENV,
            R23D4_ENGINE_ENV,
            R23D4_ATTEMPT_ROOT_ENV,
        ] {
            unsafe { env::remove_var(name) };
        }
        let failure = run_qsdk_r23d4_rapier_physical(
            R23D4_STAGE_ID,
            "reference_zero",
            "0000000000000000000000000000000000000000",
        )
        .unwrap_err();
        assert_eq!(failure["failure_code"], "QSDK_R23D4_RAP_CLOSED");
        assert_eq!(failure["failure_stage"], "before_world");
        assert_eq!(failure["world_attempt_count"], 0);
        assert_eq!(failure["world_build_count"], 0);
        assert_eq!(failure["trace_artifact"], Value::Null);
    }
}

#[cfg(test)]
mod r23d5_tests {
    use super::*;

    #[test]
    fn every_rapier_r23d5_identity_preflights_without_worlds() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt = run_qsdk_r23d5_rapier_preflight(R23D5_STAGE_ID, arm_id).unwrap();
            assert_eq!(receipt["fixed_controller_horizon_step_count"], 2_992);
            assert_eq!(receipt["fixed_terminal_restoration_step_count"], 540);
            assert_eq!(receipt["fixed_passive_settle_step_count"], 240);
            assert_eq!(receipt["fixed_total_trace_step_count"], 3_772);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
            assert_eq!(receipt["physical_acceptance_authority"], false);
        }
    }

    #[test]
    fn unknown_identity_and_direct_r23d5_physical_bypass_refuse_before_world() {
        assert!(run_qsdk_r23d5_rapier_preflight(R23D5_STAGE_ID, "invented_arm").is_err());
        assert!(run_qsdk_r23d5_rapier_preflight("invented_stage", "reference_zero").is_err());
        for name in [
            R23D5_FREEZE_PATH_ENV,
            R23D5_ATTEMPT_PATH_ENV,
            R23D5_TOKEN_ENV,
            R23D5_STAGE_ENV,
            R23D5_CELL_ENV,
            R23D5_ENGINE_ENV,
            R23D5_ATTEMPT_ROOT_ENV,
        ] {
            unsafe { env::remove_var(name) };
        }
        let failure = run_qsdk_r23d5_rapier_physical(
            R23D5_STAGE_ID,
            "reference_zero",
            "0000000000000000000000000000000000000000",
        )
        .unwrap_err();
        assert_eq!(failure["failure_code"], "QSDK_R23D5_RAP_CLOSED");
        assert_eq!(failure["failure_stage"], "before_world");
        assert_eq!(failure["world_attempt_count"], 0);
        assert_eq!(failure["world_build_count"], 0);
        assert_eq!(failure["trace_artifact"], Value::Null);
    }
}
// Distinct prospective R23D7 implementation. Nothing below changes or
// reinterprets R23D6. R23D7 keeps the frozen onset-600 turning controller and
// replaces R23D6's contact-local search/captured-pose mechanism with the
// preregistered all-eight-actuator morphology-neutral bounded-PD stance,
// followed by the unchanged genuinely passive traced settle.

const R23D7_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d7_neutral_stance_preregistration_v1.json");
const R23D7_IMPLEMENTATION_RAW: &str =
    include_str!("../../../turning/r23d7_implementation_contract_v1.json");
const R23D7_CAMPAIGN_ID: &str = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT";
const R23D7_GATE_ID: &str = "QSDK-R23D7";
const R23D7_ENGINE_ID: &str = "rapier_parry";
const R23D7_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d7_rapier_worker_preflight_v1";
const R23D7_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d7_engine_cell_report_v1";
const R23D7_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d7_worker_failure_v1";
const R23D7_TRACE_ROW_SCHEMA: &str =
    "sporespore_qsdk_r23d7_turn_neutral_stance_settle_trace_row_v1";
const R23D7_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d7_trace_retention_v1";
const R23D7_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d7_physical_freeze_v1";
const R23D7_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d7_attempt_v1";
const R23D7_CLOSURE_PATH: &str = "sdk/turning/r23d7_physical_closure_v1.json";
const R23D7_STAGE_ID: &str = "three_engine_confirmation";
const R23D7_CONTROLLER_STEPS: u64 = 2_992;
const R23D7_STANCE_STEPS: u64 = 540;
const R23D7_CONTACT_ACQUISITION_STEPS: u64 = 180;
const R23D7_CONTACT_HOLD_STEPS: u64 = 360;
const R23D7_PASSIVE_SETTLE_STEPS: u64 = 240;
const R23D7_ACTIVE_STEPS: u64 = R23D7_CONTROLLER_STEPS + R23D7_STANCE_STEPS;
const R23D7_TOTAL_TRACE_STEPS: u64 = R23D7_ACTIVE_STEPS + R23D7_PASSIVE_SETTLE_STEPS;
const R23D7_STANCE_POLICY_ID: &str = "sporespore_morphology_neutral_stance_bounded_pd_v1";
const R23D7_TARGET_POSITION_RAD: f64 = 0.0;
const R23D7_POSITION_GAIN_PER_S: f64 = 8.0;
const R23D7_RATE_DAMPING: f64 = 0.65;
const R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S: f64 = 0.35;
const R23D7_ALGEBRA_CANARY_COUNT: u64 = 5;
const R23D7_MUTATION_CONTROL_COUNT: u64 = 10;

const R23D7_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D7_FREEZE";
const R23D7_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D7_ATTEMPT";
const R23D7_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D7_TOKEN";
const R23D7_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D7_STAGE";
const R23D7_CELL_ENV: &str = "SPORESPORE_QSDK_R23D7_CELL";
const R23D7_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D7_ENGINE";
const R23D7_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D7_ATTEMPT_ROOT";
const R23D7_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D7_PYTHON";
const R23D7_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D7_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D7Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

fn r23d7_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d7_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D7_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D7_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["frozen_schedule_and_gate_snapshot"];
    let stance = &contract["neutral_stance_policy_contract"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1"
        && contract["campaign_id"] == R23D7_CAMPAIGN_ID
        && contract["gate_id"] == R23D7_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && contract["authorization"]["worker_implementation_authorized"] == true
        && schedule["turning_controller_semantic_step_count"] == R23D7_CONTROLLER_STEPS
        && schedule["terminal_stance_step_count"] == R23D7_STANCE_STEPS
        && schedule["maximum_four_contact_acquisition_steps"] == R23D7_CONTACT_ACQUISITION_STEPS
        && schedule["required_consecutive_all_four_contact_hold_steps"] == R23D7_CONTACT_HOLD_STEPS
        && schedule["passive_settle_step_count"] == R23D7_PASSIVE_SETTLE_STEPS
        && schedule["total_traced_step_count"] == R23D7_TOTAL_TRACE_STEPS
        && schedule["maximum_absolute_terminal_stance_joint_velocity_rad_s"]
            == R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        && stance["policy_id"] == R23D7_STANCE_POLICY_ID
        && stance["target_position_rad_for_every_ordered_actuator"] == R23D7_TARGET_POSITION_RAD
        && stance["position_gain_per_s"] == R23D7_POSITION_GAIN_PER_S
        && stance["measured_rate_damping"] == R23D7_RATE_DAMPING
        && stance["maximum_absolute_joint_velocity_rad_s"]
            == R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        && stance["activation_is_atomic_for_all_eight_actuators"] == true
        && stance["dynamic_pose_capture"] == false
        && stance["direct_native_position_target_permitted"] == false;
    if !exact {
        return Err("QSDK_R23D7_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d7_cell(stage_id: &str, arm_id: &str) -> Result<R23D7Cell, String> {
    if stage_id != R23D7_STAGE_ID {
        return Err(format!("QSDK_R23D7_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D7_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D7Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D7_ENGINE_ID}__neutral_stance__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d7_phase(trace_step: u64) -> (&'static str, Option<u64>, f64) {
    if trace_step < TURN_START_STEP {
        ("reference_warmup", Some(trace_step), 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", Some(trace_step), 1.0)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", Some(trace_step), 0.0)
    } else if trace_step < R23D7_CONTROLLER_STEPS {
        ("reference_continuation", Some(trace_step), 0.0)
    } else if trace_step < R23D7_CONTROLLER_STEPS + R23D7_CONTACT_ACQUISITION_STEPS {
        ("terminal_neutral_stance_acquisition", None, 0.0)
    } else if trace_step < R23D7_ACTIVE_STEPS {
        ("terminal_neutral_stance_hold", None, 0.0)
    } else {
        ("passive_zero_actuation_settle", None, 0.0)
    }
}

fn r23d7_expected_phase_counts() -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("commanded_turn", 1_200),
        ("passive_zero_actuation_settle", R23D7_PASSIVE_SETTLE_STEPS),
        ("reference_continuation", 592),
        ("reference_recovery", 600),
        ("reference_warmup", 600),
        ("terminal_neutral_stance_hold", R23D7_CONTACT_HOLD_STEPS),
        (
            "terminal_neutral_stance_acquisition",
            R23D7_CONTACT_ACQUISITION_STEPS,
        ),
    ])
}

struct R23D7NeutralComposition {
    canonical_actuation: sporespore_locomotion_core::CanonicalVelocityActuationFrameV1,
    host_mapping: sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1,
    ordered_residuals: Vec<CanonicalVelocityResidualV1>,
    receipt: Value,
}

fn r23d7_bounded_neutral_velocity(
    measured_position_rad: f64,
    measured_velocity_rad_s: f64,
) -> Result<(f64, f64, f64), String> {
    if !measured_position_rad.is_finite() || !measured_velocity_rad_s.is_finite() {
        return Err("QSDK_R23D7_RAP_NEUTRAL_OBSERVATION_NONFINITE".to_owned());
    }
    let position_error_rad = R23D7_TARGET_POSITION_RAD - measured_position_rad;
    let unbounded_velocity_rad_s = R23D7_POSITION_GAIN_PER_S * position_error_rad
        - R23D7_RATE_DAMPING * measured_velocity_rad_s;
    let bounded_velocity_rad_s = unbounded_velocity_rad_s.clamp(
        -R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
        R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
    );
    Ok((
        position_error_rad,
        unbounded_velocity_rad_s,
        bounded_velocity_rad_s,
    ))
}

fn r23d7_neutral_receipt_failures(
    receipt: &Value,
    expected_actuator_ids: &[String],
) -> Vec<String> {
    let mut failures = Vec::<String>::new();
    if receipt["schema_version"] != "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1" {
        failures.push("schema_version".to_owned());
    }
    if receipt["policy_id"] != R23D7_STANCE_POLICY_ID {
        failures.push("policy_id".to_owned());
    }
    if receipt["target_source"] != "morphology_joint_coordinate_neutral_zero_v1" {
        failures.push("target_source".to_owned());
    }
    if receipt["position_gain_per_s"] != R23D7_POSITION_GAIN_PER_S
        || receipt["measured_rate_damping"] != R23D7_RATE_DAMPING
        || receipt["maximum_absolute_joint_velocity_rad_s"]
            != R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["neutral_target_activation_count"] != R23D3_ACTUATOR_COUNT
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
    {
        failures.push("receipt_identity".to_owned());
    }
    let Some(solutions) = receipt["ordered_actuator_solutions"].as_array() else {
        failures.push("solution_shape".to_owned());
        return failures;
    };
    if solutions.len() != expected_actuator_ids.len() {
        failures.push("solution_count".to_owned());
        return failures;
    }
    for (solution, expected_actuator_id) in solutions.iter().zip(expected_actuator_ids) {
        let actuator_id = solution["actuator_id"].as_str().unwrap_or_default();
        if actuator_id != expected_actuator_id {
            failures.push(format!("actuator_order:{actuator_id}"));
        }
        let Some(measured_position_rad) = solution["measured_position_rad"].as_f64() else {
            failures.push(format!("position:{actuator_id}"));
            continue;
        };
        let Some(measured_velocity_rad_s) = solution["measured_velocity_rad_s"].as_f64() else {
            failures.push(format!("velocity:{actuator_id}"));
            continue;
        };
        let Ok((expected_error, expected_unbounded, expected_bounded)) =
            r23d7_bounded_neutral_velocity(measured_position_rad, measured_velocity_rad_s)
        else {
            failures.push(format!("equation:{actuator_id}"));
            continue;
        };
        for (field, expected) in [
            ("target_position_rad", R23D7_TARGET_POSITION_RAD),
            ("position_error_rad", expected_error),
            ("unbounded_velocity_rad_s", expected_unbounded),
            ("bounded_velocity_rad_s", expected_bounded),
        ] {
            if !solution[field]
                .as_f64()
                .is_some_and(|actual| actual.is_finite() && (actual - expected).abs() <= TOLERANCE)
            {
                failures.push(format!("{field}:{actuator_id}"));
            }
        }
        if solution["neutral_target_activated"] != true
            || solution["desired_joint_velocity_rad_s"] != solution["bounded_velocity_rad_s"]
        {
            failures.push(format!("activation:{actuator_id}"));
        }
    }
    failures
}

fn r23d7_compose_neutral_stance(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    state: &StateFrame,
    first_activation: bool,
) -> Result<R23D7NeutralComposition, String> {
    validate_controller_actuation(compiled, base_actuation)?;
    let observations = state
        .ordered_joint_observations
        .iter()
        .map(|observation| (observation.joint_id.as_str(), observation))
        .collect::<BTreeMap<_, _>>();
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if actuators.len() != R23D3_ACTUATOR_COUNT as usize
        || base_actuation.ordered_commands.len() != actuators.len()
    {
        return Err("QSDK_R23D7_RAP_NEUTRAL_ACTUATOR_COUNT_INVALID".to_owned());
    }

    let mut ordered_residuals = Vec::<CanonicalVelocityResidualV1>::with_capacity(actuators.len());
    let mut ordered_solutions = Vec::<Value>::with_capacity(actuators.len());
    for (actuator, source_command) in actuators.iter().zip(&base_actuation.ordered_commands) {
        if source_command.actuator_id != actuator.actuator_id
            || actuator.minimum_target_position_rad > R23D7_TARGET_POSITION_RAD
            || actuator.maximum_target_position_rad < R23D7_TARGET_POSITION_RAD
        {
            return Err(format!(
                "QSDK_R23D7_RAP_NEUTRAL_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let observation = observations
            .get(actuator.joint_id.as_str())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D7_RAP_NEUTRAL_OBSERVATION_MISSING:{}",
                    actuator.joint_id
                )
            })?;
        let measured_position_rad = observation
            .position_rad
            .filter(|value| value.is_finite())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D7_RAP_NEUTRAL_POSITION_INVALID:{}",
                    actuator.joint_id
                )
            })?;
        let measured_velocity_rad_s = observation
            .velocity_rad_s
            .filter(|value| value.is_finite())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D7_RAP_NEUTRAL_VELOCITY_INVALID:{}",
                    actuator.joint_id
                )
            })?;
        let (position_error_rad, unbounded_velocity_rad_s, bounded_velocity_rad_s) =
            r23d7_bounded_neutral_velocity(measured_position_rad, measured_velocity_rad_s)?;
        let portable_source_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        ordered_residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator.actuator_id.clone(),
            canonical_velocity_delta_rad_s: bounded_velocity_rad_s - portable_source_velocity,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
        ordered_solutions.push(json!({
            "actuator_id": actuator.actuator_id,
            "joint_id": actuator.joint_id,
            "minimum_target_position_rad": actuator.minimum_target_position_rad,
            "maximum_target_position_rad": actuator.maximum_target_position_rad,
            "target_position_rad": R23D7_TARGET_POSITION_RAD,
            "measured_position_rad": measured_position_rad,
            "measured_velocity_rad_s": measured_velocity_rad_s,
            "position_error_rad": position_error_rad,
            "unbounded_velocity_rad_s": unbounded_velocity_rad_s,
            "bounded_velocity_rad_s": bounded_velocity_rad_s,
            "desired_joint_velocity_rad_s": bounded_velocity_rad_s,
            "neutral_target_activated": true,
            "pose_capture_activated": first_activation,
        }));
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    for ((canonical, host), solution) in canonical_actuation
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
        .zip(&ordered_solutions)
    {
        let desired = solution["bounded_velocity_rad_s"]
            .as_f64()
            .unwrap_or(f64::NAN);
        if !desired.is_finite()
            || (canonical.combined_canonical_target_velocity_rad_s - desired).abs() > TOLERANCE
            || (host.host_target_velocity_rad_s - desired).abs() > TOLERANCE
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "QSDK_R23D7_RAP_NEUTRAL_HOST_MAPPING_INVALID:{}",
                canonical.actuator_id
            ));
        }
    }
    let receipt = json!({
        "schema_version": "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1",
        "semantic_step": base_actuation.semantic_step,
        "policy_id": R23D7_STANCE_POLICY_ID,
        "target_source": "morphology_joint_coordinate_neutral_zero_v1",
        "position_gain_per_s": R23D7_POSITION_GAIN_PER_S,
        "measured_rate_damping": R23D7_RATE_DAMPING,
        "maximum_absolute_joint_velocity_rad_s": R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
        "neutral_target_activation_count": R23D3_ACTUATOR_COUNT,
        "atomic_activation_transition": first_activation,
        "ordered_actuator_solutions": ordered_solutions,
        "physics_state_modified": false,
        "command_not_measurement": true,
        "physical_acceptance_authority": false,
    });
    let failures =
        r23d7_neutral_receipt_failures(&receipt, &compiled.morphology.ordered_actuator_ids);
    if !failures.is_empty() {
        return Err(format!(
            "QSDK_R23D7_RAP_NEUTRAL_RECEIPT_INVALID:{}",
            failures.join(",")
        ));
    }
    Ok(R23D7NeutralComposition {
        canonical_actuation,
        host_mapping,
        ordered_residuals,
        receipt,
    })
}

pub fn run_qsdk_r23d7_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let contract = r23d7_contract()?;
    let cell = r23d7_cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d3_rapier_preflight(R23D7_STAGE_ID, "onset_600", arm_id)?;
    let mut phase_counts = BTreeMap::<&'static str, u64>::new();
    for trace_step in 0..R23D7_TOTAL_TRACE_STEPS {
        *phase_counts.entry(r23d7_phase(trace_step).0).or_default() += 1;
    }

    let canaries = contract["independent_oracle_canaries"]
        .as_array()
        .filter(|rows| rows.len() == R23D7_ALGEBRA_CANARY_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D7_RAP_CANARY_DECLARATION_INVALID".to_owned())?;
    for canary in canaries {
        let measured_position = canary["measured_position_rad"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D7_RAP_CANARY_POSITION_INVALID".to_owned())?;
        let measured_velocity = canary["measured_velocity_rad_s"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D7_RAP_CANARY_VELOCITY_INVALID".to_owned())?;
        let (position_error, unbounded, bounded) =
            r23d7_bounded_neutral_velocity(measured_position, measured_velocity)?;
        if (unbounded
            - canary["expected_unbounded_velocity_rad_s"]
                .as_f64()
                .unwrap_or(f64::NAN))
        .abs()
            > TOLERANCE
            || (bounded
                - canary["expected_bounded_velocity_rad_s"]
                    .as_f64()
                    .unwrap_or(f64::NAN))
            .abs()
                > TOLERANCE
            || (position_error - (R23D7_TARGET_POSITION_RAD - measured_position)).abs() > TOLERANCE
        {
            return Err("QSDK_R23D7_RAP_CANARY_ORACLE_MISMATCH".to_owned());
        }
    }

    let (compiled, controller) = compile_boundary()?;
    let turning_cell = r23d3_cell(R23D7_STAGE_ID, "onset_600", arm_id)?;
    let mut state =
        synthetic_state_frame(&compiled, heading_quaternion(cell.turn_heading_offset_rad));
    for (index, observation) in state.ordered_joint_observations.iter_mut().enumerate() {
        let canary = &canaries[index % canaries.len()];
        observation.position_rad = canary["measured_position_rad"].as_f64();
        observation.velocity_rad_s = canary["measured_velocity_rad_s"].as_f64();
    }
    let schedule = r23d3_schedule(&turning_cell, 0, state.task_frame.reference_yaw_rad);
    let command = r23d3_motion_command(0, PhaseProgressionMode::Clocked, &schedule);
    let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
    let composition = r23d7_compose_neutral_stance(&compiled, &output.actuation, &state, true)?;

    let mutation_ids = contract["required_mutation_controls"]
        .as_array()
        .filter(|rows| rows.len() == R23D7_MUTATION_CONTROL_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D7_RAP_MUTATION_DECLARATION_INVALID".to_owned())?;
    let mut mutation_rejections = Map::<String, Value>::new();
    for (index, mutation_id) in mutation_ids.iter().enumerate() {
        let mutation_id = mutation_id
            .as_str()
            .ok_or_else(|| "QSDK_R23D7_RAP_MUTATION_ID_INVALID".to_owned())?;
        let mut mutated = composition.receipt.clone();
        let solutions = mutated["ordered_actuator_solutions"]
            .as_array_mut()
            .ok_or_else(|| "QSDK_R23D7_RAP_MUTATION_SOLUTION_SHAPE".to_owned())?;
        match index {
            0 => {
                let value = solutions[0]["position_error_rad"].as_f64().unwrap_or(0.0);
                solutions[0]["position_error_rad"] = json!(-value);
            }
            1 => {
                let error = solutions[1]["position_error_rad"].as_f64().unwrap_or(0.0);
                solutions[1]["unbounded_velocity_rad_s"] = json!(R23D7_POSITION_GAIN_PER_S * error);
            }
            2 => {
                let error = solutions[1]["position_error_rad"].as_f64().unwrap_or(0.0);
                let rate = solutions[1]["measured_velocity_rad_s"]
                    .as_f64()
                    .unwrap_or(0.0);
                solutions[1]["unbounded_velocity_rad_s"] =
                    json!(R23D7_POSITION_GAIN_PER_S * error + R23D7_RATE_DAMPING * rate);
            }
            3 => {
                solutions[0]["target_position_rad"] = solutions[0]["measured_position_rad"].clone();
            }
            4 => solutions[0]["target_position_rad"] = json!(0.1),
            5 => {
                solutions[0]["bounded_velocity_rad_s"] =
                    solutions[0]["unbounded_velocity_rad_s"].clone();
            }
            6 => solutions.truncate(2),
            7 => {
                solutions.pop();
            }
            8 => solutions.swap(0, 1),
            9 => solutions[0]["target_position_rad"] = json!(0.01),
            _ => unreachable!("exact mutation count checked above"),
        }
        let rejected =
            !r23d7_neutral_receipt_failures(&mutated, &compiled.morphology.ordered_actuator_ids)
                .is_empty();
        mutation_rejections.insert(mutation_id.to_owned(), json!(rejected));
    }
    if inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["inherited_predicate_negative_control_count"] != 35
        || inherited["inherited_native_mapping_canary_count"] != 7
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
        || mutation_rejections.values().any(|value| value != true)
        || phase_counts != r23d7_expected_phase_counts()
    {
        return Err("QSDK_R23D7_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D7_PREFLIGHT_SCHEMA,
        "campaign_id": R23D7_CAMPAIGN_ID,
        "gate_id": R23D7_GATE_ID,
        "engine_id": R23D7_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D7_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d3_native_mapping_canary_count":
            inherited["inherited_native_mapping_canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["inherited_predicate_negative_control_count"],
        "neutral_stance_algebra_canary_count": R23D7_ALGEBRA_CANARY_COUNT,
        "neutral_stance_mutation_control_count": R23D7_MUTATION_CONTROL_COUNT,
        "neutral_stance_mutation_controls_rejected": mutation_rejections,
        "production_neutral_stance_composition_complete": true,
        "neutral_target_activation_count": composition.receipt["neutral_target_activation_count"],
        "canonical_command_count": composition.canonical_actuation.ordered_commands.len(),
        "host_command_count": composition.host_mapping.ordered_commands.len(),
        "fixed_controller_horizon_step_count": R23D7_CONTROLLER_STEPS,
        "fixed_terminal_stance_step_count": R23D7_STANCE_STEPS,
        "fixed_passive_settle_step_count": R23D7_PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": R23D7_TOTAL_TRACE_STEPS,
        "trace_phase_counts": phase_counts,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d7_failure(
    cell: &R23D7Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D7_FAILURE_SCHEMA,
        "campaign_id": R23D7_CAMPAIGN_ID,
        "gate_id": R23D7_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D7_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": Value::Null,
        "godot_execution_predicates": Value::Null,

        "claims": r23d7_claims(),
    })
}

fn r23d7_source_bindings_exact(freeze: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let required_paths = [
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
        "sdk/adapters/rapier/src/bin/qsdk_r23d7_neutral_stance.rs",
        "sdk/turning/r23d7_neutral_stance_preregistration_v1.json",
        "sdk/turning/r23d7_implementation_contract_v1.json",
        "sdk/turning/r23d7_physical_evaluator.py",
        "sdk/publish_qsdk_r23d7_trace.ps1",
    ];
    let Ok(implementation) = serde_json::from_str::<Value>(R23D7_IMPLEMENTATION_RAW) else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]["rapier_parry"]
            .as_array()
    else {
        return false;
    };
    if declared.len() != required_paths.len()
        || declared
            .iter()
            .zip(required_paths)
            .any(|(actual, expected)| actual.as_str() != Some(expected))
    {
        return false;
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    required_paths.iter().all(|path| {
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        let digest = raw_sha256(&bytes);
        bindings
            .iter()
            .any(|entry| entry["path"] == *path && entry["raw_sha256"] == digest)
    })
}

fn r23d7_physical_authorization(
    cell: &R23D7Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D7_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D7_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D7_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D7_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D7_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D7_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D7_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D7_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D7_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D7_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D7_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D7_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D7_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D7_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D7_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D7_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D7_CAMPAIGN_ID
        && freeze["gate_id"] == R23D7_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D7_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d7_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D7_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D7_CAMPAIGN_ID
        && attempt["gate_id"] == R23D7_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D7_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D7_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D7_ENGINE_ENV).unwrap_or_default() == R23D7_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D7_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

fn r23d7_retain_trace(
    cell: &R23D7Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D7_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D7_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D7_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d7_physical_evaluator.py");
    let python = env::var(R23D7_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D7_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D7_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D7_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D7_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D7_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D7_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D7_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d7_limb_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<BTreeMap<String, bool>, String> {
    let value = r23d3_foot_contacts(robot, compiled)?;
    let object = value
        .as_object()
        .ok_or_else(|| "QSDK_R23D7_RAP_CONTACT_PROJECTION_INVALID".to_owned())?;
    object
        .iter()
        .map(|(limb_id, contact)| {
            contact
                .as_bool()
                .map(|present| (limb_id.clone(), present))
                .ok_or_else(|| format!("QSDK_R23D7_RAP_CONTACT_VALUE_INVALID:{limb_id}"))
        })
        .collect()
}

fn r23d7_trace_row(
    cell: &R23D7Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_application_count: u64,
    neutral_receipt: Option<&Value>,
) -> Result<Value, String> {
    let (phase_id, controller_semantic_step, heading_multiplier) = r23d7_phase(trace_step);
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let contacts = r23d7_limb_contacts(robot, compiled)?;
    let passive = phase_id == "passive_zero_actuation_settle";
    let terminal_stance = phase_id.starts_with("terminal_neutral_stance_");
    if terminal_stance != neutral_receipt.is_some() {
        return Err("QSDK_R23D7_RAP_TRACE_NEUTRAL_RECEIPT_PRESENCE_INVALID".to_owned());
    }
    let neutral_target_activation_count = neutral_receipt
        .map(|receipt| receipt["neutral_target_activation_count"].clone())
        .unwrap_or(Value::Null);
    let mut maximum_absolute_joint_position_error_rad = None::<f64>;
    let mut maximum_absolute_commanded_joint_velocity_rad_s = None::<f64>;
    if let Some(receipt) = neutral_receipt {
        let solutions = receipt["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
            .ok_or_else(|| "QSDK_R23D7_RAP_TRACE_NEUTRAL_SOLUTIONS_INVALID".to_owned())?;
        for solution in solutions {
            let error = solution["position_error_rad"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D7_RAP_TRACE_NEUTRAL_ERROR_INVALID".to_owned())?;
            let speed = solution["bounded_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D7_RAP_TRACE_NEUTRAL_SPEED_INVALID".to_owned())?;
            maximum_absolute_joint_position_error_rad = Some(
                maximum_absolute_joint_position_error_rad
                    .unwrap_or(0.0)
                    .max(error.abs()),
            );
            maximum_absolute_commanded_joint_velocity_rad_s = Some(
                maximum_absolute_commanded_joint_velocity_rad_s
                    .unwrap_or(0.0)
                    .max(speed.abs()),
            );
        }
    }
    Ok(json!({
        "schema_version": R23D7_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_semantic_step,
        "desired_heading_offset_rad":
            heading_multiplier * cell.turn_heading_offset_rad,
        "measured_yaw_rad": yaw_rad(robot),
        "torso_height_m": torso.translation().y as f64,
        "torso_tilt_rad": up.y.clamp(-1.0, 1.0).acos() as f64,

        "torso_ground_contact": robot.torso_ground_contact(),
        "ordered_foot_contacts": contacts,
        "actuator_command_count": if passive { 0 } else { R23D3_ACTUATOR_COUNT },
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": if passive {
            "passive_zero_actuation_v1"
        } else if terminal_stance {
            R23D7_STANCE_POLICY_ID
        } else {
            "balanced_wave_turning_v1"
        },
        "terminal_stance_receipt_present": terminal_stance,
        "neutral_target_activation_count": neutral_target_activation_count,
        "maximum_absolute_joint_position_error_rad":
            maximum_absolute_joint_position_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s":
            maximum_absolute_commanded_joint_velocity_rad_s,
    }))
}

// Inherited R23D6 receipt validator retained as inspectable predecessor code.
// R23D7 production and preflight routes never call it; both call the neutral
// receipt validator and composer above.
fn r23d7_obsolete_predecessor_restoration_validator(
    composition: &QsdkContactRestorationComposition,
    pre_step_contacts: &BTreeMap<String, bool>,
    independent_pose_memory: &mut BTreeMap<String, f64>,
) -> Result<(u64, f64), String> {
    let receipt = &composition.receipt;
    if receipt["policy_id"]
        != "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1"
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != 8.0
        || receipt["pose_hold_rate_damping"] != 0.65
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || receipt["damped_least_squares_lambda_m"] != 0.04
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
    {
        return Err("QSDK_R23D7_RAP_RESTORATION_RECEIPT_IDENTITY_INVALID".to_owned());
    }
    let limbs = receipt["ordered_limb_solutions"]
        .as_array()
        .filter(|rows| rows.len() == 4)
        .ok_or_else(|| "QSDK_R23D7_RAP_RESTORATION_LIMB_COUNT_INVALID".to_owned())?;
    let mut capture_count = 0_u64;
    let mut maximum_speed = 0.0_f64;
    let mut actuator_seen = BTreeMap::<String, bool>::new();
    for limb in limbs {
        let site_id = limb["contact_site_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D7_RAP_RESTORATION_SITE_ID_INVALID".to_owned())?;
        let contact = *pre_step_contacts
            .get(site_id)
            .ok_or_else(|| format!("QSDK_R23D7_RAP_RESTORATION_SITE_CONTACT_MISSING:{site_id}"))?;
        if limb["pre_step_contact"] != contact {
            return Err(format!(
                "QSDK_R23D7_RAP_RESTORATION_CONTACT_RECEIPT_INVALID:{site_id}"
            ));
        }
        let actuators = limb["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == 2)
            .ok_or_else(|| {
                format!("QSDK_R23D7_RAP_RESTORATION_ACTUATOR_COUNT_INVALID:{site_id}")
            })?;
        for actuator in actuators {
            let actuator_id = actuator["actuator_id"]
                .as_str()
                .ok_or_else(|| "QSDK_R23D7_RAP_RESTORATION_ACTUATOR_ID_INVALID".to_owned())?;
            if actuator_seen.insert(actuator_id.to_owned(), true).is_some() {
                return Err(format!(
                    "QSDK_R23D7_RAP_RESTORATION_ACTUATOR_DUPLICATE:{actuator_id}"
                ));
            }
            let desired_speed = actuator["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| format!("QSDK_R23D7_RAP_RESTORATION_SPEED_INVALID:{actuator_id}"))?;
            maximum_speed = maximum_speed.max(desired_speed.abs());
            if maximum_speed > R23D7_MAXIMUM_STANCE_JOINT_SPEED_RAD_S + TOLERANCE
                || !actuator["portable_heading_target_delta_rad"]
                    .as_f64()
                    .is_some_and(|value| value.is_finite())
            {
                return Err(format!(
                    "QSDK_R23D7_RAP_RESTORATION_COMMAND_INVALID:{actuator_id}"
                ));
            }
            let capture_activated =
                actuator["pose_capture_activated"]
                    .as_bool()
                    .ok_or_else(|| {
                        format!("QSDK_R23D7_RAP_RESTORATION_CAPTURE_INVALID:{actuator_id}")
                    })?;
            if contact {
                let neutral = actuator["neutral_joint_position_rad"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .ok_or_else(|| {
                        format!("QSDK_R23D7_RAP_RESTORATION_NEUTRAL_INVALID:{actuator_id}")
                    })?;
                let expected_capture = !independent_pose_memory.contains_key(actuator_id);
                if capture_activated != expected_capture {
                    return Err(format!(
                        "QSDK_R23D7_RAP_RESTORATION_CAPTURE_TRANSITION_INVALID:{actuator_id}"
                    ));
                }
                if expected_capture {
                    independent_pose_memory.insert(actuator_id.to_owned(), neutral);
                    capture_count += 1;
                } else if (independent_pose_memory[actuator_id] - neutral).abs() > TOLERANCE {
                    return Err(format!(
                        "QSDK_R23D7_RAP_RESTORATION_NEUTRAL_CHANGED:{actuator_id}"
                    ));
                }
            } else {
                if capture_activated || actuator["neutral_joint_position_rad"] != Value::Null {
                    return Err(format!(
                        "QSDK_R23D7_RAP_RESTORATION_MISSING_LIMB_CAPTURED:{actuator_id}"
                    ));
                }
                independent_pose_memory.remove(actuator_id);
            }
        }
    }
    if actuator_seen.len() != R23D3_ACTUATOR_COUNT as usize
        || receipt["pose_memory_actuator_count"] != independent_pose_memory.len() as u64
    {
        return Err("QSDK_R23D7_RAP_RESTORATION_MEMORY_COUNT_INVALID".to_owned());
    }
    Ok((capture_count, maximum_speed))
}

pub fn run_qsdk_r23d7_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d7_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D7_FAILURE_SCHEMA,
            "campaign_id": R23D7_CAMPAIGN_ID,
            "gate_id": R23D7_GATE_ID,
            "stage_id": stage_id,
            "engine_id": R23D7_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d7_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d7_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D7_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d7_contract().map_err(&before_world)?;
    let attempt_root = r23d7_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight = run_qsdk_r23d7_rapier_preflight(stage_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D7_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The attempt boundary is immediately before the one native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d7_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d7_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d7_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d7_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut neutral_stance_activated = false;
    let mut trace_rows = Vec::<Value>::with_capacity(R23D7_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;

    let mut native_actuation_application_count = 0_u64;
    let passive_native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut neutral_stance_receipt_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut neutral_target_activation_command_count = 0_u64;
    let neutral_target_activation_failure_count = 0_u64;
    let mut neutral_target_transition_count = 0_u64;
    let neutral_target_transition_failure_count = 0_u64;
    let mut maximum_terminal_stance_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut first_all_four_contact_terminal_stance_step = None::<u64>;
    let mut consecutive_all_four_contact_hold_step_count = 0_u64;
    let mut maximum_consecutive_all_four_contact_hold_step_count = 0_u64;

    for semantic_step in 0..R23D7_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D7_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d7_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D7_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D7_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d7_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D7_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d7_trace_row(&cell, semantic_step, &robot, &compiled, applications, None)
                .map_err(&settled_failure)?,
        );
    }

    for stance_step in 0..R23D7_STANCE_STEPS {
        let trace_step = R23D7_CONTROLLER_STEPS + stance_step;
        let state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
        let command =
            r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if output.actuation.receipt.semantic_step != trace_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
            || !oracle_failures.is_empty()
        {
            return Err(settled_failure(format!(
                "QSDK_R23D7_RAP_STANCE_CONTROLLER_INVALID:{}",
                oracle_failures.join(",")
            )));
        }
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let first_activation = !neutral_stance_activated;
        let composition =
            r23d7_compose_neutral_stance(&compiled, &output.actuation, &state, first_activation)
                .map_err(&settled_failure)?;
        if composition.receipt["semantic_step"] != trace_step {
            return Err(settled_failure(
                "QSDK_R23D7_RAP_STANCE_STEP_INVALID".to_owned(),
            ));
        }
        let receipt_failures = r23d7_neutral_receipt_failures(
            &composition.receipt,
            &compiled.morphology.ordered_actuator_ids,
        );
        if !receipt_failures.is_empty() {
            return Err(settled_failure(format!(
                "QSDK_R23D7_RAP_STANCE_RECEIPT_INVALID:{}",
                receipt_failures.join(",")
            )));
        }
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        composition
            .host_mapping
            .validate(
                &compiled.morphology,
                &composition.canonical_actuation,
                &host_profile,
            )
            .map_err(|error| {
                settled_failure(format!(
                    "QSDK_R23D7_RAP_STANCE_HOST_MAPPING_INVALID:{error}"
                ))
            })?;
        let solutions = composition.receipt["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
            .ok_or_else(|| settled_failure("QSDK_R23D7_RAP_STANCE_SOLUTIONS_INVALID".to_owned()))?;
        let activation_count = solutions
            .iter()
            .filter(|solution| solution["neutral_target_activated"] == true)
            .count() as u64;
        neutral_stance_receipt_count += 1;
        neutral_target_activation_command_count += activation_count;
        if first_activation {
            neutral_target_transition_count += solutions
                .iter()
                .filter(|solution| solution["pose_capture_activated"] == true)
                .count() as u64;
            neutral_stance_activated = true;
        }
        let mut step_maximum_speed = 0.0_f64;
        for solution in solutions {
            let desired = solution["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| settled_failure("QSDK_R23D7_RAP_STANCE_SPEED_INVALID".to_owned()))?;
            step_maximum_speed = step_maximum_speed.max(desired.abs());
        }
        maximum_terminal_stance_joint_speed =
            maximum_terminal_stance_joint_speed.max(step_maximum_speed);
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d7_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let all_four_contacts = contacts.values().all(|contact| *contact);
        if all_four_contacts && first_all_four_contact_terminal_stance_step.is_none() {
            first_all_four_contact_terminal_stance_step = Some(stance_step);
        }
        if stance_step >= R23D7_CONTACT_ACQUISITION_STEPS {
            if all_four_contacts {
                consecutive_all_four_contact_hold_step_count += 1;
                maximum_consecutive_all_four_contact_hold_step_count =
                    maximum_consecutive_all_four_contact_hold_step_count
                        .max(consecutive_all_four_contact_hold_step_count);
            } else {
                consecutive_all_four_contact_hold_step_count = 0;
            }
        }
        trace_rows.push(
            r23d7_trace_row(
                &cell,
                trace_step,
                &robot,
                &compiled,
                applications,
                Some(&composition.receipt),
            )
            .map_err(&settled_failure)?,
        );
    }

    for passive_step in 0..R23D7_PASSIVE_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        let tilt = up.y.clamp(-1.0, 1.0).acos() as f64;
        let height = torso.translation().y as f64;
        let yaw = yaw_rad(&robot);
        nonfinite_observation_count +=
            u64::from(!tilt.is_finite() || !height.is_finite() || !yaw.is_finite());
        maximum_tilt_rad = maximum_tilt_rad.max(tilt);
        minimum_torso_height_m = minimum_torso_height_m.min(height);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        trace_rows.push(
            r23d7_trace_row(
                &cell,
                R23D7_ACTIVE_STEPS + passive_step,
                &robot,
                &compiled,
                0,
                None,
            )
            .map_err(&settled_failure)?,
        );
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D7_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d7_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D7_REPORT_SCHEMA,
        "campaign_id": R23D7_CAMPAIGN_ID,
        "gate_id": R23D7_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D7_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D7_CONTROLLER_STEPS,
            "terminal_stance_step_count": R23D7_STANCE_STEPS,
            "passive_settle_step_count": R23D7_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D7_CONTROLLER_STEPS,
            "terminal_stance_step_count": R23D7_STANCE_STEPS,
            "passive_settle_step_count": R23D7_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "neutral_stance_receipt_count": neutral_stance_receipt_count,
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "first_all_four_contact_terminal_stance_step":
                first_all_four_contact_terminal_stance_step
                    .unwrap_or(R23D7_CONTACT_ACQUISITION_STEPS),
            "consecutive_all_four_contact_hold_step_count":
                maximum_consecutive_all_four_contact_hold_step_count,
            "neutral_target_activation_command_count":
                neutral_target_activation_command_count,
            "neutral_target_activation_failure_count":
                neutral_target_activation_failure_count,
            "neutral_target_transition_count": neutral_target_transition_count,
            "neutral_target_transition_failure_count":
                neutral_target_transition_failure_count,
            "maximum_absolute_terminal_stance_joint_velocity_rad_s":
                maximum_terminal_stance_joint_speed,
            "passive_settle_trace_row_count": R23D7_PASSIVE_SETTLE_STEPS,
        },
        "godot_execution_predicates": Value::Null,
        "claims": r23d7_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d7_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D7_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

// R23D8 is an implementation-only successor to the consumed, zero-world
// R23D7 attempt. Its scientific execution contract is mechanically compared
// with the pinned R23D7 question before this native route is qualified.
const R23D8_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d8_scientific_execution_contract_v1.json");
const R23D8_IMPLEMENTATION_RAW: &str =
    include_str!("../../../turning/r23d8_implementation_contract_v1.json");
const R23D8_CAMPAIGN_ID: &str =
    "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-BILATERAL-TURN-DEVELOPMENT";
const R23D8_GATE_ID: &str = "QSDK-R23D8";
const R23D8_ENGINE_ID: &str = "rapier_parry";
const R23D8_PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d8_rapier_worker_preflight_v1";
const R23D8_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d8_engine_cell_report_v1";
const R23D8_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d8_worker_failure_v1";
const R23D8_TRACE_ROW_SCHEMA: &str =
    "sporespore_qsdk_r23d8_turn_neutral_stance_settle_trace_row_v1";
const R23D8_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d8_trace_retention_v1";
const R23D8_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d8_physical_freeze_v1";
const R23D8_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d8_attempt_v1";
const R23D8_CLOSURE_PATH: &str = "sdk/turning/r23d8_physical_closure_v1.json";
const R23D8_STAGE_ID: &str = "three_engine_confirmation";
const R23D8_CONTROLLER_STEPS: u64 = 2_992;
const R23D8_STANCE_STEPS: u64 = 540;
const R23D8_CONTACT_ACQUISITION_STEPS: u64 = 180;
const R23D8_CONTACT_HOLD_STEPS: u64 = 360;
const R23D8_PASSIVE_SETTLE_STEPS: u64 = 240;
const R23D8_ACTIVE_STEPS: u64 = R23D8_CONTROLLER_STEPS + R23D8_STANCE_STEPS;
const R23D8_TOTAL_TRACE_STEPS: u64 = R23D8_ACTIVE_STEPS + R23D8_PASSIVE_SETTLE_STEPS;
const R23D8_STANCE_POLICY_ID: &str = "sporespore_morphology_neutral_stance_bounded_pd_v1";
const R23D8_TARGET_POSITION_RAD: f64 = 0.0;
const R23D8_POSITION_GAIN_PER_S: f64 = 8.0;
const R23D8_RATE_DAMPING: f64 = 0.65;
const R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S: f64 = 0.35;
const R23D8_ALGEBRA_CANARY_COUNT: u64 = 5;
const R23D8_MUTATION_CONTROL_COUNT: u64 = 10;

const R23D8_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D8_FREEZE";
const R23D8_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D8_ATTEMPT";
const R23D8_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D8_TOKEN";
const R23D8_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D8_STAGE";
const R23D8_CELL_ENV: &str = "SPORESPORE_QSDK_R23D8_CELL";
const R23D8_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D8_ENGINE";
const R23D8_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D8_ATTEMPT_ROOT";
const R23D8_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D8_PYTHON";
const R23D8_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D8_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D8Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

fn r23d8_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d8_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D8_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D8_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["frozen_schedule_and_gate_snapshot"];
    let stance = &contract["neutral_stance_policy_contract"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d8_neutral_stance_preregistration_v1"
        && contract["campaign_id"] == R23D8_CAMPAIGN_ID
        && contract["gate_id"] == R23D8_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && contract["authorization"]["worker_implementation_authorized"] == true
        && schedule["turning_controller_semantic_step_count"] == R23D8_CONTROLLER_STEPS
        && schedule["terminal_stance_step_count"] == R23D8_STANCE_STEPS
        && schedule["maximum_four_contact_acquisition_steps"] == R23D8_CONTACT_ACQUISITION_STEPS
        && schedule["required_consecutive_all_four_contact_hold_steps"] == R23D8_CONTACT_HOLD_STEPS
        && schedule["passive_settle_step_count"] == R23D8_PASSIVE_SETTLE_STEPS
        && schedule["total_traced_step_count"] == R23D8_TOTAL_TRACE_STEPS
        && schedule["maximum_absolute_terminal_stance_joint_velocity_rad_s"]
            == R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        && stance["policy_id"] == R23D8_STANCE_POLICY_ID
        && stance["target_position_rad_for_every_ordered_actuator"] == R23D8_TARGET_POSITION_RAD
        && stance["position_gain_per_s"] == R23D8_POSITION_GAIN_PER_S
        && stance["measured_rate_damping"] == R23D8_RATE_DAMPING
        && stance["maximum_absolute_joint_velocity_rad_s"]
            == R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        && stance["activation_is_atomic_for_all_eight_actuators"] == true
        && stance["dynamic_pose_capture"] == false
        && stance["direct_native_position_target_permitted"] == false;
    if !exact {
        return Err("QSDK_R23D8_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d8_cell(stage_id: &str, arm_id: &str) -> Result<R23D8Cell, String> {
    if stage_id != R23D8_STAGE_ID {
        return Err(format!("QSDK_R23D8_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D8_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D8Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D8_ENGINE_ID}__neutral_stance__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d8_phase(trace_step: u64) -> (&'static str, Option<u64>, f64) {
    if trace_step < TURN_START_STEP {
        ("reference_warmup", Some(trace_step), 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", Some(trace_step), 1.0)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", Some(trace_step), 0.0)
    } else if trace_step < R23D8_CONTROLLER_STEPS {
        ("reference_continuation", Some(trace_step), 0.0)
    } else if trace_step < R23D8_CONTROLLER_STEPS + R23D8_CONTACT_ACQUISITION_STEPS {
        ("terminal_neutral_stance_acquisition", None, 0.0)
    } else if trace_step < R23D8_ACTIVE_STEPS {
        ("terminal_neutral_stance_hold", None, 0.0)
    } else {
        ("passive_zero_actuation_settle", None, 0.0)
    }
}

fn r23d8_expected_phase_counts() -> BTreeMap<&'static str, u64> {
    BTreeMap::from([
        ("commanded_turn", 1_200),
        ("passive_zero_actuation_settle", R23D8_PASSIVE_SETTLE_STEPS),
        ("reference_continuation", 592),
        ("reference_recovery", 600),
        ("reference_warmup", 600),
        ("terminal_neutral_stance_hold", R23D8_CONTACT_HOLD_STEPS),
        (
            "terminal_neutral_stance_acquisition",
            R23D8_CONTACT_ACQUISITION_STEPS,
        ),
    ])
}

struct R23D8NeutralComposition {
    canonical_actuation: sporespore_locomotion_core::CanonicalVelocityActuationFrameV1,
    host_mapping: sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1,
    ordered_residuals: Vec<CanonicalVelocityResidualV1>,
    receipt: Value,
}

fn r23d8_bounded_neutral_velocity(
    measured_position_rad: f64,
    measured_velocity_rad_s: f64,
) -> Result<(f64, f64, f64), String> {
    if !measured_position_rad.is_finite() || !measured_velocity_rad_s.is_finite() {
        return Err("QSDK_R23D8_RAP_NEUTRAL_OBSERVATION_NONFINITE".to_owned());
    }
    let position_error_rad = R23D8_TARGET_POSITION_RAD - measured_position_rad;
    let unbounded_velocity_rad_s = R23D8_POSITION_GAIN_PER_S * position_error_rad
        - R23D8_RATE_DAMPING * measured_velocity_rad_s;
    let bounded_velocity_rad_s = unbounded_velocity_rad_s.clamp(
        -R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
        R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
    );
    Ok((
        position_error_rad,
        unbounded_velocity_rad_s,
        bounded_velocity_rad_s,
    ))
}

fn r23d8_neutral_receipt_failures(
    receipt: &Value,
    expected_actuator_ids: &[String],
) -> Vec<String> {
    let mut failures = Vec::<String>::new();
    if receipt["schema_version"] != "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1" {
        failures.push("schema_version".to_owned());
    }
    if receipt["policy_id"] != R23D8_STANCE_POLICY_ID {
        failures.push("policy_id".to_owned());
    }
    if receipt["target_source"] != "morphology_joint_coordinate_neutral_zero_v1" {
        failures.push("target_source".to_owned());
    }
    if receipt["position_gain_per_s"] != R23D8_POSITION_GAIN_PER_S
        || receipt["measured_rate_damping"] != R23D8_RATE_DAMPING
        || receipt["maximum_absolute_joint_velocity_rad_s"]
            != R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["neutral_target_activation_count"] != R23D3_ACTUATOR_COUNT
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
    {
        failures.push("receipt_identity".to_owned());
    }
    let Some(solutions) = receipt["ordered_actuator_solutions"].as_array() else {
        failures.push("solution_shape".to_owned());
        return failures;
    };
    if solutions.len() != expected_actuator_ids.len() {
        failures.push("solution_count".to_owned());
        return failures;
    }
    for (solution, expected_actuator_id) in solutions.iter().zip(expected_actuator_ids) {
        let actuator_id = solution["actuator_id"].as_str().unwrap_or_default();
        if actuator_id != expected_actuator_id {
            failures.push(format!("actuator_order:{actuator_id}"));
        }
        let Some(measured_position_rad) = solution["measured_position_rad"].as_f64() else {
            failures.push(format!("position:{actuator_id}"));
            continue;
        };
        let Some(measured_velocity_rad_s) = solution["measured_velocity_rad_s"].as_f64() else {
            failures.push(format!("velocity:{actuator_id}"));
            continue;
        };
        let Ok((expected_error, expected_unbounded, expected_bounded)) =
            r23d8_bounded_neutral_velocity(measured_position_rad, measured_velocity_rad_s)
        else {
            failures.push(format!("equation:{actuator_id}"));
            continue;
        };
        for (field, expected) in [
            ("target_position_rad", R23D8_TARGET_POSITION_RAD),
            ("position_error_rad", expected_error),
            ("unbounded_velocity_rad_s", expected_unbounded),
            ("bounded_velocity_rad_s", expected_bounded),
        ] {
            if !solution[field]
                .as_f64()
                .is_some_and(|actual| actual.is_finite() && (actual - expected).abs() <= TOLERANCE)
            {
                failures.push(format!("{field}:{actuator_id}"));
            }
        }
        if solution["neutral_target_activated"] != true
            || solution["desired_joint_velocity_rad_s"] != solution["bounded_velocity_rad_s"]
        {
            failures.push(format!("activation:{actuator_id}"));
        }
    }
    failures
}

fn r23d8_compose_neutral_stance(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    state: &StateFrame,
    first_activation: bool,
) -> Result<R23D8NeutralComposition, String> {
    validate_controller_actuation(compiled, base_actuation)?;
    let observations = state
        .ordered_joint_observations
        .iter()
        .map(|observation| (observation.joint_id.as_str(), observation))
        .collect::<BTreeMap<_, _>>();
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if actuators.len() != R23D3_ACTUATOR_COUNT as usize
        || base_actuation.ordered_commands.len() != actuators.len()
    {
        return Err("QSDK_R23D8_RAP_NEUTRAL_ACTUATOR_COUNT_INVALID".to_owned());
    }

    let mut ordered_residuals = Vec::<CanonicalVelocityResidualV1>::with_capacity(actuators.len());
    let mut ordered_solutions = Vec::<Value>::with_capacity(actuators.len());
    for (actuator, source_command) in actuators.iter().zip(&base_actuation.ordered_commands) {
        if source_command.actuator_id != actuator.actuator_id
            || actuator.minimum_target_position_rad > R23D8_TARGET_POSITION_RAD
            || actuator.maximum_target_position_rad < R23D8_TARGET_POSITION_RAD
        {
            return Err(format!(
                "QSDK_R23D8_RAP_NEUTRAL_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let observation = observations
            .get(actuator.joint_id.as_str())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D8_RAP_NEUTRAL_OBSERVATION_MISSING:{}",
                    actuator.joint_id
                )
            })?;
        let measured_position_rad = observation
            .position_rad
            .filter(|value| value.is_finite())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D8_RAP_NEUTRAL_POSITION_INVALID:{}",
                    actuator.joint_id
                )
            })?;
        let measured_velocity_rad_s = observation
            .velocity_rad_s
            .filter(|value| value.is_finite())
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D8_RAP_NEUTRAL_VELOCITY_INVALID:{}",
                    actuator.joint_id
                )
            })?;
        let (position_error_rad, unbounded_velocity_rad_s, bounded_velocity_rad_s) =
            r23d8_bounded_neutral_velocity(measured_position_rad, measured_velocity_rad_s)?;
        let portable_source_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        ordered_residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator.actuator_id.clone(),
            canonical_velocity_delta_rad_s: bounded_velocity_rad_s - portable_source_velocity,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
        ordered_solutions.push(json!({
            "actuator_id": actuator.actuator_id,
            "joint_id": actuator.joint_id,
            "minimum_target_position_rad": actuator.minimum_target_position_rad,
            "maximum_target_position_rad": actuator.maximum_target_position_rad,
            "target_position_rad": R23D8_TARGET_POSITION_RAD,
            "measured_position_rad": measured_position_rad,
            "measured_velocity_rad_s": measured_velocity_rad_s,
            "position_error_rad": position_error_rad,
            "unbounded_velocity_rad_s": unbounded_velocity_rad_s,
            "bounded_velocity_rad_s": bounded_velocity_rad_s,
            "desired_joint_velocity_rad_s": bounded_velocity_rad_s,
            "neutral_target_activated": true,
            "pose_capture_activated": first_activation,
        }));
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    for ((canonical, host), solution) in canonical_actuation
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
        .zip(&ordered_solutions)
    {
        let desired = solution["bounded_velocity_rad_s"]
            .as_f64()
            .unwrap_or(f64::NAN);
        if !desired.is_finite()
            || (canonical.combined_canonical_target_velocity_rad_s - desired).abs() > TOLERANCE
            || (host.host_target_velocity_rad_s - desired).abs() > TOLERANCE
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "QSDK_R23D8_RAP_NEUTRAL_HOST_MAPPING_INVALID:{}",
                canonical.actuator_id
            ));
        }
    }
    let receipt = json!({
        "schema_version": "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1",
        "semantic_step": base_actuation.semantic_step,
        "policy_id": R23D8_STANCE_POLICY_ID,
        "target_source": "morphology_joint_coordinate_neutral_zero_v1",
        "position_gain_per_s": R23D8_POSITION_GAIN_PER_S,
        "measured_rate_damping": R23D8_RATE_DAMPING,
        "maximum_absolute_joint_velocity_rad_s": R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S,
        "neutral_target_activation_count": R23D3_ACTUATOR_COUNT,
        "atomic_activation_transition": first_activation,
        "ordered_actuator_solutions": ordered_solutions,
        "physics_state_modified": false,
        "command_not_measurement": true,
        "physical_acceptance_authority": false,
    });
    let failures =
        r23d8_neutral_receipt_failures(&receipt, &compiled.morphology.ordered_actuator_ids);
    if !failures.is_empty() {
        return Err(format!(
            "QSDK_R23D8_RAP_NEUTRAL_RECEIPT_INVALID:{}",
            failures.join(",")
        ));
    }
    Ok(R23D8NeutralComposition {
        canonical_actuation,
        host_mapping,
        ordered_residuals,
        receipt,
    })
}

pub fn run_qsdk_r23d8_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let contract = r23d8_contract()?;
    let cell = r23d8_cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d3_rapier_preflight(R23D8_STAGE_ID, "onset_600", arm_id)?;
    let mut phase_counts = BTreeMap::<&'static str, u64>::new();
    for trace_step in 0..R23D8_TOTAL_TRACE_STEPS {
        *phase_counts.entry(r23d8_phase(trace_step).0).or_default() += 1;
    }

    let canaries = contract["independent_oracle_canaries"]
        .as_array()
        .filter(|rows| rows.len() == R23D8_ALGEBRA_CANARY_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D8_RAP_CANARY_DECLARATION_INVALID".to_owned())?;
    for canary in canaries {
        let measured_position = canary["measured_position_rad"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D8_RAP_CANARY_POSITION_INVALID".to_owned())?;
        let measured_velocity = canary["measured_velocity_rad_s"]
            .as_f64()
            .ok_or_else(|| "QSDK_R23D8_RAP_CANARY_VELOCITY_INVALID".to_owned())?;
        let (position_error, unbounded, bounded) =
            r23d8_bounded_neutral_velocity(measured_position, measured_velocity)?;
        if (unbounded
            - canary["expected_unbounded_velocity_rad_s"]
                .as_f64()
                .unwrap_or(f64::NAN))
        .abs()
            > TOLERANCE
            || (bounded
                - canary["expected_bounded_velocity_rad_s"]
                    .as_f64()
                    .unwrap_or(f64::NAN))
            .abs()
                > TOLERANCE
            || (position_error - (R23D8_TARGET_POSITION_RAD - measured_position)).abs() > TOLERANCE
        {
            return Err("QSDK_R23D8_RAP_CANARY_ORACLE_MISMATCH".to_owned());
        }
    }

    let (compiled, controller) = compile_boundary()?;
    let turning_cell = r23d3_cell(R23D8_STAGE_ID, "onset_600", arm_id)?;
    let mut state =
        synthetic_state_frame(&compiled, heading_quaternion(cell.turn_heading_offset_rad));
    for (index, observation) in state.ordered_joint_observations.iter_mut().enumerate() {
        let canary = &canaries[index % canaries.len()];
        observation.position_rad = canary["measured_position_rad"].as_f64();
        observation.velocity_rad_s = canary["measured_velocity_rad_s"].as_f64();
    }
    let schedule = r23d3_schedule(&turning_cell, 0, state.task_frame.reference_yaw_rad);
    let command = r23d3_motion_command(0, PhaseProgressionMode::Clocked, &schedule);
    let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
    let composition = r23d8_compose_neutral_stance(&compiled, &output.actuation, &state, true)?;

    let mutation_ids = contract["required_mutation_controls"]
        .as_array()
        .filter(|rows| rows.len() == R23D8_MUTATION_CONTROL_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D8_RAP_MUTATION_DECLARATION_INVALID".to_owned())?;
    let mut mutation_rejections = Map::<String, Value>::new();
    for (index, mutation_id) in mutation_ids.iter().enumerate() {
        let mutation_id = mutation_id
            .as_str()
            .ok_or_else(|| "QSDK_R23D8_RAP_MUTATION_ID_INVALID".to_owned())?;
        let mut mutated = composition.receipt.clone();
        let solutions = mutated["ordered_actuator_solutions"]
            .as_array_mut()
            .ok_or_else(|| "QSDK_R23D8_RAP_MUTATION_SOLUTION_SHAPE".to_owned())?;
        match index {
            0 => {
                let value = solutions[0]["position_error_rad"].as_f64().unwrap_or(0.0);
                solutions[0]["position_error_rad"] = json!(-value);
            }
            1 => {
                let error = solutions[1]["position_error_rad"].as_f64().unwrap_or(0.0);
                solutions[1]["unbounded_velocity_rad_s"] = json!(R23D8_POSITION_GAIN_PER_S * error);
            }
            2 => {
                let error = solutions[1]["position_error_rad"].as_f64().unwrap_or(0.0);
                let rate = solutions[1]["measured_velocity_rad_s"]
                    .as_f64()
                    .unwrap_or(0.0);
                solutions[1]["unbounded_velocity_rad_s"] =
                    json!(R23D8_POSITION_GAIN_PER_S * error + R23D8_RATE_DAMPING * rate);
            }
            3 => {
                solutions[0]["target_position_rad"] = solutions[0]["measured_position_rad"].clone();
            }
            4 => solutions[0]["target_position_rad"] = json!(0.1),
            5 => {
                solutions[0]["bounded_velocity_rad_s"] =
                    solutions[0]["unbounded_velocity_rad_s"].clone();
            }
            6 => solutions.truncate(2),
            7 => {
                solutions.pop();
            }
            8 => solutions.swap(0, 1),
            9 => solutions[0]["target_position_rad"] = json!(0.01),
            _ => unreachable!("exact mutation count checked above"),
        }
        let rejected =
            !r23d8_neutral_receipt_failures(&mutated, &compiled.morphology.ordered_actuator_ids)
                .is_empty();
        mutation_rejections.insert(mutation_id.to_owned(), json!(rejected));
    }
    if inherited["world_build_count"] != 0
        || inherited["physical_acceptance_authority"] != false
        || inherited["inherited_predicate_negative_control_count"] != 35
        || inherited["inherited_native_mapping_canary_count"] != 7
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
        || mutation_rejections.values().any(|value| value != true)
        || phase_counts != r23d8_expected_phase_counts()
    {
        return Err("QSDK_R23D8_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R23D8_PREFLIGHT_SCHEMA,
        "campaign_id": R23D8_CAMPAIGN_ID,
        "gate_id": R23D8_GATE_ID,
        "engine_id": R23D8_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "preregistration_raw_sha256": raw_sha256(R23D8_PREREGISTRATION_RAW.as_bytes()),
        "inherited_r23d3_native_mapping_canary_count":
            inherited["inherited_native_mapping_canary_count"],
        "inherited_predicate_negative_control_count":
            inherited["inherited_predicate_negative_control_count"],
        "neutral_stance_algebra_canary_count": R23D8_ALGEBRA_CANARY_COUNT,
        "neutral_stance_mutation_control_count": R23D8_MUTATION_CONTROL_COUNT,
        "neutral_stance_mutation_controls_rejected": mutation_rejections,
        "production_neutral_stance_composition_complete": true,
        "neutral_target_activation_count": composition.receipt["neutral_target_activation_count"],
        "canonical_command_count": composition.canonical_actuation.ordered_commands.len(),
        "host_command_count": composition.host_mapping.ordered_commands.len(),
        "fixed_controller_horizon_step_count": R23D8_CONTROLLER_STEPS,
        "fixed_terminal_stance_step_count": R23D8_STANCE_STEPS,
        "fixed_passive_settle_step_count": R23D8_PASSIVE_SETTLE_STEPS,
        "fixed_total_trace_step_count": R23D8_TOTAL_TRACE_STEPS,
        "trace_phase_counts": phase_counts,
        "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        "trace_retained_before_terminal_entry_required": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn r23d8_failure(
    cell: &R23D8Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D8_FAILURE_SCHEMA,
        "campaign_id": R23D8_CAMPAIGN_ID,
        "gate_id": R23D8_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D8_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "raw_sdk_authority_summary": Value::Null,
        "godot_execution_predicates": Value::Null,

        "claims": r23d8_claims(),
    })
}

fn r23d8_source_bindings_exact(freeze: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let Ok(implementation) = serde_json::from_str::<Value>(R23D8_IMPLEMENTATION_RAW) else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]["rapier_parry"]
            .as_array()
    else {
        return false;
    };
    if declared.is_empty() {
        return false;
    }
    let mut required_paths = BTreeMap::<&str, String>::new();
    for value in declared {
        let Some(path) = value.as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        if required_paths.contains_key(path) {
            return false;
        }
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        required_paths.insert(path, raw_sha256(&bytes));
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    let mut observed = BTreeMap::<&str, &str>::new();
    for entry in bindings {
        let Some(path) = entry["path"].as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        let Some(digest) = entry["raw_sha256"].as_str().filter(|digest| {
            digest.strip_prefix("sha256:").is_some_and(|hex| {
                hex.len() == 64
                    && hex
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            })
        }) else {
            return false;
        };
        if observed.insert(path, digest).is_some() {
            return false;
        }
    }
    required_paths
        .iter()
        .all(|(path, digest)| observed.get(path).is_some_and(|value| *value == digest))
}

fn r23d8_physical_authorization(
    cell: &R23D8Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D8_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D8_RAP_CLOSED".to_owned());
    }
    let freeze_path = env::var(R23D8_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D8_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D8_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D8_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D8_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D8_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D8_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D8_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D8_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D8_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D8_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D8_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D8_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D8_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D8_CAMPAIGN_ID
        && freeze["gate_id"] == R23D8_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D8_PREREGISTRATION_RAW.as_bytes())
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d8_source_bindings_exact(&freeze)
        && attempt["schema_version"] == R23D8_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D8_CAMPAIGN_ID
        && attempt["gate_id"] == R23D8_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D8_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D8_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D8_ENGINE_ENV).unwrap_or_default() == R23D8_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D8_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_qsdk_r23d8_rapier_authorization_preflight(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let _contract = r23d8_contract()?;
    let cell = r23d8_cell(stage_id, arm_id)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D8_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    r23d8_physical_authorization(&cell, source_commit)?;
    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r23d8_rapier_production_authorization_preflight_v1",
        "campaign_id": R23D8_CAMPAIGN_ID,
        "gate_id": R23D8_GATE_ID,
        "engine_id": R23D8_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "actual_production_authorization_function": "r23d8_physical_authorization",
        "authorization_passed": true,
        "returned_before_model": true,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn r23d8_retain_trace(
    cell: &R23D8Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D8_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D8_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D8_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d8_physical_evaluator.py");
    let python = env::var(R23D8_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D8_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D8_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D8_TRACE_RETAINED ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D8_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D8_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D8_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
        || receipt["world_attempt_count"] != 0
        || receipt["world_build_count"] != 0
    {
        return Err("QSDK_R23D8_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d8_limb_contacts(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<BTreeMap<String, bool>, String> {
    let value = r23d3_foot_contacts(robot, compiled)?;
    let object = value
        .as_object()
        .ok_or_else(|| "QSDK_R23D8_RAP_CONTACT_PROJECTION_INVALID".to_owned())?;
    object
        .iter()
        .map(|(limb_id, contact)| {
            contact
                .as_bool()
                .map(|present| (limb_id.clone(), present))
                .ok_or_else(|| format!("QSDK_R23D8_RAP_CONTACT_VALUE_INVALID:{limb_id}"))
        })
        .collect()
}

fn r23d8_trace_row(
    cell: &R23D8Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_application_count: u64,
    neutral_receipt: Option<&Value>,
) -> Result<Value, String> {
    let (phase_id, controller_semantic_step, heading_multiplier) = r23d8_phase(trace_step);
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let contacts = r23d8_limb_contacts(robot, compiled)?;
    let passive = phase_id == "passive_zero_actuation_settle";
    let terminal_stance = phase_id.starts_with("terminal_neutral_stance_");
    if terminal_stance != neutral_receipt.is_some() {
        return Err("QSDK_R23D8_RAP_TRACE_NEUTRAL_RECEIPT_PRESENCE_INVALID".to_owned());
    }
    let neutral_target_activation_count = neutral_receipt
        .map(|receipt| receipt["neutral_target_activation_count"].clone())
        .unwrap_or(Value::Null);
    let mut maximum_absolute_joint_position_error_rad = None::<f64>;
    let mut maximum_absolute_commanded_joint_velocity_rad_s = None::<f64>;
    if let Some(receipt) = neutral_receipt {
        let solutions = receipt["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
            .ok_or_else(|| "QSDK_R23D8_RAP_TRACE_NEUTRAL_SOLUTIONS_INVALID".to_owned())?;
        for solution in solutions {
            let error = solution["position_error_rad"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D8_RAP_TRACE_NEUTRAL_ERROR_INVALID".to_owned())?;
            let speed = solution["bounded_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D8_RAP_TRACE_NEUTRAL_SPEED_INVALID".to_owned())?;
            maximum_absolute_joint_position_error_rad = Some(
                maximum_absolute_joint_position_error_rad
                    .unwrap_or(0.0)
                    .max(error.abs()),
            );
            maximum_absolute_commanded_joint_velocity_rad_s = Some(
                maximum_absolute_commanded_joint_velocity_rad_s
                    .unwrap_or(0.0)
                    .max(speed.abs()),
            );
        }
    }
    Ok(json!({
        "schema_version": R23D8_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": controller_semantic_step,
        "desired_heading_offset_rad":
            heading_multiplier * cell.turn_heading_offset_rad,
        "measured_yaw_rad": yaw_rad(robot),
        "torso_height_m": torso.translation().y as f64,
        "torso_tilt_rad": up.y.clamp(-1.0, 1.0).acos() as f64,

        "torso_ground_contact": robot.torso_ground_contact(),
        "ordered_foot_contacts": contacts,
        "actuator_command_count": if passive { 0 } else { R23D3_ACTUATOR_COUNT },
        "native_actuation_application_count": native_application_count,
        "zero_actuation": passive,
        "command_composition_mode": if passive {
            "passive_zero_actuation_v1"
        } else if terminal_stance {
            R23D8_STANCE_POLICY_ID
        } else {
            "balanced_wave_turning_v1"
        },
        "terminal_stance_receipt_present": terminal_stance,
        "neutral_target_activation_count": neutral_target_activation_count,
        "maximum_absolute_joint_position_error_rad":
            maximum_absolute_joint_position_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s":
            maximum_absolute_commanded_joint_velocity_rad_s,
    }))
}

// Inherited R23D6 receipt validator retained as inspectable predecessor code.
// R23D8 production and preflight routes never call it; both call the neutral
// receipt validator and composer above.
fn r23d8_obsolete_predecessor_restoration_validator(
    composition: &QsdkContactRestorationComposition,
    pre_step_contacts: &BTreeMap<String, bool>,
    independent_pose_memory: &mut BTreeMap<String, f64>,
) -> Result<(u64, f64), String> {
    let receipt = &composition.receipt;
    if receipt["policy_id"]
        != "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1"
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != 8.0
        || receipt["pose_hold_rate_damping"] != 0.65
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || receipt["damped_least_squares_lambda_m"] != 0.04
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
        || composition.canonical_actuation.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.host_mapping.ordered_commands.len() != R23D3_ACTUATOR_COUNT as usize
        || composition.ordered_residuals.len() != R23D3_ACTUATOR_COUNT as usize
    {
        return Err("QSDK_R23D8_RAP_RESTORATION_RECEIPT_IDENTITY_INVALID".to_owned());
    }
    let limbs = receipt["ordered_limb_solutions"]
        .as_array()
        .filter(|rows| rows.len() == 4)
        .ok_or_else(|| "QSDK_R23D8_RAP_RESTORATION_LIMB_COUNT_INVALID".to_owned())?;
    let mut capture_count = 0_u64;
    let mut maximum_speed = 0.0_f64;
    let mut actuator_seen = BTreeMap::<String, bool>::new();
    for limb in limbs {
        let site_id = limb["contact_site_id"]
            .as_str()
            .ok_or_else(|| "QSDK_R23D8_RAP_RESTORATION_SITE_ID_INVALID".to_owned())?;
        let contact = *pre_step_contacts
            .get(site_id)
            .ok_or_else(|| format!("QSDK_R23D8_RAP_RESTORATION_SITE_CONTACT_MISSING:{site_id}"))?;
        if limb["pre_step_contact"] != contact {
            return Err(format!(
                "QSDK_R23D8_RAP_RESTORATION_CONTACT_RECEIPT_INVALID:{site_id}"
            ));
        }
        let actuators = limb["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == 2)
            .ok_or_else(|| {
                format!("QSDK_R23D8_RAP_RESTORATION_ACTUATOR_COUNT_INVALID:{site_id}")
            })?;
        for actuator in actuators {
            let actuator_id = actuator["actuator_id"]
                .as_str()
                .ok_or_else(|| "QSDK_R23D8_RAP_RESTORATION_ACTUATOR_ID_INVALID".to_owned())?;
            if actuator_seen.insert(actuator_id.to_owned(), true).is_some() {
                return Err(format!(
                    "QSDK_R23D8_RAP_RESTORATION_ACTUATOR_DUPLICATE:{actuator_id}"
                ));
            }
            let desired_speed = actuator["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| format!("QSDK_R23D8_RAP_RESTORATION_SPEED_INVALID:{actuator_id}"))?;
            maximum_speed = maximum_speed.max(desired_speed.abs());
            if maximum_speed > R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S + TOLERANCE
                || !actuator["portable_heading_target_delta_rad"]
                    .as_f64()
                    .is_some_and(|value| value.is_finite())
            {
                return Err(format!(
                    "QSDK_R23D8_RAP_RESTORATION_COMMAND_INVALID:{actuator_id}"
                ));
            }
            let capture_activated =
                actuator["pose_capture_activated"]
                    .as_bool()
                    .ok_or_else(|| {
                        format!("QSDK_R23D8_RAP_RESTORATION_CAPTURE_INVALID:{actuator_id}")
                    })?;
            if contact {
                let neutral = actuator["neutral_joint_position_rad"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .ok_or_else(|| {
                        format!("QSDK_R23D8_RAP_RESTORATION_NEUTRAL_INVALID:{actuator_id}")
                    })?;
                let expected_capture = !independent_pose_memory.contains_key(actuator_id);
                if capture_activated != expected_capture {
                    return Err(format!(
                        "QSDK_R23D8_RAP_RESTORATION_CAPTURE_TRANSITION_INVALID:{actuator_id}"
                    ));
                }
                if expected_capture {
                    independent_pose_memory.insert(actuator_id.to_owned(), neutral);
                    capture_count += 1;
                } else if (independent_pose_memory[actuator_id] - neutral).abs() > TOLERANCE {
                    return Err(format!(
                        "QSDK_R23D8_RAP_RESTORATION_NEUTRAL_CHANGED:{actuator_id}"
                    ));
                }
            } else {
                if capture_activated || actuator["neutral_joint_position_rad"] != Value::Null {
                    return Err(format!(
                        "QSDK_R23D8_RAP_RESTORATION_MISSING_LIMB_CAPTURED:{actuator_id}"
                    ));
                }
                independent_pose_memory.remove(actuator_id);
            }
        }
    }
    if actuator_seen.len() != R23D3_ACTUATOR_COUNT as usize
        || receipt["pose_memory_actuator_count"] != independent_pose_memory.len() as u64
    {
        return Err("QSDK_R23D8_RAP_RESTORATION_MEMORY_COUNT_INVALID".to_owned());
    }
    Ok((capture_count, maximum_speed))
}

pub fn run_qsdk_r23d8_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d8_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D8_FAILURE_SCHEMA,
            "campaign_id": R23D8_CAMPAIGN_ID,
            "gate_id": R23D8_GATE_ID,
            "stage_id": stage_id,
            "engine_id": R23D8_ENGINE_ID,
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d8_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d8_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D8_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d8_contract().map_err(&before_world)?;
    let attempt_root = r23d8_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight = run_qsdk_r23d8_rapier_preflight(stage_id, arm_id).map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D8_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The attempt boundary is immediately before the one native world build.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d8_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d8_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d8_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut neutral_stance_activated = false;
    let mut trace_rows = Vec::<Value>::with_capacity(R23D8_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;

    let mut native_actuation_application_count = 0_u64;
    let passive_native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut neutral_stance_receipt_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut neutral_target_activation_command_count = 0_u64;
    let neutral_target_activation_failure_count = 0_u64;
    let mut neutral_target_transition_count = 0_u64;
    let neutral_target_transition_failure_count = 0_u64;
    let mut maximum_terminal_stance_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut first_all_four_contact_terminal_stance_step = None::<u64>;
    let mut consecutive_all_four_contact_hold_step_count = 0_u64;
    let mut maximum_consecutive_all_four_contact_hold_step_count = 0_u64;

    for semantic_step in 0..R23D8_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D8_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d8_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D8_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D8_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D8_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d8_trace_row(&cell, semantic_step, &robot, &compiled, applications, None)
                .map_err(&settled_failure)?,
        );
    }

    for stance_step in 0..R23D8_STANCE_STEPS {
        let trace_step = R23D8_CONTROLLER_STEPS + stance_step;
        let state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
        let command =
            r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if output.actuation.receipt.semantic_step != trace_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
            || !oracle_failures.is_empty()
        {
            return Err(settled_failure(format!(
                "QSDK_R23D8_RAP_STANCE_CONTROLLER_INVALID:{}",
                oracle_failures.join(",")
            )));
        }
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let first_activation = !neutral_stance_activated;
        let composition =
            r23d8_compose_neutral_stance(&compiled, &output.actuation, &state, first_activation)
                .map_err(&settled_failure)?;
        if composition.receipt["semantic_step"] != trace_step {
            return Err(settled_failure(
                "QSDK_R23D8_RAP_STANCE_STEP_INVALID".to_owned(),
            ));
        }
        let receipt_failures = r23d8_neutral_receipt_failures(
            &composition.receipt,
            &compiled.morphology.ordered_actuator_ids,
        );
        if !receipt_failures.is_empty() {
            return Err(settled_failure(format!(
                "QSDK_R23D8_RAP_STANCE_RECEIPT_INVALID:{}",
                receipt_failures.join(",")
            )));
        }
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        composition
            .host_mapping
            .validate(
                &compiled.morphology,
                &composition.canonical_actuation,
                &host_profile,
            )
            .map_err(|error| {
                settled_failure(format!(
                    "QSDK_R23D8_RAP_STANCE_HOST_MAPPING_INVALID:{error}"
                ))
            })?;
        let solutions = composition.receipt["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
            .ok_or_else(|| settled_failure("QSDK_R23D8_RAP_STANCE_SOLUTIONS_INVALID".to_owned()))?;
        let activation_count = solutions
            .iter()
            .filter(|solution| solution["neutral_target_activated"] == true)
            .count() as u64;
        neutral_stance_receipt_count += 1;
        neutral_target_activation_command_count += activation_count;
        if first_activation {
            neutral_target_transition_count += solutions
                .iter()
                .filter(|solution| solution["pose_capture_activated"] == true)
                .count() as u64;
            neutral_stance_activated = true;
        }
        let mut step_maximum_speed = 0.0_f64;
        for solution in solutions {
            let desired = solution["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| settled_failure("QSDK_R23D8_RAP_STANCE_SPEED_INVALID".to_owned()))?;
            step_maximum_speed = step_maximum_speed.max(desired.abs());
        }
        maximum_terminal_stance_joint_speed =
            maximum_terminal_stance_joint_speed.max(step_maximum_speed);
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        let contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
        let all_four_contacts = contacts.values().all(|contact| *contact);
        if all_four_contacts && first_all_four_contact_terminal_stance_step.is_none() {
            first_all_four_contact_terminal_stance_step = Some(stance_step);
        }
        if stance_step >= R23D8_CONTACT_ACQUISITION_STEPS {
            if all_four_contacts {
                consecutive_all_four_contact_hold_step_count += 1;
                maximum_consecutive_all_four_contact_hold_step_count =
                    maximum_consecutive_all_four_contact_hold_step_count
                        .max(consecutive_all_four_contact_hold_step_count);
            } else {
                consecutive_all_four_contact_hold_step_count = 0;
            }
        }
        trace_rows.push(
            r23d8_trace_row(
                &cell,
                trace_step,
                &robot,
                &compiled,
                applications,
                Some(&composition.receipt),
            )
            .map_err(&settled_failure)?,
        );
    }

    for passive_step in 0..R23D8_PASSIVE_SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&settled_failure)?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        let tilt = up.y.clamp(-1.0, 1.0).acos() as f64;
        let height = torso.translation().y as f64;
        let yaw = yaw_rad(&robot);
        nonfinite_observation_count +=
            u64::from(!tilt.is_finite() || !height.is_finite() || !yaw.is_finite());
        maximum_tilt_rad = maximum_tilt_rad.max(tilt);
        minimum_torso_height_m = minimum_torso_height_m.min(height);
        torso_ground_contact_step_count += u64::from(robot.torso_ground_contact());
        trace_rows.push(
            r23d8_trace_row(
                &cell,
                R23D8_ACTIVE_STEPS + passive_step,
                &robot,
                &compiled,
                0,
                None,
            )
            .map_err(&settled_failure)?,
        );
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D8_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d8_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D8_REPORT_SCHEMA,
        "campaign_id": R23D8_CAMPAIGN_ID,
        "gate_id": R23D8_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D8_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D8_CONTROLLER_STEPS,
            "terminal_stance_step_count": R23D8_STANCE_STEPS,
            "passive_settle_step_count": R23D8_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D8_CONTROLLER_STEPS,
            "terminal_stance_step_count": R23D8_STANCE_STEPS,
            "passive_settle_step_count": R23D8_PASSIVE_SETTLE_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "passive_native_actuation_application_count":
                passive_native_actuation_application_count,
            "neutral_stance_receipt_count": neutral_stance_receipt_count,
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "first_all_four_contact_terminal_stance_step":
                first_all_four_contact_terminal_stance_step
                    .unwrap_or(R23D8_CONTACT_ACQUISITION_STEPS),
            "consecutive_all_four_contact_hold_step_count":
                maximum_consecutive_all_four_contact_hold_step_count,
            "neutral_target_activation_command_count":
                neutral_target_activation_command_count,
            "neutral_target_activation_failure_count":
                neutral_target_activation_failure_count,
            "neutral_target_transition_count": neutral_target_transition_count,
            "neutral_target_transition_failure_count":
                neutral_target_transition_failure_count,
            "maximum_absolute_terminal_stance_joint_velocity_rad_s":
                maximum_terminal_stance_joint_speed,
            "passive_settle_trace_row_count": R23D8_PASSIVE_SETTLE_STEPS,
        },
        "godot_execution_predicates": Value::Null,
        "claims": r23d8_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d8_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D8_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

// R23D9 keeps the R23D8 neutral-stance equation and replaces the fixed
// active/passive terminal schedule with a support-confirmed, irreversible
// handoff. These helpers remain beside the qualified Rapier fixture so the
// physical route reuses the exact native world, observation, mapping, and
// neutral-composition implementation rather than creating a parallel adapter.
const R23D9_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d9_support_handoff_preregistration_v1.json");
const R23D9_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d9_physical_implementation_contract_v1.json";
const R23D9_CLOSURE_PATH: &str = "sdk/turning/r23d9_physical_closure_v1.json";
const R23D9_CAMPAIGN_ID: &str =
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-BILATERAL-TURN-DEVELOPMENT";
const R23D9_GATE_ID: &str = "QSDK-R23D9";
const R23D9_ENGINE_ID: &str = "rapier_parry";
const R23D9_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d9_engine_cell_report_v1";
const R23D9_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d9_worker_failure_v1";
const R23D9_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d9_turn_support_handoff_trace_row_v1";
const R23D9_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d9_trace_retention_v1";
const R23D9_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d9_physical_freeze_v1";
const R23D9_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d9_attempt_v1";
const R23D9_STAGE_ID: &str = "three_engine_confirmation";
const R23D9_CONTROLLER_STEPS: u64 = 2_992;
const R23D9_TERMINAL_STEPS: u64 = 780;
const R23D9_TOTAL_TRACE_STEPS: u64 = R23D9_CONTROLLER_STEPS + R23D9_TERMINAL_STEPS;
const R23D9_MAXIMUM_ACTIVE_STEPS: u64 = 420;
const R23D9_SUPPORT_CONFIRMATION_STEPS: u64 = 30;
const R23D9_MINIMUM_PASSIVE_STEPS: u64 = 360;
const R23D9_ACTIVE_MODE: &str = "active_neutral_acquisition";
const R23D9_PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const R23D9_SUPPORT_REASON: &str = "support_confirmed";
const R23D9_DEADLINE_REASON: &str = "deadline_forced_without_support_confirmation";

const R23D9_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D9_FREEZE";
const R23D9_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D9_ATTEMPT";
const R23D9_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D9_TOKEN";
const R23D9_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D9_STAGE";
const R23D9_CELL_ENV: &str = "SPORESPORE_QSDK_R23D9_CELL";
const R23D9_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D9_ENGINE";
const R23D9_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D9_ATTEMPT_ROOT";
const R23D9_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D9_PYTHON";
const R23D9_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D9_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D9Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

#[derive(Debug, Clone)]
struct R23D9HandoffState {
    next_step: u64,
    active: bool,
    support_counter: u64,
    handoff_after: Option<u64>,
    first_passive: Option<u64>,
    handoff_reason: Option<&'static str>,
    support_confirmed: bool,
    active_steps: u64,
    passive_steps: u64,
    active_applications: u64,
    passive_applications: u64,
    first_post_handoff_contact_loss: Option<u64>,
    post_handoff_contact_loss_count: u64,
}

#[derive(Debug)]
struct R23D9ObservationFields {
    measured_yaw_rad: f64,
    torso_height_m: f64,
    torso_tilt_rad: f64,
    torso_ground_contact: bool,
    ordered_foot_contacts: BTreeMap<String, bool>,
}

impl Default for R23D9HandoffState {
    fn default() -> Self {
        Self {
            next_step: 0,
            active: true,
            support_counter: 0,
            handoff_after: None,
            first_passive: None,
            handoff_reason: None,
            support_confirmed: false,
            active_steps: 0,
            passive_steps: 0,
            active_applications: 0,
            passive_applications: 0,
            first_post_handoff_contact_loss: None,
            post_handoff_contact_loss_count: 0,
        }
    }
}

fn r23d9_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d9_cell(stage_id: &str, arm_id: &str) -> Result<R23D9Cell, String> {
    if stage_id != R23D9_STAGE_ID {
        return Err(format!("QSDK_R23D9_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D9_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D9Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D9_ENGINE_ID}__support_handoff__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d9_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D9_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D9_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let schedule = &contract["frozen_schedule_and_gate_snapshot"];
    let machine = &contract["handoff_state_machine_contract"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d9_support_handoff_preregistration_v1"
        && contract["campaign_id"] == R23D9_CAMPAIGN_ID
        && contract["gate_id"] == R23D9_GATE_ID
        && contract["authorization"]["physical_execution_authorized"] == false
        && schedule["turning_controller_semantic_step_count"] == R23D9_CONTROLLER_STEPS
        && schedule["terminal_support_handoff_step_count"] == R23D9_TERMINAL_STEPS
        && schedule["maximum_active_neutral_acquisition_steps"] == R23D9_MAXIMUM_ACTIVE_STEPS
        && schedule["support_confirmation_step_count"] == R23D9_SUPPORT_CONFIRMATION_STEPS
        && schedule["minimum_post_handoff_zero_actuation_steps"] == R23D9_MINIMUM_PASSIVE_STEPS
        && schedule["total_traced_step_count"] == R23D9_TOTAL_TRACE_STEPS
        && machine["initial_mode"] == R23D9_ACTIVE_MODE
        && machine["passive_mode"] == R23D9_PASSIVE_MODE
        && machine["transition_is_applied_to_next_step"] == true
        && machine["mode_reactivation_permitted"] == false;
    if !exact {
        return Err("QSDK_R23D9_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d9_failure(
    cell: &R23D9Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D9_FAILURE_SCHEMA,
        "campaign_id": R23D9_CAMPAIGN_ID,
        "gate_id": R23D9_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D9_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "claims": r23d9_claims(),
    })
}

fn r23d9_source_bindings_exact(freeze: &Value, implementation: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]
            [R23D9_ENGINE_ID]
            .as_array()
    else {
        return false;
    };
    if declared.is_empty() {
        return false;
    }
    let mut required_paths = BTreeMap::<&str, String>::new();
    for value in declared {
        let Some(path) = value.as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        if required_paths.contains_key(path) {
            return false;
        }
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        required_paths.insert(path, raw_sha256(&bytes));
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    let mut observed = BTreeMap::<&str, &str>::new();
    for entry in bindings {
        let Some(path) = entry["path"].as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        let Some(digest) = entry["raw_sha256"].as_str().filter(|digest| {
            digest.strip_prefix("sha256:").is_some_and(|hex| {
                hex.len() == 64
                    && hex
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            })
        }) else {
            return false;
        };
        if observed.insert(path, digest).is_some() {
            return false;
        }
    }
    required_paths
        .iter()
        .all(|(path, digest)| observed.get(path).is_some_and(|value| *value == digest))
}

fn r23d9_physical_authorization(
    cell: &R23D9Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D9_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D9_RAP_CLOSED".to_owned());
    }
    let implementation_path = repo_root.join(R23D9_IMPLEMENTATION_PATH);
    let freeze_path = env::var(R23D9_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D9_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D9_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D9_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !implementation_path.is_file()
        || !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D9_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let implementation_raw = fs::read(&implementation_path)
        .map_err(|_| "QSDK_R23D9_RAP_IMPLEMENTATION_UNREADABLE".to_owned())?;
    let implementation: Value = serde_json::from_slice(&implementation_raw)
        .map_err(|_| "QSDK_R23D9_RAP_IMPLEMENTATION_JSON_INVALID".to_owned())?;
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D9_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D9_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D9_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D9_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D9_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D9_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D9_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D9_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D9_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D9_CAMPAIGN_ID
        && freeze["gate_id"] == R23D9_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"] == raw_sha256(R23D9_PREREGISTRATION_RAW.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d9_source_bindings_exact(&freeze, &implementation)
        && attempt["schema_version"] == R23D9_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D9_CAMPAIGN_ID
        && attempt["gate_id"] == R23D9_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D9_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D9_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D9_ENGINE_ENV).unwrap_or_default() == R23D9_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D9_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_qsdk_r23d9_rapier_authorization_preflight_impl(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let _contract = r23d9_contract()?;
    let cell = r23d9_cell(stage_id, arm_id)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D9_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    r23d9_physical_authorization(&cell, source_commit)?;
    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r23d9_rapier_production_authorization_preflight_v1",
        "campaign_id": R23D9_CAMPAIGN_ID,
        "gate_id": R23D9_GATE_ID,
        "engine_id": R23D9_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "actual_production_authorization_function": "r23d9_physical_authorization",
        "authorization_passed": true,
        "returned_before_model": true,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn r23d9_observe_handoff(
    state: &R23D9HandoffState,
    contacts: &BTreeMap<String, bool>,
    native_applications: u64,
) -> Result<(R23D9HandoffState, Value), String> {
    if state.next_step >= R23D9_TERMINAL_STEPS {
        return Err("QSDK_R23D9_RAP_STEP_OUTSIDE_TERMINAL_HORIZON".to_owned());
    }
    let expected_applications = if state.active {
        R23D3_ACTUATOR_COUNT
    } else {
        0
    };
    if native_applications != expected_applications {
        return Err("QSDK_R23D9_RAP_NATIVE_APPLICATION_COUNT_MISMATCH".to_owned());
    }
    let all_four = contacts.len() == 4 && contacts.values().all(|present| *present);
    let mut next = state.clone();
    let pre_counter = state.support_counter;
    let mut transitioned = false;
    next.next_step += 1;
    if state.active {
        next.active_steps += 1;
        next.active_applications += native_applications;
        next.support_counter = if all_four {
            state.support_counter + 1
        } else {
            0
        };
        if next.support_counter >= R23D9_SUPPORT_CONFIRMATION_STEPS {
            next.active = false;
            next.handoff_after = Some(state.next_step);
            next.first_passive = Some(state.next_step + 1);
            next.handoff_reason = Some(R23D9_SUPPORT_REASON);
            next.support_confirmed = true;
            transitioned = true;
        } else if state.next_step == R23D9_MAXIMUM_ACTIVE_STEPS - 1 {
            next.active = false;
            next.handoff_after = Some(state.next_step);
            next.first_passive = Some(state.next_step + 1);
            next.handoff_reason = Some(R23D9_DEADLINE_REASON);
            next.support_confirmed = false;
            transitioned = true;
        } else if state.next_step >= R23D9_MAXIMUM_ACTIVE_STEPS {
            return Err("QSDK_R23D9_RAP_ACTIVE_STEP_AFTER_DEADLINE".to_owned());
        }
    } else {
        next.passive_steps += 1;
        next.passive_applications += native_applications;
        if !all_four {
            next.post_handoff_contact_loss_count += 1;
            if next.first_post_handoff_contact_loss.is_none() {
                next.first_post_handoff_contact_loss = Some(state.next_step);
            }
        }
    }
    let receipt = json!({
        "pre_step_support_counter": pre_counter,
        "post_step_support_counter": next.support_counter,
        "transition_after_step": transitioned,
        "next_mode": if next.active { R23D9_ACTIVE_MODE } else { R23D9_PASSIVE_MODE },
        "handoff_reason": if transitioned { next.handoff_reason } else { None::<&str> },
        "native_application_count": native_applications,
    });
    Ok((next, receipt))
}

fn r23d9_handoff_outcome(state: &R23D9HandoffState) -> Result<Value, String> {
    if state.next_step != R23D9_TERMINAL_STEPS {
        return Err("QSDK_R23D9_RAP_OUTCOME_BEFORE_COMPLETE_HORIZON".to_owned());
    }
    let passed = state.support_confirmed
        && state.handoff_reason == Some(R23D9_SUPPORT_REASON)
        && state.first_passive.is_some_and(|step| {
            (R23D9_SUPPORT_CONFIRMATION_STEPS..=R23D9_MAXIMUM_ACTIVE_STEPS).contains(&step)
        })
        && state.passive_steps >= R23D9_MINIMUM_PASSIVE_STEPS
        && state.passive_applications == 0
        && state.post_handoff_contact_loss_count == 0
        && !state.active;
    Ok(json!({
        "support_confirmed": state.support_confirmed,
        "handoff_after_active_step": state.handoff_after,
        "first_passive_step": state.first_passive,
        "handoff_reason": state.handoff_reason,
        "active_step_count": state.active_steps,
        "passive_step_count": state.passive_steps,
        "active_native_application_count": state.active_applications,
        "passive_native_application_count": state.passive_applications,
        "first_post_handoff_contact_loss_step": state.first_post_handoff_contact_loss,
        "post_handoff_contact_loss_step_count": state.post_handoff_contact_loss_count,
        "irreversible_handoff_gate_passed": passed,
    }))
}

fn r23d9_observation_fields(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<R23D9ObservationFields, String> {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    Ok(R23D9ObservationFields {
        measured_yaw_rad: yaw_rad(robot),
        torso_height_m: torso.translation().y as f64,
        torso_tilt_rad: up.y.clamp(-1.0, 1.0).acos() as f64,
        torso_ground_contact: robot.torso_ground_contact(),
        ordered_foot_contacts: r23d8_limb_contacts(robot, compiled)?,
    })
}

fn r23d9_controller_trace_row(
    cell: &R23D9Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_applications: u64,
) -> Result<Value, String> {
    let (phase_id, heading_offset) = if trace_step < TURN_START_STEP {
        ("reference_warmup", 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", cell.turn_heading_offset_rad)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", 0.0)
    } else {
        ("reference_continuation", 0.0)
    };
    let observation = r23d9_observation_fields(robot, compiled)?;
    Ok(json!({
        "schema_version": R23D9_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": trace_step,
        "desired_heading_offset_rad": heading_offset,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "actuator_command_count": R23D3_ACTUATOR_COUNT,
        "native_actuation_application_count": native_applications,
        "zero_actuation": false,
        "command_composition_mode": "balanced_wave_turning_v1",
        "handoff_receipt_present": false,
        "pre_step_support_counter": Value::Null,
        "post_step_support_counter": Value::Null,
        "transition_after_step": false,
        "next_terminal_mode": Value::Null,
        "handoff_reason": Value::Null,
        "maximum_absolute_joint_position_error_rad": Value::Null,
        "maximum_absolute_commanded_joint_velocity_rad_s": Value::Null,
    }))
}

fn r23d9_terminal_trace_row(
    cell: &R23D9Cell,
    trace_step: u64,
    active: bool,
    handoff_receipt: &Value,
    neutral_receipt: Option<&Value>,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<Value, String> {
    if active != neutral_receipt.is_some() {
        return Err("QSDK_R23D9_RAP_TERMINAL_RECEIPT_PRESENCE_INVALID".to_owned());
    }
    let observation = r23d9_observation_fields(robot, compiled)?;
    let mut maximum_error = None::<f64>;
    let mut maximum_speed = None::<f64>;
    if let Some(receipt) = neutral_receipt {
        let solutions = receipt["ordered_actuator_solutions"]
            .as_array()
            .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
            .ok_or_else(|| "QSDK_R23D9_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())?;
        for solution in solutions {
            let error = solution["position_error_rad"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D9_RAP_TERMINAL_ERROR_INVALID".to_owned())?;
            let speed = solution["desired_joint_velocity_rad_s"]
                .as_f64()
                .filter(|value| value.is_finite())
                .ok_or_else(|| "QSDK_R23D9_RAP_TERMINAL_SPEED_INVALID".to_owned())?;
            maximum_error = Some(maximum_error.unwrap_or(0.0).max(error.abs()));
            maximum_speed = Some(maximum_speed.unwrap_or(0.0).max(speed.abs()));
        }
    }
    Ok(json!({
        "schema_version": R23D9_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": if active {
            "terminal_neutral_acquisition"
        } else {
            "terminal_irreversible_zero_actuation"
        },
        "controller_semantic_step": Value::Null,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "actuator_command_count": if active { R23D3_ACTUATOR_COUNT } else { 0 },
        "native_actuation_application_count":
            handoff_receipt["native_application_count"].clone(),
        "zero_actuation": !active,
        "command_composition_mode": if active {
            R23D8_STANCE_POLICY_ID
        } else {
            "passive_zero_actuation_v1"
        },
        "handoff_receipt_present": true,
        "pre_step_support_counter": handoff_receipt["pre_step_support_counter"].clone(),
        "post_step_support_counter": handoff_receipt["post_step_support_counter"].clone(),
        "transition_after_step": handoff_receipt["transition_after_step"].clone(),
        "next_terminal_mode": handoff_receipt["next_mode"].clone(),
        "handoff_reason": handoff_receipt["handoff_reason"].clone(),
        "maximum_absolute_joint_position_error_rad": maximum_error,
        "maximum_absolute_commanded_joint_velocity_rad_s": maximum_speed,
    }))
}

fn r23d9_retain_trace(
    cell: &R23D9Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D9_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D9_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D9_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d9_physical_evaluator.py");
    let python = env::var(R23D9_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D9_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D9_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = "QSDK_R23D9_EVALUATION ";
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D9_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D9_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D9_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D9_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

pub fn run_qsdk_r23d9_rapier_physical_impl(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d9_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D9_FAILURE_SCHEMA,
            "campaign_id": R23D9_CAMPAIGN_ID,
            "gate_id": R23D9_GATE_ID,
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": R23D9_ENGINE_ID,
            "arm_id": arm_id,
            "turn_heading_offset_rad": Value::Null,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": Value::Null,
            "claims": r23d9_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d9_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D9_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d9_contract().map_err(&before_world)?;
    let attempt_root = r23d9_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight =
        crate::qsdk_r23d9_support_handoff::run_qsdk_r23d9_rapier_preflight(stage_id, arm_id)
            .map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D8_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The native world-attempt counter becomes one immediately before this
    // sole fixture construction. All authorization and preflight work above is
    // zero-world and therefore cannot accidentally spend the one-shot cell.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d9_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d9_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d9_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut neutral_stance_activated = false;
    let mut handoff = R23D9HandoffState::default();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D9_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut maximum_terminal_active_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;

    for semantic_step in 0..R23D9_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D9_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d9_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D9_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D9_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let observation = r23d9_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &observation.ordered_foot_contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D9_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = observation.ordered_foot_contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d9_controller_trace_row(&cell, semantic_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for terminal_step in 0..R23D9_TERMINAL_STEPS {
        let trace_step = R23D9_CONTROLLER_STEPS + terminal_step;
        let active = handoff.active;
        let mut neutral_receipt = None::<Value>;
        let applications;
        if active {
            let state = physical_state_frame(
                &robot,
                &compiled,
                trace_step,
                task_origin,
                reference_heading_rad,
            )
            .map_err(&settled_failure)?;
            nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
            let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
            let command =
                r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
            let output = controller.step(&memory, &state, &command);
            controller_error_count += u64::from(
                output.actuation.receipt.controller_error.is_some()
                    || !output.actuation.failure_codes.is_empty(),
            );
            active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
            validate_controller_actuation(&compiled, &output.actuation)
                .map_err(&settled_failure)?;
            let expected = independent_oracle(&state, &command, controller.profile())
                .map_err(&settled_failure)?;
            let observed = receipt_values(&output.actuation.receipt);
            let oracle_failures = predicate_failures(expected, observed);
            if output.actuation.receipt.semantic_step != trace_step
                || output.actuation.receipt.command_id != command.command_id
                || output.actuation.receipt.policy_id != POLICY_ID
                || !oracle_failures.is_empty()
            {
                return Err(settled_failure(format!(
                    "QSDK_R23D9_RAP_TERMINAL_CONTROLLER_INVALID:{}",
                    oracle_failures.join(",")
                )));
            }
            maximum_requested =
                maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
            maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
            let first_activation = !neutral_stance_activated;
            let composition = r23d8_compose_neutral_stance(
                &compiled,
                &output.actuation,
                &state,
                first_activation,
            )
            .map_err(&settled_failure)?;
            let receipt_failures = r23d8_neutral_receipt_failures(
                &composition.receipt,
                &compiled.morphology.ordered_actuator_ids,
            );
            if composition.receipt["semantic_step"] != trace_step || !receipt_failures.is_empty() {
                return Err(settled_failure(format!(
                    "QSDK_R23D9_RAP_TERMINAL_RECEIPT_INVALID:{}",
                    receipt_failures.join(",")
                )));
            }
            let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
            composition
                .host_mapping
                .validate(
                    &compiled.morphology,
                    &composition.canonical_actuation,
                    &host_profile,
                )
                .map_err(|error| {
                    settled_failure(format!(
                        "QSDK_R23D9_RAP_TERMINAL_HOST_MAPPING_INVALID:{error}"
                    ))
                })?;
            let solutions = composition.receipt["ordered_actuator_solutions"]
                .as_array()
                .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
                .ok_or_else(|| {
                    settled_failure("QSDK_R23D9_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())
                })?;
            let step_maximum_speed = solutions.iter().try_fold(0.0_f64, |maximum, solution| {
                solution["desired_joint_velocity_rad_s"]
                    .as_f64()
                    .filter(|value| value.is_finite())
                    .map(|speed| maximum.max(speed.abs()))
                    .ok_or_else(|| {
                        settled_failure("QSDK_R23D9_RAP_TERMINAL_SPEED_INVALID".to_owned())
                    })
            })?;
            maximum_terminal_active_joint_speed =
                maximum_terminal_active_joint_speed.max(step_maximum_speed);
            validated_portable_command_count += solutions.len() as u64;
            let (step_applications, impulse_violations) = robot
                .apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)
                .map_err(&settled_failure)?;
            applications = step_applications;
            native_actuation_application_count += applications;
            portable_impulse_violation_count += impulse_violations;
            actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
            memory = output.next_memory;
            neutral_stance_activated = true;
            neutral_receipt = Some(composition.receipt);
        } else {
            robot
                .hold_velocity_only_v4_zero_and_step()
                .map_err(&settled_failure)?;
            applications = 0;
        }

        let observation = r23d9_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        let (next_handoff, handoff_receipt) =
            r23d9_observe_handoff(&handoff, &observation.ordered_foot_contacts, applications)
                .map_err(&settled_failure)?;
        trace_rows.push(
            r23d9_terminal_trace_row(
                &cell,
                trace_step,
                active,
                &handoff_receipt,
                neutral_receipt.as_ref(),
                &robot,
                &compiled,
            )
            .map_err(&settled_failure)?,
        );
        handoff = next_handoff;
    }

    let handoff_outcome = r23d9_handoff_outcome(&handoff).map_err(&settled_failure)?;
    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D9_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d9_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D9_REPORT_SCHEMA,
        "campaign_id": R23D9_CAMPAIGN_ID,
        "gate_id": R23D9_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D9_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D9_CONTROLLER_STEPS,
            "terminal_support_handoff_step_count": R23D9_TERMINAL_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                handoff.passive_applications,
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D9_CONTROLLER_STEPS,
            "terminal_support_handoff_step_count": R23D9_TERMINAL_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                handoff.passive_applications,
            "support_confirmed": handoff_outcome["support_confirmed"].clone(),
            "handoff_after_active_step": handoff_outcome["handoff_after_active_step"].clone(),
            "first_passive_step": handoff_outcome["first_passive_step"].clone(),
            "handoff_reason": handoff_outcome["handoff_reason"].clone(),
            "active_terminal_step_count": handoff_outcome["active_step_count"].clone(),
            "passive_terminal_step_count": handoff_outcome["passive_step_count"].clone(),
            "first_post_handoff_contact_loss_step":
                handoff_outcome["first_post_handoff_contact_loss_step"].clone(),
            "post_handoff_contact_loss_step_count":
                handoff_outcome["post_handoff_contact_loss_step_count"].clone(),
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "maximum_absolute_terminal_active_joint_velocity_rad_s":
                maximum_terminal_active_joint_speed,
        },
        "claims": r23d9_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d9_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D9_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

#[cfg(test)]
mod r23d9_physical_tests {
    use super::*;

    fn contacts(all_four: bool) -> BTreeMap<String, bool> {
        BTreeMap::from([
            ("front_left".to_owned(), true),
            ("front_right".to_owned(), true),
            ("rear_left".to_owned(), true),
            ("rear_right".to_owned(), all_four),
        ])
    }

    #[test]
    fn production_handoff_machine_transitions_only_on_following_step() {
        let mut state = R23D9HandoffState::default();
        let supported = contacts(true);
        for step in 0..R23D9_TERMINAL_STEPS {
            let was_active = state.active;
            let applications = if was_active { R23D3_ACTUATOR_COUNT } else { 0 };
            let (next, receipt) = r23d9_observe_handoff(&state, &supported, applications)
                .expect("production handoff observation");
            if step == R23D9_SUPPORT_CONFIRMATION_STEPS - 1 {
                assert!(was_active);
                assert_eq!(receipt["transition_after_step"], true);
                assert_eq!(receipt["next_mode"], R23D9_PASSIVE_MODE);
            }
            if step == R23D9_SUPPORT_CONFIRMATION_STEPS {
                assert!(!was_active);
                assert_eq!(applications, 0);
            }
            state = next;
        }
        let outcome = r23d9_handoff_outcome(&state).expect("complete handoff outcome");
        assert_eq!(outcome["handoff_after_active_step"], 29);
        assert_eq!(outcome["first_passive_step"], 30);
        assert_eq!(outcome["active_step_count"], 30);
        assert_eq!(outcome["passive_step_count"], 750);
        assert_eq!(outcome["passive_native_application_count"], 0);
        assert_eq!(outcome["irreversible_handoff_gate_passed"], true);
    }

    #[test]
    fn production_handoff_machine_preserves_deadline_negative() {
        let mut state = R23D9HandoffState::default();
        let unsupported = contacts(false);
        for _ in 0..R23D9_TERMINAL_STEPS {
            let applications = if state.active {
                R23D3_ACTUATOR_COUNT
            } else {
                0
            };
            let (next, _) = r23d9_observe_handoff(&state, &unsupported, applications)
                .expect("production deadline observation");
            state = next;
        }
        let outcome = r23d9_handoff_outcome(&state).expect("complete deadline outcome");
        assert_eq!(outcome["handoff_after_active_step"], 419);
        assert_eq!(outcome["first_passive_step"], 420);
        assert_eq!(outcome["support_confirmed"], false);
        assert_eq!(outcome["active_step_count"], 420);
        assert_eq!(outcome["passive_step_count"], 360);
        assert_eq!(outcome["irreversible_handoff_gate_passed"], false);
    }
}

const R23D10_PREREGISTRATION_RAW: &str =
    include_str!("../../../turning/r23d10_quiescent_taper_preregistration_v1.json");
const R23D10_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d10_physical_implementation_contract_v1.json";
const R23D10_CLOSURE_PATH: &str = "sdk/turning/r23d10_physical_closure_v1.json";
const R23D10_CAMPAIGN_ID: &str =
    "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT";
const R23D10_GATE_ID: &str = "QSDK-R23D10";
const R23D10_ENGINE_ID: &str = "rapier_parry";
const R23D10_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d10_engine_cell_report_v1";
const R23D10_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d10_worker_failure_v1";
const R23D10_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d10_turn_quiescent_taper_trace_row_v1";
const R23D10_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d10_trace_retention_v1";
const R23D10_TRACE_RETENTION_MARKER: &str = "QSDK_R23D10_TRACE_RETENTION ";
const R23D10_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d10_physical_freeze_v1";
const R23D10_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d10_attempt_v1";
const R23D10_STAGE_ID: &str = "three_engine_confirmation";
const R23D10_CONTROLLER_STEPS: u64 = 2_992;
const R23D10_TERMINAL_STEPS: u64 = 900;
const R23D10_TOTAL_TRACE_STEPS: u64 = R23D10_CONTROLLER_STEPS + R23D10_TERMINAL_STEPS;
const R23D10_MAXIMUM_ACTIVE_STEPS: u64 = 540;
const R23D10_MINIMUM_TAPER_STEPS: u64 = 120;
const R23D10_MINIMUM_PASSIVE_STEPS: u64 = 360;
const R23D10_SCALE_DENOMINATOR: u64 = 120;
const R23D10_ACTIVE_MODE: &str = "active_neutral_acquisition";
const R23D10_TAPER_MODE: &str = "active_quiescent_taper";
const R23D10_PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const R23D10_CONFIRMED_REASON: &str = "support_pose_quiescence_confirmed";
const R23D10_DEADLINE_REASON: &str = "deadline_forced_without_quiescence_confirmation";
const R23D10_COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
const R23D10_COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
const R23D10_TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
const R23D10_TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;

const R23D10_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D10_FREEZE";
const R23D10_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D10_ATTEMPT";
const R23D10_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D10_TOKEN";
const R23D10_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D10_STAGE";
const R23D10_CELL_ENV: &str = "SPORESPORE_QSDK_R23D10_CELL";
const R23D10_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D10_ENGINE";
const R23D10_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D10_ATTEMPT_ROOT";
const R23D10_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D10_PYTHON";
const R23D10_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D10_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D10Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

#[derive(Debug)]
struct R23D10ObservationFields {
    measured_yaw_rad: f64,
    torso_height_m: f64,
    torso_tilt_rad: f64,
    torso_ground_contact: bool,
    ordered_foot_contacts: BTreeMap<String, bool>,
}

fn r23d10_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d10_cell(stage_id: &str, arm_id: &str) -> Result<R23D10Cell, String> {
    if stage_id != R23D10_STAGE_ID {
        return Err(format!("QSDK_R23D10_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D10_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D10Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D10_ENGINE_ID}__quiescent_taper__{arm_id}"),
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d10_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(R23D10_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D10_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    let policy = &contract["terminal_policy_contract"];
    let exact = contract["schema_version"]
        == "sporespore_qsdk_r23d10_quiescent_taper_preregistration_v1"
        && contract["campaign_id"] == R23D10_CAMPAIGN_ID
        && contract["gate_id"] == R23D10_GATE_ID
        && contract["stage_zero_authority"]["physical_execution_authorized"] == false
        && policy["initial_mode"] == R23D10_ACTIVE_MODE
        && policy["quiescent_mode"] == R23D10_TAPER_MODE
        && policy["passive_mode"] == R23D10_PASSIVE_MODE
        && policy["terminal_step_count"] == R23D10_TERMINAL_STEPS
        && policy["maximum_active_step_count"] == R23D10_MAXIMUM_ACTIVE_STEPS
        && policy["minimum_quiescent_taper_step_count"] == R23D10_MINIMUM_TAPER_STEPS
        && policy["minimum_passive_step_count"] == R23D10_MINIMUM_PASSIVE_STEPS
        && policy["ordered_actuator_count"] == R23D3_ACTUATOR_COUNT
        && policy["base_velocity_limit_rad_s"] == R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S
        && policy["coarse_pose_predicate"]
            == "all_four_contacts and torso_tilt_rad <= 0.035 and maximum_absolute_joint_position_error_rad <= 0.32"
        && policy["tight_pose_predicate"]
            == "all_four_contacts and torso_tilt_rad <= 0.01 and maximum_absolute_joint_position_error_rad <= 0.2"
        && policy["taper_scale_is_applied_to_canonical_velocity_limit_before_host_mapping"] == true
        && policy["taper_resets_to_acquisition_on_coarse_pose_failure"] == true
        && policy["transition_is_applied_to_next_step"] == true
        && policy["mode_reactivation_after_passive_handoff_permitted"] == false
        && policy["all_900_terminal_steps_execute"] == true;
    if !exact {
        return Err("QSDK_R23D10_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn r23d10_failure(
    cell: &R23D10Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D10_FAILURE_SCHEMA,
        "campaign_id": R23D10_CAMPAIGN_ID,
        "gate_id": R23D10_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D10_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "claims": r23d10_claims(),
    })
}

fn r23d10_source_bindings_exact(freeze: &Value, implementation: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]
            [R23D10_ENGINE_ID]
            .as_array()
    else {
        return false;
    };
    if declared.is_empty() {
        return false;
    }
    let mut required_paths = BTreeMap::<&str, String>::new();
    for value in declared {
        let Some(path) = value.as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        if required_paths.contains_key(path) {
            return false;
        }
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        required_paths.insert(path, raw_sha256(&bytes));
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    let mut observed = BTreeMap::<&str, &str>::new();
    for entry in bindings {
        let Some(path) = entry["path"].as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        let Some(digest) = entry["raw_sha256"].as_str().filter(|digest| {
            digest.strip_prefix("sha256:").is_some_and(|hex| {
                hex.len() == 64
                    && hex
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            })
        }) else {
            return false;
        };
        if observed.insert(path, digest).is_some() {
            return false;
        }
    }
    required_paths
        .iter()
        .all(|(path, digest)| observed.get(path).is_some_and(|value| *value == digest))
}

fn r23d10_physical_authorization(
    cell: &R23D10Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D10_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D10_RAP_CLOSED".to_owned());
    }
    let implementation_path = repo_root.join(R23D10_IMPLEMENTATION_PATH);
    let freeze_path = env::var(R23D10_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D10_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D10_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D10_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !implementation_path.is_file()
        || !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D10_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let implementation_raw = fs::read(&implementation_path)
        .map_err(|_| "QSDK_R23D10_RAP_IMPLEMENTATION_UNREADABLE".to_owned())?;
    let implementation: Value = serde_json::from_slice(&implementation_raw)
        .map_err(|_| "QSDK_R23D10_RAP_IMPLEMENTATION_JSON_INVALID".to_owned())?;
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D10_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D10_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D10_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D10_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let production_root = repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D10_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D10_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D10_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D10_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let stage_cells = attempt["ordered_stage_b_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let exact = freeze["schema_version"] == R23D10_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D10_CAMPAIGN_ID
        && freeze["gate_id"] == R23D10_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"]
            == raw_sha256(R23D10_PREREGISTRATION_RAW.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d10_source_bindings_exact(&freeze, &implementation)
        && attempt["schema_version"] == R23D10_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D10_CAMPAIGN_ID
        && attempt["gate_id"] == R23D10_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["full_godot_attestation_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D10_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D10_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D10_ENGINE_ENV).unwrap_or_default() == R23D10_ENGINE_ID
        && stage_cells.iter().any(|value| value == &cell.cell_id);
    if !exact {
        return Err("QSDK_R23D10_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_qsdk_r23d10_rapier_authorization_preflight_impl(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let _contract = r23d10_contract()?;
    let cell = r23d10_cell(stage_id, arm_id)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D10_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    r23d10_physical_authorization(&cell, source_commit)?;
    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r23d10_rapier_production_authorization_preflight_v1",
        "campaign_id": R23D10_CAMPAIGN_ID,
        "gate_id": R23D10_GATE_ID,
        "engine_id": R23D10_ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "actual_production_authorization_function": "r23d10_physical_authorization",
        "authorization_passed": true,
        "returned_before_model": true,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn r23d10_mode_id(mode: crate::qsdk_r23d10_quiescent_taper::Mode) -> &'static str {
    use crate::qsdk_r23d10_quiescent_taper::Mode;
    match mode {
        Mode::Active => R23D10_ACTIVE_MODE,
        Mode::Taper => R23D10_TAPER_MODE,
        Mode::Passive => R23D10_PASSIVE_MODE,
    }
}

fn r23d10_handoff_reason(
    state: &crate::qsdk_r23d10_quiescent_taper::State,
) -> Option<&'static str> {
    if state.handoff_after_active_step.is_none() {
        None
    } else if state.confirmation_satisfied {
        Some(R23D10_CONFIRMED_REASON)
    } else {
        Some(R23D10_DEADLINE_REASON)
    }
}

fn r23d10_ordered_contacts(contacts: &BTreeMap<String, bool>) -> Result<[bool; 4], String> {
    if contacts.len() != 4 {
        return Err("QSDK_R23D10_RAP_CONTACT_SHAPE_INVALID".to_owned());
    }
    let mut ordered = [false; 4];
    for (index, limb_id) in ["front_left", "front_right", "rear_left", "rear_right"]
        .iter()
        .enumerate()
    {
        ordered[index] = *contacts
            .get(*limb_id)
            .ok_or_else(|| format!("QSDK_R23D10_RAP_CONTACT_MISSING:{limb_id}"))?;
    }
    Ok(ordered)
}

fn r23d10_observe_taper(
    state: &crate::qsdk_r23d10_quiescent_taper::State,
    contacts: &BTreeMap<String, bool>,
    torso_tilt_rad: f64,
    maximum_joint_error_rad: f64,
    native_applications: u64,
    velocity_scale_numerator: u64,
    velocity_scale_denominator: u64,
) -> Result<(crate::qsdk_r23d10_quiescent_taper::State, Value), String> {
    use crate::qsdk_r23d10_quiescent_taper::{
        Mode, Observation, coarse, observe_completed_step, tight,
    };
    let observation = Observation {
        contacts: r23d10_ordered_contacts(contacts)?,
        torso_tilt_rad,
        maximum_joint_error_rad,
    };
    let pre_mode = state.mode;
    let pre_taper_count = state.taper_step_count;
    let next = observe_completed_step(
        state.clone(),
        observation,
        usize::try_from(native_applications)
            .map_err(|_| "QSDK_R23D10_RAP_NATIVE_APPLICATION_COUNT_INVALID".to_owned())?,
        usize::try_from(velocity_scale_numerator)
            .map_err(|_| "QSDK_R23D10_RAP_TAPER_NUMERATOR_INVALID".to_owned())?,
        usize::try_from(velocity_scale_denominator)
            .map_err(|_| "QSDK_R23D10_RAP_TAPER_DENOMINATOR_INVALID".to_owned())?,
    )?;
    let transitioned = next.mode != pre_mode;
    let taper_reset = pre_mode == Mode::Taper && next.mode == Mode::Active;
    let handoff_reason = if transitioned && next.mode == Mode::Passive {
        r23d10_handoff_reason(&next)
    } else {
        None
    };
    let receipt = json!({
        "step": state.next_step,
        "mode": r23d10_mode_id(pre_mode),
        "all_four_contacts": observation.contacts.into_iter().all(|contact| contact),
        "torso_tilt_rad": observation.torso_tilt_rad,
        "maximum_absolute_joint_position_error_rad":
            observation.maximum_joint_error_rad,
        "coarse_pose_satisfied": coarse(observation),
        "tight_pose_satisfied": tight(observation),
        "pre_step_taper_count": pre_taper_count,
        "post_step_taper_count": next.taper_step_count,
        "velocity_scale_numerator": velocity_scale_numerator,
        "velocity_scale_denominator": velocity_scale_denominator,
        "native_application_count": native_applications,
        "transition_after_step": transitioned,
        "taper_reset_after_step": taper_reset,
        "next_mode": r23d10_mode_id(next.mode),
        "handoff_reason": handoff_reason,
    });
    Ok((next, receipt))
}

fn r23d10_taper_outcome(
    state: &crate::qsdk_r23d10_quiescent_taper::State,
) -> Result<Value, String> {
    let result = crate::qsdk_r23d10_quiescent_taper::outcome(state)?;
    Ok(json!({
        "next_step": state.next_step,
        "mode": r23d10_mode_id(result.mode),
        "taper_step_count": state.taper_step_count,
        "confirmation_satisfied": result.confirmation_satisfied,
        "handoff_after_active_step": result.handoff_after_active_step,
        "first_passive_step": result.first_passive_step,
        "handoff_reason": r23d10_handoff_reason(state),
        "active_step_count": result.active_step_count,
        "passive_step_count": result.passive_step_count,
        "active_native_application_count": result.active_native_application_count,
        "passive_native_application_count": result.passive_native_application_count,
        "taper_reset_count": result.taper_reset_count,
        "first_post_handoff_contact_loss_step":
            result.first_post_handoff_contact_loss_step,
        "post_handoff_contact_loss_step_count":
            result.post_handoff_contact_loss_step_count,
        "quiescent_taper_gate_passed": result.passed,
    }))
}

fn r23d10_observation_fields(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<R23D10ObservationFields, String> {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    Ok(R23D10ObservationFields {
        measured_yaw_rad: yaw_rad(robot),
        torso_height_m: torso.translation().y as f64,
        torso_tilt_rad: up.y.clamp(-1.0, 1.0).acos() as f64,
        torso_ground_contact: robot.torso_ground_contact(),
        ordered_foot_contacts: r23d8_limb_contacts(robot, compiled)?,
    })
}

fn r23d10_maximum_joint_position_error(state: &StateFrame) -> Result<f64, String> {
    if state.ordered_joint_observations.len() != R23D3_ACTUATOR_COUNT as usize {
        return Err("QSDK_R23D10_RAP_TERMINAL_OBSERVATION_COUNT".to_owned());
    }
    state
        .ordered_joint_observations
        .iter()
        .try_fold(0.0_f64, |maximum, observation| {
            observation
                .position_rad
                .filter(|position| position.is_finite())
                .map(|position| maximum.max(position.abs()))
                .ok_or_else(|| {
                    format!(
                        "QSDK_R23D10_RAP_TERMINAL_POSITION_INVALID:{}",
                        observation.joint_id
                    )
                })
        })
}

struct R23D10ScaledNeutralComposition {
    host_mapping: sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1,
    maximum_absolute_commanded_joint_velocity_rad_s: f64,
}

fn r23d10_scale_neutral_composition(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    composition: &R23D8NeutralComposition,
    numerator: u64,
    denominator: u64,
) -> Result<R23D10ScaledNeutralComposition, String> {
    if denominator != R23D10_SCALE_DENOMINATOR || numerator == 0 || numerator > denominator {
        return Err("QSDK_R23D10_RAP_TAPER_SCALE_INVALID".to_owned());
    }
    let solutions = composition.receipt["ordered_actuator_solutions"]
        .as_array()
        .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D10_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())?;
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if actuators.len() != solutions.len()
        || base_actuation.ordered_commands.len() != solutions.len()
    {
        return Err("QSDK_R23D10_RAP_TAPER_ACTUATOR_COUNT_INVALID".to_owned());
    }
    let scale = numerator as f64 / denominator as f64;
    let mut ordered_residuals = Vec::<CanonicalVelocityResidualV1>::with_capacity(solutions.len());
    let mut desired_velocities = BTreeMap::<String, f64>::new();
    for ((actuator, source_command), solution) in actuators
        .iter()
        .zip(&base_actuation.ordered_commands)
        .zip(solutions)
    {
        if solution["actuator_id"] != actuator.actuator_id
            || source_command.actuator_id != actuator.actuator_id
        {
            return Err(format!(
                "QSDK_R23D10_RAP_TAPER_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let bounded_velocity = solution["bounded_velocity_rad_s"]
            .as_f64()
            .filter(|value| {
                value.is_finite()
                    && value.abs() <= R23D8_MAXIMUM_STANCE_JOINT_SPEED_RAD_S + TOLERANCE
            })
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D10_RAP_TAPER_BOUNDED_VELOCITY_INVALID:{}",
                    actuator.actuator_id
                )
            })?;
        let desired_velocity = bounded_velocity * scale;
        let portable_source_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        ordered_residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator.actuator_id.clone(),
            canonical_velocity_delta_rad_s: desired_velocity - portable_source_velocity,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
        if desired_velocities
            .insert(actuator.actuator_id.clone(), desired_velocity)
            .is_some()
        {
            return Err("QSDK_R23D10_RAP_TAPER_ACTUATOR_DUPLICATE".to_owned());
        }
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    host_mapping
        .validate(&compiled.morphology, &canonical_actuation, &host_profile)
        .map_err(|error| format!("QSDK_R23D10_RAP_TAPER_HOST_MAPPING_INVALID:{error}"))?;
    let mut maximum_speed = 0.0_f64;
    for (canonical, host) in canonical_actuation
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
    {
        let desired = *desired_velocities
            .get(&canonical.actuator_id)
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D10_RAP_TAPER_DESIRED_VELOCITY_MISSING:{}",
                    canonical.actuator_id
                )
            })?;
        if host.actuator_id != canonical.actuator_id
            || (canonical.combined_canonical_target_velocity_rad_s - desired).abs() > TOLERANCE
            || (host.host_target_velocity_rad_s - desired).abs() > TOLERANCE
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "QSDK_R23D10_RAP_TAPER_MAPPING_VALUE_INVALID:{}",
                canonical.actuator_id
            ));
        }
        maximum_speed = maximum_speed.max(desired.abs());
    }
    Ok(R23D10ScaledNeutralComposition {
        host_mapping,
        maximum_absolute_commanded_joint_velocity_rad_s: maximum_speed,
    })
}

fn r23d10_controller_trace_row(
    cell: &R23D10Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_applications: u64,
) -> Result<Value, String> {
    let (phase_id, heading_offset) = if trace_step < TURN_START_STEP {
        ("reference_warmup", 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", cell.turn_heading_offset_rad)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", 0.0)
    } else {
        ("reference_continuation", 0.0)
    };
    let observation = r23d10_observation_fields(robot, compiled)?;
    Ok(json!({
        "schema_version": R23D10_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": trace_step,
        "desired_heading_offset_rad": heading_offset,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "actuator_command_count": R23D3_ACTUATOR_COUNT,
        "native_actuation_application_count": native_applications,
        "zero_actuation": false,
        "command_composition_mode": "balanced_wave_turning_v1",
        "taper_receipt_present": false,
        "pre_step_taper_count": Value::Null,
        "post_step_taper_count": Value::Null,
        "coarse_pose_satisfied": Value::Null,
        "tight_pose_satisfied": Value::Null,
        "velocity_scale_numerator": Value::Null,
        "velocity_scale_denominator": Value::Null,
        "transition_after_step": false,
        "taper_reset_after_step": false,
        "next_terminal_mode": Value::Null,
        "handoff_reason": Value::Null,
        "maximum_absolute_joint_position_error_rad": Value::Null,
        "maximum_absolute_commanded_joint_velocity_rad_s": Value::Null,
    }))
}

fn r23d10_terminal_trace_row(
    cell: &R23D10Cell,
    trace_step: u64,
    mode: crate::qsdk_r23d10_quiescent_taper::Mode,
    taper_receipt: &Value,
    observation: &R23D10ObservationFields,
    maximum_joint_error_rad: f64,
    maximum_commanded_speed_rad_s: Option<f64>,
) -> Result<Value, String> {
    use crate::qsdk_r23d10_quiescent_taper::Mode;
    let active = mode != Mode::Passive;
    if taper_receipt["mode"] != r23d10_mode_id(mode)
        || taper_receipt["step"] != trace_step - R23D10_CONTROLLER_STEPS
        || !maximum_joint_error_rad.is_finite()
        || maximum_joint_error_rad < 0.0
        || active != maximum_commanded_speed_rad_s.is_some()
        || maximum_commanded_speed_rad_s.is_some_and(|speed| !speed.is_finite() || speed < 0.0)
    {
        return Err("QSDK_R23D10_RAP_TERMINAL_TRACE_INPUT_INVALID".to_owned());
    }
    let (phase_id, composition_mode) = match mode {
        Mode::Active => (
            "terminal_neutral_acquisition",
            "neutral_stance_full_authority_v1",
        ),
        Mode::Taper => (
            "terminal_quiescent_taper",
            "neutral_stance_quiescent_taper_v1",
        ),
        Mode::Passive => (
            "terminal_irreversible_zero_actuation",
            "passive_zero_actuation_v1",
        ),
    };
    Ok(json!({
        "schema_version": R23D10_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": Value::Null,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "actuator_command_count": if active { R23D3_ACTUATOR_COUNT } else { 0 },
        "native_actuation_application_count":
            taper_receipt["native_application_count"].clone(),
        "zero_actuation": !active,
        "command_composition_mode": composition_mode,
        "taper_receipt_present": true,
        "pre_step_taper_count": taper_receipt["pre_step_taper_count"].clone(),
        "post_step_taper_count": taper_receipt["post_step_taper_count"].clone(),
        "coarse_pose_satisfied": taper_receipt["coarse_pose_satisfied"].clone(),
        "tight_pose_satisfied": taper_receipt["tight_pose_satisfied"].clone(),
        "velocity_scale_numerator": taper_receipt["velocity_scale_numerator"].clone(),
        "velocity_scale_denominator": taper_receipt["velocity_scale_denominator"].clone(),
        "transition_after_step": taper_receipt["transition_after_step"].clone(),
        "taper_reset_after_step": taper_receipt["taper_reset_after_step"].clone(),
        "next_terminal_mode": taper_receipt["next_mode"].clone(),
        "handoff_reason": taper_receipt["handoff_reason"].clone(),
        "maximum_absolute_joint_position_error_rad": maximum_joint_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s":
            maximum_commanded_speed_rad_s,
    }))
}

fn r23d10_retain_trace(
    cell: &R23D10Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D10_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D10_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D10_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let repo_root = r23d3_repo_root()?;
    let evaluator_path = repo_root.join("sdk/turning/r23d10_physical_evaluator.py");
    let python = env::var(R23D10_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D10_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D10_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = R23D10_TRACE_RETENTION_MARKER;
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D10_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D10_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D10_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D10_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

pub fn run_qsdk_r23d10_rapier_physical_impl(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d10_cell(stage_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D10_FAILURE_SCHEMA,
            "campaign_id": R23D10_CAMPAIGN_ID,
            "gate_id": R23D10_GATE_ID,
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": R23D10_ENGINE_ID,
            "arm_id": arm_id,
            "turn_heading_offset_rad": Value::Null,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": Value::Null,
            "claims": r23d10_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d10_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D10_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d10_contract().map_err(&before_world)?;
    let attempt_root =
        r23d10_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight =
        crate::qsdk_r23d10_quiescent_taper::run_qsdk_r23d10_rapier_preflight(stage_id, arm_id)
            .map_err(&before_world)?;
    let (compiled, controller) = compile_boundary().map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D8_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The native world-attempt counter becomes one immediately before this
    // sole fixture construction. All authorization and preflight work above is
    // zero-world and therefore cannot accidentally spend the one-shot cell.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d10_failure(
                    &cell,
                    source_commit,
                    "world_construction_failed",
                    &code,
                    1,
                    0,
                    None,
                )
            })?;
    let world_constructed =
        |code: String| r23d10_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d10_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let task_origin = robot.torso_position();
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = BalancedWaveControllerMemory::initial();
    let mut neutral_stance_activated = false;
    let mut taper_state = crate::qsdk_r23d10_quiescent_taper::State::default();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D10_TOTAL_TRACE_STEPS as usize);

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut maximum_terminal_active_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;

    for semantic_step in 0..R23D10_CONTROLLER_STEPS {
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
        let schedule = r23d3_schedule(&turning_cell, semantic_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == TURN_START_STEP {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != POLICY_ID
        {
            return Err(settled_failure(
                "QSDK_R23D10_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d10_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D10_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D10_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let observation = r23d10_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &observation.ordered_foot_contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D10_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = observation.ordered_foot_contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        trace_rows.push(
            r23d10_controller_trace_row(&cell, semantic_step, &robot, &compiled, applications)
                .map_err(&settled_failure)?,
        );
    }

    for terminal_step in 0..R23D10_TERMINAL_STEPS {
        let trace_step = R23D10_CONTROLLER_STEPS + terminal_step;
        let pre_mode = taper_state.mode;
        let (scale_numerator, scale_denominator) =
            crate::qsdk_r23d10_quiescent_taper::expected_scale(&taper_state);
        let scale_numerator = u64::try_from(scale_numerator)
            .map_err(|_| settled_failure("QSDK_R23D10_RAP_TAPER_NUMERATOR_INVALID".to_owned()))?;
        let scale_denominator = u64::try_from(scale_denominator)
            .map_err(|_| settled_failure("QSDK_R23D10_RAP_TAPER_DENOMINATOR_INVALID".to_owned()))?;
        let active = pre_mode != crate::qsdk_r23d10_quiescent_taper::Mode::Passive;
        let mut maximum_commanded_speed = None::<f64>;
        let applications;
        if active {
            let state = physical_state_frame(
                &robot,
                &compiled,
                trace_step,
                task_origin,
                reference_heading_rad,
            )
            .map_err(&settled_failure)?;
            nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
            let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
            let command =
                r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
            let output = controller.step(&memory, &state, &command);
            controller_error_count += u64::from(
                output.actuation.receipt.controller_error.is_some()
                    || !output.actuation.failure_codes.is_empty(),
            );
            active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
            validate_controller_actuation(&compiled, &output.actuation)
                .map_err(&settled_failure)?;
            let expected = independent_oracle(&state, &command, controller.profile())
                .map_err(&settled_failure)?;
            let observed = receipt_values(&output.actuation.receipt);
            let oracle_failures = predicate_failures(expected, observed);
            if output.actuation.receipt.semantic_step != trace_step
                || output.actuation.receipt.command_id != command.command_id
                || output.actuation.receipt.policy_id != POLICY_ID
                || !oracle_failures.is_empty()
            {
                return Err(settled_failure(format!(
                    "QSDK_R23D10_RAP_TERMINAL_CONTROLLER_INVALID:{}",
                    oracle_failures.join(",")
                )));
            }
            maximum_requested =
                maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
            maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
            let first_activation = !neutral_stance_activated;
            let composition = r23d8_compose_neutral_stance(
                &compiled,
                &output.actuation,
                &state,
                first_activation,
            )
            .map_err(&settled_failure)?;
            let receipt_failures = r23d8_neutral_receipt_failures(
                &composition.receipt,
                &compiled.morphology.ordered_actuator_ids,
            );
            if composition.receipt["semantic_step"] != trace_step || !receipt_failures.is_empty() {
                return Err(settled_failure(format!(
                    "QSDK_R23D10_RAP_TERMINAL_RECEIPT_INVALID:{}",
                    receipt_failures.join(",")
                )));
            }
            let solutions = composition.receipt["ordered_actuator_solutions"]
                .as_array()
                .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
                .ok_or_else(|| {
                    settled_failure("QSDK_R23D10_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())
                })?;
            let scaled = r23d10_scale_neutral_composition(
                &compiled,
                &output.actuation,
                &composition,
                scale_numerator,
                scale_denominator,
            )
            .map_err(&settled_failure)?;
            maximum_terminal_active_joint_speed = maximum_terminal_active_joint_speed
                .max(scaled.maximum_absolute_commanded_joint_velocity_rad_s);
            maximum_commanded_speed = Some(scaled.maximum_absolute_commanded_joint_velocity_rad_s);
            validated_portable_command_count += solutions.len() as u64;
            let (step_applications, impulse_violations) = robot
                .apply_bw19v_velocity_only_v4_actuation(&scaled.host_mapping)
                .map_err(&settled_failure)?;
            applications = step_applications;
            native_actuation_application_count += applications;
            portable_impulse_violation_count += impulse_violations;
            actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
            memory = output.next_memory;
            neutral_stance_activated = true;
        } else {
            robot
                .hold_velocity_only_v4_zero_and_step()
                .map_err(&settled_failure)?;
            applications = 0;
        }

        let observation = r23d10_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        let completed_state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        let maximum_joint_error =
            r23d10_maximum_joint_position_error(&completed_state).map_err(&settled_failure)?;
        let (next_taper_state, taper_receipt) = r23d10_observe_taper(
            &taper_state,
            &observation.ordered_foot_contacts,
            observation.torso_tilt_rad,
            maximum_joint_error,
            applications,
            scale_numerator,
            scale_denominator,
        )
        .map_err(&settled_failure)?;
        trace_rows.push(
            r23d10_terminal_trace_row(
                &cell,
                trace_step,
                pre_mode,
                &taper_receipt,
                &observation,
                maximum_joint_error,
                maximum_commanded_speed,
            )
            .map_err(&settled_failure)?,
        );
        taper_state = next_taper_state;
    }

    let taper_outcome = r23d10_taper_outcome(&taper_state).map_err(&settled_failure)?;
    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let task_forward = Vector::new(
        reference_heading_rad.cos() as f32,
        0.0,
        reference_heading_rad.sin() as f32,
    );
    let final_forward_displacement_m = final_delta.dot(task_forward) as f64;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D10_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d10_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D10_REPORT_SCHEMA,
        "campaign_id": R23D10_CAMPAIGN_ID,
        "gate_id": R23D10_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D10_ENGINE_ID,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D10_CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": R23D10_TERMINAL_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                taper_outcome["passive_native_application_count"].clone(),
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D10_CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": R23D10_TERMINAL_STEPS,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                taper_outcome["passive_native_application_count"].clone(),
            "confirmation_satisfied": taper_outcome["confirmation_satisfied"].clone(),
            "handoff_after_active_step": taper_outcome["handoff_after_active_step"].clone(),
            "first_passive_step": taper_outcome["first_passive_step"].clone(),
            "handoff_reason": taper_outcome["handoff_reason"].clone(),
            "active_terminal_step_count": taper_outcome["active_step_count"].clone(),
            "quiescent_taper_step_count": taper_outcome["taper_step_count"].clone(),
            "passive_terminal_step_count": taper_outcome["passive_step_count"].clone(),
            "taper_reset_count": taper_outcome["taper_reset_count"].clone(),
            "active_terminal_native_actuation_application_count":
                taper_outcome["active_native_application_count"].clone(),
            "quiescent_taper_gate_passed":
                taper_outcome["quiescent_taper_gate_passed"].clone(),
            "first_post_handoff_contact_loss_step":
                taper_outcome["first_post_handoff_contact_loss_step"].clone(),
            "post_handoff_contact_loss_step_count":
                taper_outcome["post_handoff_contact_loss_step_count"].clone(),
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "maximum_absolute_terminal_active_joint_velocity_rad_s":
                maximum_terminal_active_joint_speed,
        },
        "claims": r23d10_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d10_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D10_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

#[cfg(test)]
mod r23d10_physical_tests {
    use super::*;

    fn contacts() -> BTreeMap<String, bool> {
        BTreeMap::from([
            ("front_left".to_owned(), true),
            ("front_right".to_owned(), true),
            ("rear_left".to_owned(), true),
            ("rear_right".to_owned(), true),
        ])
    }

    #[test]
    fn production_contract_matches_frozen_taper_identity() {
        let contract = r23d10_contract().expect("R23D10 contract");
        assert_eq!(
            contract["terminal_policy_contract"]["terminal_step_count"],
            R23D10_TERMINAL_STEPS
        );
        assert_eq!(R23D10_TOTAL_TRACE_STEPS, 3_892);
        assert_eq!(R23D10_MINIMUM_TAPER_STEPS, 120);
        assert_eq!(
            R23D10_TRACE_RETENTION_MARKER,
            "QSDK_R23D10_TRACE_RETENTION "
        );
    }

    #[test]
    fn production_taper_wrapper_matches_qualified_native_scheduler() {
        let mut state = crate::qsdk_r23d10_quiescent_taper::State::default();
        let contacts = contacts();
        for terminal_step in 0..R23D10_TERMINAL_STEPS {
            let (numerator, denominator) =
                crate::qsdk_r23d10_quiescent_taper::expected_scale(&state);
            let applications = if state.mode == crate::qsdk_r23d10_quiescent_taper::Mode::Passive {
                0
            } else {
                R23D3_ACTUATOR_COUNT
            };
            let (next, receipt) = r23d10_observe_taper(
                &state,
                &contacts,
                0.005,
                0.18,
                applications,
                numerator as u64,
                denominator as u64,
            )
            .expect("valid taper step");
            assert_eq!(receipt["step"], terminal_step);
            state = next;
        }
        let outcome = r23d10_taper_outcome(&state).expect("complete taper outcome");
        assert_eq!(outcome["handoff_after_active_step"], 120);
        assert_eq!(outcome["first_passive_step"], 121);
        assert_eq!(outcome["active_step_count"], 121);
        assert_eq!(outcome["passive_step_count"], 779);
        assert_eq!(outcome["quiescent_taper_gate_passed"], true);
    }

    #[test]
    fn canonical_taper_is_applied_before_rapier_host_mapping() {
        let (compiled, controller) = compile_boundary().expect("compile boundary");
        let turning_cell =
            r23d3_cell(R23D8_STAGE_ID, "onset_600", "positive_heading").expect("cell");
        let state = synthetic_state_frame(&compiled, heading_quaternion(0.2));
        let schedule = r23d3_schedule(&turning_cell, 0, state.task_frame.reference_yaw_rad);
        let command = r23d3_motion_command(0, PhaseProgressionMode::Clocked, &schedule);
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        let composition = r23d8_compose_neutral_stance(&compiled, &output.actuation, &state, true)
            .expect("neutral composition");
        let scaled =
            r23d10_scale_neutral_composition(&compiled, &output.actuation, &composition, 60, 120)
                .expect("scaled composition");
        assert!(scaled.maximum_absolute_commanded_joint_velocity_rad_s <= 0.175 + TOLERANCE);
        for (host, solution) in scaled.host_mapping.ordered_commands.iter().zip(
            composition.receipt["ordered_actuator_solutions"]
                .as_array()
                .unwrap(),
        ) {
            let expected = solution["bounded_velocity_rad_s"].as_f64().unwrap() * 0.5;
            assert!((host.host_target_velocity_rad_s - expected).abs() <= TOLERANCE);
            assert!(host.native_target_position_rad.is_none());
        }
    }
}
