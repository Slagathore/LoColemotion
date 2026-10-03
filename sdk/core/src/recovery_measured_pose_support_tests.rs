mod recovery_measured_pose_support {
    use super::*;
    use crate::recovery_measured_pose_support as measured;
    use crate::recovery_measured_support_transfer as transfer;
    use crate::recovery_floor_reference::{FloorReference,FRAME_ID};

    fn setup() -> (Candidate35Controller,BalancedWaveController,FloorReference) {
        let source=controller();let new=BalancedWaveController::new_for_policy(source.compiled().clone(),measured::POLICY).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),frame_id:FRAME_ID.to_owned(),
            surface_id:"floor".to_owned(),source_instance_id:"synthetic_v46".to_owned(),source_kind:"declared_static_horizontal_surface".to_owned(),
            geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};(source,new,floor)
    }
    fn input(source:&Candidate35Controller,n:u64,tilt:f64) -> (StateFrame,transfer::MeasuredBodyFrame) {
        let (mut s,mut f)=super::recovery_measured_support_transfer::input(source,n,true);
        let q=Quaternion {x:0.0,y:0.0,z:(tilt/2.0).sin(),w:(tilt/2.0).cos()};s.base_pose_world.orientation_xyzw=q;
        for body in &mut f.ordered_body_states {body.pose_world.orientation_xyzw=q;}(s,f)
    }
    fn bottom(source:&Candidate35Controller,s:&StateFrame,i:usize,hip:f64,knee:f64) -> f64 {
        let g=&source.compiled().geometry;let q=s.base_pose_world.orientation_xyzw;
        let fy=2.0*(q.y*q.z-q.w*q.x);let uy=1.0-2.0*(q.x*q.x+q.z*q.z);let sy=-2.0*(q.x*q.y+q.w*q.z);
        let anchor=if i<2 {g.front_hip_x_m}else{g.rear_hip_x_m}*fy+if i%2==0 {g.left_hip_z_m}else{g.right_hip_z_m}*sy;
        s.base_pose_world.position_m.y+anchor+fy*(g.upper_length_m*hip.sin()+g.lower_length_m/2.0*(hip+knee).sin())
            -uy*(g.upper_length_m*hip.cos()+g.lower_length_m/2.0*(hip+knee).cos())
            -(uy*(hip+knee).cos()-fy*(hip+knee).sin()).abs()*g.lower_length_m/2.0-g.foot_radius_m
    }
    #[test]
    fn v46_profile_retains_transfer_parameters_and_removes_only_upright_latches() {
        let (source,new,_)=setup();let old=BalancedWaveController::new_for_policy(source.compiled().clone(),transfer::POLICY).unwrap();
        let mut profile=old.profile().clone();profile.policy_id=measured::POLICY.to_owned();profile.schema_version=measured::PROFILE.to_owned();
        profile.reference_velocity_mode_id=Some(measured::MODE.to_owned());profile.support_hold_posture_mode_id=Some(measured::HOLD_MODE.to_owned());
        assert_eq!(&profile,new.profile());let mut memory=old.initial_memory();memory.schema_version=measured::MEMORY.to_owned();
        memory.support_reference.as_mut().unwrap().ordered_stance_latches=None;assert_eq!(memory,new.initial_memory());
    }
    #[test]
    fn v46_tilted_support_targets_reach_actual_floor_through_hold_release_and_reentry() {
        let (source,new,floor)=setup();let mut m=new.initial_memory();for l in &mut m.ordered_limb_memory {l.gait_step=90;}
        for n in 1..=12 {
            let (mut s,f)=input(&source,n,if n<5 {0.008}else{-0.008});
            if n==9 {s.ordered_contact_observations[3].presence=Some(false);s.ordered_contact_observations[3].bears_support=Some(false);}
            let out=new.step_with_measured_body(&m,&s,&command(n),Some(&floor),Some(&f));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);
            let r=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();let t=r.measured_support_transfer.as_ref().unwrap();
            assert!(r.upright_stance.is_none() && r.stance_latch.is_none());assert!(out.next_memory.support_reference.as_ref().unwrap().ordered_stance_latches.is_none());
            assert_eq!(measured::HOLD_MODE,r.support_hold_posture.as_ref().unwrap().mode_id);
            assert_eq!(n<6||(9..=11).contains(&n),t.effective_phase_progression_held);
            assert_eq!(0.0,r.feasible_support_plan.as_ref().unwrap().requested_lowering_m);
            for (i,p) in r.ordered_limb_proposals.iter().enumerate() {
                if t.effective_phase_progression_held || t.effective_selected_phases[i]>72 {
                    assert!(bottom(&source,&s,i,p.goal_hip_rad,p.goal_knee_rad).abs()<1e-12);
                    assert_eq!(0.0,p.walking_knee_fraction);
                }
            }
            if t.effective_phase_progression_held {
                assert_eq!(m.ordered_limb_memory,out.next_memory.ordered_limb_memory);
                if n>1 {
                    let wave=r.wave_velocity.as_ref().unwrap();
                    let now=crate::recovery_support_hold_posture::without_lift(&wave.current_wave);
                    let before=crate::recovery_support_hold_posture::without_lift(wave.previous_wave.as_ref().unwrap());
                    if now==before {
                        // The comparison reference may not gain a fake wave
                        // velocity from a pose/hold change. Absent feet still
                        // legitimately use full reference slew, independently.
                        for (target,comparison) in out.actuation.ordered_commands.iter().zip(&wave.ordered_comparison_reference_rad) {
                            assert!((target.requested_target_position_rad-comparison).abs()<1e-12);
                        }
                    }
                }
            }
            assert_eq!(measured::RECEIPT,out.actuation.receipt.schema_version);
            assert_eq!(digest_serializable(&out.actuation.receipt).unwrap(),out.actuation.receipt_sha256);
            m=serde_json::from_value(serde_json::to_value(out.next_memory).unwrap()).unwrap();
        }
    }
    #[test]
    fn v46_missing_measurements_crossed_latch_and_finite_timeout_keep_memory_and_zero() {
        let (source,new,floor)=setup();let mut m=new.initial_memory();for l in &mut m.ordered_limb_memory {l.gait_step=90;}
        let (s,f)=input(&source,1,0.008);m=new.step_with_measured_body(&m,&s,&command(1),Some(&floor),Some(&f)).next_memory;
        for kind in 0..4 {
            let (mut s,f)=input(&source,2,0.008);let mut bad=m.clone();
            match kind {
                0=>{},1=>bad.support_reference.as_mut().unwrap().ordered_stance_latches=Some(crate::recovery_support_plane::initial_stance_latches()),
                2=>{bad.support_progression.as_mut().unwrap().held_steps=120;s.ordered_contact_observations[3].presence=Some(false);s.ordered_contact_observations[3].bears_support=Some(false);},
                _=>bad.schema_version=transfer::MEMORY.to_owned(),
            }
            let out=new.step_with_measured_body(&bad,&s,&command(2),Some(&floor),if kind==0 {None} else {Some(&f)});
            assert!(out.actuation.safe_no_actuation,"kind {kind}");assert_eq!(bad,out.next_memory);
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
    }
}
