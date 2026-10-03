//! V17 tests opposing measured velocity without changing V16's pose or gates.
use super::*;
use super::smooth_stance_control_tests::{recovery_request, stance_request};

pub(super) fn rebind(request: &mut RecoveryStanceControlRequestV4) {
    let o = &request.collection.observation;
    request.portable_step_observation_v3.controller_ownership = o.controller_ownership.clone();
    request.portable_step_observation_v3.state.ordered_joint_observations = o.state.ordered_joint_observations.clone();
    let source = &request.collection.observation_source_binding;
    request.collection.observation_source_binding = bind_recovery_observation_v2_source_v1(
        o, &o.engine_step_identity.adapter_id, &source.source_route_id, &source.mapping_profile_id, SHA_A, SHA_B).unwrap();
    request.handoff_or_stance_step.observation_sha256 = Some(digest_serializable(&request.portable_step_observation_v3).unwrap());
}

pub(super) fn request(phase: RecoveryPhaseV1, positions: [f64; 8], velocities: [f64; 8]) -> RecoveryStanceControlRequestV4 {
    let mut value = stance_request(phase, true, positions);
    value.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V17_ID).to_owned();
    let owner = &mut value.collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        owner.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V17_ID.to_owned());
    } else {
        owner.stance_controller_id = Some(value.controller_id.clone());
    }
    for (joint, velocity) in value.collection.observation.state.ordered_joint_observations.iter_mut().zip(velocities) {
        joint.velocity_rad_s = Some(velocity);
        joint.validity.velocity = true;
    }
    rebind(&mut value);
    value
}

#[test]
fn v17_preserves_v16_get_up_commands_thresholds_and_caps() {
    let mut old = recovery_development_profile_v16();
    let new = recovery_development_profile_v17();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    assert_eq!(old, new);
    let prior = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V16_ID)).unwrap();
    let next = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V17_ID)).unwrap();
    let descriptor = actual_development_handoff_inputs().0.descriptor;
    assert_eq!(candidate_stance_goal_positions(prior, &descriptor).unwrap(), candidate_stance_goal_positions(next, &descriptor).unwrap());
    assert_eq!(prior["response_time_s"], next["response_time_s"]);
    assert_eq!(None, candidate_stance_velocity_damping(prior).unwrap());
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            for clock in [0,119,120,150,239,240,359,360] {
                let mut old = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V16_ID);
                let mut new = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V17_ID);
                old.phase_step = clock; new.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(old).unwrap().ordered_commands, plan_recovery_control_v1(new).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn v17_opposes_velocity_and_preserves_native_command_bounds() {
    let profile = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V17_ID)).unwrap();
    let goals = candidate_stance_goal_positions(profile, &actual_development_handoff_inputs().0.descriptor).unwrap();
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for velocity in [-5.0, -0.2, 0.0, 0.2, 5.0] {
            let req = request(phase, goals, [velocity; 8]);
            let original = serde_json::to_value(&req).unwrap();
            let result = plan_recovery_stance_control_v4(req.clone()).unwrap();
            assert_eq!(original, serde_json::to_value(req).unwrap());
            let previous = plan_recovery_stance_control_v4(stance_request(phase, true, goals)).unwrap();
            for ((command, old), position) in result.control_receipt.ordered_commands.iter().zip(&previous.control_receipt.ordered_commands).zip(goals) {
                assert_eq!(old.maximum_outer_step_impulse_nms, command.maximum_outer_step_impulse_nms);
                assert_eq!(0.75, command.maximum_target_speed_rad_s);
                assert_eq!(0.0, command.target_velocity_rad_s);
                let expected = (-0.5 * velocity).clamp(-0.75, 0.75);
                let raw = position + RECOVERY_OUTER_STEP_DURATION_S * expected;
                assert_eq!(format!("{raw:.12e}").parse::<f64>().unwrap(), command.target_position_rad);
                let realized_request = (command.target_position_rad - position) / RECOVERY_OUTER_STEP_DURATION_S;
                assert!((realized_request - expected).abs() < 1e-10);
                if velocity != 0.0 { assert!(realized_request * velocity < 0.0); }
            }
            assert!(!result.physical_acceptance_authority && !result.release_authority);
            assert_eq!((0,0), (result.world_build_count, result.solver_step_count));
        }
    }
    // A deliberately ideal, unsaturated one-step velocity follower, not native
    // physics: verify signs/units and decay of this selected discrete rule.
    for (mut error, mut velocity) in [(0.08, 0.2), (-0.08, -0.2), (0.0, 0.2)] {
        for _ in 0..240 {
            velocity = -error / 0.1 - 0.5 * velocity;
            error += RECOVERY_OUTER_STEP_DURATION_S * velocity;
        }
        assert!(error.abs() < 1e-6 && velocity.abs() < 1e-5);
    }
}

#[test]
fn v17_refuses_unusable_velocity_crossed_identity_and_invalid_gain() {
    let base = request(RecoveryPhaseV1::StanceDwell, [0.12;8], [0.2;8]);
    for id in [EXACT_S169_STANCE_CONTROLLER_ID, stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V16_ID)] {
        let mut crossed = base.clone(); crossed.controller_id = id.to_owned();
        assert!(plan_recovery_stance_control_v4(crossed).is_err());
    }
    for missing in [false, true] {
        let mut bad = base.clone();
        let joint = &mut bad.collection.observation.state.ordered_joint_observations[0];
        if missing { joint.velocity_rad_s = None; } else { joint.validity.velocity = false; }
        rebind(&mut bad);
        assert!(plan_recovery_stance_control_v4(bad).is_err());
    }
    let profile = candidate_stance_profile(&base.controller_id).unwrap();
    for value in [json!(-0.1), json!(1.0), json!("0.5"), serde_json::Value::Null] {
        let mut bad = profile.clone(); bad["measured_velocity_damping_gain"] = value;
        assert!(candidate_stance_velocity_damping(&bad).is_err());
    }
    assert_eq!(Some(0.5), candidate_stance_velocity_damping(profile).unwrap());
}

#[test]
fn v17_exported_native_shaped_fixtures() {
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V17_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for (positions, velocities) in [([0.0;8],[0.2,-0.2,0.2,-0.2,0.2,-0.2,0.2,-0.2]),
            ([0.005;8],[-0.2,0.2,-0.2,0.2,-0.2,0.2,-0.2,0.2]),
            ([0.12,-0.25,0.12,-0.25,0.12,-0.25,0.12,-0.25],[2.0,-2.0,2.0,-2.0,2.0,-2.0,2.0,-2.0])] {
            let request = request(phase, positions, velocities);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}", json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
}
