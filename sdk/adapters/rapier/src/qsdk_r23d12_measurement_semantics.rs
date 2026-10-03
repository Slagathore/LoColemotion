//! Independent Rapier/Rust diagnostic-semantics mirror for QSDK-R23D12.
//!
//! This module contains no Rapier world, controller, selector, or outcome
//! logic and does not consult the Python reference oracle.

use serde_json::{Value, json};

use crate::qsdk_r23d3_phase_balanced::r23d12_physical::{
    run_qsdk_r23d12_rapier_authorization_preflight_impl, run_qsdk_r23d12_rapier_physical_impl,
    run_qsdk_r23d12_rapier_preflight_impl,
};

const GATE_ID: &str = "QSDK-R23D12";
const CAMPAIGN_ID: &str =
    "QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-BILATERAL-TURN-DEVELOPMENT";
const ENGINE_ID: &str = "rapier_parry";

const ACTIVE_CONTROL: &str = "active_control";
const PASSIVE_OBSERVATION: &str = "passive_observation";
const PLANNER_AVAILABLE: &str = "available";
const PLANNER_OBSERVATION_UNAVAILABLE: &str = "observation_unavailable";
const PLANNER_INFEASIBLE: &str = "planning_infeasible";
const PLANNER_VALUES: [&str; 3] = [
    PLANNER_AVAILABLE,
    PLANNER_OBSERVATION_UNAVAILABLE,
    PLANNER_INFEASIBLE,
];
const MARGIN_MEASURED: &str = "measured";
const MARGIN_UNAVAILABLE: &str = "measurement_unavailable";
const ACTUATOR_COUNT: usize = 8;

const EXPECTED_MUTATION_CODES: [&str; 14] = [
    "R23D12_PHASE_CLASS_INVALID",
    "R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
    "R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
    "R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL",
    "R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
    "R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE",
    "R23D12_STABILITY_DELTA_VECTOR_INVALID",
    "R23D12_STABILITY_DELTA_VECTOR_INVALID",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
    "R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
];

#[derive(Clone, Debug)]
enum NativeScalar {
    Null,
    Bool,
    Number(f64),
}

#[derive(Clone, Debug)]
struct NativeDiagnosticInput {
    phase_class: String,
    stability_planning_availability: Option<String>,
    minimum_dynamic_support_margin_availability: String,
    minimum_dynamic_support_margin_m: NativeScalar,
    ordered_applied_stability_velocity_deltas_rad_s: Vec<NativeScalar>,
}

fn numbers(values: &[f64]) -> Vec<NativeScalar> {
    values.iter().copied().map(NativeScalar::Number).collect()
}

fn validate_diagnostic_semantics(value: &NativeDiagnosticInput) -> Result<Value, &'static str> {
    if value.phase_class != ACTIVE_CONTROL && value.phase_class != PASSIVE_OBSERVATION {
        return Err("R23D12_PHASE_CLASS_INVALID");
    }

    let planner = value.stability_planning_availability.as_deref();
    if value.phase_class == ACTIVE_CONTROL {
        if !matches!(
            planner,
            Some(PLANNER_AVAILABLE)
                | Some(PLANNER_OBSERVATION_UNAVAILABLE)
                | Some(PLANNER_INFEASIBLE)
        ) {
            return Err("R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID");
        }
    } else if planner.is_some() {
        return Err("R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL");
    }

    let margin_availability = value.minimum_dynamic_support_margin_availability.as_str();
    if margin_availability != MARGIN_MEASURED && margin_availability != MARGIN_UNAVAILABLE {
        return Err("R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID");
    }
    let normalized_margin = if margin_availability == MARGIN_MEASURED {
        match value.minimum_dynamic_support_margin_m {
            NativeScalar::Number(number) if number.is_finite() => Some(number),
            _ => return Err("R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE"),
        }
    } else {
        match value.minimum_dynamic_support_margin_m {
            NativeScalar::Null => None,
            _ => return Err("R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE"),
        }
    };

    if value.ordered_applied_stability_velocity_deltas_rad_s.len() != ACTUATOR_COUNT {
        return Err("R23D12_STABILITY_DELTA_VECTOR_INVALID");
    }
    let mut deltas = Vec::<f64>::with_capacity(ACTUATOR_COUNT);
    for item in &value.ordered_applied_stability_velocity_deltas_rad_s {
        match item {
            NativeScalar::Number(number) if number.is_finite() => deltas.push(*number),
            _ => return Err("R23D12_STABILITY_DELTA_VECTOR_INVALID"),
        }
    }

    let exact_zero_required =
        value.phase_class == PASSIVE_OBSERVATION || planner != Some(PLANNER_AVAILABLE);
    if exact_zero_required && deltas.iter().any(|item| *item != 0.0) {
        return Err("R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO");
    }

    Ok(json!({
        "phase_class": value.phase_class,
        "stability_planning_availability": planner,
        "minimum_dynamic_support_margin_availability": margin_availability,
        "minimum_dynamic_support_margin_m": normalized_margin,
        "ordered_applied_stability_velocity_deltas_rad_s": deltas,
        "stability_fallback_exact_zero_required": exact_zero_required,
    }))
}

pub(crate) fn validate_physical_diagnostics(
    active: bool,
    stability_planning_availability: Option<&str>,
    minimum_dynamic_support_margin_m: Option<f64>,
    applied_stability_deltas_rad_s: &[f64],
) -> Result<Value, String> {
    let value = NativeDiagnosticInput {
        phase_class: if active {
            ACTIVE_CONTROL.to_owned()
        } else {
            PASSIVE_OBSERVATION.to_owned()
        },
        stability_planning_availability: stability_planning_availability.map(str::to_owned),
        minimum_dynamic_support_margin_availability: if minimum_dynamic_support_margin_m.is_some() {
            MARGIN_MEASURED.to_owned()
        } else {
            MARGIN_UNAVAILABLE.to_owned()
        },
        minimum_dynamic_support_margin_m: minimum_dynamic_support_margin_m
            .map_or(NativeScalar::Null, NativeScalar::Number),
        ordered_applied_stability_velocity_deltas_rad_s: numbers(applied_stability_deltas_rad_s),
    };
    validate_diagnostic_semantics(&value).map_err(str::to_owned)
}

fn valid_canaries() -> Vec<NativeDiagnosticInput> {
    let zeros = [0.0; ACTUATOR_COUNT];
    let small = [0.01; ACTUATOR_COUNT];
    vec![
        NativeDiagnosticInput {
            phase_class: ACTIVE_CONTROL.to_owned(),
            stability_planning_availability: Some(PLANNER_AVAILABLE.to_owned()),
            minimum_dynamic_support_margin_availability: MARGIN_MEASURED.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Number(0.05),
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&small),
        },
        NativeDiagnosticInput {
            phase_class: ACTIVE_CONTROL.to_owned(),
            stability_planning_availability: Some(PLANNER_AVAILABLE.to_owned()),
            minimum_dynamic_support_margin_availability: MARGIN_UNAVAILABLE.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Null,
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&small),
        },
        NativeDiagnosticInput {
            phase_class: ACTIVE_CONTROL.to_owned(),
            stability_planning_availability: Some(PLANNER_OBSERVATION_UNAVAILABLE.to_owned()),
            minimum_dynamic_support_margin_availability: MARGIN_MEASURED.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Number(-0.01),
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&zeros),
        },
        NativeDiagnosticInput {
            phase_class: ACTIVE_CONTROL.to_owned(),
            stability_planning_availability: Some(PLANNER_OBSERVATION_UNAVAILABLE.to_owned()),
            minimum_dynamic_support_margin_availability: MARGIN_UNAVAILABLE.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Null,
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&zeros),
        },
        NativeDiagnosticInput {
            phase_class: ACTIVE_CONTROL.to_owned(),
            stability_planning_availability: Some(PLANNER_INFEASIBLE.to_owned()),
            minimum_dynamic_support_margin_availability: MARGIN_MEASURED.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Number(0.0),
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&zeros),
        },
        NativeDiagnosticInput {
            phase_class: PASSIVE_OBSERVATION.to_owned(),
            stability_planning_availability: None,
            minimum_dynamic_support_margin_availability: MARGIN_MEASURED.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Number(0.02),
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&zeros),
        },
        NativeDiagnosticInput {
            phase_class: PASSIVE_OBSERVATION.to_owned(),
            stability_planning_availability: None,
            minimum_dynamic_support_margin_availability: MARGIN_UNAVAILABLE.to_owned(),
            minimum_dynamic_support_margin_m: NativeScalar::Null,
            ordered_applied_stability_velocity_deltas_rad_s: numbers(&zeros),
        },
    ]
}

fn cross_product_inputs() -> Vec<NativeDiagnosticInput> {
    let zeros = [0.0; ACTUATOR_COUNT];
    let nonzero = [0.01; ACTUATOR_COUNT];
    let mut rows = Vec::<NativeDiagnosticInput>::new();
    for planner in PLANNER_VALUES {
        for (margin_availability, margin) in [
            (MARGIN_MEASURED, NativeScalar::Number(0.03)),
            (MARGIN_UNAVAILABLE, NativeScalar::Null),
        ] {
            rows.push(NativeDiagnosticInput {
                phase_class: ACTIVE_CONTROL.to_owned(),
                stability_planning_availability: Some(planner.to_owned()),
                minimum_dynamic_support_margin_availability: margin_availability.to_owned(),
                minimum_dynamic_support_margin_m: margin,
                ordered_applied_stability_velocity_deltas_rad_s: if planner == PLANNER_AVAILABLE {
                    numbers(&nonzero)
                } else {
                    numbers(&zeros)
                },
            });
        }
    }
    rows
}

fn mutations() -> Vec<NativeDiagnosticInput> {
    let baseline = valid_canaries().remove(0);
    let zeros = [0.0; ACTUATOR_COUNT];
    let mut rows = Vec::<NativeDiagnosticInput>::new();

    let mut row = baseline.clone();
    row.phase_class = "terminal".to_owned();
    rows.push(row);
    let mut row = baseline.clone();
    row.stability_planning_availability = None;
    rows.push(row);
    let mut row = baseline.clone();
    row.stability_planning_availability = Some("arm_specific".to_owned());
    rows.push(row);
    let mut row = baseline.clone();
    row.phase_class = PASSIVE_OBSERVATION.to_owned();
    row.stability_planning_availability = Some(PLANNER_AVAILABLE.to_owned());
    rows.push(row);
    let mut row = baseline.clone();
    row.minimum_dynamic_support_margin_availability = "estimated".to_owned();
    rows.push(row);
    let mut row = baseline.clone();
    row.minimum_dynamic_support_margin_m = NativeScalar::Null;
    rows.push(row);
    let mut row = baseline.clone();
    row.minimum_dynamic_support_margin_m = NativeScalar::Bool;
    rows.push(row);
    let mut row = baseline.clone();
    row.minimum_dynamic_support_margin_m = NativeScalar::Number(f64::NAN);
    rows.push(row);
    let mut row = baseline.clone();
    row.minimum_dynamic_support_margin_availability = MARGIN_UNAVAILABLE.to_owned();
    row.minimum_dynamic_support_margin_m = NativeScalar::Number(0.01);
    rows.push(row);
    let mut row = baseline.clone();
    row.ordered_applied_stability_velocity_deltas_rad_s = numbers(&zeros[..7]);
    rows.push(row);
    let mut row = baseline.clone();
    row.ordered_applied_stability_velocity_deltas_rad_s = numbers(&zeros);
    row.ordered_applied_stability_velocity_deltas_rad_s[7] = NativeScalar::Number(f64::INFINITY);
    rows.push(row);
    let mut row = baseline.clone();
    row.stability_planning_availability = Some(PLANNER_OBSERVATION_UNAVAILABLE.to_owned());
    rows.push(row);
    let mut row = baseline.clone();
    row.stability_planning_availability = Some(PLANNER_INFEASIBLE.to_owned());
    rows.push(row);
    let mut row = baseline;
    row.phase_class = PASSIVE_OBSERVATION.to_owned();
    row.stability_planning_availability = None;
    rows.push(row);
    rows
}

fn receipt_vector(receipt: &Value) -> String {
    let planner = receipt["stability_planning_availability"]
        .as_str()
        .unwrap_or("null");
    let margin = receipt["minimum_dynamic_support_margin_m"]
        .as_f64()
        .map(|value| format!("{value:.6}"))
        .unwrap_or_else(|| "null".to_owned());
    let deltas = receipt["ordered_applied_stability_velocity_deltas_rad_s"]
        .as_array()
        .expect("validated delta vector")
        .iter()
        .map(|item| format!("{:.6}", item.as_f64().expect("validated delta")))
        .collect::<Vec<String>>()
        .join(",");
    let exact_zero = if receipt["stability_fallback_exact_zero_required"] == true {
        "true"
    } else {
        "false"
    };
    format!(
        "{}|{}|{}|{}|{}|{}",
        receipt["phase_class"].as_str().expect("validated phase"),
        planner,
        receipt["minimum_dynamic_support_margin_availability"]
            .as_str()
            .expect("validated margin availability"),
        margin,
        deltas,
        exact_zero,
    )
}

pub fn run_qsdk_r23d12_rapier_semantics_preflight() -> Result<Value, String> {
    let valid_receipts = valid_canaries()
        .iter()
        .map(validate_diagnostic_semantics)
        .collect::<Result<Vec<Value>, &str>>()
        .map_err(str::to_owned)?;
    let cross_receipts = cross_product_inputs()
        .iter()
        .map(validate_diagnostic_semantics)
        .collect::<Result<Vec<Value>, &str>>()
        .map_err(str::to_owned)?;
    let mutation_codes = mutations()
        .iter()
        .map(|row| {
            validate_diagnostic_semantics(row)
                .err()
                .ok_or("R23D12_MUTATION_UNEXPECTEDLY_ACCEPTED")
        })
        .collect::<Result<Vec<&str>, &str>>()
        .map_err(str::to_owned)?;
    if mutation_codes.as_slice() != EXPECTED_MUTATION_CODES {
        return Err("R23D12_MUTATION_FAILURE_CODES_CHANGED".to_owned());
    }

    let critical = &valid_receipts[2];
    let critical_passed = critical["stability_planning_availability"]
        == PLANNER_OBSERVATION_UNAVAILABLE
        && critical["minimum_dynamic_support_margin_availability"] == MARGIN_MEASURED
        && critical["minimum_dynamic_support_margin_m"] == -0.01
        && critical["stability_fallback_exact_zero_required"] == true;
    if !critical_passed {
        return Err("R23D12_CRITICAL_FAILURE_SHAPE_NOT_ACCEPTED".to_owned());
    }

    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d12_native_semantics_preflight_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "engine_id": ENGINE_ID,
        "language": "rust",
        "valid_canary_count": valid_receipts.len(),
        "active_cross_product_count": cross_receipts.len(),
        "mutation_control_count": mutation_codes.len(),
        "critical_r23d11_failure_shape_passed": critical_passed,
        "valid_canary_vector": valid_receipts.iter().map(receipt_vector).collect::<Vec<String>>().join("\n"),
        "active_cross_product_vector": cross_receipts.iter().map(receipt_vector).collect::<Vec<String>>().join("\n"),
        "mutation_failure_codes": mutation_codes,
        "planner_and_support_margin_availability_are_independent": true,
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

pub fn run_qsdk_r23d12_rapier_preflight(stage_id: &str, arm_id: &str) -> Result<Value, String> {
    run_qsdk_r23d12_rapier_preflight_impl(stage_id, arm_id)
}

pub fn run_qsdk_r23d12_rapier_authorization_preflight(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    run_qsdk_r23d12_rapier_authorization_preflight_impl(stage_id, arm_id, source_commit)
}

pub fn run_qsdk_r23d12_rapier_physical(
    stage_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    run_qsdk_r23d12_rapier_physical_impl(stage_id, arm_id, source_commit)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qsdk_r23d12_accepts_seven_canaries_and_critical_shape() {
        let report = run_qsdk_r23d12_rapier_semantics_preflight().unwrap();
        assert_eq!(report["valid_canary_count"], 7);
        assert_eq!(report["active_cross_product_count"], 6);
        assert_eq!(report["critical_r23d11_failure_shape_passed"], true);
        assert_eq!(report["physical_worker_implemented"], false);
        assert_eq!(report["world_build_count"], 0);
    }

    #[test]
    fn qsdk_r23d12_rejects_fourteen_mutations_with_exact_codes() {
        let codes = mutations()
            .iter()
            .map(|row| validate_diagnostic_semantics(row).unwrap_err())
            .collect::<Vec<&str>>();
        assert_eq!(codes.as_slice(), EXPECTED_MUTATION_CODES);
    }

    #[test]
    fn qsdk_r23d12_preflight_is_deterministic() {
        let first = run_qsdk_r23d12_rapier_semantics_preflight().unwrap();
        let second = run_qsdk_r23d12_rapier_semantics_preflight().unwrap();
        assert_eq!(first, second);
        assert_eq!(first["reference_oracle_imported"], false);
        assert_eq!(first["physical_execution_authorized"], false);
    }
}
