mod recovery_smooth_swing {
    use super::*;
    use crate::controller::{
        BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_SMOOTH_SWING_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_SMOOTH_SWING_PROFILE_VERSION as PROFILE,
        PHASE_ONLY_LOADED_PEAK_SWING_LIFT_MODE_ID as MODE,
    };
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source = controller();
        let new = BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        let old = BalancedWaveController::new_for_policy(source.compiled().clone(), PARENT).unwrap();
        let floor = FloorReference {
            schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: FRAME_ID.to_owned(), surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_v36_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)), height_world_m: 0.0,
        };
        (source, new, old, floor)
    }

    #[test]
    fn v36_profile_changes_only_identity_and_lift_mode() {
        let (_, new, old, _) = setup();
        let mut expected = old.profile().clone();
        expected.policy_id = POLICY.to_owned();
        expected.schema_version = PROFILE.to_owned();
        expected.swing_lift_mode_id = Some(MODE.to_owned());
        assert_eq!(&expected, new.profile());
        assert_eq!(new.initial_memory().schema_version, BALANCED_WAVE_RECOVERY_SMOOTH_SWING_MEMORY_VERSION);
        assert!(!serde_json::to_string(old.profile()).unwrap().contains("swing_lift_mode_id"));
        assert_eq!(crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID, BALANCED_WAVE_BW5R_B_POLICY_ID);
    }

    #[test]
    fn v36_all_phases_have_contact_independent_lift_and_exact_endpoints() {
        let (source, new, _, floor) = setup();
        let amplitude = 1.1 / (0.82 * 1.75 + 0.40);
        assert_eq!(smooth_swing_knee_target(36, amplitude), 1.1);
        for phase in 0..360 {
            let mut pair = Vec::new();
            for bearing in [false, true] {
                let mut memory = new.initial_memory();
                for limb in &mut memory.ordered_limb_memory { limb.gait_step = phase + 90; }
                let mut input = state(&source, 1);
                input.base_pose_world.position_m.y = 0.37;
                for c in &mut input.ordered_contact_observations {
                    c.presence = Some(bearing); c.bears_support = Some(bearing);
                }
                let mut motion = command(1); motion.gait_amplitude = amplitude;
                let out = new.step_with_floor(&memory, &input, &motion, Some(&floor));
                assert!(!out.actuation.safe_no_actuation, "{:?}", out.actuation.receipt.controller_error);
                let receipt = out.actuation.receipt.recovery_support_plane.unwrap();
                assert_eq!(receipt.swing_lift_mode_id.as_deref(), Some(MODE));
                let p = &receipt.ordered_limb_proposals[0];
                assert_eq!(p.limb_id, "front_left");
                assert_eq!(p.scheduled_phase_step, Some(phase));
                let expected_fraction = if phase < 72 {
                    (std::f64::consts::PI * phase as f64 / 72.0).sin()
                } else { 0.0 };
                assert!((p.walking_knee_fraction - expected_fraction).abs() <= 1e-14);
                if phase == 0 || phase >= 72 { assert_eq!(p.walking_knee_fraction, 0.0); }
                pair.push(receipt);
            }
            // Initial memory fixes the phase: this compares lift/geometry, not
            // a claim that contact may never affect subsequent clock or motors.
            assert_eq!(pair[0], pair[1]);
        }
    }

    #[test]
    fn v36_four_hundred_inputs_keep_parent_gates_height_and_bounded_slew() {
        let (source, new, old, floor) = setup();
        let mut memory = new.initial_memory();
        let mut parent = old.initial_memory();
        for limb in &mut memory.ordered_limb_memory { limb.gait_step = 90; }
        for limb in &mut parent.ordered_limb_memory { limb.gait_step = 90; }
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
            assert_eq!(out.next_memory.ordered_limb_memory, oldout.next_memory.ordered_limb_memory);
            let r = out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            let p = oldout.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            assert_eq!(r.feasible_support_plan, p.feasible_support_plan);
            assert_eq!(r.floor_reference, p.floor_reference);
            for (a,b) in r.ordered_limb_proposals.iter().zip(&p.ordered_limb_proposals) {
                assert_eq!(a.nominal_leg_direction_rad, b.nominal_leg_direction_rad);
                assert_eq!(a.projected_support_hip_rad, b.projected_support_hip_rad);
                assert_eq!(a.projected_support_knee_rad, b.projected_support_knee_rad);
            }
            for (i,c) in out.actuation.ordered_commands.iter().enumerate() {
                let a = &source.compiled().morphology.morphology_spec.actuators[i];
                assert!((a.minimum_target_position_rad..=a.maximum_target_position_rad).contains(&c.requested_target_position_rad));
                let delta = c.requested_target_position_rad - memory.support_reference.as_ref().unwrap().ordered_target_positions_rad[i];
                assert!(delta.abs() <= c.maximum_target_speed_rad_s * r.reference_step_duration_s + 1e-14);
                if n == 1 { assert_eq!(c.requested_target_position_rad, 0.0); }
            }
            let cold: BalancedWaveControllerMemory = serde_json::from_str(&serde_json::to_string(&memory).unwrap()).unwrap();
            assert_eq!(out, new.step_with_floor(&cold, &input, &motion, Some(&floor)));
            memory = out.next_memory; parent = oldout.next_memory;
        }
    }

    #[test]
    fn v36_crossed_memory_missing_floor_and_changed_source_refuse() {
        let (source, new, old, floor) = setup();
        let memory = new.initial_memory();
        let input = state(&source, 1); let motion = command(1);
        let crossed = new.step_with_floor(&old.initial_memory(), &input, &motion, Some(&floor));
        assert!(crossed.actuation.safe_no_actuation);
        assert_eq!(crossed.next_memory, old.initial_memory());
        assert!(new.step(&memory, &input, &motion).actuation.safe_no_actuation);
        let first = new.step_with_floor(&memory, &input, &motion, Some(&floor));
        assert!(!first.actuation.safe_no_actuation);
        let mut changed = floor.clone(); changed.source_instance_id.push_str("_crossed");
        let refused = new.step_with_floor(&first.next_memory, &state(&source, 2), &command(2), Some(&changed));
        assert!(refused.actuation.safe_no_actuation);
        assert_eq!(refused.next_memory, first.next_memory);
        assert!(refused.actuation.ordered_commands.iter().all(|c| c.target_velocity_rad_s == 0.0));
    }
}
