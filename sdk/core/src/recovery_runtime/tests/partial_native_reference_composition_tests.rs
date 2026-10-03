//! Synthetic copies of retained numeric inputs. New ownership/command/source
//! bindings are manufactured only inside tests; no physical record is changed.
use super::super::partial_native_reference_composition as direct;
use super::partial_fall_control_tests::collection_for;
use super::*;
use crate::recovery::partial_fall as partial;
use sha2::{Digest, Sha256};
use std::sync::OnceLock;

fn fixtures() -> &'static serde_json::Value {
    static DATA: OnceLock<serde_json::Value> = OnceLock::new();
    DATA.get_or_init(|| {
        let binding: serde_json::Value = serde_json::from_str(include_str!(
            "../../../contracts/r10dd_native_reference_inputs_v1.json"
        ))
        .unwrap();
        let raw = std::fs::read(binding["fixture"]["path"].as_str().unwrap()).unwrap();
        assert_eq!(
            format!("sha256:{:x}", Sha256::digest(&raw)),
            binding["fixture"]["raw_sha256"]
        );
        assert_eq!(
            raw.len() as u64,
            binding["fixture"]["byte_length"].as_u64().unwrap()
        );
        serde_json::from_slice(&raw).unwrap()
    })
}

fn entry_request() -> direct::EntryControlRequest {
    let mut request: direct::EntryControlRequest =
        serde_json::from_value(fixtures()["entry_request"].clone()).unwrap();
    request.schema_version = direct::ENTRY_CONTROL_REQUEST.into();
    request
}

fn rebind(request: &mut direct::StepControlRequest) {
    request.collection = collection_for(
        &request.step.observation,
        &request
            .step
            .declaration
            .entry_request
            .passive_request
            .declaration
            .initialization,
        request.step.memory.phase,
    );
}

fn request(
    index: usize,
    memory: partial::Memory,
    reference_memory: Option<direct::ReferenceMemory>,
    command_sha: String,
) -> direct::StepControlRequest {
    let mut value = fixtures()["step_requests"][index].clone();
    value["reference_memory"] = serde_json::Value::Null;
    let mut request: direct::StepControlRequest = serde_json::from_value(value).unwrap();
    request.schema_version = direct::STEP_CONTROL_REQUEST.into();
    request.step.memory = memory;
    request.reference_memory = reference_memory;
    request
        .step
        .observation
        .controller_ownership
        .recovery_controller_id =
        Some(EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID.into());
    request.step.observation.applied_actuation.command_sha256 = command_sha;
    rebind(&mut request);
    request
}

fn first() -> direct::StepControlRequest {
    let entry = direct::entry_control(entry_request()).unwrap();
    request(
        0,
        entry
            .original_entry_control
            .original_control
            .entry
            .partial_memory
            .unwrap(),
        None,
        entry
            .initial_partial_control
            .unwrap()
            .command_sha256
            .unwrap(),
    )
}

fn second() -> direct::StepControlRequest {
    let prior = direct::step_control(first()).unwrap();
    request(
        1,
        prior.step.memory,
        prior.reference_memory,
        prior.next_control.unwrap().command_sha256.unwrap(),
    )
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

fn fixture<T: serde::Serialize, R: serde::Serialize>(
    id: &str,
    method: &str,
    request: &T,
    result: &R,
) {
    println!(
        "R10DD_NATIVE_FIXTURE {}",
        json!({"id":id,"physical_source":false,"synthetic_source_rebinding":true,
        "method":method,"request":request,"expected":result})
    );
}

#[test]
fn r10dd_setup_preserves_original_selector_and_physical_commands() {
    let request = entry_request();
    let result = direct::entry_control(request.clone()).unwrap();
    let mut original_request = request.clone();
    original_request.schema_version =
        super::super::upright_recovery_control::ENTRY_CONTROL_REQUEST.into();
    assert_eq!(
        result.original_entry_control,
        super::super::upright_recovery_control::entry_control(original_request).unwrap()
    );
    let control = result.initial_partial_control.as_ref().unwrap();
    assert_eq!(
        serde_json::to_value(&control.ordered_commands).unwrap(),
        fixtures()["original_setup_commands"]
    );
    assert_eq!(
        control.controller_id,
        EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID
    );
    assert_eq!(
        control.observation_sha256,
        Some(
            digest_serializable(&request.entry.original_request.passive_request.observation)
                .unwrap()
        )
    );
    assert!(
        result.reference_memory.is_none()
            && !result.physical_acceptance_authority
            && !result.release_authority
    );
    assert_eq!(
        serde_json::to_value(&result).unwrap(),
        abi(
            &request,
            crate::ffi::ss_recovery_r10dd_partial_entry_control_v1_json
        )
    );
    fixture(
        "partial_entry",
        "recovery_r10dd_partial_entry_control_v1",
        &request,
        &result,
    );
}

#[test]
fn r10dd_all_236_commands_preserve_task_caps_sources_and_final_observation() {
    let entry = direct::entry_control(entry_request()).unwrap();
    let setup = entry.initial_partial_control.unwrap();
    let mut command_sha = setup.command_sha256.clone().unwrap();
    let mut memory = entry
        .original_entry_control
        .original_control
        .entry
        .partial_memory
        .unwrap();
    let mut reference = None;
    let mut last = None;
    for index in 0..237 {
        let input = request(
            index,
            memory.clone(),
            reference.clone(),
            command_sha.clone(),
        );
        let expected_task = partial::step(input.step.clone()).unwrap();
        let result = direct::step_control(input.clone()).unwrap();
        assert_eq!(result.step, expected_task);
        assert!(
            !result.physical_acceptance_authority
                && !result.release_authority
                && !result.original_observation_rewritten
        );
        assert_eq!((result.world_build_count, result.solver_step_count), (0, 0));
        if index < 236 {
            let point = super::super::partial_native_reference_control::ReferenceSchedule::load()
                .unwrap()
                .reference_at(index as u32 + 1)
                .unwrap();
            let control = result.next_control.as_ref().unwrap();
            assert_eq!(
                result.next_reference,
                Some(serde_json::to_value(&point).unwrap())
            );
            assert!(result.diagnostic_stop_reason.is_none());
            assert_eq!(
                control.observation_sha256,
                Some(digest_serializable(&input.step.observation).unwrap())
            );
            for (j, c) in control.ordered_commands.iter().enumerate() {
                assert_eq!(
                    c.target_position_rad,
                    project_binary64_to_guarded_canonical_number_v1(
                        point.ordered_target_positions_rad[j]
                    )
                    .unwrap()
                );
                assert_eq!(c.maximum_target_speed_rad_s, 4.0);
                assert_eq!(
                    c.maximum_outer_step_impulse_nms,
                    setup.ordered_commands[j].maximum_outer_step_impulse_nms
                );
                assert_eq!(c.joint_id, setup.ordered_commands[j].joint_id);
            }
            command_sha = control.command_sha256.clone().unwrap();
            println!(
                "R10DD_COMMAND_REFERENCE {}",
                json!({"tick":index+1,"semantic_step":control.semantic_step,
                "targets":control.ordered_commands.iter().map(|c|c.target_position_rad).collect::<Vec<_>>()})
            );
        } else {
            assert!(result.next_control.is_none() && result.next_reference.is_none());
            assert_eq!(
                result.diagnostic_stop_reason.as_deref(),
                Some("finite_reference_exhausted_not_recovery_completion")
            );
            assert_eq!(result.step.next_phase, RecoveryPhaseV1::RaiseBody);
            assert!(!result.step.partial_fall_standing_complete);
            assert!(result.reference_memory.as_ref().unwrap().finished);
        }
        if [0, 1, 235, 236].contains(&index) {
            assert_eq!(
                serde_json::to_value(&result).unwrap(),
                abi(
                    &input,
                    crate::ffi::ss_recovery_r10dd_partial_step_control_v1_json
                )
            );
            fixture(
                &format!("reference_observation_{}", index + 1),
                "recovery_r10dd_partial_step_control_v1",
                &input,
                &result,
            );
        }
        memory = result.step.memory.clone();
        reference = result.reference_memory.clone();
        last = Some(result);
    }
    let end = last.unwrap();
    let mut resume = second();
    resume.reference_memory = end.reference_memory;
    assert!(direct::step_control(resume).is_err());
}

#[test]
fn r10dd_full_physical_entry_projection_refuses_drift() {
    for case in 0..9 {
        let mut bad = first();
        let o = &mut bad.step.observation;
        match case {
            0 => {
                o.state.ordered_joint_observations[0].position_rad =
                    Some(o.state.ordered_joint_observations[0].position_rad.unwrap() + 2e-6)
            }
            1 => o.state.base_pose_world.position_m.x += 2e-6,
            2 => o.state.base_twist_world.linear_velocity_m_s.x += 2e-6,
            3 => o.state.base_twist_world.angular_velocity_rad_s.x += 2e-6,
            4 => o.center_of_mass.position_world_m.x += 2e-6,
            5 => o.center_of_mass.linear_velocity_world_m_s.x += 2e-6,
            6 => o.ordered_foot_bearing_observations[0].bearing_normal_impulse_ns += 2e-6,
            7 => o.ordered_body_clearance_observations[0].minimum_nonfoot_clearance_m += 2e-6,
            _ => {
                o.state.ordered_joint_observations[0].velocity_rad_s = Some(
                    o.state.ordered_joint_observations[0]
                        .velocity_rad_s
                        .unwrap()
                        + 2e-6,
                )
            }
        }
        rebind(&mut bad);
        assert!(direct::step_control(bad).is_err(), "case {case}");
    }
    let mut bad = entry_request();
    bad.entry
        .original_request
        .passive_request
        .observation
        .state
        .base_pose_world
        .position_m
        .x += 2e-6;
    assert!(direct::entry_control(bad).is_err());
}

#[test]
fn r10dd_owner_source_energy_clock_and_setup_command_refusals() {
    for case in 0..10 {
        let mut bad = first();
        match case {
            0 => {
                bad.schema_version =
                    super::super::partial_progressive_headroom_composition::STEP_CONTROL_REQUEST
                        .into()
            }
            1 => {
                bad.collection
                    .observation
                    .controller_ownership
                    .recovery_controller_id =
                    Some(EXACT_S169_PARTIAL_PROGRESSIVE_HEADROOM_CONTROLLER_V28_ID.into())
            }
            2 => bad.collection.observation_source_binding.source_route_id = "crossed".into(),
            3 => bad.collection.descriptor.torso_length_scale += 0.01,
            4 => bad.step.observation.semantic_step += 1,
            5 => {
                bad.step
                    .observation
                    .energy_balance
                    .cumulative_signed_external_work_j += 1.
            }
            6 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            7 => bad.collection.runtime_binding.collector_id = "crossed".into(),
            8 => {
                bad.step.observation.applied_actuation.command_sha256 = SHA_A.into();
                rebind(&mut bad);
            }
            _ => bad.step.memory.phase_steps_observed += 1,
        }
        assert!(direct::step_control(bad).is_err(), "case {case}");
    }
}

#[test]
fn r10dd_reference_memory_and_previous_command_cannot_be_crossed() {
    for case in 0..9 {
        let mut bad = second();
        if case == 0 {
            bad.reference_memory = None;
        } else {
            let m = bad.reference_memory.as_mut().unwrap();
            match case {
                1 => m.finished = true,
                2 => m.declaration_sha256 = SHA_A.into(),
                3 => m.profile_sha256 = SHA_A.into(),
                4 => m.entry_semantic_step += 1,
                5 => m.last_planned_semantic_step += 1,
                6 => m.last_planned_reference_tick += 1,
                7 => m.last_command_sha256 = SHA_A.into(),
                _ => m.schema_version = "crossed".into(),
            }
        }
        assert!(direct::step_control(bad).is_err(), "case {case}");
    }
}

#[test]
fn r10dd_early_original_supervisor_transition_stops_without_next_command() {
    let mut input = second();
    let o = &mut input.step.observation;
    o.state.base_pose_world.position_m.y = 0.8;
    o.state.base_pose_world.orientation_xyzw = Quaternion {
        x: 0.,
        y: 0.,
        z: 0.,
        w: 1.,
    };
    o.center_of_mass.position_world_m.y = 0.8;
    for body in &mut o.ordered_body_clearance_observations {
        body.minimum_nonfoot_clearance_m = 0.1;
        body.accumulated_nonfoot_normal_impulse_ns = 0.;
        body.nonfoot_contact_present = false;
        body.ventral_surface_contact = false;
        body.engine_contact_ids.clear();
    }
    rebind(&mut input);
    let original = partial::step(input.step.clone()).unwrap();
    assert_eq!(original.next_phase, RecoveryPhaseV1::StanceHandoff);
    let result = direct::step_control(input.clone()).unwrap();
    assert_eq!(result.step, original);
    assert!(result.next_control.is_none() && result.next_reference.is_none());
    assert_eq!(
        result.diagnostic_stop_reason.as_deref(),
        Some("original_supervisor_phase_transition")
    );
    assert!(result.reference_memory.unwrap().finished);
}

#[test]
fn r10dd_generic_profile_remains_unsupported_and_receipt_is_strict() {
    let input = super::smooth_stance_control_tests::recovery_request(
        RecoveryNativeEngineV1::GodotJolt4_7,
        RecoveryPhaseV1::EstablishDistalSupport,
        EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID,
    );
    let result = plan_recovery_control_v1(input).unwrap();
    assert_eq!(
        result.support_status,
        RecoverySupportStatusV1::UnsupportedProfile
    );
    assert!(result.no_actuation_requested && result.ordered_commands.is_empty());
    let result = direct::step_control(first()).unwrap();
    let value = serde_json::to_value(&result).unwrap();
    assert_eq!(
        result,
        serde_json::from_value::<direct::StepControlReceipt>(value.clone()).unwrap()
    );
    let mut bad = value;
    bad["physical_execution_authorized"] = true.into();
    assert!(serde_json::from_value::<direct::StepControlReceipt>(bad).is_err());
}
