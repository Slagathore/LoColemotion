//! R10DD source-bound finite tracking diagnostic. The unchanged partial task
//! owns classification, energy, deadlines and recovery completion. Exhaustion
//! of this reference is a diagnostic stop and never a substitute task success.
use super::partial_fall_control::representations_agree;
use super::partial_native_reference_control::{LAST_TICK, ReferenceSchedule};
use super::upright_recovery_control as original_entry;
use super::*;
use crate::recovery::partial_fall as partial;

pub const ENTRY_CONTROL_REQUEST: &str =
    "sporespore_r10dd_native_reference_entry_control_request_v1";
pub const STEP_CONTROL_REQUEST: &str = "sporespore_r10dd_native_reference_step_control_request_v1";
pub const COMPOSITION: &str = "sporespore_r10dd_finite_native_reference_v29_composition_v1";
const MEMORY: &str = "sporespore_r10dd_native_reference_memory_v1";
const ENTRY_STEP: u64 = 513;
const ENTRY_TOLERANCE: f64 = 1e-6;
pub type EntryControlRequest = original_entry::EntryControlRequest;

fn require(ok: bool, code: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("r10dd_reference_{code}")))
    }
}

fn entry_contract() -> Result<serde_json::Value> {
    serde_json::from_str(include_str!(
        "../../contracts/r10dd_native_reference_entry_v1.json"
    ))
    .map_err(|e| CoreError::Internal(e.to_string()))
}

pub fn profile() -> RecoveryDevelopmentProfileV1 {
    let mut p = super::partial_progressive_headroom_composition::profile();
    p.profile_id = "sporespore_exact_s169_finite_native_reference_development_v29".into();
    p.controller_id = EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID.into();
    p.establish_distal_support_pose.pose_id = "r10dd_preserved_establishment_v29".into();
    p.stance_pose.pose_id = "r10dd_finite_native_reference_v29".into();
    p
}

pub fn profile_sha256() -> Result<String> {
    let table: serde_json::Value = serde_json::from_str(include_str!(
        "../../contracts/r10dc_native_reference_endpoints_v1.json"
    ))
    .map_err(|e| CoreError::Internal(e.to_string()))?;
    digest_json(
        &json!({"composition":COMPOSITION,"profile":profile(),"reference_table":table,
        "entry_contract":entry_contract()?,"entry_tolerance":ENTRY_TOLERANCE,"last_tick":LAST_TICK}),
    )
}

/// Only available portable physical measurements are compared. Native source,
/// owner, applied-command and energy provenance are validated independently.
fn physical_projection(o: &RecoveryObservationV3) -> serde_json::Value {
    json!({"state":o.state,"center_of_mass":o.center_of_mass,
        "ordered_foot_bearing_observations":o.ordered_foot_bearing_observations,
        "ordered_body_clearance_observations":o.ordered_body_clearance_observations})
}

fn close_value(a: &serde_json::Value, b: &serde_json::Value) -> bool {
    use serde_json::Value;
    match (a, b) {
        (Value::Number(a), Value::Number(b)) => a.as_f64().zip(b.as_f64()).is_some_and(|(a, b)| {
            a.is_finite() && b.is_finite() && (a - b).abs() <= ENTRY_TOLERANCE
        }),
        (Value::Array(a), Value::Array(b)) => {
            a.len() == b.len() && a.iter().zip(b).all(|(a, b)| close_value(a, b))
        }
        (Value::Object(a), Value::Object(b)) => {
            a.len() == b.len()
                && a.iter()
                    .all(|(k, a)| b.get(k).is_some_and(|b| close_value(a, b)))
        }
        _ => a == b,
    }
}

fn admit_entry(d: &BoundedQuadrupedDescriptor, o: &RecoveryObservationV3, step: u64) -> Result<()> {
    let reference = entry_contract()?;
    require(
        serde_json::to_value(d).map_err(|e| CoreError::Internal(e.to_string()))?
            == reference["descriptor"],
        "entry_descriptor",
    )?;
    require(
        o.semantic_step == step && o.outer_step_duration_s == RECOVERY_OUTER_STEP_DURATION_S,
        "entry_clock",
    )?;
    let expected = if step == ENTRY_STEP {
        &reference["raise_entry_projection"]
    } else {
        &reference["setup_entry_projection"]
    };
    require(
        close_value(&physical_projection(o), expected),
        "entry_physical_state",
    )
}

fn command(
    d: &BoundedQuadrupedDescriptor,
    o: &RecoveryObservationV3,
    phase: RecoveryPhaseV1,
    phase_step: u32,
    targets: [f64; 8],
) -> Result<RecoveryControlReceiptV1> {
    let mut p = profile();
    // Equal destinations bypass the generic raise blend without changing that
    // shared law or any prior controller. The actuator cap resolver is unchanged.
    p.establish_distal_support_pose.ordered_target_positions_rad = targets.to_vec();
    p.stance_pose.ordered_target_positions_rad = targets.to_vec();
    let context = RecoveryControlPlanContext {
        controller_id: EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID,
        phase_step,
        descriptor: d,
        arm_kind: RecoveryArmKindV1::CandidateCommand,
        phase,
        semantic_step: o.semantic_step,
        ordered_joint_observations: &o.state.ordered_joint_observations,
        base_orientation: o.state.base_pose_world.orientation_xyzw,
    };
    build_recovery_control_receipt(
        &context,
        Some(digest_serializable(o)?),
        p,
        profile_sha256()?,
    )
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReferenceMemory {
    pub schema_version: String,
    pub declaration_sha256: String,
    pub profile_sha256: String,
    pub entry_observation_sha256: String,
    pub entry_semantic_step: u64,
    pub last_planned_semantic_step: u64,
    pub last_planned_reference_tick: u32,
    pub last_command_sha256: String,
    pub finished: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EntryControlReceipt {
    pub schema_version: String,
    pub control_composition_id: String,
    pub request_sha256: String,
    pub original_entry_control: original_entry::EntryControlReceipt,
    pub initial_partial_control: Option<RecoveryControlReceiptV1>,
    pub reference_memory: Option<ReferenceMemory>,
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
        schema_version: original_entry::ENTRY_CONTROL_REQUEST.into(),
        entry: request.entry.clone(),
        collection: request.collection.clone(),
    })?;
    let passive = &request.entry.original_request.passive_request;
    let control = if let Some(memory) = &original.original_control.entry.partial_memory {
        require(
            memory.phase == RecoveryPhaseV1::EstablishDistalSupport
                && memory.phase_steps_observed == 0,
            "setup_phase",
        )?;
        let descriptor = &passive.declaration.initialization.descriptor;
        admit_entry(descriptor, &passive.observation, ENTRY_STEP - 1)?;
        let geometry = super::partial_progressive_headroom_control::reference(
            descriptor,
            &passive.observation,
            memory.phase,
        )?;
        Some(command(
            descriptor,
            &passive.observation,
            memory.phase,
            0,
            geometry.ordered_target_positions_rad,
        )?)
    } else {
        None
    };
    Ok(EntryControlReceipt {
        schema_version: "sporespore_r10dd_native_reference_entry_control_receipt_v1".into(),
        control_composition_id: COMPOSITION.into(),
        request_sha256: digest_serializable(&request)?,
        original_entry_control: original,
        initial_partial_control: control,
        reference_memory: None,
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
pub struct StepControlRequest {
    pub schema_version: String,
    pub collection: RecoveryNativeCollectionRequestV3,
    pub step: partial::StepRequest,
    pub reference_memory: Option<ReferenceMemory>,
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
    pub next_reference: Option<serde_json::Value>,
    pub reference_memory: Option<ReferenceMemory>,
    pub diagnostic_stop_reason: Option<String>,
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
    let phase = request.step.memory.phase;
    require(
        request.collection.task_id == partial::TASK
            && request.collection.semantics_id == partial::SEMANTICS
            && request.collection.actuator_profile_id == init.actuator_profile_id
            && request.collection.descriptor == init.descriptor
            && request.collection.morphology_context == init.morphology_context
            && request.collection.adapter_capability == init.adapter_capability
            && request.collection.arm_kind == RecoveryArmKindV1::CandidateCommand
            && request.collection.phase == phase,
        "step_context_crossed",
    )?;
    require(
        matches!(
            phase,
            RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody
        ) && request
            .collection
            .observation
            .controller_ownership
            .recovery_controller_id
            .as_deref()
            == Some(EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID),
        "controller_selection",
    )?;
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
    let o = &request.step.observation;
    let mut memory = request.reference_memory.clone();
    if phase == RecoveryPhaseV1::EstablishDistalSupport {
        require(
            memory.is_none()
                && request.step.memory.phase_steps_observed == 0
                && step.next_phase == RecoveryPhaseV1::RaiseBody
                && step.memory.phase_steps_observed == 0,
            "raise_entry_route",
        )?;
        admit_entry(&init.descriptor, o, ENTRY_STEP)?;
        let setup = &request
            .step
            .declaration
            .entry_request
            .passive_request
            .observation;
        admit_entry(&init.descriptor, setup, ENTRY_STEP - 1)?;
        let geometry = super::partial_progressive_headroom_control::reference(
            &init.descriptor,
            setup,
            RecoveryPhaseV1::EstablishDistalSupport,
        )?;
        let expected_setup = command(
            &init.descriptor,
            setup,
            RecoveryPhaseV1::EstablishDistalSupport,
            0,
            geometry.ordered_target_positions_rad,
        )?;
        require(
            expected_setup.command_sha256.as_deref()
                == Some(o.applied_actuation.command_sha256.as_str()),
            "setup_command_crossed",
        )?;
        let joints: Vec<f64> = o
            .state
            .ordered_joint_observations
            .iter()
            .map(|j| j.position_rad.unwrap_or(f64::NAN))
            .collect();
        let joints: [f64; 8] = joints
            .try_into()
            .map_err(|_| CoreError::Frame("r10dd_reference_entry_joint_count".into()))?;
        let schedule = ReferenceSchedule::load()?;
        let _ = schedule.start(joints)?;
    } else {
        let prior = memory
            .as_ref()
            .ok_or_else(|| CoreError::Frame("r10dd_reference_memory_missing".into()))?;
        require(
            prior.schema_version == MEMORY
                && !prior.finished
                && prior.declaration_sha256 == request.step.memory.declaration_sha256
                && prior.profile_sha256 == profile_sha256()?
                && prior.entry_semantic_step == ENTRY_STEP
                && prior.last_planned_reference_tick >= 1
                && prior.last_planned_reference_tick <= LAST_TICK
                && prior.last_planned_semantic_step == request.step.memory.last_semantic_step
                && prior.last_planned_semantic_step
                    == ENTRY_STEP + u64::from(prior.last_planned_reference_tick) - 1
                && request.step.memory.phase_steps_observed + 1
                    == prior.last_planned_reference_tick
                && o.applied_actuation.command_sha256 == prior.last_command_sha256,
            "reference_clock_or_command",
        )?;
    }
    let mut control = None;
    let mut reference = None;
    let mut stop = None;
    if step.next_phase != RecoveryPhaseV1::RaiseBody {
        stop = Some("original_supervisor_phase_transition".into());
    } else if step.memory.phase_steps_observed == LAST_TICK {
        stop = Some("finite_reference_exhausted_not_recovery_completion".into());
    } else {
        let tick = step
            .memory
            .phase_steps_observed
            .checked_add(1)
            .ok_or_else(|| CoreError::Frame("r10dd_reference_tick_overflow".into()))?;
        let point = ReferenceSchedule::load()?.reference_at(tick)?;
        let next = command(
            &init.descriptor,
            o,
            step.next_phase,
            step.memory.phase_steps_observed,
            point.ordered_target_positions_rad,
        )?;
        let entry_sha = memory
            .as_ref()
            .map(|m| m.entry_observation_sha256.clone())
            .unwrap_or(digest_serializable(o)?);
        memory = Some(ReferenceMemory {
            schema_version: MEMORY.into(),
            declaration_sha256: step.memory.declaration_sha256.clone(),
            profile_sha256: profile_sha256()?,
            entry_observation_sha256: entry_sha,
            entry_semantic_step: ENTRY_STEP,
            last_planned_semantic_step: o.semantic_step,
            last_planned_reference_tick: tick,
            last_command_sha256: next
                .command_sha256
                .clone()
                .ok_or_else(|| CoreError::Frame("r10dd_reference_command_refused".into()))?,
            finished: false,
        });
        reference =
            Some(serde_json::to_value(point).map_err(|e| CoreError::Internal(e.to_string()))?);
        control = Some(next);
    }
    if stop.is_some() {
        if let Some(m) = memory.as_mut() {
            m.finished = true;
        }
    }
    Ok(StepControlReceipt {
        schema_version: "sporespore_r10dd_native_reference_step_control_receipt_v1".into(),
        control_composition_id: COMPOSITION.into(),
        request_sha256: digest_serializable(&request)?,
        collection: collected,
        step,
        next_control: control,
        next_reference: reference,
        reference_memory: memory,
        diagnostic_stop_reason: stop,
        original_observation_rewritten: false,
        canonical_supervisor_synthesized: false,
        world_build_count: 0,
        solver_step_count: 0,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}
