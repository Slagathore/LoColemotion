use std::collections::BTreeMap;

use rapier3d::prelude::*;
use serde_json::{Map, Value, json};
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
    FootEvidence, HostRobot, build_bw19v_velocity_only_v4_robot, descriptor, motion_command,
    state_contains_nonfinite,
};
use crate::velocity_only_live_integration::{
    VELOCITY_ONLY_LIVE_PROFILE_ID, VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
    VELOCITY_ONLY_NATIVE_POSITION_STIFFNESS_NM_PER_RAD, velocity_only_small_step_impulse_limit_v1,
};
use crate::{
    ADAPTER_ID, RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
    RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS, RAPIER_ACTIVE_SOLVER_ITERATIONS, RAPIER_DT_S,
    capability_manifest_sha256,
};

const PREREGISTRATION_RAW: &str = include_str!(
    "../../../rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json"
);
const LIVE_INTEGRATION_RAW: &str =
    include_str!("../../../rapier_c6_velocity_only_live_integration_v1.json");
const ACTIVE_CONFIGURATION_V2_RAW: &str =
    include_str!("../../../rapier_c6_velocity_only_active_configuration_v2.json");
const CANONICAL_PROFILE_RAW: &str =
    include_str!("../../../canonical_velocity_actuation_profile_v1.json");
const VH1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json"
);
const C2_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json");
const EH1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.json");

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b";
const LIVE_INTEGRATION_RAW_SHA256: &str =
    "sha256:7c4c7435ca02f30073d5a33fce162fef67a461340ae609225b096abe59f88507";
const ACTIVE_CONFIGURATION_V2_RAW_SHA256: &str =
    "sha256:fb16ede4b295f69a343dde239c98874d547aba6cec6d47a71df1797f6c03c8fe";
const CANONICAL_PROFILE_RAW_SHA256: &str =
    "sha256:1240ad4bba89bc8d1c22fa270fa718c57ab5ee227d777434b3870b859001e6a3";
const VH1_CLOSURE_RAW_SHA256: &str =
    "sha256:d94b20ef4767479172408c1dfbd0b7f66e18e3f4bc8b9d8d84193fc157d284aa";
const C2_CLOSURE_RAW_SHA256: &str =
    "sha256:3047c2d9712a7d9b70c7423dab7df19bc8de96b1c39663b2bf0fb6e278fe5590";
const EH1_CLOSURE_RAW_SHA256: &str =
    "sha256:ee30507561e27f0d010683f2477c55d6f820342a46a45825ddc898fb0c6a6274";

pub const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-VELOCITY-ONLY-LONG-HORIZON-COMMISSIONING-LC1";
pub const GATE_ID: &str = "C6-RAP-BW19V-V4-LC1";
const REPORT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_velocity_only_long_horizon_lc1_report_v1";
const PREFLIGHT_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_velocity_only_long_horizon_lc1_preflight_v1";
const TRACE_SCHEMA_VERSION: &str =
    "sporespore_rapier_c6_bw19v_velocity_only_long_horizon_lc1_trace_step_v1";

const ACTUATOR_COUNT: usize = 8;
const TOTAL_STEPS: u64 = 2_992;
const CLOCKED_STEPS: u64 = 472;
const EVIDENCE_GAIT_STEPS: u64 = 1_440;
const MAXIMUM_EVIDENCE_EXTENSION_STEPS: u64 = 720;
const EVIDENCE_DEADLINE_EXCLUSIVE: u64 =
    CLOCKED_STEPS + EVIDENCE_GAIT_STEPS + MAXIMUM_EVIDENCE_EXTENSION_STEPS;
const REQUIRED_POST_EVIDENCE_STEPS: u64 = 360;
const COMMANDS_PER_LAYER: u64 = TOTAL_STEPS * ACTUATOR_COUNT as u64;

const MINIMUM_EVIDENCE_ADVANCE_M: f64 = 0.0401640625;
const MINIMUM_FINAL_ADVANCE_M: f64 = 0.030123046875;
const MAXIMUM_LATERAL_DRIFT_M: f64 = 0.10031893004115228;
const MAXIMUM_YAW_DRIFT_RAD: f64 = 0.45;
const MAXIMUM_TILT_RAD: f64 = 0.6;
const MINIMUM_TORSO_HEIGHT_M: f64 = 0.2499708652072946;
const MAXIMUM_ANCHOR_ERROR_M: f64 = 0.025575899999999995;
const MAXIMUM_HINGE_AXIS_ERROR_RAD: f64 = 0.2;
const MINIMUM_CONTACT_CYCLES_PER_LIMB: u64 = 2;
const MINIMUM_AIRBORNE_DWELL_STEPS: u64 = 3;
const MINIMUM_FOOT_RELOCATION_M: f64 = 0.01194880859375;

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn preregistration() -> Result<Value, String> {
    for (raw, expected, code) in [
        (
            PREREGISTRATION_RAW,
            PREREGISTRATION_RAW_SHA256,
            "C6_RAP_V4_LC1_PREREGISTRATION_HASH",
        ),
        (
            LIVE_INTEGRATION_RAW,
            LIVE_INTEGRATION_RAW_SHA256,
            "C6_RAP_V4_LC1_LIVE_INTEGRATION_HASH",
        ),
        (
            ACTIVE_CONFIGURATION_V2_RAW,
            ACTIVE_CONFIGURATION_V2_RAW_SHA256,
            "C6_RAP_V4_LC1_ACTIVE_CONFIGURATION_HASH",
        ),
        (
            CANONICAL_PROFILE_RAW,
            CANONICAL_PROFILE_RAW_SHA256,
            "C6_RAP_V4_LC1_CANONICAL_PROFILE_HASH",
        ),
        (
            VH1_CLOSURE_RAW,
            VH1_CLOSURE_RAW_SHA256,
            "C6_RAP_V4_LC1_VH1_CLOSURE_HASH",
        ),
        (
            C2_CLOSURE_RAW,
            C2_CLOSURE_RAW_SHA256,
            "C6_RAP_V4_LC1_C2_CLOSURE_HASH",
        ),
        (
            EH1_CLOSURE_RAW,
            EH1_CLOSURE_RAW_SHA256,
            "C6_RAP_V4_LC1_EH1_CLOSURE_HASH",
        ),
    ] {
        if raw_sha256(raw) != expected {
            return Err(code.to_owned());
        }
    }
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_RAP_V4_LC1_PREREGISTRATION_PARSE:{error}"))?;
    if declaration["campaign_id"] != CAMPAIGN_ID
        || declaration["gate_id"] != GATE_ID
        || declaration["study_class"]["classification"]
            != "outcome_exposed_single_body_finite_technical_commissioning_decision"
        || declaration["study_class"]["finite_decision"] != true
        || declaration["study_class"]["population_inference"] != false
        || declaration["physical_horizon"]["expected_world_count"] != 1
        || declaration["physical_horizon"]["total_controller_semantic_steps"] != TOTAL_STEPS
        || declaration["physical_horizon"]["terminal_zero_target_settle_steps"] != 0
        || declaration["frozen_portable_identity"]["controller_policy_id"]
            != BW19V_CONTROLLER_POLICY_ID
        || declaration["frozen_portable_identity"]["global_requested_correction_scale"]
            != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        || declaration["frozen_host_identity"]["motor_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
        || declaration["frozen_host_identity"]["motor_model"] != "ForceBased"
        || declaration["frozen_host_identity"]["native_position_stiffness_nm_per_rad"] != 0.0
        || declaration["preflight_contract"]["world_build_count"] != 0
        || declaration["claims_if_passed"]["physical_acceptance_authority"] != false
    {
        return Err("C6_RAP_V4_LC1_PREREGISTRATION_CONTRACT".to_owned());
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
    if compiled.morphology_id != "qsdk_r05_generated_s169"
        || controller.profile().policy_id != BW19V_CONTROLLER_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
        || runtime_sha != BW19V_S169_RUNTIME_PROFILE_SHA256
    {
        return Err("C6_RAP_V4_LC1_PORTABLE_IDENTITY".to_owned());
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
                .ok_or_else(|| format!("C6_RAP_V4_LC1_LIMB_MEMORY_MISSING:{limb_id}"))
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

fn position_json(position: Vector) -> Value {
    json!({"x": position.x, "y": position.y, "z": position.z})
}

fn torso_yaw(robot: &HostRobot) -> f64 {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let forward = torso.rotation() * Vector::X;
    (forward.z as f64).atan2(forward.x as f64)
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
    let yaw_rad = torso_yaw(robot);
    let contacts = robot.contacts(compiled);
    let site_positions = compiled
        .morphology
        .morphology_spec
        .contact_sites
        .iter()
        .map(|site| {
            (
                site.contact_site_id.clone(),
                position_json(robot.contact_site_position(site)),
            )
        })
        .collect::<Map<_, _>>();
    let (maximum_anchor_error_m, maximum_hinge_axis_error_rad) =
        robot.structural_metrics(compiled)?;
    let nonfinite = state_contains_nonfinite(state)
        || !tilt_rad.is_finite()
        || !torso_height_m.is_finite()
        || !yaw_rad.is_finite()
        || !maximum_anchor_error_m.is_finite()
        || !maximum_hinge_axis_error_rad.is_finite();
    Ok(Snapshot {
        value: json!({
            "torso_pose_world": state.base_pose_world,
            "torso_twist_world": state.base_twist_world,
            "torso_tilt_rad": tilt_rad,
            "torso_height_m": torso_height_m,
            "torso_yaw_rad": yaw_rad,
            "torso_ground_contact": robot.torso_ground_contact(),
            "ordered_declared_contacts": contacts,
            "ordered_contact_site_positions_m": site_positions,
            "maximum_anchor_error_m": maximum_anchor_error_m,
            "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
        }),
        nonfinite,
    })
}

fn events_from_snapshot(value: &Value) -> Option<Vec<String>> {
    let tilt = value["torso_tilt_rad"].as_f64()?;
    let height = value["torso_height_m"].as_f64()?;
    let anchor = value["maximum_anchor_error_m"].as_f64()?;
    let hinge = value["maximum_hinge_axis_error_rad"].as_f64()?;
    if [tilt, height, anchor, hinge]
        .iter()
        .any(|number| !number.is_finite())
    {
        return None;
    }
    let mut events = Vec::new();
    if value["torso_ground_contact"].as_bool()? {
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

fn count_nonzero_bounded(
    canonical: &sporespore_locomotion_core::CanonicalVelocityActuationFrameV1,
) -> u64 {
    canonical
        .ordered_commands
        .iter()
        .filter(|command| command.stability_canonical_velocity_delta_rad_s != 0.0)
        .count() as u64
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

fn count_effective_host_residuals(
    selected: &VelocityOnlyHostMappingReceiptV1,
    control: &VelocityOnlyHostMappingReceiptV1,
) -> Result<(u64, u64), String> {
    if selected.ordered_commands.len() != control.ordered_commands.len() {
        return Err("C6_RAP_V4_LC1_SELECTED_CONTROL_COMMAND_COUNT".to_owned());
    }
    let mut effective = 0_u64;
    let mut mismatches = 0_u64;
    for (selected_command, control_command) in selected
        .ordered_commands
        .iter()
        .zip(&control.ordered_commands)
    {
        if selected_command.actuator_id != control_command.actuator_id {
            mismatches += 1;
            continue;
        }
        effective += u64::from(
            selected_command.host_target_velocity_rad_s
                != control_command.host_target_velocity_rad_s,
        );
        if selected_command.native_target_position_rad.is_some()
            || selected_command.requested_target_position_rad
                != control_command.requested_target_position_rad
            || selected_command.clamped_target_position_rad
                != control_command.clamped_target_position_rad
            || selected_command.maximum_host_target_speed_rad_s
                != control_command.maximum_host_target_speed_rad_s
        {
            mismatches += 1;
        }
    }
    Ok((effective, mismatches))
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
            .ok_or_else(|| "C6_RAP_V4_LC1_ACTUATOR_MAPPING_MISSING".to_owned())?;
        let joint = robot
            .world
            .impulse_joints
            .get(robot.joints[joint_id])
            .ok_or_else(|| "C6_RAP_V4_LC1_JOINT_MISSING".to_owned())?;
        let motor = joint
            .data
            .as_revolute()
            .and_then(|revolute| revolute.motor())
            .ok_or_else(|| "C6_RAP_V4_LC1_MOTOR_MISSING".to_owned())?;
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

fn claim_boundary(technical_commissioning: bool) -> Value {
    json!({
        "exact_s169_rapier_v4_long_horizon_technical_commissioning": technical_commissioning,
        "finite_single_body_walking_contract": technical_commissioning,
        "independent_validation": false,
        "population_inference": false,
        "rapier_release_selected_policy_physical_c6": false,
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

fn run_physical_report(source_commit: &str) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("C6_RAP_V4_LC1_SOURCE_COMMIT_INVALID".to_owned());
    }
    let preflight = run_bw19v_velocity_only_long_horizon_lc1_preflight()?;
    if preflight["ok"] != true {
        return Err("C6_RAP_V4_LC1_PREFLIGHT_FAILED".to_owned());
    }
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot = build_bw19v_velocity_only_v4_robot(&compiled)?;
    let task_origin = robot.torso_position();
    let initial_state = robot.state_frame(&compiled, 0, task_origin)?;
    let initial_snapshot = snapshot(&robot, &compiled, &initial_state)?;
    let initial_events = events_from_snapshot(&initial_snapshot.value)
        .ok_or_else(|| "C6_RAP_V4_LC1_INITIAL_SNAPSHOT_INVALID".to_owned())?;
    let initial_contacts = robot.contacts(&compiled);
    let initial_contact_count = initial_contacts
        .values()
        .filter(|bearing| **bearing)
        .count();

    let mut foot_evidence = BTreeMap::<String, FootEvidence>::new();
    for limb in &compiled.morphology.morphology_spec.limbs {
        let site_id = &limb.ordered_contact_site_ids[0];
        foot_evidence.insert(
            limb.limb_id.clone(),
            FootEvidence::new(*initial_contacts.get(site_id).unwrap_or(&false)),
        );
    }

    let mut memory = BalancedWaveControllerMemory::initial();
    let mut composition_memory = RapierBw19vCompositionMemory::default();
    let mut trace = Vec::with_capacity(TOTAL_STEPS as usize);
    let mut evidence_start = None::<Vector>;
    let mut evidence_end = None::<Vector>;
    let mut evidence_completion_step = None::<u64>;

    let mut controller_error_count = 0_u64;
    let mut safe_no_actuation_count = 0_u64;
    let composition_error_count = 0_u64;
    let mut nonfinite_observation_count = u64::from(initial_snapshot.nonfinite);
    let mut actuator_application_mismatch_count = 0_u64;
    let mut motor_field_readback_mismatch_count = 0_u64;
    let mut small_step_impulse_limit_violation_count = 0_u64;
    let mut global_scale_mismatch_count = 0_u64;
    let mut native_position_target_application_count = 0_u64;
    let mut selected_control_mapping_mismatch_count = 0_u64;
    let mut base_command_count = 0_u64;
    let mut bounded_residual_command_count = 0_u64;
    let mut canonical_command_count = 0_u64;
    let mut host_command_count = 0_u64;
    let mut motor_observation_count = 0_u64;
    let mut nonzero_bounded_residual_count = 0_u64;
    let mut nonzero_effective_host_residual_count = 0_u64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_anchor_error_m = 0.0_f64;
    let mut maximum_hinge_axis_error_rad = 0.0_f64;
    let mut torso_ground_contact_step_count = 0_u64;

    for semantic_step in 0..TOTAL_STEPS {
        if semantic_step == CLOCKED_STEPS {
            evidence_start = Some(robot.torso_position());
            for limb in &mut memory.ordered_limb_memory {
                limb.evidence_gait_step_limit = Some(limb.gait_step + 1 + EVIDENCE_GAIT_STEPS);
            }
        }
        let phase_mode = if semantic_step < CLOCKED_STEPS {
            PhaseProgressionMode::Clocked
        } else {
            PhaseProgressionMode::ContactGated
        };
        let state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let pre_snapshot = snapshot(&robot, &compiled, &state)?;
        nonfinite_observation_count += u64::from(pre_snapshot.nonfinite);
        let stability_state = robot.bw19v_stability_state(&compiled, semantic_step)?;
        let kinematics = robot.bw19v_endpoint_kinematics(&compiled, &stability_state)?;
        let limb_steps = ordered_limb_steps(&compiled, &memory)?;
        let memory_before = limb_memory_json(&memory);
        let output = controller.step(&memory, &state, &motion_command(semantic_step, phase_mode));
        if output.actuation.receipt.controller_error.is_some()
            || !output.actuation.failure_codes.is_empty()
        {
            controller_error_count += 1;
        }
        safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        output
            .actuation
            .validate(&compiled.morphology)
            .map_err(|error| format!("C6_RAP_V4_LC1_ACTUATION_INVALID:{error}"))?;
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
        )
        .map_err(|error| format!("C6_RAP_V4_LC1_COMPOSITION_FAILED:{semantic_step}:{error}"))?;
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
        nonzero_bounded_residual_count += count_nonzero_bounded(&composition.canonical_actuation);
        let composition_json = composition.to_json();
        let composition_receipt_sha256 =
            digest_json(&composition_json).map_err(|error| error.to_string())?;
        let (_control_canonical, control_mapping) = map_bw19v_velocity_only_v4(
            &compiled,
            &output.actuation,
            &zero_residuals(&output.actuation),
        )?;
        let (effective, mapping_mismatches) =
            count_effective_host_residuals(&composition.host_mapping, &control_mapping)?;
        nonzero_effective_host_residual_count += effective;
        selected_control_mapping_mismatch_count += mapping_mismatches;
        native_position_target_application_count += composition
            .host_mapping
            .ordered_commands
            .iter()
            .filter(|command| command.native_target_position_rad.is_some())
            .count() as u64;
        canonical_command_count += composition.canonical_actuation.ordered_commands.len() as u64;
        host_command_count += composition.host_mapping.ordered_commands.len() as u64;
        let canonical_actuation_sha256 = digest_serializable(&composition.canonical_actuation)
            .map_err(|error| error.to_string())?;
        let host_mapping_sha256 =
            digest_serializable(&composition.host_mapping).map_err(|error| error.to_string())?;

        let (applications, apply_impulse_violations) =
            robot.apply_bw19v_velocity_only_v4_actuation(&composition.host_mapping)?;
        actuator_application_mismatch_count += u64::from(applications != ACTUATOR_COUNT as u64);
        let post_state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let post_snapshot = snapshot(&robot, &compiled, &post_state)?;
        nonfinite_observation_count += u64::from(post_snapshot.nonfinite);
        let events = events_from_snapshot(&post_snapshot.value)
            .ok_or_else(|| format!("C6_RAP_V4_LC1_POST_SNAPSHOT_INVALID:{semantic_step}"))?;
        let (motor_readbacks, field_mismatches, observed_impulse_violations, motor_nonfinite) =
            motor_observations(&robot, &composition.host_mapping)?;
        motor_field_readback_mismatch_count += field_mismatches;
        small_step_impulse_limit_violation_count +=
            apply_impulse_violations.max(observed_impulse_violations);
        nonfinite_observation_count += motor_nonfinite;
        motor_observation_count += motor_readbacks.len() as u64;

        maximum_tilt_rad =
            maximum_tilt_rad.max(post_snapshot.value["torso_tilt_rad"].as_f64().unwrap());
        minimum_torso_height_m =
            minimum_torso_height_m.min(post_snapshot.value["torso_height_m"].as_f64().unwrap());
        maximum_anchor_error_m = maximum_anchor_error_m.max(
            post_snapshot.value["maximum_anchor_error_m"]
                .as_f64()
                .unwrap(),
        );
        maximum_hinge_axis_error_rad = maximum_hinge_axis_error_rad.max(
            post_snapshot.value["maximum_hinge_axis_error_rad"]
                .as_f64()
                .unwrap(),
        );
        torso_ground_contact_step_count +=
            u64::from(post_snapshot.value["torso_ground_contact"] == true);
        for limb in &compiled.morphology.morphology_spec.limbs {
            let site_id = &limb.ordered_contact_site_ids[0];
            let site = compiled
                .morphology
                .morphology_spec
                .contact_sites
                .iter()
                .find(|site| site.contact_site_id == *site_id)
                .expect("compiled limb contact site");
            foot_evidence
                .get_mut(&limb.limb_id)
                .expect("limb evidence")
                .observe(
                    robot.contact(&site.body_id),
                    robot.contact_site_position(site),
                );
        }

        let next_memory = output.next_memory;
        let memory_after = limb_memory_json(&next_memory);
        trace.push(json!({
            "schema_version": TRACE_SCHEMA_VERSION,
            "semantic_step": semantic_step,
            "phase_progression_mode": if phase_mode == PhaseProgressionMode::Clocked {
                "clocked"
            } else {
                "contact_gated"
            },
            "command_provenance_recorded_before_application": true,
            "pre_step_snapshot": pre_snapshot.value,
            "ordered_limb_controller_memory_before": memory_before,
            "portable_controller_actuation_receipt_sha256": controller_actuation_sha256,
            "ordered_portable_base_commands": base_commands,
            "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
            "v4_composition": {
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
            },
            "canonical_actuation_frame_sha256": canonical_actuation_sha256,
            "selected_canonical_actuation_frame": composition.canonical_actuation,
            "rapier_host_mapping_sha256": host_mapping_sha256,
            "selected_rapier_host_mapping": composition.host_mapping,
            "ordered_load_bearing_host_commands": composition.host_mapping.ordered_commands,
            "ordered_post_step_joint_motor_readbacks_and_impulses": motor_readbacks,
            "post_step_snapshot": post_snapshot.value,
            "declared_diagnostic_events": events,
            "ordered_limb_controller_memory_after": memory_after,
        }));
        memory = next_memory;
        if evidence_completion_step.is_none()
            && semantic_step >= CLOCKED_STEPS
            && memory.ordered_limb_memory.iter().all(|limb| {
                limb.evidence_gait_step_limit
                    .is_some_and(|limit| limb.gait_step >= limit)
            })
        {
            evidence_completion_step = Some(semantic_step);
            evidence_end = Some(robot.torso_position());
        }
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let evidence_delta = evidence_end
        .zip(evidence_start)
        .map(|(end, start)| end - start);
    let terminal_contacts = robot.contacts(&compiled);
    let terminal_four_contact_stance = terminal_contacts.values().all(|contact| *contact);
    let required_post_evidence_steps_completed = evidence_completion_step
        .is_some_and(|step| step + REQUIRED_POST_EVIDENCE_STEPS < TOTAL_STEPS);
    let limb_evidence = foot_evidence
        .iter()
        .map(|(limb_id, evidence)| {
            (
                limb_id.clone(),
                json!({
                    "contact_cycles": evidence.contact_cycles,
                    "maximum_foot_relocation_m": evidence.maximum_foot_relocation_m,
                    "maximum_airborne_dwell_steps": evidence.maximum_airborne_dwell_steps,
                }),
            )
        })
        .collect::<Map<_, _>>();

    let mut report = json!({
        "schema_version": REPORT_SCHEMA_VERSION,
        "ok": false,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "source_commit": source_commit.to_ascii_lowercase(),
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "live_integration_raw_sha256": LIVE_INTEGRATION_RAW_SHA256,
        "active_configuration_v2_raw_sha256": ACTIVE_CONFIGURATION_V2_RAW_SHA256,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "eh1_closure_raw_sha256": EH1_CLOSURE_RAW_SHA256,
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
        "ordered_limb_ids": compiled.morphology.ordered_limb_ids,
        "host_configuration": {
            "motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
            "motor_model": "ForceBased",
            "motor_mode": "velocity_only",
            "native_position_stiffness_nm_per_rad": 0.0,
            "damping_nm_s_per_rad": VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
            "outer_timestep_s": RAPIER_DT_S,
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations": RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "authored_friction": 0.95,
            "terminal_zero_target_settle_steps": 0,
        },
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": compiled.morphology.ordered_body_ids.len(),
        "joint_count": compiled.morphology.ordered_joint_ids.len(),
        "actuator_count": compiled.morphology.ordered_actuator_ids.len(),
        "controller_error_count": controller_error_count,
        "safe_no_actuation_count": safe_no_actuation_count,
        "composition_error_count": composition_error_count,
        "nonfinite_observation_count": nonfinite_observation_count,
        "actuator_application_mismatch_count": actuator_application_mismatch_count,
        "motor_model_or_field_readback_mismatch_count": motor_field_readback_mismatch_count,
        "small_step_impulse_limit_violation_count": small_step_impulse_limit_violation_count,
        "global_scale_mismatch_count": global_scale_mismatch_count,
        "native_position_target_application_count": native_position_target_application_count,
        "selected_control_mapping_mismatch_count": selected_control_mapping_mismatch_count,
        "trace_step_count": trace.len(),
        "base_command_count": base_command_count,
        "bounded_residual_command_count": bounded_residual_command_count,
        "canonical_command_count": canonical_command_count,
        "host_command_count": host_command_count,
        "motor_observation_count": motor_observation_count,
        "nonzero_bounded_residual_count": nonzero_bounded_residual_count,
        "nonzero_effective_host_residual_count": nonzero_effective_host_residual_count,
        "initial_pose_snapshot": initial_snapshot.value,
        "initial_declared_diagnostic_events": initial_events,
        "initial_contact_count": initial_contact_count,
        "schedule": {
            "zero_target_settle_steps": 0,
            "controller_authority_began_at_semantic_step": 0,
            "total_controller_semantic_steps": TOTAL_STEPS,
            "clocked_steps": CLOCKED_STEPS,
            "contact_gated_start_step": CLOCKED_STEPS,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
            "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
            "evidence_limits_reached": evidence_completion_step.is_some(),
            "evidence_completion_semantic_step": evidence_completion_step,
            "required_post_evidence_steps": REQUIRED_POST_EVIDENCE_STEPS,
            "required_post_evidence_steps_completed": required_post_evidence_steps_completed,
            "terminal_zero_target_settle_steps": 0,
        },
        "metrics": {
            "evidence_forward_displacement_m": evidence_delta.map(|delta| delta.x),
            "final_forward_displacement_m": final_delta.x,
            "final_lateral_displacement_m": final_delta.z,
            "final_yaw_drift_rad": torso_yaw(&robot),
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "maximum_anchor_error_m": maximum_anchor_error_m,
            "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
        },
        "terminal_four_contact_stance": terminal_four_contact_stance,
        "torso_ground_contact_step_count": torso_ground_contact_step_count,
        "limb_evidence": Value::Object(limb_evidence),
        "ordered_trace": trace,
        "gate_failures": [],
        "claim_boundary": claim_boundary(false),
    });
    let failures = full_gate_failures(&report);
    let passed = failures.is_empty();
    report["gate_failures"] = json!(failures);
    report["ok"] = json!(passed);
    report["claim_boundary"] = claim_boundary(passed);
    Ok(report)
}

pub fn run_bw19v_velocity_only_long_horizon_lc1(source_commit: &str) -> Result<Value, String> {
    run_physical_report(source_commit)
}

fn u64_at(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer)?.as_u64()
}

fn f64_at(value: &Value, pointer: &str) -> Option<f64> {
    value
        .pointer(pointer)?
        .as_f64()
        .filter(|number| number.is_finite())
}

fn bool_at(value: &Value, pointer: &str) -> Option<bool> {
    value.pointer(pointer)?.as_bool()
}

fn close(left: f64, right: f64, tolerance: f64) -> bool {
    left.is_finite() && right.is_finite() && (left - right).abs() <= tolerance
}

fn ordered_ids_match(value: &Value, expected: &[String]) -> bool {
    value.as_array().is_some_and(|entries| {
        entries.len() == expected.len()
            && entries.iter().zip(expected).all(|(entry, actuator_id)| {
                entry["actuator_id"].as_str() == Some(actuator_id.as_str())
            })
    })
}

fn snapshot_position(value: &Value) -> Option<(f64, f64, f64)> {
    Some((
        f64_at(value, "/torso_pose_world/position_m/x")?,
        f64_at(value, "/torso_pose_world/position_m/y")?,
        f64_at(value, "/torso_pose_world/position_m/z")?,
    ))
}

fn snapshot_is_structurally_valid(value: &Value, contact_ids: &[String]) -> bool {
    let Some((_, y, _)) = snapshot_position(value) else {
        return false;
    };
    if !y.is_finite()
        || f64_at(value, "/torso_tilt_rad").is_none()
        || f64_at(value, "/torso_height_m").is_none()
        || f64_at(value, "/torso_yaw_rad").is_none()
        || bool_at(value, "/torso_ground_contact").is_none()
        || f64_at(value, "/maximum_anchor_error_m").is_none()
        || f64_at(value, "/maximum_hinge_axis_error_rad").is_none()
    {
        return false;
    }
    contact_ids.iter().all(|contact_id| {
        value["ordered_declared_contacts"][contact_id]
            .as_bool()
            .is_some()
            && value["ordered_contact_site_positions_m"][contact_id]["x"]
                .as_f64()
                .is_some_and(f64::is_finite)
            && value["ordered_contact_site_positions_m"][contact_id]["y"]
                .as_f64()
                .is_some_and(f64::is_finite)
            && value["ordered_contact_site_positions_m"][contact_id]["z"]
                .as_f64()
                .is_some_and(f64::is_finite)
    })
}

fn memory_reached_limits(value: &Value, limb_ids: &[String]) -> bool {
    let Some(entries) = value.as_array() else {
        return false;
    };
    entries.len() == limb_ids.len()
        && entries.iter().zip(limb_ids).all(|(entry, limb_id)| {
            entry["limb_id"].as_str() == Some(limb_id.as_str())
                && entry["evidence_gait_step_limit"]
                    .as_u64()
                    .zip(entry["gait_step"].as_u64())
                    .is_some_and(|(limit, step)| step >= limit)
        })
}

fn push_once(failures: &mut Vec<String>, code: &str) {
    if !failures.iter().any(|failure| failure == code) {
        failures.push(code.to_owned());
    }
}

fn full_gate_failures(report: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    let Ok((compiled, controller)) = compile_declared_boundary() else {
        return vec!["C6_RAP_V4_LC1_COMPILED_BOUNDARY_UNAVAILABLE".to_owned()];
    };
    let actuator_ids = &compiled.morphology.ordered_actuator_ids;
    let limb_ids = &compiled.morphology.ordered_limb_ids;
    let contact_ids = compiled
        .morphology
        .morphology_spec
        .contact_sites
        .iter()
        .map(|site| site.contact_site_id.clone())
        .collect::<Vec<_>>();
    let runtime_sha = digest_serializable(controller.profile()).ok();

    if report["schema_version"] != REPORT_SCHEMA_VERSION
        || report["campaign_id"] != CAMPAIGN_ID
        || report["gate_id"] != GATE_ID
        || report["study_class"]
            != "outcome_exposed_single_body_finite_technical_commissioning_decision"
        || report["preregistration_raw_sha256"] != PREREGISTRATION_RAW_SHA256
        || report["live_integration_raw_sha256"] != LIVE_INTEGRATION_RAW_SHA256
        || report["active_configuration_v2_raw_sha256"] != ACTIVE_CONFIGURATION_V2_RAW_SHA256
        || report["canonical_profile_raw_sha256"] != CANONICAL_PROFILE_RAW_SHA256
        || report["vh1_closure_raw_sha256"] != VH1_CLOSURE_RAW_SHA256
        || report["c2_closure_raw_sha256"] != C2_CLOSURE_RAW_SHA256
        || report["eh1_closure_raw_sha256"] != EH1_CLOSURE_RAW_SHA256
        || report["candidate_id"] != BW19V_CANDIDATE_ID
        || report["candidate_composition_digest"] != BW19V_CANDIDATE_COMPOSITION_DIGEST
        || report["selected_policy_id"] != BW19V_CONTROLLER_POLICY_ID
        || report["selected_policy_digest"] != BW19V_CONTROLLER_POLICY_DIGEST
        || report["runtime_profile_sha256"] != BW19V_S169_RUNTIME_PROFILE_SHA256
        || runtime_sha.as_deref() != Some(BW19V_S169_RUNTIME_PROFILE_SHA256)
        || report["global_requested_correction_scale"] != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        || report["morphology_id"] != compiled.morphology_id
        || report["descriptor_sha256"] != compiled.descriptor_sha256
        || report["ordered_actuator_ids"] != json!(actuator_ids)
        || report["ordered_limb_ids"] != json!(limb_ids)
    {
        failures.push("C6_RAP_V4_LC1_IDENTITY_INVALID".to_owned());
    }
    if report["preflight"]["ok"] != true
        || report["preflight"]["world_build_count"] != 0
        || report["preflight"]["physical_acceptance_authority"] != false
    {
        failures.push("C6_RAP_V4_LC1_PREFLIGHT_RECEIPT_INVALID".to_owned());
    }
    if report["engine"] != "rapier3d"
        || report["engine_version"] != rapier3d::VERSION
        || report["adapter_id"] != ADAPTER_ID
        || report["adapter_capability_sha256"] != capability_manifest_sha256()
        || report["host_configuration"]["motor_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
        || report["host_configuration"]["motor_model"] != "ForceBased"
        || report["host_configuration"]["motor_mode"] != "velocity_only"
        || report["host_configuration"]["native_position_stiffness_nm_per_rad"] != 0.0
        || report["host_configuration"]["damping_nm_s_per_rad"]
            != VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
        || report["host_configuration"]["solver_iterations"] != RAPIER_ACTIVE_SOLVER_ITERATIONS
        || report["host_configuration"]["internal_pgs_iterations"]
            != RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
        || report["host_configuration"]["internal_stabilization_iterations"]
            != RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS
        || report["host_configuration"]["terminal_zero_target_settle_steps"] != 0
    {
        failures.push("C6_RAP_V4_LC1_HOST_CONFIGURATION_INVALID".to_owned());
    }
    for (pointer, expected) in [
        ("/world_attempt_count", 1),
        ("/world_build_count", 1),
        ("/world_reset_count", 0),
        ("/body_count", 9),
        ("/joint_count", 8),
        ("/actuator_count", ACTUATOR_COUNT as u64),
        ("/trace_step_count", TOTAL_STEPS),
        ("/base_command_count", COMMANDS_PER_LAYER),
        ("/bounded_residual_command_count", COMMANDS_PER_LAYER),
        ("/canonical_command_count", COMMANDS_PER_LAYER),
        ("/host_command_count", COMMANDS_PER_LAYER),
        ("/motor_observation_count", COMMANDS_PER_LAYER),
        ("/controller_error_count", 0),
        ("/safe_no_actuation_count", 0),
        ("/composition_error_count", 0),
        ("/nonfinite_observation_count", 0),
        ("/actuator_application_mismatch_count", 0),
        ("/motor_model_or_field_readback_mismatch_count", 0),
        ("/small_step_impulse_limit_violation_count", 0),
        ("/global_scale_mismatch_count", 0),
        ("/native_position_target_application_count", 0),
        ("/selected_control_mapping_mismatch_count", 0),
    ] {
        if u64_at(report, pointer) != Some(expected) {
            failures.push(format!("C6_RAP_V4_LC1_COUNT_INVALID:{pointer}"));
        }
    }
    if u64_at(report, "/nonzero_bounded_residual_count").unwrap_or(0) == 0 {
        failures.push("C6_RAP_V4_LC1_NONZERO_BOUNDED_RESIDUAL_MISSING".to_owned());
    }
    if u64_at(report, "/nonzero_effective_host_residual_count").unwrap_or(0) == 0 {
        failures.push("C6_RAP_V4_LC1_NONZERO_EFFECTIVE_RESIDUAL_MISSING".to_owned());
    }
    if report["schedule"]["zero_target_settle_steps"] != 0
        || report["schedule"]["controller_authority_began_at_semantic_step"] != 0
        || report["schedule"]["total_controller_semantic_steps"] != TOTAL_STEPS
        || report["schedule"]["clocked_steps"] != CLOCKED_STEPS
        || report["schedule"]["contact_gated_start_step"] != CLOCKED_STEPS
        || report["schedule"]["evidence_gait_steps_per_limb"] != EVIDENCE_GAIT_STEPS
        || report["schedule"]["maximum_evidence_extension_steps"]
            != MAXIMUM_EVIDENCE_EXTENSION_STEPS
        || report["schedule"]["evidence_deadline_step_exclusive"] != EVIDENCE_DEADLINE_EXCLUSIVE
        || report["schedule"]["required_post_evidence_steps"] != REQUIRED_POST_EVIDENCE_STEPS
        || report["schedule"]["terminal_zero_target_settle_steps"] != 0
    {
        failures.push("C6_RAP_V4_LC1_SCHEDULE_INVALID".to_owned());
    }

    let Some(trace) = report["ordered_trace"].as_array() else {
        failures.push("C6_RAP_V4_LC1_TRACE_MISSING".to_owned());
        return failures;
    };
    if trace.len() != TOTAL_STEPS as usize {
        failures.push("C6_RAP_V4_LC1_TRACE_LENGTH_INVALID".to_owned());
        return failures;
    }
    if !snapshot_is_structurally_valid(&report["initial_pose_snapshot"], &contact_ids)
        || events_from_snapshot(&report["initial_pose_snapshot"])
            .is_none_or(|events| !events.is_empty())
        || report["initial_declared_diagnostic_events"] != json!([])
    {
        failures.push("C6_RAP_V4_LC1_INITIAL_SNAPSHOT_INVALID".to_owned());
    }
    let recomputed_initial_contact_count = contact_ids
        .iter()
        .filter(|contact_id| {
            report["initial_pose_snapshot"]["ordered_declared_contacts"][*contact_id] == true
        })
        .count() as u64;
    if u64_at(report, "/initial_contact_count") != Some(recomputed_initial_contact_count) {
        failures.push("C6_RAP_V4_LC1_INITIAL_CONTACT_COUNT_INVALID".to_owned());
    }

    let mut recomputed_base = 0_u64;
    let mut recomputed_bounded = 0_u64;
    let mut recomputed_canonical = 0_u64;
    let mut recomputed_host = 0_u64;
    let mut recomputed_motor = 0_u64;
    let mut recomputed_nonzero_bounded = 0_u64;
    let mut recomputed_nonzero_effective = 0_u64;
    let mut recomputed_maximum_tilt = 0.0_f64;
    let mut recomputed_minimum_height = f64::INFINITY;
    let mut recomputed_maximum_anchor = 0.0_f64;
    let mut recomputed_maximum_hinge = 0.0_f64;
    let mut recomputed_torso_contacts = 0_u64;
    let mut first_evidence_completion = None::<u64>;
    let mut evidence_start_position = None::<(f64, f64, f64)>;
    let mut evidence_end_position = None::<(f64, f64, f64)>;
    let initial_position = snapshot_position(&report["initial_pose_snapshot"]);
    let mut recomputed_foot_evidence = BTreeMap::<String, FootEvidence>::new();
    for limb in &compiled.morphology.morphology_spec.limbs {
        let site_id = &limb.ordered_contact_site_ids[0];
        let initial = report["initial_pose_snapshot"]["ordered_declared_contacts"][site_id]
            .as_bool()
            .unwrap_or(false);
        recomputed_foot_evidence.insert(limb.limb_id.clone(), FootEvidence::new(initial));
    }

    for (index, entry) in trace.iter().enumerate() {
        let semantic_step = index as u64;
        let expected_phase = if semantic_step < CLOCKED_STEPS {
            "clocked"
        } else {
            "contact_gated"
        };
        if entry["schema_version"] != TRACE_SCHEMA_VERSION
            || entry["semantic_step"] != semantic_step
            || entry["phase_progression_mode"] != expected_phase
            || entry["command_provenance_recorded_before_application"] != true
            || entry["production_motor_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
        {
            push_once(
                &mut failures,
                "C6_RAP_V4_LC1_TRACE_ORDER_OR_IDENTITY_INVALID",
            );
        }
        if !snapshot_is_structurally_valid(&entry["pre_step_snapshot"], &contact_ids)
            || !snapshot_is_structurally_valid(&entry["post_step_snapshot"], &contact_ids)
        {
            push_once(&mut failures, "C6_RAP_V4_LC1_TRACE_SNAPSHOT_INVALID");
            continue;
        }
        if semantic_step == CLOCKED_STEPS {
            evidence_start_position = snapshot_position(&entry["pre_step_snapshot"]);
        }
        let expected_events = events_from_snapshot(&entry["post_step_snapshot"]);
        if expected_events.as_ref().map(|events| json!(events))
            != Some(entry["declared_diagnostic_events"].clone())
        {
            push_once(&mut failures, "C6_RAP_V4_LC1_EVENT_RECONSTRUCTION_INVALID");
        }
        if expected_events.is_some_and(|events| !events.is_empty()) {
            push_once(&mut failures, "C6_RAP_V4_LC1_DECLARED_PHYSICAL_EVENT");
        }
        recomputed_maximum_tilt = recomputed_maximum_tilt
            .max(f64_at(entry, "/post_step_snapshot/torso_tilt_rad").unwrap_or(f64::INFINITY));
        recomputed_minimum_height = recomputed_minimum_height
            .min(f64_at(entry, "/post_step_snapshot/torso_height_m").unwrap_or(f64::NEG_INFINITY));
        recomputed_maximum_anchor = recomputed_maximum_anchor.max(
            f64_at(entry, "/post_step_snapshot/maximum_anchor_error_m").unwrap_or(f64::INFINITY),
        );
        recomputed_maximum_hinge = recomputed_maximum_hinge.max(
            f64_at(entry, "/post_step_snapshot/maximum_hinge_axis_error_rad")
                .unwrap_or(f64::INFINITY),
        );
        recomputed_torso_contacts +=
            u64::from(entry["post_step_snapshot"]["torso_ground_contact"] == true);

        let arrays = [
            &entry["ordered_portable_base_commands"],
            &entry["v4_composition"]["ordered_bounded_canonical_residuals"],
            &entry["selected_canonical_actuation_frame"]["ordered_commands"],
            &entry["selected_rapier_host_mapping"]["ordered_commands"],
            &entry["ordered_load_bearing_host_commands"],
            &entry["ordered_post_step_joint_motor_readbacks_and_impulses"],
        ];
        if arrays
            .iter()
            .any(|array| !ordered_ids_match(array, actuator_ids))
        {
            push_once(&mut failures, "C6_RAP_V4_LC1_ACTUATOR_ORDER_INVALID");
            continue;
        }
        recomputed_base += ACTUATOR_COUNT as u64;
        recomputed_bounded += ACTUATOR_COUNT as u64;
        recomputed_canonical += ACTUATOR_COUNT as u64;
        recomputed_host += ACTUATOR_COUNT as u64;
        recomputed_motor += ACTUATOR_COUNT as u64;

        let canonical = &entry["selected_canonical_actuation_frame"];
        let mapping = &entry["selected_rapier_host_mapping"];
        let planning = &entry["v4_composition"]["v4_planning_and_bounding_receipt"];
        if digest_json(canonical).ok().as_deref()
            != entry["canonical_actuation_frame_sha256"].as_str()
            || digest_json(mapping).ok().as_deref() != entry["rapier_host_mapping_sha256"].as_str()
            || digest_json(planning).ok().as_deref()
                != entry["v4_composition"]["v4_planning_and_bounding_receipt_sha256"].as_str()
            || mapping["ordered_commands"] != entry["ordered_load_bearing_host_commands"]
            || canonical["source_policy_id"] != BW19V_CONTROLLER_POLICY_ID
            || canonical["semantic_step"] != semantic_step
            || mapping["semantic_step"] != semantic_step
            || mapping["host_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
            || mapping["native_position_stiffness"] != 0.0
            || mapping["independent_native_position_feedback_applied"] != false
            || entry["v4_composition"]["global_requested_correction_scale"]
                != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
            || entry["v4_composition"]["retained_mixed_space_projection_applied"] != false
        {
            push_once(&mut failures, "C6_RAP_V4_LC1_RECEIPT_INVALID");
        }
        let bounded = arrays[1].as_array().unwrap();
        let canonical_commands = arrays[2].as_array().unwrap();
        let host_commands = arrays[4].as_array().unwrap();
        let motors = arrays[5].as_array().unwrap();
        for actuator_index in 0..ACTUATOR_COUNT {
            let bounded_delta = bounded[actuator_index]["applied_velocity_delta_rad_s"].as_f64();
            let stability_delta =
                canonical_commands[actuator_index]["stability_canonical_velocity_delta_rad_s"]
                    .as_f64();
            let portable_velocity =
                canonical_commands[actuator_index]["portable_canonical_target_velocity_rad_s"]
                    .as_f64();
            let combined_velocity =
                canonical_commands[actuator_index]["combined_canonical_target_velocity_rad_s"]
                    .as_f64();
            let host_velocity =
                host_commands[actuator_index]["host_target_velocity_rad_s"].as_f64();
            let motor_expected = motors[actuator_index]["expected_target_velocity_rad_s"].as_f64();
            let motor_observed = motors[actuator_index]["target_velocity_rad_s"].as_f64();
            if bounded_delta
                .zip(stability_delta)
                .is_none_or(|(left, right)| left != right)
                || combined_velocity
                    .zip(host_velocity)
                    .is_none_or(|(left, right)| left != right)
                || host_velocity
                    .zip(motor_expected)
                    .is_none_or(|(left, right)| left != right)
                || motor_expected
                    .zip(motor_observed)
                    .is_none_or(|(expected, observed)| !close(expected, observed, 1.0e-6))
                || host_commands[actuator_index]["native_target_position_rad"] != Value::Null
                || motors[actuator_index]["motor_model"] != "ForceBased"
                || motors[actuator_index]["target_position_rad"] != 0.0
                || motors[actuator_index]["stiffness_nm_per_rad"] != 0.0
                || motors[actuator_index]["damping_nm_s_per_rad"]
                    != VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
                || motors[actuator_index]["fields_match"] != true
            {
                push_once(&mut failures, "C6_RAP_V4_LC1_MOTOR_OR_MAPPING_INVALID");
            }
            if stability_delta.is_some_and(|delta| delta != 0.0) {
                recomputed_nonzero_bounded += 1;
            }
            if portable_velocity
                .zip(combined_velocity)
                .is_some_and(|(base, combined)| base != combined)
            {
                recomputed_nonzero_effective += 1;
            }
            if f64_at(&motors[actuator_index], "/motor_impulse_nms")
                .zip(f64_at(
                    &motors[actuator_index],
                    "/small_step_impulse_limit_nms",
                ))
                .is_none_or(|(impulse, limit)| impulse.abs() > limit + 1.0e-6)
            {
                push_once(&mut failures, "C6_RAP_V4_LC1_IMPULSE_LIMIT_INVALID");
            }
        }
        for limb in &compiled.morphology.morphology_spec.limbs {
            let site_id = &limb.ordered_contact_site_ids[0];
            let contact = entry["post_step_snapshot"]["ordered_declared_contacts"][site_id]
                .as_bool()
                .unwrap_or(false);
            let position = Vector::new(
                entry["post_step_snapshot"]["ordered_contact_site_positions_m"][site_id]["x"]
                    .as_f64()
                    .unwrap_or(f64::NAN) as f32,
                entry["post_step_snapshot"]["ordered_contact_site_positions_m"][site_id]["y"]
                    .as_f64()
                    .unwrap_or(f64::NAN) as f32,
                entry["post_step_snapshot"]["ordered_contact_site_positions_m"][site_id]["z"]
                    .as_f64()
                    .unwrap_or(f64::NAN) as f32,
            );
            recomputed_foot_evidence
                .get_mut(&limb.limb_id)
                .expect("recomputed limb evidence")
                .observe(contact, position);
        }
        if first_evidence_completion.is_none()
            && semantic_step >= CLOCKED_STEPS
            && memory_reached_limits(&entry["ordered_limb_controller_memory_after"], limb_ids)
        {
            first_evidence_completion = Some(semantic_step);
            evidence_end_position = snapshot_position(&entry["post_step_snapshot"]);
        }
    }

    for (pointer, recomputed) in [
        ("/base_command_count", recomputed_base),
        ("/bounded_residual_command_count", recomputed_bounded),
        ("/canonical_command_count", recomputed_canonical),
        ("/host_command_count", recomputed_host),
        ("/motor_observation_count", recomputed_motor),
        (
            "/nonzero_bounded_residual_count",
            recomputed_nonzero_bounded,
        ),
        (
            "/nonzero_effective_host_residual_count",
            recomputed_nonzero_effective,
        ),
        (
            "/torso_ground_contact_step_count",
            recomputed_torso_contacts,
        ),
    ] {
        if u64_at(report, pointer) != Some(recomputed) {
            failures.push(format!("C6_RAP_V4_LC1_RECOMPUTE:{pointer}"));
        }
    }
    if report["schedule"]["evidence_limits_reached"] != first_evidence_completion.is_some()
        || report["schedule"]["evidence_completion_semantic_step"]
            != first_evidence_completion
                .map(Value::from)
                .unwrap_or(Value::Null)
    {
        failures.push("C6_RAP_V4_LC1_EVIDENCE_COMPLETION_RECOMPUTE".to_owned());
    }
    let post_evidence_complete = first_evidence_completion
        .is_some_and(|step| step + REQUIRED_POST_EVIDENCE_STEPS < TOTAL_STEPS);
    if report["schedule"]["required_post_evidence_steps_completed"] != post_evidence_complete
        || first_evidence_completion.is_none_or(|step| step >= EVIDENCE_DEADLINE_EXCLUSIVE)
    {
        failures.push("C6_RAP_V4_LC1_EVIDENCE_DEADLINE_OR_COOLDOWN".to_owned());
    }
    let evidence_advance = evidence_start_position
        .zip(evidence_end_position)
        .map(|(start, end)| end.0 - start.0);
    let final_position = trace
        .last()
        .and_then(|entry| snapshot_position(&entry["post_step_snapshot"]));
    let final_delta = initial_position
        .zip(final_position)
        .map(|(start, end)| (end.0 - start.0, end.1 - start.1, end.2 - start.2));
    let final_yaw = trace
        .last()
        .and_then(|entry| f64_at(entry, "/post_step_snapshot/torso_yaw_rad"));
    for (pointer, recomputed) in [
        ("/metrics/evidence_forward_displacement_m", evidence_advance),
        (
            "/metrics/final_forward_displacement_m",
            final_delta.map(|delta| delta.0),
        ),
        (
            "/metrics/final_lateral_displacement_m",
            final_delta.map(|delta| delta.2),
        ),
        ("/metrics/final_yaw_drift_rad", final_yaw),
        ("/metrics/maximum_tilt_rad", Some(recomputed_maximum_tilt)),
        (
            "/metrics/minimum_torso_height_m",
            Some(recomputed_minimum_height),
        ),
        (
            "/metrics/maximum_anchor_error_m",
            Some(recomputed_maximum_anchor),
        ),
        (
            "/metrics/maximum_hinge_axis_error_rad",
            Some(recomputed_maximum_hinge),
        ),
    ] {
        if f64_at(report, pointer)
            .zip(recomputed)
            .is_none_or(|(declared, actual)| !close(declared, actual, 1.0e-6))
        {
            failures.push(format!("C6_RAP_V4_LC1_METRIC_RECOMPUTE:{pointer}"));
        }
    }
    let terminal_four_contact = trace.last().is_some_and(|entry| {
        contact_ids.iter().all(|contact_id| {
            entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true
        })
    });
    if report["terminal_four_contact_stance"] != terminal_four_contact || !terminal_four_contact {
        failures.push("C6_RAP_V4_LC1_TERMINAL_STANCE".to_owned());
    }
    for (limb_id, evidence) in &recomputed_foot_evidence {
        let declared = &report["limb_evidence"][limb_id];
        if declared["contact_cycles"] != evidence.contact_cycles
            || f64_at(declared, "/maximum_foot_relocation_m")
                .is_none_or(|value| !close(value, evidence.maximum_foot_relocation_m, 1.0e-6))
            || declared["maximum_airborne_dwell_steps"] != evidence.maximum_airborne_dwell_steps
        {
            failures.push(format!("C6_RAP_V4_LC1_LIMB_RECOMPUTE:{limb_id}"));
        }
        if evidence.contact_cycles < MINIMUM_CONTACT_CYCLES_PER_LIMB
            || evidence.maximum_airborne_dwell_steps < MINIMUM_AIRBORNE_DWELL_STEPS
            || evidence.maximum_foot_relocation_m < MINIMUM_FOOT_RELOCATION_M
        {
            failures.push(format!("C6_RAP_V4_LC1_LIMB_GATE:{limb_id}"));
        }
    }
    if evidence_advance.is_none_or(|value| value < MINIMUM_EVIDENCE_ADVANCE_M) {
        failures.push("C6_RAP_V4_LC1_EVIDENCE_ADVANCE".to_owned());
    }
    if final_delta.is_none_or(|delta| delta.0 < MINIMUM_FINAL_ADVANCE_M) {
        failures.push("C6_RAP_V4_LC1_FINAL_ADVANCE".to_owned());
    }
    if final_delta.is_none_or(|delta| delta.2.abs() > MAXIMUM_LATERAL_DRIFT_M) {
        failures.push("C6_RAP_V4_LC1_LATERAL_DRIFT".to_owned());
    }
    if final_yaw.is_none_or(|value| value.abs() > MAXIMUM_YAW_DRIFT_RAD) {
        failures.push("C6_RAP_V4_LC1_YAW_DRIFT".to_owned());
    }
    if recomputed_maximum_tilt > MAXIMUM_TILT_RAD {
        failures.push("C6_RAP_V4_LC1_TILT".to_owned());
    }
    if recomputed_minimum_height < MINIMUM_TORSO_HEIGHT_M {
        failures.push("C6_RAP_V4_LC1_TORSO_HEIGHT".to_owned());
    }
    if recomputed_maximum_anchor > MAXIMUM_ANCHOR_ERROR_M {
        failures.push("C6_RAP_V4_LC1_ANCHOR_ERROR".to_owned());
    }
    if recomputed_maximum_hinge > MAXIMUM_HINGE_AXIS_ERROR_RAD {
        failures.push("C6_RAP_V4_LC1_HINGE_AXIS_ERROR".to_owned());
    }
    if recomputed_torso_contacts != 0 {
        failures.push("C6_RAP_V4_LC1_TORSO_GROUND_CONTACT".to_owned());
    }
    let claims = &report["claim_boundary"];
    if claims["independent_validation"] != false
        || claims["population_inference"] != false
        || claims["rapier_release_selected_policy_physical_c6"] != false
        || claims["cross_engine_selected_policy_equivalence"] != false
        || claims["arbitrary_quadruped_coverage"] != false
        || claims["continuous_full_volume_coverage"] != false
        || claims["friction_or_material_robustness"] != false
        || claims["release_authorized"] != false
        || claims["physical_acceptance_authority"] != false
        || claims["completed_engine_neutral_sdk"] != false
    {
        failures.push("C6_RAP_V4_LC1_CLAIM_INFLATION".to_owned());
    }
    failures
}

pub fn evaluate_bw19v_velocity_only_long_horizon_lc1_report(report: &Value) -> Vec<String> {
    full_gate_failures(report)
}

fn synthetic_contact(step: u64, site_index: usize) -> bool {
    let offset = site_index as u64 * 20;
    !((600 + offset..606 + offset).contains(&step)
        || (1_200 + offset..1_206 + offset).contains(&step))
}

fn synthetic_site_x(step: u64, site_index: usize) -> f64 {
    let offset = site_index as u64 * 20;
    let cycles = u64::from(step >= 606 + offset) + u64::from(step >= 1_206 + offset);
    site_index as f64 * 0.1 + cycles as f64 * 0.02
}

fn synthetic_snapshot(sample_index: u64, contact_ids: &[String], post_step: bool) -> Value {
    let position_step = if post_step {
        sample_index + 1
    } else {
        sample_index
    };
    let contact_step = if post_step {
        sample_index
    } else {
        sample_index.saturating_sub(1)
    };
    let contacts = contact_ids
        .iter()
        .enumerate()
        .map(|(index, contact_id)| {
            (
                contact_id.clone(),
                json!(synthetic_contact(contact_step, index)),
            )
        })
        .collect::<Map<_, _>>();
    let positions = contact_ids
        .iter()
        .enumerate()
        .map(|(index, contact_id)| {
            (
                contact_id.clone(),
                json!({
                    "x": synthetic_site_x(contact_step, index),
                    "y": 0.0,
                    "z": index as f64 * 0.05,
                }),
            )
        })
        .collect::<Map<_, _>>();
    json!({
        "torso_pose_world": {
            "position_m": {
                "x": position_step as f64 * 0.0002,
                "y": 0.44,
                "z": 0.0,
            },
            "orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
        },
        "torso_twist_world": {
            "linear_velocity_m_s": {"x": 0.024, "y": 0.0, "z": 0.0},
            "angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
        },
        "torso_tilt_rad": 0.0,
        "torso_height_m": 0.44,
        "torso_yaw_rad": 0.0,
        "torso_ground_contact": false,
        "ordered_declared_contacts": contacts,
        "ordered_contact_site_positions_m": positions,
        "maximum_anchor_error_m": 0.0,
        "maximum_hinge_axis_error_rad": 0.0,
    })
}

fn synthetic_limb_memory(limb_ids: &[String], semantic_step: u64, after: bool) -> Vec<Value> {
    let progress = if semantic_step < CLOCKED_STEPS {
        0
    } else if after {
        (semantic_step - CLOCKED_STEPS + 1).min(EVIDENCE_GAIT_STEPS + 1)
    } else {
        (semantic_step - CLOCKED_STEPS).min(EVIDENCE_GAIT_STEPS + 1)
    };
    limb_ids
        .iter()
        .map(|limb_id| {
            json!({
                "limb_id": limb_id,
                "gait_step": progress,
                "evidence_gait_step_limit": if semantic_step >= CLOCKED_STEPS {
                    Value::from(EVIDENCE_GAIT_STEPS + 1)
                } else {
                    Value::Null
                },
                "release_hold_step_count": 0,
                "recontact_hold_step_count": 0,
                "gate_timeout_count": 0,
                "phase_sync_hold_step_count": 0,
            })
        })
        .collect()
}

fn synthetic_trace_step(
    semantic_step: u64,
    actuator_ids: &[String],
    limb_ids: &[String],
    contact_ids: &[String],
) -> Result<Value, String> {
    let canonical_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, actuator_id)| {
            let stability_delta = if index == 0 {
                if semantic_step == 1 { 0.1 } else { 0.01 }
            } else {
                0.0
            };
            let portable_velocity = if index == 0 && semantic_step == 1 {
                3.5
            } else {
                1.0 + index as f64 * 0.05
            };
            let unbounded = portable_velocity + stability_delta;
            let combined = unbounded.clamp(-3.5, 3.5);
            json!({
                "actuator_id": actuator_id,
                "canonical_speed_saturated": unbounded != combined,
                "clamped_target_position_rad": 0.0,
                "combined_canonical_target_velocity_rad_s": combined,
                "maximum_target_speed_rad_s": 3.5,
                "portable_canonical_residual_contribution_rad_s": 0.0,
                "portable_canonical_safety_contribution_rad_s": 0.0,
                "portable_canonical_target_velocity_rad_s": portable_velocity,
                "position_target_role": "provenance_and_bounds_only",
                "requested_target_position_rad": 0.0,
                "source_legacy_host_target_velocity_rad_s": -portable_velocity,
                "source_legacy_residual_contribution_rad_s": 0.0,
                "source_legacy_safety_contribution_rad_s": 0.0,
                "stability_canonical_velocity_delta_rad_s": stability_delta,
                "unbounded_canonical_target_velocity_rad_s": unbounded,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let canonical = json!({
        "schema_version": "sporespore_canonical_velocity_actuation_frame_v1",
        "profile_id": "sporespore_complete_closed_loop_canonical_velocity_v1",
        "source_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "source_velocity_convention_id": "legacy_godot_host_target_velocity_v1",
        "semantic_step": semantic_step,
        "position_target_role": "provenance_and_bounds_only",
        "load_bearing_actuation": "complete_closed_loop_canonical_target_velocity",
        "canonical_to_host_mapping_owned_by_adapter": true,
        "safe_no_actuation": false,
        "failure_codes": [],
        "ordered_commands": canonical_commands,
        "world_build_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
    });
    let host_commands = canonical["ordered_commands"]
        .as_array()
        .expect("synthetic canonical commands")
        .iter()
        .map(|command| {
            json!({
                "actuator_id": command["actuator_id"],
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "canonical_target_velocity_rad_s": command["combined_canonical_target_velocity_rad_s"],
                "host_target_velocity_rad_s": command["combined_canonical_target_velocity_rad_s"],
                "maximum_host_target_speed_rad_s": 3.5,
                "native_target_position_rad": Value::Null,
                "position_target_role": "provenance_and_bounds_only",
                "host_clamped": false,
                "valid_through_step": semantic_step,
            })
        })
        .collect::<Vec<_>>();
    let mapping = json!({
        "schema_version": "sporespore_velocity_only_host_mapping_receipt_v1",
        "adapter_id": ADAPTER_ID,
        "engine_id": "rapier3d",
        "canonical_profile_id": "sporespore_complete_closed_loop_canonical_velocity_v1",
        "host_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "native_motor_model_id": "force_based_velocity_only",
        "semantic_step": semantic_step,
        "canonical_to_host_velocity_sign": 1.0,
        "native_position_stiffness": 0.0,
        "independent_native_position_feedback_applied": false,
        "safe_no_actuation_preserved": true,
        "host_response_characterized_for_this_profile": true,
        "ordered_commands": host_commands,
        "world_build_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
    });
    let bounded = canonical["ordered_commands"]
        .as_array()
        .expect("synthetic canonical commands")
        .iter()
        .map(|command| {
            json!({
                "actuator_id": command["actuator_id"],
                "applied_position_delta_rad": 0.0,
                "applied_velocity_delta_rad_s": command["stability_canonical_velocity_delta_rad_s"],
                "fallback_zeroed": command["stability_canonical_velocity_delta_rad_s"] == 0.0,
            })
        })
        .collect::<Vec<_>>();
    let base_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, actuator_id)| {
            let velocity = if index == 0 && semantic_step == 1 {
                -3.5
            } else {
                -(1.0 + index as f64 * 0.05)
            };
            json!({
                "actuator_id": actuator_id,
                "requested_target_position_rad": 0.0,
                "clamped_target_position_rad": 0.0,
                "target_velocity_rad_s": velocity,
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
    let motors = mapping["ordered_commands"]
        .as_array()
        .expect("synthetic mapping commands")
        .iter()
        .map(|command| {
            json!({
                "actuator_id": command["actuator_id"],
                "motor_model": "ForceBased",
                "target_position_rad": 0.0,
                "target_velocity_rad_s": command["host_target_velocity_rad_s"],
                "expected_target_velocity_rad_s": command["host_target_velocity_rad_s"],
                "stiffness_nm_per_rad": 0.0,
                "damping_nm_s_per_rad": VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
                "maximum_force_nm": 6.0,
                "motor_impulse_nms": 0.001,
                "small_step_impulse_limit_nms": 0.003125,
                "fields_match": true,
            })
        })
        .collect::<Vec<_>>();
    let planning = json!({
        "schema_version": "sporespore_lc1_synthetic_v4_planning_receipt_v1",
        "semantic_step": semantic_step,
        "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
        "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "canonical_actuation_frame": canonical,
        "rapier_velocity_only_host_mapping": mapping,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    });
    let canonical = planning["canonical_actuation_frame"].clone();
    let mapping = planning["rapier_velocity_only_host_mapping"].clone();
    let canonical_sha = digest_json(&canonical).map_err(|error| error.to_string())?;
    let mapping_sha = digest_json(&mapping).map_err(|error| error.to_string())?;
    let planning_sha = digest_json(&planning).map_err(|error| error.to_string())?;
    Ok(json!({
        "schema_version": TRACE_SCHEMA_VERSION,
        "semantic_step": semantic_step,
        "phase_progression_mode": if semantic_step < CLOCKED_STEPS {
            "clocked"
        } else {
            "contact_gated"
        },
        "command_provenance_recorded_before_application": true,
        "pre_step_snapshot": synthetic_snapshot(semantic_step, contact_ids, false),
        "ordered_limb_controller_memory_before": synthetic_limb_memory(
            limb_ids,
            semantic_step,
            false,
        ),
        "portable_controller_actuation_receipt_sha256": "sha256:synthetic",
        "ordered_portable_base_commands": base_commands,
        "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "v4_composition": {
            "planning_availability": "available",
            "observation_input_available": true,
            "planning_outcome_code": "SYNTHETIC_AVAILABLE",
            "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "v4_planning_and_bounding_receipt_sha256": planning_sha,
            "v4_planning_and_bounding_receipt": planning,
            "ordered_bounded_canonical_residuals": bounded,
            "retained_mixed_space_projection_applied": false,
        },
        "canonical_actuation_frame_sha256": canonical_sha,
        "selected_canonical_actuation_frame": canonical,
        "rapier_host_mapping_sha256": mapping_sha,
        "selected_rapier_host_mapping": mapping,
        "ordered_load_bearing_host_commands": host_commands,
        "ordered_post_step_joint_motor_readbacks_and_impulses": motors,
        "post_step_snapshot": synthetic_snapshot(semantic_step, contact_ids, true),
        "declared_diagnostic_events": [],
        "ordered_limb_controller_memory_after": synthetic_limb_memory(
            limb_ids,
            semantic_step,
            true,
        ),
    }))
}

fn perfect_synthetic_report() -> Result<Value, String> {
    let _declaration = preregistration()?;
    let (compiled, _controller) = compile_declared_boundary()?;
    let actuator_ids = &compiled.morphology.ordered_actuator_ids;
    let limb_ids = &compiled.morphology.ordered_limb_ids;
    let contact_ids = compiled
        .morphology
        .morphology_spec
        .contact_sites
        .iter()
        .map(|site| site.contact_site_id.clone())
        .collect::<Vec<_>>();
    let trace = (0..TOTAL_STEPS)
        .map(|semantic_step| {
            synthetic_trace_step(semantic_step, actuator_ids, limb_ids, &contact_ids)
        })
        .collect::<Result<Vec<_>, _>>()?;
    let evidence_completion_step = CLOCKED_STEPS + EVIDENCE_GAIT_STEPS;
    let evidence_start_x =
        trace[CLOCKED_STEPS as usize]["pre_step_snapshot"]["torso_pose_world"]["position_m"]["x"]
            .as_f64()
            .expect("synthetic evidence start");
    let evidence_end_x = trace[evidence_completion_step as usize]["post_step_snapshot"]
        ["torso_pose_world"]["position_m"]["x"]
        .as_f64()
        .expect("synthetic evidence end");
    let final_x = trace.last().expect("synthetic final")["post_step_snapshot"]["torso_pose_world"]
        ["position_m"]["x"]
        .as_f64()
        .expect("synthetic final x");
    let mut foot_evidence = BTreeMap::<String, FootEvidence>::new();
    for limb in &compiled.morphology.morphology_spec.limbs {
        foot_evidence.insert(limb.limb_id.clone(), FootEvidence::new(true));
    }
    for entry in &trace {
        for limb in &compiled.morphology.morphology_spec.limbs {
            let site_id = &limb.ordered_contact_site_ids[0];
            let contact = entry["post_step_snapshot"]["ordered_declared_contacts"][site_id]
                .as_bool()
                .expect("synthetic contact");
            let position = Vector::new(
                entry["post_step_snapshot"]["ordered_contact_site_positions_m"][site_id]["x"]
                    .as_f64()
                    .expect("synthetic site x") as f32,
                0.0,
                entry["post_step_snapshot"]["ordered_contact_site_positions_m"][site_id]["z"]
                    .as_f64()
                    .expect("synthetic site z") as f32,
            );
            foot_evidence
                .get_mut(&limb.limb_id)
                .expect("synthetic foot evidence")
                .observe(contact, position);
        }
    }
    let limb_evidence = foot_evidence
        .iter()
        .map(|(limb_id, evidence)| {
            (
                limb_id.clone(),
                json!({
                    "contact_cycles": evidence.contact_cycles,
                    "maximum_foot_relocation_m": evidence.maximum_foot_relocation_m,
                    "maximum_airborne_dwell_steps": evidence.maximum_airborne_dwell_steps,
                }),
            )
        })
        .collect::<Map<_, _>>();
    Ok(json!({
        "schema_version": REPORT_SCHEMA_VERSION,
        "ok": true,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "source_commit": "0000000000000000000000000000000000000000",
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "live_integration_raw_sha256": LIVE_INTEGRATION_RAW_SHA256,
        "active_configuration_v2_raw_sha256": ACTIVE_CONFIGURATION_V2_RAW_SHA256,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "eh1_closure_raw_sha256": EH1_CLOSURE_RAW_SHA256,
        "preflight": {
            "ok": true,
            "world_build_count": 0,
            "physical_acceptance_authority": false,
        },
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
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "host_configuration": {
            "motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
            "motor_model": "ForceBased",
            "motor_mode": "velocity_only",
            "native_position_stiffness_nm_per_rad": 0.0,
            "damping_nm_s_per_rad": VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
            "outer_timestep_s": RAPIER_DT_S,
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations": RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "authored_friction": 0.95,
            "terminal_zero_target_settle_steps": 0,
        },
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": 9,
        "joint_count": 8,
        "actuator_count": ACTUATOR_COUNT,
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "composition_error_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
        "motor_model_or_field_readback_mismatch_count": 0,
        "small_step_impulse_limit_violation_count": 0,
        "global_scale_mismatch_count": 0,
        "native_position_target_application_count": 0,
        "selected_control_mapping_mismatch_count": 0,
        "trace_step_count": TOTAL_STEPS,
        "base_command_count": COMMANDS_PER_LAYER,
        "bounded_residual_command_count": COMMANDS_PER_LAYER,
        "canonical_command_count": COMMANDS_PER_LAYER,
        "host_command_count": COMMANDS_PER_LAYER,
        "motor_observation_count": COMMANDS_PER_LAYER,
        "nonzero_bounded_residual_count": TOTAL_STEPS,
        "nonzero_effective_host_residual_count": TOTAL_STEPS - 1,
        "initial_pose_snapshot": synthetic_snapshot(0, &contact_ids, false),
        "initial_declared_diagnostic_events": [],
        "initial_contact_count": ACTUATOR_COUNT / 2,
        "schedule": {
            "zero_target_settle_steps": 0,
            "controller_authority_began_at_semantic_step": 0,
            "total_controller_semantic_steps": TOTAL_STEPS,
            "clocked_steps": CLOCKED_STEPS,
            "contact_gated_start_step": CLOCKED_STEPS,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
            "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
            "evidence_limits_reached": true,
            "evidence_completion_semantic_step": evidence_completion_step,
            "required_post_evidence_steps": REQUIRED_POST_EVIDENCE_STEPS,
            "required_post_evidence_steps_completed": true,
            "terminal_zero_target_settle_steps": 0,
        },
        "metrics": {
            "evidence_forward_displacement_m": evidence_end_x - evidence_start_x,
            "final_forward_displacement_m": final_x,
            "final_lateral_displacement_m": 0.0,
            "final_yaw_drift_rad": 0.0,
            "maximum_tilt_rad": 0.0,
            "minimum_torso_height_m": 0.44,
            "maximum_anchor_error_m": 0.0,
            "maximum_hinge_axis_error_rad": 0.0,
        },
        "terminal_four_contact_stance": true,
        "torso_ground_contact_step_count": 0,
        "limb_evidence": Value::Object(limb_evidence),
        "ordered_trace": trace,
        "gate_failures": [],
        "claim_boundary": claim_boundary(true),
    }))
}

fn rejected_after<F>(report: &Value, mutate: F) -> bool
where
    F: FnOnce(&mut Value),
{
    let mut candidate = report.clone();
    mutate(&mut candidate);
    !full_gate_failures(&candidate).is_empty()
}

pub fn run_bw19v_velocity_only_long_horizon_lc1_preflight() -> Result<Value, String> {
    let declaration = preregistration()?;
    let synthetic = perfect_synthetic_report()?;
    let perfect_failures = full_gate_failures(&synthetic);
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("C6_RAP_V4_LC1_SYNTHETIC_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_V4_LC1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let canaries = vec![
        rejected_after(&synthetic, |report| {
            report["ordered_trace"].as_array_mut().unwrap().pop();
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][1]["semantic_step"] = json!(99);
        }),
        rejected_after(&synthetic, |report| {
            report["selected_policy_id"] = json!("wrong_policy");
        }),
        rejected_after(&synthetic, |report| {
            report["global_requested_correction_scale"] = json!(0.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["production_motor_profile_id"] = json!("invented_profile");
        }),
        rejected_after(&synthetic, |report| {
            report["nonzero_bounded_residual_count"] = json!(0);
        }),
        rejected_after(&synthetic, |report| {
            report["nonzero_effective_host_residual_count"] = json!(0);
        }),
        rejected_after(&synthetic, |report| {
            report["nonzero_effective_host_residual_count"] = json!(TOTAL_STEPS);
        }),
        rejected_after(&synthetic, |report| {
            report["host_configuration"]["native_position_stiffness_nm_per_rad"] = json!(1.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"][0]
                ["motor_model"] = json!("AccelerationBased");
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"][0]
                ["target_velocity_rad_s"] = json!(99.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["ordered_post_step_joint_motor_readbacks_and_impulses"][0]
                ["motor_impulse_nms"] = json!(1.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["ordered_load_bearing_host_commands"]
                .as_array_mut()
                .unwrap()
                .swap(0, 1);
        }),
        rejected_after(&synthetic, |report| {
            report["metrics"]["final_forward_displacement_m"] = json!(0.0);
        }),
        rejected_after(&synthetic, |report| {
            report["limb_evidence"]["front_left"]["contact_cycles"] = json!(0);
        }),
        rejected_after(&synthetic, |report| {
            report["schedule"]["required_post_evidence_steps_completed"] = json!(false);
        }),
        rejected_after(&synthetic, |report| {
            report["claim_boundary"]["release_authorized"] = json!(true);
            report["world_build_count"] = json!(2);
        }),
    ];
    let saturated =
        &synthetic["ordered_trace"][1]["selected_canonical_actuation_frame"]["ordered_commands"][0];
    let saturated_residual_case_passed = saturated["stability_canonical_velocity_delta_rad_s"]
        .as_f64()
        .is_some_and(|value| value != 0.0)
        && saturated["portable_canonical_target_velocity_rad_s"]
            == saturated["combined_canonical_target_velocity_rad_s"]
        && synthetic["nonzero_bounded_residual_count"] == TOTAL_STEPS
        && synthetic["nonzero_effective_host_residual_count"] == TOTAL_STEPS - 1;
    let all_canaries_rejected = canaries.iter().all(|rejected| *rejected);
    let ok = declaration["preflight_contract"]["world_build_count"] == 0
        && VELOCITY_ONLY_LIVE_PROFILE_ID == "rapier_force_based_velocity_only_v1"
        && perfect_failures.is_empty()
        && round_trip == synthetic
        && saturated_residual_case_passed
        && all_canaries_rejected;
    Ok(json!({
        "schema_version": PREFLIGHT_SCHEMA_VERSION,
        "ok": ok,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "production_profile_identity_imported_from_real_mapper": true,
        "synthetic_trace_step_count": TOTAL_STEPS,
        "synthetic_command_count_per_layer": COMMANDS_PER_LAYER,
        "perfect_synthetic_whole_gate_passed": perfect_failures.is_empty(),
        "perfect_synthetic_failures": perfect_failures,
        "positive_saturated_residual_case_passed": saturated_residual_case_passed,
        "synthetic_nonzero_bounded_residual_count": TOTAL_STEPS,
        "synthetic_nonzero_effective_host_residual_count": TOTAL_STEPS - 1,
        "negative_control_count": canaries.len(),
        "all_negative_controls_rejected": all_canaries_rejected,
        "negative_control_results": canaries,
        "serialization_round_trip_passed": round_trip == synthetic,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_synthetic_gate_passes_without_worlds() {
        let report = perfect_synthetic_report().unwrap();
        assert!(full_gate_failures(&report).is_empty());
        assert_eq!(report["preflight"]["world_build_count"], 0);
        assert_eq!(report["nonzero_bounded_residual_count"], TOTAL_STEPS);
        assert_eq!(
            report["nonzero_effective_host_residual_count"],
            TOTAL_STEPS - 1
        );
    }
}
