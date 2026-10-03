//! V54 requests enabled-motor holding at zero target velocity.
//! Native motor reactions remain subject to the existing actuator limits.
use serde::{Deserialize, Serialize};
use crate::canonical::digest_serializable;
use crate::protocol::ActuationFrame;
use crate::quadruped::CompiledQuadruped;
use crate::schema::{CoreError, Result};

pub const POLICY: &str = "sporespore_balanced_wave_recovery_zero_velocity_brake_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_zero_velocity_brake_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_zero_velocity_brake_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_zero_velocity_brake_controller_step_receipt_v1";

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandReceipt {
    pub actuator_id: String,
    pub previous_target_velocity_rad_s: f64,
    pub held_target_velocity_rad_s: f64,
    pub changed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub ordered_commands: Vec<CommandReceipt>,
    pub zero_applied_impulse_claim: bool,
    pub physical_acceptance_authority: bool,
}

fn held_velocity(value: f64, descriptor_limit: f64) -> Result<f64> {
    if !value.is_finite() || !descriptor_limit.is_finite() || descriptor_limit <= 0.0 {
        return Err(CoreError::Frame("zero_velocity_brake_nonfinite_or_invalid_limit".to_owned()));
    }
    // Preserve already-zero values bit-for-bit, including negative zero.
    Ok(if value == 0.0 { value } else { 0.0 })
}

/// Called only after a valid V54 zero-amplitude command has generated references.
pub(crate) fn apply(actuation: &mut ActuationFrame, compiled: &CompiledQuadruped) -> Result<()> {
    actuation.validate(&compiled.morphology)?;
    if actuation.safe_no_actuation {
        return Err(CoreError::Frame("zero_velocity_brake_refused_output".to_owned()));
    }
    if actuation.receipt.recovery_support_plane.as_ref()
        .and_then(|plane| plane.anchored_body_pose.as_ref()).is_none() {
        return Err(CoreError::Frame("zero_velocity_brake_missing_pose".to_owned()));
    }
    let commands = actuation.ordered_commands.iter().map(|command| {
        let held = held_velocity(command.target_velocity_rad_s, command.maximum_target_speed_rad_s)?;
        Ok(CommandReceipt {
            actuator_id: command.actuator_id.clone(),
            previous_target_velocity_rad_s: command.target_velocity_rad_s,
            held_target_velocity_rad_s: held,
            changed: held != command.target_velocity_rad_s,
        })
    }).collect::<Result<Vec<_>>>()?;
    for (command, receipt) in actuation.ordered_commands.iter_mut().zip(&commands) {
        if receipt.changed {
            command.target_velocity_rad_s = receipt.held_target_velocity_rad_s;
            command.safety_contribution_rad_s += receipt.held_target_velocity_rad_s - receipt.previous_target_velocity_rad_s;
            command.velocity_saturated = true;
        }
    }
    let pose = actuation.receipt.recovery_support_plane.as_mut()
        .and_then(|plane| plane.anchored_body_pose.as_mut()).expect("validated pose");
    pose.zero_amplitude_motor_brake = Some(Receipt {
        schema_version: "sporespore_zero_amplitude_motor_brake_receipt_v1".to_owned(),
        ordered_commands: commands,
        zero_applied_impulse_claim: false,
        physical_acceptance_authority: false,
    });
    actuation.receipt_sha256 = digest_serializable(&actuation.receipt)?;
    actuation.validate(&compiled.morphology)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn both_velocity_signs_hold_at_zero_without_raising_small_limits() {
        for limit in [0.0001, 0.05, 3.5] {
            for value in [-limit, -limit / 2.0, limit / 2.0, limit] {
                assert_eq!(held_velocity(value, limit).unwrap(), 0.0);
            }
        }
    }

    #[test]
    fn existing_signed_zero_is_preserved() {
        for value in [-0.0_f64, 0.0] {
            assert_eq!(held_velocity(value, 3.5).unwrap().to_bits(), value.to_bits());
        }
    }

    #[test]
    fn nonfinite_values_and_invalid_limits_refuse() {
        for value in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert!(held_velocity(value, 3.5).is_err());
        }
        for limit in [0.0, -0.1, f64::NAN, f64::INFINITY] {
            assert!(held_velocity(0.1, limit).is_err());
        }
    }
}
