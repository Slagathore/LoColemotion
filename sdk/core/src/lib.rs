//! SporeSpore's engine-neutral deterministic locomotion core.
//!
//! This crate owns schemas, pure morphology/controller math, canonical
//! receipts, coverage analysis, and semantic scheduling. It deliberately owns
//! no physics world, host object, contact callback, or actuator side effect.

pub mod actuator_profile;
pub mod adaptation;
pub mod canonical;
pub mod canonical_actuation;
pub mod controller;
pub mod coverage;
pub mod ffi;
pub mod joint_pose_entry;
pub mod protocol;
pub mod quadruped;
pub mod recovery;
pub mod recovery_energy;
pub mod recovery_energy_v3;
pub mod recovery_feasible_support;
pub mod recovery_floor_reference;
pub mod recovery_morphology;
pub mod recovery_runtime;
pub mod recovery_support_plane;
pub mod recovery_support_progression;
pub mod recovery_support_hold_posture;
pub mod recovery_measured_support_transfer;
pub mod recovery_measured_pose_support;
pub mod recovery_anchored_body_pose;
pub mod recovery_advancing_body_origin;
pub mod recovery_remaining_support_release;
pub mod recovery_joint_feasible_height;
pub mod recovery_extended_support_transfer;
pub mod recovery_bounded_stop_velocity;
pub mod recovery_zero_velocity_brake;
pub mod recovery_initialized_zero_brake;
pub mod recovery_extended_preparation;
pub mod runtime;
pub mod scheduler;
pub mod schema;
pub mod stability;

pub use actuator_profile::{
    ACTUATOR_CAP_PROFILE_RECEIPT_V1_VERSION, ACTUATOR_CAP_PROFILE_REQUEST_V1_VERSION,
    ACTUATOR_CAP_PROFILE_V1_VERSION, ACTUATOR_PROFILE_OUTER_STEP_DURATION_S,
    ACTUATOR_PROFILE_OUTER_STEP_HZ, ActuatorCapEntryV1, ActuatorCapProfileClaimBoundaryV1,
    ActuatorCapProfileProvenanceV1, ActuatorCapProfileReceiptV1, ActuatorCapProfileRequestV1,
    ActuatorCapProfileSemanticsV1, ActuatorCapProfileSupportStatusV1, ActuatorCapProfileV1,
    ActuatorCapSourceV1, OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
    R23D60_SELECTED_S169_DESCRIPTOR_SHA256, R23D60_SELECTED_S169_MORPHOLOGY_ID,
    R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256, r23d60_selected_s169_descriptor,
    resolve_actuator_cap_profile_v1,
};
pub use adaptation::{
    ADAPTATION_CANDIDATE_EXPERIENCE_V1_VERSION, ADAPTATION_CONTROLLER_CONTEXT_V1_VERSION,
    ADAPTATION_HISTORY_V1_VERSION, ADAPTATION_PROVIDER_MEMORY_V1_VERSION,
    ADAPTATION_PROVIDER_REQUEST_V1_VERSION, ADAPTATION_PROVIDER_RESPONSE_V1_VERSION,
    ADAPTATION_RESOLUTION_RECEIPT_V1_VERSION, ADAPTATION_RESOLUTION_REQUEST_V1_VERSION,
    ADAPTATION_SAFETY_ENVELOPE_V1_VERSION, AdaptationActuatorLimitV1,
    AdaptationCandidateExperienceV1, AdaptationControllerContextV1, AdaptationCorrectionKindV1,
    AdaptationFallbackReasonV1, AdaptationHistoryEntryV1, AdaptationHistoryV1,
    AdaptationProposedCorrectionV1, AdaptationProviderMemoryV1, AdaptationProviderProvenanceV1,
    AdaptationProviderRequestV1, AdaptationProviderResponseV1, AdaptationProviderStatusV1,
    AdaptationResolutionReceiptV1, AdaptationResolutionRequestV1,
    AdaptationResolvedActuatorCommandV1, AdaptationSafetyEnvelopeV1,
    MAX_ADAPTATION_HISTORY_ENTRIES_V1, MAX_ADAPTATION_OPAQUE_MEMORY_BYTES_V1,
    resolve_adaptation_v1,
};
pub use canonical::{
    canonical_json, digest_json, digest_serializable, project_binary64_to_canonical_number_v1,
    project_binary64_to_guarded_canonical_number_v1,
};
pub use canonical_actuation::{
    CANONICAL_VELOCITY_ACTUATION_FRAME_V1_VERSION, CANONICAL_VELOCITY_RESIDUAL_V1_VERSION,
    COMPLETE_CLOSED_LOOP_CANONICAL_VELOCITY_PROFILE_ID, CanonicalVelocityActuationFrameV1,
    CanonicalVelocityActuatorCommandV1, CanonicalVelocityResidualV1,
    GODOT_JOLT_CANONICAL_TO_HOST_VELOCITY_SIGN, GODOT_JOLT_VELOCITY_ONLY_EQUIVALENCE_PROFILE_ID,
    LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN, LEGACY_GODOT_HOST_VELOCITY_CONVENTION_ID,
    LoadBearingActuationV1, MUJOCO_CANONICAL_TO_HOST_VELOCITY_SIGN,
    MUJOCO_PER_ACTUATOR_FORCE_LIMITED_FIVE_SUBSTEP_DEVELOPMENT_PROFILE_ID,
    MUJOCO_VELOCITY_SERVO_FORCE_LIMITED_FIVE_SUBSTEP_PROFILE_ID, PositionTargetRoleV1,
    RAPIER_CANONICAL_TO_HOST_VELOCITY_SIGN, RAPIER_FORCE_BASED_VELOCITY_ONLY_PROFILE_ID,
    VELOCITY_ONLY_HOST_MAPPING_RECEIPT_V1_VERSION, VELOCITY_ONLY_HOST_PROFILE_V1_VERSION,
    VelocityOnlyHostActuatorCommandV1, VelocityOnlyHostMappingReceiptV1, VelocityOnlyHostProfileV1,
    canonicalize_and_compose_legacy_velocity_v1, map_canonical_velocity_to_host_v1,
};
pub use controller::{
    BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_POLICY_ID,
    BALANCED_WAVE_RECOVERY_SWING_END_RECONTACT_PROFILE_VERSION,
    SCHEDULED_SWING_END_RECONTACT_MODE_ID,
    BALANCED_WAVE_BOUNDED_STEERING_PROFILE_VERSION, BALANCED_WAVE_BW2_B_POLICY_ID,
    BALANCED_WAVE_BW2_C_POLICY_ID, BALANCED_WAVE_BW2R_A_POLICY_ID, BALANCED_WAVE_BW2R_B_POLICY_ID,
    BALANCED_WAVE_BW2R_C_POLICY_ID, BALANCED_WAVE_BW4R_A_POLICY_ID, BALANCED_WAVE_BW4R_B_POLICY_ID,
    BALANCED_WAVE_BW5R_A_POLICY_ID, BALANCED_WAVE_BW5R_B_POLICY_ID, BALANCED_WAVE_BW5R_C_POLICY_ID,
    BALANCED_WAVE_BW7D_A_POLICY_ID, BALANCED_WAVE_BW7D_B_POLICY_ID, BALANCED_WAVE_BW7D_C_POLICY_ID,
    BALANCED_WAVE_BW7D_D_POLICY_ID, BALANCED_WAVE_BW8U_A_POLICY_ID, BALANCED_WAVE_BW8U_B_POLICY_ID,
    BALANCED_WAVE_BW8U_C_POLICY_ID, BALANCED_WAVE_BW8U_D_POLICY_ID,
    BALANCED_WAVE_BW14V_B_POLICY_ID, BALANCED_WAVE_BW15F_B_POLICY_ID,
    BALANCED_WAVE_BW15F_C_POLICY_ID, BALANCED_WAVE_BW15F_D_POLICY_ID,
    BALANCED_WAVE_BW21L_B_POLICY_ID, BALANCED_WAVE_BW21L_C_POLICY_ID,
    BALANCED_WAVE_BW21L_D_POLICY_ID, BALANCED_WAVE_BW23Y_B_POLICY_ID,
    BALANCED_WAVE_BW34Y_A_POLICY_ID, BALANCED_WAVE_CONTINUOUS_PROFILE_VERSION,
    BALANCED_WAVE_FILTERED_PROFILE_VERSION,
    BALANCED_WAVE_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
    BALANCED_WAVE_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION,
    BALANCED_WAVE_POLICY_ID, BALANCED_WAVE_PREDICTIVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION,
    BALANCED_WAVE_PROFILE_VERSION, BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
    BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P10_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID,
    BALANCED_WAVE_R23D26_STEERING_CAP_0P30_POLICY_ID,
    BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    BALANCED_WAVE_RELEASE_GATE_UNWEIGHTING_PROFILE_VERSION,
    BALANCED_WAVE_RELEASE_PROGRESS_PROFILE_VERSION,
    BALANCED_WAVE_SIGNED_FORWARD_VELOCITY_FOOT_PLACEMENT_PROFILE_VERSION,
    BALANCED_WAVE_STABILITY_GUARDED_STEERING_PROFILE_VERSION, BalancedWaveProfile,
    COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID, Candidate35Profile,
    DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
    FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID,
    MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
    PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    RECIPROCAL_STEERING_STRIDE_TRANSFORM_ID, RELEASE_GATE_HIP_SWING_APEX_TARGET_MODE_ID,
    RELEASE_GATE_KNEE_SWING_APEX_TARGET_MODE_ID, SELECTED_BALANCED_WAVE_CANDIDATE_ID,
    SELECTED_BALANCED_WAVE_POLICY_ID, TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    balanced_wave_profile, balanced_wave_profile_for_policy, candidate35_profile,
};
pub use coverage::{ContinuousDomainCertificate, CoverageClass, compile_gq15_domain_certificate};
pub use protocol::{
    ActuationFrame, ActuatorCommand, ContactObservation, ForwardVelocityFootPlacementLimbReceipt,
    ForwardVelocityFootPlacementReceipt, MotionCommand, ReleaseGateUnweightingReceipt, StateFrame,
    SteeringAuthorityGuardReceipt,
};
pub use quadruped::{
    BoundedQuadrupedDescriptor, CompiledQuadruped, compile_bounded_quadruped, interaction_score,
};
pub use recovery::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, GODOT_JOLT_R24D57_ENERGY_SOURCE_PROFILE_ID,
    GODOT_JOLT_R24D126_ENERGY_AUTHORITY_SOURCE_SHA256,
    GODOT_JOLT_R24D126_INCOMPLETE_ENERGY_PARTITION_AUTHORITY_PROFILE_ID,
    PORTABLE_RECOVERY_SEMANTICS_ID, RECOVERY_ADAPTER_CAPABILITY_V1_VERSION,
    RECOVERY_DEVELOPMENT_PROGRESSION_RECEIPT_V1_VERSION,
    RECOVERY_ENERGY_PARTITION_AUTHORITY_V1_VERSION, RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION,
    RECOVERY_EVALUATION_RECEIPT_V1_VERSION, RECOVERY_EVALUATION_REQUEST_V1_VERSION,
    RECOVERY_EVALUATION_REQUEST_V2_VERSION, RECOVERY_EVALUATION_REQUEST_V3_VERSION,
    RECOVERY_EVALUATION_REQUEST_V4_VERSION, RECOVERY_EVALUATION_REQUEST_V5_VERSION,
    RECOVERY_INITIALIZE_RECEIPT_V1_VERSION, RECOVERY_INITIALIZE_REQUEST_V1_VERSION,
    RECOVERY_INITIALIZE_REQUEST_V2_VERSION, RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION,
    RECOVERY_OBSERVATION_V1_VERSION, RECOVERY_OBSERVATION_V2_VERSION,
    RECOVERY_OBSERVATION_V3_VERSION, RECOVERY_OUTER_STEP_DURATION_S, RECOVERY_OUTER_STEP_HZ,
    RECOVERY_STEP_RECEIPT_V1_VERSION, RECOVERY_STEP_RECEIPT_V2_VERSION,
    RECOVERY_STEP_REQUEST_V1_VERSION, RECOVERY_STEP_REQUEST_V2_VERSION,
    RECOVERY_STEP_REQUEST_V3_VERSION, RECOVERY_STEP_REQUEST_V4_VERSION,
    RECOVERY_STEP_REQUEST_V5_VERSION, RECOVERY_SUPERVISOR_MEMORY_V1_VERSION,
    RECOVERY_SYNTHETIC_THRESHOLD_PROFILE_V1_VERSION, RECOVERY_TRACE_V1_VERSION,
    RECOVERY_TRACE_V2_VERSION, RECOVERY_TRACE_V3_VERSION, RecoveryAdapterCapabilityV1,
    RecoveryAppliedActuationReceiptV1, RecoveryAppliedActuatorImpulseV1, RecoveryArmKindV1,
    RecoveryBodyClearanceObservationV1, RecoveryCenterOfMassObservationV1,
    RecoveryChannelCapabilityV1, RecoveryChannelSupportV1, RecoveryControllerOwnerV1,
    RecoveryControllerOwnershipReceiptV1, RecoveryDevelopmentProgressionReceiptV1,
    RecoveryEnergyBalanceLedgerV1, RecoveryEnergyPartitionAuthorityV1,
    RecoveryEngineStepIdentityV1, RecoveryEvaluationReceiptV1, RecoveryEvaluationRequestV1,
    RecoveryEvaluationRequestV2, RecoveryEvaluationRequestV3, RecoveryEvaluationRequestV4,
    RecoveryEvaluationRequestV5, RecoveryEvaluationVerdictV1, RecoveryExternalInterventionLedgerV1,
    RecoveryFootBearingObservationV1, RecoveryInitializeReceiptV1, RecoveryInitializeRequestV1,
    RecoveryInitializeRequestV2, RecoveryMorphologyContextV1, RecoveryNativeEngineV1,
    RecoveryObservationChannelV1, RecoveryObservationSourceKindV1, RecoveryObservationV1,
    RecoveryObservationV2, RecoveryObservationV3, RecoveryPhaseTimeoutsV1, RecoveryPhaseV1,
    RecoveryPoseClassV1, RecoveryPoseClassificationV1, RecoveryStepReceiptV1,
    RecoveryStepReceiptV2, RecoveryStepRequestV1, RecoveryStepRequestV2, RecoveryStepRequestV3,
    RecoveryStepRequestV4, RecoveryStepRequestV5, RecoverySupervisorMemoryV1,
    RecoverySupportStatusV1, RecoverySyntheticThresholdProfileV1, RecoveryTraceReplayReceiptV1,
    RecoveryTraceV1, RecoveryTraceV2, RecoveryTraceV3, SYNTHETIC_ZERO_WORLD_THRESHOLD_PROFILE_ID,
    evaluate_recovery_trace_v1, evaluate_recovery_trace_v2, evaluate_recovery_trace_v3,
    evaluate_recovery_trace_v4, evaluate_recovery_trace_v5, initialize_recovery_v1,
    initialize_recovery_v2, recovery_synthetic_threshold_profile_v1,
    required_recovery_observation_channels_v1, step_recovery_v1, step_recovery_v2,
    step_recovery_v3, step_recovery_v4, step_recovery_v5,
};
pub use recovery_energy::{
    RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V2_VERSION,
    RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V2_VERSION, RECOVERY_ENERGY_BALANCE_EQUATION_V2_ID,
    RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V2_VERSION,
    RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V2_VERSION,
    RECOVERY_ENERGY_BALANCE_LEDGER_V1_VERSION, RECOVERY_ENERGY_BALANCE_LEDGER_V2_VERSION,
    RECOVERY_ENERGY_BALANCE_MIGRATION_RECEIPT_V1_VERSION,
    RECOVERY_ENERGY_BALANCE_MIGRATION_REQUEST_V1_VERSION,
    RECOVERY_ENERGY_COMPONENT_PARTITION_V2_ID, RECOVERY_ENERGY_V1_MIGRATION_PROFILE_ID,
    RecoveryEnergyBalanceAggregationReceiptV2, RecoveryEnergyBalanceAggregationRequestV2,
    RecoveryEnergyBalanceEvaluationReceiptV2, RecoveryEnergyBalanceEvaluationRequestV2,
    RecoveryEnergyBalanceLedgerV2, RecoveryEnergyBalanceMigrationDirectionV1,
    RecoveryEnergyBalanceMigrationReceiptV1, RecoveryEnergyBalanceMigrationRequestV1,
    RecoveryEnergyBalanceSupportStatusV1, RecoveryEnergyWorkIncrementV2,
    aggregate_recovery_energy_balance_v2, evaluate_recovery_energy_balance_v2,
    migrate_recovery_energy_balance_v1,
};
pub use recovery_energy_v3::{
    RECOVERY_ENERGY_BALANCE_AGGREGATION_RECEIPT_V3_VERSION,
    RECOVERY_ENERGY_BALANCE_AGGREGATION_REQUEST_V3_VERSION, RECOVERY_ENERGY_BALANCE_EQUATION_V3_ID,
    RECOVERY_ENERGY_BALANCE_EVALUATION_RECEIPT_V3_VERSION,
    RECOVERY_ENERGY_BALANCE_EVALUATION_REQUEST_V3_VERSION,
    RECOVERY_ENERGY_BALANCE_LEDGER_V3_VERSION, RECOVERY_ENERGY_COMPONENT_PARTITION_V3_ID,
    RecoveryEnergyBalanceAggregationReceiptV3, RecoveryEnergyBalanceAggregationRequestV3,
    RecoveryEnergyBalanceEvaluationReceiptV3, RecoveryEnergyBalanceEvaluationRequestV3,
    RecoveryEnergyBalanceLedgerV3, RecoveryEnergyWorkIncrementV3,
    aggregate_recovery_energy_balance_v3, evaluate_recovery_energy_balance_v3,
};
pub use recovery_morphology::{
    RECOVERY_MORPHOLOGY_DESCRIPTOR_V1_VERSION, RECOVERY_MORPHOLOGY_RECEIPT_V1_VERSION,
    RECOVERY_PRONE_GEOMETRY_RECEIPT_V1_VERSION, RECOVERY_S169_REFERENCE_MORPHOLOGY_ID,
    RecoveryCanonicalPronePoseV1, RecoveryJointAuthorityV1, RecoveryMorphologyClaimBoundaryV1,
    RecoveryMorphologyDescriptorV1, RecoveryMorphologyReceiptV1, RecoveryMorphologySupportStatusV1,
    RecoveryProneGeometryReceiptV1, RecoveryProneLimbGeometryV1, compile_recovery_morphology_v1,
};
pub use recovery_runtime::{
    EXACT_S169_DEVELOPMENT_COHORT_ID, EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
    EXACT_S169_HELD_OUT_COHORT_ID, EXACT_S169_RECOVERY_CONTROLLER_ID,
    EXACT_S169_STANCE_CONTROLLER_ID, GODOT_INSTRUMENTED_RUNTIME_PROFILE_ID,
    GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID, GODOT_R24D57_RECOVERY_ROUTE_ID,
    MUJOCO_NATIVE_RUNTIME_PROFILE_ID, RAPIER_NATIVE_RUNTIME_PROFILE_ID,
    RAPIER_R24D48_ENERGY_V2_MAPPING_PROFILE_ID, RAPIER_R24D48_RECOVERY_ROUTE_ID,
    RECOVERY_CONTROL_COMMAND_V1_VERSION, RECOVERY_CONTROL_RECEIPT_V1_VERSION,
    RECOVERY_CONTROL_REQUEST_V1_VERSION, RECOVERY_CONTROL_REQUEST_V2_VERSION,
    RECOVERY_CONTROL_REQUEST_V3_VERSION, RECOVERY_DEVELOPMENT_PROFILE_V1_VERSION,
    RECOVERY_NATIVE_COLLECTION_RECEIPT_V1_VERSION, RECOVERY_NATIVE_COLLECTION_RECEIPT_V2_VERSION,
    RECOVERY_NATIVE_COLLECTION_REQUEST_V1_VERSION, RECOVERY_NATIVE_COLLECTION_REQUEST_V2_VERSION,
    RECOVERY_NATIVE_COLLECTION_REQUEST_V3_VERSION, RECOVERY_NATIVE_COLLECTOR_BINDING_V1_VERSION,
    RECOVERY_OBSERVATION_V2_SOURCE_BINDING_V1_VERSION, RECOVERY_STANCE_CONTROL_RECEIPT_V2_VERSION,
    RECOVERY_STANCE_CONTROL_REQUEST_V1_VERSION, RECOVERY_STANCE_CONTROL_REQUEST_V2_VERSION,
    RECOVERY_STANCE_CONTROL_REQUEST_V3_VERSION, RECOVERY_STANCE_CONTROL_REQUEST_V4_VERSION,
    RECOVERY_STANCE_CONTROLLER_PROFILE_V1_VERSION,
    RECOVERY_STANCE_OBSERVATION_BINDING_RECEIPT_V1_VERSION, RecoveryCohortCellV1,
    RecoveryControlCommandV1, RecoveryControlReceiptV1, RecoveryControlRequestV1,
    RecoveryControlRequestV2, RecoveryControlRequestV3, RecoveryControllerPoseV1,
    RecoveryDevelopmentProfileV1, RecoveryNativeCollectionReceiptV1,
    RecoveryNativeCollectionReceiptV2, RecoveryNativeCollectionRequestV1,
    RecoveryNativeCollectionRequestV2, RecoveryNativeCollectionRequestV3,
    RecoveryNativeCollectorBindingV1, RecoveryObservationV2SourceBindingV1,
    RecoveryPhysicalThresholdsV1, RecoveryStanceControlReceiptV2, RecoveryStanceControlRequestV1,
    RecoveryStanceControlRequestV2, RecoveryStanceControlRequestV3, RecoveryStanceControlRequestV4,
    RecoveryStanceObservationBindingReceiptV1, bind_recovery_observation_v2_source_v1,
    collect_native_recovery_observation_v1, collect_native_recovery_observation_v2,
    collect_native_recovery_observation_v3, plan_recovery_control_v1, plan_recovery_control_v2,
    plan_recovery_control_v3, plan_recovery_stance_control_v1, plan_recovery_stance_control_v2,
    plan_recovery_stance_control_v3, plan_recovery_stance_control_v4,
    recovery_development_profile_v1, recovery_observation_v2_source_identity_supported_v1,
};
pub use runtime::{
    BALANCED_WAVE_MEMORY_VERSION, BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION,
    BALANCED_WAVE_RUNTIME_VERSION, BalancedWaveController, BalancedWaveControllerMemory,
    BalancedWaveControllerStepOutput, Candidate35Controller, Candidate35ControllerMemory,
    ControllerStepOutput,
};
pub use scheduler::{GaitPhase, SemanticGaitScheduler, SemanticGaitState};
pub use schema::{CompiledMorphology, CoreError, MorphologySpec, Result};
pub use stability::{
    CENTROIDAL_COMMAND_VERSION, CENTROIDAL_REQUEST_VERSION, CentroidalSupportCommandV2,
    CentroidalSupportRequestV2, ENDPOINT_FORCE_JOINT_MAP_RECEIPT_V3_VERSION,
    ENDPOINT_FORCE_JOINT_MAP_RECEIPT_VERSION, ENDPOINT_FORCE_JOINT_MAP_REQUEST_V3_VERSION,
    ENDPOINT_FORCE_JOINT_MAP_REQUEST_VERSION, EndpointForceActuatorKinematicsV2,
    EndpointForceJointMapReceiptV2, EndpointForceJointMapReceiptV3, EndpointForceJointMapRequestV2,
    EndpointForceJointMapRequestV3, EndpointForceJointMappingModeV3,
    GeneralizedJointTorqueCommandV2, GeneralizedJointTorqueCommandV3,
    SCHEDULED_LOAD_TRANSFER_BW9L_A_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW9L_B_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW9L_C_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW9L_D_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW10F_A_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW10F_B_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW10F_C_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW10F_D_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW11R_A_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW11R_B_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW11R_C_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW11R_D_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW13P_A_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW13P_B_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_BW13P_C_POLICY_ID, SCHEDULED_LOAD_TRANSFER_BW13P_D_POLICY_ID,
    SCHEDULED_LOAD_TRANSFER_RECEIPT_V2_VERSION, SCHEDULED_LOAD_TRANSFER_RECEIPT_V3_VERSION,
    SCHEDULED_LOAD_TRANSFER_RECEIPT_VERSION, SCHEDULED_LOAD_TRANSFER_REQUEST_V2_VERSION,
    SCHEDULED_LOAD_TRANSFER_REQUEST_V3_VERSION, SCHEDULED_LOAD_TRANSFER_REQUEST_VERSION,
    STABILITY_INFLUENCE_RECEIPT_V3_VERSION, STABILITY_INFLUENCE_RECEIPT_VERSION,
    STABILITY_INFLUENCE_REQUEST_V3_VERSION, STABILITY_INFLUENCE_REQUEST_VERSION,
    STABILITY_STATE_VERSION, ScheduledLimbGaitStepV1, ScheduledLoadTransferContactPreferenceV1,
    ScheduledLoadTransferModeV1, ScheduledLoadTransferReceiptV1, ScheduledLoadTransferReceiptV2,
    ScheduledLoadTransferReceiptV3, ScheduledLoadTransferRequestV1, ScheduledLoadTransferRequestV2,
    ScheduledLoadTransferRequestV3, StabilityInfluenceReceiptV2, StabilityInfluenceReceiptV3,
    StabilityInfluenceRequestV2, StabilityInfluenceRequestV3, StabilityStateV2,
    SupportObservationV2, bound_stability_influence_v2, bound_stability_influence_v3,
    command_centroidal_support_v2, map_endpoint_force_to_joint_v2, map_endpoint_force_to_joint_v3,
    observe_stability_v2, plan_scheduled_load_transfer_v1, plan_scheduled_load_transfer_v2,
    plan_scheduled_load_transfer_v3,
};

pub const LOCOMOTION_SEMANTICS_VERSION: &str = "sporespore_locomotion_semantics_v1";
pub const LOCOMOTION_SEMANTICS_V2_VERSION: &str = "sporespore_locomotion_semantics_v2";
pub const LOCOMOTION_SEMANTICS_V3_VERSION: &str = "sporespore_locomotion_semantics_v3";
pub const LOCOMOTION_SEMANTICS_V4_VERSION: &str = "sporespore_locomotion_semantics_v4";
pub const SDK_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const SDK_ABI_GENERATION: u32 = 1;
