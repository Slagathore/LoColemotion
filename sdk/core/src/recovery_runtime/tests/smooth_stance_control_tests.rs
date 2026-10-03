//! V15 keeps V14 recovery motion; stance v2 relaxes measured position error.
use super::*;

pub(super) fn recovery_request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
    collection.observation.controller_ownership.recovery_controller_id = Some(id.to_owned());
    RecoveryControlRequestV1 { schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: id.to_owned(), phase_step: 150, collection }
}

pub(super) fn stance_request(phase: RecoveryPhaseV1, smooth: bool, positions: [f64; 8]) -> RecoveryStanceControlRequestV4 {
    let (mut collection, mut observation, mut step, authority, mut progression) = actual_development_handoff_inputs();
    let id = if smooth { stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V15_ID) } else { EXACT_S169_STANCE_CONTROLLER_ID };
    collection.phase = phase;
    let ownership = &mut collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        ownership.recovery_controller_id = Some(if smooth { EXACT_S169_RECOVERY_CONTROLLER_V15_ID } else { EXACT_S169_RECOVERY_CONTROLLER_V14_ID }.to_owned());
    } else {
        ownership.owner = RecoveryControllerOwnerV1::Stance;
        ownership.recovery_controller_id = None;
        ownership.stance_controller_id = Some(id.to_owned());
        ownership.handoff_event_count = 1;
        step.prior_phase = phase;
        step.next_phase = phase;
        step.transitioned = false;
        step.memory.as_mut().unwrap().phase = phase;
        step.memory.as_mut().unwrap().phase_steps_observed = 42;
        step.classification.as_mut().unwrap().exclusive_stance_handoff_gate = true;
        progression.development_progression_used = false;
    }
    for (joint, position) in collection.observation.state.ordered_joint_observations.iter_mut().zip(positions) {
        joint.position_rad = Some(position);
    }
    observation.controller_ownership = collection.observation.controller_ownership.clone();
    observation.state.ordered_joint_observations = collection.observation.state.ordered_joint_observations.clone();
    let source = &collection.observation_source_binding;
    collection.observation_source_binding = bind_recovery_observation_v2_source_v1(
        &collection.observation, &collection.observation.engine_step_identity.adapter_id,
        &source.source_route_id, &source.mapping_profile_id, SHA_A, SHA_B).unwrap();
    step.observation_sha256 = Some(digest_serializable(&observation).unwrap());
    RecoveryStanceControlRequestV4 { schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION.to_owned(),
        controller_id: id.to_owned(), collection, portable_step_observation_v3: observation,
        handoff_or_stance_step: step, energy_partition_authority: authority, development_progression: progression }
}

#[test]
fn v15_preserves_v14_recovery_commands_profile_gates_and_caps() {
    let mut old = recovery_development_profile_v14();
    let new = recovery_development_profile_v15();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    assert_eq!(old, new);
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            for clock in [0, 119, 120, 150, 239, 240, 359, 360] {
                let mut old = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
                let mut new = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V15_ID);
                old.phase_step = clock; new.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(old).unwrap().ordered_commands, plan_recovery_control_v1(new).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn stance_v2_relaxes_measured_error_with_unchanged_speed_and_force_caps() {
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for positions in [[0.0; 8], [0.005, -0.005, 0.025, -0.025, 0.1, -0.1, 0.2, -0.2]] {
            let request = stance_request(phase, true, positions);
            let pristine = serde_json::to_value(&request).unwrap();
            let result = plan_recovery_stance_control_v4(request.clone()).unwrap();
            let legacy = plan_recovery_stance_control_v4(stance_request(phase, false, positions)).unwrap();
            assert_eq!(pristine, serde_json::to_value(&request).unwrap());
            assert_ne!(result.control_receipt.controller_profile_sha256, legacy.control_receipt.controller_profile_sha256);
            assert_eq!(result.control_receipt.controller_id, stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V15_ID));
            for ((command, old), position) in result.control_receipt.ordered_commands.iter().zip(&legacy.control_receipt.ordered_commands).zip(positions) {
                assert_eq!(command.maximum_target_speed_rad_s, old.maximum_target_speed_rad_s);
                assert_eq!(command.maximum_outer_step_impulse_nms, old.maximum_outer_step_impulse_nms);
                assert_eq!(command.target_velocity_rad_s, 0.0);
                let expected_speed = (-position / 0.1).clamp(-0.75, 0.75);
                let raw_target = position + RECOVERY_OUTER_STEP_DURATION_S * expected_speed;
                // The existing transport contract retains thirteen significant
                // decimal digits. Compare its exact result, then bound the
                // propagated speed error instead of assuming unrounded output.
                let expected_target: f64 = format!("{raw_target:.12e}").parse().unwrap();
                assert_eq!(command.target_position_rad, expected_target);
                let speed = (command.target_position_rad - position) / RECOVERY_OUTER_STEP_DURATION_S;
                let rounding_bound = if raw_target == 0.0 { 0.0 } else {
                    0.5 * 10_f64.powf(raw_target.abs().log10().floor() - 12.0)
                };
                assert!((speed - expected_speed).abs() <= rounding_bound / RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
                assert!(command.target_position_rad.abs() <= position.abs());
            }
            assert!(!result.physical_acceptance_authority && !result.release_authority);
            assert_eq!(result.world_build_count, 0);
            assert_eq!(result.solver_step_count, 0);
        }
    }
}

#[test]
fn stance_v2_refuses_crossed_selection_and_observation() {
    let base = stance_request(RecoveryPhaseV1::RaiseBody, true, [0.005; 8]);
    let mut crossed = base.clone(); crossed.controller_id = EXACT_S169_STANCE_CONTROLLER_ID.to_owned();
    assert!(plan_recovery_stance_control_v4(crossed).is_err());
    let mut crossed = stance_request(RecoveryPhaseV1::RaiseBody, false, [0.005; 8]);
    crossed.controller_id = base.controller_id.clone();
    assert!(plan_recovery_stance_control_v4(crossed).is_err());
    for case in 0..3 {
        let mut changed = base.clone();
        match case {
            0 => changed.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            1 => changed.collection.observation.state.ordered_joint_observations[0].validity.position = false,
            _ => changed.portable_step_observation_v3.state.ordered_joint_observations[0].position_rad = Some(0.02),
        }
        assert!(plan_recovery_stance_control_v4(changed).is_err());
    }
}

#[test]
fn v15_exported_native_shaped_fixtures() {
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V15_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for positions in [[0.0; 8], [0.005; 8], [-0.2; 8]] {
            let request = stance_request(phase, true, positions);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
