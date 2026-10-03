//! R10Q upright stabilization is a distinct task from prone or partial falls.
//! Preserve the original passive timeout, measurements, and kick energy epoch.
use super::*;
use super::partial_fall as partial;
use super::passive_entry::native_epoch::{self, RecoveryPassiveNativeEnergyTotalsV1};
use crate::recovery_energy_v3::RecoveryEnergyWorkIncrementV3;

pub const TASK: &str = "sporespore_measured_upright_recovery_to_standing_v1";
pub const SEMANTICS: &str = "sporespore_measured_upright_recovery_semantics_v1";
pub const PROFILE: &str = "sporespore_r10q_exact_s169_upright_thresholds_v1";
pub const ENTRY_REQUEST: &str = "sporespore_r10q_upright_entry_request_v1";
pub const ENTRY_MEMORY: &str = "sporespore_r10q_upright_entry_memory_v1";
pub const DECLARATION: &str = "sporespore_upright_recovery_declaration_v1";
pub const MEMORY: &str = "sporespore_upright_recovery_memory_v1";
pub const STEP_REQUEST: &str = "sporespore_upright_recovery_step_request_v1";
const CONFIRM: u32 = 12;
const ORDER: [RecoveryPhaseV1; 5] = [RecoveryPhaseV1::EstablishDistalSupport,
    RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::StanceDwell,
    RecoveryPhaseV1::Complete];

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("upright_recovery_{code}"))) }
}

pub fn standing_thresholds() -> RecoverySyntheticThresholdProfileV1 {
    let mut profile = partial::prone_thresholds();
    profile.profile_id = PROFILE.to_owned();
    profile.scope = "r10q_distinct_upright_stabilization_absolute_standing_not_relative_com_gain".to_owned();
    // Retained classification still reports COM gain. This task's transitions
    // use absolute body clearance/height and never the relative-gain gate.
    profile.minimum_com_height_gain_m = 0.0;
    profile
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EntryRoute { Waiting, Prone, Partial, Upright, Timeout }

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryMemory {
    pub schema_version: String,
    pub original_memory: partial::EntryMemory,
    pub consecutive_upright_samples: u32,
    pub route: EntryRoute,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryRequest {
    pub schema_version: String,
    pub original_request: partial::EntryRequest,
    pub prior: Option<EntryMemory>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Declaration {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub entry_request: Box<EntryRequest>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Memory {
    pub schema_version: String,
    pub declaration_sha256: String,
    pub phase: RecoveryPhaseV1,
    pub ordered_completed_phases: Vec<RecoveryPhaseV1>,
    pub total_steps_observed: u32,
    pub phase_steps_observed: u32,
    pub standing_samples_observed: u32,
    pub last_semantic_step: u64,
    pub last_host_step_after: u64,
    pub last_observation_sha256: String,
    pub last_energy_ledger: RecoveryEnergyBalanceLedgerV3,
    pub last_native_global_energy: Option<RecoveryPassiveNativeEnergyTotalsV1>,
    pub terminal_failure_code: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryReceipt {
    pub schema_version: String,
    pub original_entry: partial::EntryReceipt,
    pub memory: EntryMemory,
    pub upright_declaration: Option<Declaration>,
    pub upright_memory: Option<Memory>,
    pub energy_epoch_reset: bool,
    pub prone_to_standing_claimed: bool,
    pub partial_fall_standing_claimed: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn select_entry(request: EntryRequest) -> Result<EntryReceipt> {
    require(request.schema_version == ENTRY_REQUEST, "entry_schema")?;
    let prior_count = match (&request.prior, &request.original_request.prior) {
        (None, None) => 0,
        (Some(prior), Some(original)) => {
            require(prior.schema_version == ENTRY_MEMORY && prior.route == EntryRoute::Waiting
                && prior.original_memory == *original
                && prior.consecutive_upright_samples <= CONFIRM
                && prior.consecutive_upright_samples <= original.passive_memory.observations_seen, "entry_prior")?;
            prior.consecutive_upright_samples
        }
        _ => return Err(CoreError::Frame("upright_recovery_entry_prior_population".to_owned())),
    };
    // The original selector remains the source/epoch/clock and branch authority.
    let original = partial::select_entry(request.original_request.clone())?;
    let passive = &original.original_passive_receipt;
    let c = &passive.classification;
    let count = if c.torso_height_ratio > 0.5 && c.torso_up_dot >= 0.95 {
        (prior_count + 1).min(CONFIRM)
    } else { 0 };
    let route = match original.memory.route {
        partial::EntryRoute::Waiting => EntryRoute::Waiting,
        partial::EntryRoute::Prone => EntryRoute::Prone,
        partial::EntryRoute::Partial => EntryRoute::Partial,
        partial::EntryRoute::Timeout if count == CONFIRM => EntryRoute::Upright,
        partial::EntryRoute::Timeout => EntryRoute::Timeout,
    };
    let (declaration, memory) = if route == EntryRoute::Upright {
        require(passive.memory.observations_seen == 240 && passive.canonical_memory.is_none()
            && passive.canonical_initialization_count == 0 && original.partial_memory.is_none()
            && original.partial_declaration.is_none(), "upright_canonical_or_partial_crossing")?;
        let declaration = Declaration { schema_version: DECLARATION.to_owned(), task_id: TASK.to_owned(),
            semantics_id: SEMANTICS.to_owned(), entry_request: Box::new(request.clone()) };
        let memory = Memory { schema_version: MEMORY.to_owned(), declaration_sha256: digest_serializable(&declaration)?,
            phase: RecoveryPhaseV1::EstablishDistalSupport, ordered_completed_phases: vec![],
            total_steps_observed: 0, phase_steps_observed: 0, standing_samples_observed: 0,
            last_semantic_step: passive.memory.last_semantic_step, last_host_step_after: passive.memory.last_host_step_after,
            last_observation_sha256: passive.memory.last_observation_sha256.clone(),
            last_energy_ledger: passive.memory.last_energy_ledger.clone(),
            last_native_global_energy: passive.memory.last_native_global_energy.clone(), terminal_failure_code: None };
        (Some(declaration), Some(memory))
    } else { (None, None) };
    Ok(EntryReceipt { schema_version: "sporespore_r10q_upright_entry_receipt_v1".to_owned(),
        memory: EntryMemory { schema_version: ENTRY_MEMORY.to_owned(), original_memory: original.memory.clone(),
            consecutive_upright_samples: count, route }, original_entry: original,
        upright_declaration: declaration, upright_memory: memory,
        energy_epoch_reset: false, prone_to_standing_claimed: false, partial_fall_standing_claimed: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepRequest {
    pub schema_version: String,
    pub declaration: Declaration,
    pub memory: Memory,
    pub observation: RecoveryObservationV3,
    pub energy_increment: RecoveryEnergyWorkIncrementV3,
    pub native_global_energy: Option<RecoveryPassiveNativeEnergyTotalsV1>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepReceipt {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub request_sha256: String,
    pub observation_sha256: String,
    pub threshold_profile_sha256: String,
    pub prior_phase: RecoveryPhaseV1,
    pub next_phase: RecoveryPhaseV1,
    pub classification: RecoveryPoseClassificationV1,
    pub memory: Memory,
    pub upright_stabilization_complete: bool,
    pub energy_epoch_reset: bool,
    pub prone_to_standing_claimed: bool,
    pub partial_fall_standing_claimed: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

fn validate_phase_memory(memory: &Memory, initial: &Memory) -> Result<()> {
    require(memory.schema_version == MEMORY && memory.declaration_sha256 == initial.declaration_sha256,
        "memory_identity")?;
    require(memory.total_steps_observed < 1200 && memory.terminal_failure_code.is_none()
        && memory.ordered_completed_phases.len() < 4
        && memory.ordered_completed_phases.iter().zip(ORDER).all(|(a,b)| *a == b)
        && memory.phase == ORDER[memory.ordered_completed_phases.len()]
        && memory.phase_steps_observed <= memory.total_steps_observed
        && memory.standing_samples_observed <= memory.phase_steps_observed
        && (memory.phase == RecoveryPhaseV1::StanceDwell || memory.standing_samples_observed == 0), "phase_history")?;
    require(standing_thresholds().per_phase_timeout_steps.for_phase(memory.phase)
        .is_some_and(|limit| memory.phase_steps_observed < limit)
        && memory.standing_samples_observed < 60, "unclosed_terminal_memory")?;
    require(memory.last_semantic_step == initial.last_semantic_step + u64::from(memory.total_steps_observed)
        && memory.last_host_step_after == initial.last_host_step_after + u64::from(memory.total_steps_observed), "memory_clock")?;
    if memory.total_steps_observed == 0 { require(memory == initial, "initial_memory")?; }
    require_digest(&memory.last_observation_sha256, "upright_recovery_last_observation_digest")?;
    Ok(())
}

fn validate_energy(request: &StepRequest) -> Result<()> {
    let passive = &request.declaration.entry_request.original_request.passive_request;
    let origin = &passive.declaration;
    let old = &request.memory.last_energy_ledger;
    let now = &request.observation.energy_balance;
    let delta = &request.energy_increment;
    require(delta.source_measurement && delta.semantic_step == request.observation.semantic_step
        && delta.sequence_index == request.observation.semantic_step - origin.first_semantic_step + 1
        && delta.passive_dissipation_j >= 0.0, "energy_increment_identity")?;
    for ledger in [old, now] {
        require(ledger.initial_mechanical_energy_j.to_bits() == origin.energy_at_boundary.initial_mechanical_energy_j.to_bits()
            && ledger.source_profile_id == origin.energy_at_boundary.source_profile_id
            && ledger.component_partition_id == origin.energy_at_boundary.component_partition_id
            && ledger.equation_id == origin.energy_at_boundary.equation_id, "energy_epoch")?;
        evaluate_recovery_energy_balance_v3(RecoveryEnergyBalanceEvaluationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION.to_owned(), ledger: ledger.clone() })?;
    }
    let global = if let Some(boundary) = &origin.native_global_energy_at_boundary {
        let previous = request.memory.last_native_global_energy.as_ref()
            .ok_or_else(|| CoreError::Frame("upright_recovery_previous_global_missing".to_owned()))?;
        let current = request.native_global_energy.as_ref()
            .ok_or_else(|| CoreError::Frame("upright_recovery_current_global_missing".to_owned()))?;
        native_epoch::validate_global_projection(boundary, previous, current, old, now, delta)?;
        true
    } else {
        require(request.memory.last_native_global_energy.is_none() && request.native_global_energy.is_none(), "undeclared_global_projection")?;
        false
    };
    for (index, (before, increment, after)) in [
        (old.cumulative_applied_actuator_work_j, delta.applied_actuator_work_j, now.cumulative_applied_actuator_work_j),
        (old.cumulative_signed_external_work_j, delta.signed_external_work_j, now.cumulative_signed_external_work_j),
        (old.cumulative_signed_constraint_exchange_j, delta.signed_constraint_exchange_j, now.cumulative_signed_constraint_exchange_j),
        (old.cumulative_signed_discrete_staging_exchange_j, delta.signed_discrete_staging_exchange_j, now.cumulative_signed_discrete_staging_exchange_j),
        (old.cumulative_passive_dissipation_j, delta.passive_dissipation_j, now.cumulative_passive_dissipation_j),
    ].into_iter().enumerate() {
        if global && index != 3 { continue; }
        require(increment.is_finite() && (before + increment).to_bits() == after.to_bits(), "energy_discontinuity")?;
    }
    Ok(())
}

fn transition(memory: &mut Memory, next: RecoveryPhaseV1) {
    memory.ordered_completed_phases.push(memory.phase);
    memory.phase = next;
    memory.phase_steps_observed = 0;
}

pub fn step(request: StepRequest) -> Result<StepReceipt> {
    require(request.schema_version == STEP_REQUEST && request.declaration.schema_version == DECLARATION
        && request.declaration.task_id == TASK && request.declaration.semantics_id == SEMANTICS, "step_identity")?;
    let selected = select_entry((*request.declaration.entry_request).clone())?;
    require(selected.upright_declaration.as_ref() == Some(&request.declaration), "entry_declaration")?;
    let initial = selected.upright_memory.as_ref()
        .ok_or_else(|| CoreError::Frame("upright_recovery_entry_not_upright".to_owned()))?;
    validate_phase_memory(&request.memory, initial)?;
    let passive = &request.declaration.entry_request.original_request.passive_request;
    let init = &passive.declaration.initialization;
    let mut context = match context_for(&init.task_id, &init.semantics_id, &init.actuator_profile_id,
        &init.threshold_profile_id, init.descriptor.clone(), Some(&init.morphology_context), &init.adapter_capability)? {
        RecoveryContextResolution::Supported(value) => *value,
        _ => return Err(CoreError::Frame("upright_recovery_context_refused".to_owned())),
    };
    context.threshold_profile = standing_thresholds();
    context.threshold_profile_sha256 = digest_serializable(&context.threshold_profile)?;
    require(request.observation.semantic_step == request.memory.last_semantic_step + 1
        && request.observation.engine_step_identity.host_step_before == request.memory.last_host_step_after, "step_clock")?;
    let residual = validate_observation_for_named_scope(&request.observation, RecoveryArmKindV1::CandidateCommand,
        Some(request.memory.phase), Some(request.memory.last_semantic_step), &context, TASK, SEMANTICS)
        .map_err(CoreError::Frame)?;
    let authority = passive.declaration.energy_partition_authority.as_ref()
        .ok_or_else(|| CoreError::Frame("upright_recovery_energy_authority_missing".to_owned()))?;
    validate_recovery_energy_partition_authority_v1(authority, &request.observation, &init.adapter_capability)?;
    require(authority.component_partition_complete && authority.exact_balance_safety_authority, "energy_authority_incomplete")?;
    validate_energy(&request)?;
    let classification = classify_observation(request.observation.view(),
        Some(passive.observation.center_of_mass.position_world_m.y), &context, residual);
    let mut memory = request.memory.clone();
    let prior_phase = memory.phase;
    memory.total_steps_observed += 1;
    memory.phase_steps_observed += 1;
    match memory.phase {
        RecoveryPhaseV1::EstablishDistalSupport if classification.distal_support_gate => transition(&mut memory, RecoveryPhaseV1::RaiseBody),
        RecoveryPhaseV1::RaiseBody if classification.safety_gate && classification.no_cheat_gate
            && classification.all_four_distal_sites_bearing && !classification.any_nonfoot_contact
            && classification.minimum_nonfoot_clearance_m >= context.threshold_profile.minimum_nonfoot_clearance_m
            && classification.torso_up_dot >= context.threshold_profile.stance_torso_up_dot_min
            && classification.torso_height_ratio >= context.threshold_profile.stance_height_ratio_min => transition(&mut memory, RecoveryPhaseV1::StanceHandoff),
        RecoveryPhaseV1::StanceHandoff if classification.exclusive_stance_handoff_gate => transition(&mut memory, RecoveryPhaseV1::StanceDwell),
        RecoveryPhaseV1::StanceDwell => {
            memory.standing_samples_observed = if classification.stable_stance_gate {
                memory.standing_samples_observed + 1
            } else { 0 };
            if memory.standing_samples_observed >= 60 { transition(&mut memory, RecoveryPhaseV1::Complete); }
        }
        _ => {}
    }
    if memory.phase != RecoveryPhaseV1::Complete {
        let timeout = context.threshold_profile.per_phase_timeout_steps.for_phase(memory.phase)
            .ok_or_else(|| CoreError::Time("upright_recovery_phase_invalid".to_owned()))?;
        let reason = if memory.total_steps_observed >= 1200 { Some("total_timeout".to_owned()) }
            else if memory.phase_steps_observed >= timeout { Some(format!("phase_timeout:{}", memory.phase.phase_id())) }
            else { None };
        if let Some(reason) = reason { memory.phase = RecoveryPhaseV1::Failed; memory.terminal_failure_code = Some(reason); }
    }
    memory.last_semantic_step = request.observation.semantic_step;
    memory.last_host_step_after = request.observation.engine_step_identity.host_step_after;
    memory.last_observation_sha256 = digest_serializable(&request.observation)?;
    memory.last_energy_ledger = request.observation.energy_balance.clone();
    memory.last_native_global_energy = request.native_global_energy.clone();
    Ok(StepReceipt { schema_version: "sporespore_upright_recovery_step_receipt_v1".to_owned(), task_id: TASK.to_owned(),
        semantics_id: SEMANTICS.to_owned(), request_sha256: digest_serializable(&request)?,
        observation_sha256: memory.last_observation_sha256.clone(), threshold_profile_sha256: context.threshold_profile_sha256,
        prior_phase, next_phase: memory.phase, upright_stabilization_complete: memory.phase == RecoveryPhaseV1::Complete,
        classification, memory, energy_epoch_reset: false, prone_to_standing_claimed: false, partial_fall_standing_claimed: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}
