//! V25/controller V19: neutral stance plus existing damping, not a stability proof.
use super::*;
use super::smooth_stance_control_tests::recovery_request;

fn retained() -> serde_json::Value {
    serde_json::from_str(include_str!("../../../contracts/recovery_v25_retained_walking_handoff_fixture_v1.json")).unwrap()
}

fn support_request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut req = recovery_request(engine, phase, id);
    let source: serde_json::Value = serde_json::from_str(include_str!("../../../contracts/recovery_v22_retained_support_fixture_v1.json")).unwrap();
    req.collection.descriptor = serde_json::from_value(source["descriptor"].clone()).unwrap();
    req.collection.observation.state.ordered_joint_observations = serde_json::from_value(source["samples"][0]["state"]["ordered_joint_observations"].clone()).unwrap();
    req.collection.observation.state.base_pose_world = serde_json::from_value(source["samples"][0]["state"]["base_pose_world"].clone()).unwrap();
    req
}

fn stance_request(phase: RecoveryPhaseV1, positions: [f64; 8], velocities: [f64; 8]) -> RecoveryStanceControlRequestV4 {
    let mut req = super::damped_stance_control_tests::request(phase, positions, velocities);
    req.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V19_ID).to_owned();
    let owner = &mut req.collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        owner.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V19_ID.to_owned());
    } else { owner.stance_controller_id = Some(req.controller_id.clone()); }
    super::damped_stance_control_tests::rebind(&mut req);
    req
}

#[test]
fn v19_preserves_every_pre_stance_command_and_all_profile_limits() {
    let mut old = recovery_development_profile_v18();
    let new = recovery_development_profile_v19();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    assert_eq!(old, new);
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::Failed] {
            for clock in [0, 119, 120, 239, 240, 359, 360] {
                let mut before = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
                let mut after = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V19_ID);
                before.phase_step = clock; after.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(before).unwrap().ordered_commands,
                           plan_recovery_control_v1(after).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn v19_goal_matches_retained_zero_amplitude_command_and_keeps_damping_and_caps() {
    let old = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V18_ID)).unwrap();
    let new = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V19_ID)).unwrap();
    assert_eq!(old["response_time_s"], new["response_time_s"]);
    assert_eq!(candidate_stance_velocity_damping(old).unwrap(), candidate_stance_velocity_damping(new).unwrap());
    let descriptor = actual_development_handoff_inputs().0.descriptor;
    let goals = candidate_stance_goal_positions(new, &descriptor).unwrap();
    let source = retained();
    let walking: Vec<f64> = serde_json::from_value(source["ordered_first_walking_target_positions_rad"].clone()).unwrap();
    assert_eq!(goals.to_vec(), walking);
    assert_eq!([0.0; 8], goals);
    assert_ne!(candidate_stance_goal_positions(old, &descriptor).unwrap(), goals);
    let observed: Vec<crate::protocol::JointObservation> = serde_json::from_value(source["ordered_joint_observations"].clone()).unwrap();
    let positions: [f64; 8] = observed.iter().map(|j| j.position_rad.unwrap()).collect::<Vec<_>>().try_into().unwrap();
    let velocities: [f64; 8] = observed.iter().map(|j| j.velocity_rad_s.unwrap()).collect::<Vec<_>>().try_into().unwrap();
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        let req = stance_request(phase, positions, velocities);
        let original = serde_json::to_value(&req).unwrap();
        let result = plan_recovery_stance_control_v4(req.clone()).unwrap();
        assert_eq!(original, serde_json::to_value(req).unwrap());
        let old_result = plan_recovery_stance_control_v4(super::damped_stance_control_tests::request(phase, positions, velocities)).unwrap();
        for (i, (cmd, old_cmd)) in result.control_receipt.ordered_commands.iter().zip(old_result.control_receipt.ordered_commands).enumerate() {
            let speed = (-positions[i] / 0.1 - 0.5 * velocities[i]).clamp(-0.75, 0.75);
            let raw = positions[i] + RECOVERY_OUTER_STEP_DURATION_S * speed;
            assert_eq!(format!("{raw:.12e}").parse::<f64>().unwrap(), cmd.target_position_rad);
            assert_eq!(old_cmd.maximum_outer_step_impulse_nms, cmd.maximum_outer_step_impulse_nms);
            assert_eq!(0.75, cmd.maximum_target_speed_rad_s);
        }
        assert_eq!((0, 0), (result.world_build_count, result.solver_step_count));
        assert!(!result.physical_acceptance_authority && !result.release_authority);
    }
}

#[test]
fn v19_refuses_crossed_ownership_or_unusable_velocity() {
    let req = stance_request(RecoveryPhaseV1::StanceDwell, [0.12; 8], [0.2; 8]);
    let mut crossed = req.clone();
    crossed.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V18_ID).to_owned();
    assert!(plan_recovery_stance_control_v4(crossed).is_err());
    for missing in [true, false] {
        let mut bad = req.clone();
        let joint = &mut bad.collection.observation.state.ordered_joint_observations[0];
        if missing { joint.velocity_rad_s = None; } else { joint.validity.velocity = false; }
        super::damped_stance_control_tests::rebind(&mut bad);
        assert!(plan_recovery_stance_control_v4(bad).is_err());
    }
}

#[test]
fn v19_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V19_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            assert_eq!(8, expected.ordered_commands.len());
            let input = serde_json::to_vec(&request).unwrap(); let mut required = 0;
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut required) }, SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8; required];
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), output.as_mut_ptr(), output.len(), &mut required) }, SS_OK);
            let actual: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(actual["value"], serde_json::to_value(&expected).unwrap());
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "retained_pose_values_injected": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for (positions, velocities) in [([0.0; 8], [0.0; 8]), ([0.005; 8], [-0.2; 8]),
                ([0.12, -0.25, 0.12, -0.25, 0.12, -0.25, 0.12, -0.25], [0.2; 8])] {
            let request = stance_request(phase, positions, velocities);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            assert_eq!(8, expected.control_receipt.ordered_commands.len());
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
