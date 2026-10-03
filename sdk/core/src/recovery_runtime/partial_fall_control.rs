//! Source-bound partial-task authority around unchanged V20 and V7 laws.
//! No canonical supervisor receipt is synthesized to obtain a control plan.
use super::*;
use crate::recovery::partial_fall as partial;
use super::passive_entry_collection::{RecoveryPassiveNativeCollectionRequestV1,
    RecoveryPassiveNativeCollectionReceiptV1, collect_passive_native_observation_v1};

pub const ENTRY_CONTROL_REQUEST: &str = "sporespore_r10k_entry_control_request_v1";
pub const STEP_CONTROL_REQUEST: &str = "sporespore_partial_fall_step_control_request_v1";

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("partial_control_{code}"))) }
}

pub(super) fn representations_agree(collection: &RecoveryObservationV2, step: &RecoveryObservationV3) -> Result<()> {
    require(recovery_observation_base_sha256(collection)? == recovery_observation_base_sha256(step)?,
        "observation_base_crossed")?;
    let mut v2 = serde_json::to_value(&collection.energy_balance).map_err(|e| CoreError::Internal(e.to_string()))?;
    let mut v3 = serde_json::to_value(&step.energy_balance).map_err(|e| CoreError::Internal(e.to_string()))?;
    for value in [&mut v2, &mut v3] {
        let object = value.as_object_mut().expect("typed energy ledger");
        for key in ["schema_version", "equation_id", "component_partition_id"] { object.remove(key); }
    }
    v3.as_object_mut().expect("typed V3 ledger").remove("cumulative_signed_discrete_staging_exchange_j");
    require(digest_json(&v2)? == digest_json(&v3)?, "energy_projection_crossed")
}

pub(super) fn plan_verified_phase(descriptor: &BoundedQuadrupedDescriptor, observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1, phase_step: u32) -> Result<Option<RecoveryControlReceiptV1>> {
    let observation_sha256 = digest_serializable(observation)?;
    match phase {
        RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody => {
            let profile = recovery_development_profile_for_controller(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)
                .ok_or_else(|| CoreError::Internal("partial_control_v20_profile_missing".to_owned()))?;
            let context = RecoveryControlPlanContext { controller_id: EXACT_S169_RECOVERY_CONTROLLER_V20_ID,
                phase_step, descriptor, arm_kind: RecoveryArmKindV1::CandidateCommand, phase,
                semantic_step: observation.semantic_step,
                ordered_joint_observations: &observation.state.ordered_joint_observations,
                base_orientation: observation.state.base_pose_world.orientation_xyzw };
            let profile_sha256 = digest_serializable(&profile)?;
            build_recovery_control_receipt(&context, Some(observation_sha256), profile, profile_sha256).map(Some)
        }
        RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell => {
            let mut control = build_base_stance_control_receipt(descriptor, observation.semantic_step,
                phase, phase_step, observation_sha256)?;
            apply_candidate_stance_feedback(&mut control, stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID),
                descriptor, &observation.state.ordered_joint_observations, observation.outer_step_duration_s)?;
            Ok(Some(control))
        }
        RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed => Ok(None),
        _ => Err(CoreError::Frame("partial_control_unregistered_phase".to_owned())),
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlRequest {
    pub schema_version: String,
    pub entry: partial::EntryRequest,
    pub collection: RecoveryPassiveNativeCollectionRequestV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlReceipt {
    pub schema_version: String,
    pub request_sha256: String,
    pub collection: RecoveryPassiveNativeCollectionReceiptV1,
    pub entry: partial::EntryReceipt,
    pub initial_partial_control: Option<RecoveryControlReceiptV1>,
    pub original_observation_rewritten: bool,
    pub canonical_supervisor_synthesized: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn entry_control(request: EntryControlRequest) -> Result<EntryControlReceipt> {
    require(request.schema_version == ENTRY_CONTROL_REQUEST, "entry_schema")?;
    let passive = &request.entry.passive_request;
    let init = &passive.declaration.initialization;
    require(request.collection.task_id == init.task_id && request.collection.semantics_id == init.semantics_id
        && request.collection.actuator_profile_id == init.actuator_profile_id
        && request.collection.descriptor == init.descriptor && request.collection.morphology_context == init.morphology_context
        && request.collection.adapter_capability == init.adapter_capability
        && request.collection.arm_kind == RecoveryArmKindV1::CandidateCommand, "entry_context_crossed")?;
    representations_agree(&request.collection.observation, &passive.observation)?;
    let collected = collect_passive_native_observation_v1(request.collection.clone())?;
    require(collected.collection.support_status == RecoverySupportStatusV1::SupportedExact
        && collected.collection.supplied_native_post_step_observation_validated, "entry_collection_refused")?;
    let entry = partial::select_entry(request.entry.clone())?;
    let control = if let Some(memory) = &entry.partial_memory {
        plan_verified_phase(&init.descriptor, &passive.observation, memory.phase, memory.phase_steps_observed)?
    } else { None };
    Ok(EntryControlReceipt { schema_version: "sporespore_r10k_entry_control_receipt_v1".to_owned(),
        request_sha256: digest_serializable(&request)?, collection: collected, entry, initial_partial_control: control,
        original_observation_rewritten: false, canonical_supervisor_synthesized: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlRequest {
    pub schema_version: String,
    pub collection: RecoveryNativeCollectionRequestV3,
    pub step: partial::StepRequest,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlReceipt {
    pub schema_version: String,
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
    let stance = matches!(request.collection.phase, RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell);
    require(if stance { owner.stance_controller_id.as_deref() == Some(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)) }
        else { owner.recovery_controller_id.as_deref() == Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID) }, "controller_selection")?;
    representations_agree(&request.collection.observation, &request.step.observation)?;
    let collected = collect_native_observation_v3_for_task(request.collection.clone(), false, NativeTaskScope::PartialFall)?;
    require(collected.support_status == RecoverySupportStatusV1::SupportedExact
        && collected.supplied_native_post_step_observation_validated, "native_collection_refused")?;
    let step = partial::step(request.step.clone())?;
    let control = plan_verified_phase(&init.descriptor, &request.step.observation,
        step.next_phase, step.memory.phase_steps_observed)?;
    Ok(StepControlReceipt { schema_version: "sporespore_partial_fall_step_control_receipt_v1".to_owned(),
        request_sha256: digest_serializable(&request)?, collection: collected, step, next_control: control,
        original_observation_rewritten: false, canonical_supervisor_synthesized: false,
        world_build_count: 0, solver_step_count: 0, physical_acceptance_authority: false, release_authority: false })
}
