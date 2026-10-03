// Native, zero-world sequencing controls for the distinct recovery policy.
mod recovery_swing_end_recontact {
    use super::*;

    fn pair() -> (
        Candidate35Controller,
        BalancedWaveController,
        BalancedWaveController,
    ) {
        let reference = controller();
        let old = BalancedWaveController::new_for_policy(
            reference.compiled().clone(),
            BALANCED_WAVE_BW5R_B_POLICY_ID,
        )
        .unwrap();
        let new = BalancedWaveController::new_for_policy(
            reference.compiled().clone(),
            BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID,
        )
        .unwrap();
        (reference, old, new)
    }

    fn at(clock: u64) -> BalancedWaveControllerMemory {
        let mut memory = BalancedWaveControllerMemory::initial();
        memory.last_semantic_step = Some(0);
        memory.phase_progression_mode = Some(PhaseProgressionMode::ContactGated);
        for limb in &mut memory.ordered_limb_memory {
            limb.gait_step = clock;
        }
        memory
    }

    fn absent_front_left(current: &mut StateFrame) {
        let contact = current
            .ordered_contact_observations
            .iter_mut()
            .find(|c| c.contact_site_id == "front_left_foot")
            .unwrap();
        contact.presence = Some(false);
        contact.bears_support = Some(false);
    }

    #[test]
    fn v32_distinct_profile_changes_only_identity_and_recontact_mode() {
        let (reference, old, new) = pair();
        let mut expected = old.profile().clone();
        expected.schema_version =
            crate::controller::BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_PROFILE_VERSION
                .to_owned();
        expected.policy_id = BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID.to_owned();
        expected.recontact_gate_mode_id = Some(SCHEDULED_SWING_END_RECONTACT_MODE_ID.to_owned());
        assert_eq!(&expected, new.profile());
        assert!(
            !serde_json::to_value(old.profile())
                .unwrap()
                .as_object()
                .unwrap()
                .contains_key("recontact_gate_mode_id")
        );
        assert_eq!(old.engine.profile.recontact_gate_local_step, 144);
        assert_eq!(new.engine.profile.recontact_gate_local_step, SWING_STEPS);
        assert_eq!(SWING_STEPS + MAXIMUM_PHASE_SKEW_STEPS, 84);
        assert!(SWING_STEPS + MAXIMUM_PHASE_SKEW_STEPS < CYCLE_STEPS / 4);
        assert_eq!(
            crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,
            BALANCED_WAVE_BW5R_B_POLICY_ID
        );
        assert!(
            BalancedWaveController::new_for_policy(
                reference.compiled().clone(),
                "unregistered_recontact_policy"
            )
            .is_err()
        );
    }

    #[test]
    fn v32_holds_at_swing_end_and_keeps_following_limb_before_swing_until_timeout() {
        let (reference, old, new) = pair();
        let mut memory = at(90 + SWING_STEPS);
        let mut first = state(&reference, 1);
        absent_front_left(&mut first);
        let prior = old.step(&memory, &first, &command(1));
        assert_eq!(prior.next_memory.ordered_limb_memory[1].gait_step, 163);
        for step in 1..=u64::from(MAXIMUM_GATE_HOLD_STEPS) {
            let mut current = state(&reference, step);
            absent_front_left(&mut current);
            let output = new.step(&memory, &current, &command(step));
            assert!(!output.actuation.safe_no_actuation);
            memory = output.next_memory;
            assert_eq!(memory.ordered_limb_memory[1].gait_step, 162);
            assert_eq!(memory.ordered_limb_memory[1].gate_timeout_count, 0);
            // Existing skew control caps the follower at clock 174, six
            // increments before its swing begins at 180. No physics claim.
            assert!(memory.ordered_limb_memory[2].gait_step <= 174);
        }
        assert_eq!(memory.ordered_limb_memory[1].recontact_hold_step_count, 120);
        let mut current = state(&reference, 121);
        absent_front_left(&mut current);
        let timed_out = new.step(&memory, &current, &command(121));
        assert_eq!(
            timed_out.next_memory.ordered_limb_memory[1].gate_timeout_count,
            1
        );
        assert_eq!(timed_out.next_memory.ordered_limb_memory[1].gait_step, 163);
        // Timeout remains the original bounded escape, not an infinite wait.
    }

    #[test]
    fn v32_requires_consecutive_contact_dwell_and_keeps_refusals() {
        let (reference, _, new) = pair();
        let mut memory = at(162);
        for (step, bearing) in [
            (1, true),
            (2, true),
            (3, false),
            (4, true),
            (5, true),
            (6, true),
        ] {
            let mut current = state(&reference, step);
            if !bearing {
                absent_front_left(&mut current);
            }
            let output = new.step(&memory, &current, &command(step));
            assert!(!output.actuation.safe_no_actuation);
            memory = output.next_memory;
            assert_eq!(
                memory.ordered_limb_memory[1].gait_step,
                if step == 6 { 163 } else { 162 }
            );
        }
        assert_eq!(memory.ordered_limb_memory[1].gate_timeout_count, 0);
        let mut bad = state(&reference, 7);
        bad.ordered_contact_observations[0].bears_support = None;
        let refused = new.step(&memory, &bad, &command(7));
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
    fn v32_preserves_clocked_commands_and_all_gated_phases_outside_changed_checkpoints() {
        let (reference, old, new) = pair();
        for clock in 0..CYCLE_STEPS {
            for bearing in [true, false] {
                let mut current = state(&reference, 1);
                if !bearing {
                    for c in &mut current.ordered_contact_observations {
                        c.presence = Some(false);
                        c.bears_support = Some(false);
                    }
                }
                let mut memory = at(clock);
                for mode in [
                    PhaseProgressionMode::Clocked,
                    PhaseProgressionMode::ContactGated,
                ] {
                    memory.phase_progression_mode = Some(mode);
                    let mut request = command(1);
                    request.phase_progression_mode = mode;
                    let a = old.step(&memory, &current, &request);
                    let b = new.step(&memory, &current, &request);
                    assert!(!a.actuation.safe_no_actuation && !b.actuation.safe_no_actuation);
                    let changed_checkpoint = (0..4)
                        .any(|i| matches!((clock + CYCLE_STEPS - i * 90) % CYCLE_STEPS, 72 | 144));
                    if mode == PhaseProgressionMode::Clocked || !changed_checkpoint {
                        assert_eq!(a.next_memory, b.next_memory);
                        assert_eq!(a.actuation.ordered_commands, b.actuation.ordered_commands);
                    }
                }
            }
        }
    }
}
