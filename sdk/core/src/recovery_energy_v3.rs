//! Additive engine-neutral recovery energy ledger with discrete-staging exchange.
//!
//! QSDK-R24D52 leaves the qualified V2 ledger unchanged. V3 adds one signed
//! channel for the force/position/half-step staging exchange measured by the
//! native engine. The channel is neither external work nor passive dissipation.
//! This module remains pure and constructs or steps no physics world.

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::recovery_energy::RecoveryEnergyBalanceSupportStatusV1;
use crate::schema::{CoreError, Result};

pub const RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION: &str =
    "sporespore_recovery_energy_balance_ledger_v3";
pub const RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION: &str =
    "sporespore_recovery_energy_balance_aggregation_request_v3";
pub const RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V3_VERSION: &str =
    "sporespore_recovery_energy_balance_aggregation_receipt_v3";
pub const RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION: &str =
    "sporespore_recovery_energy_balance_evaluation_request_v3";
pub const RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V3_VERSION: &str =
    "sporespore_recovery_energy_balance_evaluation_receipt_v3";
pub const RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID: &str =
    "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3";
pub const RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID: &str = "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3";

const MAX_EXACT_JSON_INTEGER: u64 = 9_007_199_254_740_991;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyWorkIncrementV3 {
    pub sequence_index: u64,
    pub semantic_step: u64,
    pub applied_actuator_work_j: f64,
    pub signed_external_work_j: f64,
    pub signed_constraint_exchange_j: f64,
    pub signed_discrete_staging_exchange_j: f64,
    pub passive_dissipation_j: f64,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceLedgerV3 {
    pub schema_version: String,
    pub equation_id: String,
    pub component_partition_id: String,
    pub source_profile_id: String,
    pub source_values_sha256: String,
    pub initial_mechanical_energy_j: f64,
    pub current_mechanical_energy_j: f64,
    pub cumulative_applied_actuator_work_j: f64,
    pub cumulative_signed_external_work_j: f64,
    pub cumulative_signed_constraint_exchange_j: f64,
    pub cumulative_signed_discrete_staging_exchange_j: f64,
    pub cumulative_passive_dissipation_j: f64,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceAggregationRequestV3 {
    pub schema_version: String,
    pub source_profile_id: String,
    pub initial_mechanical_energy_j: f64,
    pub current_mechanical_energy_j: f64,
    pub ordered_increments: Vec<RecoveryEnergyWorkIncrementV3>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceAggregationReceiptV3 {
    pub schema_version: String,
    pub support_status: RecoveryEnergyBalanceSupportStatusV1,
    pub increment_count: usize,
    pub first_sequence_index: u64,
    pub last_sequence_index: u64,
    pub first_semantic_step: u64,
    pub last_semantic_step: u64,
    pub ordered_source_values_sha256: String,
    pub ledger_sha256: String,
    pub ledger: RecoveryEnergyBalanceLedgerV3,
    pub evaluation: RecoveryEnergyBalanceEvaluationReceiptV3,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceEvaluationRequestV3 {
    pub schema_version: String,
    pub ledger: RecoveryEnergyBalanceLedgerV3,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceEvaluationReceiptV3 {
    pub schema_version: String,
    pub support_status: RecoveryEnergyBalanceSupportStatusV1,
    pub equation_id: String,
    pub ledger_sha256: String,
    pub signed_residual_j: f64,
    pub absolute_residual_j: f64,
    pub threshold_applied: bool,
    pub physical_result: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

fn finite(value: f64, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(CoreError::NonFinite(field.to_owned()))
    }
}

fn add_finite(total: &mut f64, value: f64, field: &str) -> Result<()> {
    finite(value, field)?;
    *total += value;
    finite(*total, field)
}

fn valid_digest(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn validate_profile_id(value: &str) -> Result<()> {
    if value.is_empty() || value.len() > 256 || value.trim() != value {
        Err(CoreError::Identity(
            "recovery_energy_v3_source_profile_id".to_owned(),
        ))
    } else {
        Ok(())
    }
}

fn validate_ledger(ledger: &RecoveryEnergyBalanceLedgerV3) -> Result<()> {
    if ledger.schema_version != RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_ledger_v3_version".to_owned(),
        ));
    }
    if ledger.equation_id != RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID
        || ledger.component_partition_id != RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID
    {
        return Err(CoreError::Identity(
            "recovery_energy_v3_equation_or_partition".to_owned(),
        ));
    }
    validate_profile_id(&ledger.source_profile_id)?;
    if !valid_digest(&ledger.source_values_sha256) {
        return Err(CoreError::Digest(
            "recovery_energy_v3_source_values_sha256".to_owned(),
        ));
    }
    for (value, field) in [
        (
            ledger.initial_mechanical_energy_j,
            "initial_mechanical_energy_j",
        ),
        (
            ledger.current_mechanical_energy_j,
            "current_mechanical_energy_j",
        ),
        (
            ledger.cumulative_applied_actuator_work_j,
            "applied_actuator_work_j",
        ),
        (
            ledger.cumulative_signed_external_work_j,
            "signed_external_work_j",
        ),
        (
            ledger.cumulative_signed_constraint_exchange_j,
            "signed_constraint_exchange_j",
        ),
        (
            ledger.cumulative_signed_discrete_staging_exchange_j,
            "signed_discrete_staging_exchange_j",
        ),
        (
            ledger.cumulative_passive_dissipation_j,
            "passive_dissipation_j",
        ),
    ] {
        finite(value, &format!("recovery_energy_v3.{field}"))?;
    }
    if ledger.cumulative_passive_dissipation_j < 0.0 {
        return Err(CoreError::Schema(
            "recovery_energy_v3_passive_dissipation_negative".to_owned(),
        ));
    }
    if !ledger.source_measurement {
        return Err(CoreError::Schema(
            "recovery_energy_v3_source_measurement_required".to_owned(),
        ));
    }
    Ok(())
}

fn evaluate_ledger(
    ledger: &RecoveryEnergyBalanceLedgerV3,
) -> Result<RecoveryEnergyBalanceEvaluationReceiptV3> {
    validate_ledger(ledger)?;
    let signed_residual_j = ledger.current_mechanical_energy_j
        - ledger.initial_mechanical_energy_j
        - ledger.cumulative_applied_actuator_work_j
        - ledger.cumulative_signed_external_work_j
        - ledger.cumulative_signed_constraint_exchange_j
        - ledger.cumulative_signed_discrete_staging_exchange_j
        + ledger.cumulative_passive_dissipation_j;
    finite(signed_residual_j, "recovery_energy_v3.signed_residual_j")?;
    let absolute_residual_j = signed_residual_j.abs();
    finite(
        absolute_residual_j,
        "recovery_energy_v3.absolute_residual_j",
    )?;
    Ok(RecoveryEnergyBalanceEvaluationReceiptV3 {
        schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V3_VERSION.to_owned(),
        support_status: RecoveryEnergyBalanceSupportStatusV1::SupportedExact,
        equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID.to_owned(),
        ledger_sha256: digest_serializable(ledger)?,
        signed_residual_j,
        absolute_residual_j,
        threshold_applied: false,
        physical_result: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

pub fn evaluate_recovery_energy_balance_v3(
    request: RecoveryEnergyBalanceEvaluationRequestV3,
) -> Result<RecoveryEnergyBalanceEvaluationReceiptV3> {
    if request.schema_version != RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_evaluation_request_v3_version".to_owned(),
        ));
    }
    evaluate_ledger(&request.ledger)
}

pub fn aggregate_recovery_energy_balance_v3(
    request: RecoveryEnergyBalanceAggregationRequestV3,
) -> Result<RecoveryEnergyBalanceAggregationReceiptV3> {
    if request.schema_version != RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_aggregation_request_v3_version".to_owned(),
        ));
    }
    validate_profile_id(&request.source_profile_id)?;
    finite(
        request.initial_mechanical_energy_j,
        "recovery_energy_v3.initial_mechanical_energy_j",
    )?;
    finite(
        request.current_mechanical_energy_j,
        "recovery_energy_v3.current_mechanical_energy_j",
    )?;
    if request.ordered_increments.is_empty() {
        return Err(CoreError::Schema(
            "recovery_energy_v3_requires_increment".to_owned(),
        ));
    }

    let first_sequence_index = request.ordered_increments[0].sequence_index;
    let first_semantic_step = request.ordered_increments[0].semantic_step;
    let mut prior_sequence = None;
    let mut prior_semantic_step = None;
    let mut actuator = 0.0;
    let mut external = 0.0;
    let mut constraint = 0.0;
    let mut staging = 0.0;
    let mut passive = 0.0;
    for increment in &request.ordered_increments {
        if increment.sequence_index > MAX_EXACT_JSON_INTEGER
            || increment.semantic_step > MAX_EXACT_JSON_INTEGER
        {
            return Err(CoreError::Schema(
                "recovery_energy_v3_step_identity_outside_exact_json_range".to_owned(),
            ));
        }
        if let Some(previous) = prior_sequence
            && increment.sequence_index != previous + 1
        {
            return Err(CoreError::Order(
                "recovery_energy_v3_sequence_not_contiguous".to_owned(),
            ));
        }
        if let Some(previous) = prior_semantic_step
            && (increment.semantic_step < previous || increment.semantic_step > previous + 1)
        {
            return Err(CoreError::Order(
                "recovery_energy_v3_semantic_steps_not_monotonic".to_owned(),
            ));
        }
        if !increment.source_measurement {
            return Err(CoreError::Schema(
                "recovery_energy_v3_increment_source_measurement_required".to_owned(),
            ));
        }
        if increment.passive_dissipation_j < 0.0 {
            return Err(CoreError::Schema(
                "recovery_energy_v3_passive_dissipation_negative".to_owned(),
            ));
        }
        add_finite(&mut actuator, increment.applied_actuator_work_j, "actuator")?;
        add_finite(&mut external, increment.signed_external_work_j, "external")?;
        add_finite(
            &mut constraint,
            increment.signed_constraint_exchange_j,
            "constraint",
        )?;
        add_finite(
            &mut staging,
            increment.signed_discrete_staging_exchange_j,
            "discrete_staging",
        )?;
        add_finite(&mut passive, increment.passive_dissipation_j, "passive")?;
        prior_sequence = Some(increment.sequence_index);
        prior_semantic_step = Some(increment.semantic_step);
    }

    let source_values_sha256 = digest_serializable(&request.ordered_increments)?;
    let ledger = RecoveryEnergyBalanceLedgerV3 {
        schema_version: RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION.to_owned(),
        equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID.to_owned(),
        component_partition_id: RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID.to_owned(),
        source_profile_id: request.source_profile_id,
        source_values_sha256: source_values_sha256.clone(),
        initial_mechanical_energy_j: request.initial_mechanical_energy_j,
        current_mechanical_energy_j: request.current_mechanical_energy_j,
        cumulative_applied_actuator_work_j: actuator,
        cumulative_signed_external_work_j: external,
        cumulative_signed_constraint_exchange_j: constraint,
        cumulative_signed_discrete_staging_exchange_j: staging,
        cumulative_passive_dissipation_j: passive,
        source_measurement: true,
    };
    let evaluation = evaluate_ledger(&ledger)?;
    let ledger_sha256 = evaluation.ledger_sha256.clone();
    let last_sequence_index = prior_sequence.ok_or_else(|| {
        CoreError::Internal("recovery_energy_v3_final_sequence_missing".to_owned())
    })?;
    let last_semantic_step = prior_semantic_step
        .ok_or_else(|| CoreError::Internal("recovery_energy_v3_final_step_missing".to_owned()))?;
    Ok(RecoveryEnergyBalanceAggregationReceiptV3 {
        schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V3_VERSION.to_owned(),
        support_status: RecoveryEnergyBalanceSupportStatusV1::SupportedExact,
        increment_count: request.ordered_increments.len(),
        first_sequence_index,
        last_sequence_index,
        first_semantic_step,
        last_semantic_step,
        ordered_source_values_sha256: source_values_sha256,
        ledger_sha256,
        ledger,
        evaluation,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request() -> RecoveryEnergyBalanceAggregationRequestV3 {
        RecoveryEnergyBalanceAggregationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION.to_owned(),
            source_profile_id: "r24d52_zero_world_staging_fixture_v1".to_owned(),
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: 11.875,
            ordered_increments: vec![
                RecoveryEnergyWorkIncrementV3 {
                    sequence_index: 0,
                    semantic_step: 7,
                    applied_actuator_work_j: 4.0,
                    signed_external_work_j: 1.0,
                    signed_constraint_exchange_j: 2.0,
                    signed_discrete_staging_exchange_j: 0.5,
                    passive_dissipation_j: 0.5,
                    source_measurement: true,
                },
                RecoveryEnergyWorkIncrementV3 {
                    sequence_index: 1,
                    semantic_step: 8,
                    applied_actuator_work_j: -0.5,
                    signed_external_work_j: -0.25,
                    signed_constraint_exchange_j: -3.0,
                    signed_discrete_staging_exchange_j: -0.125,
                    passive_dissipation_j: 1.25,
                    source_measurement: true,
                },
            ],
        }
    }

    #[test]
    fn staging_is_a_separate_signed_channel_used_once() {
        let receipt = aggregate_recovery_energy_balance_v3(request()).unwrap();
        assert_eq!(
            receipt.ledger.cumulative_signed_discrete_staging_exchange_j,
            0.375
        );
        assert_eq!(receipt.ledger.cumulative_signed_external_work_j, 0.75);
        assert_eq!(receipt.ledger.cumulative_passive_dissipation_j, 1.75);
        assert_eq!(receipt.evaluation.signed_residual_j, 0.0);

        let mut omitted = request();
        for increment in &mut omitted.ordered_increments {
            increment.signed_discrete_staging_exchange_j = 0.0;
        }
        assert_eq!(
            aggregate_recovery_energy_balance_v3(omitted)
                .unwrap()
                .evaluation
                .signed_residual_j,
            0.375
        );
    }

    #[test]
    fn invalid_order_measurement_finiteness_and_dissipation_fail_closed() {
        let mut reordered = request();
        reordered.ordered_increments[1].sequence_index = 3;
        assert!(aggregate_recovery_energy_balance_v3(reordered).is_err());

        let mut unmeasured = request();
        unmeasured.ordered_increments[0].source_measurement = false;
        assert!(aggregate_recovery_energy_balance_v3(unmeasured).is_err());

        let mut nonfinite = request();
        nonfinite.ordered_increments[0].signed_discrete_staging_exchange_j = f64::NAN;
        assert!(aggregate_recovery_energy_balance_v3(nonfinite).is_err());

        let mut negative_passive = request();
        negative_passive.ordered_increments[0].passive_dissipation_j = -0.1;
        assert!(aggregate_recovery_energy_balance_v3(negative_passive).is_err());
    }
}
