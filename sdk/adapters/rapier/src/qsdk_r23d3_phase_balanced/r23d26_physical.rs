use super::*;

use crate::bw19v_composition::{
    RapierBw19vCompositionMemory, bw19v_observation_available, compose_bw19v_step,
};
use crate::qsdk_r23d11_stability_assisted_taper::{
    Availability as R23D26Availability, CompositionMemory as R23D26CompositionMemory,
    MAXIMUM_COMBINED_VELOCITY, MAXIMUM_NEUTRAL_VELOCITY, compose_active_step,
};
use sporespore_locomotion_core::stability::StabilityInfluenceAvailability;
use sporespore_locomotion_core::{ScheduledLimbGaitStepV1, observe_stability_v2};

const R23D26_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d26_rapier_steering_cap_preregistration_v1.json");
const R23D14_TEMPORAL_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d14_tight_gated_horizon_preregistration_v1.json");
const R23D11_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d11_stability_assisted_taper_preregistration_v1.json");
const R23D26_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d26_rapier_steering_cap_implementation_v1.json";
const R23D26_CLOSURE_PATH: &str = "sdk/turning/r23d26_rapier_steering_cap_closure_v1.json";
const R23D26_CAMPAIGN_ID: &str = "QSDK-R23D26-RAPIER-STEERING-CAP-DEVELOPMENT";
const R23D26_GATE_ID: &str = "QSDK-R23D26";
const R23D26_ENGINE_ID: &str = "rapier_parry";
const R23D26_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d26_engine_cell_report_v1";
const R23D26_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d26_worker_failure_v1";
const R23D26_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d26_physical_trace_row_v1";
const R23D26_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d26_trace_retention_v1";
const R23D26_TRACE_RETENTION_MARKER: &str = "QSDK_R23D26_TRACE_RETENTION ";
const R23D26_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d26_physical_freeze_v1";
const R23D26_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d26_attempt_v1";
const R23D26_STAGE_ID: &str = "rapier_steering_cap_development";
const R23D26_CONTROLLER_STEPS: u64 = 2_992;
const R23D26_TERMINAL_STEPS: u64 = 0;
const R23D26_TOTAL_TRACE_STEPS: u64 = R23D26_CONTROLLER_STEPS + R23D26_TERMINAL_STEPS;
const R23D26_MAXIMUM_ACTIVE_STEPS: u64 = 600;
const R23D26_MINIMUM_TAPER_STEPS: u64 = 120;
const R23D26_MINIMUM_PASSIVE_STEPS: u64 = 360;
const R23D26_SCALE_DENOMINATOR: u64 = 120;
const R23D26_ACTIVE_MODE: &str = "active_neutral_acquisition";
const R23D26_TAPER_MODE: &str = "active_quiescent_taper";
const R23D26_PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const R23D26_CONFIRMED_REASON: &str = "support_pose_quiescence_confirmed";
const R23D26_DEADLINE_REASON: &str = "deadline_forced_without_quiescence_confirmation";
const R23D26_COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
const R23D26_COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
const R23D26_TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
const R23D26_TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;

const R23D26_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D26_FREEZE";
const R23D26_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D26_ATTEMPT";
const R23D26_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D26_TOKEN";
const R23D26_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D26_STAGE";
const R23D26_CELL_ENV: &str = "SPORESPORE_QSDK_R23D26_CELL";
const R23D26_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D26_ENGINE";
const R23D26_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D26_ATTEMPT_ROOT";
const R23D26_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D26_AUTHORITY_REPO_ROOT";
const R23D26_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D26_PYTHON";
const R23D26_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D26_POWERSHELL";

#[derive(Debug, Clone)]
struct R23D26Cell {
    stage_id: String,
    cell_id: String,
    candidate_id: String,
    controller_policy_id: &'static str,
    maximum_steering_fraction: f64,
    arm_id: String,
    turn_heading_offset_rad: f64,
}

#[derive(Debug)]
pub(super) struct R23D26ObservationFields {
    pub(super) measured_yaw_rad: f64,
    pub(super) torso_height_m: f64,
    pub(super) torso_tilt_rad: f64,
    pub(super) torso_ground_contact: bool,
    pub(super) ordered_foot_contacts: BTreeMap<String, bool>,
}

#[derive(Debug, Clone, Copy)]
struct R23D26ControllerTraceObservation {
    task_velocities: [f64; 3],
    maximum_joint_error_rad: f64,
}

#[derive(Debug, Clone)]
struct R23D26CommandFeedback {
    trace_step: u64,
    ordered_foot_contacts: BTreeMap<String, bool>,
    torso_tilt_rad: f64,
    maximum_joint_error_rad: f64,
}

#[derive(Debug)]
struct R23D26AuthorityReceipt {
    tilt_floor_numerator: u64,
    joint_error_floor_numerator: u64,
    pose_authority_floor_numerator: u64,
    controlling_input: Option<&'static str>,
    temporal_scale_numerator: u64,
    applied_scale_numerator: u64,
    combined_pre_taper_velocities_rad_s: Vec<Option<f64>>,
    final_canonical_velocities_rad_s: Vec<f64>,
    residual_pose_recovery_invoked: bool,
}

fn r23d26_claims() -> Value {
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

fn r23d26_cell(stage_id: &str, candidate_id: &str, arm_id: &str) -> Result<R23D26Cell, String> {
    if stage_id != R23D26_STAGE_ID {
        return Err(format!("QSDK_R23D26_RAP_STAGE_UNKNOWN:{stage_id}"));
    }
    let (controller_policy_id, maximum_steering_fraction) = match candidate_id {
        "cap_0p10" => (BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID, 0.10),
        "cap_0p20" => (BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID, 0.20),
        "cap_0p30" => (BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID, 0.30),
        _ => return Err(format!("QSDK_R23D26_RAP_CANDIDATE_UNKNOWN:{candidate_id}")),
    };
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D26_RAP_ARM_UNKNOWN:{arm_id}"))?;
    Ok(R23D26Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{R23D26_ENGINE_ID}__{candidate_id}__{arm_id}"),
        candidate_id: candidate_id.to_owned(),
        controller_policy_id,
        maximum_steering_fraction,
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
    })
}

fn r23d26_compile_boundary(
    cell: &R23D26Cell,
) -> Result<
    (
        sporespore_locomotion_core::CompiledQuadruped,
        BalancedWaveController,
    ),
    String,
> {
    let (compiled, controller) = compile_boundary_for_policy(cell.controller_policy_id)?;
    let profile = controller.profile();
    if profile.policy_id != cell.controller_policy_id
        || profile.yaw_error_stride_gain_per_rad != 1.0
        || profile.maximum_steering_fraction != Some(cell.maximum_steering_fraction)
        || profile.cross_track_frame_mode_id.as_deref()
            != Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID)
    {
        return Err("QSDK_R23D26_RAP_CONTROLLER_PROFILE_INVALID".to_owned());
    }
    Ok((compiled, controller))
}

fn r23d26_contract() -> Result<Value, String> {
    let successor: Value = serde_json::from_str(R23D26_PREREGISTRATION_RAW)
        .map_err(|error| format!("QSDK_R23D26_RAP_SUCCESSOR_CONTRACT_JSON_INVALID:{error}"))?;
    let implementation_path = r23d3_repo_root()?.join(R23D26_IMPLEMENTATION_PATH);
    let implementation: Value = serde_json::from_slice(
        &fs::read(implementation_path)
            .map_err(|error| format!("QSDK_R23D26_RAP_IMPLEMENTATION_UNREADABLE:{error}"))?,
    )
    .map_err(|error| format!("QSDK_R23D26_RAP_IMPLEMENTATION_JSON_INVALID:{error}"))?;
    let candidates = successor["candidate_family"]["ordered_candidates"]
        .as_array()
        .ok_or_else(|| "QSDK_R23D26_RAP_CANDIDATES_INVALID".to_owned())?;
    let matrix = &successor["frozen_matrix"];
    let gates = &successor["frozen_active_turn_gates"];
    let exact = successor["schema_version"]
        == "sporespore_qsdk_r23d26_rapier_steering_cap_preregistration_v1"
        && successor["campaign_id"] == R23D26_CAMPAIGN_ID
        && successor["gate_id"] == R23D26_GATE_ID
        && successor["status"] == "prospective_zero_world_only"
        && successor["study_classification"]
            == "prospective_outcome_exposed_finite_rapier_controller_development_screen"
        && successor["candidate_family"]["parent_policy_id"]
            == BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID
        && successor["candidate_family"]["only_behavioral_controller_field_changed"]
            == "maximum_steering_fraction"
        && candidates.len() == 3
        && candidates[0]["candidate_id"] == "cap_0p10"
        && candidates[0]["controller_policy_id"]
            == BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID
        && candidates[0]["maximum_steering_fraction"] == 0.10
        && candidates[1]["candidate_id"] == "cap_0p20"
        && candidates[1]["controller_policy_id"]
            == BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID
        && candidates[1]["maximum_steering_fraction"] == 0.20
        && candidates[2]["candidate_id"] == "cap_0p30"
        && candidates[2]["controller_policy_id"]
            == BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID
        && candidates[2]["maximum_steering_fraction"] == 0.30
        && successor["candidate_family"]["engine_specific_gait_logic_permitted"] == false
        && successor["candidate_family"]["candidate_or_outcome_branching_permitted"] == false
        && matrix["stage_id"] == R23D26_STAGE_ID
        && matrix["ordered_engine_ids"][0] == R23D26_ENGINE_ID
        && matrix["declared_cell_count"] == 9
        && matrix["controller_step_count"] == R23D26_CONTROLLER_STEPS
        && matrix["settlement_step_count"] == SETTLE_STEPS
        && matrix["turn_start_step"] == TURN_START_STEP
        && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && matrix["serial_execution_required"] == true
        && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
        && gates["terminal_quiescent_taper_required"] == false
        && successor["selector"]["selected_candidate_is_validation"] == false
        && successor["evidence"]["clean_pushed_source_required"] == true
        && successor["claims"]["turning_validation"] == false
        && implementation["schema_version"]
            == "sporespore_qsdk_r23d26_rapier_steering_cap_implementation_v1"
        && implementation["campaign_id"] == R23D26_CAMPAIGN_ID
        && implementation["worker"]["terminal_taper_invoked"] == false
        && implementation["evaluation"]["ordered_cell_count"] == 9;
    if !exact {
        return Err("QSDK_R23D26_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(successor)
}

fn r23d26_failure(
    cell: &R23D26Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": R23D26_FAILURE_SCHEMA,
        "campaign_id": R23D26_CAMPAIGN_ID,
        "gate_id": R23D26_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D26_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "controller_policy_id": cell.controller_policy_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "claims": r23d26_claims(),
    })
}

fn r23d26_source_bindings_exact(freeze: &Value, implementation: &Value) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    let Some(declared) =
        implementation["dependency_closure"]["required_dependency_paths_by_worker"]
            [R23D26_ENGINE_ID]
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

fn r23d26_physical_authorization(
    cell: &R23D26Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(R23D26_CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D26_RAP_CLOSED".to_owned());
    }
    let implementation_path = repo_root.join(R23D26_IMPLEMENTATION_PATH);
    let freeze_path = env::var(R23D26_FREEZE_PATH_ENV).unwrap_or_default();
    let attempt_path = env::var(R23D26_ATTEMPT_PATH_ENV).unwrap_or_default();
    let token = env::var(R23D26_TOKEN_ENV).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(R23D26_ATTEMPT_ROOT_ENV).unwrap_or_default());
    if !implementation_path.is_file()
        || !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D26_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let implementation_raw = fs::read(&implementation_path)
        .map_err(|_| "QSDK_R23D26_RAP_IMPLEMENTATION_UNREADABLE".to_owned())?;
    let implementation: Value = serde_json::from_slice(&implementation_raw)
        .map_err(|_| "QSDK_R23D26_RAP_IMPLEMENTATION_JSON_INVALID".to_owned())?;
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D26_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D26_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D26_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D26_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D26_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D26_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let production_root = authority_repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D26_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D26_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D26_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D26_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let matrix_cells = attempt["ordered_matrix_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let expected_matrix_cells = [
        "rapier_parry__cap_0p10__reference_zero",
        "rapier_parry__cap_0p10__positive_heading",
        "rapier_parry__cap_0p10__negative_heading",
        "rapier_parry__cap_0p20__reference_zero",
        "rapier_parry__cap_0p20__positive_heading",
        "rapier_parry__cap_0p20__negative_heading",
        "rapier_parry__cap_0p30__reference_zero",
        "rapier_parry__cap_0p30__positive_heading",
        "rapier_parry__cap_0p30__negative_heading",
    ];
    let matrix_cells_exact = matrix_cells.len() == expected_matrix_cells.len()
        && matrix_cells
            .iter()
            .zip(expected_matrix_cells)
            .all(|(observed, expected)| observed.as_str() == Some(expected));
    let exact = freeze["schema_version"] == R23D26_FREEZE_SCHEMA
        && freeze["campaign_id"] == R23D26_CAMPAIGN_ID
        && freeze["gate_id"] == R23D26_GATE_ID
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"]
            == raw_sha256(R23D26_PREREGISTRATION_RAW.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d26_source_bindings_exact(&freeze, &implementation)
        && attempt["schema_version"] == R23D26_ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D26_CAMPAIGN_ID
        && attempt["gate_id"] == R23D26_GATE_ID
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["matrix_authorization_immutable_before_first_world"] == true
        && matrix_cells_exact
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["campaign_attestation_adoption_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && std::path::PathBuf::from(attempt["authority_repo_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == authority_repo_root)
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(R23D26_STAGE_ENV).unwrap_or_default() == cell.stage_id
        && env::var(R23D26_CELL_ENV).unwrap_or_default() == cell.cell_id
        && env::var(R23D26_ENGINE_ENV).unwrap_or_default() == R23D26_ENGINE_ID;
    if !exact {
        return Err("QSDK_R23D26_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_qsdk_r23d26_rapier_preflight_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    let _contract = r23d26_contract()?;
    let cell = r23d26_cell(stage_id, candidate_id, arm_id)?;
    let (compiled, controller) = r23d26_compile_boundary(&cell)?;
    let compiled_repo_root = r23d3_repo_root()?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d26_rapier_physical_worker_preflight_v1",
        "campaign_id": R23D26_CAMPAIGN_ID,
        "gate_id": R23D26_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D26_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "controller_policy_id": controller.profile().policy_id,
        "yaw_error_stride_gain_per_rad": controller.profile().yaw_error_stride_gain_per_rad,
        "cross_track_frame_mode_id": controller.profile().cross_track_frame_mode_id,
        "compiled_morphology_id": compiled.morphology_id,
        "inherited_r23d11_controller_and_physics": true,
        "independent_diagnostic_availability_semantics": true,
        "inherited_r23d13_residual_pose_authority": true,
        "r23d14_tight_gated_horizon_inherited_unchanged": true,
        "inherited_r23d23_fixture_schedule_mapping_and_oracle": true,
        "terminal_taper_invoked": false,
        "nonzero_heading_aligned_receipt_regression_passed": true,
        "legacy_fixed_axis_oracle_rejected": true,
        "receipt_field_mutation_rejection_count": 5,
        "compiled_worker_repo_root_spelling": compiled_repo_root,
        "command_time_feedback_is_previous_completed_step": true,
        "physical_worker_implemented": true,
        "physical_worker_dormant_behind_supervisor_authorization": true,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_qsdk_r23d26_rapier_authorization_preflight_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let _contract = r23d26_contract()?;
    let cell = r23d26_cell(stage_id, candidate_id, arm_id)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D26_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    r23d26_physical_authorization(&cell, source_commit)?;
    Ok(json!({
        "schema_version":
            "sporespore_qsdk_r23d26_rapier_production_authorization_preflight_v1",
        "campaign_id": R23D26_CAMPAIGN_ID,
        "gate_id": R23D26_GATE_ID,
        "engine_id": R23D26_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "actual_production_authorization_function": "r23d26_physical_authorization",
        "authorization_passed": true,
        "returned_before_model": true,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn r23d26_mode_id(mode: &str) -> &str {
    mode
}

fn r23d26_handoff_reason(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
) -> Option<&'static str> {
    if state.handoff_after_active_step.is_none() {
        None
    } else if state.confirmation_satisfied {
        Some(R23D26_CONFIRMED_REASON)
    } else {
        Some(R23D26_DEADLINE_REASON)
    }
}

fn r23d26_ordered_contacts(contacts: &BTreeMap<String, bool>) -> Result<[bool; 4], String> {
    if contacts.len() != 4 {
        return Err("QSDK_R23D26_RAP_CONTACT_SHAPE_INVALID".to_owned());
    }
    let mut ordered = [false; 4];
    for (index, limb_id) in ["front_left", "front_right", "rear_left", "rear_right"]
        .iter()
        .enumerate()
    {
        ordered[index] = *contacts
            .get(*limb_id)
            .ok_or_else(|| format!("QSDK_R23D26_RAP_CONTACT_MISSING:{limb_id}"))?;
    }
    Ok(ordered)
}

fn r23d26_observe_taper(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
    contacts: &BTreeMap<String, bool>,
    torso_tilt_rad: f64,
    maximum_joint_error_rad: f64,
    native_applications: u64,
    velocity_scale_numerator: u64,
    velocity_scale_denominator: u64,
) -> Result<(crate::qsdk_r23d14_tight_gated_horizon::State, Value), String> {
    use crate::qsdk_r23d14_tight_gated_horizon::{
        production_coarse_pose_satisfied, production_observe_completed_step,
        production_tight_pose_satisfied,
    };
    let ordered_contacts = r23d26_ordered_contacts(contacts)?;
    let pre_mode = state.mode.clone();
    let pre_taper_count = state.taper_step_count;
    let (next, native_receipt) = production_observe_completed_step(
        state.clone(),
        ordered_contacts,
        torso_tilt_rad,
        maximum_joint_error_rad,
        usize::try_from(native_applications)
            .map_err(|_| "QSDK_R23D26_RAP_NATIVE_APPLICATION_COUNT_INVALID".to_owned())?,
        usize::try_from(velocity_scale_numerator)
            .map_err(|_| "QSDK_R23D26_RAP_TAPER_NUMERATOR_INVALID".to_owned())?,
        usize::try_from(velocity_scale_denominator)
            .map_err(|_| "QSDK_R23D26_RAP_TAPER_DENOMINATOR_INVALID".to_owned())?,
    )?;
    let transitioned = next.mode != pre_mode;
    let taper_reset = pre_mode == R23D26_TAPER_MODE && next.mode == R23D26_ACTIVE_MODE;
    if native_receipt.taper_reset_after_step != taper_reset {
        return Err("QSDK_R23D26_RAP_NATIVE_TAPER_RECEIPT_MISMATCH".to_owned());
    }
    let handoff_reason = if transitioned && next.mode == R23D26_PASSIVE_MODE {
        r23d26_handoff_reason(&next)
    } else {
        None
    };
    let receipt = json!({
        "step": state.next_step,
        "mode": r23d26_mode_id(&pre_mode),
        "all_four_contacts": ordered_contacts.into_iter().all(|contact| contact),
        "torso_tilt_rad": torso_tilt_rad,
        "maximum_absolute_joint_position_error_rad": maximum_joint_error_rad,
        "coarse_pose_satisfied": production_coarse_pose_satisfied(
            ordered_contacts,
            torso_tilt_rad,
            maximum_joint_error_rad,
        ),
        "tight_pose_satisfied": production_tight_pose_satisfied(
            ordered_contacts,
            torso_tilt_rad,
            maximum_joint_error_rad,
        ),
        "pre_step_taper_count": pre_taper_count,
        "post_step_taper_count": next.taper_step_count,
        "velocity_scale_numerator": velocity_scale_numerator,
        "velocity_scale_denominator": velocity_scale_denominator,
        "native_application_count": native_applications,
        "transition_after_step": transitioned,
        "taper_reset_after_step": taper_reset,
        "next_mode": r23d26_mode_id(&next.mode),
        "handoff_reason": handoff_reason,
    });
    Ok((next, receipt))
}

fn r23d26_taper_outcome(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
) -> Result<Value, String> {
    let result = crate::qsdk_r23d14_tight_gated_horizon::production_outcome(state)?;
    Ok(json!({
        "next_step": state.next_step,
        "mode": r23d26_mode_id(&result.mode),
        "taper_step_count": state.taper_step_count,
        "confirmation_satisfied": result.confirmation_satisfied,
        "handoff_after_active_step": result.handoff_after_active_step,
        "first_passive_step": result.first_passive_step,
        "handoff_reason": r23d26_handoff_reason(state),
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

pub(super) fn r23d26_observation_fields(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<R23D26ObservationFields, String> {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    Ok(R23D26ObservationFields {
        measured_yaw_rad: yaw_rad(robot),
        torso_height_m: torso.translation().y as f64,
        torso_tilt_rad: up.y.clamp(-1.0, 1.0).acos() as f64,
        torso_ground_contact: robot.torso_ground_contact(),
        ordered_foot_contacts: r23d8_limb_contacts(robot, compiled)?,
    })
}

pub(super) fn r23d26_maximum_joint_position_error(state: &StateFrame) -> Result<f64, String> {
    if state.ordered_joint_observations.len() != R23D3_ACTUATOR_COUNT as usize {
        return Err("QSDK_R23D26_RAP_TERMINAL_OBSERVATION_COUNT".to_owned());
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
                        "QSDK_R23D26_RAP_TERMINAL_POSITION_INVALID:{}",
                        observation.joint_id
                    )
                })
        })
}

struct R23D26StabilityInputs {
    raw_velocity_deltas_rad_s: Vec<Option<f64>>,
    availability: R23D26Availability,
    availability_name: &'static str,
    support_margin_m: Option<f64>,
}

struct R23D26StabilityAssistedComposition {
    host_mapping: sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1,
    applied_stability_velocity_deltas_rad_s: Vec<f64>,
    maximum_absolute_commanded_joint_velocity_rad_s: f64,
    authority_receipt: R23D26AuthorityReceipt,
}

fn r23d26_channel_floor(value: f64, tight: f64, coarse: f64) -> u64 {
    let normalized = ((value - tight) / (coarse - tight)).clamp(0.0, 1.0);
    (R23D26_SCALE_DENOMINATOR as f64 * normalized - 1.0e-12).ceil() as u64
}

fn r23d26_pose_authority_floor(
    feedback: &R23D26CommandFeedback,
) -> Result<(u64, u64, u64, &'static str), String> {
    if feedback.ordered_foot_contacts.len() != 4
        || !feedback.torso_tilt_rad.is_finite()
        || feedback.torso_tilt_rad < 0.0
        || !feedback.maximum_joint_error_rad.is_finite()
        || feedback.maximum_joint_error_rad < 0.0
    {
        return Err("QSDK_R23D26_RAP_POSE_FEEDBACK_INVALID".to_owned());
    }
    if !feedback.ordered_foot_contacts.values().all(|value| *value) {
        return Ok((
            0,
            0,
            R23D26_SCALE_DENOMINATOR,
            "incomplete_support_full_authority",
        ));
    }
    let tilt = r23d26_channel_floor(
        feedback.torso_tilt_rad,
        R23D26_TIGHT_MAXIMUM_TILT_RAD,
        R23D26_COARSE_MAXIMUM_TILT_RAD,
    );
    let joint = r23d26_channel_floor(
        feedback.maximum_joint_error_rad,
        R23D26_TIGHT_MAXIMUM_JOINT_ERROR_RAD,
        R23D26_COARSE_MAXIMUM_JOINT_ERROR_RAD,
    );
    let floor = 1_u64.max(tilt).max(joint);
    let controlling = if tilt > joint {
        "torso_tilt"
    } else if joint > tilt {
        "maximum_joint_position_error"
    } else if floor == 1 {
        "tight_pose_minimum"
    } else {
        "equal_pose_channels"
    };
    Ok((tilt, joint, floor, controlling))
}

fn r23d26_passive_authority_receipt(temporal_scale_numerator: u64) -> R23D26AuthorityReceipt {
    R23D26AuthorityReceipt {
        tilt_floor_numerator: 0,
        joint_error_floor_numerator: 0,
        pose_authority_floor_numerator: 0,
        controlling_input: None,
        temporal_scale_numerator,
        applied_scale_numerator: 0,
        combined_pre_taper_velocities_rad_s: vec![None; R23D3_ACTUATOR_COUNT as usize],
        final_canonical_velocities_rad_s: vec![0.0; R23D3_ACTUATOR_COUNT as usize],
        residual_pose_recovery_invoked: false,
    }
}

fn r23d26_ordered_limb_steps(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    memory: &BalancedWaveControllerMemory,
) -> Result<Vec<ScheduledLimbGaitStepV1>, String> {
    compiled
        .morphology
        .ordered_limb_ids
        .iter()
        .map(|limb_id| {
            memory
                .ordered_limb_memory
                .iter()
                .find(|limb| limb.limb_id == *limb_id)
                .map(|limb| ScheduledLimbGaitStepV1 {
                    limb_id: limb.limb_id.clone(),
                    gait_step: limb.gait_step,
                })
                .ok_or_else(|| format!("QSDK_R23D26_RAP_LIMB_MEMORY_MISSING:{limb_id}"))
        })
        .collect()
}

fn r23d26_availability(
    value: StabilityInfluenceAvailability,
) -> (R23D26Availability, &'static str) {
    match value {
        StabilityInfluenceAvailability::Available => (R23D26Availability::Available, "available"),
        StabilityInfluenceAvailability::ObservationUnavailable => (
            R23D26Availability::ObservationUnavailable,
            "observation_unavailable",
        ),
        StabilityInfluenceAvailability::UpstreamInfeasible => (
            R23D26Availability::PlanningInfeasible,
            "planning_infeasible",
        ),
    }
}

fn r23d26_support_margin(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    stability_state: &sporespore_locomotion_core::StabilityStateV2,
) -> Result<Option<f64>, String> {
    if !bw19v_observation_available(stability_state) {
        return Ok(None);
    }
    let observation = observe_stability_v2(&compiled.morphology, stability_state)
        .map_err(|error| format!("QSDK_R23D26_RAP_SUPPORT_OBSERVATION_INVALID:{error}"))?;
    let margin = observation.minimum_dynamic_support_margin_m;
    if !margin.is_finite() {
        return Err("QSDK_R23D26_RAP_SUPPORT_MARGIN_NONFINITE".to_owned());
    }
    Ok(Some(margin))
}

fn r23d26_stability_inputs(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    memory: &BalancedWaveControllerMemory,
    semantic_step: u64,
) -> Result<R23D26StabilityInputs, String> {
    let stability_state = robot.bw19v_stability_state(compiled, semantic_step)?;
    let support_margin_m = r23d26_support_margin(compiled, &stability_state)?;
    let kinematics = robot.bw19v_endpoint_kinematics(compiled, &stability_state)?;
    let limb_steps = r23d26_ordered_limb_steps(compiled, memory)?;
    let mut scratch_memory = RapierBw19vCompositionMemory::default();
    let receipt = compose_bw19v_step(
        compiled,
        base_actuation,
        stability_state,
        kinematics,
        limb_steps,
        &mut scratch_memory,
    )?;
    let (availability, availability_name) =
        r23d26_availability(receipt.scheduled_load_transfer.planning_availability);
    let raw_velocity_deltas_rad_s = receipt
        .ordered_commands
        .iter()
        .map(|command| command.raw_canonical_velocity_delta_rad_s)
        .collect::<Vec<_>>();
    let available = availability == R23D26Availability::Available;
    if raw_velocity_deltas_rad_s.len() != R23D3_ACTUATOR_COUNT as usize
        || (available
            && raw_velocity_deltas_rad_s
                .iter()
                .any(|value| value.is_none_or(|number| !number.is_finite())))
        || (!available && raw_velocity_deltas_rad_s.iter().any(Option::is_some))
    {
        return Err("QSDK_R23D26_RAP_STABILITY_INPUTS_INVALID".to_owned());
    }
    Ok(R23D26StabilityInputs {
        raw_velocity_deltas_rad_s,
        availability,
        availability_name,
        support_margin_m,
    })
}

pub(super) fn r23d26_task_velocities(state: &StateFrame) -> Result<[f64; 3], String> {
    let dot = |vector: Vec3, axis: Vec3| vector.x * axis.x + vector.y * axis.y + vector.z * axis.z;
    let values = [
        dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.forward_axis_world_unit,
        ),
        dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.lateral_axis_world_unit,
        ),
        dot(
            state.base_twist_world.angular_velocity_rad_s,
            state.task_frame.up_axis_world_unit,
        ),
    ];
    if values.iter().any(|value| !value.is_finite()) {
        return Err("QSDK_R23D26_RAP_TASK_VELOCITY_NONFINITE".to_owned());
    }
    Ok(values)
}

#[allow(clippy::too_many_arguments)]
fn r23d26_compose_stability_assisted_taper(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    composition: &R23D8NeutralComposition,
    stability_inputs: &R23D26StabilityInputs,
    numerator: u64,
    denominator: u64,
    command_feedback: &R23D26CommandFeedback,
    semantic_step: u64,
    memory: &R23D26CompositionMemory,
) -> Result<(R23D26CompositionMemory, R23D26StabilityAssistedComposition), String> {
    if denominator != R23D26_SCALE_DENOMINATOR || numerator == 0 || numerator > denominator {
        return Err("QSDK_R23D26_RAP_TAPER_SCALE_INVALID".to_owned());
    }
    let solutions = composition.receipt["ordered_actuator_solutions"]
        .as_array()
        .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D26_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())?;
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if actuators.len() != solutions.len()
        || base_actuation.ordered_commands.len() != solutions.len()
    {
        return Err("QSDK_R23D26_RAP_TAPER_ACTUATOR_COUNT_INVALID".to_owned());
    }
    let actuator_ids = actuators
        .iter()
        .map(|actuator| actuator.actuator_id.clone())
        .collect::<Vec<_>>();
    let mut neutral_velocities = Vec::<f64>::with_capacity(solutions.len());
    for (actuator, solution) in actuators.iter().zip(solutions) {
        if solution["actuator_id"] != actuator.actuator_id {
            return Err(format!(
                "QSDK_R23D26_RAP_TAPER_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let bounded_velocity = solution["bounded_velocity_rad_s"]
            .as_f64()
            .filter(|value| value.is_finite() && value.abs() <= MAXIMUM_NEUTRAL_VELOCITY)
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D26_RAP_TAPER_BOUNDED_VELOCITY_INVALID:{}",
                    actuator.actuator_id
                )
            })?;
        neutral_velocities.push(bounded_velocity);
    }
    let semantic_step_usize = usize::try_from(semantic_step)
        .map_err(|_| "QSDK_R23D26_RAP_COMPOSITION_STEP_INVALID".to_owned())?;
    let (next_memory, rows) = compose_active_step(
        semantic_step_usize,
        &actuator_ids,
        &neutral_velocities,
        &stability_inputs.raw_velocity_deltas_rad_s,
        stability_inputs.availability,
        R23D26_SCALE_DENOMINATOR as usize,
        R23D26_SCALE_DENOMINATOR as usize,
        memory,
    )?;
    if rows.len() != actuators.len() {
        return Err("QSDK_R23D26_RAP_COMPOSITION_ROW_COUNT_INVALID".to_owned());
    }
    let mut ordered_residuals = Vec::<CanonicalVelocityResidualV1>::with_capacity(solutions.len());
    let mut desired_velocities = BTreeMap::<String, f64>::new();
    let mut applied_stability_velocity_deltas_rad_s = Vec::with_capacity(rows.len());
    let (tilt_floor, joint_floor, pose_floor, controlling_input) =
        r23d26_pose_authority_floor(command_feedback)?;
    let applied_numerator = numerator.max(pose_floor);
    let applied_scale = applied_numerator as f64 / R23D26_SCALE_DENOMINATOR as f64;
    let mut combined_pre_taper_velocities_rad_s = Vec::with_capacity(rows.len());
    let mut final_canonical_velocities_rad_s = Vec::with_capacity(rows.len());
    for ((actuator, source_command), row) in actuators
        .iter()
        .zip(&base_actuation.ordered_commands)
        .zip(&rows)
    {
        if source_command.actuator_id != actuator.actuator_id
            || row.combined_pre_taper.abs() > MAXIMUM_COMBINED_VELOCITY + TOLERANCE
            || row.fallback_zeroed
                != (stability_inputs.availability != R23D26Availability::Available)
        {
            return Err(format!(
                "QSDK_R23D26_RAP_TAPER_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let desired_velocity = row.combined_pre_taper * applied_scale;
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
            return Err("QSDK_R23D26_RAP_TAPER_ACTUATOR_DUPLICATE".to_owned());
        }
        applied_stability_velocity_deltas_rad_s.push(row.applied_stability_delta);
        combined_pre_taper_velocities_rad_s.push(Some(row.combined_pre_taper));
        final_canonical_velocities_rad_s.push(desired_velocity);
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    host_mapping
        .validate(&compiled.morphology, &canonical_actuation, &host_profile)
        .map_err(|error| format!("QSDK_R23D26_RAP_TAPER_HOST_MAPPING_INVALID:{error}"))?;
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
                    "QSDK_R23D26_RAP_TAPER_DESIRED_VELOCITY_MISSING:{}",
                    canonical.actuator_id
                )
            })?;
        if host.actuator_id != canonical.actuator_id
            || (canonical.combined_canonical_target_velocity_rad_s - desired).abs() > TOLERANCE
            || (host.host_target_velocity_rad_s - desired).abs() > TOLERANCE
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "QSDK_R23D26_RAP_TAPER_MAPPING_VALUE_INVALID:{}",
                canonical.actuator_id
            ));
        }
        maximum_speed = maximum_speed.max(desired.abs());
    }
    Ok((
        next_memory,
        R23D26StabilityAssistedComposition {
            host_mapping,
            applied_stability_velocity_deltas_rad_s,
            maximum_absolute_commanded_joint_velocity_rad_s: maximum_speed,
            authority_receipt: R23D26AuthorityReceipt {
                tilt_floor_numerator: tilt_floor,
                joint_error_floor_numerator: joint_floor,
                pose_authority_floor_numerator: pose_floor,
                controlling_input: Some(controlling_input),
                temporal_scale_numerator: numerator,
                applied_scale_numerator: applied_numerator,
                combined_pre_taper_velocities_rad_s,
                final_canonical_velocities_rad_s,
                residual_pose_recovery_invoked: true,
            },
        },
    ))
}

#[allow(clippy::too_many_arguments)]
fn r23d26_controller_trace_row(
    cell: &R23D26Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_applications: u64,
    stability_inputs: &R23D26StabilityInputs,
    requested_steering_fraction: f64,
    held_steering_fraction: f64,
    steering_saturated: bool,
    trace_observation: R23D26ControllerTraceObservation,
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
    let observation = r23d26_observation_fields(robot, compiled)?;
    let applied_stability_deltas = vec![0.0_f64; R23D3_ACTUATOR_COUNT as usize];
    let diagnostic = crate::qsdk_r23d12_measurement_semantics::validate_physical_diagnostics(
        true,
        Some(stability_inputs.availability_name),
        stability_inputs.support_margin_m,
        &applied_stability_deltas,
    )
    .map_err(|error| format!("QSDK_R23D26_RAP_DIAGNOSTIC_SEMANTICS_INVALID:{error}"))?;
    Ok(json!({
        "schema_version": R23D26_TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": trace_step,
        "desired_heading_offset_rad": heading_offset,
        "requested_steering_fraction": requested_steering_fraction,
        "held_steering_fraction": held_steering_fraction,
        "steering_saturated": steering_saturated,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "base_linear_velocity_task_forward_m_s": trace_observation.task_velocities[0],
        "base_linear_velocity_task_lateral_m_s": trace_observation.task_velocities[1],
        "base_angular_velocity_task_yaw_rad_s": trace_observation.task_velocities[2],
        "minimum_dynamic_support_margin_m":
            diagnostic["minimum_dynamic_support_margin_m"].clone(),
        "minimum_dynamic_support_margin_availability":
            diagnostic["minimum_dynamic_support_margin_availability"].clone(),
        "stability_planning_availability":
            diagnostic["stability_planning_availability"].clone(),
        "ordered_applied_stability_velocity_deltas_rad_s":
            diagnostic["ordered_applied_stability_velocity_deltas_rad_s"].clone(),
        "actuator_command_count": R23D3_ACTUATOR_COUNT,
        "native_actuation_application_count": native_applications,
        "zero_actuation": false,
        "command_composition_mode": "balanced_wave_turning_v1",
        "taper_receipt_present": false,
        "pre_step_taper_count": Value::Null,
        "post_step_taper_count": Value::Null,
        "coarse_pose_satisfied": Value::Null,
        "tight_pose_satisfied": Value::Null,
        "command_time_feedback_trace_step": Value::Null,
        "command_time_ordered_foot_contacts": Value::Null,
        "command_time_torso_tilt_rad": Value::Null,
        "command_time_maximum_absolute_joint_position_error_rad": Value::Null,
        "temporal_scale_numerator": Value::Null,
        "temporal_scale_denominator": Value::Null,
        "tilt_floor_numerator": Value::Null,
        "joint_error_floor_numerator": Value::Null,
        "pose_authority_floor_numerator": Value::Null,
        "pose_authority_controlling_input": Value::Null,
        "applied_scale_numerator": Value::Null,
        "applied_scale_denominator": Value::Null,
        "ordered_combined_pre_taper_velocities_rad_s": Value::Null,
        "ordered_final_canonical_velocities_rad_s": Value::Null,
        "residual_pose_recovery_invoked": Value::Null,
        "authority_floor_never_reduces_temporal_authority": Value::Null,
        "complete_combined_velocity_scaled_once_before_host_mapping": Value::Null,
        "passive_mode_exact_zero_actuation": Value::Null,
        "transition_after_step": false,
        "taper_reset_after_step": false,
        "next_terminal_mode": Value::Null,
        "handoff_reason": Value::Null,
        "maximum_absolute_joint_position_error_rad":
            trace_observation.maximum_joint_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s": Value::Null,
    }))
}

#[allow(clippy::too_many_arguments)]
fn r23d26_terminal_trace_row(
    cell: &R23D26Cell,
    trace_step: u64,
    mode: &str,
    taper_receipt: &Value,
    command_feedback: &R23D26CommandFeedback,
    authority_receipt: &R23D26AuthorityReceipt,
    observation: &R23D26ObservationFields,
    maximum_joint_error_rad: f64,
    maximum_commanded_speed_rad_s: Option<f64>,
    task_velocities: [f64; 3],
    support_margin_m: Option<f64>,
    planning_availability: Option<&str>,
    applied_stability_deltas_rad_s: &[f64],
) -> Result<Value, String> {
    let active = mode != R23D26_PASSIVE_MODE;
    if taper_receipt["mode"] != r23d26_mode_id(mode)
        || taper_receipt["step"] != trace_step - R23D26_CONTROLLER_STEPS
        || !maximum_joint_error_rad.is_finite()
        || maximum_joint_error_rad < 0.0
        || active != maximum_commanded_speed_rad_s.is_some()
        || maximum_commanded_speed_rad_s.is_some_and(|speed| !speed.is_finite() || speed < 0.0)
        || applied_stability_deltas_rad_s.len() != R23D3_ACTUATOR_COUNT as usize
        || applied_stability_deltas_rad_s
            .iter()
            .any(|value| !value.is_finite())
        || (!active
            && (planning_availability.is_some()
                || applied_stability_deltas_rad_s
                    .iter()
                    .any(|value| *value != 0.0)))
    {
        return Err("QSDK_R23D26_RAP_TERMINAL_TRACE_INPUT_INVALID".to_owned());
    }
    let diagnostic = crate::qsdk_r23d12_measurement_semantics::validate_physical_diagnostics(
        active,
        planning_availability,
        support_margin_m,
        applied_stability_deltas_rad_s,
    )
    .map_err(|error| format!("QSDK_R23D26_RAP_DIAGNOSTIC_SEMANTICS_INVALID:{error}"))?;
    let (phase_id, composition_mode) = match mode {
        R23D26_ACTIVE_MODE => (
            "terminal_neutral_acquisition",
            "residual_pose_authority_neutral_full_authority_v1",
        ),
        R23D26_TAPER_MODE => (
            "terminal_quiescent_taper",
            "residual_pose_authority_neutral_quiescent_taper_v1",
        ),
        R23D26_PASSIVE_MODE => (
            "terminal_irreversible_zero_actuation",
            "passive_zero_actuation_v1",
        ),
        _ => return Err("QSDK_R23D26_RAP_TERMINAL_MODE_INVALID".to_owned()),
    };
    Ok(json!({
        "schema_version": R23D26_TRACE_ROW_SCHEMA,
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
        "base_linear_velocity_task_forward_m_s": task_velocities[0],
        "base_linear_velocity_task_lateral_m_s": task_velocities[1],
        "base_angular_velocity_task_yaw_rad_s": task_velocities[2],
        "minimum_dynamic_support_margin_m":
            diagnostic["minimum_dynamic_support_margin_m"].clone(),
        "minimum_dynamic_support_margin_availability":
            diagnostic["minimum_dynamic_support_margin_availability"].clone(),
        "stability_planning_availability":
            diagnostic["stability_planning_availability"].clone(),
        "ordered_applied_stability_velocity_deltas_rad_s":
            diagnostic["ordered_applied_stability_velocity_deltas_rad_s"].clone(),
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
        "command_time_feedback_trace_step": command_feedback.trace_step,
        "command_time_ordered_foot_contacts": command_feedback.ordered_foot_contacts,
        "command_time_torso_tilt_rad": command_feedback.torso_tilt_rad,
        "command_time_maximum_absolute_joint_position_error_rad":
            command_feedback.maximum_joint_error_rad,
        "temporal_scale_numerator": taper_receipt["velocity_scale_numerator"].clone(),
        "temporal_scale_denominator": taper_receipt["velocity_scale_denominator"].clone(),
        "tilt_floor_numerator": authority_receipt.tilt_floor_numerator,
        "joint_error_floor_numerator": authority_receipt.joint_error_floor_numerator,
        "pose_authority_floor_numerator": authority_receipt.pose_authority_floor_numerator,
        "pose_authority_controlling_input": authority_receipt.controlling_input,
        "applied_scale_numerator": authority_receipt.applied_scale_numerator,
        "applied_scale_denominator": R23D26_SCALE_DENOMINATOR,
        "ordered_combined_pre_taper_velocities_rad_s":
            authority_receipt.combined_pre_taper_velocities_rad_s,
        "ordered_final_canonical_velocities_rad_s":
            authority_receipt.final_canonical_velocities_rad_s,
        "residual_pose_recovery_invoked": authority_receipt.residual_pose_recovery_invoked,
        "authority_floor_never_reduces_temporal_authority":
            authority_receipt.applied_scale_numerator
                >= authority_receipt.temporal_scale_numerator,
        "complete_combined_velocity_scaled_once_before_host_mapping": true,
        "passive_mode_exact_zero_actuation": !active,
        "transition_after_step": taper_receipt["transition_after_step"].clone(),
        "taper_reset_after_step": taper_receipt["taper_reset_after_step"].clone(),
        "next_terminal_mode": taper_receipt["next_mode"].clone(),
        "handoff_reason": taper_receipt["handoff_reason"].clone(),
        "maximum_absolute_joint_position_error_rad": maximum_joint_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s":
            maximum_commanded_speed_rad_s,
    }))
}

fn r23d26_retain_trace(
    cell: &R23D26Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D26_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D26_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D26_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D26_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D26_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let evaluator_path = source_root.join("sdk/turning/r23d26_rapier_steering_cap_evaluator.py");
    let python = env::var(R23D26_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D26_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--source-root")
        .arg(&source_root)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D26_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = R23D26_TRACE_RETENTION_MARKER;
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D26_RAP_TRACE_RETENTION_FAILED:{}:{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D26_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D26_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D26_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

#[allow(clippy::reversed_empty_ranges)]
pub fn run_qsdk_r23d26_rapier_physical_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d26_cell(stage_id, candidate_id, arm_id).map_err(|code| {
        json!({
            "schema_version": R23D26_FAILURE_SCHEMA,
            "campaign_id": R23D26_CAMPAIGN_ID,
            "gate_id": R23D26_GATE_ID,
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": R23D26_ENGINE_ID,
            "candidate_id": candidate_id,
            "arm_id": arm_id,
            "turn_heading_offset_rad": Value::Null,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": Value::Null,
            "claims": r23d26_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d26_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D26_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let _contract = r23d26_contract().map_err(&before_world)?;
    let attempt_root =
        r23d26_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let (_, _, development) = parse_contracts().map_err(&before_world)?;
    let perturbation = initial_perturbation(&development).map_err(&before_world)?;
    let _preflight =
        crate::qsdk_r23d23_composition_recovery::run_qsdk_r23d23_rapier_inherited_composition_preflight(
            crate::qsdk_r23d23_composition_recovery::R23D23_STAGE_ID,
            arm_id,
        )
        .map_err(&before_world)?;
    let (compiled, controller) = r23d26_compile_boundary(&cell).map_err(&before_world)?;
    let turning_cell = r23d3_cell(R23D8_STAGE_ID, "onset_600", arm_id).map_err(&before_world)?;

    // The native world-attempt counter becomes one immediately before this
    // sole fixture construction. All authorization and preflight work above is
    // zero-world and therefore cannot accidentally spend the one-shot cell.
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
            .map_err(|code| {
                r23d26_failure(
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
        |code: String| r23d26_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d26_failure(
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
    let mut stability_composition_memory = R23D26CompositionMemory::default();
    let mut taper_state = crate::qsdk_r23d14_tight_gated_horizon::State::default();
    let mut trace_rows = Vec::<Value>::with_capacity(R23D26_TOTAL_TRACE_STEPS as usize);
    let mut command_feedback = None::<R23D26CommandFeedback>;

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
    let mut steering_saturation_step_count = 0_u64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;

    for semantic_step in 0..R23D26_CONTROLLER_STEPS {
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
            || output.actuation.receipt.policy_id != cell.controller_policy_id
        {
            return Err(settled_failure(
                "QSDK_R23D26_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d26_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D26_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let stability_inputs =
            r23d26_stability_inputs(&robot, &compiled, &output.actuation, &memory, semantic_step)
                .map_err(&settled_failure)?;
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &zero_residuals(&compiled))
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D26_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        if output.actuation.receipt.requested_steering_fraction.abs()
            > cell.maximum_steering_fraction + TOLERANCE
            || output.actuation.receipt.held_steering_fraction.abs()
                > cell.maximum_steering_fraction + TOLERANCE
        {
            return Err(settled_failure(
                "QSDK_R23D26_RAP_STEERING_CAP_VIOLATION".to_owned(),
            ));
        }
        steering_saturation_step_count += u64::from(output.actuation.receipt.steering_saturated);
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot
            .apply_bw19v_velocity_only_v4_actuation(&mapping)
            .map_err(&settled_failure)?;
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let observation = r23d26_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        let feedback_contacts = observation.ordered_foot_contacts.clone();
        let feedback_tilt_rad = observation.torso_tilt_rad;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &observation.ordered_foot_contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D26_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = observation.ordered_foot_contacts;
        if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        let completed_state = physical_state_frame(
            &robot,
            &compiled,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        let task_velocities = r23d26_task_velocities(&completed_state).map_err(&settled_failure)?;
        let maximum_joint_error =
            r23d26_maximum_joint_position_error(&completed_state).map_err(&settled_failure)?;
        trace_rows.push(
            r23d26_controller_trace_row(
                &cell,
                semantic_step,
                &robot,
                &compiled,
                applications,
                &stability_inputs,
                output.actuation.receipt.requested_steering_fraction,
                output.actuation.receipt.held_steering_fraction,
                output.actuation.receipt.steering_saturated,
                R23D26ControllerTraceObservation {
                    task_velocities,
                    maximum_joint_error_rad: maximum_joint_error,
                },
            )
            .map_err(&settled_failure)?,
        );
        command_feedback = Some(R23D26CommandFeedback {
            trace_step: semantic_step,
            ordered_foot_contacts: feedback_contacts,
            torso_tilt_rad: feedback_tilt_rad,
            maximum_joint_error_rad: maximum_joint_error,
        });
    }

    for terminal_step in 0..R23D26_TERMINAL_STEPS {
        let trace_step = R23D26_CONTROLLER_STEPS + terminal_step;
        let pre_mode = taper_state.mode.clone();
        let (scale_numerator, scale_denominator) =
            crate::qsdk_r23d14_tight_gated_horizon::production_expected_scale(&taper_state)
                .map_err(|error| settled_failure(error.to_owned()))?;
        let scale_numerator = u64::try_from(scale_numerator)
            .map_err(|_| settled_failure("QSDK_R23D26_RAP_TAPER_NUMERATOR_INVALID".to_owned()))?;
        let scale_denominator = u64::try_from(scale_denominator)
            .map_err(|_| settled_failure("QSDK_R23D26_RAP_TAPER_DENOMINATOR_INVALID".to_owned()))?;
        let active = pre_mode != R23D26_PASSIVE_MODE;
        let mut maximum_commanded_speed = None::<f64>;
        let mut planning_availability = None::<&str>;
        let mut support_margin_m = None::<f64>;
        let mut applied_stability_deltas_rad_s = vec![0.0_f64; R23D3_ACTUATOR_COUNT as usize];
        let command_feedback_for_step = command_feedback
            .as_ref()
            .filter(|feedback| feedback.trace_step + 1 == trace_step)
            .ok_or_else(|| {
                settled_failure("QSDK_R23D26_RAP_COMMAND_TIME_FEEDBACK_INVALID".to_owned())
            })?;
        let authority_receipt;
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
                || output.actuation.receipt.policy_id != cell.controller_policy_id
                || !oracle_failures.is_empty()
            {
                return Err(settled_failure(format!(
                    "QSDK_R23D26_RAP_TERMINAL_CONTROLLER_INVALID:{}",
                    oracle_failures.join(",")
                )));
            }
            maximum_requested =
                maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
            maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
            let stability_inputs =
                r23d26_stability_inputs(&robot, &compiled, &output.actuation, &memory, trace_step)
                    .map_err(&settled_failure)?;
            planning_availability = Some(stability_inputs.availability_name);
            support_margin_m = stability_inputs.support_margin_m;
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
                    "QSDK_R23D26_RAP_TERMINAL_RECEIPT_INVALID:{}",
                    receipt_failures.join(",")
                )));
            }
            let solutions = composition.receipt["ordered_actuator_solutions"]
                .as_array()
                .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
                .ok_or_else(|| {
                    settled_failure("QSDK_R23D26_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())
                })?;
            let (next_composition_memory, scaled) = r23d26_compose_stability_assisted_taper(
                &compiled,
                &output.actuation,
                &composition,
                &stability_inputs,
                scale_numerator,
                scale_denominator,
                command_feedback_for_step,
                trace_step,
                &stability_composition_memory,
            )
            .map_err(&settled_failure)?;
            stability_composition_memory = next_composition_memory;
            authority_receipt = scaled.authority_receipt;
            applied_stability_deltas_rad_s = scaled.applied_stability_velocity_deltas_rad_s.clone();
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
            authority_receipt = r23d26_passive_authority_receipt(scale_numerator);
        }

        let observation = r23d26_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
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
        let task_velocities = r23d26_task_velocities(&completed_state).map_err(&settled_failure)?;
        if !active {
            let passive_stability_state = robot
                .bw19v_stability_state(&compiled, trace_step)
                .map_err(&settled_failure)?;
            support_margin_m = r23d26_support_margin(&compiled, &passive_stability_state)
                .map_err(&settled_failure)?;
        }
        let maximum_joint_error =
            r23d26_maximum_joint_position_error(&completed_state).map_err(&settled_failure)?;
        let (next_taper_state, taper_receipt) = r23d26_observe_taper(
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
            r23d26_terminal_trace_row(
                &cell,
                trace_step,
                &pre_mode,
                &taper_receipt,
                command_feedback_for_step,
                &authority_receipt,
                &observation,
                maximum_joint_error,
                maximum_commanded_speed,
                task_velocities,
                support_margin_m,
                planning_availability,
                &applied_stability_deltas_rad_s,
            )
            .map_err(&settled_failure)?,
        );
        command_feedback = Some(R23D26CommandFeedback {
            trace_step,
            ordered_foot_contacts: observation.ordered_foot_contacts.clone(),
            torso_tilt_rad: observation.torso_tilt_rad,
            maximum_joint_error_rad: maximum_joint_error,
        });
        taper_state = next_taper_state;
    }

    let taper_outcome = json!({
        "confirmation_satisfied": false,
        "handoff_after_active_step": Value::Null,
        "first_passive_step": Value::Null,
        "handoff_reason": Value::Null,
        "active_step_count": 0,
        "taper_step_count": 0,
        "passive_step_count": 0,
        "taper_reset_count": 0,
        "active_native_application_count": 0,
        "passive_native_application_count": 0,
        "quiescent_taper_gate_passed": false,
        "first_post_handoff_contact_loss_step": Value::Null,
        "post_handoff_contact_loss_step_count": 0,
    });
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
        .ok_or_else(|| settled_failure("QSDK_R23D26_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention =
        r23d26_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?;
    let report = json!({
        "schema_version": R23D26_REPORT_SCHEMA,
        "campaign_id": R23D26_CAMPAIGN_ID,
        "gate_id": R23D26_GATE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D26_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "controller_policy_id": cell.controller_policy_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": R23D26_CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": R23D26_TERMINAL_STEPS,
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
            "steering_saturation_step_count": steering_saturation_step_count,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": R23D26_CONTROLLER_STEPS,
            "terminal_quiescent_taper_step_count": R23D26_TERMINAL_STEPS,
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
        "claims": r23d26_claims(),
    });
    serde_json::to_vec(&report).map_err(|error| {
        r23d26_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D26_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

#[cfg(any())]
mod legacy_cloned_tests {
    use super::*;
    use crate::qsdk_r23d11_stability_assisted_taper::MAXIMUM_STABILITY_SLEW;

    #[test]
    fn physical_worker_preflight_is_dormant_and_inherits_r23d11_physics() {
        let receipt = run_qsdk_r23d26_rapier_preflight_impl(
            "rapier_steering_cap_development",
            "positive_heading",
        )
        .expect("R23D26 Rapier worker preflight");
        assert_eq!(receipt["inherited_r23d11_controller_and_physics"], true);
        assert_eq!(
            receipt["independent_diagnostic_availability_semantics"],
            true
        );
        assert_eq!(receipt["inherited_r23d13_residual_pose_authority"], true);
        assert_eq!(
            receipt["r23d14_tight_gated_horizon_inherited_unchanged"],
            true
        );
        assert_eq!(
            receipt["r23d26_composition_recovery_identity_enabled"],
            true
        );
        assert_eq!(
            receipt["command_time_feedback_is_previous_completed_step"],
            true
        );
        assert_eq!(receipt["physical_worker_implemented"], true);
        assert_eq!(receipt["physical_execution_authorized"], false);
        assert_eq!(receipt["model_construction_count"], 0);
        assert_eq!(receipt["world_attempt_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
    }

    #[test]
    fn production_contract_matches_frozen_composition_and_temporal_identity() {
        let contract = r23d26_contract().expect("R23D26 contract");
        assert_eq!(
            contract["inherited_physical_contract"]["terminal_step_count"],
            R23D26_TERMINAL_STEPS
        );
        assert_eq!(
            contract["inherited_physical_contract"]["terminal_policy_id"],
            "sporespore_tight_gated_acquisition_active600_v1"
        );
        assert_eq!(contract["prospective_matrix"]["stage_id"], R23D26_STAGE_ID);
        let temporal: Value = serde_json::from_str(R23D14_TEMPORAL_PREREGISTRATION_RAW)
            .expect("R23D14 temporal contract");
        assert_eq!(
            temporal["inherited_whole_body_composition"]["maximum_pre_taper_combined_velocity_magnitude_rad_s"],
            MAXIMUM_COMBINED_VELOCITY
        );
        assert_eq!(
            temporal["inherited_residual_pose_authority"]["scale_denominator"],
            R23D26_SCALE_DENOMINATOR
        );
        assert_eq!(R23D26_TOTAL_TRACE_STEPS, 3_952);
        assert_eq!(
            R23D26_TRACE_RETENTION_MARKER,
            "QSDK_R23D26_TRACE_RETENTION "
        );
    }

    #[test]
    fn heading_aligned_nonzero_receipt_oracle_matches_core_and_rejects_legacy_axis() {
        let (compiled, controller) = r23d26_compile_boundary().expect("compile boundary");
        let mut state = synthetic_state_frame(&compiled, heading_quaternion(0.07));
        state.base_pose_world.position_m.x = 0.37;
        state.base_pose_world.position_m.z = 0.23;
        state.base_twist_world.linear_velocity_m_s.x = 0.19;
        state.base_twist_world.linear_velocity_m_s.z = -0.11;
        let command = command_for_arm_boundary("positive_heading", 0.0, 0.2);
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        assert_eq!(
            output.actuation.receipt.policy_id,
            R23D26_CONTROLLER_POLICY_ID
        );

        let expected = independent_oracle(&state, &command, controller.profile())
            .expect("heading-aligned independent oracle");
        let observed = receipt_values(&output.actuation.receipt);
        assert!(predicate_failures(expected, observed).is_empty());

        let legacy_cross_track_error = dot(
            subtract(
                state.base_pose_world.position_m,
                state.task_frame.origin_world_m,
            ),
            state.task_frame.lateral_axis_world_unit,
        );
        let legacy_cross_track_velocity = dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.lateral_axis_world_unit,
        );
        let requested = 0.2_f64;
        let legacy_desired = (requested
            - controller.profile().cross_track_heading_gain_rad_per_m * legacy_cross_track_error
            - controller
                .profile()
                .cross_track_velocity_heading_gain_rad_per_m_s
                * legacy_cross_track_velocity)
            .clamp(-0.25, 0.25);
        let legacy = [
            legacy_cross_track_error,
            legacy_cross_track_velocity,
            expected[2],
            legacy_desired,
            wrap_angle(expected[2] - legacy_desired),
        ];
        assert!(!predicate_failures(expected, legacy).is_empty());

        for index in 0..RECEIPT_FIELDS.len() {
            let mut mutated = expected;
            mutated[index] += 1.0e-6;
            assert_eq!(predicate_failures(expected, mutated).len(), 1);
        }
    }

    #[test]
    fn stability_is_composed_then_tapered_before_one_rapier_host_mapping() {
        let (compiled, controller) = r23d26_compile_boundary().expect("compile boundary");
        let turning_cell =
            r23d3_cell(R23D8_STAGE_ID, "onset_600", "positive_heading").expect("cell");
        let state = synthetic_state_frame(&compiled, heading_quaternion(0.2));
        let schedule = r23d3_schedule(&turning_cell, 0, state.task_frame.reference_yaw_rad);
        let command = r23d3_motion_command(0, PhaseProgressionMode::Clocked, &schedule);
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        let neutral = r23d8_compose_neutral_stance(&compiled, &output.actuation, &state, true)
            .expect("neutral composition");
        let stability_inputs = R23D26StabilityInputs {
            raw_velocity_deltas_rad_s: vec![Some(0.04); R23D3_ACTUATOR_COUNT as usize],
            availability: R23D26Availability::Available,
            availability_name: "available",
            support_margin_m: Some(0.01),
        };
        let (_, composed) = r23d26_compose_stability_assisted_taper(
            &compiled,
            &output.actuation,
            &neutral,
            &stability_inputs,
            60,
            120,
            &R23D26CommandFeedback {
                trace_step: R23D26_CONTROLLER_STEPS - 1,
                ordered_foot_contacts: BTreeMap::from([
                    ("front_left".to_owned(), true),
                    ("front_right".to_owned(), true),
                    ("rear_left".to_owned(), true),
                    ("rear_right".to_owned(), true),
                ]),
                torso_tilt_rad: 0.005,
                maximum_joint_error_rad: 0.1,
            },
            R23D26_CONTROLLER_STEPS,
            &R23D26CompositionMemory::default(),
        )
        .expect("stability-assisted composition");
        assert!(
            composed.maximum_absolute_commanded_joint_velocity_rad_s
                <= (MAXIMUM_NEUTRAL_VELOCITY + MAXIMUM_STABILITY_SLEW) * 0.5 + TOLERANCE
        );
        assert_eq!(composed.authority_receipt.applied_scale_numerator, 60);
        assert!(
            composed
                .applied_stability_velocity_deltas_rad_s
                .iter()
                .all(|value| (*value - MAXIMUM_STABILITY_SLEW).abs() <= TOLERANCE)
        );
        for (host, solution) in composed.host_mapping.ordered_commands.iter().zip(
            neutral.receipt["ordered_actuator_solutions"]
                .as_array()
                .expect("solutions"),
        ) {
            let expected = (solution["bounded_velocity_rad_s"]
                .as_f64()
                .expect("velocity")
                + MAXIMUM_STABILITY_SLEW)
                * 0.5;
            assert!((host.host_target_velocity_rad_s - expected).abs() <= TOLERANCE);
            assert!(host.native_target_position_rad.is_none());
        }
    }
}

#[cfg(test)]
mod r23d26_tests {
    use super::*;

    #[test]
    fn all_nine_cells_preflight_without_world_construction() {
        for candidate_id in ["cap_0p10", "cap_0p20", "cap_0p30"] {
            for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
                let receipt =
                    run_qsdk_r23d26_rapier_preflight_impl(R23D26_STAGE_ID, candidate_id, arm_id)
                        .expect("R23D26 preflight");
                assert_eq!(receipt["candidate_id"], candidate_id);
                assert_eq!(receipt["arm_id"], arm_id);
                assert_eq!(receipt["world_build_count"], 0);
                assert_eq!(receipt["physical_execution_authorized"], false);
                assert_eq!(receipt["terminal_taper_invoked"], false);
            }
        }
    }

    #[test]
    fn malformed_candidate_and_arm_fail_closed() {
        assert!(
            run_qsdk_r23d26_rapier_preflight_impl(R23D26_STAGE_ID, "cap_0p40", "positive_heading",)
                .is_err()
        );
        assert!(
            run_qsdk_r23d26_rapier_preflight_impl(
                R23D26_STAGE_ID,
                "cap_0p20",
                "outcome_selected_arm",
            )
            .is_err()
        );
    }
}
