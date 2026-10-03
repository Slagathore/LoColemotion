//! Independent Rapier/Rust zero-world mirror of the frozen QSDK-R23D13 law.
//!
//! This module contains no Rapier model, world, controller, selector, heading
//! command, or outcome input and does not consult the Python reference oracle.

use std::collections::HashSet;

use serde_json::{Value, json};

const GATE_ID: &str = "QSDK-R23D13";
const CAMPAIGN_ID: &str =
    "QSDK-R23D13-RESIDUAL-POSE-AUTHORITY-QUIESCENT-TAPER-BILATERAL-TURN-DEVELOPMENT";
const POLICY_ID: &str = "sporespore_residual_pose_authority_quiescent_taper_v1";
const ENGINE_ID: &str = "rapier_parry";

const ACTIVE_MODE: &str = "active_neutral_acquisition";
const TAPER_MODE: &str = "active_quiescent_taper";
const PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const ACTUATOR_COUNT: usize = 8;
const SCALE_DENOMINATOR: i64 = 120;
const TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
const COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
const TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;
const COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
const MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S: f64 = 0.425;
const NUMERICAL_CEILING_TOLERANCE: f64 = 1.0e-12;

const EXPECTED_MUTATION_CODES: [&str; 20] = [
    "R23D13_CONTACT_SHAPE_INVALID",
    "R23D13_CONTACT_TYPE_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_POSE_MEASUREMENT_INVALID",
    "R23D13_MODE_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_TEMPORAL_FRACTION_INVALID",
    "R23D13_ACTUATOR_ORDER_INVALID",
    "R23D13_ACTUATOR_ORDER_INVALID",
    "R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID",
    "R23D13_ACTIVE_VELOCITY_INVALID",
    "R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND",
    "R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT",
];

#[derive(Clone, Debug)]
enum ContactValue {
    Bool(bool),
    Integer,
}

#[derive(Clone, Debug)]
enum IntegerValue {
    Integer(i64),
    Bool,
}

#[derive(Clone, Debug)]
enum VelocityValue {
    Null,
    Number(f64),
}

#[derive(Clone, Debug)]
struct NativeAuthorityInput {
    mode: String,
    temporal_scale_numerator: IntegerValue,
    temporal_scale_denominator: IntegerValue,
    contacts: Vec<ContactValue>,
    torso_tilt_rad: f64,
    maximum_absolute_joint_position_error_rad: f64,
    actuator_ids: Vec<String>,
    combined_pre_taper_velocities_rad_s: Vec<VelocityValue>,
}

#[derive(Clone, Debug)]
struct FloorReceipt {
    tilt_floor_numerator: i64,
    joint_error_floor_numerator: i64,
    pose_authority_floor_numerator: i64,
    controlling_input: &'static str,
}

#[derive(Clone, Debug)]
struct AuthorityReceipt {
    pose_authority_floor_numerator: i64,
    temporal_scale_numerator: i64,
    applied_scale_numerator: i64,
    final_canonical_velocities_rad_s: Vec<f64>,
    residual_pose_recovery_invoked: bool,
}

fn channel_floor(value: f64, tight: f64, coarse: f64) -> i64 {
    let normalized = ((value - tight) / (coarse - tight)).clamp(0.0, 1.0);
    ((SCALE_DENOMINATOR as f64 * normalized) - NUMERICAL_CEILING_TOLERANCE).ceil() as i64
}

fn pose_authority_floor(value: &NativeAuthorityInput) -> Result<FloorReceipt, &'static str> {
    if value.contacts.len() != 4 {
        return Err("R23D13_CONTACT_SHAPE_INVALID");
    }
    let mut all_four = true;
    for contact in &value.contacts {
        match contact {
            ContactValue::Bool(present) => all_four &= *present,
            ContactValue::Integer => return Err("R23D13_CONTACT_TYPE_INVALID"),
        }
    }
    if !value.torso_tilt_rad.is_finite()
        || value.torso_tilt_rad < 0.0
        || !value.maximum_absolute_joint_position_error_rad.is_finite()
        || value.maximum_absolute_joint_position_error_rad < 0.0
    {
        return Err("R23D13_POSE_MEASUREMENT_INVALID");
    }

    if !all_four {
        return Ok(FloorReceipt {
            tilt_floor_numerator: 0,
            joint_error_floor_numerator: 0,
            pose_authority_floor_numerator: SCALE_DENOMINATOR,
            controlling_input: "incomplete_support_full_authority",
        });
    }
    let tilt = channel_floor(
        value.torso_tilt_rad,
        TIGHT_MAXIMUM_TILT_RAD,
        COARSE_MAXIMUM_TILT_RAD,
    );
    let joint = channel_floor(
        value.maximum_absolute_joint_position_error_rad,
        TIGHT_MAXIMUM_JOINT_ERROR_RAD,
        COARSE_MAXIMUM_JOINT_ERROR_RAD,
    );
    let floor = 1_i64.max(tilt).max(joint);
    let controlling = if tilt > joint {
        "torso_tilt"
    } else if joint > tilt {
        "maximum_joint_position_error"
    } else if floor == 1 {
        "tight_pose_minimum"
    } else {
        "equal_pose_channels"
    };
    Ok(FloorReceipt {
        tilt_floor_numerator: tilt,
        joint_error_floor_numerator: joint,
        pose_authority_floor_numerator: floor,
        controlling_input: controlling,
    })
}

fn integer(value: &IntegerValue) -> Option<i64> {
    match value {
        IntegerValue::Integer(number) => Some(*number),
        IntegerValue::Bool => None,
    }
}

fn apply_residual_pose_authority(
    value: &NativeAuthorityInput,
) -> Result<AuthorityReceipt, &'static str> {
    let floor_receipt = pose_authority_floor(value)?;
    if !matches!(value.mode.as_str(), ACTIVE_MODE | TAPER_MODE | PASSIVE_MODE) {
        return Err("R23D13_MODE_INVALID");
    }
    let numerator =
        integer(&value.temporal_scale_numerator).ok_or("R23D13_TEMPORAL_FRACTION_INVALID")?;
    let denominator =
        integer(&value.temporal_scale_denominator).ok_or("R23D13_TEMPORAL_FRACTION_INVALID")?;
    if denominator != SCALE_DENOMINATOR {
        return Err("R23D13_TEMPORAL_FRACTION_INVALID");
    }
    let temporal_valid = (value.mode == ACTIVE_MODE && numerator == SCALE_DENOMINATOR)
        || (value.mode == TAPER_MODE && (1..=SCALE_DENOMINATOR).contains(&numerator))
        || (value.mode == PASSIVE_MODE && numerator == 0);
    if !temporal_valid {
        return Err("R23D13_TEMPORAL_FRACTION_INVALID");
    }

    let unique = value.actuator_ids.iter().collect::<HashSet<&String>>();
    if value.actuator_ids.len() != ACTUATOR_COUNT
        || value.actuator_ids.iter().any(String::is_empty)
        || unique.len() != ACTUATOR_COUNT
    {
        return Err("R23D13_ACTUATOR_ORDER_INVALID");
    }
    if value.combined_pre_taper_velocities_rad_s.len() != ACTUATOR_COUNT {
        return Err("R23D13_PRE_TAPER_VELOCITY_COUNT_INVALID");
    }

    if value.mode == PASSIVE_MODE {
        if value
            .combined_pre_taper_velocities_rad_s
            .iter()
            .any(|item| !matches!(item, VelocityValue::Null))
        {
            return Err("R23D13_PASSIVE_PRE_TAPER_VELOCITY_PRESENT");
        }
        return Ok(AuthorityReceipt {
            pose_authority_floor_numerator: 0,
            temporal_scale_numerator: 0,
            applied_scale_numerator: 0,
            final_canonical_velocities_rad_s: vec![0.0; ACTUATOR_COUNT],
            residual_pose_recovery_invoked: false,
        });
    }

    let mut numeric = Vec::<f64>::with_capacity(ACTUATOR_COUNT);
    for item in &value.combined_pre_taper_velocities_rad_s {
        match item {
            VelocityValue::Number(number) if number.is_finite() => numeric.push(*number),
            _ => return Err("R23D13_ACTIVE_VELOCITY_INVALID"),
        }
    }
    if numeric
        .iter()
        .any(|item| item.abs() > MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S)
    {
        return Err("R23D13_ACTIVE_VELOCITY_OUTSIDE_BOUND");
    }
    let floor = floor_receipt.pose_authority_floor_numerator;
    let applied = numerator.max(floor);
    let scale = applied as f64 / SCALE_DENOMINATOR as f64;
    Ok(AuthorityReceipt {
        pose_authority_floor_numerator: floor,
        temporal_scale_numerator: numerator,
        applied_scale_numerator: applied,
        final_canonical_velocities_rad_s: numeric.iter().map(|item| *item * scale).collect(),
        residual_pose_recovery_invoked: true,
    })
}

fn baseline() -> NativeAuthorityInput {
    NativeAuthorityInput {
        mode: TAPER_MODE.to_owned(),
        temporal_scale_numerator: IntegerValue::Integer(2),
        temporal_scale_denominator: IntegerValue::Integer(120),
        contacts: vec![ContactValue::Bool(true); 4],
        torso_tilt_rad: 0.005,
        maximum_absolute_joint_position_error_rad: 0.1,
        actuator_ids: (0..ACTUATOR_COUNT)
            .map(|index| format!("actuator_{index}"))
            .collect(),
        combined_pre_taper_velocities_rad_s: [0.2, -0.1, 0.3, -0.2, 0.1, -0.3, 0.4, -0.4]
            .iter()
            .copied()
            .map(VelocityValue::Number)
            .collect(),
    }
}

fn floor_line(label: &str, receipt: &FloorReceipt) -> String {
    format!(
        "{label}|{}|{}|{}|{}",
        receipt.tilt_floor_numerator,
        receipt.joint_error_floor_numerator,
        receipt.pose_authority_floor_numerator,
        receipt.controlling_input
    )
}

fn canary_vector() -> Result<(String, Vec<AuthorityReceipt>, FloorReceipt), &'static str> {
    let base = baseline();
    let tight = pose_authority_floor(&base)?;
    let mut halfway_tilt = base.clone();
    halfway_tilt.torso_tilt_rad = 0.0225;
    let halfway_tilt = pose_authority_floor(&halfway_tilt)?;
    let mut halfway_joint = base.clone();
    halfway_joint.maximum_absolute_joint_position_error_rad = 0.26;
    let halfway_joint = pose_authority_floor(&halfway_joint)?;
    let mut joint_dominant = base.clone();
    joint_dominant.torso_tilt_rad = 0.015;
    joint_dominant.maximum_absolute_joint_position_error_rad = 0.29;
    let joint_dominant = pose_authority_floor(&joint_dominant)?;
    let mut incomplete = base.clone();
    incomplete.contacts[2] = ContactValue::Bool(false);
    let incomplete = pose_authority_floor(&incomplete)?;

    let mut active = base.clone();
    active.mode = ACTIVE_MODE.to_owned();
    active.temporal_scale_numerator = IntegerValue::Integer(120);
    let active = apply_residual_pose_authority(&active)?;
    let mut negative_best = base.clone();
    negative_best.torso_tilt_rad = 0.02039827933466296;
    negative_best.maximum_absolute_joint_position_error_rad = 0.2375508558310486;
    let raised = apply_residual_pose_authority(&negative_best)?;
    let mut temporal_input = negative_best;
    temporal_input.temporal_scale_numerator = IntegerValue::Integer(100);
    let temporal = apply_residual_pose_authority(&temporal_input)?;
    let mut negative_final_input = base.clone();
    negative_final_input.torso_tilt_rad = 0.027166660831829642;
    negative_final_input.maximum_absolute_joint_position_error_rad = 0.2706423272295883;
    let negative_final = pose_authority_floor(&negative_final_input)?;
    negative_final_input.mode = PASSIVE_MODE.to_owned();
    negative_final_input.temporal_scale_numerator = IntegerValue::Integer(0);
    negative_final_input.combined_pre_taper_velocities_rad_s =
        vec![VelocityValue::Null; ACTUATOR_COUNT];
    let passive = apply_residual_pose_authority(&negative_final_input)?;

    let lines = vec![
        floor_line("tight", &tight),
        floor_line("halfway_tilt", &halfway_tilt),
        floor_line("halfway_joint", &halfway_joint),
        floor_line("joint_dominant", &joint_dominant),
        floor_line("incomplete", &incomplete),
        format!(
            "active|{}|120|{}",
            active.pose_authority_floor_numerator, active.applied_scale_numerator
        ),
        format!(
            "raised|{}|2|{}",
            raised.pose_authority_floor_numerator, raised.applied_scale_numerator
        ),
        format!(
            "temporal_dominant|{}|100|{}",
            temporal.pose_authority_floor_numerator, temporal.applied_scale_numerator
        ),
        floor_line("negative_final", &negative_final),
        format!(
            "passive|{}|0|{}",
            passive.pose_authority_floor_numerator, passive.applied_scale_numerator
        ),
    ];
    Ok((
        lines.join("\n"),
        vec![active, raised, temporal, passive],
        tight,
    ))
}

fn mutations() -> Vec<NativeAuthorityInput> {
    let base = baseline();
    let mut rows = Vec::<NativeAuthorityInput>::new();

    let mut row = base.clone();
    row.contacts.pop();
    rows.push(row);
    let mut row = base.clone();
    row.contacts[3] = ContactValue::Integer;
    rows.push(row);
    let mut row = base.clone();
    row.torso_tilt_rad = f64::NAN;
    rows.push(row);
    let mut row = base.clone();
    row.torso_tilt_rad = -0.001;
    rows.push(row);
    let mut row = base.clone();
    row.maximum_absolute_joint_position_error_rad = f64::INFINITY;
    rows.push(row);
    let mut row = base.clone();
    row.maximum_absolute_joint_position_error_rad = -0.001;
    rows.push(row);
    let mut row = base.clone();
    row.mode = "negative_heading_recovery".to_owned();
    rows.push(row);
    let mut row = base.clone();
    row.mode = ACTIVE_MODE.to_owned();
    row.temporal_scale_numerator = IntegerValue::Integer(119);
    rows.push(row);
    let mut row = base.clone();
    row.temporal_scale_numerator = IntegerValue::Integer(0);
    rows.push(row);
    let mut row = base.clone();
    row.temporal_scale_numerator = IntegerValue::Integer(121);
    rows.push(row);
    let mut row = base.clone();
    row.temporal_scale_numerator = IntegerValue::Bool;
    rows.push(row);
    let mut row = base.clone();
    row.temporal_scale_denominator = IntegerValue::Integer(119);
    rows.push(row);
    let mut row = base.clone();
    row.temporal_scale_denominator = IntegerValue::Bool;
    rows.push(row);
    let mut row = base.clone();
    row.mode = PASSIVE_MODE.to_owned();
    row.temporal_scale_numerator = IntegerValue::Integer(1);
    row.combined_pre_taper_velocities_rad_s = vec![VelocityValue::Null; ACTUATOR_COUNT];
    rows.push(row);
    let mut row = base.clone();
    row.actuator_ids.pop();
    rows.push(row);
    let mut row = base.clone();
    row.actuator_ids[7] = row.actuator_ids[0].clone();
    rows.push(row);
    let mut row = base.clone();
    row.combined_pre_taper_velocities_rad_s.pop();
    rows.push(row);
    let mut row = base.clone();
    row.combined_pre_taper_velocities_rad_s[0] = VelocityValue::Number(f64::NAN);
    rows.push(row);
    let mut row = base.clone();
    row.combined_pre_taper_velocities_rad_s[0] = VelocityValue::Number(0.426);
    rows.push(row);
    let mut row = base;
    row.mode = PASSIVE_MODE.to_owned();
    row.temporal_scale_numerator = IntegerValue::Integer(0);
    row.combined_pre_taper_velocities_rad_s = vec![VelocityValue::Number(0.0); ACTUATOR_COUNT];
    rows.push(row);
    rows
}

pub fn run_qsdk_r23d13_rapier_authority_preflight() -> Result<Value, String> {
    let (vector, receipts, tight) = canary_vector().map_err(str::to_owned)?;
    let mutation_codes = mutations()
        .iter()
        .map(|row| {
            apply_residual_pose_authority(row)
                .err()
                .ok_or("R23D13_MUTATION_UNEXPECTEDLY_ACCEPTED")
        })
        .collect::<Result<Vec<&str>, &str>>()
        .map_err(str::to_owned)?;
    if mutation_codes.as_slice() != EXPECTED_MUTATION_CODES {
        return Err("R23D13_MUTATION_FAILURE_CODES_CHANGED".to_owned());
    }

    let active = &receipts[0];
    let raised = &receipts[1];
    let passive = &receipts[3];
    let source = [0.2, -0.1, 0.3, -0.2, 0.1, -0.3, 0.4, -0.4];
    let positive_regression = tight.pose_authority_floor_numerator == 1
        && active
            .final_canonical_velocities_rad_s
            .iter()
            .zip(source.iter())
            .all(|(actual, expected)| (*actual - *expected).abs() <= 1.0e-15);
    let critical = raised.pose_authority_floor_numerator == 50
        && raised.applied_scale_numerator == 50
        && vector.contains("negative_final|83|71|83|torso_tilt");
    let passive_zero = passive.applied_scale_numerator == 0
        && passive.temporal_scale_numerator == 0
        && !passive.residual_pose_recovery_invoked
        && passive
            .final_canonical_velocities_rad_s
            .iter()
            .all(|item| *item == 0.0);
    if !(positive_regression && critical && passive_zero) {
        return Err("R23D13_NATIVE_CANARY_FAILED".to_owned());
    }

    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d13_native_authority_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "policy_id": POLICY_ID,
        "engine_id": ENGINE_ID,
        "language": "rust",
        "valid_canary_count": 10,
        "mutation_control_count": mutation_codes.len(),
        "valid_canary_vector": vector,
        "mutation_failure_codes": mutation_codes,
        "critical_r23d12_negative_shape_passed": critical,
        "positive_tight_pose_no_regression_canary_passed": positive_regression,
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
    fn qsdk_r23d13_accepts_ten_canaries_and_critical_shapes() {
        let report = run_qsdk_r23d13_rapier_authority_preflight().unwrap();
        assert_eq!(report["valid_canary_count"], 10);
        assert_eq!(report["critical_r23d12_negative_shape_passed"], true);
        assert_eq!(
            report["positive_tight_pose_no_regression_canary_passed"],
            true
        );
        assert_eq!(report["passive_exact_zero_actuation_canary_passed"], true);
        assert_eq!(report["world_build_count"], 0);
    }

    #[test]
    fn qsdk_r23d13_rejects_twenty_mutations_with_exact_codes() {
        let codes = mutations()
            .iter()
            .map(|row| apply_residual_pose_authority(row).unwrap_err())
            .collect::<Vec<&str>>();
        assert_eq!(codes.as_slice(), EXPECTED_MUTATION_CODES);
    }

    #[test]
    fn qsdk_r23d13_preflight_is_deterministic() {
        let first = run_qsdk_r23d13_rapier_authority_preflight().unwrap();
        let second = run_qsdk_r23d13_rapier_authority_preflight().unwrap();
        assert_eq!(first, second);
        assert_eq!(first["physical_worker_implemented"], false);
        assert_eq!(first["physical_execution_authorized"], false);
    }
}
