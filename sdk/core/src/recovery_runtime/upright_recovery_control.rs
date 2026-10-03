//! Source-verified R10Q upright task using unchanged V20 and V7 actuation.
use super::*;
use crate::recovery::upright_recovery as upright;
use super::partial_fall_control as original;
use super::partial_fall_control::{plan_verified_phase, representations_agree};
use super::passive_entry_collection::RecoveryPassiveNativeCollectionRequestV1;

pub const ENTRY_CONTROL_REQUEST: &str = "sporespore_r10q_upright_entry_control_request_v1";
pub const STEP_CONTROL_REQUEST: &str = "sporespore_upright_recovery_step_control_request_v1";

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("upright_control_{code}"))) }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlRequest {
    pub schema_version: String,
    pub entry: upright::EntryRequest,
    pub collection: RecoveryPassiveNativeCollectionRequestV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlReceipt {
    pub schema_version: String,
    pub request_sha256: String,
    /// This is the actual unchanged source-verified original API result.
    pub original_control: original::EntryControlReceipt,
    pub entry: upright::EntryReceipt,
    pub initial_upright_control: Option<RecoveryControlReceiptV1>,
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
    let original_control = original::entry_control(original::EntryControlRequest {
        schema_version: original::ENTRY_CONTROL_REQUEST.to_owned(),
        entry: request.entry.original_request.clone(), collection: request.collection.clone() })?;
    let entry = upright::select_entry(request.entry.clone())?;
    require(entry.original_entry == original_control.entry, "original_entry_crossed")?;
    let passive = &request.entry.original_request.passive_request;
    let control = if let Some(memory) = &entry.upright_memory {
        plan_verified_phase(&passive.declaration.initialization.descriptor, &passive.observation,
            memory.phase, memory.phase_steps_observed)?
    } else { None };
    Ok(EntryControlReceipt { schema_version: "sporespore_r10q_upright_entry_control_receipt_v1".to_owned(),
        request_sha256: digest_serializable(&request)?, original_control, entry,
        initial_upright_control: control, original_observation_rewritten: false,
        canonical_supervisor_synthesized: false, partial_supervisor_synthesized: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlRequest {
    pub schema_version: String,
    pub collection: RecoveryNativeCollectionRequestV3,
    pub step: upright::StepRequest,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlReceipt {
    pub schema_version: String,
    pub request_sha256: String,
    pub collection: RecoveryNativeCollectionReceiptV2,
    pub step: upright::StepReceipt,
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
    let init = &request.step.declaration.entry_request.original_request.passive_request.declaration.initialization;
    require(request.collection.task_id == upright::TASK && request.collection.semantics_id == upright::SEMANTICS
        && request.collection.actuator_profile_id == init.actuator_profile_id
        && request.collection.descriptor == init.descriptor && request.collection.morphology_context == init.morphology_context
        && request.collection.adapter_capability == init.adapter_capability
        && request.collection.arm_kind == RecoveryArmKindV1::CandidateCommand
        && request.collection.phase == request.step.memory.phase, "step_context_crossed")?;
    let owner = &request.collection.observation.controller_ownership;
    let stance = matches!(request.collection.phase, RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell);
    require(if stance { owner.stance_controller_id.as_deref() == Some(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)) }
        else { owner.recovery_controller_id.as_deref() == Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID) }, "controller_selection")?;
    representations_agree(&request.collection.observation, &request.step.observation)?;
    let collected = collect_native_observation_v3_for_task(request.collection.clone(), false, NativeTaskScope::Upright)?;
    require(collected.support_status == RecoverySupportStatusV1::SupportedExact
        && collected.supplied_native_post_step_observation_validated, "native_collection_refused")?;
    let step = upright::step(request.step.clone())?;
    let control = plan_verified_phase(&init.descriptor, &request.step.observation,
        step.next_phase, step.memory.phase_steps_observed)?;
    Ok(StepControlReceipt { schema_version: "sporespore_upright_recovery_step_control_receipt_v1".to_owned(),
        request_sha256: digest_serializable(&request)?, collection: collected, step, next_control: control,
        original_observation_rewritten: false, canonical_supervisor_synthesized: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}
