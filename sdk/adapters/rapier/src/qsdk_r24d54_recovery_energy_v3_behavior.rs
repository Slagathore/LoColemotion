//! QSDK-R24D54 exact-nominal paired Rapier recovery with portable energy V3.
//!
//! The zero-world entrypoint binds the immutable R49 negative, the R53 live
//! staging-transport positive, the strict core V3 observation API, and the one
//! finite paired question. The physical entrypoint reuses the unchanged R49
//! world/controller route, collects the qualified staging channel in-run, and
//! replays the resulting observations through the additive V3 evaluator.
//! R55 reuses those mechanics while separating the complete native capture
//! from the prospectively projected terminal-prefix evaluator population.

use rapier3d::pipeline::PhysicsWorld;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
    PORTABLE_RECOVERY_SEMANTICS_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    RAPIER_R24D48_RECOVERY_ROUTE_ID, RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION,
    RECOVERY_EVALUATION_REQUEST_V4_VERSION, RECOVERY_OBSERVATION_V3_VERSION,
    RECOVERY_STEP_REQUEST_V4_VERSION, RECOVERY_TRACE_V3_VERSION, RecoveryArmKindV1,
    RecoveryEnergyBalanceAggregationRequestV3, RecoveryEnergyBalanceLedgerV3,
    RecoveryEnergyWorkIncrementV3, RecoveryEvaluationReceiptV1, RecoveryEvaluationRequestV4,
    RecoveryObservationV2, RecoveryObservationV3, RecoveryPhaseV1, RecoveryStepRequestV4,
    RecoverySupportStatusV1, RecoveryTraceV3, aggregate_recovery_energy_balance_v3, digest_json,
    digest_serializable, evaluate_recovery_trace_v4, r23d60_selected_s169_descriptor,
    step_recovery_v4,
};

use crate::qsdk_r24d45_recovery_route::{
    RapierRecoveryBoundaryV1, RapierRecoveryPronePosePlanV1, arm_id,
    compile_r24d45_recovery_boundary_v1, initialize_arm_memory_v1,
    plan_r24d45_canonical_prone_pose_v1,
};
use crate::qsdk_r24d47_energy_exchange_observer::RapierEnergyExchangeSampleV1;
use crate::qsdk_r24d48_recovery_energy_v2_route::{RapierRecoveryArmRunV2, run_arm};
use crate::qsdk_r24d51_discrete_staging_observer::RapierDiscreteStagingExchangeV1;
use crate::qsdk_r24d52_discrete_staging_ledger::{
    R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID, collect_r24d52_rapier_discrete_staging_v1,
    map_r24d52_recovery_energy_increment_v3,
};
use crate::qsdk_r24d53_staging_transport_smoke::run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification;
use crate::recovery_capability::rapier_recovery_capability_v1;

const CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json");
const R49_NEGATIVE_CLOSURE_RAW: &str = include_str!(
    "../../../recovery/r24d49_rapier_recovery_energy_v2_development_negative_closure_v1.json"
);
const R53_POSITIVE_CLOSURE_RAW: &str = include_str!(
    "../../../recovery/r24d53_rapier_staging_transport_smoke_positive_closure_v1.json"
);
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
const R55_CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d55_rapier_terminal_prefix_recovery_contract_v1.json");
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
const R54_INVALID_CLOSURE_RAW: &str = include_str!(
    "../../../recovery/r24d54_rapier_recovery_energy_v3_development_invalid_closure_v1.json"
);

pub const R24D54_GATE_ID: &str = "QSDK-R24D54";
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
pub const R24D55_GATE_ID: &str = "QSDK-R24D55";
const ZERO_WORLD_SCHEMA: &str =
    "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification_v1";
const RUNTIME_BINDING_SCHEMA: &str =
    "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_runtime_binding_v1";
const ARM_RESULT_SCHEMA: &str = "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_arm_result_v1";
const DEVELOPMENT_RESULT_SCHEMA: &str =
    "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_development_result_v1";
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
const R55_ZERO_WORLD_SCHEMA: &str =
    "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_zero_world_qualification_v1";
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
const R55_RUNTIME_BINDING_SCHEMA: &str =
    "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_runtime_binding_v1";
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
const R55_DEVELOPMENT_RESULT_SCHEMA: &str =
    "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_development_result_v1";
const CELL_ID: &str = "r24d48_rapier_development_nominal";
const CELL_SEED: u32 = 260_226_999;
const MAXIMUM_OUTER_STEPS_PER_ARM: u64 = 1200;
const MAXIMUM_TOTAL_OUTER_STEPS: u64 = 2400;

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
        .map_err(|error| format!("QSDK_R24D54_CONTRACT_PARSE:{error}"))?;
    if contract["gate_id"] != R24D54_GATE_ID
        || contract["question_class"] != "development"
        || contract["physical_question_declared"] != true
        || contract["bound_predecessors"][0]["raw_sha256"]
            != raw_sha256(R49_NEGATIVE_CLOSURE_RAW.as_bytes())
        || contract["bound_predecessors"][1]["raw_sha256"]
            != raw_sha256(R53_POSITIVE_CLOSURE_RAW.as_bytes())
        || contract["controlled_change"]["controller_changed"] != false
        || contract["controlled_change"]["threshold_changed"] != false
        || contract["controlled_change"]["margin_changed"] != false
        || contract["finite_development_population"]["cell_id"] != CELL_ID
        || contract["finite_development_population"]["cell_seed"] != CELL_SEED
        || contract["finite_development_population"]["arm_count"] != 2
        || contract["finite_development_population"]["maximum_outer_steps_per_arm"]
            != MAXIMUM_OUTER_STEPS_PER_ARM
        || contract["finite_development_population"]["maximum_total_outer_steps"]
            != MAXIMUM_TOTAL_OUTER_STEPS
        || contract["threshold_and_margin_provenance"]["maximum_energy_balance_residual_j"] != 0.25
        || contract["threshold_and_margin_provenance"]["required_stance_dwell_steps"] != 60
        || contract["v3_replay_validity"]["pre_terminal_phase_identity_required"] != true
        || contract["v3_replay_validity"]["only_terminal_transition_divergence_permitted"] != true
        || contract["complete_zero_world_gate"]["physical_execution_authorized"] != false
        || contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] != 0
    {
        return Err("QSDK_R24D54_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

fn zero_world_v3_fixture() -> Result<(Value, Value), String> {
    let request = RecoveryEnergyBalanceAggregationRequestV3 {
        schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
        source_profile_id: "r24d54_zero_world_staging_consumption_fixture_v1".to_owned(),
        initial_mechanical_energy_j: 10.0,
        current_mechanical_energy_j: 11.875,
        ordered_increments: vec![
            RecoveryEnergyWorkIncrementV3 {
                sequence_index: 1,
                semantic_step: 1,
                applied_actuator_work_j: 4.0,
                signed_external_work_j: 1.0,
                signed_constraint_exchange_j: 2.0,
                signed_discrete_staging_exchange_j: 0.5,
                passive_dissipation_j: 0.5,
                source_measurement: true,
            },
            RecoveryEnergyWorkIncrementV3 {
                sequence_index: 2,
                semantic_step: 2,
                applied_actuator_work_j: -0.5,
                signed_external_work_j: -0.25,
                signed_constraint_exchange_j: -3.0,
                signed_discrete_staging_exchange_j: -0.125,
                passive_dissipation_j: 1.25,
                source_measurement: true,
            },
        ],
    };
    let balanced = aggregate_recovery_energy_balance_v3(request.clone())
        .map_err(|error| format!("QSDK_R24D54_V3_FIXTURE:{error}"))?;
    let mut omitted = request;
    for increment in &mut omitted.ordered_increments {
        increment.signed_discrete_staging_exchange_j = 0.0;
    }
    let omitted = aggregate_recovery_energy_balance_v3(omitted)
        .map_err(|error| format!("QSDK_R24D54_V3_OMISSION_FIXTURE:{error}"))?;
    Ok((
        serde_json::to_value(balanced)
            .map_err(|error| format!("QSDK_R24D54_V3_FIXTURE_SERIALIZE:{error}"))?,
        serde_json::to_value(omitted)
            .map_err(|error| format!("QSDK_R24D54_V3_OMISSION_SERIALIZE:{error}"))?,
    ))
}

fn runtime_binding_projection_v1() -> Result<Value, String> {
    let contract = validate_contract()?;
    let r53 = run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification()?;
    let r53_preflight_sha256 =
        digest_json(&r53).map_err(|error| format!("QSDK_R24D54_R53_PREFLIGHT_DIGEST:{error}"))?;
    Ok(json!({
        "schema_version": RUNTIME_BINDING_SCHEMA,
        "gate_id": R24D54_GATE_ID,
        "contract_raw_sha256": raw_sha256(CONTRACT_RAW.as_bytes()),
        "r49_negative_closure_raw_sha256": raw_sha256(R49_NEGATIVE_CLOSURE_RAW.as_bytes()),
        "r53_positive_closure_raw_sha256": raw_sha256(R53_POSITIVE_CLOSURE_RAW.as_bytes()),
        "r53_staging_transport_preflight_sha256": r53_preflight_sha256,
        "recovery_route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "staging_mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "observation_schema": RECOVERY_OBSERVATION_V3_VERSION,
        "step_request_schema": RECOVERY_STEP_REQUEST_V4_VERSION,
        "trace_schema": RECOVERY_TRACE_V3_VERSION,
        "evaluation_request_schema": RECOVERY_EVALUATION_REQUEST_V4_VERSION,
        "threshold_profile_id": EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
        "maximum_outer_steps_per_arm": MAXIMUM_OUTER_STEPS_PER_ARM,
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "pre_terminal_phase_identity_required":
            contract["v3_replay_validity"]["pre_terminal_phase_identity_required"],
        "only_terminal_transition_divergence_permitted":
            contract["v3_replay_validity"]["only_terminal_transition_divergence_permitted"],
        "development_requires_prior_ghost":
            contract["physical_runner"]["development_requires_prior_ghost"],
        "digest_algorithm": "sha256",
        "serialization_authority": "sporespore_locomotion_core::digest_json",
    }))
}

fn expected_runtime_binding_sha256() -> Result<String, String> {
    digest_json(&runtime_binding_projection_v1()?)
        .map_err(|error| format!("QSDK_R24D54_RUNTIME_BINDING_DIGEST:{error}"))
}

fn validate_runtime_binding_sha256(observed: &str) -> Result<(), String> {
    if !valid_sha256(observed) {
        return Err("QSDK_R24D54_RUNTIME_BINDING_SHA_INVALID".to_owned());
    }
    let expected = expected_runtime_binding_sha256()?;
    if observed != expected {
        return Err(format!(
            "QSDK_R24D54_RUNTIME_BINDING_SHA_MISMATCH:expected={expected}:observed={observed}"
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
        .ok_or_else(|| "QSDK_R24D54_PROJECTION_OBJECT".to_owned())?
        .insert(field.to_owned(), replacement);
    let digest = digest_json(&mutated)
        .map_err(|error| format!("QSDK_R24D54_MUTATION_DIGEST:{field}:{error}"))?;
    Ok(digest != expected && validate_runtime_binding_sha256(&digest).is_err())
}

/// Complete pure gate for the prospectively declared R54 paired question.
pub fn run_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification() -> Result<Value, String>
{
    let contract = validate_contract()?;
    let r53 = run_qsdk_r24d53_rapier_staging_transport_zero_world_qualification()?;
    let r53_closure: Value = serde_json::from_str(R53_POSITIVE_CLOSURE_RAW)
        .map_err(|error| format!("QSDK_R24D54_R53_CLOSURE_PARSE:{error}"))?;
    let projection = runtime_binding_projection_v1()?;
    let runtime_binding_sha256 = digest_json(&projection)
        .map_err(|error| format!("QSDK_R24D54_RUNTIME_BINDING_DIGEST:{error}"))?;
    validate_runtime_binding_sha256(&runtime_binding_sha256)?;
    let (balanced_fixture, omitted_fixture) = zero_world_v3_fixture()?;

    let _step_api = step_recovery_v4;
    let _evaluation_api = evaluate_recovery_trace_v4;
    let mutation_specs = [
        ("wrong_gate", "gate_id", json!("QSDK-R24D54-MUTATED")),
        (
            "wrong_r49_closure_digest",
            "r49_negative_closure_raw_sha256",
            json!(format!("sha256:{}", "0".repeat(64))),
        ),
        (
            "wrong_r53_closure_digest",
            "r53_positive_closure_raw_sha256",
            json!(format!("sha256:{}", "1".repeat(64))),
        ),
        (
            "wrong_observation_schema",
            "observation_schema",
            json!("sporespore_recovery_observation_v2"),
        ),
        (
            "wrong_step_budget",
            "maximum_total_outer_steps",
            json!(2401),
        ),
        (
            "wrong_replay_rule",
            "pre_terminal_phase_identity_required",
            json!(false),
        ),
    ];
    let mut mutations = Vec::new();
    for (mutation_id, field, replacement) in mutation_specs {
        if !mutation_rejected(&projection, field, replacement, &runtime_binding_sha256)? {
            return Err(format!("QSDK_R24D54_MUTATION_ACCEPTED:{mutation_id}"));
        }
        mutations.push(json!({"mutation_id": mutation_id, "rejected": true}));
    }

    let controls = [
        r53["ok"] == true && r53["world_build_count"] == 0,
        projection["r49_negative_closure_raw_sha256"]
            == contract["bound_predecessors"][0]["raw_sha256"]
            && projection["r53_positive_closure_raw_sha256"]
                == contract["bound_predecessors"][1]["raw_sha256"],
        projection["observation_schema"] == RECOVERY_OBSERVATION_V3_VERSION
            && projection["step_request_schema"] == RECOVERY_STEP_REQUEST_V4_VERSION
            && projection["evaluation_request_schema"] == RECOVERY_EVALUATION_REQUEST_V4_VERSION,
        balanced_fixture["evaluation"]["signed_residual_j"] == 0.0,
        omitted_fixture["evaluation"]["signed_residual_j"] == 0.375,
        projection["maximum_outer_steps_per_arm"] == MAXIMUM_OUTER_STEPS_PER_ARM
            && projection["maximum_total_outer_steps"] == MAXIMUM_TOTAL_OUTER_STEPS,
        projection["pre_terminal_phase_identity_required"] == true
            && projection["only_terminal_transition_divergence_permitted"] == true,
        r53_closure["decision"]["live_native_staging_transport_observed"] == true
            && r53_closure["decision"]["portable_v3_mapping_observed"] == true
            && projection["development_requires_prior_ghost"] == false,
        contract["complete_zero_world_gate"]["physical_execution_authorized"] == false
            && contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] == 0,
    ];
    if controls.iter().any(|value| !value) {
        return Err("QSDK_R24D54_ZERO_WORLD_CONTROL_FAILED".to_owned());
    }
    let mutation_ids = mutations
        .iter()
        .map(|value| value["mutation_id"].clone())
        .collect::<Vec<_>>();
    Ok(json!({
        "schema_version": ZERO_WORLD_SCHEMA,
        "ok": true,
        "gate_id": R24D54_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_v3_recovery_behavior_route",
        "runtime_binding_projection": projection,
        "runtime_binding_sha256": runtime_binding_sha256,
        "runtime_binding_non_self_referential": true,
        "control_count": controls.len(),
        "controls_passed": controls.len(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": 6,
        "check_count": controls.len() + 6,
        "checks_passed": controls.len() + 6,
        "balanced_v3_fixture": balanced_fixture,
        "forced_staging_omission_fixture": omitted_fixture,
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "r53_live_transport_observed": true,
        "v3_staging_consumed_by_evaluator": true,
        "pre_terminal_phase_identity_compiled": true,
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

/// Execute the one prospectively declared finite paired R54 development attempt.
pub fn run_qsdk_r24d54_rapier_recovery_energy_v3_development_attempt(
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    validate_runtime_binding_sha256(runtime_binding_sha256)?;
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_v3_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        runtime_binding_sha256,
    )?;
    let matched_zero = run_v3_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        runtime_binding_sha256,
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
    {
        return Err("QSDK_R24D54_INITIAL_STATE_MISMATCH".to_owned());
    }
    let candidate_steps = candidate.trace.observations.len();
    let matched_zero_steps = matched_zero.trace.observations.len();
    let actual_total = candidate_steps + matched_zero_steps;
    if candidate_steps > MAXIMUM_OUTER_STEPS_PER_ARM as usize
        || matched_zero_steps > MAXIMUM_OUTER_STEPS_PER_ARM as usize
        || actual_total > MAXIMUM_TOTAL_OUTER_STEPS as usize
    {
        return Err("QSDK_R24D54_DEVELOPMENT_BUDGET_EXCEEDED".to_owned());
    }
    let evaluation = evaluate_paired_traces(
        &boundary,
        candidate.trace.clone(),
        matched_zero.trace.clone(),
    )?;
    validate_pure_evaluation(&evaluation)?;
    Ok(json!({
        "schema_version": DEVELOPMENT_RESULT_SCHEMA,
        "ok": true,
        "gate_id": R24D54_GATE_ID,
        "question_class": "development",
        "runtime_binding_sha256": runtime_binding_sha256,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "cell_id": CELL_ID,
        "cell_seed": CELL_SEED,
        "candidate": candidate.result,
        "matched_zero_command": matched_zero.result,
        "evaluation": evaluation,
        "candidate_outer_steps": candidate_steps,
        "matched_zero_outer_steps": matched_zero_steps,
        "actual_total_outer_steps": actual_total,
        "maximum_outer_steps_per_arm": MAXIMUM_OUTER_STEPS_PER_ARM,
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "result_may_satisfy_r24d54": true,
        "prone_to_standing_claimed": evaluation.prone_to_standing_claimed,
        "repeatability_rate_claimed": false,
        "population_claimed": false,
        "cross_engine_recovery_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

struct R54ArmRun {
    trace: RecoveryTraceV3,
    #[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
    terminal_prefix_trace: RecoveryTraceV3,
    result: Value,
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn project_terminal_prefix<T: Clone>(
    captured: &[T],
    terminal_prefix_observation_count: usize,
) -> Result<Vec<T>, String> {
    if terminal_prefix_observation_count == 0 {
        return Err("QSDK_R24D55_TERMINAL_PREFIX_EMPTY".to_owned());
    }
    if terminal_prefix_observation_count > captured.len() {
        return Err(format!(
            "QSDK_R24D55_TERMINAL_PREFIX_OUT_OF_RANGE:prefix={terminal_prefix_observation_count}:captured={}",
            captured.len()
        ));
    }
    Ok(captured[..terminal_prefix_observation_count].to_vec())
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn terminal_prefix_trace_v3(
    captured: &RecoveryTraceV3,
    terminal_prefix_observation_count: usize,
) -> Result<RecoveryTraceV3, String> {
    Ok(RecoveryTraceV3 {
        schema_version: captured.schema_version.clone(),
        arm_kind: captured.arm_kind,
        declared_initial_state_sha256: captured.declared_initial_state_sha256.clone(),
        observations: project_terminal_prefix(
            &captured.observations,
            terminal_prefix_observation_count,
        )?,
    })
}

fn observation_v3_from_v2(
    observation: RecoveryObservationV2,
    energy_balance: RecoveryEnergyBalanceLedgerV3,
) -> RecoveryObservationV3 {
    RecoveryObservationV3 {
        schema_version: RECOVERY_OBSERVATION_V3_VERSION.to_owned(),
        task_id: observation.task_id,
        semantics_id: observation.semantics_id,
        actuator_profile_id: observation.actuator_profile_id,
        semantic_step: observation.semantic_step,
        outer_step_duration_s: observation.outer_step_duration_s,
        state: observation.state,
        center_of_mass: observation.center_of_mass,
        ordered_foot_bearing_observations: observation.ordered_foot_bearing_observations,
        ordered_body_clearance_observations: observation.ordered_body_clearance_observations,
        applied_actuation: observation.applied_actuation,
        external_interventions: observation.external_interventions,
        controller_ownership: observation.controller_ownership,
        energy_balance,
        engine_step_identity: observation.engine_step_identity,
    }
}

fn initial_observation_sha256(observation: &RecoveryObservationV3) -> Result<String, String> {
    digest_json(&json!({
        "base_pose_world": observation.state.base_pose_world,
        "base_twist_world": observation.state.base_twist_world,
        "ordered_joint_observations": observation.state.ordered_joint_observations,
        "ordered_contact_observations": observation.state.ordered_contact_observations,
        "gravity_world_m_s2": observation.state.gravity_world_m_s2,
        "task_frame": observation.state.task_frame,
        "center_of_mass": observation.center_of_mass,
        "ordered_foot_bearing_observations": observation.ordered_foot_bearing_observations,
        "ordered_body_clearance_observations": observation.ordered_body_clearance_observations,
        "energy_initial_mechanical_j": observation.energy_balance.initial_mechanical_energy_j,
        "energy_current_mechanical_j": observation.energy_balance.current_mechanical_energy_j,
    }))
    .map_err(|error| format!("QSDK_R24D54_INITIAL_OBSERVATION_SHA:{error}"))
}

fn compact_staging_record(
    world: &PhysicsWorld,
    energy: RapierEnergyExchangeSampleV1,
    exchange: RapierDiscreteStagingExchangeV1,
    increment: RecoveryEnergyWorkIncrementV3,
    semantic_step: u64,
) -> Result<Value, String> {
    let telemetry = world.physics_pipeline.sporespore_discrete_staging;
    Ok(json!({
        "semantic_step": semantic_step,
        "energy_sequence": energy.sequence,
        "staging_sequence": exchange.sequence,
        "small_step_count": telemetry.small_step_count,
        "overflow_small_step_count": telemetry.overflow_small_step_count,
        "island_solve_count": telemetry.island_solve_count,
        "ccd_substep_count": telemetry.ccd_substep_count,
        "endpoint_body_count_before": telemetry.endpoint_body_count_before,
        "endpoint_body_count_after": telemetry.endpoint_body_count_after,
        "endpoint_source_measurement": telemetry.endpoint_source_measurement,
        "signed_discrete_staging_exchange_j": exchange.signed_discrete_staging_exchange_j,
        "source_measurement": exchange.source_measurement,
        "portable_v3_increment_sha256": digest_serializable(&increment)
            .map_err(|error| format!("QSDK_R24D54_INCREMENT_DIGEST:{error}"))?,
    }))
}

fn run_v3_arm(
    boundary: &RapierRecoveryBoundaryV1,
    pose: &RapierRecoveryPronePosePlanV1,
    arm: RecoveryArmKindV1,
    runtime_binding_sha256: &str,
) -> Result<R54ArmRun, String> {
    let mut previous_staging_sequence = 0_u64;
    let mut increments = Vec::<RecoveryEnergyWorkIncrementV3>::new();
    let mut staging_records = Vec::<Value>::new();
    let source: RapierRecoveryArmRunV2 = run_arm(
        boundary,
        pose,
        arm,
        MAXIMUM_OUTER_STEPS_PER_ARM,
        runtime_binding_sha256,
        |world: &PhysicsWorld, energy: &RapierEnergyExchangeSampleV1, semantic_step| {
            let exchange = collect_r24d52_rapier_discrete_staging_v1(
                world.physics_pipeline.sporespore_discrete_staging,
                previous_staging_sequence,
            )?;
            let increment =
                map_r24d52_recovery_energy_increment_v3(*energy, exchange, semantic_step)?;
            staging_records.push(compact_staging_record(
                world,
                *energy,
                exchange,
                increment,
                semantic_step,
            )?);
            increments.push(increment);
            previous_staging_sequence = exchange.sequence;
            Ok(())
        },
    )?;
    let observation_count = source.trace.observations.len();
    if observation_count == 0
        || observation_count != increments.len()
        || observation_count != staging_records.len()
        || previous_staging_sequence != observation_count as u64
    {
        return Err(format!(
            "QSDK_R24D54_STAGING_POPULATION_INVALID:{}",
            arm_id(arm)
        ));
    }

    let v2_trace_sha256 = digest_serializable(&source.trace).map_err(|error| error.to_string())?;
    let v2_step_receipts = source.arm_result["portable_step_receipts"]
        .as_array()
        .ok_or_else(|| "QSDK_R24D54_V2_STEP_RECEIPTS_MISSING".to_owned())?;
    let invariant_receipts = source.arm_result["invariant_receipts"]
        .as_array()
        .ok_or_else(|| "QSDK_R24D54_INVARIANT_RECEIPTS_MISSING".to_owned())?
        .clone();
    if v2_step_receipts.len() != observation_count || invariant_receipts.len() != observation_count
    {
        return Err("QSDK_R24D54_SOURCE_RECEIPT_POPULATION_INVALID".to_owned());
    }

    let mut observations_v3 = Vec::with_capacity(observation_count);
    let mut aggregation_receipts = Vec::with_capacity(observation_count);
    for (index, observation_v2) in source.trace.observations.iter().cloned().enumerate() {
        let aggregation =
            aggregate_recovery_energy_balance_v3(RecoveryEnergyBalanceAggregationRequestV3 {
                schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
                source_profile_id: R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID.to_owned(),
                initial_mechanical_energy_j: observation_v2
                    .energy_balance
                    .initial_mechanical_energy_j,
                current_mechanical_energy_j: observation_v2
                    .energy_balance
                    .current_mechanical_energy_j,
                ordered_increments: increments[..=index].to_vec(),
            })
            .map_err(|error| format!("QSDK_R24D54_V3_AGGREGATION:{error}"))?;
        if aggregation.increment_count != index + 1
            || aggregation.last_sequence_index != observation_v2.semantic_step
            || aggregation.last_semantic_step != observation_v2.semantic_step
            || aggregation.ledger.cumulative_applied_actuator_work_j
                != observation_v2
                    .energy_balance
                    .cumulative_applied_actuator_work_j
            || aggregation.ledger.cumulative_signed_external_work_j
                != observation_v2
                    .energy_balance
                    .cumulative_signed_external_work_j
            || aggregation.ledger.cumulative_signed_constraint_exchange_j
                != observation_v2
                    .energy_balance
                    .cumulative_signed_constraint_exchange_j
            || aggregation.ledger.cumulative_passive_dissipation_j
                != observation_v2
                    .energy_balance
                    .cumulative_passive_dissipation_j
            || aggregation.world_build_count != 0
            || aggregation.solver_step_count != 0
            || aggregation.physics_state_modified
            || aggregation.physical_acceptance_authority
            || aggregation.release_authority
        {
            return Err(format!(
                "QSDK_R24D54_V3_AGGREGATION_RECEIPT_INVALID:{}:{}",
                arm_id(arm),
                index + 1
            ));
        }
        aggregation_receipts.push(json!({
            "semantic_step": observation_v2.semantic_step,
            "increment_count": aggregation.increment_count,
            "ordered_source_values_sha256": aggregation.ordered_source_values_sha256,
            "ledger_sha256": aggregation.ledger_sha256,
            "signed_residual_j": aggregation.evaluation.signed_residual_j,
            "absolute_residual_j": aggregation.evaluation.absolute_residual_j,
            "threshold_applied": aggregation.evaluation.threshold_applied,
            "physical_result": aggregation.evaluation.physical_result,
        }));
        observations_v3.push(observation_v3_from_v2(observation_v2, aggregation.ledger));
    }

    let declared_initial_state_sha256 = initial_observation_sha256(&observations_v3[0])?;
    let trace = RecoveryTraceV3 {
        schema_version: RECOVERY_TRACE_V3_VERSION.to_owned(),
        arm_kind: arm,
        declared_initial_state_sha256: declared_initial_state_sha256.clone(),
        observations: observations_v3,
    };
    let trace_sha256 = digest_serializable(&trace).map_err(|error| error.to_string())?;

    let mut memory = initialize_arm_memory_v1(boundary, arm)?;
    let mut prefix_receipts = Vec::new();
    let mut terminal_prefix_observation_count = 0_usize;
    for (index, observation) in trace.observations.iter().cloned().enumerate() {
        let v2_receipt = &v2_step_receipts[index];
        let v3_receipt = step_recovery_v4(RecoveryStepRequestV4 {
            schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: boundary.morphology_context.clone(),
            adapter_capability: rapier_recovery_capability_v1(),
            memory,
            observation,
        })
        .map_err(|error| error.to_string())?;
        if v3_receipt.support_status != RecoverySupportStatusV1::SupportedExact
            || v3_receipt.refusal_reason.is_some()
            || v3_receipt.world_build_count != 0
            || v3_receipt.solver_step_count != 0
            || v3_receipt.physics_state_modified
            || v3_receipt.physical_acceptance_authority
            || v3_receipt.release_authority
        {
            return Err(format!(
                "QSDK_R24D54_V3_STEP_RECEIPT_INVALID:{}:{}",
                arm_id(arm),
                index + 1
            ));
        }
        let next_memory = v3_receipt
            .memory
            .clone()
            .ok_or_else(|| "QSDK_R24D54_V3_STEP_MEMORY_MISSING".to_owned())?;
        let terminal = matches!(
            next_memory.phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        );
        let v3_prior = serde_json::to_value(v3_receipt.prior_phase)
            .map_err(|error| format!("QSDK_R24D54_PHASE_SERIALIZE:{error}"))?;
        let v3_next = serde_json::to_value(v3_receipt.next_phase)
            .map_err(|error| format!("QSDK_R24D54_PHASE_SERIALIZE:{error}"))?;
        let prior_identical = v2_receipt["prior_phase"] == v3_prior;
        let next_identical = v2_receipt["next_phase"] == v3_next;
        if !prior_identical || (!terminal && !next_identical) {
            return Err(format!(
                "QSDK_R24D54_NONTERMINAL_PHASE_DIVERGENCE:{}:{}",
                arm_id(arm),
                index + 1
            ));
        }
        prefix_receipts.push(json!({
            "semantic_step": index + 1,
            "v2_prior_phase": v2_receipt["prior_phase"],
            "v2_next_phase": v2_receipt["next_phase"],
            "v3_prior_phase": v3_prior,
            "v3_next_phase": v3_next,
            "pre_terminal_phase_identity": prior_identical && (terminal || next_identical),
            "next_phase_identical": next_identical,
            "v3_terminal": terminal,
            "terminal_transition_divergence": terminal && !next_identical,
        }));
        terminal_prefix_observation_count = index + 1;
        memory = next_memory;
        if terminal {
            break;
        }
    }
    if terminal_prefix_observation_count == 0
        || !matches!(
            memory.phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        )
    {
        return Err(format!(
            "QSDK_R24D54_V3_TERMINAL_PREFIX_MISSING:{}",
            arm_id(arm)
        ));
    }

    #[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
    let terminal_prefix_trace =
        terminal_prefix_trace_v3(&trace, terminal_prefix_observation_count)?;

    let native_solver_step_count = source.arm_result["native_solver_step_count"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D54_NATIVE_SOLVER_STEP_COUNT".to_owned())?;
    let final_phase = memory.phase;
    let terminal_failure_code = memory.terminal_failure_code.clone();
    let result = json!({
        "schema_version": ARM_RESULT_SCHEMA,
        "gate_id": R24D54_GATE_ID,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "declared_initial_state_sha256": declared_initial_state_sha256,
        "trace_v3": trace,
        "trace_v3_sha256": trace_sha256,
        "source_trace_v2_sha256": v2_trace_sha256,
        "ordered_v3_increments": increments,
        "compact_staging_records": staging_records,
        "v3_prefix_aggregation_receipts": aggregation_receipts,
        "in_run_invariant_receipts": invariant_receipts,
        "v2_v3_phase_prefix_receipts": prefix_receipts,
        "pre_terminal_phase_identity": true,
        "pre_terminal_control_identity": true,
        "terminal_prefix_observation_count": terminal_prefix_observation_count,
        "captured_observation_count": observation_count,
        "final_phase_v3": final_phase,
        "terminal_failure_code_v3": terminal_failure_code,
        "native_solver_step_count": native_solver_step_count,
        "staging_record_count": observation_count,
        "v3_increment_count": observation_count,
        "in_run_invariant_receipt_count": invariant_receipts.len(),
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "post_initialization_intervention_count": 0,
        "physics_state_modified": true,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    Ok(R54ArmRun {
        trace,
        #[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
        terminal_prefix_trace,
        result,
    })
}

fn evaluate_paired_traces(
    boundary: &RapierRecoveryBoundaryV1,
    candidate: RecoveryTraceV3,
    matched_zero: RecoveryTraceV3,
) -> Result<RecoveryEvaluationReceiptV1, String> {
    evaluate_recovery_trace_v4(RecoveryEvaluationRequestV4 {
        schema_version: RECOVERY_EVALUATION_REQUEST_V4_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context: boundary.morphology_context.clone(),
        adapter_capability: rapier_recovery_capability_v1(),
        candidate_trace: candidate,
        matched_zero_command_trace: matched_zero,
    })
    .map_err(|error| error.to_string())
}

fn validate_pure_evaluation(evaluation: &RecoveryEvaluationReceiptV1) -> Result<(), String> {
    if evaluation.model_construction_count != 0
        || evaluation.world_attempt_count != 0
        || evaluation.world_build_count != 0
        || evaluation.solver_step_count != 0
        || evaluation.physics_state_modified
        || evaluation.physical_acceptance_authority
        || evaluation.release_authority
    {
        return Err("QSDK_R24D54_DEVELOPMENT_EVALUATION_INVALID".to_owned());
    }
    Ok(())
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn validate_r55_contract() -> Result<(Value, Value), String> {
    let contract: Value = serde_json::from_str(R55_CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R24D55_CONTRACT_PARSE:{error}"))?;
    let r54_closure: Value = serde_json::from_str(R54_INVALID_CLOSURE_RAW)
        .map_err(|error| format!("QSDK_R24D55_R54_CLOSURE_PARSE:{error}"))?;
    if contract["gate_id"] != R24D55_GATE_ID
        || contract["question_class"] != "development"
        || contract["physical_question_declared"] != true
        || contract["bound_predecessors"][0]["raw_sha256"]
            != raw_sha256(R54_INVALID_CLOSURE_RAW.as_bytes())
        || contract["controlled_change"]["controller_changed"] != false
        || contract["controlled_change"]["threshold_changed"] != false
        || contract["controlled_change"]["margin_changed"] != false
        || contract["controlled_change"]["evaluator_changed"] != false
        || contract["controlled_change"]["evaluator_input_population_projection_changed"] != true
        || contract["finite_development_population"]["cell_id"] != CELL_ID
        || contract["finite_development_population"]["cell_seed"] != CELL_SEED
        || contract["finite_development_population"]["arm_count"] != 2
        || contract["finite_development_population"]["maximum_outer_steps_per_arm"]
            != MAXIMUM_OUTER_STEPS_PER_ARM
        || contract["finite_development_population"]["maximum_total_outer_steps"]
            != MAXIMUM_TOTAL_OUTER_STEPS
        || contract["terminal_prefix_projection"]["complete_capture_retained"] != true
        || contract["terminal_prefix_projection"]["evaluator_input_is_exact_terminal_prefix"]
            != true
        || contract["terminal_prefix_projection"]["post_terminal_tail_excluded_from_evaluator"]
            != true
        || contract["complete_zero_world_gate"]["physical_execution_authorized"] != false
        || contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] != 0
        || r54_closure["closure_status"]
            != "closed_consumed_invalid_complete_evaluation_trace_population_included_post_terminal_candidate_tail"
        || r54_closure["decision"]["paired_development_attempt_consumed_for_exact_source"] != true
        || r54_closure["decision"]["physical_question_valid"] != false
        || r54_closure["decision"]["candidate_completion_promoted_to_prone_to_standing_claim"]
            != false
        || r54_closure["decision"]["same_source_or_identity_rerun_permitted"] != false
    {
        return Err("QSDK_R24D55_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok((contract, r54_closure))
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn r55_runtime_binding_projection_v1() -> Result<Value, String> {
    let (contract, _) = validate_r55_contract()?;
    let r54_preflight = run_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification()?;
    let r54_preflight_sha256 = digest_json(&r54_preflight)
        .map_err(|error| format!("QSDK_R24D55_R54_PREFLIGHT_DIGEST:{error}"))?;
    Ok(json!({
        "schema_version": R55_RUNTIME_BINDING_SCHEMA,
        "gate_id": R24D55_GATE_ID,
        "contract_raw_sha256": raw_sha256(R55_CONTRACT_RAW.as_bytes()),
        "r54_invalid_closure_raw_sha256": raw_sha256(R54_INVALID_CLOSURE_RAW.as_bytes()),
        "r54_zero_world_preflight_sha256": r54_preflight_sha256,
        "recovery_route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "staging_mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "observation_schema": RECOVERY_OBSERVATION_V3_VERSION,
        "trace_schema": RECOVERY_TRACE_V3_VERSION,
        "evaluation_request_schema": RECOVERY_EVALUATION_REQUEST_V4_VERSION,
        "threshold_profile_id": EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
        "evaluator_input_population": "exact_terminal_prefix_only",
        "complete_capture_retained": true,
        "maximum_outer_steps_per_arm": MAXIMUM_OUTER_STEPS_PER_ARM,
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "same_source_attempt_limit": 1,
        "development_requires_prior_ghost":
            contract["physical_runner"]["development_requires_prior_ghost"],
        "digest_algorithm": "sha256",
        "serialization_authority": "sporespore_locomotion_core::digest_json",
    }))
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn expected_r55_runtime_binding_sha256() -> Result<String, String> {
    digest_json(&r55_runtime_binding_projection_v1()?)
        .map_err(|error| format!("QSDK_R24D55_RUNTIME_BINDING_DIGEST:{error}"))
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn validate_r55_runtime_binding_sha256(observed: &str) -> Result<(), String> {
    if !valid_sha256(observed) {
        return Err("QSDK_R24D55_RUNTIME_BINDING_SHA_INVALID".to_owned());
    }
    let expected = expected_r55_runtime_binding_sha256()?;
    if observed != expected {
        return Err(format!(
            "QSDK_R24D55_RUNTIME_BINDING_SHA_MISMATCH:expected={expected}:observed={observed}"
        ));
    }
    Ok(())
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn r55_mutation_rejected(
    projection: &Value,
    field: &str,
    replacement: Value,
    expected: &str,
) -> Result<bool, String> {
    let mut mutated = projection.clone();
    mutated
        .as_object_mut()
        .ok_or_else(|| "QSDK_R24D55_PROJECTION_OBJECT".to_owned())?
        .insert(field.to_owned(), replacement);
    let digest = digest_json(&mutated)
        .map_err(|error| format!("QSDK_R24D55_MUTATION_DIGEST:{field}:{error}"))?;
    Ok(digest != expected && validate_r55_runtime_binding_sha256(&digest).is_err())
}

#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
fn r55_arm_projection(run: &R54ArmRun) -> Result<Value, String> {
    let captured_count = run.trace.observations.len();
    let evaluator_count = run.terminal_prefix_trace.observations.len();
    let recorded_count = run.result["terminal_prefix_observation_count"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D55_RECORDED_PREFIX_COUNT_MISSING".to_owned())?
        as usize;
    let captured_sha256 = digest_serializable(&run.trace).map_err(|error| error.to_string())?;
    let evaluator_sha256 =
        digest_serializable(&run.terminal_prefix_trace).map_err(|error| error.to_string())?;
    if evaluator_count == 0
        || evaluator_count != recorded_count
        || evaluator_count > captured_count
        || run.result["trace_v3_sha256"] != captured_sha256
    {
        return Err("QSDK_R24D55_TERMINAL_PREFIX_PROJECTION_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d55_rapier_terminal_prefix_arm_projection_v1",
        "gate_id": R24D55_GATE_ID,
        "complete_capture": run.result.clone(),
        "captured_observation_count": captured_count,
        "evaluator_observation_count": evaluator_count,
        "post_terminal_tail_observation_count": captured_count - evaluator_count,
        "captured_trace_v3_sha256": captured_sha256,
        "evaluator_terminal_prefix_trace_v3_sha256": evaluator_sha256,
        "evaluator_input_is_exact_terminal_prefix": true,
        "complete_capture_retained": true,
        "projection_world_build_count": 0,
        "projection_solver_step_count": 0,
        "projection_physics_state_modified": false,
    }))
}

/// Complete pure gate for the distinct R55 terminal-prefix successor.
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
pub fn run_qsdk_r24d55_rapier_terminal_prefix_recovery_zero_world_qualification()
-> Result<Value, String> {
    let (contract, r54_closure) = validate_r55_contract()?;
    let r54_preflight = run_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification()?;
    let projection = r55_runtime_binding_projection_v1()?;
    let runtime_binding_sha256 = digest_json(&projection)
        .map_err(|error| format!("QSDK_R24D55_RUNTIME_BINDING_DIGEST:{error}"))?;
    validate_r55_runtime_binding_sha256(&runtime_binding_sha256)?;

    let captured = vec![10_u64, 20, 30, 40];
    let prefix = project_terminal_prefix(&captured, 3)?;
    let invalid_counts_rejected = project_terminal_prefix(&captured, 0).is_err()
        && project_terminal_prefix(&captured, captured.len() + 1).is_err();
    let mutation_specs = [
        ("wrong_gate", "gate_id", json!("QSDK-R24D55-MUTATED")),
        (
            "wrong_r54_invalid_closure_digest",
            "r54_invalid_closure_raw_sha256",
            json!(format!("sha256:{}", "0".repeat(64))),
        ),
        (
            "wrong_projection_rule",
            "evaluator_input_population",
            json!("complete_capture"),
        ),
        (
            "wrong_observation_schema",
            "observation_schema",
            json!("sporespore_recovery_observation_v2"),
        ),
        (
            "wrong_step_budget",
            "maximum_total_outer_steps",
            json!(2401),
        ),
        ("wrong_attempt_limit", "same_source_attempt_limit", json!(2)),
    ];
    let mut mutations = Vec::new();
    for (mutation_id, field, replacement) in mutation_specs {
        if !r55_mutation_rejected(&projection, field, replacement, &runtime_binding_sha256)? {
            return Err(format!("QSDK_R24D55_MUTATION_ACCEPTED:{mutation_id}"));
        }
        mutations.push(json!({"mutation_id": mutation_id, "rejected": true}));
    }

    let controls = [
        r54_preflight["ok"] == true
            && r54_preflight["world_build_count"] == 0
            && r54_preflight["solver_step_count"] == 0,
        r54_closure["decision"]["paired_development_attempt_consumed_for_exact_source"] == true
            && r54_closure["decision"]["physical_question_valid"] == false
            && r54_closure["decision"]["candidate_completion_promoted_to_prone_to_standing_claim"]
                == false,
        projection["r54_invalid_closure_raw_sha256"]
            == contract["bound_predecessors"][0]["raw_sha256"],
        prefix == vec![10_u64, 20, 30],
        captured == vec![10_u64, 20, 30, 40],
        invalid_counts_rejected,
        projection["evaluator_input_population"] == "exact_terminal_prefix_only"
            && projection["complete_capture_retained"] == true,
        contract["complete_zero_world_gate"]["physical_execution_authorized"] == false
            && contract["complete_zero_world_gate"]["maximum_physical_steps_authorized"] == 0,
    ];
    if controls.iter().any(|value| !value) {
        return Err("QSDK_R24D55_ZERO_WORLD_CONTROL_FAILED".to_owned());
    }
    let mutation_ids = mutations
        .iter()
        .map(|value| value["mutation_id"].clone())
        .collect::<Vec<_>>();
    Ok(json!({
        "schema_version": R55_ZERO_WORLD_SCHEMA,
        "ok": true,
        "gate_id": R24D55_GATE_ID,
        "question_class": "development",
        "qualification_class": "zero_world_terminal_prefix_projection_route",
        "runtime_binding_projection": projection,
        "runtime_binding_sha256": runtime_binding_sha256,
        "runtime_binding_non_self_referential": true,
        "control_count": controls.len(),
        "controls_passed": controls.len(),
        "mutation_ids": mutation_ids,
        "mutation_rejections": mutations,
        "mutation_rejection_count": 6,
        "check_count": controls.len() + 6,
        "checks_passed": controls.len() + 6,
        "projection_fixture": {
            "captured": captured,
            "terminal_prefix_observation_count": 3,
            "evaluator_input": prefix,
            "complete_capture_unchanged": true,
            "invalid_counts_rejected": invalid_counts_rejected,
        },
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "r54_consumed_invalid_preserved": true,
        "complete_capture_retained": true,
        "evaluator_input_is_exact_terminal_prefix": true,
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

/// Execute the one prospectively declared finite paired R55 development attempt.
#[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
pub fn run_qsdk_r24d55_rapier_terminal_prefix_recovery_development_attempt(
    runtime_binding_sha256: &str,
) -> Result<Value, String> {
    validate_r55_runtime_binding_sha256(runtime_binding_sha256)?;
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_v3_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        runtime_binding_sha256,
    )?;
    let matched_zero = run_v3_arm(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        runtime_binding_sha256,
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
        || candidate
            .terminal_prefix_trace
            .declared_initial_state_sha256
            != matched_zero
                .terminal_prefix_trace
                .declared_initial_state_sha256
    {
        return Err("QSDK_R24D55_INITIAL_STATE_MISMATCH".to_owned());
    }
    let candidate_steps = candidate.trace.observations.len();
    let matched_zero_steps = matched_zero.trace.observations.len();
    let actual_total = candidate_steps + matched_zero_steps;
    if candidate_steps > MAXIMUM_OUTER_STEPS_PER_ARM as usize
        || matched_zero_steps > MAXIMUM_OUTER_STEPS_PER_ARM as usize
        || actual_total > MAXIMUM_TOTAL_OUTER_STEPS as usize
    {
        return Err("QSDK_R24D55_DEVELOPMENT_BUDGET_EXCEEDED".to_owned());
    }
    let candidate_projection = r55_arm_projection(&candidate)?;
    let matched_zero_projection = r55_arm_projection(&matched_zero)?;
    let candidate_evaluator_steps = candidate.terminal_prefix_trace.observations.len();
    let matched_zero_evaluator_steps = matched_zero.terminal_prefix_trace.observations.len();
    let evaluation = evaluate_paired_traces(
        &boundary,
        candidate.terminal_prefix_trace.clone(),
        matched_zero.terminal_prefix_trace.clone(),
    )?;
    validate_pure_evaluation(&evaluation)
        .map_err(|_| "QSDK_R24D55_DEVELOPMENT_EVALUATION_INVALID".to_owned())?;
    let candidate_replay = evaluation
        .candidate_trace
        .as_ref()
        .ok_or_else(|| "QSDK_R24D55_CANDIDATE_REPLAY_MISSING".to_owned())?;
    let matched_zero_replay = evaluation
        .matched_zero_command_trace
        .as_ref()
        .ok_or_else(|| "QSDK_R24D55_MATCHED_ZERO_REPLAY_MISSING".to_owned())?;
    if candidate_replay.observation_count != candidate_evaluator_steps
        || candidate_replay.accepted_observation_count != candidate_evaluator_steps
        || matched_zero_replay.observation_count != matched_zero_evaluator_steps
        || matched_zero_replay.accepted_observation_count != matched_zero_evaluator_steps
    {
        return Err("QSDK_R24D55_EVALUATOR_PREFIX_POPULATION_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": R55_DEVELOPMENT_RESULT_SCHEMA,
        "ok": true,
        "gate_id": R24D55_GATE_ID,
        "question_class": "development",
        "runtime_binding_sha256": runtime_binding_sha256,
        "route_id": RAPIER_R24D48_RECOVERY_ROUTE_ID,
        "mapping_profile_id": R24D52_STAGING_LEDGER_MAPPING_PROFILE_ID,
        "cell_id": CELL_ID,
        "cell_seed": CELL_SEED,
        "candidate": candidate_projection,
        "matched_zero_command": matched_zero_projection,
        "evaluation": evaluation,
        "candidate_outer_steps": candidate_steps,
        "matched_zero_outer_steps": matched_zero_steps,
        "actual_total_outer_steps": actual_total,
        "candidate_evaluator_observation_count": candidate_evaluator_steps,
        "matched_zero_evaluator_observation_count": matched_zero_evaluator_steps,
        "maximum_outer_steps_per_arm": MAXIMUM_OUTER_STEPS_PER_ARM,
        "maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
        "complete_native_capture_retained": true,
        "evaluator_input_is_exact_terminal_prefix": true,
        "post_terminal_observations_excluded_from_evaluator": true,
        "projection_world_build_count": 0,
        "projection_solver_step_count": 0,
        "projection_physics_state_modified": false,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "result_may_satisfy_r24d55": true,
        "prone_to_standing_claimed": evaluation.prone_to_standing_claimed,
        "repeatability_rate_claimed": false,
        "population_claimed": false,
        "cross_engine_recovery_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_world_binding_is_exact_and_nonphysical() {
        let receipt = run_qsdk_r24d54_rapier_recovery_energy_v3_zero_world_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["check_count"], 15);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert_eq!(receipt["v3_staging_consumed_by_evaluator"], true);
    }

    #[test]
    fn malformed_runtime_binding_refuses_before_world() {
        assert!(
            run_qsdk_r24d54_rapier_recovery_energy_v3_development_attempt("not-a-digest").is_err()
        );
    }

    #[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
    #[test]
    fn r24d55_terminal_prefix_projection_trims_without_mutating_capture() {
        let captured = vec![1_u64, 2, 3, 4];
        let projected = project_terminal_prefix(&captured, 3).unwrap();
        assert_eq!(projected, vec![1_u64, 2, 3]);
        assert_eq!(captured, vec![1_u64, 2, 3, 4]);
    }

    #[cfg(feature = "sporespore-rapier-r24d55-terminal-prefix-recovery")]
    #[test]
    fn r24d55_terminal_prefix_projection_refuses_invalid_counts() {
        let captured = vec![1_u64, 2, 3];
        assert!(project_terminal_prefix(&captured, 0).is_err());
        assert!(project_terminal_prefix(&captured, 4).is_err());
    }
}
