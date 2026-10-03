//! Synthetic command checks, including the actual V11 support-entry angles.
//! Iterating requested positions below is ideal tracking math, NOT physics.
use super::*;

const SUPPORT_ENTRY: [f64; 8] = [-1.4525072574615479, -0.0974312275648117,
    -1.4607325792312622, -0.09484612941741943, -1.4609103202819824,
    -0.8731687068939209, -1.4607722759246826, -0.08408135920763016];
// Original V11 report cd8316b1... at global step 410, before the first raise command.
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
fn v12_preserves_v11_poses_caps_phase_clock_and_claim_limits() {
    let mut expected = recovery_development_profile_v11();
    let actual = recovery_development_profile_v12();
    expected.profile_id = actual.profile_id.clone();
    expected.controller_id = actual.controller_id.clone();
    expected.stance_pose.pose_id = actual.stance_pose.pose_id.clone();
    assert_eq!(expected, actual);
    assert!(!actual.physical_execution_authorized);
    assert!(!actual.physical_acceptance_authority);
    assert!(!actual.release_authority);
}

#[test]
fn v12_first_raise_command_advances_from_measured_pose_on_all_adapter_inputs() {
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let result = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V12_ID)).unwrap();
        assert_eq!(RecoverySupportStatusV1::SupportedExact, result.support_status);
        assert_eq!(8, result.ordered_commands.len());
        let blend = smoothstep(1.0 / recovery_development_profile_v12().raise_body_ramp_steps as f64);
        for (i, command) in result.ordered_commands.iter().enumerate() {
            let expected = RISE_ENTRY[i] + (0.0 - RISE_ENTRY[i]) * blend;
            assert_eq!(project_binary64_to_guarded_canonical_number_v1(expected).unwrap(), command.target_position_rad);
            assert_eq!(4.0, command.maximum_target_speed_rad_s);
            // Command-only observation, not a new physical speed threshold.
            assert!((command.target_position_rad - RISE_ENTRY[i]).abs() / RECOVERY_OUTER_STEP_DURATION_S < 0.005);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &result.ordered_commands); }
        else { reference = Some(result.ordered_commands); }
        assert_eq!(0, result.engine_identity_input_count);
        assert_eq!(0, result.world_build_count);
    }
}

#[test]
fn v12_ideal_tracking_is_the_existing_smooth_clock_from_actual_entry_to_zero() {
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V12_ID);
    let profile = recovery_development_profile_v12();
    let joints = &mut input.collection.observation.state.ordered_joint_observations;
    for step in 0..profile.raise_body_ramp_steps {
        let targets = measured_pose_rise_reference(&[0.0; 8], joints, 4.0, step, profile.raise_body_ramp_steps).unwrap();
        let remaining = 1.0 - smoothstep((step as f64 + 1.0) / profile.raise_body_ramp_steps as f64);
        for i in 0..8 {
            assert!((targets[i] - RISE_ENTRY[i] * remaining).abs() < 1e-12);
            assert!(targets[i].abs() <= joints[i].position_rad.unwrap().abs());
            joints[i].position_rad = Some(targets[i]);
        }
    }
    assert!(joints.iter().all(|j| j.position_rad == Some(0.0)));
}

#[test]
fn v12_late_tracking_error_and_exhausted_clock_keep_existing_step_cap() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V12_ID);
    let joints = &input.collection.observation.state.ordered_joint_observations;
    for step in [359, 360, 900, u32::MAX] {
        let targets = measured_pose_rise_reference(&[0.0; 8], joints, 4.0, step, 360).unwrap();
        for i in 0..8 {
            assert!(targets[i].is_finite());
            assert!((targets[i] - RISE_ENTRY[i]).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
        }
    }
    assert!(measured_pose_rise_reference(&[0.0; 8], joints, 4.0, 0, 0).is_err());
}

#[test]
fn v12_each_current_reading_is_used_without_hidden_entry_pose() {
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V12_ID);
    input.phase_step = 100;
    let original = plan_recovery_control_v1(input.clone()).unwrap();
    input.collection.observation.state.ordered_joint_observations[0].position_rad = Some(-0.5);
    let shifted = plan_recovery_control_v1(input).unwrap();
    assert_ne!(original.ordered_commands[0], shifted.ordered_commands[0]);
    assert_eq!(original.ordered_commands[1..], shifted.ordered_commands[1..]);
}

#[test]
fn v12_invalid_missing_or_crossed_sources_refuse_commands() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V12_ID);
    for case in 0..4 {
        let mut bad = input.clone();
        match case {
            0 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            1 => bad.collection.observation.state.ordered_joint_observations[1].validity.position = false,
            2 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
            _ => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V11_ID.to_owned()),
        }
        let result = plan_recovery_control_v1(bad).unwrap();
        assert!(result.no_actuation_requested);
        assert!(result.ordered_commands.is_empty());
    }
}

#[test]
fn v12_preserves_v11_support_entry_and_all_other_phase_commands() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V11_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V12_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
    }
}

#[test]
fn v12_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V12_ID);
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
