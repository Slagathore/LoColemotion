mod recovery_extended_preparation {
    use super::*;
    use crate::recovery_extended_preparation::{self as v56, PreparationBudget};
    use crate::recovery_extended_support_transfer::ReferenceRange;
    use crate::recovery_measured_support_transfer as transfer;

    // Synthetic body measurements exercise policy bounds, not future motion.
    fn decide(extended: bool, memory: &transfer::Memory, ready: bool,
        missing_support: Option<usize>) -> Result<transfer::Receipt> {
        let source = controller();
        let (mut s, frame) = super::recovery_measured_support_transfer::input(&source, 2, ready);
        if let Some(index) = missing_support {
            s.ordered_contact_observations[index].presence = Some(false);
            s.ordered_contact_observations[index].bears_support = Some(false);
        }
        let mut before = Candidate35ControllerMemory::initial();
        before.last_semantic_step = Some(1);
        for limb in &mut before.ordered_limb_memory { limb.gait_step = 90; }
        let mut after = before.clone();
        for limb in &mut after.ordered_limb_memory { limb.gait_step += 1; }
        let guard = crate::recovery_support_progression::decide(
            &crate::recovery_support_progression::Memory::default(), &before, &after, &s, true)?;
        let run = if extended { transfer::decide_extended_preparation }
            else { transfer::decide_extended_remaining_support };
        run(memory, &before, &after, &s, transfer::measure(source.compiled(), &s, &frame)?,
            true, 1.0/120.0, 0.35, guard)
    }

    #[test]
    fn v56_memory_bound_is_distinct_finite_and_never_initializes_a_used_counter() {
        for count in [0, 239, 240, 241, 359, 360, 361, u32::MAX] {
            let memory = transfer::Memory { preparation_commands: count, ..Default::default() };
            assert_eq!(count <= 240, memory.validate_range(false, ReferenceRange::Extended).is_ok());
            assert_eq!(count <= 360, memory.validate_range_and_preparation(false,
                ReferenceRange::Extended, PreparationBudget::Extended).is_ok());
            assert_eq!(count == 0, memory.validate_range_and_preparation(true,
                ReferenceRange::Extended, PreparationBudget::Extended).is_ok());
        }
        for (bias, count, dwell) in [(0.3000001, 1, 0), (f64::NAN, 1, 0),
            (0.0, 5, 6), (0.0, 3, 4), (0.0, 361, 0)] {
            let memory = transfer::Memory { hip_bias_rad: bias,
                preparation_commands: count, ready_dwell_commands: dwell, ..Default::default() };
            assert!(memory.validate_range_and_preparation(false, ReferenceRange::Extended,
                PreparationBudget::Extended).is_err());
        }
        assert_eq!(None, PreparationBudget::Original.receipt_bound());
        assert_eq!(Some(360), PreparationBudget::Extended.receipt_bound());
    }

    #[test]
    fn v56_preserves_all_original_preparation_commands_then_refuses_at_its_own_bound() {
        let mut memory = transfer::Memory::default();
        for count in 1..=360 {
            let result = decide(true, &memory, false, None).unwrap();
            assert_eq!(Some(360), result.maximum_preparation_commands);
            assert_eq!(count, result.next_memory.preparation_commands);
            assert!(result.preparation_held && !result.preparation_released_this_command);
            assert_eq!(0, result.next_memory.ready_dwell_commands);
            assert!(result.next_memory.hip_bias_rad.abs() <= 0.30);
            assert!(result.applied_hip_bias_rate_rad_s.abs() <= 0.60 + 1e-14);
            if count <= 240 {
                let old = decide(false, &memory, false, None).unwrap();
                let mut without_additive_bound = result.clone();
                without_additive_bound.maximum_preparation_commands = None;
                assert_eq!(serde_json::to_vec(&old).unwrap(),
                    serde_json::to_vec(&without_additive_bound).unwrap());
            } else {
                assert!(decide(false, &memory, false, None).is_err());
            }
            memory = result.next_memory;
        }
        let saved = memory.clone();
        assert!(decide(true, &memory, false, None).unwrap_err().to_string().contains("preparation_timeout"));
        assert_eq!(saved, memory);
    }

    #[test]
    fn v56_boundary_release_requires_the_original_six_ready_samples_and_supports() {
        for count in [240, 241, 359, 360] {
            let memory = transfer::Memory { preparation_commands: count,
                ready_dwell_commands: 5, ..Default::default() };
            let result = decide(true, &memory, true, None).unwrap();
            assert!(result.preparation_released_this_command && !result.preparation_held);
            assert_eq!(0, result.next_memory.preparation_commands);
            assert_eq!(0, result.next_memory.ready_dwell_commands);
            assert_eq!(Some("front_left"), result.next_memory.prepared_limb_id.as_deref());
            assert_eq!(Some(90), result.next_memory.prepared_swing_start_gait_step);
            if count == 240 {
                assert!(decide(false, &memory, true, None).unwrap().preparation_released_this_command);
            }
            for missing in 1..4 {
                let observed = decide(true, &memory, true, Some(missing));
                if count == 360 { assert!(observed.is_err()); }
                else {
                    let held = observed.unwrap();
                    assert!(!held.readiness_conditions_met && !held.preparation_released_this_command);
                    assert_eq!(0, held.next_memory.ready_dwell_commands);
                }
            }
        }
        let incomplete = transfer::Memory { preparation_commands: 360,
            ready_dwell_commands: 4, ..Default::default() };
        assert!(decide(true, &incomplete, true, None).unwrap_err().to_string().contains("preparation_timeout"));
    }

    #[test]
    fn v56_public_policy_profile_and_memory_keep_v55_configuration_and_refuse_crossed_memory() {
        let source = controller();
        let old = BalancedWaveController::new_for_policy(source.compiled().clone(),
            crate::recovery_initialized_zero_brake::POLICY).unwrap();
        let new = BalancedWaveController::new_for_policy(source.compiled().clone(), v56::POLICY).unwrap();
        let mut old_profile = serde_json::to_value(old.profile()).unwrap();
        let mut new_profile = serde_json::to_value(new.profile()).unwrap();
        for key in ["schema_version", "policy_id"] {
            old_profile.as_object_mut().unwrap().remove(key);
            new_profile.as_object_mut().unwrap().remove(key);
        }
        assert_eq!(old_profile, new_profile);
        let old_memory = old.initial_memory();
        let mut new_memory = new.initial_memory();
        assert_eq!(v56::MEMORY, new_memory.schema_version);
        new_memory.schema_version = old_memory.schema_version.clone();
        assert_eq!(old_memory, new_memory);
        let (s, frame) = super::recovery_measured_support_transfer::input(&source, 1, true);
        let floor = crate::recovery_floor_reference::FloorReference {
            schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: crate::recovery_floor_reference::FRAME_ID.to_owned(), surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_v56".to_owned(), source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)), height_world_m: 0.0,
        };
        for (policy, memory) in [(&new, old_memory), (&old, new.initial_memory())] {
            let out = policy.step_with_measured_body(&memory, &s, &command(1), Some(&floor), Some(&frame));
            assert!(out.actuation.safe_no_actuation);
            assert_eq!(memory, out.next_memory);
            assert!(out.actuation.ordered_commands.iter().all(|c| c.target_velocity_rad_s == 0.0));
        }
    }
}
