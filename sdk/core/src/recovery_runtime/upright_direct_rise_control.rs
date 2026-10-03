//! R10R changes only the upright raise law: V20 support, V12 rise, V7 stance.
//! The original upright task still owns every threshold, clock and energy check.
use super::*;
use crate::recovery::upright_recovery as upright;
use super::partial_fall_control::{plan_verified_phase, representations_agree};

pub const STEP_CONTROL_REQUEST: &str = "sporespore_r10r_upright_direct_rise_step_control_request_v1";
pub const COMPOSITION: &str = "sporespore_r10r_upright_v20_v12_v7_control_composition_v1";
pub type StepControlRequest = super::upright_recovery_control::StepControlRequest;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepControlReceipt {
    pub schema_version: String,
    pub control_composition_id: String,
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

fn require(value: bool, code: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("r10r_upright_control_{code}"))) }
}

pub(super) fn plan(descriptor: &BoundedQuadrupedDescriptor, observation: &RecoveryObservationV3,
    phase: RecoveryPhaseV1, phase_step: u32) -> Result<Option<RecoveryControlReceiptV1>> {
    if phase != RecoveryPhaseV1::RaiseBody {
        return plan_verified_phase(descriptor, observation, phase, phase_step);
    }
    // Use the existing V12 implementation and label its actual controller.
    // No observation or supervisor is rewritten to obtain the alternate law.
    let profile = recovery_development_profile_v12();
    let context = RecoveryControlPlanContext { controller_id: EXACT_S169_RECOVERY_CONTROLLER_V12_ID,
        phase_step, descriptor, arm_kind: RecoveryArmKindV1::CandidateCommand, phase,
        semantic_step: observation.semantic_step,
        ordered_joint_observations: &observation.state.ordered_joint_observations,
        base_orientation: observation.state.base_pose_world.orientation_xyzw };
    let profile_sha256 = digest_serializable(&profile)?;
    build_recovery_control_receipt(&context, Some(digest_serializable(observation)?), profile, profile_sha256).map(Some)
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
    let controller_matches = match request.collection.phase {
        RecoveryPhaseV1::EstablishDistalSupport => owner.recovery_controller_id.as_deref() == Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID),
        RecoveryPhaseV1::RaiseBody => owner.recovery_controller_id.as_deref() == Some(EXACT_S169_RECOVERY_CONTROLLER_V12_ID),
        RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell =>
            owner.stance_controller_id.as_deref() == Some(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)),
        _ => false,
    };
    require(controller_matches, "controller_selection")?;
    representations_agree(&request.collection.observation, &request.step.observation)?;
    let collected = collect_native_observation_v3_for_task(request.collection.clone(), false, NativeTaskScope::Upright)?;
    require(collected.support_status == RecoverySupportStatusV1::SupportedExact
        && collected.supplied_native_post_step_observation_validated, "native_collection_refused")?;
    let step = upright::step(request.step.clone())?;
    let control = plan(&init.descriptor, &request.step.observation, step.next_phase, step.memory.phase_steps_observed)?;
    Ok(StepControlReceipt { schema_version: "sporespore_r10r_upright_direct_rise_step_control_receipt_v1".to_owned(),
        control_composition_id: COMPOSITION.to_owned(), request_sha256: digest_serializable(&request)?,
        collection: collected, step, next_control: control, original_observation_rewritten: false,
        canonical_supervisor_synthesized: false, world_build_count: 0, solver_step_count: 0,
        physical_acceptance_authority: false, release_authority: false })
}
