mod recovery_airborne_reference {
    use super::*;
    use crate::controller::{BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_PROFILE_VERSION as PROFILE,
        CONTACT_SELECTED_AIRBORNE_REFERENCE_MODE_ID as MODE};
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source=controller();
        let new=BalancedWaveController::new_for_policy(source.compiled().clone(),POLICY).unwrap();
        let old=BalancedWaveController::new_for_policy(source.compiled().clone(),PARENT).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id:FRAME_ID.to_owned(),surface_id:"floor".to_owned(),source_instance_id:"synthetic_v39_not_native_evidence".to_owned(),
            source_kind:"declared_static_horizontal_surface".to_owned(),geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};
        (source,new,old,floor)
    }

    #[test]
    fn v39_distinct_identity_and_explicit_absence_selector_truth_table() {
        let (_,new,old,_)=setup();
        let mut profile=old.profile().clone();profile.policy_id=POLICY.to_owned();profile.schema_version=PROFILE.to_owned();
        profile.reference_velocity_mode_id=Some(MODE.to_owned());assert_eq!(new.profile(),&profile);
        let mut memory=old.initial_memory();memory.schema_version=BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_MEMORY_VERSION.to_owned();
        assert_eq!(new.initial_memory(),memory);
        assert_eq!(crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,BALANCED_WAVE_BW5R_B_POLICY_ID);
        for previous_active in [false,true] {for current_active in [false,true] {
            for dt in [0.0,1.0/60.0] {for phase in [0,72,73,359] {
                for presence in [None,Some(false),Some(true)] {for bearing in [None,Some(false),Some(true)] {
                    let expected=previous_active && current_active && dt!=0.0 && [0,72].contains(&phase)
                        && presence==Some(false) && bearing==Some(false);
                    assert_eq!(crate::recovery_support_plane::airborne_reference_selected(
                        previous_active && current_active,dt,phase,presence,bearing),expected);
                }}
            }}
        }}
    }

    #[test]
    fn v39_four_hundred_inputs_preserve_all_parent_paths_and_unselected_commands() {
        let (source,new,old,floor)=setup();let mut memory=new.initial_memory();let mut parent=old.initial_memory();
        for m in [&mut memory,&mut parent] {for limb in &mut m.ordered_limb_memory {limb.gait_step=90;}}
        let mut selected_count=0;let mut changed_count=0;
        for n in 1..=400 {
            let mut input=state(&source,n);input.base_pose_world.position_m.y=0.37+0.02*(n as f64/17.0).sin();
            for (i,c) in input.ordered_contact_observations.iter_mut().enumerate() {
                c.presence=Some((n+i as u64*19)%53<31);c.bears_support=c.presence;
            }
            let mut motion=command(n);motion.gait_amplitude=(1.1/(0.82*1.75+0.40))*smoothstep((n-1) as f64/72.0);
            let out=new.step_with_floor(&memory,&input,&motion,Some(&floor));let before=old.step_with_floor(&parent,&input,&motion,Some(&floor));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);assert!(!before.actuation.safe_no_actuation);
            let mut expected_memory=before.next_memory.clone();expected_memory.schema_version=BALANCED_WAVE_RECOVERY_AIRBORNE_REFERENCE_MEMORY_VERSION.to_owned();
            assert_eq!(out.next_memory,expected_memory);
            let r=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();let a=r.airborne_reference.as_ref().unwrap();
            let w=r.wave_velocity.as_ref().unwrap();let rates=r.ordered_reference_velocity_rad_s.as_ref().unwrap();
            let parent_receipt=before.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            let mut expected_receipt=parent_receipt.clone();expected_receipt.reference_velocity_mode_id=Some(MODE.to_owned());
            expected_receipt.ordered_reference_velocity_rad_s=Some(rates.clone());expected_receipt.airborne_reference=Some(a.clone());
            assert_eq!(*r,expected_receipt);
            assert!(!serde_json::to_string(parent_receipt).unwrap().contains("airborne_reference"));
            assert_eq!(a.source_semantic_step,input.semantic_step);assert_eq!(a.source_sample_time_s,input.sample_time_s);
            assert_eq!(a.source_adapter_capability_sha256,input.adapter_capability_sha256);
            assert_eq!(out.actuation.receipt.schema_version,"sporespore_recovery_airborne_reference_controller_step_receipt_v1");
            for (i,(c,b)) in out.actuation.ordered_commands.iter().zip(&before.actuation.ordered_commands).enumerate() {
                let cap=c.maximum_target_speed_rad_s;let dt=r.reference_step_duration_s;let limb=&a.ordered_limbs[i/2];
                let contact=&input.ordered_contact_observations[i/2];assert_eq!(limb.precommand_contact,*contact);
                assert_eq!(limb.scheduled_phase_step,w.current_wave.ordered_limbs[i/2].scheduled_phase_step);
                let selected=w.feedforward_active && dt>0.0 && limb.scheduled_phase_step<=72
                    && contact.presence==Some(false) && contact.bears_support==Some(false);
                assert_eq!(limb.full_reference_rate_selected,selected);
                let prior=memory.support_reference.as_ref().unwrap().ordered_target_positions_rad[i];
                let full=if dt>0.0 {((c.requested_target_position_rad-prior)/dt).clamp(-cap,cap)}else{0.0};
                assert_eq!(full,a.ordered_full_reference_velocity_rad_s[i]);assert!(full.abs()<=cap);
                let rate=if selected {full}else{parent_receipt.ordered_reference_velocity_rad_s.as_ref().unwrap()[i]};
                assert_eq!(rate,rates[i]);assert!(rate.abs()<=cap);
                let q=&input.ordered_joint_observations[i];let raw=8.0*(c.requested_target_position_rad-q.position_rad.unwrap())-0.65*q.velocity_rad_s.unwrap()+1.65*rate;
                assert_eq!(-raw.clamp(-cap,cap),c.target_velocity_rad_s);assert_eq!(raw.abs()>cap,c.velocity_saturated);
                let mut expected=b.clone();
                if selected {
                    expected.target_velocity_rad_s=c.target_velocity_rad_s;expected.velocity_saturated=c.velocity_saturated;
                    expected.safety_contribution_rad_s=c.safety_contribution_rad_s;selected_count+=1;
                }
                assert_eq!(*c,expected);changed_count+=usize::from(c.target_velocity_rad_s!=b.target_velocity_rad_s);
                if n<=2 {assert!(!selected);assert_eq!(rate,0.0);}
            }
            memory=out.next_memory;parent=before.next_memory;
        }
        assert!(selected_count>0 && changed_count>0);
    }

    #[test]
    fn v39_contact_present_nonbearing_and_inactive_wave_keep_parent_velocity() {
        let (source,new,old,floor)=setup();
        for (presence,bearing) in [(false,false),(true,false),(true,true)] {
            let mut memory=new.initial_memory();let mut parent=old.initial_memory();
            for m in [&mut memory,&mut parent] {for limb in &mut m.ordered_limb_memory {limb.gait_step=90;}}
            // Activation and deactivation never select the full rate.
            for (i,amplitude) in [0.0,0.4,0.4,0.0,0.4].into_iter().enumerate() {
                let n=i as u64+1;let mut input=state(&source,n);input.base_pose_world.position_m.y=0.35;
                for c in &mut input.ordered_contact_observations {c.presence=Some(presence);c.bears_support=Some(bearing);}
                let mut motion=command(n);motion.gait_amplitude=amplitude;
                let out=new.step_with_floor(&memory,&input,&motion,Some(&floor));let before=old.step_with_floor(&parent,&input,&motion,Some(&floor));
                assert!(!out.actuation.safe_no_actuation);assert!(!before.actuation.safe_no_actuation);
                let r=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
                if presence || i!=2 {
                    assert!(r.airborne_reference.as_ref().unwrap().ordered_limbs.iter().all(|l|!l.full_reference_rate_selected));
                    assert_eq!(out.actuation.ordered_commands,before.actuation.ordered_commands);
                }
                if i!=2 {assert!(r.ordered_reference_velocity_rad_s.as_ref().unwrap().iter().all(|v|*v==0.0));}
                memory=out.next_memory;parent=before.next_memory;
            }
        }
    }

    #[test]
    fn v39_unknown_malformed_crossed_contact_and_wave_refuse_without_advancing_memory() {
        let (source,new,_,floor)=setup();
        let memory=new.step_with_floor(&new.initial_memory(),&state(&source,1),&command(1),Some(&floor)).next_memory;
        for variant in 0..12 {
            let mut bad=memory.clone();let mut input=state(&source,2);
            match variant {
                0=>input.ordered_contact_observations[0].presence=None,
                1=>input.ordered_contact_observations[0].bears_support=None,
                2=>{input.ordered_contact_observations.pop();},
                3=>input.ordered_contact_observations.swap(0,1),
                4=>input.ordered_contact_observations[0].contact_site_id="other_foot".to_owned(),
                5=>input.ordered_contact_observations[0].presence=Some(false), // Still bears=true: invalid, not airborne.
                6=>input.sample_time_s=state(&source,1).sample_time_s,
                7=>bad.schema_version=BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION.to_owned(),
                8=>bad.support_reference.as_mut().unwrap().previous_wave=None,
                9=>bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].scheduled_phase_step=360,
                10=>bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].walking_knee_fraction=f64::NAN,
                _=>input.ordered_joint_observations.swap(0,1),
            }
            let out=new.step_with_floor(&bad,&input,&command(2),Some(&floor));assert!(out.actuation.safe_no_actuation,"variant {variant}");
            // NaN is not equal to itself, so compare serialized memory for that case.
            assert_eq!(serde_json::to_string(&out.next_memory).unwrap(),serde_json::to_string(&bad).unwrap());
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
            assert!(out.actuation.receipt.recovery_support_plane.is_none());
        }
        assert!(new.step(&memory,&state(&source,2),&command(2)).actuation.safe_no_actuation);
    }
}
