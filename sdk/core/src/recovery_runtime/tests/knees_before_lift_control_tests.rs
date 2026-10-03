//! Command-only checks of knee preparation, never a simulated recovery result.
//! These retained entry angles also appear in V8/V9 step 386. Their use here
//! does not turn a synthetic native-shaped request into a new physical trace.
use super::*;

const ENTRY: [f64; 8] = [
    -1.4525072574615479, -0.0974312275648117,
    -1.4607325792312622, -0.09484612941741943,
    -1.4609103202819824, -0.8731687068939209,
    -1.4607722759246826, -0.08408135920763016,
];

fn request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
    collection.observation.controller_ownership.recovery_controller_id = Some(id.to_owned());
    for (joint, position) in collection.observation.state.ordered_joint_observations.iter_mut().zip(ENTRY) {
        joint.position_rad = Some(position);
    }
    RecoveryControlRequestV1 {
        schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: id.to_owned(), phase_step: 0, collection,
    }
}

#[test]
fn v10_keeps_v9_destinations_caps_timeouts_and_claim_limits() {
    let mut expected = recovery_development_profile_v9();
    let actual = recovery_development_profile_v10();
    expected.profile_id = actual.profile_id.clone();
    expected.controller_id = actual.controller_id.clone();
    expected.establish_distal_support_pose.pose_id = actual.establish_distal_support_pose.pose_id.clone();
    assert_eq!(expected, actual);
    assert!(!actual.physical_execution_authorized);
    assert!(!actual.physical_acceptance_authority);
    assert!(!actual.release_authority);
}

#[test]
fn v10_prepares_knees_without_requesting_hip_motion_on_all_three_adapter_inputs() {
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let result = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V10_ID)).unwrap();
        assert_eq!(result.support_status, RecoverySupportStatusV1::SupportedExact);
        assert_eq!(8, result.ordered_commands.len());
        for (index, command) in result.ordered_commands.iter().enumerate() {
            let increment = command.target_position_rad - ENTRY[index];
            if index % 2 == 0 {
                assert_eq!(project_binary64_to_guarded_canonical_number_v1(ENTRY[index]).unwrap(), command.target_position_rad);
            }
            else { assert!(increment > 0.0); }
            assert!(increment.abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-10);
            assert_eq!(4.0, command.maximum_target_speed_rad_s);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &result.ordered_commands); }
        else { reference = Some(result.ordered_commands); }
        assert_eq!(0, result.engine_identity_input_count);
        assert_eq!(0, result.world_build_count);
        assert_eq!(0, result.solver_step_count);
    }
}

#[test]
fn v10_all_four_knees_must_be_within_one_existing_motor_step_before_hip_progress() {
    let goals = recovery_development_profile_v9().establish_distal_support_pose.ordered_target_positions_rad;
    let limit = 4.0 * RECOVERY_OUTER_STEP_DURATION_S;
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V10_ID);
    for index in (1..8).step_by(2) {
        input.collection.observation.state.ordered_joint_observations[index].position_rad = Some(goals[index] - limit * 0.5);
    }
    let result = plan_recovery_control_v1(input.clone()).unwrap();
    for index in (0..8).step_by(2) {
        assert!(result.ordered_commands[index].target_position_rad > ENTRY[index]);
    }
    for knee in (1..8).step_by(2) {
        let mut drifted = input.clone();
        drifted.collection.observation.state.ordered_joint_observations[knee].position_rad = Some(goals[knee] - limit * 2.0);
        let result = plan_recovery_control_v1(drifted).unwrap();
        for hip in (0..8).step_by(2) {
            assert_eq!(project_binary64_to_guarded_canonical_number_v1(ENTRY[hip]).unwrap(), result.ordered_commands[hip].target_position_rad);
        }
    }
}

#[test]
fn v10_exact_destination_is_finite_and_missing_invalid_or_crossed_sources_refuse() {
    let goals = recovery_development_profile_v9().establish_distal_support_pose.ordered_target_positions_rad;
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V10_ID);
    for (joint, goal) in input.collection.observation.state.ordered_joint_observations.iter_mut().zip(&goals) {
        joint.position_rad = Some(*goal);
    }
    let result = plan_recovery_control_v1(input.clone()).unwrap();
    assert_eq!(goals, result.ordered_commands.iter().map(|c| c.target_position_rad).collect::<Vec<_>>());
    for case in 0..4 {
        let mut bad = input.clone();
        match case {
            0 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            1 => bad.collection.observation.state.ordered_joint_observations[1].validity.position = false,
            2 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
            _ => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V9_ID.to_owned()),
        }
        let result = plan_recovery_control_v1(bad).unwrap();
        assert!(result.no_actuation_requested);
        assert!(result.ordered_commands.is_empty());
    }
}

#[test]
fn v10_preserves_all_other_v9_phase_commands() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V9_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V10_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
        assert_eq!(old.owner, new.owner);
    }
}

#[test]
fn v10_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V10_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            let input = serde_json::to_vec(&request).unwrap();
            let mut required = 0;
            let sizing = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut required) };
            assert_eq!(sizing, SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8; required];
            let status = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), output.as_mut_ptr(), output.len(), &mut required) };
            assert_eq!(status, SS_OK);
            let actual: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(actual["value"], serde_json::to_value(&expected).unwrap());
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "retained_joint_angles_injected": true,
                "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
