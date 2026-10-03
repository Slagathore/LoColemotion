//! V45: measured body support transfer before a new swing epoch.
//!
//! This computes a bounded reference and an additional preparation interlock.
//! Capsule endpoint projections never substitute for measured contact truth.
use serde::{Deserialize, Deserializer, Serialize};
use crate::canonical::digest_serializable;
use crate::protocol::{Quaternion, StateFrame};
use crate::quadruped::CompiledQuadruped;
use crate::runtime::Candidate35ControllerMemory;
use crate::schema::{CoreError, Result, Vec3};
use crate::stability::OrderedBodyStateV2;
use crate::recovery_extended_support_transfer::ReferenceRange;
use crate::recovery_extended_preparation::PreparationBudget;

pub const POLICY: &str = "sporespore_balanced_wave_recovery_measured_support_transfer_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_measured_support_transfer_profile_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_measured_support_transfer_memory_v1";
pub const MODE: &str = "measured_com_foreaft_support_transfer_before_swing_v1";
pub const RECEIPT: &str = "sporespore_recovery_measured_support_transfer_controller_step_receipt_v1";
pub const BODY_FRAME: &str = "sporespore_measured_walking_body_frame_v1";
pub const TARGET_MARGIN: f64 = 0.025;
pub const RELEASE_MARGIN: f64 = 0.020;
pub const RELEASE_SPEED: f64 = 0.030;
pub const RELEASE_ANGULAR_SPEED: f64 = 0.15;
pub const RELEASE_TILT: f64 = 0.05;
pub const RELEASE_DWELL: u32 = 6;
pub const MAX_PREPARATION: u32 = 240;
pub const MAX_BIAS: f64 = 0.25;
pub const MAX_BIAS_RATE: f64 = 0.60;
pub const POSITION_RATE_GAIN: f64 = 4.0;
pub const VELOCITY_DAMPING: f64 = 1.5;
const LIMBS: [&str; 4] = ["front_left", "front_right", "rear_left", "rear_right"];

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MeasuredBodyFrame {
    pub schema_version: String,
    pub semantic_step: u64,
    pub sample_time_s: f64,
    pub frame_id: String,
    pub adapter_capability_sha256: String,
    pub source_measurement: bool,
    pub ordered_body_states: Vec<OrderedBodyStateV2>,
}

pub(crate) fn deserialize_present<'de, D: Deserializer<'de>>(deserializer: D)
    -> std::result::Result<Option<MeasuredBodyFrame>, D::Error>
{
    MeasuredBodyFrame::deserialize(deserializer).map(Some)
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Memory {
    pub hip_bias_rad: f64,
    pub prepared_limb_id: Option<String>,
    pub prepared_swing_start_gait_step: Option<u64>,
    pub preparation_commands: u32,
    pub ready_dwell_commands: u32,
}

impl Memory {
    pub(crate) fn validate(&self, initial: bool) -> Result<()> {
        self.validate_range(initial, ReferenceRange::Original)
    }
    pub(crate) fn validate_range(&self, initial: bool, range: ReferenceRange) -> Result<()> {
        self.validate_range_and_preparation(initial, range, PreparationBudget::Original)
    }
    pub(crate) fn validate_range_and_preparation(&self, initial: bool, range: ReferenceRange,
        budget: PreparationBudget) -> Result<()> {
        ensure(self.hip_bias_rad.is_finite() && self.hip_bias_rad.abs() <= range.maximum_bias()
            && self.preparation_commands <= budget.maximum()
            && self.ready_dwell_commands < RELEASE_DWELL
            && self.ready_dwell_commands <= self.preparation_commands
            && self.prepared_limb_id.is_some() == self.prepared_swing_start_gait_step.is_some()
            && self.prepared_limb_id.as_ref().is_none_or(|id| LIMBS.contains(&id.as_str()))
            && (!initial || *self == Self::default()), "memory_domain")
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Measurement {
    pub body_frame_sha256: String,
    pub whole_mass_kg: f64,
    pub measured_com_position_world_m: Vec3,
    pub measured_com_velocity_world_m_s: Vec3,
    pub anatomical_forward_horizontal_world_unit: Vec3,
    pub ordered_measured_capsule_endpoints_world_m: Vec<Vec3>,
    pub horizontal_com_speed_m_s: f64,
    pub forward_com_speed_m_s: f64,
    pub torso_angular_speed_rad_s: f64,
    pub torso_tilt_rad: f64,
    pub geometry_is_contact_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub source_semantic_step: u64,
    pub measurement: Measurement,
    pub incoming_memory: Memory,
    pub next_memory: Memory,
    pub planned_swing_limb_id: Option<String>,
    pub planned_swing_start_gait_step: Option<u64>,
    pub remaining_triangle_margin_m: Option<f64>,
    pub requested_foreaft_displacement_m: Option<f64>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub required_support_limb_ids: Option<Vec<String>>,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub planned_swing_contact_required: Option<bool>,
    pub readiness_conditions_met: bool,
    pub preparation_held: bool,
    pub preparation_released_this_command: bool,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub maximum_preparation_commands: Option<u32>,
    pub effective_phase_progression_held: bool,
    /// The inherited guard is a recommendation BEFORE this preparation gate.
    /// Its selected phases must not be mistaken for the final engine clocks.
    pub inherited_guard_recommendation: crate::recovery_support_progression::Receipt,
    pub effective_selected_phases: [u64; 4],
    pub requested_hip_bias_rate_rad_s: f64,
    pub applied_hip_bias_rate_rad_s: f64,
    pub hip_bias_saturated: bool,
    #[serde(default, skip_serializing_if="Option::is_none")]
    pub maximum_absolute_reference_bias_rad: Option<f64>,
    pub reference_comparison_uses_current_bias: bool,
    pub physical_acceptance_authority: bool,
}

fn ensure(value: bool, field: &str) -> Result<()> {
    if value { Ok(()) } else { Err(CoreError::Frame(format!("measured_support_transfer_{field}"))) }
}
fn add(a: Vec3, b: Vec3) -> Vec3 { Vec3 { x:a.x+b.x, y:a.y+b.y, z:a.z+b.z } }
fn sub(a: Vec3, b: Vec3) -> Vec3 { Vec3 { x:a.x-b.x, y:a.y-b.y, z:a.z-b.z } }
fn mul(a: Vec3, s: f64) -> Vec3 { Vec3 { x:a.x*s, y:a.y*s, z:a.z*s } }
fn dot(a: Vec3, b: Vec3) -> f64 { a.x*b.x+a.y*b.y+a.z*b.z }
fn norm(a: Vec3) -> f64 { dot(a,a).sqrt() }
fn cross(a: Vec3, b: Vec3) -> Vec3 { Vec3 {x:a.y*b.z-a.z*b.y,y:a.z*b.x-a.x*b.z,z:a.x*b.y-a.y*b.x} }
fn rotate(q: Quaternion, v: Vec3) -> Vec3 {
    let axis=Vec3 {x:q.x,y:q.y,z:q.z};
    let t=mul(cross(axis,v),2.0);
    add(v,add(mul(t,q.w),cross(axis,t)))
}

pub(crate) fn measure(compiled: &CompiledQuadruped, state: &StateFrame,
    frame: &MeasuredBodyFrame) -> Result<Measurement>
{
    ensure(frame.schema_version == BODY_FRAME
        && frame.frame_id == crate::recovery_floor_reference::FRAME_ID
        && frame.source_measurement && frame.semantic_step == state.semantic_step
        && frame.sample_time_s.is_finite() && frame.sample_time_s == state.sample_time_s
        && frame.adapter_capability_sha256 == state.adapter_capability_sha256, "body_frame_binding")?;
    let specs=&compiled.morphology.morphology_spec.bodies;
    ensure(frame.ordered_body_states.len() == specs.len() && specs.len() == 9, "body_population")?;
    let mut mass=0.0; let mut position=Vec3::ZERO; let mut velocity=Vec3::ZERO;
    for (spec,body) in specs.iter().zip(&frame.ordered_body_states) {
        ensure(body.body_id==spec.body_id, "body_order")?;
        body.pose_world.position_m.finite("measured_support_transfer_position")?;
        body.pose_world.orientation_xyzw.validate("measured_support_transfer_orientation")?;
        body.twist_world.linear_velocity_m_s.finite("measured_support_transfer_velocity")?;
        body.twist_world.angular_velocity_rad_s.finite("measured_support_transfer_angular_velocity")?;
        // The inherited walking body-local basis is rotated about Y. This
        // finite route has centered inertias; do not silently generalize it.
        ensure(spec.center_of_mass_local_m == Vec3::ZERO && spec.mass_kg.is_finite() && spec.mass_kg>0.0, "centered_mass_mapping")?;
        mass+=spec.mass_kg;
        position=add(position,mul(body.pose_world.position_m,spec.mass_kg));
        velocity=add(velocity,mul(body.twist_world.linear_velocity_m_s,spec.mass_kg));
    }
    let torso=&frame.ordered_body_states[0];
    ensure(torso.body_id=="torso" && norm(sub(torso.pose_world.position_m,state.base_pose_world.position_m))<1e-9
        && norm(sub(torso.twist_world.linear_velocity_m_s,state.base_twist_world.linear_velocity_m_s))<1e-9
        && norm(sub(torso.twist_world.angular_velocity_rad_s,state.base_twist_world.angular_velocity_rad_s))<1e-9,
        "torso_binding")?;
    for axis in [Vec3 {x:1.0,y:0.0,z:0.0},Vec3 {x:0.0,y:1.0,z:0.0}] {
        ensure(norm(sub(rotate(torso.pose_world.orientation_xyzw,axis),rotate(state.base_pose_world.orientation_xyzw,axis)))<1e-6,
            "torso_orientation_binding")?;
    }
    position=mul(position,1.0/mass); velocity=mul(velocity,1.0/mass);
    ensure(mass.is_finite(), "whole_mass_nonfinite")?;
    position.finite("measured_support_transfer_com_position")?;
    velocity.finite("measured_support_transfer_com_velocity")?;
    let mut forward=rotate(state.base_pose_world.orientation_xyzw,Vec3 {x:0.0,y:0.0,z:1.0});
    forward.y=0.0; ensure(norm(forward)>1e-9,"forward_projection")?;
    forward=mul(forward,1.0/norm(forward));
    let up=rotate(state.base_pose_world.orientation_xyzw,Vec3 {x:0.0,y:1.0,z:0.0});
    ensure(norm(torso.twist_world.angular_velocity_rad_s).is_finite()
        && velocity.x.hypot(velocity.z).is_finite(), "derived_speed_nonfinite")?;
    let mut feet=Vec::with_capacity(4);
    for limb in LIMBS {
        let site=compiled.morphology.morphology_spec.contact_sites.iter()
            .find(|s|s.contact_site_id==format!("{limb}_foot"))
            .ok_or_else(||CoreError::Contact("measured_support_transfer_foot_site".to_owned()))?;
        ensure(site.local_center_m.x==0.0 && site.local_center_m.z==0.0 && site.body_id==format!("{limb}_distal"), "capsule_axis_mapping")?;
        let body=frame.ordered_body_states.iter().find(|b|b.body_id==site.body_id)
            .ok_or_else(||CoreError::Order("measured_support_transfer_foot_body".to_owned()))?;
        feet.push(add(body.pose_world.position_m,rotate(body.pose_world.orientation_xyzw,site.local_center_m)));
    }
    Ok(Measurement {body_frame_sha256:digest_serializable(frame)?,whole_mass_kg:mass,
        measured_com_position_world_m:position,measured_com_velocity_world_m_s:velocity,
        anatomical_forward_horizontal_world_unit:forward,ordered_measured_capsule_endpoints_world_m:feet,
        horizontal_com_speed_m_s:velocity.x.hypot(velocity.z),forward_com_speed_m_s:dot(velocity,forward),
        torso_angular_speed_rad_s:norm(torso.twist_world.angular_velocity_rad_s),
        torso_tilt_rad:up.y.clamp(-1.0,1.0).acos(),geometry_is_contact_authority:false})
}

/// Signed minimum edge distance and nearest fore/aft displacement satisfying
/// all three inward halfspaces. Positive margin is inside the triangle.
pub(crate) fn triangle(point: Vec3, forward: Vec3, vertices: &[Vec3], target: f64) -> Result<(f64,f64)> {
    ensure(vertices.len()==3 && target.is_finite() && target>=0.0,"triangle_shape")?;
    point.finite("measured_support_transfer_triangle_point")?;
    forward.finite("measured_support_transfer_triangle_forward")?;
    let mut ordered=vertices.to_vec();
    let center=mul(ordered.iter().copied().fold(Vec3::ZERO,add),1.0/3.0);
    for v in &ordered {v.finite("measured_support_transfer_triangle_vertex")?;}
    ordered.sort_by(|a,b|(a.z-center.z).atan2(a.x-center.x).total_cmp(&(b.z-center.z).atan2(b.x-center.x)));
    let area=(0..3).map(|i|ordered[i].x*ordered[(i+1)%3].z-ordered[i].z*ordered[(i+1)%3].x).sum::<f64>();
    ensure(area>1e-12,"degenerate_triangle")?;
    let (mut margin,mut low,mut high)=(f64::INFINITY,f64::NEG_INFINITY,f64::INFINITY);
    for i in 0..3 {
        let (a,b)=(ordered[i],ordered[(i+1)%3]);
        let length=(b.x-a.x).hypot(b.z-a.z); ensure(length>1e-12,"degenerate_edge")?;
        let inward=Vec3 {x:-(b.z-a.z)/length,y:0.0,z:(b.x-a.x)/length};
        let distance=dot(inward,sub(point,a)); let slope=dot(inward,forward);
        margin=margin.min(distance);
        if slope>1e-12 {low=low.max((target-distance)/slope);}
        else if slope < -1e-12 {high=high.min((target-distance)/slope);}
        else {ensure(distance>=target,"lateral_margin_unreachable")?;}
    }
    ensure(low<=high && margin.is_finite(),"foreaft_margin_unreachable")?;
    let displacement=if low>0.0 {low} else if high<0.0 {high} else {0.0};
    ensure(displacement.is_finite(),"displacement_nonfinite")?;
    Ok((margin,displacement))
}

fn phases(memory: &Candidate35ControllerMemory) -> Result<[u64;4]> {
    let mut result=[0;4];
    for (i,limb) in LIMBS.iter().enumerate() {
        let (index,m)=memory.ordered_limb_memory.iter().enumerate().find(|(_,m)|m.limb_id==*limb)
            .ok_or_else(||CoreError::Order("measured_support_transfer_limb_memory".to_owned()))?;
        result[i]=(m.gait_step%360+360-index as u64*90)%360;
    }
    Ok(result)
}

pub(crate) fn decide(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, measured: Measurement,
    active: bool, dt: f64, leg_length: f64, inherited: crate::recovery_support_progression::Receipt) -> Result<Receipt>
{
    decide_contact_population(memory,incoming,proposed,state,measured,active,dt,leg_length,inherited,false,ReferenceRange::Original,PreparationBudget::Original)
}
pub(crate) fn decide_remaining_support(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, measured: Measurement,
    active: bool, dt: f64, leg_length: f64, inherited: crate::recovery_support_progression::Receipt) -> Result<Receipt>
{
    decide_contact_population(memory,incoming,proposed,state,measured,active,dt,leg_length,inherited,true,ReferenceRange::Original,PreparationBudget::Original)
}
pub(crate) fn decide_extended_remaining_support(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, measured: Measurement,
    active: bool, dt: f64, leg_length: f64, inherited: crate::recovery_support_progression::Receipt) -> Result<Receipt>
{
    decide_contact_population(memory,incoming,proposed,state,measured,active,dt,leg_length,inherited,true,ReferenceRange::Extended,PreparationBudget::Original)
}
pub(crate) fn decide_extended_preparation(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, measured: Measurement,
    active: bool, dt: f64, leg_length: f64, inherited: crate::recovery_support_progression::Receipt) -> Result<Receipt>
{
    decide_contact_population(memory,incoming,proposed,state,measured,active,dt,leg_length,inherited,true,ReferenceRange::Extended,PreparationBudget::Extended)
}
#[allow(clippy::too_many_arguments)]
fn decide_contact_population(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, measured: Measurement,
    active: bool, dt: f64, leg_length: f64, inherited: crate::recovery_support_progression::Receipt,
    remaining_only:bool, range:ReferenceRange, budget:PreparationBudget) -> Result<Receipt>
{
    memory.validate_range_and_preparation(incoming.last_semantic_step.is_none(),range,budget)?;
    ensure(dt.is_finite() && (dt==0.0 || (dt-1.0/120.0).abs()<1e-9)
        && leg_length.is_finite() && leg_length>0.0,"clock_or_leg_length")?;
    let before=phases(incoming)?; let after=phases(proposed)?;
    let swing=(0..4).filter(|i|active && after[*i]<=crate::runtime::SWING_STEPS).collect::<Vec<_>>();
    ensure(swing.len()<=1,"overlapping_swing_epochs")?;
    let mut next=memory.clone();
    let (mut planned,mut epoch,mut margin,mut displacement)=(None,None,None,None);
    let (mut ready,mut held,mut released)=(false,false,false);
    let (mut requested_rate,mut applied_rate)=(0.0,0.0);
    let mut saturated=false;
    if let Some(&i)=swing.first() {
        let limb=LIMBS[i];
        let clock=proposed.ordered_limb_memory.iter().find(|m|m.limb_id==limb).expect("checked limb").gait_step;
        let start=clock.checked_sub(after[i]).ok_or_else(||CoreError::Time("measured_support_transfer_epoch".to_owned()))?;
        planned=Some(limb.to_owned()); epoch=Some(start);
        let feet=measured.ordered_measured_capsule_endpoints_world_m.iter().enumerate()
            .filter_map(|(index,p)|(index!=i).then_some(*p)).collect::<Vec<_>>();
        let (distance,shift)=triangle(measured.measured_com_position_world_m,
            measured.anatomical_forward_horizontal_world_unit,&feet,TARGET_MARGIN)?;
        margin=Some(distance); displacement=Some(shift);
        requested_rate=-(POSITION_RATE_GAIN*shift-VELOCITY_DAMPING*measured.forward_com_speed_m_s)/leg_length;
        applied_rate=requested_rate.clamp(-MAX_BIAS_RATE,MAX_BIAS_RATE);
        let requested_bias=memory.hip_bias_rad+dt*applied_rate;
        next.hip_bias_rad=requested_bias.clamp(-range.maximum_bias(),range.maximum_bias());
        saturated=requested_bias!=next.hip_bias_rad || applied_rate!=requested_rate;
        applied_rate=if dt>0.0 {(next.hip_bias_rad-memory.hip_bias_rad)/dt} else {0.0};
        let all_contact=state.ordered_contact_observations.len()==4 && state.ordered_contact_observations.iter()
            .enumerate().all(|(index,c)| if remaining_only && index==i {
                c.presence.is_some() && c.bears_support.is_some()
            } else {c.presence==Some(true) && c.bears_support==Some(true)});
        ready=all_contact && distance>=RELEASE_MARGIN
            && measured.horizontal_com_speed_m_s<=RELEASE_SPEED
            && measured.torso_angular_speed_rad_s<=RELEASE_ANGULAR_SPEED
            && measured.torso_tilt_rad<=RELEASE_TILT;
        if memory.prepared_limb_id.as_deref()!=Some(limb) || memory.prepared_swing_start_gait_step!=Some(start) {
            let dwell=if ready {memory.ready_dwell_commands+1} else {0};
            if dwell>=RELEASE_DWELL {
                next.prepared_limb_id=planned.clone(); next.prepared_swing_start_gait_step=epoch;
                next.preparation_commands=0; next.ready_dwell_commands=0; released=true;
            } else {
                ensure(memory.preparation_commands<budget.maximum(),"preparation_timeout")?;
                next.preparation_commands=memory.preparation_commands+1;
                next.ready_dwell_commands=dwell; held=true;
            }
        } else { next.preparation_commands=0; next.ready_dwell_commands=0; }
    } else {
        next.preparation_commands=0; next.ready_dwell_commands=0;
        if !active {next.prepared_limb_id=None;next.prepared_swing_start_gait_step=None;}
    }
    let effective=held || inherited.phase_progression_held;
    Ok(Receipt {schema_version:"sporespore_measured_support_transfer_receipt_v1".to_owned(),
        source_semantic_step:state.semantic_step,measurement:measured,incoming_memory:memory.clone(),next_memory:next,
        planned_swing_limb_id:planned,planned_swing_start_gait_step:epoch,remaining_triangle_margin_m:margin,
        requested_foreaft_displacement_m:displacement,
        required_support_limb_ids:remaining_only.then(|| LIMBS.iter().enumerate().filter_map(|(i,id)|
            (swing.first().is_some_and(|planned|*planned!=i)).then(||(*id).to_owned())).collect()),
        planned_swing_contact_required:remaining_only.then_some(false),readiness_conditions_met:ready,preparation_held:held,
        maximum_preparation_commands:budget.receipt_bound(),
        maximum_absolute_reference_bias_rad:range.receipt_bound(),
        preparation_released_this_command:released,effective_phase_progression_held:effective,
        inherited_guard_recommendation:inherited,effective_selected_phases:if effective {before} else {after},
        requested_hip_bias_rate_rad_s:requested_rate,applied_hip_bias_rate_rad_s:applied_rate,
        hip_bias_saturated:saturated,reference_comparison_uses_current_bias:true,physical_acceptance_authority:false})
}
