//! V47 separates the desired body pose from stationary world foot references.
//! Analytic IK creates commands; native measurements remain the contact authority.
use serde::{Deserialize, Serialize};
use crate::canonical::digest_serializable;
use crate::protocol::{ActuationFrame, StateFrame, MotionCommand};
use crate::quadruped::CompiledQuadruped;
use crate::schema::{CoreError, Result, Vec3};
use crate::recovery_support_plane::{SupportReferenceMemory,SupportPlaneReceipt};
use crate::recovery_measured_support_transfer::Receipt as Transfer;
use crate::recovery_floor_reference::FloorReference;
pub const POLICY:&str="sporespore_balanced_wave_recovery_anchored_body_pose_v1";
pub const MEMORY:&str="sporespore_balanced_wave_recovery_anchored_body_pose_memory_v1";
pub const PROFILE:&str="sporespore_balanced_wave_recovery_anchored_body_pose_profile_v1";
pub const MODE:&str="stationary_world_feet_and_independent_upright_body_pose_v1";
pub const RECEIPT:&str="sporespore_recovery_anchored_body_pose_controller_step_receipt_v1";
// V50 changes only startup feed-forward authority. Historical policies retain
// their exact arithmetic and omit the new receipt field.
pub const STARTUP_POLICY:&str="sporespore_balanced_wave_recovery_startup_reference_velocity_v1";
pub const STARTUP_MEMORY:&str="sporespore_balanced_wave_recovery_startup_reference_velocity_memory_v1";
pub const STARTUP_PROFILE:&str="sporespore_balanced_wave_recovery_startup_reference_velocity_profile_v1";
pub const STARTUP_RECEIPT:&str="sporespore_recovery_startup_reference_velocity_controller_step_receipt_v1";
pub const STARTUP_MODE:&str="bounded_independent_pose_startup_ramped_reference_velocity_v1";
pub const STEP_LENGTH:f64=0.06;
pub const LIFT:f64=0.02;
pub const VERTICAL:f64=0.33;
const LIMBS:[&str;4]=["front_left","front_right","rear_left","rear_right"];
#[derive(Debug,Clone,PartialEq,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FootMemory {pub limb_id:String,pub anchor_world_m:Vec3,pub swing_start_world_m:Option<Vec3>,pub swing_epoch:Option<u64>}
#[derive(Debug,Clone,PartialEq,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Memory {
    pub origin_world_m:Vec3,pub forward_world_unit:Vec3,pub start_time_s:f64,pub last_sample_time_s:f64,
    pub ordered_feet:Vec<FootMemory>,pub last_body_reference_world_m:Vec3,pub ordered_last_targets_world_m:Vec<Vec3>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub height_correction_m:Option<f64>,
}
#[derive(Debug,Clone,PartialEq,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version:String,pub desired_body_position_world_m:Vec3,pub desired_forward_world_unit:Vec3,
    pub desired_body_up_world_unit:Vec3,pub ordered_foot_targets_world_m:Vec<Vec3>,pub ordered_joint_goals_rad:Vec<f64>,
    pub ordered_target_fk_error_m:Vec<f64>,pub ordered_lateral_projection_residual_m:Vec<f64>,
    pub ordered_goal_bottom_in_measured_pose_m:Vec<f64>,pub next_memory:Memory,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub origin_rebase:Option<crate::recovery_advancing_body_origin::Receipt>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub reference_velocity_startup_scale:Option<f64>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub joint_feasible_height:Option<crate::recovery_joint_feasible_height::Receipt>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub zero_amplitude_velocity_guard:Option<crate::recovery_bounded_stop_velocity::Receipt>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub zero_amplitude_motor_brake:Option<crate::recovery_zero_velocity_brake::Receipt>,
    pub geometry_is_contact_authority:bool,pub physical_acceptance_authority:bool,
}
fn ensure(v:bool,c:&str)->Result<()> {if v {Ok(())}else{Err(CoreError::Frame(format!("anchored_body_pose_{c}")))}}
fn add(a:Vec3,b:Vec3)->Vec3 {Vec3{x:a.x+b.x,y:a.y+b.y,z:a.z+b.z}}
fn sub(a:Vec3,b:Vec3)->Vec3 {Vec3{x:a.x-b.x,y:a.y-b.y,z:a.z-b.z}}
fn mul(a:Vec3,s:f64)->Vec3 {Vec3{x:a.x*s,y:a.y*s,z:a.z*s}}
fn dot(a:Vec3,b:Vec3)->f64 {a.x*b.x+a.y*b.y+a.z*b.z}
fn smooth(u:f64)->f64 {let u=u.clamp(0.0,1.0);u*u*(3.0-2.0*u)}
/// Positive knee branch, hip angle measured from the downward vertical.
/// Unreachable goals and actuator-bound violations are refusals, never projections.
pub(crate) fn ik(x:f64,down:f64,upper:f64,lower:f64,hip_min:f64,hip_max:f64,knee_max:f64)->Result<(f64,f64)> {
    ensure([x,down,upper,lower,hip_min,hip_max,knee_max].iter().all(|x|x.is_finite()) && down>0.0 && upper>0.0 && lower>0.0,"ik_domain")?;
    let c=(x*x+down*down-upper*upper-lower*lower)/(2.0*upper*lower);
    ensure((-1.0..=1.0).contains(&c),"unreachable_endpoint")?;
    let knee=c.acos();let hip=x.atan2(down)-(lower*knee.sin()).atan2(upper+lower*knee.cos());
    ensure(hip>=hip_min && hip<=hip_max && knee<=knee_max,"joint_bounds")?;
    Ok((hip,knee))
}
pub(crate) fn validate(memory:Option<&Memory>,initial:bool,previous_time:Option<f64>,floor:&FloorReference,radius:f64,joint_feasible_height:bool)->Result<()> {
    ensure(initial==memory.is_none(),"memory_initialization")?;
    if let Some(m)=memory {
        ensure(joint_feasible_height==m.height_correction_m.is_some(),"height_correction_selection")?;
        if let Some(correction)=m.height_correction_m {crate::recovery_joint_feasible_height::validate_correction(correction)?;}
        ensure(m.start_time_s.is_finite() && m.last_sample_time_s.is_finite() && m.start_time_s<=m.last_sample_time_s && previous_time==Some(m.last_sample_time_s),"memory_clock")?;
        for v in [&m.origin_world_m,&m.forward_world_unit,&m.last_body_reference_world_m] {v.finite("anchored_body_pose_memory_vector")?;}
        ensure(m.forward_world_unit.y==0.0 && (dot(m.forward_world_unit,m.forward_world_unit)-1.0).abs()<1e-12,"memory_forward")?;
        ensure(m.ordered_feet.len()==4 && m.ordered_last_targets_world_m.len()==4,"memory_population")?;
        for (i,f) in m.ordered_feet.iter().enumerate() {
            ensure(f.limb_id==LIMBS[i] && f.swing_epoch.is_some()==f.swing_start_world_m.is_some(),"memory_foot_identity")?;
            f.anchor_world_m.finite("anchored_body_pose_anchor")?;m.ordered_last_targets_world_m[i].finite("anchored_body_pose_target")?;
            ensure(f.anchor_world_m.y==floor.height_world_m+radius,"memory_floor")?;
            if let Some(start)=f.swing_start_world_m {start.finite("anchored_body_pose_swing_start")?;ensure(start==f.anchor_world_m,"memory_swing_anchor")?;}
        }
    }
    Ok(())
}
#[allow(clippy::too_many_arguments)]
pub(crate) fn apply(memory:Option<&Memory>,previous:&SupportReferenceMemory,state:&StateFrame,motion:&MotionCommand,
    compiled:&CompiledQuadruped,floor:&FloorReference,transfer:&Transfer,actuation:&mut ActuationFrame,
    max_controller_speed:f64,gain:f64,damping:f64,motor_sign:f64,startup_ramped:bool,joint_feasible_height:bool)->Result<(Memory,SupportReferenceMemory)> {
    let g=&compiled.geometry;let radius=g.foot_radius_m;let upper=g.upper_length_m;let lower=g.lower_length_m;
    let dt=previous.previous_sample_time_s.map_or(0.0,|v|state.sample_time_s-v);
    ensure(dt==0.0 || (dt-1.0/120.0).abs()<1e-9,"clock")?;
    let initial=memory.is_none();let mut next=if let Some(m)=memory {m.clone()}else{
        let feet=transfer.measurement.ordered_measured_capsule_endpoints_world_m.iter().enumerate().map(|(i,p)|FootMemory {
            limb_id:LIMBS[i].to_owned(),anchor_world_m:Vec3{x:p.x,y:floor.height_world_m+radius,z:p.z},swing_start_world_m:None,swing_epoch:None}).collect::<Vec<_>>();
        Memory{origin_world_m:state.base_pose_world.position_m,forward_world_unit:transfer.measurement.anatomical_forward_horizontal_world_unit,
            start_time_s:state.sample_time_s,last_sample_time_s:state.sample_time_s,
            ordered_last_targets_world_m:feet.iter().map(|f|f.anchor_world_m).collect(),ordered_feet:feet,last_body_reference_world_m:state.base_pose_world.position_m,
            height_correction_m:joint_feasible_height.then_some(0.0)}
    };
    let forward=next.forward_world_unit;let right=Vec3{x:-forward.z,y:0.0,z:forward.x};
    let startup_scale=startup_ramped.then(||smooth((state.sample_time_s-next.start_time_s)/(72.0/120.0)));
    let mut body=next.last_body_reference_world_m;
    if motion.gait_amplitude!=0.0 {
        body=add(next.origin_world_m,mul(forward,-(upper+lower)*transfer.next_memory.hip_bias_rad));
        let blend=smooth((state.sample_time_s-next.start_time_s)/(72.0/120.0));
        body.y=next.origin_world_m.y+blend*(floor.height_world_m+radius+VERTICAL-next.origin_world_m.y);
    }
    let mut targets=next.ordered_last_targets_world_m.clone();
    if motion.gait_amplitude!=0.0 {
        for (i,foot) in next.ordered_feet.iter_mut().enumerate() {
            let phase=transfer.effective_selected_phases[i];
            if phase>72 {
                if let Some(start)=foot.swing_start_world_m.take() {
                    foot.anchor_world_m=add(start,mul(forward,STEP_LENGTH));foot.swing_epoch=None;
                }
                targets[i]=foot.anchor_world_m;
            } else if transfer.next_memory.prepared_limb_id.as_deref()==Some(LIMBS[i])
                && transfer.next_memory.prepared_swing_start_gait_step==transfer.planned_swing_start_gait_step {
                let epoch=transfer.planned_swing_start_gait_step.ok_or_else(||CoreError::Time("anchored_body_pose_epoch_missing".to_owned()))?;
                if foot.swing_epoch!=Some(epoch) {ensure(foot.swing_epoch.is_none(),"swing_epoch_crossed")?;foot.swing_epoch=Some(epoch);foot.swing_start_world_m=Some(foot.anchor_world_m);}
                let start=foot.swing_start_world_m.expect("initialized swing");let u=phase as f64/72.0;
                targets[i]=add(start,mul(forward,STEP_LENGTH*smooth(u)));
                targets[i].y+=if phase==0 || phase==72 {0.0}else{LIFT*(std::f64::consts::PI*u).sin()};
            } else {targets[i]=foot.anchor_world_m;}
        }
    }
    // The parent body and foot path arithmetic above stays exact. Only the
    // explicitly selected V51 reference height can change before actual IK.
    let height_receipt=if joint_feasible_height && !initial && motion.gait_amplitude!=0.0 {
        let selected=crate::recovery_joint_feasible_height::select(body,forward,&targets,compiled,
            next.height_correction_m.expect("validated V51 memory"),dt,startup_scale.expect("V51 startup law"))?;
        body.y=selected.selected_body_height_world_m;
        next.height_correction_m=Some(selected.selected_correction_m);
        Some(selected)
    } else {None};
    let q=state.base_pose_world.orientation_xyzw;let norm=q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w;
    let fy=2.0*(q.y*q.z-q.w*q.x)/norm;let uy=1.0-2.0*(q.x*q.x+q.z*q.z)/norm;let sy=-2.0*(q.x*q.y+q.w*q.z)/norm;
    let mut goals=Vec::with_capacity(8);let mut errors=Vec::new();let mut lateral=Vec::new();let mut bottoms=Vec::new();
    for (i,target) in targets.iter().enumerate() {
        let anchor_x=if i<2 {g.front_hip_x_m}else{g.rear_hip_x_m};let anchor_side=if i%2==0 {g.left_hip_z_m}else{g.right_hip_z_m};
        let relative=sub(*target,body);let x=dot(relative,forward)-anchor_x;let down=body.y-target.y;
        let h_bound=&compiled.morphology.morphology_spec.actuators[2*i];let k_bound=&compiled.morphology.morphology_spec.actuators[2*i+1];
        let (h,k)=if initial {(0.0,0.0)}else{ik(x,down,upper,lower,h_bound.minimum_target_position_rad,h_bound.maximum_target_position_rad,k_bound.maximum_target_position_rad)?};
        let fx=upper*h.sin()+lower*(h+k).sin();let fd=upper*h.cos()+lower*(h+k).cos();
        errors.push((fx-x).hypot(fd-down));lateral.push(dot(relative,right)-anchor_side);
        bottoms.push(state.base_pose_world.position_m.y+anchor_x*fy+anchor_side*sy+fy*(upper*h.sin()+lower*0.5*(h+k).sin())
            -uy*(upper*h.cos()+lower*0.5*(h+k).cos())-(uy*(h+k).cos()-fy*(h+k).sin()).abs()*lower*0.5-radius-floor.height_world_m);
        goals.extend([h,k]);
    }
    next.last_body_reference_world_m=body;next.ordered_last_targets_world_m=targets.clone();next.last_sample_time_s=state.sample_time_s;
    let mut reference=SupportReferenceMemory::initial();reference.previous_sample_time_s=Some(state.sample_time_s);
    reference.ordered_target_positions_rad.clear();let mut rates=Vec::new();let mut slew=Vec::new();
    for (i,c) in actuation.ordered_commands.iter_mut().enumerate() {
        let old=previous.ordered_target_positions_rad[i];let limit=c.maximum_target_speed_rad_s;
        let target=old+(goals[i]-old).clamp(-limit*dt,limit*dt);let rate=if dt>0.0 {(target-old)/dt}else{0.0};
        let measured=&state.ordered_joint_observations[i];
        // Ramp only the reference-velocity term. Position feedback, measured
        // velocity damping, reference geometry, slew and motor caps persist.
        let feed_forward_rate=match startup_scale {Some(scale) if scale<1.0=>rate*scale,_=>rate};
        let raw=gain*(target-measured.position_rad.expect("validated position"))
            -damping*measured.velocity_rad_s.expect("validated velocity")+(1.0+damping)*feed_forward_rate;
        c.requested_target_position_rad=target;c.clamped_target_position_rad=target;c.target_velocity_rad_s=raw.clamp(-limit,limit)*motor_sign;
        c.position_saturated=false;c.velocity_saturated=raw.abs()>limit;c.slew_limited=target!=goals[i];
        c.safety_contribution_rad_s=c.target_velocity_rad_s-raw.clamp(-max_controller_speed,max_controller_speed)*motor_sign;
        if c.slew_limited {slew.push(c.actuator_id.clone());}reference.ordered_target_positions_rad.push(target);rates.push(rate);
    }
    actuation.receipt.schema_version=RECEIPT.to_owned();
    actuation.receipt.recovery_support_plane=Some(SupportPlaneReceipt{
        schema_version:"sporespore_recovery_support_plane_receipt_v1".to_owned(),mode_id:MODE.to_owned(),
        observation_anatomical_axis_mapping:"forward=body_z;up=body_y;right=-body_x".to_owned(),reference_step_duration_s:dt,
        first_step_holds_neutral_reference:initial,zero_amplitude_selects_neutral_goal:initial,
        proposed_torso_height_m:body.y-floor.height_world_m,unrestricted_plane_inside_joint_limits:true,
        ordered_limb_proposals:vec![],reference_slew_limited_actuator_ids:slew,all_limb_contact_claim:false,physical_acceptance_authority:false,
        floor_reference:Some(floor.clone()),feasible_support_plan:None,swing_lift_mode_id:Some("world_endpoint_sinusoidal_lift_with_cubic_forward_path_v1".to_owned()),
        reference_velocity_mode_id:Some(if startup_ramped {STARTUP_MODE}else{"bounded_independent_pose_full_reference_velocity_v1"}.to_owned()),ordered_reference_velocity_rad_s:Some(rates),
        wave_velocity:None,airborne_reference:None,upright_stance:None,stance_latch:None,support_progression:None,support_hold_posture:None,measured_support_transfer:None,
        anchored_body_pose:Some(Receipt{schema_version:"sporespore_anchored_body_pose_receipt_v1".to_owned(),desired_body_position_world_m:body,
            desired_forward_world_unit:forward,desired_body_up_world_unit:Vec3{x:0.0,y:1.0,z:0.0},ordered_foot_targets_world_m:targets,
            ordered_joint_goals_rad:goals,ordered_target_fk_error_m:errors,ordered_lateral_projection_residual_m:lateral,
            ordered_goal_bottom_in_measured_pose_m:bottoms,next_memory:next.clone(),origin_rebase:None,reference_velocity_startup_scale:startup_scale,
            joint_feasible_height:height_receipt,zero_amplitude_velocity_guard:None,zero_amplitude_motor_brake:None,geometry_is_contact_authority:false,physical_acceptance_authority:false}),
    });
    actuation.receipt_sha256=digest_serializable(&actuation.receipt)?;actuation.validate(&compiled.morphology)?;
    Ok((next,reference))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn analytic_targets_reconstruct_complete_swing_and_bounded_body_shifts() {
        for body_x in [-0.035,0.0,0.035] {for n in 0..=72 {
            let u=n as f64/72.0;let x=STEP_LENGTH*smooth(u)-body_x;let down=VERTICAL-if n==0||n==72 {0.0}else{LIFT*(std::f64::consts::PI*u).sin()};
            let(h,k)=ik(x,down,0.182685,0.167315,-0.72,0.72,1.1).unwrap();
            assert!((0.182685*h.sin()+0.167315*(h+k).sin()-x).abs()<1e-12);
            assert!((0.182685*h.cos()+0.167315*(h+k).cos()-down).abs()<1e-12);
        }}
    }
    #[test] fn impossible_and_out_of_joint_bound_targets_refuse_without_projection() {
        for (x,y) in [(0.0,0.36),(0.0,0.1),(-0.2,0.2),(f64::NAN,0.33),(0.0,-0.33)] {
            assert!(ik(x,y,0.182685,0.167315,-0.72,0.72,1.1).is_err());
        }
    }
}
