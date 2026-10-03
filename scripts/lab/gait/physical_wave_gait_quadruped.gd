class_name LabPhysicalWaveGaitQuadruped
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=function-arguments-number

## Development-only continuously scheduled physical quadruped.
##
## The torso and eight leg bodies are ordinary RigidBody3D nodes. Eight
## HingeJoint3D motors provide the only locomotor authority. No force, impulse,
## velocity, position, transform, freeze, or teleport command is applied to the
## torso after fixture release.

const SemanticContactRigidBodyScript := preload(
	"res://scripts/lab/mechanics/semantic_contact_rigid_body.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const QuaternionScalarProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)
const DeferredRecoveryTraceScript := preload(
	"res://sdk/adapters/godot/gdscript/deferred_recovery_trace_v1.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const DynamicSupportObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)
const DynamicSupportReceiptScript := preload(
	"res://scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd"
)
const SdkGodotJoltAdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const SdkGodotJoltLiveFixtureActuatorCapBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_binding.gd"
)
const SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd"
)
const SdkGodotJoltPublicActuatorCapProfileBindingScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd"
)
const SdkGodotJoltTerminalRestorationScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_terminal_restoration.gd"
)
const SdkGodotJoltNeutralStanceScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_neutral_stance.gd"
)
const SdkGodotJoltQuiescentTaperScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd"
)
const SdkGodotJoltR23D14TightGatedHorizonScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d14_tight_gated_horizon.gd"
)
const SdkGodotJoltQuiescentTaperActuationScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_quiescent_taper_actuation.gd"
)
const SdkGodotJoltStabilityAssistedTaperScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd"
)
const SdkGodotJoltStabilityAssistedTaperActuationScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper_actuation.gd"
)
const SdkGodotJoltR23D12MeasurementSemanticsScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d12_measurement_semantics.gd"
)
const SdkGodotJoltR23D13ResidualPoseAuthorityScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d13_residual_pose_authority.gd"
)
const SdkGodotJoltMaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const SdkStartupVelocityRampScript := preload(
	"res://scripts/lab/gait/sdk_startup_velocity_ramp.gd"
)
const SdkSupportLossConditionedStartupScript := preload(
	"res://scripts/lab/gait/sdk_support_loss_conditioned_startup.gd"
)

const PHYSICS_HZ := 120
const LIMB_ORDER := ["rear_left", "front_left", "rear_right", "front_right"]
const GAIT_PHASE_ORDERS := {
	"lateral": ["rear_left", "front_left", "rear_right", "front_right"],
	"diagonal": ["rear_left", "front_right", "rear_right", "front_left"],
	"alternating": ["rear_left", "front_right", "front_left", "rear_right"],
}
const MOTOR_POSITION_GAIN_PER_S := 8.0
const MOTOR_RATE_DAMPING := 0.65
const MAXIMUM_MOTOR_TARGET_SPEED_RAD_S := 3.5
const HIP_FORWARD_TARGET_RAD := 0.30
const HIP_REAR_TARGET_RAD := -0.30
const KNEE_SWING_FLEXION_RAD := 0.82
const SETTLE_TICKS := 240
const CYCLE_TICKS := 360
const SWING_TICKS := 72
const WARMUP_CYCLES := 1
const EVIDENCE_BOUNDARY_ALIGNMENT_TICKS := 112
const EVIDENCE_CYCLES := 3
const COOLDOWN_CYCLES := 1
const TERMINAL_SETTLE_TICKS := 240
const MINIMUM_AIRBORNE_DWELL_TICKS := 3
const MINIMUM_FOOT_RELOCATION_M := 0.012
const MINIMUM_EVIDENCE_TORSO_ADVANCE_M := 0.040
const MINIMUM_FINAL_TORSO_ADVANCE_M := 0.030
const MAXIMUM_LATERAL_DRIFT_M := 0.10
const MAXIMUM_YAW_DRIFT_RAD := 0.45
const MAXIMUM_TILT_RAD := 0.60
const MINIMUM_TORSO_HEIGHT_M := 0.25
const MAXIMUM_ANCHOR_ERROR_M := 0.025
const MAXIMUM_HINGE_AXIS_ERROR_RAD := 0.20
const MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M := 0.002
const MAXIMUM_INITIAL_YAW_PERTURBATION_RAD := 0.010
const MAXIMUM_INITIAL_LINEAR_SPEED_M_S := 0.008
const MAXIMUM_INITIAL_TORSO_ANGULAR_SPEED_RAD_S := 0.008
const MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS := 3
const INITIAL_PERTURBATION_KEYS := [
	"campaign_seed",
	"fixture_vertical_clearance_m",
	"fixture_yaw_rad",
	"initial_linear_velocity_world_m_s",
	"initial_torso_angular_velocity_world_rad_s",
	"gait_phase_offset_ticks",
]
const ROBUSTNESS_OPTION_KEYS := [
	"contact_gated_phase_progression",
	"maximum_contact_gate_hold_ticks",
	"maximum_contact_gated_phase_skew_ticks",
	"lateral_stride_steering_gain_per_m",
]
const PATH_STEERING_OPTION_KEYS := [
	"phase_bounded_path_steering_enabled",
	"cross_track_heading_gain_rad_per_m",
	"yaw_error_stride_gain_per_rad",
	"steering_update_interval_ticks",
	"maximum_desired_heading_error_rad",
	"maximum_steering_fraction",
]
const OPTIONAL_PATH_STEERING_OPTION_KEYS := [
	"cross_track_velocity_heading_gain_rad_per_m_s",
]
const ACTUATOR_IMPULSE_OPTION_KEYS := [
	"mass_adaptive_actuator_enabled",
	"actuator_policy_id",
	"actuator_impulse_scale",
	"hip_impulse_scale",
	"knee_impulse_scale",
]
const MOTOR_VELOCITY_OPTION_KEYS := [
	"mass_adaptive_motor_velocity_enabled",
	"motor_velocity_policy_id",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
	"contact_loaded_swing_knee_activation_start_phase_tick",
	"contact_loaded_swing_knee_full_speed_override_phase_tick",
	"anchor_error_guard_enabled",
	"morphology_interaction_score",
	"anchor_error_guard_activation_fraction",
	"anchor_error_guard_maximum_motor_target_speed_rad_s",
]
const REQUIRED_MOTOR_VELOCITY_OPTION_KEYS := [
	"mass_adaptive_motor_velocity_enabled",
	"motor_velocity_policy_id",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
]
const EVIDENCE_THRESHOLD_OPTION_KEYS := [
	"evidence_threshold_policy_id",
	"minimum_foot_relocation_m",
	"minimum_evidence_torso_advance_m",
	"minimum_final_torso_advance_m",
	"maximum_lateral_drift_m",
	"maximum_yaw_drift_rad",
	"maximum_tilt_rad",
	"minimum_torso_height_m",
	"maximum_anchor_error_m",
	"maximum_hinge_axis_error_rad",
]
const EVIDENCE_THRESHOLD_POLICY_IDS := [
	"reference_metric_thresholds_v1",
	"uniform_scale_dimensionless_thresholds_v1",
	"nonuniform_dimensionless_thresholds_v1",
]
const SOLVER_POLICY_OPTION_KEYS := [
	"solver_policy_id",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
]
const DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS := [
	"enabled",
	"lateral_limit_m",
	"source_digests",
]
const DYNAMIC_SUPPORT_DIAGNOSTIC_VERSIONED_OPTION_KEYS := [
	"enabled",
	"lateral_limit_m",
	"source_digests",
	"receipt_schema_version",
	"policy_id",
	"sample_schema_version",
]
const SDK_SHADOW_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
]
const SDK_SHADOW_EXTENDED_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
]
const SDK_SHADOW_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"material_profile_id",
]
const SDK_SHADOW_CONTROLLER_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"controller_policy_id",
]
const SDK_SHADOW_CONTROLLER_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
]
const SDK_AUTHORITY_EXTENDED_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
]
const SDK_AUTHORITY_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
]
const SDK_AUTHORITY_CONTROLLER_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"stability_influence_global_scale",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"task_frame_origin_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_ORIGIN_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"stability_influence_global_scale",
	"task_frame_origin_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_CAP_BINDING_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"task_frame_origin_policy_id",
	"live_fixture_actuator_cap_binding_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_CAP_FACTORIAL_BINDING_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"task_frame_origin_policy_id",
	"live_fixture_actuator_cap_binding_policy_id",
	"live_fixture_actuator_cap_binding_profile_id",
]
const SDK_HEADING_SCHEDULE_OPTION_KEYS := [
	"schema_version",
	"schedule_id",
	"domain",
	"reference_heading_source",
	"segments",
	"after_last_segment",
]
const SDK_HEADING_SCHEDULE_SEGMENT_KEYS := [
	"segment_id",
	"start_step_inclusive",
	"end_step_exclusive",
	"heading_offset_rad",
	"command_role",
]
const ENVIRONMENT_CHALLENGE_OPTION_KEYS := [
	"challenge_profile_id",
	"terrain_profile_id",
	"terrain_tile_length_m",
	"terrain_tile_count",
	"terrain_origin_x_m",
	"terrain_heights_m",
	"push_profile_id",
	"push_step_from_sdk_start",
	"push_impulse_task_n_s",
	"observation_fault_profile_id",
	"observation_noise_period_steps",
	"base_position_noise_amplitude_m",
	"base_linear_velocity_noise_amplitude_m_s",
	"joint_position_noise_amplitude_rad",
	"joint_velocity_noise_amplitude_rad_s",
	"stability_body_position_noise_amplitude_m",
	"stability_body_velocity_noise_amplitude_m_s",
	"support_point_noise_amplitude_m",
]
const EVIDENCE_ACQUISITION_OPTION_KEYS := [
	"policy_id",
	"enabled",
	"maximum_acquisition_ticks",
	"minimum_all_support_dwell_ticks",
]
const FLAT_TERRAIN_PROFILE_ID := "flat_v1"
const ROUGH_TERRAIN_PROFILE_ID := "rough_height_strip_v1"
const NO_PUSH_PROFILE_ID := "none"
const LATERAL_PUSH_PROFILE_ID := "lateral_impulse_v1"
const NO_OBSERVATION_FAULT_PROFILE_ID := "none"
const DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID := "deterministic_additive_v1"
const MAXIMUM_ROUGH_TERRAIN_ABSOLUTE_HEIGHT_M := 0.025
const MAXIMUM_EXTERNAL_PUSH_IMPULSE_N_S := 0.40
const MAXIMUM_OBSERVATION_POSITION_NOISE_M := 0.010
const MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S := 0.10
const MAXIMUM_OBSERVATION_JOINT_POSITION_NOISE_RAD := 0.020
const MAXIMUM_OBSERVATION_JOINT_VELOCITY_NOISE_RAD_S := 0.10
const SDK_P5I3B_STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const SDK_P5I3C_STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const SDK_BW9L_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_a_v1"
const SDK_BW9L_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_b_v1"
const SDK_BW9L_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_c_v1"
const SDK_BW9L_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_d_v1"
const SDK_BW10F_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_a_v2"
const SDK_BW10F_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_b_v2"
const SDK_BW10F_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_c_v2"
const SDK_BW10F_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_d_v2"
const SDK_BW11R_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_a_v3"
const SDK_BW11R_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_b_v3"
const SDK_BW11R_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_c_v3"
const SDK_BW11R_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_d_v3"
const SDK_BW13P_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const SDK_BW13P_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_b_v3"
const SDK_BW13P_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_c_v3"
const SDK_BW13P_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_d_v3"
const SDK_BW13P_STABILITY_POLICY_IDS := [
	SDK_BW13P_A_STABILITY_POLICY_ID,
	SDK_BW13P_B_STABILITY_POLICY_ID,
	SDK_BW13P_C_STABILITY_POLICY_ID,
	SDK_BW13P_D_STABILITY_POLICY_ID,
]
const SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS := [
	SDK_P5I3C_STABILITY_POLICY_ID,
	SDK_BW9L_A_STABILITY_POLICY_ID,
	SDK_BW9L_B_STABILITY_POLICY_ID,
	SDK_BW9L_C_STABILITY_POLICY_ID,
	SDK_BW9L_D_STABILITY_POLICY_ID,
	SDK_BW10F_A_STABILITY_POLICY_ID,
	SDK_BW10F_B_STABILITY_POLICY_ID,
	SDK_BW10F_C_STABILITY_POLICY_ID,
	SDK_BW10F_D_STABILITY_POLICY_ID,
	SDK_BW11R_A_STABILITY_POLICY_ID,
	SDK_BW11R_B_STABILITY_POLICY_ID,
	SDK_BW11R_C_STABILITY_POLICY_ID,
	SDK_BW11R_D_STABILITY_POLICY_ID,
	SDK_BW13P_A_STABILITY_POLICY_ID,
	SDK_BW13P_B_STABILITY_POLICY_ID,
	SDK_BW13P_C_STABILITY_POLICY_ID,
	SDK_BW13P_D_STABILITY_POLICY_ID,
]
const SDK_CANDIDATE35_POLICY_ID := "g4_gq15_candidate35_v5"
const SDK_BALANCED_WAVE_POLICY_ID := "sporespore_balanced_wave_v1"
const SDK_BALANCED_WAVE_BW2_B_POLICY_ID := "sporespore_balanced_wave_bw2_b_v1"
const SDK_BALANCED_WAVE_BW2_C_POLICY_ID := "sporespore_balanced_wave_bw2_c_v1"
const SDK_BALANCED_WAVE_BW2R_A_POLICY_ID := "sporespore_balanced_wave_bw2r_a_v1"
const SDK_BALANCED_WAVE_BW2R_B_POLICY_ID := "sporespore_balanced_wave_bw2r_b_v1"
const SDK_BALANCED_WAVE_BW2R_C_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const SDK_BALANCED_WAVE_BW4R_A_POLICY_ID := "sporespore_balanced_wave_bw4r_a_v1"
const SDK_BALANCED_WAVE_BW4R_B_POLICY_ID := "sporespore_balanced_wave_bw4r_b_v1"
const SDK_BALANCED_WAVE_BW5R_A_POLICY_ID := "sporespore_balanced_wave_bw5r_a_v1"
const SDK_BALANCED_WAVE_BW5R_B_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SDK_BALANCED_WAVE_BW5R_C_POLICY_ID := "sporespore_balanced_wave_bw5r_c_v1"
const SDK_BALANCED_WAVE_BW7D_A_POLICY_ID := "sporespore_balanced_wave_bw7d_a_v1"
const SDK_BALANCED_WAVE_BW7D_B_POLICY_ID := "sporespore_balanced_wave_bw7d_b_v1"
const SDK_BALANCED_WAVE_BW7D_C_POLICY_ID := "sporespore_balanced_wave_bw7d_c_v1"
const SDK_BALANCED_WAVE_BW7D_D_POLICY_ID := "sporespore_balanced_wave_bw7d_d_v1"
const SDK_BALANCED_WAVE_BW8U_A_POLICY_ID := "sporespore_balanced_wave_bw8u_a_v1"
const SDK_BALANCED_WAVE_BW8U_B_POLICY_ID := "sporespore_balanced_wave_bw8u_b_v1"
const SDK_BALANCED_WAVE_BW8U_C_POLICY_ID := "sporespore_balanced_wave_bw8u_c_v1"
const SDK_BALANCED_WAVE_BW8U_D_POLICY_ID := "sporespore_balanced_wave_bw8u_d_v1"
const SDK_BALANCED_WAVE_BW14V_B_POLICY_ID := "sporespore_balanced_wave_bw14v_b_v1"
const SDK_BALANCED_WAVE_BW15F_B_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const SDK_BALANCED_WAVE_BW15F_C_POLICY_ID := "sporespore_balanced_wave_bw15f_c_v1"
const SDK_BALANCED_WAVE_BW15F_D_POLICY_ID := "sporespore_balanced_wave_bw15f_d_v1"
const SDK_BALANCED_WAVE_BW21L_B_POLICY_ID := "sporespore_balanced_wave_bw21l_b_v1"
const SDK_BALANCED_WAVE_BW21L_C_POLICY_ID := "sporespore_balanced_wave_bw21l_c_v1"
const SDK_BALANCED_WAVE_BW21L_D_POLICY_ID := "sporespore_balanced_wave_bw21l_d_v1"
const SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID := "sporespore_balanced_wave_bw23y_b_v1"
const SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID := "sporespore_balanced_wave_bw34y_a_v1"
const SDK_BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID := "sporespore_balanced_wave_r23d19_heading_aligned_path_v1"
const SDK_BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID := "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1"
const SDK_BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID := "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1"
const SDK_COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID := "command_heading_aligned_task_frame_v1"
const SDK_FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID := "fixed_initial_origin_v1"
const SDK_HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID := (
	"heading_segment_origin_reanchor_v1"
)
const SDK_WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID := (
	"warmup_preserving_command_onset_origin_reanchor_v1"
)
const SDK_TASK_FRAME_ORIGIN_RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_jolt_task_frame_origin_receipt_v1"
)
const LEGACY_EVIDENCE_ACQUISITION_POLICY_ID := "legacy_exact_boundary_v1"
const BOUNDED_EVIDENCE_ACQUISITION_POLICY_ID := "bounded_all_support_acquisition_v1"
const SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT := 1514
const BW31N_AUTHORITY_HORIZON_POLICY_ID := "fixed_candidate_authority_exposure_horizon_v1"
const BW31N_AUTHORITY_HORIZON_POLICY_SHA256 := (
	"sha256:f074fe4004d085c4d763f0b01009c011b91af339fbaf45e42256daa91e2e09ab"
)
const BW32N_AUTHORITY_HORIZON_POLICY_SHA256 := (
	"sha256:ec8291ecd54dbc8299d79d6b3adf176bf67fe851e4bacffc3df253c9a0a605df"
)
const FIXED_AUTHORITY_HORIZON_POLICY_SHA256_VALUES := [
	BW31N_AUTHORITY_HORIZON_POLICY_SHA256,
	BW32N_AUTHORITY_HORIZON_POLICY_SHA256,
]
const BW31N_AUTHORITY_HORIZON_OBSERVATION_COUNT := 3232
const QSDK_R23D3_AUTHORITY_HORIZON_POLICY_ID := "qsdk_r23d3_fixed_controller_horizon_v1"
const QSDK_R23D3_AUTHORITY_HORIZON_POLICY_SHA256 := (
	"sha256:0ea68a8e22eba42ce786faf9256d7986a0f7b0ee2634353856f9f3504e1076db"
)
const QSDK_R23D3_AUTHORITY_HORIZON_OBSERVATION_COUNT := 2992
const TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_POLICY_ID := (
	"sporespore_turning_route_two_step_horizon_v1"
)
const TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_POLICY_SHA256 := (
	"sha256:51c63281ddf18e22b3b68e19db2352dd9b0731e62fc1fb748f756ce3949b41b9"
)
const TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_OBSERVATION_COUNT := 2
const TURNING_ROUTE_GHOST_TRACE_POLICY_ID := "sporespore_turning_route_two_step_trace_v1"
const QSDK_R23D4_AUTHORITY_HORIZON_POLICY_ID := (
	"qsdk_r23d4_fixed_turning_controller_horizon_v1"
)
const QSDK_R23D4_AUTHORITY_HORIZON_POLICY_SHA256 := (
	"sha256:42efe3d41f9115bc12613657668c2bd318367828717169dd14d74f7de0e134e7"
)
const QSDK_R23D4_CONTROLLER_STEP_COUNT := 2992
const QSDK_R23D4_RESTORATION_STEP_COUNT := 540
const QSDK_R23D4_PASSIVE_SETTLE_STEP_COUNT := 240
const QSDK_R23D4_ACTIVE_STEP_COUNT := 3532
const QSDK_R23D4_TOTAL_TRACE_STEP_COUNT := 3772
const QSDK_R23D4_TRACE_SCHEMA := "sporespore_qsdk_r23d4_turn_restore_settle_trace_v1"
const QSDK_R23D4_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d4_turn_restore_settle_trace_row_v1"
)
const QSDK_R23D9_TERMINAL_STEP_COUNT := 780
const QSDK_R23D9_MAXIMUM_ACTIVE_STEP_COUNT := 420
const QSDK_R23D9_SUPPORT_CONFIRMATION_STEP_COUNT := 30
const QSDK_R23D9_MINIMUM_PASSIVE_STEP_COUNT := 360
const QSDK_R23D9_TOTAL_TRACE_STEP_COUNT := 3772
const QSDK_R23D9_HANDOFF_POLICY_ID := (
	"sporespore_support_confirmed_irreversible_passive_handoff_v1"
)
const QSDK_R23D9_ACTIVE_MODE := "active_neutral_acquisition"
const QSDK_R23D9_PASSIVE_MODE := "irreversible_zero_actuation_stability"
const QSDK_R23D9_SUPPORT_REASON := "support_confirmed"
const QSDK_R23D9_DEADLINE_REASON := "deadline_forced_without_support_confirmation"
const QSDK_R23D9_TRACE_SCHEMA := (
	"sporespore_qsdk_r23d9_turn_support_handoff_trace_v1"
)
const QSDK_R23D9_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d9_turn_support_handoff_trace_row_v1"
)
const QSDK_R23D10_TERMINAL_STEP_COUNT := 900
const QSDK_R23D10_MAXIMUM_ACTIVE_STEP_COUNT := 540
const QSDK_R23D10_MINIMUM_TAPER_STEP_COUNT := 120
const QSDK_R23D10_MINIMUM_PASSIVE_STEP_COUNT := 360
const QSDK_R23D10_TOTAL_TRACE_STEP_COUNT := 3892
const QSDK_R23D10_TAPER_POLICY_ID := (
	"sporespore_support_pose_confirmed_quiescent_taper_v1"
)
const QSDK_R23D10_TRACE_SCHEMA := (
	"sporespore_qsdk_r23d10_turn_quiescent_taper_trace_v1"
)
const QSDK_R23D10_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d10_turn_quiescent_taper_trace_row_v1"
)
const QSDK_R23D11_TAPER_POLICY_ID := (
	"sporespore_support_centroid_assisted_quiescent_taper_v1"
)
const QSDK_R23D11_TRACE_SCHEMA := (
	"sporespore_qsdk_r23d11_turn_quiescent_taper_trace_v1"
)
const QSDK_R23D11_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d11_turn_quiescent_taper_trace_row_v1"
)
const QSDK_R23D12_TRACE_SCHEMA := "sporespore_qsdk_r23d12_physical_trace_v1"
const QSDK_R23D12_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d12_physical_trace_row_v1"
const QSDK_R23D13_TRACE_SCHEMA := "sporespore_qsdk_r23d13_physical_trace_v1"
const QSDK_R23D13_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d13_physical_trace_row_v1"
const QSDK_R23D14_TAPER_POLICY_ID := "sporespore_tight_gated_acquisition_active600_v1"
const QSDK_R23D14_TRACE_SCHEMA := "sporespore_qsdk_r23d14_physical_trace_v1"
const QSDK_R23D14_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d14_physical_trace_row_v1"
const QSDK_R23D15_TRACE_SCHEMA := "sporespore_qsdk_r23d15_physical_trace_v1"
const QSDK_R23D15_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d15_physical_trace_row_v1"
const QSDK_R23D16_TRACE_SCHEMA := "sporespore_qsdk_r23d16_physical_trace_v1"
const QSDK_R23D16_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d16_physical_trace_row_v1"
const QSDK_R23D17_TRACE_SCHEMA := "sporespore_qsdk_r23d17_physical_trace_v1"
const QSDK_R23D17_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d17_physical_trace_row_v1"
const QSDK_R23D18_TRACE_SCHEMA := "sporespore_qsdk_r23d18_physical_trace_v1"
const QSDK_R23D18_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d18_physical_trace_row_v1"
const QSDK_R23D19_TRACE_SCHEMA := "sporespore_qsdk_r23d19_physical_trace_v1"
const QSDK_R23D19_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d19_physical_trace_row_v1"
const QSDK_R23D20_TRACE_SCHEMA := "sporespore_qsdk_r23d20_physical_trace_v1"
const QSDK_R23D20_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d20_physical_trace_row_v1"
const QSDK_R23D21_TRACE_SCHEMA := "sporespore_qsdk_r23d21_physical_trace_v1"
const QSDK_R23D21_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d21_physical_trace_row_v1"
const QSDK_R23D14_TERMINAL_STEP_COUNT := 960
const QSDK_R23D14_MAXIMUM_ACTIVE_STEP_COUNT := 600
const QSDK_R23D14_TOTAL_TRACE_STEP_COUNT := 3952
const QSDK_R23D3_PHYSICAL_TRACE_POLICY_ID := "qsdk_r23d3_phase_balanced_trace_v1"
const QSDK_R23D3_PHYSICAL_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d3_turn_diagnostic_trace_row_v1"
)
const QSDK_R10B_RECOVERY_TRACE_POLICY_ID := (
	"qsdk_r10b_bounded_upright_push_recovery_trace_v3"
)
const QSDK_R10B_RECOVERY_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v3"
)
const QSDK_R10B_MINIMUM_CONTROLLER_STEP_COUNT := 2152
const QSDK_R10B_MAXIMUM_CONTROLLER_STEP_COUNT := 2872
const QSDK_R10B_PUSH_MARKER_SEMANTIC_STEP := 540
const QSDK_R10D_RECOVERY_TRACE_POLICY_ID := (
	"qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1"
)
const QSDK_R10D_RECOVERY_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r10d_supported_start_phase_robust_push_recovery_trace_row_v1"
)
const QSDK_R10D_MINIMUM_CONTROLLER_STEP_COUNT := 2152
const QSDK_R10D_MAXIMUM_CONTROLLER_STEP_COUNT := 2872
const QSDK_R10D_PUSH_MARKER_SEMANTIC_STEP := 900
const QSDK_R10E_RECOVERY_TRACE_POLICY_ID := (
	"qsdk_r10e_observer_minimized_upright_push_recovery_trace_v1"
)
const QSDK_R10E_RECOVERY_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r10e_observer_minimized_upright_push_recovery_trace_row_v1"
)
const QSDK_R10E_MINIMUM_CONTROLLER_STEP_COUNT := 2152
const QSDK_R10E_MAXIMUM_CONTROLLER_STEP_COUNT := 2872
const QSDK_R10E_PUSH_MARKER_SEMANTIC_STEP := 900
const QSDK_R10E_NATIVE_IMPULSE_APPLICATION_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r10e_native_impulse_application_receipt_v1"
)
const SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA := (
	"sporespore_godot_jolt_actuator_phase_observation_v1"
)
const SDK_GODOT_FULL_AUTHORITY_APPLICATION_RECEIPT_SCHEMA := (
	"sporespore_godot_jolt_full_authority_application_receipt_v1"
)
const SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_KEYS := [
	"schema_version",
	"semantic_step",
	"controller_step_receipt_sha256",
	"application_receipt_schema_version",
	"ordered_actuator_ids",
	"ordered_limb_ids",
	"readback_tolerance",
	"ordered_applications",
	"after_contact_observation_complete",
	"configured_motor_parameters_only",
	"measured_motor_torque_available",
	"measured_motor_impulse_available",
	"world_build_count",
	"physical_acceptance_authority",
]
const SDK_GODOT_ACTUATOR_PHASE_APPLICATION_KEYS := [
	"actuator_id",
	"joint_id",
	"host_joint_id",
	"limb_id",
	"limb_joint_index",
	"requested_target_position_rad",
	"clamped_target_position_rad",
	"controller_target_velocity_rad_s",
	"maximum_target_speed_rad_s",
	"host_applied_target_velocity_rad_s",
	"motor_target_velocity_readback_rad_s",
	"motor_target_velocity_readback_error_rad_s",
	"declared_maximum_impulse_nms",
	"motor_maximum_impulse_readback_nms",
	"motor_maximum_impulse_readback_error_nms",
	"position_saturated",
	"velocity_saturated",
	"slew_limited",
	"host_additional_clamp_applied",
	"target_velocity_readback_matches",
	"maximum_impulse_readback_matches",
	"local_phase_step_before",
	"gait_step_before",
	"release_hold_step_count_before",
	"foot_contact_before",
	"foot_contact_after",
]
const QSDK_R23D3_ORACLE_TOLERANCE := 1.0e-12
const QSDK_R23D3_MAXIMUM_STEERING_FRACTION := 0.40
const QSDK_R23D3_MAXIMUM_DESIRED_HEADING_ERROR_RAD := 0.25
const DEFAULT_SOLVER_POLICY_ID := "jolt_120hz_20v_6p_v1"
const GP4_SOLVER_POLICY_ID := "jolt_120hz_20v_7p_v1"
const ALLOWED_SOLVER_POLICY_OPTIONS := {
	DEFAULT_SOLVER_POLICY_ID:
	{
		"solver_policy_id": DEFAULT_SOLVER_POLICY_ID,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 6,
	},
	GP4_SOLVER_POLICY_ID:
	{
		"solver_policy_id": GP4_SOLVER_POLICY_ID,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
	},
}
const MINIMUM_ACTUATOR_IMPULSE_SCALE := 0.80
const MAXIMUM_ACTUATOR_IMPULSE_SCALE := 1.25
const MINIMUM_MOTOR_TARGET_SPEED_RAD_S := 0.25
const DEFAULT_MAXIMUM_CONTACT_GATE_HOLD_TICKS := 48
const MAXIMUM_CONTACT_GATE_HOLD_LIMIT_TICKS := 120
const DEFAULT_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS := 12
const MAXIMUM_CONTACT_GATED_PHASE_SKEW_LIMIT_TICKS := 90
const MAXIMUM_CONTACT_GATED_EVIDENCE_EXTENSION_TICKS := 720
const DEFAULT_LATERAL_STRIDE_STEERING_GAIN_PER_M := 0.0
const MAXIMUM_LATERAL_STRIDE_STEERING_GAIN_PER_M := 2.0
const MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION := 0.40


func run(
	tree: SceneTree,
	motor_direction_sign: float = -1.0,
	knee_motor_impulse_scale: float = 10.0,
	knee_flexion_scale: float = 1.75,
	gait_phase_order_id: String = "lateral",
	swing_ticks: int = SWING_TICKS,
	contact_clearance_assist_rad: float = 0.40,
	contact_clearance_assist_limb_id: String = "all",
	evidence_boundary_alignment_ticks: int = EVIDENCE_BOUNDARY_ALIGNMENT_TICKS,
	visible_demo: bool = false,
	requested_initial_perturbation: Dictionary = {},
	requested_robustness_options: Dictionary = {},
	requested_fixture_spec: Dictionary = {},
	requested_path_steering_options: Dictionary = {},
	requested_actuator_impulse_options: Dictionary = {},
	requested_motor_velocity_options: Dictionary = {},
	requested_evidence_threshold_options: Dictionary = {},
	requested_gait_clock_options: Dictionary = {},
	requested_solver_policy_options: Dictionary = {},
	requested_dynamic_support_diagnostic_options: Dictionary = {},
	requested_sdk_shadow_options: Dictionary = {},
	requested_sdk_authority_options: Dictionary = {},
	requested_environment_challenge_options: Dictionary = {},
	requested_evidence_acquisition_options: Dictionary = {},
	preflight_before_world: bool = false,
	requested_candidate_authority_horizon_options: Dictionary = {},
	requested_sdk_heading_schedule_options: Dictionary = {},
	requested_sdk_physical_trace_options: Dictionary = {},
	requested_sdk_terminal_restoration_options: Dictionary = {},
	requested_sdk_startup_velocity_ramp_options: Dictionary = {},
) -> Dictionary:
	if contact_clearance_assist_rad < 0.0:
		return {
			"ok": false,
			"failure_code": "INVALID_CONTACT_CLEARANCE_ASSIST",
			"contact_clearance_assist_rad": contact_clearance_assist_rad,
		}
	if (
		contact_clearance_assist_limb_id != "all"
		and not LIMB_ORDER.has(contact_clearance_assist_limb_id)
	):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_CONTACT_CLEARANCE_ASSIST_LIMB",
			"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		}
	var authority_horizon_result := compile_candidate_authority_horizon_options(
		requested_candidate_authority_horizon_options
	)
	if not bool(authority_horizon_result.get("ok", false)):
		return authority_horizon_result
	var authority_horizon_options: Dictionary = (
		authority_horizon_result.get("candidate_authority_horizon_options", {})
	)
	var authority_horizon_enabled := bool(authority_horizon_options.get("enabled", false))
	var physical_trace_result := compile_sdk_physical_trace_options(
		requested_sdk_physical_trace_options
	)
	if not bool(physical_trace_result.get("ok", false)):
		return physical_trace_result
	var sdk_physical_trace_options: Dictionary = (
		physical_trace_result.get("sdk_physical_trace_options", {})
	)
	var sdk_physical_trace_enabled := bool(sdk_physical_trace_options.get("enabled", false))
	var sdk_recovery_trace_enabled := (
		sdk_physical_trace_enabled
		and _is_qsdk_recovery_trace_policy(
			String(sdk_physical_trace_options.get("policy_id", ""))
		)
	)
	var sdk_deferred_recovery_trace_enabled := (
		sdk_physical_trace_enabled
		and (
			String(sdk_physical_trace_options.get("policy_id", ""))
			== QSDK_R10E_RECOVERY_TRACE_POLICY_ID
		)
	)
	var sdk_deferred_recovery_trace_buffer: Variant = null
	var terminal_restoration_result := compile_sdk_terminal_restoration_options(
		requested_sdk_terminal_restoration_options
	)
	if not bool(terminal_restoration_result.get("ok", false)):
		return terminal_restoration_result
	var sdk_terminal_restoration_options: Dictionary = (
		terminal_restoration_result.get("sdk_terminal_restoration_options", {})
	)
	var sdk_terminal_restoration_enabled := bool(
		sdk_terminal_restoration_options.get("enabled", false)
	)
	var sdk_startup_velocity_ramp_enabled := bool(
		requested_sdk_startup_velocity_ramp_options.get("enabled", false)
	)
	var sdk_startup_velocity_ramp_policy_id := String(
		requested_sdk_startup_velocity_ramp_options.get("policy_id", "")
	)
	if (
		sdk_startup_velocity_ramp_enabled
		and (
			requested_sdk_startup_velocity_ramp_options.keys().size() != 2
			or sdk_startup_velocity_ramp_policy_id
			not in [
				SdkStartupVelocityRampScript.POLICY_ID,
				SdkSupportLossConditionedStartupScript.POLICY_ID,
			]
		)
	):
		return {
			"ok": false,
			"failure_code": "SDK_STARTUP_RAMP_OPTIONS_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var sdk_startup_velocity_ramp_preflight := (
		(
			SdkSupportLossConditionedStartupScript.preflight()
			if sdk_startup_velocity_ramp_policy_id
			== SdkSupportLossConditionedStartupScript.POLICY_ID
			else SdkStartupVelocityRampScript.preflight()
		)
		if sdk_startup_velocity_ramp_enabled
		else {}
	)
	if (
		sdk_startup_velocity_ramp_enabled
		and not bool(sdk_startup_velocity_ramp_preflight.get("ok", false))
	):
		return sdk_startup_velocity_ramp_preflight
	var sdk_terminal_support_handoff_enabled := bool(
		sdk_terminal_restoration_options.get("support_confirmed_handoff_enabled", false)
	)
	var sdk_terminal_quiescent_taper_enabled := bool(
		sdk_terminal_restoration_options.get("quiescent_taper_enabled", false)
	)
	var sdk_terminal_stability_assisted_taper_enabled := bool(
		sdk_terminal_restoration_options.get(
			"stability_assisted_taper_enabled",
			false,
		)
	)
	var sdk_terminal_residual_pose_authority_enabled := bool(
		sdk_terminal_restoration_options.get("residual_pose_authority_enabled", false)
	)
	var sdk_terminal_tight_gated_horizon_enabled := bool(
		sdk_terminal_restoration_options.get("tight_gated_horizon_enabled", false)
	)
	var sdk_terminal_taper_script: Variant = (
		SdkGodotJoltR23D14TightGatedHorizonScript
		if sdk_terminal_tight_gated_horizon_enabled
		else SdkGodotJoltQuiescentTaperScript
	)
	var gait_clock_result := GaitClockSpecScript.compile(requested_gait_clock_options)
	if not bool(gait_clock_result.get("ok", false)):
		return gait_clock_result
	var gait_clock_options: Dictionary = gait_clock_result["gait_clock_options"]
	var physics_hz := int(gait_clock_options["physics_hz"])
	var cycle_ticks := int(gait_clock_options["cycle_ticks"])
	var settle_ticks := int(gait_clock_options["settle_ticks"])
	var terminal_settle_ticks := int(gait_clock_options["terminal_settle_ticks"])
	var warmup_cycles := int(gait_clock_options["warmup_cycles"])
	var evidence_cycles := int(gait_clock_options["evidence_cycles"])
	var cooldown_cycles := int(gait_clock_options["cooldown_cycles"])
	var maximum_contact_gated_evidence_extension_ticks := int(
		gait_clock_options["maximum_contact_gated_evidence_extension_ticks"]
	)
	var minimum_airborne_dwell_ticks := int(gait_clock_options["minimum_airborne_dwell_ticks"])
	var motor_position_gain_per_s := float(gait_clock_options["motor_position_gain_per_s"])
	var motor_rate_damping := float(gait_clock_options["motor_rate_damping"])
	var controller_maximum_motor_target_speed_rad_s := float(
		gait_clock_options["maximum_motor_target_speed_rad_s"]
	)
	if evidence_boundary_alignment_ticks < 0 or evidence_boundary_alignment_ticks >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_BOUNDARY_ALIGNMENT_TICKS",
			"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		}
	if swing_ticks < 1 or swing_ticks > cycle_ticks / LIMB_ORDER.size():
		return {
			"ok": false,
			"failure_code": "INVALID_SWING_TICKS",
			"swing_ticks": swing_ticks,
		}
	var gait_phase_order := _resolve_gait_phase_order(gait_phase_order_id)
	if gait_phase_order.is_empty():
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GAIT_PHASE_ORDER",
			"gait_phase_order_id": gait_phase_order_id,
		}
	var perturbation_result := _normalize_initial_perturbation(requested_initial_perturbation)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var initial_perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var robustness_result := _normalize_robustness_options(requested_robustness_options)
	if not bool(robustness_result.get("ok", false)):
		return robustness_result
	var robustness_options: Dictionary = robustness_result["robustness_options"]
	var path_steering_result := _normalize_path_steering_options(
		requested_path_steering_options,
		cycle_ticks,
	)
	if not bool(path_steering_result.get("ok", false)):
		return path_steering_result
	var path_steering_options: Dictionary = path_steering_result["path_steering_options"]
	var actuator_impulse_result := _normalize_actuator_impulse_options(
		requested_actuator_impulse_options
	)
	if not bool(actuator_impulse_result.get("ok", false)):
		return actuator_impulse_result
	var actuator_impulse_options: Dictionary = actuator_impulse_result["actuator_impulse_options"]
	var motor_velocity_result := _normalize_motor_velocity_options(
		requested_motor_velocity_options,
		cycle_ticks,
	)
	if not bool(motor_velocity_result.get("ok", false)):
		return motor_velocity_result
	var motor_velocity_options: Dictionary = motor_velocity_result["motor_velocity_options"]
	var evidence_threshold_result := compile_evidence_threshold_options(
		requested_evidence_threshold_options
	)
	if not bool(evidence_threshold_result.get("ok", false)):
		return evidence_threshold_result
	var evidence_threshold_options: Dictionary = evidence_threshold_result["evidence_threshold_options"]
	var evidence_threshold_configuration_sha256 := String(
		evidence_threshold_result["evidence_threshold_configuration_sha256"]
	)
	var solver_policy_result := compile_solver_policy_options(requested_solver_policy_options)
	if not bool(solver_policy_result.get("ok", false)):
		return solver_policy_result
	var solver_policy_options: Dictionary = solver_policy_result["solver_policy_options"]
	var solver_policy_configuration_sha256 := String(
		solver_policy_result["solver_policy_configuration_sha256"]
	)
	var dynamic_support_options_result := _normalize_dynamic_support_diagnostic_options(
		requested_dynamic_support_diagnostic_options
	)
	if not bool(dynamic_support_options_result.get("ok", false)):
		return dynamic_support_options_result
	var dynamic_support_options: Dictionary = dynamic_support_options_result["dynamic_support_diagnostic_options"]
	var sdk_shadow_options_result := _normalize_sdk_shadow_options(requested_sdk_shadow_options)
	if not bool(sdk_shadow_options_result.get("ok", false)):
		return sdk_shadow_options_result
	var sdk_shadow_options: Dictionary = sdk_shadow_options_result["sdk_shadow_options"]
	var sdk_shadow_enabled := bool(sdk_shadow_options["enabled"])
	var sdk_authority_options_result := _normalize_sdk_authority_options(
		requested_sdk_authority_options
	)
	if not bool(sdk_authority_options_result.get("ok", false)):
		return sdk_authority_options_result
	var sdk_authority_options: Dictionary = sdk_authority_options_result["sdk_authority_options"]
	var sdk_heading_schedule_result := compile_sdk_heading_schedule_options(
		requested_sdk_heading_schedule_options
	)
	if not bool(sdk_heading_schedule_result.get("ok", false)):
		return sdk_heading_schedule_result
	var sdk_heading_schedule_options: Dictionary = (
		sdk_heading_schedule_result["sdk_heading_schedule_options"]
	)
	var sdk_heading_schedule_sha256 := String(
		sdk_heading_schedule_result["sdk_heading_schedule_sha256"]
	)
	var environment_challenge_result := compile_environment_challenge_options(
		requested_environment_challenge_options
	)
	if not bool(environment_challenge_result.get("ok", false)):
		return environment_challenge_result
	var environment_challenge_options: Dictionary = environment_challenge_result["environment_challenge_options"]
	var environment_challenge_configuration_sha256 := String(
		environment_challenge_result["environment_challenge_configuration_sha256"]
	)
	var evidence_acquisition_result := compile_evidence_acquisition_options(
		requested_evidence_acquisition_options,
		int(gait_clock_options["maximum_contact_gated_phase_skew_ticks"]),
		minimum_airborne_dwell_ticks,
	)
	if not bool(evidence_acquisition_result.get("ok", false)):
		return evidence_acquisition_result
	var evidence_acquisition_options: Dictionary = evidence_acquisition_result["evidence_acquisition_options"]
	var evidence_acquisition_configuration_sha256 := String(
		evidence_acquisition_result["evidence_acquisition_configuration_sha256"]
	)
	var sdk_authority_enabled := bool(sdk_authority_options["enabled"])
	var sdk_authority_scope := String(sdk_authority_options["authority_scope"])
	var sdk_live_fixture_actuator_cap_binding_enabled := sdk_authority_options.has(
		"live_fixture_actuator_cap_binding_policy_id"
	)
	var sdk_heading_schedule_enabled := bool(sdk_heading_schedule_options["enabled"])
	if (
		sdk_terminal_restoration_enabled
		and (
			not authority_horizon_enabled
			or String(authority_horizon_options.get("policy_id", ""))
			!= QSDK_R23D4_AUTHORITY_HORIZON_POLICY_ID
			or int(
				authority_horizon_options.get(
					"exact_candidate_authority_observation_count",
					-1,
				)
			) != QSDK_R23D4_CONTROLLER_STEP_COUNT
			or not sdk_authority_enabled
			or sdk_authority_scope != "post_settle_full"
			or not sdk_heading_schedule_enabled
			or sdk_physical_trace_enabled
		)
	):
		return {
			"ok": false,
			"failure_code": "SDK_TERMINAL_RESTORATION_EXECUTION_CONFIGURATION_INVALID",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var sdk_physical_trace_execution_configuration_valid := true
	if sdk_physical_trace_enabled:
		if sdk_recovery_trace_enabled:
			sdk_physical_trace_execution_configuration_valid = (
				not authority_horizon_enabled
				and sdk_authority_enabled
				and sdk_authority_scope == "post_settle_full"
				and not sdk_heading_schedule_enabled
				and not sdk_terminal_restoration_enabled
			)
		else:
			sdk_physical_trace_execution_configuration_valid = (
				authority_horizon_enabled
				and sdk_authority_enabled
				and sdk_authority_scope == "post_settle_full"
				and sdk_heading_schedule_enabled
				and (
					int(
						authority_horizon_options.get(
							"exact_candidate_authority_observation_count",
							-1,
						)
					)
					== int(sdk_physical_trace_options.get("exact_controller_step_count", -2))
				)
			)
	if sdk_physical_trace_enabled and not sdk_physical_trace_execution_configuration_valid:
		return {
			"ok": false,
			"failure_code": "SDK_PHYSICAL_TRACE_EXECUTION_CONFIGURATION_INVALID",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	if sdk_deferred_recovery_trace_enabled:
		var deferred_trace_prepare_result := DeferredRecoveryTraceScript.prepare(
			sdk_physical_trace_options
		)
		if not bool(deferred_trace_prepare_result.get("ok", false)):
			return deferred_trace_prepare_result
		sdk_deferred_recovery_trace_buffer = deferred_trace_prepare_result.get("buffer", null)
	if sdk_heading_schedule_enabled and not sdk_authority_enabled:
		return {
			"ok": false,
			"failure_code": "SDK_HEADING_SCHEDULE_REQUIRES_AUTHORITY",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if sdk_shadow_enabled and sdk_authority_enabled:
		return {
			"ok": false,
			"failure_code": "SDK_ADAPTER_EXECUTION_MODES_MUTUALLY_EXCLUSIVE",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var sdk_adapter_enabled := sdk_shadow_enabled or sdk_authority_enabled
	var sdk_adapter_options := (
		sdk_authority_options if sdk_authority_enabled else sdk_shadow_options
	)
	var sdk_execution_mode_plan := compile_sdk_execution_mode_plan(
		sdk_adapter_enabled,
		sdk_authority_enabled,
		sdk_authority_scope,
		String(sdk_adapter_options.get("stability_policy_id", "")),
		int(initial_perturbation.get("gait_phase_offset_ticks", 0)),
	)
	if not bool(sdk_execution_mode_plan.get("ok", false)):
		return sdk_execution_mode_plan
	var sdk_full_post_settle_authority_enabled := bool(
		sdk_execution_mode_plan["full_post_settle_authority_enabled"],
	)
	var sdk_stability_overlay_enabled := bool(
		sdk_execution_mode_plan["stability_contribution_overlay_enabled"],
	)
	var sdk_full_authority_stability_contribution_enabled := bool(
		sdk_execution_mode_plan["full_authority_stability_contribution_enabled"],
	)
	var sdk_p5i3c_fixed_exposure_enabled := bool(
		sdk_execution_mode_plan["fixed_exposure_enabled"],
	)
	var hip_impulse_scale := 1.0
	var knee_impulse_scale := 1.0
	if actuator_impulse_options.has("actuator_impulse_scale"):
		hip_impulse_scale = float(actuator_impulse_options["actuator_impulse_scale"])
		knee_impulse_scale = hip_impulse_scale
	else:
		hip_impulse_scale = float(actuator_impulse_options["hip_impulse_scale"])
		knee_impulse_scale = float(actuator_impulse_options["knee_impulse_scale"])
	if (
		bool(path_steering_options["phase_bounded_path_steering_enabled"])
		and float(robustness_options["lateral_stride_steering_gain_per_m"]) > 0.0
	):
		return {
			"ok": false,
			"failure_code": "CONFLICTING_LATERAL_STEERING_CONTROLLERS",
			"world_build_count": 0,
		}
	if (
		String(gait_clock_options["policy_id"]) == GaitClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID
		and (
			swing_ticks != int(gait_clock_options["swing_ticks"])
			or (
				evidence_boundary_alignment_ticks
				!= int(gait_clock_options["evidence_boundary_alignment_ticks"])
			)
			or (
				int(robustness_options["maximum_contact_gate_hold_ticks"])
				!= int(gait_clock_options["maximum_contact_gate_hold_ticks"])
			)
			or (
				int(robustness_options["maximum_contact_gated_phase_skew_ticks"])
				!= int(gait_clock_options["maximum_contact_gated_phase_skew_ticks"])
			)
			or (
				int(path_steering_options["steering_update_interval_ticks"])
				!= int(gait_clock_options["steering_update_interval_ticks"])
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "DYNAMIC_GAIT_CLOCK_RECEIPT_MISMATCH",
			"world_build_count": 0,
		}
	var fixture_spec_result := FixtureSpecScript.compile(requested_fixture_spec)
	if not bool(fixture_spec_result.get("ok", false)):
		return fixture_spec_result
	var fixture_spec: Dictionary = fixture_spec_result["fixture_spec"]
	var fixture_spec_sha256 := String(fixture_spec_result["fixture_spec_sha256"])
	var controller_configuration := _controller_configuration(
		motor_direction_sign,
		knee_motor_impulse_scale,
		knee_flexion_scale,
		gait_phase_order_id,
		gait_phase_order,
		swing_ticks,
		contact_clearance_assist_rad,
		contact_clearance_assist_limb_id,
		evidence_boundary_alignment_ticks,
		robustness_options,
		path_steering_options,
		actuator_impulse_options,
		motor_velocity_options,
		gait_clock_options,
	)
	var controller_configuration_sha256 := CanonicalJsonScript.sha256(controller_configuration)
	if sdk_adapter_enabled:
		var sdk_shadow_configuration_failure := _sdk_shadow_configuration_failure(
			motor_direction_sign,
			knee_flexion_scale,
			gait_phase_order_id,
			swing_ticks,
			contact_clearance_assist_rad,
			contact_clearance_assist_limb_id,
			initial_perturbation,
			robustness_options,
			path_steering_options,
			gait_clock_options,
			sdk_full_post_settle_authority_enabled,
			sdk_p5i3c_fixed_exposure_enabled,
		)
		if not sdk_shadow_configuration_failure.is_empty():
			return {
				"ok": false,
				"failure_code": sdk_shadow_configuration_failure,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
	var original_hz := Engine.physics_ticks_per_second
	var physics_engine := String(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
	var solver_velocity_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
	)
	var solver_position_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
	)
	var realized_solver_policy_options := {
		"solver_policy_id": String(solver_policy_options["solver_policy_id"]),
		"physics_engine": physics_engine,
		"physics_hz": physics_hz,
		"solver_velocity_steps": solver_velocity_steps,
		"solver_position_steps": solver_position_steps,
	}
	var solver_policy_realized := realized_solver_policy_options == solver_policy_options
	if not solver_policy_realized:
		Engine.physics_ticks_per_second = original_hz
		return {
			"ok": false,
			"failure_code": "REALIZED_SOLVER_POLICY_MISMATCH",
			"solver_policy_options": solver_policy_options.duplicate(true),
			"realized_solver_policy_options": realized_solver_policy_options.duplicate(true),
			"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
			"world_build_count": 0,
		}
	var sdk_material_profile: Dictionary = {}
	var sdk_material_profile_sha256 := ""
	if sdk_adapter_enabled:
		var material_profile_result := (
			SdkGodotJoltMaterialProfilesScript
			. validate_for_fixture(
				String(
					(
						sdk_adapter_options
						. get(
							"material_profile_id",
							SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
						)
					)
				),
				fixture_spec["contact_material"],
				realized_solver_policy_options,
			)
		)
		if not bool(material_profile_result.get("ok", false)):
			Engine.physics_ticks_per_second = original_hz
			return {
				"ok": false,
				"failure_code":
				(
					"SDK_MATERIAL_PROFILE_INVALID:%s"
					% String(material_profile_result.get("failure_code", ""))
				),
				"failure_detail": String(material_profile_result.get("failure_detail", "")),
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		sdk_material_profile = (material_profile_result["profile"] as Dictionary).duplicate(true)
		sdk_material_profile_sha256 = String(material_profile_result["profile_sha256"])
	var sdk_transport_execution_receipt := {
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"transport_execution_version": "",
		"transport_execution_contract": {},
		"transport_execution_contract_sha256": "",
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if sdk_adapter_enabled:
		sdk_transport_execution_receipt = (
			SdkGodotJoltAdapterScript.preflight_transport_execution()
		)
		if not bool(sdk_transport_execution_receipt.get("ok", false)):
			Engine.physics_ticks_per_second = original_hz
			return {
				"ok": false,
				"failure_code":
				(
					"SDK_TRANSPORT_PREFLIGHT_FAILED:%s"
					% String(sdk_transport_execution_receipt.get("failure_code", ""))
				),
				"sdk_transport_execution_receipt":
				sdk_transport_execution_receipt.duplicate(true),
				"world_build_count": 0,
				"scene_tree_insertion_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
	if preflight_before_world:
		return {
			"ok": true,
			"failure_code": "",
			"schema_version": "physical_wave_gait_pre_world_entrypoint_preflight_v1",
			"entrypoint_control_flow_complete": true,
			"declared_controller_policy_id":
			String(sdk_authority_options.get("controller_policy_id", "")),
			"declared_stability_policy_id":
			String(sdk_authority_options.get("stability_policy_id", "")),
			"authority_scope": String(sdk_authority_options.get("authority_scope", "")),
			"sdk_live_fixture_actuator_cap_binding_enabled": (
				sdk_live_fixture_actuator_cap_binding_enabled
			),
			"sdk_live_fixture_actuator_cap_binding_policy_id": String(
				sdk_authority_options.get(
					"live_fixture_actuator_cap_binding_policy_id",
					"",
				)
			),
			"sdk_live_fixture_actuator_cap_binding_profile_id": String(
				sdk_authority_options.get(
					"live_fixture_actuator_cap_binding_profile_id",
					"",
				)
			),
			"sdk_live_fixture_actuator_cap_binding_executed": false,
			"candidate_authority_horizon_enabled": authority_horizon_enabled,
			"authority_horizon_policy_id": String(
				authority_horizon_options.get("policy_id", "")
			),
			"authority_horizon_policy_sha256": String(
				authority_horizon_options.get("policy_sha256", "")
			),
			"candidate_authority_observation_count": int(
				authority_horizon_options.get("exact_candidate_authority_observation_count", 0)
			),
			"first_candidate_authority_observation_index": int(
				authority_horizon_options.get("first_candidate_authority_observation_index", -1)
			),
			"last_candidate_authority_observation_index": int(
				authority_horizon_options.get("last_candidate_authority_observation_index", -1)
			),
			"candidate_specific_horizon_extension_count": int(
				authority_horizon_options.get("candidate_specific_horizon_extension_count", -1)
			),
			"sdk_execution_mode_plan": sdk_execution_mode_plan.duplicate(true),
			"fixture_spec_sha256": fixture_spec_sha256,
			"controller_configuration_sha256": controller_configuration_sha256,
			"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
			"material_profile_sha256": sdk_material_profile_sha256,
			"sdk_heading_schedule_enabled": sdk_heading_schedule_enabled,
			"sdk_heading_schedule_sha256": sdk_heading_schedule_sha256,
			"sdk_heading_schedule_options":
			sdk_heading_schedule_options.duplicate(true),
			"sdk_physical_trace_enabled": sdk_physical_trace_enabled,
			"sdk_physical_trace_options": sdk_physical_trace_options.duplicate(true),
			"sdk_physical_trace_configuration_sha256": String(
				physical_trace_result.get("sdk_physical_trace_configuration_sha256", "")
			),
			"sdk_terminal_restoration_enabled": sdk_terminal_restoration_enabled,
			"sdk_terminal_restoration_options": (
				sdk_terminal_restoration_options.duplicate(true)
			),
			"sdk_terminal_restoration_configuration_sha256": String(
				terminal_restoration_result.get(
					"sdk_terminal_restoration_configuration_sha256",
					"",
				)
			),
			"sdk_startup_velocity_ramp_enabled": sdk_startup_velocity_ramp_enabled,
			"sdk_startup_velocity_ramp_preflight":
			sdk_startup_velocity_ramp_preflight.duplicate(true),
			"sdk_transport_execution_receipt":
			sdk_transport_execution_receipt.duplicate(true),
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
	var sdk_public_profile_preworld_binding_preparation: Dictionary = {}
	if (
		sdk_live_fixture_actuator_cap_binding_enabled
		and String(
			sdk_adapter_options.get(
				"live_fixture_actuator_cap_binding_policy_id",
				"",
			)
		)
		== SdkGodotJoltPublicActuatorCapProfileBindingScript.POLICY_ID
	):
		sdk_public_profile_preworld_binding_preparation = (
			prepare_sdk_public_profile_actuator_cap_binding_before_world(
				fixture_spec,
				knee_motor_impulse_scale,
				hip_impulse_scale,
				knee_impulse_scale,
				initial_perturbation,
				float(sdk_adapter_options["comparison_tolerance"]),
				String(
					sdk_adapter_options[
						"live_fixture_actuator_cap_binding_policy_id"
					]
				),
				String(
					sdk_adapter_options.get(
						"live_fixture_actuator_cap_binding_profile_id",
						"",
					)
				),
				(sdk_authority_options.get("descriptor", {}) as Dictionary),
			)
		)
		if not bool(
			sdk_public_profile_preworld_binding_preparation.get("ok", false)
		):
			free_sdk_live_fixture_actuator_cap_binding_surface(
				(
					sdk_public_profile_preworld_binding_preparation.get(
						"actuator_cap_surface",
						{},
					) as Dictionary
				)
			)
			var preworld_failure := (
				sdk_public_profile_preworld_binding_preparation.duplicate(true)
			)
			preworld_failure.erase("actuator_cap_surface")
			return preworld_failure
	Engine.physics_ticks_per_second = physics_hz
	var fixture := await _build_fixture(
		tree,
		knee_motor_impulse_scale,
		hip_impulse_scale,
		knee_impulse_scale,
		visible_demo,
		initial_perturbation,
		fixture_spec,
		environment_challenge_options,
		(
			(
				sdk_public_profile_preworld_binding_preparation.get(
					"actuator_cap_surface",
					{},
				) as Dictionary
			)
		),
	)
	if not bool(fixture.get("ok", false)):
		free_sdk_live_fixture_actuator_cap_binding_surface(
			(
				sdk_public_profile_preworld_binding_preparation.get(
					"actuator_cap_surface",
					{},
				) as Dictionary
			)
		)
		Engine.physics_ticks_per_second = original_hz
		return fixture
	var cleanup_node: Node = fixture["cleanup_node"]
	var floor: StaticBody3D = fixture["floor"]
	var torso: RigidBody3D = fixture["torso"]
	var limbs: Array = fixture["limbs"]
	var bodies: Array = fixture["bodies"]
	var joint_state_by_joint_id: Dictionary = {}
	for limb_value in limbs:
		var mapped_limb: Dictionary = limb_value
		for state_value in mapped_limb["joint_states"]:
			var mapped_state: Dictionary = state_value
			joint_state_by_joint_id[String(mapped_state["joint_id"])] = mapped_state
	var initial_torso_position := torso.global_position
	var initial_torso_orientation := torso.global_basis.get_rotation_quaternion().normalized()
	var initial_yaw_rad := _yaw_rad(torso)
	var initial_lateral_axis_world := torso.global_transform.basis.z
	initial_lateral_axis_world.y = 0.0
	initial_lateral_axis_world = initial_lateral_axis_world.normalized()
	var initial_forward_axis_world := Vector3.UP.cross(initial_lateral_axis_world).normalized()
	var push_impulse_task := FixtureSpecScript.vector3_from_array(
		environment_challenge_options["push_impulse_task_n_s"]
	)
	var push_impulse_world := (
		initial_forward_axis_world * push_impulse_task.x
		+ Vector3.UP * push_impulse_task.y
		+ initial_lateral_axis_world * push_impulse_task.z
	)
	var dynamic_support_diagnostic_enabled := bool(dynamic_support_options["enabled"])
	var sdk_adapter: RefCounted
	var sdk_live_fixture_actuator_cap_binding_receipt := {
		"ok": not sdk_live_fixture_actuator_cap_binding_enabled,
		"failure_code": "",
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var sdk_actuator_cap_profile_resolution_receipt: Dictionary = {}
	var sdk_actuator_cap_profile_physical_binding_receipt: Dictionary = {}
	var sdk_live_fixture_actuator_cap_override_by_actuator_id: Dictionary = {}
	var sdk_public_profile_preworld_binding_route: Dictionary = (
		(
			sdk_public_profile_preworld_binding_preparation.get(
				"binding_route",
				{},
			) as Dictionary
		).duplicate(true)
	)
	if not sdk_public_profile_preworld_binding_route.is_empty():
		sdk_live_fixture_actuator_cap_binding_receipt = (
			(
				sdk_public_profile_preworld_binding_route.get(
					"binding_receipt",
					{},
				) as Dictionary
			).duplicate(true)
		)
		sdk_actuator_cap_profile_resolution_receipt = (
			(
				sdk_public_profile_preworld_binding_route.get(
					"actuator_cap_profile_resolution_receipt",
					{},
				) as Dictionary
			).duplicate(true)
		)
		sdk_actuator_cap_profile_physical_binding_receipt = (
			(
				sdk_public_profile_preworld_binding_route.get(
					"actuator_cap_profile_physical_binding_receipt",
					{},
				) as Dictionary
			).duplicate(true)
		)
		sdk_live_fixture_actuator_cap_override_by_actuator_id = (
			(
				sdk_public_profile_preworld_binding_route.get(
					"maximum_impulse_override_by_actuator_id",
					{},
				) as Dictionary
			).duplicate(true)
		)
	var sdk_adapter_start_result := {
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"world_build_count": 0,
	}
	if sdk_adapter_enabled:
		sdk_adapter = SdkGodotJoltAdapterScript.new()
	var sdk_terminal_restorer: RefCounted
	var sdk_terminal_compiled_morphology: Dictionary = {}
	if sdk_terminal_restoration_enabled:
		var terminal_policy_id := String(
			sdk_terminal_restoration_options.get("terminal_restoration_policy_id", "")
		)
		sdk_terminal_restorer = (
			SdkGodotJoltStabilityAssistedTaperActuationScript.new()
			if sdk_terminal_stability_assisted_taper_enabled
			else SdkGodotJoltQuiescentTaperActuationScript.new()
			if sdk_terminal_quiescent_taper_enabled
			else SdkGodotJoltNeutralStanceScript.new()
			if terminal_policy_id == SdkGodotJoltNeutralStanceScript.POLICY_ID
			else SdkGodotJoltTerminalRestorationScript.new()
		)
	var sdk_authority_failure_code := ""
	var sdk_authority_last_application_result: Dictionary = {}
	var sdk_startup_ramp_composition_step_count := 0
	var sdk_startup_ramp_active_step_count := 0
	var sdk_startup_ramp_exact_zero_scale_step_count := 0
	var sdk_startup_ramp_exact_unity_scale_step_count := 0
	var sdk_startup_ramp_maximum_absolute_residual_rad_s := 0.0
	var sdk_support_loss_startup_state := (
		SdkSupportLossConditionedStartupScript.new_state()
		if (
			sdk_startup_velocity_ramp_enabled
			and sdk_startup_velocity_ramp_policy_id
			== SdkSupportLossConditionedStartupScript.POLICY_ID
		)
		else {}
	)
	var sdk_heading_segment_sample_counts: Dictionary = {}
	for heading_segment_value in sdk_heading_schedule_options.get("segments", []):
		var heading_segment: Dictionary = heading_segment_value
		sdk_heading_segment_sample_counts[String(heading_segment["segment_id"])] = 0
	var sdk_heading_reference_sample_count := 0
	var sdk_heading_turn_sample_count := 0
	var sdk_heading_command_failure_code := ""
	var sdk_heading_turn_start_yaw_rad := NAN
	var sdk_heading_turn_end_yaw_rad := NAN
	var sdk_heading_turn_held_steering_sum := 0.0
	var sdk_heading_turn_held_steering_sample_count := 0
	var sdk_heading_maximum_absolute_requested_steering_fraction := 0.0
	var sdk_heading_maximum_absolute_held_steering_fraction := 0.0
	var sdk_terminal_restoration_failure_code := ""
	var sdk_terminal_restoration_receipt_count := 0
	var sdk_terminal_restoration_receipt_validation_failure_count := 0
	var sdk_terminal_capture_transition_count := 0
	var sdk_terminal_capture_transition_failure_count := 0
	var sdk_terminal_neutral_target_activation_command_count := 0
	var sdk_terminal_neutral_target_activation_failure_count := 0
	var sdk_terminal_maximum_absolute_joint_position_error_rad := 0.0
	var sdk_terminal_heading_correction_receipt_count := 0
	var sdk_terminal_native_application_count := 0
	var sdk_terminal_application_mismatch_count := 0
	var sdk_terminal_maximum_absolute_joint_velocity_rad_s := 0.0
	var sdk_terminal_first_all_four_contact_restoration_step := -1
	var sdk_terminal_consecutive_all_four_contact_hold_steps := 0
	var sdk_terminal_maximum_consecutive_all_four_contact_hold_steps := 0
	var sdk_terminal_independent_pose_memory: Dictionary = {}
	var sdk_terminal_trace_rows: Array[Dictionary] = []
	var sdk_terminal_trace_failure_codes: Array[String] = []
	var sdk_terminal_passive_zero_applied := false
	var sdk_terminal_handoff_active := true
	var sdk_terminal_handoff_support_counter := 0
	var sdk_terminal_handoff_after_active_step := -1
	var sdk_terminal_first_passive_step := -1
	var sdk_terminal_handoff_reason := ""
	var sdk_terminal_support_confirmed := false
	var sdk_terminal_active_step_count := 0
	var sdk_terminal_passive_step_count := 0
	var sdk_terminal_first_post_handoff_contact_loss_step := -1
	var sdk_terminal_post_handoff_contact_loss_step_count := 0
	var sdk_terminal_taper_state: Dictionary = sdk_terminal_taper_script.initial_state()
	var sdk_terminal_taper_step_count := 0
	var sdk_terminal_taper_reset_count := 0
	var legacy_evidence_actuation_application_count := 0
	var legacy_post_settle_actuation_application_count := 0
	var legacy_sdk_overlay_base_application_count := 0
	var dynamic_support_trace: Array = []
	var dynamic_support_sample_failure_code := ""
	var dynamic_support_body_by_id: Dictionary = {}
	if dynamic_support_diagnostic_enabled:
		for body_value in bodies:
			var diagnostic_body: RigidBody3D = body_value
			dynamic_support_body_by_id[String(diagnostic_body.name)] = diagnostic_body
	var contact_gated_phase_progression := bool(
		robustness_options["contact_gated_phase_progression"]
	)
	var maximum_contact_gate_hold_ticks := int(
		robustness_options["maximum_contact_gate_hold_ticks"]
	)
	var maximum_contact_gated_phase_skew_ticks := int(
		robustness_options["maximum_contact_gated_phase_skew_ticks"]
	)
	var lateral_stride_steering_gain_per_m := float(
		robustness_options["lateral_stride_steering_gain_per_m"]
	)
	var phase_bounded_path_steering_enabled := bool(
		path_steering_options["phase_bounded_path_steering_enabled"]
	)
	var cross_track_heading_gain_rad_per_m := float(
		path_steering_options["cross_track_heading_gain_rad_per_m"]
	)
	var cross_track_velocity_heading_gain_rad_per_m_s := float(
		path_steering_options.get("cross_track_velocity_heading_gain_rad_per_m_s", 0.0)
	)
	var yaw_error_stride_gain_per_rad := float(
		path_steering_options["yaw_error_stride_gain_per_rad"]
	)
	var steering_update_interval_ticks := int(
		path_steering_options["steering_update_interval_ticks"]
	)
	var maximum_desired_heading_error_rad := float(
		path_steering_options["maximum_desired_heading_error_rad"]
	)
	var maximum_steering_fraction := float(path_steering_options["maximum_steering_fraction"])
	var evidence_start_tick := (
		settle_ticks + warmup_cycles * cycle_ticks + evidence_boundary_alignment_ticks
	)
	var sdk_adapter_start_tick := (
		settle_ticks if sdk_full_post_settle_authority_enabled else evidence_start_tick
	)
	var effective_fixed_exposure_step_count := (
		int(
			authority_horizon_options.get(
				"exact_candidate_authority_observation_count",
				0,
			)
		)
		if authority_horizon_enabled
		else SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT
	)
	var sdk_phase_offset_activation_tick := settle_ticks + warmup_cycles * cycle_ticks
	var sdk_phase_offset_activation_semantic_step := sdk_phase_offset_activation_tick - settle_ticks
	var nominal_evidence_end_tick := evidence_start_tick + evidence_cycles * cycle_ticks
	var maximum_evidence_end_tick := (
		nominal_evidence_end_tick
		+ (maximum_contact_gated_evidence_extension_ticks if contact_gated_phase_progression else 0)
	)
	var evidence_end_tick := -1 if contact_gated_phase_progression else nominal_evidence_end_tick
	var cooldown_end_tick := (
		-1 if contact_gated_phase_progression else evidence_end_tick + cooldown_cycles * cycle_ticks
	)
	var maximum_total_ticks := (
		maximum_evidence_end_tick + cooldown_cycles * cycle_ticks + terminal_settle_ticks
	)
	if authority_horizon_enabled:
		maximum_total_ticks = sdk_adapter_start_tick + effective_fixed_exposure_step_count
	if sdk_terminal_restoration_enabled:
		maximum_total_ticks = sdk_adapter_start_tick + int(
			sdk_terminal_restoration_options.get(
				"total_traced_step_count",
				QSDK_R23D4_TOTAL_TRACE_STEP_COUNT,
			)
		)
	var evidence_start_torso_position := Vector3(INF, INF, INF)
	var evidence_end_torso_position := Vector3(INF, INF, INF)
	var contact_state_by_limb: Dictionary = {}
	var contact_cycle_count_by_limb: Dictionary = {}
	var rejected_short_contact_cycle_count_by_limb: Dictionary = {}
	var maximum_cycle_relocation_by_limb_m: Dictionary = {}
	var minimum_cycle_relocation_by_limb_m: Dictionary = {}
	var maximum_foot_center_height_by_limb_m: Dictionary = {}
	var contact_absent_tick_count_by_limb: Dictionary = {}
	var longest_contact_absent_dwell_by_limb_ticks: Dictionary = {}
	var current_contact_absent_dwell_by_limb_ticks: Dictionary = {}
	var contact_transition_receipts_by_limb: Dictionary = {}
	var contact_clearance_assist_tick_count_by_limb: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		contact_state_by_limb[limb_id] = {
			"bearing": _foot_bears_floor(limb, floor),
			"airborne": false,
			"release_tick": -1,
			"release_position": Vector3(INF, INF, INF),
			"airborne_dwell_ticks": 0,
		}
		contact_cycle_count_by_limb[limb_id] = 0
		rejected_short_contact_cycle_count_by_limb[limb_id] = 0
		maximum_cycle_relocation_by_limb_m[limb_id] = 0.0
		minimum_cycle_relocation_by_limb_m[limb_id] = INF
		maximum_foot_center_height_by_limb_m[limb_id] = 0.0
		contact_absent_tick_count_by_limb[limb_id] = 0
		longest_contact_absent_dwell_by_limb_ticks[limb_id] = 0
		current_contact_absent_dwell_by_limb_ticks[limb_id] = 0
		contact_transition_receipts_by_limb[limb_id] = []
		contact_clearance_assist_tick_count_by_limb[limb_id] = 0
	var motor_command_count := 0
	var maximum_motor_target_speed_rad_s := 0.0
	var maximum_motor_target_speed_by_joint_role_rad_s := {
		"hip_pitch": 0.0,
		"knee_pitch": 0.0,
	}
	var contact_loaded_swing_knee_speed_cap_activation_count := 0
	var maximum_contact_loaded_swing_knee_target_speed_rad_s := 0.0
	var anchor_error_guard_activation_count := 0
	var maximum_anchor_error_guard_input_m := 0.0
	var maximum_anchor_error_guard_progress := 0.0
	var minimum_anchor_error_guard_speed_limit_rad_s := INF
	var maximum_anchor_error_guarded_target_speed_rad_s := 0.0
	var maximum_measured_joint_speed_rad_s := 0.0
	var maximum_anchor_error_m := 0.0
	var maximum_anchor_error_joint_id := ""
	var maximum_anchor_error_tick := -1
	var maximum_anchor_error_context := {}
	var latest_motor_command_context_by_joint_id := {}
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_hinge_axis_error_joint_id := ""
	var maximum_hinge_axis_error_tick := -1
	var maximum_tilt_rad := 0.0
	var minimum_torso_height_m := INF
	var torso_contact_ticks := 0
	var direct_torso_force_command_count := 0
	var direct_torso_impulse_command_count := 0
	var direct_torso_velocity_command_count := 0
	var direct_torso_transform_command_count := 0
	var external_push_application_count := 0
	var external_push_receipt := {}
	var external_push_pre_linear_velocity_world_m_s := Vector3.ZERO
	var observation_fault_application_count := 0
	var observation_fault_base_and_stability_count := 0
	var maximum_observation_fault_component := 0.0
	var lateral_stride_steering_target_adjustment_count := 0
	var maximum_absolute_lateral_stride_steering_fraction := 0.0
	var held_path_steering_fraction := 0.0
	var path_steering_update_receipts: Array = []
	var maximum_absolute_path_cross_track_error_m := 0.0
	var maximum_absolute_path_yaw_tracking_error_rad := 0.0
	var sdk_physical_trace_rows: Array[Dictionary] = []
	var sdk_physical_trace_failure_codes: Array[String] = []
	var sdk_deferred_recovery_trace_instrumentation_receipt: Dictionary = {}
	var first_torso_contact_tick := -1
	var initial_all_four_contacts := false
	var evidence_all_four_contacts_at_start := false
	var evidence_start_bearing_contact_by_limb: Dictionary = {}
	var evidence_boundary_contact_trace: Array = []
	var evidence_support_acquisition_trace: Array = []
	var evidence_support_acquisition_dwell_ticks := 0
	var evidence_support_acquisition_passed := false
	var evidence_support_acquisition_tick := -1
	var evidence_support_acquisition_timed_out := false
	var evidence_support_acquisition_enabled := bool(evidence_acquisition_options["enabled"])
	var maximum_evidence_support_acquisition_ticks := int(
		evidence_acquisition_options["maximum_acquisition_ticks"]
	)
	var minimum_all_support_acquisition_dwell_ticks := int(
		evidence_acquisition_options["minimum_all_support_dwell_ticks"]
	)
	var terminal_all_four_contacts := false
	var executed_ticks := 0
	var evidence_start_gait_tick := -1
	var evidence_end_gait_tick := -1
	var gated_gait_tick_by_limb: Dictionary = {}
	var evidence_start_gait_tick_by_limb: Dictionary = {}
	var evidence_end_gait_tick_by_limb: Dictionary = {}
	var contact_gated_evidence_horizon_timeout := false
	var current_contact_gate_hold_ticks_by_limb: Dictionary = {}
	var current_contact_gate_transition_dwell_ticks_by_limb: Dictionary = {}
	var contact_gate_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_release_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_recontact_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_timeout_count_by_limb: Dictionary = {}
	var contact_gate_timeout_receipts_by_limb: Dictionary = {}
	var contact_gate_phase_sync_hold_tick_count_by_limb: Dictionary = {}
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		gated_gait_tick_by_limb[limb_id] = 0
		evidence_start_gait_tick_by_limb[limb_id] = -1
		evidence_end_gait_tick_by_limb[limb_id] = -1
		current_contact_gate_hold_ticks_by_limb[limb_id] = 0
		current_contact_gate_transition_dwell_ticks_by_limb[limb_id] = 0
		contact_gate_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_release_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_recontact_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_timeout_count_by_limb[limb_id] = 0
		contact_gate_timeout_receipts_by_limb[limb_id] = []
		contact_gate_phase_sync_hold_tick_count_by_limb[limb_id] = 0
	for tick in range(maximum_total_ticks):
		if (
			external_push_application_count == 1
			and int(external_push_receipt.get("tick", -2)) + 1 == tick
			and not bool(external_push_receipt.get("effect_sampled", false))
		):
			var observed_velocity_delta := (
				torso.linear_velocity - external_push_pre_linear_velocity_world_m_s
			)
			external_push_receipt["effect_sampled"] = true
			external_push_receipt["observed_next_tick_velocity_delta_world_m_s"] = (
				[
					observed_velocity_delta.x,
					observed_velocity_delta.y,
					observed_velocity_delta.z,
				]
				if sdk_deferred_recovery_trace_enabled
				else observed_velocity_delta
			)
			external_push_receipt["observed_next_tick_velocity_delta_magnitude_m_s"] = (
				observed_velocity_delta.length()
			)
		var push_tick := (
			sdk_adapter_start_tick + int(environment_challenge_options["push_step_from_sdk_start"])
		)
		if (
			String(environment_challenge_options["push_profile_id"]) != NO_PUSH_PROFILE_ID
			and tick == push_tick
		):
			external_push_pre_linear_velocity_world_m_s = torso.linear_velocity
			torso.apply_central_impulse(push_impulse_world)
			external_push_application_count += 1
			external_push_receipt = {
				"profile_id": String(environment_challenge_options["push_profile_id"]),
				"target_body_id": "torso",
				"application_method": "RigidBody3D.apply_central_impulse",
				"tick": tick,
				"step_from_sdk_start":
				int(environment_challenge_options["push_step_from_sdk_start"]),
				"impulse_task_n_s": push_impulse_task,
				"impulse_world_n_s": push_impulse_world,
				"application_count": external_push_application_count,
				"controller_command": false,
				"effect_sampled": false,
			}
			if sdk_deferred_recovery_trace_enabled:
				external_push_receipt["schema_version"] = (
					QSDK_R10E_NATIVE_IMPULSE_APPLICATION_RECEIPT_SCHEMA
				)
				external_push_receipt["initial_task_frame_forward_axis_world_host_real"] = [
					initial_forward_axis_world.x,
					initial_forward_axis_world.y,
					initial_forward_axis_world.z,
				]
				external_push_receipt["initial_task_frame_lateral_axis_world_host_real"] = [
					initial_lateral_axis_world.x,
					initial_lateral_axis_world.y,
					initial_lateral_axis_world.z,
				]
				external_push_receipt["impulse_task_n_s"] = [
					push_impulse_task.x,
					push_impulse_task.y,
					push_impulse_task.z,
				]
				external_push_receipt["impulse_world_n_s"] = [
					push_impulse_world.x,
					push_impulse_world.y,
					push_impulse_world.z,
				]
				external_push_receipt["impulse_composition_numeric_precision"] = (
					"godot_real_t_binary32"
				)
		if tick >= evidence_start_tick - 16 and tick <= evidence_start_tick + 16:
			var boundary_bearing_contact_by_limb := _bearing_contact_by_limb(limbs, floor)
			(
				evidence_boundary_contact_trace
				. append(
					{
						"tick": tick,
						"tick_from_nominal_evidence_start": tick - evidence_start_tick,
						"bearing_contact_by_limb": boundary_bearing_contact_by_limb,
						"all_feet_bear_floor":
						_all_dictionary_values_true(boundary_bearing_contact_by_limb),
					}
				)
			)
		if (
			evidence_support_acquisition_enabled
			and tick >= evidence_start_tick
			and (tick <= evidence_start_tick + maximum_evidence_support_acquisition_ticks)
		):
			var acquisition_bearing_by_limb := _bearing_contact_by_limb(limbs, floor)
			var all_support := _all_dictionary_values_true(acquisition_bearing_by_limb)
			evidence_support_acquisition_dwell_ticks = (
				evidence_support_acquisition_dwell_ticks + 1 if all_support else 0
			)
			(
				evidence_support_acquisition_trace
				. append(
					{
						"tick": tick,
						"tick_from_nominal_evidence_start": tick - evidence_start_tick,
						"bearing_contact_by_limb": acquisition_bearing_by_limb,
						"all_feet_bear_floor": all_support,
						"consecutive_all_support_dwell_ticks":
						evidence_support_acquisition_dwell_ticks,
					}
				)
			)
			if (
				not evidence_support_acquisition_passed
				and (
					evidence_support_acquisition_dwell_ticks
					>= minimum_all_support_acquisition_dwell_ticks
				)
			):
				evidence_support_acquisition_passed = true
				evidence_support_acquisition_tick = tick
			if (
				tick == evidence_start_tick + maximum_evidence_support_acquisition_ticks
				and not evidence_support_acquisition_passed
			):
				evidence_support_acquisition_timed_out = true
		if tick == evidence_start_tick:
			evidence_start_torso_position = torso.global_position
			evidence_start_bearing_contact_by_limb = _bearing_contact_by_limb(limbs, floor)
			evidence_all_four_contacts_at_start = _all_dictionary_values_true(
				evidence_start_bearing_contact_by_limb
			)
			if not evidence_support_acquisition_enabled:
				evidence_support_acquisition_passed = evidence_all_four_contacts_at_start
				evidence_support_acquisition_tick = (
					tick if evidence_all_four_contacts_at_start else -1
				)
				evidence_support_acquisition_timed_out = (not evidence_all_four_contacts_at_start)
			evidence_start_gait_tick = maxi(tick - settle_ticks, 0)
			for limb_id_value in LIMB_ORDER:
				var gait_limb_id := String(limb_id_value)
				gated_gait_tick_by_limb[gait_limb_id] = evidence_start_gait_tick
				evidence_start_gait_tick_by_limb[gait_limb_id] = evidence_start_gait_tick
				current_contact_gate_hold_ticks_by_limb[gait_limb_id] = 0
				current_contact_gate_transition_dwell_ticks_by_limb[gait_limb_id] = 0
			for limb_value in limbs:
				var limb: Dictionary = limb_value
				var limb_id := String(limb["limb_id"])
				var state: Dictionary = contact_state_by_limb[limb_id]
				state["bearing"] = _foot_bears_floor(limb, floor)
				state["airborne"] = false
				state["release_tick"] = -1
				state["release_position"] = Vector3(INF, INF, INF)
				state["airborne_dwell_ticks"] = 0
		if tick == evidence_end_tick:
			evidence_end_torso_position = torso.global_position
		var amplitude_evidence_end_tick := (
			evidence_end_tick if evidence_end_tick >= 0 else maximum_evidence_end_tick
		)
		var amplitude_cooldown_end_tick := (
			cooldown_end_tick
			if cooldown_end_tick >= 0
			else maximum_evidence_end_tick + cooldown_cycles * cycle_ticks
		)
		var gait_amplitude := _gait_amplitude(
			tick,
			amplitude_evidence_end_tick,
			amplitude_cooldown_end_tick,
			settle_ticks,
			warmup_cycles,
			cooldown_cycles,
			cycle_ticks,
		)
		var ungated_gait_tick := maxi(tick - settle_ticks, 0)
		var sdk_phase_progression_mode := (
			"contact_gated"
			if (tick >= evidence_start_tick and (evidence_end_tick < 0 or tick < evidence_end_tick))
			else "clocked"
		)
		var sdk_adapter_window_active := (
			sdk_adapter_enabled
			and tick >= sdk_adapter_start_tick
			and (
				(
					sdk_p5i3c_fixed_exposure_enabled
					and tick < sdk_adapter_start_tick + effective_fixed_exposure_step_count
				)
				or (
					not sdk_p5i3c_fixed_exposure_enabled
					and (
						sdk_full_post_settle_authority_enabled
						or (evidence_end_tick < 0 or tick < evidence_end_tick)
					)
				)
			)
		)
		var sdk_terminal_trace_step := tick - sdk_adapter_start_tick
		var sdk_terminal_controller_step_count := int(
			sdk_terminal_restoration_options.get(
				"controller_step_count",
				QSDK_R23D4_CONTROLLER_STEP_COUNT,
			)
		)
		var sdk_terminal_total_trace_step_count := int(
			sdk_terminal_restoration_options.get(
				"total_traced_step_count",
				QSDK_R23D4_TOTAL_TRACE_STEP_COUNT,
			)
		)
		if sdk_terminal_restoration_enabled:
			sdk_adapter_window_active = (
				sdk_terminal_trace_step >= 0
				and sdk_terminal_trace_step < sdk_terminal_controller_step_count
			)
		var sdk_terminal_restoration_window_active := (
			sdk_terminal_restoration_enabled
			and sdk_terminal_trace_step >= sdk_terminal_controller_step_count
			and sdk_terminal_trace_step < sdk_terminal_total_trace_step_count
			and (
				sdk_terminal_handoff_active
				if sdk_terminal_support_handoff_enabled
				else sdk_terminal_trace_step < QSDK_R23D4_ACTIVE_STEP_COUNT
			)
		)
		var sdk_terminal_passive_window_active := (
			sdk_terminal_restoration_enabled
			and sdk_terminal_trace_step >= sdk_terminal_controller_step_count
			and sdk_terminal_trace_step < sdk_terminal_total_trace_step_count
			and (
				not sdk_terminal_handoff_active
				if sdk_terminal_support_handoff_enabled
				else sdk_terminal_trace_step >= QSDK_R23D4_ACTIVE_STEP_COUNT
			)
		)
		var sdk_terminal_managed_window_active := (
			sdk_terminal_restoration_enabled
			and sdk_terminal_trace_step >= 0
			and sdk_terminal_trace_step < sdk_terminal_total_trace_step_count
		)
		var sdk_adapter_step_window_active := (
			sdk_adapter_window_active or sdk_terminal_restoration_window_active
		)
		if sdk_adapter_enabled and tick == sdk_adapter_start_tick:
			var sdk_initial_gait_step_by_limb := _sdk_initial_gait_steps(
				gated_gait_tick_by_limb,
				int(initial_perturbation["gait_phase_offset_ticks"]),
				sdk_p5i3c_fixed_exposure_enabled,
			)
			sdk_adapter_start_result = (
				sdk_adapter
				. start(
					sdk_adapter_options["descriptor"],
					sdk_initial_gait_step_by_limb,
					held_path_steering_fraction,
					initial_torso_position,
					initial_lateral_axis_world,
					initial_yaw_rad,
					physics_hz,
					realized_solver_policy_options,
					float(sdk_adapter_options["comparison_tolerance"]),
					sdk_phase_progression_mode,
					sdk_authority_enabled,
					(
						int(initial_perturbation["gait_phase_offset_ticks"])
						if sdk_full_post_settle_authority_enabled
						else 0
					),
					(
						sdk_phase_offset_activation_semantic_step
						if sdk_full_post_settle_authority_enabled
						else -1
					),
					sdk_authority_scope if sdk_authority_enabled else "shadow",
					String(sdk_adapter_options["stability_policy_id"]),
					sdk_material_profile,
					String(
						(
							sdk_adapter_options
							. get(
								"controller_policy_id",
								SDK_CANDIDATE35_POLICY_ID,
							)
						)
					),
					float(
						sdk_adapter_options.get(
							"stability_influence_global_scale",
							-1.0,
						)
					),
					sdk_terminal_stability_assisted_taper_enabled,
					String(
						sdk_adapter_options.get(
							"task_frame_origin_policy_id",
							SDK_FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
						)
					),
				)
			)
			if (
				sdk_live_fixture_actuator_cap_binding_enabled
				and bool(sdk_adapter_start_result.get("ok", false))
			):
				var binding_route: Dictionary = (
					sdk_public_profile_preworld_binding_route.duplicate(true)
				)
				if binding_route.is_empty():
					var compiled_boundary: Dictionary = (
						sdk_adapter.preflight_compiled_morphology_boundary()
					)
					binding_route = bind_sdk_live_fixture_actuator_cap_route(
						compiled_boundary,
						joint_state_by_joint_id,
						float(sdk_adapter_options["comparison_tolerance"]),
						String(
							sdk_adapter_options[
								"live_fixture_actuator_cap_binding_policy_id"
							]
						),
						String(
							sdk_adapter_options.get(
								"live_fixture_actuator_cap_binding_profile_id",
								"",
							)
						),
						(sdk_authority_options.get("descriptor", {}) as Dictionary),
					)
				sdk_live_fixture_actuator_cap_binding_receipt = (
					(binding_route.get("binding_receipt", {}) as Dictionary).duplicate(true)
				)
				sdk_live_fixture_actuator_cap_override_by_actuator_id = (
					(
						binding_route.get(
							"maximum_impulse_override_by_actuator_id",
							{},
						) as Dictionary
					).duplicate(true)
				)
				sdk_actuator_cap_profile_resolution_receipt = (
					(
						binding_route.get(
							"actuator_cap_profile_resolution_receipt",
							{},
						) as Dictionary
					).duplicate(true)
				)
				sdk_actuator_cap_profile_physical_binding_receipt = (
					(
						binding_route.get(
							"actuator_cap_profile_physical_binding_receipt",
							{},
						) as Dictionary
					).duplicate(true)
				)
				sdk_adapter_start_result[
					"live_fixture_actuator_cap_binding_receipt"
				] = sdk_live_fixture_actuator_cap_binding_receipt.duplicate(true)
				if not sdk_actuator_cap_profile_resolution_receipt.is_empty():
					sdk_adapter_start_result[
						"actuator_cap_profile_resolution_receipt"
					] = sdk_actuator_cap_profile_resolution_receipt.duplicate(true)
				if not sdk_actuator_cap_profile_physical_binding_receipt.is_empty():
					sdk_adapter_start_result[
						"actuator_cap_profile_physical_binding_receipt"
					] = sdk_actuator_cap_profile_physical_binding_receipt.duplicate(true)
				if not bool(binding_route.get("ok", false)):
					sdk_adapter_start_result["ok"] = false
					sdk_adapter_start_result["failure_code"] = String(
						binding_route.get(
							"failure_code",
							"LIVE_FIXTURE_CAP_BINDING_FAILED",
						)
					)
					sdk_authority_failure_code = String(
						sdk_adapter_start_result["failure_code"]
					)
		var sdk_adapter_sample_result: Dictionary = {}
		var sdk_adapter_step_result: Dictionary = {}
		var sdk_startup_ramp_step_receipt: Dictionary = {}
		var sdk_physical_trace_pending_row: Dictionary = {}
		var sdk_deferred_recovery_trace_step_pending := false
		var sdk_terminal_native_application_count_this_step := 0
		var sdk_terminal_command_time_feedback: Dictionary = {}
		var sdk_terminal_temporal_scale: Dictionary = {}
		var sdk_terminal_authority_receipt: Dictionary = {}
		var sdk_heading_command_options: Dictionary = {}
		var sdk_heading_command_segment_end_step_exclusive := -1
		if sdk_adapter_step_window_active and bool(sdk_adapter_start_result.get("ok", false)):
			var sdk_heading_command_resolution := resolve_sdk_heading_command_options(
				sdk_heading_schedule_options,
				ungated_gait_tick,
			)
			if not bool(sdk_heading_command_resolution.get("ok", false)):
				sdk_heading_command_failure_code = String(
					sdk_heading_command_resolution.get(
						"failure_code",
						"SDK_HEADING_COMMAND_RESOLUTION_FAILED",
					)
				)
				sdk_adapter_sample_result = sdk_heading_command_resolution
			else:
				sdk_heading_command_options = (
					(
						sdk_heading_command_resolution
						. get("heading_command_options", {})
					) as Dictionary
				).duplicate(true)
				sdk_heading_command_segment_end_step_exclusive = int(
					sdk_heading_command_resolution.get(
						"segment_end_step_exclusive",
						-1,
					)
				)
				sdk_adapter_sample_result = (
					sdk_adapter
					. sample(
						ungated_gait_tick,
						gait_amplitude,
						sdk_phase_progression_mode,
						torso,
						limbs,
						floor,
						environment_challenge_options,
						sdk_heading_command_options,
					)
				)
			var observation_fault_receipt: Dictionary = sdk_adapter_sample_result.get(
				"observation_fault_receipt", {}
			)
			if bool(observation_fault_receipt.get("applied", false)):
				observation_fault_application_count += 1
				if (
					bool(observation_fault_receipt.get("base_state_faulted", false))
					and bool(
						(
							observation_fault_receipt
							. get(
								"stability_state_faulted",
								false,
							)
						)
					)
				):
					observation_fault_base_and_stability_count += 1
				maximum_observation_fault_component = maxf(
					maximum_observation_fault_component,
					float(
						(
							observation_fault_receipt
							. get(
								"maximum_absolute_applied_component",
								0.0,
							)
						)
					),
				)
		if (
			phase_bounded_path_steering_enabled
			and tick >= settle_ticks
			and ungated_gait_tick % steering_update_interval_ticks == 0
		):
			var path_displacement_world := torso.global_position - initial_torso_position
			var cross_track_error_m := path_displacement_world.dot(initial_lateral_axis_world)
			var cross_track_velocity_m_s := torso.linear_velocity.dot(initial_lateral_axis_world)
			var measured_yaw_error_rad := _wrap_angle(_yaw_rad(torso) - initial_yaw_rad)
			var desired_heading_error_rad := clampf(
				(
					-cross_track_heading_gain_rad_per_m * cross_track_error_m
					- (cross_track_velocity_heading_gain_rad_per_m_s * cross_track_velocity_m_s)
				),
				-maximum_desired_heading_error_rad,
				maximum_desired_heading_error_rad
			)
			var yaw_tracking_error_rad := _wrap_angle(
				measured_yaw_error_rad - desired_heading_error_rad
			)
			held_path_steering_fraction = clampf(
				yaw_error_stride_gain_per_rad * yaw_tracking_error_rad,
				-maximum_steering_fraction,
				maximum_steering_fraction
			)
			maximum_absolute_path_cross_track_error_m = maxf(
				maximum_absolute_path_cross_track_error_m, absf(cross_track_error_m)
			)
			maximum_absolute_path_yaw_tracking_error_rad = maxf(
				maximum_absolute_path_yaw_tracking_error_rad, absf(yaw_tracking_error_rad)
			)
			var steering_receipt := {
				"tick": tick,
				"gait_tick": ungated_gait_tick,
				"cross_track_error_m": cross_track_error_m,
				"measured_yaw_error_rad": measured_yaw_error_rad,
				"desired_heading_error_rad": desired_heading_error_rad,
				"yaw_tracking_error_rad": yaw_tracking_error_rad,
				"steering_fraction": held_path_steering_fraction,
			}
			if path_steering_options.has("cross_track_velocity_heading_gain_rad_per_m_s"):
				steering_receipt["cross_track_velocity_m_s"] = cross_track_velocity_m_s
			path_steering_update_receipts.append(steering_receipt)
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			var limb_id := String(limb["limb_id"])
			var gait_tick := ungated_gait_tick
			if contact_gated_phase_progression and tick >= evidence_start_tick:
				gait_tick = int(gated_gait_tick_by_limb[limb_id])
			if tick >= settle_ticks + warmup_cycles * cycle_ticks:
				gait_tick += int(initial_perturbation["gait_phase_offset_ticks"])
			var phase_index := gait_phase_order.find(limb_id)
			var phase_offset_ticks := phase_index * (cycle_ticks / gait_phase_order.size())
			var local_phase_tick := posmod(gait_tick - phase_offset_ticks, cycle_ticks)
			var targets := _gait_joint_targets(
				local_phase_tick,
				gait_amplitude,
				knee_flexion_scale,
				swing_ticks,
				cycle_ticks,
			)
			var foot_bears_floor := _foot_bears_floor(limb, floor)
			if phase_bounded_path_steering_enabled or lateral_stride_steering_gain_per_m > 0.0:
				var lateral_stride_steering_fraction := held_path_steering_fraction
				if not phase_bounded_path_steering_enabled:
					var lateral_error_m := torso.global_position.z - initial_torso_position.z
					lateral_stride_steering_fraction = clampf(
						lateral_stride_steering_gain_per_m * lateral_error_m,
						-MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION,
						MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
					)
				maximum_absolute_lateral_stride_steering_fraction = maxf(
					maximum_absolute_lateral_stride_steering_fraction,
					absf(lateral_stride_steering_fraction)
				)
				if not is_zero_approx(lateral_stride_steering_fraction):
					lateral_stride_steering_target_adjustment_count += 1
				var lateral_side_sign := 1.0 if limb_id.ends_with("_right") else -1.0
				targets["hip_target_rad"] = (
					float(targets["hip_target_rad"])
					* (1.0 + lateral_side_sign * lateral_stride_steering_fraction)
				)
			if (
				local_phase_tick < swing_ticks
				and gait_amplitude > 0.0
				and contact_clearance_assist_rad > 0.0
				and (
					contact_clearance_assist_limb_id == "all"
					or contact_clearance_assist_limb_id == limb_id
				)
				and foot_bears_floor
			):
				targets["knee_target_rad"] = (
					float(targets["knee_target_rad"])
					+ gait_amplitude * contact_clearance_assist_rad
				)
				contact_clearance_assist_tick_count_by_limb[limb_id] = (
					int(contact_clearance_assist_tick_count_by_limb[limb_id]) + 1
				)
			for state_value in limb["joint_states"]:
				var state: Dictionary = state_value
				var joint_role := String(state["role"])
				var target_angle_rad := (
					float(targets["hip_target_rad"])
					if joint_role == "hip_pitch"
					else float(targets["knee_target_rad"])
				)
				var maximum_target_speed_rad_s := controller_maximum_motor_target_speed_rad_s
				var contact_loaded_speed_cap_active := (
					bool(motor_velocity_options["mass_adaptive_motor_velocity_enabled"])
					and (
						float(
							motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
						)
						< controller_maximum_motor_target_speed_rad_s
					)
					and joint_role == "knee_pitch"
					and (
						local_phase_tick
						>= int(
							motor_velocity_options["contact_loaded_swing_knee_activation_start_phase_tick"]
						)
					)
					and local_phase_tick < swing_ticks
					and (
						local_phase_tick
						!= int(
							motor_velocity_options["contact_loaded_swing_knee_full_speed_override_phase_tick"]
						)
					)
					and foot_bears_floor
				)
				if contact_loaded_speed_cap_active:
					maximum_target_speed_rad_s = float(
						motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
					)
					contact_loaded_swing_knee_speed_cap_activation_count += 1
				var anchor_error_before_command_m := float(
					_joint_geometry_receipt(state)["anchor_error_m"]
				)
				var anchor_error_guard_threshold_m := (
					float(evidence_threshold_options["maximum_anchor_error_m"])
					* float(motor_velocity_options["anchor_error_guard_activation_fraction"])
				)
				var anchor_error_guard_progress := clampf(
					(
						(
							(
								anchor_error_before_command_m
								/ float(evidence_threshold_options["maximum_anchor_error_m"])
							)
							- float(
								motor_velocity_options["anchor_error_guard_activation_fraction"]
							)
						)
						/ (
							1.0
							- float(
								motor_velocity_options["anchor_error_guard_activation_fraction"]
							)
						)
					),
					0.0,
					1.0,
				)
				var anchor_error_guard_speed_limit_rad_s := lerpf(
					controller_maximum_motor_target_speed_rad_s,
					float(
						motor_velocity_options["anchor_error_guard_maximum_motor_target_speed_rad_s"]
					),
					(
						anchor_error_guard_progress
						* float(motor_velocity_options["morphology_interaction_score"])
					),
				)
				var anchor_error_guard_active := (
					bool(motor_velocity_options["anchor_error_guard_enabled"])
					and (anchor_error_guard_speed_limit_rad_s < maximum_target_speed_rad_s)
					and joint_role == "knee_pitch"
					and local_phase_tick < swing_ticks
					and foot_bears_floor
					and anchor_error_before_command_m > anchor_error_guard_threshold_m
				)
				if anchor_error_guard_active:
					maximum_target_speed_rad_s = anchor_error_guard_speed_limit_rad_s
					anchor_error_guard_activation_count += 1
					maximum_anchor_error_guard_input_m = maxf(
						maximum_anchor_error_guard_input_m,
						anchor_error_before_command_m,
					)
					maximum_anchor_error_guard_progress = maxf(
						maximum_anchor_error_guard_progress,
						anchor_error_guard_progress,
					)
					minimum_anchor_error_guard_speed_limit_rad_s = minf(
						minimum_anchor_error_guard_speed_limit_rad_s,
						anchor_error_guard_speed_limit_rad_s,
					)
				var native_authority_window_active := (
					sdk_authority_enabled
					and not sdk_stability_overlay_enabled
					and bool(sdk_adapter_start_result.get("ok", false))
					and (
						sdk_adapter_window_active
						or sdk_terminal_managed_window_active
					)
				)
				var motor_receipt := _command_hinge_motor(
					state,
					target_angle_rad,
					motor_direction_sign,
					motor_position_gain_per_s,
					motor_rate_damping,
					maximum_target_speed_rad_s,
					not native_authority_window_active,
				)
				if (
					bool(motor_receipt.get("actuation_applied", false))
					and tick >= evidence_start_tick
					and (evidence_end_tick < 0 or tick < evidence_end_tick)
				):
					legacy_evidence_actuation_application_count += 1
				if bool(motor_receipt.get("actuation_applied", false)) and tick >= settle_ticks:
					legacy_post_settle_actuation_application_count += 1
				if (
					bool(motor_receipt.get("actuation_applied", false))
					and sdk_stability_overlay_enabled
					and sdk_adapter_window_active
				):
					legacy_sdk_overlay_base_application_count += 1
				var joint_id := String(state["joint_id"])
				latest_motor_command_context_by_joint_id[joint_id] = {
					"tick": tick,
					"joint_id": joint_id,
					"joint_role": joint_role,
					"limb_id": limb_id,
					"gait_tick": gait_tick,
					"local_phase_tick": local_phase_tick,
					"swing_phase": local_phase_tick < swing_ticks,
					"gait_amplitude": gait_amplitude,
					"target_angle_rad": target_angle_rad,
					"target_velocity_rad_s": float(motor_receipt["target_velocity_rad_s"]),
					"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
					"contact_loaded_speed_cap_active": contact_loaded_speed_cap_active,
					"contact_loaded_speed_cap_activation_start_phase_tick":
					int(
						motor_velocity_options["contact_loaded_swing_knee_activation_start_phase_tick"]
					),
					"contact_loaded_speed_cap_full_speed_override_phase_tick":
					int(
						motor_velocity_options["contact_loaded_swing_knee_full_speed_override_phase_tick"]
					),
					"anchor_error_before_command_m": anchor_error_before_command_m,
					"anchor_error_guard_threshold_m": anchor_error_guard_threshold_m,
					"anchor_error_guard_progress": anchor_error_guard_progress,
					"anchor_error_guard_speed_limit_rad_s": anchor_error_guard_speed_limit_rad_s,
					"anchor_error_guard_active": anchor_error_guard_active,
					"measured_angle_rad": float(motor_receipt["measured_angle_rad"]),
					"measured_rate_rad_s": float(motor_receipt["measured_rate_rad_s"]),
					"foot_bears_floor": foot_bears_floor,
				}
				motor_command_count += 1
				maximum_motor_target_speed_rad_s = maxf(
					maximum_motor_target_speed_rad_s,
					absf(float(motor_receipt["target_velocity_rad_s"]))
				)
				maximum_motor_target_speed_by_joint_role_rad_s[joint_role] = maxf(
					float(maximum_motor_target_speed_by_joint_role_rad_s[joint_role]),
					absf(float(motor_receipt["target_velocity_rad_s"])),
				)
				if contact_loaded_speed_cap_active:
					maximum_contact_loaded_swing_knee_target_speed_rad_s = maxf(
						maximum_contact_loaded_swing_knee_target_speed_rad_s,
						absf(float(motor_receipt["target_velocity_rad_s"])),
					)
				if anchor_error_guard_active:
					maximum_anchor_error_guarded_target_speed_rad_s = maxf(
						maximum_anchor_error_guarded_target_speed_rad_s,
						absf(float(motor_receipt["target_velocity_rad_s"])),
					)
				maximum_measured_joint_speed_rad_s = maxf(
					maximum_measured_joint_speed_rad_s,
					absf(float(motor_receipt["measured_rate_rad_s"]))
				)
		if sdk_terminal_passive_window_active and not sdk_terminal_passive_zero_applied:
			for passive_state_value in joint_state_by_joint_id.values():
				var passive_state: Dictionary = passive_state_value
				var passive_joint: HingeJoint3D = passive_state.get("joint")
				if passive_joint == null:
					sdk_terminal_restoration_failure_code = (
						"R23D4_GJT_PASSIVE_HINGE_MISSING"
					)
					continue
				passive_joint.set_param(
					HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
					0.0,
				)
			sdk_terminal_passive_zero_applied = true
		if (
			sdk_terminal_residual_pose_authority_enabled
			and sdk_terminal_managed_window_active
			and sdk_terminal_trace_step >= sdk_terminal_controller_step_count
		):
			var command_context := _r23d13_command_time_authority_context(
				sdk_adapter,
				sdk_terminal_compiled_morphology,
				sdk_terminal_taper_state,
				limbs,
				floor,
				joint_state_by_joint_id,
				sdk_terminal_trace_step,
				sdk_terminal_passive_window_active,
				sdk_terminal_taper_script,
				torso,
			)
			if bool(command_context.get("ok", false)):
				sdk_terminal_compiled_morphology = (
					command_context["compiled_morphology"] as Dictionary
				).duplicate(true)
				sdk_terminal_temporal_scale = (
					command_context["temporal_scale"] as Dictionary
				).duplicate(true)
				sdk_terminal_command_time_feedback = (
					command_context["command_time_feedback"] as Dictionary
				).duplicate(true)
				sdk_terminal_authority_receipt = (
					command_context["authority_receipt"] as Dictionary
				).duplicate(true)
			else:
				sdk_terminal_restoration_failure_code = String(
					command_context.get(
						"failure_code", "R23D13_GJT_COMMAND_TIME_FEEDBACK_INVALID"
					)
				)
		if sdk_adapter_step_window_active and bool(sdk_adapter_start_result.get("ok", false)):
			if (
				sdk_heading_schedule_enabled
				and String(sdk_heading_command_options.get("command_role", ""))
				== "turn_heading"
				and not is_finite(sdk_heading_turn_start_yaw_rad)
			):
				sdk_heading_turn_start_yaw_rad = _yaw_rad(torso)
			var sdk_legacy_gait_step_by_limb := {}
			var sdk_effective_phase_offset_ticks := _sdk_effective_phase_offset_ticks(
				int(initial_perturbation["gait_phase_offset_ticks"]),
				sdk_p5i3c_fixed_exposure_enabled,
				sdk_full_post_settle_authority_enabled,
				tick,
				sdk_phase_offset_activation_tick,
			)
			for sdk_limb_id_value in LIMB_ORDER:
				var sdk_limb_id := String(sdk_limb_id_value)
				var sdk_base_gait_step := (
					int(gated_gait_tick_by_limb[sdk_limb_id])
					if tick >= evidence_start_tick
					else ungated_gait_tick
				)
				sdk_legacy_gait_step_by_limb[sdk_limb_id] = (
					sdk_base_gait_step + sdk_effective_phase_offset_ticks
				)
			sdk_adapter_step_result = (
				sdk_adapter
				. step(
					sdk_adapter_sample_result,
					ungated_gait_tick,
					latest_motor_command_context_by_joint_id,
					sdk_legacy_gait_step_by_limb,
					held_path_steering_fraction,
					(
						path_steering_update_receipts[-1]
						if not path_steering_update_receipts.is_empty()
						else {}
					),
				)
			)
			if sdk_startup_velocity_ramp_enabled:
				sdk_startup_ramp_step_receipt = (
					SdkSupportLossConditionedStartupScript.transform_step_result(
						sdk_adapter_step_result,
						_bearing_contact_by_limb(limbs, floor),
						sdk_support_loss_startup_state,
					)
					if sdk_startup_velocity_ramp_policy_id
					== SdkSupportLossConditionedStartupScript.POLICY_ID
					else SdkStartupVelocityRampScript.transform_step_result(
						sdk_adapter_step_result
					)
				)
				if bool(sdk_startup_ramp_step_receipt.get("ok", false)):
					sdk_adapter_step_result = (
						(sdk_startup_ramp_step_receipt["step_result"] as Dictionary)
						.duplicate(true)
					)
					var startup_scale := float(
						sdk_startup_ramp_step_receipt["startup_velocity_scale"]
					)
					sdk_startup_ramp_composition_step_count += 1
					sdk_startup_ramp_active_step_count += int(startup_scale < 1.0)
					sdk_startup_ramp_exact_zero_scale_step_count += int(
						startup_scale == 0.0
					)
					sdk_startup_ramp_exact_unity_scale_step_count += int(
						startup_scale == 1.0
					)
					sdk_startup_ramp_maximum_absolute_residual_rad_s = maxf(
						sdk_startup_ramp_maximum_absolute_residual_rad_s,
						float(
							sdk_startup_ramp_step_receipt[
								"startup_ramp_maximum_absolute_residual_rad_s"
							]
						),
					)
				else:
					sdk_adapter_step_result["ok"] = false
					sdk_adapter_step_result["failure_code"] = String(
						sdk_startup_ramp_step_receipt.get(
							"failure_code",
							"SDK_STARTUP_RAMP_TRANSFORM_FAILED",
						)
					)
			if sdk_heading_schedule_enabled and not sdk_heading_command_options.is_empty():
				var heading_receipt: Dictionary = sdk_adapter_sample_result.get(
					"heading_command_receipt",
					{},
				)
				var heading_segment_id := String(
					sdk_heading_command_options.get("segment_id", "")
				)
				var heading_command_role := String(
					sdk_heading_command_options.get("command_role", "")
				)
				var heading_receipt_exact := (
					bool(sdk_adapter_step_result.get("ok", false))
					and String(heading_receipt.get("schedule_id", ""))
					== String(sdk_heading_schedule_options["schedule_id"])
					and String(heading_receipt.get("segment_id", ""))
					== heading_segment_id
					and String(heading_receipt.get("command_role", ""))
					== heading_command_role
					and int(heading_receipt.get("semantic_step", -1)) == ungated_gait_tick
					and absf(
						float(heading_receipt.get("heading_offset_rad", NAN))
						- float(sdk_heading_command_options["heading_offset_rad"])
					) <= 1.0e-15
				)
				if not heading_receipt_exact and sdk_heading_command_failure_code.is_empty():
					sdk_heading_command_failure_code = "SDK_HEADING_COMMAND_RECEIPT_INVALID"
				var heading_segment_declared := sdk_heading_segment_sample_counts.has(
					heading_segment_id
				)
				if heading_segment_declared:
					sdk_heading_segment_sample_counts[heading_segment_id] = (
						int(sdk_heading_segment_sample_counts[heading_segment_id]) + 1
					)
				if heading_segment_declared and heading_command_role == "reference_heading":
					sdk_heading_reference_sample_count += 1
				elif heading_segment_declared and heading_command_role == "turn_heading":
					sdk_heading_turn_sample_count += 1
				var native_output: Dictionary = sdk_adapter_step_result.get("native_output", {})
				var native_actuation: Dictionary = native_output.get("actuation", {})
				var native_receipt: Dictionary = native_actuation.get("receipt", {})
				var requested_steering_fraction := float(
					native_receipt.get("requested_steering_fraction", NAN)
				)
				var held_steering_fraction := float(
					native_receipt.get("held_steering_fraction", NAN)
				)
				if (
					not is_finite(requested_steering_fraction)
					or not is_finite(held_steering_fraction)
				):
					if sdk_heading_command_failure_code.is_empty():
						sdk_heading_command_failure_code = "SDK_HEADING_STEERING_RECEIPT_INVALID"
				else:
					sdk_heading_maximum_absolute_requested_steering_fraction = maxf(
						sdk_heading_maximum_absolute_requested_steering_fraction,
						absf(requested_steering_fraction),
					)
					sdk_heading_maximum_absolute_held_steering_fraction = maxf(
						sdk_heading_maximum_absolute_held_steering_fraction,
						absf(held_steering_fraction),
					)
					if heading_command_role == "turn_heading":
						sdk_heading_turn_held_steering_sum += held_steering_fraction
						sdk_heading_turn_held_steering_sample_count += 1
			if sdk_authority_enabled:
				if sdk_terminal_restoration_window_active:
					if sdk_terminal_compiled_morphology.is_empty():
						sdk_terminal_compiled_morphology = (
							sdk_adapter.compiled_morphology_for_conformance()
						)
					if sdk_terminal_quiescent_taper_enabled:
						var taper_scale: Dictionary = (
							sdk_terminal_taper_script.expected_velocity_scale(
								sdk_terminal_taper_state
							)
						)
						var applied_numerator := int(taper_scale.get("numerator", -1))
						if sdk_terminal_residual_pose_authority_enabled:
							var floor_receipt := (
								SdkGodotJoltR23D13ResidualPoseAuthorityScript
								. pose_authority_floor(sdk_terminal_command_time_feedback)
							)
							if bool(floor_receipt.get("ok", false)):
								applied_numerator = maxi(
									applied_numerator,
									int(floor_receipt["pose_authority_floor_numerator"]),
								)
							else:
								sdk_terminal_restoration_failure_code = String(
									floor_receipt.get(
										"failure_code",
										"R23D13_GJT_POSE_AUTHORITY_FLOOR_INVALID",
									)
								)
						var scale_result: Dictionary = (
							sdk_terminal_restorer.set_velocity_scale(
								applied_numerator,
								int(taper_scale.get("denominator", -1)),
							)
							if bool(taper_scale.get("ok", false))
							else taper_scale
						)
						if not bool(scale_result.get("ok", false)):
							sdk_terminal_restoration_failure_code = String(
								scale_result.get(
									"failure_code",
									"R23D10_GJT_TAPER_SCALE_INVALID",
								)
							)
					sdk_authority_last_application_result = (
						sdk_terminal_restorer
						. compose_and_apply(
							sdk_adapter_step_result,
							sdk_terminal_compiled_morphology,
							limbs,
							_bearing_contact_by_limb(limbs, floor),
							joint_state_by_joint_id,
						)
					)
					sdk_terminal_restoration_receipt_count += 1
					if bool(sdk_authority_last_application_result.get("ok", false)):
						if sdk_terminal_residual_pose_authority_enabled:
							var applied_receipt: Dictionary = (
								sdk_authority_last_application_result.get("receipt", {})
							)
							var composition_receipt: Dictionary = applied_receipt.get(
								"composition_receipt", {}
							)
							var composition_rows: Array = composition_receipt.get(
								"ordered_actuator_composition", []
							)
							var pre_taper_velocities: Array = []
							for composition_row_value in composition_rows:
								var composition_row: Dictionary = composition_row_value
								pre_taper_velocities.append(
									composition_row.get("combined_pre_taper_velocity_rad_s")
								)
							var authority_input := sdk_terminal_command_time_feedback.duplicate(true)
							authority_input["mode"] = String(sdk_terminal_taper_state["mode"])
							authority_input["temporal_scale_numerator"] = int(
								sdk_terminal_temporal_scale.get("numerator", -1)
							)
							authority_input["temporal_scale_denominator"] = int(
								sdk_terminal_temporal_scale.get("denominator", -1)
							)
							authority_input["actuator_ids"] = _sdk_terminal_ordered_actuator_ids(
								sdk_terminal_compiled_morphology
							)
							authority_input["combined_pre_taper_velocities_rad_s"] = (
								pre_taper_velocities
							)
							sdk_terminal_authority_receipt = (
								SdkGodotJoltR23D13ResidualPoseAuthorityScript
								. apply_residual_pose_authority(authority_input)
							)
							var authority_floor_receipt := (
								SdkGodotJoltR23D13ResidualPoseAuthorityScript
								. pose_authority_floor(authority_input)
							)
							sdk_terminal_authority_receipt["pose_feedback"] = (
								authority_floor_receipt
							)
							sdk_terminal_authority_receipt[
								"combined_pre_taper_velocities_rad_s"
							] = pre_taper_velocities.duplicate()
							var authority_exact := (
								bool(sdk_terminal_authority_receipt.get("ok", false))
								and composition_rows.size() == 8
								and (
									sdk_terminal_authority_receipt.get(
										"final_canonical_velocities_rad_s", []
									) as Array
								).size() == 8
							)
							if authority_exact:
								var authority_final: Array = sdk_terminal_authority_receipt[
									"final_canonical_velocities_rad_s"
								]
								for authority_index in range(8):
									authority_exact = authority_exact and (
										absf(
											float(authority_final[authority_index])
											- float(
												(composition_rows[authority_index] as Dictionary).get(
													"final_tapered_canonical_velocity_rad_s",
													NAN,
												)
											)
										) <= 1.0e-12
									)
							if not authority_exact:
								sdk_terminal_restoration_failure_code = (
									"R23D13_GJT_RESIDUAL_POSE_AUTHORITY_INVALID"
								)
								sdk_terminal_restoration_receipt_validation_failure_count += 1
						var neutral_stance_active := (
							String(
								sdk_terminal_restoration_options.get(
									"terminal_restoration_policy_id", ""
								)
							) == SdkGodotJoltNeutralStanceScript.POLICY_ID
						)
						var validation := (
							SdkGodotJoltStabilityAssistedTaperActuationScript.validate_receipt(
								sdk_authority_last_application_result.get("receipt", {}),
								ungated_gait_tick,
							)
							if sdk_terminal_stability_assisted_taper_enabled
							else SdkGodotJoltQuiescentTaperActuationScript.validate_receipt(
								sdk_authority_last_application_result.get("receipt", {}),
								ungated_gait_tick,
							)
							if sdk_terminal_quiescent_taper_enabled
							else SdkGodotJoltNeutralStanceScript.validate_receipt(
								sdk_authority_last_application_result.get("receipt", {}),
								ungated_gait_tick,
								sdk_terminal_independent_pose_memory,
							)
							if neutral_stance_active
							else SdkGodotJoltTerminalRestorationScript.validate_receipt(
								sdk_authority_last_application_result.get("receipt", {}),
								ungated_gait_tick,
								sdk_terminal_independent_pose_memory,
							)
						)
						if sdk_terminal_stability_assisted_taper_enabled:
							var external_record: Dictionary = (
								sdk_adapter
								. record_external_terminal_authority_application(
									sdk_adapter_step_result,
									int(
										sdk_authority_last_application_result.get(
											"applied_command_count",
											-1,
										)
									),
								)
							)
							if not bool(external_record.get("ok", false)):
								validation = external_record
						if not bool(validation.get("ok", false)):
							sdk_terminal_restoration_receipt_validation_failure_count += 1
							sdk_terminal_capture_transition_failure_count += 1
							if sdk_terminal_restoration_failure_code.is_empty():
								sdk_terminal_restoration_failure_code = String(
									validation.get(
										"failure_code",
										"R23D4_GJT_RESTORATION_RECEIPT_INVALID",
									)
								)
						else:
							sdk_terminal_capture_transition_count += int(
								validation.get(
									"neutral_target_transition_count",
									validation.get("pose_capture_transition_count", 0),
								)
							)
							if not neutral_stance_active:
								sdk_terminal_heading_correction_receipt_count += 1
						var activation_count := int(
							sdk_authority_last_application_result.get(
								"neutral_target_activation_count",
								0,
							)
						)
						if neutral_stance_active:
							sdk_terminal_neutral_target_activation_command_count += activation_count
							sdk_terminal_neutral_target_activation_failure_count += int(
								activation_count != 8
							)
							sdk_terminal_maximum_absolute_joint_position_error_rad = maxf(
								sdk_terminal_maximum_absolute_joint_position_error_rad,
								float(
									sdk_authority_last_application_result.get(
										"maximum_absolute_joint_position_error_rad",
										0.0,
									)
								),
							)
						sdk_terminal_native_application_count += int(
							sdk_authority_last_application_result.get(
								"applied_command_count",
								0,
							)
						)
						sdk_terminal_application_mismatch_count += int(
							int(
								sdk_authority_last_application_result.get(
									"applied_command_count",
									-1,
								)
							) != 8
						)
						sdk_terminal_maximum_absolute_joint_velocity_rad_s = maxf(
							sdk_terminal_maximum_absolute_joint_velocity_rad_s,
							float(
								sdk_authority_last_application_result.get(
									"maximum_absolute_joint_velocity_rad_s",
									INF,
								)
							),
						)
				else:
					sdk_authority_last_application_result = (
						(
							sdk_adapter
							. apply_stability_contribution(
								sdk_adapter_step_result,
								latest_motor_command_context_by_joint_id,
								joint_state_by_joint_id,
							)
						)
						if (
							sdk_stability_overlay_enabled
							or (
								sdk_full_authority_stability_contribution_enabled
								and not sdk_terminal_stability_assisted_taper_enabled
							)
						)
						else (
							sdk_adapter
							. apply_authority(
								sdk_adapter_step_result,
								joint_state_by_joint_id,
								(
									sdk_physical_trace_enabled
									and sdk_physical_trace_options.has(
										"actuator_phase_observation_schema_version"
									)
								),
								sdk_live_fixture_actuator_cap_override_by_actuator_id,
							)
						)
					)
				if (
					sdk_authority_failure_code.is_empty()
					and not bool(sdk_authority_last_application_result.get("ok", false))
				):
					sdk_authority_failure_code = String(
						(
							sdk_authority_last_application_result
							. get(
								"failure_code",
								"SDK_AUTHORITY_APPLICATION_FAILED",
							)
						)
					)
				if (
					sdk_terminal_managed_window_active
					and not sdk_terminal_passive_window_active
				):
					sdk_terminal_native_application_count_this_step = int(
						sdk_authority_last_application_result.get(
							"applied_command_count",
							0,
						)
					)
			if sdk_deferred_recovery_trace_enabled:
				var deferred_trace_before_failure := (
					DeferredRecoveryTraceScript.capture_before_solver_step(
						sdk_deferred_recovery_trace_buffer,
						sdk_adapter_sample_result,
						sdk_adapter_step_result,
						sdk_authority_last_application_result,
						ungated_gait_tick,
						_bearing_contact_by_limb(limbs, floor),
					)
				)
				if deferred_trace_before_failure.is_empty():
					sdk_deferred_recovery_trace_step_pending = true
				elif not sdk_physical_trace_failure_codes.has(deferred_trace_before_failure):
					sdk_physical_trace_failure_codes.append(deferred_trace_before_failure)
			if sdk_physical_trace_enabled and not sdk_deferred_recovery_trace_enabled:
				var trace_row_result := _compose_sdk_physical_trace_row(
					sdk_physical_trace_options,
					sdk_adapter_sample_result,
					sdk_adapter_step_result,
					sdk_authority_last_application_result,
					ungated_gait_tick,
					_bearing_contact_by_limb(limbs, floor),
					_tilt_rad(torso),
					_body_bears_floor(torso, "torso", floor),
					(
						(
							sdk_adapter_start_result.get("adapter_manifest", {})
							as Dictionary
						).get("controller_profile", {}) as Dictionary
					),
				)
				if bool(trace_row_result.get("ok", false)):
					sdk_physical_trace_pending_row = (
						(trace_row_result["row"] as Dictionary).duplicate(true)
					)
					if sdk_startup_velocity_ramp_enabled:
						sdk_physical_trace_pending_row["startup_ramp_id"] = String(
							sdk_startup_ramp_step_receipt.get("startup_ramp_id", "")
						)
						sdk_physical_trace_pending_row["startup_velocity_scale"] = float(
							sdk_startup_ramp_step_receipt.get("startup_velocity_scale", NAN)
						)
						sdk_physical_trace_pending_row["startup_ramp_active"] = bool(
							sdk_startup_ramp_step_receipt.get("startup_ramp_active", false)
						)
						sdk_physical_trace_pending_row["startup_ramp_residual_count"] = int(
							sdk_startup_ramp_step_receipt.get("startup_ramp_residual_count", -1)
						)
						sdk_physical_trace_pending_row[
						"startup_ramp_maximum_absolute_residual_rad_s"
					] = float(
						sdk_startup_ramp_step_receipt.get(
							"startup_ramp_maximum_absolute_residual_rad_s",
							NAN,
						)
					)
					if (
						sdk_startup_velocity_ramp_policy_id
						== SdkSupportLossConditionedStartupScript.POLICY_ID
					):
						for field_value in [
							"startup_transform_id",
							"startup_probe_active",
							"startup_probe_support_count",
							"startup_probe_complete_support_loss",
							"startup_transform_decision_locked",
							"startup_ramp_triggered",
							"startup_ramp_trigger_step",
							"startup_ramp_local_step",
							"startup_transform_residual_count",
							"startup_transform_maximum_absolute_residual_rad_s",
						]:
							var field := String(field_value)
							sdk_physical_trace_pending_row[field] = (
								sdk_startup_ramp_step_receipt.get(field)
							)
				else:
					var trace_failure := String(
						trace_row_result.get("failure_code", "SDK_PHYSICAL_TRACE_ROW_INVALID")
					)
					if not sdk_physical_trace_failure_codes.has(trace_failure):
						sdk_physical_trace_failure_codes.append(trace_failure)
		await tree.physics_frame
		if not sdk_physical_trace_pending_row.is_empty():
			var contacts_after := _bearing_contact_by_limb(limbs, floor)
			if sdk_recovery_trace_enabled:
				var completed_recovery_row := complete_sdk_recovery_trace_observation(
					sdk_physical_trace_pending_row,
					torso.global_position,
					torso.global_basis.get_rotation_quaternion(),
					torso.linear_velocity,
					torso.angular_velocity,
					_tilt_rad(torso),
					_body_bears_floor(torso, "torso", floor),
					contacts_after,
				)
				if bool(completed_recovery_row.get("ok", false)):
					sdk_physical_trace_pending_row = (
						(completed_recovery_row["row"] as Dictionary).duplicate(true)
					)
				else:
					var recovery_observation_failure := String(
						completed_recovery_row.get(
							"failure_code",
							"QSDK_R10B_RECOVERY_TRACE_OBSERVATION_INVALID",
						)
					)
					if not sdk_physical_trace_failure_codes.has(recovery_observation_failure):
						sdk_physical_trace_failure_codes.append(recovery_observation_failure)
			else:
				sdk_physical_trace_pending_row["ordered_foot_contacts_after"] = contacts_after
			if (
				not sdk_recovery_trace_enabled
				and sdk_physical_trace_pending_row.has("actuator_phase_observation")
			):
				var completed_observation := complete_sdk_actuator_phase_observation(
					sdk_physical_trace_pending_row,
					contacts_after,
				)
				if bool(completed_observation.get("ok", false)):
					sdk_physical_trace_pending_row = (
						(completed_observation["row"] as Dictionary).duplicate(true)
					)
				else:
					var observation_failure := String(
						completed_observation.get(
							"failure_code",
							"SDK_ACTUATOR_PHASE_OBSERVATION_COMPLETION_INVALID",
						)
					)
					if not sdk_physical_trace_failure_codes.has(observation_failure):
						sdk_physical_trace_failure_codes.append(observation_failure)
			sdk_physical_trace_rows.append(sdk_physical_trace_pending_row)
		if sdk_terminal_managed_window_active:
			var terminal_contacts := _bearing_contact_by_limb(limbs, floor)
			var sdk_terminal_handoff_receipt: Dictionary = {}
			if sdk_terminal_compiled_morphology.is_empty():
				sdk_terminal_compiled_morphology = (
					sdk_adapter.compiled_morphology_for_conformance()
				)
			var sdk_terminal_post_step_error := (
				SdkGodotJoltQuiescentTaperActuationScript
				. maximum_absolute_joint_position_error_rad(
					sdk_terminal_compiled_morphology,
					joint_state_by_joint_id,
				)
			)
			if (
				sdk_terminal_quiescent_taper_enabled
				and sdk_terminal_trace_step >= sdk_terminal_controller_step_count
			):
				var taper_scale: Dictionary = (
					sdk_terminal_taper_script.expected_velocity_scale(
						sdk_terminal_taper_state
					)
				)
				var taper_observation := {
					"contacts": [
						bool(terminal_contacts.get("front_left", false)),
						bool(terminal_contacts.get("front_right", false)),
						bool(terminal_contacts.get("rear_left", false)),
						bool(terminal_contacts.get("rear_right", false)),
					],
					"torso_tilt_rad": _tilt_rad(torso),
					"maximum_absolute_joint_position_error_rad": float(
						sdk_terminal_post_step_error.get(
							"maximum_absolute_joint_position_error_rad",
							NAN,
						)
					),
				}
				var transition: Dictionary = (
					sdk_terminal_taper_script.observe_completed_step(
						sdk_terminal_taper_state,
						taper_observation,
						sdk_terminal_native_application_count_this_step,
						int(taper_scale.get("numerator", -1)),
						int(taper_scale.get("denominator", -1)),
					)
					if bool(taper_scale.get("ok", false))
					and bool(sdk_terminal_post_step_error.get("ok", false))
					else _sdk_terminal_trace_failure(
						String(
							sdk_terminal_post_step_error.get(
								"failure_code",
								String(
									taper_scale.get(
										"failure_code",
										"R23D10_GJT_POST_STEP_OBSERVATION_INVALID",
									)
								),
							)
						)
					)
				)
				if not bool(transition.get("ok", false)):
					if sdk_terminal_restoration_failure_code.is_empty():
						sdk_terminal_restoration_failure_code = String(
							transition.get(
								"failure_code",
								"R23D10_GJT_TAPER_TRANSITION_INVALID",
							)
						)
				else:
					sdk_terminal_handoff_receipt = (
						(transition["receipt"] as Dictionary).duplicate(true)
					)
					sdk_terminal_taper_state = (
						(transition["state"] as Dictionary).duplicate(true)
					)
					sdk_terminal_handoff_active = (
						String(sdk_terminal_taper_state["mode"])
						!= String(sdk_terminal_taper_script.PASSIVE_MODE)
					)
					sdk_terminal_support_confirmed = bool(
						sdk_terminal_taper_state["confirmation_satisfied"]
					)
					var handoff_step: Variant = sdk_terminal_taper_state.get(
						"handoff_after_active_step"
					)
					var passive_step: Variant = sdk_terminal_taper_state.get(
						"first_passive_step"
					)
					sdk_terminal_handoff_after_active_step = (
						int(handoff_step) if handoff_step != null else -1
					)
					sdk_terminal_first_passive_step = (
						int(passive_step) if passive_step != null else -1
					)
					var handoff_reason_result := _normalize_sdk_terminal_handoff_reason(
						sdk_terminal_taper_state.get("handoff_reason")
					)
					if not bool(handoff_reason_result.get("ok", false)):
						sdk_terminal_restoration_failure_code = String(
							handoff_reason_result.get(
								"failure_code",
								"SDK_TERMINAL_HANDOFF_REASON_TYPE_INVALID",
							)
						)
					else:
						sdk_terminal_handoff_reason = String(
							handoff_reason_result["value"]
						)
					sdk_terminal_active_step_count = int(
						sdk_terminal_taper_state["active_step_count"]
					)
					sdk_terminal_passive_step_count = int(
						sdk_terminal_taper_state["passive_step_count"]
					)
					sdk_terminal_taper_step_count = int(
						sdk_terminal_taper_state["taper_step_count"]
					)
					sdk_terminal_taper_reset_count = int(
						sdk_terminal_taper_state["taper_reset_count"]
					)
					var first_loss: Variant = sdk_terminal_taper_state[
						"first_post_handoff_contact_loss_step"
					]
					sdk_terminal_first_post_handoff_contact_loss_step = (
						int(first_loss) if first_loss != null else -1
					)
					sdk_terminal_post_handoff_contact_loss_step_count = int(
						sdk_terminal_taper_state[
							"post_handoff_contact_loss_step_count"
						]
					)
					sdk_terminal_maximum_absolute_joint_position_error_rad = maxf(
						sdk_terminal_maximum_absolute_joint_position_error_rad,
						float(
							taper_observation[
								"maximum_absolute_joint_position_error_rad"
							]
						),
					)
			elif (
				sdk_terminal_support_handoff_enabled
				and sdk_terminal_trace_step >= sdk_terminal_controller_step_count
			):
				var terminal_step := (
					sdk_terminal_trace_step - sdk_terminal_controller_step_count
				)
				var active_this_step := sdk_terminal_restoration_window_active
				var all_four_support_contacts := terminal_contacts.values().all(
					func(value: Variant) -> bool: return bool(value)
				)
				var pre_support_counter := sdk_terminal_handoff_support_counter
				var transitioned := false
				if active_this_step:
					sdk_terminal_active_step_count += 1
					sdk_terminal_handoff_support_counter = (
						pre_support_counter + 1 if all_four_support_contacts else 0
					)
					if (
						sdk_terminal_handoff_support_counter
						>= int(
							sdk_terminal_restoration_options[
								"support_confirmation_step_count"
							]
						)
					):
						sdk_terminal_handoff_active = false
						sdk_terminal_handoff_after_active_step = terminal_step
						sdk_terminal_first_passive_step = terminal_step + 1
						sdk_terminal_handoff_reason = QSDK_R23D9_SUPPORT_REASON
						sdk_terminal_support_confirmed = true
						transitioned = true
					elif terminal_step == int(
						sdk_terminal_restoration_options[
							"maximum_active_neutral_acquisition_step_count"
						]
					) - 1:
						sdk_terminal_handoff_active = false
						sdk_terminal_handoff_after_active_step = terminal_step
						sdk_terminal_first_passive_step = terminal_step + 1
						sdk_terminal_handoff_reason = QSDK_R23D9_DEADLINE_REASON
						sdk_terminal_support_confirmed = false
						transitioned = true
				else:
					sdk_terminal_passive_step_count += 1
					if not all_four_support_contacts:
						sdk_terminal_post_handoff_contact_loss_step_count += 1
						if sdk_terminal_first_post_handoff_contact_loss_step < 0:
							sdk_terminal_first_post_handoff_contact_loss_step = terminal_step
				sdk_terminal_handoff_receipt = {
					"mode": QSDK_R23D9_ACTIVE_MODE if active_this_step else QSDK_R23D9_PASSIVE_MODE,
					"pre_step_support_counter": pre_support_counter,
					"post_step_support_counter": sdk_terminal_handoff_support_counter,
					"transition_after_step": transitioned,
					"next_mode": (
						QSDK_R23D9_ACTIVE_MODE
						if sdk_terminal_handoff_active
						else QSDK_R23D9_PASSIVE_MODE
					),
					"handoff_reason": sdk_terminal_handoff_reason if transitioned else null,
					"native_application_count": sdk_terminal_native_application_count_this_step,
				}
			if sdk_terminal_restoration_window_active:
				var restoration_step := (
					sdk_terminal_trace_step - sdk_terminal_controller_step_count
				)
				var all_four_contacts := terminal_contacts.values().all(
					func(value: Variant) -> bool: return bool(value)
				)
				if (
					all_four_contacts
					and sdk_terminal_first_all_four_contact_restoration_step < 0
				):
					sdk_terminal_first_all_four_contact_restoration_step = restoration_step
				if restoration_step >= 180:
					sdk_terminal_consecutive_all_four_contact_hold_steps = (
						sdk_terminal_consecutive_all_four_contact_hold_steps + 1
						if all_four_contacts
						else 0
					)
					sdk_terminal_maximum_consecutive_all_four_contact_hold_steps = maxi(
						sdk_terminal_maximum_consecutive_all_four_contact_hold_steps,
						sdk_terminal_consecutive_all_four_contact_hold_steps,
					)
			var r23d11_diagnostics: Dictionary = {}
			if sdk_terminal_stability_assisted_taper_enabled:
				r23d11_diagnostics = _r23d11_physical_trace_diagnostics(
					sdk_adapter_sample_result,
					sdk_adapter_step_result,
					sdk_authority_last_application_result,
					torso,
					initial_forward_axis_world,
					initial_lateral_axis_world,
					sdk_terminal_trace_step < sdk_terminal_controller_step_count,
					sdk_terminal_passive_window_active,
					String(
						sdk_terminal_restoration_options.get(
							"trace_row_schema_version", ""
						)
					),
				)
			var terminal_trace_result := _compose_sdk_terminal_trace_row(
				sdk_terminal_restoration_options,
				sdk_terminal_trace_step,
				_yaw_rad(torso),
				torso.global_position.y,
				_tilt_rad(torso),
				_body_bears_floor(torso, "torso", floor),
				terminal_contacts,
				sdk_terminal_native_application_count_this_step,
				int(
					sdk_authority_last_application_result.get(
						"neutral_target_activation_count", 0
					)
				),
				float(
					sdk_terminal_post_step_error.get(
						"maximum_absolute_joint_position_error_rad", NAN
					)
				),
				float(
					sdk_authority_last_application_result.get(
						"maximum_absolute_joint_velocity_rad_s", 0.0
					)
				),
				sdk_terminal_handoff_receipt,
				r23d11_diagnostics,
			)
			if sdk_terminal_residual_pose_authority_enabled:
				terminal_trace_result = _compose_sdk_r23d13_trace_row(
					sdk_terminal_restoration_options,
					sdk_terminal_trace_step,
					_yaw_rad(torso),
					torso.global_position.y,
					_tilt_rad(torso),
					_body_bears_floor(torso, "torso", floor),
					terminal_contacts,
					sdk_terminal_native_application_count_this_step,
					float(
						sdk_terminal_post_step_error.get(
							"maximum_absolute_joint_position_error_rad", NAN
						)
					),
					float(
						sdk_authority_last_application_result.get(
							"maximum_absolute_joint_velocity_rad_s", 0.0
						)
					),
					sdk_terminal_handoff_receipt,
					r23d11_diagnostics,
					sdk_terminal_command_time_feedback,
					sdk_terminal_authority_receipt,
				)
			if bool(terminal_trace_result.get("ok", false)):
				sdk_terminal_trace_rows.append(
					(terminal_trace_result.get("row", {}) as Dictionary).duplicate(true)
				)
			else:
				var terminal_trace_failure := String(
					terminal_trace_result.get(
						"failure_code",
						"R23D4_GJT_TRACE_ROW_INVALID",
					)
				)
				if not sdk_terminal_trace_failure_codes.has(terminal_trace_failure):
					sdk_terminal_trace_failure_codes.append(terminal_trace_failure)
		if (
			sdk_heading_schedule_enabled
			and String(sdk_heading_command_options.get("command_role", ""))
			== "turn_heading"
			and ungated_gait_tick + 1 == sdk_heading_command_segment_end_step_exclusive
		):
			sdk_heading_turn_end_yaw_rad = _yaw_rad(torso)
		executed_ticks = tick + 1
		if contact_gated_phase_progression and tick >= evidence_start_tick:
			var evidence_window_still_active := evidence_end_tick < 0 or tick < evidence_end_tick
			var minimum_gated_gait_tick := _minimum_dictionary_integer(gated_gait_tick_by_limb)
			for limb_value in limbs:
				var gated_limb: Dictionary = limb_value
				var gated_limb_id := String(gated_limb["limb_id"])
				var gait_advance_ticks := (
					int(gated_gait_tick_by_limb[gated_limb_id])
					- int(evidence_start_gait_tick_by_limb[gated_limb_id])
				)
				if (
					evidence_window_still_active
					and tick >= evidence_start_tick
					and gait_advance_ticks >= evidence_cycles * cycle_ticks
				):
					continue
				if not evidence_window_still_active:
					gated_gait_tick_by_limb[gated_limb_id] = (
						int(gated_gait_tick_by_limb[gated_limb_id]) + 1
					)
					continue
				var gated_phase_index := gait_phase_order.find(gated_limb_id)
				var commanded_gait_tick := (
					int(gated_gait_tick_by_limb[gated_limb_id])
					+ int(initial_perturbation["gait_phase_offset_ticks"])
				)
				var gate_receipt := _contact_gated_limb_phase_receipt(
					gated_limb,
					floor,
					gated_phase_index,
					commanded_gait_tick,
					swing_ticks,
					cycle_ticks,
				)
				var gate_active := bool(gate_receipt.get("gate_active", false))
				var contact_satisfied := bool(gate_receipt.get("contact_satisfied", false))
				if gate_active and contact_satisfied:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = (
						int(current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id]) + 1
					)
				elif gate_active:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
				else:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
				var hold_phase := (
					gate_active
					and (
						not contact_satisfied
						or (
							int(current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id])
							< minimum_airborne_dwell_ticks
						)
					)
				)
				if (
					hold_phase
					and (
						int(current_contact_gate_hold_ticks_by_limb[gated_limb_id])
						< maximum_contact_gate_hold_ticks
					)
				):
					var hold_reason := String(gate_receipt["hold_reason"])
					current_contact_gate_hold_ticks_by_limb[gated_limb_id] = (
						int(current_contact_gate_hold_ticks_by_limb[gated_limb_id]) + 1
					)
					contact_gate_hold_tick_count_by_limb[gated_limb_id] = (
						int(contact_gate_hold_tick_count_by_limb[gated_limb_id]) + 1
					)
					if hold_reason == "await_release":
						contact_gate_release_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_release_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
					else:
						contact_gate_recontact_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_recontact_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
				else:
					if hold_phase:
						contact_gate_timeout_count_by_limb[gated_limb_id] = (
							int(contact_gate_timeout_count_by_limb[gated_limb_id]) + 1
						)
						(
							(contact_gate_timeout_receipts_by_limb[gated_limb_id] as Array)
							. append(
								{
									"tick": tick,
									"limb_id": gated_limb_id,
									"hold_reason": String(gate_receipt.get("hold_reason", "")),
									"local_phase_tick":
									int(gate_receipt.get("local_phase_tick", -1)),
									"contact_satisfied": contact_satisfied,
									"foot_bears_floor": _foot_bears_floor(gated_limb, floor),
									"maximum_hold_ticks": maximum_contact_gate_hold_ticks,
									"gated_gait_tick": int(gated_gait_tick_by_limb[gated_limb_id]),
									"commanded_gait_tick": commanded_gait_tick,
								}
							)
						)
					var current_gated_gait_tick := int(gated_gait_tick_by_limb[gated_limb_id])
					var phase_lead_ticks := current_gated_gait_tick - minimum_gated_gait_tick
					if (
						phase_lead_ticks > 0
						and phase_lead_ticks >= maximum_contact_gated_phase_skew_ticks
					):
						contact_gate_phase_sync_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_phase_sync_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
					else:
						gated_gait_tick_by_limb[gated_limb_id] = current_gated_gait_tick + 1
					current_contact_gate_hold_ticks_by_limb[gated_limb_id] = 0
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
			if evidence_end_tick < 0 and tick >= evidence_start_tick:
				var evidence_gait_advance_ticks := _minimum_dictionary_difference(
					gated_gait_tick_by_limb, evidence_start_gait_tick_by_limb
				)
				if evidence_gait_advance_ticks >= evidence_cycles * cycle_ticks:
					evidence_end_tick = tick + 1
					evidence_end_gait_tick = evidence_start_gait_tick + evidence_gait_advance_ticks
					evidence_end_gait_tick_by_limb = gated_gait_tick_by_limb.duplicate(true)
					cooldown_end_tick = evidence_end_tick + cooldown_cycles * cycle_ticks
					evidence_end_torso_position = torso.global_position
				elif tick + 1 >= maximum_evidence_end_tick:
					contact_gated_evidence_horizon_timeout = true
					evidence_end_tick = tick + 1
					evidence_end_gait_tick = evidence_start_gait_tick + evidence_gait_advance_ticks
					evidence_end_gait_tick_by_limb = gated_gait_tick_by_limb.duplicate(true)
					cooldown_end_tick = evidence_end_tick + cooldown_cycles * cycle_ticks
					evidence_end_torso_position = torso.global_position
		if tick == settle_ticks - 1:
			initial_all_four_contacts = _all_feet_bear_floor(limbs, floor)
		if tick >= evidence_start_tick and (evidence_end_tick < 0 or tick < evidence_end_tick):
			_update_contact_cycle_receipts(
				tick,
				limbs,
				floor,
				contact_state_by_limb,
				contact_cycle_count_by_limb,
				rejected_short_contact_cycle_count_by_limb,
				maximum_cycle_relocation_by_limb_m,
				minimum_cycle_relocation_by_limb_m,
				contact_transition_receipts_by_limb,
				minimum_airborne_dwell_ticks,
				MINIMUM_FOOT_RELOCATION_M,
			)
			for limb_value in limbs:
				var limb: Dictionary = limb_value
				var limb_id := String(limb["limb_id"])
				var foot: RigidBody3D = limb["foot"]
				maximum_foot_center_height_by_limb_m[limb_id] = maxf(
					float(maximum_foot_center_height_by_limb_m[limb_id]), foot.global_position.y
				)
				if _foot_bears_floor(limb, floor):
					current_contact_absent_dwell_by_limb_ticks[limb_id] = 0
				else:
					contact_absent_tick_count_by_limb[limb_id] = (
						int(contact_absent_tick_count_by_limb[limb_id]) + 1
					)
					current_contact_absent_dwell_by_limb_ticks[limb_id] = (
						int(current_contact_absent_dwell_by_limb_ticks[limb_id]) + 1
					)
					longest_contact_absent_dwell_by_limb_ticks[limb_id] = maxi(
						int(longest_contact_absent_dwell_by_limb_ticks[limb_id]),
						int(current_contact_absent_dwell_by_limb_ticks[limb_id])
					)
		var torso_tilt_rad := _tilt_rad(torso)
		maximum_tilt_rad = maxf(maximum_tilt_rad, torso_tilt_rad)
		minimum_torso_height_m = minf(minimum_torso_height_m, torso.global_position.y)
		var torso_ground_contact := _body_bears_floor(torso, "torso", floor)
		if sdk_deferred_recovery_trace_step_pending:
			var deferred_trace_after_failure := (
				DeferredRecoveryTraceScript.capture_after_solver_step(
					sdk_deferred_recovery_trace_buffer,
					ungated_gait_tick,
					torso.global_position,
					torso.global_basis.get_rotation_quaternion(),
					torso.linear_velocity,
					torso.angular_velocity,
					torso_tilt_rad,
					torso_ground_contact,
					_bearing_contact_by_limb(limbs, floor),
				)
			)
			if (
				not deferred_trace_after_failure.is_empty()
				and not sdk_physical_trace_failure_codes.has(deferred_trace_after_failure)
			):
				sdk_physical_trace_failure_codes.append(deferred_trace_after_failure)
		if torso_ground_contact:
			torso_contact_ticks += 1
			if first_torso_contact_tick < 0:
				first_torso_contact_tick = tick
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			for state_value in limb["joint_states"]:
				var joint_state: Dictionary = state_value
				var geometry := _joint_geometry_receipt(state_value)
				var anchor_error_m := float(geometry["anchor_error_m"])
				if anchor_error_m > maximum_anchor_error_m:
					maximum_anchor_error_m = anchor_error_m
					maximum_anchor_error_joint_id = String(joint_state["joint_id"])
					maximum_anchor_error_tick = tick
					maximum_anchor_error_context = (
						latest_motor_command_context_by_joint_id
						. get(maximum_anchor_error_joint_id, {})
						. duplicate(true)
					)
				var hinge_axis_error_rad := float(geometry["hinge_axis_error_rad"])
				if hinge_axis_error_rad > maximum_hinge_axis_error_rad:
					maximum_hinge_axis_error_rad = hinge_axis_error_rad
					maximum_hinge_axis_error_joint_id = String(joint_state["joint_id"])
					maximum_hinge_axis_error_tick = tick
		if (
			dynamic_support_diagnostic_enabled
			and dynamic_support_sample_failure_code.is_empty()
			and tick >= settle_ticks - 1
		):
			var active_semantic_contact_ids: Array = []
			var support_point_by_semantic_contact_id: Dictionary = {}
			var floor_plane_height_m := (
				floor.global_position.y + 0.05 * float(fixture["fixture_view_scale"])
			)
			for contact_limb_id_value in DynamicSupportReceiptScript.ORDERED_CONTACT_IDS:
				var contact_limb_id := String(contact_limb_id_value)
				var contact_limb := _limb_by_id(limbs, contact_limb_id)
				if not contact_limb.is_empty() and _foot_bears_floor(contact_limb, floor):
					var contact_foot: RigidBody3D = contact_limb["foot"]
					active_semantic_contact_ids.append(contact_limb_id)
					support_point_by_semantic_contact_id[contact_limb_id] = Vector3(
						contact_foot.global_position.x,
						floor_plane_height_m,
						contact_foot.global_position.z,
					)
			var ordered_support_points_world: Array[Vector3] = []
			for polygon_contact_id_value in (
				DynamicSupportReceiptScript.ORDERED_SUPPORT_POLYGON_CONTACT_IDS
			):
				var polygon_contact_id := String(polygon_contact_id_value)
				if support_point_by_semantic_contact_id.has(polygon_contact_id):
					ordered_support_points_world.append(
						support_point_by_semantic_contact_id[polygon_contact_id]
					)
			var observer_result := (
				DynamicSupportObserverScript
				. observe(
					dynamic_support_body_by_id,
					ordered_support_points_world,
					float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)),
				)
			)
			var sample_result := (
				(
					DynamicSupportReceiptScript
					. compile_sample_gq15(
						tick,
						_dynamic_support_phase_id(
							tick,
							settle_ticks,
							evidence_start_tick,
							evidence_end_tick,
							cooldown_end_tick,
						),
						active_semantic_contact_ids,
						observer_result,
						(torso.global_position - initial_torso_position).dot(
							initial_lateral_axis_world
						),
					)
				)
				if (
					String(dynamic_support_options.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				else (
					(
						DynamicSupportReceiptScript
						. compile_sample_gq14(
							tick,
							_dynamic_support_phase_id(
								tick,
								settle_ticks,
								evidence_start_tick,
								evidence_end_tick,
								cooldown_end_tick,
							),
							active_semantic_contact_ids,
							observer_result,
							(torso.global_position - initial_torso_position).dot(
								initial_lateral_axis_world
							),
						)
					)
					if (
						String(dynamic_support_options.get("receipt_schema_version", ""))
						== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
					)
					else (
						DynamicSupportReceiptScript
						. compile_sample(
							tick,
							_dynamic_support_phase_id(
								tick,
								settle_ticks,
								evidence_start_tick,
								evidence_end_tick,
								cooldown_end_tick,
							),
							active_semantic_contact_ids,
							observer_result,
							(torso.global_position - initial_torso_position).dot(
								initial_lateral_axis_world
							),
						)
					)
				)
			)
			if bool(sample_result.get("ok", false)):
				dynamic_support_trace.append(
					(sample_result["sample"] as Dictionary).duplicate(true)
				)
			else:
				dynamic_support_sample_failure_code = String(
					sample_result.get("failure_code", "DYNAMIC_SUPPORT_SAMPLE_UNKNOWN_FAILURE")
				)
		var run_end_tick := (
			cooldown_end_tick + terminal_settle_ticks if cooldown_end_tick >= 0 else -1
		)
		if tick % 120 == 0 or tick + 1 == run_end_tick:
			print(
				(
					(
						"    wave_tick=%d torso=%s tilt=%.6f contacts=%s cycles=%s "
						+ "joint_angles=%s foot_heights=%s "
						+ "motor_speed=%.6f anchor=%.6f hinge=%.6f"
					)
					% [
						tick,
						str(torso.global_position),
						torso_tilt_rad,
						str(_bearing_contact_by_limb(limbs, floor)),
						str(contact_cycle_count_by_limb),
						str(_joint_angles_by_limb(limbs)),
						str(_foot_heights_by_limb(limbs)),
						maximum_motor_target_speed_rad_s,
						maximum_anchor_error_m,
						maximum_hinge_axis_error_rad,
					]
				)
			)
		if not authority_horizon_enabled and run_end_tick >= 0 and tick + 1 >= run_end_tick:
			break
	if not evidence_start_torso_position.is_finite():
		evidence_start_torso_position = initial_torso_position
	if not evidence_end_torso_position.is_finite():
		evidence_end_torso_position = torso.global_position
	terminal_all_four_contacts = _all_feet_bear_floor(limbs, floor)
	var contact_observer_callback_count_by_limb := _contact_observer_callback_count_by_limb(limbs)
	var every_contact_observer_executed := true
	for limb_id_value in LIMB_ORDER:
		every_contact_observer_executed = (
			every_contact_observer_executed
			and int(contact_observer_callback_count_by_limb[String(limb_id_value)]) > 0
		)
	var evidence_torso_displacement := evidence_end_torso_position - evidence_start_torso_position
	var final_torso_displacement := torso.global_position - evidence_start_torso_position
	var evidence_task_frame_forward_displacement_m := evidence_torso_displacement.dot(
		initial_forward_axis_world
	)
	var final_task_frame_forward_displacement_m := final_torso_displacement.dot(
		initial_forward_axis_world
	)
	var final_task_frame_lateral_displacement_m := final_torso_displacement.dot(
		initial_lateral_axis_world
	)
	var final_signed_reference_heading_error_rad := _wrap_angle(
		_yaw_rad(torso) - initial_yaw_rad
	)
	var final_yaw_drift_rad := absf(final_signed_reference_heading_error_rad)
	var evidence_gait_advance_ticks_by_limb: Dictionary = {}
	var every_limb_completed_evidence_gait_horizon := true
	for limb_id_value in LIMB_ORDER:
		var gait_limb_id := String(limb_id_value)
		var gait_advance_ticks := (
			(
				int(evidence_end_gait_tick_by_limb[gait_limb_id])
				- int(evidence_start_gait_tick_by_limb[gait_limb_id])
			)
			if contact_gated_phase_progression
			else evidence_cycles * cycle_ticks
		)
		evidence_gait_advance_ticks_by_limb[gait_limb_id] = gait_advance_ticks
		every_limb_completed_evidence_gait_horizon = (
			every_limb_completed_evidence_gait_horizon
			and gait_advance_ticks == evidence_cycles * cycle_ticks
		)
	var every_limb_two_cycles := true
	var every_limb_relocated := true
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		every_limb_two_cycles = (
			every_limb_two_cycles and int(contact_cycle_count_by_limb[limb_id]) >= 2
		)
		every_limb_relocated = (
			every_limb_relocated
			and is_finite(float(minimum_cycle_relocation_by_limb_m[limb_id]))
			and (
				float(minimum_cycle_relocation_by_limb_m[limb_id])
				>= float(evidence_threshold_options["minimum_foot_relocation_m"])
			)
		)
	var sdk_adapter_execution_summary: Dictionary = {}
	var sdk_adapter_shutdown_receipt := {
		"schema_version": "sporespore_godot_jolt_adapter_shutdown_receipt_v1",
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"explicit_shutdown_completed": not sdk_adapter_enabled,
		"native_controller_session_destroy_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if sdk_adapter_enabled:
		sdk_adapter_execution_summary = sdk_adapter.summary()
		sdk_adapter_shutdown_receipt = sdk_adapter.shutdown()
		sdk_adapter = null
	if sdk_deferred_recovery_trace_enabled:
		var deferred_trace_materialization_result := (
			DeferredRecoveryTraceScript.materialize_after_final_solver_step(
				sdk_deferred_recovery_trace_buffer,
				int(sdk_adapter_execution_summary.get("step_count", -1)),
			)
		)
		if bool(deferred_trace_materialization_result.get("ok", false)):
			sdk_physical_trace_rows.assign(
				deferred_trace_materialization_result.get("rows", [])
			)
			sdk_deferred_recovery_trace_instrumentation_receipt = (
				(
					deferred_trace_materialization_result.get(
						"observer_instrumentation_receipt",
						{},
					) as Dictionary
				).duplicate(true)
			)
		else:
			var deferred_materialization_failure := String(
				deferred_trace_materialization_result.get(
					"failure_code",
					"QSDK_R10E_DEFERRED_TRACE_MATERIALIZATION_INVALID",
				)
			)
			if not sdk_physical_trace_failure_codes.has(deferred_materialization_failure):
				sdk_physical_trace_failure_codes.append(deferred_materialization_failure)
	var walking_gate_receipts := {
		"one_continuous_world": true,
		"no_world_reset": true,
		"fixture_spec_compiled_before_world_creation": true,
		"initial_perturbation_within_declared_envelope": true,
		"contact_gating_completed_without_timeout":
		_sum_dictionary_integers(contact_gate_timeout_count_by_limb) == 0,
		"contact_gated_evidence_horizon_completed": not contact_gated_evidence_horizon_timeout,
		"every_limb_completed_evidence_gait_horizon": every_limb_completed_evidence_gait_horizon,
		"pinned_jolt_solver_settings": solver_policy_realized,
		"no_torso_force_or_impulse_or_velocity_or_transform_command":
		(
			direct_torso_force_command_count == 0
			and direct_torso_impulse_command_count == 0
			and direct_torso_velocity_command_count == 0
			and direct_torso_transform_command_count == 0
		),
		"bounded_joint_only_lateral_stride_steering":
		(
			maximum_absolute_lateral_stride_steering_fraction
			<= MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
		),
		"initial_four_contact_stance": initial_all_four_contacts,
		"every_contact_observer_executed": every_contact_observer_executed,
		"every_limb_two_contact_cycles": every_limb_two_cycles,
		"every_limb_forward_relocation": every_limb_relocated,
		"minimum_evidence_forward_translation":
		(
			evidence_task_frame_forward_displacement_m
			>= float(evidence_threshold_options["minimum_evidence_torso_advance_m"])
		),
		"minimum_final_forward_translation":
		(
			final_task_frame_forward_displacement_m
			>= float(evidence_threshold_options["minimum_final_torso_advance_m"])
		),
		"bounded_lateral_drift":
		(
			absf(final_task_frame_lateral_displacement_m)
			<= float(evidence_threshold_options["maximum_lateral_drift_m"])
		),
		"bounded_yaw_drift":
		final_yaw_drift_rad <= float(evidence_threshold_options["maximum_yaw_drift_rad"]),
		"bounded_tilt": maximum_tilt_rad <= float(evidence_threshold_options["maximum_tilt_rad"]),
		"bounded_torso_height":
		minimum_torso_height_m >= float(evidence_threshold_options["minimum_torso_height_m"]),
		"zero_torso_contact": torso_contact_ticks == 0,
		"terminal_four_contact_recovery": terminal_all_four_contacts,
		"bounded_anchor_error":
		maximum_anchor_error_m <= float(evidence_threshold_options["maximum_anchor_error_m"]),
		"bounded_hinge_axis_error":
		(
			maximum_hinge_axis_error_rad
			<= float(evidence_threshold_options["maximum_hinge_axis_error_rad"])
		),
	}
	if evidence_support_acquisition_enabled:
		walking_gate_receipts["evidence_support_acquisition"] = (
			evidence_support_acquisition_passed and not evidence_support_acquisition_timed_out
		)
	else:
		walking_gate_receipts["evidence_four_contact_stance"] = (evidence_all_four_contacts_at_start)
	if sdk_adapter_enabled:
		walking_gate_receipts["explicit_sdk_controller_session_shutdown"] = (
			bool(sdk_adapter_shutdown_receipt.get("ok", false))
			and bool(sdk_adapter_shutdown_receipt.get("explicit_shutdown_completed", false))
			and int(
				sdk_adapter_shutdown_receipt.get(
					"native_controller_session_destroy_count",
					-1,
				)
			)
			== (
				1
				if bool(
					sdk_adapter_shutdown_receipt.get(
						"native_controller_session_required",
						false,
					)
				)
				else 0
			)
		)
	if sdk_authority_enabled:
		if sdk_live_fixture_actuator_cap_binding_enabled:
			walking_gate_receipts["sdk_live_fixture_actuator_cap_binding"] = (
				bool(sdk_live_fixture_actuator_cap_binding_receipt.get("ok", false))
				and int(
					sdk_live_fixture_actuator_cap_binding_receipt.get(
						"validated_actuator_count",
						-1,
					)
				)
				== 8
				and int(
					sdk_live_fixture_actuator_cap_binding_receipt.get("write_count", -1)
				)
				== 8
				and bool(
					sdk_live_fixture_actuator_cap_binding_receipt.get(
						"all_postbinding_readbacks_match",
						false,
					)
				)
			)
		var sdk_authority_step_count := int(sdk_adapter_execution_summary.get("step_count", 0))
		var sdk_native_application_gate := false
		if sdk_terminal_restoration_enabled:
			var expected_terminal_active_steps := (
				sdk_terminal_active_step_count
				if sdk_terminal_support_handoff_enabled
				else QSDK_R23D4_RESTORATION_STEP_COUNT
			)
			var expected_terminal_authority_steps := (
				QSDK_R23D4_CONTROLLER_STEP_COUNT + expected_terminal_active_steps
			)
			sdk_native_application_gate = (
				bool(sdk_adapter_start_result.get("ok", false))
				and bool(sdk_adapter_execution_summary.get("actuation_authority", false))
				and sdk_authority_failure_code.is_empty()
				and sdk_terminal_restoration_failure_code.is_empty()
				and sdk_authority_step_count == expected_terminal_authority_steps
				and int(
					sdk_adapter_execution_summary.get(
						"native_actuation_application_count",
						-1,
					)
				) == QSDK_R23D4_CONTROLLER_STEP_COUNT * 8
				and sdk_terminal_native_application_count
				== expected_terminal_active_steps * 8
				and sdk_terminal_application_mismatch_count == 0
			)
		else:
			sdk_native_application_gate = (
				bool(sdk_adapter_start_result.get("ok", false))
				and bool(sdk_adapter_execution_summary.get("actuation_authority", false))
				and sdk_authority_failure_code.is_empty()
				and sdk_authority_step_count > 0
				and int(
					sdk_adapter_execution_summary.get(
						"native_actuation_application_count",
						-1,
					)
				) == sdk_authority_step_count * 8
			)
		if sdk_stability_overlay_enabled:
			var overlay_summary: Dictionary = (
				sdk_adapter_execution_summary
				. get(
					"stability_overlay_summary",
					{},
				)
			)
			walking_gate_receipts["sdk_stability_overlay_evidence_actuation"] = (
				sdk_native_application_gate
				and bool(
					(
						sdk_adapter_execution_summary
						. get(
							"stability_overlay_runtime_ok",
							false,
						)
					)
				)
				and sdk_authority_step_count == effective_fixed_exposure_step_count
				and legacy_sdk_overlay_base_application_count == sdk_authority_step_count * 8
				and bool(overlay_summary.get("ok", false))
				and (
					int(overlay_summary.get("application_step_count", -1))
					== sdk_authority_step_count
				)
				and (
					int(overlay_summary.get("motor_write_count", -1))
					== sdk_authority_step_count * 8
				)
				and int(overlay_summary.get("failure_count", -1)) == 0
			)
		elif sdk_terminal_restoration_enabled:
			walking_gate_receipts["native_sdk_terminal_restoration_actuation"] = (
				sdk_native_application_gate
				and int(sdk_adapter_execution_summary.get("mismatch_count", -1)) == 0
				and int(sdk_adapter_execution_summary.get("safe_no_actuation_count", -1)) == 0
				and int(
					sdk_adapter_execution_summary.get(
						"native_safe_disable_application_count",
						-1,
					)
				) == 0
				and legacy_evidence_actuation_application_count == 0
				and legacy_post_settle_actuation_application_count == 0
			)
		elif sdk_full_post_settle_authority_enabled:
			var native_sdk_exclusive_authority_gate := (
				sdk_native_application_gate
				and bool(sdk_adapter_execution_summary.get("ok", false))
				and legacy_evidence_actuation_application_count == 0
				and legacy_post_settle_actuation_application_count == 0
				and sdk_authority_step_count == executed_ticks - settle_ticks
			)
			walking_gate_receipts["native_sdk_exclusive_post_settle_actuation"] = (native_sdk_exclusive_authority_gate)
		else:
			walking_gate_receipts["native_sdk_exclusive_evidence_actuation"] = (
				sdk_native_application_gate
				and bool(sdk_adapter_execution_summary.get("ok", false))
				and legacy_evidence_actuation_application_count == 0
			)
	var walking_observed := true
	for receipt_value in walking_gate_receipts.values():
		walking_observed = walking_observed and bool(receipt_value)
	var dynamic_support_receipt_result := {
		"ok": not dynamic_support_diagnostic_enabled,
		"failure_code": "",
		"world_build_count": 0,
	}
	if dynamic_support_diagnostic_enabled:
		if not dynamic_support_sample_failure_code.is_empty():
			dynamic_support_receipt_result = {
				"ok": false,
				"failure_code": dynamic_support_sample_failure_code,
				"world_build_count": 0,
			}
		else:
			var dynamic_support_metadata := {
				"contact_progression_timeout": contact_gated_evidence_horizon_timeout,
				"evidence_extension_ticks": maxi(evidence_end_tick - nominal_evidence_end_tick, 0),
				"maximum_anchor_error_tick": maximum_anchor_error_tick,
				"final_support_contact_state": _bearing_contact_by_limb(limbs, floor),
				"lateral_limit_m": float(dynamic_support_options["lateral_limit_m"]),
				"source_digests":
				(dynamic_support_options["source_digests"] as Dictionary).duplicate(true),
			}
			dynamic_support_receipt_result = (
				(
					DynamicSupportReceiptScript
					. compile_gq15(
						dynamic_support_trace,
						dynamic_support_metadata,
					)
				)
				if (
					String(dynamic_support_options.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				else (
					(
						DynamicSupportReceiptScript
						. compile_gq14(
							dynamic_support_trace,
							dynamic_support_metadata,
						)
					)
					if (
						String(dynamic_support_options.get("receipt_schema_version", ""))
						== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
					)
					else (
						DynamicSupportReceiptScript
						. compile(
							dynamic_support_trace,
							dynamic_support_metadata,
						)
					)
				)
			)
	var sdk_heading_turn_phase_yaw_delta_rad := NAN
	if (
		is_finite(sdk_heading_turn_start_yaw_rad)
		and is_finite(sdk_heading_turn_end_yaw_rad)
	):
		sdk_heading_turn_phase_yaw_delta_rad = _wrap_angle(
			sdk_heading_turn_end_yaw_rad - sdk_heading_turn_start_yaw_rad
		)
	var sdk_heading_mean_turn_held_steering_fraction := NAN
	if sdk_heading_turn_held_steering_sample_count > 0:
		sdk_heading_mean_turn_held_steering_fraction = (
			sdk_heading_turn_held_steering_sum
			/ float(sdk_heading_turn_held_steering_sample_count)
		)
	var sdk_heading_schedule_receipt := {
		"schema_version": "sporespore_godot_jolt_heading_schedule_execution_v1",
		"enabled": sdk_heading_schedule_enabled,
		"schedule_id": String(sdk_heading_schedule_options["schedule_id"]),
		"schedule_sha256": sdk_heading_schedule_sha256,
		"observed_segment_sample_counts": sdk_heading_segment_sample_counts.duplicate(true),
		"reference_heading_sample_count": sdk_heading_reference_sample_count,
		"turn_heading_sample_count": sdk_heading_turn_sample_count,
		"command_failure_code": sdk_heading_command_failure_code,
		"turn_phase_start_yaw_rad": sdk_heading_turn_start_yaw_rad,
		"turn_phase_end_yaw_rad": sdk_heading_turn_end_yaw_rad,
		"turn_phase_yaw_delta_rad": sdk_heading_turn_phase_yaw_delta_rad,
		"final_reference_heading_error_rad": final_signed_reference_heading_error_rad,
		"maximum_absolute_requested_steering_fraction":
		sdk_heading_maximum_absolute_requested_steering_fraction,
		"maximum_absolute_held_steering_fraction":
		sdk_heading_maximum_absolute_held_steering_fraction,
		"mean_turn_held_steering_fraction":
		sdk_heading_mean_turn_held_steering_fraction,
		"world_build_count": 1,
		"physical_acceptance_authority": false,
	}
	var observed_candidate_authority_steps := (
		effective_fixed_exposure_step_count
		if sdk_terminal_restoration_enabled
		else executed_ticks - sdk_adapter_start_tick
	)
	var summary := {
		"ok": walking_observed,
		"failure_code": "" if walking_observed else "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED",
		"schema_version": "physical_wave_gait_quadruped_development_summary_v1",
		"fixture_spec": fixture_spec.duplicate(true),
		"fixture_spec_sha256": fixture_spec_sha256,
		"fixture_view_scale": float(fixture["fixture_view_scale"]),
		"controller_configuration": controller_configuration.duplicate(true),
		"controller_configuration_sha256": controller_configuration_sha256,
		"evidence_threshold_options": evidence_threshold_options.duplicate(true),
		"evidence_threshold_configuration_sha256": evidence_threshold_configuration_sha256,
		"evidence_acquisition_options": evidence_acquisition_options.duplicate(true),
		"evidence_acquisition_configuration_sha256": evidence_acquisition_configuration_sha256,
		"solver_policy_options": solver_policy_options.duplicate(true),
		"realized_solver_policy_options": realized_solver_policy_options.duplicate(true),
		"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
		"physics_hz": physics_hz,
		"physics_engine": physics_engine,
		"solver_velocity_steps": solver_velocity_steps,
		"solver_position_steps": solver_position_steps,
		"world_build_count": 1,
		"world_reset_count": 0,
		"motor_direction_sign": motor_direction_sign,
		"knee_motor_impulse_scale": knee_motor_impulse_scale,
		"knee_flexion_scale": knee_flexion_scale,
		"contact_clearance_assist_rad": contact_clearance_assist_rad,
		"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		"gait_phase_order_id": gait_phase_order_id,
		"gait_phase_order": gait_phase_order.duplicate(),
		"body_count": bodies.size(),
		"limb_count": limbs.size(),
		"executed_ticks": executed_ticks,
		"candidate_authority_horizon_enabled": authority_horizon_enabled,
		"authority_horizon_policy_id": (
			String(authority_horizon_options.get("policy_id", ""))
			if authority_horizon_enabled else ""
		),
		"authority_horizon_policy_sha256": (
			String(authority_horizon_options.get("policy_sha256", ""))
			if authority_horizon_enabled else ""
		),
		"candidate_authority_observation_count": (
			observed_candidate_authority_steps if authority_horizon_enabled else 0
		),
		"first_candidate_authority_observation_index": 0 if authority_horizon_enabled else -1,
		"last_candidate_authority_observation_index": (
			observed_candidate_authority_steps - 1 if authority_horizon_enabled else -1
		),
		"pre_authority_world_tick_count": (
			sdk_adapter_start_tick if authority_horizon_enabled else -1
		),
		"candidate_specific_horizon_extension_count": 0 if authority_horizon_enabled else -1,
		"cycle_ticks": cycle_ticks,
		"swing_ticks": swing_ticks,
		"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		"gait_clock_options": gait_clock_options.duplicate(true),
		"initial_perturbation": initial_perturbation.duplicate(true),
		"robustness_options": robustness_options.duplicate(true),
		"path_steering_options": path_steering_options.duplicate(true),
		"actuator_impulse_options": actuator_impulse_options.duplicate(true),
		"motor_velocity_options": motor_velocity_options.duplicate(true),
		"realized_hip_max_impulse_nms": float(fixture["realized_hip_max_impulse_nms"]),
		"realized_knee_max_impulse_nms": float(fixture["realized_knee_max_impulse_nms"]),
		"nominal_evidence_end_tick": nominal_evidence_end_tick,
		"maximum_evidence_end_tick": maximum_evidence_end_tick,
		"evidence_extension_ticks": evidence_end_tick - nominal_evidence_end_tick,
		"evidence_start_gait_tick": evidence_start_gait_tick,
		"evidence_start_gait_tick_by_limb": evidence_start_gait_tick_by_limb.duplicate(true),
		"evidence_end_gait_tick":
		(
			evidence_end_gait_tick
			if contact_gated_phase_progression
			else evidence_start_gait_tick + evidence_cycles * cycle_ticks
		),
		"evidence_gait_advance_ticks":
		(
			evidence_end_gait_tick - evidence_start_gait_tick
			if contact_gated_phase_progression
			else evidence_cycles * cycle_ticks
		),
		"evidence_end_gait_tick_by_limb": evidence_end_gait_tick_by_limb.duplicate(true),
		"evidence_gait_advance_ticks_by_limb": evidence_gait_advance_ticks_by_limb.duplicate(true),
		"contact_gated_evidence_horizon_timeout": contact_gated_evidence_horizon_timeout,
		"contact_gate_hold_tick_count_by_limb":
		contact_gate_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_release_hold_tick_count_by_limb":
		contact_gate_release_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_recontact_hold_tick_count_by_limb":
		contact_gate_recontact_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_timeout_count_by_limb": contact_gate_timeout_count_by_limb.duplicate(true),
		"contact_gate_timeout_receipts_by_limb":
		contact_gate_timeout_receipts_by_limb.duplicate(true),
		"contact_gate_phase_sync_hold_tick_count_by_limb":
		contact_gate_phase_sync_hold_tick_count_by_limb.duplicate(true),
		"initial_linear_velocity_body_initialization_count":
		int(fixture["initial_linear_velocity_body_initialization_count"]),
		"initial_torso_angular_velocity_initialization_count":
		int(fixture["initial_torso_angular_velocity_initialization_count"]),
		"evidence_start_tick": evidence_start_tick,
		"evidence_end_tick": evidence_end_tick,
		"contact_cycle_count_by_limb": contact_cycle_count_by_limb.duplicate(true),
		"rejected_short_contact_cycle_count_by_limb":
		rejected_short_contact_cycle_count_by_limb.duplicate(true),
		"maximum_cycle_relocation_by_limb_m": maximum_cycle_relocation_by_limb_m.duplicate(true),
		"minimum_cycle_relocation_by_limb_m": minimum_cycle_relocation_by_limb_m.duplicate(true),
		"maximum_foot_center_height_by_limb_m":
		maximum_foot_center_height_by_limb_m.duplicate(true),
		"contact_absent_tick_count_by_limb": contact_absent_tick_count_by_limb.duplicate(true),
		"longest_contact_absent_dwell_by_limb_ticks":
		longest_contact_absent_dwell_by_limb_ticks.duplicate(true),
		"contact_transition_receipts_by_limb": contact_transition_receipts_by_limb.duplicate(true),
		"contact_clearance_assist_tick_count_by_limb":
		contact_clearance_assist_tick_count_by_limb.duplicate(true),
		"initial_torso_position_world_m": initial_torso_position,
		"initial_torso_orientation_xyzw":
		{
			"x": initial_torso_orientation.x,
			"y": initial_torso_orientation.y,
			"z": initial_torso_orientation.z,
			"w": initial_torso_orientation.w,
		},
		"evidence_start_torso_position_world_m": evidence_start_torso_position,
		"evidence_end_torso_position_world_m": evidence_end_torso_position,
		"final_torso_position_world_m": torso.global_position,
		"final_torso_orientation_xyzw":
		{
			"x": torso.global_basis.get_rotation_quaternion().normalized().x,
			"y": torso.global_basis.get_rotation_quaternion().normalized().y,
			"z": torso.global_basis.get_rotation_quaternion().normalized().z,
			"w": torso.global_basis.get_rotation_quaternion().normalized().w,
		},
		"evidence_torso_displacement_world_m": evidence_torso_displacement,
		"final_torso_displacement_world_m": final_torso_displacement,
		"evidence_task_frame_forward_displacement_m": evidence_task_frame_forward_displacement_m,
		"final_task_frame_forward_displacement_m": final_task_frame_forward_displacement_m,
		"final_task_frame_lateral_displacement_m": final_task_frame_lateral_displacement_m,
		"task_frame_forward_axis_world_unit": initial_forward_axis_world,
		"task_frame_lateral_axis_world_unit": initial_lateral_axis_world,
		"final_yaw_drift_rad": final_yaw_drift_rad,
		"maximum_tilt_rad": maximum_tilt_rad,
		"minimum_torso_height_m": minimum_torso_height_m,
		"final_torso_height_m": torso.global_position.y,
		"torso_contact_ticks": torso_contact_ticks,
		"first_torso_contact_tick": first_torso_contact_tick,
		"initial_all_four_contacts": initial_all_four_contacts,
		"evidence_all_four_contacts_at_start": evidence_all_four_contacts_at_start,
		"evidence_start_bearing_contact_by_limb":
		evidence_start_bearing_contact_by_limb.duplicate(true),
		"evidence_boundary_contact_trace": evidence_boundary_contact_trace.duplicate(true),
		"evidence_support_acquisition_receipt":
		{
			"schema_version": "sporespore_evidence_support_acquisition_receipt_v1",
			"policy_id": String(evidence_acquisition_options["policy_id"]),
			"enabled": evidence_support_acquisition_enabled,
			"nominal_evidence_start_tick": evidence_start_tick,
			"maximum_acquisition_ticks": maximum_evidence_support_acquisition_ticks,
			"minimum_all_support_dwell_ticks": minimum_all_support_acquisition_dwell_ticks,
			"acquired": evidence_support_acquisition_passed,
			"acquisition_tick": evidence_support_acquisition_tick,
			"acquisition_tick_from_nominal_start":
			(
				evidence_support_acquisition_tick - evidence_start_tick
				if evidence_support_acquisition_tick >= 0
				else -1
			),
			"timed_out": evidence_support_acquisition_timed_out,
			"controller_parameter": false,
			"walking_claim_authorized": false,
		},
		"evidence_support_acquisition_trace": evidence_support_acquisition_trace.duplicate(true),
		"terminal_all_four_contacts": terminal_all_four_contacts,
		"terminal_bearing_contact_by_limb": _bearing_contact_by_limb(limbs, floor),
		"contact_observer_callback_count_by_limb": contact_observer_callback_count_by_limb,
		"motor_command_count": motor_command_count,
		"legacy_evidence_actuation_application_count": legacy_evidence_actuation_application_count,
		"legacy_post_settle_actuation_application_count":
		legacy_post_settle_actuation_application_count,
		"legacy_sdk_overlay_base_application_count": legacy_sdk_overlay_base_application_count,
		"sdk_execution_mode_plan": sdk_execution_mode_plan.duplicate(true),
		"sdk_p5i3c_fixed_exposure_enabled": sdk_p5i3c_fixed_exposure_enabled,
		"sdk_p5i3c_fixed_exposure_step_count":
		effective_fixed_exposure_step_count if sdk_p5i3c_fixed_exposure_enabled else 0,
		"maximum_motor_target_speed_rad_s": maximum_motor_target_speed_rad_s,
		"maximum_motor_target_speed_by_joint_role_rad_s":
		maximum_motor_target_speed_by_joint_role_rad_s.duplicate(true),
		"contact_loaded_swing_knee_speed_cap_activation_count":
		contact_loaded_swing_knee_speed_cap_activation_count,
		"maximum_contact_loaded_swing_knee_target_speed_rad_s":
		maximum_contact_loaded_swing_knee_target_speed_rad_s,
		"anchor_error_guard_activation_count": anchor_error_guard_activation_count,
		"maximum_anchor_error_guard_input_m": maximum_anchor_error_guard_input_m,
		"maximum_anchor_error_guard_progress": maximum_anchor_error_guard_progress,
		"minimum_anchor_error_guard_speed_limit_rad_s":
		(
			minimum_anchor_error_guard_speed_limit_rad_s
			if is_finite(minimum_anchor_error_guard_speed_limit_rad_s)
			else controller_maximum_motor_target_speed_rad_s
		),
		"maximum_anchor_error_guarded_target_speed_rad_s":
		maximum_anchor_error_guarded_target_speed_rad_s,
		"maximum_measured_joint_speed_rad_s": maximum_measured_joint_speed_rad_s,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_anchor_error_joint_id": maximum_anchor_error_joint_id,
		"maximum_anchor_error_tick": maximum_anchor_error_tick,
		"maximum_anchor_error_context": maximum_anchor_error_context.duplicate(true),
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"maximum_hinge_axis_error_joint_id": maximum_hinge_axis_error_joint_id,
		"maximum_hinge_axis_error_tick": maximum_hinge_axis_error_tick,
		"direct_torso_force_command_count": direct_torso_force_command_count,
		"direct_torso_impulse_command_count": direct_torso_impulse_command_count,
		"direct_torso_velocity_command_count": direct_torso_velocity_command_count,
		"direct_torso_transform_command_count": direct_torso_transform_command_count,
		"environment_challenge_options": environment_challenge_options.duplicate(true),
		"environment_challenge_configuration_sha256": environment_challenge_configuration_sha256,
		"terrain_profile_id": String(environment_challenge_options["terrain_profile_id"]),
		"terrain_shape_count": int(fixture["terrain_shape_count"]),
		"external_push_application_count": external_push_application_count,
		"external_push_receipt": external_push_receipt.duplicate(true),
		"observation_fault_application_count": observation_fault_application_count,
		"observation_fault_base_and_stability_count": observation_fault_base_and_stability_count,
		"maximum_observation_fault_component": maximum_observation_fault_component,
		"lateral_stride_steering_target_adjustment_count":
		lateral_stride_steering_target_adjustment_count,
		"maximum_absolute_lateral_stride_steering_fraction":
		maximum_absolute_lateral_stride_steering_fraction,
		"path_steering_update_receipts": path_steering_update_receipts.duplicate(true),
		"maximum_absolute_path_cross_track_error_m": maximum_absolute_path_cross_track_error_m,
		"maximum_absolute_path_yaw_tracking_error_rad":
		maximum_absolute_path_yaw_tracking_error_rad,
		"walking_gate_receipts": walking_gate_receipts,
		"physical_wave_gait_walking_observed": walking_observed,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	if dynamic_support_diagnostic_enabled:
		summary["dynamic_support_diagnostic_enabled"] = true
		summary["dynamic_support_diagnostic_ok"] = bool(
			dynamic_support_receipt_result.get("ok", false)
		)
		summary["dynamic_support_diagnostic_failure_code"] = String(
			dynamic_support_receipt_result.get("failure_code", "")
		)
		summary["dynamic_support_trace_sample_count"] = dynamic_support_trace.size()
		summary["dynamic_support_receipt"] = (
			(dynamic_support_receipt_result.get("dynamic_support_receipt", {}) as Dictionary)
			. duplicate(true)
		)
		summary["dynamic_support_receipt_sha256"] = String(
			dynamic_support_receipt_result.get("dynamic_support_receipt_sha256", "")
		)
	if sdk_adapter_enabled:
		summary["sdk_material_profile"] = sdk_material_profile.duplicate(true)
		summary["sdk_material_profile_sha256"] = sdk_material_profile_sha256
		summary["sdk_transport_execution_receipt"] = (
			sdk_transport_execution_receipt.duplicate(true)
		)
		summary["sdk_adapter_shutdown_receipt"] = (
			sdk_adapter_shutdown_receipt.duplicate(true)
		)
	if sdk_heading_schedule_enabled:
		summary["sdk_heading_schedule_options"] = (
			sdk_heading_schedule_options.duplicate(true)
		)
		summary["sdk_heading_schedule_sha256"] = sdk_heading_schedule_sha256
		summary["sdk_heading_schedule_receipt"] = (
			sdk_heading_schedule_receipt.duplicate(true)
		)
	if authority_horizon_enabled:
		summary["sdk_fixed_controller_horizon_receipt"] = {
			"schema_version": "sporespore_sdk_fixed_controller_horizon_receipt_v1",
			"enabled": true,
			"policy_id": String(authority_horizon_options.get("policy_id", "")),
			"policy_sha256": String(authority_horizon_options.get("policy_sha256", "")),
			"expected_controller_step_count": effective_fixed_exposure_step_count,
			"observed_controller_step_count": observed_candidate_authority_steps,
			"first_controller_step_index": 0,
			"last_controller_step_index": observed_candidate_authority_steps - 1,
			"exact": (
				observed_candidate_authority_steps == effective_fixed_exposure_step_count
			),
			"configuration_proved_before_fixture_insertion": true,
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		}
	if sdk_physical_trace_enabled:
		var sdk_physical_trace_summary := {
			"schema_version": "sporespore_sdk_physical_trace_v1",
			"enabled": true,
			"options": sdk_physical_trace_options.duplicate(true),
			"configuration_sha256": String(
				physical_trace_result.get("sdk_physical_trace_configuration_sha256", "")
			),
			"row_count": sdk_physical_trace_rows.size(),
			"failure_codes": sdk_physical_trace_failure_codes.duplicate(),
			"rows": sdk_physical_trace_rows.duplicate(true),
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		}
		if sdk_deferred_recovery_trace_enabled:
			sdk_physical_trace_summary["observer_instrumentation_receipt"] = (
				sdk_deferred_recovery_trace_instrumentation_receipt.duplicate(true)
			)
		summary["sdk_physical_trace"] = sdk_physical_trace_summary
	if sdk_startup_velocity_ramp_enabled:
		summary["sdk_startup_velocity_ramp"] = {
			"schema_version": "sporespore_sdk_startup_velocity_ramp_execution_v1",
			"enabled": true,
			"policy_id": sdk_startup_velocity_ramp_policy_id,
			"ramp_step_count": (
				SdkSupportLossConditionedStartupScript.RAMP_STEPS
				if sdk_startup_velocity_ramp_policy_id
				== SdkSupportLossConditionedStartupScript.POLICY_ID
				else SdkStartupVelocityRampScript.RAMP_STEPS
			),
			"composition_step_count": sdk_startup_ramp_composition_step_count,
			"active_step_count": sdk_startup_ramp_active_step_count,
			"exact_zero_scale_step_count": sdk_startup_ramp_exact_zero_scale_step_count,
			"exact_unity_scale_step_count": sdk_startup_ramp_exact_unity_scale_step_count,
			"maximum_absolute_residual_rad_s":
			sdk_startup_ramp_maximum_absolute_residual_rad_s,
			"controller_state_or_phase_modified": false,
			"startup_ramp_triggered": (
				int(sdk_support_loss_startup_state.get("trigger_step", -1)) >= 0
				if not sdk_support_loss_startup_state.is_empty()
				else true
			),
			"startup_ramp_trigger_step": (
				int(sdk_support_loss_startup_state["trigger_step"])
				if (
					not sdk_support_loss_startup_state.is_empty()
					and int(sdk_support_loss_startup_state["trigger_step"]) >= 0
				)
				else null
			),
			"startup_probe_minimum_support_count": (
				int(sdk_support_loss_startup_state["minimum_probe_support_count"])
				if not sdk_support_loss_startup_state.is_empty()
				else null
			),
			"startup_transform_composition_integrity_passed": (
				sdk_startup_ramp_composition_step_count
				== effective_fixed_exposure_step_count
			),
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		}
	if sdk_terminal_restoration_enabled:
		var sdk_terminal_taper_outcome: Dictionary = (
			sdk_terminal_taper_script.outcome(sdk_terminal_taper_state)
			if sdk_terminal_quiescent_taper_enabled
			else {}
		)
		summary["sdk_terminal_restoration"] = {
			"schema_version": "sporespore_qsdk_r23d4_godot_terminal_execution_v1",
			"enabled": true,
			"options": sdk_terminal_restoration_options.duplicate(true),
			"configuration_sha256": String(
				terminal_restoration_result.get(
					"sdk_terminal_restoration_configuration_sha256",
					"",
				)
			),
			"failure_code": sdk_terminal_restoration_failure_code,
			"restoration_receipt_count": sdk_terminal_restoration_receipt_count,
			"neutral_stance_receipt_count": sdk_terminal_restoration_receipt_count,
			"terminal_receipt_validation_failure_count": (
				sdk_terminal_restoration_receipt_validation_failure_count
			),
			"captured_pose_memory_transition_count": (
				sdk_terminal_capture_transition_count
			),
			"captured_pose_memory_transition_failure_count": (
				sdk_terminal_capture_transition_failure_count
			),
			"neutral_target_activation_command_count": (
				sdk_terminal_neutral_target_activation_command_count
			),
			"neutral_target_activation_failure_count": (
				sdk_terminal_neutral_target_activation_failure_count
			),
			"neutral_target_transition_count": sdk_terminal_capture_transition_count,
			"neutral_target_transition_failure_count": (
				sdk_terminal_capture_transition_failure_count
			),
			"heading_correction_receipt_count": (
				sdk_terminal_heading_correction_receipt_count
			),
			"native_actuation_application_count": sdk_terminal_native_application_count,
			"actuator_application_mismatch_count": sdk_terminal_application_mismatch_count,
			"maximum_absolute_restoration_joint_velocity_rad_s": (
				sdk_terminal_maximum_absolute_joint_velocity_rad_s
			),
			"maximum_absolute_terminal_stance_joint_velocity_rad_s": (
				sdk_terminal_maximum_absolute_joint_velocity_rad_s
			),
			"maximum_absolute_joint_position_error_rad": (
				sdk_terminal_maximum_absolute_joint_position_error_rad
			),
			"first_all_four_contact_restoration_step": (
				sdk_terminal_first_all_four_contact_restoration_step
			),
			"first_all_four_contact_terminal_stance_step": (
				sdk_terminal_first_all_four_contact_restoration_step
			),
			"consecutive_all_four_contact_hold_step_count": (
				sdk_terminal_maximum_consecutive_all_four_contact_hold_steps
			),
			"passive_zero_target_applied": sdk_terminal_passive_zero_applied,
			"trace_row_count": sdk_terminal_trace_rows.size(),
			"trace_failure_codes": sdk_terminal_trace_failure_codes.duplicate(),
			"trace_rows": sdk_terminal_trace_rows.duplicate(true),
			"support_confirmed_handoff_enabled": sdk_terminal_support_handoff_enabled,
			"quiescent_taper_enabled": sdk_terminal_quiescent_taper_enabled,
			"support_confirmed": sdk_terminal_support_confirmed,
			"confirmation_satisfied": sdk_terminal_support_confirmed,
			"handoff_after_active_step": (
				sdk_terminal_handoff_after_active_step
				if sdk_terminal_handoff_after_active_step >= 0
				else null
			),
			"first_passive_step": (
				sdk_terminal_first_passive_step
				if sdk_terminal_first_passive_step >= 0
				else null
			),
			"handoff_reason": (
				sdk_terminal_handoff_reason
				if not sdk_terminal_handoff_reason.is_empty()
				else null
			),
			"active_terminal_step_count": sdk_terminal_active_step_count,
			"quiescent_taper_step_count": sdk_terminal_taper_step_count,
			"passive_terminal_step_count": sdk_terminal_passive_step_count,
			"taper_reset_count": sdk_terminal_taper_reset_count,
			"active_terminal_native_actuation_application_count": int(
				sdk_terminal_taper_state.get("active_native_application_count", 0)
			)
			if sdk_terminal_quiescent_taper_enabled
			else sdk_terminal_native_application_count,
			"post_handoff_native_actuation_application_count": int(
				sdk_terminal_taper_state.get("passive_native_application_count", 0)
			)
			if sdk_terminal_quiescent_taper_enabled
			else 0,
			"quiescent_taper_gate_passed": bool(
				sdk_terminal_taper_outcome.get("quiescent_taper_gate_passed", false)
			),
			"first_post_handoff_contact_loss_step": (
				sdk_terminal_first_post_handoff_contact_loss_step
				if sdk_terminal_first_post_handoff_contact_loss_step >= 0
				else null
			),
			"post_handoff_contact_loss_step_count": (
				sdk_terminal_post_handoff_contact_loss_step_count
			),
			"world_build_count": 1,
			"physical_acceptance_authority": false,
		}
	if sdk_shadow_enabled:
		summary["sdk_shadow_enabled"] = true
		summary["sdk_shadow_options"] = sdk_shadow_options.duplicate(true)
		summary["sdk_shadow_start_result"] = sdk_adapter_start_result.duplicate(true)
		summary["sdk_shadow_summary"] = sdk_adapter_execution_summary.duplicate(true)
	if sdk_authority_enabled:
		summary["sdk_authority_enabled"] = true
		summary["sdk_authority_scope"] = sdk_authority_scope
		summary["sdk_full_authority_stability_contribution_enabled"] = (
			sdk_full_authority_stability_contribution_enabled
		)
		summary["sdk_adapter_start_tick"] = sdk_adapter_start_tick
		summary["sdk_phase_offset_activation_tick"] = sdk_phase_offset_activation_tick
		summary["sdk_authority_options"] = sdk_authority_options.duplicate(true)
		summary["sdk_authority_start_result"] = sdk_adapter_start_result.duplicate(true)
		summary["sdk_live_fixture_actuator_cap_binding_enabled"] = (
			sdk_live_fixture_actuator_cap_binding_enabled
		)
		if sdk_live_fixture_actuator_cap_binding_enabled:
			summary["sdk_live_fixture_actuator_cap_binding_receipt"] = (
				sdk_live_fixture_actuator_cap_binding_receipt.duplicate(true)
			)
			if not sdk_actuator_cap_profile_resolution_receipt.is_empty():
				summary["sdk_actuator_cap_profile_resolution_receipt"] = (
					sdk_actuator_cap_profile_resolution_receipt.duplicate(true)
				)
			if not sdk_actuator_cap_profile_physical_binding_receipt.is_empty():
				summary["sdk_actuator_cap_profile_physical_binding_receipt"] = (
					sdk_actuator_cap_profile_physical_binding_receipt.duplicate(true)
				)
		summary["sdk_authority_failure_code"] = sdk_authority_failure_code
		summary["sdk_authority_last_application_result"] = (
			sdk_authority_last_application_result.duplicate(true)
		)
		summary["sdk_authority_summary"] = sdk_adapter_execution_summary.duplicate(true)
	cleanup_node.queue_free()
	await tree.physics_frame
	await tree.process_frame
	Engine.physics_ticks_per_second = original_hz
	return summary


static func _r23d11_physical_trace_diagnostics(
	sample_result: Dictionary,
	step_result: Dictionary,
	application_result: Dictionary,
	torso: RigidBody3D,
	forward_axis_world: Vector3,
	lateral_axis_world: Vector3,
	controller_phase: bool,
	passive_phase: bool,
	trace_row_schema_version: String = "",
) -> Dictionary:
	return _r23d11_physical_trace_diagnostics_from_task_velocities(
		sample_result,
		step_result,
		application_result,
		torso.linear_velocity.dot(forward_axis_world),
		torso.linear_velocity.dot(lateral_axis_world),
		torso.angular_velocity.dot(Vector3.UP),
		controller_phase,
		passive_phase,
		trace_row_schema_version,
	)


static func _r23d11_physical_trace_diagnostics_from_task_velocities(
	sample_result: Dictionary,
	step_result: Dictionary,
	application_result: Dictionary,
	base_linear_velocity_task_forward_m_s: float,
	base_linear_velocity_task_lateral_m_s: float,
	base_angular_velocity_task_yaw_rad_s: float,
	controller_phase: bool,
	passive_phase: bool,
	trace_row_schema_version: String = "",
) -> Dictionary:
	var zero_deltas: Array = []
	for _index in 8:
		zero_deltas.append(0.0)
	var availability: Variant = null
	var support_margin: Variant = null
	var applied_deltas: Array = zero_deltas
	if not passive_phase:
		var independent_support_margin_availability := (
			_sdk_terminal_uses_independent_support_margin_availability(
				trace_row_schema_version
			)
		)
		var contribution: Dictionary = step_result.get("stability_contribution_shadow", {})
		var influence: Dictionary = contribution.get("influence_receipt", {})
		availability = String(influence.get("availability", ""))
		if availability == "upstream_infeasible":
			availability = SdkGodotJoltStabilityAssistedTaperScript.PLANNING_INFEASIBLE
		if (
			independent_support_margin_availability
			or availability != SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE
		):
			var stability_shadow: Dictionary = sample_result.get("stability_shadow", {})
			var native_observation: Dictionary = stability_shadow.get("native_observation", {})
			var margin_value: Variant = native_observation.get("minimum_dynamic_support_margin_m")
			if [TYPE_FLOAT, TYPE_INT].has(typeof(margin_value)) and is_finite(float(margin_value)):
				support_margin = float(margin_value)
		if not controller_phase:
			var applied_value: Variant = application_result.get(
				"ordered_applied_stability_velocity_deltas_rad_s"
			)
			if typeof(applied_value) == TYPE_ARRAY:
				applied_deltas = (applied_value as Array).duplicate()
	var result := {
		"ok": true,
		"failure_code": "",
		"base_linear_velocity_task_forward_m_s": base_linear_velocity_task_forward_m_s,
		"base_linear_velocity_task_lateral_m_s": base_linear_velocity_task_lateral_m_s,
		"base_angular_velocity_task_yaw_rad_s": base_angular_velocity_task_yaw_rad_s,
		"minimum_dynamic_support_margin_m": support_margin,
		"stability_planning_availability": availability,
		"ordered_applied_stability_velocity_deltas_rad_s": applied_deltas,
	}
	if [
		QSDK_R23D19_TRACE_ROW_SCHEMA,
		QSDK_R23D20_TRACE_ROW_SCHEMA,
		QSDK_R23D21_TRACE_ROW_SCHEMA,
	].has(
		trace_row_schema_version
	):
		var path_diagnostics := _r23d19_controller_path_diagnostics(
			sample_result,
			step_result,
			controller_phase,
		)
		if not bool(path_diagnostics.get("ok", false)):
			result["ok"] = false
			result["failure_code"] = String(
				path_diagnostics.get(
					"failure_code",
					"R23D19_GJT_PATH_DIAGNOSTIC_INVALID",
				)
			)
			return result
		for field_value in [
			"requested_heading_error_rad",
			"cross_track_error_m",
			"cross_track_velocity_m_s",
			"legacy_fixed_axis_cross_track_error_m",
			"legacy_fixed_axis_cross_track_velocity_m_s",
			"measured_yaw_error_rad",
			"desired_heading_error_rad",
			"yaw_tracking_error_rad",
			"requested_steering_fraction",
			"held_steering_fraction",
		]:
			var field := String(field_value)
			result[field] = path_diagnostics[field]
	return result


static func _r23d19_controller_path_diagnostics(
	sample_result: Dictionary,
	step_result: Dictionary,
	controller_phase: bool,
) -> Dictionary:
	var fields := [
		"requested_heading_error_rad",
		"cross_track_error_m",
		"cross_track_velocity_m_s",
		"legacy_fixed_axis_cross_track_error_m",
		"legacy_fixed_axis_cross_track_velocity_m_s",
		"measured_yaw_error_rad",
		"desired_heading_error_rad",
		"yaw_tracking_error_rad",
		"requested_steering_fraction",
		"held_steering_fraction",
	]
	var result := {"ok": true, "failure_code": ""}
	if not controller_phase:
		for field_value in fields:
			result[String(field_value)] = null
		return result
	var request_value: Variant = sample_result.get("request", null)
	var native_output_value: Variant = step_result.get("native_output", null)
	if typeof(request_value) != TYPE_DICTIONARY or typeof(native_output_value) != TYPE_DICTIONARY:
		return _sdk_terminal_trace_failure("R23D19_GJT_PATH_DIAGNOSTIC_INPUT_INVALID")
	var request: Dictionary = request_value
	var state_value: Variant = request.get("state", null)
	var command_value: Variant = request.get("command", null)
	var actuation_value: Variant = (native_output_value as Dictionary).get("actuation", null)
	if (
		typeof(state_value) != TYPE_DICTIONARY
		or typeof(command_value) != TYPE_DICTIONARY
		or typeof(actuation_value) != TYPE_DICTIONARY
	):
		return _sdk_terminal_trace_failure("R23D19_GJT_PATH_DIAGNOSTIC_INPUT_INVALID")
	var state: Dictionary = state_value
	var command: Dictionary = command_value
	var receipt_value: Variant = (actuation_value as Dictionary).get("receipt", null)
	var base_pose_value: Variant = state.get("base_pose_world", null)
	var base_twist_value: Variant = state.get("base_twist_world", null)
	var task_frame_value: Variant = state.get("task_frame", null)
	if (
		typeof(receipt_value) != TYPE_DICTIONARY
		or typeof(base_pose_value) != TYPE_DICTIONARY
		or typeof(base_twist_value) != TYPE_DICTIONARY
		or typeof(task_frame_value) != TYPE_DICTIONARY
	):
		return _sdk_terminal_trace_failure("R23D19_GJT_PATH_DIAGNOSTIC_INPUT_INVALID")
	var receipt: Dictionary = receipt_value
	var base_pose: Dictionary = base_pose_value
	var base_twist: Dictionary = base_twist_value
	var task_frame: Dictionary = task_frame_value
	var position := _r23d3_vector_projection(base_pose.get("position_m", null))
	var velocity := _r23d3_vector_projection(base_twist.get("linear_velocity_m_s", null))
	var origin := _r23d3_vector_projection(task_frame.get("origin_world_m", null))
	var fixed_lateral := _r23d3_vector_projection(task_frame.get("lateral_axis_world_unit", null))
	if (
		not bool(position.get("ok", false))
		or not bool(velocity.get("ok", false))
		or not bool(origin.get("ok", false))
		or not bool(fixed_lateral.get("ok", false))
	):
		return _sdk_terminal_trace_failure("R23D19_GJT_PATH_DIAGNOSTIC_VECTOR_INVALID")
	var position_values: Array = position["values"]
	var velocity_values: Array = velocity["values"]
	var origin_values: Array = origin["values"]
	var lateral_values: Array = fixed_lateral["values"]
	var legacy_error := 0.0
	var legacy_velocity := 0.0
	for index in 3:
		legacy_error += (
			(float(position_values[index]) - float(origin_values[index]))
			* float(lateral_values[index])
		)
		legacy_velocity += float(velocity_values[index]) * float(lateral_values[index])
	var reference_yaw_rad := float(task_frame.get("reference_yaw_rad", NAN))
	var desired_heading_rad := float(command.get("desired_heading_rad", NAN))
	var requested_heading_error_rad := _wrap_angle(desired_heading_rad - reference_yaw_rad)
	var values := {
		"requested_heading_error_rad": requested_heading_error_rad,
		"cross_track_error_m": float(receipt.get("cross_track_error_m", NAN)),
		"cross_track_velocity_m_s": float(receipt.get("cross_track_velocity_m_s", NAN)),
		"legacy_fixed_axis_cross_track_error_m": legacy_error,
		"legacy_fixed_axis_cross_track_velocity_m_s": legacy_velocity,
		"measured_yaw_error_rad": float(receipt.get("measured_yaw_error_rad", NAN)),
		"desired_heading_error_rad": float(receipt.get("desired_heading_error_rad", NAN)),
		"yaw_tracking_error_rad": float(receipt.get("yaw_tracking_error_rad", NAN)),
		"requested_steering_fraction": float(receipt.get("requested_steering_fraction", NAN)),
		"held_steering_fraction": float(receipt.get("held_steering_fraction", NAN)),
	}
	for field_value in fields:
		var field := String(field_value)
		if not is_finite(float(values[field])):
			return _sdk_terminal_trace_failure("R23D19_GJT_PATH_DIAGNOSTIC_NONFINITE:%s" % field)
		result[field] = values[field]
	return result


static func _sdk_terminal_uses_independent_support_margin_availability(
	trace_row_schema_version: String,
) -> bool:
	return (
		[
			QSDK_R23D12_TRACE_ROW_SCHEMA,
			QSDK_R23D13_TRACE_ROW_SCHEMA,
			QSDK_R23D14_TRACE_ROW_SCHEMA,
			QSDK_R23D15_TRACE_ROW_SCHEMA,
			QSDK_R23D16_TRACE_ROW_SCHEMA,
			QSDK_R23D17_TRACE_ROW_SCHEMA,
			QSDK_R23D18_TRACE_ROW_SCHEMA,
			QSDK_R23D19_TRACE_ROW_SCHEMA,
			QSDK_R23D20_TRACE_ROW_SCHEMA,
			QSDK_R23D21_TRACE_ROW_SCHEMA,
		]
		. has(trace_row_schema_version)
	)


static func run_sdk_terminal_diagnostics_schema_canary() -> Dictionary:
	var sample_result := {
		"stability_shadow": {
			"native_observation": {"minimum_dynamic_support_margin_m": 0.05}
		}
	}
	var step_result := {
		"stability_contribution_shadow": {
			"influence_receipt": {
				"availability": SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE
			}
		}
	}
	var successor_diagnostics := _r23d11_physical_trace_diagnostics_from_task_velocities(
		sample_result,
		step_result,
		{},
		0.2,
		-0.1,
		0.05,
		true,
		false,
		QSDK_R23D17_TRACE_ROW_SCHEMA,
	)
	var inherited_diagnostics := _r23d11_physical_trace_diagnostics_from_task_velocities(
		sample_result,
		step_result,
		{},
		0.2,
		-0.1,
		0.05,
		true,
		false,
		QSDK_R23D11_TRACE_ROW_SCHEMA,
	)
	var exact := (
		_sdk_terminal_uses_independent_support_margin_availability(
			QSDK_R23D17_TRACE_ROW_SCHEMA
		)
		and _sdk_terminal_uses_independent_support_margin_availability(
			QSDK_R23D16_TRACE_ROW_SCHEMA
		)
		and _sdk_terminal_uses_independent_support_margin_availability(
			QSDK_R23D15_TRACE_ROW_SCHEMA
		)
		and _sdk_terminal_uses_independent_support_margin_availability(
			QSDK_R23D14_TRACE_ROW_SCHEMA
		)
		and not _sdk_terminal_uses_independent_support_margin_availability(
			QSDK_R23D11_TRACE_ROW_SCHEMA
		)
		and float(successor_diagnostics.get("minimum_dynamic_support_margin_m", NAN))
		== 0.05
		and inherited_diagnostics.get("minimum_dynamic_support_margin_m") == null
		and (
			String(successor_diagnostics.get("stability_planning_availability", ""))
			== SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE
		)
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "SDK_TERMINAL_DIAGNOSTICS_SCHEMA_CANARY_INVALID",
		"positive_canary_count": 3,
		"mutation_control_count": 1,
		"successor_minimum_dynamic_support_margin_m": successor_diagnostics.get(
			"minimum_dynamic_support_margin_m"
		),
		"legacy_minimum_dynamic_support_margin_m": inherited_diagnostics.get(
			"minimum_dynamic_support_margin_m"
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_terminal_trace_row(
	options: Dictionary,
	trace_step: int,
	measured_yaw_rad: float,
	torso_height_m: float,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	contacts_by_limb: Dictionary,
	native_application_count: int,
	neutral_target_activation_count: int = 0,
	maximum_absolute_joint_position_error_rad: float = 0.0,
	maximum_absolute_commanded_joint_velocity_rad_s: float = 0.0,
	support_handoff_receipt: Dictionary = {},
	r23d11_diagnostics: Dictionary = {},
) -> Dictionary:
	if bool(options.get("stability_assisted_taper_enabled", false)):
		return _compose_sdk_stability_assisted_taper_trace_row(
			options,
			trace_step,
			measured_yaw_rad,
			torso_height_m,
			torso_tilt_rad,
			torso_ground_contact,
			contacts_by_limb,
			native_application_count,
			maximum_absolute_joint_position_error_rad,
			maximum_absolute_commanded_joint_velocity_rad_s,
			support_handoff_receipt,
			r23d11_diagnostics,
		)
	if bool(options.get("quiescent_taper_enabled", false)):
		return _compose_sdk_quiescent_taper_trace_row(
			options,
			trace_step,
			measured_yaw_rad,
			torso_height_m,
			torso_tilt_rad,
			torso_ground_contact,
			contacts_by_limb,
			native_application_count,
			maximum_absolute_joint_position_error_rad,
			maximum_absolute_commanded_joint_velocity_rad_s,
			support_handoff_receipt,
		)
	if bool(options.get("support_confirmed_handoff_enabled", false)):
		return _compose_sdk_support_handoff_trace_row(
			options,
			trace_step,
			measured_yaw_rad,
			torso_height_m,
			torso_tilt_rad,
			torso_ground_contact,
			contacts_by_limb,
			native_application_count,
			maximum_absolute_joint_position_error_rad,
			maximum_absolute_commanded_joint_velocity_rad_s,
			support_handoff_receipt,
		)
	if (
		trace_step < 0
		or trace_step >= QSDK_R23D4_TOTAL_TRACE_STEP_COUNT
		or not is_finite(measured_yaw_rad)
		or not is_finite(torso_height_m)
		or not is_finite(torso_tilt_rad)
	):
		return _sdk_terminal_trace_failure("R23D4_GJT_TRACE_OBSERVATION_INVALID")
	var expected_contact_keys := [
		"front_left",
		"front_right",
		"rear_left",
		"rear_right",
	]
	var contact_keys := contacts_by_limb.keys()
	contact_keys.sort()
	if contact_keys != expected_contact_keys:
		return _sdk_terminal_trace_failure("R23D4_GJT_TRACE_CONTACT_KEYS_INVALID")
	var phase_id := "reference_warmup"
	var neutral_stance := (
		String(options.get("terminal_restoration_policy_id", ""))
		== SdkGodotJoltNeutralStanceScript.POLICY_ID
	)
	var desired_heading_offset_rad := 0.0
	var controller_semantic_step: Variant = trace_step
	if trace_step < 600:
		phase_id = "reference_warmup"
	elif trace_step < 1800:
		phase_id = "commanded_turn"
		desired_heading_offset_rad = float(options["turn_heading_offset_rad"])
	elif trace_step < 2400:
		phase_id = "reference_recovery"
	elif trace_step < QSDK_R23D4_CONTROLLER_STEP_COUNT:
		phase_id = "reference_continuation"
	elif trace_step < QSDK_R23D4_CONTROLLER_STEP_COUNT + 180:
		phase_id = (
			"terminal_neutral_stance_acquisition"
			if neutral_stance
			else "terminal_contact_acquisition"
		)
		controller_semantic_step = null
	elif trace_step < QSDK_R23D4_ACTIVE_STEP_COUNT:
		phase_id = (
			"terminal_neutral_stance_hold"
			if neutral_stance
			else "terminal_captured_pose_hold"
		)
		controller_semantic_step = null
	else:
		phase_id = "passive_zero_actuation_settle"
		controller_semantic_step = null
	var passive := phase_id == "passive_zero_actuation_settle"
	var restoration := phase_id.begins_with("terminal_")
	var expected_native_count := 0 if passive else 8
	if native_application_count != expected_native_count:
		return _sdk_terminal_trace_failure("R23D4_GJT_TRACE_APPLICATION_COUNT_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"row":
		{
			"schema_version": String(
				options.get("trace_row_schema_version", QSDK_R23D4_TRACE_ROW_SCHEMA)
			),
			"cell_id": String(options["cell_id"]),
			"trace_step": trace_step,
			"phase_id": phase_id,
			"controller_semantic_step": controller_semantic_step,
			"desired_heading_offset_rad": desired_heading_offset_rad,
			"measured_yaw_rad": measured_yaw_rad,
			"torso_height_m": torso_height_m,
			"torso_tilt_rad": torso_tilt_rad,
			"torso_ground_contact": torso_ground_contact,
			"ordered_foot_contacts":
			{
				"front_left": bool(contacts_by_limb["front_left"]),
				"front_right": bool(contacts_by_limb["front_right"]),
				"rear_left": bool(contacts_by_limb["rear_left"]),
				"rear_right": bool(contacts_by_limb["rear_right"]),
			},
			"actuator_command_count": expected_native_count,
			"native_actuation_application_count": native_application_count,
			"zero_actuation": passive,
			"command_composition_mode": (
				"passive_zero_actuation_v1"
				if passive
				else String(options["terminal_restoration_policy_id"])
				if restoration
				else "balanced_wave_turning_v1"
			),
			"restoration_receipt_present": restoration,
			"terminal_stance_receipt_present": restoration and neutral_stance,
			"neutral_target_activation_count": (
				neutral_target_activation_count if restoration and neutral_stance else null
			),
			"maximum_absolute_joint_position_error_rad": (
				maximum_absolute_joint_position_error_rad
				if restoration and neutral_stance
				else null
			),
			"maximum_absolute_commanded_joint_velocity_rad_s": (
				maximum_absolute_commanded_joint_velocity_rad_s
				if restoration and neutral_stance
				else null
			),
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_quiescent_taper_trace_row(
	options: Dictionary,
	trace_step: int,
	measured_yaw_rad: float,
	torso_height_m: float,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	contacts_by_limb: Dictionary,
	native_application_count: int,
	maximum_absolute_joint_position_error_rad: float,
	maximum_absolute_commanded_joint_velocity_rad_s: float,
	taper_receipt: Dictionary,
) -> Dictionary:
	var controller_steps := int(options["controller_step_count"])
	var total_steps := int(options["total_traced_step_count"])
	if (
		trace_step < 0
		or trace_step >= total_steps
		or not is_finite(measured_yaw_rad)
		or not is_finite(torso_height_m)
		or not is_finite(torso_tilt_rad)
	):
		return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_OBSERVATION_INVALID")
	var expected_contact_keys := [
		"front_left",
		"front_right",
		"rear_left",
		"rear_right",
	]
	var contact_keys := contacts_by_limb.keys()
	contact_keys.sort()
	if contact_keys != expected_contact_keys:
		return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_CONTACT_KEYS_INVALID")
	var phase_id := "reference_warmup"
	var desired_heading_offset_rad := 0.0
	var controller_semantic_step: Variant = trace_step
	var terminal := trace_step >= controller_steps
	var mode := ""
	if trace_step < 600:
		phase_id = "reference_warmup"
	elif trace_step < 1800:
		phase_id = "commanded_turn"
		desired_heading_offset_rad = float(options["turn_heading_offset_rad"])
	elif trace_step < 2400:
		phase_id = "reference_recovery"
	elif trace_step < controller_steps:
		phase_id = "reference_continuation"
	else:
		controller_semantic_step = null
		mode = String(taper_receipt.get("mode", ""))
		match mode:
			SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE:
				phase_id = "terminal_neutral_acquisition"
			SdkGodotJoltQuiescentTaperScript.TAPER_MODE:
				phase_id = "terminal_quiescent_taper"
			SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE:
				phase_id = "terminal_irreversible_zero_actuation"
			_:
				return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_MODE_INVALID")
	var active := terminal and mode != SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE
	var expected_native_count := 8 if not terminal or active else 0
	if native_application_count != expected_native_count:
		return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_APPLICATION_COUNT_INVALID")
	if terminal:
		var expected_receipt_keys := [
			"all_four_contacts",
			"coarse_pose_satisfied",
			"handoff_reason",
			"maximum_absolute_joint_position_error_rad",
			"mode",
			"native_application_count",
			"next_mode",
			"post_step_taper_count",
			"pre_step_taper_count",
			"step",
			"taper_reset_after_step",
			"tight_pose_satisfied",
			"torso_tilt_rad",
			"transition_after_step",
			"velocity_scale_denominator",
			"velocity_scale_numerator",
		]
		var observed_receipt_keys := taper_receipt.keys()
		observed_receipt_keys.sort()
		expected_receipt_keys.sort()
		if (
			observed_receipt_keys != expected_receipt_keys
			or int(taper_receipt.get("step", -1)) != trace_step - controller_steps
			or int(taper_receipt.get("native_application_count", -1))
			!= native_application_count
			or float(
				taper_receipt.get("maximum_absolute_joint_position_error_rad", NAN)
			) != maximum_absolute_joint_position_error_rad
		):
			return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_TAPER_RECEIPT_INVALID")
	elif not taper_receipt.is_empty():
		return _sdk_terminal_trace_failure("R23D10_GJT_TRACE_CONTROLLER_TAPER_PRESENT")
	var composition_mode := "balanced_wave_turning_v1"
	if terminal:
		match mode:
			SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE:
				composition_mode = "neutral_stance_full_authority_v1"
			SdkGodotJoltQuiescentTaperScript.TAPER_MODE:
				composition_mode = "neutral_stance_quiescent_taper_v1"
			SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE:
				composition_mode = "passive_zero_actuation_v1"
	return {
		"ok": true,
		"failure_code": "",
		"row": {
			"schema_version": String(options["trace_row_schema_version"]),
			"cell_id": String(options["cell_id"]),
			"trace_step": trace_step,
			"phase_id": phase_id,
			"controller_semantic_step": controller_semantic_step,
			"desired_heading_offset_rad": desired_heading_offset_rad,
			"measured_yaw_rad": measured_yaw_rad,
			"torso_height_m": torso_height_m,
			"torso_tilt_rad": torso_tilt_rad,
			"torso_ground_contact": torso_ground_contact,
			"ordered_foot_contacts": {
				"front_left": bool(contacts_by_limb["front_left"]),
				"front_right": bool(contacts_by_limb["front_right"]),
				"rear_left": bool(contacts_by_limb["rear_left"]),
				"rear_right": bool(contacts_by_limb["rear_right"]),
			},
			"actuator_command_count": expected_native_count,
			"native_actuation_application_count": native_application_count,
			"zero_actuation": terminal and not active,
			"command_composition_mode": composition_mode,
			"taper_receipt_present": terminal,
			"pre_step_taper_count": (
				taper_receipt.get("pre_step_taper_count") if terminal else null
			),
			"post_step_taper_count": (
				taper_receipt.get("post_step_taper_count") if terminal else null
			),
			"coarse_pose_satisfied": (
				taper_receipt.get("coarse_pose_satisfied") if terminal else null
			),
			"tight_pose_satisfied": (
				taper_receipt.get("tight_pose_satisfied") if terminal else null
			),
			"velocity_scale_numerator": (
				taper_receipt.get("velocity_scale_numerator") if terminal else null
			),
			"velocity_scale_denominator": (
				taper_receipt.get("velocity_scale_denominator") if terminal else null
			),
			"transition_after_step": (
				bool(taper_receipt.get("transition_after_step", false))
				if terminal
				else false
			),
			"taper_reset_after_step": (
				bool(taper_receipt.get("taper_reset_after_step", false))
				if terminal
				else false
			),
			"next_terminal_mode": taper_receipt.get("next_mode") if terminal else null,
			"handoff_reason": taper_receipt.get("handoff_reason") if terminal else null,
			"maximum_absolute_joint_position_error_rad": (
				maximum_absolute_joint_position_error_rad if terminal else null
			),
			"maximum_absolute_commanded_joint_velocity_rad_s": (
				maximum_absolute_commanded_joint_velocity_rad_s if active else null
			),
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_stability_assisted_taper_trace_row(
	options: Dictionary,
	trace_step: int,
	measured_yaw_rad: float,
	torso_height_m: float,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	contacts_by_limb: Dictionary,
	native_application_count: int,
	maximum_absolute_joint_position_error_rad: float,
	maximum_absolute_commanded_joint_velocity_rad_s: float,
	taper_receipt: Dictionary,
	diagnostics: Dictionary,
) -> Dictionary:
	var controller_steps := int(options["controller_step_count"])
	var total_steps := int(options["total_traced_step_count"])
	if not bool(diagnostics.get("ok", true)):
		return _sdk_terminal_trace_failure(
			String(
				diagnostics.get(
					"failure_code",
					"R23D19_GJT_PATH_DIAGNOSTIC_INVALID",
				)
			)
		)
	if (
		trace_step < 0
		or trace_step >= total_steps
		or not is_finite(measured_yaw_rad)
		or not is_finite(torso_height_m)
		or not is_finite(torso_tilt_rad)
	):
		return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_OBSERVATION_INVALID")
	var expected_contact_keys := [
		"front_left",
		"front_right",
		"rear_left",
		"rear_right",
	]
	var contact_keys := contacts_by_limb.keys()
	contact_keys.sort()
	if contact_keys != expected_contact_keys:
		return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_CONTACT_KEYS_INVALID")
	for field in [
		"base_linear_velocity_task_forward_m_s",
		"base_linear_velocity_task_lateral_m_s",
		"base_angular_velocity_task_yaw_rad_s",
	]:
		if not is_finite(float(diagnostics.get(field, NAN))):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_TASK_VELOCITY_INVALID")
	var terminal := trace_step >= controller_steps
	var r23d19_or_later_path_identity := (
		[
			QSDK_R23D19_TRACE_ROW_SCHEMA,
			QSDK_R23D20_TRACE_ROW_SCHEMA,
			QSDK_R23D21_TRACE_ROW_SCHEMA,
		].has(
			String(options.get("trace_row_schema_version", ""))
		)
	)
	var r23d19_path_fields := [
		"requested_heading_error_rad",
		"cross_track_error_m",
		"cross_track_velocity_m_s",
		"legacy_fixed_axis_cross_track_error_m",
		"legacy_fixed_axis_cross_track_velocity_m_s",
		"measured_yaw_error_rad",
		"desired_heading_error_rad",
		"yaw_tracking_error_rad",
		"requested_steering_fraction",
		"held_steering_fraction",
	]
	if r23d19_or_later_path_identity:
		for field_value in r23d19_path_fields:
			var field := String(field_value)
			var diagnostic_value: Variant = diagnostics.get(field, null)
			if terminal:
				if diagnostic_value != null:
					return _sdk_terminal_trace_failure(
						"R23D19_GJT_TERMINAL_PATH_DIAGNOSTIC_PRESENT"
					)
			elif (
				not [TYPE_FLOAT, TYPE_INT].has(typeof(diagnostic_value))
				or not is_finite(float(diagnostic_value))
			):
				return _sdk_terminal_trace_failure("R23D19_GJT_CONTROLLER_PATH_DIAGNOSTIC_INVALID")
	var r23d12_identity := (
		[
			QSDK_R23D12_TRACE_ROW_SCHEMA,
			QSDK_R23D13_TRACE_ROW_SCHEMA,
			QSDK_R23D14_TRACE_ROW_SCHEMA,
			QSDK_R23D15_TRACE_ROW_SCHEMA,
			QSDK_R23D16_TRACE_ROW_SCHEMA,
			QSDK_R23D17_TRACE_ROW_SCHEMA,
			QSDK_R23D18_TRACE_ROW_SCHEMA,
			QSDK_R23D19_TRACE_ROW_SCHEMA,
			QSDK_R23D20_TRACE_ROW_SCHEMA,
			QSDK_R23D21_TRACE_ROW_SCHEMA,
		]
		. has(String(options.get("trace_row_schema_version", "")))
	)
	var mode := ""
	if terminal:
		mode = String(taper_receipt.get("mode", ""))
		if not [
			SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE,
			SdkGodotJoltQuiescentTaperScript.TAPER_MODE,
			SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE,
		].has(mode):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_MODE_INVALID")
	var passive := terminal and mode == SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE
	var availability: Variant = diagnostics.get("stability_planning_availability")
	var support_margin: Variant = diagnostics.get("minimum_dynamic_support_margin_m")
	var support_margin_availability: Variant = null
	var deltas_value: Variant = diagnostics.get(
		"ordered_applied_stability_velocity_deltas_rad_s"
	)
	if typeof(deltas_value) != TYPE_ARRAY or (deltas_value as Array).size() != 8:
		return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_STABILITY_DELTAS_INVALID")
	var stability_deltas: Array = deltas_value
	for delta_value in stability_deltas:
		if (
			not [TYPE_FLOAT, TYPE_INT].has(typeof(delta_value))
			or not is_finite(float(delta_value))
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_STABILITY_DELTAS_INVALID")
	if passive:
		if (
			availability != null
			or not stability_deltas.all(
				func(value: Variant) -> bool: return float(value) == 0.0
			)
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_PASSIVE_DIAGNOSTICS_INVALID")
	else:
		if not [
			SdkGodotJoltStabilityAssistedTaperScript.AVAILABLE,
			SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE,
			SdkGodotJoltStabilityAssistedTaperScript.PLANNING_INFEASIBLE,
		].has(availability):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_AVAILABILITY_INVALID")
		if (
			availability != SdkGodotJoltStabilityAssistedTaperScript.AVAILABLE
			and not stability_deltas.all(
				func(value: Variant) -> bool: return float(value) == 0.0
			)
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_FALLBACK_INVALID")
	if r23d12_identity:
		var diagnostic_receipt := (
			SdkGodotJoltR23D12MeasurementSemanticsScript.validate_diagnostic_semantics(
				{
					"phase_class": (
						SdkGodotJoltR23D12MeasurementSemanticsScript.PASSIVE_OBSERVATION
						if passive
						else SdkGodotJoltR23D12MeasurementSemanticsScript.ACTIVE_CONTROL
					),
					"stability_planning_availability": availability,
					"minimum_dynamic_support_margin_availability": (
						SdkGodotJoltR23D12MeasurementSemanticsScript.MARGIN_MEASURED
						if support_margin != null
						else SdkGodotJoltR23D12MeasurementSemanticsScript.MARGIN_UNAVAILABLE
					),
					"minimum_dynamic_support_margin_m": support_margin,
					"ordered_applied_stability_velocity_deltas_rad_s": stability_deltas,
				}
			)
		)
		if not bool(diagnostic_receipt.get("ok", false)):
			return _sdk_terminal_trace_failure(
				"R23D12_GJT_TRACE_DIAGNOSTICS_INVALID:%s"
				% String(diagnostic_receipt.get("failure_code", "unknown"))
			)
		support_margin = diagnostic_receipt["minimum_dynamic_support_margin_m"]
		support_margin_availability = (
			diagnostic_receipt["minimum_dynamic_support_margin_availability"]
		)
		availability = diagnostic_receipt["stability_planning_availability"]
		stability_deltas = (
			diagnostic_receipt["ordered_applied_stability_velocity_deltas_rad_s"] as Array
		).duplicate()
	else:
		if (
			availability == SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE
			and support_margin != null
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_SUPPORT_MARGIN_INVALID")
		if (
			availability != null
			and availability != SdkGodotJoltStabilityAssistedTaperScript.OBSERVATION_UNAVAILABLE
			and (
				not [TYPE_FLOAT, TYPE_INT].has(typeof(support_margin))
				or not is_finite(float(support_margin))
			)
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_SUPPORT_MARGIN_INVALID")
		if (
			availability == null
			and support_margin != null
			and (
				not [TYPE_FLOAT, TYPE_INT].has(typeof(support_margin))
				or not is_finite(float(support_margin))
			)
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_SUPPORT_MARGIN_INVALID")
	var phase_id := "reference_warmup"
	var desired_heading_offset_rad := 0.0
	var controller_semantic_step: Variant = trace_step
	if trace_step < 600:
		phase_id = "reference_warmup"
	elif trace_step < 1800:
		phase_id = "commanded_turn"
		desired_heading_offset_rad = float(options["turn_heading_offset_rad"])
	elif trace_step < 2400:
		phase_id = "reference_recovery"
	elif trace_step < controller_steps:
		phase_id = "reference_continuation"
	else:
		controller_semantic_step = null
		match mode:
			SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE:
				phase_id = "terminal_neutral_acquisition"
			SdkGodotJoltQuiescentTaperScript.TAPER_MODE:
				phase_id = "terminal_quiescent_taper"
			SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE:
				phase_id = "terminal_irreversible_zero_actuation"
	var active := terminal and not passive
	var expected_native_count := 0 if passive else 8
	if native_application_count != expected_native_count:
		return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_APPLICATION_COUNT_INVALID")
	if terminal:
		var expected_receipt_keys := [
			"all_four_contacts",
			"coarse_pose_satisfied",
			"handoff_reason",
			"maximum_absolute_joint_position_error_rad",
			"mode",
			"native_application_count",
			"next_mode",
			"post_step_taper_count",
			"pre_step_taper_count",
			"step",
			"taper_reset_after_step",
			"tight_pose_satisfied",
			"torso_tilt_rad",
			"transition_after_step",
			"velocity_scale_denominator",
			"velocity_scale_numerator",
		]
		var observed_receipt_keys := taper_receipt.keys()
		observed_receipt_keys.sort()
		expected_receipt_keys.sort()
		if (
			observed_receipt_keys != expected_receipt_keys
			or int(taper_receipt.get("step", -1)) != trace_step - controller_steps
			or int(taper_receipt.get("native_application_count", -1))
			!= native_application_count
			or float(taper_receipt.get("maximum_absolute_joint_position_error_rad", NAN))
			!= maximum_absolute_joint_position_error_rad
		):
			return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_TAPER_RECEIPT_INVALID")
	elif not taper_receipt.is_empty():
		return _sdk_terminal_trace_failure("R23D11_GJT_TRACE_CONTROLLER_TAPER_PRESENT")
	var composition_mode := "balanced_wave_turning_v1"
	if terminal:
		match mode:
			SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE:
				composition_mode = "stability_assisted_neutral_full_authority_v1"
			SdkGodotJoltQuiescentTaperScript.TAPER_MODE:
				composition_mode = "stability_assisted_neutral_quiescent_taper_v1"
			SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE:
				composition_mode = "passive_zero_actuation_v1"
	var trace_row := {
			"schema_version": String(options["trace_row_schema_version"]),
			"cell_id": String(options["cell_id"]),
			"trace_step": trace_step,
			"phase_id": phase_id,
			"controller_semantic_step": controller_semantic_step,
			"desired_heading_offset_rad": desired_heading_offset_rad,
			"measured_yaw_rad": measured_yaw_rad,
			"torso_height_m": torso_height_m,
			"torso_tilt_rad": torso_tilt_rad,
			"torso_ground_contact": torso_ground_contact,
			"ordered_foot_contacts":
			{
				"front_left": bool(contacts_by_limb["front_left"]),
				"front_right": bool(contacts_by_limb["front_right"]),
				"rear_left": bool(contacts_by_limb["rear_left"]),
				"rear_right": bool(contacts_by_limb["rear_right"]),
			},
			"base_linear_velocity_task_forward_m_s": float(
				diagnostics["base_linear_velocity_task_forward_m_s"]
			),
			"base_linear_velocity_task_lateral_m_s": float(
				diagnostics["base_linear_velocity_task_lateral_m_s"]
			),
			"base_angular_velocity_task_yaw_rad_s": float(
				diagnostics["base_angular_velocity_task_yaw_rad_s"]
			),
			"minimum_dynamic_support_margin_m": support_margin,
			"stability_planning_availability": availability,
			"ordered_applied_stability_velocity_deltas_rad_s":
			stability_deltas.duplicate(),
			"actuator_command_count": expected_native_count,
			"native_actuation_application_count": native_application_count,
			"zero_actuation": passive,
			"command_composition_mode": composition_mode,
			"taper_receipt_present": terminal,
			"pre_step_taper_count": (
				taper_receipt.get("pre_step_taper_count") if terminal else null
			),
			"post_step_taper_count": (
				taper_receipt.get("post_step_taper_count") if terminal else null
			),
			"coarse_pose_satisfied": (
				taper_receipt.get("coarse_pose_satisfied") if terminal else null
			),
			"tight_pose_satisfied": (
				taper_receipt.get("tight_pose_satisfied") if terminal else null
			),
			"velocity_scale_numerator": (
				taper_receipt.get("velocity_scale_numerator") if terminal else null
			),
			"velocity_scale_denominator": (
				taper_receipt.get("velocity_scale_denominator") if terminal else null
			),
			"transition_after_step": (
				bool(taper_receipt.get("transition_after_step", false)) if terminal else false
			),
			"taper_reset_after_step": (
				bool(taper_receipt.get("taper_reset_after_step", false)) if terminal else false
			),
			"next_terminal_mode": taper_receipt.get("next_mode") if terminal else null,
			"handoff_reason": taper_receipt.get("handoff_reason") if terminal else null,
			"maximum_absolute_joint_position_error_rad": (
				maximum_absolute_joint_position_error_rad if terminal else null
			),
			"maximum_absolute_commanded_joint_velocity_rad_s": (
				maximum_absolute_commanded_joint_velocity_rad_s if active else null
			),
		}
	if r23d12_identity:
		trace_row["minimum_dynamic_support_margin_availability"] = (support_margin_availability)
	if r23d19_or_later_path_identity:
		for field_value in r23d19_path_fields:
			var field := String(field_value)
			trace_row[field] = diagnostics[field]
	return {
		"ok": true,
		"failure_code": "",
		"row": trace_row,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_r23d13_trace_row(
	options: Dictionary,
	trace_step: int,
	measured_yaw_rad: float,
	torso_height_m: float,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	contacts_by_limb: Dictionary,
	native_application_count: int,
	maximum_absolute_joint_position_error_rad: float,
	maximum_absolute_commanded_joint_velocity_rad_s: float,
	taper_receipt: Dictionary,
	diagnostics: Dictionary,
	command_time_feedback: Dictionary,
	authority_receipt: Dictionary,
) -> Dictionary:
	var base := _compose_sdk_stability_assisted_taper_trace_row(
		options,
		trace_step,
		measured_yaw_rad,
		torso_height_m,
		torso_tilt_rad,
		torso_ground_contact,
		contacts_by_limb,
		native_application_count,
		maximum_absolute_joint_position_error_rad,
		maximum_absolute_commanded_joint_velocity_rad_s,
		taper_receipt,
		diagnostics,
	)
	if not bool(base.get("ok", false)):
		return base
	var row: Dictionary = base["row"]
	row.erase("velocity_scale_numerator")
	row.erase("velocity_scale_denominator")
	var terminal := trace_step >= int(options["controller_step_count"])
	if not terminal:
		for field in [
			"command_time_feedback_trace_step",
			"command_time_ordered_foot_contacts",
			"command_time_torso_tilt_rad",
			"command_time_maximum_absolute_joint_position_error_rad",
			"temporal_scale_numerator",
			"temporal_scale_denominator",
			"tilt_floor_numerator",
			"joint_error_floor_numerator",
			"pose_authority_floor_numerator",
			"pose_authority_controlling_input",
			"applied_scale_numerator",
			"applied_scale_denominator",
			"ordered_combined_pre_taper_velocities_rad_s",
			"ordered_final_canonical_velocities_rad_s",
			"residual_pose_recovery_invoked",
			"authority_floor_never_reduces_temporal_authority",
			"complete_combined_velocity_scaled_once_before_host_mapping",
			"passive_mode_exact_zero_actuation",
		]:
			row[field] = null
		row["maximum_absolute_joint_position_error_rad"] = (
			maximum_absolute_joint_position_error_rad
		)
		return base
	var mode := String(taper_receipt.get("mode", ""))
	var active := mode != SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE
	var pre_taper_value: Variant = authority_receipt.get(
		"combined_pre_taper_velocities_rad_s"
	)
	var final_value: Variant = authority_receipt.get("final_canonical_velocities_rad_s")
	var authority_input_failure := _sdk_r23d13_trace_authority_input_failure(
		trace_step,
		command_time_feedback,
		authority_receipt,
	)
	if not authority_input_failure.is_empty():
		return _sdk_terminal_trace_failure("R23D13_GJT_TRACE_AUTHORITY_INPUT_INVALID")
	var pose_feedback: Variant = authority_receipt.get("pose_feedback")
	if active and typeof(pose_feedback) != TYPE_DICTIONARY:
		return _sdk_terminal_trace_failure("R23D13_GJT_TRACE_POSE_FEEDBACK_INVALID")
	if not active and pose_feedback != null:
		return _sdk_terminal_trace_failure("R23D13_GJT_TRACE_PASSIVE_POSE_FEEDBACK_PRESENT")
	var temporal_numerator := int(taper_receipt.get("velocity_scale_numerator", -1))
	var applied_numerator := int(authority_receipt.get("applied_scale_numerator", -1))
	row["command_time_feedback_trace_step"] = int(command_time_feedback["trace_step"])
	row["command_time_ordered_foot_contacts"] = (
		(command_time_feedback["ordered_foot_contacts"] as Dictionary).duplicate(true)
	)
	row["command_time_torso_tilt_rad"] = float(command_time_feedback["torso_tilt_rad"])
	row["command_time_maximum_absolute_joint_position_error_rad"] = float(
		command_time_feedback["maximum_absolute_joint_position_error_rad"]
	)
	row["temporal_scale_numerator"] = temporal_numerator
	row["temporal_scale_denominator"] = int(
		taper_receipt.get("velocity_scale_denominator", -1)
	)
	row["tilt_floor_numerator"] = int(pose_feedback.get("tilt_floor_numerator", 0)) if active else 0
	row["joint_error_floor_numerator"] = (
		int(pose_feedback.get("joint_error_floor_numerator", 0)) if active else 0
	)
	row["pose_authority_floor_numerator"] = int(
		authority_receipt.get("pose_authority_floor_numerator", -1)
	)
	row["pose_authority_controlling_input"] = (
		String(pose_feedback.get("controlling_input", "")) if active else null
	)
	row["applied_scale_numerator"] = applied_numerator
	row["applied_scale_denominator"] = SdkGodotJoltR23D13ResidualPoseAuthorityScript.SCALE_DENOMINATOR
	row["ordered_combined_pre_taper_velocities_rad_s"] = (pre_taper_value as Array).duplicate()
	row["ordered_final_canonical_velocities_rad_s"] = (final_value as Array).duplicate()
	row["residual_pose_recovery_invoked"] = bool(
		authority_receipt.get("residual_pose_recovery_invoked", false)
	)
	row["authority_floor_never_reduces_temporal_authority"] = (
		applied_numerator >= temporal_numerator
	)
	row["complete_combined_velocity_scaled_once_before_host_mapping"] = true
	row["passive_mode_exact_zero_actuation"] = not active
	row["command_composition_mode"] = (
		"residual_pose_authority_neutral_full_authority_v1"
		if mode == SdkGodotJoltQuiescentTaperScript.ACTIVE_MODE
		else "residual_pose_authority_neutral_quiescent_taper_v1"
		if mode == SdkGodotJoltQuiescentTaperScript.TAPER_MODE
		else "passive_zero_actuation_v1"
	)
	return base


static func _sdk_terminal_ordered_actuator_ids(compiled_morphology: Dictionary) -> Array:
	var morphology_value: Variant = compiled_morphology.get(
		"morphology", compiled_morphology
	)
	if typeof(morphology_value) != TYPE_DICTIONARY:
		return []
	var actuator_ids: Variant = (morphology_value as Dictionary).get(
		"ordered_actuator_ids", null
	)
	if typeof(actuator_ids) != TYPE_ARRAY:
		return []
	return (actuator_ids as Array).duplicate()


static func _sdk_r23d13_trace_authority_input_failure(
	trace_step: int,
	command_time_feedback: Dictionary,
	authority_receipt: Dictionary,
) -> String:
	var feedback_contacts: Variant = command_time_feedback.get("ordered_foot_contacts")
	var pre_taper_value: Variant = authority_receipt.get(
		"combined_pre_taper_velocities_rad_s"
	)
	var final_value: Variant = authority_receipt.get("final_canonical_velocities_rad_s")
	if int(command_time_feedback.get("trace_step", -1)) != trace_step - 1:
		return "R23D13_GJT_TRACE_AUTHORITY_FEEDBACK_STEP_INVALID"
	if typeof(feedback_contacts) != TYPE_DICTIONARY:
		return "R23D13_GJT_TRACE_AUTHORITY_CONTACTS_INVALID"
	if typeof(pre_taper_value) != TYPE_ARRAY:
		return "R23D13_GJT_TRACE_AUTHORITY_PRE_TAPER_TYPE_INVALID"
	if (pre_taper_value as Array).size() != 8:
		return "R23D13_GJT_TRACE_AUTHORITY_PRE_TAPER_COUNT_INVALID"
	if typeof(final_value) != TYPE_ARRAY:
		return "R23D13_GJT_TRACE_AUTHORITY_FINAL_TYPE_INVALID"
	if (final_value as Array).size() != 8:
		return "R23D13_GJT_TRACE_AUTHORITY_FINAL_COUNT_INVALID"
	if not bool(authority_receipt.get("ok", false)):
		return "R23D13_GJT_TRACE_AUTHORITY_RECEIPT_INVALID"
	return ""


static func run_sdk_terminal_authority_input_envelope_canary() -> Dictionary:
	var actuator_ids: Array = []
	for index in range(8):
		actuator_ids.append("actuator_%d" % index)
	var compiled_envelope := {
		"ok": true,
		"morphology": {"ordered_actuator_ids": actuator_ids.duplicate()},
	}
	var extracted_ids := _sdk_terminal_ordered_actuator_ids(compiled_envelope)
	var feedback := {
		"trace_step": 2991,
		"contacts": [true, true, true, true],
		"ordered_foot_contacts": {
			"front_left": true,
			"front_right": true,
			"rear_left": true,
			"rear_right": true,
		},
		"torso_tilt_rad": 0.005,
		"maximum_absolute_joint_position_error_rad": 0.1,
	}
	var pre_taper: Array = []
	pre_taper.resize(8)
	pre_taper.fill(0.2)
	var authority_input := feedback.duplicate(true)
	authority_input["mode"] = SdkGodotJoltQuiescentTaperScript.TAPER_MODE
	authority_input["temporal_scale_numerator"] = 60
	authority_input["temporal_scale_denominator"] = 120
	authority_input["actuator_ids"] = extracted_ids
	authority_input["combined_pre_taper_velocities_rad_s"] = pre_taper
	var receipt := (
		SdkGodotJoltR23D13ResidualPoseAuthorityScript
		. apply_residual_pose_authority(authority_input)
	)
	receipt["combined_pre_taper_velocities_rad_s"] = pre_taper.duplicate()
	var positive := (
		extracted_ids == actuator_ids
		and bool(receipt.get("ok", false))
		and _sdk_r23d13_trace_authority_input_failure(2992, feedback, receipt).is_empty()
	)
	var mutations := [
		{
			"feedback": feedback.merged({"trace_step": 2990}, true),
			"receipt": receipt,
		},
		{
			"feedback": feedback.merged({"ordered_foot_contacts": []}, true),
			"receipt": receipt,
		},
		{
			"feedback": feedback,
			"receipt": receipt.merged(
				{"combined_pre_taper_velocities_rad_s": {}}, true
			),
		},
		{
			"feedback": feedback,
			"receipt": receipt.merged(
				{"combined_pre_taper_velocities_rad_s": pre_taper.slice(0, 7)}, true
			),
		},
		{
			"feedback": feedback,
			"receipt": receipt.merged({"final_canonical_velocities_rad_s": {}}, true),
		},
		{
			"feedback": feedback,
			"receipt": receipt.merged(
				{
					"final_canonical_velocities_rad_s": (
						(receipt["final_canonical_velocities_rad_s"] as Array).slice(0, 7)
					)
				},
				true,
			),
		},
		{
			"feedback": feedback,
			"receipt": receipt.merged({"ok": false}, true),
		},
	]
	var mutation_refusal_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		if not _sdk_r23d13_trace_authority_input_failure(
			2992,
			mutation["feedback"],
			mutation["receipt"],
		).is_empty():
			mutation_refusal_count += 1
	var missing_envelope_ids := _sdk_terminal_ordered_actuator_ids({"ok": true})
	var exact := positive and mutation_refusal_count == 7 and missing_envelope_ids.is_empty()
	return {
		"ok": exact,
		"failure_code": (
			"" if exact else "SDK_TERMINAL_AUTHORITY_INPUT_ENVELOPE_CANARY_INVALID"
		),
		"positive_canary_count": 8,
		"mutation_control_count": 8,
		"nested_compiled_morphology_unwrapped": extracted_ids == actuator_ids,
		"missing_morphology_envelope_refused": missing_envelope_ids.is_empty(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d13_command_time_authority_context(
	sdk_adapter: RefCounted,
	compiled_morphology: Dictionary,
	taper_state: Dictionary,
	limbs: Array,
	floor: Node3D,
	joint_state_by_joint_id: Dictionary,
	trace_step: int,
	passive: bool,
	taper_script: Variant,
	torso: RigidBody3D,
) -> Dictionary:
	var compiled := compiled_morphology.duplicate(true)
	if compiled.is_empty() and sdk_adapter != null:
		compiled = sdk_adapter.compiled_morphology_for_conformance()
	var temporal_scale: Dictionary = taper_script.expected_velocity_scale(taper_state)
	var command_time_error := (
		SdkGodotJoltQuiescentTaperActuationScript
		. maximum_absolute_joint_position_error_rad(
			compiled,
			joint_state_by_joint_id,
		)
	)
	var command_time_contacts := _bearing_contact_by_limb(limbs, floor)
	var feedback := {
		"trace_step": trace_step - 1,
		"contacts": [
			bool(command_time_contacts.get("front_left", false)),
			bool(command_time_contacts.get("front_right", false)),
			bool(command_time_contacts.get("rear_left", false)),
			bool(command_time_contacts.get("rear_right", false)),
		],
		"ordered_foot_contacts": command_time_contacts.duplicate(true),
		"torso_tilt_rad": NAN,
		"maximum_absolute_joint_position_error_rad": float(
			command_time_error.get("maximum_absolute_joint_position_error_rad", NAN)
		),
	}
	if torso == null:
		return _sdk_terminal_trace_failure("R23D13_GJT_COMMAND_TIME_TORSO_MISSING")
	feedback["torso_tilt_rad"] = _tilt_rad(torso)
	if (
		not bool(temporal_scale.get("ok", false))
		or not bool(command_time_error.get("ok", false))
	):
		return _sdk_terminal_trace_failure("R23D13_GJT_COMMAND_TIME_FEEDBACK_INVALID")
	var authority_receipt: Dictionary = {}
	if passive:
		var passive_input := feedback.duplicate(true)
		passive_input["mode"] = SdkGodotJoltQuiescentTaperScript.PASSIVE_MODE
		passive_input["temporal_scale_numerator"] = int(temporal_scale["numerator"])
		passive_input["temporal_scale_denominator"] = int(temporal_scale["denominator"])
		passive_input["actuator_ids"] = _sdk_terminal_ordered_actuator_ids(compiled)
		var passive_pre_taper: Array = []
		passive_pre_taper.resize(8)
		passive_pre_taper.fill(null)
		passive_input["combined_pre_taper_velocities_rad_s"] = passive_pre_taper
		authority_receipt = (
			SdkGodotJoltR23D13ResidualPoseAuthorityScript.apply_residual_pose_authority(
				passive_input
			)
		)
		authority_receipt["pose_feedback"] = null
		authority_receipt["combined_pre_taper_velocities_rad_s"] = (
			passive_pre_taper.duplicate()
		)
	return {
		"ok": true,
		"failure_code": "",
		"compiled_morphology": compiled,
		"temporal_scale": temporal_scale,
		"command_time_feedback": feedback,
		"authority_receipt": authority_receipt,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_support_handoff_trace_row(
	options: Dictionary,
	trace_step: int,
	measured_yaw_rad: float,
	torso_height_m: float,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	contacts_by_limb: Dictionary,
	native_application_count: int,
	maximum_absolute_joint_position_error_rad: float,
	maximum_absolute_commanded_joint_velocity_rad_s: float,
	handoff_receipt: Dictionary,
) -> Dictionary:
	var controller_steps := int(options["controller_step_count"])
	var total_steps := int(options["total_traced_step_count"])
	if (
		trace_step < 0
		or trace_step >= total_steps
		or not is_finite(measured_yaw_rad)
		or not is_finite(torso_height_m)
		or not is_finite(torso_tilt_rad)
	):
		return _sdk_terminal_trace_failure("R23D9_GJT_TRACE_OBSERVATION_INVALID")
	var expected_contact_keys := [
		"front_left",
		"front_right",
		"rear_left",
		"rear_right",
	]
	var contact_keys := contacts_by_limb.keys()
	contact_keys.sort()
	if contact_keys != expected_contact_keys:
		return _sdk_terminal_trace_failure("R23D9_GJT_TRACE_CONTACT_KEYS_INVALID")
	var phase_id := "reference_warmup"
	var desired_heading_offset_rad := 0.0
	var controller_semantic_step: Variant = trace_step
	var terminal := trace_step >= controller_steps
	var active := false
	if trace_step < 600:
		phase_id = "reference_warmup"
	elif trace_step < 1800:
		phase_id = "commanded_turn"
		desired_heading_offset_rad = float(options["turn_heading_offset_rad"])
	elif trace_step < 2400:
		phase_id = "reference_recovery"
	elif trace_step < controller_steps:
		phase_id = "reference_continuation"
	else:
		controller_semantic_step = null
		active = String(handoff_receipt.get("mode", "")) == QSDK_R23D9_ACTIVE_MODE
		phase_id = (
			"terminal_neutral_acquisition"
			if active
			else "terminal_irreversible_zero_actuation"
		)
	var expected_native_count := 8 if not terminal or active else 0
	if native_application_count != expected_native_count:
		return _sdk_terminal_trace_failure("R23D9_GJT_TRACE_APPLICATION_COUNT_INVALID")
	if terminal:
		var expected_receipt_keys := [
			"handoff_reason",
			"mode",
			"native_application_count",
			"next_mode",
			"post_step_support_counter",
			"pre_step_support_counter",
			"transition_after_step",
		]
		var observed_receipt_keys := handoff_receipt.keys()
		observed_receipt_keys.sort()
		expected_receipt_keys.sort()
		if (
			observed_receipt_keys != expected_receipt_keys
			or int(handoff_receipt.get("native_application_count", -1))
			!= native_application_count
		):
			return _sdk_terminal_trace_failure("R23D9_GJT_TRACE_HANDOFF_RECEIPT_INVALID")
	elif not handoff_receipt.is_empty():
		return _sdk_terminal_trace_failure("R23D9_GJT_TRACE_CONTROLLER_HANDOFF_PRESENT")
	return {
		"ok": true,
		"failure_code": "",
		"row":
		{
			"schema_version": String(options["trace_row_schema_version"]),
			"cell_id": String(options["cell_id"]),
			"trace_step": trace_step,
			"phase_id": phase_id,
			"controller_semantic_step": controller_semantic_step,
			"desired_heading_offset_rad": desired_heading_offset_rad,
			"measured_yaw_rad": measured_yaw_rad,
			"torso_height_m": torso_height_m,
			"torso_tilt_rad": torso_tilt_rad,
			"torso_ground_contact": torso_ground_contact,
			"ordered_foot_contacts":
			{
				"front_left": bool(contacts_by_limb["front_left"]),
				"front_right": bool(contacts_by_limb["front_right"]),
				"rear_left": bool(contacts_by_limb["rear_left"]),
				"rear_right": bool(contacts_by_limb["rear_right"]),
			},
			"actuator_command_count": expected_native_count,
			"native_actuation_application_count": native_application_count,
			"zero_actuation": terminal and not active,
			"command_composition_mode": (
				SdkGodotJoltNeutralStanceScript.POLICY_ID
				if terminal and active
				else "passive_zero_actuation_v1"
				if terminal
				else "balanced_wave_turning_v1"
			),
			"handoff_receipt_present": terminal,
			"pre_step_support_counter": (
				handoff_receipt.get("pre_step_support_counter") if terminal else null
			),
			"post_step_support_counter": (
				handoff_receipt.get("post_step_support_counter") if terminal else null
			),
			"transition_after_step": (
				bool(handoff_receipt.get("transition_after_step", false)) if terminal else false
			),
			"next_terminal_mode": handoff_receipt.get("next_mode") if terminal else null,
			"handoff_reason": handoff_receipt.get("handoff_reason") if terminal else null,
			"maximum_absolute_joint_position_error_rad": (
				maximum_absolute_joint_position_error_rad if terminal and active else null
			),
			"maximum_absolute_commanded_joint_velocity_rad_s": (
				maximum_absolute_commanded_joint_velocity_rad_s if terminal and active else null
			),
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _sdk_terminal_trace_failure(failure_code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_physical_trace_row(
	trace_options: Dictionary,
	sample_result: Dictionary,
	step_result: Dictionary,
	authority_application_result: Dictionary,
	semantic_step: int,
	ordered_foot_contacts_before: Dictionary,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	path_steering_profile: Dictionary,
) -> Dictionary:
	if _is_qsdk_recovery_trace_policy(String(trace_options.get("policy_id", ""))):
		return _compose_sdk_recovery_trace_pending_row(
			trace_options,
			sample_result,
			step_result,
			authority_application_result,
			semantic_step,
			ordered_foot_contacts_before,
		)
	if (
		not bool(sample_result.get("ok", false))
		or not bool(step_result.get("ok", false))
		or not bool(authority_application_result.get("ok", false))
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_UPSTREAM_INVALID")
	if (
		semantic_step < 0
		or semantic_step >= int(trace_options.get("exact_controller_step_count", -1))
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_STEP_OUT_OF_RANGE")
	var trace_row_schema_value: Variant = trace_options.get(
		"trace_row_schema_version",
		QSDK_R23D3_PHYSICAL_TRACE_ROW_SCHEMA,
	)
	if (
		typeof(trace_row_schema_value) != TYPE_STRING
		or String(trace_row_schema_value).is_empty()
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ROW_SCHEMA_INVALID")
	var segment_result := _r23d3_trace_segment(trace_options, semantic_step)
	if not bool(segment_result.get("ok", false)):
		return segment_result

	var request_value: Variant = sample_result.get("request", null)
	if typeof(request_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_REQUEST_INVALID")
	var request: Dictionary = request_value
	var memory_value: Variant = request.get("memory", null)
	var state_value: Variant = request.get("state", null)
	var command_value: Variant = request.get("command", null)
	if (
		typeof(memory_value) != TYPE_DICTIONARY
		or typeof(state_value) != TYPE_DICTIONARY
		or typeof(command_value) != TYPE_DICTIONARY
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_REQUEST_FIELDS_INVALID")
	var memory: Dictionary = memory_value
	var state: Dictionary = state_value
	var command: Dictionary = command_value
	if (
		int(state.get("semantic_step", -1)) != semantic_step
		or int(command.get("valid_from_step", -1)) != semantic_step
		or int(command.get("valid_through_step", -1)) != semantic_step
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_REQUEST_STEP_MISMATCH")

	var expected_offset := float(segment_result["heading_offset_rad"])
	var task_frame_value: Variant = state.get("task_frame", null)
	if typeof(task_frame_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_TASK_FRAME_INVALID")
	var task_frame: Dictionary = task_frame_value
	var reference_yaw_rad := float(task_frame.get("reference_yaw_rad", NAN))
	var desired_heading_rad := float(command.get("desired_heading_rad", NAN))
	if (
		not is_finite(reference_yaw_rad)
		or not is_finite(desired_heading_rad)
		or absf(
			_wrap_angle(desired_heading_rad - reference_yaw_rad) - expected_offset
		) > QSDK_R23D3_ORACLE_TOLERANCE
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_HEADING_COMMAND_INVALID")
	var heading_receipt_value: Variant = sample_result.get("heading_command_receipt", null)
	if typeof(heading_receipt_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_HEADING_RECEIPT_MISSING")
	var heading_receipt: Dictionary = heading_receipt_value
	if (
		int(heading_receipt.get("semantic_step", -1)) != semantic_step
		or absf(float(heading_receipt.get("heading_offset_rad", NAN)) - expected_offset)
		> QSDK_R23D3_ORACLE_TOLERANCE
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_HEADING_RECEIPT_INVALID")

	var native_output_value: Variant = step_result.get("native_output", null)
	if typeof(native_output_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_NATIVE_OUTPUT_INVALID")
	var native_output: Dictionary = native_output_value
	var actuation_value: Variant = native_output.get("actuation", null)
	if typeof(actuation_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ACTUATION_INVALID")
	var actuation: Dictionary = actuation_value
	var receipt_value: Variant = actuation.get("receipt", null)
	var commands_value: Variant = actuation.get("ordered_commands", null)
	if typeof(receipt_value) != TYPE_DICTIONARY or typeof(commands_value) != TYPE_ARRAY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ACTUATION_FIELDS_INVALID")
	var receipt: Dictionary = receipt_value
	var commands: Array = commands_value
	var applied_command_count := int(
		authority_application_result.get("applied_command_count", -1)
	)
	if (
		commands.size() != 8
		or applied_command_count != 8
		or int(step_result.get("semantic_step", -1)) != semantic_step
		or int(authority_application_result.get("semantic_step", -1)) != semantic_step
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_APPLICATION_COUNT_INVALID")

	var oracle_result := _r23d3_independent_oracle(state, command, path_steering_profile)
	if not bool(oracle_result.get("ok", false)):
		return oracle_result
	var expected_receipt: Dictionary = oracle_result["expected_receipt"]
	for field_value in [
		"cross_track_error_m",
		"cross_track_velocity_m_s",
		"measured_yaw_error_rad",
		"desired_heading_error_rad",
		"yaw_tracking_error_rad",
	]:
		var field := String(field_value)
		var observed_value := float(receipt.get(field, NAN))
		if (
			not is_finite(observed_value)
			or absf(observed_value - float(expected_receipt[field]))
			> QSDK_R23D3_ORACLE_TOLERANCE
		):
			return _sdk_physical_trace_failure(
				"SDK_PHYSICAL_TRACE_ORACLE_MISMATCH:%s" % field
			)

	var limb_phase_result := _r23d3_limb_phase_projection(memory)
	if not bool(limb_phase_result.get("ok", false)):
		return limb_phase_result
	if not _has_exact_keys(ordered_foot_contacts_before, LIMB_ORDER):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_CONTACT_KEYS_INVALID")
	for limb_id_value in LIMB_ORDER:
		if typeof(ordered_foot_contacts_before[limb_id_value]) != TYPE_BOOL:
			return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_CONTACT_TYPE_INVALID")

	var base_pose_value: Variant = state.get("base_pose_world", null)
	if typeof(base_pose_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_BASE_POSE_INVALID")
	var base_pose: Dictionary = base_pose_value
	var position_result := _r23d3_vector_projection(base_pose.get("position_m", null))
	if not bool(position_result.get("ok", false)):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_POSITION_INVALID")
	if not is_finite(torso_tilt_rad):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_TILT_INVALID")
	var position: Array = position_result["values"]
	var requested_steering_fraction := float(
		receipt.get("requested_steering_fraction", NAN)
	)
	var held_steering_fraction := float(receipt.get("held_steering_fraction", NAN))
	if (
		not is_finite(requested_steering_fraction)
		or not is_finite(held_steering_fraction)
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_STEERING_INVALID")
	var row := {
			"schema_version": String(trace_row_schema_value),
			"cell_id": String(trace_options["cell_id"]),
			"semantic_step": semantic_step,
			"segment_id": String(segment_result["segment_id"]),
			"desired_heading_offset_rad": expected_offset,
			"measured_yaw_rad": float(oracle_result["measured_heading_world_rad"]),
			"requested_heading_error_rad": float(oracle_result["requested_heading_error_rad"]),
			"cross_track_error_m": float(receipt["cross_track_error_m"]),
			"cross_track_velocity_m_s": float(receipt["cross_track_velocity_m_s"]),
			"legacy_fixed_axis_cross_track_error_m":
			float(oracle_result["legacy_fixed_axis_cross_track_error_m"]),
			"legacy_fixed_axis_cross_track_velocity_m_s":
			float(oracle_result["legacy_fixed_axis_cross_track_velocity_m_s"]),
			"measured_yaw_error_rad": float(receipt["measured_yaw_error_rad"]),
			"desired_heading_error_rad": float(receipt["desired_heading_error_rad"]),
			"yaw_tracking_error_rad": float(receipt["yaw_tracking_error_rad"]),
			"requested_steering_fraction": requested_steering_fraction,
			"held_steering_fraction": held_steering_fraction,
			"steering_saturated": (
				absf(requested_steering_fraction)
				>= QSDK_R23D3_MAXIMUM_STEERING_FRACTION - QSDK_R23D3_ORACLE_TOLERANCE
				or absf(held_steering_fraction)
				>= QSDK_R23D3_MAXIMUM_STEERING_FRACTION - QSDK_R23D3_ORACLE_TOLERANCE
			),
			"torso_position_world_m": position.duplicate(),
			"torso_height_m": float(position[1]),
			"torso_tilt_rad": torso_tilt_rad,
			"torso_ground_contact": torso_ground_contact,
			"ordered_limb_phase_before": (
				(limb_phase_result["ordered_limb_phase_before"] as Array).duplicate(true)
			),
			"ordered_foot_contacts_before": ordered_foot_contacts_before.duplicate(true),
			"ordered_foot_contacts_after": {},
			"validated_portable_command_count": commands.size(),
			"native_actuation_application_count": applied_command_count,
			"oracle_passed": true,
	}
	var origin_receipt_value: Variant = sample_result.get(
		"task_frame_origin_receipt",
		null,
	)
	if origin_receipt_value != null:
		var origin_projection := _task_frame_origin_trace_projection(
			origin_receipt_value,
			task_frame,
			heading_receipt,
		)
		if not bool(origin_projection.get("ok", false)):
			return origin_projection
		row["task_frame_origin_policy_id"] = String(
			origin_projection["task_frame_origin_policy_id"]
		)
		row["task_frame_origin_world_m"] = (
			(origin_projection["task_frame_origin_world_m"] as Array).duplicate()
		)
		row["task_frame_origin_reanchored_this_step"] = bool(
			origin_projection["task_frame_origin_reanchored_this_step"]
		)
		row["task_frame_origin_reanchor_count"] = int(
			origin_projection["task_frame_origin_reanchor_count"]
		)
	if trace_options.has("actuator_phase_observation_schema_version"):
		var actuator_phase_observation := _compose_sdk_actuator_phase_observation(
			trace_options,
			step_result,
			authority_application_result,
			limb_phase_result,
			ordered_foot_contacts_before,
			semantic_step,
		)
		if not bool(actuator_phase_observation.get("ok", false)):
			return actuator_phase_observation
		row["actuator_phase_observation"] = (
			(actuator_phase_observation["observation"] as Dictionary).duplicate(true)
		)
	return {
		"ok": true,
		"failure_code": "",
		"row": row,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_recovery_trace_pending_row(
	trace_options: Dictionary,
	sample_result: Dictionary,
	step_result: Dictionary,
	authority_application_result: Dictionary,
	semantic_step: int,
	ordered_foot_contacts_before: Dictionary,
) -> Dictionary:
	var trace_policy_id := String(trace_options.get("policy_id", ""))
	var trace_row_schema := _recovery_trace_row_schema(trace_policy_id)
	var failure_prefix := _recovery_trace_failure_prefix(trace_policy_id)
	if (
		not bool(sample_result.get("ok", false))
		or not bool(step_result.get("ok", false))
		or not bool(authority_application_result.get("ok", false))
	):
		return _sdk_physical_trace_failure(failure_prefix + "_UPSTREAM_INVALID")
	if (
		trace_row_schema.is_empty()
		or String(trace_options.get("trace_row_schema_version", "")) != trace_row_schema
		or semantic_step < 0
		or semantic_step >= int(trace_options.get("maximum_controller_step_count", -1))
	):
		return _sdk_physical_trace_failure(failure_prefix + "_STEP_INVALID")
	var request_value: Variant = sample_result.get("request", null)
	if typeof(request_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(failure_prefix + "_REQUEST_INVALID")
	var request: Dictionary = request_value
	var state_value: Variant = request.get("state", null)
	var command_value: Variant = request.get("command", null)
	if typeof(state_value) != TYPE_DICTIONARY or typeof(command_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(failure_prefix + "_REQUEST_FIELDS_INVALID")
	var state: Dictionary = state_value
	var command: Dictionary = command_value
	if (
		int(state.get("semantic_step", -1)) != semantic_step
		or int(command.get("valid_from_step", -1)) != semantic_step
		or int(command.get("valid_through_step", -1)) != semantic_step
		or int(step_result.get("semantic_step", -1)) != semantic_step
		or int(authority_application_result.get("semantic_step", -1)) != semantic_step
	):
		return _sdk_physical_trace_failure(failure_prefix + "_STEP_MISMATCH")
	var native_output_value: Variant = step_result.get("native_output", null)
	if typeof(native_output_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(failure_prefix + "_NATIVE_OUTPUT_INVALID")
	var actuation_value: Variant = (native_output_value as Dictionary).get("actuation", null)
	if typeof(actuation_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(failure_prefix + "_ACTUATION_INVALID")
	var commands_value: Variant = (actuation_value as Dictionary).get("ordered_commands", null)
	var applied_command_count := int(authority_application_result.get("applied_command_count", -1))
	if (
		typeof(commands_value) != TYPE_ARRAY
		or (commands_value as Array).size() != 8
		or applied_command_count != 8
	):
		return _sdk_physical_trace_failure(failure_prefix + "_APPLICATION_COUNT_INVALID")
	if not _has_exact_keys(ordered_foot_contacts_before, LIMB_ORDER):
		return _sdk_physical_trace_failure(failure_prefix + "_CONTACT_KEYS_INVALID")
	for limb_id_value in LIMB_ORDER:
		if typeof(ordered_foot_contacts_before[limb_id_value]) != TYPE_BOOL:
			return _sdk_physical_trace_failure(failure_prefix + "_CONTACT_TYPE_INVALID")
	var task_frame_value: Variant = state.get("task_frame", null)
	if typeof(task_frame_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(failure_prefix + "_TASK_FRAME_INVALID")
	var task_frame: Dictionary = task_frame_value
	var forward_result := _r23d3_vector_projection(task_frame.get("forward_axis_world_unit", null))
	var lateral_result := _r23d3_vector_projection(task_frame.get("lateral_axis_world_unit", null))
	if not bool(forward_result.get("ok", false)) or not bool(lateral_result.get("ok", false)):
		return _sdk_physical_trace_failure(failure_prefix + "_TASK_AXES_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"row": {
			"schema_version": trace_row_schema,
			"cell_id": String(trace_options["cell_id"]),
			"semantic_step": semantic_step,
			"sampling_phase": "post_physics_for_applied_semantic_step",
			"push_marker_semantic_step": int(trace_options["push_marker_semantic_step"]),
			"task_frame_forward_axis_world_unit": (
				(forward_result["values"] as Array).duplicate()
			),
			"task_frame_lateral_axis_world_unit": (
				(lateral_result["values"] as Array).duplicate()
			),
			"ordered_foot_contacts_before": ordered_foot_contacts_before.duplicate(true),
			"ordered_foot_contacts_after": {},
			"validated_portable_command_count": (commands_value as Array).size(),
			"native_actuation_application_count": applied_command_count,
			"torso_position_world_m": [],
			"torso_orientation_xyzw": [],
			"torso_orientation_projection": {},
			"torso_linear_velocity_world_m_s": [],
			"torso_angular_velocity_world_rad_s": [],
			"torso_tilt_rad": NAN,
			"torso_ground_contact": false,
			"post_physics_observation_complete": false,
			"observer_physics_state_modified": false,
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func complete_sdk_recovery_trace_observation(
	pending_row: Dictionary,
	torso_position_world_m: Vector3,
	torso_orientation: Quaternion,
	torso_linear_velocity_world_m_s: Vector3,
	torso_angular_velocity_world_rad_s: Vector3,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	ordered_foot_contacts_after: Dictionary,
) -> Dictionary:
	var trace_row_schema := String(pending_row.get("schema_version", ""))
	var failure_prefix := _recovery_trace_failure_prefix_for_row_schema(trace_row_schema)
	if (
		failure_prefix.is_empty()
		or bool(pending_row.get("post_physics_observation_complete", true))
		or not torso_position_world_m.is_finite()
		or not torso_linear_velocity_world_m_s.is_finite()
		or not torso_angular_velocity_world_rad_s.is_finite()
		or not is_finite(torso_tilt_rad)
		or not is_finite(torso_orientation.x)
		or not is_finite(torso_orientation.y)
		or not is_finite(torso_orientation.z)
		or not is_finite(torso_orientation.w)
	):
		return _sdk_physical_trace_failure(
			(
				("QSDK_RECOVERY_TRACE" if failure_prefix.is_empty() else failure_prefix)
				+ "_POST_STATE_INVALID"
			)
		)
	if not _has_exact_keys(ordered_foot_contacts_after, LIMB_ORDER):
		return _sdk_physical_trace_failure(failure_prefix + "_POST_CONTACT_KEYS_INVALID")
	for limb_id_value in LIMB_ORDER:
		if typeof(ordered_foot_contacts_after[limb_id_value]) != TYPE_BOOL:
			return _sdk_physical_trace_failure(failure_prefix + "_POST_CONTACT_TYPE_INVALID")
	var orientation_projection := (
		QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1(torso_orientation)
	)
	if not bool(orientation_projection.get("ok", false)):
		return _sdk_physical_trace_failure(
			failure_prefix + "_QUATERNION_PROJECTION_REFUSED",
			{"quaternion_projection": orientation_projection},
		)
	var orientation: Array = orientation_projection["orientation_xyzw"]
	var row := pending_row.duplicate(true)
	row["torso_position_world_m"] = [
		torso_position_world_m.x,
		torso_position_world_m.y,
		torso_position_world_m.z,
	]
	row["torso_orientation_xyzw"] = orientation.duplicate()
	row["torso_orientation_projection"] = orientation_projection.duplicate(true)
	row["torso_linear_velocity_world_m_s"] = [
		torso_linear_velocity_world_m_s.x,
		torso_linear_velocity_world_m_s.y,
		torso_linear_velocity_world_m_s.z,
	]
	row["torso_angular_velocity_world_rad_s"] = [
		torso_angular_velocity_world_rad_s.x,
		torso_angular_velocity_world_rad_s.y,
		torso_angular_velocity_world_rad_s.z,
	]
	row["torso_tilt_rad"] = torso_tilt_rad
	row["torso_ground_contact"] = torso_ground_contact
	row["ordered_foot_contacts_after"] = ordered_foot_contacts_after.duplicate(true)
	row["post_physics_observation_complete"] = true
	return {
		"ok": true,
		"failure_code": "",
		"row": row,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _compose_sdk_actuator_phase_observation(
	trace_options: Dictionary,
	step_result: Dictionary,
	authority_application_result: Dictionary,
	limb_phase_result: Dictionary,
	ordered_foot_contacts_before: Dictionary,
	semantic_step: int,
) -> Dictionary:
	if (
		String(trace_options.get("actuator_phase_observation_schema_version", ""))
		!= SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA
		or String(authority_application_result.get("schema_version", ""))
		!= SDK_GODOT_FULL_AUTHORITY_APPLICATION_RECEIPT_SCHEMA
		or int(authority_application_result.get("semantic_step", -1)) != semantic_step
		or not bool(
			authority_application_result.get("configured_motor_parameters_only", false)
		)
		or bool(authority_application_result.get("measured_motor_torque_available", true))
		or bool(authority_application_result.get("measured_motor_impulse_available", true))
	):
		return _sdk_physical_trace_failure(
			"SDK_ACTUATOR_PHASE_APPLICATION_RECEIPT_INVALID"
		)
	var native_output_value: Variant = step_result.get("native_output", null)
	if typeof(native_output_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_NATIVE_OUTPUT_INVALID")
	var actuation_value: Variant = (native_output_value as Dictionary).get("actuation", null)
	if typeof(actuation_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_ACTUATION_INVALID")
	var commands_value: Variant = (actuation_value as Dictionary).get("ordered_commands", null)
	var applications_value: Variant = authority_application_result.get(
		"ordered_applications",
		null,
	)
	var ordered_actuator_ids_value: Variant = authority_application_result.get(
		"ordered_actuator_ids",
		null,
	)
	var limb_phase_value: Variant = limb_phase_result.get(
		"ordered_limb_phase_before",
		null,
	)
	if (
		typeof(commands_value) != TYPE_ARRAY
		or typeof(applications_value) != TYPE_ARRAY
		or typeof(ordered_actuator_ids_value) != TYPE_ARRAY
		or typeof(limb_phase_value) != TYPE_ARRAY
	):
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_ARRAYS_INVALID")
	var commands: Array = commands_value
	var applications: Array = applications_value
	var ordered_actuator_ids: Array = ordered_actuator_ids_value
	var limb_phase_rows: Array = limb_phase_value
	var tolerance := float(authority_application_result.get("readback_tolerance", NAN))
	if (
		not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or commands.size() != applications.size()
		or commands.size() != ordered_actuator_ids.size()
		or commands.size() != int(authority_application_result.get("applied_command_count", -1))
	):
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_CARDINALITY_INVALID")
	var phase_by_limb_id: Dictionary = {}
	var ordered_limb_ids: Array[String] = []
	for phase_value in limb_phase_rows:
		if typeof(phase_value) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_LIMB_PHASE_INVALID")
		var phase: Dictionary = phase_value
		var limb_id := String(phase.get("limb_id", ""))
		if (
			limb_id.is_empty()
			or phase_by_limb_id.has(limb_id)
			or not ordered_foot_contacts_before.has(limb_id)
			or typeof(ordered_foot_contacts_before[limb_id]) != TYPE_BOOL
		):
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_LIMB_LINK_INVALID")
		phase_by_limb_id[limb_id] = phase
		ordered_limb_ids.append(limb_id)
	var ordered_observations: Array[Dictionary] = []
	for index in range(commands.size()):
		if typeof(commands[index]) != TYPE_DICTIONARY or typeof(applications[index]) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_ROW_TYPE_INVALID")
		var command: Dictionary = commands[index]
		var application: Dictionary = applications[index]
		var actuator_id := String(command.get("actuator_id", ""))
		var limb_id := String(application.get("limb_id", ""))
		var controller_target := float(command.get("target_velocity_rad_s", NAN))
		var application_controller_target := float(
			application.get("controller_target_velocity_rad_s", NAN)
		)
		var applied_target := float(
			application.get("host_applied_target_velocity_rad_s", NAN)
		)
		var target_readback := float(
			application.get("motor_target_velocity_readback_rad_s", NAN)
		)
		var target_error := float(
			application.get("motor_target_velocity_readback_error_rad_s", NAN)
		)
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		var application_maximum_speed := float(
			application.get("maximum_target_speed_rad_s", NAN)
		)
		var declared_impulse := float(application.get("declared_maximum_impulse_nms", NAN))
		var impulse_readback := float(
			application.get("motor_maximum_impulse_readback_nms", NAN)
		)
		var impulse_error := float(
			application.get("motor_maximum_impulse_readback_error_nms", NAN)
		)
		if (
			actuator_id.is_empty()
			or actuator_id != String(ordered_actuator_ids[index])
			or actuator_id != String(application.get("actuator_id", ""))
			or String(application.get("joint_id", "")).is_empty()
			or not phase_by_limb_id.has(limb_id)
			or int(application.get("limb_joint_index", -1)) < 0
			or not is_finite(controller_target)
			or not is_finite(application_controller_target)
			or not is_finite(applied_target)
			or not is_finite(target_readback)
			or not is_finite(target_error)
			or not is_finite(maximum_speed)
			or not is_finite(application_maximum_speed)
			or not is_finite(declared_impulse)
			or not is_finite(impulse_readback)
			or not is_finite(impulse_error)
			or maximum_speed <= 0.0
			or declared_impulse <= 0.0
			or absf(controller_target) > maximum_speed + tolerance
			or absf(application_controller_target - controller_target) > tolerance
			or absf(applied_target - controller_target) > tolerance
			or absf(target_readback - applied_target) > tolerance
			or absf(target_error - absf(target_readback - applied_target)) > 1.0e-15
			or absf(application_maximum_speed - maximum_speed) > tolerance
			or absf(impulse_error - absf(impulse_readback - declared_impulse)) > 1.0e-15
			or target_error > tolerance
			or impulse_error > tolerance
			or bool(application.get("host_additional_clamp_applied", true))
			or not bool(application.get("target_velocity_readback_matches", false))
			or not bool(application.get("maximum_impulse_readback_matches", false))
			or bool(application.get("position_saturated", false))
			!= bool(command.get("position_saturated", false))
			or bool(application.get("velocity_saturated", false))
			!= bool(command.get("velocity_saturated", false))
			or bool(application.get("slew_limited", false))
			!= bool(command.get("slew_limited", false))
		):
			return _sdk_physical_trace_failure(
				"SDK_ACTUATOR_PHASE_APPLICATION_MISMATCH:%s" % actuator_id
			)
		var phase: Dictionary = phase_by_limb_id[limb_id]
		var projected := application.duplicate(true)
		projected["local_phase_step_before"] = int(phase.get("local_phase_step", -1))
		projected["gait_step_before"] = int(phase.get("gait_step", -1))
		projected["release_hold_step_count_before"] = int(
			phase.get("release_hold_step_count", -1)
		)
		projected["foot_contact_before"] = bool(ordered_foot_contacts_before[limb_id])
		projected["foot_contact_after"] = null
		ordered_observations.append(projected)
	return {
		"ok": true,
		"failure_code": "",
		"observation": {
			"schema_version": SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA,
			"semantic_step": semantic_step,
			"controller_step_receipt_sha256": String(
				step_result.get("controller_step_receipt_sha256", "")
			),
			"application_receipt_schema_version":
			SDK_GODOT_FULL_AUTHORITY_APPLICATION_RECEIPT_SCHEMA,
			"ordered_actuator_ids": ordered_actuator_ids.duplicate(),
			"ordered_limb_ids": ordered_limb_ids,
			"readback_tolerance": tolerance,
			"ordered_applications": ordered_observations,
			"after_contact_observation_complete": false,
			"configured_motor_parameters_only": true,
			"measured_motor_torque_available": false,
			"measured_motor_impulse_available": false,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func complete_sdk_actuator_phase_observation(
	row: Dictionary,
	ordered_foot_contacts_after: Dictionary,
) -> Dictionary:
	var completed := row.duplicate(true)
	var observation_value: Variant = completed.get("actuator_phase_observation", null)
	if typeof(observation_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_MISSING")
	var observation: Dictionary = observation_value
	var applications_value: Variant = observation.get("ordered_applications", null)
	if typeof(applications_value) != TYPE_ARRAY:
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_ROWS_INVALID")
	var applications: Array = applications_value
	for index in range(applications.size()):
		if typeof(applications[index]) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_ROW_INVALID")
		var application: Dictionary = applications[index]
		var limb_id := String(application.get("limb_id", ""))
		if (
			limb_id.is_empty()
			or not ordered_foot_contacts_after.has(limb_id)
			or typeof(ordered_foot_contacts_after[limb_id]) != TYPE_BOOL
		):
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_AFTER_CONTACT_INVALID")
		application["foot_contact_after"] = bool(ordered_foot_contacts_after[limb_id])
		applications[index] = application
	observation["ordered_applications"] = applications
	observation["after_contact_observation_complete"] = true
	completed["actuator_phase_observation"] = observation
	completed["ordered_foot_contacts_after"] = ordered_foot_contacts_after.duplicate(true)
	var validation := validate_sdk_actuator_phase_observation(completed)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok": true,
		"failure_code": "",
		"row": completed,
		"validated_application_count": applications.size(),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func validate_sdk_actuator_phase_observation(row: Dictionary) -> Dictionary:
	var observation_value: Variant = row.get("actuator_phase_observation", null)
	var before_value: Variant = row.get("ordered_foot_contacts_before", null)
	var after_value: Variant = row.get("ordered_foot_contacts_after", null)
	var limb_phase_value: Variant = row.get("ordered_limb_phase_before", null)
	if (
		typeof(observation_value) != TYPE_DICTIONARY
		or typeof(before_value) != TYPE_DICTIONARY
		or typeof(after_value) != TYPE_DICTIONARY
		or typeof(limb_phase_value) != TYPE_ARRAY
	):
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_VALIDATION_INPUT_INVALID")
	var observation: Dictionary = observation_value
	var before: Dictionary = before_value
	var after: Dictionary = after_value
	var limb_phase_rows: Array = limb_phase_value
	var applications_value: Variant = observation.get("ordered_applications", null)
	var ordered_actuator_ids_value: Variant = observation.get("ordered_actuator_ids", null)
	var ordered_limb_ids_value: Variant = observation.get("ordered_limb_ids", null)
	if (
		not _has_exact_keys(
			observation,
			SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_KEYS,
		)
		or not String(observation.get("controller_step_receipt_sha256", "")).begins_with(
			"sha256:"
		)
		or String(observation.get("controller_step_receipt_sha256", "")).length() != 71
		or String(observation.get("schema_version", ""))
		!= SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA
		or String(observation.get("application_receipt_schema_version", ""))
		!= SDK_GODOT_FULL_AUTHORITY_APPLICATION_RECEIPT_SCHEMA
		or int(observation.get("semantic_step", -1)) != int(row.get("semantic_step", -2))
		or not bool(observation.get("after_contact_observation_complete", false))
		or not bool(observation.get("configured_motor_parameters_only", false))
		or bool(observation.get("measured_motor_torque_available", true))
		or bool(observation.get("measured_motor_impulse_available", true))
		or int(observation.get("world_build_count", -1)) != 0
		or bool(observation.get("physical_acceptance_authority", true))
		or typeof(applications_value) != TYPE_ARRAY
		or typeof(ordered_actuator_ids_value) != TYPE_ARRAY
		or typeof(ordered_limb_ids_value) != TYPE_ARRAY
	):
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_HEADER_INVALID")
	var applications: Array = applications_value
	var ordered_actuator_ids: Array = ordered_actuator_ids_value
	var ordered_limb_ids: Array = ordered_limb_ids_value
	var tolerance := float(observation.get("readback_tolerance", NAN))
	if (
		not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or applications.size() != ordered_actuator_ids.size()
	):
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_CARDINALITY_INVALID")
	var phase_by_limb_id: Dictionary = {}
	var observed_limb_ids: Array[String] = []
	for phase_value in limb_phase_rows:
		if typeof(phase_value) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_PHASE_INVALID")
		var phase: Dictionary = phase_value
		var limb_id := String(phase.get("limb_id", ""))
		if limb_id.is_empty() or phase_by_limb_id.has(limb_id):
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_LIMB_INVALID")
		phase_by_limb_id[limb_id] = phase
		observed_limb_ids.append(limb_id)
	if observed_limb_ids != ordered_limb_ids:
		return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_LIMB_ORDER_INVALID")
	var seen_actuator_ids: Dictionary = {}
	for index in range(applications.size()):
		if typeof(applications[index]) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_ACTUATOR_PHASE_OBSERVATION_ROW_INVALID")
		var application: Dictionary = applications[index]
		var actuator_id := String(application.get("actuator_id", ""))
		var limb_id := String(application.get("limb_id", ""))
		var requested_position := float(
			application.get("requested_target_position_rad", NAN)
		)
		var clamped_position := float(
			application.get("clamped_target_position_rad", NAN)
		)
		var controller_target := float(
			application.get("controller_target_velocity_rad_s", NAN)
		)
		var applied_target := float(application.get("host_applied_target_velocity_rad_s", NAN))
		var target_readback := float(application.get("motor_target_velocity_readback_rad_s", NAN))
		var target_error := float(application.get("motor_target_velocity_readback_error_rad_s", NAN))
		var declared_impulse := float(application.get("declared_maximum_impulse_nms", NAN))
		var impulse_readback := float(application.get("motor_maximum_impulse_readback_nms", NAN))
		var impulse_error := float(application.get("motor_maximum_impulse_readback_error_nms", NAN))
		var maximum_speed := float(application.get("maximum_target_speed_rad_s", NAN))
		if (
			not _has_exact_keys(
				application,
				SDK_GODOT_ACTUATOR_PHASE_APPLICATION_KEYS,
			)
			or actuator_id.is_empty()
			or seen_actuator_ids.has(actuator_id)
			or actuator_id != String(ordered_actuator_ids[index])
			or String(application.get("joint_id", "")).is_empty()
			or String(application.get("host_joint_id", "")).is_empty()
			or int(application.get("limb_joint_index", -1)) < 0
			or not phase_by_limb_id.has(limb_id)
			or not before.has(limb_id)
			or not after.has(limb_id)
			or typeof(before[limb_id]) != TYPE_BOOL
			or typeof(after[limb_id]) != TYPE_BOOL
			or typeof(application.get("foot_contact_before", null)) != TYPE_BOOL
			or typeof(application.get("foot_contact_after", null)) != TYPE_BOOL
			or bool(application["foot_contact_before"]) != bool(before[limb_id])
			or bool(application["foot_contact_after"]) != bool(after[limb_id])
			or int(application.get("local_phase_step_before", -1))
			!= int((phase_by_limb_id[limb_id] as Dictionary).get("local_phase_step", -2))
			or int(application.get("gait_step_before", -1))
			!= int((phase_by_limb_id[limb_id] as Dictionary).get("gait_step", -2))
			or int(application.get("release_hold_step_count_before", -1))
			!= int((phase_by_limb_id[limb_id] as Dictionary).get("release_hold_step_count", -2))
			or not is_finite(requested_position)
			or not is_finite(clamped_position)
			or not is_finite(controller_target)
			or not is_finite(applied_target)
			or not is_finite(target_readback)
			or not is_finite(target_error)
			or not is_finite(declared_impulse)
			or not is_finite(impulse_readback)
			or not is_finite(impulse_error)
			or not is_finite(maximum_speed)
			or maximum_speed <= 0.0
			or declared_impulse <= 0.0
			or absf(controller_target - applied_target) > tolerance
			or absf(applied_target) > maximum_speed + tolerance
			or absf(target_error - absf(target_readback - applied_target)) > 1.0e-15
			or absf(impulse_error - absf(impulse_readback - declared_impulse)) > 1.0e-15
			or target_error > tolerance
			or impulse_error > tolerance
			or bool(application.get("host_additional_clamp_applied", true))
			or not bool(application.get("target_velocity_readback_matches", false))
			or not bool(application.get("maximum_impulse_readback_matches", false))
		):
			return _sdk_physical_trace_failure(
				"SDK_ACTUATOR_PHASE_OBSERVATION_ROW_MISMATCH:%s" % actuator_id
			)
		seen_actuator_ids[actuator_id] = true
	return {
		"ok": true,
		"failure_code": "",
		"validated_application_count": applications.size(),
		"validated_limb_count": ordered_limb_ids.size(),
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d3_trace_segment(trace_options: Dictionary, semantic_step: int) -> Dictionary:
	var turn_start := int(trace_options.get("turn_start_semantic_step", -1))
	var turn_end := turn_start + int(trace_options.get("turn_duration_steps", -1))
	var recovery_end := turn_end + int(trace_options.get("recovery_duration_steps", -1))
	var post_schedule_segment_id := String(
		trace_options.get("post_schedule_segment_id", "after_declared_schedule")
	)
	if not ["after_declared_schedule", "reference_continuation"].has(
		post_schedule_segment_id
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_POST_SCHEDULE_SEGMENT_INVALID")
	var segment_id := "reference_warmup"
	var heading_offset_rad := 0.0
	if semantic_step >= recovery_end:
		segment_id = post_schedule_segment_id
	elif semantic_step >= turn_end:
		segment_id = "reference_recovery"
	elif semantic_step >= turn_start:
		segment_id = "commanded_turn"
		heading_offset_rad = float(trace_options.get("turn_heading_offset_rad", NAN))
	if not is_finite(heading_offset_rad):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_SEGMENT_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"segment_id": segment_id,
		"heading_offset_rad": heading_offset_rad,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d3_limb_phase_projection(memory: Dictionary) -> Dictionary:
	var ordered_value: Variant = memory.get("ordered_limb_memory", null)
	if typeof(ordered_value) != TYPE_ARRAY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_LIMB_MEMORY_INVALID")
	var ordered_memory: Array = ordered_value
	if ordered_memory.size() != LIMB_ORDER.size():
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_LIMB_MEMORY_COUNT_INVALID")
	var phase_offsets := [0, 90, 180, 270]
	var result: Array[Dictionary] = []
	for index in range(LIMB_ORDER.size()):
		var memory_value: Variant = ordered_memory[index]
		if typeof(memory_value) != TYPE_DICTIONARY:
			return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_LIMB_MEMORY_ROW_INVALID")
		var limb_memory: Dictionary = memory_value
		var gait_step_value: Variant = limb_memory.get("gait_step", null)
		var release_hold_value: Variant = limb_memory.get("release_hold_step_count", null)
		if (
			String(limb_memory.get("limb_id", "")) != String(LIMB_ORDER[index])
			or not _r23d3_nonnegative_integer_value(gait_step_value)
			or not _r23d3_nonnegative_integer_value(release_hold_value)
		):
			return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_LIMB_MEMORY_VALUE_INVALID")
		var gait_step := int(gait_step_value)
		result.append(
			{
				"limb_id": String(LIMB_ORDER[index]),
				"gait_step": gait_step,
				"local_phase_step": posmod(gait_step + 360 - int(phase_offsets[index]), 360),
				"release_hold_step_count": int(release_hold_value),
			}
		)
	return {
		"ok": true,
		"failure_code": "",
		"ordered_limb_phase_before": result,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d3_nonnegative_integer_value(value: Variant) -> bool:
	# Native controller memory crosses the JSON transport before it reaches the
	# Godot trace projection. Godot may retain an unchanged counter as a float
	# even though the Rust schema is an unsigned integer; counters touched by a
	# host-side phase synchronization may already be TYPE_INT. Accept both
	# lossless representations, while still rejecting fractional, non-finite,
	# negative, and nonnumeric values.
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(value)):
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric >= 0.0 and numeric == floorf(numeric)


static func _r23d3_independent_oracle(
	state: Dictionary,
	command: Dictionary,
	profile: Dictionary,
) -> Dictionary:
	var base_pose_value: Variant = state.get("base_pose_world", null)
	var base_twist_value: Variant = state.get("base_twist_world", null)
	var task_frame_value: Variant = state.get("task_frame", null)
	if (
		typeof(base_pose_value) != TYPE_DICTIONARY
		or typeof(base_twist_value) != TYPE_DICTIONARY
		or typeof(task_frame_value) != TYPE_DICTIONARY
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_STATE_INVALID")
	var base_pose: Dictionary = base_pose_value
	var base_twist: Dictionary = base_twist_value
	var task_frame: Dictionary = task_frame_value
	var position_result := _r23d3_vector_projection(base_pose.get("position_m", null))
	var velocity_result := _r23d3_vector_projection(
		base_twist.get("linear_velocity_m_s", null)
	)
	var origin_result := _r23d3_vector_projection(task_frame.get("origin_world_m", null))
	var lateral_result := _r23d3_vector_projection(task_frame.get("lateral_axis_world_unit", null))
	var forward_result := _r23d3_vector_projection(task_frame.get("forward_axis_world_unit", null))
	if (
		not bool(position_result.get("ok", false))
		or not bool(velocity_result.get("ok", false))
		or not bool(origin_result.get("ok", false))
		or not bool(lateral_result.get("ok", false))
		or not bool(forward_result.get("ok", false))
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_VECTOR_INVALID")
	var orientation_value: Variant = base_pose.get("orientation_xyzw", null)
	if typeof(orientation_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_ORIENTATION_INVALID")
	var orientation: Dictionary = orientation_value
	if not _has_exact_keys(orientation, ["x", "y", "z", "w"]):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_ORIENTATION_INVALID")
	var quaternion := [
		float(orientation.get("x", NAN)),
		float(orientation.get("y", NAN)),
		float(orientation.get("z", NAN)),
		float(orientation.get("w", NAN)),
	]
	for component in quaternion:
		if not is_finite(float(component)):
			return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_ORIENTATION_INVALID")
	var position: Array = position_result["values"]
	var velocity: Array = velocity_result["values"]
	var origin: Array = origin_result["values"]
	var fixed_lateral: Array = lateral_result["values"]
	var forward: Array = forward_result["values"]
	var lateral_norm := sqrt(
		(
			float(fixed_lateral[0]) * float(fixed_lateral[0])
			+ float(fixed_lateral[1]) * float(fixed_lateral[1])
			+ float(fixed_lateral[2]) * float(fixed_lateral[2])
		)
	)
	var forward_norm := sqrt(
		(
			float(forward[0]) * float(forward[0])
			+ float(forward[1]) * float(forward[1])
			+ float(forward[2]) * float(forward[2])
		)
	)
	var forward_lateral_dot := (
		float(forward[0]) * float(fixed_lateral[0])
		+ float(forward[1]) * float(fixed_lateral[1])
		+ float(forward[2]) * float(fixed_lateral[2])
	)
	if (
		absf(lateral_norm - 1.0) > QSDK_R23D3_ORACLE_TOLERANCE
		or absf(forward_norm - 1.0) > QSDK_R23D3_ORACLE_TOLERANCE
		or absf(forward_lateral_dot) > QSDK_R23D3_ORACLE_TOLERANCE
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_LATERAL_NOT_UNIT")
	var displacement := [
		float(position[0]) - float(origin[0]),
		float(position[1]) - float(origin[1]),
		float(position[2]) - float(origin[2]),
	]
	var legacy_fixed_axis_cross_track_error_m := (
		float(displacement[0]) * float(fixed_lateral[0])
		+ float(displacement[1]) * float(fixed_lateral[1])
		+ float(displacement[2]) * float(fixed_lateral[2])
	)
	var legacy_fixed_axis_cross_track_velocity_m_s := (
		float(velocity[0]) * float(fixed_lateral[0])
		+ float(velocity[1]) * float(fixed_lateral[1])
		+ float(velocity[2]) * float(fixed_lateral[2])
	)
	var measured_heading_world_rad := atan2(
		2.0 * (float(quaternion[0]) * float(quaternion[2]) - float(quaternion[3]) * float(quaternion[1])),
		1.0 - 2.0 * (float(quaternion[1]) * float(quaternion[1]) + float(quaternion[2]) * float(quaternion[2])),
	)
	var reference_yaw_rad := float(task_frame.get("reference_yaw_rad", NAN))
	var desired_heading_rad := float(command.get("desired_heading_rad", NAN))
	var requested_heading_error_rad := _wrap_angle(desired_heading_rad - reference_yaw_rad)
	var selected_lateral := fixed_lateral.duplicate()
	var cross_track_frame_mode_id := String(profile.get("cross_track_frame_mode_id", ""))
	if cross_track_frame_mode_id == SDK_COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID:
		var sin_heading := sin(requested_heading_error_rad)
		var cos_heading := cos(requested_heading_error_rad)
		selected_lateral = [
			-sin_heading * float(forward[0]) + cos_heading * float(fixed_lateral[0]),
			-sin_heading * float(forward[1]) + cos_heading * float(fixed_lateral[1]),
			-sin_heading * float(forward[2]) + cos_heading * float(fixed_lateral[2]),
		]
	elif not cross_track_frame_mode_id.is_empty():
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_FRAME_MODE_INVALID")
	var cross_track_error_m := (
		float(displacement[0]) * float(selected_lateral[0])
		+ float(displacement[1]) * float(selected_lateral[1])
		+ float(displacement[2]) * float(selected_lateral[2])
	)
	var cross_track_velocity_m_s := (
		float(velocity[0]) * float(selected_lateral[0])
		+ float(velocity[1]) * float(selected_lateral[1])
		+ float(velocity[2]) * float(selected_lateral[2])
	)
	var heading_gain := float(profile.get("cross_track_heading_gain_rad_per_m", NAN))
	var velocity_gain := float(
		profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN)
	)
	var maximum_heading_error := float(
		profile.get(
			"maximum_desired_heading_error_rad",
			QSDK_R23D3_MAXIMUM_DESIRED_HEADING_ERROR_RAD,
		)
	)
	if (
		not is_finite(measured_heading_world_rad)
		or not is_finite(reference_yaw_rad)
		or not is_finite(desired_heading_rad)
		or not is_finite(heading_gain)
		or not is_finite(velocity_gain)
		or not is_finite(maximum_heading_error)
		or maximum_heading_error <= 0.0
	):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_ORACLE_INPUT_INVALID")
	var measured_yaw_error_rad := _wrap_angle(measured_heading_world_rad - reference_yaw_rad)
	var desired_heading_error_rad := clampf(
		requested_heading_error_rad
		- heading_gain * cross_track_error_m
		- velocity_gain * cross_track_velocity_m_s,
		-maximum_heading_error,
		maximum_heading_error,
	)
	return {
		"ok": true,
		"failure_code": "",
		"measured_heading_world_rad": measured_heading_world_rad,
		"requested_heading_error_rad": requested_heading_error_rad,
		"legacy_fixed_axis_cross_track_error_m": legacy_fixed_axis_cross_track_error_m,
		"legacy_fixed_axis_cross_track_velocity_m_s": legacy_fixed_axis_cross_track_velocity_m_s,
		"expected_receipt":
		{
			"cross_track_error_m": cross_track_error_m,
			"cross_track_velocity_m_s": cross_track_velocity_m_s,
			"measured_yaw_error_rad": measured_yaw_error_rad,
			"desired_heading_error_rad": desired_heading_error_rad,
			"yaw_tracking_error_rad": _wrap_angle(
				measured_yaw_error_rad - desired_heading_error_rad
			),
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _task_frame_origin_trace_projection(
	receipt_value: Variant,
	task_frame: Dictionary,
	heading_receipt: Dictionary,
) -> Dictionary:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure(
			"SDK_PHYSICAL_TRACE_TASK_FRAME_ORIGIN_RECEIPT_INVALID"
		)
	var receipt: Dictionary = receipt_value
	if not _has_exact_keys(
		receipt,
		[
			"schema_version",
			"policy_id",
			"schedule_id",
			"segment_id",
			"origin_world_m",
			"reanchored_this_step",
			"reanchor_count",
			"world_build_count",
			"physics_state_modified",
			"adapter_actuation_applied",
			"physical_acceptance_authority",
		],
	):
		return _sdk_physical_trace_failure(
			"SDK_PHYSICAL_TRACE_TASK_FRAME_ORIGIN_RECEIPT_INVALID"
		)
	var state_origin := _r23d3_vector_projection(
		task_frame.get("origin_world_m", null)
	)
	var receipt_origin := _r23d3_vector_projection(
		receipt.get("origin_world_m", null)
	)
	if not bool(state_origin.get("ok", false)) or not bool(
		receipt_origin.get("ok", false)
	):
		return _sdk_physical_trace_failure(
			"SDK_PHYSICAL_TRACE_TASK_FRAME_ORIGIN_VECTOR_INVALID"
		)
	var state_values: Array = state_origin["values"]
	var receipt_values: Array = receipt_origin["values"]
	var vectors_match := true
	for index in range(3):
		vectors_match = (
			vectors_match
			and absf(float(state_values[index]) - float(receipt_values[index]))
			<= QSDK_R23D3_ORACLE_TOLERANCE
		)
	var origin_policy_id := String(receipt.get("policy_id", ""))
	var origin_reanchor_count := int(receipt.get("reanchor_count", -1))
	if (
		String(receipt.get("schema_version", ""))
		!= SDK_TASK_FRAME_ORIGIN_RECEIPT_SCHEMA_VERSION
		or not [
			SDK_HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID,
			SDK_WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID,
		].has(origin_policy_id)
		or String(receipt.get("schedule_id", ""))
		!= String(heading_receipt.get("schedule_id", ""))
		or String(receipt.get("segment_id", ""))
		!= String(heading_receipt.get("segment_id", ""))
		or typeof(receipt.get("reanchored_this_step", null)) != TYPE_BOOL
		or typeof(receipt.get("reanchor_count", null)) != TYPE_INT
		or (
			origin_policy_id == SDK_HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID
			and origin_reanchor_count <= 0
		)
		or (
			origin_policy_id
			== SDK_WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID
			and origin_reanchor_count < 0
		)
		or int(receipt.get("world_build_count", -1)) != 0
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("adapter_actuation_applied", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or not vectors_match
	):
		return _sdk_physical_trace_failure(
			"SDK_PHYSICAL_TRACE_TASK_FRAME_ORIGIN_RECEIPT_INVALID"
		)
	return {
		"ok": true,
		"failure_code": "",
		"task_frame_origin_policy_id": String(receipt["policy_id"]),
		"task_frame_origin_world_m": receipt_values.duplicate(),
		"task_frame_origin_reanchored_this_step": bool(
			receipt["reanchored_this_step"]
		),
		"task_frame_origin_reanchor_count": int(receipt["reanchor_count"]),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d3_vector_projection(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_VECTOR_INVALID")
	var vector: Dictionary = value
	if not _has_exact_keys(vector, ["x", "y", "z"]):
		return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_VECTOR_INVALID")
	var values := [
		float(vector.get("x", NAN)),
		float(vector.get("y", NAN)),
		float(vector.get("z", NAN)),
	]
	for component in values:
		if not is_finite(float(component)):
			return _sdk_physical_trace_failure("SDK_PHYSICAL_TRACE_VECTOR_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"values": values,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _sdk_physical_trace_failure(
	failure_code: String,
	detail: Dictionary = {},
) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"detail": detail.duplicate(true),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _normalize_sdk_shadow_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_shadow_options":
			{
				"enabled": false,
				"descriptor": {},
				"comparison_tolerance": 1.0e-9,
				"stability_policy_id": SDK_P5I3B_STABILITY_POLICY_ID,
			},
			"world_build_count": 0,
		}
	var uses_extended_options := _has_exact_keys(
		requested,
		SDK_SHADOW_EXTENDED_OPTION_KEYS,
	)
	var uses_material_options := _has_exact_keys(
		requested,
		SDK_SHADOW_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_options := _has_exact_keys(
		requested,
		SDK_SHADOW_CONTROLLER_OPTION_KEYS,
	)
	var uses_controller_material_options := _has_exact_keys(
		requested,
		SDK_SHADOW_CONTROLLER_MATERIAL_OPTION_KEYS,
	)
	if (
		not uses_controller_material_options
		and not uses_controller_options
		and not uses_material_options
		and not uses_extended_options
		and not _has_exact_keys(requested, SDK_SHADOW_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_KEYS",
			"world_build_count": 0,
		}
	var enabled_value: Variant = requested["enabled"]
	var descriptor_value: Variant = requested["descriptor"]
	var tolerance_value: Variant = requested["comparison_tolerance"]
	var stability_policy_value: Variant = (
		requested
		. get(
			"stability_policy_id",
			SDK_P5I3B_STABILITY_POLICY_ID,
		)
	)
	var material_profile_value: Variant = (
		requested
		. get(
			"material_profile_id",
			SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
		)
	)
	var controller_policy_value: Variant = (
		requested
		. get(
			"controller_policy_id",
			SDK_CANDIDATE35_POLICY_ID,
		)
	)
	if (
		typeof(enabled_value) != TYPE_BOOL
		or typeof(descriptor_value) != TYPE_DICTIONARY
		or typeof(stability_policy_value) != TYPE_STRING
		or typeof(material_profile_value) != TYPE_STRING
		or typeof(controller_policy_value) != TYPE_STRING
		or (typeof(tolerance_value) != TYPE_FLOAT and typeof(tolerance_value) != TYPE_INT)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_TYPE",
			"world_build_count": 0,
		}
	var tolerance := float(tolerance_value)
	if (
		not bool(enabled_value)
		or (descriptor_value as Dictionary).is_empty()
		or not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or not (
			[
				SDK_P5I3B_STABILITY_POLICY_ID,
				SDK_P5I3C_STABILITY_POLICY_ID,
				SDK_BW9L_A_STABILITY_POLICY_ID,
				SDK_BW9L_B_STABILITY_POLICY_ID,
				SDK_BW9L_C_STABILITY_POLICY_ID,
				SDK_BW9L_D_STABILITY_POLICY_ID,
				SDK_BW10F_A_STABILITY_POLICY_ID,
				SDK_BW10F_B_STABILITY_POLICY_ID,
				SDK_BW10F_C_STABILITY_POLICY_ID,
				SDK_BW10F_D_STABILITY_POLICY_ID,
				SDK_BW11R_A_STABILITY_POLICY_ID,
				SDK_BW11R_B_STABILITY_POLICY_ID,
				SDK_BW11R_C_STABILITY_POLICY_ID,
				SDK_BW11R_D_STABILITY_POLICY_ID,
				SDK_BW13P_A_STABILITY_POLICY_ID,
				SDK_BW13P_B_STABILITY_POLICY_ID,
				SDK_BW13P_C_STABILITY_POLICY_ID,
				SDK_BW13P_D_STABILITY_POLICY_ID,
			]
			. has(String(stability_policy_value))
		)
		or not (
			[
				SDK_CANDIDATE35_POLICY_ID,
				SDK_BALANCED_WAVE_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW14V_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID,
				SDK_BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
				SDK_BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
				SDK_BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID,
			]
			. has(String(controller_policy_value))
		)
		or String(material_profile_value).is_empty()
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_VALUE",
			"world_build_count": 0,
		}
	var normalized_options := {
		"enabled": true,
		"descriptor": (descriptor_value as Dictionary).duplicate(true),
		"comparison_tolerance": tolerance,
		"stability_policy_id": String(stability_policy_value),
	}
	if uses_controller_options or uses_controller_material_options:
		normalized_options["controller_policy_id"] = String(controller_policy_value)
	if uses_material_options or uses_controller_material_options:
		normalized_options["material_profile_id"] = String(material_profile_value)
	return {
		"ok": true,
		"failure_code": "",
		"sdk_shadow_options": normalized_options,
		"world_build_count": 0,
	}


static func compile_sdk_heading_schedule_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_heading_schedule_options":
			{
				"enabled": false,
				"schema_version": "",
				"schedule_id": "",
				"domain": "controller_semantic_step",
				"reference_heading_source": "state.task_frame.reference_yaw_rad",
				"segments": [],
				"after_last_segment": "hold_reference_heading",
			},
			"sdk_heading_schedule_sha256": "",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if not _has_exact_keys(requested, SDK_HEADING_SCHEDULE_OPTION_KEYS):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_HEADING_SCHEDULE_KEYS",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if (
		typeof(requested["schema_version"]) != TYPE_STRING
		or typeof(requested["schedule_id"]) != TYPE_STRING
		or typeof(requested["domain"]) != TYPE_STRING
		or typeof(requested["reference_heading_source"]) != TYPE_STRING
		or typeof(requested["segments"]) != TYPE_ARRAY
		or typeof(requested["after_last_segment"]) != TYPE_STRING
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_HEADING_SCHEDULE_TYPE",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if (
		String(requested["schema_version"]) != "sporespore_heading_offset_schedule_v1"
		or String(requested["schedule_id"]).is_empty()
		or String(requested["domain"]) != "controller_semantic_step"
		or (
			String(requested["reference_heading_source"])
			!= "state.task_frame.reference_yaw_rad"
		)
		or String(requested["after_last_segment"]) != "hold_reference_heading"
		or (requested["segments"] as Array).is_empty()
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_HEADING_SCHEDULE_VALUE",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var normalized_segments: Array = []
	var observed_segment_ids: Dictionary = {}
	var expected_start_step := 0
	for segment_value in requested["segments"]:
		if typeof(segment_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"failure_code": "INVALID_SDK_HEADING_SEGMENT_TYPE",
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		var segment: Dictionary = segment_value
		if not _has_exact_keys(segment, SDK_HEADING_SCHEDULE_SEGMENT_KEYS):
			return {
				"ok": false,
				"failure_code": "INVALID_SDK_HEADING_SEGMENT_KEYS",
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		if (
			typeof(segment["segment_id"]) != TYPE_STRING
			or typeof(segment["start_step_inclusive"]) != TYPE_INT
			or typeof(segment["end_step_exclusive"]) != TYPE_INT
			or (
				typeof(segment["heading_offset_rad"]) != TYPE_FLOAT
				and typeof(segment["heading_offset_rad"]) != TYPE_INT
			)
			or typeof(segment["command_role"]) != TYPE_STRING
		):
			return {
				"ok": false,
				"failure_code": "INVALID_SDK_HEADING_SEGMENT_FIELD_TYPE",
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		var segment_id := String(segment["segment_id"])
		var start_step := int(segment["start_step_inclusive"])
		var end_step := int(segment["end_step_exclusive"])
		var heading_offset_rad := float(segment["heading_offset_rad"])
		var command_role := String(segment["command_role"])
		if (
			segment_id.is_empty()
			or observed_segment_ids.has(segment_id)
			or start_step != expected_start_step
			or end_step <= start_step
			or not is_finite(heading_offset_rad)
			or absf(heading_offset_rad) > PI
			or not ["reference_heading", "turn_heading"].has(command_role)
			or (command_role == "reference_heading" and heading_offset_rad != 0.0)
		):
			return {
				"ok": false,
				"failure_code": "INVALID_SDK_HEADING_SEGMENT_VALUE",
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		observed_segment_ids[segment_id] = true
		normalized_segments.append(
			{
				"segment_id": segment_id,
				"start_step_inclusive": start_step,
				"end_step_exclusive": end_step,
				"heading_offset_rad": heading_offset_rad,
				"command_role": command_role,
			}
		)
		expected_start_step = end_step
	var normalized := {
		"enabled": true,
		"schema_version": "sporespore_heading_offset_schedule_v1",
		"schedule_id": String(requested["schedule_id"]),
		"domain": "controller_semantic_step",
		"reference_heading_source": "state.task_frame.reference_yaw_rad",
		"segments": normalized_segments,
		"after_last_segment": "hold_reference_heading",
	}
	return {
		"ok": true,
		"failure_code": "",
		"sdk_heading_schedule_options": normalized,
		"sdk_heading_schedule_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func resolve_sdk_heading_command_options(
	compiled_schedule: Dictionary,
	semantic_step: int,
) -> Dictionary:
	if semantic_step < 0:
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_HEADING_COMMAND_STEP",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if not bool(compiled_schedule.get("enabled", false)):
		return {
			"ok": true,
			"failure_code": "",
			"heading_command_options": {},
			"segment_end_step_exclusive": -1,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var selected_segment: Dictionary = {}
	for segment_value in compiled_schedule.get("segments", []):
		var segment: Dictionary = segment_value
		if (
			int(segment["start_step_inclusive"]) <= semantic_step
			and semantic_step < int(segment["end_step_exclusive"])
		):
			selected_segment = segment
			break
	if selected_segment.is_empty():
		selected_segment = {
			"segment_id": "reference_continuation",
			"start_step_inclusive": semantic_step,
			"end_step_exclusive": -1,
			"heading_offset_rad": 0.0,
			"command_role": "reference_heading",
		}
	return {
		"ok": true,
		"failure_code": "",
		"heading_command_options":
		{
			"schema_version": "sporespore_heading_offset_command_v1",
			"schedule_id": String(compiled_schedule["schedule_id"]),
			"segment_id": String(selected_segment["segment_id"]),
			"command_role": String(selected_segment["command_role"]),
			"heading_offset_rad": float(selected_segment["heading_offset_rad"]),
		},
		"segment_end_step_exclusive": int(selected_segment["end_step_exclusive"]),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _normalize_sdk_authority_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_authority_options":
			{
				"enabled": false,
				"descriptor": {},
				"comparison_tolerance": 1.0e-9,
				"authority_scope": "evidence_handoff",
				"stability_policy_id": SDK_P5I3B_STABILITY_POLICY_ID,
			},
			"world_build_count": 0,
		}
	var uses_extended_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_EXTENDED_OPTION_KEYS,
	)
	var uses_material_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_OPTION_KEYS,
	)
	var uses_controller_material_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_material_scale_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_OPTION_KEYS,
	)
	var uses_controller_material_origin_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_OPTION_KEYS,
	)
	var uses_controller_material_scale_origin_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_ORIGIN_OPTION_KEYS,
	)
	var uses_controller_material_origin_cap_binding_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_CAP_BINDING_OPTION_KEYS,
	)
	var uses_controller_material_origin_cap_factorial_binding_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_ORIGIN_CAP_FACTORIAL_BINDING_OPTION_KEYS,
	)
	if (
		not uses_controller_material_origin_cap_factorial_binding_options
		and not uses_controller_material_origin_cap_binding_options
		and not uses_controller_material_scale_origin_options
		and not uses_controller_material_origin_options
		and not uses_controller_material_scale_options
		and not uses_controller_material_options
		and not uses_controller_options
		and not uses_material_options
		and not uses_extended_options
		and not _has_exact_keys(requested, SDK_AUTHORITY_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_KEYS",
			"world_build_count": 0,
		}
	var enabled_value: Variant = requested["enabled"]
	var descriptor_value: Variant = requested["descriptor"]
	var tolerance_value: Variant = requested["comparison_tolerance"]
	var authority_scope_value: Variant = requested["authority_scope"]
	var stability_policy_value: Variant = (
		requested
		. get(
			"stability_policy_id",
			SDK_P5I3B_STABILITY_POLICY_ID,
		)
	)
	var material_profile_value: Variant = (
		requested
		. get(
			"material_profile_id",
			SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
		)
	)
	var controller_policy_value: Variant = (
		requested
		. get(
			"controller_policy_id",
			SDK_CANDIDATE35_POLICY_ID,
		)
	)
	var stability_influence_global_scale_value: Variant = (
		requested.get("stability_influence_global_scale", -1.0)
	)
	var task_frame_origin_policy_value: Variant = requested.get(
		"task_frame_origin_policy_id",
		SDK_FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
	)
	var live_fixture_actuator_cap_binding_policy_value: Variant = requested.get(
		"live_fixture_actuator_cap_binding_policy_id",
		"",
	)
	var live_fixture_actuator_cap_binding_profile_value: Variant = requested.get(
		"live_fixture_actuator_cap_binding_profile_id",
		"",
	)
	if (
		typeof(enabled_value) != TYPE_BOOL
		or typeof(descriptor_value) != TYPE_DICTIONARY
		or typeof(authority_scope_value) != TYPE_STRING
		or typeof(stability_policy_value) != TYPE_STRING
		or typeof(material_profile_value) != TYPE_STRING
		or typeof(controller_policy_value) != TYPE_STRING
		or typeof(task_frame_origin_policy_value) != TYPE_STRING
		or typeof(live_fixture_actuator_cap_binding_policy_value) != TYPE_STRING
		or typeof(live_fixture_actuator_cap_binding_profile_value) != TYPE_STRING
		or (
			typeof(stability_influence_global_scale_value) != TYPE_FLOAT
			and typeof(stability_influence_global_scale_value) != TYPE_INT
		)
		or (typeof(tolerance_value) != TYPE_FLOAT and typeof(tolerance_value) != TYPE_INT)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_TYPE",
			"world_build_count": 0,
		}
	var tolerance := float(tolerance_value)
	var stability_influence_global_scale := float(
		stability_influence_global_scale_value
	)
	if (
		not bool(enabled_value)
		or (descriptor_value as Dictionary).is_empty()
		or not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or not (
			[
				"evidence_handoff",
				"post_settle_full",
				"stability_contribution_overlay",
			]
			. has(String(authority_scope_value))
		)
		or not (
			[
				SDK_P5I3B_STABILITY_POLICY_ID,
				SDK_P5I3C_STABILITY_POLICY_ID,
				SDK_BW9L_A_STABILITY_POLICY_ID,
				SDK_BW9L_B_STABILITY_POLICY_ID,
				SDK_BW9L_C_STABILITY_POLICY_ID,
				SDK_BW9L_D_STABILITY_POLICY_ID,
				SDK_BW10F_A_STABILITY_POLICY_ID,
				SDK_BW10F_B_STABILITY_POLICY_ID,
				SDK_BW10F_C_STABILITY_POLICY_ID,
				SDK_BW10F_D_STABILITY_POLICY_ID,
				SDK_BW11R_A_STABILITY_POLICY_ID,
				SDK_BW11R_B_STABILITY_POLICY_ID,
				SDK_BW11R_C_STABILITY_POLICY_ID,
				SDK_BW11R_D_STABILITY_POLICY_ID,
				SDK_BW13P_A_STABILITY_POLICY_ID,
				SDK_BW13P_B_STABILITY_POLICY_ID,
				SDK_BW13P_C_STABILITY_POLICY_ID,
				SDK_BW13P_D_STABILITY_POLICY_ID,
			]
			. has(String(stability_policy_value))
		)
		or (
			String(authority_scope_value) == "stability_contribution_overlay"
			and not SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS.has(String(stability_policy_value))
		)
		or not (
			[
				SDK_CANDIDATE35_POLICY_ID,
				SDK_BALANCED_WAVE_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW14V_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID,
				SDK_BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
				SDK_BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
				SDK_BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID,
			]
			. has(String(controller_policy_value))
		)
		or String(material_profile_value).is_empty()
		or not [
			SDK_FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
			SDK_HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID,
			SDK_WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID,
		].has(String(task_frame_origin_policy_value))
		or (
			(
				uses_controller_material_origin_cap_binding_options
				or uses_controller_material_origin_cap_factorial_binding_options
			)
			and (
				(
					uses_controller_material_origin_cap_binding_options
					and (
						String(live_fixture_actuator_cap_binding_policy_value)
						!= SdkGodotJoltLiveFixtureActuatorCapBindingScript.POLICY_ID
						or not String(live_fixture_actuator_cap_binding_profile_value).is_empty()
					)
				)
				or (
					uses_controller_material_origin_cap_factorial_binding_options
					and (
						not (
							(
								String(live_fixture_actuator_cap_binding_policy_value)
								== SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript.POLICY_ID
								and SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript.ORDERED_PROFILE_IDS.has(
									String(live_fixture_actuator_cap_binding_profile_value)
								)
							)
							or (
								String(live_fixture_actuator_cap_binding_policy_value)
								== SdkGodotJoltPublicActuatorCapProfileBindingScript.POLICY_ID
								and String(live_fixture_actuator_cap_binding_profile_value)
								== SdkGodotJoltPublicActuatorCapProfileBindingScript.PROFILE_ID
							)
						)
					)
				)
				or String(authority_scope_value) != "post_settle_full"
			)
		)
		or not is_finite(stability_influence_global_scale)
		or (
			(
				uses_controller_material_scale_options
				or uses_controller_material_scale_origin_options
			)
			and (
				stability_influence_global_scale < 0.0
				or stability_influence_global_scale > 1.0
				or String(authority_scope_value) != "post_settle_full"
				or not SDK_BW13P_STABILITY_POLICY_IDS.has(
					String(stability_policy_value)
				)
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_VALUE",
			"world_build_count": 0,
		}
	var normalized_options := {
		"enabled": true,
		"descriptor": (descriptor_value as Dictionary).duplicate(true),
		"comparison_tolerance": tolerance,
		"authority_scope": String(authority_scope_value),
		"stability_policy_id": String(stability_policy_value),
	}
	if (
		uses_controller_options
		or uses_controller_material_options
		or uses_controller_material_scale_options
		or uses_controller_material_origin_options
		or uses_controller_material_scale_origin_options
		or uses_controller_material_origin_cap_binding_options
		or uses_controller_material_origin_cap_factorial_binding_options
	):
		normalized_options["controller_policy_id"] = String(controller_policy_value)
	if (
		uses_material_options
		or uses_controller_material_options
		or uses_controller_material_scale_options
		or uses_controller_material_origin_options
		or uses_controller_material_scale_origin_options
		or uses_controller_material_origin_cap_binding_options
		or uses_controller_material_origin_cap_factorial_binding_options
	):
		normalized_options["material_profile_id"] = String(material_profile_value)
	if (
		uses_controller_material_scale_options
		or uses_controller_material_scale_origin_options
	):
		normalized_options["stability_influence_global_scale"] = (
			stability_influence_global_scale
		)
	if (
		uses_controller_material_origin_options
		or uses_controller_material_scale_origin_options
		or uses_controller_material_origin_cap_binding_options
		or uses_controller_material_origin_cap_factorial_binding_options
	):
		normalized_options["task_frame_origin_policy_id"] = String(
			task_frame_origin_policy_value
		)
	if (
		uses_controller_material_origin_cap_binding_options
		or uses_controller_material_origin_cap_factorial_binding_options
	):
		normalized_options["live_fixture_actuator_cap_binding_policy_id"] = String(
			live_fixture_actuator_cap_binding_policy_value
		)
	if uses_controller_material_origin_cap_factorial_binding_options:
		normalized_options["live_fixture_actuator_cap_binding_profile_id"] = String(
			live_fixture_actuator_cap_binding_profile_value
		)
	return {
		"ok": true,
		"failure_code": "",
		"sdk_authority_options": normalized_options,
		"world_build_count": 0,
	}


static func _sdk_shadow_configuration_failure(
	motor_direction_sign: float,
	knee_flexion_scale: float,
	gait_phase_order_id: String,
	swing_ticks: int,
	contact_clearance_assist_rad: float,
	contact_clearance_assist_limb_id: String,
	initial_perturbation: Dictionary,
	robustness_options: Dictionary,
	path_steering_options: Dictionary,
	gait_clock_options: Dictionary,
	sdk_full_post_settle_authority_enabled: bool,
	sdk_p5i3c_fixed_exposure_enabled: bool,
) -> String:
	if (
		not is_equal_approx(motor_direction_sign, -1.0)
		or not is_equal_approx(knee_flexion_scale, 1.75)
		or gait_phase_order_id != "lateral"
		or swing_ticks != 72
		or not is_equal_approx(contact_clearance_assist_rad, 0.40)
		or contact_clearance_assist_limb_id != "all"
	):
		return "SDK_SHADOW_UNSUPPORTED_CONTROLLER_CONFIGURATION"
	if (
		int(initial_perturbation.get("gait_phase_offset_ticks", 0)) != 0
		and not (sdk_full_post_settle_authority_enabled or sdk_p5i3c_fixed_exposure_enabled)
	):
		return "SDK_SHADOW_PHASE_OFFSET_NOT_YET_SUPPORTED"
	if (
		not bool(robustness_options.get("contact_gated_phase_progression", false))
		or int(robustness_options.get("maximum_contact_gate_hold_ticks", -1)) != 120
		or int(robustness_options.get("maximum_contact_gated_phase_skew_ticks", -1)) != 12
		or not is_zero_approx(
			float(robustness_options.get("lateral_stride_steering_gain_per_m", NAN))
		)
	):
		return "SDK_SHADOW_UNSUPPORTED_CONTACT_CLOCK"
	if (
		not bool(path_steering_options.get("phase_bounded_path_steering_enabled", false))
		or not is_equal_approx(
			float(path_steering_options.get("maximum_desired_heading_error_rad", NAN)),
			0.25,
		)
		or not is_equal_approx(
			float(path_steering_options.get("maximum_steering_fraction", NAN)),
			0.40,
		)
		or int(path_steering_options.get("steering_update_interval_ticks", -1)) != 90
	):
		return "SDK_SHADOW_UNSUPPORTED_STEERING_CLOCK"
	if (
		int(gait_clock_options.get("physics_hz", -1)) != 120
		or int(gait_clock_options.get("cycle_ticks", -1)) != 360
		or int(gait_clock_options.get("swing_ticks", -1)) != 72
		or int(gait_clock_options.get("minimum_airborne_dwell_ticks", -1)) != 3
		or not is_equal_approx(
			float(gait_clock_options.get("motor_position_gain_per_s", NAN)),
			8.0,
		)
		or not is_equal_approx(
			float(gait_clock_options.get("motor_rate_damping", NAN)),
			0.65,
		)
		or not is_equal_approx(
			float(gait_clock_options.get("maximum_motor_target_speed_rad_s", NAN)),
			3.5,
		)
	):
		return "SDK_SHADOW_UNSUPPORTED_GAIT_CLOCK"
	return ""


static func _normalize_dynamic_support_diagnostic_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"dynamic_support_diagnostic_options":
			{
				"enabled": false,
				"lateral_limit_m": 1.0,
				"source_digests": {},
				"receipt_schema_version": "",
				"policy_id": "",
				"sample_schema_version": "",
			},
			"world_build_count": 0,
		}
	var is_versioned_profile := _has_exact_keys(
		requested,
		DYNAMIC_SUPPORT_DIAGNOSTIC_VERSIONED_OPTION_KEYS,
	)
	if (
		not is_versioned_profile
		and not _has_exact_keys(requested, DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS",
			"world_build_count": 0,
		}
	if (
		is_versioned_profile
		and (not (
			(
				(
					String(requested.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
				)
				and (
					String(requested.get("policy_id", ""))
					== DynamicSupportReceiptScript.GQ14_POLICY_ID
				)
				and (
					String(requested.get("sample_schema_version", ""))
					== DynamicSupportReceiptScript.GQ14_SAMPLE_SCHEMA_VERSION
				)
			)
			or (
				(
					String(requested.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				and (
					String(requested.get("policy_id", ""))
					== DynamicSupportReceiptScript.GQ15_POLICY_ID
				)
				and (
					String(requested.get("sample_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SAMPLE_SCHEMA_VERSION
				)
			)
		))
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_DIAGNOSTIC_PROFILE_IDENTITY",
			"world_build_count": 0,
		}
	if typeof(requested["enabled"]) != TYPE_BOOL or not bool(requested["enabled"]):
		return {
			"ok": false,
			"failure_code": "DYNAMIC_SUPPORT_DIAGNOSTIC_MUST_BE_ENABLED",
			"world_build_count": 0,
		}
	var lateral_limit_value: Variant = requested["lateral_limit_m"]
	if (
		(typeof(lateral_limit_value) != TYPE_FLOAT and typeof(lateral_limit_value) != TYPE_INT)
		or not is_finite(float(lateral_limit_value))
		or float(lateral_limit_value) <= 0.0
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_LATERAL_LIMIT",
			"world_build_count": 0,
		}
	if not requested["source_digests"] is Dictionary:
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_SOURCE_DIGESTS",
			"world_build_count": 0,
		}
	var source_digests: Dictionary = requested["source_digests"]
	if source_digests.is_empty():
		return {
			"ok": false,
			"failure_code": "EMPTY_DYNAMIC_SUPPORT_SOURCE_DIGESTS",
			"world_build_count": 0,
		}
	for digest_value in source_digests.values():
		if (
			typeof(digest_value) != TYPE_STRING
			or not String(digest_value).begins_with("sha256:")
			or String(digest_value).length() != 71
		):
			return {
				"ok": false,
				"failure_code": "INVALID_DYNAMIC_SUPPORT_SOURCE_DIGEST",
				"world_build_count": 0,
			}
	return {
		"ok": true,
		"dynamic_support_diagnostic_options":
		{
			"enabled": true,
			"lateral_limit_m": float(lateral_limit_value),
			"source_digests": source_digests.duplicate(true),
			"receipt_schema_version": String(requested.get("receipt_schema_version", "")),
			"policy_id": String(requested.get("policy_id", "")),
			"sample_schema_version": String(requested.get("sample_schema_version", "")),
		},
		"world_build_count": 0,
	}


static func _dynamic_support_phase_id(
	tick: int,
	settle_ticks: int,
	evidence_start_tick: int,
	evidence_end_tick: int,
	cooldown_end_tick: int,
) -> String:
	if tick == settle_ticks - 1:
		return "SETTLE_BOUNDARY"
	if tick < evidence_start_tick:
		return "WARMUP"
	if evidence_end_tick < 0 or tick < evidence_end_tick:
		return "EVIDENCE"
	if cooldown_end_tick < 0 or tick < cooldown_end_tick:
		return "COOLDOWN"
	return "TERMINAL_SETTLE"


static func _limb_by_id(limbs: Array, limb_id: String) -> Dictionary:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb.get("limb_id", "")) == limb_id:
			return limb
	return {}


static func _has_exact_keys(source: Dictionary, expected: Array) -> bool:
	if source.size() != expected.size():
		return false
	for key in expected:
		if not source.has(key):
			return false
	return true


static func _sdk_initial_gait_steps(
	base_gait_step_by_limb: Dictionary,
	phase_offset_ticks: int,
	fixed_exposure_enabled: bool,
) -> Dictionary:
	var result := base_gait_step_by_limb.duplicate(true)
	if fixed_exposure_enabled:
		for limb_id_value in LIMB_ORDER:
			var limb_id := String(limb_id_value)
			result[limb_id] = int(result[limb_id]) + phase_offset_ticks
	return result


## Resolves the same mutually exclusive SDK route used by the physical loop.
## This function is public so zero-world launch gates can test production
## control-flow identity instead of reconstructing the booleans independently.
static func compile_sdk_execution_mode_plan(
	sdk_adapter_enabled: bool,
	sdk_authority_enabled: bool,
	sdk_authority_scope: String,
	stability_policy_id: String,
	phase_offset_ticks: int,
) -> Dictionary:
	if (
		absi(phase_offset_ticks) > MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS
		or (
			sdk_authority_enabled
			and not [
				"evidence_handoff",
				"post_settle_full",
				"stability_contribution_overlay",
			].has(sdk_authority_scope)
		)
	):
		return {
			"schema_version": "sporespore_sdk_execution_mode_plan_v1",
			"ok": false,
			"failure_code": "SDK_EXECUTION_MODE_PLAN_INPUT_INVALID",
			"actual_world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var full_post_settle := (
		sdk_adapter_enabled
		and sdk_authority_enabled
		and sdk_authority_scope == "post_settle_full"
	)
	var contribution_overlay := (
		sdk_adapter_enabled
		and sdk_authority_enabled
		and sdk_authority_scope == "stability_contribution_overlay"
	)
	var feedback_policy := (
		sdk_adapter_enabled
		and SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS.has(stability_policy_id)
	)
	## The fixed-exposure path is the legacy-base overlay experiment. A full
	## post-settle authority campaign must never inherit its initial-memory,
	## time-window, or legacy-write semantics merely because both routes use
	## the same stability policy.
	var fixed_exposure := feedback_policy and not full_post_settle
	var full_authority_contribution := (
		full_post_settle
		and SDK_BW13P_STABILITY_POLICY_IDS.has(stability_policy_id)
	)
	var route_count := (
		int(full_post_settle)
		+ int(contribution_overlay)
		+ int(
			sdk_adapter_enabled
			and sdk_authority_enabled
			and sdk_authority_scope == "evidence_handoff"
		)
	)
	var exact := (
		not sdk_authority_enabled
		or route_count == 1
	)
	var zero_base_initial_gait_steps := {
		"front_left": 0,
		"front_right": 0,
		"rear_left": 0,
		"rear_right": 0,
	}
	var resolved_zero_base_initial_gait_steps := _sdk_initial_gait_steps(
		zero_base_initial_gait_steps,
		phase_offset_ticks,
		fixed_exposure,
	)
	return {
		"schema_version": "sporespore_sdk_execution_mode_plan_v1",
		"ok": exact,
		"failure_code": "" if exact else "SDK_EXECUTION_MODE_PLAN_ROUTE_AMBIGUOUS",
		"sdk_adapter_enabled": sdk_adapter_enabled,
		"sdk_authority_enabled": sdk_authority_enabled,
		"authority_scope": sdk_authority_scope,
		"stability_policy_id": stability_policy_id,
		"requested_phase_offset_ticks": phase_offset_ticks,
		"zero_base_initial_gait_steps":
		resolved_zero_base_initial_gait_steps,
		"initial_phase_offset_ticks":
		phase_offset_ticks if fixed_exposure else 0,
		"full_post_settle_authority_enabled": full_post_settle,
		"stability_contribution_overlay_enabled": contribution_overlay,
		"stability_feedback_policy": feedback_policy,
		"fixed_exposure_enabled": fixed_exposure,
		"full_authority_stability_contribution_enabled":
		full_authority_contribution,
		"phase_offset_application_mode":
		(
			"scheduled_once_at_warmup_boundary"
			if full_post_settle
			else (
				"baked_once_into_initial_memory"
				if fixed_exposure
				else "not_applicable"
			)
		),
		"legacy_base_motor_writes_allowed":
		contribution_overlay or fixed_exposure,
		"exclusive_native_post_settle_motor_writes_required":
		full_post_settle,
		"actual_world_build_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


static func _sdk_effective_phase_offset_ticks(
	phase_offset_ticks: int,
	fixed_exposure_enabled: bool,
	full_post_settle_authority_enabled: bool,
	tick: int,
	activation_tick: int,
) -> int:
	if fixed_exposure_enabled or (full_post_settle_authority_enabled and tick >= activation_tick):
		return phase_offset_ticks
	return 0


static func _controller_configuration(
	motor_direction_sign: float,
	knee_motor_impulse_scale: float,
	knee_flexion_scale: float,
	gait_phase_order_id: String,
	gait_phase_order: Array,
	swing_ticks: int,
	contact_clearance_assist_rad: float,
	contact_clearance_assist_limb_id: String,
	evidence_boundary_alignment_ticks: int,
	robustness_options: Dictionary,
	path_steering_options: Dictionary,
	actuator_impulse_options: Dictionary,
	motor_velocity_options: Dictionary,
	gait_clock_options: Dictionary,
) -> Dictionary:
	var configuration := {
		"schema_version": "sporespore_physical_wave_gait_controller_configuration_v1",
		"physics_hz": int(gait_clock_options["physics_hz"]),
		"motor_direction_sign": motor_direction_sign,
		"knee_motor_impulse_scale": knee_motor_impulse_scale,
		"knee_flexion_scale": knee_flexion_scale,
		"motor_position_gain_per_s": float(gait_clock_options["motor_position_gain_per_s"]),
		"motor_rate_damping": float(gait_clock_options["motor_rate_damping"]),
		"maximum_motor_target_speed_rad_s":
		float(gait_clock_options["maximum_motor_target_speed_rad_s"]),
		"hip_forward_target_rad": HIP_FORWARD_TARGET_RAD,
		"hip_rear_target_rad": HIP_REAR_TARGET_RAD,
		"knee_swing_flexion_rad": KNEE_SWING_FLEXION_RAD,
		"gait_phase_order_id": gait_phase_order_id,
		"gait_phase_order": gait_phase_order.duplicate(),
		"cycle_ticks": int(gait_clock_options["cycle_ticks"]),
		"swing_ticks": swing_ticks,
		"settle_ticks": int(gait_clock_options["settle_ticks"]),
		"warmup_cycles": int(gait_clock_options["warmup_cycles"]),
		"evidence_cycles": int(gait_clock_options["evidence_cycles"]),
		"cooldown_cycles": int(gait_clock_options["cooldown_cycles"]),
		"terminal_settle_ticks": int(gait_clock_options["terminal_settle_ticks"]),
		"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		"contact_clearance_assist_rad": contact_clearance_assist_rad,
		"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		"robustness_options": robustness_options.duplicate(true),
		"morphology_adaptive_policy_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	if bool(path_steering_options["phase_bounded_path_steering_enabled"]):
		configuration["path_steering_options"] = path_steering_options.duplicate(true)
	if bool(actuator_impulse_options["mass_adaptive_actuator_enabled"]):
		configuration["actuator_impulse_options"] = actuator_impulse_options.duplicate(true)
	if bool(motor_velocity_options["mass_adaptive_motor_velocity_enabled"]):
		configuration["motor_velocity_options"] = motor_velocity_options.duplicate(true)
	if String(gait_clock_options["policy_id"]) != GaitClockSpecScript.REFERENCE_POLICY_ID:
		configuration["gait_clock_options"] = gait_clock_options.duplicate(true)
	return configuration


static func compile_evidence_threshold_options(requested: Dictionary = {}) -> Dictionary:
	var normalized_result := _normalize_evidence_threshold_options(requested)
	if not bool(normalized_result.get("ok", false)):
		return normalized_result
	var evidence_threshold_options: Dictionary = normalized_result["evidence_threshold_options"]
	return {
		"ok": true,
		"failure_code": "",
		"evidence_threshold_options": evidence_threshold_options.duplicate(true),
		"evidence_threshold_configuration_sha256":
		CanonicalJsonScript.sha256(evidence_threshold_options),
		"world_build_count": 0,
	}


static func compile_solver_policy_options(requested: Dictionary = {}) -> Dictionary:
	var candidate := requested.duplicate(true)
	if candidate.is_empty():
		candidate = (
			(ALLOWED_SOLVER_POLICY_OPTIONS[DEFAULT_SOLVER_POLICY_ID] as Dictionary).duplicate(true)
		)
	for key_value in candidate.keys():
		var requested_key := String(key_value)
		if not SOLVER_POLICY_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_SOLVER_POLICY_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in SOLVER_POLICY_OPTION_KEYS:
		if not candidate.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_SOLVER_POLICY_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(candidate["solver_policy_id"]) != TYPE_STRING
		or typeof(candidate["physics_engine"]) != TYPE_STRING
		or typeof(candidate["physics_hz"]) != TYPE_INT
		or typeof(candidate["solver_velocity_steps"]) != TYPE_INT
		or typeof(candidate["solver_position_steps"]) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SOLVER_POLICY_OPTION_TYPE",
			"world_build_count": 0,
		}
	var policy_id := String(candidate["solver_policy_id"])
	if not ALLOWED_SOLVER_POLICY_OPTIONS.has(policy_id):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_SOLVER_POLICY_ID",
			"solver_policy_id": policy_id,
			"world_build_count": 0,
		}
	var normalized: Dictionary = (ALLOWED_SOLVER_POLICY_OPTIONS[policy_id] as Dictionary).duplicate(
		true
	)
	if candidate != normalized:
		return {
			"ok": false,
			"failure_code": "SOLVER_POLICY_RECEIPT_MISMATCH",
			"solver_policy_id": policy_id,
			"world_build_count": 0,
		}
	return {
		"ok": true,
		"failure_code": "",
		"solver_policy_options": normalized.duplicate(true),
		"solver_policy_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
	}


static func compile_seeded_initial_perturbation(campaign_seed: int) -> Dictionary:
	if campaign_seed <= 0:
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_SEED",
			"campaign_seed": campaign_seed,
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = campaign_seed
	return _normalize_initial_perturbation(
		{
			"campaign_seed": campaign_seed,
			"fixture_vertical_clearance_m":
			rng.randf_range(0.0, MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M * 0.50),
			"fixture_yaw_rad":
			rng.randf_range(
				-MAXIMUM_INITIAL_YAW_PERTURBATION_RAD * 0.75,
				MAXIMUM_INITIAL_YAW_PERTURBATION_RAD * 0.75
			),
			"initial_linear_velocity_world_m_s":
			Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004)),
			"initial_torso_angular_velocity_world_rad_s":
			Vector3(
				rng.randf_range(-0.002, 0.002),
				rng.randf_range(-0.004, 0.004),
				rng.randf_range(-0.002, 0.002)
			),
			"gait_phase_offset_ticks":
			rng.randi_range(
				-MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS, MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS
			),
		}
	)


static func _normalize_initial_perturbation(requested: Dictionary) -> Dictionary:
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not INITIAL_PERTURBATION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_INITIAL_PERTURBATION_FIELD",
				"unknown_field": requested_key,
			}
	var campaign_seed := int(requested.get("campaign_seed", 0))
	var vertical_clearance_m := float(requested.get("fixture_vertical_clearance_m", 0.0))
	var fixture_yaw_rad := float(requested.get("fixture_yaw_rad", 0.0))
	var linear_velocity_value: Variant = requested.get(
		"initial_linear_velocity_world_m_s", Vector3.ZERO
	)
	var torso_angular_velocity_value: Variant = requested.get(
		"initial_torso_angular_velocity_world_rad_s", Vector3.ZERO
	)
	var gait_phase_offset_ticks := int(requested.get("gait_phase_offset_ticks", 0))
	if (
		typeof(linear_velocity_value) != TYPE_VECTOR3
		or typeof(torso_angular_velocity_value) != TYPE_VECTOR3
	):
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_VECTOR",
		}
	var linear_velocity: Vector3 = linear_velocity_value
	var torso_angular_velocity: Vector3 = torso_angular_velocity_value
	if campaign_seed < 0:
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_SEED",
			"campaign_seed": campaign_seed,
		}
	if (
		not is_finite(vertical_clearance_m)
		or vertical_clearance_m < 0.0
		or vertical_clearance_m > MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_VERTICAL_CLEARANCE_OUT_OF_BOUNDS",
			"fixture_vertical_clearance_m": vertical_clearance_m,
		}
	if (
		not is_finite(fixture_yaw_rad)
		or absf(fixture_yaw_rad) > MAXIMUM_INITIAL_YAW_PERTURBATION_RAD
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_YAW_PERTURBATION_OUT_OF_BOUNDS",
			"fixture_yaw_rad": fixture_yaw_rad,
		}
	if (
		not linear_velocity.is_finite()
		or absf(linear_velocity.y) > 1.0e-9
		or linear_velocity.length() > MAXIMUM_INITIAL_LINEAR_SPEED_M_S
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_LINEAR_VELOCITY_OUT_OF_BOUNDS",
			"initial_linear_velocity_world_m_s": linear_velocity,
		}
	if (
		not torso_angular_velocity.is_finite()
		or torso_angular_velocity.length() > MAXIMUM_INITIAL_TORSO_ANGULAR_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_TORSO_ANGULAR_VELOCITY_OUT_OF_BOUNDS",
			"initial_torso_angular_velocity_world_rad_s": torso_angular_velocity,
		}
	if absi(gait_phase_offset_ticks) > MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS:
		return {
			"ok": false,
			"failure_code": "INITIAL_GAIT_PHASE_OFFSET_OUT_OF_BOUNDS",
			"gait_phase_offset_ticks": gait_phase_offset_ticks,
		}
	return {
		"ok": true,
		"failure_code": "",
		"initial_perturbation":
		{
			"campaign_seed": campaign_seed,
			"fixture_vertical_clearance_m": vertical_clearance_m,
			"fixture_yaw_rad": fixture_yaw_rad,
			"initial_linear_velocity_world_m_s": linear_velocity,
			"initial_torso_angular_velocity_world_rad_s": torso_angular_velocity,
			"gait_phase_offset_ticks": gait_phase_offset_ticks,
		},
	}


static func compile_environment_challenge_options(requested: Dictionary) -> Dictionary:
	var defaults := {
		"challenge_profile_id": "none_v1",
		"terrain_profile_id": FLAT_TERRAIN_PROFILE_ID,
		"terrain_tile_length_m": 20.0,
		"terrain_tile_count": 1,
		"terrain_origin_x_m": -10.0,
		"terrain_heights_m": [0.0],
		"push_profile_id": NO_PUSH_PROFILE_ID,
		"push_step_from_sdk_start": -1,
		"push_impulse_task_n_s": [0.0, 0.0, 0.0],
		"observation_fault_profile_id": NO_OBSERVATION_FAULT_PROFILE_ID,
		"observation_noise_period_steps": 120,
		"base_position_noise_amplitude_m": 0.0,
		"base_linear_velocity_noise_amplitude_m_s": 0.0,
		"joint_position_noise_amplitude_rad": 0.0,
		"joint_velocity_noise_amplitude_rad_s": 0.0,
		"stability_body_position_noise_amplitude_m": 0.0,
		"stability_body_velocity_noise_amplitude_m_s": 0.0,
		"support_point_noise_amplitude_m": 0.0,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"environment_challenge_options": defaults,
			"environment_challenge_configuration_sha256": CanonicalJsonScript.sha256(defaults),
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ENVIRONMENT_CHALLENGE_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_ENVIRONMENT_CHALLENGE_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in ENVIRONMENT_CHALLENGE_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_ENVIRONMENT_CHALLENGE_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	var profile_id_fields := [
		"challenge_profile_id",
		"terrain_profile_id",
		"push_profile_id",
		"observation_fault_profile_id",
	]
	for profile_id_field in profile_id_fields:
		if typeof(requested[profile_id_field]) != TYPE_STRING:
			return {
				"ok": false,
				"failure_code": "INVALID_ENVIRONMENT_CHALLENGE_PROFILE_ID_TYPE",
				"profile_id_field": profile_id_field,
				"world_build_count": 0,
			}
	var challenge_profile_id := String(requested["challenge_profile_id"])
	var terrain_profile_id := String(requested["terrain_profile_id"])
	var push_profile_id := String(requested["push_profile_id"])
	var observation_fault_profile_id := String(requested["observation_fault_profile_id"])
	if (
		challenge_profile_id.is_empty()
		or not [FLAT_TERRAIN_PROFILE_ID, ROUGH_TERRAIN_PROFILE_ID].has(terrain_profile_id)
		or not [NO_PUSH_PROFILE_ID, LATERAL_PUSH_PROFILE_ID].has(push_profile_id)
		or not (
			[
				NO_OBSERVATION_FAULT_PROFILE_ID,
				DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID,
			]
			. has(observation_fault_profile_id)
		)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_CHALLENGE_PROFILE_ID",
			"world_build_count": 0,
		}
	var tile_length_value: Variant = requested["terrain_tile_length_m"]
	var tile_count_value: Variant = requested["terrain_tile_count"]
	var terrain_origin_x_value: Variant = requested["terrain_origin_x_m"]
	var terrain_heights_value: Variant = requested["terrain_heights_m"]
	if (
		(typeof(tile_length_value) != TYPE_FLOAT and typeof(tile_length_value) != TYPE_INT)
		or (typeof(tile_count_value) != TYPE_FLOAT and typeof(tile_count_value) != TYPE_INT)
		or (
			typeof(terrain_origin_x_value) != TYPE_FLOAT
			and typeof(terrain_origin_x_value) != TYPE_INT
		)
		or typeof(terrain_heights_value) != TYPE_ARRAY
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_GEOMETRY_TYPE",
			"world_build_count": 0,
		}
	var tile_length_m := float(tile_length_value)
	var tile_count := int(tile_count_value)
	var terrain_origin_x_m := float(terrain_origin_x_value)
	if (
		not is_finite(tile_length_m)
		or tile_length_m <= 0.0
		or tile_length_m > 20.0
		or not is_finite(float(tile_count_value))
		or float(tile_count_value) != floorf(float(tile_count_value))
		or tile_count < 1
		or tile_count > 256
		or not is_finite(terrain_origin_x_m)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_GEOMETRY",
			"world_build_count": 0,
		}
	var terrain_heights: Array = terrain_heights_value
	if terrain_heights.is_empty() or terrain_heights.size() > 64:
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_HEIGHT_COUNT",
			"world_build_count": 0,
		}
	var normalized_heights: Array = []
	var distinct_height_tokens := {}
	for height_value in terrain_heights:
		if typeof(height_value) != TYPE_FLOAT and typeof(height_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_ENVIRONMENT_TERRAIN_HEIGHT",
				"world_build_count": 0,
			}
		var height_m := float(height_value)
		if not is_finite(height_m) or absf(height_m) > MAXIMUM_ROUGH_TERRAIN_ABSOLUTE_HEIGHT_M:
			return {
				"ok": false,
				"failure_code": "ENVIRONMENT_TERRAIN_HEIGHT_OUT_OF_BOUNDS",
				"world_build_count": 0,
			}
		normalized_heights.append(height_m)
		distinct_height_tokens[str(height_m)] = true
	if (
		terrain_profile_id == FLAT_TERRAIN_PROFILE_ID
		and (
			tile_count != 1 or normalized_heights.size() != 1 or float(normalized_heights[0]) != 0.0
		)
	):
		return {
			"ok": false,
			"failure_code": "FLAT_TERRAIN_PROFILE_NOT_FLAT",
			"world_build_count": 0,
		}
	if (
		terrain_profile_id == ROUGH_TERRAIN_PROFILE_ID
		and (tile_count < 8 or normalized_heights.size() < 3 or distinct_height_tokens.size() < 3)
	):
		return {
			"ok": false,
			"failure_code": "ROUGH_TERRAIN_PROFILE_NOT_ROUGH",
			"world_build_count": 0,
		}
	var push_step_value: Variant = requested["push_step_from_sdk_start"]
	if typeof(push_step_value) != TYPE_FLOAT and typeof(push_step_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_STEP_TYPE",
			"world_build_count": 0,
		}
	var push_step_float := float(push_step_value)
	if not is_finite(push_step_float) or push_step_float != floorf(push_step_float):
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_STEP",
			"world_build_count": 0,
		}
	var push_step := int(push_step_float)
	var push_value: Variant = requested["push_impulse_task_n_s"]
	if typeof(push_value) != TYPE_ARRAY or (push_value as Array).size() != 3:
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_VECTOR",
			"world_build_count": 0,
		}
	var push_components: Array = []
	for component_value in push_value:
		if typeof(component_value) != TYPE_FLOAT and typeof(component_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_EXTERNAL_PUSH_COMPONENT",
				"world_build_count": 0,
			}
		var component := float(component_value)
		if not is_finite(component):
			return {
				"ok": false,
				"failure_code": "NONFINITE_EXTERNAL_PUSH_COMPONENT",
				"world_build_count": 0,
			}
		push_components.append(component)
	var push_vector := FixtureSpecScript.vector3_from_array(push_components)
	if (
		push_vector.length() > MAXIMUM_EXTERNAL_PUSH_IMPULSE_N_S
		or (
			push_profile_id == NO_PUSH_PROFILE_ID
			and (push_step != -1 or not push_vector.is_zero_approx())
		)
		or (
			push_profile_id == LATERAL_PUSH_PROFILE_ID
			and (
				push_step < 1
				or push_step >= SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT
				or absf(push_vector.x) > 1.0e-12
				or absf(push_vector.y) > 1.0e-12
				or absf(push_vector.z) <= 1.0e-12
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "EXTERNAL_PUSH_PROFILE_MISMATCH",
			"world_build_count": 0,
		}
	var noise_period_value: Variant = requested["observation_noise_period_steps"]
	if typeof(noise_period_value) != TYPE_FLOAT and typeof(noise_period_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_OBSERVATION_NOISE_PERIOD_TYPE",
			"world_build_count": 0,
		}
	var noise_period_float := float(noise_period_value)
	if not is_finite(noise_period_float) or noise_period_float != floorf(noise_period_float):
		return {
			"ok": false,
			"failure_code": "INVALID_OBSERVATION_NOISE_PERIOD",
			"world_build_count": 0,
		}
	var noise_period_steps := int(noise_period_float)
	var amplitude_fields := [
		"base_position_noise_amplitude_m",
		"base_linear_velocity_noise_amplitude_m_s",
		"joint_position_noise_amplitude_rad",
		"joint_velocity_noise_amplitude_rad_s",
		"stability_body_position_noise_amplitude_m",
		"stability_body_velocity_noise_amplitude_m_s",
		"support_point_noise_amplitude_m",
	]
	var amplitude_limits := [
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
		MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S,
		MAXIMUM_OBSERVATION_JOINT_POSITION_NOISE_RAD,
		MAXIMUM_OBSERVATION_JOINT_VELOCITY_NOISE_RAD_S,
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
		MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S,
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
	]
	var normalized_amplitudes := {}
	var nonzero_amplitude_count := 0
	for field_index in range(amplitude_fields.size()):
		var field := String(amplitude_fields[field_index])
		var requested_amplitude: Variant = requested[field]
		if typeof(requested_amplitude) != TYPE_FLOAT and typeof(requested_amplitude) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "OBSERVATION_NOISE_AMPLITUDE_INVALID",
				"amplitude_field": field,
				"world_build_count": 0,
			}
		var value := float(requested_amplitude)
		if not is_finite(value) or value < 0.0 or value > float(amplitude_limits[field_index]):
			return {
				"ok": false,
				"failure_code": "OBSERVATION_NOISE_AMPLITUDE_OUT_OF_BOUNDS",
				"amplitude_field": field,
				"world_build_count": 0,
			}
		normalized_amplitudes[field] = value
		if value > 0.0:
			nonzero_amplitude_count += 1
	if (
		noise_period_steps < 8
		or noise_period_steps > 600
		or (
			observation_fault_profile_id == NO_OBSERVATION_FAULT_PROFILE_ID
			and nonzero_amplitude_count != 0
		)
		or (
			observation_fault_profile_id == DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID
			and nonzero_amplitude_count == 0
		)
	):
		return {
			"ok": false,
			"failure_code": "OBSERVATION_FAULT_PROFILE_MISMATCH",
			"world_build_count": 0,
		}
	var normalized := {
		"challenge_profile_id": challenge_profile_id,
		"terrain_profile_id": terrain_profile_id,
		"terrain_tile_length_m": tile_length_m,
		"terrain_tile_count": tile_count,
		"terrain_origin_x_m": terrain_origin_x_m,
		"terrain_heights_m": normalized_heights,
		"push_profile_id": push_profile_id,
		"push_step_from_sdk_start": push_step,
		"push_impulse_task_n_s": push_components,
		"observation_fault_profile_id": observation_fault_profile_id,
		"observation_noise_period_steps": noise_period_steps,
	}
	for amplitude_field in amplitude_fields:
		normalized[amplitude_field] = float(normalized_amplitudes[amplitude_field])
	return {
		"ok": true,
		"failure_code": "",
		"environment_challenge_options": normalized,
		"environment_challenge_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _normalize_actuator_impulse_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"actuator_impulse_options":
			{
				"mass_adaptive_actuator_enabled": false,
				"actuator_policy_id": "none",
				"actuator_impulse_scale": 1.0,
			},
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ACTUATOR_IMPULSE_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_ACTUATOR_IMPULSE_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in ["mass_adaptive_actuator_enabled", "actuator_policy_id"]:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_ACTUATOR_IMPULSE_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["mass_adaptive_actuator_enabled"]) != TYPE_BOOL
		or not bool(requested["mass_adaptive_actuator_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ACTUATOR_IMPULSE_MODE",
			"world_build_count": 0,
		}
	var actuator_policy_id := String(requested["actuator_policy_id"])
	if actuator_policy_id.is_empty():
		return {
			"ok": false,
			"failure_code": "INVALID_ACTUATOR_POLICY_ID",
			"world_build_count": 0,
		}
	var has_common_scale := requested.has("actuator_impulse_scale")
	var has_hip_scale := requested.has("hip_impulse_scale")
	var has_knee_scale := requested.has("knee_impulse_scale")
	if has_common_scale and (has_hip_scale or has_knee_scale):
		return {
			"ok": false,
			"failure_code": "CONFLICTING_ACTUATOR_IMPULSE_SCALE_MODES",
			"world_build_count": 0,
		}
	if not has_common_scale and not (has_hip_scale and has_knee_scale):
		return {
			"ok": false,
			"failure_code": "MISSING_ACTUATOR_IMPULSE_SCALE_MODE",
			"world_build_count": 0,
		}
	var requested_scale_fields: Array = (
		["actuator_impulse_scale"]
		if has_common_scale
		else ["hip_impulse_scale", "knee_impulse_scale"]
	)
	var normalized_scales := {}
	for scale_field in requested_scale_fields:
		var scale_value: Variant = requested[scale_field]
		if typeof(scale_value) != TYPE_FLOAT and typeof(scale_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_ACTUATOR_IMPULSE_SCALE",
				"scale_field": scale_field,
				"world_build_count": 0,
			}
		var impulse_scale := float(scale_value)
		if (
			not is_finite(impulse_scale)
			or impulse_scale < MINIMUM_ACTUATOR_IMPULSE_SCALE
			or impulse_scale > MAXIMUM_ACTUATOR_IMPULSE_SCALE
		):
			return {
				"ok": false,
				"failure_code": "ACTUATOR_IMPULSE_SCALE_OUT_OF_BOUNDS",
				"scale_field": scale_field,
				"actuator_impulse_scale": impulse_scale,
				"world_build_count": 0,
			}
		normalized_scales[scale_field] = impulse_scale
	if not has_common_scale:
		return {
			"ok": true,
			"failure_code": "",
			"actuator_impulse_options":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": actuator_policy_id,
				"hip_impulse_scale": float(normalized_scales["hip_impulse_scale"]),
				"knee_impulse_scale": float(normalized_scales["knee_impulse_scale"]),
			},
		}
	var actuator_impulse_scale := float(normalized_scales["actuator_impulse_scale"])
	return {
		"ok": true,
		"failure_code": "",
		"actuator_impulse_options":
		{
			"mass_adaptive_actuator_enabled": true,
			"actuator_policy_id": actuator_policy_id,
			"actuator_impulse_scale": actuator_impulse_scale,
		},
	}


static func _normalize_motor_velocity_options(
	requested: Dictionary,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var default_options := {
		"mass_adaptive_motor_velocity_enabled": false,
		"motor_velocity_policy_id": "none",
		"activation_predicate_id": "contact_loaded_swing_knee",
		"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
		MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
		"contact_loaded_swing_knee_activation_start_phase_tick": 0,
		"contact_loaded_swing_knee_full_speed_override_phase_tick": -1,
		"anchor_error_guard_enabled": false,
		"morphology_interaction_score": 0.0,
		"anchor_error_guard_activation_fraction": 0.90,
		"anchor_error_guard_maximum_motor_target_speed_rad_s": MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"motor_velocity_options": default_options,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not MOTOR_VELOCITY_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_MOTOR_VELOCITY_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in REQUIRED_MOTOR_VELOCITY_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_MOTOR_VELOCITY_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["mass_adaptive_motor_velocity_enabled"]) != TYPE_BOOL
		or not bool(requested["mass_adaptive_motor_velocity_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_MODE",
			"world_build_count": 0,
		}
	var policy_id := String(requested["motor_velocity_policy_id"])
	if policy_id.is_empty():
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_POLICY_ID",
			"world_build_count": 0,
		}
	var speed_value: Variant = requested["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
	if typeof(speed_value) != TYPE_FLOAT and typeof(speed_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_TARGET_SPEED",
			"world_build_count": 0,
		}
	var maximum_target_speed_rad_s := float(speed_value)
	if (
		not is_finite(maximum_target_speed_rad_s)
		or maximum_target_speed_rad_s < MINIMUM_MOTOR_TARGET_SPEED_RAD_S
		or maximum_target_speed_rad_s > MAXIMUM_MOTOR_TARGET_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "MOTOR_TARGET_SPEED_OUT_OF_BOUNDS",
			"maximum_motor_target_speed_rad_s": maximum_target_speed_rad_s,
			"world_build_count": 0,
		}
	var activation_start_value: Variant = (
		requested
		. get(
			"contact_loaded_swing_knee_activation_start_phase_tick",
			0,
		)
	)
	if typeof(activation_start_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_ACTIVATION_START_PHASE_TICK",
			"world_build_count": 0,
		}
	var activation_start_phase_tick := int(activation_start_value)
	if activation_start_phase_tick < 0 or activation_start_phase_tick >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "MOTOR_VELOCITY_ACTIVATION_START_PHASE_TICK_OUT_OF_BOUNDS",
			"activation_start_phase_tick": activation_start_phase_tick,
			"world_build_count": 0,
		}
	var full_speed_override_value: Variant = (
		requested
		. get(
			"contact_loaded_swing_knee_full_speed_override_phase_tick",
			-1,
		)
	)
	if typeof(full_speed_override_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_FULL_SPEED_OVERRIDE_PHASE_TICK",
			"world_build_count": 0,
		}
	var full_speed_override_phase_tick := int(full_speed_override_value)
	if full_speed_override_phase_tick < -1 or full_speed_override_phase_tick >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "MOTOR_VELOCITY_FULL_SPEED_OVERRIDE_PHASE_TICK_OUT_OF_BOUNDS",
			"full_speed_override_phase_tick": full_speed_override_phase_tick,
			"world_build_count": 0,
		}
	var anchor_guard_enabled_value: Variant = requested.get("anchor_error_guard_enabled", false)
	if typeof(anchor_guard_enabled_value) != TYPE_BOOL:
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_MODE",
			"world_build_count": 0,
		}
	var anchor_guard_enabled := bool(anchor_guard_enabled_value)
	var morphology_interaction_score_value: Variant = (
		requested
		. get(
			"morphology_interaction_score",
			0.0,
		)
	)
	if (
		typeof(morphology_interaction_score_value) != TYPE_FLOAT
		and typeof(morphology_interaction_score_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MORPHOLOGY_INTERACTION_SCORE",
			"world_build_count": 0,
		}
	var morphology_interaction_score := float(morphology_interaction_score_value)
	if (
		not is_finite(morphology_interaction_score)
		or morphology_interaction_score < 0.0
		or morphology_interaction_score > 1.0
	):
		return {
			"ok": false,
			"failure_code": "MORPHOLOGY_INTERACTION_SCORE_OUT_OF_BOUNDS",
			"morphology_interaction_score": morphology_interaction_score,
			"world_build_count": 0,
		}
	var anchor_guard_fraction_value: Variant = (
		requested
		. get(
			"anchor_error_guard_activation_fraction",
			0.90,
		)
	)
	if (
		typeof(anchor_guard_fraction_value) != TYPE_FLOAT
		and typeof(anchor_guard_fraction_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_ACTIVATION_FRACTION",
			"world_build_count": 0,
		}
	var anchor_guard_activation_fraction := float(anchor_guard_fraction_value)
	if (
		not is_finite(anchor_guard_activation_fraction)
		or anchor_guard_activation_fraction < 0.50
		or anchor_guard_activation_fraction >= 1.0
	):
		return {
			"ok": false,
			"failure_code": "ANCHOR_ERROR_GUARD_ACTIVATION_FRACTION_OUT_OF_BOUNDS",
			"anchor_error_guard_activation_fraction": anchor_guard_activation_fraction,
			"world_build_count": 0,
		}
	var anchor_guard_speed_value: Variant = (
		requested
		. get(
			"anchor_error_guard_maximum_motor_target_speed_rad_s",
			MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
		)
	)
	if (
		typeof(anchor_guard_speed_value) != TYPE_FLOAT
		and typeof(anchor_guard_speed_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_MOTOR_TARGET_SPEED",
			"world_build_count": 0,
		}
	var anchor_guard_maximum_target_speed_rad_s := float(anchor_guard_speed_value)
	if (
		not is_finite(anchor_guard_maximum_target_speed_rad_s)
		or anchor_guard_maximum_target_speed_rad_s < MINIMUM_MOTOR_TARGET_SPEED_RAD_S
		or anchor_guard_maximum_target_speed_rad_s > MAXIMUM_MOTOR_TARGET_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "ANCHOR_ERROR_GUARD_MOTOR_TARGET_SPEED_OUT_OF_BOUNDS",
			"maximum_motor_target_speed_rad_s": anchor_guard_maximum_target_speed_rad_s,
			"world_build_count": 0,
		}
	var activation_predicate_id := (
		"morphology_interaction_anchor_guarded_contact_loaded_swing_knee"
		if anchor_guard_enabled
		else (
			"release_gate_notched_contact_loaded_swing_knee"
			if full_speed_override_phase_tick >= 0
			else (
				"phase_windowed_contact_loaded_swing_knee"
				if activation_start_phase_tick > 0
				else "contact_loaded_swing_knee"
			)
		)
	)
	return {
		"ok": true,
		"failure_code": "",
		"motor_velocity_options":
		{
			"mass_adaptive_motor_velocity_enabled": true,
			"motor_velocity_policy_id": policy_id,
			"activation_predicate_id": activation_predicate_id,
			"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
			maximum_target_speed_rad_s,
			"contact_loaded_swing_knee_activation_start_phase_tick": activation_start_phase_tick,
			"contact_loaded_swing_knee_full_speed_override_phase_tick":
			full_speed_override_phase_tick,
			"anchor_error_guard_enabled": anchor_guard_enabled,
			"morphology_interaction_score": morphology_interaction_score,
			"anchor_error_guard_activation_fraction": anchor_guard_activation_fraction,
			"anchor_error_guard_maximum_motor_target_speed_rad_s":
			anchor_guard_maximum_target_speed_rad_s,
		},
	}


static func _normalize_evidence_threshold_options(requested: Dictionary) -> Dictionary:
	var default_options := {
		"evidence_threshold_policy_id": "reference_metric_thresholds_v1",
		"minimum_foot_relocation_m": MINIMUM_FOOT_RELOCATION_M,
		"minimum_evidence_torso_advance_m": MINIMUM_EVIDENCE_TORSO_ADVANCE_M,
		"minimum_final_torso_advance_m": MINIMUM_FINAL_TORSO_ADVANCE_M,
		"maximum_lateral_drift_m": MAXIMUM_LATERAL_DRIFT_M,
		"maximum_yaw_drift_rad": MAXIMUM_YAW_DRIFT_RAD,
		"maximum_tilt_rad": MAXIMUM_TILT_RAD,
		"minimum_torso_height_m": MINIMUM_TORSO_HEIGHT_M,
		"maximum_anchor_error_m": MAXIMUM_ANCHOR_ERROR_M,
		"maximum_hinge_axis_error_rad": MAXIMUM_HINGE_AXIS_ERROR_RAD,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"evidence_threshold_options": default_options,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not EVIDENCE_THRESHOLD_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_EVIDENCE_THRESHOLD_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in EVIDENCE_THRESHOLD_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_EVIDENCE_THRESHOLD_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if typeof(requested["evidence_threshold_policy_id"]) != TYPE_STRING:
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_THRESHOLD_POLICY_ID",
			"world_build_count": 0,
		}
	var policy_id := String(requested["evidence_threshold_policy_id"])
	if not EVIDENCE_THRESHOLD_POLICY_IDS.has(policy_id):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_EVIDENCE_THRESHOLD_POLICY_ID",
			"evidence_threshold_policy_id": policy_id,
			"world_build_count": 0,
		}
	var normalized := {"evidence_threshold_policy_id": policy_id}
	for key_value in EVIDENCE_THRESHOLD_OPTION_KEYS:
		var key := String(key_value)
		if key == "evidence_threshold_policy_id":
			continue
		var value: Variant = requested[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_EVIDENCE_THRESHOLD_VALUE",
				"threshold_field": key,
				"world_build_count": 0,
			}
		var threshold := float(value)
		if not is_finite(threshold) or threshold <= 0.0:
			return {
				"ok": false,
				"failure_code": "EVIDENCE_THRESHOLD_OUT_OF_BOUNDS",
				"threshold_field": key,
				"threshold_value": threshold,
				"world_build_count": 0,
			}
		normalized[key] = threshold
	return {
		"ok": true,
		"failure_code": "",
		"evidence_threshold_options": normalized,
	}


static func _normalize_path_steering_options(
	requested: Dictionary,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"path_steering_options":
			{
				"phase_bounded_path_steering_enabled": false,
				"cross_track_heading_gain_rad_per_m": 0.0,
				"yaw_error_stride_gain_per_rad": 0.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if (
			not PATH_STEERING_OPTION_KEYS.has(requested_key)
			and not OPTIONAL_PATH_STEERING_OPTION_KEYS.has(requested_key)
		):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_PATH_STEERING_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in PATH_STEERING_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_PATH_STEERING_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["phase_bounded_path_steering_enabled"]) != TYPE_BOOL
		or not bool(requested["phase_bounded_path_steering_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_MODE",
			"world_build_count": 0,
		}
	var numeric_keys := [
		"cross_track_heading_gain_rad_per_m",
		"yaw_error_stride_gain_per_rad",
		"maximum_desired_heading_error_rad",
		"maximum_steering_fraction",
	]
	if requested.has("cross_track_velocity_heading_gain_rad_per_m_s"):
		numeric_keys.append("cross_track_velocity_heading_gain_rad_per_m_s")
	var numeric_values: Dictionary = {}
	for numeric_key in numeric_keys:
		var numeric_value: Variant = requested[numeric_key]
		if typeof(numeric_value) != TYPE_FLOAT and typeof(numeric_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_PATH_STEERING_NUMERIC_FIELD",
				"field": numeric_key,
				"world_build_count": 0,
			}
		var normalized_value: float = float(numeric_value)
		if not is_finite(normalized_value) or normalized_value <= 0.0:
			return {
				"ok": false,
				"failure_code": "INVALID_PATH_STEERING_NUMERIC_FIELD",
				"field": numeric_key,
				"world_build_count": 0,
			}
		numeric_values[numeric_key] = normalized_value
	if (
		float(numeric_values["cross_track_heading_gain_rad_per_m"]) > 4.0
		or float(numeric_values["yaw_error_stride_gain_per_rad"]) > 4.0
		or float(numeric_values["maximum_desired_heading_error_rad"]) > 0.50
		or (
			float(numeric_values["maximum_steering_fraction"])
			> MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
		)
		or (
			numeric_values.has("cross_track_velocity_heading_gain_rad_per_m_s")
			and float(numeric_values["cross_track_velocity_heading_gain_rad_per_m_s"]) > 1.0
		)
	):
		return {
			"ok": false,
			"failure_code": "PATH_STEERING_BOUND_EXCEEDED",
			"world_build_count": 0,
		}
	if typeof(requested["steering_update_interval_ticks"]) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_UPDATE_INTERVAL",
			"world_build_count": 0,
		}
	var update_interval_ticks := int(requested["steering_update_interval_ticks"])
	if (
		update_interval_ticks < 1
		or update_interval_ticks > cycle_ticks
		or cycle_ticks % update_interval_ticks != 0
	):
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_UPDATE_INTERVAL",
			"world_build_count": 0,
		}
	var normalized_options := {
		"phase_bounded_path_steering_enabled": true,
		"cross_track_heading_gain_rad_per_m":
		float(numeric_values["cross_track_heading_gain_rad_per_m"]),
		"yaw_error_stride_gain_per_rad": float(numeric_values["yaw_error_stride_gain_per_rad"]),
		"steering_update_interval_ticks": update_interval_ticks,
		"maximum_desired_heading_error_rad":
		float(numeric_values["maximum_desired_heading_error_rad"]),
		"maximum_steering_fraction": float(numeric_values["maximum_steering_fraction"]),
	}
	if numeric_values.has("cross_track_velocity_heading_gain_rad_per_m_s"):
		normalized_options["cross_track_velocity_heading_gain_rad_per_m_s"] = float(
			numeric_values["cross_track_velocity_heading_gain_rad_per_m_s"]
		)
	return {
		"ok": true,
		"failure_code": "",
		"path_steering_options": normalized_options,
	}


static func compile_sdk_physical_trace_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_physical_trace_options": {"enabled": false},
			"sdk_physical_trace_configuration_sha256": CanonicalJsonScript.sha256(
				{"enabled": false}
			),
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	if typeof(requested.get("policy_id")) == TYPE_STRING:
		var requested_policy_id := String(requested.get("policy_id", ""))
		if _is_qsdk_recovery_trace_policy(requested_policy_id):
			return _compile_qsdk_recovery_trace_options(requested)
	var expected_keys := [
		"cell_id",
		"exact_controller_step_count",
		"policy_id",
		"recovery_duration_steps",
		"turn_duration_steps",
		"turn_heading_offset_rad",
		"turn_start_semantic_step",
	]
	var caller_declared_row_schema := requested.has("trace_row_schema_version")
	if caller_declared_row_schema:
		expected_keys.append("trace_row_schema_version")
	var caller_declared_post_schedule_segment := requested.has("post_schedule_segment_id")
	if caller_declared_post_schedule_segment:
		expected_keys.append("post_schedule_segment_id")
	var caller_declared_actuator_phase_observation := requested.has(
		"actuator_phase_observation_schema_version"
	)
	if caller_declared_actuator_phase_observation:
		expected_keys.append("actuator_phase_observation_schema_version")
	if not _has_exact_keys(requested, expected_keys):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_PHYSICAL_TRACE_OPTION_KEYS",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	if (
		typeof(requested["policy_id"]) != TYPE_STRING
		or typeof(requested["cell_id"]) != TYPE_STRING
		or typeof(requested["exact_controller_step_count"]) != TYPE_INT
		or typeof(requested["turn_start_semantic_step"]) != TYPE_INT
		or typeof(requested["turn_duration_steps"]) != TYPE_INT
		or typeof(requested["recovery_duration_steps"]) != TYPE_INT
		or not [TYPE_FLOAT, TYPE_INT].has(typeof(requested["turn_heading_offset_rad"]))
		or (
			caller_declared_row_schema
			and typeof(requested["trace_row_schema_version"]) != TYPE_STRING
		)
		or (
			caller_declared_post_schedule_segment
			and typeof(requested["post_schedule_segment_id"]) != TYPE_STRING
		)
		or (
			caller_declared_actuator_phase_observation
			and typeof(requested["actuator_phase_observation_schema_version"])
			!= TYPE_STRING
		)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_PHYSICAL_TRACE_OPTION_TYPE",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var exact_controller_step_count := int(requested["exact_controller_step_count"])
	var turn_start_semantic_step := int(requested["turn_start_semantic_step"])
	var turn_duration_steps := int(requested["turn_duration_steps"])
	var recovery_duration_steps := int(requested["recovery_duration_steps"])
	var turn_heading_offset_rad := float(requested["turn_heading_offset_rad"])
	var production_turning_route_ghost := (
		String(requested["policy_id"]) == TURNING_ROUTE_GHOST_TRACE_POLICY_ID
	)
	var declared_schedule_exact := (
		exact_controller_step_count == TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_OBSERVATION_COUNT
		and turn_start_semantic_step == 0
		and turn_duration_steps == TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_OBSERVATION_COUNT
		and recovery_duration_steps == 0
		and turn_heading_offset_rad == 0.2
		if production_turning_route_ghost
		else (
			exact_controller_step_count == QSDK_R23D3_AUTHORITY_HORIZON_OBSERVATION_COUNT
			and [600, 690, 780, 870].has(turn_start_semantic_step)
			and turn_duration_steps == 1200
			and recovery_duration_steps == 600
			and turn_start_semantic_step + turn_duration_steps + recovery_duration_steps
			<= exact_controller_step_count
			and [-0.2, 0.0, 0.2].has(turn_heading_offset_rad)
		)
	)
	if (
		(
			String(requested["policy_id"]) != QSDK_R23D3_PHYSICAL_TRACE_POLICY_ID
			and not production_turning_route_ghost
		)
		or String(requested["cell_id"]).is_empty()
		or not declared_schedule_exact
		or (
			caller_declared_row_schema
			and String(requested["trace_row_schema_version"]).is_empty()
		)
		or (
			caller_declared_post_schedule_segment
			and not ["after_declared_schedule", "reference_continuation"].has(
				String(requested["post_schedule_segment_id"])
			)
		)
		or (
			caller_declared_actuator_phase_observation
			and String(requested["actuator_phase_observation_schema_version"])
			!= SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA
		)
	):
		return {
			"ok": false,
			"failure_code": "SDK_PHYSICAL_TRACE_POLICY_RECEIPT_MISMATCH",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var normalized := requested.duplicate(true)
	normalized["enabled"] = true
	return {
		"ok": true,
		"failure_code": "",
		"sdk_physical_trace_options": normalized,
		"sdk_physical_trace_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _compile_qsdk_recovery_trace_options(requested: Dictionary) -> Dictionary:
	var policy_id := String(requested.get("policy_id", ""))
	var expected_row_schema := _recovery_trace_row_schema(policy_id)
	var expected_minimum_step_count := _recovery_trace_minimum_step_count(policy_id)
	var expected_maximum_step_count := _recovery_trace_maximum_step_count(policy_id)
	var expected_push_marker_step := _recovery_trace_push_marker_step(policy_id)
	var failure_prefix := _recovery_trace_failure_prefix(policy_id)
	var expected_keys := [
		"cell_id",
		"maximum_controller_step_count",
		"minimum_controller_step_count",
		"policy_id",
		"push_marker_semantic_step",
		"sampling_phase",
		"trace_row_schema_version",
	]
	if not _has_exact_keys(requested, expected_keys):
		return _sdk_physical_trace_configuration_failure(
			"INVALID_" + failure_prefix + "_OPTION_KEYS"
		)
	if (
		typeof(requested["cell_id"]) != TYPE_STRING
		or typeof(requested["maximum_controller_step_count"]) != TYPE_INT
		or typeof(requested["minimum_controller_step_count"]) != TYPE_INT
		or typeof(requested["policy_id"]) != TYPE_STRING
		or typeof(requested["push_marker_semantic_step"]) != TYPE_INT
		or typeof(requested["sampling_phase"]) != TYPE_STRING
		or typeof(requested["trace_row_schema_version"]) != TYPE_STRING
	):
		return _sdk_physical_trace_configuration_failure(
			"INVALID_" + failure_prefix + "_OPTION_TYPE"
		)
	if (
		String(requested["cell_id"]).is_empty()
		or expected_row_schema.is_empty()
		or (
			int(requested["minimum_controller_step_count"])
			!= expected_minimum_step_count
		)
		or (
			int(requested["maximum_controller_step_count"])
			!= expected_maximum_step_count
		)
		or int(requested["push_marker_semantic_step"]) != expected_push_marker_step
		or String(requested["sampling_phase"]) != "post_physics_for_applied_semantic_step"
		or String(requested["trace_row_schema_version"]) != expected_row_schema
	):
		return _sdk_physical_trace_configuration_failure(
			failure_prefix + "_POLICY_RECEIPT_MISMATCH"
		)
	var normalized := requested.duplicate(true)
	normalized["enabled"] = true
	return {
		"ok": true,
		"failure_code": "",
		"sdk_physical_trace_options": normalized,
		"sdk_physical_trace_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _is_qsdk_recovery_trace_policy(policy_id: String) -> bool:
	return policy_id in [
		QSDK_R10B_RECOVERY_TRACE_POLICY_ID,
		QSDK_R10D_RECOVERY_TRACE_POLICY_ID,
		QSDK_R10E_RECOVERY_TRACE_POLICY_ID,
	]


static func _recovery_trace_row_schema(policy_id: String) -> String:
	if policy_id == QSDK_R10B_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10B_RECOVERY_TRACE_ROW_SCHEMA
	if policy_id == QSDK_R10D_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10D_RECOVERY_TRACE_ROW_SCHEMA
	if policy_id == QSDK_R10E_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10E_RECOVERY_TRACE_ROW_SCHEMA
	return ""


static func _recovery_trace_minimum_step_count(policy_id: String) -> int:
	if policy_id == QSDK_R10B_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10B_MINIMUM_CONTROLLER_STEP_COUNT
	if policy_id == QSDK_R10D_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10D_MINIMUM_CONTROLLER_STEP_COUNT
	if policy_id == QSDK_R10E_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10E_MINIMUM_CONTROLLER_STEP_COUNT
	return -1


static func _recovery_trace_maximum_step_count(policy_id: String) -> int:
	if policy_id == QSDK_R10B_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10B_MAXIMUM_CONTROLLER_STEP_COUNT
	if policy_id == QSDK_R10D_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10D_MAXIMUM_CONTROLLER_STEP_COUNT
	if policy_id == QSDK_R10E_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10E_MAXIMUM_CONTROLLER_STEP_COUNT
	return -1


static func _recovery_trace_push_marker_step(policy_id: String) -> int:
	if policy_id == QSDK_R10B_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10B_PUSH_MARKER_SEMANTIC_STEP
	if policy_id == QSDK_R10D_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10D_PUSH_MARKER_SEMANTIC_STEP
	if policy_id == QSDK_R10E_RECOVERY_TRACE_POLICY_ID:
		return QSDK_R10E_PUSH_MARKER_SEMANTIC_STEP
	return -1


static func _recovery_trace_failure_prefix(policy_id: String) -> String:
	if policy_id == QSDK_R10B_RECOVERY_TRACE_POLICY_ID:
		return "QSDK_R10B_RECOVERY_TRACE"
	if policy_id == QSDK_R10D_RECOVERY_TRACE_POLICY_ID:
		return "QSDK_R10D_RECOVERY_TRACE"
	if policy_id == QSDK_R10E_RECOVERY_TRACE_POLICY_ID:
		return "QSDK_R10E_RECOVERY_TRACE"
	return "QSDK_RECOVERY_TRACE"


static func _recovery_trace_failure_prefix_for_row_schema(row_schema: String) -> String:
	if row_schema == QSDK_R10B_RECOVERY_TRACE_ROW_SCHEMA:
		return "QSDK_R10B_RECOVERY_TRACE"
	if row_schema == QSDK_R10D_RECOVERY_TRACE_ROW_SCHEMA:
		return "QSDK_R10D_RECOVERY_TRACE"
	if row_schema == QSDK_R10E_RECOVERY_TRACE_ROW_SCHEMA:
		return "QSDK_R10E_RECOVERY_TRACE"
	return ""


static func _sdk_physical_trace_configuration_failure(failure_code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func compile_sdk_terminal_restoration_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		var disabled := {"enabled": false}
		return {
			"ok": true,
			"failure_code": "",
			"sdk_terminal_restoration_options": disabled,
			"sdk_terminal_restoration_configuration_sha256": (
				CanonicalJsonScript.sha256(disabled)
			),
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	if requested.has("terminal_taper_policy_id"):
		return _compile_sdk_quiescent_taper_options(requested)
	if requested.has("terminal_handoff_policy_id"):
		return _compile_sdk_support_handoff_options(requested)
	var expected_keys := [
		"cell_id",
		"controller_step_count",
		"passive_settle_step_count",
		"restoration_step_count",
		"terminal_restoration_policy_id",
		"total_traced_step_count",
		"trace_row_schema_version",
		"trace_schema_version",
		"turn_heading_offset_rad",
	]
	if not _has_exact_keys(requested, expected_keys):
		return _sdk_terminal_configuration_failure(
			"INVALID_SDK_TERMINAL_RESTORATION_OPTION_KEYS"
		)
	if (
		typeof(requested["cell_id"]) != TYPE_STRING
		or typeof(requested["controller_step_count"]) != TYPE_INT
		or typeof(requested["restoration_step_count"]) != TYPE_INT
		or typeof(requested["passive_settle_step_count"]) != TYPE_INT
		or typeof(requested["total_traced_step_count"]) != TYPE_INT
		or typeof(requested["terminal_restoration_policy_id"]) != TYPE_STRING
		or typeof(requested["trace_schema_version"]) != TYPE_STRING
		or typeof(requested["trace_row_schema_version"]) != TYPE_STRING
		or not [TYPE_FLOAT, TYPE_INT].has(typeof(requested["turn_heading_offset_rad"]))
	):
		return _sdk_terminal_configuration_failure(
			"INVALID_SDK_TERMINAL_RESTORATION_OPTION_TYPE"
		)
	if (
		String(requested["cell_id"]).is_empty()
		or int(requested["controller_step_count"]) != QSDK_R23D4_CONTROLLER_STEP_COUNT
		or int(requested["restoration_step_count"]) != QSDK_R23D4_RESTORATION_STEP_COUNT
		or int(requested["passive_settle_step_count"])
		!= QSDK_R23D4_PASSIVE_SETTLE_STEP_COUNT
		or int(requested["total_traced_step_count"]) != QSDK_R23D4_TOTAL_TRACE_STEP_COUNT
		or not [-0.2, 0.0, 0.2].has(float(requested["turn_heading_offset_rad"]))
	):
		return _sdk_terminal_configuration_failure(
			"SDK_TERMINAL_RESTORATION_POLICY_RECEIPT_MISMATCH"
		)
	var policy_id := String(requested["terminal_restoration_policy_id"])
	var trace_schema := String(requested["trace_schema_version"])
	var trace_row_schema := String(requested["trace_row_schema_version"])
	var predecessor_identity := (
		policy_id == SdkGodotJoltTerminalRestorationScript.POLICY_ID
		and trace_schema == QSDK_R23D4_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D4_TRACE_ROW_SCHEMA
	)
	var neutral_stance_r23d7_identity := (
		policy_id == SdkGodotJoltNeutralStanceScript.POLICY_ID
		and trace_schema == "sporespore_qsdk_r23d7_turn_neutral_stance_settle_trace_v1"
		and trace_row_schema
		== "sporespore_qsdk_r23d7_turn_neutral_stance_settle_trace_row_v1"
	)
	var neutral_stance_r23d8_identity := (
		policy_id == SdkGodotJoltNeutralStanceScript.POLICY_ID
		and trace_schema == "sporespore_qsdk_r23d8_turn_neutral_stance_settle_trace_v1"
		and trace_row_schema
		== "sporespore_qsdk_r23d8_turn_neutral_stance_settle_trace_row_v1"
	)
	if (
		not predecessor_identity
		and not neutral_stance_r23d7_identity
		and not neutral_stance_r23d8_identity
	):
		return _sdk_terminal_configuration_failure(
			"SDK_TERMINAL_RESTORATION_POLICY_RECEIPT_MISMATCH"
		)
	var normalized := requested.duplicate(true)
	normalized["enabled"] = true
	return {
		"ok": true,
		"failure_code": "",
		"sdk_terminal_restoration_options": normalized,
		"sdk_terminal_restoration_configuration_sha256": (
			CanonicalJsonScript.sha256(normalized)
		),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _normalize_sdk_terminal_handoff_reason(value: Variant) -> Dictionary:
	if value == null:
		return {
			"ok": true,
			"failure_code": "",
			"value": "",
		}
	if typeof(value) != TYPE_STRING:
		return {
			"ok": false,
			"failure_code": "SDK_TERMINAL_HANDOFF_REASON_TYPE_INVALID",
			"value": "",
		}
	return {
		"ok": true,
		"failure_code": "",
		"value": String(value),
	}


static func run_sdk_terminal_handoff_reason_canary() -> Dictionary:
	var active_state := _normalize_sdk_terminal_handoff_reason(null)
	var passive_state := _normalize_sdk_terminal_handoff_reason(
		"support_pose_quiescence_confirmed"
	)
	var invalid_state := _normalize_sdk_terminal_handoff_reason(17)
	var exact := (
		bool(active_state.get("ok", false))
		and String(active_state.get("value", "not-empty")).is_empty()
		and bool(passive_state.get("ok", false))
		and String(passive_state.get("value", ""))
		== "support_pose_quiescence_confirmed"
		and not bool(invalid_state.get("ok", true))
		and String(invalid_state.get("failure_code", ""))
		== "SDK_TERMINAL_HANDOFF_REASON_TYPE_INVALID"
	)
	return {
		"schema_version": "sporespore_sdk_terminal_handoff_reason_canary_v1",
		"ok": exact,
		"failure_code": "" if exact else "SDK_TERMINAL_HANDOFF_REASON_CANARY_FAILED",
		"valid_canary_count": 2,
		"mutation_control_count": 1,
		"nullable_active_state_preserved": true,
		"confirmed_passive_reason_preserved": true,
		"non_string_reason_refused": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _compile_sdk_quiescent_taper_options(requested: Dictionary) -> Dictionary:
	var expected_keys := [
		"cell_id",
		"controller_step_count",
		"maximum_active_neutral_acquisition_step_count",
		"minimum_post_handoff_zero_actuation_step_count",
		"minimum_quiescent_taper_step_count",
		"terminal_restoration_policy_id",
		"terminal_step_count",
		"terminal_taper_policy_id",
		"total_traced_step_count",
		"trace_row_schema_version",
		"trace_schema_version",
		"turn_heading_offset_rad",
	]
	var residual_pose_authority_requested := requested.has(
		"residual_pose_authority_policy_id"
	)
	if residual_pose_authority_requested:
		expected_keys.append("residual_pose_authority_policy_id")
	if not _has_exact_keys(requested, expected_keys):
		return _sdk_terminal_configuration_failure(
			"INVALID_SDK_QUIESCENT_TAPER_OPTION_KEYS"
		)
	for field in [
		"controller_step_count",
		"maximum_active_neutral_acquisition_step_count",
		"minimum_post_handoff_zero_actuation_step_count",
		"minimum_quiescent_taper_step_count",
		"terminal_step_count",
		"total_traced_step_count",
	]:
		if typeof(requested[field]) != TYPE_INT:
			return _sdk_terminal_configuration_failure(
				"INVALID_SDK_QUIESCENT_TAPER_OPTION_TYPE"
			)
	var taper_policy_id := String(requested.get("terminal_taper_policy_id", ""))
	var trace_schema := String(requested.get("trace_schema_version", ""))
	var trace_row_schema := String(requested.get("trace_row_schema_version", ""))
	var r23d10_identity := (
		taper_policy_id == QSDK_R23D10_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D10_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D10_TRACE_ROW_SCHEMA
	)
	var r23d11_identity := (
		taper_policy_id == QSDK_R23D11_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D11_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D11_TRACE_ROW_SCHEMA
	)
	var r23d12_identity := (
		taper_policy_id == QSDK_R23D11_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D12_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D12_TRACE_ROW_SCHEMA
	)
	var r23d13_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D11_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D13_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D13_TRACE_ROW_SCHEMA
	)
	var r23d14_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D14_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D14_TRACE_ROW_SCHEMA
	)
	var r23d15_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D15_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D15_TRACE_ROW_SCHEMA
	)
	var r23d16_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D16_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D16_TRACE_ROW_SCHEMA
	)
	var r23d17_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D17_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D17_TRACE_ROW_SCHEMA
	)
	var r23d18_identity := (
		residual_pose_authority_requested
		and String(requested.get("residual_pose_authority_policy_id", ""))
		== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D18_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D18_TRACE_ROW_SCHEMA
	)
	var r23d19_identity := (
		residual_pose_authority_requested
		and (
			String(requested.get("residual_pose_authority_policy_id", ""))
			== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		)
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D19_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D19_TRACE_ROW_SCHEMA
	)
	var r23d20_identity := (
		residual_pose_authority_requested
		and (
			String(requested.get("residual_pose_authority_policy_id", ""))
			== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		)
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D20_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D20_TRACE_ROW_SCHEMA
	)
	var r23d21_identity := (
		residual_pose_authority_requested
		and (
			String(requested.get("residual_pose_authority_policy_id", ""))
			== SdkGodotJoltR23D13ResidualPoseAuthorityScript.POLICY_ID
		)
		and taper_policy_id == QSDK_R23D14_TAPER_POLICY_ID
		and trace_schema == QSDK_R23D21_TRACE_SCHEMA
		and trace_row_schema == QSDK_R23D21_TRACE_ROW_SCHEMA
	)
	var expected_terminal_steps := (
		QSDK_R23D14_TERMINAL_STEP_COUNT
		if (
			r23d14_identity
			or r23d15_identity
			or r23d16_identity
			or r23d17_identity
			or r23d18_identity
			or r23d19_identity
			or r23d20_identity
			or r23d21_identity
		)
		else QSDK_R23D10_TERMINAL_STEP_COUNT
	)
	var expected_maximum_active_steps := (
		QSDK_R23D14_MAXIMUM_ACTIVE_STEP_COUNT
		if (
			r23d14_identity
			or r23d15_identity
			or r23d16_identity
			or r23d17_identity
			or r23d18_identity
			or r23d19_identity
			or r23d20_identity
			or r23d21_identity
		)
		else QSDK_R23D10_MAXIMUM_ACTIVE_STEP_COUNT
	)
	var expected_total_trace_steps := (
		QSDK_R23D14_TOTAL_TRACE_STEP_COUNT
		if (
			r23d14_identity
			or r23d15_identity
			or r23d16_identity
			or r23d17_identity
			or r23d18_identity
			or r23d19_identity
			or r23d20_identity
			or r23d21_identity
		)
		else QSDK_R23D10_TOTAL_TRACE_STEP_COUNT
	)
	var exact := (
		typeof(requested["cell_id"]) == TYPE_STRING
		and not String(requested["cell_id"]).is_empty()
		and typeof(requested["terminal_taper_policy_id"]) == TYPE_STRING
		and typeof(requested["terminal_restoration_policy_id"]) == TYPE_STRING
		and String(requested["terminal_restoration_policy_id"])
		== SdkGodotJoltNeutralStanceScript.POLICY_ID
		and typeof(requested["trace_schema_version"]) == TYPE_STRING
		and typeof(requested["trace_row_schema_version"]) == TYPE_STRING
		and (
			r23d10_identity
			or r23d11_identity
			or r23d12_identity
			or r23d13_identity
			or r23d14_identity
			or r23d15_identity
			or r23d16_identity
			or r23d17_identity
			or r23d18_identity
			or r23d19_identity
			or r23d20_identity
			or r23d21_identity
		)
		and [TYPE_FLOAT, TYPE_INT].has(typeof(requested["turn_heading_offset_rad"]))
		and [-0.2, 0.0, 0.2].has(float(requested["turn_heading_offset_rad"]))
		and int(requested["controller_step_count"]) == QSDK_R23D4_CONTROLLER_STEP_COUNT
		and int(requested["terminal_step_count"]) == expected_terminal_steps
		and int(requested["maximum_active_neutral_acquisition_step_count"])
		== expected_maximum_active_steps
		and int(requested["minimum_quiescent_taper_step_count"])
		== QSDK_R23D10_MINIMUM_TAPER_STEP_COUNT
		and int(requested["minimum_post_handoff_zero_actuation_step_count"])
		== QSDK_R23D10_MINIMUM_PASSIVE_STEP_COUNT
		and int(requested["total_traced_step_count"]) == expected_total_trace_steps
	)
	if not exact:
		return _sdk_terminal_configuration_failure(
			"SDK_QUIESCENT_TAPER_POLICY_RECEIPT_MISMATCH"
		)
	var normalized := requested.duplicate(true)
	normalized["enabled"] = true
	normalized["support_confirmed_handoff_enabled"] = true
	normalized["quiescent_taper_enabled"] = true
	if (
		r23d11_identity
		or r23d12_identity
		or r23d13_identity
		or r23d14_identity
		or r23d15_identity
		or r23d16_identity
		or r23d17_identity
		or r23d18_identity
		or r23d19_identity
		or r23d20_identity
		or r23d21_identity
	):
		normalized["stability_assisted_taper_enabled"] = true
	if (
		r23d13_identity
		or r23d14_identity
		or r23d15_identity
		or r23d16_identity
		or r23d17_identity
		or r23d18_identity
		or r23d19_identity
		or r23d20_identity
		or r23d21_identity
	):
		normalized["residual_pose_authority_enabled"] = true
	if (
		r23d14_identity
		or r23d15_identity
		or r23d16_identity
		or r23d17_identity
		or r23d18_identity
		or r23d19_identity
		or r23d20_identity
		or r23d21_identity
	):
		normalized["tight_gated_horizon_enabled"] = true
	return {
		"ok": true,
		"failure_code": "",
		"sdk_terminal_restoration_options": normalized,
		"sdk_terminal_restoration_configuration_sha256": (
			CanonicalJsonScript.sha256(normalized)
		),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _compile_sdk_support_handoff_options(requested: Dictionary) -> Dictionary:
	var expected_keys := [
		"cell_id",
		"controller_step_count",
		"maximum_active_neutral_acquisition_step_count",
		"minimum_post_handoff_zero_actuation_step_count",
		"support_confirmation_step_count",
		"terminal_handoff_policy_id",
		"terminal_restoration_policy_id",
		"terminal_step_count",
		"total_traced_step_count",
		"trace_row_schema_version",
		"trace_schema_version",
		"turn_heading_offset_rad",
	]
	if not _has_exact_keys(requested, expected_keys):
		return _sdk_terminal_configuration_failure(
			"INVALID_SDK_SUPPORT_HANDOFF_OPTION_KEYS"
		)
	for field in [
		"controller_step_count",
		"maximum_active_neutral_acquisition_step_count",
		"minimum_post_handoff_zero_actuation_step_count",
		"support_confirmation_step_count",
		"terminal_step_count",
		"total_traced_step_count",
	]:
		if typeof(requested[field]) != TYPE_INT:
			return _sdk_terminal_configuration_failure(
				"INVALID_SDK_SUPPORT_HANDOFF_OPTION_TYPE"
			)
	var exact := (
		typeof(requested["cell_id"]) == TYPE_STRING
		and not String(requested["cell_id"]).is_empty()
		and typeof(requested["terminal_handoff_policy_id"]) == TYPE_STRING
		and String(requested["terminal_handoff_policy_id"]) == QSDK_R23D9_HANDOFF_POLICY_ID
		and typeof(requested["terminal_restoration_policy_id"]) == TYPE_STRING
		and String(requested["terminal_restoration_policy_id"])
		== SdkGodotJoltNeutralStanceScript.POLICY_ID
		and typeof(requested["trace_schema_version"]) == TYPE_STRING
		and String(requested["trace_schema_version"]) == QSDK_R23D9_TRACE_SCHEMA
		and typeof(requested["trace_row_schema_version"]) == TYPE_STRING
		and String(requested["trace_row_schema_version"]) == QSDK_R23D9_TRACE_ROW_SCHEMA
		and [TYPE_FLOAT, TYPE_INT].has(typeof(requested["turn_heading_offset_rad"]))
		and [-0.2, 0.0, 0.2].has(float(requested["turn_heading_offset_rad"]))
		and int(requested["controller_step_count"]) == QSDK_R23D4_CONTROLLER_STEP_COUNT
		and int(requested["terminal_step_count"]) == QSDK_R23D9_TERMINAL_STEP_COUNT
		and int(requested["maximum_active_neutral_acquisition_step_count"])
		== QSDK_R23D9_MAXIMUM_ACTIVE_STEP_COUNT
		and int(requested["support_confirmation_step_count"])
		== QSDK_R23D9_SUPPORT_CONFIRMATION_STEP_COUNT
		and int(requested["minimum_post_handoff_zero_actuation_step_count"])
		== QSDK_R23D9_MINIMUM_PASSIVE_STEP_COUNT
		and int(requested["total_traced_step_count"]) == QSDK_R23D9_TOTAL_TRACE_STEP_COUNT
	)
	if not exact:
		return _sdk_terminal_configuration_failure(
			"SDK_SUPPORT_HANDOFF_POLICY_RECEIPT_MISMATCH"
		)
	var normalized := requested.duplicate(true)
	normalized["enabled"] = true
	normalized["support_confirmed_handoff_enabled"] = true
	return {
		"ok": true,
		"failure_code": "",
		"sdk_terminal_restoration_options": normalized,
		"sdk_terminal_restoration_configuration_sha256": (
			CanonicalJsonScript.sha256(normalized)
		),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _sdk_terminal_configuration_failure(failure_code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": failure_code,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func compile_candidate_authority_horizon_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"candidate_authority_horizon_options": {"enabled": false},
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var expected_keys := [
		"candidate_specific_horizon_extension_count",
		"exact_candidate_authority_observation_count",
		"first_candidate_authority_observation_index",
		"last_candidate_authority_observation_index",
		"policy_id",
		"policy_sha256",
	]
	if not _has_exact_keys(requested, expected_keys):
		return {
			"ok": false,
			"failure_code": "INVALID_CANDIDATE_AUTHORITY_HORIZON_OPTION_KEYS",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	if (
		typeof(requested["policy_id"]) != TYPE_STRING
		or typeof(requested["policy_sha256"]) != TYPE_STRING
		or typeof(requested["exact_candidate_authority_observation_count"]) != TYPE_INT
		or typeof(requested["first_candidate_authority_observation_index"]) != TYPE_INT
		or typeof(requested["last_candidate_authority_observation_index"]) != TYPE_INT
		or typeof(requested["candidate_specific_horizon_extension_count"]) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_CANDIDATE_AUTHORITY_HORIZON_OPTION_TYPE",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var policy_id := String(requested["policy_id"])
	var policy_sha256 := String(requested["policy_sha256"])
	var expected_observation_count := -1
	var policy_identity_exact := false
	if policy_id == BW31N_AUTHORITY_HORIZON_POLICY_ID:
		expected_observation_count = BW31N_AUTHORITY_HORIZON_OBSERVATION_COUNT
		policy_identity_exact = FIXED_AUTHORITY_HORIZON_POLICY_SHA256_VALUES.has(policy_sha256)
	elif policy_id == QSDK_R23D3_AUTHORITY_HORIZON_POLICY_ID:
		expected_observation_count = QSDK_R23D3_AUTHORITY_HORIZON_OBSERVATION_COUNT
		policy_identity_exact = policy_sha256 == QSDK_R23D3_AUTHORITY_HORIZON_POLICY_SHA256
	elif policy_id == QSDK_R23D4_AUTHORITY_HORIZON_POLICY_ID:
		expected_observation_count = QSDK_R23D4_CONTROLLER_STEP_COUNT
		policy_identity_exact = policy_sha256 == QSDK_R23D4_AUTHORITY_HORIZON_POLICY_SHA256
	elif policy_id == TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_POLICY_ID:
		expected_observation_count = TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_OBSERVATION_COUNT
		policy_identity_exact = (
			policy_sha256 == TURNING_ROUTE_GHOST_AUTHORITY_HORIZON_POLICY_SHA256
		)
	if (
		not policy_identity_exact
		or int(requested["exact_candidate_authority_observation_count"])
		!= expected_observation_count
		or int(requested["first_candidate_authority_observation_index"]) != 0
		or int(requested["last_candidate_authority_observation_index"])
		!= expected_observation_count - 1
		or int(requested["candidate_specific_horizon_extension_count"]) != 0
	):
		return {
			"ok": false,
			"failure_code": "CANDIDATE_AUTHORITY_HORIZON_POLICY_RECEIPT_MISMATCH",
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	return {
		"ok": true,
		"failure_code": "",
		"candidate_authority_horizon_options": {
			"enabled": true,
			"policy_id": policy_id,
			"policy_sha256": policy_sha256,
			"exact_candidate_authority_observation_count": (
				expected_observation_count
			),
			"first_candidate_authority_observation_index": 0,
			"last_candidate_authority_observation_index": (
				expected_observation_count - 1
			),
			"candidate_specific_horizon_extension_count": 0,
		},
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func compile_evidence_acquisition_options(
	requested: Dictionary,
	maximum_contact_gated_phase_skew_ticks: int = 12,
	minimum_airborne_dwell_ticks: int = 3,
) -> Dictionary:
	var source := (
		{
			"policy_id": LEGACY_EVIDENCE_ACQUISITION_POLICY_ID,
			"enabled": false,
			"maximum_acquisition_ticks": 0,
			"minimum_all_support_dwell_ticks": 1,
		}
		if requested.is_empty()
		else requested.duplicate(true)
	)
	if not _has_exact_keys(source, EVIDENCE_ACQUISITION_OPTION_KEYS):
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_ACQUISITION_OPTION_KEYS",
			"world_build_count": 0,
		}
	if (
		typeof(source["policy_id"]) != TYPE_STRING
		or typeof(source["enabled"]) != TYPE_BOOL
		or typeof(source["maximum_acquisition_ticks"]) != TYPE_INT
		or typeof(source["minimum_all_support_dwell_ticks"]) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_ACQUISITION_OPTION_TYPE",
			"world_build_count": 0,
		}
	var policy_id := String(source["policy_id"])
	var enabled := bool(source["enabled"])
	var maximum_acquisition_ticks := int(source["maximum_acquisition_ticks"])
	var minimum_all_support_dwell_ticks := int(source["minimum_all_support_dwell_ticks"])
	var exact_legacy := (
		policy_id == LEGACY_EVIDENCE_ACQUISITION_POLICY_ID
		and not enabled
		and maximum_acquisition_ticks == 0
		and minimum_all_support_dwell_ticks == 1
	)
	var exact_bounded := (
		policy_id == BOUNDED_EVIDENCE_ACQUISITION_POLICY_ID
		and enabled
		and maximum_contact_gated_phase_skew_ticks >= 0
		and minimum_airborne_dwell_ticks >= 1
		and minimum_all_support_dwell_ticks == minimum_airborne_dwell_ticks
		and (
			maximum_acquisition_ticks
			== maximum_contact_gated_phase_skew_ticks + minimum_airborne_dwell_ticks
		)
	)
	if not exact_legacy and not exact_bounded:
		return {
			"ok": false,
			"failure_code": "EVIDENCE_ACQUISITION_POLICY_RECEIPT_MISMATCH",
			"world_build_count": 0,
		}
	var normalized := {
		"policy_id": policy_id,
		"enabled": enabled,
		"maximum_acquisition_ticks": maximum_acquisition_ticks,
		"minimum_all_support_dwell_ticks": minimum_all_support_dwell_ticks,
	}
	return {
		"ok": true,
		"failure_code": "",
		"evidence_acquisition_options": normalized,
		"evidence_acquisition_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"derivation":
		(
			"legacy exact-boundary assertion"
			if exact_legacy
			else "maximum phase skew plus minimum airborne dwell"
		),
		"world_build_count": 0,
	}


static func _normalize_robustness_options(requested: Dictionary) -> Dictionary:
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ROBUSTNESS_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_WALKING_ROBUSTNESS_OPTION",
				"unknown_field": requested_key,
			}
	var contact_gating_value: Variant = requested.get("contact_gated_phase_progression", false)
	if typeof(contact_gating_value) != TYPE_BOOL:
		return {
			"ok": false,
			"failure_code": "INVALID_CONTACT_GATING_MODE",
		}
	var maximum_hold_ticks := int(
		requested.get("maximum_contact_gate_hold_ticks", DEFAULT_MAXIMUM_CONTACT_GATE_HOLD_TICKS)
	)
	if maximum_hold_ticks < 1 or maximum_hold_ticks > MAXIMUM_CONTACT_GATE_HOLD_LIMIT_TICKS:
		return {
			"ok": false,
			"failure_code": "INVALID_MAXIMUM_CONTACT_GATE_HOLD_TICKS",
			"maximum_contact_gate_hold_ticks": maximum_hold_ticks,
		}
	var maximum_phase_skew_ticks := int(
		requested.get(
			"maximum_contact_gated_phase_skew_ticks", DEFAULT_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS
		)
	)
	if (
		maximum_phase_skew_ticks < 0
		or maximum_phase_skew_ticks > MAXIMUM_CONTACT_GATED_PHASE_SKEW_LIMIT_TICKS
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS",
			"maximum_contact_gated_phase_skew_ticks": maximum_phase_skew_ticks,
		}
	var lateral_steering_gain_value: Variant = requested.get(
		"lateral_stride_steering_gain_per_m", DEFAULT_LATERAL_STRIDE_STEERING_GAIN_PER_M
	)
	if (
		typeof(lateral_steering_gain_value) != TYPE_FLOAT
		and typeof(lateral_steering_gain_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_LATERAL_STRIDE_STEERING_GAIN",
		}
	var lateral_steering_gain_per_m := float(lateral_steering_gain_value)
	if (
		not is_finite(lateral_steering_gain_per_m)
		or lateral_steering_gain_per_m < 0.0
		or lateral_steering_gain_per_m > MAXIMUM_LATERAL_STRIDE_STEERING_GAIN_PER_M
	):
		return {
			"ok": false,
			"failure_code": "INVALID_LATERAL_STRIDE_STEERING_GAIN",
			"lateral_stride_steering_gain_per_m": lateral_steering_gain_per_m,
		}
	return {
		"ok": true,
		"failure_code": "",
		"robustness_options":
		{
			"contact_gated_phase_progression": bool(contact_gating_value),
			"maximum_contact_gate_hold_ticks": maximum_hold_ticks,
			"maximum_contact_gated_phase_skew_ticks": maximum_phase_skew_ticks,
			"lateral_stride_steering_gain_per_m": lateral_steering_gain_per_m,
		},
	}


static func _contact_gated_limb_phase_receipt(
	limb: Dictionary,
	floor: StaticBody3D,
	phase_index: int,
	gait_tick: int,
	swing_ticks: int,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var release_gate_phase_tick := (swing_ticks * 3) / 4
	var recontact_gate_phase_tick := swing_ticks + (cycle_ticks - swing_ticks) / 4
	var phase_offset_ticks := phase_index * (cycle_ticks / LIMB_ORDER.size())
	var local_phase_tick := posmod(gait_tick - phase_offset_ticks, cycle_ticks)
	if local_phase_tick == release_gate_phase_tick:
		return {
			"gate_active": true,
			"contact_satisfied": not _foot_bears_floor(limb, floor),
			"hold_reason": "await_release",
			"limb_id": String(limb["limb_id"]),
			"local_phase_tick": local_phase_tick,
		}
	if local_phase_tick == recontact_gate_phase_tick:
		return {
			"gate_active": true,
			"contact_satisfied": _foot_bears_floor(limb, floor),
			"hold_reason": "await_recontact",
			"limb_id": String(limb["limb_id"]),
			"local_phase_tick": local_phase_tick,
		}
	return {
		"gate_active": false,
		"contact_satisfied": false,
		"hold_reason": "",
		"limb_id": "",
		"local_phase_tick": -1,
	}


static func _sum_dictionary_integers(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


static func _all_dictionary_values_true(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for value in values.values():
		if not bool(value):
			return false
	return true


static func _minimum_dictionary_difference(current: Dictionary, initial: Dictionary) -> int:
	var minimum_difference := 0x7FFFFFFF
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		minimum_difference = mini(minimum_difference, int(current[limb_id]) - int(initial[limb_id]))
	return minimum_difference


static func _minimum_dictionary_integer(values: Dictionary) -> int:
	var minimum_value := 0x7FFFFFFF
	for value in values.values():
		minimum_value = mini(minimum_value, int(value))
	return minimum_value


## Executes the exact live-fixture cap-binding policy selected by normalized
## SDK authority options and projects the authoritative per-actuator caps used
## by the adapter's configured-readback check. This helper is shared by the
## physical route and R23D58's zero-world production-route gate.
static func bind_sdk_live_fixture_actuator_cap_route(
	compiled_morphology_boundary: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	policy_id: String,
	profile_id: String = "",
	descriptor: Dictionary = {},
) -> Dictionary:
	var failure := {
		"ok": false,
		"failure_code": "LIVE_FIXTURE_CAP_ROUTE_INPUT_INVALID",
		"binding_receipt": {
			"ok": false,
			"failure_code": "LIVE_FIXTURE_CAP_ROUTE_INPUT_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		},
		"actuator_cap_profile_resolution_receipt": {},
		"actuator_cap_profile_host_mapping_receipt": {},
		"actuator_cap_profile_physical_binding_receipt": {},
		"maximum_impulse_override_by_actuator_id": {},
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var public_profile_policy := (
		policy_id == SdkGodotJoltPublicActuatorCapProfileBindingScript.POLICY_ID
	)
	if (
		joint_state_by_joint_id.size() != 8
		or not is_finite(readback_tolerance_nms)
		or readback_tolerance_nms < 0.0
		or readback_tolerance_nms > 1.0e-6
		or (
			not public_profile_policy
			and (
				not bool(compiled_morphology_boundary.get("ok", false))
				or typeof(compiled_morphology_boundary.get("morphology", null))
				!= TYPE_DICTIONARY
				or (
					compiled_morphology_boundary.get("morphology", {}) as Dictionary
				).is_empty()
			)
		)
	):
		return failure
	var morphology: Dictionary = (
		{}
		if public_profile_policy
		else compiled_morphology_boundary["morphology"]
	)
	var receipt: Dictionary
	var resolution_receipt: Dictionary = {}
	var physical_binding_receipt: Dictionary = {}
	var selected_value_key := ""
	if policy_id == SdkGodotJoltLiveFixtureActuatorCapBindingScript.POLICY_ID:
		if not profile_id.is_empty():
			failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_PROFILE_FORBIDDEN"
			(failure["binding_receipt"] as Dictionary)["failure_code"] = String(
				failure["failure_code"]
			)
			return failure
		var binder := SdkGodotJoltLiveFixtureActuatorCapBindingScript.new()
		receipt = binder.bind_compiled_actuator_caps(
			morphology,
			joint_state_by_joint_id,
			readback_tolerance_nms,
			policy_id,
		)
		selected_value_key = "declared_maximum_impulse_nms"
	elif policy_id == SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript.POLICY_ID:
		if not SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript.ORDERED_PROFILE_IDS.has(
			profile_id
		):
			failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_PROFILE_INVALID"
			(failure["binding_receipt"] as Dictionary)["failure_code"] = String(
				failure["failure_code"]
			)
			return failure
		var binder := SdkGodotJoltLiveFixtureActuatorCapFactorialBindingScript.new()
		receipt = binder.bind_profile(
			morphology,
			joint_state_by_joint_id,
			readback_tolerance_nms,
			profile_id,
			policy_id,
		)
		selected_value_key = "selected_maximum_impulse_nms"
	elif policy_id == SdkGodotJoltPublicActuatorCapProfileBindingScript.POLICY_ID:
		if (
			profile_id != SdkGodotJoltPublicActuatorCapProfileBindingScript.PROFILE_ID
			or descriptor.is_empty()
		):
			failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_PUBLIC_PROFILE_INVALID"
			(failure["binding_receipt"] as Dictionary)["failure_code"] = String(
				failure["failure_code"]
			)
			return failure
		var binder := SdkGodotJoltPublicActuatorCapProfileBindingScript.new()
		var public_route: Dictionary = binder.resolve_bind_and_project(
			descriptor,
			joint_state_by_joint_id,
			readback_tolerance_nms,
			profile_id,
			policy_id,
		)
		if not bool(public_route.get("ok", false)):
			failure["failure_code"] = String(
				public_route.get(
					"failure_code",
					"LIVE_FIXTURE_CAP_ROUTE_PUBLIC_BINDING_FAILED",
				)
			)
			failure["binding_receipt"] = (
				(
					public_route.get(
						"actuator_cap_profile_host_mapping_receipt",
						{},
					) as Dictionary
				).duplicate(true)
			)
			failure["actuator_cap_profile_resolution_receipt"] = (
				(
					public_route.get(
						"actuator_cap_profile_resolution_receipt",
						{},
					) as Dictionary
				).duplicate(true)
			)
			return failure
		receipt = (
			(
				public_route["actuator_cap_profile_host_mapping_receipt"]
				as Dictionary
			).duplicate(true)
		)
		resolution_receipt = (
			(
				public_route["actuator_cap_profile_resolution_receipt"]
				as Dictionary
			).duplicate(true)
		)
		physical_binding_receipt = (
			(
				public_route["actuator_cap_profile_physical_binding_receipt"]
				as Dictionary
			).duplicate(true)
		)
		selected_value_key = "declared_maximum_outer_step_impulse_nms"
	else:
		failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_POLICY_INVALID"
		(failure["binding_receipt"] as Dictionary)["failure_code"] = String(
			failure["failure_code"]
		)
		return failure
	if not bool(receipt.get("ok", false)):
		failure["failure_code"] = String(
			receipt.get("failure_code", "LIVE_FIXTURE_CAP_ROUTE_BINDING_FAILED")
		)
		failure["binding_receipt"] = receipt.duplicate(true)
		return failure
	var bindings_value: Variant = receipt.get("ordered_bindings", null)
	if typeof(bindings_value) != TYPE_ARRAY or (bindings_value as Array).size() != 8:
		failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_BINDING_CARDINALITY_INVALID"
		failure["binding_receipt"] = receipt.duplicate(true)
		return failure
	var maximum_impulse_override_by_actuator_id: Dictionary = {}
	for binding_value in bindings_value as Array:
		if typeof(binding_value) != TYPE_DICTIONARY:
			failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_BINDING_ROW_INVALID"
			failure["binding_receipt"] = receipt.duplicate(true)
			return failure
		var binding: Dictionary = binding_value
		var actuator_id := String(binding.get("actuator_id", ""))
		var selected_value: Variant = binding.get(selected_value_key, null)
		if (
			actuator_id.is_empty()
			or maximum_impulse_override_by_actuator_id.has(actuator_id)
			or (typeof(selected_value) != TYPE_FLOAT and typeof(selected_value) != TYPE_INT)
			or not is_finite(float(selected_value))
			or float(selected_value) <= 0.0
		):
			failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_OVERRIDE_INVALID"
			failure["binding_receipt"] = receipt.duplicate(true)
			return failure
		maximum_impulse_override_by_actuator_id[actuator_id] = float(selected_value)
	if maximum_impulse_override_by_actuator_id.size() != 8:
		failure["failure_code"] = "LIVE_FIXTURE_CAP_ROUTE_OVERRIDE_CARDINALITY_INVALID"
		failure["binding_receipt"] = receipt.duplicate(true)
		return failure
	return {
		"schema_version": "sporespore_godot_jolt_live_fixture_actuator_cap_route_v1",
		"ok": true,
		"failure_code": "",
		"policy_id": policy_id,
		"profile_id": profile_id,
		"binding_receipt": receipt.duplicate(true),
		"actuator_cap_profile_resolution_receipt": resolution_receipt.duplicate(true),
		"actuator_cap_profile_host_mapping_receipt": receipt.duplicate(true),
		"actuator_cap_profile_physical_binding_receipt": (
			physical_binding_receipt.duplicate(true)
		),
		"maximum_impulse_override_by_actuator_id": (
			maximum_impulse_override_by_actuator_id.duplicate(true)
		),
		"validated_actuator_count": 8,
		"write_count": int(receipt.get("write_count", -1)),
		"readback_count": int(receipt.get("readback_count", -1)),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


## Prepares and binds the exact unparented hinge objects that _build_fixture()
## will insert into the physical world. The public-profile route does not use a
## compiled-morphology input: it resolves the declared descriptor itself. This
## function is therefore safe to execute before model or world construction.
static func prepare_sdk_public_profile_actuator_cap_binding_before_world(
	fixture_spec: Dictionary,
	knee_motor_impulse_scale: float,
	hip_impulse_scale: float,
	knee_impulse_scale: float,
	initial_perturbation: Dictionary,
	readback_tolerance_nms: float,
	policy_id: String,
	profile_id: String,
	descriptor: Dictionary,
) -> Dictionary:
	var surface := compose_sdk_live_fixture_actuator_cap_binding_surface(
		fixture_spec,
		knee_motor_impulse_scale,
		hip_impulse_scale,
		knee_impulse_scale,
		initial_perturbation,
	)
	if not bool(surface.get("ok", false)):
		return {
			"ok": false,
			"failure_code": String(
				surface.get(
					"failure_code",
					"SDK_PUBLIC_PROFILE_PREWORLD_SURFACE_INVALID",
				)
			),
			"actuator_cap_surface": surface,
			"binding_route": {},
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var route := bind_sdk_live_fixture_actuator_cap_route(
		{},
		surface["joint_state_by_joint_id"],
		readback_tolerance_nms,
		policy_id,
		profile_id,
		descriptor,
	)
	if not bool(route.get("ok", false)):
		return {
			"ok": false,
			"failure_code": String(
				route.get(
					"failure_code",
					"SDK_PUBLIC_PROFILE_PREWORLD_BINDING_INVALID",
				)
			),
			"actuator_cap_surface": surface,
			"binding_route": route,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var validation := validate_sdk_live_fixture_actuator_cap_surface_for_world(
		surface,
		String(surface.get("fixture_spec_sha256", "")),
	)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"failure_code": String(
				validation.get(
					"failure_code",
					"SDK_PUBLIC_PROFILE_PREWORLD_CARRY_INVALID",
				)
			),
			"actuator_cap_surface": surface,
			"binding_route": route,
			"surface_validation": validation,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	return {
		"schema_version": (
			"sporespore_godot_jolt_public_profile_preworld_binding_preparation_v1"
		),
		"ok": true,
		"failure_code": "",
		"policy_id": policy_id,
		"profile_id": profile_id,
		"actuator_cap_surface": surface,
		"binding_route": route,
		"surface_validation": validation,
		"host_object_creation_count": int(
			surface.get("host_object_creation_count", -1)
		),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


## Validates the identity and ownership state of a prepared hinge surface at
## the exact handoff into _build_fixture(). It creates no object or world.
static func validate_sdk_live_fixture_actuator_cap_surface_for_world(
	surface: Dictionary,
	expected_fixture_spec_sha256: String,
) -> Dictionary:
	var joint_pairs_value: Variant = surface.get("joint_pair_by_limb_id", null)
	var joint_states_value: Variant = surface.get("joint_state_by_joint_id", null)
	var ordered_ids_value: Variant = surface.get("ordered_joint_ids", null)
	var ordered_nodes_value: Variant = surface.get("ordered_joint_nodes", null)
	if (
		not bool(surface.get("ok", false))
		or expected_fixture_spec_sha256.is_empty()
		or String(surface.get("fixture_spec_sha256", ""))
		!= expected_fixture_spec_sha256
		or typeof(joint_pairs_value) != TYPE_DICTIONARY
		or typeof(joint_states_value) != TYPE_DICTIONARY
		or typeof(ordered_ids_value) != TYPE_ARRAY
		or typeof(ordered_nodes_value) != TYPE_ARRAY
		or (joint_pairs_value as Dictionary).size() != 4
		or (joint_states_value as Dictionary).size() != 8
		or (ordered_ids_value as Array).size() != 8
		or (ordered_nodes_value as Array).size() != 8
		or int(surface.get("scene_tree_insertion_count", -1)) != 0
		or int(surface.get("model_construction_count", -1)) != 0
		or int(surface.get("world_attempt_count", -1)) != 0
		or int(surface.get("world_build_count", -1)) != 0
		or bool(surface.get("physics_state_modified", true))
	):
		return {
			"ok": false,
			"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_CARRY_INPUT_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var joint_states: Dictionary = joint_states_value
	var ordered_ids: Array = ordered_ids_value
	var ordered_nodes: Array = ordered_nodes_value
	var seen_instance_ids: Dictionary = {}
	for index in range(ordered_ids.size()):
		var joint_id := String(ordered_ids[index])
		var joint_value: Variant = ordered_nodes[index]
		if (
			joint_id.is_empty()
			or not joint_states.has(joint_id)
			or not (joint_value is HingeJoint3D)
		):
			return {
				"ok": false,
				"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_CARRY_ROW_INVALID",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"scene_tree_insertion_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
		var joint: HingeJoint3D = joint_value
		var state: Dictionary = joint_states[joint_id]
		var instance_id := joint.get_instance_id()
		if (
			joint.get_parent() != null
			or joint.is_inside_tree()
			or String(joint.get_meta("lab_joint_id", "")) != joint_id
			or state.get("joint", null) != joint
			or seen_instance_ids.has(instance_id)
		):
			return {
				"ok": false,
				"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_CARRY_IDENTITY_INVALID",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"scene_tree_insertion_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
		seen_instance_ids[instance_id] = true
	return {
		"schema_version": (
			"sporespore_godot_jolt_live_fixture_cap_surface_carry_validation_v1"
		),
		"ok": true,
		"failure_code": "",
		"validated_joint_count": 8,
		"unique_host_object_count": seen_instance_ids.size(),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func free_sdk_live_fixture_actuator_cap_binding_surface(
	surface: Dictionary,
) -> void:
	for joint_value in surface.get("ordered_joint_nodes", []):
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			if is_instance_valid(joint) and joint.get_parent() == null:
				joint.free()


## Composes the exact eight hinge objects later inserted by _build_fixture(),
## but leaves every object unparented. This is the zero-world fixture-path
## boundary used by the R23D55 cap-conformance gate. It constructs no body,
## model, viewport, SceneTree node, or physics world.
static func compose_sdk_live_fixture_actuator_cap_binding_surface(
	fixture_spec: Dictionary,
	knee_motor_impulse_scale: float,
	hip_impulse_scale: float,
	knee_impulse_scale: float,
	initial_perturbation: Dictionary = {},
) -> Dictionary:
	if (
		fixture_spec.is_empty()
		or not is_finite(knee_motor_impulse_scale)
		or knee_motor_impulse_scale <= 0.0
		or not is_finite(hip_impulse_scale)
		or hip_impulse_scale <= 0.0
		or not is_finite(knee_impulse_scale)
		or knee_impulse_scale <= 0.0
	):
		return {
			"ok": false,
			"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_INPUT_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var fixture_result := FixtureSpecScript.compile(fixture_spec)
	if not bool(fixture_result.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_FIXTURE_INVALID",
			"detail": fixture_result,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var compiled_fixture: Dictionary = fixture_result["fixture_spec"]
	var torso_spec: Dictionary = compiled_fixture["torso"]
	var limb_specs: Array = compiled_fixture["limbs"]
	var joint_limits: Dictionary = compiled_fixture["joint_limits"]
	var motor_impulses: Dictionary = compiled_fixture["motor_impulses"]
	var realized_hip_max_impulse_nms := (
		float(motor_impulses["hip_max_impulse_nms"]) * hip_impulse_scale
	)
	var realized_knee_max_impulse_nms := (
		float(motor_impulses["knee_base_max_impulse_nms"])
		* knee_motor_impulse_scale
		* knee_impulse_scale
	)
	var torso_initial_center_m := FixtureSpecScript.vector3_from_array(
		torso_spec["initial_center_m"]
	)
	var fixture_vertical_clearance_m := float(
		initial_perturbation.get("fixture_vertical_clearance_m", 0.0)
	)
	if not is_finite(fixture_vertical_clearance_m):
		return {
			"ok": false,
			"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_CLEARANCE_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var vertical_offset := Vector3.UP * fixture_vertical_clearance_m
	var joint_pair_by_limb_id: Dictionary = {}
	var joint_state_by_joint_id: Dictionary = {}
	var ordered_joint_ids: Array[String] = []
	var ordered_joint_nodes: Array[HingeJoint3D] = []
	var scene_tree_insertion_count := 0
	for limb_spec_value in limb_specs:
		if typeof(limb_spec_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_LIMB_INVALID",
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
		var limb_spec: Dictionary = limb_spec_value
		var limb_id := String(limb_spec["limb_id"])
		var hip_world := (
			torso_initial_center_m
			+ FixtureSpecScript.vector3_from_array(
				limb_spec["hip_offset_from_torso_center_m"]
			)
			+ vertical_offset
		)
		var knee_world := hip_world + Vector3.DOWN * float(limb_spec["upper_length_m"])
		var pair := _compose_fixture_hinge_pair(
			limb_id,
			hip_world,
			knee_world,
			joint_limits,
			realized_hip_max_impulse_nms,
			realized_knee_max_impulse_nms,
		)
		if not bool(pair.get("ok", false)) or joint_pair_by_limb_id.has(limb_id):
			return {
				"ok": false,
				"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_PAIR_INVALID:%s" % limb_id,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
		joint_pair_by_limb_id[limb_id] = pair
		for state_value in pair["ordered_joint_states"]:
			var state: Dictionary = state_value
			var joint_id := String(state["joint_id"])
			var joint: HingeJoint3D = state["joint"]
			if joint_state_by_joint_id.has(joint_id):
				return {
					"ok": false,
					"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_DUPLICATE:%s" % joint_id,
					"model_construction_count": 0,
					"world_attempt_count": 0,
					"world_build_count": 0,
					"physics_state_modified": false,
					"physical_acceptance_authority": false,
				}
			joint_state_by_joint_id[joint_id] = state
			ordered_joint_ids.append(joint_id)
			ordered_joint_nodes.append(joint)
			scene_tree_insertion_count += int(joint.is_inside_tree())
	if (
		joint_pair_by_limb_id.size() != 4
		or joint_state_by_joint_id.size() != 8
		or ordered_joint_nodes.size() != 8
	):
		return {
			"ok": false,
			"failure_code": "SDK_LIVE_FIXTURE_CAP_SURFACE_CARDINALITY_INVALID",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	return {
		"schema_version": (
			SdkGodotJoltLiveFixtureActuatorCapBindingScript
			. FIXTURE_COMPOSITION_SCHEMA_VERSION
		),
		"ok": true,
		"failure_code": "",
		"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		"joint_pair_by_limb_id": joint_pair_by_limb_id,
		"joint_state_by_joint_id": joint_state_by_joint_id,
		"ordered_joint_ids": ordered_joint_ids,
		"ordered_joint_nodes": ordered_joint_nodes,
		"realized_hip_max_impulse_nms": realized_hip_max_impulse_nms,
		"realized_knee_max_impulse_nms": realized_knee_max_impulse_nms,
		"host_object_creation_count": ordered_joint_nodes.size(),
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _compose_fixture_hinge_pair(
	limb_id: String,
	hip_world: Vector3,
	knee_world: Vector3,
	joint_limits: Dictionary,
	realized_hip_max_impulse_nms: float,
	realized_knee_max_impulse_nms: float,
) -> Dictionary:
	if limb_id.is_empty() or not hip_world.is_finite() or not knee_world.is_finite():
		return {"ok": false}
	var hip_joint := _hinge_joint(
		"wave_gait_%s_hip" % limb_id,
		hip_world,
		float(joint_limits["hip_lower_rad"]),
		float(joint_limits["hip_upper_rad"]),
		realized_hip_max_impulse_nms,
		float(joint_limits["bias"]),
		float(joint_limits["relaxation"]),
	)
	var knee_joint := _hinge_joint(
		"wave_gait_%s_knee" % limb_id,
		knee_world,
		float(joint_limits["knee_lower_rad"]),
		float(joint_limits["knee_upper_rad"]),
		realized_knee_max_impulse_nms,
		float(joint_limits["bias"]),
		float(joint_limits["relaxation"]),
	)
	var hip_joint_id := "%s.hip_pitch" % limb_id
	var knee_joint_id := "%s.knee_pitch" % limb_id
	for identity in [
		{"joint": hip_joint, "joint_id": hip_joint_id},
		{"joint": knee_joint, "joint_id": knee_joint_id},
	]:
		var joint: HingeJoint3D = identity["joint"]
		joint.set_meta("lab_joint_id", String(identity["joint_id"]))
		joint.set_meta(
			"sporespore_fixture_joint_composition_schema_version",
			SdkGodotJoltLiveFixtureActuatorCapBindingScript.FIXTURE_COMPOSITION_SCHEMA_VERSION,
		)
	return {
		"ok": true,
		"limb_id": limb_id,
		"hip_world": hip_world,
		"knee_world": knee_world,
		"hip_joint": hip_joint,
		"knee_joint": knee_joint,
		"ordered_joint_states": [
			{"joint_id": hip_joint_id, "role": "hip_pitch", "joint": hip_joint},
			{"joint_id": knee_joint_id, "role": "knee_pitch", "joint": knee_joint},
		],
	}


static func _build_fixture(
	tree: SceneTree,
	knee_motor_impulse_scale: float,
	hip_impulse_scale: float,
	knee_impulse_scale: float,
	visible_demo: bool = false,
	initial_perturbation: Dictionary = {},
	fixture_spec: Dictionary = {},
	environment_challenge_options: Dictionary = {},
	precomposed_actuator_cap_surface: Dictionary = {},
) -> Dictionary:
	var torso_spec: Dictionary = fixture_spec["torso"]
	var limb_specs: Array = fixture_spec["limbs"]
	var joint_limits: Dictionary = fixture_spec["joint_limits"]
	var motor_impulses: Dictionary = fixture_spec["motor_impulses"]
	var contact_material: Dictionary = fixture_spec["contact_material"]
	var body_dynamics: Dictionary = fixture_spec["body_dynamics"]
	var collision_margin_m := float(fixture_spec["collision_margin_m"])
	var realized_hip_max_impulse_nms := (
		float(motor_impulses["hip_max_impulse_nms"]) * hip_impulse_scale
	)
	var realized_knee_max_impulse_nms := (
		float(motor_impulses["knee_base_max_impulse_nms"])
		* knee_motor_impulse_scale
		* knee_impulse_scale
	)
	var torso_initial_center_m := FixtureSpecScript.vector3_from_array(
		torso_spec["initial_center_m"]
	)
	var torso_size_m := FixtureSpecScript.vector3_from_array(torso_spec["size_m"])
	var reference_torso_size_m := FixtureSpecScript.vector3_from_array(
		(FixtureSpecScript.reference_spec()["torso"] as Dictionary)["size_m"]
	)
	var fixture_view_scale := torso_size_m.x / reference_torso_size_m.x
	var fixture_vertical_clearance_m := float(
		initial_perturbation.get("fixture_vertical_clearance_m", 0.0)
	)
	var fixture_yaw_rad := float(initial_perturbation.get("fixture_yaw_rad", 0.0))
	var initial_linear_velocity_world_m_s: Vector3 = initial_perturbation.get(
		"initial_linear_velocity_world_m_s", Vector3.ZERO
	)
	var initial_torso_angular_velocity_world_rad_s: Vector3 = initial_perturbation.get(
		"initial_torso_angular_velocity_world_rad_s", Vector3.ZERO
	)
	var vertical_offset := Vector3.UP * fixture_vertical_clearance_m
	var actuator_cap_surface: Dictionary
	if precomposed_actuator_cap_surface.is_empty():
		actuator_cap_surface = compose_sdk_live_fixture_actuator_cap_binding_surface(
			fixture_spec,
			knee_motor_impulse_scale,
			hip_impulse_scale,
			knee_impulse_scale,
			initial_perturbation,
		)
	else:
		var expected_fixture := FixtureSpecScript.compile(fixture_spec)
		if not bool(expected_fixture.get("ok", false)):
			return expected_fixture
		var carried_surface_validation := (
			validate_sdk_live_fixture_actuator_cap_surface_for_world(
				precomposed_actuator_cap_surface,
				String(expected_fixture.get("fixture_spec_sha256", "")),
			)
		)
		if not bool(carried_surface_validation.get("ok", false)):
			return carried_surface_validation
		actuator_cap_surface = precomposed_actuator_cap_surface
	if not bool(actuator_cap_surface.get("ok", false)):
		return actuator_cap_surface
	var joint_pair_by_limb_id: Dictionary = actuator_cap_surface["joint_pair_by_limb_id"]
	var viewport := SubViewport.new()
	viewport.name = "PhysicalWaveGaitQuadrupedViewport"
	viewport.size = Vector2i(1280, 720) if visible_demo else Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if visible_demo else SubViewport.UPDATE_DISABLED
	)
	var cleanup_node: Node = viewport
	if visible_demo:
		var viewport_container := SubViewportContainer.new()
		viewport_container.name = "PhysicalWaveGaitQuadrupedDemo"
		viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport_container.stretch = true
		tree.root.add_child(viewport_container)
		viewport_container.add_child(viewport)
		_add_demo_overlay(viewport_container)
		cleanup_node = viewport_container
	else:
		tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "PhysicalWaveGaitQuadrupedWorld"
	world.rotation.y = fixture_yaw_rad
	viewport.add_child(world)
	if visible_demo:
		_add_demo_environment(world, fixture_view_scale)
	var floor := StaticBody3D.new()
	floor.name = "wave_gait_floor"
	floor.set_meta("lab_body_id", "floor")
	floor.collision_layer = 1
	floor.collision_mask = 0
	floor.position = Vector3.ZERO
	var terrain_profile_id := String(
		environment_challenge_options.get("terrain_profile_id", FLAT_TERRAIN_PROFILE_ID)
	)
	var terrain_shape_count := 0
	if terrain_profile_id == ROUGH_TERRAIN_PROFILE_ID:
		var tile_length_m := float(environment_challenge_options["terrain_tile_length_m"])
		var tile_count := int(environment_challenge_options["terrain_tile_count"])
		var terrain_origin_x_m := float(environment_challenge_options["terrain_origin_x_m"])
		var terrain_heights: Array = environment_challenge_options["terrain_heights_m"]
		for tile_index in range(tile_count):
			var tile_height_m := float(terrain_heights[tile_index % terrain_heights.size()])
			var tile_shape_node := CollisionShape3D.new()
			tile_shape_node.name = "rough_tile_%03d" % tile_index
			var tile_shape := BoxShape3D.new()
			tile_shape.size = Vector3(tile_length_m, 0.1, 20.0)
			tile_shape.margin = collision_margin_m
			tile_shape_node.position = Vector3(
				terrain_origin_x_m + (float(tile_index) + 0.5) * tile_length_m,
				-0.05 + tile_height_m,
				0.0,
			)
			tile_shape_node.shape = tile_shape
			floor.add_child(tile_shape_node)
			if visible_demo:
				_add_box_visual(
					floor,
					tile_shape.size,
					Color("273043"),
					tile_shape_node.position,
				)
			terrain_shape_count += 1
	else:
		floor.position = Vector3(0.0, -0.05 * fixture_view_scale, 0.0)
		var floor_shape_node := CollisionShape3D.new()
		var floor_shape := BoxShape3D.new()
		floor_shape.size = Vector3(20.0, 0.1, 20.0) * fixture_view_scale
		floor_shape.margin = collision_margin_m
		floor_shape_node.shape = floor_shape
		floor.add_child(floor_shape_node)
		if visible_demo:
			_add_box_visual(floor, floor_shape.size, Color("273043"))
		terrain_shape_count = 1
	floor.physics_material_override = _physics_material(contact_material)
	world.add_child(floor)
	var torso := _rigid_body(
		"wave_gait_torso",
		float(torso_spec["mass_kg"]),
		torso_initial_center_m + vertical_offset,
		true,
		contact_material,
		body_dynamics
	)
	var torso_shape_node := CollisionShape3D.new()
	var torso_shape := BoxShape3D.new()
	torso_shape.size = torso_size_m
	torso_shape.margin = collision_margin_m
	torso_shape_node.shape = torso_shape
	torso_shape_node.set_meta("lab_shape_id", "torso")
	torso.add_child(torso_shape_node)
	if visible_demo:
		_add_box_visual(torso, torso_shape.size, Color("ff9f1c"))
	world.add_child(torso)
	var limbs: Array = []
	var bodies: Array = [torso]
	var joint_nodes: Array = []
	for limb_spec_value in limb_specs:
		var limb_spec: Dictionary = limb_spec_value
		var limb_id := String(limb_spec["limb_id"])
		var hip_world := (
			torso_initial_center_m
			+ FixtureSpecScript.vector3_from_array(limb_spec["hip_offset_from_torso_center_m"])
			+ vertical_offset
		)
		var upper_length_m := float(limb_spec["upper_length_m"])
		var lower_length_m := float(limb_spec["lower_length_m"])
		var upper_cross_section: Array = limb_spec["upper_cross_section_m"]
		var knee_world := hip_world + Vector3.DOWN * upper_length_m
		var foot_world := knee_world + Vector3.DOWN * lower_length_m
		var upper := _rigid_body(
			"wave_gait_%s_upper" % limb_id,
			float(limb_spec["upper_mass_kg"]),
			hip_world.lerp(knee_world, 0.5),
			false,
			contact_material,
			body_dynamics
		)
		var upper_shape_node := CollisionShape3D.new()
		var upper_shape := BoxShape3D.new()
		upper_shape.size = Vector3(
			float(upper_cross_section[0]), upper_length_m, float(upper_cross_section[1])
		)
		upper_shape.margin = collision_margin_m
		upper_shape_node.shape = upper_shape
		upper.add_child(upper_shape_node)
		if visible_demo:
			var upper_color := Color("3a86ff") if limb_id.ends_with("left") else Color("2ec4b6")
			_add_box_visual(upper, upper_shape.size, upper_color)
		var foot := _rigid_body(
			"wave_gait_%s_foot" % limb_id,
			float(limb_spec["distal_mass_kg"]),
			foot_world,
			true,
			contact_material,
			body_dynamics
		)
		var foot_shape_node := CollisionShape3D.new()
		var foot_shape := SphereShape3D.new()
		foot_shape.radius = float(limb_spec["foot_radius_m"])
		foot_shape.margin = collision_margin_m
		foot_shape_node.shape = foot_shape
		foot_shape_node.set_meta("lab_shape_id", "foot")
		foot.add_child(foot_shape_node)
		if visible_demo:
			var foot_color := Color("90beff") if limb_id.ends_with("left") else Color("8ce3d8")
			_add_sphere_visual(foot, foot_shape.radius, foot_color)
		world.add_child(upper)
		world.add_child(foot)
		bodies.append(upper)
		bodies.append(foot)
		var joint_pair: Dictionary = joint_pair_by_limb_id[limb_id]
		var hip_joint: HingeJoint3D = joint_pair["hip_joint"]
		var knee_joint: HingeJoint3D = joint_pair["knee_joint"]
		world.add_child(hip_joint)
		world.add_child(knee_joint)
		joint_nodes.append(hip_joint)
		joint_nodes.append(knee_joint)
		(
			limbs
			. append(
				{
					"limb_id": limb_id,
					"upper": upper,
					"foot": foot,
					"hip_joint": hip_joint,
					"knee_joint": knee_joint,
					"joint_states":
					[
						{
							"joint_id": "%s.hip_pitch" % limb_id,
							"role": "hip_pitch",
							"parent": torso,
							"child": upper,
							"joint": hip_joint,
							"pivot_world_initial": world.to_global(hip_world),
						},
						{
							"joint_id": "%s.knee_pitch" % limb_id,
							"role": "knee_pitch",
							"parent": upper,
							"child": foot,
							"joint": knee_joint,
							"pivot_world_initial": world.to_global(knee_world),
						},
					],
				}
			)
		)
	await tree.process_frame
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var hip_joint: HingeJoint3D = limb["hip_joint"]
		var knee_joint: HingeJoint3D = limb["knee_joint"]
		hip_joint.node_a = hip_joint.get_path_to(torso)
		hip_joint.node_b = hip_joint.get_path_to(limb["upper"])
		knee_joint.node_a = knee_joint.get_path_to(limb["upper"])
		knee_joint.node_b = knee_joint.get_path_to(limb["foot"])
	await tree.physics_frame
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = state["parent"]
			var child: RigidBody3D = state["child"]
			var pivot_world: Vector3 = state["pivot_world_initial"]
			state["rest_relative_basis"] = (
				(parent.global_basis.inverse() * child.global_basis).orthonormalized()
			)
			state["axis_parent_local"] = (parent.global_basis.inverse() * Vector3.BACK).normalized()
			state["axis_child_local"] = (child.global_basis.inverse() * Vector3.BACK).normalized()
			state["anchor_parent_local"] = parent.to_local(pivot_world)
			state["anchor_child_local"] = child.to_local(pivot_world)
	var initial_linear_velocity_body_initialization_count := 0
	var initial_torso_angular_velocity_initialization_count := 0
	for body_value in bodies:
		var body: RigidBody3D = body_value
		body.freeze = false
		body.sleeping = false
	if not initial_linear_velocity_world_m_s.is_zero_approx():
		for body_value in bodies:
			var initialized_body: RigidBody3D = body_value
			initialized_body.linear_velocity = initial_linear_velocity_world_m_s
			initial_linear_velocity_body_initialization_count += 1
	if not initial_torso_angular_velocity_world_rad_s.is_zero_approx():
		torso.angular_velocity = initial_torso_angular_velocity_world_rad_s
		initial_torso_angular_velocity_initialization_count = 1
	await tree.physics_frame
	return {
		"ok": true,
		"viewport": viewport,
		"cleanup_node": cleanup_node,
		"world": world,
		"floor": floor,
		"torso": torso,
		"limbs": limbs,
		"bodies": bodies,
		"joint_nodes": joint_nodes,
		"terrain_shape_count": terrain_shape_count,
		"fixture_view_scale": fixture_view_scale,
		"realized_hip_max_impulse_nms": realized_hip_max_impulse_nms,
		"realized_knee_max_impulse_nms": realized_knee_max_impulse_nms,
		"initial_linear_velocity_body_initialization_count":
		initial_linear_velocity_body_initialization_count,
		"initial_torso_angular_velocity_initialization_count":
		initial_torso_angular_velocity_initialization_count,
	}


static func _add_demo_overlay(parent: Control) -> void:
	var panel := ColorRect.new()
	panel.name = "EvidenceBoundaryLabelBackground"
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(590.0, 92.0)
	panel.color = Color(0.025, 0.035, 0.06, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var label := Label.new()
	label.name = "EvidenceBoundaryLabel"
	label.position = Vector2(16.0, 10.0)
	label.text = (
		"SporeSpore physical quadruped — best development candidate\n"
		+ "8 hinge motors • 9 free rigid bodies • no root force or teleport\n"
		+ "Development walking pass • exact multi-seed certification is still pending"
	)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f4f7ff"))
	panel.add_child(label)


static func _add_demo_environment(world: Node3D, fixture_view_scale: float) -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "DemoWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b132b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e3fc")
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.name = "DemoKeyLight"
	light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.name = "DemoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7 * fixture_view_scale
	camera.position = Vector3(0.58, 0.88, 1.72) * fixture_view_scale
	camera.look_at_from_position(
		camera.position, Vector3(0.58, 0.24, 0.0) * fixture_view_scale, Vector3.UP
	)
	camera.current = true
	world.add_child(camera)


static func _add_box_visual(
	body: CollisionObject3D,
	size_m: Vector3,
	color: Color,
	local_position: Vector3 = Vector3.ZERO,
) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_m
	mesh.material = _demo_material(color)
	visual.mesh = mesh
	visual.position = local_position
	body.add_child(visual)


static func _add_sphere_visual(body: CollisionObject3D, radius_m: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius_m
	mesh.height = radius_m * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _demo_material(color)
	visual.mesh = mesh
	body.add_child(visual)


static func _demo_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.72
	return material


static func _rigid_body(
	body_name: String,
	mass_kg: float,
	position_world_m: Vector3,
	monitor_contacts: bool,
	contact_material: Dictionary,
	body_dynamics: Dictionary
) -> RigidBody3D:
	var body: RigidBody3D
	if monitor_contacts:
		body = SemanticContactRigidBodyScript.new()
	else:
		body = RigidBody3D.new()
	body.name = body_name
	body.mass = mass_kg
	body.position = position_world_m
	body.freeze = true
	body.can_sleep = bool(body_dynamics["can_sleep"])
	body.continuous_cd = bool(body_dynamics["continuous_collision_detection"])
	body.linear_damp = float(body_dynamics["linear_damp"])
	body.angular_damp = float(body_dynamics["angular_damp"])
	body.collision_layer = int(body_dynamics["collision_layer"])
	body.collision_mask = int(body_dynamics["collision_mask"])
	body.contact_monitor = monitor_contacts
	body.max_contacts_reported = (
		int(body_dynamics["maximum_reported_contacts"]) if monitor_contacts else 0
	)
	body.physics_material_override = _physics_material(contact_material)
	return body


static func _physics_material(configuration: Dictionary) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = float(configuration["friction"])
	material.rough = bool(configuration["rough"])
	material.bounce = float(configuration["bounce"])
	material.absorbent = bool(configuration["absorbent"])
	return material


static func _hinge_joint(
	joint_name: String,
	pivot_world_m: Vector3,
	lower_limit_rad: float,
	upper_limit_rad: float,
	maximum_motor_impulse_nms: float,
	limit_bias: float,
	limit_relaxation: float
) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = joint_name
	joint.position = pivot_world_m
	joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lower_limit_rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, upper_limit_rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_BIAS, limit_bias)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_RELAXATION, limit_relaxation)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, maximum_motor_impulse_nms)
	return joint


static func _gait_amplitude(
	tick: int,
	evidence_end_tick: int,
	cooldown_end_tick: int,
	settle_ticks: int = SETTLE_TICKS,
	warmup_cycles: int = WARMUP_CYCLES,
	cooldown_cycles: int = COOLDOWN_CYCLES,
	cycle_ticks: int = CYCLE_TICKS,
) -> float:
	if tick < settle_ticks:
		return 0.0
	if tick < settle_ticks + warmup_cycles * cycle_ticks:
		return _smoothstep(
			clampf(
				float(tick - settle_ticks) / float(warmup_cycles * cycle_ticks),
				0.0,
				1.0,
			)
		)
	if tick < evidence_end_tick:
		return 1.0
	if tick < cooldown_end_tick:
		return (
			1.0
			- _smoothstep(
				clampf(
					float(tick - evidence_end_tick) / float(cooldown_cycles * cycle_ticks),
					0.0,
					1.0,
				)
			)
		)
	return 0.0


static func _resolve_gait_phase_order(gait_phase_order_id: String) -> Array:
	if GAIT_PHASE_ORDERS.has(gait_phase_order_id):
		return (GAIT_PHASE_ORDERS[gait_phase_order_id] as Array).duplicate()
	var requested_order: Array = Array(gait_phase_order_id.split(",", false))
	if requested_order.size() != LIMB_ORDER.size():
		return []
	for limb_id_value in LIMB_ORDER:
		if requested_order.count(String(limb_id_value)) != 1:
			return []
	return requested_order


static func _gait_joint_targets(
	local_phase_tick: int,
	amplitude: float,
	knee_flexion_scale: float,
	swing_ticks: int,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var hip_target_rad: float
	var knee_target_rad := 0.0
	if local_phase_tick < swing_ticks:
		var swing_fraction := clampf(float(local_phase_tick) / float(swing_ticks), 0.0, 1.0)
		hip_target_rad = lerpf(
			HIP_REAR_TARGET_RAD, HIP_FORWARD_TARGET_RAD, _smoothstep(swing_fraction)
		)
		knee_target_rad = KNEE_SWING_FLEXION_RAD * knee_flexion_scale * sin(PI * swing_fraction)
	else:
		var stance_fraction := clampf(
			float(local_phase_tick - swing_ticks) / float(cycle_ticks - swing_ticks),
			0.0,
			1.0,
		)
		hip_target_rad = lerpf(
			HIP_FORWARD_TARGET_RAD, HIP_REAR_TARGET_RAD, _smoothstep(stance_fraction)
		)
	return {
		"hip_target_rad": amplitude * hip_target_rad,
		"knee_target_rad": amplitude * knee_target_rad,
	}


static func _command_hinge_motor(
	state: Dictionary,
	target_angle_rad: float,
	motor_direction_sign: float,
	motor_position_gain_per_s: float = MOTOR_POSITION_GAIN_PER_S,
	motor_rate_damping: float = MOTOR_RATE_DAMPING,
	maximum_target_speed_rad_s: float = MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
	apply_actuation: bool = true,
) -> Dictionary:
	var joint: HingeJoint3D = state["joint"]
	var measured_angle_rad := _joint_angle_rad(state)
	var measured_rate_rad_s := _joint_rate_rad_s(state)
	var target_velocity_rad_s := clampf(
		(
			motor_position_gain_per_s * (target_angle_rad - measured_angle_rad)
			- motor_rate_damping * measured_rate_rad_s
		),
		-maximum_target_speed_rad_s,
		maximum_target_speed_rad_s,
	)
	target_velocity_rad_s *= motor_direction_sign
	if apply_actuation:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, target_velocity_rad_s)
	return {
		"target_velocity_rad_s": target_velocity_rad_s,
		"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
		"measured_angle_rad": measured_angle_rad,
		"measured_rate_rad_s": measured_rate_rad_s,
		"actuation_applied": apply_actuation,
	}


static func _joint_angle_rad(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var rest_relative: Basis = state["rest_relative_basis"]
	var current_relative := (parent.global_basis.inverse() * child.global_basis).orthonormalized()
	var delta := (current_relative * rest_relative.inverse()).orthonormalized()
	var rotation := delta.get_rotation_quaternion()
	var angle_rad := rotation.get_angle()
	if angle_rad <= 1.0e-9:
		return 0.0
	var axis_parent_local: Vector3 = state["axis_parent_local"]
	return angle_rad * signf(rotation.get_axis().dot(axis_parent_local))


static func _joint_rate_rad_s(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var axis_world := (parent.global_basis * (state["axis_parent_local"] as Vector3)).normalized()
	return (child.angular_velocity - parent.angular_velocity).dot(axis_world)


static func _joint_geometry_receipt(state: Dictionary) -> Dictionary:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_anchor := parent.to_global(state["anchor_parent_local"])
	var child_anchor := child.to_global(state["anchor_child_local"])
	var parent_axis := (parent.global_basis * (state["axis_parent_local"] as Vector3)).normalized()
	var child_axis := (child.global_basis * (state["axis_child_local"] as Vector3)).normalized()
	return {
		"anchor_error_m": parent_anchor.distance_to(child_anchor),
		"hinge_axis_error_rad": acos(clampf(absf(parent_axis.dot(child_axis)), 0.0, 1.0)),
	}


static func _update_contact_cycle_receipts(
	tick: int,
	limbs: Array,
	floor: StaticBody3D,
	contact_state_by_limb: Dictionary,
	contact_cycle_count_by_limb: Dictionary,
	rejected_short_contact_cycle_count_by_limb: Dictionary,
	maximum_cycle_relocation_by_limb_m: Dictionary,
	minimum_cycle_relocation_by_limb_m: Dictionary,
	contact_transition_receipts_by_limb: Dictionary,
	minimum_airborne_dwell_ticks: int = MINIMUM_AIRBORNE_DWELL_TICKS,
	minimum_foot_relocation_m: float = MINIMUM_FOOT_RELOCATION_M,
) -> void:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		var foot: RigidBody3D = limb["foot"]
		var contact_now := _foot_bears_floor(limb, floor)
		var state: Dictionary = contact_state_by_limb[limb_id]
		if not bool(state["airborne"]):
			if bool(state["bearing"]) and not contact_now:
				state["airborne"] = true
				state["bearing"] = false
				state["release_tick"] = tick
				state["release_position"] = foot.global_position
				state["airborne_dwell_ticks"] = 1
				(
					(contact_transition_receipts_by_limb[limb_id] as Array)
					. append(
						{
							"event": "release",
							"tick": tick,
							"foot_position_world_m": foot.global_position,
						}
					)
				)
			else:
				state["bearing"] = contact_now
			continue
		if not contact_now:
			state["airborne_dwell_ticks"] = int(state["airborne_dwell_ticks"]) + 1
			continue
		var airborne_dwell_ticks := int(state["airborne_dwell_ticks"])
		var release_position: Vector3 = state["release_position"]
		var forward_relocation_m := foot.global_position.x - release_position.x
		var accepted := (
			airborne_dwell_ticks >= minimum_airborne_dwell_ticks
			and forward_relocation_m >= minimum_foot_relocation_m
		)
		(
			(contact_transition_receipts_by_limb[limb_id] as Array)
			. append(
				{
					"event": "recontact",
					"tick": tick,
					"airborne_dwell_ticks": airborne_dwell_ticks,
					"forward_relocation_m": forward_relocation_m,
					"accepted": accepted,
					"foot_position_world_m": foot.global_position,
				}
			)
		)
		if accepted:
			contact_cycle_count_by_limb[limb_id] = int(contact_cycle_count_by_limb[limb_id]) + 1
			maximum_cycle_relocation_by_limb_m[limb_id] = maxf(
				float(maximum_cycle_relocation_by_limb_m[limb_id]), forward_relocation_m
			)
			minimum_cycle_relocation_by_limb_m[limb_id] = minf(
				float(minimum_cycle_relocation_by_limb_m[limb_id]), forward_relocation_m
			)
		else:
			rejected_short_contact_cycle_count_by_limb[limb_id] = (
				int(rejected_short_contact_cycle_count_by_limb[limb_id]) + 1
			)
		state["airborne"] = false
		state["bearing"] = true
		state["release_tick"] = -1
		state["release_position"] = Vector3(INF, INF, INF)
		state["airborne_dwell_ticks"] = 0


static func _foot_bears_floor(limb: Dictionary, floor: StaticBody3D) -> bool:
	var foot: RigidBody3D = limb["foot"]
	return _body_bears_floor(foot, "foot", floor)


static func _body_bears_floor(
	body: RigidBody3D, semantic_shape_id: String, floor: StaticBody3D
) -> bool:
	if (
		floor.has_meta("lab_body_id")
		and body.has_method("has_semantic_contact")
		and body.get("semantic_contact_callback_count") != null
		and int(body.get("semantic_contact_callback_count")) > 0
	):
		return bool(
			body.call(
				"has_semantic_contact", semantic_shape_id, String(floor.get_meta("lab_body_id"))
			)
		)
	return floor in body.get_colliding_bodies()


static func _all_feet_bear_floor(limbs: Array, floor: StaticBody3D) -> bool:
	for limb_value in limbs:
		if not _foot_bears_floor(limb_value, floor):
			return false
	return true


static func _bearing_contact_by_limb(limbs: Array, floor: StaticBody3D) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		result[String(limb["limb_id"])] = _foot_bears_floor(limb, floor)
	return result


static func _contact_observer_callback_count_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var foot: RigidBody3D = limb["foot"]
		result[String(limb["limb_id"])] = int(foot.get("semantic_contact_callback_count"))
	return result


static func _joint_angles_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var angles := {}
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			angles[String(state["role"])] = _joint_angle_rad(state)
		result[String(limb["limb_id"])] = angles
	return result


static func _foot_heights_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var foot: RigidBody3D = limb["foot"]
		result[String(limb["limb_id"])] = foot.global_position.y
	return result


static func _tilt_rad(torso: RigidBody3D) -> float:
	return acos(clampf(torso.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _yaw_rad(torso: RigidBody3D) -> float:
	var forward := -torso.global_basis.z.normalized()
	return atan2(forward.x, -forward.z)


static func _wrap_angle(angle_rad: float) -> float:
	return fposmod(angle_rad + PI, TAU) - PI


static func _smoothstep(value: float) -> float:
	var bounded := clampf(value, 0.0, 1.0)
	return bounded * bounded * (3.0 - 2.0 * bounded)
