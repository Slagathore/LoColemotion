//! Supplied observations only. The eight starting angles are from retained
//! V8 step 386 (report sha256 dd424aa0557e59b6d0bf17a7d7cdd93313c804fae70d045b6d6466a128db5a88).
//! They are injected into explicitly synthetic planning inputs, not promoted
//! into a new native observation, rollout, or force-aware recovery result.
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
fn v9_keeps_v8_destinations_caps_phase_rules_and_claim_limits() {
    let mut expected = recovery_development_profile_v8();
    let actual = recovery_development_profile_v9();
    expected.profile_id = actual.profile_id.clone();
    expected.controller_id = actual.controller_id.clone();
    expected.establish_distal_support_pose.pose_id = actual.establish_distal_support_pose.pose_id.clone();
    assert_eq!(expected, actual);
    assert!(!actual.physical_execution_authorized);
    assert!(!actual.physical_acceptance_authority);
    assert!(!actual.release_authority);
}

#[test]
fn v9_coordinates_retained_joint_errors_with_one_fraction_and_no_larger_step() {
    let goals = recovery_development_profile_v8().establish_distal_support_pose.ordered_target_positions_rad;
    let largest_error = goals.iter().zip(ENTRY).map(|(g, q)| (g - q).abs()).fold(0.0_f64, f64::max);
    let fraction = 4.0 * RECOVERY_OUTER_STEP_DURATION_S / largest_error;
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let actual = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V9_ID)).unwrap();
        assert_eq!(actual.support_status, RecoverySupportStatusV1::SupportedExact);
        assert_eq!(actual.ordered_commands.len(), 8);
        for ((command, goal), position) in actual.ordered_commands.iter().zip(&goals).zip(ENTRY) {
            let increment = command.target_position_rad - position;
            assert!((increment / (goal - position) - fraction).abs() < 1.0e-10);
            assert!(increment.abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1.0e-10);
            assert_eq!(command.maximum_target_speed_rad_s, 4.0);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &actual.ordered_commands); }
        else { reference = Some(actual.ordered_commands); }
        assert_eq!(actual.engine_identity_input_count, 0);
        assert_eq!(actual.world_build_count, 0);
        assert_eq!(actual.solver_step_count, 0);
    }
}

#[test]
fn v9_exact_destination_zero_error_and_near_goal_are_finite() {
    let goals = recovery_development_profile_v8().establish_distal_support_pose.ordered_target_positions_rad;
    for offset in [0.0, 1.0e-8, -1.0e-8] {
        let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V9_ID);
        for (joint, goal) in input.collection.observation.state.ordered_joint_observations.iter_mut().zip(&goals) {
            joint.position_rad = Some(goal + offset);
        }
        let receipt = plan_recovery_control_v1(input).unwrap();
        assert_eq!(receipt.ordered_commands.iter().map(|c| c.target_position_rad).collect::<Vec<_>>(), goals);
    }
}

#[test]
fn v9_preserves_v8_other_phases_and_refuses_missing_or_crossed_sources() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V8_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V9_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
        assert_eq!(old.owner, new.owner);
    }
    for crossed in [false, true] {
        let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, EXACT_S169_RECOVERY_CONTROLLER_V9_ID);
        if crossed { input.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned()); }
        else { input.collection.observation.state.ordered_joint_observations[0].position_rad = None; }
        let result = plan_recovery_control_v1(input).unwrap();
        assert!(result.no_actuation_requested);
        assert!(result.ordered_commands.is_empty());
    }
}

#[test]
fn v9_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let input_request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V9_ID);
            let expected = plan_recovery_control_v1(input_request.clone()).unwrap();
            let input = serde_json::to_vec(&input_request).unwrap();
            let mut required = 0;
            let sizing = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), std::ptr::null_mut(), 0, &mut required) };
            assert_eq!(sizing, SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8; required];
            let status = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(), output.as_mut_ptr(), output.len(), &mut required) };
            assert_eq!(status, SS_OK);
            let response: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(response["value"], serde_json::to_value(&expected).unwrap());
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request": input_request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "retained_joint_angles_injected": true,
                "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}
