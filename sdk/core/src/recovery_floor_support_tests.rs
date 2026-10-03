// New policy only. Synthetic states test geometry/contracts, not physical success.
mod recovery_floor_support {
    use super::*;
    use crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID as POLICY;
    use crate::recovery_floor_reference::{FRAME_ID, FloorReference, MEMORY_VERSION, MODE_ID};

    fn setup() -> (
        Candidate35Controller,
        BalancedWaveController,
        FloorReference,
    ) {
        let source = controller();
        let policy =
            BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        let floor = FloorReference {
            schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: FRAME_ID.to_owned(),
            surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_construction_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)),
            height_world_m: 0.0,
        };
        (source, policy, floor)
    }

    #[test]
    fn v34_distinct_profile_memory_and_missing_or_crossed_context_refuse() {
        let (source, policy, floor) = setup();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            crate::controller::BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID,
        )
        .unwrap();
        let mut expected = old.profile().clone();
        expected.policy_id = POLICY.to_owned();
        expected.schema_version =
            crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_PROFILE_VERSION.to_owned();
        expected.stance_support_mode_id = Some(MODE_ID.to_owned());
        assert_eq!(&expected, policy.profile());
        let memory = policy.initial_memory();
        assert_eq!(memory.schema_version, MEMORY_VERSION);
        let missing = policy.step(&memory, &state(&source, 1), &command(1));
        assert!(missing.actuation.safe_no_actuation);
        assert_eq!(missing.next_memory, memory);
        let crossed = old.step_with_floor(
            &old.initial_memory(),
            &state(&source, 1),
            &command(1),
            Some(&floor),
        );
        assert!(crossed.actuation.safe_no_actuation);
        assert!(
            !serde_json::to_value(old.initial_memory())
                .unwrap()
                .as_object()
                .unwrap()
                .contains_key("floor_reference_sha256")
        );
        assert_eq!(
            crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID
        );
    }

    #[test]
    fn v34_explicit_floor_reachable_support_and_translated_world_agree() {
        let (source, policy, floor) = setup();
        let mut observation = state(&source, 1);
        observation.base_pose_world.position_m.y = 0.37;
        let first = policy.step_with_floor(
            &policy.initial_memory(),
            &observation,
            &command(1),
            Some(&floor),
        );
        assert!(!first.actuation.safe_no_actuation);
        assert!(
            first
                .actuation
                .ordered_commands
                .iter()
                .all(|c| c.requested_target_position_rad == 0.0)
        );
        let receipt = first
            .actuation
            .receipt
            .recovery_support_plane
            .as_ref()
            .unwrap();
        assert_eq!(receipt.mode_id, MODE_ID);
        assert_eq!(receipt.floor_reference.as_ref(), Some(&floor));
        assert_eq!(receipt.proposed_torso_height_m, 0.37);
        for p in &receipt.ordered_limb_proposals {
            assert!(!p.link_reach_projection_required.unwrap());
            assert!(!p.support_joint_projection_required);
            assert!(p.projected_support_nominal_plane_residual_m.abs() < 1e-14);
        }
        let mut moved = observation.clone();
        moved.base_pose_world.position_m.y += 7.0;
        moved.task_frame.origin_world_m.y += 7.0;
        let mut moved_floor = floor.clone();
        moved_floor.height_world_m += 7.0;
        let translated = policy.step_with_floor(
            &policy.initial_memory(),
            &moved,
            &command(1),
            Some(&moved_floor),
        );
        assert!(!translated.actuation.safe_no_actuation);
        for (a, b) in receipt.ordered_limb_proposals.iter().zip(
            &translated
                .actuation
                .receipt
                .recovery_support_plane
                .unwrap()
                .ordered_limb_proposals,
        ) {
            assert!((a.projected_support_hip_rad - b.projected_support_hip_rad).abs() < 1e-12);
            assert!((a.projected_support_knee_rad - b.projected_support_knee_rad).abs() < 1e-12);
        }
    }

    #[test]
    fn v34_unreachable_and_overfolded_support_retain_limits_and_residuals() {
        let (source, policy, floor) = setup();
        for height in [0.45, 0.1, 0.04, -0.02] {
            let mut observation = state(&source, 1);
            observation.base_pose_world.position_m.y = height;
            let output = policy.step_with_floor(
                &policy.initial_memory(),
                &observation,
                &command(1),
                Some(&floor),
            );
            assert!(
                !output.actuation.safe_no_actuation,
                "{:?}",
                output.actuation.receipt.controller_error
            );
            let receipt = output.actuation.receipt.recovery_support_plane.unwrap();
            for p in receipt.ordered_limb_proposals {
                assert!((0.0..=1.1).contains(&p.goal_knee_rad));
                assert!((-0.72..=0.72).contains(&p.goal_hip_rad));
                if height == 0.45 {
                    assert!(p.link_reach_projection_required.unwrap());
                    assert_eq!(p.projected_support_knee_rad, 0.0);
                    assert!(p.projected_support_nominal_plane_residual_m > 0.05);
                } else {
                    assert!(p.support_joint_projection_required);
                    assert_eq!(p.projected_support_knee_rad, 1.1);
                    assert!(p.projected_support_nominal_plane_residual_m < 0.0);
                }
            }
            assert!(!receipt.all_limb_contact_claim && !receipt.physical_acceptance_authority);
        }
    }

    #[test]
    fn v34_floor_provenance_and_continuity_fail_without_advancing() {
        let (source, policy, floor) = setup();
        let first = policy.step_with_floor(
            &policy.initial_memory(),
            &state(&source, 1),
            &command(1),
            Some(&floor),
        );
        let mut alternatives = Vec::new();
        let mut bad = floor.clone();
        bad.height_world_m = 1.;
        alternatives.push(bad);
        let mut bad = floor.clone();
        bad.geometry_source_sha256 = format!("sha256:{}", "2".repeat(64));
        alternatives.push(bad);
        let mut bad = floor.clone();
        bad.source_instance_id = "different_world".to_owned();
        alternatives.push(bad);
        let mut bad = floor.clone();
        bad.frame_id = "body_local".to_owned();
        alternatives.push(bad);
        let mut bad = floor.clone();
        bad.geometry_source_sha256 = "unbound".to_owned();
        alternatives.push(bad);
        let mut bad = floor.clone();
        bad.height_world_m = f64::NAN;
        alternatives.push(bad);
        for plane in alternatives {
            let output = policy.step_with_floor(
                &first.next_memory,
                &state(&source, 2),
                &command(2),
                Some(&plane),
            );
            assert!(output.actuation.safe_no_actuation);
            assert_eq!(output.next_memory, first.next_memory);
            assert!(
                output
                    .actuation
                    .ordered_commands
                    .iter()
                    .all(|c| c.target_velocity_rad_s == 0.)
            );
        }
    }

    #[test]
    fn v34_consecutive_replay_preserves_scheduler_bounds_and_neutral_startup() {
        let (source, policy, floor) = setup();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            crate::controller::BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID,
        )
        .unwrap();
        let mut memory = policy.initial_memory();
        let mut old_memory = old.initial_memory();
        for step in 1..=400 {
            let mut observation = state(&source, step);
            observation.base_pose_world.position_m.y = 0.37 + 0.03 * (step as f64 / 17.).sin();
            for (i, c) in observation
                .ordered_contact_observations
                .iter_mut()
                .enumerate()
            {
                c.presence = Some((step + i as u64 * 19) % 53 < 31);
                c.bears_support = c.presence;
            }
            let mut request = command(step);
            request.gait_amplitude = 0.5994550408719347 * smoothstep((step - 1) as f64 / 72.);
            let output = policy.step_with_floor(&memory, &observation, &request, Some(&floor));
            let old_output = old.step(&old_memory, &observation, &request);
            assert!(!output.actuation.safe_no_actuation && !old_output.actuation.safe_no_actuation);
            assert_eq!(
                output.next_memory.ordered_limb_memory,
                old_output.next_memory.ordered_limb_memory
            );
            let cold: BalancedWaveControllerMemory =
                serde_json::from_str(&serde_json::to_string(&memory).unwrap()).unwrap();
            assert_eq!(
                output,
                policy.step_with_floor(&cold, &observation, &request, Some(&floor))
            );
            let receipt = output
                .actuation
                .receipt
                .recovery_support_plane
                .as_ref()
                .unwrap();
            for (i, c) in output.actuation.ordered_commands.iter().enumerate() {
                let a = &source.compiled().morphology.morphology_spec.actuators[i];
                assert!(
                    (a.minimum_target_position_rad..=a.maximum_target_position_rad)
                        .contains(&c.requested_target_position_rad)
                );
                assert!(
                    (c.requested_target_position_rad
                        - memory
                            .support_reference
                            .as_ref()
                            .unwrap()
                            .ordered_target_positions_rad[i])
                        .abs()
                        <= c.maximum_target_speed_rad_s * receipt.reference_step_duration_s + 1e-14
                );
            }
            memory = output.next_memory;
            old_memory = old_output.next_memory;
        }
    }
}
