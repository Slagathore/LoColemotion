//! R10AM composition: validated native observations into support-anchored leveling.
//! The original selector and partial task own all gates, deadlines and energy.
use super::partial_fall_control::{plan_verified_phase, representations_agree};
use super::upright_recovery_control as original_entry;
use super::*;
use crate::recovery::partial_fall as partial;

pub const ENTRY_CONTROL_REQUEST: &str =
    "sporespore_r10am_partial_support_anchored_entry_control_request_v1";
pub const STEP_CONTROL_REQUEST: &str =
    "sporespore_r10am_partial_support_anchored_step_control_request_v1";
pub const COMPOSITION: &str = "sporespore_r10am_partial_support_anchored_v27_v7_composition_v1";
pub type EntryControlRequest = original_entry::EntryControlRequest;
pub type StepControlRequest = super::partial_fall_control::StepControlRequest;

fn require(value: bool, code: &str) -> Result<()> {
    if value {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10am_partial_control_{code}")))
    }
}

pub fn profile() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v12();
    profile.profile_id =
        "sporespore_exact_s169_partial_support_anchored_development_v27".to_owned();
    profile.controller_id = EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_bounded_support_anchored_support_v27".to_owned();
    profile
        .establish_distal_support_pose
        .ordered_target_positions_rad = profile.stance_pose.ordered_target_positions_rad.clone();
    profile.stance_pose.pose_id = "exact_s169_load_gated_support_anchored_v27".to_owned();
    profile
}

pub fn profile_sha256() -> Result<String> {
    let contract: serde_json::Value = serde_json::from_str(include_str!(
        "../../../recovery/r10am_support_anchored_kernel_contract_v1.json"
    ))
    .map_err(|e| CoreError::Internal(e.to_string()))?;
    digest_json(&json!({"profile":profile(),"support_anchored_kernel_contract":contract}))
}

pub(super) fn plan(
    descriptor: &BoundedQuadrupedDescriptor,
    observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
    phase_step: u32,
) -> Result<(
    Option<RecoveryControlReceiptV1>,
    Option<super::partial_support_anchored_control::SupportAnchoredPlan>,
)> {
    if !matches!(
        phase,
        RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody
    ) {
        return Ok((
            plan_verified_phase(descriptor, observation, phase, phase_step)?,
            None,
        ));
    }
    let geometry =
        super::partial_support_anchored_control::reference(descriptor, observation, phase)?;
    let mut command_profile = profile();
    // Both phase destinations are this observation's computed joint reference.
    // The profile identity binds the fixed algorithm contract, not a fabricated
    // source pose. The complete support-anchored plan is retained beside the command.
    command_profile
        .establish_distal_support_pose
        .ordered_target_positions_rad = geometry.ordered_target_positions_rad.to_vec();
    command_profile.stance_pose.ordered_target_positions_rad =
        geometry.ordered_target_positions_rad.to_vec();
    let context = RecoveryControlPlanContext {
        controller_id: EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
        phase_step,
        descriptor,
        arm_kind: RecoveryArmKindV1::CandidateCommand,
        phase,
        semantic_step: observation.semantic_step,
        ordered_joint_observations: &observation.state.ordered_joint_observations,
        base_orientation: observation.state.base_pose_world.orientation_xyzw,
    };
    let control = build_recovery_control_receipt(
        &context,
        Some(digest_serializable(observation)?),
        command_profile,
        profile_sha256()?,
    )?;
    Ok((Some(control), Some(geometry)))
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlReceipt {
    pub schema_version: String,
    pub control_composition_id: String,
    pub request_sha256: String,
    /// Unchanged original selector/control receipt, including the unexecuted
    /// historical V20 plan. Only separately labeled initial_partial_control
    /// may be applied by a prospectively selected R10AM partial worker.
    pub original_entry_control: original_entry::EntryControlReceipt,
    pub initial_partial_control: Option<RecoveryControlReceiptV1>,
    pub initial_load_plan: Option<super::partial_support_anchored_control::SupportAnchoredPlan>,
    pub original_observation_rewritten: bool,
    pub canonical_supervisor_synthesized: bool,
    pub partial_supervisor_synthesized: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn entry_control(request: EntryControlRequest) -> Result<EntryControlReceipt> {
    require(
        request.schema_version == ENTRY_CONTROL_REQUEST,
        "entry_schema",
    )?;
    let original = original_entry::entry_control(original_entry::EntryControlRequest {
        schema_version: original_entry::ENTRY_CONTROL_REQUEST.to_owned(),
        entry: request.entry.clone(),
        collection: request.collection.clone(),
    })?;
    let passive = &request.entry.original_request.passive_request;
    let (control, geometry) = if let Some(memory) = &original.original_control.entry.partial_memory
    {
        plan(
            &passive.declaration.initialization.descriptor,
            &passive.observation,
            memory.phase,
            memory.phase_steps_observed,
        )?
    } else {
        (None, None)
    };
    Ok(EntryControlReceipt {
        schema_version: "sporespore_r10am_partial_support_anchored_entry_control_receipt_v1"
            .to_owned(),
        control_composition_id: COMPOSITION.to_owned(),
        request_sha256: digest_serializable(&request)?,
        original_entry_control: original,
        initial_partial_control: control,
        initial_load_plan: geometry,
        original_observation_rewritten: false,
        canonical_supervisor_synthesized: false,
        partial_supervisor_synthesized: false,
        world_build_count: 0,
        solver_step_count: 0,
        physical_acceptance_authority: false,
        release_authority: false,
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
    pub next_load_plan: Option<super::partial_support_anchored_control::SupportAnchoredPlan>,
    pub original_observation_rewritten: bool,
    pub canonical_supervisor_synthesized: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub fn step_control(request: StepControlRequest) -> Result<StepControlReceipt> {
    require(
        request.schema_version == STEP_CONTROL_REQUEST
            && request.collection.schema_version == RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION,
        "step_schema",
    )?;
    let init = &request
        .step
        .declaration
        .entry_request
        .passive_request
        .declaration
        .initialization;
    require(
        request.collection.task_id == partial::TASK
            && request.collection.semantics_id == partial::SEMANTICS
            && request.collection.actuator_profile_id == init.actuator_profile_id
            && request.collection.descriptor == init.descriptor
            && request.collection.morphology_context == init.morphology_context
            && request.collection.adapter_capability == init.adapter_capability
            && request.collection.arm_kind == RecoveryArmKindV1::CandidateCommand
            && request.collection.phase == request.step.memory.phase,
        "step_context_crossed",
    )?;
    let owner = &request.collection.observation.controller_ownership;
    let matches = match request.collection.phase {
        RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody => {
            owner.recovery_controller_id.as_deref()
                == Some(EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID)
        }
        RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell => {
            owner.stance_controller_id.as_deref()
                == Some(stance_id_for_recovery(
                    EXACT_S169_RECOVERY_CONTROLLER_V20_ID,
                ))
        }
        _ => false,
    };
    require(matches, "controller_selection")?;
    representations_agree(&request.collection.observation, &request.step.observation)?;
    let collected = collect_native_observation_v3_for_task(
        request.collection.clone(),
        false,
        NativeTaskScope::PartialFall,
    )?;
    require(
        collected.support_status == RecoverySupportStatusV1::SupportedExact
            && collected.supplied_native_post_step_observation_validated,
        "native_collection_refused",
    )?;
    let step = partial::step(request.step.clone())?;
    let (control, geometry) = plan(
        &init.descriptor,
        &request.step.observation,
        step.next_phase,
        step.memory.phase_steps_observed,
    )?;
    Ok(StepControlReceipt {
        schema_version: "sporespore_r10am_partial_support_anchored_step_control_receipt_v1"
            .to_owned(),
        control_composition_id: COMPOSITION.to_owned(),
        request_sha256: digest_serializable(&request)?,
        collection: collected,
        step,
        next_control: control,
        next_load_plan: geometry,
        original_observation_rewritten: false,
        canonical_supervisor_synthesized: false,
        world_build_count: 0,
        solver_step_count: 0,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}
