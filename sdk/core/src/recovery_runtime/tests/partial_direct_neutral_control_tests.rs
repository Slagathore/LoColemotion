//! Synthetic R10Y source/command tests; no controller success is inferred.
use super::*;
use crate::recovery::{partial_fall as partial, upright_recovery as upright};
use crate::recovery::tests::partial_fall_tests::{partial_handoff, step_input};
use crate::recovery::tests::upright_recovery_tests::{entry_first, advance};
use super::super::partial_direct_neutral_control as direct;
use super::super::upright_recovery_control as old_entry;
use super::partial_fall_control_tests::collection_for;

fn entry_request(height: f64) -> direct::EntryControlRequest {
    let mut entry = entry_first(height);
    for _ in 1..240 {
        let receipt = upright::select_entry(entry.clone()).unwrap();
        assert_eq!(upright::EntryRoute::Waiting, receipt.memory.route);
        advance(&mut entry, &receipt, height);
    }
    let passive = &entry.original_request.passive_request;
    let collection = collection_for(&passive.observation, &passive.declaration.initialization,
        RecoveryPhaseV1::ConfirmProne);
    let mut value = serde_json::to_value(collection).unwrap();
    value["schema_version"] = json!(super::super::passive_entry_collection::PASSIVE_COLLECTION_REQUEST_V1);
    value.as_object_mut().unwrap().remove("phase");
    direct::EntryControlRequest { schema_version: direct::ENTRY_CONTROL_REQUEST.to_owned(), entry,
        collection: serde_json::from_value(value).unwrap() }
}

fn request(declaration: &partial::Declaration, memory: &partial::Memory) -> direct::StepControlRequest {
    let mut step = step_input(declaration, memory);
    if matches!(memory.phase, RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody) {
        step.observation.controller_ownership.recovery_controller_id =
            Some(EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID.to_owned());
    }
    let collection = collection_for(&step.observation,
        &declaration.entry_request.passive_request.declaration.initialization, memory.phase);
    direct::StepControlRequest { schema_version: direct::STEP_CONTROL_REQUEST.to_owned(), collection, step }
}

#[test]
fn r10y_entry_retains_original_selector_and_separately_labels_partial_control() {
    for height in [0.4, 0.72] {
        let input = entry_request(height);
        let expected = old_entry::entry_control(old_entry::EntryControlRequest {
            schema_version: old_entry::ENTRY_CONTROL_REQUEST.to_owned(),
            entry: input.entry.clone(), collection: input.collection.clone(),
        }).unwrap();
        let result = direct::entry_control(input.clone()).unwrap();
        assert_eq!(expected, result.original_entry_control);
        if height == 0.4 {
            let original = expected.original_control.initial_partial_control.unwrap();
            assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, original.controller_id);
            let next = result.initial_partial_control.unwrap();
            assert_eq!(EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID, next.controller_id);
            assert_eq!(RecoveryPhaseV1::EstablishDistalSupport, next.phase);
            assert_eq!(0, next.phase_step);
        } else {
            assert!(result.initial_partial_control.is_none());
            assert_eq!(upright::EntryRoute::Upright, expected.entry.memory.route);
        }
        assert!(!result.original_observation_rewritten && !result.canonical_supervisor_synthesized
            && !result.partial_supervisor_synthesized && !result.physical_acceptance_authority && !result.release_authority);
        assert_eq!((0, 0), (result.world_build_count, result.solver_step_count));
    }
}

#[test]
fn r10y_full_partial_task_is_exact_and_stops_after_sixty_standing_samples() {
    let entry = partial_handoff();
    let declaration = entry.partial_declaration.unwrap(); let mut memory = entry.partial_memory.unwrap();
    for count in 1..=63 {
        let input = request(&declaration, &memory);
        let expected = partial::step(input.step.clone()).unwrap();
        let result = direct::step_control(input).unwrap();
        assert_eq!(expected, result.step);
        assert!(result.collection.supplied_native_post_step_observation_validated);
        assert_eq!(count == 63, result.step.partial_fall_standing_complete);
        match &result.next_control {
            Some(control) if count == 1 => assert_eq!(EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID, control.controller_id),
            Some(control) => assert_eq!(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID), control.controller_id),
            None => assert_eq!(63, count),
        }
        assert!(!result.original_observation_rewritten && !result.canonical_supervisor_synthesized);
        assert!(!result.physical_acceptance_authority && !result.release_authority);
        assert_eq!((0, 0), (result.world_build_count, result.solver_step_count));
        memory = result.step.memory;
    }
    assert_eq!(60, memory.standing_samples_observed);
}

#[test]
fn r10y_crossed_owner_source_clock_energy_and_old_api_refuse() {
    let entry = partial_handoff();
    let base = request(&entry.partial_declaration.unwrap(), &entry.partial_memory.unwrap());
    for case in 0..11 {
        let mut bad = base.clone();
        match case {
            0 => bad.schema_version = super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned(),
            1 => bad.collection.task_id = upright::TASK.to_owned(),
            2 => bad.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            3 => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned()),
            4 => bad.step.observation.semantic_step += 1,
            5 => bad.step.observation.energy_balance.cumulative_signed_external_work_j = 0.0,
            6 => bad.step.memory.phase = RecoveryPhaseV1::StanceDwell,
            7 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            8 => bad.collection.runtime_binding.collector_id = GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned(),
            9 => bad.collection.descriptor.torso_length_scale += 0.01,
            _ => bad.collection.observation.controller_ownership.fallback_controller_active = true,
        }
        assert!(direct::step_control(bad).is_err(), "step case {case}");
    }
    let mut old = base.clone();
    old.schema_version = super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned();
    assert!(super::super::partial_fall_control::step_control(old).is_err());
    let original = step_input(&base.step.declaration, &base.step.memory);
    let collection = collection_for(&original.observation, &base.step.declaration.entry_request.passive_request.declaration.initialization,
        base.step.memory.phase);
    let old = super::super::partial_fall_control::step_control(super::super::partial_fall_control::StepControlRequest {
        schema_version: super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned(), collection, step: original,
    }).unwrap();
    assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, old.next_control.unwrap().controller_id);
    let base = entry_request(0.4);
    for case in 0..6 {
        let mut bad = base.clone();
        match case {
            0 => bad.schema_version = old_entry::ENTRY_CONTROL_REQUEST.to_owned(),
            1 => bad.collection.observation.state.base_pose_world.position_m.y += 0.001,
            2 => bad.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            3 => bad.entry.original_request.passive_request.observation.energy_balance.initial_mechanical_energy_j += 1.0,
            4 => bad.collection.task_id = partial::TASK.to_owned(),
            _ => bad.entry.prior.as_mut().unwrap().schema_version = "crossed".to_owned(),
        }
        assert!(direct::entry_control(bad).is_err(), "entry case {case}");
    }
}

#[test]
fn r10y_support_and_rise_request_bounded_progress_toward_neutral_from_both_fold_directions() {
    let entry = partial_handoff();
    let base = request(&entry.partial_declaration.unwrap(), &entry.partial_memory.unwrap());
    let profile = direct::profile();
    assert_eq!(360, profile.raise_body_ramp_steps);
    assert_eq!(vec![0.0; 8], profile.establish_distal_support_pose.ordered_target_positions_rad);
    for positions in [[-1.582,0.953,-1.097,0.542,-0.212,-1.01,0.513,-1.104],
        [0.105,1.097,0.111,1.047,1.045,0.189,1.046,0.146],
        [0.261,1.011,0.277,0.901,1.57,-0.886,1.08,0.165],
        [0.113,1.1,0.078,1.099,1.6,-1.038,1.041,0.17]] {
        let mut observed = base.step.observation.clone();
        for (joint, q) in observed.state.ordered_joint_observations.iter_mut().zip(positions) { joint.position_rad = Some(q); }
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            for clock in [0, 1, 119, 120, 239, 240, 359, 360, 599] {
                let result = direct::plan(&base.collection.descriptor, &observed, phase, clock).unwrap().unwrap();
                assert_eq!(phase, result.phase); assert_eq!(clock, result.phase_step);
                for (q, command) in positions.iter().zip(result.ordered_commands) {
                    let target = command.target_position_rad;
                    assert!(target >= q.min(0.0) - 1e-12 && target <= q.max(0.0) + 1e-12);
                    assert!((target-q).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-12);
                    assert_eq!(4.0, command.maximum_target_speed_rad_s);
                }
            }
        }
    }
    for phase in [RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::StanceDwell, RecoveryPhaseV1::Complete, RecoveryPhaseV1::Failed] {
        assert_eq!(super::super::partial_fall_control::plan_verified_phase(&base.collection.descriptor,
            &base.step.observation, phase, 17).unwrap(), direct::plan(&base.collection.descriptor, &base.step.observation, phase, 17).unwrap());
    }
}

fn abi<T: serde::Serialize>(request: &T,
    call: unsafe extern "C" fn(*const u8, usize, *mut u8, usize, *mut usize) -> std::ffi::c_int,
) -> serde_json::Value {
    let input = serde_json::to_vec(request).unwrap(); let mut length = 0;
    assert_eq!(crate::ffi::SS_BUFFER_TOO_SMALL,
        unsafe { call(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut length) });
    let mut output = vec![0; length];
    assert_eq!(crate::ffi::SS_OK,
        unsafe { call(input.as_ptr(), input.len(), output.as_mut_ptr(), output.len(), &mut length) });
    serde_json::from_slice::<serde_json::Value>(&output[..length]).unwrap()["value"].clone()
}

#[test]
fn r10y_public_buffer_abi_and_retained_native_interface_fixtures() {
    let input = entry_request(0.4);
    let entry = direct::entry_control(input.clone()).unwrap();
    assert_eq!(serde_json::to_value(&entry).unwrap(), abi(&input, crate::ffi::ss_recovery_r10y_partial_entry_control_v1_json));
    println!("R10Y_PARTIAL_FIXTURE {}", json!({"id":"partial_entry", "physical_source":false,
        "method":"recovery_r10y_partial_entry_control_v1", "request":input, "expected":entry}));
    let declaration = entry.original_entry_control.original_control.entry.partial_declaration.unwrap();
    let mut memory = entry.original_entry_control.original_control.entry.partial_memory.unwrap();
    for count in 1..=63 {
        let input = request(&declaration, &memory);
        let expected = direct::step_control(input.clone()).unwrap();
        assert_eq!(serde_json::to_value(&expected).unwrap(), abi(&input, crate::ffi::ss_recovery_r10y_partial_step_control_v1_json));
        if [1,2,3,63].contains(&count) {
            println!("R10Y_PARTIAL_FIXTURE {}", json!({"id":format!("partial_step_{count}"),
                "method":"recovery_r10y_partial_step_control_v1", "request":input, "expected":expected,
                "physical_source":false}));
        }
        memory = expected.step.memory;
    }
    assert_eq!(RecoveryPhaseV1::Complete, memory.phase);
}
