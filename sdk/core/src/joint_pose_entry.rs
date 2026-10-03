//! Bounded joint-pose entry, owned separately from the walking policy.
//! A reference pose is never evidence of support, settling, or successful entry.
use crate::protocol::{ActuationFrame, MotionCommand, StateFrame};
use crate::quadruped::CompiledQuadruped;
use crate::schema::{CoreError, Result};
use serde::{Deserialize, Serialize};

pub const POLICY: &str = "sporespore_balanced_wave_joint_pose_entry_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_joint_pose_entry_profile_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_joint_pose_entry_memory_v1";
pub const MAX_COMMANDS: u64 = 240;
pub const MAX_SPEED: f64 = 0.75;
const DT: f64 = 1.0 / 120.0;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Memory {
    pub first_semantic_step: u64,
    pub start_sample_time_s: f64,
    pub last_sample_time_s: f64,
    pub completed_reference_intervals: u64,
    pub ramp_intervals: u64,
    pub ordered_initial_positions_rad: [f64; 8],
    pub ordered_goal_positions_rad: [f64; 8],
    pub ordered_previous_references_rad: [f64; 8],
    pub reference_ramp_complete: bool,
}

fn ensure(ok: bool, reason: &str) -> Result<()> {
    if ok {
        Ok(())
    } else {
        Err(CoreError::Frame(format!("joint_pose_entry_{reason}")))
    }
}

pub(crate) fn goals(compiled: &CompiledQuadruped) -> Result<[f64; 8]> {
    let actuators = &compiled.morphology.morphology_spec.actuators;
    ensure(actuators.len() == 8, "actuator_population")?;
    let g = &compiled.geometry;
    let mut result = [0.0; 8];
    for i in 0..4 {
        let hip = &actuators[2 * i];
        let knee = &actuators[2 * i + 1];
        let (h, k) = crate::recovery_anchored_body_pose::ik(
            0.0,
            crate::recovery_anchored_body_pose::VERTICAL,
            g.upper_length_m,
            g.lower_length_m,
            hip.minimum_target_position_rad,
            hip.maximum_target_position_rad,
            knee.maximum_target_position_rad,
        )?;
        ensure(k >= knee.minimum_target_position_rad, "knee_minimum")?;
        result[2 * i] = h;
        result[2 * i + 1] = k;
    }
    Ok(result)
}

fn duration(initial: &[f64; 8], goal: &[f64; 8]) -> u64 {
    let distance = initial
        .iter()
        .zip(goal)
        .map(|(a, b)| (b - a).abs())
        .fold(0.0, f64::max);
    // Smoothstep's peak derivative is 1.5. Round duration upward, not speed.
    (1.5 * distance / (MAX_SPEED * DT)).ceil().max(1.0) as u64
}

fn reference(memory: &Memory, interval: u64) -> [f64; 8] {
    if interval == 0 {
        return memory.ordered_initial_positions_rad;
    }
    if interval >= memory.ramp_intervals {
        return memory.ordered_goal_positions_rad;
    }
    let u = interval as f64 / memory.ramp_intervals as f64;
    let blend = u * u * (3.0 - 2.0 * u);
    std::array::from_fn(|i| {
        memory.ordered_initial_positions_rad[i]
            + blend
                * (memory.ordered_goal_positions_rad[i] - memory.ordered_initial_positions_rad[i])
    })
}

pub(crate) fn apply(
    previous: Option<&Memory>,
    state: &StateFrame,
    command: &MotionCommand,
    compiled: &CompiledQuadruped,
    actuation: &mut ActuationFrame,
    gain: f64,
    damping: f64,
    motor_sign: f64,
) -> Result<Memory> {
    ensure(
        command.gait_amplitude == 0.0
            && command.desired_planar_velocity_task_m_s == crate::schema::Vec3::ZERO
            && command.desired_yaw_rate_rad_s.is_none_or(|v| v == 0.0),
        "stationary_command",
    )?;
    ensure(
        state.ordered_joint_observations.len() == 8 && actuation.ordered_commands.len() == 8,
        "joint_population",
    )?;
    let goal = goals(compiled)?;
    let actuators = &compiled.morphology.morphology_spec.actuators;
    let measured: [f64; 8] = std::array::from_fn(|i| {
        state.ordered_joint_observations[i]
            .position_rad
            .unwrap_or(f64::NAN)
    });
    for (i, q) in measured.iter().enumerate() {
        ensure(
            q.is_finite()
                && *q >= actuators[i].minimum_target_position_rad
                && *q <= actuators[i].maximum_target_position_rad,
            "measured_joint_bounds",
        )?;
    }
    let initial = previous.is_none();
    let mut next = if let Some(memory) = previous {
        ensure(memory.ordered_goal_positions_rad == goal, "goal_memory")?;
        for (i, q) in memory.ordered_initial_positions_rad.iter().enumerate() {
            ensure(
                q.is_finite()
                    && *q >= actuators[i].minimum_target_position_rad
                    && *q <= actuators[i].maximum_target_position_rad,
                "initial_joint_memory",
            )?;
        }
        ensure(
            memory.ramp_intervals == duration(&memory.ordered_initial_positions_rad, &goal)
                && memory.ordered_previous_references_rad
                    == reference(memory, memory.completed_reference_intervals)
                && memory.reference_ramp_complete
                    == (memory.completed_reference_intervals >= memory.ramp_intervals),
            "reference_memory",
        )?;
        ensure(
            memory.first_semantic_step == 1
                && memory.completed_reference_intervals < MAX_COMMANDS - 1
                && state.semantic_step
                    == memory.first_semantic_step + memory.completed_reference_intervals + 1
                && memory.start_sample_time_s.is_finite()
                && memory.last_sample_time_s.is_finite()
                && (state.sample_time_s - memory.last_sample_time_s - DT).abs() < 1e-9
                && (memory.last_sample_time_s
                    - memory.start_sample_time_s
                    - memory.completed_reference_intervals as f64 * DT)
                    .abs()
                    < 1e-9,
            "clock_or_bound",
        )?;
        memory.clone()
    } else {
        ensure(
            state.semantic_step == 1 && state.sample_time_s.is_finite(),
            "initial_clock",
        )?;
        Memory {
            first_semantic_step: state.semantic_step,
            start_sample_time_s: state.sample_time_s,
            last_sample_time_s: state.sample_time_s,
            completed_reference_intervals: 0,
            ramp_intervals: duration(&measured, &goal),
            ordered_initial_positions_rad: measured,
            ordered_goal_positions_rad: goal,
            ordered_previous_references_rad: measured,
            reference_ramp_complete: false,
        }
    };
    if !initial {
        next.completed_reference_intervals += 1;
    }
    let target = reference(&next, next.completed_reference_intervals);
    for (i, output) in actuation.ordered_commands.iter_mut().enumerate() {
        let rate = if initial {
            0.0
        } else {
            (target[i] - next.ordered_previous_references_rad[i]) / DT
        };
        ensure(rate.abs() <= MAX_SPEED + 1e-12, "reference_speed")?;
        let velocity = state.ordered_joint_observations[i]
            .velocity_rad_s
            .ok_or_else(|| CoreError::Frame("joint_pose_entry_measured_velocity".to_owned()))?;
        ensure(velocity.is_finite(), "measured_velocity")?;
        let raw = if initial {
            0.0
        } else {
            gain * (target[i] - measured[i]) - damping * velocity + (1.0 + damping) * rate
        };
        output.requested_target_position_rad = target[i];
        output.clamped_target_position_rad = target[i];
        output.maximum_target_speed_rad_s = MAX_SPEED;
        output.target_velocity_rad_s = raw.clamp(-MAX_SPEED, MAX_SPEED) * motor_sign;
        output.position_saturated = false;
        output.velocity_saturated = raw.abs() > MAX_SPEED;
        output.slew_limited = target[i] != goal[i];
        output.safety_contribution_rad_s = 0.0;
        output.residual_contribution_rad_s = 0.0;
    }
    next.ordered_previous_references_rad = target;
    next.last_sample_time_s = state.sample_time_s;
    next.reference_ramp_complete = next.completed_reference_intervals >= next.ramp_intervals;
    actuation.validate(&compiled.morphology)?;
    Ok(next)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn under_hip_goal_matches_existing_v50_height_and_all_joint_bounds() {
        let compiled = crate::quadruped::compile_bounded_quadruped(
            crate::actuator_profile::r23d60_selected_s169_descriptor(),
        )
        .unwrap();
        let q = goals(&compiled).unwrap();
        let g = &compiled.geometry;
        for pair in q.chunks_exact(2) {
            let (h, k) = (pair[0], pair[1]);
            assert!((g.upper_length_m * h.sin() + g.lower_length_m * (h + k).sin()).abs() < 1e-14);
            assert!(
                (g.upper_length_m * h.cos() + g.lower_length_m * (h + k).cos() - 0.33).abs()
                    < 1e-14
            );
        }
        assert_eq!(duration(&[0.0; 8], &q), 164);
    }
}
