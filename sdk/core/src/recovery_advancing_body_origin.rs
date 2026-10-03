//! V48 recenters coordinates when planned stance anchors advance.
//! This coordinate change preserves the desired body pose and all bias bounds.
use serde::{Serialize,Deserialize};
use crate::schema::{CoreError,Result,Vec3};
use crate::recovery_anchored_body_pose::{Memory,STEP_LENGTH};
use crate::recovery_measured_support_transfer::Memory as TransferMemory;
use crate::recovery_extended_support_transfer::ReferenceRange;
pub const POLICY:&str="sporespore_balanced_wave_recovery_advancing_body_origin_v1";
pub const MEMORY:&str="sporespore_balanced_wave_recovery_advancing_body_origin_memory_v1";
pub const PROFILE:&str="sporespore_balanced_wave_recovery_advancing_body_origin_profile_v1";
pub const RECEIPT:&str="sporespore_recovery_advancing_body_origin_controller_step_receipt_v1";
#[derive(Debug,Clone,PartialEq,Serialize,Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version:String,pub committed_planned_stance_limb_ids:Vec<String>,pub origin_forward_advance_m:f64,
    pub previous_origin_world_m:Vec3,pub next_origin_world_m:Vec3,pub bias_before_recenter_rad:f64,pub bias_after_recenter_rad:f64,
    pub body_translation_before_recenter_world_m:Vec3,pub body_translation_after_recenter_world_m:Vec3,
    pub parent_transfer_next_memory_role:String,pub geometry_is_contact_authority:bool,pub physical_acceptance_authority:bool,
    #[serde(default,skip_serializing_if="Option::is_none")]
    pub maximum_absolute_reference_bias_rad:Option<f64>,
}
fn ensure(v:bool,c:&str)->Result<()> {if v {Ok(())}else{Err(CoreError::Frame(format!("advancing_body_origin_{c}")))}}
fn shift(p:Vec3,f:Vec3,d:f64)->Vec3 {Vec3{x:p.x+f.x*d,y:p.y+f.y*d,z:p.z+f.z*d}}
fn dot(a:Vec3,b:Vec3)->f64 {a.x*b.x+a.y*b.y+a.z*b.z}
fn sub(a:Vec3,b:Vec3)->Vec3 {Vec3{x:a.x-b.x,y:a.y-b.y,z:a.z-b.z}}
pub(crate) fn rebase(previous:Option<&Memory>,next:&mut Memory,transfer:&mut TransferMemory,leg_length:f64)->Result<Option<Receipt>> {
    rebase_range(previous,next,transfer,leg_length,ReferenceRange::Original)
}
pub(crate) fn rebase_extended(previous:Option<&Memory>,next:&mut Memory,transfer:&mut TransferMemory,leg_length:f64)->Result<Option<Receipt>> {
    rebase_range(previous,next,transfer,leg_length,ReferenceRange::Extended)
}
fn rebase_range(previous:Option<&Memory>,next:&mut Memory,transfer:&mut TransferMemory,leg_length:f64,range:ReferenceRange)->Result<Option<Receipt>> {
    let Some(old)=previous else{return Ok(None)};
    ensure(leg_length.is_finite() && leg_length>0.0 && old.ordered_feet.len()==4 && next.ordered_feet.len()==4
        && old.origin_world_m==next.origin_world_m && old.forward_world_unit==next.forward_world_unit,"context")?;
    let mut distance=0.0;let mut committed=Vec::new();
    for (a,b) in old.ordered_feet.iter().zip(&next.ordered_feet) {
        ensure(a.limb_id==b.limb_id,"limb_identity")?;let delta=sub(b.anchor_world_m,a.anchor_world_m);
        if delta!=Vec3::ZERO {
            let forward=dot(delta,next.forward_world_unit);let residual=sub(delta,shift(Vec3::ZERO,next.forward_world_unit,STEP_LENGTH));
            ensure((forward-STEP_LENGTH).abs()<1e-12 && dot(residual,residual).sqrt()<1e-12
                && a.swing_epoch.is_some() && b.swing_epoch.is_none(),"planned_anchor_transition")?;
            distance+=forward/4.0;committed.push(b.limb_id.clone());
        }
    }
    if committed.is_empty(){return Ok(None)}
    let before=transfer.hip_bias_rad;let after=before+distance/leg_length;
    ensure(before.is_finite() && before.abs()<=range.maximum_bias() && after.is_finite() && after.abs()<=range.maximum_bias(),"bias_bound")?;
    let origin=next.origin_world_m;let advanced=shift(origin,next.forward_world_unit,distance);
    let pose_before=shift(origin,next.forward_world_unit,-leg_length*before);let pose_after=shift(advanced,next.forward_world_unit,-leg_length*after);
    ensure(dot(sub(pose_before,pose_after),sub(pose_before,pose_after)).sqrt()<1e-12,"pose_continuity")?;
    // All checks precede mutation. This records a coordinate change, not a
    // physical body shift, extra motor velocity, or inferred landing contact.
    next.origin_world_m=advanced;transfer.hip_bias_rad=after;
    Ok(Some(Receipt{schema_version:"sporespore_advancing_body_origin_receipt_v1".to_owned(),committed_planned_stance_limb_ids:committed,
        origin_forward_advance_m:distance,previous_origin_world_m:origin,next_origin_world_m:advanced,bias_before_recenter_rad:before,bias_after_recenter_rad:after,
        body_translation_before_recenter_world_m:pose_before,body_translation_after_recenter_world_m:pose_after,
        parent_transfer_next_memory_role:"before_coordinate_recenter_actual_next_memory_is_output_next_memory".to_owned(),
        geometry_is_contact_authority:false,physical_acceptance_authority:false,maximum_absolute_reference_bias_rad:range.receipt_bound()}))
}
#[cfg(test)] mod tests {
    use super::*;
    use crate::recovery_anchored_body_pose::FootMemory;
    fn pair()->(Memory,Memory) {
        let feet=["front_left","front_right","rear_left","rear_right"].iter().map(|id|FootMemory{limb_id:(*id).to_owned(),anchor_world_m:Vec3::ZERO,swing_start_world_m:None,swing_epoch:None}).collect::<Vec<_>>();
        let mut old=Memory{origin_world_m:Vec3::ZERO,forward_world_unit:Vec3{x:0.6,y:0.0,z:0.8},start_time_s:0.0,last_sample_time_s:0.0,ordered_feet:feet,last_body_reference_world_m:Vec3::ZERO,ordered_last_targets_world_m:vec![Vec3::ZERO;4],height_correction_m:None};
        old.ordered_feet[0].swing_epoch=Some(90);old.ordered_feet[0].swing_start_world_m=Some(Vec3::ZERO);
        let mut next=old.clone();next.ordered_feet[0].anchor_world_m=shift(Vec3::ZERO,old.forward_world_unit,STEP_LENGTH);next.ordered_feet[0].swing_epoch=None;next.ordered_feet[0].swing_start_world_m=None;(old,next)
    }
    #[test] fn recenters_planned_anchor_without_body_pose_jump_or_relaxing_bias_bounds() {
        for bias in [-0.25,-0.1,0.0,0.07] {
            let(old,mut next)=pair();let mut t=TransferMemory{hip_bias_rad:bias,..Default::default()};let r=rebase(Some(&old),&mut next,&mut t,0.35).unwrap().unwrap();
            assert!((r.origin_forward_advance_m-0.015).abs()<1e-15);assert!((t.hip_bias_rad-bias-0.015/0.35).abs()<1e-15);
            assert!(dot(sub(r.body_translation_before_recenter_world_m,r.body_translation_after_recenter_world_m),sub(r.body_translation_before_recenter_world_m,r.body_translation_after_recenter_world_m))<1e-28);
            assert!(rebase(Some(&next.clone()),&mut next,&mut t,0.35).unwrap().is_none());
        }
    }
    #[test] fn invalid_transition_and_exhausted_recenter_bound_leave_memory_unchanged() {
        for kind in 0..3 {
            let(old,mut next)=pair();let mut t=TransferMemory{hip_bias_rad:if kind==0 {0.24}else{0.0},..Default::default()};
            if kind==1 {next.ordered_feet[0].anchor_world_m.y=0.01;}if kind==2 {next.ordered_feet[0].limb_id="wrong".to_owned();}
            let before=next.clone();let tm=t.clone();assert!(rebase(Some(&old),&mut next,&mut t,0.35).is_err());assert_eq!(before,next);assert_eq!(tm,t);
        }
    }
    #[test] fn extended_recenter_preserves_pose_and_enforces_its_distinct_bound() {
        let (old, mut next)=pair();
        let mut transfer=TransferMemory{hip_bias_rad:0.25,..Default::default()};
        let before=next.clone();let original_transfer=transfer.clone();
        assert!(rebase(Some(&old),&mut next,&mut transfer,0.35).is_err());
        assert_eq!(before,next);assert_eq!(original_transfer,transfer);
        let receipt=rebase_extended(Some(&old),&mut next,&mut transfer,0.35).unwrap().unwrap();
        assert_eq!(Some(0.30),receipt.maximum_absolute_reference_bias_rad);
        assert!(transfer.hip_bias_rad>0.25 && transfer.hip_bias_rad<=0.30);
        assert!(dot(sub(receipt.body_translation_before_recenter_world_m,receipt.body_translation_after_recenter_world_m),
                    sub(receipt.body_translation_before_recenter_world_m,receipt.body_translation_after_recenter_world_m))<1e-28);
        let (old,mut next)=pair();let before=next.clone();
        let mut transfer=TransferMemory{hip_bias_rad:0.28,..Default::default()};let saved=transfer.clone();
        assert!(rebase_extended(Some(&old),&mut next,&mut transfer,0.35).is_err());
        assert_eq!(before,next);assert_eq!(saved,transfer);
    }
}
