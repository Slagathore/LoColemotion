use std::any::Any;
use std::panic::{AssertUnwindSafe, catch_unwind};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::PhaseProgressionMode;
use sporespore_locomotion_core::stability::StabilityInfluenceAvailability;
use sporespore_locomotion_core::{
    BALANCED_WAVE_BW15F_B_POLICY_ID, BalancedWaveController, BalancedWaveControllerMemory,
    CANONICAL_VELOCITY_RESIDUAL_V1_VERSION, CanonicalVelocityResidualV1, CompiledQuadruped,
    ScheduledLimbGaitStepV1, VelocityOnlyHostMappingReceiptV1, compile_bounded_quadruped,
    digest_json, digest_serializable,
};

use crate::bw19v_composition::{
    BW19V_CANDIDATE_COMPOSITION_DIGEST, BW19V_CANDIDATE_ID, BW19V_CONTROLLER_POLICY_DIGEST,
    BW19V_CONTROLLER_POLICY_ID, BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
    BW19V_S169_RUNTIME_PROFILE_SHA256, RapierBw19vCompositionMemory, compose_bw19v_step_v4,
    map_bw19v_velocity_only_v4,
};
use crate::locomotion::{
    HostRobot, build_bw19v_velocity_only_v4_robot, descriptor, motion_command,
    state_contains_nonfinite,
};
use crate::velocity_only_live_integration::{
    VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD, VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD,
    velocity_only_small_step_impulse_limit_v1,
};
use crate::{ADAPTER_ID, RAPIER_DT_S, capability_manifest_sha256};

const PREREGISTRATION_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_velocity_only_early_horizon_eh1_preregistration.json");
const LIVE_INTEGRATION_RAW: &str =
    include_str!("../../../rapier_c6_velocity_only_live_integration_v1.json");
const ACTIVE_CONFIGURATION_V2_RAW: &str =
    include_str!("../../../rapier_c6_velocity_only_active_configuration_v2.json");
const VH1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"
);
const ED1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.json");
const ASD1_DIAGNOSTIC_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_actuation_semantics_diagnostic.json");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:be3573e44948e3e2b17327ed0cfafe4c666055c39962c548eec54ed95fa69253";
const LIVE_INTEGRATION_RAW_SHA256: &str =
    "sha256:7c4c7435ca02f30073d5a33fce162fef67a461340ae609225b096abe59f88507";
const ACTIVE_CONFIGURATION_V2_RAW_SHA256: &str =
    "sha256:fb16ede4b295f69a343dde239c98874d547aba6cec6d47a71df1797f6c03c8fe";
const VH1_CLOSURE_RAW_SHA256: &str =
    "sha256:d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa";
const ED1_CLOSURE_RAW_SHA256: &str =
    "sha256:8155effd3e0141839964a18b59733fc256e3b5c130f936824b6a34c0cd21f3d4";
const ASD1_DIAGNOSTIC_RAW_SHA256: &str =
    "sha256:a42888f04c9a42af78ab3796dee9cc98365592470f81d0153bc55ab2a375ca57";
const RETAINED_EH1_REPORT_RAW_SHA256: &str =
    "sha256:cdbcebc11eb727f9d24be6900788f6fd180cf8fc27a7df71780dc7d1921f6fa5";

pub const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-VELOCITY-ONLY-EARLY-HORIZON-DEVELOPMENT-EH1";
pub const GATE_ID: &str = "C6-RAP-BW19V-V4-EH1";
const REPORT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_velocity_only_early_horizon_eh1_report_v1";
const PREFLIGHT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_velocity_only_early_horizon_eh1_preflight_v1";
const ARM_A: &str = "EH1-A";
const ARM_B: &str = "EH1-B";
const HORIZON_STEPS: u64 = 472;
const ACTUATOR_COUNT: usize = 8;
const TOTAL_TRACE_STEPS: u64 = HORIZON_STEPS * 2;
const COMMANDS_PER_ARM: u64 = HORIZON_STEPS * ACTUATOR_COUNT as u64;

const MAXIMUM_TILT_RAD: f64 = 0.6;
const MINIMUM_TORSO_HEIGHT_M: f64 = 0.2499708652072946;
const MAXIMUM_ANCHOR_ERROR_M: f64 = 0.025575899999999995;
const MAXIMUM_HINGE_AXIS_ERROR_RAD: f64 = 0.2;

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn preregistration() -> Result<Value, String> {
    for (raw, expected, code) in [
        (
            PREREGISTRATION_RAW,
            PREREGISTRATION_RAW_SHA256,
            "C6_RAP_V4_EH1_PREREGISTRATION_HASH",
        ),
        (
            LIVE_INTEGRATION_RAW,
            LIVE_INTEGRATION_RAW_SHA256,
            "C6_RAP_V4_EH1_LIVE_INTEGRATION_HASH",
        ),
        (
            ACTIVE_CONFIGURATION_V2_RAW,
            ACTIVE_CONFIGURATION_V2_RAW_SHA256,
            "C6_RAP_V4_EH1_ACTIVE_CONFIGURATION_HASH",
        ),
        (
            VH1_CLOSURE_RAW,
            VH1_CLOSURE_RAW_SHA256,
            "C6_RAP_V4_EH1_VH1_CLOSURE_HASH",
        ),
        (
            ED1_CLOSURE_RAW,
            ED1_CLOSURE_RAW_SHA256,
            "C6_RAP_V4_EH1_ED1_CLOSURE_HASH",
        ),
        (
            ASD1_DIAGNOSTIC_RAW,
            ASD1_DIAGNOSTIC_RAW_SHA256,
            "C6_RAP_V4_EH1_ASD1_DIAGNOSTIC_HASH",
        ),
    ] {
        if raw_sha256(raw) != expected {
            return Err(code.to_owned());
        }
    }
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_V4_EH1_PREREGISTRATION_PARSE:{error}"))?;
    if declaration["campaign_id"] != CAMPAIGN_ID
        || declaration["gate_id"] != GATE_ID
        || declaration["study_class"]
            != "outcome_exposed_paired_early_horizon_mechanism_development_screen"
        || declaration["physical_horizon"]["expected_world_count"] != 2
        || declaration["physical_horizon"]["steps_per_arm"] != HORIZON_STEPS
        || declaration["initialization_contract"]["zero_target_settle_steps"] != 0
        || declaration["frozen_portable_identity"]["controller_policy_id"]
            != BW19V_CONTROLLER_POLICY_ID
        || declaration["frozen_portable_identity"]["global_requested_correction_scale"]
            != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        || declaration["frozen_host_identity"]["motor_model"] != "ForceBased"
        || declaration["frozen_host_identity"]["motor_mode"] != "velocity_only"
        || declaration["frozen_host_identity"]["native_position_stiffness_nm_per_rad"] != 0.0
        || declaration["preflight_contract"]["world_build_count"] != 0
        || declaration["preflight_contract"]["physical_acceptance_authority"] != false
    {
        return Err("C6_RAP_V4_EH1_PREREGISTRATION_CONTRACT".to_owned());
    }
    Ok(declaration)
}

fn compile_declared_boundary() -> Result<(CompiledQuadruped, BalancedWaveController), String> {
    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller =
        BalancedWaveController::new_for_policy(compiled.clone(), BALANCED_WAVE_BW15F_B_POLICY_ID)
            .map_err(|error| error.to_string())?;
    let runtime_sha =
        digest_serializable(controller.profile()).map_err(|error| error.to_string())?;
    if controller.profile().policy_id != BW19V_CONTROLLER_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
        || runtime_sha != BW19V_S169_RUNTIME_PROFILE_SHA256
    {
        return Err("C6_RAP_V4_EH1_PORTABLE_IDENTITY".to_owned());
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
                .ok_or_else(|| format!("C6_RAP_V4_EH1_LIMB_MEMORY_MISSING:{limb_id}"))
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

struct Snapshot {
    value: Value,
    nonfinite: bool,
}

fn snapshot(
    robot: &HostRobot,
    compiled: &CompiledQuadruped,
    state: &sporespore_locomotion_core::StateFrame,
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
    })
}

fn events_from_snapshot(value: &Value) -> Option<Vec<String>> {
    let tilt = value["torso_tilt_rad"].as_f64()?;
    let height = value["torso_height_m"].as_f64()?;
    let torso_contact = value["torso_ground_contact"].as_bool()?;
    let anchor = value["maximum_anchor_error_m"].as_f64()?;
    let hinge = value["maximum_hinge_axis_error_rad"].as_f64()?;
    if [tilt, height, anchor, hinge]
        .iter()
        .any(|number| !number.is_finite())
    {
        return None;
    }
    let mut events = Vec::new();
    if torso_contact {
        events.push("torso_ground_contact".to_owned());
    }
    if tilt > MAXIMUM_TILT_RAD {
        events.push("maximum_tilt_threshold_crossing".to_owned());
    }
    if height < MINIMUM_TORSO_HEIGHT_M {
        events.push("minimum_torso_height_threshold_crossing".to_owned());
    }
    if anchor > MAXIMUM_ANCHOR_ERROR_M {
        events.push("maximum_anchor_error_threshold_crossing".to_owned());
    }
    if hinge > MAXIMUM_HINGE_AXIS_ERROR_RAD {
        events.push("maximum_hinge_axis_error_threshold_crossing".to_owned());
    }
    Some(events)
}

fn first_failure_event(trace: &[Value]) -> Value {
    for step in trace {
        if let Some(events) = step["declared_diagnostic_events"].as_array()
            && !events.is_empty()
        {
            return json!({
                "semantic_step": step["semantic_step"],
                "event_code": events[0],
                "all_event_codes": events,
                "observation_point": "post_step",
            });
        }
    }
    Value::Null
}

fn zero_residuals(
    actuation: &sporespore_locomotion_core::ActuationFrame,
) -> Vec<CanonicalVelocityResidualV1> {
    actuation
        .ordered_commands
        .iter()
        .map(|command| CanonicalVelocityResidualV1 {
            schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
            actuator_id: command.actuator_id.clone(),
            canonical_velocity_delta_rad_s: 0.0,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        })
        .collect()
}

fn motor_observations(
    robot: &HostRobot,
    mapping: &VelocityOnlyHostMappingReceiptV1,
) -> Result<(Vec<Value>, u64, u64, u64), String> {
    let mut observations = Vec::with_capacity(mapping.ordered_commands.len());
    let mut field_mismatches = 0_u64;
    let mut impulse_violations = 0_u64;
    let mut nonfinite = 0_u64;
    for command in &mapping.ordered_commands {
        let joint_id = robot
            .actuator_joints
            .get(&command.actuator_id)
            .ok_or_else(|| "C6_RAP_V4_EH1_ACTUATOR_MAPPING_MISSING".to_owned())?;
        let joint = robot
            .world
            .impulse_joints
            .get(robot.joints[joint_id])
            .ok_or_else(|| "C6_RAP_V4_EH1_JOINT_MISSING".to_owned())?;
        let motor = joint
            .data
            .as_revolute()
            .and_then(|revolute| revolute.motor())
            .ok_or_else(|| "C6_RAP_V4_EH1_MOTOR_MISSING".to_owned())?;
        let maximum_force = robot.actuator_maximum_force[&command.actuator_id];
        let small_step_limit = velocity_only_small_step_impulse_limit_v1(maximum_force);
        let fields_match = motor.model == MotorModel::ForceBased
            && motor.target_pos == 0.0
            && motor.target_vel == command.host_target_velocity_rad_s as f32
            && motor.stiffness == VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD
            && motor.damping == VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
            && motor.max_force == maximum_force;
        field_mismatches += u64::from(!fields_match);
        impulse_violations += u64::from(motor.impulse.abs() > small_step_limit + 1.0e-6);
        nonfinite += u64::from(
            !motor.target_vel.is_finite()
                || !motor.max_force.is_finite()
                || !motor.impulse.is_finite(),
        );
        observations.push(json!({
            "actuator_id": command.actuator_id,
            "motor_model": if motor.model == MotorModel::ForceBased {
                "ForceBased"
            } else {
                "AccelerationBased"
            },
            "target_position_rad": motor.target_pos,
            "target_velocity_rad_s": motor.target_vel,
            "expected_target_velocity_rad_s": command.host_target_velocity_rad_s,
            "stiffness_nm_per_rad": motor.stiffness,
            "damping_nm_s_per_rad": motor.damping,
            "maximum_force_nm": motor.max_force,
            "motor_impulse_nms": motor.impulse,
            "small_step_impulse_limit_nms": small_step_limit,
            "fields_match": fields_match,
        }));
    }
    Ok((
        observations,
        field_mismatches,
        impulse_violations,
        nonfinite,
    ))
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

fn count_nonzero_residuals(
    canonical: &sporespore_locomotion_core::CanonicalVelocityActuationFrameV1,
) -> u64 {
    canonical
        .ordered_commands
        .iter()
        .filter(|command| command.stability_canonical_velocity_delta_rad_s != 0.0)
        .count() as u64
}

fn count_applied_residuals(
    selected: &VelocityOnlyHostMappingReceiptV1,
    control: &VelocityOnlyHostMappingReceiptV1,
) -> Result<(u64, u64), String> {
    if selected.ordered_commands.len() != control.ordered_commands.len() {
        return Err("C6_RAP_V4_EH1_SELECTED_CONTROL_COMMAND_COUNT".to_owned());
    }
    let mut nonzero = 0_u64;
    let mut order_or_value_mismatches = 0_u64;
    for (selected_command, control_command) in selected
        .ordered_commands
        .iter()
        .zip(&control.ordered_commands)
    {
        if selected_command.actuator_id != control_command.actuator_id {
            order_or_value_mismatches += 1;
            continue;
        }
        if selected_command.host_target_velocity_rad_s != control_command.host_target_velocity_rad_s
        {
            nonzero += 1;
        }
        if selected_command.native_target_position_rad.is_some()
            || selected_command.requested_target_position_rad
                != control_command.requested_target_position_rad
            || selected_command.clamped_target_position_rad
                != control_command.clamped_target_position_rad
            || selected_command.maximum_host_target_speed_rad_s
                != control_command.maximum_host_target_speed_rad_s
        {
            order_or_value_mismatches += 1;
        }
    }
    Ok((nonzero, order_or_value_mismatches))
}

fn run_arm(arm_id: &str, apply_residual: bool) -> Result<Value, String> {
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot = build_bw19v_velocity_only_v4_robot(&compiled)?;
    let task_origin = robot.torso_position();
    let initial_state = robot.state_frame(&compiled, 0, task_origin)?;
    let initial_snapshot = snapshot(&robot, &compiled, &initial_state)?;
    let initial_events = events_from_snapshot(&initial_snapshot.value)
        .ok_or_else(|| "C6_RAP_V4_EH1_INITIAL_SNAPSHOT_INVALID".to_owned())?;
    let initial_contact_count = robot
        .contacts(&compiled)
        .values()
        .filter(|value| **value)
        .count();

    let mut memory = BalancedWaveControllerMemory::initial();
    let mut composition_memory = RapierBw19vCompositionMemory::default();
    let mut trace = Vec::with_capacity(HORIZON_STEPS as usize);
    let mut controller_error_count = 0_u64;
    let mut safe_no_actuation_count = 0_u64;
    let composition_error_count = 0_u64;
    let mut nonfinite_observation_count = u64::from(initial_snapshot.nonfinite);
    let mut actuator_application_mismatch_count = 0_u64;
    let mut motor_field_readback_mismatch_count = 0_u64;
    let mut small_step_impulse_limit_violation_count = 0_u64;
    let mut global_scale_mismatch_count = 0_u64;
    let mut native_position_target_application_count = 0_u64;
    let mut base_command_count = 0_u64;
    let mut bounded_residual_command_count = 0_u64;
    let mut canonical_command_count = 0_u64;
    let mut host_command_count = 0_u64;
    let mut motor_observation_count = 0_u64;
    let mut shadow_nonzero_bounded_residual_count = 0_u64;
    let mut applied_nonzero_stability_residual_count = 0_u64;
    let mut selected_control_mapping_mismatch_count = 0_u64;

    for semantic_step in 0..HORIZON_STEPS {
        let state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let pre_snapshot = snapshot(&robot, &compiled, &state)?;
        nonfinite_observation_count += u64::from(pre_snapshot.nonfinite);
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
        safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        output
            .actuation
            .validate(&compiled.morphology)
            .map_err(|error| format!("C6_RAP_V4_EH1_ACTUATION_INVALID:{error}"))?;
        let base_commands = output
            .actuation
            .ordered_commands
            .iter()
            .map(base_command_json)
            .collect::<Vec<_>>();
        base_command_count += base_commands.len() as u64;
        let controller_actuation_sha256 =
            digest_serializable(&output.actuation).map_err(|error| error.to_string())?;

        let composition = compose_bw19v_step_v4(
            &compiled,
            &output.actuation,
            stability_state,
            kinematics,
            limb_steps,
            &mut composition_memory,
        );
        let composition = match composition {
            Ok(receipt) => receipt,
            Err(error) => {
                return Err(format!(
                    "C6_RAP_V4_EH1_COMPOSITION_FAILED:{semantic_step}:{error}"
                ));
            }
        };
        if composition
            .planning_receipt
            .stability_influence
            .global_requested_correction_scale
            != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        {
            global_scale_mismatch_count += 1;
        }
        let bounded_residuals = composition
            .planning_receipt
            .stability_influence
            .ordered_applied_corrections
            .iter()
            .map(|correction| {
                json!({
                    "actuator_id": correction.actuator_id,
                    "applied_position_delta_rad": correction.applied_position_delta_rad,
                    "applied_velocity_delta_rad_s": correction.applied_velocity_delta_rad_s,
                    "fallback_zeroed": correction.fallback_zeroed,
                })
            })
            .collect::<Vec<_>>();
        bounded_residual_command_count += bounded_residuals.len() as u64;
        shadow_nonzero_bounded_residual_count +=
            count_nonzero_residuals(&composition.canonical_actuation);
        let composition_json = composition.to_json();
        let composition_receipt_sha256 =
            digest_json(&composition_json).map_err(|error| error.to_string())?;
        let (control_canonical, control_mapping) = map_bw19v_velocity_only_v4(
            &compiled,
            &output.actuation,
            &zero_residuals(&output.actuation),
        )?;
        let selected_mapping = if apply_residual {
            &composition.host_mapping
        } else {
            &control_mapping
        };
        let (applied_nonzero, mapping_mismatches) =
            count_applied_residuals(selected_mapping, &control_mapping)?;
        applied_nonzero_stability_residual_count += applied_nonzero;
        selected_control_mapping_mismatch_count += mapping_mismatches;
        native_position_target_application_count += selected_mapping
            .ordered_commands
            .iter()
            .filter(|command| command.native_target_position_rad.is_some())
            .count() as u64;
        canonical_command_count += if apply_residual {
            composition.canonical_actuation.ordered_commands.len() as u64
        } else {
            control_canonical.ordered_commands.len() as u64
        };
        host_command_count += selected_mapping.ordered_commands.len() as u64;
        let host_mapping_sha256 =
            digest_serializable(selected_mapping).map_err(|error| error.to_string())?;
        let selected_canonical = if apply_residual {
            &composition.canonical_actuation
        } else {
            &control_canonical
        };
        let canonical_actuation_sha256 =
            digest_serializable(selected_canonical).map_err(|error| error.to_string())?;

        let (applications, apply_impulse_violations) =
            robot.apply_bw19v_velocity_only_v4_actuation(selected_mapping)?;
        actuator_application_mismatch_count += u64::from(applications != ACTUATOR_COUNT as u64);

        let post_state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let post_snapshot = snapshot(&robot, &compiled, &post_state)?;
        nonfinite_observation_count += u64::from(post_snapshot.nonfinite);
        let events = events_from_snapshot(&post_snapshot.value)
            .ok_or_else(|| format!("C6_RAP_V4_EH1_POST_SNAPSHOT_INVALID:{semantic_step}"))?;
        let (motor_readbacks, field_mismatches, observed_impulse_violations, motor_nonfinite) =
            motor_observations(&robot, selected_mapping)?;
        motor_field_readback_mismatch_count += field_mismatches;
        small_step_impulse_limit_violation_count +=
            apply_impulse_violations.max(observed_impulse_violations);
        nonfinite_observation_count += motor_nonfinite;
        motor_observation_count += motor_readbacks.len() as u64;

        trace.push(json!({
            "schema_version": "sporespore_rapier_c6_bw19v_velocity_only_eh1_trace_step_v1",
            "arm_id": arm_id,
            "semantic_step": semantic_step,
            "phase_progression_mode": "clocked",
            "command_provenance_recorded_before_application": true,
            "pre_step_snapshot": pre_snapshot.value,
            "ordered_limb_controller_memory_before": memory_before,
            "portable_controller_actuation_receipt_sha256": controller_actuation_sha256,
            "ordered_portable_base_commands": base_commands,
            "shadow_v4_composition": {
                "planning_availability": availability_name(
                    composition.planning_receipt.scheduled_load_transfer.planning_availability
                ),
                "observation_input_available": composition
                    .planning_receipt
                    .scheduled_load_transfer
                    .observation_input_available,
                "planning_outcome_code": composition
                    .planning_receipt
                    .scheduled_load_transfer
                    .planning_outcome_code,
                "global_requested_correction_scale": composition
                    .planning_receipt
                    .stability_influence
                    .global_requested_correction_scale,
                "v4_planning_and_bounding_receipt_sha256": composition_receipt_sha256,
                "v4_planning_and_bounding_receipt": composition_json,
                "ordered_bounded_canonical_residuals": bounded_residuals,
                "retained_mixed_space_projection_applied": false,
                "retained_mixed_space_projection_difference_count": composition
                    .retained_mixed_space_projection_difference_count,
            },
            "residual_applied_to_host": apply_residual,
            "canonical_actuation_frame_sha256": canonical_actuation_sha256,
            "selected_canonical_actuation_frame": selected_canonical,
            "rapier_host_mapping_sha256": host_mapping_sha256,
            "selected_rapier_host_mapping": selected_mapping,
            "ordered_load_bearing_host_commands": selected_mapping.ordered_commands,
            "ordered_post_step_joint_motor_readbacks_and_impulses": motor_readbacks,
            "post_step_snapshot": post_snapshot.value,
            "declared_diagnostic_events": events,
        }));
        memory = output.next_memory;
    }

    Ok(json!({
        "schema_version": "sporespore_rapier_c6_bw19v_velocity_only_eh1_arm_report_v1",
        "arm_id": arm_id,
        "arm_order_index": if arm_id == ARM_A { 0 } else { 1 },
        "completed_declared_horizon": true,
        "fatal_error": Value::Null,
        "residual_application_mode": if apply_residual {
            "exact_canonical_bw15f_b_plus_bounded_bw19v_scale_0_5"
        } else {
            "exact_canonical_bw15f_b_plus_zero_residual_shadow_bw19v"
        },
        "bw19v_plan_and_residual_computed_in_shadow": true,
        "bw19v_stability_contribution_applied_to_host": apply_residual,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": compiled.morphology.ordered_body_ids.len(),
        "joint_count": compiled.morphology.ordered_joint_ids.len(),
        "actuator_count": compiled.morphology.ordered_actuator_ids.len(),
        "zero_target_settle_steps": 0,
        "controller_authority_began_at_semantic_step": 0,
        "controller_semantic_step_count": HORIZON_STEPS,
        "trace_step_count": trace.len(),
        "initial_pose_snapshot": initial_snapshot.value,
        "initial_declared_diagnostic_events": initial_events,
        "initial_contact_count": initial_contact_count,
        "controller_error_count": controller_error_count,
        "safe_no_actuation_count": safe_no_actuation_count,
        "composition_error_count": composition_error_count,
        "nonfinite_observation_count": nonfinite_observation_count,
        "actuator_application_mismatch_count": actuator_application_mismatch_count,
        "motor_model_or_field_readback_mismatch_count": motor_field_readback_mismatch_count,
        "small_step_impulse_limit_violation_count": small_step_impulse_limit_violation_count,
        "global_scale_mismatch_count": global_scale_mismatch_count,
        "native_position_target_application_count": native_position_target_application_count,
        "base_command_count": base_command_count,
        "bounded_residual_command_count": bounded_residual_command_count,
        "canonical_command_count": canonical_command_count,
        "host_command_count": host_command_count,
        "motor_observation_count": motor_observation_count,
        "shadow_nonzero_bounded_residual_count": shadow_nonzero_bounded_residual_count,
        "applied_nonzero_stability_residual_count": applied_nonzero_stability_residual_count,
        "selected_control_mapping_mismatch_count": selected_control_mapping_mismatch_count,
        "first_failure_event": first_failure_event(&trace),
        "ordered_trace": trace,
        "physical_acceptance_authority": false,
    }))
}

fn panic_message(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_owned()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "non_string_panic_payload".to_owned()
    }
}

fn incomplete_arm(arm_id: &str, error: String) -> Value {
    json!({
        "schema_version": "sporespore_rapier_c6_bw19v_velocity_only_eh1_arm_report_v1",
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
            "first_event_step_difference_b_minus_a": Value::Null,
            "descriptive_not_a_selector": true,
            "physical_acceptance_authority": false,
        });
    }
    let a = arms[0]["first_failure_event"]["semantic_step"].as_u64();
    let b = arms[1]["first_failure_event"]["semantic_step"].as_u64();
    let (classification, statement) = match (a, b) {
        (None, None) => (
            "neither_arm_event",
            "The v4 pair completed the early horizon without a declared event; this is not walking acceptance.",
        ),
        (Some(_), None) => (
            "control_only_event",
            "The exact BW19V treatment delayed or avoided an event in this paired development screen.",
        ),
        (None, Some(_)) => (
            "treatment_only_event",
            "The applied BW19V residual is a candidate contributor to the early event and requires diagnosis.",
        ),
        (Some(_), Some(_)) => (
            "both_arms_event",
            "Both exact v4 arms produced an early body-level event; the retained traces bound diagnosis to shared and arm-specific mechanisms.",
        ),
    };
    json!({
        "classification": classification,
        "statement": statement,
        "first_event_step_difference_b_minus_a": match (a, b) {
            (Some(a_step), Some(b_step)) => Some(b_step as i64 - a_step as i64),
            _ => None,
        },
        "descriptive_not_a_selector": true,
        "no_arm_or_policy_selected": true,
        "walking_acceptance": false,
        "physical_acceptance_authority": false,
    })
}

fn claim_boundary() -> Value {
    json!({
        "complete_mechanism_development_trace_only": true,
        "rapier_v4_selected_policy_physical_authority": false,
        "rapier_locomotion_acceptance": false,
        "walking_acceptance": false,
        "bw19v_improvement": false,
        "cross_engine_selected_policy_equivalence": false,
        "arbitrary_quadruped_coverage": false,
        "continuous_full_volume_coverage": false,
        "friction_or_material_robustness": false,
        "rough_terrain_robustness": false,
        "external_push_recovery": false,
        "sensor_noise_or_latency_robustness": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
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
        "live_integration_raw_sha256": LIVE_INTEGRATION_RAW_SHA256,
        "active_configuration_v2_raw_sha256": ACTIVE_CONFIGURATION_V2_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "ed1_closure_raw_sha256": ED1_CLOSURE_RAW_SHA256,
        "asd1_diagnostic_raw_sha256": ASD1_DIAGNOSTIC_RAW_SHA256,
        "preflight": preflight,
        "engine": "rapier3d",
        "engine_version": rapier3d::VERSION,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "selected_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
        "runtime_profile_sha256": BW19V_S169_RUNTIME_PROFILE_SHA256,
        "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "ordered_actuator_ids": compiled.morphology.ordered_actuator_ids,
        "host_configuration": {
            "motor_model": "ForceBased",
            "motor_mode": "velocity_only",
            "native_position_stiffness_nm_per_rad":
                VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD,
            "damping_nm_s_per_rad": VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
            "outer_timestep_s": RAPIER_DT_S,
            "solver_iterations": crate::RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": crate::RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations":
                crate::RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "canonical_to_host_velocity_sign": 1.0,
        },
        "study_class":
            "outcome_exposed_paired_early_horizon_mechanism_development_screen",
        "report_ok_means_complete_diagnostic_not_physical_success": true,
        "physical_event_pattern_is_not_an_integrity_predicate": true,
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
        "bounded_residual_command_count_total": arms.iter().map(|arm| {
            arm["bounded_residual_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "canonical_command_count_total": arms.iter().map(|arm| {
            arm["canonical_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "host_command_count_total": arms.iter().map(|arm| {
            arm["host_command_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "motor_observation_count_total": arms.iter().map(|arm| {
            arm["motor_observation_count"].as_u64().unwrap_or(0)
        }).sum::<u64>(),
        "arms": arms,
        "pair_interpretation": pair,
        "claim_boundary": claim_boundary(),
        "integrity_gate_failures": [],
    }))
}

fn u64_at(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer).and_then(Value::as_u64)
}

fn f64_at(value: &Value, pointer: &str) -> Option<f64> {
    value.pointer(pointer).and_then(Value::as_f64)
}

fn digest_shape(value: &Value) -> bool {
    value
        .as_str()
        .is_some_and(|digest| digest.len() == 71 && digest.starts_with("sha256:"))
}

fn array_ids_exact(value: &Value, expected: &[String]) -> bool {
    value.as_array().is_some_and(|entries| {
        entries.len() == expected.len()
            && entries
                .iter()
                .zip(expected)
                .all(|(entry, id)| entry["actuator_id"].as_str() == Some(id.as_str()))
    })
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

fn snapshot_json_complete(value: &Value) -> bool {
    let pose = &value["torso_pose_world"];
    let twist = &value["torso_twist_world"];
    let orientation = &pose["orientation_xyzw"];
    let quaternion_complete = finite_object_fields(orientation, &["x", "y", "z", "w"]) && {
        let norm_squared = ["x", "y", "z", "w"]
            .iter()
            .map(|field| orientation[*field].as_f64().unwrap_or(f64::NAN))
            .map(|component| component * component)
            .sum::<f64>();
        (norm_squared - 1.0).abs() <= 1.0e-9
    };
    let contacts = &value["ordered_declared_contacts"];
    finite_object_fields(&pose["position_m"], &["x", "y", "z"])
        && quaternion_complete
        && finite_object_fields(&twist["linear_velocity_m_s"], &["x", "y", "z"])
        && finite_object_fields(&twist["angular_velocity_rad_s"], &["x", "y", "z"])
        && value["torso_tilt_rad"].as_f64().is_some_and(f64::is_finite)
        && value["torso_height_m"].as_f64().is_some_and(f64::is_finite)
        && value["torso_ground_contact"].as_bool().is_some()
        && contacts.as_object().is_some_and(|object| {
            object.len() == 4
                && [
                    "front_left_foot",
                    "front_right_foot",
                    "rear_left_foot",
                    "rear_right_foot",
                ]
                .iter()
                .all(|id| object.get(*id).and_then(Value::as_bool).is_some())
        })
        && value["maximum_anchor_error_m"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["maximum_hinge_axis_error_rad"]
            .as_f64()
            .is_some_and(f64::is_finite)
}

fn base_command_complete(value: &Value) -> bool {
    [
        "requested_target_position_rad",
        "clamped_target_position_rad",
        "target_velocity_rad_s",
        "maximum_target_speed_rad_s",
        "portable_residual_contribution_rad_s",
        "portable_safety_contribution_rad_s",
    ]
    .iter()
    .all(|field| value[*field].as_f64().is_some_and(f64::is_finite))
        && value["valid_through_step"].as_u64().is_some()
}

fn bounded_residual_complete(value: &Value) -> bool {
    value["applied_position_delta_rad"].as_f64() == Some(0.0)
        && value["applied_velocity_delta_rad_s"]
            .as_f64()
            .is_some_and(f64::is_finite)
        && value["fallback_zeroed"].as_bool().is_some()
}

fn canonical_command_complete(value: &Value) -> bool {
    [
        "requested_target_position_rad",
        "clamped_target_position_rad",
        "source_legacy_host_target_velocity_rad_s",
        "portable_canonical_target_velocity_rad_s",
        "stability_canonical_velocity_delta_rad_s",
        "unbounded_canonical_target_velocity_rad_s",
        "combined_canonical_target_velocity_rad_s",
        "maximum_target_speed_rad_s",
    ]
    .iter()
    .all(|field| value[*field].as_f64().is_some_and(f64::is_finite))
        && value["valid_through_step"].as_u64().is_some()
}

fn host_command_complete(value: &Value) -> bool {
    [
        "requested_target_position_rad",
        "clamped_target_position_rad",
        "canonical_target_velocity_rad_s",
        "host_target_velocity_rad_s",
        "maximum_host_target_speed_rad_s",
    ]
    .iter()
    .all(|field| value[*field].as_f64().is_some_and(f64::is_finite))
        && value["native_target_position_rad"].is_null()
        && value["host_clamped"].as_bool() == Some(false)
        && value["valid_through_step"].as_u64().is_some()
}

fn motor_observation_complete(value: &Value) -> bool {
    let observed_target = value["target_velocity_rad_s"].as_f64();
    let expected_target = value["expected_target_velocity_rad_s"].as_f64();
    let maximum_force = value["maximum_force_nm"].as_f64();
    let impulse = value["motor_impulse_nms"].as_f64();
    let limit = value["small_step_impulse_limit_nms"].as_f64();
    value["motor_model"] == "ForceBased"
        && value["target_position_rad"].as_f64() == Some(0.0)
        && observed_target
            .zip(expected_target)
            .is_some_and(|(observed, expected)| {
                observed.is_finite()
                    && expected.is_finite()
                    && (observed - expected).abs() <= 1.0e-6
            })
        && value["stiffness_nm_per_rad"].as_f64()
            == Some(VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD as f64)
        && value["damping_nm_s_per_rad"].as_f64()
            == Some(VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD as f64)
        && maximum_force.is_some_and(|number| number.is_finite() && number > 0.0)
        && impulse.is_some_and(f64::is_finite)
        && limit.is_some_and(|number| number.is_finite() && number > 0.0)
        && impulse
            .zip(limit)
            .is_some_and(|(observed, maximum)| observed.abs() <= maximum + 1.0e-6)
        && maximum_force
            .zip(limit)
            .is_some_and(|(force, observed_limit)| {
                let expected_limit =
                    force * RAPIER_DT_S as f64 / crate::RAPIER_ACTIVE_SOLVER_ITERATIONS as f64;
                (observed_limit - expected_limit).abs() <= 1.0e-6
            })
        && value["fields_match"] == true
}

fn integrity_failures(report: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    if report["schema_version"] != REPORT_SCHEMA_VERSION
        || report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["preregistration_raw_sha256"] != PREREGISTRATION_RAW_SHA256
        || report["live_integration_raw_sha256"] != LIVE_INTEGRATION_RAW_SHA256
        || report["active_configuration_v2_raw_sha256"] != ACTIVE_CONFIGURATION_V2_RAW_SHA256
        || report["vh1_closure_raw_sha256"] != VH1_CLOSURE_RAW_SHA256
        || report["ed1_closure_raw_sha256"] != ED1_CLOSURE_RAW_SHA256
        || report["asd1_diagnostic_raw_sha256"] != ASD1_DIAGNOSTIC_RAW_SHA256
        || report["candidate_id"] != BW19V_CANDIDATE_ID
        || report["candidate_composition_digest"] != BW19V_CANDIDATE_COMPOSITION_DIGEST
        || report["selected_policy_id"] != BW19V_CONTROLLER_POLICY_ID
        || report["selected_policy_digest"] != BW19V_CONTROLLER_POLICY_DIGEST
        || report["runtime_profile_sha256"] != BW19V_S169_RUNTIME_PROFILE_SHA256
        || report["global_requested_correction_scale"].as_f64()
            != Some(BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE)
        || report["source_commit"].as_str().is_none_or(|commit| {
            commit.len() != 40 || !commit.bytes().all(|byte| byte.is_ascii_hexdigit())
        })
    {
        failures.push("C6_RAP_V4_EH1_IDENTITY_MISMATCH".to_owned());
    }
    if report["preflight"]["ok"] != true
        || u64_at(report, "/preflight/world_build_count") != Some(0)
        || u64_at(report, "/preflight/scene_insertion_count") != Some(0)
        || u64_at(report, "/preflight/physics_state_mutation_count") != Some(0)
        || report["preflight"]["physical_acceptance_authority"] != false
    {
        failures.push("C6_RAP_V4_EH1_PREFLIGHT_INVALID".to_owned());
    }
    if report["engine"] != "rapier3d"
        || report["engine_version"] != rapier3d::VERSION
        || report["adapter_id"] != ADAPTER_ID
        || report["host_configuration"]["motor_model"] != "ForceBased"
        || report["host_configuration"]["motor_mode"] != "velocity_only"
        || f64_at(
            report,
            "/host_configuration/native_position_stiffness_nm_per_rad",
        ) != Some(VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD as f64)
        || f64_at(report, "/host_configuration/damping_nm_s_per_rad")
            != Some(VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD as f64)
        || u64_at(report, "/host_configuration/solver_iterations")
            != Some(crate::RAPIER_ACTIVE_SOLVER_ITERATIONS as u64)
        || u64_at(report, "/host_configuration/internal_pgs_iterations")
            != Some(crate::RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS as u64)
        || u64_at(
            report,
            "/host_configuration/internal_stabilization_iterations",
        ) != Some(crate::RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS as u64)
        || f64_at(
            report,
            "/host_configuration/canonical_to_host_velocity_sign",
        ) != Some(1.0)
    {
        failures.push("C6_RAP_V4_EH1_HOST_IDENTITY_MISMATCH".to_owned());
    }
    if report["study_class"] != "outcome_exposed_paired_early_horizon_mechanism_development_screen"
        || report["report_ok_means_complete_diagnostic_not_physical_success"] != true
        || report["physical_event_pattern_is_not_an_integrity_predicate"] != true
        || u64_at(report, "/world_attempt_count") != Some(2)
        || u64_at(report, "/world_build_count") != Some(2)
        || u64_at(report, "/world_reset_count") != Some(0)
        || u64_at(report, "/trace_step_count_total") != Some(TOTAL_TRACE_STEPS)
        || u64_at(report, "/base_command_count_total") != Some(COMMANDS_PER_ARM * 2)
        || u64_at(report, "/bounded_residual_command_count_total") != Some(COMMANDS_PER_ARM * 2)
        || u64_at(report, "/canonical_command_count_total") != Some(COMMANDS_PER_ARM * 2)
        || u64_at(report, "/host_command_count_total") != Some(COMMANDS_PER_ARM * 2)
        || u64_at(report, "/motor_observation_count_total") != Some(COMMANDS_PER_ARM * 2)
    {
        failures.push("C6_RAP_V4_EH1_AGGREGATE_COUNT_MISMATCH".to_owned());
    }
    let claims = &report["claim_boundary"];
    if claims["complete_mechanism_development_trace_only"] != true
        || claims.as_object().is_none_or(|fields| {
            fields.iter().any(|(name, value)| {
                name != "complete_mechanism_development_trace_only" && value == true
            })
        })
    {
        failures.push("C6_RAP_V4_EH1_CLAIM_INFLATION".to_owned());
    }

    let Some(expected) = report["ordered_actuator_ids"].as_array().map(|ids| {
        ids.iter()
            .filter_map(Value::as_str)
            .map(str::to_owned)
            .collect::<Vec<_>>()
    }) else {
        failures.push("C6_RAP_V4_EH1_ACTUATOR_IDS_MISSING".to_owned());
        return failures;
    };
    if expected.len() != ACTUATOR_COUNT {
        failures.push("C6_RAP_V4_EH1_ACTUATOR_IDENTITY_INVALID".to_owned());
    }
    let Some(arms) = report["arms"].as_array() else {
        failures.push("C6_RAP_V4_EH1_ARMS_MISSING".to_owned());
        return failures;
    };
    if arms.len() != 2
        || arms[0]["arm_id"] != ARM_A
        || arms[1]["arm_id"] != ARM_B
        || arms[0]["arm_order_index"] != 0
        || arms[1]["arm_order_index"] != 1
    {
        failures.push("C6_RAP_V4_EH1_ARM_ORDER_INVALID".to_owned());
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
            || u64_at(arm, "/zero_target_settle_steps") != Some(0)
            || u64_at(arm, "/controller_authority_began_at_semantic_step") != Some(0)
            || u64_at(arm, "/controller_semantic_step_count") != Some(HORIZON_STEPS)
            || u64_at(arm, "/trace_step_count") != Some(HORIZON_STEPS)
            || !snapshot_json_complete(&arm["initial_pose_snapshot"])
            || arm["initial_declared_diagnostic_events"]
                .as_array()
                .is_none_or(|events| !events.is_empty())
            || arm["initial_contact_count"].as_u64().is_none()
        {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_HORIZON_INVALID"));
        }
        for pointer in [
            "/controller_error_count",
            "/safe_no_actuation_count",
            "/composition_error_count",
            "/nonfinite_observation_count",
            "/actuator_application_mismatch_count",
            "/motor_model_or_field_readback_mismatch_count",
            "/small_step_impulse_limit_violation_count",
            "/global_scale_mismatch_count",
            "/native_position_target_application_count",
            "/selected_control_mapping_mismatch_count",
        ] {
            if u64_at(arm, pointer) != Some(0) {
                failures.push(format!("C6_RAP_V4_EH1_{arm_id}_INTEGRITY_COUNT:{pointer}"));
                break;
            }
        }
        for pointer in [
            "/base_command_count",
            "/bounded_residual_command_count",
            "/canonical_command_count",
            "/host_command_count",
            "/motor_observation_count",
        ] {
            if u64_at(arm, pointer) != Some(COMMANDS_PER_ARM) {
                failures.push(format!("C6_RAP_V4_EH1_{arm_id}_COMMAND_COUNT:{pointer}"));
                break;
            }
        }
        if u64_at(arm, "/shadow_nonzero_bounded_residual_count").is_none_or(|count| count == 0) {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_SHADOW_RESIDUAL_MISSING"));
        }
        if index == 0 {
            if arm["bw19v_stability_contribution_applied_to_host"] != false
                || u64_at(arm, "/applied_nonzero_stability_residual_count") != Some(0)
            {
                failures.push("C6_RAP_V4_EH1_ARM_A_INTERVENTION_INVALID".to_owned());
            }
        } else if arm["bw19v_stability_contribution_applied_to_host"] != true
            || u64_at(arm, "/applied_nonzero_stability_residual_count")
                .is_none_or(|count| count == 0)
        {
            failures.push("C6_RAP_V4_EH1_ARM_B_INTERVENTION_INVALID".to_owned());
        }

        let Some(trace) = arm["ordered_trace"].as_array() else {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_TRACE_MISSING"));
            continue;
        };
        if trace.len() != HORIZON_STEPS as usize {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_TRACE_COUNT"));
            continue;
        }
        let mut derived_shadow_nonzero = 0_u64;
        let mut derived_applied_nonzero = 0_u64;
        for (semantic_step, entry) in trace.iter().enumerate() {
            let base = &entry["ordered_portable_base_commands"];
            let bounded = &entry["shadow_v4_composition"]["ordered_bounded_canonical_residuals"];
            let canonical = &entry["selected_canonical_actuation_frame"];
            let mapping = &entry["selected_rapier_host_mapping"];
            let host = &entry["ordered_load_bearing_host_commands"];
            let motors = &entry["ordered_post_step_joint_motor_readbacks_and_impulses"];
            if entry["arm_id"] != arm_id
                || entry["semantic_step"].as_u64() != Some(semantic_step as u64)
                || entry["phase_progression_mode"] != "clocked"
                || entry["command_provenance_recorded_before_application"] != true
                || !snapshot_json_complete(&entry["pre_step_snapshot"])
                || !snapshot_json_complete(&entry["post_step_snapshot"])
                || entry["ordered_limb_controller_memory_before"]
                    .as_array()
                    .is_none_or(|memory| memory.len() != 4)
                || !digest_shape(&entry["portable_controller_actuation_receipt_sha256"])
                || !array_ids_exact(base, &expected)
                || !array_ids_exact(bounded, &expected)
                || !array_ids_exact(&canonical["ordered_commands"], &expected)
                || !array_ids_exact(&mapping["ordered_commands"], &expected)
                || !array_ids_exact(host, &expected)
                || !array_ids_exact(motors, &expected)
                || entry["shadow_v4_composition"]["planning_availability"]
                    .as_str()
                    .is_none_or(|availability| {
                        ![
                            "available",
                            "observation_unavailable",
                            "upstream_infeasible",
                        ]
                        .contains(&availability)
                    })
                || entry["shadow_v4_composition"]["observation_input_available"]
                    .as_bool()
                    .is_none()
                || entry["shadow_v4_composition"]["global_requested_correction_scale"].as_f64()
                    != Some(BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE)
                || entry["shadow_v4_composition"]["retained_mixed_space_projection_applied"]
                    != false
                || entry["residual_applied_to_host"].as_bool() != Some(index == 1)
            {
                failures.push(format!(
                    "C6_RAP_V4_EH1_{arm_id}_TRACE_INVALID:{semantic_step}"
                ));
                break;
            }
            let planning = &entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt"];
            let planning_sha =
                &entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt_sha256"];
            if digest_json(planning).ok().as_deref() != planning_sha.as_str()
                || digest_json(canonical).ok().as_deref()
                    != entry["canonical_actuation_frame_sha256"].as_str()
                || digest_json(mapping).ok().as_deref()
                    != entry["rapier_host_mapping_sha256"].as_str()
                || mapping["ordered_commands"] != *host
                || canonical["source_policy_id"] != BW19V_CONTROLLER_POLICY_ID
                || canonical["semantic_step"].as_u64() != Some(semantic_step as u64)
                || mapping["semantic_step"].as_u64() != Some(semantic_step as u64)
                || mapping["host_profile_id"] != "rapier_force_based_velocity_only_v1"
                || mapping["adapter_id"] != ADAPTER_ID
                || mapping["engine_id"] != "rapier3d"
                || mapping["native_motor_model_id"] != "force_based_velocity_only"
                || mapping["independent_native_position_feedback_applied"] != false
                || mapping["native_position_stiffness"].as_f64() != Some(0.0)
                || planning["global_requested_correction_scale"].as_f64()
                    != Some(BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE)
                || planning["load_bearing_command_source"]
                    != "rapier_velocity_only_host_mapping.ordered_commands"
            {
                failures.push(format!(
                    "C6_RAP_V4_EH1_{arm_id}_RECEIPT_INVALID:{semantic_step}"
                ));
                break;
            }
            let base_entries = base.as_array().expect("checked base array");
            let bounded_entries = bounded.as_array().expect("checked bounded array");
            let canonical_entries = canonical["ordered_commands"]
                .as_array()
                .expect("checked canonical array");
            let host_entries = host.as_array().expect("checked host array");
            let motor_entries = motors.as_array().expect("checked motor array");
            if base_entries
                .iter()
                .any(|value| !base_command_complete(value))
                || bounded_entries
                    .iter()
                    .any(|value| !bounded_residual_complete(value))
                || canonical_entries
                    .iter()
                    .any(|value| !canonical_command_complete(value))
                || host_entries
                    .iter()
                    .any(|value| !host_command_complete(value))
                || motor_entries
                    .iter()
                    .any(|value| !motor_observation_complete(value))
            {
                failures.push(format!(
                    "C6_RAP_V4_EH1_{arm_id}_TRACE_LAYER_INCOMPLETE:{semantic_step}"
                ));
                break;
            }
            for (((base_command, bounded_command), canonical_command), (host_command, motor)) in
                base_entries
                    .iter()
                    .zip(bounded_entries)
                    .zip(canonical_entries)
                    .zip(host_entries.iter().zip(motor_entries))
            {
                let bounded_delta = bounded_command["applied_velocity_delta_rad_s"]
                    .as_f64()
                    .unwrap_or(f64::NAN);
                let selected_delta = canonical_command["stability_canonical_velocity_delta_rad_s"]
                    .as_f64()
                    .unwrap_or(f64::NAN);
                let portable_canonical_base =
                    canonical_command["portable_canonical_target_velocity_rad_s"]
                        .as_f64()
                        .unwrap_or(f64::NAN);
                let final_canonical_velocity =
                    canonical_command["combined_canonical_target_velocity_rad_s"]
                        .as_f64()
                        .unwrap_or(f64::NAN);
                derived_shadow_nonzero += u64::from(bounded_delta != 0.0);
                derived_applied_nonzero +=
                    u64::from(final_canonical_velocity != portable_canonical_base);
                let expected_delta = if index == 0 { 0.0 } else { bounded_delta };
                if selected_delta != expected_delta
                    || host_command["canonical_target_velocity_rad_s"]
                        != canonical_command["combined_canonical_target_velocity_rad_s"]
                    || host_command["host_target_velocity_rad_s"]
                        != canonical_command["combined_canonical_target_velocity_rad_s"]
                    || motor["expected_target_velocity_rad_s"]
                        != host_command["host_target_velocity_rad_s"]
                    || base_command["actuator_id"] != canonical_command["actuator_id"]
                {
                    failures.push(format!(
                        "C6_RAP_V4_EH1_{arm_id}_APPLICATION_RECONSTRUCTION:{semantic_step}"
                    ));
                    break;
                }
            }
            let Some(derived_events) = events_from_snapshot(&entry["post_step_snapshot"]) else {
                failures.push(format!(
                    "C6_RAP_V4_EH1_{arm_id}_POST_SNAPSHOT_INVALID:{semantic_step}"
                ));
                break;
            };
            if entry["declared_diagnostic_events"] != json!(derived_events) {
                failures.push(format!(
                    "C6_RAP_V4_EH1_{arm_id}_EVENT_RECONSTRUCTION:{semantic_step}"
                ));
                break;
            }
        }
        if u64_at(arm, "/shadow_nonzero_bounded_residual_count") != Some(derived_shadow_nonzero)
            || u64_at(arm, "/applied_nonzero_stability_residual_count")
                != Some(derived_applied_nonzero)
        {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_RESIDUAL_COUNT_RECOMPUTE"));
        }
        if arm["first_failure_event"] != first_failure_event(trace) {
            failures.push(format!("C6_RAP_V4_EH1_{arm_id}_FIRST_EVENT_MISMATCH"));
        }
    }
    if report["pair_interpretation"] != pair_interpretation(arms) {
        failures.push("C6_RAP_V4_EH1_PAIR_INTERPRETATION_MISMATCH".to_owned());
    }
    failures
}

fn synthetic_snapshot_value() -> Value {
    json!({
        "torso_pose_world": {
            "position_m": { "x": 0.0, "y": 0.55, "z": 0.0 },
            "orientation_xyzw": { "x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0 },
        },
        "torso_twist_world": {
            "linear_velocity_m_s": { "x": 0.0, "y": 0.0, "z": 0.0 },
            "angular_velocity_rad_s": { "x": 0.0, "y": 0.0, "z": 0.0 },
        },
        "torso_tilt_rad": 0.0,
        "torso_height_m": 0.55,
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
) -> Result<Value, String> {
    let base_velocity = -0.25;
    let bounded_delta = 0.01;
    let selected_delta = if apply_residual { bounded_delta } else { 0.0 };
    let base = actuator_ids
        .iter()
        .map(|id| {
            json!({
                "actuator_id": id,
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "target_velocity_rad_s": base_velocity,
                "maximum_target_speed_rad_s": 3.5,
                "position_saturated": false,
                "velocity_saturated": false,
                "slew_limited": false,
                "portable_residual_contribution_rad_s": 0.0,
                "portable_safety_contribution_rad_s": 0.0,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let bounded = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            json!({
                "actuator_id": id,
                "applied_position_delta_rad": 0.0,
                "applied_velocity_delta_rad_s": if index == 0 { bounded_delta } else { 0.0 },
                "fallback_zeroed": false,
            })
        })
        .collect::<Vec<_>>();
    let canonical_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            let delta = if index == 0 { selected_delta } else { 0.0 };
            json!({
                "actuator_id": id,
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "position_target_role": "provenance_and_bounds_only",
                "source_legacy_host_target_velocity_rad_s": -base_velocity,
                "source_legacy_residual_contribution_rad_s": 0.0,
                "source_legacy_safety_contribution_rad_s": 0.0,
                "portable_canonical_target_velocity_rad_s": base_velocity,
                "portable_canonical_residual_contribution_rad_s": 0.0,
                "portable_canonical_safety_contribution_rad_s": 0.0,
                "stability_canonical_velocity_delta_rad_s": delta,
                "unbounded_canonical_target_velocity_rad_s": base_velocity + delta,
                "combined_canonical_target_velocity_rad_s": base_velocity + delta,
                "maximum_target_speed_rad_s": 3.5,
                "canonical_speed_saturated": false,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let canonical = json!({
        "schema_version": "sporespore_canonical_velocity_actuation_frame_v1",
        "profile_id": "complete_closed_loop_canonical_velocity_v1",
        "source_velocity_convention_id": "legacy_godot_host_velocity_v1",
        "source_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "source_actuation_receipt_sha256": format!("sha256:{semantic_step:064x}"),
        "semantic_step": semantic_step,
        "position_target_role": "provenance_and_bounds_only",
        "load_bearing_actuation": "complete_closed_loop_canonical_target_velocity",
        "canonical_to_host_mapping_owned_by_adapter": true,
        "ordered_commands": canonical_commands,
        "safe_no_actuation": false,
        "failure_codes": [],
        "world_build_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
    });
    let host_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            let delta = if index == 0 { selected_delta } else { 0.0 };
            json!({
                "actuator_id": id,
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "position_target_role": "provenance_and_bounds_only",
                "native_target_position_rad": Value::Null,
                "canonical_target_velocity_rad_s": base_velocity + delta,
                "host_target_velocity_rad_s": base_velocity + delta,
                "maximum_host_target_speed_rad_s": 3.5,
                "host_clamped": false,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let mapping = json!({
        "schema_version": "sporespore_velocity_only_host_mapping_receipt_v1",
        "canonical_profile_id": "complete_closed_loop_canonical_velocity_v1",
        "host_profile_id": "rapier_force_based_velocity_only_v1",
        "adapter_id": ADAPTER_ID,
        "engine_id": "rapier3d",
        "semantic_step": semantic_step,
        "canonical_to_host_velocity_sign": 1.0,
        "native_motor_model_id": "force_based_velocity_only",
        "independent_native_position_feedback_applied": false,
        "native_position_stiffness": 0.0,
        "host_response_characterized_for_this_profile": false,
        "ordered_commands": host_commands,
        "safe_no_actuation_preserved": true,
        "world_build_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
    });
    let planning = json!({
        "schema_version": "sporespore_rapier_bw19v_velocity_only_composition_receipt_v1",
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "controller_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
        "planning_and_bounding_receipt": {
            "semantic_step": semantic_step,
            "stability_influence_receipt": {
                "ordered_applied_corrections": bounded,
            },
        },
        "canonical_actuation_frame": canonical,
        "rapier_velocity_only_host_mapping": mapping,
        "retained_historical_mixed_space_projection": {
            "applied_to_host": false,
            "difference_count_from_v4_host_mapping": 1,
        },
        "load_bearing_command_source": "rapier_velocity_only_host_mapping.ordered_commands",
        "native_position_feedback_applied": false,
        "world_build_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
    });
    let motors = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, id)| {
            let delta = if index == 0 { selected_delta } else { 0.0 };
            json!({
                "actuator_id": id,
                "motor_model": "ForceBased",
                "target_position_rad": 0.0,
                "target_velocity_rad_s": base_velocity + delta,
                "expected_target_velocity_rad_s": base_velocity + delta,
                "stiffness_nm_per_rad": 0.0,
                "damping_nm_s_per_rad": 10.0,
                "maximum_force_nm": 96.0,
                "motor_impulse_nms": 0.0,
                "small_step_impulse_limit_nms": 0.05,
                "fields_match": true,
            })
        })
        .collect::<Vec<_>>();
    let snapshot = synthetic_snapshot_value();
    let canonical_sha = digest_json(&canonical).map_err(|error| error.to_string())?;
    let mapping_sha = digest_json(&mapping).map_err(|error| error.to_string())?;
    let planning_sha = digest_json(&planning).map_err(|error| error.to_string())?;
    Ok(json!({
        "schema_version": "sporespore_rapier_c6_bw19v_velocity_only_eh1_trace_step_v1",
        "arm_id": arm_id,
        "semantic_step": semantic_step,
        "phase_progression_mode": "clocked",
        "command_provenance_recorded_before_application": true,
        "pre_step_snapshot": snapshot.clone(),
        "ordered_limb_controller_memory_before": [
            { "limb_id": "front_left", "gait_step": semantic_step },
            { "limb_id": "front_right", "gait_step": semantic_step },
            { "limb_id": "rear_left", "gait_step": semantic_step },
            { "limb_id": "rear_right", "gait_step": semantic_step },
        ],
        "portable_controller_actuation_receipt_sha256": format!("sha256:{semantic_step:064x}"),
        "ordered_portable_base_commands": base,
        "shadow_v4_composition": {
            "planning_availability": "available",
            "observation_input_available": true,
            "planning_outcome_code": "synthetic_available",
            "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "v4_planning_and_bounding_receipt_sha256": planning_sha,
            "v4_planning_and_bounding_receipt": planning,
            "ordered_bounded_canonical_residuals": bounded,
            "retained_mixed_space_projection_applied": false,
            "retained_mixed_space_projection_difference_count": 1,
        },
        "residual_applied_to_host": apply_residual,
        "canonical_actuation_frame_sha256": canonical_sha,
        "selected_canonical_actuation_frame": canonical,
        "rapier_host_mapping_sha256": mapping_sha,
        "selected_rapier_host_mapping": mapping,
        "ordered_load_bearing_host_commands": host_commands,
        "ordered_post_step_joint_motor_readbacks_and_impulses": motors,
        "post_step_snapshot": snapshot,
        "declared_diagnostic_events": [],
    }))
}

fn synthetic_arm(
    arm_id: &str,
    actuator_ids: &[String],
    apply_residual: bool,
) -> Result<Value, String> {
    let trace = (0..HORIZON_STEPS)
        .map(|step| synthetic_trace_step(arm_id, step, actuator_ids, apply_residual))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(json!({
        "schema_version": "sporespore_rapier_c6_bw19v_velocity_only_eh1_arm_report_v1",
        "arm_id": arm_id,
        "arm_order_index": if arm_id == ARM_A { 0 } else { 1 },
        "completed_declared_horizon": true,
        "fatal_error": Value::Null,
        "residual_application_mode": if apply_residual {
            "exact_canonical_bw15f_b_plus_bounded_bw19v_scale_0_5"
        } else {
            "exact_canonical_bw15f_b_plus_zero_residual_shadow_bw19v"
        },
        "bw19v_plan_and_residual_computed_in_shadow": true,
        "bw19v_stability_contribution_applied_to_host": apply_residual,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": 9,
        "joint_count": 8,
        "actuator_count": 8,
        "zero_target_settle_steps": 0,
        "controller_authority_began_at_semantic_step": 0,
        "controller_semantic_step_count": HORIZON_STEPS,
        "trace_step_count": HORIZON_STEPS,
        "initial_pose_snapshot": synthetic_snapshot_value(),
        "initial_declared_diagnostic_events": [],
        "initial_contact_count": 4,
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "composition_error_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
        "motor_model_or_field_readback_mismatch_count": 0,
        "small_step_impulse_limit_violation_count": 0,
        "global_scale_mismatch_count": 0,
        "native_position_target_application_count": 0,
        "base_command_count": COMMANDS_PER_ARM,
        "bounded_residual_command_count": COMMANDS_PER_ARM,
        "canonical_command_count": COMMANDS_PER_ARM,
        "host_command_count": COMMANDS_PER_ARM,
        "motor_observation_count": COMMANDS_PER_ARM,
        "shadow_nonzero_bounded_residual_count": HORIZON_STEPS,
        "applied_nonzero_stability_residual_count": if apply_residual {
            HORIZON_STEPS
        } else {
            0
        },
        "selected_control_mapping_mismatch_count": 0,
        "first_failure_event": Value::Null,
        "ordered_trace": trace,
        "physical_acceptance_authority": false,
    }))
}

fn perfect_synthetic_report() -> Result<Value, String> {
    let (compiled, _controller) = compile_declared_boundary()?;
    report_shell(
        "0000000000000000000000000000000000000000",
        json!({
            "ok": true,
            "world_build_count": 0,
            "scene_insertion_count": 0,
            "physics_state_mutation_count": 0,
            "physical_acceptance_authority": false,
        }),
        vec![
            synthetic_arm(ARM_A, &compiled.morphology.ordered_actuator_ids, false)?,
            synthetic_arm(ARM_B, &compiled.morphology.ordered_actuator_ids, true)?,
        ],
    )
}

fn set_synthetic_failure(report: &mut Value, arm_index: usize) {
    report["arms"][arm_index]["ordered_trace"][117]["post_step_snapshot"]["torso_ground_contact"] =
        json!(true);
    report["arms"][arm_index]["ordered_trace"][117]["declared_diagnostic_events"] =
        json!(["torso_ground_contact"]);
    let trace = report["arms"][arm_index]["ordered_trace"]
        .as_array()
        .expect("synthetic trace");
    report["arms"][arm_index]["first_failure_event"] = first_failure_event(trace);
    let arms = report["arms"].as_array().expect("synthetic arms");
    report["pair_interpretation"] = pair_interpretation(arms);
}

fn set_synthetic_saturated_residual(report: &mut Value) -> Result<(), String> {
    let entry = &mut report["arms"][1]["ordered_trace"][0];
    entry["ordered_portable_base_commands"][0]["target_velocity_rad_s"] = json!(-3.5);
    entry["selected_canonical_actuation_frame"]["ordered_commands"][0]["source_legacy_host_target_velocity_rad_s"] =
        json!(-3.5);
    entry["selected_canonical_actuation_frame"]["ordered_commands"][0]["portable_canonical_target_velocity_rad_s"] =
        json!(3.5);
    entry["selected_canonical_actuation_frame"]["ordered_commands"][0]["unbounded_canonical_target_velocity_rad_s"] =
        json!(3.51);
    entry["selected_canonical_actuation_frame"]["ordered_commands"][0]["combined_canonical_target_velocity_rad_s"] =
        json!(3.5);
    entry["selected_canonical_actuation_frame"]["ordered_commands"][0]["canonical_speed_saturated"] =
        json!(true);
    entry["selected_rapier_host_mapping"]["ordered_commands"][0]["canonical_target_velocity_rad_s"] =
        json!(3.5);
    entry["selected_rapier_host_mapping"]["ordered_commands"][0]["host_target_velocity_rad_s"] =
        json!(3.5);
    entry["ordered_load_bearing_host_commands"][0]["canonical_target_velocity_rad_s"] = json!(3.5);
    entry["ordered_load_bearing_host_commands"][0]["host_target_velocity_rad_s"] = json!(3.5);
    entry["ordered_post_step_joint_motor_readbacks_and_impulses"][0]["target_velocity_rad_s"] =
        json!(3.5);
    entry["ordered_post_step_joint_motor_readbacks_and_impulses"][0]["expected_target_velocity_rad_s"] =
        json!(3.5);

    let canonical = entry["selected_canonical_actuation_frame"].clone();
    let mapping = entry["selected_rapier_host_mapping"].clone();
    entry["canonical_actuation_frame_sha256"] =
        json!(digest_json(&canonical).map_err(|error| error.to_string())?);
    entry["rapier_host_mapping_sha256"] =
        json!(digest_json(&mapping).map_err(|error| error.to_string())?);
    entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt"]["canonical_actuation_frame"] =
        canonical;
    entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt"]["rapier_velocity_only_host_mapping"] =
        mapping;
    let planning = entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt"].clone();
    entry["shadow_v4_composition"]["v4_planning_and_bounding_receipt_sha256"] =
        json!(digest_json(&planning).map_err(|error| error.to_string())?);
    report["arms"][1]["applied_nonzero_stability_residual_count"] = json!(HORIZON_STEPS - 1);
    Ok(())
}

pub fn run_bw19v_velocity_only_early_horizon_eh1_preflight() -> Result<Value, String> {
    let declaration = preregistration()?;
    let perfect = perfect_synthetic_report()?;
    let perfect_passed = integrity_failures(&perfect).is_empty();

    let outcome_variants_passed = [(false, false), (true, false), (false, true), (true, true)]
        .into_iter()
        .all(|(a_event, b_event)| {
            let mut report = perfect.clone();
            if a_event {
                set_synthetic_failure(&mut report, 0);
            }
            if b_event {
                set_synthetic_failure(&mut report, 1);
            }
            integrity_failures(&report).is_empty()
        });

    let mut saturated_residual_variant = perfect.clone();
    set_synthetic_saturated_residual(&mut saturated_residual_variant)?;
    let saturated_residual_fidelity_variant_passed =
        integrity_failures(&saturated_residual_variant).is_empty();

    let mut missing_trace = perfect.clone();
    missing_trace["arms"][0]["ordered_trace"]
        .as_array_mut()
        .expect("synthetic trace")
        .pop();
    let missing_trace_step_canary_rejected = !integrity_failures(&missing_trace).is_empty();

    let mut reordered_step = perfect.clone();
    reordered_step["arms"][0]["ordered_trace"][1]["semantic_step"] = json!(7);
    let reordered_semantic_step_canary_rejected = !integrity_failures(&reordered_step).is_empty();

    let mut wrong_policy = perfect.clone();
    wrong_policy["selected_policy_id"] = json!("not_the_selected_policy");
    let wrong_selected_policy_identity_canary_rejected =
        !integrity_failures(&wrong_policy).is_empty();

    let mut wrong_scale = perfect.clone();
    wrong_scale["global_requested_correction_scale"] = json!(0.25);
    let wrong_bw19v_scale_canary_rejected = !integrity_failures(&wrong_scale).is_empty();

    let mut arm_a_nonzero = perfect.clone();
    arm_a_nonzero["arms"][0]["applied_nonzero_stability_residual_count"] = json!(1);
    let arm_a_nonzero_residual_canary_rejected = !integrity_failures(&arm_a_nonzero).is_empty();

    let mut arm_b_missing = perfect.clone();
    arm_b_missing["arms"][1]["applied_nonzero_stability_residual_count"] = json!(0);
    let arm_b_missing_nonzero_residual_canary_rejected =
        !integrity_failures(&arm_b_missing).is_empty();

    let mut stiffness = perfect.clone();
    stiffness["arms"][0]["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"]
        [0]["stiffness_nm_per_rad"] = json!(1.0);
    let nonzero_native_position_stiffness_canary_rejected =
        !integrity_failures(&stiffness).is_empty();

    let mut wrong_host_profile = perfect.clone();
    wrong_host_profile["arms"][0]["ordered_trace"][0]["selected_rapier_host_mapping"]["host_profile_id"] =
        json!("rapier_force_based_velocity_only_target_v1");
    let wrong_host_profile_canary_rejected = !integrity_failures(&wrong_host_profile).is_empty();

    let mut wrong_model = perfect.clone();
    wrong_model["arms"][0]["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"]
        [0]["motor_model"] = json!("AccelerationBased");
    let wrong_motor_model_canary_rejected = !integrity_failures(&wrong_model).is_empty();

    let mut target = perfect.clone();
    target["arms"][0]["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"]
        [0]["target_velocity_rad_s"] = json!(2.0);
    let motor_target_readback_mismatch_canary_rejected = !integrity_failures(&target).is_empty();

    let mut impulse = perfect.clone();
    impulse["arms"][0]["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"]
        [0]["motor_impulse_nms"] = json!(0.1);
    let small_step_impulse_limit_violation_canary_rejected =
        !integrity_failures(&impulse).is_empty();

    let mut actuator = perfect.clone();
    actuator["arms"][0]["ordered_trace"][0]["ordered_load_bearing_host_commands"]
        .as_array_mut()
        .expect("synthetic host commands")
        .swap(0, 1);
    let missing_or_reordered_actuator_canary_rejected = !integrity_failures(&actuator).is_empty();

    let mut claim = perfect.clone();
    claim["claim_boundary"]["walking_acceptance"] = json!(true);
    let claim_inflation_canary_rejected = !integrity_failures(&claim).is_empty();

    let mut world = perfect.clone();
    world["world_build_count"] = json!(3);
    let world_count_inflation_canary_rejected = !integrity_failures(&world).is_empty();

    let round_trip: Value =
        serde_json::from_str(&serde_json::to_string(&perfect).map_err(|error| error.to_string())?)
            .map_err(|error| error.to_string())?;
    let serialization_round_trip_passed = round_trip == perfect;
    let all_canaries_rejected = missing_trace_step_canary_rejected
        && reordered_semantic_step_canary_rejected
        && wrong_selected_policy_identity_canary_rejected
        && wrong_bw19v_scale_canary_rejected
        && arm_a_nonzero_residual_canary_rejected
        && arm_b_missing_nonzero_residual_canary_rejected
        && nonzero_native_position_stiffness_canary_rejected
        && wrong_host_profile_canary_rejected
        && wrong_motor_model_canary_rejected
        && motor_target_readback_mismatch_canary_rejected
        && small_step_impulse_limit_violation_canary_rejected
        && missing_or_reordered_actuator_canary_rejected
        && claim_inflation_canary_rejected
        && world_count_inflation_canary_rejected;
    let report = json!({
        "schema_version": PREFLIGHT_SCHEMA_VERSION,
        "ok": perfect_passed
            && outcome_variants_passed
            && saturated_residual_fidelity_variant_passed
            && all_canaries_rejected
            && serialization_round_trip_passed,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "preregistration_status": declaration["status"],
        "perfect_synthetic_two_arm_report_passed_complete_real_integrity_gate":
            perfect_passed,
        "synthetic_outcome_variants_all_integrity_valid": outcome_variants_passed,
        "saturated_residual_fidelity_variant_passed":
            saturated_residual_fidelity_variant_passed,
        "synthetic_arm_count": 2,
        "synthetic_trace_step_count": TOTAL_TRACE_STEPS,
        "synthetic_command_count_per_layer": COMMANDS_PER_ARM * 2,
        "missing_trace_step_canary_rejected": missing_trace_step_canary_rejected,
        "reordered_semantic_step_canary_rejected":
            reordered_semantic_step_canary_rejected,
        "wrong_selected_policy_identity_canary_rejected":
            wrong_selected_policy_identity_canary_rejected,
        "wrong_bw19v_scale_canary_rejected": wrong_bw19v_scale_canary_rejected,
        "arm_a_nonzero_residual_canary_rejected": arm_a_nonzero_residual_canary_rejected,
        "arm_b_missing_nonzero_residual_canary_rejected":
            arm_b_missing_nonzero_residual_canary_rejected,
        "nonzero_native_position_stiffness_canary_rejected":
            nonzero_native_position_stiffness_canary_rejected,
        "wrong_host_profile_canary_rejected": wrong_host_profile_canary_rejected,
        "wrong_motor_model_canary_rejected": wrong_motor_model_canary_rejected,
        "motor_target_readback_mismatch_canary_rejected":
            motor_target_readback_mismatch_canary_rejected,
        "small_step_impulse_limit_violation_canary_rejected":
            small_step_impulse_limit_violation_canary_rejected,
        "missing_or_reordered_actuator_canary_rejected":
            missing_or_reordered_actuator_canary_rejected,
        "claim_inflation_canary_rejected": claim_inflation_canary_rejected,
        "world_count_inflation_canary_rejected": world_count_inflation_canary_rejected,
        "all_declared_negative_controls_rejected": all_canaries_rejected,
        "serialization_round_trip_passed": serialization_round_trip_passed,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    });
    if report["ok"] != true {
        return Err(format!(
            "C6_RAP_V4_EH1_PREFLIGHT_GATE_INVALID:{}",
            serde_json::to_string(&report).map_err(|error| error.to_string())?
        ));
    }
    Ok(report)
}

pub fn run_bw19v_velocity_only_early_horizon_eh1(source_commit: &str) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("C6_RAP_V4_EH1_SOURCE_COMMIT_INVALID".to_owned());
    }
    let preflight = run_bw19v_velocity_only_early_horizon_eh1_preflight()?;
    let arms = [(ARM_A, false), (ARM_B, true)]
        .into_iter()
        .map(|(arm_id, apply_residual)| {
            match catch_unwind(AssertUnwindSafe(|| run_arm(arm_id, apply_residual))) {
                Ok(Ok(arm)) => arm,
                Ok(Err(error)) => incomplete_arm(arm_id, error),
                Err(payload) => incomplete_arm(
                    arm_id,
                    format!("C6_RAP_V4_EH1_ARM_PANIC:{}", panic_message(payload)),
                ),
            }
        })
        .collect::<Vec<_>>();
    let mut report = report_shell(&source_commit.to_ascii_lowercase(), preflight, arms)?;
    let failures = integrity_failures(&report);
    report["integrity_gate_failures"] = json!(failures);
    report["ok"] = json!(
        report["integrity_gate_failures"]
            .as_array()
            .is_some_and(Vec::is_empty)
    );
    Ok(report)
}

fn posthoc_arm_summary(arm: &Value) -> Result<Value, String> {
    let trace = arm["ordered_trace"]
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_EH1_POSTHOC_TRACE_MISSING".to_owned())?;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_torso_tilt_rad = 0.0_f64;
    let mut maximum_anchor_error_m = 0.0_f64;
    let mut maximum_hinge_axis_error_rad = 0.0_f64;
    let mut torso_ground_contact_step_count = 0_u64;
    let mut declared_event_step_count = 0_u64;
    for entry in trace {
        let snapshot = &entry["post_step_snapshot"];
        if !snapshot_json_complete(snapshot) {
            return Err("C6_RAP_V4_EH1_POSTHOC_SNAPSHOT_INVALID".to_owned());
        }
        minimum_torso_height_m = minimum_torso_height_m.min(
            snapshot["torso_height_m"]
                .as_f64()
                .expect("checked torso height"),
        );
        maximum_torso_tilt_rad = maximum_torso_tilt_rad.max(
            snapshot["torso_tilt_rad"]
                .as_f64()
                .expect("checked torso tilt"),
        );
        maximum_anchor_error_m = maximum_anchor_error_m.max(
            snapshot["maximum_anchor_error_m"]
                .as_f64()
                .expect("checked anchor error"),
        );
        maximum_hinge_axis_error_rad = maximum_hinge_axis_error_rad.max(
            snapshot["maximum_hinge_axis_error_rad"]
                .as_f64()
                .expect("checked hinge error"),
        );
        torso_ground_contact_step_count += u64::from(snapshot["torso_ground_contact"] == true);
        declared_event_step_count += u64::from(
            entry["declared_diagnostic_events"]
                .as_array()
                .is_some_and(|events| !events.is_empty()),
        );
    }
    Ok(json!({
        "arm_id": arm["arm_id"],
        "trace_step_count": trace.len(),
        "minimum_torso_height_m": minimum_torso_height_m,
        "maximum_torso_tilt_rad": maximum_torso_tilt_rad,
        "maximum_anchor_error_m": maximum_anchor_error_m,
        "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
        "torso_ground_contact_step_count": torso_ground_contact_step_count,
        "declared_event_step_count": declared_event_step_count,
        "first_failure_event": first_failure_event(trace),
        "shadow_nonzero_bounded_residual_count":
            arm["shadow_nonzero_bounded_residual_count"],
        "applied_nonzero_stability_residual_count":
            arm["applied_nonzero_stability_residual_count"],
        "terminal_post_step_snapshot": trace
            .last()
            .map(|entry| entry["post_step_snapshot"].clone())
            .unwrap_or(Value::Null),
        "physical_acceptance_authority": false,
    }))
}

/// Diagnose the immutable consumed EH1 report without rewriting or promoting
/// it. The original primary report remains `ok=false`; this function proves
/// only whether replacing the evaluator's contradicted synthetic profile ID
/// with the already-pinned canonical profile makes the retained trace
/// internally reconstructible.
pub fn evaluate_retained_bw19v_velocity_only_early_horizon_eh1_report(
    retained_report_raw: &str,
) -> Result<Value, String> {
    if raw_sha256(retained_report_raw) != RETAINED_EH1_REPORT_RAW_SHA256 {
        return Err("C6_RAP_V4_EH1_POSTHOC_REPORT_HASH_MISMATCH".to_owned());
    }
    let report: Value = serde_json::from_str(retained_report_raw)
        .map_err(|error| format!("C6_RAP_V4_EH1_POSTHOC_REPORT_PARSE:{error}"))?;
    let original_failure_codes = vec![
        "C6_RAP_V4_EH1_EH1-A_RECEIPT_INVALID:0",
        "C6_RAP_V4_EH1_EH1-A_RESIDUAL_COUNT_RECOMPUTE",
        "C6_RAP_V4_EH1_EH1-B_RECEIPT_INVALID:0",
        "C6_RAP_V4_EH1_EH1-B_RESIDUAL_COUNT_RECOMPUTE",
    ];
    if report["ok"] != false
        || report["source_commit"] != "fad011bbdca6b2b81791058abee3901bcda0ac8a"
        || report["integrity_gate_failures"] != json!(original_failure_codes)
        || report["world_build_count"] != 2
        || report["trace_step_count_total"] != TOTAL_TRACE_STEPS
    {
        return Err("C6_RAP_V4_EH1_POSTHOC_ORIGINAL_DISPOSITION_MISMATCH".to_owned());
    }
    let corrected_failures = integrity_failures(&report);
    let arms = report["arms"]
        .as_array()
        .ok_or_else(|| "C6_RAP_V4_EH1_POSTHOC_ARMS_MISSING".to_owned())?;
    let arm_summaries = arms
        .iter()
        .map(posthoc_arm_summary)
        .collect::<Result<Vec<_>, _>>()?;
    let corrected_counterfactual_integrity_passed = corrected_failures.is_empty();
    let all_traces_complete_without_declared_event = arm_summaries.iter().all(|arm| {
        arm["trace_step_count"] == HORIZON_STEPS
            && arm["declared_event_step_count"] == 0
            && arm["first_failure_event"].is_null()
    });
    let diagnostic = json!({
        "schema_version":
            "sporespore_rapier_c6_bw19v_velocity_only_eh1_posthoc_diagnostic_v1",
        "ok": corrected_counterfactual_integrity_passed
            && all_traces_complete_without_declared_event,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source_commit": report["source_commit"],
        "retained_report_raw_sha256": RETAINED_EH1_REPORT_RAW_SHA256,
        "retained_primary_report_ok": false,
        "retained_primary_report_remains_invalid": true,
        "same_identity_rerun_allowed": false,
        "original_evaluator_failure_codes": original_failure_codes,
        "primary_defect": {
            "classification": "shared_synthetic_and_evaluator_fidelity_defects",
            "incorrect_expected_profile_id":
                "rapier_force_based_velocity_only_target_v1",
            "authoritative_profile_id": "rapier_force_based_velocity_only_v1",
            "runtime_profile_id": report["arms"][0]["ordered_trace"][0]
                ["selected_rapier_host_mapping"]["host_profile_id"],
            "residual_count_failures_are_secondary_to_step_zero_early_exit": true,
            "posthoc_counter_reconstruction_defect": {
                "incorrect_basis": "nonzero_pre_clamp_bounded_residual_count",
                "correct_basis":
                    "final_clamped_canonical_velocity_differs_from_portable_canonical_base",
                "treatment_pre_clamp_nonzero_count": report["arms"][1]
                    ["shadow_nonzero_bounded_residual_count"],
                "treatment_effective_host_application_count": report["arms"][1]
                    ["applied_nonzero_stability_residual_count"],
            },
        },
        "corrected_counterfactual_integrity_failure_codes": corrected_failures,
        "corrected_counterfactual_integrity_passed":
            corrected_counterfactual_integrity_passed,
        "all_traces_complete_without_declared_event":
            all_traces_complete_without_declared_event,
        "world_build_count": report["world_build_count"],
        "trace_step_count_total": report["trace_step_count_total"],
        "host_command_count_total": report["host_command_count_total"],
        "arm_summaries": arm_summaries,
        "reported_pair_interpretation": report["pair_interpretation"],
        "scientific_disposition":
            "invalid_primary_report_with_complete_posthoc_reconstructible_trace",
        "claims": {
            "posthoc_trace_diagnostic": true,
            "primary_eh1_integrity_restored": false,
            "rapier_v4_selected_policy_physical_authority": false,
            "walking_acceptance": false,
            "bw19v_improvement": false,
            "policy_selection": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
        },
    });
    if diagnostic["ok"] != true {
        return Err(format!(
            "C6_RAP_V4_EH1_POSTHOC_DIAGNOSTIC_INVALID:{}",
            serde_json::to_string(&diagnostic).map_err(|error| error.to_string())?
        ));
    }
    Ok(diagnostic)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_zero_world_eh1_gate_and_declared_canaries_pass() {
        let report = run_bw19v_velocity_only_early_horizon_eh1_preflight().unwrap();
        assert_eq!(report["ok"], true);
        assert_eq!(
            report["perfect_synthetic_two_arm_report_passed_complete_real_integrity_gate"],
            true
        );
        assert_eq!(
            report["synthetic_outcome_variants_all_integrity_valid"],
            true
        );
        assert_eq!(report["synthetic_trace_step_count"], TOTAL_TRACE_STEPS);
        assert_eq!(report["all_declared_negative_controls_rejected"], true);
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(report["scene_insertion_count"], 0);
        assert_eq!(report["physics_state_mutation_count"], 0);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn every_declared_event_pattern_remains_integrity_valid() {
        let perfect = perfect_synthetic_report().unwrap();
        for (a_event, b_event) in [(false, false), (true, false), (false, true), (true, true)] {
            let mut report = perfect.clone();
            if a_event {
                set_synthetic_failure(&mut report, 0);
            }
            if b_event {
                set_synthetic_failure(&mut report, 1);
            }
            assert!(
                integrity_failures(&report).is_empty(),
                "physical event pattern ({a_event}, {b_event}) must not affect integrity"
            );
        }
    }
}
