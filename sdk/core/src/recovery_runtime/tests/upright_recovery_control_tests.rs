//! Exact source-carrier and public ABI checks for R10Q; no physics objects.
use super::*;
use crate::recovery::upright_recovery as upright;
use crate::recovery::tests::upright_recovery_tests::{handoff, step_input};
use super::super::upright_recovery_control::*;
use super::super::passive_entry_collection::PASSIVE_COLLECTION_REQUEST_V1;
use super::partial_fall_control_tests::collection_for;

fn entry_request() -> EntryControlRequest {
    let entry = *handoff().upright_declaration.unwrap().entry_request;
    let original = &entry.original_request.passive_request;
    let collection = collection_for(&original.observation, &original.declaration.initialization,
        RecoveryPhaseV1::ConfirmProne);
    let mut value = serde_json::to_value(collection).unwrap();
    value["schema_version"] = json!(PASSIVE_COLLECTION_REQUEST_V1);
    value.as_object_mut().unwrap().remove("phase");
    EntryControlRequest { schema_version: ENTRY_CONTROL_REQUEST.to_owned(), entry,
        collection: serde_json::from_value(value).unwrap() }
}

fn controlled_step(declaration: &upright::Declaration, memory: &upright::Memory) -> StepControlRequest {
    let step = step_input(declaration, memory);
    let collection = collection_for(&step.observation,
        &declaration.entry_request.original_request.passive_request.declaration.initialization, memory.phase);
    StepControlRequest { schema_version: STEP_CONTROL_REQUEST.to_owned(), collection, step }
}

#[test]
fn upright_control_retains_the_actual_original_api_result_and_source() {
    let request = entry_request();
    let expected = super::super::partial_fall_control::entry_control(super::super::partial_fall_control::EntryControlRequest {
        schema_version: super::super::partial_fall_control::ENTRY_CONTROL_REQUEST.to_owned(),
        entry: request.entry.original_request.clone(), collection: request.collection.clone() }).unwrap();
    let result = entry_control(request.clone()).unwrap();
    assert_eq!(expected, result.original_control);
    assert_eq!(result.entry.original_entry, expected.entry);
    assert!(result.original_control.initial_partial_control.is_none());
    assert_eq!(upright::EntryRoute::Upright, result.entry.memory.route);
    assert_eq!(Some(&request.collection.observation), result.original_control.collection.collection.observation.as_ref());
    let plan = result.initial_upright_control.unwrap();
    assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, plan.controller_id);
    assert_eq!(RecoveryPhaseV1::EstablishDistalSupport, plan.phase);
    assert_eq!(8, plan.ordered_commands.len());
    assert!(!result.original_observation_rewritten && !result.canonical_supervisor_synthesized
        && !result.partial_supervisor_synthesized);
    assert_eq!((0,0), (result.world_build_count, result.solver_step_count));
}

#[test]
fn native_upright_collection_runs_the_full_named_task_and_releases_control_at_completion() {
    let entry = entry_control(entry_request()).unwrap().entry;
    let declaration = entry.upright_declaration.unwrap(); let mut memory = entry.upright_memory.unwrap();
    for count in 1..=63 {
        let result = step_control(controlled_step(&declaration, &memory)).unwrap();
        assert_eq!(RecoverySupportStatusV1::SupportedExact, result.collection.support_status);
        assert!(result.collection.supplied_native_post_step_observation_validated);
        assert_eq!(count == 63, result.step.upright_stabilization_complete);
        if count == 63 {
            assert!(result.next_control.is_none());
            assert_eq!(60, result.step.memory.standing_samples_observed);
        } else {
            let control = result.next_control.as_ref().unwrap();
            let expected = if matches!(result.step.next_phase, RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell) {
                stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)
            } else { EXACT_S169_RECOVERY_CONTROLLER_V20_ID };
            assert_eq!(expected, control.controller_id);
        }
        assert!(!result.physical_acceptance_authority && !result.release_authority);
        memory = result.step.memory;
    }
}

#[test]
fn upright_source_task_owner_epoch_and_memory_corruption_refuse_without_a_plan() {
    let base = entry_request();
    for case in 0..6 {
        let mut request = base.clone();
        match case {
            0 => request.collection.observation.state.base_pose_world.position_m.y += 0.001,
            1 => request.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            2 => request.entry.original_request.passive_request.observation.energy_balance.initial_mechanical_energy_j += 1.0,
            3 => request.collection.task_id = upright::TASK.to_owned(),
            4 => request.collection.runtime_binding.collector_id = GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned(),
            _ => request.entry.prior.as_mut().unwrap().schema_version = "crossed".to_owned(),
        }
        assert!(entry_control(request).is_err(), "entry case {case}");
    }
    let entry = entry_control(base).unwrap().entry;
    let base = controlled_step(&entry.upright_declaration.unwrap(), &entry.upright_memory.unwrap());
    for case in 0..8 {
        let mut request = base.clone();
        match case {
            0 => request.collection.task_id = crate::recovery::partial_fall::TASK.to_owned(),
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
    let legacy = collect_native_recovery_observation_v3(base.collection).unwrap();
    assert_eq!(RecoverySupportStatusV1::UnsupportedProfile, legacy.support_status);
}

fn abi<T: serde::Serialize>(request: &T, call: unsafe extern "C" fn(*const u8,usize,*mut u8,usize,*mut usize)->i32) -> serde_json::Value {
    let input = serde_json::to_vec(request).unwrap(); let mut length = 0;
    let status = unsafe { call(input.as_ptr(),input.len(),std::ptr::null_mut(),0,&mut length) };
    assert_eq!(crate::ffi::SS_BUFFER_TOO_SMALL, status);
    let mut output = vec![0;length];
    let status = unsafe { call(input.as_ptr(),input.len(),output.as_mut_ptr(),output.len(),&mut length) };
    assert_eq!(crate::ffi::SS_OK, status);
    serde_json::from_slice(&output[..length]).unwrap()
}

#[test]
fn upright_entry_and_step_round_trip_through_the_public_buffer_abi() {
    let request = entry_request();
    let result = abi(&request, crate::ffi::ss_recovery_r10q_upright_entry_control_v1_json);
    assert_eq!(true, result["ok"]);
    assert_eq!("upright", result["value"]["entry"]["memory"]["route"]);
    assert_eq!("timeout", result["value"]["original_control"]["entry"]["memory"]["route"]);
    let entry: upright::EntryReceipt = serde_json::from_value(result["value"]["entry"].clone()).unwrap();
    let request = controlled_step(&entry.upright_declaration.unwrap(), &entry.upright_memory.unwrap());
    let result = abi(&request, crate::ffi::ss_recovery_upright_step_control_v1_json);
    assert_eq!(true, result["ok"]);
    assert_eq!("raise_body", result["value"]["step"]["next_phase"]);
    assert_eq!(false, result["value"]["step"]["upright_stabilization_complete"]);
    assert_eq!(false, result["value"]["physical_acceptance_authority"]);
}

#[test]
fn emit_r10q_upright_native_fixtures() {
    // These are generated synthetic requests and expected native results, not
    // edited physical records. The candidate build retains this exact output.
    let request = entry_request();
    let receipt = entry_control(request.clone()).unwrap();
    println!("R10Q_UPRIGHT_FIXTURE {}", serde_json::to_string(&json!({
        "id": "upright_timeout", "method": "recovery_r10q_upright_entry_control_v1",
        "request": request, "expected": receipt, "physical_source": false
    })).unwrap());
    let declaration = receipt.entry.upright_declaration.unwrap();
    let mut memory = receipt.entry.upright_memory.unwrap();
    for count in 1..=63 {
        let request = controlled_step(&declaration, &memory);
        let receipt = step_control(request.clone()).unwrap();
        if count == 1 || count == 63 {
            println!("R10Q_UPRIGHT_FIXTURE {}", serde_json::to_string(&json!({
                "id": if count == 1 { "first_upright_control" } else { "complete_upright_standing" },
                "method": "recovery_upright_step_control_v1", "request": request,
                "expected": receipt, "physical_source": false
            })).unwrap());
        }
        assert_eq!(count == 63, receipt.step.upright_stabilization_complete);
        memory = receipt.step.memory;
    }
}
