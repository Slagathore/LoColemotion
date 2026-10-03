use std::collections::HashSet;

use serde::{Deserialize, Serialize};

use crate::schema::{CoreError, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GaitPhase {
    Swing,
    Stance,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LimbGaitState {
    pub limb_id: String,
    pub phase: GaitPhase,
    pub cycle_step: u32,
    pub limb_phase_step: u32,
    pub swing_step: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SemanticGaitState {
    pub schema_version: String,
    pub policy_id: String,
    pub semantic_step: u64,
    pub cycle_step: u32,
    pub ordered_limb_states: Vec<LimbGaitState>,
    pub world_build_count: u32,
    pub physical_acceptance_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SemanticGaitScheduler {
    pub schema_version: String,
    pub policy_id: String,
    pub ordered_limb_ids: Vec<String>,
    pub nominal_phase_offsets_steps: Vec<u32>,
    pub cycle_steps: u32,
    pub swing_steps: u32,
}

impl SemanticGaitScheduler {
    pub fn new(
        policy_id: impl Into<String>,
        ordered_limb_ids: Vec<String>,
        nominal_phase_offsets_steps: Vec<u32>,
        cycle_steps: u32,
        swing_steps: u32,
    ) -> Result<Self> {
        let policy_id = policy_id.into();
        if policy_id.is_empty() {
            return Err(CoreError::Identity("scheduler_policy_id".to_owned()));
        }
        if ordered_limb_ids.is_empty()
            || ordered_limb_ids.len() != nominal_phase_offsets_steps.len()
        {
            return Err(CoreError::Topology(
                "scheduler_limb_phase_cardinality".to_owned(),
            ));
        }
        if cycle_steps == 0 || swing_steps == 0 || swing_steps >= cycle_steps {
            return Err(CoreError::Schema("scheduler_period".to_owned()));
        }
        let mut ids = HashSet::new();
        for id in &ordered_limb_ids {
            if id.is_empty() || !ids.insert(id.clone()) {
                return Err(CoreError::Identity(format!("scheduler_limb_id:{id}")));
            }
        }
        if nominal_phase_offsets_steps
            .iter()
            .any(|offset| *offset >= cycle_steps)
        {
            return Err(CoreError::Schema(
                "scheduler_phase_offset_out_of_range".to_owned(),
            ));
        }
        let unique_offsets: HashSet<_> = nominal_phase_offsets_steps.iter().collect();
        if unique_offsets.len() != nominal_phase_offsets_steps.len() {
            return Err(CoreError::Topology(
                "scheduler_duplicate_phase_offset".to_owned(),
            ));
        }
        Ok(Self {
            schema_version: "sporespore_semantic_gait_scheduler_v1".to_owned(),
            policy_id,
            ordered_limb_ids,
            nominal_phase_offsets_steps,
            cycle_steps,
            swing_steps,
        })
    }

    pub fn evenly_spaced(
        policy_id: impl Into<String>,
        ordered_limb_ids: Vec<String>,
        cycle_steps: u32,
        swing_steps: u32,
    ) -> Result<Self> {
        if ordered_limb_ids.is_empty()
            || cycle_steps < ordered_limb_ids.len() as u32
            || !cycle_steps.is_multiple_of(ordered_limb_ids.len() as u32)
        {
            return Err(CoreError::Schema(
                "scheduler_nonintegral_even_spacing".to_owned(),
            ));
        }
        let stride = cycle_steps / ordered_limb_ids.len() as u32;
        let offsets = (0..ordered_limb_ids.len())
            .map(|index| index as u32 * stride)
            .collect();
        Self::new(
            policy_id,
            ordered_limb_ids,
            offsets,
            cycle_steps,
            swing_steps,
        )
    }

    pub fn gq15_lateral() -> Result<Self> {
        Self::evenly_spaced(
            "g4_gq15_four_cycle_contact_clock_v1",
            ["rear_left", "front_left", "rear_right", "front_right"]
                .into_iter()
                .map(str::to_owned)
                .collect(),
            360,
            72,
        )
    }

    pub fn state_at(&self, semantic_step: u64) -> SemanticGaitState {
        let cycle_step = (semantic_step % u64::from(self.cycle_steps)) as u32;
        let ordered_limb_states = self
            .ordered_limb_ids
            .iter()
            .zip(&self.nominal_phase_offsets_steps)
            .map(|(limb_id, offset)| {
                let limb_phase_step = (cycle_step + self.cycle_steps - *offset) % self.cycle_steps;
                let phase = if limb_phase_step < self.swing_steps {
                    GaitPhase::Swing
                } else {
                    GaitPhase::Stance
                };
                LimbGaitState {
                    limb_id: limb_id.clone(),
                    phase,
                    cycle_step,
                    limb_phase_step,
                    swing_step: (phase == GaitPhase::Swing).then_some(limb_phase_step),
                }
            })
            .collect();
        SemanticGaitState {
            schema_version: "sporespore_semantic_gait_state_v1".to_owned(),
            policy_id: self.policy_id.clone(),
            semantic_step,
            cycle_step,
            ordered_limb_states,
            world_build_count: 0,
            physical_acceptance_authority: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gq15_lateral_order_and_boundaries_are_exact() {
        let scheduler = SemanticGaitScheduler::gq15_lateral().unwrap();
        assert_eq!(
            scheduler.ordered_limb_ids,
            ["rear_left", "front_left", "rear_right", "front_right"]
        );
        assert_eq!(scheduler.nominal_phase_offsets_steps, [0, 90, 180, 270]);
        assert_eq!(
            scheduler.state_at(0).ordered_limb_states[0].phase,
            GaitPhase::Swing
        );
        assert_eq!(
            scheduler.state_at(71).ordered_limb_states[0].phase,
            GaitPhase::Swing
        );
        assert_eq!(
            scheduler.state_at(72).ordered_limb_states[0].phase,
            GaitPhase::Stance
        );
        assert_eq!(
            scheduler.state_at(90).ordered_limb_states[1].phase,
            GaitPhase::Swing
        );
        assert_eq!(scheduler.state_at(360).cycle_step, 0);
        assert_eq!(
            scheduler.state_at(360).ordered_limb_states,
            scheduler.state_at(0).ordered_limb_states
        );
    }

    #[test]
    fn scheduler_is_not_quadruped_hardcoded() {
        for limb_count in [2_usize, 4, 6, 8, 32] {
            let ids = (0..limb_count)
                .map(|index| format!("limb_{index}"))
                .collect::<Vec<_>>();
            let scheduler =
                SemanticGaitScheduler::evenly_spaced("generic_wave", ids, 960, 24).unwrap();
            assert_eq!(scheduler.ordered_limb_ids.len(), limb_count);
            assert_eq!(
                scheduler
                    .state_at(0)
                    .ordered_limb_states
                    .iter()
                    .filter(|state| state.phase == GaitPhase::Swing)
                    .count(),
                1
            );
        }
    }

    #[test]
    fn malformed_schedules_fail_closed() {
        assert!(SemanticGaitScheduler::evenly_spaced("x", vec![], 360, 72).is_err());
        assert!(
            SemanticGaitScheduler::new(
                "x",
                vec!["same".to_owned(), "same".to_owned()],
                vec![0, 90],
                360,
                72
            )
            .is_err()
        );
        assert!(
            SemanticGaitScheduler::new(
                "x",
                vec!["a".to_owned(), "b".to_owned()],
                vec![0, 0],
                360,
                72
            )
            .is_err()
        );
    }
}
