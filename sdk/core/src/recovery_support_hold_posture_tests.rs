mod recovery_support_hold_posture {
    use super::*;
    use crate::recovery_support_hold_posture as posture;
    use crate::recovery_support_progression as guard;
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source=controller();
        let new=BalancedWaveController::new_for_policy(source.compiled().clone(),posture::POLICY).unwrap();
        let old=BalancedWaveController::new_for_policy(source.compiled().clone(),guard::POLICY).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id:FRAME_ID.to_owned(),surface_id:"floor".to_owned(),source_instance_id:"synthetic_v44".to_owned(),
            source_kind:"declared_static_horizontal_surface".to_owned(),geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};
        (source,new,old,floor)
    }
    fn input(source:&Candidate35Controller,n:u64,lost:bool) -> StateFrame {
        let mut s=state(source,n);s.base_pose_world.position_m.y=0.37;
        if lost {
            let c=s.ordered_contact_observations.iter_mut().find(|c|c.contact_site_id=="rear_right_foot").unwrap();
            c.presence=Some(false);c.bears_support=Some(false);
        }
        s
    }
    fn parent(memory:&BalancedWaveControllerMemory) -> BalancedWaveControllerMemory {
        let mut m=memory.clone();m.schema_version=guard::MEMORY.to_owned();m
    }
    fn initial(new:&BalancedWaveController,source:&Candidate35Controller,floor:&FloorReference) -> BalancedWaveControllerMemory {
        let mut m=new.initial_memory();for l in &mut m.ordered_limb_memory {l.gait_step=122;}
        new.step_with_floor(&m,&input(source,1,false),&command(1),Some(floor)).next_memory
    }

    #[test]
    fn v44_profile_inherits_every_limit_and_initial_memory() {
        let (_,new,old,_)=setup();let mut p=old.profile().clone();
        p.schema_version=posture::PROFILE.to_owned();p.policy_id=posture::POLICY.to_owned();
        p.support_hold_posture_mode_id=Some(posture::MODE.to_owned());assert_eq!(&p,new.profile());
        assert_eq!(parent(&new.initial_memory()),old.initial_memory());
    }

    #[test]
    fn v44_held_swing_uses_support_goals_without_changing_contacts_clocks_or_latches() {
        let (source,new,old,floor)=setup();let m=initial(&new,&source,&floor);
        let s=input(&source,2,true);let saved=s.clone();
        let a=new.step_with_floor(&m,&s,&command(2),Some(&floor));
        let b=old.step_with_floor(&parent(&m),&s,&command(2),Some(&floor));
        assert!(!a.actuation.safe_no_actuation && !b.actuation.safe_no_actuation);
        let r=a.actuation.receipt.recovery_support_plane.as_ref().unwrap();
        let prior=b.actuation.receipt.recovery_support_plane.as_ref().unwrap();
        assert!(r.support_hold_posture.as_ref().unwrap().enabled);
        assert_eq!(r.support_progression,prior.support_progression);
        assert_eq!(r.stance_latch,prior.stance_latch);
        assert_eq!(m.ordered_limb_memory,a.next_memory.ordered_limb_memory);
        assert_eq!(a.next_memory.support_reference.as_ref().unwrap().previous_wave,b.next_memory.support_reference.as_ref().unwrap().previous_wave);
        assert!(r.upright_stance.as_ref().unwrap().ordered_limbs.iter().all(|l|l.upright_reference_selected));
        for p in &r.ordered_limb_proposals {
            assert_eq!(0.0,p.walking_knee_fraction);
            assert_eq!(p.goal_hip_rad,p.projected_support_hip_rad);
            assert_eq!(p.goal_knee_rad,p.projected_support_knee_rad);
        }
        assert_ne!(r.ordered_limb_proposals[0].goal_knee_rad,prior.ordered_limb_proposals[0].goal_knee_rad);
        // Both different goals initially hit the same existing slew bound.
        // A target-geometry change need not change the very first command.
        assert_eq!(a.actuation.ordered_commands,b.actuation.ordered_commands);
        assert_eq!(saved,s);assert_eq!(posture::RECEIPT,a.actuation.receipt.schema_version);
        assert_eq!(digest_serializable(&a.actuation.receipt).unwrap(),a.actuation.receipt_sha256);
    }

    #[test]
    fn v44_nonheld_parent_outputs_are_exact_for_a_full_synthetic_cycle() {
        let (source,new,old,floor)=setup();let mut m=initial(&new,&source,&floor);
        for n in 2..=401 {
            let s=input(&source,n,false);
            let a=new.step_with_floor(&m,&s,&command(n),Some(&floor));
            let b=old.step_with_floor(&parent(&m),&s,&command(n),Some(&floor));
            assert!(!a.actuation.safe_no_actuation && !b.actuation.safe_no_actuation);
            assert!(!a.actuation.receipt.recovery_support_plane.as_ref().unwrap().support_hold_posture.as_ref().unwrap().enabled);
            assert_eq!(a.actuation.ordered_commands,b.actuation.ordered_commands);
            assert_eq!(parent(&a.next_memory),b.next_memory);m=a.next_memory;
        }
    }

    #[test]
    fn v44_entry_clear_dwell_release_and_reentry_preserve_slew_and_memory() {
        let (source,new,old,floor)=setup();let mut m=initial(&new,&source,&floor);
        for n in 2..=12 {
            let lost=matches!(n,2|3|7|8);let s=input(&source,n,lost);
            let a=new.step_with_floor(&m,&s,&command(n),Some(&floor));
            let b=old.step_with_floor(&parent(&m),&s,&command(n),Some(&floor));
            assert!(!a.actuation.safe_no_actuation);
            let r=a.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            assert_eq!(r.support_progression,b.actuation.receipt.recovery_support_plane.as_ref().unwrap().support_progression);
            assert_eq!((2..=5).contains(&n)||(7..=10).contains(&n),r.support_hold_posture.as_ref().unwrap().enabled);
            for (i,c) in a.actuation.ordered_commands.iter().enumerate() {
                let before=m.support_reference.as_ref().unwrap().ordered_target_positions_rad[i];
                assert!((c.requested_target_position_rad-before).abs()<=c.maximum_target_speed_rad_s*r.reference_step_duration_s+1e-14);
                assert!(c.target_velocity_rad_s.abs()<=c.maximum_target_speed_rad_s);
            }
            m=serde_json::from_value(serde_json::to_value(a.next_memory).unwrap()).unwrap();
        }
    }

    #[test]
    fn v44_missing_invalid_crossed_and_timeout_inputs_still_refuse() {
        let (source,new,old,floor)=setup();let m=initial(&new,&source,&floor);
        for kind in 0..8 {
            let mut memory=m.clone();let mut s=input(&source,2,true);let mut plane=floor.clone();
            match kind {
                0=>memory.support_progression=None,
                1=>memory.support_progression.as_mut().unwrap().held_steps=121,
                2=>memory.support_progression.as_mut().unwrap().held_steps=120,
                3=>memory.support_progression.as_mut().unwrap().clear_dwell_steps=3,
                4=>memory.schema_version=guard::MEMORY.to_owned(),
                5=>s.ordered_contact_observations[0].presence=None,
                6=>{s.ordered_contact_observations[0].presence=Some(false);s.ordered_contact_observations[0].bears_support=Some(true);},
                _=>plane.source_instance_id="crossed".to_owned(),
            }
            let a=new.step_with_floor(&memory,&s,&command(2),Some(&plane));
            assert!(a.actuation.safe_no_actuation,"kind {kind}");assert_eq!(memory,a.next_memory);
            assert!(a.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
        assert!(old.step_with_floor(&m,&input(&source,2,true),&command(2),Some(&floor)).actuation.safe_no_actuation);
    }
}
