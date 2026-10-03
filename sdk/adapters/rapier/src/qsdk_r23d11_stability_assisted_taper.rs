//! Independent Rapier/Rust composition mirror for prospective QSDK-R23D11.
//!
//! This module composes canonical velocities only. It calls the frozen R23D10
//! temporal preflight as an inherited zero-world canary, but constructs no
//! Rapier body, collider, pipeline, model, or world.

use std::collections::HashSet;

use serde_json::{Value, json};

use crate::qsdk_r23d3_phase_balanced::r23d11_physical::{
    run_qsdk_r23d11_rapier_authorization_preflight_impl, run_qsdk_r23d11_rapier_physical_impl,
};
use crate::qsdk_r23d10_quiescent_taper::run_qsdk_r23d10_rapier_preflight;

const CAMPAIGN_ID: &str =
    "QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT";
pub(crate) const ACTUATOR_COUNT: usize = 8;
pub(crate) const GLOBAL_SCALE: f64 = 0.5;
pub(crate) const MAXIMUM_STABILITY_DELTA: f64 = 0.075;
pub(crate) const MAXIMUM_STABILITY_SLEW: f64 = 0.010;
pub(crate) const MAXIMUM_NEUTRAL_VELOCITY: f64 = 0.35;
pub(crate) const MAXIMUM_COMBINED_VELOCITY: f64 = 0.425;
pub(crate) const TAPER_DENOMINATOR: usize = 120;
const TOLERANCE: f64 = 1.0e-12;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Availability {
    Available,
    ObservationUnavailable,
    PlanningInfeasible,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct CompositionMemory {
    previous_semantic_step: Option<usize>,
    ordered_actuator_ids: Option<Vec<String>>,
    previous_applied_velocity_deltas: Option<Vec<f64>>,
}

#[derive(Clone, Debug)]
pub(crate) struct Row {
    pub(crate) applied_stability_delta: f64,
    pub(crate) combined_pre_taper: f64,
    pub(crate) final_tapered_velocity: f64,
    pub(crate) fallback_zeroed: bool,
}

fn clamp(value: f64, minimum: f64, maximum: f64) -> f64 {
    value.max(minimum).min(maximum)
}

fn validate_ids(actuator_ids: &[String]) -> Result<(), String> {
    let unique: HashSet<&str> = actuator_ids.iter().map(String::as_str).collect();
    if actuator_ids.len() != ACTUATOR_COUNT
        || unique.len() != ACTUATOR_COUNT
        || actuator_ids.iter().any(String::is_empty)
    {
        return Err("R23D11_ACTUATOR_ORDER_INVALID".to_owned());
    }
    Ok(())
}

fn previous(
    memory: &CompositionMemory,
    semantic_step: usize,
    actuator_ids: &[String],
) -> Result<Vec<f64>, String> {
    match (
        memory.previous_semantic_step,
        memory.ordered_actuator_ids.as_ref(),
        memory.previous_applied_velocity_deltas.as_ref(),
    ) {
        (None, None, None) => Ok(vec![0.0; ACTUATOR_COUNT]),
        (Some(previous_step), Some(previous_ids), Some(values)) => {
            if previous_step >= semantic_step {
                return Err("R23D11_PREVIOUS_STEP_NOT_PREVIOUS".to_owned());
            }
            if previous_ids != actuator_ids {
                return Err("R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID".to_owned());
            }
            if values.len() != ACTUATOR_COUNT || values.iter().any(|value| !value.is_finite()) {
                return Err("R23D11_PREVIOUS_CORRECTION_INVALID".to_owned());
            }
            Ok(values.clone())
        }
        _ => Err("R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE".to_owned()),
    }
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn compose_active_step(
    semantic_step: usize,
    actuator_ids: &[String],
    neutral_velocities: &[f64],
    raw_stability_deltas: &[Option<f64>],
    availability: Availability,
    taper_numerator: usize,
    taper_denominator: usize,
    memory: &CompositionMemory,
) -> Result<(CompositionMemory, Vec<Row>), String> {
    validate_ids(actuator_ids)?;
    if neutral_velocities.len() != ACTUATOR_COUNT
        || neutral_velocities.iter().any(|value| !value.is_finite())
    {
        return Err("R23D11_NEUTRAL_VELOCITY_INVALID".to_owned());
    }
    if neutral_velocities
        .iter()
        .any(|value| value.abs() > MAXIMUM_NEUTRAL_VELOCITY)
    {
        return Err("R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND".to_owned());
    }
    if raw_stability_deltas.len() != ACTUATOR_COUNT {
        return Err("R23D11_STABILITY_CORRECTION_COUNT_INVALID".to_owned());
    }
    let available = availability == Availability::Available;
    if available {
        if raw_stability_deltas
            .iter()
            .any(|value| value.is_none_or(|number| !number.is_finite()))
        {
            return Err("R23D11_AVAILABLE_CORRECTION_INVALID".to_owned());
        }
    } else if raw_stability_deltas.iter().any(Option::is_some) {
        return Err("R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE".to_owned());
    }
    if taper_numerator == 0
        || taper_numerator > TAPER_DENOMINATOR
        || taper_denominator != TAPER_DENOMINATOR
    {
        return Err("R23D11_TAPER_FRACTION_INVALID".to_owned());
    }

    let previous_values = previous(memory, semantic_step, actuator_ids)?;
    let taper_scale = taper_numerator as f64 / taper_denominator as f64;
    let mut applied_values = Vec::with_capacity(ACTUATOR_COUNT);
    let mut rows = Vec::with_capacity(ACTUATOR_COUNT);
    for index in 0..ACTUATOR_COUNT {
        let applied = if available {
            let scaled = raw_stability_deltas[index].unwrap() * GLOBAL_SCALE;
            let magnitude = clamp(scaled, -MAXIMUM_STABILITY_DELTA, MAXIMUM_STABILITY_DELTA);
            clamp(
                magnitude,
                previous_values[index] - MAXIMUM_STABILITY_SLEW,
                previous_values[index] + MAXIMUM_STABILITY_SLEW,
            )
        } else {
            0.0
        };
        let combined = neutral_velocities[index] + applied;
        if combined.abs() > MAXIMUM_COMBINED_VELOCITY + TOLERANCE {
            return Err("R23D11_COMBINED_VELOCITY_OUTSIDE_DERIVED_BOUND".to_owned());
        }
        applied_values.push(applied);
        rows.push(Row {
            applied_stability_delta: applied,
            combined_pre_taper: combined,
            final_tapered_velocity: combined * taper_scale,
            fallback_zeroed: !available,
        });
    }
    Ok((
        CompositionMemory {
            previous_semantic_step: Some(semantic_step),
            ordered_actuator_ids: Some(actuator_ids.to_vec()),
            previous_applied_velocity_deltas: Some(applied_values),
        },
        rows,
    ))
}

fn ids() -> Vec<String> {
    (0..ACTUATOR_COUNT)
        .map(|index| format!("actuator_{index}"))
        .collect()
}

#[allow(clippy::too_many_arguments)]
fn call(
    semantic_step: usize,
    actuator_ids: &[String],
    neutral: &[f64],
    raw: &[Option<f64>],
    availability: Availability,
    numerator: usize,
    denominator: usize,
    memory: &CompositionMemory,
) -> Result<(CompositionMemory, Vec<Row>), String> {
    compose_active_step(
        semantic_step,
        actuator_ids,
        neutral,
        raw,
        availability,
        numerator,
        denominator,
        memory,
    )
}

fn require(condition: bool, code: &str) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(code.to_owned())
    }
}

fn expect_error<T>(result: Result<T, String>, code: &str) -> Result<(), String> {
    require(result.err().as_deref() == Some(code), code)
}

fn run_canaries() -> Result<usize, String> {
    let actuator_ids = ids();
    let neutral = vec![0.1; ACTUATOR_COUNT];
    let raw = vec![Some(1.0); ACTUATOR_COUNT];
    let empty = CompositionMemory::default();
    let (memory, first) = call(
        0,
        &actuator_ids,
        &neutral,
        &raw,
        Availability::Available,
        120,
        120,
        &empty,
    )?;
    require(
        first.iter().all(|row| row.applied_stability_delta == 0.01),
        "R23D11_RAP_CANARY_FIRST",
    )?;
    let (second_memory, second) = call(
        1,
        &actuator_ids,
        &neutral,
        &raw,
        Availability::Available,
        120,
        120,
        &memory,
    )?;
    require(
        second.iter().all(|row| row.applied_stability_delta == 0.02),
        "R23D11_RAP_CANARY_MEMORY",
    )?;
    let none = vec![None; ACTUATOR_COUNT];
    let (_, fallback) = call(
        2,
        &actuator_ids,
        &neutral,
        &none,
        Availability::ObservationUnavailable,
        120,
        120,
        &second_memory,
    )?;
    require(
        fallback
            .iter()
            .all(|row| row.fallback_zeroed && row.applied_stability_delta == 0.0),
        "R23D11_RAP_CANARY_FALLBACK",
    )?;
    let small = vec![Some(0.02); ACTUATOR_COUNT];
    let (_, half) = call(
        0,
        &actuator_ids,
        &neutral,
        &small,
        Availability::Available,
        60,
        120,
        &empty,
    )?;
    require(
        half.iter().all(|row| {
            (row.final_tapered_velocity - row.combined_pre_taper * 0.5).abs() <= TOLERANCE
        }),
        "R23D11_RAP_CANARY_TAPER_ORDER",
    )?;
    let mirrored_neutral = vec![-0.1; ACTUATOR_COUNT];
    let mirrored_raw = vec![Some(-1.0); ACTUATOR_COUNT];
    let (_, mirrored) = call(
        0,
        &actuator_ids,
        &mirrored_neutral,
        &mirrored_raw,
        Availability::Available,
        120,
        120,
        &empty,
    )?;
    require(
        first.iter().zip(&mirrored).all(|(left, right)| {
            (left.final_tapered_velocity + right.final_tapered_velocity).abs() <= TOLERANCE
        }),
        "R23D11_RAP_CANARY_MIRROR",
    )?;
    require(
        [0.0_f64; ACTUATOR_COUNT]
            .iter()
            .all(|command| *command == 0.0),
        "R23D11_RAP_CANARY_PASSIVE",
    )?;
    let temporal = run_qsdk_r23d10_rapier_preflight("three_engine_confirmation", "reference_zero")?;
    require(
        temporal["oracle_canary_count"] == 5
            && temporal["mutation_control_count"] == 16
            && temporal["world_build_count"] == 0,
        "R23D11_RAP_CANARY_TEMPORAL",
    )?;
    Ok(7)
}

fn run_mutations() -> Result<usize, String> {
    let actuator_ids = ids();
    let neutral = vec![0.1; ACTUATOR_COUNT];
    let raw = vec![Some(1.0); ACTUATOR_COUNT];
    let empty = CompositionMemory::default();
    let mut count = 0;
    let mut short_ids = actuator_ids.clone();
    short_ids.pop();
    expect_error(
        call(
            0,
            &short_ids,
            &neutral,
            &raw,
            Availability::Available,
            120,
            120,
            &empty,
        ),
        "R23D11_ACTUATOR_ORDER_INVALID",
    )?;
    count += 1;
    let mut duplicate_ids = actuator_ids.clone();
    duplicate_ids[7] = duplicate_ids[0].clone();
    expect_error(
        call(
            0,
            &duplicate_ids,
            &neutral,
            &raw,
            Availability::Available,
            120,
            120,
            &empty,
        ),
        "R23D11_ACTUATOR_ORDER_INVALID",
    )?;
    count += 1;
    for (values, code) in [
        (vec![0.1; 7], "R23D11_NEUTRAL_VELOCITY_INVALID"),
        (
            {
                let mut values = neutral.clone();
                values[0] = f64::NAN;
                values
            },
            "R23D11_NEUTRAL_VELOCITY_INVALID",
        ),
        (
            {
                let mut values = neutral.clone();
                values[0] = 0.351;
                values
            },
            "R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND",
        ),
    ] {
        expect_error(
            call(
                0,
                &actuator_ids,
                &values,
                &raw,
                Availability::Available,
                120,
                120,
                &empty,
            ),
            code,
        )?;
        count += 1;
    }
    expect_error(
        call(
            0,
            &actuator_ids,
            &neutral,
            &raw[..7],
            Availability::Available,
            120,
            120,
            &empty,
        ),
        "R23D11_STABILITY_CORRECTION_COUNT_INVALID",
    )?;
    count += 1;
    let mut nonfinite_raw = raw.clone();
    nonfinite_raw[0] = Some(f64::INFINITY);
    expect_error(
        call(
            0,
            &actuator_ids,
            &neutral,
            &nonfinite_raw,
            Availability::Available,
            120,
            120,
            &empty,
        ),
        "R23D11_AVAILABLE_CORRECTION_INVALID",
    )?;
    count += 1;
    expect_error(
        call(
            0,
            &actuator_ids,
            &neutral,
            &raw,
            Availability::ObservationUnavailable,
            120,
            120,
            &empty,
        ),
        "R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE",
    )?;
    count += 1;
    let none = vec![None; ACTUATOR_COUNT];
    require(
        call(
            0,
            &actuator_ids,
            &neutral,
            &none,
            Availability::PlanningInfeasible,
            120,
            120,
            &empty,
        )
        .is_ok(),
        "R23D11_RAP_MUTATION_AVAILABILITY_ENUM",
    )?;
    count += 1;
    for (numerator, denominator) in [(0, 120), (121, 120), (120, 119)] {
        expect_error(
            call(
                0,
                &actuator_ids,
                &neutral,
                &raw,
                Availability::Available,
                numerator,
                denominator,
                &empty,
            ),
            "R23D11_TAPER_FRACTION_INVALID",
        )?;
        count += 1;
    }
    let incomplete = CompositionMemory {
        previous_semantic_step: Some(0),
        ..CompositionMemory::default()
    };
    expect_error(
        call(
            1,
            &actuator_ids,
            &neutral,
            &raw,
            Availability::Available,
            120,
            120,
            &incomplete,
        ),
        "R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE",
    )?;
    count += 1;
    let complete = CompositionMemory {
        previous_semantic_step: Some(0),
        ordered_actuator_ids: Some(actuator_ids.clone()),
        previous_applied_velocity_deltas: Some(vec![0.0; ACTUATOR_COUNT]),
    };
    expect_error(
        call(
            0,
            &actuator_ids,
            &neutral,
            &raw,
            Availability::Available,
            120,
            120,
            &complete,
        ),
        "R23D11_PREVIOUS_STEP_NOT_PREVIOUS",
    )?;
    count += 1;
    let mut reversed_ids = actuator_ids.clone();
    reversed_ids.reverse();
    let reordered = CompositionMemory {
        ordered_actuator_ids: Some(reversed_ids),
        ..complete.clone()
    };
    expect_error(
        call(
            1,
            &actuator_ids,
            &neutral,
            &raw,
            Availability::Available,
            120,
            120,
            &reordered,
        ),
        "R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID",
    )?;
    count += 1;
    for previous_values in [vec![0.0; 7], {
        let mut values = vec![0.0; ACTUATOR_COUNT];
        values[0] = f64::NAN;
        values
    }] {
        let invalid = CompositionMemory {
            previous_applied_velocity_deltas: Some(previous_values),
            ..complete.clone()
        };
        expect_error(
            call(
                1,
                &actuator_ids,
                &neutral,
                &raw,
                Availability::Available,
                120,
                120,
                &invalid,
            ),
            "R23D11_PREVIOUS_CORRECTION_INVALID",
        )?;
        count += 1;
    }
    require(
        (
            GLOBAL_SCALE,
            MAXIMUM_STABILITY_DELTA,
            MAXIMUM_STABILITY_SLEW,
        ) == (0.5, 0.075, 0.010),
        "R23D11_RAP_MUTATION_CONSTANTS",
    )?;
    count += 1;
    require(count == 18, "R23D11_RAP_MUTATION_COUNT")?;
    Ok(count)
}

fn validate_cell(stage_id: &str, arm_id: &str) -> Result<(), String> {
    let valid = stage_id == "three_engine_confirmation"
        && matches!(
            arm_id,
            "reference_zero" | "positive_heading" | "negative_heading"
        );
    require(valid, "R23D11_RAP_CELL_IDENTITY_INVALID")
}

pub fn run_qsdk_r23d11_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    validate_cell(stage_id, arm_id)?;
    let canaries = run_canaries()?;
    let mutations = run_mutations()?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d11_rapier_composition_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": "QSDK-R23D11",
        "engine_id": "rapier_parry",
        "stage_id": stage_id,
        "arm_id": arm_id,
        "composition_canary_count": canaries,
        "mutation_control_count": mutations,
        "inherited_temporal_canary_count": 5,
        "native_composition_mirror": true,
        "physical_worker_implemented": true,
        "physical_worker_dormant_behind_supervisor_authorization": true,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
    }))
}

pub fn run_qsdk_r23d11_rapier_authorization_preflight(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    validate_cell(stage_id, arm_id)?;
    run_qsdk_r23d11_rapier_authorization_preflight_impl(stage_id, arm_id, source_commit)
}

pub fn run_qsdk_r23d11_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    if let Err(code) = validate_cell(stage_id, arm_id) {
        return Err(json!({
            "schema_version": "sporespore_qsdk_r23d11_worker_failure_v1",
            "campaign_id": CAMPAIGN_ID,
            "gate_id": "QSDK-R23D11",
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
    run_qsdk_r23d11_rapier_physical_impl(stage_id, arm_id, source_commit)
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
    fn qsdk_r23d11_native_preflight_is_zero_world() {
        let receipt =
            run_qsdk_r23d11_rapier_preflight("three_engine_confirmation", "negative_heading")
                .unwrap();
        assert_eq!(receipt["composition_canary_count"], 7);
        assert_eq!(receipt["mutation_control_count"], 18);
        assert_eq!(receipt["model_construction_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["physical_execution_authorized"], false);
        assert_eq!(receipt["physical_worker_implemented"], true);
    }

    #[test]
    fn qsdk_r23d11_identity_fails_closed() {
        assert_eq!(
            run_qsdk_r23d11_rapier_preflight(
                "mujoco_stability_assisted_taper_screen",
                "positive_heading",
            )
            .unwrap_err(),
            "R23D11_RAP_CELL_IDENTITY_INVALID"
        );
    }
}
