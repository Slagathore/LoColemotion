mod recovery_support_progression {
    use super::*;
    use crate::recovery_support_progression as guard;
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller,BalancedWaveController,BalancedWaveController,FloorReference) {
        let source=controller();
        let new=BalancedWaveController::new_for_policy(source.compiled().clone(),guard::POLICY).unwrap();
        let old=BalancedWaveController::new_for_policy(source.compiled().clone(),crate::controller::BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id:FRAME_ID.to_owned(),surface_id:"floor".to_owned(),source_instance_id:"synthetic_v43".to_owned(),
            source_kind:"declared_static_horizontal_surface".to_owned(),geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};
        (source,new,old,floor)
    }
    fn at(clock:u64) -> Candidate35ControllerMemory {
        let mut m=Candidate35ControllerMemory::initial();m.last_semantic_step=Some(1);
        for l in &mut m.ordered_limb_memory {l.gait_step=clock;}
        m
    }
    fn absent(s:&mut StateFrame,limb:&str) {
        let c=s.ordered_contact_observations.iter_mut().find(|c|c.contact_site_id==format!("{limb}_foot")).unwrap();
        c.presence=Some(false);c.bears_support=Some(false);
    }

    #[test]
    fn v43_profile_identity_phase_wrap_and_truthful_support() {
        let (source,new,old,_)=setup();let mut p=old.profile().clone();
        p.policy_id=guard::POLICY.to_owned();p.schema_version=guard::PROFILE.to_owned();p.support_progression_mode_id=Some(guard::MODE.to_owned());
        assert_eq!(&p,new.profile());
        let mut m=old.initial_memory();m.schema_version=guard::MEMORY.to_owned();m.support_progression=Some(guard::Memory::default());
        assert_eq!(m,new.initial_memory());
        for clock in [0,53,54,71,72,73,88,89,90,161,162,163,358,359,360,449] {
            for missing in ["front_left","front_right","rear_left","rear_right"] {
                let mut input=state(&source,2);absent(&mut input,missing);let preserved=input.clone();
                let r=guard::decide(&guard::Memory::default(),&at(clock),&at(clock+1),&input,true).unwrap();
                let swing=r.ordered_limbs.iter().any(|l|l.incoming_phase<=72 || l.proposed_phase<=72);
                let required=r.ordered_limbs.iter().find(|l|l.limb_id==missing).unwrap().proposed_phase>72;
                assert_eq!(swing && required,r.phase_progression_held);assert_eq!(preserved,input);
                for l in r.ordered_limbs {assert_eq!(l.selected_phase,if swing && required {l.incoming_phase}else{l.proposed_phase});}
            }
        }
        let mut input=state(&source,2);absent(&mut input,"front_right");
        let r=guard::decide(&guard::Memory::default(),&at(89),&at(90),&input,true).unwrap();
        assert_eq!((359,0,359),(r.ordered_limbs[0].incoming_phase,r.ordered_limbs[0].proposed_phase,r.ordered_limbs[0].selected_phase));
        input.ordered_contact_observations[1].presence=Some(true);
        assert!(guard::decide(&guard::Memory::default(),&at(89),&at(90),&input,true).unwrap().phase_progression_held);
    }

    #[test]
    fn v43_hold_clear_dwell_interrupt_disable_and_finite_timeout() {
        let (source,_,_,_)=setup();let ready=state(&source,2);let mut lost=ready.clone();absent(&mut lost,"front_right");
        let mut m=guard::Memory::default();
        for n in 1..=120 {
            let r=guard::decide(&m,&at(90),&at(91),&lost,true).unwrap();
            assert!(r.phase_progression_held);assert_eq!(n,r.next_memory.held_steps);m=r.next_memory;
        }
        assert!(guard::decide(&m,&at(90),&at(91),&lost,true).unwrap_err().to_string().contains("hold_timeout"));
        assert_eq!(guard::Memory::default(),guard::decide(&m,&at(90),&at(91),&lost,false).unwrap().next_memory);
        m=guard::Memory {held_steps:1,clear_dwell_steps:0};
        for clear in 1..=2 {
            let r=guard::decide(&m,&at(90),&at(91),&ready,true).unwrap();
            assert!(r.phase_progression_held);assert_eq!(clear,r.next_memory.clear_dwell_steps);m=r.next_memory;
        }
        let interrupted=guard::decide(&m,&at(90),&at(91),&lost,true).unwrap();assert_eq!(0,interrupted.next_memory.clear_dwell_steps);
        let released=guard::decide(&m,&at(90),&at(91),&ready,true).unwrap();
        assert!(!released.phase_progression_held);assert_eq!(guard::Memory::default(),released.next_memory);
        let limit_release=guard::Memory {held_steps:120,clear_dwell_steps:2};
        assert!(!guard::decide(&limit_release,&at(90),&at(91),&ready,true).unwrap().phase_progression_held);
    }

    #[test]
    fn v43_native_holds_commands_continue_and_three_clear_samples_release() {
        let (source,new,_,floor)=setup();let mut memory=new.initial_memory();
        for l in &mut memory.ordered_limb_memory {l.gait_step=89;}
        for n in 1..=6 {
            let mut s=state(&source,n);s.base_pose_world.position_m.y=0.37;
            if n==2 {absent(&mut s,"front_right");}
            let before=memory.clone();let out=new.step_with_floor(&memory,&s,&command(n),Some(&floor));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);
            let r=out.actuation.receipt.recovery_support_plane.as_ref().unwrap().support_progression.as_ref().unwrap();
            assert_eq!((2..=4).contains(&n),r.phase_progression_held);
            assert_eq!(guard::RECEIPT,out.actuation.receipt.schema_version);
            assert_eq!(digest_serializable(&out.actuation.receipt).unwrap(),out.actuation.receipt_sha256);
            assert_eq!(Some(r.next_memory.clone()),out.next_memory.support_progression);
            if r.phase_progression_held {
                assert_eq!(before.ordered_limb_memory,out.next_memory.ordered_limb_memory);
                assert!(out.actuation.ordered_commands.iter().any(|c|c.target_velocity_rad_s!=0.0));
            }
            assert_eq!(Some(n),out.next_memory.last_semantic_step);
            for c in &out.actuation.ordered_commands {assert!(c.target_velocity_rad_s.abs()<=c.maximum_target_speed_rad_s);}
            memory=serde_json::from_str(&serde_json::to_string(&out.next_memory).unwrap()).unwrap();
        }
        assert!(memory.ordered_limb_memory.iter().all(|l|l.gait_step==91));
    }

    #[test]
    fn v43_nonheld_parent_commands_and_gate_memory_remain_exact() {
        let (source,new,old,floor)=setup();let mut m=new.initial_memory();
        for l in &mut m.ordered_limb_memory {l.gait_step=90;}
        for n in 1..=400 {
            let mut s=state(&source,n);s.base_pose_world.position_m.y=0.37;
            for (index,l) in m.ordered_limb_memory.iter().enumerate() {
                let phase=(l.gait_step+360-index as u64*90)%360;
                if (1..70).contains(&phase) {absent(&mut s,&l.limb_id);}
            }
            let mut parent=m.clone();parent.schema_version=BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION.to_owned();parent.support_progression=None;
            let a=new.step_with_floor(&m,&s,&command(n),Some(&floor));let b=old.step_with_floor(&parent,&s,&command(n),Some(&floor));
            assert!(!a.actuation.safe_no_actuation && !b.actuation.safe_no_actuation);
            let r=a.actuation.receipt.recovery_support_plane.as_ref().unwrap().support_progression.as_ref().unwrap();
            assert!(!r.phase_progression_held);assert_eq!(a.actuation.ordered_commands,b.actuation.ordered_commands);
            let mut expected=b.next_memory;expected.schema_version=guard::MEMORY.to_owned();expected.support_progression=Some(r.next_memory.clone());
            assert_eq!(a.next_memory,expected);m=a.next_memory;
        }
    }

    #[test]
    fn v43_missing_crossed_malformed_memory_and_timeout_refuse() {
        let (source,new,old,floor)=setup();let mut initial=new.initial_memory();
        for l in &mut initial.ordered_limb_memory {l.gait_step=89;}
        let memory=new.step_with_floor(&initial,&state(&source,1),&command(1),Some(&floor)).next_memory;
        for kind in 0..6 {
            let mut bad=memory.clone();let mut s=state(&source,2);
            match kind {
                0=>bad.support_progression=None,
                1=>bad.support_progression.as_mut().unwrap().held_steps=121,
                2=>bad.support_progression.as_mut().unwrap().clear_dwell_steps=3,
                3=>bad.support_progression.as_mut().unwrap().clear_dwell_steps=1,
                4=>{bad.support_progression.as_mut().unwrap().held_steps=120;absent(&mut s,"front_right");},
                _=>s.ordered_contact_observations[0].presence=None,
            }
            let out=new.step_with_floor(&bad,&s,&command(2),Some(&floor));
            assert!(out.actuation.safe_no_actuation,"kind {kind}");assert_eq!(bad,out.next_memory);
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
        let mut crossed=memory.clone();crossed.schema_version=BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION.to_owned();
        assert!(old.step_with_floor(&crossed,&state(&source,2),&command(2),Some(&floor)).actuation.safe_no_actuation);
        for value in [serde_json::json!(-1),serde_json::json!(1.5),serde_json::json!("1")] {
            let mut raw=serde_json::to_value(&memory).unwrap();raw["support_progression"]["held_steps"]=value;
            assert!(serde_json::from_value::<BalancedWaveControllerMemory>(raw).is_err());
        }
    }
}
