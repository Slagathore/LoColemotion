//! V14 command and ideal-geometry checks, not a physics simulation.
use super::*;

const SUPPORT_ENTRY: [f64; 8] = [-1.4525072574615479, -0.0974312275648117,
    -1.4607325792312622, -0.09484612941741943, -1.4609103202819824,
    -0.8731687068939209, -1.4607722759246826, -0.08408135920763016];
// Original V13 report b660daf2..., step 410 before the raising controller acts.
const RISE_ENTRY: [f64; 8] = [-1.4540300369262695, -0.08694559335708618,
    -1.4813200235366821, -0.03961467370390892, -1.4592338800430298,
    -0.08806305378675461, -1.4627629518508911, -0.0546673983335495];

fn request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, id: &str) -> RecoveryControlRequestV1 {
    let mut collection = native_request(engine, RecoveryArmKindV1::CandidateCommand, phase);
    collection.observation.controller_ownership.recovery_controller_id = Some(id.to_owned());
    for (joint, position) in collection.observation.state.ordered_joint_observations.iter_mut()
        .zip(if phase == RecoveryPhaseV1::RaiseBody { RISE_ENTRY } else { SUPPORT_ENTRY }) {
        joint.position_rad = Some(position);
    }
    RecoveryControlRequestV1 { schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
        controller_id: id.to_owned(), phase_step: 0, collection }
}

#[test]
fn v14_preserves_v13_profile_gates_caps_and_total_clock() {
    let mut expected = recovery_development_profile_v13();
    let actual = recovery_development_profile_v14();
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
fn v14_first_command_folds_knees_up_without_intended_hip_progress_on_all_adapter_inputs() {
    let mut reference = None;
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        let output = plan_recovery_control_v1(request(engine, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID)).unwrap();
        assert_eq!(RecoverySupportStatusV1::SupportedExact, output.support_status);
        assert_eq!(8, output.ordered_commands.len());
        for (i, command) in output.ordered_commands.iter().enumerate() {
            let expected = if i % 2 == 0 { RISE_ENTRY[i] }
                else { RISE_ENTRY[i] + (-1.05 - RISE_ENTRY[i]) * smoothstep(1.0 / 120.0) };
            assert_eq!(project_binary64_to_guarded_canonical_number_v1(expected).unwrap(), command.target_position_rad);
            if i % 2 == 1 { assert!(command.target_position_rad < RISE_ENTRY[i]); }
            assert_eq!(4.0, command.maximum_target_speed_rad_s);
        }
        if let Some(commands) = &reference { assert_eq!(commands, &output.ordered_commands); }
        else { reference = Some(output.ordered_commands); }
        assert_eq!(0, output.engine_identity_input_count);
        assert_eq!(0, output.world_build_count);
    }
}

#[test]
fn v14_fixed_torso_ideal_fold_raises_endpoints_where_opposite_knee_fold_lowers_them() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
    let upper = 0.35 * input.collection.descriptor.upper_length_fraction;
    let distal = 0.35 - upper;
    for i in (0..8).step_by(2) {
        let hip = RISE_ENTRY[i];
        let knee = RISE_ENTRY[i+1];
        let height = |k: f64| -upper * hip.cos() - distal * (hip+k).cos();
        let start = height(knee);
        let mut previous = start;
        for step in 1..=120 {
            let k = knee + (-1.05-knee) * smoothstep(step as f64 / 120.0);
            assert!((-std::f64::consts::PI..=0.0).contains(&(hip+k)));
            assert!(height(k) >= previous - 1e-14);
            previous = height(k);
        }
        assert!(height(-1.05) > start);
        assert!(height(1.05) < start);
    }
}

#[test]
fn v14_ideal_tracking_visits_fold_replant_and_zero_within_original_clock() {
    let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
    let profile = recovery_development_profile_v14();
    let support = &profile.establish_distal_support_pose.ordered_target_positions_rad;
    let mirrored: Vec<f64> = support.iter().map(|v| -v).collect();
    let folded: Vec<f64> = RISE_ENTRY.iter().enumerate().map(|(i, q)| if i % 2 == 0 { *q } else { -1.05 }).collect();
    let standing = [0.0; 8];
    let joints = &mut input.collection.observation.state.ordered_joint_observations;
    for step in 0..360 {
        let targets = knee_fold_replant_rise_reference(support, &[0.0; 8], joints, 4.0, step, 360).unwrap();
        let (start, end, local_step) = if step < 120 { (RISE_ENTRY.as_slice(), folded.as_slice(), step) }
            else if step < 240 { (folded.as_slice(), mirrored.as_slice(), step-120) }
            else { (mirrored.as_slice(), standing.as_slice(), step-240) };
        for i in 0..8 {
            let expected = start[i] + (end[i]-start[i]) * smoothstep((local_step as f64+1.0)/120.0);
            assert!((targets[i]-expected).abs() < 1e-12);
            assert!((targets[i]-joints[i].position_rad.unwrap()).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
            assert!(targets[i].abs() <= if i % 2 == 0 { 1.6 } else { 1.1 });
            joints[i].position_rad = Some(targets[i]);
        }
        if step == 119 { assert_eq!(folded, targets); }
        if step == 239 { assert_eq!(mirrored, targets); }
    }
    assert!(joints.iter().all(|j| j.position_rad == Some(0.0)));
}

#[test]
fn v14_every_segment_uses_actual_readings_without_assumed_attainment_or_hidden_hips() {
    for step in [60, 120, 240] {
        let mut input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
        input.phase_step = step;
        let old = plan_recovery_control_v1(input.clone()).unwrap();
        input.collection.observation.state.ordered_joint_observations[0].position_rad = Some(-0.2);
        let new = plan_recovery_control_v1(input).unwrap();
        assert_ne!(old.ordered_commands[0], new.ordered_commands[0]);
        assert_eq!(old.ordered_commands[1..], new.ordered_commands[1..]);
        assert!(!new.stance_handoff_requested);
        if step == 60 { assert_eq!(-0.2, new.ordered_commands[0].target_position_rad); }
    }
}

#[test]
fn v14_late_error_odd_and_exhausted_clocks_preserve_command_bounds() {
    let input = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
    let joints = &input.collection.observation.state.ordered_joint_observations;
    let support = recovery_development_profile_v14().establish_distal_support_pose.ordered_target_positions_rad;
    for ramp in [3, 360, 361, 362] {
        for step in [0, 119, 120, 239, 240, 359, 360, 900, u32::MAX] {
            let targets = knee_fold_replant_rise_reference(&support, &[0.0; 8], joints, 4.0, step, ramp).unwrap();
            for i in 0..8 {
                assert!(targets[i].is_finite());
                assert!((targets[i]-RISE_ENTRY[i]).abs() <= 4.0 * RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
            }
        }
    }
    for ramp in 0..3 { assert!(knee_fold_replant_rise_reference(&support, &[0.0; 8], joints, 4.0, 0, ramp).is_err()); }
    assert!(knee_fold_replant_rise_reference(&support[..6], &[0.0; 8], joints, 4.0, 0, 360).is_err());
}

#[test]
fn v14_invalid_missing_or_crossed_sources_refuse_every_segment() {
    for step in [0, 120, 240] {
        for case in 0..4 {
            let mut bad = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::RaiseBody, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
            bad.phase_step = step;
            match case {
                0 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
                1 => bad.collection.observation.state.ordered_joint_observations[1].validity.position = false,
                2 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
                _ => bad.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V13_ID.to_owned()),
            }
            let output = plan_recovery_control_v1(bad).unwrap();
            assert!(output.no_actuation_requested);
            assert!(output.ordered_commands.is_empty());
        }
    }
}

#[test]
fn v14_preserves_v13_support_and_other_phase_commands() {
    for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::StanceHandoff, RecoveryPhaseV1::Failed] {
        let old = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V13_ID)).unwrap();
        let new = plan_recovery_control_v1(request(RecoveryNativeEngineV1::GodotJolt4_7, phase, EXACT_S169_RECOVERY_CONTROLLER_V14_ID)).unwrap();
        assert_eq!(old.ordered_commands, new.ordered_commands);
        assert_eq!(old.no_actuation_requested, new.no_actuation_requested);
    }
}

#[test]
fn v14_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, EXACT_S169_RECOVERY_CONTROLLER_V14_ID);
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
