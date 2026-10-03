mod recovery_wave_velocity {
    use super::*;
    use crate::controller::{BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_POLICY_ID as PARENT,
        BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_POLICY_ID as POLICY,
        BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_PROFILE_VERSION as PROFILE,
        BOUNDED_WAVE_VELOCITY_MODE_ID as MODE};
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};

    fn setup() -> (Candidate35Controller, BalancedWaveController, BalancedWaveController, FloorReference) {
        let source=controller();
        let new=BalancedWaveController::new_for_policy(source.compiled().clone(),POLICY).unwrap();
        let old=BalancedWaveController::new_for_policy(source.compiled().clone(),PARENT).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id:FRAME_ID.to_owned(),surface_id:"floor".to_owned(),source_instance_id:"synthetic_v38_not_native_evidence".to_owned(),
            source_kind:"declared_static_horizontal_surface".to_owned(),geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};
        (source,new,old,floor)
    }

    #[test]
    fn v38_profile_and_memory_are_distinct_without_changing_parent() {
        let (_,new,old,_)=setup();
        let mut expected=old.profile().clone();expected.policy_id=POLICY.to_owned();expected.schema_version=PROFILE.to_owned();
        expected.reference_velocity_mode_id=Some(MODE.to_owned());assert_eq!(new.profile(),&expected);
        assert_eq!(new.initial_memory().schema_version,BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION);
        assert!(new.initial_memory().support_reference.unwrap().previous_wave.is_none());
        assert!(!serde_json::to_string(&old.initial_memory()).unwrap().contains("previous_wave"));
        assert_eq!(crate::controller::SELECTED_BALANCED_WAVE_POLICY_ID,BALANCED_WAVE_BW5R_B_POLICY_ID);
    }

    #[test]
    fn v38_four_hundred_inputs_preserve_positions_and_bound_wave_rates() {
        let (source,new,old,floor)=setup();let mut memory=new.initial_memory();let mut parent=old.initial_memory();
        for m in [&mut memory,&mut parent] {for limb in &mut m.ordered_limb_memory {limb.gait_step=90;}}
        let mut changed=0;let mut active_rates=0;
        for n in 1..=400 {
            let mut input=state(&source,n);input.base_pose_world.position_m.y=0.37+0.02*(n as f64/17.0).sin();
            for (i,c) in input.ordered_contact_observations.iter_mut().enumerate() {c.presence=Some((n+i as u64*19)%53<31);c.bears_support=c.presence;}
            let mut motion=command(n);motion.gait_amplitude=(1.1/(0.82*1.75+0.40))*smoothstep((n-1) as f64/72.0);
            let out=new.step_with_floor(&memory,&input,&motion,Some(&floor));let before=old.step_with_floor(&parent,&input,&motion,Some(&floor));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);assert!(!before.actuation.safe_no_actuation);
            let receipt=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();let wr=receipt.wave_velocity.as_ref().unwrap();
            let rates=receipt.ordered_reference_velocity_rad_s.as_ref().unwrap();
            assert_eq!(wr.previous_wave,memory.support_reference.as_ref().unwrap().previous_wave);
            assert_eq!(Some(&wr.current_wave),out.next_memory.support_reference.as_ref().unwrap().previous_wave.as_ref());
            let mut expected_memory=before.next_memory.clone();expected_memory.schema_version=BALANCED_WAVE_RECOVERY_WAVE_VELOCITY_MEMORY_VERSION.to_owned();
            expected_memory.support_reference.as_mut().unwrap().previous_wave=Some(wr.current_wave.clone());assert_eq!(out.next_memory,expected_memory);
            let mut expected_receipt=before.actuation.receipt.recovery_support_plane.clone().unwrap();
            expected_receipt.reference_velocity_mode_id=Some(MODE.to_owned());expected_receipt.ordered_reference_velocity_rad_s=Some(rates.clone());
            expected_receipt.wave_velocity=Some(wr.clone());assert_eq!(*receipt,expected_receipt);
            assert_eq!(out.actuation.receipt.schema_version,"sporespore_recovery_wave_velocity_controller_step_receipt_v1");
            for (i,(c,b)) in out.actuation.ordered_commands.iter().zip(&before.actuation.ordered_commands).enumerate() {
                let cap=c.maximum_target_speed_rad_s;let dt=receipt.reference_step_duration_s;
                let rate=if wr.feedforward_active && dt>0.0 {((c.requested_target_position_rad-wr.ordered_comparison_reference_rad[i])/dt).clamp(-cap,cap)}else{0.0};
                assert_eq!(rate,rates[i]);assert!(rate.abs()<=cap);active_rates+=usize::from(rate!=0.0);
                let q=&input.ordered_joint_observations[i];let raw=8.0*(c.requested_target_position_rad-q.position_rad.unwrap())-0.65*q.velocity_rad_s.unwrap()+1.65*rate;
                assert_eq!(raw.clamp(-cap,cap)*MOTOR_DIRECTION_SIGN,c.target_velocity_rad_s);assert_eq!(raw.abs()>cap,c.velocity_saturated);
                let mut expected=b.clone();expected.target_velocity_rad_s=c.target_velocity_rad_s;expected.safety_contribution_rad_s=c.safety_contribution_rad_s;expected.velocity_saturated=c.velocity_saturated;
                assert_eq!(*c,expected);changed+=usize::from(c.target_velocity_rad_s!=b.target_velocity_rad_s);
                if n<=2 {assert_eq!(rate,0.0);assert!(!wr.feedforward_active);}
                if n==1 {assert_eq!(*c,*b);}
            }
            memory=out.next_memory;parent=before.next_memory;
        }
        assert!(changed>0 && active_rates>0);
    }

    #[test]
    fn v38_static_wave_excludes_pose_and_catchup_and_zero_amplitude_disables_rate() {
        let (source,new,_,floor)=setup();
        let first=new.step_with_floor(&new.initial_memory(),&state(&source,1),&command(1),Some(&floor));
        let mut memory=first.next_memory;let input=state(&source,2);let motion=command(2);
        let preview=new.step_with_floor(&memory,&input,&motion,Some(&floor));assert!(!preview.actuation.safe_no_actuation);
        memory.support_reference.as_mut().unwrap().previous_wave=preview.next_memory.support_reference.unwrap().previous_wave;
        for height in [0.33,0.35,0.37,0.39] {
            let mut pose=input.clone();pose.base_pose_world.position_m.y=height;
            let out=new.step_with_floor(&memory,&pose,&motion,Some(&floor));assert!(!out.actuation.safe_no_actuation);
            let r=out.actuation.receipt.recovery_support_plane.unwrap();let w=r.wave_velocity.unwrap();
            assert_eq!(w.previous_wave.as_ref().unwrap(),&w.current_wave);
            assert!(r.ordered_reference_velocity_rad_s.unwrap().iter().all(|v|*v==0.0));
        }
        let mut zero=motion.clone();zero.gait_amplitude=0.0;
        let out=new.step_with_floor(&memory,&input,&zero,Some(&floor));assert!(!out.actuation.safe_no_actuation);
        let r=out.actuation.receipt.recovery_support_plane.unwrap();assert!(!r.wave_velocity.unwrap().feedforward_active);
        assert!(r.ordered_reference_velocity_rad_s.unwrap().iter().all(|v|*v==0.0));
    }

    #[test]
    fn v38_missing_crossed_malformed_wave_and_counterfactual_geometry_refuse() {
        let (source,new,old,floor)=setup();let first=new.step_with_floor(&new.initial_memory(),&state(&source,1),&command(1),Some(&floor));
        let memory=first.next_memory;let input=state(&source,2);let motion=command(2);
        for variant in 0..7 {
            let mut bad=memory.clone();let support=bad.support_reference.as_mut().unwrap();
            match variant {
                0=>support.previous_wave=None,
                1=>support.previous_wave.as_mut().unwrap().ordered_limbs.pop().map(|_|()).unwrap(),
                2=>support.previous_wave.as_mut().unwrap().ordered_limbs[0].limb_id="other".to_owned(),
                3=>support.previous_wave.as_mut().unwrap().ordered_limbs[0].nominal_leg_direction_rad=f64::NAN,
                4=>support.previous_wave.as_mut().unwrap().ordered_limbs[0].walking_knee_fraction=1.1,
                5=>support.previous_wave.as_mut().unwrap().ordered_limbs[0].scheduled_phase_step=360,
                _=>bad.schema_version=BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION.to_owned(),
            }
            let out=new.step_with_floor(&bad,&input,&motion,Some(&floor));assert!(out.actuation.safe_no_actuation,"variant {variant}");
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
        let mut crossed=memory.clone();crossed.schema_version=BALANCED_WAVE_RECOVERY_REFERENCE_VELOCITY_MEMORY_VERSION.to_owned();
        assert!(old.step_with_floor(&crossed,&input,&motion,Some(&floor)).actuation.safe_no_actuation);
        assert!(new.step(&memory,&input,&motion).actuation.safe_no_actuation);
        let mut bad=memory.clone();bad.support_reference.as_mut().unwrap().previous_wave.as_mut().unwrap().ordered_limbs[0].nominal_leg_direction_rad=0.72;
        let mut pose=input.clone();pose.base_pose_world.orientation_xyzw.x=-(0.55_f64).sin();pose.base_pose_world.orientation_xyzw.y=0.0;pose.base_pose_world.orientation_xyzw.z=0.0;pose.base_pose_world.orientation_xyzw.w=(0.55_f64).cos();
        let out=new.step_with_floor(&bad,&pose,&motion,Some(&floor));assert!(out.actuation.safe_no_actuation);
        assert_eq!(out.next_memory,bad);
    }
}
