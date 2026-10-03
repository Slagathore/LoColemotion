//! Engine-neutral canonical prone-to-standing observation and supervision.
//!
//! QSDK-R24D2 introduced the zero-world semantics and synthetic canary.  The
//! additive QSDK-R24D18 path also accepts the prospectively frozen exact-s169
//! physical-development profile published by QSDK-R24D17.  Native observations
//! remain fail-closed unless that exact profile is selected.  This module still
//! owns no host object and never constructs or steps a physics world; it only
//! classifies supplied observations, advances the portable phase machine, and
//! evaluates paired traces.

use std::collections::HashSet;

use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::actuator_profile::{
    ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION, ActuatorCapProfileRequestV1,
    ActuatorCapProfileSupportStatusV1, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256, R23D60_SELECTED_S169_DESCRIPTOR_SHA256,
    R23D60_SELECTED_S169_MORPHOLOGY_ID, R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256,
    resolve_actuator_cap_profile_v1,
};
use crate::canonical::{digest_json, digest_serializable};
use crate::protocol::{ContactQuality, StateFrame};
use crate::quadruped::{BoundedQuadrupedDescriptor, CompiledQuadruped, compile_bounded_quadruped};
use crate::recovery_energy::{
    RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V2_VERSION,
    RecoveryEnergyBalanceEvaluationRequestV2, RecoveryEnergyBalanceLedgerV2,
    evaluate_recovery_energy_balance_v2,
};
use crate::recovery_energy_v3::{
    RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION,
    RecoveryEnergyBalanceEvaluationRequestV3, RecoveryEnergyBalanceLedgerV3,
    evaluate_recovery_energy_balance_v3,
};
use crate::recovery_morphology::{
    RecoveryMorphologyDescriptorV1, RecoveryMorphologySupportStatusV1,
    compile_recovery_morphology_v1,
};
use crate::schema::{CompiledMorphology, CoreError, Result, Vec3};

pub mod passive_entry;
pub mod partial_fall;
pub mod upright_recovery;

pub const RECOVERY_ADAPTER_CAPABILITY_V1_VERSION: &str =
    "sporespore_recovery_adapter_capability_v1";
pub const RECOVERY_OBSERVATION_V1_VERSION: &str = "sporespore_recovery_observation_v1";
pub const RECOVERY_OBSERVATION_V2_VERSION: &str = "sporespore_recovery_observation_v2";
pub const RECOVERY_OBSERVATION_V3_VERSION: &str = "sporespore_recovery_observation_v3";
pub const RECOVERY_SUPERVISOR_MEMORY_V1_VERSION: &str = "sporespore_recovery_supervisor_memory_v1";
pub const RECOVERY_INITIALIZE_REQUEST_V1_VERSION: &str =
    "sporespore_recovery_initialize_request_v1";
pub const RECOVERY_INITIALIZE_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_initialize_request_v2";
pub const RECOVERY_INITIALIZE_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_initialize_receipt_v1";
pub const RECOVERY_STEP_REQUEST_V1_VERSION: &str = "sporespore_recovery_step_request_v1";
pub const RECOVERY_STEP_REQUEST_V2_VERSION: &str = "sporespore_recovery_step_request_v2";
pub const RECOVERY_STEP_REQUEST_V3_VERSION: &str = "sporespore_recovery_step_request_v3";
pub const RECOVERY_STEP_REQUEST_V4_VERSION: &str = "sporespore_recovery_step_request_v4";
pub const RECOVERY_STEP_REQUEST_V5_VERSION: &str = "sporespore_recovery_step_request_v5";
pub const RECOVERY_STEP_RECEIPT_V1_VERSION: &str = "sporespore_recovery_step_receipt_v1";
pub const RECOVERY_STEP_RECEIPT_V2_VERSION: &str = "sporespore_recovery_step_receipt_v2";
pub const RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION: &str =
    "sporespore_recovery_energy_partition_authority_v1";
pub const RECOVERY_DEVELOPMENT_PROGRESSION_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_development_progression_receipt_v1";
pub const RECOVERY_TRACE_V1_VERSION: &str = "sporespore_recovery_trace_v1";
pub const RECOVERY_TRACE_V2_VERSION: &str = "sporespore_recovery_trace_v2";
pub const RECOVERY_TRACE_V3_VERSION: &str = "sporespore_recovery_trace_v3";
pub const RECOVERY_EVALUATION_REQUEST_V1_VERSION: &str =
    "sporespore_recovery_evaluation_request_v1";
pub const RECOVERY_EVALUATION_REQUEST_V2_VERSION: &str =
    "sporespore_recovery_evaluation_request_v2";
pub const RECOVERY_EVALUATION_REQUEST_V3_VERSION: &str =
    "sporespore_recovery_evaluation_request_v3";
pub const RECOVERY_EVALUATION_REQUEST_V4_VERSION: &str =
    "sporespore_recovery_evaluation_request_v4";
pub const RECOVERY_EVALUATION_REQUEST_V5_VERSION: &str =
    "sporespore_recovery_evaluation_request_v5";
pub const RECOVERY_EVALUATION_RECEIPT_V1_VERSION: &str =
    "sporespore_recovery_evaluation_receipt_v1";
pub const RECOVERY_SYNTHETIC_THRESHOLD_PROFILE_V1_VERSION: &str =
    "sporespore_recovery_synthetic_threshold_profile_v1";
pub const RECOVERY_PHYSICAL_THRESHOLD_PROFILE_V1_VERSION: &str =
    "sporespore_recovery_physical_threshold_profile_v1";
pub const RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION: &str =
    "sporespore_recovery_engine_step_identity_v1";
pub const RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION: &str =
    "sporespore_recovery_morphology_context_v1";

/// The retained R126 authority profile records the R86 finding; it does not
/// repair, complete, or rebalance the Godot/Jolt energy partition.
pub const GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID: &str =
    "godot_jolt_r24d126_incomplete_energy_partition_authority_v1";
pub const GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256: &str =
    "sha256:da405c692776564d091c4be0e4adf282e720445b0859738b139fc2cdd0c60da6";
pub const GODOT_JOLT_R24D57_ENERGY_SOURCE_PROFILE_ID: &str =
    "godot_jolt_r24d57_native_recovery_energy_mapping_v1";

/// R136's distinct prospective complete-partition profile. Its source digest
/// binds the exact native solver-exchange subset and adapter-side disjointness
/// conditions; it grants exact balance to a matching observation, never
/// physical acceptance or release authority.
pub const GODOT_JOLT_R24D136_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID: &str =
    "godot_jolt_r24d136_complete_energy_partition_authority_v1";
pub const GODOT_JOLT_R24D136_ENERGY_AUTHORITY_SOURCE_SHA256: &str =
    "sha256:b5daccd4d59052820954824dcbb30c3caabb6ff614b8470c4036d77d39670518";
pub const GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID: &str =
    "godot_jolt_r24d136_complete_native_recovery_energy_mapping_v1";

/// R144 preserves R136's complete claim shape while binding the independently
/// versioned solver-coupled native-motor source partition selected by R143.
/// The source digest prevents either complete profile from being manufactured
/// by relabeling the other profile's observation or authority receipt.
pub const GODOT_JOLT_R24D144_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID: &str =
    "godot_jolt_r24d144_solver_coupled_complete_energy_partition_authority_v1";
pub const GODOT_JOLT_R24D144_ENERGY_AUTHORITY_SOURCE_SHA256: &str =
    "sha256:1583fb7c1652104a07a24378ed62bf390215d831b033ea5e2b1c2a2c45644858";
pub const GODOT_JOLT_R24D144_ENERGY_SOURCE_PROFILE_ID: &str =
    "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1";

/// R151 promotes the independently qualified R148 discrete-staging mapping
/// only after the consumed R150 live-route commissioning positive. The new
/// identity keeps the prospective R148 profile immutable while allowing one
/// separately qualified finite behavior successor to use exact-balance gates.
pub const GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_PROFILE_ID: &str =
    "godot_jolt_r24d151_commissioned_discrete_staging_complete_energy_partition_authority_v1";
pub const GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_SOURCE_SHA256: &str =
    "sha256:75e587a17fb599986051b6627f0977d791d041b3f7b15ee5faf19d782641b95c";
pub const GODOT_JOLT_R24D148_DISCRETE_STAGING_ENERGY_SOURCE_PROFILE_ID: &str =
    "godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1";

pub const CANONICAL_PRONE_TO_STANDING_TASK_ID: &str =
    "sporespore_canonical_ventral_prone_to_four_foot_stance_v1";
pub const PORTABLE_RECOVERY_SEMANTICS_ID: &str =
    "sporespore_qsdk_r24d2_portable_recovery_semantics_v1";
pub const SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID: &str =
    "sporespore_qsdk_r24d2_synthetic_zero_world_canary_thresholds_v1";
pub const RECOVERY_OUTER_STEP_HZ: u32 = 120;
pub const RECOVERY_OUTER_STEP_DURATION_S: f64 = 1.0 / RECOVERY_OUTER_STEP_HZ as f64;

const GODOT_ADAPTER_ID: &str = "sporespore_godot_jolt_adapter";
const GODOT_MAPPING_ID: &str = "sporespore_godot_jolt_recovery_observation_capability_v1";
const RAPIER_ADAPTER_ID: &str = "sporespore_rapier3d_adapter";
const RAPIER_MAPPING_ID: &str = "sporespore_rapier_parry_recovery_observation_capability_v1";
const MUJOCO_ADAPTER_ID: &str = "sporespore_mujoco_adapter";
const MUJOCO_MAPPING_ID: &str = "sporespore_mujoco_native_recovery_observation_capability_v2";

const ORDERED_SUCCESS_PHASES: [RecoveryPhaseV1; 6] = [
    RecoveryPhaseV1::ConfirmProne,
    RecoveryPhaseV1::EstablishDistalSupport,
    RecoveryPhaseV1::RaiseBody,
    RecoveryPhaseV1::StanceHandoff,
    RecoveryPhaseV1::StanceDwell,
    RecoveryPhaseV1::Complete,
];

const REQUIRED_CHANNELS: [RecoveryObservationChannelV1; 10] = [
    RecoveryObservationChannelV1::CanonicalBodyPoseAndTwist,
    RecoveryObservationChannelV1::WholeSystemCenterOfMassPositionAndVelocity,
    RecoveryObservationChannelV1::OrderedJointPositionAndVelocity,
    RecoveryObservationChannelV1::OrderedFootBearingContactObservations,
    RecoveryObservationChannelV1::ClassifiedNonfootContactObservations,
    RecoveryObservationChannelV1::AppliedActuationReceipts,
    RecoveryObservationChannelV1::ExternalInterventionLedger,
    RecoveryObservationChannelV1::ControllerOwnershipReceipt,
    RecoveryObservationChannelV1::EnergyBalanceLedger,
    RecoveryObservationChannelV1::EngineStepIdentity,
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryObservationChannelV1 {
    CanonicalBodyPoseAndTwist,
    WholeSystemCenterOfMassPositionAndVelocity,
    OrderedJointPositionAndVelocity,
    OrderedFootBearingContactObservations,
    ClassifiedNonfootContactObservations,
    AppliedActuationReceipts,
    ExternalInterventionLedger,
    ControllerOwnershipReceipt,
    EnergyBalanceLedger,
    EngineStepIdentity,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryNativeEngineV1 {
    GodotJolt4_7,
    RapierParryNative,
    MujocoNative,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryChannelSupportV1 {
    SupportedMeasured,
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryChannelCapabilityV1 {
    pub channel: RecoveryObservationChannelV1,
    pub support: RecoveryChannelSupportV1,
    pub host_source_ids: Vec<String>,
    pub mapping_rule_id: String,
    pub source_measurement_only: bool,
    pub synthesized_when_missing: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryAdapterCapabilityV1 {
    pub schema_version: String,
    pub adapter_id: String,
    pub engine: RecoveryNativeEngineV1,
    pub engine_version: String,
    pub mapping_id: String,
    pub native_engine: bool,
    pub ordered_channels: Vec<RecoveryChannelCapabilityV1>,
    pub host_pose_label_used_for_success: bool,
    pub fallback_control_permitted: bool,
    pub engine_identity_exposed_to_policy: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

impl RecoveryAdapterCapabilityV1 {
    fn expected_identity(&self) -> (&'static str, &'static str) {
        match self.engine {
            RecoveryNativeEngineV1::GodotJolt4_7 => (GODOT_ADAPTER_ID, GODOT_MAPPING_ID),
            RecoveryNativeEngineV1::RapierParryNative => (RAPIER_ADAPTER_ID, RAPIER_MAPPING_ID),
            RecoveryNativeEngineV1::MujocoNative => (MUJOCO_ADAPTER_ID, MUJOCO_MAPPING_ID),
        }
    }

    fn validate_support(&self) -> std::result::Result<(), String> {
        if self.schema_version != RECOVERY_ADAPTER_CAPABILITY_V1_VERSION {
            return Err("capability_schema_invalid".to_owned());
        }
        let (expected_adapter, expected_mapping) = self.expected_identity();
        if self.adapter_id != expected_adapter || self.mapping_id != expected_mapping {
            return Err("adapter_or_mapping_identity_invalid".to_owned());
        }
        if self.engine_version.trim().is_empty() || !self.native_engine {
            return Err("native_engine_identity_invalid".to_owned());
        }
        if self.ordered_channels.len() != REQUIRED_CHANNELS.len() {
            return Err("required_channel_cardinality_invalid".to_owned());
        }
        for (index, channel) in self.ordered_channels.iter().enumerate() {
            if channel.channel != REQUIRED_CHANNELS[index] {
                return Err("required_channel_order_invalid".to_owned());
            }
            if channel.support != RecoveryChannelSupportV1::SupportedMeasured {
                return Err(format!(
                    "required_channel_unsupported:{:?}",
                    channel.channel
                ));
            }
            if channel.host_source_ids.is_empty()
                || channel
                    .host_source_ids
                    .iter()
                    .any(|value| value.trim().is_empty())
                || channel.mapping_rule_id.trim().is_empty()
                || !channel.source_measurement_only
                || channel.synthesized_when_missing
            {
                return Err(format!(
                    "required_channel_mapping_invalid:{:?}",
                    channel.channel
                ));
            }
        }
        if self.host_pose_label_used_for_success
            || self.fallback_control_permitted
            || self.engine_identity_exposed_to_policy
            || self.model_construction_count != 0
            || self.world_attempt_count != 0
            || self.world_build_count != 0
            || self.solver_step_count != 0
            || self.physics_state_modified
            || self.physical_acceptance_authority
            || self.release_authority
        {
            return Err("capability_claim_or_side_effect_boundary_invalid".to_owned());
        }
        Ok(())
    }
}

pub fn required_recovery_observation_channels_v1() -> Vec<RecoveryObservationChannelV1> {
    REQUIRED_CHANNELS.to_vec()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoverySupportStatusV1 {
    SupportedExact,
    OutOfDomainMorphology,
    UnsupportedProfile,
    UnsupportedCapability,
    InvalidObservation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryPhaseV1 {
    ConfirmProne,
    EstablishDistalSupport,
    RaiseBody,
    StanceHandoff,
    StanceDwell,
    Complete,
    Failed,
    Refused,
}

impl RecoveryPhaseV1 {
    pub const fn phase_id(self) -> &'static str {
        match self {
            Self::ConfirmProne => "confirm_prone",
            Self::EstablishDistalSupport => "establish_distal_support",
            Self::RaiseBody => "raise_body",
            Self::StanceHandoff => "stance_handoff",
            Self::StanceDwell => "stance_dwell",
            Self::Complete => "complete",
            Self::Failed => "failed",
            Self::Refused => "refused",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryArmKindV1 {
    CandidateCommand,
    MatchedZeroCommand,
}

include!(concat!(env!("OUT_DIR"), "/recovery_controller_owner_v1.rs"));

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryObservationSourceKindV1 {
    SyntheticZeroWorldCanary,
    NativePostStep,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryPoseClassV1 {
    VentralProne,
    DistalSupport,
    RaisedBody,
    StableFourFootStance,
    Transitional,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecoveryEvaluationVerdictV1 {
    SyntheticCanaryPassed,
    SyntheticCanaryFailed,
    PhysicalDevelopmentPassed,
    PhysicalDevelopmentFailed,
    PhysicalDevelopmentIncomplete,
    Refused,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryInitialStateMatchRuleV1 {
    pub representation: String,
    pub exact_canonical_digest_required: bool,
    pub numeric_tolerance_vector: Vec<f64>,
    pub physical_threshold_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPhaseTimeoutsV1 {
    pub confirm_prone: u32,
    pub establish_distal_support: u32,
    pub raise_body: u32,
    pub stance_handoff: u32,
    pub stance_dwell: u32,
}

impl RecoveryPhaseTimeoutsV1 {
    fn for_phase(&self, phase: RecoveryPhaseV1) -> Option<u32> {
        match phase {
            RecoveryPhaseV1::ConfirmProne => Some(self.confirm_prone),
            RecoveryPhaseV1::EstablishDistalSupport => Some(self.establish_distal_support),
            RecoveryPhaseV1::RaiseBody => Some(self.raise_body),
            RecoveryPhaseV1::StanceHandoff => Some(self.stance_handoff),
            RecoveryPhaseV1::StanceDwell => Some(self.stance_dwell),
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoverySyntheticThresholdProfileV1 {
    pub schema_version: String,
    pub profile_id: String,
    pub scope: String,
    pub entry_prone_height_ratio_max: f64,
    pub entry_torso_up_dot_max: f64,
    pub entry_prone_confirm_steps: u32,
    pub entry_initial_state_match_tolerance: RecoveryInitialStateMatchRuleV1,
    pub distal_bearing_minimum_impulse_ns: f64,
    pub minimum_com_height_gain_m: f64,
    pub stance_height_ratio_min: f64,
    pub stance_torso_up_dot_min: f64,
    pub minimum_nonfoot_clearance_m: f64,
    pub maximum_forbidden_contact_impulse_ns: f64,
    pub maximum_terminal_linear_speed_m_s: f64,
    pub maximum_terminal_angular_speed_rad_s: f64,
    pub stance_dwell_steps: u32,
    pub per_phase_timeout_steps: RecoveryPhaseTimeoutsV1,
    pub total_timeout_steps: u32,
    pub maximum_energy_balance_residual_j: f64,
    pub physical_threshold_authority: bool,
    pub physical_execution_permitted: bool,
    pub population_claim: bool,
    pub world_build_count: u32,
    pub release_authority: bool,
}

pub fn recovery_synthetic_threshold_profile_v1() -> RecoverySyntheticThresholdProfileV1 {
    RecoverySyntheticThresholdProfileV1 {
        schema_version: RECOVERY_SYNTHETIC_THRESHOLD_PROFILE_V1_VERSION.to_owned(),
        profile_id: SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
        scope: "synthetic_branch_and_mutation_canaries_only_not_physical_adequacy".to_owned(),
        entry_prone_height_ratio_max: 0.5,
        entry_torso_up_dot_max: 0.25,
        entry_prone_confirm_steps: 2,
        entry_initial_state_match_tolerance: RecoveryInitialStateMatchRuleV1 {
            representation: "canonical_initial_state_sha256_exact".to_owned(),
            exact_canonical_digest_required: true,
            numeric_tolerance_vector: Vec::new(),
            physical_threshold_authority: false,
        },
        distal_bearing_minimum_impulse_ns: 0.125,
        minimum_com_height_gain_m: 0.25,
        stance_height_ratio_min: 0.75,
        stance_torso_up_dot_min: 0.875,
        minimum_nonfoot_clearance_m: 0.0625,
        maximum_forbidden_contact_impulse_ns: 0.0,
        maximum_terminal_linear_speed_m_s: 0.125,
        maximum_terminal_angular_speed_rad_s: 0.125,
        stance_dwell_steps: 2,
        per_phase_timeout_steps: RecoveryPhaseTimeoutsV1 {
            confirm_prone: 4,
            establish_distal_support: 4,
            raise_body: 4,
            stance_handoff: 4,
            stance_dwell: 4,
        },
        total_timeout_steps: 32,
        maximum_energy_balance_residual_j: 0.0,
        physical_threshold_authority: false,
        physical_execution_permitted: false,
        population_claim: false,
        world_build_count: 0,
        release_authority: false,
    }
}

/// Return the exact QSDK-R24D17 thresholds in the portable supervisor shape.
///
/// The duplicated representation is deliberate: `recovery_runtime` publishes
/// controller/cohort metadata, while this module owns phase supervision.  A
/// zero-world equality test below prevents either representation from drifting.
pub fn recovery_physical_development_threshold_profile_v1() -> RecoverySyntheticThresholdProfileV1 {
    RecoverySyntheticThresholdProfileV1 {
        schema_version: RECOVERY_PHYSICAL_THRESHOLD_PROFILE_V1_VERSION.to_owned(),
        profile_id: crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        scope: "exact_s169_repeatable_native_physical_development_only".to_owned(),
        entry_prone_height_ratio_max: 0.25,
        entry_torso_up_dot_max: 1.0,
        entry_prone_confirm_steps: 12,
        entry_initial_state_match_tolerance: RecoveryInitialStateMatchRuleV1 {
            representation: "exact_initializer_manifest_sha256_and_canonical_pre_step_state_sha256"
                .to_owned(),
            exact_canonical_digest_required: true,
            numeric_tolerance_vector: Vec::new(),
            physical_threshold_authority: true,
        },
        distal_bearing_minimum_impulse_ns: 0.019293,
        minimum_com_height_gain_m: 0.22,
        stance_height_ratio_min: 0.75,
        stance_torso_up_dot_min: 0.95,
        minimum_nonfoot_clearance_m: 0.005,
        maximum_forbidden_contact_impulse_ns: 0.0,
        maximum_terminal_linear_speed_m_s: 0.10,
        maximum_terminal_angular_speed_rad_s: 0.20,
        stance_dwell_steps: 60,
        per_phase_timeout_steps: RecoveryPhaseTimeoutsV1 {
            confirm_prone: 60,
            establish_distal_support: 240,
            raise_body: 600,
            stance_handoff: 120,
            stance_dwell: 240,
        },
        total_timeout_steps: 1200,
        maximum_energy_balance_residual_j: 0.25,
        physical_threshold_authority: true,
        physical_execution_permitted: true,
        population_claim: false,
        world_build_count: 0,
        release_authority: false,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryCenterOfMassObservationV1 {
    pub position_world_m: Vec3,
    pub linear_velocity_world_m_s: Vec3,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryFootBearingObservationV1 {
    pub contact_site_id: String,
    pub bearing_normal_impulse_ns: f64,
    pub ordinary_unilateral_contact: bool,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryBodyClearanceObservationV1 {
    pub adapter_id: String,
    pub body_id: String,
    pub nonfoot_contact_present: bool,
    pub ventral_surface_contact: bool,
    pub accumulated_nonfoot_normal_impulse_ns: f64,
    pub minimum_nonfoot_clearance_m: f64,
    pub engine_contact_ids: Vec<String>,
    pub classification_rule_id: String,
    pub foot_site_contacts_excluded: bool,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryAppliedActuatorImpulseV1 {
    pub actuator_id: String,
    pub applied_angular_impulse_nms: f64,
    pub host_clamped: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryAppliedActuationReceiptV1 {
    pub adapter_id: String,
    pub adapter_receipt_sha256: String,
    pub source_semantic_step: u64,
    pub command_id: String,
    pub command_sha256: String,
    pub actuator_profile_id: String,
    pub actuator_profile_sha256: String,
    pub zero_command: bool,
    pub ordered_applied_impulses: Vec<RecoveryAppliedActuatorImpulseV1>,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct RecoveryExternalInterventionLedgerV1 {
    pub root_force_application_count: u64,
    pub root_torque_application_count: u64,
    pub root_impulse_application_count: u64,
    pub root_pose_write_count: u64,
    pub root_velocity_write_count: u64,
    pub pin_or_guide_constraint_count: u64,
    pub hidden_body_actuation_count: u64,
    pub pose_teleport_count: u64,
    pub collision_disable_count: u64,
    pub contact_relabel_count: u64,
    pub gravity_mutation_count: u64,
    pub time_scale_mutation_count: u64,
    pub engine_specific_policy_branch_count: u64,
}

impl RecoveryExternalInterventionLedgerV1 {
    pub fn total_count(self) -> u64 {
        self.root_force_application_count
            .saturating_add(self.root_torque_application_count)
            .saturating_add(self.root_impulse_application_count)
            .saturating_add(self.root_pose_write_count)
            .saturating_add(self.root_velocity_write_count)
            .saturating_add(self.pin_or_guide_constraint_count)
            .saturating_add(self.hidden_body_actuation_count)
            .saturating_add(self.pose_teleport_count)
            .saturating_add(self.collision_disable_count)
            .saturating_add(self.contact_relabel_count)
            .saturating_add(self.gravity_mutation_count)
            .saturating_add(self.time_scale_mutation_count)
            .saturating_add(self.engine_specific_policy_branch_count)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryControllerOwnershipReceiptV1 {
    pub owner: RecoveryControllerOwnerV1,
    pub recovery_controller_id: Option<String>,
    pub stance_controller_id: Option<String>,
    pub handoff_event_count: u32,
    pub fallback_controller_active: bool,
    pub source_measurement: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyBalanceLedgerV1 {
    pub initial_mechanical_energy_j: f64,
    pub current_mechanical_energy_j: f64,
    pub cumulative_applied_actuator_work_j: f64,
    pub cumulative_external_work_j: f64,
    pub cumulative_dissipated_energy_j: f64,
    pub source_measurement: bool,
}

impl RecoveryEnergyBalanceLedgerV1 {
    fn residual_j(self) -> f64 {
        self.current_mechanical_energy_j
            - self.initial_mechanical_energy_j
            - self.cumulative_applied_actuator_work_j
            - self.cumulative_external_work_j
            + self.cumulative_dissipated_energy_j
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEngineStepIdentityV1 {
    pub schema_version: String,
    pub source_kind: RecoveryObservationSourceKindV1,
    pub adapter_id: String,
    pub engine: RecoveryNativeEngineV1,
    pub capability_sha256: String,
    pub source_trace_sha256: String,
    pub semantic_step: u64,
    pub host_step_before: u64,
    pub host_step_after: u64,
    pub native_solver_substep_count: u32,
    pub post_step_observation: bool,
    pub engine_identity_exposed_to_policy: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryObservationV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub semantic_step: u64,
    pub outer_step_duration_s: f64,
    pub state: StateFrame,
    pub center_of_mass: RecoveryCenterOfMassObservationV1,
    pub ordered_foot_bearing_observations: Vec<RecoveryFootBearingObservationV1>,
    pub ordered_body_clearance_observations: Vec<RecoveryBodyClearanceObservationV1>,
    pub applied_actuation: RecoveryAppliedActuationReceiptV1,
    pub external_interventions: RecoveryExternalInterventionLedgerV1,
    pub controller_ownership: RecoveryControllerOwnershipReceiptV1,
    pub energy_balance: RecoveryEnergyBalanceLedgerV1,
    pub engine_step_identity: RecoveryEngineStepIdentityV1,
}

/// Additive recovery observation carrying the R24D37 signed-exchange ledger.
///
/// The thirteen non-energy fields intentionally preserve the flat V1 shape.
/// V1 remains a distinct strict schema and is never implicitly upgraded or
/// downgraded through this type.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryObservationV2 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub semantic_step: u64,
    pub outer_step_duration_s: f64,
    pub state: StateFrame,
    pub center_of_mass: RecoveryCenterOfMassObservationV1,
    pub ordered_foot_bearing_observations: Vec<RecoveryFootBearingObservationV1>,
    pub ordered_body_clearance_observations: Vec<RecoveryBodyClearanceObservationV1>,
    pub applied_actuation: RecoveryAppliedActuationReceiptV1,
    pub external_interventions: RecoveryExternalInterventionLedgerV1,
    pub controller_ownership: RecoveryControllerOwnershipReceiptV1,
    pub energy_balance: RecoveryEnergyBalanceLedgerV2,
    pub engine_step_identity: RecoveryEngineStepIdentityV1,
}

/// Additive recovery observation carrying the R24D52 discrete-staging ledger.
///
/// The non-energy fields remain identical to V1 and V2. The distinct schema
/// prevents a V3 energy result from being silently relabelled as either older
/// observation contract.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryObservationV3 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub semantic_step: u64,
    pub outer_step_duration_s: f64,
    pub state: StateFrame,
    pub center_of_mass: RecoveryCenterOfMassObservationV1,
    pub ordered_foot_bearing_observations: Vec<RecoveryFootBearingObservationV1>,
    pub ordered_body_clearance_observations: Vec<RecoveryBodyClearanceObservationV1>,
    pub applied_actuation: RecoveryAppliedActuationReceiptV1,
    pub external_interventions: RecoveryExternalInterventionLedgerV1,
    pub controller_ownership: RecoveryControllerOwnershipReceiptV1,
    pub energy_balance: RecoveryEnergyBalanceLedgerV3,
    pub engine_step_identity: RecoveryEngineStepIdentityV1,
}

#[derive(Clone, Copy)]
pub(crate) struct RecoveryObservationView<'a> {
    pub(crate) schema_version: &'a str,
    pub(crate) task_id: &'a str,
    pub(crate) semantics_id: &'a str,
    pub(crate) actuator_profile_id: &'a str,
    pub(crate) semantic_step: u64,
    pub(crate) outer_step_duration_s: f64,
    pub(crate) state: &'a StateFrame,
    pub(crate) center_of_mass: &'a RecoveryCenterOfMassObservationV1,
    pub(crate) ordered_foot_bearing_observations: &'a [RecoveryFootBearingObservationV1],
    pub(crate) ordered_body_clearance_observations: &'a [RecoveryBodyClearanceObservationV1],
    pub(crate) applied_actuation: &'a RecoveryAppliedActuationReceiptV1,
    pub(crate) external_interventions: &'a RecoveryExternalInterventionLedgerV1,
    pub(crate) controller_ownership: &'a RecoveryControllerOwnershipReceiptV1,
    pub(crate) engine_step_identity: &'a RecoveryEngineStepIdentityV1,
}

pub(crate) trait RecoveryObservationLike: Clone + Serialize {
    fn view(&self) -> RecoveryObservationView<'_>;
    fn expected_schema_version() -> &'static str;
    fn initial_mechanical_energy_j(&self) -> f64;
    fn current_mechanical_energy_j(&self) -> f64;
    fn validate_energy_balance(&self) -> std::result::Result<f64, String>;
    fn validate_development_replay_authority(
        &self,
        _authority: &RecoveryEnergyPartitionAuthorityV1,
        _adapter_capability: &RecoveryAdapterCapabilityV1,
    ) -> Result<String> {
        Err(CoreError::Schema(
            "recovery_development_replay_requires_observation_v3".to_owned(),
        ))
    }
}

impl RecoveryObservationLike for RecoveryObservationV1 {
    fn view(&self) -> RecoveryObservationView<'_> {
        RecoveryObservationView {
            schema_version: &self.schema_version,
            task_id: &self.task_id,
            semantics_id: &self.semantics_id,
            actuator_profile_id: &self.actuator_profile_id,
            semantic_step: self.semantic_step,
            outer_step_duration_s: self.outer_step_duration_s,
            state: &self.state,
            center_of_mass: &self.center_of_mass,
            ordered_foot_bearing_observations: &self.ordered_foot_bearing_observations,
            ordered_body_clearance_observations: &self.ordered_body_clearance_observations,
            applied_actuation: &self.applied_actuation,
            external_interventions: &self.external_interventions,
            controller_ownership: &self.controller_ownership,
            engine_step_identity: &self.engine_step_identity,
        }
    }

    fn expected_schema_version() -> &'static str {
        RECOVERY_OBSERVATION_V1_VERSION
    }

    fn initial_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.initial_mechanical_energy_j
    }

    fn current_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.current_mechanical_energy_j
    }

    fn validate_energy_balance(&self) -> std::result::Result<f64, String> {
        let energy = self.energy_balance;
        for (value, field) in [
            (
                energy.initial_mechanical_energy_j,
                "initial_mechanical_energy_j",
            ),
            (
                energy.current_mechanical_energy_j,
                "current_mechanical_energy_j",
            ),
            (
                energy.cumulative_applied_actuator_work_j,
                "cumulative_applied_actuator_work_j",
            ),
            (
                energy.cumulative_external_work_j,
                "cumulative_external_work_j",
            ),
            (
                energy.cumulative_dissipated_energy_j,
                "cumulative_dissipated_energy_j",
            ),
        ] {
            finite(value, field)?;
        }
        if !energy.source_measurement
            || energy.cumulative_dissipated_energy_j < 0.0
            || energy.cumulative_external_work_j != 0.0
        {
            return Err("energy_balance_ledger_invalid".to_owned());
        }
        Ok(energy.residual_j().abs())
    }
}

impl RecoveryObservationLike for RecoveryObservationV2 {
    fn view(&self) -> RecoveryObservationView<'_> {
        RecoveryObservationView {
            schema_version: &self.schema_version,
            task_id: &self.task_id,
            semantics_id: &self.semantics_id,
            actuator_profile_id: &self.actuator_profile_id,
            semantic_step: self.semantic_step,
            outer_step_duration_s: self.outer_step_duration_s,
            state: &self.state,
            center_of_mass: &self.center_of_mass,
            ordered_foot_bearing_observations: &self.ordered_foot_bearing_observations,
            ordered_body_clearance_observations: &self.ordered_body_clearance_observations,
            applied_actuation: &self.applied_actuation,
            external_interventions: &self.external_interventions,
            controller_ownership: &self.controller_ownership,
            engine_step_identity: &self.engine_step_identity,
        }
    }

    fn expected_schema_version() -> &'static str {
        RECOVERY_OBSERVATION_V2_VERSION
    }

    fn initial_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.initial_mechanical_energy_j
    }

    fn current_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.current_mechanical_energy_j
    }

    fn validate_energy_balance(&self) -> std::result::Result<f64, String> {
        evaluate_recovery_energy_balance_v2(RecoveryEnergyBalanceEvaluationRequestV2 {
            schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V2_VERSION.to_owned(),
            ledger: self.energy_balance.clone(),
        })
        .map(|receipt| receipt.absolute_residual_j)
        .map_err(|error| format!("energy_balance_ledger_v2_invalid:{error}"))
    }
}

impl RecoveryObservationLike for RecoveryObservationV3 {
    fn view(&self) -> RecoveryObservationView<'_> {
        RecoveryObservationView {
            schema_version: &self.schema_version,
            task_id: &self.task_id,
            semantics_id: &self.semantics_id,
            actuator_profile_id: &self.actuator_profile_id,
            semantic_step: self.semantic_step,
            outer_step_duration_s: self.outer_step_duration_s,
            state: &self.state,
            center_of_mass: &self.center_of_mass,
            ordered_foot_bearing_observations: &self.ordered_foot_bearing_observations,
            ordered_body_clearance_observations: &self.ordered_body_clearance_observations,
            applied_actuation: &self.applied_actuation,
            external_interventions: &self.external_interventions,
            controller_ownership: &self.controller_ownership,
            engine_step_identity: &self.engine_step_identity,
        }
    }

    fn expected_schema_version() -> &'static str {
        RECOVERY_OBSERVATION_V3_VERSION
    }

    fn initial_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.initial_mechanical_energy_j
    }

    fn current_mechanical_energy_j(&self) -> f64 {
        self.energy_balance.current_mechanical_energy_j
    }

    fn validate_energy_balance(&self) -> std::result::Result<f64, String> {
        evaluate_recovery_energy_balance_v3(RecoveryEnergyBalanceEvaluationRequestV3 {
            schema_version: RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION.to_owned(),
            ledger: self.energy_balance.clone(),
        })
        .map(|receipt| receipt.absolute_residual_j)
        .map_err(|error| format!("energy_balance_ledger_v3_invalid:{error}"))
    }

    fn validate_development_replay_authority(
        &self,
        authority: &RecoveryEnergyPartitionAuthorityV1,
        adapter_capability: &RecoveryAdapterCapabilityV1,
    ) -> Result<String> {
        validate_recovery_energy_partition_authority_v1(authority, self, adapter_capability)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPoseClassificationV1 {
    pub pose_class: RecoveryPoseClassV1,
    pub torso_height_ratio: f64,
    pub torso_up_dot: f64,
    pub center_of_mass_height_gain_m: f64,
    pub all_four_distal_sites_bearing: bool,
    pub minimum_distal_bearing_impulse_ns: f64,
    pub any_nonfoot_contact: bool,
    pub torso_ventral_contact: bool,
    pub minimum_nonfoot_clearance_m: f64,
    pub maximum_nonfoot_contact_impulse_ns: f64,
    pub terminal_linear_speed_m_s: f64,
    pub terminal_angular_speed_rad_s: f64,
    pub energy_balance_residual_j: f64,
    pub joint_limits_respected: bool,
    pub actuator_budget_respected: bool,
    pub intervention_counter_total: u64,
    pub entry_prone_gate: bool,
    pub distal_support_gate: bool,
    pub raised_body_gate: bool,
    pub exclusive_stance_handoff_gate: bool,
    pub stable_stance_gate: bool,
    pub safety_gate: bool,
    pub no_cheat_gate: bool,
    pub physical_threshold_authority: bool,
    pub physical_result: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoverySupervisorMemoryV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub descriptor_sha256: String,
    pub morphology_spec_sha256: String,
    pub actuator_profile_id: String,
    pub actuator_profile_sha256: String,
    pub capability_sha256: String,
    pub threshold_profile_id: String,
    pub threshold_profile_sha256: String,
    pub arm_kind: RecoveryArmKindV1,
    pub phase: RecoveryPhaseV1,
    pub ordered_completed_phases: Vec<RecoveryPhaseV1>,
    pub start_semantic_step: Option<u64>,
    pub last_semantic_step: Option<u64>,
    pub total_steps_observed: u32,
    pub phase_steps_observed: u32,
    pub prone_confirm_steps_observed: u32,
    pub stance_dwell_steps_observed: u32,
    pub initial_center_of_mass_height_m: Option<f64>,
    pub terminal_failure_code: Option<String>,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryMorphologyContextV1 {
    pub schema_version: String,
    pub recovery_morphology_id: String,
    pub recovery_descriptor: RecoveryMorphologyDescriptorV1,
    pub recovery_descriptor_sha256: String,
    pub base_descriptor_sha256: String,
    pub base_morphology_spec_sha256: String,
    pub recovery_morphology_spec_sha256: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryInitializeRequestV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub arm_kind: RecoveryArmKindV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryInitializeRequestV2 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub arm_kind: RecoveryArmKindV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryInitializeReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub requested_task_id: String,
    pub requested_semantics_id: String,
    pub requested_actuator_profile_id: String,
    pub requested_threshold_profile_id: String,
    pub supported_task_ids: Vec<String>,
    pub supported_semantics_ids: Vec<String>,
    pub supported_actuator_profile_ids: Vec<String>,
    pub supported_threshold_profile_ids: Vec<String>,
    pub descriptor_sha256: String,
    pub morphology_spec_sha256: String,
    pub actuator_profile_sha256: Option<String>,
    pub capability_sha256: String,
    pub threshold_profile_sha256: Option<String>,
    pub memory: Option<RecoverySupervisorMemoryV1>,
    pub controller_implemented: bool,
    pub physical_threshold_authority: bool,
    pub physical_question_opened: bool,
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
pub struct RecoveryStepRequestV1 {
    pub schema_version: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub memory: RecoverySupervisorMemoryV1,
    pub observation: RecoveryObservationV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepRequestV2 {
    pub schema_version: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub memory: RecoverySupervisorMemoryV1,
    pub observation: RecoveryObservationV1,
}

/// Morphology-aware recovery step carrying a true observation V2.
///
/// Request V2 remains the morphology-aware request for observation V1. The
/// additive V3 identity prevents those two independent version axes from being
/// conflated at the public boundary.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepRequestV3 {
    pub schema_version: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub memory: RecoverySupervisorMemoryV1,
    pub observation: RecoveryObservationV2,
}

/// Morphology-aware recovery step carrying a discrete-staging observation V3.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepRequestV4 {
    pub schema_version: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub memory: RecoverySupervisorMemoryV1,
    pub observation: RecoveryObservationV3,
}

/// Provenance-bound statement about whether an observation's energy ledger is
/// complete enough to carry exact balance authority.
///
/// R126 registers only the retained Godot/Jolt incomplete profile. The type is
/// additive so a later, independently qualified complete profile can receive a
/// distinct identity without relabelling this observation or its diagnosis.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEnergyPartitionAuthorityV1 {
    pub schema_version: String,
    pub authority_profile_id: String,
    pub authority_source_sha256: String,
    pub adapter_id: String,
    pub engine: RecoveryNativeEngineV1,
    pub capability_sha256: String,
    pub energy_source_profile_id: String,
    pub component_partition_id: String,
    pub constraint_exchange_partition_complete: bool,
    pub passive_dissipation_partition_complete: bool,
    pub component_partition_complete: bool,
    pub exact_balance_safety_authority: bool,
    pub unclosed_energy_residual_preserved: bool,
    pub residual_balancing_permitted: bool,
    pub development_progression_permitted: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

/// Observation-V3 recovery step with an explicit energy-partition authority.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepRequestV5 {
    pub schema_version: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub memory: RecoverySupervisorMemoryV1,
    pub observation: RecoveryObservationV3,
    pub energy_partition_authority: RecoveryEnergyPartitionAuthorityV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub observation_sha256: Option<String>,
    pub prior_phase: RecoveryPhaseV1,
    pub next_phase: RecoveryPhaseV1,
    pub transitioned: bool,
    pub classification: Option<RecoveryPoseClassificationV1>,
    pub memory: Option<RecoverySupervisorMemoryV1>,
    pub post_step_observation_only: bool,
    pub phase_skip_permitted: bool,
    pub controller_command_emitted: bool,
    pub controller_implemented: bool,
    pub synthetic_canary_semantics_executed: bool,
    pub physical_threshold_authority: bool,
    pub physical_result: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

/// R126's additive, non-acceptance progression receipt.
///
/// `legacy_safety_gate` and `legacy_stable_stance_gate` are copied from the V1
/// classification without reinterpretation. The development gates remove only
/// the explicitly incomplete energy component and can neither complete the
/// supervisor nor create a physical/release claim.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryDevelopmentProgressionReceiptV1 {
    pub schema_version: String,
    pub energy_partition_authority_sha256: String,
    pub authority_profile_id: String,
    pub component_partition_complete: bool,
    pub exact_balance_safety_authority: bool,
    pub legacy_safety_gate: bool,
    pub legacy_stable_stance_gate: bool,
    pub acceptance_safety_gate: bool,
    pub development_nonenergy_safety_gate: bool,
    pub development_stance_handoff_gate: bool,
    pub development_progression_permitted: bool,
    pub development_progression_used: bool,
    pub stable_stance_completion_authorized: bool,
    pub physical_result_authorized: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
}

/// V2 wraps the unchanged V1 step receipt rather than widening or relabelling
/// its historical schema.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStepReceiptV2 {
    pub schema_version: String,
    pub step: RecoveryStepReceiptV1,
    pub development_progression: RecoveryDevelopmentProgressionReceiptV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryTraceV1 {
    pub schema_version: String,
    pub arm_kind: RecoveryArmKindV1,
    pub declared_initial_state_sha256: String,
    pub observations: Vec<RecoveryObservationV1>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryTraceV2 {
    pub schema_version: String,
    pub arm_kind: RecoveryArmKindV1,
    pub declared_initial_state_sha256: String,
    pub observations: Vec<RecoveryObservationV2>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryTraceV3 {
    pub schema_version: String,
    pub arm_kind: RecoveryArmKindV1,
    pub declared_initial_state_sha256: String,
    pub observations: Vec<RecoveryObservationV3>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationRequestV1 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub candidate_trace: RecoveryTraceV1,
    pub matched_zero_command_trace: RecoveryTraceV1,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationRequestV2 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub candidate_trace: RecoveryTraceV1,
    pub matched_zero_command_trace: RecoveryTraceV1,
}

/// Morphology-aware paired evaluation over true observation-V2 traces.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationRequestV3 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub candidate_trace: RecoveryTraceV2,
    pub matched_zero_command_trace: RecoveryTraceV2,
}

/// Morphology-aware paired evaluation over discrete-staging observation-V3 traces.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationRequestV4 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub candidate_trace: RecoveryTraceV3,
    pub matched_zero_command_trace: RecoveryTraceV3,
}

/// Observation-V3 paired evaluation using an explicit, provenance-bound
/// development authority. The authority can enable only the same incomplete-
/// energy phase progression as recovery step V5; it cannot authorize exact
/// balance, physical acceptance, completion, or release.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationRequestV5 {
    pub schema_version: String,
    pub task_id: String,
    pub semantics_id: String,
    pub actuator_profile_id: String,
    pub threshold_profile_id: String,
    pub descriptor: BoundedQuadrupedDescriptor,
    pub morphology_context: RecoveryMorphologyContextV1,
    pub adapter_capability: RecoveryAdapterCapabilityV1,
    pub energy_partition_authority: RecoveryEnergyPartitionAuthorityV1,
    pub candidate_trace: RecoveryTraceV3,
    pub matched_zero_command_trace: RecoveryTraceV3,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryTraceReplayReceiptV1 {
    pub arm_kind: RecoveryArmKindV1,
    pub observation_count: usize,
    pub accepted_observation_count: usize,
    pub final_phase: RecoveryPhaseV1,
    pub terminal_failure_code: Option<String>,
    pub completed: bool,
    pub refused: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryEvaluationReceiptV1 {
    pub schema_version: String,
    pub support_status: RecoverySupportStatusV1,
    pub refusal_reason: Option<String>,
    pub verdict: RecoveryEvaluationVerdictV1,
    pub descriptor_sha256: String,
    pub morphology_spec_sha256: String,
    pub actuator_profile_sha256: Option<String>,
    pub capability_sha256: String,
    pub threshold_profile_sha256: Option<String>,
    pub candidate_trace: Option<RecoveryTraceReplayReceiptV1>,
    pub matched_zero_command_trace: Option<RecoveryTraceReplayReceiptV1>,
    pub initial_state_identity_matched: bool,
    pub candidate_synthetic_path_completed: bool,
    pub matched_zero_command_control_failed_to_complete: bool,
    pub candidate_physical_path_completed: bool,
    pub matched_zero_command_physical_control_failed_to_complete: bool,
    pub physical_development_trace_valid: bool,
    pub all_negative_control_requirements_enforced: bool,
    pub controller_implemented: bool,
    pub synthetic_canary_passed: bool,
    pub physical_threshold_authority: bool,
    pub physical_question_opened: bool,
    pub physical_result: bool,
    pub model_construction_count: u32,
    pub world_attempt_count: u32,
    pub world_build_count: u32,
    pub solver_step_count: u64,
    pub physics_state_modified: bool,
    pub prone_to_standing_claimed: bool,
    pub physical_acceptance_authority: bool,
    pub release_authority: bool,
}

pub(crate) struct ResolvedRecoveryMorphology {
    pub(crate) descriptor_sha256: String,
    pub(crate) morphology: CompiledMorphology,
    pub(crate) geometry: crate::quadruped::DerivedQuadrupedGeometry,
    pub(crate) base: CompiledQuadruped,
    pub(crate) refusal_reason: Option<String>,
}

pub(crate) fn resolve_recovery_morphology_context(
    descriptor: BoundedQuadrupedDescriptor,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<ResolvedRecoveryMorphology> {
    let base = compile_bounded_quadruped(descriptor.clone())?;
    let Some(context) = morphology_context else {
        return Ok(ResolvedRecoveryMorphology {
            descriptor_sha256: base.descriptor_sha256.clone(),
            morphology: base.morphology.clone(),
            geometry: base.geometry.clone(),
            base,
            refusal_reason: None,
        });
    };
    if context.schema_version != RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_morphology_context_version".to_owned(),
        ));
    }
    for (value, field) in [
        (
            &context.recovery_descriptor_sha256,
            "recovery_context.recovery_descriptor_sha256",
        ),
        (
            &context.base_descriptor_sha256,
            "recovery_context.base_descriptor_sha256",
        ),
        (
            &context.base_morphology_spec_sha256,
            "recovery_context.base_morphology_spec_sha256",
        ),
        (
            &context.recovery_morphology_spec_sha256,
            "recovery_context.recovery_morphology_spec_sha256",
        ),
    ] {
        require_digest(value, field)?;
    }
    if context.recovery_morphology_id != context.recovery_descriptor.recovery_morphology_id
        || context.recovery_descriptor.base_descriptor != descriptor
    {
        return Err(CoreError::Identity(
            "recovery_morphology_context_descriptor_identity".to_owned(),
        ));
    }
    let receipt = compile_recovery_morphology_v1(context.recovery_descriptor.clone())?;
    if receipt.recovery_morphology_id != context.recovery_morphology_id
        || receipt.descriptor_sha256 != context.recovery_descriptor_sha256
        || receipt.base_descriptor_sha256 != context.base_descriptor_sha256
        || receipt.base_morphology_spec_sha256 != context.base_morphology_spec_sha256
        || receipt.recovery_morphology_spec_sha256 != context.recovery_morphology_spec_sha256
        || receipt.base_descriptor_sha256 != base.descriptor_sha256
        || receipt.base_morphology_spec_sha256 != base.morphology.morphology_spec_sha256
    {
        return Err(CoreError::Identity(
            "recovery_morphology_context_receipt_identity".to_owned(),
        ));
    }
    let refusal_reason =
        if receipt.support_status == RecoveryMorphologySupportStatusV1::SupportedExact {
            None
        } else {
            Some(
                receipt
                    .refusal_reason
                    .clone()
                    .unwrap_or_else(|| "recovery_morphology_not_supported".to_owned()),
            )
        };
    Ok(ResolvedRecoveryMorphology {
        descriptor_sha256: receipt.descriptor_sha256,
        morphology: receipt.morphology,
        geometry: receipt.geometry,
        base,
        refusal_reason,
    })
}

struct RecoveryContext {
    compiled: ResolvedRecoveryMorphology,
    adapter_id: String,
    engine: RecoveryNativeEngineV1,
    capability_sha256: String,
    threshold_profile: RecoverySyntheticThresholdProfileV1,
    threshold_profile_sha256: String,
    ordered_caps_nms: Vec<f64>,
}

enum RecoveryContextResolution {
    Supported(Box<RecoveryContext>),
    Refused {
        status: RecoverySupportStatusV1,
        reason: String,
        compiled: Box<ResolvedRecoveryMorphology>,
        capability_sha256: String,
    },
}

fn valid_id(value: &str) -> bool {
    let mut characters = value.chars();
    matches!(characters.next(), Some('a'..='z'))
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn require_digest(value: &str, field: &str) -> Result<()> {
    if value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
    {
        Ok(())
    } else {
        Err(CoreError::Digest(field.to_owned()))
    }
}

pub(crate) fn validate_recovery_energy_partition_authority_v1(
    authority: &RecoveryEnergyPartitionAuthorityV1,
    observation: &RecoveryObservationV3,
    adapter_capability: &RecoveryAdapterCapabilityV1,
) -> Result<String> {
    if authority.schema_version != RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_energy_partition_authority_version".to_owned(),
        ));
    }
    if !valid_id(&authority.authority_profile_id)
        || !valid_id(&authority.adapter_id)
        || !valid_id(&authority.energy_source_profile_id)
        || !valid_id(&authority.component_partition_id)
    {
        return Err(CoreError::Identity(
            "recovery_energy_partition_authority_identifier_invalid".to_owned(),
        ));
    }
    require_digest(
        &authority.authority_source_sha256,
        "recovery_energy_partition_authority.authority_source_sha256",
    )?;
    require_digest(
        &authority.capability_sha256,
        "recovery_energy_partition_authority.capability_sha256",
    )?;

    let component_partition_consistent = authority.component_partition_complete
        == (authority.constraint_exchange_partition_complete
            && authority.passive_dissipation_partition_complete);
    let exact_authority_consistent =
        !authority.exact_balance_safety_authority || authority.component_partition_complete;
    let residual_status_consistent =
        authority.unclosed_energy_residual_preserved == !authority.component_partition_complete;
    let development_status_consistent = !authority.development_progression_permitted
        || (!authority.component_partition_complete
            && !authority.exact_balance_safety_authority
            && authority.unclosed_energy_residual_preserved);
    if !component_partition_consistent
        || !exact_authority_consistent
        || !residual_status_consistent
        || !development_status_consistent
        || authority.residual_balancing_permitted
        || authority.physical_acceptance_authority
        || authority.release_authority
    {
        return Err(CoreError::Capability(
            "recovery_energy_partition_authority_claim_invalid".to_owned(),
        ));
    }

    let capability_sha256 = digest_serializable(adapter_capability)?;
    if authority.capability_sha256 != capability_sha256
        || authority.capability_sha256 != observation.engine_step_identity.capability_sha256
        || authority.adapter_id != adapter_capability.adapter_id
        || authority.adapter_id != observation.engine_step_identity.adapter_id
        || authority.engine != adapter_capability.engine
        || authority.engine != observation.engine_step_identity.engine
        || authority.energy_source_profile_id != observation.energy_balance.source_profile_id
        || authority.component_partition_id != observation.energy_balance.component_partition_id
    {
        return Err(CoreError::Identity(
            "recovery_energy_partition_authority_observation_binding_invalid".to_owned(),
        ));
    }

    // Profile recognition is exact and additive. The historical R126 shape
    // remains immutable; R136 cannot be manufactured by changing its booleans
    // because the profile, source, observation mapping, and full claim shape
    // must all match the separately content-addressed authority source.
    let retained_r24d126_incomplete = authority.authority_profile_id
        == GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
        && authority.authority_source_sha256 == GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256
        && authority.adapter_id == GODOT_ADAPTER_ID
        && authority.engine == RecoveryNativeEngineV1::GodotJolt4_7
        && authority.energy_source_profile_id == GODOT_JOLT_R24D57_ENERGY_SOURCE_PROFILE_ID
        && authority.component_partition_id
            == crate::recovery_energy_v3::RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID
        && !authority.constraint_exchange_partition_complete
        && !authority.passive_dissipation_partition_complete
        && !authority.component_partition_complete
        && !authority.exact_balance_safety_authority
        && authority.unclosed_energy_residual_preserved
        && !authority.residual_balancing_permitted
        && authority.development_progression_permitted
        && !authority.physical_acceptance_authority
        && !authority.release_authority;
    let prospective_r24d136_complete = authority.authority_profile_id
        == GODOT_JOLT_R24D136_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
        && authority.authority_source_sha256 == GODOT_JOLT_R24D136_ENERGY_AUTHORITY_SOURCE_SHA256
        && authority.adapter_id == GODOT_ADAPTER_ID
        && authority.engine == RecoveryNativeEngineV1::GodotJolt4_7
        && authority.energy_source_profile_id == GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID
        && authority.component_partition_id
            == crate::recovery_energy_v3::RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID
        && authority.constraint_exchange_partition_complete
        && authority.passive_dissipation_partition_complete
        && authority.component_partition_complete
        && authority.exact_balance_safety_authority
        && !authority.unclosed_energy_residual_preserved
        && !authority.residual_balancing_permitted
        && !authority.development_progression_permitted
        && !authority.physical_acceptance_authority
        && !authority.release_authority;
    let prospective_r24d144_complete = authority.authority_profile_id
        == GODOT_JOLT_R24D144_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
        && authority.authority_source_sha256 == GODOT_JOLT_R24D144_ENERGY_AUTHORITY_SOURCE_SHA256
        && authority.adapter_id == GODOT_ADAPTER_ID
        && authority.engine == RecoveryNativeEngineV1::GodotJolt4_7
        && authority.energy_source_profile_id == GODOT_JOLT_R24D144_ENERGY_SOURCE_PROFILE_ID
        && authority.component_partition_id
            == crate::recovery_energy_v3::RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID
        && authority.constraint_exchange_partition_complete
        && authority.passive_dissipation_partition_complete
        && authority.component_partition_complete
        && authority.exact_balance_safety_authority
        && !authority.unclosed_energy_residual_preserved
        && !authority.residual_balancing_permitted
        && !authority.development_progression_permitted
        && !authority.physical_acceptance_authority
        && !authority.release_authority;
    let prospective_r24d151_commissioned_discrete_staging_complete = authority.authority_profile_id
        == GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_PROFILE_ID
        && authority.authority_source_sha256
            == GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_SOURCE_SHA256
        && authority.adapter_id == GODOT_ADAPTER_ID
        && authority.engine == RecoveryNativeEngineV1::GodotJolt4_7
        && authority.energy_source_profile_id
            == GODOT_JOLT_R24D148_DISCRETE_STAGING_ENERGY_SOURCE_PROFILE_ID
        && authority.component_partition_id
            == crate::recovery_energy_v3::RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID
        && authority.constraint_exchange_partition_complete
        && authority.passive_dissipation_partition_complete
        && authority.component_partition_complete
        && authority.exact_balance_safety_authority
        && !authority.unclosed_energy_residual_preserved
        && !authority.residual_balancing_permitted
        && !authority.development_progression_permitted
        && !authority.physical_acceptance_authority
        && !authority.release_authority;
    if !retained_r24d126_incomplete
        && !prospective_r24d136_complete
        && !prospective_r24d144_complete
        && !prospective_r24d151_commissioned_discrete_staging_complete
    {
        return Err(CoreError::Capability(
            "recovery_energy_partition_authority_profile_unsupported".to_owned(),
        ));
    }
    digest_serializable(authority)
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

fn vec_norm(value: Vec3) -> f64 {
    (value.x * value.x + value.y * value.y + value.z * value.z).sqrt()
}

fn torso_up_dot(state: &StateFrame) -> f64 {
    let q = state.base_pose_world.orientation_xyzw;
    1.0 - 2.0 * (q.x * q.x + q.z * q.z)
}

fn supported_threshold_profile_ids() -> Vec<String> {
    vec![
        SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
        crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        partial_fall::PRONE_PROFILE.to_owned(),
    ]
}

fn resolve_threshold_profile(profile_id: &str) -> Option<RecoverySyntheticThresholdProfileV1> {
    match profile_id {
        SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID => {
            Some(recovery_synthetic_threshold_profile_v1())
        }
        crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID => {
            Some(recovery_physical_development_threshold_profile_v1())
        }
        partial_fall::PRONE_PROFILE => Some(partial_fall::prone_thresholds()),
        _ => None,
    }
}

fn expected_native_substeps(engine: RecoveryNativeEngineV1) -> u32 {
    match engine {
        RecoveryNativeEngineV1::GodotJolt4_7 | RecoveryNativeEngineV1::RapierParryNative => 1,
        RecoveryNativeEngineV1::MujocoNative => 5,
    }
}

fn context_for(
    task_id: &str,
    semantics_id: &str,
    actuator_profile_id: &str,
    threshold_profile_id: &str,
    descriptor: BoundedQuadrupedDescriptor,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
    capability: &RecoveryAdapterCapabilityV1,
) -> Result<RecoveryContextResolution> {
    // Compile before every support decision so an unsupported identifier can
    // never become a descriptor-validation bypass.
    let compiled = Box::new(resolve_recovery_morphology_context(
        descriptor.clone(),
        morphology_context,
    )?);
    let capability_sha256 = digest_serializable(capability)?;

    if let Some(reason) = compiled.refusal_reason.clone() {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::OutOfDomainMorphology,
            reason,
            compiled,
            capability_sha256,
        });
    }

    if task_id != CANONICAL_PRONE_TO_STANDING_TASK_ID
        || semantics_id != PORTABLE_RECOVERY_SEMANTICS_ID
        || resolve_threshold_profile(threshold_profile_id).is_none()
    {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedProfile,
            reason: "task_semantics_or_threshold_profile_not_registered".to_owned(),
            compiled,
            capability_sha256,
        });
    }
    if actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedProfile,
            reason: "actuator_profile_not_registered".to_owned(),
            compiled,
            capability_sha256,
        });
    }

    let profile_receipt = resolve_actuator_cap_profile_v1(ActuatorCapProfileRequestV1 {
        schema_version: ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION.to_owned(),
        profile_id: actuator_profile_id.to_owned(),
        descriptor,
    })?;
    if profile_receipt.support_status == ActuatorCapProfileSupportStatusV1::OutOfDomainMorphology {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::OutOfDomainMorphology,
            reason: "descriptor_outside_exact_recovery_scope".to_owned(),
            compiled,
            capability_sha256,
        });
    }
    if profile_receipt.support_status != ActuatorCapProfileSupportStatusV1::SupportedExact {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedProfile,
            reason: "actuator_profile_resolution_refused".to_owned(),
            compiled,
            capability_sha256,
        });
    }
    if compiled.base.morphology_id != R23D60_SELECTED_S169_MORPHOLOGY_ID
        || compiled.base.descriptor_sha256 != R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        || compiled.base.morphology.morphology_spec_sha256
            != R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        || profile_receipt.profile_sha256.as_deref()
            != Some(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256)
    {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::OutOfDomainMorphology,
            reason: "descriptor_or_profile_identity_outside_exact_recovery_scope".to_owned(),
            compiled,
            capability_sha256,
        });
    }
    if let Err(reason) = capability.validate_support() {
        return Ok(RecoveryContextResolution::Refused {
            status: RecoverySupportStatusV1::UnsupportedCapability,
            reason,
            compiled,
            capability_sha256,
        });
    }

    let profile = profile_receipt
        .profile
        .ok_or_else(|| CoreError::Internal("supported_recovery_profile_missing".to_owned()))?;
    let ordered_caps_nms = profile
        .ordered_caps
        .iter()
        .map(|entry| entry.maximum_outer_step_impulse_nms)
        .collect();
    let threshold_profile = resolve_threshold_profile(threshold_profile_id)
        .ok_or_else(|| CoreError::Internal("registered_threshold_profile_missing".to_owned()))?;
    let threshold_profile_sha256 = digest_serializable(&threshold_profile)?;
    Ok(RecoveryContextResolution::Supported(Box::new(
        RecoveryContext {
            compiled: *compiled,
            adapter_id: capability.adapter_id.clone(),
            engine: capability.engine,
            capability_sha256,
            threshold_profile,
            threshold_profile_sha256,
            ordered_caps_nms,
        },
    )))
}

fn initialize_refusal(
    request: &RecoveryInitializeRequestV1,
    status: RecoverySupportStatusV1,
    reason: String,
    compiled: &ResolvedRecoveryMorphology,
    capability_sha256: String,
) -> RecoveryInitializeReceiptV1 {
    RecoveryInitializeReceiptV1 {
        schema_version: RECOVERY_INITIALIZE_RECEIPT_V1_VERSION.to_owned(),
        support_status: status,
        refusal_reason: Some(reason),
        requested_task_id: request.task_id.clone(),
        requested_semantics_id: request.semantics_id.clone(),
        requested_actuator_profile_id: request.actuator_profile_id.clone(),
        requested_threshold_profile_id: request.threshold_profile_id.clone(),
        supported_task_ids: vec![CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned()],
        supported_semantics_ids: vec![PORTABLE_RECOVERY_SEMANTICS_ID.to_owned()],
        supported_actuator_profile_ids: vec![
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        ],
        supported_threshold_profile_ids: supported_threshold_profile_ids(),
        descriptor_sha256: compiled.descriptor_sha256.clone(),
        morphology_spec_sha256: compiled.morphology.morphology_spec_sha256.clone(),
        actuator_profile_sha256: None,
        capability_sha256,
        threshold_profile_sha256: None,
        memory: None,
        controller_implemented: false,
        physical_threshold_authority: false,
        physical_question_opened: false,
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

pub fn initialize_recovery_v1(
    request: RecoveryInitializeRequestV1,
) -> Result<RecoveryInitializeReceiptV1> {
    if request.schema_version != RECOVERY_INITIALIZE_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_initialize_request_version".to_owned(),
        ));
    }
    initialize_recovery(request, None)
}

pub fn initialize_recovery_v2(
    request: RecoveryInitializeRequestV2,
) -> Result<RecoveryInitializeReceiptV1> {
    if request.schema_version != RECOVERY_INITIALIZE_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_initialize_request_version".to_owned(),
        ));
    }
    let morphology_context = request.morphology_context;
    initialize_recovery(
        RecoveryInitializeRequestV1 {
            schema_version: RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
            task_id: request.task_id,
            semantics_id: request.semantics_id,
            actuator_profile_id: request.actuator_profile_id,
            threshold_profile_id: request.threshold_profile_id,
            descriptor: request.descriptor,
            adapter_capability: request.adapter_capability,
            arm_kind: request.arm_kind,
        },
        Some(&morphology_context),
    )
}

fn initialize_recovery(
    request: RecoveryInitializeRequestV1,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<RecoveryInitializeReceiptV1> {
    let resolution = context_for(
        &request.task_id,
        &request.semantics_id,
        &request.actuator_profile_id,
        &request.threshold_profile_id,
        request.descriptor.clone(),
        morphology_context,
        &request.adapter_capability,
    )?;
    let context = match resolution {
        RecoveryContextResolution::Supported(value) => *value,
        RecoveryContextResolution::Refused {
            status,
            reason,
            compiled,
            capability_sha256,
        } => {
            return Ok(initialize_refusal(
                &request,
                status,
                reason,
                &compiled,
                capability_sha256,
            ));
        }
    };

    let memory = RecoverySupervisorMemoryV1 {
        schema_version: RECOVERY_SUPERVISOR_MEMORY_V1_VERSION.to_owned(),
        task_id: request.task_id.clone(),
        semantics_id: request.semantics_id.clone(),
        descriptor_sha256: context.compiled.descriptor_sha256.clone(),
        morphology_spec_sha256: context.compiled.morphology.morphology_spec_sha256.clone(),
        actuator_profile_id: request.actuator_profile_id.clone(),
        actuator_profile_sha256: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned(),
        capability_sha256: context.capability_sha256.clone(),
        threshold_profile_id: request.threshold_profile_id.clone(),
        threshold_profile_sha256: context.threshold_profile_sha256.clone(),
        arm_kind: request.arm_kind,
        phase: RecoveryPhaseV1::ConfirmProne,
        ordered_completed_phases: Vec::new(),
        start_semantic_step: None,
        last_semantic_step: None,
        total_steps_observed: 0,
        phase_steps_observed: 0,
        prone_confirm_steps_observed: 0,
        stance_dwell_steps_observed: 0,
        initial_center_of_mass_height_m: None,
        terminal_failure_code: None,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        physical_acceptance_authority: false,
        release_authority: false,
    };
    Ok(RecoveryInitializeReceiptV1 {
        schema_version: RECOVERY_INITIALIZE_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        requested_task_id: request.task_id,
        requested_semantics_id: request.semantics_id,
        requested_actuator_profile_id: request.actuator_profile_id,
        requested_threshold_profile_id: request.threshold_profile_id,
        supported_task_ids: vec![CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned()],
        supported_semantics_ids: vec![PORTABLE_RECOVERY_SEMANTICS_ID.to_owned()],
        supported_actuator_profile_ids: vec![
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        ],
        supported_threshold_profile_ids: supported_threshold_profile_ids(),
        descriptor_sha256: context.compiled.descriptor_sha256,
        morphology_spec_sha256: context.compiled.morphology.morphology_spec_sha256,
        actuator_profile_sha256: Some(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
        capability_sha256: context.capability_sha256,
        threshold_profile_sha256: Some(context.threshold_profile_sha256),
        memory: Some(memory),
        controller_implemented: context.threshold_profile.physical_threshold_authority,
        physical_threshold_authority: context.threshold_profile.physical_threshold_authority,
        physical_question_opened: false,
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

fn validate_memory(memory: &RecoverySupervisorMemoryV1, context: &RecoveryContext) -> Result<()> {
    if memory.schema_version != RECOVERY_SUPERVISOR_MEMORY_V1_VERSION
        || memory.task_id != CANONICAL_PRONE_TO_STANDING_TASK_ID
        || memory.semantics_id != PORTABLE_RECOVERY_SEMANTICS_ID
        || memory.descriptor_sha256 != context.compiled.descriptor_sha256
        || memory.morphology_spec_sha256 != context.compiled.morphology.morphology_spec_sha256
        || memory.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || memory.actuator_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || memory.capability_sha256 != context.capability_sha256
        || memory.threshold_profile_id != context.threshold_profile.profile_id
        || memory.threshold_profile_sha256 != context.threshold_profile_sha256
    {
        return Err(CoreError::Frame(
            "recovery_memory_identity_invalid".to_owned(),
        ));
    }
    if memory.world_build_count != 0
        || memory.solver_step_count != 0
        || memory.physics_state_modified
        || memory.physical_acceptance_authority
        || memory.release_authority
    {
        return Err(CoreError::Frame(
            "recovery_memory_claim_or_side_effect_invalid".to_owned(),
        ));
    }
    if memory.total_steps_observed == 0 {
        if memory.start_semantic_step.is_some()
            || memory.last_semantic_step.is_some()
            || memory.initial_center_of_mass_height_m.is_some()
            || memory.phase_steps_observed != 0
            || !memory.ordered_completed_phases.is_empty()
        {
            return Err(CoreError::Time(
                "unstarted_recovery_memory_inconsistent".to_owned(),
            ));
        }
    } else if memory.start_semantic_step.is_none()
        || memory.last_semantic_step.is_none()
        || memory.initial_center_of_mass_height_m.is_none()
    {
        return Err(CoreError::Time(
            "started_recovery_memory_incomplete".to_owned(),
        ));
    }
    if memory.ordered_completed_phases.len() > 5
        || memory
            .ordered_completed_phases
            .iter()
            .zip(ORDERED_SUCCESS_PHASES)
            .any(|(actual, expected)| *actual != expected)
    {
        return Err(CoreError::Time(
            "recovery_completed_phase_prefix_invalid".to_owned(),
        ));
    }
    if !matches!(
        memory.phase,
        RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
    ) {
        let expected_phase = ORDERED_SUCCESS_PHASES
            .get(memory.ordered_completed_phases.len())
            .copied()
            .ok_or_else(|| CoreError::Time("recovery_phase_history_overflow".to_owned()))?;
        if memory.phase != expected_phase {
            return Err(CoreError::Time("recovery_phase_skip_detected".to_owned()));
        }
    }
    if matches!(
        memory.phase,
        RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
    ) != memory.terminal_failure_code.is_some()
    {
        return Err(CoreError::Time(
            "recovery_terminal_failure_identity_invalid".to_owned(),
        ));
    }
    Ok(())
}

fn validate_controller_ownership(
    ownership: &RecoveryControllerOwnershipReceiptV1,
    arm: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> std::result::Result<(), String> {
    if !ownership.source_measurement || ownership.fallback_controller_active {
        return Err("controller_ownership_source_or_fallback_invalid".to_owned());
    }
    let ids_valid = ownership
        .recovery_controller_id
        .as_deref()
        .is_none_or(valid_id)
        && ownership
            .stance_controller_id
            .as_deref()
            .is_none_or(valid_id);
    if !ids_valid {
        return Err("controller_ownership_id_invalid".to_owned());
    }
    match ownership.owner {
        RecoveryControllerOwnerV1::None => {
            if ownership.recovery_controller_id.is_some()
                || ownership.stance_controller_id.is_some()
                || ownership.handoff_event_count != 0
            {
                return Err("none_controller_ownership_inconsistent".to_owned());
            }
        }
        RecoveryControllerOwnerV1::Recovery => {
            if ownership.recovery_controller_id.is_none()
                || ownership.stance_controller_id.is_some()
                || ownership.handoff_event_count != 0
            {
                return Err("recovery_controller_ownership_inconsistent".to_owned());
            }
        }
        RecoveryControllerOwnerV1::Stance => {
            if ownership.recovery_controller_id.is_some()
                || ownership.stance_controller_id.is_none()
                || ownership.handoff_event_count != 1
            {
                return Err("stance_controller_ownership_inconsistent".to_owned());
            }
        }
    }
    match arm {
        RecoveryArmKindV1::MatchedZeroCommand => {
            if ownership.owner != RecoveryControllerOwnerV1::None {
                return Err("matched_zero_control_has_controller_owner".to_owned());
            }
        }
        RecoveryArmKindV1::CandidateCommand => match phase {
            RecoveryPhaseV1::ConfirmProne
            | RecoveryPhaseV1::EstablishDistalSupport
            | RecoveryPhaseV1::RaiseBody => {
                if ownership.owner != RecoveryControllerOwnerV1::Recovery {
                    return Err("active_recovery_phase_owner_invalid".to_owned());
                }
            }
            RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell => {
                if ownership.owner != RecoveryControllerOwnerV1::Stance {
                    return Err("stance_handoff_owner_invalid".to_owned());
                }
            }
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {}
        },
    }
    Ok(())
}

pub(crate) fn validate_body_clearance_observation_v1(
    body: &RecoveryBodyClearanceObservationV1,
    expected_adapter_id: &str,
    expected_body_id: &str,
) -> std::result::Result<(), String> {
    if body.adapter_id != expected_adapter_id
        || body.body_id != expected_body_id
        || body.classification_rule_id.trim().is_empty()
        || !body.foot_site_contacts_excluded
        || !body.source_measurement
    {
        return Err("body_clearance_order_or_source_invalid".to_owned());
    }
    finite(
        body.minimum_nonfoot_clearance_m,
        "minimum_nonfoot_clearance",
    )?;
    nonnegative(
        body.accumulated_nonfoot_normal_impulse_ns,
        "nonfoot_normal_impulse",
    )?;
    let mut engine_ids = HashSet::new();
    if body
        .engine_contact_ids
        .iter()
        .any(|id| id.trim().is_empty() || !engine_ids.insert(id.as_str()))
    {
        return Err("body_clearance_engine_contact_identity_invalid".to_owned());
    }
    if body.ventral_surface_contact && (body.body_id != "torso" || !body.nonfoot_contact_present) {
        return Err("ventral_contact_classification_invalid".to_owned());
    }

    // Native contact presence/provenance and signed geometric clearance are
    // independent source measurements. A negative clearance without a native
    // contact remains valid data and still fails the later clearance gate; it
    // must not be converted into invented contact provenance or invalid data.
    if body.nonfoot_contact_present {
        if body.engine_contact_ids.is_empty() {
            return Err("present_nonfoot_contact_provenance_invalid".to_owned());
        }
    } else if !body.engine_contact_ids.is_empty()
        || body.accumulated_nonfoot_normal_impulse_ns != 0.0
    {
        return Err("absent_nonfoot_contact_values_invalid".to_owned());
    }
    Ok(())
}

fn validate_observation<O: RecoveryObservationLike>(
    observation_value: &O,
    memory: &RecoverySupervisorMemoryV1,
    context: &RecoveryContext,
) -> std::result::Result<f64, String> {
    validate_observation_for_scope(
        observation_value, memory.arm_kind, Some(memory.phase), memory.last_semantic_step, context,
    )
}

/// `None` is the distinct passive-entry scope: no controller may own the
/// observed step. It does not relabel the candidate arm as a matched-zero arm.
fn validate_observation_for_scope<O: RecoveryObservationLike>(
    observation_value: &O,
    arm_kind: RecoveryArmKindV1,
    canonical_phase: Option<RecoveryPhaseV1>,
    last_semantic_step: Option<u64>,
    context: &RecoveryContext,
) -> std::result::Result<f64, String> {
    validate_observation_for_named_scope(observation_value, arm_kind, canonical_phase,
        last_semantic_step, context, CANONICAL_PRONE_TO_STANDING_TASK_ID, PORTABLE_RECOVERY_SEMANTICS_ID)
}

// Shared measurement validation only. A caller must explicitly select a
// registered task before using this kernel; observed identifiers stay intact.
#[allow(clippy::too_many_arguments)]
fn validate_observation_for_named_scope<O: RecoveryObservationLike>(
    observation_value: &O,
    arm_kind: RecoveryArmKindV1,
    canonical_phase: Option<RecoveryPhaseV1>,
    last_semantic_step: Option<u64>,
    context: &RecoveryContext,
    task_id: &str,
    semantics_id: &str,
) -> std::result::Result<f64, String> {
    let observation = observation_value.view();
    if observation.schema_version != O::expected_schema_version()
        || observation.task_id != task_id
        || observation.semantics_id != semantics_id
        || observation.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
    {
        return Err("observation_identity_invalid".to_owned());
    }
    finite(observation.outer_step_duration_s, "outer_step_duration_s")?;
    if observation.outer_step_duration_s.to_bits() != RECOVERY_OUTER_STEP_DURATION_S.to_bits() {
        return Err("outer_step_duration_invalid".to_owned());
    }
    if observation.semantic_step != observation.state.semantic_step
        || observation.semantic_step != observation.applied_actuation.source_semantic_step
        || observation.semantic_step != observation.engine_step_identity.semantic_step
    {
        return Err("semantic_step_identity_mismatch".to_owned());
    }
    observation
        .state
        .validate(&context.compiled.morphology)
        .map_err(|error| format!("state_frame_invalid:{error}"))?;
    if observation.state.adapter_capability_sha256 != context.capability_sha256 {
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
        if contact.provenance.adapter_id != context.adapter_id
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
        != context.compiled.morphology.ordered_contact_site_ids.len()
    {
        return Err("foot_bearing_cardinality_invalid".to_owned());
    }
    for (index, foot) in observation
        .ordered_foot_bearing_observations
        .iter()
        .enumerate()
    {
        if foot.contact_site_id != context.compiled.morphology.ordered_contact_site_ids[index]
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
        != context.compiled.morphology.ordered_body_ids.len()
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
            &context.adapter_id,
            &context.compiled.morphology.ordered_body_ids[index],
        )?;
    }

    let applied = &observation.applied_actuation;
    if applied.adapter_id != context.adapter_id
        || require_digest(
            &applied.adapter_receipt_sha256,
            "recovery.adapter_receipt_sha256",
        )
        .is_err()
        || !valid_id(&applied.command_id)
        || require_digest(&applied.command_sha256, "recovery.command_sha256").is_err()
        || applied.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || applied.actuator_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || !applied.source_measurement
        || applied.ordered_applied_impulses.len()
            != context.compiled.morphology.ordered_actuator_ids.len()
    {
        return Err("applied_actuation_receipt_invalid".to_owned());
    }
    if applied.zero_command != (arm_kind == RecoveryArmKindV1::MatchedZeroCommand) {
        return Err("actuation_arm_identity_invalid".to_owned());
    }
    for (index, item) in applied.ordered_applied_impulses.iter().enumerate() {
        if item.actuator_id != context.compiled.morphology.ordered_actuator_ids[index] {
            return Err("applied_actuation_order_invalid".to_owned());
        }
        finite(item.applied_angular_impulse_nms, "applied_angular_impulse")?;
        if item.applied_angular_impulse_nms.abs() > context.ordered_caps_nms[index] {
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
    if let Some(phase) = canonical_phase {
        validate_controller_ownership(&observation.controller_ownership, arm_kind, phase)?;
    } else {
        // Reuse the strict owner-none source/ID/fallback checks. The actual arm
        // identity was checked above; no observation field is rewritten.
        validate_controller_ownership(
            &observation.controller_ownership,
            RecoveryArmKindV1::MatchedZeroCommand,
            RecoveryPhaseV1::ConfirmProne,
        )?;
    }

    let energy_balance_residual_j = observation_value.validate_energy_balance()?;

    let engine = &observation.engine_step_identity;
    if engine.schema_version != RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION
        || engine.adapter_id != context.adapter_id
        || engine.engine != context.engine
        || engine.capability_sha256 != context.capability_sha256
        || require_digest(&engine.source_trace_sha256, "recovery.source_trace_sha256").is_err()
        || !engine.post_step_observation
        || engine.engine_identity_exposed_to_policy
    {
        return Err("engine_step_identity_invalid".to_owned());
    }
    match engine.source_kind {
        RecoveryObservationSourceKindV1::SyntheticZeroWorldCanary => {
            if context.threshold_profile.physical_threshold_authority
                || engine.native_solver_substep_count != 0
                || engine.host_step_after != engine.host_step_before.saturating_add(1)
            {
                return Err("synthetic_engine_step_identity_invalid".to_owned());
            }
        }
        RecoveryObservationSourceKindV1::NativePostStep => {
            if !context.threshold_profile.physical_threshold_authority {
                return Err(
                    "native_observation_requires_frozen_physical_threshold_profile".to_owned(),
                );
            }
            if engine.native_solver_substep_count != expected_native_substeps(context.engine)
                || engine.host_step_after != engine.host_step_before.saturating_add(1)
            {
                return Err("native_engine_step_identity_invalid".to_owned());
            }
        }
    }

    if let Some(last) = last_semantic_step
        && observation.semantic_step != last.saturating_add(1)
    {
        return Err("semantic_step_not_strictly_consecutive".to_owned());
    }
    Ok(energy_balance_residual_j)
}

fn classify_observation(
    observation: RecoveryObservationView<'_>,
    initial_center_of_mass_height_m: Option<f64>,
    context: &RecoveryContext,
    energy_balance_residual_j: f64,
) -> RecoveryPoseClassificationV1 {
    let thresholds = &context.threshold_profile;
    let torso_height_ratio = observation.state.base_pose_world.position_m.y
        / context.compiled.geometry.initial_torso_center_y_m;
    let torso_up_dot = torso_up_dot(&observation.state);
    let initial_com_height = initial_center_of_mass_height_m
        .unwrap_or(observation.center_of_mass.position_world_m.y);
    let center_of_mass_height_gain_m =
        observation.center_of_mass.position_world_m.y - initial_com_height;
    let all_four_distal_sites_bearing = observation
        .state
        .ordered_contact_observations
        .iter()
        .zip(observation.ordered_foot_bearing_observations)
        .all(|(base, supplement)| {
            base.presence == Some(true)
                && base.bears_support == Some(true)
                && supplement.ordinary_unilateral_contact
                && supplement.bearing_normal_impulse_ns
                    >= thresholds.distal_bearing_minimum_impulse_ns
        });
    let minimum_distal_bearing_impulse_ns = observation
        .ordered_foot_bearing_observations
        .iter()
        .map(|value| value.bearing_normal_impulse_ns)
        .fold(f64::INFINITY, f64::min);
    let any_nonfoot_contact = observation
        .ordered_body_clearance_observations
        .iter()
        .any(|value| value.nonfoot_contact_present);
    let torso_ventral_contact = observation
        .ordered_body_clearance_observations
        .iter()
        .any(|value| value.body_id == "torso" && value.ventral_surface_contact);
    let minimum_nonfoot_clearance_m = observation
        .ordered_body_clearance_observations
        .iter()
        .map(|value| value.minimum_nonfoot_clearance_m)
        .fold(f64::INFINITY, f64::min);
    let maximum_nonfoot_contact_impulse_ns = observation
        .ordered_body_clearance_observations
        .iter()
        .map(|value| value.accumulated_nonfoot_normal_impulse_ns)
        .fold(0.0_f64, f64::max);
    let terminal_linear_speed_m_s =
        vec_norm(observation.state.base_twist_world.linear_velocity_m_s);
    let terminal_angular_speed_rad_s =
        vec_norm(observation.state.base_twist_world.angular_velocity_rad_s);
    let joint_limits_respected = observation
        .state
        .ordered_joint_observations
        .iter()
        .zip(&context.compiled.morphology.morphology_spec.joints)
        .all(|(observed, spec)| {
            observed
                .position_rad
                .is_some_and(|value| value >= spec.lower_limit_rad && value <= spec.upper_limit_rad)
        });
    let actuator_budget_respected = observation
        .applied_actuation
        .ordered_applied_impulses
        .iter()
        .zip(&context.ordered_caps_nms)
        .all(|(observed, cap)| observed.applied_angular_impulse_nms.abs() <= *cap);
    let intervention_counter_total = observation.external_interventions.total_count();
    let entry_prone_gate = torso_height_ratio <= thresholds.entry_prone_height_ratio_max
        && torso_up_dot <= thresholds.entry_torso_up_dot_max
        && torso_ventral_contact;
    let distal_support_gate = all_four_distal_sites_bearing;
    let raised_body_gate = center_of_mass_height_gain_m >= thresholds.minimum_com_height_gain_m
        && minimum_nonfoot_clearance_m >= thresholds.minimum_nonfoot_clearance_m
        && !any_nonfoot_contact;
    let exclusive_stance_handoff_gate =
        observation.controller_ownership.owner == RecoveryControllerOwnerV1::Stance;
    let safety_gate = joint_limits_respected
        && actuator_budget_respected
        && maximum_nonfoot_contact_impulse_ns <= thresholds.maximum_forbidden_contact_impulse_ns
        && energy_balance_residual_j <= thresholds.maximum_energy_balance_residual_j;
    let no_cheat_gate = intervention_counter_total == 0;
    let stable_stance_gate = torso_height_ratio >= thresholds.stance_height_ratio_min
        && torso_up_dot >= thresholds.stance_torso_up_dot_min
        && all_four_distal_sites_bearing
        && !any_nonfoot_contact
        && minimum_nonfoot_clearance_m >= thresholds.minimum_nonfoot_clearance_m
        && terminal_linear_speed_m_s <= thresholds.maximum_terminal_linear_speed_m_s
        && terminal_angular_speed_rad_s <= thresholds.maximum_terminal_angular_speed_rad_s
        && exclusive_stance_handoff_gate
        && safety_gate
        && no_cheat_gate;
    let pose_class = if stable_stance_gate {
        RecoveryPoseClassV1::StableFourFootStance
    } else if entry_prone_gate {
        RecoveryPoseClassV1::VentralProne
    } else if raised_body_gate {
        RecoveryPoseClassV1::RaisedBody
    } else if distal_support_gate {
        RecoveryPoseClassV1::DistalSupport
    } else {
        RecoveryPoseClassV1::Transitional
    };
    RecoveryPoseClassificationV1 {
        pose_class,
        torso_height_ratio,
        torso_up_dot,
        center_of_mass_height_gain_m,
        all_four_distal_sites_bearing,
        minimum_distal_bearing_impulse_ns,
        any_nonfoot_contact,
        torso_ventral_contact,
        minimum_nonfoot_clearance_m,
        maximum_nonfoot_contact_impulse_ns,
        terminal_linear_speed_m_s,
        terminal_angular_speed_rad_s,
        energy_balance_residual_j,
        joint_limits_respected,
        actuator_budget_respected,
        intervention_counter_total,
        entry_prone_gate,
        distal_support_gate,
        raised_body_gate,
        exclusive_stance_handoff_gate,
        stable_stance_gate,
        safety_gate,
        no_cheat_gate,
        physical_threshold_authority: thresholds.physical_threshold_authority,
        physical_result: thresholds.physical_threshold_authority && stable_stance_gate,
    }
}

fn transition_to(memory: &mut RecoverySupervisorMemoryV1, next: RecoveryPhaseV1) {
    memory.ordered_completed_phases.push(memory.phase);
    memory.phase = next;
    memory.phase_steps_observed = 0;
}

fn record_recovery_observation(
    memory: &mut RecoverySupervisorMemoryV1,
    semantic_step: u64,
    center_of_mass_height_m: f64,
) {
    if memory.total_steps_observed == 0 {
        memory.start_semantic_step = Some(semantic_step);
        memory.initial_center_of_mass_height_m = Some(center_of_mass_height_m);
    }
    memory.last_semantic_step = Some(semantic_step);
    memory.total_steps_observed = memory.total_steps_observed.saturating_add(1);
    memory.phase_steps_observed = memory.phase_steps_observed.saturating_add(1);
}

fn terminal_failure(memory: &mut RecoverySupervisorMemoryV1, code: String, refused: bool) {
    memory.phase = if refused {
        RecoveryPhaseV1::Refused
    } else {
        RecoveryPhaseV1::Failed
    };
    memory.terminal_failure_code = Some(code);
}

fn invalid_step_receipt(
    prior_phase: RecoveryPhaseV1,
    mut memory: RecoverySupervisorMemoryV1,
    reason: String,
) -> RecoveryStepReceiptV1 {
    terminal_failure(&mut memory, reason.clone(), true);
    RecoveryStepReceiptV1 {
        schema_version: RECOVERY_STEP_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::InvalidObservation,
        refusal_reason: Some(reason),
        observation_sha256: None,
        prior_phase,
        next_phase: RecoveryPhaseV1::Refused,
        transitioned: false,
        classification: None,
        memory: Some(memory),
        post_step_observation_only: true,
        phase_skip_permitted: false,
        controller_command_emitted: false,
        controller_implemented: false,
        synthetic_canary_semantics_executed: false,
        physical_threshold_authority: false,
        physical_result: false,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    }
}

struct RecoveryStepAuthorityContext<'a> {
    authority: &'a RecoveryEnergyPartitionAuthorityV1,
    authority_sha256: &'a str,
}

struct RecoveryStepComputation {
    step: RecoveryStepReceiptV1,
    development_progression: Option<RecoveryDevelopmentProgressionReceiptV1>,
}

fn development_nonenergy_safety_gate(classification: &RecoveryPoseClassificationV1) -> bool {
    classification.joint_limits_respected
        && classification.actuator_budget_respected
        && classification.maximum_nonfoot_contact_impulse_ns == 0.0
        && classification.no_cheat_gate
}

fn finalize_step_computation(
    step: RecoveryStepReceiptV1,
    authority_context: Option<RecoveryStepAuthorityContext<'_>>,
    development_progression_used: bool,
) -> RecoveryStepComputation {
    let development_progression = authority_context.map(|context| {
        let classification = step.classification.as_ref();
        let legacy_safety_gate = classification.is_some_and(|value| value.safety_gate);
        let legacy_stable_stance_gate =
            classification.is_some_and(|value| value.stable_stance_gate);
        let development_nonenergy_safety_gate =
            classification.is_some_and(development_nonenergy_safety_gate);
        let development_stance_handoff_gate = context.authority.development_progression_permitted
            && classification.is_some_and(|value| value.raised_body_gate)
            && development_nonenergy_safety_gate;
        RecoveryDevelopmentProgressionReceiptV1 {
            schema_version: RECOVERY_DEVELOPMENT_PROGRESSION_RECEIPT_V1_VERSION.to_owned(),
            energy_partition_authority_sha256: context.authority_sha256.to_owned(),
            authority_profile_id: context.authority.authority_profile_id.clone(),
            component_partition_complete: context.authority.component_partition_complete,
            exact_balance_safety_authority: context.authority.exact_balance_safety_authority,
            legacy_safety_gate,
            legacy_stable_stance_gate,
            acceptance_safety_gate: legacy_safety_gate
                && context.authority.exact_balance_safety_authority,
            development_nonenergy_safety_gate,
            development_stance_handoff_gate,
            development_progression_permitted: context.authority.development_progression_permitted,
            development_progression_used,
            stable_stance_completion_authorized: context.authority.component_partition_complete
                && context.authority.exact_balance_safety_authority,
            physical_result_authorized: step.physical_result
                && context.authority.component_partition_complete
                && context.authority.exact_balance_safety_authority,
            prone_to_standing_claimed: false,
            physical_acceptance_authority: false,
            release_authority: false,
            world_build_count: 0,
            solver_step_count: 0,
            physics_state_modified: false,
        }
    });
    RecoveryStepComputation {
        step,
        development_progression,
    }
}

pub fn step_recovery_v1(request: RecoveryStepRequestV1) -> Result<RecoveryStepReceiptV1> {
    if request.schema_version != RECOVERY_STEP_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_step_request_version".to_owned(),
        ));
    }
    step_recovery(
        request.descriptor,
        request.adapter_capability,
        request.memory,
        request.observation,
        None,
    )
}

pub fn step_recovery_v2(request: RecoveryStepRequestV2) -> Result<RecoveryStepReceiptV1> {
    if request.schema_version != RECOVERY_STEP_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_step_request_version".to_owned(),
        ));
    }
    let morphology_context = request.morphology_context;
    step_recovery(
        request.descriptor,
        request.adapter_capability,
        request.memory,
        request.observation,
        Some(&morphology_context),
    )
}

pub fn step_recovery_v3(request: RecoveryStepRequestV3) -> Result<RecoveryStepReceiptV1> {
    if request.schema_version != RECOVERY_STEP_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_step_request_version".to_owned(),
        ));
    }
    let morphology_context = request.morphology_context;
    step_recovery(
        request.descriptor,
        request.adapter_capability,
        request.memory,
        request.observation,
        Some(&morphology_context),
    )
}

pub fn step_recovery_v4(request: RecoveryStepRequestV4) -> Result<RecoveryStepReceiptV1> {
    if request.schema_version != RECOVERY_STEP_REQUEST_V4_VERSION {
        return Err(CoreError::Schema(
            "recovery_step_request_version".to_owned(),
        ));
    }
    let morphology_context = request.morphology_context;
    step_recovery(
        request.descriptor,
        request.adapter_capability,
        request.memory,
        request.observation,
        Some(&morphology_context),
    )
}

pub fn step_recovery_v5(request: RecoveryStepRequestV5) -> Result<RecoveryStepReceiptV2> {
    if request.schema_version != RECOVERY_STEP_REQUEST_V5_VERSION {
        return Err(CoreError::Schema(
            "recovery_step_request_version".to_owned(),
        ));
    }
    let authority_sha256 = validate_recovery_energy_partition_authority_v1(
        &request.energy_partition_authority,
        &request.observation,
        &request.adapter_capability,
    )?;
    let morphology_context = request.morphology_context;
    let computation = step_recovery_internal(
        request.descriptor,
        request.adapter_capability,
        request.memory,
        request.observation,
        Some(&morphology_context),
        Some(RecoveryStepAuthorityContext {
            authority: &request.energy_partition_authority,
            authority_sha256: &authority_sha256,
        }),
    )?;
    Ok(RecoveryStepReceiptV2 {
        schema_version: RECOVERY_STEP_RECEIPT_V2_VERSION.to_owned(),
        step: computation.step,
        development_progression: computation
            .development_progression
            .expect("V5 always supplies a validated energy authority"),
    })
}

fn step_recovery<O: RecoveryObservationLike>(
    descriptor: BoundedQuadrupedDescriptor,
    adapter_capability: RecoveryAdapterCapabilityV1,
    memory: RecoverySupervisorMemoryV1,
    observation: O,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<RecoveryStepReceiptV1> {
    step_recovery_internal(
        descriptor,
        adapter_capability,
        memory,
        observation,
        morphology_context,
        None,
    )
    .map(|computation| computation.step)
}

fn step_recovery_internal<O: RecoveryObservationLike>(
    descriptor: BoundedQuadrupedDescriptor,
    adapter_capability: RecoveryAdapterCapabilityV1,
    memory: RecoverySupervisorMemoryV1,
    observation: O,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
    authority_context: Option<RecoveryStepAuthorityContext<'_>>,
) -> Result<RecoveryStepComputation> {
    let prior_phase = memory.phase;
    let resolution = context_for(
        &memory.task_id,
        &memory.semantics_id,
        &memory.actuator_profile_id,
        &memory.threshold_profile_id,
        descriptor,
        morphology_context,
        &adapter_capability,
    )?;
    let context = match resolution {
        RecoveryContextResolution::Supported(value) => *value,
        RecoveryContextResolution::Refused { status, reason, .. } => {
            return Ok(finalize_step_computation(
                RecoveryStepReceiptV1 {
                    schema_version: RECOVERY_STEP_RECEIPT_V1_VERSION.to_owned(),
                    support_status: status,
                    refusal_reason: Some(reason),
                    observation_sha256: None,
                    prior_phase,
                    next_phase: RecoveryPhaseV1::Refused,
                    transitioned: false,
                    classification: None,
                    memory: None,
                    post_step_observation_only: true,
                    phase_skip_permitted: false,
                    controller_command_emitted: false,
                    controller_implemented: false,
                    synthetic_canary_semantics_executed: false,
                    physical_threshold_authority: false,
                    physical_result: false,
                    world_build_count: 0,
                    solver_step_count: 0,
                    physics_state_modified: false,
                    prone_to_standing_claimed: false,
                    physical_acceptance_authority: false,
                    release_authority: false,
                },
                authority_context,
                false,
            ));
        }
    };
    validate_memory(&memory, &context)?;
    if matches!(
        memory.phase,
        RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
    ) {
        return Err(CoreError::Time(
            "recovery_terminal_memory_cannot_step".to_owned(),
        ));
    }
    let energy_balance_residual_j = match validate_observation(&observation, &memory, &context) {
        Ok(value) => value,
        Err(reason) => {
            return Ok(finalize_step_computation(
                invalid_step_receipt(prior_phase, memory, reason),
                authority_context,
                false,
            ));
        }
    };
    let observation_sha256 = digest_serializable(&observation)?;
    let observation_view = observation.view();
    let classification = classify_observation(
        observation_view,
        memory.initial_center_of_mass_height_m,
        &context,
        energy_balance_residual_j,
    );
    let semantic_step = observation_view.semantic_step;
    let center_of_mass_height_m = observation_view.center_of_mass.position_world_m.y;
    let mut memory = memory;
    record_recovery_observation(&mut memory, semantic_step, center_of_mass_height_m);

    let mut development_progression_used = false;
    match memory.phase {
        RecoveryPhaseV1::ConfirmProne => {
            if classification.entry_prone_gate {
                memory.prone_confirm_steps_observed =
                    memory.prone_confirm_steps_observed.saturating_add(1);
            } else {
                memory.prone_confirm_steps_observed = 0;
            }
            if memory.prone_confirm_steps_observed
                >= context.threshold_profile.entry_prone_confirm_steps
            {
                transition_to(&mut memory, RecoveryPhaseV1::EstablishDistalSupport);
            }
        }
        RecoveryPhaseV1::EstablishDistalSupport => {
            if classification.distal_support_gate {
                transition_to(&mut memory, RecoveryPhaseV1::RaiseBody);
            }
        }
        RecoveryPhaseV1::RaiseBody => {
            let acceptance_handoff_gate = classification.raised_body_gate
                && classification.safety_gate
                && authority_context
                    .as_ref()
                    .is_none_or(|context| context.authority.exact_balance_safety_authority);
            let development_handoff_gate = authority_context.as_ref().is_some_and(|context| {
                context.authority.development_progression_permitted
                    && classification.raised_body_gate
                    && development_nonenergy_safety_gate(&classification)
            });
            if acceptance_handoff_gate || development_handoff_gate {
                development_progression_used = development_handoff_gate && !acceptance_handoff_gate;
                transition_to(&mut memory, RecoveryPhaseV1::StanceHandoff);
            }
        }
        RecoveryPhaseV1::StanceHandoff => {
            if classification.exclusive_stance_handoff_gate {
                transition_to(&mut memory, RecoveryPhaseV1::StanceDwell);
            }
        }
        RecoveryPhaseV1::StanceDwell => {
            let stable_stance_completion_authorized =
                authority_context.as_ref().is_none_or(|context| {
                    context.authority.component_partition_complete
                        && context.authority.exact_balance_safety_authority
                });
            if classification.stable_stance_gate && stable_stance_completion_authorized {
                memory.stance_dwell_steps_observed =
                    memory.stance_dwell_steps_observed.saturating_add(1);
            } else {
                memory.stance_dwell_steps_observed = 0;
            }
            if memory.stance_dwell_steps_observed >= context.threshold_profile.stance_dwell_steps {
                transition_to(&mut memory, RecoveryPhaseV1::Complete);
            }
        }
        RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {
            unreachable!("terminal phases were rejected before phase advancement")
        }
    }

    if !matches!(memory.phase, RecoveryPhaseV1::Complete) {
        if memory.total_steps_observed >= context.threshold_profile.total_timeout_steps {
            terminal_failure(&mut memory, "total_timeout".to_owned(), false);
        } else if context
            .threshold_profile
            .per_phase_timeout_steps
            .for_phase(memory.phase)
            .is_some_and(|limit| memory.phase_steps_observed >= limit)
        {
            let timed_out_phase = memory.phase.phase_id();
            terminal_failure(
                &mut memory,
                format!("phase_timeout:{timed_out_phase}"),
                false,
            );
        }
    }
    let next_phase = memory.phase;
    let physical_threshold_authority = context.threshold_profile.physical_threshold_authority;
    let physical_result = physical_threshold_authority && next_phase == RecoveryPhaseV1::Complete;
    Ok(finalize_step_computation(
        RecoveryStepReceiptV1 {
            schema_version: RECOVERY_STEP_RECEIPT_V1_VERSION.to_owned(),
            support_status: RecoverySupportStatusV1::SupportedExact,
            refusal_reason: None,
            observation_sha256: Some(observation_sha256),
            prior_phase,
            next_phase,
            transitioned: next_phase != prior_phase,
            classification: Some(classification),
            memory: Some(memory),
            post_step_observation_only: true,
            phase_skip_permitted: false,
            controller_command_emitted: false,
            controller_implemented: physical_threshold_authority,
            synthetic_canary_semantics_executed: !physical_threshold_authority,
            physical_threshold_authority,
            physical_result,
            world_build_count: 0,
            solver_step_count: 0,
            physics_state_modified: false,
            prone_to_standing_claimed: physical_result,
            physical_acceptance_authority: false,
            release_authority: false,
        },
        authority_context,
        development_progression_used,
    ))
}

fn initial_state_sha256<O: RecoveryObservationLike>(observation_value: &O) -> Result<String> {
    let observation = observation_value.view();
    digest_json(&json!({
        "base_pose_world": observation.state.base_pose_world,
        "base_twist_world": observation.state.base_twist_world,
        "ordered_joint_observations": observation.state.ordered_joint_observations,
        "ordered_contact_observations": observation.state.ordered_contact_observations,
        "gravity_world_m_s2": observation.state.gravity_world_m_s2,
        "task_frame": observation.state.task_frame,
        "center_of_mass": observation.center_of_mass,
        "ordered_foot_bearing_observations": observation.ordered_foot_bearing_observations,
        "ordered_body_clearance_observations": observation.ordered_body_clearance_observations,
        "energy_initial_mechanical_j": observation_value.initial_mechanical_energy_j(),
        "energy_current_mechanical_j": observation_value.current_mechanical_energy_j(),
    }))
}

pub(crate) fn recovery_observation_base_sha256<O: RecoveryObservationLike>(
    observation_value: &O,
) -> Result<String> {
    let observation = observation_value.view();
    digest_json(&json!({
        "task_id": observation.task_id,
        "semantics_id": observation.semantics_id,
        "actuator_profile_id": observation.actuator_profile_id,
        "semantic_step": observation.semantic_step,
        "outer_step_duration_s": observation.outer_step_duration_s,
        "state": observation.state,
        "center_of_mass": observation.center_of_mass,
        "ordered_foot_bearing_observations": observation.ordered_foot_bearing_observations,
        "ordered_body_clearance_observations": observation.ordered_body_clearance_observations,
        "applied_actuation": observation.applied_actuation,
        "external_interventions": observation.external_interventions,
        "controller_ownership": observation.controller_ownership,
        "engine_step_identity": observation.engine_step_identity,
    }))
}

struct RecoveryTraceInput<'a, O> {
    schema_version: &'a str,
    expected_schema_version: &'static str,
    arm_kind: RecoveryArmKindV1,
    declared_initial_state_sha256: &'a str,
    observations: &'a [O],
}

struct RecoveryEvaluationInput<'a, O> {
    task_id: &'a str,
    semantics_id: &'a str,
    actuator_profile_id: &'a str,
    threshold_profile_id: &'a str,
    descriptor: &'a BoundedQuadrupedDescriptor,
    adapter_capability: &'a RecoveryAdapterCapabilityV1,
    development_replay_authority: Option<&'a RecoveryEnergyPartitionAuthorityV1>,
    candidate_trace: RecoveryTraceInput<'a, O>,
    matched_zero_command_trace: RecoveryTraceInput<'a, O>,
}

fn replay_trace<O: RecoveryObservationLike>(
    common: &RecoveryEvaluationInput<'_, O>,
    trace: &RecoveryTraceInput<'_, O>,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<(RecoveryTraceReplayReceiptV1, bool)> {
    if trace.schema_version != trace.expected_schema_version {
        return Err(CoreError::Schema("recovery_trace_version".to_owned()));
    }
    require_digest(
        &trace.declared_initial_state_sha256,
        "recovery.declared_initial_state_sha256",
    )?;
    if trace.observations.is_empty() {
        return Ok((
            RecoveryTraceReplayReceiptV1 {
                arm_kind: trace.arm_kind,
                observation_count: 0,
                accepted_observation_count: 0,
                final_phase: RecoveryPhaseV1::Refused,
                terminal_failure_code: Some("empty_trace".to_owned()),
                completed: false,
                refused: true,
            },
            false,
        ));
    }
    let observed_initial_sha256 = initial_state_sha256(&trace.observations[0])?;
    let initial_identity_valid = observed_initial_sha256 == trace.declared_initial_state_sha256;
    if !initial_identity_valid {
        return Ok((
            RecoveryTraceReplayReceiptV1 {
                arm_kind: trace.arm_kind,
                observation_count: trace.observations.len(),
                accepted_observation_count: 0,
                final_phase: RecoveryPhaseV1::Refused,
                terminal_failure_code: Some("declared_initial_state_digest_mismatch".to_owned()),
                completed: false,
                refused: true,
            },
            false,
        ));
    }

    let initialization = initialize_recovery(
        RecoveryInitializeRequestV1 {
            schema_version: RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
            task_id: common.task_id.to_owned(),
            semantics_id: common.semantics_id.to_owned(),
            actuator_profile_id: common.actuator_profile_id.to_owned(),
            threshold_profile_id: common.threshold_profile_id.to_owned(),
            descriptor: common.descriptor.clone(),
            adapter_capability: common.adapter_capability.clone(),
            arm_kind: trace.arm_kind,
        },
        morphology_context,
    )?;
    let Some(mut memory) = initialization.memory else {
        return Ok((
            RecoveryTraceReplayReceiptV1 {
                arm_kind: trace.arm_kind,
                observation_count: trace.observations.len(),
                accepted_observation_count: 0,
                final_phase: RecoveryPhaseV1::Refused,
                terminal_failure_code: initialization.refusal_reason,
                completed: false,
                refused: true,
            },
            true,
        ));
    };
    let mut accepted = 0;
    for observation in trace.observations {
        let receipt = if let Some(authority) = common.development_replay_authority {
            let authority_sha256 = observation
                .validate_development_replay_authority(authority, common.adapter_capability)?;
            step_recovery_internal(
                common.descriptor.clone(),
                common.adapter_capability.clone(),
                memory,
                observation.clone(),
                morphology_context,
                Some(RecoveryStepAuthorityContext {
                    authority,
                    authority_sha256: &authority_sha256,
                }),
            )?
            .step
        } else {
            step_recovery(
                common.descriptor.clone(),
                common.adapter_capability.clone(),
                memory,
                observation.clone(),
                morphology_context,
            )?
        };
        if receipt.support_status != RecoverySupportStatusV1::SupportedExact {
            return Ok((
                RecoveryTraceReplayReceiptV1 {
                    arm_kind: trace.arm_kind,
                    observation_count: trace.observations.len(),
                    accepted_observation_count: accepted,
                    final_phase: RecoveryPhaseV1::Refused,
                    terminal_failure_code: receipt.refusal_reason,
                    completed: false,
                    refused: true,
                },
                true,
            ));
        }
        accepted += 1;
        memory = receipt.memory.ok_or_else(|| {
            CoreError::Internal("supported_recovery_step_missing_memory".to_owned())
        })?;
        if matches!(
            memory.phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        ) {
            break;
        }
    }
    Ok((
        RecoveryTraceReplayReceiptV1 {
            arm_kind: trace.arm_kind,
            observation_count: trace.observations.len(),
            accepted_observation_count: accepted,
            final_phase: memory.phase,
            terminal_failure_code: memory.terminal_failure_code.clone(),
            completed: memory.phase == RecoveryPhaseV1::Complete,
            refused: memory.phase == RecoveryPhaseV1::Refused,
        },
        true,
    ))
}

fn evaluation_refusal(
    status: RecoverySupportStatusV1,
    reason: String,
    descriptor_sha256: String,
    morphology_spec_sha256: String,
    capability_sha256: String,
) -> RecoveryEvaluationReceiptV1 {
    RecoveryEvaluationReceiptV1 {
        schema_version: RECOVERY_EVALUATION_RECEIPT_V1_VERSION.to_owned(),
        support_status: status,
        refusal_reason: Some(reason),
        verdict: RecoveryEvaluationVerdictV1::Refused,
        descriptor_sha256,
        morphology_spec_sha256,
        actuator_profile_sha256: None,
        capability_sha256,
        threshold_profile_sha256: None,
        candidate_trace: None,
        matched_zero_command_trace: None,
        initial_state_identity_matched: false,
        candidate_synthetic_path_completed: false,
        matched_zero_command_control_failed_to_complete: false,
        candidate_physical_path_completed: false,
        matched_zero_command_physical_control_failed_to_complete: false,
        physical_development_trace_valid: false,
        all_negative_control_requirements_enforced: false,
        controller_implemented: false,
        synthetic_canary_passed: false,
        physical_threshold_authority: false,
        physical_question_opened: false,
        physical_result: false,
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

pub fn evaluate_recovery_trace_v1(
    request: RecoveryEvaluationRequestV1,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.schema_version != RECOVERY_EVALUATION_REQUEST_V1_VERSION {
        return Err(CoreError::Schema(
            "recovery_evaluation_request_version".to_owned(),
        ));
    }
    let input = RecoveryEvaluationInput {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        threshold_profile_id: &request.threshold_profile_id,
        descriptor: &request.descriptor,
        adapter_capability: &request.adapter_capability,
        development_replay_authority: None,
        candidate_trace: RecoveryTraceInput {
            schema_version: &request.candidate_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V1_VERSION,
            arm_kind: request.candidate_trace.arm_kind,
            declared_initial_state_sha256: &request.candidate_trace.declared_initial_state_sha256,
            observations: &request.candidate_trace.observations,
        },
        matched_zero_command_trace: RecoveryTraceInput {
            schema_version: &request.matched_zero_command_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V1_VERSION,
            arm_kind: request.matched_zero_command_trace.arm_kind,
            declared_initial_state_sha256: &request
                .matched_zero_command_trace
                .declared_initial_state_sha256,
            observations: &request.matched_zero_command_trace.observations,
        },
    };
    evaluate_recovery_trace(&input, None)
}

pub fn evaluate_recovery_trace_v2(
    request: RecoveryEvaluationRequestV2,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.schema_version != RECOVERY_EVALUATION_REQUEST_V2_VERSION {
        return Err(CoreError::Schema(
            "recovery_evaluation_request_version".to_owned(),
        ));
    }
    let input = RecoveryEvaluationInput {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        threshold_profile_id: &request.threshold_profile_id,
        descriptor: &request.descriptor,
        adapter_capability: &request.adapter_capability,
        development_replay_authority: None,
        candidate_trace: RecoveryTraceInput {
            schema_version: &request.candidate_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V1_VERSION,
            arm_kind: request.candidate_trace.arm_kind,
            declared_initial_state_sha256: &request.candidate_trace.declared_initial_state_sha256,
            observations: &request.candidate_trace.observations,
        },
        matched_zero_command_trace: RecoveryTraceInput {
            schema_version: &request.matched_zero_command_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V1_VERSION,
            arm_kind: request.matched_zero_command_trace.arm_kind,
            declared_initial_state_sha256: &request
                .matched_zero_command_trace
                .declared_initial_state_sha256,
            observations: &request.matched_zero_command_trace.observations,
        },
    };
    evaluate_recovery_trace(&input, Some(&request.morphology_context))
}

pub fn evaluate_recovery_trace_v3(
    request: RecoveryEvaluationRequestV3,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.schema_version != RECOVERY_EVALUATION_REQUEST_V3_VERSION {
        return Err(CoreError::Schema(
            "recovery_evaluation_request_version".to_owned(),
        ));
    }
    let input = RecoveryEvaluationInput {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        threshold_profile_id: &request.threshold_profile_id,
        descriptor: &request.descriptor,
        adapter_capability: &request.adapter_capability,
        development_replay_authority: None,
        candidate_trace: RecoveryTraceInput {
            schema_version: &request.candidate_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V2_VERSION,
            arm_kind: request.candidate_trace.arm_kind,
            declared_initial_state_sha256: &request.candidate_trace.declared_initial_state_sha256,
            observations: &request.candidate_trace.observations,
        },
        matched_zero_command_trace: RecoveryTraceInput {
            schema_version: &request.matched_zero_command_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V2_VERSION,
            arm_kind: request.matched_zero_command_trace.arm_kind,
            declared_initial_state_sha256: &request
                .matched_zero_command_trace
                .declared_initial_state_sha256,
            observations: &request.matched_zero_command_trace.observations,
        },
    };
    evaluate_recovery_trace(&input, Some(&request.morphology_context))
}

pub fn evaluate_recovery_trace_v4(
    request: RecoveryEvaluationRequestV4,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.schema_version != RECOVERY_EVALUATION_REQUEST_V4_VERSION {
        return Err(CoreError::Schema(
            "recovery_evaluation_request_version".to_owned(),
        ));
    }
    let input = RecoveryEvaluationInput {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        threshold_profile_id: &request.threshold_profile_id,
        descriptor: &request.descriptor,
        adapter_capability: &request.adapter_capability,
        development_replay_authority: None,
        candidate_trace: RecoveryTraceInput {
            schema_version: &request.candidate_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V3_VERSION,
            arm_kind: request.candidate_trace.arm_kind,
            declared_initial_state_sha256: &request.candidate_trace.declared_initial_state_sha256,
            observations: &request.candidate_trace.observations,
        },
        matched_zero_command_trace: RecoveryTraceInput {
            schema_version: &request.matched_zero_command_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V3_VERSION,
            arm_kind: request.matched_zero_command_trace.arm_kind,
            declared_initial_state_sha256: &request
                .matched_zero_command_trace
                .declared_initial_state_sha256,
            observations: &request.matched_zero_command_trace.observations,
        },
    };
    evaluate_recovery_trace(&input, Some(&request.morphology_context))
}

pub fn evaluate_recovery_trace_v5(
    request: RecoveryEvaluationRequestV5,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.schema_version != RECOVERY_EVALUATION_REQUEST_V5_VERSION {
        return Err(CoreError::Schema(
            "recovery_evaluation_request_version".to_owned(),
        ));
    }
    let input = RecoveryEvaluationInput {
        task_id: &request.task_id,
        semantics_id: &request.semantics_id,
        actuator_profile_id: &request.actuator_profile_id,
        threshold_profile_id: &request.threshold_profile_id,
        descriptor: &request.descriptor,
        adapter_capability: &request.adapter_capability,
        development_replay_authority: Some(&request.energy_partition_authority),
        candidate_trace: RecoveryTraceInput {
            schema_version: &request.candidate_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V3_VERSION,
            arm_kind: request.candidate_trace.arm_kind,
            declared_initial_state_sha256: &request.candidate_trace.declared_initial_state_sha256,
            observations: &request.candidate_trace.observations,
        },
        matched_zero_command_trace: RecoveryTraceInput {
            schema_version: &request.matched_zero_command_trace.schema_version,
            expected_schema_version: RECOVERY_TRACE_V3_VERSION,
            arm_kind: request.matched_zero_command_trace.arm_kind,
            declared_initial_state_sha256: &request
                .matched_zero_command_trace
                .declared_initial_state_sha256,
            observations: &request.matched_zero_command_trace.observations,
        },
    };
    evaluate_recovery_trace(&input, Some(&request.morphology_context))
}

fn evaluate_recovery_trace<O: RecoveryObservationLike>(
    request: &RecoveryEvaluationInput<'_, O>,
    morphology_context: Option<&RecoveryMorphologyContextV1>,
) -> Result<RecoveryEvaluationReceiptV1> {
    if request.candidate_trace.arm_kind != RecoveryArmKindV1::CandidateCommand
        || request.matched_zero_command_trace.arm_kind != RecoveryArmKindV1::MatchedZeroCommand
    {
        return Err(CoreError::Schema(
            "recovery_trace_arm_assignment_invalid".to_owned(),
        ));
    }
    let resolution = context_for(
        &request.task_id,
        &request.semantics_id,
        &request.actuator_profile_id,
        &request.threshold_profile_id,
        request.descriptor.clone(),
        morphology_context,
        &request.adapter_capability,
    )?;
    let context = match resolution {
        RecoveryContextResolution::Supported(value) => *value,
        RecoveryContextResolution::Refused {
            status,
            reason,
            compiled,
            capability_sha256,
        } => {
            return Ok(evaluation_refusal(
                status,
                reason,
                compiled.descriptor_sha256,
                compiled.morphology.morphology_spec_sha256,
                capability_sha256,
            ));
        }
    };
    let (candidate, candidate_initial_valid) =
        replay_trace(&request, &request.candidate_trace, morphology_context)?;
    let (zero, zero_initial_valid) = replay_trace(
        &request,
        &request.matched_zero_command_trace,
        morphology_context,
    )?;
    let initial_state_identity_matched = candidate_initial_valid
        && zero_initial_valid
        && request.candidate_trace.declared_initial_state_sha256
            == request
                .matched_zero_command_trace
                .declared_initial_state_sha256;
    let physical_threshold_authority = context.threshold_profile.physical_threshold_authority;
    let candidate_synthetic_path_completed =
        !physical_threshold_authority && candidate.completed && !candidate.refused;
    let matched_zero_command_control_failed_to_complete = !physical_threshold_authority
        && !zero.completed
        && !zero.refused
        && zero.final_phase == RecoveryPhaseV1::Failed;
    let synthetic_canary_passed = !physical_threshold_authority
        && initial_state_identity_matched
        && candidate_synthetic_path_completed
        && matched_zero_command_control_failed_to_complete;
    let physical_development_trace_valid = physical_threshold_authority
        && initial_state_identity_matched
        && !candidate.refused
        && !zero.refused
        && candidate.accepted_observation_count == candidate.observation_count
        && zero.accepted_observation_count == zero.observation_count;
    let candidate_physical_path_completed = physical_development_trace_valid && candidate.completed;
    let matched_zero_command_physical_control_failed_to_complete = physical_development_trace_valid
        && !zero.completed
        && zero.final_phase == RecoveryPhaseV1::Failed;
    let physical_development_passed = candidate_physical_path_completed
        && matched_zero_command_physical_control_failed_to_complete;
    let physical_development_incomplete = physical_development_trace_valid
        && !candidate.completed
        && candidate.final_phase != RecoveryPhaseV1::Failed
        && !zero.completed
        && zero.final_phase != RecoveryPhaseV1::Failed;
    let verdict = if candidate.refused || zero.refused || !initial_state_identity_matched {
        RecoveryEvaluationVerdictV1::Refused
    } else if physical_development_passed {
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentPassed
    } else if physical_development_incomplete {
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentIncomplete
    } else if physical_threshold_authority {
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentFailed
    } else if synthetic_canary_passed {
        RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
    } else {
        RecoveryEvaluationVerdictV1::SyntheticCanaryFailed
    };
    let support_status = if verdict == RecoveryEvaluationVerdictV1::Refused {
        RecoverySupportStatusV1::InvalidObservation
    } else {
        RecoverySupportStatusV1::SupportedExact
    };
    let refusal_reason = if verdict == RecoveryEvaluationVerdictV1::Refused {
        Some("trace_or_initial_state_invalid".to_owned())
    } else {
        None
    };
    Ok(RecoveryEvaluationReceiptV1 {
        schema_version: RECOVERY_EVALUATION_RECEIPT_V1_VERSION.to_owned(),
        support_status,
        refusal_reason,
        verdict,
        descriptor_sha256: context.compiled.descriptor_sha256,
        morphology_spec_sha256: context.compiled.morphology.morphology_spec_sha256,
        actuator_profile_sha256: Some(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
        capability_sha256: context.capability_sha256,
        threshold_profile_sha256: Some(context.threshold_profile_sha256),
        candidate_trace: Some(candidate),
        matched_zero_command_trace: Some(zero),
        initial_state_identity_matched,
        candidate_synthetic_path_completed,
        matched_zero_command_control_failed_to_complete,
        candidate_physical_path_completed,
        matched_zero_command_physical_control_failed_to_complete,
        physical_development_trace_valid,
        all_negative_control_requirements_enforced: synthetic_canary_passed
            || physical_development_passed,
        controller_implemented: physical_threshold_authority,
        synthetic_canary_passed,
        physical_threshold_authority,
        physical_question_opened: physical_threshold_authority,
        physical_result: physical_development_passed,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: physical_development_passed,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

#[cfg(test)]
pub(crate) mod tests {
    mod passive_entry_tests;
    pub(crate) mod partial_fall_tests;
    pub(crate) mod upright_recovery_tests;
    #[test]
    fn shared_owner_wire_contract_preserves_the_existing_domain() {
        use super::RecoveryControllerOwnerV1;
        let contract: serde_json::Value =
            serde_json::from_str(include_str!("../contracts/recovery_interfaces_v1.json"))
                .unwrap();
        let expected = [
            ("none", RecoveryControllerOwnerV1::None),
            ("recovery", RecoveryControllerOwnerV1::Recovery),
            ("stance", RecoveryControllerOwnerV1::Stance),
        ];
        assert_eq!(
            contract["canonical_owners"].as_array().unwrap().len(),
            expected.len()
        );
        for ((wire, variant), row) in expected
            .into_iter()
            .zip(contract["canonical_owners"].as_array().unwrap())
        {
            assert_eq!(row["wire_name"], wire);
            assert_eq!(serde_json::to_value(variant).unwrap(), wire);
            assert_eq!(
                serde_json::from_value::<RecoveryControllerOwnerV1>(row["wire_name"].clone())
                    .unwrap(),
                variant
            );
        }
        for invalid in ["recovery_v6", "walking_bw5r_b", "unknown", "Recovery", ""] {
            assert!(
                serde_json::from_value::<RecoveryControllerOwnerV1>(serde_json::json!(invalid))
                    .is_err()
            );
        }
        for invalid in [
            serde_json::json!(null),
            serde_json::json!(true),
            serde_json::json!(1),
        ] {
            assert!(serde_json::from_value::<RecoveryControllerOwnerV1>(invalid).is_err());
        }
    }

    use super::*;
    use crate::actuator_profile::r23d60_selected_s169_descriptor;
    use crate::protocol::{
        ContactObservation, ContactProvenance, JointObservation, JointValidityMask, Pose,
        Quaternion, STATE_FRAME_VERSION, TaskFrame, Twist,
    };

    fn channel(channel: RecoveryObservationChannelV1, index: usize) -> RecoveryChannelCapabilityV1 {
        RecoveryChannelCapabilityV1 {
            channel,
            support: RecoveryChannelSupportV1::SupportedMeasured,
            host_source_ids: vec![format!("host_source_{index}")],
            mapping_rule_id: format!("mapping_rule_{index}"),
            source_measurement_only: true,
            synthesized_when_missing: false,
        }
    }

    fn capability(engine: RecoveryNativeEngineV1) -> RecoveryAdapterCapabilityV1 {
        let (adapter_id, mapping_id, version) = match engine {
            RecoveryNativeEngineV1::GodotJolt4_7 => {
                (GODOT_ADAPTER_ID, GODOT_MAPPING_ID, "4.7-stable")
            }
            RecoveryNativeEngineV1::RapierParryNative => (
                RAPIER_ADAPTER_ID,
                RAPIER_MAPPING_ID,
                "rapier3d-0.34.0-parry3d-0.29.0",
            ),
            RecoveryNativeEngineV1::MujocoNative => {
                (MUJOCO_ADAPTER_ID, MUJOCO_MAPPING_ID, "3.11.0")
            }
        };
        RecoveryAdapterCapabilityV1 {
            schema_version: RECOVERY_ADAPTER_CAPABILITY_V1_VERSION.to_owned(),
            adapter_id: adapter_id.to_owned(),
            engine,
            engine_version: version.to_owned(),
            mapping_id: mapping_id.to_owned(),
            native_engine: true,
            ordered_channels: REQUIRED_CHANNELS
                .iter()
                .copied()
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

    fn initialization(
        engine: RecoveryNativeEngineV1,
        arm_kind: RecoveryArmKindV1,
    ) -> RecoveryInitializeRequestV1 {
        RecoveryInitializeRequestV1 {
            schema_version: RECOVERY_INITIALIZE_REQUEST_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id: SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(engine),
            arm_kind,
        }
    }

    fn recovery_context_for(
        descriptor: RecoveryMorphologyDescriptorV1,
    ) -> RecoveryMorphologyContextV1 {
        let receipt = compile_recovery_morphology_v1(descriptor).unwrap();
        RecoveryMorphologyContextV1 {
            schema_version: RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION.to_owned(),
            recovery_morphology_id: receipt.recovery_morphology_id.clone(),
            recovery_descriptor: receipt.descriptor.clone(),
            recovery_descriptor_sha256: receipt.descriptor_sha256,
            base_descriptor_sha256: receipt.base_descriptor_sha256,
            base_morphology_spec_sha256: receipt.base_morphology_spec_sha256,
            recovery_morphology_spec_sha256: receipt.recovery_morphology_spec_sha256,
        }
    }

    fn exact_recovery_context() -> RecoveryMorphologyContextV1 {
        recovery_context_for(RecoveryMorphologyDescriptorV1::exact_s169_reference(
            r23d60_selected_s169_descriptor(),
        ))
    }

    fn initialization_v2(
        engine: RecoveryNativeEngineV1,
        arm_kind: RecoveryArmKindV1,
    ) -> RecoveryInitializeRequestV2 {
        let legacy = initialization(engine, arm_kind);
        RecoveryInitializeRequestV2 {
            schema_version: RECOVERY_INITIALIZE_REQUEST_V2_VERSION.to_owned(),
            task_id: legacy.task_id,
            semantics_id: legacy.semantics_id,
            actuator_profile_id: legacy.actuator_profile_id,
            threshold_profile_id: legacy.threshold_profile_id,
            descriptor: legacy.descriptor,
            morphology_context: exact_recovery_context(),
            adapter_capability: legacy.adapter_capability,
            arm_kind: legacy.arm_kind,
        }
    }

    fn owner(arm: RecoveryArmKindV1, stance: bool) -> RecoveryControllerOwnershipReceiptV1 {
        if arm == RecoveryArmKindV1::MatchedZeroCommand {
            RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::None,
                recovery_controller_id: None,
                stance_controller_id: None,
                handoff_event_count: 0,
                fallback_controller_active: false,
                source_measurement: true,
            }
        } else if stance {
            RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::Stance,
                recovery_controller_id: None,
                stance_controller_id: Some("synthetic_stance_controller".to_owned()),
                handoff_event_count: 1,
                fallback_controller_active: false,
                source_measurement: true,
            }
        } else {
            RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::Recovery,
                recovery_controller_id: Some("synthetic_recovery_controller".to_owned()),
                stance_controller_id: None,
                handoff_event_count: 0,
                fallback_controller_active: false,
                source_measurement: true,
            }
        }
    }

    fn observation(
        engine: RecoveryNativeEngineV1,
        arm: RecoveryArmKindV1,
        step: u64,
        prone: bool,
        feet_bearing: bool,
        raised: bool,
        stance_owner: bool,
    ) -> RecoveryObservationV1 {
        let compiled = compile_bounded_quadruped(r23d60_selected_s169_descriptor()).unwrap();
        let capability = capability(engine);
        let capability_sha256 = digest_serializable(&capability).unwrap();
        let pose_y = if prone {
            0.125
        } else {
            compiled.geometry.initial_torso_center_y_m
        };
        let orientation = if prone {
            let half = std::f64::consts::FRAC_1_SQRT_2;
            Quaternion {
                x: 0.0,
                y: 0.0,
                z: half,
                w: half,
            }
        } else {
            Quaternion::IDENTITY
        };
        let contacts = compiled
            .morphology
            .ordered_contact_site_ids
            .iter()
            .map(|contact_site_id| ContactObservation {
                contact_site_id: contact_site_id.clone(),
                presence: Some(feet_bearing),
                bears_support: Some(feet_bearing),
                normal_load_n: None,
                provenance: ContactProvenance {
                    adapter_id: capability.adapter_id.clone(),
                    engine_contact_ids: if feet_bearing {
                        vec![format!("{contact_site_id}_synthetic_contact")]
                    } else {
                        Vec::new()
                    },
                    aggregation_rule_id: "synthetic_bearing_aggregation".to_owned(),
                    quality: ContactQuality::QualifiedBearing,
                    impulse_source_profile_id: None,
                    impulse_source_kind: None,
                },
            })
            .collect();
        let state = StateFrame {
            schema_version: STATE_FRAME_VERSION.to_owned(),
            semantic_step: step,
            sample_time_s: step as f64 * RECOVERY_OUTER_STEP_DURATION_S,
            base_pose_world: Pose {
                position_m: Vec3 {
                    x: 0.0,
                    y: pose_y,
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
            ordered_contact_observations: contacts,
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
        let candidate_work = step as f64 * 0.125;
        RecoveryObservationV1 {
            schema_version: RECOVERY_OBSERVATION_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            semantic_step: step,
            outer_step_duration_s: RECOVERY_OUTER_STEP_DURATION_S,
            state,
            center_of_mass: RecoveryCenterOfMassObservationV1 {
                position_world_m: Vec3 {
                    x: 0.0,
                    y: if raised { 0.375 } else { 0.125 },
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
                    bearing_normal_impulse_ns: if feet_bearing { 0.125 } else { 0.0 },
                    ordinary_unilateral_contact: true,
                    source_measurement: true,
                })
                .collect(),
            ordered_body_clearance_observations: compiled
                .morphology
                .ordered_body_ids
                .iter()
                .map(|body_id| {
                    let ventral = prone && body_id == "torso";
                    RecoveryBodyClearanceObservationV1 {
                        adapter_id: capability.adapter_id.clone(),
                        body_id: body_id.clone(),
                        nonfoot_contact_present: ventral,
                        ventral_surface_contact: ventral,
                        accumulated_nonfoot_normal_impulse_ns: 0.0,
                        minimum_nonfoot_clearance_m: if ventral { 0.0 } else { 0.0625 },
                        engine_contact_ids: if ventral {
                            vec!["synthetic_torso_ventral_contact".to_owned()]
                        } else {
                            Vec::new()
                        },
                        classification_rule_id: "synthetic_nonfoot_classification".to_owned(),
                        foot_site_contacts_excluded: true,
                        source_measurement: true,
                    }
                })
                .collect(),
            applied_actuation: RecoveryAppliedActuationReceiptV1 {
                adapter_id: capability.adapter_id.clone(),
                adapter_receipt_sha256:
                    "sha256:3333333333333333333333333333333333333333333333333333333333333333"
                        .to_owned(),
                source_semantic_step: step,
                command_id: if arm == RecoveryArmKindV1::MatchedZeroCommand {
                    "matched_zero_command".to_owned()
                } else {
                    "synthetic_recovery_command".to_owned()
                },
                command_sha256:
                    "sha256:1111111111111111111111111111111111111111111111111111111111111111"
                        .to_owned(),
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
                        applied_angular_impulse_nms: if arm == RecoveryArmKindV1::MatchedZeroCommand
                        {
                            0.0
                        } else {
                            0.015625
                        },
                        host_clamped: false,
                    })
                    .collect(),
                source_measurement: true,
            },
            external_interventions: RecoveryExternalInterventionLedgerV1::default(),
            controller_ownership: owner(arm, stance_owner),
            energy_balance: RecoveryEnergyBalanceLedgerV1 {
                initial_mechanical_energy_j: 1.0,
                current_mechanical_energy_j: if arm == RecoveryArmKindV1::MatchedZeroCommand {
                    1.0
                } else {
                    1.0 + candidate_work
                },
                cumulative_applied_actuator_work_j: if arm == RecoveryArmKindV1::MatchedZeroCommand
                {
                    0.0
                } else {
                    candidate_work
                },
                cumulative_external_work_j: 0.0,
                cumulative_dissipated_energy_j: 0.0,
                source_measurement: true,
            },
            engine_step_identity: RecoveryEngineStepIdentityV1 {
                schema_version: RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION.to_owned(),
                source_kind: RecoveryObservationSourceKindV1::SyntheticZeroWorldCanary,
                adapter_id: capability.adapter_id,
                engine,
                capability_sha256,
                source_trace_sha256:
                    "sha256:2222222222222222222222222222222222222222222222222222222222222222"
                        .to_owned(),
                semantic_step: step,
                host_step_before: step,
                host_step_after: step + 1,
                native_solver_substep_count: 0,
                post_step_observation: true,
                engine_identity_exposed_to_policy: false,
            },
        }
    }

    fn native_observation(arm: RecoveryArmKindV1, step: u64) -> RecoveryObservationV1 {
        let mut value = observation(
            RecoveryNativeEngineV1::MujocoNative,
            arm,
            step,
            true,
            false,
            false,
            false,
        );
        value.engine_step_identity.source_kind = RecoveryObservationSourceKindV1::NativePostStep;
        value.engine_step_identity.native_solver_substep_count = 5;
        if arm == RecoveryArmKindV1::CandidateCommand {
            for impulse in &mut value.applied_actuation.ordered_applied_impulses {
                impulse.applied_angular_impulse_nms = 0.0;
            }
            value.energy_balance.current_mechanical_energy_j = 1.0;
            value.energy_balance.cumulative_applied_actuator_work_j = 0.0;
        }
        value
    }

    fn observation_v2_from_v1(
        value: RecoveryObservationV1,
        signed_constraint_exchange_j: f64,
    ) -> RecoveryObservationV2 {
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
        } = value;
        RecoveryObservationV2 {
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
                schema_version: crate::recovery_energy::RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION
                    .to_owned(),
                equation_id: crate::recovery_energy::RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID
                    .to_owned(),
                component_partition_id:
                    crate::recovery_energy::RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID.to_owned(),
                source_profile_id: "mujoco_r24d36_native_components_to_recovery_energy_v2_v1"
                    .to_owned(),
                source_values_sha256:
                    "sha256:3333333333333333333333333333333333333333333333333333333333333333"
                        .to_owned(),
                initial_mechanical_energy_j: energy_balance.initial_mechanical_energy_j,
                current_mechanical_energy_j: energy_balance.current_mechanical_energy_j
                    + signed_constraint_exchange_j,
                cumulative_applied_actuator_work_j: energy_balance
                    .cumulative_applied_actuator_work_j,
                cumulative_signed_external_work_j: energy_balance.cumulative_external_work_j,
                cumulative_signed_constraint_exchange_j: signed_constraint_exchange_j,
                cumulative_passive_dissipation_j: energy_balance.cumulative_dissipated_energy_j,
                source_measurement: energy_balance.source_measurement,
            },
            engine_step_identity,
        }
    }

    fn observation_v3_from_v2(
        value: RecoveryObservationV2,
        signed_discrete_staging_exchange_j: f64,
    ) -> RecoveryObservationV3 {
        let RecoveryObservationV2 {
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
        } = value;
        RecoveryObservationV3 {
            schema_version: RECOVERY_OBSERVATION_V3_VERSION.to_owned(),
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
            energy_balance: RecoveryEnergyBalanceLedgerV3 {
                schema_version:
                    crate::recovery_energy_v3::RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION.to_owned(),
                equation_id: crate::recovery_energy_v3::RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID
                    .to_owned(),
                component_partition_id:
                    crate::recovery_energy_v3::RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID.to_owned(),
                source_profile_id: "r24d54_zero_world_observation_v3_fixture_v1".to_owned(),
                source_values_sha256:
                    "sha256:4444444444444444444444444444444444444444444444444444444444444444"
                        .to_owned(),
                initial_mechanical_energy_j: energy_balance.initial_mechanical_energy_j,
                current_mechanical_energy_j: energy_balance.current_mechanical_energy_j,
                cumulative_applied_actuator_work_j: energy_balance
                    .cumulative_applied_actuator_work_j,
                cumulative_signed_external_work_j: energy_balance.cumulative_signed_external_work_j,
                cumulative_signed_constraint_exchange_j: energy_balance
                    .cumulative_signed_constraint_exchange_j,
                cumulative_signed_discrete_staging_exchange_j: signed_discrete_staging_exchange_j,
                cumulative_passive_dissipation_j: energy_balance.cumulative_passive_dissipation_j,
                source_measurement: energy_balance.source_measurement,
            },
            engine_step_identity,
        }
    }

    fn godot_physical_observation_v3(
        step: u64,
        stance_owner: bool,
        added_unclosed_residual_j: f64,
    ) -> RecoveryObservationV3 {
        let mut legacy = observation(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
            step,
            false,
            true,
            true,
            stance_owner,
        );
        legacy.engine_step_identity.source_kind = RecoveryObservationSourceKindV1::NativePostStep;
        legacy.engine_step_identity.native_solver_substep_count = 1;
        let mut observation = observation_v3_from_v2(observation_v2_from_v1(legacy, 0.0), 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D57_ENERGY_SOURCE_PROFILE_ID.to_owned();
        observation.energy_balance.current_mechanical_energy_j += added_unclosed_residual_j;
        observation
    }

    fn godot_replay_observation_v3(
        arm: RecoveryArmKindV1,
        step: u64,
        prone: bool,
        feet_bearing: bool,
        raised: bool,
        stance_owner: bool,
        added_unclosed_residual_j: f64,
    ) -> RecoveryObservationV3 {
        let mut legacy = observation(
            RecoveryNativeEngineV1::GodotJolt4_7,
            arm,
            step,
            prone,
            feet_bearing,
            raised,
            stance_owner,
        );
        legacy.engine_step_identity.source_kind = RecoveryObservationSourceKindV1::NativePostStep;
        legacy.engine_step_identity.native_solver_substep_count = 1;
        let mut observation = observation_v3_from_v2(observation_v2_from_v1(legacy, 0.0), 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D57_ENERGY_SOURCE_PROFILE_ID.to_owned();
        observation.energy_balance.current_mechanical_energy_j += added_unclosed_residual_j;
        if prone {
            let compiled = compile_bounded_quadruped(r23d60_selected_s169_descriptor()).unwrap();
            observation.state.base_pose_world.position_m.y =
                compiled.geometry.initial_torso_center_y_m * 0.2;
            observation.center_of_mass.position_world_m.y = 0.05;
        }
        observation
    }

    fn godot_physical_memory(
        phase: RecoveryPhaseV1,
        semantic_step: u64,
        stance_dwell_steps_observed: u32,
    ) -> RecoverySupervisorMemoryV1 {
        assert!(semantic_step > 0);
        let mut initialization = initialization_v2(
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryArmKindV1::CandidateCommand,
        );
        initialization.threshold_profile_id =
            crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned();
        let mut memory = initialize_recovery_v2(initialization)
            .unwrap()
            .memory
            .unwrap();
        memory.phase = phase;
        memory.ordered_completed_phases = match phase {
            RecoveryPhaseV1::RaiseBody => vec![
                RecoveryPhaseV1::ConfirmProne,
                RecoveryPhaseV1::EstablishDistalSupport,
            ],
            RecoveryPhaseV1::StanceHandoff => vec![
                RecoveryPhaseV1::ConfirmProne,
                RecoveryPhaseV1::EstablishDistalSupport,
                RecoveryPhaseV1::RaiseBody,
            ],
            RecoveryPhaseV1::StanceDwell => vec![
                RecoveryPhaseV1::ConfirmProne,
                RecoveryPhaseV1::EstablishDistalSupport,
                RecoveryPhaseV1::RaiseBody,
                RecoveryPhaseV1::StanceHandoff,
            ],
            _ => panic!("test helper supports only active progression phases"),
        };
        memory.start_semantic_step = Some(0);
        memory.last_semantic_step = Some(semantic_step - 1);
        memory.total_steps_observed = semantic_step as u32;
        memory.phase_steps_observed = stance_dwell_steps_observed;
        memory.prone_confirm_steps_observed =
            recovery_physical_development_threshold_profile_v1().entry_prone_confirm_steps;
        memory.stance_dwell_steps_observed = stance_dwell_steps_observed;
        memory.initial_center_of_mass_height_m = Some(0.125);
        memory
    }

    fn godot_incomplete_energy_authority(
        observation: &RecoveryObservationV3,
    ) -> RecoveryEnergyPartitionAuthorityV1 {
        RecoveryEnergyPartitionAuthorityV1 {
            schema_version: RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION.to_owned(),
            authority_profile_id:
                GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID.to_owned(),
            authority_source_sha256: GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned(),
            adapter_id: GODOT_ADAPTER_ID.to_owned(),
            engine: RecoveryNativeEngineV1::GodotJolt4_7,
            capability_sha256: observation.engine_step_identity.capability_sha256.clone(),
            energy_source_profile_id: observation.energy_balance.source_profile_id.clone(),
            component_partition_id: observation.energy_balance.component_partition_id.clone(),
            constraint_exchange_partition_complete: false,
            passive_dissipation_partition_complete: false,
            component_partition_complete: false,
            exact_balance_safety_authority: false,
            unclosed_energy_residual_preserved: true,
            residual_balancing_permitted: false,
            development_progression_permitted: true,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    fn godot_complete_energy_authority(
        observation: &RecoveryObservationV3,
    ) -> RecoveryEnergyPartitionAuthorityV1 {
        RecoveryEnergyPartitionAuthorityV1 {
            schema_version: RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION.to_owned(),
            authority_profile_id: GODOT_JOLT_R24D136_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
                .to_owned(),
            authority_source_sha256: GODOT_JOLT_R24D136_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned(),
            adapter_id: GODOT_ADAPTER_ID.to_owned(),
            engine: RecoveryNativeEngineV1::GodotJolt4_7,
            capability_sha256: observation.engine_step_identity.capability_sha256.clone(),
            energy_source_profile_id: observation.energy_balance.source_profile_id.clone(),
            component_partition_id: observation.energy_balance.component_partition_id.clone(),
            constraint_exchange_partition_complete: true,
            passive_dissipation_partition_complete: true,
            component_partition_complete: true,
            exact_balance_safety_authority: true,
            unclosed_energy_residual_preserved: false,
            residual_balancing_permitted: false,
            development_progression_permitted: false,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    fn godot_solver_coupled_complete_energy_authority(
        observation: &RecoveryObservationV3,
    ) -> RecoveryEnergyPartitionAuthorityV1 {
        RecoveryEnergyPartitionAuthorityV1 {
            schema_version: RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION.to_owned(),
            authority_profile_id: GODOT_JOLT_R24D144_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
                .to_owned(),
            authority_source_sha256: GODOT_JOLT_R24D144_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned(),
            adapter_id: GODOT_ADAPTER_ID.to_owned(),
            engine: RecoveryNativeEngineV1::GodotJolt4_7,
            capability_sha256: observation.engine_step_identity.capability_sha256.clone(),
            energy_source_profile_id: observation.energy_balance.source_profile_id.clone(),
            component_partition_id: observation.energy_balance.component_partition_id.clone(),
            constraint_exchange_partition_complete: true,
            passive_dissipation_partition_complete: true,
            component_partition_complete: true,
            exact_balance_safety_authority: true,
            unclosed_energy_residual_preserved: false,
            residual_balancing_permitted: false,
            development_progression_permitted: false,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    fn godot_commissioned_discrete_staging_energy_authority(
        observation: &RecoveryObservationV3,
    ) -> RecoveryEnergyPartitionAuthorityV1 {
        RecoveryEnergyPartitionAuthorityV1 {
            schema_version: RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION.to_owned(),
            authority_profile_id:
                GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_PROFILE_ID.to_owned(),
            authority_source_sha256:
                GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_SOURCE_SHA256.to_owned(),
            adapter_id: GODOT_ADAPTER_ID.to_owned(),
            engine: RecoveryNativeEngineV1::GodotJolt4_7,
            capability_sha256: observation.engine_step_identity.capability_sha256.clone(),
            energy_source_profile_id: observation.energy_balance.source_profile_id.clone(),
            component_partition_id: observation.energy_balance.component_partition_id.clone(),
            constraint_exchange_partition_complete: true,
            passive_dissipation_partition_complete: true,
            component_partition_complete: true,
            exact_balance_safety_authority: true,
            unclosed_energy_residual_preserved: false,
            residual_balancing_permitted: false,
            development_progression_permitted: false,
            physical_acceptance_authority: false,
            release_authority: false,
        }
    }

    fn godot_step_v5_request(
        memory: RecoverySupervisorMemoryV1,
        observation: RecoveryObservationV3,
    ) -> RecoveryStepRequestV5 {
        let energy_partition_authority = godot_incomplete_energy_authority(&observation);
        RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory,
            observation,
            energy_partition_authority,
        }
    }

    fn evaluation_request_v3() -> RecoveryEvaluationRequestV3 {
        let legacy = evaluation_request(RecoveryNativeEngineV1::MujocoNative);
        let candidate_observations = legacy
            .candidate_trace
            .observations
            .into_iter()
            .enumerate()
            .map(|(index, observation)| {
                observation_v2_from_v1(
                    observation,
                    if index == 0 {
                        0.0
                    } else if index % 2 == 0 {
                        0.125
                    } else {
                        -0.125
                    },
                )
            })
            .collect::<Vec<_>>();
        let matched_zero_observations = legacy
            .matched_zero_command_trace
            .observations
            .into_iter()
            .enumerate()
            .map(|(index, observation)| {
                observation_v2_from_v1(observation, if index == 0 { 0.0 } else { -0.0625 })
            })
            .collect::<Vec<_>>();
        let initial_sha256 = initial_state_sha256(&candidate_observations[0]).unwrap();
        assert_eq!(
            initial_sha256,
            initial_state_sha256(&matched_zero_observations[0]).unwrap()
        );
        RecoveryEvaluationRequestV3 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V3_VERSION.to_owned(),
            task_id: legacy.task_id,
            semantics_id: legacy.semantics_id,
            actuator_profile_id: legacy.actuator_profile_id,
            threshold_profile_id: legacy.threshold_profile_id,
            descriptor: legacy.descriptor,
            morphology_context: exact_recovery_context(),
            adapter_capability: legacy.adapter_capability,
            candidate_trace: RecoveryTraceV2 {
                schema_version: RECOVERY_TRACE_V2_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                declared_initial_state_sha256: initial_sha256.clone(),
                observations: candidate_observations,
            },
            matched_zero_command_trace: RecoveryTraceV2 {
                schema_version: RECOVERY_TRACE_V2_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::MatchedZeroCommand,
                declared_initial_state_sha256: initial_sha256,
                observations: matched_zero_observations,
            },
        }
    }

    fn evaluation_request_v4() -> RecoveryEvaluationRequestV4 {
        let RecoveryEvaluationRequestV3 {
            task_id,
            semantics_id,
            actuator_profile_id,
            threshold_profile_id,
            descriptor,
            morphology_context,
            adapter_capability,
            candidate_trace,
            matched_zero_command_trace,
            ..
        } = evaluation_request_v3();
        let candidate_observations = candidate_trace
            .observations
            .into_iter()
            .map(|observation| observation_v3_from_v2(observation, 0.0))
            .collect::<Vec<_>>();
        let matched_zero_observations = matched_zero_command_trace
            .observations
            .into_iter()
            .map(|observation| observation_v3_from_v2(observation, 0.0))
            .collect::<Vec<_>>();
        let initial_sha256 = initial_state_sha256(&candidate_observations[0]).unwrap();
        assert_eq!(
            initial_sha256,
            initial_state_sha256(&matched_zero_observations[0]).unwrap()
        );
        RecoveryEvaluationRequestV4 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V4_VERSION.to_owned(),
            task_id,
            semantics_id,
            actuator_profile_id,
            threshold_profile_id,
            descriptor,
            morphology_context,
            adapter_capability,
            candidate_trace: RecoveryTraceV3 {
                schema_version: RECOVERY_TRACE_V3_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                declared_initial_state_sha256: initial_sha256.clone(),
                observations: candidate_observations,
            },
            matched_zero_command_trace: RecoveryTraceV3 {
                schema_version: RECOVERY_TRACE_V3_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::MatchedZeroCommand,
                declared_initial_state_sha256: initial_sha256,
                observations: matched_zero_observations,
            },
        }
    }

    fn evaluation_request(engine: RecoveryNativeEngineV1) -> RecoveryEvaluationRequestV1 {
        let candidate_observations = vec![
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                0,
                true,
                false,
                false,
                false,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                1,
                true,
                false,
                false,
                false,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                2,
                true,
                true,
                false,
                false,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                3,
                false,
                true,
                true,
                false,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                4,
                false,
                true,
                true,
                true,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                5,
                false,
                true,
                true,
                true,
            ),
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                6,
                false,
                true,
                true,
                true,
            ),
        ];
        let zero_observations = (0..6)
            .map(|step| {
                observation(
                    engine,
                    RecoveryArmKindV1::MatchedZeroCommand,
                    step,
                    true,
                    false,
                    false,
                    false,
                )
            })
            .collect::<Vec<_>>();
        let initial_sha = initial_state_sha256(&candidate_observations[0]).unwrap();
        assert_eq!(
            initial_sha,
            initial_state_sha256(&zero_observations[0]).unwrap()
        );
        RecoveryEvaluationRequestV1 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id: SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(engine),
            candidate_trace: RecoveryTraceV1 {
                schema_version: RECOVERY_TRACE_V1_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                declared_initial_state_sha256: initial_sha.clone(),
                observations: candidate_observations,
            },
            matched_zero_command_trace: RecoveryTraceV1 {
                schema_version: RECOVERY_TRACE_V1_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::MatchedZeroCommand,
                declared_initial_state_sha256: initial_sha,
                observations: zero_observations,
            },
        }
    }

    #[test]
    fn observation_v2_step_uses_signed_constraint_without_v1_relabelling() {
        let engine = RecoveryNativeEngineV1::MujocoNative;
        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let observation_v2 = observation_v2_from_v1(
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                0,
                true,
                false,
                false,
                false,
            ),
            0.5,
        );
        let serialized = serde_json::to_value(&observation_v2).unwrap();
        assert!(serde_json::from_value::<RecoveryObservationV1>(serialized).is_err());
        let receipt = step_recovery_v3(RecoveryStepRequestV3 {
            schema_version: RECOVERY_STEP_REQUEST_V3_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: observation_v2.clone(),
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(
            receipt
                .classification
                .as_ref()
                .unwrap()
                .energy_balance_residual_j,
            0.0
        );

        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let mut residual = observation_v2.clone();
        residual
            .energy_balance
            .cumulative_signed_constraint_exchange_j += 1.0;
        let receipt = step_recovery_v3(RecoveryStepRequestV3 {
            schema_version: RECOVERY_STEP_REQUEST_V3_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: residual,
        })
        .unwrap();
        let classification = receipt.classification.unwrap();
        assert_eq!(classification.energy_balance_residual_j, 1.0);
        assert!(!classification.safety_gate);

        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let mut invalid = observation_v2;
        invalid.energy_balance.equation_id = "mutated_equation".to_owned();
        let receipt = step_recovery_v3(RecoveryStepRequestV3 {
            schema_version: RECOVERY_STEP_REQUEST_V3_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: invalid,
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert!(
            receipt
                .refusal_reason
                .as_deref()
                .is_some_and(|reason| reason.starts_with("energy_balance_ledger_v2_invalid:"))
        );
    }

    #[test]
    fn observation_v2_paired_evaluator_preserves_zero_world_v1_behavior_semantics() {
        let receipt = evaluate_recovery_trace_v3(evaluation_request_v3()).unwrap();
        assert_eq!(
            receipt.verdict,
            RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
        );
        assert!(receipt.synthetic_canary_passed);
        assert_eq!(receipt.model_construction_count, 0);
        assert_eq!(receipt.world_attempt_count, 0);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_result);
        assert!(!receipt.release_authority);
    }

    #[test]
    fn observation_v3_consumes_staging_once_without_v1_or_v2_relabelling() {
        let engine = RecoveryNativeEngineV1::RapierParryNative;
        let mut observation_v2 = observation_v2_from_v1(
            observation(
                engine,
                RecoveryArmKindV1::CandidateCommand,
                0,
                true,
                false,
                false,
                false,
            ),
            0.5,
        );
        observation_v2.energy_balance.current_mechanical_energy_j += 1.0;

        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let v2_receipt = step_recovery_v3(RecoveryStepRequestV3 {
            schema_version: RECOVERY_STEP_REQUEST_V3_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: observation_v2.clone(),
        })
        .unwrap();
        let v2_classification = v2_receipt.classification.unwrap();
        assert_eq!(v2_classification.energy_balance_residual_j, 1.0);
        assert!(!v2_classification.safety_gate);

        let observation_v3 = observation_v3_from_v2(observation_v2.clone(), 1.0);
        assert!(
            serde_json::from_value::<RecoveryObservationV2>(
                serde_json::to_value(&observation_v3).unwrap()
            )
            .is_err()
        );
        assert!(
            serde_json::from_value::<RecoveryObservationV3>(
                serde_json::to_value(&observation_v2).unwrap()
            )
            .is_err()
        );

        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let v3_receipt = step_recovery_v4(RecoveryStepRequestV4 {
            schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: observation_v3.clone(),
        })
        .unwrap();
        let v3_classification = v3_receipt.classification.unwrap();
        assert_eq!(v3_classification.energy_balance_residual_j, 0.0);
        assert!(v3_classification.safety_gate);

        let initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        let mut invalid = observation_v3;
        invalid.energy_balance.equation_id = "mutated_equation".to_owned();
        let invalid_receipt = step_recovery_v4(RecoveryStepRequestV4 {
            schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(engine),
            memory: initialization.memory.unwrap(),
            observation: invalid,
        })
        .unwrap();
        assert_eq!(
            invalid_receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert!(
            invalid_receipt
                .refusal_reason
                .as_deref()
                .is_some_and(|reason| reason.starts_with("energy_balance_ledger_v3_invalid:"))
        );
    }

    #[test]
    fn observation_v3_paired_evaluator_preserves_zero_world_behavior_semantics() {
        let receipt = evaluate_recovery_trace_v4(evaluation_request_v4()).unwrap();
        assert_eq!(
            receipt.verdict,
            RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
        );
        assert!(receipt.synthetic_canary_passed);
        assert_eq!(receipt.model_construction_count, 0);
        assert_eq!(receipt.world_attempt_count, 0);
        assert_eq!(receipt.world_build_count, 0);
        assert_eq!(receipt.solver_step_count, 0);
        assert!(!receipt.physics_state_modified);
        assert!(!receipt.physical_result);
        assert!(!receipt.release_authority);
    }

    #[test]
    fn r24d134_evaluator_replays_the_production_development_authority_without_relabelling_v4() {
        let mut candidate_observations = (0..12)
            .map(|step| {
                godot_replay_observation_v3(
                    RecoveryArmKindV1::CandidateCommand,
                    step,
                    true,
                    false,
                    false,
                    false,
                    0.0,
                )
            })
            .collect::<Vec<_>>();
        candidate_observations.push(godot_replay_observation_v3(
            RecoveryArmKindV1::CandidateCommand,
            12,
            false,
            true,
            false,
            false,
            0.0,
        ));
        candidate_observations.push(godot_replay_observation_v3(
            RecoveryArmKindV1::CandidateCommand,
            13,
            false,
            true,
            true,
            false,
            1.0,
        ));
        candidate_observations.push(godot_replay_observation_v3(
            RecoveryArmKindV1::CandidateCommand,
            14,
            false,
            true,
            true,
            true,
            1.0,
        ));
        let matched_zero_observations = (0..15)
            .map(|step| {
                godot_replay_observation_v3(
                    RecoveryArmKindV1::MatchedZeroCommand,
                    step,
                    true,
                    false,
                    false,
                    false,
                    0.0,
                )
            })
            .collect::<Vec<_>>();
        let initial_sha256 = initial_state_sha256(&candidate_observations[0]).unwrap();
        assert_eq!(
            initial_sha256,
            initial_state_sha256(&matched_zero_observations[0]).unwrap()
        );
        let request_v4 = RecoveryEvaluationRequestV4 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V4_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id:
                crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            candidate_trace: RecoveryTraceV3 {
                schema_version: RECOVERY_TRACE_V3_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                declared_initial_state_sha256: initial_sha256.clone(),
                observations: candidate_observations,
            },
            matched_zero_command_trace: RecoveryTraceV3 {
                schema_version: RECOVERY_TRACE_V3_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::MatchedZeroCommand,
                declared_initial_state_sha256: initial_sha256,
                observations: matched_zero_observations,
            },
        };

        // V4 remains historically exact: it cannot infer the authority that
        // production supplied, stays in raise_body, then rejects stance owner.
        let legacy = evaluate_recovery_trace_v4(request_v4.clone()).unwrap();
        assert_eq!(legacy.verdict, RecoveryEvaluationVerdictV1::Refused);
        assert_eq!(
            legacy.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        let legacy_candidate = legacy.candidate_trace.as_ref().unwrap();
        assert_eq!(legacy_candidate.observation_count, 15);
        assert_eq!(legacy_candidate.accepted_observation_count, 14);
        assert_eq!(legacy_candidate.final_phase, RecoveryPhaseV1::Refused);
        assert_eq!(
            legacy_candidate.terminal_failure_code.as_deref(),
            Some("active_recovery_phase_owner_invalid")
        );

        let energy_partition_authority =
            godot_incomplete_energy_authority(&request_v4.candidate_trace.observations[0]);
        let request_v5 = RecoveryEvaluationRequestV5 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V5_VERSION.to_owned(),
            task_id: request_v4.task_id.clone(),
            semantics_id: request_v4.semantics_id.clone(),
            actuator_profile_id: request_v4.actuator_profile_id.clone(),
            threshold_profile_id: request_v4.threshold_profile_id.clone(),
            descriptor: request_v4.descriptor.clone(),
            morphology_context: request_v4.morphology_context.clone(),
            adapter_capability: request_v4.adapter_capability.clone(),
            energy_partition_authority,
            candidate_trace: request_v4.candidate_trace.clone(),
            matched_zero_command_trace: request_v4.matched_zero_command_trace.clone(),
        };
        let receipt = evaluate_recovery_trace_v5(request_v5.clone()).unwrap();
        assert_eq!(
            receipt.verdict,
            RecoveryEvaluationVerdictV1::PhysicalDevelopmentIncomplete,
            "{receipt:#?}"
        );
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(receipt.refusal_reason, None);
        assert!(receipt.physical_development_trace_valid);
        let candidate = receipt.candidate_trace.as_ref().unwrap();
        assert_eq!(candidate.accepted_observation_count, 15);
        assert_eq!(candidate.final_phase, RecoveryPhaseV1::StanceDwell);
        assert!(!candidate.refused);
        let matched_zero = receipt.matched_zero_command_trace.as_ref().unwrap();
        assert_eq!(matched_zero.accepted_observation_count, 15);
        assert!(!matched_zero.refused);
        assert!(!receipt.physical_result);
        assert!(!receipt.prone_to_standing_claimed);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);

        let mut mutated = request_v5.clone();
        mutated.energy_partition_authority.authority_source_sha256 =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_owned();
        assert!(evaluate_recovery_trace_v5(mutated).is_err());

        let mut missing_authority = serde_json::to_value(&request_v5).unwrap();
        missing_authority
            .as_object_mut()
            .unwrap()
            .remove("energy_partition_authority");
        assert!(serde_json::from_value::<RecoveryEvaluationRequestV5>(missing_authority).is_err());

        let mut legacy_with_authority = serde_json::to_value(&request_v4).unwrap();
        legacy_with_authority.as_object_mut().unwrap().insert(
            "energy_partition_authority".to_owned(),
            serde_json::to_value(request_v5.energy_partition_authority).unwrap(),
        );
        assert!(
            serde_json::from_value::<RecoveryEvaluationRequestV4>(legacy_with_authority).is_err()
        );
    }

    #[test]
    fn r24d126_incomplete_godot_authority_opens_only_development_handoff() {
        let memory = godot_physical_memory(RecoveryPhaseV1::RaiseBody, 40, 0);
        let observation = godot_physical_observation_v3(40, false, 1.0);

        let legacy = step_recovery_v4(RecoveryStepRequestV4 {
            schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory: memory.clone(),
            observation: observation.clone(),
        })
        .unwrap();
        assert_eq!(legacy.prior_phase, RecoveryPhaseV1::RaiseBody);
        assert_eq!(legacy.next_phase, RecoveryPhaseV1::RaiseBody);
        let legacy_classification = legacy.classification.as_ref().unwrap();
        assert!(legacy_classification.raised_body_gate);
        assert!(!legacy_classification.safety_gate);
        assert!(legacy_classification.energy_balance_residual_j > 0.25);

        let receipt = step_recovery_v5(godot_step_v5_request(memory, observation)).unwrap();
        assert_eq!(receipt.schema_version, RECOVERY_STEP_RECEIPT_V2_VERSION);
        assert_eq!(receipt.step.prior_phase, RecoveryPhaseV1::RaiseBody);
        assert_eq!(receipt.step.next_phase, RecoveryPhaseV1::StanceHandoff);
        assert!(receipt.step.transitioned);
        assert_eq!(receipt.step.classification, legacy.classification);
        assert!(!receipt.step.physical_result);
        assert!(!receipt.step.prone_to_standing_claimed);
        assert!(!receipt.step.physical_acceptance_authority);
        assert!(!receipt.step.release_authority);

        let progression = receipt.development_progression;
        assert!(!progression.component_partition_complete);
        assert!(!progression.exact_balance_safety_authority);
        assert!(!progression.legacy_safety_gate);
        assert!(!progression.acceptance_safety_gate);
        assert!(progression.development_nonenergy_safety_gate);
        assert!(progression.development_stance_handoff_gate);
        assert!(progression.development_progression_permitted);
        assert!(progression.development_progression_used);
        assert!(!progression.stable_stance_completion_authorized);
        assert!(!progression.physical_result_authorized);
        assert!(!progression.prone_to_standing_claimed);
        assert!(!progression.physical_acceptance_authority);
        assert!(!progression.release_authority);
        assert_eq!(progression.world_build_count, 0);
        assert_eq!(progression.solver_step_count, 0);
        assert!(!progression.physics_state_modified);
    }

    #[test]
    fn r24d126_incomplete_authority_cannot_complete_a_legacy_stable_stance() {
        let thresholds = recovery_physical_development_threshold_profile_v1();
        let dwell_before = thresholds.stance_dwell_steps - 1;
        let memory = godot_physical_memory(RecoveryPhaseV1::StanceDwell, 500, dwell_before);
        let observation = godot_physical_observation_v3(500, true, 0.0);
        let receipt = step_recovery_v5(godot_step_v5_request(memory, observation)).unwrap();

        assert_eq!(receipt.step.prior_phase, RecoveryPhaseV1::StanceDwell);
        assert_eq!(receipt.step.next_phase, RecoveryPhaseV1::StanceDwell);
        assert!(!receipt.step.transitioned);
        assert_eq!(
            receipt
                .step
                .memory
                .as_ref()
                .unwrap()
                .stance_dwell_steps_observed,
            0
        );
        let classification = receipt.step.classification.as_ref().unwrap();
        assert!(classification.safety_gate);
        assert!(classification.stable_stance_gate);
        assert!(classification.physical_result);
        assert!(!receipt.step.physical_result);

        let progression = receipt.development_progression;
        assert!(progression.legacy_safety_gate);
        assert!(progression.legacy_stable_stance_gate);
        assert!(!progression.acceptance_safety_gate);
        assert!(!progression.stable_stance_completion_authorized);
        assert!(!progression.physical_result_authorized);
        assert!(!progression.prone_to_standing_claimed);
        assert!(!progression.physical_acceptance_authority);
        assert!(!progression.release_authority);
    }

    #[test]
    fn r24d136_complete_authority_can_complete_exact_stance_without_release_authority() {
        let thresholds = recovery_physical_development_threshold_profile_v1();
        let dwell_before = thresholds.stance_dwell_steps - 1;
        let memory = godot_physical_memory(RecoveryPhaseV1::StanceDwell, 500, dwell_before);
        let mut observation = godot_physical_observation_v3(500, true, 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID.to_owned();
        let authority = godot_complete_energy_authority(&observation);
        let receipt = step_recovery_v5(RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory,
            observation,
            energy_partition_authority: authority,
        })
        .unwrap();

        assert_eq!(receipt.step.prior_phase, RecoveryPhaseV1::StanceDwell);
        assert_eq!(receipt.step.next_phase, RecoveryPhaseV1::Complete);
        assert!(receipt.step.transitioned);
        assert!(receipt.step.physical_result);
        let progression = receipt.development_progression;
        assert!(progression.component_partition_complete);
        assert!(progression.exact_balance_safety_authority);
        assert!(progression.acceptance_safety_gate);
        assert!(progression.stable_stance_completion_authorized);
        assert!(progression.physical_result_authorized);
        assert!(!progression.development_progression_permitted);
        assert!(!progression.development_progression_used);
        assert!(!progression.prone_to_standing_claimed);
        assert!(!progression.physical_acceptance_authority);
        assert!(!progression.release_authority);
    }

    #[test]
    fn r24d136_complete_authority_mutations_fail_closed() {
        let memory = godot_physical_memory(RecoveryPhaseV1::RaiseBody, 40, 0);
        let mut observation = godot_physical_observation_v3(40, false, 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID.to_owned();
        let authority = godot_complete_energy_authority(&observation);
        let request = RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory,
            observation,
            energy_partition_authority: authority,
        };
        let mut mutations = Vec::new();

        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_source_sha256 =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_owned();
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .constraint_exchange_partition_complete = false;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .development_progression_permitted = true;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .residual_balancing_permitted = true;
        mutations.push(mutated);

        let mut mutated = request;
        mutated
            .energy_partition_authority
            .physical_acceptance_authority = true;
        mutations.push(mutated);

        assert_eq!(mutations.len(), 5);
        for mutation in mutations {
            assert!(step_recovery_v5(mutation).is_err());
        }
    }

    #[test]
    fn r24d144_solver_coupled_complete_authority_is_exact_and_cross_profile_closed() {
        let thresholds = recovery_physical_development_threshold_profile_v1();
        let dwell_before = thresholds.stance_dwell_steps - 1;
        let memory = godot_physical_memory(RecoveryPhaseV1::StanceDwell, 500, dwell_before);
        let mut observation = godot_physical_observation_v3(500, true, 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D144_ENERGY_SOURCE_PROFILE_ID.to_owned();
        let authority = godot_solver_coupled_complete_energy_authority(&observation);
        let request = RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory,
            observation,
            energy_partition_authority: authority,
        };
        let receipt = step_recovery_v5(request.clone()).unwrap();
        assert_eq!(receipt.step.prior_phase, RecoveryPhaseV1::StanceDwell);
        assert_eq!(receipt.step.next_phase, RecoveryPhaseV1::Complete);
        assert!(receipt.step.transitioned);
        assert!(receipt.step.physical_result);
        let progression = receipt.development_progression;
        assert_eq!(
            progression.authority_profile_id,
            GODOT_JOLT_R24D144_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID
        );
        assert!(progression.component_partition_complete);
        assert!(progression.exact_balance_safety_authority);
        assert!(progression.stable_stance_completion_authorized);
        assert!(!progression.prone_to_standing_claimed);
        assert!(!progression.physical_acceptance_authority);
        assert!(!progression.release_authority);

        let mut mutations = Vec::new();
        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_source_sha256 =
            GODOT_JOLT_R24D136_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned();
        mutations.push(mutated);
        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_profile_id =
            GODOT_JOLT_R24D136_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID.to_owned();
        mutations.push(mutated);
        let mut mutated = request.clone();
        mutated.energy_partition_authority.energy_source_profile_id =
            GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID.to_owned();
        mutations.push(mutated);
        let mut mutated = request;
        mutated.observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D136_ENERGY_SOURCE_PROFILE_ID.to_owned();
        mutations.push(mutated);
        assert_eq!(mutations.len(), 4);
        for mutation in mutations {
            assert!(step_recovery_v5(mutation).is_err());
        }
    }

    #[test]
    fn r24d151_commissioned_discrete_staging_authority_is_exact_and_cross_profile_closed() {
        let thresholds = recovery_physical_development_threshold_profile_v1();
        let dwell_before = thresholds.stance_dwell_steps - 1;
        let memory = godot_physical_memory(RecoveryPhaseV1::StanceDwell, 500, dwell_before);
        let mut observation = godot_physical_observation_v3(500, true, 0.0);
        observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D148_DISCRETE_STAGING_ENERGY_SOURCE_PROFILE_ID.to_owned();
        let authority = godot_commissioned_discrete_staging_energy_authority(&observation);
        let request = RecoveryStepRequestV5 {
            schema_version: RECOVERY_STEP_REQUEST_V5_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: exact_recovery_context(),
            adapter_capability: capability(RecoveryNativeEngineV1::GodotJolt4_7),
            memory,
            observation,
            energy_partition_authority: authority,
        };
        let receipt = step_recovery_v5(request.clone()).unwrap();
        assert_eq!(receipt.step.next_phase, RecoveryPhaseV1::Complete);
        assert!(receipt.step.physical_result);
        assert_eq!(
            receipt.development_progression.authority_profile_id,
            GODOT_JOLT_R24D151_COMMISSIONED_DISCRETE_STAGING_AUTHORITY_PROFILE_ID
        );
        assert!(
            receipt
                .development_progression
                .stable_stance_completion_authorized
        );
        assert!(
            !receipt
                .development_progression
                .physical_acceptance_authority
        );
        assert!(!receipt.development_progression.release_authority);

        let mut mutations = Vec::new();
        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_source_sha256 =
            GODOT_JOLT_R24D144_ENERGY_AUTHORITY_SOURCE_SHA256.to_owned();
        mutations.push(mutated);
        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_profile_id =
            GODOT_JOLT_R24D144_COMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID.to_owned();
        mutations.push(mutated);
        let mut mutated = request.clone();
        mutated.energy_partition_authority.energy_source_profile_id =
            GODOT_JOLT_R24D144_ENERGY_SOURCE_PROFILE_ID.to_owned();
        mutations.push(mutated);
        let mut mutated = request;
        mutated.observation.energy_balance.source_profile_id =
            GODOT_JOLT_R24D144_ENERGY_SOURCE_PROFILE_ID.to_owned();
        mutations.push(mutated);
        assert_eq!(mutations.len(), 4);
        for mutation in mutations {
            assert!(step_recovery_v5(mutation).is_err());
        }
    }

    #[test]
    fn r24d126_authority_mutations_and_cross_version_shapes_fail_closed() {
        let memory = godot_physical_memory(RecoveryPhaseV1::RaiseBody, 40, 0);
        let observation = godot_physical_observation_v3(40, false, 1.0);
        let request = godot_step_v5_request(memory, observation);
        let mut mutations = Vec::new();

        let mut mutated = request.clone();
        mutated.energy_partition_authority.authority_source_sha256 =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_owned();
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated.energy_partition_authority.capability_sha256 =
            "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".to_owned();
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .exact_balance_safety_authority = true;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .constraint_exchange_partition_complete = true;
        mutated
            .energy_partition_authority
            .passive_dissipation_partition_complete = true;
        mutated
            .energy_partition_authority
            .component_partition_complete = true;
        mutated
            .energy_partition_authority
            .exact_balance_safety_authority = true;
        mutated
            .energy_partition_authority
            .unclosed_energy_residual_preserved = false;
        mutated
            .energy_partition_authority
            .development_progression_permitted = false;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .residual_balancing_permitted = true;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated
            .energy_partition_authority
            .development_progression_permitted = false;
        mutations.push(mutated);

        let mut mutated = request.clone();
        mutated.energy_partition_authority.engine = RecoveryNativeEngineV1::RapierParryNative;
        mutations.push(mutated);

        assert_eq!(mutations.len(), 7);
        for mutation in mutations {
            assert!(step_recovery_v5(mutation).is_err());
        }

        let mut missing_authority = serde_json::to_value(&request).unwrap();
        missing_authority
            .as_object_mut()
            .unwrap()
            .remove("energy_partition_authority");
        assert!(serde_json::from_value::<RecoveryStepRequestV5>(missing_authority).is_err());

        let mut unknown_authority_field = serde_json::to_value(&request).unwrap();
        unknown_authority_field["energy_partition_authority"]
            .as_object_mut()
            .unwrap()
            .insert("manufactured_balance".to_owned(), json!(true));
        assert!(serde_json::from_value::<RecoveryStepRequestV5>(unknown_authority_field).is_err());

        let mut legacy_shape = serde_json::to_value(RecoveryStepRequestV4 {
            schema_version: RECOVERY_STEP_REQUEST_V4_VERSION.to_owned(),
            descriptor: request.descriptor.clone(),
            morphology_context: request.morphology_context.clone(),
            adapter_capability: request.adapter_capability.clone(),
            memory: request.memory.clone(),
            observation: request.observation.clone(),
        })
        .unwrap();
        legacy_shape.as_object_mut().unwrap().insert(
            "energy_partition_authority".to_owned(),
            serde_json::to_value(request.energy_partition_authority).unwrap(),
        );
        assert!(serde_json::from_value::<RecoveryStepRequestV4>(legacy_shape).is_err());
    }

    #[test]
    fn entry_initialization_retained_reference_changes_raise_predicate() {
        // Counterfactual classifier regression, not a replay of an unobserved
        // post-kick get-up. The cold Python audit binds these retained values.
        let diagnosis: serde_json::Value = serde_json::from_str(include_str!(
            "../../development_recovery_entry_initialization_diagnosis_v1.json"
        ))
        .unwrap();
        let value = |group: &str, key: &str| diagnosis[group][key].as_f64().unwrap();
        let postkick_reference = value("observed", "postkick_reference_com_m");
        let prone_reference = value("observed", "canonical_prone_reference_com_m");
        let standing_com = value(
            "derived",
            "precondition_standing_com_m_from_retained_reference_and_gain",
        );
        let engine = RecoveryNativeEngineV1::GodotJolt4_7;
        let arm = RecoveryArmKindV1::CandidateCommand;
        let init = initialization(engine, arm);
        let mut memory = initialize_recovery_v1(init.clone()).unwrap().memory.unwrap();
        for (step, height) in [(0, postkick_reference), (1, prone_reference)] {
            let mut sample = observation(engine, arm, step, false, true, true, false);
            sample.center_of_mass.position_world_m.y = height;
            let result = step_recovery(
                init.descriptor.clone(), init.adapter_capability.clone(), memory, sample, None,
            )
            .unwrap();
            assert_eq!(result.support_status, RecoverySupportStatusV1::SupportedExact);
            memory = result.memory.unwrap();
            // Waiting for a lower sample does not move an already captured reference.
            assert_eq!(memory.initial_center_of_mass_height_m, Some(postkick_reference));
            assert_eq!(memory.phase, RecoveryPhaseV1::ConfirmProne);
            assert_eq!(u64::from(memory.total_steps_observed), step + 1);
        }

        let physical = recovery_physical_development_threshold_profile_v1();
        assert_eq!(physical.minimum_com_height_gain_m, value("derived", "minimum_com_rise_m"));
        assert_eq!(physical.per_phase_timeout_steps.confirm_prone, 60);
        assert_eq!(physical.entry_prone_confirm_steps, 12);
        let RecoveryContextResolution::Supported(context) = context_for(
            &init.task_id, &init.semantics_id, &init.actuator_profile_id,
            &physical.profile_id, init.descriptor.clone(), None, &init.adapter_capability,
        )
        .unwrap() else { panic!("registered physical profile must resolve"); };
        let mut standing = observation(engine, arm, 2, false, true, true, false);
        standing.center_of_mass.position_world_m.y = standing_com;
        let too_early = classify_observation(standing.view(), memory.initial_center_of_mass_height_m, &context, 0.0);
        assert_eq!(too_early.center_of_mass_height_gain_m,
            value("derived", "same_precondition_stance_gain_using_postkick_reference_m"));
        assert!(!too_early.raised_body_gate);
        let mut from_prone = memory.clone();
        from_prone.initial_center_of_mass_height_m = Some(prone_reference);
        let correctly_referenced = classify_observation(standing.view(), from_prone.initial_center_of_mass_height_m, &context, 0.0);
        assert!(correctly_referenced.raised_body_gate);
        assert!(!correctly_referenced.physical_result);
        // The only changed input is controller reference memory. This neither
        // changes an observed record nor authorizes editing live memory in place.
        assert_eq!(standing.center_of_mass.position_world_m.y, standing_com);
    }

    #[test]
    fn physical_profile_exactly_matches_r24d17_controller_profile() {
        let portable = recovery_physical_development_threshold_profile_v1();
        let frozen = crate::recovery_runtime::recovery_development_profile_v1();
        let source = frozen.thresholds;
        assert_eq!(
            portable.profile_id,
            crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID
        );
        assert_eq!(
            portable.entry_prone_height_ratio_max,
            source.entry_prone_height_ratio_max
        );
        assert_eq!(
            portable.entry_torso_up_dot_max,
            source.entry_torso_up_dot_max
        );
        assert_eq!(
            portable.entry_prone_confirm_steps,
            source.entry_prone_confirm_steps
        );
        assert_eq!(
            portable.distal_bearing_minimum_impulse_ns,
            source.distal_bearing_minimum_impulse_ns
        );
        assert_eq!(
            portable.minimum_com_height_gain_m,
            source.minimum_com_height_gain_m
        );
        assert_eq!(
            portable.stance_height_ratio_min,
            source.stance_height_ratio_min
        );
        assert_eq!(
            portable.stance_torso_up_dot_min,
            source.stance_torso_up_dot_min
        );
        assert_eq!(
            portable.minimum_nonfoot_clearance_m,
            source.minimum_nonfoot_clearance_m
        );
        assert_eq!(
            portable.maximum_forbidden_contact_impulse_ns,
            source.maximum_forbidden_contact_impulse_ns
        );
        assert_eq!(
            portable.maximum_terminal_linear_speed_m_s,
            source.maximum_terminal_linear_speed_m_s
        );
        assert_eq!(
            portable.maximum_terminal_angular_speed_rad_s,
            source.maximum_terminal_angular_speed_rad_s
        );
        assert_eq!(portable.stance_dwell_steps, source.stance_dwell_steps);
        assert_eq!(
            portable.per_phase_timeout_steps.confirm_prone,
            source.confirm_prone_timeout_steps
        );
        assert_eq!(
            portable.per_phase_timeout_steps.establish_distal_support,
            source.establish_distal_support_timeout_steps
        );
        assert_eq!(
            portable.per_phase_timeout_steps.raise_body,
            source.raise_body_timeout_steps
        );
        assert_eq!(
            portable.per_phase_timeout_steps.stance_handoff,
            source.stance_handoff_timeout_steps
        );
        assert_eq!(
            portable.per_phase_timeout_steps.stance_dwell,
            source.stance_dwell_timeout_steps
        );
        assert_eq!(portable.total_timeout_steps, source.total_timeout_steps);
        assert_eq!(
            portable.maximum_energy_balance_residual_j,
            source.maximum_energy_balance_residual_j
        );
        assert!(portable.physical_threshold_authority);
        assert!(portable.physical_execution_permitted);
        assert!(!portable.population_claim);
        assert!(!portable.release_authority);
    }

    #[test]
    fn native_physical_pair_can_close_as_valid_incomplete_without_success_claim() {
        let mut init = initialization(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryArmKindV1::CandidateCommand,
        );
        init.threshold_profile_id =
            crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned();
        let initialized = initialize_recovery_v1(init).unwrap();
        assert_eq!(
            initialized.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(initialized.controller_implemented);
        assert!(initialized.physical_threshold_authority);
        assert!(!initialized.physical_question_opened);

        let candidate = native_observation(RecoveryArmKindV1::CandidateCommand, 0);
        let zero = native_observation(RecoveryArmKindV1::MatchedZeroCommand, 0);
        let initial_sha256 = initial_state_sha256(&candidate).unwrap();
        assert_eq!(initial_sha256, initial_state_sha256(&zero).unwrap());
        let receipt = evaluate_recovery_trace_v1(RecoveryEvaluationRequestV1 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V1_VERSION.to_owned(),
            task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
            semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
            actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
            threshold_profile_id:
                crate::recovery_runtime::EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(RecoveryNativeEngineV1::MujocoNative),
            candidate_trace: RecoveryTraceV1 {
                schema_version: RECOVERY_TRACE_V1_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::CandidateCommand,
                declared_initial_state_sha256: initial_sha256.clone(),
                observations: vec![candidate],
            },
            matched_zero_command_trace: RecoveryTraceV1 {
                schema_version: RECOVERY_TRACE_V1_VERSION.to_owned(),
                arm_kind: RecoveryArmKindV1::MatchedZeroCommand,
                declared_initial_state_sha256: initial_sha256,
                observations: vec![zero],
            },
        })
        .unwrap();
        assert_eq!(
            receipt.verdict,
            RecoveryEvaluationVerdictV1::PhysicalDevelopmentIncomplete
        );
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(receipt.physical_development_trace_valid);
        assert!(receipt.physical_threshold_authority);
        assert!(receipt.physical_question_opened);
        assert!(receipt.controller_implemented);
        assert!(!receipt.physical_result);
        assert!(!receipt.prone_to_standing_claimed);
        assert!(!receipt.physical_acceptance_authority);
        assert!(!receipt.release_authority);
    }

    #[test]
    fn exact_scope_initialization_is_zero_world_and_nonphysical() {
        for engine in [
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryNativeEngineV1::MujocoNative,
        ] {
            let receipt =
                initialize_recovery_v1(initialization(engine, RecoveryArmKindV1::CandidateCommand))
                    .unwrap();
            assert_eq!(
                receipt.support_status,
                RecoverySupportStatusV1::SupportedExact
            );
            assert!(receipt.memory.is_some());
            assert_eq!(receipt.world_build_count, 0);
            assert_eq!(receipt.solver_step_count, 0);
            assert!(!receipt.controller_implemented);
            assert!(!receipt.physical_threshold_authority);
            assert!(!receipt.prone_to_standing_claimed);
            assert!(!receipt.physical_acceptance_authority);
            assert!(!receipt.release_authority);
        }
    }

    #[test]
    fn synthetic_candidate_and_matched_zero_replay_on_all_capability_identities() {
        for engine in [
            RecoveryNativeEngineV1::GodotJolt4_7,
            RecoveryNativeEngineV1::RapierParryNative,
            RecoveryNativeEngineV1::MujocoNative,
        ] {
            let receipt = evaluate_recovery_trace_v1(evaluation_request(engine)).unwrap();
            assert_eq!(
                receipt.verdict,
                RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
            );
            assert!(receipt.synthetic_canary_passed);
            assert!(receipt.initial_state_identity_matched);
            assert!(receipt.candidate_synthetic_path_completed);
            assert!(receipt.matched_zero_command_control_failed_to_complete);
            assert_eq!(
                receipt.candidate_trace.as_ref().unwrap().final_phase,
                RecoveryPhaseV1::Complete
            );
            assert_eq!(
                receipt
                    .matched_zero_command_trace
                    .as_ref()
                    .unwrap()
                    .final_phase,
                RecoveryPhaseV1::Failed
            );
            assert_eq!(receipt.world_build_count, 0);
            assert!(!receipt.physical_result);
            assert!(!receipt.prone_to_standing_claimed);
        }
    }

    #[test]
    fn exact_twelve_declared_negative_controls_fail_closed() {
        let engine = RecoveryNativeEngineV1::RapierParryNative;
        let mut rejected = 0;

        let mut matched = evaluation_request(engine);
        matched.matched_zero_command_trace.observations.clear();
        rejected += usize::from(
            !evaluate_recovery_trace_v1(matched)
                .unwrap()
                .synthetic_canary_passed,
        );

        let mutations: [fn(&mut RecoveryEvaluationRequestV1); 8] = [
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .root_force_application_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .root_pose_write_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .pin_or_guide_constraint_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .hidden_body_actuation_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .pose_teleport_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .contact_relabel_count = 1;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[3].semantic_step = 2;
            },
            |value: &mut RecoveryEvaluationRequestV1| {
                value.candidate_trace.observations[2]
                    .external_interventions
                    .engine_specific_policy_branch_count = 1;
            },
        ];
        for mutate in mutations {
            let mut request = evaluation_request(engine);
            mutate(&mut request);
            rejected += usize::from(
                !evaluate_recovery_trace_v1(request)
                    .unwrap()
                    .synthetic_canary_passed,
            );
        }

        let mut missing = initialization(engine, RecoveryArmKindV1::CandidateCommand);
        missing.adapter_capability.ordered_channels.pop();
        rejected += usize::from(
            initialize_recovery_v1(missing).unwrap().support_status
                == RecoverySupportStatusV1::UnsupportedCapability,
        );

        let mut ood = initialization(engine, RecoveryArmKindV1::CandidateCommand);
        ood.descriptor = BoundedQuadrupedDescriptor::reference("valid_out_of_domain");
        rejected += usize::from(
            initialize_recovery_v1(ood).unwrap().support_status
                == RecoverySupportStatusV1::OutOfDomainMorphology,
        );

        let mut profile = initialization(engine, RecoveryArmKindV1::CandidateCommand);
        profile.actuator_profile_id = "mutated_profile".to_owned();
        rejected += usize::from(
            initialize_recovery_v1(profile).unwrap().support_status
                == RecoverySupportStatusV1::UnsupportedProfile,
        );

        assert_eq!(rejected, 12);
    }

    #[test]
    fn legacy_v1_request_shape_is_unchanged_and_rejects_morphology_context() {
        let request = initialization(
            RecoveryNativeEngineV1::MujocoNative,
            RecoveryArmKindV1::CandidateCommand,
        );
        let mut serialized = serde_json::to_value(&request).unwrap();
        let object = serialized.as_object_mut().unwrap();
        assert!(!object.contains_key("morphology_context"));
        assert_eq!(
            object
                .get("schema_version")
                .and_then(serde_json::Value::as_str),
            Some(RECOVERY_INITIALIZE_REQUEST_V1_VERSION)
        );
        object.insert(
            "morphology_context".to_owned(),
            serde_json::to_value(exact_recovery_context()).unwrap(),
        );
        assert!(serde_json::from_value::<RecoveryInitializeRequestV1>(serialized).is_err());
    }

    #[test]
    fn v2_context_binds_exact_recovery_identity_across_initialize_step_and_replay() {
        let engine = RecoveryNativeEngineV1::MujocoNative;
        let context = exact_recovery_context();
        let recovery_initialization = initialize_recovery_v2(initialization_v2(
            engine,
            RecoveryArmKindV1::CandidateCommand,
        ))
        .unwrap();
        assert_eq!(
            recovery_initialization.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert_eq!(
            recovery_initialization.descriptor_sha256,
            context.recovery_descriptor_sha256
        );
        assert_eq!(
            recovery_initialization.morphology_spec_sha256,
            context.recovery_morphology_spec_sha256
        );

        let mut prone = observation(
            engine,
            RecoveryArmKindV1::CandidateCommand,
            0,
            true,
            false,
            false,
            false,
        );
        for (joint, position) in prone
            .state
            .ordered_joint_observations
            .iter_mut()
            .zip([1.55, 1.10, 1.55, 1.10, -1.55, -1.10, -1.55, -1.10])
        {
            joint.position_rad = Some(position);
        }
        let recovery_step = step_recovery_v2(RecoveryStepRequestV2 {
            schema_version: RECOVERY_STEP_REQUEST_V2_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: context.clone(),
            adapter_capability: capability(engine),
            memory: recovery_initialization.memory.unwrap(),
            observation: prone.clone(),
        })
        .unwrap();
        assert_eq!(
            recovery_step.support_status,
            RecoverySupportStatusV1::SupportedExact
        );
        assert!(
            recovery_step
                .classification
                .as_ref()
                .unwrap()
                .joint_limits_respected
        );

        let legacy_initialization =
            initialize_recovery_v1(initialization(engine, RecoveryArmKindV1::CandidateCommand))
                .unwrap();
        let legacy_step = step_recovery_v1(RecoveryStepRequestV1 {
            schema_version: RECOVERY_STEP_REQUEST_V1_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(engine),
            memory: legacy_initialization.memory.unwrap(),
            observation: prone,
        })
        .unwrap();
        assert!(
            !legacy_step
                .classification
                .as_ref()
                .unwrap()
                .joint_limits_respected
        );

        let legacy_evaluation = evaluation_request(engine);
        let evaluation = evaluate_recovery_trace_v2(RecoveryEvaluationRequestV2 {
            schema_version: RECOVERY_EVALUATION_REQUEST_V2_VERSION.to_owned(),
            task_id: legacy_evaluation.task_id,
            semantics_id: legacy_evaluation.semantics_id,
            actuator_profile_id: legacy_evaluation.actuator_profile_id,
            threshold_profile_id: legacy_evaluation.threshold_profile_id,
            descriptor: legacy_evaluation.descriptor,
            morphology_context: context.clone(),
            adapter_capability: legacy_evaluation.adapter_capability,
            candidate_trace: legacy_evaluation.candidate_trace,
            matched_zero_command_trace: legacy_evaluation.matched_zero_command_trace,
        })
        .unwrap();
        assert_eq!(
            evaluation.verdict,
            RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
        );
        assert_eq!(
            evaluation.descriptor_sha256,
            context.recovery_descriptor_sha256
        );
        assert_eq!(
            evaluation.morphology_spec_sha256,
            context.recovery_morphology_spec_sha256
        );
    }

    #[test]
    fn v2_context_mutation_and_infeasible_geometry_fail_closed() {
        let engine = RecoveryNativeEngineV1::MujocoNative;
        let mut mutated = initialization_v2(engine, RecoveryArmKindV1::CandidateCommand);
        mutated.morphology_context.recovery_morphology_spec_sha256 =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_owned();
        assert!(matches!(
            initialize_recovery_v2(mutated),
            Err(CoreError::Identity(_))
        ));

        let mut infeasible_descriptor =
            RecoveryMorphologyDescriptorV1::exact_s169_reference(r23d60_selected_s169_descriptor());
        infeasible_descriptor.recovery_morphology_id = "recovery_context_infeasible".to_owned();
        infeasible_descriptor.joint_authority.hip_anchor_parent_y_m = -0.05;
        infeasible_descriptor
            .joint_authority
            .hip_limit_magnitude_rad = 0.72;
        infeasible_descriptor
            .canonical_prone_pose
            .front_hip_angle_rad = 0.72;
        infeasible_descriptor
            .canonical_prone_pose
            .rear_hip_angle_rad = -0.72;
        let mut infeasible = initialization_v2(engine, RecoveryArmKindV1::CandidateCommand);
        infeasible.morphology_context = recovery_context_for(infeasible_descriptor);
        let refusal = initialize_recovery_v2(infeasible).unwrap();
        assert_eq!(
            refusal.support_status,
            RecoverySupportStatusV1::OutOfDomainMorphology
        );
        assert_eq!(
            refusal.refusal_reason.as_deref(),
            Some("canonical_prone_pose_ground_penetration")
        );
        assert!(refusal.memory.is_none());
    }

    #[test]
    fn nonfinite_native_and_over_budget_observations_are_invalid_not_results() {
        let engine = RecoveryNativeEngineV1::MujocoNative;
        let init =
            initialize_recovery_v1(initialization(engine, RecoveryArmKindV1::CandidateCommand))
                .unwrap();
        let memory = init.memory.unwrap();

        let mut nonfinite = observation(
            engine,
            RecoveryArmKindV1::CandidateCommand,
            0,
            true,
            false,
            false,
            false,
        );
        nonfinite.center_of_mass.position_world_m.y = f64::NAN;
        let receipt = step_recovery_v1(RecoveryStepRequestV1 {
            schema_version: RECOVERY_STEP_REQUEST_V1_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(engine),
            memory: memory.clone(),
            observation: nonfinite,
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert!(!receipt.physical_result);

        let mut over_budget = observation(
            engine,
            RecoveryArmKindV1::CandidateCommand,
            0,
            true,
            false,
            false,
            false,
        );
        over_budget.applied_actuation.ordered_applied_impulses[0].applied_angular_impulse_nms = 1.0;
        let receipt = step_recovery_v1(RecoveryStepRequestV1 {
            schema_version: RECOVERY_STEP_REQUEST_V1_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            adapter_capability: capability(engine),
            memory,
            observation: over_budget,
        })
        .unwrap();
        assert_eq!(
            receipt.support_status,
            RecoverySupportStatusV1::InvalidObservation
        );
        assert!(
            receipt
                .refusal_reason
                .as_deref()
                .unwrap()
                .starts_with("published_actuator_budget_exceeded")
        );
    }

    #[test]
    fn synthetic_threshold_profile_is_content_addressed_and_never_physical() {
        let profile = recovery_synthetic_threshold_profile_v1();
        let digest = digest_serializable(&profile).unwrap();
        println!("QSDK_R24D2_SYNTHETIC_THRESHOLD_PROFILE_SHA256={digest}");
        assert!(digest.starts_with("sha256:"));
        assert_eq!(digest.len(), 71);
        assert!(!profile.physical_threshold_authority);
        assert!(!profile.physical_execution_permitted);
        assert!(!profile.population_claim);
        assert_eq!(profile.world_build_count, 0);
        assert!(!profile.release_authority);
    }
}
