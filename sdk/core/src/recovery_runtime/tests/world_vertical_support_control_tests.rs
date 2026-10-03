//! V22 candidate / controller V18: retained inputs, synthetic command checks.
use super::*;
use super::smooth_stance_control_tests::recovery_request;

fn fixture() -> serde_json::Value {
    serde_json::from_str(include_str!("../../../contracts/recovery_v22_retained_support_fixture_v1.json")).unwrap()
}

fn request(engine: RecoveryNativeEngineV1, phase: RecoveryPhaseV1, index: usize, id: &str) -> RecoveryControlRequestV1 {
    let mut value = recovery_request(engine, phase, id);
    let source = fixture();
    value.phase_step = 0;
    // The retained host descriptor and native fixture have the same canonical
    // identity but can differ by a binary64 ULP after host JSON transport.
    // Bind with the production canonical rule, then use the retained values.
    assert_eq!(digest_serializable(&value.collection.descriptor).unwrap(), digest_json(&source["descriptor"]).unwrap());
    value.collection.descriptor = serde_json::from_value(source["descriptor"].clone()).unwrap();
    value.collection.observation.state.ordered_joint_observations = serde_json::from_value(source["samples"][index]["state"]["ordered_joint_observations"].clone()).unwrap();
    value.collection.observation.state.base_pose_world = serde_json::from_value(source["samples"][index]["state"]["base_pose_world"].clone()).unwrap();
    value
}

fn positions(request: &RecoveryControlRequestV1) -> Vec<f64> {
    request.collection.observation.state.ordered_joint_observations.iter().map(|j| j.position_rad.unwrap()).collect()
}

fn reference(request: &RecoveryControlRequestV1) -> Vec<f64> {
    world_vertical_foot_reach_reference(
        &recovery_development_profile_v18().establish_distal_support_pose.ordered_target_positions_rad,
        &request.collection.observation.state.ordered_joint_observations, 4.0, &request.collection.descriptor,
        request.collection.observation.state.base_pose_world.orientation_xyzw).unwrap()
}

fn heights(request: &RecoveryControlRequestV1, positions: &[f64]) -> Vec<f64> {
    // Independent forward projection of the complete ideal two-link endpoint.
    let g = crate::quadruped::derive_geometry(&request.collection.descriptor);
    let q = request.collection.observation.state.base_pose_world.orientation_xyzw;
    (0..4).map(|leg| {
        let (hip, knee) = (positions[2*leg], positions[2*leg+1]);
        let x = (if leg < 2 { g.front_hip_x_m } else { g.rear_hip_x_m })
            + g.upper_length_m * hip.sin() + g.lower_length_m * (hip + knee).sin();
        let y = -g.upper_length_m * hip.cos() - g.lower_length_m * (hip + knee).cos();
        let z = if leg % 2 == 0 { g.left_hip_z_m } else { g.right_hip_z_m };
        2.0*(q.x*q.y+q.z*q.w)*x + (1.0-2.0*(q.x*q.x+q.z*q.z))*y + 2.0*(q.y*q.z-q.x*q.w)*z
    }).collect()
}

#[test]
fn v18_preserves_profile_limits_and_all_other_phase_commands() {
    let mut old = recovery_development_profile_v17();
    let new = recovery_development_profile_v18();
    old.profile_id = new.profile_id.clone(); old.controller_id = new.controller_id.clone();
    old.establish_distal_support_pose.pose_id = new.establish_distal_support_pose.pose_id.clone();
    assert_eq!(old, new);
    let previous = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V17_ID)).unwrap();
    let next = candidate_stance_profile(stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V18_ID)).unwrap();
    for key in ["response_time_s", "geometry_rule_id", "target_knee_angle_rad", "measured_velocity_damping_gain"] {
        assert_eq!(previous[key], next[key]);
    }
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::ConfirmProne, RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::Failed] {
            for clock in [0, 119, 120, 239, 240, 359, 360] {
                let mut old = request(engine, phase, 0, EXACT_S169_RECOVERY_CONTROLLER_V17_ID);
                let mut new = request(engine, phase, 0, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
                old.phase_step = clock; new.phase_step = clock;
                assert_eq!(plan_recovery_control_v1(old).unwrap().ordered_commands, plan_recovery_control_v1(new).unwrap().ordered_commands);
            }
        }
    }
}

#[test]
fn v18_retained_entry_moves_lagging_world_height_not_lowest_foot() {
    for index in 0..4 {
        let req = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, index, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
        let before = positions(&req);
        let after = reference(&req);
        let old = heights(&req, &before); let new = heights(&req, &after);
        let spread = |values: &[f64]| values.iter().copied().fold(f64::NEG_INFINITY, f64::max)
            - values.iter().copied().fold(f64::INFINITY, f64::min);
        assert!(spread(&new) < spread(&old), "retained fixture {index}");
        for hip in [0,2,4,6] { assert_eq!(before[hip], after[hip]); }
        // The lowest current foot is FL in these retained observations. It
        // must not be pushed farther down just to level feet with the torso.
        if index < 3 {
            assert!((old[0]-new[0]).abs() < 1e-13);
        } else {
            // At retained step 450 the original lowest plane is beyond the
            // rear legs' existing knee destination. The common reachable
            // plane is higher: allow retraction, never additional down-push.
            assert!(new[0] > old[0]);
        }
        for (target, position) in after.iter().zip(before) {
            assert!((target-position).abs() <= 4.0*RECOVERY_OUTER_STEP_DURATION_S + 1e-14);
        }
    }
}

#[test]
fn v18_level_and_yaw_only_inputs_keep_exact_old_reference() {
    let mut req = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, 0, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
    let goals = recovery_development_profile_v17().establish_distal_support_pose.ordered_target_positions_rad;
    for angle in [0.0_f64, 0.6, -1.3] {
        req.collection.observation.state.base_pose_world.orientation_xyzw = Quaternion { x:0.0,y:(angle/2.0).sin(),z:0.0,w:(angle/2.0).cos() };
        assert_eq!(reference(&req), matched_foot_reach_reference(&goals,
            &req.collection.observation.state.ordered_joint_observations,4.0,&req.collection.descriptor).unwrap());
    }
}

#[test]
fn v18_orientation_sign_and_translation_do_not_change_relative_height_rule() {
    let req = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, 0, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
    let expected = plan_recovery_control_v1(req.clone()).unwrap().ordered_commands;
    let mut shifted = req;
    let pose = &mut shifted.collection.observation.state.base_pose_world;
    pose.position_m.x += 5.0; pose.position_m.y += 2.0; pose.position_m.z -= 3.0;
    let q = pose.orientation_xyzw;
    pose.orientation_xyzw = Quaternion{x:-q.x,y:-q.y,z:-q.z,w:-q.w};
    assert_eq!(expected, plan_recovery_control_v1(shifted).unwrap().ordered_commands);
}

#[test]
fn v18_invalid_inputs_refuse_and_nonmonotone_geometry_keeps_bounded_fallback() {
    let req = request(RecoveryNativeEngineV1::GodotJolt4_7, RecoveryPhaseV1::EstablishDistalSupport, 0, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
    let goals = recovery_development_profile_v18().establish_distal_support_pose.ordered_target_positions_rad;
    for mode in 0..5 {
        let mut bad = req.clone();
        match mode {
            0 => bad.collection.observation.state.base_pose_world.orientation_xyzw.w = f64::NAN,
            1 => bad.collection.observation.state.base_pose_world.orientation_xyzw.w = 2.0,
            2 => bad.collection.observation.state.ordered_joint_observations[0].position_rad = None,
            3 => bad.collection.observation.state.ordered_joint_observations.swap(0, 1),
            _ => bad.collection.descriptor.upper_length_fraction = 0.0,
        }
        assert!(world_vertical_foot_reach_reference(&goals, &bad.collection.observation.state.ordered_joint_observations,
            4.0,&bad.collection.descriptor,bad.collection.observation.state.base_pose_world.orientation_xyzw).is_err());
    }
    for q in [Quaternion{x:0.5,y:0.5,z:-0.5,w:0.5}, Quaternion{x:1.0,y:0.0,z:0.0,w:0.0}] {
        let mut side = req.clone(); side.collection.observation.state.base_pose_world.orientation_xyzw = q;
        assert_eq!(reference(&side), coordinated_support_reference(&goals, &side.collection.observation.state.ordered_joint_observations,4.0).unwrap());
    }
    let mut crossed = req;
    crossed.collection.observation.controller_ownership.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V17_ID.to_owned());
    assert!(plan_recovery_control_v1(crossed).unwrap().ordered_commands.is_empty());
}

fn stance_request(phase: RecoveryPhaseV1, positions: [f64;8], velocities: [f64;8]) -> RecoveryStanceControlRequestV4 {
    let mut req = super::damped_stance_control_tests::request(phase, positions, velocities);
    req.controller_id = stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V18_ID).to_owned();
    let owner = &mut req.collection.observation.controller_ownership;
    if phase == RecoveryPhaseV1::RaiseBody {
        owner.recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V18_ID.to_owned());
    } else { owner.stance_controller_id = Some(req.controller_id.clone()); }
    super::damped_stance_control_tests::rebind(&mut req);
    req
}

#[test]
fn v18_selected_stance_commands_preserve_v17_exactly() {
    for phase in [RecoveryPhaseV1::RaiseBody, RecoveryPhaseV1::StanceDwell] {
        for velocity in [-2.0,0.0,2.0] {
            let old = super::damped_stance_control_tests::request(phase,[0.12;8],[velocity;8]);
            let new = stance_request(phase,[0.12;8],[velocity;8]);
            assert_eq!(plan_recovery_stance_control_v4(old).unwrap().control_receipt.ordered_commands,
                plan_recovery_stance_control_v4(new).unwrap().control_receipt.ordered_commands);
        }
    }
}

#[test]
fn v18_public_json_buffer_and_exported_native_shaped_fixtures() {
    use crate::ffi::{SS_BUFFER_TOO_SMALL, SS_OK, ss_recovery_plan_control_v1_json};
    let mut support_commands = Vec::new();
    for engine in [RecoveryNativeEngineV1::GodotJolt4_7, RecoveryNativeEngineV1::RapierParryNative, RecoveryNativeEngineV1::MujocoNative] {
        for phase in [RecoveryPhaseV1::EstablishDistalSupport, RecoveryPhaseV1::RaiseBody] {
            let request = request(engine, phase, 0, EXACT_S169_RECOVERY_CONTROLLER_V18_ID);
            let expected = plan_recovery_control_v1(request.clone()).unwrap();
            assert_eq!(8, expected.ordered_commands.len());
            assert_eq!((0,0), (expected.world_build_count,expected.solver_step_count));
            assert!(!expected.physical_acceptance_authority && !expected.release_authority);
            if phase == RecoveryPhaseV1::EstablishDistalSupport { support_commands.push(expected.ordered_commands.clone()); }
            let input = serde_json::to_vec(&request).unwrap(); let mut required = 0;
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(),input.len(),std::ptr::null_mut(),0,&mut required) },SS_BUFFER_TOO_SMALL);
            let mut output = vec![0u8;required];
            assert_eq!(unsafe { ss_recovery_plan_control_v1_json(input.as_ptr(),input.len(),output.as_mut_ptr(),output.len(),&mut required) },SS_OK);
            let actual: serde_json::Value = serde_json::from_slice(&output[..required]).unwrap();
            assert_eq!(actual["value"],serde_json::to_value(&expected).unwrap());
            println!("CANDIDATE_RECOVERY_CONTROL_FIXTURE {}",json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"retained_pose_values_injected":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
    assert_eq!(support_commands[0],support_commands[1]); assert_eq!(support_commands[0],support_commands[2]);
    for phase in [RecoveryPhaseV1::RaiseBody,RecoveryPhaseV1::StanceDwell] {
        for (positions,velocities) in [([0.0;8],[0.2;8]),([0.005;8],[-0.2;8]),([0.12,-0.25,0.12,-0.25,0.12,-0.25,0.12,-0.25],[2.0,-2.0,2.0,-2.0,2.0,-2.0,2.0,-2.0])] {
            let request = stance_request(phase,positions,velocities);
            let expected = plan_recovery_stance_control_v4(request.clone()).unwrap();
            println!("CANDIDATE_STANCE_CONTROL_FIXTURE {}",json!({"request":request,"expected":expected,
                "synthetic_native_shaped_observations_only":true,"world_build_count":0,"solver_step_count":0}));
        }
    }
}
