//! V27/controller V20: a bounded reference ramp, never a native stability proof.
use super::*;
use super::smooth_stance_control_tests::recovery_request;

fn support_request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut req = recovery_request(engine, phase, id);
    let source: serde_json::Value = serde_json::from_str(include_str!("../../../contracts/recovery_v22_retained_support_fixture_v1.json")).unwrap();
    req.collection.descriptor = serde_json::from_value(source["descriptor"].clone()).unwrap();
    req.collection.observation.state.ordered_joint_observations = serde_json::from_value(source["samples"][0]["state"]["ordered_joint_observations"].clone()).unwrap();
    req.collection.observation.state.base_pose_world = serde_json::from_value(source["samples"][0]["state"]["base_pose_world"].clone()).unwrap();
    req
}

fn stance_request(id: &str, phase: RecoveryPhaseV1, clock: u32, positions: [f64; 8], velocities: [f64; 8]) -> RecoveryStanceControlRequestV4 {
    let mut req = super::damped_stance_control_tests::request(phase, positions, velocities);
    req.controller_id = stance_id_for_recovery(id).to_owned();
    let owner = &mut req.collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        owner.recovery_controller_id = Some(id.to_owned());
    } else {
        owner.stance_controller_id = Some(req.controller_id.clone());
        req.handoff_or_stance_step.memory.as_mut().unwrap().phase_steps_observed = clock;
    }
    super::damped_stance_control_tests::rebind(&mut req);
    req
}

#[test]
fn v20_preserves_every_pre_stance_command_and_all_limits() {
    let mut old = recovery_development_profile_v19();
    let new = recovery_development_profile_v20();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    assert_eq!(old, new);
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::Failed] {
            for clock in [0, 59, 60, 119, 120, 239, 240, 359, 360] {
                let mut before = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V19_ID);
                let mut after = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V20_ID);
                before.phase_step = clock; after.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(before).unwrap().ordered_commands,
                           plan_recovery_control_v1(after).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn v20_reference_is_bounded_and_neutral_by_earliest_possible_completion() {
    let descriptor = actual_development_handoff_inputs().0.descriptor;
    let profile = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID)).unwrap();
    let origin = candidate_stance_goal_positions(candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V18_ID)).unwrap(), &descriptor).unwrap();
    let thresholds = crate::recovery::recovery_physical_development_threshold_profile_v1();
    assert_eq!(60, thresholds.stance_dwell_steps);
    assert_eq!(240, thresholds.per_phase_timeout_steps.stance_dwell);
    let mut previous = candidate_stance_goals_for_control_step(profile, &descriptor, RecoveryPhaseV1::StanceHandoff, 0).unwrap();
    assert_eq!(origin, previous);
    assert_eq!(0.25, origin.into_iter().map(f64::abs).fold(0.0, f64::max));
    assert_eq!(0.75, 1.5 * 0.25 / (60.0 * RECOVERY_OUTER_STEP_DURATION_S));
    for completed in 0..240 {
        let goals = candidate_stance_goals_for_control_step(profile, &descriptor, RecoveryPhaseV1::StanceDwell, completed).unwrap();
        for i in 0..8 {
            assert!(goals[i].abs() <= previous[i].abs());
            assert!((goals[i] - previous[i]).abs() / RECOVERY_OUTER_STEP_DURATION_S <= 0.75);
        }
        if completed + 1 >= thresholds.stance_dwell_steps { assert_eq!([0.0; 8], goals); }
        previous = goals;
    }
    assert_eq!([0.0; 8], candidate_stance_goals_for_control_step(profile, &descriptor, RecoveryPhaseV1::StanceDwell, u32::MAX).unwrap());
    // Existing static profiles keep their exact goals at every clock.
    for id in [EXACT_S169_RECOVERY_CONTROLLER_V18_ID, EXACT_S169_RECOVERY_CONTROLLER_V19_ID] {
        let old = candidate_stance_profile(stance_id_for_recovery(id)).unwrap();
        for clock in [0, 29, 59, 60, 239] {
            assert_eq!(candidate_stance_goal_positions(old, &descriptor).unwrap(),
                candidate_stance_goals_for_control_step(old, &descriptor, RecoveryPhaseV1::StanceDwell, clock).unwrap());
        }
    }
}

#[test]
fn v20_actual_stance_path_preserves_observations_damping_and_caps() {
    let positions = [0.12, -0.25, 0.12, -0.25, 0.12, -0.25, 0.12, -0.25];
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for clock in [0, 29, 58, 59, 60, 239] {
            for velocity in [-2.0, 0.0, 2.0] {
                let req = stance_request(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, phase, clock, positions, [velocity; 8]);
                let original = serde_json::to_value(&req).unwrap();
                let result = plan_recovery_stance_control_v4(req.clone()).unwrap();
                assert_eq!(original, serde_json::to_value(&req).unwrap());
                let control = &result.control_receipt;
                let profile = candidate_stance_profile(&control.controller_id).unwrap();
                let goals = candidate_stance_goals_for_control_step(profile, &req.collection.descriptor, control.phase, control.phase_step).unwrap();
                let prior_id = if phase == RecoveryPhaseV1::RaiseBody { EXACT_S169_RECOVERY_CONTROLLER_V18_ID } else { EXACT_S169_RECOVERY_CONTROLLER_V19_ID };
                let prior = plan_recovery_stance_control_v4(stance_request(prior_id, phase, clock, positions, [velocity; 8])).unwrap();
                for (i, (cmd, old)) in control.ordered_commands.iter().zip(&prior.control_receipt.ordered_commands).enumerate() {
                    let speed = ((goals[i] - positions[i]) / 0.1 - 0.5 * velocity).clamp(-0.75, 0.75);
                    let raw = positions[i] + RECOVERY_OUTER_STEP_DURATION_S * speed;
                    assert_eq!(format!("{raw:.12e}").parse::<f64>().unwrap(), cmd.target_position_rad);
                    assert_eq!(old.maximum_outer_step_impulse_nms, cmd.maximum_outer_step_impulse_nms);
                    assert_eq!((0.75, 0.0), (cmd.maximum_target_speed_rad_s, cmd.target_velocity_rad_s));
                }
                if phase == RecoveryPhaseV1::RaiseBody || clock >= 59 {
                    assert_eq!(prior.control_receipt.ordered_commands, control.ordered_commands);
                }
                assert_eq!((0, 0), (result.world_build_count, result.solver_step_count));
                assert!(!result.physical_acceptance_authority && !result.release_authority);
            }
        }
    }
}

#[test]
fn v20_refuses_crossed_ownership_bad_velocity_and_undeclared_ramp() {
    let req = stance_request(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, RecoveryPhaseV1::StanceDwell, 29, [0.12; 8], [0.2; 8]);
    let mut crossed = req.clone();
    crossed.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V19_ID).to_owned();
    assert!(plan_recovery_stance_control_v4(crossed).is_err());
    for missing in [true, false] {
        let mut bad = req.clone();
        let joint = &mut bad.collection.observation.state.ordered_joint_observations[0];
        if missing { joint.velocity_rad_s = None; } else { joint.validity.velocity = false; }
        super::damped_stance_control_tests::rebind(&mut bad);
        assert!(plan_recovery_stance_control_v4(bad).is_err());
    }
    let profile = candidate_stance_profile(&req.controller_id).unwrap();
    for (key, value) in [("duration_steps", json!(0)), ("duration_steps", json!(61)),
        ("duration_steps", json!("60")), ("rule_id", json!("unknown")),
        ("initial_stance_controller_id", json!("sporespore_exact_s169_stance_handoff_controller_v6"))] {
        let mut bad = profile.clone(); bad["reference_ramp"][key] = value;
        assert!(candidate_stance_goals_for_control_step(&bad, &req.collection.descriptor, RecoveryPhaseV1::StanceDwell, 29).is_err());
    }
    assert!(candidate_stance_goals_for_control_step(profile, &req.collection.descriptor, RecoveryPhaseV1::Failed, 0).is_err());
}

#[test]
fn v20_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = support_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V20_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
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
        for (clock, positions, velocities) in [(0, [0.0; 8], [0.0; 8]), (29, [0.005; 8], [-0.2; 8]),
            (59, [0.12, -0.25, 0.12, -0.25, 0.12, -0.25, 0.12, -0.25], [0.2; 8])] {
            let request = stance_request(EXACT_S169_RECOVERY_CONTROLLER_V20_ID, phase, clock, positions, velocities);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
