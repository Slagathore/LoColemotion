//! Synthetic R10AM source/command tests; no controller success is inferred.
use super::super::partial_support_anchored_composition as direct;
use super::super::upright_recovery_control as old_entry;
use super::partial_fall_control_tests::collection_for;
use super::*;
use crate::recovery::tests::partial_fall_tests::{partial_handoff, step_input};
use crate::recovery::tests::upright_recovery_tests::{advance, entry_first};
use crate::recovery::{partial_fall as partial, upright_recovery as upright};

fn entry_request(height: f64) -> direct::EntryControlRequest {
    let mut entry = entry_first(height);
    for _ in 1..240 {
        let receipt = upright::select_entry(entry.clone()).unwrap();
        assert_eq!(upright::EntryRoute::Waiting, receipt.memory.route);
        advance(&mut entry, &receipt, height);
    }
    let passive = &entry.original_request.passive_request;
    let collection = collection_for(
        &passive.observation,
        &passive.declaration.initialization,
        RecoveryPhaseV1::ConfirmProne,
    );
    let mut value = serde_json::to_value(collection).unwrap();
    value["schema_version"] =
        json!(super::super::passive_entry_collection::PASSIVE_COLLECTION_REQUEST_V1);
    value.as_object_mut().unwrap().remove("phase");
    direct::EntryControlRequest {
        schema_version: direct::ENTRY_CONTROL_REQUEST.to_owned(),
        entry,
        collection: serde_json::from_value(value).unwrap(),
    }
}

fn request(
    declaration: &partial::Declaration,
    memory: &partial::Memory,
) -> direct::StepControlRequest {
    let mut step = step_input(declaration, memory);
    if matches!(
        memory.phase,
        RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody
    ) {
        step.observation.controller_ownership.recovery_controller_id =
            Some(EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID.to_owned());
    }
    let collection = collection_for(
        &step.observation,
        &declaration
            .entry_request
            .passive_request
            .declaration
            .initialization,
        memory.phase,
    );
    direct::StepControlRequest {
        schema_version: direct::STEP_CONTROL_REQUEST.to_owned(),
        collection,
        step,
    }
}

#[test]
fn r10am_entry_retains_original_selector_and_separately_labels_partial_control() {
    for height in [0.4, 0.72] {
        let input = entry_request(height);
        let expected = old_entry::entry_control(old_entry::EntryControlRequest {
            schema_version: old_entry::ENTRY_CONTROL_REQUEST.to_owned(),
            entry: input.entry.clone(),
            collection: input.collection.clone(),
        })
        .unwrap();
        let result = direct::entry_control(input.clone()).unwrap();
        assert_eq!(expected, result.original_entry_control);
        if height == 0.4 {
            let original = expected.original_control.initial_partial_control.unwrap();
            assert_eq!(
                EXACT_S169_RECOVERY_CONTROLLER_V20_ID,
                original.controller_id
            );
            let next = result.initial_partial_control.unwrap();
            assert_eq!(
                EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
                next.controller_id
            );
            assert_eq!(RecoveryPhaseV1::EstablishDistalSupport, next.phase);
            assert_eq!(0, next.phase_step);
        } else {
            assert!(result.initial_partial_control.is_none());
            assert_eq!(upright::EntryRoute::Upright, expected.entry.memory.route);
        }
        assert!(
            !result.original_observation_rewritten
                && !result.canonical_supervisor_synthesized
                && !result.partial_supervisor_synthesized
                && !result.physical_acceptance_authority
                && !result.release_authority
        );
        assert_eq!((0, 0), (result.world_build_count, result.solver_step_count));
    }
}

#[test]
fn r10am_full_partial_task_is_exact_and_stops_after_sixty_standing_samples() {
    let entry = partial_handoff();
    let declaration = entry.partial_declaration.unwrap();
    let mut memory = entry.partial_memory.unwrap();
    for count in 1..=63 {
        let input = request(&declaration, &memory);
        let expected = partial::step(input.step.clone()).unwrap();
        let result = direct::step_control(input).unwrap();
        assert_eq!(expected, result.step);
        assert!(
            result
                .collection
                .supplied_native_post_step_observation_validated
        );
        assert_eq!(count == 63, result.step.partial_fall_standing_complete);
        match &result.next_control {
            Some(control) if count == 1 => assert_eq!(
                EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
                control.controller_id
            ),
            Some(control) => assert_eq!(
                stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID),
                control.controller_id
            ),
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
fn r10am_crossed_owner_source_clock_energy_and_old_api_refuse() {
    let entry = partial_handoff();
    let base = request(
        &entry.partial_declaration.unwrap(),
        &entry.partial_memory.unwrap(),
    );
    for case in 0..13 {
        let mut bad = base.clone();
        match case {
            0 => {
                bad.schema_version =
                    super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned()
            }
            1 => bad.collection.task_id = upright::TASK.to_owned(),
            2 => {
                bad.collection.observation_source_binding.source_route_id =
                    "unregistered".to_owned()
            }
            3 => {
                bad.collection
                    .observation
                    .controller_ownership
                    .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned())
            }
            4 => bad.step.observation.semantic_step += 1,
            5 => {
                bad.step
                    .observation
                    .energy_balance
                    .cumulative_signed_external_work_j = 0.0
            }
            6 => bad.step.memory.phase = RecoveryPhaseV1::StanceDwell,
            7 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            8 => {
                bad.collection.runtime_binding.collector_id =
                    GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned()
            }
            9 => bad.collection.descriptor.torso_length_scale += 0.01,
            10 => {
                bad.collection
                    .observation
                    .controller_ownership
                    .recovery_controller_id =
                    Some(EXACT_S169_PARTIAL_LOAD_SEEKING_CONTROLLER_V23_ID.to_owned());
            }
            11 => {
                bad.collection
                    .observation
                    .controller_ownership
                    .recovery_controller_id =
                    Some(EXACT_S169_PARTIAL_CONCURRENT_LOAD_RISE_CONTROLLER_V25_ID.to_owned());
            }
            _ => {
                bad.collection
                    .observation
                    .controller_ownership
                    .fallback_controller_active = true
            }
        }
        assert!(direct::step_control(bad).is_err(), "step case {case}");
    }
    let mut old = base.clone();
    old.schema_version = super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned();
    assert!(super::super::partial_fall_control::step_control(old).is_err());
    let original = step_input(&base.step.declaration, &base.step.memory);
    let collection = collection_for(
        &original.observation,
        &base
            .step
            .declaration
            .entry_request
            .passive_request
            .declaration
            .initialization,
        base.step.memory.phase,
    );
    let old = super::super::partial_fall_control::step_control(
        super::super::partial_fall_control::StepControlRequest {
            schema_version: super::super::partial_fall_control::STEP_CONTROL_REQUEST.to_owned(),
            collection,
            step: original,
        },
    )
    .unwrap();
    assert_eq!(
        EXACT_S169_RECOVERY_CONTROLLER_V20_ID,
        old.next_control.unwrap().controller_id
    );
    let base = entry_request(0.4);
    for case in 0..6 {
        let mut bad = base.clone();
        match case {
            0 => bad.schema_version = old_entry::ENTRY_CONTROL_REQUEST.to_owned(),
            1 => {
                bad.collection
                    .observation
                    .state
                    .base_pose_world
                    .position_m
                    .y += 0.001
            }
            2 => {
                bad.collection.observation_source_binding.source_route_id =
                    "unregistered".to_owned()
            }
            3 => {
                bad.entry
                    .original_request
                    .passive_request
                    .observation
                    .energy_balance
                    .initial_mechanical_energy_j += 1.0
            }
            4 => bad.collection.task_id = partial::TASK.to_owned(),
            _ => bad.entry.prior.as_mut().unwrap().schema_version = "crossed".to_owned(),
        }
        assert!(direct::entry_control(bad).is_err(), "entry case {case}");
    }
}

// These are explicitly synthetic boundary inputs. They never replace a retained
// physical source or bypass the collection validator in the composition.
fn weak_request(
    declaration: &partial::Declaration,
    memory: &partial::Memory,
) -> direct::StepControlRequest {
    let mut input = request(declaration, memory);
    input.step.observation.state.base_pose_world.position_m.y = 0.18;
    // A flexed synthetic pose leaves geometric room to rise. The original
    // straight-leg fixture correctly selects fallback instead.
    for (index, joint) in input
        .step
        .observation
        .state
        .ordered_joint_observations
        .iter_mut()
        .enumerate()
    {
        joint.position_rad = Some(if index % 2 == 0 { 0.2 } else { 0.8 });
    }
    input.step.observation.center_of_mass.position_world_m.y = declaration
        .entry_request
        .passive_request
        .observation
        .center_of_mass
        .position_world_m
        .y
        + 0.09;
    input.step.observation.state.ordered_contact_observations[0].presence = Some(false);
    input.step.observation.state.ordered_contact_observations[0].bears_support = Some(false);
    input.step.observation.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns = 0.0;
    input.collection = collection_for(
        &input.step.observation,
        &declaration
            .entry_request
            .passive_request
            .declaration
            .initialization,
        memory.phase,
    );
    input
}

fn boundary_fixtures() -> Vec<(&'static str, direct::StepControlRequest)> {
    let entry = partial_handoff();
    let declaration = entry.partial_declaration.unwrap();
    let initial = entry.partial_memory.unwrap();
    let raised = direct::step_control(request(&declaration, &initial))
        .unwrap()
        .step
        .memory;
    let weak = weak_request(&declaration, &raised);
    let mut boundary = raised;
    boundary.phase_steps_observed = 599;
    boundary.total_steps_observed = 600;
    boundary.last_semantic_step = initial.last_semantic_step + 600;
    boundary.last_host_step_after = initial.last_host_step_after + 600;
    vec![
        ("weak_raise", weak),
        ("raise_timeout", weak_request(&declaration, &boundary)),
    ]
}

#[test]
fn r10am_weak_load_keeps_original_task_and_timeout_emits_no_command() {
    for (identity, input) in boundary_fixtures() {
        let expected = partial::step(input.step.clone()).unwrap();
        let result = direct::step_control(input.clone()).unwrap();
        assert_eq!(expected, result.step);
        if identity == "weak_raise" {
            assert_eq!(RecoveryPhaseV1::RaiseBody, result.step.next_phase);
            let plan = result.next_load_plan.unwrap();
            assert!(!plan.baseline_reference.qualified_support[0]);
            assert_eq!("support_anchored_leveling", plan.mode);
            let geometry = plan.support_anchored_geometry.unwrap();
            assert!(geometry.hold_reason.is_none());
            assert!(geometry.selected_scale.is_some());
            assert!(geometry.maximum_anchor_error_m <= 0.0005 + 1e-12);
            assert_eq!(
                EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
                result.next_control.unwrap().controller_id
            );
        } else {
            assert_eq!(RecoveryPhaseV1::Failed, result.step.next_phase);
            assert_eq!(
                Some("phase_timeout:raise_body"),
                result.step.memory.terminal_failure_code.as_deref()
            );
            assert!(result.next_control.is_none() && result.next_load_plan.is_none());
            assert!(
                direct::step_control(request(&input.step.declaration, &result.step.memory))
                    .is_err()
            );
        }
    }
}

fn abi<T: serde::Serialize>(
    request: &T,
    call: unsafe extern "C" fn(*const u8, usize, *mut u8, usize, *mut usize) -> std::ffi::c_int,
) -> serde_json::Value {
    let input = serde_json::to_vec(request).unwrap();
    let mut length = 0;
    assert_eq!(crate::ffi::SS_BUFFER_TOO_SMALL, unsafe {
        call(
            input.as_ptr(),
            input.len(),
            std::ptr::null_mut(),
            0,
            &mut length,
        )
    });
    let mut output = vec![0; length];
    assert_eq!(crate::ffi::SS_OK, unsafe {
        call(
            input.as_ptr(),
            input.len(),
            output.as_mut_ptr(),
            output.len(),
            &mut length,
        )
    });
    serde_json::from_slice::<serde_json::Value>(&output[..length]).unwrap()["value"].clone()
}

#[test]
fn r10am_public_buffer_abi_and_retained_native_interface_fixtures() {
    let input = entry_request(0.4);
    let entry = direct::entry_control(input.clone()).unwrap();
    assert_eq!(
        serde_json::to_value(&entry).unwrap(),
        abi(
            &input,
            crate::ffi::ss_recovery_r10am_partial_entry_control_v1_json
        )
    );
    println!(
        "R10AM_PARTIAL_FIXTURE {}",
        json!({"id":"partial_entry", "physical_source":false,
        "method":"recovery_r10am_partial_entry_control_v1", "request":input, "expected":entry})
    );
    let declaration = entry
        .original_entry_control
        .original_control
        .entry
        .partial_declaration
        .unwrap();
    let mut memory = entry
        .original_entry_control
        .original_control
        .entry
        .partial_memory
        .unwrap();
    for count in 1..=63 {
        let input = request(&declaration, &memory);
        let expected = direct::step_control(input.clone()).unwrap();
        assert_eq!(
            serde_json::to_value(&expected).unwrap(),
            abi(
                &input,
                crate::ffi::ss_recovery_r10am_partial_step_control_v1_json
            )
        );
        if [1, 2, 3, 63].contains(&count) {
            println!(
                "R10AM_PARTIAL_FIXTURE {}",
                json!({"id":format!("partial_step_{count}"),
                "method":"recovery_r10am_partial_step_control_v1", "request":input, "expected":expected,
                "physical_source":false})
            );
        }
        memory = expected.step.memory;
    }
    assert_eq!(RecoveryPhaseV1::Complete, memory.phase);
    for (identity, input) in boundary_fixtures() {
        let expected = direct::step_control(input.clone()).unwrap();
        assert_eq!(
            serde_json::to_value(&expected).unwrap(),
            abi(
                &input,
                crate::ffi::ss_recovery_r10am_partial_step_control_v1_json
            )
        );
        println!(
            "R10AM_PARTIAL_FIXTURE {}",
            json!({"id":identity, "physical_source":false,
            "method":"recovery_r10am_partial_step_control_v1", "request":input, "expected":expected})
        );
    }
}

#[test]
fn r10am_retained_geometry_is_the_actual_bounded_command_in_both_phases() {
    // These exposed inputs are command-forwarding probes, not admissions of
    // their original terminal/weak-support observations to a physical session.
    let binding: serde_json::Value = serde_json::from_str(include_str!(
        "../../../contracts/r10am_retained_canonical_geometry_input_binding_v1.json"
    ))
    .unwrap();
    let raw = std::fs::read(binding["fixture"]["path"].as_str().unwrap()).unwrap();
    use sha2::{Digest, Sha256};
    assert_eq!(
        format!("sha256:{:x}", Sha256::digest(&raw)),
        binding["fixture"]["raw_sha256"]
    );
    let retained: serde_json::Value = serde_json::from_slice(&raw).unwrap();
    let descriptor: BoundedQuadrupedDescriptor =
        serde_json::from_value(retained["descriptor"].clone()).unwrap();
    let inputs: Vec<(BoundedQuadrupedDescriptor, RecoveryObservationV3)> = retained["observations"]
        .as_array()
        .unwrap()
        .iter()
        .map(|row| {
            (
                descriptor.clone(),
                serde_json::from_value(row["observation"].clone()).unwrap(),
            )
        })
        .collect();
    assert_eq!(inputs.len(), 600);
    for (descriptor, observation) in inputs {
        for phase in [
            RecoveryPhaseV1::EstablishDistalSupport,
            RecoveryPhaseV1::RaiseBody,
        ] {
            let (control, geometry) = direct::plan(&descriptor, &observation, phase, 123).unwrap();
            let control = control.unwrap();
            let geometry = geometry.unwrap();
            assert_eq!(
                Some(digest_serializable(&observation).unwrap()),
                control.observation_sha256
            );
            assert_eq!(
                direct::profile_sha256().unwrap(),
                control.controller_profile_sha256
            );
            assert_eq!(phase, control.phase);
            assert_eq!(123, control.phase_step);
            assert_eq!(
                EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
                control.controller_id
            );
            if phase == RecoveryPhaseV1::EstablishDistalSupport {
                assert!(geometry.support_anchored_geometry.is_none());
                assert_eq!(geometry.mode, "unchanged_support_reference");
            } else {
                let planned = geometry.support_anchored_geometry.as_ref().unwrap();
                if planned.selected_scale.is_some() {
                    assert_eq!(geometry.mode, "support_anchored_leveling");
                    assert!(planned.hold_reason.is_none());
                } else {
                    assert_eq!(geometry.mode, "explicit_v23_fallback");
                    assert!(planned.hold_reason.is_some());
                }
            }
            assert_eq!(control.ordered_commands.len(), 8);
            for (i, command) in control.ordered_commands.iter().enumerate() {
                assert_eq!(
                    project_binary64_to_guarded_canonical_number_v1(
                        geometry.ordered_target_positions_rad[i]
                    )
                    .unwrap(),
                    command.target_position_rad
                );
                assert_eq!(4.0, command.maximum_target_speed_rad_s);
            }
            assert_eq!(
                Some(digest_serializable(&control.ordered_commands).unwrap()),
                control.command_sha256
            );
            assert!(
                !control.physical_acceptance_authority
                    && !control.release_authority
                    && !control.physics_state_modified
            );
        }
    }
}

#[test]
fn r10am_requires_its_source_bound_composition_not_the_generic_profile_api() {
    let request = super::smooth_stance_control_tests::recovery_request(
        RecoveryNativeEngineV1::GodotJolt4_7,
        RecoveryPhaseV1::EstablishDistalSupport,
        EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID,
    );
    let result = plan_recovery_control_v1(request).unwrap();
    assert_eq!(
        RecoverySupportStatusV1::UnsupportedProfile,
        result.support_status
    );
    assert!(result.no_actuation_requested && result.ordered_commands.is_empty());
}
