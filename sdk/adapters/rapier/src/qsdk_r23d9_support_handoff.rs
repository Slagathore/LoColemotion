//! Rapier/Parry temporal mirror and dormant physical route for QSDK-R23D9.
//!
//! This module composes the qualified R23D8 neutral-stance preflight with an
//! independent Rust implementation of the frozen R23D9 handoff state machine.
//! The real Rapier world loop lives beside the already-qualified native fixture
//! helpers and is unreachable without source-exact supervisor authorization.

use serde_json::{Value, json};

use crate::qsdk_r23d3_phase_balanced::{
    run_qsdk_r23d8_rapier_preflight, run_qsdk_r23d9_rapier_authorization_preflight_impl,
    run_qsdk_r23d9_rapier_physical_impl,
};

const DECLARATION_RAW: &str =
    include_str!("../../../turning/r23d9_support_handoff_preregistration_v1.json");
const CAMPAIGN_ID: &str =
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-BILATERAL-TURN-DEVELOPMENT";
const GATE_ID: &str = "QSDK-R23D9";
const ENGINE_ID: &str = "rapier_parry";
const POLICY_ID: &str = "sporespore_support_confirmed_irreversible_passive_handoff_v1";
const ACTIVE_POLICY_ID: &str = "sporespore_morphology_neutral_stance_bounded_pd_v1";
const PREFLIGHT_SCHEMA: &str = "sporespore_qsdk_r23d9_rapier_worker_preflight_v1";
const TERMINAL_STEPS: u64 = 780;
const CONTROLLER_STEPS: u64 = 2_992;
const TOTAL_TRACE_STEPS: u64 = CONTROLLER_STEPS + TERMINAL_STEPS;
const MAXIMUM_ACTIVE_STEPS: u64 = 420;
const SUPPORT_CONFIRMATION_STEPS: u64 = 30;
const MINIMUM_PASSIVE_STEPS: u64 = 360;
const ACTUATOR_COUNT: u64 = 8;
const ACTIVE_MODE: &str = "active_neutral_acquisition";
const PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const SUPPORT_REASON: &str = "support_confirmed";
const DEADLINE_REASON: &str = "deadline_forced_without_support_confirmation";

#[derive(Clone, Debug, PartialEq, Eq)]
struct Cell {
    stage_id: String,
    cell_id: String,
    arm_id: String,
    heading_offset_microrad: i64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct State {
    next_step: u64,
    active: bool,
    support_counter: u64,
    handoff_after: Option<u64>,
    first_passive: Option<u64>,
    reason: Option<&'static str>,
    support_confirmed: bool,
    active_steps: u64,
    passive_steps: u64,
    active_applications: u64,
    passive_applications: u64,
    first_loss: Option<u64>,
    loss_count: u64,
}

impl Default for State {
    fn default() -> Self {
        Self {
            next_step: 0,
            active: true,
            support_counter: 0,
            handoff_after: None,
            first_passive: None,
            reason: None,
            support_confirmed: false,
            active_steps: 0,
            passive_steps: 0,
            active_applications: 0,
            passive_applications: 0,
            first_loss: None,
            loss_count: 0,
        }
    }
}

fn cell(stage_id: &str, arm_id: &str) -> Result<Cell, String> {
    let allowed: &[&str] = match stage_id {
        "three_engine_confirmation" => &["reference_zero", "positive_heading", "negative_heading"],
        _ => return Err(format!("QSDK_R23D9_RAP_STAGE_UNKNOWN:{stage_id}")),
    };
    if !allowed.contains(&arm_id) {
        return Err(format!("QSDK_R23D9_RAP_ARM_UNKNOWN:{arm_id}"));
    }
    let heading_offset_microrad = match arm_id {
        "reference_zero" => 0,
        "positive_heading" => 200_000,
        "negative_heading" => -200_000,
        _ => unreachable!("arm identity checked above"),
    };
    Ok(Cell {
        stage_id: stage_id.to_owned(),
        cell_id: format!("{ENGINE_ID}__support_handoff__{arm_id}"),
        arm_id: arm_id.to_owned(),
        heading_offset_microrad,
    })
}

fn contract() -> Result<Value, String> {
    let declaration: Value = serde_json::from_str(DECLARATION_RAW)
        .map_err(|error| format!("QSDK_R23D9_RAP_DECLARATION_JSON:{error}"))?;
    let schedule = &declaration["frozen_schedule_and_gate_snapshot"];
    let machine = &declaration["handoff_state_machine_contract"];
    let exact = declaration["schema_version"]
        == "sporespore_qsdk_r23d9_support_handoff_preregistration_v1"
        && declaration["campaign_id"] == CAMPAIGN_ID
        && declaration["gate_id"] == GATE_ID
        && schedule["turning_controller_semantic_step_count"] == CONTROLLER_STEPS
        && schedule["terminal_support_handoff_step_count"] == TERMINAL_STEPS
        && schedule["maximum_active_neutral_acquisition_steps"] == MAXIMUM_ACTIVE_STEPS
        && schedule["support_confirmation_step_count"] == SUPPORT_CONFIRMATION_STEPS
        && schedule["minimum_post_handoff_zero_actuation_steps"] == MINIMUM_PASSIVE_STEPS
        && schedule["total_traced_step_count"] == TOTAL_TRACE_STEPS
        && machine["initial_mode"] == ACTIVE_MODE
        && machine["passive_mode"] == PASSIVE_MODE
        && machine["transition_is_applied_to_next_step"] == true
        && machine["mode_reactivation_permitted"] == false
        && declaration["authorization"]["physical_execution_authorized"] == false;
    if !exact {
        return Err("QSDK_R23D9_RAP_DECLARATION_IDENTITY_INVALID".to_owned());
    }
    Ok(declaration)
}

fn observe(
    state: &State,
    contacts: [bool; 4],
    applications: u64,
) -> Result<(State, Value), String> {
    if state.next_step >= TERMINAL_STEPS {
        return Err("QSDK_R23D9_RAP_STEP_OUTSIDE_HORIZON".to_owned());
    }
    let expected_applications = if state.active { ACTUATOR_COUNT } else { 0 };
    if applications != expected_applications {
        return Err("QSDK_R23D9_RAP_APPLICATION_COUNT_MISMATCH".to_owned());
    }
    let mode = if state.active {
        ACTIVE_MODE
    } else {
        PASSIVE_MODE
    };
    let all_four = contacts.into_iter().all(|present| present);
    let mut next = state.clone();
    let pre_counter = state.support_counter;
    let mut transitioned = false;
    next.next_step += 1;
    if state.active {
        next.active_steps += 1;
        next.active_applications += applications;
        next.support_counter = if all_four {
            state.support_counter + 1
        } else {
            0
        };
        if next.support_counter >= SUPPORT_CONFIRMATION_STEPS {
            next.active = false;
            next.handoff_after = Some(state.next_step);
            next.first_passive = Some(state.next_step + 1);
            next.reason = Some(SUPPORT_REASON);
            next.support_confirmed = true;
            transitioned = true;
        } else if state.next_step == MAXIMUM_ACTIVE_STEPS - 1 {
            next.active = false;
            next.handoff_after = Some(state.next_step);
            next.first_passive = Some(state.next_step + 1);
            next.reason = Some(DEADLINE_REASON);
            next.support_confirmed = false;
            transitioned = true;
        } else if state.next_step >= MAXIMUM_ACTIVE_STEPS {
            return Err("QSDK_R23D9_RAP_ACTIVE_AFTER_DEADLINE".to_owned());
        }
    } else {
        next.passive_steps += 1;
        next.passive_applications += applications;
        if !all_four {
            next.loss_count += 1;
            if next.first_loss.is_none() {
                next.first_loss = Some(state.next_step);
            }
        }
    }
    let receipt = json!({
        "step": state.next_step,
        "mode": mode,
        "all_four_contacts": all_four,
        "pre_step_support_counter": pre_counter,
        "post_step_support_counter": next.support_counter,
        "native_application_count": applications,
        "transition_after_step": transitioned,
        "next_mode": if next.active { ACTIVE_MODE } else { PASSIVE_MODE },
        "handoff_reason": if transitioned { next.reason } else { None::<&str> },
    });
    Ok((next, receipt))
}

fn outcome(state: &State) -> Result<Value, String> {
    if state.next_step != TERMINAL_STEPS {
        return Err("QSDK_R23D9_RAP_OUTCOME_BEFORE_HORIZON".to_owned());
    }
    let passed = state.support_confirmed
        && state.reason == Some(SUPPORT_REASON)
        && state.first_passive.is_some_and(|step| {
            (SUPPORT_CONFIRMATION_STEPS..=MAXIMUM_ACTIVE_STEPS).contains(&step)
        })
        && state.passive_steps >= MINIMUM_PASSIVE_STEPS
        && state.passive_applications == 0
        && state.loss_count == 0
        && !state.active;
    Ok(json!({
        "terminal_step_count": state.next_step,
        "handoff_after_active_step": state.handoff_after,
        "first_passive_step": state.first_passive,
        "handoff_reason": state.reason,
        "support_confirmed": state.support_confirmed,
        "active_step_count": state.active_steps,
        "passive_step_count": state.passive_steps,
        "active_native_application_count": state.active_applications,
        "passive_native_application_count": state.passive_applications,
        "first_post_handoff_contact_loss_step": state.first_loss,
        "post_handoff_contact_loss_step_count": state.loss_count,
        "irreversible_handoff_gate_passed": passed,
    }))
}

fn rows(segments: &[(usize, [bool; 4])]) -> Result<Vec<[bool; 4]>, String> {
    let mut result = Vec::new();
    for (count, contacts) in segments {
        result.extend(std::iter::repeat_n(*contacts, *count));
    }
    if result.len() != TERMINAL_STEPS as usize {
        return Err("QSDK_R23D9_RAP_CANARY_HORIZON_INVALID".to_owned());
    }
    Ok(result)
}

fn simulate(contact_rows: &[[bool; 4]]) -> Result<(Vec<Value>, Value), String> {
    if contact_rows.len() != TERMINAL_STEPS as usize {
        return Err("QSDK_R23D9_RAP_CONTACT_HORIZON_INVALID".to_owned());
    }
    let mut state = State::default();
    let mut receipts = Vec::with_capacity(contact_rows.len());
    for contacts in contact_rows {
        let applications = if state.active { ACTUATOR_COUNT } else { 0 };
        let (next, receipt) = observe(&state, *contacts, applications)?;
        state = next;
        receipts.push(receipt);
    }
    Ok((receipts, outcome(&state)?))
}

fn replay_valid(rows: &[[bool; 4]], receipts: &[Value], reported: &Value) -> bool {
    simulate(rows).is_ok_and(|(expected_receipts, expected)| {
        expected_receipts == receipts && expected == *reported
    })
}

fn canaries() -> Result<Value, String> {
    let down = [false; 4];
    let partial = [true, true, true, false];
    let supported = [true; 4];
    let cases = [
        (
            "support_from_first_step",
            rows(&[(780, supported)])?,
            29,
            30,
            true,
            750,
            0,
        ),
        (
            "predecessor_shaped_transients",
            rows(&[
                (100, down),
                (23, supported),
                (1, partial),
                (16, supported),
                (1, partial),
                (159, down),
                (480, supported),
            ])?,
            329,
            330,
            true,
            450,
            0,
        ),
        (
            "confirmation_at_deadline",
            rows(&[(390, down), (390, supported)])?,
            419,
            420,
            true,
            360,
            0,
        ),
        (
            "never_confirmed",
            rows(&[(780, down)])?,
            419,
            420,
            false,
            360,
            360,
        ),
        (
            "post_handoff_contact_loss",
            rows(&[
                (30, supported),
                (10, supported),
                (1, partial),
                (739, supported),
            ])?,
            29,
            30,
            false,
            750,
            1,
        ),
    ];
    let mut result = serde_json::Map::new();
    for (name, rows, after, first, passed, passive, losses) in cases {
        let (receipts, observed) = simulate(&rows)?;
        let exact = replay_valid(&rows, &receipts, &observed)
            && observed["handoff_after_active_step"] == after
            && observed["first_passive_step"] == first
            && observed["irreversible_handoff_gate_passed"] == passed
            && observed["passive_step_count"] == passive
            && observed["post_handoff_contact_loss_step_count"] == losses;
        if !exact {
            return Err(format!("QSDK_R23D9_RAP_CANARY_FAILED:{name}"));
        }
        result.insert(name.to_owned(), observed);
    }
    Ok(Value::Object(result))
}

fn mutations() -> Result<Value, String> {
    let down = [false; 4];
    let partial = [true, true, true, false];
    let supported = [true; 4];
    let sequence = rows(&[
        (100, down),
        (23, supported),
        (1, partial),
        (16, supported),
        (1, partial),
        (159, down),
        (480, supported),
    ])?;
    let (receipts, observed) = simulate(&sequence)?;
    let mut cases: Vec<(&str, Vec<Value>, Value)> = Vec::new();
    let mutate_receipt = |index: usize, key: &str, value: Value| {
        let mut changed = receipts.clone();
        changed[index][key] = value;
        (changed, observed.clone())
    };
    let (changed, report) = mutate_receipt(100, "transition_after_step", json!(true));
    cases.push(("transitioned_after_one_contact_step", changed, report));
    let (changed, report) = mutate_receipt(328, "transition_after_step", json!(true));
    cases.push((
        "transitioned_after_twenty_nine_contact_steps",
        changed,
        report,
    ));
    let (changed, report) = mutate_receipt(123, "post_step_support_counter", json!(23));
    cases.push(("did_not_reset_counter_on_contact_loss", changed, report));
    let (changed, report) = mutate_receipt(123, "all_four_contacts", json!(true));
    cases.push(("counted_partial_contact_as_all_four", changed, report));
    let (changed, report) = mutate_receipt(329, "mode", json!(PASSIVE_MODE));
    cases.push((
        "applied_transition_to_confirming_step_instead_of_next_step",
        changed,
        report,
    ));
    let (changed, report) = mutate_receipt(400, "mode", json!(ACTIVE_MODE));
    cases.push((
        "reactivated_after_post_handoff_contact_loss",
        changed,
        report,
    ));
    let (changed, report) = mutate_receipt(400, "native_application_count", json!(ACTUATOR_COUNT));
    cases.push(("applied_native_actuation_after_handoff", changed, report));
    let mut changed_outcome = observed.clone();
    changed_outcome["handoff_after_active_step"] = json!(418);
    changed_outcome["first_passive_step"] = json!(419);
    cases.push((
        "forced_deadline_before_420_active_steps",
        receipts.clone(),
        changed_outcome,
    ));
    let (changed, report) = mutate_receipt(420, "mode", json!(ACTIVE_MODE));
    cases.push(("allowed_active_step_after_deadline", changed, report));
    let mut forced_pass = observed.clone();
    forced_pass["handoff_reason"] = json!(DEADLINE_REASON);
    forced_pass["support_confirmed"] = json!(false);
    forced_pass["irreversible_handoff_gate_passed"] = json!(true);
    cases.push((
        "allowed_deadline_forced_handoff_to_pass",
        receipts.clone(),
        forced_pass,
    ));
    cases.push((
        "stopped_outcome_execution_early",
        receipts[..receipts.len() - 1].to_vec(),
        observed.clone(),
    ));
    let mut changed_horizon = observed.clone();
    changed_horizon["terminal_step_count"] = json!(779);
    cases.push((
        "changed_total_terminal_horizon",
        receipts.clone(),
        changed_horizon,
    ));

    let mut result = serde_json::Map::new();
    for (name, changed_receipts, changed_outcome) in cases {
        if replay_valid(&sequence, &changed_receipts, &changed_outcome) {
            return Err(format!("QSDK_R23D9_RAP_MUTATION_ESCAPED:{name}"));
        }
        result.insert(name.to_owned(), json!("rejected"));
    }
    Ok(Value::Object(result))
}

pub fn run_qsdk_r23d9_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    let declaration = contract()?;
    let cell = cell(stage_id, arm_id)?;
    let inherited = run_qsdk_r23d8_rapier_preflight("three_engine_confirmation", arm_id)?;
    let canaries = canaries()?;
    let mutations = mutations()?;
    if inherited["model_construction_count"] != 0
        || inherited["world_attempt_count"] != 0
        || inherited["world_build_count"] != 0
        || inherited["fixed_controller_horizon_step_count"] != CONTROLLER_STEPS
        || inherited["neutral_stance_algebra_canary_count"] != 5
        || canaries.as_object().map_or(0, |value| value.len()) != 5
        || mutations.as_object().map_or(0, |value| value.len()) != 12
        || declaration["required_oracle_canaries"]
            != json!([
                "support_from_first_step",
                "predecessor_shaped_transients",
                "confirmation_at_deadline",
                "never_confirmed",
                "post_handoff_contact_loss"
            ])
    {
        return Err("QSDK_R23D9_RAP_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "arm_id": cell.arm_id,
        "turn_heading_offset_rad": cell.heading_offset_microrad as f64 / 1_000_000.0,
        "terminal_policy_id": POLICY_ID,
        "active_acquisition_policy_id": ACTIVE_POLICY_ID,
        "fixed_controller_horizon_step_count": CONTROLLER_STEPS,
        "fixed_terminal_handoff_step_count": TERMINAL_STEPS,
        "fixed_total_trace_step_count": TOTAL_TRACE_STEPS,
        "maximum_active_neutral_acquisition_step_count": MAXIMUM_ACTIVE_STEPS,
        "support_confirmation_step_count": SUPPORT_CONFIRMATION_STEPS,
        "minimum_post_handoff_zero_actuation_step_count": MINIMUM_PASSIVE_STEPS,
        "neutral_stance_algebra_canary_count":
            inherited["neutral_stance_algebra_canary_count"],
        "neutral_stance_mutation_control_count":
            inherited["neutral_stance_mutation_control_count"],
        "support_handoff_oracle_canary_count": 5,
        "support_handoff_mutation_control_count": 12,
        "native_temporal_mirror": true,
        "transition_applies_to_following_step": true,
        "handoff_is_irreversible": true,
        "post_handoff_native_actuation_permitted": false,
        "physical_worker_implemented": true,
        "physical_worker_dormant_behind_supervisor_authorization": true,
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_qsdk_r23d9_rapier_authorization_preflight(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let _cell = cell(stage_id, arm_id)?;
    run_qsdk_r23d9_rapier_authorization_preflight_impl(stage_id, arm_id, source_commit)
}

pub fn run_qsdk_r23d9_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    if let Err(code) = cell(stage_id, arm_id) {
        return Err(json!({
            "schema_version": "sporespore_qsdk_r23d9_worker_failure_v1",
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": ENGINE_ID,
            "arm_id": arm_id,
            "turn_heading_offset_rad": Value::Null,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": Value::Null,
            "claims": false_claims(),
        }));
    }
    run_qsdk_r23d9_rapier_physical_impl(stage_id, arm_id, source_commit)
}

fn false_claims() -> Value {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_declared_rapier_routes_are_zero_world() {
        for arm in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt = run_qsdk_r23d9_rapier_preflight("three_engine_confirmation", arm)
                .expect("R23D9 Rapier preflight");
            assert_eq!(receipt["support_handoff_oracle_canary_count"], 5);
            assert_eq!(receipt["support_handoff_mutation_control_count"], 12);
            assert_eq!(receipt["physical_worker_implemented"], true);
            assert_eq!(
                receipt["physical_worker_dormant_behind_supervisor_authorization"],
                true
            );
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
        }
    }

    #[test]
    fn invalid_source_refuses_before_world() {
        let receipt = run_qsdk_r23d9_rapier_physical(
            "three_engine_confirmation",
            "positive_heading",
            "invalid",
        )
        .expect_err("R23D9 invalid source must fail closed");
        assert_eq!(receipt["failure_stage"], "before_world");
        assert_eq!(
            receipt["failure_code"],
            "QSDK_R23D9_RAP_SOURCE_COMMIT_INVALID"
        );
        assert_eq!(receipt["world_attempt_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
    }
}
