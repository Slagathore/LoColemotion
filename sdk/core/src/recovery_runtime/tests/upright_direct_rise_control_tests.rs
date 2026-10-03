//! R10R tests exercise the real source collector, task supervisor and public ABI.
//! Synthetic observations are not physical trajectory evidence.
use super::*;
use crate::recovery::upright_recovery as upright;
use crate::recovery::tests::upright_recovery_tests::{handoff, step_input};
use super::super::upright_direct_rise_control as direct;
use super::partial_fall_control_tests::collection_for;

fn request(declaration: &upright::Declaration, memory: &upright::Memory) -> direct::StepControlRequest {
    let mut step = step_input(declaration, memory);
    if memory.phase == RecoveryPhaseV1::RaiseBody {
        step.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V12_ID.to_owned());
    }
    let collection = collection_for(&step.observation,
        &declaration.entry_request.original_request.passive_request.declaration.initialization, memory.phase);
    direct::StepControlRequest { schema_version: direct::STEP_CONTROL_REQUEST.to_owned(), collection, step }
}

#[test]
fn r10r_full_source_route_uses_actual_v12_raise_and_retains_standing_completion() {
    let entry = handoff();
    let declaration = entry.upright_declaration.unwrap(); let mut memory = entry.upright_memory.unwrap();
    for count in 1..=63 {
        let input = request(&declaration, &memory);
        let expected_task = upright::step(input.step.clone()).unwrap();
        let result = direct::step_control(input).unwrap();
        assert_eq!(expected_task, result.step);
        assert_eq!(direct::COMPOSITION, result.control_composition_id);
        assert!(result.collection.supplied_native_post_step_observation_validated);
        assert_eq!(count == 63, result.step.upright_stabilization_complete);
        match &result.next_control {
            Some(control) if count == 1 => assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V12_ID, control.controller_id),
            Some(control) => assert_eq!(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID), control.controller_id),
            None => assert_eq!(63, count),
        }
        assert!(!result.original_observation_rewritten && !result.canonical_supervisor_synthesized);
        assert!(!result.physical_acceptance_authority && !result.release_authority);
        assert_eq!((0,0), (result.world_build_count, result.solver_step_count));
        memory = result.step.memory;
    }
}

#[test]
fn r10r_source_owner_clock_task_memory_and_old_api_crossings_refuse() {
    let entry = handoff();
    let declaration = entry.upright_declaration.unwrap();
    let first = request(&declaration, &entry.upright_memory.unwrap());
    let raised = direct::step_control(first.clone()).unwrap();
    let base = request(&declaration, &raised.step.memory);
    for case in 0..10 {
        let mut bad = base.clone();
        match case {
            0 => bad.schema_version = super::super::upright_recovery_control::STEP_CONTROL_REQUEST.to_owned(),
            1 => bad.collection.task_id = crate::recovery::partial_fall::TASK.to_owned(),
            2 => bad.collection.observation_source_binding.source_route_id = "unregistered".to_owned(),
            3 => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned()),
            4 => bad.step.observation.semantic_step += 1,
            5 => bad.step.observation.energy_balance.cumulative_signed_external_work_j = 0.0,
            6 => bad.step.memory.phase = RecoveryPhaseV1::StanceDwell,
            7 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            8 => bad.collection.runtime_binding.collector_id = GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned(),
            _ => bad.collection.descriptor.torso_length_scale += 0.01,
        }
        assert!(direct::step_control(bad).is_err(), "case {case}");
    }
    // Q still refuses V12 ownership; the successor cannot silently use its API.
    let mut old_api = base;
    old_api.schema_version = super::super::upright_recovery_control::STEP_CONTROL_REQUEST.to_owned();
    assert!(super::super::upright_recovery_control::step_control(old_api).is_err());
    let mut old_first = first;
    old_first.schema_version = super::super::upright_recovery_control::STEP_CONTROL_REQUEST.to_owned();
    let old = super::super::upright_recovery_control::step_control(old_first).unwrap();
    assert_eq!(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, old.next_control.unwrap().controller_id);
}

#[test]
fn r10r_raise_command_is_byte_identical_to_the_existing_v12_law() {
    let entry = handoff();
    let declaration = entry.upright_declaration.unwrap();
    let first = request(&declaration, &entry.upright_memory.unwrap());
    // Exact exposed R10Q step-512 readings, bound by the command component.
    // Only these joint positions are injected into this synthetic fixture.
    let mut observed = first.step.observation.clone();
    for (joint, position) in observed.state.ordered_joint_observations.iter_mut().zip([0.7737443447113037, -1.1019550561904907, -0.8592941761016846, 1.1006510257720947, 0.49910634756088257, -1.1000043153762817, -0.3257862329483032, 1.101442813873291]) {
        joint.position_rad = Some(position);
    }
    let observation = &observed;
    let descriptor = &first.collection.descriptor;
    for clock in [0, 59, 119, 120, 239, 240, 359, 360, 599] {
        let result = super::super::upright_direct_rise_control::plan(descriptor, observation,
            RecoveryPhaseV1::RaiseBody, clock).unwrap().unwrap();
        let profile = recovery_development_profile_v12();
        let context = RecoveryControlPlanContext { controller_id: EXACT_S169_RECOVERY_CONTROLLER_V12_ID,
            phase_step: clock, descriptor, arm_kind: RecoveryArmKindV1::CandidateCommand,
            phase: RecoveryPhaseV1::RaiseBody, semantic_step: observation.semantic_step,
            ordered_joint_observations: &observation.state.ordered_joint_observations,
            base_orientation: observation.state.base_pose_world.orientation_xyzw };
        let expected = build_recovery_control_receipt(&context, Some(digest_serializable(observation).unwrap()),
            profile.clone(), digest_serializable(&profile).unwrap()).unwrap();
        assert_eq!(serde_json::to_vec(&expected).unwrap(), serde_json::to_vec(&result).unwrap());
    }
    for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::StanceHandoff,
                  RecoveryPhaseV1::StanceDwell, RecoveryPhaseV1::Complete, RecoveryPhaseV1::Failed] {
        assert_eq!(super::super::partial_fall_control::plan_verified_phase(descriptor, observation, phase, 0).unwrap(),
            super::super::upright_direct_rise_control::plan(descriptor, observation, phase, 0).unwrap());
    }
}

#[test]
fn r10r_public_buffer_abi_and_retained_synthetic_fixtures() {
    let entry = handoff();
    let declaration = entry.upright_declaration.unwrap(); let mut memory = entry.upright_memory.unwrap();
    for count in 1..=63 {
        let request = request(&declaration, &memory);
        let expected = direct::step_control(request.clone()).unwrap();
        let input = serde_json::to_vec(&request).unwrap(); let mut length = 0;
        let call = crate::ffi::ss_recovery_r10r_upright_step_control_v1_json;
        assert_eq!(crate::ffi::SS_BUFFER_TOO_SMALL,
            unsafe { call(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut length) });
        let mut output = vec![0;length];
        assert_eq!(crate::ffi::SS_OK,
            unsafe { call(input.as_ptr(),input.len(),output.as_mut_ptr(),output.len(),&mut length) });
        let actual: serde_json::Value = serde_json::from_slice(&output[..length]).unwrap();
        assert_eq!(serde_json::to_value(&expected).unwrap(), actual["value"]);
        if [1,2,63].contains(&count) {
            println!("R10R_UPRIGHT_FIXTURE {}", json!({"id": format!("upright_step_{count}"),
                "method": "recovery_r10r_upright_step_control_v1", "request": request,
                "expected": expected, "physical_source": false}));
        }
        memory = expected.step.memory;
    }
}
