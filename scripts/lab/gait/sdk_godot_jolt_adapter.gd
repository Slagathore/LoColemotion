class_name LabSdkGodotJoltAdapter
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-returns
# gdlint: disable=function-arguments-number

## Godot/Jolt adapter for the engine-neutral locomotion SDK.
##
## Shadow mode samples the existing physical fixture and compares native output
## without writing a motor. Authority mode validates the complete native frame
## before mapping all ordered commands to hinge motors. Neither mode ever writes
## a body transform, body velocity, force, or impulse.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const DevelopmentNativeFailure := preload("res://sdk/adapters/godot/gdscript/development_native_step_failure_v1.gd")
const DynamicSupportObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const NATIVE_CLASS_NAME := "SporeLocomotionSdk"
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const TRANSPORT_CONTRACT_SCHEMA_VERSION := (
	"sporespore_godot_transport_execution_contract_v1"
)
const TRANSPORT_EXECUTION_VERSION := "sporespore_godot_json_preallocated_single_pass_v1"
const CONTROLLER_SESSION_CONTRACT_SCHEMA_VERSION := (
	"sporespore_godot_controller_session_execution_contract_v1"
)
const CONTROLLER_SESSION_EXECUTION_VERSION := (
	"sporespore_godot_balanced_wave_persistent_session_v1"
)
const NATIVE_STEP_TRANSPORT_VERIFICATION_CONTRACT_SCHEMA_VERSION := (
	"sporespore_godot_balanced_wave_native_step_transport_verification_contract_v1"
)
const NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION := (
	"sporespore_godot_balanced_wave_native_step_transport_verification_v1"
)
const NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_native_step_transport_verification_v1"
)
const NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_KEYS := [
	"schema_version",
	"verification_version",
	"ok",
	"policy_id",
	"semantic_step",
	"controller_receipt_schema_version",
	"controller_receipt_sha256",
	"native_actuation_receipt_sha256",
	"raw_native_response_sha256",
	"raw_native_response_byte_length",
	"successful_public_envelope",
	"policy_identity_exact",
	"semantic_step_identity_exact",
	"controller_receipt_schema_exact",
	"native_canonical_receipt_digest_exact",
	"preparse_native_response_verified",
	"raw_native_response_rewritten",
	"post_parse_dictionary_rehash_used",
	"floating_point_measurement_field_count",
	"world_build_count",
	"solver_step_count",
	"physical_acceptance_authority",
	"payload_sha256",
]
const TRANSPORT_INITIAL_OUTPUT_CAPACITY_BYTES := 16384
const TRANSPORT_NORMAL_PATH_NATIVE_INVOCATION_COUNT := 1
const TRANSPORT_OVERFLOW_RETRY_LIMIT := 1
const MANIFEST_SCHEMA_VERSION := "sporespore_godot_jolt_adapter_manifest_v14"
const MANIFEST_SCHEMA_V15_VERSION := "sporespore_godot_jolt_adapter_manifest_v15"
const MANIFEST_SCHEMA_V16_VERSION := "sporespore_godot_jolt_adapter_manifest_v16"
const EXECUTION_SUMMARY_SCHEMA_VERSION := "sporespore_godot_jolt_execution_summary_v1"
const HEADING_OFFSET_COMMAND_SCHEMA_VERSION := (
	"sporespore_heading_offset_command_v1"
)
const HEADING_COMMAND_RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_jolt_heading_command_receipt_v1"
)
const TASK_FRAME_ORIGIN_RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_jolt_task_frame_origin_receipt_v1"
)
const FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID := "fixed_initial_origin_v1"
const HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID := (
	"heading_segment_origin_reanchor_v1"
)
const WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID := (
	"warmup_preserving_command_onset_origin_reanchor_v1"
)
const TASK_FRAME_ORIGIN_POLICY_IDS := [
	FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
	HEADING_SEGMENT_ORIGIN_REANCHOR_POLICY_ID,
	WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID,
]
const BALANCED_WAVE_COMMAND_VALIDATION_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_command_validation_receipt_v1"
)
const BALANCED_WAVE_COMMAND_VALIDATION_MODE := (
	"native_balanced_wave_structure_and_receipts_v1"
)
const HEADING_OFFSET_COMMAND_KEYS := [
	"schema_version",
	"schedule_id",
	"segment_id",
	"command_role",
	"heading_offset_rad",
]
const HEADING_COMMAND_RECEIPT_KEYS := [
	"schema_version",
	"schedule_id",
	"segment_id",
	"command_role",
	"semantic_step",
	"reference_heading_rad",
	"heading_offset_rad",
	"desired_heading_rad",
	"world_build_count",
	"physics_state_modified",
	"adapter_actuation_applied",
	"physical_acceptance_authority",
]
const STABILITY_SHADOW_SUMMARY_VERSION := "sporespore_godot_jolt_stability_shadow_summary_v1"
const MAPPING_SHADOW_SUMMARY_VERSION := (
	"sporespore_godot_jolt_joint_mapping_shadow_summary_v1"
)
const CONTRIBUTION_SHADOW_SUMMARY_VERSION := (
	"sporespore_godot_jolt_stability_contribution_shadow_summary_v1"
)
# This strict default remains suitable for binary64-only comparisons. Physical
# Godot/Jolt campaigns must pass their separately preregistered host-mapping
# tolerance explicitly; the adapter records that value in its capability hash.
const DEFAULT_TOLERANCE := 1.0e-9
const GAIT_CYCLE_STEPS := 360
const CANDIDATE35_EVIDENCE_GAIT_STEPS := 4 * GAIT_CYCLE_STEPS
const MAXIMUM_PHASE_OFFSET_SYNCHRONIZATION_TICKS := 3
const STABILITY_SHADOW_ABSOLUTE_TOLERANCE := 5.0e-5
const JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM := 5.0e-5
const JOINT_MAPPING_NONZERO_TORQUE_NM := 1.0e-6
const MOTOR_RESPONSE_CHARACTERIZATION_SOURCE_COMMIT := (
	"c816ab36e4b696d8e8073fac88e6570242909609"
)
const MOTOR_RESPONSE_CHARACTERIZATION_REPORT_SHA256 := (
	"aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729"
)
const MOTOR_RESPONSE_LOCAL_FIT_GAIN := 1.00000003022822
const MOTOR_RESPONSE_MAXIMUM_FIT_RESIDUAL_RAD_S := 7.663529394408286e-10
const MOTOR_RESPONSE_UNCERTAINTY_FRACTION := 3.0654117577633144e-8
const CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM := 0.24999998477941607
const CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE := -1.0
const CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM := 0.2805286655276139
const CHARACTERIZED_MAXIMUM_VELOCITY_DELTA_RAD_S := 0.07013216211209337
const CHARACTERIZED_TESTED_LOCAL_VELOCITY_ENVELOPE_RAD_S := 0.075
const CONTRIBUTION_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD := 0.0
const CONTRIBUTION_MAXIMUM_POSITION_SLEW_PER_STEP_RAD := 0.0
const CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S := 0.075
const CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S := 0.010
const CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE := 5.0e-8
const P5I3B_WEIGHT_SUPPORT_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const P5I3C_FEEDBACK_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const BW9L_A_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw9l_a_v1"
)
const BW9L_B_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw9l_b_v1"
)
const BW9L_C_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw9l_c_v1"
)
const BW9L_D_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw9l_d_v1"
)
const BW9L_LOAD_TRANSFER_POLICY_IDS := [
	BW9L_A_LOAD_TRANSFER_POLICY_ID,
	BW9L_B_LOAD_TRANSFER_POLICY_ID,
	BW9L_C_LOAD_TRANSFER_POLICY_ID,
	BW9L_D_LOAD_TRANSFER_POLICY_ID,
]
const BW10F_A_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw10f_a_v2"
)
const BW10F_B_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw10f_b_v2"
)
const BW10F_C_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw10f_c_v2"
)
const BW10F_D_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw10f_d_v2"
)
const BW10F_LOAD_TRANSFER_POLICY_IDS := [
	BW10F_A_LOAD_TRANSFER_POLICY_ID,
	BW10F_B_LOAD_TRANSFER_POLICY_ID,
	BW10F_C_LOAD_TRANSFER_POLICY_ID,
	BW10F_D_LOAD_TRANSFER_POLICY_ID,
]
const BW11R_A_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw11r_a_v3"
)
const BW11R_B_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw11r_b_v3"
)
const BW11R_C_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw11r_c_v3"
)
const BW11R_D_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw11r_d_v3"
)
const BW11R_LOAD_TRANSFER_POLICY_IDS := [
	BW11R_A_LOAD_TRANSFER_POLICY_ID,
	BW11R_B_LOAD_TRANSFER_POLICY_ID,
	BW11R_C_LOAD_TRANSFER_POLICY_ID,
	BW11R_D_LOAD_TRANSFER_POLICY_ID,
]
const BW13P_A_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw13p_a_v3"
)
const BW13P_B_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw13p_b_v3"
)
const BW13P_C_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw13p_c_v3"
)
const BW13P_D_LOAD_TRANSFER_POLICY_ID := (
	"sporespore_scheduled_load_transfer_bw13p_d_v3"
)
const BW13P_LOAD_TRANSFER_POLICY_IDS := [
	BW13P_A_LOAD_TRANSFER_POLICY_ID,
	BW13P_B_LOAD_TRANSFER_POLICY_ID,
	BW13P_C_LOAD_TRANSFER_POLICY_ID,
	BW13P_D_LOAD_TRANSFER_POLICY_ID,
]
const P5I3C_OVERLAY_RUNTIME_ID := (
	"sporespore_godot_jolt_stability_overlay_runtime_v1"
)
const P5I3C_OVERLAY_MEMORY_ID := "sporespore_stability_overlay_memory_v1"
const P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M := 5.0
const P5I3C_HORIZONTAL_VELOCITY_GAIN_NS_PER_M := 0.1
const P5I3C_MAXIMUM_HORIZONTAL_FORCE_N := 0.75
const P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD := 0.5
const P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD := 0.05
const P5I3C_MAXIMUM_ROLL_PITCH_MOMENT_NM := 0.10
const P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S := 2.0e-8
const P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S := 1.2e-7
const CANDIDATE35_POLICY_ID := "g4_gq15_candidate35_v5"
const BALANCED_WAVE_POLICY_ID := "sporespore_balanced_wave_v1"
const BALANCED_WAVE_BW2_B_POLICY_ID := "sporespore_balanced_wave_bw2_b_v1"
const BALANCED_WAVE_BW2_C_POLICY_ID := "sporespore_balanced_wave_bw2_c_v1"
const BALANCED_WAVE_BW2R_A_POLICY_ID := "sporespore_balanced_wave_bw2r_a_v1"
const BALANCED_WAVE_BW2R_B_POLICY_ID := "sporespore_balanced_wave_bw2r_b_v1"
const BALANCED_WAVE_BW2R_C_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const BALANCED_WAVE_BW4R_A_POLICY_ID := "sporespore_balanced_wave_bw4r_a_v1"
const BALANCED_WAVE_BW4R_B_POLICY_ID := "sporespore_balanced_wave_bw4r_b_v1"
const BALANCED_WAVE_BW5R_A_POLICY_ID := "sporespore_balanced_wave_bw5r_a_v1"
const BALANCED_WAVE_BW5R_B_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const DEVELOPMENT_SWING_END_RECONTACT_POLICY_ID := "sporespore_balanced_wave_recovery_swing_end_recontact_v1"
const DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID := "sporespore_balanced_wave_recovery_bounded_support_v1"
const DEVELOPMENT_BOUNDED_SUPPORT_RECEIPT_SCHEMA := "sporespore_recovery_support_controller_step_receipt_v1"
const DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID := "sporespore_balanced_wave_recovery_floor_support_v1"
const DEVELOPMENT_FLOOR_SUPPORT_RECEIPT_SCHEMA := "sporespore_recovery_floor_support_controller_step_receipt_v1"
const DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID := "sporespore_balanced_wave_recovery_feasible_support_v1"
const DEVELOPMENT_FEASIBLE_SUPPORT_RECEIPT_SCHEMA := "sporespore_recovery_feasible_support_controller_step_receipt_v1"
const DEVELOPMENT_SMOOTH_SWING_POLICY_ID := "sporespore_balanced_wave_recovery_smooth_swing_v1"
const DEVELOPMENT_SMOOTH_SWING_RECEIPT_SCHEMA := "sporespore_recovery_smooth_swing_controller_step_receipt_v1"
const DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID := "sporespore_balanced_wave_recovery_reference_velocity_v1"
const DEVELOPMENT_REFERENCE_VELOCITY_RECEIPT_SCHEMA := "sporespore_recovery_reference_velocity_controller_step_receipt_v1"
const DEVELOPMENT_WAVE_VELOCITY_POLICY_ID := "sporespore_balanced_wave_recovery_wave_velocity_v1"
const DEVELOPMENT_WAVE_VELOCITY_RECEIPT_SCHEMA := "sporespore_recovery_wave_velocity_controller_step_receipt_v1"
const DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID := "sporespore_balanced_wave_recovery_airborne_reference_v1"
const DEVELOPMENT_AIRBORNE_REFERENCE_RECEIPT_SCHEMA := "sporespore_recovery_airborne_reference_controller_step_receipt_v1"
const DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID := "sporespore_balanced_wave_recovery_absent_contact_reference_v1"
const DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID := "sporespore_balanced_wave_recovery_upright_stance_v1"
const DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID := "sporespore_balanced_wave_recovery_support_progression_v1"
const DevelopmentMeasuredBody := preload("res://sdk/adapters/godot/gdscript/development_recovery_measured_body_source_v1.gd")
const DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID := "sporespore_balanced_wave_joint_pose_entry_v1"
## R10J: a zero-amplitude V50 hold session requests zero planar velocity on every command.
var _development_stationary_hold := false
const DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID := "sporespore_balanced_wave_recovery_extended_preparation_v1"
const DEVELOPMENT_EXTENDED_PREPARATION_RECEIPT_SCHEMA := "sporespore_recovery_extended_preparation_controller_step_receipt_v1"
const DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID := "sporespore_balanced_wave_recovery_initialized_zero_brake_v1"
const DEVELOPMENT_INITIALIZED_ZERO_BRAKE_RECEIPT_SCHEMA := "sporespore_recovery_initialized_zero_brake_controller_step_receipt_v1"
const DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID := "sporespore_balanced_wave_recovery_zero_velocity_brake_v1"
const DEVELOPMENT_ZERO_VELOCITY_BRAKE_RECEIPT_SCHEMA := "sporespore_recovery_zero_velocity_brake_controller_step_receipt_v1"
const DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID := "sporespore_balanced_wave_recovery_bounded_stop_velocity_v1"
const DEVELOPMENT_BOUNDED_STOP_VELOCITY_RECEIPT_SCHEMA := "sporespore_recovery_bounded_stop_velocity_controller_step_receipt_v1"
const DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID := "sporespore_balanced_wave_recovery_extended_support_transfer_v1"
const DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_RECEIPT_SCHEMA := "sporespore_recovery_extended_support_transfer_controller_step_receipt_v1"
const DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID := "sporespore_balanced_wave_recovery_joint_feasible_height_v1"
const DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_RECEIPT_SCHEMA := "sporespore_recovery_joint_feasible_height_controller_step_receipt_v1"
const DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID := "sporespore_balanced_wave_recovery_startup_reference_velocity_v1"
const DEVELOPMENT_STARTUP_VELOCITY_RECEIPT_SCHEMA := "sporespore_recovery_startup_reference_velocity_controller_step_receipt_v1"
const DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID := "sporespore_balanced_wave_recovery_remaining_support_release_v1"
const DEVELOPMENT_REMAINING_SUPPORT_RECEIPT_SCHEMA := "sporespore_recovery_remaining_support_release_controller_step_receipt_v1"
const DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID := "sporespore_balanced_wave_recovery_support_hold_posture_v1"
const DEVELOPMENT_SUPPORT_PROGRESSION_RECEIPT_SCHEMA := "sporespore_recovery_support_progression_controller_step_receipt_v1"
const DEVELOPMENT_SUPPORT_HOLD_POSTURE_RECEIPT_SCHEMA := "sporespore_recovery_support_hold_posture_controller_step_receipt_v1"
const DEVELOPMENT_STANCE_LATCH_POLICY_ID := "sporespore_balanced_wave_recovery_stance_latched_upright_v1"
const DEVELOPMENT_STANCE_LATCH_RECEIPT_SCHEMA := "sporespore_recovery_stance_latched_upright_controller_step_receipt_v1"
const DEVELOPMENT_ABSENT_CONTACT_REFERENCE_RECEIPT_SCHEMA := "sporespore_recovery_absent_contact_reference_controller_step_receipt_v1"
const DEVELOPMENT_UPRIGHT_STANCE_RECEIPT_SCHEMA := "sporespore_recovery_upright_stance_controller_step_receipt_v1"
const DevelopmentFloor := preload("res://sdk/adapters/godot/gdscript/development_recovery_floor_source_v1.gd")
const BALANCED_WAVE_BW5R_C_POLICY_ID := "sporespore_balanced_wave_bw5r_c_v1"
const BALANCED_WAVE_BW7D_A_POLICY_ID := "sporespore_balanced_wave_bw7d_a_v1"
const BALANCED_WAVE_BW7D_B_POLICY_ID := "sporespore_balanced_wave_bw7d_b_v1"
const BALANCED_WAVE_BW7D_C_POLICY_ID := "sporespore_balanced_wave_bw7d_c_v1"
const BALANCED_WAVE_BW7D_D_POLICY_ID := "sporespore_balanced_wave_bw7d_d_v1"
const BALANCED_WAVE_BW8U_A_POLICY_ID := "sporespore_balanced_wave_bw8u_a_v1"
const BALANCED_WAVE_BW8U_B_POLICY_ID := "sporespore_balanced_wave_bw8u_b_v1"
const BALANCED_WAVE_BW8U_C_POLICY_ID := "sporespore_balanced_wave_bw8u_c_v1"
const BALANCED_WAVE_BW8U_D_POLICY_ID := "sporespore_balanced_wave_bw8u_d_v1"
const BALANCED_WAVE_BW14V_B_POLICY_ID := "sporespore_balanced_wave_bw14v_b_v1"
const BALANCED_WAVE_BW15F_B_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const BALANCED_WAVE_BW15F_C_POLICY_ID := "sporespore_balanced_wave_bw15f_c_v1"
const BALANCED_WAVE_BW15F_D_POLICY_ID := "sporespore_balanced_wave_bw15f_d_v1"
const BALANCED_WAVE_BW21L_B_POLICY_ID := "sporespore_balanced_wave_bw21l_b_v1"
const BALANCED_WAVE_BW21L_C_POLICY_ID := "sporespore_balanced_wave_bw21l_c_v1"
const BALANCED_WAVE_BW21L_D_POLICY_ID := "sporespore_balanced_wave_bw21l_d_v1"
const BALANCED_WAVE_BW23Y_B_POLICY_ID := "sporespore_balanced_wave_bw23y_b_v1"
const BALANCED_WAVE_BW34Y_A_POLICY_ID := "sporespore_balanced_wave_bw34y_a_v1"
const BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID := (
	"sporespore_balanced_wave_r23d19_heading_aligned_path_v1"
)
const BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID := (
	"sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1"
)
const BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1"
)
const FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID := "forward_velocity_foot_placement_v1"
const DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID := (
	"desired_minus_measured_forward_velocity_error_v1"
)
const MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID := (
	"measured_minus_desired_forward_velocity_error_v1"
)
const BALANCED_WAVE_POLICY_IDS := [
	BALANCED_WAVE_POLICY_ID,
	BALANCED_WAVE_BW2_B_POLICY_ID,
	BALANCED_WAVE_BW2_C_POLICY_ID,
	BALANCED_WAVE_BW2R_A_POLICY_ID,
	BALANCED_WAVE_BW2R_B_POLICY_ID,
	BALANCED_WAVE_BW2R_C_POLICY_ID,
	BALANCED_WAVE_BW4R_A_POLICY_ID,
	BALANCED_WAVE_BW4R_B_POLICY_ID,
	BALANCED_WAVE_BW5R_A_POLICY_ID,
	BALANCED_WAVE_BW5R_B_POLICY_ID,
	DEVELOPMENT_SWING_END_RECONTACT_POLICY_ID,
	DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID,
	DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID,
	DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID,
	DEVELOPMENT_SMOOTH_SWING_POLICY_ID,
	DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID, DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID,
	BALANCED_WAVE_BW5R_C_POLICY_ID,
	BALANCED_WAVE_BW7D_A_POLICY_ID,
	BALANCED_WAVE_BW7D_B_POLICY_ID,
	BALANCED_WAVE_BW7D_C_POLICY_ID,
	BALANCED_WAVE_BW7D_D_POLICY_ID,
	BALANCED_WAVE_BW8U_A_POLICY_ID,
	BALANCED_WAVE_BW8U_B_POLICY_ID,
	BALANCED_WAVE_BW8U_C_POLICY_ID,
	BALANCED_WAVE_BW8U_D_POLICY_ID,
	BALANCED_WAVE_BW14V_B_POLICY_ID,
	BALANCED_WAVE_BW15F_B_POLICY_ID,
	BALANCED_WAVE_BW15F_C_POLICY_ID,
	BALANCED_WAVE_BW15F_D_POLICY_ID,
	BALANCED_WAVE_BW21L_B_POLICY_ID,
	BALANCED_WAVE_BW21L_C_POLICY_ID,
	BALANCED_WAVE_BW21L_D_POLICY_ID,
	BALANCED_WAVE_BW23Y_B_POLICY_ID,
	BALANCED_WAVE_BW34Y_A_POLICY_ID,
	BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
	BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
	BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID,
]
const BALANCED_WAVE_RUNTIME_VERSION := "sporespore_balanced_wave_runtime_v1"
const BALANCED_WAVE_MEMORY_VERSION := "sporespore_balanced_wave_memory_v1"
const BALANCED_WAVE_PERSISTENT_PREDICTIVE_GUARD_MEMORY_VERSION := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const BALANCED_WAVE_MEMORY_SCHEMA_RECEIPT_VERSION := (
	"sporespore_balanced_wave_memory_schema_receipt_v1"
)
const R23D2_ORACLE_TRACE_ENVIRONMENT_VARIABLE := (
	"SPORESPORE_QSDK_R23D2_GODOT_JOLT_ORACLE_TRACE"
)
const R23D2_ORACLE_TRACE_ENABLE_VALUE := "sporespore_qsdk_r23d2_oracle_trace_v1"
const R23D2_ORACLE_RECEIPT_FIELDS := [
	"cross_track_error_m",
	"cross_track_velocity_m_s",
	"measured_yaw_error_rad",
	"desired_heading_error_rad",
	"yaw_tracking_error_rad",
]
const LEGACY_SUPPORT_CONTACT_ORDER := [
	"front_left_foot",
	"rear_left_foot",
	"rear_right_foot",
	"front_right_foot",
]

var _api: Object
var _development_floor_source: Dictionary = {}
var _extension_resource: Resource
var _descriptor: Dictionary = {}
var _compiled: Dictionary = {}
var _memory: Dictionary = {}
var _initial_origin_world_m := Vector3.ZERO
var _active_task_frame_origin_world_m := Vector3.ZERO
var _active_task_frame_schedule_id := ""
var _active_task_frame_segment_id := ""
var _task_frame_origin_reanchor_count := 0
var _task_frame_origin_policy_id := FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID
var _initial_lateral_axis_world := Vector3.BACK
var _initial_forward_axis_world := Vector3.RIGHT
var _initial_legacy_yaw_rad := 0.0
var _canonical_initial_heading_rad := 0.0
var _physics_hz := 120
var _tolerance := DEFAULT_TOLERANCE
var _requested_phase_progression_mode := ""
var _adapter_manifest: Dictionary = {}
var _adapter_capability_sha256 := ""
var _transport_execution_contract: Dictionary = {}
var _transport_execution_contract_sha256 := ""
var _controller_session_execution_contract: Dictionary = {}
var _controller_session_execution_contract_sha256 := ""
var _controller_session_receipt: Dictionary = {}
var _controller_session_shutdown_receipt: Dictionary = {}
var _shutdown_completed := false
var _actuation_authority_enabled := false
var _authority_scope := "shadow"
var _stability_policy_id := P5I3B_WEIGHT_SUPPORT_POLICY_ID
var _stability_influence_scale_enabled := false
var _stability_influence_global_scale := 1.0
var _stability_contribution_shadow_only_until_terminal := false
var _external_terminal_application_step_count := 0
var _external_terminal_motor_write_count := 0
var _external_terminal_previous_semantic_step := -1
var _controller_policy_id := CANDIDATE35_POLICY_ID
var _development_native_step_failure_retention_enabled := false
var _controller_runtime_version := ""
var _controller_profile: Dictionary = {}
var _controller_profile_sha256 := ""
var _material_profile: Dictionary = {}
var _material_profile_sha256 := ""
var _characterized_controller_friction_coefficient := 1.0
var _started := false
var _start_failure_code := ""
var _step_count := 0
var _compared_actuator_command_count := 0
var _validated_balanced_wave_command_count := 0
var _balanced_wave_step_receipt_count := 0
var _balanced_wave_native_validation_step_count := 0
var _balanced_wave_heading_conditioned_step_count := 0
var _balanced_wave_unconditioned_step_count := 0
var _balanced_wave_first_step_receipt_sha256 := ""
var _balanced_wave_last_step_receipt_sha256 := ""
var _r23d2_oracle_trace_enabled := false
var _r23d2_oracle_trace: Array[Dictionary] = []
var _release_gate_unweighting_receipt_count := 0
var _release_gate_knee_override_step_count := 0
var _release_gate_hip_override_step_count := 0
var _release_gate_knee_override_limb_count := 0
var _release_gate_hip_override_limb_count := 0
var _forward_velocity_foot_placement_receipt_count := 0
var _maximum_absolute_normalized_forward_velocity_error := 0.0
var _maximum_absolute_forward_velocity_hip_target_correction_rad := 0.0
var _steering_feedback_update_count := 0
var _steering_filter_application_count := 0
var _steering_saturation_count := 0
var _steering_slew_limited_count := 0
var _maximum_absolute_requested_steering_fraction := 0.0
var _maximum_absolute_filtered_steering_fraction := 0.0
var _maximum_absolute_steering_delta_per_step := 0.0
var _cumulative_absolute_cross_track_error_m_steps := 0.0
var _minimum_cross_track_error_m := INF
var _maximum_cross_track_error_m := -INF
var _mismatch_count := 0
var _safe_no_actuation_count := 0
var _native_actuation_application_count := 0
var _native_safe_disable_application_count := 0
var _maximum_absolute_target_position_error_rad := 0.0
var _maximum_absolute_target_velocity_error_rad_s := 0.0
var _maximum_absolute_speed_limit_error_rad_s := 0.0
var _maximum_absolute_phase_error_steps := 0
var _maximum_absolute_steering_error := 0.0
var _failure_codes: Array[String] = []
var _failure_details: Array[Dictionary] = []
var _first_phase_mismatch_detail: Dictionary = {}
var _first_large_command_mismatch_detail: Dictionary = {}
var _phase_offset_synchronization_scheduled := false
var _requested_phase_offset_ticks := 0
var _phase_offset_activation_semantic_step := -1
var _phase_offset_application_count := 0
var _phase_offset_synchronized_limb_count := 0
var _phase_offset_representation_shift_ticks := 0
var _stability_shadow_attempt_count := 0
var _stability_shadow_available_count := 0
var _stability_shadow_unavailable_count := 0
var _stability_shadow_mismatch_count := 0
var _stability_shadow_failure_codes: Array[String] = []
var _stability_shadow_maximum_error_by_field: Dictionary = {}
var _mapping_shadow_attempt_count := 0
var _mapping_shadow_available_count := 0
var _mapping_shadow_unavailable_count := 0
var _mapping_shadow_infeasible_count := 0
var _mapping_shadow_mismatch_count := 0
var _mapping_shadow_compared_actuator_count := 0
var _mapping_shadow_maximum_absolute_torque_error_nm := 0.0
var _mapping_shadow_maximum_absolute_commanded_torque_nm := 0.0
var _mapping_shadow_outcome_codes: Array[String] = []
var _mapping_shadow_failure_codes: Array[String] = []
var _contribution_previous_semantic_step := -1
var _contribution_previous_applied_corrections: Array = []
var _contribution_attempt_count := 0
var _contribution_full_support_attempt_count := 0
var _contribution_partial_support_attempt_count := 0
var _contribution_available_count := 0
var _contribution_upstream_infeasible_count := 0
var _contribution_unavailable_count := 0
var _contribution_untyped_count := 0
var _contribution_ordered_command_count := 0
var _contribution_active_command_count := 0
var _contribution_inactive_command_count := 0
var _contribution_influence_output_count := 0
var _contribution_fallback_zero_output_count := 0
var _contribution_inactive_hard_zero_transition_count := 0
var _contribution_profile_input_clamped_count := 0
var _contribution_profile_conversion_failure_count := 0
var _contribution_feedback_nonzero_attempt_count := 0
var _contribution_nonzero_active_command_count := 0
var _contribution_slew_limited_output_count := 0
var _contribution_magnitude_saturated_output_count := 0
var _contribution_mismatch_count := 0
var _contribution_full_v3_v2_compared_count := 0
var _contribution_limiter_mismatch_count := 0
var _contribution_inactive_zero_mismatch_count := 0
var _contribution_maximum_full_v3_v2_torque_error_nm := 0.0
var _contribution_maximum_active_oracle_torque_error_nm := 0.0
var _contribution_maximum_absolute_commanded_torque_nm := 0.0
var _contribution_maximum_absolute_profile_input_torque_nm := 0.0
var _contribution_maximum_absolute_proposed_velocity_rad_s := 0.0
var _contribution_maximum_absolute_applied_velocity_rad_s := 0.0
var _contribution_maximum_absolute_host_delta_rad_s := 0.0
var _contribution_maximum_limiter_reconstruction_error := 0.0
var _contribution_failure_codes: Array[String] = []
var _scheduled_load_transfer_receipt_count := 0
var _scheduled_load_transfer_active_step_count := 0
var _scheduled_load_transfer_unweighted_contact_count := 0
var _scheduled_load_transfer_preferred_normal_step_count := 0
var _scheduled_load_transfer_remaining_centroid_step_count := 0
var _scheduled_load_transfer_available_receipt_count := 0
var _scheduled_load_transfer_unavailable_receipt_count := 0
var _scheduled_load_transfer_upstream_infeasible_receipt_count := 0
var _scheduled_load_transfer_fail_zero_receipt_count := 0
var _scheduled_load_transfer_first_receipt_sha256 := ""
var _scheduled_load_transfer_last_receipt_sha256 := ""
var _stability_overlay_application_step_count := 0
var _stability_overlay_motor_write_count := 0
var _portable_controller_base_application_count := 0
var _stability_overlay_nonzero_effective_application_count := 0
var _stability_overlay_host_saturation_count := 0
var _stability_overlay_combined_speed_limit_violation_count := 0
var _stability_overlay_failure_count := 0
var _stability_overlay_maximum_absolute_requested_delta_rad_s := 0.0
var _stability_overlay_maximum_absolute_effective_delta_rad_s := 0.0
var _stability_overlay_maximum_readback_error_rad_s := 0.0
var _stability_overlay_maximum_host_command_quantization_error_rad_s := 0.0
var _stability_overlay_failure_codes: Array[String] = []


func start(
	descriptor: Dictionary,
	initial_gait_step_by_limb: Dictionary,
	initial_held_steering_fraction: float,
	initial_origin_world_m: Vector3,
	initial_lateral_axis_world: Vector3,
	initial_yaw_rad: float,
	physics_hz: int,
	realized_solver_policy: Dictionary,
	tolerance: float = DEFAULT_TOLERANCE,
	initial_phase_progression_mode: String = "contact_gated",
	actuation_authority_enabled: bool = false,
	requested_phase_offset_ticks: int = 0,
	phase_offset_activation_semantic_step: int = -1,
	authority_scope: String = "shadow",
	stability_policy_id: String = P5I3B_WEIGHT_SUPPORT_POLICY_ID,
	requested_material_profile: Dictionary = {},
	controller_policy_id: String = CANDIDATE35_POLICY_ID,
	stability_influence_global_scale: float = -1.0,
	stability_contribution_shadow_only_until_terminal: bool = false,
	task_frame_origin_policy_id: String = FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
	use_preloaded_native_runtime: bool = false,
) -> Dictionary:
	if _started:
		return _failure("ADAPTER_ALREADY_STARTED")
	if descriptor.is_empty():
		return _failure("ADAPTER_DESCRIPTOR_MISSING")
	if (
		not is_finite(initial_held_steering_fraction)
		or not initial_origin_world_m.is_finite()
		or not initial_lateral_axis_world.is_finite()
		or initial_lateral_axis_world.length_squared() <= 1.0e-12
		or not is_finite(initial_yaw_rad)
		or physics_hz <= 0
		or not is_finite(tolerance)
		or tolerance < 0.0
		or not is_finite(stability_influence_global_scale)
		or (
			stability_influence_global_scale != -1.0
			and (
				stability_influence_global_scale < 0.0
				or stability_influence_global_scale > 1.0
			)
		)
		or not ["clocked", "contact_gated"].has(initial_phase_progression_mode)
		or not TASK_FRAME_ORIGIN_POLICY_IDS.has(task_frame_origin_policy_id)
		or phase_offset_activation_semantic_step < -1
		or absi(requested_phase_offset_ticks) > MAXIMUM_PHASE_OFFSET_SYNCHRONIZATION_TICKS
		or (
			phase_offset_activation_semantic_step == -1
			and requested_phase_offset_ticks != 0
		)
		or not [
			"shadow",
			"evidence_handoff",
			"post_settle_full",
			"stability_contribution_overlay",
		].has(authority_scope)
		or not [
			P5I3B_WEIGHT_SUPPORT_POLICY_ID,
			P5I3C_FEEDBACK_POLICY_ID,
			BW9L_A_LOAD_TRANSFER_POLICY_ID,
			BW9L_B_LOAD_TRANSFER_POLICY_ID,
			BW9L_C_LOAD_TRANSFER_POLICY_ID,
			BW9L_D_LOAD_TRANSFER_POLICY_ID,
			BW10F_A_LOAD_TRANSFER_POLICY_ID,
			BW10F_B_LOAD_TRANSFER_POLICY_ID,
			BW10F_C_LOAD_TRANSFER_POLICY_ID,
			BW10F_D_LOAD_TRANSFER_POLICY_ID,
			BW11R_A_LOAD_TRANSFER_POLICY_ID,
			BW11R_B_LOAD_TRANSFER_POLICY_ID,
			BW11R_C_LOAD_TRANSFER_POLICY_ID,
			BW11R_D_LOAD_TRANSFER_POLICY_ID,
			BW13P_A_LOAD_TRANSFER_POLICY_ID,
			BW13P_B_LOAD_TRANSFER_POLICY_ID,
			BW13P_C_LOAD_TRANSFER_POLICY_ID,
			BW13P_D_LOAD_TRANSFER_POLICY_ID,
		].has(stability_policy_id)
		or (
			stability_influence_global_scale >= 0.0
			and (
				not actuation_authority_enabled
				or authority_scope != "post_settle_full"
				or not BW13P_LOAD_TRANSFER_POLICY_IDS.has(stability_policy_id)
			)
		)
		or (
			stability_contribution_shadow_only_until_terminal
			and (
				not actuation_authority_enabled
				or authority_scope != "post_settle_full"
				or not _is_balanced_wave_policy(controller_policy_id)
				or stability_policy_id != BW13P_A_LOAD_TRANSFER_POLICY_ID
				or stability_influence_global_scale != 0.5
			)
		)
		or not [
			CANDIDATE35_POLICY_ID,
			BALANCED_WAVE_POLICY_ID,
			BALANCED_WAVE_BW2_B_POLICY_ID,
			BALANCED_WAVE_BW2_C_POLICY_ID,
			BALANCED_WAVE_BW2R_A_POLICY_ID,
			BALANCED_WAVE_BW2R_B_POLICY_ID,
			BALANCED_WAVE_BW2R_C_POLICY_ID,
			BALANCED_WAVE_BW4R_A_POLICY_ID,
			BALANCED_WAVE_BW4R_B_POLICY_ID,
			BALANCED_WAVE_BW5R_A_POLICY_ID,
			BALANCED_WAVE_BW5R_B_POLICY_ID,
			DEVELOPMENT_SWING_END_RECONTACT_POLICY_ID,
			DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID,
			DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID,
			DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID,
			DEVELOPMENT_SMOOTH_SWING_POLICY_ID,
			DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID, DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID,
			BALANCED_WAVE_BW5R_C_POLICY_ID,
			BALANCED_WAVE_BW7D_A_POLICY_ID,
			BALANCED_WAVE_BW7D_B_POLICY_ID,
			BALANCED_WAVE_BW7D_C_POLICY_ID,
			BALANCED_WAVE_BW7D_D_POLICY_ID,
			BALANCED_WAVE_BW8U_A_POLICY_ID,
			BALANCED_WAVE_BW8U_B_POLICY_ID,
			BALANCED_WAVE_BW8U_C_POLICY_ID,
			BALANCED_WAVE_BW8U_D_POLICY_ID,
			BALANCED_WAVE_BW14V_B_POLICY_ID,
			BALANCED_WAVE_BW15F_B_POLICY_ID,
			BALANCED_WAVE_BW15F_C_POLICY_ID,
			BALANCED_WAVE_BW15F_D_POLICY_ID,
			BALANCED_WAVE_BW21L_B_POLICY_ID,
			BALANCED_WAVE_BW21L_C_POLICY_ID,
			BALANCED_WAVE_BW21L_D_POLICY_ID,
			BALANCED_WAVE_BW23Y_B_POLICY_ID,
			BALANCED_WAVE_BW34Y_A_POLICY_ID,
			BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
			BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
			BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID,
		].has(controller_policy_id)
		or (
			_is_balanced_wave_policy(controller_policy_id)
			and actuation_authority_enabled
			and authority_scope != "stability_contribution_overlay"
			and not (
				[
					BALANCED_WAVE_BW5R_B_POLICY_ID,
					DEVELOPMENT_SWING_END_RECONTACT_POLICY_ID,
					DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID,
					DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID,
					DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID,
					DEVELOPMENT_SMOOTH_SWING_POLICY_ID,
					DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID, DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID,
					BALANCED_WAVE_BW14V_B_POLICY_ID,
					BALANCED_WAVE_BW15F_B_POLICY_ID,
					BALANCED_WAVE_BW15F_C_POLICY_ID,
					BALANCED_WAVE_BW15F_D_POLICY_ID,
					BALANCED_WAVE_BW21L_B_POLICY_ID,
					BALANCED_WAVE_BW21L_C_POLICY_ID,
					BALANCED_WAVE_BW21L_D_POLICY_ID,
					BALANCED_WAVE_BW23Y_B_POLICY_ID,
					BALANCED_WAVE_BW34Y_A_POLICY_ID,
					BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID,
					BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID,
					BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID,
				].has(controller_policy_id)
				and authority_scope == "post_settle_full"
			)
		)
		or (
			authority_scope == "stability_contribution_overlay"
			and (
				not actuation_authority_enabled
				or not _is_stability_feedback_authority_policy(stability_policy_id)
			)
		)
		or (
			not actuation_authority_enabled
			and authority_scope != "shadow"
		)
	):
		return _failure("ADAPTER_START_INPUT_INVALID")
	# The new policy requires an explicitly loaded, bound development runtime.
	# The ordinary SDK/default-extension path cannot select it accidentally.
	if controller_policy_id in [DEVELOPMENT_SWING_END_RECONTACT_POLICY_ID, DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID, DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID, DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID, DEVELOPMENT_SMOOTH_SWING_POLICY_ID, DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID, DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID] and not use_preloaded_native_runtime:
		return _failure("ADAPTER_DEVELOPMENT_POLICY_RUNTIME_REQUIRED")
	var material_profile_result := MaterialProfilesScript.validate_resolved_profile(
		requested_material_profile,
		realized_solver_policy,
	)
	if not bool(material_profile_result.get("ok", false)):
		return _failure(
			"ADAPTER_MATERIAL_PROFILE_INVALID",
			String(material_profile_result.get("failure_code", "")),
		)
	if physics_hz != int(realized_solver_policy.get("physics_hz", -1)):
		return _failure(
			"ADAPTER_MATERIAL_PROFILE_INVALID",
			"MATERIAL_PROFILE_PHYSICS_HZ_ARGUMENT_MISMATCH",
		)
	_material_profile = (
		material_profile_result["profile"] as Dictionary
	).duplicate(true)
	_material_profile_sha256 = String(
		material_profile_result["profile_sha256"]
	)
	_characterized_controller_friction_coefficient = float(
		_material_profile["characterized_friction_coefficient"]
	)
	# An explicitly selected runtime must not be replaced by the default DLL.
	# The caller owns its runtime binding; still create a fresh SDK/session here.
	# Ordinary callers retain the original default-extension loading path.
	if not use_preloaded_native_runtime:
		_extension_resource = load(EXTENSION_PATH)
		if _extension_resource == null:
			return _failure("ADAPTER_EXTENSION_RESOURCE_UNAVAILABLE")
	if not ClassDB.class_exists(NATIVE_CLASS_NAME):
		return _failure("ADAPTER_NATIVE_CLASS_UNAVAILABLE")
	_api = ClassDB.instantiate(NATIVE_CLASS_NAME)
	if _api == null:
		return _failure("ADAPTER_NATIVE_CLASS_INSTANTIATION_FAILED")
	var transport_receipt := _validate_transport_api(_api)
	if not bool(transport_receipt.get("ok", false)):
		return _failure(
			String(transport_receipt.get("failure_code", "ADAPTER_TRANSPORT_PREFLIGHT_FAILED")),
			String(transport_receipt.get("detail", "")),
		)
	_transport_execution_contract = (
		transport_receipt["transport_execution_contract"] as Dictionary
	).duplicate(true)
	_transport_execution_contract_sha256 = String(
		transport_receipt["transport_execution_contract_sha256"]
	)
	_controller_session_execution_contract = (
		transport_receipt["controller_session_execution_contract"] as Dictionary
	).duplicate(true)
	_controller_session_execution_contract_sha256 = String(
		transport_receipt["controller_session_execution_contract_sha256"]
	)
	_descriptor = descriptor.duplicate(true)
	_controller_policy_id = controller_policy_id
	var compile_envelope := _call_input("compile_bounded_quadruped_json", _descriptor)
	if not bool(compile_envelope.get("ok", false)):
		return _failure(
			"ADAPTER_DESCRIPTOR_COMPILE_FAILED",
			String(compile_envelope.get("failure_code", "")),
		)
	_compiled = compile_envelope["value"]
	var profile_request := _descriptor
	if _is_balanced_wave_policy(_controller_policy_id):
		profile_request = {
			"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": _controller_policy_id,
			"descriptor": _descriptor,
		}
	var profile_envelope := _call_input(_controller_profile_method(), profile_request)
	if not bool(profile_envelope.get("ok", false)):
		return _failure(
			"ADAPTER_CONTROLLER_PROFILE_FAILED",
			String(profile_envelope.get("failure_code", "")),
		)
	_controller_profile = (profile_envelope["value"] as Dictionary).duplicate(true)
	if String(_controller_profile.get("policy_id", "")) != _controller_policy_id:
		return _failure("ADAPTER_CONTROLLER_PROFILE_IDENTITY_MISMATCH")
	_controller_profile_sha256 = CanonicalJsonScript.sha256(_controller_profile)
	_controller_runtime_version = String(_api.call(_controller_runtime_version_method()))
	if _is_balanced_wave_policy(_controller_policy_id):
		var session_envelope := _call_input(
			"balanced_wave_policy_session_create_json",
			{
				"schema_version":
				"sporespore_balanced_wave_policy_session_create_request_v1",
				"policy_id": _controller_policy_id,
				"descriptor": _descriptor,
			},
		)
		if not bool(session_envelope.get("ok", false)):
			return _failure(
				"ADAPTER_CONTROLLER_SESSION_CREATE_FAILED",
				String(session_envelope.get("failure_code", "")),
			)
		_controller_session_receipt = (
			session_envelope.get("value", {}) as Dictionary
		).duplicate(true)
		if (
			String(_controller_session_receipt.get("schema_version", ""))
			!= "sporespore_godot_balanced_wave_policy_session_receipt_v1"
			or String(_controller_session_receipt.get("execution_version", ""))
			!= CONTROLLER_SESSION_EXECUTION_VERSION
			or not bool(_controller_session_receipt.get("active", false))
			or int(_controller_session_receipt.get("world_build_count", -1)) != 0
			or bool(
				_controller_session_receipt.get("physical_acceptance_authority", true)
			)
		):
			return _failure("ADAPTER_CONTROLLER_SESSION_RECEIPT_INVALID")
	var memory_envelope := _controller_initial_memory()
	if not bool(memory_envelope.get("ok", false)):
		return _failure(
			"ADAPTER_MEMORY_INITIALIZATION_FAILED",
			String(memory_envelope.get("failure_code", "")),
		)
	_memory = (memory_envelope["value"] as Dictionary).duplicate(true)
	var expected_limb_ids: Array = (
		(_compiled["morphology"] as Dictionary)["ordered_limb_ids"] as Array
	)
	if expected_limb_ids.size() != initial_gait_step_by_limb.size():
		return _failure("ADAPTER_INITIAL_PHASE_CARDINALITY_MISMATCH")
	var memory_by_limb: Dictionary = {}
	for limb_memory_value in _memory["ordered_limb_memory"]:
		var limb_memory: Dictionary = limb_memory_value
		memory_by_limb[String(limb_memory["limb_id"])] = limb_memory
	for limb_id_value in expected_limb_ids:
		var limb_id := String(limb_id_value)
		if not initial_gait_step_by_limb.has(limb_id) or not memory_by_limb.has(limb_id):
			return _failure("ADAPTER_INITIAL_PHASE_LIMB_MISMATCH", limb_id)
		(memory_by_limb[limb_id] as Dictionary)["gait_step"] = int(
			initial_gait_step_by_limb[limb_id]
		)
	_memory["held_path_steering_fraction"] = initial_held_steering_fraction
	var phase_mode_result := _configure_phase_progression_mode(initial_phase_progression_mode)
	if not bool(phase_mode_result.get("ok", false)):
		return phase_mode_result
	_initial_origin_world_m = initial_origin_world_m
	_active_task_frame_origin_world_m = initial_origin_world_m
	_active_task_frame_schedule_id = ""
	_active_task_frame_segment_id = ""
	_task_frame_origin_reanchor_count = 0
	_task_frame_origin_policy_id = task_frame_origin_policy_id
	_initial_lateral_axis_world = initial_lateral_axis_world
	_initial_lateral_axis_world.y = 0.0
	_initial_lateral_axis_world = _initial_lateral_axis_world.normalized()
	_initial_forward_axis_world = Vector3.UP.cross(_initial_lateral_axis_world).normalized()
	# Godot's conventional body forward is local -Z and right is local +X.
	# Rotate those host-local axes into the SDK's +X-forward, +Z-right body
	# frame. The equivalent canonical initial heading is the legacy Godot
	# heading minus one quarter turn.
	_initial_legacy_yaw_rad = initial_yaw_rad
	_canonical_initial_heading_rad = _wrap_angle(initial_yaw_rad - PI * 0.5)
	_physics_hz = physics_hz
	_tolerance = tolerance
	_actuation_authority_enabled = actuation_authority_enabled
	_authority_scope = authority_scope
	_stability_policy_id = stability_policy_id
	_stability_influence_scale_enabled = stability_influence_global_scale >= 0.0
	_stability_influence_global_scale = (
		stability_influence_global_scale
		if _stability_influence_scale_enabled
		else 1.0
	)
	_stability_contribution_shadow_only_until_terminal = (
		stability_contribution_shadow_only_until_terminal
	)
	_phase_offset_synchronization_scheduled = phase_offset_activation_semantic_step >= 0
	_requested_phase_offset_ticks = requested_phase_offset_ticks
	_phase_offset_activation_semantic_step = phase_offset_activation_semantic_step
	_adapter_manifest = {
		"schema_version":
		(
			MANIFEST_SCHEMA_V16_VERSION
			if _task_frame_origin_policy_id != FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID
			else (
				MANIFEST_SCHEMA_V15_VERSION
				if _is_scheduled_load_transfer_v3_policy(_stability_policy_id)
				else MANIFEST_SCHEMA_VERSION
			)
		),
		"adapter_id": "godot_jolt_gdextension_v1",
		"transport_execution": _transport_execution_contract.duplicate(true),
		"transport_execution_contract_sha256": _transport_execution_contract_sha256,
		"controller_session_execution": (
			_controller_session_execution_contract.duplicate(true)
		),
		"controller_session_execution_contract_sha256": (
			_controller_session_execution_contract_sha256
		),
		"controller_session_receipt": _controller_session_receipt.duplicate(true),
		"authority_scope": _authority_scope,
		"stability_policy_id": _stability_policy_id,
		"stability_influence_global_scale":
		_stability_influence_global_scale,
		"stability_contribution_shadow_only_until_terminal":
		_stability_contribution_shadow_only_until_terminal,
		"stability_influence_scale_authority":
		(
			"portable_core_v3"
			if _stability_influence_scale_enabled
			else "legacy_v2_unscaled"
		),
		"controller_policy_id": _controller_policy_id,
		"controller_runtime_version": _controller_runtime_version,
		"controller_profile": _controller_profile.duplicate(true),
		"controller_profile_sha256": _controller_profile_sha256,
		"candidate35_runtime_version":
		(
			_controller_runtime_version
			if _controller_policy_id == CANDIDATE35_POLICY_ID
			else ""
		),
		"balanced_wave_runtime_version":
		(
			_controller_runtime_version
			if _is_balanced_wave_policy(_controller_policy_id)
			else ""
		),
		"godot_api_version": "4.7",
		"physics_engine": String(realized_solver_policy.get("physics_engine", "")),
		"physics_hz": physics_hz,
		"solver_velocity_steps": int(realized_solver_policy.get("solver_velocity_steps", -1)),
		"solver_position_steps": int(realized_solver_policy.get("solver_position_steps", -1)),
		"sampling_phase": "pre_step_after_previous_physics_frame",
		"phase_progression_modes": ["clocked", "contact_gated"],
		"phase_offset_synchronization":
		{
			"supported": true,
			"minimum_offset_ticks": -MAXIMUM_PHASE_OFFSET_SYNCHRONIZATION_TICKS,
			"maximum_offset_ticks": MAXIMUM_PHASE_OFFSET_SYNCHRONIZATION_TICKS,
			"application_mode": "one_time_before_scheduled_sample",
			"gait_step_representation": "nonnegative_u64_cycle_epoch",
			"cycle_steps": GAIT_CYCLE_STEPS,
			"underflow_policy": "common_whole_cycle_shift_preserves_relative_phase",
		},
		"actuator_model": "hinge_target_velocity_with_impulse_cap",
		"actuator_capabilities":
		{
			"position_target": "adapter_pd_to_velocity",
			"velocity_target": "native_hinge_motor",
			"effort_target": "unavailable",
			"impulse_limit": "native_per_step_cap",
			"saturation": "core_then_host",
			"rate_limit": "core_only",
		},
		"contact_quality": "qualified_bearing",
		"normal_load_available": false,
		"contact_capabilities":
		{
			"presence": "qualified",
			"bears_support": "qualified",
			"point": "host_observer_only",
			"normal": "host_observer_only",
			"relative_velocity": "host_observer_only",
			"raw_impulse": "host_observer_only",
			"normal_load": "unavailable",
			"persistence": "per_step_engine_contact_id",
			"friction": "manifest_material_only",
			"contact_site_shape_model": "one_semantic_shape_per_contact_site",
			"multi_shape_contact_sites_supported": false,
		},
		"stability_v2":
		{
			"state_emission": "ordered_body_and_qualified_contact_state",
			"observation": "native_core_shadow_against_gdscript_oracle",
			"comparison_absolute_tolerance": STABILITY_SHADOW_ABSOLUTE_TOLERANCE,
			"contact_geometry_aggregation":
			"arithmetic_mean_per_semantic_site_per_step",
			"contact_normal_direction": "local_body_contact_normal_world",
			"contact_material_identity": "godot_jolt_fixture_material",
			"missing_support": "observation_unavailable",
			"material_characterization":
			{
				"profile": _material_profile.duplicate(true),
				"profile_sha256": _material_profile_sha256,
				"source_commit":
				String(_material_profile["characterization_source_commit"]),
				"report_sha256":
				String(_material_profile["characterization_report_sha256"]),
				"controller_friction_coefficient":
				_characterized_controller_friction_coefficient,
				"cross_engine_portable": false,
				"locomotion_robustness": false,
			},
			"centroidal_command":
			"live_zero_gain_weight_support_allocation_shadow",
			"stability_influence":
			"called_by_adapter_contribution_shadow_not_walker",
			"actuator_mapping":
			"portable_j_transpose_with_characterized_host_velocity_profile_shadow",
			"mapping_comparison_absolute_tolerance_nm":
			JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM,
			"partial_support_mapping": "typed_unavailable_v2",
			"host_motor_response_characterization":
			{
				"schema_version":
				"sporespore_godot_jolt_motor_response_profile_v1",
				"source_commit": MOTOR_RESPONSE_CHARACTERIZATION_SOURCE_COMMIT,
				"report_sha256": MOTOR_RESPONSE_CHARACTERIZATION_REPORT_SHA256,
				"host_target_velocity_sign_per_canonical_positive":
				CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE,
				"local_fit_gain": MOTOR_RESPONSE_LOCAL_FIT_GAIN,
				"maximum_fit_residual_rad_s":
				MOTOR_RESPONSE_MAXIMUM_FIT_RESIDUAL_RAD_S,
				"uncertainty_fraction": MOTOR_RESPONSE_UNCERTAINTY_FRACTION,
				"conservative_velocity_per_torque_rad_s_per_nm":
				CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM,
				"maximum_characterized_generalized_torque_nm":
				CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM,
				"maximum_velocity_delta_rad_s":
				CHARACTERIZED_MAXIMUM_VELOCITY_DELTA_RAD_S,
				"tested_local_velocity_envelope_rad_s":
				CHARACTERIZED_TESTED_LOCAL_VELOCITY_ENVELOPE_RAD_S,
				"legacy_impulse_caps_nms": [0.045, 0.055],
				"physics_hz": 120,
				"solver_velocity_steps": 20,
				"solver_position_steps": 7,
				"mapping_operation":
				"characterized_generalized_torque_to_host_velocity_shadow",
				"isolated_fixture_only": true,
				"stability_influence_applied": false,
				"cross_engine_portable": false,
				"physical_acceptance_authority": false,
			},
			"actuation_authority": false,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		},
		"stability_v3":
		{
			"partial_support_mapping": "portable_v3_exact_zero_shadow",
			"contribution_shadow":
			{
				"schema_version":
				"sporespore_godot_jolt_stability_contribution_profile_v1",
				"mapping_operation":
				"map_endpoint_force_to_joint_v3_json",
				"influence_operation":
				(
					"bound_stability_influence_v3_json"
					if _stability_influence_scale_enabled
					else "bound_stability_influence_v2_json"
				),
				"global_requested_correction_scale":
				_stability_influence_global_scale,
				"velocity_per_torque_rad_s_per_nm":
				CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM,
				"host_target_velocity_sign_per_canonical_positive":
				CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE,
				"maximum_absolute_position_delta_rad":
				CONTRIBUTION_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
				"maximum_position_delta_slew_per_step_rad":
				CONTRIBUTION_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
				"maximum_absolute_velocity_delta_rad_s":
				CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
				"maximum_velocity_delta_slew_per_step_rad_s":
				CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
				"inactive_contact_transition":
				"typed_hard_zero_bypasses_slew",
				"profile_input_policy":
				"clamp_raw_v3_torque_to_characterized_p5i2_envelope",
				"limiter_reconstruction_tolerance":
				CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE,
				"motor_response_source_commit":
				MOTOR_RESPONSE_CHARACTERIZATION_SOURCE_COMMIT,
				"motor_response_report_sha256":
				MOTOR_RESPONSE_CHARACTERIZATION_REPORT_SHA256,
				"adapter_actuation_applied": false,
				"physics_state_modified": false,
				"physical_balance_recovery": false,
				"physical_acceptance_authority": false,
			},
			"feedback_policy":
			{
				"policy_id": _stability_policy_id,
				"runtime_id": P5I3C_OVERLAY_RUNTIME_ID,
				"memory_id": P5I3C_OVERLAY_MEMORY_ID,
				"enabled":
				_is_stability_feedback_authority_policy(_stability_policy_id),
				"target_mode":
				(
					(
						(
							"portable_scheduler_aware_load_transfer_v3_observation_fail_zero"
							if _is_scheduled_load_transfer_v3_policy(
								_stability_policy_id
							)
							else "portable_scheduler_aware_load_transfer_v2_fail_zero"
						)
						if _is_scheduled_load_transfer_typed_policy(
							_stability_policy_id
						)
						else "portable_scheduler_aware_load_transfer_v1"
					)
					if _is_scheduled_load_transfer_policy(
						_stability_policy_id
					)
					else "current_forward_height_support_centroid_lateral"
				),
				"portable_plan_operation":
				(
					_scheduled_load_transfer_plan_operation(
						_stability_policy_id
					)
					if _is_scheduled_load_transfer_policy(_stability_policy_id)
					else "not_requested"
				),
				"portable_plan_schema_version":
				(
					_scheduled_load_transfer_receipt_schema_version(
						_stability_policy_id
					)
					if _is_scheduled_load_transfer_policy(_stability_policy_id)
					else ""
				),
				"horizontal_position_gain_n_per_m":
				P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M,
				"horizontal_velocity_gain_ns_per_m":
				P5I3C_HORIZONTAL_VELOCITY_GAIN_NS_PER_M,
				"maximum_horizontal_force_n":
				P5I3C_MAXIMUM_HORIZONTAL_FORCE_N,
				"vertical_position_gain_n_per_m": 0.0,
				"vertical_velocity_gain_ns_per_m": 0.0,
				"maximum_vertical_correction_n": 0.0,
				"roll_position_gain_nm_per_rad":
				P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD,
				"roll_velocity_gain_nm_s_per_rad":
				P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD,
				"pitch_position_gain_nm_per_rad":
				P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD,
				"pitch_velocity_gain_nm_s_per_rad":
				P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD,
				"maximum_roll_pitch_moment_nm":
				P5I3C_MAXIMUM_ROLL_PITCH_MOMENT_NM,
			},
			"physical_overlay":
			{
				"enabled":
				_uses_stability_contribution_actuation(),
				"base_command":
				(
					"unchanged_legacy_candidate35_motor_target_velocity"
					if _controller_policy_id == CANDIDATE35_POLICY_ID
					else "portable_balanced_wave_ordered_command"
				),
				"operation":
				"bounded_host_delta_add_then_existing_speed_limit",
				"motor_parameter":
				"HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY",
				"readback_tolerance_rad_s":
				P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S,
				"host_command_quantization":
				"explicit_ieee754_binary32_before_motor_write",
				"host_command_quantization_tolerance_rad_s":
				P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S,
				"candidate35_shadow_parity":
				(
					"observation_only_not_overlay_authority"
					if _controller_policy_id == CANDIDATE35_POLICY_ID
					else "not_applicable_balanced_wave"
				),
				"overlay_runtime_gate":
				"typed_stability_contribution_base_host_and_readback_only",
				"body_state_write_authority": false,
				"balance_recovery_claim": false,
			},
		},
		"core_numeric_precision": "ieee754_binary64",
		"host_geometry_numeric_precision": "godot_real_t_binary32",
		"dynamic_mapping_comparison_tolerance": tolerance,
		"dynamic_mapping_tolerance_basis":
		"measured_godot_real_t_quantization_with_8x_velocity_gain",
		"execution_mode":
		(
			"native_balanced_wave_base_with_stability_contribution"
			if (
				_authority_scope == "post_settle_full"
				and _is_bw13p_policy(_stability_policy_id)
			)
			else (
				(
					"legacy_base_with_stability_overlay"
					if _controller_policy_id == CANDIDATE35_POLICY_ID
					else "portable_balanced_wave_base_with_stability_overlay"
				)
				if _authority_scope == "stability_contribution_overlay"
				else (
					"native_authority_with_legacy_observer"
					if actuation_authority_enabled
					else "shadow"
				)
			)
		),
		"shadow_mode": not actuation_authority_enabled,
		"actuation_authority": actuation_authority_enabled,
	}
	if _task_frame_origin_policy_id != FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID:
		_adapter_manifest["task_frame_origin_policy_id"] = (
			_task_frame_origin_policy_id
		)
	var r23d2_trace_request := OS.get_environment(
		R23D2_ORACLE_TRACE_ENVIRONMENT_VARIABLE,
	)
	if (
		not r23d2_trace_request.is_empty()
		and r23d2_trace_request != R23D2_ORACLE_TRACE_ENABLE_VALUE
	):
		return _failure("ADAPTER_R23D2_ORACLE_TRACE_REQUEST_INVALID")
	_r23d2_oracle_trace_enabled = r23d2_trace_request == R23D2_ORACLE_TRACE_ENABLE_VALUE
	_r23d2_oracle_trace.clear()
	if (
		_r23d2_oracle_trace_enabled
		and (
			controller_policy_id != BALANCED_WAVE_BW5R_B_POLICY_ID
			or not actuation_authority_enabled
			or authority_scope != "post_settle_full"
		)
	):
		return _failure("ADAPTER_R23D2_ORACLE_TRACE_SCOPE_INVALID")
	_adapter_capability_sha256 = CanonicalJsonScript.sha256(_adapter_manifest)
	_started = true
	return {
		"ok": true,
		"failure_code": "",
		"compiled_morphology_spec_sha256":
		String((_compiled["morphology"] as Dictionary)["morphology_spec_sha256"]),
		"adapter_manifest": _adapter_manifest.duplicate(true),
		"adapter_capability_sha256": _adapter_capability_sha256,
		"actuation_authority": _actuation_authority_enabled,
		"authority_scope": _authority_scope,
		"stability_policy_id": _stability_policy_id,
		"controller_policy_id": _controller_policy_id,
		"controller_runtime_version": _controller_runtime_version,
		"controller_profile_sha256": _controller_profile_sha256,
		"phase_offset_synchronization_receipt": _phase_offset_synchronization_receipt(),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


## Executes the declared signed phase transition and the first native policy
## request against a deterministic perfect synthetic state. This is a
## zero-world launch gate: callers must run it before creating any fixture.
##
## Startup-only preflights cannot detect a request that becomes unencodable at
## a later semantic boundary. In particular, BW13P-aa92940 passed startup and
## aggregate serialization checks but every physical world failed when a
## negative phase offset reached the u64 gait_step schema. This method makes
## that transition itself part of the executable adapter contract.
func preflight_perfect_declared_policy_runtime_boundary(
	requested_heading_command: Dictionary = {},
) -> Dictionary:
	if not _started:
		return _declared_policy_runtime_boundary_failure(
			"DECLARED_POLICY_RUNTIME_BOUNDARY_ADAPTER_NOT_STARTED",
		)
	if (
		not _phase_offset_synchronization_scheduled
		or _phase_offset_activation_semantic_step < 0
	):
		return _declared_policy_runtime_boundary_failure(
			"DECLARED_POLICY_RUNTIME_BOUNDARY_PHASE_TRANSITION_NOT_SCHEDULED",
		)
	var phase_result := _apply_scheduled_phase_offset_if_due(
		_phase_offset_activation_semantic_step,
	)
	if not bool(phase_result.get("ok", false)):
		return _declared_policy_runtime_boundary_failure(
			(
				"DECLARED_POLICY_RUNTIME_BOUNDARY_PHASE_TRANSITION:%s"
				% String(phase_result.get("failure_code", "UNKNOWN"))
			),
		)
	var phase_receipt := _phase_offset_synchronization_receipt()
	var morphology: Dictionary = _compiled.get("morphology", {})
	var ordered_limb_memory: Array = _memory.get("ordered_limb_memory", [])
	var memory_nonnegative := ordered_limb_memory.size() == 4
	var minimum_gait_step := 0
	var minimum_initialized := false
	for memory_value in ordered_limb_memory:
		if typeof(memory_value) != TYPE_DICTIONARY:
			memory_nonnegative = false
			continue
		var limb_memory: Dictionary = memory_value
		var gait_step := int(limb_memory.get("gait_step", -1))
		memory_nonnegative = memory_nonnegative and gait_step >= 0
		if not minimum_initialized or gait_step < minimum_gait_step:
			minimum_gait_step = gait_step
			minimum_initialized = true
	if not memory_nonnegative:
		return _declared_policy_runtime_boundary_failure(
			"DECLARED_POLICY_RUNTIME_BOUNDARY_NEGATIVE_GAIT_MEMORY",
			phase_receipt,
		)

	var semantic_step := _phase_offset_activation_semantic_step
	var state_frame := _perfect_synthetic_controller_state_frame(
		semantic_step,
		morphology,
	)
	var heading_command_result := compile_heading_offset_command(
		_canonical_initial_heading_rad,
		semantic_step,
		requested_heading_command,
	)
	if not bool(heading_command_result.get("ok", false)):
		return _declared_policy_runtime_boundary_failure(
			(
				"DECLARED_POLICY_RUNTIME_BOUNDARY_HEADING_COMMAND:%s"
				% String(heading_command_result.get("failure_code", "UNKNOWN"))
			),
			phase_receipt,
		)
	var motion_command := _perfect_synthetic_motion_command(semantic_step)
	if not requested_heading_command.is_empty():
		motion_command["command_id"] = String(heading_command_result["command_id"])
		motion_command["desired_heading_rad"] = float(
			heading_command_result["desired_heading_rad"]
		)
	var controller_request := _controller_step_request(
		_memory,
		state_frame,
		motion_command,
	)
	var validation_sample := {"request": controller_request}
	if not requested_heading_command.is_empty():
		validation_sample["heading_command_receipt"] = (
			(heading_command_result["receipt"] as Dictionary).duplicate(true)
		)
	var command_validation_receipt := {
		"schema_version": BALANCED_WAVE_COMMAND_VALIDATION_RECEIPT_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"enabled": false,
		"validation_mode": "not_applicable_non_balanced_wave",
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if _is_balanced_wave_policy(_controller_policy_id):
		command_validation_receipt = _balanced_wave_command_validation_receipt(
			validation_sample,
			semantic_step,
		)
	if not bool(command_validation_receipt.get("ok", false)):
		var command_validation_failure := _declared_policy_runtime_boundary_failure(
			(
				"DECLARED_POLICY_RUNTIME_BOUNDARY_COMMAND_VALIDATION:%s"
				% String(command_validation_receipt.get("failure_code", "UNKNOWN"))
			),
			phase_receipt,
		)
		command_validation_failure["balanced_wave_command_validation_receipt"] = (
			command_validation_receipt.duplicate(true)
		)
		return command_validation_failure
	var controller_envelope := _call_input(
		_controller_step_method(),
		controller_request,
	)
	if not bool(controller_envelope.get("ok", false)):
		var controller_failure := _declared_policy_runtime_boundary_failure(
			(
				"DECLARED_POLICY_RUNTIME_BOUNDARY_NATIVE_STEP:%s"
				% String(controller_envelope.get("failure_code", "UNKNOWN"))
			),
			phase_receipt,
		)
		controller_failure["native_controller_failure_detail"] = String(
			controller_envelope.get("detail", "")
		)
		return controller_failure
	var controller_output: Dictionary = controller_envelope.get("value", {})
	var actuation: Dictionary = controller_output.get("actuation", {})
	var controller_receipt: Dictionary = actuation.get("receipt", {})
	var commands: Array = actuation.get("ordered_commands", [])
	var expected_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var command_order_exact := commands.size() == expected_actuator_ids.size()
	for index in range(mini(commands.size(), expected_actuator_ids.size())):
		var command: Dictionary = commands[index]
		command_order_exact = (
			command_order_exact
			and String(command.get("actuator_id", ""))
			== String(expected_actuator_ids[index])
		)
	var next_memory: Dictionary = controller_output.get("next_memory", {})
	var production_step_validation := {
		"ok": true,
		"failure_code": "",
		"validation_mode": "not_applicable_non_balanced_wave",
		"physical_acceptance_authority": false,
	}
	if _is_balanced_wave_policy(_controller_policy_id):
		# Exercise the exact post-controller validator used by live physics.  This
		# closes the class of defects where a synthetic preflight accepts a native
		# receipt that the live adapter later rejects.
		production_step_validation = _finish_balanced_wave_shadow_step(
			controller_output,
			semantic_step,
			validation_sample,
		)
	var next_memory_nonnegative := true
	for memory_value in next_memory.get("ordered_limb_memory", []):
		var limb_memory: Dictionary = memory_value
		next_memory_nonnegative = (
			next_memory_nonnegative
			and int(limb_memory.get("gait_step", -1)) >= 0
		)
	var controller_step_exact := (
		not bool(actuation.get("safe_no_actuation", true))
		and command_order_exact
		and commands.size() == 8
		and next_memory_nonnegative
		and bool(production_step_validation.get("ok", false))
	)
	if not controller_step_exact:
		var output_failure := _declared_policy_runtime_boundary_failure(
			"DECLARED_POLICY_RUNTIME_BOUNDARY_NATIVE_OUTPUT_INVALID",
			phase_receipt,
		)
		output_failure["native_safe_no_actuation"] = bool(
			actuation.get("safe_no_actuation", true)
		)
		output_failure["native_failure_codes"] = (
			(actuation.get("failure_codes", []) as Array).duplicate()
		)
		output_failure["native_command_count"] = commands.size()
		output_failure["native_next_memory"] = next_memory.duplicate(true)
		output_failure["production_post_step_validation"] = (
			production_step_validation.duplicate(true)
		)
		return output_failure

	var scheduled_plan_required := _is_scheduled_load_transfer_policy(
		_stability_policy_id,
	)
	var scheduled_plan: Dictionary = {
		"ok": true,
		"failure_code": "",
		"receipt": {},
	}
	if scheduled_plan_required:
		scheduled_plan = _scheduled_load_transfer_plan(
			semantic_step,
			morphology,
			_perfect_synthetic_stability_state(semantic_step, morphology),
			1.0,
			true,
			"",
		)
		if not bool(scheduled_plan.get("ok", false)):
			var plan_failure := _declared_policy_runtime_boundary_failure(
				(
					"DECLARED_POLICY_RUNTIME_BOUNDARY_PORTABLE_PLAN:%s"
					% String(scheduled_plan.get("failure_code", "UNKNOWN"))
				),
				phase_receipt,
			)
			plan_failure["portable_plan_failure_detail"] = String(
				scheduled_plan.get("detail", "")
			)
			return plan_failure
	var scheduled_receipt: Dictionary = scheduled_plan.get("receipt", {})
	var scheduled_plan_exact := (
		not scheduled_plan_required
		or (
			String(scheduled_receipt.get("policy_id", ""))
			== _stability_policy_id
			and int(scheduled_receipt.get("semantic_step", -1)) == semantic_step
			and not bool(scheduled_plan.get("fail_zero_required", true))
		)
	)
	var portable_influence_required := _uses_stability_contribution_actuation()
	var portable_influence: Dictionary = {
		"ok": true,
		"failure_code": "",
	}
	if portable_influence_required:
		var planning_availability := String(
			scheduled_plan.get("planning_availability", "")
		)
		var mapped_commands: Array = []
		if planning_availability == "available":
			var actuator_ids: Array = morphology.get(
				"ordered_actuator_ids",
				[],
			)
			for actuator_index in range(actuator_ids.size()):
				mapped_commands.append(
					{
						"actuator_id": String(actuator_ids[actuator_index]),
						"mapping_mode": "support_command",
						"generalized_torque_command_nm":
						0.02 if actuator_index % 2 == 0 else -0.02,
					}
				)
		portable_influence = _bound_stability_contribution_shadow(
			semantic_step,
			morphology,
			mapped_commands,
			planning_availability,
		)
		if not bool(portable_influence.get("ok", false)):
			var influence_failure := _declared_policy_runtime_boundary_failure(
				(
					"DECLARED_POLICY_RUNTIME_BOUNDARY_PORTABLE_INFLUENCE:%s"
					% String(
						portable_influence.get(
							"failure_code",
							"UNKNOWN",
						)
					)
				),
				phase_receipt,
			)
			influence_failure["portable_influence_failure_detail"] = (
				portable_influence.duplicate(true)
			)
			return influence_failure
	var portable_influence_exact := (
		not portable_influence_required
		or (
			bool(portable_influence.get("ok", false))
			and (
				String(
					portable_influence.get(
						"stability_influence_operation",
						"",
					)
				)
				== (
					"bound_stability_influence_v3_json"
					if _stability_influence_scale_enabled
					else "bound_stability_influence_v2_json"
				)
			)
			and float(
				portable_influence.get(
					"global_requested_correction_scale",
					NAN,
				)
			)
			== _stability_influence_global_scale
			and not bool(
				portable_influence.get("adapter_actuation_applied", true)
			)
			and not bool(portable_influence.get("physics_state_modified", true))
			and not bool(
				portable_influence.get("physical_acceptance_authority", true)
			)
		)
	)
	var exact := (
		String(phase_receipt.get("schema_version", ""))
		== "sporespore_sdk_phase_offset_synchronization_receipt_v2"
		and int(phase_receipt.get("application_count", -1)) == 1
		and int(phase_receipt.get("synchronized_limb_count", -1)) == 4
		and (
			int(phase_receipt.get("common_representation_shift_ticks", -1))
			% GAIT_CYCLE_STEPS
			== 0
		)
		and memory_nonnegative
		and bool(command_validation_receipt.get("ok", false))
		and controller_step_exact
		and scheduled_plan_exact
		and portable_influence_exact
	)
	var result := {
		"schema_version":
		"sporespore_declared_policy_runtime_boundary_preflight_v1",
		"ok": exact,
		"failure_code":
		"" if exact else "DECLARED_POLICY_RUNTIME_BOUNDARY_RECONCILIATION_FAILED",
		"controller_policy_id": _controller_policy_id,
		"stability_policy_id": _stability_policy_id,
		"requested_phase_offset_ticks": _requested_phase_offset_ticks,
		"phase_offset_activation_semantic_step": semantic_step,
		"phase_offset_synchronization_receipt": phase_receipt,
		"minimum_represented_gait_step": minimum_gait_step,
		"gait_memory_nonnegative": memory_nonnegative,
		"native_controller_step_passed": controller_step_exact,
		"balanced_wave_command_validation_receipt":
		command_validation_receipt.duplicate(true),
		"native_controller_command_count": commands.size(),
		"native_controller_command_order_exact": command_order_exact,
		"native_next_memory_nonnegative": next_memory_nonnegative,
		"production_post_step_validation": production_step_validation.duplicate(true),
		"portable_scheduled_plan_required": scheduled_plan_required,
		"portable_scheduled_plan_passed": scheduled_plan_exact,
		"portable_scheduled_plan_receipt": scheduled_receipt.duplicate(true),
		"portable_stability_influence_required":
		portable_influence_required,
		"portable_stability_influence_passed": portable_influence_exact,
		"portable_stability_influence_receipt":
		portable_influence.duplicate(true),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	if not requested_heading_command.is_empty():
		result["heading_command_receipt"] = (
			(heading_command_result["receipt"] as Dictionary).duplicate(true)
		)
		result["controller_heading_receipt"] = {
			"requested_steering_fraction":
			float(controller_receipt.get("requested_steering_fraction", NAN)),
			"held_steering_fraction":
			float(controller_receipt.get("held_steering_fraction", NAN)),
			"desired_heading_error_rad":
			float(controller_receipt.get("desired_heading_error_rad", NAN)),
			"yaw_tracking_error_rad":
			float(controller_receipt.get("yaw_tracking_error_rad", NAN)),
		}
	return result


## Returns the exact portable morphology already compiled by the native
## GDExtension during start(). This is a zero-world inspection boundary for
## engine-worker canaries; callers cannot mutate the adapter's retained copy.
func preflight_compiled_morphology_boundary() -> Dictionary:
	if not _started:
		return {
			"ok": false,
			"failure_code": "COMPILED_MORPHOLOGY_BOUNDARY_ADAPTER_NOT_STARTED",
			"morphology": {},
			"world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	return {
		"ok": true,
		"failure_code": "",
		"morphology": (_compiled.get("morphology", {}) as Dictionary).duplicate(true),
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


## Executes one caller-supplied full StateFrame/MotionCommand pair through the
## real persistent-session GDExtension controller and the production
## apply_authority() path. The host writes target unparented HingeJoint3D
## objects and reads the exact motor parameter back, but never inserts a node
## into a SceneTree or constructs a physics world.
func preflight_explicit_balanced_wave_heading_runtime_boundary(
	state_frame: Dictionary,
	motion_command: Dictionary,
	include_actuator_phase_observation: bool = false,
) -> Dictionary:
	if not _started:
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_ADAPTER_NOT_STARTED",
		)
	if not _is_balanced_wave_policy(_controller_policy_id):
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_POLICY_UNSUPPORTED",
		)
	var semantic_step := int(state_frame.get("semantic_step", -1))
	if (
		semantic_step < 0
		or String(state_frame.get("schema_version", ""))
		!= "sporespore_state_frame_v1"
		or String(motion_command.get("schema_version", ""))
		!= "sporespore_motion_command_v2"
		or int(motion_command.get("valid_from_step", -1)) != semantic_step
		or int(motion_command.get("valid_through_step", -1)) != semantic_step
	):
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_INPUT_INVALID",
		)
	var controller_request := _controller_step_request(
		_memory,
		state_frame,
		motion_command,
	)
	var sample_result := {"request": controller_request}
	var command_validation_receipt := _balanced_wave_command_validation_receipt(
		sample_result,
		semantic_step,
	)
	if not bool(command_validation_receipt.get("ok", false)):
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_COMMAND_INVALID:%s"
			% String(command_validation_receipt.get("failure_code", "UNKNOWN")),
			{},
			command_validation_receipt,
		)
	var controller_envelope := _call_input(
		_controller_step_method(),
		controller_request,
	)
	if not bool(controller_envelope.get("ok", false)):
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_NATIVE_STEP:%s"
			% String(controller_envelope.get("failure_code", "UNKNOWN")),
			{},
			command_validation_receipt,
		)
	var controller_output: Dictionary = controller_envelope.get("value", {})
	var step_result := _finish_balanced_wave_shadow_step(
		controller_output,
		semantic_step,
		sample_result,
	)
	var actuation: Dictionary = controller_output.get("actuation", {})
	var controller_receipt: Dictionary = actuation.get("receipt", {})
	if not bool(step_result.get("ok", false)):
		return _explicit_heading_runtime_failure(
			"EXPLICIT_HEADING_BOUNDARY_ADAPTER_VALIDATION:%s"
			% String(step_result.get("failure_code", "UNKNOWN")),
			controller_receipt,
			command_validation_receipt,
		)

	var commands: Array = actuation.get("ordered_commands", [])
	var morphology: Dictionary = _compiled.get("morphology", {})
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var actuator_by_id: Dictionary = {}
	for actuator_value in morphology_spec.get("actuators", []):
		if typeof(actuator_value) == TYPE_DICTIONARY:
			var actuator: Dictionary = actuator_value
			actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	var joint_state_by_joint_id: Dictionary = {}
	var host_joints: Array[HingeJoint3D] = []
	var scene_tree_insertion_count := 0
	for command_value in commands:
		if typeof(command_value) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = command_value
		var joint_id := _legacy_joint_id_for_actuator(
			String(command.get("actuator_id", "")),
		)
		if joint_id.is_empty() or joint_state_by_joint_id.has(joint_id):
			continue
		var joint := HingeJoint3D.new()
		var actuator_id := String(command.get("actuator_id", ""))
		if include_actuator_phase_observation and actuator_by_id.has(actuator_id):
			var actuator: Dictionary = actuator_by_id[actuator_id]
			joint.set_param(
				HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
				float(actuator.get("maximum_impulse_nms", NAN)),
			)
		if joint.is_inside_tree():
			scene_tree_insertion_count += 1
		host_joints.append(joint)
		joint_state_by_joint_id[joint_id] = {"joint": joint}
	var authority_receipt := apply_authority(
		step_result,
		joint_state_by_joint_id,
		include_actuator_phase_observation,
	)
	var host_mappings: Array[Dictionary] = []
	var maximum_readback_error_rad_s := 0.0
	var mapping_valid := (
		bool(authority_receipt.get("ok", false))
		and commands.size() == 8
		and host_joints.size() == 8
	)
	for command_value in commands:
		if typeof(command_value) != TYPE_DICTIONARY:
			mapping_valid = false
			continue
		var command: Dictionary = command_value
		var actuator_id := String(command.get("actuator_id", ""))
		var joint_id := _legacy_joint_id_for_actuator(actuator_id)
		if joint_id.is_empty() or not joint_state_by_joint_id.has(joint_id):
			mapping_valid = false
			continue
		var joint_state: Dictionary = joint_state_by_joint_id[joint_id]
		var joint: HingeJoint3D = joint_state.get("joint")
		var target_velocity_rad_s := float(
			command.get("target_velocity_rad_s", NAN)
		)
		var readback_velocity_rad_s := joint.get_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		)
		var readback_error_rad_s := absf(
			readback_velocity_rad_s - target_velocity_rad_s,
		)
		maximum_readback_error_rad_s = maxf(
			maximum_readback_error_rad_s,
			readback_error_rad_s,
		)
		if (
			not is_finite(target_velocity_rad_s)
			or not is_finite(readback_velocity_rad_s)
			or readback_error_rad_s > _tolerance
			or joint.is_inside_tree()
		):
			mapping_valid = false
		host_mappings.append(
			{
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"motor_parameter": "HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY",
				"target_velocity_rad_s": target_velocity_rad_s,
				"readback_velocity_rad_s": readback_velocity_rad_s,
				"readback_error_rad_s": readback_error_rad_s,
				"host_object_inside_scene_tree": joint.is_inside_tree(),
			}
		)
	var exact := (
		mapping_valid
		and host_mappings.size() == 8
		and int(authority_receipt.get("applied_command_count", -1)) == 8
		and scene_tree_insertion_count == 0
	)
	for joint in host_joints:
		joint.free()
	var result := {
		"schema_version":
		"sporespore_godot_jolt_explicit_heading_runtime_preflight_v1",
		"ok": exact,
		"failure_code": (
			"" if exact else "EXPLICIT_HEADING_BOUNDARY_HOST_MAPPING_INVALID"
		),
		"semantic_step": semantic_step,
		"controller_policy_id": _controller_policy_id,
		"controller_profile_sha256": _controller_profile_sha256,
		"balanced_wave_command_validation_receipt":
		command_validation_receipt.duplicate(true),
		"controller_receipt": controller_receipt.duplicate(true),
		"controller_receipt_sha256": String(
			actuation.get("receipt_sha256", "")
		),
		"native_controller_command_count": commands.size(),
		"native_controller_command_order_exact": bool(
			step_result.get("balanced_wave_shadow_valid", false)
		),
		"authority_receipt": authority_receipt.duplicate(true),
		"ordered_host_mappings": host_mappings,
		"host_object_creation_count": host_joints.size(),
		"host_parameter_write_count": int(
			authority_receipt.get("applied_command_count", 0)
		),
		"maximum_readback_error_rad_s": maximum_readback_error_rad_s,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if include_actuator_phase_observation:
		result["trace_step_result"] = step_result.duplicate(true)
	return result


func _explicit_heading_runtime_failure(
	failure_code: String,
	rejected_controller_receipt: Dictionary = {},
	command_validation_receipt: Dictionary = {},
) -> Dictionary:
	return {
		"schema_version":
		"sporespore_godot_jolt_explicit_heading_runtime_preflight_v1",
		"ok": false,
		"failure_code": failure_code,
		"balanced_wave_command_validation_receipt":
		command_validation_receipt.duplicate(true),
		"rejected_controller_receipt":
		rejected_controller_receipt.duplicate(true),
		"native_controller_command_count": 0,
		"ordered_host_mappings": [],
		"host_object_creation_count": 0,
		"host_parameter_write_count": 0,
		"scene_tree_insertion_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


## Replays the complete declared no-world runtime schedule through the same
## phase-transition, phase-mode, portable-planner, and native-controller
## operations used by a physical run. The caller supplies the already-compiled
## production horizon so campaign-specific clocks remain explicit.
##
## This is deliberately stateful and must run on a fresh preflight adapter. It
## advances real native controller memory on every step; it does not construct
## nodes, insert a scene, modify physics state, or claim a locomotion outcome.
func preflight_perfect_declared_policy_runtime_horizon(
	declared_step_count: int,
	contact_gated_start_step: int,
	contact_gated_end_step: int,
) -> Dictionary:
	if not _started:
		return _declared_policy_runtime_horizon_failure(
			"DECLARED_POLICY_RUNTIME_HORIZON_ADAPTER_NOT_STARTED",
			-1,
		)
	if (
		declared_step_count <= 0
		or not _phase_offset_synchronization_scheduled
		or _phase_offset_activation_semantic_step < 0
		or _phase_offset_activation_semantic_step >= declared_step_count
		or contact_gated_start_step < 0
		or contact_gated_start_step >= contact_gated_end_step
		or contact_gated_end_step > declared_step_count
	):
		return _declared_policy_runtime_horizon_failure(
			"DECLARED_POLICY_RUNTIME_HORIZON_SCHEDULE_INVALID",
			-1,
		)
	var morphology: Dictionary = _compiled.get("morphology", {})
	var expected_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var native_step_count := 0
	var native_command_count := 0
	var portable_plan_count := 0
	var portable_available_count := 0
	var portable_fail_zero_count := 0
	var phase_mode_transition_count := 0
	var previous_phase_mode := ""
	var minimum_represented_gait_step := 0
	var minimum_initialized := false
	var first_plan_receipt_sha256 := ""
	var last_plan_receipt_sha256 := ""
	for semantic_step in range(declared_step_count):
		var phase_result := _apply_scheduled_phase_offset_if_due(semantic_step)
		if not bool(phase_result.get("ok", false)):
			return _declared_policy_runtime_horizon_failure(
				(
					"DECLARED_POLICY_RUNTIME_HORIZON_PHASE_TRANSITION:%s"
					% String(phase_result.get("failure_code", "UNKNOWN"))
				),
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
		var phase_progression_mode := (
			"contact_gated"
			if (
				semantic_step >= contact_gated_start_step
				and semantic_step < contact_gated_end_step
			)
			else "clocked"
		)
		if phase_progression_mode != previous_phase_mode:
			var mode_result := _configure_phase_progression_mode(
				phase_progression_mode,
			)
			if not bool(mode_result.get("ok", false)):
				return _declared_policy_runtime_horizon_failure(
					(
						"DECLARED_POLICY_RUNTIME_HORIZON_PHASE_MODE:%s"
						% String(mode_result.get("failure_code", "UNKNOWN"))
					),
					semantic_step,
					native_step_count,
					portable_plan_count,
				)
			phase_mode_transition_count += 1
			previous_phase_mode = phase_progression_mode
		var ordered_limb_memory: Array = _memory.get("ordered_limb_memory", [])
		if ordered_limb_memory.size() != 4:
			return _declared_policy_runtime_horizon_failure(
				"DECLARED_POLICY_RUNTIME_HORIZON_MEMORY_CARDINALITY",
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
		for memory_value in ordered_limb_memory:
			if typeof(memory_value) != TYPE_DICTIONARY:
				return _declared_policy_runtime_horizon_failure(
					"DECLARED_POLICY_RUNTIME_HORIZON_MEMORY_TYPE",
					semantic_step,
					native_step_count,
					portable_plan_count,
				)
			var limb_memory: Dictionary = memory_value
			var represented_gait_step := int(limb_memory.get("gait_step", -1))
			if represented_gait_step < 0:
				return _declared_policy_runtime_horizon_failure(
					"DECLARED_POLICY_RUNTIME_HORIZON_NEGATIVE_GAIT_MEMORY",
					semantic_step,
					native_step_count,
					portable_plan_count,
				)
			if (
				not minimum_initialized
				or represented_gait_step < minimum_represented_gait_step
			):
				minimum_represented_gait_step = represented_gait_step
				minimum_initialized = true
		var scheduled_plan := _scheduled_load_transfer_plan(
			semantic_step,
			morphology,
			_perfect_synthetic_stability_state(semantic_step, morphology),
			1.0,
			true,
			"",
		)
		if not bool(scheduled_plan.get("ok", false)):
			var plan_failure := _declared_policy_runtime_horizon_failure(
				(
					"DECLARED_POLICY_RUNTIME_HORIZON_PORTABLE_PLAN:%s"
					% String(scheduled_plan.get("failure_code", "UNKNOWN"))
				),
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
			plan_failure["portable_plan_failure_detail"] = String(
				scheduled_plan.get("detail", "")
			)
			return plan_failure
		var scheduled_receipt: Dictionary = scheduled_plan.get("receipt", {})
		var scheduled_receipt_exact := (
			String(scheduled_receipt.get("schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v3"
			and String(scheduled_receipt.get("policy_id", ""))
			== _stability_policy_id
			and int(scheduled_receipt.get("semantic_step", -1)) == semantic_step
			and typeof(scheduled_plan.get("fail_zero_required", null)) == TYPE_BOOL
		)
		if not scheduled_receipt_exact:
			return _declared_policy_runtime_horizon_failure(
				"DECLARED_POLICY_RUNTIME_HORIZON_PORTABLE_RECEIPT_INVALID",
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
		var plan_receipt_sha256 := CanonicalJsonScript.sha256(scheduled_receipt)
		if first_plan_receipt_sha256.is_empty():
			first_plan_receipt_sha256 = plan_receipt_sha256
		last_plan_receipt_sha256 = plan_receipt_sha256
		portable_plan_count += 1
		if bool(scheduled_plan.get("fail_zero_required", false)):
			portable_fail_zero_count += 1
		else:
			portable_available_count += 1
		var state_frame := _perfect_synthetic_controller_state_frame(
			semantic_step,
			morphology,
		)
		var motion_command := _perfect_synthetic_motion_command(
			semantic_step,
			phase_progression_mode,
		)
		var controller_request := _controller_step_request(
			_memory,
			state_frame,
			motion_command,
		)
		var controller_envelope := _call_input(
			_controller_step_method(),
			controller_request,
		)
		if not bool(controller_envelope.get("ok", false)):
			var controller_failure := _declared_policy_runtime_horizon_failure(
				(
					"DECLARED_POLICY_RUNTIME_HORIZON_NATIVE_STEP:%s"
					% String(controller_envelope.get("failure_code", "UNKNOWN"))
				),
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
			controller_failure["native_controller_failure_detail"] = String(
				controller_envelope.get("detail", "")
			)
			return controller_failure
		var controller_output: Dictionary = controller_envelope.get("value", {})
		var actuation: Dictionary = controller_output.get("actuation", {})
		var commands: Array = actuation.get("ordered_commands", [])
		var command_order_exact := (
			not bool(actuation.get("safe_no_actuation", true))
			and commands.size() == expected_actuator_ids.size()
			and commands.size() == 8
		)
		for command_index in range(
			mini(commands.size(), expected_actuator_ids.size())
		):
			var command: Dictionary = commands[command_index]
			command_order_exact = (
				command_order_exact
				and String(command.get("actuator_id", ""))
				== String(expected_actuator_ids[command_index])
			)
		var next_memory: Dictionary = controller_output.get("next_memory", {})
		var next_ordered_limb_memory: Array = next_memory.get(
			"ordered_limb_memory",
			[],
		)
		var next_memory_nonnegative := next_ordered_limb_memory.size() == 4
		for next_memory_value in next_ordered_limb_memory:
			if typeof(next_memory_value) != TYPE_DICTIONARY:
				next_memory_nonnegative = false
				continue
			var next_limb_memory: Dictionary = next_memory_value
			next_memory_nonnegative = (
				next_memory_nonnegative
				and int(next_limb_memory.get("gait_step", -1)) >= 0
			)
		if not command_order_exact or not next_memory_nonnegative:
			return _declared_policy_runtime_horizon_failure(
				"DECLARED_POLICY_RUNTIME_HORIZON_NATIVE_OUTPUT_INVALID",
				semantic_step,
				native_step_count,
				portable_plan_count,
			)
		_memory = next_memory.duplicate(true)
		native_step_count += 1
		native_command_count += commands.size()
	var phase_receipt := _phase_offset_synchronization_receipt()
	var exact := (
		native_step_count == declared_step_count
		and native_command_count == declared_step_count * 8
		and portable_plan_count == declared_step_count
		and portable_available_count + portable_fail_zero_count
		== declared_step_count
		and phase_mode_transition_count == 3
		and String(phase_receipt.get("schema_version", ""))
		== "sporespore_sdk_phase_offset_synchronization_receipt_v2"
		and int(phase_receipt.get("application_count", -1)) == 1
		and int(phase_receipt.get("synchronized_limb_count", -1)) == 4
	)
	return {
		"schema_version":
		"sporespore_declared_policy_runtime_horizon_preflight_v1",
		"ok": exact,
		"failure_code":
		"" if exact else "DECLARED_POLICY_RUNTIME_HORIZON_RECONCILIATION_FAILED",
		"controller_policy_id": _controller_policy_id,
		"stability_policy_id": _stability_policy_id,
		"requested_phase_offset_ticks": _requested_phase_offset_ticks,
		"phase_offset_activation_semantic_step":
		_phase_offset_activation_semantic_step,
		"phase_offset_synchronization_receipt": phase_receipt,
		"declared_step_count": declared_step_count,
		"native_controller_step_count": native_step_count,
		"native_controller_command_count": native_command_count,
		"portable_scheduled_plan_count": portable_plan_count,
		"portable_scheduled_available_count": portable_available_count,
		"portable_scheduled_fail_zero_count": portable_fail_zero_count,
		"phase_mode_transition_count": phase_mode_transition_count,
		"contact_gated_start_step": contact_gated_start_step,
		"contact_gated_end_step": contact_gated_end_step,
		"minimum_represented_gait_step": minimum_represented_gait_step,
		"gait_memory_nonnegative": true,
		"native_controller_step_passed": native_step_count == declared_step_count,
		"portable_scheduled_plan_passed":
		portable_plan_count == declared_step_count,
		"first_portable_plan_receipt_sha256": first_plan_receipt_sha256,
		"last_portable_plan_receipt_sha256": last_plan_receipt_sha256,
		"zero_error_synthetic_state_on_every_step": true,
		"exact_production_phase_transition_called": true,
		"exact_native_controller_operation_called": true,
		"exact_portable_planner_operation_called": true,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _declared_policy_runtime_horizon_failure(
	failure_code: String,
	failing_semantic_step: int,
	native_step_count: int = 0,
	portable_plan_count: int = 0,
) -> Dictionary:
	return {
		"schema_version":
		"sporespore_declared_policy_runtime_horizon_preflight_v1",
		"ok": false,
		"failure_code": failure_code,
		"failing_semantic_step": failing_semantic_step,
		"controller_policy_id": _controller_policy_id,
		"stability_policy_id": _stability_policy_id,
		"requested_phase_offset_ticks": _requested_phase_offset_ticks,
		"phase_offset_activation_semantic_step":
		_phase_offset_activation_semantic_step,
		"phase_offset_synchronization_receipt":
		_phase_offset_synchronization_receipt(),
		"native_controller_step_count": native_step_count,
		"portable_scheduled_plan_count": portable_plan_count,
		"gait_memory_nonnegative":
		not failure_code.contains("NEGATIVE_GAIT_MEMORY"),
		"native_controller_step_passed": false,
		"portable_scheduled_plan_passed": false,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _declared_policy_runtime_boundary_failure(
	failure_code: String,
	phase_receipt: Dictionary = {},
) -> Dictionary:
	return {
		"schema_version":
		"sporespore_declared_policy_runtime_boundary_preflight_v1",
		"ok": false,
		"failure_code": failure_code,
		"controller_policy_id": _controller_policy_id,
		"stability_policy_id": _stability_policy_id,
		"requested_phase_offset_ticks": _requested_phase_offset_ticks,
		"phase_offset_activation_semantic_step":
		_phase_offset_activation_semantic_step,
		"phase_offset_synchronization_receipt":
		phase_receipt.duplicate(true),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _perfect_synthetic_controller_state_frame(
	semantic_step: int,
	morphology: Dictionary,
) -> Dictionary:
	var joints: Array = []
	for joint_id_value in morphology.get("ordered_joint_ids", []):
		joints.append(
			{
				"joint_id": String(joint_id_value),
				"position_rad": 0.0,
				"velocity_rad_s": 0.0,
				"anchor_error_m": 0.0,
				"validity":
				{
					"position": true,
					"velocity": true,
					"anchor_error": true,
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": true,
				"bears_support": true,
				"normal_load_n": null,
				"provenance":
				{
					"adapter_id": "declared_policy_runtime_boundary_preflight",
					"engine_contact_ids": ["%s_synthetic" % contact_id],
					"aggregation_rule_id": "perfect_synthetic_bearing",
					"quality": "qualified_bearing",
				},
			}
		)
	return {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": semantic_step,
		"sample_time_s": float(semantic_step) / float(_physics_hz),
		"base_pose_world":
		{
			"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
			"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		},
		"ordered_joint_observations": joints,
		"ordered_contact_observations": contacts,
		"previous_applied_actuation": null,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"task_frame":
		{
			"origin_world_m": _vector(_initial_origin_world_m),
			"forward_axis_world_unit":
			_unit_vector_dictionary_binary64(_initial_forward_axis_world),
			"lateral_axis_world_unit":
			_unit_vector_dictionary_binary64(_initial_lateral_axis_world),
			"up_axis_world_unit":
			_unit_vector_dictionary_binary64(Vector3.UP),
			"reference_yaw_rad": _canonical_initial_heading_rad,
		},
		"adapter_capability_sha256": _adapter_capability_sha256,
	}


func _perfect_synthetic_motion_command(
	semantic_step: int,
	phase_progression_mode: String = "clocked",
) -> Dictionary:
	return {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": "declared_policy_runtime_boundary_preflight",
		"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
		"desired_heading_rad": _canonical_initial_heading_rad,
		"desired_yaw_rate_rad_s": null,
		"gait_family_id": "lateral_wave",
		"speed_class": "walk",
		"gait_amplitude": 1.0,
		"phase_progression_mode": phase_progression_mode,
		"valid_from_step": semantic_step,
		"valid_through_step": semantic_step,
		"authority": "test_fixture",
	}


func _perfect_synthetic_stability_state(
	semantic_step: int,
	morphology: Dictionary,
) -> Dictionary:
	var bodies: Array = []
	for body_id_value in morphology.get("ordered_body_ids", []):
		bodies.append(
			{
				"body_id": String(body_id_value),
				"pose_world":
				{
					"position_m": {"x": 0.0, "y": 0.44, "z": 0.08},
					"orientation_xyzw":
					{"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
				},
				"twist_world":
				{
					"linear_velocity_m_s":
					{"x": 0.0, "y": 0.0, "z": 0.0},
					"angular_velocity_rad_s":
					{"x": 0.0, "y": 0.0, "z": 0.0},
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": true,
				"bears_support": true,
				"point_world_m":
				{
					"x": 0.30 if contact_id.begins_with("front") else -0.30,
					"y": 0.0,
					"z": -0.20 if contact_id.contains("left") else 0.20,
				},
				"normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
				"surface_relative_velocity_world_m_s":
				{"x": 0.0, "y": 0.0, "z": 0.0},
				"material_id": "declared_policy_runtime_boundary_preflight",
				"adapter_id": "declared_policy_runtime_boundary_preflight",
				"engine_contact_ids": ["%s_synthetic" % contact_id],
			}
		)
	return {
		"schema_version": "sporespore_stability_state_v2",
		"semantic_step": semantic_step,
		"ordered_body_states": bodies,
		"ordered_support_contacts": contacts,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"adapter_capability_sha256": _adapter_capability_sha256,
	}


static func resolve_task_frame_origin_policy_step(
	policy_id: String,
	active_origin_world_m: Vector3,
	active_schedule_id: String,
	active_segment_id: String,
	reanchor_count: int,
	observed_torso_position_world_m: Vector3,
	requested_heading_command: Dictionary,
) -> Dictionary:
	if (
		not TASK_FRAME_ORIGIN_POLICY_IDS.has(policy_id)
		or not active_origin_world_m.is_finite()
		or not observed_torso_position_world_m.is_finite()
		or reanchor_count < 0
	):
		return {
			"ok": false,
			"failure_code": "ADAPTER_TASK_FRAME_ORIGIN_CONTEXT_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if policy_id == FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID:
		return {
			"ok": true,
			"failure_code": "",
			"origin_world_m": active_origin_world_m,
			"active_schedule_id": active_schedule_id,
			"active_segment_id": active_segment_id,
			"reanchor_count": reanchor_count,
			"reanchored_this_step": false,
			"receipt": {},
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if requested_heading_command.is_empty():
		return {
			"ok": false,
			"failure_code": "ADAPTER_TASK_FRAME_ORIGIN_HEADING_COMMAND_REQUIRED",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var heading_validation := compile_heading_offset_command(
		0.0,
		0,
		requested_heading_command,
	)
	if (
		not bool(heading_validation.get("ok", false))
		or not bool(heading_validation.get("heading_command_enabled", false))
	):
		return {
			"ok": false,
			"failure_code": "ADAPTER_TASK_FRAME_ORIGIN_HEADING_COMMAND_INVALID",
			"detail": String(
				heading_validation.get("failure_code", "HEADING_COMMAND_DISABLED")
			),
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var schedule_id := String(requested_heading_command["schedule_id"])
	var segment_id := String(requested_heading_command["segment_id"])
	var segment_changed := (
		schedule_id != active_schedule_id or segment_id != active_segment_id
	)
	var initial_schedule_binding := (
		active_schedule_id.is_empty() and active_segment_id.is_empty()
	)
	var reanchored := segment_changed
	if (
		policy_id == WARMUP_PRESERVING_COMMAND_ONSET_ORIGIN_REANCHOR_POLICY_ID
		and initial_schedule_binding
	):
		reanchored = false
	var resolved_origin := (
		observed_torso_position_world_m if reanchored else active_origin_world_m
	)
	var resolved_count := reanchor_count + (1 if reanchored else 0)
	var receipt := {
		"schema_version": TASK_FRAME_ORIGIN_RECEIPT_SCHEMA_VERSION,
		"policy_id": policy_id,
		"schedule_id": schedule_id,
		"segment_id": segment_id,
		"origin_world_m": _vector(resolved_origin),
		"reanchored_this_step": reanchored,
		"reanchor_count": resolved_count,
		"world_build_count": 0,
		"physics_state_modified": false,
		"adapter_actuation_applied": false,
		"physical_acceptance_authority": false,
	}
	return {
		"ok": true,
		"failure_code": "",
		"origin_world_m": resolved_origin,
		"active_schedule_id": schedule_id,
		"active_segment_id": segment_id,
		"reanchor_count": resolved_count,
		"reanchored_this_step": reanchored,
		"receipt": receipt,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func compile_heading_offset_command(
	reference_heading_rad: float,
	semantic_step: int,
	requested: Dictionary = {},
) -> Dictionary:
	if not is_finite(reference_heading_rad) or semantic_step < 0:
		return {
			"ok": false,
			"failure_code": "ADAPTER_HEADING_COMMAND_CONTEXT_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"command_id": "godot_jolt_shadow_walk",
			"desired_heading_rad": reference_heading_rad,
			"heading_command_enabled": false,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var observed_keys: Array = requested.keys()
	var expected_keys: Array = HEADING_OFFSET_COMMAND_KEYS.duplicate()
	observed_keys.sort()
	expected_keys.sort()
	if observed_keys != expected_keys:
		return {
			"ok": false,
			"failure_code": "ADAPTER_HEADING_COMMAND_KEYS_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var schedule_id_value: Variant = requested["schedule_id"]
	var segment_id_value: Variant = requested["segment_id"]
	var command_role_value: Variant = requested["command_role"]
	var heading_offset_value: Variant = requested["heading_offset_rad"]
	if (
		requested["schema_version"] != HEADING_OFFSET_COMMAND_SCHEMA_VERSION
		or typeof(schedule_id_value) != TYPE_STRING
		or typeof(segment_id_value) != TYPE_STRING
		or typeof(command_role_value) != TYPE_STRING
		or (
			typeof(heading_offset_value) != TYPE_FLOAT
			and typeof(heading_offset_value) != TYPE_INT
		)
	):
		return {
			"ok": false,
			"failure_code": "ADAPTER_HEADING_COMMAND_TYPE_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var schedule_id := String(schedule_id_value)
	var segment_id := String(segment_id_value)
	var command_role := String(command_role_value)
	var heading_offset_rad := float(heading_offset_value)
	if (
		schedule_id.is_empty()
		or segment_id.is_empty()
		or not ["reference_heading", "turn_heading"].has(command_role)
		or not is_finite(heading_offset_rad)
		or absf(heading_offset_rad) > PI
		or (command_role == "reference_heading" and heading_offset_rad != 0.0)
	):
		return {
			"ok": false,
			"failure_code": "ADAPTER_HEADING_COMMAND_VALUE_INVALID",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var desired_heading_rad := _wrap_angle(reference_heading_rad + heading_offset_rad)
	var receipt := {
		"schema_version": HEADING_COMMAND_RECEIPT_SCHEMA_VERSION,
		"schedule_id": schedule_id,
		"segment_id": segment_id,
		"command_role": command_role,
		"semantic_step": semantic_step,
		"reference_heading_rad": reference_heading_rad,
		"heading_offset_rad": heading_offset_rad,
		"desired_heading_rad": desired_heading_rad,
		"world_build_count": 0,
		"physics_state_modified": false,
		"adapter_actuation_applied": false,
		"physical_acceptance_authority": false,
	}
	return {
		"ok": true,
		"failure_code": "",
		"command_id": "%s_%s" % [schedule_id, segment_id],
		"desired_heading_rad": desired_heading_rad,
		"heading_command_enabled": true,
		"receipt": receipt,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _balanced_wave_command_validation_receipt(
	sample_result: Dictionary,
	semantic_step: int,
) -> Dictionary:
	var failure_code := ""
	var request_value: Variant = sample_result.get("request", null)
	var request: Dictionary = {}
	var command: Dictionary = {}
	if semantic_step < 0 or typeof(request_value) != TYPE_DICTIONARY:
		failure_code = "ADAPTER_BALANCED_WAVE_VALIDATION_REQUEST_INVALID"
	else:
		request = request_value
		var command_value: Variant = request.get("command", null)
		if typeof(command_value) != TYPE_DICTIONARY:
			failure_code = "ADAPTER_BALANCED_WAVE_VALIDATION_COMMAND_INVALID"
		else:
			command = command_value
	var desired_heading_value: Variant = command.get("desired_heading_rad", null)
	if (
		failure_code.is_empty()
		and (
			String(command.get("schema_version", "")) != "sporespore_motion_command_v2"
			or typeof(command.get("command_id", null)) != TYPE_STRING
			or String(command.get("command_id", "")).is_empty()
			or (
				typeof(desired_heading_value) != TYPE_FLOAT
				and typeof(desired_heading_value) != TYPE_INT
			)
			or not is_finite(float(desired_heading_value))
			or command.get("desired_yaw_rate_rad_s", false) != null
			or int(command.get("valid_from_step", -1)) != semantic_step
			or int(command.get("valid_through_step", -1)) != semantic_step
		)
	):
		failure_code = "ADAPTER_BALANCED_WAVE_VALIDATION_COMMAND_INVALID"
	var heading_command_conditioned := sample_result.has("heading_command_receipt")
	var heading_receipt: Dictionary = {}
	if failure_code.is_empty() and heading_command_conditioned:
		var heading_receipt_value: Variant = sample_result.get(
			"heading_command_receipt",
			null,
		)
		if typeof(heading_receipt_value) != TYPE_DICTIONARY:
			failure_code = "ADAPTER_BALANCED_WAVE_HEADING_RECEIPT_INVALID"
		else:
			heading_receipt = heading_receipt_value
			var observed_keys: Array = heading_receipt.keys()
			var expected_keys: Array = HEADING_COMMAND_RECEIPT_KEYS.duplicate()
			observed_keys.sort()
			expected_keys.sort()
			if observed_keys != expected_keys:
				failure_code = "ADAPTER_BALANCED_WAVE_HEADING_RECEIPT_KEYS_INVALID"
	if failure_code.is_empty() and heading_command_conditioned:
		var reference_value: Variant = heading_receipt.get("reference_heading_rad", null)
		var offset_value: Variant = heading_receipt.get("heading_offset_rad", null)
		var desired_value: Variant = heading_receipt.get("desired_heading_rad", null)
		var numeric_types_valid := (
			(typeof(reference_value) == TYPE_FLOAT or typeof(reference_value) == TYPE_INT)
			and (typeof(offset_value) == TYPE_FLOAT or typeof(offset_value) == TYPE_INT)
			and (typeof(desired_value) == TYPE_FLOAT or typeof(desired_value) == TYPE_INT)
		)
		if not numeric_types_valid:
			failure_code = "ADAPTER_BALANCED_WAVE_HEADING_RECEIPT_TYPE_INVALID"
		else:
			var reference_heading_rad := float(reference_value)
			var heading_offset_rad := float(offset_value)
			var desired_heading_rad := float(desired_value)
			var schedule_id := String(heading_receipt.get("schedule_id", ""))
			var segment_id := String(heading_receipt.get("segment_id", ""))
			var command_role := String(heading_receipt.get("command_role", ""))
			var expected_command_id := "%s_%s" % [schedule_id, segment_id]
			if (
				String(heading_receipt.get("schema_version", ""))
				!= HEADING_COMMAND_RECEIPT_SCHEMA_VERSION
				or schedule_id.is_empty()
				or segment_id.is_empty()
				or not ["reference_heading", "turn_heading"].has(command_role)
				or not is_finite(reference_heading_rad)
				or not is_finite(heading_offset_rad)
				or absf(heading_offset_rad) > PI
				or (command_role == "reference_heading" and heading_offset_rad != 0.0)
				or not is_finite(desired_heading_rad)
				or absf(
					_wrap_angle(reference_heading_rad + heading_offset_rad)
					- desired_heading_rad
				) > 1.0e-15
				or int(heading_receipt.get("semantic_step", -1)) != semantic_step
				or int(heading_receipt.get("world_build_count", -1)) != 0
				or bool(heading_receipt.get("physics_state_modified", true))
				or bool(heading_receipt.get("adapter_actuation_applied", true))
				or bool(heading_receipt.get("physical_acceptance_authority", true))
				or String(command.get("command_id", "")) != expected_command_id
				or absf(float(command.get("desired_heading_rad", NAN)) - desired_heading_rad)
				> 1.0e-15
			):
				failure_code = "ADAPTER_BALANCED_WAVE_HEADING_RECEIPT_INVALID"
	return {
		"schema_version": BALANCED_WAVE_COMMAND_VALIDATION_RECEIPT_SCHEMA_VERSION,
		"ok": failure_code.is_empty(),
		"failure_code": failure_code,
		"enabled": true,
		"validation_mode": BALANCED_WAVE_COMMAND_VALIDATION_MODE,
		"native_structure_and_receipts_required": true,
		"heading_command_conditioned": heading_command_conditioned,
		"heading_command_receipt_present": not heading_receipt.is_empty(),
		"command_id": String(command.get("command_id", "")),
		"command_role": String(heading_receipt.get("command_role", "")),
		"heading_offset_rad": float(heading_receipt.get("heading_offset_rad", 0.0)),
		"legacy_command_parity_applicable": false,
		"legacy_command_parity_checked": false,
		"legacy_command_parity_waived": false,
		"legacy_command_parity_not_applicable_reason":
		"balanced_wave_routes_to_native_validator_before_candidate35_parity",
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func characterized_host_velocity_delta_for_generalized_torque(
	generalized_torque_nm: float,
) -> Dictionary:
	if (
		not is_finite(generalized_torque_nm)
		or absf(generalized_torque_nm)
		> CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM + 1.0e-12
	):
		return {
			"ok": false,
			"failure_code": "GENERALIZED_TORQUE_OUTSIDE_CHARACTERIZED_ENVELOPE",
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var canonical_velocity_delta := (
		CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM
		* generalized_torque_nm
	)
	if (
		not is_finite(canonical_velocity_delta)
		or absf(canonical_velocity_delta)
		> CHARACTERIZED_TESTED_LOCAL_VELOCITY_ENVELOPE_RAD_S + 1.0e-12
	):
		return {
			"ok": false,
			"failure_code": "HOST_VELOCITY_OUTSIDE_CHARACTERIZED_ENVELOPE",
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	return {
		"schema_version":
		"sporespore_godot_jolt_characterized_velocity_mapping_receipt_v1",
		"ok": true,
		"failure_code": "",
		"generalized_torque_command_nm": generalized_torque_nm,
		"canonical_velocity_delta_rad_s": canonical_velocity_delta,
		"host_target_velocity_delta_rad_s":
		CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE
		* canonical_velocity_delta,
		"host_target_velocity_sign_per_canonical_positive":
		CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE,
		"conservative_velocity_per_torque_rad_s_per_nm":
		CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM,
		"uncertainty_fraction": MOTOR_RESPONSE_UNCERTAINTY_FRACTION,
		"maximum_characterized_generalized_torque_nm":
		CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM,
		"tested_local_velocity_envelope_rad_s":
		CHARACTERIZED_TESTED_LOCAL_VELOCITY_ENVELOPE_RAD_S,
		"command_not_measured_torque": true,
		"isolated_response_characterized": true,
		"stability_influence_applied": false,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func sample(
	semantic_step: int,
	gait_amplitude: float,
	phase_progression_mode: String,
	torso: RigidBody3D,
	limbs: Array,
	floor: StaticBody3D,
	observation_fault_options: Dictionary = {},
	requested_heading_command: Dictionary = {},
) -> Dictionary:
	if _shutdown_completed:
		return _failure("ADAPTER_ALREADY_SHUT_DOWN")
	if not _started:
		return _failure("ADAPTER_NOT_STARTED")
	var phase_offset_result := _apply_scheduled_phase_offset_if_due(semantic_step)
	if not bool(phase_offset_result.get("ok", false)):
		var phase_offset_code := String(
			phase_offset_result.get(
				"failure_code",
				"ADAPTER_PHASE_OFFSET_SYNCHRONIZATION_FAILED",
			)
		)
		_record_failure(phase_offset_code)
		return phase_offset_result
	var phase_mode_result := _configure_phase_progression_mode(phase_progression_mode)
	if not bool(phase_mode_result.get("ok", false)):
		var phase_code := String(
			phase_mode_result.get("failure_code", "ADAPTER_PHASE_PROGRESSION_MODE_INVALID")
		)
		_record_failure(phase_code)
		return phase_mode_result
	var sample_result := _build_step_request(
		semantic_step,
		gait_amplitude,
		phase_progression_mode,
		torso,
		limbs,
		floor,
		requested_heading_command,
	)
	if not bool(sample_result.get("ok", false)):
		_record_failure(String(sample_result.get("failure_code", "ADAPTER_STATE_BUILD_FAILED")))
		return sample_result
	var step_fault_result := _apply_observation_fault_to_step_request(
		sample_result,
		semantic_step,
		observation_fault_options,
	)
	if not bool(step_fault_result.get("ok", false)):
		var step_fault_code := String(
			step_fault_result.get("failure_code", "ADAPTER_OBSERVATION_FAULT_INVALID")
		)
		_record_failure(step_fault_code)
		return step_fault_result
	sample_result = step_fault_result["sample_result"]
	var stability_shadow := _sample_stability_shadow(
		semantic_step,
		torso,
		limbs,
		floor,
		gait_amplitude,
		observation_fault_options,
	)
	stability_shadow = _ensure_v3_unavailable_stability_receipt(
		semantic_step,
		(_compiled.get("morphology", {}) as Dictionary),
		stability_shadow,
		gait_amplitude,
	)
	_record_stability_shadow(stability_shadow)
	sample_result["stability_shadow"] = stability_shadow
	if _controller_policy_id == DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID:
		sample_result["request"]["command"]["desired_planar_velocity_task_m_s"] = {"x": 0.0, "y": 0.0, "z": 0.0}
	if _controller_policy_id in [DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID]:
		var measured := DevelopmentMeasuredBody.project_v1(sample_result["request"]["state"], stability_shadow.get("stability_state", {}))
		if measured.is_empty():
			return _failure("DEVELOPMENT_MEASURED_BODY_SAMPLE_CROSSED")
		sample_result["request"]["measured_body_frame"] = measured
		if gait_amplitude == 0.0 and (_memory.get("anchored_body_pose") is Dictionary or _development_stationary_hold):
			sample_result["request"]["command"]["desired_planar_velocity_task_m_s"] = {"x": 0.0, "y": 0.0, "z": 0.0}
	var fault_profile_id := String(
		observation_fault_options.get("observation_fault_profile_id", "none")
	)
	sample_result["observation_fault_receipt"] = {
		"schema_version": "sporespore_observation_fault_receipt_v1",
		"applied": fault_profile_id != "none",
		"profile_id": fault_profile_id,
		"semantic_step": semantic_step,
		"maximum_absolute_applied_component":
		maxf(
			float(step_fault_result.get("maximum_absolute_applied_component", 0.0)),
			float(stability_shadow.get("maximum_absolute_fault_component", 0.0)),
		),
		"base_state_faulted": bool(step_fault_result.get("fault_applied", false)),
		"stability_state_faulted":
		bool(stability_shadow.get("observation_fault_applied", false)),
		"physics_state_modified": false,
		"adapter_actuation_applied": false,
	}
	return sample_result


func compiled_morphology_for_conformance() -> Dictionary:
	if not _started:
		return _failure("ADAPTER_NOT_STARTED")
	return {
		"ok": true,
		"failure_code": "",
		"morphology": (_compiled["morphology"] as Dictionary).duplicate(true),
		"adapter_manifest": _adapter_manifest.duplicate(true),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func step(
	sample_result: Dictionary,
	semantic_step: int,
	legacy_command_context_by_joint_id: Dictionary,
	legacy_gait_step_by_limb: Dictionary,
	legacy_held_steering_fraction: float,
	legacy_steering_context: Dictionary,
	require_native_step_transport_verification: bool = false,
) -> Dictionary:
	if _shutdown_completed:
		return _failure("ADAPTER_ALREADY_SHUT_DOWN")
	if not _started:
		return _failure("ADAPTER_NOT_STARTED")
	if not bool(sample_result.get("ok", false)):
		var sample_code := String(
			sample_result.get("failure_code", "ADAPTER_PRECONTROL_SAMPLE_INVALID")
		)
		_record_failure(sample_code)
		return _failure("ADAPTER_PRECONTROL_SAMPLE_INVALID", sample_code)
	var sampled_request: Dictionary = sample_result.get("request", {})
	var sampled_state: Dictionary = sampled_request.get("state", {})
	if int(sampled_state.get("semantic_step", -1)) != semantic_step:
		_record_failure("ADAPTER_PRECONTROL_SAMPLE_STEP_MISMATCH")
		return _failure("ADAPTER_PRECONTROL_SAMPLE_STEP_MISMATCH")
	var native_step_transport_verification: Dictionary = {}
	var envelope: Dictionary = {}
	if require_native_step_transport_verification:
		if not _is_balanced_wave_policy(_controller_policy_id):
			return _failure("ADAPTER_NATIVE_STEP_TRANSPORT_VERIFICATION_POLICY_UNSUPPORTED")
		envelope = _call_balanced_wave_session_step_with_transport_verification(
			sampled_request,
			semantic_step,
		)
		native_step_transport_verification = (
			envelope.get("native_step_transport_verification", {}) as Dictionary
		).duplicate(true)
	else:
		envelope = _call_input(_controller_step_method(), sampled_request)
	if not bool(envelope.get("ok", false)):
		var transport_code := String(envelope.get("failure_code", "ADAPTER_NATIVE_STEP_FAILED"))
		_record_failure(transport_code)
		var transport_failure_result := _failure("ADAPTER_NATIVE_STEP_FAILED", transport_code)
		if require_native_step_transport_verification:
			transport_failure_result["native_step_transport_verification"] = (
				native_step_transport_verification.duplicate(true)
			)
		if envelope.get("development_native_step_failure") is Dictionary:
			transport_failure_result["development_native_step_failure"] = envelope.development_native_step_failure.duplicate(true)
		return transport_failure_result
	var output: Dictionary = envelope["value"]
	var actuation: Dictionary = output["actuation"]
	if bool(actuation.get("safe_no_actuation", false)):
		_safe_no_actuation_count += 1
		var safe_codes: Array = actuation.get("failure_codes", [])
		var receipt: Dictionary = actuation.get("receipt", {})
		var controller_error := String(receipt.get("controller_error", ""))
		var safe_code := "ADAPTER_NATIVE_SAFE_NO_ACTUATION"
		if not safe_codes.is_empty():
			safe_code = "%s:%s" % [safe_code, String(safe_codes[0])]
		_record_failure(
			safe_code if controller_error.is_empty() else "%s:%s" % [safe_code, controller_error]
		)
		if _failure_details.size() < 20:
			_failure_details.append(
				{
					"semantic_step": semantic_step,
					"failure_codes": safe_codes.duplicate(),
					"controller_error": controller_error,
				}
			)
		_memory = (output["next_memory"] as Dictionary).duplicate(true)
		_step_count += 1
		var safe_failure_result := _failure(safe_code)
		if require_native_step_transport_verification:
			safe_failure_result["native_step_transport_verification"] = (
				native_step_transport_verification.duplicate(true)
			)
		return safe_failure_result
	if _is_balanced_wave_policy(_controller_policy_id):
		return _finish_balanced_wave_shadow_step(
			output,
			semantic_step,
			sample_result,
			native_step_transport_verification,
		)
	var step_mismatch_count := 0
	var command_mismatch_details: Array[Dictionary] = []
	for command_value in actuation["ordered_commands"]:
		var command: Dictionary = command_value
		var actuator_id := String(command["actuator_id"])
		var legacy_joint_id := _legacy_joint_id_for_actuator(actuator_id)
		if legacy_joint_id.is_empty() or not legacy_command_context_by_joint_id.has(legacy_joint_id):
			step_mismatch_count += 1
			_record_failure("ADAPTER_ACTUATOR_MAPPING_MISSING:%s" % actuator_id)
			command_mismatch_details.append(
				{
					"actuator_id": actuator_id,
					"legacy_joint_id": legacy_joint_id,
					"failure_code": "ADAPTER_ACTUATOR_MAPPING_MISSING",
				}
			)
			continue
		var legacy: Dictionary = legacy_command_context_by_joint_id[legacy_joint_id]
		var target_position_error := absf(
			float(command["requested_target_position_rad"]) - float(legacy["target_angle_rad"])
		)
		var target_velocity_error := absf(
			float(command["target_velocity_rad_s"]) - float(legacy["target_velocity_rad_s"])
		)
		var speed_limit_error := absf(
			float(command["maximum_target_speed_rad_s"])
			- float(legacy["maximum_target_speed_rad_s"])
		)
		_maximum_absolute_target_position_error_rad = maxf(
			_maximum_absolute_target_position_error_rad,
			target_position_error,
		)
		_maximum_absolute_target_velocity_error_rad_s = maxf(
			_maximum_absolute_target_velocity_error_rad_s,
			target_velocity_error,
		)
		_maximum_absolute_speed_limit_error_rad_s = maxf(
			_maximum_absolute_speed_limit_error_rad_s,
			speed_limit_error,
		)
		_compared_actuator_command_count += 1
		if (
			target_position_error > _tolerance
			or target_velocity_error > _tolerance
			or speed_limit_error > _tolerance
		):
			step_mismatch_count += 1
			command_mismatch_details.append(
				{
					"actuator_id": actuator_id,
					"legacy_joint_id": legacy_joint_id,
					"native_target_position_rad":
					float(command["requested_target_position_rad"]),
					"legacy_target_position_rad": float(legacy["target_angle_rad"]),
					"target_position_error_rad": target_position_error,
					"native_target_velocity_rad_s": float(command["target_velocity_rad_s"]),
					"legacy_target_velocity_rad_s": float(legacy["target_velocity_rad_s"]),
					"target_velocity_error_rad_s": target_velocity_error,
					"native_maximum_target_speed_rad_s":
					float(command["maximum_target_speed_rad_s"]),
					"legacy_maximum_target_speed_rad_s":
					float(legacy["maximum_target_speed_rad_s"]),
					"maximum_target_speed_error_rad_s": speed_limit_error,
				}
			)
			if (
				_first_large_command_mismatch_detail.is_empty()
				and (
					target_position_error > 1.0e-6
					or target_velocity_error > 1.0e-6
					or speed_limit_error > 1.0e-6
				)
			):
				_first_large_command_mismatch_detail = {
					"semantic_step": semantic_step,
					"actuator_id": actuator_id,
					"legacy_joint_id": legacy_joint_id,
					"native_target_position_rad":
					float(command["requested_target_position_rad"]),
					"legacy_target_position_rad": float(legacy["target_angle_rad"]),
					"target_position_error_rad": target_position_error,
					"native_target_velocity_rad_s": float(command["target_velocity_rad_s"]),
					"legacy_target_velocity_rad_s": float(legacy["target_velocity_rad_s"]),
					"target_velocity_error_rad_s": target_velocity_error,
					"native_maximum_target_speed_rad_s":
					float(command["maximum_target_speed_rad_s"]),
					"legacy_maximum_target_speed_rad_s":
					float(legacy["maximum_target_speed_rad_s"]),
					"maximum_target_speed_error_rad_s": speed_limit_error,
				}
	var next_memory: Dictionary = output["next_memory"]
	var phase_mismatch_details: Array[Dictionary] = []
	for limb_memory_value in next_memory["ordered_limb_memory"]:
		var limb_memory: Dictionary = limb_memory_value
		var limb_id := String(limb_memory["limb_id"])
		if not legacy_gait_step_by_limb.has(limb_id):
			step_mismatch_count += 1
			_record_failure("ADAPTER_PHASE_MAPPING_MISSING:%s" % limb_id)
			phase_mismatch_details.append(
				{
					"limb_id": limb_id,
					"failure_code": "ADAPTER_PHASE_MAPPING_MISSING",
				}
			)
			continue
		## A signed phase perturbation may place the host's unbounded raw clock
		## just below zero. The portable schema intentionally keeps gait_step
		## nonnegative, so phase synchronization moves every limb into one
		## common equivalent cycle epoch. Compare against that declared
		## representation shift rather than hiding a whole-cycle difference.
		var represented_legacy_gait_step := (
			int(legacy_gait_step_by_limb[limb_id])
			+ _phase_offset_representation_shift_ticks
		)
		var phase_error := absi(
			int(limb_memory["gait_step"]) - represented_legacy_gait_step
		)
		_maximum_absolute_phase_error_steps = maxi(
			_maximum_absolute_phase_error_steps,
			phase_error,
		)
		if phase_error != 0:
			step_mismatch_count += 1
			phase_mismatch_details.append(
				{
					"limb_id": limb_id,
					"native_gait_step": int(limb_memory["gait_step"]),
					"legacy_gait_step": int(legacy_gait_step_by_limb[limb_id]),
					"representation_shift_ticks":
					_phase_offset_representation_shift_ticks,
					"represented_legacy_gait_step": represented_legacy_gait_step,
					"absolute_phase_error_steps": phase_error,
				}
			)
			if _first_phase_mismatch_detail.is_empty():
				var previous_native_gait_step := -1
				for previous_memory_value in _memory["ordered_limb_memory"]:
					var previous_memory: Dictionary = previous_memory_value
					if String(previous_memory["limb_id"]) == limb_id:
						previous_native_gait_step = int(previous_memory["gait_step"])
						break
				var sampled_contact: Dictionary = {}
				for contact_value in sampled_state["ordered_contact_observations"]:
					var contact: Dictionary = contact_value
					if String(contact["contact_site_id"]) == "%s_foot" % limb_id:
						sampled_contact = contact.duplicate(true)
						break
				_first_phase_mismatch_detail = {
					"semantic_step": semantic_step,
					"limb_id": limb_id,
					"previous_native_gait_step": previous_native_gait_step,
					"native_gait_step": int(limb_memory["gait_step"]),
					"legacy_gait_step": int(legacy_gait_step_by_limb[limb_id]),
					"representation_shift_ticks":
					_phase_offset_representation_shift_ticks,
					"represented_legacy_gait_step": represented_legacy_gait_step,
					"absolute_phase_error_steps": phase_error,
					"sampled_contact": sampled_contact,
				}
	var steering_error := absf(
		float(next_memory["held_path_steering_fraction"]) - legacy_held_steering_fraction
	)
	_maximum_absolute_steering_error = maxf(
		_maximum_absolute_steering_error,
		steering_error,
	)
	if steering_error > _tolerance:
		step_mismatch_count += 1
	if step_mismatch_count > 0:
		_record_failure("ADAPTER_DYNAMIC_PARITY_MISMATCH:%d" % semantic_step)
		if _failure_details.size() < 20:
			var controller_receipt: Dictionary = actuation.get("receipt", {})
			var adapter_legacy_yaw_rad := float(
				sample_result.get("adapter_legacy_yaw_rad", NAN)
			)
			var request: Dictionary = sample_result["request"]
			var state_frame: Dictionary = request["state"]
			var base_pose: Dictionary = state_frame["base_pose_world"]
			var orientation: Dictionary = base_pose["orientation_xyzw"]
			var canonical_quaternion_x := float(orientation["x"])
			var canonical_quaternion_y := float(orientation["y"])
			var canonical_quaternion_z := float(orientation["z"])
			var canonical_quaternion_w := float(orientation["w"])
			var adapter_canonical_heading_rad := atan2(
				2.0
				* (
					canonical_quaternion_x * canonical_quaternion_z
					- canonical_quaternion_w * canonical_quaternion_y
				),
				1.0
				- 2.0
				* (
					canonical_quaternion_y * canonical_quaternion_y
					+ canonical_quaternion_z * canonical_quaternion_z
				),
			)
			var expected_canonical_heading_rad := _wrap_angle(
				adapter_legacy_yaw_rad - PI * 0.5
			)
			_failure_details.append(
				{
					"semantic_step": semantic_step,
					"native_held_steering_fraction":
					float(next_memory["held_path_steering_fraction"]),
					"legacy_held_steering_fraction": legacy_held_steering_fraction,
					"absolute_steering_error": steering_error,
					"native_cross_track_error_m":
					float(controller_receipt.get("cross_track_error_m", NAN)),
					"native_cross_track_velocity_m_s":
					float(controller_receipt.get("cross_track_velocity_m_s", NAN)),
					"native_measured_yaw_error_rad":
					float(controller_receipt.get("measured_yaw_error_rad", NAN)),
					"native_desired_heading_error_rad":
					float(controller_receipt.get("desired_heading_error_rad", NAN)),
					"native_yaw_tracking_error_rad":
					float(controller_receipt.get("yaw_tracking_error_rad", NAN)),
					"legacy_steering_context": legacy_steering_context.duplicate(true),
					"adapter_legacy_measured_yaw_error_rad":
					_wrap_angle(adapter_legacy_yaw_rad - _initial_legacy_yaw_rad),
					"adapter_canonical_heading_rad": adapter_canonical_heading_rad,
					"expected_canonical_heading_rad": expected_canonical_heading_rad,
					"canonical_heading_conversion_error_rad":
					_wrap_angle(
						adapter_canonical_heading_rad - expected_canonical_heading_rad
					),
					"canonical_orientation_xyzw": orientation.duplicate(true),
					"command_mismatches": command_mismatch_details,
					"phase_mismatches": phase_mismatch_details,
				}
			)
	_mismatch_count += step_mismatch_count
	_memory = next_memory.duplicate(true)
	_step_count += 1
	var stability_shadow: Dictionary = sample_result.get("stability_shadow", {})
	var stability_contribution_shadow: Dictionary = stability_shadow.get(
		"stability_contribution_shadow",
		{},
	)
	return {
		"ok": step_mismatch_count == 0,
		"failure_code": "" if step_mismatch_count == 0 else "ADAPTER_DYNAMIC_PARITY_MISMATCH",
		"candidate35_shadow_parity_ok": step_mismatch_count == 0,
		"balanced_wave_shadow_valid": false,
		"controller_policy_id": _controller_policy_id,
		"controller_profile_sha256": _controller_profile_sha256,
		"controller_step_receipt_sha256": String(actuation.get("receipt_sha256", "")),
		"overlay_inputs_valid": true,
		"semantic_step": semantic_step,
		"step_mismatch_count": step_mismatch_count,
		"native_output": output.duplicate(true),
		"stability_contribution_shadow":
		stability_contribution_shadow.duplicate(true),
		"native_actuation_applied": false,
		"actuation_authority": _actuation_authority_enabled,
		"physical_acceptance_authority": false,
	}


func _finish_balanced_wave_shadow_step(
	output: Dictionary,
	semantic_step: int,
	sample_result: Dictionary,
	native_step_transport_verification: Dictionary = {},
) -> Dictionary:
	var failures: Array[String] = []
	var command_validation_receipt := _balanced_wave_command_validation_receipt(
		sample_result,
		semantic_step,
	)
	if not bool(command_validation_receipt.get("ok", false)):
		failures.append(String(command_validation_receipt.get(
			"failure_code",
			"ADAPTER_BALANCED_WAVE_COMMAND_VALIDATION_INVALID",
		)))
	var actuation: Dictionary = output.get("actuation", {})
	var next_memory: Dictionary = output.get("next_memory", {})
	if String(output.get("schema_version", "")) != BALANCED_WAVE_RUNTIME_VERSION:
		failures.append("ADAPTER_BALANCED_WAVE_RUNTIME_VERSION_MISMATCH")
	if String(actuation.get("schema_version", "")) != "sporespore_actuation_frame_v1":
		failures.append("ADAPTER_BALANCED_WAVE_ACTUATION_VERSION_MISMATCH")
	if int(actuation.get("semantic_step", -1)) != semantic_step:
		failures.append("ADAPTER_BALANCED_WAVE_ACTUATION_STEP_MISMATCH")
	if (
		bool(actuation.get("safe_no_actuation", true))
		or int(actuation.get("world_build_count", -1)) != 0
		or bool(actuation.get("physical_acceptance_authority", true))
	):
		failures.append("ADAPTER_BALANCED_WAVE_ACTUATION_AUTHORITY_INVALID")
	var receipt: Dictionary = actuation.get("receipt", {})
	var receipt_sha256 := String(actuation.get("receipt_sha256", ""))
	if (
		not native_step_transport_verification.is_empty()
		and not native_step_transport_verification_receipt_valid_v1(
			native_step_transport_verification,
			_controller_policy_id,
			_balanced_wave_expected_controller_receipt_schema(),
			semantic_step,
			receipt_sha256,
		)
	):
		failures.append("ADAPTER_NATIVE_STEP_TRANSPORT_VERIFICATION_INVALID")
	var r23d2_trace_failure := _record_r23d2_oracle_trace(
		sample_result,
		receipt,
		receipt_sha256,
		semantic_step,
	)
	if not r23d2_trace_failure.is_empty():
		failures.append(r23d2_trace_failure)
	var release_gate_unweighting_receipt: Dictionary = {}
	var forward_velocity_foot_placement_receipt: Dictionary = {}
	var expected_receipt_schema := _balanced_wave_expected_controller_receipt_schema()
	if (
		String(receipt.get("schema_version", "")) != expected_receipt_schema
		or String(receipt.get("policy_id", "")) != _controller_policy_id
		or int(receipt.get("semantic_step", -1)) != semantic_step
		or int(receipt.get("world_build_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
		or not receipt_sha256.begins_with("sha256:")
		or receipt_sha256.length() != 71
	):
		failures.append("ADAPTER_BALANCED_WAVE_RECEIPT_INVALID")
	if _is_bw8u_policy(_controller_policy_id):
		var unweighting_value: Variant = receipt.get(
			"release_gate_unweighting",
			null,
		)
		if typeof(unweighting_value) != TYPE_DICTIONARY:
			failures.append("ADAPTER_BW8U_UNWEIGHTING_RECEIPT_MISSING")
		else:
			var unweighting: Dictionary = unweighting_value
			release_gate_unweighting_receipt = unweighting
			var knee_mode_value: Variant = unweighting.get(
				"knee_target_mode_id",
				null,
			)
			var hip_mode_value: Variant = unweighting.get(
				"hip_target_mode_id",
				null,
			)
			var expected_knee_mode: Variant = _controller_profile.get(
				"release_gate_knee_target_mode_id",
				null,
			)
			var expected_hip_mode: Variant = _controller_profile.get(
				"release_gate_hip_target_mode_id",
				null,
			)
			if (
				String(unweighting.get("schema_version", ""))
				!= "sporespore_release_gate_unweighting_receipt_v1"
				or knee_mode_value != expected_knee_mode
				or hip_mode_value != expected_hip_mode
				or typeof(
					unweighting.get("ordered_knee_override_limb_ids", null)
				) != TYPE_ARRAY
				or typeof(
					unweighting.get("ordered_hip_override_limb_ids", null)
				) != TYPE_ARRAY
				or String(unweighting.get("analytic_target_basis", ""))
				!= "existing_lateral_wave_swing_apex_at_half_swing_v1"
				or int(unweighting.get("morphology_branch_surface_count", -1)) != 0
				or not bool(unweighting.get("controller_parameter", false))
				or bool(unweighting.get("walking_claim_authorized", true))
				or bool(unweighting.get("physical_acceptance_authority", true))
			):
				failures.append("ADAPTER_BW8U_UNWEIGHTING_RECEIPT_INVALID")
	elif receipt.has("release_gate_unweighting"):
		failures.append("ADAPTER_UNEXPECTED_UNWEIGHTING_RECEIPT")
	if _is_forward_velocity_foot_placement_policy(_controller_policy_id):
		var forward_placement_value: Variant = receipt.get(
			"forward_velocity_foot_placement",
			null,
		)
		if typeof(forward_placement_value) != TYPE_DICTIONARY:
			failures.append("ADAPTER_FORWARD_PLACEMENT_RECEIPT_MISSING")
		else:
			var forward_placement: Dictionary = forward_placement_value
			forward_velocity_foot_placement_receipt = forward_placement
			var expected_forward_receipt_schema := (
				"sporespore_forward_velocity_foot_placement_receipt_v2"
				if _is_signed_forward_velocity_policy(_controller_policy_id)
				else "sporespore_forward_velocity_foot_placement_receipt_v1"
			)
			var expected_orientation_value: Variant = (
				_controller_profile.get(
					"forward_velocity_error_orientation_id",
					null,
				)
				if _is_signed_forward_velocity_policy(_controller_policy_id)
				else null
			)
			var observed_orientation_value: Variant = forward_placement.get(
				"velocity_error_orientation_id",
				null,
			)
			var desired_forward_velocity := float(
				forward_placement.get("desired_forward_velocity_task_m_s", NAN)
			)
			var measured_forward_velocity := float(
				forward_placement.get("measured_forward_velocity_task_m_s", NAN)
			)
			var normalized_forward_velocity_error := float(
				forward_placement.get("normalized_forward_velocity_error", NAN)
			)
			var maximum_correction := float(
				forward_placement.get("maximum_hip_target_correction_rad", NAN)
			)
			var expected_normalized_error := 0.0
			if (
				is_finite(desired_forward_velocity)
				and is_finite(measured_forward_velocity)
				and absf(desired_forward_velocity) > 1.0e-12
			):
				expected_normalized_error = clampf(
					(
						desired_forward_velocity
						- measured_forward_velocity
					) / absf(desired_forward_velocity),
					-1.0,
					1.0,
				)
			if (
				expected_orientation_value
				== MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID
			):
				expected_normalized_error = -expected_normalized_error
			var corrections_value: Variant = forward_placement.get(
				"ordered_limb_corrections",
				null,
			)
			var corrections_valid := typeof(corrections_value) == TYPE_ARRAY
			var expected_limb_order := [
				"front_left",
				"front_right",
				"rear_left",
				"rear_right",
			]
			if corrections_valid:
				var corrections: Array = corrections_value
				corrections_valid = corrections.size() == expected_limb_order.size()
				for index in range(mini(corrections.size(), expected_limb_order.size())):
					var correction_value: Variant = corrections[index]
					if typeof(correction_value) != TYPE_DICTIONARY:
						corrections_valid = false
						continue
					var correction: Dictionary = correction_value
					var cycle_envelope := float(correction.get("cycle_envelope", NAN))
					var applied_correction := float(
						correction.get("applied_hip_target_correction_rad", NAN)
					)
					if (
						String(correction.get("limb_id", ""))
						!= String(expected_limb_order[index])
						or int(correction.get("local_phase_step", -1)) < 0
						or int(correction.get("local_phase_step", -1)) >= 360
						or not is_finite(cycle_envelope)
						or cycle_envelope < 0.0
						or cycle_envelope > 1.0
						or not is_finite(applied_correction)
						or absf(applied_correction) > maximum_correction + 1.0e-12
					):
						corrections_valid = false
			if (
				String(forward_placement.get("schema_version", ""))
				!= expected_forward_receipt_schema
				or String(forward_placement.get("mode_id", ""))
				!= FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID
				or String(_controller_profile.get(
					"forward_velocity_foot_placement_mode_id",
					"",
				)) != FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID
				or observed_orientation_value != expected_orientation_value
				or (
					_is_signed_forward_velocity_policy(_controller_policy_id)
					and not [
						DESIRED_MINUS_MEASURED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
						MEASURED_MINUS_DESIRED_FORWARD_VELOCITY_ERROR_ORIENTATION_ID,
					].has(String(observed_orientation_value))
				)
				or not is_finite(desired_forward_velocity)
				or not is_finite(measured_forward_velocity)
				or not is_finite(normalized_forward_velocity_error)
				or absf(normalized_forward_velocity_error) > 1.0 + 1.0e-12
				or absf(
					normalized_forward_velocity_error - expected_normalized_error
				) > 1.0e-12
				or not is_finite(maximum_correction)
				or maximum_correction <= 0.0
				or absf(float(_controller_profile.get(
					"maximum_forward_velocity_hip_target_correction_rad",
					NAN,
				)) - maximum_correction) > 1.0e-12
				or not corrections_valid
				or int(forward_placement.get("morphology_branch_surface_count", -1)) != 0
				or not bool(forward_placement.get("controller_parameter", false))
				or bool(forward_placement.get("walking_claim_authorized", true))
				or bool(forward_placement.get("physical_acceptance_authority", true))
			):
				failures.append("ADAPTER_FORWARD_PLACEMENT_RECEIPT_INVALID")
	elif receipt.has("forward_velocity_foot_placement"):
		failures.append("ADAPTER_UNEXPECTED_FORWARD_PLACEMENT_RECEIPT")
	var requested_steering_fraction := float(
		receipt.get("requested_steering_fraction", NAN)
	)
	var previous_steering_fraction := float(
		receipt.get("previous_steering_fraction", NAN)
	)
	var held_steering_fraction := float(receipt.get("held_steering_fraction", NAN))
	var applied_steering_delta := float(receipt.get("applied_steering_delta", NAN))
	var cross_track_error_m := float(receipt.get("cross_track_error_m", NAN))
	var filter_alpha_value: Variant = receipt.get("steering_filter_alpha_per_step", null)
	var filter_time_constant_value: Variant = receipt.get(
		"steering_filter_time_constant_cycle_fraction",
		null,
	)
	var filter_pair_valid := (
		(filter_alpha_value == null and filter_time_constant_value == null)
		or (
			(typeof(filter_alpha_value) == TYPE_FLOAT or typeof(filter_alpha_value) == TYPE_INT)
			and (
				typeof(filter_time_constant_value) == TYPE_FLOAT
				or typeof(filter_time_constant_value) == TYPE_INT
			)
			and is_finite(float(filter_alpha_value))
			and float(filter_alpha_value) > 0.0
			and float(filter_alpha_value) <= 1.0
			and is_finite(float(filter_time_constant_value))
			and float(filter_time_constant_value) > 0.0
		)
	)
	if (
		not is_finite(requested_steering_fraction)
		or not is_finite(previous_steering_fraction)
		or not is_finite(held_steering_fraction)
		or not is_finite(applied_steering_delta)
		or not is_finite(cross_track_error_m)
		or absf(held_steering_fraction) > 0.40 + 1.0e-12
		or absf(applied_steering_delta - (held_steering_fraction - previous_steering_fraction))
		> 1.0e-12
		or absf(held_steering_fraction - float(next_memory.get(
			"held_path_steering_fraction",
			NAN,
		))) > 1.0e-12
		or typeof(receipt.get("steering_feedback_updated", null)) != TYPE_BOOL
		or typeof(receipt.get("steering_saturated", null)) != TYPE_BOOL
		or typeof(receipt.get("steering_slew_limited", null)) != TYPE_BOOL
		or not filter_pair_valid
	):
		failures.append("ADAPTER_BALANCED_WAVE_STEERING_RECEIPT_INVALID")
	var morphology: Dictionary = _compiled.get("morphology", {})
	var expected_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var commands: Array = actuation.get("ordered_commands", [])
	if commands.size() != expected_actuator_ids.size():
		failures.append("ADAPTER_BALANCED_WAVE_COMMAND_CARDINALITY_MISMATCH")
	var actuator_by_id: Dictionary = {}
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	for actuator_value in morphology_spec.get("actuators", []):
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	for index in range(mini(commands.size(), expected_actuator_ids.size())):
		var command: Dictionary = commands[index]
		var expected_actuator_id := String(expected_actuator_ids[index])
		var actuator_id := String(command.get("actuator_id", ""))
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		var target_velocity := float(command.get("target_velocity_rad_s", NAN))
		var requested_position := float(command.get("requested_target_position_rad", NAN))
		var clamped_position := float(command.get("clamped_target_position_rad", NAN))
		var residual := float(command.get("residual_contribution_rad_s", NAN))
		var safety := float(command.get("safety_contribution_rad_s", NAN))
		if actuator_id != expected_actuator_id:
			failures.append("ADAPTER_BALANCED_WAVE_COMMAND_ORDER_MISMATCH")
			continue
		if (
			not is_finite(maximum_speed)
			or not is_finite(target_velocity)
			or not is_finite(requested_position)
			or not is_finite(clamped_position)
			or not is_finite(residual)
			or not is_finite(safety)
			or maximum_speed <= 0.0
			or absf(target_velocity) > maximum_speed + 1.0e-12
			or int(command.get("valid_through_step", -1)) < semantic_step
		):
			failures.append("ADAPTER_BALANCED_WAVE_COMMAND_BOUNDS_INVALID")
			continue
		if not actuator_by_id.has(actuator_id):
			failures.append("ADAPTER_BALANCED_WAVE_ACTUATOR_SPEC_MISSING")
			continue
		var actuator: Dictionary = actuator_by_id[actuator_id]
		if (
			clamped_position
			< float(actuator.get("minimum_target_position_rad", INF)) - 1.0e-12
			or clamped_position
			> float(actuator.get("maximum_target_position_rad", -INF)) + 1.0e-12
		):
			failures.append("ADAPTER_BALANCED_WAVE_POSITION_BOUNDS_INVALID")
	var memory_schema_receipt := _balanced_wave_memory_schema_receipt(next_memory)
	if not bool(memory_schema_receipt.get("ok", false)):
		failures.append("ADAPTER_BALANCED_WAVE_MEMORY_VERSION_MISMATCH")
	if int(next_memory.get("last_semantic_step", -1)) != semantic_step:
		failures.append("ADAPTER_BALANCED_WAVE_MEMORY_STEP_MISMATCH")
	var expected_limb_ids: Array = []
	for previous_limb_memory_value in _memory.get("ordered_limb_memory", []):
		var previous_limb_memory: Dictionary = previous_limb_memory_value
		expected_limb_ids.append(String(previous_limb_memory.get("limb_id", "")))
	var ordered_limb_memory: Array = next_memory.get("ordered_limb_memory", [])
	if ordered_limb_memory.size() != expected_limb_ids.size():
		failures.append("ADAPTER_BALANCED_WAVE_MEMORY_CARDINALITY_MISMATCH")
	for index in range(mini(ordered_limb_memory.size(), expected_limb_ids.size())):
		var limb_memory: Dictionary = ordered_limb_memory[index]
		if String(limb_memory.get("limb_id", "")) != String(expected_limb_ids[index]):
			failures.append("ADAPTER_BALANCED_WAVE_MEMORY_ORDER_MISMATCH")
	if not failures.is_empty():
		for failure in failures:
			_record_failure(failure)
	else:
		_balanced_wave_step_receipt_count += 1
		_balanced_wave_native_validation_step_count += 1
		if bool(command_validation_receipt.get("heading_command_conditioned", false)):
			_balanced_wave_heading_conditioned_step_count += 1
		else:
			_balanced_wave_unconditioned_step_count += 1
		if _is_bw8u_policy(_controller_policy_id):
			_release_gate_unweighting_receipt_count += 1
			var knee_override_limb_ids: Array = release_gate_unweighting_receipt.get(
				"ordered_knee_override_limb_ids",
				[],
			)
			var hip_override_limb_ids: Array = release_gate_unweighting_receipt.get(
				"ordered_hip_override_limb_ids",
				[],
			)
			_release_gate_knee_override_limb_count += knee_override_limb_ids.size()
			_release_gate_hip_override_limb_count += hip_override_limb_ids.size()
			if not knee_override_limb_ids.is_empty():
				_release_gate_knee_override_step_count += 1
			if not hip_override_limb_ids.is_empty():
				_release_gate_hip_override_step_count += 1
		if _is_forward_velocity_foot_placement_policy(_controller_policy_id):
			_forward_velocity_foot_placement_receipt_count += 1
			_maximum_absolute_normalized_forward_velocity_error = maxf(
				_maximum_absolute_normalized_forward_velocity_error,
				absf(float(forward_velocity_foot_placement_receipt.get(
					"normalized_forward_velocity_error",
					0.0,
				))),
			)
			for correction_value in forward_velocity_foot_placement_receipt.get(
				"ordered_limb_corrections",
				[],
			):
				var correction: Dictionary = correction_value
				_maximum_absolute_forward_velocity_hip_target_correction_rad = maxf(
					_maximum_absolute_forward_velocity_hip_target_correction_rad,
					absf(float(correction.get(
						"applied_hip_target_correction_rad",
						0.0,
					))),
				)
		if bool(receipt["steering_feedback_updated"]):
			_steering_feedback_update_count += 1
		if filter_alpha_value != null:
			_steering_filter_application_count += 1
		if bool(receipt["steering_saturated"]):
			_steering_saturation_count += 1
		if bool(receipt["steering_slew_limited"]):
			_steering_slew_limited_count += 1
		_maximum_absolute_requested_steering_fraction = maxf(
			_maximum_absolute_requested_steering_fraction,
			absf(requested_steering_fraction),
		)
		_maximum_absolute_filtered_steering_fraction = maxf(
			_maximum_absolute_filtered_steering_fraction,
			absf(held_steering_fraction),
		)
		_maximum_absolute_steering_delta_per_step = maxf(
			_maximum_absolute_steering_delta_per_step,
			absf(applied_steering_delta),
		)
		_cumulative_absolute_cross_track_error_m_steps += absf(cross_track_error_m)
		_minimum_cross_track_error_m = minf(_minimum_cross_track_error_m, cross_track_error_m)
		_maximum_cross_track_error_m = maxf(_maximum_cross_track_error_m, cross_track_error_m)
		if _balanced_wave_first_step_receipt_sha256.is_empty():
			_balanced_wave_first_step_receipt_sha256 = receipt_sha256
		_balanced_wave_last_step_receipt_sha256 = receipt_sha256
	_mismatch_count += failures.size()
	_validated_balanced_wave_command_count += commands.size()
	_memory = next_memory.duplicate(true)
	_step_count += 1
	var stability_shadow: Dictionary = sample_result.get("stability_shadow", {})
	var stability_contribution_shadow: Dictionary = stability_shadow.get(
		"stability_contribution_shadow",
		{},
	)
	var result := {
		"ok": failures.is_empty(),
		"failure_code":
		"" if failures.is_empty() else "ADAPTER_BALANCED_WAVE_SHADOW_INVALID",
		"candidate35_shadow_parity_ok": false,
		"balanced_wave_shadow_valid": failures.is_empty(),
		"balanced_wave_command_validation_receipt":
		command_validation_receipt.duplicate(true),
		"balanced_wave_memory_schema_receipt": memory_schema_receipt.duplicate(true),
		"controller_policy_id": _controller_policy_id,
		"controller_profile_sha256": _controller_profile_sha256,
		"controller_step_receipt_sha256": receipt_sha256,
		"overlay_inputs_valid": true,
		"semantic_step": semantic_step,
		"step_mismatch_count": failures.size(),
		"failure_codes": failures.duplicate(),
		"native_output": output.duplicate(true),
		"stability_contribution_shadow":
		stability_contribution_shadow.duplicate(true),
		"native_actuation_applied": false,
		"actuation_authority": false,
		"physical_acceptance_authority": false,
	}
	if not native_step_transport_verification.is_empty():
		result["native_step_transport_verification"] = (
			native_step_transport_verification.duplicate(true)
		)
	return result


## Resolves the exact configured motor-cap vector that apply_authority() will
## check against the live HingeJoint3D readbacks. An empty override preserves
## the compiled portable morphology caps. A non-empty override must be a
## complete, exact, finite, positive replacement keyed by every ordered
## actuator ID; partial or extra maps fail closed. The function is static so a
## zero-world gate can exercise the production validation path directly.
static func resolve_authorized_maximum_impulse_by_actuator_id(
	morphology: Dictionary,
	maximum_impulse_override_by_actuator_id: Dictionary = {},
) -> Dictionary:
	var failure := {
		"ok": false,
		"failure_code": "AUTHORIZED_MAXIMUM_IMPULSE_INPUT_INVALID",
		"maximum_impulse_by_actuator_id": {},
		"validated_actuator_count": 0,
		"override_applied": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var ordered_actuator_ids_value: Variant = morphology.get("ordered_actuator_ids", null)
	var morphology_spec_value: Variant = morphology.get("morphology_spec", null)
	if (
		typeof(ordered_actuator_ids_value) != TYPE_ARRAY
		or (ordered_actuator_ids_value as Array).is_empty()
		or typeof(morphology_spec_value) != TYPE_DICTIONARY
	):
		return failure
	var ordered_actuator_ids: Array = ordered_actuator_ids_value
	var morphology_spec: Dictionary = morphology_spec_value
	var actuators_value: Variant = morphology_spec.get("actuators", null)
	if typeof(actuators_value) != TYPE_ARRAY:
		failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ACTUATORS_INVALID"
		return failure
	var compiled_maximum_impulse_by_actuator_id: Dictionary = {}
	for actuator_value in actuators_value as Array:
		if typeof(actuator_value) != TYPE_DICTIONARY:
			failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ACTUATOR_ROW_INVALID"
			return failure
		var actuator: Dictionary = actuator_value
		var actuator_id_value: Variant = actuator.get("actuator_id", null)
		var maximum_impulse_value: Variant = actuator.get("maximum_impulse_nms", null)
		if (
			typeof(actuator_id_value) != TYPE_STRING
			or String(actuator_id_value).is_empty()
			or compiled_maximum_impulse_by_actuator_id.has(String(actuator_id_value))
			or (
				typeof(maximum_impulse_value) != TYPE_FLOAT
				and typeof(maximum_impulse_value) != TYPE_INT
			)
			or not is_finite(float(maximum_impulse_value))
			or float(maximum_impulse_value) <= 0.0
		):
			failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ACTUATOR_VALUE_INVALID"
			return failure
		compiled_maximum_impulse_by_actuator_id[String(actuator_id_value)] = float(
			maximum_impulse_value
		)
	if compiled_maximum_impulse_by_actuator_id.size() != ordered_actuator_ids.size():
		failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ACTUATOR_CARDINALITY_INVALID"
		return failure
	var override_applied := not maximum_impulse_override_by_actuator_id.is_empty()
	if (
		override_applied
		and maximum_impulse_override_by_actuator_id.size() != ordered_actuator_ids.size()
	):
		failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_OVERRIDE_CARDINALITY_INVALID"
		return failure
	var resolved: Dictionary = {}
	for actuator_id_value in ordered_actuator_ids:
		if typeof(actuator_id_value) != TYPE_STRING:
			failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ORDER_INVALID"
			return failure
		var actuator_id := String(actuator_id_value)
		if (
			actuator_id.is_empty()
			or resolved.has(actuator_id)
			or not compiled_maximum_impulse_by_actuator_id.has(actuator_id)
			or (
				override_applied
				and not maximum_impulse_override_by_actuator_id.has(actuator_id)
			)
		):
			failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_ORDER_INVALID"
			return failure
		var selected_value: Variant = compiled_maximum_impulse_by_actuator_id[actuator_id]
		if override_applied:
			selected_value = maximum_impulse_override_by_actuator_id[actuator_id]
		if (
			(typeof(selected_value) != TYPE_FLOAT and typeof(selected_value) != TYPE_INT)
			or not is_finite(float(selected_value))
			or float(selected_value) <= 0.0
		):
			failure["failure_code"] = "AUTHORIZED_MAXIMUM_IMPULSE_SELECTED_VALUE_INVALID"
			return failure
		resolved[actuator_id] = float(selected_value)
	return {
		"schema_version": "sporespore_authorized_maximum_impulse_resolution_v1",
		"ok": true,
		"failure_code": "",
		"maximum_impulse_by_actuator_id": resolved.duplicate(true),
		"validated_actuator_count": resolved.size(),
		"override_applied": override_applied,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func apply_authority(
	step_result: Dictionary,
	joint_state_by_joint_id: Dictionary,
	include_actuator_phase_observation: bool = false,
	maximum_impulse_override_by_actuator_id: Dictionary = {},
) -> Dictionary:
	if not _started:
		return _authority_failure("ADAPTER_NOT_STARTED", joint_state_by_joint_id)
	if not _actuation_authority_enabled:
		return _authority_failure("ADAPTER_ACTUATION_AUTHORITY_DISABLED", joint_state_by_joint_id)
	if _authority_scope == "stability_contribution_overlay":
		return _authority_failure(
			"ADAPTER_FULL_AUTHORITY_FORBIDDEN_FOR_STABILITY_OVERLAY",
			joint_state_by_joint_id,
		)
	if not bool(step_result.get("ok", false)):
		return _authority_failure(
			"ADAPTER_AUTHORITY_STEP_INVALID:%s" % String(step_result.get("failure_code", "")),
			joint_state_by_joint_id,
		)
	var output: Dictionary = step_result.get("native_output", {})
	var actuation: Dictionary = output.get("actuation", {})
	if bool(actuation.get("safe_no_actuation", true)):
		return _authority_failure("ADAPTER_AUTHORITY_SAFE_NO_ACTUATION", joint_state_by_joint_id)
	var commands: Array = actuation.get("ordered_commands", [])
	var expected_actuator_ids: Array = (
		(_compiled.get("morphology", {}) as Dictionary).get("ordered_actuator_ids", [])
	)
	if commands.size() != expected_actuator_ids.size():
		return _authority_failure("ADAPTER_AUTHORITY_COMMAND_CARDINALITY", joint_state_by_joint_id)
	var morphology: Dictionary = _compiled.get("morphology", {})
	var maximum_impulse_override_applied := not (
		maximum_impulse_override_by_actuator_id.is_empty()
	)
	var declared_maximum_impulse_by_actuator_id: Dictionary = {}
	if maximum_impulse_override_applied:
		var maximum_impulse_resolution := (
			resolve_authorized_maximum_impulse_by_actuator_id(
				morphology,
				maximum_impulse_override_by_actuator_id,
			)
		)
		if not bool(maximum_impulse_resolution.get("ok", false)):
			return _authority_failure(
				"ADAPTER_AUTHORITY_MAXIMUM_IMPULSE_RESOLUTION_INVALID:%s"
				% String(maximum_impulse_resolution.get("failure_code", "UNKNOWN")),
				joint_state_by_joint_id,
			)
		declared_maximum_impulse_by_actuator_id = (
			maximum_impulse_resolution.get("maximum_impulse_by_actuator_id", {})
		)
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var actuator_by_id: Dictionary = {}
	for actuator_value in morphology_spec.get("actuators", []):
		if typeof(actuator_value) != TYPE_DICTIONARY:
			continue
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	var limb_context_by_joint_id: Dictionary = {}
	for limb_value in morphology_spec.get("limbs", []):
		if typeof(limb_value) != TYPE_DICTIONARY:
			continue
		var limb: Dictionary = limb_value
		var ordered_joint_ids: Array = limb.get("ordered_joint_ids", [])
		for limb_joint_index in range(ordered_joint_ids.size()):
			limb_context_by_joint_id[String(ordered_joint_ids[limb_joint_index])] = {
				"limb_id": String(limb.get("limb_id", "")),
				"limb_joint_index": limb_joint_index,
			}
	var pending_applications: Array[Dictionary] = []
	for command_index in range(commands.size()):
		var command: Dictionary = commands[command_index]
		var actuator_id := String(command.get("actuator_id", ""))
		if actuator_id != String(expected_actuator_ids[command_index]):
			return _authority_failure("ADAPTER_AUTHORITY_COMMAND_ORDER", joint_state_by_joint_id)
		if String(command.get("mode", "")) != "position_velocity":
			return _authority_failure(
				"ADAPTER_AUTHORITY_MODE_UNSUPPORTED:%s" % actuator_id,
				joint_state_by_joint_id,
			)
		var legacy_joint_id := _legacy_joint_id_for_actuator(actuator_id)
		if legacy_joint_id.is_empty() or not joint_state_by_joint_id.has(legacy_joint_id):
			return _authority_failure(
				"ADAPTER_AUTHORITY_JOINT_MAPPING_MISSING:%s" % actuator_id,
				joint_state_by_joint_id,
			)
		var target_velocity_rad_s := float(command.get("target_velocity_rad_s", NAN))
		var maximum_target_speed_rad_s := float(
			command.get("maximum_target_speed_rad_s", NAN)
		)
		if not actuator_by_id.has(actuator_id):
			return _authority_failure(
				"ADAPTER_AUTHORITY_ACTUATOR_SPEC_MISSING:%s" % actuator_id,
				joint_state_by_joint_id,
			)
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var portable_joint_id := String(actuator.get("joint_id", ""))
		var declared_maximum_impulse_nms := float(
			actuator.get("maximum_impulse_nms", NAN)
		)
		if maximum_impulse_override_applied:
			declared_maximum_impulse_nms = float(
				declared_maximum_impulse_by_actuator_id.get(actuator_id, NAN)
			)
		else:
			declared_maximum_impulse_by_actuator_id[actuator_id] = (
				declared_maximum_impulse_nms
			)
		var limb_context: Dictionary = limb_context_by_joint_id.get(portable_joint_id, {})
		if (
			not is_finite(target_velocity_rad_s)
			or not is_finite(maximum_target_speed_rad_s)
			or not is_finite(declared_maximum_impulse_nms)
			or maximum_target_speed_rad_s <= 0.0
			or declared_maximum_impulse_nms <= 0.0
			or absf(target_velocity_rad_s) > maximum_target_speed_rad_s + _tolerance
			or portable_joint_id.is_empty()
			or limb_context.is_empty()
		):
			return _authority_failure(
				"ADAPTER_AUTHORITY_COMMAND_OUT_OF_BOUNDS:%s" % actuator_id,
				joint_state_by_joint_id,
			)
		var joint_state: Dictionary = joint_state_by_joint_id[legacy_joint_id]
		var joint: HingeJoint3D = joint_state.get("joint")
		if joint == null:
			return _authority_failure(
				"ADAPTER_AUTHORITY_JOINT_UNAVAILABLE:%s" % actuator_id,
				joint_state_by_joint_id,
			)
		pending_applications.append(
			{
				"actuator_id": actuator_id,
				"joint_id": portable_joint_id,
				"host_joint_id": legacy_joint_id,
				"limb_id": String(limb_context.get("limb_id", "")),
				"limb_joint_index": int(limb_context.get("limb_joint_index", -1)),
				"joint": joint,
				"requested_target_position_rad":
				float(command.get("requested_target_position_rad", NAN)),
				"clamped_target_position_rad":
				float(command.get("clamped_target_position_rad", NAN)),
				"target_velocity_rad_s": target_velocity_rad_s,
				"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
				"declared_maximum_impulse_nms": declared_maximum_impulse_nms,
				"position_saturated": bool(command.get("position_saturated", false)),
				"velocity_saturated": bool(command.get("velocity_saturated", false)),
				"slew_limited": bool(command.get("slew_limited", false)),
			}
		)
	for application in pending_applications:
		var joint: HingeJoint3D = application["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			float(application["target_velocity_rad_s"]),
		)
	var ordered_applications: Array[Dictionary] = []
	var maximum_target_velocity_readback_error_rad_s := 0.0
	var maximum_impulse_readback_error_nms := 0.0
	for application in pending_applications:
		var joint: HingeJoint3D = application["joint"]
		var target_readback := joint.get_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		)
		var impulse_readback := joint.get_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
		)
		var target_error := absf(
			target_readback - float(application["target_velocity_rad_s"])
		)
		var impulse_error := absf(
			impulse_readback - float(application["declared_maximum_impulse_nms"])
		)
		maximum_target_velocity_readback_error_rad_s = maxf(
			maximum_target_velocity_readback_error_rad_s,
			target_error,
		)
		maximum_impulse_readback_error_nms = maxf(
			maximum_impulse_readback_error_nms,
			impulse_error,
		)
		ordered_applications.append(
			{
				"actuator_id": String(application["actuator_id"]),
				"joint_id": String(application["joint_id"]),
				"host_joint_id": String(application["host_joint_id"]),
				"limb_id": String(application["limb_id"]),
				"limb_joint_index": int(application["limb_joint_index"]),
				"requested_target_position_rad":
				float(application["requested_target_position_rad"]),
				"clamped_target_position_rad":
				float(application["clamped_target_position_rad"]),
				"controller_target_velocity_rad_s":
				float(application["target_velocity_rad_s"]),
				"maximum_target_speed_rad_s":
				float(application["maximum_target_speed_rad_s"]),
				"host_applied_target_velocity_rad_s":
				float(application["target_velocity_rad_s"]),
				"motor_target_velocity_readback_rad_s": target_readback,
				"motor_target_velocity_readback_error_rad_s": target_error,
				"declared_maximum_impulse_nms":
				float(application["declared_maximum_impulse_nms"]),
				"motor_maximum_impulse_readback_nms": impulse_readback,
				"motor_maximum_impulse_readback_error_nms": impulse_error,
				"position_saturated": bool(application["position_saturated"]),
				"velocity_saturated": bool(application["velocity_saturated"]),
				"slew_limited": bool(application["slew_limited"]),
				"host_additional_clamp_applied": false,
				"target_velocity_readback_matches": target_error <= _tolerance,
				"maximum_impulse_readback_matches": impulse_error <= _tolerance,
			}
		)
	_native_actuation_application_count += pending_applications.size()
	var result := {
		"ok": true,
		"failure_code": "",
		"semantic_step": int(step_result.get("semantic_step", -1)),
		"applied_command_count": pending_applications.size(),
		"actuation_authority": true,
		"physical_acceptance_authority": false,
	}
	if include_actuator_phase_observation:
		result["schema_version"] = (
			"sporespore_godot_jolt_full_authority_application_receipt_v1"
		)
		result["ordered_actuator_ids"] = expected_actuator_ids.duplicate()
		result["ordered_applications"] = ordered_applications
		result["readback_tolerance"] = _tolerance
		result["maximum_target_velocity_readback_error_rad_s"] = (
			maximum_target_velocity_readback_error_rad_s
		)
		result["maximum_impulse_readback_error_nms"] = (
			maximum_impulse_readback_error_nms
		)
		result["maximum_impulse_override_applied"] = maximum_impulse_override_applied
		result["authorized_maximum_impulse_by_actuator_id"] = (
			declared_maximum_impulse_by_actuator_id.duplicate(true)
		)
		result["configured_motor_parameters_only"] = true
		result["measured_motor_torque_available"] = false
		result["measured_motor_impulse_available"] = false
	return result


func record_external_terminal_authority_application(
	step_result: Dictionary,
	applied_command_count: int,
) -> Dictionary:
	var semantic_step := int(step_result.get("semantic_step", -1))
	if (
		not _started
		or not _actuation_authority_enabled
		or not _stability_contribution_shadow_only_until_terminal
		or semantic_step < 0
		or semantic_step <= _external_terminal_previous_semantic_step
		or applied_command_count != 8
	):
		return _failure("R23D11_EXTERNAL_TERMINAL_APPLICATION_INVALID")
	_external_terminal_previous_semantic_step = semantic_step
	_external_terminal_application_step_count += 1
	_external_terminal_motor_write_count += applied_command_count
	_native_actuation_application_count += applied_command_count
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"applied_command_count": applied_command_count,
		"external_terminal_application_recorded": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func apply_stability_contribution(
	step_result: Dictionary,
	legacy_command_context_by_joint_id: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	if not _started:
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_ADAPTER_NOT_STARTED",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	if (
		not _actuation_authority_enabled
		or not _uses_stability_contribution_actuation()
		or not _is_stability_feedback_authority_policy(_stability_policy_id)
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_AUTHORITY_SCOPE_INVALID",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	var step_failure_code := String(step_result.get("failure_code", ""))
	if (
		not bool(step_result.get("overlay_inputs_valid", false))
		or (
			not bool(step_result.get("ok", false))
			and step_failure_code != "ADAPTER_DYNAMIC_PARITY_MISMATCH"
		)
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_STEP_INVALID:%s"
			% step_failure_code,
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	var native_output: Dictionary = step_result.get("native_output", {})
	var native_actuation: Dictionary = native_output.get("actuation", {})
	var native_base_commands: Array = native_actuation.get("ordered_commands", [])
	var portable_base_enabled := _is_balanced_wave_policy(_controller_policy_id)
	if (
		native_output.is_empty()
		or native_actuation.is_empty()
		or bool(native_actuation.get("safe_no_actuation", true))
		or (
			portable_base_enabled
			and native_base_commands.size()
			!= (
				(_compiled.get("morphology", {}) as Dictionary)
				. get("ordered_actuator_ids", [])
			).size()
		)
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_NATIVE_OUTPUT_INVALID",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	var contribution: Dictionary = step_result.get(
		"stability_contribution_shadow",
		{},
	)
	if (
		not bool(contribution.get("ok", false))
		or String(contribution.get("stability_policy_id", ""))
		!= _stability_policy_id
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_CONTRIBUTION_INVALID:%s"
			% String(contribution.get("failure_code", "")),
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	var influence_receipt: Dictionary = contribution.get("influence_receipt", {})
	if (
		int(influence_receipt.get("semantic_step", -1))
		!= int(step_result.get("semantic_step", -2))
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_SEMANTIC_STEP_STALE",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)
	var ordered_contributions: Array = contribution.get(
		"ordered_contributions",
		[],
	)
	var expected_actuator_ids: Array = (
		(_compiled.get("morphology", {}) as Dictionary).get("ordered_actuator_ids", [])
	)
	if (
		expected_actuator_ids.size() != 8
		or ordered_contributions.size() != expected_actuator_ids.size()
	):
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_COMMAND_CARDINALITY",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)

	var pending_applications: Array[Dictionary] = []
	for command_index in range(ordered_contributions.size()):
		var command: Dictionary = ordered_contributions[command_index]
		var actuator_id := String(command.get("actuator_id", ""))
		if actuator_id != String(expected_actuator_ids[command_index]):
			return _stability_overlay_failure(
				"STABILITY_OVERLAY_COMMAND_ORDER",
				legacy_command_context_by_joint_id,
				joint_state_by_joint_id,
			)
		var legacy_joint_id := _legacy_joint_id_for_actuator(actuator_id)
		if (
			legacy_joint_id.is_empty()
			or (
				not portable_base_enabled
				and not legacy_command_context_by_joint_id.has(legacy_joint_id)
			)
			or not joint_state_by_joint_id.has(legacy_joint_id)
		):
			return _stability_overlay_failure(
				"STABILITY_OVERLAY_JOINT_MAPPING_MISSING:%s" % actuator_id,
				legacy_command_context_by_joint_id,
				joint_state_by_joint_id,
			)
		var joint_state: Dictionary = joint_state_by_joint_id[legacy_joint_id]
		var joint: HingeJoint3D = joint_state.get("joint")
		var base_context: Dictionary
		if portable_base_enabled:
			var native_base_command_value: Variant = native_base_commands[command_index]
			if typeof(native_base_command_value) != TYPE_DICTIONARY:
				return _stability_overlay_failure(
					"STABILITY_OVERLAY_PORTABLE_BASE_COMMAND_INVALID:%s"
					% actuator_id,
					legacy_command_context_by_joint_id,
					joint_state_by_joint_id,
				)
			var native_base_command: Dictionary = native_base_command_value
			if (
				String(native_base_command.get("actuator_id", "")) != actuator_id
				or String(native_base_command.get("mode", ""))
				!= "position_velocity"
			):
				return _stability_overlay_failure(
					"STABILITY_OVERLAY_PORTABLE_BASE_COMMAND_ORDER_OR_MODE:%s"
					% actuator_id,
					legacy_command_context_by_joint_id,
					joint_state_by_joint_id,
				)
			base_context = native_base_command
		else:
			base_context = legacy_command_context_by_joint_id[legacy_joint_id]
		var base_target_velocity_rad_s := float(
			base_context.get("target_velocity_rad_s", NAN)
		)
		var maximum_target_speed_rad_s := float(
			base_context.get("maximum_target_speed_rad_s", NAN)
		)
		var requested_delta_rad_s := float(
			command.get("host_target_velocity_delta_rad_s", NAN)
		)
		if (
			joint == null
			or not is_finite(base_target_velocity_rad_s)
			or not is_finite(maximum_target_speed_rad_s)
			or maximum_target_speed_rad_s <= 0.0
			or absf(base_target_velocity_rad_s)
			> maximum_target_speed_rad_s + _tolerance
			or not is_finite(requested_delta_rad_s)
			or absf(requested_delta_rad_s)
			> CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S + 1.0e-12
		):
			return _stability_overlay_failure(
				"STABILITY_OVERLAY_COMMAND_OUT_OF_BOUNDS:%s" % actuator_id,
				legacy_command_context_by_joint_id,
				joint_state_by_joint_id,
			)
		var host_base_target_velocity_rad_s := _host_real_t(
			base_target_velocity_rad_s
		)
		var host_maximum_target_speed_rad_s := _host_real_t(
			maximum_target_speed_rad_s
		)
		var unbounded_target_velocity_rad_s := (
			host_base_target_velocity_rad_s + requested_delta_rad_s
		)
		var bounded_binary64_target_velocity_rad_s := clampf(
			unbounded_target_velocity_rad_s,
			-host_maximum_target_speed_rad_s,
			host_maximum_target_speed_rad_s,
		)
		var combined_target_velocity_rad_s := _host_real_t(
			bounded_binary64_target_velocity_rad_s
		)
		var effective_delta_rad_s := (
			combined_target_velocity_rad_s - host_base_target_velocity_rad_s
		)
		var host_command_quantization_error_rad_s := absf(
			combined_target_velocity_rad_s
			- bounded_binary64_target_velocity_rad_s
		)
		if (
			not is_finite(combined_target_velocity_rad_s)
			or not is_finite(effective_delta_rad_s)
			or absf(combined_target_velocity_rad_s)
			> host_maximum_target_speed_rad_s
			or absf(effective_delta_rad_s)
			> CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S + 1.0e-12
			or host_command_quantization_error_rad_s
			> P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S
		):
			return _stability_overlay_failure(
				"STABILITY_OVERLAY_EFFECTIVE_COMMAND_OUT_OF_BOUNDS:%s"
				% actuator_id,
				legacy_command_context_by_joint_id,
				joint_state_by_joint_id,
			)
		pending_applications.append(
			{
				"actuator_id": actuator_id,
				"joint_id": legacy_joint_id,
				"joint": joint,
				"base_target_velocity_rad_s": base_target_velocity_rad_s,
				"host_base_target_velocity_rad_s":
				host_base_target_velocity_rad_s,
				"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
				"host_maximum_target_speed_rad_s":
				host_maximum_target_speed_rad_s,
				"requested_delta_rad_s": requested_delta_rad_s,
				"unbounded_target_velocity_rad_s":
				unbounded_target_velocity_rad_s,
				"bounded_binary64_target_velocity_rad_s":
				bounded_binary64_target_velocity_rad_s,
				"combined_target_velocity_rad_s":
				combined_target_velocity_rad_s,
				"effective_delta_rad_s": effective_delta_rad_s,
				"host_command_quantization_error_rad_s":
				host_command_quantization_error_rad_s,
				"host_saturated":
				bounded_binary64_target_velocity_rad_s
				!= unbounded_target_velocity_rad_s,
				"base_command_source":
				(
					"portable_controller_ordered_commands"
					if portable_base_enabled
					else "legacy_host_command_context"
				),
			}
		)

	for application in pending_applications:
		var joint: HingeJoint3D = application["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			float(application["combined_target_velocity_rad_s"]),
		)
	var maximum_readback_error_rad_s := 0.0
	for application in pending_applications:
		var joint: HingeJoint3D = application["joint"]
		var readback_velocity_rad_s := joint.get_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
		)
		var readback_error_rad_s := absf(
			readback_velocity_rad_s
			- float(application["combined_target_velocity_rad_s"])
		)
		application["readback_velocity_rad_s"] = readback_velocity_rad_s
		application["readback_error_rad_s"] = readback_error_rad_s
		maximum_readback_error_rad_s = maxf(
			maximum_readback_error_rad_s,
			readback_error_rad_s,
		)
	if maximum_readback_error_rad_s > P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S:
		return _stability_overlay_failure(
			"STABILITY_OVERLAY_MOTOR_READBACK_MISMATCH",
			legacy_command_context_by_joint_id,
			joint_state_by_joint_id,
		)

	var nonzero_effective_application_count := 0
	var host_saturation_count := 0
	var maximum_absolute_requested_delta_rad_s := 0.0
	var maximum_absolute_effective_delta_rad_s := 0.0
	var maximum_host_command_quantization_error_rad_s := 0.0
	for application in pending_applications:
		var requested_delta_rad_s := float(application["requested_delta_rad_s"])
		var effective_delta_rad_s := float(application["effective_delta_rad_s"])
		maximum_absolute_requested_delta_rad_s = maxf(
			maximum_absolute_requested_delta_rad_s,
			absf(requested_delta_rad_s),
		)
		maximum_absolute_effective_delta_rad_s = maxf(
			maximum_absolute_effective_delta_rad_s,
			absf(effective_delta_rad_s),
		)
		maximum_host_command_quantization_error_rad_s = maxf(
			maximum_host_command_quantization_error_rad_s,
			float(application["host_command_quantization_error_rad_s"]),
		)
		if absf(effective_delta_rad_s) > 0.0:
			nonzero_effective_application_count += 1
		if bool(application["host_saturated"]):
			host_saturation_count += 1
	_stability_overlay_application_step_count += 1
	_stability_overlay_motor_write_count += pending_applications.size()
	if portable_base_enabled:
		_portable_controller_base_application_count += pending_applications.size()
	_stability_overlay_nonzero_effective_application_count += (
		nonzero_effective_application_count
	)
	_stability_overlay_host_saturation_count += host_saturation_count
	_stability_overlay_maximum_absolute_requested_delta_rad_s = maxf(
		_stability_overlay_maximum_absolute_requested_delta_rad_s,
		maximum_absolute_requested_delta_rad_s,
	)
	_stability_overlay_maximum_absolute_effective_delta_rad_s = maxf(
		_stability_overlay_maximum_absolute_effective_delta_rad_s,
		maximum_absolute_effective_delta_rad_s,
	)
	_stability_overlay_maximum_readback_error_rad_s = maxf(
		_stability_overlay_maximum_readback_error_rad_s,
		maximum_readback_error_rad_s,
	)
	_stability_overlay_maximum_host_command_quantization_error_rad_s = maxf(
		_stability_overlay_maximum_host_command_quantization_error_rad_s,
		maximum_host_command_quantization_error_rad_s,
	)
	_native_actuation_application_count += pending_applications.size()
	return {
		"schema_version": "sporespore_godot_jolt_stability_overlay_receipt_v1",
		"ok": true,
		"failure_code": "",
		"semantic_step": int(step_result.get("semantic_step", -1)),
		"policy_id": _stability_policy_id,
		"runtime_id": P5I3C_OVERLAY_RUNTIME_ID,
		"memory_id": P5I3C_OVERLAY_MEMORY_ID,
		"base_command_source":
		(
			"portable_controller_ordered_commands"
			if portable_base_enabled
			else "legacy_host_command_context"
		),
		"applied_command_count": pending_applications.size(),
		"nonzero_effective_application_count":
		nonzero_effective_application_count,
		"host_saturation_count": host_saturation_count,
		"maximum_absolute_requested_delta_rad_s":
		maximum_absolute_requested_delta_rad_s,
		"maximum_absolute_effective_delta_rad_s":
		maximum_absolute_effective_delta_rad_s,
		"maximum_readback_error_rad_s": maximum_readback_error_rad_s,
		"maximum_host_command_quantization_error_rad_s":
		maximum_host_command_quantization_error_rad_s,
		"readback_tolerance_rad_s": P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S,
		"host_command_quantization_tolerance_rad_s":
		P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S,
		"ordered_applications": pending_applications.duplicate(true),
		"whole_step_base_restored": false,
		"motor_target_velocity_only": true,
		"direct_body_write_count": 0,
		"actuation_authority": true,
		"physical_influence": true,
		"physical_balance_recovery": false,
		"locomotion_robustness": false,
		"physical_acceptance_authority": false,
	}


func _record_r23d2_oracle_trace(
	sample_result: Dictionary,
	controller_receipt: Dictionary,
	controller_receipt_sha256: String,
	semantic_step: int,
) -> String:
	if not _r23d2_oracle_trace_enabled:
		return ""
	var request: Dictionary = sample_result.get("request", {})
	var state: Dictionary = request.get("state", {})
	var command: Dictionary = request.get("command", {})
	var base_pose: Dictionary = state.get("base_pose_world", {})
	var base_twist: Dictionary = state.get("base_twist_world", {})
	var task_frame: Dictionary = state.get("task_frame", {})
	var controller_projection: Dictionary = {}
	for field_value in R23D2_ORACLE_RECEIPT_FIELDS:
		var field := String(field_value)
		controller_projection[field] = controller_receipt.get(field, null)
	_r23d2_oracle_trace.append(
		{
			"schema_version": "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_row_v1",
			"semantic_step": semantic_step,
			"state_frame_sha256": CanonicalJsonScript.sha256(state),
			"motion_command_sha256": CanonicalJsonScript.sha256(command),
			"controller_receipt_sha256": controller_receipt_sha256,
			"controller_profile_sha256": _controller_profile_sha256,
			"oracle_state_projection":
			{
				"base_position_world_m":
				(base_pose.get("position_m", {}) as Dictionary).duplicate(true),
				"base_orientation_xyzw":
				(base_pose.get("orientation_xyzw", {}) as Dictionary).duplicate(true),
				"base_linear_velocity_world_m_s":
				(
					(base_twist.get("linear_velocity_m_s", {}) as Dictionary)
					. duplicate(true)
				),
				"task_origin_world_m":
				(task_frame.get("origin_world_m", {}) as Dictionary).duplicate(true),
				"task_lateral_axis_world_unit":
				(
					(task_frame.get("lateral_axis_world_unit", {}) as Dictionary)
					. duplicate(true)
				),
				"reference_yaw_rad": task_frame.get("reference_yaw_rad", null),
			},
			"oracle_command_projection":
			{
				"desired_heading_rad": command.get("desired_heading_rad", null),
			},
			"controller_receipt_projection": controller_projection,
			"physical_acceptance_authority": false,
		}
	)
	return ""


func summary() -> Dictionary:
	var expected_native_application_count := 0
	if _actuation_authority_enabled:
		expected_native_application_count = (
			_step_count
			* int(
				(
					(_compiled.get("morphology", {}) as Dictionary)
					. get("ordered_actuator_ids", [])
				).size()
			)
		)
	var stability_overlay_runtime_ok := (
		_uses_stability_contribution_actuation()
		and _started
		and _start_failure_code.is_empty()
		and _step_count > 0
		and _safe_no_actuation_count == 0
		and _native_safe_disable_application_count == 0
		and _stability_overlay_application_step_count == _step_count
		and _stability_overlay_motor_write_count == _step_count * 8
		and (
			(
				_is_balanced_wave_policy(_controller_policy_id)
				and _portable_controller_base_application_count
				== _step_count * 8
			)
			or (
				not _is_balanced_wave_policy(_controller_policy_id)
				and _portable_controller_base_application_count == 0
			)
		)
		and _native_actuation_application_count == expected_native_application_count
		and _stability_overlay_failure_count == 0
		and _contribution_mismatch_count == 0
		and _contribution_limiter_mismatch_count == 0
		and _contribution_inactive_zero_mismatch_count == 0
		and _contribution_profile_conversion_failure_count == 0
		and _stability_overlay_maximum_readback_error_rad_s
		<= P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S
		and _stability_overlay_maximum_host_command_quantization_error_rad_s
		<= P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S
	)
	return {
		"schema_version": EXECUTION_SUMMARY_SCHEMA_VERSION,
		"ok": (
			_started
			and _start_failure_code.is_empty()
			and _step_count > 0
			and _mismatch_count == 0
			and _safe_no_actuation_count == 0
			and _native_safe_disable_application_count == 0
			and _native_actuation_application_count == expected_native_application_count
			and _stability_overlay_failure_count == 0
			and (
				not _uses_stability_contribution_actuation()
				or (
					_stability_overlay_application_step_count == _step_count
					and _stability_overlay_motor_write_count == _step_count * 8
				)
			)
			and (
				not _phase_offset_synchronization_scheduled
				or _phase_offset_application_count == 1
			)
		),
		"failure_code": _start_failure_code,
		"started": _started,
		"step_count": _step_count,
		"compared_actuator_command_count": _compared_actuator_command_count,
		"validated_balanced_wave_command_count":
		_validated_balanced_wave_command_count,
		"balanced_wave_step_receipt_count":
		_balanced_wave_step_receipt_count,
		"balanced_wave_command_validation_summary":
		{
			"schema_version":
			"sporespore_balanced_wave_command_validation_summary_v1",
			"enabled": _is_balanced_wave_policy(_controller_policy_id),
			"ok": (
				(
					_is_balanced_wave_policy(_controller_policy_id)
					and _balanced_wave_native_validation_step_count == _step_count
					and (
						_balanced_wave_heading_conditioned_step_count
						+ _balanced_wave_unconditioned_step_count
					) == _step_count
				)
				or (
					not _is_balanced_wave_policy(_controller_policy_id)
					and _balanced_wave_native_validation_step_count == 0
					and _balanced_wave_heading_conditioned_step_count == 0
					and _balanced_wave_unconditioned_step_count == 0
				)
			),
			"validation_mode": BALANCED_WAVE_COMMAND_VALIDATION_MODE,
			"native_validation_step_count":
			_balanced_wave_native_validation_step_count,
			"heading_command_conditioned_step_count":
			_balanced_wave_heading_conditioned_step_count,
			"unconditioned_step_count": _balanced_wave_unconditioned_step_count,
			"legacy_command_parity_applicable": false,
			"legacy_command_parity_checked_step_count": 0,
			"legacy_command_parity_waived_step_count": 0,
			"legacy_command_parity_not_applicable_reason":
			"balanced_wave_routes_to_native_validator_before_candidate35_parity",
			"physical_acceptance_authority": false,
		},
		"balanced_wave_first_step_receipt_sha256":
		_balanced_wave_first_step_receipt_sha256,
		"balanced_wave_last_step_receipt_sha256":
		_balanced_wave_last_step_receipt_sha256,
		"r23d2_oracle_trace":
		{
			"schema_version": "sporespore_qsdk_r23d2_godot_jolt_oracle_trace_v1",
			"enabled": _r23d2_oracle_trace_enabled,
			"controller_profile_sha256": _controller_profile_sha256,
			"step_count": _r23d2_oracle_trace.size(),
			"rows": _r23d2_oracle_trace.duplicate(true),
			"physical_acceptance_authority": false,
		},
		"release_gate_unweighting_summary":
		{
			"schema_version":
			"sporespore_release_gate_unweighting_execution_summary_v1",
			"enabled": _is_bw8u_policy(_controller_policy_id),
			"receipt_count": _release_gate_unweighting_receipt_count,
			"knee_override_step_count": _release_gate_knee_override_step_count,
			"hip_override_step_count": _release_gate_hip_override_step_count,
			"knee_override_limb_count": _release_gate_knee_override_limb_count,
			"hip_override_limb_count": _release_gate_hip_override_limb_count,
			"analytic_target_basis":
			"existing_lateral_wave_swing_apex_at_half_swing_v1",
			"morphology_branch_surface_count": 0,
			"controller_parameter": true,
			"walking_claim_authorized": false,
			"physical_acceptance_authority": false,
		},
		"forward_velocity_foot_placement_summary":
		{
			"schema_version":
			"sporespore_forward_velocity_foot_placement_execution_summary_v1",
			"enabled": _is_forward_velocity_foot_placement_policy(_controller_policy_id),
			"mode_id":
			(
				FORWARD_VELOCITY_FOOT_PLACEMENT_MODE_ID
				if _is_forward_velocity_foot_placement_policy(_controller_policy_id)
				else ""
			),
			"velocity_error_orientation_id":
			(
				String(_controller_profile.get(
					"forward_velocity_error_orientation_id",
					"",
				))
				if _is_signed_forward_velocity_policy(_controller_policy_id)
				else ""
			),
			"receipt_count": _forward_velocity_foot_placement_receipt_count,
			"maximum_absolute_normalized_forward_velocity_error":
			_maximum_absolute_normalized_forward_velocity_error,
			"maximum_absolute_hip_target_correction_rad":
			_maximum_absolute_forward_velocity_hip_target_correction_rad,
			"maximum_declared_hip_target_correction_rad":
			(
				float(_controller_profile.get(
					"maximum_forward_velocity_hip_target_correction_rad",
					0.0,
				))
				if _is_forward_velocity_foot_placement_policy(_controller_policy_id)
				else 0.0
			),
			"morphology_branch_surface_count": 0,
			"controller_parameter": true,
			"walking_claim_authorized": false,
			"physical_acceptance_authority": false,
		},
		"scheduled_load_transfer_summary":
		{
			"schema_version":
			"sporespore_scheduled_load_transfer_execution_summary_v1",
			"enabled":
			_is_scheduled_load_transfer_policy(_stability_policy_id),
			"policy_id": _stability_policy_id,
			"portable_plan_operation":
			_scheduled_load_transfer_plan_operation(_stability_policy_id),
			"receipt_schema_version":
			_scheduled_load_transfer_receipt_schema_version(
				_stability_policy_id
			),
			"receipt_count": _scheduled_load_transfer_receipt_count,
			"active_step_count":
			_scheduled_load_transfer_active_step_count,
			"unweighted_contact_count":
			_scheduled_load_transfer_unweighted_contact_count,
			"preferred_normal_step_count":
			_scheduled_load_transfer_preferred_normal_step_count,
			"remaining_centroid_step_count":
			_scheduled_load_transfer_remaining_centroid_step_count,
			"available_receipt_count":
			_scheduled_load_transfer_available_receipt_count,
			"observation_unavailable_receipt_count":
			_scheduled_load_transfer_unavailable_receipt_count,
			"upstream_infeasible_receipt_count":
			_scheduled_load_transfer_upstream_infeasible_receipt_count,
			"fail_zero_receipt_count":
			_scheduled_load_transfer_fail_zero_receipt_count,
			"first_receipt_sha256":
			_scheduled_load_transfer_first_receipt_sha256,
			"last_receipt_sha256":
			_scheduled_load_transfer_last_receipt_sha256,
			"activation_uses_scheduler_boundaries_only": true,
			"morphology_branch_surface_count": 0,
			"per_foot_measured_load_allocation_available": false,
			"walking_claim_authorized": false,
			"physical_acceptance_authority": false,
		},
		"steering_feedback_update_count": _steering_feedback_update_count,
		"steering_filter_application_count": _steering_filter_application_count,
		"steering_saturation_count": _steering_saturation_count,
		"steering_slew_limited_count": _steering_slew_limited_count,
		"maximum_absolute_requested_steering_fraction":
		_maximum_absolute_requested_steering_fraction,
		"maximum_absolute_filtered_steering_fraction":
		_maximum_absolute_filtered_steering_fraction,
		"maximum_absolute_steering_delta_per_step":
		_maximum_absolute_steering_delta_per_step,
		"cumulative_absolute_cross_track_error_m_steps":
		_cumulative_absolute_cross_track_error_m_steps,
		"cumulative_absolute_cross_track_error_m_s":
		(
			_cumulative_absolute_cross_track_error_m_steps / float(_physics_hz)
			if _physics_hz > 0
			else INF
		),
		"minimum_cross_track_error_m":
		(_minimum_cross_track_error_m if _step_count > 0 else 0.0),
		"maximum_cross_track_error_m":
		(_maximum_cross_track_error_m if _step_count > 0 else 0.0),
		"mismatch_count": _mismatch_count,
		"candidate35_shadow_parity_ok":
		(
			_controller_policy_id == CANDIDATE35_POLICY_ID
			and _mismatch_count == 0
		),
		"balanced_wave_shadow_valid":
		(
			_is_balanced_wave_policy(_controller_policy_id)
			and _mismatch_count == 0
			and _validated_balanced_wave_command_count == _step_count * 8
			and _balanced_wave_step_receipt_count == _step_count
			and _balanced_wave_native_validation_step_count == _step_count
		),
		"controller_policy_id": _controller_policy_id,
		"controller_runtime_version": _controller_runtime_version,
		"controller_profile_sha256": _controller_profile_sha256,
		"stability_overlay_runtime_ok": stability_overlay_runtime_ok,
		"safe_no_actuation_count": _safe_no_actuation_count,
		"native_actuation_application_count": _native_actuation_application_count,
		"native_safe_disable_application_count": _native_safe_disable_application_count,
		"actuation_authority": _actuation_authority_enabled,
		"authority_scope": _authority_scope,
		"stability_policy_id": _stability_policy_id,
		"stability_influence_global_scale":
		_stability_influence_global_scale,
		"stability_contribution_shadow_only_until_terminal":
		_stability_contribution_shadow_only_until_terminal,
		"external_terminal_application_step_count":
		_external_terminal_application_step_count,
		"external_terminal_motor_write_count":
		_external_terminal_motor_write_count,
		"stability_influence_scale_authority":
		(
			"portable_core_v3"
			if _stability_influence_scale_enabled
			else "legacy_v2_unscaled"
		),
		"maximum_absolute_target_position_error_rad":
		_maximum_absolute_target_position_error_rad,
		"maximum_absolute_target_velocity_error_rad_s":
		_maximum_absolute_target_velocity_error_rad_s,
		"maximum_absolute_speed_limit_error_rad_s":
		_maximum_absolute_speed_limit_error_rad_s,
		"maximum_absolute_phase_error_steps": _maximum_absolute_phase_error_steps,
		"maximum_absolute_steering_error": _maximum_absolute_steering_error,
		"comparison_tolerance": _tolerance,
		"failure_codes": _failure_codes.duplicate(),
		"failure_details": _failure_details.duplicate(true),
		"first_phase_mismatch_detail": _first_phase_mismatch_detail.duplicate(true),
		"first_large_command_mismatch_detail":
		_first_large_command_mismatch_detail.duplicate(true),
		"adapter_manifest": _adapter_manifest.duplicate(true),
		"adapter_capability_sha256": _adapter_capability_sha256,
		"compiled_morphology_spec_sha256": String(
			(_compiled.get("morphology", {}) as Dictionary).get("morphology_spec_sha256", "")
		),
		"phase_offset_synchronization_receipt": _phase_offset_synchronization_receipt(),
		"stability_shadow_summary":
		{
			"schema_version": STABILITY_SHADOW_SUMMARY_VERSION,
			"ok":
			(
				_stability_shadow_attempt_count > 0
				and _stability_shadow_mismatch_count == 0
			),
			"attempt_count": _stability_shadow_attempt_count,
			"available_count": _stability_shadow_available_count,
			"unavailable_count": _stability_shadow_unavailable_count,
			"mismatch_count": _stability_shadow_mismatch_count,
			"failure_codes": _stability_shadow_failure_codes.duplicate(),
			"maximum_absolute_error_by_field":
			_stability_shadow_maximum_error_by_field.duplicate(true),
			"comparison_absolute_tolerance": STABILITY_SHADOW_ABSOLUTE_TOLERANCE,
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_balance_recovery": false,
			"physical_acceptance_authority": false,
		},
		"joint_mapping_shadow_summary":
		{
			"schema_version": MAPPING_SHADOW_SUMMARY_VERSION,
			"ok":
			(
				_mapping_shadow_attempt_count > 0
				and _mapping_shadow_available_count > 0
				and _mapping_shadow_mismatch_count == 0
				and _mapping_shadow_compared_actuator_count
				== _mapping_shadow_available_count * 8
				and _mapping_shadow_maximum_absolute_commanded_torque_nm
				> JOINT_MAPPING_NONZERO_TORQUE_NM
			),
			"attempt_count": _mapping_shadow_attempt_count,
			"available_count": _mapping_shadow_available_count,
			"unavailable_count": _mapping_shadow_unavailable_count,
			"infeasible_count": _mapping_shadow_infeasible_count,
			"mismatch_count": _mapping_shadow_mismatch_count,
			"compared_actuator_count": _mapping_shadow_compared_actuator_count,
			"maximum_absolute_torque_error_nm":
			_mapping_shadow_maximum_absolute_torque_error_nm,
			"maximum_absolute_commanded_torque_nm":
			_mapping_shadow_maximum_absolute_commanded_torque_nm,
			"comparison_absolute_tolerance_nm":
			JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM,
			"nonzero_torque_threshold_nm": JOINT_MAPPING_NONZERO_TORQUE_NM,
			"outcome_codes": _mapping_shadow_outcome_codes.duplicate(),
			"failure_codes": _mapping_shadow_failure_codes.duplicate(),
			"controller_friction_coefficient":
			_characterized_controller_friction_coefficient,
			"actuator_response_characterized": false,
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_balance_recovery": false,
			"physical_acceptance_authority": false,
		},
		"stability_contribution_shadow_summary":
		{
			"schema_version": CONTRIBUTION_SHADOW_SUMMARY_VERSION,
			"ok":
			(
				_contribution_attempt_count > 0
				and _contribution_mismatch_count == 0
				and _contribution_limiter_mismatch_count == 0
				and _contribution_inactive_zero_mismatch_count == 0
				and _contribution_profile_input_clamped_count > 0
				and _contribution_profile_conversion_failure_count == 0
			),
			"attempt_count": _contribution_attempt_count,
			"full_support_attempt_count":
			_contribution_full_support_attempt_count,
			"partial_support_attempt_count":
			_contribution_partial_support_attempt_count,
			"available_count": _contribution_available_count,
			"upstream_infeasible_count":
			_contribution_upstream_infeasible_count,
			"unavailable_count": _contribution_unavailable_count,
			"untyped_count": _contribution_untyped_count,
			"ordered_v3_command_count":
			_contribution_ordered_command_count,
			"active_support_command_count":
			_contribution_active_command_count,
			"inactive_contact_command_count":
			_contribution_inactive_command_count,
			"influence_output_count": _contribution_influence_output_count,
			"fallback_zero_output_count":
			_contribution_fallback_zero_output_count,
			"inactive_hard_zero_transition_count":
			_contribution_inactive_hard_zero_transition_count,
			"profile_input_clamped_count":
			_contribution_profile_input_clamped_count,
			"profile_conversion_failure_count":
			_contribution_profile_conversion_failure_count,
			"feedback_nonzero_attempt_count":
			_contribution_feedback_nonzero_attempt_count,
			"nonzero_active_command_count":
			_contribution_nonzero_active_command_count,
			"slew_limited_output_count":
			_contribution_slew_limited_output_count,
			"magnitude_saturated_output_count":
			_contribution_magnitude_saturated_output_count,
			"full_v3_v2_compared_actuator_count":
			_contribution_full_v3_v2_compared_count,
			"limiter_mismatch_count":
			_contribution_limiter_mismatch_count,
			"inactive_zero_mismatch_count":
			_contribution_inactive_zero_mismatch_count,
			"mismatch_count": _contribution_mismatch_count,
			"failure_codes": _contribution_failure_codes.duplicate(),
			"maximum_full_v3_v2_torque_error_nm":
			_contribution_maximum_full_v3_v2_torque_error_nm,
			"maximum_active_oracle_torque_error_nm":
			_contribution_maximum_active_oracle_torque_error_nm,
			"maximum_absolute_commanded_torque_nm":
			_contribution_maximum_absolute_commanded_torque_nm,
			"maximum_absolute_profile_input_torque_nm":
			_contribution_maximum_absolute_profile_input_torque_nm,
			"maximum_absolute_proposed_velocity_rad_s":
			_contribution_maximum_absolute_proposed_velocity_rad_s,
			"maximum_absolute_applied_velocity_rad_s":
			_contribution_maximum_absolute_applied_velocity_rad_s,
			"maximum_absolute_host_delta_rad_s":
			_contribution_maximum_absolute_host_delta_rad_s,
			"maximum_limiter_reconstruction_error":
			_contribution_maximum_limiter_reconstruction_error,
			"mapping_comparison_absolute_tolerance_nm":
			JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM,
			"limiter_reconstruction_tolerance":
			CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE,
			"maximum_characterized_generalized_torque_nm":
			CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM,
			"maximum_characterized_proposed_velocity_rad_s":
			CHARACTERIZED_MAXIMUM_VELOCITY_DELTA_RAD_S,
			"maximum_absolute_velocity_delta_rad_s":
			CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
			"maximum_velocity_delta_slew_per_step_rad_s":
			CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
			"influence_operation":
			(
				"bound_stability_influence_v3_json"
				if _stability_influence_scale_enabled
				else "bound_stability_influence_v2_json"
			),
			"global_requested_correction_scale":
			_stability_influence_global_scale,
			"global_scale_applied_before_magnitude_and_slew":
			_stability_influence_scale_enabled,
			"velocity_per_torque_rad_s_per_nm":
			CHARACTERIZED_VELOCITY_PER_TORQUE_RAD_S_PER_NM,
			"host_target_velocity_sign_per_canonical_positive":
			CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE,
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_balance_recovery": false,
			"locomotion_robustness": false,
			"cross_engine_portable": false,
			"physical_acceptance_authority": false,
			"completed_sdk": false,
		},
		"stability_overlay_summary":
		{
			"schema_version":
			"sporespore_godot_jolt_stability_overlay_summary_v1",
			"ok":
			(
				(
					_uses_stability_contribution_actuation()
					and _stability_overlay_application_step_count == _step_count
					and _stability_overlay_motor_write_count == _step_count * 8
					and (
						(
							_is_balanced_wave_policy(_controller_policy_id)
							and _portable_controller_base_application_count
							== _step_count * 8
						)
						or (
							not _is_balanced_wave_policy(_controller_policy_id)
							and _portable_controller_base_application_count == 0
						)
					)
					and _stability_overlay_failure_count == 0
					and _stability_overlay_maximum_readback_error_rad_s
					<= P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S
					and _stability_overlay_maximum_host_command_quantization_error_rad_s
					<= P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S
				)
				or (
					not _uses_stability_contribution_actuation()
					and _stability_overlay_application_step_count == 0
					and _stability_overlay_motor_write_count == 0
					and _stability_overlay_failure_count == 0
				)
			),
			"policy_id": _stability_policy_id,
			"runtime_id": P5I3C_OVERLAY_RUNTIME_ID,
			"memory_id": P5I3C_OVERLAY_MEMORY_ID,
			"authority_scope": _authority_scope,
			"application_step_count":
			_stability_overlay_application_step_count,
			"motor_write_count": _stability_overlay_motor_write_count,
			"base_command_source":
			(
				"not_applied"
				if not _uses_stability_contribution_actuation()
				else (
					"portable_controller_ordered_commands"
					if _is_balanced_wave_policy(_controller_policy_id)
					else "legacy_host_command_context"
				)
			),
			"portable_controller_base_application_count":
			_portable_controller_base_application_count,
			"nonzero_effective_application_count":
			_stability_overlay_nonzero_effective_application_count,
			"host_saturation_count":
			_stability_overlay_host_saturation_count,
			"combined_speed_limit_violation_count":
			_stability_overlay_combined_speed_limit_violation_count,
			"failure_count": _stability_overlay_failure_count,
			"failure_codes": _stability_overlay_failure_codes.duplicate(),
			"maximum_absolute_requested_delta_rad_s":
			_stability_overlay_maximum_absolute_requested_delta_rad_s,
			"maximum_absolute_effective_delta_rad_s":
			_stability_overlay_maximum_absolute_effective_delta_rad_s,
			"maximum_readback_error_rad_s":
			_stability_overlay_maximum_readback_error_rad_s,
			"maximum_host_command_quantization_error_rad_s":
			_stability_overlay_maximum_host_command_quantization_error_rad_s,
			"readback_tolerance_rad_s":
			P5I3C_MOTOR_READBACK_TOLERANCE_RAD_S,
			"host_command_quantization_tolerance_rad_s":
			P5I3C_HOST_COMMAND_QUANTIZATION_TOLERANCE_RAD_S,
			"motor_target_velocity_only": true,
			"direct_body_write_count": 0,
			"physical_influence":
			_uses_stability_contribution_actuation()
			and _stability_overlay_motor_write_count > 0,
			"physical_balance_recovery": false,
			"locomotion_robustness": false,
			"physical_acceptance_authority": false,
			"completed_sdk": false,
		},
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


## Terminates the adapter's process-local native controller session after the
## caller has copied its final execution summary. Successful physical and
## zero-world routes call this explicitly so native session destruction occurs
## while Godot and the GDExtension are fully alive. The Rust Drop implementation
## remains a fail-safe for abandoned adapters, not the normal success path.
func shutdown() -> Dictionary:
	if _shutdown_completed:
		return _controller_session_shutdown_receipt.duplicate(true)
	if not _started:
		return _shutdown_failure("ADAPTER_SHUTDOWN_BEFORE_SUCCESSFUL_START")
	var native_receipt: Dictionary = {}
	var native_destroy_count := 0
	if _is_balanced_wave_policy(_controller_policy_id):
		if (
			_controller_session_receipt.is_empty()
			or _api == null
			or not _api.has_method("balanced_wave_policy_session_destroy_json")
		):
			return _shutdown_failure("ADAPTER_CONTROLLER_SESSION_SHUTDOWN_UNAVAILABLE")
		var envelope := _call_no_input(&"balanced_wave_policy_session_destroy_json")
		var receipt_value: Variant = envelope.get("value", null)
		if not bool(envelope.get("ok", false)) or typeof(receipt_value) != TYPE_DICTIONARY:
			return _shutdown_failure(
				"ADAPTER_CONTROLLER_SESSION_DESTROY_FAILED",
				String(envelope.get("failure_code", "INVALID_NATIVE_SHUTDOWN_RECEIPT")),
			)
		native_receipt = (receipt_value as Dictionary).duplicate(true)
		if (
			String(native_receipt.get("schema_version", ""))
			!= "sporespore_godot_balanced_wave_policy_session_receipt_v1"
			or String(native_receipt.get("execution_version", ""))
			!= CONTROLLER_SESSION_EXECUTION_VERSION
			or bool(native_receipt.get("active", true))
			or int(native_receipt.get("world_build_count", -1)) != 0
			or bool(native_receipt.get("physical_acceptance_authority", true))
		):
			return _shutdown_failure(
				"ADAPTER_CONTROLLER_SESSION_DESTROY_RECEIPT_INVALID",
				JSON.stringify(native_receipt),
			)
		native_destroy_count = 1
		_controller_session_receipt.clear()
	_controller_session_shutdown_receipt = {
		"schema_version": "sporespore_godot_jolt_adapter_shutdown_receipt_v1",
		"ok": true,
		"failure_code": "",
		"controller_policy_id": _controller_policy_id,
		"native_controller_session_required": _is_balanced_wave_policy(_controller_policy_id),
		"native_controller_session_destroy_count": native_destroy_count,
		"native_controller_session_receipt": native_receipt,
		"explicit_shutdown_completed": true,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	_shutdown_completed = true
	return _controller_session_shutdown_receipt.duplicate(true)


func _shutdown_failure(code: String, detail: String = "") -> Dictionary:
	_record_failure(code if detail.is_empty() else "%s:%s" % [code, detail])
	return {
		"schema_version": "sporespore_godot_jolt_adapter_shutdown_receipt_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"controller_policy_id": _controller_policy_id,
		"native_controller_session_required": _is_balanced_wave_policy(_controller_policy_id),
		"native_controller_session_destroy_count": 0,
		"native_controller_session_receipt": {},
		"explicit_shutdown_completed": false,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _observation_fault_signal(
	semantic_step: int,
	channel_index: int,
	period_steps: int,
) -> float:
	var phase_step := posmod(semantic_step + channel_index * 17, period_steps)
	return sin(TAU * float(phase_step) / float(period_steps))


static func _faulted_vector_dictionary(
	source: Dictionary,
	semantic_step: int,
	first_channel_index: int,
	period_steps: int,
	amplitude: float,
) -> Dictionary:
	return {
		"x":
		float(source["x"])
		+ amplitude
		* _observation_fault_signal(semantic_step, first_channel_index, period_steps),
		"y":
		float(source["y"])
		+ amplitude
		* _observation_fault_signal(semantic_step, first_channel_index + 1, period_steps),
		"z":
		float(source["z"])
		+ amplitude
		* _observation_fault_signal(semantic_step, first_channel_index + 2, period_steps),
	}


static func _apply_observation_fault_to_step_request(
	sample_result: Dictionary,
	semantic_step: int,
	options: Dictionary,
) -> Dictionary:
	var profile_id := String(options.get("observation_fault_profile_id", "none"))
	if profile_id == "none":
		return {
			"ok": true,
			"failure_code": "",
			"sample_result": sample_result,
			"fault_applied": false,
			"maximum_absolute_applied_component": 0.0,
		}
	if profile_id != "deterministic_additive_v1":
		return {
			"ok": false,
			"failure_code": "ADAPTER_UNKNOWN_OBSERVATION_FAULT_PROFILE",
		}
	var period_steps := int(options.get("observation_noise_period_steps", 0))
	if period_steps < 8:
		return {
			"ok": false,
			"failure_code": "ADAPTER_OBSERVATION_FAULT_PERIOD_INVALID",
		}
	var base_position_amplitude := float(
		options.get("base_position_noise_amplitude_m", NAN)
	)
	var base_velocity_amplitude := float(
		options.get("base_linear_velocity_noise_amplitude_m_s", NAN)
	)
	var joint_position_amplitude := float(
		options.get("joint_position_noise_amplitude_rad", NAN)
	)
	var joint_velocity_amplitude := float(
		options.get("joint_velocity_noise_amplitude_rad_s", NAN)
	)
	if (
		not is_finite(base_position_amplitude)
		or not is_finite(base_velocity_amplitude)
		or not is_finite(joint_position_amplitude)
		or not is_finite(joint_velocity_amplitude)
	):
		return {
			"ok": false,
			"failure_code": "ADAPTER_OBSERVATION_FAULT_AMPLITUDE_INVALID",
		}
	var faulted := sample_result.duplicate(true)
	var request: Dictionary = faulted.get("request", {})
	var state: Dictionary = request.get("state", {})
	var base_pose: Dictionary = state.get("base_pose_world", {})
	var base_twist: Dictionary = state.get("base_twist_world", {})
	base_pose["position_m"] = _faulted_vector_dictionary(
		base_pose.get("position_m", {}),
		semantic_step,
		1,
		period_steps,
		base_position_amplitude,
	)
	base_twist["linear_velocity_m_s"] = _faulted_vector_dictionary(
		base_twist.get("linear_velocity_m_s", {}),
		semantic_step,
		4,
		period_steps,
		base_velocity_amplitude,
	)
	state["base_pose_world"] = base_pose
	state["base_twist_world"] = base_twist
	var joints: Array = state.get("ordered_joint_observations", [])
	for joint_index in range(joints.size()):
		var joint: Dictionary = joints[joint_index]
		joint["position_rad"] = (
			float(joint["position_rad"])
			+ joint_position_amplitude
			* _observation_fault_signal(
				semantic_step,
				10 + joint_index * 2,
				period_steps,
			)
		)
		joint["velocity_rad_s"] = (
			float(joint["velocity_rad_s"])
			+ joint_velocity_amplitude
			* _observation_fault_signal(
				semantic_step,
				11 + joint_index * 2,
				period_steps,
			)
		)
	state["ordered_joint_observations"] = joints
	request["state"] = state
	faulted["request"] = request
	return {
		"ok": true,
		"failure_code": "",
		"sample_result": faulted,
		"fault_applied": true,
		"maximum_absolute_applied_component":
		maxf(
			maxf(base_position_amplitude, base_velocity_amplitude),
			maxf(joint_position_amplitude, joint_velocity_amplitude),
		),
	}


static func _apply_observation_fault_to_stability_state(
	stability_state: Dictionary,
	support_point_by_contact_id: Dictionary,
	semantic_step: int,
	options: Dictionary,
) -> Dictionary:
	var profile_id := String(options.get("observation_fault_profile_id", "none"))
	if profile_id == "none":
		return {
			"ok": true,
			"failure_code": "",
			"stability_state": stability_state,
			"support_point_by_contact_id": support_point_by_contact_id,
			"fault_applied": false,
			"maximum_absolute_applied_component": 0.0,
		}
	if profile_id != "deterministic_additive_v1":
		return {
			"ok": false,
			"failure_code": "STABILITY_UNKNOWN_OBSERVATION_FAULT_PROFILE",
		}
	var period_steps := int(options.get("observation_noise_period_steps", 0))
	var position_amplitude := float(
		options.get("stability_body_position_noise_amplitude_m", NAN)
	)
	var velocity_amplitude := float(
		options.get("stability_body_velocity_noise_amplitude_m_s", NAN)
	)
	var support_amplitude := float(options.get("support_point_noise_amplitude_m", NAN))
	if (
		period_steps < 8
		or not is_finite(position_amplitude)
		or not is_finite(velocity_amplitude)
		or not is_finite(support_amplitude)
	):
		return {
			"ok": false,
			"failure_code": "STABILITY_OBSERVATION_FAULT_OPTIONS_INVALID",
		}
	var faulted_state := stability_state.duplicate(true)
	var body_states: Array = faulted_state.get("ordered_body_states", [])
	for body_index in range(body_states.size()):
		var body_state: Dictionary = body_states[body_index]
		var pose: Dictionary = body_state.get("pose_world", {})
		var twist: Dictionary = body_state.get("twist_world", {})
		pose["position_m"] = _faulted_vector_dictionary(
			pose.get("position_m", {}),
			semantic_step,
			100 + body_index * 6,
			period_steps,
			position_amplitude,
		)
		twist["linear_velocity_m_s"] = _faulted_vector_dictionary(
			twist.get("linear_velocity_m_s", {}),
			semantic_step,
			103 + body_index * 6,
			period_steps,
			velocity_amplitude,
		)
		body_state["pose_world"] = pose
		body_state["twist_world"] = twist
	faulted_state["ordered_body_states"] = body_states
	var faulted_support_points := support_point_by_contact_id.duplicate(true)
	var contacts: Array = faulted_state.get("ordered_support_contacts", [])
	for contact_index in range(contacts.size()):
		var contact: Dictionary = contacts[contact_index]
		var contact_id := String(contact.get("contact_site_id", ""))
		if not faulted_support_points.has(contact_id):
			continue
		var point_value: Variant = faulted_support_points[contact_id]
		if typeof(point_value) != TYPE_VECTOR3:
			return {
				"ok": false,
				"failure_code": "STABILITY_OBSERVATION_FAULT_CONTACT_INVALID",
			}
		var point: Vector3 = point_value
		var point_dictionary := _faulted_vector_dictionary(
			{"x": point.x, "y": point.y, "z": point.z},
			semantic_step,
			300 + contact_index * 3,
			period_steps,
			support_amplitude,
		)
		var faulted_point := Vector3(
			float(point_dictionary["x"]),
			float(point_dictionary["y"]),
			float(point_dictionary["z"]),
		)
		faulted_support_points[contact_id] = faulted_point
		contact["point_world_m"] = point_dictionary
	faulted_state["ordered_support_contacts"] = contacts
	return {
		"ok": true,
		"failure_code": "",
		"stability_state": faulted_state,
		"support_point_by_contact_id": faulted_support_points,
		"fault_applied": true,
		"maximum_absolute_applied_component":
		maxf(position_amplitude, maxf(velocity_amplitude, support_amplitude)),
	}


func _sample_stability_shadow(
	semantic_step: int,
	torso: RigidBody3D,
	limbs: Array,
	floor: StaticBody3D,
	gait_amplitude: float,
	observation_fault_options: Dictionary = {},
) -> Dictionary:
	var morphology: Dictionary = _compiled.get("morphology", {})
	var body_by_id_result := _stability_body_by_id(torso, limbs)
	if not bool(body_by_id_result.get("ok", false)):
		return _stability_shadow_failure(
			String(body_by_id_result.get("failure_code", "STABILITY_BODY_MAPPING_FAILED"))
		)
	var body_by_id: Dictionary = body_by_id_result["body_by_id"]
	var ordered_body_states: Array = []
	for body_id_value in morphology.get("ordered_body_ids", []):
		var body_id := String(body_id_value)
		if not body_by_id.has(body_id):
			return _stability_shadow_failure("STABILITY_BODY_MAPPING_MISSING:%s" % body_id)
		var body: RigidBody3D = body_by_id[body_id]
		var orientation_result := _canonical_orientation_xyzw(body.global_basis)
		if not bool(orientation_result.get("ok", false)):
			return _stability_shadow_failure(
				"STABILITY_BODY_ORIENTATION_INVALID:%s" % body_id
			)
		var orientation: Dictionary = orientation_result["orientation_xyzw"]
		ordered_body_states.append(
			{
				"body_id": body_id,
				"pose_world":
				{
					"position_m": _vector(body.global_position),
					"orientation_xyzw":
					{
						"x": float(orientation["x"]),
						"y": float(orientation["y"]),
						"z": float(orientation["z"]),
						"w": float(orientation["w"]),
					},
				},
				"twist_world":
				{
					"linear_velocity_m_s": _vector(body.linear_velocity),
					"angular_velocity_rad_s": _vector(body.angular_velocity),
				},
			}
		)

	var limb_by_id: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		limb_by_id[String(limb.get("limb_id", ""))] = limb
	var ordered_support_contacts: Array = []
	var support_point_by_contact_id: Dictionary = {}
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		var limb_id := contact_id.trim_suffix("_foot")
		if not limb_by_id.has(limb_id):
			return _stability_shadow_failure(
				"STABILITY_CONTACT_MAPPING_MISSING:%s" % contact_id
			)
		var contact_limb: Dictionary = limb_by_id[limb_id]
		var contact_result := _stability_contact_state(
			contact_id,
			contact_limb,
			floor,
		)
		if not bool(contact_result.get("ok", false)):
			return _stability_shadow_failure(
				String(
					contact_result.get(
						"failure_code",
						"STABILITY_CONTACT_STATE_INVALID:%s" % contact_id,
					)
				)
			)
		ordered_support_contacts.append(contact_result["contact"])
		if bool(contact_result.get("qualified", false)):
			support_point_by_contact_id[contact_id] = contact_result["point_world_m"]

	var stability_state := {
		"schema_version": "sporespore_stability_state_v2",
		"semantic_step": semantic_step,
		"ordered_body_states": ordered_body_states,
		"ordered_support_contacts": ordered_support_contacts,
		"gravity_world_m_s2": _vector(
			Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		),
		"support_plane_forward_world_unit": _vector(_initial_forward_axis_world),
		"adapter_capability_sha256": _adapter_capability_sha256,
	}
	var stability_fault_result := _apply_observation_fault_to_stability_state(
		stability_state,
		support_point_by_contact_id,
		semantic_step,
		observation_fault_options,
	)
	if not bool(stability_fault_result.get("ok", false)):
		return _stability_shadow_failure(
			String(
				stability_fault_result.get(
					"failure_code",
					"STABILITY_OBSERVATION_FAULT_INVALID",
				)
			),
			stability_state,
		)
	stability_state = stability_fault_result["stability_state"]
	support_point_by_contact_id = stability_fault_result["support_point_by_contact_id"]
	var observation_fault_applied := bool(stability_fault_result["fault_applied"])
	var maximum_absolute_fault_component := float(
		stability_fault_result["maximum_absolute_applied_component"]
	)
	if support_point_by_contact_id.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"observation_available": false,
			"unavailable_reason": "NO_QUALIFIED_SUPPORT_CONTACT",
			"state_emitted": true,
			"stability_state": stability_state,
			"comparison_performed": false,
			"observation_fault_applied": observation_fault_applied,
			"maximum_absolute_fault_component": maximum_absolute_fault_component,
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_balance_recovery": false,
			"physical_acceptance_authority": false,
		}

	var envelope := _call_input(
		"observe_stability_v2_json",
		{
			"schema_version": "sporespore_observe_stability_request_v2",
			"descriptor": _descriptor,
			"state": stability_state,
		},
	)
	if not bool(envelope.get("ok", false)):
		return _stability_shadow_failure(
			"STABILITY_NATIVE_OBSERVER_FAILED:%s"
			% String(envelope.get("failure_code", "")),
			stability_state,
		)
	var native_observation: Dictionary = envelope["value"]
	var legacy_support_points: Array[Vector3] = []
	for contact_id in LEGACY_SUPPORT_CONTACT_ORDER:
		if support_point_by_contact_id.has(contact_id):
			legacy_support_points.append(support_point_by_contact_id[contact_id])
	var legacy_observation := {}
	if not observation_fault_applied:
		legacy_observation = DynamicSupportObserverScript.observe(
			body_by_id,
			legacy_support_points,
			float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)),
		)
		if not bool(legacy_observation.get("ok", false)):
			return _stability_shadow_failure(
				"STABILITY_GDSCRIPT_ORACLE_FAILED:%s"
				% String(legacy_observation.get("failure_code", "")),
				stability_state,
			)

	var absolute_error_by_field := {}
	if not observation_fault_applied:
		absolute_error_by_field = {
		"whole_system_mass_kg":
		absf(
			float(native_observation["whole_system_mass_kg"])
			- float(legacy_observation["whole_system_mass_kg"])
		),
		"center_of_mass_world_m":
		_dictionary_vector(native_observation["center_of_mass_world_m"]).distance_to(
			legacy_observation["center_of_mass_world_m"]
		),
		"center_of_mass_velocity_world_m_s":
		_dictionary_vector(
			native_observation["center_of_mass_velocity_world_m_s"]
		).distance_to(legacy_observation["center_of_mass_velocity_world_m_s"]),
		"support_plane_height_m":
		absf(
			float(native_observation["support_plane_height_m"])
			- float(legacy_observation["support_plane_height_m"])
		),
		"center_of_mass_height_above_support_m":
		absf(
			float(native_observation["center_of_mass_height_above_support_m"])
			- float(legacy_observation["center_of_mass_height_above_support_m"])
		),
		"linearized_natural_frequency_rad_s":
		absf(
			float(native_observation["linearized_natural_frequency_rad_s"])
			- float(legacy_observation["linearized_natural_frequency_rad_s"])
		),
		"linearized_capture_point_world_m":
		_dictionary_vector(
			native_observation["linearized_capture_point_world_m"]
		).distance_to(legacy_observation["linearized_capture_point_world_m"]),
		"support_centroid_world_m":
		_dictionary_vector(native_observation["support_centroid_world_m"]).distance_to(
			legacy_observation["support_centroid_world_m"]
		),
		"center_of_mass_margin_m":
		absf(
			float(native_observation["center_of_mass_margin_m"])
			- float(legacy_observation["center_of_mass_margin_m"])
		),
		"linearized_capture_margin_m":
		absf(
			float(native_observation["linearized_capture_margin_m"])
			- float(legacy_observation["linearized_capture_margin_m"])
		),
		"support_centroid_margin_m":
		absf(
			float(native_observation["support_centroid_margin_m"])
			- float(legacy_observation["support_centroid_margin_m"])
		),
		"minimum_dynamic_support_margin_m":
		absf(
			float(native_observation["minimum_dynamic_support_margin_m"])
			- float(legacy_observation["minimum_dynamic_support_margin_m"])
		),
		}
	var maximum_error := 0.0
	for error_value in absolute_error_by_field.values():
		maximum_error = maxf(maximum_error, float(error_value))
	var geometry_matches := (
		true
		if observation_fault_applied
		else (
			int(native_observation.get("support_geometry_dimension", -1))
			== int(legacy_observation.get("support_geometry_dimension", -2))
		)
	)
	var comparison_ok := (
		geometry_matches and maximum_error <= STABILITY_SHADOW_ABSOLUTE_TOLERANCE
	)
	var joint_mapping_shadow := _sample_joint_mapping_shadow(
		semantic_step,
		morphology,
		native_observation,
		stability_state,
		limbs,
		support_point_by_contact_id,
	)
	var contribution_shadow := _sample_stability_contribution_shadow(
		semantic_step,
		morphology,
		native_observation,
		stability_state,
		torso,
		limbs,
		support_point_by_contact_id,
		joint_mapping_shadow,
		gait_amplitude,
	)
	return {
		"ok": comparison_ok,
		"failure_code": "" if comparison_ok else "STABILITY_SHADOW_MISMATCH",
		"observation_available": true,
		"unavailable_reason": "",
		"state_emitted": true,
		"stability_state": stability_state,
		"comparison_performed": not observation_fault_applied,
		"absolute_error_by_field": absolute_error_by_field,
		"maximum_absolute_error": maximum_error,
		"comparison_absolute_tolerance": STABILITY_SHADOW_ABSOLUTE_TOLERANCE,
		"geometry_matches": geometry_matches,
		"native_observation": native_observation,
		"legacy_observation": legacy_observation,
		"observation_fault_applied": observation_fault_applied,
		"maximum_absolute_fault_component": maximum_absolute_fault_component,
		"joint_mapping_shadow": joint_mapping_shadow,
		"stability_contribution_shadow": contribution_shadow,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}


func _sample_joint_mapping_shadow(
	semantic_step: int,
	morphology: Dictionary,
	native_observation: Dictionary,
	stability_state: Dictionary,
	limbs: Array,
	support_point_by_contact_id: Dictionary,
) -> Dictionary:
	var qualified_contact_ids: Array[String] = []
	var support_contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		if not support_point_by_contact_id.has(contact_id):
			continue
		qualified_contact_ids.append(contact_id)
		support_contacts.append(
			{
				"contact_id": contact_id,
				"point_world_m": _vector(support_point_by_contact_id[contact_id]),
				"preferred_normal_force_n": 0.0,
			}
		)
	if support_contacts.size() < 3:
		return {
			"ok": true,
			# The mapping stage was sampled and produced a typed unavailable
			# result. Recording that completed sample keeps the per-step
			# partition auditable without pretending a centroidal solve ran.
			"attempted": true,
			"mapping_available": false,
			"infeasible": false,
			"outcome_code": "INELIGIBLE_SUPPORT_COUNT:%d" % support_contacts.size(),
			"failure_code": "",
			"qualified_contact_ids": qualified_contact_ids,
			"compared_actuator_count": 0,
			"mismatch_count": 0,
			"maximum_absolute_torque_error_nm": 0.0,
			"maximum_absolute_commanded_torque_nm": 0.0,
			"adapter_actuation_applied": false,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}

	var gravity := _dictionary_vector(stability_state["gravity_world_m_s2"])
	var whole_system_mass_kg := float(native_observation["whole_system_mass_kg"])
	var centroidal_request := {
		"schema_version": "sporespore_centroidal_support_request_v2",
		"semantic_step": semantic_step,
		"whole_system_mass_kg": whole_system_mass_kg,
		"gravity_world_m_s2": stability_state["gravity_world_m_s2"],
		"support_plane_forward_world_unit":
		stability_state["support_plane_forward_world_unit"],
		"center_of_mass_world_m": native_observation["center_of_mass_world_m"],
		"center_of_mass_velocity_world_m_s":
		native_observation["center_of_mass_velocity_world_m_s"],
		"target_center_of_mass_world_m":
		native_observation["center_of_mass_world_m"],
		"torso_roll_rad": 0.0,
		"torso_pitch_rad": 0.0,
		"torso_roll_rate_rad_s": 0.0,
		"torso_pitch_rate_rad_s": 0.0,
		"horizontal_position_gain_n_per_m": 0.0,
		"horizontal_velocity_gain_ns_per_m": 0.0,
		"vertical_position_gain_n_per_m": 0.0,
		"vertical_velocity_gain_ns_per_m": 0.0,
		"roll_position_gain_nm_per_rad": 0.0,
		"roll_velocity_gain_nm_s_per_rad": 0.0,
		"pitch_position_gain_nm_per_rad": 0.0,
		"pitch_velocity_gain_nm_s_per_rad": 0.0,
		"maximum_horizontal_force_n": 0.0,
		"maximum_vertical_correction_n": 0.0,
		"maximum_roll_pitch_moment_nm": 0.0,
		"declared_supported_weight_fraction": 1.0,
		"characterized_friction_coefficient":
		_characterized_controller_friction_coefficient,
		"minimum_normal_force_n": 0.0,
		"maximum_normal_force_n": whole_system_mass_kg * gravity.length(),
		"nominal_support_count": 4,
		"feasibility_tolerance": 1.0e-5,
		"support_contacts": support_contacts,
	}
	var command_envelope := _call_input(
		"command_centroidal_support_v2_json",
		centroidal_request,
	)
	if not bool(command_envelope.get("ok", false)):
		return _mapping_infeasible(
			_typed_envelope_code("CENTROIDAL_COMMAND", command_envelope),
			qualified_contact_ids,
		)
	var centroidal_command: Dictionary = command_envelope["value"]
	if not bool(centroidal_command.get("feasible", false)):
		return _mapping_infeasible(
			"CENTROIDAL_INFEASIBLE:%s"
			% ",".join(centroidal_command.get("infeasibility_reasons", [])),
			qualified_contact_ids,
		)

	var kinematics_result := _joint_mapping_kinematics(
		morphology,
		limbs,
		support_point_by_contact_id,
	)
	if not bool(kinematics_result.get("ok", false)):
		return _mapping_failure(
			String(
				kinematics_result.get(
					"failure_code",
					"JOINT_MAPPING_KINEMATICS_INVALID",
				)
			),
			qualified_contact_ids,
		)
	var ordered_kinematics: Array = kinematics_result["ordered_kinematics"]
	var map_envelope := _call_input(
		"map_endpoint_force_to_joint_v2_json",
		{
			"schema_version": "sporespore_map_endpoint_force_to_joint_request_v2",
			"descriptor": _descriptor,
			"request":
			{
				"schema_version": "sporespore_endpoint_force_joint_map_request_v2",
				"semantic_step": semantic_step,
				"centroidal_command": centroidal_command,
				"ordered_actuator_kinematics": ordered_kinematics,
			},
		},
	)
	if not bool(map_envelope.get("ok", false)):
		var expected_partial_support_unavailable := (
			qualified_contact_ids.size()
			< int(morphology.get("ordered_contact_site_ids", []).size())
			and String(map_envelope.get("failure_code", "")) == "REFERENCE_INVALID"
			and String(map_envelope.get("detail", "")).begins_with(
				"endpoint_force_contact_command:"
			)
		)
		if expected_partial_support_unavailable:
			return {
				"ok": true,
				"attempted": true,
				"mapping_available": false,
				"infeasible": false,
				"outcome_code":
				_typed_envelope_code("MAPPING_UNAVAILABLE", map_envelope),
				"qualified_contact_ids": qualified_contact_ids,
				"compared_actuator_count": 0,
				"adapter_actuation_applied": false,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
		return _mapping_failure(
			_typed_envelope_code("JOINT_MAPPING", map_envelope),
			qualified_contact_ids,
		)

	var receipt: Dictionary = map_envelope["value"]
	var nonclaims_exact := (
		bool(receipt.get("endpoint_force_map_available", false))
		and not bool(receipt.get("measured_joint_torque_available", true))
		and not bool(receipt.get("actuator_response_characterized", true))
		and not bool(receipt.get("adapter_actuation_applied", true))
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)
	var command_by_contact_id: Dictionary = {}
	for command_value in centroidal_command.get(
		"ordered_support_contact_commands",
		[],
	):
		var command: Dictionary = command_value
		command_by_contact_id[String(command.get("contact_id", ""))] = command
	var kinematics_by_actuator_id: Dictionary = {}
	for kinematics_value in ordered_kinematics:
		var kinematics: Dictionary = kinematics_value
		kinematics_by_actuator_id[String(kinematics["actuator_id"])] = kinematics

	var compared_actuator_count := 0
	var mismatch_count := 0
	var maximum_absolute_torque_error_nm := 0.0
	var maximum_absolute_commanded_torque_nm := 0.0
	for mapped_value in receipt.get(
		"ordered_generalized_joint_torque_commands",
		[],
	):
		var mapped: Dictionary = mapped_value
		var actuator_id := String(mapped.get("actuator_id", ""))
		var contact_id := String(mapped.get("contact_site_id", ""))
		if (
			not kinematics_by_actuator_id.has(actuator_id)
			or not command_by_contact_id.has(contact_id)
		):
			mismatch_count += 1
			continue
		var kinematics: Dictionary = kinematics_by_actuator_id[actuator_id]
		var command: Dictionary = command_by_contact_id[contact_id]
		var axis := _dictionary_vector(kinematics["joint_axis_world_unit"])
		var anchor := _dictionary_vector(kinematics["joint_anchor_world_m"])
		var endpoint := _dictionary_vector(kinematics["endpoint_world_m"])
		var force := _dictionary_vector(
			command["joint_task_force_delta_world_n"]
		)
		var independent_jacobian := axis.cross(endpoint - anchor)
		var independent_torque_nm := independent_jacobian.dot(force)
		var native_torque_nm := float(mapped["generalized_torque_command_nm"])
		var torque_error_nm := absf(native_torque_nm - independent_torque_nm)
		maximum_absolute_torque_error_nm = maxf(
			maximum_absolute_torque_error_nm,
			torque_error_nm,
		)
		maximum_absolute_commanded_torque_nm = maxf(
			maximum_absolute_commanded_torque_nm,
			absf(native_torque_nm),
		)
		compared_actuator_count += 1
		if torque_error_nm > JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM:
			mismatch_count += 1

	var expected_actuator_count := int(
		morphology.get("ordered_actuator_ids", []).size()
	)
	if compared_actuator_count != expected_actuator_count or not nonclaims_exact:
		mismatch_count += 1
	var comparison_ok := mismatch_count == 0
	return {
		"ok": comparison_ok,
		"attempted": true,
		"mapping_available": true,
		"infeasible": false,
		"outcome_code": "AVAILABLE" if comparison_ok else "MAPPING_SHADOW_MISMATCH",
		"failure_code": "" if comparison_ok else "MAPPING_SHADOW_MISMATCH",
		"qualified_contact_ids": qualified_contact_ids,
		"compared_actuator_count": compared_actuator_count,
		"mismatch_count": mismatch_count,
		"maximum_absolute_torque_error_nm": maximum_absolute_torque_error_nm,
		"maximum_absolute_commanded_torque_nm":
		maximum_absolute_commanded_torque_nm,
		"comparison_absolute_tolerance_nm":
		JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM,
		"centroidal_request": centroidal_request,
		"centroidal_command": centroidal_command,
		"mapping_receipt": receipt,
		"actuator_response_characterized": false,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}


func _scheduled_load_transfer_plan(
	semantic_step: int,
	morphology: Dictionary,
	stability_state: Dictionary,
	gait_amplitude: float,
	observation_available: bool = true,
	observation_unavailable_reason: String = "",
) -> Dictionary:
	if not _is_scheduled_load_transfer_policy(_stability_policy_id):
		return {
			"ok": false,
			"failure_code": "SCHEDULED_LOAD_TRANSFER_POLICY_NOT_REQUESTED",
		}
	var memory_by_limb_id: Dictionary = {}
	for memory_value in _memory.get("ordered_limb_memory", []):
		var limb_memory: Dictionary = memory_value
		memory_by_limb_id[String(limb_memory.get("limb_id", ""))] = limb_memory
	var ordered_limb_gait_steps: Array = []
	for limb_id_value in morphology.get("ordered_limb_ids", []):
		var limb_id := String(limb_id_value)
		if not memory_by_limb_id.has(limb_id):
			return {
				"ok": false,
				"failure_code":
				"SCHEDULED_LOAD_TRANSFER_MEMORY_LIMB_MISSING:%s" % limb_id,
			}
		var limb_memory: Dictionary = memory_by_limb_id[limb_id]
		ordered_limb_gait_steps.append(
			{
				"limb_id": limb_id,
				"gait_step": int(limb_memory.get("gait_step", -1)),
			}
		)
	var plan_v3 := _is_scheduled_load_transfer_v3_policy(
		_stability_policy_id
	)
	var gravity := _dictionary_vector(stability_state.get("gravity_world_m_s2", {}))
	if (
		plan_v3
		and not observation_available
		and (
			not gravity.is_finite()
			or gravity.length_squared() <= 1.0e-12
		)
	):
		gravity = (
			Vector3.DOWN
			* float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		)
	var whole_system_mass_kg := float(morphology.get("total_mass_kg", NAN))
	if (
		not is_finite(gait_amplitude)
		or gait_amplitude < 0.0
		or gait_amplitude > 1.0
		or not gravity.is_finite()
		or gravity.length_squared() <= 1.0e-12
		or not is_finite(whole_system_mass_kg)
		or whole_system_mass_kg <= 0.0
		or (
			plan_v3
			and observation_available
			and stability_state.is_empty()
		)
		or (
			plan_v3
			and not observation_available
			and observation_unavailable_reason.strip_edges().is_empty()
		)
	):
		return {
			"ok": false,
			"failure_code": "SCHEDULED_LOAD_TRANSFER_INPUT_INVALID",
		}
	var plan_v2 := _is_scheduled_load_transfer_v2_policy(
		_stability_policy_id
	)
	var request_schema_version := (
		(
			"sporespore_scheduled_load_transfer_request_v3"
			if plan_v3
			else "sporespore_scheduled_load_transfer_request_v2"
		)
		if plan_v3 or plan_v2
		else "sporespore_scheduled_load_transfer_request_v1"
	)
	var envelope_schema_version := (
		(
			"sporespore_plan_scheduled_load_transfer_request_v3"
			if plan_v3
			else "sporespore_plan_scheduled_load_transfer_request_v2"
		)
		if plan_v3 or plan_v2
		else "sporespore_plan_scheduled_load_transfer_request_v1"
	)
	var portable_request := {
		"schema_version": request_schema_version,
		"policy_id": _stability_policy_id,
		"gait_amplitude": gait_amplitude,
		"cycle_steps": GAIT_CYCLE_STEPS,
		"swing_steps": 72,
		"characterized_friction_coefficient":
		_characterized_controller_friction_coefficient,
		"maximum_normal_force_n":
		whole_system_mass_kg * gravity.length(),
		"feasibility_tolerance": 1.0e-5,
		"ordered_limb_gait_steps": ordered_limb_gait_steps,
		"stability_state": stability_state,
	}
	if plan_v3:
		portable_request["semantic_step"] = semantic_step
		portable_request["observation_available"] = observation_available
		portable_request["observation_unavailable_reason"] = (
			null
			if observation_available
			else observation_unavailable_reason.strip_edges()
		)
		portable_request["stability_state"] = (
			null if stability_state.is_empty() else stability_state
		)
	var envelope := _call_input(
		StringName(
			_scheduled_load_transfer_plan_operation(_stability_policy_id)
		),
		{
			"schema_version":
			envelope_schema_version,
			"descriptor": _descriptor,
			"request": portable_request,
		},
	)
	if not bool(envelope.get("ok", false)):
		return {
			"ok": false,
			"failure_code":
			_typed_envelope_code("SCHEDULED_LOAD_TRANSFER_PLAN", envelope),
		}
	var receipt: Dictionary = envelope.get("value", {})
	var centroidal_request_value: Variant = receipt.get(
		"centroidal_request",
		null,
	)
	var centroidal_command_value: Variant = receipt.get(
		"centroidal_command",
		null,
	)
	var plan_typed := plan_v2 or plan_v3
	var planning_availability := (
		String(receipt.get("planning_availability", ""))
		if plan_typed
		else "available"
	)
	var fail_zero_required := (
		bool(receipt.get("fail_zero_required", false))
		if plan_typed
		else false
	)
	var typed_availability_exact := true
	if plan_typed:
		typed_availability_exact = (
			[
				"available",
				"observation_unavailable",
				"upstream_infeasible",
			].has(planning_availability)
			and typeof(receipt.get("planning_outcome_code", null))
			== TYPE_STRING
			and typeof(receipt.get("fail_zero_required", null)) == TYPE_BOOL
			and typeof(receipt.get("ordered_safe_zero_actuator_ids", null))
			== TYPE_ARRAY
			and fail_zero_required
			== (planning_availability != "available")
			and (
				(
					planning_availability == "available"
					and typeof(centroidal_request_value) == TYPE_DICTIONARY
					and typeof(centroidal_command_value) == TYPE_DICTIONARY
					and (
						receipt.get(
							"ordered_safe_zero_actuator_ids",
							[],
						) as Array
					).is_empty()
				)
				or (
					planning_availability != "available"
					and (
						receipt.get(
							"ordered_safe_zero_actuator_ids",
							[],
						) as Array
					)
					== (morphology.get("ordered_actuator_ids", []) as Array)
				)
			)
		)
	if plan_v3:
		typed_availability_exact = (
			typed_availability_exact
			and bool(receipt.get("observation_input_available", false))
			== observation_available
			and (
				(
					observation_available
					and receipt.get("observation_unavailable_reason", null) == null
				)
				or (
					not observation_available
					and typeof(
						receipt.get(
							"observation_unavailable_reason",
							null,
						)
					)
					== TYPE_STRING
					and String(
						receipt.get(
							"observation_unavailable_reason",
							"",
						)
					)
					== observation_unavailable_reason.strip_edges()
					and planning_availability == "observation_unavailable"
					and fail_zero_required
				)
			)
		)
	var nonclaims_exact := (
		String(receipt.get("schema_version", ""))
		== _scheduled_load_transfer_receipt_schema_version(
			_stability_policy_id
		)
		and int(receipt.get("semantic_step", -1)) == semantic_step
		and String(receipt.get("policy_id", "")) == _stability_policy_id
		and typeof(receipt.get("active", null)) == TYPE_BOOL
		and typeof(receipt.get("activation_reason", null)) == TYPE_STRING
		and typeof(
			receipt.get("ordered_scheduled_unweighted_contact_ids", null)
		) == TYPE_ARRAY
		and typeof(receipt.get("qualified_support_contact_ids", null))
		== TYPE_ARRAY
		and typeof(receipt.get("remaining_support_contact_ids", null))
		== TYPE_ARRAY
		and typeof(receipt.get("ordered_contact_preferences", null))
		== TYPE_ARRAY
		and typed_availability_exact
		and (
			plan_typed
			or (
				typeof(centroidal_request_value) == TYPE_DICTIONARY
				and typeof(centroidal_command_value) == TYPE_DICTIONARY
			)
		)
		and bool(
			receipt.get(
				"activation_uses_scheduler_boundaries_only",
				false,
			)
		)
		and int(receipt.get("morphology_branch_surface_count", -1)) == 0
		and not bool(
			receipt.get(
				"per_foot_measured_load_allocation_available",
				true,
			)
		)
		and not bool(receipt.get("commands_are_measurements", true))
		and not bool(receipt.get("adapter_actuation_applied", true))
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("walking_claim_authorized", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)
	if not nonclaims_exact:
		return {
			"ok": false,
			"failure_code": "SCHEDULED_LOAD_TRANSFER_RECEIPT_INVALID",
		}
	if fail_zero_required:
		return {
			"ok": true,
			"failure_code": "",
			"receipt": receipt.duplicate(true),
			"planning_availability": planning_availability,
			"fail_zero_required": true,
			"centroidal_request": {},
			"centroidal_command": {},
			"feedback_request":
			{
				"ok": true,
				"failure_code": "",
				"policy_id": _stability_policy_id,
				"feedback_request_nonzero": false,
				"portable_scheduler_aware_plan": true,
				"scheduled_load_transfer_active": false,
				"activation_reason":
				String(receipt.get("activation_reason", "")),
			},
		}
	var centroidal_request: Dictionary = centroidal_request_value
	var centroidal_command: Dictionary = centroidal_command_value
	if (
		String(centroidal_request.get("schema_version", ""))
		!= "sporespore_centroidal_support_request_v2"
		or int(centroidal_request.get("semantic_step", -1)) != semantic_step
		or String(centroidal_command.get("schema_version", ""))
		!= "sporespore_centroidal_support_command_v2"
		or int(centroidal_command.get("semantic_step", -1)) != semantic_step
	):
		return {
			"ok": false,
			"failure_code": "SCHEDULED_LOAD_TRANSFER_CENTROIDAL_PAIR_INVALID",
		}
	var desired_force := _dictionary_vector(
		centroidal_command.get("desired_external_force_world_n", {})
	)
	var desired_moment := _dictionary_vector(
		centroidal_command.get(
			"desired_external_roll_pitch_moment_world_nm",
			{},
		)
	)
	var up_axis := (-gravity).normalized()
	var desired_horizontal_force := (
		desired_force - up_axis * desired_force.dot(up_axis)
	)
	var feedback_request_nonzero := (
		desired_horizontal_force.length_squared() > 0.0
		or desired_moment.length_squared() > 0.0
	)
	return {
		"ok": true,
		"failure_code": "",
		"receipt": receipt.duplicate(true),
		"planning_availability": planning_availability,
		"fail_zero_required": false,
		"centroidal_request": centroidal_request.duplicate(true),
		"centroidal_command": centroidal_command.duplicate(true),
		"feedback_request":
		{
			"ok": true,
			"failure_code": "",
			"policy_id": _stability_policy_id,
			"target_center_of_mass_world_m":
			centroidal_request["target_center_of_mass_world_m"],
			"feedback_request_nonzero": feedback_request_nonzero,
			"portable_scheduler_aware_plan": true,
			"scheduled_load_transfer_active":
			bool(receipt.get("active", false)),
			"activation_reason":
			String(receipt.get("activation_reason", "")),
		},
	}


func _record_scheduled_load_transfer_receipt(receipt: Dictionary) -> void:
	_scheduled_load_transfer_receipt_count += 1
	var receipt_sha256 := CanonicalJsonScript.sha256(receipt)
	if _scheduled_load_transfer_first_receipt_sha256.is_empty():
		_scheduled_load_transfer_first_receipt_sha256 = receipt_sha256
	_scheduled_load_transfer_last_receipt_sha256 = receipt_sha256
	if bool(receipt.get("active", false)):
		_scheduled_load_transfer_active_step_count += 1
		var unweighted_contact_ids: Array = receipt.get(
			"ordered_scheduled_unweighted_contact_ids",
			[],
		)
		_scheduled_load_transfer_unweighted_contact_count += (
			unweighted_contact_ids.size()
		)
		var load_transfer_mode := String(receipt.get("mode", ""))
		if [
			"preferred_normal_force",
			"combined",
		].has(load_transfer_mode):
			_scheduled_load_transfer_preferred_normal_step_count += 1
		if [
			"remaining_support_centroid",
			"combined",
		].has(load_transfer_mode):
			_scheduled_load_transfer_remaining_centroid_step_count += 1
	if _is_scheduled_load_transfer_typed_policy(_stability_policy_id):
		match String(receipt.get("planning_availability", "")):
			"available":
				_scheduled_load_transfer_available_receipt_count += 1
			"observation_unavailable":
				_scheduled_load_transfer_unavailable_receipt_count += 1
			"upstream_infeasible":
				_scheduled_load_transfer_upstream_infeasible_receipt_count += 1
		if bool(receipt.get("fail_zero_required", false)):
			_scheduled_load_transfer_fail_zero_receipt_count += 1


func _ensure_v3_unavailable_stability_receipt(
	semantic_step: int,
	morphology: Dictionary,
	stability_shadow: Dictionary,
	gait_amplitude: float,
) -> Dictionary:
	if (
		not _is_scheduled_load_transfer_v3_policy(_stability_policy_id)
		or bool(stability_shadow.get("observation_available", false))
	):
		return stability_shadow
	var completed := stability_shadow.duplicate(true)
	var unavailable_reason := String(
		completed.get(
			"unavailable_reason",
			completed.get(
				"failure_code",
				"STABILITY_OBSERVATION_UNAVAILABLE",
			),
		)
	).strip_edges()
	if unavailable_reason.is_empty():
		unavailable_reason = "STABILITY_OBSERVATION_UNAVAILABLE"
	var stability_state: Dictionary = completed.get("stability_state", {})
	var plan := _scheduled_load_transfer_plan(
		semantic_step,
		morphology,
		stability_state,
		gait_amplitude,
		false,
		unavailable_reason,
	)
	completed["joint_mapping_shadow"] = {
		"ok": true,
		"attempted": true,
		"mapping_available": false,
		"infeasible": false,
		"outcome_code": "OBSERVATION_UNAVAILABLE:%s" % unavailable_reason,
		"failure_code": "",
		"qualified_contact_ids": [],
		"compared_actuator_count": 0,
		"mismatch_count": 0,
		"maximum_absolute_torque_error_nm": 0.0,
		"maximum_absolute_commanded_torque_nm": 0.0,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if not bool(plan.get("ok", false)):
		completed["stability_contribution_shadow"] = (
			_contribution_shadow_failure(
				String(
					plan.get(
						"failure_code",
						"CONTRIBUTION_SCHEDULED_LOAD_TRANSFER_V3_INVALID",
					)
				),
				"untyped",
			)
		)
		return completed
	var receipt: Dictionary = (
		plan.get("receipt", {}) as Dictionary
	).duplicate(true)
	_record_scheduled_load_transfer_receipt(receipt)
	var influence := _scheduled_load_transfer_fail_zero_influence(
		semantic_step,
		morphology,
		[],
		plan,
	)
	influence["observation_unavailable_reason"] = unavailable_reason
	completed["stability_contribution_shadow"] = influence
	return completed


func _scheduled_load_transfer_fail_zero_influence(
	semantic_step: int,
	morphology: Dictionary,
	qualified_contact_ids: Array[String],
	plan: Dictionary,
) -> Dictionary:
	var availability := String(
		plan.get("planning_availability", "observation_unavailable")
	)
	var influence := _bound_stability_contribution_shadow(
		semantic_step,
		morphology,
		[],
		availability,
	)
	var unavailable := availability == "observation_unavailable"
	influence["support_mode"] = "unavailable" if unavailable else "infeasible"
	influence["qualified_contact_ids"] = qualified_contact_ids
	influence["v3_available"] = false
	influence["upstream_infeasible"] = not unavailable
	influence["unavailable"] = unavailable
	influence["ordered_v3_command_count"] = 0
	influence["active_support_command_count"] = 0
	influence["inactive_contact_command_count"] = 0
	influence["full_v3_v2_compared_actuator_count"] = 0
	influence["maximum_full_v3_v2_torque_error_nm"] = 0.0
	influence["maximum_active_oracle_torque_error_nm"] = 0.0
	influence["maximum_absolute_commanded_torque_nm"] = 0.0
	influence["v2_outcome_matches"] = true
	influence["v2_observed_outcome_matches"] = false
	influence["v2_torque_comparison_required"] = false
	influence["stability_policy_id"] = _stability_policy_id
	influence["feedback_request_nonzero"] = false
	influence["planning_availability"] = availability
	influence["planning_outcome_code"] = String(
		(plan.get("receipt", {}) as Dictionary).get(
			"planning_outcome_code",
			"",
		)
	)
	influence["scheduled_load_transfer_receipt"] = (
		plan.get("receipt", {}) as Dictionary
	).duplicate(true)
	return influence


func _sample_stability_contribution_shadow(
	semantic_step: int,
	morphology: Dictionary,
	native_observation: Dictionary,
	stability_state: Dictionary,
	torso: RigidBody3D,
	limbs: Array,
	support_point_by_contact_id: Dictionary,
	v2_shadow: Dictionary,
	gait_amplitude: float,
) -> Dictionary:
	var qualified_contact_ids: Array[String] = []
	var support_contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		if not support_point_by_contact_id.has(contact_id):
			continue
		qualified_contact_ids.append(contact_id)
		support_contacts.append(
			{
				"contact_id": contact_id,
				"point_world_m": _vector(support_point_by_contact_id[contact_id]),
				"preferred_normal_force_n": 0.0,
			}
		)
	var scheduled_plan: Dictionary = {}
	var scheduled_load_transfer_receipt: Dictionary = {}
	if _is_scheduled_load_transfer_typed_policy(_stability_policy_id):
		scheduled_plan = _scheduled_load_transfer_plan(
			semantic_step,
			morphology,
			stability_state,
			gait_amplitude,
		)
		if not bool(scheduled_plan.get("ok", false)):
			return _contribution_shadow_failure(
				String(
					scheduled_plan.get(
						"failure_code",
						"CONTRIBUTION_SCHEDULED_LOAD_TRANSFER_V2_INVALID",
					)
				),
				"untyped",
			)
		scheduled_load_transfer_receipt = (
			scheduled_plan.get("receipt", {}) as Dictionary
		).duplicate(true)
		_record_scheduled_load_transfer_receipt(
			scheduled_load_transfer_receipt
		)
		if bool(scheduled_plan.get("fail_zero_required", false)):
			return _scheduled_load_transfer_fail_zero_influence(
				semantic_step,
				morphology,
				qualified_contact_ids,
				scheduled_plan,
			)
	if support_contacts.size() < 3:
		var unavailable_influence := _bound_stability_contribution_shadow(
			semantic_step,
			morphology,
			[],
			"observation_unavailable",
		)
		unavailable_influence["support_mode"] = "unavailable"
		unavailable_influence["qualified_contact_ids"] = qualified_contact_ids
		unavailable_influence["v3_available"] = false
		unavailable_influence["upstream_infeasible"] = false
		unavailable_influence["unavailable"] = true
		unavailable_influence["ordered_v3_command_count"] = 0
		unavailable_influence["active_support_command_count"] = 0
		unavailable_influence["inactive_contact_command_count"] = 0
		unavailable_influence["full_v3_v2_compared_actuator_count"] = 0
		unavailable_influence["maximum_full_v3_v2_torque_error_nm"] = 0.0
		unavailable_influence["maximum_active_oracle_torque_error_nm"] = 0.0
		unavailable_influence["maximum_absolute_commanded_torque_nm"] = 0.0
		unavailable_influence["v2_outcome_matches"] = true
		unavailable_influence["v2_observed_outcome_matches"] = false
		unavailable_influence["v2_torque_comparison_required"] = false
		unavailable_influence["stability_policy_id"] = _stability_policy_id
		unavailable_influence["feedback_request_nonzero"] = false
		unavailable_influence["observation_unavailable_reason"] = (
			"QUALIFIED_SUPPORT_COUNT:%d" % support_contacts.size()
		)
		return unavailable_influence

	var gravity := _dictionary_vector(stability_state["gravity_world_m_s2"])
	var whole_system_mass_kg := float(native_observation["whole_system_mass_kg"])
	var feedback_request: Dictionary = {}
	var centroidal_request: Dictionary = {}
	var centroidal_command: Dictionary = {}
	if _is_scheduled_load_transfer_policy(_stability_policy_id):
		if not _is_scheduled_load_transfer_typed_policy(
			_stability_policy_id
		):
			scheduled_plan = _scheduled_load_transfer_plan(
				semantic_step,
				morphology,
				stability_state,
				gait_amplitude,
			)
			if not bool(scheduled_plan.get("ok", false)):
				return _contribution_shadow_failure(
					String(
						scheduled_plan.get(
							"failure_code",
							"CONTRIBUTION_SCHEDULED_LOAD_TRANSFER_INVALID",
						)
					),
					"untyped",
				)
			scheduled_load_transfer_receipt = (
				scheduled_plan.get("receipt", {}) as Dictionary
			).duplicate(true)
			_record_scheduled_load_transfer_receipt(
				scheduled_load_transfer_receipt
			)
		feedback_request = (
			scheduled_plan.get("feedback_request", {}) as Dictionary
		).duplicate(true)
		centroidal_request = (
			scheduled_plan.get("centroidal_request", {}) as Dictionary
		).duplicate(true)
		centroidal_command = (
			scheduled_plan.get("centroidal_command", {}) as Dictionary
		).duplicate(true)
	else:
		feedback_request = _stability_feedback_request(
			torso,
			native_observation,
			stability_state,
		)
		if not bool(feedback_request.get("ok", false)):
			return _contribution_shadow_failure(
				String(
					feedback_request.get(
						"failure_code",
						"CONTRIBUTION_FEEDBACK_REQUEST_INVALID",
					)
				),
				"untyped",
			)
		centroidal_request = {
			"schema_version": "sporespore_centroidal_support_request_v2",
			"semantic_step": semantic_step,
			"whole_system_mass_kg": whole_system_mass_kg,
			"gravity_world_m_s2": stability_state["gravity_world_m_s2"],
			"support_plane_forward_world_unit":
			stability_state["support_plane_forward_world_unit"],
			"center_of_mass_world_m":
			native_observation["center_of_mass_world_m"],
			"center_of_mass_velocity_world_m_s":
			native_observation["center_of_mass_velocity_world_m_s"],
			"target_center_of_mass_world_m":
			feedback_request["target_center_of_mass_world_m"],
			"torso_roll_rad": float(feedback_request["torso_roll_rad"]),
			"torso_pitch_rad": float(feedback_request["torso_pitch_rad"]),
			"torso_roll_rate_rad_s":
			float(feedback_request["torso_roll_rate_rad_s"]),
			"torso_pitch_rate_rad_s":
			float(feedback_request["torso_pitch_rate_rad_s"]),
			"horizontal_position_gain_n_per_m":
			float(feedback_request["horizontal_position_gain_n_per_m"]),
			"horizontal_velocity_gain_ns_per_m":
			float(feedback_request["horizontal_velocity_gain_ns_per_m"]),
			"vertical_position_gain_n_per_m": 0.0,
			"vertical_velocity_gain_ns_per_m": 0.0,
			"roll_position_gain_nm_per_rad":
			float(feedback_request["roll_position_gain_nm_per_rad"]),
			"roll_velocity_gain_nm_s_per_rad":
			float(feedback_request["roll_velocity_gain_nm_s_per_rad"]),
			"pitch_position_gain_nm_per_rad":
			float(feedback_request["pitch_position_gain_nm_per_rad"]),
			"pitch_velocity_gain_nm_s_per_rad":
			float(feedback_request["pitch_velocity_gain_nm_s_per_rad"]),
			"maximum_horizontal_force_n":
			float(feedback_request["maximum_horizontal_force_n"]),
			"maximum_vertical_correction_n": 0.0,
			"maximum_roll_pitch_moment_nm":
			float(feedback_request["maximum_roll_pitch_moment_nm"]),
			"declared_supported_weight_fraction": 1.0,
			"characterized_friction_coefficient":
			_characterized_controller_friction_coefficient,
			"minimum_normal_force_n": 0.0,
			"maximum_normal_force_n":
			whole_system_mass_kg * gravity.length(),
			"nominal_support_count": 4,
			"feasibility_tolerance": 1.0e-5,
			"support_contacts": support_contacts,
		}
		var command_envelope := _call_input(
			"command_centroidal_support_v2_json",
			centroidal_request,
		)
		if not bool(command_envelope.get("ok", false)):
			return _contribution_shadow_failure(
				_typed_envelope_code(
					"CONTRIBUTION_CENTROIDAL_COMMAND",
					command_envelope,
				),
				"untyped",
			)
		centroidal_command = command_envelope["value"]
	if not bool(centroidal_command.get("feasible", false)):
		var infeasible_influence := _bound_stability_contribution_shadow(
			semantic_step,
			morphology,
			[],
			"upstream_infeasible",
		)
		var v2_observed_infeasible_match := bool(
			v2_shadow.get("infeasible", false)
		)
		var v2_infeasible_matches := (
			v2_observed_infeasible_match
			or _is_stability_feedback_authority_policy(_stability_policy_id)
		)
		infeasible_influence["support_mode"] = "infeasible"
		infeasible_influence["qualified_contact_ids"] = qualified_contact_ids
		infeasible_influence["v3_available"] = false
		infeasible_influence["upstream_infeasible"] = true
		infeasible_influence["ordered_v3_command_count"] = 0
		infeasible_influence["active_support_command_count"] = 0
		infeasible_influence["inactive_contact_command_count"] = 0
		infeasible_influence["full_v3_v2_compared_actuator_count"] = 0
		infeasible_influence["maximum_full_v3_v2_torque_error_nm"] = 0.0
		infeasible_influence["maximum_active_oracle_torque_error_nm"] = 0.0
		infeasible_influence["maximum_absolute_commanded_torque_nm"] = 0.0
		infeasible_influence["v2_outcome_matches"] = v2_infeasible_matches
		infeasible_influence["v2_observed_outcome_matches"] = (
			v2_observed_infeasible_match
		)
		infeasible_influence["v2_torque_comparison_required"] = (
			_stability_policy_id == P5I3B_WEIGHT_SUPPORT_POLICY_ID
		)
		infeasible_influence["stability_policy_id"] = _stability_policy_id
		infeasible_influence["feedback_request_nonzero"] = bool(
			feedback_request["feedback_request_nonzero"]
		)
		infeasible_influence["feedback_request"] = feedback_request.duplicate(true)
		infeasible_influence["centroidal_request"] = centroidal_request.duplicate(true)
		infeasible_influence["centroidal_command"] = centroidal_command.duplicate(true)
		infeasible_influence["scheduled_load_transfer_receipt"] = (
			scheduled_load_transfer_receipt.duplicate(true)
		)
		if not v2_infeasible_matches:
			infeasible_influence["mismatch_count"] = (
				int(infeasible_influence.get("mismatch_count", 0)) + 1
			)
			infeasible_influence["ok"] = false
			infeasible_influence["failure_code"] = (
				"CONTRIBUTION_V2_INFEASIBLE_OUTCOME_MISMATCH"
			)
		return infeasible_influence

	var kinematics_result := _joint_mapping_kinematics(
		morphology,
		limbs,
		support_point_by_contact_id,
	)
	if not bool(kinematics_result.get("ok", false)):
		return _contribution_shadow_failure(
			String(
				kinematics_result.get(
					"failure_code",
					"CONTRIBUTION_KINEMATICS_INVALID",
				)
			),
			"untyped",
		)
	var ordered_kinematics: Array = kinematics_result["ordered_kinematics"]
	var map_envelope := _call_input(
		"map_endpoint_force_to_joint_v3_json",
		{
			"schema_version": "sporespore_map_endpoint_force_to_joint_request_v3",
			"descriptor": _descriptor,
			"request":
			{
				"schema_version": "sporespore_endpoint_force_joint_map_request_v3",
				"semantic_step": semantic_step,
				"centroidal_command": centroidal_command,
				"ordered_actuator_kinematics": ordered_kinematics,
			},
		},
	)
	if not bool(map_envelope.get("ok", false)):
		return _contribution_shadow_failure(
			_typed_envelope_code("CONTRIBUTION_V3_MAPPING", map_envelope),
			"untyped",
		)
	var receipt: Dictionary = map_envelope["value"]
	var mapped_commands: Array = receipt.get(
		"ordered_generalized_joint_torque_commands",
		[],
	)
	var expected_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var mapping_mismatch_count := 0
	var inactive_zero_mismatch_count := 0
	var maximum_active_oracle_torque_error_nm := 0.0
	var maximum_full_v3_v2_torque_error_nm := 0.0
	var maximum_absolute_commanded_torque_nm := 0.0
	var active_command_count := 0
	var inactive_command_count := 0
	var command_by_contact_id: Dictionary = {}
	for command_value in centroidal_command.get(
		"ordered_support_contact_commands",
		[],
	):
		var command: Dictionary = command_value
		command_by_contact_id[String(command.get("contact_id", ""))] = command
	var kinematics_by_actuator_id: Dictionary = {}
	for kinematics_value in ordered_kinematics:
		var kinematics: Dictionary = kinematics_value
		kinematics_by_actuator_id[String(kinematics.get("actuator_id", ""))] = kinematics
	var v2_command_by_actuator_id: Dictionary = {}
	var full_support := (
		qualified_contact_ids.size()
		== int((morphology.get("ordered_contact_site_ids", []) as Array).size())
	)
	var compare_full_v3_v2_torques := (
		full_support
		and _stability_policy_id == P5I3B_WEIGHT_SUPPORT_POLICY_ID
	)
	if full_support and bool(v2_shadow.get("mapping_available", false)):
		if compare_full_v3_v2_torques:
			var v2_receipt: Dictionary = v2_shadow.get("mapping_receipt", {})
			for v2_value in v2_receipt.get(
				"ordered_generalized_joint_torque_commands",
				[],
			):
				var v2_command: Dictionary = v2_value
				v2_command_by_actuator_id[
					String(v2_command.get("actuator_id", ""))
				] = v2_command
	elif full_support:
		mapping_mismatch_count += 1
	elif bool(v2_shadow.get("mapping_available", true)):
		mapping_mismatch_count += 1

	if mapped_commands.size() != expected_actuator_ids.size():
		mapping_mismatch_count += 1
	for index in range(mini(mapped_commands.size(), expected_actuator_ids.size())):
		var mapped: Dictionary = mapped_commands[index]
		var actuator_id := String(mapped.get("actuator_id", ""))
		var contact_id := String(mapped.get("contact_site_id", ""))
		if actuator_id != String(expected_actuator_ids[index]):
			mapping_mismatch_count += 1
		if (
			not kinematics_by_actuator_id.has(actuator_id)
			or (
				bool(mapped.get("active_support_contact", false))
				and not command_by_contact_id.has(contact_id)
			)
		):
			mapping_mismatch_count += 1
			continue
		var torque_nm := float(mapped.get("generalized_torque_command_nm", NAN))
		maximum_absolute_commanded_torque_nm = maxf(
			maximum_absolute_commanded_torque_nm,
			absf(torque_nm),
		)
		if bool(mapped.get("active_support_contact", false)):
			active_command_count += 1
			var kinematics: Dictionary = kinematics_by_actuator_id[actuator_id]
			var command: Dictionary = command_by_contact_id[contact_id]
			var axis := _dictionary_vector(kinematics["joint_axis_world_unit"])
			var anchor := _dictionary_vector(kinematics["joint_anchor_world_m"])
			var endpoint := _dictionary_vector(kinematics["endpoint_world_m"])
			var force := _dictionary_vector(
				command["joint_task_force_delta_world_n"]
			)
			var independent_torque_nm := axis.cross(endpoint - anchor).dot(force)
			var oracle_error_nm := absf(torque_nm - independent_torque_nm)
			maximum_active_oracle_torque_error_nm = maxf(
				maximum_active_oracle_torque_error_nm,
				oracle_error_nm,
			)
			if (
				String(mapped.get("mapping_mode", "")) != "support_command"
				or bool(mapped.get("inactive_contact_forced_zero", true))
				or oracle_error_nm > JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM
			):
				mapping_mismatch_count += 1
		else:
			inactive_command_count += 1
			var inactive_exact := (
				String(mapped.get("mapping_mode", "")) == "inactive_contact_zero"
				and bool(mapped.get("inactive_contact_forced_zero", false))
				and (
					_dictionary_vector(
						mapped.get(
							"endpoint_task_force_command_world_n",
							{},
						)
					)
					== Vector3.ZERO
				)
				and torque_nm == 0.0
			)
			if not inactive_exact:
				inactive_zero_mismatch_count += 1
				mapping_mismatch_count += 1
		if compare_full_v3_v2_torques:
			if not v2_command_by_actuator_id.has(actuator_id):
				mapping_mismatch_count += 1
			else:
				var v2_command: Dictionary = v2_command_by_actuator_id[actuator_id]
				var v2_error_nm := absf(
					torque_nm
					- float(v2_command.get("generalized_torque_command_nm", NAN))
				)
				maximum_full_v3_v2_torque_error_nm = maxf(
					maximum_full_v3_v2_torque_error_nm,
					v2_error_nm,
				)
				if v2_error_nm > JOINT_MAPPING_SHADOW_ABSOLUTE_TOLERANCE_NM:
					mapping_mismatch_count += 1

	var receipt_nonclaims_exact := (
		String(receipt.get("schema_version", ""))
		== "sporespore_endpoint_force_joint_map_receipt_v3"
		and int(receipt.get("semantic_step", -1)) == semantic_step
		and int(receipt.get("active_actuator_count", -1)) == active_command_count
		and int(receipt.get("inactive_actuator_count", -1))
		== inactive_command_count
		and bool(receipt.get("endpoint_force_map_available", false))
		and bool(receipt.get("partial_support_mapping_available", false))
		and bool(receipt.get("inactive_contact_commands_forced_zero", false))
		and not bool(receipt.get("measured_joint_torque_available", true))
		and not bool(receipt.get("actuator_response_characterized", true))
		and not bool(receipt.get("adapter_actuation_applied", true))
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)
	if not receipt_nonclaims_exact:
		mapping_mismatch_count += 1

	var influence := _bound_stability_contribution_shadow(
		semantic_step,
		morphology,
		mapped_commands,
		"available",
	)
	influence["support_mode"] = "full" if full_support else "partial"
	influence["qualified_contact_ids"] = qualified_contact_ids
	influence["v3_available"] = true
	influence["upstream_infeasible"] = false
	influence["ordered_v3_command_count"] = mapped_commands.size()
	influence["active_support_command_count"] = active_command_count
	influence["inactive_contact_command_count"] = inactive_command_count
	influence["full_v3_v2_compared_actuator_count"] = (
		mapped_commands.size() if compare_full_v3_v2_torques else 0
	)
	influence["maximum_full_v3_v2_torque_error_nm"] = (
		maximum_full_v3_v2_torque_error_nm
	)
	influence["maximum_active_oracle_torque_error_nm"] = (
		maximum_active_oracle_torque_error_nm
	)
	influence["maximum_absolute_commanded_torque_nm"] = (
		maximum_absolute_commanded_torque_nm
	)
	influence["stability_policy_id"] = _stability_policy_id
	influence["feedback_request_nonzero"] = bool(
		feedback_request["feedback_request_nonzero"]
	)
	influence["feedback_request"] = feedback_request.duplicate(true)
	influence["centroidal_request"] = centroidal_request.duplicate(true)
	influence["centroidal_command"] = centroidal_command.duplicate(true)
	influence["scheduled_load_transfer_receipt"] = (
		scheduled_load_transfer_receipt.duplicate(true)
	)
	influence["inactive_zero_mismatch_count"] = (
		int(influence.get("inactive_zero_mismatch_count", 0))
		+ inactive_zero_mismatch_count
	)
	influence["mismatch_count"] = (
		int(influence.get("mismatch_count", 0)) + mapping_mismatch_count
	)
	var v2_observed_outcome_matches := (
		(
			full_support
			and bool(v2_shadow.get("mapping_available", false))
		)
		or (
			not full_support
			and not bool(v2_shadow.get("mapping_available", true))
			and not bool(v2_shadow.get("infeasible", true))
		)
	)
	influence["v2_observed_outcome_matches"] = v2_observed_outcome_matches
	influence["v2_torque_comparison_required"] = (
		_stability_policy_id == P5I3B_WEIGHT_SUPPORT_POLICY_ID
	)
	influence["v2_outcome_matches"] = (
		v2_observed_outcome_matches
		or _is_stability_feedback_authority_policy(_stability_policy_id)
	)
	if (
		mapping_mismatch_count != 0
		or not bool(influence.get("v2_outcome_matches", false))
	):
		influence["ok"] = false
		if String(influence.get("failure_code", "")).is_empty():
			influence["failure_code"] = "CONTRIBUTION_MAPPING_COMPARISON_MISMATCH"
	return influence


func _stability_feedback_request(
	torso: RigidBody3D,
	native_observation: Dictionary,
	stability_state: Dictionary,
) -> Dictionary:
	var center_of_mass := _dictionary_vector(
		native_observation.get("center_of_mass_world_m", {})
	)
	var center_of_mass_velocity := _dictionary_vector(
		native_observation.get("center_of_mass_velocity_world_m_s", {})
	)
	var support_centroid := _dictionary_vector(
		native_observation.get("support_centroid_world_m", {})
	)
	var gravity := _dictionary_vector(stability_state.get("gravity_world_m_s2", {}))
	var declared_forward := _dictionary_vector(
		stability_state.get("support_plane_forward_world_unit", {})
	)
	if (
		torso == null
		or not center_of_mass.is_finite()
		or not center_of_mass_velocity.is_finite()
		or not support_centroid.is_finite()
		or not gravity.is_finite()
		or gravity.length_squared() <= 1.0e-12
		or not declared_forward.is_finite()
	):
		return {
			"ok": false,
			"failure_code": "CONTRIBUTION_FEEDBACK_STATE_INVALID",
		}
	var up_axis := (-gravity).normalized()
	var forward_axis := declared_forward - up_axis * declared_forward.dot(up_axis)
	if forward_axis.length_squared() <= 1.0e-12:
		return {
			"ok": false,
			"failure_code": "CONTRIBUTION_FEEDBACK_FORWARD_DEGENERATE",
		}
	forward_axis = forward_axis.normalized()
	var lateral_axis := forward_axis.cross(up_axis)
	if lateral_axis.length_squared() <= 1.0e-12:
		return {
			"ok": false,
			"failure_code": "CONTRIBUTION_FEEDBACK_LATERAL_DEGENERATE",
		}
	lateral_axis = lateral_axis.normalized()
	var torso_up := torso.global_basis.y.normalized()
	var upright_component := torso_up.dot(up_axis)
	var torso_roll_rad := atan2(torso_up.dot(lateral_axis), upright_component)
	var torso_pitch_rad := atan2(-torso_up.dot(forward_axis), upright_component)
	var torso_roll_rate_rad_s := torso.angular_velocity.dot(forward_axis)
	var torso_pitch_rate_rad_s := torso.angular_velocity.dot(lateral_axis)
	if (
		not is_finite(torso_roll_rad)
		or not is_finite(torso_pitch_rad)
		or not is_finite(torso_roll_rate_rad_s)
		or not is_finite(torso_pitch_rate_rad_s)
	):
		return {
			"ok": false,
			"failure_code": "CONTRIBUTION_FEEDBACK_ATTITUDE_INVALID",
		}

	var target_center_of_mass := center_of_mass
	var horizontal_position_gain := 0.0
	var horizontal_velocity_gain := 0.0
	var maximum_horizontal_force := 0.0
	var roll_position_gain := 0.0
	var roll_velocity_gain := 0.0
	var pitch_position_gain := 0.0
	var pitch_velocity_gain := 0.0
	var maximum_roll_pitch_moment := 0.0
	if _stability_policy_id == P5I3C_FEEDBACK_POLICY_ID:
		target_center_of_mass += (
			lateral_axis
			* (support_centroid - center_of_mass).dot(lateral_axis)
		)
		horizontal_position_gain = P5I3C_HORIZONTAL_POSITION_GAIN_N_PER_M
		horizontal_velocity_gain = P5I3C_HORIZONTAL_VELOCITY_GAIN_NS_PER_M
		maximum_horizontal_force = P5I3C_MAXIMUM_HORIZONTAL_FORCE_N
		roll_position_gain = P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD
		roll_velocity_gain = P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD
		pitch_position_gain = P5I3C_ROLL_PITCH_POSITION_GAIN_NM_PER_RAD
		pitch_velocity_gain = P5I3C_ROLL_PITCH_VELOCITY_GAIN_NM_S_PER_RAD
		maximum_roll_pitch_moment = P5I3C_MAXIMUM_ROLL_PITCH_MOMENT_NM

	var target_offset := target_center_of_mass - center_of_mass
	var horizontal_velocity := (
		center_of_mass_velocity
		- up_axis * center_of_mass_velocity.dot(up_axis)
	)
	var unconstrained_horizontal_force := (
		horizontal_position_gain * target_offset
		- horizontal_velocity_gain * horizontal_velocity
	)
	var unconstrained_roll_moment := (
		-roll_position_gain * torso_roll_rad
		- roll_velocity_gain * torso_roll_rate_rad_s
	)
	var unconstrained_pitch_moment := (
		-pitch_position_gain * torso_pitch_rad
		- pitch_velocity_gain * torso_pitch_rate_rad_s
	)
	var feedback_request_nonzero := (
		unconstrained_horizontal_force.length_squared() > 0.0
		or absf(unconstrained_roll_moment) > 0.0
		or absf(unconstrained_pitch_moment) > 0.0
	)
	return {
		"ok": true,
		"failure_code": "",
		"policy_id": _stability_policy_id,
		"target_center_of_mass_world_m": _vector(target_center_of_mass),
		"support_frame_forward_world_unit":
		_unit_vector_dictionary_binary64(forward_axis),
		"support_frame_lateral_world_unit":
		_unit_vector_dictionary_binary64(lateral_axis),
		"support_frame_up_world_unit": _unit_vector_dictionary_binary64(up_axis),
		"torso_roll_rad": torso_roll_rad,
		"torso_pitch_rad": torso_pitch_rad,
		"torso_roll_rate_rad_s": torso_roll_rate_rad_s,
		"torso_pitch_rate_rad_s": torso_pitch_rate_rad_s,
		"horizontal_position_gain_n_per_m": horizontal_position_gain,
		"horizontal_velocity_gain_ns_per_m": horizontal_velocity_gain,
		"maximum_horizontal_force_n": maximum_horizontal_force,
		"roll_position_gain_nm_per_rad": roll_position_gain,
		"roll_velocity_gain_nm_s_per_rad": roll_velocity_gain,
		"pitch_position_gain_nm_per_rad": pitch_position_gain,
		"pitch_velocity_gain_nm_s_per_rad": pitch_velocity_gain,
		"maximum_roll_pitch_moment_nm": maximum_roll_pitch_moment,
		"unconstrained_horizontal_force_world_n":
		_vector(unconstrained_horizontal_force),
		"unconstrained_roll_moment_nm": unconstrained_roll_moment,
		"unconstrained_pitch_moment_nm": unconstrained_pitch_moment,
		"feedback_request_nonzero": feedback_request_nonzero,
		"vertical_feedback_enabled": false,
	}


func _bound_stability_contribution_shadow(
	semantic_step: int,
	morphology: Dictionary,
	mapped_commands: Array,
	availability: String,
) -> Dictionary:
	if not [
		"available",
		"observation_unavailable",
		"upstream_infeasible",
	].has(availability):
		return _contribution_shadow_failure(
			"CONTRIBUTION_AVAILABILITY_INVALID:%s" % availability,
			"untyped",
		)
	var available := availability == "available"
	var observation_unavailable := availability == "observation_unavailable"
	var upstream_infeasible := availability == "upstream_infeasible"
	var actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var mapped_by_actuator_id: Dictionary = {}
	for mapped_value in mapped_commands:
		var mapped: Dictionary = mapped_value
		mapped_by_actuator_id[String(mapped.get("actuator_id", ""))] = mapped
	if available and mapped_by_actuator_id.size() != actuator_ids.size():
		return _contribution_shadow_failure(
			"CONTRIBUTION_MAPPED_ACTUATOR_COUNT_MISMATCH",
			"untyped",
		)

	var previous_by_actuator_id: Dictionary = {}
	for previous_value in _contribution_previous_applied_corrections:
		var previous: Dictionary = previous_value
		previous_by_actuator_id[String(previous.get("actuator_id", ""))] = previous
	var requested_corrections: Array = []
	var effective_previous_corrections: Array = []
	var proposed_by_actuator_id: Dictionary = {}
	var raw_torque_by_actuator_id: Dictionary = {}
	var profile_input_by_actuator_id: Dictionary = {}
	var profile_input_clamped_by_actuator_id: Dictionary = {}
	var mapping_mode_by_actuator_id: Dictionary = {}
	var inactive_hard_zero_transition_count := 0
	var profile_input_clamped_count := 0
	var profile_conversion_failure_count := 0
	var preparation_mismatch_count := 0
	var maximum_absolute_profile_input_torque_nm := 0.0
	var maximum_absolute_proposed_velocity_rad_s := 0.0
	var nonzero_active_command_count := 0
	for actuator_id_value in actuator_ids:
		var actuator_id := String(actuator_id_value)
		var mapping_mode := ""
		var proposed_velocity: Variant = null
		if available:
			if not mapped_by_actuator_id.has(actuator_id):
				preparation_mismatch_count += 1
				proposed_velocity = 0.0
				raw_torque_by_actuator_id[actuator_id] = NAN
				profile_input_by_actuator_id[actuator_id] = NAN
				profile_input_clamped_by_actuator_id[actuator_id] = false
			else:
				var mapped: Dictionary = mapped_by_actuator_id[actuator_id]
				mapping_mode = String(mapped.get("mapping_mode", ""))
				var raw_torque_nm := float(
					mapped.get("generalized_torque_command_nm", NAN)
				)
				var profile_input_torque_nm := clampf(
					raw_torque_nm,
					-CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM,
					CHARACTERIZED_MAXIMUM_GENERALIZED_TORQUE_NM,
				)
				var profile_input_clamped := (
					profile_input_torque_nm != raw_torque_nm
				)
				raw_torque_by_actuator_id[actuator_id] = raw_torque_nm
				profile_input_by_actuator_id[actuator_id] = (
					profile_input_torque_nm
				)
				profile_input_clamped_by_actuator_id[actuator_id] = (
					profile_input_clamped
				)
				if profile_input_clamped:
					profile_input_clamped_count += 1
				maximum_absolute_profile_input_torque_nm = maxf(
					maximum_absolute_profile_input_torque_nm,
					absf(profile_input_torque_nm),
				)
				var profile := characterized_host_velocity_delta_for_generalized_torque(
					profile_input_torque_nm
				)
				if not bool(profile.get("ok", false)):
					preparation_mismatch_count += 1
					profile_conversion_failure_count += 1
					proposed_velocity = 0.0
				else:
					proposed_velocity = float(
						profile["canonical_velocity_delta_rad_s"]
					)
			proposed_by_actuator_id[actuator_id] = proposed_velocity
			mapping_mode_by_actuator_id[actuator_id] = mapping_mode
			maximum_absolute_proposed_velocity_rad_s = maxf(
				maximum_absolute_proposed_velocity_rad_s,
				absf(float(proposed_velocity)),
			)
			if (
				mapping_mode == "support_command"
				and absf(float(proposed_velocity)) > 0.0
			):
				nonzero_active_command_count += 1
			requested_corrections.append(
				{
					"actuator_id": actuator_id,
					"requested_position_delta_rad": 0.0,
					"requested_velocity_delta_rad_s": proposed_velocity,
				}
			)
		else:
			requested_corrections.append(
				{
					"actuator_id": actuator_id,
					"requested_position_delta_rad": null,
					"requested_velocity_delta_rad_s": null,
				}
			)
		if _contribution_previous_semantic_step >= 0:
			if not previous_by_actuator_id.has(actuator_id):
				preparation_mismatch_count += 1
				effective_previous_corrections.append(
					{
						"actuator_id": actuator_id,
						"applied_position_delta_rad": 0.0,
						"applied_velocity_delta_rad_s": 0.0,
					}
				)
			else:
				var previous: Dictionary = (
					previous_by_actuator_id[actuator_id] as Dictionary
				).duplicate(true)
				if (
					available
					and mapping_mode == "inactive_contact_zero"
				):
					if (
						float(previous.get("applied_position_delta_rad", 0.0)) != 0.0
						or float(
							previous.get(
								"applied_velocity_delta_rad_s",
								0.0,
							)
						)
						!= 0.0
					):
						inactive_hard_zero_transition_count += 1
					previous["applied_position_delta_rad"] = 0.0
					previous["applied_velocity_delta_rad_s"] = 0.0
				effective_previous_corrections.append(previous)

	var previous_step_for_request: Variant = null
	var previous_corrections_for_request: Variant = null
	if _contribution_previous_semantic_step >= 0:
		previous_step_for_request = _contribution_previous_semantic_step
		previous_corrections_for_request = effective_previous_corrections
	var use_scaled_influence := _stability_influence_scale_enabled
	var request := {
		"schema_version":
		(
			"sporespore_stability_influence_request_v3"
			if use_scaled_influence
			else "sporespore_stability_influence_request_v2"
		),
		"semantic_step": semantic_step,
		"availability": availability,
		"maximum_absolute_position_delta_rad":
		CONTRIBUTION_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
		"maximum_absolute_velocity_delta_rad_s":
		CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
		"maximum_position_delta_slew_per_step_rad":
		CONTRIBUTION_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
		"maximum_velocity_delta_slew_per_step_rad_s":
		CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
		"ordered_requested_corrections": requested_corrections,
		"previous_semantic_step": previous_step_for_request,
		"ordered_previous_applied_corrections":
		previous_corrections_for_request,
	}
	if use_scaled_influence:
		request["global_requested_correction_scale"] = (
			_stability_influence_global_scale
		)
	var envelope := _call_input(
		(
			"bound_stability_influence_v3_json"
			if use_scaled_influence
			else "bound_stability_influence_v2_json"
		),
		{
			"schema_version":
			(
				"sporespore_bound_stability_influence_request_v3"
				if use_scaled_influence
				else "sporespore_bound_stability_influence_request_v2"
			),
			"descriptor": _descriptor,
			"request": request,
		},
	)
	if not bool(envelope.get("ok", false)):
		return _contribution_shadow_failure(
			_typed_envelope_code("CONTRIBUTION_INFLUENCE", envelope),
			"untyped",
		)
	var receipt: Dictionary = envelope["value"]
	var applied_corrections: Array = receipt.get(
		"ordered_applied_corrections",
		[],
	)
	var effective_previous_by_actuator_id: Dictionary = {}
	for previous_value in effective_previous_corrections:
		var previous: Dictionary = previous_value
		effective_previous_by_actuator_id[String(previous.get("actuator_id", ""))] = previous
	var mismatch_count := preparation_mismatch_count
	var limiter_mismatch_count := 0
	var inactive_zero_mismatch_count := 0
	var fallback_zero_output_count := 0
	var slew_limited_output_count := 0
	var magnitude_saturated_output_count := 0
	var maximum_absolute_applied_velocity_rad_s := 0.0
	var maximum_absolute_host_delta_rad_s := 0.0
	var maximum_limiter_reconstruction_error := 0.0
	var independently_any_slew_limiting := false
	var independently_any_magnitude_saturation := false
	var ordered_contributions: Array = []
	if applied_corrections.size() != actuator_ids.size():
		mismatch_count += 1
		limiter_mismatch_count += 1
	for index in range(mini(applied_corrections.size(), actuator_ids.size())):
		var actuator_id := String(actuator_ids[index])
		var correction: Dictionary = applied_corrections[index]
		if String(correction.get("actuator_id", "")) != actuator_id:
			mismatch_count += 1
			limiter_mismatch_count += 1
		var previous_position := 0.0
		var previous_velocity := 0.0
		if effective_previous_by_actuator_id.has(actuator_id):
			var previous: Dictionary = effective_previous_by_actuator_id[actuator_id]
			previous_position = float(
				previous.get("applied_position_delta_rad", NAN)
			)
			previous_velocity = float(
				previous.get("applied_velocity_delta_rad_s", NAN)
			)
		var expected_position := 0.0
		var expected_velocity := 0.0
		var expected_magnitude_saturated := false
		var expected_slew_limited := false
		var expected_fallback_zeroed := not available
		if available:
			var raw_requested_velocity := float(
				proposed_by_actuator_id.get(actuator_id, NAN)
			)
			var requested_velocity := (
				raw_requested_velocity * _stability_influence_global_scale
				if use_scaled_influence
				else raw_requested_velocity
			)
			var magnitude_position := clampf(
				0.0,
				-CONTRIBUTION_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
				CONTRIBUTION_MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
			)
			var magnitude_velocity := clampf(
				requested_velocity,
				-CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
				CONTRIBUTION_MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
			)
			expected_magnitude_saturated = (
				magnitude_position != 0.0
				or magnitude_velocity != requested_velocity
			)
			expected_position = clampf(
				magnitude_position,
				previous_position
				- CONTRIBUTION_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
				previous_position
				+ CONTRIBUTION_MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
			)
			expected_velocity = clampf(
				magnitude_velocity,
				previous_velocity
				- CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
				previous_velocity
				+ CONTRIBUTION_MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S,
			)
			expected_slew_limited = (
				expected_position != magnitude_position
				or expected_velocity != magnitude_velocity
			)
		var applied_position := float(
			correction.get("applied_position_delta_rad", NAN)
		)
		var applied_velocity := float(
			correction.get("applied_velocity_delta_rad_s", NAN)
		)
		var host_delta := (
			CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE
			* applied_velocity
		)
		var reconstruction_error := maxf(
			absf(applied_position - expected_position),
			absf(applied_velocity - expected_velocity),
		)
		maximum_limiter_reconstruction_error = maxf(
			maximum_limiter_reconstruction_error,
			reconstruction_error,
		)
		maximum_absolute_applied_velocity_rad_s = maxf(
			maximum_absolute_applied_velocity_rad_s,
			absf(applied_velocity),
		)
		maximum_absolute_host_delta_rad_s = maxf(
			maximum_absolute_host_delta_rad_s,
			absf(host_delta),
		)
		if bool(correction.get("slew_limited", false)):
			slew_limited_output_count += 1
		if bool(correction.get("magnitude_saturated", false)):
			magnitude_saturated_output_count += 1
		if bool(correction.get("fallback_zeroed", false)):
			fallback_zero_output_count += 1
		independently_any_slew_limiting = (
			independently_any_slew_limiting or expected_slew_limited
		)
		independently_any_magnitude_saturation = (
			independently_any_magnitude_saturation
			or expected_magnitude_saturated
		)
		var requested_fields_match := false
		if use_scaled_influence:
			requested_fields_match = (
				(
					available
					and correction.get("raw_requested_position_delta_rad") != null
					and correction.get("raw_requested_velocity_delta_rad_s") != null
					and correction.get("scaled_requested_position_delta_rad") != null
					and correction.get("scaled_requested_velocity_delta_rad_s") != null
					and float(correction["raw_requested_position_delta_rad"]) == 0.0
					and absf(
						float(correction["raw_requested_velocity_delta_rad_s"])
						- float(proposed_by_actuator_id.get(actuator_id, NAN))
					)
					<= CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE
					and float(correction["scaled_requested_position_delta_rad"]) == 0.0
					and absf(
						float(correction["scaled_requested_velocity_delta_rad_s"])
						- (
							float(proposed_by_actuator_id.get(actuator_id, NAN))
							* _stability_influence_global_scale
						)
					)
					<= CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE
				)
				or (
					not available
					and correction.get("raw_requested_position_delta_rad") == null
					and correction.get("raw_requested_velocity_delta_rad_s") == null
					and correction.get("scaled_requested_position_delta_rad") == null
					and correction.get("scaled_requested_velocity_delta_rad_s") == null
				)
			)
		else:
			requested_fields_match = (
				(
					available
					and correction.get("requested_position_delta_rad") != null
					and correction.get("requested_velocity_delta_rad_s") != null
					and float(correction["requested_position_delta_rad"]) == 0.0
					and absf(
						float(correction["requested_velocity_delta_rad_s"])
						- float(proposed_by_actuator_id.get(actuator_id, NAN))
					)
					<= CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE
				)
				or (
					not available
					and correction.get("requested_position_delta_rad") == null
					and correction.get("requested_velocity_delta_rad_s") == null
				)
			)
		var flags_match := (
			bool(correction.get("magnitude_saturated", not expected_magnitude_saturated))
			== expected_magnitude_saturated
			and bool(correction.get("slew_limited", not expected_slew_limited))
			== expected_slew_limited
			and bool(correction.get("fallback_zeroed", not expected_fallback_zeroed))
			== expected_fallback_zeroed
		)
		if (
			not requested_fields_match
			or not flags_match
			or reconstruction_error
			> CONTRIBUTION_LIMITER_RECONSTRUCTION_TOLERANCE
		):
			mismatch_count += 1
			limiter_mismatch_count += 1
		var mapping_mode := String(
			mapping_mode_by_actuator_id.get(actuator_id, "")
		)
		if (
			available
			and mapping_mode == "inactive_contact_zero"
			and (
				float(proposed_by_actuator_id.get(actuator_id, NAN)) != 0.0
				or applied_position != 0.0
				or applied_velocity != 0.0
				or host_delta != 0.0
			)
		):
			mismatch_count += 1
			inactive_zero_mismatch_count += 1
		if not available and (
			applied_position != 0.0
			or applied_velocity != 0.0
			or host_delta != 0.0
			or not bool(correction.get("fallback_zeroed", false))
		):
			mismatch_count += 1
			limiter_mismatch_count += 1
		ordered_contributions.append(
			{
				"actuator_id": actuator_id,
				"mapping_mode": mapping_mode,
				"raw_generalized_torque_command_nm":
				raw_torque_by_actuator_id.get(actuator_id),
				"profile_input_torque_nm":
				profile_input_by_actuator_id.get(actuator_id),
				"profile_input_clamped":
				bool(
					profile_input_clamped_by_actuator_id.get(
						actuator_id,
						false,
					)
				),
				"proposed_canonical_velocity_delta_rad_s":
				proposed_by_actuator_id.get(actuator_id),
				"global_requested_correction_scale":
				_stability_influence_global_scale,
				"scaled_proposed_canonical_velocity_delta_rad_s":
				(
					float(proposed_by_actuator_id.get(actuator_id, 0.0))
					* _stability_influence_global_scale
				),
				"applied_canonical_velocity_delta_rad_s":
				applied_velocity,
				"host_target_velocity_delta_rad_s": host_delta,
				"magnitude_saturated":
				bool(correction.get("magnitude_saturated", false)),
				"slew_limited": bool(correction.get("slew_limited", false)),
				"fallback_zeroed":
				bool(correction.get("fallback_zeroed", false)),
			}
		)

	var receipt_contract_exact := (
		String(receipt.get("schema_version", ""))
		== (
			"sporespore_stability_influence_receipt_v3"
			if use_scaled_influence
			else "sporespore_stability_influence_receipt_v2"
		)
		and int(receipt.get("semantic_step", -1)) == semantic_step
		and String(receipt.get("availability", "")) == availability
		and (
			(
				use_scaled_influence
				and float(
					receipt.get("global_requested_correction_scale", NAN)
				)
				== _stability_influence_global_scale
				and bool(
					receipt.get(
						"global_scale_applied_before_magnitude_and_slew",
						false,
					)
				)
			)
			or (
				not use_scaled_influence
				and not receipt.has("global_requested_correction_scale")
			)
		)
		and bool(receipt.get("any_magnitude_saturation", false))
		== independently_any_magnitude_saturation
		and bool(receipt.get("any_slew_limiting", false))
		== independently_any_slew_limiting
		and bool(receipt.get("fallback_applied", false)) == (not available)
		and bool(
			receipt.get(
				"fallback_bypasses_slew_to_reach_zero",
				false,
			)
		)
		== (not available)
		and bool(
			receipt.get(
				"corrections_are_bounded_contributions_not_complete_actuation",
				false,
			)
		)
		and not bool(receipt.get("adapter_actuation_applied", true))
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
	)
	if not receipt_contract_exact:
		mismatch_count += 1
		limiter_mismatch_count += 1
	_contribution_previous_semantic_step = semantic_step
	_contribution_previous_applied_corrections = []
	for correction_value in applied_corrections:
		var correction: Dictionary = correction_value
		_contribution_previous_applied_corrections.append(
			{
				"actuator_id": String(correction.get("actuator_id", "")),
				"applied_position_delta_rad":
				float(correction.get("applied_position_delta_rad", NAN)),
				"applied_velocity_delta_rad_s":
				float(correction.get("applied_velocity_delta_rad_s", NAN)),
			}
		)
	var ok := mismatch_count == 0
	return {
		"ok": ok,
		"failure_code": "" if ok else "CONTRIBUTION_INFLUENCE_MISMATCH",
		"support_mode":
		(
			"available"
			if available
			else ("unavailable" if observation_unavailable else "infeasible")
		),
		"v3_available": available,
		"upstream_infeasible": upstream_infeasible,
		"unavailable": observation_unavailable,
		"untyped": false,
		"mismatch_count": mismatch_count,
		"limiter_mismatch_count": limiter_mismatch_count,
		"inactive_zero_mismatch_count": inactive_zero_mismatch_count,
		"influence_output_count": applied_corrections.size(),
		"fallback_zero_output_count": fallback_zero_output_count,
		"inactive_hard_zero_transition_count":
		inactive_hard_zero_transition_count,
		"profile_input_clamped_count": profile_input_clamped_count,
		"profile_conversion_failure_count":
		profile_conversion_failure_count,
		"nonzero_active_command_count": nonzero_active_command_count,
		"slew_limited_output_count": slew_limited_output_count,
		"magnitude_saturated_output_count":
		magnitude_saturated_output_count,
		"maximum_absolute_proposed_velocity_rad_s":
		maximum_absolute_proposed_velocity_rad_s,
		"maximum_absolute_profile_input_torque_nm":
		maximum_absolute_profile_input_torque_nm,
		"maximum_absolute_applied_velocity_rad_s":
		maximum_absolute_applied_velocity_rad_s,
		"maximum_absolute_host_delta_rad_s":
		maximum_absolute_host_delta_rad_s,
		"stability_influence_operation":
		(
			"bound_stability_influence_v3_json"
			if use_scaled_influence
			else "bound_stability_influence_v2_json"
		),
		"global_requested_correction_scale":
		_stability_influence_global_scale,
		"maximum_limiter_reconstruction_error":
		maximum_limiter_reconstruction_error,
		"influence_receipt": receipt,
		"ordered_contributions": ordered_contributions,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}


static func _contribution_shadow_failure(
	code: String,
	outcome: String,
) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"support_mode": outcome,
		"v3_available": false,
		"upstream_infeasible": false,
		"unavailable": outcome == "unavailable",
		"untyped": outcome == "untyped",
		"mismatch_count": 1,
		"limiter_mismatch_count": 0,
		"inactive_zero_mismatch_count": 0,
		"ordered_v3_command_count": 0,
		"active_support_command_count": 0,
		"inactive_contact_command_count": 0,
		"influence_output_count": 0,
		"fallback_zero_output_count": 0,
		"inactive_hard_zero_transition_count": 0,
		"profile_input_clamped_count": 0,
		"profile_conversion_failure_count": 0,
		"stability_policy_id": "",
		"feedback_request_nonzero": false,
		"nonzero_active_command_count": 0,
		"slew_limited_output_count": 0,
		"magnitude_saturated_output_count": 0,
		"full_v3_v2_compared_actuator_count": 0,
		"maximum_full_v3_v2_torque_error_nm": 0.0,
		"maximum_active_oracle_torque_error_nm": 0.0,
		"maximum_absolute_commanded_torque_nm": 0.0,
		"maximum_absolute_profile_input_torque_nm": 0.0,
		"maximum_absolute_proposed_velocity_rad_s": 0.0,
		"maximum_absolute_applied_velocity_rad_s": 0.0,
		"maximum_absolute_host_delta_rad_s": 0.0,
		"maximum_limiter_reconstruction_error": 0.0,
		"stability_influence_operation": "",
		"global_requested_correction_scale": 0.0,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}


func _joint_mapping_kinematics(
	morphology: Dictionary,
	limbs: Array,
	support_point_by_contact_id: Dictionary,
) -> Dictionary:
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var actuator_by_id: Dictionary = {}
	for actuator_value in morphology_spec.get("actuators", []):
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator.get("actuator_id", ""))] = actuator
	var limb_spec_by_joint_id: Dictionary = {}
	for limb_value in morphology_spec.get("limbs", []):
		var limb_spec: Dictionary = limb_value
		for joint_id_value in limb_spec.get("ordered_joint_ids", []):
			limb_spec_by_joint_id[String(joint_id_value)] = limb_spec
	var live_limb_by_id: Dictionary = {}
	for limb_value in limbs:
		var live_limb: Dictionary = limb_value
		live_limb_by_id[String(live_limb.get("limb_id", ""))] = live_limb

	var ordered_kinematics: Array = []
	for actuator_id_value in morphology.get("ordered_actuator_ids", []):
		var actuator_id := String(actuator_id_value)
		if not actuator_by_id.has(actuator_id):
			return {
				"ok": false,
				"failure_code": "JOINT_MAPPING_ACTUATOR_MISSING:%s" % actuator_id,
			}
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var joint_id := String(actuator.get("joint_id", ""))
		if not limb_spec_by_joint_id.has(joint_id):
			return {
				"ok": false,
				"failure_code": "JOINT_MAPPING_LIMB_SPEC_MISSING:%s" % joint_id,
			}
		var limb_spec: Dictionary = limb_spec_by_joint_id[joint_id]
		var limb_id := String(limb_spec.get("limb_id", ""))
		if not live_limb_by_id.has(limb_id):
			return {
				"ok": false,
				"failure_code": "JOINT_MAPPING_LIVE_LIMB_MISSING:%s" % limb_id,
			}
		var live_limb: Dictionary = live_limb_by_id[limb_id]
		var role := "hip_pitch" if joint_id.ends_with("_hip") else "knee_pitch"
		var joint_state: Dictionary = {}
		for state_value in live_limb.get("joint_states", []):
			var state: Dictionary = state_value
			if String(state.get("role", "")) == role:
				joint_state = state
				break
		if joint_state.is_empty():
			return {
				"ok": false,
				"failure_code": "JOINT_MAPPING_STATE_MISSING:%s" % joint_id,
			}
		var contact_ids: Array = limb_spec.get("ordered_contact_site_ids", [])
		if contact_ids.size() != 1:
			return {
				"ok": false,
				"failure_code": "JOINT_MAPPING_CONTACT_CARDINALITY:%s" % limb_id,
			}
		var contact_id := String(contact_ids[0])
		var endpoint: Vector3 = (
			support_point_by_contact_id[contact_id]
			if support_point_by_contact_id.has(contact_id)
			else (live_limb["foot"] as RigidBody3D).global_position
		)
		var parent: RigidBody3D = joint_state["parent"]
		var axis_world := (
			parent.global_basis
			* (joint_state["axis_parent_local"] as Vector3)
		).normalized()
		ordered_kinematics.append(
			{
				"actuator_id": actuator_id,
				"contact_site_id": contact_id,
				"joint_anchor_world_m":
				_vector(parent.to_global(joint_state["anchor_parent_local"])),
				"joint_axis_world_unit": _unit_vector_dictionary_binary64(axis_world),
				"endpoint_world_m": _vector(endpoint),
			}
		)
	return {
		"ok": true,
		"failure_code": "",
		"ordered_kinematics": ordered_kinematics,
	}


static func _mapping_infeasible(
	code: String,
	qualified_contact_ids: Array[String],
) -> Dictionary:
	return {
		"ok": true,
		"attempted": true,
		"mapping_available": false,
		"infeasible": true,
		"outcome_code": code,
		"qualified_contact_ids": qualified_contact_ids,
		"compared_actuator_count": 0,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _mapping_failure(
	code: String,
	qualified_contact_ids: Array[String],
) -> Dictionary:
	return {
		"ok": false,
		"attempted": true,
		"mapping_available": false,
		"infeasible": false,
		"outcome_code": code,
		"failure_code": code,
		"qualified_contact_ids": qualified_contact_ids,
		"compared_actuator_count": 0,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _typed_envelope_code(prefix: String, envelope: Dictionary) -> String:
	return "%s:%s:%s" % [
		prefix,
		String(envelope.get("failure_code", "UNKNOWN")),
		String(envelope.get("detail", "")),
	]


func _stability_body_by_id(torso: RigidBody3D, limbs: Array) -> Dictionary:
	if torso == null:
		return {"ok": false, "failure_code": "STABILITY_TORSO_MISSING"}
	var body_by_id := {"torso": torso}
	for limb_value in limbs:
		if typeof(limb_value) != TYPE_DICTIONARY:
			return {"ok": false, "failure_code": "STABILITY_LIMB_INVALID"}
		var limb: Dictionary = limb_value
		var limb_id := String(limb.get("limb_id", ""))
		var upper: RigidBody3D = limb.get("upper")
		var foot: RigidBody3D = limb.get("foot")
		if limb_id.is_empty() or upper == null or foot == null:
			return {"ok": false, "failure_code": "STABILITY_LIMB_BODY_MISSING"}
		body_by_id["%s_upper" % limb_id] = upper
		body_by_id["%s_distal" % limb_id] = foot
	return {"ok": true, "failure_code": "", "body_by_id": body_by_id}


func _stability_contact_state(
	contact_id: String,
	limb: Dictionary,
	floor: StaticBody3D,
) -> Dictionary:
	var foot: RigidBody3D = limb.get("foot")
	if foot == null:
		return {
			"ok": false,
			"failure_code": "STABILITY_CONTACT_FOOT_MISSING:%s" % contact_id,
		}
	var matching_samples: Array[Dictionary] = []
	var observed_samples: Variant = limb.get("native_qualified_contact_samples", foot.get("latest_semantic_contact_samples"))
	if typeof(observed_samples) == TYPE_ARRAY:
		for sample_value in observed_samples:
			if typeof(sample_value) != TYPE_DICTIONARY:
				continue
			var sample: Dictionary = sample_value
			if (
				String(sample.get("local_shape_id", "")) == _foot_shape_id(limb)
				and String(sample.get("counterparty_id", "")) == "floor"
				and int(sample.get("local_shape_index", -1)) >= 0
				and int(sample.get("collider_shape_index", -1)) >= 0
			):
				matching_samples.append(sample)
	if matching_samples.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"qualified": false,
			"contact":
			{
				"contact_site_id": contact_id,
				"presence": false,
				"bears_support": false,
				"point_world_m": null,
				"normal_world_unit": null,
				"surface_relative_velocity_world_m_s": null,
				"material_id": "godot_jolt_fixture_material",
				"adapter_id": "godot_jolt_gdextension",
				"engine_contact_ids": [],
			},
		}
	var mean_point := Vector3.ZERO
	var mean_normal := Vector3.ZERO
	var mean_relative_velocity := Vector3.ZERO
	var engine_contact_ids: Array[String] = []
	for sample in matching_samples:
		var point: Variant = sample.get("local_position_world_m")
		var normal: Variant = sample.get("local_normal_world_unit")
		var relative_velocity: Variant = sample.get("relative_velocity_world_m_s")
		if (
			typeof(point) != TYPE_VECTOR3
			or typeof(normal) != TYPE_VECTOR3
			or typeof(relative_velocity) != TYPE_VECTOR3
			or not (point as Vector3).is_finite()
			or not (normal as Vector3).is_finite()
			or not (relative_velocity as Vector3).is_finite()
		):
			return {
				"ok": false,
				"failure_code": "STABILITY_CONTACT_GEOMETRY_INVALID:%s" % contact_id,
			}
		mean_point += point as Vector3
		mean_normal += normal as Vector3
		mean_relative_velocity += relative_velocity as Vector3
		var engine_contact_id := (
			"%s_local_shape_%d_%s_shape_%d"
			% [
				String(foot.name),
				int(sample["local_shape_index"]),
				String(sample["counterparty_id"]),
				int(sample["collider_shape_index"]),
			]
		)
		if not engine_contact_ids.has(engine_contact_id):
			engine_contact_ids.append(engine_contact_id)
	var sample_count := float(matching_samples.size())
	mean_point /= sample_count
	mean_relative_velocity /= sample_count
	if mean_normal.length_squared() <= 1.0e-12:
		return {
			"ok": false,
			"failure_code": "STABILITY_CONTACT_NORMAL_DEGENERATE:%s" % contact_id,
		}
	mean_normal = mean_normal.normalized()
	engine_contact_ids.sort()
	if limb.has("native_qualified_contact"):
		engine_contact_ids.assign(limb["native_qualified_contact"]["provenance"]["engine_contact_ids"])
	var bearing := _foot_bears_floor(limb, floor) and mean_normal.dot(Vector3.UP) >= 0.5
	return {
		"ok": true,
		"failure_code": "",
		"qualified": bearing,
		"point_world_m": mean_point,
		"contact":
		{
			"contact_site_id": contact_id,
			"presence": true,
			"bears_support": bearing,
			"point_world_m": _vector(mean_point),
			"normal_world_unit": _unit_vector_dictionary_binary64(mean_normal),
			"surface_relative_velocity_world_m_s": _vector(mean_relative_velocity),
			"material_id": "godot_jolt_fixture_material",
			"adapter_id": "godot_jolt_gdextension",
			"engine_contact_ids": engine_contact_ids,
		},
	}


func _record_stability_shadow(result: Dictionary) -> void:
	_stability_shadow_attempt_count += 1
	if bool(result.get("observation_available", false)):
		_stability_shadow_available_count += 1
	else:
		_stability_shadow_unavailable_count += 1
	if not bool(result.get("ok", false)):
		_stability_shadow_mismatch_count += 1
		var code := String(result.get("failure_code", "STABILITY_SHADOW_UNKNOWN_FAILURE"))
		if (
			not code.is_empty()
			and not _stability_shadow_failure_codes.has(code)
			and _stability_shadow_failure_codes.size() < 20
		):
			_stability_shadow_failure_codes.append(code)
	for field_value in (result.get("absolute_error_by_field", {}) as Dictionary).keys():
		var field := String(field_value)
		_stability_shadow_maximum_error_by_field[field] = maxf(
			float(_stability_shadow_maximum_error_by_field.get(field, 0.0)),
			float((result["absolute_error_by_field"] as Dictionary)[field]),
		)
	_record_joint_mapping_shadow(result.get("joint_mapping_shadow", {}))
	_record_stability_contribution_shadow(
		result.get("stability_contribution_shadow", {})
	)


func _record_joint_mapping_shadow(result: Dictionary) -> void:
	if result.is_empty() or not bool(result.get("attempted", false)):
		return
	_mapping_shadow_attempt_count += 1
	var outcome_code := String(result.get("outcome_code", "MAPPING_OUTCOME_UNTYPED"))
	if (
		not _mapping_shadow_outcome_codes.has(outcome_code)
		and _mapping_shadow_outcome_codes.size() < 40
	):
		_mapping_shadow_outcome_codes.append(outcome_code)
	if bool(result.get("mapping_available", false)):
		_mapping_shadow_available_count += 1
		_mapping_shadow_compared_actuator_count += int(
			result.get("compared_actuator_count", 0)
		)
		_mapping_shadow_maximum_absolute_torque_error_nm = maxf(
			_mapping_shadow_maximum_absolute_torque_error_nm,
			float(result.get("maximum_absolute_torque_error_nm", 0.0)),
		)
		_mapping_shadow_maximum_absolute_commanded_torque_nm = maxf(
			_mapping_shadow_maximum_absolute_commanded_torque_nm,
			float(result.get("maximum_absolute_commanded_torque_nm", 0.0)),
		)
	elif bool(result.get("infeasible", false)):
		_mapping_shadow_infeasible_count += 1
	else:
		_mapping_shadow_unavailable_count += 1
	if not bool(result.get("ok", false)):
		_mapping_shadow_mismatch_count += maxi(
			int(result.get("mismatch_count", 0)),
			1,
		)
		var failure_code := String(
			result.get("failure_code", "MAPPING_SHADOW_UNKNOWN_FAILURE")
		)
		if (
			not _mapping_shadow_failure_codes.has(failure_code)
			and _mapping_shadow_failure_codes.size() < 20
		):
			_mapping_shadow_failure_codes.append(failure_code)


func _record_stability_contribution_shadow(result: Dictionary) -> void:
	if result.is_empty():
		return
	_contribution_attempt_count += 1
	match String(result.get("support_mode", "untyped")):
		"full":
			_contribution_full_support_attempt_count += 1
		"partial":
			_contribution_partial_support_attempt_count += 1
		"infeasible":
			_contribution_upstream_infeasible_count += 1
		"unavailable":
			_contribution_unavailable_count += 1
		_:
			_contribution_untyped_count += 1
	if bool(result.get("v3_available", false)):
		_contribution_available_count += 1
	_contribution_ordered_command_count += int(
		result.get("ordered_v3_command_count", 0)
	)
	_contribution_active_command_count += int(
		result.get("active_support_command_count", 0)
	)
	_contribution_inactive_command_count += int(
		result.get("inactive_contact_command_count", 0)
	)
	_contribution_influence_output_count += int(
		result.get("influence_output_count", 0)
	)
	_contribution_fallback_zero_output_count += int(
		result.get("fallback_zero_output_count", 0)
	)
	_contribution_inactive_hard_zero_transition_count += int(
		result.get("inactive_hard_zero_transition_count", 0)
	)
	_contribution_profile_input_clamped_count += int(
		result.get("profile_input_clamped_count", 0)
	)
	_contribution_profile_conversion_failure_count += int(
		result.get("profile_conversion_failure_count", 0)
	)
	if bool(result.get("feedback_request_nonzero", false)):
		_contribution_feedback_nonzero_attempt_count += 1
	_contribution_nonzero_active_command_count += int(
		result.get("nonzero_active_command_count", 0)
	)
	_contribution_slew_limited_output_count += int(
		result.get("slew_limited_output_count", 0)
	)
	_contribution_magnitude_saturated_output_count += int(
		result.get("magnitude_saturated_output_count", 0)
	)
	_contribution_full_v3_v2_compared_count += int(
		result.get("full_v3_v2_compared_actuator_count", 0)
	)
	_contribution_limiter_mismatch_count += int(
		result.get("limiter_mismatch_count", 0)
	)
	_contribution_inactive_zero_mismatch_count += int(
		result.get("inactive_zero_mismatch_count", 0)
	)
	_contribution_maximum_full_v3_v2_torque_error_nm = maxf(
		_contribution_maximum_full_v3_v2_torque_error_nm,
		float(result.get("maximum_full_v3_v2_torque_error_nm", 0.0)),
	)
	_contribution_maximum_active_oracle_torque_error_nm = maxf(
		_contribution_maximum_active_oracle_torque_error_nm,
		float(result.get("maximum_active_oracle_torque_error_nm", 0.0)),
	)
	_contribution_maximum_absolute_commanded_torque_nm = maxf(
		_contribution_maximum_absolute_commanded_torque_nm,
		float(result.get("maximum_absolute_commanded_torque_nm", 0.0)),
	)
	_contribution_maximum_absolute_profile_input_torque_nm = maxf(
		_contribution_maximum_absolute_profile_input_torque_nm,
		float(
			result.get(
				"maximum_absolute_profile_input_torque_nm",
				0.0,
			)
		),
	)
	_contribution_maximum_absolute_proposed_velocity_rad_s = maxf(
		_contribution_maximum_absolute_proposed_velocity_rad_s,
		float(
			result.get(
				"maximum_absolute_proposed_velocity_rad_s",
				0.0,
			)
		),
	)
	_contribution_maximum_absolute_applied_velocity_rad_s = maxf(
		_contribution_maximum_absolute_applied_velocity_rad_s,
		float(result.get("maximum_absolute_applied_velocity_rad_s", 0.0)),
	)
	_contribution_maximum_absolute_host_delta_rad_s = maxf(
		_contribution_maximum_absolute_host_delta_rad_s,
		float(result.get("maximum_absolute_host_delta_rad_s", 0.0)),
	)
	_contribution_maximum_limiter_reconstruction_error = maxf(
		_contribution_maximum_limiter_reconstruction_error,
		float(result.get("maximum_limiter_reconstruction_error", 0.0)),
	)
	if not bool(result.get("ok", false)):
		_contribution_mismatch_count += maxi(
			int(result.get("mismatch_count", 0)),
			1,
		)
		var failure_code := String(
			result.get(
				"failure_code",
				"CONTRIBUTION_SHADOW_UNKNOWN_FAILURE",
			)
		)
		if (
			not failure_code.is_empty()
			and not _contribution_failure_codes.has(failure_code)
			and _contribution_failure_codes.size() < 20
		):
			_contribution_failure_codes.append(failure_code)


func _stability_shadow_failure(
	code: String,
	stability_state: Dictionary = {},
) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"observation_available": false,
		"unavailable_reason": code,
		"state_emitted": not stability_state.is_empty(),
		"stability_state": stability_state.duplicate(true),
		"comparison_performed": false,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
		"physical_balance_recovery": false,
		"physical_acceptance_authority": false,
	}


func _apply_scheduled_phase_offset_if_due(semantic_step: int) -> Dictionary:
	if not _phase_offset_synchronization_scheduled:
		return {"ok": true, "failure_code": ""}
	if _phase_offset_application_count == 1:
		if semantic_step == _phase_offset_activation_semantic_step:
			return _failure("ADAPTER_PHASE_OFFSET_SYNCHRONIZATION_REPEATED")
		return {"ok": true, "failure_code": ""}
	if semantic_step < _phase_offset_activation_semantic_step:
		return {"ok": true, "failure_code": ""}
	if semantic_step > _phase_offset_activation_semantic_step:
		return _failure(
			"ADAPTER_PHASE_OFFSET_SYNCHRONIZATION_MISSED",
			"%d>%d" % [semantic_step, _phase_offset_activation_semantic_step],
		)
	var pending_updates: Array[Dictionary] = []
	var minimum_raw_gait_step := 0
	var minimum_initialized := false
	for limb_memory_value in _memory.get("ordered_limb_memory", []):
		if typeof(limb_memory_value) != TYPE_DICTIONARY:
			return _failure("ADAPTER_PHASE_OFFSET_MEMORY_INVALID")
		var limb_memory: Dictionary = limb_memory_value
		var limb_id := String(limb_memory.get("limb_id", ""))
		if limb_id.is_empty():
			return _failure("ADAPTER_PHASE_OFFSET_MEMORY_LIMB_ID_INVALID")
		var raw_gait_step := (
			int(limb_memory.get("gait_step", 0))
			+ _requested_phase_offset_ticks
		)
		pending_updates.append(
			{
				"limb_memory": limb_memory,
				"limb_id": limb_id,
				"raw_gait_step": raw_gait_step,
			}
		)
		if not minimum_initialized or raw_gait_step < minimum_raw_gait_step:
			minimum_raw_gait_step = raw_gait_step
			minimum_initialized = true
	if pending_updates.size() != 4:
		return _failure(
			"ADAPTER_PHASE_OFFSET_LIMB_CARDINALITY_MISMATCH",
			str(pending_updates.size()),
		)
	## gait_step is a monotonic nonnegative clock in the public Rust schema,
	## while a perturbation is a signed cyclic phase shift. If the signed shift
	## would underflow, move every limbâ€”not only the underflowing oneâ€”into the
	## same equivalent cycle epoch. A common whole-cycle shift preserves all
	## relative phases and contact-gate skew.
	var representation_shift_ticks := 0
	while minimum_raw_gait_step + representation_shift_ticks < 0:
		representation_shift_ticks += GAIT_CYCLE_STEPS
	for update_value in pending_updates:
		var update: Dictionary = update_value
		var updated_memory: Dictionary = update["limb_memory"]
		updated_memory["gait_step"] = (
			int(update["raw_gait_step"]) + representation_shift_ticks
		)
	_phase_offset_representation_shift_ticks = representation_shift_ticks
	_phase_offset_application_count = 1
	_phase_offset_synchronized_limb_count = pending_updates.size()
	return {
		"ok": true,
		"failure_code": "",
		"receipt": _phase_offset_synchronization_receipt(),
	}


func _phase_offset_synchronization_receipt() -> Dictionary:
	return {
		"schema_version": "sporespore_sdk_phase_offset_synchronization_receipt_v2",
		"scheduled": _phase_offset_synchronization_scheduled,
		"requested_offset_ticks": _requested_phase_offset_ticks,
		"activation_semantic_step": _phase_offset_activation_semantic_step,
		"application_count": _phase_offset_application_count,
		"synchronized_limb_count": _phase_offset_synchronized_limb_count,
		"gait_step_representation": "nonnegative_u64_cycle_epoch",
		"cycle_steps": GAIT_CYCLE_STEPS,
		"common_representation_shift_ticks":
		_phase_offset_representation_shift_ticks,
	}


func _authority_failure(code: String, joint_state_by_joint_id: Dictionary) -> Dictionary:
	_record_failure(code)
	for state_value in joint_state_by_joint_id.values():
		if typeof(state_value) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = state_value
		var joint: HingeJoint3D = state.get("joint")
		if joint == null:
			continue
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		_native_safe_disable_application_count += 1
	return {
		"ok": false,
		"failure_code": code,
		"applied_command_count": 0,
		"safe_disable_application_count": _native_safe_disable_application_count,
		"actuation_authority": _actuation_authority_enabled,
		"physical_acceptance_authority": false,
	}


func _stability_overlay_failure(
	code: String,
	legacy_command_context_by_joint_id: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	_record_failure(code)
	_stability_overlay_failure_count += 1
	if (
		not _stability_overlay_failure_codes.has(code)
		and _stability_overlay_failure_codes.size() < 20
	):
		_stability_overlay_failure_codes.append(code)
	var restored_base_command_count := 0
	if _is_balanced_wave_policy(_controller_policy_id):
		for state_value in joint_state_by_joint_id.values():
			if typeof(state_value) != TYPE_DICTIONARY:
				continue
			var state: Dictionary = state_value
			var joint: HingeJoint3D = state.get("joint")
			if joint == null:
				continue
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
			_native_safe_disable_application_count += 1
		return {
			"schema_version": "sporespore_godot_jolt_stability_overlay_receipt_v1",
			"ok": false,
			"failure_code": code,
			"applied_command_count": 0,
			"restored_base_command_count": 0,
			"safe_disable_application_count":
			_native_safe_disable_application_count,
			"whole_step_base_restored": false,
			"base_command_source": "portable_controller_ordered_commands",
			"motor_target_velocity_only": true,
			"direct_body_write_count": 0,
			"actuation_authority": _actuation_authority_enabled,
			"physical_influence": false,
			"physical_balance_recovery": false,
			"locomotion_robustness": false,
			"physical_acceptance_authority": false,
		}
	for joint_id_value in legacy_command_context_by_joint_id.keys():
		var joint_id := String(joint_id_value)
		if not joint_state_by_joint_id.has(joint_id):
			continue
		var legacy_context: Variant = legacy_command_context_by_joint_id[joint_id]
		var joint_state: Variant = joint_state_by_joint_id[joint_id]
		if (
			typeof(legacy_context) != TYPE_DICTIONARY
			or typeof(joint_state) != TYPE_DICTIONARY
		):
			continue
		var base_target_velocity_rad_s := float(
			(legacy_context as Dictionary).get("target_velocity_rad_s", NAN)
		)
		var joint: HingeJoint3D = (joint_state as Dictionary).get("joint")
		if joint == null or not is_finite(base_target_velocity_rad_s):
			continue
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
			_host_real_t(base_target_velocity_rad_s),
		)
		restored_base_command_count += 1
	return {
		"schema_version": "sporespore_godot_jolt_stability_overlay_receipt_v1",
		"ok": false,
		"failure_code": code,
		"applied_command_count": 0,
		"restored_base_command_count": restored_base_command_count,
		"whole_step_base_restored":
		(
			not legacy_command_context_by_joint_id.is_empty()
			and restored_base_command_count
			== legacy_command_context_by_joint_id.size()
		),
		"motor_target_velocity_only": true,
		"direct_body_write_count": 0,
		"actuation_authority": _actuation_authority_enabled,
		"physical_influence": false,
		"physical_balance_recovery": false,
		"locomotion_robustness": false,
		"physical_acceptance_authority": false,
	}


func _configure_phase_progression_mode(mode: String) -> Dictionary:
	if not ["clocked", "contact_gated"].has(mode):
		return _failure("ADAPTER_PHASE_PROGRESSION_MODE_INVALID", mode)
	if mode == _requested_phase_progression_mode:
		return {"ok": true, "failure_code": ""}
	for limb_memory_value in _memory.get("ordered_limb_memory", []):
		var limb_memory: Dictionary = limb_memory_value
		var transition_advance_steps := (
			1 if mode == "contact_gated" and _requested_phase_progression_mode == "clocked" else 0
		)
		if mode == "contact_gated":
			limb_memory["evidence_gait_step_limit"] = (
				int(limb_memory.get("gait_step", 0))
				+ transition_advance_steps
				+ CANDIDATE35_EVIDENCE_GAIT_STEPS
			)
		elif _requested_phase_progression_mode != "contact_gated":
			limb_memory["evidence_gait_step_limit"] = null
	_requested_phase_progression_mode = mode
	return {"ok": true, "failure_code": ""}


func _build_step_request(
	semantic_step: int,
	gait_amplitude: float,
	phase_progression_mode: String,
	torso: RigidBody3D,
	limbs: Array,
	floor: StaticBody3D,
	requested_heading_command: Dictionary = {},
) -> Dictionary:
	var limb_by_id: Dictionary = {}
	var joint_state_by_sdk_id: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		limb_by_id[limb_id] = limb
		for joint_state_value in limb["joint_states"]:
			var joint_state: Dictionary = joint_state_value
			var suffix := "hip" if String(joint_state["role"]) == "hip_pitch" else "knee"
			joint_state_by_sdk_id["%s_%s" % [limb_id, suffix]] = joint_state
	var morphology: Dictionary = _compiled["morphology"]
	var joints: Array = []
	for joint_id_value in morphology["ordered_joint_ids"]:
		var joint_id := String(joint_id_value)
		if not joint_state_by_sdk_id.has(joint_id):
			return _failure("ADAPTER_JOINT_MAPPING_MISSING", joint_id)
		var state: Dictionary = joint_state_by_sdk_id[joint_id]
		joints.append(
			{
				"joint_id": joint_id,
				"position_rad": _joint_angle_rad(state),
				"velocity_rad_s": _joint_rate_rad_s(state),
				"anchor_error_m": _joint_anchor_error_m(state),
				"validity":
				{
					"position": true,
					"velocity": true,
					"anchor_error": true,
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		var limb_id := contact_id.trim_suffix("_foot")
		if not limb_by_id.has(limb_id):
			return _failure("ADAPTER_CONTACT_MAPPING_MISSING", contact_id)
		contacts.append(_walking_contact_observation(contact_id, limb_by_id[limb_id], floor))
	var canonical_orientation_result := _canonical_orientation_xyzw(torso.global_basis)
	if not bool(canonical_orientation_result.get("ok", false)):
		return _failure("ADAPTER_BASE_ORIENTATION_INVALID")
	var canonical_orientation: Dictionary = canonical_orientation_result["orientation_xyzw"]
	var heading_command_result := compile_heading_offset_command(
		_canonical_initial_heading_rad,
		semantic_step,
		requested_heading_command,
	)
	if not bool(heading_command_result.get("ok", false)):
		return heading_command_result
	var task_frame_origin_world_m := _initial_origin_world_m
	var task_frame_origin_receipt: Dictionary = {}
	if _task_frame_origin_policy_id != FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID:
		var origin_result := resolve_task_frame_origin_policy_step(
			_task_frame_origin_policy_id,
			_active_task_frame_origin_world_m,
			_active_task_frame_schedule_id,
			_active_task_frame_segment_id,
			_task_frame_origin_reanchor_count,
			torso.global_position,
			requested_heading_command,
		)
		if not bool(origin_result.get("ok", false)):
			return origin_result
		_active_task_frame_origin_world_m = origin_result["origin_world_m"]
		_active_task_frame_schedule_id = String(origin_result["active_schedule_id"])
		_active_task_frame_segment_id = String(origin_result["active_segment_id"])
		_task_frame_origin_reanchor_count = int(origin_result["reanchor_count"])
		task_frame_origin_world_m = _active_task_frame_origin_world_m
		task_frame_origin_receipt = (
			(origin_result["receipt"] as Dictionary).duplicate(true)
		)
	var state_frame := {
		"schema_version": "sporespore_state_frame_v1",
		"semantic_step": semantic_step,
		"sample_time_s": float(semantic_step) / float(_physics_hz),
		"base_pose_world":
		{
			"position_m": _vector(torso.global_position),
			"orientation_xyzw":
			{
				"x": float(canonical_orientation["x"]),
				"y": float(canonical_orientation["y"]),
				"z": float(canonical_orientation["z"]),
				"w": float(canonical_orientation["w"]),
			},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s": _vector(torso.linear_velocity),
			"angular_velocity_rad_s": _vector(torso.angular_velocity),
		},
		"ordered_joint_observations": joints,
		"ordered_contact_observations": contacts,
		"previous_applied_actuation": null,
		"gravity_world_m_s2": _vector(
			Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		),
		"task_frame":
		{
			"origin_world_m": _vector(task_frame_origin_world_m),
			"forward_axis_world_unit":
			_unit_vector_dictionary_binary64(_initial_forward_axis_world),
			"lateral_axis_world_unit":
			_unit_vector_dictionary_binary64(_initial_lateral_axis_world),
			"up_axis_world_unit": _unit_vector_dictionary_binary64(Vector3.UP),
			"reference_yaw_rad": _canonical_initial_heading_rad,
		},
		"adapter_capability_sha256": _adapter_capability_sha256,
	}
	var command := {
		"schema_version": "sporespore_motion_command_v2",
		"command_id": String(heading_command_result["command_id"]),
		"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
		"desired_heading_rad": float(heading_command_result["desired_heading_rad"]),
		"desired_yaw_rate_rad_s": null,
		"gait_family_id": "lateral_wave",
		"speed_class": "walk",
		"gait_amplitude": gait_amplitude,
		"phase_progression_mode": phase_progression_mode,
		"valid_from_step": semantic_step,
		"valid_through_step": semantic_step,
		"authority": "test_fixture",
	}
	var request := _controller_step_request(_memory, state_frame, command)
	if request.is_empty():
		return DevelopmentFloor.failure_v1("MISSING_SOURCE_OR_OUTSIDE_FINITE_FLOOR")
	var result := {
		"ok": true,
		"failure_code": "",
		"adapter_legacy_yaw_rad":
		atan2(
			(-torso.global_basis.z.normalized()).x,
			-(-torso.global_basis.z.normalized()).z,
		),
		"request": request,
	}
	if _controller_policy_id in [DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID, DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID, DEVELOPMENT_SMOOTH_SWING_POLICY_ID, DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID]:
		result["development_floor_source"] = _development_floor_source.duplicate(true)
	if not requested_heading_command.is_empty():
		result["heading_command_receipt"] = (
			(heading_command_result["receipt"] as Dictionary).duplicate(true)
		)
	if not task_frame_origin_receipt.is_empty():
		result["task_frame_origin_receipt"] = (
			task_frame_origin_receipt.duplicate(true)
		)
	return result


func _controller_profile_method() -> StringName:
	return (
		&"balanced_wave_policy_profile_json"
		if _is_balanced_wave_policy(_controller_policy_id)
		else &"candidate35_profile_json"
	)


func _controller_initial_memory() -> Dictionary:
	if _is_balanced_wave_policy(_controller_policy_id):
		return _call_input(
			&"balanced_wave_policy_initial_memory_json",
			{
				"schema_version":
				"sporespore_balanced_wave_policy_initial_memory_request_v1",
				"policy_id": _controller_policy_id,
				"descriptor": _descriptor,
			},
		)
	return _call_no_input(&"candidate35_initial_memory_json")


func _controller_step_method() -> StringName:
	return (
		&"balanced_wave_policy_session_step_json"
		if _is_balanced_wave_policy(_controller_policy_id)
		else &"candidate35_step_json"
	)


func _balanced_wave_expected_controller_receipt_schema() -> String:
	if _controller_policy_id == DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID:
		return DEVELOPMENT_EXTENDED_PREPARATION_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID:
		return DEVELOPMENT_INITIALIZED_ZERO_BRAKE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID:
		return DEVELOPMENT_ZERO_VELOCITY_BRAKE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID:
		return DEVELOPMENT_BOUNDED_STOP_VELOCITY_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID:
		return DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID:
		return DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID:
		return DEVELOPMENT_STARTUP_VELOCITY_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID:
		return DEVELOPMENT_REMAINING_SUPPORT_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID:
		return DEVELOPMENT_SUPPORT_HOLD_POSTURE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID:
		return DEVELOPMENT_SUPPORT_PROGRESSION_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_STANCE_LATCH_POLICY_ID:
		return DEVELOPMENT_STANCE_LATCH_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID:
		return DEVELOPMENT_UPRIGHT_STANCE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID:
		return DEVELOPMENT_ABSENT_CONTACT_REFERENCE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID:
		return DEVELOPMENT_AIRBORNE_REFERENCE_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_WAVE_VELOCITY_POLICY_ID:
		return DEVELOPMENT_WAVE_VELOCITY_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID:
		return DEVELOPMENT_REFERENCE_VELOCITY_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_SMOOTH_SWING_POLICY_ID:
		return DEVELOPMENT_SMOOTH_SWING_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID:
		return DEVELOPMENT_FEASIBLE_SUPPORT_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID:
		return DEVELOPMENT_FLOOR_SUPPORT_RECEIPT_SCHEMA
	if _controller_policy_id == DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID:
		return DEVELOPMENT_BOUNDED_SUPPORT_RECEIPT_SCHEMA
	return (
		(
			"sporespore_controller_step_receipt_v8"
			if _is_r23d29_two_swing_persistent_predictive_policy(_controller_policy_id)
			else "sporespore_controller_step_receipt_v5"
			if _is_signed_forward_velocity_policy(_controller_policy_id)
			else "sporespore_controller_step_receipt_v4"
			if _is_bw14v_policy(_controller_policy_id)
			else "sporespore_controller_step_receipt_v3"
		)
		if (
			_is_forward_velocity_foot_placement_policy(_controller_policy_id)
			or _is_bw8u_policy(_controller_policy_id)
		)
		else "sporespore_controller_step_receipt_v2"
	)


func _controller_runtime_version_method() -> StringName:
	return (
		&"balanced_wave_runtime_version"
		if _is_balanced_wave_policy(_controller_policy_id)
		else &"candidate35_runtime_version"
	)


func _controller_step_request_schema_version() -> String:
	if _controller_policy_id in [DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID]:
		return "sporespore_balanced_wave_policy_session_step_request_v3"
	if _controller_policy_id in [DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID, DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID, DEVELOPMENT_SMOOTH_SWING_POLICY_ID, DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID]:
		return "sporespore_balanced_wave_policy_session_step_request_v2"
	return (
		"sporespore_balanced_wave_policy_session_step_request_v1"
		if _is_balanced_wave_policy(_controller_policy_id)
		else "sporespore_candidate35_step_request_v1"
	)


func _controller_step_request(
	memory: Dictionary,
	state: Dictionary,
	command: Dictionary,
) -> Dictionary:
	var request := {
		"schema_version": _controller_step_request_schema_version(),
		"memory": memory,
		"state": state,
		"command": command,
	}
	if not _is_balanced_wave_policy(_controller_policy_id):
		request["descriptor"] = _descriptor
	if _controller_policy_id in [DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID, DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID, DEVELOPMENT_SMOOTH_SWING_POLICY_ID, DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID]:
		if _development_floor_source.is_empty() or not DevelopmentFloor.applicable_v1(_development_floor_source, state, _compiled["geometry"]):
			return {}
		request["floor_reference"] = _development_floor_source["floor_reference"].duplicate(true)
	return request


func bind_development_floor_source_v1(source: Dictionary, model_instance_id: String) -> Dictionary:
	if _controller_policy_id not in [DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID, DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID, DEVELOPMENT_SMOOTH_SWING_POLICY_ID, DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID, DEVELOPMENT_WAVE_VELOCITY_POLICY_ID, DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID, DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID, DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID, DEVELOPMENT_STANCE_LATCH_POLICY_ID, DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID, DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID, DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID, DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID] or not _started or _shutdown_completed or not DevelopmentFloor.verify_v1(_api, source, model_instance_id):
		return DevelopmentFloor.failure_v1("ADAPTER_SOURCE_BINDING")
	if not _development_floor_source.is_empty() and DevelopmentFloor.Transport.stringify(source) != DevelopmentFloor.Transport.stringify(_development_floor_source):
		return DevelopmentFloor.failure_v1("STATIC_SOURCE_CHANGED")
	_development_floor_source = source.duplicate(true)
	return {"ok": true}


func _is_balanced_wave_policy(policy_id: String) -> bool:
	return BALANCED_WAVE_POLICY_IDS.has(policy_id)


func _is_bw8u_policy(policy_id: String) -> bool:
	return [
		BALANCED_WAVE_BW8U_A_POLICY_ID,
		BALANCED_WAVE_BW8U_B_POLICY_ID,
		BALANCED_WAVE_BW8U_C_POLICY_ID,
		BALANCED_WAVE_BW8U_D_POLICY_ID,
	].has(policy_id)


func _is_bw14v_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_BW14V_B_POLICY_ID


func _is_bw15f_policy(policy_id: String) -> bool:
	return [
		BALANCED_WAVE_BW15F_B_POLICY_ID,
		BALANCED_WAVE_BW15F_C_POLICY_ID,
		BALANCED_WAVE_BW15F_D_POLICY_ID,
	].has(policy_id)


func _is_bw21l_policy(policy_id: String) -> bool:
	return [
		BALANCED_WAVE_BW21L_B_POLICY_ID,
		BALANCED_WAVE_BW21L_C_POLICY_ID,
		BALANCED_WAVE_BW21L_D_POLICY_ID,
	].has(policy_id)


func _is_bw23y_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_BW23Y_B_POLICY_ID


func _is_bw34y_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_BW34Y_A_POLICY_ID


func _is_r23d19_heading_aligned_path_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID


func _is_r23d21_reduced_yaw_authority_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_R23D21_REDUCED_YAW_AUTHORITY_POLICY_ID


func _is_r23d29_two_swing_persistent_predictive_policy(policy_id: String) -> bool:
	return policy_id == BALANCED_WAVE_R23D29_TWO_SWING_PERSISTENT_PREDICTIVE_POLICY_ID


func _expected_balanced_wave_memory_version(policy_id: String) -> String:
	if policy_id == DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID:
		return "sporespore_balanced_wave_recovery_extended_preparation_memory_v1"
	if policy_id == DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_initialized_zero_brake_memory_v1"
	if policy_id == DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_zero_velocity_brake_memory_v1"
	if policy_id == DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID:
		return "sporespore_balanced_wave_recovery_bounded_stop_velocity_memory_v1"
	if policy_id == DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID:
		return "sporespore_balanced_wave_recovery_extended_support_transfer_memory_v1"
	if policy_id == DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID:
		return "sporespore_balanced_wave_recovery_joint_feasible_height_memory_v1"
	if policy_id == DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID:
		return "sporespore_balanced_wave_joint_pose_entry_memory_v1"
	if policy_id == DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID:
		return "sporespore_balanced_wave_recovery_startup_reference_velocity_memory_v1"
	if policy_id == DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID:
		return "sporespore_balanced_wave_recovery_remaining_support_release_memory_v1"
	if policy_id == DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_support_hold_posture_memory_v1"
	if policy_id == DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID:
		return "sporespore_balanced_wave_recovery_support_progression_memory_v1"
	if policy_id == DEVELOPMENT_STANCE_LATCH_POLICY_ID:
		return "sporespore_balanced_wave_recovery_stance_latched_upright_memory_v1"
	if policy_id == DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_upright_stance_memory_v1"
	if policy_id == DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_absent_contact_reference_memory_v1"
	if policy_id == DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID:
		return "sporespore_balanced_wave_recovery_airborne_reference_memory_v1"
	if policy_id == DEVELOPMENT_WAVE_VELOCITY_POLICY_ID:
		return "sporespore_balanced_wave_recovery_wave_velocity_memory_v1"
	if policy_id == DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID:
		return "sporespore_balanced_wave_recovery_reference_velocity_memory_v1"
	if policy_id == DEVELOPMENT_SMOOTH_SWING_POLICY_ID:
		return "sporespore_balanced_wave_recovery_smooth_swing_memory_v1"
	if policy_id == DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID:
		return "sporespore_balanced_wave_recovery_feasible_support_memory_v1"
	if policy_id == DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID:
		return "sporespore_balanced_wave_recovery_floor_support_memory_v1"
	if policy_id == DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID:
		return "sporespore_balanced_wave_recovery_support_memory_v1"
	if _is_r23d29_two_swing_persistent_predictive_policy(policy_id):
		return BALANCED_WAVE_PERSISTENT_PREDICTIVE_GUARD_MEMORY_VERSION
	return BALANCED_WAVE_MEMORY_VERSION


func _balanced_wave_memory_schema_receipt(next_memory: Dictionary) -> Dictionary:
	var expected_version := _expected_balanced_wave_memory_version(_controller_policy_id)
	var observed_version := String(next_memory.get("schema_version", ""))
	var policy_valid := _is_balanced_wave_policy(_controller_policy_id)
	var exact := policy_valid and observed_version == expected_version
	return {
		"schema_version": BALANCED_WAVE_MEMORY_SCHEMA_RECEIPT_VERSION,
		"ok": exact,
		"failure_code": (
			"" if exact else "ADAPTER_BALANCED_WAVE_MEMORY_VERSION_MISMATCH"
		),
		"controller_policy_id": _controller_policy_id,
		"expected_memory_schema_version": expected_version,
		"observed_memory_schema_version": observed_version,
		"policy_is_balanced_wave": policy_valid,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


## Zero-world negative-control surface for the exact policy-aware memory check
## used by the live post-controller validator.
func preflight_balanced_wave_memory_schema_receipt(next_memory: Dictionary) -> Dictionary:
	return _balanced_wave_memory_schema_receipt(next_memory)


func _is_signed_forward_velocity_policy(policy_id: String) -> bool:
	return (
		_is_bw15f_policy(policy_id)
		or _is_bw21l_policy(policy_id)
		or _is_bw23y_policy(policy_id)
		or _is_bw34y_policy(policy_id)
		or _is_r23d19_heading_aligned_path_policy(policy_id)
		or _is_r23d21_reduced_yaw_authority_policy(policy_id)
		or _is_r23d29_two_swing_persistent_predictive_policy(policy_id)
	)


func _is_forward_velocity_foot_placement_policy(policy_id: String) -> bool:
	return _is_bw14v_policy(policy_id) or _is_signed_forward_velocity_policy(policy_id)


func _is_scheduled_load_transfer_policy(policy_id: String) -> bool:
	return (
		BW9L_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
		or BW10F_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
		or BW11R_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
		or BW13P_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
	)


func _is_scheduled_load_transfer_v2_policy(policy_id: String) -> bool:
	return BW10F_LOAD_TRANSFER_POLICY_IDS.has(policy_id)


func _is_scheduled_load_transfer_v3_policy(policy_id: String) -> bool:
	return (
		BW11R_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
		or BW13P_LOAD_TRANSFER_POLICY_IDS.has(policy_id)
	)


func _is_scheduled_load_transfer_typed_policy(policy_id: String) -> bool:
	return (
		_is_scheduled_load_transfer_v2_policy(policy_id)
		or _is_scheduled_load_transfer_v3_policy(policy_id)
	)


func _scheduled_load_transfer_plan_operation(policy_id: String) -> String:
	return (
		(
			"plan_scheduled_load_transfer_v3_json"
			if _is_scheduled_load_transfer_v3_policy(policy_id)
			else "plan_scheduled_load_transfer_v2_json"
		)
		if _is_scheduled_load_transfer_typed_policy(policy_id)
		else "plan_scheduled_load_transfer_v1_json"
	)


func _scheduled_load_transfer_receipt_schema_version(
	policy_id: String,
) -> String:
	return (
		(
			"sporespore_scheduled_load_transfer_receipt_v3"
			if _is_scheduled_load_transfer_v3_policy(policy_id)
			else "sporespore_scheduled_load_transfer_receipt_v2"
		)
		if _is_scheduled_load_transfer_typed_policy(policy_id)
		else "sporespore_scheduled_load_transfer_receipt_v1"
	)


func _is_stability_feedback_authority_policy(policy_id: String) -> bool:
	return (
		policy_id == P5I3C_FEEDBACK_POLICY_ID
		or _is_scheduled_load_transfer_policy(policy_id)
	)


func _is_bw13p_policy(policy_id: String) -> bool:
	return BW13P_LOAD_TRANSFER_POLICY_IDS.has(policy_id)


func _uses_stability_contribution_actuation() -> bool:
	return (
		not _stability_contribution_shadow_only_until_terminal
		and (
			_authority_scope == "stability_contribution_overlay"
			or (
				_authority_scope == "post_settle_full"
				and _is_balanced_wave_policy(_controller_policy_id)
				and _is_bw13p_policy(_stability_policy_id)
			)
		)
	)


static func native_step_transport_verification_receipt_valid_v1(
	receipt: Dictionary,
	expected_policy_id: String,
	expected_receipt_schema: String,
	expected_semantic_step: int,
	expected_controller_receipt_sha256: String = "",
) -> bool:
	var observed_keys: Array = receipt.keys()
	var expected_keys: Array = NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_KEYS.duplicate()
	observed_keys.sort()
	expected_keys.sort()
	if observed_keys != expected_keys:
		return false
	for integer_key in [
		"semantic_step",
		"raw_native_response_byte_length",
		"floating_point_measurement_field_count",
		"world_build_count",
		"solver_step_count",
	]:
		var integer_value: Variant = receipt.get(integer_key, null)
		if (
			(typeof(integer_value) != TYPE_INT and typeof(integer_value) != TYPE_FLOAT)
			or not is_finite(float(integer_value))
			or float(integer_value) != float(int(integer_value))
		):
			return false
	var controller_receipt_sha256 := String(receipt.get("controller_receipt_sha256", ""))
	var native_actuation_receipt_sha256 := String(
		receipt.get("native_actuation_receipt_sha256", "")
	)
	if (
		String(receipt.get("schema_version", ""))
		!= NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION
		or String(receipt.get("verification_version", ""))
		!= NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION
		or not bool(receipt.get("ok", false))
		or String(receipt.get("policy_id", "")) != expected_policy_id
		or int(receipt.get("semantic_step", -1)) != expected_semantic_step
		or String(receipt.get("controller_receipt_schema_version", ""))
		!= expected_receipt_schema
		or not _native_step_transport_digest_valid_v1(controller_receipt_sha256)
		or native_actuation_receipt_sha256 != controller_receipt_sha256
		or (
			not expected_controller_receipt_sha256.is_empty()
			and controller_receipt_sha256 != expected_controller_receipt_sha256
		)
		or not _native_step_transport_digest_valid_v1(
			String(receipt.get("raw_native_response_sha256", ""))
		)
		or int(receipt.get("raw_native_response_byte_length", 0)) <= 0
		or not bool(receipt.get("successful_public_envelope", false))
		or not bool(receipt.get("policy_identity_exact", false))
		or not bool(receipt.get("semantic_step_identity_exact", false))
		or not bool(receipt.get("controller_receipt_schema_exact", false))
		or not bool(receipt.get("native_canonical_receipt_digest_exact", false))
		or not bool(receipt.get("preparse_native_response_verified", false))
		or bool(receipt.get("raw_native_response_rewritten", true))
		or bool(receipt.get("post_parse_dictionary_rehash_used", true))
		or int(receipt.get("floating_point_measurement_field_count", -1)) != 0
		or int(receipt.get("world_build_count", -1)) != 0
		or int(receipt.get("solver_step_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		return false
	var declared_payload_sha256 := String(receipt.get("payload_sha256", ""))
	if not _native_step_transport_digest_valid_v1(declared_payload_sha256):
		return false
	var payload := receipt.duplicate(true)
	payload["payload_sha256"] = ""
	return CanonicalJsonScript.sha256(payload) == declared_payload_sha256


static func _native_step_transport_digest_valid_v1(value: String) -> bool:
	if not value.begins_with("sha256:") or value.length() != 71:
		return false
	const HEX_DIGITS := "0123456789abcdef"
	for index in range(7, value.length()):
		if HEX_DIGITS.find(value.substr(index, 1)) < 0:
			return false
	return true


func _call_balanced_wave_session_step_with_transport_verification(
	value: Dictionary,
	semantic_step: int,
) -> Dictionary:
	# The exact native response string stays untouched and unparsed until the
	# native verifier has independently accepted its envelope and receipt digest.
	var raw_request := JSON.stringify(value, "", true, true)
	var raw_response := String(
		_api.call(
			&"balanced_wave_policy_session_step_json",
			raw_request,
		)
	)
	var verification_response := String(
		_api.call(
			&"balanced_wave_native_step_transport_verification_json",
			raw_response,
			_controller_policy_id,
			_balanced_wave_expected_controller_receipt_schema(),
			semantic_step,
		)
	)
	var verification_value: Variant = JSON.parse_string(verification_response)
	if typeof(verification_value) != TYPE_DICTIONARY:
		if _development_native_step_failure_retention_enabled:
			return _capture_development_native_failure_v1(raw_request, raw_response, verification_response, semantic_step)
		return {
			"ok": false,
			"failure_code": "ADAPTER_NATIVE_STEP_TRANSPORT_VERIFICATION_JSON_INVALID",
			"native_step_transport_verification": {},
		}
	var verification_envelope: Dictionary = verification_value
	var receipt_value: Variant = verification_envelope.get("value", null)
	if not bool(verification_envelope.get("ok", false)) or typeof(receipt_value) != TYPE_DICTIONARY:
		if _development_native_step_failure_retention_enabled:
			return _capture_development_native_failure_v1(raw_request, raw_response, verification_response, semantic_step)
		return {
			"ok": false,
			"failure_code": "ADAPTER_NATIVE_STEP_TRANSPORT_VERIFICATION_FAILED",
			"detail": String(verification_envelope.get("failure_code", "")),
			"native_step_transport_verification": verification_envelope.duplicate(true),
		}
	var verification_receipt: Dictionary = receipt_value
	if not native_step_transport_verification_receipt_valid_v1(
		verification_receipt,
		_controller_policy_id,
		_balanced_wave_expected_controller_receipt_schema(),
		semantic_step,
	):
		if _development_native_step_failure_retention_enabled:
			return _capture_development_native_failure_v1(raw_request, raw_response, verification_response, semantic_step)
		return {
			"ok": false,
			"failure_code": "ADAPTER_NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_INVALID",
			"native_step_transport_verification": verification_receipt.duplicate(true),
		}
	var parsed: Variant = _api.call(&"decode_exact_json_v1", raw_response) if _controller_policy_id in [DEVELOPMENT_JOINT_POSE_ENTRY_POLICY_ID, DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID] else JSON.parse_string(raw_response)
	if typeof(parsed) != TYPE_DICTIONARY:
		if _development_native_step_failure_retention_enabled:
			return _capture_development_native_failure_v1(raw_request, raw_response, verification_response, semantic_step)
		return {
			"ok": false,
			"failure_code": "ADAPTER_NATIVE_STEP_RESPONSE_POST_VERIFICATION_PARSE_INVALID",
			"native_step_transport_verification": verification_receipt.duplicate(true),
		}
	var result: Dictionary = parsed
	if _development_native_step_failure_retention_enabled:
		var output_value: Variant = result.get("value")
		if output_value is Dictionary and output_value.get("actuation") is Dictionary and output_value.actuation.get("safe_no_actuation") == true:
			return _capture_development_native_failure_v1(raw_request, raw_response, verification_response, semantic_step)
	result["native_step_transport_verification"] = verification_receipt.duplicate(true)
	return result


func _capture_development_native_failure_v1(request_raw: String, response_raw: String,
	verification_raw: String, semantic_step: int) -> Dictionary:
	return DevelopmentNativeFailure.capture_v1(_api, request_raw, response_raw,
		verification_raw, _controller_policy_id, _balanced_wave_expected_controller_receipt_schema(),
		semantic_step, _compiled.get("morphology", {}))


func _call_input(method: StringName, value: Dictionary) -> Dictionary:
	# Godot's default JSON precision can move a normalized quaternion outside
	# the core's 1e-9 unit-norm contract. Preserve all available Variant
	# precision at the adapter boundary instead of weakening core validation.
	var response := String(_api.call(method, JSON.stringify(value, "", true, true)))
	var parsed: Variant = _api.call(&"decode_exact_json_v1", response) if _controller_policy_id in [DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID] else JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _call_no_input(method: StringName) -> Dictionary:
	var response := String(_api.call(method))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func preflight_transport_execution() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null:
		return _transport_failure("ADAPTER_EXTENSION_RESOURCE_UNAVAILABLE")
	if not ClassDB.class_exists(NATIVE_CLASS_NAME):
		return _transport_failure("ADAPTER_NATIVE_CLASS_UNAVAILABLE")
	var api: Object = ClassDB.instantiate(NATIVE_CLASS_NAME)
	if api == null:
		return _transport_failure("ADAPTER_NATIVE_CLASS_INSTANTIATION_FAILED")
	return _validate_transport_api(api)


static func _validate_transport_api(api: Object) -> Dictionary:
	if not api.has_method("transport_execution_version"):
		return _transport_failure("ADAPTER_TRANSPORT_VERSION_METHOD_MISSING")
	if not api.has_method("transport_execution_contract_json"):
		return _transport_failure("ADAPTER_TRANSPORT_CONTRACT_METHOD_MISSING")
	var actual_version := String(api.call("transport_execution_version"))
	if actual_version != TRANSPORT_EXECUTION_VERSION:
		return _transport_failure(
			"ADAPTER_TRANSPORT_EXECUTION_VERSION_MISMATCH",
			"expected=%s actual=%s" % [TRANSPORT_EXECUTION_VERSION, actual_version],
		)
	var contract_value: Variant = JSON.parse_string(
		String(api.call("transport_execution_contract_json"))
	)
	if typeof(contract_value) != TYPE_DICTIONARY:
		return _transport_failure("ADAPTER_TRANSPORT_CONTRACT_JSON_INVALID")
	var contract: Dictionary = contract_value
	if (
		String(contract.get("schema_version", "")) != TRANSPORT_CONTRACT_SCHEMA_VERSION
		or String(contract.get("execution_version", "")) != TRANSPORT_EXECUTION_VERSION
		or String(contract.get("input_transport", "")) != "normalized_json_utf8"
		or String(contract.get("output_transport", "")) != "json_utf8"
		or (
			int(contract.get("initial_output_capacity_bytes", -1))
			!= TRANSPORT_INITIAL_OUTPUT_CAPACITY_BYTES
		)
		or (
			int(contract.get("normal_path_native_invocation_count", -1))
			!= TRANSPORT_NORMAL_PATH_NATIVE_INVOCATION_COUNT
		)
		or (
			int(contract.get("overflow_retry_limit", -1))
			!= TRANSPORT_OVERFLOW_RETRY_LIMIT
		)
		or int(contract.get("world_build_count", -1)) != 0
		or bool(contract.get("physical_acceptance_authority", true))
	):
		return _transport_failure("ADAPTER_TRANSPORT_CONTRACT_MISMATCH")
	if not api.has_method("controller_session_execution_version"):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_VERSION_METHOD_MISSING")
	if not api.has_method("controller_session_execution_contract_json"):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_CONTRACT_METHOD_MISSING")
	if not api.has_method("balanced_wave_policy_session_create_json"):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_CREATE_METHOD_MISSING")
	if not api.has_method("balanced_wave_policy_session_step_json"):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_STEP_METHOD_MISSING")
	if not api.has_method("balanced_wave_policy_session_destroy_json"):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_DESTROY_METHOD_MISSING")
	if not api.has_method("balanced_wave_policy_initial_memory_json"):
		return _transport_failure("ADAPTER_POLICY_MEMORY_INITIALIZER_METHOD_MISSING")
	if not api.has_method("balanced_wave_native_step_transport_verification_version"):
		return _transport_failure("ADAPTER_NATIVE_STEP_VERIFICATION_VERSION_METHOD_MISSING")
	if not api.has_method("balanced_wave_native_step_transport_verification_contract_json"):
		return _transport_failure("ADAPTER_NATIVE_STEP_VERIFICATION_CONTRACT_METHOD_MISSING")
	if not api.has_method("balanced_wave_native_step_transport_verification_json"):
		return _transport_failure("ADAPTER_NATIVE_STEP_VERIFICATION_METHOD_MISSING")
	var actual_session_version := String(
		api.call("controller_session_execution_version")
	)
	if actual_session_version != CONTROLLER_SESSION_EXECUTION_VERSION:
		return _transport_failure(
			"ADAPTER_CONTROLLER_SESSION_EXECUTION_VERSION_MISMATCH",
			"expected=%s actual=%s"
			% [CONTROLLER_SESSION_EXECUTION_VERSION, actual_session_version],
		)
	var session_contract_value: Variant = JSON.parse_string(
		String(api.call("controller_session_execution_contract_json"))
	)
	if typeof(session_contract_value) != TYPE_DICTIONARY:
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_CONTRACT_JSON_INVALID")
	var session_contract: Dictionary = session_contract_value
	if (
		String(session_contract.get("schema_version", ""))
		!= CONTROLLER_SESSION_CONTRACT_SCHEMA_VERSION
		or String(session_contract.get("execution_version", ""))
		!= CONTROLLER_SESSION_EXECUTION_VERSION
		or String(session_contract.get("create_request_schema_version", ""))
		!= "sporespore_balanced_wave_policy_session_create_request_v1"
		or String(session_contract.get("initial_memory_request_schema_version", ""))
		!= "sporespore_balanced_wave_policy_initial_memory_request_v1"
		or String(session_contract.get("step_request_schema_version", ""))
		!= "sporespore_balanced_wave_policy_session_step_request_v1"
		or String(session_contract.get("controller_memory_initialization", ""))
		!= "explicit_named_policy"
		or String(session_contract.get("controller_memory_transport", ""))
		!= "explicit_every_step"
		or not bool(session_contract.get("compiled_morphology_reused", false))
		or not bool(session_contract.get("controller_profile_reused", false))
		or not bool(session_contract.get("process_local_opaque_handle", false))
		or not bool(session_contract.get("automatic_destroy_on_adapter_release", false))
		or int(session_contract.get("world_build_count", -1)) != 0
		or bool(session_contract.get("physical_acceptance_authority", true))
	):
		return _transport_failure("ADAPTER_CONTROLLER_SESSION_CONTRACT_MISMATCH")
	var actual_verification_version := String(
		api.call("balanced_wave_native_step_transport_verification_version")
	)
	if actual_verification_version != NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION:
		return _transport_failure(
			"ADAPTER_NATIVE_STEP_VERIFICATION_VERSION_MISMATCH",
			"expected=%s actual=%s"
			% [NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION, actual_verification_version],
		)
	var verification_contract_value: Variant = JSON.parse_string(
		String(api.call("balanced_wave_native_step_transport_verification_contract_json"))
	)
	if typeof(verification_contract_value) != TYPE_DICTIONARY:
		return _transport_failure("ADAPTER_NATIVE_STEP_VERIFICATION_CONTRACT_JSON_INVALID")
	var verification_contract: Dictionary = verification_contract_value
	if (
		String(verification_contract.get("schema_version", ""))
		!= NATIVE_STEP_TRANSPORT_VERIFICATION_CONTRACT_SCHEMA_VERSION
		or String(verification_contract.get("verification_version", ""))
		!= NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION
		or String(verification_contract.get("receipt_schema_version", ""))
		!= NATIVE_STEP_TRANSPORT_VERIFICATION_RECEIPT_SCHEMA_VERSION
		or String(verification_contract.get("verification_input", ""))
		!= "exact_native_session_step_response_utf8_before_host_parse"
		or String(verification_contract.get("controller_receipt_digest_implementation", ""))
		!= "sporespore_core_native_canonical_json_v1"
		or String(verification_contract.get("raw_response_digest_implementation", ""))
		!= "sha256_exact_utf8_bytes"
		or bool(verification_contract.get("raw_response_rewritten", true))
		or bool(verification_contract.get("post_parse_dictionary_rehash_used", true))
		or int(verification_contract.get("floating_point_measurement_field_count", -1)) != 0
		or int(verification_contract.get("world_build_count", -1)) != 0
		or int(verification_contract.get("solver_step_count", -1)) != 0
		or bool(verification_contract.get("physical_acceptance_authority", true))
	):
		return _transport_failure("ADAPTER_NATIVE_STEP_VERIFICATION_CONTRACT_MISMATCH")
	return {
		"ok": true,
		"failure_code": "",
		"transport_execution_version": TRANSPORT_EXECUTION_VERSION,
		"transport_execution_contract": contract.duplicate(true),
		"transport_execution_contract_sha256": CanonicalJsonScript.sha256(contract),
		"controller_session_execution_version": CONTROLLER_SESSION_EXECUTION_VERSION,
		"controller_session_execution_contract": session_contract.duplicate(true),
		"controller_session_execution_contract_sha256": (
			CanonicalJsonScript.sha256(session_contract)
		),
		"native_step_transport_verification_version": (
			NATIVE_STEP_TRANSPORT_VERIFICATION_VERSION
		),
		"native_step_transport_verification_contract": verification_contract.duplicate(true),
		"native_step_transport_verification_contract_sha256": (
			CanonicalJsonScript.sha256(verification_contract)
		),
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _transport_failure(code: String, detail: String = "") -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"transport_execution_version": "",
		"transport_execution_contract": {},
		"transport_execution_contract_sha256": "",
		"controller_session_execution_version": "",
		"controller_session_execution_contract": {},
		"controller_session_execution_contract_sha256": "",
		"native_step_transport_verification_version": "",
		"native_step_transport_verification_contract": {},
		"native_step_transport_verification_contract_sha256": "",
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func _record_failure(code: String) -> void:
	if code.is_empty():
		return
	if not _failure_codes.has(code) and _failure_codes.size() < 20:
		_failure_codes.append(code)


func _failure(code: String, detail: String = "") -> Dictionary:
	if (
		not _started
		and not _controller_session_receipt.is_empty()
		and _api != null
		and _api.has_method("balanced_wave_policy_session_destroy_json")
	):
		_api.call("balanced_wave_policy_session_destroy_json")
		_controller_session_receipt.clear()
	if not _started and _start_failure_code.is_empty():
		_start_failure_code = code
	_record_failure(code if detail.is_empty() else "%s:%s" % [code, detail])
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _legacy_joint_id_for_actuator(actuator_id: String) -> String:
	if not actuator_id.ends_with("_motor"):
		return ""
	var joint_id := actuator_id.trim_suffix("_motor")
	if joint_id.ends_with("_hip"):
		return "%s.hip_pitch" % joint_id.trim_suffix("_hip")
	if joint_id.ends_with("_knee"):
		return "%s.knee_pitch" % joint_id.trim_suffix("_knee")
	return ""


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


static func _joint_anchor_error_m(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_anchor := parent.to_global(state["anchor_parent_local"])
	var child_anchor := child.to_global(state["anchor_child_local"])
	return parent_anchor.distance_to(child_anchor)


## Default stays exact for the normal launcher and all historical routes.
## Recovery successors bind their existing CollisionShape metadata explicitly.
static func _foot_shape_id(limb: Dictionary) -> String:
	return String(limb.get("contact_shape_id", "foot"))


static func _walking_contact_observation(contact_id: String, limb: Dictionary, floor: StaticBody3D) -> Dictionary:
	if limb.has("native_qualified_contact"):
		return (limb["native_qualified_contact"] as Dictionary).duplicate(true)
	var bearing := _foot_bears_floor(limb, floor)
	var foot: RigidBody3D = limb["foot"]
	var engine_contact_ids: Array[String] = []
	var observed_samples: Variant = foot.get("latest_semantic_contact_samples")
	if typeof(observed_samples) == TYPE_ARRAY:
		for sample_value in observed_samples:
			if typeof(sample_value) != TYPE_DICTIONARY:
				continue
			var sample: Dictionary = sample_value
			if (String(sample.get("local_shape_id", "")) == _foot_shape_id(limb)
				and String(sample.get("counterparty_id", "")) == "floor"
				and int(sample.get("local_shape_index", -1)) >= 0
				and int(sample.get("collider_shape_index", -1)) >= 0):
				engine_contact_ids.append("%s_local_shape_%d_%s_shape_%d" % [String(foot.name),
					int(sample["local_shape_index"]), String(sample["counterparty_id"]), int(sample["collider_shape_index"])])
	engine_contact_ids.sort()
	return {"contact_site_id": contact_id, "presence": bearing, "bears_support": bearing, "normal_load_n": null,
		"provenance": {"adapter_id": "godot_jolt_gdextension", "engine_contact_ids": engine_contact_ids,
			"aggregation_rule_id": "semantic_floor_bearing", "quality": "qualified_bearing"}}


static func _foot_bears_floor(limb: Dictionary, floor: StaticBody3D) -> bool:
	if limb.has("native_qualified_contact"):
		return bool(limb["native_qualified_contact"]["bears_support"])
	var foot: RigidBody3D = limb["foot"]
	if (
		floor.has_meta("lab_body_id")
		and foot.has_method("has_semantic_contact")
		and foot.get("semantic_contact_callback_count") != null
		and int(foot.get("semantic_contact_callback_count")) > 0
	):
		return bool(
			foot.call(
				"has_semantic_contact",
				_foot_shape_id(limb),
				String(floor.get_meta("lab_body_id")),
			)
		)
	return floor in foot.get_colliding_bodies()


static func _canonical_orientation_xyzw(host_basis: Basis) -> Dictionary:
	# Preserve the exact float-backed host forward vector used by the legacy
	# oracle, but perform the matrix-to-quaternion conversion in binary64.
	# Calling Godot's get_rotation_quaternion() would round the quaternion back
	# through real_t and measurably change projected heading.
	var forward_x := -float(host_basis.z.x)
	var forward_y := -float(host_basis.z.y)
	var forward_z := -float(host_basis.z.z)
	var forward_norm := sqrt(
		forward_x * forward_x + forward_y * forward_y + forward_z * forward_z
	)
	var up_x := float(host_basis.y.x)
	var up_y := float(host_basis.y.y)
	var up_z := float(host_basis.y.z)
	if (
		not is_finite(forward_norm)
		or forward_norm <= 1.0e-12
		or not is_finite(up_x)
		or not is_finite(up_y)
		or not is_finite(up_z)
	):
		return {"ok": false}
	forward_x /= forward_norm
	forward_y /= forward_norm
	forward_z /= forward_norm
	var forward_up_projection := forward_x * up_x + forward_y * up_y + forward_z * up_z
	up_x -= forward_up_projection * forward_x
	up_y -= forward_up_projection * forward_y
	up_z -= forward_up_projection * forward_z
	var up_norm := sqrt(up_x * up_x + up_y * up_y + up_z * up_z)
	if not is_finite(up_norm) or up_norm <= 1.0e-12:
		return {"ok": false}
	up_x /= up_norm
	up_y /= up_norm
	up_z /= up_norm
	var right_x := forward_y * up_z - forward_z * up_y
	var right_y := forward_z * up_x - forward_x * up_z
	var right_z := forward_x * up_y - forward_y * up_x
	var right_norm := sqrt(right_x * right_x + right_y * right_y + right_z * right_z)
	if not is_finite(right_norm) or right_norm <= 1.0e-12:
		return {"ok": false}
	right_x /= right_norm
	right_y /= right_norm
	right_z /= right_norm
	# Recompute up from the orthonormal right/forward pair so all three matrix
	# columns belong to the same binary64 rotation.
	up_x = right_y * forward_z - right_z * forward_y
	up_y = right_z * forward_x - right_x * forward_z
	up_z = right_x * forward_y - right_y * forward_x

	# Rotation-matrix columns are canonical forward (+X), up (+Y), right (+Z).
	var m00 := forward_x
	var m01 := up_x
	var m02 := right_x
	var m10 := forward_y
	var m11 := up_y
	var m12 := right_y
	var m20 := forward_z
	var m21 := up_z
	var m22 := right_z
	var trace := m00 + m11 + m22
	var quaternion_x: float
	var quaternion_y: float
	var quaternion_z: float
	var quaternion_w: float
	if trace > 0.0:
		var scale := sqrt(trace + 1.0) * 2.0
		quaternion_w = 0.25 * scale
		quaternion_x = (m21 - m12) / scale
		quaternion_y = (m02 - m20) / scale
		quaternion_z = (m10 - m01) / scale
	elif m00 > m11 and m00 > m22:
		var scale := sqrt(1.0 + m00 - m11 - m22) * 2.0
		quaternion_w = (m21 - m12) / scale
		quaternion_x = 0.25 * scale
		quaternion_y = (m01 + m10) / scale
		quaternion_z = (m02 + m20) / scale
	elif m11 > m22:
		var scale := sqrt(1.0 + m11 - m00 - m22) * 2.0
		quaternion_w = (m02 - m20) / scale
		quaternion_x = (m01 + m10) / scale
		quaternion_y = 0.25 * scale
		quaternion_z = (m12 + m21) / scale
	else:
		var scale := sqrt(1.0 + m22 - m00 - m11) * 2.0
		quaternion_w = (m10 - m01) / scale
		quaternion_x = (m02 + m20) / scale
		quaternion_y = (m12 + m21) / scale
		quaternion_z = 0.25 * scale
	var norm := sqrt(
		quaternion_x * quaternion_x
		+ quaternion_y * quaternion_y
		+ quaternion_z * quaternion_z
		+ quaternion_w * quaternion_w
	)
	if not is_finite(norm) or norm <= 1.0e-12:
		return {"ok": false}
	return {
		"ok": true,
		"orientation_xyzw":
		{
			"x": quaternion_x / norm,
			"y": quaternion_y / norm,
			"z": quaternion_z / norm,
			"w": quaternion_w / norm,
		},
	}


static func _wrap_angle(angle_rad: float) -> float:
	return fposmod(angle_rad + PI, TAU) - PI


static func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _host_real_t(value: float) -> float:
	var host_values := PackedFloat32Array([value])
	return float(host_values[0])


static func _dictionary_vector(value: Variant) -> Vector3:
	var vector: Dictionary = value
	return Vector3(float(vector["x"]), float(vector["y"]), float(vector["z"]))


static func _unit_vector_dictionary_binary64(value: Vector3) -> Dictionary:
	# Vector3 components cross Godot's real_t boundary before reaching this
	# adapter. Re-normalize their scalar values in binary64 so the strict core
	# unit-vector contract does not confuse host quantization with bad geometry.
	var x := float(value.x)
	var y := float(value.y)
	var z := float(value.z)
	var length := sqrt(x * x + y * y + z * z)
	return {"x": x / length, "y": y / length, "z": z / length}
