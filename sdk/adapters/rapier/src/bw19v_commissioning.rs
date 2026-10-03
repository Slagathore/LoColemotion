use std::collections::{BTreeMap, HashMap};

use rapier3d::prelude::{MotorModel, RevoluteJoint, Vector};
use serde_json::{Map, Value, json};
use sha2::{Digest, Sha256};
use sporespore_locomotion_core::protocol::{
    CommandAuthority, ContactObservation, ContactProvenance, ContactQuality, JointObservation,
    JointValidityMask, MOTION_COMMAND_VERSION, MotionCommand, PhaseProgressionMode, Pose,
    Quaternion, STATE_FRAME_VERSION, SpeedClass, StateFrame, TaskFrame, Twist,
};
use sporespore_locomotion_core::schema::Vec3;
use sporespore_locomotion_core::stability::{
    EndpointForceActuatorKinematicsV2, OrderedBodyStateV2, ScheduledLimbGaitStepV1,
    StabilityInfluenceAvailability, StabilityStateV2, SupportContactStateV2,
};
use sporespore_locomotion_core::{
    BALANCED_WAVE_BW15F_B_POLICY_ID, BalancedWaveController, BalancedWaveControllerMemory,
    CompiledQuadruped, STABILITY_STATE_VERSION, compile_bounded_quadruped, digest_json,
    digest_serializable,
};

use crate::bw19v_composition::{
    BW19V_AUTHORED_FRICTION, BW19V_CANDIDATE_COMPOSITION_DIGEST, BW19V_CANDIDATE_ID,
    BW19V_CHARACTERIZED_CONTROLLER_FRICTION, BW19V_CONTROLLER_POLICY_DIGEST,
    BW19V_CONTROLLER_POLICY_ID, BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
    BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON, BW19V_REFERENCE_RUNTIME_PROFILE_SHA256,
    BW19V_S169_RUNTIME_PROFILE_SHA256, RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN,
    RAPIER_BW19V_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
    RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
    RAPIER_BW19V_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
    RAPIER_BW19V_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S, RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
    RapierBw19vCompositionMemory, compose_bw19v_step,
    source_derived_velocity_delta_for_generalized_torque,
};
use crate::locomotion::{
    ActuatorEvidence, ContactOccupancyEvidence, FootEvidence, build_bw19v_robot, descriptor,
    full_integrity_failures_for, motion_command, state_contains_nonfinite,
};
use crate::{
    ADAPTER_ID, RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
    RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS, RAPIER_ACTIVE_SOLVER_ITERATIONS, RAPIER_DT_S,
    capability_manifest_sha256,
};

const PREREGISTRATION: &str =
    include_str!("../../../rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration.json");
pub const PREREGISTRATION_RAW_SHA256: &str =
    "sha256:231ddf65d2f12137f1215182c9076b46cd5f1adf3e0db2443ac4da1ecf1af319";
pub const CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1";
pub const GATE_ID: &str = "C6-RAP-BW19V-C1";
const C2_PREREGISTRATION: &str =
    include_str!("../../../rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration.json");
const C1_CLOSURE: &str =
    include_str!("../../../rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json");
pub const C2_PREREGISTRATION_RAW_SHA256: &str =
    "sha256:c2f4c071c7b55e20dd77f32b72370f6891c3b1b2426baa2fca2ac0e23730da27";
pub const C2_CAMPAIGN_ID: &str = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C2";
pub const C2_GATE_ID: &str = "C6-RAP-BW19V-C2";
const C1_CLOSURE_RAW_SHA256: &str =
    "sha256:e2919cc899df78aebe5d2486bb7250a1388044f2f040f53f23f581d113aa8fae";

const SETTLE_STEPS: u64 = 240;
const CONTACT_GATED_START_STEP: u64 = 472;
const EVIDENCE_GAIT_STEPS: u64 = 1440;
const MAXIMUM_EVIDENCE_EXTENSION_STEPS: u64 = 720;
const COOLDOWN_STEPS: u64 = 360;
const TERMINAL_SETTLE_STEPS: u64 = 240;
const MAXIMUM_CONTROLLER_SEMANTIC_STEPS: u64 = 3232;
const MOTOR_FORCE_MARGIN: f64 = 1.015;
const COMPLETE_SYNTHETIC_HORIZON_STEPS: u64 = MAXIMUM_CONTROLLER_SEMANTIC_STEPS;
const C2_ZERO_SUPPORT_START_STEP: u64 = 1440;
const C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE: u64 = 1800;
const C2_EXPECTED_AVAILABLE_PLAN_COUNT: u64 = 1920;
const C2_EXPECTED_OBSERVED_PLANNING_UNAVAILABLE_COUNT: u64 = 952;
const C2_EXPECTED_PARTIAL_SUPPORT_MAPPING_COUNT: u64 = 960;

#[derive(Clone, Copy)]
struct CampaignSpec {
    campaign_id: &'static str,
    gate_id: &'static str,
    preregistration: &'static str,
    preregistration_raw_sha256: &'static str,
    report_schema_version: &'static str,
    preflight_schema_version: &'static str,
    failure_prefix: &'static str,
    zero_support_segment: bool,
}

const C1_SPEC: CampaignSpec = CampaignSpec {
    campaign_id: CAMPAIGN_ID,
    gate_id: GATE_ID,
    preregistration: PREREGISTRATION,
    preregistration_raw_sha256: PREREGISTRATION_RAW_SHA256,
    report_schema_version: "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_report_v1",
    preflight_schema_version: "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_preflight_v1",
    failure_prefix: "C6_RAP_BW19V_C1",
    zero_support_segment: false,
};

const C2_SPEC: CampaignSpec = CampaignSpec {
    campaign_id: C2_CAMPAIGN_ID,
    gate_id: C2_GATE_ID,
    preregistration: C2_PREREGISTRATION,
    preregistration_raw_sha256: C2_PREREGISTRATION_RAW_SHA256,
    report_schema_version: "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_report_v1",
    preflight_schema_version: "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_preflight_v1",
    failure_prefix: "C6_RAP_BW19V_C2",
    zero_support_segment: true,
};

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
        return Err("C6_RAP_BW19V_C1_CONTROLLER_IDENTITY_MISMATCH".to_owned());
    }
    let profile_sha256 =
        digest_serializable(controller.profile()).map_err(|error| error.to_string())?;
    if profile_sha256 != BW19V_S169_RUNTIME_PROFILE_SHA256 {
        return Err(format!(
            "C6_RAP_BW19V_C1_RUNTIME_PROFILE_MISMATCH:{profile_sha256}"
        ));
    }
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

fn full_gate_failures_for_spec(report: &Value, spec: CampaignSpec) -> Vec<String> {
    let mut failures = full_integrity_failures_for(report, spec.failure_prefix);
    for (pointer, expected, name) in [
        (
            "/composition/composition_error_count",
            0,
            "COMPOSITION_ERROR_COUNT",
        ),
        (
            "/composition/global_scale_mismatch_count",
            0,
            "GLOBAL_SCALE_MISMATCH",
        ),
        (
            "/composition/host_response_conversion_failure_count",
            0,
            "HOST_RESPONSE_CONVERSION_FAILURE",
        ),
        (
            "/composition/inactive_contact_zero_mismatch_count",
            0,
            "INACTIVE_CONTACT_ZERO_MISMATCH",
        ),
        (
            "/composition/motor_model_readback_mismatch_count",
            0,
            "MOTOR_MODEL_READBACK_MISMATCH",
        ),
    ] {
        if u64_at(report, pointer) != Some(expected) {
            failures.push(format!("{}_{name}", spec.failure_prefix));
        }
    }
    if report["campaign_id"] != spec.campaign_id
        || report["gate_id"] != spec.gate_id
        || report["preregistration_raw_sha256"] != spec.preregistration_raw_sha256
        || report["candidate_id"] != BW19V_CANDIDATE_ID
        || report["candidate_composition_digest"] != BW19V_CANDIDATE_COMPOSITION_DIGEST
        || report["selected_policy_id"] != BW19V_CONTROLLER_POLICY_ID
        || report["selected_policy_digest"] != BW19V_CONTROLLER_POLICY_DIGEST
        || report["reference_runtime_profile_sha256"] != BW19V_REFERENCE_RUNTIME_PROFILE_SHA256
        || report["runtime_profile_sha256"] != BW19V_S169_RUNTIME_PROFILE_SHA256
    {
        failures.push(format!("{}_IDENTITY_MISMATCH", spec.failure_prefix));
    }
    if report["host_configuration"]["motor_model"] != "ForceBased"
        || u64_at(report, "/host_configuration/solver_iterations")
            != Some(RAPIER_ACTIVE_SOLVER_ITERATIONS as u64)
        || u64_at(report, "/host_configuration/internal_pgs_iterations")
            != Some(RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS as u64)
        || u64_at(
            report,
            "/host_configuration/internal_stabilization_iterations",
        ) != Some(RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS as u64)
        || f64_at(report, "/host_configuration/authored_friction")
            != Some(BW19V_AUTHORED_FRICTION as f64)
        || f64_at(
            report,
            "/host_configuration/characterized_controller_friction",
        ) != Some(BW19V_CHARACTERIZED_CONTROLLER_FRICTION)
    {
        failures.push(format!(
            "{}_HOST_CONFIGURATION_MISMATCH",
            spec.failure_prefix
        ));
    }
    let attempts = u64_at(report, "/composition/attempt_count");
    let plan_receipts = u64_at(report, "/composition/scheduled_plan_receipt_count");
    let influence_receipts = u64_at(report, "/composition/stability_influence_receipt_count");
    let influence_outputs = u64_at(report, "/composition/influence_output_count");
    let mapping_receipts = u64_at(report, "/composition/mapping_receipt_count");
    let available = u64_at(report, "/composition/available_plan_count");
    let unavailable = u64_at(report, "/composition/observation_unavailable_plan_count");
    let infeasible = u64_at(report, "/composition/upstream_infeasible_plan_count");
    let fail_zero = u64_at(report, "/composition/fail_zero_receipt_count");
    let controller_steps = u64_at(report, "/controller_semantic_step_count");
    if attempts.is_none()
        || attempts == Some(0)
        || attempts != controller_steps
        || plan_receipts != attempts
        || influence_receipts != attempts
        || influence_outputs != attempts.map(|count| count * 8)
        || available
            .zip(unavailable)
            .zip(infeasible)
            .map(|((a, u), i)| a + u + i)
            != attempts
        || mapping_receipts != available
        || fail_zero != unavailable.zip(infeasible).map(|(u, i)| u + i)
    {
        failures.push(format!(
            "{}_COMPOSITION_ACCOUNTING_INVALID",
            spec.failure_prefix
        ));
    }
    if f64_at(report, "/composition/global_requested_correction_scale")
        != Some(BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE)
        || f64_at(
            report,
            "/composition/response_reconstruction_maximum_error_nm",
        )
        .is_none_or(|error| error > 1.0e-12)
    {
        failures.push(format!("{}_RESPONSE_CONTRACT_FAILED", spec.failure_prefix));
    }
    for (pointer, name) in [
        (
            "/composition/nonzero_raw_request_count",
            "NONZERO_RAW_REQUEST_MISSING",
        ),
        (
            "/composition/nonzero_scaled_request_count",
            "NONZERO_SCALED_REQUEST_MISSING",
        ),
        (
            "/composition/nonzero_applied_contribution_count",
            "NONZERO_APPLIED_CONTRIBUTION_MISSING",
        ),
        (
            "/composition/nonzero_effective_host_application_count",
            "NONZERO_EFFECTIVE_HOST_APPLICATION_MISSING",
        ),
    ] {
        if u64_at(report, pointer).unwrap_or(0) == 0 {
            failures.push(format!("{}_{name}", spec.failure_prefix));
        }
    }
    if !bool_at(report, "/claim_boundary/technical_commissioning_only")
        || bool_at(report, "/claim_boundary/independent_validation")
        || bool_at(report, "/claim_boundary/arbitrary_quadruped_coverage")
        || bool_at(report, "/claim_boundary/material_robustness")
        || bool_at(report, "/claim_boundary/cross_engine_c6")
        || bool_at(report, "/claim_boundary/release_authorized")
        || bool_at(report, "/claim_boundary/physical_acceptance_authority")
    {
        failures.push(format!("{}_CLAIM_BOUNDARY_INVALID", spec.failure_prefix));
    }
    if spec.zero_support_segment {
        let unavailable_outputs = unavailable.map(|count| count * 8);
        let explicit_host_unavailable = u64_at(
            report,
            "/composition/explicit_host_observation_unavailable_plan_count",
        );
        let observed_planning_unavailable = u64_at(
            report,
            "/composition/observed_planning_unavailable_plan_count",
        );
        if !report["composition"]["first_composition_error_semantic_step"].is_null()
            || !report["composition"]["first_composition_error_code"].is_null()
            || explicit_host_unavailable
                .zip(observed_planning_unavailable)
                .map(|(explicit, observed)| explicit + observed)
                != unavailable
            || u64_at(
                report,
                "/composition/observation_unavailable_reason_mismatch_count",
            ) != Some(0)
            || u64_at(
                report,
                "/composition/observation_unavailable_base_command_mismatch_count",
            ) != Some(0)
            || u64_at(
                report,
                "/composition/observation_unavailable_stability_zero_mismatch_count",
            ) != Some(0)
            || u64_at(
                report,
                "/composition/observation_unavailable_base_command_application_count",
            ) != unavailable_outputs
            || u64_at(
                report,
                "/composition/observation_unavailable_exact_zero_stability_output_count",
            ) != unavailable_outputs
        {
            failures.push(format!(
                "{}_OBSERVATION_UNAVAILABLE_ROUTE_INVALID",
                spec.failure_prefix
            ));
        }
    }
    failures
}

fn perfect_synthetic_report(spec: CampaignSpec) -> Value {
    let limb = || {
        json!({
            "contact_cycles": 2,
            "maximum_foot_relocation_m": 0.01194880859375,
            "maximum_airborne_dwell_steps": 3,
        })
    };
    let steps = 100_u64;
    json!({
        "schema_version": spec.report_schema_version,
        "ok": false,
        "campaign_id": spec.campaign_id,
        "gate_id": spec.gate_id,
        "source_commit": "0000000000000000000000000000000000000000",
        "preregistration_raw_sha256": spec.preregistration_raw_sha256,
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "selected_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
        "reference_runtime_profile_sha256":
            BW19V_REFERENCE_RUNTIME_PROFILE_SHA256,
        "runtime_profile_sha256": BW19V_S169_RUNTIME_PROFILE_SHA256,
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
        "controller_semantic_step_count": steps,
        "validated_portable_command_count": steps * 8,
        "native_motor_application_count": steps * 8,
        "initial_four_contact_stance": true,
        "terminal_four_contact_recovery": true,
        "zero_torso_ground_contact": true,
        "host_configuration": {
            "motor_model": "ForceBased",
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations":
                RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "authored_friction": BW19V_AUTHORED_FRICTION,
            "characterized_controller_friction":
                BW19V_CHARACTERIZED_CONTROLLER_FRICTION,
        },
        "composition": {
            "attempt_count": steps,
            "scheduled_plan_receipt_count": steps,
            "stability_influence_receipt_count": steps,
            "influence_output_count": steps * 8,
            "mapping_receipt_count": steps,
            "available_plan_count": steps,
            "observation_unavailable_plan_count": 0,
            "explicit_host_observation_unavailable_plan_count": 0,
            "observed_planning_unavailable_plan_count": 0,
            "upstream_infeasible_plan_count": 0,
            "fail_zero_receipt_count": 0,
            "global_requested_correction_scale":
                BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "global_scale_mismatch_count": 0,
            "response_reconstruction_maximum_error_nm": 0.0,
            "host_response_conversion_failure_count": 0,
            "nonzero_raw_request_count": 8,
            "nonzero_scaled_request_count": 8,
            "nonzero_applied_contribution_count": 8,
            "nonzero_effective_host_application_count": 8,
            "inactive_contact_zero_mismatch_count": 0,
            "motor_model_readback_mismatch_count": 0,
            "composition_error_count": 0,
            "first_composition_error_semantic_step": Value::Null,
            "first_composition_error_code": Value::Null,
            "observation_unavailable_reason_mismatch_count": 0,
            "observation_unavailable_base_command_mismatch_count": 0,
            "observation_unavailable_stability_zero_mismatch_count": 0,
            "observation_unavailable_base_command_application_count": 0,
            "observation_unavailable_exact_zero_stability_output_count": 0,
        },
        "schedule": {
            "evidence_limits_reached": true,
            "cooldown_completed": true,
            "terminal_settle_completed": true,
        },
        "metrics": {
            "evidence_forward_displacement_m": 0.0401640625,
            "final_forward_displacement_m": 0.030123046875,
            "final_lateral_displacement_m": 0.0,
            "final_yaw_drift_rad": 0.0,
            "maximum_tilt_rad": 0.0,
            "minimum_torso_height_m": 0.4,
            "maximum_anchor_error_m": 0.0,
            "maximum_hinge_axis_error_rad": 0.0,
        },
        "limb_evidence": {
            "front_left": limb(),
            "front_right": limb(),
            "rear_left": limb(),
            "rear_right": limb(),
        },
        "claim_boundary": claim_boundary(),
    })
}

fn claim_boundary() -> Value {
    json!({
        "technical_commissioning_only": true,
        "independent_validation": false,
        "arbitrary_quadruped_coverage": false,
        "continuous_full_volume_coverage": false,
        "material_robustness": false,
        "rough_terrain_robustness": false,
        "external_push_recovery": false,
        "sensor_noise_or_latency_robustness": false,
        "cross_engine_c6": false,
        "different_physics_engines": false,
        "locomotion_acceptance": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
        "completed_engine_neutral_sdk": false,
    })
}

fn synthetic_positions(compiled: &CompiledQuadruped) -> Result<HashMap<String, Vec3>, String> {
    let mut positions = HashMap::new();
    positions.insert(
        "torso".to_owned(),
        Vec3 {
            x: 0.0,
            y: compiled.geometry.initial_torso_center_y_m,
            z: 0.0,
        },
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
            .ok_or_else(|| format!("C6_RAP_BW19V_C1_SYNTHETIC_JOINT:{}", body.body_id))?;
        let parent = positions
            .get(&joint.parent_body_id)
            .copied()
            .ok_or_else(|| "C6_RAP_BW19V_C1_SYNTHETIC_PARENT".to_owned())?;
        positions.insert(
            body.body_id.clone(),
            Vec3 {
                x: parent.x + joint.anchor_parent_m.x - joint.anchor_child_m.x,
                y: parent.y + joint.anchor_parent_m.y - joint.anchor_child_m.y,
                z: parent.z + joint.anchor_parent_m.z - joint.anchor_child_m.z,
            },
        );
    }
    Ok(positions)
}

fn synthetic_support_pattern(step: u64, contact_id: &str) -> bool {
    match step % 30 {
        0..=9 => true,
        10..=19 => contact_id != "front_left_foot",
        _ => contact_id == "front_right_foot" || contact_id == "rear_left_foot",
    }
}

fn synthetic_fixture(
    compiled: &CompiledQuadruped,
    semantic_step: u64,
    force_no_support: bool,
) -> Result<
    (
        StateFrame,
        StabilityStateV2,
        Vec<EndpointForceActuatorKinematicsV2>,
    ),
    String,
> {
    let positions = synthetic_positions(compiled)?;
    let identity = Quaternion {
        x: 0.0,
        y: 0.0,
        z: 0.0,
        w: 1.0,
    };
    let synthetic_torso_roll_rad = 0.10_f64;
    let torso_orientation = Quaternion {
        x: (synthetic_torso_roll_rad / 2.0).sin(),
        y: 0.0,
        z: 0.0,
        w: (synthetic_torso_roll_rad / 2.0).cos(),
    };
    let zero = Vec3::ZERO;
    let ordered_body_states = compiled
        .morphology
        .morphology_spec
        .bodies
        .iter()
        .map(|body| OrderedBodyStateV2 {
            body_id: body.body_id.clone(),
            pose_world: Pose {
                position_m: positions[&body.body_id],
                orientation_xyzw: if body.body_id == "torso" {
                    torso_orientation
                } else {
                    identity
                },
            },
            twist_world: Twist {
                linear_velocity_m_s: zero,
                angular_velocity_rad_s: zero,
            },
        })
        .collect::<Vec<_>>();
    let mut ordered_support_contacts =
        Vec::with_capacity(compiled.morphology.ordered_contact_site_ids.len());
    let mut state_contacts = Vec::with_capacity(compiled.morphology.ordered_contact_site_ids.len());
    let mut endpoint_by_contact = HashMap::new();
    for site in &compiled.morphology.morphology_spec.contact_sites {
        let body = positions[&site.body_id];
        // Keep the synthetic leg endpoints inside a declared, non-singular
        // pitch-actuation geometry. A perfectly vertical leg makes a vertical
        // support-force delta pass exactly through both pitch anchors and
        // therefore produces a legitimate zero generalized torque; that is a
        // useful physical configuration but cannot prove the nonzero response
        // branch of this composition contract.
        let endpoint_pitch_offset_m = if site.contact_site_id.starts_with("front_") {
            0.05
        } else {
            -0.05
        };
        let point = Vec3 {
            x: body.x + site.local_center_m.x + endpoint_pitch_offset_m,
            y: body.y + site.local_center_m.y,
            z: body.z + site.local_center_m.z,
        };
        endpoint_by_contact.insert(site.contact_site_id.as_str(), point);
        let present =
            !force_no_support && synthetic_support_pattern(semantic_step, &site.contact_site_id);
        ordered_support_contacts.push(SupportContactStateV2 {
            contact_site_id: site.contact_site_id.clone(),
            presence: Some(present),
            bears_support: Some(present),
            point_world_m: present.then_some(point),
            normal_world_unit: present.then_some(Vec3 {
                x: 0.0,
                y: 1.0,
                z: 0.0,
            }),
            surface_relative_velocity_world_m_s: present.then_some(zero),
            material_id: Some("rapier_bw19v_mu095".to_owned()),
            adapter_id: ADAPTER_ID.to_owned(),
            engine_contact_ids: if present {
                vec![format!("synthetic_pair_{}", site.contact_site_id)]
            } else {
                Vec::new()
            },
        });
        state_contacts.push(ContactObservation {
            contact_site_id: site.contact_site_id.clone(),
            presence: Some(present),
            bears_support: Some(present),
            normal_load_n: None,
            provenance: ContactProvenance {
                adapter_id: ADAPTER_ID.to_owned(),
                engine_contact_ids: if present {
                    vec![format!("synthetic_pair_{}", site.contact_site_id)]
                } else {
                    Vec::new()
                },
                aggregation_rule_id: "synthetic_declared_support_pattern_equals_bearing_v1"
                    .to_owned(),
                quality: ContactQuality::QualifiedBearing,
                impulse_source_profile_id: None,
                impulse_source_kind: None,
            },
        });
    }
    let stability_state = StabilityStateV2 {
        schema_version: STABILITY_STATE_VERSION.to_owned(),
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
    };
    let ordered_kinematics = compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .map(|actuator| {
            let joint = compiled
                .morphology
                .morphology_spec
                .joints
                .iter()
                .find(|joint| joint.joint_id == actuator.joint_id)
                .expect("compiled actuator joint");
            let limb = compiled
                .morphology
                .morphology_spec
                .limbs
                .iter()
                .find(|limb| limb.ordered_joint_ids.contains(&joint.joint_id))
                .expect("compiled actuator limb");
            let contact_site_id = limb.ordered_contact_site_ids[0].clone();
            let parent = positions[&joint.parent_body_id];
            EndpointForceActuatorKinematicsV2 {
                actuator_id: actuator.actuator_id.clone(),
                contact_site_id: contact_site_id.clone(),
                joint_anchor_world_m: Vec3 {
                    x: parent.x + joint.anchor_parent_m.x,
                    y: parent.y + joint.anchor_parent_m.y,
                    z: parent.z + joint.anchor_parent_m.z,
                },
                joint_axis_world_unit: joint.axis_parent_unit,
                endpoint_world_m: endpoint_by_contact[contact_site_id.as_str()],
            }
        })
        .collect();
    let torso = positions["torso"];
    let state = StateFrame {
        schema_version: STATE_FRAME_VERSION.to_owned(),
        semantic_step,
        sample_time_s: semantic_step as f64 * RAPIER_DT_S as f64,
        base_pose_world: Pose {
            position_m: torso,
            orientation_xyzw: torso_orientation,
        },
        base_twist_world: Twist {
            linear_velocity_m_s: zero,
            angular_velocity_rad_s: zero,
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
        ordered_contact_observations: state_contacts,
        previous_applied_actuation: None,
        gravity_world_m_s2: stability_state.gravity_world_m_s2,
        task_frame: TaskFrame {
            origin_world_m: torso,
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
    };
    Ok((state, stability_state, ordered_kinematics))
}

fn preflight_motion_command(step: u64, mode: PhaseProgressionMode) -> MotionCommand {
    MotionCommand {
        schema_version: MOTION_COMMAND_VERSION.to_owned(),
        command_id: format!("rapier_bw19v_c1_synthetic_{step}"),
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
        phase_progression_mode: mode,
        valid_from_step: step,
        valid_through_step: step,
        authority: CommandAuthority::TestFixture,
    }
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
                .ok_or_else(|| format!("C6_RAP_BW19V_C1_LIMB_MEMORY_MISSING:{limb_id}"))
        })
        .collect()
}

fn run_bw19v_selected_policy_commissioning_preflight_impl(
    spec: CampaignSpec,
) -> Result<Value, String> {
    if raw_sha256(spec.preregistration) != spec.preregistration_raw_sha256 {
        return Err(format!(
            "{}_PREREGISTRATION_HASH_MISMATCH",
            spec.failure_prefix
        ));
    }
    let preregistration: Value = serde_json::from_str(spec.preregistration)
        .map_err(|error| format!("{}_PREREGISTRATION_PARSE:{error}", spec.failure_prefix))?;
    if preregistration["campaign_id"] != spec.campaign_id
        || preregistration["gate_id"] != spec.gate_id
        || preregistration["portable_policy_identity"]["candidate_composition_digest"]
            != BW19V_CANDIDATE_COMPOSITION_DIGEST
    {
        return Err(format!("{}_PREREGISTRATION_IDENTITY", spec.failure_prefix));
    }
    if spec.zero_support_segment {
        if raw_sha256(C1_CLOSURE) != C1_CLOSURE_RAW_SHA256 {
            return Err(format!("{}_C1_CLOSURE_HASH_MISMATCH", spec.failure_prefix));
        }
        let predecessor: Value = serde_json::from_str(C1_CLOSURE)
            .map_err(|error| format!("{}_C1_CLOSURE_PARSE:{error}", spec.failure_prefix))?;
        if predecessor["status"]
            != "closed_negative_portable_observation_availability_routing_failure"
            || predecessor["disposition"]["same_identity_rerun_allowed"] != false
            || preregistration["predecessor_interlocks"]["c1_closure_raw_sha256"]
                != C1_CLOSURE_RAW_SHA256.trim_start_matches("sha256:")
        {
            return Err(format!(
                "{}_C1_DECLARATION_CHAIN_INVALID",
                spec.failure_prefix
            ));
        }
    }
    let (compiled, controller) = compile_declared_boundary()?;
    let runtime_profile_sha256 =
        digest_serializable(controller.profile()).map_err(|error| error.to_string())?;
    let mut default_canary = RevoluteJoint::new(Vector::Z);
    default_canary.set_motor(0.0, 0.0, 40.0, 10.0);
    let default_model = default_canary.motor().map(|motor| motor.model);
    let mut explicit = RevoluteJoint::new(Vector::Z);
    explicit
        .set_motor(0.0, 0.0, 40.0, 10.0)
        .set_motor_model(MotorModel::ForceBased);
    let explicit_model = explicit.motor().map(|motor| motor.model);
    explicit
        .set_motor(0.1, -0.2, 40.0, 10.0)
        .set_motor_model(MotorModel::ForceBased);
    let mutable_model = explicit.motor().map(|motor| motor.model);

    let signed_response_pair_passed = [-0.75, 0.75].into_iter().all(|torque| {
        source_derived_velocity_delta_for_generalized_torque(torque).is_ok_and(|delta| {
            delta.signum() == torque.signum()
                && (delta * RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD - torque).abs() <= 1.0e-12
        })
    });
    let nonfinite_response_canaries_rejected =
        source_derived_velocity_delta_for_generalized_torque(f64::NAN).is_err()
            && source_derived_velocity_delta_for_generalized_torque(f64::INFINITY).is_err();

    let mut controller_memory = BalancedWaveControllerMemory::initial();
    let mut composition_memory = RapierBw19vCompositionMemory::default();
    let mut available_count = 0_u64;
    let mut observation_unavailable_count = 0_u64;
    let mut explicit_host_observation_unavailable_count = 0_u64;
    let mut observed_planning_unavailable_count = 0_u64;
    let mut upstream_infeasible_count = 0_u64;
    let mut partial_support_count = 0_u64;
    let mut fail_zero_count = 0_u64;
    let mut nonzero_raw_count = 0_u64;
    let mut nonzero_scaled_count = 0_u64;
    let mut nonzero_applied_count = 0_u64;
    let mut nonzero_effective_count = 0_u64;
    let mut influence_output_count = 0_u64;
    let mut observation_unavailable_base_application_count = 0_u64;
    let mut observation_unavailable_exact_zero_stability_output_count = 0_u64;
    let mut explicit_host_unavailable_base_application_count = 0_u64;
    let mut explicit_host_unavailable_exact_zero_stability_output_count = 0_u64;
    let mut available_before_zero_segment = false;
    let mut available_after_zero_segment = false;
    for semantic_step in 0..COMPLETE_SYNTHETIC_HORIZON_STEPS {
        let force_no_support = spec.zero_support_segment
            && (C2_ZERO_SUPPORT_START_STEP..C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE)
                .contains(&semantic_step);
        let (state, stability_state, kinematics) =
            synthetic_fixture(&compiled, semantic_step, force_no_support)?;
        let limb_steps = ordered_limb_steps(&compiled, &controller_memory)?;
        let phase_mode = if semantic_step < CONTACT_GATED_START_STEP {
            PhaseProgressionMode::Clocked
        } else {
            PhaseProgressionMode::ContactGated
        };
        let output = controller.step(
            &controller_memory,
            &state,
            &preflight_motion_command(semantic_step, phase_mode),
        );
        if output.actuation.safe_no_actuation {
            return Err(format!(
                "C6_RAP_BW19V_C1_SYNTHETIC_BASE_SAFE_ZERO:{semantic_step}"
            ));
        }
        let receipt = compose_bw19v_step(
            &compiled,
            &output.actuation,
            stability_state,
            kinematics,
            limb_steps,
            &mut composition_memory,
        )?;
        match receipt.scheduled_load_transfer.planning_availability {
            StabilityInfluenceAvailability::Available => {
                available_count += 1;
                if semantic_step < C2_ZERO_SUPPORT_START_STEP {
                    available_before_zero_segment = true;
                }
                if semantic_step >= C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE {
                    available_after_zero_segment = true;
                }
            }
            StabilityInfluenceAvailability::ObservationUnavailable => {
                observation_unavailable_count += 1;
                fail_zero_count += 1;
                let explicit_host_unavailable =
                    !receipt.scheduled_load_transfer.observation_input_available;
                if !explicit_host_unavailable {
                    observed_planning_unavailable_count += 1;
                    if force_no_support
                        || receipt
                            .scheduled_load_transfer
                            .observation_unavailable_reason
                            .is_some()
                    {
                        return Err(format!(
                            "{}_SYNTHETIC_OBSERVED_PLANNING_UNAVAILABLE_INVALID:{semantic_step}",
                            spec.failure_prefix
                        ));
                    }
                } else {
                    explicit_host_observation_unavailable_count += 1;
                    if !force_no_support
                        || receipt
                            .scheduled_load_transfer
                            .observation_unavailable_reason
                            .as_deref()
                            != Some(BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON)
                        || receipt.scheduled_load_transfer.planning_outcome_code
                            != format!(
                                "OBSERVATION_UNAVAILABLE:{BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON}"
                            )
                    {
                        return Err(format!(
                            "{}_SYNTHETIC_EXPLICIT_UNAVAILABLE_RECEIPT_INVALID:{semantic_step}",
                            spec.failure_prefix
                        ));
                    }
                }
                if !receipt.scheduled_load_transfer.fail_zero_required
                    || receipt.endpoint_mapping.is_some()
                {
                    return Err(format!(
                        "{}_SYNTHETIC_UNAVAILABLE_FAIL_ZERO_INVALID:{semantic_step}",
                        spec.failure_prefix
                    ));
                }
                for command in &receipt.ordered_commands {
                    if command.raw_generalized_torque_command_nm.is_some()
                        || command.raw_canonical_velocity_delta_rad_s.is_some()
                        || command.scaled_canonical_velocity_delta_rad_s.is_some()
                        || command.applied_canonical_velocity_delta_rad_s != 0.0
                        || command.requested_host_target_velocity_delta_rad_s != 0.0
                        || command.effective_host_target_velocity_delta_rad_s != 0.0
                        || command.combined_target_velocity_rad_s
                            != command.base_target_velocity_rad_s
                    {
                        return Err(format!(
                            "{}_SYNTHETIC_UNAVAILABLE_COMPOSITION_INVALID:{semantic_step}:{}",
                            spec.failure_prefix, command.actuator_id
                        ));
                    }
                    observation_unavailable_base_application_count += 1;
                    observation_unavailable_exact_zero_stability_output_count += 1;
                    if explicit_host_unavailable {
                        explicit_host_unavailable_base_application_count += 1;
                        explicit_host_unavailable_exact_zero_stability_output_count += 1;
                    }
                }
            }
            StabilityInfluenceAvailability::UpstreamInfeasible => {
                upstream_infeasible_count += 1;
                fail_zero_count += 1;
            }
        }
        if receipt
            .endpoint_mapping
            .as_ref()
            .is_some_and(|mapping| mapping.inactive_actuator_count > 0)
        {
            partial_support_count += 1;
        }
        nonzero_raw_count += receipt.nonzero_raw_request_count as u64;
        nonzero_scaled_count += receipt.nonzero_scaled_request_count as u64;
        nonzero_applied_count += receipt.nonzero_applied_contribution_count as u64;
        nonzero_effective_count += receipt.nonzero_effective_host_application_count as u64;
        influence_output_count += receipt.ordered_commands.len() as u64;
        controller_memory = output.next_memory;
    }
    let complete_horizon_passed = available_count > 0
        && partial_support_count > 0
        && fail_zero_count > 0
        && nonzero_effective_count > 0
        && influence_output_count == COMPLETE_SYNTHETIC_HORIZON_STEPS * 8
        && (!spec.zero_support_segment
            || (explicit_host_observation_unavailable_count
                == C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE - C2_ZERO_SUPPORT_START_STEP
                && available_count == C2_EXPECTED_AVAILABLE_PLAN_COUNT
                && observed_planning_unavailable_count
                    == C2_EXPECTED_OBSERVED_PLANNING_UNAVAILABLE_COUNT
                && upstream_infeasible_count == 0
                && partial_support_count == C2_EXPECTED_PARTIAL_SUPPORT_MAPPING_COUNT
                && observation_unavailable_count
                    == explicit_host_observation_unavailable_count
                        + observed_planning_unavailable_count
                && observation_unavailable_base_application_count
                    == observation_unavailable_count * 8
                && observation_unavailable_exact_zero_stability_output_count
                    == observation_unavailable_count * 8
                && explicit_host_unavailable_base_application_count
                    == explicit_host_observation_unavailable_count * 8
                && explicit_host_unavailable_exact_zero_stability_output_count
                    == explicit_host_observation_unavailable_count * 8
                && available_before_zero_segment
                && available_after_zero_segment));

    let synthetic = perfect_synthetic_report(spec);
    let perfect_failures = full_gate_failures_for_spec(&synthetic, spec);
    let mut wrong_scale = synthetic.clone();
    wrong_scale["composition"]["global_requested_correction_scale"] = json!(0.0);
    let mut wrong_count = synthetic.clone();
    wrong_count["composition"]["stability_influence_receipt_count"] = json!(99);
    let mut wrong_model = synthetic.clone();
    wrong_model["host_configuration"]["motor_model"] = json!("AccelerationBased");
    let mut missing_application = synthetic.clone();
    missing_application["composition"]["nonzero_effective_host_application_count"] = json!(0);
    let mut unavailable_route_mismatch = synthetic.clone();
    unavailable_route_mismatch["composition"]["observation_unavailable_reason_mismatch_count"] =
        json!(1);
    let serialized = serde_json::to_string(&synthetic)
        .map_err(|error| format!("{}_SYNTHETIC_SERIALIZE:{error}", spec.failure_prefix))?;
    let round_trip: Value = serde_json::from_str(&serialized)
        .map_err(|error| format!("{}_SYNTHETIC_ROUND_TRIP:{error}", spec.failure_prefix))?;
    let ok = default_model == Some(MotorModel::AccelerationBased)
        && explicit_model == Some(MotorModel::ForceBased)
        && mutable_model == Some(MotorModel::ForceBased)
        && runtime_profile_sha256 == BW19V_S169_RUNTIME_PROFILE_SHA256
        && signed_response_pair_passed
        && nonfinite_response_canaries_rejected
        && complete_horizon_passed
        && perfect_failures.is_empty()
        && !full_gate_failures_for_spec(&wrong_scale, spec).is_empty()
        && !full_gate_failures_for_spec(&wrong_count, spec).is_empty()
        && !full_gate_failures_for_spec(&wrong_model, spec).is_empty()
        && !full_gate_failures_for_spec(&missing_application, spec).is_empty()
        && (!spec.zero_support_segment
            || !full_gate_failures_for_spec(&unavailable_route_mismatch, spec).is_empty())
        && round_trip == synthetic;
    Ok(json!({
        "schema_version": spec.preflight_schema_version,
        "ok": ok,
        "campaign_id": spec.campaign_id,
        "gate_id": spec.gate_id,
        "preregistration_raw_sha256": spec.preregistration_raw_sha256,
        "c1_closure_raw_sha256": if spec.zero_support_segment {
            Value::String(C1_CLOSURE_RAW_SHA256.to_owned())
        } else {
            Value::Null
        },
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "selected_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
        "runtime_profile_sha256": runtime_profile_sha256,
        "selected_policy_branch_surface_count": controller.profile().branch_surfaces.len(),
        "default_model_canary_passed":
            default_model == Some(MotorModel::AccelerationBased),
        "explicit_builder_force_based_passed":
            explicit_model == Some(MotorModel::ForceBased),
        "mutable_update_force_based_passed":
            mutable_model == Some(MotorModel::ForceBased),
        "signed_response_pair_passed": signed_response_pair_passed,
        "nonfinite_response_canaries_rejected":
            nonfinite_response_canaries_rejected,
        "complete_declared_horizon_steps": COMPLETE_SYNTHETIC_HORIZON_STEPS,
        "complete_declared_horizon_passed": complete_horizon_passed,
        "synthetic_available_plan_count": available_count,
        "synthetic_observation_unavailable_plan_count": observation_unavailable_count,
        "synthetic_explicit_host_observation_unavailable_plan_count":
            explicit_host_observation_unavailable_count,
        "synthetic_observed_planning_unavailable_plan_count":
            observed_planning_unavailable_count,
        "synthetic_upstream_infeasible_plan_count": upstream_infeasible_count,
        "synthetic_partial_support_mapping_count": partial_support_count,
        "synthetic_fail_zero_count": fail_zero_count,
        "synthetic_nonzero_raw_request_count": nonzero_raw_count,
        "synthetic_nonzero_scaled_request_count": nonzero_scaled_count,
        "synthetic_nonzero_applied_contribution_count": nonzero_applied_count,
        "synthetic_nonzero_effective_application_count": nonzero_effective_count,
        "synthetic_influence_output_count": influence_output_count,
        "sustained_zero_support_segment_start_step_inclusive":
            if spec.zero_support_segment {
                Value::from(C2_ZERO_SUPPORT_START_STEP)
            } else {
                Value::Null
            },
        "sustained_zero_support_segment_end_step_exclusive":
            if spec.zero_support_segment {
                Value::from(C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE)
            } else {
                Value::Null
            },
        "sustained_zero_support_segment_steps":
            if spec.zero_support_segment {
                Value::from(C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE - C2_ZERO_SUPPORT_START_STEP)
            } else {
                Value::Null
            },
        "synthetic_observation_unavailable_base_application_count":
            observation_unavailable_base_application_count,
        "synthetic_observation_unavailable_exact_zero_stability_output_count":
            observation_unavailable_exact_zero_stability_output_count,
        "synthetic_explicit_host_unavailable_base_application_count":
            explicit_host_unavailable_base_application_count,
        "synthetic_explicit_host_unavailable_exact_zero_stability_output_count":
            explicit_host_unavailable_exact_zero_stability_output_count,
        "available_receipt_before_zero_support_segment": available_before_zero_segment,
        "available_receipt_after_zero_support_segment": available_after_zero_segment,
        "perfect_synthetic_whole_gate_passed": perfect_failures.is_empty(),
        "perfect_synthetic_failures": perfect_failures,
        "wrong_scale_canary_rejected":
            !full_gate_failures_for_spec(&wrong_scale, spec).is_empty(),
        "composition_count_canary_rejected":
            !full_gate_failures_for_spec(&wrong_count, spec).is_empty(),
        "motor_model_canary_rejected":
            !full_gate_failures_for_spec(&wrong_model, spec).is_empty(),
        "missing_nonzero_application_canary_rejected":
            !full_gate_failures_for_spec(&missing_application, spec).is_empty(),
        "observation_unavailable_route_canary_rejected":
            !full_gate_failures_for_spec(&unavailable_route_mismatch, spec).is_empty(),
        "serialization_round_trip_passed": round_trip == synthetic,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_bw19v_selected_policy_commissioning_preflight() -> Result<Value, String> {
    run_bw19v_selected_policy_commissioning_preflight_impl(C1_SPEC)
}

pub fn run_bw19v_selected_policy_commissioning_c2_preflight() -> Result<Value, String> {
    run_bw19v_selected_policy_commissioning_preflight_impl(C2_SPEC)
}

pub fn run_bw19v_selected_policy_commissioning(source_commit: &str) -> Result<Value, String> {
    run_bw19v_selected_policy_commissioning_impl(source_commit, C1_SPEC)
}

pub fn run_bw19v_selected_policy_commissioning_c2(source_commit: &str) -> Result<Value, String> {
    run_bw19v_selected_policy_commissioning_impl(source_commit, C2_SPEC)
}

fn run_bw19v_selected_policy_commissioning_impl(
    source_commit: &str,
    spec: CampaignSpec,
) -> Result<Value, String> {
    if source_commit.len() != 40 || !source_commit.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(format!("{}_SOURCE_COMMIT_INVALID", spec.failure_prefix));
    }
    let preflight = run_bw19v_selected_policy_commissioning_preflight_impl(spec)?;
    if preflight["ok"] != true {
        return Err(format!("{}_PREFLIGHT_FAILED", spec.failure_prefix));
    }
    let (compiled, controller) = compile_declared_boundary()?;
    let mut robot = build_bw19v_robot(&compiled)?;
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
        .collect::<Result<Map<String, Value>, String>>()?;
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
    let mut composition_memory = RapierBw19vCompositionMemory::default();
    let mut evidence_start = None::<Vector>;
    let mut evidence_end = None::<Vector>;
    let mut evidence_limits_reached = false;
    let mut evidence_completion_step = None::<u64>;
    let mut controller_semantic_step_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_motor_application_count = 0_u64;
    let mut controller_error_count = 0_u64;
    let mut controller_error_receipts = BTreeMap::<String, u64>::new();
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
    let mut actuator_evidence = compiled
        .morphology
        .ordered_actuator_ids
        .iter()
        .map(|actuator_id| (actuator_id.clone(), ActuatorEvidence::new()))
        .collect::<BTreeMap<_, _>>();

    let mut composition_attempt_count = 0_u64;
    let mut composition_error_count = 0_u64;
    let mut composition_error_codes = BTreeMap::<String, u64>::new();
    let mut first_composition_error_semantic_step = None::<u64>;
    let mut first_composition_error_code = None::<String>;
    let mut scheduled_plan_receipt_count = 0_u64;
    let mut stability_influence_receipt_count = 0_u64;
    let mut influence_output_count = 0_u64;
    let mut mapping_receipt_count = 0_u64;
    let mut available_plan_count = 0_u64;
    let mut observation_unavailable_plan_count = 0_u64;
    let mut explicit_host_observation_unavailable_plan_count = 0_u64;
    let mut observed_planning_unavailable_plan_count = 0_u64;
    let mut upstream_infeasible_plan_count = 0_u64;
    let mut fail_zero_receipt_count = 0_u64;
    let mut global_scale_mismatch_count = 0_u64;
    let mut response_reconstruction_maximum_error_nm = 0.0_f64;
    let host_response_conversion_failure_count = 0_u64;
    let mut nonzero_raw_request_count = 0_u64;
    let mut nonzero_scaled_request_count = 0_u64;
    let mut nonzero_applied_contribution_count = 0_u64;
    let mut nonzero_effective_host_application_count = 0_u64;
    let mut host_speed_saturation_count = 0_u64;
    let mut inactive_contact_exact_zero_count = 0_u64;
    let inactive_contact_zero_mismatch_count = 0_u64;
    let motor_model_readback_mismatch_count = 0_u64;
    let mut observation_unavailable_reason_mismatch_count = 0_u64;
    let mut observation_unavailable_base_command_mismatch_count = 0_u64;
    let mut observation_unavailable_stability_zero_mismatch_count = 0_u64;
    let mut observation_unavailable_base_command_application_count = 0_u64;
    let mut observation_unavailable_exact_zero_stability_output_count = 0_u64;
    let mut first_composition_receipt_sha256 = None::<String>;
    let mut last_composition_receipt_sha256 = None::<String>;

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
        let stability_state = robot.bw19v_stability_state(&compiled, semantic_step)?;
        let kinematics = robot.bw19v_endpoint_kinematics(&compiled, &stability_state)?;
        let limb_steps = ordered_limb_steps(&compiled, &memory)?;
        let output = controller.step(&memory, &state, &motion_command(semantic_step, phase_mode));
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
            .map_err(|error| format!("C6_RAP_BW19V_C1_ACTUATION_INVALID:{error}"))?;
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        composition_attempt_count += 1;
        let composition = compose_bw19v_step(
            &compiled,
            &output.actuation,
            stability_state,
            kinematics,
            limb_steps,
            &mut composition_memory,
        );
        match composition {
            Ok(receipt) => {
                scheduled_plan_receipt_count += 1;
                stability_influence_receipt_count += 1;
                influence_output_count += receipt.ordered_commands.len() as u64;
                if receipt.endpoint_mapping.is_some() {
                    mapping_receipt_count += 1;
                }
                match receipt.scheduled_load_transfer.planning_availability {
                    StabilityInfluenceAvailability::Available => available_plan_count += 1,
                    StabilityInfluenceAvailability::ObservationUnavailable => {
                        observation_unavailable_plan_count += 1;
                        if receipt.scheduled_load_transfer.observation_input_available {
                            observed_planning_unavailable_plan_count += 1;
                            if receipt
                                .scheduled_load_transfer
                                .observation_unavailable_reason
                                .is_some()
                            {
                                observation_unavailable_reason_mismatch_count += 1;
                            }
                        } else {
                            explicit_host_observation_unavailable_plan_count += 1;
                            if receipt
                                .scheduled_load_transfer
                                .observation_unavailable_reason
                                .as_deref()
                                != Some(BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON)
                                || receipt.scheduled_load_transfer.planning_outcome_code
                                    != format!(
                                        "OBSERVATION_UNAVAILABLE:{BW19V_NO_QUALIFIED_SUPPORT_CONTACT_REASON}"
                                    )
                            {
                                observation_unavailable_reason_mismatch_count += 1;
                            }
                        }
                        for command in &receipt.ordered_commands {
                            if command.combined_target_velocity_rad_s
                                == command.base_target_velocity_rad_s
                            {
                                observation_unavailable_base_command_application_count += 1;
                            } else {
                                observation_unavailable_base_command_mismatch_count += 1;
                            }
                            if command.raw_generalized_torque_command_nm.is_none()
                                && command.raw_canonical_velocity_delta_rad_s.is_none()
                                && command.scaled_canonical_velocity_delta_rad_s.is_none()
                                && command.applied_canonical_velocity_delta_rad_s == 0.0
                                && command.requested_host_target_velocity_delta_rad_s == 0.0
                                && command.effective_host_target_velocity_delta_rad_s == 0.0
                            {
                                observation_unavailable_exact_zero_stability_output_count += 1;
                            } else {
                                observation_unavailable_stability_zero_mismatch_count += 1;
                            }
                        }
                    }
                    StabilityInfluenceAvailability::UpstreamInfeasible => {
                        upstream_infeasible_plan_count += 1
                    }
                }
                if receipt.scheduled_load_transfer.fail_zero_required {
                    fail_zero_receipt_count += 1;
                }
                if receipt
                    .stability_influence
                    .global_requested_correction_scale
                    != BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE
                {
                    global_scale_mismatch_count += 1;
                }
                response_reconstruction_maximum_error_nm = response_reconstruction_maximum_error_nm
                    .max(receipt.response_reconstruction_maximum_error_nm);
                nonzero_raw_request_count += receipt.nonzero_raw_request_count as u64;
                nonzero_scaled_request_count += receipt.nonzero_scaled_request_count as u64;
                nonzero_applied_contribution_count +=
                    receipt.nonzero_applied_contribution_count as u64;
                nonzero_effective_host_application_count +=
                    receipt.nonzero_effective_host_application_count as u64;
                host_speed_saturation_count += receipt.host_speed_saturation_count as u64;
                inactive_contact_exact_zero_count +=
                    receipt.inactive_contact_exact_zero_count as u64;
                for command in &receipt.ordered_commands {
                    actuator_evidence
                        .get_mut(&command.actuator_id)
                        .expect("compiled actuator evidence")
                        .observe_command(
                            command.base_target_position_rad,
                            command.combined_target_velocity_rad_s,
                        );
                }
                let receipt_json = receipt.to_json();
                let receipt_sha256 =
                    digest_json(&receipt_json).map_err(|error| error.to_string())?;
                first_composition_receipt_sha256.get_or_insert(receipt_sha256.clone());
                last_composition_receipt_sha256 = Some(receipt_sha256);
                let (applications, violations) =
                    robot.apply_bw19v_composed_actuation(&receipt.ordered_commands)?;
                native_motor_application_count += applications;
                motor_impulse_limit_violation_count += violations;
                if applications != receipt.ordered_commands.len() as u64 {
                    actuator_application_mismatch_count += 1;
                }
            }
            Err(error) => {
                composition_error_count += 1;
                if first_composition_error_semantic_step.is_none() {
                    first_composition_error_semantic_step = Some(semantic_step);
                    first_composition_error_code = Some(error.clone());
                }
                *composition_error_codes.entry(error).or_insert(0) += 1;
                actuator_application_mismatch_count += 1;
                robot.hold_zero_and_step()?;
            }
        }
        for actuator in &compiled.morphology.morphology_spec.actuators {
            let angle = robot.joint_angle(&actuator.joint_id)?;
            let impulse = robot.actuator_motor_impulse(&actuator.actuator_id)?;
            actuator_evidence
                .get_mut(&actuator.actuator_id)
                .expect("compiled actuator evidence")
                .observe_host(
                    angle,
                    impulse,
                    actuator.maximum_impulse_nms * MOTOR_FORCE_MARGIN,
                );
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
                foot_evidence
                    .get_mut(&limb.limb_id)
                    .expect("limb evidence")
                    .observe(
                        robot.contact(&site.body_id),
                        robot.contact_site_position(site),
                    );
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
        .collect::<Map<_, _>>();
    let actuator_observability = actuator_evidence
        .iter()
        .map(|(actuator_id, evidence)| (actuator_id.clone(), evidence.receipt()))
        .collect::<Map<_, _>>();
    let contact_observability = contact_occupancy
        .iter()
        .map(|(contact_site_id, evidence)| (contact_site_id.clone(), evidence.receipt()))
        .collect::<Map<_, _>>();
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
        .collect::<Map<_, _>>();
    let mut report = json!({
        "schema_version": spec.report_schema_version,
        "ok": false,
        "campaign_id": spec.campaign_id,
        "gate_id": spec.gate_id,
        "source_commit": source_commit.to_ascii_lowercase(),
        "preregistration_raw_sha256": spec.preregistration_raw_sha256,
        "c1_closure_raw_sha256": if spec.zero_support_segment {
            Value::String(C1_CLOSURE_RAW_SHA256.to_owned())
        } else {
            Value::Null
        },
        "preflight": preflight,
        "engine": "rapier3d",
        "engine_version": rapier3d::VERSION,
        "adapter_id": ADAPTER_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "candidate_id": BW19V_CANDIDATE_ID,
        "candidate_composition_digest": BW19V_CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": BW19V_CONTROLLER_POLICY_ID,
        "selected_policy_digest": BW19V_CONTROLLER_POLICY_DIGEST,
        "reference_runtime_profile_sha256":
            BW19V_REFERENCE_RUNTIME_PROFILE_SHA256,
        "runtime_profile_sha256": BW19V_S169_RUNTIME_PROFILE_SHA256,
        "stability_policy_id":
            sporespore_locomotion_core::SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID,
        "morphology_id": compiled.morphology_id,
        "descriptor_sha256": compiled.descriptor_sha256,
        "portable_morphology_spec_sha256":
            compiled.morphology.morphology_spec_sha256,
        "host_configuration": {
            "motor_model": "ForceBased",
            "motor_stiffness": 40.0,
            "motor_damping": RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
            "outer_timestep_s": RAPIER_DT_S,
            "solver_iterations": RAPIER_ACTIVE_SOLVER_ITERATIONS,
            "internal_pgs_iterations": RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS,
            "internal_stabilization_iterations":
                RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS,
            "authored_friction": BW19V_AUTHORED_FRICTION,
            "characterized_controller_friction":
                BW19V_CHARACTERIZED_CONTROLLER_FRICTION,
        },
        "source_derived_response_contract": {
            "profile_id": "rapier_force_based_velocity_residual_v1",
            "motor_damping_nm_s_per_rad":
                RAPIER_BW19V_MOTOR_DAMPING_NM_S_PER_RAD,
            "canonical_to_host_velocity_sign":
                RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN,
            "maximum_absolute_position_delta_rad":
                RAPIER_BW19V_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
            "maximum_position_slew_per_step_rad":
                RAPIER_BW19V_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
            "maximum_absolute_velocity_delta_rad_s":
                RAPIER_BW19V_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
            "maximum_velocity_slew_per_step_rad_s":
                RAPIER_BW19V_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
            "requested_generalized_torque_is_not_a_measurement": true,
            "exact_realized_incremental_torque_claim": false,
        },
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
        "actuator_application_mismatch_count":
            actuator_application_mismatch_count,
        "motor_impulse_limit_violation_count":
            motor_impulse_limit_violation_count,
        "controller_semantic_step_count": controller_semantic_step_count,
        "validated_portable_command_count": validated_portable_command_count,
        "native_motor_application_count": native_motor_application_count,
        "initial_four_contact_stance": initial_four_contact_stance,
        "terminal_four_contact_recovery": terminal_four_contact_recovery,
        "zero_torso_ground_contact": torso_ground_contact_count == 0,
        "torso_ground_contact_step_count": torso_ground_contact_count,
        "composition": {
            "attempt_count": composition_attempt_count,
            "composition_error_count": composition_error_count,
            "composition_error_codes": composition_error_codes,
            "first_composition_error_semantic_step":
                first_composition_error_semantic_step,
            "first_composition_error_code": first_composition_error_code,
            "scheduled_plan_receipt_count": scheduled_plan_receipt_count,
            "stability_influence_receipt_count":
                stability_influence_receipt_count,
            "influence_output_count": influence_output_count,
            "mapping_receipt_count": mapping_receipt_count,
            "available_plan_count": available_plan_count,
            "observation_unavailable_plan_count":
                observation_unavailable_plan_count,
            "explicit_host_observation_unavailable_plan_count":
                explicit_host_observation_unavailable_plan_count,
            "observed_planning_unavailable_plan_count":
                observed_planning_unavailable_plan_count,
            "upstream_infeasible_plan_count":
                upstream_infeasible_plan_count,
            "fail_zero_receipt_count": fail_zero_receipt_count,
            "global_requested_correction_scale":
                BW19V_GLOBAL_REQUESTED_CORRECTION_SCALE,
            "global_scale_mismatch_count": global_scale_mismatch_count,
            "response_reconstruction_maximum_error_nm":
                response_reconstruction_maximum_error_nm,
            "host_response_conversion_failure_count":
                host_response_conversion_failure_count,
            "nonzero_raw_request_count": nonzero_raw_request_count,
            "nonzero_scaled_request_count": nonzero_scaled_request_count,
            "nonzero_applied_contribution_count":
                nonzero_applied_contribution_count,
            "nonzero_effective_host_application_count":
                nonzero_effective_host_application_count,
            "host_speed_saturation_count": host_speed_saturation_count,
            "inactive_contact_exact_zero_count":
                inactive_contact_exact_zero_count,
            "inactive_contact_zero_mismatch_count":
                inactive_contact_zero_mismatch_count,
            "motor_model_readback_mismatch_count":
                motor_model_readback_mismatch_count,
            "observation_unavailable_reason_mismatch_count":
                observation_unavailable_reason_mismatch_count,
            "observation_unavailable_base_command_mismatch_count":
                observation_unavailable_base_command_mismatch_count,
            "observation_unavailable_stability_zero_mismatch_count":
                observation_unavailable_stability_zero_mismatch_count,
            "observation_unavailable_base_command_application_count":
                observation_unavailable_base_command_application_count,
            "observation_unavailable_exact_zero_stability_output_count":
                observation_unavailable_exact_zero_stability_output_count,
            "first_composition_receipt_sha256":
                first_composition_receipt_sha256,
            "last_composition_receipt_sha256":
                last_composition_receipt_sha256,
        },
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
        "observability": {
            "post_settle": {
                "torso_position_m": {
                    "x": post_settle_position.x,
                    "y": post_settle_position.y,
                    "z": post_settle_position.z,
                },
                "torso_tilt_rad": post_settle_tilt_rad,
                "torso_height_m": post_settle_position.y,
                "torso_ground_contact": post_settle_torso_ground_contact,
                "ordered_joint_angles_rad":
                    Value::Object(post_settle_joint_angles),
            },
            "first_torso_ground_contact_semantic_step":
                first_torso_ground_contact_semantic_step,
            "actuators": Value::Object(actuator_observability),
            "contacts": Value::Object(contact_observability),
            "final_limb_memory": Value::Object(final_limb_memory),
        },
        "claim_boundary": claim_boundary(),
    });
    let mut failures = full_gate_failures_for_spec(&report, spec);
    if !controller_limit_respected {
        failures.push(format!(
            "{}_CONTROLLER_STEP_LIMIT_EXCEEDED",
            spec.failure_prefix
        ));
    }
    report["gate_failures"] = json!(failures);
    report["ok"] = json!(
        report["gate_failures"]
            .as_array()
            .is_some_and(Vec::is_empty)
    );
    report["rapier_bw19v_single_body_technical_commissioning_passed"] = report["ok"].clone();
    report["rapier_selected_policy_physical_c6"] = json!(false);
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn complete_zero_world_bw19v_gate_and_canaries_pass() {
        let report = run_bw19v_selected_policy_commissioning_preflight().unwrap();
        assert_eq!(report["ok"], true, "{report:#}");
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(
            report["complete_declared_horizon_steps"],
            COMPLETE_SYNTHETIC_HORIZON_STEPS
        );
        assert_eq!(report["complete_declared_horizon_passed"], true);
        assert_eq!(report["perfect_synthetic_whole_gate_passed"], true);
        assert_eq!(report["wrong_scale_canary_rejected"], true);
        assert_eq!(report["composition_count_canary_rejected"], true);
        assert_eq!(report["motor_model_canary_rejected"], true);
        assert_eq!(report["missing_nonzero_application_canary_rejected"], true);
        assert_eq!(report["physical_acceptance_authority"], false);
    }

    #[test]
    fn c2_sustained_zero_support_route_is_complete_and_recovers() {
        let report = run_bw19v_selected_policy_commissioning_c2_preflight().unwrap();
        assert_eq!(report["ok"], true, "{report:#}");
        assert_eq!(report["world_build_count"], 0);
        assert_eq!(
            report["synthetic_explicit_host_observation_unavailable_plan_count"],
            C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE - C2_ZERO_SUPPORT_START_STEP
        );
        assert_eq!(
            report["synthetic_explicit_host_unavailable_base_application_count"],
            (C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE - C2_ZERO_SUPPORT_START_STEP) * 8
        );
        assert_eq!(
            report["synthetic_explicit_host_unavailable_exact_zero_stability_output_count"],
            (C2_ZERO_SUPPORT_END_STEP_EXCLUSIVE - C2_ZERO_SUPPORT_START_STEP) * 8
        );
        assert_eq!(
            report["available_receipt_before_zero_support_segment"],
            true
        );
        assert_eq!(report["available_receipt_after_zero_support_segment"], true);
        assert_eq!(
            report["observation_unavailable_route_canary_rejected"],
            true
        );
        assert_eq!(report["physical_acceptance_authority"], false);
    }
}
