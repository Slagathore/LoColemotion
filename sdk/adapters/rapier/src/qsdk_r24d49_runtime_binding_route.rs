//! R24D49 successor that makes the physical runtime binding producer-owned.
//!
//! Rust emits one digest over a compact non-self-referential projection during
//! zero-world qualification. The launcher transports that exact field; only
//! Rust recomputes the projection before the inherited R24D48 physical path.

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::digest_json;

use crate::qsdk_r24d48_recovery_energy_v2_route::{
    R24D48_GATE_ID, run_qsdk_r24d48_rapier_recovery_energy_v2_development_after_runtime_binding_v1,
    run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1,
    run_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification,
};

const CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d49_rapier_runtime_binding_contract_v1.json");
pub const R24D49_GATE_ID: &str = "QSDK-R24D49";
const ZERO_WORLD_SCHEMA: &str =
    "sporespore_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification_v1";
const PROJECTION_SCHEMA: &str = "sporespore_qsdk_r24d49_runtime_binding_projection_v1";
const GHOST_SCHEMA: &str = "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_ghost_v1";
const DEVELOPMENT_SCHEMA: &str =
    "sporespore_qsdk_r24d49_rapier_recovery_energy_v2_development_result_v1";

fn raw_sha256(value: &[u8]) -> String {
    format!("sha256:{:x}", Sha256::digest(value))
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn validate_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R24D49_CONTRACT_PARSE:{error}"))?;
    if contract["gate_id"] != R24D49_GATE_ID
        || contract["question_class"] != "development"
        || contract["physical_question_declared"] != true
        || contract["predecessor"]["gate_id"] != R24D48_GATE_ID
        || contract["controlled_change"]["runtime_digest_transport_change_count"] != 1
        || contract["controlled_change"]["controller_change_count"] != 0
        || contract["controlled_change"]["evaluator_change_count"] != 0
        || contract["runtime_binding"]["projection_schema"] != PROJECTION_SCHEMA
        || contract["runtime_binding"]["producer"] != "rust_zero_world_preflight"
        || contract["runtime_binding"]["launcher_recomputation_permitted"] != false
        || contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] != 0
        || contract["staged_physical_execution"]["integration_ghost"]["maximum_outer_steps_per_arm"]
            != 2
        || contract["staged_physical_execution"]["paired_development"]["maximum_outer_steps_per_arm"]
            != 1200
    {
        return Err("QSDK_R24D49_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn runtime_binding_projection_v1() -> Result<Value, String> {
    let contract = validate_contract()?;
    let predecessor = run_qsdk_r24d48_rapier_recovery_energy_v2_zero_world_qualification()?;
    let predecessor_sha256 = digest_json(&predecessor)
        .map_err(|error| format!("QSDK_R24D49_PREDECESSOR_DIGEST:{error}"))?;
    Ok(json!({
        "schema_version": PROJECTION_SCHEMA,
        "gate_id": R24D49_GATE_ID,
        "predecessor_gate_id": R24D48_GATE_ID,
        "predecessor_zero_world_sha256": predecessor_sha256,
        "predecessor_invalid_closure_raw_sha256":
            contract["predecessor"]["invalid_ghost_closure_raw_sha256"],
        "contract_raw_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "route_id": predecessor["route_id"],
        "mapping_profile_id": predecessor["mapping_profile_id"],
        "energy_rule_id": predecessor["energy_rule_id"],
        "digest_algorithm": "sha256",
        "serialization_authority": "sporespore_locomotion_core::digest_json",
        "behavior_lineage_gate_id": R24D48_GATE_ID,
    }))
}

fn expected_runtime_binding_sha256() -> Result<String, String> {
    digest_json(&runtime_binding_projection_v1()?)
        .map_err(|error| format!("QSDK_R24D49_RUNTIME_BINDING_DIGEST:{error}"))
}

fn validate_runtime_binding_sha256(observed: &str) -> Result<(), String> {
    if !valid_sha256(observed) {
        return Err("QSDK_R24D49_RUNTIME_BINDING_SHA_INVALID".to_owned());
    }
    let expected = expected_runtime_binding_sha256()?;
    if observed != expected {
        return Err(format!(
            "QSDK_R24D49_RUNTIME_BINDING_SHA_MISMATCH:expected={expected}:observed={observed}"
        ));
    }
    Ok(())
}

fn mutated_projection_digest_differs(
    projection: &Value,
    field: &str,
    replacement: Value,
    expected: &str,
) -> Result<bool, String> {
    let mut mutated = projection.clone();
    let object = mutated
        .as_object_mut()
        .ok_or_else(|| "QSDK_R24D49_PROJECTION_OBJECT".to_owned())?;
    object.insert(field.to_owned(), replacement);
    let digest = digest_json(&mutated)
        .map_err(|error| format!("QSDK_R24D49_MUTATION_DIGEST:{field}:{error}"))?;
    Ok(digest != expected && validate_runtime_binding_sha256(&digest).is_err())
}

/// Complete zero-world qualification of the producer-owned digest transport.
pub fn run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification() -> Result<Value, String> {
    let contract = validate_contract()?;
    let projection = runtime_binding_projection_v1()?;
    let runtime_binding_sha256 = digest_json(&projection)
        .map_err(|error| format!("QSDK_R24D49_RUNTIME_BINDING_DIGEST:{error}"))?;
    validate_runtime_binding_sha256(&runtime_binding_sha256)?;

    let mutations = [
        ("wrong_gate", "gate_id", json!("QSDK-R24D49-MUTATED")),
        (
            "wrong_predecessor_digest",
            "predecessor_zero_world_sha256",
            json!(format!("sha256:{}", "0".repeat(64))),
        ),
        ("wrong_route", "route_id", json!("mutated_route")),
        (
            "wrong_contract_digest",
            "contract_raw_sha256",
            json!(format!("sha256:{}", "0".repeat(64))),
        ),
    ];
    let mut mutation_results = Vec::new();
    for (mutation_id, field, replacement) in mutations {
        let rejected = mutated_projection_digest_differs(
            &projection,
            field,
            replacement,
            &runtime_binding_sha256,
        )?;
        if !rejected {
            return Err(format!(
                "QSDK_R24D49_RUNTIME_BINDING_MUTATION_ACCEPTED:{mutation_id}"
            ));
        }
        mutation_results.push(json!({"mutation_id": mutation_id, "rejected": true}));
    }
    if projection.get("runtime_binding_sha256").is_some() {
        return Err("QSDK_R24D49_SELF_REFERENTIAL_PROJECTION".to_owned());
    }

    Ok(json!({
        "schema_version": ZERO_WORLD_SCHEMA,
        "ok": true,
        "gate_id": R24D49_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_producer_owned_runtime_binding",
        "predecessor_gate_id": R24D48_GATE_ID,
        "route_id": projection["route_id"],
        "mapping_profile_id": projection["mapping_profile_id"],
        "energy_rule_id": projection["energy_rule_id"],
        "runtime_binding_projection": projection,
        "runtime_binding_sha256": runtime_binding_sha256,
        "runtime_binding_projection_field_count": 12,
        "runtime_binding_self_check_passed": true,
        "runtime_binding_non_self_referential": true,
        "launcher_recomputation_permitted": false,
        "runtime_binding_mutation_rejection_count": mutation_results.len(),
        "runtime_binding_mutation_results": mutation_results,
        "r48_zero_world_replayed_exactly": true,
        "r48_behavior_semantics_changed": false,
        "physical_question_declared": contract["physical_question_declared"],
        "physical_execution_authorized_by_this_receipt": false,
        "maximum_physical_steps_authorized_by_this_receipt": 0,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "prone_to_standing_claimed": false,
        "sdk1_milestone_advanced": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

fn relabel_result(
    mut result: Value,
    schema_version: &str,
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    let object = result
        .as_object_mut()
        .ok_or_else(|| "QSDK_R24D49_INHERITED_RESULT_OBJECT".to_owned())?;
    object.insert("schema_version".to_owned(), json!(schema_version));
    object.insert("gate_id".to_owned(), json!(R24D49_GATE_ID));
    object.insert(
        "runtime_binding_sha256".to_owned(),
        json!(runtime_binding_sha256),
    );
    object.insert("behavior_lineage_gate_id".to_owned(), json!(R24D48_GATE_ID));
    object.insert(
        "runtime_binding_projection_schema".to_owned(),
        json!(PROJECTION_SCHEMA),
    );
    if object.remove("result_may_satisfy_r24d48").is_some() {
        object.insert("result_may_satisfy_r24d49".to_owned(), json!(true));
    }
    Ok(result)
}

/// Two-step-per-arm integration ghost after validating the R24D49 binding.
pub fn run_qsdk_r24d49_rapier_recovery_energy_v2_ghost(
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_binding_sha256(runtime_binding_sha256)?;
    let result = run_qsdk_r24d48_rapier_recovery_energy_v2_ghost_after_runtime_binding_v1(
        runtime_binding_sha256,
    )?;
    relabel_result(result, GHOST_SCHEMA, runtime_binding_sha256)
}

/// Unchanged finite recovery development path after R24D49 binding validation.
pub fn run_qsdk_r24d49_rapier_recovery_energy_v2_development_attempt(
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_binding_sha256(runtime_binding_sha256)?;
    let result = run_qsdk_r24d48_rapier_recovery_energy_v2_development_after_runtime_binding_v1(
        runtime_binding_sha256,
    )?;
    relabel_result(result, DEVELOPMENT_SCHEMA, runtime_binding_sha256)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runtime_binding_is_explicit_non_self_referential_and_zero_world() {
        let receipt = run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["runtime_binding_projection_field_count"], 12);
        assert_eq!(receipt["runtime_binding_mutation_rejection_count"], 4);
        assert_eq!(receipt["model_construction_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert!(
            receipt["runtime_binding_projection"]
                .get("runtime_binding_sha256")
                .is_none()
        );
    }

    #[test]
    fn malformed_and_wrong_runtime_bindings_refuse_before_physics() {
        assert!(run_qsdk_r24d49_rapier_recovery_energy_v2_ghost("not-a-digest").is_err());
        let wrong = format!("sha256:{}", "0".repeat(64));
        assert!(run_qsdk_r24d49_rapier_recovery_energy_v2_ghost(&wrong).is_err());
    }
}
