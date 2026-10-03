//! Exact-s169 native recovery collection and deterministic control planning.
//!
//! QSDK-R24D17 is a zero-world source-conformance boundary. This module
//! validates already-sampled native post-step observations, publishes the
//! prospective development threshold/cohort profile, and emits canonical
//! recovery targets. It owns no host object, constructs no model or world,
//! takes no solver step, and cannot establish prone-to-standing.

use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::actuator_profile::{
    ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION, ActuatorCapProfileRequestV1,
    ActuatorCapProfileSupportStatusV1, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256, R23D60_SELECTED_S169_DESCRIPTOR_SHA256,
    R23D60_SELECTED_S169_MORPHOLOGY_ID, R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256,
    resolve_actuator_cap_profile_v1,
};
#[cfg(test)]
use crate::canonical::project_binary64_to_canonical_number_v1;
use crate::canonical::{
    digest_json, digest_serializable, project_binary64_to_guarded_canonical_number_v1,
};
use crate::protocol::{ContactQuality, JointObservation, Quaternion};
use crate::quadruped::BoundedQuadrupedDescriptor;
#[cfg(test)]
use crate::quadruped::compile_bounded_quadruped;
use crate::recovery::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, PORTABLE_RECOVERY_SEMANTICS_ID,
    RECOVERY_DEVELOPMENT_PROGRESSION_RECEIPT_V1_VERSION, RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION,
    RECOVERY_OBSERVATION_V2_VERSION, RECOVERY_OBSERVATION_V3_VERSION,
    RECOVERY_OUTER_STEP_DURATION_S, RECOVERY_STEP_RECEIPT_V1_VERSION, RecoveryAdapterCapabilityV1,
    RecoveryArmKindV1, RecoveryControllerOwnerV1, RecoveryDevelopmentProgressionReceiptV1,
    RecoveryEnergyPartitionAuthorityV1, RecoveryInitializeRequestV1, RecoveryInitializeRequestV2,
    RecoveryMorphologyContextV1, RecoveryNativeEngineV1, RecoveryObservationLike,
    RecoveryObservationSourceKindV1, RecoveryObservationV1, RecoveryObservationV2,
    RecoveryObservationV3, RecoveryPhaseV1, RecoveryStepReceiptV1, RecoverySupportStatusV1,
    ResolvedRecoveryMorphology, initialize_recovery_v1, initialize_recovery_v2,
    recovery_observation_base_sha256, resolve_recovery_morphology_context,
    validate_body_clearance_observation_v1, validate_recovery_energy_partition_authority_v1,
};
use crate::schema::{ActuatorMode, CoreError, Result};

#[cfg(test)]
use crate::recovery::RECOVERY_OBSERVATION_V1_VERSION;

pub const RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION: &str =
    "sporespore_recovery_native_collector_binding_v1";
pub const RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION: &str =
    "sporespore_recovery_native_collection_request_v1";
pub const RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_native_collection_request_v2";
pub const RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION: &str =
    "sporespore_recovery_native_collection_request_v3";
pub const RECOVERY_NATIVE_COLLECTION_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_native_collection_receipt_v1";
pub const RECOVERY_NATIVE_COLLECTION_RECEIPT_V2_VERSION: &str =
    "sporespore_recovery_native_collection_receipt_v2";
pub const RECOVERY_OBSERVATION_V2_SOURCE_BINDING_V1_VERSION: &str =
    "sporespore_recovery_observation_v2_source_binding_v1";
pub const RECOVERY_DEVELOPMENT_PROFILE_V1_VERSION: &str =
    "sporespore_recovery_development_profile_v1";
pub const RECOVERY_CONTROL_REQUEST_V1_VERSION: &str = "sporespore_recovery_control_request_v1";
pub const RECOVERY_CONTROL_REQUEST_V2_VERSION: &str = "sporespore_recovery_control_request_v2";
pub const RECOVERY_CONTROL_REQUEST_V3_VERSION: &str = "sporespore_recovery_control_request_v3";
pub const RECOVERY_CONTROL_RECEIPT_V1_VERSION: &str = "sporespore_recovery_control_receipt_v1";
pub const RECOVERY_CONTROL_COMMAND_V1_VERSION: &str = "sporespore_recovery_control_command_v1";
pub const RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION: &str =
    "sporespore_recovery_stance_control_request_v1";
pub const RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_stance_control_request_v2";
pub const RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION: &str =
    "sporespore_recovery_stance_control_request_v3";
pub const RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION: &str =
    "sporespore_recovery_stance_control_request_v4";
pub const RECOVERY_STANCE_OBSERVATION_BINDING_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_stance_observation_binding_receipt_v1";
pub const RECOVERY_STANCE_CONTROL_RECEIPT_V2_VERSION: &str =
    "sporespore_recovery_stance_control_receipt_v2";
pub const RECOVERY_STANCE_CONTROLLER_PROFILE_V1_VERSION: &str =
    "sporespore_recovery_stance_controller_profile_v1";

pub const EXACT_S169_RECOVERY_CONTROLLER_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v1";
pub const EXACT_S169_RECOVERY_CONTROLLER_V2_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v2";
pub const EXACT_S169_RECOVERY_CONTROLLER_V3_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v3";
pub const EXACT_S169_RECOVERY_CONTROLLER_V4_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v4";
pub const EXACT_S169_RECOVERY_CONTROLLER_V5_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v5";
pub const EXACT_S169_RECOVERY_CONTROLLER_V6_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v6";
pub const EXACT_S169_RECOVERY_CONTROLLER_V7_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v7";
pub const EXACT_S169_RECOVERY_CONTROLLER_V8_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v8";
pub const EXACT_S169_RECOVERY_CONTROLLER_V9_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v9";
pub const EXACT_S169_RECOVERY_CONTROLLER_V10_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v10";
pub const EXACT_S169_RECOVERY_CONTROLLER_V11_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v11";
pub const EXACT_S169_RECOVERY_CONTROLLER_V12_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v12";
pub const EXACT_S169_RECOVERY_CONTROLLER_V13_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v13";
pub const EXACT_S169_RECOVERY_CONTROLLER_V14_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v14";
pub const EXACT_S169_RECOVERY_CONTROLLER_V15_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v15";
pub const EXACT_S169_RECOVERY_CONTROLLER_V16_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v16";
pub const EXACT_S169_RECOVERY_CONTROLLER_V17_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v17";
pub const EXACT_S169_RECOVERY_CONTROLLER_V18_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v18";
pub const EXACT_S169_RECOVERY_CONTROLLER_V19_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v19";
pub const EXACT_S169_RECOVERY_CONTROLLER_V20_ID: &str =
    "sporespore_exact_s169_prone_to_standing_controller_v20";
pub const EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID: &str =
    "sporespore_exact_s169_partial_direct_neutral_controller_v21";
pub const EXACT_S169_PARTIAL_POSE_GEOMETRY_CONTROLLER_V22_ID: &str =
    "sporespore_exact_s169_partial_pose_geometry_controller_v22";
pub const EXACT_S169_PARTIAL_LOAD_SEEKING_CONTROLLER_V23_ID: &str =
    "sporespore_exact_s169_partial_load_seeking_controller_v23";
pub const EXACT_S169_PARTIAL_DOWNWARD_RISE_CONTROLLER_V24_ID: &str =
    "sporespore_exact_s169_partial_downward_rise_controller_v24";
pub const EXACT_S169_PARTIAL_CONCURRENT_LOAD_RISE_CONTROLLER_V25_ID: &str =
    "sporespore_exact_s169_partial_concurrent_load_rise_controller_v25";
pub const EXACT_S169_PARTIAL_HIP_RECENTER_CONTROLLER_V26_ID: &str =
    "sporespore_exact_s169_partial_hip_recenter_controller_v26";
pub const EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID: &str =
    "sporespore_exact_s169_partial_support_anchored_controller_v27";
pub const EXACT_S169_PARTIAL_PROGRESSIVE_HEADROOM_CONTROLLER_V28_ID: &str =
    "sporespore_exact_s169_partial_progressive_headroom_controller_v28";
pub const EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID: &str =
    "sporespore_exact_s169_partial_native_reference_controller_v29";
pub const EXACT_S169_STANCE_CONTROLLER_ID: &str =
    "sporespore_exact_s169_stance_handoff_controller_v1";

fn candidate_stance_contract() -> &'static serde_json::Value {
    static VALUE: std::sync::OnceLock<serde_json::Value> = std::sync::OnceLock::new();
    VALUE.get_or_init(|| {
        let mut base: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v1.json"))
            .expect("compile-time candidate stance contract");
        let successor: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v2.json"))
            .expect("compile-time successor stance contract");
        base["profiles"].as_array_mut().unwrap().extend(successor["profiles"].as_array().unwrap().iter().cloned());
        let damped: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v3.json"))
            .expect("compile-time damped stance contract");
        base["profiles"].as_array_mut().unwrap().extend(damped["profiles"].as_array().unwrap().iter().cloned());
        let ground_aligned: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v4.json"))
            .expect("compile-time ground-aligned candidate stance mapping");
        base["profiles"].as_array_mut().unwrap().extend(ground_aligned["profiles"].as_array().unwrap().iter().cloned());
        let neutral: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v5.json"))
            .expect("compile-time damped neutral candidate stance mapping");
        base["profiles"].as_array_mut().unwrap().extend(neutral["profiles"].as_array().unwrap().iter().cloned());
        let ramped: serde_json::Value = serde_json::from_str(include_str!("../contracts/recovery_candidate_stance_profiles_v6.json"))
            .expect("compile-time ramped neutral stance mapping");
        base["profiles"].as_array_mut().unwrap().extend(ramped["profiles"].as_array().unwrap().iter().cloned());
        base
    })
}

fn candidate_stance_profile(id: &str) -> Option<&'static serde_json::Value> {
    candidate_stance_contract()["profiles"].as_array().unwrap().iter()
        .find(|profile| profile["controller_id"].as_str() == Some(id))
}

fn stance_id_for_recovery(id: &str) -> &'static str {
    // R10Y composes its new partial support/rise law with the unchanged V7
    // stance law. Keep the historical embedded stance contract byte-identical.
    if matches!(id, EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID | EXACT_S169_PARTIAL_POSE_GEOMETRY_CONTROLLER_V22_ID | EXACT_S169_PARTIAL_LOAD_SEEKING_CONTROLLER_V23_ID | EXACT_S169_PARTIAL_DOWNWARD_RISE_CONTROLLER_V24_ID | EXACT_S169_PARTIAL_CONCURRENT_LOAD_RISE_CONTROLLER_V25_ID | EXACT_S169_PARTIAL_HIP_RECENTER_CONTROLLER_V26_ID | EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID | EXACT_S169_PARTIAL_PROGRESSIVE_HEADROOM_CONTROLLER_V28_ID | EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID) {
        return stance_id_for_recovery(EXACT_S169_RECOVERY_CONTROLLER_V20_ID);
    }
    candidate_stance_contract()["profiles"].as_array().unwrap().iter()
        .find(|profile| profile["recovery_controller_id"].as_str() == Some(id))
        .map(|profile| profile["controller_id"].as_str().unwrap())
        .unwrap_or(EXACT_S169_STANCE_CONTROLLER_ID)
}

fn candidate_stance_goal_positions(profile: &serde_json::Value, descriptor: &BoundedQuadrupedDescriptor) -> Result<[f64; 8]> {
    let Some(rule) = profile.get("geometry_rule_id") else { return Ok(STANCE_TARGETS_RAD); };
    if rule.as_str() != Some("two_link_sagittal_endpoint_under_hip_v1") {
        return Err(CoreError::Schema("STANCE_GEOMETRY_RULE".to_owned()));
    }
    let knee = profile["target_knee_angle_rad"].as_f64()
        .ok_or_else(|| CoreError::Schema("STANCE_KNEE_GOAL".to_owned()))?;
    let upper = descriptor.upper_length_fraction;
    if !knee.is_finite() || !(-1.10..0.0).contains(&knee) || !upper.is_finite() || upper <= 0.0 || upper >= 1.0 {
        return Err(CoreError::Schema("STANCE_GEOMETRY_DOMAIN".to_owned()));
    }
    // Rotate the combined link vector back under the hip; absolute length
    // cancels. This is a target geometry, never a reconstructed observation.
    let lower = 1.0 - upper;
    let hip = -(lower * knee.sin()).atan2(upper + lower * knee.cos());
    Ok([hip, knee, hip, knee, hip, knee, hip, knee])
}

fn candidate_stance_velocity_damping(profile: &serde_json::Value) -> Result<Option<f64>> {
    profile.get("measured_velocity_damping_gain").map(|value| {
        value.as_f64().filter(|gain| gain.is_finite() && (0.0..1.0).contains(gain))
            .ok_or_else(|| CoreError::Schema("STANCE_VELOCITY_DAMPING_GAIN".to_owned()))
    }).transpose()
}

fn candidate_stance_goals_for_control_step(
    profile: &serde_json::Value, descriptor: &BoundedQuadrupedDescriptor,
    next_phase: RecoveryPhaseV1, completed_phase_steps: u32,
) -> Result<[f64; 8]> {
    let terminal = candidate_stance_goal_positions(profile, descriptor)?;
    let Some(ramp) = profile.get("reference_ramp") else { return Ok(terminal); };
    if ramp["rule_id"].as_str() != Some("flexed_to_neutral_joint_reference_smoothstep_v1")
        || ramp["initial_stance_controller_id"].as_str() != Some("sporespore_exact_s169_stance_handoff_controller_v5")
        || ramp["duration_steps"].as_u64() != Some(60)
        || terminal != STANCE_TARGETS_RAD
    {
        return Err(CoreError::Schema("STANCE_REFERENCE_RAMP_SELECTION".to_owned()));
    }
    let initial_profile = candidate_stance_profile("sporespore_exact_s169_stance_handoff_controller_v5")
        .ok_or_else(|| CoreError::Schema("STANCE_REFERENCE_RAMP_ORIGIN".to_owned()))?;
    let initial = candidate_stance_goal_positions(initial_profile, descriptor)?;
    // The receipt's counter describes completed steps. The command applies to
    // the upcoming dwell step, so command 60 is neutral before the earliest
    // possible completion of the unchanged consecutive-60 standing gate.
    let clock = match next_phase {
        RecoveryPhaseV1::StanceHandoff => 0,
        RecoveryPhaseV1::StanceDwell => completed_phase_steps.saturating_add(1),
        _ => return Err(CoreError::Schema("STANCE_REFERENCE_RAMP_PHASE".to_owned())),
    };
    if clock == 0 { return Ok(initial); }
    if clock >= 60 { return Ok(terminal); }
    let t = f64::from(clock) / 60.0;
    let blend = t * t * (3.0 - 2.0 * t);
    Ok(std::array::from_fn(|i| initial[i] * (1.0 - blend) + terminal[i] * blend))
}

fn validate_stance_selection<O: RecoveryObservationLike>(id: &str, observation: &O) -> Result<()> {
    let ownership = observation.view().controller_ownership;
    let expected = match ownership.owner {
        RecoveryControllerOwnerV1::Recovery => stance_id_for_recovery(ownership.recovery_controller_id.as_deref().unwrap_or("")),
        RecoveryControllerOwnerV1::Stance => ownership.stance_controller_id.as_deref().unwrap_or(""),
        RecoveryControllerOwnerV1::None => "",
    };
    if id != expected && (candidate_stance_profile(id).is_some() || candidate_stance_profile(expected).is_some()) {
        return Err(CoreError::Schema("STANCE_CONTROLLER_SELECTION".to_owned()));
    }
    Ok(())
}
pub const EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID: &str =
    "sporespore_exact_s169_recovery_development_thresholds_v1";
pub const EXACT_S169_DEVELOPMENT_COHORT_ID: &str =
    "sporespore_exact_s169_recovery_repeatable_development_cohort_v1";
pub const EXACT_S169_HELD_OUT_COHORT_ID: &str =
    "sporespore_exact_s169_recovery_native_held_out_cohort_v1";

pub const GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID: &str =
    "godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3";
pub const GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID: &str =
    "godot_4_7_jolt_sporespore_motor_solved_contact_and_solver_energy_telemetry_v4";
pub const GODOT_ROTATION_AWARE_COMPLETE_ENERGY_RUNTIME_PROFILE_ID: &str =
    "godot_4_7_jolt_sporespore_motor_solved_contact_and_solver_energy_telemetry_v6";
pub const RAPIER_NATIVE_RUNTIME_PROFILE_ID: &str = "rapier3d_0_34_parry3d_0_29_native_recovery_v1";
pub const MUJOCO_NATIVE_RUNTIME_PROFILE_ID: &str = "mujoco_3_11_native_recovery_v1";

const GODOT_COLLECTOR_ID: &str =
    "sporespore_godot_jolt_motor_and_solved_contact_v3_recovery_collector_v1";
pub const GODOT_COMPLETE_ENERGY_COLLECTOR_ID: &str =
    "sporespore_godot_jolt_complete_energy_v4_recovery_collector_v1";
pub const GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID: &str =
    "sporespore_godot_jolt_solver_coupled_complete_energy_v4_recovery_collector_v1";
pub const GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID: &str =
    "sporespore_godot_jolt_discrete_staging_complete_energy_v4_recovery_collector_v1";
pub const GODOT_ROTATION_AWARE_COMPLETE_ENERGY_COLLECTOR_ID: &str =
    "sporespore_godot_jolt_rotation_aware_complete_energy_v6_recovery_collector_v1";
const RAPIER_COLLECTOR_ID: &str = "sporespore_rapier_parry_recovery_collector_v1";
const MUJOCO_COLLECTOR_ID: &str = "sporespore_mujoco_recovery_collector_v1";
const GODOT_ADAPTER_ID: &str = "sporespore_godot_jolt_adapter";
const RAPIER_ADAPTER_ID: &str = "sporespore_rapier3d_adapter";
const MUJOCO_ADAPTER_ID: &str = "sporespore_mujoco_adapter";
pub const GODOT_R24D57_RECOVERY_ROUTE_ID: &str =
    "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1";
pub const GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID: &str =
    "godot_jolt_r24d57_native_recovery_energy_mapping_v1";
pub const GODOT_R24D136_RECOVERY_ROUTE_ID: &str =
    "sporespore_qsdk_r24d136_godot_jolt_complete_energy_recovery_observation_v3_route_v1";
pub const GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID: &str =
    "godot_jolt_r24d136_complete_native_recovery_energy_mapping_v1";
pub const GODOT_R24D144_RECOVERY_ROUTE_ID: &str = "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1";
pub const GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID: &str =
    "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1";
pub const GODOT_R24D148_RECOVERY_ROUTE_ID: &str = "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1";
pub const GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID: &str =
    "godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1";
pub const MUJOCO_R24D36_SIGNED_WORK_ROUTE_ID: &str =
    "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3";
pub const MUJOCO_R24D38_ENERGY_V2_MAPPING_PROFILE_ID: &str =
    "mujoco_r24d36_native_components_to_recovery_energy_v2_v1";
pub const MUJOCO_R24D42_STREAMING_ENERGY_V2_MAPPING_PROFILE_ID: &str =
    "mujoco_r24d36_native_components_to_recovery_energy_v2_streaming_v1";
pub const RAPIER_R24D48_RECOVERY_ROUTE_ID: &str =
    "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1";
pub const RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID: &str =
    "rapier_r24d47_native_components_to_recovery_energy_v2_v1";

const ORDERED_ACTUATOR_IDS: [&str; 8] = [
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
];

const ORDERED_JOINT_IDS: [&str; 8] = [
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
];

const ESTABLISH_DISTAL_SUPPORT_TARGETS_RAD: [f64; 8] =
    [0.60, 1.05, 0.60, 1.05, -0.60, 1.05, -0.60, 1.05];
const ESTABLISH_DISTAL_SUPPORT_TARGETS_V2_RAD: [f64; 8] =
    [0.60, -1.05, 0.60, -1.05, -0.60, 1.05, -0.60, 1.05];
const STANCE_TARGETS_RAD: [f64; 8] = [0.0; 8];
const RAISE_BODY_RAMP_STEPS: u32 = 360;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectorBindingV1 {
    pub schema_version: String,
    pub collector_id: String,
    pub runtime_profile_id: String,
    pub runtime_qualification_sha256: String,
    pub capability_sha256: String,
    pub exact_runtime_identity_qualified: bool,
    pub native_post_step_only: bool,
    pub source_measurement_only: bool,
    pub missing_value_synthesis_permitted: bool,
    pub engine_identity_exposed_to_controller: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectionRequestV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub runtime_binding: RecoveryNativeCollectorBindingV1,
    pub arm_kind: RecoveryArmKindV1,
    pub phase: RecoveryPhaseV1,
    pub observation: RecoveryObservationV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectionRequestV2 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub runtime_binding: RecoveryNativeCollectorBindingV1,
    pub arm_kind: RecoveryArmKindV1,
    pub phase: RecoveryPhaseV1,
    pub observation: RecoveryObservationV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryObservationV2SourceBindingV1 {
    pub schema_version: String,
    pub producer_adapter_id: String,
    pub source_route_id: String,
    pub mapping_profile_id: String,
    pub mapping_receipt_sha256: String,
    pub source_component_receipts_sha256: String,
    pub observation_base_sha256: String,
    pub ledger_sha256: String,
    pub portable_observation_sha256: String,
    pub source_chain_sha256: String,
}

impl RecoveryObservationV2SourceBindingV1 {
    fn source_chain_sha256(&self) -> Result<String> {
        digest_json(&json!({
            "schema_version": self.schema_version,
            "producer_adapter_id": self.producer_adapter_id,
            "source_route_id": self.source_route_id,
            "mapping_profile_id": self.mapping_profile_id,
            "mapping_receipt_sha256": self.mapping_receipt_sha256,
            "source_component_receipts_sha256": self.source_component_receipts_sha256,
            "observation_base_sha256": self.observation_base_sha256,
            "ledger_sha256": self.ledger_sha256,
            "portable_observation_sha256": self.portable_observation_sha256,
        }))
    }
}

/// Construct the content-addressed source chain for one already assembled
/// observation V2. This helper assigns no engine support on its own; the V3
/// collector separately checks the exact qualified adapter, route, and mapping
/// tuple before accepting the observation.
pub fn bind_recovery_observation_v2_source_v1(
    observation: &RecoveryObservationV2,
    producer_adapter_id: &str,
    source_route_id: &str,
    mapping_profile_id: &str,
    mapping_receipt_sha256: &str,
    source_component_receipts_sha256: &str,
) -> Result<RecoveryObservationV2SourceBindingV1> {
    if observation.schema_version != RECOVERY_OBSERVATION_V2_VERSION
        || producer_adapter_id.is_empty()
        || source_route_id.is_empty()
        || mapping_profile_id.is_empty()
        || observation.energy_balance.source_profile_id != mapping_profile_id
    {
        return Err(CoreError::Schema(
            "recovery_observation_v2_source_binding_identity".to_owned(),
        ));
    }
    if !valid_digest(mapping_receipt_sha256) || !valid_digest(source_component_receipts_sha256) {
        return Err(CoreError::Digest(
            "recovery_observation_v2_source_binding_input".to_owned(),
        ));
    }
    let mut source = RecoveryObservationV2SourceBindingV1 {
        schema_version: RECOVERY_OBSERVATION_V2_SOURCE_BINDING_V1_VERSION.to_owned(),
        producer_adapter_id: producer_adapter_id.to_owned(),
        source_route_id: source_route_id.to_owned(),
        mapping_profile_id: mapping_profile_id.to_owned(),
        mapping_receipt_sha256: mapping_receipt_sha256.to_owned(),
        source_component_receipts_sha256: source_component_receipts_sha256.to_owned(),
        observation_base_sha256: recovery_observation_base_sha256(observation)?,
        ledger_sha256: digest_serializable(&observation.energy_balance)?,
        portable_observation_sha256: digest_serializable(observation)?,
        source_chain_sha256: mapping_receipt_sha256.to_owned(),
    };
    source.source_chain_sha256 = source.source_chain_sha256()?;
    Ok(source)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectionRequestV3 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub runtime_binding: RecoveryNativeCollectorBindingV1,
    pub arm_kind: RecoveryArmKindV1,
    pub phase: RecoveryPhaseV1,
    pub observation_source_binding: RecoveryObservationV2SourceBindingV1,
    pub observation: RecoveryObservationV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectionReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub collector_id: String,
    pub adapter_id: String,
    pub engine: RecoveryNativeEngineV1,
    pub runtime_profile_id: String,
    pub capability_sha256: String,
    pub observation_sha256: Option<String>,
    pub observation: Option<RecoveryObservationV1>,
    pub native_observation_validation_kernel_implemented: bool,
    pub native_adapter_collection_surface_implemented: bool,
    pub supplied_native_post_step_observation_validated: bool,
    pub native_runtime_observation_collection_executed: bool,
    pub engine_identity_exposed_to_controller: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryNativeCollectionReceiptV2 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub collector_id: String,
    pub adapter_id: String,
    pub engine: RecoveryNativeEngineV1,
    pub runtime_profile_id: String,
    pub capability_sha256: String,
    pub observation_source_binding_sha256: Option<String>,
    pub observation_source_binding: Option<RecoveryObservationV2SourceBindingV1>,
    pub observation_sha256: Option<String>,
    pub observation: Option<RecoveryObservationV2>,
    pub native_observation_validation_kernel_implemented: bool,
    pub native_adapter_collection_surface_implemented: bool,
    pub supplied_native_post_step_observation_validated: bool,
    pub native_runtime_observation_collection_executed: bool,
    pub engine_identity_exposed_to_controller: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPhysicalThresholdsV1 {
    pub entry_prone_height_ratio_max: f64,
    pub entry_torso_up_dot_max: f64,
    pub entry_prone_confirm_steps: u32,
    pub distal_bearing_minimum_impulse_ns: f64,
    pub minimum_com_height_gain_m: f64,
    pub stance_height_ratio_min: f64,
    pub stance_torso_up_dot_min: f64,
    pub minimum_nonfoot_clearance_m: f64,
    pub maximum_forbidden_contact_impulse_ns: f64,
    pub maximum_terminal_linear_speed_m_s: f64,
    pub maximum_terminal_angular_speed_rad_s: f64,
    pub stance_dwell_steps: u32,
    pub confirm_prone_timeout_steps: u32,
    pub establish_distal_support_timeout_steps: u32,
    pub raise_body_timeout_steps: u32,
    pub stance_handoff_timeout_steps: u32,
    pub stance_dwell_timeout_steps: u32,
    pub total_timeout_steps: u32,
    pub maximum_energy_balance_residual_j: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryCohortCellV1 {
    pub cell_id: String,
    pub engine: Option<RecoveryNativeEngineV1>,
    pub seed: u32,
    pub seed_derivation_label: String,
    pub seed_derivation_sha256: String,
    pub initial_state_id: String,
    pub torso_roll_rad: f64,
    pub candidate_and_matched_zero_required: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControllerPoseV1 {
    pub pose_id: String,
    pub ordered_actuator_ids: Vec<String>,
    pub ordered_joint_ids: Vec<String>,
    pub ordered_target_positions_rad: Vec<f64>,
    pub maximum_target_speed_rad_s: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryDevelopmentProfileV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub task_id: String,
    pub semantics_id: String,
    pub morphology_id: String,
    pub descriptor_sha256: String,
    pub morphology_spec_sha256: String,
    pub actuator_profile_id: String,
    pub actuator_profile_sha256: String,
    pub controller_id: String,
    pub threshold_profile_id: String,
    pub threshold_selection_basis_id: String,
    pub thresholds: RecoveryPhysicalThresholdsV1,
    pub initial_state_match_rule: String,
    pub establish_distal_support_pose: RecoveryControllerPoseV1,
    pub stance_pose: RecoveryControllerPoseV1,
    pub raise_body_ramp_steps: u32,
    pub development_cohort_id: String,
    pub development_cohort: Vec<RecoveryCohortCellV1>,
    pub held_out_cohort_id: String,
    pub held_out_native_cohort: Vec<RecoveryCohortCellV1>,
    pub development_question_class: String,
    pub held_out_question_class: String,
    pub held_out_seed_use_during_development_permitted: bool,
    pub matched_zero_command_required: bool,
    pub thresholds_frozen_before_physical_outcome: bool,
    pub post_outcome_rethresholding_permitted: bool,
    pub arbitrary_morphology_claim: bool,
    pub repeatability_rate_claim: bool,
    pub population_claim: bool,
    pub cross_engine_equivalence_claim: bool,
    pub physical_execution_authorized: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControlRequestV1 {
    pub schema_version: String,
    pub controller_id: String,
    pub phase_step: u32,
    pub collection: RecoveryNativeCollectionRequestV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControlRequestV2 {
    pub schema_version: String,
    pub controller_id: String,
    pub phase_step: u32,
    pub collection: RecoveryNativeCollectionRequestV2,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControlRequestV3 {
    pub schema_version: String,
    pub controller_id: String,
    pub phase_step: u32,
    pub collection: RecoveryNativeCollectionRequestV3,
}

/// Compose a stance-owned command from an accepted observation-V1 collection
/// and the portable supervisor receipt that transferred ownership.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceControlRequestV1 {
    pub schema_version: String,
    pub controller_id: String,
    pub collection: RecoveryNativeCollectionRequestV1,
    pub handoff_or_stance_step: RecoveryStepReceiptV1,
}

/// Morphology-aware stance composition over an observation-V1 collection.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceControlRequestV2 {
    pub schema_version: String,
    pub controller_id: String,
    pub collection: RecoveryNativeCollectionRequestV2,
    pub handoff_or_stance_step: RecoveryStepReceiptV1,
}

/// Stance composition over a source-bound observation-V2 collection.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceControlRequestV3 {
    pub schema_version: String,
    pub controller_id: String,
    pub collection: RecoveryNativeCollectionRequestV3,
    pub handoff_or_stance_step: RecoveryStepReceiptV1,
}

/// Additive source-projection handoff for an observation-V3 portable step and
/// its source-bound observation-V2 stance-control projection. Both full
/// representations remain distinct; their shared non-energy sample must bind.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceControlRequestV4 {
    pub schema_version: String,
    pub controller_id: String,
    pub collection: RecoveryNativeCollectionRequestV3,
    pub handoff_or_stance_step: RecoveryStepReceiptV1,
    pub portable_step_observation_v3: RecoveryObservationV3,
    pub energy_partition_authority: RecoveryEnergyPartitionAuthorityV1,
    pub development_progression: RecoveryDevelopmentProgressionReceiptV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControlCommandV1 {
    pub schema_version: String,
    pub actuator_id: String,
    pub joint_id: String,
    pub mode: ActuatorMode,
    pub target_position_rad: f64,
    pub target_velocity_rad_s: f64,
    pub maximum_target_speed_rad_s: f64,
    pub maximum_outer_step_impulse_nms: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControlReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub controller_id: String,
    pub controller_profile_sha256: String,
    pub observation_sha256: Option<String>,
    pub semantic_step: u64,
    pub phase: RecoveryPhaseV1,
    pub phase_step: u32,
    pub owner: RecoveryControllerOwnerV1,
    pub recovery_controller_active: bool,
    pub stance_handoff_requested: bool,
    pub matched_zero_command: bool,
    pub no_actuation_requested: bool,
    pub ordered_commands: Vec<RecoveryControlCommandV1>,
    pub command_sha256: Option<String>,
    pub controller_implemented: bool,
    pub deterministic: bool,
    pub engine_identity_input_count: u32,
    pub engine_specific_policy_branch_count: u32,
    pub fallback_controller_active: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceObservationBindingReceiptV1 {
    pub schema_version: String,
    pub collection_observation_v2_sha256: String,
    pub portable_step_observation_v3_sha256: String,
    pub shared_observation_base_sha256: String,
    pub observation_source_binding_sha256: String,
    pub energy_partition_authority_sha256: String,
    pub development_progression_receipt_sha256: String,
    pub semantic_step: u64,
    pub source_bound_v2_collection_validated: bool,
    pub portable_step_v3_validated: bool,
    pub cross_representation_base_binding_validated: bool,
    pub development_progression_validated: bool,
    pub development_handoff_authorized: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStanceControlReceiptV2 {
    pub schema_version: String,
    pub control_receipt: RecoveryControlReceiptV1,
    pub observation_binding: RecoveryStanceObservationBindingReceiptV1,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

fn cohort_cell(
    cell_id: &str,
    engine: Option<RecoveryNativeEngineV1>,
    seed: u32,
    label: &str,
    sha256: &str,
    initial_state_id: &str,
    torso_roll_rad: f64,
) -> RecoveryCohortCellV1 {
    RecoveryCohortCellV1 {
        cell_id: cell_id.to_owned(),
        engine,
        seed,
        seed_derivation_label: label.to_owned(),
        seed_derivation_sha256: format!("sha256:{sha256}"),
        initial_state_id: initial_state_id.to_owned(),
        torso_roll_rad,
        candidate_and_matched_zero_required: true,
    }
}

pub fn recovery_development_profile_v1() -> RecoveryDevelopmentProfileV1 {
    let actuator_ids = ORDERED_ACTUATOR_IDS
        .iter()
        .map(|value| (*value).to_owned())
        .collect::<Vec<_>>();
    let joint_ids = ORDERED_JOINT_IDS
        .iter()
        .map(|value| (*value).to_owned())
        .collect::<Vec<_>>();
    RecoveryDevelopmentProfileV1 {
        schema_version: RECOVERY_DEVELOPMENT_PROFILE_V1_VERSION.to_owned(),
        profile_id: "sporespore_qsdk_r24d17_exact_s169_recovery_development_v1".to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        morphology_id: R23D60_SELECTED_S169_MORPHOLOGY_ID.to_owned(),
        descriptor_sha256: R23D60_SELECTED_S169_DESCRIPTOR_SHA256.to_owned(),
        morphology_spec_sha256: R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        actuator_profile_sha256: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned(),
        controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
        threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        threshold_selection_basis_id:
            "r24d17_exact_s169_geometry_weight_outer_step_and_product_stability_requirements_v1"
                .to_owned(),
        thresholds: RecoveryPhysicalThresholdsV1 {
            entry_prone_height_ratio_max: 0.25,
            entry_torso_up_dot_max: 1.0,
            entry_prone_confirm_steps: 12,
            distal_bearing_minimum_impulse_ns: 0.019293,
            minimum_com_height_gain_m: 0.22,
            stance_height_ratio_min: 0.75,
            stance_torso_up_dot_min: 0.95,
            minimum_nonfoot_clearance_m: 0.005,
            maximum_forbidden_contact_impulse_ns: 0.0,
            maximum_terminal_linear_speed_m_s: 0.10,
            maximum_terminal_angular_speed_rad_s: 0.20,
            stance_dwell_steps: 60,
            confirm_prone_timeout_steps: 60,
            establish_distal_support_timeout_steps: 240,
            raise_body_timeout_steps: 600,
            stance_handoff_timeout_steps: 120,
            stance_dwell_timeout_steps: 240,
            total_timeout_steps: 1200,
            maximum_energy_balance_residual_j: 0.25,
        },
        initial_state_match_rule:
            "exact_initializer_manifest_sha256_and_canonical_pre_step_state_sha256_equality_within_each_engine_pair"
                .to_owned(),
        establish_distal_support_pose: RecoveryControllerPoseV1 {
            pose_id: "exact_s169_distal_support_pose_v1".to_owned(),
            ordered_actuator_ids: actuator_ids.clone(),
            ordered_joint_ids: joint_ids.clone(),
            ordered_target_positions_rad: ESTABLISH_DISTAL_SUPPORT_TARGETS_RAD.to_vec(),
            maximum_target_speed_rad_s: 1.0,
        },
        stance_pose: RecoveryControllerPoseV1 {
            pose_id: "exact_s169_zero_joint_stance_pose_v1".to_owned(),
            ordered_actuator_ids: actuator_ids,
            ordered_joint_ids: joint_ids,
            ordered_target_positions_rad: STANCE_TARGETS_RAD.to_vec(),
            maximum_target_speed_rad_s: 0.75,
        },
        raise_body_ramp_steps: RAISE_BODY_RAMP_STEPS,
        development_cohort_id: EXACT_S169_DEVELOPMENT_COHORT_ID.to_owned(),
        development_cohort: vec![
            cohort_cell(
                "development_nominal",
                Some(RecoveryNativeEngineV1::MujocoNative),
                1_129_522_465,
                "QSDK-R24D17/development/nominal",
                "c35325212e3227572f07779f9c9e3e90e405183e3194b715f3929feb34d30dc5",
                "exact_s169_ventral_prone_nominal_v1",
                0.0,
            ),
            cohort_cell(
                "development_roll_positive",
                Some(RecoveryNativeEngineV1::MujocoNative),
                1_391_741_483,
                "QSDK-R24D17/development/roll-positive",
                "52f44a2b758c45fd74fc0c36f4ff33b7d794729ebca16b6a0fc305a812c23004",
                "exact_s169_ventral_prone_roll_positive_v1",
                0.035,
            ),
            cohort_cell(
                "development_roll_negative",
                Some(RecoveryNativeEngineV1::MujocoNative),
                622_413_176,
                "QSDK-R24D17/development/roll-negative",
                "2519457824c0fb094c3bcd6d7151211dca1034117e2edbbb447c192e6226b224",
                "exact_s169_ventral_prone_roll_negative_v1",
                -0.035,
            ),
        ],
        held_out_cohort_id: EXACT_S169_HELD_OUT_COHORT_ID.to_owned(),
        held_out_native_cohort: vec![
            cohort_cell(
                "heldout_godot_nominal",
                Some(RecoveryNativeEngineV1::GodotJolt4_7),
                1_358_036_517,
                "QSDK-R24D17/heldout/godot/nominal",
                "d0f1fe2504700e8a2ca1594e200d939e8e7110a1c7d6ce288530fd44a6dac699",
                "exact_s169_ventral_prone_nominal_v1",
                0.0,
            ),
            cohort_cell(
                "heldout_godot_roll_positive",
                Some(RecoveryNativeEngineV1::GodotJolt4_7),
                513_646_485,
                "QSDK-R24D17/heldout/godot/roll-positive",
                "1e9d9f95887cd18846193b941aa6a0d04f04404ceda854cb90db24526ebbd1b2",
                "exact_s169_ventral_prone_roll_positive_v1",
                0.035,
            ),
            cohort_cell(
                "heldout_godot_roll_negative",
                Some(RecoveryNativeEngineV1::GodotJolt4_7),
                2_066_397_479,
                "QSDK-R24D17/heldout/godot/roll-negative",
                "fb2ab9278888da462380dfbb56a54304fe91ff3644b93a201117270bdcdaf303",
                "exact_s169_ventral_prone_roll_negative_v1",
                -0.035,
            ),
            cohort_cell(
                "heldout_rapier_nominal",
                Some(RecoveryNativeEngineV1::RapierParryNative),
                2_003_727_451,
                "QSDK-R24D17/heldout/rapier/nominal",
                "f76e745b075bc6f936dab851d0cb07bf74ea7d271352e9b91be94d45d26bf008",
                "exact_s169_ventral_prone_nominal_v1",
                0.0,
            ),
            cohort_cell(
                "heldout_rapier_roll_positive",
                Some(RecoveryNativeEngineV1::RapierParryNative),
                1_386_094_307,
                "QSDK-R24D17/heldout/rapier/roll-positive",
                "529e1ee33b91cd43870ce978e976a6d25da3f134422c6dbd9c07c3de0ba8faf9",
                "exact_s169_ventral_prone_roll_positive_v1",
                0.035,
            ),
            cohort_cell(
                "heldout_rapier_roll_negative",
                Some(RecoveryNativeEngineV1::RapierParryNative),
                1_765_225_127,
                "QSDK-R24D17/heldout/rapier/roll-negative",
                "693732a77ee7cce9fafb0156c8a0df9012c0ab46c9d16998d4ab2cb2c83af8df",
                "exact_s169_ventral_prone_roll_negative_v1",
                -0.035,
            ),
            cohort_cell(
                "heldout_mujoco_nominal",
                Some(RecoveryNativeEngineV1::MujocoNative),
                948_793_232,
                "QSDK-R24D17/heldout/mujoco/nominal",
                "388d6f905dbb7c0ea5a19067fcecc530e1bbc6d13594cec15d97c216e1511150",
                "exact_s169_ventral_prone_nominal_v1",
                0.0,
            ),
            cohort_cell(
                "heldout_mujoco_roll_positive",
                Some(RecoveryNativeEngineV1::MujocoNative),
                817_960_042,
                "QSDK-R24D17/heldout/mujoco/roll-positive",
                "b0c1146ac50bc3083be3f11186b8d357192df31f82c96d674f1cdad8c15f9a7b",
                "exact_s169_ventral_prone_roll_positive_v1",
                0.035,
            ),
            cohort_cell(
                "heldout_mujoco_roll_negative",
                Some(RecoveryNativeEngineV1::MujocoNative),
                1_059_891_591,
                "QSDK-R24D17/heldout/mujoco/roll-negative",
                "3f2ca987d56c4ac623c86ad57a4511e0d34f1c374d4c2d89e1c20b5c8bbbf3c7",
                "exact_s169_ventral_prone_roll_negative_v1",
                -0.035,
            ),
        ],
        development_question_class: "repeatable_development".to_owned(),
        held_out_question_class: "finite_decision".to_owned(),
        held_out_seed_use_during_development_permitted: false,
        matched_zero_command_required: true,
        thresholds_frozen_before_physical_outcome: true,
        post_outcome_rethresholding_permitted: false,
        arbitrary_morphology_claim: false,
        repeatability_rate_claim: false,
        population_claim: false,
        cross_engine_equivalence_claim: false,
        physical_execution_authorized: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

/// R24D113's distinct controller identity preserves the complete historical
/// V1 profile and changes only the two front-knee distal-support targets.
/// The serialized schema remains V1 because the profile shape is unchanged;
/// the profile, controller, and support-pose identities carry the new version.
pub fn recovery_development_profile_v2() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v1();
    profile.profile_id = "sporespore_qsdk_r24d113_exact_s169_recovery_development_v2".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned();
    profile.establish_distal_support_pose.pose_id = "exact_s169_distal_support_pose_v2".to_owned();
    profile
        .establish_distal_support_pose
        .ordered_target_positions_rad = ESTABLISH_DISTAL_SUPPORT_TARGETS_V2_RAD.to_vec();
    profile
}

/// R24D117 preserves the complete V2 controller and support-pose geometry,
/// then changes only the distal-support target-speed ceiling selected by the
/// retained-state R24D116 development diagnosis. The serialized profile shape
/// remains V1; profile, controller, and support-pose identities carry V3.
pub fn recovery_development_profile_v3() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v2();
    profile.profile_id = "sporespore_qsdk_r24d117_exact_s169_recovery_development_v3".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned();
    profile.establish_distal_support_pose.pose_id = "exact_s169_distal_support_pose_v3".to_owned();
    profile
        .establish_distal_support_pose
        .maximum_target_speed_rad_s = 8.0;
    profile
}

/// R24D120 preserves the complete V3 controller, including its qualified
/// distal-support pose and speed, then continues that same 8 rad/s ceiling
/// across the raise-body phase boundary selected by the retained-state R24D119
/// development diagnosis. The serialized profile shape remains V1; profile,
/// controller, and zero-joint stance-pose identities carry V4.
pub fn recovery_development_profile_v4() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v3();
    profile.profile_id = "sporespore_qsdk_r24d120_exact_s169_recovery_development_v4".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned();
    profile.stance_pose.pose_id = "exact_s169_zero_joint_stance_pose_v2".to_owned();
    profile.stance_pose.maximum_target_speed_rad_s = 8.0;
    profile
}

/// R24D123 preserves the complete V4 controller, including its qualified
/// distal-support command and zero-joint raise-body target trajectory, then
/// changes only the raise-body speed ceiling selected by the immutable R24D122
/// retained-trace diagnosis. The serialized profile shape remains V1; profile,
/// controller, and zero-joint stance-pose identities carry V5.
pub fn recovery_development_profile_v5() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v4();
    profile.profile_id = "sporespore_qsdk_r24d123_exact_s169_recovery_development_v5".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned();
    profile.stance_pose.pose_id = "exact_s169_zero_joint_stance_pose_v3".to_owned();
    profile.stance_pose.maximum_target_speed_rad_s = 22.0;
    profile
}

/// R24D127 preserves the complete qualified V5 portable policy. The distinct
/// identity lets the Godot adapter bind that policy to its solver-coupled
/// native constraint-motor realization without changing targets, speeds,
/// caps, ramps, phase gates, thresholds, or evaluator semantics.
pub fn recovery_development_profile_v6() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v5();
    profile.profile_id = "sporespore_qsdk_r24d127_exact_s169_recovery_development_v6".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned();
    profile
}

/// Development-only fixed support pose for the retained rearward-folded entry.
/// This does not infer a pose from engine identity or replace V6. It mirrors
/// the two front legs' hip/knee targets, preserving every threshold, speed,
/// cap, ramp and other phase rule. Physical suitability remains unproved.
pub fn recovery_development_profile_v7() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v6();
    profile.profile_id = "sporespore_exact_s169_rearward_fold_recovery_development_v7".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V7_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_rearward_fold_distal_support_pose_v1".to_owned();
    for target in &mut profile.establish_distal_support_pose.ordered_target_positions_rad[..4] {
        *target = -*target;
    }
    profile
}

/// Development-only lower target-speed ceiling through support and rise.
/// V7's retained fall reaches support while rotating, then requests 8 -> 22
/// rad/s at the rise boundary. V8 tests a single 4 rad/s ceiling, not an
/// acceleration limiter or a bound on actual solver velocities. All poses,
/// caps, ramps, phase gates and acceptance requirements remain unchanged.
pub fn recovery_development_profile_v8() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v7();
    profile.profile_id = "sporespore_exact_s169_rate_limited_recovery_development_v8".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V8_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_rate_limited_rearward_fold_support_pose_v1".to_owned();
    profile.stance_pose.pose_id = "exact_s169_rate_limited_zero_joint_stance_pose_v1".to_owned();
    profile.establish_distal_support_pose.maximum_target_speed_rad_s = 4.0;
    profile.stance_pose.maximum_target_speed_rad_s = 4.0;
    profile
}

/// Development hypothesis: all support joints advance the same fraction of
/// their remaining position error, instead of independently saturating at
/// 4 rad/s. V8 destinations, caps, rise trajectory and phase gates are retained.
/// This coordinates requested motion, not actual contacts or solver response;
/// it is neither force-aware recovery nor evidence that get-up succeeds.
pub fn recovery_development_profile_v9() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v8();
    profile.profile_id = "sporespore_exact_s169_coordinated_support_development_v9".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V9_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_measured_coordinated_support_reference_v1".to_owned();
    profile
}

/// Development-only knee preparation before requesting hip lift. The existing
/// V9 support destination, speeds, caps, phase gates and later motion remain
/// unchanged. Readiness is an observation-dependent command rule, not a claim
/// that the feet are touching or bearing load and not a new acceptance gate.
pub fn recovery_development_profile_v10() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v9();
    profile.profile_id = "sporespore_exact_s169_knees_before_lift_development_v10".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V10_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_knees_before_hip_lift_reference_v1".to_owned();
    profile
}

/// Match lagging foot reach before extending the already more extended legs.
/// This is ideal body-relative link geometry, not measured ground clearance,
/// load feedback, or force-aware recovery. V9's final poses and gates stay fixed.
pub fn recovery_development_profile_v11() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v9();
    profile.profile_id = "sporespore_exact_s169_matched_foot_reach_development_v11".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V11_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_match_foot_reach_before_common_lift_v1".to_owned();
    profile
}

/// Continue from measured support entry, not the old fixed support pose. The
/// existing phase clock, final stance target, caps and phase gates are unchanged.
/// This is position feedback, not force-aware recovery or a success claim.
pub fn recovery_development_profile_v12() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v11();
    profile.profile_id = "sporespore_exact_s169_measured_pose_rise_development_v12".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V12_ID.to_owned();
    profile.stance_pose.pose_id = "exact_s169_measured_pose_smooth_rise_reference_v1".to_owned();
    profile
}

/// Development reference through the existing bent-leg support waypoint before
/// straightening. Split the unchanged clock equally between two measured-pose
/// smooth segments. A scheduled waypoint is not proof of reaching or loading it.
pub fn recovery_development_profile_v13() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v12();
    profile.profile_id = "sporespore_exact_s169_support_waypoint_rise_development_v13".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V13_ID.to_owned();
    profile.stance_pose.pose_id = "exact_s169_support_waypoint_measured_rise_reference_v1".to_owned();
    profile
}

/// Test a knee-supported replant route: fold distal links upward first, then
/// approach the mirrored support posture and straighten. All contacts remain
/// measured and the final nonfoot-clearance/standing rules remain unchanged.
pub fn recovery_development_profile_v14() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v13();
    profile.profile_id = "sporespore_exact_s169_knee_fold_replant_development_v14".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V14_ID.to_owned();
    profile.stance_pose.pose_id = "exact_s169_knee_fold_replant_rise_reference_v1".to_owned();
    profile
}

/// Preserve V14's fold/replant path; a separate stance identity owns settling.
pub fn recovery_development_profile_v15() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v14();
    profile.profile_id = "sporespore_exact_s169_smooth_stance_development_v15".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V15_ID.to_owned();
    profile
}

pub fn recovery_development_profile_v16() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v15();
    profile.profile_id = "sporespore_exact_s169_flexed_stance_development_v16".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V16_ID.to_owned();
    profile
}

pub fn recovery_development_profile_v17() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v16();
    profile.profile_id = "sporespore_exact_s169_velocity_damped_stance_development_v17".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V17_ID.to_owned();
    profile
}

/// V22 development candidate: match foot reach along world vertical, using
/// measured torso orientation and the production link/hip geometry. No force
/// channel, floor-height assumption, deadline or later-phase motion changes.
pub fn recovery_development_profile_v18() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v17();
    profile.profile_id = "sporespore_exact_s169_world_vertical_support_development_v18".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V18_ID.to_owned();
    profile.establish_distal_support_pose.pose_id =
        "exact_s169_match_world_vertical_foot_reach_v1".to_owned();
    profile
}

/// V25 candidate: only the separately owned stance goal changes. Keep all
/// support/rise commands and clocks exact; a neutral goal is not proof of load.
pub fn recovery_development_profile_v19() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v18();
    profile.profile_id = "sporespore_exact_s169_damped_walking_neutral_development_v19".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V19_ID.to_owned();
    profile
}

/// V27: change only the stance reference trajectory. No new phase, counter,
/// walking semantics, speed/impulse limit or completion predicate is introduced.
pub fn recovery_development_profile_v20() -> RecoveryDevelopmentProfileV1 {
    let mut profile = recovery_development_profile_v19();
    profile.profile_id = "sporespore_exact_s169_ramped_neutral_stance_development_v20".to_owned();
    profile.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V20_ID.to_owned();
    profile
}

fn registered_recovery_controller(controller_id: &str) -> bool {
    matches!(
        controller_id,
        EXACT_S169_RECOVERY_CONTROLLER_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V2_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V3_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V4_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V5_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V6_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V7_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V8_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V9_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V10_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V11_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V12_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V13_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V14_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V15_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V16_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V17_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V18_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V19_ID
            | EXACT_S169_RECOVERY_CONTROLLER_V20_ID
            | EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID
            | EXACT_S169_PARTIAL_POSE_GEOMETRY_CONTROLLER_V22_ID
            | EXACT_S169_PARTIAL_LOAD_SEEKING_CONTROLLER_V23_ID
            | EXACT_S169_PARTIAL_DOWNWARD_RISE_CONTROLLER_V24_ID | EXACT_S169_PARTIAL_CONCURRENT_LOAD_RISE_CONTROLLER_V25_ID | EXACT_S169_PARTIAL_HIP_RECENTER_CONTROLLER_V26_ID | EXACT_S169_PARTIAL_SUPPORT_ANCHORED_CONTROLLER_V27_ID | EXACT_S169_PARTIAL_PROGRESSIVE_HEADROOM_CONTROLLER_V28_ID | EXACT_S169_PARTIAL_NATIVE_REFERENCE_CONTROLLER_V29_ID
    )
}

fn recovery_development_profile_for_controller(
    controller_id: &str,
) -> Option<RecoveryDevelopmentProfileV1> {
    match controller_id {
        EXACT_S169_RECOVERY_CONTROLLER_ID => Some(recovery_development_profile_v1()),
        EXACT_S169_RECOVERY_CONTROLLER_V2_ID => Some(recovery_development_profile_v2()),
        EXACT_S169_RECOVERY_CONTROLLER_V3_ID => Some(recovery_development_profile_v3()),
        EXACT_S169_RECOVERY_CONTROLLER_V4_ID => Some(recovery_development_profile_v4()),
        EXACT_S169_RECOVERY_CONTROLLER_V5_ID => Some(recovery_development_profile_v5()),
        EXACT_S169_RECOVERY_CONTROLLER_V6_ID => Some(recovery_development_profile_v6()),
        EXACT_S169_RECOVERY_CONTROLLER_V7_ID => Some(recovery_development_profile_v7()),
        EXACT_S169_RECOVERY_CONTROLLER_V8_ID => Some(recovery_development_profile_v8()),
        EXACT_S169_RECOVERY_CONTROLLER_V9_ID => Some(recovery_development_profile_v9()),
        EXACT_S169_RECOVERY_CONTROLLER_V10_ID => Some(recovery_development_profile_v10()),
        EXACT_S169_RECOVERY_CONTROLLER_V11_ID => Some(recovery_development_profile_v11()),
        EXACT_S169_RECOVERY_CONTROLLER_V12_ID => Some(recovery_development_profile_v12()),
        EXACT_S169_RECOVERY_CONTROLLER_V13_ID => Some(recovery_development_profile_v13()),
        EXACT_S169_RECOVERY_CONTROLLER_V14_ID => Some(recovery_development_profile_v14()),
        EXACT_S169_RECOVERY_CONTROLLER_V15_ID => Some(recovery_development_profile_v15()),
        EXACT_S169_RECOVERY_CONTROLLER_V16_ID => Some(recovery_development_profile_v16()),
        EXACT_S169_RECOVERY_CONTROLLER_V17_ID => Some(recovery_development_profile_v17()),
        EXACT_S169_RECOVERY_CONTROLLER_V18_ID => Some(recovery_development_profile_v18()),
        EXACT_S169_RECOVERY_CONTROLLER_V19_ID => Some(recovery_development_profile_v19()),
        EXACT_S169_RECOVERY_CONTROLLER_V20_ID => Some(recovery_development_profile_v20()),
        EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID => Some(partial_direct_neutral_control::profile()),
        _ => None,
    }
}

fn valid_digest(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn finite(value: f64, field: &str) -> std::result::Result<(), String> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(format!("nonfinite:{field}"))
    }
}

fn nonnegative(value: f64, field: &str) -> std::result::Result<(), String> {
    finite(value, field)?;
    if value < 0.0 {
        Err(format!("negative:{field}"))
    } else {
        Ok(())
    }
}

fn expected_runtime_binding(engine: RecoveryNativeEngineV1) -> (&'static str, &'static str, u32) {
    match engine {
        RecoveryNativeEngineV1::GodotJolt4_7 => {
            (GODOT_COLLECTOR_ID, GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID, 1)
        }
        RecoveryNativeEngineV1::RapierParryNative => {
            (RAPIER_COLLECTOR_ID, RAPIER_NATIVE_RUNTIME_PROFILE_ID, 1)
        }
        RecoveryNativeEngineV1::MujocoNative => {
            (MUJOCO_COLLECTOR_ID, MUJOCO_NATIVE_RUNTIME_PROFILE_ID, 5)
        }
    }
}

fn collection_refusal(
    request: &RecoveryNativeCollectionRequestV1,
    status: RecoverySupportStatusV1,
    reason: String,
    capability_sha256: String,
) -> RecoveryNativeCollectionReceiptV1 {
    RecoveryNativeCollectionReceiptV1 {
        schema_version: RECOVERY_NATIVE_COLLECTION_RECEIPT_V1_VERSION.to_owned(),
        support_status: status,
        refusal_reason: Some(reason),
        collector_id: request.runtime_binding.collector_id.clone(),
        adapter_id: request.adapter_capability.adapter_id.clone(),
        engine: request.adapter_capability.engine,
        runtime_profile_id: request.runtime_binding.runtime_profile_id.clone(),
        capability_sha256,
        observation_sha256: None,
        observation: None,
        native_observation_validation_kernel_implemented: true,
        native_adapter_collection_surface_implemented: true,
        supplied_native_post_step_observation_validated: false,
        native_runtime_observation_collection_executed: false,
        engine_identity_exposed_to_controller: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

fn collection_v2_refusal(
    request: &RecoveryNativeCollectionRequestV3,
    status: RecoverySupportStatusV1,
    reason: String,
    capability_sha256: String,
) -> RecoveryNativeCollectionReceiptV2 {
    RecoveryNativeCollectionReceiptV2 {
        schema_version: RECOVERY_NATIVE_COLLECTION_RECEIPT_V2_VERSION.to_owned(),
        support_status: status,
        refusal_reason: Some(reason),
        collector_id: request.runtime_binding.collector_id.clone(),
        adapter_id: request.adapter_capability.adapter_id.clone(),
        engine: request.adapter_capability.engine,
        runtime_profile_id: request.runtime_binding.runtime_profile_id.clone(),
        capability_sha256,
        observation_source_binding_sha256: None,
        observation_source_binding: None,
        observation_sha256: None,
        observation: None,
        native_observation_validation_kernel_implemented: true,
        native_adapter_collection_surface_implemented: true,
        supplied_native_post_step_observation_validated: false,
        native_runtime_observation_collection_executed: false,
        engine_identity_exposed_to_controller: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

fn validate_binding(
    binding: &RecoveryNativeCollectorBindingV1,
    engine: RecoveryNativeEngineV1,
    capability_sha256: &str,
) -> std::result::Result<(), String> {
    if binding.schema_version != RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION {
        return Err("collector_binding_schema_invalid".to_owned());
    }
    let binding_identity_supported = match engine {
        RecoveryNativeEngineV1::GodotJolt4_7 => {
            (binding.collector_id == GODOT_COLLECTOR_ID
                && binding.runtime_profile_id == GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID)
                || (binding.collector_id == GODOT_COMPLETE_ENERGY_COLLECTOR_ID
                    && binding.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID)
                || (binding.collector_id == GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID
                    && binding.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID)
                || (binding.collector_id == GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID
                    && binding.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID)
                || (binding.collector_id == GODOT_ROTATION_AWARE_COMPLETE_ENERGY_COLLECTOR_ID
                    && binding.runtime_profile_id
                        == GODOT_ROTATION_AWARE_COMPLETE_ENERGY_RUNTIME_PROFILE_ID)
        }
        RecoveryNativeEngineV1::RapierParryNative => {
            binding.collector_id == RAPIER_COLLECTOR_ID
                && binding.runtime_profile_id == RAPIER_NATIVE_RUNTIME_PROFILE_ID
        }
        RecoveryNativeEngineV1::MujocoNative => {
            binding.collector_id == MUJOCO_COLLECTOR_ID
                && binding.runtime_profile_id == MUJOCO_NATIVE_RUNTIME_PROFILE_ID
        }
    };
    if !binding_identity_supported {
        return Err("collector_or_runtime_profile_identity_invalid".to_owned());
    }
    if !valid_digest(&binding.runtime_qualification_sha256)
        || binding.capability_sha256 != capability_sha256
    {
        return Err("collector_runtime_or_capability_digest_invalid".to_owned());
    }
    if !binding.exact_runtime_identity_qualified
        || !binding.native_post_step_only
        || !binding.source_measurement_only
        || binding.missing_value_synthesis_permitted
        || binding.engine_identity_exposed_to_controller
    {
        return Err("collector_claim_boundary_invalid".to_owned());
    }
    Ok(())
}

/// Report whether an adapter/route/mapping tuple has a registered observation-
/// V2 source identity. This is a registry query, not evidence that any supplied
/// observation, implementation, qualification, or physical execution is valid.
pub fn recovery_observation_v2_source_identity_supported_v1(
    engine: RecoveryNativeEngineV1,
    producer_adapter_id: &str,
    source_route_id: &str,
    mapping_profile_id: &str,
) -> bool {
    match engine {
        RecoveryNativeEngineV1::MujocoNative => {
            producer_adapter_id == MUJOCO_ADAPTER_ID
                && source_route_id == MUJOCO_R24D36_SIGNED_WORK_ROUTE_ID
                && matches!(
                    mapping_profile_id,
                    MUJOCO_R24D38_ENERGY_V2_MAPPING_PROFILE_ID
                        | MUJOCO_R24D42_STREAMING_ENERGY_V2_MAPPING_PROFILE_ID
                )
        }
        RecoveryNativeEngineV1::RapierParryNative => {
            producer_adapter_id == RAPIER_ADAPTER_ID
                && source_route_id == RAPIER_R24D48_RECOVERY_ROUTE_ID
                && mapping_profile_id == RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID
        }
        RecoveryNativeEngineV1::GodotJolt4_7 => {
            producer_adapter_id == GODOT_ADAPTER_ID
                && ((source_route_id == GODOT_R24D57_RECOVERY_ROUTE_ID
                    && mapping_profile_id == GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID)
                    || (source_route_id == GODOT_R24D136_RECOVERY_ROUTE_ID
                        && mapping_profile_id == GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID)
                    || (source_route_id == GODOT_R24D144_RECOVERY_ROUTE_ID
                        && mapping_profile_id == GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID)
                    || (source_route_id == GODOT_R24D148_RECOVERY_ROUTE_ID
                        && mapping_profile_id == GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID))
        }
    }
}

fn recovery_observation_v2_source_identity_matches_runtime_binding_v1(
    engine: RecoveryNativeEngineV1,
    runtime: &RecoveryNativeCollectorBindingV1,
    source: &RecoveryObservationV2SourceBindingV1,
) -> bool {
    if !recovery_observation_v2_source_identity_supported_v1(
        engine,
        &source.producer_adapter_id,
        &source.source_route_id,
        &source.mapping_profile_id,
    ) {
        return false;
    }
    match engine {
        RecoveryNativeEngineV1::GodotJolt4_7 => {
            (runtime.collector_id == GODOT_COLLECTOR_ID
                && runtime.runtime_profile_id == GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID
                && source.source_route_id == GODOT_R24D57_RECOVERY_ROUTE_ID
                && source.mapping_profile_id == GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID)
                || (runtime.collector_id == GODOT_COMPLETE_ENERGY_COLLECTOR_ID
                    && runtime.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID
                    && source.source_route_id == GODOT_R24D136_RECOVERY_ROUTE_ID
                    && source.mapping_profile_id == GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID)
                || (runtime.collector_id == GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID
                    && runtime.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID
                    && source.source_route_id == GODOT_R24D144_RECOVERY_ROUTE_ID
                    && source.mapping_profile_id == GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID)
                || (runtime.collector_id == GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID
                    && runtime.runtime_profile_id == GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID
                    && source.source_route_id == GODOT_R24D148_RECOVERY_ROUTE_ID
                    && source.mapping_profile_id == GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID)
                || (runtime.collector_id == GODOT_ROTATION_AWARE_COMPLETE_ENERGY_COLLECTOR_ID
                    && runtime.runtime_profile_id
                        == GODOT_ROTATION_AWARE_COMPLETE_ENERGY_RUNTIME_PROFILE_ID
                    && source.source_route_id == GODOT_R24D148_RECOVERY_ROUTE_ID
                    && source.mapping_profile_id == GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID)
        }
        RecoveryNativeEngineV1::RapierParryNative | RecoveryNativeEngineV1::MujocoNative => true,
    }
}

fn validate_observation_v2_source_binding(
    request: &RecoveryNativeCollectionRequestV3,
    observation_sha256: &str,
) -> std::result::Result<String, String> {
    let source = &request.observation_source_binding;
    if source.schema_version != RECOVERY_OBSERVATION_V2_SOURCE_BINDING_V1_VERSION
        || source.producer_adapter_id != request.adapter_capability.adapter_id
        || !recovery_observation_v2_source_identity_matches_runtime_binding_v1(
            request.adapter_capability.engine,
            &request.runtime_binding,
            source,
        )
        || request.observation.schema_version != RECOVERY_OBSERVATION_V2_VERSION
        || request.observation.energy_balance.source_profile_id != source.mapping_profile_id
    {
        return Err("observation_v2_source_identity_invalid".to_owned());
    }
    if [
        &source.mapping_receipt_sha256,
        &source.source_component_receipts_sha256,
        &source.observation_base_sha256,
        &source.ledger_sha256,
        &source.portable_observation_sha256,
        &source.source_chain_sha256,
    ]
    .into_iter()
    .any(|value| !valid_digest(value))
    {
        return Err("observation_v2_source_digest_invalid".to_owned());
    }
    let observed_base_sha256 = recovery_observation_base_sha256(&request.observation)
        .map_err(|error| format!("observation_v2_base_digest_failed:{error}"))?;
    let observed_ledger_sha256 = digest_serializable(&request.observation.energy_balance)
        .map_err(|error| format!("observation_v2_ledger_digest_failed:{error}"))?;
    let observed_source_chain_sha256 = source
        .source_chain_sha256()
        .map_err(|error| format!("observation_v2_source_chain_digest_failed:{error}"))?;
    if source.observation_base_sha256 != observed_base_sha256
        || source.ledger_sha256 != observed_ledger_sha256
        || source.portable_observation_sha256 != observation_sha256
        || source.source_chain_sha256 != observed_source_chain_sha256
    {
        return Err("observation_v2_source_binding_mismatch".to_owned());
    }
    digest_serializable(source)
        .map_err(|error| format!("observation_v2_source_binding_digest_failed:{error}"))
}

fn validate_ownership<O: RecoveryObservationLike>(
    observation_value: &O,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> std::result::Result<(), String> {
    let observation = observation_value.view();
    let ownership = observation.controller_ownership;
    if !ownership.source_measurement || ownership.fallback_controller_active {
        return Err("controller_ownership_source_or_fallback_invalid".to_owned());
    }
    match arm_kind {
        RecoveryArmKindV1::MatchedZeroCommand => {
            if ownership.owner != RecoveryControllerOwnerV1::None
                || ownership.recovery_controller_id.is_some()
                || ownership.stance_controller_id.is_some()
                || ownership.handoff_event_count != 0
            {
                return Err("matched_zero_controller_ownership_invalid".to_owned());
            }
        }
        RecoveryArmKindV1::CandidateCommand => match phase {
            RecoveryPhaseV1::ConfirmProne
            | RecoveryPhaseV1::EstablishDistalSupport
            | RecoveryPhaseV1::RaiseBody => {
                if ownership.owner != RecoveryControllerOwnerV1::Recovery
                    || !ownership
                        .recovery_controller_id
                        .as_deref()
                        .is_some_and(registered_recovery_controller)
                    || ownership.stance_controller_id.is_some()
                    || ownership.handoff_event_count != 0
                {
                    return Err("recovery_controller_ownership_invalid".to_owned());
                }
            }
            RecoveryPhaseV1::StanceHandoff
            | RecoveryPhaseV1::StanceDwell
            | RecoveryPhaseV1::Complete => {
                if ownership.owner != RecoveryControllerOwnerV1::Stance
                    || ownership.recovery_controller_id.is_some()
                    || !ownership.stance_controller_id.as_deref().is_some_and(|id|
                        id == EXACT_S169_STANCE_CONTROLLER_ID || candidate_stance_profile(id).is_some())
                    || ownership.handoff_event_count != 1
                {
                    return Err("stance_controller_ownership_invalid".to_owned());
                }
            }
            RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {
                if ownership.owner != RecoveryControllerOwnerV1::None {
                    return Err("terminal_controller_ownership_invalid".to_owned());
                }
            }
        },
    }
    Ok(())
}

fn observation_ownership_matches_requested_controller<O: RecoveryObservationLike>(
    observation_value: &O,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    controller_id: &str,
) -> bool {
    if arm_kind == RecoveryArmKindV1::MatchedZeroCommand
        || !matches!(
            phase,
            RecoveryPhaseV1::ConfirmProne
                | RecoveryPhaseV1::EstablishDistalSupport
                | RecoveryPhaseV1::RaiseBody
        )
    {
        return true;
    }
    let ownership = observation_value.view().controller_ownership;
    ownership.owner == RecoveryControllerOwnerV1::Recovery
        && ownership.recovery_controller_id.as_deref() == Some(controller_id)
}

fn validate_observation<O: RecoveryObservationLike>(
    observation_value: &O,
    task_id: &str,
    semantics_id: &str,
    actuator_profile_id: &str,
    descriptor: &BoundedQuadrupedDescriptor,
    adapter_capability: &RecoveryAdapterCapabilityV1,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    capability_sha256: &str,
    compiled: &ResolvedRecoveryMorphology,
    passive_entry: bool,
) -> std::result::Result<(), String> {
    let observation = observation_value.view();
    if observation.schema_version != O::expected_schema_version()
        || observation.task_id != task_id
        || observation.semantics_id != semantics_id
        || observation.actuator_profile_id != actuator_profile_id
    {
        return Err("observation_identity_invalid".to_owned());
    }
    finite(observation.outer_step_duration_s, "outer_step_duration_s")?;
    if observation.outer_step_duration_s.to_bits() != RECOVERY_OUTER_STEP_DURATION_S.to_bits()
        || observation.semantic_step != observation.state.semantic_step
        || observation.semantic_step != observation.applied_actuation.source_semantic_step
        || observation.semantic_step != observation.engine_step_identity.semantic_step
    {
        return Err("observation_step_identity_invalid".to_owned());
    }
    observation
        .state
        .validate(&compiled.morphology)
        .map_err(|error| format!("state_frame_invalid:{error}"))?;
    if observation.state.adapter_capability_sha256 != capability_sha256 {
        return Err("state_capability_digest_mismatch".to_owned());
    }
    for joint in &observation.state.ordered_joint_observations {
        if !joint.validity.position
            || !joint.validity.velocity
            || joint.position_rad.is_none()
            || joint.velocity_rad_s.is_none()
        {
            return Err(format!("joint_channel_incomplete:{}", joint.joint_id));
        }
    }
    for contact in &observation.state.ordered_contact_observations {
        if contact.provenance.adapter_id != adapter_capability.adapter_id
            || !matches!(
                contact.provenance.quality,
                ContactQuality::QualifiedBearing | ContactQuality::QualifiedLoad
            )
            || contact.presence.is_none()
            || contact.bears_support.is_none()
        {
            return Err(format!(
                "foot_contact_channel_incomplete:{}",
                contact.contact_site_id
            ));
        }
    }

    observation
        .center_of_mass
        .position_world_m
        .finite("recovery.center_of_mass.position")
        .map_err(|error| error.to_string())?;
    observation
        .center_of_mass
        .linear_velocity_world_m_s
        .finite("recovery.center_of_mass.velocity")
        .map_err(|error| error.to_string())?;
    if !observation.center_of_mass.source_measurement {
        return Err("center_of_mass_not_measured".to_owned());
    }

    if observation.ordered_foot_bearing_observations.len()
        != compiled.morphology.ordered_contact_site_ids.len()
    {
        return Err("foot_bearing_cardinality_invalid".to_owned());
    }
    for (index, foot) in observation
        .ordered_foot_bearing_observations
        .iter()
        .enumerate()
    {
        if foot.contact_site_id != compiled.morphology.ordered_contact_site_ids[index]
            || !foot.source_measurement
        {
            return Err("foot_bearing_order_or_source_invalid".to_owned());
        }
        nonnegative(foot.bearing_normal_impulse_ns, "foot_bearing_impulse")?;
        let base = &observation.state.ordered_contact_observations[index];
        if (foot.bearing_normal_impulse_ns > 0.0
            && (base.presence != Some(true) || base.bears_support != Some(true)))
            || (!foot.ordinary_unilateral_contact && foot.bearing_normal_impulse_ns > 0.0)
        {
            return Err("foot_bearing_semantics_inconsistent".to_owned());
        }
    }

    if observation.ordered_body_clearance_observations.len()
        != compiled.morphology.ordered_body_ids.len()
    {
        return Err("body_clearance_cardinality_invalid".to_owned());
    }
    for (index, body) in observation
        .ordered_body_clearance_observations
        .iter()
        .enumerate()
    {
        validate_body_clearance_observation_v1(
            body,
            &adapter_capability.adapter_id,
            &compiled.morphology.ordered_body_ids[index],
        )?;
    }

    let profile = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
        profile_id: actuator_profile_id.to_owned(),
        descriptor: descriptor.clone(),
    })
    .map_err(|error| format!("actuator_profile_invalid:{error}"))?;
    let profile = profile
        .profile
        .ok_or_else(|| "actuator_profile_missing".to_owned())?;
    let applied = &observation.applied_actuation;
    if applied.adapter_id != adapter_capability.adapter_id
        || !valid_digest(&applied.adapter_receipt_sha256)
        || applied.command_id.trim().is_empty()
        || !valid_digest(&applied.command_sha256)
        || applied.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || applied.actuator_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || !applied.source_measurement
        || applied.ordered_applied_impulses.len() != profile.ordered_caps.len()
    {
        return Err("applied_actuation_receipt_invalid".to_owned());
    }
    if applied.zero_command != (arm_kind == RecoveryArmKindV1::MatchedZeroCommand) {
        return Err("actuation_arm_identity_invalid".to_owned());
    }
    for (item, cap) in applied
        .ordered_applied_impulses
        .iter()
        .zip(profile.ordered_caps)
    {
        if item.actuator_id != cap.actuator_id {
            return Err("applied_actuation_order_invalid".to_owned());
        }
        finite(item.applied_angular_impulse_nms, "applied_angular_impulse")?;
        if item.applied_angular_impulse_nms.abs() > cap.maximum_outer_step_impulse_nms {
            return Err(format!(
                "published_actuator_budget_exceeded:{}",
                item.actuator_id
            ));
        }
        if applied.zero_command && item.applied_angular_impulse_nms != 0.0 {
            return Err(format!("matched_zero_command_nonzero:{}", item.actuator_id));
        }
    }

    if observation.external_interventions.total_count() != 0 {
        return Err("no_cheat_intervention_counter_nonzero".to_owned());
    }
    if passive_entry {
        // Candidate identity is still checked above. A passive entry sample
        // has no controller; it is not a matched-zero arm or a terminal sample.
        let ownership = observation.controller_ownership;
        if !ownership.source_measurement || ownership.fallback_controller_active
            || ownership.owner != RecoveryControllerOwnerV1::None
            || ownership.recovery_controller_id.is_some()
            || ownership.stance_controller_id.is_some()
            || ownership.handoff_event_count != 0
        {
            return Err("passive_entry_collector_ownership_invalid".to_owned());
        }
        if applied.ordered_applied_impulses.iter()
            .any(|v| v.applied_angular_impulse_nms != 0.0)
        {
            return Err("passive_entry_collector_nonzero_motor_impulse".to_owned());
        }
    } else {
        validate_ownership(observation_value, arm_kind, phase)?;
    }
    observation_value.validate_energy_balance()?;

    let engine = &observation.engine_step_identity;
    let (_, _, expected_substeps) = expected_runtime_binding(adapter_capability.engine);
    if engine.schema_version != RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION
        || engine.source_kind != RecoveryObservationSourceKindV1::NativePostStep
        || engine.adapter_id != adapter_capability.adapter_id
        || engine.engine != adapter_capability.engine
        || engine.capability_sha256 != capability_sha256
        || !valid_digest(&engine.source_trace_sha256)
        || engine.host_step_after != engine.host_step_before.saturating_add(1)
        || engine.native_solver_substep_count != expected_substeps
        || !engine.post_step_observation
        || engine.engine_identity_exposed_to_policy
    {
        return Err("native_engine_step_identity_invalid".to_owned());
    }
    Ok(())
}

struct NativeCollectionRequestView<'a, O> {
    task_id: &'a str,
    semantics_id: &'a str,
    actuator_profile_id: &'a str,
    descriptor: &'a BoundedQuadrupedDescriptor,
    morphology_context: Option<&'a RecoveryMorphologyContextV1>,
    adapter_capability: &'a RecoveryAdapterCapabilityV1,
    runtime_binding: &'a RecoveryNativeCollectorBindingV1,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    observation: &'a O,
}

enum NativeCollectionResolution {
    Supported {
        capability_sha256: String,
    },
    Refused {
        status: RecoverySupportStatusV1,
        reason: String,
        capability_sha256: String,
    },
}

fn resolve_native_collection<O: RecoveryObservationLike>(
    request: NativeCollectionRequestView<'_, O>,
) -> Result<NativeCollectionResolution> {
    resolve_native_collection_scoped(request, false)
}

fn resolve_native_collection_scoped<O: RecoveryObservationLike>(
    request: NativeCollectionRequestView<'_, O>,
    passive_entry: bool,
) -> Result<NativeCollectionResolution> {
    resolve_native_collection_for_task(request, passive_entry, NativeTaskScope::Canonical)
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum NativeTaskScope { Canonical, PartialFall, Upright }

fn resolve_native_collection_for_task<O: RecoveryObservationLike>(
    request: NativeCollectionRequestView<'_, O>,
    passive_entry: bool,
    task: NativeTaskScope,
) -> Result<NativeCollectionResolution> {
    let capability_sha256 = digest_serializable(request.adapter_capability)?;
    let (task_id, semantics_id) = if task == NativeTaskScope::Canonical {
        (CANONICAL_PRONE_TO_STANDING_TASK_ID, PORTABLE_RECOVERY_SEMANTICS_ID)
    } else if task == NativeTaskScope::PartialFall {
        (crate::recovery::partial_fall::TASK, crate::recovery::partial_fall::SEMANTICS)
    } else { (crate::recovery::upright_recovery::TASK, crate::recovery::upright_recovery::SEMANTICS) };
    if request.task_id != task_id
        || request.semantics_id != semantics_id
        || request.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || (task != NativeTaskScope::Canonical && (passive_entry
            || request.arm_kind != RecoveryArmKindV1::CandidateCommand
            || !matches!(request.phase, RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody
                | RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell)))
    {
        return Ok(NativeCollectionResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedProfile,
            reason: "task_semantics_or_actuator_profile_not_registered".to_owned(),
            capability_sha256,
        });
    }
    let compiled = resolve_recovery_morphology_context(
        request.descriptor.clone(),
        request.morphology_context,
    )?;
    if let Some(reason) = compiled.refusal_reason.clone() {
        return Ok(NativeCollectionResolution::Refused {
            status: RecoverySupportStatusV1::OutOfDomainMorphology,
            reason,
            capability_sha256,
        });
    }
    if compiled.base.morphology_id != R23D60_SELECTED_S169_MORPHOLOGY_ID
        || compiled.base.descriptor_sha256 != R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        || compiled.base.morphology.morphology_spec_sha256
            != R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
    {
        return Ok(NativeCollectionResolution::Refused {
            status: RecoverySupportStatusV1::OutOfDomainMorphology,
            reason: "descriptor_outside_exact_recovery_scope".to_owned(),
            capability_sha256,
        });
    }
    if task != NativeTaskScope::Canonical {
        let context = request.morphology_context
            .ok_or_else(|| CoreError::Schema("partial_fall_native_morphology_context_missing".to_owned()))?;
        crate::recovery::partial_fall::validate_native_context(request.descriptor.clone(), context,
            request.adapter_capability)?;
    } else {
    let initialization = if let Some(context) = request.morphology_context {
        initialize_recovery_v2(RecoveryInitializeRequestV2 {
            schema_version: crate::recovery::RECOVERY_INITIALIZE_REQUEST_V2_VERSION.to_owned(),
            task_id: request.task_id.to_owned(),
            semantics_id: request.semantics_id.to_owned(),
            actuator_profile_id: request.actuator_profile_id.to_owned(),
            threshold_profile_id: crate::recovery::SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID
                .to_owned(),
            descriptor: request.descriptor.clone(),
            morphology_context: context.clone(),
            adapter_capability: request.adapter_capability.clone(),
            arm_kind: request.arm_kind,
        })?
    } else {
        initialize_recovery_v1(RecoveryInitializeRequestV1 {
            schema_version: crate::recovery::RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
            task_id: request.task_id.to_owned(),
            semantics_id: request.semantics_id.to_owned(),
            actuator_profile_id: request.actuator_profile_id.to_owned(),
            threshold_profile_id: crate::recovery::SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID
                .to_owned(),
            descriptor: request.descriptor.clone(),
            adapter_capability: request.adapter_capability.clone(),
            arm_kind: request.arm_kind,
        })?
    };
    if initialization.support_status != RecoverySupportStatusV1::SupportedExact {
        return Ok(NativeCollectionResolution::Refused {
            status: initialization.support_status,
            reason: initialization
                .refusal_reason
                .unwrap_or_else(|| "adapter_capability_refused".to_owned()),
            capability_sha256,
        });
    }
    }
    if let Err(reason) = validate_binding(
        request.runtime_binding,
        request.adapter_capability.engine,
        &capability_sha256,
    ) {
        return Ok(NativeCollectionResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedCapability,
            reason,
            capability_sha256,
        });
    }
    if let Err(reason) = validate_observation(
        request.observation,
        request.task_id,
        request.semantics_id,
        request.actuator_profile_id,
        request.descriptor,
        request.adapter_capability,
        request.arm_kind,
        request.phase,
        &capability_sha256,
        &compiled,
        passive_entry,
    ) {
        return Ok(NativeCollectionResolution::Refused {
            status: RecoverySupportStatusV1::InvalidObservation,
            reason,
            capability_sha256,
        });
    }
    Ok(NativeCollectionResolution::Supported { capability_sha256 })
}

pub fn collect_native_recovery_observation_v1(
    request: RecoveryNativeCollectionRequestV1,
) -> Result<RecoveryNativeCollectionReceiptV1> {
    if request.schema_version != RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_native_collection_request_version".to_owned(),
        ));
    }
    collect_native_recovery_observation(request, None)
}

pub fn collect_native_recovery_observation_v2(
    request: RecoveryNativeCollectionRequestV2,
) -> Result<RecoveryNativeCollectionReceiptV1> {
    if request.schema_version != RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_native_collection_request_version".to_owned(),
        ));
    }
    let morphology_context = request.morphology_context;
    collect_native_recovery_observation(
        RecoveryNativeCollectionRequestV1 {
            schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION.to_owned(),
            task_id: request.task_id,
            semantics_id: request.semantics_id,
            actuator_profile_id: request.actuator_profile_id,
            descriptor: request.descriptor,
            adapter_capability: request.adapter_capability,
            runtime_binding: request.runtime_binding,
            arm_kind: request.arm_kind,
            phase: request.phase,
            observation: request.observation,
        },
        Some(&morphology_context),
    )
}

pub mod passive_entry_collection;
pub mod partial_fall_control;
pub mod partial_direct_neutral_control;
pub mod partial_pose_geometry_control;
pub mod partial_pose_geometry_composition;
pub mod partial_load_seeking_control;
pub mod partial_load_seeking_composition;
pub mod partial_downward_rise_control;
pub mod partial_downward_rise_composition;
pub mod partial_concurrent_load_rise_control;
pub mod partial_concurrent_load_rise_composition;
pub mod partial_hip_recenter_control;
pub mod partial_support_anchored_control;
pub mod partial_progressive_headroom_control;
pub mod partial_native_reference_control;
pub mod partial_native_reference_composition;
pub mod partial_hip_recenter_composition;
pub mod partial_support_anchored_composition;
pub mod partial_progressive_headroom_composition;
pub mod upright_recovery_control;
pub mod upright_direct_rise_control;

pub fn collect_native_recovery_observation_v3(
    request: RecoveryNativeCollectionRequestV3,
) -> Result<RecoveryNativeCollectionReceiptV2> {
    if request.schema_version != RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_native_collection_request_version".to_owned(),
        ));
    }
    collect_native_observation_v3_scoped(request, false)
}

fn collect_native_observation_v3_scoped(
    request: RecoveryNativeCollectionRequestV3,
    passive_entry: bool,
) -> Result<RecoveryNativeCollectionReceiptV2> {
    collect_native_observation_v3_for_task(request, passive_entry, NativeTaskScope::Canonical)
}

fn collect_native_observation_v3_for_task(
    request: RecoveryNativeCollectionRequestV3,
    passive_entry: bool,
    task: NativeTaskScope,
) -> Result<RecoveryNativeCollectionReceiptV2> {
    let adapter_mapping_qualified = matches!(
        (
            request.adapter_capability.engine,
            request.adapter_capability.adapter_id.as_str(),
        ),
        (RecoveryNativeEngineV1::MujocoNative, MUJOCO_ADAPTER_ID)
            | (RecoveryNativeEngineV1::RapierParryNative, RAPIER_ADAPTER_ID)
            | (RecoveryNativeEngineV1::GodotJolt4_7, GODOT_ADAPTER_ID)
    );
    if !adapter_mapping_qualified {
        let capability_sha256 = digest_serializable(&request.adapter_capability)?;
        return Ok(collection_v2_refusal(
            &request,
            RecoverySupportStatusV1::UnsupportedCapability,
            "observation_v2_native_mapping_not_qualified_for_engine".to_owned(),
            capability_sha256,
        ));
    }
    let capability_sha256 = match resolve_native_collection_for_task(NativeCollectionRequestView {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        descriptor: &request.descriptor,
        morphology_context: Some(&request.morphology_context),
        adapter_capability: &request.adapter_capability,
        runtime_binding: &request.runtime_binding,
        arm_kind: request.arm_kind,
        phase: request.phase,
        observation: &request.observation,
    }, passive_entry, task)? {
        NativeCollectionResolution::Supported { capability_sha256 } => capability_sha256,
        NativeCollectionResolution::Refused {
            status,
            reason,
            capability_sha256,
        } => {
            return Ok(collection_v2_refusal(
                &request,
                status,
                reason,
                capability_sha256,
            ));
        }
    };
    let observation_sha256 = digest_serializable(&request.observation)?;
    let observation_source_binding_sha256 =
        match validate_observation_v2_source_binding(&request, &observation_sha256) {
            Ok(value) => value,
            Err(reason) => {
                return Ok(collection_v2_refusal(
                    &request,
                    RecoverySupportStatusV1::InvalidObservation,
                    reason,
                    capability_sha256,
                ));
            }
        };
    Ok(RecoveryNativeCollectionReceiptV2 {
        schema_version: RECOVERY_NATIVE_COLLECTION_RECEIPT_V2_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        collector_id: request.runtime_binding.collector_id.clone(),
        adapter_id: request.adapter_capability.adapter_id.clone(),
        engine: request.adapter_capability.engine,
        runtime_profile_id: request.runtime_binding.runtime_profile_id.clone(),
        capability_sha256,
        observation_source_binding_sha256: Some(observation_source_binding_sha256),
        observation_source_binding: Some(request.observation_source_binding),
        observation_sha256: Some(observation_sha256),
        observation: Some(request.observation),
        native_observation_validation_kernel_implemented: true,
        native_adapter_collection_surface_implemented: true,
        supplied_native_post_step_observation_validated: true,
        native_runtime_observation_collection_executed: false,
        engine_identity_exposed_to_controller: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

fn collect_native_recovery_observation(
    request: RecoveryNativeCollectionRequestV1,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<RecoveryNativeCollectionReceiptV1> {
    let capability_sha256 = match resolve_native_collection(NativeCollectionRequestView {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        descriptor: &request.descriptor,
        morphology_context,
        adapter_capability: &request.adapter_capability,
        runtime_binding: &request.runtime_binding,
        arm_kind: request.arm_kind,
        phase: request.phase,
        observation: &request.observation,
    })? {
        NativeCollectionResolution::Supported { capability_sha256 } => capability_sha256,
        NativeCollectionResolution::Refused {
            status,
            reason,
            capability_sha256,
        } => {
            return Ok(collection_refusal(
                &request,
                status,
                reason,
                capability_sha256,
            ));
        }
    };
    let observation_sha256 = digest_serializable(&request.observation)?;
    Ok(RecoveryNativeCollectionReceiptV1 {
        schema_version: RECOVERY_NATIVE_COLLECTION_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        collector_id: request.runtime_binding.collector_id.clone(),
        adapter_id: request.adapter_capability.adapter_id.clone(),
        engine: request.adapter_capability.engine,
        runtime_profile_id: request.runtime_binding.runtime_profile_id.clone(),
        capability_sha256,
        observation_sha256: Some(observation_sha256),
        observation: Some(request.observation),
        native_observation_validation_kernel_implemented: true,
        native_adapter_collection_surface_implemented: true,
        supplied_native_post_step_observation_validated: true,
        native_runtime_observation_collection_executed: false,
        engine_identity_exposed_to_controller: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

struct RecoveryControlPlanContext<'a> {
    controller_id: &'a str,
    phase_step: u32,
    descriptor: &'a BoundedQuadrupedDescriptor,
    arm_kind: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    semantic_step: u64,
    ordered_joint_observations: &'a [JointObservation],
    base_orientation: Quaternion,
}

fn controller_refusal(
    request: &RecoveryControlPlanContext<'_>,
    status: RecoverySupportStatusV1,
    reason: String,
    profile_sha256: String,
) -> RecoveryControlReceiptV1 {
    RecoveryControlReceiptV1 {
        schema_version: RECOVERY_CONTROL_RECEIPT_V1_VERSION.to_owned(),
        support_status: status,
        refusal_reason: Some(reason),
        controller_id: request.controller_id.to_owned(),
        controller_profile_sha256: profile_sha256,
        observation_sha256: None,
        semantic_step: request.semantic_step,
        phase: request.phase,
        phase_step: request.phase_step,
        owner: RecoveryControllerOwnerV1::None,
        recovery_controller_active: false,
        stance_handoff_requested: false,
        matched_zero_command: request.arm_kind == RecoveryArmKindV1::MatchedZeroCommand,
        no_actuation_requested: true,
        ordered_commands: Vec::new(),
        command_sha256: None,
        controller_implemented: true,
        deterministic: true,
        engine_identity_input_count: 0,
        engine_specific_policy_branch_count: 0,
        fallback_controller_active: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

fn smoothstep(progress: f64) -> f64 {
    progress * progress * (3.0 - 2.0 * progress)
}

fn coordinated_support_reference(
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
) -> Result<Vec<f64>> {
    if goals.len() != observations.len() || observations.len() != ORDERED_JOINT_IDS.len() {
        return Err(CoreError::Frame("coordinated_support_joint_population".to_owned()));
    }
    let positions = observations
        .iter()
        .zip(ORDERED_JOINT_IDS)
        .map(|(joint, expected_id)| {
            let position = joint.position_rad.ok_or_else(|| {
                CoreError::Frame("coordinated_support_position_missing".to_owned())
            })?;
            if joint.joint_id != expected_id || !joint.validity.position || !position.is_finite() {
                return Err(CoreError::Frame("coordinated_support_position_invalid".to_owned()));
            }
            Ok(position)
        })
        .collect::<Result<Vec<_>>>()?;
    let largest_error = goals
        .iter()
        .zip(&positions)
        .map(|(goal, position)| (goal - position).abs())
        .fold(0.0_f64, f64::max);
    let maximum_step = maximum_speed_rad_s * RECOVERY_OUTER_STEP_DURATION_S;
    // Inside one permitted step, request the destination exactly. This also
    // handles zero error without dividing by zero or publishing a zero cap.
    if largest_error <= maximum_step {
        return Ok(goals.to_vec());
    }
    let fraction = maximum_step / largest_error;
    Ok(goals.iter().zip(positions)
        .map(|(goal, position)| position + (goal - position) * fraction)
        .collect())
}

fn knees_before_lift_reference(
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
) -> Result<Vec<f64>> {
    // Validate the complete ordered measured population using the same V9 rule.
    let coordinated = coordinated_support_reference(goals, observations, maximum_speed_rad_s)?;
    let maximum_step = maximum_speed_rad_s * RECOVERY_OUTER_STEP_DURATION_S;
    let knees_ready = (1..goals.len()).step_by(2).all(|index| {
        (goals[index] - observations[index].position_rad.unwrap()).abs() <= maximum_step
    });
    if knees_ready {
        return Ok(coordinated);
    }
    let mut knee_goals = goals.to_vec();
    for index in (0..goals.len()).step_by(2) {
        // A target equal to the current angle requests no intended hip progress;
        // the unchanged command serialization projection still applies later.
        // This does not freeze a body or guarantee no actual hip motion.
        knee_goals[index] = observations[index].position_rad.unwrap();
    }
    // Re-evaluate every observation: if a knee drifts away under load, requested
    // hip progress pauses again. No hidden latch or engine-specific state exists.
    coordinated_support_reference(&knee_goals, observations, maximum_speed_rad_s)
}

fn matched_foot_reach_reference(
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
    descriptor: &BoundedQuadrupedDescriptor,
) -> Result<Vec<f64>> {
    let coordinated = coordinated_support_reference(goals, observations, maximum_speed_rad_s)?;
    let positions: Vec<f64> = observations.iter().map(|j| j.position_rad.unwrap()).collect();
    // Same lengths and +Z joint convention as the production quadruped compiler.
    let upper = 0.35 * descriptor.upper_length_fraction;
    let distal = 0.35 * (1.0 - descriptor.upper_length_fraction);
    let height = |hip: f64, knee: f64| -upper * hip.cos() - distal * (hip + knee).cos();
    // Knee-only matching applies to the rearward-folded, monotonically downward
    // branch. Elsewhere continue V9's ordinary coordinated support trajectory.
    if !(0..8).step_by(2).all(|i| {
        let current = positions[i] + positions[i + 1];
        let destination = positions[i] + goals[i + 1];
        (-std::f64::consts::PI..=0.0).contains(&current)
            && (-std::f64::consts::PI..=0.0).contains(&destination)
    }) {
        return Ok(coordinated);
    }
    let lowest_current = (0..8).step_by(2)
        .map(|i| height(positions[i], positions[i + 1])).fold(f64::INFINITY, f64::min);
    let common_reachable = (0..8).step_by(2)
        .map(|i| height(positions[i], goals[i + 1])).fold(f64::NEG_INFINITY, f64::max);
    // Do not demand a reach beyond any leg's existing final knee destination.
    let common_height = lowest_current.max(common_reachable);
    let mut matched = positions.clone();
    for i in (0..8).step_by(2) {
        let cosine = (-(common_height + upper * positions[i].cos()) / distal).clamp(-1.0, 1.0);
        let knee = -cosine.acos() - positions[i];
        // Never leave the joint range already spanned by measured knees and the
        // existing destination. An unreachable matching geometry simply uses
        // the normal coordinated trajectory; it does not relax a joint limit.
        let minimum = positions.iter().skip(1).step_by(2).copied().fold(goals[i + 1], f64::min);
        if knee < minimum || knee > goals[i + 1] {
            return Ok(coordinated);
        }
        matched[i + 1] = knee;
    }
    let maximum_step = maximum_speed_rad_s * RECOVERY_OUTER_STEP_DURATION_S;
    if (1..8).step_by(2).all(|i| (matched[i] - positions[i]).abs() <= maximum_step) {
        return Ok(coordinated);
    }
    // No dwell or persistent latch: re-evaluate reach from each actual reading.
    coordinated_support_reference(&matched, observations, maximum_speed_rad_s)
}

fn world_vertical_foot_reach_reference(
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
    descriptor: &BoundedQuadrupedDescriptor,
    orientation: Quaternion,
) -> Result<Vec<f64>> {
    let coordinated = coordinated_support_reference(goals, observations, maximum_speed_rad_s)?;
    orientation.validate("support_base_orientation")?;
    crate::quadruped::validate_bounded_quadruped_descriptor(descriptor)?;
    let geometry = crate::quadruped::derive_geometry(descriptor);
    let positions: Vec<f64> = observations.iter().map(|j| j.position_rad.unwrap()).collect();
    // World-Y row of the measured body rotation. Common body translation and
    // common hip-Y offset cancel when comparing all four foot heights.
    let q = orientation;
    let a = 2.0 * (q.x * q.y + q.z * q.w);
    let b = 1.0 - 2.0 * (q.x * q.x + q.z * q.z);
    let c = 2.0 * (q.y * q.z - q.x * q.w);
    if a == 0.0 && b == 1.0 && c == 0.0 {
        // Exact legacy arithmetic for level/yaw-only input, where the two
        // constructions are identical. No historical controller is changed.
        return matched_foot_reach_reference(goals, observations, maximum_speed_rad_s, descriptor);
    }
    let radius = a.hypot(b);
    if radius == 0.0 {
        return Ok(coordinated); // Knee motion cannot change world height here.
    }
    let shift = a.atan2(b);
    if !(0..8).step_by(2).all(|i| {
        (-std::f64::consts::PI..=0.0).contains(&(positions[i] + positions[i + 1] + shift))
            && (-std::f64::consts::PI..=0.0).contains(&(positions[i] + goals[i + 1] + shift))
    }) {
        return Ok(coordinated);
    }
    let base_height = |i: usize| {
        let hip_x = if i < 4 { geometry.front_hip_x_m } else { geometry.rear_hip_x_m };
        let hip_z = if i % 4 == 0 { geometry.left_hip_z_m } else { geometry.right_hip_z_m };
        a * hip_x + c * hip_z
            + geometry.upper_length_m * (a * positions[i].sin() - b * positions[i].cos())
    };
    let height = |i: usize, knee: f64| {
        base_height(i) - geometry.lower_length_m * radius * (positions[i] + knee + shift).cos()
    };
    let lowest_current = (0..8).step_by(2).map(|i| height(i, positions[i + 1]))
        .fold(f64::INFINITY, f64::min);
    let common_reachable = (0..8).step_by(2).map(|i| height(i, goals[i + 1]))
        .fold(f64::NEG_INFINITY, f64::max);
    let common_height = lowest_current.max(common_reachable);
    let mut matched = positions.clone();
    for i in (0..8).step_by(2) {
        let cosine = ((base_height(i) - common_height) / (geometry.lower_length_m * radius)).clamp(-1.0, 1.0);
        let knee = -cosine.acos() - shift - positions[i];
        let minimum = positions.iter().skip(1).step_by(2).copied().fold(goals[i + 1], f64::min);
        if knee < minimum || knee > goals[i + 1] {
            return Ok(coordinated);
        }
        matched[i + 1] = knee;
    }
    let maximum_step = maximum_speed_rad_s * RECOVERY_OUTER_STEP_DURATION_S;
    if (1..8).step_by(2).all(|i| (matched[i] - positions[i]).abs() <= maximum_step) {
        return Ok(coordinated);
    }
    // Ideal geometry only: keep the hip request at its measured position while
    // knees match world height. Actual load, tracking and stability remain
    // measured by the unchanged native observer and recovery gates.
    coordinated_support_reference(&matched, observations, maximum_speed_rad_s)
}

fn measured_pose_rise_reference(
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
    phase_step: u32,
    ramp_steps: u32,
) -> Result<Vec<f64>> {
    // Validate the same complete ordered measured population before indexing it.
    let final_step = coordinated_support_reference(goals, observations, maximum_speed_rad_s)?;
    if ramp_steps == 0 {
        return Err(CoreError::Frame("measured_pose_rise_zero_ramp".to_owned()));
    }
    let now = smoothstep((phase_step as f64 / ramp_steps as f64).clamp(0.0, 1.0));
    let next = smoothstep(((phase_step as f64 + 1.0) / ramp_steps as f64).clamp(0.0, 1.0));
    if now >= 1.0 {
        return Ok(final_step);
    }
    // Advance this step's fraction of the REMAINING smooth trajectory. With
    // perfect tracking these factors telescope to the ordinary smoothstep path
    // from the actual phase-entry pose. Under imperfect tracking, use the next
    // actual reading; no hidden saved pose or synthetic observation is introduced.
    let fraction = ((next - now) / (1.0 - now)).clamp(0.0, 1.0);
    let targets: Vec<f64> = goals.iter().zip(observations).map(|(goal, joint)| {
        let position = joint.position_rad.unwrap();
        position + (goal - position) * fraction
    }).collect();
    // Late tracking error must not exceed the existing one-step command bound.
    coordinated_support_reference(&targets, observations, maximum_speed_rad_s)
}

fn support_waypoint_rise_reference(
    waypoint: &[f64],
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
    phase_step: u32,
    ramp_steps: u32,
) -> Result<Vec<f64>> {
    if ramp_steps < 2 {
        return Err(CoreError::Frame("support_waypoint_rise_short_ramp".to_owned()));
    }
    // Equal allocation is a prospective development design, not a fitted
    // physical threshold. Preserve the full existing clock, including odd sizes.
    let preparation_steps = ramp_steps / 2;
    if phase_step < preparation_steps {
        measured_pose_rise_reference(waypoint, observations, maximum_speed_rad_s,
            phase_step, preparation_steps)
    } else {
        // Use the ACTUAL reading at the segment boundary, not an invented pose
        // or a hidden latch claiming that preparation must have succeeded.
        measured_pose_rise_reference(goals, observations, maximum_speed_rad_s,
            phase_step - preparation_steps, ramp_steps - preparation_steps)
    }
}

fn knee_fold_replant_rise_reference(
    support: &[f64],
    goals: &[f64],
    observations: &[JointObservation],
    maximum_speed_rad_s: f64,
    phase_step: u32,
    ramp_steps: u32,
) -> Result<Vec<f64>> {
    // Validate before reading/indexing the measured joints. The existing support
    // pose is mirrored (+0.6, -1.05) without enlarging any angle or motor limit.
    coordinated_support_reference(goals, observations, maximum_speed_rad_s)?;
    if support.len() != goals.len() || ramp_steps < 3 {
        return Err(CoreError::Frame("knee_fold_replant_shape_or_clock".to_owned()));
    }
    let mirrored: Vec<f64> = support.iter().map(|q| -q).collect();
    let segment = ramp_steps / 3;
    if phase_step < segment {
        let mut fold = mirrored;
        for i in (0..fold.len()).step_by(2) {
            // No intended hip progress while folding distal links upward. This
            // requests a motor target; it neither freezes a body nor guarantees
            // actual stationary hips, floor clearance, or unloading of the feet.
            fold[i] = observations[i].position_rad.unwrap();
        }
        measured_pose_rise_reference(&fold, observations, maximum_speed_rad_s,
            phase_step, segment)
    } else if phase_step < 2 * segment {
        measured_pose_rise_reference(&mirrored, observations, maximum_speed_rad_s,
            phase_step - segment, segment)
    } else {
        // Each boundary uses the actual current pose, not assumed attainment.
        measured_pose_rise_reference(goals, observations, maximum_speed_rad_s,
            phase_step - 2 * segment, ramp_steps - 2 * segment)
    }
}

fn build_recovery_control_receipt(
    request: &RecoveryControlPlanContext<'_>,
    observation_sha256: Option<String>,
    profile: RecoveryDevelopmentProfileV1,
    profile_sha256: String,
) -> Result<RecoveryControlReceiptV1> {
    let matched_zero = request.arm_kind == RecoveryArmKindV1::MatchedZeroCommand;
    let (owner, recovery_active, stance_handoff, targets, maximum_speed) = if matched_zero {
        (RecoveryControllerOwnerV1::None, false, false, None, 0.0)
    } else {
        match request.phase {
            RecoveryPhaseV1::ConfirmProne => {
                (RecoveryControllerOwnerV1::Recovery, true, false, None, 0.0)
            }
            RecoveryPhaseV1::EstablishDistalSupport => (
                RecoveryControllerOwnerV1::Recovery,
                true,
                false,
                Some(
                    profile
                        .establish_distal_support_pose
                        .ordered_target_positions_rad
                        .clone(),
                ),
                profile
                    .establish_distal_support_pose
                    .maximum_target_speed_rad_s,
            ),
            RecoveryPhaseV1::RaiseBody => {
                let progress = (request.phase_step as f64 / profile.raise_body_ramp_steps as f64)
                    .clamp(0.0, 1.0);
                let blend = smoothstep(progress);
                let targets = profile
                    .establish_distal_support_pose
                    .ordered_target_positions_rad
                    .iter()
                    .zip(&profile.stance_pose.ordered_target_positions_rad)
                    .map(|(start, end)| start + (end - start) * blend)
                    .collect();
                (
                    RecoveryControllerOwnerV1::Recovery,
                    true,
                    false,
                    Some(targets),
                    profile.stance_pose.maximum_target_speed_rad_s,
                )
            }
            RecoveryPhaseV1::StanceHandoff
            | RecoveryPhaseV1::StanceDwell
            | RecoveryPhaseV1::Complete => {
                (RecoveryControllerOwnerV1::Stance, false, true, None, 0.0)
            }
            RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {
                (RecoveryControllerOwnerV1::None, false, false, None, 0.0)
            }
        }
    };

    let ordered_commands = if let Some(targets) = targets {
        let targets = if request.controller_id == EXACT_S169_PARTIAL_DIRECT_NEUTRAL_CONTROLLER_V21_ID
            && matches!(request.phase, RecoveryPhaseV1::EstablishDistalSupport | RecoveryPhaseV1::RaiseBody)
        {
            measured_pose_rise_reference(&profile.stance_pose.ordered_target_positions_rad,
                request.ordered_joint_observations, maximum_speed, request.phase_step,
                profile.raise_body_ramp_steps)?
        } else if matches!(request.controller_id, EXACT_S169_RECOVERY_CONTROLLER_V14_ID | EXACT_S169_RECOVERY_CONTROLLER_V15_ID | EXACT_S169_RECOVERY_CONTROLLER_V16_ID | EXACT_S169_RECOVERY_CONTROLLER_V17_ID | EXACT_S169_RECOVERY_CONTROLLER_V18_ID | EXACT_S169_RECOVERY_CONTROLLER_V19_ID | EXACT_S169_RECOVERY_CONTROLLER_V20_ID)
            && request.phase == RecoveryPhaseV1::RaiseBody
        {
            knee_fold_replant_rise_reference(
                &profile.establish_distal_support_pose.ordered_target_positions_rad,
                &profile.stance_pose.ordered_target_positions_rad,
                request.ordered_joint_observations, maximum_speed, request.phase_step,
                profile.raise_body_ramp_steps)?
        } else if request.controller_id == EXACT_S169_RECOVERY_CONTROLLER_V13_ID
            && request.phase == RecoveryPhaseV1::RaiseBody
        {
            support_waypoint_rise_reference(
                &profile.establish_distal_support_pose.ordered_target_positions_rad,
                &profile.stance_pose.ordered_target_positions_rad,
                request.ordered_joint_observations, maximum_speed, request.phase_step,
                profile.raise_body_ramp_steps)?
        } else if request.controller_id == EXACT_S169_RECOVERY_CONTROLLER_V12_ID
            && request.phase == RecoveryPhaseV1::RaiseBody
        {
            measured_pose_rise_reference(&profile.stance_pose.ordered_target_positions_rad,
                request.ordered_joint_observations, maximum_speed, request.phase_step,
                profile.raise_body_ramp_steps)?
        } else if matches!(request.controller_id, EXACT_S169_RECOVERY_CONTROLLER_V18_ID | EXACT_S169_RECOVERY_CONTROLLER_V19_ID | EXACT_S169_RECOVERY_CONTROLLER_V20_ID)
            && request.phase == RecoveryPhaseV1::EstablishDistalSupport
        {
            world_vertical_foot_reach_reference(&targets, request.ordered_joint_observations,
                maximum_speed, request.descriptor, request.base_orientation)?
        } else if matches!(request.controller_id, EXACT_S169_RECOVERY_CONTROLLER_V11_ID | EXACT_S169_RECOVERY_CONTROLLER_V12_ID | EXACT_S169_RECOVERY_CONTROLLER_V13_ID | EXACT_S169_RECOVERY_CONTROLLER_V14_ID | EXACT_S169_RECOVERY_CONTROLLER_V15_ID | EXACT_S169_RECOVERY_CONTROLLER_V16_ID | EXACT_S169_RECOVERY_CONTROLLER_V17_ID)
            && request.phase == RecoveryPhaseV1::EstablishDistalSupport
        {
            matched_foot_reach_reference(&targets, request.ordered_joint_observations, maximum_speed, request.descriptor)?
        } else if request.controller_id == EXACT_S169_RECOVERY_CONTROLLER_V10_ID
            && request.phase == RecoveryPhaseV1::EstablishDistalSupport
        {
            knees_before_lift_reference(&targets, request.ordered_joint_observations, maximum_speed)?
        } else if request.controller_id == EXACT_S169_RECOVERY_CONTROLLER_V9_ID
            && request.phase == RecoveryPhaseV1::EstablishDistalSupport
        {
            coordinated_support_reference(&targets, request.ordered_joint_observations, maximum_speed)?
        } else {
            targets
        };
        let profile_receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
            schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
            profile_id: profile.actuator_profile_id.clone(),
            descriptor: request.descriptor.clone(),
        })?;
        if profile_receipt.support_status != ActuatorCapProfileSupportStatusV1::SupportedExact {
            return Ok(controller_refusal(
                request,
                RecoverySupportStatusV1::UnsupportedProfile,
                "actuator_profile_resolution_refused".to_owned(),
                profile_sha256,
            ));
        }
        let actuator_profile = profile_receipt
            .profile
            .ok_or_else(|| CoreError::Internal("supported_actuator_profile_missing".to_owned()))?;
        targets
            .into_iter()
            .zip(actuator_profile.ordered_caps)
            .map(|(target, cap)| {
                Ok(RecoveryControlCommandV1 {
                    schema_version: RECOVERY_CONTROL_COMMAND_V1_VERSION.to_owned(),
                    actuator_id: cap.actuator_id,
                    joint_id: cap.joint_id,
                    mode: ActuatorMode::PositionVelocity,
                    // Keep one decimal guard digit below canonical JSON so the
                    // command value and digest retain one portable identity
                    // across host JSON parsers.
                    target_position_rad: project_binary64_to_guarded_canonical_number_v1(target)?,
                    target_velocity_rad_s: 0.0,
                    maximum_target_speed_rad_s: maximum_speed,
                    maximum_outer_step_impulse_nms: cap.maximum_outer_step_impulse_nms,
                })
            })
            .collect::<Result<Vec<_>>>()?
    } else {
        Vec::new()
    };
    let command_sha256 = if ordered_commands.is_empty() {
        None
    } else {
        Some(digest_serializable(&ordered_commands)?)
    };
    Ok(RecoveryControlReceiptV1 {
        schema_version: RECOVERY_CONTROL_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        controller_id: request.controller_id.to_owned(),
        controller_profile_sha256: profile_sha256,
        observation_sha256,
        semantic_step: request.semantic_step,
        phase: request.phase,
        phase_step: request.phase_step,
        owner,
        recovery_controller_active: recovery_active,
        stance_handoff_requested: stance_handoff,
        matched_zero_command: matched_zero,
        no_actuation_requested: ordered_commands.is_empty(),
        ordered_commands,
        command_sha256,
        controller_implemented: true,
        deterministic: true,
        engine_identity_input_count: 0,
        engine_specific_policy_branch_count: 0,
        fallback_controller_active: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

pub fn plan_recovery_control_v1(
    request: RecoveryControlRequestV1,
) -> Result<RecoveryControlReceiptV1> {
    if request.schema_version != RECOVERY_CONTROL_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_control_request_version".to_owned(),
        ));
    }
    plan_recovery_control(request, None)
}

pub fn plan_recovery_control_v2(
    request: RecoveryControlRequestV2,
) -> Result<RecoveryControlReceiptV1> {
    if request.schema_version != RECOVERY_CONTROL_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_control_request_version".to_owned(),
        ));
    }
    let morphology_context = request.collection.morphology_context;
    plan_recovery_control(
        RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: request.controller_id,
            phase_step: request.phase_step,
            collection: RecoveryNativeCollectionRequestV1 {
                schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION.to_owned(),
                task_id: request.collection.task_id,
                semantics_id: request.collection.semantics_id,
                actuator_profile_id: request.collection.actuator_profile_id,
                descriptor: request.collection.descriptor,
                adapter_capability: request.collection.adapter_capability,
                runtime_binding: request.collection.runtime_binding,
                arm_kind: request.collection.arm_kind,
                phase: request.collection.phase,
                observation: request.collection.observation,
            },
        },
        Some(&morphology_context),
    )
}

pub fn plan_recovery_control_v3(
    request: RecoveryControlRequestV3,
) -> Result<RecoveryControlReceiptV1> {
    if request.schema_version != RECOVERY_CONTROL_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_control_request_version".to_owned(),
        ));
    }
    let plan_context = RecoveryControlPlanContext {
        controller_id: &request.controller_id,
        phase_step: request.phase_step,
        descriptor: &request.collection.descriptor,
        arm_kind: request.collection.arm_kind,
        phase: request.collection.phase,
        semantic_step: request.collection.observation.semantic_step,
        ordered_joint_observations: &request.collection.observation.state.ordered_joint_observations,
        base_orientation: request.collection.observation.state.base_pose_world.orientation_xyzw,
    };
    let profile = match recovery_development_profile_for_controller(&request.controller_id) {
        Some(profile) => profile,
        None => {
            let profile_sha256 = digest_serializable(&recovery_development_profile_v1())?;
            return Ok(controller_refusal(
                &plan_context,
                RecoverySupportStatusV1::UnsupportedProfile,
                "recovery_controller_not_registered".to_owned(),
                profile_sha256,
            ));
        }
    };
    let profile_sha256 = digest_serializable(&profile)?;
    if !observation_ownership_matches_requested_controller(
        &request.collection.observation,
        request.collection.arm_kind,
        request.collection.phase,
        &request.controller_id,
    ) {
        return Ok(controller_refusal(
            &plan_context,
            RecoverySupportStatusV1::InvalidObservation,
            "recovery_controller_ownership_mismatch".to_owned(),
            profile_sha256,
        ));
    }
    let collection = collect_native_recovery_observation_v3(request.collection.clone())?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact {
        return Ok(controller_refusal(
            &plan_context,
            collection.support_status,
            collection
                .refusal_reason
                .unwrap_or_else(|| "native_collection_refused".to_owned()),
            profile_sha256,
        ));
    }
    build_recovery_control_receipt(
        &plan_context,
        collection.observation_sha256,
        profile,
        profile_sha256,
    )
}

fn validate_stance_development_progression(
    step: &RecoveryStepReceiptV1,
    observation: &RecoveryObservationV3,
    adapter_capability: &RecoveryAdapterCapabilityV1,
    authority: &RecoveryEnergyPartitionAuthorityV1,
    progression: &RecoveryDevelopmentProgressionReceiptV1,
) -> Result<(String, String, bool)> {
    let authority_sha256 = validate_recovery_energy_partition_authority_v1(
        authority,
        observation,
        adapter_capability,
    )?;
    let classification = step
        .classification
        .as_ref()
        .ok_or_else(|| CoreError::Schema("STANCE_DEVELOPMENT_CLASSIFICATION".to_owned()))?;
    let development_nonenergy_safety_gate = classification.joint_limits_respected
        && classification.actuator_budget_respected
        && classification.maximum_nonfoot_contact_impulse_ns == 0.0
        && classification.no_cheat_gate;
    let development_stance_handoff_gate = authority.development_progression_permitted
        && classification.raised_body_gate
        && development_nonenergy_safety_gate;
    let acceptance_safety_gate =
        classification.safety_gate && authority.exact_balance_safety_authority;
    let development_handoff_authorized = matches!(
        (step.prior_phase, step.next_phase, step.transitioned),
        (
            RecoveryPhaseV1::RaiseBody,
            RecoveryPhaseV1::StanceHandoff,
            true
        )
    ) && development_stance_handoff_gate
        && !acceptance_safety_gate;
    let expected_progression_used = development_handoff_authorized;
    let stable_stance_completion_authorized =
        authority.component_partition_complete && authority.exact_balance_safety_authority;
    let physical_result_authorized = step.physical_result
        && authority.component_partition_complete
        && authority.exact_balance_safety_authority;
    if progression.schema_version != RECOVERY_DEVELOPMENT_PROGRESSION_RECEIPT_V1_VERSION
        || progression.energy_partition_authority_sha256 != authority_sha256
        || progression.authority_profile_id != authority.authority_profile_id
        || progression.component_partition_complete != authority.component_partition_complete
        || progression.exact_balance_safety_authority != authority.exact_balance_safety_authority
        || progression.legacy_safety_gate != classification.safety_gate
        || progression.legacy_stable_stance_gate != classification.stable_stance_gate
        || progression.acceptance_safety_gate != acceptance_safety_gate
        || progression.development_nonenergy_safety_gate != development_nonenergy_safety_gate
        || progression.development_stance_handoff_gate != development_stance_handoff_gate
        || progression.development_progression_permitted
            != authority.development_progression_permitted
        || progression.development_progression_used != expected_progression_used
        || progression.stable_stance_completion_authorized != stable_stance_completion_authorized
        || progression.physical_result_authorized != physical_result_authorized
        || progression.prone_to_standing_claimed
        || progression.physical_acceptance_authority
        || progression.release_authority
        || progression.world_build_count != 0
        || progression.solver_step_count != 0
        || progression.physics_state_modified
    {
        return Err(CoreError::Schema(
            "STANCE_DEVELOPMENT_PROGRESSION_BINDING".to_owned(),
        ));
    }
    Ok((
        authority_sha256,
        digest_serializable(progression)?,
        development_handoff_authorized,
    ))
}

fn build_recovery_stance_control_receipt(
    controller_id: &str,
    descriptor: &BoundedQuadrupedDescriptor,
    arm_kind: RecoveryArmKindV1,
    collection_phase: RecoveryPhaseV1,
    semantic_step: u64,
    step: &RecoveryStepReceiptV1,
    observation_sha256: String,
    development_handoff_authorized: bool,
) -> Result<RecoveryControlReceiptV1> {
    if controller_id != EXACT_S169_STANCE_CONTROLLER_ID {
        return Err(CoreError::Schema("STANCE_CONTROLLER_ID".to_owned()));
    }
    if arm_kind != RecoveryArmKindV1::CandidateCommand {
        return Err(CoreError::Schema("STANCE_CANDIDATE_ARM".to_owned()));
    }
    if step.schema_version != RECOVERY_STEP_RECEIPT_V1_VERSION {
        return Err(CoreError::Schema("STANCE_STEP_SCHEMA".to_owned()));
    }
    if step.support_status != RecoverySupportStatusV1::SupportedExact
        || step.refusal_reason.is_some()
        || !step.post_step_observation_only
    {
        return Err(CoreError::Schema("STANCE_STEP_SUPPORT".to_owned()));
    }
    if step.observation_sha256.as_deref() != Some(observation_sha256.as_str()) {
        return Err(CoreError::Digest(
            "STANCE_STEP_OBSERVATION_BINDING".to_owned(),
        ));
    }

    let memory = step
        .memory
        .as_ref()
        .ok_or_else(|| CoreError::Schema("STANCE_STEP_MEMORY".to_owned()))?;
    let classification = step
        .classification
        .as_ref()
        .ok_or_else(|| CoreError::Schema("STANCE_CLASSIFICATION".to_owned()))?;
    let allowed_edge = matches!(
        (step.prior_phase, step.next_phase, step.transitioned),
        (
            RecoveryPhaseV1::RaiseBody,
            RecoveryPhaseV1::StanceHandoff,
            true
        ) | (
            RecoveryPhaseV1::StanceHandoff,
            RecoveryPhaseV1::StanceDwell,
            true
        ) | (
            RecoveryPhaseV1::StanceDwell,
            RecoveryPhaseV1::StanceDwell,
            false
        )
    );
    if collection_phase != step.prior_phase || memory.phase != step.next_phase || !allowed_edge {
        return Err(CoreError::Schema("STANCE_STEP_EDGE".to_owned()));
    }
    if memory.terminal_failure_code.is_some() {
        return Err(CoreError::Schema("STANCE_TERMINAL_MEMORY".to_owned()));
    }
    if step.prior_phase == RecoveryPhaseV1::RaiseBody
        && (!classification.raised_body_gate
            || (!classification.safety_gate && !development_handoff_authorized))
    {
        return Err(CoreError::Schema("STANCE_HANDOFF_GATES".to_owned()));
    }
    if step.prior_phase == RecoveryPhaseV1::StanceHandoff
        && !classification.exclusive_stance_handoff_gate
    {
        return Err(CoreError::Schema("STANCE_OWNERSHIP_GATE".to_owned()));
    }

    build_base_stance_control_receipt(descriptor, semantic_step, step.next_phase,
        memory.phase_steps_observed, observation_sha256)
}

// Pure stance law after the caller has verified its own task handoff.
// Canonical and partial recovery provide separate typed supervision authority.
fn build_base_stance_control_receipt(
    descriptor: &BoundedQuadrupedDescriptor,
    semantic_step: u64,
    phase: RecoveryPhaseV1,
    phase_step: u32,
    observation_sha256: String,
) -> Result<RecoveryControlReceiptV1> {
    let profile = recovery_development_profile_v1();
    if profile.schema_version != RECOVERY_DEVELOPMENT_PROFILE_V1_VERSION
        || profile.profile_id != "sporespore_qsdk_r24d17_exact_s169_recovery_development_v1"
        || profile.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || profile.actuator_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || profile.physical_execution_authorized
        || profile.physical_acceptance_authority
        || profile.release_authority
    {
        return Err(CoreError::Digest("STANCE_RECOVERY_PROFILE".to_owned()));
    }
    let pose = &profile.stance_pose;
    if pose.pose_id != "exact_s169_zero_joint_stance_pose_v1"
        || pose.ordered_actuator_ids != ORDERED_ACTUATOR_IDS.map(str::to_owned).to_vec()
        || pose.ordered_joint_ids != ORDERED_JOINT_IDS.map(str::to_owned).to_vec()
        || pose.ordered_target_positions_rad != STANCE_TARGETS_RAD
        || pose.maximum_target_speed_rad_s.to_bits() != 0.75_f64.to_bits()
    {
        return Err(CoreError::Digest("STANCE_POSE_IDENTITY".to_owned()));
    }

    let cap_receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
        profile_id: profile.actuator_profile_id.clone(),
        descriptor: descriptor.clone(),
    })?;
    if cap_receipt.support_status != ActuatorCapProfileSupportStatusV1::SupportedExact
        || cap_receipt.profile_sha256.as_deref() != Some(profile.actuator_profile_sha256.as_str())
    {
        return Err(CoreError::Schema("STANCE_CAPS".to_owned()));
    }
    let cap_profile = cap_receipt
        .profile
        .ok_or_else(|| CoreError::Internal("STANCE_CAP_PROFILE".to_owned()))?;
    if cap_profile.ordered_caps.len() != ORDERED_ACTUATOR_IDS.len() {
        return Err(CoreError::Order("STANCE_CAPS".to_owned()));
    }

    let mut ordered_commands = Vec::with_capacity(ORDERED_ACTUATOR_IDS.len());
    for (index, cap) in cap_profile.ordered_caps.into_iter().enumerate() {
        if cap.actuator_id != pose.ordered_actuator_ids[index]
            || cap.joint_id != pose.ordered_joint_ids[index]
            || !cap.maximum_outer_step_impulse_nms.is_finite()
            || cap.maximum_outer_step_impulse_nms <= 0.0
        {
            return Err(CoreError::Order(format!("STANCE_CAP_IDENTITY:{index}")));
        }
        ordered_commands.push(RecoveryControlCommandV1 {
            schema_version: RECOVERY_CONTROL_COMMAND_V1_VERSION.to_owned(),
            actuator_id: cap.actuator_id,
            joint_id: cap.joint_id,
            mode: ActuatorMode::PositionVelocity,
            target_position_rad: pose.ordered_target_positions_rad[index],
            target_velocity_rad_s: 0.0,
            maximum_target_speed_rad_s: pose.maximum_target_speed_rad_s,
            maximum_outer_step_impulse_nms: cap.maximum_outer_step_impulse_nms,
        });
    }

    let source_recovery_profile_sha256 = digest_serializable(&profile)?;
    let controller_profile = json!({
        "schema_version": RECOVERY_STANCE_CONTROLLER_PROFILE_V1_VERSION,
        "controller_id": EXACT_S169_STANCE_CONTROLLER_ID,
        "source_recovery_profile_id": profile.profile_id,
        "source_recovery_profile_sha256": source_recovery_profile_sha256,
        "source_actuator_profile_id": profile.actuator_profile_id,
        "source_actuator_profile_sha256": profile.actuator_profile_sha256,
        "stance_pose": profile.stance_pose,
        "accepted_next_phases": ["stance_handoff", "stance_dwell"],
        "recovery_controller_overlap_permitted": false,
        "engine_identity_input_count": 0,
        "engine_specific_policy_branch_count": 0,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    let command_sha256 = digest_serializable(&ordered_commands)?;
    Ok(RecoveryControlReceiptV1 {
        schema_version: RECOVERY_CONTROL_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
        controller_profile_sha256: digest_json(&controller_profile)?,
        observation_sha256: Some(observation_sha256),
        semantic_step,
        phase: phase,
        phase_step: phase_step,
        owner: RecoveryControllerOwnerV1::Stance,
        recovery_controller_active: false,
        stance_handoff_requested: phase == RecoveryPhaseV1::StanceHandoff,
        matched_zero_command: false,
        no_actuation_requested: false,
        ordered_commands,
        command_sha256: Some(command_sha256),
        controller_implemented: true,
        deterministic: true,
        engine_identity_input_count: 0,
        engine_specific_policy_branch_count: 0,
        fallback_controller_active: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

pub fn plan_recovery_stance_control_v1(
    request: RecoveryStanceControlRequestV1,
) -> Result<RecoveryControlReceiptV1> {
    validate_stance_selection(&request.controller_id, &request.collection.observation)?;
    if request.schema_version != RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION {
        return Err(CoreError::Schema("STANCE_REQUEST_SCHEMA".to_owned()));
    }
    let collection = collect_native_recovery_observation_v1(request.collection.clone())?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact
        || !collection.supplied_native_post_step_observation_validated
    {
        return Err(CoreError::Schema("STANCE_COLLECTION_REFUSED".to_owned()));
    }
    build_recovery_stance_control_receipt(
        &request.controller_id,
        &request.collection.descriptor,
        request.collection.arm_kind,
        request.collection.phase,
        request.collection.observation.semantic_step,
        &request.handoff_or_stance_step,
        collection
            .observation_sha256
            .ok_or_else(|| CoreError::Digest("STANCE_COLLECTION_DIGEST".to_owned()))?,
        false,
    )
}

pub fn plan_recovery_stance_control_v2(
    request: RecoveryStanceControlRequestV2,
) -> Result<RecoveryControlReceiptV1> {
    validate_stance_selection(&request.controller_id, &request.collection.observation)?;
    if request.schema_version != RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION {
        return Err(CoreError::Schema("STANCE_REQUEST_SCHEMA".to_owned()));
    }
    let collection = collect_native_recovery_observation_v2(request.collection.clone())?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact
        || !collection.supplied_native_post_step_observation_validated
    {
        return Err(CoreError::Schema("STANCE_COLLECTION_REFUSED".to_owned()));
    }
    build_recovery_stance_control_receipt(
        &request.controller_id,
        &request.collection.descriptor,
        request.collection.arm_kind,
        request.collection.phase,
        request.collection.observation.semantic_step,
        &request.handoff_or_stance_step,
        collection
            .observation_sha256
            .ok_or_else(|| CoreError::Digest("STANCE_COLLECTION_DIGEST".to_owned()))?,
        false,
    )
}

pub fn plan_recovery_stance_control_v3(
    request: RecoveryStanceControlRequestV3,
) -> Result<RecoveryControlReceiptV1> {
    validate_stance_selection(&request.controller_id, &request.collection.observation)?;
    if request.schema_version != RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION {
        return Err(CoreError::Schema("STANCE_REQUEST_SCHEMA".to_owned()));
    }
    let collection = collect_native_recovery_observation_v3(request.collection.clone())?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact
        || !collection.supplied_native_post_step_observation_validated
    {
        return Err(CoreError::Schema("STANCE_COLLECTION_REFUSED".to_owned()));
    }
    build_recovery_stance_control_receipt(
        &request.controller_id,
        &request.collection.descriptor,
        request.collection.arm_kind,
        request.collection.phase,
        request.collection.observation.semantic_step,
        &request.handoff_or_stance_step,
        collection
            .observation_sha256
            .ok_or_else(|| CoreError::Digest("STANCE_COLLECTION_DIGEST".to_owned()))?,
        false,
    )
}

pub fn plan_recovery_stance_control_v4(
    request: RecoveryStanceControlRequestV4,
) -> Result<RecoveryStanceControlReceiptV2> {
    validate_stance_selection(&request.controller_id, &request.collection.observation)?;
    if request.schema_version != RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION {
        return Err(CoreError::Schema("STANCE_REQUEST_SCHEMA".to_owned()));
    }
    if request.portable_step_observation_v3.schema_version != RECOVERY_OBSERVATION_V3_VERSION {
        return Err(CoreError::Schema(
            "STANCE_STEP_OBSERVATION_V3_SCHEMA".to_owned(),
        ));
    }

    let collection = collect_native_recovery_observation_v3(request.collection.clone())?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact
        || !collection.supplied_native_post_step_observation_validated
    {
        return Err(CoreError::Schema("STANCE_COLLECTION_REFUSED".to_owned()));
    }
    let collection_observation_v2_sha256 = collection
        .observation_sha256
        .ok_or_else(|| CoreError::Digest("STANCE_COLLECTION_DIGEST".to_owned()))?;
    let observation_source_binding_sha256 = collection
        .observation_source_binding_sha256
        .ok_or_else(|| CoreError::Digest("STANCE_COLLECTION_SOURCE_DIGEST".to_owned()))?;
    let portable_step_observation_v3_sha256 =
        digest_serializable(&request.portable_step_observation_v3)?;
    if request.handoff_or_stance_step.observation_sha256.as_deref()
        != Some(portable_step_observation_v3_sha256.as_str())
    {
        return Err(CoreError::Digest(
            "STANCE_STEP_OBSERVATION_V3_BINDING".to_owned(),
        ));
    }

    let collection_observation_base_sha256 =
        recovery_observation_base_sha256(&request.collection.observation)?;
    let portable_step_observation_base_sha256 =
        recovery_observation_base_sha256(&request.portable_step_observation_v3)?;
    if request.collection.observation.semantic_step
        != request.portable_step_observation_v3.semantic_step
        || request
            .collection
            .observation
            .energy_balance
            .source_profile_id
            != request
                .portable_step_observation_v3
                .energy_balance
                .source_profile_id
        || collection_observation_base_sha256 != portable_step_observation_base_sha256
    {
        return Err(CoreError::Digest(
            "STANCE_OBSERVATION_PROJECTION_BINDING".to_owned(),
        ));
    }
    request
        .portable_step_observation_v3
        .validate_energy_balance()
        .map_err(|reason| {
            CoreError::Schema(format!("STANCE_STEP_OBSERVATION_V3_INVALID:{reason}"))
        })?;
    let (
        energy_partition_authority_sha256,
        development_progression_receipt_sha256,
        development_handoff_authorized,
    ) = validate_stance_development_progression(
        &request.handoff_or_stance_step,
        &request.portable_step_observation_v3,
        &request.collection.adapter_capability,
        &request.energy_partition_authority,
        &request.development_progression,
    )?;

    let smooth = candidate_stance_profile(&request.controller_id);
    let mut control_receipt = build_recovery_stance_control_receipt(
        if smooth.is_some() { EXACT_S169_STANCE_CONTROLLER_ID } else { &request.controller_id },
        &request.collection.descriptor,
        request.collection.arm_kind,
        request.collection.phase,
        request.collection.observation.semantic_step,
        &request.handoff_or_stance_step,
        portable_step_observation_v3_sha256.clone(),
        development_handoff_authorized,
    )?;
    apply_candidate_stance_feedback(&mut control_receipt, &request.controller_id,
        &request.collection.descriptor, &request.collection.observation.state.ordered_joint_observations,
        request.collection.observation.outer_step_duration_s)?;
    Ok(RecoveryStanceControlReceiptV2 {
        schema_version: RECOVERY_STANCE_CONTROL_RECEIPT_V2_VERSION.to_owned(),
        control_receipt,
        observation_binding: RecoveryStanceObservationBindingReceiptV1 {
            schema_version: RECOVERY_STANCE_OBSERVATION_BINDING_RECEIPT_V1_VERSION.to_owned(),
            collection_observation_v2_sha256,
            portable_step_observation_v3_sha256,
            shared_observation_base_sha256: collection_observation_base_sha256,
            observation_source_binding_sha256,
            energy_partition_authority_sha256,
            development_progression_receipt_sha256,
            semantic_step: request.collection.observation.semantic_step,
            source_bound_v2_collection_validated: true,
            portable_step_v3_validated: true,
            cross_representation_base_binding_validated: true,
            development_progression_validated: true,
            development_handoff_authorized,
            model_construction_count: 0,
            world_attempt_count: 0,
            world_build_count: 0,
            solver_step_count: 0,
            physics_state_modified: false,
            physical_acceptance_authority: false,
            release_authority: false,
        },
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

// Exact shared V2-V7 feedback arithmetic; this helper has no task authority.
fn apply_candidate_stance_feedback(
    control_receipt: &mut RecoveryControlReceiptV1,
    controller_id: &str,
    descriptor: &BoundedQuadrupedDescriptor,
    joints: &[JointObservation],
    dt: f64,
) -> Result<()> {
    if let Some(profile) = candidate_stance_profile(controller_id) {
        let goals = candidate_stance_goals_for_control_step(profile, descriptor,
            control_receipt.phase, control_receipt.phase_step)?;
        let velocity_damping = candidate_stance_velocity_damping(profile)?;
        let response_time_s = profile["response_time_s"].as_f64().unwrap();
        if !response_time_s.is_finite() || response_time_s < dt {
            return Err(CoreError::Schema("STANCE_RESPONSE_TIME".to_owned()));
        }
        for ((index, command), joint) in control_receipt.ordered_commands.iter_mut().enumerate()
            .zip(joints) {
            let measured = joint.position_rad.ok_or_else(|| CoreError::Schema("STANCE_MEASURED_POSITION".to_owned()))?;
            if joint.joint_id != command.joint_id || !joint.validity.position || !measured.is_finite() {
                return Err(CoreError::Schema("STANCE_MEASURED_POSITION".to_owned()));
            }
            let mut speed = (goals[index] - measured) / response_time_s;
            if let Some(gain) = velocity_damping {
                let velocity = joint.velocity_rad_s
                    .filter(|value| joint.validity.velocity && value.is_finite())
                    .ok_or_else(|| CoreError::Schema("STANCE_MEASURED_VELOCITY".to_owned()))?;
                // Oppose measured motion; the native motor still owns force
                // realization under the same published speed and impulse caps.
                speed -= gain * velocity;
            }
            let speed = speed.clamp(-command.maximum_target_speed_rad_s, command.maximum_target_speed_rad_s);
            command.target_position_rad = project_binary64_to_guarded_canonical_number_v1(measured + dt * speed)?;
        }
        control_receipt.controller_id = controller_id.to_owned();
        control_receipt.controller_profile_sha256 = digest_json(&json!({
            "source_stance_profile_sha256": control_receipt.controller_profile_sha256,
            "candidate_stance_profile": profile,
        }))?;
        control_receipt.command_sha256 = Some(digest_serializable(&control_receipt.ordered_commands)?);
    }
    Ok(())
}

fn plan_recovery_control(
    request: RecoveryControlRequestV1,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<RecoveryControlReceiptV1> {
    let plan_context = RecoveryControlPlanContext {
        controller_id: &request.controller_id,
        phase_step: request.phase_step,
        descriptor: &request.collection.descriptor,
        arm_kind: request.collection.arm_kind,
        phase: request.collection.phase,
        semantic_step: request.collection.observation.semantic_step,
        ordered_joint_observations: &request.collection.observation.state.ordered_joint_observations,
        base_orientation: request.collection.observation.state.base_pose_world.orientation_xyzw,
    };
    let profile = match recovery_development_profile_for_controller(&request.controller_id) {
        Some(profile) => profile,
        None => {
            let profile_sha256 = digest_serializable(&recovery_development_profile_v1())?;
            return Ok(controller_refusal(
                &plan_context,
                RecoverySupportStatusV1::UnsupportedProfile,
                "recovery_controller_not_registered".to_owned(),
                profile_sha256,
            ));
        }
    };
    let profile_sha256 = digest_serializable(&profile)?;
    if !observation_ownership_matches_requested_controller(
        &request.collection.observation,
        request.collection.arm_kind,
        request.collection.phase,
        &request.controller_id,
    ) {
        return Ok(controller_refusal(
            &plan_context,
            RecoverySupportStatusV1::InvalidObservation,
            "recovery_controller_ownership_mismatch".to_owned(),
            profile_sha256,
        ));
    }
    let collection =
        collect_native_recovery_observation(request.collection.clone(), morphology_context)?;
    if collection.support_status != RecoverySupportStatusV1::SupportedExact {
        return Ok(controller_refusal(
            &plan_context,
            collection.support_status,
            collection
                .refusal_reason
                .unwrap_or_else(|| "native_collection_refused".to_owned()),
            profile_sha256,
        ));
    }
    build_recovery_control_receipt(
        &plan_context,
        collection.observation_sha256,
        profile,
        profile_sha256,
    )
}

#[cfg(test)]
mod tests {
    mod passive_entry_collection_tests;
    mod rearward_fold_control_tests;
    mod coordinated_support_control_tests;
    mod knees_before_lift_control_tests;
    mod matched_foot_reach_control_tests;
    mod measured_pose_rise_control_tests;
    mod support_waypoint_rise_control_tests;
    mod knee_fold_replant_control_tests;
    mod smooth_stance_control_tests;
    mod flexed_stance_control_tests;
    mod damped_stance_control_tests;
    mod world_vertical_support_control_tests;
    mod damped_neutral_stance_control_tests;
    mod ramped_neutral_stance_control_tests;
    mod partial_fall_control_tests;
    mod partial_direct_neutral_control_tests;
    mod partial_pose_geometry_composition_tests;
    mod partial_load_seeking_composition_tests;
    mod partial_downward_rise_composition_tests;
    mod partial_concurrent_load_rise_composition_tests;
    mod partial_hip_recenter_composition_tests;
    mod partial_support_anchored_composition_tests;
    mod partial_progressive_headroom_composition_tests;
    mod partial_native_reference_composition_tests;
    mod upright_recovery_control_tests;
    mod upright_direct_rise_control_tests;
    use std::collections::HashSet;

    use super::*;
    use crate::protocol::{
        ContactObservation, ContactProvenance, JointObservation, JointValidityMask, Pose,
        Quaternion, STATE_FRAME_VERSION, StateFrame, TaskFrame, Twist,
    };
    use crate::r23d60_selected_s169_descriptor;
    use crate::recovery::{
        GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256,
        GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID,
        RECOVERY_ADAPTER_CAPABILITY_V1_VERSION, RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION,
        RECOVERY_STEP_REQUEST_V5_VERSION, RECOVERY_SUPERVISOR_MEMORY_V1_VERSION,
        RecoveryAppliedActuationReceiptV1, RecoveryAppliedActuatorImpulseV1,
        RecoveryBodyClearanceObservationV1, RecoveryCenterOfMassObservationV1,
        RecoveryChannelCapabilityV1, RecoveryChannelSupportV1,
        RecoveryControllerOwnershipReceiptV1, RecoveryEnergyBalanceLedgerV1,
        RecoveryEnergyPartitionAuthorityV1, RecoveryEngineStepIdentityV1,
        RecoveryExternalInterventionLedgerV1, RecoveryFootBearingObservationV1,
        RecoveryObservationChannelV1, RecoveryPoseClassV1, RecoveryPoseClassificationV1,
        RecoveryStepRequestV5, RecoverySupervisorMemoryV1,
        recovery_physical_development_threshold_profile_v1,
        required_recovery_observation_channels_v1, step_recovery_v5,
    };
    use crate::recovery_energy::{
        RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID, RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
        RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID, RecoveryEnergyBalanceLedgerV2,
    };
    use crate::recovery_energy_v3::{
        RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID, RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION,
        RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID, RecoveryEnergyBalanceLedgerV3,
    };
    use crate::recovery_morphology::{
        RecoveryMorphologyDescriptorV1, compile_recovery_morphology_v1,
    };
    use crate::schema::Vec3;

    const SHA_A: &str = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const SHA_B: &str = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const SHA_C: &str = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";

    fn engine_identity(
        engine: RecoveryNativeEngineV1,
    ) -> (&'static str, &'static str, &'static str, &'static str, u32) {
        match engine {
            RecoveryNativeEngineV1::GodotJolt4_7 => (
                "sporespore_godot_jolt_adapter",
                "sporespore_godot_jolt_recovery_observation_capability_v1",
                "4.7-stable",
                GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID,
                1,
            ),
            RecoveryNativeEngineV1::RapierParryNative => (
                "sporespore_rapier3d_adapter",
                "sporespore_rapier_parry_recovery_observation_capability_v1",
                "rapier3d-0.34.0-parry3d-0.29.0",
                RAPIER_NATIVE_RUNTIME_PROFILE_ID,
                1,
            ),
            RecoveryNativeEngineV1::MujocoNative => (
                "sporespore_mujoco_adapter",
                "sporespore_mujoco_native_recovery_observation_capability_v2",
                "3.11.0",
                MUJOCO_NATIVE_RUNTIME_PROFILE_ID,
                5,
            ),
        }
    }

    fn channel(channel: RecoveryObservationChannelV1, index: usize) -> RecoveryChannelCapabilityV1 {
        RecoveryChannelCapabilityV1 {
            channel,
            support: RecoveryChannelSupportV1::SupportedMeasured,
            host_source_ids: vec![format!("native_source_{index}")],
            mapping_rule_id: format!("native_mapping_{index}"),
            source_measurement_only: true,
            synthesized_when_missing: false,
        }
    }

    fn capability(engine: RecoveryNativeEngineV1) -> RecoveryAdapterCapabilityV1 {
        let (adapter_id, mapping_id, engine_version, _, _) = engine_identity(engine);
        RecoveryAdapterCapabilityV1 {
            schema_version: RECOVERY_ADAPTER_CAPABILITY_V1_VERSION.to_owned(),
            adapter_id: adapter_id.to_owned(),
            engine,
            engine_version: engine_version.to_owned(),
            mapping_id: mapping_id.to_owned(),
            native_engine: true,
            ordered_channels: required_recovery_observation_channels_v1()
                .into_iter()
                .enumerate()
                .map(|(index, value)| channel(value, index))
                .collect(),
            host_pose_label_used_for_success: false,
            fallback_control_permitted: false,
            engine_identity_exposed_to_policy: false,
            model_construction_count: 0,
            world_attempt_count: 0,
            world_build_count: 0,
            solver_step_count: 0,
            physics_state_modified: false,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    fn ownership(
        arm: RecoveryArmKindV1,
        phase: RecoveryPhaseV1,
    ) -> RecoveryControllerOwnershipReceiptV1 {
        if arm == RecoveryArmKindV1::MatchedZeroCommand {
            return RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::None,
                recovery_controller_id: None,
                stance_controller_id: None,
                handoff_event_count: 0,
                fallback_controller_active: false,
                source_measurement: true,
            };
        }
        match phase {
            RecoveryPhaseV1::ConfirmProne
            | RecoveryPhaseV1::EstablishDistalSupport
            | RecoveryPhaseV1::RaiseBody => RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::Recovery,
                recovery_controller_id: Some(EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned()),
                stance_controller_id: None,
                handoff_event_count: 0,
                fallback_controller_active: false,
                source_measurement: true,
            },
            RecoveryPhaseV1::StanceHandoff
            | RecoveryPhaseV1::StanceDwell
            | RecoveryPhaseV1::Complete => RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::Stance,
                recovery_controller_id: None,
                stance_controller_id: Some(EXACT_S169_STANCE_CONTROLLER_ID.to_owned()),
                handoff_event_count: 1,
                fallback_controller_active: false,
                source_measurement: true,
            },
            RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {
                RecoveryControllerOwnershipReceiptV1 {
                    owner: RecoveryControllerOwnerV1::None,
                    recovery_controller_id: None,
                    stance_controller_id: None,
                    handoff_event_count: 0,
                    fallback_controller_active: false,
                    source_measurement: true,
                }
            }
        }
    }

    fn native_request(
        engine: RecoveryNativeEngineV1,
        arm: RecoveryArmKindV1,
        phase: RecoveryPhaseV1,
    ) -> RecoveryNativeCollectionRequestV1 {
        let descriptor = r23d60_selected_s169_descriptor();
        let compiled = compile_bounded_quadruped(descriptor.clone()).unwrap();
        let capability = capability(engine);
        let capability_sha256 = digest_serializable(&capability).unwrap();
        let (adapter_id, _, _, runtime_profile_id, native_substeps) = engine_identity(engine);
        let state = StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step: 1,
            sample_time_s: RECOVERY_OUTER_STEP_DURATION_S,
            base_pose_world: Pose {
                position_m: Vec3 {
                    x: 0.0,
                    y: compiled.geometry.initial_torso_center_y_m,
                    z: 0.0,
                },
                orientation_xyzw: Quaternion::IDENTITY,
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
                        adapter_id: adapter_id.to_owned(),
                        engine_contact_ids: vec![format!("{contact_site_id}_native_contact")],
                        aggregation_rule_id: "native_bearing_aggregation_v1".to_owned(),
                        quality: ContactQuality::QualifiedBearing,
                        impulse_source_profile_id: None,
                        impulse_source_kind: None,
                    },
                })
                .collect(),
            previous_applied_actuation: None,
            gravity_world_m_s2: Vec3 {
                x: 0.0,
                y: -9.81,
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
            adapter_capability_sha256: capability_sha256.clone(),
        };
        let observation = RecoveryObservationV1 {
            schema_version: RECOVERY_OBSERVATION_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            semantic_step: 1,
            outer_step_duration_s: RECOVERY_OUTER_STEP_DURATION_S,
            state,
            center_of_mass: RecoveryCenterOfMassObservationV1 {
                position_world_m: Vec3 {
                    x: 0.0,
                    y: compiled.geometry.initial_torso_center_y_m,
                    z: 0.0,
                },
                linear_velocity_world_m_s: Vec3::ZERO,
                source_measurement: true,
            },
            ordered_foot_bearing_observations: compiled
                .morphology
                .ordered_contact_site_ids
                .iter()
                .map(|contact_site_id| RecoveryFootBearingObservationV1 {
                    contact_site_id: contact_site_id.clone(),
                    bearing_normal_impulse_ns: 0.05,
                    ordinary_unilateral_contact: true,
                    source_measurement: true,
                })
                .collect(),
            ordered_body_clearance_observations: compiled
                .morphology
                .ordered_body_ids
                .iter()
                .map(|body_id| RecoveryBodyClearanceObservationV1 {
                    adapter_id: adapter_id.to_owned(),
                    body_id: body_id.clone(),
                    nonfoot_contact_present: false,
                    ventral_surface_contact: false,
                    accumulated_nonfoot_normal_impulse_ns: 0.0,
                    minimum_nonfoot_clearance_m: 0.01,
                    engine_contact_ids: Vec::new(),
                    classification_rule_id: "native_nonfoot_classification_v1".to_owned(),
                    foot_site_contacts_excluded: true,
                    source_measurement: true,
                })
                .collect(),
            applied_actuation: RecoveryAppliedActuationReceiptV1 {
                adapter_id: adapter_id.to_owned(),
                adapter_receipt_sha256: SHA_A.to_owned(),
                source_semantic_step: 1,
                command_id: if arm == RecoveryArmKindV1::MatchedZeroCommand {
                    "matched_zero_command_v1".to_owned()
                } else {
                    "candidate_recovery_command_v1".to_owned()
                },
                command_sha256: SHA_B.to_owned(),
                actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
                actuator_profile_sha256: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
                    .to_owned(),
                zero_command: arm == RecoveryArmKindV1::MatchedZeroCommand,
                ordered_applied_impulses: compiled
                    .morphology
                    .ordered_actuator_ids
                    .iter()
                    .map(|actuator_id| RecoveryAppliedActuatorImpulseV1 {
                        actuator_id: actuator_id.clone(),
                        applied_angular_impulse_nms: 0.0,
                        host_clamped: false,
                    })
                    .collect(),
                source_measurement: true,
            },
            external_interventions: RecoveryExternalInterventionLedgerV1::default(),
            controller_ownership: ownership(arm, phase),
            energy_balance: RecoveryEnergyBalanceLedgerV1 {
                initial_mechanical_energy_j: 20.0,
                current_mechanical_energy_j: 20.0,
                cumulative_applied_actuator_work_j: 0.0,
                cumulative_external_work_j: 0.0,
                cumulative_dissipated_energy_j: 0.0,
                source_measurement: true,
            },
            engine_step_identity: RecoveryEngineStepIdentityV1 {
                schema_version: RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION.to_owned(),
                source_kind: RecoveryObservationSourceKindV1::NativePostStep,
                adapter_id: adapter_id.to_owned(),
                engine,
                capability_sha256: capability_sha256.clone(),
                source_trace_sha256: SHA_C.to_owned(),
                semantic_step: 1,
                host_step_before: 0,
                host_step_after: 1,
                native_solver_substep_count: native_substeps,
                post_step_observation: true,
                engine_identity_exposed_to_policy: false,
            },
        };
        let (collector_id, _, _) = expected_runtime_binding(engine);
        RecoveryNativeCollectionRequestV1 {
            schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            descriptor,
            adapter_capability: capability,
            runtime_binding: RecoveryNativeCollectorBindingV1 {
                schema_version: RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION.to_owned(),
                collector_id: collector_id.to_owned(),
                runtime_profile_id: runtime_profile_id.to_owned(),
                runtime_qualification_sha256: SHA_A.to_owned(),
                capability_sha256,
                exact_runtime_identity_qualified: true,
                native_post_step_only: true,
                source_measurement_only: true,
                missing_value_synthesis_permitted: false,
                engine_identity_exposed_to_controller: false,
            },
            arm_kind: arm,
            phase,
            observation,
        }
    }

    fn native_request_v2(
        engine: RecoveryNativeEngineV1,
        arm: RecoveryArmKindV1,
        phase: RecoveryPhaseV1,
    ) -> RecoveryNativeCollectionRequestV2 {
        let legacy = native_request(engine, arm, phase);
        let receipt = compile_recovery_morphology_v1(
            RecoveryMorphologyDescriptorV1::exact_s169_reference(legacy.descriptor.clone()),
        )
        .unwrap();
        RecoveryNativeCollectionRequestV2 {
            schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION.to_owned(),
            task_id: legacy.task_id,
            semantics_id: legacy.semantics_id,
            actuator_profile_id: legacy.actuator_profile_id,
            descriptor: legacy.descriptor,
            morphology_context: RecoveryMorphologyContextV1 {
                schema_version: crate::recovery::RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION.to_owned(),
                recovery_morphology_id: receipt.recovery_morphology_id,
                recovery_descriptor: receipt.descriptor,
                recovery_descriptor_sha256: receipt.descriptor_sha256,
                base_descriptor_sha256: receipt.base_descriptor_sha256,
                base_morphology_spec_sha256: receipt.base_morphology_spec_sha256,
                recovery_morphology_spec_sha256: receipt.recovery_morphology_spec_sha256,
            },
            adapter_capability: legacy.adapter_capability,
            runtime_binding: legacy.runtime_binding,
            arm_kind: legacy.arm_kind,
            phase: legacy.phase,
            observation: legacy.observation,
        }
    }

    fn native_request_v3_for_phase(
        engine: RecoveryNativeEngineV1,
        phase: RecoveryPhaseV1,
    ) -> RecoveryNativeCollectionRequestV3 {
        let (source_route_id, mapping_profile_id) = match engine {
            RecoveryNativeEngineV1::RapierParryNative => (
                RAPIER_R24D48_RECOVERY_ROUTE_ID,
                RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
            ),
            RecoveryNativeEngineV1::GodotJolt4_7 => (
                GODOT_R24D57_RECOVERY_ROUTE_ID,
                GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID,
            ),
            RecoveryNativeEngineV1::MujocoNative => (
                MUJOCO_R24D36_SIGNED_WORK_ROUTE_ID,
                MUJOCO_R24D38_ENERGY_V2_MAPPING_PROFILE_ID,
            ),
        };
        let legacy = native_request_v2(engine, RecoveryArmKindV1::CandidateCommand, phase);
        let RecoveryObservationV1 {
            task_id,
            semantics_id,
            actuator_profile_id,
            semantic_step,
            outer_step_duration_s,
            state,
            center_of_mass,
            ordered_foot_bearing_observations,
            ordered_body_clearance_observations,
            applied_actuation,
            external_interventions,
            controller_ownership,
            energy_balance,
            engine_step_identity,
            ..
        } = legacy.observation;
        let signed_constraint_exchange_j = 0.25;
        let observation = RecoveryObservationV2 {
            schema_version: RECOVERY_OBSERVATION_V2_VERSION.to_owned(),
            task_id,
            semantics_id,
            actuator_profile_id,
            semantic_step,
            outer_step_duration_s,
            state,
            center_of_mass,
            ordered_foot_bearing_observations,
            ordered_body_clearance_observations,
            applied_actuation,
            external_interventions,
            controller_ownership,
            energy_balance: RecoveryEnergyBalanceLedgerV2 {
                schema_version: RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION.to_owned(),
                equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID.to_owned(),
                component_partition_id: RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID.to_owned(),
                source_profile_id: mapping_profile_id.to_owned(),
                source_values_sha256: SHA_C.to_owned(),
                initial_mechanical_energy_j: energy_balance.initial_mechanical_energy_j,
                current_mechanical_energy_j: energy_balance.current_mechanical_energy_j
                    + signed_constraint_exchange_j,
                cumulative_applied_actuator_work_j: energy_balance
                    .cumulative_applied_actuator_work_j,
                cumulative_signed_external_work_j: energy_balance.cumulative_external_work_j,
                cumulative_signed_constraint_exchange_j: signed_constraint_exchange_j,
                cumulative_passive_dissipation_j: energy_balance.cumulative_dissipated_energy_j,
                source_measurement: true,
            },
            engine_step_identity,
        };
        let observation_source_binding = bind_recovery_observation_v2_source_v1(
            &observation,
            &observation.engine_step_identity.adapter_id,
            source_route_id,
            mapping_profile_id,
            SHA_A,
            SHA_B,
        )
        .unwrap();
        RecoveryNativeCollectionRequestV3 {
            schema_version: RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION.to_owned(),
            task_id: legacy.task_id,
            semantics_id: legacy.semantics_id,
            actuator_profile_id: legacy.actuator_profile_id,
            descriptor: legacy.descriptor,
            morphology_context: legacy.morphology_context,
            adapter_capability: legacy.adapter_capability,
            runtime_binding: legacy.runtime_binding,
            arm_kind: legacy.arm_kind,
            phase: legacy.phase,
            observation_source_binding,
            observation,
        }
    }

    fn native_request_v3(engine: RecoveryNativeEngineV1) -> RecoveryNativeCollectionRequestV3 {
        native_request_v3_for_phase(engine, RecoveryPhaseV1::EstablishDistalSupport)
    }

    fn observation_v3_projection(observation: &RecoveryObservationV2) -> RecoveryObservationV3 {
        RecoveryObservationV3 {
            schema_version: RECOVERY_OBSERVATION_V3_VERSION.to_owned(),
            task_id: observation.task_id.clone(),
            semantics_id: observation.semantics_id.clone(),
            actuator_profile_id: observation.actuator_profile_id.clone(),
            semantic_step: observation.semantic_step,
            outer_step_duration_s: observation.outer_step_duration_s,
            state: observation.state.clone(),
            center_of_mass: observation.center_of_mass.clone(),
            ordered_foot_bearing_observations: observation
                .ordered_foot_bearing_observations
                .clone(),
            ordered_body_clearance_observations: observation
                .ordered_body_clearance_observations
                .clone(),
            applied_actuation: observation.applied_actuation.clone(),
            external_interventions: observation.external_interventions.clone(),
            controller_ownership: observation.controller_ownership.clone(),
            energy_balance: RecoveryEnergyBalanceLedgerV3 {
                schema_version: RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION.to_owned(),
                equation_id: RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID.to_owned(),
                component_partition_id: RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID.to_owned(),
                source_profile_id: observation.energy_balance.source_profile_id.clone(),
                source_values_sha256: observation.energy_balance.source_values_sha256.clone(),
                initial_mechanical_energy_j: observation.energy_balance.initial_mechanical_energy_j,
                current_mechanical_energy_j: observation.energy_balance.current_mechanical_energy_j,
                cumulative_applied_actuator_work_j: observation
                    .energy_balance
                    .cumulative_applied_actuator_work_j,
                cumulative_signed_external_work_j: observation
                    .energy_balance
                    .cumulative_signed_external_work_j,
                cumulative_signed_constraint_exchange_j: observation
                    .energy_balance
                    .cumulative_signed_constraint_exchange_j,
                cumulative_signed_discrete_staging_exchange_j: 0.0,
                cumulative_passive_dissipation_j: observation
                    .energy_balance
                    .cumulative_passive_dissipation_j,
                source_measurement: observation.energy_balance.source_measurement,
            },
            engine_step_identity: observation.engine_step_identity.clone(),
        }
    }

    fn actual_development_handoff_inputs() -> (
        RecoveryNativeCollectionRequestV3,
        RecoveryObservationV3,
        RecoveryStepReceiptV1,
        RecoveryEnergyPartitionAuthorityV1,
        RecoveryDevelopmentProgressionReceiptV1,
    ) {
        let mut collection = native_request_v3_for_phase(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryPhaseV1::RaiseBody,
        );
        let semantic_step = 40;
        collection.observation.semantic_step = semantic_step;
        collection.observation.state.semantic_step = semantic_step;
        collection.observation.state.sample_time_s =
            semantic_step as f64 * RECOVERY_OUTER_STEP_DURATION_S;
        collection.observation.state.base_pose_world.position_m.y = 0.375;
        collection.observation.center_of_mass.position_world_m.y = 0.375;
        for contact in &mut collection.observation.state.ordered_contact_observations {
            contact.presence = Some(true);
            contact.bears_support = Some(true);
        }
        for foot in &mut collection.observation.ordered_foot_bearing_observations {
            foot.bearing_normal_impulse_ns = 0.125;
        }
        for body in &mut collection.observation.ordered_body_clearance_observations {
            body.nonfoot_contact_present = false;
            body.ventral_surface_contact = false;
            body.accumulated_nonfoot_normal_impulse_ns = 0.0;
            body.minimum_nonfoot_clearance_m = 0.0625;
            body.engine_contact_ids.clear();
        }
        collection
            .observation
            .applied_actuation
            .source_semantic_step = semantic_step;
        collection.observation.engine_step_identity.semantic_step = semantic_step;
        collection.observation.engine_step_identity.host_step_before = semantic_step - 1;
        collection.observation.engine_step_identity.host_step_after = semantic_step;

        let producer_adapter_id = collection
            .observation
            .engine_step_identity
            .adapter_id
            .clone();
        let source_route_id = collection
            .observation_source_binding
            .source_route_id
            .clone();
        let mapping_profile_id = collection
            .observation_source_binding
            .mapping_profile_id
            .clone();
        collection.observation_source_binding = bind_recovery_observation_v2_source_v1(
            &collection.observation,
            &producer_adapter_id,
            &source_route_id,
            &mapping_profile_id,
            SHA_A,
            SHA_B,
        )
        .unwrap();

        let mut portable_step_observation_v3 = observation_v3_projection(&collection.observation);
        portable_step_observation_v3
            .energy_balance
            .current_mechanical_energy_j += 1.0;

        let initialization = initialize_recovery_v2(RecoveryInitializeRequestV2 {
            schema_version: crate::recovery::RECOVERY_INITIALIZE_REQUEST_V2_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: collection.descriptor.clone(),
            morphology_context: collection.morphology_context.clone(),
            adapter_capability: collection.adapter_capability.clone(),
            arm_kind: RecoveryArmKindV1::CandidateCommand,
        })
        .unwrap();
        let mut memory = initialization.memory.unwrap();
        memory.phase = RecoveryPhaseV1::RaiseBody;
        memory.ordered_completed_phases = vec![
            RecoveryPhaseV1::ConfirmProne,
            RecoveryPhaseV1::EstablishDistalSupport,
        ];
        memory.start_semantic_step = Some(0);
        memory.last_semantic_step = Some(semantic_step - 1);
        memory.total_steps_observed = semantic_step as u32;
        memory.phase_steps_observed = 0;
        memory.prone_confirm_steps_observed =
            recovery_physical_development_threshold_profile_v1().entry_prone_confirm_steps;
        memory.stance_dwell_steps_observed = 0;
        memory.initial_center_of_mass_height_m = Some(0.125);
        memory.terminal_failure_code = None;

        let authority = RecoveryEnergyPartitionAuthorityV1 {
            schema_version: RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION.to_owned(),
            authority_profile_id:
                GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID.to_owned(),
            authority_source_sha256: GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned(),
            adapter_id: producer_adapter_id,
            engine: RecoveryNativeEngineV1::GodotJolt4_7,
            capability_sha256: portable_step_observation_v3
                .engine_step_identity
                .capability_sha256
                .clone(),
            energy_source_profile_id: portable_step_observation_v3
                .energy_balance
                .source_profile_id
                .clone(),
            component_partition_id: portable_step_observation_v3
                .energy_balance
                .component_partition_id
                .clone(),
            constraint_exchange_partition_complete: false,
            passive_dissipation_partition_complete: false,
            component_partition_complete: false,
            exact_balance_safety_authority: false,
            unclosed_energy_residual_preserved: true,
            residual_balancing_permitted: false,
            development_progression_permitted: true,
            physical_acceptance_authority: false,
            release_authority: false,
        };
        let step = step_recovery_v5(RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: collection.descriptor.clone(),
            morphology_context: collection.morphology_context.clone(),
            adapter_capability: collection.adapter_capability.clone(),
            memory,
            observation: portable_step_observation_v3.clone(),
            energy_partition_authority: authority.clone(),
        })
        .unwrap();
        assert_eq!(step.step.prior_phase, RecoveryPhaseV1::RaiseBody);
        assert_eq!(step.step.next_phase, RecoveryPhaseV1::StanceHandoff);
        assert!(step.step.transitioned);
        assert!(step.development_progression.development_progression_used);
        (
            collection,
            portable_step_observation_v3,
            step.step,
            authority,
            step.development_progression,
        )
    }

    fn stance_step(
        prior_phase: RecoveryPhaseV1,
        next_phase: RecoveryPhaseV1,
        transitioned: bool,
        observation_sha256: String,
    ) -> RecoveryStepReceiptV1 {
        RecoveryStepReceiptV1 {
            schema_version: RECOVERY_STEP_RECEIPT_V1_VERSION.to_owned(),
            support_status: RecoverySupportStatusV1::SupportedExact,
            refusal_reason: None,
            observation_sha256: Some(observation_sha256),
            prior_phase,
            next_phase,
            transitioned,
            classification: Some(RecoveryPoseClassificationV1 {
                pose_class: RecoveryPoseClassV1::StableFourFootStance,
                torso_height_ratio: 0.8,
                torso_up_dot: 0.99,
                center_of_mass_height_gain_m: 0.3,
                all_four_distal_sites_bearing: true,
                minimum_distal_bearing_impulse_ns: 0.05,
                any_nonfoot_contact: false,
                torso_ventral_contact: false,
                minimum_nonfoot_clearance_m: 0.01,
                maximum_nonfoot_contact_impulse_ns: 0.0,
                terminal_linear_speed_m_s: 0.0,
                terminal_angular_speed_rad_s: 0.0,
                energy_balance_residual_j: 0.0,
                joint_limits_respected: true,
                actuator_budget_respected: true,
                intervention_counter_total: 0,
                entry_prone_gate: true,
                distal_support_gate: true,
                raised_body_gate: true,
                exclusive_stance_handoff_gate: prior_phase == RecoveryPhaseV1::StanceHandoff,
                stable_stance_gate: true,
                safety_gate: true,
                no_cheat_gate: true,
                physical_threshold_authority: true,
                physical_result: true,
            }),
            memory: Some(RecoverySupervisorMemoryV1 {
                schema_version: RECOVERY_SUPERVISOR_MEMORY_V1_VERSION.to_owned(),
                task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
                semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
                descriptor_sha256: R23D60_SELECTED_S169_DESCRIPTOR_SHA256.to_owned(),
                morphology_spec_sha256: R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256.to_owned(),
                actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
                actuator_profile_sha256: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
                    .to_owned(),
                capability_sha256: SHA_A.to_owned(),
                threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
                threshold_profile_sha256: SHA_B.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                phase: next_phase,
                ordered_completed_phases: vec![prior_phase],
                start_semantic_step: Some(0),
                last_semantic_step: Some(1),
                total_steps_observed: 1,
                phase_steps_observed: if transitioned { 0 } else { 7 },
                prone_confirm_steps_observed: 12,
                stance_dwell_steps_observed: if prior_phase == RecoveryPhaseV1::StanceDwell {
                    7
                } else {
                    0
                },
                initial_center_of_mass_height_m: Some(0.1),
                terminal_failure_code: None,
                world_build_count: 0,
                solver_step_count: 0,
                physics_state_modified: false,
                physical_acceptance_authority: false,
                release_authority: false,
            }),
            post_step_observation_only: true,
            phase_skip_permitted: false,
            controller_command_emitted: false,
            controller_implemented: true,
            synthetic_canary_semantics_executed: false,
            physical_threshold_authority: true,
            physical_result: true,
            world_build_count: 0,
            solver_step_count: 0,
            physics_state_modified: false,
            prone_to_standing_claimed: false,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    #[test]
    fn prospective_profile_is_finite_scoped_and_separates_held_out_cells() {
        let profile = recovery_development_profile_v1();
        let contract: serde_json::Value = serde_json::from_str(include_str!(
            "../../recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
        ))
        .unwrap();
        assert_eq!(profile.development_cohort.len(), 3);
        assert_eq!(profile.held_out_native_cohort.len(), 9);
        assert!(!profile.physical_execution_authorized);
        assert!(!profile.physical_acceptance_authority);
        assert!(!profile.release_authority);
        assert!(!profile.arbitrary_morphology_claim);
        assert!(!profile.cross_engine_equivalence_claim);
        assert!(!profile.held_out_seed_use_during_development_permitted);
        assert!(profile.thresholds_frozen_before_physical_outcome);
        assert!(!profile.post_outcome_rethresholding_permitted);
        let development = profile
            .development_cohort
            .iter()
            .map(|cell| cell.seed)
            .collect::<HashSet<_>>();
        let held_out = profile
            .held_out_native_cohort
            .iter()
            .map(|cell| cell.seed)
            .collect::<HashSet<_>>();
        assert_eq!(development.len(), 3);
        assert_eq!(held_out.len(), 9);
        assert!(development.is_disjoint(&held_out));
        assert!(profile.thresholds.minimum_com_height_gain_m > 0.0);
        assert!(profile.thresholds.stance_dwell_steps > 0);
        assert!(profile.thresholds.total_timeout_steps > 0);

        let threshold_records = contract["threshold_profile"]["thresholds"]
            .as_array()
            .unwrap();
        let threshold = |id: &str| {
            &threshold_records
                .iter()
                .find(|item| item["threshold_id"] == id)
                .unwrap()["value"]
        };
        assert_eq!(
            threshold("entry_prone_height_ratio_max").as_f64().unwrap(),
            profile.thresholds.entry_prone_height_ratio_max
        );
        assert_eq!(
            threshold("entry_torso_up_dot_max").as_f64().unwrap(),
            profile.thresholds.entry_torso_up_dot_max
        );
        assert_eq!(
            threshold("entry_prone_confirm_steps").as_u64().unwrap(),
            u64::from(profile.thresholds.entry_prone_confirm_steps)
        );
        assert_eq!(
            threshold("entry_initial_state_match_tolerance")
                .as_str()
                .unwrap(),
            profile.initial_state_match_rule
        );
        assert_eq!(
            threshold("distal_bearing_minimum_impulse_ns")
                .as_f64()
                .unwrap(),
            profile.thresholds.distal_bearing_minimum_impulse_ns
        );
        assert_eq!(
            threshold("minimum_com_height_gain_m").as_f64().unwrap(),
            profile.thresholds.minimum_com_height_gain_m
        );
        assert_eq!(
            threshold("stance_height_ratio_min").as_f64().unwrap(),
            profile.thresholds.stance_height_ratio_min
        );
        assert_eq!(
            threshold("stance_torso_up_dot_min").as_f64().unwrap(),
            profile.thresholds.stance_torso_up_dot_min
        );
        assert_eq!(
            threshold("minimum_nonfoot_clearance_m").as_f64().unwrap(),
            profile.thresholds.minimum_nonfoot_clearance_m
        );
        assert_eq!(
            threshold("maximum_forbidden_contact_impulse_ns")
                .as_f64()
                .unwrap(),
            profile.thresholds.maximum_forbidden_contact_impulse_ns
        );
        assert_eq!(
            threshold("maximum_terminal_linear_speed_m_s")
                .as_f64()
                .unwrap(),
            profile.thresholds.maximum_terminal_linear_speed_m_s
        );
        assert_eq!(
            threshold("maximum_terminal_angular_speed_rad_s")
                .as_f64()
                .unwrap(),
            profile.thresholds.maximum_terminal_angular_speed_rad_s
        );
        assert_eq!(
            threshold("stance_dwell_steps").as_u64().unwrap(),
            u64::from(profile.thresholds.stance_dwell_steps)
        );
        let phase_timeouts = threshold("per_phase_timeout_steps");
        assert_eq!(
            phase_timeouts["confirm_prone"].as_u64().unwrap(),
            u64::from(profile.thresholds.confirm_prone_timeout_steps)
        );
        assert_eq!(
            phase_timeouts["establish_distal_support"].as_u64().unwrap(),
            u64::from(profile.thresholds.establish_distal_support_timeout_steps)
        );
        assert_eq!(
            phase_timeouts["raise_body"].as_u64().unwrap(),
            u64::from(profile.thresholds.raise_body_timeout_steps)
        );
        assert_eq!(
            phase_timeouts["stance_handoff"].as_u64().unwrap(),
            u64::from(profile.thresholds.stance_handoff_timeout_steps)
        );
        assert_eq!(
            phase_timeouts["stance_dwell"].as_u64().unwrap(),
            u64::from(profile.thresholds.stance_dwell_timeout_steps)
        );
        assert_eq!(
            threshold("total_timeout_steps").as_u64().unwrap(),
            u64::from(profile.thresholds.total_timeout_steps)
        );
        assert_eq!(
            threshold("maximum_energy_balance_residual_j")
                .as_f64()
                .unwrap(),
            profile.thresholds.maximum_energy_balance_residual_j
        );

        for (actual, declared) in profile.development_cohort.iter().zip(
            contract["cohort_profile"]["development"]["cells"]
                .as_array()
                .unwrap(),
        ) {
            assert_eq!(actual.cell_id, declared["cell_id"].as_str().unwrap());
            assert_eq!(actual.seed, declared["seed"].as_u64().unwrap() as u32);
            assert_eq!(
                actual.seed_derivation_label,
                declared["seed_label"].as_str().unwrap()
            );
            assert_eq!(
                actual.seed_derivation_sha256,
                declared["seed_sha256"].as_str().unwrap()
            );
            assert_eq!(
                actual.initial_state_id,
                declared["initial_state_id"].as_str().unwrap()
            );
            assert_eq!(actual.engine, Some(RecoveryNativeEngineV1::MujocoNative));
        }
        for (actual, declared) in profile.held_out_native_cohort.iter().zip(
            contract["cohort_profile"]["held_out"]["cells"]
                .as_array()
                .unwrap(),
        ) {
            assert_eq!(actual.cell_id, declared["cell_id"].as_str().unwrap());
            assert_eq!(actual.seed, declared["seed"].as_u64().unwrap() as u32);
            assert_eq!(
                actual.seed_derivation_sha256,
                declared["seed_sha256"].as_str().unwrap()
            );
            assert_eq!(
                serde_json::to_value(actual.engine).unwrap(),
                declared["engine"]
            );
        }
    }

    #[test]
    fn all_three_native_identities_collect_and_plan_identical_commands() {
        let mut command_digests = HashSet::new();
        for engine in [
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryNativeEngineV1::MujocoNative,
        ] {
            let request = native_request(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                RecoveryPhaseV1::EstablishDistalSupport,
            );
            let collection = collect_native_recovery_observation_v1(request.clone()).unwrap();
            assert_eq!(
                collection.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert!(collection.native_observation_validation_kernel_implemented);
            assert!(collection.native_adapter_collection_surface_implemented);
            assert!(collection.supplied_native_post_step_observation_validated);
            assert!(!collection.native_runtime_observation_collection_executed);
            assert_eq!(collection.solver_step_count, 0);

            let control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
                phase_step: 0,
                collection: request,
            })
            .unwrap();
            assert_eq!(
                control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(control.ordered_commands.len(), 8);
            assert!(control.recovery_controller_active);
            assert_eq!(control.engine_identity_input_count, 0);
            assert_eq!(control.engine_specific_policy_branch_count, 0);
            assert_eq!(control.solver_step_count, 0);
            command_digests.insert(control.command_sha256.unwrap());
        }
        assert_eq!(command_digests.len(), 1);
    }

    #[test]
    fn complete_active_recovery_population_has_transport_stable_command_identity() {
        let establish_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        let raise_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let mut command_digests = HashSet::new();
        let mut cell_count = 0_u32;

        for (phase_step, collection) in std::iter::once((0, establish_collection))
            .chain((0..=600).map(|phase_step| (phase_step, raise_collection.clone())))
        {
            let control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
                phase_step,
                collection,
            })
            .unwrap();
            assert_eq!(
                control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(control.ordered_commands.len(), 8);

            for command in &control.ordered_commands {
                assert_eq!(
                    command.target_position_rad.to_bits(),
                    project_binary64_to_canonical_number_v1(command.target_position_rad)
                        .unwrap()
                        .to_bits()
                );
                assert_eq!(
                    command.target_position_rad.to_bits(),
                    project_binary64_to_guarded_canonical_number_v1(command.target_position_rad)
                        .unwrap()
                        .to_bits()
                );
            }

            let transported_json = serde_json::to_string(&control.ordered_commands).unwrap();
            let transported_commands: Vec<RecoveryControlCommandV1> =
                serde_json::from_str(&transported_json).unwrap();
            assert_eq!(transported_commands, control.ordered_commands);
            assert_eq!(
                digest_serializable(&transported_commands).unwrap(),
                control.command_sha256.clone().unwrap()
            );
            command_digests.insert(control.command_sha256.unwrap());
            cell_count += 1;
        }

        assert_eq!(cell_count, 602);
        assert_eq!(command_digests.len(), 362);
    }

    #[test]
    fn stance_composer_is_identical_across_v1_v2_and_v3_collection_shapes() {
        let v1_collection = native_request(
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let v1_observation_sha256 = digest_serializable(&v1_collection.observation).unwrap();
        let v1 = plan_recovery_stance_control_v1(RecoveryStanceControlRequestV1 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
                true,
                v1_observation_sha256,
            ),
            collection: v1_collection,
        })
        .unwrap();

        let v2_collection = native_request_v2(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let v2_observation_sha256 = digest_serializable(&v2_collection.observation).unwrap();
        let v2 = plan_recovery_stance_control_v2(RecoveryStanceControlRequestV2 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
                true,
                v2_observation_sha256,
            ),
            collection: v2_collection,
        })
        .unwrap();

        let v3_collection = native_request_v3_for_phase(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryPhaseV1::RaiseBody,
        );
        let v3_observation_sha256 = digest_serializable(&v3_collection.observation).unwrap();
        let v3 = plan_recovery_stance_control_v3(RecoveryStanceControlRequestV3 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
                true,
                v3_observation_sha256,
            ),
            collection: v3_collection,
        })
        .unwrap();

        for receipt in [&v1, &v2, &v3] {
            assert_eq!(
                receipt.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(receipt.controller_id, EXACT_S169_STANCE_CONTROLLER_ID);
            assert_eq!(receipt.phase, RecoveryPhaseV1::StanceHandoff);
            assert_eq!(receipt.owner, RecoveryControllerOwnerV1::Stance);
            assert!(!receipt.recovery_controller_active);
            assert!(receipt.stance_handoff_requested);
            assert!(!receipt.no_actuation_requested);
            assert_eq!(receipt.ordered_commands.len(), 8);
            assert!(
                receipt
                    .ordered_commands
                    .iter()
                    .all(|command| command.target_position_rad == 0.0
                        && command.target_velocity_rad_s == 0.0
                        && command.maximum_target_speed_rad_s == 0.75)
            );
            assert_eq!(receipt.engine_identity_input_count, 0);
            assert_eq!(receipt.engine_specific_policy_branch_count, 0);
            assert_eq!(receipt.model_construction_count, 0);
            assert_eq!(receipt.world_attempt_count, 0);
            assert_eq!(receipt.world_build_count, 0);
            assert_eq!(receipt.solver_step_count, 0);
            assert!(!receipt.physics_state_modified);
            assert!(!receipt.physical_acceptance_authority);
            assert!(!receipt.release_authority);
        }
        assert_eq!(v1.command_sha256, v2.command_sha256);
        assert_eq!(v2.command_sha256, v3.command_sha256);
        assert_eq!(v1.controller_profile_sha256, v2.controller_profile_sha256);
        assert_eq!(v2.controller_profile_sha256, v3.controller_profile_sha256);

        let dwell_collection = native_request(
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::StanceDwell,
        );
        let dwell_observation_sha256 = digest_serializable(&dwell_collection.observation).unwrap();
        let dwell = plan_recovery_stance_control_v1(RecoveryStanceControlRequestV1 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::StanceDwell,
                RecoveryPhaseV1::StanceDwell,
                false,
                dwell_observation_sha256,
            ),
            collection: dwell_collection,
        })
        .unwrap();
        assert_eq!(dwell.phase, RecoveryPhaseV1::StanceDwell);
        assert_eq!(dwell.phase_step, 7);
        assert!(!dwell.stance_handoff_requested);
        assert_eq!(dwell.command_sha256, v1.command_sha256);
    }

    #[test]
    fn stance_v4_binds_v3_step_to_source_bound_v2_projection() {
        let (
            collection,
            portable_step_observation_v3,
            handoff_or_stance_step,
            energy_partition_authority,
            development_progression,
        ) = actual_development_handoff_inputs();
        let portable_step_observation_v3_sha256 =
            digest_serializable(&portable_step_observation_v3).unwrap();
        let receipt = plan_recovery_stance_control_v4(RecoveryStanceControlRequestV4 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step,
            portable_step_observation_v3,
            energy_partition_authority,
            development_progression,
            collection: collection.clone(),
        })
        .unwrap();

        assert_eq!(
            receipt.schema_version,
            RECOVERY_STANCE_CONTROL_RECEIPT_V2_VERSION
        );
        assert_eq!(
            receipt.control_receipt.observation_sha256.as_deref(),
            Some(portable_step_observation_v3_sha256.as_str())
        );
        assert_eq!(
            receipt.observation_binding.schema_version,
            RECOVERY_STANCE_OBSERVATION_BINDING_RECEIPT_V1_VERSION
        );
        assert_eq!(
            receipt.observation_binding.collection_observation_v2_sha256,
            digest_serializable(&collection.observation).unwrap()
        );
        assert_eq!(
            receipt
                .observation_binding
                .portable_step_observation_v3_sha256,
            portable_step_observation_v3_sha256
        );
        assert_eq!(
            receipt.observation_binding.shared_observation_base_sha256,
            recovery_observation_base_sha256(&collection.observation).unwrap()
        );
        assert!(
            receipt
                .observation_binding
                .source_bound_v2_collection_validated
        );
        assert!(receipt.observation_binding.portable_step_v3_validated);
        assert!(
            receipt
                .observation_binding
                .cross_representation_base_binding_validated
        );
        assert!(
            receipt
                .observation_binding
                .development_progression_validated
        );
        assert!(receipt.observation_binding.development_handoff_authorized);
        assert_eq!(
            receipt.control_receipt.owner,
            RecoveryControllerOwnerV1::Stance
        );
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);
    }

    #[test]
    fn stance_v4_fails_closed_on_cross_representation_mutations() {
        let (
            collection,
            portable_step_observation_v3,
            handoff_or_stance_step,
            energy_partition_authority,
            development_progression,
        ) = actual_development_handoff_inputs();
        let base = RecoveryStanceControlRequestV4 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            collection,
            handoff_or_stance_step,
            portable_step_observation_v3,
            energy_partition_authority,
            development_progression,
        };

        let mut wrong_schema = base.clone();
        wrong_schema.portable_step_observation_v3.schema_version =
            RECOVERY_OBSERVATION_V2_VERSION.to_owned();
        assert!(
            plan_recovery_stance_control_v4(wrong_schema)
                .unwrap_err()
                .to_string()
                .contains("STANCE_STEP_OBSERVATION_V3_SCHEMA")
        );

        let mut wrong_step_digest = base.clone();
        wrong_step_digest.handoff_or_stance_step.observation_sha256 = Some(SHA_C.to_owned());
        assert!(
            plan_recovery_stance_control_v4(wrong_step_digest)
                .unwrap_err()
                .to_string()
                .contains("STANCE_STEP_OBSERVATION_V3_BINDING")
        );

        let mut wrong_semantic_step = base.clone();
        wrong_semantic_step
            .portable_step_observation_v3
            .semantic_step += 1;
        wrong_semantic_step
            .handoff_or_stance_step
            .observation_sha256 =
            Some(digest_serializable(&wrong_semantic_step.portable_step_observation_v3).unwrap());
        assert!(
            plan_recovery_stance_control_v4(wrong_semantic_step)
                .unwrap_err()
                .to_string()
                .contains("STANCE_OBSERVATION_PROJECTION_BINDING")
        );

        let mut wrong_progression = base.clone();
        wrong_progression
            .development_progression
            .development_progression_used = false;
        assert!(
            plan_recovery_stance_control_v4(wrong_progression)
                .unwrap_err()
                .to_string()
                .contains("STANCE_DEVELOPMENT_PROGRESSION_BINDING")
        );

        let mut wrong_authority = base.clone();
        wrong_authority
            .energy_partition_authority
            .authority_source_sha256 = SHA_A.to_owned();
        assert!(plan_recovery_stance_control_v4(wrong_authority).is_err());

        let mut wrong_energy_source = base;
        wrong_energy_source
            .portable_step_observation_v3
            .energy_balance
            .source_profile_id = "wrong_source_profile".to_owned();
        wrong_energy_source
            .handoff_or_stance_step
            .observation_sha256 =
            Some(digest_serializable(&wrong_energy_source.portable_step_observation_v3).unwrap());
        assert!(
            plan_recovery_stance_control_v4(wrong_energy_source)
                .unwrap_err()
                .to_string()
                .contains("STANCE_OBSERVATION_PROJECTION_BINDING")
        );
    }

    #[test]
    fn stance_composer_fails_closed_on_handoff_and_ownership_mutations() {
        let collection = native_request(
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let observation_sha256 = digest_serializable(&collection.observation).unwrap();
        let base = RecoveryStanceControlRequestV1 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
                true,
                observation_sha256,
            ),
            collection,
        };

        let mut wrong_controller = base.clone();
        wrong_controller.controller_id = "wrong_controller".to_owned();
        assert!(
            plan_recovery_stance_control_v1(wrong_controller)
                .unwrap_err()
                .to_string()
                .contains("STANCE_CONTROLLER_ID")
        );

        let mut wrong_digest = base.clone();
        wrong_digest.handoff_or_stance_step.observation_sha256 = Some(SHA_C.to_owned());
        assert!(
            plan_recovery_stance_control_v1(wrong_digest)
                .unwrap_err()
                .to_string()
                .contains("STANCE_STEP_OBSERVATION_BINDING")
        );

        let mut skipped_phase = base.clone();
        skipped_phase.handoff_or_stance_step.next_phase = RecoveryPhaseV1::StanceDwell;
        skipped_phase
            .handoff_or_stance_step
            .memory
            .as_mut()
            .unwrap()
            .phase = RecoveryPhaseV1::StanceDwell;
        assert!(
            plan_recovery_stance_control_v1(skipped_phase)
                .unwrap_err()
                .to_string()
                .contains("STANCE_STEP_EDGE")
        );

        let mut missing_gate = base.clone();
        missing_gate
            .handoff_or_stance_step
            .classification
            .as_mut()
            .unwrap()
            .raised_body_gate = false;
        assert!(
            plan_recovery_stance_control_v1(missing_gate)
                .unwrap_err()
                .to_string()
                .contains("STANCE_HANDOFF_GATES")
        );

        let zero_collection = native_request(
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryArmKindV1::MatchedZeroCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let zero_observation_sha256 = digest_serializable(&zero_collection.observation).unwrap();
        let zero = RecoveryStanceControlRequestV1 {
            schema_version: RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_STANCE_CONTROLLER_ID.to_owned(),
            handoff_or_stance_step: stance_step(
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
                true,
                zero_observation_sha256,
            ),
            collection: zero_collection,
        };
        assert!(
            plan_recovery_stance_control_v1(zero)
                .unwrap_err()
                .to_string()
                .contains("STANCE_CANDIDATE_ARM")
        );
    }

    #[test]
    fn v2_native_collection_and_control_require_context_without_changing_v1_shape() {
        let legacy = native_request(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        let mut legacy_json = serde_json::to_value(&legacy).unwrap();
        let object = legacy_json.as_object_mut().unwrap();
        assert!(!object.contains_key("morphology_context"));

        let request = native_request_v2(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        object.insert(
            "morphology_context".to_owned(),
            serde_json::to_value(&request.morphology_context).unwrap(),
        );
        assert!(serde_json::from_value::<RecoveryNativeCollectionRequestV1>(legacy_json).is_err());

        let collection = collect_native_recovery_observation_v2(request.clone()).unwrap();
        assert_eq!(
            collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(collection.supplied_native_post_step_observation_validated);
        let control = plan_recovery_control_v2(RecoveryControlRequestV2 {
            schema_version: RECOVERY_CONTROL_REQUEST_V2_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: request,
        })
        .unwrap();
        assert_eq!(
            control.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(control.ordered_commands.len(), 8);
        assert_eq!(control.engine_specific_policy_branch_count, 0);
        assert_eq!(control.world_build_count, 0);
        assert_eq!(control.solver_step_count, 0);
    }

    #[test]
    fn observation_v2_collection_binds_qualified_native_mappings_and_refuses_mutations() {
        let request = native_request_v3(RecoveryNativeEngineV1::MujocoNative);
        let collection = collect_native_recovery_observation_v3(request.clone()).unwrap();
        assert_eq!(
            collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(collection.supplied_native_post_step_observation_validated);
        assert!(collection.observation_source_binding_sha256.is_some());
        assert_eq!(collection.model_construction_count, 0);
        assert_eq!(collection.world_attempt_count, 0);
        assert_eq!(collection.world_build_count, 0);
        assert_eq!(collection.solver_step_count, 0);
        assert!(!collection.physics_state_modified);

        let control = plan_recovery_control_v3(RecoveryControlRequestV3 {
            schema_version: RECOVERY_CONTROL_REQUEST_V3_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: request.clone(),
        })
        .unwrap();
        assert_eq!(
            control.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(control.ordered_commands.len(), 8);
        assert_eq!(control.engine_specific_policy_branch_count, 0);
        assert_eq!(control.solver_step_count, 0);

        let rapier = native_request_v3(RecoveryNativeEngineV1::RapierParryNative);
        let rapier_collection = collect_native_recovery_observation_v3(rapier.clone()).unwrap();
        assert_eq!(
            rapier_collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(rapier_collection.supplied_native_post_step_observation_validated);
        assert!(recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::RapierParryNative,
            RAPIER_ADAPTER_ID,
            RAPIER_R24D48_RECOVERY_ROUTE_ID,
            RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID,
        ));
        for (field, mut mutation) in [
            ("route", rapier.clone()),
            ("mapping", rapier.clone()),
            ("adapter", rapier.clone()),
        ] {
            match field {
                "route" => {
                    mutation.observation_source_binding.source_route_id =
                        "mutated_route".to_owned();
                }
                "mapping" => {
                    mutation.observation_source_binding.mapping_profile_id =
                        "mutated_mapping".to_owned();
                }
                "adapter" => {
                    mutation.observation_source_binding.producer_adapter_id =
                        "mutated_adapter".to_owned();
                }
                _ => unreachable!(),
            }
            let refusal = collect_native_recovery_observation_v3(mutation).unwrap();
            assert_eq!(
                refusal.support_status,
                RecoverySupportStatusV1::InvalidObservation,
                "Rapier {field} mutation must refuse",
            );
            assert_eq!(
                refusal.refusal_reason.as_deref(),
                Some("observation_v2_source_identity_invalid"),
                "Rapier {field} mutation must fail at source identity",
            );
        }
        let rapier_control = plan_recovery_control_v3(RecoveryControlRequestV3 {
            schema_version: RECOVERY_CONTROL_REQUEST_V3_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: rapier,
        })
        .unwrap();
        assert_eq!(
            rapier_control.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(rapier_control.engine_specific_policy_branch_count, 0);
        assert_eq!(rapier_control.solver_step_count, 0);

        let mut streaming = request.clone();
        streaming.observation.energy_balance.source_profile_id =
            MUJOCO_R24D42_STREAMING_ENERGY_V2_MAPPING_PROFILE_ID.to_owned();
        streaming.observation_source_binding.mapping_profile_id =
            MUJOCO_R24D42_STREAMING_ENERGY_V2_MAPPING_PROFILE_ID.to_owned();
        streaming.observation_source_binding.ledger_sha256 =
            digest_serializable(&streaming.observation.energy_balance).unwrap();
        streaming
            .observation_source_binding
            .portable_observation_sha256 = digest_serializable(&streaming.observation).unwrap();
        streaming.observation_source_binding.source_chain_sha256 = streaming
            .observation_source_binding
            .source_chain_sha256()
            .unwrap();
        let streaming_collection =
            collect_native_recovery_observation_v3(streaming.clone()).unwrap();
        assert_eq!(
            streaming_collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(streaming_collection.supplied_native_post_step_observation_validated);
        assert_eq!(streaming_collection.solver_step_count, 0);

        let mut crossed_profiles = streaming;
        crossed_profiles
            .observation
            .energy_balance
            .source_profile_id = MUJOCO_R24D38_ENERGY_V2_MAPPING_PROFILE_ID.to_owned();
        crossed_profiles.observation_source_binding.ledger_sha256 =
            digest_serializable(&crossed_profiles.observation.energy_balance).unwrap();
        crossed_profiles
            .observation_source_binding
            .portable_observation_sha256 =
            digest_serializable(&crossed_profiles.observation).unwrap();
        crossed_profiles
            .observation_source_binding
            .source_chain_sha256 = crossed_profiles
            .observation_source_binding
            .source_chain_sha256()
            .unwrap();
        let crossed_refusal = collect_native_recovery_observation_v3(crossed_profiles).unwrap();
        assert_eq!(
            crossed_refusal.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_refusal.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );

        let mut mutated = request;
        mutated
            .observation_source_binding
            .portable_observation_sha256 = SHA_A.to_owned();
        let refusal = collect_native_recovery_observation_v3(mutated).unwrap();
        assert_eq!(
            refusal.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            refusal.refusal_reason.as_deref(),
            Some("observation_v2_source_binding_mismatch")
        );

        let godot = native_request_v3(RecoveryNativeEngineV1::GodotJolt4_7);
        let godot_collection = collect_native_recovery_observation_v3(godot.clone()).unwrap();
        assert_eq!(
            godot_collection.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(godot_collection.supplied_native_post_step_observation_validated);
        assert!(recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::GodotJolt4_7,
            GODOT_ADAPTER_ID,
            GODOT_R24D57_RECOVERY_ROUTE_ID,
            GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID,
        ));

        let mut wrong_godot_route = godot;
        wrong_godot_route.observation_source_binding.source_route_id =
            "mutated_godot_route".to_owned();
        let godot_refusal = collect_native_recovery_observation_v3(wrong_godot_route).unwrap();
        assert_eq!(
            godot_refusal.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            godot_refusal.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );
    }

    #[test]
    fn controller_keeps_zero_and_handoff_arms_actuation_free() {
        let zero = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: native_request(
                RecoveryNativeEngineV1::MujocoNative,
                RecoveryArmKindV1::MatchedZeroCommand,
                RecoveryPhaseV1::RaiseBody,
            ),
        })
        .unwrap();
        assert_eq!(zero.support_status, RecoverySupportStatusV1::SupportedExact);
        assert!(zero.matched_zero_command);
        assert!(zero.no_actuation_requested);
        assert!(zero.ordered_commands.is_empty());

        let handoff = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: native_request(
                RecoveryNativeEngineV1::RapierParryNative,
                RecoveryArmKindV1::CandidateCommand,
                RecoveryPhaseV1::StanceHandoff,
            ),
        })
        .unwrap();
        assert_eq!(
            handoff.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(handoff.stance_handoff_requested);
        assert!(handoff.no_actuation_requested);
        assert!(handoff.ordered_commands.is_empty());
    }

    #[test]
    fn r24d136_godot_runtime_and_source_bindings_are_additive_and_pair_exact() {
        let request = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );
        let capability_sha256 = request.runtime_binding.capability_sha256.clone();
        assert!(
            validate_binding(
                &request.runtime_binding,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            )
            .is_ok()
        );

        let mut complete = request.runtime_binding.clone();
        complete.collector_id = GODOT_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        complete.runtime_profile_id = GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
        assert!(
            validate_binding(
                &complete,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            )
            .is_ok()
        );

        let mut crossed = complete.clone();
        crossed.collector_id = GODOT_COLLECTOR_ID.to_owned();
        assert_eq!(
            validate_binding(
                &crossed,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            ),
            Err("collector_or_runtime_profile_identity_invalid".to_owned())
        );
        crossed = request.runtime_binding.clone();
        crossed.collector_id = GODOT_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        assert_eq!(
            validate_binding(
                &crossed,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            ),
            Err("collector_or_runtime_profile_identity_invalid".to_owned())
        );

        assert!(recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::GodotJolt4_7,
            GODOT_ADAPTER_ID,
            GODOT_R24D136_RECOVERY_ROUTE_ID,
            GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID,
        ));
        assert!(!recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::GodotJolt4_7,
            GODOT_ADAPTER_ID,
            GODOT_R24D136_RECOVERY_ROUTE_ID,
            GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID,
        ));
        assert!(!recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::GodotJolt4_7,
            GODOT_ADAPTER_ID,
            GODOT_R24D57_RECOVERY_ROUTE_ID,
            GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID,
        ));

        let source_request = native_request_v3(RecoveryNativeEngineV1::GodotJolt4_7);
        let retained_source = source_request.observation_source_binding.clone();
        assert!(
            recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &source_request.runtime_binding,
                &retained_source,
            )
        );
        let mut complete_source = retained_source.clone();
        complete_source.source_route_id = GODOT_R24D136_RECOVERY_ROUTE_ID.to_owned();
        complete_source.mapping_profile_id = GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID.to_owned();
        assert!(
            recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &complete,
                &complete_source,
            )
        );
        assert!(
            !recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &source_request.runtime_binding,
                &complete_source,
            )
        );
        assert!(
            !recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &complete,
                &retained_source,
            )
        );
    }

    #[test]
    fn r24d144_godot_solver_coupled_complete_energy_binding_is_pair_exact() {
        let mut request = native_request_v3(RecoveryNativeEngineV1::GodotJolt4_7);
        let capability_sha256 = request.runtime_binding.capability_sha256.clone();
        request.runtime_binding.collector_id =
            GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        request.runtime_binding.runtime_profile_id =
            GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
        request.observation_source_binding.source_route_id =
            GODOT_R24D144_RECOVERY_ROUTE_ID.to_owned();
        request.observation_source_binding.mapping_profile_id =
            GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID.to_owned();

        assert!(
            validate_binding(
                &request.runtime_binding,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            )
            .is_ok()
        );
        assert!(recovery_observation_v2_source_identity_supported_v1(
            RecoveryNativeEngineV1::GodotJolt4_7,
            GODOT_ADAPTER_ID,
            GODOT_R24D144_RECOVERY_ROUTE_ID,
            GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID,
        ));
        assert!(
            recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &request.runtime_binding,
                &request.observation_source_binding,
            )
        );

        let mut crossed_runtime = request.runtime_binding.clone();
        crossed_runtime.collector_id = GODOT_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        assert!(
            !recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &crossed_runtime,
                &request.observation_source_binding,
            )
        );

        let mut crossed_source = request.observation_source_binding.clone();
        crossed_source.mapping_profile_id = GODOT_R24D136_ENERGY_MAPPING_PROFILE_ID.to_owned();
        assert!(
            !recovery_observation_v2_source_identity_matches_runtime_binding_v1(
                RecoveryNativeEngineV1::GodotJolt4_7,
                &request.runtime_binding,
                &crossed_source,
            )
        );

        crossed_runtime = request.runtime_binding.clone();
        crossed_runtime.runtime_profile_id = GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID.to_owned();
        assert_eq!(
            validate_binding(
                &crossed_runtime,
                RecoveryNativeEngineV1::GodotJolt4_7,
                &capability_sha256,
            ),
            Err("collector_or_runtime_profile_identity_invalid".to_owned())
        );
    }

    #[test]
    fn r24d150_godot_discrete_staging_binding_reaches_production_collection() {
        let mut request = native_request_v3(RecoveryNativeEngineV1::GodotJolt4_7);
        request.runtime_binding.collector_id =
            GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        request.runtime_binding.runtime_profile_id =
            GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
        request.observation.energy_balance.source_profile_id =
            GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID.to_owned();
        request.observation_source_binding = bind_recovery_observation_v2_source_v1(
            &request.observation,
            GODOT_ADAPTER_ID,
            GODOT_R24D148_RECOVERY_ROUTE_ID,
            GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID,
            SHA_A,
            SHA_B,
        )
        .unwrap();

        let receipt = collect_native_recovery_observation_v3(request.clone()).unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(receipt.refusal_reason, None);
        assert!(receipt.supplied_native_post_step_observation_validated);
        assert_eq!(receipt.model_construction_count, 0);
        assert_eq!(receipt.world_attempt_count, 0);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);

        let mut crossed_collector = request.clone();
        crossed_collector.runtime_binding.collector_id =
            GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        let crossed_collector_receipt =
            collect_native_recovery_observation_v3(crossed_collector).unwrap();
        assert_eq!(
            crossed_collector_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_collector_receipt.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );

        let mut crossed_route = request.clone();
        crossed_route.observation_source_binding.source_route_id =
            GODOT_R24D144_RECOVERY_ROUTE_ID.to_owned();
        let crossed_route_receipt = collect_native_recovery_observation_v3(crossed_route).unwrap();
        assert_eq!(
            crossed_route_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_route_receipt.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );

        let mut crossed_mapping = request.clone();
        crossed_mapping
            .observation_source_binding
            .mapping_profile_id = GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID.to_owned();
        let crossed_mapping_receipt =
            collect_native_recovery_observation_v3(crossed_mapping).unwrap();
        assert_eq!(
            crossed_mapping_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_mapping_receipt.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );

        let mut crossed_runtime = request;
        crossed_runtime.runtime_binding.runtime_profile_id =
            GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID.to_owned();
        let crossed_runtime_receipt =
            collect_native_recovery_observation_v3(crossed_runtime).unwrap();
        assert_eq!(
            crossed_runtime_receipt.support_status,
            RecoverySupportStatusV1::UnsupportedCapability
        );
        assert_eq!(
            crossed_runtime_receipt.refusal_reason.as_deref(),
            Some("collector_or_runtime_profile_identity_invalid")
        );
    }

    #[test]
    fn r24d163_godot_rotation_aware_binding_reaches_production_collection() {
        let mut request = native_request_v3(RecoveryNativeEngineV1::GodotJolt4_7);
        request.runtime_binding.collector_id =
            GODOT_ROTATION_AWARE_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        request.runtime_binding.runtime_profile_id =
            GODOT_ROTATION_AWARE_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
        request.observation.energy_balance.source_profile_id =
            GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID.to_owned();
        request.observation_source_binding = bind_recovery_observation_v2_source_v1(
            &request.observation,
            GODOT_ADAPTER_ID,
            GODOT_R24D148_RECOVERY_ROUTE_ID,
            GODOT_R24D148_ENERGY_MAPPING_PROFILE_ID,
            SHA_A,
            SHA_B,
        )
        .unwrap();

        let receipt = collect_native_recovery_observation_v3(request.clone()).unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(receipt.refusal_reason, None);
        assert!(receipt.supplied_native_post_step_observation_validated);
        assert_eq!(receipt.model_construction_count, 0);
        assert_eq!(receipt.world_attempt_count, 0);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);

        let mut crossed_collector = request.clone();
        crossed_collector.runtime_binding.collector_id =
            GODOT_DISCRETE_STAGING_COMPLETE_ENERGY_COLLECTOR_ID.to_owned();
        let crossed_collector_receipt =
            collect_native_recovery_observation_v3(crossed_collector).unwrap();
        assert_eq!(
            crossed_collector_receipt.support_status,
            RecoverySupportStatusV1::UnsupportedCapability
        );
        assert_eq!(
            crossed_collector_receipt.refusal_reason.as_deref(),
            Some("collector_or_runtime_profile_identity_invalid")
        );

        let mut crossed_runtime = request.clone();
        crossed_runtime.runtime_binding.runtime_profile_id =
            GODOT_COMPLETE_ENERGY_RUNTIME_PROFILE_ID.to_owned();
        let crossed_runtime_receipt =
            collect_native_recovery_observation_v3(crossed_runtime).unwrap();
        assert_eq!(
            crossed_runtime_receipt.support_status,
            RecoverySupportStatusV1::UnsupportedCapability
        );
        assert_eq!(
            crossed_runtime_receipt.refusal_reason.as_deref(),
            Some("collector_or_runtime_profile_identity_invalid")
        );

        let mut crossed_route = request.clone();
        crossed_route.observation_source_binding.source_route_id =
            GODOT_R24D144_RECOVERY_ROUTE_ID.to_owned();
        let crossed_route_receipt = collect_native_recovery_observation_v3(crossed_route).unwrap();
        assert_eq!(
            crossed_route_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_route_receipt.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );

        let mut crossed_mapping = request;
        crossed_mapping
            .observation_source_binding
            .mapping_profile_id = GODOT_R24D144_ENERGY_MAPPING_PROFILE_ID.to_owned();
        let crossed_mapping_receipt =
            collect_native_recovery_observation_v3(crossed_mapping).unwrap();
        assert_eq!(
            crossed_mapping_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            crossed_mapping_receipt.refusal_reason.as_deref(),
            Some("observation_v2_source_identity_invalid")
        );
    }

    #[test]
    fn collector_mutations_fail_closed_without_world_side_effects() {
        let base = native_request(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::RaiseBody,
        );

        let mut mutations = Vec::new();
        let mut wrong_runtime = base.clone();
        wrong_runtime.runtime_binding.runtime_profile_id = "wrong_runtime".to_owned();
        mutations.push((
            wrong_runtime,
            RecoverySupportStatusV1::UnsupportedCapability,
        ));

        let mut wrong_digest = base.clone();
        wrong_digest.runtime_binding.capability_sha256 = SHA_B.to_owned();
        mutations.push((wrong_digest, RecoverySupportStatusV1::UnsupportedCapability));

        let mut synthetic = base.clone();
        synthetic.observation.engine_step_identity.source_kind =
            RecoveryObservationSourceKindV1::SyntheticZeroWorldCanary;
        mutations.push((synthetic, RecoverySupportStatusV1::InvalidObservation));

        let mut missing = base.clone();
        missing.observation.center_of_mass.source_measurement = false;
        mutations.push((missing, RecoverySupportStatusV1::InvalidObservation));

        let mut nonfinite_value = base.clone();
        nonfinite_value
            .observation
            .center_of_mass
            .position_world_m
            .y = f64::NAN;
        mutations.push((nonfinite_value, RecoverySupportStatusV1::InvalidObservation));

        let mut intervention = base.clone();
        intervention
            .observation
            .external_interventions
            .root_pose_write_count = 1;
        mutations.push((intervention, RecoverySupportStatusV1::InvalidObservation));

        let mut substeps = base.clone();
        substeps
            .observation
            .engine_step_identity
            .native_solver_substep_count = 1;
        mutations.push((substeps, RecoverySupportStatusV1::InvalidObservation));

        let mut over_budget = base;
        over_budget
            .observation
            .applied_actuation
            .ordered_applied_impulses[0]
            .applied_angular_impulse_nms = f64::MAX;
        mutations.push((over_budget, RecoverySupportStatusV1::InvalidObservation));

        for (request, expected) in mutations {
            let receipt = collect_native_recovery_observation_v1(request).unwrap();
            assert_eq!(receipt.support_status, expected);
            assert!(receipt.refusal_reason.is_some());
            assert_eq!(receipt.world_attempt_count, 0);
            assert_eq!(receipt.world_build_count, 0);
            assert_eq!(receipt.solver_step_count, 0);
            assert!(!receipt.physics_state_modified);
            assert!(!receipt.physical_acceptance_authority);
        }
    }

    #[test]
    fn unregistered_controller_refuses_without_planning_commands() {
        let receipt = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: "unknown_controller".to_owned(),
            phase_step: 0,
            collection: native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                RecoveryPhaseV1::RaiseBody,
            ),
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::UnsupportedProfile
        );
        assert!(receipt.ordered_commands.is_empty());
        assert_eq!(receipt.solver_step_count, 0);
    }

    #[test]
    fn r24d113_controller_v2_changes_only_the_two_front_knee_targets() {
        let historical_profile = recovery_development_profile_v1();
        let successor_profile = recovery_development_profile_v2();
        let mut exact_expected_successor = historical_profile.clone();
        exact_expected_successor.profile_id =
            "sporespore_qsdk_r24d113_exact_s169_recovery_development_v2".to_owned();
        exact_expected_successor.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned();
        exact_expected_successor
            .establish_distal_support_pose
            .pose_id = "exact_s169_distal_support_pose_v2".to_owned();
        exact_expected_successor
            .establish_distal_support_pose
            .ordered_target_positions_rad = ESTABLISH_DISTAL_SUPPORT_TARGETS_V2_RAD.to_vec();
        assert_eq!(successor_profile, exact_expected_successor);

        let historical_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        let historical_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
            phase_step: 0,
            collection: historical_collection.clone(),
        })
        .unwrap();
        assert_eq!(
            historical_control.command_sha256.as_deref(),
            Some("sha256:a3db46122897f379a8e85913bfb8d1b52f795886fd122ec9a99966917e57fd74")
        );
        assert_eq!(
            historical_control
                .ordered_commands
                .iter()
                .map(|command| command.target_position_rad)
                .collect::<Vec<_>>(),
            ESTABLISH_DISTAL_SUPPORT_TARGETS_RAD
        );

        let mismatched = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned(),
            phase_step: 0,
            collection: historical_collection,
        })
        .unwrap();
        assert_eq!(
            mismatched.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            mismatched.refusal_reason.as_deref(),
            Some("recovery_controller_ownership_mismatch")
        );
        assert!(mismatched.ordered_commands.is_empty());

        let mut successor_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        successor_collection
            .observation
            .controller_ownership
            .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned());
        let successor_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned(),
            phase_step: 0,
            collection: successor_collection,
        })
        .unwrap();
        assert_eq!(
            successor_control.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(
            successor_control
                .ordered_commands
                .iter()
                .map(|command| command.target_position_rad)
                .collect::<Vec<_>>(),
            ESTABLISH_DISTAL_SUPPORT_TARGETS_V2_RAD
        );
        assert_ne!(
            successor_control.controller_profile_sha256,
            historical_control.controller_profile_sha256
        );
        assert_ne!(
            successor_control.command_sha256,
            historical_control.command_sha256
        );
        assert_eq!(successor_control.model_construction_count, 0);
        assert_eq!(successor_control.world_attempt_count, 0);
        assert_eq!(successor_control.world_build_count, 0);
        assert_eq!(successor_control.solver_step_count, 0);
        assert!(!successor_control.physics_state_modified);
    }

    #[test]
    fn r24d117_controller_v3_changes_only_support_speed_ceiling() {
        let historical_v1 = recovery_development_profile_v1();
        let historical_v2 = recovery_development_profile_v2();
        let successor_v3 = recovery_development_profile_v3();
        let mut exact_expected_successor = historical_v2.clone();
        exact_expected_successor.profile_id =
            "sporespore_qsdk_r24d117_exact_s169_recovery_development_v3".to_owned();
        exact_expected_successor.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned();
        exact_expected_successor
            .establish_distal_support_pose
            .pose_id = "exact_s169_distal_support_pose_v3".to_owned();
        exact_expected_successor
            .establish_distal_support_pose
            .maximum_target_speed_rad_s = 8.0;
        assert_eq!(successor_v3, exact_expected_successor);
        assert_eq!(
            historical_v2
                .establish_distal_support_pose
                .maximum_target_speed_rad_s,
            1.0
        );
        assert_eq!(
            successor_v3
                .establish_distal_support_pose
                .maximum_target_speed_rad_s,
            8.0
        );
        assert_eq!(
            successor_v3
                .establish_distal_support_pose
                .ordered_target_positions_rad,
            ESTABLISH_DISTAL_SUPPORT_TARGETS_V2_RAD
        );

        let mut v2_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        v2_collection
            .observation
            .controller_ownership
            .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned());
        let v2_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V2_ID.to_owned(),
            phase_step: 0,
            collection: v2_collection.clone(),
        })
        .unwrap();
        let mismatch = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned(),
            phase_step: 0,
            collection: v2_collection,
        })
        .unwrap();
        assert_eq!(
            mismatch.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert_eq!(
            mismatch.refusal_reason.as_deref(),
            Some("recovery_controller_ownership_mismatch")
        );
        assert!(mismatch.ordered_commands.is_empty());

        let mut v3_collection = native_request(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            RecoveryPhaseV1::EstablishDistalSupport,
        );
        v3_collection
            .observation
            .controller_ownership
            .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned());
        let v3_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
            schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
            controller_id: EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned(),
            phase_step: 0,
            collection: v3_collection,
        })
        .unwrap();
        assert_eq!(
            v3_control.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(v2_control.ordered_commands.len(), 8);
        assert_eq!(v3_control.ordered_commands.len(), 8);
        for (v2, v3) in v2_control
            .ordered_commands
            .iter()
            .zip(&v3_control.ordered_commands)
        {
            let mut expected = v2.clone();
            expected.maximum_target_speed_rad_s = 8.0;
            assert_eq!(*v3, expected);
        }
        assert_ne!(
            v3_control.controller_profile_sha256,
            v2_control.controller_profile_sha256
        );
        assert_ne!(v3_control.command_sha256, v2_control.command_sha256);
        assert_eq!(
            v3_control.controller_profile_sha256,
            "sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
        );
        assert_eq!(
            v3_control.command_sha256.as_deref(),
            Some("sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4")
        );
        assert_eq!(historical_v1, recovery_development_profile_v1());
        assert_eq!(historical_v2, recovery_development_profile_v2());
        assert_eq!(v3_control.model_construction_count, 0);
        assert_eq!(v3_control.world_attempt_count, 0);
        assert_eq!(v3_control.world_build_count, 0);
        assert_eq!(v3_control.solver_step_count, 0);
        assert!(!v3_control.physics_state_modified);
    }

    #[test]
    fn r24d120_controller_v4_changes_only_raise_body_speed_ceiling() {
        let historical_v1 = recovery_development_profile_v1();
        let historical_v2 = recovery_development_profile_v2();
        let historical_v3 = recovery_development_profile_v3();
        let successor_v4 = recovery_development_profile_v4();
        let mut exact_expected_successor = historical_v3.clone();
        exact_expected_successor.profile_id =
            "sporespore_qsdk_r24d120_exact_s169_recovery_development_v4".to_owned();
        exact_expected_successor.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned();
        exact_expected_successor.stance_pose.pose_id =
            "exact_s169_zero_joint_stance_pose_v2".to_owned();
        exact_expected_successor
            .stance_pose
            .maximum_target_speed_rad_s = 8.0;
        assert_eq!(successor_v4, exact_expected_successor);
        assert_eq!(
            digest_serializable(&successor_v4).unwrap(),
            "sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900"
        );
        assert_eq!(
            historical_v3.establish_distal_support_pose,
            successor_v4.establish_distal_support_pose
        );
        assert_eq!(
            historical_v3.raise_body_ramp_steps,
            successor_v4.raise_body_ramp_steps
        );
        assert_eq!(historical_v3.stance_pose.maximum_target_speed_rad_s, 0.75);
        assert_eq!(successor_v4.stance_pose.maximum_target_speed_rad_s, 8.0);
        assert_eq!(
            historical_v3.stance_pose.ordered_target_positions_rad,
            successor_v4.stance_pose.ordered_target_positions_rad
        );

        for (phase, phase_step, historical_command_sha256, successor_command_sha256) in [
            (
                RecoveryPhaseV1::EstablishDistalSupport,
                0,
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                0,
                "sha256:c9b643dc31923b9c59389d21a3750e2cd6c800002b9b30faf7631d47823a4b2d",
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                RAISE_BODY_RAMP_STEPS / 2,
                "sha256:32727a1340c791d9c2224c633908018ce113ddef686f0dc755a894b9d168f38f",
                "sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                RAISE_BODY_RAMP_STEPS,
                "sha256:c37b949e24558a92b1656b7b773d63e294152264b35c9f7623674a1eb202e545",
                "sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
            ),
        ] {
            let mut historical_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            historical_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned());
            let historical_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V3_ID.to_owned(),
                phase_step,
                collection: historical_collection,
            })
            .unwrap();

            let mut successor_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            successor_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned());
            let successor_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned(),
                phase_step,
                collection: successor_collection,
            })
            .unwrap();
            assert_eq!(
                historical_control.command_sha256.as_deref(),
                Some(historical_command_sha256)
            );
            assert_eq!(
                successor_control.command_sha256.as_deref(),
                Some(successor_command_sha256)
            );

            assert_eq!(
                historical_control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(
                successor_control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(historical_control.ordered_commands.len(), 8);
            assert_eq!(successor_control.ordered_commands.len(), 8);
            for (historical, successor) in historical_control
                .ordered_commands
                .iter()
                .zip(&successor_control.ordered_commands)
            {
                let mut expected = historical.clone();
                if phase == RecoveryPhaseV1::RaiseBody {
                    expected.maximum_target_speed_rad_s = 8.0;
                }
                assert_eq!(*successor, expected);
            }
            if phase == RecoveryPhaseV1::EstablishDistalSupport {
                assert_eq!(
                    successor_control.command_sha256,
                    historical_control.command_sha256
                );
            } else {
                assert_ne!(
                    successor_control.command_sha256,
                    historical_control.command_sha256
                );
            }
            assert_eq!(successor_control.model_construction_count, 0);
            assert_eq!(successor_control.world_attempt_count, 0);
            assert_eq!(successor_control.world_build_count, 0);
            assert_eq!(successor_control.solver_step_count, 0);
            assert!(!successor_control.physics_state_modified);
        }

        assert_eq!(historical_v1, recovery_development_profile_v1());
        assert_eq!(historical_v2, recovery_development_profile_v2());
        assert_eq!(historical_v3, recovery_development_profile_v3());
    }

    #[test]
    fn r24d123_controller_v5_changes_only_raise_body_speed_ceiling() {
        let historical_v1 = recovery_development_profile_v1();
        let historical_v2 = recovery_development_profile_v2();
        let historical_v3 = recovery_development_profile_v3();
        let historical_v4 = recovery_development_profile_v4();
        let successor_v5 = recovery_development_profile_v5();
        let mut exact_expected_successor = historical_v4.clone();
        exact_expected_successor.profile_id =
            "sporespore_qsdk_r24d123_exact_s169_recovery_development_v5".to_owned();
        exact_expected_successor.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned();
        exact_expected_successor.stance_pose.pose_id =
            "exact_s169_zero_joint_stance_pose_v3".to_owned();
        exact_expected_successor
            .stance_pose
            .maximum_target_speed_rad_s = 22.0;
        assert_eq!(successor_v5, exact_expected_successor);
        assert_eq!(
            digest_serializable(&successor_v5).unwrap(),
            "sha256:fe6beb259550c06e137fc89a5e752d2cfc088edd5f8136cd944c5776a4c34909"
        );
        assert_eq!(
            historical_v4.establish_distal_support_pose,
            successor_v5.establish_distal_support_pose
        );
        assert_eq!(
            historical_v4.raise_body_ramp_steps,
            successor_v5.raise_body_ramp_steps
        );
        assert_eq!(historical_v4.stance_pose.maximum_target_speed_rad_s, 8.0);
        assert_eq!(successor_v5.stance_pose.maximum_target_speed_rad_s, 22.0);
        assert_eq!(
            historical_v4.stance_pose.ordered_target_positions_rad,
            successor_v5.stance_pose.ordered_target_positions_rad
        );

        for (phase, phase_step, historical_command_sha256, successor_command_sha256) in [
            (
                RecoveryPhaseV1::EstablishDistalSupport,
                0,
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                0,
                "sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
                "sha256:ddef8c449c3c02109ae5f23cac0df5627df0513c7d07270f79dd865bd46040bc",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                RAISE_BODY_RAMP_STEPS / 2,
                "sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
                "sha256:6a3bea40b02478ecf05c7baf4a77d27d8b7688cadb6d83b0f441a174b551691d",
            ),
            (
                RecoveryPhaseV1::RaiseBody,
                RAISE_BODY_RAMP_STEPS,
                "sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
                "sha256:c6398659885964de9b154d520c90311f3896881557aa93b4ce90cd1f048a783f",
            ),
        ] {
            let mut historical_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            historical_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned());
            let historical_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V4_ID.to_owned(),
                phase_step,
                collection: historical_collection,
            })
            .unwrap();

            let mut successor_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            successor_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned());
            let successor_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned(),
                phase_step,
                collection: successor_collection,
            })
            .unwrap();
            assert_eq!(
                historical_control.command_sha256.as_deref(),
                Some(historical_command_sha256)
            );
            assert_eq!(
                successor_control.command_sha256.as_deref(),
                Some(successor_command_sha256)
            );

            assert_eq!(
                historical_control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(
                successor_control.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert_eq!(historical_control.ordered_commands.len(), 8);
            assert_eq!(successor_control.ordered_commands.len(), 8);
            for (historical, successor) in historical_control
                .ordered_commands
                .iter()
                .zip(&successor_control.ordered_commands)
            {
                let mut expected = historical.clone();
                if phase == RecoveryPhaseV1::RaiseBody {
                    expected.maximum_target_speed_rad_s = 22.0;
                }
                assert_eq!(*successor, expected);
            }
            if phase == RecoveryPhaseV1::EstablishDistalSupport {
                assert_eq!(
                    successor_control.command_sha256,
                    historical_control.command_sha256
                );
            } else {
                assert_ne!(
                    successor_control.command_sha256,
                    historical_control.command_sha256
                );
            }
            assert_eq!(successor_control.model_construction_count, 0);
            assert_eq!(successor_control.world_attempt_count, 0);
            assert_eq!(successor_control.world_build_count, 0);
            assert_eq!(successor_control.solver_step_count, 0);
            assert!(!successor_control.physics_state_modified);
        }

        assert_eq!(historical_v1, recovery_development_profile_v1());
        assert_eq!(historical_v2, recovery_development_profile_v2());
        assert_eq!(historical_v3, recovery_development_profile_v3());
        assert_eq!(historical_v4, recovery_development_profile_v4());
    }

    #[test]
    fn r24d127_controller_v6_preserves_v5_portable_policy() {
        let historical_v5 = recovery_development_profile_v5();
        let successor_v6 = recovery_development_profile_v6();
        let mut expected_successor = historical_v5.clone();
        expected_successor.profile_id =
            "sporespore_qsdk_r24d127_exact_s169_recovery_development_v6".to_owned();
        expected_successor.controller_id = EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned();
        assert_eq!(successor_v6, expected_successor);
        assert_eq!(
            digest_serializable(&successor_v6).unwrap(),
            "sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33"
        );

        for (phase, phase_step) in [
            (RecoveryPhaseV1::EstablishDistalSupport, 0),
            (RecoveryPhaseV1::RaiseBody, 0),
            (RecoveryPhaseV1::RaiseBody, RAISE_BODY_RAMP_STEPS / 2),
            (RecoveryPhaseV1::RaiseBody, RAISE_BODY_RAMP_STEPS),
        ] {
            let mut historical_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            historical_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned());
            let historical_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V5_ID.to_owned(),
                phase_step,
                collection: historical_collection,
            })
            .unwrap();

            let mut successor_collection = native_request(
                RecoveryNativeEngineV1::GodotJolt4_7,
                RecoveryArmKindV1::CandidateCommand,
                phase,
            );
            successor_collection
                .observation
                .controller_ownership
                .recovery_controller_id = Some(EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned());
            let successor_control = plan_recovery_control_v1(RecoveryControlRequestV1 {
                schema_version: RECOVERY_CONTROL_REQUEST_V1_VERSION.to_owned(),
                controller_id: EXACT_S169_RECOVERY_CONTROLLER_V6_ID.to_owned(),
                phase_step,
                collection: successor_collection,
            })
            .unwrap();

            assert_eq!(
                successor_control.ordered_commands,
                historical_control.ordered_commands
            );
            assert_eq!(
                successor_control.command_sha256,
                historical_control.command_sha256
            );
            assert_ne!(
                successor_control.controller_profile_sha256,
                historical_control.controller_profile_sha256
            );
            assert_eq!(successor_control.model_construction_count, 0);
            assert_eq!(successor_control.world_attempt_count, 0);
            assert_eq!(successor_control.world_build_count, 0);
            assert_eq!(successor_control.solver_step_count, 0);
            assert!(!successor_control.physics_state_modified);
        }
    }
}
