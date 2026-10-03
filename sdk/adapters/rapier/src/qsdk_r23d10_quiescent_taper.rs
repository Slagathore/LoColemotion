//! Independent Rapier/Rust temporal mirror for prospective QSDK-R23D10.
//!
//! This module contains no Rapier world construction.  It transcribes the
//! frozen terminal scheduler in Rust and proves its canaries before any future
//! physical worker is allowed to exist.

use serde_json::{Value, json};

use crate::qsdk_r23d3_phase_balanced::{
    run_qsdk_r23d10_rapier_authorization_preflight_impl, run_qsdk_r23d10_rapier_physical_impl,
};

const CAMPAIGN_ID: &str =
    "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT";
pub(crate) const TERMINAL_STEPS: usize = 900;
pub(crate) const MAXIMUM_ACTIVE_STEPS: usize = 540;
pub(crate) const MINIMUM_TAPER_STEPS: usize = 120;
pub(crate) const MINIMUM_PASSIVE_STEPS: usize = 360;
pub(crate) const ACTUATOR_COUNT: usize = 8;
pub(crate) const SCALE_DENOMINATOR: usize = 120;
pub(crate) const COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
pub(crate) const COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
pub(crate) const TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
pub(crate) const TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Mode {
    Active,
    Taper,
    Passive,
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct Observation {
    pub(crate) contacts: [bool; 4],
    pub(crate) torso_tilt_rad: f64,
    pub(crate) maximum_joint_error_rad: f64,
}

#[derive(Clone, Debug)]
pub(crate) struct State {
    pub(crate) next_step: usize,
    pub(crate) mode: Mode,
    pub(crate) taper_step_count: usize,
    pub(crate) confirmation_satisfied: bool,
    pub(crate) handoff_after_active_step: Option<usize>,
    pub(crate) first_passive_step: Option<usize>,
    pub(crate) deadline_handoff: bool,
    pub(crate) active_step_count: usize,
    pub(crate) passive_step_count: usize,
    pub(crate) active_native_application_count: usize,
    pub(crate) passive_native_application_count: usize,
    pub(crate) taper_reset_count: usize,
    pub(crate) first_post_handoff_contact_loss_step: Option<usize>,
    pub(crate) post_handoff_contact_loss_step_count: usize,
}

impl Default for State {
    fn default() -> Self {
        Self {
            next_step: 0,
            mode: Mode::Active,
            taper_step_count: 0,
            confirmation_satisfied: false,
            handoff_after_active_step: None,
            first_passive_step: None,
            deadline_handoff: false,
            active_step_count: 0,
            passive_step_count: 0,
            active_native_application_count: 0,
            passive_native_application_count: 0,
            taper_reset_count: 0,
            first_post_handoff_contact_loss_step: None,
            post_handoff_contact_loss_step_count: 0,
        }
    }
}

#[derive(Clone, Debug)]
pub(crate) struct Outcome {
    pub(crate) mode: Mode,
    pub(crate) confirmation_satisfied: bool,
    pub(crate) handoff_after_active_step: Option<usize>,
    pub(crate) first_passive_step: Option<usize>,
    pub(crate) active_step_count: usize,
    pub(crate) passive_step_count: usize,
    pub(crate) active_native_application_count: usize,
    pub(crate) passive_native_application_count: usize,
    pub(crate) taper_reset_count: usize,
    pub(crate) first_post_handoff_contact_loss_step: Option<usize>,
    pub(crate) post_handoff_contact_loss_step_count: usize,
    pub(crate) passed: bool,
}

fn validate_observation(observation: Observation) -> Result<(), String> {
    if !observation.torso_tilt_rad.is_finite()
        || observation.torso_tilt_rad < 0.0
        || !observation.maximum_joint_error_rad.is_finite()
        || observation.maximum_joint_error_rad < 0.0
    {
        return Err("R23D10_OBSERVATION_NUMERIC_VALUE_INVALID".to_owned());
    }
    Ok(())
}

fn all_four(observation: Observation) -> bool {
    observation.contacts.into_iter().all(|contact| contact)
}

pub(crate) fn coarse(observation: Observation) -> bool {
    all_four(observation)
        && observation.torso_tilt_rad <= COARSE_MAXIMUM_TILT_RAD
        && observation.maximum_joint_error_rad <= COARSE_MAXIMUM_JOINT_ERROR_RAD
}

pub(crate) fn tight(observation: Observation) -> bool {
    all_four(observation)
        && observation.torso_tilt_rad <= TIGHT_MAXIMUM_TILT_RAD
        && observation.maximum_joint_error_rad <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
}

pub(crate) fn expected_scale(state: &State) -> (usize, usize) {
    match state.mode {
        Mode::Active => (SCALE_DENOMINATOR, SCALE_DENOMINATOR),
        Mode::Taper => (
            (MINIMUM_TAPER_STEPS - state.taper_step_count).max(1),
            SCALE_DENOMINATOR,
        ),
        Mode::Passive => (0, SCALE_DENOMINATOR),
    }
}

fn handoff(mut state: State, step: usize, confirmed: bool) -> State {
    state.mode = Mode::Passive;
    state.confirmation_satisfied = confirmed;
    state.handoff_after_active_step = Some(step);
    state.first_passive_step = Some(step + 1);
    state.deadline_handoff = !confirmed;
    state
}

pub(crate) fn observe_completed_step(
    state: State,
    observation: Observation,
    native_application_count: usize,
    velocity_scale_numerator: usize,
    velocity_scale_denominator: usize,
) -> Result<State, String> {
    if state.next_step >= TERMINAL_STEPS {
        return Err("R23D10_STEP_OUTSIDE_HORIZON".to_owned());
    }
    validate_observation(observation)?;
    if expected_scale(&state) != (velocity_scale_numerator, velocity_scale_denominator) {
        return Err("R23D10_VELOCITY_SCALE_MISMATCH".to_owned());
    }
    let expected_applications = if state.mode == Mode::Passive {
        0
    } else {
        ACTUATOR_COUNT
    };
    if native_application_count != expected_applications {
        return Err("R23D10_APPLICATION_COUNT_MISMATCH".to_owned());
    }

    let step = state.next_step;
    let pre_mode = state.mode;
    let pre_taper_count = state.taper_step_count;
    let mut next = state;
    next.next_step += 1;
    if pre_mode != Mode::Passive {
        next.active_step_count += 1;
        next.active_native_application_count += native_application_count;
        if pre_mode == Mode::Active {
            if step == MAXIMUM_ACTIVE_STEPS - 1 {
                next = handoff(next, step, false);
            } else if coarse(observation) {
                next.mode = Mode::Taper;
                next.taper_step_count = 0;
            }
        } else if coarse(observation) {
            next.taper_step_count = (pre_taper_count + 1).min(MINIMUM_TAPER_STEPS);
            if next.taper_step_count >= MINIMUM_TAPER_STEPS && tight(observation) {
                next = handoff(next, step, true);
            } else if step == MAXIMUM_ACTIVE_STEPS - 1 {
                next = handoff(next, step, false);
            }
        } else if step == MAXIMUM_ACTIVE_STEPS - 1 {
            next = handoff(next, step, false);
        } else {
            next.mode = Mode::Active;
            next.taper_step_count = 0;
            next.taper_reset_count += 1;
        }
    } else {
        next.passive_step_count += 1;
        next.passive_native_application_count += native_application_count;
        if !all_four(observation) {
            next.post_handoff_contact_loss_step_count += 1;
            if next.first_post_handoff_contact_loss_step.is_none() {
                next.first_post_handoff_contact_loss_step = Some(step);
            }
        }
    }
    Ok(next)
}

pub(crate) fn outcome(state: &State) -> Result<Outcome, String> {
    if state.next_step != TERMINAL_STEPS {
        return Err("R23D10_OUTCOME_BEFORE_HORIZON".to_owned());
    }
    let passed = state.confirmation_satisfied
        && !state.deadline_handoff
        && state
            .first_passive_step
            .is_some_and(|step| step <= MAXIMUM_ACTIVE_STEPS)
        && state.passive_step_count >= MINIMUM_PASSIVE_STEPS
        && state.passive_native_application_count == 0
        && state.post_handoff_contact_loss_step_count == 0
        && state.mode == Mode::Passive;
    Ok(Outcome {
        mode: state.mode,
        confirmation_satisfied: state.confirmation_satisfied,
        handoff_after_active_step: state.handoff_after_active_step,
        first_passive_step: state.first_passive_step,
        active_step_count: state.active_step_count,
        passive_step_count: state.passive_step_count,
        active_native_application_count: state.active_native_application_count,
        passive_native_application_count: state.passive_native_application_count,
        taper_reset_count: state.taper_reset_count,
        first_post_handoff_contact_loss_step: state.first_post_handoff_contact_loss_step,
        post_handoff_contact_loss_step_count: state.post_handoff_contact_loss_step_count,
        passed,
    })
}

fn simulate(observations: &[Observation]) -> Result<Outcome, String> {
    if observations.len() != TERMINAL_STEPS {
        return Err("R23D10_OBSERVATION_HORIZON_INVALID".to_owned());
    }
    let mut state = State::default();
    for observation in observations {
        let (numerator, denominator) = expected_scale(&state);
        let applications = if state.mode == Mode::Passive {
            0
        } else {
            ACTUATOR_COUNT
        };
        state = observe_completed_step(state, *observation, applications, numerator, denominator)?;
    }
    outcome(&state)
}

const TIGHT: Observation = Observation {
    contacts: [true, true, true, true],
    torso_tilt_rad: 0.005,
    maximum_joint_error_rad: 0.18,
};
const PARTIAL_TIGHT: Observation = Observation {
    contacts: [true, true, true, false],
    torso_tilt_rad: 0.005,
    maximum_joint_error_rad: 0.18,
};
const COARSE_ONLY: Observation = Observation {
    contacts: [true, true, true, true],
    torso_tilt_rad: 0.03,
    maximum_joint_error_rad: 0.30,
};

fn require(condition: bool, code: &str) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(code.to_owned())
    }
}

fn run_canaries() -> Result<usize, String> {
    let first = simulate(&vec![TIGHT; TERMINAL_STEPS])?;
    require(
        first.passed && first.handoff_after_active_step == Some(120),
        "R23D10_RAP_CANARY_FIRST",
    )?;
    require(
        first.confirmation_satisfied
            && first.first_passive_step == Some(121)
            && first.active_step_count == 121,
        "R23D10_RAP_CANARY_FIRST_COUNTS",
    )?;

    let mut delayed = vec![PARTIAL_TIGHT; 313];
    delayed.extend(vec![TIGHT; 587]);
    let delayed = simulate(&delayed)?;
    require(
        delayed.passed && delayed.handoff_after_active_step == Some(433),
        "R23D10_RAP_CANARY_DELAYED",
    )?;

    let mut reset = vec![PARTIAL_TIGHT; 10];
    reset.extend(vec![TIGHT; 51]);
    reset.push(PARTIAL_TIGHT);
    reset.extend(vec![TIGHT; 838]);
    let reset = simulate(&reset)?;
    require(
        reset.passed
            && reset.taper_reset_count == 1
            && reset.handoff_after_active_step == Some(182),
        "R23D10_RAP_CANARY_RESET",
    )?;

    let deadline = simulate(&vec![COARSE_ONLY; TERMINAL_STEPS])?;
    require(
        !deadline.passed
            && deadline.handoff_after_active_step == Some(539)
            && deadline.passive_step_count == 360,
        "R23D10_RAP_CANARY_DEADLINE",
    )?;

    let mut loss = vec![TIGHT; TERMINAL_STEPS];
    loss[500] = PARTIAL_TIGHT;
    let loss = simulate(&loss)?;
    require(
        !loss.passed
            && loss.mode == Mode::Passive
            && loss.first_post_handoff_contact_loss_step == Some(500)
            && loss.post_handoff_contact_loss_step_count == 1,
        "R23D10_RAP_CANARY_LOSS",
    )?;
    Ok(5)
}

fn run_mutations() -> Result<usize, String> {
    let mut count = 0;
    let state = observe_completed_step(State::default(), PARTIAL_TIGHT, 8, 120, 120)?;
    require(
        state.mode == Mode::Active,
        "R23D10_RAP_MUTATION_COARSE_CONTACT",
    )?;
    count += 1;

    let taper = State {
        next_step: 10,
        mode: Mode::Taper,
        taper_step_count: 5,
        ..State::default()
    };
    let state = observe_completed_step(taper.clone(), PARTIAL_TIGHT, 8, 115, 120)?;
    require(
        state.mode == Mode::Active && state.taper_reset_count == 1,
        "R23D10_RAP_MUTATION_RESET_CONTACT",
    )?;
    count += 1;
    for (observation, code) in [
        (
            Observation {
                torso_tilt_rad: 0.04,
                ..TIGHT
            },
            "R23D10_RAP_MUTATION_RESET_TILT",
        ),
        (
            Observation {
                maximum_joint_error_rad: 0.33,
                ..TIGHT
            },
            "R23D10_RAP_MUTATION_RESET_ERROR",
        ),
    ] {
        let state = observe_completed_step(taper.clone(), observation, 8, 115, 120)?;
        require(state.mode == Mode::Active, code)?;
        count += 1;
    }
    require(
        observe_completed_step(taper.clone(), TIGHT, 8, 114, 120)
            .err()
            .as_deref()
            == Some("R23D10_VELOCITY_SCALE_MISMATCH"),
        "R23D10_RAP_MUTATION_NUMERATOR",
    )?;
    count += 1;
    require(
        observe_completed_step(taper, TIGHT, 8, 115, 119)
            .err()
            .as_deref()
            == Some("R23D10_VELOCITY_SCALE_MISMATCH"),
        "R23D10_RAP_MUTATION_DENOMINATOR",
    )?;
    count += 1;

    let early = State {
        next_step: 100,
        mode: Mode::Taper,
        taper_step_count: 118,
        ..State::default()
    };
    require(
        observe_completed_step(early, TIGHT, 8, 2, 120)?.mode == Mode::Taper,
        "R23D10_RAP_MUTATION_EARLY_HANDOFF",
    )?;
    count += 1;
    let near = State {
        next_step: 200,
        mode: Mode::Taper,
        taper_step_count: 119,
        ..State::default()
    };
    for (observation, code) in [
        (
            Observation {
                torso_tilt_rad: 0.02,
                ..TIGHT
            },
            "R23D10_RAP_MUTATION_TIGHT_TILT",
        ),
        (
            Observation {
                maximum_joint_error_rad: 0.25,
                ..TIGHT
            },
            "R23D10_RAP_MUTATION_TIGHT_ERROR",
        ),
    ] {
        let state = observe_completed_step(near.clone(), observation, 8, 1, 120)?;
        require(
            state.mode == Mode::Taper && !state.confirmation_satisfied,
            code,
        )?;
        count += 1;
    }
    let deadline = State {
        next_step: 539,
        ..State::default()
    };
    let deadline = observe_completed_step(deadline, PARTIAL_TIGHT, 8, 120, 120)?;
    require(
        deadline.mode == Mode::Passive && deadline.deadline_handoff,
        "R23D10_RAP_MUTATION_DEADLINE",
    )?;
    count += 1;
    require(
        !simulate(&vec![COARSE_ONLY; 900])?.passed,
        "R23D10_RAP_MUTATION_FORCED_PASS",
    )?;
    count += 1;

    let passive = State {
        next_step: 600,
        mode: Mode::Passive,
        confirmation_satisfied: true,
        handoff_after_active_step: Some(120),
        first_passive_step: Some(121),
        ..State::default()
    };
    require(
        observe_completed_step(passive.clone(), PARTIAL_TIGHT, 0, 0, 120)?.mode == Mode::Passive,
        "R23D10_RAP_MUTATION_REACTIVATION",
    )?;
    count += 1;
    require(
        observe_completed_step(passive, TIGHT, 8, 0, 120)
            .err()
            .as_deref()
            == Some("R23D10_APPLICATION_COUNT_MISMATCH"),
        "R23D10_RAP_MUTATION_PASSIVE_APPLICATION",
    )?;
    count += 1;
    require(
        outcome(&State {
            next_step: 899,
            ..State::default()
        })
        .err()
        .as_deref()
            == Some("R23D10_OUTCOME_BEFORE_HORIZON"),
        "R23D10_RAP_MUTATION_SHORT_HORIZON",
    )?;
    count += 1;
    require(
        (
            COARSE_MAXIMUM_TILT_RAD,
            COARSE_MAXIMUM_JOINT_ERROR_RAD,
            TIGHT_MAXIMUM_TILT_RAD,
            TIGHT_MAXIMUM_JOINT_ERROR_RAD,
        ) == (0.035, 0.32, 0.01, 0.2),
        "R23D10_RAP_MUTATION_THRESHOLDS",
    )?;
    count += 1;
    require(
        (
            MINIMUM_TAPER_STEPS,
            MAXIMUM_ACTIVE_STEPS,
            MINIMUM_PASSIVE_STEPS,
            TERMINAL_STEPS,
        ) == (120, 540, 360, 900),
        "R23D10_RAP_MUTATION_SCHEDULE",
    )?;
    count += 1;
    require(count == 16, "R23D10_RAP_MUTATION_COUNT")?;
    Ok(count)
}

fn validate_cell(stage_id: &str, arm_id: &str) -> Result<(), String> {
    let valid = stage_id == "three_engine_confirmation"
        && matches!(
            arm_id,
            "reference_zero" | "positive_heading" | "negative_heading"
        );
    require(valid, "R23D10_RAP_CELL_IDENTITY_INVALID")
}

pub fn run_qsdk_r23d10_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    validate_cell(stage_id, arm_id)?;
    let canaries = run_canaries()?;
    let mutations = run_mutations()?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d10_rapier_temporal_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": "QSDK-R23D10",
        "engine_id": "rapier_parry",
        "stage_id": stage_id,
        "arm_id": arm_id,
        "terminal_step_count": TERMINAL_STEPS,
        "maximum_active_step_count": MAXIMUM_ACTIVE_STEPS,
        "minimum_quiescent_taper_step_count": MINIMUM_TAPER_STEPS,
        "minimum_passive_step_count": MINIMUM_PASSIVE_STEPS,
        "oracle_canary_count": canaries,
        "mutation_control_count": mutations,
        "native_temporal_mirror": true,
        "fixed_total_trace_step_count": 3_892,
        "physical_worker_implemented": true,
        "physical_worker_dormant_behind_supervisor_authorization": true,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }))
}

pub fn run_qsdk_r23d10_rapier_authorization_preflight(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    validate_cell(stage_id, arm_id)?;
    run_qsdk_r23d10_rapier_authorization_preflight_impl(stage_id, arm_id, source_commit)
}

pub fn run_qsdk_r23d10_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    if let Err(code) = validate_cell(stage_id, arm_id) {
        return Err(json!({
            "schema_version": "sporespore_qsdk_r23d10_worker_failure_v1",
            "campaign_id": CAMPAIGN_ID,
            "gate_id": "QSDK-R23D10",
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": "rapier_parry",
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
    run_qsdk_r23d10_rapier_physical_impl(stage_id, arm_id, source_commit)
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
    fn frozen_canaries_and_mutations_pass() {
        assert_eq!(run_canaries().unwrap(), 5);
        assert_eq!(run_mutations().unwrap(), 16);
    }

    #[test]
    fn frozen_outcome_shapes_match_oracle_expectations() {
        let first = simulate(&vec![TIGHT; TERMINAL_STEPS]).unwrap();
        assert_eq!(first.first_passive_step, Some(121));
        assert_eq!(first.active_step_count, 121);
        assert_eq!(first.passive_step_count, 779);
        assert!(first.confirmation_satisfied);
        let deadline = simulate(&vec![COARSE_ONLY; TERMINAL_STEPS]).unwrap();
        assert_eq!(deadline.first_passive_step, Some(540));
        assert!(!deadline.passed);
    }

    #[test]
    fn preflight_is_zero_world_and_cell_bound() {
        let receipt =
            run_qsdk_r23d10_rapier_preflight("three_engine_confirmation", "positive_heading")
                .unwrap();
        assert_eq!(receipt["oracle_canary_count"], 5);
        assert_eq!(receipt["mutation_control_count"], 16);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["physical_worker_implemented"], true);
        assert!(run_qsdk_r23d10_rapier_preflight("wrong", "positive_heading").is_err());
    }
}
