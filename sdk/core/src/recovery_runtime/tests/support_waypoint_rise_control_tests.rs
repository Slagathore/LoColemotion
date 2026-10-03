//! V13 command-path checks. Ideal tracking is algebra, not simulated physics.
use super::*;

const SUPPORT_ENTRY: [f64; 8] = [-1.4525072574615479, -0.0974312275648117,
    -1.4607325792312622, -0.09484612941741943, -1.4609103202819824,
    -0.8731687068939209, -1.4607722759246826, -0.08408135920763016];
// Original V12 step 410, report 0e0d4699..., before its first raising command.
const RISE_ENTRY: [f64; 8] = [-1.4540300369262695, -0.08694559335708618,
    -1.4813200235366821, -0.03961467370390892, -1.4592338800430298,
    -0.08806305378675461, -1.4627629518508911, -0.0546673983335495];

fn request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
    collection.observation.controller_ownership.recovery_controller_id = Some(id.to_owned());
    let positions = if phase == RecoveryPhaseV1::RaiseBody { RISE_ENTRY } else { SUPPORT_ENTRY };
    for (joint, position) in collection.observation.state.ordered_joint_observations.iter_mut().zip(positions) {
        joint.position_rad = Some(position);
    }
    RecoveryControlRequestV1 { schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: id.to_owned(), phase_step: 0, collection }
}

#[test]
fn v13_preserves_v12_destinations_caps_clock_and_claim_limits() {
    let mut expected = recovery_development_profile_v12();
    let actual = recovery_development_profile_v13();
    expected.profile_id = actual.profile_id.clone();
    expected.controller_id = actual.controller_id.clone();
    expected.stance_pose.pose_id = actual.stance_pose.pose_id.clone();
    assert_eq!(expected, actual);
    assert_eq!(360, actual.raise_body_ramp_steps);
    assert_eq!(vec![-0.6, 1.05, -0.6, 1.05, -0.6, 1.05, -0.6, 1.05],
        actual.establish_distal_support_pose.ordered_target_positions_rad);
    assert!(!actual.physical_execution_authorized);
    assert!(!actual.physical_acceptance_authority);
    assert!(!actual.release_authority);
}

#[test]
fn v13_first_command_approaches_support_waypoint_on_all_adapter_inputs() {
    let profile = recovery_development_profile_v13();
    let waypoint = &profile.establish_distal_support_pose.ordered_target_positions_rad;
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let output = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V13_ID)).unwrap();
        assert_eq!(RecoverySupportStatusV1::SupportedExact, output.support_status);
        assert_eq!(8, output.ordered_commands.len());
        for (i, command) in output.ordered_commands.iter().enumerate() {
            let expected = RISE_ENTRY[i] + (waypoint[i] - RISE_ENTRY[i]) * smoothstep(1.0 / 180.0);
            assert_eq!(project_binary64_to_guarded_canonical_number_v1(expected).unwrap(), command.target_position_rad);
            assert_eq!(4.0, command.maximum_target_speed_rad_s);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &output.ordered_commands); }
        else { reference = Some(output.ordered_commands); }
        assert_eq!(0, output.engine_identity_input_count);
        assert_eq!(0, output.world_build_count);
    }
}

#[test]
fn v13_ideal_tracking_visits_waypoint_then_stance_within_same_clock() {
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V13_ID);
    let profile = recovery_development_profile_v13();
    let waypoint = &profile.establish_distal_support_pose.ordered_target_positions_rad;
    let joints = &mut input.collection.observation.state.ordered_joint_observations;
    for step in 0..360 {
        let targets = support_waypoint_rise_reference(waypoint, &[0.0; 8], joints, 4.0, step, 360).unwrap();
        for i in 0..8 {
            let expected = if step < 180 {
                RISE_ENTRY[i] + (waypoint[i] - RISE_ENTRY[i]) * smoothstep((step as f64 + 1.0) / 180.0)
            } else {
                waypoint[i] * (1.0 - smoothstep((step as f64 - 179.0) / 180.0))
            };
            assert!((targets[i] - expected).abs() < 1e-12);
            assert!((targets[i] - joints[i].position_rad.unwrap()).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
            joints[i].position_rad = Some(targets[i]);
        }
        if step == 179 { assert_eq!(waypoint, &targets); }
    }
    assert!(joints.iter().all(|j| j.position_rad == Some(0.0)));
}

#[test]
fn v13_segment_boundary_uses_measured_error_not_a_fabricated_completed_waypoint() {
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V13_ID);
    input.phase_step = 180;
    let output = plan_recovery_control_v1(input.clone()).unwrap();
    for (i, command) in output.ordered_commands.iter().enumerate() {
        let expected = RISE_ENTRY[i] * (1.0 - smoothstep(1.0 / 180.0));
        assert_eq!(project_binary64_to_guarded_canonical_number_v1(expected).unwrap(), command.target_position_rad);
    }
    input.collection.observation.state.ordered_joint_observations[0].position_rad = Some(-0.2);
    let shifted = plan_recovery_control_v1(input).unwrap();
    assert_ne!(output.ordered_commands[0], shifted.ordered_commands[0]);
    assert_eq!(output.ordered_commands[1..], shifted.ordered_commands[1..]);
    assert!(!output.stance_handoff_requested);
}

#[test]
fn v13_late_error_odd_clock_and_terminal_clocks_keep_existing_command_bound() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V13_ID);
    let joints = &input.collection.observation.state.ordered_joint_observations;
    let profile = recovery_development_profile_v13();
    let waypoint = &profile.establish_distal_support_pose.ordered_target_positions_rad;
    for ramp in [2, 360, 361] {
        for step in [0, 179, 180, 359, 360, 900, u32::MAX] {
            let targets = support_waypoint_rise_reference(waypoint, &[0.0; 8], joints, 4.0, step, ramp).unwrap();
            for i in 0..8 {
                assert!(targets[i].is_finite());
                assert!((targets[i] - RISE_ENTRY[i]).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
            }
        }
    }
    for ramp in [0, 1] {
        assert!(support_waypoint_rise_reference(waypoint, &[0.0; 8], joints, 4.0, 0, ramp).is_err());
    }
}

#[test]
fn v13_invalid_missing_or_crossed_sources_refuse_both_segments() {
    for step in [0, 180] {
        for case in 0..4 {
            let mut bad = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V13_ID);
            bad.phase_step = step;
            match case {
                0 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
                1 => bad.collection.observation.state.ordered_joint_observations[1].validity.position = false,
                2 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
                _ => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V12_ID.to_owned()),
            }
            let output = plan_recovery_control_v1(bad).unwrap();
            assert!(output.no_actuation_requested);
            assert!(output.ordered_commands.is_empty());
        }
    }
}

#[test]
fn v13_preserves_v12_support_and_other_phase_commands() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V12_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V13_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
    }
}

#[test]
fn v13_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V13_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            let input = serde_json::to_vec(&request).unwrap();
            let mut required = 0;
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut required) }, SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8; required];
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), output.as_mut_ptr(), output.len(), &mut required) }, SS_OK);
            let actual: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(actual["value"], serde_json::to_value(&expected).unwrap());
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "retained_joint_angles_injected": true,
                "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
