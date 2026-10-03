//! Synthetic command/geometry checks, not contact or recovery evidence.
use super::*;

const ENTRY: [f64; 8] = [-1.4525072574615479, -0.0974312275648117,
    -1.4607325792312622, -0.09484612941741943,
    -1.4609103202819824, -0.8731687068939209,
    -1.4607722759246826, -0.08408135920763016];

fn request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
    collection.observation.controller_ownership.recovery_controller_id = Some(id.to_owned());
    for (joint, position) in collection.observation.state.ordered_joint_observations.iter_mut().zip(ENTRY) {
        joint.position_rad = Some(position);
    }
    RecoveryControlRequestV1 { schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: id.to_owned(), phase_step: 0, collection }
}

#[test]
fn v11_preserves_v9_final_poses_caps_timeouts_and_claim_limits() {
    let mut expected = recovery_development_profile_v9();
    let actual = recovery_development_profile_v11();
    expected.profile_id = actual.profile_id.clone();
    expected.controller_id = actual.controller_id.clone();
    expected.establish_distal_support_pose.pose_id = actual.establish_distal_support_pose.pose_id.clone();
    assert_eq!(expected, actual);
    assert!(!actual.physical_execution_authorized);
    assert!(!actual.physical_acceptance_authority);
    assert!(!actual.release_authority);
}

#[test]
fn v11_retained_entry_catches_up_rear_left_without_extending_front_knees_to_final_pose() {
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let result = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V11_ID)).unwrap();
        assert_eq!(RecoverySupportStatusV1::SupportedExact, result.support_status);
        assert_eq!(8, result.ordered_commands.len());
        for i in (0..8).step_by(2) {
            assert_eq!(project_binary64_to_guarded_canonical_number_v1(ENTRY[i]).unwrap(), result.ordered_commands[i].target_position_rad);
        }
        // Most extended front-left is held; the less extended legs catch up.
        assert_eq!(project_binary64_to_guarded_canonical_number_v1(ENTRY[1]).unwrap(), result.ordered_commands[1].target_position_rad);
        assert!(result.ordered_commands[5].target_position_rad > ENTRY[5]);
        assert!(result.ordered_commands[3].target_position_rad - ENTRY[3] < 0.001);
        assert!(result.ordered_commands[7].target_position_rad - ENTRY[7] < 0.001);
        for (i, command) in result.ordered_commands.iter().enumerate() {
            assert!((command.target_position_rad - ENTRY[i]).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-10);
            assert_eq!(4.0, command.maximum_target_speed_rad_s);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &result.ordered_commands); }
        else { reference = Some(result.ordered_commands); }
        assert_eq!(0, result.engine_identity_input_count);
        assert_eq!(0, result.world_build_count);
    }
}

#[test]
fn v11_requested_knee_motion_reduces_ideal_foot_height_spread() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V11_ID);
    let upper = 0.35 * input.collection.descriptor.upper_length_fraction;
    let distal = 0.35 - upper;
    let goals = recovery_development_profile_v11().establish_distal_support_pose.ordered_target_positions_rad;
    let output = matched_foot_reach_reference(&goals, &input.collection.observation.state.ordered_joint_observations, 4.0, &input.collection.descriptor).unwrap();
    let y = |p: &[f64], i: usize| -upper * p[i].cos() - distal * (p[i] + p[i+1]).cos();
    assert!(y(&output, 4) < y(&ENTRY, 4));
    assert!((y(&output, 0) - y(&ENTRY, 0)).abs() < 1e-14);
    assert!(y(&output, 4) - y(&output, 0) < y(&ENTRY, 4) - y(&ENTRY, 0));
}

#[test]
fn v11_matched_reach_progresses_and_a_new_lag_is_rechecked() {
    let goals = recovery_development_profile_v11().establish_distal_support_pose.ordered_target_positions_rad;
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V11_ID);
    for i in 0..8 { input.collection.observation.state.ordered_joint_observations[i].position_rad = Some(if i%2==0 {-1.46} else {-0.10}); }
    let observations = &input.collection.observation.state.ordered_joint_observations;
    assert_eq!(coordinated_support_reference(&goals, observations, 4.0).unwrap(),
        matched_foot_reach_reference(&goals, observations, 4.0, &input.collection.descriptor).unwrap());
    for knee in [1, 3, 5, 7] {
        let mut drifted = observations.clone();
        drifted[knee].position_rad = Some(-0.80);
        let result = matched_foot_reach_reference(&goals, &drifted, 4.0, &input.collection.descriptor).unwrap();
        for hip in [0, 2, 4, 6] { assert_eq!(-1.46, result[hip]); }
        assert!(result[knee] > -0.80);
    }
}

#[test]
fn v11_outside_monotone_branch_and_exact_destination_use_v9_coordination() {
    let goals = recovery_development_profile_v11().establish_distal_support_pose.ordered_target_positions_rad;
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V11_ID);
    for exact in [false, true] {
        if exact {
            for (joint, target) in input.collection.observation.state.ordered_joint_observations.iter_mut().zip(&goals) { joint.position_rad = Some(*target); }
        } else { input.collection.observation.state.ordered_joint_observations[0].position_rad = Some(0.2); }
        let observations = &input.collection.observation.state.ordered_joint_observations;
        assert_eq!(coordinated_support_reference(&goals, observations, 4.0).unwrap(),
            matched_foot_reach_reference(&goals, observations, 4.0, &input.collection.descriptor).unwrap());
    }
}

#[test]
fn v11_missing_invalid_or_crossed_sources_refuse_before_commands() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V11_ID);
    for case in 0..4 {
        let mut bad = input.clone();
        match case {
            0 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            1 => bad.collection.observation.state.ordered_joint_observations[1].validity.position = false,
            2 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
            _ => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V10_ID.to_owned()),
        }
        let result = plan_recovery_control_v1(bad).unwrap();
        assert!(result.no_actuation_requested);
        assert!(result.ordered_commands.is_empty());
    }
}

#[test]
fn v11_preserves_all_other_v9_phase_commands() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V9_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V11_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
    }
}

#[test]
fn v11_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V11_ID);
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
