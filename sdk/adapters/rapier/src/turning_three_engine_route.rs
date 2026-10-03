//! Genuine Rapier/Parry worker for the bounded three-engine turning route.
//!
//! This module owns route identity, zero-world validation, physical
//! authorization, and terminal projection. The native world and controller
//! loop remain in the established R23D29 production kernel; the route invokes
//! that kernel with the prospective two-step development horizon.

use std::{env, fs, path::PathBuf};

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::{
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
};

use crate::actuator_cap_profile::resolve_production_public_profile_binding_v1;
use crate::qsdk_r23d3_phase_balanced::r23d27_physical::{
    TURNING_ROUTE_CAMPAIGN_SEED, TURNING_ROUTE_CELL_ID, TURNING_ROUTE_CONTROLLER_STEPS,
    TURNING_ROUTE_ENGINE_ID, TURNING_ROUTE_ID, run_turning_route_rapier_physical_core,
};

const ROUTE_CONTRACT_RAW: &str =
    include_str!("../../../turning/three_engine_turning_success_transport_route_v2.json");
const ROUTE_CONTRACT_RELATIVE_PATH: &str =
    "sdk/turning/three_engine_turning_success_transport_route_v2.json";
const ROUTE_REPORT_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_cell_report_v2";
const ROUTE_FAILURE_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_worker_failure_v2";
const ROUTE_RETENTION_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_trace_retention_v2";
const ROUTE_PREFLIGHT_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_rapier_preflight_v2";
const ROUTE_AUTHORIZATION_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_rapier_authorization_v2";
const ROUTE_FREEZE_SCHEMA: &str = "sporespore_three_engine_turning_success_transport_freeze_v2";
const ROUTE_ATTEMPT_SCHEMA: &str = "sporespore_three_engine_turning_success_transport_attempt_v2";
const ROUTE_ARM_ID: &str = "positive_heading";
const ROUTE_HEADING_OFFSET_RAD: f64 = 0.2;
const ROUTE_HOST_MAPPING_ID: &str = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
const ROUTE_POLICY_ID: &str =
    "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1";
const ROUTE_MEMORY_SCHEMA: &str = "sporespore_balanced_wave_persistent_predictive_guard_memory_v1";
const ROUTE_HORIZON_POLICY_ID: &str = "sporespore_turning_route_two_step_horizon_v1";
const ROUTE_HORIZON_POLICY_SHA256: &str =
    "sha256:51c63281ddf18e22b3b68e19db2352dd9b0731e62fc1fb748f756ce3949b41b9";
const ROUTE_TRACE_POLICY_ID: &str = "sporespore_turning_route_two_step_trace_v1";
const ROUTE_TRACE_POLICY_SHA256: &str =
    "sha256:eaeba8aea37e27d91f1f2e4af8ba6a76ed4d7d2e2a98eb5778d5c1edf7fc81df";

const ROUTE_FREEZE_PATH_ENV: &str = "SPORESPORE_TURNING_ROUTE_FREEZE";
const ROUTE_ATTEMPT_PATH_ENV: &str = "SPORESPORE_TURNING_ROUTE_ATTEMPT";
const ROUTE_TOKEN_ENV: &str = "SPORESPORE_TURNING_ROUTE_TOKEN";
const ROUTE_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_TURNING_ROUTE_ATTEMPT_ROOT";
const ROUTE_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_TURNING_ROUTE_AUTHORITY_REPO_ROOT";
const ROUTE_ENGINE_ENV: &str = "SPORESPORE_TURNING_ROUTE_ENGINE";
const ROUTE_CELL_ENV: &str = "SPORESPORE_TURNING_ROUTE_CELL";

fn ledger_scope() -> Value {
    json!({
        "subsystem": "turning",
        "engine_scope": "3e",
        "authority_mode": "development_ghost",
        "question_class": "development",
    })
}

fn false_claims() -> Value {
    json!({
        "turning_established": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "arbitrary_quadruped_coverage": false,
        "q_sdk_r23_satisfied": false,
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
        .map_err(|error| format!("TURNING_ROUTE_RAP_REPO_ROOT_UNREADABLE:{error}"))
}

fn expected_cell_ids() -> Value {
    json!([
        "turning_success_transport_v2__godot_jolt__s21516__positive_heading",
        "turning_success_transport_v2__rapier_parry__s21516__positive_heading",
        "turning_success_transport_v2__mujoco__s21516__positive_heading",
    ])
}

fn validate_route_contract_value(contract: &Value) -> Result<(), String> {
    let ghost = &contract["development_ghost"];
    let semantics = &contract["canonical_semantics"];
    let thresholds = &contract["route_integrity_thresholds"];
    let transport = &contract["trace_transport_contract"];
    let exact = contract["schema_version"] == TURNING_ROUTE_ID
        && contract["route_id"] == TURNING_ROUTE_ID
        && contract["status"] == "prospective_zero_world_only"
        && contract["ledger_scope"] == ledger_scope()
        && ghost["development_seed"] == TURNING_ROUTE_CAMPAIGN_SEED
        && ghost["ordered_engine_ids"] == json!(["godot_jolt", "rapier_parry", "mujoco"])
        && ghost["arm_id"] == ROUTE_ARM_ID
        && ghost["turn_heading_offset_rad"] == ROUTE_HEADING_OFFSET_RAD
        && ghost["controller_step_count"] == TURNING_ROUTE_CONTROLLER_STEPS
        && ghost["turn_start_semantic_step"] == 0
        && ghost["turn_duration_steps"] == TURNING_ROUTE_CONTROLLER_STEPS
        && ghost["recovery_duration_steps"] == 0
        && ghost["terminal_step_count"] == 0
        && ghost["expected_actuator_count"] == 8
        && ghost["expected_native_actuation_application_count"] == 16
        && ghost["fixed_horizon_policy_id"] == ROUTE_HORIZON_POLICY_ID
        && ghost["fixed_horizon_policy_sha256"] == ROUTE_HORIZON_POLICY_SHA256
        && ghost["trace_policy_id"] == ROUTE_TRACE_POLICY_ID
        && ghost["trace_policy_sha256"] == ROUTE_TRACE_POLICY_SHA256
        && ghost["cell_report_schema"] == ROUTE_REPORT_SCHEMA
        && ghost["worker_failure_schema"] == ROUTE_FAILURE_SCHEMA
        && ghost["trace_retention_schema"] == ROUTE_RETENTION_SCHEMA
        && semantics["controller_policy_id"] == ROUTE_POLICY_ID
        && semantics["controller_memory_schema"] == ROUTE_MEMORY_SCHEMA
        && semantics["actuator_cap_profile_id"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && semantics["actuator_cap_profile_sha256"]
            == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        && thresholds["exact_cell_count"] == 3
        && thresholds["exact_controller_step_count_per_cell"] == TURNING_ROUTE_CONTROLLER_STEPS
        && thresholds["exact_trace_row_count_per_cell"] == TURNING_ROUTE_CONTROLLER_STEPS
        && thresholds["exact_world_attempt_count_per_cell"] == 1
        && thresholds["exact_world_build_count_per_cell"] == 1
        && thresholds["minimum_nonzero_turn_command_step_count_per_cell"] == 1
        && thresholds["exact_required_artifact_transport_field_count"] == 4
        && thresholds["exact_terminal_question_class_count"] == 3
        && thresholds["physical_behavior_thresholds_applied"] == false
        && transport["trace_transport_id"]
            == "sporespore_three_engine_turning_success_transport_v2"
        && transport["artifact_schema_version"]
            == "sporespore_content_addressed_artifact_receipt_v1"
        && transport["canonical_ndjson"] == true
        && transport["full_precision"] == true
        && transport["terminal_question_class"] == "development"
        && contract["claims"]["route_implemented"] == false
        && contract["claims"]["development_ghost_opened"] == false
        && contract["claims"]["physical_acceptance_authority"] == false;
    if !exact {
        return Err("TURNING_ROUTE_RAP_CONTRACT_INVALID".to_owned());
    }
    Ok(())
}

fn route_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(ROUTE_CONTRACT_RAW)
        .map_err(|error| format!("TURNING_ROUTE_RAP_CONTRACT_JSON_INVALID:{error}"))?;
    validate_route_contract_value(&contract)?;
    let root = repo_root()?;
    let disk_raw = fs::read(root.join(ROUTE_CONTRACT_RELATIVE_PATH))
        .map_err(|error| format!("TURNING_ROUTE_RAP_CONTRACT_UNREADABLE:{error}"))?;
    if disk_raw != ROUTE_CONTRACT_RAW.as_bytes() {
        return Err("TURNING_ROUTE_RAP_EMBEDDED_CONTRACT_MISMATCH".to_owned());
    }
    Ok(contract)
}

fn failure(
    code: &str,
    source_commit: Option<&str>,
    world_attempts: u64,
    world_builds: u64,
) -> Value {
    json!({
        "schema_version": ROUTE_FAILURE_SCHEMA,
        "campaign_id": TURNING_ROUTE_ID,
        "gate_id": TURNING_ROUTE_ID,
        "route_id": TURNING_ROUTE_ID,
        "ledger_scope": ledger_scope(),
        "question_class": "development",
        "stage_id": "turning_3e_success_transport_development_ghost",
        "engine_id": TURNING_ROUTE_ENGINE_ID,
        "cell_id": TURNING_ROUTE_CELL_ID,
        "campaign_seed": TURNING_ROUTE_CAMPAIGN_SEED,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "host_mapping_id": ROUTE_HOST_MAPPING_ID,
        "arm_id": ROUTE_ARM_ID,
        "turn_heading_offset_rad": ROUTE_HEADING_OFFSET_RAD,
        "source_commit": source_commit,
        "failure_stage": "before_world",
        "failure_code": code,
        "model_construction_count": world_builds,
        "world_attempt_count": world_attempts,
        "world_build_count": world_builds,
        "physical_behavior_thresholds_applied": false,
        "claims": false_claims(),
        "physical_acceptance_authority": false,
    })
}

fn normalize_terminal(mut terminal: Value, source_commit: &str, success: bool) -> Value {
    let Some(object) = terminal.as_object_mut() else {
        return failure(
            "TURNING_ROUTE_RAP_PHYSICAL_TERMINAL_NOT_OBJECT",
            Some(source_commit),
            0,
            0,
        );
    };
    let world_attempts = object
        .get("world_attempt_count")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let world_builds = object
        .get("world_build_count")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    object.insert(
        "schema_version".to_owned(),
        Value::String(
            (if success {
                ROUTE_REPORT_SCHEMA
            } else {
                ROUTE_FAILURE_SCHEMA
            })
            .to_owned(),
        ),
    );
    object.insert(
        "route_id".to_owned(),
        Value::String(TURNING_ROUTE_ID.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(TURNING_ROUTE_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(TURNING_ROUTE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String("turning_3e_success_transport_development_ghost".to_owned()),
    );
    object.insert(
        "question_class".to_owned(),
        Value::String("development".to_owned()),
    );
    object.insert("ledger_scope".to_owned(), ledger_scope());
    object.insert(
        "engine_id".to_owned(),
        Value::String(TURNING_ROUTE_ENGINE_ID.to_owned()),
    );
    object.insert(
        "cell_id".to_owned(),
        Value::String(TURNING_ROUTE_CELL_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(TURNING_ROUTE_CAMPAIGN_SEED),
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
        Value::String(ROUTE_HOST_MAPPING_ID.to_owned()),
    );
    object.insert("arm_id".to_owned(), Value::String(ROUTE_ARM_ID.to_owned()));
    object.insert(
        "turn_heading_offset_rad".to_owned(),
        Value::from(ROUTE_HEADING_OFFSET_RAD),
    );
    object.insert(
        "source_commit".to_owned(),
        Value::String(source_commit.to_owned()),
    );
    object.insert(
        "physical_behavior_thresholds_applied".to_owned(),
        Value::Bool(false),
    );
    object.insert("claims".to_owned(), false_claims());
    object.insert(
        "physical_acceptance_authority".to_owned(),
        Value::Bool(false),
    );
    if success {
        let trace_artifact = object.get("trace_artifact").cloned().unwrap_or(Value::Null);
        let trace_summary = object.get("trace_summary").cloned().unwrap_or(Value::Null);
        let nonzero_turn_steps = trace_summary["nonzero_turn_command_step_count"]
            .as_u64()
            .unwrap_or(0);
        object.insert(
            "trace_retention".to_owned(),
            json!({
                "schema_version": ROUTE_RETENTION_SCHEMA,
                "route_id": TURNING_ROUTE_ID,
                "ledger_scope": ledger_scope(),
                "question_class": "development",
                "engine_id": TURNING_ROUTE_ENGINE_ID,
                "cell_id": TURNING_ROUTE_CELL_ID,
                "campaign_seed": TURNING_ROUTE_CAMPAIGN_SEED,
                "row_count": trace_summary["row_count"].clone(),
                "first_semantic_step": trace_summary["first_semantic_step"].clone(),
                "last_semantic_step": trace_summary["last_semantic_step"].clone(),
                "nonzero_turn_command_step_count": nonzero_turn_steps,
                "canonical_ndjson": true,
                "retained_before_terminal_entry": true,
                "trace_artifact": trace_artifact,
                "physical_behavior_thresholds_applied": false,
                "physical_acceptance_authority": false,
            }),
        );
        if let Some(execution) = object.get_mut("execution").and_then(Value::as_object_mut) {
            execution.insert(
                "nonzero_turn_command_step_count".to_owned(),
                Value::from(nonzero_turn_steps),
            );
        }
        object.remove("model_construction_count");
        object.remove("world_attempt_count");
        object.remove("world_build_count");
    } else {
        object.insert(
            "model_construction_count".to_owned(),
            Value::from(world_builds),
        );
        object.insert(
            "world_attempt_count".to_owned(),
            Value::from(world_attempts),
        );
        object.insert("world_build_count".to_owned(), Value::from(world_builds));
    }
    terminal
}

fn physical_authorization(source_commit: &str) -> Result<PathBuf, String> {
    route_contract()?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("TURNING_ROUTE_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    let root = repo_root()?;
    let freeze_path = PathBuf::from(env::var(ROUTE_FREEZE_PATH_ENV).unwrap_or_default());
    let attempt_path = PathBuf::from(env::var(ROUTE_ATTEMPT_PATH_ENV).unwrap_or_default());
    let attempt_root = PathBuf::from(env::var(ROUTE_ATTEMPT_ROOT_ENV).unwrap_or_default());
    let authority_root = PathBuf::from(env::var(ROUTE_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default());
    let token = env::var(ROUTE_TOKEN_ENV).unwrap_or_default();
    if !freeze_path.is_file()
        || !attempt_path.is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("TURNING_ROUTE_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let canonical_authority_root = authority_root
        .canonicalize()
        .map_err(|_| "TURNING_ROUTE_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "TURNING_ROUTE_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    let evidence_root = root
        .parent()
        .ok_or_else(|| "TURNING_ROUTE_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "TURNING_ROUTE_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let freeze_raw = fs::read(&freeze_path)
        .map_err(|error| format!("TURNING_ROUTE_RAP_FREEZE_UNREADABLE:{error}"))?;
    let attempt_raw = fs::read(&attempt_path)
        .map_err(|error| format!("TURNING_ROUTE_RAP_ATTEMPT_UNREADABLE:{error}"))?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|error| format!("TURNING_ROUTE_RAP_FREEZE_JSON_INVALID:{error}"))?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|error| format!("TURNING_ROUTE_RAP_ATTEMPT_JSON_INVALID:{error}"))?;
    let exact = canonical_authority_root == root
        && canonical_attempt_root.starts_with(&evidence_root)
        && freeze["schema_version"] == ROUTE_FREEZE_SCHEMA
        && freeze["route_id"] == TURNING_ROUTE_ID
        && freeze["authority_mode"] == "development_ghost"
        && freeze["source_commit"] == source_commit
        && freeze["origin_main_commit"] == source_commit
        && freeze["live_github_main_commit"] == source_commit
        && freeze["contract_raw_sha256"] == raw_sha256(ROUTE_CONTRACT_RAW.as_bytes())
        && freeze["source_worktree_clean"] == true
        && freeze["complete_zero_world_gate_passed"] == true
        && freeze["declared_world_count"] == 3
        && freeze["ordered_cell_ids"] == expected_cell_ids()
        && freeze["serial_execution_required"] == true
        && freeze["physical_execution_authorized"] == true
        && freeze["physical_behavior_thresholds_applied"] == false
        && attempt["schema_version"] == ROUTE_ATTEMPT_SCHEMA
        && attempt["route_id"] == TURNING_ROUTE_ID
        && attempt["source_commit"] == source_commit
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["attempt_root"]
            .as_str()
            .and_then(|value| PathBuf::from(value).canonicalize().ok())
            .is_some_and(|value| value == canonical_attempt_root)
        && attempt["ordered_cell_ids"] == expected_cell_ids()
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["operation_lock_held"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && attempt["physical_execution_authorized"] == true
        && env::var(ROUTE_ENGINE_ENV).unwrap_or_default() == TURNING_ROUTE_ENGINE_ID
        && env::var(ROUTE_CELL_ENV).unwrap_or_default() == TURNING_ROUTE_CELL_ID;
    if !exact {
        return Err("TURNING_ROUTE_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_turning_route_rapier_preflight() -> Result<Value, String> {
    let contract = route_contract()?;
    let binding = resolve_production_public_profile_binding_v1()?;
    if binding.ordered_mappings.len() != 8
        || binding.resolution_receipt["requested_profile_id"]
            != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || binding.host_mapping_receipt["host_mapping_id"] != ROUTE_HOST_MAPPING_ID
    {
        return Err("TURNING_ROUTE_RAP_PUBLIC_PROFILE_BINDING_INVALID".to_owned());
    }
    let mut wrong_horizon = contract.clone();
    wrong_horizon["development_ghost"]["controller_step_count"] = Value::from(3);
    let mut wrong_engine_population = contract;
    wrong_engine_population["development_ghost"]["ordered_engine_ids"] =
        json!(["godot_jolt", "rapier_parry"]);
    if validate_route_contract_value(&wrong_horizon).is_ok()
        || validate_route_contract_value(&wrong_engine_population).is_ok()
    {
        return Err("TURNING_ROUTE_RAP_NEGATIVE_CONTROL_NOT_REJECTED".to_owned());
    }
    let synthetic_source_commit = "0".repeat(40);
    let success_projection = normalize_terminal(
        json!({
            "execution": {
                "integrity_passed": true,
                "worker_failure_code": "",
                "controller_semantic_step_count": TURNING_ROUTE_CONTROLLER_STEPS,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "trace_retained_before_terminal_entry": true,
                "fixed_horizon_configuration_proved_before_fixture_insertion": true,
            },
            "trace_artifact": {
                "sha256": format!("sha256:{}", "0".repeat(64)),
            },
            "trace_summary": {
                "row_count": TURNING_ROUTE_CONTROLLER_STEPS,
                "first_semantic_step": 0,
                "last_semantic_step": TURNING_ROUTE_CONTROLLER_STEPS - 1,
                "nonzero_turn_command_step_count": TURNING_ROUTE_CONTROLLER_STEPS,
            },
        }),
        &synthetic_source_commit,
        true,
    );
    if success_projection["trace_retention"]["question_class"] != "development" {
        return Err("TURNING_ROUTE_RAP_SUCCESS_RETENTION_QUESTION_CLASS_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": ROUTE_PREFLIGHT_SCHEMA,
        "ok": true,
        "failure_code": "",
        "route_id": TURNING_ROUTE_ID,
        "ledger_scope": ledger_scope(),
        "engine_id": TURNING_ROUTE_ENGINE_ID,
        "cell_id": TURNING_ROUTE_CELL_ID,
        "campaign_seed": TURNING_ROUTE_CAMPAIGN_SEED,
        "controller_step_count": TURNING_ROUTE_CONTROLLER_STEPS,
        "nonzero_turn_command_compiled": true,
        "public_profile_route_compiled": true,
        "public_profile_force_plan_actuator_count": binding.ordered_mappings.len(),
        "success_trace_retention_question_class_checked": true,
        "negative_control_count": 2,
        "negative_controls_rejected": 2,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_behavior_thresholds_applied": false,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_turning_route_rapier_authorization_preflight(
    source_commit: &str,
) -> Result<Value, String> {
    let attempt_root = physical_authorization(source_commit)?;
    Ok(json!({
        "schema_version": ROUTE_AUTHORIZATION_SCHEMA,
        "ok": true,
        "failure_code": "",
        "route_id": TURNING_ROUTE_ID,
        "ledger_scope": ledger_scope(),
        "engine_id": TURNING_ROUTE_ENGINE_ID,
        "cell_id": TURNING_ROUTE_CELL_ID,
        "attempt_root": attempt_root,
        "authorization_passed": true,
        "returned_before_model": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_turning_route_rapier_physical(source_commit: &str) -> Result<Value, Value> {
    let attempt_root = physical_authorization(source_commit)
        .map_err(|code| failure(&code, Some(source_commit), 0, 0))?;
    match run_turning_route_rapier_physical_core(source_commit, attempt_root) {
        Ok(value) => Ok(normalize_terminal(value, source_commit, true)),
        Err(value) => Err(normalize_terminal(value, source_commit, false)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn route_contract_is_exact_and_mutations_fail_closed() {
        let contract: Value = serde_json::from_str(ROUTE_CONTRACT_RAW).expect("route contract");
        validate_route_contract_value(&contract).expect("exact route contract");
        for field in ["controller_step_count", "development_seed"] {
            let mut candidate = contract.clone();
            candidate["development_ghost"][field] = Value::from(0);
            assert!(validate_route_contract_value(&candidate).is_err());
        }
    }

    #[test]
    fn zero_world_preflight_compiles_the_public_route() {
        let receipt = run_turning_route_rapier_preflight().expect("route preflight");
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["controller_step_count"], 2);
        assert_eq!(receipt["public_profile_force_plan_actuator_count"], 8);
        assert_eq!(receipt["negative_controls_rejected"], 2);
        assert_eq!(receipt["world_build_count"], 0);
    }

    #[test]
    fn terminal_projection_separates_success_and_failure_world_counts() {
        let source_commit = "1".repeat(40);
        let success = normalize_terminal(
            json!({
                "execution": {
                    "integrity_passed": true,
                    "worker_failure_code": "",
                    "controller_semantic_step_count": 2,
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "trace_retained_before_terminal_entry": true,
                    "fixed_horizon_configuration_proved_before_fixture_insertion": true,
                },
                "trace_artifact": {"sha256": format!("sha256:{}", "1".repeat(64))},
                "trace_summary": {
                    "row_count": 2,
                    "first_semantic_step": 0,
                    "last_semantic_step": 1,
                    "nonzero_turn_command_step_count": 2,
                },
                "world_attempt_count": 1,
                "world_build_count": 1,
            }),
            &source_commit,
            true,
        );
        assert_eq!(success["schema_version"], ROUTE_REPORT_SCHEMA);
        assert!(success.get("world_attempt_count").is_none());
        assert!(success.get("world_build_count").is_none());
        assert_eq!(success["execution"]["nonzero_turn_command_step_count"], 2);
        assert_eq!(success["trace_retention"]["question_class"], "development");

        let failed = normalize_terminal(
            json!({
                "failure_code": "SYNTHETIC_AFTER_WORLD_FAILURE",
                "world_attempt_count": 1,
                "world_build_count": 1,
            }),
            &source_commit,
            false,
        );
        assert_eq!(failed["schema_version"], ROUTE_FAILURE_SCHEMA);
        assert_eq!(failed["model_construction_count"], 1);
        assert_eq!(failed["world_attempt_count"], 1);
        assert_eq!(failed["world_build_count"], 1);
    }
}
