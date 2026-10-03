mod recovery_stance_latch {
    use super::*;
    use crate::controller::{BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_STANCE_LATCH_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_STANCE_LATCH_PROFILE_VERSION as PROFILE,
        STANCE_LATCHED_UPRIGHT_MODE_ID as MODE};
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};
    use crate::recovery_support_plane::{stance_latch_selected, initial_stance_latches};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source = controller();
        let new = BalancedWaveController::new_for_policy(source.compiled().clone(), POLICY).unwrap();
        let old = BalancedWaveController::new_for_policy(source.compiled().clone(), PARENT).unwrap();
        let floor = FloorReference {schema_version: "sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id: FRAME_ID.to_owned(), surface_id: "floor".to_owned(),
            source_instance_id: "synthetic_v42_not_native_evidence".to_owned(),
            source_kind: "declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256: format!("sha256:{}", "1".repeat(64)), height_world_m: 0.0};
        (source,new,old,floor)
    }

    #[test]
    fn v42_distinct_identity_and_selector_lifecycle() {
        let (_,new,old,_) = setup();
        let mut profile=old.profile().clone(); profile.policy_id=POLICY.to_owned();
        profile.schema_version=PROFILE.to_owned();profile.reference_velocity_mode_id=Some(MODE.to_owned());
        assert_eq!(&profile,new.profile());
        let mut memory=old.initial_memory();memory.schema_version=BALANCED_WAVE_RECOVERY_STANCE_LATCH_MEMORY_VERSION.to_owned();
        memory.support_reference.as_mut().unwrap().ordered_stance_latches=Some(initial_stance_latches());
        assert_eq!(memory,new.initial_memory());
        for active in [false,true] {for phase in [0,72,73,74,359,360] {
            for prior_active in [false,true] {for prior_phase in [None,Some(0),Some(72),Some(73),Some(359)] {
                for latch in [false,true] {for presence in [None,Some(false),Some(true)] {for bearing in [None,Some(false),Some(true)] {
                    let carry=latch && prior_active && prior_phase.is_some_and(|p|p>72 && p<360 && phase>=p && phase<360);
                    let expected=active && phase>72 && phase<360 && presence.is_some() && bearing.is_some()
                        && !(presence==Some(false) && bearing==Some(true))
                        && (carry || (presence==Some(true) && bearing==Some(true)));
                    assert_eq!(expected,stance_latch_selected(active,phase,presence,bearing,prior_active,prior_phase,latch));
                }}}
            }}
        }}
        assert!(stance_latch_selected(true,74,Some(false),Some(false),true,Some(73),true));
        assert!(!stance_latch_selected(true,73,Some(false),Some(false),true,Some(359),true));
        assert!(!stance_latch_selected(true,74,Some(true),Some(false),true,Some(73),false));
    }

    #[test]
    fn v42_chained_inputs_preserve_contacts_upstream_memory_and_same_mask_commands() {
        let (source,new,old,floor)=setup();let mut memory=new.initial_memory();
        for limb in &mut memory.ordered_limb_memory {limb.gait_step=90;}
        let mut carried_absent=0;let mut differences=0;let mut inactive=0;
        for n in 1..=400 {
            let mut input=state(&source,n);input.base_pose_world.position_m.y=0.37+0.02*(n as f64/17.0).sin();
            input.base_pose_world.orientation_xyzw=Quaternion{x:0.06_f64.sin(),y:0.0,z:0.0,w:0.06_f64.cos()};
            for (i,c) in input.ordered_contact_observations.iter_mut().enumerate() {
                c.presence=Some((n+i as u64*19)%53<31);c.bears_support=c.presence;
            }
            let preserved=input.clone();let mut motion=command(n);
            motion.gait_amplitude=if n==1 || n==201 {0.0} else {0.4};
            let mut parent=memory.clone();parent.schema_version=BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION.to_owned();
            parent.support_reference.as_mut().unwrap().ordered_stance_latches=None;
            let out=new.step_with_floor(&memory,&input,&motion,Some(&floor));
            let before=old.step_with_floor(&parent,&input,&motion,Some(&floor));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);
            assert!(!before.actuation.safe_no_actuation);assert_eq!(input,preserved);
            let r=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            let u=r.upright_stance.as_ref().unwrap();let latch=r.stance_latch.as_ref().unwrap();
            let prior=before.actuation.receipt.recovery_support_plane.as_ref().unwrap().upright_stance.as_ref().unwrap();
            let wave=r.wave_velocity.as_ref().unwrap();
            let old_wave=before.actuation.receipt.recovery_support_plane.as_ref().unwrap().wave_velocity.as_ref().unwrap();
            // Reference comparison positions may differ; upstream wave inputs
            // and activation must not change as a side effect of the latch.
            assert_eq!(wave.previous_wave,old_wave.previous_wave);
            assert_eq!(wave.current_wave,old_wave.current_wave);
            assert_eq!(wave.feedforward_active,old_wave.feedforward_active);
            let mut expected=before.next_memory.clone();expected.schema_version=out.next_memory.schema_version.clone();
            expected.support_reference=out.next_memory.support_reference.clone();
            assert_eq!(expected,out.next_memory);
            assert_eq!(latch.source_semantic_step,input.semantic_step);
            for i in 0..4 {
                let l=&latch.ordered_limbs[i];let contact=&input.ordered_contact_observations[i];
                assert_eq!(&l.precommand_contact,contact);
                let chosen=stance_latch_selected(motion.gait_amplitude!=0.0,l.current_scheduled_phase_step,
                    contact.presence,contact.bears_support,l.previous_wave_active,l.previous_scheduled_phase_step,l.incoming_upright_reference_latched);
                assert_eq!(chosen,l.next_upright_reference_latched);
                assert_eq!(chosen,u.ordered_limbs[i].upright_reference_selected);
                assert_eq!(chosen,out.next_memory.support_reference.as_ref().unwrap().ordered_stance_latches.as_ref().unwrap()[i].upright_reference_latched);
                if chosen && contact.presence==Some(false) {carried_absent+=1;}
                if motion.gait_amplitude==0.0 {assert!(!chosen);inactive+=1;}
                for j in 2*i..2*i+2 {
                    let c=&out.actuation.ordered_commands[j];let b=&before.actuation.ordered_commands[j];
                    if chosen==prior.ordered_limbs[i].upright_reference_selected {assert_eq!(c,b);}
                    differences+=usize::from(c!=b);
                    assert!((c.requested_target_position_rad-memory.support_reference.as_ref().unwrap().ordered_target_positions_rad[j]).abs()
                        <=c.maximum_target_speed_rad_s*r.reference_step_duration_s+1e-14);
                    assert!(c.target_velocity_rad_s.abs()<=c.maximum_target_speed_rad_s);
                }
            }
            memory=serde_json::from_str(&serde_json::to_string(&out.next_memory).unwrap()).unwrap();
        }
        assert!(carried_absent>0 && differences>0 && inactive==8);
    }

    #[test]
    fn v42_missing_crossed_initial_and_malformed_latch_memory_refuses() {
        let (source,new,old,floor)=setup();
        let memory=new.step_with_floor(&new.initial_memory(),&state(&source,1),&command(1),Some(&floor)).next_memory;
        for variant in 0..8 {
            let mut bad=memory.clone();
            match variant {
                0=>bad.support_reference.as_mut().unwrap().ordered_stance_latches=None,
                1=>bad.support_reference.as_mut().unwrap().ordered_stance_latches=Some(vec![]),
                2=>bad.support_reference.as_mut().unwrap().ordered_stance_latches.as_mut().unwrap().swap(0,1),
                3=>bad.support_reference.as_mut().unwrap().ordered_stance_latches.as_mut().unwrap()[0].limb_id="other".to_owned(),
                4=>{bad.schema_version=BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION.to_owned();},
                5=>bad.support_reference.as_mut().unwrap().previous_wave=None,
                6=>bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].scheduled_phase_step=360,
                _=>{bad=new.initial_memory();bad.support_reference.as_mut().unwrap().ordered_stance_latches.as_mut().unwrap()[0].upright_reference_latched=true;},
            }
            let out=new.step_with_floor(&bad,&state(&source,2),&command(2),Some(&floor));
            assert!(out.actuation.safe_no_actuation,"variant {variant}");assert_eq!(out.next_memory,bad);
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
        let mut crossed=memory.clone();crossed.schema_version=BALANCED_WAVE_RECOVERY_UPRIGHT_STANCE_MEMORY_VERSION.to_owned();
        assert!(old.step_with_floor(&crossed,&state(&source,2),&command(2),Some(&floor)).actuation.safe_no_actuation);
        let mut value=serde_json::to_value(&memory).unwrap();
        value["support_reference"]["ordered_stance_latches"][0]["upright_reference_latched"]=serde_json::json!(1);
        assert!(serde_json::from_value::<BalancedWaveControllerMemory>(value).is_err());
    }
}
