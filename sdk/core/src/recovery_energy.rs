//! Versioned engine-neutral recovery energy accounting.
//!
//! QSDK-R24D37 keeps the historical V1 ledger unchanged and introduces an
//! additive V2 boundary. V2 records signed external work and signed constraint
//! exchange independently from nonnegative passive dissipation. This module is
//! pure: it aggregates already-observed values, evaluates the declared balance,
//! and performs explicit migrations without constructing or stepping a world.

use serde::{Deserialize, Serialize};

use crate::canonical::digest_serializable;
use crate::recovery::RecoveryEnergyBalanceLedgerV1;
use crate::schema::{CoreError, Result};

pub const RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION: &str =
    "sporespore_recovery_energy_balance_ledger_v1";
pub const RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION: &str =
    "sporespore_recovery_energy_balance_ledger_v2";
pub const RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_energy_balance_aggregation_request_v2";
pub const RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V2_VERSION: &str =
    "sporespore_recovery_energy_balance_aggregation_receipt_v2";
pub const RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_energy_balance_evaluation_request_v2";
pub const RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V2_VERSION: &str =
    "sporespore_recovery_energy_balance_evaluation_receipt_v2";
pub const RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION: &str =
    "sporespore_recovery_energy_balance_migration_request_v1";
pub const RECOVERY_ENERGY_BALANCE_MIGRATION_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_energy_balance_migration_receipt_v1";
pub const RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID: &str =
    "sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2";
pub const RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID: &str =
    "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2";
pub const RECOVERY_ENERGY_V1_MIGRATION_PROFILE_ID: &str =
    "sporespore_recovery_energy_v1_lossless_zero_exchange_migration_v1";

const MAX_EXACT_JSON_INTEGER: u64 = 9_007_199_254_740_991;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryEnergyBalanceSupportStatusV1 {
    SupportedExact,
    UnsupportedCapability,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryEnergyBalanceMigrationDirectionV1 {
    V1ToV2,
    V2ToV1,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyWorkIncrementV2 {
    pub sequence_index: u64,
    pub semantic_step: u64,
    pub applied_actuator_work_j: f64,
    pub signed_external_work_j: f64,
    pub signed_constraint_exchange_j: f64,
    pub passive_dissipation_j: f64,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceLedgerV2 {
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
    pub cumulative_passive_dissipation_j: f64,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceAggregationRequestV2 {
    pub schema_version: String,
    pub source_profile_id: String,
    pub initial_mechanical_energy_j: f64,
    pub current_mechanical_energy_j: f64,
    pub ordered_increments: Vec<RecoveryEnergyWorkIncrementV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceAggregationReceiptV2 {
    pub schema_version: String,
    pub support_status: RecoveryEnergyBalanceSupportStatusV1,
    pub refusal_reason: Option<String>,
    pub increment_count: usize,
    pub first_sequence_index: u64,
    pub last_sequence_index: u64,
    pub first_semantic_step: u64,
    pub last_semantic_step: u64,
    pub ordered_source_values_sha256: String,
    pub ledger_sha256: String,
    pub ledger: RecoveryEnergyBalanceLedgerV2,
    pub evaluation: RecoveryEnergyBalanceEvaluationReceiptV2,
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
pub struct RecoveryEnergyBalanceEvaluationRequestV2 {
    pub schema_version: String,
    pub ledger: RecoveryEnergyBalanceLedgerV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceEvaluationReceiptV2 {
    pub schema_version: String,
    pub support_status: RecoveryEnergyBalanceSupportStatusV1,
    pub refusal_reason: Option<String>,
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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceMigrationRequestV1 {
    pub schema_version: String,
    pub direction: RecoveryEnergyBalanceMigrationDirectionV1,
    pub source_v1: Option<RecoveryEnergyBalanceLedgerV1>,
    pub source_v2: Option<RecoveryEnergyBalanceLedgerV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceMigrationReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoveryEnergyBalanceSupportStatusV1,
    pub refusal_reason: Option<String>,
    pub direction: RecoveryEnergyBalanceMigrationDirectionV1,
    pub source_schema_version: String,
    pub target_schema_version: String,
    pub source_ledger_sha256: String,
    pub target_ledger_sha256: Option<String>,
    pub target_v1: Option<RecoveryEnergyBalanceLedgerV1>,
    pub target_v2: Option<RecoveryEnergyBalanceLedgerV2>,
    pub numeric_energy_values_lossless: bool,
    pub implicit_migration_used: bool,
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
            "recovery_energy_source_profile_id".to_owned(),
        ))
    } else {
        Ok(())
    }
}

fn validate_v1(ledger: RecoveryEnergyBalanceLedgerV1) -> Result<()> {
    for (value, field) in [
        (
            ledger.initial_mechanical_energy_j,
            "recovery_energy_v1.initial_mechanical_energy_j",
        ),
        (
            ledger.current_mechanical_energy_j,
            "recovery_energy_v1.current_mechanical_energy_j",
        ),
        (
            ledger.cumulative_applied_actuator_work_j,
            "recovery_energy_v1.cumulative_applied_actuator_work_j",
        ),
        (
            ledger.cumulative_external_work_j,
            "recovery_energy_v1.cumulative_external_work_j",
        ),
        (
            ledger.cumulative_dissipated_energy_j,
            "recovery_energy_v1.cumulative_dissipated_energy_j",
        ),
    ] {
        finite(value, field)?;
    }
    if !ledger.source_measurement {
        return Err(CoreError::Schema(
            "recovery_energy_v1_source_measurement_required".to_owned(),
        ));
    }
    if ledger.cumulative_dissipated_energy_j < 0.0 {
        return Err(CoreError::Schema(
            "recovery_energy_v1_dissipation_negative".to_owned(),
        ));
    }
    if ledger.cumulative_external_work_j != 0.0 {
        return Err(CoreError::Capability(
            "recovery_energy_v1_nonzero_external_work_unsupported".to_owned(),
        ));
    }
    Ok(())
}

fn validate_v2(ledger: &RecoveryEnergyBalanceLedgerV2) -> Result<()> {
    if ledger.schema_version != RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_ledger_v2_version".to_owned(),
        ));
    }
    if ledger.equation_id != RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID {
        return Err(CoreError::Identity(
            "recovery_energy_balance_equation_v2".to_owned(),
        ));
    }
    if ledger.component_partition_id != RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID {
        return Err(CoreError::Identity(
            "recovery_energy_component_partition_v2".to_owned(),
        ));
    }
    validate_profile_id(&ledger.source_profile_id)?;
    if !valid_digest(&ledger.source_values_sha256) {
        return Err(CoreError::Digest(
            "recovery_energy_source_values_sha256".to_owned(),
        ));
    }
    for (value, field) in [
        (
            ledger.initial_mechanical_energy_j,
            "recovery_energy_v2.initial_mechanical_energy_j",
        ),
        (
            ledger.current_mechanical_energy_j,
            "recovery_energy_v2.current_mechanical_energy_j",
        ),
        (
            ledger.cumulative_applied_actuator_work_j,
            "recovery_energy_v2.cumulative_applied_actuator_work_j",
        ),
        (
            ledger.cumulative_signed_external_work_j,
            "recovery_energy_v2.cumulative_signed_external_work_j",
        ),
        (
            ledger.cumulative_signed_constraint_exchange_j,
            "recovery_energy_v2.cumulative_signed_constraint_exchange_j",
        ),
        (
            ledger.cumulative_passive_dissipation_j,
            "recovery_energy_v2.cumulative_passive_dissipation_j",
        ),
    ] {
        finite(value, field)?;
    }
    if ledger.cumulative_passive_dissipation_j < 0.0 {
        return Err(CoreError::Schema(
            "recovery_energy_v2_passive_dissipation_negative".to_owned(),
        ));
    }
    if !ledger.source_measurement {
        return Err(CoreError::Schema(
            "recovery_energy_v2_source_measurement_required".to_owned(),
        ));
    }
    Ok(())
}

fn add_finite(total: &mut f64, value: f64, field: &str) -> Result<()> {
    finite(value, field)?;
    *total += value;
    finite(*total, field)
}

fn zero_physics_evaluation(
    ledger: &RecoveryEnergyBalanceLedgerV2,
) -> Result<RecoveryEnergyBalanceEvaluationReceiptV2> {
    validate_v2(ledger)?;
    let signed_residual_j = ledger.current_mechanical_energy_j
        - ledger.initial_mechanical_energy_j
        - ledger.cumulative_applied_actuator_work_j
        - ledger.cumulative_signed_external_work_j
        - ledger.cumulative_signed_constraint_exchange_j
        + ledger.cumulative_passive_dissipation_j;
    finite(signed_residual_j, "recovery_energy_v2.signed_residual_j")?;
    let absolute_residual_j = signed_residual_j.abs();
    finite(
        absolute_residual_j,
        "recovery_energy_v2.absolute_residual_j",
    )?;
    Ok(RecoveryEnergyBalanceEvaluationReceiptV2 {
        schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V2_VERSION.to_owned(),
        support_status: RecoveryEnergyBalanceSupportStatusV1::SupportedExact,
        refusal_reason: None,
        equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID.to_owned(),
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

pub fn evaluate_recovery_energy_balance_v2(
    request: RecoveryEnergyBalanceEvaluationRequestV2,
) -> Result<RecoveryEnergyBalanceEvaluationReceiptV2> {
    if request.schema_version != RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_evaluation_request_v2_version".to_owned(),
        ));
    }
    zero_physics_evaluation(&request.ledger)
}

pub fn aggregate_recovery_energy_balance_v2(
    request: RecoveryEnergyBalanceAggregationRequestV2,
) -> Result<RecoveryEnergyBalanceAggregationReceiptV2> {
    if request.schema_version != RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_aggregation_request_v2_version".to_owned(),
        ));
    }
    validate_profile_id(&request.source_profile_id)?;
    finite(
        request.initial_mechanical_energy_j,
        "recovery_energy_aggregation.initial_mechanical_energy_j",
    )?;
    finite(
        request.current_mechanical_energy_j,
        "recovery_energy_aggregation.current_mechanical_energy_j",
    )?;
    if request.ordered_increments.is_empty() {
        return Err(CoreError::Schema(
            "recovery_energy_aggregation_requires_increment".to_owned(),
        ));
    }

    let first_sequence_index = request.ordered_increments[0].sequence_index;
    let first_semantic_step = request.ordered_increments[0].semantic_step;
    if first_sequence_index > MAX_EXACT_JSON_INTEGER || first_semantic_step > MAX_EXACT_JSON_INTEGER
    {
        return Err(CoreError::Schema(
            "recovery_energy_step_identity_outside_exact_json_range".to_owned(),
        ));
    }
    let mut prior_sequence = None;
    let mut prior_semantic_step = None;
    let mut cumulative_actuator = 0.0;
    let mut cumulative_external = 0.0;
    let mut cumulative_constraint = 0.0;
    let mut cumulative_passive = 0.0;
    for increment in &request.ordered_increments {
        if increment.sequence_index > MAX_EXACT_JSON_INTEGER
            || increment.semantic_step > MAX_EXACT_JSON_INTEGER
        {
            return Err(CoreError::Schema(
                "recovery_energy_step_identity_outside_exact_json_range".to_owned(),
            ));
        }
        if let Some(previous) = prior_sequence
            && increment.sequence_index != previous + 1
        {
            return Err(CoreError::Order(
                "recovery_energy_sequence_not_contiguous".to_owned(),
            ));
        }
        if let Some(previous) = prior_semantic_step
            && (increment.semantic_step < previous || increment.semantic_step > previous + 1)
        {
            return Err(CoreError::Order(
                "recovery_energy_semantic_steps_not_monotonic".to_owned(),
            ));
        }
        if !increment.source_measurement {
            return Err(CoreError::Schema(
                "recovery_energy_increment_source_measurement_required".to_owned(),
            ));
        }
        if increment.passive_dissipation_j < 0.0 {
            return Err(CoreError::Schema(
                "recovery_energy_increment_passive_dissipation_negative".to_owned(),
            ));
        }
        add_finite(
            &mut cumulative_actuator,
            increment.applied_actuator_work_j,
            "recovery_energy_aggregation.applied_actuator_work_j",
        )?;
        add_finite(
            &mut cumulative_external,
            increment.signed_external_work_j,
            "recovery_energy_aggregation.signed_external_work_j",
        )?;
        add_finite(
            &mut cumulative_constraint,
            increment.signed_constraint_exchange_j,
            "recovery_energy_aggregation.signed_constraint_exchange_j",
        )?;
        add_finite(
            &mut cumulative_passive,
            increment.passive_dissipation_j,
            "recovery_energy_aggregation.passive_dissipation_j",
        )?;
        prior_sequence = Some(increment.sequence_index);
        prior_semantic_step = Some(increment.semantic_step);
    }

    let source_values_sha256 = digest_serializable(&request.ordered_increments)?;
    let ledger = RecoveryEnergyBalanceLedgerV2 {
        schema_version: RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION.to_owned(),
        equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID.to_owned(),
        component_partition_id: RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID.to_owned(),
        source_profile_id: request.source_profile_id,
        source_values_sha256: source_values_sha256.clone(),
        initial_mechanical_energy_j: request.initial_mechanical_energy_j,
        current_mechanical_energy_j: request.current_mechanical_energy_j,
        cumulative_applied_actuator_work_j: cumulative_actuator,
        cumulative_signed_external_work_j: cumulative_external,
        cumulative_signed_constraint_exchange_j: cumulative_constraint,
        cumulative_passive_dissipation_j: cumulative_passive,
        source_measurement: true,
    };
    let evaluation = zero_physics_evaluation(&ledger)?;
    let ledger_sha256 = evaluation.ledger_sha256.clone();
    let last_sequence_index = prior_sequence.ok_or_else(|| {
        CoreError::Internal("recovery_energy_aggregation_sequence_missing".to_owned())
    })?;
    let last_semantic_step = prior_semantic_step.ok_or_else(|| {
        CoreError::Internal("recovery_energy_aggregation_semantic_step_missing".to_owned())
    })?;
    Ok(RecoveryEnergyBalanceAggregationReceiptV2 {
        schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V2_VERSION.to_owned(),
        support_status: RecoveryEnergyBalanceSupportStatusV1::SupportedExact,
        refusal_reason: None,
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

struct RecoveryEnergyMigrationPayloadV1<'a> {
    source_ledger_sha256: String,
    target_ledger_sha256: Option<String>,
    target_v1: Option<RecoveryEnergyBalanceLedgerV1>,
    target_v2: Option<RecoveryEnergyBalanceLedgerV2>,
    refusal_reason: Option<&'a str>,
}

fn migration_receipt(
    direction: RecoveryEnergyBalanceMigrationDirectionV1,
    source_schema_version: &str,
    target_schema_version: &str,
    payload: RecoveryEnergyMigrationPayloadV1<'_>,
) -> RecoveryEnergyBalanceMigrationReceiptV1 {
    RecoveryEnergyBalanceMigrationReceiptV1 {
        schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_RECEIPT_V1_VERSION.to_owned(),
        support_status: if payload.refusal_reason.is_some() {
            RecoveryEnergyBalanceSupportStatusV1::UnsupportedCapability
        } else {
            RecoveryEnergyBalanceSupportStatusV1::SupportedExact
        },
        refusal_reason: payload.refusal_reason.map(str::to_owned),
        direction,
        source_schema_version: source_schema_version.to_owned(),
        target_schema_version: target_schema_version.to_owned(),
        source_ledger_sha256: payload.source_ledger_sha256,
        target_ledger_sha256: payload.target_ledger_sha256,
        target_v1: payload.target_v1,
        target_v2: payload.target_v2,
        numeric_energy_values_lossless: payload.refusal_reason.is_none(),
        implicit_migration_used: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

pub fn migrate_recovery_energy_balance_v1(
    request: RecoveryEnergyBalanceMigrationRequestV1,
) -> Result<RecoveryEnergyBalanceMigrationReceiptV1> {
    if request.schema_version != RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_balance_migration_request_v1_version".to_owned(),
        ));
    }
    match request.direction {
        RecoveryEnergyBalanceMigrationDirectionV1::V1ToV2 => {
            let source = match (request.source_v1, request.source_v2) {
                (Some(source), None) => source,
                _ => {
                    return Err(CoreError::Schema(
                        "recovery_energy_v1_to_v2_source_shape".to_owned(),
                    ));
                }
            };
            validate_v1(source)?;
            let source_ledger_sha256 = digest_serializable(&source)?;
            let target = RecoveryEnergyBalanceLedgerV2 {
                schema_version: RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION.to_owned(),
                equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID.to_owned(),
                component_partition_id: RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID.to_owned(),
                source_profile_id: RECOVERY_ENERGY_V1_MIGRATION_PROFILE_ID.to_owned(),
                source_values_sha256: source_ledger_sha256.clone(),
                initial_mechanical_energy_j: source.initial_mechanical_energy_j,
                current_mechanical_energy_j: source.current_mechanical_energy_j,
                cumulative_applied_actuator_work_j: source.cumulative_applied_actuator_work_j,
                cumulative_signed_external_work_j: 0.0,
                cumulative_signed_constraint_exchange_j: 0.0,
                cumulative_passive_dissipation_j: source.cumulative_dissipated_energy_j,
                source_measurement: true,
            };
            validate_v2(&target)?;
            let target_ledger_sha256 = digest_serializable(&target)?;
            Ok(migration_receipt(
                request.direction,
                RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION,
                RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
                RecoveryEnergyMigrationPayloadV1 {
                    source_ledger_sha256,
                    target_ledger_sha256: Some(target_ledger_sha256),
                    target_v1: None,
                    target_v2: Some(target),
                    refusal_reason: None,
                },
            ))
        }
        RecoveryEnergyBalanceMigrationDirectionV1::V2ToV1 => {
            let source = match (request.source_v1, request.source_v2) {
                (None, Some(source)) => source,
                _ => {
                    return Err(CoreError::Schema(
                        "recovery_energy_v2_to_v1_source_shape".to_owned(),
                    ));
                }
            };
            validate_v2(&source)?;
            let source_ledger_sha256 = digest_serializable(&source)?;
            if source.cumulative_signed_constraint_exchange_j != 0.0 {
                return Ok(migration_receipt(
                    request.direction,
                    RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
                    RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION,
                    RecoveryEnergyMigrationPayloadV1 {
                        source_ledger_sha256,
                        target_ledger_sha256: None,
                        target_v1: None,
                        target_v2: None,
                        refusal_reason: Some("portable_v1_signed_constraint_work_unrepresentable"),
                    },
                ));
            }
            if source.cumulative_signed_external_work_j != 0.0 {
                return Ok(migration_receipt(
                    request.direction,
                    RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
                    RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION,
                    RecoveryEnergyMigrationPayloadV1 {
                        source_ledger_sha256,
                        target_ledger_sha256: None,
                        target_v1: None,
                        target_v2: None,
                        refusal_reason: Some("portable_v1_nonzero_external_work_unrepresentable"),
                    },
                ));
            }
            let target = RecoveryEnergyBalanceLedgerV1 {
                initial_mechanical_energy_j: source.initial_mechanical_energy_j,
                current_mechanical_energy_j: source.current_mechanical_energy_j,
                cumulative_applied_actuator_work_j: source.cumulative_applied_actuator_work_j,
                cumulative_external_work_j: 0.0,
                cumulative_dissipated_energy_j: source.cumulative_passive_dissipation_j,
                source_measurement: true,
            };
            validate_v1(target)?;
            let target_ledger_sha256 = digest_serializable(&target)?;
            Ok(migration_receipt(
                request.direction,
                RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
                RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION,
                RecoveryEnergyMigrationPayloadV1 {
                    source_ledger_sha256,
                    target_ledger_sha256: Some(target_ledger_sha256),
                    target_v1: Some(target),
                    target_v2: None,
                    refusal_reason: None,
                },
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn aggregation_request() -> RecoveryEnergyBalanceAggregationRequestV2 {
        RecoveryEnergyBalanceAggregationRequestV2 {
            schema_version: RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION.to_owned(),
            source_profile_id: "zero_world_signed_exchange_fixture_v1".to_owned(),
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: 11.5,
            ordered_increments: vec![
                RecoveryEnergyWorkIncrementV2 {
                    sequence_index: 0,
                    semantic_step: 7,
                    applied_actuator_work_j: 4.0,
                    signed_external_work_j: 1.0,
                    signed_constraint_exchange_j: 2.0,
                    passive_dissipation_j: 0.5,
                    source_measurement: true,
                },
                RecoveryEnergyWorkIncrementV2 {
                    sequence_index: 1,
                    semantic_step: 8,
                    applied_actuator_work_j: -0.5,
                    signed_external_work_j: -0.25,
                    signed_constraint_exchange_j: -3.0,
                    passive_dissipation_j: 1.25,
                    source_measurement: true,
                },
            ],
        }
    }

    fn v1_ledger() -> RecoveryEnergyBalanceLedgerV1 {
        RecoveryEnergyBalanceLedgerV1 {
            initial_mechanical_energy_j: 10.0,
            current_mechanical_energy_j: 11.0,
            cumulative_applied_actuator_work_j: 2.0,
            cumulative_external_work_j: 0.0,
            cumulative_dissipated_energy_j: 1.0,
            source_measurement: true,
        }
    }

    #[test]
    fn ordered_aggregation_separates_signed_exchange_and_nonnegative_dissipation() {
        let receipt = aggregate_recovery_energy_balance_v2(aggregation_request()).unwrap();
        assert_eq!(receipt.increment_count, 2);
        assert_eq!(
            (receipt.first_sequence_index, receipt.last_sequence_index),
            (0, 1)
        );
        assert_eq!(
            (receipt.first_semantic_step, receipt.last_semantic_step),
            (7, 8)
        );
        assert_eq!(receipt.ledger.cumulative_applied_actuator_work_j, 3.5);
        assert_eq!(receipt.ledger.cumulative_signed_external_work_j, 0.75);
        assert_eq!(receipt.ledger.cumulative_signed_constraint_exchange_j, -1.0);
        assert_eq!(receipt.ledger.cumulative_passive_dissipation_j, 1.75);
        assert_eq!(receipt.evaluation.signed_residual_j, 0.0);
        assert_eq!(receipt.evaluation.absolute_residual_j, 0.0);
        assert!(!receipt.evaluation.threshold_applied);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
    }

    #[test]
    fn source_order_and_source_values_are_content_addressed() {
        let baseline = aggregate_recovery_energy_balance_v2(aggregation_request()).unwrap();
        let mut mutated = aggregation_request();
        mutated.ordered_increments[1].signed_constraint_exchange_j = -2.5;
        let mutated = aggregate_recovery_energy_balance_v2(mutated).unwrap();
        assert_ne!(
            baseline.ordered_source_values_sha256,
            mutated.ordered_source_values_sha256
        );
        assert_ne!(baseline.ledger_sha256, mutated.ledger_sha256);

        let mut reordered = aggregation_request();
        reordered.ordered_increments.swap(0, 1);
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(reordered),
            Err(CoreError::Order(_))
        ));

        let mut repeated_outer_step = aggregation_request();
        repeated_outer_step.ordered_increments[1].semantic_step = 7;
        let repeated = aggregate_recovery_energy_balance_v2(repeated_outer_step).unwrap();
        assert_eq!(
            (repeated.first_semantic_step, repeated.last_semantic_step),
            (7, 7)
        );

        let mut skipped_outer_step = aggregation_request();
        skipped_outer_step.ordered_increments[1].semantic_step = 9;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(skipped_outer_step),
            Err(CoreError::Order(_))
        ));
    }

    #[test]
    fn aggregation_rejects_unmeasured_nonfinite_or_negative_passive_values() {
        let mut unmeasured = aggregation_request();
        unmeasured.ordered_increments[0].source_measurement = false;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(unmeasured),
            Err(CoreError::Schema(_))
        ));

        let mut negative = aggregation_request();
        negative.ordered_increments[0].passive_dissipation_j = -0.25;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(negative),
            Err(CoreError::Schema(_))
        ));

        let mut nonfinite = aggregation_request();
        nonfinite.ordered_increments[0].signed_constraint_exchange_j = f64::NAN;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(nonfinite),
            Err(CoreError::NonFinite(_))
        ));

        let mut overflowing = aggregation_request();
        overflowing.ordered_increments[0].applied_actuator_work_j = f64::MAX;
        overflowing.ordered_increments[1].applied_actuator_work_j = f64::MAX;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(overflowing),
            Err(CoreError::NonFinite(_))
        ));

        let mut inexact_identity = aggregation_request();
        inexact_identity.ordered_increments[0].sequence_index = MAX_EXACT_JSON_INTEGER + 1;
        assert!(matches!(
            aggregate_recovery_energy_balance_v2(inexact_identity),
            Err(CoreError::Schema(_))
        ));
    }

    #[test]
    fn v1_to_v2_migration_is_explicit_and_lossless_for_the_v1_domain() {
        let source = v1_ledger();
        let receipt = migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
            schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
            direction: RecoveryEnergyBalanceMigrationDirectionV1::V1ToV2,
            source_v1: Some(source),
            source_v2: None,
        })
        .unwrap();
        let target = receipt.target_v2.unwrap();
        assert_eq!(
            receipt.support_status,
            RecoveryEnergyBalanceSupportStatusV1::SupportedExact
        );
        assert!(receipt.numeric_energy_values_lossless);
        assert!(!receipt.implicit_migration_used);
        assert_eq!(target.cumulative_signed_external_work_j, 0.0);
        assert_eq!(target.cumulative_signed_constraint_exchange_j, 0.0);
        assert_eq!(target.cumulative_passive_dissipation_j, 1.0);
        assert_eq!(target.source_values_sha256, receipt.source_ledger_sha256);
    }

    #[test]
    fn zero_exchange_v2_downgrade_is_exact() {
        let migrated =
            migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
                schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
                direction: RecoveryEnergyBalanceMigrationDirectionV1::V1ToV2,
                source_v1: Some(v1_ledger()),
                source_v2: None,
            })
            .unwrap()
            .target_v2
            .unwrap();
        let receipt = migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
            schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
            direction: RecoveryEnergyBalanceMigrationDirectionV1::V2ToV1,
            source_v1: None,
            source_v2: Some(migrated),
        })
        .unwrap();
        assert_eq!(receipt.target_v1, Some(v1_ledger()));
        assert_eq!(receipt.refusal_reason, None);
        assert!(receipt.numeric_energy_values_lossless);
    }

    #[test]
    fn either_sign_of_constraint_exchange_refuses_v1_downgrade() {
        for signed_constraint_exchange_j in [-0.5, 0.5] {
            let mut source = aggregate_recovery_energy_balance_v2(aggregation_request())
                .unwrap()
                .ledger;
            source.cumulative_signed_constraint_exchange_j = signed_constraint_exchange_j;
            let receipt =
                migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
                    schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
                    direction: RecoveryEnergyBalanceMigrationDirectionV1::V2ToV1,
                    source_v1: None,
                    source_v2: Some(source),
                })
                .unwrap();
            assert_eq!(
                receipt.support_status,
                RecoveryEnergyBalanceSupportStatusV1::UnsupportedCapability
            );
            assert_eq!(
                receipt.refusal_reason.as_deref(),
                Some("portable_v1_signed_constraint_work_unrepresentable")
            );
            assert!(receipt.target_v1.is_none());
            assert!(!receipt.numeric_energy_values_lossless);
        }
    }

    #[test]
    fn nonzero_external_work_refuses_v1_downgrade() {
        let mut source = aggregate_recovery_energy_balance_v2(aggregation_request())
            .unwrap()
            .ledger;
        source.cumulative_signed_constraint_exchange_j = 0.0;
        source.cumulative_signed_external_work_j = -0.25;
        let receipt = migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
            schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
            direction: RecoveryEnergyBalanceMigrationDirectionV1::V2ToV1,
            source_v1: None,
            source_v2: Some(source),
        })
        .unwrap();
        assert_eq!(
            receipt.refusal_reason.as_deref(),
            Some("portable_v1_nonzero_external_work_unrepresentable")
        );
        assert!(receipt.target_v1.is_none());
    }

    #[test]
    fn migration_source_shape_and_v1_invariants_fail_closed() {
        let malformed = RecoveryEnergyBalanceMigrationRequestV1 {
            schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
            direction: RecoveryEnergyBalanceMigrationDirectionV1::V1ToV2,
            source_v1: None,
            source_v2: None,
        };
        assert!(matches!(
            migrate_recovery_energy_balance_v1(malformed),
            Err(CoreError::Schema(_))
        ));

        let mut invalid = v1_ledger();
        invalid.cumulative_external_work_j = 0.25;
        assert!(matches!(
            migrate_recovery_energy_balance_v1(RecoveryEnergyBalanceMigrationRequestV1 {
                schema_version: RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION.to_owned(),
                direction: RecoveryEnergyBalanceMigrationDirectionV1::V1ToV2,
                source_v1: Some(invalid),
                source_v2: None,
            }),
            Err(CoreError::Capability(_))
        ));
    }
}
