//! Synthetic source-bound API tests. No retained physical observation is edited.
use super::*;
use crate::recovery::partial_fall as partial;
use crate::recovery::tests::partial_fall_tests::{partial_handoff, step_input};
use super::super::partial_fall_control::*;
use super::super::passive_entry_collection::PASSIVE_COLLECTION_REQUEST_V1;

pub(super) fn collection_for(observation: &RecoveryObservationV3, init: &RecoveryInitializeRequestV2,
    phase: RecoveryPhaseV1) -> RecoveryNativeCollectionRequestV3 {
    let mut request = native_request_v3_for_phase(RecoveryNativeEngineV1::GodotJolt4_7, phase);
    request.task_id = observation.task_id.clone();
    request.semantics_id = observation.semantics_id.clone();
    request.descriptor = init.descriptor.clone();
    request.morphology_context = init.morphology_context.clone();
    request.adapter_capability = init.adapter_capability.clone();
    request.runtime_binding.capability_sha256 = digest_serializable(&init.adapter_capability).unwrap();
    request.runtime_binding.collector_id = GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
    request.runtime_binding.runtime_profile_id = GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
    // Project the SAME newly generated synthetic sample into its V2 source carrier.
    let mut value = serde_json::to_value(observation).unwrap();
    value["schema_version"] = json!(RECOVERY_OBSERVATION_V2_VERSION);
    let ledger = value["energy_balance"].as_object_mut().unwrap();
    ledger.insert("schema_version".to_owned(), json!(RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION));
    ledger.insert("equation_id".to_owned(), json!(RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID));
    ledger.insert("component_partition_id".to_owned(), json!(RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID));
    ledger.remove("cumulative_signed_discrete_staging_exchange_j");
    request.observation = serde_json::from_value(value).unwrap();
    request.observation_source_binding = bind_recovery_observation_v2_source_v1(
        &request.observation, GODOT_ADAPTER_ID, GODOT_R24D148_RECOVERY_ROUTE_ID,
        GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID, SHA_A, SHA_B).unwrap();
    request
}

fn entry_request() -> EntryControlRequest {
    let result = partial_handoff();
    let entry = *result.partial_declaration.unwrap().entry_request;
    let collection = collection_for(&entry.passive_request.observation,
        &entry.passive_request.declaration.initialization, RecoveryPhaseV1::ConfirmProne);
    let mut value = serde_json::to_value(collection).unwrap();
    value["schema_version"] = json!(PASSIVE_COLLECTION_REQUEST_V1);
    value.as_object_mut().unwrap().remove("phase");
    EntryControlRequest { schema_version: ENTRY_CONTROL_REQUEST.to_owned(), entry,
        collection: serde_json::from_value(value).unwrap() }
}

fn controlled_step(declaration: &partial::Declaration, memory: &partial::Memory) -> StepControlRequest {
    let step = step_input(declaration, memory);
    let collection = collection_for(&step.observation,
        &declaration.entry_request.passive_request.declaration.initialization, memory.phase);
    StepControlRequest { schema_version: STEP_CONTROL_REQUEST.to_owned(), collection, step }
}

#[test]
fn partial_control_entry_keeps_original_timeout_source_and_plans_only_next_owner() {
    let request = entry_request();
    let original = request.clone();
    let result = entry_control(request.clone()).unwrap();
    assert_eq!(request, original);
    assert_eq!(partial::EntryRoute::Partial, result.entry.memory.route);
    assert_eq!(result.collection.collection.observation.as_ref(), Some(&request.collection.observation));
    assert_eq!(result.collection.collection.observation_source_binding.as_ref(), Some(&request.collection.observation_source_binding));
    assert_eq!(RecoveryControllerOwnerV1::None, request.collection.observation.controller_ownership.owner);
    assert!(result.entry.original_passive_receipt.canonical_memory.is_none());
    let plan = result.initial_partial_control.unwrap();
    assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, plan.controller_id);
    assert_eq!(RecoveryPhaseV1::EstablishDistalSupport, plan.phase);
    assert_eq!(8, plan.ordered_commands.len());
    assert_eq!(Some(digest_serializable(&request.entry.passive_request.observation).unwrap()), plan.observation_sha256);
    assert!(!result.original_observation_rewritten && !result.canonical_supervisor_synthesized);
    assert_eq!((0,0), (result.world_build_count, result.solver_step_count));
    assert!(!result.physical_acceptance_authority && !result.release_authority);
}

#[test]
fn partial_control_full_source_bound_sequence_preserves_energy_and_stops_actuation_at_completion() {
    let entry = entry_control(entry_request()).unwrap().entry;
    let declaration = entry.partial_declaration.unwrap();
    let mut memory = entry.partial_memory.unwrap();
    let mut phases = Vec::new();
    for _ in 0..70 {
        let request = controlled_step(&declaration, &memory);
        let before = request.clone();
        let result = step_control(request.clone()).unwrap();
        assert_eq!(request, before);
        assert_eq!(result.collection.observation.as_ref(), Some(&request.collection.observation));
        assert_eq!(2.0, result.step.memory.last_energy_ledger.cumulative_signed_external_work_j);
        assert!(!result.canonical_supervisor_synthesized && !result.original_observation_rewritten);
        assert_eq!((0,0), (result.world_build_count, result.solver_step_count));
        assert!(!result.physical_acceptance_authority && !result.release_authority);
        if phases.last() != Some(&result.step.prior_phase) { phases.push(result.step.prior_phase); }
        if result.step.next_phase == RecoveryPhaseV1::Complete {
            assert!(result.next_control.is_none());
            assert_eq!(60, result.step.memory.standing_samples_observed);
            assert_eq!(phases, vec![RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::StanceDwell]);
            return;
        }
        let plan = result.next_control.as_ref().unwrap();
        let expected_id = if matches!(result.step.next_phase, RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell) {
            stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)
        } else { EXACT_S169_RECOVERY_CONTROLLER_V20_ID };
        assert_eq!(expected_id, plan.controller_id);
        memory = result.step.memory;
    }
    panic!("synthetic standing sequence did not terminate");
}

#[test]
fn partial_control_refuses_crossed_source_owner_task_clock_and_energy_without_a_plan() {
    let base = entry_request();
    for case in 0..5 {
        let mut request = base.clone();
        match case {
            0 => request.collection.observation.state.base_pose_world.position_m.y += 0.001,
            1 => request.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            2 => request.entry.passive_request.observation.energy_balance.initial_mechanical_energy_j += 1.0,
            3 => request.collection.task_id = partial::TASK.to_owned(),
            _ => request.collection.runtime_binding.collector_id = GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned(),
        }
        assert!(entry_control(request).is_err(), "entry case {case}");
    }
    let entry = entry_control(base).unwrap().entry;
    let base = controlled_step(&entry.partial_declaration.unwrap(), &entry.partial_memory.unwrap());
    for case in 0..8 {
        let mut request = base.clone();
        match case {
            0 => request.collection.task_id = CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            1 => request.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            2 => request.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V19_ID.to_owned()),
            3 => request.step.observation.semantic_step += 1,
            4 => request.step.observation.energy_balance.cumulative_signed_external_work_j = 0.0,
            5 => request.step.memory.phase = RecoveryPhaseV1::StanceDwell,
            6 => request.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            _ => request.collection.runtime_binding.collector_id = GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned(),
        }
        assert!(step_control(request).is_err(), "step case {case}");
    }
    let old = collect_native_recovery_observation_v3(base.collection).unwrap();
    assert_eq!(RecoverySupportStatusV1::UnsupportedProfile, old.support_status);
}

#[test]
fn partial_control_uses_exact_v7_feedback_law_and_refuses_nonrecovery_phases() {
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for clock in [0, 1, 59, 60, 239, 240, 359] {
            let mut request = damped_stance_control_tests::request(phase, [0.12;8], [0.2;8]);
            request.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID).to_owned();
            if phase == RecoveryPhaseV1::RaiseBody {
                request.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned());
            } else {
                request.collection.observation.controller_ownership.stance_controller_id = Some(request.controller_id.clone());
                request.handoff_or_stance_step.memory.as_mut().unwrap().phase_steps_observed = clock;
            }
            damped_stance_control_tests::rebind(&mut request);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap().control_receipt;
            let actual = plan_verified_phase(&request.collection.descriptor, &request.portable_step_observation_v3,
                expected.phase, expected.phase_step).unwrap().unwrap();
            assert_eq!(expected, actual);
        }
    }
    let base = entry_request();
    assert!(plan_verified_phase(&base.collection.descriptor, &base.entry.passive_request.observation,
        RecoveryPhaseV1::ConfirmProne, 0).is_err());
    assert!(plan_verified_phase(&base.collection.descriptor, &base.entry.passive_request.observation,
        RecoveryPhaseV1::Failed, 0).unwrap().is_none());
}

#[test]
fn partial_control_exported_api_fixtures_cover_entry_all_phases_and_completion() {
    let request = entry_request();
    let result = entry_control(request.clone()).unwrap();
    println!("R10K_CONTROL_FIXTURE {}", json!({"kind":"entry", "request":request, "expected":result}));
    let declaration = result.entry.partial_declaration.unwrap();
    let mut memory = result.entry.partial_memory.unwrap();
    let mut seen = Vec::new();
    for _ in 0..70 {
        let request = controlled_step(&declaration, &memory);
        let result = step_control(request.clone()).unwrap();
        if !seen.contains(&result.step.prior_phase) || result.step.next_phase == RecoveryPhaseV1::Complete {
            println!("R10K_CONTROL_FIXTURE {}", json!({"kind":"step", "request":request, "expected":result}));
            seen.push(result.step.prior_phase);
        }
        if result.step.next_phase == RecoveryPhaseV1::Complete { return; }
        memory = result.step.memory;
    }
    panic!("exported fixture did not complete");
}
