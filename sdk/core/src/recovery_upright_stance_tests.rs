mod recovery_upright_stance {
    use super::*;
    use crate::controller::{BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_PROFILE_VERSION as PROFILE,
        CONTACT_SELECTED_UPRIGHT_STANCE_MODE_ID as MODE};
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source = controller();
        let new = BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        let old = BalancedWaveController::new_for_policy(source.compiled().clone(), PARENT).unwrap();
        let floor = FloorReference {schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: FRAME_ID.to_owned(), surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_v41_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)), height_world_m: 0.0};
        (source, new, old, floor)
    }

    #[test]
    fn v41_identity_and_current_contact_selector_truth_table() {
        let (_, new, old, _) = setup();
        let mut profile = old.profile().clone();
        profile.policy_id = POLICY.to_owned(); profile.schema_version = PROFILE.to_owned();
        profile.reference_velocity_mode_id = Some(MODE.to_owned());
        assert_eq!(new.profile(), &profile);
        let mut memory = old.initial_memory();
        memory.schema_version = BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION.to_owned();
        assert_eq!(new.initial_memory(), memory);
        assert_eq!(crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID, BALANCED_WAVE_BW5R_B_POLICY_ID);
        for active in [false, true] {for phase in [0, 71, 72, 73, 359, 360] {
            for presence in [None, Some(false), Some(true)] {for bearing in [None, Some(false), Some(true)] {
                assert_eq!(crate::recovery_support_plane::upright_stance_selected(active, phase, presence, bearing),
                    active && phase > 72 && phase < 360 && presence == Some(true) && bearing == Some(true));
            }}
        }}
    }

    #[test]
    fn v41_upright_yaws_identity_initial_hold_and_inactive_activation_controls() {
        let (source, new, old, floor) = setup();
        for yaw in [0.0_f64, 0.6, -1.7] {
            let mut memory = new.initial_memory();
            for limb in &mut memory.ordered_limb_memory {limb.gait_step = 90;}
            for (i, amplitude) in [0.0, 0.4, 0.4, 0.0, 0.4].into_iter().enumerate() {
                let n = i as u64 + 1; let mut input = state(&source, n);
                input.base_pose_world.position_m.y = 0.35;
                input.base_pose_world.orientation_xyzw = Quaternion {x: 0.0, y: (yaw/2.0).sin(), z: 0.0, w: (yaw/2.0).cos()};
                let preserved = input.clone(); let mut motion = command(n); motion.gait_amplitude = amplitude;
                let mut parent = memory.clone(); parent.schema_version = BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION.to_owned();
                let out = new.step_with_floor(&memory, &input, &motion, Some(&floor));
                let before = old.step_with_floor(&parent, &input, &motion, Some(&floor));
                assert!(!out.actuation.safe_no_actuation, "{:?}", out.actuation.receipt.controller_error);
                assert!(!before.actuation.safe_no_actuation); assert_eq!(input, preserved);
                assert_eq!(out.actuation.ordered_commands, before.actuation.ordered_commands);
                let receipt = out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
                let upright = receipt.upright_stance.as_ref().unwrap();
                assert_eq!(upright.measured_pose_baseline_proposals, upright.floor_upright_reference_proposals);
                if amplitude == 0.0 {assert!(upright.ordered_selected_goals_rad.iter().all(|v| *v == 0.0));}
                if i != 2 {assert!(receipt.ordered_reference_velocity_rad_s.as_ref().unwrap().iter().all(|v| *v == 0.0));}
                if i == 0 {assert!(out.actuation.ordered_commands.iter().all(|c| c.requested_target_position_rad == 0.0));}
                memory = out.next_memory;
            }
        }
    }

    #[test]
    fn v41_tilted_four_hundred_chained_inputs_truthful_goals_and_same_memory_parent() {
        let (source, new, old, floor) = setup(); let mut memory = new.initial_memory();
        for limb in &mut memory.ordered_limb_memory {limb.gait_step = 90;}
        let mut selected_count = 0; let mut changed_count = 0;
        for n in 1..=400 {
            let mut input = state(&source, n); input.base_pose_world.position_m.y = 0.37 + 0.02*(n as f64/17.0).sin();
            let angle = 0.06_f64;
            input.base_pose_world.orientation_xyzw = Quaternion {x: angle.sin(), y: 0.0, z: 0.0, w: angle.cos()};
            for (i, c) in input.ordered_contact_observations.iter_mut().enumerate() {
                c.presence = Some((n + i as u64*19)%53 < 31); c.bears_support = c.presence;
            }
            let preserved = input.clone(); let mut motion = command(n);
            motion.gait_amplitude = (1.1/(0.82*1.75+0.40))*smoothstep((n-1) as f64/72.0);
            let mut parent = memory.clone(); parent.schema_version = BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION.to_owned();
            let out = new.step_with_floor(&memory, &input, &motion, Some(&floor));
            let before = old.step_with_floor(&parent, &input, &motion, Some(&floor));
            assert!(!out.actuation.safe_no_actuation, "{:?}", out.actuation.receipt.controller_error);
            assert!(!before.actuation.safe_no_actuation); assert_eq!(input, preserved);
            let r = out.actuation.receipt.recovery_support_plane.as_ref().unwrap(); let u = r.upright_stance.as_ref().unwrap();
            let old_r = before.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            assert_eq!(u.measured_pose_baseline_proposals, old_r.ordered_limb_proposals);
            assert_eq!(u.measured_pose_baseline_plan, old_r.feasible_support_plan);
            assert!(r.feasible_support_plan.is_none()); assert!(u.comparison_uses_current_selector);
            assert_eq!(u.source_semantic_step, input.semantic_step); assert_eq!(u.source_floor_reference, floor);
            assert_eq!(u.reference_anatomical_vertical_projections, [0.0, 1.0, 0.0]);
            // Only reference positions and identity may differ in next memory.
            let mut expected = before.next_memory.clone(); expected.schema_version = out.next_memory.schema_version.clone();
            expected.support_reference.as_mut().unwrap().ordered_target_positions_rad = out.next_memory.support_reference.as_ref().unwrap().ordered_target_positions_rad.clone();
            assert_eq!(expected, out.next_memory);
            for i in 0..4 {
                let limb = &u.ordered_limbs[i]; let selected = limb.upright_reference_selected;
                assert_eq!(limb.precommand_contact, input.ordered_contact_observations[i]);
                let actual = &r.ordered_limb_proposals[i];
                assert_eq!(actual, if selected {&u.floor_upright_reference_proposals[i]} else {&u.measured_pose_baseline_proposals[i]});
                assert_eq!(&u.ordered_selected_goals_rad[2*i..2*i+2], &[actual.goal_hip_rad, actual.goal_knee_rad]);
                selected_count += usize::from(selected);
                for j in 2*i..2*i+2 {
                    let c = &out.actuation.ordered_commands[j]; let b = &before.actuation.ordered_commands[j];
                    if !selected {assert_eq!(c, b);}
                    changed_count += usize::from(c.target_velocity_rad_s != b.target_velocity_rad_s);
                    let old_ref = memory.support_reference.as_ref().unwrap().ordered_target_positions_rad[j];
                    assert!((c.requested_target_position_rad-old_ref).abs() <= c.maximum_target_speed_rad_s*r.reference_step_duration_s+1e-14);
                    assert!(c.target_velocity_rad_s.abs() <= c.maximum_target_speed_rad_s);
                    if n <= 2 {assert_eq!(r.ordered_reference_velocity_rad_s.as_ref().unwrap()[j], 0.0);}
                }
            }
            memory = out.next_memory;
        }
        assert!(selected_count > 0 && changed_count > 0);
    }

    #[test]
    fn v41_invalid_state_floor_wave_and_crossed_identity_refuse_without_memory_advance() {
        let (source, new, _, floor) = setup();
        let memory = new.step_with_floor(&new.initial_memory(), &state(&source, 1), &command(1), Some(&floor)).next_memory;
        for variant in 0..15 {
            let mut bad = memory.clone(); let mut input = state(&source, 2); let mut plane = floor.clone();
            match variant {
                0 => input.ordered_contact_observations[0].presence = None,
                1 => input.ordered_contact_observations[0].bears_support = None,
                2 => {input.ordered_contact_observations.pop();},
                3 => input.ordered_contact_observations.swap(0, 1),
                4 => input.ordered_contact_observations[0].contact_site_id = "other_foot".to_owned(),
                5 => input.ordered_contact_observations[0].presence = Some(false),
                6 => input.sample_time_s = state(&source, 1).sample_time_s,
                7 => bad.schema_version = BALANCED_WAVE_RECOVERY_ABSENT_CONTACT_REFERENCE_MEMORY_VERSION.to_owned(),
                8 => bad.support_reference.as_mut().unwrap().previous_wave = None,
                9 => bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].scheduled_phase_step = 360,
                10 => bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].walking_knee_fraction = f64::NAN,
                11 => input.ordered_joint_observations.swap(0, 1),
                12 => plane.height_world_m = 1.0,
                13 => input.base_pose_world.orientation_xyzw = Quaternion {x: 0.0, y: 0.0, z: 0.0, w: 0.0},
                _ => input.base_pose_world.position_m.y = f64::NAN,
            }
            let out = new.step_with_floor(&bad, &input, &command(2), Some(&plane));
            assert!(out.actuation.safe_no_actuation, "variant {variant}");
            assert_eq!(serde_json::to_string(&out.next_memory).unwrap(), serde_json::to_string(&bad).unwrap());
            assert!(out.actuation.ordered_commands.iter().all(|c| c.target_velocity_rad_s == 0.0));
            assert!(out.actuation.receipt.recovery_support_plane.is_none());
        }
        assert!(new.step(&memory, &state(&source, 2), &command(2)).actuation.safe_no_actuation);
    }
}
