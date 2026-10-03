//! R10Y partial recovery: measured-pose motion toward neutral in support/rise.
//! The original selector and partial task own all gates, deadlines and energy.
use super::*;
use crate::recovery::partial_fall as partial;
use super::partial_fall_control::{plan_verified_phase, representations_agree};
use super::upright_recovery_control as original_entry;

pub const ENTRY_CONTROL_REQUEST: &str = "sporespore_r10y_partial_direct_neutral_entry_control_request_v1";
pub const STEP_CONTROL_REQUEST: &str = "sporespore_r10y_partial_direct_neutral_step_control_request_v1";
pub const COMPOSITION: &str = "sporespore_r10y_partial_direct_neutral_v21_v7_composition_v1";
pub type EntryControlRequest = original_entry::EntryControlRequest;
pub type StepControlRequest = super::partial_fall_control::StepControlRequest;

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("r10y_partial_control_{code}"))) }
}

pub fn profile() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v12();
    profile.profile_id = "sporespore_exact_s169_partial_direct_neutral_development_v21".to_owned();
    profile.controller_id = EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID.to_owned();
    profile.establish_distal_support_pose.pose_id = "exact_s169_measured_pose_neutral_support_v21".to_owned();
    profile.establish_distal_support_pose.ordered_target_positions_rad =
        profile.stance_pose.ordered_target_positions_rad.clone();
    profile.stance_pose.pose_id = "exact_s169_measured_pose_neutral_rise_v21".to_owned();
    profile
}

pub(super) fn plan(descriptor: &BoundedQuadrupedDescriptor, observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1, phase_step: u32) -> Result<Option<RecoveryControlReceiptV1>> {
    if !matches!(phase, RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody) {
        return plan_verified_phase(descriptor, observation, phase, phase_step);
    }
    let profile = profile();
    // The actual phase clock is retained. Transition restarts the smooth
    // reference from the newly measured pose; no stored or fabricated pose.
    let context = RecoveryControlPlanContext {
        controller_id: EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID,
        phase_step, descriptor, arm_kind: RecoveryArmKindV1::CandidateCommand, phase,
        semantic_step: observation.semantic_step,
        ordered_joint_observations: &observation.state.ordered_joint_observations,
        base_orientation: observation.state.base_pose_world.orientation_xyzw,
    };
    let sha = digest_serializable(&profile)?;
    build_recovery_control_receipt(&context, Some(digest_serializable(observation)?), profile, sha).map(Some)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlReceipt {
    pub schema_version: String,
    pub control_composition_id: String,
    pub request_sha256: String,
    /// Unchanged original selector/control receipt, including the unexecuted
    /// historical V20 plan. Only separately labeled initial_partial_control
    /// may be applied by a prospectively selected R10Y partial worker.
    pub original_entry_control: original_entry::EntryControlReceipt,
    pub initial_partial_control: Option<RecoveryControlReceiptV1>,
    pub original_observation_rewritten: bool,
    pub canonical_supervisor_synthesized: bool,
    pub partial_supervisor_synthesized: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn entry_control(request: EntryControlRequest) -> Result<EntryControlReceipt> {
    require(request.schema_version == ENTRY_CONTROL_REQUEST, "entry_schema")?;
    let original = original_entry::entry_control(original_entry::EntryControlRequest {
        schema_version: original_entry::ENTRY_CONTROL_REQUEST.to_owned(),
        entry: request.entry.clone(), collection: request.collection.clone(),
    })?;
    let passive = &request.entry.original_request.passive_request;
    let control = if let Some(memory) = &original.original_control.entry.partial_memory {
        plan(&passive.declaration.initialization.descriptor, &passive.observation,
            memory.phase, memory.phase_steps_observed)?
    } else { None };
    Ok(EntryControlReceipt {
        schema_version: "sporespore_r10y_partial_direct_neutral_entry_control_receipt_v1".to_owned(),
        control_composition_id: COMPOSITION.to_owned(), request_sha256: digest_serializable(&request)?,
        original_entry_control: original, initial_partial_control: control,
        original_observation_rewritten: false, canonical_supervisor_synthesized: false,
        partial_supervisor_synthesized: false, world_build_count: 0, solver_step_count: 0,
        physical_acceptance_authority: false, release_authority: false,
    })
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlReceipt {
    pub schema_version: String,
    pub control_composition_id: String,
    pub request_sha256: String,
    pub collection: RecoveryNativeCollectionReceiptV2,
    pub step: partial::StepReceipt,
    pub next_control: Option<RecoveryControlReceiptV1>,
    pub original_observation_rewritten: bool,
    pub canonical_supervisor_synthesized: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn step_control(request: StepControlRequest) -> Result<StepControlReceipt> {
    require(request.schema_version == STEP_CONTROL_REQUEST
        && request.collection.schema_version == RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION, "step_schema")?;
    let init = &request.step.declaration.entry_request.passive_request.declaration.initialization;
    require(request.collection.task_id == partial::TASK && request.collection.semantics_id == partial::SEMANTICS
        && request.collection.actuator_profile_id == init.actuator_profile_id
        && request.collection.descriptor == init.descriptor && request.collection.morphology_context == init.morphology_context
        && request.collection.adapter_capability == init.adapter_capability
        && request.collection.arm_kind == RecoveryArmKindV1::CandidateCommand
        && request.collection.phase == request.step.memory.phase, "step_context_crossed")?;
    let owner = &request.collection.observation.controller_ownership;
    let matches = match request.collection.phase {
        RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody =>
            owner.recovery_controller_id.as_deref() == Some(EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID),
        RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell =>
            owner.stance_controller_id.as_deref() == Some(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)),
        _ => false,
    };
    require(matches, "controller_selection")?;
    representations_agree(&request.collection.observation, &request.step.observation)?;
    let collected = collect_native_observation_v3_for_task(request.collection.clone(), false, NativeTaskScope::PartialFall)?;
    require(collected.support_status == RecoverySupportStatusV1::SupportedExact
        && collected.supplied_native_post_step_observation_validated, "native_collection_refused")?;
    let step = partial::step(request.step.clone())?;
    let control = plan(&init.descriptor, &request.step.observation, step.next_phase, step.memory.phase_steps_observed)?;
    Ok(StepControlReceipt {
        schema_version: "sporespore_r10y_partial_direct_neutral_step_control_receipt_v1".to_owned(),
        control_composition_id: COMPOSITION.to_owned(), request_sha256: digest_serializable(&request)?,
        collection: collected, step, next_control: control, original_observation_rewritten: false,
        canonical_supervisor_synthesized: false, world_build_count: 0, solver_step_count: 0,
        physical_acceptance_authority: false, release_authority: false,
    })
}
