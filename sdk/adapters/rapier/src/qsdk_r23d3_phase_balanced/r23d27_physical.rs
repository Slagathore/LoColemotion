use super::*;

use crate::bw19v_composition::{
    RapierBw19vCompositionMemory, bw19v_observation_available, compose_bw19v_step,
};
use crate::qsdk_r23d11_stability_assisted_taper::{
    Availability as R23D27Availability, CompositionMemory as R23D27CompositionMemory,
    MAXIMUM_COMBINED_VELOCITY, MAXIMUM_NEUTRAL_VELOCITY, compose_active_step,
};
use sporespore_locomotion_core::stability::StabilityInfluenceAvailability;
use sporespore_locomotion_core::{
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
    ScheduledLimbGaitStepV1, digest_serializable, observe_stability_v2,
};

use crate::actuator_cap_profile::resolve_production_public_profile_binding_v1;

const R23D27_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d27_stability_guarded_steering_preregistration_v1.json");
const R23D28_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d28_predictive_stability_guarded_steering_preregistration_v1.json"
);
const R23D29_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1.json"
);
const R23D30_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d30_cycle_coherent_directional_response_preregistration_v1.json"
);
const R23D31_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d31_cycle_integrated_directional_response_preregistration_v1.json"
);
const R23D32_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d32_finite_rapier_turning_replication_preregistration_v1.json"
);
const R23D40_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d40_three_engine_startup_ramp_turning_preregistration_v1.json"
);
const R23D41_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d41_three_engine_startup_ramp_turning_preregistration_v1.json"
);
const R23D42_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d42_three_engine_startup_ramp_turning_preregistration_v1.json"
);
const R23D43_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d43_rapier_retention_hardened_turning_preregistration_v1.json"
);
const R23D44_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d44_rapier_paired_startup_transform_preregistration_v1.json"
);
const R23D48_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d48_support_loss_conditioned_three_engine_turning_preregistration_v1.json"
);
const R23D49_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d49_rapier_retention_repair_replay_preregistration_v1.json"
);
const R23D50_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d50_rapier_cas_path_identity_replay_preregistration_v1.json"
);
const R23D14_TEMPORAL_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d14_tight_gated_horizon_preregistration_v1.json");
const R23D11_PREREGISTRATION_RAW: &str =
    include_str!("../../../../turning/r23d11_stability_assisted_taper_preregistration_v1.json");
const R23D27_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d27_stability_guarded_steering_implementation_v1.json";
const R23D27_CLOSURE_PATH: &str = "sdk/turning/r23d27_stability_guarded_steering_closure_v1.json";
const R23D27_CAMPAIGN_ID: &str = "QSDK-R23D27-RAPIER-STABILITY-GUARDED-STEERING-VALIDATION";
const R23D27_GATE_ID: &str = "QSDK-R23D27";
const R23D27_ENGINE_ID: &str = "rapier_parry";
const R23D27_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d27_engine_cell_report_v1";
const R23D27_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d27_worker_failure_v1";
const R23D27_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d27_physical_trace_row_v1";
const R23D27_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d27_trace_retention_v1";
const R23D27_TRACE_RETENTION_MARKER: &str = "QSDK_R23D27_TRACE_RETENTION ";
const R23D27_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d27_physical_freeze_v1";
const R23D27_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d27_attempt_v1";
const R23D27_STAGE_ID: &str = "rapier_stability_guarded_steering_validation";
const R23D27_CONTROLLER_STEPS: u64 = 2_992;
const R23D27_TERMINAL_STEPS: u64 = 0;
const R23D27_TOTAL_TRACE_STEPS: u64 = R23D27_CONTROLLER_STEPS + R23D27_TERMINAL_STEPS;
const FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA: &str =
    "sporespore_forward_displacement_measurement_origin_receipt_v1";
const LEGACY_TASK_FRAME_MEASUREMENT_ORIGIN_POLICY_ID: &str = "mutable_task_frame_origin_legacy_v1";
const EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID: &str = "evidence_window_start_semantic_step_v1";
const EVIDENCE_WINDOW_START_SEMANTIC_STEP: u64 = 472;
const R23D27_MAXIMUM_ACTIVE_STEPS: u64 = 600;
const R23D27_MINIMUM_TAPER_STEPS: u64 = 120;
const R23D27_MINIMUM_PASSIVE_STEPS: u64 = 360;
const R23D27_SCALE_DENOMINATOR: u64 = 120;
const R23D27_ACTIVE_MODE: &str = "active_neutral_acquisition";
const R23D27_TAPER_MODE: &str = "active_quiescent_taper";
const R23D27_PASSIVE_MODE: &str = "irreversible_zero_actuation_stability";
const R23D27_CONFIRMED_REASON: &str = "support_pose_quiescence_confirmed";
const R23D27_DEADLINE_REASON: &str = "deadline_forced_without_quiescence_confirmation";
const R23D27_COARSE_MAXIMUM_TILT_RAD: f64 = 0.035;
const R23D27_COARSE_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.32;
const R23D27_TIGHT_MAXIMUM_TILT_RAD: f64 = 0.01;
const R23D27_TIGHT_MAXIMUM_JOINT_ERROR_RAD: f64 = 0.2;

const R23D27_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D27_FREEZE";
const R23D27_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D27_ATTEMPT";
const R23D27_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D27_TOKEN";
const R23D27_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D27_STAGE";
const R23D27_CELL_ENV: &str = "SPORESPORE_QSDK_R23D27_CELL";
const R23D27_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D27_ENGINE";
const R23D27_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D27_ATTEMPT_ROOT";
const R23D27_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D27_AUTHORITY_REPO_ROOT";
const R23D27_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D27_PYTHON";
const R23D27_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D27_POWERSHELL";

const R23D28_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d28_predictive_stability_guarded_steering_implementation_v1.json";
const R23D28_CLOSURE_PATH: &str =
    "sdk/turning/r23d28_predictive_stability_guarded_steering_closure_v1.json";
const R23D28_CAMPAIGN_ID: &str =
    "QSDK-R23D28-RAPIER-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT";
const R23D28_GATE_ID: &str = "QSDK-R23D28";
const R23D28_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d28_engine_cell_report_v1";
const R23D28_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d28_worker_failure_v1";
const R23D28_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d28_physical_trace_row_v1";
const R23D28_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d28_trace_retention_v1";
const R23D28_TRACE_RETENTION_MARKER: &str = "QSDK_R23D28_TRACE_RETENTION ";
const R23D28_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d28_physical_freeze_v1";
const R23D28_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d28_attempt_v1";
pub(crate) const R23D28_STAGE_ID: &str = "rapier_predictive_stability_guarded_steering_development";
const R23D28_CANDIDATE_ID: &str = "predictive_stability_guarded_0p20_to_0p28";
const R23D28_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D28_FREEZE";
const R23D28_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D28_ATTEMPT";
const R23D28_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D28_TOKEN";
const R23D28_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D28_STAGE";
const R23D28_CELL_ENV: &str = "SPORESPORE_QSDK_R23D28_CELL";
const R23D28_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D28_ENGINE";
const R23D28_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D28_ATTEMPT_ROOT";
const R23D28_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D28_AUTHORITY_REPO_ROOT";
const R23D28_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D28_PYTHON";
const R23D28_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D28_POWERSHELL";

const R23D29_IMPLEMENTATION_PATH: &str = "sdk/turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1.json";
const R23D29_CLOSURE_PATH: &str =
    "sdk/turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_closure_v1.json";
const R23D29_CAMPAIGN_ID: &str =
    "QSDK-R23D29-RAPIER-TWO-SWING-PERSISTENT-PREDICTIVE-STABILITY-GUARDED-STEERING-DEVELOPMENT";
const R23D29_GATE_ID: &str = "QSDK-R23D29";
const R23D29_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d29_engine_cell_report_v1";
const R23D29_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d29_worker_failure_v1";
const R23D29_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d29_physical_trace_row_v1";
const R23D29_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d29_trace_retention_v1";
const R23D29_TRACE_RETENTION_MARKER: &str = "QSDK_R23D29_TRACE_RETENTION ";
const R23D29_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d29_physical_freeze_v1";
const R23D29_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d29_attempt_v1";
pub(crate) const R23D29_STAGE_ID: &str =
    "rapier_two_swing_persistent_predictive_stability_guarded_steering_development";
const R23D29_CANDIDATE_ID: &str = "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28";
const R23D29_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D29_FREEZE";
const R23D29_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D29_ATTEMPT";
const R23D29_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D29_TOKEN";
const R23D29_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D29_STAGE";
const R23D29_CELL_ENV: &str = "SPORESPORE_QSDK_R23D29_CELL";
const R23D29_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D29_ENGINE";
const R23D29_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D29_ATTEMPT_ROOT";
const R23D29_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D29_AUTHORITY_REPO_ROOT";
const R23D29_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D29_PYTHON";
const R23D29_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D29_POWERSHELL";

const R23D30_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d30_cycle_coherent_directional_response_implementation_v1.json";
const R23D30_CLOSURE_PATH: &str =
    "sdk/turning/r23d30_cycle_coherent_directional_response_closure_v1.json";
const R23D30_CAMPAIGN_ID: &str =
    "QSDK-R23D30-RAPIER-CYCLE-COHERENT-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION";
const R23D30_GATE_ID: &str = "QSDK-R23D30";
const R23D30_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d30_engine_cell_report_v1";
const R23D30_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d30_worker_failure_v1";
const R23D30_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d30_physical_trace_row_v1";
const R23D30_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d30_trace_retention_v1";
const R23D30_TRACE_RETENTION_MARKER: &str = "QSDK_R23D30_TRACE_RETENTION ";
const R23D30_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d30_physical_freeze_v1";
const R23D30_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d30_attempt_v1";
pub(crate) const R23D30_STAGE_ID: &str =
    "rapier_cycle_coherent_directional_response_measurement_validation";
const R23D30_CANDIDATE_ID: &str = "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28";
const R23D30_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D30_FREEZE";
const R23D30_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D30_ATTEMPT";
const R23D30_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D30_TOKEN";
const R23D30_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D30_STAGE";
const R23D30_CELL_ENV: &str = "SPORESPORE_QSDK_R23D30_CELL";
const R23D30_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D30_ENGINE";
const R23D30_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D30_ATTEMPT_ROOT";
const R23D30_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D30_AUTHORITY_REPO_ROOT";
const R23D30_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D30_PYTHON";
const R23D30_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D30_POWERSHELL";
const R23D30_CAMPAIGN_SEED: u64 = 21_504;
const R23D30_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_819_909_968_413_413,
    yaw_rad: -0.005_616_032_518_446_45,
    linear_velocity_world_m_s: [-0.001_546_637_155_115_6, 0.0, 0.002_751_263_324_171_3],
    torso_angular_velocity_world_rad_s: [
        0.000_047_163_339_331_746_1,
        -0.003_010_923_974_215_98,
        -0.000_810_656_696_557_999,
    ],
    gait_phase_offset_ticks: -1,
};

const R23D31_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d31_cycle_integrated_directional_response_implementation_v1.json";
const R23D31_CLOSURE_PATH: &str =
    "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json";
const R23D31_CAMPAIGN_ID: &str =
    "QSDK-R23D31-RAPIER-CYCLE-INTEGRATED-DIRECTIONAL-RESPONSE-MEASUREMENT-VALIDATION";
const R23D31_GATE_ID: &str = "QSDK-R23D31";
const R23D31_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d31_engine_cell_report_v1";
const R23D31_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d31_worker_failure_v1";
const R23D31_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d31_physical_trace_row_v1";
const R23D31_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d31_trace_retention_v1";
const R23D31_TRACE_RETENTION_MARKER: &str = "QSDK_R23D31_TRACE_RETENTION ";
const R23D31_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d31_physical_freeze_v1";
const R23D31_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d31_attempt_v1";
pub(crate) const R23D31_STAGE_ID: &str =
    "rapier_cycle_integrated_directional_response_measurement_validation";
const R23D31_CANDIDATE_ID: &str = "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28";
const R23D31_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D31_FREEZE";
const R23D31_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D31_ATTEMPT";
const R23D31_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D31_TOKEN";
const R23D31_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D31_STAGE";
const R23D31_CELL_ENV: &str = "SPORESPORE_QSDK_R23D31_CELL";
const R23D31_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D31_ENGINE";
const R23D31_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D31_ATTEMPT_ROOT";
const R23D31_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D31_AUTHORITY_REPO_ROOT";
const R23D31_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D31_PYTHON";
const R23D31_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D31_POWERSHELL";
const R23D31_CAMPAIGN_SEED: u64 = 21_505;
const R23D31_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_383_537_524_612_62,
    yaw_rad: -0.004_832_542_501_389_98,
    linear_velocity_world_m_s: [-0.000_736_588_845_029_473, 0.0, 0.003_547_052_852_809_43],
    torso_angular_velocity_world_rad_s: [
        0.000_218_588_626_012_206,
        -0.002_199_356_909_841_3,
        0.001_941_695_110_872_39,
    ],
    gait_phase_offset_ticks: 2,
};

const R23D32_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d32_finite_rapier_turning_replication_implementation_v1.json";
const R23D32_CLOSURE_PATH: &str =
    "sdk/turning/r23d32_finite_rapier_turning_replication_closure_v1.json";
const R23D32_CAMPAIGN_ID: &str = "QSDK-R23D32-RAPIER-FINITE-TURNING-REPLICATION-VALIDATION";
const R23D32_GATE_ID: &str = "QSDK-R23D32";
const R23D32_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d32_engine_cell_report_v1";
const R23D32_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d32_worker_failure_v1";
const R23D32_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d32_physical_trace_row_v1";
const R23D32_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d32_trace_retention_v1";
const R23D32_TRACE_RETENTION_MARKER: &str = "QSDK_R23D32_TRACE_RETENTION ";
const R23D32_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d32_physical_freeze_v1";
const R23D32_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d32_attempt_v1";
pub(crate) const R23D32_STAGE_ID: &str = "rapier_finite_turning_replication_validation";
const R23D32_CANDIDATE_ID: &str = "two_swing_persistent_predictive_stability_guarded_0p20_to_0p28";
const R23D32_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D32_FREEZE";
const R23D32_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D32_ATTEMPT";
const R23D32_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D32_TOKEN";
const R23D32_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D32_STAGE";
const R23D32_CELL_ENV: &str = "SPORESPORE_QSDK_R23D32_CELL";
const R23D32_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D32_ENGINE";
const R23D32_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D32_ATTEMPT_ROOT";
const R23D32_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D32_AUTHORITY_REPO_ROOT";
const R23D32_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D32_PYTHON";
const R23D32_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D32_POWERSHELL";
const R23D32_CAMPAIGN_SEED: u64 = 21_506;
const R23D32_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_792_568_200_267_851,
    yaw_rad: 0.006_294_156_890_362_5,
    linear_velocity_world_m_s: [-0.003_036_018_926_650_29, 0.0, 0.002_007_758_710_533_38],
    torso_angular_velocity_world_rad_s: [
        0.001_023_013_144_731_52,
        0.003_879_645_373_672_25,
        0.001_593_770_226_463_68,
    ],
    gait_phase_offset_ticks: 0,
};

const R23D40_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d40_three_engine_startup_ramp_turning_implementation_v1.json";
const R23D40_CLOSURE_PATH: &str =
    "sdk/turning/r23d40_three_engine_startup_ramp_turning_closure_v1.json";
const R23D40_CAMPAIGN_ID: &str = "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION";
const R23D40_GATE_ID: &str = "QSDK-R23D40";
const R23D40_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d40_engine_cell_report_v1";
const R23D40_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d40_worker_failure_v1";
const R23D40_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d40_turning_trace_row_v1";
const R23D40_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d40_trace_retention_v1";
const R23D40_TRACE_RETENTION_MARKER: &str = "QSDK_R23D40_TRACE_RETAINED ";
const R23D40_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d40_physical_freeze_v1";
const R23D40_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d40_attempt_v1";
pub(crate) const R23D40_STAGE_ID: &str = "three_engine_startup_ramp_turning_validation";
const R23D40_CANDIDATE_ID: &str = "r23d29_startup_ramp_turning_validation";
const R23D40_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D40_FREEZE";
const R23D40_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D40_ATTEMPT";
const R23D40_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D40_TOKEN";
const R23D40_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D40_STAGE";
const R23D40_CELL_ENV: &str = "SPORESPORE_QSDK_R23D40_CELL";
const R23D40_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D40_ENGINE";
const R23D40_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D40_ATTEMPT_ROOT";
const R23D40_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D40_AUTHORITY_REPO_ROOT";
const R23D40_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D40_PYTHON";
const R23D40_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D40_POWERSHELL";
const R23D40_CAMPAIGN_SEED: u64 = 21_508;
const R23D40_STARTUP_RAMP_ID: &str = "canonical_velocity_smoothstep_one_gait_cycle_v1";
const R23D40_STARTUP_RAMP_STEPS: u64 = 360;
const R23D40_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_299_032_486_509_532,
    yaw_rad: -0.001_256_962_772_458_79,
    linear_velocity_world_m_s: [-0.002_163_921_250_030_4, 0.0, -0.000_117_000_658_065_081],
    torso_angular_velocity_world_rad_s: [
        -0.001_846_772_036_515_18,
        -0.000_002_637_039_870_023_73,
        0.001_654_841_471_463_44,
    ],
    gait_phase_offset_ticks: 3,
};

const R23D41_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d41_three_engine_startup_ramp_turning_implementation_v1.json";
const R23D41_CLOSURE_PATH: &str =
    "sdk/turning/r23d41_three_engine_startup_ramp_turning_closure_v1.json";
const R23D41_CAMPAIGN_ID: &str = "QSDK-R23D41-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION";
const R23D41_GATE_ID: &str = "QSDK-R23D41";
const R23D41_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d41_engine_cell_report_v1";
const R23D41_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d41_worker_failure_v1";
const R23D41_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d41_turning_trace_row_v1";
const R23D41_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d41_trace_retention_v1";
const R23D41_TRACE_RETENTION_MARKER: &str = "QSDK_R23D41_TRACE_RETAINED ";
const R23D41_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d41_physical_freeze_v1";
const R23D41_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d41_attempt_v1";
pub(crate) const R23D41_STAGE_ID: &str =
    "three_engine_authorization_repaired_startup_ramp_turning_validation";
const R23D41_CANDIDATE_ID: &str = "r23d29_startup_ramp_turning_validation";
const R23D41_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D41_FREEZE";
const R23D41_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D41_ATTEMPT";
const R23D41_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D41_TOKEN";
const R23D41_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D41_STAGE";
const R23D41_CELL_ENV: &str = "SPORESPORE_QSDK_R23D41_CELL";
const R23D41_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D41_ENGINE";
const R23D41_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D41_ATTEMPT_ROOT";
const R23D41_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D41_AUTHORITY_REPO_ROOT";
const R23D41_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D41_PYTHON";
const R23D41_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D41_POWERSHELL";
const R23D41_CAMPAIGN_SEED: u64 = 21_509;
const R23D41_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_574_131_438_042_969,
    yaw_rad: 0.002_517_911_139_875_65,
    linear_velocity_world_m_s: [-0.001_591_542_968_526_48, 0.0, -0.003_181_105_013_936_76],
    torso_angular_velocity_world_rad_s: [
        0.001_699_818_996_712_57,
        0.000_193_144_660_443_068,
        -0.000_216_255_779_378_116,
    ],
    gait_phase_offset_ticks: -1,
};

const R23D42_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_implementation_v1.json";
const R23D42_CLOSURE_PATH: &str =
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_closure_v1.json";
const R23D42_CAMPAIGN_ID: &str = "QSDK-R23D42-TRACE-INTERFACE-REPAIR-REPLICATION";
const R23D42_GATE_ID: &str = "QSDK-R23D42";
const R23D42_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d42_engine_cell_report_v1";
const R23D42_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d42_worker_failure_v1";
const R23D42_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d42_turning_trace_row_v1";
const R23D42_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d42_trace_retention_v1";
const R23D42_TRACE_RETENTION_MARKER: &str = "QSDK_R23D42_TRACE_RETAINED ";
const R23D42_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d42_physical_freeze_v1";
const R23D42_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d42_attempt_v1";
pub(crate) const R23D42_STAGE_ID: &str = "three_engine_trace_interface_repair_replication";
const R23D42_CANDIDATE_ID: &str = "r23d29_startup_ramp_turning_validation";
const R23D42_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D42_FREEZE";
const R23D42_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D42_ATTEMPT";
const R23D42_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D42_TOKEN";
const R23D42_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D42_STAGE";
const R23D42_CELL_ENV: &str = "SPORESPORE_QSDK_R23D42_CELL";
const R23D42_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D42_ENGINE";
const R23D42_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D42_ATTEMPT_ROOT";
const R23D42_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D42_AUTHORITY_REPO_ROOT";
const R23D42_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D42_PYTHON";
const R23D42_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D42_POWERSHELL";
const R23D42_CAMPAIGN_SEED: u64 = 21_510;
const R23D42_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_629_330_868_832_767,
    yaw_rad: -0.003_790_494_985_878_47,
    linear_velocity_world_m_s: [-0.001_986_867_282_539_61, 0.0, -0.001_810_202_607_885],
    torso_angular_velocity_world_rad_s: [
        0.001_342_963_660_135_87,
        -0.001_646_848_628_297_45,
        0.000_016_219_913_959_503_2,
    ],
    gait_phase_offset_ticks: -3,
};

const R23D43_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d43_rapier_retention_hardened_turning_implementation_v1.json";
const R23D43_CLOSURE_PATH: &str =
    "sdk/turning/r23d43_rapier_retention_hardened_turning_closure_v1.json";
const R23D43_CAMPAIGN_ID: &str = "QSDK-R23D43-RAPIER-RETENTION-HARDENED-TURNING-REPLICATION";
const R23D43_GATE_ID: &str = "QSDK-R23D43";
const R23D43_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d43_engine_cell_report_v1";
const R23D43_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d43_worker_failure_v1";
const R23D43_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d43_turning_trace_row_v1";
const R23D43_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d43_trace_retention_v1";
const R23D43_TRACE_RETENTION_MARKER: &str = "QSDK_R23D43_TRACE_RETENTION ";
const R23D43_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d43_physical_freeze_v1";
const R23D43_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d43_attempt_v1";
pub(crate) const R23D43_STAGE_ID: &str = "rapier_retention_hardened_turning_replication";
const R23D43_CANDIDATE_ID: &str = "r23d29_startup_ramp_turning_validation";
const R23D43_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D43_FREEZE";
const R23D43_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D43_ATTEMPT";
const R23D43_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D43_TOKEN";
const R23D43_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D43_STAGE";
const R23D43_CELL_ENV: &str = "SPORESPORE_QSDK_R23D43_CELL";
const R23D43_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D43_ENGINE";
const R23D43_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D43_ATTEMPT_ROOT";
const R23D43_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D43_AUTHORITY_REPO_ROOT";
const R23D43_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D43_PYTHON";
const R23D43_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D43_POWERSHELL";
const R23D43_CAMPAIGN_SEED: u64 = 21_511;
const R23D43_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_007_303_339_771_169_7,
    yaw_rad: 0.002_133_707_050_234_08,
    linear_velocity_world_m_s: [-0.000_430_257_059_633_732, 0.0, -0.001_419_635_955_244_3],
    torso_angular_velocity_world_rad_s: [
        -0.000_931_125_832_721_591,
        -0.000_651_016_598_567_367,
        -0.001_998_038_263_991_48,
    ],
    gait_phase_offset_ticks: -1,
};

const R23D44_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d44_rapier_paired_startup_transform_implementation_v1.json";
const R23D44_CLOSURE_PATH: &str =
    "sdk/turning/r23d44_rapier_paired_startup_transform_closure_v1.json";
const R23D44_CAMPAIGN_ID: &str = "QSDK-R23D44-RAPIER-PAIRED-STARTUP-TRANSFORM-DEVELOPMENT";
const R23D44_GATE_ID: &str = "QSDK-R23D44";
const R23D44_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d44_engine_cell_report_v1";
const R23D44_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d44_worker_failure_v1";
const R23D44_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d44_turning_trace_row_v1";
const R23D44_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d44_trace_retention_v1";
const R23D44_TRACE_RETENTION_MARKER: &str = "QSDK_R23D44_TRACE_RETENTION ";
const R23D44_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d44_physical_freeze_v1";
const R23D44_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d44_attempt_v1";
pub(crate) const R23D44_STAGE_ID: &str = "rapier_paired_startup_transform_development";
const R23D44_NO_RAMP_CANDIDATE_ID: &str = "r23d29_no_startup_ramp_control";
const R23D44_RAMP_CANDIDATE_ID: &str = "r23d29_canonical_startup_ramp_treatment";
const R23D44_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D44_FREEZE";
const R23D44_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D44_ATTEMPT";
const R23D44_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D44_TOKEN";
const R23D44_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D44_STAGE";
const R23D44_CELL_ENV: &str = "SPORESPORE_QSDK_R23D44_CELL";
const R23D44_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D44_ENGINE";
const R23D44_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D44_ATTEMPT_ROOT";
const R23D44_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D44_AUTHORITY_REPO_ROOT";
const R23D44_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D44_PYTHON";
const R23D44_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D44_POWERSHELL";

const R23D48_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_implementation_v1.json";
const R23D48_CLOSURE_PATH: &str =
    "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json";
const R23D48_CAMPAIGN_ID: &str = "QSDK-R23D48-SUPPORT-LOSS-CONDITIONED-THREE-ENGINE-TURNING";
const R23D48_GATE_ID: &str = "QSDK-R23D48";
const R23D48_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d48_engine_cell_report_v1";
const R23D48_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d48_worker_failure_v1";
const R23D48_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d48_turning_trace_row_v1";
const R23D48_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d48_trace_retention_v1";
const R23D48_TRACE_RETENTION_MARKER: &str = "QSDK_R23D48_TRACE_RETAINED ";
const R23D48_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d48_physical_freeze_v1";
const R23D48_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d48_attempt_v1";
pub(crate) const R23D48_STAGE_ID: &str = "three_engine_support_loss_conditioned_turning_validation";
const R23D48_CANDIDATE_ID: &str = "r23d29_support_loss_conditioned_turning_validation";
const R23D48_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D48_FREEZE";
const R23D48_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D48_ATTEMPT";
const R23D48_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D48_TOKEN";
const R23D48_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D48_STAGE";
const R23D48_CELL_ENV: &str = "SPORESPORE_QSDK_R23D48_CELL";
const R23D48_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D48_ENGINE";
const R23D48_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D48_ATTEMPT_ROOT";
const R23D48_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D48_AUTHORITY_REPO_ROOT";
const R23D48_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D48_PYTHON";
const R23D48_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D48_POWERSHELL";
const R23D48_CAMPAIGN_SEED: u64 = 21_512;
const R23D48_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_977_878_458_797_932,
    yaw_rad: -0.003_037_654_794_752_6,
    linear_velocity_world_m_s: [0.002_695_661_503_821_61, 0.0, 0.000_103_241_764_008_999],
    torso_angular_velocity_world_rad_s: [
        0.000_322_412_699_460_983,
        -0.002_021_209_103_986_62,
        0.000_436_143_483_966_589,
    ],
    gait_phase_offset_ticks: 1,
};
const R23D48_STARTUP_TRANSFORM_ID: &str = "support_loss_latched_smoothstep_one_cycle_v1";
const R23D48_PROBE_LAST_SEMANTIC_STEP: u64 = 3;

const R23D49_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d49_rapier_retention_repair_replay_implementation_v1.json";
const R23D49_CLOSURE_PATH: &str =
    "sdk/turning/r23d49_rapier_retention_repair_replay_closure_v1.json";
const R23D49_CAMPAIGN_ID: &str = "QSDK-R23D49-RAPIER-RETENTION-REPAIR-REPLAY";
const R23D49_GATE_ID: &str = "QSDK-R23D49";
const R23D49_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d49_engine_cell_report_v1";
const R23D49_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d49_worker_failure_v1";
const R23D49_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d49_turning_trace_row_v1";
const R23D49_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d49_trace_retention_v1";
const R23D49_TRACE_RETENTION_MARKER: &str = "QSDK_R23D49_TRACE_RETENTION ";
const R23D49_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d49_physical_freeze_v1";
const R23D49_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d49_attempt_v1";
pub(crate) const R23D49_STAGE_ID: &str = "rapier_r48_retention_repair_replay";
const R23D49_CANDIDATE_ID: &str = "r23d29_support_loss_conditioned_turning_validation";
const R23D49_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D49_FREEZE";
const R23D49_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D49_ATTEMPT";
const R23D49_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D49_TOKEN";
const R23D49_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D49_STAGE";
const R23D49_CELL_ENV: &str = "SPORESPORE_QSDK_R23D49_CELL";
const R23D49_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D49_ENGINE";
const R23D49_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D49_ATTEMPT_ROOT";
const R23D49_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D49_AUTHORITY_REPO_ROOT";
const R23D49_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D49_PYTHON";
const R23D49_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D49_POWERSHELL";

const R23D50_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d50_rapier_cas_path_identity_replay_implementation_v1.json";
const R23D50_CLOSURE_PATH: &str =
    "sdk/turning/r23d50_rapier_cas_path_identity_replay_closure_v1.json";
const R23D50_CAMPAIGN_ID: &str = "QSDK-R23D50-RAPIER-CAS-PATH-IDENTITY-REPLAY";
const R23D50_GATE_ID: &str = "QSDK-R23D50";
const R23D50_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d50_engine_cell_report_v1";
const R23D50_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d50_worker_failure_v1";
const R23D50_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d50_turning_trace_row_v1";
const R23D50_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d50_trace_retention_v1";
const R23D50_TRACE_RETENTION_MARKER: &str = "QSDK_R23D50_TRACE_RETENTION ";
const R23D50_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d50_physical_freeze_v1";
const R23D50_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d50_attempt_v1";
pub(crate) const R23D50_STAGE_ID: &str = "rapier_r49_cas_path_identity_replay";
const R23D50_CANDIDATE_ID: &str = "r23d29_support_loss_conditioned_turning_validation";
const R23D50_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D50_FREEZE";
const R23D50_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D50_ATTEMPT";
const R23D50_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D50_TOKEN";
const R23D50_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D50_STAGE";
const R23D50_CELL_ENV: &str = "SPORESPORE_QSDK_R23D50_CELL";
const R23D50_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D50_ENGINE";
const R23D50_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D50_ATTEMPT_ROOT";
const R23D50_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D50_AUTHORITY_REPO_ROOT";
const R23D50_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D50_PYTHON";
const R23D50_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D50_POWERSHELL";

const R23D62_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d62_selected_profile_three_engine_turning_validation_preregistration_v1.json"
);
const R23D62_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json";
const R23D62_CLOSURE_PATH: &str =
    "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_closure_v1.json";
const R23D62_CAMPAIGN_ID: &str =
    "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
const R23D62_GATE_ID: &str = "QSDK-R23D62";
const R23D62_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d62_engine_cell_report_v1";
const R23D62_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d62_worker_failure_v1";
const R23D62_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d62_turning_trace_row_v1";
const R23D62_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d62_trace_retention_v1";
const R23D62_TRACE_RETENTION_MARKER: &str = "QSDK_R23D62_TRACE_RETAINED ";
const R23D62_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d62_physical_freeze_v1";
const R23D62_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d62_attempt_v1";
pub(crate) const R23D62_STAGE_ID: &str = "selected_profile_matched_three_engine_turning_validation";
const R23D62_CANDIDATE_ID: &str = "selected_profile";
const R23D62_CAMPAIGN_SEED: u64 = 23_167;
const R23D62_TASK_ORIGIN_POLICY_ID: &str = "warmup_preserving_command_onset_origin_reanchor_v1";
const R23D62_HOST_MAPPING_ID: &str = "sporespore_rapier_force_based_outer_impulse_cap_mapping_v1";
const R23D62_HOST_MAPPING_PYTHON_CANONICAL_SHA256: &str =
    "sha256:7dcdd7b19b3a88351e94b9753b9c2a9c3f7ebed2de08a192bd59f88bd09aef7b";
const R23D62_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d62_full_precision_native_trace_transport_v1";
const R23D62_ACTUATOR_PHASE_OBSERVATION_SCHEMA: &str =
    "sporespore_godot_jolt_actuator_phase_observation_v1";
const R23D62_APPLICATION_RECEIPT_SCHEMA: &str =
    "sporespore_godot_jolt_full_authority_application_receipt_v1";
const R23D62_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D62_FREEZE";
const R23D62_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D62_ATTEMPT";
const R23D62_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D62_TOKEN";
const R23D62_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D62_STAGE";
const R23D62_CELL_ENV: &str = "SPORESPORE_QSDK_R23D62_CELL";
const R23D62_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D62_ENGINE";
const R23D62_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D62_ATTEMPT_ROOT";
const R23D62_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D62_AUTHORITY_REPO_ROOT";
const R23D62_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D62_PYTHON";
const R23D62_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D62_POWERSHELL";
const R23D62_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_101_514_473_499_264_57,
    yaw_rad: 0.006_582_133_937_627_077,
    linear_velocity_world_m_s: [-0.001_543_798_949_569_463_7, 0.0, -0.001_072_383_951_395_75],
    torso_angular_velocity_world_rad_s: [
        0.001_727_872_760_966_420_2,
        0.003_018_336_370_587_349,
        -0.000_743_836_630_135_774_6,
    ],
    gait_phase_offset_ticks: 2,
};

const R23D63_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d63_selected_profile_three_engine_turning_validation_preregistration_v1.json"
);
const R23D63_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_implementation_v1.json";
const R23D63_CLOSURE_PATH: &str =
    "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json";
const R23D63_CAMPAIGN_ID: &str =
    "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
const R23D63_GATE_ID: &str = "QSDK-R23D63";
const R23D63_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d63_engine_cell_report_v1";
const R23D63_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d63_worker_failure_v1";
const R23D63_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d63_turning_trace_row_v1";
const R23D63_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d63_trace_retention_v1";
const R23D63_TRACE_RETENTION_MARKER: &str = "QSDK_R23D63_TRACE_RETAINED ";
const R23D63_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d63_physical_freeze_v1";
const R23D63_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d63_attempt_v1";
pub(crate) const R23D63_STAGE_ID: &str =
    "receipt_schema_repaired_selected_profile_matched_three_engine_turning_validation";
const R23D63_CANDIDATE_ID: &str = "selected_profile";
const R23D63_CAMPAIGN_SEED: u64 = 23_169;
const R23D63_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d63_full_precision_native_trace_transport_v1";
const R23D63_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D63_FREEZE";
const R23D63_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D63_ATTEMPT";
const R23D63_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D63_TOKEN";
const R23D63_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D63_STAGE";
const R23D63_CELL_ENV: &str = "SPORESPORE_QSDK_R23D63_CELL";
const R23D63_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D63_ENGINE";
const R23D63_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D63_ATTEMPT_ROOT";
const R23D63_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D63_AUTHORITY_REPO_ROOT";
const R23D63_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D63_PYTHON";
const R23D63_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D63_POWERSHELL";
const R23D63_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_079_321_522_207_465_02,
    yaw_rad: 0.002_175_381_872_802_973,
    linear_velocity_world_m_s: [0.002_873_786_259_442_568, 0.0, -0.003_608_073_107_898_235_3],
    torso_angular_velocity_world_rad_s: [
        -0.000_146_493_199_281_394_48,
        0.002_177_086_193_114_519,
        0.001_765_456_981_956_958_8,
    ],
    gait_phase_offset_ticks: 1,
};

const R23D64_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d64_selected_profile_three_engine_turning_validation_preregistration_v1.json"
);
const R23D64_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_implementation_v1.json";
const R23D64_CLOSURE_PATH: &str =
    "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_closure_v1.json";
const R23D64_CAMPAIGN_ID: &str = "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
const R23D64_GATE_ID: &str = "QSDK-R23D64";
const R23D64_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d64_engine_cell_report_v1";
const R23D64_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d64_worker_failure_v1";
const R23D64_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d64_turning_trace_row_v1";
const R23D64_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d64_trace_retention_v1";
const R23D64_TRACE_RETENTION_MARKER: &str = "QSDK_R23D64_TRACE_RETAINED ";
const R23D64_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d64_physical_freeze_v1";
const R23D64_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d64_attempt_v1";
pub(crate) const R23D64_STAGE_ID: &str =
    "rapier_launch_contract_repaired_selected_profile_matched_three_engine_turning_validation";
const R23D64_CANDIDATE_ID: &str = "selected_profile";
const R23D64_CAMPAIGN_SEED: u64 = 23_171;
const R23D64_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d64_full_precision_native_trace_transport_v1";
const R23D64_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D64_FREEZE";
const R23D64_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D64_ATTEMPT";
const R23D64_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D64_TOKEN";
const R23D64_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D64_STAGE";
const R23D64_CELL_ENV: &str = "SPORESPORE_QSDK_R23D64_CELL";
const R23D64_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D64_ENGINE";
const R23D64_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D64_ATTEMPT_ROOT";
const R23D64_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D64_AUTHORITY_REPO_ROOT";
const R23D64_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D64_PYTHON";
const R23D64_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D64_POWERSHELL";
const R23D64_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_199_877_074_919_641_02,
    yaw_rad: -0.000_288_112_089_037_895_2,
    linear_velocity_world_m_s: [
        -0.000_804_933_486_506_342_9,
        0.0,
        -0.001_213_713_083_416_223_5,
    ],
    torso_angular_velocity_world_rad_s: [
        0.001_966_250_361_874_699_6,
        0.001_407_362_520_694_732_7,
        0.000_979_003_030_806_779_9,
    ],
    gait_phase_offset_ticks: -2,
};

const R23D65_PREREGISTRATION_RAW: &str = include_str!(
    "../../../../turning/r23d65_selected_profile_three_engine_turning_validation_preregistration_v1.json"
);
const R23D65_IMPLEMENTATION_PATH: &str =
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_implementation_v1.json";
const R23D65_CLOSURE_PATH: &str =
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json";
const R23D65_CAMPAIGN_ID: &str = "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION";
const R23D65_GATE_ID: &str = "QSDK-R23D65";
const R23D65_REPORT_SCHEMA: &str = "sporespore_qsdk_r23d65_engine_cell_report_v1";
const R23D65_FAILURE_SCHEMA: &str = "sporespore_qsdk_r23d65_worker_failure_v1";
const R23D65_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d65_turning_trace_row_v1";
const R23D65_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d65_trace_retention_v1";
const R23D65_TRACE_RETENTION_MARKER: &str = "QSDK_R23D65_TRACE_RETAINED ";
const R23D65_FREEZE_SCHEMA: &str = "sporespore_qsdk_r23d65_physical_freeze_v1";
const R23D65_ATTEMPT_SCHEMA: &str = "sporespore_qsdk_r23d65_attempt_v1";
pub(crate) const R23D65_STAGE_ID: &str =
    "runtime_integration_repaired_selected_profile_matched_three_engine_turning_validation";
const R23D65_CANDIDATE_ID: &str = "selected_profile";
const R23D65_CAMPAIGN_SEED: u64 = 23_175;
const R23D65_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d65_full_precision_native_trace_transport_v1";
const R23D65_FREEZE_PATH_ENV: &str = "SPORESPORE_QSDK_R23D65_FREEZE";
const R23D65_ATTEMPT_PATH_ENV: &str = "SPORESPORE_QSDK_R23D65_ATTEMPT";
const R23D65_TOKEN_ENV: &str = "SPORESPORE_QSDK_R23D65_TOKEN";
const R23D65_STAGE_ENV: &str = "SPORESPORE_QSDK_R23D65_STAGE";
const R23D65_CELL_ENV: &str = "SPORESPORE_QSDK_R23D65_CELL";
const R23D65_ENGINE_ENV: &str = "SPORESPORE_QSDK_R23D65_ENGINE";
const R23D65_ATTEMPT_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D65_ATTEMPT_ROOT";
const R23D65_AUTHORITY_REPO_ROOT_ENV: &str = "SPORESPORE_QSDK_R23D65_AUTHORITY_REPO_ROOT";
const R23D65_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D65_PYTHON";
const R23D65_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D65_POWERSHELL";
const R23D65_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_313_575_379_550_457,
    yaw_rad: 0.006_558_361_928_910_017,
    linear_velocity_world_m_s: [0.003_878_579_940_646_887, 0.0, -0.001_923_750_387_504_696_8],
    torso_angular_velocity_world_rad_s: [
        0.000_102_321_617_305_278_78,
        0.003_464_266_192_167_997_4,
        -0.001_478_442_223_742_604_3,
    ],
    gait_phase_offset_ticks: 3,
};

pub const R23D66_CAMPAIGN_ID: &str =
    "QSDK-R23D66-PRODUCTION-ROUTE-QUALIFIED-SELECTED-PROFILE-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D66_GATE_ID: &str = "QSDK-R23D66";
pub const R23D66_STAGE_ID: &str =
    "production_route_qualified_selected_profile_three_engine_turning_validation";
pub const R23D66_CAMPAIGN_SEED: u64 = 23_179;
pub(crate) const R23D66_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D66_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d66_turning_trace_row_v1";
pub(crate) const R23D66_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d66_trace_retention_v1";
pub(crate) const R23D66_TRACE_RETENTION_MARKER: &str = "QSDK_R23D66_TRACE_RETAINED ";
pub(crate) const R23D66_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d66_full_precision_native_trace_transport_v1";
pub(crate) const R23D66_EVALUATOR_PATH: &str =
    "sdk/turning/r23d66_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D66_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D66_AUTHORITY_REPO_ROOT";
pub(crate) const R23D66_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D66_PYTHON";
pub(crate) const R23D66_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D66_POWERSHELL";
const R23D66_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_709_165_120_497_345_9,
    yaw_rad: -0.005_476_593_039_929_867,
    linear_velocity_world_m_s: [
        0.000_077_179_167_419_672_01,
        0.0,
        -0.002_451_487_351_208_925_2,
    ],
    torso_angular_velocity_world_rad_s: [
        -0.000_389_243_825_338_780_9,
        -0.002_560_383_873_060_345_6,
        0.001_447_041_286_155_581_5,
    ],
    gait_phase_offset_ticks: -2,
};

pub const R23D67_CAMPAIGN_ID: &str =
    "QSDK-R23D67-AUTHORIZATION-SCHEMA-REPAIRED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D67_GATE_ID: &str = "QSDK-R23D67";
pub const R23D67_STAGE_ID: &str = "authorization_schema_repaired_three_engine_turning_validation";
pub const R23D67_CAMPAIGN_SEED: u64 = 23_181;
pub(crate) const R23D67_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D67_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d67_turning_trace_row_v1";
pub(crate) const R23D67_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d67_trace_retention_v1";
pub(crate) const R23D67_TRACE_RETENTION_MARKER: &str = "QSDK_R23D67_TRACE_RETAINED ";
pub(crate) const R23D67_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d67_full_precision_native_trace_transport_v1";
pub(crate) const R23D67_EVALUATOR_PATH: &str =
    "sdk/turning/r23d67_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D67_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D67_AUTHORITY_REPO_ROOT";
pub(crate) const R23D67_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D67_PYTHON";
pub(crate) const R23D67_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D67_POWERSHELL";
const R23D67_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_233_307_218_877_598_64,
    yaw_rad: -0.000_507_550_314_068_794_3,
    linear_velocity_world_m_s: [-0.003_907_699_137_926_102, 0.0, 0.000_441_535_841_673_612_6],
    torso_angular_velocity_world_rad_s: [
        0.001_256_550_429_388_880_7,
        0.002_035_621_553_659_439,
        0.000_437_956_536_188_721_66,
    ],
    gait_phase_offset_ticks: 3,
};

pub const R23D68_CAMPAIGN_ID: &str =
    "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D68_GATE_ID: &str = "QSDK-R23D68";
pub const R23D68_STAGE_ID: &str =
    "production_path_conformance_repaired_three_engine_turning_validation";
pub const R23D68_CAMPAIGN_SEED: u64 = 23_185;
pub(crate) const R23D68_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D68_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d68_turning_trace_row_v1";
pub(crate) const R23D68_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d68_trace_retention_v1";
pub(crate) const R23D68_TRACE_RETENTION_MARKER: &str = "QSDK_R23D68_TRACE_RETAINED ";
pub(crate) const R23D68_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d68_full_precision_native_trace_transport_v1";
pub(crate) const R23D68_EVALUATOR_PATH: &str =
    "sdk/turning/r23d68_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D68_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D68_AUTHORITY_REPO_ROOT";
pub(crate) const R23D68_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D68_PYTHON";
pub(crate) const R23D68_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D68_POWERSHELL";
const R23D68_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_893_494_870_979_338_9,
    yaw_rad: 0.000_820_848_625_153_303_1,
    linear_velocity_world_m_s: [
        -0.000_230_720_965_191_721_92,
        0.0,
        0.001_137_608_196_586_370_5,
    ],
    torso_angular_velocity_world_rad_s: [
        0.000_775_061_082_094_907_8,
        0.001_772_123_854_607_343_7,
        0.000_136_278_569_698_333_74,
    ],
    gait_phase_offset_ticks: 0,
};

pub const R23D69_CAMPAIGN_ID: &str =
    "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D69_GATE_ID: &str = "QSDK-R23D69";
pub const R23D69_STAGE_ID: &str =
    "complete_production_row_conformance_repaired_three_engine_turning_validation";
pub const R23D69_CAMPAIGN_SEED: u64 = 23_187;
pub(crate) const R23D69_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D69_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d69_turning_trace_row_v1";
pub(crate) const R23D69_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d69_trace_retention_v1";
pub(crate) const R23D69_TRACE_RETENTION_MARKER: &str = "QSDK_R23D69_TRACE_RETAINED ";
pub(crate) const R23D69_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d69_full_precision_native_trace_transport_v1";
const R23D69_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D69_EVALUATOR_PATH: &str =
    "sdk/turning/r23d69_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D69_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D69_AUTHORITY_REPO_ROOT";
pub(crate) const R23D69_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D69_PYTHON";
pub(crate) const R23D69_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D69_POWERSHELL";
const R23D69_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_108_158_397_779_334_34,
    yaw_rad: 0.005_546_426_866_203_546_5,
    linear_velocity_world_m_s: [
        0.002_818_681_765_347_719,
        0.0,
        -0.000_058_669_596_910_476_685,
    ],
    torso_angular_velocity_world_rad_s: [
        -0.000_020_042_527_467_012_405,
        -0.003_150_121_541_693_806_6,
        0.001_983_115_216_717_124,
    ],
    gait_phase_offset_ticks: 1,
};

pub const R23D70_CAMPAIGN_ID: &str =
    "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D70_GATE_ID: &str = "QSDK-R23D70";
pub const R23D70_STAGE_ID: &str =
    "trace_retention_receipt_contract_repaired_three_engine_turning_validation";
pub const R23D70_CAMPAIGN_SEED: u64 = 23_189;
pub(crate) const R23D70_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D70_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d70_turning_trace_row_v1";
pub(crate) const R23D70_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d70_trace_retention_v1";
pub(crate) const R23D70_TRACE_RETENTION_MARKER: &str = "QSDK_R23D70_TRACE_RETAINED ";
pub(crate) const R23D70_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d70_full_precision_native_trace_transport_v1";
const R23D70_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D70_EVALUATOR_PATH: &str =
    "sdk/turning/r23d70_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D70_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D70_AUTHORITY_REPO_ROOT";
pub(crate) const R23D70_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D70_PYTHON";
pub(crate) const R23D70_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D70_POWERSHELL";
const R23D70_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_554_921_803_995_966_9,
    yaw_rad: 0.000_620_645_936_578_512_2,
    linear_velocity_world_m_s: [
        -0.001_825_063_489_377_498_6,
        0.0,
        0.000_385_833_904_147_148_13,
    ],
    torso_angular_velocity_world_rad_s: [
        0.000_403_618_207_201_361_66,
        0.001_313_144_341_111_183_2,
        -0.000_127_993_989_735_841_75,
    ],
    gait_phase_offset_ticks: 3,
};

pub const R23D71_CAMPAIGN_ID: &str =
    "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-THREE-ENGINE-TURNING-VALIDATION";
pub const R23D71_GATE_ID: &str = "QSDK-R23D71";
pub const R23D71_STAGE_ID: &str =
    "success_terminal_projection_repaired_three_engine_turning_validation";
pub const R23D71_CAMPAIGN_SEED: u64 = 23_191;
pub(crate) const R23D71_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D71_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d71_turning_trace_row_v1";
pub(crate) const R23D71_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d71_trace_retention_v1";
pub(crate) const R23D71_TRACE_RETENTION_MARKER: &str = "QSDK_R23D71_TRACE_RETAINED ";
pub(crate) const R23D71_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d71_full_precision_native_trace_transport_v1";
const R23D71_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D71_EVALUATOR_PATH: &str =
    "sdk/turning/r23d71_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D71_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D71_AUTHORITY_REPO_ROOT";
pub(crate) const R23D71_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D71_PYTHON";
pub(crate) const R23D71_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D71_POWERSHELL";
const R23D71_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_260_413_275_100_290_8,
    yaw_rad: -0.004_926_238_209_009_170_5,
    linear_velocity_world_m_s: [0.002_370_542_846_620_083, 0.0, 0.003_711_124_416_440_725_3],
    torso_angular_velocity_world_rad_s: [
        -0.000_355_222_495_272_755_6,
        -0.002_212_324_179_708_957_7,
        0.000_080_247_642_472_386_36,
    ],
    gait_phase_offset_ticks: -1,
};

pub const R23D74_CAMPAIGN_ID: &str = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION";
pub const R23D74_GATE_ID: &str = "QSDK-R23D74";
pub const R23D74_STAGE_ID: &str = "fresh_finite_three_engine_turning_decision";
pub const R23D74_CAMPAIGN_SEED: u64 = 23_193;
pub(crate) const R23D74_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D74_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d74_turning_trace_row_v1";
pub(crate) const R23D74_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d74_trace_retention_v1";
pub(crate) const R23D74_TRACE_RETENTION_MARKER: &str = "QSDK_R23D74_TRACE_RETAINED ";
pub(crate) const R23D74_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d74_full_precision_native_trace_transport_v1";
const R23D74_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D74_EVALUATOR_PATH: &str =
    "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D74_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D74_AUTHORITY_REPO_ROOT";
pub(crate) const R23D74_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D74_PYTHON";
pub(crate) const R23D74_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D74_POWERSHELL";
const R23D74_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_044_139_225_792_605_43,
    yaw_rad: -0.003_177_209_757_268_429,
    linear_velocity_world_m_s: [
        -0.003_142_363_624_647_259_7,
        0.0,
        0.001_673_305_872_827_768_3,
    ],
    torso_angular_velocity_world_rad_s: [
        0.001_671_605_277_806_520_5,
        -0.000_620_645_936_578_512_2,
        0.000_921_537_866_815_924_6,
    ],
    gait_phase_offset_ticks: 0,
};

pub const R23D76_CAMPAIGN_ID: &str = "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION";
pub const R23D76_GATE_ID: &str = "QSDK-R23D76";
pub const R23D76_STAGE_ID: &str = "fresh_finite_three_engine_turning_decision";
pub const R23D76_CAMPAIGN_SEED: u64 = 23_197;
pub(crate) const R23D76_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D76_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d76_turning_trace_row_v1";
pub(crate) const R23D76_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d76_trace_retention_v1";
pub(crate) const R23D76_TRACE_RETENTION_MARKER: &str = "QSDK_R23D76_TRACE_RETAINED ";
pub(crate) const R23D76_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d76_full_precision_native_trace_transport_v1";
const R23D76_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D76_EVALUATOR_PATH: &str =
    "sdk/turning/r23d76_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D76_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D76_AUTHORITY_REPO_ROOT";
pub(crate) const R23D76_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D76_PYTHON";
pub(crate) const R23D76_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D76_POWERSHELL";
const R23D76_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_804_827_199_317_514_9,
    yaw_rad: 0.006_968_908_477_574_587,
    linear_velocity_world_m_s: [
        0.001_113_993_581_384_420_4,
        0.0,
        0.000_995_726_324_617_862_7,
    ],
    torso_angular_velocity_world_rad_s: [
        0.001_996_839_651_837_945,
        0.001_567_048_020_660_877_2,
        0.001_006_490_318_104_624_7,
    ],
    gait_phase_offset_ticks: -3,
};

pub const R23D78_CAMPAIGN_ID: &str = "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION";
pub const R23D78_GATE_ID: &str = "QSDK-R23D78";
pub const R23D78_STAGE_ID: &str = "fresh_finite_three_engine_turning_decision";
pub const R23D78_CAMPAIGN_SEED: u64 = 23_199;
pub(crate) const R23D78_ENGINE_ID: &str = "rapier_parry";
pub(crate) const R23D78_TRACE_ROW_SCHEMA: &str = "sporespore_qsdk_r23d78_turning_trace_row_v1";
pub(crate) const R23D78_TRACE_RETENTION_SCHEMA: &str = "sporespore_qsdk_r23d78_trace_retention_v1";
pub(crate) const R23D78_TRACE_RETENTION_MARKER: &str = "QSDK_R23D78_TRACE_RETAINED ";
pub(crate) const R23D78_TRACE_TRANSPORT_ID: &str =
    "sporespore_r23d78_full_precision_native_trace_transport_v1";
const R23D78_RECOVERY_END_STEP_EXCLUSIVE: u64 = 2_400;
pub(crate) const R23D78_EVALUATOR_PATH: &str =
    "sdk/turning/r23d78_production_route_three_engine_turning_evaluator.py";
pub(crate) const R23D78_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_QSDK_R23D78_AUTHORITY_REPO_ROOT";
pub(crate) const R23D78_PYTHON_ENV: &str = "SPORESPORE_QSDK_R23D78_PYTHON";
pub(crate) const R23D78_POWERSHELL_ENV: &str = "SPORESPORE_QSDK_R23D78_POWERSHELL";
const R23D78_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_679_127_580_951_899_3,
    yaw_rad: -0.002_407_998_312_264_681,
    linear_velocity_world_m_s: [-0.003_193_350_043_147_802_4, 0.0, 0.002_137_005_329_132_08],
    torso_angular_velocity_world_rad_s: [
        0.001_658_749_766_647_815_7,
        0.002_840_237_691_998_481_8,
        -0.001_745_306_886_732_578_3,
    ],
    gait_phase_offset_ticks: 3,
};

pub(crate) const TURNING_ROUTE_ID: &str =
    "sporespore_three_engine_turning_success_transport_route_v2";
pub(crate) const TURNING_ROUTE_STAGE_ID: &str = "turning_3e_success_transport_development_ghost";
pub(crate) const TURNING_ROUTE_CELL_ID: &str =
    "turning_success_transport_v2__rapier_parry__s21516__positive_heading";
pub(crate) const TURNING_ROUTE_ENGINE_ID: &str = "rapier_parry";
pub(crate) const TURNING_ROUTE_CAMPAIGN_SEED: u64 = 21_516;
pub(crate) const TURNING_ROUTE_CONTROLLER_STEPS: u64 = 2;
pub(crate) const TURNING_ROUTE_TERMINAL_STEPS: u64 = 0;
pub(crate) const TURNING_ROUTE_TRACE_ROW_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_trace_row_v2";
pub(crate) const TURNING_ROUTE_TRACE_RETENTION_SCHEMA: &str =
    "sporespore_three_engine_turning_success_transport_trace_retention_v2";
pub(crate) const TURNING_ROUTE_TRACE_RETENTION_MARKER: &str =
    "SPORESPORE_TURNING_ROUTE_TRACE_RETAINED ";
pub(crate) const TURNING_ROUTE_EVALUATOR_PATH: &str =
    "sdk/turning/three_engine_turning_route_evaluator.py";
pub(crate) const TURNING_ROUTE_AUTHORITY_REPO_ROOT_ENV: &str =
    "SPORESPORE_TURNING_ROUTE_AUTHORITY_REPO_ROOT";
pub(crate) const TURNING_ROUTE_PYTHON_ENV: &str = "SPORESPORE_TURNING_ROUTE_PYTHON";
pub(crate) const TURNING_ROUTE_POWERSHELL_ENV: &str = "SPORESPORE_TURNING_ROUTE_POWERSHELL";
const TURNING_ROUTE_SCHEDULE_SEMANTIC_OFFSET: u64 = TURN_START_STEP;
const TURNING_ROUTE_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_829_280_004_836_618_9,
    yaw_rad: -0.003_193_265_292_793_512_3,
    linear_velocity_world_m_s: [
        0.003_093_475_010_246_038_4,
        0.0,
        -0.000_766_574_172_303_080_6,
    ],
    torso_angular_velocity_world_rad_s: [
        -0.000_751_252_751_797_437_7,
        0.001_039_189_752_191_305_2,
        0.001_042_153_453_454_375_3,
    ],
    gait_phase_offset_ticks: 0,
};

#[derive(Debug)]
struct R23D27CampaignContract {
    preregistration_raw: &'static str,
    preregistration_schema: &'static str,
    implementation_path: &'static str,
    implementation_schema: &'static str,
    closure_path: &'static str,
    campaign_id: &'static str,
    gate_id: &'static str,
    report_schema: &'static str,
    failure_schema: &'static str,
    trace_row_schema: &'static str,
    trace_retention_schema: &'static str,
    trace_retention_marker: &'static str,
    freeze_schema: &'static str,
    attempt_schema: &'static str,
    stage_id: &'static str,
    candidate_id: &'static str,
    controller_policy_id: &'static str,
    guard_mode_id: &'static str,
    study_classification: &'static str,
    behavior_change_count: usize,
    parent_policy_id: &'static str,
    predictive: bool,
    floor_hold_steps: Option<u64>,
    selected_candidate_is_validation: bool,
    freeze_path_env: &'static str,
    attempt_path_env: &'static str,
    token_env: &'static str,
    stage_env: &'static str,
    cell_env: &'static str,
    engine_env: &'static str,
    attempt_root_env: &'static str,
    authority_repo_root_env: &'static str,
    python_env: &'static str,
    powershell_env: &'static str,
    evaluator_path: &'static str,
    trace_retain_source_root_argument_required: bool,
    preflight_schema: &'static str,
    authorization_preflight_schema: &'static str,
    campaign_seed: u64,
    prospective_initial_perturbation: Option<InitialPerturbation>,
    startup_velocity_ramp: bool,
    support_loss_conditioned_startup: bool,
}

const R23D27_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D27_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d27_stability_guarded_steering_preregistration_v1",
    implementation_path: R23D27_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d27_stability_guarded_steering_implementation_v1",
    closure_path: R23D27_CLOSURE_PATH,
    campaign_id: R23D27_CAMPAIGN_ID,
    gate_id: R23D27_GATE_ID,
    report_schema: R23D27_REPORT_SCHEMA,
    failure_schema: R23D27_FAILURE_SCHEMA,
    trace_row_schema: R23D27_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D27_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D27_TRACE_RETENTION_MARKER,
    freeze_schema: R23D27_FREEZE_SCHEMA,
    attempt_schema: R23D27_ATTEMPT_SCHEMA,
    stage_id: R23D27_STAGE_ID,
    candidate_id: "stability_guarded_0p20_to_0p28",
    controller_policy_id: BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_candidate_validation",
    behavior_change_count: 6,
    parent_policy_id: BALANCED_WAVE_R23D26_STEERING_CAP_0P20_POLICY_ID,
    predictive: false,
    floor_hold_steps: None,
    selected_candidate_is_validation: true,
    freeze_path_env: R23D27_FREEZE_PATH_ENV,
    attempt_path_env: R23D27_ATTEMPT_PATH_ENV,
    token_env: R23D27_TOKEN_ENV,
    stage_env: R23D27_STAGE_ENV,
    cell_env: R23D27_CELL_ENV,
    engine_env: R23D27_ENGINE_ENV,
    attempt_root_env: R23D27_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D27_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D27_PYTHON_ENV,
    powershell_env: R23D27_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d27_stability_guarded_steering_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d27_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d27_rapier_production_authorization_preflight_v1",
    campaign_seed: CAMPAIGN_SEED,
    prospective_initial_perturbation: None,
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D28_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D28_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d28_predictive_stability_guarded_steering_preregistration_v1",
    implementation_path: R23D28_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d28_predictive_stability_guarded_steering_implementation_v1",
    closure_path: R23D28_CLOSURE_PATH,
    campaign_id: R23D28_CAMPAIGN_ID,
    gate_id: R23D28_GATE_ID,
    report_schema: R23D28_REPORT_SCHEMA,
    failure_schema: R23D28_FAILURE_SCHEMA,
    trace_row_schema: R23D28_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D28_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D28_TRACE_RETENTION_MARKER,
    freeze_schema: R23D28_FREEZE_SCHEMA,
    attempt_schema: R23D28_ATTEMPT_SCHEMA,
    stage_id: R23D28_STAGE_ID,
    candidate_id: R23D28_CANDIDATE_ID,
    controller_policy_id: BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_controller_development",
    behavior_change_count: 4,
    parent_policy_id: BALANCED_WAVE_R23D27_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: None,
    selected_candidate_is_validation: false,
    freeze_path_env: R23D28_FREEZE_PATH_ENV,
    attempt_path_env: R23D28_ATTEMPT_PATH_ENV,
    token_env: R23D28_TOKEN_ENV,
    stage_env: R23D28_STAGE_ENV,
    cell_env: R23D28_CELL_ENV,
    engine_env: R23D28_ENGINE_ENV,
    attempt_root_env: R23D28_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D28_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D28_PYTHON_ENV,
    powershell_env: R23D28_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d28_predictive_stability_guarded_steering_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d28_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d28_rapier_production_authorization_preflight_v1",
    campaign_seed: CAMPAIGN_SEED,
    prospective_initial_perturbation: None,
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D29_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D29_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d29_two_swing_persistent_predictive_stability_guarded_steering_preregistration_v1",
    implementation_path: R23D29_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d29_two_swing_persistent_predictive_stability_guarded_steering_implementation_v1",
    closure_path: R23D29_CLOSURE_PATH,
    campaign_id: R23D29_CAMPAIGN_ID,
    gate_id: R23D29_GATE_ID,
    report_schema: R23D29_REPORT_SCHEMA,
    failure_schema: R23D29_FAILURE_SCHEMA,
    trace_row_schema: R23D29_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D29_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D29_TRACE_RETENTION_MARKER,
    freeze_schema: R23D29_FREEZE_SCHEMA,
    attempt_schema: R23D29_ATTEMPT_SCHEMA,
    stage_id: R23D29_STAGE_ID,
    candidate_id: R23D29_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_controller_development",
    behavior_change_count: 4,
    parent_policy_id: BALANCED_WAVE_R23D28_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D29_FREEZE_PATH_ENV,
    attempt_path_env: R23D29_ATTEMPT_PATH_ENV,
    token_env: R23D29_TOKEN_ENV,
    stage_env: R23D29_STAGE_ENV,
    cell_env: R23D29_CELL_ENV,
    engine_env: R23D29_ENGINE_ENV,
    attempt_root_env: R23D29_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D29_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D29_PYTHON_ENV,
    powershell_env: R23D29_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d29_two_swing_persistent_predictive_stability_guarded_steering_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d29_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d29_rapier_production_authorization_preflight_v1",
    campaign_seed: CAMPAIGN_SEED,
    prospective_initial_perturbation: None,
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D30_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D30_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d30_cycle_coherent_directional_response_preregistration_v1",
    implementation_path: R23D30_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d30_cycle_coherent_directional_response_implementation_v1",
    closure_path: R23D30_CLOSURE_PATH,
    campaign_id: R23D30_CAMPAIGN_ID,
    gate_id: R23D30_GATE_ID,
    report_schema: R23D30_REPORT_SCHEMA,
    failure_schema: R23D30_FAILURE_SCHEMA,
    trace_row_schema: R23D30_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D30_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D30_TRACE_RETENTION_MARKER,
    freeze_schema: R23D30_FREEZE_SCHEMA,
    attempt_schema: R23D30_ATTEMPT_SCHEMA,
    stage_id: R23D30_STAGE_ID,
    candidate_id: R23D30_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_measurement_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D30_FREEZE_PATH_ENV,
    attempt_path_env: R23D30_ATTEMPT_PATH_ENV,
    token_env: R23D30_TOKEN_ENV,
    stage_env: R23D30_STAGE_ENV,
    cell_env: R23D30_CELL_ENV,
    engine_env: R23D30_ENGINE_ENV,
    attempt_root_env: R23D30_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D30_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D30_PYTHON_ENV,
    powershell_env: R23D30_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d30_cycle_coherent_directional_response_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d30_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d30_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D30_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D30_INITIAL_PERTURBATION),
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D31_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D31_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d31_cycle_integrated_directional_response_preregistration_v1",
    implementation_path: R23D31_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d31_cycle_integrated_directional_response_implementation_v1",
    closure_path: R23D31_CLOSURE_PATH,
    campaign_id: R23D31_CAMPAIGN_ID,
    gate_id: R23D31_GATE_ID,
    report_schema: R23D31_REPORT_SCHEMA,
    failure_schema: R23D31_FAILURE_SCHEMA,
    trace_row_schema: R23D31_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D31_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D31_TRACE_RETENTION_MARKER,
    freeze_schema: R23D31_FREEZE_SCHEMA,
    attempt_schema: R23D31_ATTEMPT_SCHEMA,
    stage_id: R23D31_STAGE_ID,
    candidate_id: R23D31_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_measurement_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D31_FREEZE_PATH_ENV,
    attempt_path_env: R23D31_ATTEMPT_PATH_ENV,
    token_env: R23D31_TOKEN_ENV,
    stage_env: R23D31_STAGE_ENV,
    cell_env: R23D31_CELL_ENV,
    engine_env: R23D31_ENGINE_ENV,
    attempt_root_env: R23D31_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D31_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D31_PYTHON_ENV,
    powershell_env: R23D31_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d31_cycle_integrated_directional_response_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d31_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d31_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D31_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D31_INITIAL_PERTURBATION),
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D32_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D32_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d32_finite_rapier_turning_replication_preregistration_v1",
    implementation_path: R23D32_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d32_finite_rapier_turning_replication_implementation_v1",
    closure_path: R23D32_CLOSURE_PATH,
    campaign_id: R23D32_CAMPAIGN_ID,
    gate_id: R23D32_GATE_ID,
    report_schema: R23D32_REPORT_SCHEMA,
    failure_schema: R23D32_FAILURE_SCHEMA,
    trace_row_schema: R23D32_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D32_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D32_TRACE_RETENTION_MARKER,
    freeze_schema: R23D32_FREEZE_SCHEMA,
    attempt_schema: R23D32_ATTEMPT_SCHEMA,
    stage_id: R23D32_STAGE_ID,
    candidate_id: R23D32_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_turning_replication_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D32_FREEZE_PATH_ENV,
    attempt_path_env: R23D32_ATTEMPT_PATH_ENV,
    token_env: R23D32_TOKEN_ENV,
    stage_env: R23D32_STAGE_ENV,
    cell_env: R23D32_CELL_ENV,
    engine_env: R23D32_ENGINE_ENV,
    attempt_root_env: R23D32_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D32_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D32_PYTHON_ENV,
    powershell_env: R23D32_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d32_finite_rapier_turning_replication_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d32_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d32_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D32_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D32_INITIAL_PERTURBATION),
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D40_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D40_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d40_three_engine_startup_ramp_turning_preregistration_v1",
    implementation_path: R23D40_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d40_three_engine_startup_ramp_turning_implementation_v1",
    closure_path: R23D40_CLOSURE_PATH,
    campaign_id: R23D40_CAMPAIGN_ID,
    gate_id: R23D40_GATE_ID,
    report_schema: R23D40_REPORT_SCHEMA,
    failure_schema: R23D40_FAILURE_SCHEMA,
    trace_row_schema: R23D40_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D40_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D40_TRACE_RETENTION_MARKER,
    freeze_schema: R23D40_FREEZE_SCHEMA,
    attempt_schema: R23D40_ATTEMPT_SCHEMA,
    stage_id: R23D40_STAGE_ID,
    candidate_id: R23D40_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_finite_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D40_FREEZE_PATH_ENV,
    attempt_path_env: R23D40_ATTEMPT_PATH_ENV,
    token_env: R23D40_TOKEN_ENV,
    stage_env: R23D40_STAGE_ENV,
    cell_env: R23D40_CELL_ENV,
    engine_env: R23D40_ENGINE_ENV,
    attempt_root_env: R23D40_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D40_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D40_PYTHON_ENV,
    powershell_env: R23D40_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d40_three_engine_startup_ramp_turning_evaluator.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d40_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d40_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D40_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D40_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: false,
};

const R23D41_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D41_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d41_three_engine_startup_ramp_turning_preregistration_v1",
    implementation_path: R23D41_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d41_three_engine_startup_ramp_turning_implementation_v1",
    closure_path: R23D41_CLOSURE_PATH,
    campaign_id: R23D41_CAMPAIGN_ID,
    gate_id: R23D41_GATE_ID,
    report_schema: R23D41_REPORT_SCHEMA,
    failure_schema: R23D41_FAILURE_SCHEMA,
    trace_row_schema: R23D41_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D41_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D41_TRACE_RETENTION_MARKER,
    freeze_schema: R23D41_FREEZE_SCHEMA,
    attempt_schema: R23D41_ATTEMPT_SCHEMA,
    stage_id: R23D41_STAGE_ID,
    candidate_id: R23D41_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_finite_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D41_FREEZE_PATH_ENV,
    attempt_path_env: R23D41_ATTEMPT_PATH_ENV,
    token_env: R23D41_TOKEN_ENV,
    stage_env: R23D41_STAGE_ENV,
    cell_env: R23D41_CELL_ENV,
    engine_env: R23D41_ENGINE_ENV,
    attempt_root_env: R23D41_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D41_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D41_PYTHON_ENV,
    powershell_env: R23D41_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d41_three_engine_startup_ramp_turning_evaluator.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d41_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d41_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D41_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D41_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: false,
};

const R23D42_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D42_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d42_three_engine_startup_ramp_turning_preregistration_v1",
    implementation_path: R23D42_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d42_three_engine_startup_ramp_turning_implementation_v1",
    closure_path: R23D42_CLOSURE_PATH,
    campaign_id: R23D42_CAMPAIGN_ID,
    gate_id: R23D42_GATE_ID,
    report_schema: R23D42_REPORT_SCHEMA,
    failure_schema: R23D42_FAILURE_SCHEMA,
    trace_row_schema: R23D42_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D42_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D42_TRACE_RETENTION_MARKER,
    freeze_schema: R23D42_FREEZE_SCHEMA,
    attempt_schema: R23D42_ATTEMPT_SCHEMA,
    stage_id: R23D42_STAGE_ID,
    candidate_id: R23D42_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_finite_fresh_three_engine_trace_interface_repair_successor_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D42_FREEZE_PATH_ENV,
    attempt_path_env: R23D42_ATTEMPT_PATH_ENV,
    token_env: R23D42_TOKEN_ENV,
    stage_env: R23D42_STAGE_ENV,
    cell_env: R23D42_CELL_ENV,
    engine_env: R23D42_ENGINE_ENV,
    attempt_root_env: R23D42_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D42_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D42_PYTHON_ENV,
    powershell_env: R23D42_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d42_three_engine_startup_ramp_turning_evaluator.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d42_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d42_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D42_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D42_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: false,
};

const R23D43_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D43_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d43_rapier_retention_hardened_turning_preregistration_v1",
    implementation_path: R23D43_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d43_rapier_retention_hardened_turning_implementation_v1",
    closure_path: R23D43_CLOSURE_PATH,
    campaign_id: R23D43_CAMPAIGN_ID,
    gate_id: R23D43_GATE_ID,
    report_schema: R23D43_REPORT_SCHEMA,
    failure_schema: R23D43_FAILURE_SCHEMA,
    trace_row_schema: R23D43_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D43_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D43_TRACE_RETENTION_MARKER,
    freeze_schema: R23D43_FREEZE_SCHEMA,
    attempt_schema: R23D43_ATTEMPT_SCHEMA,
    stage_id: R23D43_STAGE_ID,
    candidate_id: R23D43_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_finite_rapier_turning_replication_with_evidence_implementation_repair",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D43_FREEZE_PATH_ENV,
    attempt_path_env: R23D43_ATTEMPT_PATH_ENV,
    token_env: R23D43_TOKEN_ENV,
    stage_env: R23D43_STAGE_ENV,
    cell_env: R23D43_CELL_ENV,
    engine_env: R23D43_ENGINE_ENV,
    attempt_root_env: R23D43_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D43_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D43_PYTHON_ENV,
    powershell_env: R23D43_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d43_rapier_retention_hardened_turning_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d43_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d43_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D43_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D43_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: false,
};

const R23D44_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D44_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d44_rapier_paired_startup_transform_preregistration_v1",
    implementation_path: R23D44_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d44_rapier_paired_startup_transform_implementation_v1",
    closure_path: R23D44_CLOSURE_PATH,
    campaign_id: R23D44_CAMPAIGN_ID,
    gate_id: R23D44_GATE_ID,
    report_schema: R23D44_REPORT_SCHEMA,
    failure_schema: R23D44_FAILURE_SCHEMA,
    trace_row_schema: R23D44_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D44_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D44_TRACE_RETENTION_MARKER,
    freeze_schema: R23D44_FREEZE_SCHEMA,
    attempt_schema: R23D44_ATTEMPT_SCHEMA,
    stage_id: R23D44_STAGE_ID,
    candidate_id: R23D44_NO_RAMP_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_outcome_exposed_paired_same_seed_rapier_startup_transform_development",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D44_FREEZE_PATH_ENV,
    attempt_path_env: R23D44_ATTEMPT_PATH_ENV,
    token_env: R23D44_TOKEN_ENV,
    stage_env: R23D44_STAGE_ENV,
    cell_env: R23D44_CELL_ENV,
    engine_env: R23D44_ENGINE_ENV,
    attempt_root_env: R23D44_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D44_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D44_PYTHON_ENV,
    powershell_env: R23D44_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d44_rapier_paired_startup_transform_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d44_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d44_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D30_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D30_INITIAL_PERTURBATION),
    // R44 varies this per cell; false is only the campaign-level default.
    startup_velocity_ramp: false,
    support_loss_conditioned_startup: false,
};

const R23D48_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D48_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d48_support_loss_conditioned_three_engine_turning_preregistration_v1",
    implementation_path: R23D48_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d48_support_loss_conditioned_three_engine_turning_implementation_v1",
    closure_path: R23D48_CLOSURE_PATH,
    campaign_id: R23D48_CAMPAIGN_ID,
    gate_id: R23D48_GATE_ID,
    report_schema: R23D48_REPORT_SCHEMA,
    failure_schema: R23D48_FAILURE_SCHEMA,
    trace_row_schema: R23D48_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D48_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D48_TRACE_RETENTION_MARKER,
    freeze_schema: R23D48_FREEZE_SCHEMA,
    attempt_schema: R23D48_ATTEMPT_SCHEMA,
    stage_id: R23D48_STAGE_ID,
    candidate_id: R23D48_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_finite_fresh_three_engine_support_loss_conditioned_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D48_FREEZE_PATH_ENV,
    attempt_path_env: R23D48_ATTEMPT_PATH_ENV,
    token_env: R23D48_TOKEN_ENV,
    stage_env: R23D48_STAGE_ENV,
    cell_env: R23D48_CELL_ENV,
    engine_env: R23D48_ENGINE_ENV,
    attempt_root_env: R23D48_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D48_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D48_PYTHON_ENV,
    powershell_env: R23D48_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_evaluator.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d48_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d48_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D48_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D48_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D49_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D49_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d49_rapier_retention_repair_replay_preregistration_v1",
    implementation_path: R23D49_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d49_rapier_retention_repair_replay_implementation_v1",
    closure_path: R23D49_CLOSURE_PATH,
    campaign_id: R23D49_CAMPAIGN_ID,
    gate_id: R23D49_GATE_ID,
    report_schema: R23D49_REPORT_SCHEMA,
    failure_schema: R23D49_FAILURE_SCHEMA,
    trace_row_schema: R23D49_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D49_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D49_TRACE_RETENTION_MARKER,
    freeze_schema: R23D49_FREEZE_SCHEMA,
    attempt_schema: R23D49_ATTEMPT_SCHEMA,
    stage_id: R23D49_STAGE_ID,
    candidate_id: R23D49_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D49_FREEZE_PATH_ENV,
    attempt_path_env: R23D49_ATTEMPT_PATH_ENV,
    token_env: R23D49_TOKEN_ENV,
    stage_env: R23D49_STAGE_ENV,
    cell_env: R23D49_CELL_ENV,
    engine_env: R23D49_ENGINE_ENV,
    attempt_root_env: R23D49_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D49_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D49_PYTHON_ENV,
    powershell_env: R23D49_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d49_rapier_retention_repair_replay_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d49_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d49_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D48_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D48_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D50_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D50_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d50_rapier_cas_path_identity_replay_preregistration_v1",
    implementation_path: R23D50_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d50_rapier_cas_path_identity_replay_implementation_v1",
    closure_path: R23D50_CLOSURE_PATH,
    campaign_id: R23D50_CAMPAIGN_ID,
    gate_id: R23D50_GATE_ID,
    report_schema: R23D50_REPORT_SCHEMA,
    failure_schema: R23D50_FAILURE_SCHEMA,
    trace_row_schema: R23D50_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D50_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D50_TRACE_RETENTION_MARKER,
    freeze_schema: R23D50_FREEZE_SCHEMA,
    attempt_schema: R23D50_ATTEMPT_SCHEMA,
    stage_id: R23D50_STAGE_ID,
    candidate_id: R23D50_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "prospective_exact_outcome_exposed_rapier_evidence_implementation_repair_replay",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: false,
    freeze_path_env: R23D50_FREEZE_PATH_ENV,
    attempt_path_env: R23D50_ATTEMPT_PATH_ENV,
    token_env: R23D50_TOKEN_ENV,
    stage_env: R23D50_STAGE_ENV,
    cell_env: R23D50_CELL_ENV,
    engine_env: R23D50_ENGINE_ENV,
    attempt_root_env: R23D50_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D50_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D50_PYTHON_ENV,
    powershell_env: R23D50_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d50_rapier_cas_path_identity_replay_evaluator.py",
    trace_retain_source_root_argument_required: true,
    preflight_schema: "sporespore_qsdk_r23d50_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d50_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D48_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D48_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D62_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D62_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d62_selected_profile_three_engine_turning_validation_preregistration_v1",
    implementation_path: R23D62_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d62_selected_profile_three_engine_turning_validation_implementation_v1",
    closure_path: R23D62_CLOSURE_PATH,
    campaign_id: R23D62_CAMPAIGN_ID,
    gate_id: R23D62_GATE_ID,
    report_schema: R23D62_REPORT_SCHEMA,
    failure_schema: R23D62_FAILURE_SCHEMA,
    trace_row_schema: R23D62_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D62_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D62_TRACE_RETENTION_MARKER,
    freeze_schema: R23D62_FREEZE_SCHEMA,
    attempt_schema: R23D62_ATTEMPT_SCHEMA,
    stage_id: R23D62_STAGE_ID,
    candidate_id: R23D62_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "exact_single_held_out_deterministic_fixture_nine_cell_native_matched_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D62_FREEZE_PATH_ENV,
    attempt_path_env: R23D62_ATTEMPT_PATH_ENV,
    token_env: R23D62_TOKEN_ENV,
    stage_env: R23D62_STAGE_ENV,
    cell_env: R23D62_CELL_ENV,
    engine_env: R23D62_ENGINE_ENV,
    attempt_root_env: R23D62_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D62_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D62_PYTHON_ENV,
    powershell_env: R23D62_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d62_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d62_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D62_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D62_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D63_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D63_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d63_selected_profile_three_engine_turning_validation_preregistration_v1",
    implementation_path: R23D63_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d63_selected_profile_three_engine_turning_validation_implementation_v1",
    closure_path: R23D63_CLOSURE_PATH,
    campaign_id: R23D63_CAMPAIGN_ID,
    gate_id: R23D63_GATE_ID,
    report_schema: R23D63_REPORT_SCHEMA,
    failure_schema: R23D63_FAILURE_SCHEMA,
    trace_row_schema: R23D63_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D63_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D63_TRACE_RETENTION_MARKER,
    freeze_schema: R23D63_FREEZE_SCHEMA,
    attempt_schema: R23D63_ATTEMPT_SCHEMA,
    stage_id: R23D63_STAGE_ID,
    candidate_id: R23D63_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "exact_single_held_out_deterministic_fixture_nine_cell_native_matched_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D63_FREEZE_PATH_ENV,
    attempt_path_env: R23D63_ATTEMPT_PATH_ENV,
    token_env: R23D63_TOKEN_ENV,
    stage_env: R23D63_STAGE_ENV,
    cell_env: R23D63_CELL_ENV,
    engine_env: R23D63_ENGINE_ENV,
    attempt_root_env: R23D63_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D63_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D63_PYTHON_ENV,
    powershell_env: R23D63_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_evaluator_v2.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d63_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d63_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D63_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D63_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D64_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D64_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d64_selected_profile_three_engine_turning_validation_preregistration_v1",
    implementation_path: R23D64_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d64_selected_profile_three_engine_turning_validation_implementation_v1",
    closure_path: R23D64_CLOSURE_PATH,
    campaign_id: R23D64_CAMPAIGN_ID,
    gate_id: R23D64_GATE_ID,
    report_schema: R23D64_REPORT_SCHEMA,
    failure_schema: R23D64_FAILURE_SCHEMA,
    trace_row_schema: R23D64_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D64_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D64_TRACE_RETENTION_MARKER,
    freeze_schema: R23D64_FREEZE_SCHEMA,
    attempt_schema: R23D64_ATTEMPT_SCHEMA,
    stage_id: R23D64_STAGE_ID,
    candidate_id: R23D64_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "exact_single_held_out_deterministic_fixture_nine_cell_native_matched_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D64_FREEZE_PATH_ENV,
    attempt_path_env: R23D64_ATTEMPT_PATH_ENV,
    token_env: R23D64_TOKEN_ENV,
    stage_env: R23D64_STAGE_ENV,
    cell_env: R23D64_CELL_ENV,
    engine_env: R23D64_ENGINE_ENV,
    attempt_root_env: R23D64_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D64_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D64_PYTHON_ENV,
    powershell_env: R23D64_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_evaluator_v2.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d64_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d64_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D64_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D64_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

const R23D65_CAMPAIGN: R23D27CampaignContract = R23D27CampaignContract {
    preregistration_raw: R23D65_PREREGISTRATION_RAW,
    preregistration_schema: "sporespore_qsdk_r23d65_selected_profile_three_engine_turning_validation_preregistration_v1",
    implementation_path: R23D65_IMPLEMENTATION_PATH,
    implementation_schema: "sporespore_qsdk_r23d65_selected_profile_three_engine_turning_validation_implementation_v1",
    closure_path: R23D65_CLOSURE_PATH,
    campaign_id: R23D65_CAMPAIGN_ID,
    gate_id: R23D65_GATE_ID,
    report_schema: R23D65_REPORT_SCHEMA,
    failure_schema: R23D65_FAILURE_SCHEMA,
    trace_row_schema: R23D65_TRACE_ROW_SCHEMA,
    trace_retention_schema: R23D65_TRACE_RETENTION_SCHEMA,
    trace_retention_marker: R23D65_TRACE_RETENTION_MARKER,
    freeze_schema: R23D65_FREEZE_SCHEMA,
    attempt_schema: R23D65_ATTEMPT_SCHEMA,
    stage_id: R23D65_STAGE_ID,
    candidate_id: R23D65_CANDIDATE_ID,
    controller_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    guard_mode_id: PERSISTENT_PREDICTED_TILT_AND_CONTACT_STEERING_AUTHORITY_GUARD_MODE_ID,
    study_classification: "exact_single_held_out_deterministic_fixture_nine_cell_native_matched_three_engine_portable_turning_validation",
    behavior_change_count: 0,
    parent_policy_id:
        BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID,
    predictive: true,
    floor_hold_steps: Some(144),
    selected_candidate_is_validation: true,
    freeze_path_env: R23D65_FREEZE_PATH_ENV,
    attempt_path_env: R23D65_ATTEMPT_PATH_ENV,
    token_env: R23D65_TOKEN_ENV,
    stage_env: R23D65_STAGE_ENV,
    cell_env: R23D65_CELL_ENV,
    engine_env: R23D65_ENGINE_ENV,
    attempt_root_env: R23D65_ATTEMPT_ROOT_ENV,
    authority_repo_root_env: R23D65_AUTHORITY_REPO_ROOT_ENV,
    python_env: R23D65_PYTHON_ENV,
    powershell_env: R23D65_POWERSHELL_ENV,
    evaluator_path: "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py",
    trace_retain_source_root_argument_required: false,
    preflight_schema: "sporespore_qsdk_r23d65_rapier_physical_worker_preflight_v1",
    authorization_preflight_schema: "sporespore_qsdk_r23d65_rapier_production_authorization_preflight_v1",
    campaign_seed: R23D65_CAMPAIGN_SEED,
    prospective_initial_perturbation: Some(R23D65_INITIAL_PERTURBATION),
    startup_velocity_ramp: true,
    support_loss_conditioned_startup: true,
};

fn r23d27_campaign(stage_id: &str) -> Result<&'static R23D27CampaignContract, String> {
    match stage_id {
        R23D27_STAGE_ID => Ok(&R23D27_CAMPAIGN),
        R23D28_STAGE_ID => Ok(&R23D28_CAMPAIGN),
        R23D29_STAGE_ID => Ok(&R23D29_CAMPAIGN),
        R23D30_STAGE_ID => Ok(&R23D30_CAMPAIGN),
        R23D31_STAGE_ID => Ok(&R23D31_CAMPAIGN),
        R23D32_STAGE_ID => Ok(&R23D32_CAMPAIGN),
        R23D40_STAGE_ID => Ok(&R23D40_CAMPAIGN),
        R23D41_STAGE_ID => Ok(&R23D41_CAMPAIGN),
        R23D42_STAGE_ID => Ok(&R23D42_CAMPAIGN),
        R23D43_STAGE_ID => Ok(&R23D43_CAMPAIGN),
        R23D44_STAGE_ID => Ok(&R23D44_CAMPAIGN),
        R23D48_STAGE_ID => Ok(&R23D48_CAMPAIGN),
        R23D49_STAGE_ID => Ok(&R23D49_CAMPAIGN),
        R23D50_STAGE_ID => Ok(&R23D50_CAMPAIGN),
        R23D62_STAGE_ID => Ok(&R23D62_CAMPAIGN),
        R23D63_STAGE_ID => Ok(&R23D63_CAMPAIGN),
        R23D64_STAGE_ID => Ok(&R23D64_CAMPAIGN),
        R23D65_STAGE_ID => Ok(&R23D65_CAMPAIGN),
        _ => Err(format!("QSDK_R23D27_RAP_STAGE_UNKNOWN:{stage_id}")),
    }
}

fn is_selected_profile_campaign(campaign: &R23D27CampaignContract) -> bool {
    matches!(
        campaign.gate_id,
        R23D62_GATE_ID | R23D63_GATE_ID | R23D64_GATE_ID | R23D65_GATE_ID
    )
}

fn selected_profile_trace_transport_id(campaign: &R23D27CampaignContract) -> &'static str {
    if campaign.gate_id == R23D65_GATE_ID {
        R23D65_TRACE_TRANSPORT_ID
    } else if campaign.gate_id == R23D64_GATE_ID {
        R23D64_TRACE_TRANSPORT_ID
    } else if campaign.gate_id == R23D63_GATE_ID {
        R23D63_TRACE_TRANSPORT_ID
    } else {
        R23D62_TRACE_TRANSPORT_ID
    }
}

#[derive(Debug, Clone)]
struct R23D27Cell {
    campaign: &'static R23D27CampaignContract,
    stage_id: String,
    cell_id: String,
    candidate_id: String,
    controller_policy_id: &'static str,
    maximum_steering_fraction: f64,
    arm_id: String,
    turn_heading_offset_rad: f64,
    startup_velocity_ramp: bool,
    support_loss_conditioned_startup: bool,
}

#[derive(Debug)]
pub(super) struct R23D27ObservationFields {
    pub(super) measured_yaw_rad: f64,
    pub(super) torso_height_m: f64,
    pub(super) torso_tilt_rad: f64,
    pub(super) torso_ground_contact: bool,
    pub(super) ordered_foot_contacts: BTreeMap<String, bool>,
}

#[derive(Debug, Clone)]
struct R23D27ControllerTraceObservation {
    task_velocities: [f64; 3],
    maximum_joint_error_rad: f64,
    ordered_final_canonical_velocities_rad_s: [f64; R23D3_ACTUATOR_COUNT as usize],
    ordered_actuator_velocity_limits_rad_s: [f64; R23D3_ACTUATOR_COUNT as usize],
    steering_authority_guard: Value,
    ordered_foot_contacts_before: BTreeMap<String, bool>,
    startup_ramp: R23D40StartupRampReceipt,
    support_loss_conditioned_startup: Option<R23D48SupportLossReceipt>,
}

#[derive(Debug)]
struct R23D62TraceExtension {
    task_frame_origin_world_m: [f64; 3],
    torso_position_world_m: [f64; 3],
    task_frame_origin_reanchored_this_step: bool,
    task_frame_origin_reanchor_count: u64,
    ordered_limb_phase_before: Vec<Value>,
    actuator_phase_observation: Value,
}

fn r23d62_task_origin_reanchor_required(semantic_step: u64) -> bool {
    matches!(semantic_step, 600 | 1_800 | 2_400)
}

fn r23d62_ordered_limb_phase_before(
    memory: &BalancedWaveControllerMemory,
) -> Result<Vec<Value>, String> {
    const R23D62_GAIT_CYCLE_STEPS: u64 = 360;
    const EXPECTED_LIMBS: [&str; 4] = ["rear_left", "front_left", "rear_right", "front_right"];
    if memory.ordered_limb_memory.len() != EXPECTED_LIMBS.len() {
        return Err("QSDK_R23D62_RAP_LIMB_MEMORY_CARDINALITY_INVALID".to_owned());
    }
    memory
        .ordered_limb_memory
        .iter()
        .zip(EXPECTED_LIMBS)
        .enumerate()
        .map(|(phase_index, (limb, expected_limb_id))| {
            if limb.limb_id != expected_limb_id {
                return Err(format!(
                    "QSDK_R23D62_RAP_LIMB_MEMORY_ORDER_INVALID:{phase_index}"
                ));
            }
            let phase_offset = phase_index as u64 * (R23D62_GAIT_CYCLE_STEPS / 4);
            let local_phase_step =
                (limb.gait_step + R23D62_GAIT_CYCLE_STEPS - phase_offset) % R23D62_GAIT_CYCLE_STEPS;
            Ok(json!({
                "limb_id": limb.limb_id,
                "local_phase_step": local_phase_step,
                "gait_step": limb.gait_step,
                "release_hold_step_count": limb.release_hold_step_count,
            }))
        })
        .collect()
}

fn r23d62_actuator_limb_identity(actuator_id: &str) -> Result<(&str, u64), String> {
    if let Some(limb_id) = actuator_id.strip_suffix("_hip_motor") {
        Ok((limb_id, 0))
    } else if let Some(limb_id) = actuator_id.strip_suffix("_knee_motor") {
        Ok((limb_id, 1))
    } else {
        Err(format!(
            "QSDK_R23D62_RAP_TRACE_ACTUATOR_ID_INVALID:{actuator_id}"
        ))
    }
}

fn r23d62_actuator_phase_observation(
    semantic_step: u64,
    controller_step_receipt_sha256: String,
    ordered_limb_phase_before: &[Value],
    ordered_foot_contacts_before: &BTreeMap<String, bool>,
    ordered_foot_contacts_after: &BTreeMap<String, bool>,
    readback: &crate::locomotion::RapierR23D62StepReadbackV1,
) -> Result<Value, String> {
    const TRACE_READBACK_TOLERANCE: f64 = 2.5e-7;
    let phase_by_limb = ordered_limb_phase_before
        .iter()
        .map(|value| {
            value["limb_id"]
                .as_str()
                .map(|limb_id| (limb_id, value))
                .ok_or_else(|| "QSDK_R23D62_RAP_TRACE_PHASE_ID_INVALID".to_owned())
        })
        .collect::<Result<BTreeMap<_, _>, _>>()?;
    let mut ordered_actuator_ids = Vec::with_capacity(readback.ordered_applications.len());
    let mut ordered_applications = Vec::with_capacity(readback.ordered_applications.len());
    for application in &readback.ordered_applications {
        let (limb_id, limb_joint_index) = r23d62_actuator_limb_identity(&application.actuator_id)?;
        let phase = phase_by_limb
            .get(limb_id)
            .ok_or_else(|| format!("QSDK_R23D62_RAP_TRACE_PHASE_MISSING:{limb_id}"))?;
        let before = *ordered_foot_contacts_before
            .get(limb_id)
            .ok_or_else(|| format!("QSDK_R23D62_RAP_TRACE_CONTACT_BEFORE_MISSING:{limb_id}"))?;
        let after = *ordered_foot_contacts_after
            .get(limb_id)
            .ok_or_else(|| format!("QSDK_R23D62_RAP_TRACE_CONTACT_AFTER_MISSING:{limb_id}"))?;
        ordered_actuator_ids.push(application.actuator_id.clone());
        ordered_applications.push(json!({
            "actuator_id": application.actuator_id,
            "joint_id": application.joint_id,
            "host_joint_id": application.joint_id,
            "limb_id": limb_id,
            "limb_joint_index": limb_joint_index,
            "requested_target_position_rad": application.requested_target_position_rad,
            "clamped_target_position_rad": application.clamped_target_position_rad,
            "controller_target_velocity_rad_s": application.controller_target_velocity_rad_s,
            "maximum_target_speed_rad_s": application.maximum_target_speed_rad_s,
            "host_applied_target_velocity_rad_s": application.host_applied_target_velocity_rad_s,
            "motor_target_velocity_readback_rad_s": application.motor_target_velocity_readback_rad_s,
            "motor_target_velocity_readback_error_rad_s":
                application.motor_target_velocity_readback_error_rad_s,
            "declared_maximum_impulse_nms": application.declared_maximum_impulse_nms,
            "motor_maximum_impulse_readback_nms":
                application.motor_maximum_impulse_readback_nms,
            "motor_maximum_impulse_readback_error_nms":
                application.motor_maximum_impulse_readback_error_nms,
            "position_saturated": application.position_saturated,
            "velocity_saturated": application.velocity_saturated,
            "slew_limited": application.slew_limited,
            "host_additional_clamp_applied": false,
            "target_velocity_readback_matches": application.target_velocity_readback_matches,
            "maximum_impulse_readback_matches": application.maximum_impulse_readback_matches,
            "local_phase_step_before": phase["local_phase_step"],
            "gait_step_before": phase["gait_step"],
            "release_hold_step_count_before": phase["release_hold_step_count"],
            "foot_contact_before": before,
            "foot_contact_after": after,
        }));
    }
    Ok(json!({
        "schema_version": R23D62_ACTUATOR_PHASE_OBSERVATION_SCHEMA,
        "semantic_step": semantic_step,
        "controller_step_receipt_sha256": controller_step_receipt_sha256,
        "application_receipt_schema_version": R23D62_APPLICATION_RECEIPT_SCHEMA,
        "ordered_actuator_ids": ordered_actuator_ids,
        "ordered_limb_ids": ["rear_left", "front_left", "rear_right", "front_right"],
        "readback_tolerance": TRACE_READBACK_TOLERANCE,
        "ordered_applications": ordered_applications,
        "after_contact_observation_complete": true,
        "configured_motor_parameters_only": true,
        "measured_motor_torque_available": false,
        "measured_motor_impulse_available": false,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

#[derive(Debug, Clone)]
struct R23D40StartupRampReceipt {
    startup_ramp_id: &'static str,
    startup_velocity_scale: f64,
    startup_ramp_active: bool,
    startup_ramp_residual_count: usize,
    startup_ramp_maximum_absolute_residual_rad_s: f64,
}

#[derive(Debug, Clone)]
struct R23D48SupportLossReceipt {
    startup_probe_active: bool,
    startup_probe_support_count: usize,
    startup_probe_complete_support_loss: bool,
    startup_transform_decision_locked: bool,
    startup_ramp_triggered: bool,
    startup_ramp_trigger_step: Option<u64>,
    startup_ramp_local_step: Option<u64>,
}

#[derive(Debug, Clone)]
struct R23D48SupportLossState {
    next_semantic_step: u64,
    trigger_step: Option<u64>,
    decision_locked: bool,
    minimum_probe_support_count: usize,
}

impl Default for R23D48SupportLossState {
    fn default() -> Self {
        Self {
            next_semantic_step: 0,
            trigger_step: None,
            decision_locked: false,
            minimum_probe_support_count: 4,
        }
    }
}

fn r23d40_startup_velocity_scale(semantic_step: u64) -> f64 {
    if semantic_step >= R23D40_STARTUP_RAMP_STEPS - 1 {
        return 1.0;
    }
    let progress = semantic_step as f64 / (R23D40_STARTUP_RAMP_STEPS - 1) as f64;
    progress * progress * (3.0 - 2.0 * progress)
}

fn r23d40_startup_residuals(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    semantic_step: u64,
) -> Result<(Vec<CanonicalVelocityResidualV1>, R23D40StartupRampReceipt), String> {
    let scale = r23d40_startup_velocity_scale(semantic_step);
    if base_actuation.ordered_commands.len() != compiled.morphology.ordered_actuator_ids.len() {
        return Err("QSDK_R23D40_RAP_STARTUP_COMMAND_COUNT_INVALID".to_owned());
    }
    let mut residuals = Vec::with_capacity(base_actuation.ordered_commands.len());
    let mut maximum_absolute_residual = 0.0_f64;
    for (actuator_id, source_command) in compiled
        .morphology
        .ordered_actuator_ids
        .iter()
        .zip(&base_actuation.ordered_commands)
    {
        if source_command.actuator_id != *actuator_id
            || !source_command.target_velocity_rad_s.is_finite()
        {
            return Err(format!(
                "QSDK_R23D40_RAP_STARTUP_COMMAND_INVALID:{actuator_id}"
            ));
        }
        let source_canonical_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        let delta = source_canonical_velocity * (scale - 1.0);
        maximum_absolute_residual = maximum_absolute_residual.max(delta.abs());
        residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator_id.clone(),
            canonical_velocity_delta_rad_s: delta,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
    }
    let receipt = R23D40StartupRampReceipt {
        startup_ramp_id: R23D40_STARTUP_RAMP_ID,
        startup_velocity_scale: scale,
        startup_ramp_active: scale < 1.0,
        startup_ramp_residual_count: residuals.len(),
        startup_ramp_maximum_absolute_residual_rad_s: maximum_absolute_residual,
    };
    Ok((residuals, receipt))
}

fn r23d48_support_count(
    ordered_foot_contacts_before: &BTreeMap<String, bool>,
) -> Result<usize, String> {
    const LIMB_IDS: [&str; 4] = ["rear_left", "front_left", "rear_right", "front_right"];
    if ordered_foot_contacts_before.len() != LIMB_IDS.len()
        || LIMB_IDS
            .iter()
            .any(|limb_id| !ordered_foot_contacts_before.contains_key(*limb_id))
    {
        return Err("QSDK_R23D48_RAP_CONTACT_IDENTITY_INVALID".to_owned());
    }
    Ok(LIMB_IDS
        .iter()
        .filter(|limb_id| {
            ordered_foot_contacts_before
                .get(**limb_id)
                .copied()
                .unwrap_or(false)
        })
        .count())
}

fn r23d48_support_loss_step(
    state: &mut R23D48SupportLossState,
    semantic_step: u64,
    ordered_foot_contacts_before: &BTreeMap<String, bool>,
) -> Result<(f64, R23D48SupportLossReceipt), String> {
    if semantic_step != state.next_semantic_step || semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err(format!(
            "QSDK_R23D48_RAP_SEMANTIC_STEP_INVALID:{semantic_step}:expected_{}",
            state.next_semantic_step
        ));
    }
    let support_count = r23d48_support_count(ordered_foot_contacts_before)?;
    let in_probe = semantic_step <= R23D48_PROBE_LAST_SEMANTIC_STEP;
    state.minimum_probe_support_count = state.minimum_probe_support_count.min(support_count);
    if in_probe && !state.decision_locked && state.trigger_step.is_none() && support_count == 0 {
        state.trigger_step = Some(semantic_step);
    }
    if semantic_step >= R23D48_PROBE_LAST_SEMANTIC_STEP {
        state.decision_locked = true;
    }
    let local_step = state
        .trigger_step
        .map(|trigger_step| semantic_step - trigger_step);
    let scale = local_step.map_or(1.0, r23d40_startup_velocity_scale);
    state.next_semantic_step += 1;
    Ok((
        scale,
        R23D48SupportLossReceipt {
            startup_probe_active: in_probe,
            startup_probe_support_count: support_count,
            startup_probe_complete_support_loss: support_count == 0,
            startup_transform_decision_locked: state.decision_locked,
            startup_ramp_triggered: state.trigger_step.is_some(),
            startup_ramp_trigger_step: state.trigger_step,
            startup_ramp_local_step: local_step,
        },
    ))
}

fn r23d48_support_loss_conditioned_residuals(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    semantic_step: u64,
    ordered_foot_contacts_before: &BTreeMap<String, bool>,
    state: &mut R23D48SupportLossState,
) -> Result<
    (
        Vec<CanonicalVelocityResidualV1>,
        R23D40StartupRampReceipt,
        R23D48SupportLossReceipt,
    ),
    String,
> {
    let (scale, support_loss_receipt) =
        r23d48_support_loss_step(state, semantic_step, ordered_foot_contacts_before)?;
    if base_actuation.ordered_commands.len() != compiled.morphology.ordered_actuator_ids.len() {
        return Err("QSDK_R23D48_RAP_STARTUP_COMMAND_COUNT_INVALID".to_owned());
    }
    let mut residuals = Vec::with_capacity(base_actuation.ordered_commands.len());
    let mut maximum_absolute_residual = 0.0_f64;
    for (actuator_id, source_command) in compiled
        .morphology
        .ordered_actuator_ids
        .iter()
        .zip(&base_actuation.ordered_commands)
    {
        if source_command.actuator_id != *actuator_id
            || !source_command.target_velocity_rad_s.is_finite()
        {
            return Err(format!(
                "QSDK_R23D48_RAP_STARTUP_COMMAND_INVALID:{actuator_id}"
            ));
        }
        let source_canonical_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        let delta = source_canonical_velocity * (scale - 1.0);
        maximum_absolute_residual = maximum_absolute_residual.max(delta.abs());
        residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator_id.clone(),
            canonical_velocity_delta_rad_s: delta,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
    }
    let ramp_receipt = R23D40StartupRampReceipt {
        startup_ramp_id: R23D48_STARTUP_TRANSFORM_ID,
        startup_velocity_scale: scale,
        startup_ramp_active: support_loss_receipt.startup_ramp_triggered && scale < 1.0,
        startup_ramp_residual_count: residuals.len(),
        startup_ramp_maximum_absolute_residual_rad_s: maximum_absolute_residual,
    };
    Ok((residuals, ramp_receipt, support_loss_receipt))
}

fn r23d48_support_loss_canaries() -> Result<(bool, bool), String> {
    let contacts = |rear_left: bool, front_left: bool, rear_right: bool, front_right: bool| {
        BTreeMap::from([
            ("rear_left".to_owned(), rear_left),
            ("front_left".to_owned(), front_left),
            ("rear_right".to_owned(), rear_right),
            ("front_right".to_owned(), front_right),
        ])
    };
    let mut trigger = R23D48SupportLossState::default();
    let trigger_inputs = [
        contacts(true, true, true, true),
        contacts(true, true, true, true),
        contacts(true, false, false, true),
        contacts(false, false, false, false),
    ];
    let mut trigger_receipt = None;
    let mut trigger_scale = 1.0;
    for (semantic_step, input) in trigger_inputs.iter().enumerate() {
        let (scale, receipt) = r23d48_support_loss_step(&mut trigger, semantic_step as u64, input)?;
        trigger_scale = scale;
        trigger_receipt = Some(receipt);
    }
    let trigger_receipt = trigger_receipt
        .ok_or_else(|| "QSDK_R23D48_RAP_TRIGGER_CANARY_RECEIPT_MISSING".to_owned())?;
    let trigger_passed = trigger.trigger_step == Some(3)
        && trigger.decision_locked
        && trigger.minimum_probe_support_count == 0
        && trigger_scale == 0.0
        && trigger_receipt.startup_ramp_triggered
        && trigger_receipt.startup_ramp_trigger_step == Some(3)
        && trigger_receipt.startup_ramp_local_step == Some(0)
        && trigger_scale < 1.0;

    let mut identity = R23D48SupportLossState::default();
    let all_support = contacts(true, true, true, true);
    let mut identity_passed = true;
    for semantic_step in 0..=R23D48_PROBE_LAST_SEMANTIC_STEP {
        let (scale, receipt) =
            r23d48_support_loss_step(&mut identity, semantic_step, &all_support)?;
        identity_passed &= scale == 1.0
            && !receipt.startup_ramp_triggered
            && receipt.startup_ramp_trigger_step.is_none()
            && receipt.startup_ramp_local_step.is_none();
    }
    let (post_probe_scale, post_probe_receipt) = r23d48_support_loss_step(
        &mut identity,
        R23D48_PROBE_LAST_SEMANTIC_STEP + 1,
        &contacts(false, false, false, false),
    )?;
    identity_passed &= identity.trigger_step.is_none()
        && identity.decision_locked
        && post_probe_scale == 1.0
        && !post_probe_receipt.startup_ramp_triggered
        && post_probe_receipt.startup_ramp_trigger_step.is_none()
        && post_probe_receipt.startup_ramp_local_step.is_none();
    Ok((trigger_passed, identity_passed))
}

#[derive(Debug, Clone)]
struct R23D27CommandFeedback {
    trace_step: u64,
    ordered_foot_contacts: BTreeMap<String, bool>,
    torso_tilt_rad: f64,
    maximum_joint_error_rad: f64,
}

#[derive(Debug)]
struct R23D27AuthorityReceipt {
    tilt_floor_numerator: u64,
    joint_error_floor_numerator: u64,
    pose_authority_floor_numerator: u64,
    controlling_input: Option<&'static str>,
    temporal_scale_numerator: u64,
    applied_scale_numerator: u64,
    combined_pre_taper_velocities_rad_s: Vec<Option<f64>>,
    final_canonical_velocities_rad_s: Vec<f64>,
    residual_pose_recovery_invoked: bool,
}

fn r23d27_claims() -> Value {
    json!({
        "command_conditioned_turning": false,
        "bilateral_signed_turning": false,
        "portable_basic_turning": false,
        "cross_engine_equivalence": false,
        "q_sdk_r23_satisfied": false,
        "prone_to_standing": false,
        "release_authorized": false,
        "physical_acceptance_authority": false,
    })
}

fn r23d27_cell(stage_id: &str, candidate_id: &str, arm_id: &str) -> Result<R23D27Cell, String> {
    let campaign = r23d27_campaign(stage_id)?;
    let startup_velocity_ramp = if campaign.gate_id == R23D44_GATE_ID {
        match candidate_id {
            R23D44_NO_RAMP_CANDIDATE_ID => false,
            R23D44_RAMP_CANDIDATE_ID => true,
            _ => return Err(format!("QSDK_R23D44_RAP_CANDIDATE_UNKNOWN:{candidate_id}")),
        }
    } else {
        if candidate_id != campaign.candidate_id {
            return Err(format!("QSDK_R23D27_RAP_CANDIDATE_UNKNOWN:{candidate_id}"));
        }
        campaign.startup_velocity_ramp
    };
    let turn_heading_offset_rad = r23d3_arm_offset(arm_id)
        .filter(|_| {
            matches!(
                arm_id,
                "reference_zero" | "positive_heading" | "negative_heading"
            )
        })
        .ok_or_else(|| format!("QSDK_R23D27_RAP_ARM_UNKNOWN:{arm_id}"))?;
    let cell_id = if is_selected_profile_campaign(campaign) {
        format!(
            "{R23D27_ENGINE_ID}__s{}__{}__{arm_id}",
            campaign.campaign_seed, campaign.candidate_id,
        )
    } else {
        format!("{R23D27_ENGINE_ID}__{candidate_id}__{arm_id}")
    };
    Ok(R23D27Cell {
        campaign,
        stage_id: stage_id.to_owned(),
        cell_id,
        candidate_id: candidate_id.to_owned(),
        controller_policy_id: campaign.controller_policy_id,
        maximum_steering_fraction: 0.28,
        arm_id: arm_id.to_owned(),
        turn_heading_offset_rad,
        startup_velocity_ramp,
        support_loss_conditioned_startup: campaign.support_loss_conditioned_startup,
    })
}

fn r23d27_compile_boundary(
    cell: &R23D27Cell,
) -> Result<
    (
        sporespore_locomotion_core::CompiledQuadruped,
        BalancedWaveController,
    ),
    String,
> {
    let (compiled, controller) = compile_boundary_for_policy(cell.controller_policy_id)?;
    let profile = controller.profile();
    if profile.policy_id != cell.controller_policy_id
        || profile.yaw_error_stride_gain_per_rad != 1.0
        || profile.maximum_steering_fraction != Some(cell.maximum_steering_fraction)
        || profile.minimum_steering_fraction != Some(0.20)
        || profile.steering_authority_guard_mode_id.as_deref() != Some(cell.campaign.guard_mode_id)
        || profile.steering_guard_full_authority_maximum_tilt_rad != Some(0.10)
        || profile.steering_guard_minimum_authority_tilt_rad != Some(0.20)
        || profile.steering_guard_minimum_support_contact_count != Some(2)
        || profile.steering_guard_prediction_horizon_s != cell.campaign.predictive.then_some(0.6)
        || profile.steering_guard_floor_hold_steps != cell.campaign.floor_hold_steps
        || profile.cross_track_frame_mode_id.as_deref()
            != Some(COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID)
    {
        return Err("QSDK_R23D27_RAP_CONTROLLER_PROFILE_INVALID".to_owned());
    }
    let initial_memory = controller.initial_memory();
    if initial_memory.steering_guard_floor_hold_steps_remaining
        != cell.campaign.floor_hold_steps.map(|_| 0)
        || (cell.campaign.floor_hold_steps.is_some()
            && initial_memory.schema_version != BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION)
    {
        return Err("QSDK_R23D27_RAP_CONTROLLER_MEMORY_PROFILE_INVALID".to_owned());
    }
    Ok((compiled, controller))
}

fn r23d27_validate_guard_receipt(
    campaign: &R23D27CampaignContract,
    state: &StateFrame,
    memory_before: &BalancedWaveControllerMemory,
    memory_after: &BalancedWaveControllerMemory,
    receipt: &sporespore_locomotion_core::SteeringAuthorityGuardReceipt,
) -> Result<(), String> {
    let orientation = state.base_pose_world.orientation_xyzw;
    let torso_up = Vec3 {
        x: 2.0 * (orientation.x * orientation.y - orientation.w * orientation.z),
        y: orientation.w * orientation.w - orientation.x * orientation.x
            + orientation.y * orientation.y
            - orientation.z * orientation.z,
        z: 2.0 * (orientation.y * orientation.z + orientation.w * orientation.x),
    };
    let gravity = state.gravity_world_m_s2;
    let gravity_magnitude =
        (gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z).sqrt();
    if !gravity_magnitude.is_finite() || gravity_magnitude <= TOLERANCE {
        return Err("QSDK_R23D27_RAP_GUARD_GRAVITY_INVALID".to_owned());
    }
    let gravity_up = Vec3 {
        x: -gravity.x / gravity_magnitude,
        y: -gravity.y / gravity_magnitude,
        z: -gravity.z / gravity_magnitude,
    };
    let expected_tilt = dot(torso_up, gravity_up).clamp(-1.0, 1.0).acos();
    let (expected_rate, expected_worsening_rate, expected_predicted_tilt) = if campaign.predictive {
        let angular_velocity = state.base_twist_world.angular_velocity_rad_s;
        let torso_up_derivative = Vec3 {
            x: angular_velocity.y * torso_up.z - angular_velocity.z * torso_up.y,
            y: angular_velocity.z * torso_up.x - angular_velocity.x * torso_up.z,
            z: angular_velocity.x * torso_up.y - angular_velocity.y * torso_up.x,
        };
        let cosine = dot(torso_up, gravity_up).clamp(-1.0, 1.0);
        let sine = (1.0 - cosine * cosine).max(0.0).sqrt();
        let rate = if sine > 1.0e-9 {
            -dot(torso_up_derivative, gravity_up) / sine
        } else {
            (torso_up_derivative.x * torso_up_derivative.x
                + torso_up_derivative.y * torso_up_derivative.y
                + torso_up_derivative.z * torso_up_derivative.z)
                .sqrt()
        };
        let worsening = rate.max(0.0);
        (
            Some(rate),
            Some(worsening),
            Some((expected_tilt + 0.6 * worsening).clamp(0.0, std::f64::consts::PI)),
        )
    } else {
        (None, None, None)
    };
    let expected_authority_tilt = expected_predicted_tilt.unwrap_or(expected_tilt);
    let mut expected_contacts = 0_u32;
    let mut expected_fallback = false;
    for contact in &state.ordered_contact_observations {
        let supports = match contact.bears_support {
            Some(value) => value,
            None => {
                expected_fallback = true;
                contact.presence.unwrap_or(false)
            }
        };
        expected_contacts += u32::from(supports);
    }
    let contact_permitted = expected_contacts >= 2;
    let expected_instantaneous_fraction = if !contact_permitted || expected_authority_tilt >= 0.20 {
        0.0
    } else if expected_authority_tilt <= 0.10 {
        1.0
    } else {
        (0.20 - expected_authority_tilt) / 0.10
    };
    let expected_instantaneous_effective = 0.20 + expected_instantaneous_fraction * 0.08;
    let (
        expected_floor_triggered,
        expected_floor_active,
        expected_remaining_before,
        expected_remaining_after,
        expected_fraction,
        expected_effective,
    ) = if let Some(duration_steps) = campaign.floor_hold_steps {
        let Some(remaining_before) = memory_before.steering_guard_floor_hold_steps_remaining else {
            return Err("QSDK_R23D27_RAP_GUARD_MEMORY_BEFORE_MISSING".to_owned());
        };
        if remaining_before > duration_steps
            || memory_before.schema_version != BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
            || memory_after.schema_version != BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
        {
            return Err("QSDK_R23D27_RAP_GUARD_MEMORY_BEFORE_INVALID".to_owned());
        }
        let triggered = expected_instantaneous_effective <= 0.20 + TOLERANCE;
        let refreshed = if triggered {
            duration_steps
        } else {
            remaining_before
        };
        let active = refreshed > 0;
        let remaining_after = if active { refreshed - 1 } else { 0 };
        if memory_after.steering_guard_floor_hold_steps_remaining != Some(remaining_after) {
            return Err("QSDK_R23D27_RAP_GUARD_MEMORY_AFTER_INVALID".to_owned());
        }
        (
            Some(triggered),
            Some(active),
            Some(remaining_before),
            Some(remaining_after),
            if active {
                0.0
            } else {
                expected_instantaneous_fraction
            },
            if active {
                0.20
            } else {
                expected_instantaneous_effective
            },
        )
    } else {
        if memory_before
            .steering_guard_floor_hold_steps_remaining
            .is_some()
            || memory_after
                .steering_guard_floor_hold_steps_remaining
                .is_some()
        {
            return Err("QSDK_R23D27_RAP_UNEXPECTED_GUARD_MEMORY".to_owned());
        }
        (
            None,
            None,
            None,
            None,
            expected_instantaneous_fraction,
            expected_instantaneous_effective,
        )
    };
    let exact = receipt.schema_version
        == if campaign.floor_hold_steps.is_some() {
            "sporespore_steering_authority_guard_receipt_v3"
        } else if campaign.predictive {
            "sporespore_steering_authority_guard_receipt_v2"
        } else {
            "sporespore_steering_authority_guard_receipt_v1"
        }
        && receipt.mode_id == campaign.guard_mode_id
        && (receipt.torso_tilt_rad - expected_tilt).abs() <= TOLERANCE
        && match (receipt.torso_tilt_rate_rad_s, expected_rate) {
            (Some(observed), Some(expected)) => (observed - expected).abs() <= TOLERANCE,
            (None, None) => true,
            _ => false,
        }
        && match (
            receipt.worsening_torso_tilt_rate_rad_s,
            expected_worsening_rate,
        ) {
            (Some(observed), Some(expected)) => (observed - expected).abs() <= TOLERANCE,
            (None, None) => true,
            _ => false,
        }
        && receipt.prediction_horizon_s == campaign.predictive.then_some(0.6)
        && receipt.prediction_horizon_scheduler_swing_steps == campaign.predictive.then_some(72)
        && match (receipt.predicted_torso_tilt_rad, expected_predicted_tilt) {
            (Some(observed), Some(expected)) => (observed - expected).abs() <= TOLERANCE,
            (None, None) => true,
            _ => false,
        }
        && receipt.tilt_rate_source_id.as_deref()
            == campaign
                .predictive
                .then_some("state_frame_base_twist_world_angular_velocity_v1")
        && receipt.prediction_horizon_basis_id.as_deref()
            == campaign
                .predictive
                .then_some("one_balanced_wave_scheduler_swing_v1")
        && receipt.support_contact_count == expected_contacts
        && receipt.support_contact_count_uses_presence_fallback == expected_fallback
        && receipt.minimum_support_contact_count == 2
        && receipt.contact_authority_permitted == contact_permitted
        && (receipt.tilt_authority_fraction - expected_fraction).abs() <= TOLERANCE
        && receipt.baseline_maximum_steering_fraction == 0.20
        && receipt.expanded_maximum_steering_fraction == 0.28
        && (receipt.effective_maximum_steering_fraction - expected_effective).abs() <= TOLERANCE
        && match (
            receipt.instantaneous_tilt_authority_fraction,
            campaign
                .floor_hold_steps
                .map(|_| expected_instantaneous_fraction),
        ) {
            (Some(observed), Some(expected)) => (observed - expected).abs() <= TOLERANCE,
            (None, None) => true,
            _ => false,
        }
        && match (
            receipt.instantaneous_effective_maximum_steering_fraction,
            campaign
                .floor_hold_steps
                .map(|_| expected_instantaneous_effective),
        ) {
            (Some(observed), Some(expected)) => (observed - expected).abs() <= TOLERANCE,
            (None, None) => true,
            _ => false,
        }
        && receipt.floor_hold_duration_steps == campaign.floor_hold_steps
        && receipt.floor_hold_scheduler_swing_count
            == campaign.floor_hold_steps.map(|steps| steps / 72)
        && receipt.floor_hold_steps_remaining_before_step == expected_remaining_before
        && receipt.floor_hold_steps_remaining_after_step == expected_remaining_after
        && receipt.floor_hold_triggered_this_step == expected_floor_triggered
        && receipt.floor_hold_active_this_step == expected_floor_active
        && receipt.floor_hold_basis_id.as_deref()
            == campaign
                .floor_hold_steps
                .map(|_| "two_balanced_wave_scheduler_swings_v1")
        && receipt.full_authority_maximum_tilt_rad == 0.10
        && receipt.minimum_authority_tilt_rad == 0.20
        && receipt.direction_neutral
        && receipt.engine_identity_input_count == 0
        && receipt.controller_parameter
        && !receipt.turning_claim_authorized
        && !receipt.physical_acceptance_authority;
    if !exact {
        return Err("QSDK_R23D27_RAP_GUARD_RECEIPT_INVALID".to_owned());
    }
    Ok(())
}

fn r23d27_initial_perturbation(
    campaign: &R23D27CampaignContract,
    successor: &Value,
) -> Result<InitialPerturbation, String> {
    let Some(expected) = campaign.prospective_initial_perturbation else {
        let (_, _, development) = parse_contracts()?;
        return initial_perturbation(&development);
    };
    let value = &successor["frozen_matrix"]["initial_perturbation"];
    let linear = exact_f64_array(value.get("initial_linear_velocity_world_m_s"), 3)?;
    let angular = exact_f64_array(value.get("initial_torso_angular_velocity_world_rad_s"), 3)?;
    let observed = InitialPerturbation {
        vertical_clearance_m: value["fixture_vertical_clearance_m"]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| "QSDK_R23D30_RAP_INITIAL_CLEARANCE_INVALID".to_owned())?,
        yaw_rad: value["fixture_yaw_rad"]
            .as_f64()
            .filter(|number| number.is_finite())
            .ok_or_else(|| "QSDK_R23D30_RAP_INITIAL_YAW_INVALID".to_owned())?,
        linear_velocity_world_m_s: [linear[0], linear[1], linear[2]],
        torso_angular_velocity_world_rad_s: [angular[0], angular[1], angular[2]],
        gait_phase_offset_ticks: value["gait_phase_offset_ticks"]
            .as_i64()
            .ok_or_else(|| "QSDK_R23D30_RAP_INITIAL_PHASE_INVALID".to_owned())?,
    };
    let exact = value["campaign_seed"] == campaign.campaign_seed
        && observed.vertical_clearance_m == expected.vertical_clearance_m
        && observed.yaw_rad == expected.yaw_rad
        && observed.linear_velocity_world_m_s == expected.linear_velocity_world_m_s
        && observed.torso_angular_velocity_world_rad_s
            == expected.torso_angular_velocity_world_rad_s
        && observed.gait_phase_offset_ticks == expected.gait_phase_offset_ticks;
    if !exact {
        return Err("QSDK_R23D30_RAP_INITIAL_PERTURBATION_INVALID".to_owned());
    }
    Ok(observed)
}

fn selected_profile_contract_exact(
    campaign: &R23D27CampaignContract,
    successor: &Value,
    implementation: &Value,
    generation: &str,
) -> Result<(), String> {
    let historical_world_key = format!("historical_world_reused_as_{generation}_cell");
    let historical_composition_key =
        format!("historical_engine_positive_composed_as_{generation}_result");
    let seed_occurrence_key = format!("{generation}_seed_had_prior_repository_occurrence");
    let worker_path = format!("sdk/adapters/rapier/src/qsdk_{generation}_rapier_worker.rs");
    let route_path = format!("sdk/adapters/rapier/src/qsdk_{generation}_public_profile_route.rs");
    let binary_path = format!("sdk/adapters/rapier/src/bin/qsdk_{generation}_physical.rs");
    let error_prefix = generation.to_ascii_uppercase();
    let expected_implementation_status = match generation {
        "r23d63" => {
            "prospective_campaign_machinery_implemented_receipt_schema_gate_passed_complete_zero_world_gate_passed_physical_not_opened"
        }
        "r23d64" => {
            "prospective_campaign_machinery_implemented_receipt_schema_and_rapier_launcher_contract_gates_passed_complete_zero_world_gate_passed_physical_not_opened"
        }
        "r23d65" => {
            "prospective_campaign_machinery_implemented_runtime_integration_gates_passed_complete_zero_world_gate_passed_physical_not_opened"
        }
        _ => {
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_passed_physical_not_opened"
        }
    };
    let profile = &successor["published_profile_binding"];
    let matrix = &successor["frozen_matrix"];
    let gates = &successor["frozen_common_physical_gates"];
    let measurement = &successor["cycle_integrated_measurement"];
    let rule = &successor["finite_decision_rule"];
    let requirements = &successor["implementation_and_execution_requirements"];
    let rapier = &implementation["workers"][R23D27_ENGINE_ID];
    let claims = &implementation["claims"];
    let exact = successor["schema_version"] == campaign.preregistration_schema
        && successor["status"] == "prospective_zero_world_only_physical_not_opened"
        && successor["campaign_id"] == campaign.campaign_id
        && successor["gate_id"] == campaign.gate_id
        && successor["question_class"] == "finite_decision"
        && successor["study_classification"] == campaign.study_classification
        && successor["physical_question_declared"] == true
        && successor["physical_campaign_opened"] == false
        && successor["immutable_lineage"]["historical_result_reinterpreted"] == false
        && successor["immutable_lineage"][historical_world_key.as_str()] == false
        && successor["immutable_lineage"][historical_composition_key.as_str()] == false
        && successor["immutable_lineage"][seed_occurrence_key.as_str()] == false
        && profile["profile_id"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && profile["profile_sha256"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        && profile["morphology_id"] == MORPHOLOGY_ID
        && profile["descriptor_sha256"]
            == sporespore_locomotion_core::R23D60_SELECTED_S169_DESCRIPTOR_SHA256
        && profile["morphology_spec_sha256"]
            == sporespore_locomotion_core::R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
        && profile["semantics_id"]
            == sporespore_locomotion_core::OUTER_STEP_ANGULAR_IMPULSE_SEMANTICS_V1
        && profile["public_resolution_required_in_each_worker"] == true
        && profile["host_mapping_receipt_required_before_each_world"] == true
        && profile["legacy_fixture_override_permitted"] == false
        && matrix["stage_id"] == campaign.stage_id
        && matrix["ordered_engine_ids"] == json!(["godot_jolt", R23D27_ENGINE_ID, "mujoco"])
        && matrix["ordered_arm_ids"]
            == json!(["reference_zero", "positive_heading", "negative_heading"])
        && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
        && matrix["declared_cell_count"] == 9
        && matrix["declared_world_count"] == 9
        && matrix["seed"] == campaign.campaign_seed
        && matrix["morphology_id"] == MORPHOLOGY_ID
        && matrix["controller_policy_id"] == campaign.controller_policy_id
        && matrix["task_frame_origin_policy_id"] == R23D62_TASK_ORIGIN_POLICY_ID
        && matrix["initial_schedule_bind_semantic_step"] == 0
        && matrix["fixed_origin_last_semantic_step"] == 599
        && matrix["expected_reanchor_semantic_steps"] == json!([600, 1800, 2400])
        && matrix["startup_transform_id"] == R23D48_STARTUP_TRANSFORM_ID
        && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
        && matrix["turn_start_step"] == TURN_START_STEP
        && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && matrix["recovery_duration_steps"] == 600
        && matrix["host_mapping_ids"][R23D27_ENGINE_ID] == R23D62_HOST_MAPPING_ID
        && matrix["engine_identity_is_policy_input"] == false
        && matrix["arm_identity_is_policy_input"] == false
        && matrix["serial_execution_required"] == true
        && matrix["fresh_world_required_per_cell"] == true
        && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
        && gates["minimum_final_forward_displacement_m"] == 0.030123046875
        && gates["maximum_tilt_rad"] == 0.6
        && gates["minimum_torso_height_m"] == 0.2499708652072946
        && gates["minimum_contact_cycles_per_limb"] == 2
        && matrix["terminal_restoration_or_taper_invoked"] == false
        && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
        && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
        && measurement["both_signed_arms_required"] == true
        && measurement["reference_arm_required"] == true
        && rule["complete_execution_valid_nine_cell_matrix_required"] == true
        && rule["all_nine_cells_must_pass_every_common_physical_gate"] == true
        && rule["each_engine_must_independently_pass_both_turning_gates"] == true
        && rule["early_stop_or_selective_rerun_permitted"] == false
        && rule["positive_cross_engine_equivalence"] == false
        && requirements["separate_dependency_closed_workers_required"] == true
        && requirements["three_separate_native_workers_required"] == true
        && requirements["complete_zero_world_gate_and_negative_controls_required"] == true
        && requirements["public_profile_resolution_and_host_readback_controls_required"] == true
        && requirements["task_origin_and_schedule_semantic_canaries_required_per_engine"] == true
        && requirements["physical_world_may_open_from_this_declaration_alone"] == false
        && implementation["schema_version"] == campaign.implementation_schema
        && implementation["status"] == expected_implementation_status
        && implementation["campaign_id"] == campaign.campaign_id
        && implementation["gate_id"] == campaign.gate_id
        && implementation["question_class"] == "finite_decision"
        && implementation["physical_campaign_opened"] == false
        && implementation["declared_world_count"] == 9
        && implementation["profile_id"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && implementation["profile_sha256"] == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        && implementation["implemented_native_dependency_route_count"] == 3
        && implementation["implemented_native_worker_count"] == 3
        && rapier["path"] == worker_path
        && rapier["implementation_complete"] == true
        && rapier["production_public_profile_route_path"] == route_path
        && rapier["production_profile_mapping_path"]
            == "sdk/adapters/rapier/src/actuator_cap_profile.rs"
        && rapier["production_physical_constructor_path"]
            == "sdk/adapters/rapier/src/locomotion.rs"
        && rapier["production_physical_runner_path"]
            == "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
        && rapier["binary_path"] == binary_path
        && rapier["declared_preflight_cell_count"] == 3
        && rapier["zero_world_dependency_route_gate_passed"] == true
        && rapier["zero_world_worker_gate_passed"] == true
        && rapier["physical_execution_authorized"] == false
        && claims["godot_worker_implementation_complete"] == true
        && claims["rapier_public_profile_dependency_route_complete"] == true
        && claims["rapier_worker_implementation_complete"] == true
        && claims["mujoco_public_profile_dependency_route_complete"] == true
        && claims["mujoco_worker_implementation_complete"] == true
        && claims["native_routes_and_workers_complete"] == true
        && claims["implementation_complete"] == true
        && claims["complete_zero_world_gate_passed"] == true
        && claims["complete_transitive_dependency_inventory_proved"] == true
        && claims["physical_world_opened"] == false
        && claims["fresh_rapier_turning_replication"] == false
        && claims["finite_three_engine_turning"] == false
        && claims["q_sdk_r23_satisfied"] == false
        && claims["cross_engine_equivalence"] == false
        && claims["prone_to_standing"] == false
        && claims["release_authority"] == false
        && claims["physical_acceptance_authority"] == false;
    if !exact {
        return Err(format!("QSDK_{error_prefix}_RAP_CONTRACT_IDENTITY_INVALID"));
    }
    if generation == "r23d63" {
        let predecessor = &successor["predecessor_closure"];
        let change_budget = &successor["successor_change_budget"];
        let receipt = &successor["authorization_receipt_schema_conformance"];
        let implementation_receipt = &implementation["authorization_receipt_schema_conformance"];
        let execution = &successor["implementation_and_execution_requirements"];
        let controls = &successor["required_zero_world_negative_controls"];
        let receipt_exact = predecessor["gate_id"] == R23D62_GATE_ID
            && predecessor["campaign_id"] == R23D62_CAMPAIGN_ID
            && predecessor["campaign_identity_consumed"] == true
            && predecessor["physical_outcome_exposed"] == false
            && predecessor["world_attempt_count"] == 0
            && predecessor["same_identity_repair_or_rerun_permitted"] == false
            && change_budget["allowed_mechanism_changes"]
                == json!([
                    "production_authorization_receipt_complete_matrix_proof_projection",
                    "pre_attempt_three_engine_receipt_schema_parity_and_mutation_gate",
                    "named_supervisor_receipt_schema_failure_diagnostic",
                ])
            && change_budget["selected_public_profile_preserved"] == true
            && change_budget["controller_and_policy_semantics_preserved"] == true
            && change_budget["physics_and_native_engine_bindings_preserved"] == true
            && change_budget["common_physical_thresholds_preserved"] == true
            && change_budget["turning_thresholds_preserved"] == true
            && change_budget["selector_evaluator_and_interpretation_preserved"] == true
            && receipt["question_class"] == "equivalence_non_inferiority"
            && receipt["declared_producer_count"] == 3
            && receipt["required_conforming_producer_count"] == 3
            && receipt["producer_ids"] == json!(["godot_jolt", "rapier_parry", "mujoco"])
            && receipt["required_field"] == "complete_ordered_nine_cell_matrix_validated"
            && receipt["required_json_type"] == "boolean"
            && receipt["required_value"] == true
            && receipt["equivalence_margin"] == 0
            && receipt["non_inferiority_margin"] == 0
            && receipt["sampling_used"] == false
            && receipt["negative_control_count_per_engine"] == 4
            && receipt["total_negative_control_count"] == 12
            && receipt["must_pass_before_physical_freeze"] == true
            && receipt["must_pass_before_attempt_authorization"] == true
            && receipt["physical_equivalence_claimed"] == false
            && execution["authorization_receipt_schema_conformance_gate_required"] == true
            && execution["authorization_receipt_schema_conformance_gate_must_precede_freeze"]
                == true
            && execution["authorization_receipt_schema_conformance_gate_must_precede_attempt_authorization"]
                == true
            && controls["authorization_receipt_complete_matrix_field_missing_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_false_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_wrong_type_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_alias_rejected_per_engine"]
                == true
            && implementation_receipt["question_class"] == "equivalence_non_inferiority"
            && implementation_receipt["gate_path"]
                == "tests/test_qsdk_r23d63_authorization_receipt_schema.ps1"
            && implementation_receipt["producer_ids"]
                == json!(["godot_jolt", "rapier_parry", "mujoco"])
            && implementation_receipt["declared_producer_count"] == 3
            && implementation_receipt["conforming_producer_count"] == 3
            && implementation_receipt["required_field"]
                == "complete_ordered_nine_cell_matrix_validated"
            && implementation_receipt["required_json_type"] == "boolean"
            && implementation_receipt["required_value"] == true
            && implementation_receipt["equivalence_margin"] == 0
            && implementation_receipt["non_inferiority_margin"] == 0
            && implementation_receipt["sampling_used"] == false
            && implementation_receipt["actual_production_composer_invoked_per_engine"] == true
            && implementation_receipt["total_negative_control_count"] == 12
            && implementation_receipt["negative_controls_passed"] == 12
            && implementation_receipt["runtime_dependency_question_class"]
                == "equivalence_non_inferiority"
            && implementation_receipt["runtime_dependency_population"]
                == "complete_locked_mujoco_python_environment"
            && implementation_receipt["runtime_dependency_lock_path"]
                == "sdk/adapters/mujoco/requirements-lock.txt"
            && implementation_receipt["runtime_dependency_lock_raw_sha256"]
                == "sha256:1c4da4ba7964874fc55c8e16b60d1c6114f40e598f402fb2db1bb6a703b37603"
            && implementation_receipt["runtime_dependency_distribution_count"] == 9
            && implementation_receipt["runtime_dependency_distribution_file_count"] == 8094
            && implementation_receipt["runtime_dependency_distribution_byte_count"] == 131440050
            && implementation_receipt["runtime_dependency_environment_manifest_sha256"]
                == "sha256:95ea9d7f02a82fc84f62b04cf3c3a7415b62ccab4d04cb56cd12df7cd7696f68"
            && implementation_receipt["runtime_dependency_mujoco_version"] == "3.11.0"
            && implementation_receipt["runtime_dependency_mujoco_module_raw_sha256"]
                == "sha256:131342cd035fa2022b8ea46e1380aaa80641ee1d983d65c427a694517c3c6790"
            && implementation_receipt["runtime_dependency_path_self_bound"] == true
            && implementation_receipt["caller_pythonpath_required"] == false
            && implementation_receipt["caller_pythonpath_independence_control_count"] == 2
            && implementation_receipt["caller_pythonpath_independence_controls_passed"] == 2
            && implementation_receipt["runtime_dependency_equivalence_margin"] == 0
            && implementation_receipt["runtime_dependency_non_inferiority_margin"] == 0
            && implementation_receipt["runtime_dependency_sampling_used"] == false
            && implementation_receipt["must_pass_before_physical_freeze"] == true
            && implementation_receipt["must_pass_before_attempt_authorization"] == true
            && implementation_receipt["world_attempt_count"] == 0
            && implementation_receipt["physical_equivalence_claimed"] == false
            && implementation_receipt["physical_acceptance_authority"] == false
            && implementation_receipt["passed"] == true;
        if !receipt_exact {
            return Err("QSDK_R23D63_RAP_RECEIPT_SCHEMA_CONTRACT_INVALID".to_owned());
        }
    }
    if generation == "r23d64" {
        let predecessor = &successor["predecessor_closure"];
        let change_budget = &successor["successor_change_budget"];
        let receipt = &successor["authorization_receipt_schema_conformance"];
        let launcher = &successor["rapier_launcher_contract_conformance"];
        let implementation_receipt = &implementation["authorization_receipt_schema_conformance"];
        let implementation_launcher = &implementation["rapier_launcher_contract_conformance"];
        let execution = &successor["implementation_and_execution_requirements"];
        let controls = &successor["required_zero_world_negative_controls"];
        let conformance_exact = predecessor["gate_id"] == R23D63_GATE_ID
            && predecessor["campaign_id"] == R23D63_CAMPAIGN_ID
            && predecessor["classification"]
                == "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation"
            && predecessor["campaign_identity_consumed"] == true
            && predecessor["physical_outcome_exposed"] == false
            && predecessor["world_attempt_count"] == 0
            && predecessor["world_build_count"] == 0
            && predecessor["same_identity_repair_or_rerun_permitted"] == false
            && change_budget["allowed_mechanism_changes"]
                == json!([
                    "namespaced_r23d64_rapier_campaign_contract_registration",
                    "shared_rapier_supervisor_launch_argument_builder",
                    "exact_authorization_and_physical_supervisor_vectors_exercised_through_production_parser_pre_freeze",
                    "production_parser_negative_controls_for_campaign_seed_alias_missing_duplicate_and_wrong_type_seed_forms",
                ])
            && change_budget["selected_public_profile_preserved"] == true
            && change_budget["controller_and_policy_semantics_preserved"] == true
            && change_budget["physics_and_native_engine_bindings_preserved"] == true
            && change_budget["common_physical_thresholds_preserved"] == true
            && change_budget["turning_thresholds_preserved"] == true
            && change_budget["selector_evaluator_and_interpretation_preserved"] == true
            && receipt["question_class"] == "equivalence_non_inferiority"
            && receipt["declared_producer_count"] == 3
            && receipt["required_conforming_producer_count"] == 3
            && receipt["producer_ids"] == json!(["godot_jolt", "rapier_parry", "mujoco"])
            && receipt["required_field"] == "complete_ordered_nine_cell_matrix_validated"
            && receipt["required_json_type"] == "boolean"
            && receipt["required_value"] == true
            && receipt["equivalence_margin"] == 0
            && receipt["non_inferiority_margin"] == 0
            && receipt["sampling_used"] == false
            && receipt["total_negative_control_count"] == 12
            && receipt["must_pass_before_physical_freeze"] == true
            && receipt["must_pass_before_attempt_authorization"] == true
            && receipt["physical_equivalence_claimed"] == false
            && launcher["question_class"] == "equivalence_non_inferiority"
            && launcher["population"] == "complete_two_supervisor_rapier_production_call_sites"
            && launcher["declared_call_site_count"] == 2
            && launcher["required_conforming_call_site_count"] == 2
            && launcher["required_shared_builder_count"] == 1
            && launcher["required_seed_option"] == "--seed"
            && launcher["forbidden_seed_alias"] == "--campaign-seed"
            && launcher["exact_vectors_executed_through_production_parser"] == 2
            && launcher["required_parser_negative_control_count"] == 6
            && launcher["equivalence_margin"] == 0
            && launcher["non_inferiority_margin"] == 0
            && launcher["sampling_used"] == false
            && launcher["must_pass_before_physical_freeze"] == true
            && launcher["must_pass_before_attempt_authorization"] == true
            && launcher["physical_equivalence_claimed"] == false
            && execution["authorization_receipt_schema_conformance_gate_required"] == true
            && execution["authorization_receipt_schema_conformance_gate_must_precede_freeze"]
                == true
            && execution["authorization_receipt_schema_conformance_gate_must_precede_attempt_authorization"]
                == true
            && execution["rapier_launcher_contract_conformance_gate_required"] == true
            && execution["rapier_launcher_complete_call_site_population_required"] == true
            && execution["rapier_launcher_exact_vectors_must_reach_production_parser_before_freeze"]
                == true
            && execution["rapier_launcher_contract_gate_must_precede_attempt_authorization"]
                == true
            && controls["authorization_receipt_complete_matrix_field_missing_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_false_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_wrong_type_rejected_per_engine"]
                == true
            && controls["authorization_receipt_complete_matrix_field_alias_rejected_per_engine"]
                == true
            && controls["rapier_campaign_seed_alias_rejected_for_authorization_and_physical_vectors"]
                == true
            && controls["rapier_duplicate_seed_rejected"] == true
            && controls["rapier_missing_seed_rejected"] == true
            && controls["rapier_wrong_type_seed_rejected"] == true
            && controls["rapier_underscore_seed_alias_rejected"] == true
            && implementation_receipt["question_class"] == "equivalence_non_inferiority"
            && implementation_receipt["gate_path"]
                == "tests/test_qsdk_r23d64_authorization_receipt_schema.ps1"
            && implementation_receipt["producer_ids"]
                == json!(["godot_jolt", "rapier_parry", "mujoco"])
            && implementation_receipt["declared_producer_count"] == 3
            && implementation_receipt["conforming_producer_count"] == 3
            && implementation_receipt["total_negative_control_count"] == 12
            && implementation_receipt["negative_controls_passed"] == 12
            && implementation_receipt["must_pass_before_physical_freeze"] == true
            && implementation_receipt["must_pass_before_attempt_authorization"] == true
            && implementation_receipt["world_attempt_count"] == 0
            && implementation_receipt["physical_equivalence_claimed"] == false
            && implementation_receipt["physical_acceptance_authority"] == false
            && implementation_receipt["passed"] == true
            && implementation_launcher["question_class"] == "equivalence_non_inferiority"
            && implementation_launcher["population"]
                == "complete_two_supervisor_rapier_production_call_sites"
            && implementation_launcher["contract_path"]
                == "sdk/turning/r23d64_rapier_launcher_contract.ps1"
            && implementation_launcher["gate_path"]
                == "tests/test_qsdk_r23d64_rapier_launcher_contract.ps1"
            && implementation_launcher["supervisor_rapier_production_call_site_count"] == 2
            && implementation_launcher["conforming_call_site_count"] == 2
            && implementation_launcher["population_compared_completely"] == true
            && implementation_launcher["required_seed_option"] == "--seed"
            && implementation_launcher["forbidden_seed_alias"] == "--campaign-seed"
            && implementation_launcher["shared_builder_count"] == 1
            && implementation_launcher["exact_vectors_executed_through_production_parser"] == 2
            && implementation_launcher["negative_control_count"] == 6
            && implementation_launcher["negative_controls_passed"] == 6
            && implementation_launcher["equivalence_margin"] == 0
            && implementation_launcher["non_inferiority_margin"] == 0
            && implementation_launcher["sampling_used"] == false
            && implementation_launcher["must_pass_before_physical_freeze"] == true
            && implementation_launcher["must_pass_before_attempt_authorization"] == true
            && implementation_launcher["world_attempt_count"] == 0
            && implementation_launcher["physical_equivalence_claimed"] == false
            && implementation_launcher["physical_acceptance_authority"] == false
            && implementation_launcher["passed"] == true;
        if !conformance_exact {
            return Err("QSDK_R23D64_RAP_CONFORMANCE_CONTRACT_INVALID".to_owned());
        }
    }
    if generation == "r23d65" {
        let predecessor = &successor["predecessor_closure"];
        let change_budget = &successor["successor_change_budget"];
        let runtime = &successor["runtime_integration_conformance"];
        let implementation_runtime = &implementation["runtime_integration_conformance"];
        let execution = &successor["implementation_and_execution_requirements"];
        let controls = &successor["required_zero_world_negative_controls"];
        let conformance_exact = predecessor["gate_id"] == R23D64_GATE_ID
            && predecessor["campaign_id"] == R23D64_CAMPAIGN_ID
            && predecessor["classification"]
                == "invalid_or_incomplete_exact_matched_three_engine_portable_turning_validation"
            && predecessor["campaign_identity_consumed"] == true
            && predecessor["physical_outcome_exposed"] == true
            && predecessor["held_out_seed_physical_outcome_exposed"] == true
            && predecessor["model_construction_count_lower_bound"] == 6
            && predecessor["world_attempt_count"] == 6
            && predecessor["world_build_count"] == 6
            && predecessor["execution_valid_cell_count"] == 0
            && predecessor["turning_evaluated_cell_count"] == 0
            && predecessor["complete_evaluation_created"] == false
            && predecessor["turning_result_observed"] == false
            && predecessor["same_identity_repair_or_rerun_permitted"] == false
            && change_budget["allowed_mechanism_changes"]
                == json!([
                    "namespaced_r23d65_rapier_campaign_contract_registration",
                    "godot_public_profile_binding_before_scene_tree_insertion_on_exact_carried_hinges",
                    "shared_trace_cas_child_powershell_execution_policy_bypass",
                    "mujoco_inherited_private_preflight_bridge_binding",
                    "complete_worker_failure_terminal_identity_projection",
                    "supervisor_observed_terminal_normalization_and_world_count_preservation",
                    "complete_evaluator_three_engine_failure_terminal_canaries",
                ])
            && change_budget["selected_public_profile_preserved"] == true
            && change_budget["controller_and_policy_semantics_preserved"] == true
            && change_budget["physics_and_native_engine_bindings_preserved"] == true
            && change_budget["schedule_task_origin_startup_and_measurement_preserved"] == true
            && change_budget["common_physical_thresholds_preserved"] == true
            && change_budget["turning_thresholds_preserved"] == true
            && change_budget["selector_evaluator_and_interpretation_preserved"] == true
            && change_budget["historical_result_or_interpretation_rewritten"] == false
            && runtime["question_class"] == "equivalence_non_inferiority"
            && runtime["population"]
                == "complete_seven_r23d65_successor_obligations_derived_from_observed_r23d64_runtime_failures"
            && runtime["declared_obligation_count"] == 7
            && runtime["required_conforming_obligation_count"] == 7
            && runtime["ordered_obligation_ids"]
                == json!([
                    "rapier_campaign_registration",
                    "godot_preworld_exact_hinge_binding_and_carry",
                    "rapier_worker_evaluator_powershell_cas_chain",
                    "mujoco_inherited_physical_entry_preflight_bridge",
                    "worker_failure_terminal_complete_identity",
                    "supervisor_terminal_preservation_and_normalization",
                    "complete_evaluator_failure_terminal_acceptance",
                ])
            && runtime["equivalence_margin"] == 0
            && runtime["non_inferiority_margin"] == 0
            && runtime["sampling_used"] == false
            && runtime["must_pass_before_physical_freeze"] == true
            && runtime["must_pass_before_attempt_authorization"] == true
            && runtime["physical_equivalence_claimed"] == false
            && implementation_runtime["question_class"] == "equivalence_non_inferiority"
            && implementation_runtime["population"] == runtime["population"]
            && implementation_runtime["gate_path"]
                == "tests/test_qsdk_r23d65_runtime_integration.ps1"
            && implementation_runtime["canary_path"]
                == "sdk/turning/r23d65_runtime_integration_conformance.py"
            && implementation_runtime["ordered_obligation_ids"]
                == runtime["ordered_obligation_ids"]
            && implementation_runtime["declared_obligation_count"] == 7
            && implementation_runtime["conforming_obligation_count"] == 7
            && implementation_runtime["equivalence_margin"] == 0
            && implementation_runtime["non_inferiority_margin"] == 0
            && implementation_runtime["sampling_used"] == false
            && implementation_runtime["complete_worker_failure_terminal_engine_count"] == 3
            && implementation_runtime["complete_evaluator_failure_terminal_cell_count"] == 9
            && implementation_runtime["supervisor_terminal_conforming_engine_count"] == 3
            && implementation_runtime["must_pass_before_physical_freeze"] == true
            && implementation_runtime["must_pass_before_attempt_authorization"] == true
            && implementation_runtime["world_attempt_count"] == 0
            && implementation_runtime["world_build_count"] == 0
            && implementation_runtime["physical_equivalence_claimed"] == false
            && implementation_runtime["physical_acceptance_authority"] == false
            && implementation_runtime["passed"] == true
            && execution["runtime_integration_conformance_gate_required"] == true
            && execution["runtime_integration_complete_obligation_population_required"] == true
            && execution["runtime_integration_gate_must_precede_freeze"] == true
            && execution["runtime_integration_gate_must_precede_attempt_authorization"] == true
            && controls["failure_terminal_missing_identity_rejected_per_engine"] == true
            && controls["failure_terminal_world_count_loss_rejected"] == true
            && controls["supervisor_wrong_identity_or_missing_world_count_rejected"] == true;
        if !conformance_exact {
            return Err("QSDK_R23D65_RAP_RUNTIME_INTEGRATION_CONTRACT_INVALID".to_owned());
        }
    }
    r23d27_initial_perturbation(campaign, successor)?;
    Ok(())
}

fn r23d27_contract(campaign: &R23D27CampaignContract) -> Result<Value, String> {
    let successor: Value = serde_json::from_str(campaign.preregistration_raw)
        .map_err(|error| format!("QSDK_R23D27_RAP_SUCCESSOR_CONTRACT_JSON_INVALID:{error}"))?;
    let implementation_path = r23d3_repo_root()?.join(campaign.implementation_path);
    let implementation: Value = serde_json::from_slice(
        &fs::read(implementation_path)
            .map_err(|error| format!("QSDK_R23D27_RAP_IMPLEMENTATION_UNREADABLE:{error}"))?,
    )
    .map_err(|error| format!("QSDK_R23D27_RAP_IMPLEMENTATION_JSON_INVALID:{error}"))?;
    if is_selected_profile_campaign(campaign) {
        let generation = if campaign.gate_id == R23D62_GATE_ID {
            "r23d62"
        } else if campaign.gate_id == R23D63_GATE_ID {
            "r23d63"
        } else if campaign.gate_id == R23D64_GATE_ID {
            "r23d64"
        } else if campaign.gate_id == R23D65_GATE_ID {
            "r23d65"
        } else {
            return Err("QSDK_R23D27_RAP_SELECTED_PROFILE_CAMPAIGN_INVALID".to_owned());
        };
        selected_profile_contract_exact(campaign, &successor, &implementation, generation)?;
        return Ok(successor);
    }
    if campaign.gate_id == R23D50_GATE_ID {
        let lineage = &successor["immutable_lineage"];
        let repair = &successor["implementation_repair_boundary"];
        let candidate = &successor["candidate"];
        let matrix = &successor["frozen_matrix"];
        let measurement = &successor["cycle_integrated_measurement"];
        let gates = &successor["frozen_common_physical_gates"];
        let retention = &successor["production_trace_retention_gate"];
        let evidence = &successor["evidence"];
        let repo_root = r23d3_repo_root()?;
        let predecessor_hash = fs::read(
            repo_root.join("sdk/turning/r23d49_rapier_retention_repair_replay_closure_v1.json"),
        )
        .map(|bytes| raw_sha256(&bytes))
        .map_err(|error| format!("QSDK_R23D50_RAP_LINEAGE_UNREADABLE:{error}"))?;
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["status"] == "prospective_zero_world_only"
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["study_classification"] == campaign.study_classification
            && lineage["r23d49_closure_raw_sha256"] == predecessor_hash
            && lineage["r23d49_identity_consumed"] == true
            && lineage["r23d49_same_identity_rerun_permitted"] == false
            && lineage["r23d49_rapier_worlds_completed_and_traces_retained"] == true
            && lineage["r23d49_outcomes_exposed_before_this_preregistration"] == true
            && lineage["r23d49_postfailure_diagnostic_reinterpreted_as_official"] == false
            && lineage["historical_world_reused_as_a_new_cell"] == false
            && lineage["same_identity_rerun_permitted"] == false
            && repair["single_permitted_change"]
                == "Compare each existing CAS payload and manifest path with os.path.samefile instead of textual Path equality."
            && repair["complete_cas_binding_verifier_required_before_first_world"] == true
            && repair["ordinary_and_windows_extended_same_file_positive_control_required"] == true
            && repair["wrong_existing_file_negative_control_required"] == true
            && repair["exact_rust_to_python_to_powershell_to_cas_canary_required_before_first_world"]
                == true
            && repair["synthetic_trace_row_count"] == R23D27_CONTROLLER_STEPS
            && repair["controller_behavior_changed"] == false
            && repair["physics_or_adapter_actuation_changed"] == false
            && repair["startup_transform_changed"] == false
            && repair["fixture_or_seed_changed"] == false
            && repair["command_schedule_changed"] == false
            && repair["measurement_changed"] == false
            && repair["physical_threshold_changed"] == false
            && repair["other_implementation_changes_permitted"] == false
            && candidate["candidate_id"] == campaign.candidate_id
            && candidate["controller_policy_id"] == campaign.controller_policy_id
            && candidate["minimum_steering_fraction"] == 0.20
            && candidate["maximum_steering_fraction"] == 0.28
            && candidate["steering_guard_floor_hold_steps"] == 144
            && candidate["engine_specific_parameters"] == false
            && matrix["stage_id"] == campaign.stage_id
            && matrix["ordered_engine_ids"] == json!([R23D27_ENGINE_ID])
            && matrix["ordered_candidate_ids"] == json!([campaign.candidate_id])
            && matrix["ordered_arm_ids"]
                == json!(["reference_zero", "positive_heading", "negative_heading"])
            && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
            && matrix["declared_cell_count"] == 3
            && matrix["declared_world_count"] == 3
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["seed_was_outcome_exposed_before_preregistration"] == true
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["startup_transform_id"] == R23D48_STARTUP_TRANSFORM_ID
            && matrix["startup_probe_step_count"] == R23D48_PROBE_LAST_SEMANTIC_STEP + 1
            && matrix["conditional_ramp_step_count_if_triggered"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["recovery_duration_steps"] == 600
            && matrix["terminal_restoration_or_taper_invoked"] == false
            && measurement["inherited_unchanged_from_r23d31"] == true
            && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
            && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
            && measurement["both_signed_arms_required"] == true
            && measurement["reference_arm_required"] == true
            && measurement["threshold_changed_from_r23d49"] == false
            && gates["minimum_final_forward_displacement_m"] == 0.030123046875
            && gates["maximum_tilt_rad"] == 0.6
            && gates["minimum_torso_height_m"] == 0.2499708652072946
            && gates["minimum_contact_cycles_per_limb"] == 2
            && gates["exact_startup_transform_composition_required"] == true
            && gates["terminal_quiescent_taper_required"] == false
            && retention["required_before_first_world"] == true
            && retention["model_construction_count"] == 0
            && retention["world_build_count"] == 0
            && retention["synthetic_trace_row_count"] == R23D27_CONTROLLER_STEPS
            && retention["exact_rust_to_python_to_powershell_to_artifact_store_route_required"]
                == true
            && retention["process_scoped_execution_policy_bypass_required"] == true
            && retention["complete_cas_binding_verifier_exercised_required"] == true
            && retention["ordinary_and_windows_extended_path_positive_control_count"] == 1
            && retention["wrong_existing_file_rejection_count"] == 1
            && retention["pinned_publisher_source_required"] == true
            && retention["expected_digest_and_byte_length_verification_required"] == true
            && retention["production_evidence_root_required"] == true
            && retention["test_only_artifact_forbidden"] == true
            && retention["publisher_maximum_attempt_count"] == 3
            && evidence["clean_pushed_live_source_required"] == true
            && evidence["campaign_local_lca1_qualification_required"] == true
            && evidence["positive_production_authorization_preflight_required_per_cell"] == true
            && evidence["authorization_preflight_must_return_before_model_or_world"] == true
            && evidence["same_identity_rerun_allowed"] == false
            && successor["claims"]["finite_outcome_exposed_rapier_cas_path_identity_replay"]
                == false
            && successor["claims"]["fresh_rapier_turning_replication"] == false
            && successor["claims"]["finite_three_engine_turning"] == false
            && successor["claims"]["cross_engine_equivalence"] == false
            && successor["claims"]["release_authorized"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["status"] == "prospective_zero_world_only"
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["worker"]["engine_id"] == R23D27_ENGINE_ID
            && implementation["worker"]["controller_policy_id"] == campaign.controller_policy_id
            && implementation["worker"]["controller_behavior_changed_from_r23d49"] == false
            && implementation["worker"]["physics_or_adapter_actuation_changed_from_r23d49"]
                == false
            && implementation["worker"]["measurement_changed_from_r23d49"] == false
            && implementation["worker"]["startup_transform_changed_from_r23d49"] == false
            && implementation["worker"]["physical_threshold_changed_from_r23d49"] == false
            && implementation["worker"]["campaign_seed"] == campaign.campaign_seed
            && implementation["worker"]["uses_outcome_exposed_r23d49_perturbation"] == true
            && implementation["worker"]["terminal_taper_invoked"] == false
            && implementation["worker"]["positive_production_authorization_preflight_required_per_cell"]
                == true
            && implementation["worker"]["authorization_preflight_returns_before_model_or_world"]
                == true
            && implementation["worker"]["world_builds_during_preflight"] == 0
            && implementation["trace_retention"]["process_scoped_execution_policy"] == "Bypass"
            && implementation["trace_retention"]["complete_cas_binding_uses_filesystem_identity"]
                == true
            && implementation["trace_retention"]["ordinary_and_windows_extended_same_file_positive_control_required"]
                == true
            && implementation["trace_retention"]["wrong_existing_file_negative_control_required"]
                == true
            && implementation["trace_retention"]["preworld_production_canary_required"] == true
            && implementation["trace_retention"]["preworld_production_canary_route"]
                == "rust_worker_to_python_evaluator_to_powershell_publisher_to_cas_to_complete_binding_verifier_v1"
            && implementation["trace_retention"]["preworld_production_canary_row_count"]
                == R23D27_CONTROLLER_STEPS
            && implementation["trace_retention"]["preworld_production_canary_model_count"] == 0
            && implementation["trace_retention"]["preworld_production_canary_world_count"] == 0
            && implementation["evaluation"]["ordered_cell_count"] == 3
            && implementation["evaluation"]["outcome_aware_early_stop_permitted"] == false
            && implementation["evaluation"]["outcome_exposed_replay"] == true
            && implementation["source_binding_policy"]["source_bytes_consumed_by_build_must_equal_git_blobs"]
                == true
            && implementation["source_binding_policy"]["campaign_source_family_checkout_lf_pinned"]
                == true
            && implementation["source_binding_policy"]["ambient_checkout_is_not_build_authority"]
                == true;
        if !exact {
            return Err("QSDK_R23D50_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    if campaign.gate_id == R23D49_GATE_ID {
        let lineage = &successor["immutable_lineage"];
        let repair = &successor["implementation_repair_boundary"];
        let candidate = &successor["candidate"];
        let matrix = &successor["frozen_matrix"];
        let measurement = &successor["cycle_integrated_measurement"];
        let gates = &successor["frozen_common_physical_gates"];
        let retention = &successor["production_trace_retention_gate"];
        let evidence = &successor["evidence"];
        let repo_root = r23d3_repo_root()?;
        let predecessor_hash = fs::read(repo_root.join(
            "sdk/turning/r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json",
        ))
        .map(|bytes| raw_sha256(&bytes))
        .map_err(|error| format!("QSDK_R23D49_RAP_LINEAGE_UNREADABLE:{error}"))?;
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["status"] == "prospective_zero_world_only"
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["study_classification"] == campaign.study_classification
            && lineage["r23d48_closure_raw_sha256"] == predecessor_hash
            && lineage["r23d48_identity_consumed"] == true
            && lineage["r23d48_same_identity_rerun_permitted"] == false
            && lineage["r23d48_rapier_worlds_completed_before_publication_failure"] == true
            && lineage["r23d48_rapier_outcomes_exposed_before_this_preregistration"] == true
            && lineage["historical_world_reused_as_a_new_cell"] == false
            && lineage["same_identity_rerun_permitted"] == false
            && repair["single_permitted_change"]
                == "Invoke the exact pinned publisher with -ExecutionPolicy Bypass in that child process only."
            && repair["exact_rust_to_python_to_powershell_to_cas_canary_required_before_first_world"]
                == true
            && repair["synthetic_trace_row_count"] == R23D27_CONTROLLER_STEPS
            && repair["controller_behavior_changed"] == false
            && repair["physics_or_adapter_actuation_changed"] == false
            && repair["startup_transform_changed"] == false
            && repair["fixture_or_seed_changed"] == false
            && repair["command_schedule_changed"] == false
            && repair["measurement_changed"] == false
            && repair["physical_threshold_changed"] == false
            && repair["other_implementation_changes_permitted"] == false
            && candidate["candidate_id"] == campaign.candidate_id
            && candidate["controller_policy_id"] == campaign.controller_policy_id
            && candidate["minimum_steering_fraction"] == 0.20
            && candidate["maximum_steering_fraction"] == 0.28
            && candidate["steering_guard_floor_hold_steps"] == 144
            && candidate["engine_specific_parameters"] == false
            && matrix["stage_id"] == campaign.stage_id
            && matrix["ordered_engine_ids"] == json!([R23D27_ENGINE_ID])
            && matrix["ordered_candidate_ids"] == json!([campaign.candidate_id])
            && matrix["ordered_arm_ids"]
                == json!(["reference_zero", "positive_heading", "negative_heading"])
            && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
            && matrix["declared_cell_count"] == 3
            && matrix["declared_world_count"] == 3
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["seed_was_outcome_exposed_before_preregistration"] == true
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["startup_transform_id"] == R23D48_STARTUP_TRANSFORM_ID
            && matrix["startup_probe_step_count"] == R23D48_PROBE_LAST_SEMANTIC_STEP + 1
            && matrix["conditional_ramp_step_count_if_triggered"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["recovery_duration_steps"] == 600
            && matrix["terminal_restoration_or_taper_invoked"] == false
            && measurement["inherited_unchanged_from_r23d31"] == true
            && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
            && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
            && measurement["both_signed_arms_required"] == true
            && measurement["reference_arm_required"] == true
            && measurement["threshold_changed_from_r23d48"] == false
            && gates["minimum_final_forward_displacement_m"] == 0.030123046875
            && gates["maximum_tilt_rad"] == 0.6
            && gates["minimum_torso_height_m"] == 0.2499708652072946
            && gates["minimum_contact_cycles_per_limb"] == 2
            && gates["exact_startup_transform_composition_required"] == true
            && gates["terminal_quiescent_taper_required"] == false
            && retention["required_before_first_world"] == true
            && retention["model_construction_count"] == 0
            && retention["world_build_count"] == 0
            && retention["synthetic_trace_row_count"] == R23D27_CONTROLLER_STEPS
            && retention["exact_rust_to_python_to_powershell_to_artifact_store_route_required"]
                == true
            && retention["process_scoped_execution_policy_bypass_required"] == true
            && retention["pinned_publisher_source_required"] == true
            && retention["expected_digest_and_byte_length_verification_required"] == true
            && retention["production_evidence_root_required"] == true
            && retention["test_only_artifact_forbidden"] == true
            && retention["publisher_maximum_attempt_count"] == 3
            && evidence["clean_pushed_live_source_required"] == true
            && evidence["campaign_local_lca1_qualification_required"] == true
            && evidence["positive_production_authorization_preflight_required_per_cell"] == true
            && evidence["authorization_preflight_must_return_before_model_or_world"] == true
            && evidence["same_identity_rerun_allowed"] == false
            && successor["claims"]["finite_outcome_exposed_rapier_retention_repair_replay"]
                == false
            && successor["claims"]["fresh_rapier_turning_replication"] == false
            && successor["claims"]["finite_three_engine_turning"] == false
            && successor["claims"]["cross_engine_equivalence"] == false
            && successor["claims"]["release_authorized"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["status"] == "prospective_zero_world_only"
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["worker"]["engine_id"] == R23D27_ENGINE_ID
            && implementation["worker"]["controller_policy_id"] == campaign.controller_policy_id
            && implementation["worker"]["controller_behavior_changed_from_r23d48"] == false
            && implementation["worker"]["physics_or_adapter_actuation_changed_from_r23d48"]
                == false
            && implementation["worker"]["measurement_changed_from_r23d48"] == false
            && implementation["worker"]["startup_transform_changed_from_r23d48"] == false
            && implementation["worker"]["physical_threshold_changed_from_r23d48"] == false
            && implementation["worker"]["campaign_seed"] == campaign.campaign_seed
            && implementation["worker"]["uses_outcome_exposed_r23d48_perturbation"] == true
            && implementation["worker"]["terminal_taper_invoked"] == false
            && implementation["worker"]["positive_production_authorization_preflight_required_per_cell"]
                == true
            && implementation["worker"]["authorization_preflight_returns_before_model_or_world"]
                == true
            && implementation["worker"]["world_builds_during_preflight"] == 0
            && implementation["trace_retention"]["process_scoped_execution_policy"] == "Bypass"
            && implementation["trace_retention"]["preworld_production_canary_required"] == true
            && implementation["trace_retention"]["preworld_production_canary_route"]
                == "rust_worker_to_python_evaluator_to_powershell_publisher_to_cas_v1"
            && implementation["trace_retention"]["preworld_production_canary_row_count"]
                == R23D27_CONTROLLER_STEPS
            && implementation["trace_retention"]["preworld_production_canary_model_count"] == 0
            && implementation["trace_retention"]["preworld_production_canary_world_count"] == 0
            && implementation["evaluation"]["ordered_cell_count"] == 3
            && implementation["evaluation"]["outcome_aware_early_stop_permitted"] == false
            && implementation["evaluation"]["outcome_exposed_replay"] == true
            && implementation["source_binding_policy"]["source_bytes_consumed_by_build_must_equal_git_blobs"]
                == true
            && implementation["source_binding_policy"]["campaign_source_family_checkout_lf_pinned"]
                == true
            && implementation["source_binding_policy"]["ambient_checkout_is_not_build_authority"]
                == true;
        if !exact {
            return Err("QSDK_R23D49_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    if campaign.gate_id == R23D48_GATE_ID {
        let lineage = &successor["immutable_lineage"];
        let distinct = &successor["scientifically_distinct_successor"];
        let matrix = &successor["frozen_matrix"];
        let candidate = &successor["candidate"];
        let measurement = &successor["cycle_integrated_measurement"];
        let gates = &successor["frozen_common_physical_gates"];
        let entry = &successor["zero_world_entry_gate"];
        let repo_root = r23d3_repo_root()?;
        let lineage_hash = |path: &str| -> Result<String, String> {
            fs::read(repo_root.join(path))
                .map(|bytes| raw_sha256(&bytes))
                .map_err(|error| format!("QSDK_R23D48_RAP_LINEAGE_UNREADABLE:{path}:{error}"))
        };
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["status"] == "prospective_zero_world_only"
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["study_classification"] == campaign.study_classification
            && lineage["r23d42_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d42_three_engine_startup_ramp_turning_closure_v1.json",
                )?
            && lineage["r23d44_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d44_rapier_paired_startup_transform_closure_v1.json",
                )?
            && lineage["r23d47_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d47_support_loss_conditioned_startup_closure_v1.json",
                )?
            && lineage["measurement_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d31_cycle_integrated_directional_response_closure_v1.json",
                )?
            && lineage["historical_result_reinterpreted"] == false
            && lineage["historical_world_reused_as_a_new_cell"] == false
            && lineage["same_identity_rerun_permitted"] == false
            && distinct["fresh_held_out_seed"] == campaign.campaign_seed
            && distinct["seed_outcome_exposed_before_preregistration"] == false
            && distinct["controller_policy_id"] == campaign.controller_policy_id
            && distinct["controller_behavior_changed"] == false
            && distinct["measurement_changed"] == false
            && distinct["threshold_changed"] == false
            && distinct["startup_transform_id"] == R23D48_STARTUP_TRANSFORM_ID
            && distinct["startup_transform_applied_to_all_engines_and_arms"] == true
            && distinct["startup_probe_first_semantic_step"] == 0
            && distinct["startup_probe_last_semantic_step"] == R23D48_PROBE_LAST_SEMANTIC_STEP
            && distinct["trigger_latched_for_remainder_of_run"] == true
            && distinct["engine_identity_input_count"] == 0
            && distinct["arm_identity_input_count"] == 0
            && distinct["command_sign_branching_permitted"] == false
            && candidate["candidate_id"] == campaign.candidate_id
            && candidate["controller_policy_id"] == campaign.controller_policy_id
            && candidate["minimum_steering_fraction"] == 0.20
            && candidate["maximum_steering_fraction"] == 0.28
            && candidate["steering_guard_floor_hold_steps"] == 144
            && candidate["engine_specific_parameters"] == false
            && matrix["stage_id"] == campaign.stage_id
            && matrix["ordered_engine_ids"] == json!(["rapier_parry", "godot_jolt", "mujoco"])
            && matrix["ordered_candidate_ids"] == json!([campaign.candidate_id])
            && matrix["ordered_arm_ids"]
                == json!(["reference_zero", "positive_heading", "negative_heading"])
            && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
            && matrix["declared_cell_count"] == 9
            && matrix["declared_world_count"] == 9
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["startup_transform_id"] == R23D48_STARTUP_TRANSFORM_ID
            && matrix["startup_probe_step_count"] == R23D48_PROBE_LAST_SEMANTIC_STEP + 1
            && matrix["conditional_ramp_step_count_if_triggered"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["recovery_duration_steps"] == 600
            && matrix["terminal_restoration_or_taper_invoked"] == false
            && measurement["inherited_unchanged_from_r23d31"] == true
            && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
            && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
            && measurement["both_signed_arms_required"] == true
            && measurement["reference_arm_required"] == true
            && gates["minimum_final_forward_displacement_m"] == 0.030123046875
            && gates["maximum_tilt_rad"] == 0.6
            && gates["minimum_torso_height_m"] == 0.2499708652072946
            && gates["minimum_contact_cycles_per_limb"] == 2
            && gates["exact_startup_transform_composition_required"] == true
            && gates["terminal_quiescent_taper_required"] == false
            && entry["both_startup_transform_branches_and_cross_host_composition_required"] == true
            && entry["campaign_local_gates_plus_cep1_only"] == true
            && entry["historical_full_suite_required_per_attempt"] == false
            && entry["physical_execution_authorized"] == false
            && entry["world_build_count"] == 0
            && successor["selector"]["positive_qsdk_r23_satisfied"] == true
            && successor["selector"]["positive_cross_engine_equivalence"] == false
            && successor["claims"]["finite_three_engine_turning"] == false
            && successor["claims"]["q_sdk_r23_satisfied"] == false
            && successor["claims"]["cross_engine_equivalence"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["status"] == "prospective_zero_world_only"
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["fresh_seed"] == campaign.campaign_seed
            && implementation["declared_world_count"] == 9
            && implementation["portable_transform"]["transform_id"] == R23D48_STARTUP_TRANSFORM_ID
            && implementation["portable_transform"]["engine_identity_input_count"] == 0
            && implementation["portable_transform"]["arm_identity_input_count"] == 0
            && implementation["portable_transform"]["trigger_and_identity_branch_canaries_required_per_host"]
                == true
            && implementation["portable_transform"]["trace_replay_validation_required"] == true
            && implementation["workers"][R23D27_ENGINE_ID]
                == "sdk/adapters/rapier/src/bin/qsdk_r23d48_physical.rs"
            && implementation["supervisor"]["requires_clean_pushed_live_source"] == true
            && implementation["supervisor"]["requires_complete_campaign_local_zero_world_preflight"]
                == true
            && implementation["supervisor"]["serialized_worlds"] == true
            && implementation["supervisor"]["all_cells_run_regardless_of_intermediate_outcome"]
                == true
            && implementation["supervisor"]["matrix_authorization_immutable_before_first_world_required"]
                == true
            && implementation["supervisor"]["positive_exact_production_authorization_preflight_required_for_each_engine"]
                == true
            && implementation["supervisor"]["authorization_preflight_must_return_before_model_or_world"]
                == true
            && implementation["claims"]["implementation_complete"] == true
            && implementation["claims"]["physical_world_opened"] == false;
        if !exact {
            return Err("QSDK_R23D48_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    if campaign.gate_id == R23D44_GATE_ID {
        let lineage = &successor["immutable_lineage"];
        let paired = &successor["paired_causal_development"];
        let repair = &successor["implementation_repair_boundary"];
        let matrix = &successor["frozen_matrix"];
        let measurement = &successor["cycle_integrated_measurement"];
        let gates = &successor["frozen_common_physical_gates"];
        let retention = &successor["production_trace_retention_gate"];
        let evidence = &successor["evidence"];
        let repo_root = r23d3_repo_root()?;
        let lineage_hash = |path: &str| -> Result<String, String> {
            fs::read(repo_root.join(path))
                .map(|bytes| raw_sha256(&bytes))
                .map_err(|error| format!("QSDK_R23D44_RAP_LINEAGE_UNREADABLE:{path}:{error}"))
        };
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["status"] == "prospective_zero_world_only"
            && successor["study_classification"] == campaign.study_classification
            && lineage["r23d30_physical_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d30_cycle_coherent_directional_response_closure_v1.json",
                )?
            && lineage["r23d43_physical_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/turning/r23d43_rapier_retention_hardened_turning_closure_v1.json",
                )?
            && lineage["r23d43_startup_transform_diagnosis_closure_raw_sha256"]
                == lineage_hash(
                    "sdk/trace_analysis/r23d43_rapier_startup_transform_diagnosis_closure_v1.json",
                )?
            && lineage["r23d30_identity_consumed"] == true
            && lineage["r23d43_identity_consumed"] == true
            && lineage["same_identity_rerun_permitted"] == false
            && lineage["historical_result_reinterpreted"] == false
            && lineage["historical_world_reused_as_new_cell"] == false
            && lineage["diagnosis_found_seed_and_transform_confounded"] == true
            && lineage["diagnosis_authorized_only_a_paired_same_seed_development_successor"]
                == true
            && paired["campaign_seed"] == campaign.campaign_seed
            && paired["seed_was_outcome_exposed_before_preregistration"] == true
            && paired["fresh_or_held_out_condition"] == false
            && paired["validation_or_replication_study"] == false
            && paired["same_initial_perturbation_across_candidates"] == true
            && paired["sole_declared_candidate_difference"] == "startup_velocity_transform"
            && paired["ordered_candidate_ids"]
                == json!([R23D44_NO_RAMP_CANDIDATE_ID, R23D44_RAMP_CANDIDATE_ID])
            && paired["identity_transform_id"] == "none"
            && paired["canonical_startup_ramp_id"] == R23D40_STARTUP_RAMP_ID
            && paired["canonical_startup_ramp_step_count"] == R23D40_STARTUP_RAMP_STEPS
            && paired["controller_policy_id"] == campaign.controller_policy_id
            && paired["controller_behavior_changed"] == false
            && paired["measurement_changed"] == false
            && paired["threshold_changed"] == false
            && paired["physics_changed"] == false
            && paired["morphology_changed"] == false
            && paired["command_schedule_changed"] == false
            && paired["engine_specific_gait_logic_permitted"] == false
            && paired["engine_identity_input_to_controller_permitted"] == false
            && paired["command_sign_branching_permitted"] == false
            && paired["causal_scope"] == "exact_deterministic_seed_21504_only"
            && paired["population_or_cross_seed_inference_permitted"] == false
            && repair["windows_same_file_cas_verifier_repair"] == true
            && repair["path_text_equality_for_file_identity_forbidden"] == true
            && repair["ordinary_and_extended_windows_namespace_positive_control_required"] == true
            && repair["wrong_existing_file_negative_control_required"] == true
            && repair["complete_evaluator_cas_binding_function_exercised_before_first_world"]
                == true
            && repair["old_r23d43_official_result_repaired_or_reclassified"] == false
            && matrix["stage_id"] == campaign.stage_id
            && matrix["ordered_engine_ids"] == json!([R23D27_ENGINE_ID])
            && matrix["ordered_candidate_ids"]
                == json!([R23D44_NO_RAMP_CANDIDATE_ID, R23D44_RAMP_CANDIDATE_ID])
            && matrix["ordered_arm_ids"]
                == json!(["reference_zero", "positive_heading", "negative_heading"])
            && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
            && matrix["declared_cell_count"] == 6
            && matrix["declared_world_count"] == 6
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["recovery_duration_steps"] == 600
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["startup_ramp_step_count"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["startup_ramp_active_step_count"] == R23D40_STARTUP_RAMP_STEPS - 1
            && matrix["terminal_restoration_or_taper_invoked"] == false
            && measurement["inherited_unchanged_from_r23d31"] == true
            && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
            && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
            && measurement["both_signed_arms_required"] == true
            && measurement["reference_arm_required"] == true
            && measurement["threshold_changed_after_diagnosis"] == false
            && gates["terminal_quiescent_taper_required"] == false
            && gates["exact_candidate_startup_transform_composition_required"] == true
            && retention["required_before_first_world"] == true
            && retention["world_build_count"] == 0
            && retention["model_construction_count"] == 0
            && retention["synthetic_trace_count"] == 2
            && retention["synthetic_trace_row_count"] == 2 * R23D27_CONTROLLER_STEPS
            && retention["one_trace_per_candidate_required"] == true
            && retention["exact_evaluator_to_publisher_to_artifact_store_route_required"] == true
            && retention["complete_cas_binding_verifier_required"] == true
            && retention["production_evidence_root_required"] == true
            && retention["test_only_artifact_forbidden"] == true
            && retention["publisher_maximum_attempt_count"] == 3
            && retention["bounded_stdout_and_stderr_required_on_failure"] == true
            && evidence["clean_pushed_source_required"] == true
            && evidence["campaign_local_lca1_qualification_required"] == true
            && evidence["positive_production_authorization_preflight_required_per_cell"] == true
            && evidence["authorization_preflight_must_return_before_model_or_world"] == true
            && evidence["same_identity_rerun_allowed"] == false
            && successor["claims"]["paired_same_seed_startup_transform_effect_characterized"]
                == false
            && successor["claims"]["finite_rapier_turning_validation"] == false
            && successor["claims"]["portable_basic_turning"] == false
            && successor["claims"]["cross_engine_equivalence"] == false
            && successor["claims"]["release_authorized"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["status"] == "prospective_zero_world_only"
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["worker"]["engine_id"] == R23D27_ENGINE_ID
            && implementation["worker"]["controller_policy_id"] == campaign.controller_policy_id
            && implementation["worker"]["controller_behavior_changed"] == false
            && implementation["worker"]["measurement_changed"] == false
            && implementation["worker"]["threshold_changed"] == false
            && implementation["worker"]["physics_changed"] == false
            && implementation["worker"]["morphology_changed"] == false
            && implementation["worker"]["campaign_seed"] == campaign.campaign_seed
            && implementation["worker"]["candidate_count"] == 2
            && implementation["worker"]["ordered_candidate_ids"]
                == json!([R23D44_NO_RAMP_CANDIDATE_ID, R23D44_RAMP_CANDIDATE_ID])
            && implementation["worker"]["candidate_local_startup_transform_only"] == true
            && implementation["worker"]["terminal_taper_invoked"] == false
            && implementation["worker"]["captures_failed_child_stdout"] == true
            && implementation["worker"]["captures_failed_child_stderr"] == true
            && implementation["worker"]["positive_production_authorization_preflight_required_per_cell"]
                == true
            && implementation["worker"]["authorization_preflight_returns_before_model_or_world"]
                == true
            && implementation["worker"]["world_builds_during_preflight"] == 0
            && implementation["trace_retention"]["maximum_publication_attempt_count"] == 3
            && implementation["trace_retention"]["both_failure_streams_bounded_and_retained"]
                == true
            && implementation["trace_retention"]["preworld_production_canary_required"] == true
            && implementation["trace_retention"]["preworld_production_canary_trace_count"] == 2
            && implementation["trace_retention"]["preworld_production_canary_row_count"]
                == 2 * R23D27_CONTROLLER_STEPS
            && implementation["trace_retention"]["preworld_production_canary_world_count"] == 0
            && implementation["trace_retention"]["complete_cas_binding_verifier_exercised_before_first_world"]
                == true
            && implementation["evaluation"]["ordered_cell_count"] == 6
            && implementation["evaluation"]["outcome_aware_early_stop_permitted"] == false
            && implementation["evaluation"]["development_only"] == true
            && implementation["source_binding_policy"]["source_bytes_consumed_by_build_must_equal_git_blobs"]
                == true
            && implementation["source_binding_policy"]["campaign_source_family_checkout_lf_pinned"]
                == true
            && implementation["source_binding_policy"]["ambient_checkout_is_not_build_authority"]
                == true;
        if !exact {
            return Err("QSDK_R23D44_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    if campaign.gate_id == R23D43_GATE_ID {
        let lineage = &successor["immutable_lineage"];
        let distinct = &successor["scientifically_distinct_successor"];
        let matrix = &successor["frozen_matrix"];
        let measurement = &successor["cycle_integrated_measurement"];
        let gates = &successor["frozen_common_physical_gates"];
        let retention = &successor["production_trace_retention_gate"];
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["status"] == "prospective_zero_world_only"
            && successor["study_classification"] == campaign.study_classification
            && lineage["r23d42_identity_consumed"] == true
            && lineage["r23d42_same_identity_rerun_permitted"] == false
            && lineage["r23d42_outcome_reinterpreted"] == false
            && lineage["r23d42_worlds_reused_as_r23d43_cells"] == false
            && lineage["historical_result_reinterpreted"] == false
            && lineage["same_identity_rerun_permitted"] == false
            && distinct["fresh_held_out_seed"] == campaign.campaign_seed
            && distinct["fresh_held_out_condition_selected"] == true
            && distinct["outcome_exposed_before_preregistration"] == false
            && distinct["same_initial_condition_as_r23d42"] == false
            && distinct["controller_policy_id"] == campaign.controller_policy_id
            && distinct["controller_behavior_changed"] == false
            && distinct["measurement_changed"] == false
            && distinct["threshold_changed"] == false
            && distinct["physics_changed"] == false
            && distinct["morphology_changed"] == false
            && distinct["canonical_startup_transform_inherited_unchanged"] == true
            && distinct["startup_ramp_id"] == R23D40_STARTUP_RAMP_ID
            && distinct["startup_ramp_step_count"] == R23D40_STARTUP_RAMP_STEPS
            && distinct["engine_specific_gait_logic_permitted"] == false
            && distinct["engine_identity_input_to_controller_permitted"] == false
            && distinct["command_sign_branching_permitted"] == false
            && distinct["evidence_implementation_change_count"] == 5
            && distinct["evidence_implementation_changes"]
                .as_array()
                .is_some_and(|changes| changes.len() == 5)
            && matrix["stage_id"] == campaign.stage_id
            && matrix["ordered_engine_ids"] == json!([R23D27_ENGINE_ID])
            && matrix["ordered_candidate_ids"] == json!([campaign.candidate_id])
            && matrix["ordered_arm_ids"]
                == json!(["reference_zero", "positive_heading", "negative_heading"])
            && matrix["ordered_heading_offsets_rad"] == json!([0.0, 0.2, -0.2])
            && matrix["declared_cell_count"] == 3
            && matrix["declared_world_count"] == 3
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["recovery_duration_steps"] == 600
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["startup_ramp_id"] == R23D40_STARTUP_RAMP_ID
            && matrix["startup_ramp_step_count"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["startup_ramp_active_step_count"] == R23D40_STARTUP_RAMP_STEPS - 1
            && matrix["terminal_restoration_or_taper_invoked"] == false
            && measurement["inherited_unchanged_from_r23d31"] == true
            && measurement["minimum_raw_signed_cycle_shift_rad"] == 0.01
            && measurement["minimum_reference_conditioned_cycle_shift_rad"] == 0.01
            && measurement["both_signed_arms_required"] == true
            && measurement["reference_arm_required"] == true
            && gates["terminal_quiescent_taper_required"] == false
            && gates["exact_startup_ramp_composition_required"] == true
            && gates["inherited_unchanged_from_r23d42"] == true
            && retention["required_before_first_world"] == true
            && retention["world_build_count"] == 0
            && retention["model_construction_count"] == 0
            && retention["synthetic_trace_row_count"] == R23D27_CONTROLLER_STEPS
            && retention["exact_evaluator_to_publisher_to_artifact_store_route_required"] == true
            && retention["production_evidence_root_required"] == true
            && retention["test_only_artifact_forbidden"] == true
            && retention["publisher_maximum_attempt_count"] == 3
            && retention["bounded_stdout_and_stderr_required_on_failure"] == true
            && successor["evidence"]["clean_pushed_source_required"] == true
            && successor["evidence"]["campaign_local_lca1_qualification_required"] == true
            && successor["evidence"]["positive_production_authorization_preflight_required_per_cell"]
                == true
            && successor["evidence"]["authorization_preflight_must_return_before_model_or_world"]
                == true
            && successor["evidence"]["same_identity_rerun_allowed"] == false
            && successor["claims"]["finite_rapier_turning_replication"] == false
            && successor["claims"]["portable_basic_turning"] == false
            && successor["claims"]["cross_engine_equivalence"] == false
            && successor["claims"]["release_authorized"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["worker"]["engine_id"] == R23D27_ENGINE_ID
            && implementation["worker"]["controller_policy_id"] == campaign.controller_policy_id
            && implementation["worker"]["controller_behavior_changed_from_r23d42"] == false
            && implementation["worker"]["measurement_changed_from_r23d42"] == false
            && implementation["worker"]["startup_ramp_changed_from_r23d42"] == false
            && implementation["worker"]["campaign_seed"] == campaign.campaign_seed
            && implementation["worker"]["terminal_taper_invoked"] == false
            && implementation["worker"]["captures_failed_child_stdout"] == true
            && implementation["worker"]["captures_failed_child_stderr"] == true
            && implementation["worker"]["positive_production_authorization_preflight_required_per_cell"]
                == true
            && implementation["worker"]["authorization_preflight_returns_before_model_or_world"]
                == true
            && implementation["worker"]["world_builds_during_preflight"] == 0
            && implementation["trace_retention"]["maximum_publication_attempt_count"] == 3
            && implementation["trace_retention"]["both_failure_streams_bounded_and_retained"]
                == true
            && implementation["trace_retention"]["preworld_production_canary_required"] == true
            && implementation["trace_retention"]["preworld_production_canary_row_count"]
                == R23D27_CONTROLLER_STEPS
            && implementation["trace_retention"]["preworld_production_canary_world_count"] == 0
            && implementation["evaluation"]["ordered_cell_count"] == 3
            && implementation["evaluation"]["outcome_aware_early_stop_permitted"] == false
            && implementation["source_binding_policy"]["source_bytes_consumed_by_build_must_equal_git_blobs"]
                == true
            && implementation["source_binding_policy"]["campaign_source_family_checkout_lf_pinned"]
                == true
            && implementation["source_binding_policy"]["ambient_checkout_is_not_build_authority"]
                == true;
        if !exact {
            return Err("QSDK_R23D43_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    if campaign.startup_velocity_ramp {
        let matrix = &successor["frozen_matrix"];
        let candidate = &successor["candidate"];
        let gates = &successor["frozen_common_physical_gates"];
        let engines = matrix["ordered_engine_ids"].as_array();
        let exact = successor["schema_version"] == campaign.preregistration_schema
            && successor["campaign_id"] == campaign.campaign_id
            && successor["gate_id"] == campaign.gate_id
            && successor["release_gate_id"] == "QSDK-R23"
            && successor["status"] == "prospective_zero_world_only"
            && successor["study_classification"] == campaign.study_classification
            && successor["scientifically_distinct_successor"]["controller_policy_id"]
                == campaign.controller_policy_id
            && successor["scientifically_distinct_successor"]["controller_behavior_changed"]
                == false
            && successor["scientifically_distinct_successor"]["startup_ramp_id"]
                == R23D40_STARTUP_RAMP_ID
            && successor["scientifically_distinct_successor"]["startup_ramp_step_count"]
                == R23D40_STARTUP_RAMP_STEPS
            && successor["scientifically_distinct_successor"]["startup_ramp_applied_to_all_engines"]
                == true
            && successor["scientifically_distinct_successor"]["engine_specific_gait_logic_permitted"]
                == false
            && candidate["candidate_id"] == campaign.candidate_id
            && candidate["controller_policy_id"] == campaign.controller_policy_id
            && candidate["minimum_steering_fraction"] == 0.20
            && candidate["maximum_steering_fraction"] == 0.28
            && candidate["steering_guard_floor_hold_steps"] == 144
            && candidate["engine_specific_parameters"] == false
            && matrix["stage_id"] == campaign.stage_id
            && engines.is_some_and(|values| {
                values.len() == 3
                    && values[0] == R23D27_ENGINE_ID
                    && values[1] == "godot_jolt"
                    && values[2] == "mujoco"
            })
            && matrix["declared_cell_count"] == 9
            && matrix["declared_world_count"] == 9
            && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
            && matrix["settlement_step_count"] == SETTLE_STEPS
            && matrix["turn_start_step"] == TURN_START_STEP
            && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
            && matrix["serial_execution_required"] == true
            && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
            && matrix["seed"] == campaign.campaign_seed
            && matrix["startup_ramp_id"] == R23D40_STARTUP_RAMP_ID
            && matrix["startup_ramp_step_count"] == R23D40_STARTUP_RAMP_STEPS
            && matrix["startup_ramp_active_step_count"] == R23D40_STARTUP_RAMP_STEPS - 1
            && gates["terminal_quiescent_taper_required"] == false
            && gates["exact_startup_ramp_composition_required"] == true
            && successor["selector"]["positive_qsdk_r23_satisfied"] == true
            && successor["selector"]["positive_cross_engine_equivalence"] == false
            && successor["zero_world_entry_gate"]["physical_execution_authorized"] == false
            && successor["claims"]["finite_three_engine_turning"] == false
            && successor["claims"]["q_sdk_r23_satisfied"] == false
            && implementation["schema_version"] == campaign.implementation_schema
            && implementation["campaign_id"] == campaign.campaign_id
            && implementation["gate_id"] == campaign.gate_id
            && implementation["workers"][R23D27_ENGINE_ID]["real_physics"] == true
            && implementation["workers"][R23D27_ENGINE_ID]["startup_transform_space"]
                == "canonical_velocity_before_host_mapping"
            && implementation["evaluation"]["ordered_cell_count"] == 9
            && implementation["supervisor"]["declared_world_count"] == 9
            && implementation["supervisor"]["serial_execution_required"] == true;
        if !exact {
            return Err("QSDK_R23D40_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
        }
        r23d27_initial_perturbation(campaign, &successor)?;
        return Ok(successor);
    }
    let candidates = successor["candidate_family"]["ordered_candidates"]
        .as_array()
        .ok_or_else(|| "QSDK_R23D27_RAP_CANDIDATES_INVALID".to_owned())?;
    let matrix = &successor["frozen_matrix"];
    let gates = if campaign.prospective_initial_perturbation.is_some() {
        &successor["frozen_common_physical_gates"]
    } else {
        &successor["frozen_active_turn_gates"]
    };
    let exact = successor["schema_version"] == campaign.preregistration_schema
        && successor["campaign_id"] == campaign.campaign_id
        && successor["gate_id"] == campaign.gate_id
        && successor["status"] == "prospective_zero_world_only"
        && successor["study_classification"] == campaign.study_classification
        && successor["candidate_family"]["parent_policy_id"] == campaign.parent_policy_id
        && successor["candidate_family"]["behavioral_controller_change_set"]
            .as_array()
            .is_some_and(|changes| changes.len() == campaign.behavior_change_count)
        && candidates.len() == 1
        && candidates[0]["candidate_id"] == campaign.candidate_id
        && candidates[0]["controller_policy_id"] == campaign.controller_policy_id
        && candidates[0]["minimum_steering_fraction"] == 0.20
        && candidates[0]["maximum_steering_fraction"] == 0.28
        && candidates[0]["full_authority_maximum_tilt_rad"] == 0.10
        && candidates[0]["minimum_authority_tilt_rad"] == 0.20
        && candidates[0]["minimum_support_contact_count"] == 2
        && (!campaign.predictive
            || (candidates[0]["prediction_horizon_s"] == 0.6
                && candidates[0]["prediction_horizon_scheduler_swing_steps"] == 72
                && candidates[0]["tilt_rate_source_id"]
                    == "state_frame_base_twist_world_angular_velocity_v1"
                && successor["candidate_family"]["finite_difference_trace_window_selected"]
                    == false))
        && (campaign.floor_hold_steps.is_none()
            || (candidates[0]["floor_hold_duration_steps"] == campaign.floor_hold_steps.unwrap()
                && candidates[0]["floor_hold_scheduler_swing_count"] == 2
                && candidates[0]["floor_hold_refresh_trigger"]
                    == "instantaneous_effective_authority_reaches_baseline"
                && candidates[0]["controller_memory_schema"]
                    == BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
                && candidates[0]["guard_receipt_schema"]
                    == "sporespore_steering_authority_guard_receipt_v3"))
        && successor["candidate_family"]["engine_specific_gait_logic_permitted"] == false
        && successor["candidate_family"]["candidate_or_outcome_branching_permitted"] == false
        && matrix["stage_id"] == campaign.stage_id
        && matrix["ordered_engine_ids"][0] == R23D27_ENGINE_ID
        && matrix["declared_cell_count"] == 3
        && matrix["controller_step_count"] == R23D27_CONTROLLER_STEPS
        && matrix["settlement_step_count"] == SETTLE_STEPS
        && matrix["turn_start_step"] == TURN_START_STEP
        && matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && matrix["serial_execution_required"] == true
        && matrix["all_cells_run_regardless_of_intermediate_outcome"] == true
        && matrix["seed"] == campaign.campaign_seed
        && gates["terminal_quiescent_taper_required"] == false
        && successor["selector"]["selected_candidate_is_validation"]
            == campaign.selected_candidate_is_validation
        && successor["evidence"]["clean_pushed_source_required"] == true
        && successor["claims"]["turning_validation"] == false
        && implementation["schema_version"] == campaign.implementation_schema
        && implementation["campaign_id"] == campaign.campaign_id
        && implementation["gate_id"] == campaign.gate_id
        && implementation["worker"]["terminal_taper_invoked"] == false
        && (campaign.prospective_initial_perturbation.is_none()
            || implementation["worker"]["campaign_seed"] == campaign.campaign_seed)
        && implementation["evaluation"]["ordered_cell_count"] == 3;
    if !exact {
        return Err("QSDK_R23D27_RAP_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    r23d27_initial_perturbation(campaign, &successor)?;
    Ok(successor)
}

fn r23d27_failure(
    cell: &R23D27Cell,
    source_commit: &str,
    failure_stage: &str,
    failure_code: &str,
    world_attempt_count: u64,
    world_build_count: u64,
    trace_artifact: Option<Value>,
) -> Value {
    json!({
        "schema_version": cell.campaign.failure_schema,
        "campaign_id": cell.campaign.campaign_id,
        "gate_id": cell.campaign.gate_id,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D27_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "controller_policy_id": cell.controller_policy_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "campaign_seed": cell.campaign.campaign_seed,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "failure_stage": failure_stage,
        "failure_code": failure_code,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "trace_artifact": trace_artifact,
        "claims": r23d27_claims(),
    })
}

fn r23d27_source_bindings_exact(
    campaign: &R23D27CampaignContract,
    freeze: &Value,
    implementation: &Value,
) -> bool {
    let Ok(repo_root) = r23d3_repo_root() else {
        return false;
    };
    if implementation["campaign_id"] != campaign.campaign_id
        || implementation["gate_id"] != campaign.gate_id
    {
        return false;
    }
    let declared_value = if matches!(
        campaign.gate_id,
        R23D43_GATE_ID | R23D44_GATE_ID | R23D49_GATE_ID | R23D50_GATE_ID
    ) {
        &implementation["dependency_closure"]["required_dependency_paths_by_worker"]
            [R23D27_ENGINE_ID]
    } else if campaign.startup_velocity_ramp {
        &implementation["source_binding_policy"]["exact_paths"]
    } else {
        &implementation["dependency_closure"]["required_dependency_paths_by_worker"]
            [R23D27_ENGINE_ID]
    };
    let Some(declared) = declared_value.as_array() else {
        return false;
    };
    if declared.is_empty() {
        return false;
    }
    let mut required_paths = BTreeMap::<&str, String>::new();
    for value in declared {
        let Some(path) = value.as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        if required_paths.contains_key(path) {
            return false;
        }
        let Ok(bytes) = fs::read(repo_root.join(path)) else {
            return false;
        };
        required_paths.insert(path, raw_sha256(&bytes));
    }
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    let mut observed = BTreeMap::<&str, &str>::new();
    for entry in bindings {
        let Some(path) = entry["path"].as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        let Some(digest) = entry["raw_sha256"].as_str().filter(|digest| {
            digest.strip_prefix("sha256:").is_some_and(|hex| {
                hex.len() == 64
                    && hex
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            })
        }) else {
            return false;
        };
        if observed.insert(path, digest).is_some() {
            return false;
        }
    }
    required_paths
        .iter()
        .all(|(path, digest)| observed.get(path).is_some_and(|value| *value == digest))
}

fn selected_profile_expected_matrix_cell_ids(campaign: &R23D27CampaignContract) -> Vec<String> {
    ["godot_jolt", "rapier_parry", "mujoco"]
        .into_iter()
        .flat_map(|engine_id| {
            ["reference_zero", "positive_heading", "negative_heading"]
                .into_iter()
                .map(move |arm_id| {
                    format!(
                        "{engine_id}__s{}__{}__{arm_id}",
                        campaign.campaign_seed, campaign.candidate_id
                    )
                })
        })
        .collect()
}

fn selected_profile_source_bindings_exact(
    repo_root: &std::path::Path,
    freeze: &Value,
    implementation: &Value,
) -> bool {
    let Some(expected) =
        implementation["dependency_closure"]["expected_transitive_paths"].as_array()
    else {
        return false;
    };
    let Some(bindings) = freeze["source_bindings"].as_array() else {
        return false;
    };
    let inventory = &freeze["dependency_inventory"];
    if expected.is_empty()
        || bindings.len() != expected.len()
        || inventory["ordered_paths"] != Value::Array(expected.clone())
        || inventory["transitive_path_count"].as_u64() != Some(expected.len() as u64)
    {
        return false;
    }
    let mut observed = BTreeMap::<String, String>::new();
    for item in bindings {
        let Some(path) = item["path"].as_str().filter(|path| !path.is_empty()) else {
            return false;
        };
        let Some(digest) = item["raw_sha256"].as_str().filter(|digest| {
            digest.strip_prefix("sha256:").is_some_and(|hex| {
                hex.len() == 64
                    && hex
                        .bytes()
                        .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
            })
        }) else {
            return false;
        };
        if observed
            .insert(path.to_owned(), digest.to_owned())
            .is_some()
        {
            return false;
        }
    }
    expected.iter().all(|value| {
        value.as_str().is_some_and(|path| {
            !path.is_empty()
                && fs::read(repo_root.join(path)).is_ok_and(|bytes| {
                    observed
                        .get(path)
                        .is_some_and(|digest| digest == &raw_sha256(&bytes))
                })
        })
    })
}

fn r23d63_receipt_schema_conformance_exact(value: &Value) -> bool {
    value["schema_version"] == "sporespore_qsdk_r23d63_authorization_receipt_schema_conformance_v1"
        && value["campaign_id"] == R23D63_CAMPAIGN_ID
        && value["gate_id"] == R23D63_GATE_ID
        && value["question_class"] == "equivalence_non_inferiority"
        && value["declared_producer_count"] == 3
        && value["conforming_producer_count"] == 3
        && value["required_field"] == "complete_ordered_nine_cell_matrix_validated"
        && value["required_json_type"] == "boolean"
        && value["required_value"].as_bool() == Some(true)
        && value["equivalence_margin"] == 0
        && value["non_inferiority_margin"] == 0
        && value["sampling_used"] == false
        && value["total_negative_control_count"] == 12
        && value["negative_controls_passed"] == 12
        && value["runtime_dependency_question_class"] == "equivalence_non_inferiority"
        && value["runtime_dependency_population"] == "complete_locked_mujoco_python_environment"
        && value["runtime_dependency_lock_path"] == "sdk/adapters/mujoco/requirements-lock.txt"
        && value["runtime_dependency_lock_raw_sha256"]
            == "sha256:1c4da4ba7964874fc55c8e16b60d1c6114f40e598f402fb2db1bb6a703b37603"
        && value["runtime_dependency_distribution_count"] == 9
        && value["runtime_dependency_distribution_file_count"] == 8094
        && value["runtime_dependency_distribution_byte_count"] == 131440050
        && value["runtime_dependency_environment_manifest_sha256"]
            == "sha256:95ea9d7f02a82fc84f62b04cf3c3a7415b62ccab4d04cb56cd12df7cd7696f68"
        && value["runtime_dependency_mujoco_version"] == "3.11.0"
        && value["runtime_dependency_mujoco_module_raw_sha256"]
            == "sha256:131342cd035fa2022b8ea46e1380aaa80641ee1d983d65c427a694517c3c6790"
        && value["runtime_dependency_path_self_bound"] == true
        && value["caller_pythonpath_required"] == false
        && value["caller_pythonpath_independence_control_count"] == 2
        && value["caller_pythonpath_independence_controls_passed"] == 2
        && value["runtime_dependency_equivalence_margin"] == 0
        && value["runtime_dependency_non_inferiority_margin"] == 0
        && value["runtime_dependency_sampling_used"] == false
        && value["model_construction_count"] == 0
        && value["world_attempt_count"] == 0
        && value["world_build_count"] == 0
        && value["physical_equivalence_claimed"] == false
        && value["physical_acceptance_authority"] == false
}

fn r23d64_receipt_schema_conformance_exact(value: &Value) -> bool {
    value["schema_version"] == "sporespore_qsdk_r23d64_authorization_receipt_schema_conformance_v1"
        && value["campaign_id"] == R23D64_CAMPAIGN_ID
        && value["gate_id"] == R23D64_GATE_ID
        && value["question_class"] == "equivalence_non_inferiority"
        && value["declared_producer_count"] == 3
        && value["conforming_producer_count"] == 3
        && value["required_field"] == "complete_ordered_nine_cell_matrix_validated"
        && value["required_json_type"] == "boolean"
        && value["required_value"].as_bool() == Some(true)
        && value["equivalence_margin"] == 0
        && value["non_inferiority_margin"] == 0
        && value["sampling_used"] == false
        && value["total_negative_control_count"] == 12
        && value["negative_controls_passed"] == 12
        && value["model_construction_count"] == 0
        && value["world_attempt_count"] == 0
        && value["world_build_count"] == 0
        && value["physical_equivalence_claimed"] == false
        && value["physical_acceptance_authority"] == false
}

fn r23d64_launcher_contract_conformance_exact(value: &Value) -> bool {
    value["schema_version"] == "sporespore_qsdk_r23d64_rapier_launcher_contract_conformance_v1"
        && value["campaign_id"] == R23D64_CAMPAIGN_ID
        && value["gate_id"] == R23D64_GATE_ID
        && value["question_class"] == "equivalence_non_inferiority"
        && value["population"] == "complete_two_supervisor_rapier_production_call_sites"
        && value["supervisor_rapier_production_call_site_count"] == 2
        && value["conforming_call_site_count"] == 2
        && value["population_compared_completely"] == true
        && value["sampling_used"] == false
        && value["required_seed_option"] == "--seed"
        && value["forbidden_seed_alias"] == "--campaign-seed"
        && value["shared_builder_count"] == 1
        && value["exact_vectors_executed_through_production_parser"] == 2
        && value["negative_control_count"] == 6
        && value["negative_controls_passed"] == 6
        && value["equivalence_margin"] == 0
        && value["non_inferiority_margin"] == 0
        && value["model_construction_count"] == 0
        && value["world_attempt_count"] == 0
        && value["world_build_count"] == 0
        && value["physical_equivalence_claimed"] == false
        && value["physical_acceptance_authority"] == false
        && value["release_authority"] == false
}

fn r23d65_receipt_schema_conformance_exact(value: &Value) -> bool {
    value["schema_version"] == "sporespore_qsdk_r23d65_authorization_receipt_schema_conformance_v1"
        && value["campaign_id"] == R23D65_CAMPAIGN_ID
        && value["gate_id"] == R23D65_GATE_ID
        && value["question_class"] == "equivalence_non_inferiority"
        && value["declared_producer_count"] == 3
        && value["conforming_producer_count"] == 3
        && value["required_field"] == "complete_ordered_nine_cell_matrix_validated"
        && value["required_json_type"] == "boolean"
        && value["required_value"].as_bool() == Some(true)
        && value["equivalence_margin"] == 0
        && value["non_inferiority_margin"] == 0
        && value["sampling_used"] == false
        && value["total_negative_control_count"] == 12
        && value["negative_controls_passed"] == 12
        && value["model_construction_count"] == 0
        && value["world_attempt_count"] == 0
        && value["world_build_count"] == 0
        && value["physical_equivalence_claimed"] == false
        && value["physical_acceptance_authority"] == false
}

fn r23d65_launcher_contract_conformance_exact(value: &Value) -> bool {
    value["schema_version"] == "sporespore_qsdk_r23d65_rapier_launcher_contract_conformance_v1"
        && value["campaign_id"] == R23D65_CAMPAIGN_ID
        && value["gate_id"] == R23D65_GATE_ID
        && value["question_class"] == "equivalence_non_inferiority"
        && value["population"] == "complete_two_supervisor_rapier_production_call_sites"
        && value["supervisor_rapier_production_call_site_count"] == 2
        && value["conforming_call_site_count"] == 2
        && value["population_compared_completely"] == true
        && value["sampling_used"] == false
        && value["required_seed_option"] == "--seed"
        && value["forbidden_seed_alias"] == "--campaign-seed"
        && value["shared_builder_count"] == 1
        && value["exact_vectors_executed_through_production_parser"] == 2
        && value["negative_control_count"] == 6
        && value["negative_controls_passed"] == 6
        && value["equivalence_margin"] == 0
        && value["non_inferiority_margin"] == 0
        && value["model_construction_count"] == 0
        && value["world_attempt_count"] == 0
        && value["world_build_count"] == 0
        && value["physical_equivalence_claimed"] == false
        && value["physical_acceptance_authority"] == false
        && value["release_authority"] == false
}

fn selected_profile_physical_authorization(
    cell: &R23D27Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    let campaign = cell.campaign;
    let generation = if campaign.gate_id == R23D62_GATE_ID {
        "r23d62"
    } else if campaign.gate_id == R23D63_GATE_ID {
        "r23d63"
    } else if campaign.gate_id == R23D64_GATE_ID {
        "r23d64"
    } else if campaign.gate_id == R23D65_GATE_ID {
        "r23d65"
    } else {
        return Err("QSDK_R23D27_RAP_SELECTED_PROFILE_CAMPAIGN_INVALID".to_owned());
    };
    let error_prefix = generation.to_ascii_uppercase();
    let error = |suffix: &str| format!("QSDK_{error_prefix}_RAP_{suffix}");
    let inventory_schema = format!("sporespore_qsdk_{generation}_dependency_inventory_v1");
    let inventory_policy =
        format!("{generation}_declared_roots_recursive_local_language_closure_v1");
    let repo_root = r23d3_repo_root()?;
    if repo_root.join(campaign.closure_path).is_file() {
        return Err(error("CLOSED"));
    }
    let implementation_path = repo_root.join(campaign.implementation_path);
    let freeze_path = env::var(campaign.freeze_path_env).unwrap_or_default();
    let attempt_path = env::var(campaign.attempt_path_env).unwrap_or_default();
    let token = env::var(campaign.token_env).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(campaign.attempt_root_env).unwrap_or_default());
    if !implementation_path.is_file()
        || !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err(error("PHYSICAL_AUTHORIZATION_REQUIRED"));
    }
    let implementation_raw =
        fs::read(&implementation_path).map_err(|_| error("IMPLEMENTATION_UNREADABLE"))?;
    let freeze_raw = fs::read(&freeze_path).map_err(|_| error("FREEZE_UNREADABLE"))?;
    let attempt_raw = fs::read(&attempt_path).map_err(|_| error("ATTEMPT_UNREADABLE"))?;
    let implementation: Value = serde_json::from_slice(&implementation_raw)
        .map_err(|_| error("IMPLEMENTATION_JSON_INVALID"))?;
    let freeze: Value =
        serde_json::from_slice(&freeze_raw).map_err(|_| error("FREEZE_JSON_INVALID"))?;
    let attempt: Value =
        serde_json::from_slice(&attempt_raw).map_err(|_| error("ATTEMPT_JSON_INVALID"))?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(campaign.authority_repo_root_env).unwrap_or_default())
            .canonicalize()
            .map_err(|_| error("AUTHORITY_REPO_ROOT_UNREADABLE"))?;
    let production_root = authority_repo_root
        .parent()
        .ok_or_else(|| error("REPO_PARENT_MISSING"))?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| error("EVIDENCE_ROOT_UNREADABLE"))?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| error("ATTEMPT_ROOT_UNREADABLE"))?;
    let expected_cells = selected_profile_expected_matrix_cell_ids(campaign);
    let dependency_policy = &implementation["dependency_closure"];
    let inventory = &freeze["dependency_inventory"];
    let zero_world = &freeze["zero_world_receipt"];
    let freeze_receipt_schema = &freeze["authorization_receipt_schema_conformance"];
    let attempt_receipt_schema = &attempt["authorization_receipt_schema_conformance"];
    let freeze_launcher_contract = &freeze["rapier_launcher_contract_conformance"];
    let attempt_launcher_contract = &attempt["rapier_launcher_contract_conformance"];
    let frozen_inputs = &freeze["content_addressed_inputs"];
    let adoption_input = &frozen_inputs["campaign_attestation_adoption"];
    let receipt_schema_exact = if campaign.gate_id == R23D62_GATE_ID {
        true
    } else if campaign.gate_id == R23D63_GATE_ID {
        r23d63_receipt_schema_conformance_exact(freeze_receipt_schema)
            && attempt_receipt_schema == freeze_receipt_schema
            && zero_world.get("authorization_receipt_schema_conformance")
                == Some(freeze_receipt_schema)
            && freeze["authorization_receipt_schema_conformance_passed_before_freeze"] == true
            && attempt["authorization_receipt_schema_conformance_passed_before_attempt"] == true
    } else if campaign.gate_id == R23D64_GATE_ID {
        r23d64_receipt_schema_conformance_exact(freeze_receipt_schema)
            && attempt_receipt_schema == freeze_receipt_schema
            && zero_world.get("authorization_receipt_schema_conformance")
                == Some(freeze_receipt_schema)
            && freeze["authorization_receipt_schema_conformance_passed_before_freeze"] == true
            && attempt["authorization_receipt_schema_conformance_passed_before_attempt"] == true
            && r23d64_launcher_contract_conformance_exact(freeze_launcher_contract)
            && attempt_launcher_contract == freeze_launcher_contract
            && zero_world.get("rapier_launcher_contract_conformance")
                == Some(freeze_launcher_contract)
            && freeze["rapier_launcher_contract_conformance_passed_before_freeze"] == true
            && attempt["rapier_launcher_contract_conformance_passed_before_attempt"] == true
    } else if campaign.gate_id == R23D65_GATE_ID {
        r23d65_receipt_schema_conformance_exact(freeze_receipt_schema)
            && attempt_receipt_schema == freeze_receipt_schema
            && zero_world.get("authorization_receipt_schema_conformance")
                == Some(freeze_receipt_schema)
            && freeze["authorization_receipt_schema_conformance_passed_before_freeze"] == true
            && attempt["authorization_receipt_schema_conformance_passed_before_attempt"] == true
            && r23d65_launcher_contract_conformance_exact(freeze_launcher_contract)
            && attempt_launcher_contract == freeze_launcher_contract
            && zero_world.get("rapier_launcher_contract_conformance")
                == Some(freeze_launcher_contract)
            && freeze["rapier_launcher_contract_conformance_passed_before_freeze"] == true
            && attempt["rapier_launcher_contract_conformance_passed_before_attempt"] == true
    } else {
        false
    };
    let exact = canonical_attempt_root.starts_with(&production_root)
        && freeze["schema_version"] == campaign.freeze_schema
        && freeze["campaign_id"] == campaign.campaign_id
        && freeze["gate_id"] == campaign.gate_id
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"]
            == raw_sha256(campaign.preregistration_raw.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["origin_main_commit"] == source_commit
        && freeze["live_github_main_commit"] == source_commit
        && freeze["source_tree_git_oid"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 40))
        && freeze["complete_zero_world_gate_passed"] == true
        && zero_world["campaign_id"] == campaign.campaign_id
        && zero_world["gate_id"] == campaign.gate_id
        && zero_world["model_construction_count"] == 0
        && zero_world["world_attempt_count"] == 0
        && zero_world["world_build_count"] == 0
        && zero_world["physical_execution_authorized"] == false
        && zero_world["physical_acceptance_authority"] == false
        && receipt_schema_exact
        && freeze["dependency_inventory_complete"] == true
        && inventory["schema_version"] == inventory_schema
        && inventory["policy_id"] == inventory_policy
        && inventory["inventory_projection_sha256"]
            == dependency_policy["expected_inventory_projection_sha256"]
        && inventory["expected_transitive_path_set_exact"] == true
        && inventory["all_paths_tracked_with_exact_case"] == true
        && inventory["checkout_bytes_equal_git_blobs"] == true
        && inventory["model_construction_count"] == 0
        && inventory["world_attempt_count"] == 0
        && inventory["world_build_count"] == 0
        && freeze["source_bindings"] == inventory["source_receipts"]
        && freeze["declared_world_count"] == 9
        && freeze["ordered_matrix_cell_ids"] == json!(expected_cells)
        && freeze["serial_execution_required"] == true
        && freeze["all_cells_run_regardless_of_intermediate_outcome"] == true
        && freeze["terminal_restoration_or_taper_invoked"] == false
        && freeze["source_checkout_bytes_equal_git_blobs"] == true
        && freeze["reproducible_runtime_materialization_passed"] == true
        && freeze["campaign_attestation_adoption_sha256"] == adoption_input["sha256"]
        && freeze["physical_execution_authorized"] == true
        && selected_profile_source_bindings_exact(&repo_root, &freeze, &implementation)
        && attempt["schema_version"] == campaign.attempt_schema
        && attempt["campaign_id"] == campaign.campaign_id
        && attempt["gate_id"] == campaign.gate_id
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["matrix_authorization_immutable_before_first_world"] == true
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["campaign_attestation_adoption_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["content_addressed_inputs"] == *frozen_inputs
        && attempt["one_shot_attempt_unconsumed"] == true
        && attempt["all_cells_run_regardless_of_intermediate_outcome"] == true
        && attempt["attempt_root"]
            .as_str()
            .and_then(|value| std::path::PathBuf::from(value).canonicalize().ok())
            .is_some_and(|path| path == canonical_attempt_root)
        && attempt["authority_repo_root"]
            .as_str()
            .and_then(|value| std::path::PathBuf::from(value).canonicalize().ok())
            .is_some_and(|path| path == authority_repo_root)
        && attempt["ordered_matrix_cell_ids"]
            == json!(selected_profile_expected_matrix_cell_ids(campaign))
        && env::var(campaign.stage_env).unwrap_or_default() == cell.stage_id
        && env::var(campaign.cell_env).unwrap_or_default() == cell.cell_id
        && env::var(campaign.engine_env).unwrap_or_default() == R23D27_ENGINE_ID;
    if !exact {
        return Err(error("PHYSICAL_AUTHORIZATION_INVALID"));
    }
    Ok(canonical_attempt_root)
}

fn r23d27_physical_authorization(
    cell: &R23D27Cell,
    source_commit: &str,
) -> Result<std::path::PathBuf, String> {
    if is_selected_profile_campaign(cell.campaign) {
        return selected_profile_physical_authorization(cell, source_commit);
    }
    let repo_root = r23d3_repo_root()?;
    let campaign = cell.campaign;
    if repo_root.join(campaign.closure_path).is_file() {
        return Err("QSDK_R23D27_RAP_CLOSED".to_owned());
    }
    let implementation_path = repo_root.join(campaign.implementation_path);
    let freeze_path = env::var(campaign.freeze_path_env).unwrap_or_default();
    let attempt_path = env::var(campaign.attempt_path_env).unwrap_or_default();
    let token = env::var(campaign.token_env).unwrap_or_default();
    let attempt_root =
        std::path::PathBuf::from(env::var(campaign.attempt_root_env).unwrap_or_default());
    if !implementation_path.is_file()
        || !std::path::Path::new(&freeze_path).is_file()
        || !std::path::Path::new(&attempt_path).is_file()
        || !attempt_root.is_dir()
        || !valid_lower_hex(&token, 32)
    {
        return Err("QSDK_R23D27_RAP_PHYSICAL_AUTHORIZATION_REQUIRED".to_owned());
    }
    let implementation_raw = fs::read(&implementation_path)
        .map_err(|_| "QSDK_R23D27_RAP_IMPLEMENTATION_UNREADABLE".to_owned())?;
    let implementation: Value = serde_json::from_slice(&implementation_raw)
        .map_err(|_| "QSDK_R23D27_RAP_IMPLEMENTATION_JSON_INVALID".to_owned())?;
    let freeze_raw =
        fs::read(&freeze_path).map_err(|_| "QSDK_R23D27_RAP_FREEZE_UNREADABLE".to_owned())?;
    let attempt_raw =
        fs::read(&attempt_path).map_err(|_| "QSDK_R23D27_RAP_ATTEMPT_UNREADABLE".to_owned())?;
    let freeze: Value = serde_json::from_slice(&freeze_raw)
        .map_err(|_| "QSDK_R23D27_RAP_FREEZE_JSON_INVALID".to_owned())?;
    let attempt: Value = serde_json::from_slice(&attempt_raw)
        .map_err(|_| "QSDK_R23D27_RAP_ATTEMPT_JSON_INVALID".to_owned())?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(campaign.authority_repo_root_env).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D27_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let production_root = authority_repo_root
        .parent()
        .ok_or_else(|| "QSDK_R23D27_RAP_REPO_PARENT_MISSING".to_owned())?
        .join("SporeSpore_Evidence")
        .canonicalize()
        .map_err(|_| "QSDK_R23D27_RAP_EVIDENCE_ROOT_UNREADABLE".to_owned())?;
    let canonical_attempt_root = attempt_root
        .canonicalize()
        .map_err(|_| "QSDK_R23D27_RAP_ATTEMPT_ROOT_UNREADABLE".to_owned())?;
    if !canonical_attempt_root.starts_with(&production_root) {
        return Err("QSDK_R23D27_RAP_ATTEMPT_ROOT_NOT_DURABLE".to_owned());
    }
    let matrix_cells = attempt["ordered_matrix_cell_ids"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    let expected_matrix_cells = if campaign.gate_id == R23D44_GATE_ID {
        [R23D44_NO_RAMP_CANDIDATE_ID, R23D44_RAMP_CANDIDATE_ID]
            .into_iter()
            .flat_map(|candidate_id| {
                ["reference_zero", "positive_heading", "negative_heading"]
                    .into_iter()
                    .map(move |arm_id| format!("{R23D27_ENGINE_ID}__{candidate_id}__{arm_id}"))
            })
            .collect::<Vec<_>>()
    } else if matches!(
        campaign.gate_id,
        R23D43_GATE_ID | R23D49_GATE_ID | R23D50_GATE_ID
    ) {
        ["reference_zero", "positive_heading", "negative_heading"]
            .into_iter()
            .map(|arm_id| format!("{R23D27_ENGINE_ID}__{}__{arm_id}", campaign.candidate_id))
            .collect::<Vec<_>>()
    } else if campaign.startup_velocity_ramp {
        ["rapier_parry", "godot_jolt", "mujoco"]
            .into_iter()
            .flat_map(|engine_id| {
                ["reference_zero", "positive_heading", "negative_heading"]
                    .into_iter()
                    .map(move |arm_id| format!("{engine_id}__{}__{arm_id}", campaign.candidate_id))
            })
            .collect::<Vec<_>>()
    } else {
        vec![
            format!("rapier_parry__{}__reference_zero", campaign.candidate_id),
            format!("rapier_parry__{}__positive_heading", campaign.candidate_id),
            format!("rapier_parry__{}__negative_heading", campaign.candidate_id),
        ]
    };
    let matrix_cells_exact = matrix_cells.len() == expected_matrix_cells.len()
        && matrix_cells
            .iter()
            .zip(expected_matrix_cells.iter())
            .all(|(observed, expected)| observed.as_str() == Some(expected.as_str()));
    let exact = freeze["schema_version"] == campaign.freeze_schema
        && freeze["campaign_id"] == campaign.campaign_id
        && freeze["gate_id"] == campaign.gate_id
        && freeze["status"] == "frozen_supervisor_only_physical_authorized"
        && freeze["preregistration_raw_sha256"]
            == raw_sha256(campaign.preregistration_raw.as_bytes())
        && freeze["implementation_contract_raw_sha256"] == raw_sha256(&implementation_raw)
        && freeze["source_commit"] == source_commit
        && freeze["physical_execution_authorized"] == true
        && r23d27_source_bindings_exact(campaign, &freeze, &implementation)
        && attempt["schema_version"] == campaign.attempt_schema
        && attempt["campaign_id"] == campaign.campaign_id
        && attempt["gate_id"] == campaign.gate_id
        && attempt["freeze_raw_sha256"] == raw_sha256(&freeze_raw)
        && attempt["source_commit"] == source_commit
        && attempt["authorization_token"] == token
        && attempt["attempt_id"]
            .as_str()
            .is_some_and(|value| valid_lower_hex(value, 32))
        && attempt["physical_execution_authorized"] == true
        && attempt["single_use_supervisor_authorization"] == true
        && attempt["matrix_authorization_immutable_before_first_world"] == true
        && matrix_cells_exact
        && attempt["source_worktree_clean"] == true
        && attempt["source_matches_live_github_main"] == true
        && attempt["operation_lock_held"] == true
        && attempt["campaign_attestation_adoption_valid"] == true
        && attempt["content_addressed_inputs_retained"] == true
        && attempt["one_shot_attempt_unconsumed"] == true
        && (!matches!(
            campaign.gate_id,
            R23D43_GATE_ID | R23D44_GATE_ID | R23D49_GATE_ID | R23D50_GATE_ID
        ) || (attempt["production_retention_preflight_passed"] == true
            && freeze["production_retention_preflight"]["schema_version"]
                == match campaign.gate_id {
                    R23D44_GATE_ID => "sporespore_qsdk_r23d44_production_retention_preflight_v1",
                    R23D49_GATE_ID => "sporespore_qsdk_r23d49_production_retention_preflight_v1",
                    R23D50_GATE_ID => "sporespore_qsdk_r23d50_production_retention_preflight_v1",
                    _ => "sporespore_qsdk_r23d43_production_retention_preflight_v1",
                }
            && freeze["production_retention_preflight"]["campaign_id"] == campaign.campaign_id
            && freeze["production_retention_preflight"]["gate_id"] == campaign.gate_id
            && freeze["production_retention_preflight"]["exact_production_cas_path_exercised"]
                == true
            && freeze["production_retention_preflight"]["synthetic_trace_row_count"]
                == if campaign.gate_id == R23D44_GATE_ID {
                    2 * R23D27_CONTROLLER_STEPS
                } else {
                    R23D27_CONTROLLER_STEPS
                }
            && freeze["production_retention_preflight"]["model_construction_count"] == 0
            && freeze["production_retention_preflight"]["world_attempt_count"] == 0
            && freeze["production_retention_preflight"]["world_build_count"] == 0
            && if campaign.gate_id == R23D44_GATE_ID {
                freeze["production_retention_preflight"]["synthetic_trace_count"] == 2
                    && freeze["production_retention_preflight"]["complete_cas_binding_verifier_exercised"]
                        == true
                    && freeze["production_retention_preflight"]["ordinary_and_windows_extended_path_spelling_positive_control_count"]
                        == 2
                    && freeze["production_retention_preflight"]["wrong_existing_file_rejection_count"]
                        == 1
                    && freeze["production_retention_preflight"]["trace_retentions"]
                        .as_array()
                        .is_some_and(|receipts| {
                            receipts.len() == 2
                                && receipts
                                    .iter()
                                    .all(|receipt| receipt["trace_artifact"]["test_only"] == false)
                        })
            } else if campaign.gate_id == R23D49_GATE_ID {
                freeze["production_retention_preflight"]["exact_rust_to_python_to_powershell_to_artifact_store_route_exercised"]
                    == true
                    && freeze["production_retention_preflight"]["process_scoped_execution_policy_bypass_exercised"]
                        == true
                    && freeze["production_retention_preflight"]["trace_retention"]["trace_artifact"]
                        ["test_only"]
                        == false
            } else if campaign.gate_id == R23D50_GATE_ID {
                freeze["production_retention_preflight"]["exact_rust_to_python_to_powershell_to_artifact_store_route_exercised"]
                    == true
                    && freeze["production_retention_preflight"]["process_scoped_execution_policy_bypass_exercised"]
                        == true
                    && freeze["production_retention_preflight"]["complete_cas_binding_verifier_exercised"]
                        == true
                    && freeze["production_retention_preflight"]["ordinary_and_windows_extended_path_spelling_positive_control_count"]
                        == 1
                    && freeze["production_retention_preflight"]["wrong_existing_file_rejection_count"]
                        == 1
                    && freeze["production_retention_preflight"]["trace_retention"]["trace_artifact"]
                        ["test_only"]
                        == false
            } else {
                freeze["production_retention_preflight"]["trace_retention"]["trace_artifact"]["test_only"]
                    == false
            }))
        && std::path::PathBuf::from(attempt["authority_repo_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == authority_repo_root)
        && std::path::PathBuf::from(attempt["attempt_root"].as_str().unwrap_or_default())
            .canonicalize()
            .is_ok_and(|path| path == canonical_attempt_root)
        && env::var(campaign.stage_env).unwrap_or_default() == cell.stage_id
        && env::var(campaign.cell_env).unwrap_or_default() == cell.cell_id
        && env::var(campaign.engine_env).unwrap_or_default() == R23D27_ENGINE_ID;
    if !exact {
        return Err("QSDK_R23D27_RAP_PHYSICAL_AUTHORIZATION_INVALID".to_owned());
    }
    Ok(canonical_attempt_root)
}

pub fn run_qsdk_r23d27_rapier_preflight_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    let cell = r23d27_cell(stage_id, candidate_id, arm_id)?;
    let contract = r23d27_contract(cell.campaign)?;
    let _perturbation = r23d27_initial_perturbation(cell.campaign, &contract)?;
    let (compiled, controller) = r23d27_compile_boundary(&cell)?;
    let compiled_repo_root = r23d3_repo_root()?;
    let (trigger_canary_passed, identity_canary_passed) = if cell.support_loss_conditioned_startup {
        r23d48_support_loss_canaries()?
    } else {
        (true, true)
    };
    let mut receipt = json!({
        "schema_version": cell.campaign.preflight_schema,
        "campaign_id": cell.campaign.campaign_id,
        "gate_id": cell.campaign.gate_id,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D27_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "campaign_seed": cell.campaign.campaign_seed,
        "controller_policy_id": controller.profile().policy_id,
        "predictive_guard_enabled": cell.campaign.predictive,
        "persistent_guard_enabled": cell.campaign.floor_hold_steps.is_some(),
        "startup_velocity_ramp_enabled": cell.startup_velocity_ramp,
        "trace_retention_cli_contract": if cell.campaign.trace_retain_source_root_argument_required {
            "source_root_and_repo_root_v1"
        } else {
            "repo_root_only_v1"
        },
        "trace_retain_source_root_argument_required":
            cell.campaign.trace_retain_source_root_argument_required,
        "production_retention_preflight_required": matches!(
            cell.campaign.gate_id,
            R23D43_GATE_ID | R23D44_GATE_ID | R23D49_GATE_ID | R23D50_GATE_ID
        ),
        "failed_child_stdout_and_stderr_bounded":
            matches!(
                cell.campaign.gate_id,
                R23D43_GATE_ID
                    | R23D44_GATE_ID
                    | R23D48_GATE_ID
                    | R23D49_GATE_ID
                    | R23D50_GATE_ID
            ),
        "startup_ramp_id": if cell.startup_velocity_ramp {
            Value::String(if cell.support_loss_conditioned_startup {
                R23D48_STARTUP_TRANSFORM_ID.to_owned()
            } else {
                R23D40_STARTUP_RAMP_ID.to_owned()
            })
        } else {
            Value::Null
        },
        "startup_ramp_step_count": if cell.startup_velocity_ramp {
            Value::from(R23D40_STARTUP_RAMP_STEPS)
        } else {
            Value::Null
        },
        "startup_ramp_exact_zero_at_step_zero":
            !cell.startup_velocity_ramp || r23d40_startup_velocity_scale(0) == 0.0,
        "startup_ramp_exact_unity_from_step_359":
            !cell.startup_velocity_ramp
                || (r23d40_startup_velocity_scale(358) < 1.0
                    && r23d40_startup_velocity_scale(359) == 1.0
                    && r23d40_startup_velocity_scale(R23D27_CONTROLLER_STEPS - 1) == 1.0),
        "startup_ramp_composed_in_canonical_velocity_space_before_host_mapping":
            cell.startup_velocity_ramp,
        "support_loss_conditioned_startup_enabled":
            cell.support_loss_conditioned_startup,
        "support_loss_trigger_branch_canary_passed": trigger_canary_passed,
        "support_loss_identity_branch_canary_passed": identity_canary_passed,
        "prediction_horizon_s": controller.profile().steering_guard_prediction_horizon_s,
        "floor_hold_duration_steps": controller.profile().steering_guard_floor_hold_steps,
        "controller_memory_schema": controller.initial_memory().schema_version,
        "yaw_error_stride_gain_per_rad": controller.profile().yaw_error_stride_gain_per_rad,
        "cross_track_frame_mode_id": controller.profile().cross_track_frame_mode_id,
        "compiled_morphology_id": compiled.morphology_id,
        "inherited_r23d11_controller_and_physics": true,
        "independent_diagnostic_availability_semantics": true,
        "inherited_r23d13_residual_pose_authority": true,
        "r23d14_tight_gated_horizon_inherited_unchanged": true,
        "inherited_r23d23_fixture_schedule_mapping_and_oracle": true,
        "terminal_taper_invoked": false,
        "nonzero_heading_aligned_receipt_regression_passed": true,
        "legacy_fixed_axis_oracle_rejected": true,
        "receipt_field_mutation_rejection_count": 5,
        "compiled_worker_repo_root_spelling": compiled_repo_root,
        "command_time_feedback_is_previous_completed_step": true,
        "physical_worker_implemented": true,
        "physical_worker_dormant_behind_supervisor_authorization": true,
        "physical_execution_authorized": false,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    });
    if is_selected_profile_campaign(cell.campaign) {
        let binding = resolve_production_public_profile_binding_v1()?;
        let force_plan =
            crate::locomotion::compile_public_profile_actuator_force_plan_v1(&compiled, &binding)?;
        if compiled.descriptor_sha256
            != sporespore_locomotion_core::R23D60_SELECTED_S169_DESCRIPTOR_SHA256
            || compiled.morphology.morphology_spec_sha256
                != sporespore_locomotion_core::R23D60_SELECTED_S169_MORPHOLOGY_SPEC_SHA256
            || !force_plan.public_profile_bound
            || force_plan.ordered_entries.len() != R23D3_ACTUATOR_COUNT as usize
        {
            return Err("QSDK_R23D62_RAP_PUBLIC_PROFILE_BOUNDARY_INVALID".to_owned());
        }
        let object = receipt
            .as_object_mut()
            .ok_or_else(|| "QSDK_R23D62_RAP_PREFLIGHT_NOT_OBJECT".to_owned())?;
        object.insert(
            "profile_id".to_owned(),
            Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()),
        );
        object.insert(
            "profile_sha256".to_owned(),
            Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
        );
        object.insert(
            "host_mapping_id".to_owned(),
            Value::String(R23D62_HOST_MAPPING_ID.to_owned()),
        );
        object.insert(
            "host_mapping_python_canonical_sha256".to_owned(),
            Value::String(R23D62_HOST_MAPPING_PYTHON_CANONICAL_SHA256.to_owned()),
        );
        object.insert(
            "actuator_cap_profile_resolution_receipt".to_owned(),
            binding.resolution_receipt,
        );
        object.insert(
            "actuator_cap_profile_host_mapping_receipt".to_owned(),
            binding.host_mapping_receipt,
        );
        object.insert(
            "public_profile_force_plan_actuator_count".to_owned(),
            Value::from(force_plan.ordered_entries.len()),
        );
        object.insert(
            "public_profile_force_plan_compiled_before_model".to_owned(),
            Value::Bool(true),
        );
        object.insert(
            "task_frame_origin_policy_id".to_owned(),
            Value::String(R23D62_TASK_ORIGIN_POLICY_ID.to_owned()),
        );
        object.insert(
            "expected_task_origin_reanchor_semantic_steps".to_owned(),
            json!([600, 1800, 2400]),
        );
        object.insert(
            "actuator_phase_observation_schema_version".to_owned(),
            Value::String(R23D62_ACTUATOR_PHASE_OBSERVATION_SCHEMA.to_owned()),
        );
        object.insert(
            "application_receipt_schema_version".to_owned(),
            Value::String(R23D62_APPLICATION_RECEIPT_SCHEMA.to_owned()),
        );
        object.insert(
            "trace_transport_id".to_owned(),
            Value::String(selected_profile_trace_transport_id(cell.campaign).to_owned()),
        );
        object.insert(
            "physical_constructor".to_owned(),
            Value::String("build_bw19v_velocity_only_v4_robot_with_public_profile".to_owned()),
        );
        object.insert(
            "physical_motor_readback_function".to_owned(),
            Value::String("apply_r23d62_public_profile_velocity_only_actuation".to_owned()),
        );
        object.insert(
            "physical_binding_readback_function".to_owned(),
            Value::String("r23d62_public_profile_physical_binding_receipt".to_owned()),
        );
    }
    Ok(receipt)
}

pub fn run_qsdk_r23d27_rapier_authorization_preflight_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, String> {
    let cell = r23d27_cell(stage_id, candidate_id, arm_id)?;
    let _contract = r23d27_contract(cell.campaign)?;
    if !valid_lower_hex(source_commit, 40) {
        return Err("QSDK_R23D27_RAP_SOURCE_COMMIT_INVALID".to_owned());
    }
    r23d27_physical_authorization(&cell, source_commit)?;
    let authorization_function = if cell.campaign.gate_id == R23D62_GATE_ID {
        "r23d62_physical_authorization"
    } else if cell.campaign.gate_id == R23D63_GATE_ID {
        "r23d63_physical_authorization"
    } else if cell.campaign.gate_id == R23D64_GATE_ID {
        "r23d64_physical_authorization"
    } else if cell.campaign.gate_id == R23D65_GATE_ID {
        "r23d65_physical_authorization"
    } else {
        "r23d27_physical_authorization"
    };
    Ok(json!({
        "schema_version": cell.campaign.authorization_preflight_schema,
        "campaign_id": cell.campaign.campaign_id,
        "gate_id": cell.campaign.gate_id,
        "engine_id": R23D27_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "actual_production_authorization_function": authorization_function,
        "authorization_passed": true,
        "returned_before_model": true,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

fn r23d27_mode_id(mode: &str) -> &str {
    mode
}

fn r23d27_handoff_reason(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
) -> Option<&'static str> {
    if state.handoff_after_active_step.is_none() {
        None
    } else if state.confirmation_satisfied {
        Some(R23D27_CONFIRMED_REASON)
    } else {
        Some(R23D27_DEADLINE_REASON)
    }
}

fn r23d27_ordered_contacts(contacts: &BTreeMap<String, bool>) -> Result<[bool; 4], String> {
    if contacts.len() != 4 {
        return Err("QSDK_R23D27_RAP_CONTACT_SHAPE_INVALID".to_owned());
    }
    let mut ordered = [false; 4];
    for (index, limb_id) in ["front_left", "front_right", "rear_left", "rear_right"]
        .iter()
        .enumerate()
    {
        ordered[index] = *contacts
            .get(*limb_id)
            .ok_or_else(|| format!("QSDK_R23D27_RAP_CONTACT_MISSING:{limb_id}"))?;
    }
    Ok(ordered)
}

fn r23d27_observe_taper(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
    contacts: &BTreeMap<String, bool>,
    torso_tilt_rad: f64,
    maximum_joint_error_rad: f64,
    native_applications: u64,
    velocity_scale_numerator: u64,
    velocity_scale_denominator: u64,
) -> Result<(crate::qsdk_r23d14_tight_gated_horizon::State, Value), String> {
    use crate::qsdk_r23d14_tight_gated_horizon::{
        production_coarse_pose_satisfied, production_observe_completed_step,
        production_tight_pose_satisfied,
    };
    let ordered_contacts = r23d27_ordered_contacts(contacts)?;
    let pre_mode = state.mode.clone();
    let pre_taper_count = state.taper_step_count;
    let (next, native_receipt) = production_observe_completed_step(
        state.clone(),
        ordered_contacts,
        torso_tilt_rad,
        maximum_joint_error_rad,
        usize::try_from(native_applications)
            .map_err(|_| "QSDK_R23D27_RAP_NATIVE_APPLICATION_COUNT_INVALID".to_owned())?,
        usize::try_from(velocity_scale_numerator)
            .map_err(|_| "QSDK_R23D27_RAP_TAPER_NUMERATOR_INVALID".to_owned())?,
        usize::try_from(velocity_scale_denominator)
            .map_err(|_| "QSDK_R23D27_RAP_TAPER_DENOMINATOR_INVALID".to_owned())?,
    )?;
    let transitioned = next.mode != pre_mode;
    let taper_reset = pre_mode == R23D27_TAPER_MODE && next.mode == R23D27_ACTIVE_MODE;
    if native_receipt.taper_reset_after_step != taper_reset {
        return Err("QSDK_R23D27_RAP_NATIVE_TAPER_RECEIPT_MISMATCH".to_owned());
    }
    let handoff_reason = if transitioned && next.mode == R23D27_PASSIVE_MODE {
        r23d27_handoff_reason(&next)
    } else {
        None
    };
    let receipt = json!({
        "step": state.next_step,
        "mode": r23d27_mode_id(&pre_mode),
        "all_four_contacts": ordered_contacts.into_iter().all(|contact| contact),
        "torso_tilt_rad": torso_tilt_rad,
        "maximum_absolute_joint_position_error_rad": maximum_joint_error_rad,
        "coarse_pose_satisfied": production_coarse_pose_satisfied(
            ordered_contacts,
            torso_tilt_rad,
            maximum_joint_error_rad,
        ),
        "tight_pose_satisfied": production_tight_pose_satisfied(
            ordered_contacts,
            torso_tilt_rad,
            maximum_joint_error_rad,
        ),
        "pre_step_taper_count": pre_taper_count,
        "post_step_taper_count": next.taper_step_count,
        "velocity_scale_numerator": velocity_scale_numerator,
        "velocity_scale_denominator": velocity_scale_denominator,
        "native_application_count": native_applications,
        "transition_after_step": transitioned,
        "taper_reset_after_step": taper_reset,
        "next_mode": r23d27_mode_id(&next.mode),
        "handoff_reason": handoff_reason,
    });
    Ok((next, receipt))
}

fn r23d27_taper_outcome(
    state: &crate::qsdk_r23d14_tight_gated_horizon::State,
) -> Result<Value, String> {
    let result = crate::qsdk_r23d14_tight_gated_horizon::production_outcome(state)?;
    Ok(json!({
        "next_step": state.next_step,
        "mode": r23d27_mode_id(&result.mode),
        "taper_step_count": state.taper_step_count,
        "confirmation_satisfied": result.confirmation_satisfied,
        "handoff_after_active_step": result.handoff_after_active_step,
        "first_passive_step": result.first_passive_step,
        "handoff_reason": r23d27_handoff_reason(state),
        "active_step_count": result.active_step_count,
        "passive_step_count": result.passive_step_count,
        "active_native_application_count": result.active_native_application_count,
        "passive_native_application_count": result.passive_native_application_count,
        "taper_reset_count": result.taper_reset_count,
        "first_post_handoff_contact_loss_step":
            result.first_post_handoff_contact_loss_step,
        "post_handoff_contact_loss_step_count":
            result.post_handoff_contact_loss_step_count,
        "quiescent_taper_gate_passed": result.passed,
    }))
}

pub(super) fn r23d27_observation_fields(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
) -> Result<R23D27ObservationFields, String> {
    let torso = &robot.world.bodies[robot.bodies["torso"]];
    let up = torso.rotation() * Vector::Y;
    Ok(R23D27ObservationFields {
        measured_yaw_rad: yaw_rad(robot),
        torso_height_m: torso.translation().y as f64,
        torso_tilt_rad: up.y.clamp(-1.0, 1.0).acos() as f64,
        torso_ground_contact: robot.torso_ground_contact(),
        ordered_foot_contacts: r23d8_limb_contacts(robot, compiled)?,
    })
}

pub(super) fn r23d27_maximum_joint_position_error(state: &StateFrame) -> Result<f64, String> {
    if state.ordered_joint_observations.len() != R23D3_ACTUATOR_COUNT as usize {
        return Err("QSDK_R23D27_RAP_TERMINAL_OBSERVATION_COUNT".to_owned());
    }
    state
        .ordered_joint_observations
        .iter()
        .try_fold(0.0_f64, |maximum, observation| {
            observation
                .position_rad
                .filter(|position| position.is_finite())
                .map(|position| maximum.max(position.abs()))
                .ok_or_else(|| {
                    format!(
                        "QSDK_R23D27_RAP_TERMINAL_POSITION_INVALID:{}",
                        observation.joint_id
                    )
                })
        })
}

struct R23D27StabilityInputs {
    raw_velocity_deltas_rad_s: Vec<Option<f64>>,
    availability: R23D27Availability,
    availability_name: &'static str,
    support_margin_m: Option<f64>,
}

struct R23D27StabilityAssistedComposition {
    host_mapping: sporespore_locomotion_core::VelocityOnlyHostMappingReceiptV1,
    applied_stability_velocity_deltas_rad_s: Vec<f64>,
    maximum_absolute_commanded_joint_velocity_rad_s: f64,
    authority_receipt: R23D27AuthorityReceipt,
}

fn r23d27_channel_floor(value: f64, tight: f64, coarse: f64) -> u64 {
    let normalized = ((value - tight) / (coarse - tight)).clamp(0.0, 1.0);
    (R23D27_SCALE_DENOMINATOR as f64 * normalized - 1.0e-12).ceil() as u64
}

fn r23d27_pose_authority_floor(
    feedback: &R23D27CommandFeedback,
) -> Result<(u64, u64, u64, &'static str), String> {
    if feedback.ordered_foot_contacts.len() != 4
        || !feedback.torso_tilt_rad.is_finite()
        || feedback.torso_tilt_rad < 0.0
        || !feedback.maximum_joint_error_rad.is_finite()
        || feedback.maximum_joint_error_rad < 0.0
    {
        return Err("QSDK_R23D27_RAP_POSE_FEEDBACK_INVALID".to_owned());
    }
    if !feedback.ordered_foot_contacts.values().all(|value| *value) {
        return Ok((
            0,
            0,
            R23D27_SCALE_DENOMINATOR,
            "incomplete_support_full_authority",
        ));
    }
    let tilt = r23d27_channel_floor(
        feedback.torso_tilt_rad,
        R23D27_TIGHT_MAXIMUM_TILT_RAD,
        R23D27_COARSE_MAXIMUM_TILT_RAD,
    );
    let joint = r23d27_channel_floor(
        feedback.maximum_joint_error_rad,
        R23D27_TIGHT_MAXIMUM_JOINT_ERROR_RAD,
        R23D27_COARSE_MAXIMUM_JOINT_ERROR_RAD,
    );
    let floor = 1_u64.max(tilt).max(joint);
    let controlling = if tilt > joint {
        "torso_tilt"
    } else if joint > tilt {
        "maximum_joint_position_error"
    } else if floor == 1 {
        "tight_pose_minimum"
    } else {
        "equal_pose_channels"
    };
    Ok((tilt, joint, floor, controlling))
}

fn r23d27_passive_authority_receipt(temporal_scale_numerator: u64) -> R23D27AuthorityReceipt {
    R23D27AuthorityReceipt {
        tilt_floor_numerator: 0,
        joint_error_floor_numerator: 0,
        pose_authority_floor_numerator: 0,
        controlling_input: None,
        temporal_scale_numerator,
        applied_scale_numerator: 0,
        combined_pre_taper_velocities_rad_s: vec![None; R23D3_ACTUATOR_COUNT as usize],
        final_canonical_velocities_rad_s: vec![0.0; R23D3_ACTUATOR_COUNT as usize],
        residual_pose_recovery_invoked: false,
    }
}

fn r23d27_ordered_limb_steps(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
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
                .ok_or_else(|| format!("QSDK_R23D27_RAP_LIMB_MEMORY_MISSING:{limb_id}"))
        })
        .collect()
}

fn r23d27_availability(
    value: StabilityInfluenceAvailability,
) -> (R23D27Availability, &'static str) {
    match value {
        StabilityInfluenceAvailability::Available => (R23D27Availability::Available, "available"),
        StabilityInfluenceAvailability::ObservationUnavailable => (
            R23D27Availability::ObservationUnavailable,
            "observation_unavailable",
        ),
        StabilityInfluenceAvailability::UpstreamInfeasible => (
            R23D27Availability::PlanningInfeasible,
            "planning_infeasible",
        ),
    }
}

fn r23d27_support_margin(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    stability_state: &sporespore_locomotion_core::StabilityStateV2,
) -> Result<Option<f64>, String> {
    if !bw19v_observation_available(stability_state) {
        return Ok(None);
    }
    let observation = observe_stability_v2(&compiled.morphology, stability_state)
        .map_err(|error| format!("QSDK_R23D27_RAP_SUPPORT_OBSERVATION_INVALID:{error}"))?;
    let margin = observation.minimum_dynamic_support_margin_m;
    if !margin.is_finite() {
        return Err("QSDK_R23D27_RAP_SUPPORT_MARGIN_NONFINITE".to_owned());
    }
    Ok(Some(margin))
}

fn r23d27_stability_inputs(
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    memory: &BalancedWaveControllerMemory,
    semantic_step: u64,
) -> Result<R23D27StabilityInputs, String> {
    let stability_state = robot.bw19v_stability_state(compiled, semantic_step)?;
    let support_margin_m = r23d27_support_margin(compiled, &stability_state)?;
    let kinematics = robot.bw19v_endpoint_kinematics(compiled, &stability_state)?;
    let limb_steps = r23d27_ordered_limb_steps(compiled, memory)?;
    let mut scratch_memory = RapierBw19vCompositionMemory::default();
    let receipt = compose_bw19v_step(
        compiled,
        base_actuation,
        stability_state,
        kinematics,
        limb_steps,
        &mut scratch_memory,
    )?;
    let (availability, availability_name) =
        r23d27_availability(receipt.scheduled_load_transfer.planning_availability);
    let raw_velocity_deltas_rad_s = receipt
        .ordered_commands
        .iter()
        .map(|command| command.raw_canonical_velocity_delta_rad_s)
        .collect::<Vec<_>>();
    let available = availability == R23D27Availability::Available;
    if raw_velocity_deltas_rad_s.len() != R23D3_ACTUATOR_COUNT as usize
        || (available
            && raw_velocity_deltas_rad_s
                .iter()
                .any(|value| value.is_none_or(|number| !number.is_finite())))
        || (!available && raw_velocity_deltas_rad_s.iter().any(Option::is_some))
    {
        return Err("QSDK_R23D27_RAP_STABILITY_INPUTS_INVALID".to_owned());
    }
    Ok(R23D27StabilityInputs {
        raw_velocity_deltas_rad_s,
        availability,
        availability_name,
        support_margin_m,
    })
}

pub(super) fn r23d27_task_velocities(state: &StateFrame) -> Result<[f64; 3], String> {
    let dot = |vector: Vec3, axis: Vec3| vector.x * axis.x + vector.y * axis.y + vector.z * axis.z;
    let values = [
        dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.forward_axis_world_unit,
        ),
        dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.lateral_axis_world_unit,
        ),
        dot(
            state.base_twist_world.angular_velocity_rad_s,
            state.task_frame.up_axis_world_unit,
        ),
    ];
    if values.iter().any(|value| !value.is_finite()) {
        return Err("QSDK_R23D27_RAP_TASK_VELOCITY_NONFINITE".to_owned());
    }
    Ok(values)
}

#[allow(clippy::too_many_arguments)]
fn r23d27_compose_stability_assisted_taper(
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    base_actuation: &ActuationFrame,
    composition: &R23D8NeutralComposition,
    stability_inputs: &R23D27StabilityInputs,
    numerator: u64,
    denominator: u64,
    command_feedback: &R23D27CommandFeedback,
    semantic_step: u64,
    memory: &R23D27CompositionMemory,
) -> Result<(R23D27CompositionMemory, R23D27StabilityAssistedComposition), String> {
    if denominator != R23D27_SCALE_DENOMINATOR || numerator == 0 || numerator > denominator {
        return Err("QSDK_R23D27_RAP_TAPER_SCALE_INVALID".to_owned());
    }
    let solutions = composition.receipt["ordered_actuator_solutions"]
        .as_array()
        .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
        .ok_or_else(|| "QSDK_R23D27_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())?;
    let actuators = &compiled.morphology.morphology_spec.actuators;
    if actuators.len() != solutions.len()
        || base_actuation.ordered_commands.len() != solutions.len()
    {
        return Err("QSDK_R23D27_RAP_TAPER_ACTUATOR_COUNT_INVALID".to_owned());
    }
    let actuator_ids = actuators
        .iter()
        .map(|actuator| actuator.actuator_id.clone())
        .collect::<Vec<_>>();
    let mut neutral_velocities = Vec::<f64>::with_capacity(solutions.len());
    for (actuator, solution) in actuators.iter().zip(solutions) {
        if solution["actuator_id"] != actuator.actuator_id {
            return Err(format!(
                "QSDK_R23D27_RAP_TAPER_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let bounded_velocity = solution["bounded_velocity_rad_s"]
            .as_f64()
            .filter(|value| value.is_finite() && value.abs() <= MAXIMUM_NEUTRAL_VELOCITY)
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D27_RAP_TAPER_BOUNDED_VELOCITY_INVALID:{}",
                    actuator.actuator_id
                )
            })?;
        neutral_velocities.push(bounded_velocity);
    }
    let semantic_step_usize = usize::try_from(semantic_step)
        .map_err(|_| "QSDK_R23D27_RAP_COMPOSITION_STEP_INVALID".to_owned())?;
    let (next_memory, rows) = compose_active_step(
        semantic_step_usize,
        &actuator_ids,
        &neutral_velocities,
        &stability_inputs.raw_velocity_deltas_rad_s,
        stability_inputs.availability,
        R23D27_SCALE_DENOMINATOR as usize,
        R23D27_SCALE_DENOMINATOR as usize,
        memory,
    )?;
    if rows.len() != actuators.len() {
        return Err("QSDK_R23D27_RAP_COMPOSITION_ROW_COUNT_INVALID".to_owned());
    }
    let mut ordered_residuals = Vec::<CanonicalVelocityResidualV1>::with_capacity(solutions.len());
    let mut desired_velocities = BTreeMap::<String, f64>::new();
    let mut applied_stability_velocity_deltas_rad_s = Vec::with_capacity(rows.len());
    let (tilt_floor, joint_floor, pose_floor, controlling_input) =
        r23d27_pose_authority_floor(command_feedback)?;
    let applied_numerator = numerator.max(pose_floor);
    let applied_scale = applied_numerator as f64 / R23D27_SCALE_DENOMINATOR as f64;
    let mut combined_pre_taper_velocities_rad_s = Vec::with_capacity(rows.len());
    let mut final_canonical_velocities_rad_s = Vec::with_capacity(rows.len());
    for ((actuator, source_command), row) in actuators
        .iter()
        .zip(&base_actuation.ordered_commands)
        .zip(&rows)
    {
        if source_command.actuator_id != actuator.actuator_id
            || row.combined_pre_taper.abs() > MAXIMUM_COMBINED_VELOCITY + TOLERANCE
            || row.fallback_zeroed
                != (stability_inputs.availability != R23D27Availability::Available)
        {
            return Err(format!(
                "QSDK_R23D27_RAP_TAPER_ACTUATOR_IDENTITY_INVALID:{}",
                actuator.actuator_id
            ));
        }
        let desired_velocity = row.combined_pre_taper * applied_scale;
        let portable_source_velocity = source_command.target_velocity_rad_s
            * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
        ordered_residuals.push(CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: actuator.actuator_id.clone(),
            canonical_velocity_delta_rad_s: desired_velocity - portable_source_velocity,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        });
        if desired_velocities
            .insert(actuator.actuator_id.clone(), desired_velocity)
            .is_some()
        {
            return Err("QSDK_R23D27_RAP_TAPER_ACTUATOR_DUPLICATE".to_owned());
        }
        applied_stability_velocity_deltas_rad_s.push(row.applied_stability_delta);
        combined_pre_taper_velocities_rad_s.push(Some(row.combined_pre_taper));
        final_canonical_velocities_rad_s.push(desired_velocity);
    }
    let (canonical_actuation, host_mapping) =
        map_bw19v_velocity_only_v4(compiled, base_actuation, &ordered_residuals)?;
    let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
    host_mapping
        .validate(&compiled.morphology, &canonical_actuation, &host_profile)
        .map_err(|error| format!("QSDK_R23D27_RAP_TAPER_HOST_MAPPING_INVALID:{error}"))?;
    let mut maximum_speed = 0.0_f64;
    for (canonical, host) in canonical_actuation
        .ordered_commands
        .iter()
        .zip(&host_mapping.ordered_commands)
    {
        let desired = *desired_velocities
            .get(&canonical.actuator_id)
            .ok_or_else(|| {
                format!(
                    "QSDK_R23D27_RAP_TAPER_DESIRED_VELOCITY_MISSING:{}",
                    canonical.actuator_id
                )
            })?;
        if host.actuator_id != canonical.actuator_id
            || (canonical.combined_canonical_target_velocity_rad_s - desired).abs() > TOLERANCE
            || (host.host_target_velocity_rad_s - desired).abs() > TOLERANCE
            || host.native_target_position_rad.is_some()
        {
            return Err(format!(
                "QSDK_R23D27_RAP_TAPER_MAPPING_VALUE_INVALID:{}",
                canonical.actuator_id
            ));
        }
        maximum_speed = maximum_speed.max(desired.abs());
    }
    Ok((
        next_memory,
        R23D27StabilityAssistedComposition {
            host_mapping,
            applied_stability_velocity_deltas_rad_s,
            maximum_absolute_commanded_joint_velocity_rad_s: maximum_speed,
            authority_receipt: R23D27AuthorityReceipt {
                tilt_floor_numerator: tilt_floor,
                joint_error_floor_numerator: joint_floor,
                pose_authority_floor_numerator: pose_floor,
                controlling_input: Some(controlling_input),
                temporal_scale_numerator: numerator,
                applied_scale_numerator: applied_numerator,
                combined_pre_taper_velocities_rad_s,
                final_canonical_velocities_rad_s,
                residual_pose_recovery_invoked: true,
            },
        },
    ))
}

#[allow(clippy::too_many_arguments)]
fn r23d27_controller_trace_row(
    cell: &R23D27Cell,
    trace_step: u64,
    robot: &HostRobot,
    compiled: &sporespore_locomotion_core::CompiledQuadruped,
    native_applications: u64,
    stability_inputs: &R23D27StabilityInputs,
    requested_steering_fraction: f64,
    held_steering_fraction: f64,
    steering_saturated: bool,
    trace_observation: R23D27ControllerTraceObservation,
    r23d62_extension: Option<R23D62TraceExtension>,
) -> Result<Value, String> {
    let (phase_id, heading_offset) = if trace_step < TURN_START_STEP {
        ("reference_warmup", 0.0)
    } else if trace_step < TURN_END_STEP_EXCLUSIVE {
        ("commanded_turn", cell.turn_heading_offset_rad)
    } else if trace_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE {
        ("reference_recovery", 0.0)
    } else {
        ("reference_continuation", 0.0)
    };
    let segment_id = if phase_id == "reference_continuation" {
        "after_declared_schedule"
    } else {
        phase_id
    };
    let observation = r23d27_observation_fields(robot, compiled)?;
    let applied_stability_deltas = vec![0.0_f64; R23D3_ACTUATOR_COUNT as usize];
    let diagnostic = crate::qsdk_r23d12_measurement_semantics::validate_physical_diagnostics(
        true,
        Some(stability_inputs.availability_name),
        stability_inputs.support_margin_m,
        &applied_stability_deltas,
    )
    .map_err(|error| format!("QSDK_R23D27_RAP_DIAGNOSTIC_SEMANTICS_INVALID:{error}"))?;
    let support_loss_receipt = trace_observation.support_loss_conditioned_startup.clone();
    let startup_residual_count = trace_observation.startup_ramp.startup_ramp_residual_count;
    let startup_maximum_residual = trace_observation
        .startup_ramp
        .startup_ramp_maximum_absolute_residual_rad_s;
    let mut row = json!({
        "schema_version": cell.campaign.trace_row_schema,
        "cell_id": cell.cell_id,
        "campaign_seed": cell.campaign.campaign_seed,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "semantic_step": trace_step,
        "segment_id": segment_id,
        "controller_semantic_step": trace_step,
        "desired_heading_offset_rad": heading_offset,
        "requested_steering_fraction": requested_steering_fraction,
        "held_steering_fraction": held_steering_fraction,
        "steering_saturated": steering_saturated,
        "steering_authority_guard": trace_observation.steering_authority_guard,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts.clone(),
        "ordered_foot_contacts_before": trace_observation.ordered_foot_contacts_before,
        "ordered_foot_contacts_after": observation.ordered_foot_contacts,
        "base_linear_velocity_task_forward_m_s": trace_observation.task_velocities[0],
        "base_linear_velocity_task_lateral_m_s": trace_observation.task_velocities[1],
        "base_angular_velocity_task_yaw_rad_s": trace_observation.task_velocities[2],
        "minimum_dynamic_support_margin_m":
            diagnostic["minimum_dynamic_support_margin_m"].clone(),
        "minimum_dynamic_support_margin_availability":
            diagnostic["minimum_dynamic_support_margin_availability"].clone(),
        "stability_planning_availability":
            diagnostic["stability_planning_availability"].clone(),
        "ordered_applied_stability_velocity_deltas_rad_s":
            diagnostic["ordered_applied_stability_velocity_deltas_rad_s"].clone(),
        "actuator_command_count": R23D3_ACTUATOR_COUNT,
        "validated_portable_command_count": R23D3_ACTUATOR_COUNT,
        "native_actuation_application_count": native_applications,
        "oracle_passed": true,
        "startup_ramp_id": trace_observation.startup_ramp.startup_ramp_id,
        "startup_velocity_scale": trace_observation.startup_ramp.startup_velocity_scale,
        "startup_ramp_active": trace_observation.startup_ramp.startup_ramp_active,
        "startup_ramp_residual_count":
            trace_observation.startup_ramp.startup_ramp_residual_count,
        "startup_ramp_maximum_absolute_residual_rad_s":
            trace_observation.startup_ramp.startup_ramp_maximum_absolute_residual_rad_s,
        "zero_actuation": false,
        "command_composition_mode": "balanced_wave_turning_v1",
        "taper_receipt_present": false,
        "pre_step_taper_count": Value::Null,
        "post_step_taper_count": Value::Null,
        "coarse_pose_satisfied": Value::Null,
        "tight_pose_satisfied": Value::Null,
        "command_time_feedback_trace_step": Value::Null,
        "command_time_ordered_foot_contacts": Value::Null,
        "command_time_torso_tilt_rad": Value::Null,
        "command_time_maximum_absolute_joint_position_error_rad": Value::Null,
        "temporal_scale_numerator": Value::Null,
        "temporal_scale_denominator": Value::Null,
        "tilt_floor_numerator": Value::Null,
        "joint_error_floor_numerator": Value::Null,
        "pose_authority_floor_numerator": Value::Null,
        "pose_authority_controlling_input": Value::Null,
        "applied_scale_numerator": Value::Null,
        "applied_scale_denominator": Value::Null,
        "ordered_combined_pre_taper_velocities_rad_s": Value::Null,
        "ordered_final_canonical_velocities_rad_s":
            trace_observation.ordered_final_canonical_velocities_rad_s,
        "ordered_actuator_velocity_limits_rad_s":
            trace_observation.ordered_actuator_velocity_limits_rad_s,
        "residual_pose_recovery_invoked": Value::Null,
        "authority_floor_never_reduces_temporal_authority": Value::Null,
        "complete_combined_velocity_scaled_once_before_host_mapping": Value::Null,
        "passive_mode_exact_zero_actuation": Value::Null,
        "transition_after_step": false,
        "taper_reset_after_step": false,
        "next_terminal_mode": Value::Null,
        "handoff_reason": Value::Null,
        "maximum_absolute_joint_position_error_rad":
            trace_observation.maximum_joint_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s": Value::Null,
    });
    if let Some(receipt) = support_loss_receipt {
        let object = row
            .as_object_mut()
            .ok_or_else(|| "QSDK_R23D48_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
        object.insert(
            "startup_transform_id".to_owned(),
            Value::String(R23D48_STARTUP_TRANSFORM_ID.to_owned()),
        );
        object.insert(
            "startup_probe_active".to_owned(),
            Value::Bool(receipt.startup_probe_active),
        );
        object.insert(
            "startup_probe_support_count".to_owned(),
            Value::from(receipt.startup_probe_support_count),
        );
        object.insert(
            "startup_probe_complete_support_loss".to_owned(),
            Value::Bool(receipt.startup_probe_complete_support_loss),
        );
        object.insert(
            "startup_transform_decision_locked".to_owned(),
            Value::Bool(receipt.startup_transform_decision_locked),
        );
        object.insert(
            "startup_ramp_triggered".to_owned(),
            Value::Bool(receipt.startup_ramp_triggered),
        );
        object.insert(
            "startup_ramp_trigger_step".to_owned(),
            receipt
                .startup_ramp_trigger_step
                .map_or(Value::Null, Value::from),
        );
        object.insert(
            "startup_ramp_local_step".to_owned(),
            receipt
                .startup_ramp_local_step
                .map_or(Value::Null, Value::from),
        );
        object.insert(
            "startup_transform_residual_count".to_owned(),
            Value::from(startup_residual_count),
        );
        object.insert(
            "startup_transform_maximum_absolute_residual_rad_s".to_owned(),
            Value::from(startup_maximum_residual),
        );
    }
    if let Some(extension) = r23d62_extension {
        let object = row
            .as_object_mut()
            .ok_or_else(|| "QSDK_R23D62_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
        object.insert(
            "task_frame_origin_policy_id".to_owned(),
            Value::String(R23D62_TASK_ORIGIN_POLICY_ID.to_owned()),
        );
        object.insert(
            "task_frame_origin_world_m".to_owned(),
            json!(extension.task_frame_origin_world_m),
        );
        object.insert(
            "torso_position_world_m".to_owned(),
            json!(extension.torso_position_world_m),
        );
        object.insert(
            "task_frame_origin_reanchored_this_step".to_owned(),
            Value::Bool(extension.task_frame_origin_reanchored_this_step),
        );
        object.insert(
            "task_frame_origin_reanchor_count".to_owned(),
            Value::from(extension.task_frame_origin_reanchor_count),
        );
        object.insert(
            "ordered_limb_phase_before".to_owned(),
            Value::Array(extension.ordered_limb_phase_before),
        );
        object.insert(
            "actuator_phase_observation".to_owned(),
            extension.actuator_phase_observation,
        );
    }
    Ok(row)
}

#[allow(clippy::too_many_arguments)]
fn r23d27_terminal_trace_row(
    cell: &R23D27Cell,
    trace_step: u64,
    mode: &str,
    taper_receipt: &Value,
    command_feedback: &R23D27CommandFeedback,
    authority_receipt: &R23D27AuthorityReceipt,
    observation: &R23D27ObservationFields,
    maximum_joint_error_rad: f64,
    maximum_commanded_speed_rad_s: Option<f64>,
    task_velocities: [f64; 3],
    support_margin_m: Option<f64>,
    planning_availability: Option<&str>,
    applied_stability_deltas_rad_s: &[f64],
) -> Result<Value, String> {
    let active = mode != R23D27_PASSIVE_MODE;
    if taper_receipt["mode"] != r23d27_mode_id(mode)
        || taper_receipt["step"] != trace_step - R23D27_CONTROLLER_STEPS
        || !maximum_joint_error_rad.is_finite()
        || maximum_joint_error_rad < 0.0
        || active != maximum_commanded_speed_rad_s.is_some()
        || maximum_commanded_speed_rad_s.is_some_and(|speed| !speed.is_finite() || speed < 0.0)
        || applied_stability_deltas_rad_s.len() != R23D3_ACTUATOR_COUNT as usize
        || applied_stability_deltas_rad_s
            .iter()
            .any(|value| !value.is_finite())
        || (!active
            && (planning_availability.is_some()
                || applied_stability_deltas_rad_s
                    .iter()
                    .any(|value| *value != 0.0)))
    {
        return Err("QSDK_R23D27_RAP_TERMINAL_TRACE_INPUT_INVALID".to_owned());
    }
    let diagnostic = crate::qsdk_r23d12_measurement_semantics::validate_physical_diagnostics(
        active,
        planning_availability,
        support_margin_m,
        applied_stability_deltas_rad_s,
    )
    .map_err(|error| format!("QSDK_R23D27_RAP_DIAGNOSTIC_SEMANTICS_INVALID:{error}"))?;
    let (phase_id, composition_mode) = match mode {
        R23D27_ACTIVE_MODE => (
            "terminal_neutral_acquisition",
            "residual_pose_authority_neutral_full_authority_v1",
        ),
        R23D27_TAPER_MODE => (
            "terminal_quiescent_taper",
            "residual_pose_authority_neutral_quiescent_taper_v1",
        ),
        R23D27_PASSIVE_MODE => (
            "terminal_irreversible_zero_actuation",
            "passive_zero_actuation_v1",
        ),
        _ => return Err("QSDK_R23D27_RAP_TERMINAL_MODE_INVALID".to_owned()),
    };
    Ok(json!({
        "schema_version": cell.campaign.trace_row_schema,
        "cell_id": cell.cell_id,
        "campaign_seed": cell.campaign.campaign_seed,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": Value::Null,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": observation.measured_yaw_rad,
        "torso_height_m": observation.torso_height_m,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": observation.torso_ground_contact,
        "ordered_foot_contacts": observation.ordered_foot_contacts,
        "base_linear_velocity_task_forward_m_s": task_velocities[0],
        "base_linear_velocity_task_lateral_m_s": task_velocities[1],
        "base_angular_velocity_task_yaw_rad_s": task_velocities[2],
        "minimum_dynamic_support_margin_m":
            diagnostic["minimum_dynamic_support_margin_m"].clone(),
        "minimum_dynamic_support_margin_availability":
            diagnostic["minimum_dynamic_support_margin_availability"].clone(),
        "stability_planning_availability":
            diagnostic["stability_planning_availability"].clone(),
        "ordered_applied_stability_velocity_deltas_rad_s":
            diagnostic["ordered_applied_stability_velocity_deltas_rad_s"].clone(),
        "actuator_command_count": if active { R23D3_ACTUATOR_COUNT } else { 0 },
        "native_actuation_application_count":
            taper_receipt["native_application_count"].clone(),
        "zero_actuation": !active,
        "command_composition_mode": composition_mode,
        "taper_receipt_present": true,
        "pre_step_taper_count": taper_receipt["pre_step_taper_count"].clone(),
        "post_step_taper_count": taper_receipt["post_step_taper_count"].clone(),
        "coarse_pose_satisfied": taper_receipt["coarse_pose_satisfied"].clone(),
        "tight_pose_satisfied": taper_receipt["tight_pose_satisfied"].clone(),
        "command_time_feedback_trace_step": command_feedback.trace_step,
        "command_time_ordered_foot_contacts": command_feedback.ordered_foot_contacts,
        "command_time_torso_tilt_rad": command_feedback.torso_tilt_rad,
        "command_time_maximum_absolute_joint_position_error_rad":
            command_feedback.maximum_joint_error_rad,
        "temporal_scale_numerator": taper_receipt["velocity_scale_numerator"].clone(),
        "temporal_scale_denominator": taper_receipt["velocity_scale_denominator"].clone(),
        "tilt_floor_numerator": authority_receipt.tilt_floor_numerator,
        "joint_error_floor_numerator": authority_receipt.joint_error_floor_numerator,
        "pose_authority_floor_numerator": authority_receipt.pose_authority_floor_numerator,
        "pose_authority_controlling_input": authority_receipt.controlling_input,
        "applied_scale_numerator": authority_receipt.applied_scale_numerator,
        "applied_scale_denominator": R23D27_SCALE_DENOMINATOR,
        "ordered_combined_pre_taper_velocities_rad_s":
            authority_receipt.combined_pre_taper_velocities_rad_s,
        "ordered_final_canonical_velocities_rad_s":
            authority_receipt.final_canonical_velocities_rad_s,
        "residual_pose_recovery_invoked": authority_receipt.residual_pose_recovery_invoked,
        "authority_floor_never_reduces_temporal_authority":
            authority_receipt.applied_scale_numerator
                >= authority_receipt.temporal_scale_numerator,
        "complete_combined_velocity_scaled_once_before_host_mapping": true,
        "passive_mode_exact_zero_actuation": !active,
        "transition_after_step": taper_receipt["transition_after_step"].clone(),
        "taper_reset_after_step": taper_receipt["taper_reset_after_step"].clone(),
        "next_terminal_mode": taper_receipt["next_mode"].clone(),
        "handoff_reason": taper_receipt["handoff_reason"].clone(),
        "maximum_absolute_joint_position_error_rad": maximum_joint_error_rad,
        "maximum_absolute_commanded_joint_velocity_rad_s":
            maximum_commanded_speed_rad_s,
    }))
}

fn r23d27_bounded_child_stream(bytes: &[u8]) -> String {
    let mut characters = String::from_utf8_lossy(bytes)
        .replace('\0', "\\0")
        .chars()
        .rev()
        .take(2_000)
        .collect::<Vec<_>>();
    characters.reverse();
    characters.into_iter().collect()
}

fn r23d27_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D27_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D27_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D27_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root = std::path::PathBuf::from(
        env::var(cell.campaign.authority_repo_root_env).unwrap_or_default(),
    )
    .canonicalize()
    .map_err(|_| "QSDK_R23D27_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    let evaluator_path = source_root.join(cell.campaign.evaluator_path);
    let python = env::var(cell.campaign.python_env).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(cell.campaign.powershell_env).unwrap_or_else(|_| "pwsh".to_owned());
    let mut command = std::process::Command::new(python);
    command
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path);
    if cell.campaign.trace_retain_source_root_argument_required {
        command.arg("--source-root").arg(&source_root);
    }
    let output = command
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D27_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let prefix = cell.campaign.trace_retention_marker;
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(prefix))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D27_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let mut receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D27_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != cell.campaign.trace_retention_schema
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D27_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    if is_selected_profile_campaign(cell.campaign) {
        if receipt["campaign_seed"] != cell.campaign.campaign_seed
            || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
            || receipt["engine_id"] != R23D27_ENGINE_ID
            || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        {
            return Err("QSDK_R23D62_RAP_TRACE_RETENTION_IDENTITY_INVALID".to_owned());
        }
        let artifact = receipt
            .get_mut("trace_artifact")
            .and_then(Value::as_object_mut)
            .ok_or_else(|| "QSDK_R23D62_RAP_TRACE_ARTIFACT_MISSING".to_owned())?;
        artifact.insert(
            "trace_transport_id".to_owned(),
            Value::String(selected_profile_trace_transport_id(cell.campaign).to_owned()),
        );
        artifact.insert(
            "trace_transport_engine_id".to_owned(),
            Value::String(R23D27_ENGINE_ID.to_owned()),
        );
        artifact.insert("canonical_ndjson".to_owned(), Value::Bool(true));
        artifact.insert("full_precision".to_owned(), Value::Bool(true));
        artifact.insert(
            "rust_serde_json_full_precision".to_owned(),
            Value::Bool(true),
        );
        let object = receipt
            .as_object_mut()
            .ok_or_else(|| "QSDK_R23D62_RAP_TRACE_RECEIPT_NOT_OBJECT".to_owned())?;
        object.insert(
            "trace_transport_id".to_owned(),
            Value::String(selected_profile_trace_transport_id(cell.campaign).to_owned()),
        );
        object.insert(
            "trace_transport_engine_id".to_owned(),
            Value::String(R23D27_ENGINE_ID.to_owned()),
        );
        object.insert("canonical_ndjson".to_owned(), Value::Bool(true));
        object.insert("full_precision".to_owned(), Value::Bool(true));
    }
    Ok(receipt)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ForwardDisplacementMeasurementOriginPlan {
    LegacyMutableTaskFrame,
    EvidenceWindowStart { semantic_step: u64 },
}

impl ForwardDisplacementMeasurementOriginPlan {
    fn validate(self, controller_steps: u64) -> Result<(), String> {
        match self {
            Self::LegacyMutableTaskFrame => Ok(()),
            Self::EvidenceWindowStart { semantic_step } if semantic_step < controller_steps => {
                Ok(())
            }
            Self::EvidenceWindowStart { .. } => {
                Err("QSDK_RAP_FORWARD_MEASUREMENT_PLAN_INVALID".to_owned())
            }
        }
    }

    const fn semantic_step(self) -> Option<u64> {
        match self {
            Self::LegacyMutableTaskFrame => None,
            Self::EvidenceWindowStart { semantic_step } => Some(semantic_step),
        }
    }
}

fn project_forward_displacement_measurement(
    plan: ForwardDisplacementMeasurementOriginPlan,
    mutable_task_origin_world_m: [f32; 3],
    evidence_window_origin_world_m: Option<[f32; 3]>,
    final_position_world_m: [f32; 3],
    reference_heading_rad: f64,
) -> Result<(f64, Option<Value>), String> {
    if !mutable_task_origin_world_m
        .iter()
        .chain(final_position_world_m.iter())
        .all(|value| value.is_finite())
        || !reference_heading_rad.is_finite()
    {
        return Err("QSDK_RAP_FORWARD_MEASUREMENT_INPUT_INVALID".to_owned());
    }

    let (origin, receipt) = match plan {
        ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame => {
            if evidence_window_origin_world_m.is_some() {
                return Err("QSDK_RAP_FORWARD_MEASUREMENT_LEGACY_CAPTURE_AMBIGUOUS".to_owned());
            }
            (mutable_task_origin_world_m, None)
        }
        ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart { semantic_step } => {
            let origin = evidence_window_origin_world_m.ok_or_else(|| {
                "QSDK_RAP_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_MISSING".to_owned()
            })?;
            if !origin.iter().all(|value| value.is_finite()) {
                return Err("QSDK_RAP_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_INVALID".to_owned());
            }
            let receipt = json!({
                "schema_version": FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA,
                "policy_id": EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
                "semantic_step": semantic_step,
                "origin_world_m": origin,
                "captured_before_controller_step": true,
                "task_frame_reanchors_change_measurement_origin": false,
                "physical_acceptance_authority": false,
            });
            (origin, Some(receipt))
        }
    };

    let forward_x = reference_heading_rad.cos() as f32;
    let forward_z = reference_heading_rad.sin() as f32;
    let displacement = ((final_position_world_m[0] - origin[0]) * forward_x
        + (final_position_world_m[2] - origin[2]) * forward_z) as f64;
    if !displacement.is_finite() {
        return Err("QSDK_RAP_FORWARD_MEASUREMENT_RESULT_INVALID".to_owned());
    }
    Ok((displacement, receipt))
}

pub(crate) fn run_forward_displacement_measurement_origin_preflight(
    semantic_step: u64,
    controller_steps: u64,
) -> Result<Value, String> {
    let plan = ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart { semantic_step };
    plan.validate(controller_steps)?;
    let task_origin = [1.9, 0.42, 0.02];
    let evidence_origin = [0.4, 0.42, -0.01];
    let (displacement, receipt) = project_forward_displacement_measurement(
        plan,
        task_origin,
        Some(evidence_origin),
        [1.901, 0.42, 0.02],
        0.0,
    )?;
    let receipt = receipt
        .ok_or_else(|| "QSDK_RAP_FORWARD_MEASUREMENT_PREFLIGHT_RECEIPT_MISSING".to_owned())?;
    if displacement != (1.901_f32 - 0.4_f32) as f64 {
        return Err("QSDK_RAP_FORWARD_MEASUREMENT_PREFLIGHT_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_rapier_forward_displacement_measurement_origin_preflight_v1",
        "engine_id": R23D27_ENGINE_ID,
        "measurement_origin": receipt,
        "synthetic_final_forward_displacement_m": displacement,
        "controller_task_origin_unchanged": task_origin == [1.9, 0.42, 0.02],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

#[derive(Debug, Clone, Copy)]
struct R23D27PhysicalExecutionPlan {
    controller_steps: u64,
    terminal_steps: u64,
    schedule_semantic_offset: u64,
    turn_start_step: u64,
    turn_end_step_exclusive: u64,
    turning_route: bool,
    r23d66_route: bool,
    r23d67_route: bool,
    r23d68_route: bool,
    r23d69_route: bool,
    r23d70_route: bool,
    r23d71_route: bool,
    r23d74_route: bool,
    r23d76_route: bool,
    r23d78_route: bool,
    forward_displacement_measurement_origin: ForwardDisplacementMeasurementOriginPlan,
}

impl R23D27PhysicalExecutionPlan {
    const LEGACY: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const TURNING_ROUTE: Self = Self {
        controller_steps: TURNING_ROUTE_CONTROLLER_STEPS,
        terminal_steps: TURNING_ROUTE_TERMINAL_STEPS,
        schedule_semantic_offset: TURNING_ROUTE_SCHEDULE_SEMANTIC_OFFSET,
        turn_start_step: 0,
        turn_end_step_exclusive: TURNING_ROUTE_CONTROLLER_STEPS,
        turning_route: true,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D66_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: true,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D67_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: true,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D68_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: true,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D69_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: true,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D70_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: true,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D71_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: true,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
    };

    const R23D74_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: true,
        r23d76_route: false,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            },
    };

    const R23D76_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: true,
        r23d78_route: false,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            },
    };

    const R23D78_ROUTE: Self = Self {
        controller_steps: R23D27_CONTROLLER_STEPS,
        terminal_steps: R23D27_TERMINAL_STEPS,
        schedule_semantic_offset: 0,
        turn_start_step: TURN_START_STEP,
        turn_end_step_exclusive: TURN_END_STEP_EXCLUSIVE,
        turning_route: false,
        r23d66_route: false,
        r23d67_route: false,
        r23d68_route: false,
        r23d69_route: false,
        r23d70_route: false,
        r23d71_route: false,
        r23d74_route: false,
        r23d76_route: false,
        r23d78_route: true,
        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            },
    };

    const fn with_evidence_window_measurement_origin(mut self, semantic_step: u64) -> Self {
        self.forward_displacement_measurement_origin =
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart { semantic_step };
        self
    }

    fn total_trace_steps(self) -> Result<u64, String> {
        self.controller_steps
            .checked_add(self.terminal_steps)
            .ok_or_else(|| "QSDK_R23D27_RAP_TRACE_HORIZON_OVERFLOW".to_owned())
    }
}

fn turning_route_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell: &R23D27Cell,
    observed_heading_offset_rad: f64,
) -> Result<Value, String> {
    if !observed_heading_offset_rad.is_finite()
        || observed_heading_offset_rad != cell.turn_heading_offset_rad
    {
        return Err("TURNING_ROUTE_RAP_NONZERO_SCHEDULE_NOT_OBSERVED".to_owned());
    }
    let object = row
        .as_object_mut()
        .ok_or_else(|| "TURNING_ROUTE_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(TURNING_ROUTE_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "route_id".to_owned(),
        Value::String(TURNING_ROUTE_ID.to_owned()),
    );
    object.insert(
        "engine_id".to_owned(),
        Value::String(TURNING_ROUTE_ENGINE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell.cell_id.clone()));
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(TURNING_ROUTE_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "phase_id".to_owned(),
        Value::String("commanded_turn".to_owned()),
    );
    object.insert(
        "segment_id".to_owned(),
        Value::String("commanded_turn".to_owned()),
    );
    object.insert(
        "desired_heading_offset_rad".to_owned(),
        Value::from(observed_heading_offset_rad),
    );
    Ok(row)
}

fn r23d66_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell: &R23D27Cell,
) -> Result<Value, String> {
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D66_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D66_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D66_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D66_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D66_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell.cell_id.clone()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D66_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D66_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    Ok(row)
}

fn r23d66_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D66_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D66_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D66_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D66_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D66_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D66_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D66_EVALUATOR_PATH);
    let python = env::var(R23D66_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D66_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D66_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D66_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D66_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D66_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D66_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["engine_id"] != R23D66_ENGINE_ID
        || receipt["campaign_seed"] != R23D66_CAMPAIGN_SEED
        || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        || receipt["row_count"] != R23D27_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D66_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d67_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell: &R23D27Cell,
) -> Result<Value, String> {
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D67_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D67_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D67_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D67_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D67_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell.cell_id.clone()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D67_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D67_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    Ok(row)
}

fn r23d67_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D67_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D67_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D67_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D67_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D67_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D67_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D67_EVALUATOR_PATH);
    let python = env::var(R23D67_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D67_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D67_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D67_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D67_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D67_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D67_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["engine_id"] != R23D67_ENGINE_ID
        || receipt["campaign_seed"] != R23D67_CAMPAIGN_SEED
        || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        || receipt["row_count"] != R23D27_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D67_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d68_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell: &R23D27Cell,
) -> Result<Value, String> {
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D68_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D68_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D68_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D68_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D68_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell.cell_id.clone()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D68_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D68_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    Ok(row)
}

pub(crate) fn r23d69_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D69_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D69_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D69_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D69_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D69_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D69_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D69_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D69_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D69_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d69_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d69_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

pub(crate) fn r23d70_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D70_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D70_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D70_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D70_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D70_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D70_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D70_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D70_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D70_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d70_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d70_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

pub(crate) fn r23d71_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D71_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D71_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D71_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D71_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D71_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D71_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D71_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D71_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D71_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d71_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d71_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

pub(crate) fn r23d74_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D74_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D74_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D74_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D74_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D74_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D74_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D74_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D74_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D74_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d74_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d74_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

pub(crate) fn r23d76_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D76_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D76_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D76_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D76_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D76_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D76_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D76_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D76_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D76_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d76_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d76_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

pub(crate) fn r23d78_project_production_trace_row(
    mut row: Value,
    semantic_step: u64,
    cell_id: &str,
) -> Result<Value, String> {
    if semantic_step >= R23D27_CONTROLLER_STEPS {
        return Err("QSDK_R23D78_RAP_SEMANTIC_STEP_INVALID".to_owned());
    }
    let segment_id = if semantic_step < TURN_START_STEP {
        "reference_warmup"
    } else if semantic_step < TURN_END_STEP_EXCLUSIVE {
        "commanded_turn"
    } else if semantic_step < R23D78_RECOVERY_END_STEP_EXCLUSIVE {
        "reference_recovery"
    } else {
        "reference_continuation"
    };
    let object = row
        .as_object_mut()
        .ok_or_else(|| "QSDK_R23D78_RAP_TRACE_ROW_NOT_OBJECT".to_owned())?;
    object.insert(
        "schema_version".to_owned(),
        Value::String(R23D78_TRACE_ROW_SCHEMA.to_owned()),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D78_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D78_GATE_ID.to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D78_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(cell_id.to_owned()));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D78_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D78_CAMPAIGN_SEED),
    );
    object.insert("semantic_step".to_owned(), Value::from(semantic_step));
    object.insert("trace_step".to_owned(), Value::from(semantic_step));
    object.insert(
        "segment_id".to_owned(),
        Value::String(segment_id.to_owned()),
    );
    Ok(row)
}

fn r23d78_trace_row(row: Value, semantic_step: u64, cell: &R23D27Cell) -> Result<Value, String> {
    r23d78_project_production_trace_row(row, semantic_step, &cell.cell_id)
}

fn r23d68_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D68_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D68_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D68_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D68_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D68_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D68_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D68_EVALUATOR_PATH);
    let python = env::var(R23D68_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D68_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D68_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D68_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D68_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D68_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D68_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["engine_id"] != R23D68_ENGINE_ID
        || receipt["campaign_seed"] != R23D68_CAMPAIGN_SEED
        || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        || receipt["row_count"] != R23D27_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D68_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d69_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D69_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D69_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D69_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D69_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D69_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D69_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D69_EVALUATOR_PATH);
    let python = env::var(R23D69_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D69_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D69_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D69_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D69_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D69_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != R23D69_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["engine_id"] != R23D69_ENGINE_ID
        || receipt["campaign_seed"] != R23D69_CAMPAIGN_SEED
        || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        || receipt["row_count"] != R23D27_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D69_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

fn r23d70_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D70_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D70_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D70_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D70_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D70_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D70_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D70_EVALUATOR_PATH);
    let python = env::var(R23D70_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D70_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D70_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D70_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D70_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D70_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    crate::qsdk_r23d70_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d70_receipt_contract::ExpectedReceipt {
            schema_version: R23D70_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D70_ENGINE_ID,
            campaign_seed: R23D70_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D70_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
    Ok(receipt)
}

fn r23d71_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D71_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D71_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D71_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D71_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D71_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D71_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D71_EVALUATOR_PATH);
    let python = env::var(R23D71_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D71_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D71_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D71_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D71_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D71_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    crate::qsdk_r23d71_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d71_receipt_contract::ExpectedReceipt {
            schema_version: R23D71_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D71_ENGINE_ID,
            campaign_seed: R23D71_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D71_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
    Ok(receipt)
}

fn r23d74_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D74_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D74_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D74_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D74_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D74_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D74_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D74_EVALUATOR_PATH);
    let python = env::var(R23D74_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D74_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D74_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D74_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D74_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D74_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    crate::qsdk_r23d74_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d74_receipt_contract::ExpectedReceipt {
            schema_version: R23D74_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D74_ENGINE_ID,
            campaign_seed: R23D74_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D74_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
    Ok(receipt)
}

fn r23d76_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D76_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D76_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D76_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D76_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D76_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D76_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D76_EVALUATOR_PATH);
    let python = env::var(R23D76_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D76_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D76_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D76_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D76_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D76_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    crate::qsdk_r23d76_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d76_receipt_contract::ExpectedReceipt {
            schema_version: R23D76_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D76_ENGINE_ID,
            campaign_seed: R23D76_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D76_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
    Ok(receipt)
}

fn r23d78_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("QSDK_R23D78_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}__{}.rows.json", cell.stage_id, cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("QSDK_R23D78_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("QSDK_R23D78_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root =
        std::path::PathBuf::from(env::var(R23D78_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default())
            .canonicalize()
            .map_err(|_| "QSDK_R23D78_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("QSDK_R23D78_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(R23D78_EVALUATOR_PATH);
    let python = env::var(R23D78_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(R23D78_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--stage-id")
        .arg(&cell.stage_id)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("QSDK_R23D78_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(R23D78_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "QSDK_R23D78_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("QSDK_R23D78_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    crate::qsdk_r23d78_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d78_receipt_contract::ExpectedReceipt {
            schema_version: R23D78_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D78_ENGINE_ID,
            campaign_seed: R23D78_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D78_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
    Ok(receipt)
}

fn turning_route_retain_trace(
    cell: &R23D27Cell,
    rows: &[Value],
    attempt_root: &std::path::Path,
) -> Result<Value, String> {
    let pending_root = attempt_root.join("pending-traces");
    fs::create_dir_all(&pending_root)
        .map_err(|error| format!("TURNING_ROUTE_RAP_TRACE_ROOT_CREATE_FAILED:{error}"))?;
    let rows_path = pending_root.join(format!("{}.rows.json", cell.cell_id));
    let file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&rows_path)
        .map_err(|error| format!("TURNING_ROUTE_RAP_TRACE_ROWS_CREATE_FAILED:{error}"))?;
    serde_json::to_writer(file, rows)
        .map_err(|error| format!("TURNING_ROUTE_RAP_TRACE_ROWS_WRITE_FAILED:{error}"))?;
    let source_root = r23d3_repo_root()?;
    let authority_repo_root = std::path::PathBuf::from(
        env::var(TURNING_ROUTE_AUTHORITY_REPO_ROOT_ENV).unwrap_or_default(),
    )
    .canonicalize()
    .map_err(|_| "TURNING_ROUTE_RAP_AUTHORITY_REPO_ROOT_UNREADABLE".to_owned())?;
    if authority_repo_root != source_root {
        return Err("TURNING_ROUTE_RAP_AUTHORITY_REPO_ROOT_INVALID".to_owned());
    }
    let evaluator_path = source_root.join(TURNING_ROUTE_EVALUATOR_PATH);
    let python = env::var(TURNING_ROUTE_PYTHON_ENV).unwrap_or_else(|_| "python".to_owned());
    let powershell = env::var(TURNING_ROUTE_POWERSHELL_ENV).unwrap_or_else(|_| "pwsh".to_owned());
    let output = std::process::Command::new(python)
        .current_dir(&authority_repo_root)
        .arg(&evaluator_path)
        .arg("retain-trace")
        .arg("--engine-id")
        .arg(TURNING_ROUTE_ENGINE_ID)
        .arg("--cell-id")
        .arg(&cell.cell_id)
        .arg("--rows-json")
        .arg(&rows_path)
        .arg("--repo-root")
        .arg(&authority_repo_root)
        .arg("--attempt-root")
        .arg(attempt_root)
        .arg("--powershell")
        .arg(powershell)
        .output()
        .map_err(|error| format!("TURNING_ROUTE_RAP_TRACE_RETAINER_START_FAILED:{error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let markers = stdout
        .lines()
        .filter_map(|line| line.strip_prefix(TURNING_ROUTE_TRACE_RETENTION_MARKER))
        .collect::<Vec<_>>();
    if !output.status.success() || markers.len() != 1 {
        return Err(format!(
            "TURNING_ROUTE_RAP_TRACE_RETENTION_FAILED:{}:markers={}:stdout={}:stderr={}",
            output.status,
            markers.len(),
            r23d27_bounded_child_stream(&output.stdout),
            r23d27_bounded_child_stream(&output.stderr),
        ));
    }
    let receipt: Value = serde_json::from_str(markers[0])
        .map_err(|error| format!("TURNING_ROUTE_RAP_TRACE_RECEIPT_INVALID:{error}"))?;
    if receipt["schema_version"] != TURNING_ROUTE_TRACE_RETENTION_SCHEMA
        || receipt["route_id"] != TURNING_ROUTE_ID
        || receipt["engine_id"] != TURNING_ROUTE_ENGINE_ID
        || receipt["cell_id"] != cell.cell_id
        || receipt["campaign_seed"] != TURNING_ROUTE_CAMPAIGN_SEED
        || receipt["row_count"] != TURNING_ROUTE_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("TURNING_ROUTE_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
    Ok(receipt)
}

#[allow(clippy::reversed_empty_ranges)]
pub fn run_qsdk_r23d27_rapier_physical_impl(
    stage_id: &str,
    candidate_id: &str,
    arm_id: &str,
    source_commit: &str,
) -> Result<Value, Value> {
    let cell = r23d27_cell(stage_id, candidate_id, arm_id).map_err(|code| {
        let campaign = r23d27_campaign(stage_id).unwrap_or(&R23D27_CAMPAIGN);
        json!({
            "schema_version": campaign.failure_schema,
            "campaign_id": campaign.campaign_id,
            "gate_id": campaign.gate_id,
            "stage_id": stage_id,
            "cell_id": Value::Null,
            "engine_id": R23D27_ENGINE_ID,
            "candidate_id": candidate_id,
            "arm_id": arm_id,
            "campaign_seed": campaign.campaign_seed,
            "turn_heading_offset_rad": Value::Null,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "trace_artifact": Value::Null,
            "claims": r23d27_claims(),
        })
    })?;
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D27_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    let contract = r23d27_contract(cell.campaign).map_err(&before_world)?;
    let attempt_root =
        r23d27_physical_authorization(&cell, source_commit).map_err(&before_world)?;
    let perturbation =
        r23d27_initial_perturbation(cell.campaign, &contract).map_err(&before_world)?;
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        perturbation,
        R23D27PhysicalExecutionPlan::LEGACY,
    )
}

pub(crate) fn run_turning_route_rapier_physical_core(
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell =
        r23d27_cell(R23D65_STAGE_ID, "selected_profile", "positive_heading").map_err(|code| {
            json!({
                "schema_version": "sporespore_three_engine_turning_success_transport_worker_failure_v2",
                "route_id": TURNING_ROUTE_ID,
                "question_class": "development",
                "engine_id": TURNING_ROUTE_ENGINE_ID,
                "cell_id": Value::Null,
                "campaign_seed": TURNING_ROUTE_CAMPAIGN_SEED,
                "arm_id": "positive_heading",
                "turn_heading_offset_rad": 0.2,
                "source_commit": source_commit,
                "failure_stage": "before_world",
                "failure_code": code,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "trace_artifact": Value::Null,
                "claims": r23d27_claims(),
            })
        })?;
    cell.stage_id = TURNING_ROUTE_STAGE_ID.to_owned();
    cell.cell_id = TURNING_ROUTE_CELL_ID.to_owned();
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "TURNING_ROUTE_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "TURNING_ROUTE_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        TURNING_ROUTE_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::TURNING_ROUTE,
    )
}

pub(crate) fn run_r23d66_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d66_worker_failure_v1",
            "campaign_id": R23D66_CAMPAIGN_ID,
            "gate_id": R23D66_GATE_ID,
            "stage_id": R23D66_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D66_ENGINE_ID,
            "campaign_seed": R23D66_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D66_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d66__{R23D66_ENGINE_ID}__s{R23D66_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D66_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D66_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D66_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D66_ROUTE,
    )
}

pub(crate) fn run_r23d66_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D66_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || !plan.r23d66_route
    {
        return Err("QSDK_R23D66_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d66_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D66_CAMPAIGN_ID,
        "gate_id": R23D66_GATE_ID,
        "stage_id": R23D66_STAGE_ID,
        "engine_id": R23D66_ENGINE_ID,
        "cell_id": format!(
            "r23d66__{R23D66_ENGINE_ID}__s{R23D66_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D66_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D66_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D66_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D66_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D66_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D66_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D66_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d67_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d67_worker_failure_v1",
            "campaign_id": R23D67_CAMPAIGN_ID,
            "gate_id": R23D67_GATE_ID,
            "stage_id": R23D67_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D67_ENGINE_ID,
            "campaign_seed": R23D67_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D67_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d67__{R23D67_ENGINE_ID}__s{R23D67_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D67_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D67_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D67_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D67_ROUTE,
    )
}

pub(crate) fn run_r23d67_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D67_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || !plan.r23d67_route
    {
        return Err("QSDK_R23D67_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d67_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D67_CAMPAIGN_ID,
        "gate_id": R23D67_GATE_ID,
        "stage_id": R23D67_STAGE_ID,
        "engine_id": R23D67_ENGINE_ID,
        "cell_id": format!(
            "r23d67__{R23D67_ENGINE_ID}__s{R23D67_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D67_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D67_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D67_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D67_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D67_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D67_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D67_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d68_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d68_worker_failure_v1",
            "campaign_id": R23D68_CAMPAIGN_ID,
            "gate_id": R23D68_GATE_ID,
            "stage_id": R23D68_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D68_ENGINE_ID,
            "campaign_seed": R23D68_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D68_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d68__{R23D68_ENGINE_ID}__s{R23D68_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D68_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D68_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D68_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D68_ROUTE,
    )
}

pub(crate) fn run_r23d68_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D68_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d69_route
        || plan.r23d70_route
        || plan.r23d71_route
        || plan.r23d74_route
        || plan.r23d76_route
        || plan.r23d78_route
        || !plan.r23d68_route
    {
        return Err("QSDK_R23D68_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d68_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D68_CAMPAIGN_ID,
        "gate_id": R23D68_GATE_ID,
        "stage_id": R23D68_STAGE_ID,
        "engine_id": R23D68_ENGINE_ID,
        "cell_id": format!(
            "r23d68__{R23D68_ENGINE_ID}__s{R23D68_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D68_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D68_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D68_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D68_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D68_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D68_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D68_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d69_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d69_worker_failure_v1",
            "campaign_id": R23D69_CAMPAIGN_ID,
            "gate_id": R23D69_GATE_ID,
            "stage_id": R23D69_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D69_ENGINE_ID,
            "campaign_seed": R23D69_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D69_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d69__{R23D69_ENGINE_ID}__s{R23D69_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D69_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D69_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D69_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D69_ROUTE,
    )
}

pub(crate) fn run_r23d69_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D69_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d70_route
        || plan.r23d71_route
        || plan.r23d74_route
        || plan.r23d76_route
        || plan.r23d78_route
        || !plan.r23d69_route
    {
        return Err("QSDK_R23D69_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d69_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D69_CAMPAIGN_ID,
        "gate_id": R23D69_GATE_ID,
        "stage_id": R23D69_STAGE_ID,
        "engine_id": R23D69_ENGINE_ID,
        "cell_id": format!(
            "r23d69__{R23D69_ENGINE_ID}__s{R23D69_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D69_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D69_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D69_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D69_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D69_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D69_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D69_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d70_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d70_worker_failure_v1",
            "campaign_id": R23D70_CAMPAIGN_ID,
            "gate_id": R23D70_GATE_ID,
            "stage_id": R23D70_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D70_ENGINE_ID,
            "campaign_seed": R23D70_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D70_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d70__{R23D70_ENGINE_ID}__s{R23D70_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D70_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D70_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D70_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D70_ROUTE,
    )
}

pub(crate) fn run_r23d70_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D70_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d69_route
        || plan.r23d71_route
        || plan.r23d74_route
        || plan.r23d76_route
        || plan.r23d78_route
        || !plan.r23d70_route
    {
        return Err("QSDK_R23D70_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d70_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D70_CAMPAIGN_ID,
        "gate_id": R23D70_GATE_ID,
        "stage_id": R23D70_STAGE_ID,
        "engine_id": R23D70_ENGINE_ID,
        "cell_id": format!(
            "r23d70__{R23D70_ENGINE_ID}__s{R23D70_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D70_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D70_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D70_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D70_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D70_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D70_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D70_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "trace_retention_receipt_contract_validator_bound": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d71_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d71_worker_failure_v1",
            "campaign_id": R23D71_CAMPAIGN_ID,
            "gate_id": R23D71_GATE_ID,
            "stage_id": R23D71_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D71_ENGINE_ID,
            "campaign_seed": R23D71_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D71_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d71__{R23D71_ENGINE_ID}__s{R23D71_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D71_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D71_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D71_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D71_ROUTE,
    )
}

pub(crate) fn run_r23d71_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D71_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d69_route
        || plan.r23d70_route
        || !plan.r23d71_route
    {
        return Err("QSDK_R23D71_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d71_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D71_CAMPAIGN_ID,
        "gate_id": R23D71_GATE_ID,
        "stage_id": R23D71_STAGE_ID,
        "engine_id": R23D71_ENGINE_ID,
        "cell_id": format!(
            "r23d71__{R23D71_ENGINE_ID}__s{R23D71_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D71_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
            "campaign_seed": R23D71_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D71_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D71_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D71_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D71_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D71_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "trace_retention_receipt_contract_validator_bound": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d74_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d74_worker_failure_v1",
            "campaign_id": R23D74_CAMPAIGN_ID,
            "gate_id": R23D74_GATE_ID,
            "stage_id": R23D74_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D74_ENGINE_ID,
            "campaign_seed": R23D74_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D74_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d74__{R23D74_ENGINE_ID}__s{R23D74_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D74_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D74_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D74_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D74_ROUTE,
    )
}

pub(crate) fn run_r23d74_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D74_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d69_route
        || plan.r23d70_route
        || plan.r23d71_route
        || !plan.r23d74_route
        || plan.forward_displacement_measurement_origin
            != (ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            })
    {
        return Err("QSDK_R23D74_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    let measurement_origin_preflight = run_forward_displacement_measurement_origin_preflight(
        EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        R23D27_CONTROLLER_STEPS,
    )?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d74_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D74_CAMPAIGN_ID,
        "gate_id": R23D74_GATE_ID,
        "stage_id": R23D74_STAGE_ID,
        "engine_id": R23D74_ENGINE_ID,
        "cell_id": format!(
            "r23d74__{R23D74_ENGINE_ID}__s{R23D74_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D74_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "forward_displacement_measurement_origin_policy_id":
            EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        "forward_displacement_measurement_origin_semantic_step":
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        "forward_displacement_measurement_origin_preflight": measurement_origin_preflight,
        "initial_perturbation": {
            "campaign_seed": R23D74_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D74_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D74_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D74_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D74_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D74_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "trace_retention_receipt_contract_validator_bound": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d76_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d76_worker_failure_v1",
            "campaign_id": R23D76_CAMPAIGN_ID,
            "gate_id": R23D76_GATE_ID,
            "stage_id": R23D76_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D76_ENGINE_ID,
            "campaign_seed": R23D76_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D76_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d76__{R23D76_ENGINE_ID}__s{R23D76_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D76_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D76_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D76_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D76_ROUTE,
    )
}

pub(crate) fn run_r23d76_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D76_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d69_route
        || plan.r23d70_route
        || plan.r23d71_route
        || plan.r23d74_route
        || !plan.r23d76_route
        || plan.forward_displacement_measurement_origin
            != (ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            })
    {
        return Err("QSDK_R23D76_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    let measurement_origin_preflight = run_forward_displacement_measurement_origin_preflight(
        EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        R23D27_CONTROLLER_STEPS,
    )?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d76_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D76_CAMPAIGN_ID,
        "gate_id": R23D76_GATE_ID,
        "stage_id": R23D76_STAGE_ID,
        "engine_id": R23D76_ENGINE_ID,
        "cell_id": format!(
            "r23d76__{R23D76_ENGINE_ID}__s{R23D76_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D76_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "forward_displacement_measurement_origin_policy_id":
            EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        "forward_displacement_measurement_origin_semantic_step":
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        "forward_displacement_measurement_origin_preflight": measurement_origin_preflight,
        "initial_perturbation": {
            "campaign_seed": R23D76_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D76_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D76_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D76_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D76_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D76_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "trace_retention_receipt_contract_validator_bound": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

pub(crate) fn run_r23d78_rapier_physical_core(
    arm_id: &str,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
) -> Result<Value, Value> {
    let mut cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id).map_err(|code| {
        json!({
            "schema_version": "sporespore_qsdk_r23d78_worker_failure_v1",
            "campaign_id": R23D78_CAMPAIGN_ID,
            "gate_id": R23D78_GATE_ID,
            "stage_id": R23D78_STAGE_ID,
            "cell_id": Value::Null,
            "engine_id": R23D78_ENGINE_ID,
            "campaign_seed": R23D78_CAMPAIGN_SEED,
            "arm_id": arm_id,
            "source_commit": source_commit,
            "failure_stage": "before_world",
            "failure_code": code,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "claims": r23d27_claims(),
        })
    })?;
    cell.stage_id = R23D78_STAGE_ID.to_owned();
    cell.cell_id = format!("r23d78__{R23D78_ENGINE_ID}__s{R23D78_CAMPAIGN_SEED}__{arm_id}");
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    if !valid_lower_hex(source_commit, 40) {
        return Err(before_world(
            "QSDK_R23D78_RAP_SOURCE_COMMIT_INVALID".to_owned(),
        ));
    }
    if !attempt_root.is_dir() {
        return Err(before_world(
            "QSDK_R23D78_RAP_ATTEMPT_ROOT_INVALID".to_owned(),
        ));
    }
    run_r23d27_rapier_physical_world(
        cell,
        source_commit,
        attempt_root,
        R23D78_INITIAL_PERTURBATION,
        R23D27PhysicalExecutionPlan::R23D78_ROUTE,
    )
}

pub(crate) fn run_r23d78_rapier_kernel_preflight(arm_id: &str) -> Result<Value, String> {
    let cell = r23d27_cell(R23D65_STAGE_ID, "selected_profile", arm_id)?;
    let plan = R23D27PhysicalExecutionPlan::R23D78_ROUTE;
    if plan.controller_steps != R23D27_CONTROLLER_STEPS
        || plan.terminal_steps != R23D27_TERMINAL_STEPS
        || plan.schedule_semantic_offset != 0
        || plan.turn_start_step != TURN_START_STEP
        || plan.turn_end_step_exclusive != TURN_END_STEP_EXCLUSIVE
        || plan.turning_route
        || plan.r23d66_route
        || plan.r23d67_route
        || plan.r23d68_route
        || plan.r23d69_route
        || plan.r23d70_route
        || plan.r23d71_route
        || plan.r23d74_route
        || plan.r23d76_route
        || !plan.r23d78_route
        || plan.forward_displacement_measurement_origin
            != (ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            })
    {
        return Err("QSDK_R23D78_RAP_EXECUTION_PLAN_INVALID".to_owned());
    }
    let measurement_origin_preflight = run_forward_displacement_measurement_origin_preflight(
        EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        R23D27_CONTROLLER_STEPS,
    )?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d78_rapier_shared_kernel_preflight_v1",
        "campaign_id": R23D78_CAMPAIGN_ID,
        "gate_id": R23D78_GATE_ID,
        "stage_id": R23D78_STAGE_ID,
        "engine_id": R23D78_ENGINE_ID,
        "cell_id": format!(
            "r23d78__{R23D78_ENGINE_ID}__s{R23D78_CAMPAIGN_SEED}__{arm_id}"
        ),
        "campaign_seed": R23D78_CAMPAIGN_SEED,
        "arm_id": arm_id,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "controller_step_count": plan.controller_steps,
        "terminal_step_count": plan.terminal_steps,
        "turn_start_step": plan.turn_start_step,
        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "forward_displacement_measurement_origin_policy_id":
            EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        "forward_displacement_measurement_origin_semantic_step":
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        "forward_displacement_measurement_origin_preflight": measurement_origin_preflight,
        "initial_perturbation": {
            "campaign_seed": R23D78_CAMPAIGN_SEED,
            "fixture_vertical_clearance_m": R23D78_INITIAL_PERTURBATION.vertical_clearance_m,
            "fixture_yaw_rad": R23D78_INITIAL_PERTURBATION.yaw_rad,
            "initial_linear_velocity_world_m_s":
                R23D78_INITIAL_PERTURBATION.linear_velocity_world_m_s,
            "initial_torso_angular_velocity_world_rad_s":
                R23D78_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s,
            "gait_phase_offset_ticks": R23D78_INITIAL_PERTURBATION.gait_phase_offset_ticks,
        },
        "shared_native_kernel_reused": true,
        "complete_production_row_projection_reused": true,
        "trace_retention_receipt_contract_validator_bound": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

fn run_r23d27_rapier_physical_world(
    cell: R23D27Cell,
    source_commit: &str,
    attempt_root: std::path::PathBuf,
    perturbation: InitialPerturbation,
    execution_plan: R23D27PhysicalExecutionPlan,
) -> Result<Value, Value> {
    let before_world =
        |code: String| r23d27_failure(&cell, source_commit, "before_world", &code, 0, 0, None);
    let total_trace_steps = execution_plan.total_trace_steps().map_err(&before_world)?;
    execution_plan
        .forward_displacement_measurement_origin
        .validate(execution_plan.controller_steps)
        .map_err(&before_world)?;
    if execution_plan.controller_steps == 0
        || execution_plan.turn_start_step >= execution_plan.turn_end_step_exclusive
        || execution_plan.turn_end_step_exclusive > execution_plan.controller_steps
        || (execution_plan.turning_route
            && (execution_plan.controller_steps != TURNING_ROUTE_CONTROLLER_STEPS
                || execution_plan.terminal_steps != TURNING_ROUTE_TERMINAL_STEPS
                || cell.cell_id != TURNING_ROUTE_CELL_ID
                || cell.arm_id != "positive_heading"
                || cell.turn_heading_offset_rad != 0.2))
    {
        return Err(before_world(
            "TURNING_ROUTE_RAP_EXECUTION_PLAN_INVALID".to_owned(),
        ));
    }
    let _preflight =
        crate::qsdk_r23d23_composition_recovery::run_qsdk_r23d23_rapier_inherited_composition_preflight(
            crate::qsdk_r23d23_composition_recovery::R23D23_STAGE_ID,
            &cell.arm_id,
        )
        .map_err(&before_world)?;
    let (compiled, controller) = r23d27_compile_boundary(&cell).map_err(&before_world)?;
    let turning_cell =
        r23d3_cell(R23D8_STAGE_ID, "onset_600", &cell.arm_id).map_err(&before_world)?;
    let public_profile_binding = if is_selected_profile_campaign(cell.campaign) {
        Some(resolve_production_public_profile_binding_v1().map_err(&before_world)?)
    } else {
        None
    };

    // The native world-attempt counter becomes one immediately before this
    // sole fixture construction. All authorization and preflight work above is
    // zero-world and therefore cannot accidentally spend the one-shot cell.
    let mut robot = if let Some(binding) = public_profile_binding.as_ref() {
        crate::locomotion::build_bw19v_velocity_only_v4_robot_with_public_profile(
            &compiled,
            AUTHORED_FRICTION as f32,
            binding,
        )
    } else {
        build_bw19v_velocity_only_v4_robot_with_friction(&compiled, AUTHORED_FRICTION as f32)
    }
    .map_err(|code| {
        r23d27_failure(
            &cell,
            source_commit,
            "world_construction_failed",
            &code,
            1,
            0,
            None,
        )
    })?;
    let world_constructed =
        |code: String| r23d27_failure(&cell, source_commit, "world_constructed", &code, 1, 1, None);
    let public_profile_physical_binding = public_profile_binding
        .as_ref()
        .map(|binding| {
            robot.r23d62_public_profile_physical_binding_receipt(
                binding,
                R23D62_HOST_MAPPING_PYTHON_CANONICAL_SHA256,
            )
        })
        .transpose()
        .map_err(&world_constructed)?;
    apply_initial_perturbation(&mut robot, perturbation).map_err(&world_constructed)?;
    for _ in 0..SETTLE_STEPS {
        robot
            .hold_velocity_only_v4_zero_and_step()
            .map_err(&world_constructed)?;
    }
    let settled_failure = |code: String| {
        r23d27_failure(
            &cell,
            source_commit,
            "settlement_complete",
            &code,
            1,
            1,
            None,
        )
    };

    let mut task_origin = robot.torso_position();
    let mut task_origin_reanchor_count = 0_u64;
    let reference_heading_rad = yaw_rad(&robot);
    let initial_contacts = r23d8_limb_contacts(&robot, &compiled).map_err(&settled_failure)?;
    let mut previous_contacts = initial_contacts.clone();
    let mut contact_cycles = BTreeMap::<String, u64>::from_iter(
        initial_contacts.keys().map(|limb_id| (limb_id.clone(), 0)),
    );
    let mut memory = controller.initial_memory();
    let mut neutral_stance_activated = false;
    let mut stability_composition_memory = R23D27CompositionMemory::default();
    let mut taper_state = crate::qsdk_r23d14_tight_gated_horizon::State::default();
    let mut trace_rows = Vec::<Value>::with_capacity(total_trace_steps as usize);
    let mut command_feedback = None::<R23D27CommandFeedback>;
    let mut evidence_window_measurement_origin = None::<[f32; 3]>;

    let mut controller_error_count = 0_u64;
    let mut active_safe_no_actuation_count = 0_u64;
    let mut nonfinite_observation_count = 0_u64;
    let mut actuator_application_mismatch_count = 0_u64;
    let mut validated_portable_command_count = 0_u64;
    let mut native_actuation_application_count = 0_u64;
    let mut portable_impulse_violation_count = 0_u64;
    let mut torso_ground_contact_step_count = 0_u64;
    let terminal_receipt_validation_failure_count = 0_u64;
    let mut maximum_terminal_active_joint_speed = 0.0_f64;
    let mut maximum_tilt_rad = 0.0_f64;
    let mut minimum_torso_height_m = f64::INFINITY;
    let mut maximum_requested = 0.0_f64;
    let mut maximum_held = 0.0_f64;
    let mut steering_saturation_step_count = 0_u64;
    let mut turn_start_yaw_rad = None::<f64>;
    let mut turn_end_yaw_rad = None::<f64>;
    let mut startup_ramp_composition_step_count = 0_u64;
    let mut startup_ramp_active_step_count = 0_u64;
    let mut startup_ramp_exact_zero_scale_step_count = 0_u64;
    let mut startup_ramp_exact_unity_scale_step_count = 0_u64;
    let mut maximum_absolute_startup_ramp_residual_rad_s = 0.0_f64;
    let mut support_loss_state = R23D48SupportLossState::default();
    let is_selected_profile = is_selected_profile_campaign(cell.campaign);

    for semantic_step in 0..execution_plan.controller_steps {
        let ordered_foot_contacts_before = previous_contacts.clone();
        if semantic_step == PHASE_OFFSET_ACTIVATION_STEP {
            apply_phase_offset(&mut memory, perturbation.gait_phase_offset_ticks)
                .map_err(&settled_failure)?;
        }
        if semantic_step == CONTACT_GATED_START_STEP {
            for limb in &mut memory.ordered_limb_memory {
                limb.evidence_gait_step_limit = Some(limb.gait_step + 1 + 1_440);
            }
        }
        let task_origin_reanchored_this_step =
            is_selected_profile && r23d62_task_origin_reanchor_required(semantic_step);
        if task_origin_reanchored_this_step {
            task_origin = robot.torso_position();
            task_origin_reanchor_count += 1;
        }
        let command_time_torso_position = robot.torso_position();
        if execution_plan
            .forward_displacement_measurement_origin
            .semantic_step()
            == Some(semantic_step)
        {
            if evidence_window_measurement_origin.is_some() {
                return Err(settled_failure(
                    "QSDK_RAP_FORWARD_MEASUREMENT_CAPTURE_DUPLICATE".to_owned(),
                ));
            }
            evidence_window_measurement_origin = Some([
                command_time_torso_position.x,
                command_time_torso_position.y,
                command_time_torso_position.z,
            ]);
        }
        let ordered_limb_phase_before = if is_selected_profile {
            Some(r23d62_ordered_limb_phase_before(&memory).map_err(&settled_failure)?)
        } else {
            None
        };
        let phase_mode = if semantic_step < CONTACT_GATED_START_STEP {
            PhaseProgressionMode::Clocked
        } else {
            PhaseProgressionMode::ContactGated
        };
        let state = physical_state_frame(
            &robot,
            &compiled,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
        let schedule_step = semantic_step
            .checked_add(execution_plan.schedule_semantic_offset)
            .ok_or_else(|| {
                settled_failure("TURNING_ROUTE_RAP_SCHEDULE_STEP_OVERFLOW".to_owned())
            })?;
        let schedule = r23d3_schedule(&turning_cell, schedule_step, reference_heading_rad);
        let command = r23d3_motion_command(semantic_step, phase_mode, &schedule);
        if semantic_step == execution_plan.turn_start_step {
            turn_start_yaw_rad = Some(yaw_rad(&robot));
        }
        let output = controller.step(&memory, &state, &command);
        controller_error_count += u64::from(
            output.actuation.receipt.controller_error.is_some()
                || !output.actuation.failure_codes.is_empty(),
        );
        active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
        validate_controller_actuation(&compiled, &output.actuation).map_err(&settled_failure)?;
        if output.actuation.receipt.semantic_step != semantic_step
            || output.actuation.receipt.command_id != command.command_id
            || output.actuation.receipt.policy_id != cell.controller_policy_id
        {
            return Err(settled_failure(
                "QSDK_R23D27_RAP_CONTROLLER_IDENTITY_INVALID".to_owned(),
            ));
        }
        let expected =
            independent_oracle(&state, &command, controller.profile()).map_err(&settled_failure)?;
        let observed = receipt_values(&output.actuation.receipt);
        let oracle_failures = predicate_failures(expected, observed);
        if !oracle_failures.is_empty() {
            return Err(r23d27_failure(
                &cell,
                source_commit,
                "controller_validation_failed",
                &format!(
                    "QSDK_R23D27_RAP_CONTROLLER_RECEIPT_INVALID:{}",
                    oracle_failures.join(",")
                ),
                1,
                1,
                None,
            ));
        }
        let guard_receipt = output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .ok_or_else(|| settled_failure("QSDK_R23D27_RAP_GUARD_RECEIPT_MISSING".to_owned()))?;
        r23d27_validate_guard_receipt(
            cell.campaign,
            &state,
            &memory,
            &output.next_memory,
            guard_receipt,
        )
        .map_err(&settled_failure)?;
        let guard_receipt_json = serde_json::to_value(guard_receipt).map_err(|error| {
            settled_failure(format!("QSDK_R23D27_RAP_GUARD_RECEIPT_JSON:{error}"))
        })?;
        let stability_inputs =
            r23d27_stability_inputs(&robot, &compiled, &output.actuation, &memory, semantic_step)
                .map_err(&settled_failure)?;
        let (startup_residuals, startup_ramp_receipt, support_loss_receipt) =
            if cell.support_loss_conditioned_startup {
                let (residuals, ramp_receipt, support_receipt) =
                    r23d48_support_loss_conditioned_residuals(
                        &compiled,
                        &output.actuation,
                        semantic_step,
                        &ordered_foot_contacts_before,
                        &mut support_loss_state,
                    )
                    .map_err(&settled_failure)?;
                (residuals, ramp_receipt, Some(support_receipt))
            } else if cell.startup_velocity_ramp {
                r23d40_startup_residuals(&compiled, &output.actuation, semantic_step)
                    .map(|(residuals, receipt)| (residuals, receipt, None))
                    .map_err(&settled_failure)?
            } else {
                (
                    zero_residuals(&compiled),
                    R23D40StartupRampReceipt {
                        startup_ramp_id: "none",
                        startup_velocity_scale: 1.0,
                        startup_ramp_active: false,
                        startup_ramp_residual_count: R23D3_ACTUATOR_COUNT as usize,
                        startup_ramp_maximum_absolute_residual_rad_s: 0.0,
                    },
                    None,
                )
            };
        if cell.startup_velocity_ramp {
            startup_ramp_composition_step_count += 1;
            startup_ramp_active_step_count += u64::from(startup_ramp_receipt.startup_ramp_active);
            startup_ramp_exact_zero_scale_step_count +=
                u64::from(startup_ramp_receipt.startup_velocity_scale == 0.0);
            startup_ramp_exact_unity_scale_step_count +=
                u64::from(startup_ramp_receipt.startup_velocity_scale == 1.0);
            maximum_absolute_startup_ramp_residual_rad_s =
                maximum_absolute_startup_ramp_residual_rad_s
                    .max(startup_ramp_receipt.startup_ramp_maximum_absolute_residual_rad_s);
        } else if cell.campaign.gate_id == R23D44_GATE_ID {
            // The R44 control must prove its identity transform on every step,
            // not merely omit the ramp branch.
            startup_ramp_composition_step_count += 1;
            startup_ramp_exact_unity_scale_step_count += 1;
        }
        let (canonical, mapping) =
            map_bw19v_velocity_only_v4(&compiled, &output.actuation, &startup_residuals)
                .map_err(&settled_failure)?;
        let host_profile = VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target();
        mapping
            .validate(&compiled.morphology, &canonical, &host_profile)
            .map_err(|error| {
                settled_failure(format!("QSDK_R23D27_RAP_HOST_MAPPING_INVALID:{error}"))
            })?;
        let ordered_final_canonical_velocities_rad_s: [f64; R23D3_ACTUATOR_COUNT as usize] =
            canonical
                .ordered_commands
                .iter()
                .map(|command| command.combined_canonical_target_velocity_rad_s)
                .collect::<Vec<_>>()
                .try_into()
                .map_err(|_| {
                    settled_failure("QSDK_R23D27_RAP_CANONICAL_COMMAND_COUNT_INVALID".to_owned())
                })?;
        let ordered_actuator_velocity_limits_rad_s: [f64; R23D3_ACTUATOR_COUNT as usize] =
            canonical
                .ordered_commands
                .iter()
                .map(|command| command.maximum_target_speed_rad_s)
                .collect::<Vec<_>>()
                .try_into()
                .map_err(|_| {
                    settled_failure("QSDK_R23D27_RAP_CANONICAL_LIMIT_COUNT_INVALID".to_owned())
                })?;
        maximum_requested =
            maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
        maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
        if output.actuation.receipt.requested_steering_fraction.abs()
            > cell.maximum_steering_fraction + TOLERANCE
            || output.actuation.receipt.held_steering_fraction.abs()
                > cell.maximum_steering_fraction + TOLERANCE
            || output.actuation.receipt.requested_steering_fraction.abs()
                > guard_receipt.effective_maximum_steering_fraction + TOLERANCE
            || output.actuation.receipt.held_steering_fraction.abs()
                > guard_receipt.effective_maximum_steering_fraction + TOLERANCE
        {
            return Err(settled_failure(
                "QSDK_R23D27_RAP_STEERING_CAP_VIOLATION".to_owned(),
            ));
        }
        steering_saturation_step_count += u64::from(output.actuation.receipt.steering_saturated);
        validated_portable_command_count += output.actuation.ordered_commands.len() as u64;
        let controller_step_receipt_sha256 = if is_selected_profile {
            Some(
                digest_serializable(&output.actuation.receipt).map_err(|error| {
                    settled_failure(format!(
                        "QSDK_R23D62_RAP_CONTROLLER_RECEIPT_DIGEST_FAILED:{error}"
                    ))
                })?,
            )
        } else {
            None
        };
        let (applications, impulse_violations, r23d62_native_readback) =
            if let Some(binding) = public_profile_binding.as_ref() {
                let readback = robot
                    .apply_r23d62_public_profile_velocity_only_actuation(
                        &output.actuation,
                        &mapping,
                        binding,
                    )
                    .map_err(&settled_failure)?;
                (
                    readback.native_application_count,
                    readback.impulse_violation_count,
                    Some(readback),
                )
            } else {
                let (applications, impulse_violations) = robot
                    .apply_bw19v_velocity_only_v4_actuation(&mapping)
                    .map_err(&settled_failure)?;
                (applications, impulse_violations, None)
            };
        native_actuation_application_count += applications;
        portable_impulse_violation_count += impulse_violations;
        actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
        memory = output.next_memory;

        let observation = r23d27_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        let ordered_foot_contacts_after = observation.ordered_foot_contacts.clone();
        let feedback_contacts = observation.ordered_foot_contacts.clone();
        let feedback_tilt_rad = observation.torso_tilt_rad;
        if semantic_step >= CONTACT_GATED_START_STEP {
            for (limb_id, contact) in &observation.ordered_foot_contacts {
                if !previous_contacts[limb_id] && *contact {
                    *contact_cycles.get_mut(limb_id).ok_or_else(|| {
                        settled_failure(format!(
                            "QSDK_R23D27_RAP_CONTACT_CYCLE_LIMB_MISSING:{limb_id}"
                        ))
                    })? += 1;
                }
            }
        }
        previous_contacts = ordered_foot_contacts_after.clone();
        if semantic_step + 1 == execution_plan.turn_end_step_exclusive {
            turn_end_yaw_rad = Some(yaw_rad(&robot));
        }
        let completed_state = physical_state_frame(
            &robot,
            &compiled,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        let task_velocities = r23d27_task_velocities(&completed_state).map_err(&settled_failure)?;
        let maximum_joint_error =
            r23d27_maximum_joint_position_error(&completed_state).map_err(&settled_failure)?;
        let r23d62_extension = if is_selected_profile {
            let phases = ordered_limb_phase_before.ok_or_else(|| {
                settled_failure("QSDK_R23D62_RAP_TRACE_PHASES_MISSING".to_owned())
            })?;
            let readback = r23d62_native_readback.as_ref().ok_or_else(|| {
                settled_failure("QSDK_R23D62_RAP_NATIVE_READBACK_MISSING".to_owned())
            })?;
            let receipt_sha256 = controller_step_receipt_sha256.ok_or_else(|| {
                settled_failure("QSDK_R23D62_RAP_CONTROLLER_RECEIPT_DIGEST_MISSING".to_owned())
            })?;
            let actuator_phase_observation = r23d62_actuator_phase_observation(
                semantic_step,
                receipt_sha256,
                &phases,
                &ordered_foot_contacts_before,
                &ordered_foot_contacts_after,
                readback,
            )
            .map_err(&settled_failure)?;
            Some(R23D62TraceExtension {
                task_frame_origin_world_m: [
                    task_origin.x as f64,
                    task_origin.y as f64,
                    task_origin.z as f64,
                ],
                torso_position_world_m: [
                    command_time_torso_position.x as f64,
                    command_time_torso_position.y as f64,
                    command_time_torso_position.z as f64,
                ],
                task_frame_origin_reanchored_this_step: task_origin_reanchored_this_step,
                task_frame_origin_reanchor_count: task_origin_reanchor_count,
                ordered_limb_phase_before: phases,
                actuator_phase_observation,
            })
        } else {
            None
        };
        let trace_row = r23d27_controller_trace_row(
            &cell,
            semantic_step,
            &robot,
            &compiled,
            applications,
            &stability_inputs,
            output.actuation.receipt.requested_steering_fraction,
            output.actuation.receipt.held_steering_fraction,
            output.actuation.receipt.steering_saturated,
            R23D27ControllerTraceObservation {
                task_velocities,
                maximum_joint_error_rad: maximum_joint_error,
                ordered_final_canonical_velocities_rad_s,
                ordered_actuator_velocity_limits_rad_s,
                steering_authority_guard: guard_receipt_json,
                ordered_foot_contacts_before,
                startup_ramp: startup_ramp_receipt,
                support_loss_conditioned_startup: support_loss_receipt,
            },
            r23d62_extension,
        )
        .map_err(&settled_failure)?;
        trace_rows.push(if execution_plan.turning_route {
            turning_route_trace_row(trace_row, semantic_step, &cell, schedule.heading_offset_rad)
                .map_err(&settled_failure)?
        } else if execution_plan.r23d66_route {
            r23d66_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d67_route {
            r23d67_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d68_route {
            r23d68_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d69_route {
            r23d69_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d70_route {
            r23d70_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d71_route {
            r23d71_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d74_route {
            r23d74_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d76_route {
            r23d76_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d78_route {
            r23d78_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
            trace_row
        });
        command_feedback = Some(R23D27CommandFeedback {
            trace_step: semantic_step,
            ordered_foot_contacts: feedback_contacts,
            torso_tilt_rad: feedback_tilt_rad,
            maximum_joint_error_rad: maximum_joint_error,
        });
    }

    for terminal_step in 0..execution_plan.terminal_steps {
        let trace_step = execution_plan.controller_steps + terminal_step;
        let pre_mode = taper_state.mode.clone();
        let (scale_numerator, scale_denominator) =
            crate::qsdk_r23d14_tight_gated_horizon::production_expected_scale(&taper_state)
                .map_err(|error| settled_failure(error.to_owned()))?;
        let scale_numerator = u64::try_from(scale_numerator)
            .map_err(|_| settled_failure("QSDK_R23D27_RAP_TAPER_NUMERATOR_INVALID".to_owned()))?;
        let scale_denominator = u64::try_from(scale_denominator)
            .map_err(|_| settled_failure("QSDK_R23D27_RAP_TAPER_DENOMINATOR_INVALID".to_owned()))?;
        let active = pre_mode != R23D27_PASSIVE_MODE;
        let mut maximum_commanded_speed = None::<f64>;
        let mut planning_availability = None::<&str>;
        let mut support_margin_m = None::<f64>;
        let mut applied_stability_deltas_rad_s = vec![0.0_f64; R23D3_ACTUATOR_COUNT as usize];
        let command_feedback_for_step = command_feedback
            .as_ref()
            .filter(|feedback| feedback.trace_step + 1 == trace_step)
            .ok_or_else(|| {
                settled_failure("QSDK_R23D27_RAP_COMMAND_TIME_FEEDBACK_INVALID".to_owned())
            })?;
        let authority_receipt;
        let applications;
        if active {
            let state = physical_state_frame(
                &robot,
                &compiled,
                trace_step,
                task_origin,
                reference_heading_rad,
            )
            .map_err(&settled_failure)?;
            nonfinite_observation_count += u64::from(state_contains_nonfinite(&state));
            let schedule = r23d3_schedule(&turning_cell, trace_step, reference_heading_rad);
            let command =
                r23d3_motion_command(trace_step, PhaseProgressionMode::ContactGated, &schedule);
            let output = controller.step(&memory, &state, &command);
            controller_error_count += u64::from(
                output.actuation.receipt.controller_error.is_some()
                    || !output.actuation.failure_codes.is_empty(),
            );
            active_safe_no_actuation_count += u64::from(output.actuation.safe_no_actuation);
            validate_controller_actuation(&compiled, &output.actuation)
                .map_err(&settled_failure)?;
            let expected = independent_oracle(&state, &command, controller.profile())
                .map_err(&settled_failure)?;
            let observed = receipt_values(&output.actuation.receipt);
            let oracle_failures = predicate_failures(expected, observed);
            if output.actuation.receipt.semantic_step != trace_step
                || output.actuation.receipt.command_id != command.command_id
                || output.actuation.receipt.policy_id != cell.controller_policy_id
                || !oracle_failures.is_empty()
            {
                return Err(settled_failure(format!(
                    "QSDK_R23D27_RAP_TERMINAL_CONTROLLER_INVALID:{}",
                    oracle_failures.join(",")
                )));
            }
            maximum_requested =
                maximum_requested.max(output.actuation.receipt.requested_steering_fraction.abs());
            maximum_held = maximum_held.max(output.actuation.receipt.held_steering_fraction.abs());
            let stability_inputs =
                r23d27_stability_inputs(&robot, &compiled, &output.actuation, &memory, trace_step)
                    .map_err(&settled_failure)?;
            planning_availability = Some(stability_inputs.availability_name);
            support_margin_m = stability_inputs.support_margin_m;
            let first_activation = !neutral_stance_activated;
            let composition = r23d8_compose_neutral_stance(
                &compiled,
                &output.actuation,
                &state,
                first_activation,
            )
            .map_err(&settled_failure)?;
            let receipt_failures = r23d8_neutral_receipt_failures(
                &composition.receipt,
                &compiled.morphology.ordered_actuator_ids,
            );
            if composition.receipt["semantic_step"] != trace_step || !receipt_failures.is_empty() {
                return Err(settled_failure(format!(
                    "QSDK_R23D27_RAP_TERMINAL_RECEIPT_INVALID:{}",
                    receipt_failures.join(",")
                )));
            }
            let solutions = composition.receipt["ordered_actuator_solutions"]
                .as_array()
                .filter(|rows| rows.len() == R23D3_ACTUATOR_COUNT as usize)
                .ok_or_else(|| {
                    settled_failure("QSDK_R23D27_RAP_TERMINAL_SOLUTIONS_INVALID".to_owned())
                })?;
            let (next_composition_memory, scaled) = r23d27_compose_stability_assisted_taper(
                &compiled,
                &output.actuation,
                &composition,
                &stability_inputs,
                scale_numerator,
                scale_denominator,
                command_feedback_for_step,
                trace_step,
                &stability_composition_memory,
            )
            .map_err(&settled_failure)?;
            stability_composition_memory = next_composition_memory;
            authority_receipt = scaled.authority_receipt;
            applied_stability_deltas_rad_s = scaled.applied_stability_velocity_deltas_rad_s.clone();
            maximum_terminal_active_joint_speed = maximum_terminal_active_joint_speed
                .max(scaled.maximum_absolute_commanded_joint_velocity_rad_s);
            maximum_commanded_speed = Some(scaled.maximum_absolute_commanded_joint_velocity_rad_s);
            validated_portable_command_count += solutions.len() as u64;
            let (step_applications, impulse_violations) = robot
                .apply_bw19v_velocity_only_v4_actuation(&scaled.host_mapping)
                .map_err(&settled_failure)?;
            applications = step_applications;
            native_actuation_application_count += applications;
            portable_impulse_violation_count += impulse_violations;
            actuator_application_mismatch_count += u64::from(applications != R23D3_ACTUATOR_COUNT);
            memory = output.next_memory;
            neutral_stance_activated = true;
        } else {
            robot
                .hold_velocity_only_v4_zero_and_step()
                .map_err(&settled_failure)?;
            applications = 0;
            authority_receipt = r23d27_passive_authority_receipt(scale_numerator);
        }

        let observation = r23d27_observation_fields(&robot, &compiled).map_err(&settled_failure)?;
        nonfinite_observation_count += u64::from(
            !observation.measured_yaw_rad.is_finite()
                || !observation.torso_height_m.is_finite()
                || !observation.torso_tilt_rad.is_finite(),
        );
        maximum_tilt_rad = maximum_tilt_rad.max(observation.torso_tilt_rad);
        minimum_torso_height_m = minimum_torso_height_m.min(observation.torso_height_m);
        torso_ground_contact_step_count += u64::from(observation.torso_ground_contact);
        let completed_state = physical_state_frame(
            &robot,
            &compiled,
            trace_step,
            task_origin,
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
        let task_velocities = r23d27_task_velocities(&completed_state).map_err(&settled_failure)?;
        if !active {
            let passive_stability_state = robot
                .bw19v_stability_state(&compiled, trace_step)
                .map_err(&settled_failure)?;
            support_margin_m = r23d27_support_margin(&compiled, &passive_stability_state)
                .map_err(&settled_failure)?;
        }
        let maximum_joint_error =
            r23d27_maximum_joint_position_error(&completed_state).map_err(&settled_failure)?;
        let (next_taper_state, taper_receipt) = r23d27_observe_taper(
            &taper_state,
            &observation.ordered_foot_contacts,
            observation.torso_tilt_rad,
            maximum_joint_error,
            applications,
            scale_numerator,
            scale_denominator,
        )
        .map_err(&settled_failure)?;
        trace_rows.push(
            r23d27_terminal_trace_row(
                &cell,
                trace_step,
                &pre_mode,
                &taper_receipt,
                command_feedback_for_step,
                &authority_receipt,
                &observation,
                maximum_joint_error,
                maximum_commanded_speed,
                task_velocities,
                support_margin_m,
                planning_availability,
                &applied_stability_deltas_rad_s,
            )
            .map_err(&settled_failure)?,
        );
        command_feedback = Some(R23D27CommandFeedback {
            trace_step,
            ordered_foot_contacts: observation.ordered_foot_contacts.clone(),
            torso_tilt_rad: observation.torso_tilt_rad,
            maximum_joint_error_rad: maximum_joint_error,
        });
        taper_state = next_taper_state;
    }

    let taper_outcome = json!({
        "confirmation_satisfied": false,
        "handoff_after_active_step": Value::Null,
        "first_passive_step": Value::Null,
        "handoff_reason": Value::Null,
        "active_step_count": 0,
        "taper_step_count": 0,
        "passive_step_count": 0,
        "taper_reset_count": 0,
        "active_native_application_count": 0,
        "passive_native_application_count": 0,
        "quiescent_taper_gate_passed": false,
        "first_post_handoff_contact_loss_step": Value::Null,
        "post_handoff_contact_loss_step_count": 0,
    });
    let final_position = robot.torso_position();
    let (final_forward_displacement_m, measurement_origin_receipt) =
        project_forward_displacement_measurement(
            execution_plan.forward_displacement_measurement_origin,
            [task_origin.x, task_origin.y, task_origin.z],
            evidence_window_measurement_origin,
            [final_position.x, final_position.y, final_position.z],
            reference_heading_rad,
        )
        .map_err(&settled_failure)?;
    let turn_phase_yaw_delta_rad = turn_start_yaw_rad
        .zip(turn_end_yaw_rad)
        .map(|(start, end)| wrap_angle(end - start))
        .ok_or_else(|| settled_failure("QSDK_R23D27_RAP_TURN_WINDOW_INCOMPLETE".to_owned()))?;
    let retention = if execution_plan.turning_route {
        turning_route_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d66_route {
        r23d66_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d67_route {
        r23d67_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d68_route {
        r23d68_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d69_route {
        r23d69_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d70_route {
        r23d70_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d71_route {
        r23d71_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d74_route {
        r23d74_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d76_route {
        r23d76_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d78_route {
        r23d78_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
        r23d27_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    };
    let support_loss_composition_integrity_passed = if cell.support_loss_conditioned_startup {
        support_loss_state.next_semantic_step == execution_plan.controller_steps
            && startup_ramp_composition_step_count == execution_plan.controller_steps
            && if execution_plan.turning_route {
                startup_ramp_active_step_count + startup_ramp_exact_unity_scale_step_count
                    == execution_plan.controller_steps
                    && startup_ramp_exact_zero_scale_step_count <= startup_ramp_active_step_count
            } else if support_loss_state.trigger_step.is_some() {
                startup_ramp_active_step_count == R23D40_STARTUP_RAMP_STEPS - 1
                    && startup_ramp_exact_zero_scale_step_count == 1
                    && startup_ramp_exact_unity_scale_step_count
                        == execution_plan.controller_steps - (R23D40_STARTUP_RAMP_STEPS - 1)
            } else {
                startup_ramp_active_step_count == 0
                    && startup_ramp_exact_zero_scale_step_count == 0
                    && startup_ramp_exact_unity_scale_step_count == execution_plan.controller_steps
            }
    } else {
        true
    };
    let mut report = json!({
        "schema_version": cell.campaign.report_schema,
        "campaign_id": cell.campaign.campaign_id,
        "gate_id": cell.campaign.gate_id,
        "stage_id": cell.stage_id,
        "cell_id": cell.cell_id,
        "engine_id": R23D27_ENGINE_ID,
        "candidate_id": cell.candidate_id,
        "controller_policy_id": cell.controller_policy_id,
        "maximum_steering_fraction": cell.maximum_steering_fraction,
        "arm_id": cell.arm_id,
        "campaign_seed": cell.campaign.campaign_seed,
        "turn_heading_offset_rad": cell.turn_heading_offset_rad,
        "source_commit": source_commit,
        "trace_artifact": retention["trace_artifact"].clone(),
        "trace_summary": retention["trace_summary"].clone(),
        "execution": {
            "integrity_passed": true,
            "worker_failure_code": "",
            "controller_semantic_step_count": execution_plan.controller_steps,
            "terminal_quiescent_taper_step_count": execution_plan.terminal_steps,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                taper_outcome["passive_native_application_count"].clone(),
            "portable_impulse_violation_count": portable_impulse_violation_count,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "trace_retained_before_terminal_entry": true,
            "fixed_horizon_configuration_proved_before_fixture_insertion": true,
        },
        "measurements": {
            "final_forward_displacement_m": final_forward_displacement_m,
            "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
            "maximum_absolute_requested_steering_fraction": maximum_requested,
            "maximum_absolute_held_steering_fraction": maximum_held,
            "steering_saturation_step_count": steering_saturation_step_count,
            "maximum_tilt_rad": maximum_tilt_rad,
            "minimum_torso_height_m": minimum_torso_height_m,
            "contact_cycle_count_by_limb": contact_cycles,
            "torso_ground_contact_step_count": torso_ground_contact_step_count,
            "controller_error_count": controller_error_count,
            "active_safe_no_actuation_count": active_safe_no_actuation_count,
            "safe_no_actuation_count": active_safe_no_actuation_count,
            "nonfinite_observation_count": nonfinite_observation_count,
            "actuator_application_mismatch_count": actuator_application_mismatch_count,
            "controller_semantic_step_count": execution_plan.controller_steps,
            "terminal_quiescent_taper_step_count": execution_plan.terminal_steps,
            "validated_portable_command_count": validated_portable_command_count,
            "native_actuation_application_count": native_actuation_application_count,
            "post_handoff_native_actuation_application_count":
                taper_outcome["passive_native_application_count"].clone(),
            "confirmation_satisfied": taper_outcome["confirmation_satisfied"].clone(),
            "handoff_after_active_step": taper_outcome["handoff_after_active_step"].clone(),
            "first_passive_step": taper_outcome["first_passive_step"].clone(),
            "handoff_reason": taper_outcome["handoff_reason"].clone(),
            "active_terminal_step_count": taper_outcome["active_step_count"].clone(),
            "quiescent_taper_step_count": taper_outcome["taper_step_count"].clone(),
            "passive_terminal_step_count": taper_outcome["passive_step_count"].clone(),
            "taper_reset_count": taper_outcome["taper_reset_count"].clone(),
            "active_terminal_native_actuation_application_count":
                taper_outcome["active_native_application_count"].clone(),
            "quiescent_taper_gate_passed":
                taper_outcome["quiescent_taper_gate_passed"].clone(),
            "first_post_handoff_contact_loss_step":
                taper_outcome["first_post_handoff_contact_loss_step"].clone(),
            "post_handoff_contact_loss_step_count":
                taper_outcome["post_handoff_contact_loss_step_count"].clone(),
            "terminal_receipt_validation_failure_count":
                terminal_receipt_validation_failure_count,
            "maximum_absolute_terminal_active_joint_velocity_rad_s":
                maximum_terminal_active_joint_speed,
            "startup_velocity_ramp_enabled": cell.startup_velocity_ramp,
            "startup_ramp_id": if cell.startup_velocity_ramp {
                Value::String(if cell.support_loss_conditioned_startup {
                    R23D48_STARTUP_TRANSFORM_ID.to_owned()
                } else {
                    R23D40_STARTUP_RAMP_ID.to_owned()
                })
            } else {
                Value::Null
            },
            "startup_ramp_step_count": if cell.startup_velocity_ramp {
                Value::from(R23D40_STARTUP_RAMP_STEPS)
            } else {
                Value::Null
            },
            "startup_ramp_composition_step_count": startup_ramp_composition_step_count,
            "startup_ramp_active_step_count": startup_ramp_active_step_count,
            "startup_ramp_exact_zero_scale_step_count":
                startup_ramp_exact_zero_scale_step_count,
            "startup_ramp_exact_unity_scale_step_count":
                startup_ramp_exact_unity_scale_step_count,
            "startup_ramp_composition_integrity_passed":
                if cell.support_loss_conditioned_startup {
                    support_loss_composition_integrity_passed
                } else if cell.campaign.gate_id == R23D44_GATE_ID && !cell.startup_velocity_ramp {
                    startup_ramp_composition_step_count == execution_plan.controller_steps
                        && startup_ramp_active_step_count == 0
                        && startup_ramp_exact_zero_scale_step_count == 0
                        && startup_ramp_exact_unity_scale_step_count == execution_plan.controller_steps
                } else {
                    !cell.startup_velocity_ramp
                        || (startup_ramp_composition_step_count == execution_plan.controller_steps
                        && startup_ramp_active_step_count == R23D40_STARTUP_RAMP_STEPS - 1
                        && startup_ramp_exact_zero_scale_step_count == 1
                        && startup_ramp_exact_unity_scale_step_count
                            == execution_plan.controller_steps - (R23D40_STARTUP_RAMP_STEPS - 1))
                },
            "maximum_absolute_startup_ramp_residual_rad_s":
                maximum_absolute_startup_ramp_residual_rad_s,
            "startup_transform_id": if cell.support_loss_conditioned_startup {
                Value::String(R23D48_STARTUP_TRANSFORM_ID.to_owned())
            } else {
                Value::Null
            },
            "startup_ramp_triggered": support_loss_state.trigger_step.is_some(),
            "startup_ramp_trigger_step": support_loss_state
                .trigger_step
                .map_or(Value::Null, Value::from),
            "startup_probe_minimum_support_count": if cell.support_loss_conditioned_startup {
                Value::from(support_loss_state.minimum_probe_support_count)
            } else {
                Value::Null
            },
            "startup_transform_composition_integrity_passed":
                support_loss_composition_integrity_passed,
        },
        "claims": r23d27_claims(),
    });
    if let Some(receipt) = measurement_origin_receipt {
        let object = report.as_object_mut().ok_or_else(|| {
            settled_failure("QSDK_RAP_FORWARD_MEASUREMENT_REPORT_INVALID".to_owned())
        })?;
        object.insert(
            "forward_displacement_measurement_origin".to_owned(),
            receipt,
        );
    }
    if is_selected_profile {
        let binding = public_profile_binding.as_ref().ok_or_else(|| {
            settled_failure("QSDK_R23D62_RAP_PUBLIC_PROFILE_BINDING_MISSING".to_owned())
        })?;
        let physical_binding = public_profile_physical_binding.ok_or_else(|| {
            settled_failure("QSDK_R23D62_RAP_PHYSICAL_BINDING_RECEIPT_MISSING".to_owned())
        })?;
        let object = report
            .as_object_mut()
            .ok_or_else(|| settled_failure("QSDK_R23D62_RAP_REPORT_NOT_OBJECT".to_owned()))?;
        object.insert(
            "profile_id".to_owned(),
            Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()),
        );
        object.insert(
            "profile_sha256".to_owned(),
            Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
        );
        object.insert(
            "host_mapping_id".to_owned(),
            Value::String(R23D62_HOST_MAPPING_ID.to_owned()),
        );
        object.insert(
            "actuator_cap_profile_resolution_receipt".to_owned(),
            binding.resolution_receipt.clone(),
        );
        object.insert(
            "actuator_cap_profile_host_mapping_receipt".to_owned(),
            binding.host_mapping_receipt.clone(),
        );
        object.insert(
            "actuator_cap_profile_physical_binding_receipt".to_owned(),
            physical_binding,
        );
        object.insert(
            "task_frame_origin_policy_id".to_owned(),
            Value::String(R23D62_TASK_ORIGIN_POLICY_ID.to_owned()),
        );
        object.insert(
            "trace_transport".to_owned(),
            json!({
                "trace_transport_id": selected_profile_trace_transport_id(cell.campaign),
                "trace_transport_engine_id": R23D27_ENGINE_ID,
                "canonical_ndjson": true,
                "full_precision": true,
                "rust_serde_json_full_precision": true,
            }),
        );
    }
    serde_json::to_vec(&report).map_err(|error| {
        r23d27_failure(
            &cell,
            source_commit,
            "cell_report_complete",
            &format!("QSDK_R23D27_RAP_REPORT_SERIALIZATION_FAILED:{error}"),
            1,
            1,
            Some(retention["trace_artifact"].clone()),
        )
    })?;
    Ok(report)
}

#[cfg(any())]
mod legacy_cloned_tests {
    use super::*;
    use crate::qsdk_r23d11_stability_assisted_taper::MAXIMUM_STABILITY_SLEW;

    #[test]
    fn physical_worker_preflight_is_dormant_and_inherits_r23d11_physics() {
        let receipt = run_qsdk_r23d27_rapier_preflight_impl(
            "rapier_stability_guarded_steering_validation",
            "positive_heading",
        )
        .expect("R23D27 Rapier worker preflight");
        assert_eq!(receipt["inherited_r23d11_controller_and_physics"], true);
        assert_eq!(
            receipt["independent_diagnostic_availability_semantics"],
            true
        );
        assert_eq!(receipt["inherited_r23d13_residual_pose_authority"], true);
        assert_eq!(
            receipt["r23d14_tight_gated_horizon_inherited_unchanged"],
            true
        );
        assert_eq!(
            receipt["r23d27_composition_recovery_identity_enabled"],
            true
        );
        assert_eq!(
            receipt["command_time_feedback_is_previous_completed_step"],
            true
        );
        assert_eq!(receipt["physical_worker_implemented"], true);
        assert_eq!(receipt["physical_execution_authorized"], false);
        assert_eq!(receipt["model_construction_count"], 0);
        assert_eq!(receipt["world_attempt_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
    }

    #[test]
    fn production_contract_matches_frozen_composition_and_temporal_identity() {
        let contract = r23d27_contract().expect("R23D27 contract");
        assert_eq!(
            contract["inherited_physical_contract"]["terminal_step_count"],
            R23D27_TERMINAL_STEPS
        );
        assert_eq!(
            contract["inherited_physical_contract"]["terminal_policy_id"],
            "sporespore_tight_gated_acquisition_active600_v1"
        );
        assert_eq!(contract["prospective_matrix"]["stage_id"], R23D27_STAGE_ID);
        let temporal: Value = serde_json::from_str(R23D14_TEMPORAL_PREREGISTRATION_RAW)
            .expect("R23D14 temporal contract");
        assert_eq!(
            temporal["inherited_whole_body_composition"]["maximum_pre_taper_combined_velocity_magnitude_rad_s"],
            MAXIMUM_COMBINED_VELOCITY
        );
        assert_eq!(
            temporal["inherited_residual_pose_authority"]["scale_denominator"],
            R23D27_SCALE_DENOMINATOR
        );
        assert_eq!(R23D27_TOTAL_TRACE_STEPS, 3_952);
        assert_eq!(
            R23D27_TRACE_RETENTION_MARKER,
            "QSDK_R23D27_TRACE_RETENTION "
        );
    }

    #[test]
    fn heading_aligned_nonzero_receipt_oracle_matches_core_and_rejects_legacy_axis() {
        let (compiled, controller) = r23d27_compile_boundary().expect("compile boundary");
        let mut state = synthetic_state_frame(&compiled, heading_quaternion(0.07));
        state.base_pose_world.position_m.x = 0.37;
        state.base_pose_world.position_m.z = 0.23;
        state.base_twist_world.linear_velocity_m_s.x = 0.19;
        state.base_twist_world.linear_velocity_m_s.z = -0.11;
        let command = command_for_arm_boundary("positive_heading", 0.0, 0.2);
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        assert_eq!(
            output.actuation.receipt.policy_id,
            R23D27_CONTROLLER_POLICY_ID
        );

        let expected = independent_oracle(&state, &command, controller.profile())
            .expect("heading-aligned independent oracle");
        let observed = receipt_values(&output.actuation.receipt);
        assert!(predicate_failures(expected, observed).is_empty());

        let legacy_cross_track_error = dot(
            subtract(
                state.base_pose_world.position_m,
                state.task_frame.origin_world_m,
            ),
            state.task_frame.lateral_axis_world_unit,
        );
        let legacy_cross_track_velocity = dot(
            state.base_twist_world.linear_velocity_m_s,
            state.task_frame.lateral_axis_world_unit,
        );
        let requested = 0.2_f64;
        let legacy_desired = (requested
            - controller.profile().cross_track_heading_gain_rad_per_m * legacy_cross_track_error
            - controller
                .profile()
                .cross_track_velocity_heading_gain_rad_per_m_s
                * legacy_cross_track_velocity)
            .clamp(-0.25, 0.25);
        let legacy = [
            legacy_cross_track_error,
            legacy_cross_track_velocity,
            expected[2],
            legacy_desired,
            wrap_angle(expected[2] - legacy_desired),
        ];
        assert!(!predicate_failures(expected, legacy).is_empty());

        for index in 0..RECEIPT_FIELDS.len() {
            let mut mutated = expected;
            mutated[index] += 1.0e-6;
            assert_eq!(predicate_failures(expected, mutated).len(), 1);
        }
    }

    #[test]
    fn stability_is_composed_then_tapered_before_one_rapier_host_mapping() {
        let (compiled, controller) = r23d27_compile_boundary().expect("compile boundary");
        let turning_cell =
            r23d3_cell(R23D8_STAGE_ID, "onset_600", "positive_heading").expect("cell");
        let state = synthetic_state_frame(&compiled, heading_quaternion(0.2));
        let schedule = r23d3_schedule(&turning_cell, 0, state.task_frame.reference_yaw_rad);
        let command = r23d3_motion_command(0, PhaseProgressionMode::Clocked, &schedule);
        let output = controller.step(&BalancedWaveControllerMemory::initial(), &state, &command);
        let neutral = r23d8_compose_neutral_stance(&compiled, &output.actuation, &state, true)
            .expect("neutral composition");
        let stability_inputs = R23D27StabilityInputs {
            raw_velocity_deltas_rad_s: vec![Some(0.04); R23D3_ACTUATOR_COUNT as usize],
            availability: R23D27Availability::Available,
            availability_name: "available",
            support_margin_m: Some(0.01),
        };
        let (_, composed) = r23d27_compose_stability_assisted_taper(
            &compiled,
            &output.actuation,
            &neutral,
            &stability_inputs,
            60,
            120,
            &R23D27CommandFeedback {
                trace_step: R23D27_CONTROLLER_STEPS - 1,
                ordered_foot_contacts: BTreeMap::from([
                    ("front_left".to_owned(), true),
                    ("front_right".to_owned(), true),
                    ("rear_left".to_owned(), true),
                    ("rear_right".to_owned(), true),
                ]),
                torso_tilt_rad: 0.005,
                maximum_joint_error_rad: 0.1,
            },
            R23D27_CONTROLLER_STEPS,
            &R23D27CompositionMemory::default(),
        )
        .expect("stability-assisted composition");
        assert!(
            composed.maximum_absolute_commanded_joint_velocity_rad_s
                <= (MAXIMUM_NEUTRAL_VELOCITY + MAXIMUM_STABILITY_SLEW) * 0.5 + TOLERANCE
        );
        assert_eq!(composed.authority_receipt.applied_scale_numerator, 60);
        assert!(
            composed
                .applied_stability_velocity_deltas_rad_s
                .iter()
                .all(|value| (*value - MAXIMUM_STABILITY_SLEW).abs() <= TOLERANCE)
        );
        for (host, solution) in composed.host_mapping.ordered_commands.iter().zip(
            neutral.receipt["ordered_actuator_solutions"]
                .as_array()
                .expect("solutions"),
        ) {
            let expected = (solution["bounded_velocity_rad_s"]
                .as_f64()
                .expect("velocity")
                + MAXIMUM_STABILITY_SLEW)
                * 0.5;
            assert!((host.host_target_velocity_rad_s - expected).abs() <= TOLERANCE);
            assert!(host.native_target_position_rad.is_none());
        }
    }
}

#[cfg(test)]
mod r23d27_tests {
    use super::*;

    #[test]
    fn forward_measurement_evidence_origin_preflight_is_exact_and_zero_world() {
        let receipt = run_forward_displacement_measurement_origin_preflight(
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            R23D27_CONTROLLER_STEPS,
        )
        .expect("evidence-origin preflight");
        assert_eq!(
            receipt["measurement_origin"]["schema_version"],
            FORWARD_DISPLACEMENT_MEASUREMENT_ORIGIN_SCHEMA
        );
        assert_eq!(
            receipt["measurement_origin"]["policy_id"],
            EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID
        );
        assert_eq!(
            receipt["measurement_origin"]["semantic_step"],
            EVIDENCE_WINDOW_START_SEMANTIC_STEP
        );
        assert_eq!(
            receipt["measurement_origin"]["origin_world_m"],
            json!([0.4_f32, 0.42_f32, -0.01_f32])
        );
        assert_eq!(
            receipt["measurement_origin"]["captured_before_controller_step"],
            true
        );
        assert_eq!(
            receipt["measurement_origin"]["task_frame_reanchors_change_measurement_origin"],
            false
        );
        assert_eq!(receipt["controller_task_origin_unchanged"], true);
        assert_eq!(receipt["model_construction_count"], 0);
        assert_eq!(receipt["world_attempt_count"], 0);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["physical_execution_authorized"], false);
    }

    #[test]
    fn forward_measurement_origin_is_opt_in_and_rejects_mutations() {
        for plan in [
            R23D27PhysicalExecutionPlan::LEGACY,
            R23D27PhysicalExecutionPlan::TURNING_ROUTE,
            R23D27PhysicalExecutionPlan::R23D66_ROUTE,
            R23D27PhysicalExecutionPlan::R23D67_ROUTE,
            R23D27PhysicalExecutionPlan::R23D68_ROUTE,
            R23D27PhysicalExecutionPlan::R23D69_ROUTE,
            R23D27PhysicalExecutionPlan::R23D70_ROUTE,
            R23D27PhysicalExecutionPlan::R23D71_ROUTE,
        ] {
            assert_eq!(
                plan.forward_displacement_measurement_origin,
                ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame
            );
        }

        let evidence_plan = R23D27PhysicalExecutionPlan::R23D71_ROUTE
            .with_evidence_window_measurement_origin(EVIDENCE_WINDOW_START_SEMANTIC_STEP);
        assert_eq!(evidence_plan.controller_steps, R23D27_CONTROLLER_STEPS);
        assert!(evidence_plan.r23d71_route);
        assert_eq!(
            evidence_plan.forward_displacement_measurement_origin,
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            }
        );

        let (legacy_displacement, legacy_receipt) = project_forward_displacement_measurement(
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
            [1.9, 0.42, 0.02],
            None,
            [1.901, 0.42, 0.02],
            0.0,
        )
        .expect("legacy projection");
        assert_eq!(legacy_displacement, (1.901_f32 - 1.9_f32) as f64);
        assert!(legacy_receipt.is_none());

        let (evidence_displacement, evidence_receipt) = project_forward_displacement_measurement(
            evidence_plan.forward_displacement_measurement_origin,
            [1.9, 0.42, 0.02],
            Some([0.4, 0.42, -0.01]),
            [1.901, 0.42, 0.02],
            0.0,
        )
        .expect("evidence projection");
        assert_eq!(evidence_displacement, (1.901_f32 - 0.4_f32) as f64);
        assert!(evidence_receipt.is_some());

        assert_eq!(
            run_forward_displacement_measurement_origin_preflight(
                R23D27_CONTROLLER_STEPS,
                R23D27_CONTROLLER_STEPS,
            ),
            Err("QSDK_RAP_FORWARD_MEASUREMENT_PLAN_INVALID".to_owned())
        );
        assert_eq!(
            project_forward_displacement_measurement(
                evidence_plan.forward_displacement_measurement_origin,
                [1.9, 0.42, 0.02],
                None,
                [1.901, 0.42, 0.02],
                0.0,
            ),
            Err("QSDK_RAP_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_MISSING".to_owned())
        );
        assert_eq!(
            project_forward_displacement_measurement(
                ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
                [1.9, 0.42, 0.02],
                Some([0.4, 0.42, -0.01]),
                [1.901, 0.42, 0.02],
                0.0,
            ),
            Err("QSDK_RAP_FORWARD_MEASUREMENT_LEGACY_CAPTURE_AMBIGUOUS".to_owned())
        );
        assert_eq!(
            project_forward_displacement_measurement(
                evidence_plan.forward_displacement_measurement_origin,
                [1.9, 0.42, 0.02],
                Some([f32::NAN, 0.42, -0.01]),
                [1.901, 0.42, 0.02],
                0.0,
            ),
            Err("QSDK_RAP_FORWARD_MEASUREMENT_EVIDENCE_CAPTURE_INVALID".to_owned())
        );
    }

    #[test]
    fn r23d65_namespaced_campaign_registration_is_exact_and_zero_world() {
        let campaign = r23d27_campaign(R23D65_STAGE_ID).expect("R23D65 campaign registration");
        assert_eq!(campaign.campaign_id, R23D65_CAMPAIGN_ID);
        assert_eq!(campaign.gate_id, R23D65_GATE_ID);
        assert_eq!(campaign.stage_id, R23D65_STAGE_ID);
        assert_eq!(campaign.campaign_seed, R23D65_CAMPAIGN_SEED);
        assert_eq!(campaign.candidate_id, R23D65_CANDIDATE_ID);
        assert_eq!(
            selected_profile_trace_transport_id(campaign),
            R23D65_TRACE_TRANSPORT_ID
        );
        assert!(is_selected_profile_campaign(campaign));
        let perturbation = campaign
            .prospective_initial_perturbation
            .expect("R23D65 prospective perturbation");
        assert_eq!(
            perturbation.linear_velocity_world_m_s,
            R23D65_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            perturbation.torso_angular_velocity_world_rad_s,
            R23D65_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(
            perturbation.gait_phase_offset_ticks,
            R23D65_INITIAL_PERTURBATION.gait_phase_offset_ticks
        );
    }

    #[test]
    fn all_three_cells_preflight_without_world_construction() {
        let candidate_id = "stability_guarded_0p20_to_0p28";
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D27_STAGE_ID, candidate_id, arm_id)
                    .expect("R23D27 preflight");
            assert_eq!(receipt["candidate_id"], candidate_id);
            assert_eq!(receipt["arm_id"], arm_id);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
            assert_eq!(receipt["terminal_taper_invoked"], false);
        }
    }

    #[test]
    #[allow(clippy::assertions_on_constants)]
    fn trace_retention_cli_contract_separates_legacy_and_repo_root_only_evaluators() {
        assert!(R23D27_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(R23D32_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(R23D43_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(R23D44_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(R23D49_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(R23D50_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(!R23D40_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(!R23D41_CAMPAIGN.trace_retain_source_root_argument_required);
        assert!(!R23D42_CAMPAIGN.trace_retain_source_root_argument_required);
    }

    #[test]
    fn r23d43_retention_hardened_worker_preflights_three_cells_without_a_world() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D43_STAGE_ID, R23D43_CANDIDATE_ID, arm_id)
                    .expect("R23D43 preflight");
            assert_eq!(receipt["campaign_id"], R23D43_CAMPAIGN_ID);
            assert_eq!(receipt["candidate_id"], R23D43_CANDIDATE_ID);
            assert_eq!(receipt["arm_id"], arm_id);
            assert_eq!(receipt["production_retention_preflight_required"], true);
            assert_eq!(receipt["failed_child_stdout_and_stderr_bounded"], true);
            assert_eq!(receipt["trace_retain_source_root_argument_required"], true);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
        }
    }

    #[test]
    fn r23d43_child_stream_diagnostics_are_bounded_and_keep_the_tail() {
        let input = format!("{}TAIL", "x".repeat(2_500));
        let excerpt = r23d27_bounded_child_stream(input.as_bytes());
        assert_eq!(excerpt.chars().count(), 2_000);
        assert!(excerpt.ends_with("TAIL"));
        assert!(!excerpt.contains('\0'));
    }

    #[test]
    fn r23d44_paired_worker_preflights_six_cells_with_only_transform_varying() {
        for candidate_id in [R23D44_NO_RAMP_CANDIDATE_ID, R23D44_RAMP_CANDIDATE_ID] {
            for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
                let receipt =
                    run_qsdk_r23d27_rapier_preflight_impl(R23D44_STAGE_ID, candidate_id, arm_id)
                        .expect("R23D44 preflight");
                assert_eq!(receipt["campaign_id"], R23D44_CAMPAIGN_ID);
                assert_eq!(receipt["campaign_seed"], R23D30_CAMPAIGN_SEED);
                assert_eq!(receipt["candidate_id"], candidate_id);
                assert_eq!(receipt["arm_id"], arm_id);
                assert_eq!(
                    receipt["startup_velocity_ramp_enabled"],
                    candidate_id == R23D44_RAMP_CANDIDATE_ID
                );
                assert_eq!(receipt["production_retention_preflight_required"], true);
                assert_eq!(receipt["failed_child_stdout_and_stderr_bounded"], true);
                assert_eq!(receipt["model_construction_count"], 0);
                assert_eq!(receipt["world_attempt_count"], 0);
                assert_eq!(receipt["world_build_count"], 0);
            }
        }
        let contract = r23d27_contract(&R23D44_CAMPAIGN).expect("R23D44 contract");
        let observed = r23d27_initial_perturbation(&R23D44_CAMPAIGN, &contract)
            .expect("R23D44 paired perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D30_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, -1);
    }

    #[test]
    fn independent_guard_oracle_accepts_core_receipt_and_rejects_mutation() {
        let cell = r23d27_cell(
            R23D27_STAGE_ID,
            "stability_guarded_0p20_to_0p28",
            "positive_heading",
        )
        .expect("R23D27 positive cell");
        let (compiled, controller) = r23d27_compile_boundary(&cell).expect("compile boundary");
        let state = synthetic_state_frame(&compiled, heading_quaternion(0.0));
        let command = command_for_arm_boundary("positive_heading", 0.0, 0.2);
        let memory = controller.initial_memory();
        let output = controller.step(&memory, &state, &command);
        let guard = output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .expect("R23D27 guard receipt");
        r23d27_validate_guard_receipt(cell.campaign, &state, &memory, &output.next_memory, guard)
            .expect("independent guard oracle");

        let mut mutated = guard.clone();
        mutated.effective_maximum_steering_fraction += 0.001;
        assert!(
            r23d27_validate_guard_receipt(
                cell.campaign,
                &state,
                &memory,
                &output.next_memory,
                &mutated,
            )
            .is_err()
        );
    }

    #[test]
    fn r23d28_predictive_worker_preflights_and_its_independent_oracle_rejects_mutation() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D28_STAGE_ID, R23D28_CANDIDATE_ID, arm_id)
                    .expect("R23D28 preflight");
            assert_eq!(receipt["campaign_id"], R23D28_CAMPAIGN_ID);
            assert_eq!(receipt["predictive_guard_enabled"], true);
            assert_eq!(receipt["prediction_horizon_s"], 0.6);
            assert_eq!(receipt["world_build_count"], 0);
        }

        let cell = r23d27_cell(R23D28_STAGE_ID, R23D28_CANDIDATE_ID, "positive_heading")
            .expect("R23D28 positive cell");
        let (compiled, controller) = r23d27_compile_boundary(&cell).expect("compile boundary");
        let mut state = synthetic_state_frame(&compiled, heading_quaternion(0.0));
        state.base_twist_world.angular_velocity_rad_s = Vec3 {
            x: 0.15,
            y: 0.0,
            z: 0.0,
        };
        let command = command_for_arm_boundary("positive_heading", 0.0, 0.2);
        let memory = controller.initial_memory();
        let output = controller.step(&memory, &state, &command);
        let guard = output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .expect("R23D28 guard receipt");
        r23d27_validate_guard_receipt(cell.campaign, &state, &memory, &output.next_memory, guard)
            .expect("independent predictive guard oracle");
        assert_eq!(guard.prediction_horizon_s, Some(0.6));
        assert_eq!(guard.prediction_horizon_scheduler_swing_steps, Some(72));

        let mut mutated = guard.clone();
        mutated.predicted_torso_tilt_rad =
            mutated.predicted_torso_tilt_rad.map(|value| value + 0.001);
        assert!(
            r23d27_validate_guard_receipt(
                cell.campaign,
                &state,
                &memory,
                &output.next_memory,
                &mutated,
            )
            .is_err()
        );
    }

    #[test]
    fn r23d29_persistent_worker_preflights_and_transition_oracle_rejects_mutation() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D29_STAGE_ID, R23D29_CANDIDATE_ID, arm_id)
                    .expect("R23D29 preflight");
            assert_eq!(receipt["campaign_id"], R23D29_CAMPAIGN_ID);
            assert_eq!(receipt["predictive_guard_enabled"], true);
            assert_eq!(receipt["persistent_guard_enabled"], true);
            assert_eq!(receipt["prediction_horizon_s"], 0.6);
            assert_eq!(receipt["floor_hold_duration_steps"], 144);
            assert_eq!(
                receipt["controller_memory_schema"],
                BALANCED_WAVE_PERSISTENT_GUARD_MEMORY_VERSION
            );
            assert_eq!(receipt["world_build_count"], 0);
        }

        let cell = r23d27_cell(R23D29_STAGE_ID, R23D29_CANDIDATE_ID, "positive_heading")
            .expect("R23D29 positive cell");
        let (compiled, controller) = r23d27_compile_boundary(&cell).expect("compile boundary");
        let mut state = synthetic_state_frame(&compiled, heading_quaternion(0.10));
        state.base_twist_world.angular_velocity_rad_s = Vec3 {
            x: 0.40,
            y: 0.0,
            z: 0.0,
        };
        let command = command_for_arm_boundary("positive_heading", 0.0, 0.2);
        let memory = controller.initial_memory();
        let output = controller.step(&memory, &state, &command);
        let guard = output
            .actuation
            .receipt
            .steering_authority_guard
            .as_ref()
            .expect("R23D29 guard receipt");
        r23d27_validate_guard_receipt(cell.campaign, &state, &memory, &output.next_memory, guard)
            .expect("independent persistent guard transition oracle");
        assert_eq!(guard.floor_hold_triggered_this_step, Some(true));
        assert_eq!(guard.floor_hold_steps_remaining_after_step, Some(143));

        let mut mutated = guard.clone();
        mutated.floor_hold_steps_remaining_after_step = Some(142);
        assert!(
            r23d27_validate_guard_receipt(
                cell.campaign,
                &state,
                &memory,
                &output.next_memory,
                &mutated,
            )
            .is_err()
        );
    }

    #[test]
    fn r23d30_cycle_coherent_worker_uses_held_out_fixture_without_controller_change() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D30_STAGE_ID, R23D30_CANDIDATE_ID, arm_id)
                    .expect("R23D30 preflight");
            assert_eq!(receipt["campaign_id"], R23D30_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D30_CAMPAIGN_SEED);
            assert_eq!(
                receipt["controller_policy_id"],
                BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            );
            assert_eq!(receipt["persistent_guard_enabled"], true);
            assert_eq!(receipt["floor_hold_duration_steps"], 144);
            assert_eq!(receipt["world_build_count"], 0);
        }
        let contract = r23d27_contract(&R23D30_CAMPAIGN).expect("R23D30 contract");
        let observed = r23d27_initial_perturbation(&R23D30_CAMPAIGN, &contract)
            .expect("R23D30 held-out perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D30_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            observed.torso_angular_velocity_world_rad_s,
            R23D30_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, -1);
    }

    #[test]
    fn r23d31_cycle_integrated_worker_uses_fresh_fixture_without_controller_change() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D31_STAGE_ID, R23D31_CANDIDATE_ID, arm_id)
                    .expect("R23D31 preflight");
            assert_eq!(receipt["campaign_id"], R23D31_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D31_CAMPAIGN_SEED);
            assert_eq!(
                receipt["controller_policy_id"],
                BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            );
            assert_eq!(receipt["persistent_guard_enabled"], true);
            assert_eq!(receipt["floor_hold_duration_steps"], 144);
            assert_eq!(receipt["world_build_count"], 0);
        }
        let contract = r23d27_contract(&R23D31_CAMPAIGN).expect("R23D31 contract");
        let observed = r23d27_initial_perturbation(&R23D31_CAMPAIGN, &contract)
            .expect("R23D31 held-out perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D31_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            observed.torso_angular_velocity_world_rad_s,
            R23D31_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, 2);
    }

    #[test]
    fn r23d32_turning_replication_worker_uses_fresh_fixture_without_behavior_change() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D32_STAGE_ID, R23D32_CANDIDATE_ID, arm_id)
                    .expect("R23D32 preflight");
            assert_eq!(receipt["campaign_id"], R23D32_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D32_CAMPAIGN_SEED);
            assert_eq!(
                receipt["controller_policy_id"],
                BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_STABILITY_GUARDED_STEERING_POLICY_ID
            );
            assert_eq!(receipt["persistent_guard_enabled"], true);
            assert_eq!(receipt["floor_hold_duration_steps"], 144);
            assert_eq!(receipt["world_build_count"], 0);
        }
        let contract = r23d27_contract(&R23D32_CAMPAIGN).expect("R23D32 contract");
        let observed = r23d27_initial_perturbation(&R23D32_CAMPAIGN, &contract)
            .expect("R23D32 held-out perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D32_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            observed.torso_angular_velocity_world_rad_s,
            R23D32_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, 0);
    }

    #[test]
    fn r23d48_support_loss_conditioned_worker_preflights_both_transform_branches() {
        assert_eq!(r23d48_support_loss_canaries(), Ok((true, true)));
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D48_STAGE_ID, R23D48_CANDIDATE_ID, arm_id)
                    .expect("R23D48 preflight");
            assert_eq!(receipt["campaign_id"], R23D48_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D48_CAMPAIGN_SEED);
            assert_eq!(receipt["startup_velocity_ramp_enabled"], true);
            assert_eq!(receipt["support_loss_conditioned_startup_enabled"], true);
            assert_eq!(receipt["startup_ramp_id"], R23D48_STARTUP_TRANSFORM_ID);
            assert_eq!(receipt["support_loss_trigger_branch_canary_passed"], true);
            assert_eq!(receipt["support_loss_identity_branch_canary_passed"], true);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
        }
        let contract = r23d27_contract(&R23D48_CAMPAIGN).expect("R23D48 contract");
        let observed = r23d27_initial_perturbation(&R23D48_CAMPAIGN, &contract)
            .expect("R23D48 held-out perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D48_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, 1);

        let cell = r23d27_cell(R23D48_STAGE_ID, R23D48_CANDIDATE_ID, "reference_zero")
            .expect("R23D48 cell");
        let (compiled, controller) = r23d27_compile_boundary(&cell).expect("compile boundary");
        let state = synthetic_state_frame(&compiled, heading_quaternion(0.0));
        let command = command_for_arm_boundary("reference_zero", 0.0, 0.0);
        let output = controller.step(&controller.initial_memory(), &state, &command);
        let all_support = BTreeMap::from([
            ("rear_left".to_owned(), true),
            ("front_left".to_owned(), true),
            ("rear_right".to_owned(), true),
            ("front_right".to_owned(), true),
        ]);
        let no_support = all_support
            .keys()
            .map(|limb_id| (limb_id.clone(), false))
            .collect::<BTreeMap<_, _>>();
        let mut identity_state = R23D48SupportLossState::default();
        let (identity_residuals, identity_ramp, identity_receipt) =
            r23d48_support_loss_conditioned_residuals(
                &compiled,
                &output.actuation,
                0,
                &all_support,
                &mut identity_state,
            )
            .expect("identity composition");
        assert_eq!(identity_ramp.startup_velocity_scale, 1.0);
        assert!(!identity_receipt.startup_ramp_triggered);
        assert!(
            identity_residuals
                .iter()
                .all(|residual| residual.canonical_velocity_delta_rad_s == 0.0)
        );

        let mut trigger_state = R23D48SupportLossState::default();
        let (trigger_residuals, trigger_ramp, trigger_receipt) =
            r23d48_support_loss_conditioned_residuals(
                &compiled,
                &output.actuation,
                0,
                &no_support,
                &mut trigger_state,
            )
            .expect("trigger composition");
        assert_eq!(trigger_ramp.startup_velocity_scale, 0.0);
        assert_eq!(trigger_receipt.startup_ramp_trigger_step, Some(0));
        for (residual, command) in trigger_residuals
            .iter()
            .zip(output.actuation.ordered_commands.iter())
        {
            let source_canonical = command.target_velocity_rad_s
                * sporespore_locomotion_core::LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN;
            assert_eq!(residual.canonical_velocity_delta_rad_s, -source_canonical);
        }
    }

    #[test]
    fn r23d49_retention_repair_worker_preflights_three_cells_without_a_world() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D49_STAGE_ID, R23D49_CANDIDATE_ID, arm_id)
                    .expect("R23D49 preflight");
            assert_eq!(receipt["campaign_id"], R23D49_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D48_CAMPAIGN_SEED);
            assert_eq!(receipt["candidate_id"], R23D49_CANDIDATE_ID);
            assert_eq!(receipt["arm_id"], arm_id);
            assert_eq!(receipt["startup_velocity_ramp_enabled"], true);
            assert_eq!(receipt["support_loss_conditioned_startup_enabled"], true);
            assert_eq!(receipt["production_retention_preflight_required"], true);
            assert_eq!(receipt["trace_retain_source_root_argument_required"], true);
            assert_eq!(receipt["failed_child_stdout_and_stderr_bounded"], true);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
        }
    }

    #[test]
    fn r23d49_contract_reuses_exact_r48_physics_only_for_outcome_exposed_replay() {
        let contract = r23d27_contract(&R23D49_CAMPAIGN).expect("R23D49 contract");
        let observed = r23d27_initial_perturbation(&R23D49_CAMPAIGN, &contract)
            .expect("R23D49 replay perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D48_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            observed.torso_angular_velocity_world_rad_s,
            R23D48_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, 1);
        assert_eq!(
            contract["frozen_matrix"]["seed_was_outcome_exposed_before_preregistration"],
            true
        );
        assert_eq!(
            contract["implementation_repair_boundary"]["controller_behavior_changed"],
            false
        );
        assert_eq!(
            contract["implementation_repair_boundary"]["physical_threshold_changed"],
            false
        );
    }

    #[test]
    fn r23d50_path_identity_repair_worker_preflights_three_cells_without_a_world() {
        for arm_id in ["reference_zero", "positive_heading", "negative_heading"] {
            let receipt =
                run_qsdk_r23d27_rapier_preflight_impl(R23D50_STAGE_ID, R23D50_CANDIDATE_ID, arm_id)
                    .expect("R23D50 preflight");
            assert_eq!(receipt["campaign_id"], R23D50_CAMPAIGN_ID);
            assert_eq!(receipt["campaign_seed"], R23D48_CAMPAIGN_SEED);
            assert_eq!(receipt["candidate_id"], R23D50_CANDIDATE_ID);
            assert_eq!(receipt["arm_id"], arm_id);
            assert_eq!(receipt["startup_velocity_ramp_enabled"], true);
            assert_eq!(receipt["support_loss_conditioned_startup_enabled"], true);
            assert_eq!(receipt["production_retention_preflight_required"], true);
            assert_eq!(receipt["trace_retain_source_root_argument_required"], true);
            assert_eq!(receipt["failed_child_stdout_and_stderr_bounded"], true);
            assert_eq!(receipt["model_construction_count"], 0);
            assert_eq!(receipt["world_attempt_count"], 0);
            assert_eq!(receipt["world_build_count"], 0);
            assert_eq!(receipt["physical_execution_authorized"], false);
        }
    }

    #[test]
    fn r23d50_contract_reuses_exact_r49_physics_only_for_outcome_exposed_replay() {
        let contract = r23d27_contract(&R23D50_CAMPAIGN).expect("R23D50 contract");
        let observed = r23d27_initial_perturbation(&R23D50_CAMPAIGN, &contract)
            .expect("R23D50 replay perturbation");
        assert_eq!(
            observed.linear_velocity_world_m_s,
            R23D48_INITIAL_PERTURBATION.linear_velocity_world_m_s
        );
        assert_eq!(
            observed.torso_angular_velocity_world_rad_s,
            R23D48_INITIAL_PERTURBATION.torso_angular_velocity_world_rad_s
        );
        assert_eq!(observed.gait_phase_offset_ticks, 1);
        assert_eq!(
            contract["frozen_matrix"]["seed_was_outcome_exposed_before_preregistration"],
            true
        );
        assert_eq!(
            contract["implementation_repair_boundary"]["controller_behavior_changed"],
            false
        );
        assert_eq!(
            contract["implementation_repair_boundary"]["physical_threshold_changed"],
            false
        );
        assert_eq!(
            contract["implementation_repair_boundary"]["complete_cas_binding_verifier_required_before_first_world"],
            true
        );
    }

    #[test]
    fn malformed_candidate_and_arm_fail_closed() {
        assert!(
            run_qsdk_r23d27_rapier_preflight_impl(R23D27_STAGE_ID, "cap_0p40", "positive_heading",)
                .is_err()
        );
        assert!(
            run_qsdk_r23d27_rapier_preflight_impl(
                R23D27_STAGE_ID,
                "stability_guarded_0p20_to_0p28",
                "outcome_selected_arm",
            )
            .is_err()
        );
    }
}
