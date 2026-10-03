mod joint_pose_entry_tests {
    use super::*;
    use crate::joint_pose_entry as entry;

    fn setup() -> (BalancedWaveController, Candidate35Controller) {
        let compiled =
            compile_bounded_quadruped(crate::actuator_profile::r23d60_selected_s169_descriptor())
                .unwrap();
        (
            BalancedWaveController::new_for_policy(compiled.clone(), entry::POLICY).unwrap(),
            Candidate35Controller::new(compiled).unwrap(),
        )
    }

    fn stationary(step: u64) -> MotionCommand {
        let mut result = command(step);
        result.gait_amplitude = 0.0;
        result.desired_planar_velocity_task_m_s = Vec3::ZERO;
        result
    }

    #[test]
    fn measured_entry_ramp_is_bounded_and_finishes_before_the_ready_dwell_budget() {
        let (controller, source) = setup();
        let mut memory = controller.initial_memory();
        let goal = entry::goals(controller.compiled()).unwrap();
        let mut q = [0.0; 8];
        let mut velocity = [0.0; 8];
        for step in 1..=entry::MAX_COMMANDS {
            let mut observed = state(&source, step);
            for i in 0..8 {
                observed.ordered_joint_observations[i].position_rad = Some(q[i]);
                observed.ordered_joint_observations[i].velocity_rad_s = Some(velocity[i]);
            }
            let original = observed.clone();
            let output = controller.step(&memory, &observed, &stationary(step));
            assert!(
                !output.actuation.safe_no_actuation,
                "{:?}",
                output.actuation.failure_codes
            );
            assert_eq!(observed, original);
            assert_eq!(output.actuation.world_build_count, 0);
            let pose = output.next_memory.joint_pose_entry.as_ref().unwrap();
            assert_eq!(pose.ramp_intervals, 164);
            assert_eq!(pose.reference_ramp_complete, step >= 165);
            for (i, c) in output.actuation.ordered_commands.iter().enumerate() {
                assert!(!c.position_saturated);
                assert_eq!(c.maximum_target_speed_rad_s, 0.75);
                assert!(c.target_velocity_rad_s.abs() <= 0.75);
                assert!((c.requested_target_position_rad - q[i]).abs() <= 0.75 / 120.0 + 1e-14);
                if step == 1 {
                    assert_eq!(c.target_velocity_rad_s, 0.0);
                }
                velocity[i] = (c.requested_target_position_rad - q[i]) * 120.0;
                q[i] = c.requested_target_position_rad;
            }
            if step >= 165 {
                assert_eq!(q, goal);
            }
            memory = output.next_memory;
        }
        let refused = controller.step(&memory, &state(&source, 241), &stationary(241));
        assert!(refused.actuation.safe_no_actuation);
        assert_eq!(refused.next_memory, memory);
        assert!(
            refused
                .actuation
                .ordered_commands
                .iter()
                .all(|c| c.target_velocity_rad_s == 0.0)
        );
    }

    #[test]
    fn entry_refuses_changed_pose_memory_clocks_and_nonstationary_commands() {
        let (controller, source) = setup();
        let first = controller.step(
            &controller.initial_memory(),
            &state(&source, 1),
            &stationary(1),
        );
        for kind in 0..7 {
            let mut memory = first.next_memory.clone();
            let mut observed = state(&source, 2);
            let mut motion = stationary(2);
            let pose = memory.joint_pose_entry.as_mut().unwrap();
            match kind {
                0 => pose.ordered_goal_positions_rad[0] += 0.001,
                1 => pose.ordered_previous_references_rad[0] += 0.001,
                2 => pose.ramp_intervals += 1,
                3 => pose.reference_ramp_complete = true,
                4 => observed.sample_time_s += 1.0 / 120.0,
                5 => motion.gait_amplitude = 1.0,
                _ => motion.desired_planar_velocity_task_m_s.x = 0.1,
            }
            let refused = controller.step(&memory, &observed, &motion);
            assert!(refused.actuation.safe_no_actuation, "kind {kind}");
            assert_eq!(refused.next_memory, memory);
            assert!(
                refused
                    .actuation
                    .ordered_commands
                    .iter()
                    .all(|c| c.target_velocity_rad_s == 0.0)
            );
        }
    }

    #[test]
    fn entry_memory_is_explicit_and_cannot_cross_into_legacy_walking() {
        let (controller, source) = setup();
        let first = controller.step(
            &controller.initial_memory(),
            &state(&source, 1),
            &stationary(1),
        );
        let old = BalancedWaveController::new_for_policy(
            controller.compiled().clone(),
            BALANCED_WAVE_BW5R_B_POLICY_ID,
        )
        .unwrap();
        let mut crossed = first.next_memory;
        crossed.schema_version = old.initial_memory().schema_version;
        let refused = old.step(&crossed, &state(&source, 2), &stationary(2));
        assert!(refused.actuation.safe_no_actuation);
        assert_eq!(refused.next_memory, crossed);
        assert!(
            !serde_json::to_string(&old.initial_memory())
                .unwrap()
                .contains("joint_pose_entry")
        );
        let mut outside = state(&source, 1);
        outside.ordered_joint_observations[1].position_rad = Some(1.2);
        assert!(
            controller
                .step(&controller.initial_memory(), &outside, &stationary(1))
                .actuation
                .safe_no_actuation
        );
    }
}
