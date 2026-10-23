//! Pure BW19V composition for batched host execution. No world or hidden memory.
//!
//! The scalar adapter remains the comparison oracle. This moves its sequence of
//! existing core operations across one ABI boundary without changing the policy.

use serde::{Deserialize, Serialize};

use crate::canonical_actuation::{
    CanonicalVelocityActuationFrameV1, CanonicalVelocityResidualV1,
    VelocityOnlyHostMappingReceiptV1, VelocityOnlyHostProfileV1,
    canonicalize_and_compose_legacy_velocity_v1, map_canonical_velocity_to_host_v1,
};
use crate::controller::BALANCED_WAVE_BW15F_B_POLICY_ID;
use crate::protocol::{MotionCommand, StateFrame};
use crate::runtime::{BalancedWaveController, BalancedWaveControllerMemory, BalancedWaveControllerStepOutput};
use crate::schema::{CoreError, Result};
use crate::stability::{
    EndpointForceActuatorKinematicsV2, EndpointForceJointMapReceiptV3,
    EndpointForceJointMapRequestV3, EndpointForceJointMappingModeV3,
    PreviousStabilityCorrectionV2, RequestedStabilityCorrectionV2,
    ScheduledLimbGaitStepV1, ScheduledLoadTransferReceiptV3, ScheduledLoadTransferRequestV3,
    StabilityInfluenceAvailability, StabilityInfluenceReceiptV3, StabilityInfluenceRequestV3,
    StabilityStateV2, bound_stability_influence_v3, map_endpoint_force_to_joint_v3,
    plan_scheduled_load_transfer_v3,
};

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompositionMemory {
    pub previous_semantic_step: Option<u64>,
    pub ordered_previous_applied_corrections: Option<Vec<PreviousStabilityCorrectionV2>>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StepRequest {
    pub memory: BalancedWaveControllerMemory,
    pub state: StateFrame,
    pub command: MotionCommand,
    pub stability: StabilityStateV2,
    pub kinematics: Vec<EndpointForceActuatorKinematicsV2>,
    pub composition_memory: CompositionMemory,
    pub host_profile: VelocityOnlyHostProfileV1,
}

#[derive(Debug, Serialize)]
pub struct Composition {
    pub scheduled_load_transfer: ScheduledLoadTransferReceiptV3,
    pub endpoint_mapping: Option<EndpointForceJointMapReceiptV3>,
    pub stability_influence: StabilityInfluenceReceiptV3,
    pub raw_generalized_torque_commands_nm: Vec<Option<f64>>,
    pub canonical_actuation: CanonicalVelocityActuationFrameV1,
    pub host_mapping: VelocityOnlyHostMappingReceiptV1,
}

#[derive(Debug, Serialize)]
pub struct StepOutput {
    pub output: BalancedWaveControllerStepOutput,
    pub composition: Composition,
    pub next_composition_memory: CompositionMemory,
}

pub fn step(controller: &BalancedWaveController, request: &StepRequest) -> Result<StepOutput> {
    if controller.profile().policy_id != BALANCED_WAVE_BW15F_B_POLICY_ID {
        return Err(CoreError::Identity("bw19v_batch_policy".to_owned()));
    }
    let morphology = &controller.compiled().morphology;
    let output = controller.step(&request.memory, &request.state, &request.command);
    // Match the scalar production bridge's refusal before any composition.
    if output.actuation.receipt.controller_error.is_some() || !output.actuation.failure_codes.is_empty() {
        return Err(CoreError::Actuation(format!("bw19v_batch_controller_refused:{:?}", output.actuation.failure_codes)));
    }
    let semantic_step = output.actuation.semantic_step;
    let ordered_limb_gait_steps = morphology.ordered_limb_ids.iter().map(|id| {
        request.memory.ordered_limb_memory.iter().find(|m| &m.limb_id == id)
            .map(|m| ScheduledLimbGaitStepV1 { limb_id: id.clone(), gait_step: m.gait_step })
            .ok_or_else(|| CoreError::Order("bw19v_batch_limb_memory".to_owned()))
    }).collect::<Result<Vec<_>>>()?;
    let available = request.stability.ordered_support_contacts.iter().any(|contact| contact.bears_support == Some(true));
    let gravity = request.stability.gravity_world_m_s2;
    // Preserve Python's left-to-right sum and separate products; no fused norm.
    let gravity_norm = (((0.0 + gravity.x * gravity.x) + gravity.y * gravity.y) + gravity.z * gravity.z).sqrt();
    let plan = plan_scheduled_load_transfer_v3(morphology, &ScheduledLoadTransferRequestV3 {
        schema_version: "sporespore_scheduled_load_transfer_request_v3".to_owned(),
        policy_id: "sporespore_scheduled_load_transfer_bw13p_a_v3".to_owned(),
        semantic_step, observation_available: available,
        observation_unavailable_reason: if available { None } else { Some("NO_QUALIFIED_SUPPORT_CONTACT".to_owned()) },
        gait_amplitude: 1.0, cycle_steps: 360, swing_steps: 72,
        characterized_friction_coefficient: 0.94,
        maximum_normal_force_n: morphology.total_mass_kg * gravity_norm,
        feasibility_tolerance: 1.0e-5, ordered_limb_gait_steps,
        stability_state: Some(request.stability.clone()),
    })?;
    let mapping = if plan.planning_availability == StabilityInfluenceAvailability::Available {
        Some(map_endpoint_force_to_joint_v3(morphology, &EndpointForceJointMapRequestV3 {
            schema_version: "sporespore_endpoint_force_joint_map_request_v3".to_owned(),
            semantic_step,
            centroidal_command: plan.centroidal_command.clone().ok_or_else(|| CoreError::Internal("bw19v_batch_centroidal_missing".to_owned()))?,
            ordered_actuator_kinematics: request.kinematics.clone(),
        })?)
    } else { None };
    let mut raw_torque = Vec::with_capacity(morphology.ordered_actuator_ids.len());
    let mut requested = Vec::with_capacity(morphology.ordered_actuator_ids.len());
    let mut previous = request.composition_memory.ordered_previous_applied_corrections.clone();
    if let Some(mapping) = &mapping {
        if mapping.ordered_generalized_joint_torque_commands.len() != morphology.ordered_actuator_ids.len() {
            return Err(CoreError::Order("bw19v_batch_mapping_count".to_owned()));
        }
        for (index, (id, command)) in morphology.ordered_actuator_ids.iter().zip(&mapping.ordered_generalized_joint_torque_commands).enumerate() {
            if id != &command.actuator_id { return Err(CoreError::Order("bw19v_batch_mapping_order".to_owned())); }
            raw_torque.push(Some(command.generalized_torque_command_nm));
            requested.push(RequestedStabilityCorrectionV2 { actuator_id: id.clone(),
                requested_position_delta_rad: Some(0.0),
                requested_velocity_delta_rad_s: Some(command.generalized_torque_command_nm / 10.0) });
            if command.mapping_mode == EndpointForceJointMappingModeV3::InactiveContactZero {
                if let Some(previous) = &mut previous {
                    let correction = previous.get_mut(index).ok_or_else(|| CoreError::Order("bw19v_batch_previous_count".to_owned()))?;
                    correction.applied_position_delta_rad = 0.0;
                    correction.applied_velocity_delta_rad_s = 0.0;
                }
            }
        }
    } else {
        for id in &morphology.ordered_actuator_ids {
            raw_torque.push(None);
            requested.push(RequestedStabilityCorrectionV2 { actuator_id: id.clone(),
                requested_position_delta_rad: None, requested_velocity_delta_rad_s: None });
        }
    }
    let influence = bound_stability_influence_v3(morphology, &StabilityInfluenceRequestV3 {
        schema_version: "sporespore_stability_influence_request_v3".to_owned(), semantic_step,
        availability: plan.planning_availability, global_requested_correction_scale: 0.5,
        maximum_absolute_position_delta_rad: 0.0, maximum_absolute_velocity_delta_rad_s: 0.075,
        maximum_position_delta_slew_per_step_rad: 0.0, maximum_velocity_delta_slew_per_step_rad_s: 0.010,
        ordered_requested_corrections: requested,
        previous_semantic_step: request.composition_memory.previous_semantic_step,
        ordered_previous_applied_corrections: previous,
    })?;
    let next_composition_memory = CompositionMemory { previous_semantic_step: Some(semantic_step),
        ordered_previous_applied_corrections: Some(influence.ordered_applied_corrections.iter().map(|c| PreviousStabilityCorrectionV2 {
            actuator_id: c.actuator_id.clone(), applied_position_delta_rad: c.applied_position_delta_rad,
            applied_velocity_delta_rad_s: c.applied_velocity_delta_rad_s,
        }).collect()) };
    let residuals = influence.ordered_applied_corrections.iter().map(|c| CanonicalVelocityResidualV1 {
        schema_version: "sporespore_canonical_velocity_residual_v1".to_owned(), actuator_id: c.actuator_id.clone(),
        canonical_velocity_delta_rad_s: c.applied_velocity_delta_rad_s,
        command_not_measurement: true, physical_acceptance_authority: false,
    }).collect::<Vec<_>>();
    let canonical = canonicalize_and_compose_legacy_velocity_v1(morphology, &output.actuation, &residuals)?;
    let host_mapping = map_canonical_velocity_to_host_v1(morphology, &canonical, &request.host_profile)?;
    Ok(StepOutput { output, next_composition_memory, composition: Composition {
        scheduled_load_transfer: plan, endpoint_mapping: mapping, stability_influence: influence,
        raw_generalized_torque_commands_nm: raw_torque, canonical_actuation: canonical, host_mapping,
    } })
}
