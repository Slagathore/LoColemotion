use std::collections::BTreeMap;

use rapier3d::prelude::*;
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{PhaseProgressionMode, StateFrame};
use sporespore_locomotion_core::schema::Vec3 as CoreVec3;
use sporespore_locomotion_core::{
    BALANCED_WAVE_BW15F_B_POLICY_ID, BalancedWaveController, BalancedWaveControllerMemory,
    CANONICAL_VELOCITY_RESIDUAL_V1_VERSION, CanonicalVelocityResidualV1, CompiledQuadruped,
    EndpointForceActuatorKinematicsV2, LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
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
    FootEvidence, HostRobot, build_bw19v_velocity_only_v4_robot_with_friction, descriptor,
    motion_command, state_contains_nonfinite,
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
    "../../../cross_engine_c6_bw19v_discrete_material_validation_xv1_preregistration.json"
);
const CROSS_ENGINE_HC_R2_CLOSURE_RAW: &str =
    include_str!("../../../cross_engine_c6_host_characterization_r2_closure.json");
const SPV1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_force_based_selected_configuration_validation_spv1_closure.json"
);
const PH1_CLOSURE_RAW: &str =
    include_str!("../../../rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json");
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
const LC1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json"
);
const TS1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json"
);
const TR1_CLOSURE_RAW: &str = include_str!(
    "../../../rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json"
);

const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:63277890098878651c3a30144b1e4d5e00f15b1a8f95917d202cade4dd46ae2f";
const CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256: &str =
    "sha256:a7b1b3c172b98780f574cec9dbb18bebda35429ece5105a0385ecb7d67d6ddd9";
const SPV1_CLOSURE_RAW_SHA256: &str =
    "sha256:7830f66de49f1d7c2d5b88d151c0c2d5077782903457837d7ecd0da2fb724203";
const PH1_CLOSURE_RAW_SHA256: &str =
    "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db";
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
const LC1_CLOSURE_RAW_SHA256: &str =
    "sha256:526ed77562036f1a5e0a039269a053f154f29ec76903c3709006798a8b848206";
const TS1_CLOSURE_RAW_SHA256: &str =
    "sha256:375fdec1e04efede7beefc80b0fd5a916f201e9b83fb40b572c28c20b9d43891";
const TR1_CLOSURE_RAW_SHA256: &str =
    "sha256:1bb0204dd78733ee5de6b1af95007625e844108fd9246d5ab353fc0aa5e7b127";

pub const CAMPAIGN_ID: &str = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV1";
pub const GATE_ID: &str = "C6-XE-BW19V-XV1";
const REPORT_SCHEMA_VERSION: &str =
    "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_rapier_cell_v1";
const PREFLIGHT_SCHEMA_VERSION: &str =
    "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_rapier_preflight_v1";
const TRACE_SCHEMA_VERSION: &str =
    "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv1_rapier_trace_step_v1";

const RAPIER_MATERIAL_CELLS: [(&str, f64, &str); 3] = [
    ("rapier_mu020", 0.2, "rapier_bw19v_xv1_mu020_v1"),
    ("rapier_mu060", 0.6, "rapier_bw19v_xv1_mu060_v1"),
    ("rapier_mu100", 1.0, "rapier_bw19v_xv1_mu100_v1"),
];

const ACTUATOR_COUNT: usize = 8;
const CLOCKED_STEPS: u64 = 472;
const EVIDENCE_GAIT_STEPS: u64 = 1_440;
const MAXIMUM_EVIDENCE_EXTENSION_STEPS: u64 = 720;
const EVIDENCE_DEADLINE_EXCLUSIVE: u64 =
    CLOCKED_STEPS + EVIDENCE_GAIT_STEPS + MAXIMUM_EVIDENCE_EXTENSION_STEPS;
const GAIT_CYCLE_STEPS: u64 = 360;
const SWING_STEPS: u64 = 72;
const EVIDENCE_LIMIT_GAIT_STEP: u64 = 1_912;
const EVIDENCE_ENDPOINT_GLOBAL_CYCLE_STEP: u64 = 112;
const MAXIMUM_TERMINAL_ACQUISITION_STEPS: u64 = 180;
const TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE: u64 =
    EVIDENCE_DEADLINE_EXCLUSIVE + MAXIMUM_TERMINAL_ACQUISITION_STEPS;
const REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS: u64 = 360;
const TOTAL_STEPS: u64 =
    TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE + REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS;
const COMMANDS_PER_LAYER: u64 = TOTAL_STEPS * ACTUATOR_COUNT as u64;
const CONTACT_RESTORATION_POLICY_ID: &str =
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1";
const CONTACT_RESTORATION_DOWNWARD_SPEED_M_S: f64 = 0.02;
const CONTACT_RESTORATION_DAMPING_LAMBDA_M: f64 = 0.04;
const CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S: f64 = 0.35;
const POSE_HOLD_POSITION_GAIN_PER_S: f64 = 8.0;
const POSE_HOLD_RATE_DAMPING: f64 = 0.65;
const MAXIMUM_ABSOLUTE_STEERING_FRACTION: f64 = 0.40;

const SCHEDULER_ORDERED_LIMB_IDS: [&str; 4] =
    ["rear_left", "front_left", "rear_right", "front_right"];
const MORPHOLOGY_ORDERED_LIMB_IDS: [&str; 4] =
    ["front_left", "front_right", "rear_left", "rear_right"];
const NOMINAL_PHASE_OFFSETS_STEPS: [u64; 4] = [0, 90, 180, 270];
const EVIDENCE_ENDPOINT_LOCAL_PHASE_STEPS: [u64; 4] = [112, 22, 292, 202];

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

fn local_phase_step(gait_step: u64, phase_offset: u64) -> u64 {
    (gait_step + GAIT_CYCLE_STEPS - phase_offset) % GAIT_CYCLE_STEPS
}

fn evidence_schedule_identity_is_exact() -> bool {
    EVIDENCE_LIMIT_GAIT_STEP % GAIT_CYCLE_STEPS == EVIDENCE_ENDPOINT_GLOBAL_CYCLE_STEP
        && NOMINAL_PHASE_OFFSETS_STEPS
            .iter()
            .enumerate()
            .all(|(index, offset)| {
                local_phase_step(EVIDENCE_LIMIT_GAIT_STEP, *offset)
                    == EVIDENCE_ENDPOINT_LOCAL_PHASE_STEPS[index]
            })
}

fn memory_is_at_exact_limit(memory: &BalancedWaveControllerMemory, expected_limit: u64) -> bool {
    memory.ordered_limb_memory.len() == SCHEDULER_ORDERED_LIMB_IDS.len()
        && SCHEDULER_ORDERED_LIMB_IDS.iter().all(|expected_id| {
            let mut matches = memory
                .ordered_limb_memory
                .iter()
                .filter(|limb| limb.limb_id == *expected_id);
            let first = matches.next();
            first.is_some_and(|limb| {
                limb.gait_step == expected_limit
                    && limb.evidence_gait_step_limit == Some(expected_limit)
            }) && matches.next().is_none()
        })
}

fn raw_sha256(raw: &str) -> String {
    format!("sha256:{:x}", Sha256::digest(raw.as_bytes()))
}

fn declared_material_cell(
    cell_id: &str,
    authored_friction: f64,
    material_profile_id: &str,
) -> Result<(), String> {
    if !authored_friction.is_finite() {
        return Err("C6_XE_BW19V_XV1_RAP_AUTHORED_FRICTION_NONFINITE".to_owned());
    }
    let matched = RAPIER_MATERIAL_CELLS.iter().any(|expected| {
        cell_id == expected.0
            && authored_friction.to_bits() == expected.1.to_bits()
            && material_profile_id == expected.2
    });
    if !matched {
        return Err("C6_XE_BW19V_XV1_RAP_MATERIAL_CELL_UNDECLARED".to_owned());
    }
    Ok(())
}

fn preregistration() -> Result<Value, String> {
    for (raw, expected, code) in [
        (
            PREREGISTRATION_RAW,
            PREREGISTRATION_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_PREREGISTRATION_HASH",
        ),
        (
            CROSS_ENGINE_HC_R2_CLOSURE_RAW,
            CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_HC_R2_CLOSURE_HASH",
        ),
        (
            SPV1_CLOSURE_RAW,
            SPV1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_SPV1_CLOSURE_HASH",
        ),
        (
            PH1_CLOSURE_RAW,
            PH1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_PH1_CLOSURE_HASH",
        ),
        (
            LIVE_INTEGRATION_RAW,
            LIVE_INTEGRATION_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_LIVE_INTEGRATION_HASH",
        ),
        (
            ACTIVE_CONFIGURATION_V2_RAW,
            ACTIVE_CONFIGURATION_V2_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_ACTIVE_CONFIGURATION_HASH",
        ),
        (
            CANONICAL_PROFILE_RAW,
            CANONICAL_PROFILE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_CANONICAL_PROFILE_HASH",
        ),
        (
            VH1_CLOSURE_RAW,
            VH1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_VH1_CLOSURE_HASH",
        ),
        (
            C2_CLOSURE_RAW,
            C2_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_C2_CLOSURE_HASH",
        ),
        (
            EH1_CLOSURE_RAW,
            EH1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_EH1_CLOSURE_HASH",
        ),
        (
            LC1_CLOSURE_RAW,
            LC1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_LC1_CLOSURE_HASH",
        ),
        (
            TS1_CLOSURE_RAW,
            TS1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_TS1_CLOSURE_HASH",
        ),
        (
            TR1_CLOSURE_RAW,
            TR1_CLOSURE_RAW_SHA256,
            "C6_XE_BW19V_XV1_RAP_TR1_CLOSURE_HASH",
        ),
    ] {
        if raw_sha256(raw) != expected {
            return Err(code.to_owned());
        }
    }
    let declaration: Value = serde_json::from_str(PREREGISTRATION_RAW)
        .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_PREREGISTRATION_PARSE:{error}"))?;
    if declaration["campaign_id"] != CAMPAIGN_ID
        || declaration["gate_id"] != GATE_ID
        || declaration["status"] != "frozen_before_first_c6_xe_bw19v_xv1_physics_world"
        || declaration["study_class"]["classification"]
            != "exact_finite_cell_independent_cross_engine_material_validation"
        || declaration["study_class"]["finite_decision"] != true
        || declaration["study_class"]["independent_validation"] != true
        || declaration["study_class"]["population_inference"] != false
        || declaration["study_class"]["noninferiority_or_equivalence_study"] != false
        || declaration["matrix"]["expected_world_count"] != 6
        || declaration["matrix"]["ordered_cells"]
            .as_array()
            .is_none_or(|cells| cells.len() != 6)
        || declaration["engine_contracts"]["rapier"]["total_controller_semantic_steps"]
            != TOTAL_STEPS
        || declaration["engine_contracts"]["rapier"]["clocked_steps"] != CLOCKED_STEPS
        || declaration["engine_contracts"]["rapier"]["evidence_gait_steps_per_limb"]
            != EVIDENCE_GAIT_STEPS
        || declaration["engine_contracts"]["rapier"]["maximum_evidence_extension_steps"]
            != MAXIMUM_EVIDENCE_EXTENSION_STEPS
        || declaration["engine_contracts"]["rapier"]["maximum_four_contact_acquisition_steps"]
            != MAXIMUM_TERMINAL_ACQUISITION_STEPS
        || declaration["engine_contracts"]["rapier"]["required_consecutive_all_four_contact_steps"]
            != REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
        || declaration["frozen_portable_identity"]["controller_policy_id"]
            != BW19V_CONTROLLER_POLICY_ID
        || declaration["frozen_portable_identity"]["global_requested_correction_scale"]
            != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
        || declaration["frozen_portable_identity"]["terminal_restoration_policy_id"]
            != CONTACT_RESTORATION_POLICY_ID
        || declaration["engine_contracts"]["rapier"]["motor_profile_id"]
            != VELOCITY_ONLY_LIVE_PROFILE_ID
        || declaration["engine_contracts"]["rapier"]["motor_model"] != "ForceBased"
        || declaration["preflight_contract"]["model_or_world_build_count"] != 0
        || declaration["claims_if_accepted"]["formal_cross_engine_equivalence"] != false
        || declaration["claims_if_accepted"]["physical_acceptance_authority"] != false
    {
        return Err("C6_XE_BW19V_XV1_RAP_PREREGISTRATION_CONTRACT".to_owned());
    }
    let cells = declaration["matrix"]["ordered_cells"]
        .as_array()
        .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_MATRIX_MISSING".to_owned())?;
    for (index, expected) in RAPIER_MATERIAL_CELLS.iter().enumerate() {
        if cells[index]["ordinal"] != (index + 1) as u64
            || cells[index]["cell_id"] != expected.0
            || cells[index]["engine"] != "rapier"
            || cells[index]["engine_version"] != rapier3d::VERSION
            || cells[index]["authored_sliding_friction"] != expected.1
            || cells[index]["authored_friction_vector"] != json!([expected.1])
            || cells[index]["material_profile_id"] != expected.2
            || cells[index]["inherited_worker_contract"] != "PH1"
        {
            return Err("C6_XE_BW19V_XV1_RAP_MATRIX_BINDING".to_owned());
        }
    }
    for (pointer, expected) in [
        (
            "/bound_authorities/cross_engine_host_characterization_r2/raw_sha256",
            CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256,
        ),
        (
            "/bound_authorities/rapier_selected_configuration_validation_spv1/raw_sha256",
            SPV1_CLOSURE_RAW_SHA256,
        ),
        (
            "/bound_authorities/rapier_velocity_only_host_characterization_vh1/raw_sha256",
            VH1_CLOSURE_RAW_SHA256,
        ),
        (
            "/bound_authorities/rapier_pose_hold_restoration_ph1/raw_sha256",
            PH1_CLOSURE_RAW_SHA256,
        ),
    ] {
        if declaration
            .pointer(pointer)
            .and_then(Value::as_str)
            .is_none_or(|actual| Some(actual) != expected.strip_prefix("sha256:"))
        {
            return Err("C6_XE_BW19V_XV1_RAP_BOUND_AUTHORITY".to_owned());
        }
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
        || controller.profile().yaw_error_stride_gain_per_rad != 1.3
        || controller
            .profile()
            .steering_low_pass_time_constant_cycle_fraction
            != Some(1.0 / 16.0)
        || controller.profile().steering_stride_transform_id.is_some()
        || runtime_sha != BW19V_S169_RUNTIME_PROFILE_SHA256
    {
        return Err("C6_XE_BW19V_XV1_RAP_PORTABLE_IDENTITY".to_owned());
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
                .ok_or_else(|| format!("C6_XE_BW19V_XV1_RAP_LIMB_MEMORY_MISSING:{limb_id}"))
        })
        .collect()
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
        return Err("C6_XE_BW19V_XV1_RAP_SELECTED_CONTROL_COMMAND_COUNT".to_owned());
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
            .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_ACTUATOR_MAPPING_MISSING".to_owned())?;
        let joint = robot
            .world
            .impulse_joints
            .get(robot.joints[joint_id])
            .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_JOINT_MISSING".to_owned())?;
        let motor = joint
            .data
            .as_revolute()
            .and_then(|revolute| revolute.motor())
            .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_MOTOR_MISSING".to_owned())?;
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

struct ContactRestorationComposition {
    canonical_actuation: sporespore_locomotion_core::CanonicalVelocityActuationFrameV1,
    host_mapping: VelocityOnlyHostMappingReceiptV1,
    ordered_residuals: Vec<CanonicalVelocityResidualV1>,
    receipt: Value,
}

#[derive(Default)]
struct PoseHoldRestorationMemory {
    activation_held_steering_fraction: Option<f64>,
    neutral_joint_position_by_actuator: BTreeMap<String, f64>,
}

struct PortableHeadingTargetDelta {
    delta_rad: f64,
    lateral_side_sign: Option<f64>,
    forward_velocity_correction_rad: Option<f64>,
    nominal_unsteered_hip_target_rad: Option<f64>,
}

fn vec3_sub(left: CoreVec3, right: CoreVec3) -> CoreVec3 {
    CoreVec3 {
        x: left.x - right.x,
        y: left.y - right.y,
        z: left.z - right.z,
    }
}

fn vec3_cross(left: CoreVec3, right: CoreVec3) -> CoreVec3 {
    CoreVec3 {
        x: left.y * right.z - left.z * right.y,
        y: left.z * right.x - left.x * right.z,
        z: left.x * right.y - left.y * right.x,
    }
}

fn vec3_dot(left: CoreVec3, right: CoreVec3) -> f64 {
    left.x * right.x + left.y * right.y + left.z * right.z
}

fn portable_heading_target_delta(
    base_actuation: &sporespore_locomotion_core::ActuationFrame,
    command: &sporespore_locomotion_core::ActuatorCommand,
    limb_id: &str,
    joint_id: &str,
    activation_held_steering_fraction: f64,
) -> Result<PortableHeadingTargetDelta, String> {
    if !joint_id.ends_with("_hip") {
        return Ok(PortableHeadingTargetDelta {
            delta_rad: 0.0,
            lateral_side_sign: None,
            forward_velocity_correction_rad: None,
            nominal_unsteered_hip_target_rad: None,
        });
    }
    let current_held = base_actuation.receipt.held_steering_fraction;
    if !current_held.is_finite()
        || current_held.abs() > MAXIMUM_ABSOLUTE_STEERING_FRACTION
        || !activation_held_steering_fraction.is_finite()
        || activation_held_steering_fraction.abs() > MAXIMUM_ABSOLUTE_STEERING_FRACTION
    {
        return Err("C6_XE_BW19V_XV1_RAP_HEADING_STEERING_FRACTION_INVALID".to_owned());
    }
    let forward = base_actuation
        .receipt
        .forward_velocity_foot_placement
        .as_ref()
        .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_FORWARD_RECEIPT_MISSING".to_owned())?;
    let mut matches = forward
        .ordered_limb_corrections
        .iter()
        .filter(|correction| correction.limb_id == limb_id);
    let correction = matches
        .next()
        .ok_or_else(|| format!("C6_XE_BW19V_XV1_RAP_FORWARD_LIMB_MISSING:{limb_id}"))?;
    if matches.next().is_some() {
        return Err(format!(
            "C6_XE_BW19V_XV1_RAP_FORWARD_LIMB_DUPLICATE:{limb_id}"
        ));
    }
    let side_sign = if limb_id.ends_with("_right") {
        1.0
    } else if limb_id.ends_with("_left") {
        -1.0
    } else {
        return Err(format!(
            "C6_XE_BW19V_XV1_RAP_LATERAL_SIDE_UNKNOWN:{limb_id}"
        ));
    };
    let denominator = 1.0 + side_sign * current_held;
    if !denominator.is_finite() || denominator <= 0.0 {
        return Err(format!(
            "C6_XE_BW19V_XV1_RAP_STEERING_DENOMINATOR:{limb_id}"
        ));
    }
    let nominal_unsteered_hip_target_rad = (command.requested_target_position_rad
        - correction.applied_hip_target_correction_rad)
        / denominator;
    let delta_rad = nominal_unsteered_hip_target_rad
        * side_sign
        * (current_held - activation_held_steering_fraction);
    if !nominal_unsteered_hip_target_rad.is_finite() || !delta_rad.is_finite() {
        return Err(format!(
            "C6_XE_BW19V_XV1_RAP_HEADING_DELTA_NONFINITE:{limb_id}"
        ));
    }
    Ok(PortableHeadingTargetDelta {
        delta_rad,
        lateral_side_sign: Some(side_sign),
        forward_velocity_correction_rad: Some(correction.applied_hip_target_correction_rad),
        nominal_unsteered_hip_target_rad: Some(nominal_unsteered_hip_target_rad),
    })
}

fn contact_restoration_composition(
    compiled: &CompiledQuadruped,
    base_actuation: &sporespore_locomotion_core::ActuationFrame,
    state: &StateFrame,
    pre_step_contacts: &BTreeMap<String, bool>,
    ordered_kinematics: &[EndpointForceActuatorKinematicsV2],
    memory: &mut PoseHoldRestorationMemory,
) -> Result<ContactRestorationComposition, String> {
    if ordered_kinematics.len() != compiled.morphology.ordered_actuator_ids.len()
        || ordered_kinematics
            .iter()
            .zip(&compiled.morphology.ordered_actuator_ids)
            .any(|(kinematics, actuator_id)| kinematics.actuator_id != *actuator_id)
    {
        return Err("C6_XE_BW19V_XV1_RAP_RESTORATION_KINEMATIC_ORDER".to_owned());
    }

    let current_held_steering_fraction = base_actuation.receipt.held_steering_fraction;
    let activation_held_steering_fraction = *memory
        .activation_held_steering_fraction
        .get_or_insert(current_held_steering_fraction);
    let joint_observation_by_id = state
        .ordered_joint_observations
        .iter()
        .map(|observation| (observation.joint_id.as_str(), observation))
        .collect::<BTreeMap<_, _>>();
    let base_command_by_actuator = base_actuation
        .ordered_commands
        .iter()
        .map(|command| (command.actuator_id.as_str(), command))
        .collect::<BTreeMap<_, _>>();
    let actuator_by_id = compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .map(|actuator| (actuator.actuator_id.as_str(), actuator))
        .collect::<BTreeMap<_, _>>();

    let desired_foot_velocity = CoreVec3 {
        x: 0.0,
        y: -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S,
        z: 0.0,
    };
    let lambda_squared =
        CONTACT_RESTORATION_DAMPING_LAMBDA_M * CONTACT_RESTORATION_DAMPING_LAMBDA_M;
    let mut desired_joint_velocity_by_actuator = BTreeMap::<String, f64>::new();
    let mut ordered_limb_solutions =
        Vec::with_capacity(compiled.morphology.morphology_spec.limbs.len());

    for limb in &compiled.morphology.morphology_spec.limbs {
        if limb.ordered_joint_ids.len() != 2 || limb.ordered_contact_site_ids.len() != 1 {
            return Err(format!(
                "C6_XE_BW19V_XV1_RAP_RESTORATION_LIMB_CARDINALITY:{}",
                limb.limb_id
            ));
        }
        let contact_site_id = &limb.ordered_contact_site_ids[0];
        let contact = *pre_step_contacts.get(contact_site_id).ok_or_else(|| {
            format!("C6_XE_BW19V_XV1_RAP_RESTORATION_CONTACT_MISSING:{contact_site_id}")
        })?;
        let limb_kinematics = ordered_kinematics
            .iter()
            .filter(|kinematics| kinematics.contact_site_id == *contact_site_id)
            .collect::<Vec<_>>();
        if limb_kinematics.len() != 2 {
            return Err(format!(
                "C6_XE_BW19V_XV1_RAP_RESTORATION_KINEMATIC_CARDINALITY:{}",
                limb.limb_id
            ));
        }
        let columns = limb_kinematics
            .iter()
            .map(|kinematics| {
                vec3_cross(
                    kinematics.joint_axis_world_unit,
                    vec3_sub(kinematics.endpoint_world_m, kinematics.joint_anchor_world_m),
                )
            })
            .collect::<Vec<_>>();
        let missing_limb_solution = if contact {
            None
        } else {
            let a00 = vec3_dot(columns[0], columns[0]) + lambda_squared;
            let a01 = vec3_dot(columns[0], columns[1]);
            let a11 = vec3_dot(columns[1], columns[1]) + lambda_squared;
            let b0 = vec3_dot(columns[0], desired_foot_velocity);
            let b1 = vec3_dot(columns[1], desired_foot_velocity);
            let determinant = a00 * a11 - a01 * a01;
            if !determinant.is_finite() || determinant <= 0.0 {
                return Err(format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_DLS_SINGULAR:{}",
                    limb.limb_id
                ));
            }
            let raw = [
                (b0 * a11 - a01 * b1) / determinant,
                (a00 * b1 - a01 * b0) / determinant,
            ];
            if raw.iter().any(|value| !value.is_finite()) {
                return Err(format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_DLS_NONFINITE:{}",
                    limb.limb_id
                ));
            }
            Some(raw)
        };
        let mut actuator_solutions = Vec::with_capacity(2);
        for index in 0..2 {
            let actuator_id = &limb_kinematics[index].actuator_id;
            let actuator = *actuator_by_id.get(actuator_id.as_str()).ok_or_else(|| {
                format!("C6_XE_BW19V_XV1_RAP_RESTORATION_ACTUATOR_MISSING:{actuator_id}")
            })?;
            let observation = *joint_observation_by_id
                .get(actuator.joint_id.as_str())
                .ok_or_else(|| {
                    format!(
                        "C6_XE_BW19V_XV1_RAP_RESTORATION_JOINT_OBSERVATION_MISSING:{}",
                        actuator.joint_id
                    )
                })?;
            let measured_position_rad = observation.position_rad.ok_or_else(|| {
                format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_POSITION_MISSING:{}",
                    actuator.joint_id
                )
            })?;
            let measured_velocity_rad_s = observation.velocity_rad_s.ok_or_else(|| {
                format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_VELOCITY_MISSING:{}",
                    actuator.joint_id
                )
            })?;
            let base_command = *base_command_by_actuator
                .get(actuator_id.as_str())
                .ok_or_else(|| {
                    format!("C6_XE_BW19V_XV1_RAP_RESTORATION_BASE_COMMAND_MISSING:{actuator_id}")
                })?;
            let heading = portable_heading_target_delta(
                base_actuation,
                base_command,
                &limb.limb_id,
                &actuator.joint_id,
                activation_held_steering_fraction,
            )?;
            let (
                pose_capture_activated,
                neutral_joint_position_rad,
                requested_pose_target_position_rad,
                clamped_pose_target_position_rad,
                unbounded_joint_velocity_rad_s,
                desired_joint_velocity_rad_s,
            ) = if let Some(raw) = missing_limb_solution {
                memory
                    .neutral_joint_position_by_actuator
                    .remove(actuator_id.as_str());
                let bounded = raw[index].clamp(
                    -CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                    CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                );
                (false, None, None, None, raw[index], bounded)
            } else {
                let pose_capture_activated = !memory
                    .neutral_joint_position_by_actuator
                    .contains_key(actuator_id.as_str());
                if pose_capture_activated {
                    memory.neutral_joint_position_by_actuator.insert(
                        actuator_id.clone(),
                        measured_position_rad - heading.delta_rad,
                    );
                }
                let neutral = memory.neutral_joint_position_by_actuator[actuator_id.as_str()];
                let requested = neutral + heading.delta_rad;
                let clamped = requested.clamp(
                    actuator.minimum_target_position_rad,
                    actuator.maximum_target_position_rad,
                );
                let raw = POSE_HOLD_POSITION_GAIN_PER_S * (clamped - measured_position_rad)
                    - POSE_HOLD_RATE_DAMPING * measured_velocity_rad_s;
                let bounded = raw.clamp(
                    -CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                    CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                );
                (
                    pose_capture_activated,
                    Some(neutral),
                    Some(requested),
                    Some(clamped),
                    raw,
                    bounded,
                )
            };
            desired_joint_velocity_by_actuator
                .insert(actuator_id.clone(), desired_joint_velocity_rad_s);
            actuator_solutions.push(json!({
                "actuator_id": actuator_id,
                "joint_id": actuator.joint_id,
                "kinematics": limb_kinematics[index],
                "linear_jacobian_column_world_m": columns[index],
                "measured_joint_position_rad": measured_position_rad,
                "measured_joint_velocity_rad_s": measured_velocity_rad_s,
                "pose_capture_activated": pose_capture_activated,
                "neutral_joint_position_rad": neutral_joint_position_rad,
                "portable_lateral_side_sign": heading.lateral_side_sign,
                "portable_forward_velocity_hip_target_correction_rad":
                    heading.forward_velocity_correction_rad,
                "portable_nominal_unsteered_hip_target_rad":
                    heading.nominal_unsteered_hip_target_rad,
                "portable_heading_target_delta_rad": heading.delta_rad,
                "requested_pose_target_position_rad": requested_pose_target_position_rad,
                "clamped_pose_target_position_rad": clamped_pose_target_position_rad,
                "unbounded_joint_velocity_rad_s": unbounded_joint_velocity_rad_s,
                "desired_joint_velocity_rad_s": desired_joint_velocity_rad_s,
            }));
        }
        ordered_limb_solutions.push(json!({
            "limb_id": limb.limb_id,
            "contact_site_id": contact_site_id,
            "pre_step_contact": contact,
            "desired_foot_velocity_world_m_s": if contact { CoreVec3::ZERO } else { desired_foot_velocity },
            "ordered_actuator_solutions": actuator_solutions,
        }));
    }

    let mut ordered_residuals = Vec::with_capacity(base_actuation.ordered_commands.len());
    for command in &base_actuation.ordered_commands {
        let desired_joint_velocity = *desired_joint_velocity_by_actuator
            .get(&command.actuator_id)
            .ok_or_else(|| {
                format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_ACTUATOR_SOLUTION_MISSING:{}",
                    command.actuator_id
                )
            })?;
        let portable_canonical_velocity =
            command.target_velocity_rad_s * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        ordered_residuals.push(CanonicalVelocityResidualV1 {
            schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
            actuator_id: command.actuator_id.clone(),
            canonical_velocity_delta_rad_s: desired_joint_velocity - portable_canonical_velocity,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    for ((canonical, host), desired) in canonical_actuation
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
        .zip(
            compiled
                .morphology
                .ordered_actuator_ids
                .iter()
                .map(|actuator_id| desired_joint_velocity_by_actuator[actuator_id]),
        )
    {
        if !close(
            canonical.combined_canonical_target_velocity_rad_s,
            desired,
            1.0e-12,
        ) || !close(host.host_target_velocity_rad_s, desired, 1.0e-12)
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "C6_XE_BW19V_XV1_RAP_RESTORATION_MAPPING_MISMATCH:{}",
                canonical.actuator_id
            ));
        }
    }
    let receipt = json!({
        "schema_version": "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1",
        "semantic_step": base_actuation.semantic_step,
        "policy_id": CONTACT_RESTORATION_POLICY_ID,
        "missing_limb_desired_foot_velocity_world_m_s": desired_foot_velocity,
        "contacting_limb_target_joint_velocity_mode":
            "captured_pose_proportional_derivative_velocity_v1",
        "pose_hold_position_gain_per_s": POSE_HOLD_POSITION_GAIN_PER_S,
        "pose_hold_rate_damping": POSE_HOLD_RATE_DAMPING,
        "maximum_absolute_pose_hold_joint_velocity_rad_s":
            CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
        "heading_correction_mode":
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1",
        "activation_held_steering_fraction": activation_held_steering_fraction,
        "current_held_steering_fraction": current_held_steering_fraction,
        "registered_steering_stride_transform_id": Value::Null,
        "damped_least_squares_lambda_m": CONTACT_RESTORATION_DAMPING_LAMBDA_M,
        "maximum_absolute_search_joint_velocity_rad_s":
            CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
        "ordered_limb_solutions": ordered_limb_solutions,
        "pose_memory_actuator_count": memory.neutral_joint_position_by_actuator.len(),
        "world_build_count": 0,
        "physics_state_modified": false,
        "command_not_measurement": true,
        "physical_acceptance_authority": false,
    });
    Ok(ContactRestorationComposition {
        canonical_actuation,
        host_mapping,
        ordered_residuals,
        receipt,
    })
}

fn claim_boundary(cell_contract_passed: bool) -> Value {
    json!({
        "exact_s169_rapier_xv1_engine_native_cell_contract": cell_contract_passed,
        "finite_single_body_walking_contract": cell_contract_passed,
        "aggregate_six_cell_validation": false,
        "independent_validation": false,
        "population_inference": false,
        "rapier_release_selected_same_policy_physical_c6": false,
        "different_physics_engines_have_same_policy_exact_finite_validation": false,
        "bounded_discrete_material_validation": false,
        "formal_cross_engine_equivalence": false,
        "trajectory_equivalence": false,
        "arbitrary_quadruped_coverage": false,
        "continuous_full_volume_coverage": false,
        "continuous_friction_coverage": false,
        "arbitrary_material_robustness": false,
        "rough_terrain_robustness": false,
        "external_push_recovery": false,
        "sensor_noise_or_latency_robustness": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    })
}

fn declared_schedule(
    evidence_completion_step: Option<u64>,
    restoration_activation_step: Option<u64>,
    first_four_contact_acquisition_step: Option<u64>,
    consecutive_four_contact_completion_step: Option<u64>,
    maximum_consecutive_four_contact_steps: u64,
) -> Value {
    json!({
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
        "terminal_restoration_phase": {
            "scheduler_ordered_limb_ids": SCHEDULER_ORDERED_LIMB_IDS,
            "nominal_phase_offsets_steps": NOMINAL_PHASE_OFFSETS_STEPS,
            "gait_cycle_steps": GAIT_CYCLE_STEPS,
            "swing_steps": SWING_STEPS,
            "frozen_evidence_limit_gait_step": EVIDENCE_LIMIT_GAIT_STEP,
            "frozen_evidence_endpoint_global_cycle_step": EVIDENCE_ENDPOINT_GLOBAL_CYCLE_STEP,
            "frozen_evidence_endpoint_local_phase_steps":
                EVIDENCE_ENDPOINT_LOCAL_PHASE_STEPS,
            "gait_memory_frozen_at_evidence_limit": true,
            "restoration_policy_id": CONTACT_RESTORATION_POLICY_ID,
            "contacting_limb_target_joint_velocity_mode":
                "captured_pose_proportional_derivative_velocity_v1",
            "pose_hold_position_gain_per_s": POSE_HOLD_POSITION_GAIN_PER_S,
            "pose_hold_rate_damping": POSE_HOLD_RATE_DAMPING,
            "maximum_absolute_pose_hold_joint_velocity_rad_s":
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            "heading_correction_mode":
                "registered_portable_yaw_only_hip_target_delta_from_activation_v1",
            "heading_gain_or_filter_changed": false,
            "missing_limb_desired_foot_velocity_world_m_s":
                [0.0, -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S, 0.0],
            "damped_least_squares_lambda_m": CONTACT_RESTORATION_DAMPING_LAMBDA_M,
            "maximum_absolute_search_joint_velocity_rad_s":
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            "maximum_four_contact_acquisition_steps_after_evidence_completion":
                MAXIMUM_TERMINAL_ACQUISITION_STEPS,
            "terminal_acquisition_deadline_step_exclusive":
                TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE,
            "required_consecutive_all_four_contact_steps":
                REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS,
            "hold_counter_resets_on_any_contact_loss": true,
            "activation_semantic_step": restoration_activation_step,
            "first_four_contact_acquisition_semantic_step":
                first_four_contact_acquisition_step,
            "consecutive_four_contact_completion_semantic_step":
                consecutive_four_contact_completion_step,
            "maximum_consecutive_four_contact_steps":
                maximum_consecutive_four_contact_steps,
            "required_consecutive_hold_completed":
                consecutive_four_contact_completion_step.is_some()
                    && maximum_consecutive_four_contact_steps
                        >= REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS,
        },
        "required_post_terminal_steps": REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS,
        "terminal_zero_target_settle_steps": 0,
    })
}

fn run_physical_report(
    source_commit: &str,
    cell_id: &str,
    authored_friction: f64,
    material_profile_id: &str,
) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("C6_XE_BW19V_XV1_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    declared_material_cell(cell_id, authored_friction, material_profile_id)?;
    let preflight = run_cross_engine_discrete_material_validation_xv1_rapier_preflight()?;
    if preflight["ok"] != true {
        return Err("C6_XE_BW19V_XV1_RAP_PREFLIGHT_FAILED".to_owned());
    }
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot =
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, authored_friction as f32)?;
    let task_origin = robot.torso_position();
    let initial_state = robot.state_frame(&compiled, 0, task_origin)?;
    let initial_snapshot = snapshot(&robot, &compiled, &initial_state)?;
    let initial_events = events_from_snapshot(&initial_snapshot.value)
        .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_INITIAL_SNAPSHOT_INVALID".to_owned())?;
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
    let mut restoration_memory = PoseHoldRestorationMemory::default();
    let mut trace = Vec::with_capacity(TOTAL_STEPS as usize);
    let mut evidence_start = None::<Vector>;
    let mut evidence_end = None::<Vector>;
    let mut evidence_completion_step = None::<u64>;
    let mut restoration_activation_step = None::<u64>;
    let mut first_four_contact_acquisition_step = None::<u64>;
    let mut consecutive_four_contact_completion_step = None::<u64>;
    let mut consecutive_four_contact_steps = 0_u64;
    let mut maximum_consecutive_four_contact_steps = 0_u64;

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
        let campaign_phase = if semantic_step < CLOCKED_STEPS {
            "clocked_walking"
        } else if evidence_completion_step.is_none() {
            "evidence_walking"
        } else if consecutive_four_contact_completion_step.is_none() {
            "terminal_acquisition"
        } else {
            "terminal_hold"
        };
        let state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let pre_snapshot = snapshot(&robot, &compiled, &state)?;
        let pre_step_contacts = robot.contacts(&compiled);
        let pre_step_joint_observations =
            serde_json::to_value(&state.ordered_joint_observations)
                .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_PRE_JOINT_SERIALIZE:{error}"))?;
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
            .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_ACTUATION_INVALID:{error}"))?;
        let base_commands = output
            .actuation
            .ordered_commands
            .iter()
            .map(base_command_json)
            .collect::<Vec<_>>();
        base_command_count += base_commands.len() as u64;
        let controller_actuation_sha256 =
            digest_serializable(&output.actuation).map_err(|error| error.to_string())?;

        let (canonical_actuation, host_mapping, command_composition) =
            if evidence_completion_step.is_none() {
                let composition = compose_bw19v_step_v4(
                    &compiled,
                    &output.actuation,
                    stability_state,
                    kinematics,
                    limb_steps,
                    &mut composition_memory,
                )
                .map_err(|error| {
                    format!("C6_XE_BW19V_XV1_RAP_COMPOSITION_FAILED:{semantic_step}:{error}")
                })?;
                if composition
                    .planning_receipt
                    .stability_influence
                    .global_requested_correction_scale
                    != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
                {
                    global_scale_mismatch_count += 1;
                }
                let ordered_residuals = composition
                    .canonical_actuation
                    .ordered_commands
                    .iter()
                    .map(|command| CanonicalVelocityResidualV1 {
                        schema_version: CANONICAL_VELOCITY_RESIDUAL_V1_VERSION.to_owned(),
                        actuator_id: command.actuator_id.clone(),
                        canonical_velocity_delta_rad_s: command
                            .stability_canonical_velocity_delta_rad_s,
                        command_not_measurement: true,
                        physical_acceptance_authority: false,
                    })
                    .collect::<Vec<_>>();
                let receipt = composition.to_json();
                let receipt_sha256 = digest_json(&receipt).map_err(|error| error.to_string())?;
                let command_composition = json!({
                    "mode": "walking_v4",
                    "receipt_sha256": receipt_sha256,
                    "receipt": receipt,
                    "ordered_canonical_residuals": ordered_residuals,
                    "retained_mixed_space_projection_applied": false,
                });
                (
                    composition.canonical_actuation,
                    composition.host_mapping,
                    command_composition,
                )
            } else {
                let composition = contact_restoration_composition(
                    &compiled,
                    &output.actuation,
                    &state,
                    &pre_step_contacts,
                    &kinematics,
                    &mut restoration_memory,
                )
                .map_err(|error| {
                    format!("C6_XE_BW19V_XV1_RAP_RESTORATION_FAILED:{semantic_step}:{error}")
                })?;
                let receipt_sha256 =
                    digest_json(&composition.receipt).map_err(|error| error.to_string())?;
                let command_composition = json!({
                    "mode": "terminal_pose_hold_restoration_v1",
                    "receipt_sha256": receipt_sha256,
                    "receipt": composition.receipt,
                    "ordered_canonical_residuals": composition.ordered_residuals,
                    "retained_mixed_space_projection_applied": false,
                });
                (
                    composition.canonical_actuation,
                    composition.host_mapping,
                    command_composition,
                )
            };
        let ordered_residual_count = command_composition["ordered_canonical_residuals"]
            .as_array()
            .map_or(0, Vec::len) as u64;
        bounded_residual_command_count += ordered_residual_count;
        nonzero_bounded_residual_count += count_nonzero_bounded(&canonical_actuation);
        let (_control_canonical, control_mapping) = map_bw19v_velocity_only_v4(
            &compiled,
            &output.actuation,
            &zero_residuals(&output.actuation),
        )?;
        let (effective, mapping_mismatches) =
            count_effective_host_residuals(&host_mapping, &control_mapping)?;
        nonzero_effective_host_residual_count += effective;
        selected_control_mapping_mismatch_count += mapping_mismatches;
        native_position_target_application_count += host_mapping
            .ordered_commands
            .iter()
            .filter(|command| command.native_target_position_rad.is_some())
            .count() as u64;
        canonical_command_count += canonical_actuation.ordered_commands.len() as u64;
        host_command_count += host_mapping.ordered_commands.len() as u64;
        let canonical_actuation_sha256 =
            digest_serializable(&canonical_actuation).map_err(|error| error.to_string())?;
        let host_mapping_sha256 =
            digest_serializable(&host_mapping).map_err(|error| error.to_string())?;

        let (applications, apply_impulse_violations) =
            robot.apply_bw19v_velocity_only_v4_actuation(&host_mapping)?;
        actuator_application_mismatch_count += u64::from(applications != ACTUATOR_COUNT as u64);
        let post_state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        let post_step_joint_observations =
            serde_json::to_value(&post_state.ordered_joint_observations)
                .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_POST_JOINT_SERIALIZE:{error}"))?;
        let post_snapshot = snapshot(&robot, &compiled, &post_state)?;
        nonfinite_observation_count += u64::from(post_snapshot.nonfinite);
        let events = events_from_snapshot(&post_snapshot.value)
            .ok_or_else(|| format!("C6_XE_BW19V_XV1_RAP_POST_SNAPSHOT_INVALID:{semantic_step}"))?;
        let (motor_readbacks, field_mismatches, observed_impulse_violations, motor_nonfinite) =
            motor_observations(&robot, &host_mapping)?;
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
            "campaign_phase": campaign_phase,
            "phase_progression_mode": if phase_mode == PhaseProgressionMode::Clocked {
                "clocked"
            } else {
                "contact_gated"
            },
            "command_provenance_recorded_before_application": true,
            "pre_step_snapshot": pre_snapshot.value,
            "ordered_pre_step_joint_position_velocity_observations":
                pre_step_joint_observations,
            "ordered_limb_controller_memory_before": memory_before,
            "portable_controller_actuation_receipt_sha256": controller_actuation_sha256,
            "ordered_portable_base_commands": base_commands,
            "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
            "command_composition": command_composition,
            "canonical_actuation_frame_sha256": canonical_actuation_sha256,
            "selected_canonical_actuation_frame": canonical_actuation,
            "rapier_host_mapping_sha256": host_mapping_sha256,
            "selected_rapier_host_mapping": host_mapping,
            "ordered_load_bearing_host_commands": host_mapping.ordered_commands,
            "ordered_post_step_joint_motor_readbacks_and_impulses": motor_readbacks,
            "post_step_snapshot": post_snapshot.value,
            "ordered_post_step_joint_position_velocity_observations":
                post_step_joint_observations,
            "declared_diagnostic_events": events,
            "ordered_limb_controller_memory_after": memory_after,
        }));
        memory = next_memory;
        if evidence_completion_step.is_none()
            && semantic_step >= CLOCKED_STEPS
            && memory_is_at_exact_limit(&memory, EVIDENCE_LIMIT_GAIT_STEP)
        {
            evidence_completion_step = Some(semantic_step);
            evidence_end = Some(robot.torso_position());
            restoration_activation_step = semantic_step.checked_add(1);
        } else if evidence_completion_step.is_some() {
            if !memory_is_at_exact_limit(&memory, EVIDENCE_LIMIT_GAIT_STEP) {
                return Err(format!(
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_MEMORY_NOT_FROZEN:{semantic_step}"
                ));
            }
            let all_four_contacts = robot.contacts(&compiled).values().all(|contact| *contact);
            if all_four_contacts {
                first_four_contact_acquisition_step.get_or_insert(semantic_step);
                consecutive_four_contact_steps += 1;
                maximum_consecutive_four_contact_steps =
                    maximum_consecutive_four_contact_steps.max(consecutive_four_contact_steps);
                if consecutive_four_contact_steps == REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
                    && consecutive_four_contact_completion_step.is_none()
                {
                    consecutive_four_contact_completion_step = Some(semantic_step);
                }
            } else {
                consecutive_four_contact_steps = 0;
            }
        }
    }

    let final_position = robot.torso_position();
    let final_delta = final_position - task_origin;
    let evidence_delta = evidence_end
        .zip(evidence_start)
        .map(|(end, start)| end - start);
    let terminal_contacts = robot.contacts(&compiled);
    let terminal_four_contact_stance = terminal_contacts.values().all(|contact| *contact);
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
        "study_class": "exact_finite_cell_independent_cross_engine_material_validation",
        "cell_id": cell_id,
        "material_profile_id": material_profile_id,
        "authored_sliding_friction": authored_friction,
        "authored_friction_vector": [authored_friction],
        "inherited_worker_contract": "PH1",
        "source_commit": source_commit.to_ascii_lowercase(),
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "cross_engine_host_characterization_r2_closure_raw_sha256":
            CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256,
        "rapier_spv1_closure_raw_sha256": SPV1_CLOSURE_RAW_SHA256,
        "rapier_ph1_closure_raw_sha256": PH1_CLOSURE_RAW_SHA256,
        "live_integration_raw_sha256": LIVE_INTEGRATION_RAW_SHA256,
        "active_configuration_v2_raw_sha256": ACTIVE_CONFIGURATION_V2_RAW_SHA256,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "eh1_closure_raw_sha256": EH1_CLOSURE_RAW_SHA256,
        "lc1_closure_raw_sha256": LC1_CLOSURE_RAW_SHA256,
        "ts1_closure_raw_sha256": TS1_CLOSURE_RAW_SHA256,
        "tr1_closure_raw_sha256": TR1_CLOSURE_RAW_SHA256,
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
            "authored_friction": authored_friction,
            "authored_friction_vector": [authored_friction],
            "material_profile_id": material_profile_id,
            "ground_and_every_robot_collider_use_same_friction": true,
            "friction_combine_rule": "min",
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
        "schedule": declared_schedule(
            evidence_completion_step,
            restoration_activation_step,
            first_four_contact_acquisition_step,
            consecutive_four_contact_completion_step,
            maximum_consecutive_four_contact_steps,
        ),
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

pub fn run_cross_engine_discrete_material_validation_xv1_rapier(
    source_commit: &str,
    cell_id: &str,
    authored_friction: f64,
    material_profile_id: &str,
) -> Result<Value, String> {
    run_physical_report(
        source_commit,
        cell_id,
        authored_friction,
        material_profile_id,
    )
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

fn memory_has_exact_identity_set(value: &Value, limb_ids: &[String]) -> bool {
    let Some(entries) = value.as_array() else {
        return false;
    };
    entries.len() == limb_ids.len()
        && limb_ids.iter().all(|limb_id| {
            entries
                .iter()
                .filter(|entry| entry["limb_id"].as_str() == Some(limb_id.as_str()))
                .count()
                == 1
        })
}

fn memory_has_gait_and_limit(
    value: &Value,
    limb_ids: &[String],
    expected_gait_step: u64,
    expected_limit: u64,
) -> bool {
    memory_has_exact_identity_set(value, limb_ids)
        && limb_ids.iter().all(|limb_id| {
            value
                .as_array()
                .and_then(|entries| {
                    entries
                        .iter()
                        .find(|entry| entry["limb_id"].as_str() == Some(limb_id.as_str()))
                })
                .is_some_and(|entry| {
                    entry["evidence_gait_step_limit"].as_u64() == Some(expected_limit)
                        && entry["gait_step"].as_u64() == Some(expected_gait_step)
                })
        })
}

fn memory_is_at_declared_limit(value: &Value, limb_ids: &[String], expected_limit: u64) -> bool {
    memory_has_gait_and_limit(value, limb_ids, expected_limit, expected_limit)
}

fn push_once(failures: &mut Vec<String>, code: &str) {
    if !failures.iter().any(|failure| failure == code) {
        failures.push(code.to_owned());
    }
}

fn core_vec3(value: &Value) -> Option<CoreVec3> {
    Some(CoreVec3 {
        x: value["x"].as_f64().filter(|number| number.is_finite())?,
        y: value["y"].as_f64().filter(|number| number.is_finite())?,
        z: value["z"].as_f64().filter(|number| number.is_finite())?,
    })
}

fn vec3_close(left: CoreVec3, right: CoreVec3, tolerance: f64) -> bool {
    close(left.x, right.x, tolerance)
        && close(left.y, right.y, tolerance)
        && close(left.z, right.z, tolerance)
}

fn joint_observations_are_valid(value: &Value, joint_ids: &[String]) -> bool {
    value.as_array().is_some_and(|observations| {
        observations.len() == joint_ids.len()
            && observations
                .iter()
                .zip(joint_ids)
                .all(|(observation, joint_id)| {
                    observation["joint_id"].as_str() == Some(joint_id.as_str())
                        && observation["position_rad"]
                            .as_f64()
                            .is_some_and(f64::is_finite)
                        && observation["velocity_rad_s"]
                            .as_f64()
                            .is_some_and(f64::is_finite)
                        && observation["validity"]["position"] == true
                        && observation["validity"]["velocity"] == true
                })
    })
}

fn restoration_receipt_is_reconstructible(
    entry: &Value,
    previous_terminal_entry: Option<&Value>,
    compiled: &CompiledQuadruped,
) -> bool {
    let composition = &entry["command_composition"];
    let receipt = &composition["receipt"];
    let Some(current_held) = receipt["current_held_steering_fraction"].as_f64() else {
        return false;
    };
    let Some(activation_held) = receipt["activation_held_steering_fraction"].as_f64() else {
        return false;
    };
    if composition["mode"] != "terminal_pose_hold_restoration_v1"
        || receipt["schema_version"]
            != "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1"
        || receipt["semantic_step"] != entry["semantic_step"]
        || receipt["policy_id"] != CONTACT_RESTORATION_POLICY_ID
        || receipt["missing_limb_desired_foot_velocity_world_m_s"]
            != json!({"x": 0.0, "y": -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S, "z": 0.0})
        || receipt["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || receipt["pose_hold_position_gain_per_s"] != POSE_HOLD_POSITION_GAIN_PER_S
        || receipt["pose_hold_rate_damping"] != POSE_HOLD_RATE_DAMPING
        || receipt["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S
        || receipt["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || !receipt["registered_steering_stride_transform_id"].is_null()
        || receipt["damped_least_squares_lambda_m"] != CONTACT_RESTORATION_DAMPING_LAMBDA_M
        || receipt["maximum_absolute_search_joint_velocity_rad_s"]
            != CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S
        || !current_held.is_finite()
        || current_held.abs() > MAXIMUM_ABSOLUTE_STEERING_FRACTION
        || !activation_held.is_finite()
        || activation_held.abs() > MAXIMUM_ABSOLUTE_STEERING_FRACTION
        || receipt["world_build_count"] != 0
        || receipt["physics_state_modified"] != false
        || receipt["command_not_measurement"] != true
        || receipt["physical_acceptance_authority"] != false
    {
        return false;
    }
    if let Some(previous) = previous_terminal_entry {
        if previous["command_composition"]["receipt"]["activation_held_steering_fraction"]
            != receipt["activation_held_steering_fraction"]
        {
            return false;
        }
    } else if !close(current_held, activation_held, 1.0e-12) {
        return false;
    }

    let Some(limb_solutions) = receipt["ordered_limb_solutions"].as_array() else {
        return false;
    };
    let Some(base_commands) = entry["ordered_portable_base_commands"].as_array() else {
        return false;
    };
    let Some(residuals) = composition["ordered_canonical_residuals"].as_array() else {
        return false;
    };
    let Some(canonical_commands) =
        entry["selected_canonical_actuation_frame"]["ordered_commands"].as_array()
    else {
        return false;
    };
    let Some(joint_observations) =
        entry["ordered_pre_step_joint_position_velocity_observations"].as_array()
    else {
        return false;
    };
    if limb_solutions.len() != compiled.morphology.morphology_spec.limbs.len()
        || base_commands.len() != compiled.morphology.ordered_actuator_ids.len()
        || residuals.len() != compiled.morphology.ordered_actuator_ids.len()
        || canonical_commands.len() != compiled.morphology.ordered_actuator_ids.len()
    {
        return false;
    }

    let desired_foot_velocity = CoreVec3 {
        x: 0.0,
        y: -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S,
        z: 0.0,
    };
    let lambda_squared =
        CONTACT_RESTORATION_DAMPING_LAMBDA_M * CONTACT_RESTORATION_DAMPING_LAMBDA_M;
    let mut expected_pose_memory_count = 0_u64;

    for (limb, solution) in compiled
        .morphology
        .morphology_spec
        .limbs
        .iter()
        .zip(limb_solutions)
    {
        if limb.ordered_contact_site_ids.len() != 1
            || solution["limb_id"] != limb.limb_id
            || solution["contact_site_id"] != limb.ordered_contact_site_ids[0]
        {
            return false;
        }
        let contact_site_id = &limb.ordered_contact_site_ids[0];
        let Some(pre_step_contact) =
            entry["pre_step_snapshot"]["ordered_declared_contacts"][contact_site_id].as_bool()
        else {
            return false;
        };
        if solution["pre_step_contact"] != pre_step_contact {
            return false;
        }
        let expected_foot_velocity = if pre_step_contact {
            CoreVec3::ZERO
        } else {
            desired_foot_velocity
        };
        if core_vec3(&solution["desired_foot_velocity_world_m_s"])
            .is_none_or(|value| !vec3_close(value, expected_foot_velocity, 1.0e-12))
        {
            return false;
        }

        let expected_actuators = compiled
            .morphology
            .morphology_spec
            .actuators
            .iter()
            .filter(|actuator| limb.ordered_joint_ids.contains(&actuator.joint_id))
            .collect::<Vec<_>>();
        let Some(actuator_solutions) = solution["ordered_actuator_solutions"].as_array() else {
            return false;
        };
        if expected_actuators.len() != 2 || actuator_solutions.len() != 2 {
            return false;
        }

        let mut columns = Vec::with_capacity(2);
        for (actuator_solution, actuator) in actuator_solutions.iter().zip(&expected_actuators) {
            let kinematics = &actuator_solution["kinematics"];
            if actuator_solution["actuator_id"] != actuator.actuator_id
                || actuator_solution["joint_id"] != actuator.joint_id
                || kinematics["actuator_id"] != actuator.actuator_id
                || kinematics["contact_site_id"] != *contact_site_id
            {
                return false;
            }
            let Some(axis) = core_vec3(&kinematics["joint_axis_world_unit"]) else {
                return false;
            };
            let Some(anchor) = core_vec3(&kinematics["joint_anchor_world_m"]) else {
                return false;
            };
            let Some(endpoint) = core_vec3(&kinematics["endpoint_world_m"]) else {
                return false;
            };
            let column = vec3_cross(axis, vec3_sub(endpoint, anchor));
            if core_vec3(&actuator_solution["linear_jacobian_column_world_m"])
                .is_none_or(|declared| !vec3_close(declared, column, 1.0e-12))
            {
                return false;
            }
            columns.push(column);
        }

        let missing_raw = if pre_step_contact {
            None
        } else {
            let a00 = vec3_dot(columns[0], columns[0]) + lambda_squared;
            let a01 = vec3_dot(columns[0], columns[1]);
            let a11 = vec3_dot(columns[1], columns[1]) + lambda_squared;
            let b0 = vec3_dot(columns[0], desired_foot_velocity);
            let b1 = vec3_dot(columns[1], desired_foot_velocity);
            let determinant = a00 * a11 - a01 * a01;
            if !determinant.is_finite() || determinant <= 0.0 {
                return false;
            }
            Some([
                (b0 * a11 - a01 * b1) / determinant,
                (a00 * b1 - a01 * b0) / determinant,
            ])
        };

        for index in 0..2 {
            let actuator = expected_actuators[index];
            let actuator_solution = &actuator_solutions[index];
            let Some(global_index) = compiled
                .morphology
                .ordered_actuator_ids
                .iter()
                .position(|actuator_id| actuator_id == &actuator.actuator_id)
            else {
                return false;
            };
            let Some(observation) = joint_observations
                .iter()
                .find(|observation| observation["joint_id"] == actuator.joint_id)
            else {
                return false;
            };
            let Some(measured_position) = observation["position_rad"].as_f64() else {
                return false;
            };
            let Some(measured_velocity) = observation["velocity_rad_s"].as_f64() else {
                return false;
            };
            if actuator_solution["measured_joint_position_rad"]
                .as_f64()
                .is_none_or(|declared| !close(declared, measured_position, 1.0e-12))
                || actuator_solution["measured_joint_velocity_rad_s"]
                    .as_f64()
                    .is_none_or(|declared| !close(declared, measured_velocity, 1.0e-12))
            {
                return false;
            }

            let (side_sign, expected_heading_delta) = if actuator.joint_id.ends_with("_hip") {
                let side = if limb.limb_id.ends_with("_right") {
                    1.0
                } else if limb.limb_id.ends_with("_left") {
                    -1.0
                } else {
                    return false;
                };
                let Some(forward_correction) =
                    actuator_solution["portable_forward_velocity_hip_target_correction_rad"]
                        .as_f64()
                else {
                    return false;
                };
                let Some(nominal) =
                    actuator_solution["portable_nominal_unsteered_hip_target_rad"].as_f64()
                else {
                    return false;
                };
                let Some(requested_base_target) =
                    base_commands[global_index]["requested_target_position_rad"].as_f64()
                else {
                    return false;
                };
                let denominator = 1.0 + side * current_held;
                let recomputed_nominal = (requested_base_target - forward_correction) / denominator;
                let delta = recomputed_nominal * side * (current_held - activation_held);
                if actuator_solution["portable_lateral_side_sign"] != json!(side)
                    || !close(nominal, recomputed_nominal, 1.0e-12)
                    || !delta.is_finite()
                {
                    return false;
                }
                (Some(side), delta)
            } else {
                if !actuator_solution["portable_lateral_side_sign"].is_null()
                    || !actuator_solution["portable_forward_velocity_hip_target_correction_rad"]
                        .is_null()
                    || !actuator_solution["portable_nominal_unsteered_hip_target_rad"].is_null()
                {
                    return false;
                }
                (None, 0.0)
            };
            let _ = side_sign;
            if actuator_solution["portable_heading_target_delta_rad"]
                .as_f64()
                .is_none_or(|declared| !close(declared, expected_heading_delta, 1.0e-12))
            {
                return false;
            }

            let raw = if let Some(missing) = missing_raw {
                if actuator_solution["pose_capture_activated"] != false
                    || !actuator_solution["neutral_joint_position_rad"].is_null()
                    || !actuator_solution["requested_pose_target_position_rad"].is_null()
                    || !actuator_solution["clamped_pose_target_position_rad"].is_null()
                {
                    return false;
                }
                missing[index]
            } else {
                expected_pose_memory_count += 1;
                let previous_solution = previous_terminal_entry.and_then(|previous| {
                    previous["command_composition"]["receipt"]["ordered_limb_solutions"]
                        .as_array()?
                        .iter()
                        .flat_map(|limb| {
                            limb["ordered_actuator_solutions"]
                                .as_array()
                                .into_iter()
                                .flatten()
                        })
                        .find(|candidate| candidate["actuator_id"] == actuator.actuator_id)
                });
                let previous_contact = previous_terminal_entry
                    .and_then(|previous| {
                        previous["pre_step_snapshot"]["ordered_declared_contacts"][contact_site_id]
                            .as_bool()
                    })
                    .unwrap_or(false);
                let expected_capture = previous_solution.is_none() || !previous_contact;
                if actuator_solution["pose_capture_activated"] != expected_capture {
                    return false;
                }
                let Some(neutral) = actuator_solution["neutral_joint_position_rad"].as_f64() else {
                    return false;
                };
                if expected_capture {
                    if !close(neutral, measured_position - expected_heading_delta, 1.0e-12) {
                        return false;
                    }
                } else if previous_solution
                    .and_then(|previous| previous["neutral_joint_position_rad"].as_f64())
                    .is_none_or(|previous| !close(previous, neutral, 1.0e-12))
                {
                    return false;
                }
                let requested = neutral + expected_heading_delta;
                let clamped = requested.clamp(
                    actuator.minimum_target_position_rad,
                    actuator.maximum_target_position_rad,
                );
                if actuator_solution["requested_pose_target_position_rad"]
                    .as_f64()
                    .is_none_or(|declared| !close(declared, requested, 1.0e-12))
                    || actuator_solution["clamped_pose_target_position_rad"]
                        .as_f64()
                        .is_none_or(|declared| !close(declared, clamped, 1.0e-12))
                {
                    return false;
                }
                POSE_HOLD_POSITION_GAIN_PER_S * (clamped - measured_position)
                    - POSE_HOLD_RATE_DAMPING * measured_velocity
            };
            let bounded = raw.clamp(
                -CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            );
            if actuator_solution["unbounded_joint_velocity_rad_s"]
                .as_f64()
                .is_none_or(|declared| !close(declared, raw, 1.0e-12))
                || actuator_solution["desired_joint_velocity_rad_s"]
                    .as_f64()
                    .is_none_or(|declared| !close(declared, bounded, 1.0e-12))
            {
                return false;
            }
            let Some(base_host_velocity) =
                base_commands[global_index]["target_velocity_rad_s"].as_f64()
            else {
                return false;
            };
            let portable = base_host_velocity * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let expected_residual = bounded - portable;
            if residuals[global_index]["canonical_velocity_delta_rad_s"]
                .as_f64()
                .is_none_or(|declared| !close(declared, expected_residual, 1.0e-12))
                || canonical_commands[global_index]["combined_canonical_target_velocity_rad_s"]
                    .as_f64()
                    .is_none_or(|declared| !close(declared, bounded, 1.0e-12))
            {
                return false;
            }
        }
    }
    receipt["pose_memory_actuator_count"] == expected_pose_memory_count
}
fn full_gate_failures_inner(report: &Value, fail_fast: bool) -> Vec<String> {
    let mut failures = Vec::new();
    let Ok((compiled, controller)) = compile_declared_boundary() else {
        return vec!["C6_XE_BW19V_XV1_RAP_COMPILED_BOUNDARY_UNAVAILABLE".to_owned()];
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
        || report["study_class"] != "exact_finite_cell_independent_cross_engine_material_validation"
        || report["preregistration_raw_sha256"] != PREREGISTRATION_RAW_SHA256
        || report["cross_engine_host_characterization_r2_closure_raw_sha256"]
            != CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256
        || report["rapier_spv1_closure_raw_sha256"] != SPV1_CLOSURE_RAW_SHA256
        || report["rapier_ph1_closure_raw_sha256"] != PH1_CLOSURE_RAW_SHA256
        || report["live_integration_raw_sha256"] != LIVE_INTEGRATION_RAW_SHA256
        || report["active_configuration_v2_raw_sha256"] != ACTIVE_CONFIGURATION_V2_RAW_SHA256
        || report["canonical_profile_raw_sha256"] != CANONICAL_PROFILE_RAW_SHA256
        || report["vh1_closure_raw_sha256"] != VH1_CLOSURE_RAW_SHA256
        || report["c2_closure_raw_sha256"] != C2_CLOSURE_RAW_SHA256
        || report["eh1_closure_raw_sha256"] != EH1_CLOSURE_RAW_SHA256
        || report["lc1_closure_raw_sha256"] != LC1_CLOSURE_RAW_SHA256
        || report["ts1_closure_raw_sha256"] != TS1_CLOSURE_RAW_SHA256
        || report["tr1_closure_raw_sha256"] != TR1_CLOSURE_RAW_SHA256
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
        failures.push("C6_XE_BW19V_XV1_RAP_IDENTITY_INVALID".to_owned());
    }
    let material_binding_valid = report["cell_id"]
        .as_str()
        .zip(report["authored_sliding_friction"].as_f64())
        .zip(report["material_profile_id"].as_str())
        .is_some_and(|((cell_id, authored_friction), material_profile_id)| {
            declared_material_cell(cell_id, authored_friction, material_profile_id).is_ok()
                && report["inherited_worker_contract"] == "PH1"
                && report["authored_friction_vector"] == json!([authored_friction])
                && report["host_configuration"]["authored_friction"] == authored_friction
                && report["host_configuration"]["authored_friction_vector"]
                    == json!([authored_friction])
                && report["host_configuration"]["material_profile_id"] == material_profile_id
                && report["host_configuration"]["ground_and_every_robot_collider_use_same_friction"]
                    == true
                && report["host_configuration"]["friction_combine_rule"] == "min"
        });
    if !material_binding_valid {
        failures.push("C6_XE_BW19V_XV1_RAP_MATERIAL_BINDING_INVALID".to_owned());
    }
    if report["preflight"]["ok"] != true
        || report["preflight"]["world_build_count"] != 0
        || report["preflight"]["physical_acceptance_authority"] != false
    {
        failures.push("C6_XE_BW19V_XV1_RAP_PREFLIGHT_RECEIPT_INVALID".to_owned());
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
        failures.push("C6_XE_BW19V_XV1_RAP_HOST_CONFIGURATION_INVALID".to_owned());
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
            failures.push(format!("C6_XE_BW19V_XV1_RAP_COUNT_INVALID:{pointer}"));
        }
    }
    if u64_at(report, "/nonzero_bounded_residual_count").unwrap_or(0) == 0 {
        failures.push("C6_XE_BW19V_XV1_RAP_NONZERO_BOUNDED_RESIDUAL_MISSING".to_owned());
    }
    if u64_at(report, "/nonzero_effective_host_residual_count").unwrap_or(0) == 0 {
        failures.push("C6_XE_BW19V_XV1_RAP_NONZERO_EFFECTIVE_RESIDUAL_MISSING".to_owned());
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
        || report["schedule"]["terminal_restoration_phase"]["scheduler_ordered_limb_ids"]
            != json!(SCHEDULER_ORDERED_LIMB_IDS)
        || report["schedule"]["terminal_restoration_phase"]["nominal_phase_offsets_steps"]
            != json!(NOMINAL_PHASE_OFFSETS_STEPS)
        || report["schedule"]["terminal_restoration_phase"]["gait_cycle_steps"] != GAIT_CYCLE_STEPS
        || report["schedule"]["terminal_restoration_phase"]["swing_steps"] != SWING_STEPS
        || report["schedule"]["terminal_restoration_phase"]["frozen_evidence_limit_gait_step"]
            != EVIDENCE_LIMIT_GAIT_STEP
        || report["schedule"]["terminal_restoration_phase"]["frozen_evidence_endpoint_global_cycle_step"]
            != EVIDENCE_ENDPOINT_GLOBAL_CYCLE_STEP
        || report["schedule"]["terminal_restoration_phase"]["frozen_evidence_endpoint_local_phase_steps"]
            != json!(EVIDENCE_ENDPOINT_LOCAL_PHASE_STEPS)
        || report["schedule"]["terminal_restoration_phase"]["gait_memory_frozen_at_evidence_limit"]
            != true
        || report["schedule"]["terminal_restoration_phase"]["restoration_policy_id"]
            != CONTACT_RESTORATION_POLICY_ID
        || report["schedule"]["terminal_restoration_phase"]["contacting_limb_target_joint_velocity_mode"]
            != "captured_pose_proportional_derivative_velocity_v1"
        || report["schedule"]["terminal_restoration_phase"]["pose_hold_position_gain_per_s"]
            != POSE_HOLD_POSITION_GAIN_PER_S
        || report["schedule"]["terminal_restoration_phase"]["pose_hold_rate_damping"]
            != POSE_HOLD_RATE_DAMPING
        || report["schedule"]["terminal_restoration_phase"]["maximum_absolute_pose_hold_joint_velocity_rad_s"]
            != CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S
        || report["schedule"]["terminal_restoration_phase"]["heading_correction_mode"]
            != "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        || report["schedule"]["terminal_restoration_phase"]["heading_gain_or_filter_changed"]
            != false
        || report["schedule"]["terminal_restoration_phase"]["missing_limb_desired_foot_velocity_world_m_s"]
            != json!([0.0, -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S, 0.0])
        || report["schedule"]["terminal_restoration_phase"]["damped_least_squares_lambda_m"]
            != CONTACT_RESTORATION_DAMPING_LAMBDA_M
        || report["schedule"]["terminal_restoration_phase"]["maximum_absolute_search_joint_velocity_rad_s"]
            != CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S
        || report["schedule"]["terminal_restoration_phase"]["maximum_four_contact_acquisition_steps_after_evidence_completion"]
            != MAXIMUM_TERMINAL_ACQUISITION_STEPS
        || report["schedule"]["terminal_restoration_phase"]["terminal_acquisition_deadline_step_exclusive"]
            != TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE
        || report["schedule"]["terminal_restoration_phase"]["required_consecutive_all_four_contact_steps"]
            != REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
        || report["schedule"]["terminal_restoration_phase"]["hold_counter_resets_on_any_contact_loss"]
            != true
        || report["schedule"]["required_post_terminal_steps"]
            != REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
        || report["schedule"]["terminal_zero_target_settle_steps"] != 0
    {
        failures.push("C6_XE_BW19V_XV1_RAP_SCHEDULE_INVALID".to_owned());
    }
    if fail_fast && !failures.is_empty() {
        return failures;
    }

    let Some(trace) = report["ordered_trace"].as_array() else {
        failures.push("C6_XE_BW19V_XV1_RAP_TRACE_MISSING".to_owned());
        return failures;
    };
    if trace.len() != TOTAL_STEPS as usize {
        failures.push("C6_XE_BW19V_XV1_RAP_TRACE_LENGTH_INVALID".to_owned());
        return failures;
    }
    if !snapshot_is_structurally_valid(&report["initial_pose_snapshot"], &contact_ids)
        || events_from_snapshot(&report["initial_pose_snapshot"])
            .is_none_or(|events| !events.is_empty())
        || report["initial_declared_diagnostic_events"] != json!([])
    {
        failures.push("C6_XE_BW19V_XV1_RAP_INITIAL_SNAPSHOT_INVALID".to_owned());
    }
    let recomputed_initial_contact_count = contact_ids
        .iter()
        .filter(|contact_id| {
            report["initial_pose_snapshot"]["ordered_declared_contacts"][*contact_id] == true
        })
        .count() as u64;
    if u64_at(report, "/initial_contact_count") != Some(recomputed_initial_contact_count) {
        failures.push("C6_XE_BW19V_XV1_RAP_INITIAL_CONTACT_COUNT_INVALID".to_owned());
    }
    if fail_fast && !failures.is_empty() {
        return failures;
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
    let mut first_four_contact_acquisition = None::<u64>;
    let mut consecutive_four_contact_completion = None::<u64>;
    let mut consecutive_four_contact_steps = 0_u64;
    let mut maximum_consecutive_four_contact_steps = 0_u64;
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
        let expected_campaign_phase = if semantic_step < CLOCKED_STEPS {
            "clocked_walking"
        } else if first_evidence_completion.is_none() {
            "evidence_walking"
        } else if consecutive_four_contact_completion.is_none() {
            "terminal_acquisition"
        } else {
            "terminal_hold"
        };
        if entry["schema_version"] != TRACE_SCHEMA_VERSION
            || entry["semantic_step"] != semantic_step
            || entry["campaign_phase"] != expected_campaign_phase
            || entry["phase_progression_mode"] != expected_phase
            || entry["command_provenance_recorded_before_application"] != true
            || entry["production_motor_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
        {
            push_once(
                &mut failures,
                "C6_XE_BW19V_XV1_RAP_TRACE_ORDER_OR_IDENTITY_INVALID",
            );
        }
        if !memory_has_exact_identity_set(&entry["ordered_limb_controller_memory_before"], limb_ids)
            || !memory_has_exact_identity_set(
                &entry["ordered_limb_controller_memory_after"],
                limb_ids,
            )
        {
            push_once(
                &mut failures,
                "C6_XE_BW19V_XV1_RAP_LIMB_MEMORY_IDENTITY_INVALID",
            );
        }
        if first_evidence_completion.is_some()
            && (!memory_is_at_declared_limit(
                &entry["ordered_limb_controller_memory_before"],
                limb_ids,
                EVIDENCE_LIMIT_GAIT_STEP,
            ) || !memory_is_at_declared_limit(
                &entry["ordered_limb_controller_memory_after"],
                limb_ids,
                EVIDENCE_LIMIT_GAIT_STEP,
            ))
        {
            push_once(
                &mut failures,
                "C6_XE_BW19V_XV1_RAP_RESTORATION_MEMORY_FREEZE_INVALID",
            );
        }
        if !joint_observations_are_valid(
            &entry["ordered_pre_step_joint_position_velocity_observations"],
            &compiled.morphology.ordered_joint_ids,
        ) || !joint_observations_are_valid(
            &entry["ordered_post_step_joint_position_velocity_observations"],
            &compiled.morphology.ordered_joint_ids,
        ) || (index > 0
            && entry["ordered_pre_step_joint_position_velocity_observations"]
                != trace[index - 1]["ordered_post_step_joint_position_velocity_observations"])
        {
            push_once(
                &mut failures,
                "C6_XE_BW19V_XV1_RAP_JOINT_OBSERVATION_INVALID",
            );
        }
        if !snapshot_is_structurally_valid(&entry["pre_step_snapshot"], &contact_ids)
            || !snapshot_is_structurally_valid(&entry["post_step_snapshot"], &contact_ids)
        {
            push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_TRACE_SNAPSHOT_INVALID");
            if fail_fast {
                return failures;
            }
            continue;
        }
        if semantic_step == CLOCKED_STEPS {
            evidence_start_position = snapshot_position(&entry["pre_step_snapshot"]);
        }
        let expected_events = events_from_snapshot(&entry["post_step_snapshot"]);
        if expected_events.as_ref().map(|events| json!(events))
            != Some(entry["declared_diagnostic_events"].clone())
        {
            push_once(
                &mut failures,
                "C6_XE_BW19V_XV1_RAP_EVENT_RECONSTRUCTION_INVALID",
            );
        }
        if expected_events.is_some_and(|events| !events.is_empty()) {
            push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_DECLARED_PHYSICAL_EVENT");
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
            &entry["command_composition"]["ordered_canonical_residuals"],
            &entry["selected_canonical_actuation_frame"]["ordered_commands"],
            &entry["selected_rapier_host_mapping"]["ordered_commands"],
            &entry["ordered_load_bearing_host_commands"],
            &entry["ordered_post_step_joint_motor_readbacks_and_impulses"],
        ];
        if arrays
            .iter()
            .any(|array| !ordered_ids_match(array, actuator_ids))
        {
            push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_ACTUATOR_ORDER_INVALID");
            if fail_fast {
                return failures;
            }
            continue;
        }
        recomputed_base += ACTUATOR_COUNT as u64;
        recomputed_bounded += ACTUATOR_COUNT as u64;
        recomputed_canonical += ACTUATOR_COUNT as u64;
        recomputed_host += ACTUATOR_COUNT as u64;
        recomputed_motor += ACTUATOR_COUNT as u64;

        let canonical = &entry["selected_canonical_actuation_frame"];
        let mapping = &entry["selected_rapier_host_mapping"];
        let composition_receipt = &entry["command_composition"]["receipt"];
        let expected_composition_mode = if first_evidence_completion.is_none() {
            "walking_v4"
        } else {
            "terminal_pose_hold_restoration_v1"
        };
        if digest_json(canonical).ok().as_deref()
            != entry["canonical_actuation_frame_sha256"].as_str()
            || digest_json(mapping).ok().as_deref() != entry["rapier_host_mapping_sha256"].as_str()
            || digest_json(composition_receipt).ok().as_deref()
                != entry["command_composition"]["receipt_sha256"].as_str()
            || mapping["ordered_commands"] != entry["ordered_load_bearing_host_commands"]
            || canonical["source_policy_id"] != BW19V_CONTROLLER_POLICY_ID
            || canonical["semantic_step"] != semantic_step
            || mapping["semantic_step"] != semantic_step
            || mapping["host_profile_id"] != VELOCITY_ONLY_LIVE_PROFILE_ID
            || mapping["native_position_stiffness"] != 0.0
            || mapping["independent_native_position_feedback_applied"] != false
            || entry["command_composition"]["mode"] != expected_composition_mode
            || entry["command_composition"]["retained_mixed_space_projection_applied"] != false
        {
            push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_RECEIPT_INVALID");
        }
        if expected_composition_mode == "walking_v4" {
            if composition_receipt["global_requested_correction_scale"]
                != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
                || composition_receipt["candidate_id"] != BW19V_CANDIDATE_ID
                || composition_receipt["candidate_composition_digest"]
                    != BW19V_CANDIDATE_COMPOSITION_DIGEST
            {
                push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_WALKING_RECEIPT_INVALID");
            }
        } else {
            let previous_terminal_entry = index.checked_sub(1).and_then(|previous_index| {
                (trace[previous_index]["command_composition"]["mode"]
                    == "terminal_pose_hold_restoration_v1")
                    .then_some(&trace[previous_index])
            });
            if !restoration_receipt_is_reconstructible(entry, previous_terminal_entry, &compiled) {
                push_once(
                    &mut failures,
                    "C6_XE_BW19V_XV1_RAP_RESTORATION_RECONSTRUCTION_INVALID",
                );
            }
        }
        let bounded = arrays[1].as_array().unwrap();
        let canonical_commands = arrays[2].as_array().unwrap();
        let host_commands = arrays[4].as_array().unwrap();
        let motors = arrays[5].as_array().unwrap();
        for actuator_index in 0..ACTUATOR_COUNT {
            let bounded_delta = bounded[actuator_index]["canonical_velocity_delta_rad_s"].as_f64();
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
            let base_host_velocity =
                arrays[0].as_array().unwrap()[actuator_index]["target_velocity_rad_s"].as_f64();
            let maximum_speed =
                canonical_commands[actuator_index]["maximum_target_speed_rad_s"].as_f64();
            if bounded_delta
                .zip(stability_delta)
                .is_none_or(|(left, right)| !close(left, right, 1.0e-12))
                || base_host_velocity
                    .zip(portable_velocity)
                    .is_none_or(|(host, portable)| {
                        !close(
                            host * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
                            portable,
                            1.0e-12,
                        )
                    })
                || portable_velocity
                    .zip(bounded_delta)
                    .zip(maximum_speed)
                    .zip(combined_velocity)
                    .is_none_or(|(((portable, residual), maximum), combined)| {
                        !close(
                            (portable + residual).clamp(-maximum, maximum),
                            combined,
                            1.0e-12,
                        )
                    })
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
                push_once(
                    &mut failures,
                    "C6_XE_BW19V_XV1_RAP_MOTOR_OR_MAPPING_INVALID",
                );
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
                push_once(&mut failures, "C6_XE_BW19V_XV1_RAP_IMPULSE_LIMIT_INVALID");
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
            && memory_is_at_declared_limit(
                &entry["ordered_limb_controller_memory_after"],
                limb_ids,
                EVIDENCE_LIMIT_GAIT_STEP,
            )
        {
            first_evidence_completion = Some(semantic_step);
            evidence_end_position = snapshot_position(&entry["post_step_snapshot"]);
        } else if first_evidence_completion.is_some() {
            let all_four_contacts = contact_ids.iter().all(|contact_id| {
                entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true
            });
            if all_four_contacts {
                first_four_contact_acquisition.get_or_insert(semantic_step);
                consecutive_four_contact_steps += 1;
                maximum_consecutive_four_contact_steps =
                    maximum_consecutive_four_contact_steps.max(consecutive_four_contact_steps);
                if consecutive_four_contact_steps == REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
                    && consecutive_four_contact_completion.is_none()
                {
                    consecutive_four_contact_completion = Some(semantic_step);
                }
            } else {
                consecutive_four_contact_steps = 0;
            }
        }
        if fail_fast && !failures.is_empty() {
            return failures;
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
            failures.push(format!("C6_XE_BW19V_XV1_RAP_RECOMPUTE:{pointer}"));
        }
    }
    if report["schedule"]["evidence_limits_reached"] != first_evidence_completion.is_some()
        || report["schedule"]["evidence_completion_semantic_step"]
            != first_evidence_completion
                .map(Value::from)
                .unwrap_or(Value::Null)
    {
        failures.push("C6_XE_BW19V_XV1_RAP_EVIDENCE_COMPLETION_RECOMPUTE".to_owned());
    }
    let expected_restoration_activation =
        first_evidence_completion.and_then(|step| step.checked_add(1));
    let restoration_schedule = &report["schedule"]["terminal_restoration_phase"];
    if restoration_schedule["activation_semantic_step"]
        != expected_restoration_activation
            .map(Value::from)
            .unwrap_or(Value::Null)
        || restoration_schedule["first_four_contact_acquisition_semantic_step"]
            != first_four_contact_acquisition
                .map(Value::from)
                .unwrap_or(Value::Null)
        || restoration_schedule["consecutive_four_contact_completion_semantic_step"]
            != consecutive_four_contact_completion
                .map(Value::from)
                .unwrap_or(Value::Null)
        || restoration_schedule["maximum_consecutive_four_contact_steps"]
            != maximum_consecutive_four_contact_steps
        || restoration_schedule["required_consecutive_hold_completed"]
            != consecutive_four_contact_completion.is_some()
    {
        failures.push("C6_XE_BW19V_XV1_RAP_RESTORATION_COMPLETION_RECOMPUTE".to_owned());
    }
    if first_evidence_completion.is_none_or(|step| step >= EVIDENCE_DEADLINE_EXCLUSIVE) {
        failures.push("C6_XE_BW19V_XV1_RAP_EVIDENCE_DEADLINE".to_owned());
    }
    let terminal_acquisition_in_time = first_evidence_completion
        .zip(first_four_contact_acquisition)
        .is_some_and(|(evidence, acquisition)| {
            acquisition > evidence
                && acquisition - evidence <= MAXIMUM_TERMINAL_ACQUISITION_STEPS
                && acquisition < TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE
        });
    if !terminal_acquisition_in_time {
        failures.push("C6_XE_BW19V_XV1_RAP_TERMINAL_ACQUISITION_DEADLINE".to_owned());
    }
    if consecutive_four_contact_completion.is_none()
        || maximum_consecutive_four_contact_steps < REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS
    {
        failures.push("C6_XE_BW19V_XV1_RAP_CONSECUTIVE_TERMINAL_HOLD".to_owned());
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
            failures.push(format!("C6_XE_BW19V_XV1_RAP_METRIC_RECOMPUTE:{pointer}"));
        }
    }
    let terminal_four_contact = trace.last().is_some_and(|entry| {
        contact_ids.iter().all(|contact_id| {
            entry["post_step_snapshot"]["ordered_declared_contacts"][contact_id] == true
        })
    });
    if report["terminal_four_contact_stance"] != terminal_four_contact || !terminal_four_contact {
        failures.push("C6_XE_BW19V_XV1_RAP_TERMINAL_STANCE".to_owned());
    }
    for (limb_id, evidence) in &recomputed_foot_evidence {
        let declared = &report["limb_evidence"][limb_id];
        if declared["contact_cycles"] != evidence.contact_cycles
            || f64_at(declared, "/maximum_foot_relocation_m")
                .is_none_or(|value| !close(value, evidence.maximum_foot_relocation_m, 1.0e-6))
            || declared["maximum_airborne_dwell_steps"] != evidence.maximum_airborne_dwell_steps
        {
            failures.push(format!("C6_XE_BW19V_XV1_RAP_LIMB_RECOMPUTE:{limb_id}"));
        }
        if evidence.contact_cycles < MINIMUM_CONTACT_CYCLES_PER_LIMB
            || evidence.maximum_airborne_dwell_steps < MINIMUM_AIRBORNE_DWELL_STEPS
            || evidence.maximum_foot_relocation_m < MINIMUM_FOOT_RELOCATION_M
        {
            failures.push(format!("C6_XE_BW19V_XV1_RAP_LIMB_GATE:{limb_id}"));
        }
    }
    if evidence_advance.is_none_or(|value| value < MINIMUM_EVIDENCE_ADVANCE_M) {
        failures.push("C6_XE_BW19V_XV1_RAP_EVIDENCE_ADVANCE".to_owned());
    }
    if final_delta.is_none_or(|delta| delta.0 < MINIMUM_FINAL_ADVANCE_M) {
        failures.push("C6_XE_BW19V_XV1_RAP_FINAL_ADVANCE".to_owned());
    }
    if final_delta.is_none_or(|delta| delta.2.abs() > MAXIMUM_LATERAL_DRIFT_M) {
        failures.push("C6_XE_BW19V_XV1_RAP_LATERAL_DRIFT".to_owned());
    }
    if final_yaw.is_none_or(|value| value.abs() > MAXIMUM_YAW_DRIFT_RAD) {
        failures.push("C6_XE_BW19V_XV1_RAP_YAW_DRIFT".to_owned());
    }
    if recomputed_maximum_tilt > MAXIMUM_TILT_RAD {
        failures.push("C6_XE_BW19V_XV1_RAP_TILT".to_owned());
    }
    if recomputed_minimum_height < MINIMUM_TORSO_HEIGHT_M {
        failures.push("C6_XE_BW19V_XV1_RAP_TORSO_HEIGHT".to_owned());
    }
    if recomputed_maximum_anchor > MAXIMUM_ANCHOR_ERROR_M {
        failures.push("C6_XE_BW19V_XV1_RAP_ANCHOR_ERROR".to_owned());
    }
    if recomputed_maximum_hinge > MAXIMUM_HINGE_AXIS_ERROR_RAD {
        failures.push("C6_XE_BW19V_XV1_RAP_HINGE_AXIS_ERROR".to_owned());
    }
    if recomputed_torso_contacts != 0 {
        failures.push("C6_XE_BW19V_XV1_RAP_TORSO_GROUND_CONTACT".to_owned());
    }
    let claims = &report["claim_boundary"];
    if claims["exact_s169_rapier_xv1_engine_native_cell_contract"] != report["ok"]
        || claims["finite_single_body_walking_contract"] != report["ok"]
        || claims["aggregate_six_cell_validation"] != false
        || claims["independent_validation"] != false
        || claims["population_inference"] != false
        || claims["rapier_release_selected_same_policy_physical_c6"] != false
        || claims["different_physics_engines_have_same_policy_exact_finite_validation"] != false
        || claims["bounded_discrete_material_validation"] != false
        || claims["formal_cross_engine_equivalence"] != false
        || claims["trajectory_equivalence"] != false
        || claims["arbitrary_quadruped_coverage"] != false
        || claims["continuous_full_volume_coverage"] != false
        || claims["continuous_friction_coverage"] != false
        || claims["arbitrary_material_robustness"] != false
        || claims["release_authorized"] != false
        || claims["physical_acceptance_authority"] != false
        || claims["completed_engine_neutral_sdk"] != false
    {
        failures.push("C6_XE_BW19V_XV1_RAP_CLAIM_INFLATION".to_owned());
    }
    failures
}

fn full_gate_failures(report: &Value) -> Vec<String> {
    full_gate_failures_inner(report, false)
}

pub fn evaluate_cross_engine_discrete_material_validation_xv1_rapier_report(
    report: &Value,
) -> Vec<String> {
    full_gate_failures(report)
}

fn synthetic_contact(step: u64, site_index: usize) -> bool {
    let offset = site_index as u64 * 20;
    !(step == EVIDENCE_LIMIT_GAIT_STEP && site_index == 0
        || (600 + offset..606 + offset).contains(&step)
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

fn synthetic_limb_memory(semantic_step: u64, after: bool) -> Vec<Value> {
    let gait_step = if after {
        if semantic_step == 0 {
            0
        } else {
            semantic_step.min(EVIDENCE_LIMIT_GAIT_STEP)
        }
    } else {
        semantic_step
            .saturating_sub(1)
            .min(EVIDENCE_LIMIT_GAIT_STEP)
    };
    let gait_limit = if semantic_step < CLOCKED_STEPS {
        Value::Null
    } else {
        Value::from(EVIDENCE_LIMIT_GAIT_STEP)
    };
    SCHEDULER_ORDERED_LIMB_IDS
        .iter()
        .map(|limb_id| {
            json!({
                "limb_id": limb_id,
                "gait_step": gait_step,
                "evidence_gait_step_limit": gait_limit,
                "release_hold_step_count": 0,
                "recontact_hold_step_count": 0,
                "gate_timeout_count": 0,
                "phase_sync_hold_step_count": 0,
            })
        })
        .collect()
}

fn synthetic_joint_observations(joint_ids: &[String], semantic_step: u64, after: bool) -> Value {
    let sample = semantic_step as f64 + if after { 1.0 } else { 0.0 };
    Value::Array(
        joint_ids
            .iter()
            .enumerate()
            .map(|(index, joint_id)| {
                json!({
                    "joint_id": joint_id,
                    "position_rad": index as f64 * 0.01 + sample * 1.0e-6,
                    "velocity_rad_s": 0.01,
                    "anchor_error_m": 0.0,
                    "validity": {"position": true, "velocity": true, "anchor_error": true},
                })
            })
            .collect(),
    )
}

fn synthetic_restoration_receipt(
    semantic_step: u64,
    compiled: &CompiledQuadruped,
    base_commands: &[Value],
) -> Result<(Value, BTreeMap<String, f64>), String> {
    let desired_foot_velocity = CoreVec3 {
        x: 0.0,
        y: -CONTACT_RESTORATION_DOWNWARD_SPEED_M_S,
        z: 0.0,
    };
    let lambda_squared =
        CONTACT_RESTORATION_DAMPING_LAMBDA_M * CONTACT_RESTORATION_DAMPING_LAMBDA_M;
    let mut desired_by_actuator = BTreeMap::new();
    let mut limb_solutions = Vec::new();
    let mut pose_memory_actuator_count = 0_u64;
    for limb in &compiled.morphology.morphology_spec.limbs {
        let contact_site_id = &limb.ordered_contact_site_ids[0];
        let site_index = compiled
            .morphology
            .morphology_spec
            .contact_sites
            .iter()
            .position(|site| site.contact_site_id == *contact_site_id)
            .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_SYNTHETIC_SITE_MISSING".to_owned())?;
        let contact = synthetic_contact(semantic_step.saturating_sub(1), site_index);
        let actuators = compiled
            .morphology
            .morphology_spec
            .actuators
            .iter()
            .filter(|actuator| limb.ordered_joint_ids.contains(&actuator.joint_id))
            .collect::<Vec<_>>();
        if actuators.len() != 2 {
            return Err("C6_XE_BW19V_XV1_RAP_SYNTHETIC_LIMB_CARDINALITY".to_owned());
        }
        let anchors = [
            CoreVec3 {
                x: 0.0,
                y: 0.0,
                z: 0.0,
            },
            CoreVec3 {
                x: 0.1,
                y: 0.0,
                z: 0.0,
            },
        ];
        let endpoint = CoreVec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        };
        let axis = CoreVec3 {
            x: 0.0,
            y: 0.0,
            z: 1.0,
        };
        let columns = [
            vec3_cross(axis, vec3_sub(endpoint, anchors[0])),
            vec3_cross(axis, vec3_sub(endpoint, anchors[1])),
        ];
        let missing_raw = if contact {
            None
        } else {
            let a00 = vec3_dot(columns[0], columns[0]) + lambda_squared;
            let a01 = vec3_dot(columns[0], columns[1]);
            let a11 = vec3_dot(columns[1], columns[1]) + lambda_squared;
            let b0 = vec3_dot(columns[0], desired_foot_velocity);
            let b1 = vec3_dot(columns[1], desired_foot_velocity);
            let determinant = a00 * a11 - a01 * a01;
            Some([
                (b0 * a11 - a01 * b1) / determinant,
                (a00 * b1 - a01 * b0) / determinant,
            ])
        };
        let capture_step = EVIDENCE_LIMIT_GAIT_STEP + 1 + u64::from(site_index == 0);
        let mut actuator_solutions = Vec::new();
        for index in 0..2 {
            let actuator = actuators[index];
            let global_joint_index = compiled
                .morphology
                .ordered_joint_ids
                .iter()
                .position(|joint_id| joint_id == &actuator.joint_id)
                .ok_or_else(|| "C6_XE_BW19V_XV1_RAP_SYNTHETIC_JOINT_MISSING".to_owned())?;
            let measured_position =
                global_joint_index as f64 * 0.01 + semantic_step as f64 * 1.0e-6;
            let measured_velocity = 0.01;
            let is_hip = actuator.joint_id.ends_with("_hip");
            let side_sign = if is_hip {
                Some(if limb.limb_id.ends_with("_right") {
                    1.0
                } else {
                    -1.0
                })
            } else {
                None
            };
            let (
                pose_capture_activated,
                neutral_joint_position_rad,
                requested_pose_target_position_rad,
                clamped_pose_target_position_rad,
                raw,
            ) = if let Some(missing) = missing_raw {
                (false, None, None, None, missing[index])
            } else {
                pose_memory_actuator_count += 1;
                let neutral = global_joint_index as f64 * 0.01 + capture_step as f64 * 1.0e-6;
                let requested = neutral;
                let clamped = requested.clamp(
                    actuator.minimum_target_position_rad,
                    actuator.maximum_target_position_rad,
                );
                (
                    semantic_step == capture_step,
                    Some(neutral),
                    Some(requested),
                    Some(clamped),
                    POSE_HOLD_POSITION_GAIN_PER_S * (clamped - measured_position)
                        - POSE_HOLD_RATE_DAMPING * measured_velocity,
                )
            };
            let bounded = raw.clamp(
                -CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            );
            desired_by_actuator.insert(actuator.actuator_id.clone(), bounded);
            actuator_solutions.push(json!({
                "actuator_id": actuator.actuator_id,
                "joint_id": actuator.joint_id,
                "kinematics": {
                    "actuator_id": actuator.actuator_id,
                    "contact_site_id": contact_site_id,
                    "joint_anchor_world_m": anchors[index],
                    "joint_axis_world_unit": axis,
                    "endpoint_world_m": endpoint,
                },
                "linear_jacobian_column_world_m": columns[index],
                "measured_joint_position_rad": measured_position,
                "measured_joint_velocity_rad_s": measured_velocity,
                "pose_capture_activated": pose_capture_activated,
                "neutral_joint_position_rad": neutral_joint_position_rad,
                "portable_lateral_side_sign": side_sign,
                "portable_forward_velocity_hip_target_correction_rad":
                    is_hip.then_some(0.0),
                "portable_nominal_unsteered_hip_target_rad": is_hip.then_some(0.0),
                "portable_heading_target_delta_rad": 0.0,
                "requested_pose_target_position_rad": requested_pose_target_position_rad,
                "clamped_pose_target_position_rad": clamped_pose_target_position_rad,
                "unbounded_joint_velocity_rad_s": raw,
                "desired_joint_velocity_rad_s": bounded,
            }));
        }
        limb_solutions.push(json!({
            "limb_id": limb.limb_id,
            "contact_site_id": contact_site_id,
            "pre_step_contact": contact,
            "desired_foot_velocity_world_m_s":
                if contact { CoreVec3::ZERO } else { desired_foot_velocity },
            "ordered_actuator_solutions": actuator_solutions,
        }));
    }
    if base_commands.len() != compiled.morphology.ordered_actuator_ids.len() {
        return Err("C6_XE_BW19V_XV1_RAP_SYNTHETIC_BASE_COMMAND_COUNT".to_owned());
    }
    Ok((
        json!({
            "schema_version":
                "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1",
            "semantic_step": semantic_step,
            "policy_id": CONTACT_RESTORATION_POLICY_ID,
            "missing_limb_desired_foot_velocity_world_m_s": desired_foot_velocity,
            "contacting_limb_target_joint_velocity_mode":
                "captured_pose_proportional_derivative_velocity_v1",
            "pose_hold_position_gain_per_s": POSE_HOLD_POSITION_GAIN_PER_S,
            "pose_hold_rate_damping": POSE_HOLD_RATE_DAMPING,
            "maximum_absolute_pose_hold_joint_velocity_rad_s":
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            "heading_correction_mode":
                "registered_portable_yaw_only_hip_target_delta_from_activation_v1",
            "activation_held_steering_fraction": 0.0,
            "current_held_steering_fraction": 0.0,
            "registered_steering_stride_transform_id": Value::Null,
            "damped_least_squares_lambda_m": CONTACT_RESTORATION_DAMPING_LAMBDA_M,
            "maximum_absolute_search_joint_velocity_rad_s":
                CONTACT_RESTORATION_MAXIMUM_JOINT_SPEED_RAD_S,
            "ordered_limb_solutions": limb_solutions,
            "pose_memory_actuator_count": pose_memory_actuator_count,
            "world_build_count": 0,
            "physics_state_modified": false,
            "command_not_measurement": true,
            "physical_acceptance_authority": false,
        }),
        desired_by_actuator,
    ))
}
fn synthetic_trace_step(
    semantic_step: u64,
    compiled: &CompiledQuadruped,
    contact_ids: &[String],
) -> Result<Value, String> {
    let actuator_ids = &compiled.morphology.ordered_actuator_ids;
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
    let terminal_restoration = semantic_step > EVIDENCE_LIMIT_GAIT_STEP;
    let (restoration_receipt, desired_by_actuator) = if terminal_restoration {
        let (receipt, desired) =
            synthetic_restoration_receipt(semantic_step, compiled, &base_commands)?;
        (Some(receipt), desired)
    } else {
        (None, BTreeMap::new())
    };
    let canonical_commands = actuator_ids
        .iter()
        .enumerate()
        .map(|(index, actuator_id)| {
            let portable_velocity = base_commands[index]["target_velocity_rad_s"]
                .as_f64()
                .expect("synthetic base velocity")
                * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            let stability_delta = if terminal_restoration {
                desired_by_actuator[actuator_id] - portable_velocity
            } else if index == 0 {
                if semantic_step == 1 { 0.1 } else { 0.01 }
            } else {
                0.0
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
                "schema_version": CANONICAL_VELOCITY_RESIDUAL_V1_VERSION,
                "actuator_id": command["actuator_id"],
                "canonical_velocity_delta_rad_s":
                    command["stability_canonical_velocity_delta_rad_s"],
                "command_not_measurement": true,
                "physical_acceptance_authority": false,
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
        "schema_version": "sporespore_ph1_synthetic_v4_planning_receipt_v1",
        "semantic_step": semantic_step,
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "global_requested_correction_scale": BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
        "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    });
    let command_receipt = restoration_receipt.unwrap_or(planning);
    let canonical_sha = digest_json(&canonical).map_err(|error| error.to_string())?;
    let mapping_sha = digest_json(&mapping).map_err(|error| error.to_string())?;
    let command_receipt_sha = digest_json(&command_receipt).map_err(|error| error.to_string())?;
    let synthetic_hold_completion_step =
        EVIDENCE_LIMIT_GAIT_STEP + REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS;
    Ok(json!({
        "schema_version": TRACE_SCHEMA_VERSION,
        "semantic_step": semantic_step,
        "campaign_phase": if semantic_step < CLOCKED_STEPS {
            "clocked_walking"
        } else if semantic_step <= EVIDENCE_LIMIT_GAIT_STEP {
            "evidence_walking"
        } else if semantic_step <= synthetic_hold_completion_step {
            "terminal_acquisition"
        } else {
            "terminal_hold"
        },
        "phase_progression_mode": if semantic_step < CLOCKED_STEPS {
            "clocked"
        } else {
            "contact_gated"
        },
        "command_provenance_recorded_before_application": true,
        "pre_step_snapshot": synthetic_snapshot(semantic_step, contact_ids, false),
        "ordered_pre_step_joint_position_velocity_observations":
            synthetic_joint_observations(
                &compiled.morphology.ordered_joint_ids,
                semantic_step,
                false,
            ),
        "ordered_limb_controller_memory_before": synthetic_limb_memory(semantic_step, false),
        "portable_controller_actuation_receipt_sha256": "sha256:synthetic",
        "ordered_portable_base_commands": base_commands,
        "production_motor_profile_id": VELOCITY_ONLY_LIVE_PROFILE_ID,
        "command_composition": {
            "mode": if terminal_restoration {
                "terminal_pose_hold_restoration_v1"
            } else {
                "walking_v4"
            },
            "receipt_sha256": command_receipt_sha,
            "receipt": command_receipt,
            "ordered_canonical_residuals": bounded,
            "retained_mixed_space_projection_applied": false,
        },
        "canonical_actuation_frame_sha256": canonical_sha,
        "selected_canonical_actuation_frame": canonical,
        "rapier_host_mapping_sha256": mapping_sha,
        "selected_rapier_host_mapping": mapping,
        "ordered_load_bearing_host_commands": host_commands,
        "ordered_post_step_joint_motor_readbacks_and_impulses": motors,
        "post_step_snapshot": synthetic_snapshot(semantic_step, contact_ids, true),
        "ordered_post_step_joint_position_velocity_observations":
            synthetic_joint_observations(
                &compiled.morphology.ordered_joint_ids,
                semantic_step,
                true,
            ),
        "declared_diagnostic_events": [],
        "ordered_limb_controller_memory_after": synthetic_limb_memory(semantic_step, true),
    }))
}

fn perfect_synthetic_report(
    cell_id: &str,
    authored_friction: f64,
    material_profile_id: &str,
) -> Result<Value, String> {
    let _declaration = preregistration()?;
    declared_material_cell(cell_id, authored_friction, material_profile_id)?;
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
        .map(|semantic_step| synthetic_trace_step(semantic_step, &compiled, &contact_ids))
        .collect::<Result<Vec<_>, _>>()?;
    let evidence_completion_step = EVIDENCE_LIMIT_GAIT_STEP;
    let first_four_contact_acquisition_step = EVIDENCE_LIMIT_GAIT_STEP + 1;
    let consecutive_four_contact_completion_step =
        EVIDENCE_LIMIT_GAIT_STEP + REQUIRED_CONSECUTIVE_ALL_FOUR_CONTACT_STEPS;
    let maximum_consecutive_four_contact_steps = TOTAL_STEPS - first_four_contact_acquisition_step;
    let synthetic_nonzero_bounded_residual_count = trace
        .iter()
        .flat_map(|entry| {
            entry["selected_canonical_actuation_frame"]["ordered_commands"]
                .as_array()
                .into_iter()
                .flatten()
        })
        .filter(|command| command["stability_canonical_velocity_delta_rad_s"] != 0.0)
        .count() as u64;
    let synthetic_nonzero_effective_host_residual_count = trace
        .iter()
        .flat_map(|entry| {
            entry["selected_canonical_actuation_frame"]["ordered_commands"]
                .as_array()
                .into_iter()
                .flatten()
        })
        .filter(|command| {
            command["portable_canonical_target_velocity_rad_s"]
                != command["combined_canonical_target_velocity_rad_s"]
        })
        .count() as u64;
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
        "study_class": "exact_finite_cell_independent_cross_engine_material_validation",
        "cell_id": cell_id,
        "material_profile_id": material_profile_id,
        "authored_sliding_friction": authored_friction,
        "authored_friction_vector": [authored_friction],
        "inherited_worker_contract": "PH1",
        "source_commit": "0000000000000000000000000000000000000000",
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "cross_engine_host_characterization_r2_closure_raw_sha256":
            CROSS_ENGINE_HC_R2_CLOSURE_RAW_SHA256,
        "rapier_spv1_closure_raw_sha256": SPV1_CLOSURE_RAW_SHA256,
        "rapier_ph1_closure_raw_sha256": PH1_CLOSURE_RAW_SHA256,
        "live_integration_raw_sha256": LIVE_INTEGRATION_RAW_SHA256,
        "active_configuration_v2_raw_sha256": ACTIVE_CONFIGURATION_V2_RAW_SHA256,
        "canonical_profile_raw_sha256": CANONICAL_PROFILE_RAW_SHA256,
        "vh1_closure_raw_sha256": VH1_CLOSURE_RAW_SHA256,
        "c2_closure_raw_sha256": C2_CLOSURE_RAW_SHA256,
        "eh1_closure_raw_sha256": EH1_CLOSURE_RAW_SHA256,
        "lc1_closure_raw_sha256": LC1_CLOSURE_RAW_SHA256,
        "ts1_closure_raw_sha256": TS1_CLOSURE_RAW_SHA256,
        "tr1_closure_raw_sha256": TR1_CLOSURE_RAW_SHA256,
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
            "authored_friction": authored_friction,
            "authored_friction_vector": [authored_friction],
            "material_profile_id": material_profile_id,
            "ground_and_every_robot_collider_use_same_friction": true,
            "friction_combine_rule": "min",
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
        "nonzero_bounded_residual_count": synthetic_nonzero_bounded_residual_count,
        "nonzero_effective_host_residual_count":
            synthetic_nonzero_effective_host_residual_count,
        "initial_pose_snapshot": synthetic_snapshot(0, &contact_ids, false),
        "initial_declared_diagnostic_events": [],
        "initial_contact_count": ACTUATOR_COUNT / 2,
        "schedule": declared_schedule(
            Some(evidence_completion_step),
            Some(evidence_completion_step + 1),
            Some(first_four_contact_acquisition_step),
            Some(consecutive_four_contact_completion_step),
            maximum_consecutive_four_contact_steps,
        ),
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
    !full_gate_failures_inner(&candidate, true).is_empty()
}

pub fn run_cross_engine_discrete_material_validation_xv1_rapier_preflight() -> Result<Value, String>
{
    let declaration = preregistration()?;
    let (first_cell_id, first_friction, first_profile_id) = RAPIER_MATERIAL_CELLS[0];
    let synthetic = perfect_synthetic_report(first_cell_id, first_friction, first_profile_id)?;
    let perfect_failures = full_gate_failures(&synthetic);
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_SYNTHETIC_SERIALIZE:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let mut material_synthetic_results = vec![json!({
        "cell_id": first_cell_id,
        "authored_friction": first_friction,
        "material_profile_id": first_profile_id,
        "whole_gate_passed": perfect_failures.is_empty(),
        "serialization_round_trip_passed": round_trip == synthetic,
    })];
    for (cell_id, authored_friction, material_profile_id) in
        RAPIER_MATERIAL_CELLS.iter().skip(1).copied()
    {
        let report = perfect_synthetic_report(cell_id, authored_friction, material_profile_id)?;
        let failures = full_gate_failures(&report);
        let serialized = serde_json::to_string(&report)
            .map_err(|error| format!("C6_XE_BW19V_XV1_RAP_MATERIAL_SYNTHETIC_SERIALIZE:{error}"))?;
        let round_trip: Value = serde_json::from_str(&serialized).map_err(|error| {
            format!("C6_XE_BW19V_XV1_RAP_MATERIAL_SYNTHETIC_ROUND_TRIP:{error}")
        })?;
        material_synthetic_results.push(json!({
            "cell_id": cell_id,
            "authored_friction": authored_friction,
            "material_profile_id": material_profile_id,
            "whole_gate_passed": failures.is_empty(),
            "failure_codes": failures,
            "serialization_round_trip_passed": round_trip == report,
        }));
    }
    let all_material_synthetic_gates_passed = material_synthetic_results.iter().all(|result| {
        result["whole_gate_passed"] == true && result["serialization_round_trip_passed"] == true
    });
    let canaries = vec![
        rejected_after(&synthetic, |report| {
            report["cell_id"] = json!("rapier_mu060");
        }),
        rejected_after(&synthetic, |report| {
            report["authored_sliding_friction"] = json!(0.6);
        }),
        rejected_after(&synthetic, |report| {
            report["material_profile_id"] = json!("rapier_bw19v_xv1_mu060_v1");
        }),
        rejected_after(&synthetic, |report| {
            report["host_configuration"]["authored_friction_vector"] = json!([0.6]);
        }),
        rejected_after(&synthetic, |report| {
            report["cross_engine_host_characterization_r2_closure_raw_sha256"] =
                json!("sha256:wrong");
        }),
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
            report["ordered_trace"][1]["command_composition"]["ordered_canonical_residuals"][0]["canonical_velocity_delta_rad_s"] =
                json!(0.0);
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
            report["ordered_trace"][0]["ordered_limb_controller_memory_before"][1]["limb_id"] =
                json!("rear_left");
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][0]["ordered_limb_controller_memory_after"]
                .as_array_mut()
                .unwrap()
                .pop();
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["ordered_limb_controller_memory_before"]
                [0]["evidence_gait_step_limit"] = json!(EVIDENCE_LIMIT_GAIT_STEP - 1);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["policy_id"] = json!("wrong_restorer");
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["missing_limb_desired_foot_velocity_world_m_s"]["y"] = json!(-0.03);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["damped_least_squares_lambda_m"] = json!(0.05);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["maximum_absolute_search_joint_velocity_rad_s"] = json!(0.36);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 2) as usize]["command_composition"]
                ["receipt"]["pose_hold_position_gain_per_s"] = json!(7.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 2) as usize]["command_composition"]
                ["receipt"]["pose_hold_rate_damping"] = json!(0.5);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 3) as usize]["command_composition"]
                ["receipt"]["ordered_limb_solutions"][0]["ordered_actuator_solutions"][0]["neutral_joint_position_rad"] =
                json!(0.5);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 2) as usize]["command_composition"]
                ["receipt"]["ordered_limb_solutions"][0]["ordered_actuator_solutions"][0]["portable_heading_target_delta_rad"] =
                json!(0.01);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["ordered_limb_solutions"][0]["ordered_actuator_solutions"][0]["neutral_joint_position_rad"] =
                json!(0.0);
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]
                ["ordered_pre_step_joint_position_velocity_observations"]
                .as_array_mut()
                .unwrap()
                .pop();
        }),
        rejected_after(&synthetic, |report| {
            report["ordered_trace"][(EVIDENCE_LIMIT_GAIT_STEP + 1) as usize]["command_composition"]
                ["receipt"]["ordered_limb_solutions"][0]["ordered_actuator_solutions"][0]["kinematics"]
                ["endpoint_world_m"]["x"] = json!(0.25);
        }),
        rejected_after(&synthetic, |report| {
            report["schedule"]["terminal_restoration_phase"]["first_four_contact_acquisition_semantic_step"] =
                json!(TERMINAL_ACQUISITION_DEADLINE_EXCLUSIVE);
        }),
        rejected_after(&synthetic, |report| {
            for step in [2_200_usize, 2_500, 2_800, 3_100] {
                report["ordered_trace"][step]["post_step_snapshot"]["ordered_declared_contacts"]
                    ["front_left_foot"] = json!(false);
            }
        }),
        rejected_after(&synthetic, |report| {
            let final_entry = report["ordered_trace"]
                .as_array_mut()
                .unwrap()
                .last_mut()
                .unwrap();
            final_entry["post_step_snapshot"]["ordered_declared_contacts"]["front_left_foot"] =
                json!(false);
            report["terminal_four_contact_stance"] = json!(false);
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
        && synthetic["nonzero_bounded_residual_count"]
            .as_u64()
            .is_some_and(|count| count > 0)
        && synthetic["nonzero_effective_host_residual_count"]
            .as_u64()
            .is_some_and(|count| count > 0);
    let production_memory = BalancedWaveControllerMemory::initial();
    let real_memory_order = production_memory
        .ordered_limb_memory
        .iter()
        .map(|limb| limb.limb_id.as_str())
        .collect::<Vec<_>>();
    let synthetic_memory_order =
        synthetic["ordered_trace"][0]["ordered_limb_controller_memory_before"]
            .as_array()
            .into_iter()
            .flatten()
            .filter_map(|entry| entry["limb_id"].as_str())
            .collect::<Vec<_>>();
    let morphology_order = synthetic["ordered_limb_ids"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .collect::<Vec<_>>();
    let production_scheduler_order_memory_witness_passed = real_memory_order
        == SCHEDULER_ORDERED_LIMB_IDS
        && synthetic_memory_order == SCHEDULER_ORDERED_LIMB_IDS
        && morphology_order == MORPHOLOGY_ORDERED_LIMB_IDS
        && real_memory_order != morphology_order;
    let all_canaries_rejected = canaries.iter().all(|rejected| *rejected);
    let ok = declaration["preflight_contract"]["model_or_world_build_count"] == 0
        && VELOCITY_ONLY_LIVE_PROFILE_ID == "rapier_force_based_velocity_only_v1"
        && perfect_failures.is_empty()
        && round_trip == synthetic
        && all_material_synthetic_gates_passed
        && saturated_residual_case_passed
        && production_scheduler_order_memory_witness_passed
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
        "declared_material_cell_count": RAPIER_MATERIAL_CELLS.len(),
        "all_declared_material_synthetic_gates_passed":
            all_material_synthetic_gates_passed,
        "material_synthetic_results": material_synthetic_results,
        "perfect_synthetic_whole_gate_passed": perfect_failures.is_empty(),
        "perfect_synthetic_failures": perfect_failures,
        "positive_saturated_residual_case_passed": saturated_residual_case_passed,
        "production_scheduler_order_memory_witness_passed":
            production_scheduler_order_memory_witness_passed,
        "production_scheduler_ordered_limb_ids": real_memory_order,
        "morphology_ordered_limb_ids": morphology_order,
        "synthetic_memory_ordered_limb_ids": synthetic_memory_order,
        "limb_memory_matched_by_explicit_limb_id": true,
        "evidence_schedule_identity_is_exact": evidence_schedule_identity_is_exact(),
        "synthetic_nonzero_bounded_residual_count":
            synthetic["nonzero_bounded_residual_count"],
        "synthetic_nonzero_effective_host_residual_count":
            synthetic["nonzero_effective_host_residual_count"],
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
        let report =
            perfect_synthetic_report("rapier_mu020", 0.2, "rapier_bw19v_xv1_mu020_v1").unwrap();
        let failures = full_gate_failures(&report);
        assert!(failures.is_empty(), "synthetic failures: {failures:?}");
        assert_eq!(report["preflight"]["world_build_count"], 0);
        assert!(report["nonzero_bounded_residual_count"].as_u64().unwrap() > 0);
        assert!(
            report["nonzero_effective_host_residual_count"]
                .as_u64()
                .unwrap()
                > 0
        );
    }

    #[test]
    fn evidence_freeze_is_exact_and_memory_evaluation_is_identity_based() {
        assert!(evidence_schedule_identity_is_exact());
        let morphology_ids = MORPHOLOGY_ORDERED_LIMB_IDS
            .iter()
            .map(|id| (*id).to_owned())
            .collect::<Vec<_>>();
        let mut memory = synthetic_limb_memory(EVIDENCE_LIMIT_GAIT_STEP, true);
        assert!(memory_is_at_declared_limit(
            &Value::Array(memory.clone()),
            &morphology_ids,
            EVIDENCE_LIMIT_GAIT_STEP,
        ));
        memory.reverse();
        assert!(memory_is_at_declared_limit(
            &Value::Array(memory),
            &morphology_ids,
            EVIDENCE_LIMIT_GAIT_STEP,
        ));
    }

    #[test]
    fn undeclared_material_identity_is_rejected_before_world_construction() {
        assert!(declared_material_cell("rapier_mu999", 0.2, "rapier_bw19v_xv1_mu020_v1").is_err());
        assert!(declared_material_cell("rapier_mu020", 0.6, "rapier_bw19v_xv1_mu020_v1").is_err());
        assert!(declared_material_cell("rapier_mu020", 0.2, "wrong_profile").is_err());
    }
}
