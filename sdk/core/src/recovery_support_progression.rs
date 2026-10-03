//! V43: bounded schedule interlock, never a contact or force estimator.
use serde::{Deserialize, Serialize};
use crate::protocol::{ContactObservation, StateFrame};
use crate::runtime::Candidate35ControllerMemory;
use crate::schema::{CoreError, Result};

pub const POLICY: &str = "sporespore_balanced_wave_recovery_support_progression_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_support_progression_profile_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_support_progression_memory_v1";
pub const MODE: &str = "truthful_stance_support_bounded_phase_hold_v1";
pub const RECEIPT: &str = "sporespore_recovery_support_progression_controller_step_receipt_v1";
pub const MAX_HOLD: u32 = crate::runtime::MAXIMUM_GATE_HOLD_STEPS;
pub const CLEAR_DWELL: u32 = crate::runtime::MINIMUM_GATE_DWELL_STEPS;
const LIMBS: [&str;4] = ["front_left","front_right","rear_left","rear_right"];

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Memory {
    pub held_steps: u32,
    pub clear_dwell_steps: u32,
}

impl Memory {
    pub(crate) fn validate(&self, initial: bool) -> Result<()> {
        if self.held_steps > MAX_HOLD || self.clear_dwell_steps >= CLEAR_DWELL
            || self.clear_dwell_steps > self.held_steps
            || (initial && *self != Self::default()) {
            return Err(CoreError::Schema("support_progression_memory_domain".to_owned()));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LimbReceipt {
    pub limb_id: String,
    pub incoming_phase: u64,
    pub proposed_phase: u64,
    pub selected_phase: u64,
    pub current_or_proposed_swing: bool,
    pub proposed_stance_support_required: bool,
    pub precommand_contact: ContactObservation,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub source_semantic_step: u64,
    pub enabled: bool,
    pub incoming_memory: Memory,
    pub next_memory: Memory,
    pub ordered_limbs: Vec<LimbReceipt>,
    pub missing_support_limb_ids: Vec<String>,
    pub phase_progression_held: bool,
    pub minimum_clear_dwell_steps: u32,
    pub maximum_held_commands: u32,
    pub physical_acceptance_authority: bool,
}

fn phase(memory: &Candidate35ControllerMemory, limb: &str) -> Result<u64> {
    let (index, entry) = memory.ordered_limb_memory.iter().enumerate()
        .find(|(_,m)|m.limb_id==limb)
        .ok_or_else(||CoreError::Order("support_progression_limb_memory".to_owned()))?;
    Ok((entry.gait_step % 360 + 360 - index as u64*90) % 360)
}

pub(crate) fn decide(memory: &Memory, incoming: &Candidate35ControllerMemory,
    proposed: &Candidate35ControllerMemory, state: &StateFrame, active: bool) -> Result<Receipt> {
    memory.validate(incoming.last_semantic_step.is_none())?;
    let mut limbs = Vec::with_capacity(4);
    let mut missing = Vec::new();
    for limb in LIMBS {
        let before = phase(incoming,limb)?;
        let after = phase(proposed,limb)?;
        let contact = state.ordered_contact_observations.iter()
            .find(|c|c.contact_site_id==format!("{limb}_foot"))
            .ok_or_else(||CoreError::Contact("support_progression_contact_missing".to_owned()))?;
        let (Some(presence),Some(bearing)) = (contact.presence,contact.bears_support) else {
            return Err(CoreError::Contact("support_progression_contact_unavailable".to_owned()));
        };
        if !presence && bearing {
            return Err(CoreError::Contact("support_progression_contact_contradictory".to_owned()));
        }
        // Phase 72 is the existing landing/recontact boundary, not stance.
        let required = after > crate::runtime::SWING_STEPS;
        if required && !(presence && bearing) { missing.push(limb.to_owned()); }
        limbs.push(LimbReceipt {limb_id:limb.to_owned(),incoming_phase:before,proposed_phase:after,
            selected_phase:after,current_or_proposed_swing:before<=crate::runtime::SWING_STEPS
                || after<=crate::runtime::SWING_STEPS,
            proposed_stance_support_required:required,precommand_contact:contact.clone()});
    }
    let enabled = active && limbs.iter().any(|l|l.current_or_proposed_swing);
    let clear = if missing.is_empty() {memory.clear_dwell_steps+1} else {0};
    let held = enabled && (!missing.is_empty() || (memory.held_steps>0 && clear<CLEAR_DWELL));
    if held && memory.held_steps == MAX_HOLD {
        return Err(CoreError::Capability("support_progression_hold_timeout".to_owned()));
    }
    let next = if held {Memory {held_steps:memory.held_steps+1,clear_dwell_steps:clear}}
        else {Memory::default()};
    if held {for limb in &mut limbs {limb.selected_phase=limb.incoming_phase;}}
    Ok(Receipt {schema_version:"sporespore_support_progression_receipt_v1".to_owned(),
        source_semantic_step:state.semantic_step,enabled,incoming_memory:memory.clone(),next_memory:next,
        ordered_limbs:limbs,missing_support_limb_ids:missing,phase_progression_held:held,
        minimum_clear_dwell_steps:CLEAR_DWELL,maximum_held_commands:MAX_HOLD,
        physical_acceptance_authority:false})
}
