//! QSDK-R24D53 minimal native staging-transport smoke.
//!
//! Zero-world qualification content-addresses the already-qualified R49
//! recovery route and R52 staging ledger. The separately launched physical
//! function reuses that world for one candidate arm and exactly two steps,
//! retaining the existing R45 in-run invariants plus every raw staging sample
//! and the cumulative portable V3 ledger. It does not evaluate behavior.

use rapier3d::pipeline::{PhysicsWorld, SporeSporeDiscreteStagingTelemetry};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::{
    RAPIER_R24D48_RECOVERY_ROUTE_ID, RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION,
    RecoveryArmKindV1, RecoveryEnergyBalanceAggregationRequestV3, RecoveryEnergyWorkIncrementV3,
    aggregate_recovery_energy_balance_v3, digest_json,
};

use crate::qsdk_r24d45_recovery_route::{
    compile_r24d45_recovery_boundary_v1, plan_r24d45_canonical_prone_pose_v1,
};
use crate::qsdk_r24d47_energy_exchange_observer::RapierEnergyExchangeSampleV1;
use crate::qsdk_r24d48_recovery_energy_v2_route::run_arm;
use crate::qsdk_r24d49_runtime_binding_route::run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification;
use crate::qsdk_r24d51_discrete_staging_observer::{
    R24D51_STAGING_RULE_ID, RapierDiscreteStagingExchangeV1,
};
use crate::qsdk_r24d52_discrete_staging_ledger::{
    R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID, collect_r24d52_rapier_discrete_staging_v1,
    map_r24d52_recovery_energy_increment_v3,
    run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification,
};

const CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d53_rapier_staging_transport_smoke_contract_v1.json");
const R52_CLOSURE_RAW: &str = include_str!(
    "../../../recovery/r24d52_rapier_discrete_staging_ledger_qualification_closure_v1.json"
);
pub const R24D53_GATE_ID: &str = "QSDK-R24D53";
const ZERO_WORLD_SCHEMA: &str =
    "sporespore_qsdk_r24d53_rapier_staging_transport_zero_world_qualification_v1";
const PROJECTION_SCHEMA: &str =
    "sporespore_qsdk_r24d53_staging_transport_runtime_binding_projection_v1";
const PHYSICAL_SCHEMA: &str = "sporespore_qsdk_r24d53_rapier_staging_transport_smoke_result_v1";

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
        .map_err(|error| format!("QSDK_R24D53_CONTRACT_PARSE:{error}"))?;
    if contract["gate_id"] != R24D53_GATE_ID
        || contract["question_class"] != "development"
        || contract["physical_question_declared"] != true
        || contract["predecessor"]["gate_id"] != "QSDK-R24D52"
        || contract["predecessor"]["closure_raw_sha256"] != raw_sha256(R52_CLOSURE_RAW.as_bytes())
        || contract["finite_physical_population"]["world_count"] != 1
        || contract["finite_physical_population"]["arm_count"] != 1
        || contract["finite_physical_population"]["arm_kind"] != "candidate_command"
        || contract["finite_physical_population"]["maximum_total_outer_steps"] != 2
        || contract["transport_acceptance"]["exact_staging_record_count"] != 2
        || contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] != 0
        || contract["controlled_change"]["threshold_changed"] != false
        || contract["controlled_change"]["margin_changed"] != false
        || contract["controlled_change"]["r49_controller_changed"] != false
    {
        return Err("QSDK_R24D53_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn runtime_binding_projection_v1() -> Result<Value, String> {
    let contract = validate_contract()?;
    let r49 = run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification()?;
    let r52 = run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification()?;
    let r49_sha256 =
        digest_json(&r49).map_err(|error| format!("QSDK_R24D53_R49_DIGEST:{error}"))?;
    let r52_sha256 =
        digest_json(&r52).map_err(|error| format!("QSDK_R24D53_R52_DIGEST:{error}"))?;
    Ok(json!({
        "schema_version": PROJECTION_SCHEMA,
        "gate_id": R24D53_GATE_ID,
        "predecessor_gate_id": "QSDK-R24D52",
        "predecessor_closure_raw_sha256":
            contract["predecessor"]["closure_raw_sha256"],
        "r49_recovery_route_preflight_sha256": r49_sha256,
        "r52_native_staging_preflight_sha256": r52_sha256,
        "contract_raw_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "transport_arm_kind": "candidate_command",
        "maximum_total_outer_steps": 2,
        "digest_algorithm": "sha256",
        "serialization_authority": "sporespore_locomotion_core::digest_json",
        "behavior_question_declared": false,
    }))
}

fn expected_runtime_binding_sha256() -> Result<String, String> {
    digest_json(&runtime_binding_projection_v1()?)
        .map_err(|error| format!("QSDK_R24D53_RUNTIME_BINDING_DIGEST:{error}"))
}

fn validate_runtime_binding_sha256(observed: &str) -> Result<(), String> {
    if !valid_sha256(observed) {
        return Err("QSDK_R24D53_RUNTIME_BINDING_SHA_INVALID".to_owned());
    }
    let expected = expected_runtime_binding_sha256()?;
    if observed != expected {
        return Err(format!(
            "QSDK_R24D53_RUNTIME_BINDING_SHA_MISMATCH:expected={expected}:observed={observed}"
        ));
    }
    Ok(())
}

fn mutation_rejected(
    projection: &Value,
    field: &str,
    replacement: Value,
    expected: &str,
) -> Result<bool, String> {
    let mut mutated = projection.clone();
    mutated
        .as_object_mut()
        .ok_or_else(|| "QSDK_R24D53_PROJECTION_OBJECT".to_owned())?
        .insert(field.to_owned(), replacement);
    let digest = digest_json(&mutated)
        .map_err(|error| format!("QSDK_R24D53_MUTATION_DIGEST:{field}:{error}"))?;
    Ok(digest != expected && validate_runtime_binding_sha256(&digest).is_err())
}

pub fn run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification() -> Result<Value, String>
{
    let contract = validate_contract()?;
    let r49 = run_qsdk_r24d49_rapier_runtime_binding_zero_world_qualification()?;
    let r52 = run_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_qualification()?;
    let projection = runtime_binding_projection_v1()?;
    let runtime_binding_sha256 = digest_json(&projection)
        .map_err(|error| format!("QSDK_R24D53_RUNTIME_BINDING_DIGEST:{error}"))?;
    validate_runtime_binding_sha256(&runtime_binding_sha256)?;

    let mutation_specs = [
        ("wrong_gate", "gate_id", json!("QSDK-R24D53-MUTATED")),
        (
            "wrong_r52_predecessor_digest",
            "predecessor_closure_raw_sha256",
            json!(format!("sha256:{}", "0".repeat(64))),
        ),
        ("wrong_recovery_route", "route_id", json!("mutated_route")),
        (
            "wrong_staging_mapping_profile",
            "mapping_profile_id",
            json!("mutated_mapping"),
        ),
        ("wrong_step_budget", "maximum_total_outer_steps", json!(3)),
    ];
    let mut mutations = Vec::new();
    for (mutation_id, field, replacement) in mutation_specs {
        let rejected = mutation_rejected(&projection, field, replacement, &runtime_binding_sha256)?;
        if !rejected {
            return Err(format!("QSDK_R24D53_MUTATION_ACCEPTED:{mutation_id}"));
        }
        mutations.push(json!({"mutation_id": mutation_id, "rejected": true}));
    }
    let controls = [
        r52["ok"] == true && r52["check_count"] == 17,
        r49["ok"] == true && r49["world_build_count"] == 0,
        projection.get("runtime_binding_sha256").is_none() && valid_sha256(&runtime_binding_sha256),
        contract["finite_physical_population"]["arm_count"] == 1
            && contract["finite_physical_population"]["maximum_total_outer_steps"] == 2,
        contract["transport_acceptance"]["in_run_r45_invariant_receipt_count"] == 2,
        projection["route_id"] == RAPIER_R24D48_RECOVERY_ROUTE_ID
            && projection["mapping_profile_id"] == R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        contract["complete_zero_world_gate"]["physical_execution_authorized"] == false,
    ];
    if controls.iter().any(|value| !value) {
        return Err("QSDK_R24D53_ZERO_WORLD_CONTROL_FAILED".to_owned());
    }
    let mutation_ids = mutations
        .iter()
        .map(|value| value["mutation_id"].clone())
        .collect::<Vec<_>>();
    Ok(json!({
        "schema_version": ZERO_WORLD_SCHEMA,
        "ok": true,
        "gate_id": R24D53_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_native_staging_transport_binding",
        "runtime_binding_projection": projection,
        "runtime_binding_sha256": runtime_binding_sha256,
        "runtime_binding_non_self_referential": true,
        "control_count": controls.len(),
        "controls_passed": controls.len(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": 5,
        "check_count": controls.len() + 5,
        "checks_passed": controls.len() + 5,
        "inherited_r49_runtime_binding_mutation_count":
            r49["runtime_binding_mutation_rejection_count"],
        "inherited_r52_check_count": r52["check_count"],
        "transport_arm_count": 1,
        "maximum_total_outer_steps": 2,
        "native_staging_transport_implemented": true,
        "native_staging_transport_observed": false,
        "in_run_physical_invariant_route_compiled": true,
        "physical_question_declared": true,
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

fn exchange_json(exchange: RapierDiscreteStagingExchangeV1) -> Value {
    json!({
        "schema_version": "sporespore_rapier_discrete_staging_exchange_v1",
        "rule_id": R24D51_STAGING_RULE_ID,
        "sequence": exchange.sequence,
        "force_integration_kinetic_exchange_j":
            exchange.force_integration_kinetic_exchange_j,
        "raw_gravity_potential_position_exchange_j":
            exchange.raw_gravity_potential_position_exchange_j,
        "endpoint_half_step_projection_exchange_j":
            exchange.endpoint_half_step_projection_exchange_j,
        "signed_discrete_staging_exchange_j": exchange.signed_discrete_staging_exchange_j,
        "small_step_count": exchange.small_step_count,
        "source_measurement": exchange.source_measurement,
        "mechanical_energy_change_used_as_input": false,
        "energy_balance_residual_used_as_input": false,
        "acceptance_threshold_used_as_input": false,
    })
}

fn native_telemetry_json(telemetry: SporeSporeDiscreteStagingTelemetry) -> Value {
    let retained_count = usize::try_from(telemetry.small_step_count)
        .unwrap_or(usize::MAX)
        .min(telemetry.small_steps.len());
    let small_steps = telemetry
        .small_steps
        .iter()
        .take(retained_count)
        .map(|step| {
            json!({
                "small_step_index": step.small_step_index,
                "kinetic_energy_before_force_j": f64::from(step.kinetic_energy_before_force_j),
                "kinetic_energy_after_force_j": f64::from(step.kinetic_energy_after_force_j),
                "raw_gravity_potential_before_position_j":
                    f64::from(step.raw_gravity_potential_before_position_j),
                "raw_gravity_potential_after_position_j":
                    f64::from(step.raw_gravity_potential_after_position_j),
                "source_measurement": step.source_measurement,
            })
        })
        .collect::<Vec<_>>();
    json!({
        "schema_version": "sporespore_rapier_native_discrete_staging_telemetry_v1",
        "sequence": telemetry.sequence,
        "small_steps": small_steps,
        "small_step_count": telemetry.small_step_count,
        "overflow_small_step_count": telemetry.overflow_small_step_count,
        "island_solve_count": telemetry.island_solve_count,
        "ccd_substep_count": telemetry.ccd_substep_count,
        "endpoint_half_step_projection_before_j":
            f64::from(telemetry.endpoint_half_step_projection_before_j),
        "endpoint_half_step_projection_after_j":
            f64::from(telemetry.endpoint_half_step_projection_after_j),
        "endpoint_body_count_before": telemetry.endpoint_body_count_before,
        "endpoint_body_count_after": telemetry.endpoint_body_count_after,
        "endpoint_source_measurement": telemetry.endpoint_source_measurement,
    })
}

pub fn run_qsdk_r24d53_rapier_staging_transport_smoke(
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_binding_sha256(runtime_binding_sha256)?;
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let mut previous_staging_sequence = 0_u64;
    let mut increments = Vec::<RecoveryEnergyWorkIncrementV3>::new();
    let mut staging_records = Vec::<Value>::new();
    let arm = run_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        2,
        runtime_binding_sha256,
        |world: &PhysicsWorld, energy: &RapierEnergyExchangeSampleV1, semantic_step| {
            let telemetry = world.physics_pipeline.sporespore_discrete_staging;
            let exchange =
                collect_r24d52_rapier_discrete_staging_v1(telemetry, previous_staging_sequence)?;
            let increment =
                map_r24d52_recovery_energy_increment_v3(*energy, exchange, semantic_step)?;
            staging_records.push(json!({
                "semantic_step": semantic_step,
                "native_telemetry": native_telemetry_json(telemetry),
                "staging_exchange": exchange_json(exchange),
                "energy_exchange_sample": energy.to_json(),
                "portable_v3_increment": serde_json::to_value(increment)
                    .map_err(|error| format!("QSDK_R24D53_INCREMENT_SERIALIZE:{error}"))?,
            }));
            increments.push(increment);
            previous_staging_sequence = exchange.sequence;
            Ok(())
        },
    )?;
    if arm.trace.observations.len() != 2
        || staging_records.len() != 2
        || increments.len() != 2
        || previous_staging_sequence != 2
    {
        return Err("QSDK_R24D53_EXACT_TRANSPORT_POPULATION_INVALID".to_owned());
    }
    let first = arm
        .trace
        .observations
        .first()
        .ok_or_else(|| "QSDK_R24D53_FIRST_OBSERVATION_MISSING".to_owned())?;
    let last = arm
        .trace
        .observations
        .last()
        .ok_or_else(|| "QSDK_R24D53_LAST_OBSERVATION_MISSING".to_owned())?;
    let aggregation =
        aggregate_recovery_energy_balance_v3(RecoveryEnergyBalanceAggregationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
            source_profile_id: R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID.to_owned(),
            initial_mechanical_energy_j: first.energy_balance.initial_mechanical_energy_j,
            current_mechanical_energy_j: last.energy_balance.current_mechanical_energy_j,
            ordered_increments: increments,
        })
        .map_err(|error| format!("QSDK_R24D53_V3_AGGREGATION:{error}"))?;
    let outer_steps = arm.arm_result["outer_step_count"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D53_OUTER_STEP_COUNT".to_owned())?;
    let native_solver_steps = arm.arm_result["native_solver_step_count"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D53_NATIVE_SOLVER_STEP_COUNT".to_owned())?;
    let invariant_count = arm.arm_result["invariant_receipts"]
        .as_array()
        .map(Vec::len)
        .ok_or_else(|| "QSDK_R24D53_INVARIANT_RECEIPTS".to_owned())?;
    if outer_steps != 2
        || native_solver_steps != 2
        || invariant_count != 2
        || aggregation.increment_count != 2
        || aggregation.first_sequence_index != 1
        || aggregation.last_sequence_index != 2
        || !valid_sha256(&aggregation.ordered_source_values_sha256)
        || aggregation.evaluation.threshold_applied
        || aggregation.evaluation.physical_result
        || aggregation.world_build_count != 0
        || aggregation.solver_step_count != 0
        || aggregation.physics_state_modified
        || aggregation.physical_acceptance_authority
        || aggregation.release_authority
    {
        return Err("QSDK_R24D53_TRANSPORT_RECEIPT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": PHYSICAL_SCHEMA,
        "ok": true,
        "gate_id": R24D53_GATE_ID,
        "question_class": "development_integration_smoke",
        "runtime_binding_sha256": runtime_binding_sha256,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "transport_arm": arm.arm_result,
        "native_staging_records": staging_records,
        "portable_v3_aggregation": aggregation,
        "maximum_total_outer_steps": 2,
        "actual_total_outer_steps": 2,
        "native_staging_record_count": 2,
        "portable_v3_increment_count": 2,
        "in_run_invariant_receipt_count": 2,
        "native_staging_transport_observed": true,
        "portable_v3_mapping_observed": true,
        "behavior_success_required": false,
        "official_behavior_evidence": false,
        "recovery_evaluation_executed": false,
        "result_may_satisfy_prone_to_standing": false,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 2,
        "physics_state_modified": true,
        "physical_question_opened": true,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_world_binding_is_exact_and_nonphysical() {
        let receipt = run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["checks_passed"], 12);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert_eq!(receipt["native_staging_transport_observed"], false);
    }

    #[test]
    fn malformed_runtime_binding_refuses_before_world() {
        assert!(run_qsdk_r24d53_rapier_staging_transport_smoke("not-a-digest").is_err());
    }
}
