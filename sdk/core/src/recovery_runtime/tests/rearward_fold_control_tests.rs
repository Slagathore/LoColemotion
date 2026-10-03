//! Real portable planning calls with supplied native-shaped observations.
//! No engine, model, native read, or solver step is executed by these tests.
use super::*;

const TARGETS: [f64; 8] = [-0.6, 1.05, -0.6, 1.05, -0.6, 1.05, -0.6, 1.05];

#[test]
fn v8_changes_only_identities_and_two_target_speed_ceilings() {
    let old = recovery_development_profile_v7();
    let candidate = recovery_development_profile_v8();
    let mut expected = old.clone();
    expected.profile_id = candidate.profile_id.clone();
    expected.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned();
    expected.establish_distal_support_pose.pose_id =
        "exact_s169_rate_limited_rearward_fold_support_pose_v1".to_owned();
    expected.stance_pose.pose_id = "exact_s169_rate_limited_zero_joint_stance_pose_v1".to_owned();
    expected.establish_distal_support_pose.maximum_target_speed_rad_s = 4.0;
    expected.stance_pose.maximum_target_speed_rad_s = 4.0;
    assert_eq!(candidate, expected);
    assert_eq!(old, recovery_development_profile_v7());
    assert_eq!(old.establish_distal_support_pose.maximum_target_speed_rad_s, 8.0);
    assert_eq!(old.stance_pose.maximum_target_speed_rad_s, 22.0);
    assert!(!candidate.physical_execution_authorized);
    assert!(!candidate.physical_acceptance_authority);
    assert!(!candidate.release_authority);
}

#[test]
fn v8_portable_commands_preserve_targets_caps_ramp_and_terminal_behavior() {
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7,
                   RecoveryNativeEngineV1::RapierParryNative,
                   RecoveryNativeEngineV1::MujocoNative] {
        for (phase, step) in [(RecoveryPhaseV1::ConfirmProne, 0),
            (RecoveryPhaseV1::EstablishDistalSupport, 0),
            (RecoveryPhaseV1::RaiseBody, 0), (RecoveryPhaseV1::RaiseBody, 180),
            (RecoveryPhaseV1::RaiseBody, 360), (RecoveryPhaseV1::StanceHandoff, 0),
            (RecoveryPhaseV1::StanceDwell, 0), (RecoveryPhaseV1::Complete, 0),
            (RecoveryPhaseV1::Failed, 0), (RecoveryPhaseV1::Refused, 0)] {
            for arm in [RecoveryArmKindV1::CandidateCommand, RecoveryArmKindV1::MatchedZeroCommand] {
                let old = planned(engine, arm, phase, step, EXACT_S169_RECOVERY_CONTROLLER_V7_ID);
                let new = planned(engine, arm, phase, step, EXACT_S169_RECOVERY_CONTROLLER_V8_ID);
                assert_eq!(old.support_status, new.support_status);
                assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
                assert_eq!(old.owner, new.owner);
                let mut expected = old.ordered_commands;
                for command in &mut expected {
                    command.maximum_target_speed_rad_s = 4.0;
                }
                assert_eq!(new.ordered_commands, expected);
                assert_eq!(new.engine_identity_input_count, 0);
                assert_eq!(new.world_build_count, 0);
                assert_eq!(new.solver_step_count, 0);
            }
        }
    }
}

#[test]
fn v8_refuses_v6_v7_and_unknown_ownership() {
    for owner in [EXACT_S169_RECOVERY_CONTROLLER_V6_ID, EXACT_S169_RECOVERY_CONTROLLER_V7_ID, "unknown"] {
        let mut collection = native_request(RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand, RecoveryPhaseV1::EstablishDistalSupport);
        collection.observation.controller_ownership.recovery_controller_id = Some(owner.to_owned());
        let result = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned(), phase_step: 0, collection,
        }).unwrap();
        assert!(result.no_actuation_requested);
        assert!(result.ordered_commands.is_empty());
        assert_ne!(result.support_status, RecoverySupportStatusV1::SupportedExact);
    }
}

#[test]
fn v8_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7,
                   RecoveryNativeEngineV1::RapierParryNative,
                   RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
            collection.observation.controller_ownership.recovery_controller_id =
                Some(EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned());
            let request = RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned(), phase_step: 0, collection,
            };
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            let input = serde_json::to_vec(&request).unwrap();
            let mut required = 0;
            let sizing = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(),
                std::ptr::null_mut(), 0, &mut required) };
            assert_eq!(sizing, SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8; required];
            let status = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(),
                output.as_mut_ptr(), output.len(), &mut required) };
            assert_eq!(status, SS_OK);
            let response: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(response["value"], serde_json::to_value(&expected).unwrap());
            println!("RATE_LIMITED_RECOVERY_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
                "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
        }
    }
}

fn planned(
    engine: RecoveryNativeEngineV1,
    arm: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    phase_step: u32,
    controller: &str,
) -> RecoveryControlReceiptV1 {
    let mut collection = native_request(engine, arm, phase);
    if arm == RecoveryArmKindV1::CandidateCommand {
        collection.observation.controller_ownership.recovery_controller_id =
            Some(controller.to_owned());
    }
    plan_recovery_control_v1(RecoveryControlRequestV1 {
        schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: controller.to_owned(),
        phase_step,
        collection,
    })
    .unwrap()
}

#[test]
fn v7_changes_only_declared_identity_and_four_front_targets() {
    let old = recovery_development_profile_v6();
    assert_eq!(digest_serializable(&old).unwrap(),
        "sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33");
    let candidate = recovery_development_profile_v7();
    let mut expected = old.clone();
    expected.profile_id = candidate.profile_id.clone();
    expected.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V7_ID.to_owned();
    expected.establish_distal_support_pose.pose_id =
        "exact_s169_rearward_fold_distal_support_pose_v1".to_owned();
    expected.establish_distal_support_pose.ordered_target_positions_rad = TARGETS.to_vec();
    assert_eq!(candidate, expected);
    assert_eq!(old, recovery_development_profile_v6());
    assert!(!candidate.physical_execution_authorized);
    assert!(!candidate.physical_acceptance_authority);
    assert!(!candidate.release_authority);
}

#[test]
fn v7_actual_support_commands_are_identical_across_three_native_adapters() {
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7,
                   RecoveryNativeEngineV1::RapierParryNative,
                   RecoveryNativeEngineV1::MujocoNative] {
        let receipt = planned(engine, RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport, 0, EXACT_S169_RECOVERY_CONTROLLER_V7_ID);
        assert_eq!(receipt.support_status, RecoverySupportStatusV1::SupportedExact);
        assert_eq!(receipt.ordered_commands.iter().map(|c| c.target_position_rad).collect::<Vec<_>>(), TARGETS);
        assert_eq!(receipt.engine_identity_input_count, 0);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.prone_to_standing_claimed);
        if let Some(commands) = &reference {
            assert_eq!(&receipt.ordered_commands, commands);
        } else {
            reference = Some(receipt.ordered_commands);
        }
    }
}

#[test]
fn v7_preserves_caps_speed_and_interpolates_its_own_support_pose_to_stance() {
    for (phase, phase_step) in [(RecoveryPhaseV1::EstablishDistalSupport, 0),
        (RecoveryPhaseV1::RaiseBody, 0), (RecoveryPhaseV1::RaiseBody, 180),
        (RecoveryPhaseV1::RaiseBody, 360)] {
        let old = planned(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryArmKindV1::CandidateCommand,
            phase, phase_step, EXACT_S169_RECOVERY_CONTROLLER_V6_ID);
        let new = planned(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryArmKindV1::CandidateCommand,
            phase, phase_step, EXACT_S169_RECOVERY_CONTROLLER_V7_ID);
        assert_eq!(new.support_status, RecoverySupportStatusV1::SupportedExact);
        let mut expected = old.ordered_commands;
        for command in &mut expected[..4] {
            // JSON transport canonicalizes zero: do not introduce a -0 target.
            command.target_position_rad = if command.target_position_rad == 0.0 { 0.0 }
                else { -command.target_position_rad };
        }
        assert_eq!(new.ordered_commands, expected);
        assert_eq!(new.command_sha256, Some(digest_serializable(&new.ordered_commands).unwrap()));
    }
}

#[test]
fn v7_preserves_no_actuation_and_refuses_crossed_controller_ownership() {
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7,
                   RecoveryNativeEngineV1::RapierParryNative,
                   RecoveryNativeEngineV1::MujocoNative] {
        let zero = planned(engine, RecoveryArmKindV1::MatchedZeroCommand,
            RecoveryPhaseV1::EstablishDistalSupport, 0, EXACT_S169_RECOVERY_CONTROLLER_V7_ID);
        assert_eq!(zero.support_status, RecoverySupportStatusV1::SupportedExact);
        assert!(zero.no_actuation_requested);
        assert!(zero.ordered_commands.is_empty());
        assert_eq!(zero.command_sha256, None);
        let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport);
        collection.observation.controller_ownership.recovery_controller_id =
            Some(EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned());
        let refused = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V7_ID.to_owned(), phase_step: 0, collection,
        }).unwrap();
        assert_eq!(refused.refusal_reason.as_deref(), Some("recovery_controller_ownership_mismatch"));
        assert!(refused.no_actuation_requested);
        assert!(refused.ordered_commands.is_empty());
    }
}

#[test]
fn v7_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7,
                   RecoveryNativeEngineV1::RapierParryNative,
                   RecoveryNativeEngineV1::MujocoNative] {
        let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport);
        collection.observation.controller_ownership.recovery_controller_id =
            Some(EXACT_S169_RECOVERY_CONTROLLER_V7_ID.to_owned());
        let request = RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V7_ID.to_owned(), phase_step: 0, collection,
        };
        let expected = plan_recovery_control_v1(request.clone()).unwrap();
        let input = serde_json::to_vec(&request).unwrap();
        let mut required = 0;
        let sizing = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(),
            std::ptr::null_mut(), 0, &mut required) };
        assert_eq!(sizing, SS_BUFFER_TOO_SMALL);
        let mut output = vec![0u8; required];
        let status = unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(), input.len(),
            output.as_mut_ptr(), output.len(), &mut required) };
        assert_eq!(status, SS_OK);
        let response: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
        assert_eq!(response["value"], serde_json::to_value(&expected).unwrap());
        // A separate Python process uses this unchanged request against the
        // built adapter DLL, not only the Rust unit-test executable.
        println!("REARWARD_FOLD_CONTROL_FIXTURE {}", json!({"request": request, "expected": expected,
            "synthetic_native_shaped_observations_only": true, "world_build_count": 0, "solver_step_count": 0}));
    }
}
