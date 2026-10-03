//! Development-only passive descent and one-time measured prone handoff.
//!
//! This is an additive entry path, not a longer ConfirmProne timeout. It owns
//! no world, emits no motor command, and never repairs an existing supervisor.
//! The host must retain the declaration, observations, increments and receipts
//! under a fresh attempt and enforce single-writer consumption of the state.

use super::*;
use crate::recovery_energy_v3::RecoveryEnergyWorkIncrementV3;
pub mod native_epoch;
use native_epoch::RecoveryPassiveNativeEnergyTotalsV1;

pub const PASSIVE_ENTRY_DECLARATION_V1: &str = "sporespore_recovery_passive_entry_declaration_v1";
pub const PASSIVE_ENTRY_REQUEST_V1: &str = "sporespore_recovery_passive_entry_request_v1";
pub const PASSIVE_ENTRY_MEMORY_V1: &str = "sporespore_recovery_passive_entry_memory_v1";
pub const PASSIVE_ENTRY_RECEIPT_V1: &str = "sporespore_recovery_passive_entry_receipt_v1";
const MAX_EXACT_JSON_INTEGER: u64 = 9_007_199_254_740_991;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveEntryDeclarationV1 {
    pub schema_version: String,
    pub attempt_id: String,
    pub initialization: RecoveryInitializeRequestV2,
    pub first_semantic_step: u64,
    pub first_host_step_before: u64,
    /// Explicit diagnostic bound, capped by the existing total resource budget.
    /// The caller still owes an adequacy argument for the selected duration.
    pub maximum_descent_steps: u32,
    /// The already-retained kick-boundary ledger. Never replace it with a
    /// ledger rebased at the later prone/get-up control boundary.
    pub energy_at_boundary: RecoveryEnergyBalanceLedgerV3,
    pub energy_boundary_sequence_index: u64,
    pub energy_partition_authority: Option<RecoveryEnergyPartitionAuthorityV1>,
    /// Optional explicit global-offset accounting, matching the Godot epoch
    /// producer. Omitted legacy requests keep ordered-local-increment semantics.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub native_global_energy_at_boundary: Option<RecoveryPassiveNativeEnergyTotalsV1>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryPassiveEntryStatusV1 {
    WaitingForProne,
    ProneHandoff,
    DescentTimeout,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveEntryMemoryV1 {
    pub schema_version: String,
    pub declaration_sha256: String,
    pub status: RecoveryPassiveEntryStatusV1,
    pub observations_seen: u32,
    pub last_semantic_step: u64,
    pub last_host_step_after: u64,
    pub last_observation_sha256: String,
    pub last_energy_ledger: RecoveryEnergyBalanceLedgerV3,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_native_global_energy: Option<RecoveryPassiveNativeEnergyTotalsV1>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveEntryStepRequestV1 {
    pub schema_version: String,
    pub declaration: RecoveryPassiveEntryDeclarationV1,
    pub prior: Option<RecoveryPassiveEntryMemoryV1>,
    pub observation: RecoveryObservationV3,
    pub energy_increment: RecoveryEnergyWorkIncrementV3,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub native_global_energy: Option<RecoveryPassiveNativeEnergyTotalsV1>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveEntryReceiptV1 {
    pub schema_version: String,
    pub ledger_scope: serde_json::Value,
    pub memory: RecoveryPassiveEntryMemoryV1,
    pub classification: RecoveryPoseClassificationV1,
    /// Exists only at the first measured prone sample. It is a NEW memory,
    /// with one real confirmation sample, not a modified old get-up attempt.
    pub canonical_memory: Option<RecoverySupervisorMemoryV1>,
    pub canonical_initialization_count: u32,
    pub controller_command_emitted: bool,
    pub energy_epoch_reset: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

fn require(condition: bool, reason: &str) -> Result<()> {
    if condition {
        Ok(())
    } else {
        Err(CoreError::Frame(reason.to_owned()))
    }
}

/// Validate supplied observations and advance only the passive-entry state.
/// Existing initialize/step/evaluate APIs retain their original semantics.
pub fn step_passive_entry_v1(
    request: RecoveryPassiveEntryStepRequestV1,
) -> Result<RecoveryPassiveEntryReceiptV1> {
    require(
        request.schema_version == PASSIVE_ENTRY_REQUEST_V1,
        "passive_entry_request_version",
    )?;
    let declaration = &request.declaration;
    let init = &declaration.initialization;
    require(
        declaration.schema_version == PASSIVE_ENTRY_DECLARATION_V1
            && valid_id(&declaration.attempt_id)
            && init.schema_version == RECOVERY_INITIALIZE_REQUEST_V2_VERSION
            && init.arm_kind == RecoveryArmKindV1::CandidateCommand,
        "passive_entry_declaration_identity",
    )?;
    let context = match context_for(
        &init.task_id,
        &init.semantics_id,
        &init.actuator_profile_id,
        &init.threshold_profile_id,
        init.descriptor.clone(),
        Some(&init.morphology_context),
        &init.adapter_capability,
    )? {
        RecoveryContextResolution::Supported(value) => *value,
        RecoveryContextResolution::Refused { reason, .. } => {
            return Err(CoreError::Frame(format!(
                "passive_entry_context_refused:{reason}"
            )));
        }
    };
    let limit = u64::from(declaration.maximum_descent_steps);
    require(
        limit > 0
            && limit <= u64::from(context.threshold_profile.total_timeout_steps)
            && declaration.first_semantic_step > 0
            && declaration.first_semantic_step <= MAX_EXACT_JSON_INTEGER - limit
            && declaration.first_host_step_before <= MAX_EXACT_JSON_INTEGER - limit
            && declaration.energy_boundary_sequence_index <= MAX_EXACT_JSON_INTEGER - limit,
        "passive_entry_bounds_invalid",
    )?;
    let declaration_sha256 = digest_serializable(declaration)?;
    evaluate_recovery_energy_balance_v3(RecoveryEnergyBalanceEvaluationRequestV3 {
        schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION.to_owned(),
        ledger: declaration.energy_at_boundary.clone(),
    })?;
    let (seen, previous_energy) = if let Some(prior) = &request.prior {
        require(
            prior.schema_version == PASSIVE_ENTRY_MEMORY_V1
                && prior.declaration_sha256 == declaration_sha256
                && prior.status == RecoveryPassiveEntryStatusV1::WaitingForProne
                && prior.observations_seen > 0
                && prior.observations_seen < declaration.maximum_descent_steps,
            "passive_entry_prior_identity_or_terminal",
        )?;
        let count = u64::from(prior.observations_seen);
        require(
            prior.last_semantic_step == declaration.first_semantic_step + count - 1
                && prior.last_host_step_after == declaration.first_host_step_before + count,
            "passive_entry_prior_sequence",
        )?;
        require_digest(
            &prior.last_observation_sha256,
            "passive_entry_last_observation_digest",
        )?;
        evaluate_recovery_energy_balance_v3(RecoveryEnergyBalanceEvaluationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION.to_owned(),
            ledger: prior.last_energy_ledger.clone(),
        })?;
        (count, &prior.last_energy_ledger)
    } else {
        (0, &declaration.energy_at_boundary)
    };
    let observation = &request.observation;
    require(
        observation.semantic_step == declaration.first_semantic_step + seen
            && observation.engine_step_identity.host_step_before
                == declaration.first_host_step_before + seen,
        "passive_entry_observation_sequence",
    )?;
    let residual = validate_observation_for_scope(
        observation,
        init.arm_kind,
        None,
        request.prior.as_ref().map(|v| v.last_semantic_step),
        &context,
    )
    .map_err(CoreError::Frame)?;
    // The published zero_command flag identifies the arm, not whether these
    // particular motors applied zero. Check the measured motor population.
    require(
        observation
            .applied_actuation
            .ordered_applied_impulses
            .iter()
            .all(|v| v.applied_angular_impulse_nms == 0.0),
        "passive_entry_nonzero_motor_impulse",
    )?;
    if context.threshold_profile.physical_threshold_authority {
        let authority = declaration
            .energy_partition_authority
            .as_ref()
            .ok_or_else(|| {
                CoreError::Frame("passive_entry_native_energy_authority_missing".to_owned())
            })?;
        validate_recovery_energy_partition_authority_v1(
            authority,
            observation,
            &init.adapter_capability,
        )?;
        require(
            authority.component_partition_complete && authority.exact_balance_safety_authority,
            "passive_entry_native_energy_partition_incomplete",
        )?;
    } else {
        require(
            declaration.energy_partition_authority.is_none(),
            "passive_entry_synthetic_authority_mismatch",
        )?;
    }

    let energy = &observation.energy_balance;
    let increment = &request.energy_increment;
    require(
        increment.source_measurement
            && increment.sequence_index == declaration.energy_boundary_sequence_index + seen + 1
            && increment.semantic_step == observation.semantic_step
            && increment.applied_actuator_work_j == 0.0
            && increment.passive_dissipation_j >= 0.0,
        "passive_entry_increment_identity_or_actuation",
    )?;
    require(
        energy.initial_mechanical_energy_j.to_bits()
            == declaration
                .energy_at_boundary
                .initial_mechanical_energy_j
                .to_bits()
            && previous_energy.initial_mechanical_energy_j.to_bits()
                == energy.initial_mechanical_energy_j.to_bits()
            && energy.source_profile_id == declaration.energy_at_boundary.source_profile_id
            && energy.component_partition_id
                == declaration.energy_at_boundary.component_partition_id
            && energy.equation_id == declaration.energy_at_boundary.equation_id
            && previous_energy.source_profile_id == energy.source_profile_id
            && previous_energy.component_partition_id == energy.component_partition_id
            && previous_energy.equation_id == energy.equation_id,
        "passive_entry_energy_epoch_changed",
    )?;
    let native_offset_projection = native_epoch::validate_projection(&request)?;
    for (index, (prior, delta, current)) in [
        (
            previous_energy.cumulative_applied_actuator_work_j,
            increment.applied_actuator_work_j,
            energy.cumulative_applied_actuator_work_j,
        ),
        (
            previous_energy.cumulative_signed_external_work_j,
            increment.signed_external_work_j,
            energy.cumulative_signed_external_work_j,
        ),
        (
            previous_energy.cumulative_signed_constraint_exchange_j,
            increment.signed_constraint_exchange_j,
            energy.cumulative_signed_constraint_exchange_j,
        ),
        (
            previous_energy.cumulative_signed_discrete_staging_exchange_j,
            increment.signed_discrete_staging_exchange_j,
            energy.cumulative_signed_discrete_staging_exchange_j,
        ),
        (
            previous_energy.cumulative_passive_dissipation_j,
            increment.passive_dissipation_j,
            energy.cumulative_passive_dissipation_j,
        ),
    ]
    .into_iter()
    .enumerate()
    {
        if native_offset_projection && index != 3 {
            // Already checked using the actual global accumulator followed by
            // fixed-offset subtraction. Staging is still accumulated locally.
            continue;
        }
        // Match the existing ordered aggregation arithmetic. No tolerance or
        // residual-derived correction can hide a reset or a missing increment.
        require(
            delta.is_finite() && (prior + delta).to_bits() == current.to_bits(),
            "passive_entry_energy_increment_discontinuity",
        )?;
    }

    // Reuse the canonical classifier, without inventing an early COM reference.
    let classification = classify_observation(observation.view(), None, &context, residual);
    let ready = classification.entry_prone_gate;
    let status = if ready {
        RecoveryPassiveEntryStatusV1::ProneHandoff
    } else if seen + 1 == limit {
        RecoveryPassiveEntryStatusV1::DescentTimeout
    } else {
        RecoveryPassiveEntryStatusV1::WaitingForProne
    };
    let canonical_memory = if ready {
        // This new entry API consumes the genuine owner-none boundary sample.
        // It does not route it through, or rewrite it for, the historical V5
        // step API, which correctly requires recovery ownership in ConfirmProne.
        let mut memory = initialize_recovery_v2(init.clone())?
            .memory
            .ok_or_else(|| CoreError::Frame("passive_entry_initialization_refused".to_owned()))?;
        require(
            context.threshold_profile.entry_prone_confirm_steps > 1,
            "passive_entry_profile_dwell_unsupported",
        )?;
        record_recovery_observation(
            &mut memory,
            observation.semantic_step,
            observation.center_of_mass.position_world_m.y,
        );
        memory.prone_confirm_steps_observed = 1;
        validate_memory(&memory, &context)?;
        Some(memory)
    } else {
        None
    };
    Ok(RecoveryPassiveEntryReceiptV1 {
        schema_version: PASSIVE_ENTRY_RECEIPT_V1.to_owned(),
        ledger_scope: json!({"subsystem": "recovery", "engine_scope": init.adapter_capability.engine,
            "authority_mode": "development_component", "question_class": "development"}),
        memory: RecoveryPassiveEntryMemoryV1 {
            schema_version: PASSIVE_ENTRY_MEMORY_V1.to_owned(),
            declaration_sha256,
            status,
            observations_seen: (seen + 1) as u32,
            last_semantic_step: observation.semantic_step,
            last_host_step_after: observation.engine_step_identity.host_step_after,
            last_observation_sha256: digest_serializable(observation)?,
            last_energy_ledger: energy.clone(),
            last_native_global_energy: request.native_global_energy.clone(),
        },
        classification,
        canonical_memory,
        canonical_initialization_count: u32::from(ready),
        controller_command_emitted: false,
        energy_epoch_reset: false,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}
