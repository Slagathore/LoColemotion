mod recovery_measured_support_transfer {
    use super::*;
    use crate::recovery_measured_support_transfer as transfer;
    use crate::recovery_support_progression as guard;
    use crate::recovery_floor_reference::{FloorReference, FRAME_ID};
    use crate::stability::OrderedBodyStateV2;

    fn setup() -> (Candidate35Controller, BalancedWaveController, FloorReference) {
        let source=controller();
        let new=BalancedWaveController::new_for_policy(source.compiled().clone(),transfer::POLICY).unwrap();
        let floor=FloorReference {schema_version:"sporespore_static_horizontal_floor_reference_v1".to_owned(),
            frame_id:FRAME_ID.to_owned(),surface_id:"floor".to_owned(),source_instance_id:"synthetic_v45".to_owned(),
            source_kind:"declared_static_horizontal_surface".to_owned(),geometry_source_sha256:format!("sha256:{}","1".repeat(64)),height_world_m:0.0};
        (source,new,floor)
    }
    // Synthetic measurement fixture, not a physical trajectory or FK estimate.
    pub(super) fn input(source:&Candidate35Controller,n:u64,ready:bool) -> (StateFrame,transfer::MeasuredBodyFrame) {
        let mut s=state(source,n);s.base_pose_world.position_m.y=0.37;
        s.base_pose_world.position_m.z=if ready {-0.10} else {0.0};
        let compiled=source.compiled();
        let bodies=compiled.morphology.morphology_spec.bodies.iter().map(|spec| {
            let mut pose=s.base_pose_world;
            if spec.body_id!="torso" {
                pose.position_m.x=if spec.body_id.contains("left") {-0.18} else {0.18};
                pose.position_m.z=if spec.body_id.contains("front") {0.20} else {-0.20};
                pose.position_m.y=0.20;
            }
            OrderedBodyStateV2 {body_id:spec.body_id.clone(),pose_world:pose,twist_world:s.base_twist_world}
        }).collect();
        let f=transfer::MeasuredBodyFrame {schema_version:transfer::BODY_FRAME.to_owned(),
            semantic_step:n,sample_time_s:s.sample_time_s,frame_id:FRAME_ID.to_owned(),
            adapter_capability_sha256:s.adapter_capability_sha256.clone(),source_measurement:true,ordered_body_states:bodies};
        (s,f)
    }
    fn at(clock:u64) -> Candidate35ControllerMemory {
        let mut m=Candidate35ControllerMemory::initial();m.last_semantic_step=Some(1);
        for l in &mut m.ordered_limb_memory {l.gait_step=clock;} m
    }
    fn decide(m:&transfer::Memory,source:&Candidate35Controller,ready:bool,clock:u64) -> transfer::Receipt {
        let (s,f)=input(source,2,ready);let before=at(clock);let after=at(clock+1);
        let inherited=guard::decide(&guard::Memory::default(),&before,&after,&s,true).unwrap();
        transfer::decide(m,&before,&after,&s,transfer::measure(source.compiled(),&s,&f).unwrap(),
            true,1.0/120.0,0.35,inherited).unwrap()
    }
    fn receipt(out:&BalancedWaveControllerStepOutput) -> &transfer::Receipt {
        out.actuation.receipt.recovery_support_plane.as_ref().unwrap().measured_support_transfer.as_ref().unwrap()
    }

    #[test]
    fn v45_triangle_geometry_and_rigid_frame_invariance() {
        let p=Vec3::ZERO;let f=Vec3 {x:0.0,y:0.0,z:1.0};
        let points=[Vec3 {x:0.18,y:0.0,z:0.2},Vec3 {x:-0.18,y:0.0,z:-0.2},Vec3 {x:0.18,y:0.0,z:-0.2}];
        let (margin,shift)=transfer::triangle(p,f,&points,0.025).unwrap();
        assert!(margin.abs()<1e-15 && shift<0.0);
        let inside=Vec3 {x:0.0,y:0.0,z:shift};
        let (d,next)=transfer::triangle(inside,f,&points,0.025).unwrap();
        assert!((d-0.025).abs()<1e-14 && next.abs()<1e-14);
        let rotate=|v:Vec3|Vec3 {x:v.z+0.5,y:v.y+0.8,z:-v.x-0.2};
        let mut transformed=points.map(rotate);transformed.reverse();
        let (d,s)=transfer::triangle(rotate(p),Vec3 {x:1.0,y:0.0,z:0.0},&transformed,0.025).unwrap();
        assert!((d-margin).abs()<1e-14 && (s-shift).abs()<1e-14);
        assert!(transfer::triangle(p,f,&[p,p,p],0.025).is_err());
        assert!(transfer::triangle(Vec3 {x:1.0,y:0.0,z:0.0},f,&points,0.025).is_err());
    }

    #[test]
    fn v45_measured_mass_velocity_and_body_binding_refuse_crosses() {
        let (source,_,_)=setup();let (s,f)=input(&source,2,true);
        let measured=transfer::measure(source.compiled(),&s,&f).unwrap();
        let mass=source.compiled().morphology.morphology_spec.bodies.iter().map(|b|b.mass_kg).sum::<f64>();
        assert_eq!(mass,measured.whole_mass_kg);
        assert!((measured.measured_com_position_world_m.z+0.3/mass).abs()<1e-14);
        assert!(!measured.geometry_is_contact_authority);
        let mut moving=f.clone();moving.ordered_body_states[1].twist_world.linear_velocity_m_s.z=0.1;
        let m=transfer::measure(source.compiled(),&s,&moving).unwrap();
        assert!((m.forward_com_speed_m_s-0.1*source.compiled().morphology.morphology_spec.bodies[1].mass_kg/mass).abs()<1e-14);
        for kind in 0..9 {
            let mut bad=f.clone();
            match kind {
                0=>bad.semantic_step+=1,1=>bad.sample_time_s+=0.001,2=>bad.source_measurement=false,
                3=>bad.ordered_body_states.swap(1,2),4=>bad.ordered_body_states[0].pose_world.position_m.x+=0.01,
                5=>bad.ordered_body_states[1].twist_world.linear_velocity_m_s.x=f64::NAN,
                6=>bad.ordered_body_states[0].pose_world.orientation_xyzw=Quaternion {x:0.0,y:1.0,z:0.0,w:0.0},
                7=>bad.adapter_capability_sha256=format!("sha256:{}","2".repeat(64)),
                _=>{for b in &mut bad.ordered_body_states {b.pose_world.position_m.x=f64::MAX;}},
            }
            assert!(transfer::measure(source.compiled(),&s,&bad).is_err(),"kind {kind}");
        }
    }

    #[test]
    fn v45_six_measurements_release_then_new_epoch_prepares_again() {
        let (source,_,_)=setup();let mut m=transfer::Memory::default();
        for n in 1..=6 {
            let r=decide(&m,&source,true,90);
            assert_eq!(n<6,r.preparation_held);assert_eq!(n==6,r.preparation_released_this_command);
            assert_eq!(Some("front_left"),r.planned_swing_limb_id.as_deref());
            assert_eq!(Some(90),r.planned_swing_start_gait_step);
            m=r.next_memory;m.validate(false).unwrap();
        }
        assert!(!decide(&m,&source,true,91).preparation_held);
        let next=decide(&m,&source,true,450);
        assert!(next.preparation_held);assert_eq!(Some(450),next.planned_swing_start_gait_step);
        let interrupted=decide(&next.next_memory,&source,false,450);
        assert_eq!(0,interrupted.next_memory.ready_dwell_commands);
    }

    #[test]
    fn v45_bias_direction_damping_clips_and_preparation_timeout() {
        let (source,_,_)=setup();let mut m=transfer::Memory::default();
        for n in 1..=240 {
            let r=decide(&m,&source,false,90);
            assert!(r.preparation_held && r.requested_foreaft_displacement_m.unwrap()<0.0);
            assert!(r.next_memory.hip_bias_rad>=m.hip_bias_rad);
            assert!(r.applied_hip_bias_rate_rad_s.abs()<=transfer::MAX_BIAS_RATE+1e-14);
            assert!(r.next_memory.hip_bias_rad.abs()<=transfer::MAX_BIAS);
            assert_eq!(n,r.next_memory.preparation_commands);m=r.next_memory;
        }
        assert_eq!(transfer::MAX_BIAS,m.hip_bias_rad);
        let (s,f)=input(&source,2,false);let inherited=guard::decide(&guard::Memory::default(),&at(90),&at(91),&s,true).unwrap();
        let e=transfer::decide(&m,&at(90),&at(91),&s,transfer::measure(source.compiled(),&s,&f).unwrap(),true,
            1.0/120.0,0.35,inherited).unwrap_err();assert!(e.to_string().contains("preparation_timeout"));
    }

    #[test]
    fn v52_extended_range_keeps_rate_dwell_and_exhausted_deadline() {
        let (source,_,_)=setup();let (s,f)=input(&source,2,false);
        let mut memory=transfer::Memory::default();
        for n in 1..=240 {
            let inherited=guard::decide(&guard::Memory::default(),&at(90),&at(91),&s,true).unwrap();
            let receipt=transfer::decide_extended_remaining_support(&memory,&at(90),&at(91),&s,
                transfer::measure(source.compiled(),&s,&f).unwrap(),true,1.0/120.0,0.35,inherited).unwrap();
            assert_eq!(Some(0.30),receipt.maximum_absolute_reference_bias_rad);
            assert!(receipt.applied_hip_bias_rate_rad_s.abs()<=transfer::MAX_BIAS_RATE+1e-14);
            assert_eq!(n,receipt.next_memory.preparation_commands);
            assert_eq!(0,receipt.next_memory.ready_dwell_commands);
            assert!(receipt.preparation_held && !receipt.preparation_released_this_command);
            assert!(receipt.next_memory.hip_bias_rad.abs()<=0.30);
            memory=receipt.next_memory;
        }
        assert_eq!(0.30,memory.hip_bias_rad);
        assert!(memory.validate(false).is_err());
        let inherited=guard::decide(&guard::Memory::default(),&at(90),&at(91),&s,true).unwrap();
        let error=transfer::decide_extended_remaining_support(&memory,&at(90),&at(91),&s,
            transfer::measure(source.compiled(),&s,&f).unwrap(),true,1.0/120.0,0.35,inherited).unwrap_err();
        assert!(error.to_string().contains("preparation_timeout"));
    }

    #[test]
    fn v45_runtime_hold_has_real_commands_and_truthful_effective_phases() {
        let (source,new,floor)=setup();let mut memory=new.initial_memory();
        for l in &mut memory.ordered_limb_memory {l.gait_step=90;}
        for n in 1..=8 {
            let (s,f)=input(&source,n,true);let saved=s.clone();
            let out=new.step_with_measured_body(&memory,&s,&command(n),Some(&floor),Some(&f));
            assert!(!out.actuation.safe_no_actuation,"{:?}",out.actuation.receipt.controller_error);
            let r=receipt(&out);assert_eq!(n<6,r.effective_phase_progression_held);
            for (i,id) in ["front_left","front_right","rear_left","rear_right"].iter().enumerate() {
                let (index,l)=out.next_memory.ordered_limb_memory.iter().enumerate().find(|(_,l)|l.limb_id==*id).unwrap();
                assert_eq!((l.gait_step%360+360-index as u64*90)%360,r.effective_selected_phases[i]);
            }
            if n<6 {assert_eq!(memory.ordered_limb_memory,out.next_memory.ordered_limb_memory);}
            let support=out.actuation.receipt.recovery_support_plane.as_ref().unwrap();
            assert!(support.support_progression.is_none());
            assert_eq!(n<6,support.support_hold_posture.as_ref().unwrap().enabled);
            if n==2 {assert!(out.actuation.ordered_commands.iter().any(|c|c.target_velocity_rad_s!=0.0));}
            assert_eq!(s,saved);assert_eq!(digest_serializable(&out.actuation.receipt).unwrap(),out.actuation.receipt_sha256);
            memory=serde_json::from_value(serde_json::to_value(out.next_memory).unwrap()).unwrap();
        }
    }

    #[test]
    fn v45_inherited_contact_hold_and_safe_zero_preserve_memory() {
        let (source,new,floor)=setup();let mut memory=new.initial_memory();
        for l in &mut memory.ordered_limb_memory {l.gait_step=90;}
        let (s,f)=input(&source,1,false);
        memory=new.step_with_measured_body(&memory,&s,&command(1),Some(&floor),Some(&f)).next_memory;
        for kind in 0..7 {
            let (mut s,mut f)=input(&source,2,false);let mut m=memory.clone();
            match kind {
                0=>{},1=>f.source_measurement=false,
                2=>m.measured_support_transfer.as_mut().unwrap().preparation_commands=240,
                3=>m.measured_support_transfer.as_mut().unwrap().hip_bias_rad=0.251,
                4=>m.measured_support_transfer=None,
                5=>{s.ordered_contact_observations[3].presence=Some(false);s.ordered_contact_observations[3].bears_support=Some(false);m.support_progression.as_mut().unwrap().held_steps=120;},
                _=>m.schema_version=crate::recovery_support_hold_posture::MEMORY.to_owned(),
            }
            let out=new.step_with_measured_body(&m,&s,&command(2),Some(&floor),if kind==0 {None} else {Some(&f)});
            assert!(out.actuation.safe_no_actuation,"kind {kind}");assert_eq!(m,out.next_memory);
            assert!(out.actuation.ordered_commands.iter().all(|c|c.target_velocity_rad_s==0.0));
        }
        let (mut s,f)=input(&source,2,true);
        s.ordered_contact_observations[3].presence=Some(false);s.ordered_contact_observations[3].bears_support=Some(false);
        let out=new.step_with_measured_body(&memory,&s,&command(2),Some(&floor),Some(&f));
        assert!(!out.actuation.safe_no_actuation);let r=receipt(&out);
        assert!(r.preparation_held && r.inherited_guard_recommendation.phase_progression_held);
        assert_eq!(memory.ordered_limb_memory,out.next_memory.ordered_limb_memory);
    }
}
