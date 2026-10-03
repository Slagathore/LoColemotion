// Zero-world tests for the distinct V33 walking controller. Not physics proof.
mod recovery_bounded_support {
    use super::*;
    use crate::controller::{
        BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_BOUNDED_SUPPORT_PROFILE_VERSION as PROFILE,
    };
    use crate::recovery_support_plane::{MEMORY_VERSION, MODE_ID};

    fn pair() -> (Candidate35Controller, BalancedWaveController) {
        let source = controller();
        let policy =
            BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        (source, policy)
    }

    fn rolled(source: &Candidate35Controller, step: u64, angle: f64) -> StateFrame {
        let mut observation = state(source, step);
        // Anatomical Rx(roll), postmultiplied by the historical walking Ry(pi/2).
        let s = std::f64::consts::FRAC_1_SQRT_2;
        observation.base_pose_world.orientation_xyzw = crate::protocol::Quaternion {
            x: (angle / 2.0).sin() * s,
            y: (angle / 2.0).cos() * s,
            z: (angle / 2.0).sin() * s,
            w: (angle / 2.0).cos() * s,
        };
        observation
    }

    #[test]
    fn v33_identity_and_memory_are_distinct_and_legacy_serialization_stays_empty() {
        let (source, new) = pair();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID,
        )
        .unwrap();
        let mut expected = old.profile().clone();
        expected.policy_id = POLICY.to_owned();
        expected.schema_version = PROFILE.to_owned();
        expected.stance_support_mode_id = Some(MODE_ID.to_owned());
        assert_eq!(&expected, new.profile());
        assert_eq!(new.initial_memory().schema_version, MEMORY_VERSION);
        assert!(new.initial_memory().support_reference.is_some());
        assert!(
            !serde_json::to_value(old.initial_memory())
                .unwrap()
                .as_object()
                .unwrap()
                .contains_key("support_reference")
        );
        assert!(
            !serde_json::to_value(old.profile())
                .unwrap()
                .as_object()
                .unwrap()
                .contains_key("stance_support_mode_id")
        );
        assert_eq!(
            crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID
        );
    }

    #[test]
    fn v33_zero_amplitude_and_first_command_hold_neutral_references() {
        let (source, policy) = pair();
        for amplitude in [0.0, 0.5994550408719347] {
            let mut request = command(1);
            request.gait_amplitude = amplitude;
            let first = policy.step(
                &policy.initial_memory(),
                &rolled(&source, 1, 0.15),
                &request,
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
            assert!(receipt.first_step_holds_neutral_reference);
            assert_eq!(receipt.reference_step_duration_s, 0.0);
            if amplitude == 0.0 {
                assert!(
                    receipt
                        .ordered_limb_proposals
                        .iter()
                        .all(|p| p.goal_hip_rad == 0.0 && p.goal_knee_rad == 0.0)
                );
            }
        }
    }

    #[test]
    fn v33_plane_projection_retains_joint_limits_and_nonzero_residual() {
        let (source, policy) = pair();
        for roll in [-0.25, -0.1, 0.0, 0.1, 0.25] {
            let mut request = command(1);
            request.gait_amplitude = 0.3;
            let output = policy.step(
                &policy.initial_memory(),
                &rolled(&source, 1, roll),
                &request,
            );
            assert!(
                !output.actuation.safe_no_actuation,
                "{:?}",
                output.actuation.failure_codes
            );
            let receipt = output.actuation.receipt.recovery_support_plane.unwrap();
            let geometry = &source.compiled().geometry;
            for p in &receipt.ordered_limb_proposals {
                assert!((0.0..=1.1).contains(&p.projected_support_knee_rad));
                assert!((-0.72..=0.72).contains(&p.projected_support_hip_rad));
                let side = if p.limb_id.ends_with("left") {
                    geometry.left_hip_z_m
                } else {
                    geometry.right_hip_z_m
                };
                let h = p.projected_support_hip_rad;
                let k = p.projected_support_knee_rad;
                // Independent sagittal FK under a known anatomical roll.
                let actual_bottom = receipt.proposed_torso_height_m
                    - side * roll.sin()
                    - roll.cos()
                        * (geometry.upper_length_m * h.cos()
                            + geometry.lower_length_m * (h + k).cos())
                    - geometry.foot_radius_m;
                assert!(
                    (actual_bottom - p.projected_support_nominal_plane_residual_m).abs() < 1e-14
                );
                if !p.support_joint_projection_required {
                    assert!(actual_bottom.abs() < 1e-14);
                }
            }
            if roll.abs() == 0.25 {
                assert!(!receipt.unrestricted_plane_inside_joint_limits);
                assert!(
                    receipt
                        .ordered_limb_proposals
                        .iter()
                        .any(|p| p.projected_support_nominal_plane_residual_m.abs() > 0.001)
                );
            }
            assert!(!receipt.all_limb_contact_claim && !receipt.physical_acceptance_authority);
        }
    }

    #[test]
    fn v33_consecutive_serialized_replay_bounds_startup_phase_and_contact_changes() {
        let (source, policy) = pair();
        let mut memory = policy.initial_memory();
        for limb in &mut memory.ordered_limb_memory {
            limb.gait_step = 90;
        }
        let mut limited = 0;
        for step in 1..=800 {
            let mut observation = rolled(&source, step, 0.15 * (step as f64 / 29.0).sin());
            for (index, contact) in observation
                .ordered_contact_observations
                .iter_mut()
                .enumerate()
            {
                let bearing = (step + index as u64 * 37) % 53 < 31;
                contact.presence = Some(bearing);
                contact.bears_support = Some(bearing);
            }
            let mut request = command(step);
            request.gait_amplitude =
                0.5994550408719347 * smoothstep(((step - 1) as f64 / 72.0).min(1.0));
            let output = policy.step(&memory, &observation, &request);
            assert!(
                !output.actuation.safe_no_actuation,
                "step={step} {:?}",
                output.actuation.receipt.controller_error
            );
            let cold_memory =
                serde_json::from_str(&serde_json::to_string(&memory).unwrap()).unwrap();
            let cold_state =
                serde_json::from_str(&serde_json::to_string(&observation).unwrap()).unwrap();
            let cold_command =
                serde_json::from_str(&serde_json::to_string(&request).unwrap()).unwrap();
            assert_eq!(
                output,
                policy.step(&cold_memory, &cold_state, &cold_command)
            );
            let old = memory.support_reference.as_ref().unwrap();
            let receipt = output
                .actuation
                .receipt
                .recovery_support_plane
                .as_ref()
                .unwrap();
            for (index, c) in output.actuation.ordered_commands.iter().enumerate() {
                let spec = &source.compiled().morphology.morphology_spec.actuators[index];
                assert!(c.requested_target_position_rad >= spec.minimum_target_position_rad);
                assert!(c.requested_target_position_rad <= spec.maximum_target_position_rad);
                assert!(!c.position_saturated);
                assert!(
                    (c.requested_target_position_rad - old.ordered_target_positions_rad[index])
                        .abs()
                        <= c.maximum_target_speed_rad_s * receipt.reference_step_duration_s + 1e-14
                );
                assert_eq!(
                    c.target_velocity_rad_s,
                    (MOTOR_POSITION_GAIN_PER_S * c.requested_target_position_rad)
                        .clamp(-c.maximum_target_speed_rad_s, c.maximum_target_speed_rad_s)
                        * MOTOR_DIRECTION_SIGN
                );
                limited += usize::from(c.slew_limited);
            }
            memory = output.next_memory;
        }
        assert!(limited > 0);
        assert!(memory.ordered_limb_memory.iter().any(|m| m.gait_step > 450));
    }

    #[test]
    fn v33_preserves_v32_scheduler_for_the_same_inputs() {
        let (source, policy) = pair();
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID,
        )
        .unwrap();
        let mut new_memory = policy.initial_memory();
        let mut old_memory = old.initial_memory();
        for step in 1..=500 {
            let mut observation = rolled(&source, step, 0.0);
            for contact in &mut observation.ordered_contact_observations {
                contact.presence = Some(false);
                contact.bears_support = Some(false);
            }
            let old_output = old.step(&old_memory, &observation, &command(step));
            let new_output = policy.step(&new_memory, &observation, &command(step));
            assert!(
                !old_output.actuation.safe_no_actuation && !new_output.actuation.safe_no_actuation
            );
            assert_eq!(
                old_output.next_memory.ordered_limb_memory,
                new_output.next_memory.ordered_limb_memory
            );
            assert_eq!(
                old_output.next_memory.held_path_steering_fraction,
                new_output.next_memory.held_path_steering_fraction
            );
            old_memory = old_output.next_memory;
            new_memory = new_output.next_memory;
        }
    }

    #[test]
    fn v33_corrupt_reference_and_cross_policy_memory_refuse_without_advancing() {
        let (source, policy) = pair();
        let observation = rolled(&source, 1, 0.0);
        let clean = policy.initial_memory();
        let mut variants = Vec::new();
        let mut bad = clean.clone();
        bad.support_reference = None;
        variants.push(bad);
        let mut bad = clean.clone();
        bad.support_reference
            .as_mut()
            .unwrap()
            .ordered_target_positions_rad
            .pop();
        variants.push(bad);
        let mut bad = clean.clone();
        bad.support_reference
            .as_mut()
            .unwrap()
            .ordered_target_positions_rad[0] = 1.0;
        variants.push(bad);
        let mut bad = clean.clone();
        bad.support_reference
            .as_mut()
            .unwrap()
            .previous_sample_time_s = Some(0.0);
        variants.push(bad);
        for memory in variants {
            let refused = policy.step(&memory, &observation, &command(1));
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
        let old = BalancedWaveController::new_for_policy(
            source.compiled().clone(),
            BALANCED_WAVE_BW5R_B_POLICY_ID,
        )
        .unwrap();
        assert!(
            old.step(&clean, &observation, &command(1))
                .actuation
                .safe_no_actuation
        );
        let first = policy.step(&clean, &observation, &command(1));
        let mut clock_bad = rolled(&source, 2, 0.0);
        clock_bad.sample_time_s = observation.sample_time_s;
        let refused = policy.step(&first.next_memory, &clock_bad, &command(2));
        assert!(refused.actuation.safe_no_actuation);
        assert_eq!(refused.next_memory, first.next_memory);
    }

    #[test]
    fn v33_invalid_pose_or_observation_refuses_without_a_new_reference() {
        let (source, policy) = pair();
        let clean = policy.initial_memory();
        let inverted = rolled(&source, 1, std::f64::consts::PI);
        let output = policy.step(&clean, &inverted, &command(1));
        assert!(output.actuation.safe_no_actuation);
        assert_eq!(output.next_memory, clean);
        let mut absent = rolled(&source, 1, 0.0);
        absent.ordered_joint_observations[0].position_rad = None;
        let output = policy.step(&clean, &absent, &command(1));
        assert!(output.actuation.safe_no_actuation);
        assert_eq!(output.next_memory, clean);
    }
}
