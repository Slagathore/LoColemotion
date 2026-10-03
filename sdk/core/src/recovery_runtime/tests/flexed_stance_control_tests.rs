//! V16 changes the stance goal, not observations, gates, or recovery motion.
use super::*;
use super::smooth_stance_control_tests::recovery_request;

fn request(phase: RecoveryPhaseV1, positions: [f64; 8]) -> RecoveryStanceControlRequestV4 {
    let mut value = super::smooth_stance_control_tests::stance_request(phase, true, positions);
    value.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V16_ID).to_owned();
    let owner = &mut value.collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        owner.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V16_ID.to_owned());
    } else {
        owner.stance_controller_id = Some(value.controller_id.clone());
    }
    value.portable_step_observation_v3.controller_ownership = owner.clone();
    let source = &value.collection.observation_source_binding;
    value.collection.observation_source_binding = bind_recovery_observation_v2_source_v1(
        &value.collection.observation, &value.collection.observation.engine_step_identity.adapter_id,
        &source.source_route_id, &source.mapping_profile_id, SHA_A, SHA_B).unwrap();
    value.handoff_or_stance_step.observation_sha256 = Some(digest_serializable(&value.portable_step_observation_v3).unwrap());
    value
}

#[test]
fn v16_preserves_v15_get_up_commands_thresholds_and_caps() {
    let mut old = recovery_development_profile_v15();
    let new = recovery_development_profile_v16();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    assert_eq!(old, new);
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            for clock in [0,119,120,150,239,240,359,360] {
                let mut old = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V15_ID);
                let mut new = recovery_request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V16_ID);
                old.phase_step = clock; new.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(old).unwrap().ordered_commands, plan_recovery_control_v1(new).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn v16_ideal_foot_stays_under_hip_and_recovers_vertical_joint_sensitivity() {
    let id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V16_ID);
    let profile = candidate_stance_profile(id).unwrap();
    for fraction in [0.45, 0.5219571428571428, 0.60] {
        let mut descriptor = actual_development_handoff_inputs().0.descriptor;
        descriptor.upper_length_fraction = fraction;
        let goals = candidate_stance_goal_positions(profile, &descriptor).unwrap();
        let (hip, knee) = (goals[0], goals[1]);
        let (upper, lower) = (0.35*fraction, 0.35*(1.0-fraction));
        let x = upper*hip.sin() + lower*(hip+knee).sin();
        let y = -upper*hip.cos() - lower*(hip+knee).cos();
        assert!(x.abs() < 1e-15);
        assert_eq!(-0.25, knee);
        assert!(hip > 0.0 && hip < 0.25);
        assert!(y > -0.35 && y < 0.0);
        let knee_height_derivative = lower*(hip+knee).sin();
        let epsilon = 1e-6;
        let difference = (-lower*(hip+knee+epsilon).cos() + lower*(hip+knee-epsilon).cos()) / (2.0*epsilon);
        assert!((knee_height_derivative-difference).abs() < 1e-10);
        assert!(knee_height_derivative.abs() > 0.0);
        assert_eq!(0.0, lower*0.0_f64.sin()); // Fully straight height derivative.
        for pair in goals.chunks_exact(2) { assert_eq!(pair, &[hip,knee]); }
    }
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        let req = request(phase, [0.0;8]);
        let before = serde_json::to_value(&req).unwrap();
        let result = plan_recovery_stance_control_v4(req.clone()).unwrap();
        let previous = plan_recovery_stance_control_v4(super::smooth_stance_control_tests::stance_request(phase,true,[0.0;8])).unwrap();
        assert_eq!(before, serde_json::to_value(req).unwrap());
        assert_ne!(result.control_receipt.controller_profile_sha256, previous.control_receipt.controller_profile_sha256);
        for (i, (command, old)) in result.control_receipt.ordered_commands.iter().zip(previous.control_receipt.ordered_commands).enumerate() {
            assert_eq!(old.maximum_outer_step_impulse_nms, command.maximum_outer_step_impulse_nms);
            assert_eq!(0.75, command.maximum_target_speed_rad_s);
            assert_eq!(0.0, command.target_velocity_rad_s);
            assert_eq!(if i%2 == 0 {0.00625} else {-0.00625}, command.target_position_rad);
        }
        assert!(!result.release_authority && !result.physical_acceptance_authority);
    }
}

#[test]
fn v16_refuses_crossed_stance_identity_and_invalid_geometry() {
    let base = request(RecoveryPhaseV1::RaiseBody,[0.0;8]);
    for id in [EXACT_S169_STANCE_CONTROLLER_ID, stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V15_ID)] {
        let mut wrong = base.clone(); wrong.controller_id = id.to_owned();
        assert!(plan_recovery_stance_control_v4(wrong).is_err());
    }
    let profile = candidate_stance_profile(&base.controller_id).unwrap();
    for (key,value) in [("geometry_rule_id",json!("unknown")), ("target_knee_angle_rad",json!(0.0)), ("target_knee_angle_rad",json!(-1.11))] {
        let mut bad = profile.clone(); bad[key] = value;
        assert!(candidate_stance_goal_positions(&bad,&base.collection.descriptor).is_err());
    }
    for fraction in [0.0,1.0,f64::NAN] {
        let mut descriptor = base.collection.descriptor.clone(); descriptor.upper_length_fraction = fraction;
        assert!(candidate_stance_goal_positions(profile,&descriptor).is_err());
    }
}

#[test]
fn v16_exported_native_shaped_fixtures() {
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = recovery_request(engine,phase,EXACT_S169_RECOVERY_CONTROLLER_V16_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}", json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for positions in [[0.0;8],[0.005;8],[-0.2;8]] {
            let request = request(phase,positions);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}",json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
}
