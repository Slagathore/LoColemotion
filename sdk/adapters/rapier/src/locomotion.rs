use std::collections::{BTreeMap, HashMap};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{
    ActuationFrame, CommandAuthority, ContactObservation, ContactProvenance, ContactQuality,
    JointObservation, JointValidityMask, MOTION_COMMAND_VERSION, MotionCommand,
    PhaseProgressionMode, Pose, Quaternion, STATE_FRAME_VERSION, SpeedClass, StateFrame, TaskFrame,
    Twist,
};
use sporespore_locomotion_core::schema::{CollisionShape, Vec3};
use sporespore_locomotion_core::stability::{
    EndpointForceActuatorKinematicsV2, OrderedBodyStateV2, StabilityStateV2, SupportContactStateV2,
};
use sporespore_locomotion_core::{
    BalancedWaveController, BalancedWaveControllerMemory, BoundedQuadrupedDescriptor,
    CompiledQuadruped, RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID,
    SELECTED_BALANCED_WAVE_POLICY_ID, VelocityOnlyHostMappingReceiptV1, compile_bounded_quadruped,
    digest_serializable,
};

use crate::{
    ADAPTER_ID, RAPIER_DT_S,
    active_configuration::new_active_world,
    actuator_cap_profile::RapierPublicActuatorCapBindingV1,
    bw19v_composition::{
        BW19V_AUTHORED_FRICTION, RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
        RapierBw19vComposedCommand,
    },
    capability_manifest_sha256,
    velocity_only_live_integration::{
        build_velocity_only_joint_v1, update_velocity_only_motor_v1,
        velocity_only_maximum_force_from_outer_impulse_v1,
        velocity_only_small_step_impulse_limit_v1,
    },
};

const PREREGISTRATION: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_preregistration.json");
const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:5d1f77ae8b84bd2fa32f2cd7c71613b0f0c01b03ecbc88b4ca0deba9670bb440";
const R1_PREREGISTRATION: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_r1_preregistration.json");
const R1_PREREGISTRATION_RAW_SHA256: &str =
    "sha256:3102a8dddb8f6c7236735e2cdc6b403763d000a6b1518d55c201a7627e00a37f";
const R2_PREREGISTRATION: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_r2_preregistration.json");
const R2_PREREGISTRATION_RAW_SHA256: &str =
    "sha256:fe0b6d23f1262d1d3ead5621f6c8042c48ae016afebbdac20d51c52671ff7ec9";
const PREDECESSOR_CLOSURE: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_closure.json");
const PREDECESSOR_CLOSURE_RAW_SHA256: &str =
    "sha256:b7f461bcadff96069e14b85357e58b97c61c555903792b99c37116e17ee31557";
const R1_CLOSURE: &str =
    include_str!("../../../rapier_c6_selected_policy_commissioning_r1_closure.json");
const R1_CLOSURE_RAW_SHA256: &str =
    "sha256:0fe513b1af8fe386f4d9c13d7485f4bdfd37711d38a846a938fab11270b0e9fb";
const CAMPAIGN_ID: &str = "C6-RAPIER-SELECTED-POLICY-COMMISSIONING";
const GATE_ID: &str = "C6-RAP-SP1";
const R1_CAMPAIGN_ID: &str = "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R1";
const R1_GATE_ID: &str = "C6-RAP-SP1-R1";
const R2_CAMPAIGN_ID: &str = "C6-RAPIER-SELECTED-POLICY-COMMISSIONING-R2";
const R2_GATE_ID: &str = "C6-RAP-SP1-R2";
const DT_S: f32 = RAPIER_DT_S;
const SETTLE_STEPS: u64 = 240;
const CONTACT_GATED_START_STEP: u64 = 472;
const EVIDENCE_GAIT_STEPS: u64 = 1440;
const MAXIMUM_EVIDENCE_EXTENSION_STEPS: u64 = 720;
const COOLDOWN_STEPS: u64 = 360;
const TERMINAL_SETTLE_STEPS: u64 = 240;
const MAXIMUM_CONTROLLER_SEMANTIC_STEPS: u64 = 3232;
const MOTOR_STIFFNESS: f32 = 40.0;
const MOTOR_DAMPING: f32 = 10.0;
const MOTOR_FORCE_MARGIN: f32 = 1.015;

const MINIMUM_FOOT_RELOCATION_M: f64 = 0.01194880859375;
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

fn raw_sha256(bytes: &[u8]) -> String {
    format!("sha256:{:x}", Sha256::digest(bytes))
}

pub(crate) fn descriptor() -> BoundedQuadrupedDescriptor {
    BoundedQuadrupedDescriptor {
        schema_version: "sporespore_bounded_quadruped_descriptor_v1".to_owned(),
        morphology_id: "qsdk_r05_generated_s169".to_owned(),
        torso_length_scale: 1.0041015625,
        torso_width_scale: 1.0031893004115227,
        upper_length_fraction: 0.5219571428571428,
        hip_span_scale: 0.9856413994169096,
        foot_radius_scale: 0.9987180691209617,
        front_limb_mass_scale: 0.975022758306782,
    }
}

pub(crate) fn live_explorer_scene() -> Result<Value, String> {
    let descriptor = descriptor();
    let compiled =
        compile_bounded_quadruped(descriptor.clone()).map_err(|error| error.to_string())?;
    Ok(json!({
        "descriptor": descriptor,
        "morphology_spec": compiled.morphology.morphology_spec,
        "coordinate_frame": "canonical_x_forward_y_up_z_right",
    }))
}

fn compile_declared_boundary() -> Result<(CompiledQuadruped, BalancedWaveController), String> {
    let compiled = compile_bounded_quadruped(descriptor()).map_err(|error| error.to_string())?;
    let controller =
        BalancedWaveController::new_for_policy(compiled.clone(), SELECTED_BALANCED_WAVE_POLICY_ID)
            .map_err(|error| error.to_string())?;
    Ok((compiled, controller))
}

fn bool_at(value: &Value, pointer: &str) -> bool {
    value.pointer(pointer).and_then(Value::as_bool) == Some(true)
}

fn u64_at(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer).and_then(Value::as_u64)
}

fn f64_at(value: &Value, pointer: &str) -> Option<f64> {
    value.pointer(pointer).and_then(Value::as_f64)
}

fn full_integrity_failures(report: &Value) -> Vec<String> {
    let mut failures = Vec::new();
    let exact_u64 = [
        ("/world_attempt_count", 1, "world_attempt_count"),
        ("/world_build_count", 1, "world_build_count"),
        ("/world_reset_count", 0, "world_reset_count"),
        ("/body_count", 9, "body_count"),
        ("/joint_count", 8, "joint_count"),
        ("/actuator_count", 8, "actuator_count"),
        ("/direct_body_write_count", 0, "direct_body_write_count"),
        ("/controller_error_count", 0, "controller_error_count"),
        ("/safe_no_actuation_count", 0, "safe_no_actuation_count"),
        (
            "/nonfinite_observation_count",
            0,
            "nonfinite_observation_count",
        ),
        (
            "/actuator_application_mismatch_count",
            0,
            "actuator_application_mismatch_count",
        ),
        (
            "/motor_impulse_limit_violation_count",
            0,
            "motor_impulse_limit_violation_count",
        ),
    ];
    for (pointer, expected, name) in exact_u64 {
        if u64_at(report, pointer) != Some(expected) {
            failures.push(format!("C6_RAP_SP1_{name}_INVALID"));
        }
    }
    let controller_steps = u64_at(report, "/controller_semantic_step_count");
    let command_count = u64_at(report, "/validated_portable_command_count");
    let application_count = u64_at(report, "/native_motor_application_count");
    if controller_steps.is_none()
        || controller_steps == Some(0)
        || command_count != controller_steps.map(|steps| steps * 8)
        || application_count != command_count
    {
        failures.push("C6_RAP_SP1_COMMAND_APPLICATION_ACCOUNTING_INVALID".to_owned());
    }
    for (pointer, name) in [
        (
            "/schedule/evidence_limits_reached",
            "evidence_limits_not_reached",
        ),
        ("/schedule/cooldown_completed", "cooldown_incomplete"),
        (
            "/schedule/terminal_settle_completed",
            "terminal_settle_incomplete",
        ),
        ("/initial_four_contact_stance", "initial_stance"),
        ("/terminal_four_contact_recovery", "terminal_stance"),
        ("/zero_torso_ground_contact", "torso_ground_contact"),
    ] {
        if !bool_at(report, pointer) {
            failures.push(format!("C6_RAP_SP1_{name}"));
        }
    }
    let metric_checks = [
        (
            f64_at(report, "/metrics/evidence_forward_displacement_m")
                .is_some_and(|value| value >= MINIMUM_EVIDENCE_ADVANCE_M),
            "evidence_advance",
        ),
        (
            f64_at(report, "/metrics/final_forward_displacement_m")
                .is_some_and(|value| value >= MINIMUM_FINAL_ADVANCE_M),
            "final_advance",
        ),
        (
            f64_at(report, "/metrics/final_lateral_displacement_m")
                .is_some_and(|value| value.abs() <= MAXIMUM_LATERAL_DRIFT_M),
            "lateral_drift",
        ),
        (
            f64_at(report, "/metrics/final_yaw_drift_rad")
                .is_some_and(|value| value.abs() <= MAXIMUM_YAW_DRIFT_RAD),
            "yaw_drift",
        ),
        (
            f64_at(report, "/metrics/maximum_tilt_rad")
                .is_some_and(|value| value <= MAXIMUM_TILT_RAD),
            "tilt",
        ),
        (
            f64_at(report, "/metrics/minimum_torso_height_m")
                .is_some_and(|value| value >= MINIMUM_TORSO_HEIGHT_M),
            "torso_height",
        ),
        (
            f64_at(report, "/metrics/maximum_anchor_error_m")
                .is_some_and(|value| value <= MAXIMUM_ANCHOR_ERROR_M),
            "anchor_error",
        ),
        (
            f64_at(report, "/metrics/maximum_hinge_axis_error_rad")
                .is_some_and(|value| value <= MAXIMUM_HINGE_AXIS_ERROR_RAD),
            "hinge_axis_error",
        ),
    ];
    for (passed, name) in metric_checks {
        if !passed {
            failures.push(format!("C6_RAP_SP1_{name}_GATE_FAILED"));
        }
    }
    let Some(limbs) = report.pointer("/limb_evidence").and_then(Value::as_object) else {
        failures.push("C6_RAP_SP1_LIMB_EVIDENCE_MISSING".to_owned());
        return failures;
    };
    for limb_id in ["front_left", "front_right", "rear_left", "rear_right"] {
        let Some(limb) = limbs.get(limb_id) else {
            failures.push(format!("C6_RAP_SP1_LIMB_EVIDENCE_MISSING_{limb_id}"));
            continue;
        };
        if u64_at(limb, "/contact_cycles").unwrap_or(0) < MINIMUM_CONTACT_CYCLES_PER_LIMB {
            failures.push(format!("C6_RAP_SP1_CONTACT_CYCLES_{limb_id}"));
        }
        if f64_at(limb, "/maximum_foot_relocation_m").unwrap_or(f64::NEG_INFINITY)
            < MINIMUM_FOOT_RELOCATION_M
        {
            failures.push(format!("C6_RAP_SP1_FOOT_RELOCATION_{limb_id}"));
        }
        if u64_at(limb, "/maximum_airborne_dwell_steps").unwrap_or(0) < MINIMUM_AIRBORNE_DWELL_STEPS
        {
            failures.push(format!("C6_RAP_SP1_AIRBORNE_DWELL_{limb_id}"));
        }
    }
    failures
}

pub(crate) fn full_integrity_failures_for(report: &Value, failure_prefix: &str) -> Vec<String> {
    full_integrity_failures(report)
        .into_iter()
        .map(|failure| failure.replacen("C6_RAP_SP1", failure_prefix, 1))
        .collect()
}

fn perfect_synthetic_report() -> Value {
    let limb = || {
        json!({
            "contact_cycles": MINIMUM_CONTACT_CYCLES_PER_LIMB,
            "maximum_foot_relocation_m": MINIMUM_FOOT_RELOCATION_M,
            "maximum_airborne_dwell_steps": MINIMUM_AIRBORNE_DWELL_STEPS,
        })
    };
    json!({
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": 9,
        "joint_count": 8,
        "actuator_count": 8,
        "direct_body_write_count": 0,
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
        "motor_impulse_limit_violation_count": 0,
        "controller_semantic_step_count": 1,
        "validated_portable_command_count": 8,
        "native_motor_application_count": 8,
        "schedule": {
            "evidence_limits_reached": true,
            "cooldown_completed": true,
            "terminal_settle_completed": true,
        },
        "initial_four_contact_stance": true,
        "terminal_four_contact_recovery": true,
        "zero_torso_ground_contact": true,
        "metrics": {
            "evidence_forward_displacement_m": MINIMUM_EVIDENCE_ADVANCE_M,
            "final_forward_displacement_m": MINIMUM_FINAL_ADVANCE_M,
            "final_lateral_displacement_m": MAXIMUM_LATERAL_DRIFT_M,
            "final_yaw_drift_rad": MAXIMUM_YAW_DRIFT_RAD,
            "maximum_tilt_rad": MAXIMUM_TILT_RAD,
            "minimum_torso_height_m": MINIMUM_TORSO_HEIGHT_M,
            "maximum_anchor_error_m": MAXIMUM_ANCHOR_ERROR_M,
            "maximum_hinge_axis_error_rad": MAXIMUM_HINGE_AXIS_ERROR_RAD,
        },
        "limb_evidence": {
            "front_left": limb(),
            "front_right": limb(),
            "rear_left": limb(),
            "rear_right": limb(),
        },
    })
}

pub fn run_selected_policy_commissioning_preflight() -> Result<Value, String> {
    if raw_sha256(PREREGISTRATION.as_bytes()) != PREREGISTRATION_RAW_SHA256 {
        return Err("C6_RAP_SP1_PREREGISTRATION_HASH_MISMATCH".to_owned());
    }
    let preregistration: Value = serde_json::from_str(PREREGISTRATION)
        .map_err(|error| format!("C6_RAP_SP1_PREREGISTRATION_JSON_INVALID:{error}"))?;
    if preregistration["campaign_id"] != CAMPAIGN_ID
        || preregistration["gate_id"] != GATE_ID
        || preregistration["status"] != "frozen_before_first_c6_rap_sp1_physics_world"
    {
        return Err("C6_RAP_SP1_PREREGISTRATION_IDENTITY_INVALID".to_owned());
    }
    let (compiled, controller) = compile_declared_boundary()?;
    if compiled.world_build_count != 0
        || compiled.morphology.world_build_count != 0
        || controller.profile().policy_id != SELECTED_BALANCED_WAVE_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
    {
        return Err("C6_RAP_SP1_PORTABLE_BOUNDARY_INVALID".to_owned());
    }
    let synthetic = perfect_synthetic_report();
    let perfect_failures = full_integrity_failures(&synthetic);
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("C6_RAP_SP1_SYNTHETIC_SERIALIZATION:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_SP1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let mut canary = synthetic.clone();
    canary["controller_error_count"] = json!(1);
    let canary_failures = full_integrity_failures(&canary);
    let report = json!({
        "schema_version": "sporespore_rapier_c6_selected_policy_commissioning_preflight_v1",
        "ok": perfect_failures.is_empty()
            && round_trip == synthetic
            && canary_failures.iter().any(|failure| failure.contains("controller_error_count")),
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": PREREGISTRATION_RAW_SHA256,
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "portable_morphology_spec_sha256": compiled.morphology.morphology_spec_sha256,
        "portable_controller_profile_sha256":
            digest_serializable(controller.profile()).map_err(|error| error.to_string())?,
        "selected_policy_id": controller.profile().policy_id,
        "selected_policy_branch_surface_count": controller.profile().branch_surfaces.len(),
        "perfect_synthetic_result_passed": perfect_failures.is_empty(),
        "perfect_synthetic_failures": perfect_failures,
        "report_serialization_round_trip_passed": round_trip == synthetic,
        "nonzero_failure_canary_rejected":
            canary_failures.iter().any(|failure| failure.contains("controller_error_count")),
        "nonzero_failure_canary_failures": canary_failures,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    });
    if report["ok"] != true {
        return Err("C6_RAP_SP1_PREFLIGHT_GATE_INVALID".to_owned());
    }
    Ok(report)
}

pub(crate) fn canonical_quaternion(rotation: &Rotation) -> Result<Quaternion, String> {
    let x = rotation.x as f64;
    let y = rotation.y as f64;
    let z = rotation.z as f64;
    let w = rotation.w as f64;
    let norm = (x * x + y * y + z * z + w * w).sqrt();
    if !norm.is_finite() || norm <= f64::EPSILON {
        return Err("C6_RAP_SP1_HOST_QUATERNION_NONFINITE_OR_ZERO".to_owned());
    }
    Ok(Quaternion {
        x: x / norm,
        y: y / norm,
        z: z / norm,
        w: w / norm,
    })
}

pub(crate) fn synthetic_state_frame(
    compiled: &CompiledQuadruped,
    orientation: Quaternion,
) -> StateFrame {
    StateFrame {
        schema_version: STATE_FRAME_VERSION.to_owned(),
        semantic_step: 0,
        sample_time_s: 0.0,
        base_pose_world: Pose {
            position_m: Vec3 {
                x: 0.0,
                y: compiled.geometry.initial_torso_center_y_m,
                z: 0.0,
            },
            orientation_xyzw: orientation,
        },
        base_twist_world: Twist {
            linear_velocity_m_s: Vec3::ZERO,
            angular_velocity_rad_s: Vec3::ZERO,
        },
        ordered_joint_observations: compiled
            .morphology
            .ordered_joint_ids
            .iter()
            .map(|joint_id| JointObservation {
                joint_id: joint_id.clone(),
                position_rad: Some(0.0),
                velocity_rad_s: Some(0.0),
                anchor_error_m: Some(0.0),
                validity: JointValidityMask {
                    position: true,
                    velocity: true,
                    anchor_error: true,
                },
            })
            .collect(),
        ordered_contact_observations: compiled
            .morphology
            .ordered_contact_site_ids
            .iter()
            .map(|contact_site_id| ContactObservation {
                contact_site_id: contact_site_id.clone(),
                presence: Some(true),
                bears_support: Some(true),
                normal_load_n: None,
                provenance: ContactProvenance {
                    adapter_id: ADAPTER_ID.to_owned(),
                    engine_contact_ids: vec![format!("synthetic_pair_{contact_site_id}")],
                    aggregation_rule_id: "rapier_active_pair_presence_equals_support_bearing_v1"
                        .to_owned(),
                    quality: ContactQuality::QualifiedBearing,
                    impulse_source_profile_id: None,
                    impulse_source_kind: None,
                },
            })
            .collect(),
        previous_applied_actuation: None,
        gravity_world_m_s2: Vec3 {
            x: 0.0,
            y: -9.8,
            z: 0.0,
        },
        task_frame: TaskFrame {
            origin_world_m: Vec3::ZERO,
            forward_axis_world_unit: Vec3 {
                x: 1.0,
                y: 0.0,
                z: 0.0,
            },
            lateral_axis_world_unit: Vec3 {
                x: 0.0,
                y: 0.0,
                z: 1.0,
            },
            up_axis_world_unit: Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            },
            reference_yaw_rad: 0.0,
        },
        adapter_capability_sha256: capability_manifest_sha256(),
    }
}

pub(crate) fn state_contains_nonfinite(state: &StateFrame) -> bool {
    let base_values = [
        state.sample_time_s,
        state.base_pose_world.position_m.x,
        state.base_pose_world.position_m.y,
        state.base_pose_world.position_m.z,
        state.base_pose_world.orientation_xyzw.x,
        state.base_pose_world.orientation_xyzw.y,
        state.base_pose_world.orientation_xyzw.z,
        state.base_pose_world.orientation_xyzw.w,
        state.base_twist_world.linear_velocity_m_s.x,
        state.base_twist_world.linear_velocity_m_s.y,
        state.base_twist_world.linear_velocity_m_s.z,
        state.base_twist_world.angular_velocity_rad_s.x,
        state.base_twist_world.angular_velocity_rad_s.y,
        state.base_twist_world.angular_velocity_rad_s.z,
        state.gravity_world_m_s2.x,
        state.gravity_world_m_s2.y,
        state.gravity_world_m_s2.z,
        state.task_frame.origin_world_m.x,
        state.task_frame.origin_world_m.y,
        state.task_frame.origin_world_m.z,
        state.task_frame.forward_axis_world_unit.x,
        state.task_frame.forward_axis_world_unit.y,
        state.task_frame.forward_axis_world_unit.z,
        state.task_frame.lateral_axis_world_unit.x,
        state.task_frame.lateral_axis_world_unit.y,
        state.task_frame.lateral_axis_world_unit.z,
        state.task_frame.up_axis_world_unit.x,
        state.task_frame.up_axis_world_unit.y,
        state.task_frame.up_axis_world_unit.z,
        state.task_frame.reference_yaw_rad,
    ];
    !base_values.into_iter().all(f64::is_finite)
        || state.ordered_joint_observations.iter().any(|joint| {
            joint.position_rad.is_some_and(|value| !value.is_finite())
                || joint.velocity_rad_s.is_some_and(|value| !value.is_finite())
                || joint.anchor_error_m.is_some_and(|value| !value.is_finite())
        })
        || state.ordered_contact_observations.iter().any(|contact| {
            contact
                .normal_load_n
                .is_some_and(|value| !value.is_finite())
        })
}

pub fn run_selected_policy_commissioning_r1_preflight() -> Result<Value, String> {
    if raw_sha256(R1_PREREGISTRATION.as_bytes()) != R1_PREREGISTRATION_RAW_SHA256 {
        return Err("C6_RAP_SP1_R1_PREREGISTRATION_HASH_MISMATCH".to_owned());
    }
    if raw_sha256(PREDECESSOR_CLOSURE.as_bytes()) != PREDECESSOR_CLOSURE_RAW_SHA256 {
        return Err("C6_RAP_SP1_R1_PREDECESSOR_CLOSURE_HASH_MISMATCH".to_owned());
    }
    let preregistration: Value = serde_json::from_str(R1_PREREGISTRATION)
        .map_err(|error| format!("C6_RAP_SP1_R1_PREREGISTRATION_JSON_INVALID:{error}"))?;
    let predecessor: Value = serde_json::from_str(PREDECESSOR_CLOSURE)
        .map_err(|error| format!("C6_RAP_SP1_R1_PREDECESSOR_JSON_INVALID:{error}"))?;
    if preregistration["campaign_id"] != R1_CAMPAIGN_ID
        || preregistration["gate_id"] != R1_GATE_ID
        || preregistration["status"] != "frozen_before_first_c6_rap_sp1_r1_physics_world"
        || predecessor["status"] != "closed_negative_adapter_transport"
        || predecessor["diagnosis"]["same_identity_rerun_allowed"] != false
    {
        return Err("C6_RAP_SP1_R1_DECLARATION_CHAIN_INVALID".to_owned());
    }
    let (compiled, controller) = compile_declared_boundary()?;
    if compiled.world_build_count != 0
        || compiled.morphology.world_build_count != 0
        || compiled.morphology.morphology_spec_sha256
            != preregistration["frozen_inputs"]["portable_morphology_spec_sha256"]
        || controller.profile().policy_id != SELECTED_BALANCED_WAVE_POLICY_ID
        || !controller.profile().branch_surfaces.is_empty()
    {
        return Err("C6_RAP_SP1_R1_PORTABLE_BOUNDARY_INVALID".to_owned());
    }
    let profile_sha256 =
        digest_serializable(controller.profile()).map_err(|error| error.to_string())?;
    if profile_sha256 != preregistration["frozen_inputs"]["portable_controller_profile_sha256"] {
        return Err("C6_RAP_SP1_R1_CONTROLLER_PROFILE_CHANGED".to_owned());
    }
    let host_rotation = Rotation::from_rotation_z(0.731);
    let raw_components = [
        host_rotation.x as f64,
        host_rotation.y as f64,
        host_rotation.z as f64,
        host_rotation.w as f64,
    ];
    let raw_norm_squared = raw_components
        .iter()
        .map(|component| component * component)
        .sum::<f64>();
    let normalized = canonical_quaternion(&host_rotation)?;
    normalized
        .validate("r1_preflight_nonidentity_host_quaternion")
        .map_err(|error| format!("C6_RAP_SP1_R1_NORMALIZED_QUATERNION_INVALID:{error}"))?;
    let synthetic_state = synthetic_state_frame(&compiled, normalized);
    synthetic_state
        .validate(&compiled.morphology)
        .map_err(|error| format!("C6_RAP_SP1_R1_SYNTHETIC_STATE_INVALID:{error}"))?;
    let intentional_null_ignored = synthetic_state.previous_applied_actuation.is_none()
        && !state_contains_nonfinite(&synthetic_state);

    let synthetic = perfect_synthetic_report();
    let perfect_failures = full_integrity_failures_for(&synthetic, "C6_RAP_SP1_R1");
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("C6_RAP_SP1_R1_SYNTHETIC_SERIALIZATION:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_SP1_R1_SYNTHETIC_ROUND_TRIP:{error}"))?;
    let mut canary = synthetic.clone();
    canary["controller_error_count"] = json!(1);
    let canary_failures = full_integrity_failures_for(&canary, "C6_RAP_SP1_R1");
    let canary_rejected = canary_failures
        .iter()
        .any(|failure| failure.contains("controller_error_count"));
    let report = json!({
        "schema_version":
            "sporespore_rapier_c6_selected_policy_commissioning_r1_preflight_v1",
        "ok": perfect_failures.is_empty()
            && round_trip == synthetic
            && canary_rejected
            && intentional_null_ignored,
        "campaign_id": R1_CAMPAIGN_ID,
        "gate_id": R1_GATE_ID,
        "preregistration_raw_sha256": R1_PREREGISTRATION_RAW_SHA256,
        "predecessor_closure_raw_sha256": PREDECESSOR_CLOSURE_RAW_SHA256,
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "portable_morphology_spec_sha256": compiled.morphology.morphology_spec_sha256,
        "portable_controller_profile_sha256": profile_sha256,
        "selected_policy_id": controller.profile().policy_id,
        "selected_policy_branch_surface_count": controller.profile().branch_surfaces.len(),
        "nonidentity_host_quaternion_conversion": {
            "angle_rad": 0.731,
            "raw_promoted_norm_squared": raw_norm_squared,
            "normalized_norm_squared":
                normalized.x * normalized.x
                + normalized.y * normalized.y
                + normalized.z * normalized.z
                + normalized.w * normalized.w,
            "portable_unit_norm_validation_passed": true,
        },
        "intentional_previous_actuation_null_ignored_by_numeric_finiteness_check":
            intentional_null_ignored,
        "perfect_synthetic_result_passed": perfect_failures.is_empty(),
        "perfect_synthetic_failures": perfect_failures,
        "report_serialization_round_trip_passed": round_trip == synthetic,
        "nonzero_failure_canary_rejected": canary_rejected,
        "nonzero_failure_canary_failures": canary_failures,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    });
    if report["ok"] != true {
        return Err("C6_RAP_SP1_R1_PREFLIGHT_GATE_INVALID".to_owned());
    }
    Ok(report)
}

fn perfect_synthetic_observability_receipt() -> Value {
    let actuator = || {
        json!({
            "nonzero_target_position_count": 1,
            "nonzero_target_velocity_count": 1,
            "minimum_target_position_rad": -0.1,
            "maximum_target_position_rad": 0.1,
            "minimum_target_velocity_rad_s": -0.1,
            "maximum_target_velocity_rad_s": 0.1,
            "minimum_observed_joint_angle_rad": -0.1,
            "maximum_observed_joint_angle_rad": 0.1,
            "maximum_motor_impulse_nms": 0.01,
            "maximum_motor_impulse_utilization": 0.5,
        })
    };
    let contact = || {
        json!({
            "bearing_true_step_count": 1,
            "bearing_false_step_count": 1,
            "transition_count": 1,
        })
    };
    let memory = || {
        json!({
            "gait_step": 1,
            "evidence_gait_step_limit": 2,
            "release_hold_step_count": 0,
            "recontact_hold_step_count": 0,
            "gate_timeout_count": 0,
            "phase_sync_hold_step_count": 0,
        })
    };
    json!({
        "post_settle": {
            "torso_position_m": {"x": 0.0, "y": 0.4, "z": 0.0},
            "torso_tilt_rad": 0.0,
            "torso_height_m": 0.4,
            "torso_ground_contact": false,
            "ordered_joint_angles_rad": {},
        },
        "first_torso_ground_contact_semantic_step": null,
        "actuators": {
            "front_left_hip_motor": actuator(),
            "front_left_knee_motor": actuator(),
            "front_right_hip_motor": actuator(),
            "front_right_knee_motor": actuator(),
            "rear_left_hip_motor": actuator(),
            "rear_left_knee_motor": actuator(),
            "rear_right_hip_motor": actuator(),
            "rear_right_knee_motor": actuator(),
        },
        "contacts": {
            "front_left_foot": contact(),
            "front_right_foot": contact(),
            "rear_left_foot": contact(),
            "rear_right_foot": contact(),
        },
        "final_limb_memory": {
            "front_left": memory(),
            "front_right": memory(),
            "rear_left": memory(),
            "rear_right": memory(),
        },
    })
}

fn observability_receipt_complete(receipt: &Value) -> bool {
    let Some(root) = receipt.as_object() else {
        return false;
    };
    if !root.contains_key("first_torso_ground_contact_semantic_step")
        || receipt.pointer("/post_settle/torso_position_m/x").is_none()
        || receipt.pointer("/post_settle/torso_position_m/y").is_none()
        || receipt.pointer("/post_settle/torso_position_m/z").is_none()
        || receipt.pointer("/post_settle/torso_tilt_rad").is_none()
        || receipt.pointer("/post_settle/torso_height_m").is_none()
        || receipt
            .pointer("/post_settle/torso_ground_contact")
            .is_none()
        || receipt
            .pointer("/post_settle/ordered_joint_angles_rad")
            .is_none()
    {
        return false;
    }
    let Some(actuators) = receipt.pointer("/actuators").and_then(Value::as_object) else {
        return false;
    };
    let Some(contacts) = receipt.pointer("/contacts").and_then(Value::as_object) else {
        return false;
    };
    let Some(memory) = receipt
        .pointer("/final_limb_memory")
        .and_then(Value::as_object)
    else {
        return false;
    };
    if actuators.len() != 8 || contacts.len() != 4 || memory.len() != 4 {
        return false;
    }
    let actuator_fields = [
        "nonzero_target_position_count",
        "nonzero_target_velocity_count",
        "minimum_target_position_rad",
        "maximum_target_position_rad",
        "minimum_target_velocity_rad_s",
        "maximum_target_velocity_rad_s",
        "minimum_observed_joint_angle_rad",
        "maximum_observed_joint_angle_rad",
        "maximum_motor_impulse_nms",
        "maximum_motor_impulse_utilization",
    ];
    let contact_fields = [
        "bearing_true_step_count",
        "bearing_false_step_count",
        "transition_count",
    ];
    let memory_fields = [
        "gait_step",
        "evidence_gait_step_limit",
        "release_hold_step_count",
        "recontact_hold_step_count",
        "gate_timeout_count",
        "phase_sync_hold_step_count",
    ];
    actuators.values().all(|value| {
        actuator_fields
            .iter()
            .all(|field| value.get(field).is_some())
    }) && contacts.values().all(|value| {
        contact_fields
            .iter()
            .all(|field| value.get(field).is_some())
    }) && memory
        .values()
        .all(|value| memory_fields.iter().all(|field| value.get(field).is_some()))
}

pub fn run_selected_policy_commissioning_r2_preflight() -> Result<Value, String> {
    if raw_sha256(R2_PREREGISTRATION.as_bytes()) != R2_PREREGISTRATION_RAW_SHA256 {
        return Err("C6_RAP_SP1_R2_PREREGISTRATION_HASH_MISMATCH".to_owned());
    }
    if raw_sha256(R1_CLOSURE.as_bytes()) != R1_CLOSURE_RAW_SHA256 {
        return Err("C6_RAP_SP1_R2_PREDECESSOR_CLOSURE_HASH_MISMATCH".to_owned());
    }
    let preregistration: Value = serde_json::from_str(R2_PREREGISTRATION)
        .map_err(|error| format!("C6_RAP_SP1_R2_PREREGISTRATION_JSON_INVALID:{error}"))?;
    let predecessor: Value = serde_json::from_str(R1_CLOSURE)
        .map_err(|error| format!("C6_RAP_SP1_R2_PREDECESSOR_JSON_INVALID:{error}"))?;
    if preregistration["campaign_id"] != R2_CAMPAIGN_ID
        || preregistration["gate_id"] != R2_GATE_ID
        || preregistration["status"] != "frozen_before_first_c6_rap_sp1_r2_physics_world"
        || predecessor["status"] != "closed_negative_active_controller_host_dynamics"
        || predecessor["disposition"]["same_identity_rerun_allowed"] != false
    {
        return Err("C6_RAP_SP1_R2_DECLARATION_CHAIN_INVALID".to_owned());
    }
    let r1_preflight = run_selected_policy_commissioning_r1_preflight()?;
    let synthetic = perfect_synthetic_observability_receipt();
    let synthetic_passed = observability_receipt_complete(&synthetic);
    let mut canary = synthetic.clone();
    canary
        .as_object_mut()
        .expect("synthetic observability object")
        .remove("post_settle");
    let missing_field_canary_rejected = !observability_receipt_complete(&canary);
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("C6_RAP_SP1_R2_OBSERVABILITY_SERIALIZATION:{error}"))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("C6_RAP_SP1_R2_OBSERVABILITY_ROUND_TRIP:{error}"))?;
    let report = json!({
        "schema_version":
            "sporespore_rapier_c6_selected_policy_commissioning_r2_preflight_v1",
        "ok": r1_preflight["ok"] == true
            && synthetic_passed
            && missing_field_canary_rejected
            && round_trip == synthetic,
        "campaign_id": R2_CAMPAIGN_ID,
        "gate_id": R2_GATE_ID,
        "preregistration_raw_sha256": R2_PREREGISTRATION_RAW_SHA256,
        "predecessor_closure_raw_sha256": R1_CLOSURE_RAW_SHA256,
        "inherited_r1_preflight": r1_preflight,
        "perfect_synthetic_observability_receipt_passed": synthetic_passed,
        "missing_required_observability_field_canary_rejected":
            missing_field_canary_rejected,
        "observability_serialization_round_trip_passed": round_trip == synthetic,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false,
    });
    if report["ok"] != true {
        return Err("C6_RAP_SP1_R2_PREFLIGHT_GATE_INVALID".to_owned());
    }
    Ok(report)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum HostMotorProfile {
    RetainedPositionVelocityV1,
    CanonicalVelocityOnlyV4,
}

#[derive(Clone, Debug)]
pub(crate) struct RapierActuatorForcePlanEntryV1 {
    pub(crate) actuator_id: String,
    pub(crate) joint_id: String,
    pub(crate) portable_maximum_outer_step_impulse_nms: f64,
    pub(crate) maximum_force_nm: f32,
}

/// Pure, complete actuator-force plan compiled before any Rapier model or
/// world is constructed.  The profiled physical constructor consumes this
/// exact plan rather than deriving a second set of motor limits.
#[derive(Clone, Debug)]
pub(crate) struct RapierActuatorForcePlanV1 {
    pub(crate) ordered_entries: Vec<RapierActuatorForcePlanEntryV1>,
    pub(crate) public_profile_bound: bool,
}

/// One production Rapier motor application/readback captured before the
/// corresponding solver step.  R23D62 converts these typed native values into
/// its evaluator-owned actuator/phase observation without inventing a second
/// motor configuration path.
#[derive(Clone, Debug)]
pub(crate) struct RapierR23D62MotorApplicationReadbackV1 {
    pub(crate) actuator_id: String,
    pub(crate) joint_id: String,
    pub(crate) requested_target_position_rad: f64,
    pub(crate) clamped_target_position_rad: f64,
    pub(crate) controller_target_velocity_rad_s: f64,
    pub(crate) maximum_target_speed_rad_s: f64,
    pub(crate) host_applied_target_velocity_rad_s: f64,
    pub(crate) motor_target_velocity_readback_rad_s: f64,
    pub(crate) motor_target_velocity_readback_error_rad_s: f64,
    pub(crate) declared_maximum_impulse_nms: f64,
    pub(crate) motor_maximum_impulse_readback_nms: f64,
    pub(crate) motor_maximum_impulse_readback_error_nms: f64,
    pub(crate) position_saturated: bool,
    pub(crate) velocity_saturated: bool,
    pub(crate) slew_limited: bool,
    pub(crate) target_velocity_readback_matches: bool,
    pub(crate) maximum_impulse_readback_matches: bool,
}

#[derive(Clone, Debug)]
pub(crate) struct RapierR23D62StepReadbackV1 {
    pub(crate) ordered_applications: Vec<RapierR23D62MotorApplicationReadbackV1>,
    pub(crate) native_application_count: u64,
    pub(crate) impulse_violation_count: u64,
}

pub(crate) struct HostRobot {
    pub(crate) world: PhysicsWorld,
    pub(crate) ground_collider: ColliderHandle,
    pub(crate) bodies: HashMap<String, RigidBodyHandle>,
    pub(crate) colliders: HashMap<String, ColliderHandle>,
    pub(crate) joints: HashMap<String, ImpulseJointHandle>,
    pub(crate) actuator_joints: HashMap<String, String>,
    pub(crate) actuator_maximum_force: HashMap<String, f32>,
    motor_profile: HostMotorProfile,
    pub(crate) solver_step_count: u64,
}

fn vector(value: Vec3) -> Vector {
    Vector::new(value.x as f32, value.y as f32, value.z as f32)
}

fn groups(membership: Group, filter: Group) -> InteractionGroups {
    InteractionGroups::new(membership, filter, InteractionTestMode::And)
}

fn robot_collider(
    body: &sporespore_locomotion_core::schema::BodySpec,
    authored_friction: f32,
) -> ColliderBuilder {
    let shape = match body.collision {
        CollisionShape::Box { size_m } => ColliderBuilder::cuboid(
            (size_m.x / 2.0) as f32,
            (size_m.y / 2.0) as f32,
            (size_m.z / 2.0) as f32,
        ),
        CollisionShape::Capsule { radius_m, length_m } => {
            ColliderBuilder::capsule_y((length_m / 2.0) as f32, radius_m as f32)
        }
        CollisionShape::Sphere { radius_m } => ColliderBuilder::ball(radius_m as f32),
    };
    shape
        .mass_properties(MassProperties::new(
            vector(body.center_of_mass_local_m),
            body.mass_kg as f32,
            vector(body.inertia_diagonal_kg_m2),
        ))
        .friction(authored_friction)
        .friction_combine_rule(CoefficientCombineRule::Min)
        .restitution(0.0)
        .collision_groups(groups(Group::GROUP_2, Group::GROUP_1))
}

fn compile_actuator_force_plan_v1(
    compiled: &CompiledQuadruped,
    motor_profile: HostMotorProfile,
    public_profile_binding: Option<&RapierPublicActuatorCapBindingV1>,
) -> Result<RapierActuatorForcePlanV1, String> {
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if let Some(binding) = public_profile_binding {
        if motor_profile != HostMotorProfile::CanonicalVelocityOnlyV4 {
            return Err("QSDK_R23D62_RAP_PROFILE_MOTOR_MODE_INVALID".to_owned());
        }
        let resolution = &binding.resolution_receipt;
        let host = &binding.host_mapping_receipt;
        let host_rows = host["ordered_mappings"]
            .as_array()
            .ok_or_else(|| "QSDK_R23D62_RAP_PROFILE_HOST_ROWS_INVALID".to_owned())?;
        if resolution["requested_profile_id"]
            != sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
            || resolution["profile_sha256"]
                != sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
            || resolution["support_status"] != "supported_exact"
            || resolution["profile"]["supported_morphology_id"] != compiled.morphology_id
            || host["schema_version"]
                != "sporespore_rapier_actuator_cap_profile_zero_world_mapping_v1"
            || host["host_mapping_id"]
                != "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1"
            || host["profile_id"]
                != sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
            || host["profile_sha256"]
                != sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
            || host["validated_actuator_count"] != actuators.len()
            || host["world_build_count"] != 0
            || host["solver_step_count"] != 0
            || host["physics_state_modified"] != false
            || binding.ordered_mappings.len() != actuators.len()
            || host_rows.len() != actuators.len()
        {
            return Err("QSDK_R23D62_RAP_PROFILE_BINDING_HEADER_INVALID".to_owned());
        }

        let mut ordered_entries = Vec::with_capacity(actuators.len());
        for (index, ((actuator, mapping), host_row)) in actuators
            .iter()
            .zip(&binding.ordered_mappings)
            .zip(host_rows)
            .enumerate()
        {
            let expected_force = velocity_only_maximum_force_from_outer_impulse_v1(
                mapping.portable_maximum_outer_step_impulse_nms,
            )?;
            let reconstructed = expected_force as f64 * RAPIER_DT_S as f64;
            let error = (reconstructed - mapping.portable_maximum_outer_step_impulse_nms).abs();
            if actuator.actuator_id != mapping.actuator_id
                || actuator.joint_id != mapping.joint_id
                || mapping.portable_maximum_outer_step_impulse_nms <= 0.0
                || !mapping.portable_maximum_outer_step_impulse_nms.is_finite()
                || mapping.rapier_maximum_force_nm_f32 != expected_force
                || mapping.reconstructed_outer_step_impulse_nms != reconstructed
                || mapping.outer_step_reconstruction_error_nms != error
                || !mapping.outer_step_reconstruction_budget_nms.is_finite()
                || mapping.outer_step_reconstruction_budget_nms < error
                || host_row["actuator_id"] != mapping.actuator_id
                || host_row["joint_id"] != mapping.joint_id
                || host_row["portable_maximum_outer_step_impulse_nms"]
                    != mapping.portable_maximum_outer_step_impulse_nms
                || host_row["rapier_maximum_force_nm_f32"] != expected_force
                || host_row["reconstructed_outer_step_impulse_nms"] != reconstructed
                || host_row["outer_step_reconstruction_error_nms"] != error
                || host_row["outer_step_reconstruction_budget_nms"]
                    != mapping.outer_step_reconstruction_budget_nms
                || host_row["builder_motor_model"] != "ForceBased"
                || host_row["builder_maximum_force_readback_nm_f32"] != expected_force
                || host_row["mutable_maximum_force_readback_nm_f32"] != expected_force
            {
                return Err(format!(
                    "QSDK_R23D62_RAP_PROFILE_BINDING_ENTRY_INVALID:{index}"
                ));
            }
            ordered_entries.push(RapierActuatorForcePlanEntryV1 {
                actuator_id: actuator.actuator_id.clone(),
                joint_id: actuator.joint_id.clone(),
                portable_maximum_outer_step_impulse_nms: mapping
                    .portable_maximum_outer_step_impulse_nms,
                maximum_force_nm: expected_force,
            });
        }
        return Ok(RapierActuatorForcePlanV1 {
            ordered_entries,
            public_profile_bound: true,
        });
    }

    let mut ordered_entries = Vec::with_capacity(actuators.len());
    for actuator in actuators {
        let maximum_force_nm = match motor_profile {
            HostMotorProfile::RetainedPositionVelocityV1 => {
                actuator.maximum_impulse_nms as f32 * MOTOR_FORCE_MARGIN / DT_S
            }
            HostMotorProfile::CanonicalVelocityOnlyV4 => {
                velocity_only_maximum_force_from_outer_impulse_v1(actuator.maximum_impulse_nms)?
            }
        };
        ordered_entries.push(RapierActuatorForcePlanEntryV1 {
            actuator_id: actuator.actuator_id.clone(),
            joint_id: actuator.joint_id.clone(),
            portable_maximum_outer_step_impulse_nms: actuator.maximum_impulse_nms,
            maximum_force_nm,
        });
    }
    Ok(RapierActuatorForcePlanV1 {
        ordered_entries,
        public_profile_bound: false,
    })
}

/// Compile the exact force plan used by the public-profile physical
/// constructor without constructing a model or world.
pub(crate) fn compile_public_profile_actuator_force_plan_v1(
    compiled: &CompiledQuadruped,
    binding: &RapierPublicActuatorCapBindingV1,
) -> Result<RapierActuatorForcePlanV1, String> {
    compile_actuator_force_plan_v1(
        compiled,
        HostMotorProfile::CanonicalVelocityOnlyV4,
        Some(binding),
    )
}

fn build_robot(compiled: &CompiledQuadruped) -> Result<HostRobot, String> {
    build_robot_with_friction(
        compiled,
        1.0,
        HostMotorProfile::RetainedPositionVelocityV1,
        None,
    )
}

pub(crate) fn build_bw19v_robot(compiled: &CompiledQuadruped) -> Result<HostRobot, String> {
    build_robot_with_friction(
        compiled,
        BW19V_AUTHORED_FRICTION,
        HostMotorProfile::RetainedPositionVelocityV1,
        None,
    )
}

/// Build the prospective live-v4 BW19V robot. This constructor is intentionally
/// separate from every retained pre-v4 campaign entry point.
#[allow(dead_code)]
pub(crate) fn build_bw19v_velocity_only_v4_robot(
    compiled: &CompiledQuadruped,
) -> Result<HostRobot, String> {
    build_robot_with_friction(
        compiled,
        BW19V_AUTHORED_FRICTION,
        HostMotorProfile::CanonicalVelocityOnlyV4,
        None,
    )
}

/// Build a fresh live-v4 BW19V material-validation world while leaving every
/// retained commissioning entry point pinned to its original 0.95 coefficient.
/// The successor campaign owns validation of the supplied coefficient and the
/// exact finite material profile identity before this constructor is called.
pub(crate) fn build_bw19v_velocity_only_v4_robot_with_friction(
    compiled: &CompiledQuadruped,
    authored_friction: f32,
) -> Result<HostRobot, String> {
    build_robot_with_friction(
        compiled,
        authored_friction,
        HostMotorProfile::CanonicalVelocityOnlyV4,
        None,
    )
}

/// Build the prospective R23D62 live-v4 robot from the same typed public
/// profile plan exercised by the zero-world production-route gate.
#[allow(dead_code)]
pub(crate) fn build_bw19v_velocity_only_v4_robot_with_public_profile(
    compiled: &CompiledQuadruped,
    authored_friction: f32,
    binding: &RapierPublicActuatorCapBindingV1,
) -> Result<HostRobot, String> {
    build_robot_with_friction(
        compiled,
        authored_friction,
        HostMotorProfile::CanonicalVelocityOnlyV4,
        Some(binding),
    )
}

fn build_robot_with_friction(
    compiled: &CompiledQuadruped,
    authored_friction: f32,
    motor_profile: HostMotorProfile,
    public_profile_binding: Option<&RapierPublicActuatorCapBindingV1>,
) -> Result<HostRobot, String> {
    if !authored_friction.is_finite() || authored_friction < 0.0 {
        return Err("C6_RAP_SP1_AUTHORED_FRICTION_INVALID".to_owned());
    }
    // This complete plan is validated before the first native model or world
    // object is constructed.  The joint-building loop below only consumes it.
    let actuator_force_plan =
        compile_actuator_force_plan_v1(compiled, motor_profile, public_profile_binding)?;
    let mut world = new_active_world(Vector::new(0.0, -9.8, 0.0));
    let (_ground_body, ground_collider) = world.insert(
        RigidBodyBuilder::fixed().translation(Vector::new(0.0, -0.05, 0.0)),
        ColliderBuilder::cuboid(10.0, 0.05, 10.0)
            .friction(authored_friction)
            .friction_combine_rule(CoefficientCombineRule::Min)
            .restitution(0.0)
            .collision_groups(groups(Group::GROUP_1, Group::GROUP_2)),
    );

    let mut positions = HashMap::<String, Vector>::new();
    positions.insert(
        "torso".to_owned(),
        Vector::new(0.0, compiled.geometry.initial_torso_center_y_m as f32, 0.0),
    );
    for body in &compiled.morphology.morphology_spec.bodies {
        if body.body_id == "torso" {
            continue;
        }
        let joint = compiled
            .morphology
            .morphology_spec
            .joints
            .iter()
            .find(|joint| joint.child_body_id == body.body_id)
            .ok_or_else(|| format!("C6_RAP_SP1_CHILD_JOINT_MISSING:{}", body.body_id))?;
        let parent = *positions
            .get(&joint.parent_body_id)
            .ok_or_else(|| format!("C6_RAP_SP1_PARENT_POSE_MISSING:{}", joint.parent_body_id))?;
        positions.insert(
            body.body_id.clone(),
            parent + vector(joint.anchor_parent_m) - vector(joint.anchor_child_m),
        );
    }

    let mut bodies = HashMap::new();
    let mut colliders = HashMap::new();
    for body in &compiled.morphology.morphology_spec.bodies {
        let position = *positions
            .get(&body.body_id)
            .ok_or_else(|| format!("C6_RAP_SP1_BODY_POSE_MISSING:{}", body.body_id))?;
        let (body_handle, collider_handle) = world.insert(
            RigidBodyBuilder::dynamic()
                .translation(position)
                .can_sleep(false)
                .ccd_enabled(true),
            robot_collider(body, authored_friction),
        );
        bodies.insert(body.body_id.clone(), body_handle);
        colliders.insert(body.body_id.clone(), collider_handle);
    }

    let actuator_for_joint = compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .map(|actuator| (actuator.joint_id.as_str(), actuator))
        .collect::<HashMap<_, _>>();
    let mut joints = HashMap::new();
    let mut actuator_joints = HashMap::new();
    let mut actuator_maximum_force = HashMap::new();
    for joint in &compiled.morphology.morphology_spec.joints {
        let actuator = actuator_for_joint
            .get(joint.joint_id.as_str())
            .ok_or_else(|| format!("C6_RAP_SP1_JOINT_ACTUATOR_MISSING:{}", joint.joint_id))?;
        let plan_entry = actuator_force_plan
            .ordered_entries
            .iter()
            .find(|entry| {
                entry.actuator_id == actuator.actuator_id && entry.joint_id == joint.joint_id
            })
            .ok_or_else(|| {
                format!(
                    "C6_RAP_SP1_ACTUATOR_FORCE_PLAN_MISSING:{}",
                    actuator.actuator_id
                )
            })?;
        let maximum_force = plan_entry.maximum_force_nm;
        let builder = RevoluteJointBuilder::new(Vector::Z)
            .local_anchor1(vector(joint.anchor_parent_m))
            .local_anchor2(vector(joint.anchor_child_m))
            .limits([joint.lower_limit_rad as f32, joint.upper_limit_rad as f32]);
        let joint_data = match motor_profile {
            HostMotorProfile::RetainedPositionVelocityV1 => builder
                .motor(0.0, 0.0, MOTOR_STIFFNESS, MOTOR_DAMPING)
                .motor_model(MotorModel::ForceBased)
                .motor_max_force(maximum_force)
                .build(),
            HostMotorProfile::CanonicalVelocityOnlyV4 => {
                build_velocity_only_joint_v1(builder, 0.0, maximum_force)?
            }
        };
        let handle = world.insert_impulse_joint(
            *bodies
                .get(&joint.parent_body_id)
                .ok_or_else(|| "C6_RAP_SP1_JOINT_PARENT_MISSING".to_owned())?,
            *bodies
                .get(&joint.child_body_id)
                .ok_or_else(|| "C6_RAP_SP1_JOINT_CHILD_MISSING".to_owned())?,
            joint_data,
        );
        joints.insert(joint.joint_id.clone(), handle);
        actuator_joints.insert(actuator.actuator_id.clone(), joint.joint_id.clone());
        actuator_maximum_force.insert(actuator.actuator_id.clone(), maximum_force);
    }
    Ok(HostRobot {
        world,
        ground_collider,
        bodies,
        colliders,
        joints,
        actuator_joints,
        actuator_maximum_force,
        motor_profile,
        solver_step_count: 0,
    })
}

impl HostRobot {
    fn apply_live_explorer_impulses(&mut self) -> Result<Value, String> {
        let impulses = crate::live_explorer::take_due_rapier_impulses()?;
        let mut receipts = Vec::with_capacity(impulses.len());
        for impulse in impulses {
            let handle = *self
                .bodies
                .get(&impulse.target_body_id)
                .ok_or_else(|| "LIVE_EXPLORER_RAPIER_IMPULSE_TARGET_MISSING".to_owned())?;
            self.world.bodies[handle].apply_impulse(
                Vector::new(impulse.x_n_s, impulse.y_n_s, impulse.z_n_s),
                true,
            );
            receipts.push(json!({
                "command_id": impulse.command_id,
                "target_body_id": impulse.target_body_id,
                "apply_at_frame": impulse.apply_at_frame,
                "native_application": "RigidBody::apply_impulse",
                "impulse_n_s": {
                    "x": impulse.x_n_s,
                    "y": impulse.y_n_s,
                    "z": impulse.z_n_s,
                },
            }));
        }
        Ok(json!(receipts))
    }

    fn live_explorer_frame_payload(&self) -> Result<Value, String> {
        let mut body_ids = self.bodies.keys().cloned().collect::<Vec<_>>();
        body_ids.sort();
        let mut ordered_bodies = Vec::with_capacity(body_ids.len());
        let mut ordered_body_ground_contacts = Vec::with_capacity(body_ids.len());
        for body_id in body_ids {
            let body = &self.world.bodies[*self
                .bodies
                .get(&body_id)
                .ok_or_else(|| format!("LIVE_EXPLORER_RAPIER_BODY_MISSING:{body_id}"))?];
            let quaternion = body.rotation();
            ordered_bodies.push(json!({
                "body_id": body_id,
                "position_m": {
                    "x": body.translation().x,
                    "y": body.translation().y,
                    "z": body.translation().z,
                },
                "orientation_xyzw": {
                    "x": quaternion.x,
                    "y": quaternion.y,
                    "z": quaternion.z,
                    "w": quaternion.w,
                },
                "linear_velocity_m_s": {
                    "x": body.linvel().x,
                    "y": body.linvel().y,
                    "z": body.linvel().z,
                },
                "angular_velocity_rad_s": {
                    "x": body.angvel().x,
                    "y": body.angvel().y,
                    "z": body.angvel().z,
                },
            }));
            ordered_body_ground_contacts.push(json!({
                "body_id": body_id,
                "present": self.contact(&body_id),
            }));
        }
        Ok(json!({
            "ordered_bodies": ordered_bodies,
            "ordered_body_ground_contacts": ordered_body_ground_contacts,
        }))
    }

    pub(crate) fn torso_position(&self) -> Vector {
        self.world.bodies[*self.bodies.get("torso").expect("torso handle")].translation()
    }

    pub(crate) fn contact(&self, body_id: &str) -> bool {
        let collider = *self.colliders.get(body_id).expect("contact body collider");
        self.world
            .contact_pair(collider, self.ground_collider)
            .is_some_and(|pair| pair.has_any_active_contact())
    }

    pub(crate) fn torso_ground_contact(&self) -> bool {
        self.contact("torso")
    }

    pub(crate) fn contact_site_position(
        &self,
        site: &sporespore_locomotion_core::schema::ContactSiteSpec,
    ) -> Vector {
        self.world.bodies[*self.bodies.get(&site.body_id).expect("contact body")]
            .position()
            .transform_point(vector(site.local_center_m))
    }

    pub(crate) fn contacts(&self, compiled: &CompiledQuadruped) -> BTreeMap<String, bool> {
        compiled
            .morphology
            .morphology_spec
            .contact_sites
            .iter()
            .map(|site| (site.contact_site_id.clone(), self.contact(&site.body_id)))
            .collect()
    }

    pub(crate) fn state_frame(
        &self,
        compiled: &CompiledQuadruped,
        semantic_step: u64,
        task_origin: Vector,
    ) -> Result<StateFrame, String> {
        let torso = &self.world.bodies[*self.bodies.get("torso").expect("torso")];
        let rotation = torso.rotation();
        let orientation = canonical_quaternion(rotation)?;
        let mut joint_observations = Vec::with_capacity(8);
        for joint_spec in &compiled.morphology.morphology_spec.joints {
            let handle = *self
                .joints
                .get(&joint_spec.joint_id)
                .ok_or_else(|| "C6_RAP_SP1_JOINT_HANDLE_MISSING".to_owned())?;
            let impulse_joint = self
                .world
                .impulse_joints
                .get(handle)
                .ok_or_else(|| "C6_RAP_SP1_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = impulse_joint
                .data
                .as_revolute()
                .ok_or_else(|| "C6_RAP_SP1_REVOLUTE_TYPE_MISMATCH".to_owned())?;
            let parent = &self.world.bodies[impulse_joint.body1()];
            let child = &self.world.bodies[impulse_joint.body2()];
            let angle = revolute.angle(parent.rotation(), child.rotation()) as f64;
            let world_axis = parent.rotation() * Vector::Z;
            let velocity = (child.angvel() - parent.angvel()).dot(world_axis) as f64;
            let parent_anchor = parent.position().transform_point(revolute.local_anchor1());
            let child_anchor = child.position().transform_point(revolute.local_anchor2());
            joint_observations.push(JointObservation {
                joint_id: joint_spec.joint_id.clone(),
                position_rad: Some(angle),
                velocity_rad_s: Some(velocity),
                anchor_error_m: Some((parent_anchor - child_anchor).length() as f64),
                validity: JointValidityMask {
                    position: true,
                    velocity: true,
                    anchor_error: true,
                },
            });
        }
        let ordered_contact_observations = compiled
            .morphology
            .morphology_spec
            .contact_sites
            .iter()
            .map(|site| {
                let present = self.contact(&site.body_id);
                ContactObservation {
                    contact_site_id: site.contact_site_id.clone(),
                    presence: Some(present),
                    bears_support: Some(present && site.can_support),
                    normal_load_n: None,
                    provenance: ContactProvenance {
                        adapter_id: ADAPTER_ID.to_owned(),
                        engine_contact_ids: if present {
                            vec![format!("rapier_pair_{}", site.contact_site_id)]
                        } else {
                            Vec::new()
                        },
                        aggregation_rule_id:
                            "rapier_active_pair_presence_equals_support_bearing_v1".to_owned(),
                        quality: ContactQuality::QualifiedBearing,
                        impulse_source_profile_id: None,
                        impulse_source_kind: None,
                    },
                }
            })
            .collect();
        Ok(StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step,
            sample_time_s: semantic_step as f64 * DT_S as f64,
            base_pose_world: Pose {
                position_m: Vec3 {
                    x: torso.translation().x as f64,
                    y: torso.translation().y as f64,
                    z: torso.translation().z as f64,
                },
                orientation_xyzw: orientation,
            },
            base_twist_world: Twist {
                linear_velocity_m_s: Vec3 {
                    x: torso.linvel().x as f64,
                    y: torso.linvel().y as f64,
                    z: torso.linvel().z as f64,
                },
                angular_velocity_rad_s: Vec3 {
                    x: torso.angvel().x as f64,
                    y: torso.angvel().y as f64,
                    z: torso.angvel().z as f64,
                },
            },
            ordered_joint_observations: joint_observations,
            ordered_contact_observations,
            previous_applied_actuation: None,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.8,
                z: 0.0,
            },
            task_frame: TaskFrame {
                origin_world_m: Vec3 {
                    x: task_origin.x as f64,
                    y: task_origin.y as f64,
                    z: task_origin.z as f64,
                },
                forward_axis_world_unit: Vec3 {
                    x: 1.0,
                    y: 0.0,
                    z: 0.0,
                },
                lateral_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 0.0,
                    z: 1.0,
                },
                up_axis_world_unit: Vec3 {
                    x: 0.0,
                    y: 1.0,
                    z: 0.0,
                },
                reference_yaw_rad: 0.0,
            },
            adapter_capability_sha256: capability_manifest_sha256(),
        })
    }

    pub(crate) fn bw19v_stability_state(
        &self,
        compiled: &CompiledQuadruped,
        semantic_step: u64,
    ) -> Result<StabilityStateV2, String> {
        let mut ordered_body_states =
            Vec::with_capacity(compiled.morphology.ordered_body_ids.len());
        for body_id in &compiled.morphology.ordered_body_ids {
            let body = &self.world.bodies[*self
                .bodies
                .get(body_id)
                .ok_or_else(|| format!("C6_RAP_BW19V_BODY_MISSING:{body_id}"))?];
            ordered_body_states.push(OrderedBodyStateV2 {
                body_id: body_id.clone(),
                pose_world: Pose {
                    position_m: Vec3 {
                        x: body.translation().x as f64,
                        y: body.translation().y as f64,
                        z: body.translation().z as f64,
                    },
                    orientation_xyzw: canonical_quaternion(body.rotation())?,
                },
                twist_world: Twist {
                    linear_velocity_m_s: Vec3 {
                        x: body.linvel().x as f64,
                        y: body.linvel().y as f64,
                        z: body.linvel().z as f64,
                    },
                    angular_velocity_rad_s: Vec3 {
                        x: body.angvel().x as f64,
                        y: body.angvel().y as f64,
                        z: body.angvel().z as f64,
                    },
                },
            });
        }

        let mut ordered_support_contacts =
            Vec::with_capacity(compiled.morphology.ordered_contact_site_ids.len());
        for site in &compiled.morphology.morphology_spec.contact_sites {
            let collider = *self
                .colliders
                .get(&site.body_id)
                .ok_or_else(|| format!("C6_RAP_BW19V_CONTACT_COLLIDER_MISSING:{}", site.body_id))?;
            let body_handle = *self
                .bodies
                .get(&site.body_id)
                .ok_or_else(|| format!("C6_RAP_BW19V_CONTACT_BODY_MISSING:{}", site.body_id))?;
            let geometry = self
                .world
                .contact_pair(collider, self.ground_collider)
                .filter(|pair| pair.has_any_active_contact())
                .and_then(|pair| {
                    pair.manifolds.iter().find_map(|manifold| {
                        manifold
                            .data
                            .solver_contacts
                            .first()
                            .map(|contact| contact.point)
                    })
                });
            if let Some(point) = geometry {
                let velocity = self.world.bodies[body_handle].velocity_at_point(point);
                ordered_support_contacts.push(SupportContactStateV2 {
                    contact_site_id: site.contact_site_id.clone(),
                    presence: Some(true),
                    bears_support: Some(site.can_support),
                    point_world_m: Some(Vec3 {
                        x: point.x as f64,
                        y: point.y as f64,
                        z: point.z as f64,
                    }),
                    normal_world_unit: Some(Vec3 {
                        x: 0.0,
                        y: 1.0,
                        z: 0.0,
                    }),
                    surface_relative_velocity_world_m_s: Some(Vec3 {
                        x: velocity.x as f64,
                        y: velocity.y as f64,
                        z: velocity.z as f64,
                    }),
                    material_id: Some("rapier_bw19v_mu095".to_owned()),
                    adapter_id: ADAPTER_ID.to_owned(),
                    engine_contact_ids: vec![format!("rapier_pair_{}", site.contact_site_id)],
                });
            } else {
                ordered_support_contacts.push(SupportContactStateV2 {
                    contact_site_id: site.contact_site_id.clone(),
                    presence: Some(false),
                    bears_support: Some(false),
                    point_world_m: None,
                    normal_world_unit: None,
                    surface_relative_velocity_world_m_s: None,
                    material_id: Some("rapier_bw19v_mu095".to_owned()),
                    adapter_id: ADAPTER_ID.to_owned(),
                    engine_contact_ids: Vec::new(),
                });
            }
        }
        Ok(StabilityStateV2 {
            schema_version: sporespore_locomotion_core::STABILITY_STATE_VERSION.to_owned(),
            semantic_step,
            ordered_body_states,
            ordered_support_contacts,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.8,
                z: 0.0,
            },
            support_plane_forward_world_unit: Vec3 {
                x: 1.0,
                y: 0.0,
                z: 0.0,
            },
            adapter_capability_sha256: capability_manifest_sha256(),
        })
    }

    pub(crate) fn bw19v_endpoint_kinematics(
        &self,
        compiled: &CompiledQuadruped,
        stability_state: &StabilityStateV2,
    ) -> Result<Vec<EndpointForceActuatorKinematicsV2>, String> {
        let support_point_by_id = stability_state
            .ordered_support_contacts
            .iter()
            .filter_map(|contact| {
                contact
                    .point_world_m
                    .map(|point| (contact.contact_site_id.as_str(), point))
            })
            .collect::<HashMap<_, _>>();
        let mut ordered = Vec::with_capacity(compiled.morphology.ordered_actuator_ids.len());
        for actuator in &compiled.morphology.morphology_spec.actuators {
            let joint_spec = compiled
                .morphology
                .morphology_spec
                .joints
                .iter()
                .find(|joint| joint.joint_id == actuator.joint_id)
                .ok_or_else(|| {
                    format!("C6_RAP_BW19V_KINEMATIC_JOINT_MISSING:{}", actuator.joint_id)
                })?;
            let limb = compiled
                .morphology
                .morphology_spec
                .limbs
                .iter()
                .find(|limb| limb.ordered_joint_ids.contains(&joint_spec.joint_id))
                .ok_or_else(|| {
                    format!(
                        "C6_RAP_BW19V_KINEMATIC_LIMB_MISSING:{}",
                        joint_spec.joint_id
                    )
                })?;
            if limb.ordered_contact_site_ids.len() != 1 {
                return Err(format!(
                    "C6_RAP_BW19V_KINEMATIC_CONTACT_CARDINALITY:{}",
                    limb.limb_id
                ));
            }
            let contact_site_id = &limb.ordered_contact_site_ids[0];
            let site = compiled
                .morphology
                .morphology_spec
                .contact_sites
                .iter()
                .find(|site| site.contact_site_id == *contact_site_id)
                .ok_or_else(|| {
                    format!("C6_RAP_BW19V_KINEMATIC_CONTACT_MISSING:{contact_site_id}")
                })?;
            let joint_handle = *self.joints.get(&joint_spec.joint_id).ok_or_else(|| {
                format!(
                    "C6_RAP_BW19V_KINEMATIC_HANDLE_MISSING:{}",
                    joint_spec.joint_id
                )
            })?;
            let joint = self
                .world
                .impulse_joints
                .get(joint_handle)
                .ok_or_else(|| "C6_RAP_BW19V_KINEMATIC_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute()
                .ok_or_else(|| "C6_RAP_BW19V_KINEMATIC_REVOLUTE_MISMATCH".to_owned())?;
            let parent = &self.world.bodies[joint.body1()];
            let anchor = parent.position().transform_point(revolute.local_anchor1());
            let raw_axis = parent.rotation() * vector(joint_spec.axis_parent_unit);
            let raw_axis_f64 = Vec3 {
                x: raw_axis.x as f64,
                y: raw_axis.y as f64,
                z: raw_axis.z as f64,
            };
            let axis_norm = (raw_axis_f64.x * raw_axis_f64.x
                + raw_axis_f64.y * raw_axis_f64.y
                + raw_axis_f64.z * raw_axis_f64.z)
                .sqrt();
            if !axis_norm.is_finite() || axis_norm <= 1.0e-12 {
                return Err("C6_RAP_BW19V_KINEMATIC_AXIS_INVALID".to_owned());
            }
            let endpoint = support_point_by_id
                .get(contact_site_id.as_str())
                .copied()
                .unwrap_or_else(|| {
                    let point = self.contact_site_position(site);
                    Vec3 {
                        x: point.x as f64,
                        y: point.y as f64,
                        z: point.z as f64,
                    }
                });
            ordered.push(EndpointForceActuatorKinematicsV2 {
                actuator_id: actuator.actuator_id.clone(),
                contact_site_id: contact_site_id.clone(),
                joint_anchor_world_m: Vec3 {
                    x: anchor.x as f64,
                    y: anchor.y as f64,
                    z: anchor.z as f64,
                },
                joint_axis_world_unit: Vec3 {
                    x: raw_axis_f64.x / axis_norm,
                    y: raw_axis_f64.y / axis_norm,
                    z: raw_axis_f64.z / axis_norm,
                },
                endpoint_world_m: endpoint,
            });
        }
        Ok(ordered)
    }

    pub(crate) fn apply_bw19v_composed_actuation(
        &mut self,
        commands: &[RapierBw19vComposedCommand],
    ) -> Result<(u64, u64), String> {
        if self.motor_profile != HostMotorProfile::RetainedPositionVelocityV1 {
            return Err("C6_RAP_BW19V_RETAINED_MOTOR_PROFILE_MISMATCH".to_owned());
        }
        if MOTOR_DAMPING as f64 != RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD {
            return Err("C6_RAP_BW19V_MOTOR_DAMPING_PROFILE_MISMATCH".to_owned());
        }
        if commands.len() != self.actuator_joints.len() {
            return Err("C6_RAP_BW19V_HOST_COMMAND_COUNT_MISMATCH".to_owned());
        }
        let mut applications = 0_u64;
        for command in commands {
            let joint_id = self
                .actuator_joints
                .get(&command.actuator_id)
                .ok_or_else(|| {
                    format!(
                        "C6_RAP_BW19V_ACTUATOR_MAPPING_MISSING:{}",
                        command.actuator_id
                    )
                })?;
            let joint = self
                .world
                .impulse_joints
                .get_mut(
                    *self
                        .joints
                        .get(joint_id)
                        .ok_or_else(|| "C6_RAP_BW19V_MOTOR_JOINT_MISSING".to_owned())?,
                    true,
                )
                .ok_or_else(|| "C6_RAP_BW19V_MOTOR_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_BW19V_MOTOR_REVOLUTE_MISMATCH".to_owned())?;
            let maximum_force = *self
                .actuator_maximum_force
                .get(&command.actuator_id)
                .ok_or_else(|| "C6_RAP_BW19V_MOTOR_FORCE_MISSING".to_owned())?;
            revolute
                .set_motor(
                    command.base_target_position_rad as f32,
                    command.combined_target_velocity_rad_s as f32,
                    MOTOR_STIFFNESS,
                    MOTOR_DAMPING,
                )
                .set_motor_model(MotorModel::ForceBased)
                .set_motor_max_force(maximum_force);
            let motor = revolute
                .motor()
                .ok_or_else(|| "C6_RAP_BW19V_MOTOR_READBACK_MISSING".to_owned())?;
            if motor.model != MotorModel::ForceBased
                || motor.target_pos != command.base_target_position_rad as f32
                || motor.target_vel != command.combined_target_velocity_rad_s as f32
                || motor.stiffness != MOTOR_STIFFNESS
                || motor.damping != MOTOR_DAMPING
                || motor.max_force != maximum_force
            {
                return Err("C6_RAP_BW19V_MOTOR_READBACK_MISMATCH".to_owned());
            }
            applications += 1;
        }
        self.world.step();
        self.solver_step_count += 1;
        let mut impulse_violations = 0_u64;
        for (actuator_id, joint_id) in &self.actuator_joints {
            let joint = self
                .world
                .impulse_joints
                .get(*self.joints.get(joint_id).expect("mapped joint"))
                .expect("mapped impulse joint");
            let impulse = joint
                .data
                .as_revolute()
                .and_then(|revolute| revolute.motor())
                .map(|motor| motor.impulse.abs())
                .ok_or_else(|| "C6_RAP_BW19V_MOTOR_IMPULSE_MISSING".to_owned())?;
            let maximum_force = *self
                .actuator_maximum_force
                .get(actuator_id)
                .expect("mapped actuator force");
            if impulse > maximum_force * DT_S + 1.0e-6 {
                impulse_violations += 1;
            }
        }
        Ok((applications, impulse_violations))
    }

    /// Apply the only load-bearing command receipt accepted by the prospective
    /// live-v4 path. Native position targets are forbidden, every mutable motor
    /// field is read back before stepping, and the post-step `JointMotor.impulse`
    /// is checked against Rapier's solver-small-step cap.
    #[allow(dead_code)]
    pub(crate) fn apply_bw19v_velocity_only_v4_actuation(
        &mut self,
        mapping: &VelocityOnlyHostMappingReceiptV1,
    ) -> Result<(u64, u64), String> {
        if self.motor_profile != HostMotorProfile::CanonicalVelocityOnlyV4 {
            return Err("C6_RAP_V4_HOST_MOTOR_PROFILE_MISMATCH".to_owned());
        }
        if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
            || mapping.independent_native_position_feedback_applied
            || mapping.native_position_stiffness != 0.0
            || mapping.host_response_characterized_for_this_profile
            || mapping.world_build_count != 0
            || mapping.physics_state_modified
            || mapping.physical_acceptance_authority
            || mapping.ordered_commands.len() != self.actuator_joints.len()
        {
            return Err("C6_RAP_V4_HOST_MAPPING_CONTRACT_MISMATCH".to_owned());
        }
        crate::live_explorer::wait_for_live_explorer_start()?;
        let mut applications = 0_u64;
        for command in &mapping.ordered_commands {
            if command.native_target_position_rad.is_some() || command.host_clamped {
                return Err(format!(
                    "C6_RAP_V4_NATIVE_POSITION_OR_HOST_CLAMP_FORBIDDEN:{}",
                    command.actuator_id
                ));
            }
            let joint_id = self
                .actuator_joints
                .get(&command.actuator_id)
                .ok_or_else(|| {
                    format!("C6_RAP_V4_ACTUATOR_MAPPING_MISSING:{}", command.actuator_id)
                })?;
            let maximum_force = *self
                .actuator_maximum_force
                .get(&command.actuator_id)
                .ok_or_else(|| "C6_RAP_V4_MOTOR_FORCE_MISSING".to_owned())?;
            let joint = self
                .world
                .impulse_joints
                .get_mut(
                    *self
                        .joints
                        .get(joint_id)
                        .ok_or_else(|| "C6_RAP_V4_MOTOR_JOINT_MISSING".to_owned())?,
                    true,
                )
                .ok_or_else(|| "C6_RAP_V4_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_V4_REVOLUTE_JOINT_MISSING".to_owned())?;
            update_velocity_only_motor_v1(
                revolute,
                command.host_target_velocity_rad_s as f32,
                maximum_force,
            )?;
            applications += 1;
        }
        let applied_impulses = self.apply_live_explorer_impulses()?;
        self.world.step();
        self.solver_step_count += 1;
        let mut live_frame = self.live_explorer_frame_payload()?;
        live_frame["applied_impulses"] = applied_impulses;
        crate::live_explorer::emit_rapier_frame(live_frame)?;
        let mut impulse_violations = 0_u64;
        for (actuator_id, joint_id) in &self.actuator_joints {
            let motor = self
                .world
                .impulse_joints
                .get(*self.joints.get(joint_id).expect("mapped v4 joint"))
                .and_then(|joint| joint.data.as_revolute())
                .and_then(|revolute| revolute.motor())
                .ok_or_else(|| "C6_RAP_V4_POST_STEP_MOTOR_MISSING".to_owned())?;
            let maximum_force = self.actuator_maximum_force[actuator_id];
            let maximum_small_step_impulse =
                velocity_only_small_step_impulse_limit_v1(maximum_force);
            if !motor.impulse.is_finite()
                || motor.impulse.abs() > maximum_small_step_impulse + 1.0e-6
            {
                impulse_violations += 1;
            }
        }
        Ok((applications, impulse_violations))
    }

    /// Apply one R23D62 public-profile command step and retain the actual
    /// mutable `JointMotor` target/maximum-force readbacks used by Rapier.
    /// The solver is advanced exactly once after all eight readbacks exist.
    #[allow(dead_code)]
    pub(crate) fn apply_r23d62_public_profile_velocity_only_actuation(
        &mut self,
        actuation: &ActuationFrame,
        mapping: &VelocityOnlyHostMappingReceiptV1,
        binding: &RapierPublicActuatorCapBindingV1,
    ) -> Result<RapierR23D62StepReadbackV1, String> {
        const TRACE_READBACK_TOLERANCE: f64 = 2.5e-7;

        if self.motor_profile != HostMotorProfile::CanonicalVelocityOnlyV4 {
            return Err("QSDK_R23D62_RAP_HOST_MOTOR_PROFILE_MISMATCH".to_owned());
        }
        if mapping.host_profile_id != RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID
            || mapping.independent_native_position_feedback_applied
            || mapping.native_position_stiffness != 0.0
            || mapping.host_response_characterized_for_this_profile
            || mapping.world_build_count != 0
            || mapping.physics_state_modified
            || mapping.physical_acceptance_authority
            || mapping.ordered_commands.len() != self.actuator_joints.len()
            || actuation.ordered_commands.len() != mapping.ordered_commands.len()
            || binding.ordered_mappings.len() != mapping.ordered_commands.len()
        {
            return Err("QSDK_R23D62_RAP_HOST_MAPPING_CONTRACT_MISMATCH".to_owned());
        }

        crate::live_explorer::wait_for_live_explorer_start()?;
        let mut ordered_applications = Vec::with_capacity(mapping.ordered_commands.len());
        for ((source, command), profile) in actuation
            .ordered_commands
            .iter()
            .zip(&mapping.ordered_commands)
            .zip(&binding.ordered_mappings)
        {
            if source.actuator_id != command.actuator_id
                || source.actuator_id != profile.actuator_id
                || command.native_target_position_rad.is_some()
                || command.host_clamped
                || command.valid_through_step != actuation.semantic_step
            {
                return Err(format!(
                    "QSDK_R23D62_RAP_APPLICATION_IDENTITY_INVALID:{}",
                    command.actuator_id
                ));
            }
            let joint_id = self
                .actuator_joints
                .get(&command.actuator_id)
                .ok_or_else(|| {
                    format!(
                        "QSDK_R23D62_RAP_ACTUATOR_MAPPING_MISSING:{}",
                        command.actuator_id
                    )
                })?;
            if joint_id != &profile.joint_id {
                return Err(format!(
                    "QSDK_R23D62_RAP_PROFILE_JOINT_MISMATCH:{}",
                    command.actuator_id
                ));
            }
            let maximum_force = *self
                .actuator_maximum_force
                .get(&command.actuator_id)
                .ok_or_else(|| "QSDK_R23D62_RAP_MOTOR_FORCE_MISSING".to_owned())?;
            if maximum_force != profile.rapier_maximum_force_nm_f32 {
                return Err(format!(
                    "QSDK_R23D62_RAP_PROFILE_FORCE_MISMATCH:{}",
                    command.actuator_id
                ));
            }
            let joint = self
                .world
                .impulse_joints
                .get_mut(
                    *self
                        .joints
                        .get(joint_id)
                        .ok_or_else(|| "QSDK_R23D62_RAP_MOTOR_JOINT_MISSING".to_owned())?,
                    true,
                )
                .ok_or_else(|| "QSDK_R23D62_RAP_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "QSDK_R23D62_RAP_REVOLUTE_JOINT_MISSING".to_owned())?;
            let readback = update_velocity_only_motor_v1(
                revolute,
                command.host_target_velocity_rad_s as f32,
                maximum_force,
            )?;
            let host_applied = command.host_target_velocity_rad_s;
            let target_readback = readback.target_velocity_rad_s as f64;
            let target_error = (target_readback - host_applied).abs();
            let declared_impulse = profile.portable_maximum_outer_step_impulse_nms;
            let impulse_readback = readback.maximum_force_nm as f64 * RAPIER_DT_S as f64;
            let impulse_error = (impulse_readback - declared_impulse).abs();
            if target_error > TRACE_READBACK_TOLERANCE || impulse_error > TRACE_READBACK_TOLERANCE {
                return Err(format!(
                    "QSDK_R23D62_RAP_APPLICATION_READBACK_MISMATCH:{}",
                    command.actuator_id
                ));
            }
            ordered_applications.push(RapierR23D62MotorApplicationReadbackV1 {
                actuator_id: command.actuator_id.clone(),
                joint_id: joint_id.clone(),
                requested_target_position_rad: source.requested_target_position_rad,
                clamped_target_position_rad: source.clamped_target_position_rad,
                controller_target_velocity_rad_s: command.canonical_target_velocity_rad_s,
                maximum_target_speed_rad_s: source.maximum_target_speed_rad_s,
                host_applied_target_velocity_rad_s: host_applied,
                motor_target_velocity_readback_rad_s: target_readback,
                motor_target_velocity_readback_error_rad_s: target_error,
                declared_maximum_impulse_nms: declared_impulse,
                motor_maximum_impulse_readback_nms: impulse_readback,
                motor_maximum_impulse_readback_error_nms: impulse_error,
                position_saturated: source.position_saturated,
                velocity_saturated: source.velocity_saturated,
                slew_limited: source.slew_limited,
                target_velocity_readback_matches: true,
                maximum_impulse_readback_matches: true,
            });
        }

        let applied_impulses = self.apply_live_explorer_impulses()?;
        self.world.step();
        self.solver_step_count += 1;
        let mut live_frame = self.live_explorer_frame_payload()?;
        live_frame["applied_impulses"] = applied_impulses;
        crate::live_explorer::emit_rapier_frame(live_frame)?;

        let mut impulse_violations = 0_u64;
        for (actuator_id, joint_id) in &self.actuator_joints {
            let motor = self
                .world
                .impulse_joints
                .get(*self.joints.get(joint_id).expect("mapped R23D62 joint"))
                .and_then(|joint| joint.data.as_revolute())
                .and_then(|revolute| revolute.motor())
                .ok_or_else(|| "QSDK_R23D62_RAP_POST_STEP_MOTOR_MISSING".to_owned())?;
            let maximum_force = self.actuator_maximum_force[actuator_id];
            let maximum_small_step_impulse =
                velocity_only_small_step_impulse_limit_v1(maximum_force);
            if !motor.impulse.is_finite()
                || motor.impulse.abs() > maximum_small_step_impulse + 1.0e-6
            {
                impulse_violations += 1;
            }
        }
        Ok(RapierR23D62StepReadbackV1 {
            native_application_count: ordered_applications.len() as u64,
            ordered_applications,
            impulse_violation_count: impulse_violations,
        })
    }

    /// Read the eight live motors configured by the public-profile constructor
    /// before any solver step.  The supplied digest is the prequalified Python
    /// `json.dumps(sort_keys=True, separators=(",", ":"))` identity of the
    /// attached host-mapping receipt.
    #[allow(dead_code)]
    pub(crate) fn r23d62_public_profile_physical_binding_receipt(
        &self,
        binding: &RapierPublicActuatorCapBindingV1,
        host_mapping_receipt_sha256: &str,
    ) -> Result<Value, String> {
        const CONFIGURATION_READBACK_TOLERANCE_NMS: f64 = 4.355_907_492_481_492e-7;

        if self.motor_profile != HostMotorProfile::CanonicalVelocityOnlyV4
            || self.solver_step_count != 0
            || binding.ordered_mappings.len() != self.actuator_joints.len()
            || !host_mapping_receipt_sha256.starts_with("sha256:")
            || host_mapping_receipt_sha256.len() != 71
        {
            return Err("QSDK_R23D62_RAP_PHYSICAL_BINDING_INPUT_INVALID".to_owned());
        }
        let mut ordered_bindings = Vec::with_capacity(binding.ordered_mappings.len());
        for profile in &binding.ordered_mappings {
            let joint_id = self
                .actuator_joints
                .get(&profile.actuator_id)
                .ok_or_else(|| {
                    format!(
                        "QSDK_R23D62_RAP_PHYSICAL_BINDING_ACTUATOR_MISSING:{}",
                        profile.actuator_id
                    )
                })?;
            if joint_id != &profile.joint_id {
                return Err(format!(
                    "QSDK_R23D62_RAP_PHYSICAL_BINDING_JOINT_MISMATCH:{}",
                    profile.actuator_id
                ));
            }
            let motor =
                self.world
                    .impulse_joints
                    .get(*self.joints.get(joint_id).ok_or_else(|| {
                        "QSDK_R23D62_RAP_PHYSICAL_BINDING_JOINT_MISSING".to_owned()
                    })?)
                    .and_then(|joint| joint.data.as_revolute())
                    .and_then(|revolute| revolute.motor())
                    .ok_or_else(|| "QSDK_R23D62_RAP_PHYSICAL_BINDING_MOTOR_MISSING".to_owned())?;
            let readback = motor.max_force as f64 * RAPIER_DT_S as f64;
            let declared = profile.portable_maximum_outer_step_impulse_nms;
            let error = (readback - declared).abs();
            if motor.model != MotorModel::ForceBased
                || motor.max_force != profile.rapier_maximum_force_nm_f32
                || error > CONFIGURATION_READBACK_TOLERANCE_NMS
            {
                return Err(format!(
                    "QSDK_R23D62_RAP_PHYSICAL_BINDING_READBACK_MISMATCH:{}",
                    profile.actuator_id
                ));
            }
            ordered_bindings.push(json!({
                "profile_actuator_id": profile.actuator_id,
                "trace_actuator_id": profile.actuator_id,
                "joint_id": profile.joint_id,
                "declared_maximum_outer_step_impulse_nms": declared,
                "host_readback_outer_step_impulse_nms": readback,
                "readback_error_nms": error,
                "readback_matches": true,
            }));
        }
        Ok(json!({
            "schema_version": "sporespore_qsdk_r23d62_physical_actuator_cap_binding_v1",
            "ok": true,
            "failure_code": "",
            "engine_id": "rapier_parry",
            "profile_id": sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            "profile_sha256": sporespore_locomotion_core::R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
            "host_mapping_id": "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1",
            "host_mapping_receipt_sha256": host_mapping_receipt_sha256,
            "completed_before_first_solver_step": true,
            "solver_step_count_at_binding": self.solver_step_count,
            "validated_actuator_count": ordered_bindings.len(),
            "write_count": ordered_bindings.len(),
            "readback_count": ordered_bindings.len(),
            "all_readbacks_match": true,
            "ordered_bindings": ordered_bindings,
        }))
    }

    fn apply_actuation(
        &mut self,
        actuation: &sporespore_locomotion_core::ActuationFrame,
    ) -> Result<(u64, u64), String> {
        if self.motor_profile != HostMotorProfile::RetainedPositionVelocityV1 {
            return Err("C6_RAP_SP1_RETAINED_MOTOR_PROFILE_MISMATCH".to_owned());
        }
        let mut applications = 0;
        let mut impulse_violations = 0;
        for command in &actuation.ordered_commands {
            let joint_id = self
                .actuator_joints
                .get(&command.actuator_id)
                .ok_or_else(|| {
                    format!(
                        "C6_RAP_SP1_ACTUATOR_MAPPING_MISSING:{}",
                        command.actuator_id
                    )
                })?;
            let joint = self
                .world
                .impulse_joints
                .get_mut(
                    *self
                        .joints
                        .get(joint_id)
                        .ok_or_else(|| "C6_RAP_SP1_MOTOR_JOINT_MISSING".to_owned())?,
                    true,
                )
                .ok_or_else(|| "C6_RAP_SP1_MOTOR_IMPULSE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_SP1_MOTOR_REVOLUTE_TYPE_MISMATCH".to_owned())?;
            let maximum_force = *self
                .actuator_maximum_force
                .get(&command.actuator_id)
                .ok_or_else(|| "C6_RAP_SP1_MOTOR_FORCE_MISSING".to_owned())?;
            revolute
                .set_motor(
                    command.clamped_target_position_rad as f32,
                    command.target_velocity_rad_s as f32,
                    MOTOR_STIFFNESS,
                    MOTOR_DAMPING,
                )
                .set_motor_model(MotorModel::ForceBased)
                .set_motor_max_force(maximum_force);
            if revolute.motor().map(|motor| motor.model) != Some(MotorModel::ForceBased) {
                return Err("C6_RAP_SP1_MOTOR_MODEL_READBACK_MISMATCH".to_owned());
            }
            applications += 1;
        }
        self.world.step();
        self.solver_step_count += 1;
        for (actuator_id, joint_id) in &self.actuator_joints {
            let joint = self
                .world
                .impulse_joints
                .get(*self.joints.get(joint_id).expect("mapped joint"))
                .expect("joint after step");
            let impulse = joint
                .data
                .as_revolute()
                .and_then(|revolute| revolute.motor())
                .map(|motor| motor.impulse.abs())
                .unwrap_or(f32::INFINITY);
            let maximum = self.actuator_maximum_force[actuator_id] * DT_S;
            if !impulse.is_finite() || impulse > maximum + 1.0e-5 {
                impulse_violations += 1;
            }
        }
        Ok((applications, impulse_violations))
    }

    pub(crate) fn hold_zero_and_step(&mut self) -> Result<(), String> {
        if self.motor_profile != HostMotorProfile::RetainedPositionVelocityV1 {
            return Err("C6_RAP_SP1_RETAINED_SETTLE_PROFILE_MISMATCH".to_owned());
        }
        for (actuator_id, joint_id) in &self.actuator_joints {
            let joint = self
                .world
                .impulse_joints
                .get_mut(*self.joints.get(joint_id).expect("mapped joint"), true)
                .ok_or_else(|| "C6_RAP_SP1_SETTLE_JOINT_MISSING".to_owned())?;
            joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_SP1_SETTLE_REVOLUTE_MISSING".to_owned())?
                .set_motor(0.0, 0.0, MOTOR_STIFFNESS, MOTOR_DAMPING)
                .set_motor_model(MotorModel::ForceBased)
                .set_motor_max_force(self.actuator_maximum_force[actuator_id]);
        }
        self.world.step();
        self.solver_step_count += 1;
        Ok(())
    }

    #[allow(dead_code)]
    pub(crate) fn hold_velocity_only_v4_zero_and_step(&mut self) -> Result<(), String> {
        if self.motor_profile != HostMotorProfile::CanonicalVelocityOnlyV4 {
            return Err("C6_RAP_V4_SETTLE_MOTOR_PROFILE_MISMATCH".to_owned());
        }
        for (actuator_id, joint_id) in &self.actuator_joints {
            let joint = self
                .world
                .impulse_joints
                .get_mut(*self.joints.get(joint_id).expect("mapped v4 joint"), true)
                .ok_or_else(|| "C6_RAP_V4_SETTLE_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "C6_RAP_V4_SETTLE_REVOLUTE_MISSING".to_owned())?;
            update_velocity_only_motor_v1(revolute, 0.0, self.actuator_maximum_force[actuator_id])?;
        }
        self.world.step();
        self.solver_step_count += 1;
        Ok(())
    }

    pub(crate) fn joint_angle(&self, joint_id: &str) -> Result<f64, String> {
        let joint = self
            .world
            .impulse_joints
            .get(
                *self
                    .joints
                    .get(joint_id)
                    .ok_or_else(|| format!("C6_RAP_OBS_JOINT_HANDLE_MISSING:{joint_id}"))?,
            )
            .ok_or_else(|| format!("C6_RAP_OBS_JOINT_MISSING:{joint_id}"))?;
        let revolute = joint
            .data
            .as_revolute()
            .ok_or_else(|| format!("C6_RAP_OBS_REVOLUTE_MISSING:{joint_id}"))?;
        Ok(revolute.angle(
            self.world.bodies[joint.body1()].rotation(),
            self.world.bodies[joint.body2()].rotation(),
        ) as f64)
    }

    pub(crate) fn actuator_motor_impulse(&self, actuator_id: &str) -> Result<f64, String> {
        let joint_id = self
            .actuator_joints
            .get(actuator_id)
            .ok_or_else(|| format!("C6_RAP_OBS_ACTUATOR_MISSING:{actuator_id}"))?;
        let joint = self
            .world
            .impulse_joints
            .get(self.joints[joint_id])
            .ok_or_else(|| format!("C6_RAP_OBS_MOTOR_JOINT_MISSING:{joint_id}"))?;
        Ok(joint
            .data
            .as_revolute()
            .and_then(|revolute| revolute.motor())
            .map(|motor| motor.impulse.abs() as f64)
            .unwrap_or(f64::NAN))
    }

    pub(crate) fn structural_metrics(
        &self,
        compiled: &CompiledQuadruped,
    ) -> Result<(f64, f64), String> {
        let mut max_anchor = 0.0_f64;
        let mut max_axis = 0.0_f64;
        for spec in &compiled.morphology.morphology_spec.joints {
            let joint = self
                .world
                .impulse_joints
                .get(self.joints[&spec.joint_id])
                .ok_or_else(|| "C6_RAP_SP1_METRIC_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute()
                .ok_or_else(|| "C6_RAP_SP1_METRIC_REVOLUTE_MISSING".to_owned())?;
            let parent = &self.world.bodies[joint.body1()];
            let child = &self.world.bodies[joint.body2()];
            let anchor1 = parent.position().transform_point(revolute.local_anchor1());
            let anchor2 = child.position().transform_point(revolute.local_anchor2());
            max_anchor = max_anchor.max((anchor1 - anchor2).length() as f64);
            let parent_axis = parent.rotation() * Vector::Z;
            let child_axis = child.rotation() * Vector::Z;
            max_axis = max_axis.max(parent_axis.dot(child_axis).clamp(-1.0, 1.0).acos() as f64);
        }
        Ok((max_anchor, max_axis))
    }
}

#[derive(Debug, Clone)]
pub(crate) struct FootEvidence {
    pub(crate) previous_contact: bool,
    pub(crate) airborne_steps: u64,
    pub(crate) maximum_airborne_dwell_steps: u64,
    pub(crate) liftoff_position: Option<Vector>,
    pub(crate) contact_cycles: u64,
    pub(crate) maximum_foot_relocation_m: f64,
}

#[derive(Debug, Clone)]
pub(crate) struct ActuatorEvidence {
    nonzero_target_position_count: u64,
    nonzero_target_velocity_count: u64,
    minimum_target_position_rad: f64,
    maximum_target_position_rad: f64,
    minimum_target_velocity_rad_s: f64,
    maximum_target_velocity_rad_s: f64,
    minimum_observed_joint_angle_rad: f64,
    maximum_observed_joint_angle_rad: f64,
    maximum_motor_impulse_nms: f64,
    maximum_motor_impulse_utilization: f64,
}

impl ActuatorEvidence {
    pub(crate) fn new() -> Self {
        Self {
            nonzero_target_position_count: 0,
            nonzero_target_velocity_count: 0,
            minimum_target_position_rad: f64::INFINITY,
            maximum_target_position_rad: f64::NEG_INFINITY,
            minimum_target_velocity_rad_s: f64::INFINITY,
            maximum_target_velocity_rad_s: f64::NEG_INFINITY,
            minimum_observed_joint_angle_rad: f64::INFINITY,
            maximum_observed_joint_angle_rad: f64::NEG_INFINITY,
            maximum_motor_impulse_nms: 0.0,
            maximum_motor_impulse_utilization: 0.0,
        }
    }

    pub(crate) fn observe_command(&mut self, position_rad: f64, velocity_rad_s: f64) {
        if position_rad.abs() > 1.0e-12 {
            self.nonzero_target_position_count += 1;
        }
        if velocity_rad_s.abs() > 1.0e-12 {
            self.nonzero_target_velocity_count += 1;
        }
        self.minimum_target_position_rad = self.minimum_target_position_rad.min(position_rad);
        self.maximum_target_position_rad = self.maximum_target_position_rad.max(position_rad);
        self.minimum_target_velocity_rad_s = self.minimum_target_velocity_rad_s.min(velocity_rad_s);
        self.maximum_target_velocity_rad_s = self.maximum_target_velocity_rad_s.max(velocity_rad_s);
    }

    pub(crate) fn observe_host(&mut self, angle_rad: f64, impulse_nms: f64, limit_nms: f64) {
        self.minimum_observed_joint_angle_rad =
            self.minimum_observed_joint_angle_rad.min(angle_rad);
        self.maximum_observed_joint_angle_rad =
            self.maximum_observed_joint_angle_rad.max(angle_rad);
        self.maximum_motor_impulse_nms = self.maximum_motor_impulse_nms.max(impulse_nms);
        if limit_nms > 0.0 {
            self.maximum_motor_impulse_utilization = self
                .maximum_motor_impulse_utilization
                .max(impulse_nms / limit_nms);
        }
    }

    pub(crate) fn receipt(&self) -> Value {
        json!({
            "nonzero_target_position_count": self.nonzero_target_position_count,
            "nonzero_target_velocity_count": self.nonzero_target_velocity_count,
            "minimum_target_position_rad": self.minimum_target_position_rad,
            "maximum_target_position_rad": self.maximum_target_position_rad,
            "minimum_target_velocity_rad_s": self.minimum_target_velocity_rad_s,
            "maximum_target_velocity_rad_s": self.maximum_target_velocity_rad_s,
            "minimum_observed_joint_angle_rad": self.minimum_observed_joint_angle_rad,
            "maximum_observed_joint_angle_rad": self.maximum_observed_joint_angle_rad,
            "maximum_motor_impulse_nms": self.maximum_motor_impulse_nms,
            "maximum_motor_impulse_utilization": self.maximum_motor_impulse_utilization,
        })
    }
}

#[derive(Debug, Clone)]
pub(crate) struct ContactOccupancyEvidence {
    previous: bool,
    bearing_true_step_count: u64,
    bearing_false_step_count: u64,
    transition_count: u64,
}

impl ContactOccupancyEvidence {
    pub(crate) fn new(initial: bool) -> Self {
        Self {
            previous: initial,
            bearing_true_step_count: 0,
            bearing_false_step_count: 0,
            transition_count: 0,
        }
    }

    pub(crate) fn observe(&mut self, bearing: bool) {
        if bearing {
            self.bearing_true_step_count += 1;
        } else {
            self.bearing_false_step_count += 1;
        }
        if bearing != self.previous {
            self.transition_count += 1;
        }
        self.previous = bearing;
    }

    pub(crate) fn receipt(&self) -> Value {
        json!({
            "bearing_true_step_count": self.bearing_true_step_count,
            "bearing_false_step_count": self.bearing_false_step_count,
            "transition_count": self.transition_count,
        })
    }
}

impl FootEvidence {
    pub(crate) fn new(contact: bool) -> Self {
        Self {
            previous_contact: contact,
            airborne_steps: 0,
            maximum_airborne_dwell_steps: 0,
            liftoff_position: None,
            contact_cycles: 0,
            maximum_foot_relocation_m: 0.0,
        }
    }

    pub(crate) fn observe(&mut self, contact: bool, position: Vector) {
        match (self.previous_contact, contact) {
            (true, false) => {
                self.airborne_steps = 1;
                self.maximum_airborne_dwell_steps =
                    self.maximum_airborne_dwell_steps.max(self.airborne_steps);
                self.liftoff_position = Some(position);
            }
            (false, false) => {
                self.airborne_steps += 1;
                self.maximum_airborne_dwell_steps =
                    self.maximum_airborne_dwell_steps.max(self.airborne_steps);
            }
            (false, true) => {
                self.maximum_airborne_dwell_steps =
                    self.maximum_airborne_dwell_steps.max(self.airborne_steps);
                if self.airborne_steps >= MINIMUM_AIRBORNE_DWELL_STEPS {
                    self.contact_cycles += 1;
                    if let Some(liftoff) = self.liftoff_position {
                        self.maximum_foot_relocation_m = self
                            .maximum_foot_relocation_m
                            .max((position - liftoff).length() as f64);
                    }
                }
                self.airborne_steps = 0;
                self.liftoff_position = None;
            }
            (true, true) => {}
        }
        self.previous_contact = contact;
    }
}

pub(crate) fn motion_command(
    step: u64,
    phase_progression_mode: PhaseProgressionMode,
) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("rapier_c6_step_{step}"),
        desired_planar_velocity_task_m_s: Vec3 {
            x: 0.2,
            y: 0.0,
            z: 0.0,
        },
        desired_heading_rad: Some(0.0),
        desired_yaw_rate_rad_s: None,
        gait_family_id: "lateral_wave".to_owned(),
        speed_class: SpeedClass::Walk,
        gait_amplitude: 1.0,
        phase_progression_mode,
        valid_from_step: step,
        valid_through_step: step,
        authority: CommandAuthority::TestFixture,
    }
}

pub fn run_selected_policy_commissioning(source_commit: &str) -> Result<Value, String> {
    let preflight = run_selected_policy_commissioning_preflight()?;
    run_selected_policy_commissioning_impl(
        source_commit,
        CAMPAIGN_ID,
        GATE_ID,
        PREREGISTRATION_RAW_SHA256,
        "sporespore_rapier_c6_selected_policy_commissioning_report_v1",
        "C6_RAP_SP1",
        preflight,
    )
}

pub fn run_selected_policy_commissioning_r1(source_commit: &str) -> Result<Value, String> {
    let preflight = run_selected_policy_commissioning_r1_preflight()?;
    run_selected_policy_commissioning_impl(
        source_commit,
        R1_CAMPAIGN_ID,
        R1_GATE_ID,
        R1_PREREGISTRATION_RAW_SHA256,
        "sporespore_rapier_c6_selected_policy_commissioning_r1_report_v1",
        "C6_RAP_SP1_R1",
        preflight,
    )
}

pub fn run_selected_policy_commissioning_r2(source_commit: &str) -> Result<Value, String> {
    let preflight = run_selected_policy_commissioning_r2_preflight()?;
    run_selected_policy_commissioning_impl(
        source_commit,
        R2_CAMPAIGN_ID,
        R2_GATE_ID,
        R2_PREREGISTRATION_RAW_SHA256,
        "sporespore_rapier_c6_selected_policy_commissioning_r2_report_v1",
        "C6_RAP_SP1_R2",
        preflight,
    )
}

fn run_selected_policy_commissioning_impl(
    source_commit: &str,
    campaign_id: &str,
    gate_id: &str,
    preregistration_raw_sha256: &str,
    report_schema_version: &str,
    failure_prefix: &str,
    preflight: Value,
) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(format!("{failure_prefix}_SOURCE_COMMIT_INVALID"));
    }
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot = build_robot(&compiled)?;
    for _ in 0..SETTLE_STEPS {
        robot.hold_zero_and_step()?;
    }
    let task_origin = robot.torso_position();
    let post_settle_torso = &robot.world.bodies[robot.bodies["torso"]];
    let post_settle_position = post_settle_torso.translation();
    let post_settle_up = post_settle_torso.rotation() * Vector::Y;
    let post_settle_tilt_rad = post_settle_up.y.clamp(-1.0, 1.0).acos() as f64;
    let post_settle_torso_ground_contact = robot.torso_ground_contact();
    let post_settle_joint_angles = compiled
        .morphology
        .ordered_joint_ids
        .iter()
        .map(|joint_id| Ok((joint_id.clone(), json!(robot.joint_angle(joint_id)?))))
        .collect::<Result<serde_json::Map<String, Value>, String>>()?;
    let initial_contacts = robot.contacts(&compiled);
    let initial_four_contact_stance = initial_contacts.values().all(|contact| *contact);
    let mut foot_evidence = BTreeMap::<String, FootEvidence>::new();
    let mut contact_occupancy = BTreeMap::<String, ContactOccupancyEvidence>::new();
    for (contact_site_id, bearing) in &initial_contacts {
        contact_occupancy.insert(
            contact_site_id.clone(),
            ContactOccupancyEvidence::new(*bearing),
        );
    }
    for limb in &compiled.morphology.morphology_spec.limbs {
        let site_id = &limb.ordered_contact_site_ids[0];
        foot_evidence.insert(
            limb.limb_id.clone(),
            FootEvidence::new(*initial_contacts.get(site_id).unwrap_or(&false)),
        );
    }

    let mut memory = BalancedWaveControllerMemory::initial();
    let mut evidence_start = None::<Vector>;
    let mut evidence_end = None::<Vector>;
    let mut evidence_limits_reached = false;
    let mut evidence_completion_step = None::<u64>;
    let mut controller_semantic_step_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_motor_application_count = 0_u64;
    let mut controller_error_count = 0_u64;
    let mut controller_error_receipts = BTreeMap::<String, u64>::new();
    let mut actuator_evidence = compiled
        .morphology
        .ordered_actuator_ids
        .iter()
        .map(|actuator_id| (actuator_id.clone(), ActuatorEvidence::new()))
        .collect::<BTreeMap<_, _>>();
    let mut safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut motor_impulse_limit_violation_count = 0_u64;
    let mut torso_ground_contact_count = 0_u64;
    let mut first_torso_ground_contact_semantic_step = None::<u64>;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_anchor_error_m = 0.0_f64;
    let mut maximum_hinge_axis_error_rad = 0.0_f64;
    let evidence_deadline =
        CONTACT_GATED_START_STEP + EVIDENCE_GAIT_STEPS + MAXIMUM_EVIDENCE_EXTENSION_STEPS;
    let mut cooldown_completed = false;
    let mut cooldown_end = None::<u64>;

    for semantic_step in 0..evidence_deadline + COOLDOWN_STEPS {
        if semantic_step == CONTACT_GATED_START_STEP {
            evidence_start = Some(robot.torso_position());
            for limb in &mut memory.ordered_limb_memory {
                limb.evidence_gait_step_limit = Some(limb.gait_step + 1 + EVIDENCE_GAIT_STEPS);
            }
        }
        let phase_mode = if semantic_step < CONTACT_GATED_START_STEP {
            PhaseProgressionMode::Clocked
        } else {
            PhaseProgressionMode::ContactGated
        };
        let state = robot.state_frame(&compiled, semantic_step, task_origin)?;
        if state_contains_nonfinite(&state) {
            nonfinite_observation_count += 1;
        }
        let command = motion_command(semantic_step, phase_mode);
        let output = controller.step(&memory, &state, &command);
        if let Some(controller_error) = &output.actuation.receipt.controller_error {
            controller_error_count += 1;
            *controller_error_receipts
                .entry(controller_error.clone())
                .or_insert(0) += 1;
        } else if !output.actuation.failure_codes.is_empty() {
            controller_error_count += 1;
            for failure_code in &output.actuation.failure_codes {
                *controller_error_receipts
                    .entry(failure_code.clone())
                    .or_insert(0) += 1;
            }
        }
        if output.actuation.safe_no_actuation {
            safe_no_actuation_count += 1;
        }
        output
            .actuation
            .validate(&compiled.morphology)
            .map_err(|error| format!("C6_RAP_SP1_ACTUATION_INVALID:{error}"))?;
        for command in &output.actuation.ordered_commands {
            actuator_evidence
                .get_mut(&command.actuator_id)
                .expect("compiled actuator evidence")
                .observe_command(
                    command.clamped_target_position_rad,
                    command.target_velocity_rad_s,
                );
        }
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let (applications, impulse_violations) = robot.apply_actuation(&output.actuation)?;
        for actuator in &compiled.morphology.morphology_spec.actuators {
            let angle = robot.joint_angle(&actuator.joint_id)?;
            let impulse = robot.actuator_motor_impulse(&actuator.actuator_id)?;
            actuator_evidence
                .get_mut(&actuator.actuator_id)
                .expect("compiled actuator evidence")
                .observe_host(
                    angle,
                    impulse,
                    actuator.maximum_impulse_nms * MOTOR_FORCE_MARGIN as f64,
                );
        }
        native_motor_application_count += applications;
        motor_impulse_limit_violation_count += impulse_violations;
        if applications != output.actuation.ordered_commands.len() as u64 {
            actuator_application_mismatch_count += 1;
        }
        memory = output.next_memory;
        controller_semantic_step_count += 1;

        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        let (anchor_error, axis_error) = robot.structural_metrics(&compiled)?;
        maximum_anchor_error_m = maximum_anchor_error_m.max(anchor_error);
        maximum_hinge_axis_error_rad = maximum_hinge_axis_error_rad.max(axis_error);
        if robot.torso_ground_contact() {
            torso_ground_contact_count += 1;
            first_torso_ground_contact_semantic_step.get_or_insert(semantic_step);
        }
        let step_contacts = robot.contacts(&compiled);
        for (contact_site_id, bearing) in &step_contacts {
            contact_occupancy
                .get_mut(contact_site_id)
                .expect("compiled contact occupancy")
                .observe(*bearing);
        }
        if semantic_step >= CONTACT_GATED_START_STEP {
            for limb in &compiled.morphology.morphology_spec.limbs {
                let site = compiled
                    .morphology
                    .morphology_spec
                    .contact_sites
                    .iter()
                    .find(|site| site.contact_site_id == limb.ordered_contact_site_ids[0])
                    .expect("compiled limb contact site");
                let contact = robot.contact(&site.body_id);
                foot_evidence
                    .get_mut(&limb.limb_id)
                    .expect("limb evidence")
                    .observe(contact, robot.contact_site_position(site));
            }
        }
        if !evidence_limits_reached
            && semantic_step >= CONTACT_GATED_START_STEP
            && memory.ordered_limb_memory.iter().all(|limb| {
                limb.evidence_gait_step_limit
                    .is_some_and(|limit| limb.gait_step >= limit)
            })
        {
            evidence_limits_reached = true;
            evidence_completion_step = Some(semantic_step);
            evidence_end = Some(robot.torso_position());
            cooldown_end = Some(semantic_step + COOLDOWN_STEPS);
        }
        if cooldown_end.is_some_and(|end| semantic_step >= end) {
            cooldown_completed = true;
            break;
        }
    }

    let controller_limit_respected =
        controller_semantic_step_count + TERMINAL_SETTLE_STEPS <= MAXIMUM_CONTROLLER_SEMANTIC_STEPS;
    for _ in 0..TERMINAL_SETTLE_STEPS {
        robot.hold_zero_and_step()?;
        let torso = &robot.world.bodies[robot.bodies["torso"]];
        let up = torso.rotation() * Vector::Y;
        maximum_tilt_rad = maximum_tilt_rad.max(up.y.clamp(-1.0, 1.0).acos() as f64);
        minimum_torso_height_m = minimum_torso_height_m.min(torso.translation().y as f64);
        let (anchor_error, axis_error) = robot.structural_metrics(&compiled)?;
        maximum_anchor_error_m = maximum_anchor_error_m.max(anchor_error);
        maximum_hinge_axis_error_rad = maximum_hinge_axis_error_rad.max(axis_error);
        if robot.torso_ground_contact() {
            torso_ground_contact_count += 1;
        }
    }
    let final_position = robot.torso_position();
    let final_rotation = robot.world.bodies[robot.bodies["torso"]].rotation();
    let forward = final_rotation * Vector::X;
    let final_yaw = (forward.z as f64).atan2(forward.x as f64);
    let terminal_contacts = robot.contacts(&compiled);
    let terminal_four_contact_recovery = terminal_contacts.values().all(|contact| *contact);
    let evidence_delta = evidence_end
        .zip(evidence_start)
        .map(|(end, start)| end - start)
        .unwrap_or(Vector::splat(f32::NAN));
    let final_delta = final_position - task_origin;
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
        .collect::<serde_json::Map<_, _>>();
    let actuator_observability = actuator_evidence
        .iter()
        .map(|(actuator_id, evidence)| (actuator_id.clone(), evidence.receipt()))
        .collect::<serde_json::Map<_, _>>();
    let contact_observability = contact_occupancy
        .iter()
        .map(|(contact_site_id, evidence)| (contact_site_id.clone(), evidence.receipt()))
        .collect::<serde_json::Map<_, _>>();
    let final_limb_memory = memory
        .ordered_limb_memory
        .iter()
        .map(|limb| {
            (
                limb.limb_id.clone(),
                json!({
                    "gait_step": limb.gait_step,
                    "evidence_gait_step_limit": limb.evidence_gait_step_limit,
                    "release_hold_step_count": limb.release_hold_step_count,
                    "recontact_hold_step_count": limb.recontact_hold_step_count,
                    "gate_timeout_count": limb.gate_timeout_count,
                    "phase_sync_hold_step_count": limb.phase_sync_hold_step_count,
                }),
            )
        })
        .collect::<serde_json::Map<_, _>>();
    let observability = json!({
        "post_settle": {
            "torso_position_m": {
                "x": post_settle_position.x,
                "y": post_settle_position.y,
                "z": post_settle_position.z,
            },
            "torso_tilt_rad": post_settle_tilt_rad,
            "torso_height_m": post_settle_position.y,
            "torso_ground_contact": post_settle_torso_ground_contact,
            "ordered_joint_angles_rad": Value::Object(post_settle_joint_angles),
        },
        "first_torso_ground_contact_semantic_step":
            first_torso_ground_contact_semantic_step,
        "actuators": Value::Object(actuator_observability),
        "contacts": Value::Object(contact_observability),
        "final_limb_memory": Value::Object(final_limb_memory),
    });
    let mut report = json!({
        "schema_version": report_schema_version,
        "ok": false,
        "campaign_id": campaign_id,
        "gate_id": gate_id,
        "source_commit": source_commit.to_ascii_lowercase(),
        "preregistration_raw_sha256": preregistration_raw_sha256,
        "preflight": preflight,
        "engine": "rapier3d",
        "engine_version": rapier3d::VERSION,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "selected_policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
        "selected_policy_digest":
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "portable_morphology_spec_sha256": compiled.morphology.morphology_spec_sha256,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "body_count": compiled.morphology.ordered_body_ids.len(),
        "joint_count": compiled.morphology.ordered_joint_ids.len(),
        "actuator_count": compiled.morphology.ordered_actuator_ids.len(),
        "direct_body_write_count": 0,
        "controller_error_count": controller_error_count,
        "controller_error_receipts": controller_error_receipts,
        "safe_no_actuation_count": safe_no_actuation_count,
        "nonfinite_observation_count": nonfinite_observation_count,
        "actuator_application_mismatch_count": actuator_application_mismatch_count,
        "motor_impulse_limit_violation_count": motor_impulse_limit_violation_count,
        "controller_semantic_step_count": controller_semantic_step_count,
        "validated_portable_command_count": validated_portable_command_count,
        "native_motor_application_count": native_motor_application_count,
        "initial_four_contact_stance": initial_four_contact_stance,
        "terminal_four_contact_recovery": terminal_four_contact_recovery,
        "zero_torso_ground_contact": torso_ground_contact_count == 0,
        "torso_ground_contact_step_count": torso_ground_contact_count,
        "schedule": {
            "settle_steps": SETTLE_STEPS,
            "contact_gated_start_step": CONTACT_GATED_START_STEP,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "evidence_deadline_semantic_step": evidence_deadline,
            "evidence_limits_reached": evidence_limits_reached,
            "evidence_completion_semantic_step": evidence_completion_step,
            "cooldown_steps": COOLDOWN_STEPS,
            "cooldown_completed": cooldown_completed,
            "terminal_settle_steps": TERMINAL_SETTLE_STEPS,
            "terminal_settle_completed": true,
            "controller_limit_respected": controller_limit_respected,
        },
        "metrics": {
            "evidence_forward_displacement_m": evidence_delta.x,
            "final_forward_displacement_m": final_delta.x,
            "final_lateral_displacement_m": final_delta.z,
            "final_yaw_drift_rad": final_yaw,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "maximum_anchor_error_m": maximum_anchor_error_m,
            "maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
        },
        "limb_evidence": Value::Object(limb_evidence),
        "observability": observability,
        "claim_boundary": {
            "technical_commissioning_only": true,
            "independent_validation": false,
            "arbitrary_quadruped_coverage": false,
            "continuous_full_volume_coverage": false,
            "material_robustness": false,
            "rough_terrain_robustness": false,
            "external_push_recovery": false,
            "sensor_noise_or_latency_robustness": false,
            "cross_engine_c6": false,
            "locomotion_acceptance": false,
            "release_authorized": false,
            "physical_acceptance_authority": false,
            "completed_engine_neutral_sdk": false,
        },
    });
    let mut failures = full_integrity_failures_for(&report, failure_prefix);
    if !controller_limit_respected {
        failures.push("C6_RAP_SP1_CONTROLLER_STEP_LIMIT_EXCEEDED".to_owned());
    }
    if campaign_id == R2_CAMPAIGN_ID && !observability_receipt_complete(&report["observability"]) {
        failures.push("C6_RAP_SP1_R2_OBSERVABILITY_RECEIPT_INCOMPLETE".to_owned());
    }
    report["gate_failures"] = json!(failures);
    report["ok"] = json!(
        report["gate_failures"]
            .as_array()
            .is_some_and(Vec::is_empty)
    );
    report["rapier_selected_policy_single_body_technical_commissioning_passed"] =
        report["ok"].clone();
    report["rapier_selected_policy_physical_c6"] = json!(false);
    Ok(report)
}
