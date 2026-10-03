mod recovery_reference_velocity {
    use super::*;
    use crate::controller::{
        BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_PROFILE_VERSION as PROFILE,
        BOUNDED_REFERENCE_VELOCITY_MODE_ID as MODE,
    };
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source = controller();
        let new = BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        let old = BalancedWaveController::new_for_policy(source.compiled().clone(), PARENT).unwrap();
        let floor = FloorReference {
            schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: FRAME_ID.to_owned(), surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_v37_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)), height_world_m: 0.0,
        };
        (source, new, old, floor)
    }

    #[test]
    fn v37_profile_adds_only_identity_and_reference_velocity_mode() {
        let (_, new, old, _) = setup();
        let mut expected = old.profile().clone();
        expected.policy_id = POLICY.to_owned(); expected.schema_version = PROFILE.to_owned();
        expected.reference_velocity_mode_id = Some(MODE.to_owned());
        assert_eq!(&expected, new.profile());
        assert_eq!(new.initial_memory().schema_version, BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION);
        assert!(!serde_json::to_string(old.profile()).unwrap().contains("reference_velocity_mode_id"));
        assert_eq!(crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID, BALANCED_WAVE_BW5R_B_POLICY_ID);
    }

    #[test]
    fn v37_four_hundred_inputs_preserve_all_position_paths_and_reconstruct_rates() {
        let (source, new, old, floor) = setup();
        let mut memory = new.initial_memory(); let mut parent = old.initial_memory();
        for limb in &mut memory.ordered_limb_memory { limb.gait_step = 90; }
        for limb in &mut parent.ordered_limb_memory { limb.gait_step = 90; }
        let mut changed = 0;
        for n in 1..=400 {
            let mut input = state(&source, n);
            input.base_pose_world.position_m.y = 0.37 + 0.02 * (n as f64 / 17.0).sin();
            for (i, c) in input.ordered_contact_observations.iter_mut().enumerate() {
                c.presence = Some((n + i as u64 * 19) % 53 < 31); c.bears_support = c.presence;
            }
            let mut motion = command(n);
            motion.gait_amplitude = (1.1 / (0.82 * 1.75 + 0.40)) * smoothstep((n-1) as f64 / 72.0);
            let out = new.step_with_floor(&memory, &input, &motion, Some(&floor));
            let oldout = old.step_with_floor(&parent, &input, &motion, Some(&floor));
            assert!(!out.actuation.safe_no_actuation, "{:?}", out.actuation.receipt.controller_error);
            assert!(!oldout.actuation.safe_no_actuation);
            let mut expected_memory = oldout.next_memory.clone();
            expected_memory.schema_version = BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION.to_owned();
            assert_eq!(out.next_memory, expected_memory);
            assert_eq!(out.actuation.receipt.schema_version, "sporespore_recovery_reference_velocity_controller_step_receipt_v1");
            let receipt = out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            let rates = receipt.ordered_reference_velocity_rad_s.as_ref().unwrap();
            let mut expected_receipt = oldout.actuation.receipt.recovery_support_plane.clone().unwrap();
            expected_receipt.reference_velocity_mode_id = Some(MODE.to_owned());
            expected_receipt.ordered_reference_velocity_rad_s = Some(rates.clone());
            assert_eq!(*receipt, expected_receipt);
            assert_eq!(rates.len(), 8);
            for (i, (c, before)) in out.actuation.ordered_commands.iter().zip(&oldout.actuation.ordered_commands).enumerate() {
                let previous = memory.support_reference.as_ref().unwrap().ordered_target_positions_rad[i];
                let dt = receipt.reference_step_duration_s; let cap = c.maximum_target_speed_rad_s;
                let rate = if dt > 0.0 { ((c.requested_target_position_rad-previous)/dt).clamp(-cap, cap) } else { 0.0 };
                assert_eq!(rate, rates[i]); assert!(rate.abs() <= cap);
                let joint = &input.ordered_joint_observations[i];
                let raw = MOTOR_POSITION_GAIN_PER_S * (c.requested_target_position_rad-joint.position_rad.unwrap())
                    - MOTOR_RATE_DAMPING * joint.velocity_rad_s.unwrap() + (1.0+MOTOR_RATE_DAMPING)*rate;
                assert_eq!(raw.clamp(-cap, cap)*MOTOR_DIRECTION_SIGN, c.target_velocity_rad_s);
                assert_eq!(raw.abs() > cap, c.velocity_saturated);
                let mut expected = before.clone();
                expected.target_velocity_rad_s = c.target_velocity_rad_s;
                expected.safety_contribution_rad_s = c.safety_contribution_rad_s;
                expected.velocity_saturated = c.velocity_saturated;
                assert_eq!(*c, expected);
                changed += usize::from(c.target_velocity_rad_s != before.target_velocity_rad_s);
                if n == 1 { assert_eq!(*c, *before); assert_eq!(rate, 0.0); }
            }
            memory = out.next_memory; parent = oldout.next_memory;
        }
        assert!(changed > 0);
    }

    #[test]
    fn v37_ideal_velocity_servo_cancels_reference_rate_only_under_stated_assumptions() {
        // Algebra check, not a simulation: assume instantaneous q_dot=u and
        // no output clamp, torque limit, delay or contact coupling.
        for rate in [-3.5, -0.2, 0.0, 0.4, 3.5] {
            for error in [-0.3, 0.0, 0.2] {
                let ideal_speed = rate + MOTOR_POSITION_GAIN_PER_S*error/(1.0+MOTOR_RATE_DAMPING);
                let command = rate + MOTOR_POSITION_GAIN_PER_S*error - MOTOR_RATE_DAMPING*(ideal_speed-rate);
                assert!((command-ideal_speed).abs() < 1e-14);
                assert!((rate-ideal_speed+MOTOR_POSITION_GAIN_PER_S*error/(1.0+MOTOR_RATE_DAMPING)).abs() < 1e-14);
            }
        }
    }

    #[test]
    fn v37_crossed_memory_missing_floor_and_time_drift_refuse() {
        let (source, new, old, floor) = setup(); let memory = new.initial_memory();
        let input = state(&source, 1); let motion = command(1);
        assert!(new.step_with_floor(&old.initial_memory(), &input, &motion, Some(&floor)).actuation.safe_no_actuation);
        assert!(new.step(&memory, &input, &motion).actuation.safe_no_actuation);
        let first = new.step_with_floor(&memory, &input, &motion, Some(&floor));
        assert!(!first.actuation.safe_no_actuation);
        let mut changed = floor.clone(); changed.source_instance_id.push_str("_crossed");
        let refused = new.step_with_floor(&first.next_memory, &state(&source, 2), &command(2), Some(&changed));
        assert!(refused.actuation.safe_no_actuation); assert_eq!(refused.next_memory, first.next_memory);
        let mut stale = state(&source, 2); stale.sample_time_s = input.sample_time_s;
        let refused = new.step_with_floor(&first.next_memory, &stale, &command(2), Some(&floor));
        assert!(refused.actuation.safe_no_actuation); assert_eq!(refused.next_memory, first.next_memory);
        assert!(refused.actuation.ordered_commands.iter().all(|c| c.target_velocity_rad_s == 0.0));
    }
}
