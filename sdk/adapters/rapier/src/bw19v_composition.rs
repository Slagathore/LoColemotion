use serde_json::{Value, json};
use sporespore_locomotion_core::stability::{
    PreviousStabilityCorrectionV2, RequestedStabilityCorrectionV2, StabilityInfluenceAvailability,
};
use sporespore_locomotion_core::{
    ActuationFrame, CANONICAL_VELOCITY_RESIDUAL_V1_VERSION, CanonicalVelocityActuationFrameV1,
    CanonicalVelocityResidualV1, CompiledQuadruped, ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION,
    EndpointForceActuatorKinematicsV2, EndpointForceJointMapReceiptV3,
    EndpointForceJointMapRequestV3, EndpointForceJointMappingModeV3,
    SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID, SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION,
    STABILITY_INFLUENCE_REQUEST_V3_VERSION, ScheduledLimbGaitStepV1,
    ScheduledLoadTransferReceiptV3, ScheduledLoadTransferRequestV3, StabilityInfluenceReceiptV3,
    StabilityInfluenceRequestV3, StabilityStateV2, VelocityOnlyHostMappingReceiptV1,
    VelocityOnlyHostProfileV1, bound_stability_influence_v3,
    canonicalize_and_compose_legacy_velocity_v1, map_canonical_velocity_to_host_v1,
    map_endpoint_force_to_joint_v3, plan_scheduled_load_transfer_v3,
};

pub(crate) const BW19V_CONTROLLER_POLICY_ID: &str = "sporespore_balanced_wave_bw15f_b_v1";
pub(crate) const BW19V_CONTROLLER_POLICY_DIGEST: &str =
    "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd";
pub(crate) const BW19V_REFERENCE_RUNTIME_PROFILE_SHA256: &str =
    "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413";
pub(crate) const BW19V_S169_RUNTIME_PROFILE_SHA256: &str =
    "sha256:312957dedabd3bd0eb7160c5cc69c7788bc7927acaedc42dc609a781f9c6c7db";
pub(crate) const BW19V_CANDIDATE_ID: &str = "BW19V-B";
pub(crate) const BW19V_CANDIDATE_COMPOSITION_DIGEST: &str =
    "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77";
pub(crate) const BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE: f64 = 0.5;
pub(crate) const BW19V_AUTHORED_FRICTION: f32 = 0.95;
pub(crate) const BW19V_CHARACTERIZED_CONTROLLER_FRICTION: f64 = 0.94;
pub(crate) const BW19V_CYCLE_STEPS: u64 = 360;
pub(crate) const BW19V_SWING_STEPS: u64 = 72;
pub(crate) const BW19V_FEASIBILITY_TOLERANCE: f64 = 1.0e-5;

/// The active Rapier selected-policy motor damping.
///
/// Rapier 0.34 defines the ForceBased motor law as
/// `torque = stiffness * position_error + damping * velocity_error`.
/// Holding the base position target fixed therefore gives the prospective,
/// source-derived additive conversion `delta_target_velocity = torque / damping`.
pub(crate) const RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD: f64 = 10.0;
pub(crate) const BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON: &str = "NO_QUALIFIED_SUPPORT_CONTACT";
pub(crate) const RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN: f64 = 1.0;
pub(crate) const RAPIER_BW19V_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD: f64 = 0.0;
pub(crate) const RAPIER_BW19V_MAXIMUM_POSITION_SLEW_PER_STEP_RAD: f64 = 0.0;
pub(crate) const RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S: f64 = 0.075;
pub(crate) const RAPIER_BW19V_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S: f64 = 0.010;

#[derive(Debug, Clone, Default)]
pub(crate) struct RapierBw19vCompositionMemory {
    previous_semantic_step: Option<u64>,
    ordered_previous_applied_corrections: Option<Vec<PreviousStabilityCorrectionV2>>,
}

#[derive(Debug, Clone)]
pub(crate) struct RapierBw19vComposedCommand {
    pub actuator_id: String,
    pub mapping_mode: Option<EndpointForceJointMappingModeV3>,
    pub base_target_position_rad: f64,
    pub base_target_velocity_rad_s: f64,
    pub maximum_target_speed_rad_s: f64,
    pub raw_generalized_torque_command_nm: Option<f64>,
    pub raw_canonical_velocity_delta_rad_s: Option<f64>,
    pub scaled_canonical_velocity_delta_rad_s: Option<f64>,
    pub applied_canonical_velocity_delta_rad_s: f64,
    pub requested_host_target_velocity_delta_rad_s: f64,
    pub combined_target_velocity_rad_s: f64,
    pub effective_host_target_velocity_delta_rad_s: f64,
    pub host_speed_saturated: bool,
    pub fallback_zeroed: bool,
}

impl RapierBw19vComposedCommand {
    fn to_json(&self) -> Value {
        json!({
            "actuator_id": self.actuator_id,
            "mapping_mode": self.mapping_mode.map(mapping_mode_name),
            "base_target_position_rad": self.base_target_position_rad,
            "base_target_velocity_rad_s": self.base_target_velocity_rad_s,
            "maximum_target_speed_rad_s": self.maximum_target_speed_rad_s,
            "raw_generalized_torque_command_nm": self.raw_generalized_torque_command_nm,
            "raw_canonical_velocity_delta_rad_s": self.raw_canonical_velocity_delta_rad_s,
            "scaled_canonical_velocity_delta_rad_s":
                self.scaled_canonical_velocity_delta_rad_s,
            "applied_canonical_velocity_delta_rad_s":
                self.applied_canonical_velocity_delta_rad_s,
            "requested_host_target_velocity_delta_rad_s":
                self.requested_host_target_velocity_delta_rad_s,
            "combined_target_velocity_rad_s": self.combined_target_velocity_rad_s,
            "effective_host_target_velocity_delta_rad_s":
                self.effective_host_target_velocity_delta_rad_s,
            "host_speed_saturated": self.host_speed_saturated,
            "fallback_zeroed": self.fallback_zeroed,
        })
    }
}

#[derive(Debug, Clone)]
pub(crate) struct RapierBw19vCompositionReceipt {
    pub semantic_step: u64,
    pub scheduled_load_transfer: ScheduledLoadTransferReceiptV3,
    pub endpoint_mapping: Option<EndpointForceJointMapReceiptV3>,
    pub stability_influence: StabilityInfluenceReceiptV3,
    pub ordered_commands: Vec<RapierBw19vComposedCommand>,
    pub response_reconstruction_maximum_error_nm: f64,
    pub nonzero_raw_request_count: usize,
    pub nonzero_scaled_request_count: usize,
    pub nonzero_applied_contribution_count: usize,
    pub nonzero_effective_host_application_count: usize,
    pub host_speed_saturation_count: usize,
    pub inactive_contact_exact_zero_count: usize,
}

impl RapierBw19vCompositionReceipt {
    pub fn to_json(&self) -> Value {
        json!({
            "schema_version": "sporespore_rapier_bw19v_composition_receipt_v1",
            "semantic_step": self.semantic_step,
            "candidate_id": BW19V_CANDIDATE_ID,
            "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
            "controller_policy_id": BW19V_CONTROLLER_POLICY_ID,
            "controller_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
            "controller_reference_runtime_profile_sha256":
                BW19V_REFERENCE_RUNTIME_PROFILE_SHA256,
            "stability_policy_id": SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID,
            "execution_mode":
                "native_balanced_wave_base_with_stability_contribution",
            "authority_scope": "post_settle_full",
            "global_requested_correction_scale":
                BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "source_derived_host_response": {
                "profile_id": "rapier_force_based_velocity_residual_v1",
                "motor_model": "ForceBased",
                "motor_damping_nm_s_per_rad":
                    RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
                "canonical_to_host_velocity_sign":
                    RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN,
                "formula":
                    "delta_target_velocity_rad_s=generalized_torque_nm/motor_damping_nm_s_per_rad",
                "requested_torque_is_not_a_measurement": true,
                "exact_realized_torque_claim": false,
            },
            "scheduled_load_transfer_receipt": self.scheduled_load_transfer,
            "endpoint_force_joint_map_receipt": self.endpoint_mapping,
            "stability_influence_receipt": self.stability_influence,
            "ordered_composed_commands":
                self.ordered_commands.iter().map(RapierBw19vComposedCommand::to_json)
                    .collect::<Vec<_>>(),
            "response_reconstruction_maximum_error_nm":
                self.response_reconstruction_maximum_error_nm,
            "nonzero_raw_request_count": self.nonzero_raw_request_count,
            "nonzero_scaled_request_count": self.nonzero_scaled_request_count,
            "nonzero_applied_contribution_count":
                self.nonzero_applied_contribution_count,
            "nonzero_effective_host_application_count":
                self.nonzero_effective_host_application_count,
            "host_speed_saturation_count": self.host_speed_saturation_count,
            "inactive_contact_exact_zero_count":
                self.inactive_contact_exact_zero_count,
            "adapter_actuation_applied": false,
            "physics_state_modified": false,
            "physical_acceptance_authority": false,
        })
    }
}

/// Versioned v4 composition receipt for the prospective live Rapier path.
///
/// `planning_receipt` retains the already-audited BW19V load-transfer and
/// bounding computation. Its historical mixed-space projection is preserved
/// only as provenance and a negative witness. The only load-bearing commands
/// in this receipt are `host_mapping.ordered_commands`, produced after the
/// legacy portable command and BW19V residual have both entered canonical
/// velocity space.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub(crate) struct RapierBw19vVelocityOnlyCompositionReceiptV1 {
    pub planning_receipt: RapierBw19vCompositionReceipt,
    pub canonical_actuation: CanonicalVelocityActuationFrameV1,
    pub host_mapping: VelocityOnlyHostMappingReceiptV1,
    pub retained_mixed_space_projection_difference_count: usize,
}

#[allow(dead_code)]
impl RapierBw19vVelocityOnlyCompositionReceiptV1 {
    pub fn to_json(&self) -> Value {
        json!({
            "schema_version":
                "sporespore_rapier_bw19v_velocity_only_composition_receipt_v1",
            "candidate_id": BW19V_CANDIDATE_ID,
            "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
            "controller_policy_id": BW19V_CONTROLLER_POLICY_ID,
            "global_requested_correction_scale":
                BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "planning_and_bounding_receipt": self.planning_receipt.to_json(),
            "canonical_actuation_frame": self.canonical_actuation,
            "rapier_velocity_only_host_mapping": self.host_mapping,
            "retained_historical_mixed_space_projection": {
                "applied_to_host": false,
                "difference_count_from_v4_host_mapping":
                    self.retained_mixed_space_projection_difference_count,
                "purpose":
                    "provenance_and_negative_witness_for_closed_pre_v4_paths",
            },
            "load_bearing_command_source":
                "rapier_velocity_only_host_mapping.ordered_commands",
            "native_position_feedback_applied": false,
            "world_build_count": 0,
            "physics_state_modified": false,
            "physical_acceptance_authority": false,
        })
    }
}

/// Map a portable BW15F-B actuation frame plus ordered BW19V canonical
/// residuals into the exact Rapier v4 velocity-only host convention.
///
/// This function is deliberately pure. It owns no Rapier joint and opens no
/// physics world, which makes the sign/order/position-feedback boundary
/// executable before a future selected-policy campaign is allowed to run.
pub(crate) fn map_bw19v_velocity_only_v4(
    compiled: &CompiledQuadruped,
    base_actuation: &ActuationFrame,
    ordered_residuals: &[CanonicalVelocityResidualV1],
) -> Result<
    (
        CanonicalVelocityActuationFrameV1,
        VelocityOnlyHostMappingReceiptV1,
    ),
    String,
> {
    let canonical = canonicalize_and_compose_legacy_velocity_v1(
        &compiled.morphology,
        base_actuation,
        ordered_residuals,
    )
    .map_err(|error| format!("C6_RAP_V4_CANONICAL_COMPOSITION_FAILED:{error}"))?;
    let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    let host_mapping =
        map_canonical_velocity_to_host_v1(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| format!("C6_RAP_V4_HOST_MAPPING_FAILED:{error}"))?;
    Ok((canonical, host_mapping))
}

fn mapping_mode_name(mode: EndpointForceJointMappingModeV3) -> &'static str {
    match mode {
        EndpointForceJointMappingModeV3::SupportCommand => "support_command",
        EndpointForceJointMappingModeV3::InactiveContactZero => "inactive_contact_zero",
    }
}

pub(crate) fn source_derived_velocity_delta_for_generalized_torque(
    generalized_torque_nm: f64,
) -> Result<f64, String> {
    if !generalized_torque_nm.is_finite() {
        return Err("C6_RAP_BW19V_GENERALIZED_TORQUE_NONFINITE".to_owned());
    }
    let delta = generalized_torque_nm / RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD;
    if !delta.is_finite() {
        return Err("C6_RAP_BW19V_RESPONSE_CONVERSION_NONFINITE".to_owned());
    }
    Ok(delta)
}

pub(crate) fn bw19v_observation_available(stability_state: &StabilityStateV2) -> bool {
    stability_state
        .ordered_support_contacts
        .iter()
        .any(|contact| contact.bears_support == Some(true))
}

pub(crate) fn compose_bw19v_step(
    compiled: &CompiledQuadruped,
    base_actuation: &ActuationFrame,
    stability_state: StabilityStateV2,
    ordered_actuator_kinematics: Vec<EndpointForceActuatorKinematicsV2>,
    ordered_limb_gait_steps: Vec<ScheduledLimbGaitStepV1>,
    memory: &mut RapierBw19vCompositionMemory,
) -> Result<RapierBw19vCompositionReceipt, String> {
    base_actuation
        .validate(&compiled.morphology)
        .map_err(|error| format!("C6_RAP_BW19V_BASE_ACTUATION_INVALID:{error}"))?;
    if base_actuation.safe_no_actuation {
        return Err("C6_RAP_BW19V_BASE_SAFE_NO_ACTUATION".to_owned());
    }
    let semantic_step = base_actuation.semantic_step;
    if stability_state.semantic_step != semantic_step {
        return Err("C6_RAP_BW19V_STABILITY_STEP_MISMATCH".to_owned());
    }

    let observation_available = bw19v_observation_available(&stability_state);
    let observation_unavailable_reason =
        (!observation_available).then(|| BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON.to_owned());
    let request = ScheduledLoadTransferRequestV3 {
        schema_version: SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION.to_owned(),
        policy_id: SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID.to_owned(),
        semantic_step,
        observation_available,
        observation_unavailable_reason,
        gait_amplitude: 1.0,
        cycle_steps: BW19V_CYCLE_STEPS,
        swing_steps: BW19V_SWING_STEPS,
        characterized_friction_coefficient: BW19V_CHARACTERIZED_CONTROLLER_FRICTION,
        maximum_normal_force_n: compiled.morphology.total_mass_kg
            * stability_state.gravity_world_m_s2.norm(),
        feasibility_tolerance: BW19V_FEASIBILITY_TOLERANCE,
        ordered_limb_gait_steps,
        stability_state: Some(stability_state),
    };
    let scheduled_load_transfer = plan_scheduled_load_transfer_v3(&compiled.morphology, &request)
        .map_err(|error| format!("C6_RAP_BW19V_PLAN_FAILED:{error}"))?;

    let available =
        scheduled_load_transfer.planning_availability == StabilityInfluenceAvailability::Available;
    if scheduled_load_transfer.fail_zero_required == available {
        return Err("C6_RAP_BW19V_PLAN_AVAILABILITY_CONTRACT".to_owned());
    }
    if available
        && !scheduled_load_transfer
            .ordered_safe_zero_actuator_ids
            .is_empty()
    {
        return Err("C6_RAP_BW19V_AVAILABLE_SAFE_ZERO_IDS_NONEMPTY".to_owned());
    }
    if !available
        && scheduled_load_transfer.ordered_safe_zero_actuator_ids
            != compiled.morphology.ordered_actuator_ids
    {
        return Err("C6_RAP_BW19V_UNAVAILABLE_SAFE_ZERO_ORDER".to_owned());
    }

    let endpoint_mapping = if available {
        let centroidal_command = scheduled_load_transfer
            .centroidal_command
            .clone()
            .ok_or_else(|| "C6_RAP_BW19V_AVAILABLE_COMMAND_MISSING".to_owned())?;
        if !centroidal_command.feasible {
            return Err("C6_RAP_BW19V_AVAILABLE_COMMAND_INFEASIBLE".to_owned());
        }
        Some(
            map_endpoint_force_to_joint_v3(
                &compiled.morphology,
                &EndpointForceJointMapRequestV3 {
                    schema_version: ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION.to_owned(),
                    semantic_step,
                    centroidal_command,
                    ordered_actuator_kinematics,
                },
            )
            .map_err(|error| format!("C6_RAP_BW19V_MAP_FAILED:{error}"))?,
        )
    } else {
        None
    };

    let mut raw_torque_by_actuator = Vec::with_capacity(base_actuation.ordered_commands.len());
    let mut mapping_mode_by_actuator = Vec::with_capacity(base_actuation.ordered_commands.len());
    let mut requested = Vec::with_capacity(base_actuation.ordered_commands.len());
    if let Some(mapping) = &endpoint_mapping {
        if mapping.ordered_generalized_joint_torque_commands.len()
            != compiled.morphology.ordered_actuator_ids.len()
        {
            return Err("C6_RAP_BW19V_MAP_COMMAND_COUNT".to_owned());
        }
        for (expected_id, command) in compiled
            .morphology
            .ordered_actuator_ids
            .iter()
            .zip(&mapping.ordered_generalized_joint_torque_commands)
        {
            if expected_id != &command.actuator_id {
                return Err("C6_RAP_BW19V_MAP_COMMAND_ORDER".to_owned());
            }
            let delta = source_derived_velocity_delta_for_generalized_torque(
                command.generalized_torque_command_nm,
            )?;
            raw_torque_by_actuator.push(Some(command.generalized_torque_command_nm));
            mapping_mode_by_actuator.push(Some(command.mapping_mode));
            requested.push(RequestedStabilityCorrectionV2 {
                actuator_id: command.actuator_id.clone(),
                requested_position_delta_rad: Some(0.0),
                requested_velocity_delta_rad_s: Some(delta),
            });
        }
    } else {
        for actuator_id in &compiled.morphology.ordered_actuator_ids {
            raw_torque_by_actuator.push(None);
            mapping_mode_by_actuator.push(None);
            requested.push(RequestedStabilityCorrectionV2 {
                actuator_id: actuator_id.clone(),
                requested_position_delta_rad: None,
                requested_velocity_delta_rad_s: None,
            });
        }
    }

    let effective_previous =
        memory
            .ordered_previous_applied_corrections
            .clone()
            .map(|mut corrections| {
                for (correction, mapping_mode) in
                    corrections.iter_mut().zip(&mapping_mode_by_actuator)
                {
                    if *mapping_mode == Some(EndpointForceJointMappingModeV3::InactiveContactZero) {
                        correction.applied_position_delta_rad = 0.0;
                        correction.applied_velocity_delta_rad_s = 0.0;
                    }
                }
                corrections
            });
    let stability_influence = bound_stability_influence_v3(
        &compiled.morphology,
        &StabilityInfluenceRequestV3 {
            schema_version: STABILITY_INFLUENCE_REQUEST_V3_VERSION.to_owned(),
            semantic_step,
            availability: scheduled_load_transfer.planning_availability,
            global_requested_correction_scale: BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            maximum_absolute_position_delta_rad: RAPIER_BW19V_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
            maximum_absolute_velocity_delta_rad_s:
                RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
            maximum_position_delta_slew_per_step_rad:
                RAPIER_BW19V_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
            maximum_velocity_delta_slew_per_step_rad_s:
                RAPIER_BW19V_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
            ordered_requested_corrections: requested,
            previous_semantic_step: memory.previous_semantic_step,
            ordered_previous_applied_corrections: effective_previous,
        },
    )
    .map_err(|error| format!("C6_RAP_BW19V_INFLUENCE_FAILED:{error}"))?;

    if stability_influence.ordered_applied_corrections.len()
        != base_actuation.ordered_commands.len()
    {
        return Err("C6_RAP_BW19V_INFLUENCE_COMMAND_COUNT".to_owned());
    }
    let mut ordered_commands = Vec::with_capacity(base_actuation.ordered_commands.len());
    let mut response_reconstruction_maximum_error_nm = 0.0_f64;
    let mut nonzero_raw_request_count = 0_usize;
    let mut nonzero_scaled_request_count = 0_usize;
    let mut nonzero_applied_contribution_count = 0_usize;
    let mut nonzero_effective_host_application_count = 0_usize;
    let mut host_speed_saturation_count = 0_usize;
    let mut inactive_contact_exact_zero_count = 0_usize;
    for (index, (base, influence)) in base_actuation
        .ordered_commands
        .iter()
        .zip(&stability_influence.ordered_applied_corrections)
        .enumerate()
    {
        if base.actuator_id != influence.actuator_id {
            return Err("C6_RAP_BW19V_INFLUENCE_COMMAND_ORDER".to_owned());
        }
        let mapping_mode = mapping_mode_by_actuator[index];
        let raw_torque = raw_torque_by_actuator[index];
        let raw_delta = influence.raw_requested_velocity_delta_rad_s;
        let scaled_delta = influence.scaled_requested_velocity_delta_rad_s;
        if raw_delta.is_some_and(|value| value != 0.0) {
            nonzero_raw_request_count += 1;
        }
        if scaled_delta.is_some_and(|value| value != 0.0) {
            nonzero_scaled_request_count += 1;
        }
        if influence.applied_velocity_delta_rad_s != 0.0 {
            nonzero_applied_contribution_count += 1;
        }
        if let (Some(torque), Some(delta)) = (raw_torque, raw_delta) {
            let reconstructed = delta * RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD;
            response_reconstruction_maximum_error_nm =
                response_reconstruction_maximum_error_nm.max((reconstructed - torque).abs());
        }
        let requested_host_delta =
            RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN * influence.applied_velocity_delta_rad_s;
        let unbounded = base.target_velocity_rad_s + requested_host_delta;
        let combined = unbounded.clamp(
            -base.maximum_target_speed_rad_s,
            base.maximum_target_speed_rad_s,
        );
        let effective = combined - base.target_velocity_rad_s;
        let host_speed_saturated = combined != unbounded;
        if effective != 0.0 {
            nonzero_effective_host_application_count += 1;
        }
        if host_speed_saturated {
            host_speed_saturation_count += 1;
        }
        if mapping_mode == Some(EndpointForceJointMappingModeV3::InactiveContactZero) {
            if raw_torque != Some(0.0)
                || raw_delta != Some(0.0)
                || scaled_delta != Some(0.0)
                || influence.applied_position_delta_rad != 0.0
                || influence.applied_velocity_delta_rad_s != 0.0
                || effective != 0.0
            {
                return Err("C6_RAP_BW19V_INACTIVE_CONTACT_NOT_EXACT_ZERO".to_owned());
            }
            inactive_contact_exact_zero_count += 1;
        }
        if influence.applied_position_delta_rad != 0.0
            || requested_host_delta.abs()
                > RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S + 1.0e-12
            || effective.abs() > RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S + 1.0e-12
            || !combined.is_finite()
        {
            return Err("C6_RAP_BW19V_COMPOSED_COMMAND_OUT_OF_BOUNDS".to_owned());
        }
        ordered_commands.push(RapierBw19vComposedCommand {
            actuator_id: base.actuator_id.clone(),
            mapping_mode,
            base_target_position_rad: base.clamped_target_position_rad,
            base_target_velocity_rad_s: base.target_velocity_rad_s,
            maximum_target_speed_rad_s: base.maximum_target_speed_rad_s,
            raw_generalized_torque_command_nm: raw_torque,
            raw_canonical_velocity_delta_rad_s: raw_delta,
            scaled_canonical_velocity_delta_rad_s: scaled_delta,
            applied_canonical_velocity_delta_rad_s: influence.applied_velocity_delta_rad_s,
            requested_host_target_velocity_delta_rad_s: requested_host_delta,
            combined_target_velocity_rad_s: combined,
            effective_host_target_velocity_delta_rad_s: effective,
            host_speed_saturated,
            fallback_zeroed: influence.fallback_zeroed,
        });
    }

    memory.previous_semantic_step = Some(semantic_step);
    memory.ordered_previous_applied_corrections = Some(
        stability_influence
            .ordered_applied_corrections
            .iter()
            .map(|correction| PreviousStabilityCorrectionV2 {
                actuator_id: correction.actuator_id.clone(),
                applied_position_delta_rad: correction.applied_position_delta_rad,
                applied_velocity_delta_rad_s: correction.applied_velocity_delta_rad_s,
            })
            .collect(),
    );

    Ok(RapierBw19vCompositionReceipt {
        semantic_step,
        scheduled_load_transfer,
        endpoint_mapping,
        stability_influence,
        ordered_commands,
        response_reconstruction_maximum_error_nm,
        nonzero_raw_request_count,
        nonzero_scaled_request_count,
        nonzero_applied_contribution_count,
        nonzero_effective_host_application_count,
        host_speed_saturation_count,
        inactive_contact_exact_zero_count,
    })
}

/// Compose BW19V through the versioned v4 canonical-velocity boundary.
///
/// The retained v1 composition remains responsible for the established pure
/// load-transfer, endpoint mapping, scaling, magnitude bounds, slew bounds,
/// and fallback behavior. Its final mixed-space host projection is never
/// applied here. Instead, the bounded corrections are re-expressed as
/// canonical residuals and composed with the complete portable command before
/// the Rapier sign conversion is performed exactly once.
#[allow(dead_code)]
pub(crate) fn compose_bw19v_step_v4(
    compiled: &CompiledQuadruped,
    base_actuation: &ActuationFrame,
    stability_state: StabilityStateV2,
    ordered_actuator_kinematics: Vec<EndpointForceActuatorKinematicsV2>,
    ordered_limb_gait_steps: Vec<ScheduledLimbGaitStepV1>,
    memory: &mut RapierBw19vCompositionMemory,
) -> Result<RapierBw19vVelocityOnlyCompositionReceiptV1, String> {
    let planning_receipt = compose_bw19v_step(
        compiled,
        base_actuation,
        stability_state,
        ordered_actuator_kinematics,
        ordered_limb_gait_steps,
        memory,
    )?;
    if planning_receipt
        .stability_influence
        .global_requested_correction_scale
        != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
    {
        return Err("C6_RAP_V4_BW19V_GLOBAL_SCALE_MISMATCH".to_owned());
    }
    let ordered_residuals = planning_receipt
        .stability_influence
        .ordered_applied_corrections
        .iter()
        .map(|correction| {
            if correction.applied_position_delta_rad != 0.0 {
                return Err(format!(
                    "C6_RAP_V4_NATIVE_POSITION_CONTRIBUTION_FORBIDDEN:{}",
                    correction.actuator_id
                ));
            }
            Ok(CanonicalVelocityResidualV1 {
                schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
                actuator_id: correction.actuator_id.clone(),
                canonical_velocity_delta_rad_s: correction.applied_velocity_delta_rad_s,
                command_not_measurement: true,
                physical_acceptance_authority: false,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    let retained_mixed_space_projection_difference_count = planning_receipt
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
        .filter(|(historical, v4)| {
            historical.combined_target_velocity_rad_s.to_bits()
                != v4.host_target_velocity_rad_s.to_bits()
        })
        .count();
    Ok(RapierBw19vVelocityOnlyCompositionReceiptV1 {
        planning_receipt,
        canonical_actuation,
        host_mapping,
        retained_mixed_space_projection_difference_count,
    })
}

trait Vec3Norm {
    fn norm(self) -> f64;
}

impl Vec3Norm for sporespore_locomotion_core::schema::Vec3 {
    fn norm(self) -> f64 {
        (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn source_derived_force_based_response_is_signed_and_dimensionally_exact() {
        for torque in [-0.75, -0.10, 0.0, 0.10, 0.75] {
            let delta = source_derived_velocity_delta_for_generalized_torque(torque).unwrap();
            assert_eq!(delta * RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD, torque);
            assert_eq!(delta.signum(), torque.signum());
        }
        assert!(source_derived_velocity_delta_for_generalized_torque(f64::NAN).is_err());
        assert!(source_derived_velocity_delta_for_generalized_torque(f64::INFINITY).is_err());
    }
}
