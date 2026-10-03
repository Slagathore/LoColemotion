//! V53 preserves V52 reference generation and bounds zero-amplitude feedback.
//! The cap is controller authority, never a contact or physical-success claim.
use serde::{Deserialize, Serialize};
use crate::canonical::digest_serializable;
use crate::protocol::ActuationFrame;
use crate::quadruped::CompiledQuadruped;
use crate::schema::{CoreError, Result};

pub const POLICY: &str = "sporespore_balanced_wave_recovery_bounded_stop_velocity_v1";
pub const MEMORY: &str = "sporespore_balanced_wave_recovery_bounded_stop_velocity_memory_v1";
pub const PROFILE: &str = "sporespore_balanced_wave_recovery_bounded_stop_velocity_profile_v1";
pub const RECEIPT: &str = "sporespore_recovery_bounded_stop_velocity_controller_step_receipt_v1";
pub const MAXIMUM_HOLD_VELOCITY_RAD_S: f64 = 0.25;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandReceipt {
    pub actuator_id: String,
    pub effective_limit_rad_s: f64,
    pub original_velocity_rad_s: f64,
    pub bounded_velocity_rad_s: f64,
    pub clipped: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub maximum_absolute_velocity_rad_s: f64,
    pub ordered_commands: Vec<CommandReceipt>,
    pub physical_acceptance_authority: bool,
}

fn bounded_velocity(value: f64, descriptor_limit: f64) -> Result<(f64, f64)> {
    if !value.is_finite() || !descriptor_limit.is_finite() || descriptor_limit <= 0.0 {
        return Err(CoreError::Frame("bounded_stop_velocity_nonfinite_or_invalid_limit".to_owned()));
    }
    let limit = descriptor_limit.min(MAXIMUM_HOLD_VELOCITY_RAD_S);
    Ok((value.clamp(-limit, limit), limit))
}

/// Called only for a valid V53 zero-amplitude output, after unchanged V52 math.
pub(crate) fn apply(actuation: &mut ActuationFrame, compiled: &CompiledQuadruped) -> Result<()> {
    actuation.validate(&compiled.morphology)?;
    if actuation.safe_no_actuation {
        return Err(CoreError::Frame("bounded_stop_velocity_refused_output".to_owned()));
    }
    let commands = actuation.ordered_commands.iter().map(|command| {
        let (bounded, limit) = bounded_velocity(command.target_velocity_rad_s,
                                                command.maximum_target_speed_rad_s)?;
        Ok(CommandReceipt {
            actuator_id: command.actuator_id.clone(), effective_limit_rad_s: limit,
            original_velocity_rad_s: command.target_velocity_rad_s,
            bounded_velocity_rad_s: bounded, clipped: bounded != command.target_velocity_rad_s,
        })
    }).collect::<Result<Vec<_>>>()?;
    for (command, receipt) in actuation.ordered_commands.iter_mut().zip(&commands) {
        // Avoid touching unclipped fields, including their exact floating-point bits.
        if receipt.clipped {
            command.target_velocity_rad_s = receipt.bounded_velocity_rad_s;
            command.safety_contribution_rad_s += receipt.bounded_velocity_rad_s - receipt.original_velocity_rad_s;
            command.velocity_saturated = true;
        }
    }
    let pose = actuation.receipt.recovery_support_plane.as_mut()
        .and_then(|plane| plane.anchored_body_pose.as_mut())
        .ok_or_else(|| CoreError::Frame("bounded_stop_velocity_missing_pose".to_owned()))?;
    pose.zero_amplitude_velocity_guard = Some(Receipt {
        schema_version: "sporespore_bounded_zero_amplitude_velocity_receipt_v1".to_owned(),
        maximum_absolute_velocity_rad_s: MAXIMUM_HOLD_VELOCITY_RAD_S,
        ordered_commands: commands, physical_acceptance_authority: false,
    });
    actuation.receipt_sha256 = digest_serializable(&actuation.receipt)?;
    actuation.validate(&compiled.morphology)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_cap_both_signs_preserves_unclipped_values_and_signed_zero() {
        for value in [-0.25_f64, -0.1, -0.0, 0.0, 0.1, 0.25] {
            assert_eq!(bounded_velocity(value, 3.5).unwrap().0.to_bits(), value.to_bits());
        }
        assert_eq!(bounded_velocity(-1.018436380059079, 3.5).unwrap(), (-0.25, 0.25));
        assert_eq!(bounded_velocity(1.018436380059079, 3.5).unwrap(), (0.25, 0.25));
    }

    #[test]
    fn lower_descriptor_limit_is_never_raised() {
        assert_eq!(bounded_velocity(0.2, 0.05).unwrap(), (0.05, 0.05));
        assert_eq!(bounded_velocity(-0.2, 0.05).unwrap(), (-0.05, 0.05));
    }

    #[test]
    fn nonfinite_command_and_invalid_limit_refuse() {
        for value in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert!(bounded_velocity(value, 3.5).is_err());
        }
        for limit in [0.0, -0.1, f64::NAN, f64::INFINITY] {
            assert!(bounded_velocity(0.1, limit).is_err());
        }
    }
}
