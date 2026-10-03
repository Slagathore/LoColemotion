//! R23D66 finite-decision binding of the accepted Rapier/Parry turning kernel.
//!
//! Campaign identity, the fresh seed fixture, compact authorization, trace
//! retention, and terminal projection are owned here. The native world,
//! controller loop, public actuator-profile application, and observations stay
//! in the accepted shared R23D65/R23D29 physical kernel. Preflight and
//! authorization construct no model or world.

use std::{
    env, fs,
    path::{Path, PathBuf},
};

use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::{
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
};

use crate::actuator_cap_profile::resolve_production_public_profile_binding_v1;
use crate::qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D66_CAMPAIGN_ID, R23D66_CAMPAIGN_SEED, R23D66_ENGINE_ID, R23D66_GATE_ID, R23D66_STAGE_ID,
    R23D66_TRACE_TRANSPORT_ID, run_r23d66_rapier_kernel_preflight, run_r23d66_rapier_physical_core,
};

const PREREGISTRATION_RAW: &str = include_str!(
    "../../../turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json"
);
const PREREGISTRATION_PATH: &str =
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json";
const IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d66_production_route_three_engine_turning_implementation_v1.json";
const CLOSURE_PATH: &str =
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_closure_v1.json";
const WORKER_PATH: &str = "sdk/adapters/rapier/src/qsdk_r23d66_turning_route.rs";
const SHARED_KERNEL_PATH: &str =
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs";
const IMPLEMENTATION_SCHEMA: &str =
    "sporespore_qsdk_r23d66_production_route_three_engine_turning_implementation_v1";
const PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d66_rapier_worker_preflight_v1";
const AUTHORIZATION_SCHEMA: &str = "sporespore_qsdk_r23d66_rapier_authorization_v1";
const REPORT_SCHEMA: &str = "sporespore_qsdk_r23d66_engine_cell_report_v1";
const FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d66_worker_failure_v1";
const FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d66_physical_freeze_v1";
const ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d66_physical_attempt_v1";
const ONSET_ID: &str = "onset_600";
const HOST_MAPPING_ID: &str = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
const TURN_START_STEP: u64 = 600;
const TURN_END_STEP_EXCLUSIVE: u64 = 1_800;
const RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
const CONTROLLER_STEPS: u64 = 2_992;
const ORDERED_ARM_IDS: [&str; 3] = ["reference_zero", "positive_heading", "negative_heading"];

const FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D66_FREEZE";
const ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D66_ATTEMPT";
const TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D66_TOKEN";
const STAGE_ENV: &str = "SPORESPORE_QSDK_R23D66_STAGE";
const CELL_ENV: &str = "SPORESPORE_QSDK_R23D66_CELL";
const ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D66_ENGINE";
const ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D66_ATTEMPT_ROOT";
const AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D66_AUTHORITY_REPO_ROOT";

fn false_claims() -> Value {
    json!({
        "r23d66_finite_three_engine_turning": false,
        "finite_three_engine_turning": false,
        "portable_basic_turning": false,
        "q_sdk_r23_satisfied": false,
        "cross_engine_equivalence": false,
        "population_robustness": false,
        "arbitrary_quadruped_coverage": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn valid_lower_hex(value: &str, length: usize) -> bool {
    value.len() == length
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn raw_sha256(raw: &[u8]) -> String {
    format!("sha256:{:x}", Sha256::digest(raw))
}

fn repo_root() -> Result<PathBuf, String> {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .map_err(|error| format!("QSDK_R23D66_RAP_REPO_ROOT_UNREADABLE:{error}"))
}

fn read_json(path: &Path, code: &str) -> Result<(Vec<u8>, Value), String> {
    let raw = fs::read(path).map_err(|error| format!("{code}:{error}"))?;
    let value: Value =
        serde_json::from_slice(&raw).map_err(|error| format!("{code}_JSON_INVALID:{error}"))?;
    if !value.is_object() {
        return Err(format!("{code}_ROOT_INVALID"));
    }
    Ok((raw, value))
}

fn exact_cell_id(arm_id: &str) -> String {
    format!("r23d66__{R23D66_ENGINE_ID}__s{R23D66_CAMPAIGN_SEED}__{arm_id}")
}

fn arm_heading_offset(arm_id: &str) -> Value {
    match arm_id {
        "reference_zero" => Value::from(0.0),
        "positive_heading" => Value::from(0.2),
        "negative_heading" => Value::from(-0.2),
        _ => Value::Null,
    }
}

fn expected_cell_ids() -> Vec<String> {
    ["godot_jolt", "rapier_parry", "mujoco"]
        .into_iter()
        .flat_map(|engine_id| {
            ORDERED_ARM_IDS.into_iter().map(move |arm_id| {
                format!("r23d66__{engine_id}__s{R23D66_CAMPAIGN_SEED}__{arm_id}")
            })
        })
        .collect()
}

fn validate_identity(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
) -> Result<(), String> {
    if stage_id != R23D66_STAGE_ID {
        return Err("QSDK_R23D66_RAP_STAGE_INVALID".to_owned());
    }
    if onset_id != ONSET_ID {
        return Err("QSDK_R23D66_RAP_ONSET_INVALID".to_owned());
    }
    if campaign_seed != R23D66_CAMPAIGN_SEED {
        return Err("QSDK_R23D66_RAP_CAMPAIGN_SEED_INVALID".to_owned());
    }
    if profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID {
        return Err("QSDK_R23D66_RAP_PROFILE_INVALID".to_owned());
    }
    if !ORDERED_ARM_IDS.contains(&arm_id) {
        return Err("QSDK_R23D66_RAP_ARM_INVALID".to_owned());
    }
    Ok(())
}

fn dependencies_exact(root: &Path, values: &Value) -> bool {
    let Some(values) = values.as_object() else {
        return false;
    };
    !values.is_empty()
        && values.iter().all(|(relative, digest)| {
            let Some(digest) = digest.as_str() else {
                return false;
            };
            let Ok(path) = root.join(relative).canonicalize() else {
                return false;
            };
            path.starts_with(root)
                && path.is_file()
                && fs::read(path).is_ok_and(|raw| raw_sha256(&raw) == digest)
        })
}

fn implementation_contract() -> Result<Value, String> {
    let root = repo_root()?;
    if root.join(CLOSURE_PATH).is_file() {
        return Err("QSDK_R23D66_RAP_CLOSED".to_owned());
    }
    let preregistration_disk = fs::read(root.join(PREREGISTRATION_PATH))
        .map_err(|error| format!("QSDK_R23D66_RAP_PREREGISTRATION_UNREADABLE:{error}"))?;
    if preregistration_disk != PREREGISTRATION_RAW.as_bytes() {
        return Err("QSDK_R23D66_RAP_EMBEDDED_PREREGISTRATION_MISMATCH".to_owned());
    }
    let (_, value) = read_json(
        &root.join(IMPLEMENTATION_PATH),
        "QSDK_R23D66_RAP_IMPLEMENTATION_UNREADABLE",
    )?;
    let worker = &value["workers"][R23D66_ENGINE_ID];
    let worker_raw = fs::read(root.join(WORKER_PATH))
        .map_err(|error| format!("QSDK_R23D66_RAP_WORKER_UNREADABLE:{error}"))?;
    let exact = value["schema_version"] == IMPLEMENTATION_SCHEMA
        && value["status"]
            == "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized"
        && value["campaign_id"] == R23D66_CAMPAIGN_ID
        && value["gate_id"] == R23D66_GATE_ID
        && value["question_class"] == "finite_decision"
        && value["preregistration_path"] == PREREGISTRATION_PATH
        && value["preregistration_raw_sha256"] == raw_sha256(&preregistration_disk)
        && value["declared_cell_count"] == 9
        && value["declared_world_count"] == 9
        && value["ordered_cell_ids"] == json!(expected_cell_ids())
        && worker["path"] == WORKER_PATH
        && worker["raw_sha256"] == raw_sha256(&worker_raw)
        && worker["shared_native_kernel_path"] == SHARED_KERNEL_PATH
        && worker["shared_native_kernel_reused"] == true
        && worker["implementation_complete"] == true
        && value["claims"]["implementation_complete"] == true
        && value["claims"]["complete_zero_world_gate_passed"] == true
        && value["claims"]["physical_campaign_opened"] == false
        && value["claims"]["q_sdk_r23_satisfied"] == false
        && value["claims"]["release_authorized"] == false
        && dependencies_exact(&root, &value["dependency_digests"]);
    if !exact {
        return Err("QSDK_R23D66_RAP_IMPLEMENTATION_IDENTITY_INVALID".to_owned());
    }
    Ok(value)
}

fn failure(
    code: &str,
    arm_id: &str,
    source_commit: Option<&str>,
    model_constructions: u64,
    world_attempts: u64,
    world_builds: u64,
) -> Value {
    json!({
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": R23D66_CAMPAIGN_ID,
        "gate_id": R23D66_GATE_ID,
        "question_class": "finite_decision",
        "stage_id": R23D66_STAGE_ID,
        "cell_id": if ORDERED_ARM_IDS.contains(&arm_id) {
            Value::String(exact_cell_id(arm_id))
        } else {
            Value::Null
        },
        "engine_id": R23D66_ENGINE_ID,
        "campaign_seed": R23D66_CAMPAIGN_SEED,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": arm_id,
        "turn_heading_offset_rad": arm_heading_offset(arm_id),
        "source_commit": source_commit,
        "failure_stage": "before_world",
        "failure_code": code,
        "model_construction_count": model_constructions,
        "world_attempt_count": world_attempts,
        "world_build_count": world_builds,
        "claims": false_claims(),
        "physical_acceptance_authority": false,
    })
}

fn canonical_json_path(value: &Value) -> Option<PathBuf> {
    value
        .as_str()
        .and_then(|raw| PathBuf::from(raw).canonicalize().ok())
}

fn physical_authorization(arm_id: &str, source_commit: &str) -> Result<PathBuf, String> {
    let implementation = implementation_contract()?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D66_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    let root = repo_root()?;
    let freeze_path = PathBuf::from(env::var(FREEZE_PATH_ENV).unwrap_or_default());
    let attempt_path = PathBuf::from(env::var(ATTEMPT_PATH_ENV).unwrap_or_default());
    let attempt_root = PathBuf::from(env::var(ATTEMPT_ROOT_ENV).unwrap_or_default());
    let authority_root = PathBuf::from(env::var(AUTHORITY_REPO_ROOT_ENV).unwrap_or_default());
    let token = env::var(TOKEN_ENV).unwrap_or_default();
    if !freeze_path.is_file()
        || !attempt_path.is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D66_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let authority_root = authority_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D66_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D66_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    let evidence_root = root
        .parent()
        .ok_or_else(|| "QSDK_R23D66_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D66_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let (freeze_raw, freeze) = read_json(&freeze_path, "QSDK_R23D66_RAP_FREEZE_UNREADABLE")?;
    let (_, attempt) = read_json(&attempt_path, "QSDK_R23D66_RAP_ATTEMPT_UNREADABLE")?;
    let implementation_raw = fs::read(root.join(IMPLEMENTATION_PATH))
        .map_err(|error| format!("QSDK_R23D66_RAP_IMPLEMENTATION_UNREADABLE:{error}"))?;
    let environment_key = freeze["dependency_toolchain_environment_key"]
        .as_str()
        .unwrap_or_default();
    let exact = authority_root == root
        && attempt_root.starts_with(&evidence_root)
        && freeze["schema_version"] == FREEZE_SCHEMA
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["campaign_id"] == R23D66_CAMPAIGN_ID
        && freeze["gate_id"] == R23D66_GATE_ID
        && freeze["preregistration_raw_sha256"] == raw_sha256(PREREGISTRATION_RAW.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["origin_main_commit"] == source_commit
        && freeze["live_github_main_commit"] == source_commit
        && freeze["source_tree_git_oid"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 40))
        && freeze["source_worktree_clean"] == true
        && freeze["complete_zero_world_gate_passed"] == true
        && freeze["implementation_dependency_digests"] == implementation["dependency_digests"]
        && dependencies_exact(&root, &implementation["dependency_digests"])
        && valid_lower_hex(environment_key, 64)
        && freeze["declared_world_count"] == 9
        && freeze["ordered_cell_ids"] == json!(expected_cell_ids())
        && freeze["serial_execution_required"] == true
        && freeze["all_cells_run_regardless_of_intermediate_outcome"] == true
        && freeze["physical_behavior_thresholds_applied"] == true
        && freeze["physical_execution_authorized"] == true
        && freeze["physical_acceptance_authority"] == false
        && attempt["schema_version"] == ATTEMPT_SCHEMA
        && attempt["campaign_id"] == R23D66_CAMPAIGN_ID
        && attempt["gate_id"] == R23D66_GATE_ID
        && attempt["source_commit"] == source_commit
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["dependency_toolchain_environment_key"] == environment_key
        && attempt["ordered_cell_ids"] == json!(expected_cell_ids())
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["operation_lock_held"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && attempt["physical_execution_authorized"] == true
        && attempt["physical_acceptance_authority"] == false
        && canonical_json_path(&attempt["attempt_root"]).is_some_and(|path| path == attempt_root)
        && canonical_json_path(&attempt["authority_repo_root"])
            .is_some_and(|path| path == authority_root)
        && env::var(STAGE_ENV).unwrap_or_default() == R23D66_STAGE_ID
        && env::var(CELL_ENV).unwrap_or_default() == exact_cell_id(arm_id)
        && env::var(ENGINE_ENV).unwrap_or_default() == R23D66_ENGINE_ID;
    if !exact {
        return Err("QSDK_R23D66_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(attempt_root)
}

fn normalize_terminal(mut value: Value, arm_id: &str, source_commit: &str, report: bool) -> Value {
    let Some(object) = value.as_object_mut() else {
        return failure(
            "QSDK_R23D66_RAP_PHYSICAL_TERMINAL_NOT_OBJECT",
            arm_id,
            Some(source_commit),
            0,
            0,
            0,
        );
    };
    object.insert(
        "schema_version".to_owned(),
        Value::String(
            (if report {
                REPORT_SCHEMA
            } else {
                FAILURE_SCHEMA
            })
            .to_owned(),
        ),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D66_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D66_GATE_ID.to_owned()),
    );
    object.insert(
        "question_class".to_owned(),
        Value::String("finite_decision".to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D66_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(exact_cell_id(arm_id)));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D66_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D66_CAMPAIGN_SEED),
    );
    object.insert(
        "profile_id".to_owned(),
        Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()),
    );
    object.insert(
        "profile_sha256".to_owned(),
        Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
    );
    object.insert(
        "host_mapping_id".to_owned(),
        Value::String(HOST_MAPPING_ID.to_owned()),
    );
    object.insert("arm_id".to_owned(), Value::String(arm_id.to_owned()));
    object.insert(
        "turn_heading_offset_rad".to_owned(),
        arm_heading_offset(arm_id),
    );
    object.insert(
        "source_commit".to_owned(),
        Value::String(source_commit.to_owned()),
    );
    object.insert("claims".to_owned(), false_claims());
    object.insert(
        "physical_acceptance_authority".to_owned(),
        Value::Bool(false),
    );
    if let Some(transport) = object
        .get_mut("trace_transport")
        .and_then(Value::as_object_mut)
    {
        transport.insert(
            "trace_transport_id".to_owned(),
            Value::String(R23D66_TRACE_TRANSPORT_ID.to_owned()),
        );
    }
    if !report {
        object
            .entry("model_construction_count".to_owned())
            .or_insert(Value::from(0));
        object
            .entry("world_attempt_count".to_owned())
            .or_insert(Value::from(0));
        object
            .entry("world_build_count".to_owned())
            .or_insert(Value::from(0));
    }
    value
}

pub fn run_qsdk_r23d66_rapier_preflight(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id)?;
    let implementation = implementation_contract()?;
    let (_, declaration) = read_json(
        &repo_root()?.join(PREREGISTRATION_PATH),
        "QSDK_R23D66_RAP_PREREGISTRATION_UNREADABLE",
    )?;
    let kernel = run_r23d66_rapier_kernel_preflight(arm_id)?;
    let binding = resolve_production_public_profile_binding_v1()?;
    let matrix = &declaration["frozen_matrix"];
    let exact = kernel["initial_perturbation"] == matrix["initial_perturbation"]
        && kernel["campaign_seed"] == R23D66_CAMPAIGN_SEED
        && kernel["cell_id"] == exact_cell_id(arm_id)
        && kernel["turn_heading_offset_rad"] == arm_heading_offset(arm_id)
        && kernel["controller_step_count"] == CONTROLLER_STEPS
        && kernel["terminal_step_count"] == 0
        && kernel["turn_start_step"] == TURN_START_STEP
        && kernel["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && kernel["shared_native_kernel_reused"] == true
        && matrix["controller_step_count"] == CONTROLLER_STEPS
        && matrix["turn_start_step"] == TURN_START_STEP
        && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && matrix["recovery_duration_steps"]
            == RECOVERY_END_STEP_EXCLUSIVE - TURN_END_STEP_EXCLUSIVE
        && matrix["cells"]
            .as_array()
            .is_some_and(|cells| cells.len() == 9)
        && binding.ordered_mappings.len() == 8
        && binding.resolution_receipt["requested_profile_id"]
            == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && binding.host_mapping_receipt["host_mapping_id"] == HOST_MAPPING_ID;
    if !exact {
        return Err("QSDK_R23D66_RAP_PREFLIGHT_BINDING_INVALID".to_owned());
    }
    let dependency_count = implementation["dependency_digests"]
        .as_object()
        .map_or(0, Map::len);
    Ok(json!({
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": true,
        "failure_code": "",
        "campaign_id": R23D66_CAMPAIGN_ID,
        "gate_id": R23D66_GATE_ID,
        "question_class": "finite_decision",
        "stage_id": R23D66_STAGE_ID,
        "cell_id": exact_cell_id(arm_id),
        "engine_id": R23D66_ENGINE_ID,
        "campaign_seed": R23D66_CAMPAIGN_SEED,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": arm_id,
        "turn_heading_offset_rad": arm_heading_offset(arm_id),
        "controller_step_count": CONTROLLER_STEPS,
        "turn_start_step": TURN_START_STEP,
        "turn_end_step_exclusive": TURN_END_STEP_EXCLUSIVE,
        "recovery_end_step_exclusive": RECOVERY_END_STEP_EXCLUSIVE,
        "expected_segment_counts": {
            "reference_warmup": 600,
            "commanded_turn": 1200,
            "reference_recovery": 600,
            "reference_continuation": 592,
        },
        "implementation_dependency_count": dependency_count,
        "public_profile_force_plan_actuator_count": binding.ordered_mappings.len(),
        "public_profile_route_compiled": true,
        "fresh_perturbation_compiled": true,
        "shared_native_kernel_reused": true,
        "physical_worker_implemented": true,
        "returned_before_model": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_qsdk_r23d66_rapier_authorization_preflight(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id)?;
    let attempt_root = physical_authorization(arm_id, source_commit)?;
    Ok(json!({
        "schema_version": AUTHORIZATION_SCHEMA,
        "ok": true,
        "failure_code": "",
        "campaign_id": R23D66_CAMPAIGN_ID,
        "gate_id": R23D66_GATE_ID,
        "question_class": "finite_decision",
        "stage_id": R23D66_STAGE_ID,
        "cell_id": exact_cell_id(arm_id),
        "engine_id": R23D66_ENGINE_ID,
        "campaign_seed": R23D66_CAMPAIGN_SEED,
        "attempt_root": attempt_root,
        "authorization_passed": true,
        "returned_before_model": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_qsdk_r23d66_rapier_physical(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    if let Err(code) = validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id) {
        return Err(failure(&code, arm_id, Some(source_commit), 0, 0, 0));
    }
    let attempt_root = physical_authorization(arm_id, source_commit)
        .map_err(|code| failure(&code, arm_id, Some(source_commit), 0, 0, 0))?;
    match run_r23d66_rapier_physical_core(arm_id, source_commit, attempt_root) {
        Ok(value) => Ok(normalize_terminal(value, arm_id, source_commit, true)),
        Err(value) => Err(normalize_terminal(value, arm_id, source_commit, false)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frozen_identity_rejects_selector_mutations_without_a_world() {
        assert!(
            validate_identity(
                R23D66_STAGE_ID,
                ONSET_ID,
                R23D66_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            )
            .is_ok()
        );
        for candidate in [
            (
                "wrong",
                ONSET_ID,
                R23D66_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            ),
            (
                R23D66_STAGE_ID,
                "wrong",
                R23D66_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            ),
            (
                R23D66_STAGE_ID,
                ONSET_ID,
                R23D66_CAMPAIGN_SEED + 1,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "reference_zero",
            ),
            (
                R23D66_STAGE_ID,
                ONSET_ID,
                R23D66_CAMPAIGN_SEED,
                "wrong",
                "reference_zero",
            ),
            (
                R23D66_STAGE_ID,
                ONSET_ID,
                R23D66_CAMPAIGN_SEED,
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
                "wrong",
            ),
        ] {
            assert!(
                validate_identity(
                    candidate.0,
                    candidate.1,
                    candidate.2,
                    candidate.3,
                    candidate.4
                )
                .is_err()
            );
        }
    }

    #[test]
    fn matrix_order_is_engine_major_and_arm_minor() {
        let cells = expected_cell_ids();
        assert_eq!(cells.len(), 9);
        assert_eq!(cells[0], "r23d66__godot_jolt__s23179__reference_zero");
        assert_eq!(cells[4], "r23d66__rapier_parry__s23179__positive_heading");
        assert_eq!(cells[8], "r23d66__mujoco__s23179__negative_heading");
    }

    #[test]
    fn terminal_projection_preserves_observed_failure_counts() {
        let value = normalize_terminal(
            json!({
                "failure_code": "SYNTHETIC_AFTER_WORLD_FAILURE",
                "failure_stage": "settlement_complete",
                "model_construction_count": 1,
                "world_attempt_count": 1,
                "world_build_count": 1,
            }),
            "positive_heading",
            "1111111111111111111111111111111111111111",
            false,
        );
        assert_eq!(value["schema_version"], FAILURE_SCHEMA);
        assert_eq!(value["campaign_seed"], R23D66_CAMPAIGN_SEED);
        assert_eq!(value["world_attempt_count"], 1);
        assert_eq!(value["world_build_count"], 1);
        assert_eq!(value["claims"], false_claims());
    }
}
