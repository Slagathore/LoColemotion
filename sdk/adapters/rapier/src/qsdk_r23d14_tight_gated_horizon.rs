//! Independent Rapier/Rust zero-world mirror of the frozen R23D14 policy.
//!
//! This module contains no Rapier model, world, controller, selector, heading
//! command, or outcome input and does not consult the Python reference oracle.

use serde_json::{Value, json};

const GATE_ID: &str = "QSDK-R23D14";
const CAMPAIGN_ID: &str = "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION";
const POLICY_ID: &str = "sporespore_tight_gated_acquisition_active600_v1";
const ENGINE_ID: &str = "rapier_parry";

const ACTIVE_MODE: &str = "active_neutral_acquisition";
const TAPER_MODE: &str = "active_quiescent_taper";
const PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const CONFIRMED_REASON: &str = "support_pose_quiescence_confirmed";
const DEADLINE_REASON: &str = "deadline_forced_without_quiescence_confirmation";

const TERMINAL_STEPS: usize = 960;
const MAXIMUM_ACTIVE_STEPS: usize = 600;
const MINIMUM_TAPER_STEPS: usize = 120;
const MINIMUM_PASSIVE_STEPS: usize = 360;
const ACTUATOR_COUNT: usize = 8;
const SCALE_DENOMINATOR: usize = 120;
const COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
const COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
const TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
const TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;

const EXPECTED_MUTATION_CODES: [&str; 14] = [
    "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
    "R23D14_OBSERVATION_CONTACT_SHAPE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_TYPE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
    "R23D14_OBSERVATION_NUMERIC_VALUE_INVALID",
    "R23D14_STEP_OUTSIDE_HORIZON",
    "R23D14_STATE_MODE_INVALID",
    "R23D14_VELOCITY_SCALE_MISMATCH",
    "R23D14_VELOCITY_SCALE_MISMATCH",
    "R23D14_APPLICATION_COUNT_MISMATCH",
    "R23D14_APPLICATION_COUNT_MISMATCH",
    "R23D14_OBSERVATION_HORIZON_INVALID",
    "R23D14_OBSERVATION_HORIZON_INVALID",
    "R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON",
];

#[derive(Clone, Debug)]
enum ContactValue {
    Bool(bool),
    Integer,
}

#[derive(Clone, Debug)]
enum NumericValue {
    Number(f64),
    Text,
}

#[derive(Clone, Debug)]
struct Observation {
    contacts: Vec<ContactValue>,
    torso_tilt_rad: NumericValue,
    maximum_absolute_joint_position_error_rad: NumericValue,
}

#[derive(Clone, Debug)]
pub(crate) struct State {
    pub(crate) next_step: usize,
    pub(crate) mode: String,
    pub(crate) taper_step_count: usize,
    pub(crate) confirmation_satisfied: bool,
    pub(crate) handoff_after_active_step: Option<usize>,
    pub(crate) first_passive_step: Option<usize>,
    pub(crate) handoff_reason: Option<&'static str>,
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
            mode: ACTIVE_MODE.to_owned(),
            taper_step_count: 0,
            confirmation_satisfied: false,
            handoff_after_active_step: None,
            first_passive_step: None,
            handoff_reason: None,
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
pub(crate) struct StepReceipt {
    pub(crate) tight_pose_satisfied: bool,
    pub(crate) taper_reset_after_step: bool,
}

#[derive(Clone, Debug)]
pub(crate) struct Outcome {
    pub(crate) mode: String,
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

fn number(value: &NumericValue) -> Result<f64, &'static str> {
    match value {
        NumericValue::Text => Err("R23D14_OBSERVATION_NUMERIC_TYPE_INVALID"),
        NumericValue::Number(number) if number.is_finite() && *number >= 0.0 => Ok(*number),
        NumericValue::Number(_) => Err("R23D14_OBSERVATION_NUMERIC_VALUE_INVALID"),
    }
}

fn observation_values(observation: &Observation) -> Result<(bool, f64, f64), &'static str> {
    if observation.contacts.len() != 4 {
        return Err("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID");
    }
    let mut all_four = true;
    for contact in &observation.contacts {
        match contact {
            ContactValue::Bool(value) => all_four &= *value,
            ContactValue::Integer => {
                return Err("R23D14_OBSERVATION_CONTACT_SHAPE_INVALID");
            }
        }
    }
    Ok((
        all_four,
        number(&observation.torso_tilt_rad)?,
        number(&observation.maximum_absolute_joint_position_error_rad)?,
    ))
}

fn expected_velocity_scale(state: &State) -> Result<(usize, usize), &'static str> {
    match state.mode.as_str() {
        ACTIVE_MODE => Ok((SCALE_DENOMINATOR, SCALE_DENOMINATOR)),
        TAPER_MODE => Ok((
            1_usize.max(MINIMUM_TAPER_STEPS.saturating_sub(state.taper_step_count)),
            SCALE_DENOMINATOR,
        )),
        PASSIVE_MODE => Ok((0, SCALE_DENOMINATOR)),
        _ => Err("R23D14_STATE_MODE_INVALID"),
    }
}

fn handoff(mut state: State, step: usize, confirmed: bool) -> State {
    state.mode = PASSIVE_MODE.to_owned();
    state.confirmation_satisfied = confirmed;
    state.handoff_after_active_step = Some(step);
    state.first_passive_step = Some(step + 1);
    state.handoff_reason = Some(if confirmed {
        CONFIRMED_REASON
    } else {
        DEADLINE_REASON
    });
    state
}

fn observe_completed_step(
    state: State,
    observation: &Observation,
    native_application_count: usize,
    velocity_scale_numerator: usize,
    velocity_scale_denominator: usize,
) -> Result<(State, StepReceipt), &'static str> {
    if state.next_step >= TERMINAL_STEPS {
        return Err("R23D14_STEP_OUTSIDE_HORIZON");
    }
    if !matches!(state.mode.as_str(), ACTIVE_MODE | TAPER_MODE | PASSIVE_MODE) {
        return Err("R23D14_STATE_MODE_INVALID");
    }
    let (all_four, tilt, joint_error) = observation_values(observation)?;
    if expected_velocity_scale(&state)? != (velocity_scale_numerator, velocity_scale_denominator) {
        return Err("R23D14_VELOCITY_SCALE_MISMATCH");
    }
    let expected_applications = if state.mode == PASSIVE_MODE {
        0
    } else {
        ACTUATOR_COUNT
    };
    if native_application_count != expected_applications {
        return Err("R23D14_APPLICATION_COUNT_MISMATCH");
    }

    let step = state.next_step;
    let pre_mode = state.mode.clone();
    let pre_taper_count = state.taper_step_count;
    let _coarse = all_four
        && tilt <= COARSE_MAXIMUM_TILT_RAD
        && joint_error <= COARSE_MAXIMUM_JOINT_ERROR_RAD;
    let tight =
        all_four && tilt <= TIGHT_MAXIMUM_TILT_RAD && joint_error <= TIGHT_MAXIMUM_JOINT_ERROR_RAD;
    let mut reset = false;
    let mut next = state;
    next.next_step += 1;
    if matches!(pre_mode.as_str(), ACTIVE_MODE | TAPER_MODE) {
        next.active_step_count += 1;
        next.active_native_application_count += native_application_count;
        if pre_mode == ACTIVE_MODE {
            if step == MAXIMUM_ACTIVE_STEPS - 1 {
                next = handoff(next, step, false);
            } else if tight {
                next.mode = TAPER_MODE.to_owned();
                next.taper_step_count = 0;
            }
        } else if tight {
            next.taper_step_count = (pre_taper_count + 1).min(MINIMUM_TAPER_STEPS);
            if next.taper_step_count >= MINIMUM_TAPER_STEPS {
                next = handoff(next, step, true);
            } else if step == MAXIMUM_ACTIVE_STEPS - 1 {
                next = handoff(next, step, false);
            }
        } else if step == MAXIMUM_ACTIVE_STEPS - 1 {
            next = handoff(next, step, false);
        } else {
            next.mode = ACTIVE_MODE.to_owned();
            next.taper_step_count = 0;
            next.taper_reset_count += 1;
            reset = true;
        }
    } else {
        next.passive_step_count += 1;
        next.passive_native_application_count += native_application_count;
        if !all_four {
            next.post_handoff_contact_loss_step_count += 1;
            if next.first_post_handoff_contact_loss_step.is_none() {
                next.first_post_handoff_contact_loss_step = Some(step);
            }
        }
    }
    Ok((
        next,
        StepReceipt {
            tight_pose_satisfied: tight,
            taper_reset_after_step: reset,
        },
    ))
}

fn outcome(state: &State) -> Result<Outcome, &'static str> {
    if state.next_step != TERMINAL_STEPS {
        return Err("R23D14_OUTCOME_BEFORE_TERMINAL_HORIZON");
    }
    let passed = state.confirmation_satisfied
        && state.handoff_reason == Some(CONFIRMED_REASON)
        && state
            .first_passive_step
            .is_some_and(|step| step <= MAXIMUM_ACTIVE_STEPS)
        && state.passive_step_count >= MINIMUM_PASSIVE_STEPS
        && state.passive_native_application_count == 0
        && state.post_handoff_contact_loss_step_count == 0
        && state.mode == PASSIVE_MODE;
    Ok(Outcome {
        mode: state.mode.clone(),
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

/// Production-facing reuse seam for the frozen native temporal law.
///
/// The zero-world mirror keeps its mutation-oriented input enums private. The
/// physical worker can supply only already typed host observations through
/// these functions, while the state transition and outcome logic remain the
/// exact implementation qualified by the native canaries.
pub(crate) fn production_expected_scale(state: &State) -> Result<(usize, usize), &'static str> {
    expected_velocity_scale(state)
}

pub(crate) fn production_observe_completed_step(
    state: State,
    contacts: [bool; 4],
    torso_tilt_rad: f64,
    maximum_absolute_joint_position_error_rad: f64,
    native_application_count: usize,
    velocity_scale_numerator: usize,
    velocity_scale_denominator: usize,
) -> Result<(State, StepReceipt), &'static str> {
    let observation = observation(
        contacts,
        torso_tilt_rad,
        maximum_absolute_joint_position_error_rad,
    );
    observe_completed_step(
        state,
        &observation,
        native_application_count,
        velocity_scale_numerator,
        velocity_scale_denominator,
    )
}

pub(crate) fn production_outcome(state: &State) -> Result<Outcome, &'static str> {
    outcome(state)
}

pub(crate) fn production_coarse_pose_satisfied(
    contacts: [bool; 4],
    torso_tilt_rad: f64,
    maximum_absolute_joint_position_error_rad: f64,
) -> bool {
    contacts.into_iter().all(|contact| contact)
        && torso_tilt_rad <= COARSE_MAXIMUM_TILT_RAD
        && maximum_absolute_joint_position_error_rad <= COARSE_MAXIMUM_JOINT_ERROR_RAD
}

pub(crate) fn production_tight_pose_satisfied(
    contacts: [bool; 4],
    torso_tilt_rad: f64,
    maximum_absolute_joint_position_error_rad: f64,
) -> bool {
    contacts.into_iter().all(|contact| contact)
        && torso_tilt_rad <= TIGHT_MAXIMUM_TILT_RAD
        && maximum_absolute_joint_position_error_rad <= TIGHT_MAXIMUM_JOINT_ERROR_RAD
}

fn simulate(observations: &[Observation]) -> Result<Outcome, &'static str> {
    if observations.len() != TERMINAL_STEPS {
        return Err("R23D14_OBSERVATION_HORIZON_INVALID");
    }
    let mut state = State::default();
    for observation in observations {
        let (numerator, denominator) = expected_velocity_scale(&state)?;
        let applications = if state.mode == PASSIVE_MODE {
            0
        } else {
            ACTUATOR_COUNT
        };
        state = observe_completed_step(state, observation, applications, numerator, denominator)?.0;
    }
    outcome(&state)
}

fn observation(contacts: [bool; 4], tilt: f64, joint_error: f64) -> Observation {
    Observation {
        contacts: contacts.into_iter().map(ContactValue::Bool).collect(),
        torso_tilt_rad: NumericValue::Number(tilt),
        maximum_absolute_joint_position_error_rad: NumericValue::Number(joint_error),
    }
}

fn tight() -> Observation {
    observation([true, true, true, true], 0.005, 0.1)
}

fn coarse() -> Observation {
    observation([true, true, true, true], 0.02, 0.25)
}

fn unsupported() -> Observation {
    observation([true, true, true, false], 0.005, 0.1)
}

fn combined(prefix: (&Observation, usize), suffix: (&Observation, usize)) -> Vec<Observation> {
    let mut rows = vec![prefix.0.clone(); prefix.1];
    rows.extend(vec![suffix.0.clone(); suffix.1]);
    rows
}

fn semantic_vector() -> Result<(String, Vec<Outcome>), &'static str> {
    let tight = tight();
    let coarse = coarse();
    let unsupported = unsupported();
    let (tight_state, _) = observe_completed_step(State::default(), &tight, 8, 120, 120)?;
    let (coarse_state, _) = observe_completed_step(State::default(), &coarse, 8, 120, 120)?;
    let (reset_state, reset_receipt) =
        observe_completed_step(tight_state.clone(), &unsupported, 8, 120, 120)?;
    let positive = simulate(&combined((&coarse, 318), (&tight, 642)))?;
    let negative = simulate(&combined((&coarse, 459), (&tight, 501)))?;
    let deadline = simulate(&vec![coarse.clone(); TERMINAL_STEPS])?;
    let earliest = simulate(&vec![tight.clone(); TERMINAL_STEPS])?;
    let mut loss_rows = vec![tight.clone(); 121];
    loss_rows.push(unsupported);
    loss_rows.extend(vec![tight.clone(); 838]);
    let loss = simulate(&loss_rows)?;
    let (boundary_state, boundary_receipt) = observe_completed_step(
        State::default(),
        &observation([true, true, true, true], 0.01, 0.2),
        8,
        120,
        120,
    )?;
    let (over_state, over_receipt) = observe_completed_step(
        State::default(),
        &observation([true, true, true, true], 0.010000000001, 0.2),
        8,
        120,
        120,
    )?;
    let vector = [
        "schedule|960|600|120|360".to_owned(),
        format!(
            "tight_entry|{}|{}|120|120",
            tight_state.mode, tight_state.taper_step_count
        ),
        format!("coarse_hold|{}|120|120", coarse_state.mode),
        format!(
            "tight_loss_reset|{}|{}|120|120",
            reset_state.mode, reset_state.taper_reset_count
        ),
        format!("positive|438|439|521|{}", positive.passed),
        format!("negative|579|580|380|{}", negative.passed),
        format!("deadline|599|600|360|{}", deadline.passed),
        format!("earliest|120|121|839|{}", earliest.passed),
        format!("post_handoff_loss|120|121|1|121|{}", loss.passed),
        format!(
            "tight_boundary|{}|{}",
            boundary_state.mode, boundary_receipt.tight_pose_satisfied
        ),
        format!(
            "over_tight_boundary|{}|{}",
            over_state.mode, over_receipt.tight_pose_satisfied
        ),
        format!(
            "passive_zero|{}|0|{}",
            earliest.passive_native_application_count, earliest.mode
        ),
    ]
    .join("\n");
    if !reset_receipt.taper_reset_after_step {
        return Err("R23D14_NATIVE_CANARY_FAILED");
    }
    Ok((vector, vec![positive, negative, deadline, earliest, loss]))
}

fn mutation_codes() -> Result<Vec<&'static str>, &'static str> {
    let tight = tight();
    let mut short_contacts = tight.clone();
    short_contacts.contacts.pop();
    let mut typed_contacts = tight.clone();
    typed_contacts.contacts[3] = ContactValue::Integer;
    let mut typed_number = tight.clone();
    typed_number.torso_tilt_rad = NumericValue::Text;
    let mut nan_tilt = tight.clone();
    nan_tilt.torso_tilt_rad = NumericValue::Number(f64::NAN);
    let mut negative_error = tight.clone();
    negative_error.maximum_absolute_joint_position_error_rad = NumericValue::Number(-0.1);
    let actions = vec![
        observe_completed_step(State::default(), &short_contacts, 8, 120, 120).map(|_| ()),
        observe_completed_step(State::default(), &typed_contacts, 8, 120, 120).map(|_| ()),
        observe_completed_step(State::default(), &typed_number, 8, 120, 120).map(|_| ()),
        observe_completed_step(State::default(), &nan_tilt, 8, 120, 120).map(|_| ()),
        observe_completed_step(State::default(), &negative_error, 8, 120, 120).map(|_| ()),
        observe_completed_step(
            State {
                next_step: TERMINAL_STEPS,
                ..State::default()
            },
            &tight,
            8,
            120,
            120,
        )
        .map(|_| ()),
        observe_completed_step(
            State {
                mode: "negative_heading_recovery".to_owned(),
                ..State::default()
            },
            &tight,
            8,
            120,
            120,
        )
        .map(|_| ()),
        observe_completed_step(State::default(), &tight, 8, 119, 120).map(|_| ()),
        observe_completed_step(State::default(), &tight, 8, 120, 119).map(|_| ()),
        observe_completed_step(State::default(), &tight, 0, 120, 120).map(|_| ()),
        observe_completed_step(
            State {
                mode: PASSIVE_MODE.to_owned(),
                ..State::default()
            },
            &tight,
            8,
            0,
            120,
        )
        .map(|_| ()),
        simulate(&vec![tight.clone(); TERMINAL_STEPS - 1]).map(|_| ()),
        simulate(&vec![tight.clone(); TERMINAL_STEPS + 1]).map(|_| ()),
        outcome(&State {
            next_step: TERMINAL_STEPS - 1,
            ..State::default()
        })
        .map(|_| ()),
    ];
    let mut codes = Vec::<&'static str>::with_capacity(actions.len());
    for action in actions {
        codes.push(
            action
                .err()
                .ok_or("R23D14_MUTATION_UNEXPECTEDLY_ACCEPTED")?,
        );
    }
    Ok(codes)
}

pub fn run_qsdk_r23d14_rapier_temporal_preflight() -> Result<Value, String> {
    let (vector, outcomes) = semantic_vector().map_err(str::to_owned)?;
    let codes = mutation_codes().map_err(str::to_owned)?;
    if codes.as_slice() != EXPECTED_MUTATION_CODES {
        return Err("R23D14_MUTATION_FAILURE_CODES_CHANGED".to_owned());
    }
    let positive = &outcomes[0];
    let negative = &outcomes[1];
    let earliest = &outcomes[3];
    let retained_positive = positive.handoff_after_active_step == Some(438)
        && positive.first_passive_step == Some(439)
        && positive.passive_step_count == 521
        && positive.passed;
    let retained_negative = negative.handoff_after_active_step == Some(579)
        && negative.first_passive_step == Some(580)
        && negative.passive_step_count == 380
        && negative.passed;
    let passive_zero = earliest.passive_native_application_count == 0
        && earliest.mode == PASSIVE_MODE
        && earliest.passed;
    if !(retained_positive && retained_negative && passive_zero) {
        return Err("R23D14_NATIVE_CANARY_FAILED".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d14_native_temporal_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "policy_id": POLICY_ID,
        "engine_id": ENGINE_ID,
        "language": "rust",
        "valid_canary_count": 12,
        "mutation_control_count": codes.len(),
        "valid_canary_vector": vector,
        "mutation_failure_codes": codes,
        "retained_positive_timing_shape_passed": retained_positive,
        "retained_negative_timing_shape_passed": retained_negative,
        "passive_exact_zero_actuation_canary_passed": passive_zero,
        "reference_oracle_imported": false,
        "physical_worker_implemented": false,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qsdk_r23d14_accepts_twelve_canaries_and_retained_shapes() {
        let report = run_qsdk_r23d14_rapier_temporal_preflight().unwrap();
        assert_eq!(report["valid_canary_count"], 12);
        assert_eq!(report["retained_positive_timing_shape_passed"], true);
        assert_eq!(report["retained_negative_timing_shape_passed"], true);
        assert_eq!(report["passive_exact_zero_actuation_canary_passed"], true);
        assert_eq!(report["world_build_count"], 0);
    }

    #[test]
    fn qsdk_r23d14_rejects_fourteen_mutations_with_exact_codes() {
        assert_eq!(
            mutation_codes().unwrap().as_slice(),
            EXPECTED_MUTATION_CODES
        );
    }

    #[test]
    fn qsdk_r23d14_preflight_is_deterministic() {
        let first = run_qsdk_r23d14_rapier_temporal_preflight().unwrap();
        let second = run_qsdk_r23d14_rapier_temporal_preflight().unwrap();
        assert_eq!(first, second);
        assert_eq!(first["physical_worker_implemented"], false);
        assert_eq!(first["physical_execution_authorized"], false);
    }

    #[test]
    fn qsdk_r23d14_internal_counts_remain_coherent() {
        let earliest = simulate(&vec![tight(); TERMINAL_STEPS]).unwrap();
        assert!(earliest.confirmation_satisfied);
        assert_eq!(earliest.active_step_count, 121);
        assert_eq!(earliest.passive_step_count, 839);
        assert_eq!(earliest.active_native_application_count, 968);
        assert_eq!(earliest.taper_reset_count, 0);
        assert_eq!(earliest.first_post_handoff_contact_loss_step, None);
        assert_eq!(earliest.post_handoff_contact_loss_step_count, 0);
    }
}
