use rapier3d::prelude::Vector;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::PhaseProgressionMode;
use sporespore_locomotion_core::stability::{
    EndpointForceJointMappingModeV3, ScheduledLimbGaitStepV1, StabilityInfluenceAvailability,
};
use sporespore_locomotion_core::{
    BALANCED_WAVE_BW15F_B_POLICY_ID, BalancedWaveController, BalancedWaveControllerMemory,
    CompiledQuadruped, StateFrame, compile_bounded_quadruped, digest_json, digest_serializable,
};

use crate::bw19v_composition::{
    BW19V_AUTHORED_FRICTION, BW19V_CANDIDATE_COMPOSITION_DIGEST, BW19V_CANDIDATE_ID,
    BW19V_CHARACTERIZED_CONTROLLER_FRICTION, BW19V_CONTROLLER_POLICY_DIGEST,
    BW19V_CONTROLLER_POLICY_ID, BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
    BW19V_REFERENCE_RUNTIME_PROFILE_SHA256, BW19V_S169_RUNTIME_PROFILE_SHA256,
    RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD, RapierBw19vComposedCommand,
    RapierBw19vCompositionMemory, compose_bw19v_step,
};
use crate::locomotion::{
    HostRobot, build_bw19v_robot, descriptor, motion_command, state_contains_nonfinite,
};
use crate::{
    ADAPTER_ID, RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
    RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS, RAPIER_ACTIVE_SOLVER_ITERATIONS, RAPIER_DT_S,
    capability_manifest_sha256,
};

const PREREGISTRATION: &str = include_str!(
    "../../../rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration.json"
);
pub const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:8c149f47a87bbd72402a7aa98fec1e75ff05abb36df2802f9b8a333f469b3197";
const C2_CLOSURE: &str =
    include_str!("../../../rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json");
const C2_CLOSURE_RAW_SHA256: &str =
    "sha256:3047c2d9712a7d9b70c7423dab7df19bc8de96b1c39663b2bf0fb6e278fe5590";

pub const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1";
pub const GATE_ID: &str = "C6-RAP-BW19V-ED1";
const REPORT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_report_v1";
const PREFLIGHT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preflight_v1";
const ARM_A: &str = "ED1-A";
const ARM_B: &str = "ED1-B";
const SETTLE_STEPS: u64 = 240;
const HORIZON_STEPS: u64 = 472;
const ACTUATOR_COUNT: usize = 8;
const TOTAL_TRACE_STEPS: u64 = HORIZON_STEPS * 2;
const TOTAL_COMMANDS_PER_LAYER: u64 = TOTAL_TRACE_STEPS * ACTUATOR_COUNT as u64;
const MOTOR_FORCE_MARGIN: f64 = 1.015;

const MAXIMUM_TILT_RAD: f64 = 0.6;
const MINIMUM_TORSO_HEIGHT_M: f64 = 0.2499708652072946;
const MAXIMUM_ANCHOR_ERROR_M: f64 = 0.025575899999999995;
const MAXIMUM_HINGE_AXIS_ERROR_RAD: f64 = 0.2;

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn compile_declared_boundary() -> Result<(CompiledQuadruped, BalancedWaveController), String> {
    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller =
        BalancedWaveController::new_for_policy(compiled.clone(), BALANCED_WAVE_BW15F_B_POLICY_ID)
            .map_err(|error| error.to_string())?;
    if controller.profile().policy_id != BW19V_CONTROLLER_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
    {
        return Err("C6_RAP_BW19V_ED1_CONTROLLER_IDENTITY_MISMATCH".to_owned());
    }
    let profile_sha256 =
        digest_serializable(controller.profile()).map_err(|error| error.to_string())?;
    if profile_sha256 != BW19V_S169_RUNTIME_PROFILE_SHA256 {
        return Err(format!(
            "C6_RAP_BW19V_ED1_RUNTIME_PROFILE_MISMATCH:{profile_sha256}"
        ));
    }
    Ok((compiled, controller))
}

fn ordered_limb_steps(
    compiled: &CompiledQuadruped,
    memory: &BalancedWaveControllerMemory,
) -> Result<Vec<ScheduledLimbGaitStepV1>, String> {
    compiled
        .morphology
        .ordered_limb_ids
        .iter()
        .map(|limb_id| {
            memory
                .ordered_limb_memory
                .iter()
                .find(|limb| limb.limb_id == *limb_id)
                .map(|limb| ScheduledLimbGaitStepV1 {
                    limb_id: limb.limb_id.clone(),
                    gait_step: limb.gait_step,
                })
                .ok_or_else(|| format!("C6_RAP_BW19V_ED1_LIMB_MEMORY_MISSING:{limb_id}"))
        })
        .collect()
}

fn availability_name(value: StabilityInfluenceAvailability) -> &'static str {
    match value {
        StabilityInfluenceAvailability::Available => "available",
        StabilityInfluenceAvailability::ObservationUnavailable => "observation_unavailable",
        StabilityInfluenceAvailability::UpstreamInfeasible => "upstream_infeasible",
    }
}

fn mapping_mode_name(value: EndpointForceJointMappingModeV3) -> &'static str {
    match value {
        EndpointForceJointMappingModeV3::SupportCommand => "support_command",
        EndpointForceJointMappingModeV3::InactiveContactZero => "inactive_contact_zero",
    }
}

fn base_command_json(command: &sporespore_locomotion_core::ActuatorCommand) -> Value {
    json!({
        "actuator_id": command.actuator_id,
        "requested_target_position_rad": command.requested_target_position_rad,
        "clamped_target_position_rad": command.clamped_target_position_rad,
        "target_velocity_rad_s": command.target_velocity_rad_s,
        "maximum_target_speed_rad_s": command.maximum_target_speed_rad_s,
        "position_saturated": command.position_saturated,
        "velocity_saturated": command.velocity_saturated,
        "slew_limited": command.slew_limited,
        "portable_residual_contribution_rad_s": command.residual_contribution_rad_s,
        "portable_safety_contribution_rad_s": command.safety_contribution_rad_s,
        "valid_through_step": command.valid_through_step,
    })
}

fn residual_command_json(command: &RapierBw19vComposedCommand) -> Value {
    json!({
        "actuator_id": command.actuator_id,
        "mapping_mode": command.mapping_mode.map(mapping_mode_name),
        "raw_generalized_torque_command_nm": command.raw_generalized_torque_command_nm,
        "raw_canonical_velocity_delta_rad_s": command.raw_canonical_velocity_delta_rad_s,
        "scaled_canonical_velocity_delta_rad_s":
            command.scaled_canonical_velocity_delta_rad_s,
        "applied_canonical_velocity_delta_rad_s":
            command.applied_canonical_velocity_delta_rad_s,
        "requested_host_target_velocity_delta_rad_s":
            command.requested_host_target_velocity_delta_rad_s,
        "combined_target_velocity_rad_s": command.combined_target_velocity_rad_s,
        "effective_host_target_velocity_delta_rad_s":
            command.effective_host_target_velocity_delta_rad_s,
        "host_speed_saturated": command.host_speed_saturated,
        "fallback_zeroed": command.fallback_zeroed,
    })
}

fn final_command_json(command: &RapierBw19vComposedCommand) -> Value {
    json!({
        "actuator_id": command.actuator_id,
        "final_target_position_rad": command.base_target_position_rad,
        "final_target_velocity_rad_s": command.combined_target_velocity_rad_s,
        "maximum_target_speed_rad_s": command.maximum_target_speed_rad_s,
        "applied_residual_velocity_rad_s":
            command.effective_host_target_velocity_delta_rad_s,
        "motor_model": "ForceBased",
    })
}

fn base_only_host_commands(
    base: &sporespore_locomotion_core::ActuationFrame,
) -> Vec<RapierBw19vComposedCommand> {
    base.ordered_commands
        .iter()
        .map(|command| RapierBw19vComposedCommand {
            actuator_id: command.actuator_id.clone(),
            mapping_mode: None,
            base_target_position_rad: command.clamped_target_position_rad,
            base_target_velocity_rad_s: command.target_velocity_rad_s,
            maximum_target_speed_rad_s: command.maximum_target_speed_rad_s,
            raw_generalized_torque_command_nm: None,
            raw_canonical_velocity_delta_rad_s: None,
            scaled_canonical_velocity_delta_rad_s: None,
            applied_canonical_velocity_delta_rad_s: 0.0,
            requested_host_target_velocity_delta_rad_s: 0.0,
            combined_target_velocity_rad_s: command.target_velocity_rad_s,
            effective_host_target_velocity_delta_rad_s: 0.0,
            host_speed_saturated: false,
            fallback_zeroed: true,
        })
        .collect()
}

struct Snapshot {
    value: Value,
    nonfinite: bool,
    torso_ground_contact: bool,
    tilt_rad: f64,
    torso_height_m: f64,
    maximum_anchor_error_m: f64,
    maximum_hinge_axis_error_rad: f64,
}

fn snapshot(
    robot: &HostRobot,
    compiled: &CompiledQuadruped,
    state: &StateFrame,
) -> Result<Snapshot, String> {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    let tilt_rad = up.y.clamp(-1.0, 1.0).acos() as f64;
    let torso_height_m = torso.translation().y as f64;
    let torso_ground_contact = robot.torso_ground_contact();
    let contacts = robot.contacts(compiled);
    let (maximum_anchor_error_m, maximum_hinge_axis_error_rad) =
        robot.structural_metrics(compiled)?;
    let nonfinite = state_contains_nonfinite(state)
        || !tilt_rad.is_finite()
        || !torso_height_m.is_finite()
        || !maximum_anchor_error_m.is_finite()
        || !maximum_hinge_axis_error_rad.is_finite();
    Ok(Snapshot {
        value: json!({
            "torso_pose_world": state.base_pose_world,
            "torso_twist_world": state.base_twist_world,
            "torso_tilt_rad": tilt_rad,
            "torso_height_m": torso_height_m,
            "torso_ground_contact": torso_ground_contact,
            "ordered_declared_contacts": contacts,
            "maximum_anchor_error_m": maximum_anchor_error_m,
            "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
        }),
        nonfinite,
        torso_ground_contact,
        tilt_rad,
        torso_height_m,
        maximum_anchor_error_m,
        maximum_hinge_axis_error_rad,
    })
}

fn declared_failure_events(snapshot: &Snapshot) -> Vec<String> {
    let mut events = Vec::new();
    if snapshot.nonfinite {
        events.push("integrity_failure".to_owned());
    }
    if snapshot.torso_ground_contact {
        events.push("torso_ground_contact".to_owned());
    }
    if snapshot.tilt_rad > MAXIMUM_TILT_RAD {
        events.push("maximum_tilt_threshold_crossing".to_owned());
    }
    if snapshot.torso_height_m < MINIMUM_TORSO_HEIGHT_M {
        events.push("minimum_torso_height_threshold_crossing".to_owned());
    }
    if snapshot.maximum_anchor_error_m > MAXIMUM_ANCHOR_ERROR_M {
        events.push("maximum_anchor_error_threshold_crossing".to_owned());
    }
    if snapshot.maximum_hinge_axis_error_rad > MAXIMUM_HINGE_AXIS_ERROR_RAD {
        events.push("maximum_hinge_axis_error_threshold_crossing".to_owned());
    }
    events
}

fn first_event_receipt(semantic_step: u64, events: &[String]) -> Value {
    json!({
        "observation_point": "post_step",
        "semantic_step": semantic_step,
        "event_code": events.first(),
        "all_event_codes": events,
    })
}

fn first_trace_event(trace: &[Value]) -> Value {
    for step in trace {
        if let Some(events) = step["declared_failure_events"].as_array()
            && !events.is_empty()
        {
            let semantic_step = step["semantic_step"].as_u64().unwrap_or(u64::MAX);
            let event_codes = events
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect::<Vec<_>>();
            return first_event_receipt(semantic_step, &event_codes);
        }
    }
    Value::Null
}

fn host_observations(
    robot: &HostRobot,
    compiled: &CompiledQuadruped,
) -> Result<Vec<Value>, String> {
    compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .map(|actuator| {
            Ok(json!({
                "actuator_id": actuator.actuator_id,
                "joint_id": actuator.joint_id,
                "joint_angle_rad": robot.joint_angle(&actuator.joint_id)?,
                "motor_impulse_nms":
                    robot.actuator_motor_impulse(&actuator.actuator_id)?,
                "maximum_impulse_nms": actuator.maximum_impulse_nms,
            }))
        })
        .collect()
}

fn limb_memory_json(memory: &BalancedWaveControllerMemory) -> Vec<Value> {
    memory
        .ordered_limb_memory
        .iter()
        .map(|limb| {
            json!({
                "limb_id": limb.limb_id,
                "gait_step": limb.gait_step,
                "evidence_gait_step_limit": limb.evidence_gait_step_limit,
                "release_hold_step_count": limb.release_hold_step_count,
                "recontact_hold_step_count": limb.recontact_hold_step_count,
                "gate_timeout_count": limb.gate_timeout_count,
                "phase_sync_hold_step_count": limb.phase_sync_hold_step_count,
            })
        })
        .collect()
}

fn run_arm(arm_id: &str, apply_residual: bool) -> Result<Value, String> {
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot = build_bw19v_robot(&compiled)?;
    for _ in 0..SETTLE_STEPS {
        robot.hold_zero_and_step()?;
    }
    let task_origin = robot.torso_position();
    let initial_contacts = robot.contacts(&compiled);
    let post_settle_state = robot.state_frame(&compiled, 0, task_origin)?;
    let post_settle_snapshot = snapshot(&robot, &compiled, &post_settle_state)?;
    let post_settle_events = declared_failure_events(&post_settle_snapshot);

    let mut memory = BalancedWaveControllerMemory::initial();
    let mut composition_memory = RapierBw19vCompositionMemory::default();
    let mut trace = Vec::with_capacity(HORIZON_STEPS as usize);
    let mut controller_error_count = 0_u64;
    let mut safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut motor_impulse_limit_violation_count = 0_u64;
    let mut native_motor_application_count = 0_u64;
    let mut base_command_count = 0_u64;
    let mut shadow_residual_command_count = 0_u64;
    let mut final_host_command_count = 0_u64;
    let mut post_step_host_observation_count = 0_u64;
    let mut shadow_nonzero_effective_count = 0_u64;
    let mut applied_residual_nonzero_count = 0_u64;
    let mut final_command_mismatch_from_base_count = 0_u64;
    let mut shadow_and_applied_residual_mismatch_count = 0_u64;
    let mut global_scale_mismatch_count = 0_u64;
    let mut response_reconstruction_maximum_error_nm = 0.0_f64;

    for semantic_step in 0..HORIZON_STEPS {
        let state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let pre_snapshot = snapshot(&robot, &compiled, &state)?;
        if pre_snapshot.nonfinite {
            nonfinite_observation_count += 1;
        }
        let stability_state = robot.bw19v_stability_state(&compiled, semantic_step)?;
        let kinematics = robot.bw19v_endpoint_kinematics(&compiled, &stability_state)?;
        let limb_steps = ordered_limb_steps(&compiled, &memory)?;
        let memory_before = limb_memory_json(&memory);
        let output = controller.step(
            &memory,
            &state,
            &motion_command(semantic_step, PhaseProgressionMode::Clocked),
        );
        if output.actuation.receipt.controller_error.is_some()
            || !output.actuation.failure_codes.is_empty()
        {
            controller_error_count += 1;
        }
        if output.actuation.safe_no_actuation {
            safe_no_actuation_count += 1;
        }
        output
            .actuation
            .validate(&compiled.morphology)
            .map_err(|error| format!("C6_RAP_BW19V_ED1_ACTUATION_INVALID:{error}"))?;
        let base_commands = output
            .actuation
            .ordered_commands
            .iter()
            .map(base_command_json)
            .collect::<Vec<_>>();
        base_command_count += base_commands.len() as u64;

        let composition = compose_bw19v_step(
            &compiled,
            &output.actuation,
            stability_state,
            kinematics,
            limb_steps,
            &mut composition_memory,
        );
        let receipt = match composition {
            Ok(receipt) => receipt,
            Err(error) => {
                return Err(format!(
                    "C6_RAP_BW19V_ED1_COMPOSITION_FAILED:{semantic_step}:{error}"
                ));
            }
        };
        if receipt
            .stability_influence
            .global_requested_correction_scale
            != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        {
            global_scale_mismatch_count += 1;
        }
        response_reconstruction_maximum_error_nm = response_reconstruction_maximum_error_nm
            .max(receipt.response_reconstruction_maximum_error_nm);
        shadow_nonzero_effective_count += receipt.nonzero_effective_host_application_count as u64;
        let shadow_commands = receipt
            .ordered_commands
            .iter()
            .map(residual_command_json)
            .collect::<Vec<_>>();
        shadow_residual_command_count += shadow_commands.len() as u64;
        let receipt_json = receipt.to_json();
        let receipt_sha256 = digest_json(&receipt_json).map_err(|error| error.to_string())?;

        let host_commands = if apply_residual {
            receipt.ordered_commands.clone()
        } else {
            base_only_host_commands(&output.actuation)
        };
        for ((base, shadow), final_command) in output
            .actuation
            .ordered_commands
            .iter()
            .zip(&receipt.ordered_commands)
            .zip(&host_commands)
        {
            if final_command.effective_host_target_velocity_delta_rad_s != 0.0 {
                applied_residual_nonzero_count += 1;
            }
            if !apply_residual
                && (final_command.base_target_position_rad != base.clamped_target_position_rad
                    || final_command.combined_target_velocity_rad_s != base.target_velocity_rad_s)
            {
                final_command_mismatch_from_base_count += 1;
            }
            if apply_residual
                && (final_command.combined_target_velocity_rad_s
                    != shadow.combined_target_velocity_rad_s
                    || final_command.effective_host_target_velocity_delta_rad_s
                        != shadow.effective_host_target_velocity_delta_rad_s)
            {
                shadow_and_applied_residual_mismatch_count += 1;
            }
        }
        let final_commands = host_commands
            .iter()
            .map(final_command_json)
            .collect::<Vec<_>>();
        final_host_command_count += final_commands.len() as u64;
        let (applications, violations) = robot.apply_bw19v_composed_actuation(&host_commands)?;
        native_motor_application_count += applications;
        motor_impulse_limit_violation_count += violations;
        if applications != host_commands.len() as u64 {
            actuator_application_mismatch_count += 1;
        }

        let post_state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let post_snapshot = snapshot(&robot, &compiled, &post_state)?;
        if post_snapshot.nonfinite {
            nonfinite_observation_count += 1;
        }
        let events = declared_failure_events(&post_snapshot);
        let observations = host_observations(&robot, &compiled)?;
        post_step_host_observation_count += observations.len() as u64;
        trace.push(json!({
            "schema_version":
                "sporespore_rapier_c6_bw19v_ed1_trace_step_v1",
            "arm_id": arm_id,
            "semantic_step": semantic_step,
            "phase_progression_mode": "clocked",
            "command_provenance_recorded_before_application": true,
            "pre_state": pre_snapshot.value,
            "ordered_limb_controller_memory_before": memory_before,
            "ordered_base_commands": base_commands,
            "shadow_composition": {
                "planning_availability": availability_name(
                    receipt.scheduled_load_transfer.planning_availability
                ),
                "observation_input_available":
                    receipt.scheduled_load_transfer.observation_input_available,
                "observation_unavailable_reason":
                    receipt.scheduled_load_transfer.observation_unavailable_reason,
                "planning_outcome_code":
                    receipt.scheduled_load_transfer.planning_outcome_code,
                "global_requested_correction_scale":
                    receipt.stability_influence.global_requested_correction_scale,
                "response_reconstruction_maximum_error_nm":
                    receipt.response_reconstruction_maximum_error_nm,
                "composition_receipt_sha256": receipt_sha256,
                "ordered_shadow_residual_commands": shadow_commands,
            },
            "residual_applied_to_host": apply_residual,
            "ordered_final_host_commands": final_commands,
            "post_state": post_snapshot.value,
            "ordered_post_step_host_observations": observations,
            "declared_failure_events": events,
        }));
        memory = output.next_memory;
    }

    let first_failure_event = first_trace_event(&trace);
    Ok(json!({
        "schema_version": "sporespore_rapier_c6_bw19v_ed1_arm_report_v1",
        "arm_id": arm_id,
        "arm_order_index": if arm_id == ARM_A { 0 } else { 1 },
        "completed_declared_horizon": true,
        "fatal_error": Value::Null,
        "residual_application_mode": if apply_residual {
            "exact_bw19v_b_full_composition"
        } else {
            "bw15f_b_base_only_shadow_bw19v_b"
        },
        "bw19v_plan_and_residual_computed": true,
        "bw19v_stability_contribution_applied_to_host": apply_residual,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": compiled.morphology.ordered_body_ids.len(),
        "joint_count": compiled.morphology.ordered_joint_ids.len(),
        "actuator_count": compiled.morphology.ordered_actuator_ids.len(),
        "settle_steps": SETTLE_STEPS,
        "controller_semantic_step_count": HORIZON_STEPS,
        "trace_step_count": trace.len(),
        "post_settle_initial_four_contact_stance":
            initial_contacts.values().all(|contact| *contact),
        "post_settle_state": post_settle_snapshot.value,
        "post_settle_declared_failure_events": post_settle_events,
        "controller_error_count": controller_error_count,
        "safe_no_actuation_count": safe_no_actuation_count,
        "nonfinite_observation_count": nonfinite_observation_count,
        "composition_error_count": 0,
        "actuator_application_mismatch_count": actuator_application_mismatch_count,
        "motor_impulse_limit_violation_count": motor_impulse_limit_violation_count,
        "native_motor_application_count": native_motor_application_count,
        "base_command_count": base_command_count,
        "shadow_residual_command_count": shadow_residual_command_count,
        "final_host_command_count": final_host_command_count,
        "post_step_host_observation_count": post_step_host_observation_count,
        "shadow_nonzero_effective_host_residual_count":
            shadow_nonzero_effective_count,
        "applied_residual_nonzero_count": applied_residual_nonzero_count,
        "final_command_mismatch_from_base_count":
            final_command_mismatch_from_base_count,
        "shadow_and_applied_residual_mismatch_count":
            shadow_and_applied_residual_mismatch_count,
        "global_scale_mismatch_count": global_scale_mismatch_count,
        "response_reconstruction_maximum_error_nm":
            response_reconstruction_maximum_error_nm,
        "motor_model_readback_mismatch_count": 0,
        "first_failure_event": first_failure_event,
        "ordered_trace": trace,
        "physical_acceptance_authority": false,
    }))
}

fn incomplete_arm(arm_id: &str, error: String) -> Value {
    json!({
        "schema_version": "sporespore_rapier_c6_bw19v_ed1_arm_report_v1",
        "arm_id": arm_id,
        "arm_order_index": if arm_id == ARM_A { 0 } else { 1 },
        "completed_declared_horizon": false,
        "fatal_error": error,
        "world_attempt_count": 1,
        "world_build_count": 0,
        "controller_semantic_step_count": 0,
        "trace_step_count": 0,
        "first_failure_event": Value::Null,
        "ordered_trace": [],
        "physical_acceptance_authority": false,
    })
}

fn pair_interpretation(arms: &[Value]) -> Value {
    if arms.len() != 2
        || arms
            .iter()
            .any(|arm| arm["completed_declared_horizon"] != true)
    {
        return json!({
            "classification": "integrity_failure_uninterpretable",
            "statement": "The paired physical diagnostic is incomplete and has no mechanism interpretation.",
            "exact_pair_causal_scope_only": true,
            "population_inference": false,
        });
    }
    let a_failed = !arms[0]["first_failure_event"].is_null();
    let b_failed = !arms[1]["first_failure_event"].is_null();
    let (classification, statement) = match (a_failed, b_failed) {
        (false, true) => (
            "full_composition_failure_only",
            "The applied BW19V-B residual is necessary for the observed declared early failure in this exact deterministic pair.",
        ),
        (true, false) => (
            "base_only_failure_only",
            "The applied BW19V-B residual prevents the observed declared early failure in this exact deterministic pair.",
        ),
        (true, true) => (
            "both_arms_failure",
            "The applied BW19V-B residual is not necessary for declared early failure in this exact deterministic pair.",
        ),
        (false, false) => (
            "neither_arm_failure",
            "No declared early failure occurred in either arm through semantic step 471.",
        ),
    };
    json!({
        "classification": classification,
        "statement": statement,
        "exact_pair_causal_scope_only": true,
        "population_inference": false,
        "policy_superiority": false,
        "walking_acceptance": false,
        "physical_acceptance_authority": false,
    })
}

fn claim_boundary() -> Value {
    json!({
        "complete_mechanism_development_trace_only": true,
        "technical_commissioning": false,
        "walking_acceptance": false,
        "policy_superiority": false,
        "policy_noninferiority_or_equivalence": false,
        "independent_validation": false,
        "population_inference": false,
        "arbitrary_quadruped_coverage": false,
        "continuous_full_volume_coverage": false,
        "material_robustness": false,
        "rough_terrain_robustness": false,
        "external_push_recovery": false,
        "sensor_noise_or_latency_robustness": false,
        "rapier_selected_policy_physical_c6": false,
        "cross_engine_c6": false,
        "different_physics_engines": false,
        "locomotion_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    })
}

fn expected_ids(report: &Value) -> Vec<&str> {
    report["ordered_actuator_ids"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .collect()
}

fn array_ids_exact(value: &Value, expected: &[&str]) -> bool {
    value
        .as_array()
        .map(|entries| {
            entries.len() == expected.len()
                && entries
                    .iter()
                    .zip(expected)
                    .all(|(entry, id)| entry["actuator_id"].as_str() == Some(*id))
        })
        .unwrap_or(false)
}

fn u64_at(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer).and_then(Value::as_u64)
}

fn f64_at(value: &Value, pointer: &str) -> Option<f64> {
    value.pointer(pointer).and_then(Value::as_f64)
}

fn finite_object_fields(value: &Value, fields: &[&str]) -> bool {
    value.as_object().is_some_and(|object| {
        object.len() == fields.len()
            && fields.iter().all(|field| {
                object
                    .get(*field)
                    .and_then(Value::as_f64)
                    .is_some_and(f64::is_finite)
            })
    })
}

fn pose_json_complete(value: &Value) -> bool {
    let Some(object) = value.as_object() else {
        return false;
    };
    if object.len() != 2
        || !finite_object_fields(&value["position_m"], &["x", "y", "z"])
        || !finite_object_fields(&value["orientation_xyzw"], &["x", "y", "z", "w"])
    {
        return false;
    }
    let orientation = &value["orientation_xyzw"];
    let norm_squared = ["x", "y", "z", "w"]
        .into_iter()
        .map(|field| {
            orientation[field]
                .as_f64()
                .expect("checked quaternion field")
        })
        .map(|component| component * component)
        .sum::<f64>();
    (norm_squared - 1.0).abs() <= 1.0e-9
}

fn twist_json_complete(value: &Value) -> bool {
    value.as_object().is_some_and(|object| object.len() == 2)
        && finite_object_fields(&value["linear_velocity_m_s"], &["x", "y", "z"])
        && finite_object_fields(&value["angular_velocity_rad_s"], &["x", "y", "z"])
}

fn declared_contacts_json_complete(value: &Value) -> bool {
    const DECLARED_CONTACT_IDS: [&str; 4] = [
        "front_left_foot",
        "front_right_foot",
        "rear_left_foot",
        "rear_right_foot",
    ];
    value.as_object().is_some_and(|object| {
        object.len() == DECLARED_CONTACT_IDS.len()
            && DECLARED_CONTACT_IDS
                .iter()
                .all(|contact_id| object.get(*contact_id).and_then(Value::as_bool).is_some())
    })
}

fn snapshot_json_complete(value: &Value) -> bool {
    pose_json_complete(&value["torso_pose_world"])
        && twist_json_complete(&value["torso_twist_world"])
        && value["torso_tilt_rad"].as_f64().is_some_and(f64::is_finite)
        && value["torso_height_m"].as_f64().is_some_and(f64::is_finite)
        && value["torso_ground_contact"].as_bool().is_some()
        && declared_contacts_json_complete(&value["ordered_declared_contacts"])
        && value["maximum_anchor_error_m"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["maximum_hinge_axis_error_rad"]
            .as_f64()
            .is_some_and(f64::is_finite)
}

fn events_from_snapshot_json(value: &Value) -> Option<Vec<String>> {
    if !snapshot_json_complete(value) {
        return None;
    }
    let mut events = Vec::new();
    if value["torso_ground_contact"].as_bool() == Some(true) {
        events.push("torso_ground_contact".to_owned());
    }
    if value["torso_tilt_rad"]
        .as_f64()
        .is_some_and(|number| number > MAXIMUM_TILT_RAD)
    {
        events.push("maximum_tilt_threshold_crossing".to_owned());
    }
    if value["torso_height_m"]
        .as_f64()
        .is_some_and(|number| number < MINIMUM_TORSO_HEIGHT_M)
    {
        events.push("minimum_torso_height_threshold_crossing".to_owned());
    }
    if value["maximum_anchor_error_m"]
        .as_f64()
        .is_some_and(|number| number > MAXIMUM_ANCHOR_ERROR_M)
    {
        events.push("maximum_anchor_error_threshold_crossing".to_owned());
    }
    if value["maximum_hinge_axis_error_rad"]
        .as_f64()
        .is_some_and(|number| number > MAXIMUM_HINGE_AXIS_ERROR_RAD)
    {
        events.push("maximum_hinge_axis_error_threshold_crossing".to_owned());
    }
    Some(events)
}

fn base_command_complete(value: &Value) -> bool {
    value["requested_target_position_rad"]
        .as_f64()
        .is_some_and(f64::is_finite)
        && value["clamped_target_position_rad"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["target_velocity_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["maximum_target_speed_rad_s"]
            .as_f64()
            .is_some_and(|number| number.is_finite() && number > 0.0)
        && value["valid_through_step"].as_u64().is_some()
}

fn shadow_command_complete(value: &Value) -> bool {
    value["applied_canonical_velocity_delta_rad_s"]
        .as_f64()
        .is_some_and(f64::is_finite)
        && value["requested_host_target_velocity_delta_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["combined_target_velocity_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["effective_host_target_velocity_delta_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["host_speed_saturated"].as_bool().is_some()
        && value["fallback_zeroed"].as_bool().is_some()
}

fn final_command_complete(value: &Value) -> bool {
    value["final_target_position_rad"]
        .as_f64()
        .is_some_and(f64::is_finite)
        && value["final_target_velocity_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["maximum_target_speed_rad_s"]
            .as_f64()
            .is_some_and(|number| number.is_finite() && number > 0.0)
        && value["applied_residual_velocity_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["motor_model"] == "ForceBased"
}

fn host_observation_complete(value: &Value) -> bool {
    value["joint_id"].as_str().is_some_and(|id| !id.is_empty())
        && value["joint_angle_rad"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["motor_impulse_nms"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["maximum_impulse_nms"]
            .as_f64()
            .is_some_and(|number| number.is_finite() && number > 0.0)
}

fn diagnostic_failures(report: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    if report["schema_version"] != REPORT_SCHEMA_VERSION
        || report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["preregistration_raw_sha256"] != PREREGISTRATION_RAW_SHA256
        || report["c2_closure_raw_sha256"] != C2_CLOSURE_RAW_SHA256
        || report["candidate_id"] != BW19V_CANDIDATE_ID
        || report["candidate_composition_digest"] != BW19V_CANDIDATE_COMPOSITION_DIGEST
        || report["selected_policy_id"] != BW19V_CONTROLLER_POLICY_ID
        || report["selected_policy_digest"] != BW19V_CONTROLLER_POLICY_DIGEST
        || report["runtime_profile_sha256"] != BW19V_S169_RUNTIME_PROFILE_SHA256
        || report["source_commit"].as_str().is_none_or(|commit| {
            commit.len() != 40 || !commit.bytes().all(|byte| byte.is_ascii_hexdigit())
        })
    {
        failures.push("C6_RAP_BW19V_ED1_IDENTITY_MISMATCH".to_owned());
    }
    if report["preflight"]["ok"] != true
        || u64_at(report, "/preflight/world_build_count") != Some(0)
        || u64_at(report, "/preflight/physics_state_mutation_count") != Some(0)
    {
        failures.push("C6_RAP_BW19V_ED1_PREFLIGHT_INVALID".to_owned());
    }
    if report["engine"] != "rapier3d"
        || report["engine_version"] != rapier3d::VERSION
        || report["adapter_id"] != ADAPTER_ID
        || report["host_configuration"]["motor_model"] != "ForceBased"
        || u64_at(report, "/host_configuration/solver_iterations")
            != Some(RAPIER_ACTIVE_SOLVER_ITERATIONS as u64)
        || u64_at(report, "/host_configuration/internal_pgs_iterations")
            != Some(RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS as u64)
        || u64_at(
            report,
            "/host_configuration/internal_stabilization_iterations",
        ) != Some(RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS as u64)
    {
        failures.push("C6_RAP_BW19V_ED1_HOST_IDENTITY_MISMATCH".to_owned());
    }
    if u64_at(report, "/world_attempt_count") != Some(2)
        || u64_at(report, "/world_build_count") != Some(2)
        || u64_at(report, "/world_reset_count") != Some(0)
        || u64_at(report, "/trace_step_count_total") != Some(TOTAL_TRACE_STEPS)
        || u64_at(report, "/base_command_count_total") != Some(TOTAL_COMMANDS_PER_LAYER)
        || u64_at(report, "/shadow_residual_command_count_total") != Some(TOTAL_COMMANDS_PER_LAYER)
        || u64_at(report, "/final_host_command_count_total") != Some(TOTAL_COMMANDS_PER_LAYER)
        || u64_at(report, "/post_step_host_observation_count_total")
            != Some(TOTAL_COMMANDS_PER_LAYER)
    {
        failures.push("C6_RAP_BW19V_ED1_AGGREGATE_COUNT_MISMATCH".to_owned());
    }
    let claims = &report["claim_boundary"];
    if claims["complete_mechanism_development_trace_only"] != true
        || claims.as_object().is_none_or(|fields| {
            fields.iter().any(|(name, value)| {
                name != "complete_mechanism_development_trace_only" && value == true
            })
        })
    {
        failures.push("C6_RAP_BW19V_ED1_CLAIM_INFLATION".to_owned());
    }

    let expected = expected_ids(report);
    if expected.len() != ACTUATOR_COUNT {
        failures.push("C6_RAP_BW19V_ED1_ACTUATOR_IDENTITY_INVALID".to_owned());
    }
    let Some(arms) = report["arms"].as_array() else {
        failures.push("C6_RAP_BW19V_ED1_ARMS_MISSING".to_owned());
        return failures;
    };
    if arms.len() != 2
        || arms[0]["arm_id"] != ARM_A
        || arms[1]["arm_id"] != ARM_B
        || arms[0]["arm_order_index"] != 0
        || arms[1]["arm_order_index"] != 1
    {
        failures.push("C6_RAP_BW19V_ED1_ARM_ORDER_INVALID".to_owned());
        return failures;
    }
    for (index, arm) in arms.iter().enumerate() {
        let arm_id = if index == 0 { ARM_A } else { ARM_B };
        if arm["completed_declared_horizon"] != true
            || !arm["fatal_error"].is_null()
            || u64_at(arm, "/world_attempt_count") != Some(1)
            || u64_at(arm, "/world_build_count") != Some(1)
            || u64_at(arm, "/world_reset_count") != Some(0)
            || u64_at(arm, "/body_count") != Some(9)
            || u64_at(arm, "/joint_count") != Some(8)
            || u64_at(arm, "/actuator_count") != Some(8)
            || u64_at(arm, "/settle_steps") != Some(SETTLE_STEPS)
            || u64_at(arm, "/controller_semantic_step_count") != Some(HORIZON_STEPS)
            || u64_at(arm, "/trace_step_count") != Some(HORIZON_STEPS)
            || arm["post_settle_initial_four_contact_stance"] != true
            || !snapshot_json_complete(&arm["post_settle_state"])
            || arm["post_settle_declared_failure_events"]
                .as_array()
                .is_none_or(|events| !events.is_empty())
        {
            failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_HORIZON_INVALID"));
        }
        for pointer in [
            "/controller_error_count",
            "/safe_no_actuation_count",
            "/nonfinite_observation_count",
            "/composition_error_count",
            "/actuator_application_mismatch_count",
            "/motor_impulse_limit_violation_count",
            "/global_scale_mismatch_count",
            "/motor_model_readback_mismatch_count",
        ] {
            if u64_at(arm, pointer) != Some(0) {
                failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_INTEGRITY_COUNT"));
                break;
            }
        }
        for (pointer, expected_count) in [
            ("/native_motor_application_count", HORIZON_STEPS * 8),
            ("/base_command_count", HORIZON_STEPS * 8),
            ("/shadow_residual_command_count", HORIZON_STEPS * 8),
            ("/final_host_command_count", HORIZON_STEPS * 8),
            ("/post_step_host_observation_count", HORIZON_STEPS * 8),
        ] {
            if u64_at(arm, pointer) != Some(expected_count) {
                failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_COMMAND_COUNT"));
                break;
            }
        }
        if f64_at(arm, "/response_reconstruction_maximum_error_nm")
            .is_none_or(|error| error > 1.0e-12)
        {
            failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_RESPONSE_ERROR"));
        }
        if index == 0 {
            if arm["bw19v_stability_contribution_applied_to_host"] != false
                || u64_at(arm, "/applied_residual_nonzero_count") != Some(0)
                || u64_at(arm, "/final_command_mismatch_from_base_count") != Some(0)
            {
                failures.push("C6_RAP_BW19V_ED1_ARM_A_INTERVENTION_INVALID".to_owned());
            }
        } else if arm["bw19v_stability_contribution_applied_to_host"] != true
            || u64_at(arm, "/shadow_nonzero_effective_host_residual_count")
                .is_none_or(|count| count == 0)
            || u64_at(arm, "/shadow_and_applied_residual_mismatch_count") != Some(0)
        {
            failures.push("C6_RAP_BW19V_ED1_ARM_B_INTERVENTION_INVALID".to_owned());
        }

        let Some(trace) = arm["ordered_trace"].as_array() else {
            failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_TRACE_MISSING"));
            continue;
        };
        if trace.len() != HORIZON_STEPS as usize {
            failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_TRACE_COUNT"));
            continue;
        }
        for (semantic_step, entry) in trace.iter().enumerate() {
            let base = &entry["ordered_base_commands"];
            let shadow = &entry["shadow_composition"]["ordered_shadow_residual_commands"];
            let final_commands = &entry["ordered_final_host_commands"];
            let observations = &entry["ordered_post_step_host_observations"];
            if entry["arm_id"] != arm_id
                || entry["semantic_step"].as_u64() != Some(semantic_step as u64)
                || entry["phase_progression_mode"] != "clocked"
                || entry["command_provenance_recorded_before_application"] != true
                || !array_ids_exact(base, &expected)
                || !array_ids_exact(shadow, &expected)
                || !array_ids_exact(final_commands, &expected)
                || !array_ids_exact(observations, &expected)
                || !snapshot_json_complete(&entry["pre_state"])
                || !snapshot_json_complete(&entry["post_state"])
                || entry["ordered_limb_controller_memory_before"]
                    .as_array()
                    .is_none_or(|memory| memory.len() != 4)
                || entry["shadow_composition"]["planning_availability"]
                    .as_str()
                    .is_none_or(|availability| {
                        ![
                            "available",
                            "observation_unavailable",
                            "upstream_infeasible",
                        ]
                        .contains(&availability)
                    })
                || entry["shadow_composition"]["observation_input_available"]
                    .as_bool()
                    .is_none()
                || entry["shadow_composition"]["global_requested_correction_scale"].as_f64()
                    != Some(BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE)
                || entry["shadow_composition"]["response_reconstruction_maximum_error_nm"]
                    .as_f64()
                    .is_none_or(|error| !error.is_finite() || error > 1.0e-12)
                || entry["shadow_composition"]["composition_receipt_sha256"]
                    .as_str()
                    .is_none_or(|digest| digest.len() != 71 || !digest.starts_with("sha256:"))
            {
                failures.push(format!(
                    "C6_RAP_BW19V_ED1_{arm_id}_TRACE_INVALID:{semantic_step}"
                ));
                break;
            }
            let base_entries = base.as_array().expect("checked base array");
            let shadow_entries = shadow.as_array().expect("checked shadow array");
            let final_entries = final_commands.as_array().expect("checked final array");
            let observation_entries = observations.as_array().expect("checked observation array");
            if base_entries
                .iter()
                .any(|entry| !base_command_complete(entry))
                || shadow_entries
                    .iter()
                    .any(|entry| !shadow_command_complete(entry))
                || final_entries
                    .iter()
                    .any(|entry| !final_command_complete(entry))
                || observation_entries
                    .iter()
                    .any(|entry| !host_observation_complete(entry))
            {
                failures.push(format!(
                    "C6_RAP_BW19V_ED1_{arm_id}_TRACE_LAYER_INCOMPLETE:{semantic_step}"
                ));
                break;
            }
            let Some(derived_events) = events_from_snapshot_json(&entry["post_state"]) else {
                failures.push(format!(
                    "C6_RAP_BW19V_ED1_{arm_id}_POST_STATE_INVALID:{semantic_step}"
                ));
                break;
            };
            if entry["declared_failure_events"] != json!(derived_events) {
                failures.push(format!(
                    "C6_RAP_BW19V_ED1_{arm_id}_EVENT_RECONSTRUCTION_MISMATCH:{semantic_step}"
                ));
                break;
            }
            for ((base_command, shadow_command), final_command) in
                base_entries.iter().zip(shadow_entries).zip(final_entries)
            {
                let base_velocity = base_command["target_velocity_rad_s"].as_f64();
                let shadow_effective =
                    shadow_command["effective_host_target_velocity_delta_rad_s"].as_f64();
                let shadow_combined = shadow_command["combined_target_velocity_rad_s"].as_f64();
                let final_velocity = final_command["final_target_velocity_rad_s"].as_f64();
                let applied_residual = final_command["applied_residual_velocity_rad_s"].as_f64();
                if index == 0 && (applied_residual != Some(0.0) || final_velocity != base_velocity)
                {
                    failures.push(format!(
                        "C6_RAP_BW19V_ED1_ARM_A_NONZERO_APPLICATION:{semantic_step}"
                    ));
                    break;
                }
                if index == 1
                    && (applied_residual != shadow_effective || final_velocity != shadow_combined)
                {
                    failures.push(format!(
                        "C6_RAP_BW19V_ED1_ARM_B_APPLICATION_MISMATCH:{semantic_step}"
                    ));
                    break;
                }
            }
        }
        let derived_first = first_trace_event(trace);
        if arm["first_failure_event"] != derived_first {
            failures.push(format!("C6_RAP_BW19V_ED1_{arm_id}_FIRST_EVENT_MISMATCH"));
        }
    }
    if report["pair_interpretation"] != pair_interpretation(arms) {
        failures.push("C6_RAP_BW19V_ED1_PAIR_INTERPRETATION_MISMATCH".to_owned());
    }
    failures
}

fn synthetic_snapshot_value() -> Value {
    json!({
        "torso_pose_world": {
            "position_m": { "x": 0.0, "y": 0.4, "z": 0.0 },
            "orientation_xyzw": { "x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0 },
        },
        "torso_twist_world": {
            "linear_velocity_m_s": { "x": 0.0, "y": 0.0, "z": 0.0 },
            "angular_velocity_rad_s": { "x": 0.0, "y": 0.0, "z": 0.0 },
        },
        "torso_tilt_rad": 0.0,
        "torso_height_m": 0.4,
        "torso_ground_contact": false,
        "ordered_declared_contacts": {
            "front_left_foot": true,
            "front_right_foot": true,
            "rear_left_foot": true,
            "rear_right_foot": true,
        },
        "maximum_anchor_error_m": 0.0,
        "maximum_hinge_axis_error_rad": 0.0,
    })
}

fn synthetic_trace_step(
    arm_id: &str,
    semantic_step: u64,
    actuator_ids: &[String],
    apply_residual: bool,
) -> Value {
    let base_velocity = 0.2_f64;
    let residual = 0.001_f64;
    let base = actuator_ids
        .iter()
        .map(|id| {
            json!({
                "actuator_id": id,
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "target_velocity_rad_s": base_velocity,
                "maximum_target_speed_rad_s": 3.5,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let shadow = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            let effective = if index == 0 { residual } else { 0.0 };
            json!({
                "actuator_id": id,
                "applied_canonical_velocity_delta_rad_s": effective,
                "requested_host_target_velocity_delta_rad_s": effective,
                "combined_target_velocity_rad_s": base_velocity + effective,
                "effective_host_target_velocity_delta_rad_s": effective,
                "host_speed_saturated": false,
                "fallback_zeroed": false,
            })
        })
        .collect::<Vec<_>>();
    let final_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            let effective = if apply_residual && index == 0 {
                residual
            } else {
                0.0
            };
            json!({
                "actuator_id": id,
                "final_target_position_rad": 0.0,
                "final_target_velocity_rad_s": base_velocity + effective,
                "maximum_target_speed_rad_s": 3.5,
                "applied_residual_velocity_rad_s": effective,
                "motor_model": "ForceBased",
            })
        })
        .collect::<Vec<_>>();
    let observations = actuator_ids
        .iter()
        .map(|id| {
            json!({
                "actuator_id": id,
                "joint_id": id.replace("_motor", "_joint"),
                "joint_angle_rad": 0.0,
                "motor_impulse_nms": 0.0,
                "maximum_impulse_nms": 0.05,
            })
        })
        .collect::<Vec<_>>();
    let snapshot = synthetic_snapshot_value();
    let limb_memory = ["front_left", "front_right", "rear_left", "rear_right"]
        .into_iter()
        .map(|limb_id| json!({ "limb_id": limb_id, "gait_step": semantic_step }))
        .collect::<Vec<_>>();
    json!({
        "schema_version": "sporespore_rapier_c6_bw19v_ed1_trace_step_v1",
        "arm_id": arm_id,
        "semantic_step": semantic_step,
        "phase_progression_mode": "clocked",
        "command_provenance_recorded_before_application": true,
        "pre_state": snapshot.clone(),
        "ordered_limb_controller_memory_before": limb_memory,
        "ordered_base_commands": base,
        "shadow_composition": {
            "planning_availability": "available",
            "observation_input_available": true,
            "global_requested_correction_scale": 0.5,
            "response_reconstruction_maximum_error_nm": 0.0,
            "composition_receipt_sha256": format!("sha256:{semantic_step:064x}"),
            "ordered_shadow_residual_commands": shadow,
        },
        "residual_applied_to_host": apply_residual,
        "ordered_final_host_commands": final_commands,
        "post_state": snapshot,
        "ordered_post_step_host_observations": observations,
        "declared_failure_events": [],
    })
}

fn synthetic_arm(arm_id: &str, actuator_ids: &[String], apply_residual: bool) -> Value {
    let trace = (0..HORIZON_STEPS)
        .map(|step| synthetic_trace_step(arm_id, step, actuator_ids, apply_residual))
        .collect::<Vec<_>>();
    json!({
        "schema_version": "sporespore_rapier_c6_bw19v_ed1_arm_report_v1",
        "arm_id": arm_id,
        "arm_order_index": if arm_id == ARM_A { 0 } else { 1 },
        "completed_declared_horizon": true,
        "fatal_error": Value::Null,
        "residual_application_mode": if apply_residual {
            "exact_bw19v_b_full_composition"
        } else {
            "bw15f_b_base_only_shadow_bw19v_b"
        },
        "bw19v_plan_and_residual_computed": true,
        "bw19v_stability_contribution_applied_to_host": apply_residual,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": 9,
        "joint_count": 8,
        "actuator_count": 8,
        "settle_steps": SETTLE_STEPS,
        "controller_semantic_step_count": HORIZON_STEPS,
        "trace_step_count": HORIZON_STEPS,
        "post_settle_initial_four_contact_stance": true,
        "post_settle_state": synthetic_snapshot_value(),
        "post_settle_declared_failure_events": [],
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "nonfinite_observation_count": 0,
        "composition_error_count": 0,
        "actuator_application_mismatch_count": 0,
        "motor_impulse_limit_violation_count": 0,
        "native_motor_application_count": HORIZON_STEPS * 8,
        "base_command_count": HORIZON_STEPS * 8,
        "shadow_residual_command_count": HORIZON_STEPS * 8,
        "final_host_command_count": HORIZON_STEPS * 8,
        "post_step_host_observation_count": HORIZON_STEPS * 8,
        "shadow_nonzero_effective_host_residual_count": HORIZON_STEPS,
        "applied_residual_nonzero_count": if apply_residual { HORIZON_STEPS } else { 0 },
        "final_command_mismatch_from_base_count": 0,
        "shadow_and_applied_residual_mismatch_count": 0,
        "global_scale_mismatch_count": 0,
        "response_reconstruction_maximum_error_nm": 0.0,
        "motor_model_readback_mismatch_count": 0,
        "first_failure_event": Value::Null,
        "ordered_trace": trace,
        "physical_acceptance_authority": false,
    })
}

fn report_shell(source_commit: &str, preflight: Value, arms: Vec<Value>) -> Result<Value, String> {
    let (compiled, _controller) = compile_declared_boundary()?;
    let pair = pair_interpretation(&arms);
    Ok(json!({
        "schema_version": REPORT_SCHEMA_VERSION,
        "ok": false,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source_commit": source_commit,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "preflight": preflight,
        "engine": "rapier3d",
        "engine_version": rapier3d::VERSION,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "selected_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
        "reference_runtime_profile_sha256": BW19V_REFERENCE_RUNTIME_PROFILE_SHA256,
        "runtime_profile_sha256": BW19V_S169_RUNTIME_PROFILE_SHA256,
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "ordered_actuator_ids": compiled.morphology.ordered_actuator_ids,
        "host_configuration": {
            "motor_model": "ForceBased",
            "motor_stiffness_nm_per_rad": 40.0,
            "motor_damping_nm_s_per_rad":
                RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
            "outer_timestep_s": RAPIER_DT_S,
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations":
                RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "authored_friction": BW19V_AUTHORED_FRICTION,
            "characterized_controller_friction":
                BW19V_CHARACTERIZED_CONTROLLER_FRICTION,
            "motor_force_margin": MOTOR_FORCE_MARGIN,
        },
        "study_class":
            "outcome_exposed_paired_single_body_mechanism_development_screen",
        "report_ok_means_complete_diagnostic_not_physical_success": true,
        "physical_failure_events_are_not_diagnostic_gate_failures": true,
        "world_attempt_count": 2,
        "world_build_count": arms.iter().map(|arm| {
            arm["world_build_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "world_reset_count": 0,
        "trace_step_count_total": arms.iter().map(|arm| {
            arm["trace_step_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "base_command_count_total": arms.iter().map(|arm| {
            arm["base_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "shadow_residual_command_count_total": arms.iter().map(|arm| {
            arm["shadow_residual_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "final_host_command_count_total": arms.iter().map(|arm| {
            arm["final_host_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "post_step_host_observation_count_total": arms.iter().map(|arm| {
            arm["post_step_host_observation_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "arms": arms,
        "pair_interpretation": pair,
        "claim_boundary": claim_boundary(),
        "diagnostic_gate_failures": [],
    }))
}

fn set_synthetic_failure(report: &mut Value, arm_index: usize, event_code: &str) {
    let event_codes = vec![event_code.to_owned()];
    if event_code == "torso_ground_contact" {
        report["arms"][arm_index]["ordered_trace"][117]["post_state"]["torso_ground_contact"] =
            json!(true);
    }
    report["arms"][arm_index]["ordered_trace"][117]["declared_failure_events"] = json!(event_codes);
    report["arms"][arm_index]["first_failure_event"] =
        first_event_receipt(117, &[event_code.to_owned()]);
    let arms = report["arms"].as_array().expect("synthetic arms");
    report["pair_interpretation"] = pair_interpretation(arms);
}

fn perfect_synthetic_report() -> Result<Value, String> {
    let (compiled, _controller) = compile_declared_boundary()?;
    report_shell(
        "0000000000000000000000000000000000000000",
        json!({
            "ok": true,
            "world_build_count": 0,
            "physics_state_mutation_count": 0,
        }),
        vec![
            synthetic_arm(ARM_A, &compiled.morphology.ordered_actuator_ids, false),
            synthetic_arm(ARM_B, &compiled.morphology.ordered_actuator_ids, true),
        ],
    )
}

pub fn run_bw19v_early_horizon_development_preflight() -> Result<Value, String> {
    if raw_sha256(PREREGISTRATION) != PREREGISTRATION_RAW_SHA256 {
        return Err("C6_RAP_BW19V_ED1_PREREGISTRATION_HASH_MISMATCH".to_owned());
    }
    if raw_sha256(C2_CLOSURE) != C2_CLOSURE_RAW_SHA256 {
        return Err("C6_RAP_BW19V_ED1_C2_CLOSURE_HASH_MISMATCH".to_owned());
    }
    let perfect = perfect_synthetic_report()?;
    let perfect_passed = diagnostic_failures(&perfect).is_empty();

    let outcome_variants_passed = [(false, false), (true, false), (false, true), (true, true)]
        .into_iter()
        .all(|(a_failure, b_failure)| {
            let mut report = perfect.clone();
            if a_failure {
                set_synthetic_failure(&mut report, 0, "torso_ground_contact");
            }
            if b_failure {
                set_synthetic_failure(&mut report, 1, "torso_ground_contact");
            }
            diagnostic_failures(&report).is_empty()
        });

    let mut missing_trace = perfect.clone();
    missing_trace["arms"][0]["ordered_trace"]
        .as_array_mut()
        .expect("synthetic trace")
        .pop();
    let missing_trace_step_canary_rejected = !diagnostic_failures(&missing_trace).is_empty();

    let mut reordered = perfect.clone();
    reordered["arms"][0]["ordered_trace"][1]["semantic_step"] = json!(7);
    let reordered_semantic_step_canary_rejected = !diagnostic_failures(&reordered).is_empty();

    let mut arm_a_nonzero = perfect.clone();
    arm_a_nonzero["arms"][0]["ordered_trace"][0]["ordered_final_host_commands"][0]["applied_residual_velocity_rad_s"] =
        json!(0.001);
    arm_a_nonzero["arms"][0]["applied_residual_nonzero_count"] = json!(1);
    let arm_a_nonzero_applied_residual_canary_rejected =
        !diagnostic_failures(&arm_a_nonzero).is_empty();

    let mut arm_b_missing = perfect.clone();
    arm_b_missing["arms"][1]["shadow_nonzero_effective_host_residual_count"] = json!(0);
    let arm_b_missing_nonzero_shadow_residual_canary_rejected =
        !diagnostic_failures(&arm_b_missing).is_empty();

    let mut command_count = perfect.clone();
    command_count["final_host_command_count_total"] = json!(TOTAL_COMMANDS_PER_LAYER - 1);
    let final_command_count_canary_rejected = !diagnostic_failures(&command_count).is_empty();

    let mut nested_state_schema = perfect.clone();
    nested_state_schema["arms"][0]["ordered_trace"][0]["post_state"]["torso_pose_world"]["position_m"]
        ["x"] = json!("corrupt");
    let nested_state_schema_canary_rejected = !diagnostic_failures(&nested_state_schema).is_empty();

    let mut inflated = perfect.clone();
    inflated["claim_boundary"]["walking_acceptance"] = json!(true);
    let claim_inflation_canary_rejected = !diagnostic_failures(&inflated).is_empty();

    let round_trip: Value =
        serde_json::from_str(&serde_json::to_string(&perfect).map_err(|error| error.to_string())?)
            .map_err(|error| error.to_string())?;
    let report = json!({
        "schema_version": PREFLIGHT_SCHEMA_VERSION,
        "ok": perfect_passed
            && outcome_variants_passed
            && missing_trace_step_canary_rejected
            && reordered_semantic_step_canary_rejected
            && arm_a_nonzero_applied_residual_canary_rejected
            && arm_b_missing_nonzero_shadow_residual_canary_rejected
            && final_command_count_canary_rejected
            && nested_state_schema_canary_rejected
            && claim_inflation_canary_rejected
            && round_trip == perfect,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "perfect_synthetic_two_arm_report_passed_complete_integrity_gate":
            perfect_passed,
        "synthetic_outcome_variants_all_integrity_valid": outcome_variants_passed,
        "synthetic_arm_count": 2,
        "synthetic_trace_step_count": TOTAL_TRACE_STEPS,
        "synthetic_command_count_per_layer": TOTAL_COMMANDS_PER_LAYER,
        "missing_trace_step_canary_rejected": missing_trace_step_canary_rejected,
        "reordered_semantic_step_canary_rejected":
            reordered_semantic_step_canary_rejected,
        "arm_a_nonzero_applied_residual_canary_rejected":
            arm_a_nonzero_applied_residual_canary_rejected,
        "arm_b_missing_nonzero_shadow_residual_canary_rejected":
            arm_b_missing_nonzero_shadow_residual_canary_rejected,
        "final_command_count_canary_rejected": final_command_count_canary_rejected,
        "nested_state_schema_canary_rejected": nested_state_schema_canary_rejected,
        "claim_inflation_canary_rejected": claim_inflation_canary_rejected,
        "serialization_round_trip_passed": round_trip == perfect,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    });
    if report["ok"] != true {
        return Err("C6_RAP_BW19V_ED1_PREFLIGHT_GATE_INVALID".to_owned());
    }
    Ok(report)
}

pub fn run_bw19v_early_horizon_development(source_commit: &str) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("C6_RAP_BW19V_ED1_SOURCE_COMMIT_INVALID".to_owned());
    }
    let preflight = run_bw19v_early_horizon_development_preflight()?;
    let arms = [(ARM_A, false), (ARM_B, true)]
        .into_iter()
        .map(|(arm_id, apply_residual)| {
            run_arm(arm_id, apply_residual).unwrap_or_else(|error| incomplete_arm(arm_id, error))
        })
        .collect::<Vec<_>>();
    let mut report = report_shell(&source_commit.to_ascii_lowercase(), preflight, arms)?;
    let failures = diagnostic_failures(&report);
    report["diagnostic_gate_failures"] = json!(failures);
    report["ok"] = json!(
        report["diagnostic_gate_failures"]
            .as_array()
            .is_some_and(Vec::is_empty)
    );
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_zero_world_ed1_gate_and_canaries_pass() {
        let report = run_bw19v_early_horizon_development_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(report["synthetic_arm_count"], 2);
        assert_eq!(report["synthetic_trace_step_count"], 944);
        assert_eq!(report["synthetic_command_count_per_layer"], 7552);
        assert_eq!(
            report["synthetic_outcome_variants_all_integrity_valid"],
            true
        );
        assert_eq!(report["missing_trace_step_canary_rejected"], true);
        assert_eq!(report["reordered_semantic_step_canary_rejected"], true);
        assert_eq!(
            report["arm_a_nonzero_applied_residual_canary_rejected"],
            true
        );
        assert_eq!(
            report["arm_b_missing_nonzero_shadow_residual_canary_rejected"],
            true
        );
        assert_eq!(report["final_command_count_canary_rejected"], true);
        assert_eq!(report["claim_inflation_canary_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["physics_state_mutation_count"], 0);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn physical_outcomes_do_not_change_diagnostic_integrity() {
        let perfect = perfect_synthetic_report().unwrap();
        for (a_failure, b_failure) in [(false, false), (true, false), (false, true), (true, true)] {
            let mut report = perfect.clone();
            if a_failure {
                set_synthetic_failure(&mut report, 0, "torso_ground_contact");
            }
            if b_failure {
                set_synthetic_failure(&mut report, 1, "torso_ground_contact");
            }
            assert!(diagnostic_failures(&report).is_empty());
        }
    }
}
