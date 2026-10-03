mod recovery_feasible_support {
    use super::*;
    use crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_POLICY_ID as POLICY;
    use crate::recovery_feasible_support::{MEMORY_VERSION, MODE_ID};
    use crate::recovery_floor_reference::{FRAME_ID, FloorReference};
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
            source_instance_id: "synthetic_v35_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)),
            height_world_m: 0.0,
        };
        (source, policy, floor)
    }
    #[test]
    fn v35_profile_is_distinct_and_old_profile_is_not_promoted() {
        let (source, policy, floor) = setup();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID,
        )
        .unwrap();
        let mut expected = old.profile().clone();
        expected.policy_id = POLICY.to_owned();
        expected.schema_version =
            crate::controller::BALANCED_WAVE_RECOVERY_FEASIBLE_SUPPORT_PROFILE_VERSION.to_owned();
        expected.stance_support_mode_id = Some(MODE_ID.to_owned());
        assert_eq!(policy.profile(), &expected);
        assert_eq!(policy.initial_memory().schema_version, MEMORY_VERSION);
        let crossed = policy.step_with_floor(
            &old.initial_memory(),
            &state(&source, 1),
            &command(1),
            Some(&floor),
        );
        assert!(crossed.actuation.safe_no_actuation);
        let missing = policy.step(&policy.initial_memory(), &state(&source, 1), &command(1));
        assert!(missing.actuation.safe_no_actuation);
        assert_eq!(
            crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID
        );
    }
    #[test]
    fn v35_actual_landing_floor_and_scheduled_stance_height_are_separate() {
        let (source, policy, floor) = setup();
        let mut memory = policy.initial_memory();
        for limb in &mut memory.ordered_limb_memory {
            limb.gait_step = 162;
        }
        let mut observation = state(&source, 1);
        observation.base_pose_world.position_m.y = 0.4;
        for contact in &mut observation.ordered_contact_observations {
            contact.presence = Some(false);
            contact.bears_support = Some(false);
        }
        let out = policy.step_with_floor(&memory, &observation, &command(1), Some(&floor));
        assert!(
            !out.actuation.safe_no_actuation,
            "{:?}",
            out.actuation.receipt.controller_error
        );
        assert!(
            out.actuation
                .ordered_commands
                .iter()
                .all(|c| c.requested_target_position_rad == 0.0)
        );
        let r = out.actuation.receipt.recovery_support_plane.unwrap();
        let plan = r.feasible_support_plan.unwrap();
        assert!(plan.requested_lowering_m > 0.0 && plan.common_height_interval_nonempty);
        assert_eq!(
            plan.ordered_lowering_participant_limb_ids,
            vec!["front_right", "rear_left", "rear_right"]
        );
        for p in r.ordered_limb_proposals {
            if p.limb_id == "front_left" {
                assert_eq!(p.scheduled_phase_step, Some(72));
                assert_eq!(p.support_reference_torso_height_m, Some(0.4));
                assert!(p.link_reach_projection_required.unwrap());
            } else {
                assert!(p.scheduled_phase_step.unwrap() > 72);
                assert_eq!(
                    p.support_reference_torso_height_m,
                    Some(plan.requested_stance_torso_height_m)
                );
                assert!(!p.support_joint_projection_required);
            }
        }
    }
    #[test]
    fn v35_four_hundred_steps_replay_scheduler_and_slew_without_new_timeouts() {
        let (source, policy, floor) = setup();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            crate::controller::BALANCED_WAVE_RECOVERY_FLOOR_SUPPORT_POLICY_ID,
        )
        .unwrap();
        let mut memory = policy.initial_memory();
        let mut previous = old.initial_memory();
        for (new, old) in memory
            .ordered_limb_memory
            .iter_mut()
            .zip(&mut previous.ordered_limb_memory)
        {
            new.gait_step = 90;
            old.gait_step = 90;
        }
        for n in 1..=400 {
            let mut observation = state(&source, n);
            observation.base_pose_world.position_m.y = 0.37 + 0.02 * (n as f64 / 17.0).sin();
            for (i, c) in observation
                .ordered_contact_observations
                .iter_mut()
                .enumerate()
            {
                c.presence = Some((n + i as u64 * 19) % 53 < 31);
                c.bears_support = c.presence;
            }
            let mut request = command(n);
            request.gait_amplitude = 0.5994550408719347 * smoothstep((n - 1) as f64 / 72.0);
            let out = policy.step_with_floor(&memory, &observation, &request, Some(&floor));
            let oldout = old.step_with_floor(&previous, &observation, &request, Some(&floor));
            assert!(
                !out.actuation.safe_no_actuation,
                "{:?}",
                out.actuation.receipt.controller_error
            );
            assert_eq!(
                out.next_memory.ordered_limb_memory,
                oldout.next_memory.ordered_limb_memory
            );
            let cold: BalancedWaveControllerMemory =
                serde_json::from_str(&serde_json::to_string(&memory).unwrap()).unwrap();
            assert_eq!(
                out,
                policy.step_with_floor(&cold, &observation, &request, Some(&floor))
            );
            let receipt = out
                .actuation
                .receipt
                .recovery_support_plane
                .as_ref()
                .unwrap();
            let plan = receipt.feasible_support_plan.as_ref().unwrap();
            assert!(plan.requested_stance_torso_height_m <= plan.measured_torso_height_m);
            for (i, c) in out.actuation.ordered_commands.iter().enumerate() {
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
            memory = out.next_memory;
            previous = oldout.next_memory;
        }
    }
}
