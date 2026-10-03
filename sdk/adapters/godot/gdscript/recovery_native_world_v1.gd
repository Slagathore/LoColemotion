class_name SporeGodotRecoveryNativeWorldV1
extends RefCounted
# gdlint: disable=max-line-length

## Genuine Godot/Jolt world construction and source-only recovery sampling.
##
## This module owns native geometry, initialization, contact classification,
## direct-body-state energy terms, and instrumented Jolt motor telemetry.  It
## does not choose policy actions or evaluate recovery success.  The sibling
## recovery_native_route_v1.gd module remains the only portable-runtime seam.

const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const TaskSource := preload("res://sdk/adapters/godot/gdscript/recovery_task_source_selector_v1.gd")
const DetectionFrameContacts := preload("res://sdk/adapters/godot/gdscript/recovery_detection_frame_contacts_v1.gd")
const CanonicalOwnershipL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd"
)
const SemanticContactRigidBodyScript := preload(
	"res://scripts/lab/mechanics/semantic_contact_rigid_body.gd"
)
const RotationAwareEnergyLedgerScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_rotation_aware_energy_ledger_v1.gd"
)
const ContiguousBoundaryTransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)

const ROUTE_ID := "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1"
const WORLD_ROUTE_ID := "sporespore_qsdk_r24d57_godot_jolt_recovery_native_world_v1"
const R144_COMPLETE_ENERGY_ROUTE_ID := (
	"sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1"
)
const R144_COMPLETE_ENERGY_WORLD_ROUTE_ID := (
	"sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_native_world_v1"
)
const R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID := (
	"godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1"
)
const R148_COMPLETE_ENERGY_ROUTE_ID := (
	"sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
)
const R148_COMPLETE_ENERGY_WORLD_ROUTE_ID := (
	"sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_native_world_v1"
)
const R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1"
)
const R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID := (
	"godot_jolt_r24d151_commissioned_discrete_staging_complete_energy_partition_authority_v1"
)
const R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID := (
	"godot_jolt_r24d152_route_aware_discrete_staging_application_provenance_v1"
)
const R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID := (
	"godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
)
const ADAPTER_ID := "sporespore_godot_jolt_adapter"
const ENGINE_ID := "godot_jolt4_7"
const TASK_ID := "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
const SEMANTICS_ID := "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
const ACTUATOR_PROFILE_ID := "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
const ACTUATOR_PROFILE_SHA256 := (
	"sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
const RECOVERY_MORPHOLOGY_ID := "qsdk_r24_recovery_s169_v1"
const RECOVERY_DESCRIPTOR_SHA256 := (
	"sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"
)
const RECOVERY_MORPHOLOGY_SPEC_SHA256 := (
	"sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
)
const RECOVERY_CONTROLLER_ID := "sporespore_exact_s169_prone_to_standing_controller_v1"
const RECOVERY_CONTROLLER_V2_ID := "sporespore_exact_s169_prone_to_standing_controller_v2"
const RECOVERY_CONTROLLER_V3_ID := "sporespore_exact_s169_prone_to_standing_controller_v3"
const RECOVERY_CONTROLLER_V4_ID := "sporespore_exact_s169_prone_to_standing_controller_v4"
const RECOVERY_CONTROLLER_V5_ID := "sporespore_exact_s169_prone_to_standing_controller_v5"
const RECOVERY_CONTROLLER_V6_ID := "sporespore_exact_s169_prone_to_standing_controller_v6"
const OUTER_STEP_DURATION_S := 1.0 / 120.0
const FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1"
)
const FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d87_centered_source_measured_joint_work_v1"
)
const GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d94_source_measured_native_angular_velocity_guarded_joint_impulse_v1"
)
const GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d94_guarded_centered_source_measured_joint_work_v1"
)
const NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d96_source_measured_nested_native_angular_velocity_guarded_joint_impulse_v1"
)
const NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d96_nested_guarded_centered_source_measured_joint_work_v1"
)
const COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d99_component_norm_nested_guarded_joint_impulse_v1"
)
const COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d99_component_norm_nested_guarded_centered_joint_work_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d100_refinement_safe_component_norm_nested_guarded_joint_impulse_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d100_refinement_safe_component_norm_nested_guarded_centered_joint_work_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d103_order_neutral_population_guarded_joint_impulse_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d103_order_neutral_population_guarded_centered_joint_work_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d107_order_neutral_joint_target_monotone_population_guarded_joint_impulse_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d107_order_neutral_joint_target_monotone_population_guarded_centered_joint_work_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_joint_impulse_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID := (
	"godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_centered_joint_work_v1"
)
const R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1"
)
const R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID := (
	"godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1"
)
const R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID := (
	"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1"
)
const R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID := (
	"godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
)
const R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID := (
	"godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1"
)
const R144_PARTITION_NUMERICAL_TERM_COUNT := 13
const NATIVE_FLOAT32_EPSILON := 1.1920928955078125e-7
const GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d94_guarded_force_based_joint_impulse_projection_v1"
)
const GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d94_guarded_force_based_joint_work_projection_v1"
)
const NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d96_nested_guarded_force_based_joint_impulse_projection_v1"
)
const NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d96_nested_guarded_force_based_joint_work_projection_v1"
)
const COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d99_component_norm_nested_guarded_force_based_joint_impulse_projection_v1"
)
const COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d99_component_norm_nested_guarded_force_based_joint_work_projection_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_guarded_force_based_joint_work_projection_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARD_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d103_order_neutral_population_guard_projection_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d103_order_neutral_population_guarded_force_based_joint_impulse_projection_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d103_order_neutral_population_guarded_force_based_joint_work_projection_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARD_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d107_joint_target_monotone_population_guard_projection_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d107_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d107_joint_target_monotone_population_guarded_force_based_joint_work_projection_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARD_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guard_projection_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guarded_force_based_joint_work_projection_v1"
)
const NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d94_immediate_native_angular_velocity_readback_v1"
)
const NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d96_nested_immediate_native_angular_velocity_readback_v1"
)
const COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d99_component_norm_nested_immediate_native_angular_velocity_readback_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_immediate_native_angular_velocity_readback_v1"
)
const ORDER_NEUTRAL_POPULATION_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d103_order_neutral_population_immediate_native_angular_velocity_readback_v1"
)
const ORDER_NEUTRAL_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d103_order_neutral_population_joint_angular_velocity_readback_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d107_joint_target_monotone_population_joint_angular_velocity_readback_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA := (
	"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_joint_angular_velocity_readback_v1"
)
const FORCE_BASED_VELOCITY_ERROR_GAIN_NM_S_PER_RAD := 10.0
const FORCE_BASED_AXIS_PARENT_LOCAL := Vector3.BACK
const FORCE_BASED_AXIS_UNIT_LENGTH_SQUARED_TOLERANCE := (
	8.0 * 1.1920928955078125e-7
)
const FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS := 16
const QUATERNION_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d66_godot_quaternion_scalar_projection_v1"
)
const QUATERNION_DIAGNOSTIC_SCHEMA := (
	"sporespore_qsdk_r24d66_godot_quaternion_scalar_diagnostic_v1"
)
const CORE_QUATERNION_NORM_SQUARED_TOLERANCE := 1.0e-9
const COLLISION_MARGIN_M := 0.002
const CONTACT_CLASSIFICATION_TOLERANCE_M := 1.0e-6
const INITIALIZER_READBACK_TOLERANCE := 1.0e-8
const INITIALIZER_NATIVE_PROJECTION_PROFILE_ID := (
	"godot_4_7_real_t_basis_relative_angle_projection_v1"
)
const GODOT_INITIAL_RELATIVE_JOINT_LIMIT_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d83_godot_initial_relative_joint_limit_projection_v1"
)
const GODOT_INITIAL_RELATIVE_JOINT_LIMIT_PROJECTION_ID := (
	"godot_4_7_binary32_outward_initial_relative_joint_limit_projection_v1"
)
const CANONICAL_TO_GODOT_HOST_JOINT_SIGN := -1.0
const RECOVERY_FLOOR_COLLISION_LAYER := 1
const RECOVERY_FLOOR_COLLISION_MASK := 2
const RECOVERY_ROBOT_COLLISION_LAYER := 2
const RECOVERY_ROBOT_COLLISION_MASK := 1
const GODOT_RECOVERY_COLLISION_FILTER_SCHEMA := (
	"sporespore_qsdk_r24d83_godot_recovery_collision_filter_v1"
)
const TELEMETRY_IMPULSE_TOLERANCE_NMS := 1.0e-6
const TELEMETRY_NET_WORK_IDENTITY_TOLERANCE_J := 1.0e-12
const STRICT_HOST_IMPULSE_CAP_PROJECTION_ID := (
	"godot_jolt_binary32_floor_strict_published_impulse_cap_v1"
)
const STRICT_MOTOR_TELEMETRY_CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d68_godot_native_motor_telemetry_contract_v2"
)
const STRICT_ACTUATOR_BUDGET_DIAGNOSTIC_SCHEMA := (
	"sporespore_qsdk_r24d68_strict_actuator_budget_diagnostic_v1"
)
const NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID := (
	"godot_jolt_binary32_native_effective_impulse_limit_inverse_projection_v1"
)
const NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_projection_v1"
)
const SOLVED_CONTACT_TELEMETRY_SCHEMA := (
	"sporespore.godot_jolt_solved_contact_telemetry.v1"
)
const SOLVED_CONTACT_TELEMETRY_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_solved_contact_telemetry_v1"
)
const SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d71_godot_solved_contact_telemetry_contract_v1"
)
const SOLVED_CONTACT_SOURCE_SCHEMA := (
	"sporespore_qsdk_r24d71_godot_exact_solved_contact_source_v1"
)
const CONTACT_SOURCE_RETENTION_SCHEMA := (
	"sporespore_qsdk_r24d75_godot_contact_source_retention_v1"
)
const SOURCE_COMPONENT_RECEIPTS_SCHEMA := (
	"sporespore_qsdk_r24d75_godot_source_component_receipts_v1"
)
const JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH := (
	"physics/jolt_physics_3d/limits/max_angular_velocity"
)
const JOLT_ANGULAR_VELOCITY_RUNTIME_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d93_godot_jolt_angular_velocity_runtime_projection_v1"
)
const BODY_ANGULAR_VELOCITY_LIMIT_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d93_godot_body_angular_velocity_limit_receipt_v1"
)
const HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND := 1.1920928955078125e-7
const NATIVE_ANGULAR_VELOCITY_GUARD_ERROR_MULTIPLIER := 1024.0
const NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d94_godot_jolt_angular_velocity_guard_limit_projection_v1"
)
const NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d94_godot_jolt_paired_angular_impulse_guard_projection_v1"
)
const NATIVE_ANGULAR_VELOCITY_INNER_PROJECTION_TARGET_SCHEMA := (
	"sporespore_qsdk_r24d96_godot_jolt_angular_velocity_inner_projection_target_v1"
)
const NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d96_godot_jolt_nested_paired_angular_impulse_guard_projection_v1"
)
const COMPONENT_NORM_ANGULAR_VELOCITY_LIMIT_RELATION_SCHEMA := (
	"sporespore_qsdk_r24d99_component_norm_angular_velocity_limit_relation_v1"
)
const COMPONENT_NORM_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d99_godot_jolt_component_norm_paired_angular_impulse_guard_projection_v1"
)
const COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d99_godot_jolt_component_norm_nested_paired_angular_impulse_guard_projection_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d100_godot_jolt_refinement_safe_component_norm_paired_angular_impulse_guard_projection_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d100_godot_jolt_refinement_safe_component_norm_nested_paired_angular_impulse_guard_projection_v1"
)
const COMPONENT_NORM_NUMERIC_PREDICATE_ID := (
	"godot_vector3_components_widened_to_float64_euclidean_squared_norm_v1"
)
const COMPONENT_NORM_GUARD_REFINEMENT_DIAGNOSTIC_SCHEMA := (
	"sporespore_qsdk_r24d100_component_norm_guard_refinement_diagnostic_v1"
)
const GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d97_godot_guarded_force_based_applied_scale_projection_v1"
)
const COMPONENT_NORM_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d99_godot_component_norm_guarded_applied_scale_projection_v1"
)
const REFINEMENT_SAFE_COMPONENT_NORM_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_guarded_applied_scale_projection_v1"
)
const ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_applied_scale_projection_v1"
)
const JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_applied_scale_projection_v1"
)
const JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_applied_scale_projection_v1"
)
const NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS := 64
const SOLVED_CONTACT_TELEMETRY_FIELDS := [
	"schema",
	"profile_id",
	"capture_space_step_sequence",
	"read_space_step_sequence",
	"captured_during_active_step",
	"snapshot_is_current_space_step",
	"reported_manifold_count",
	"reported_contact_point_count",
	"exact_manifold_count",
	"exact_contact_point_count",
	"missing_manifold_count",
	"ccd_only_manifold_count",
	"point_count_mismatch_count",
	"nonfinite_impulse_count",
	"complete",
]

const ORDERED_ACTUATOR_IDS := [
	"front_left_hip_motor",
	"front_left_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
]
const ORDERED_JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const ORDERED_PARENT_BODY_IDS := [
	"torso",
	"front_left_upper",
	"torso",
	"front_right_upper",
	"torso",
	"rear_left_upper",
	"torso",
	"rear_right_upper",
]
const ORDERED_CHILD_BODY_IDS := [
	"front_left_upper",
	"front_left_distal",
	"front_right_upper",
	"front_right_distal",
	"rear_left_upper",
	"rear_left_distal",
	"rear_right_upper",
	"rear_right_distal",
]
const ORDERED_CONTACT_SITE_IDS := [
	"front_left_foot",
	"front_right_foot",
	"rear_left_foot",
	"rear_right_foot",
]
const ORDERED_BODY_IDS := [
	"torso",
	"front_left_upper",
	"front_left_distal",
	"front_right_upper",
	"front_right_distal",
	"rear_left_upper",
	"rear_left_distal",
	"rear_right_upper",
	"rear_right_distal",
]
const ORDERED_PUBLISHED_CAPS_NMS := [
	0.05362625170687301,
	0.4567500054836273,
	0.05362625170687301,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
]
const ORDERED_NEAREST_BINARY32_CAPS_NMS := [
	0.053626250475645065,
	0.4567500054836273,
	0.053626250475645065,
	0.4567500054836273,
	0.05637374892830849,
	0.4567500054836273,
	0.05637374892830849,
	0.4567500054836273,
]
const ORDERED_STRICT_HOST_CAPS_NMS := [
	0.053626250475645065,
	0.4567500054836273,
	0.053626250475645065,
	0.4567500054836273,
	0.05637374520301819,
	0.4567500054836273,
	0.05637374520301819,
	0.4567500054836273,
]
const ORDERED_STRICT_HOST_CAPS_BINARY32_HEX := [
	"0x3d5ba733",
	"0x3ee9db23",
	"0x3d5ba733",
	"0x3ee9db23",
	"0x3d66e828",
	"0x3ee9db23",
	"0x3d66e828",
	"0x3ee9db23",
]


## Read the effective runtime fail-safe from the selected Godot/Jolt process.
## The value is engine provenance, not a campaign-authored behavior threshold.
static func jolt_angular_velocity_limit_runtime_projection_v1() -> Dictionary:
	var setting_present := ProjectSettings.has_setting(
		JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH
	)
	var setting_value: Variant = ProjectSettings.get_setting(
		JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH
	)
	var setting_type := typeof(setting_value)
	if (
		not setting_present
		or (setting_type != TYPE_FLOAT and setting_type != TYPE_INT)
	):
		return _failure(
			"QSDK_R24D93_JOLT_ANGULAR_VELOCITY_RUNTIME_SETTING_INVALID",
			{
				"setting_path": JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH,
				"setting_present": setting_present,
				"setting_variant_type": type_string(setting_type),
			},
		)
	var maximum := float(setting_value)
	if not is_finite(maximum) or maximum <= 0.0:
		return _failure(
			"QSDK_R24D93_JOLT_ANGULAR_VELOCITY_RUNTIME_LIMIT_INVALID",
			{
				"setting_path": JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH,
				"effective_max_angular_velocity_rad_s": maximum,
			},
		)
	return {
		"schema_version": JOLT_ANGULAR_VELOCITY_RUNTIME_PROJECTION_SCHEMA,
		"ok": true,
		"setting_path": JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH,
		"setting_present": true,
		"setting_variant_type": type_string(setting_type),
		"effective_max_angular_velocity_rad_s": maximum,
		"provenance_source": "ProjectSettings.get_setting",
		"threshold_kind": "engine_runtime_safety_limit_not_campaign_acceptance_threshold",
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Validate and retain the complete ordered body angular-velocity population for
## one native step. Exact equality with the engine limit passes; any exceedance,
## non-finite value, stale callback, missing body, or runtime-limit drift fails.
static func body_angular_velocity_limit_receipt_v1(
	runtime_projection_value: Variant,
	ordered_body_measurements_value: Variant,
	semantic_step: int,
) -> Dictionary:
	if not (runtime_projection_value is Dictionary):
		return _failure("QSDK_R24D93_ANGULAR_LIMIT_RUNTIME_PROJECTION_MISSING")
	var runtime_projection: Dictionary = runtime_projection_value
	var maximum := float(runtime_projection.get("effective_max_angular_velocity_rad_s", NAN))
	if (
		String(runtime_projection.get("schema_version", ""))
		!= JOLT_ANGULAR_VELOCITY_RUNTIME_PROJECTION_SCHEMA
		or not bool(runtime_projection.get("ok", false))
		or String(runtime_projection.get("setting_path", ""))
		!= JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH
		or not bool(runtime_projection.get("setting_present", false))
		or not bool(runtime_projection.get("source_measurement", false))
		or not is_finite(maximum)
		or maximum <= 0.0
		or semantic_step < 1
	):
		return _failure("QSDK_R24D93_ANGULAR_LIMIT_RUNTIME_PROJECTION_INVALID")
	if not (ordered_body_measurements_value is Array):
		return _failure("QSDK_R24D93_ANGULAR_LIMIT_BODY_POPULATION_MISSING")
	var ordered_body_measurements: Array = ordered_body_measurements_value
	if ordered_body_measurements.size() != ORDERED_BODY_IDS.size():
		return _failure(
			"QSDK_R24D93_ANGULAR_LIMIT_BODY_POPULATION_INVALID",
			{
				"expected_body_count": ORDERED_BODY_IDS.size(),
				"observed_body_count": ordered_body_measurements.size(),
			},
		)

	var retained_measurements: Array = []
	var exceeded_body_ids: Array = []
	var maximum_observed_speed := 0.0
	for index in ORDERED_BODY_IDS.size():
		var row_value: Variant = ordered_body_measurements[index]
		if not (row_value is Dictionary):
			return _failure(
				"QSDK_R24D93_ANGULAR_LIMIT_BODY_MEASUREMENT_INVALID:%d" % index
			)
		var row: Dictionary = row_value
		var body_id := String(row.get("body_id", ""))
		var angular_value: Variant = row.get("angular_velocity_world_rad_s")
		if (
			body_id != String(ORDERED_BODY_IDS[index])
			or int(row.get("callback_sequence", -1)) != semantic_step
			or not bool(row.get("source_measurement", false))
			or not (angular_value is Vector3)
		):
			return _failure(
				"QSDK_R24D93_ANGULAR_LIMIT_BODY_MEASUREMENT_INVALID:%s" % body_id
			)
		var angular: Vector3 = angular_value
		var speed := angular.length()
		if not angular.is_finite() or not is_finite(speed):
			return _failure(
				"QSDK_R24D93_ANGULAR_LIMIT_BODY_NONFINITE:%s" % body_id
			)
		var within_limit := speed <= maximum
		maximum_observed_speed = maxf(maximum_observed_speed, speed)
		if not within_limit:
			exceeded_body_ids.append(body_id)
		retained_measurements.append(
			{
				"body_id": body_id,
				"callback_sequence": semantic_step,
				"angular_velocity_world_rad_s": _vector_json(angular),
				"angular_speed_rad_s": speed,
				"effective_max_angular_velocity_rad_s": maximum,
				"within_effective_runtime_limit": within_limit,
				"source_measurement": true,
			}
		)

	var receipt := {
		"schema_version": BODY_ANGULAR_VELOCITY_LIMIT_RECEIPT_SCHEMA,
		"ok": exceeded_body_ids.is_empty(),
		"semantic_step": semantic_step,
		"runtime_limit_projection": runtime_projection.duplicate(true),
		"comparison_rule": "angular_speed_norm_lte_effective_runtime_limit",
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_body_measurements": retained_measurements,
		"body_measurement_count": retained_measurements.size(),
		"within_limit_count": retained_measurements.size() - exceeded_body_ids.size(),
		"maximum_observed_angular_speed_rad_s": maximum_observed_speed,
		"effective_max_angular_velocity_rad_s": maximum,
		"exceeded_body_ids": exceeded_body_ids,
		"native_engine_health_passed": exceeded_body_ids.is_empty(),
		"source_measurement": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not exceeded_body_ids.is_empty():
		return _failure(
			"QSDK_R24D93_ANGULAR_VELOCITY_LIMIT_EXCEEDED",
			{"receipt": receipt},
		)
	return receipt


## Derive a representational operating boundary below Jolt's effective native
## fail-safe. The 1024-epsilon separation is an engineering guard for the two
## independently implemented binary32 matrix/vector paths (Godot Basis and
## Jolt inverse inertia), not a behavior threshold or an engine-limit change.
static func native_angular_velocity_guard_limit_projection_v1(
	runtime_projection_value: Variant,
) -> Dictionary:
	if not (runtime_projection_value is Dictionary):
		return _failure("QSDK_R24D94_GUARD_RUNTIME_PROJECTION_MISSING")
	var runtime_projection: Dictionary = runtime_projection_value
	var maximum := float(runtime_projection.get("effective_max_angular_velocity_rad_s", NAN))
	if (
		String(runtime_projection.get("schema_version", ""))
		!= JOLT_ANGULAR_VELOCITY_RUNTIME_PROJECTION_SCHEMA
		or not bool(runtime_projection.get("ok", false))
		or String(runtime_projection.get("setting_path", ""))
		!= JOLT_MAX_ANGULAR_VELOCITY_SETTING_PATH
		or not bool(runtime_projection.get("source_measurement", false))
		or not is_finite(maximum)
		or maximum <= 0.0
	):
		return _failure("QSDK_R24D94_GUARD_RUNTIME_PROJECTION_INVALID")
	var relative_headroom := (
		NATIVE_ANGULAR_VELOCITY_GUARD_ERROR_MULTIPLIER
		* HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND
	)
	var unprojected_guard_limit := maximum * (1.0 - relative_headroom)
	var guard_limit := _binary32_floor_v1(unprojected_guard_limit)
	if (
		not is_finite(relative_headroom)
		or relative_headroom <= 0.0
		or relative_headroom >= 1.0
		or not is_finite(guard_limit)
		or guard_limit <= 0.0
		or guard_limit >= maximum
	):
		return _failure("QSDK_R24D94_GUARD_LIMIT_PROJECTION_INVALID")
	return {
		"schema_version": NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA,
		"ok": true,
		"runtime_limit_projection": runtime_projection.duplicate(true),
		"effective_max_angular_velocity_rad_s": maximum,
		"host_real_binary32_relative_error_bound": (
			HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND
		),
		"representational_error_multiplier": (
			NATIVE_ANGULAR_VELOCITY_GUARD_ERROR_MULTIPLIER
		),
		"relative_headroom": relative_headroom,
		"unprojected_guard_limit_rad_s": unprojected_guard_limit,
		"guard_limit_rad_s": guard_limit,
		"guard_limit_binary32_hex": "0x%08x" % _binary32_bits_v1(guard_limit),
		"absolute_headroom_rad_s": maximum - guard_limit,
		"selection_rule": (
			"binary32_floor_of_effective_runtime_limit_times_one_minus_1024_"
			+ "binary32_relative_error_bounds"
		),
		"margin_kind": "source_derived_representational_operating_guard",
		"engine_limit_changed": false,
		"behavior_threshold_changed": false,
		"empirical_margin": false,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Derive R96's mathematical projection target strictly inside the unchanged
## R94/R95 native readback guard. The separation rule is the same source-derived
## 1024-binary32-epsilon rule used to derive the outer guard from Jolt's runtime
## limit. The R95 observation diagnoses the need for two boundaries but does not
## select, fit, or rethreshold this margin.
static func native_angular_velocity_inner_projection_target_v1(
	guard_projection_value: Variant,
) -> Dictionary:
	if not (guard_projection_value is Dictionary):
		return _failure("QSDK_R24D96_INNER_TARGET_OUTER_GUARD_MISSING")
	var guard_projection: Dictionary = guard_projection_value
	var runtime_value: Variant = guard_projection.get("runtime_limit_projection")
	var expected_guard := native_angular_velocity_guard_limit_projection_v1(runtime_value)
	if (
		not bool(expected_guard.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_projection, expected_guard)
	):
		return _failure("QSDK_R24D96_INNER_TARGET_OUTER_GUARD_INVALID")
	var outer_guard_limit := float(expected_guard["guard_limit_rad_s"])
	var relative_headroom := (
		NATIVE_ANGULAR_VELOCITY_GUARD_ERROR_MULTIPLIER
		* HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND
	)
	var unprojected_target := outer_guard_limit * (1.0 - relative_headroom)
	var projection_target := _binary32_floor_v1(unprojected_target)
	if (
		not is_finite(relative_headroom)
		or relative_headroom <= 0.0
		or relative_headroom >= 1.0
		or not is_finite(projection_target)
		or projection_target <= 0.0
		or projection_target >= outer_guard_limit
	):
		return _failure("QSDK_R24D96_INNER_TARGET_PROJECTION_INVALID")
	return {
		"schema_version": NATIVE_ANGULAR_VELOCITY_INNER_PROJECTION_TARGET_SCHEMA,
		"ok": true,
		"outer_guard_limit_projection": expected_guard.duplicate(true),
		"effective_max_angular_velocity_rad_s": float(
			expected_guard["effective_max_angular_velocity_rad_s"]
		),
		"outer_guard_limit_rad_s": outer_guard_limit,
		"outer_guard_limit_binary32_hex": String(
			expected_guard["guard_limit_binary32_hex"]
		),
		"host_real_binary32_relative_error_bound": (
			HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND
		),
		"representational_error_multiplier": (
			NATIVE_ANGULAR_VELOCITY_GUARD_ERROR_MULTIPLIER
		),
		"relative_headroom": relative_headroom,
		"unprojected_projection_target_limit_rad_s": unprojected_target,
		"projection_target_limit_rad_s": projection_target,
		"projection_target_limit_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(projection_target)
		),
		"absolute_outer_to_target_headroom_rad_s": (
			outer_guard_limit - projection_target
		),
		"selection_rule": (
			"binary32_floor_of_frozen_outer_guard_times_one_minus_1024_"
			+ "binary32_relative_error_bounds"
		),
		"margin_kind": "source_derived_nested_representational_projection_target",
		"outer_guard_changed": false,
		"engine_limit_changed": false,
		"behavior_threshold_changed": false,
		"empirical_margin": false,
		"r24d95_observation_selected_margin": false,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Project one requested equal-and-opposite body torque-impulse pair through the
## source-measured angular velocities and inverse inertia tensors. The greatest
## common scale in [0, 1] that keeps both predicted bodies inside the native
## operating guard is selected. This pure function owns no Node, RID, model,
## world, or solver step.
static func native_angular_velocity_guard_pair_projection_v1(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	guard_projection_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	if (
		actuator_index < 0
		or actuator_index >= ORDERED_ACTUATOR_IDS.size()
		or actuator_id != String(ORDERED_ACTUATOR_IDS[actuator_index])
		or joint_id != String(ORDERED_JOINT_IDS[actuator_index])
		or parent_body_id != String(ORDERED_PARENT_BODY_IDS[actuator_index])
		or child_body_id != String(ORDERED_CHILD_BODY_IDS[actuator_index])
		or parent_body_id == child_body_id
		or source_semantic_step < 1
	):
		return _failure("QSDK_R24D94_GUARD_BINDING_INVALID:%d" % actuator_index)
	if not (guard_projection_value is Dictionary):
		return _failure("QSDK_R24D94_GUARD_LIMIT_PROJECTION_MISSING")
	var guard_projection: Dictionary = guard_projection_value
	var guard_limit := float(guard_projection.get("guard_limit_rad_s", NAN))
	var effective_limit := float(
		guard_projection.get("effective_max_angular_velocity_rad_s", NAN)
	)
	if (
		String(guard_projection.get("schema_version", ""))
		!= NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA
		or not bool(guard_projection.get("ok", false))
		or not bool(guard_projection.get("source_measurement", false))
		or not is_finite(guard_limit)
		or not is_finite(effective_limit)
		or guard_limit <= 0.0
		or guard_limit >= effective_limit
	):
		return _failure("QSDK_R24D94_GUARD_LIMIT_PROJECTION_INVALID")
	if (
		not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not _basis_is_finite_v1(parent_inverse_inertia_tensor_world_kg_inv_m2)
		or not _basis_is_finite_v1(child_inverse_inertia_tensor_world_kg_inv_m2)
		or parent_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or child_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or not requested_parent_impulse_world_nms.is_finite()
		or not requested_child_impulse_world_nms.is_finite()
		or requested_parent_impulse_world_nms + requested_child_impulse_world_nms
		!= Vector3.ZERO
	):
		return _failure("QSDK_R24D94_GUARD_SOURCE_INVALID:%d" % actuator_index)
	var parent_source_speed := parent_angular_velocity_world_rad_s.length()
	var child_source_speed := child_angular_velocity_world_rad_s.length()
	if (
		not is_finite(parent_source_speed)
		or not is_finite(child_source_speed)
		or parent_source_speed > effective_limit
		or child_source_speed > effective_limit
	):
		return _failure("QSDK_R24D94_GUARD_SOURCE_LIMIT_INVALID:%d" % actuator_index)

	var parent_full_delta := (
		parent_inverse_inertia_tensor_world_kg_inv_m2
		* requested_parent_impulse_world_nms
	)
	var child_full_delta := (
		child_inverse_inertia_tensor_world_kg_inv_m2
		* requested_child_impulse_world_nms
	)
	if not parent_full_delta.is_finite() or not child_full_delta.is_finite():
		return _failure("QSDK_R24D94_GUARD_DELTA_INVALID:%d" % actuator_index)
	var parent_interval := _angular_guard_scale_interval_v1(
		parent_angular_velocity_world_rad_s,
		parent_full_delta,
		guard_limit,
	)
	var child_interval := _angular_guard_scale_interval_v1(
		child_angular_velocity_world_rad_s,
		child_full_delta,
		guard_limit,
	)
	if not bool(parent_interval.get("ok", false)) or not bool(child_interval.get("ok", false)):
		return _failure(
			"QSDK_R24D94_GUARD_NO_FEASIBLE_BODY_SCALE:%d" % actuator_index,
			{"parent_interval": parent_interval, "child_interval": child_interval},
		)
	var feasible_lower := maxf(
		float(parent_interval["minimum_scale"]),
		float(child_interval["minimum_scale"]),
	)
	var feasible_upper := minf(
		float(parent_interval["maximum_scale"]),
		float(child_interval["maximum_scale"]),
	)
	if feasible_lower > feasible_upper:
		return _failure(
			"QSDK_R24D94_GUARD_NO_FEASIBLE_PAIR_SCALE:%d" % actuator_index,
			{"feasible_lower": feasible_lower, "feasible_upper": feasible_upper},
		)
	var applied_scale := _binary32_floor_v1(clampf(feasible_upper, 0.0, 1.0))
	var refinement_count := 0
	var applied_child_impulse := requested_child_impulse_world_nms * applied_scale
	var applied_parent_impulse := -applied_child_impulse
	var predicted_parent := (
		parent_angular_velocity_world_rad_s
		+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
	)
	var predicted_child := (
		child_angular_velocity_world_rad_s
		+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
	)
	while (
		(predicted_parent.length() > guard_limit or predicted_child.length() > guard_limit)
		and applied_scale > 0.0
		and refinement_count < NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
	):
		var scale_bits := _binary32_bits_v1(applied_scale)
		applied_scale = _binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
		applied_child_impulse = requested_child_impulse_world_nms * applied_scale
		applied_parent_impulse = -applied_child_impulse
		predicted_parent = (
			parent_angular_velocity_world_rad_s
			+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
		)
		predicted_child = (
			child_angular_velocity_world_rad_s
			+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
		)
		refinement_count += 1
	var predicted_parent_speed := predicted_parent.length()
	var predicted_child_speed := predicted_child.length()
	if (
		not predicted_parent.is_finite()
		or not predicted_child.is_finite()
		or not is_finite(predicted_parent_speed)
		or not is_finite(predicted_child_speed)
		or applied_scale < feasible_lower
		or applied_scale > 1.0
		or predicted_parent_speed > guard_limit
		or predicted_child_speed > guard_limit
		or applied_parent_impulse + applied_child_impulse != Vector3.ZERO
	):
		return _failure("QSDK_R24D94_GUARD_REFINEMENT_FAILED:%d" % actuator_index)
	return {
		"schema_version": NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA,
		"ok": true,
		"actuator_index": actuator_index,
		"actuator_id": actuator_id,
		"joint_id": joint_id,
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": source_semantic_step,
		"guard_limit_projection": guard_projection.duplicate(true),
		"effective_max_angular_velocity_rad_s": effective_limit,
		"guard_limit_rad_s": guard_limit,
		"parent_source_angular_velocity_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s
		),
		"child_source_angular_velocity_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s
		),
		"parent_source_angular_speed_rad_s": parent_source_speed,
		"child_source_angular_speed_rad_s": child_source_speed,
		"parent_inverse_inertia_tensor_world_kg_inv_m2": _basis_json_v1(
			parent_inverse_inertia_tensor_world_kg_inv_m2
		),
		"child_inverse_inertia_tensor_world_kg_inv_m2": _basis_json_v1(
			child_inverse_inertia_tensor_world_kg_inv_m2
		),
		"requested_parent_impulse_world_nms": _vector_json(
			requested_parent_impulse_world_nms
		),
		"requested_child_impulse_world_nms": _vector_json(
			requested_child_impulse_world_nms
		),
		"applied_parent_impulse_world_nms": _vector_json(applied_parent_impulse),
		"applied_child_impulse_world_nms": _vector_json(applied_child_impulse),
		"applied_pairing_residual_world_nms": _vector_json(
			applied_parent_impulse + applied_child_impulse
		),
		"parent_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			parent_full_delta
		),
		"child_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			child_full_delta
		),
		"feasible_scale_lower": feasible_lower,
		"feasible_scale_upper": feasible_upper,
		"applied_scale": applied_scale,
		"scale_binary32_hex": "0x%08x" % _binary32_bits_v1(applied_scale),
		"guard_engaged": applied_scale < 1.0,
		"scale_refinement_count": refinement_count,
		"predicted_parent_angular_velocity_world_rad_s": _vector_json(predicted_parent),
		"predicted_child_angular_velocity_world_rad_s": _vector_json(predicted_child),
		"predicted_parent_angular_speed_rad_s": predicted_parent_speed,
		"predicted_child_angular_speed_rad_s": predicted_child_speed,
		"both_predicted_inside_guard": (
			predicted_parent_speed <= guard_limit
			and predicted_child_speed <= guard_limit
		),
		"source_measurement": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R96 reuses the frozen R94 pair solver against a strictly inner mathematical
## target, then restores the unchanged outer guard as native readback authority.
## The temporary adapter projection never escapes this pure function; the
## returned receipt carries and validates both exact boundaries independently.
static func nested_native_angular_velocity_guard_pair_projection_v1(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	if not (inner_projection_target_value is Dictionary):
		return _failure("QSDK_R24D96_NESTED_PAIR_TARGET_MISSING")
	var inner_projection_target: Dictionary = inner_projection_target_value
	var outer_guard_value: Variant = inner_projection_target.get(
		"outer_guard_limit_projection"
	)
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(inner_projection_target, expected_target)
	):
		return _failure("QSDK_R24D96_NESTED_PAIR_TARGET_INVALID")
	var outer_guard: Dictionary = expected_target["outer_guard_limit_projection"]
	var target_limit := float(expected_target["projection_target_limit_rad_s"])
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])

	# Adapt only the old solver's numerical limit input. The successor validator
	# reconstructs this result from the exact outer and inner receipts, so this
	# internal adapter can neither weaken nor masquerade as an R94 receipt.
	var target_solver_projection: Dictionary = outer_guard.duplicate(true)
	target_solver_projection["guard_limit_rad_s"] = target_limit
	target_solver_projection["guard_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	var base := native_angular_velocity_guard_pair_projection_v1(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		target_solver_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	if not bool(base.get("ok", false)):
		var predecessor_failure_code := String(base.get("failure_code", ""))
		var parent_source_speed := parent_angular_velocity_world_rad_s.length()
		var child_source_speed := child_angular_velocity_world_rad_s.length()
		var outer_hold_allowed := (
			predecessor_failure_code.begins_with(
				"QSDK_R24D94_GUARD_NO_FEASIBLE_"
			)
			and parent_source_speed <= outer_guard_limit
			and child_source_speed <= outer_guard_limit
			and (parent_source_speed > target_limit or child_source_speed > target_limit)
		)
		if not outer_hold_allowed:
			return _failure(
				"QSDK_R24D96_NESTED_PAIR_TARGET_PROJECTION_FAILED",
				{"predecessor_projection_failure": base},
			)
		base = native_angular_velocity_guard_pair_projection_v1(
			actuator_index,
			actuator_id,
			joint_id,
			parent_body_id,
			child_body_id,
			source_semantic_step,
			outer_guard,
			parent_angular_velocity_world_rad_s,
			child_angular_velocity_world_rad_s,
			parent_inverse_inertia_tensor_world_kg_inv_m2,
			child_inverse_inertia_tensor_world_kg_inv_m2,
			Vector3.ZERO,
			Vector3.ZERO,
		)
		if not bool(base.get("ok", false)):
			return _failure("QSDK_R24D96_NESTED_PAIR_OUTER_HOLD_FAILED", base)
		base["requested_parent_impulse_world_nms"] = _vector_json(
			requested_parent_impulse_world_nms
		)
		base["requested_child_impulse_world_nms"] = _vector_json(
			requested_child_impulse_world_nms
		)
		base["parent_full_scale_delta_angular_velocity_world_rad_s"] = _vector_json(
			parent_inverse_inertia_tensor_world_kg_inv_m2
			* requested_parent_impulse_world_nms
		)
		base["child_full_scale_delta_angular_velocity_world_rad_s"] = _vector_json(
			child_inverse_inertia_tensor_world_kg_inv_m2
			* requested_child_impulse_world_nms
		)
		base["applied_scale"] = 0.0
		base["scale_binary32_hex"] = "0x00000000"
		base["guard_engaged"] = true
		base["feasible_scale_lower"] = 0.0
		base["feasible_scale_upper"] = 0.0
		base["projection_target_feasible"] = false
		base["outer_guard_zero_impulse_hold"] = true
		base["outer_guard_hold_reason"] = "source_inside_outer_guard_but_outside_inner_target"
	var result: Dictionary = base.duplicate(true)
	var parent_speed := float(result["predicted_parent_angular_speed_rad_s"])
	var child_speed := float(result["predicted_child_angular_speed_rad_s"])
	var outer_hold := bool(result.get("outer_guard_zero_impulse_hold", false))
	if (
		(parent_speed > target_limit or child_speed > target_limit)
		and not outer_hold
	):
		return _failure("QSDK_R24D96_NESTED_PAIR_TARGET_EXCEEDED")
	result["schema_version"] = NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
	result["guard_limit_projection"] = outer_guard.duplicate(true)
	result["inner_projection_target"] = expected_target.duplicate(true)
	result["guard_limit_rad_s"] = outer_guard_limit
	result["projection_target_limit_rad_s"] = target_limit
	result["projection_target_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	result["both_predicted_inside_guard"] = (
		parent_speed <= outer_guard_limit and child_speed <= outer_guard_limit
	)
	result["both_predicted_inside_projection_target"] = (
		parent_speed <= target_limit and child_speed <= target_limit
	)
	result["projection_target_feasible"] = not outer_hold
	result["outer_guard_zero_impulse_hold"] = outer_hold
	result["projection_target_separated_from_native_readback_guard"] = true
	result["outer_guard_changed"] = false
	result["r24d95_observation_selected_margin"] = false
	return result


static func _angular_guard_scale_interval_v1(
	current_angular_velocity: Vector3,
	full_scale_delta_angular_velocity: Vector3,
	guard_limit: float,
) -> Dictionary:
	if (
		not current_angular_velocity.is_finite()
		or not full_scale_delta_angular_velocity.is_finite()
		or not is_finite(guard_limit)
		or guard_limit <= 0.0
	):
		return _failure("QSDK_R24D94_GUARD_INTERVAL_INPUT_INVALID")
	var a := full_scale_delta_angular_velocity.length_squared()
	var b := 2.0 * current_angular_velocity.dot(full_scale_delta_angular_velocity)
	var c := current_angular_velocity.length_squared() - guard_limit * guard_limit
	if not is_finite(a) or not is_finite(b) or not is_finite(c):
		return _failure("QSDK_R24D94_GUARD_INTERVAL_NONFINITE")
	if a == 0.0:
		if c > 0.0:
			return _failure("QSDK_R24D94_GUARD_INTERVAL_STATIC_OUTSIDE")
		return {"ok": true, "minimum_scale": 0.0, "maximum_scale": 1.0}
	var discriminant := b * b - 4.0 * a * c
	if not is_finite(discriminant) or discriminant < 0.0:
		return _failure("QSDK_R24D94_GUARD_INTERVAL_EMPTY")
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	var minimum_scale := maxf(0.0, minf(first, second))
	var maximum_scale := minf(1.0, maxf(first, second))
	if minimum_scale > maximum_scale:
		return _failure("QSDK_R24D94_GUARD_INTERVAL_OUTSIDE_UNIT")
	return {
		"ok": true,
		"minimum_scale": minimum_scale,
		"maximum_scale": maximum_scale,
	}


## R99's reusable numerical primitive. Vector3 stores real_t components, but
## the guard decision is made only after widening those components to GDScript
## float64 and evaluating one Euclidean squared-norm relation. The historical
## Vector3 predicates remain diagnostics and never select an action.
static func angular_velocity_component_norm_limit_relation_v1(
	angular_velocity_world_rad_s: Vector3,
	limit_rad_s: float,
) -> Dictionary:
	if (
		not angular_velocity_world_rad_s.is_finite()
		or not is_finite(limit_rad_s)
		or limit_rad_s <= 0.0
	):
		return _failure("QSDK_R24D99_COMPONENT_NORM_RELATION_INPUT_INVALID")
	var x := float(angular_velocity_world_rad_s.x)
	var y := float(angular_velocity_world_rad_s.y)
	var z := float(angular_velocity_world_rad_s.z)
	var component_squared := x * x + y * y + z * z
	var limit_squared := limit_rad_s * limit_rad_s
	var component_norm := sqrt(component_squared)
	var legacy_length := angular_velocity_world_rad_s.length()
	var legacy_length_squared := angular_velocity_world_rad_s.length_squared()
	if (
		not is_finite(component_squared)
		or not is_finite(limit_squared)
		or not is_finite(component_norm)
		or not is_finite(legacy_length)
		or not is_finite(legacy_length_squared)
	):
		return _failure("QSDK_R24D99_COMPONENT_NORM_RELATION_NONFINITE")
	var inside := component_squared <= limit_squared
	var legacy_length_inside := legacy_length <= limit_rad_s
	var legacy_squared_inside := legacy_length_squared <= limit_squared
	return {
		"schema_version": COMPONENT_NORM_ANGULAR_VELOCITY_LIMIT_RELATION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"angular_velocity_world_rad_s": _vector_json(
			angular_velocity_world_rad_s
		),
		"component_squared_norm_rad2_s2": component_squared,
		"component_norm_rad_s": component_norm,
		"limit_rad_s": limit_rad_s,
		"limit_squared_rad2_s2": limit_squared,
		"inside_or_on_limit": inside,
		"outside_limit": not inside,
		"exact_component_boundary": component_squared == limit_squared,
		"legacy_vector_length_rad_s": legacy_length,
		"legacy_vector_length_squared_rad2_s2": legacy_length_squared,
		"legacy_length_predicate_inside": legacy_length_inside,
		"legacy_squared_predicate_inside": legacy_squared_inside,
		"legacy_predicates_disagree": (
			legacy_length_inside != legacy_squared_inside
		),
		"legacy_predicates_have_action_authority": false,
		"source_measurement": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _component_dot_float64_v1(left: Vector3, right: Vector3) -> float:
	return (
		float(left.x) * float(right.x)
		+ float(left.y) * float(right.y)
		+ float(left.z) * float(right.z)
	)


## Solve |w + s*d| <= limit for s in [0,1] using exactly the same widened-
## component squared norm that owns every R99 boundary decision.
static func _angular_guard_scale_interval_component_norm_v1(
	current_angular_velocity: Vector3,
	full_scale_delta_angular_velocity: Vector3,
	guard_limit: float,
) -> Dictionary:
	if (
		not current_angular_velocity.is_finite()
		or not full_scale_delta_angular_velocity.is_finite()
		or not is_finite(guard_limit)
		or guard_limit <= 0.0
	):
		return _failure("QSDK_R24D99_GUARD_INTERVAL_INPUT_INVALID")
	var a := _component_dot_float64_v1(
		full_scale_delta_angular_velocity,
		full_scale_delta_angular_velocity,
	)
	var b := 2.0 * _component_dot_float64_v1(
		current_angular_velocity,
		full_scale_delta_angular_velocity,
	)
	var c := (
		_component_dot_float64_v1(
			current_angular_velocity,
			current_angular_velocity,
		)
		- guard_limit * guard_limit
	)
	if not is_finite(a) or not is_finite(b) or not is_finite(c):
		return _failure("QSDK_R24D99_GUARD_INTERVAL_NONFINITE")
	if a == 0.0:
		if c > 0.0:
			return _failure("QSDK_R24D99_GUARD_INTERVAL_STATIC_OUTSIDE")
		return {
			"ok": true,
			"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
			"quadratic_a": a,
			"quadratic_b": b,
			"quadratic_c": c,
			"minimum_scale": 0.0,
			"maximum_scale": 1.0,
		}
	var discriminant := b * b - 4.0 * a * c
	if not is_finite(discriminant) or discriminant < 0.0:
		return _failure("QSDK_R24D99_GUARD_INTERVAL_EMPTY")
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	var minimum_scale := maxf(0.0, minf(first, second))
	var maximum_scale := minf(1.0, maxf(first, second))
	if minimum_scale > maximum_scale:
		return _failure("QSDK_R24D99_GUARD_INTERVAL_OUTSIDE_UNIT")
	return {
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"quadratic_a": a,
		"quadratic_b": b,
		"quadratic_c": c,
		"discriminant": discriminant,
		"minimum_scale": minimum_scale,
		"maximum_scale": maximum_scale,
	}


## R103 solves one scale for the complete actuator/body population before any
## native write. Input order has no action authority: requests are bound by
## unique actuator index and rebuilt in canonical order before accumulation.
## The pure receipt is also the sole body-write plan consumed by the route.
static func order_neutral_population_guard_projection_v1(
	request_values: Array,
	source_angular_velocity_by_body_id: Dictionary,
	inverse_inertia_tensor_by_body_id: Dictionary,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
) -> Dictionary:
	if source_semantic_step < 1 or not (inner_projection_target_value is Dictionary):
		return _failure("QSDK_R24D103_POPULATION_BINDING_INVALID")
	var inner_projection_target: Dictionary = inner_projection_target_value
	var outer_guard_value: Variant = inner_projection_target.get("outer_guard_limit_projection")
	var expected_target := native_angular_velocity_inner_projection_target_v1(outer_guard_value)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(inner_projection_target, expected_target)
	):
		return _failure("QSDK_R24D103_POPULATION_TARGET_INVALID")
	if (
		request_values.size() != ORDERED_ACTUATOR_IDS.size()
		or source_angular_velocity_by_body_id.size() != ORDERED_BODY_IDS.size()
		or inverse_inertia_tensor_by_body_id.size() != ORDERED_BODY_IDS.size()
	):
		return _failure("QSDK_R24D103_POPULATION_CARDINALITY_INVALID")

	var request_by_index: Dictionary = {}
	for request_value in request_values:
		if not (request_value is Dictionary):
			return _failure("QSDK_R24D103_POPULATION_REQUEST_INVALID")
		var request: Dictionary = request_value
		var index := int(request.get("actuator_index", -1))
		if index < 0 or index >= ORDERED_ACTUATOR_IDS.size() or request_by_index.has(index):
			return _failure("QSDK_R24D103_POPULATION_REQUEST_INDEX_INVALID")
		var parent_body_id := String(request.get("parent_body_id", ""))
		var child_body_id := String(request.get("child_body_id", ""))
		var parent_impulse_value: Variant = request.get("requested_parent_impulse_world_nms")
		var child_impulse_value: Variant = request.get("requested_child_impulse_world_nms")
		if (
			String(request.get("actuator_id", "")) != String(ORDERED_ACTUATOR_IDS[index])
			or String(request.get("joint_id", "")) != String(ORDERED_JOINT_IDS[index])
			or parent_body_id != String(ORDERED_PARENT_BODY_IDS[index])
			or child_body_id != String(ORDERED_CHILD_BODY_IDS[index])
			or parent_body_id == child_body_id
			or not (parent_impulse_value is Vector3)
			or not (child_impulse_value is Vector3)
		):
			return _failure("QSDK_R24D103_POPULATION_REQUEST_BINDING_INVALID:%d" % index)
		var parent_impulse: Vector3 = parent_impulse_value
		var child_impulse: Vector3 = child_impulse_value
		if (
			not parent_impulse.is_finite()
			or not child_impulse.is_finite()
			or parent_impulse + child_impulse != Vector3.ZERO
		):
			return _failure("QSDK_R24D103_POPULATION_REQUEST_PAIR_INVALID:%d" % index)
		request_by_index[index] = {
			"actuator_index": index,
			"actuator_id": String(ORDERED_ACTUATOR_IDS[index]),
			"joint_id": String(ORDERED_JOINT_IDS[index]),
			"parent_body_id": parent_body_id,
			"child_body_id": child_body_id,
			"requested_parent_impulse_world_nms": parent_impulse,
			"requested_child_impulse_world_nms": child_impulse,
		}
	if request_by_index.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D103_POPULATION_REQUEST_POPULATION_INCOMPLETE")

	var ordered_requests: Array = []
	var requested_aggregate_by_body_id: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		requested_aggregate_by_body_id[String(body_id_value)] = Vector3.ZERO
	var requested_population_residual := Vector3.ZERO
	for index in range(ORDERED_ACTUATOR_IDS.size()):
		var request: Dictionary = request_by_index[index]
		ordered_requests.append(request)
		var parent_body_id := String(request["parent_body_id"])
		var child_body_id := String(request["child_body_id"])
		var parent_impulse: Vector3 = request["requested_parent_impulse_world_nms"]
		var child_impulse: Vector3 = request["requested_child_impulse_world_nms"]
		requested_aggregate_by_body_id[parent_body_id] = (
			(requested_aggregate_by_body_id[parent_body_id] as Vector3) + parent_impulse
		)
		requested_aggregate_by_body_id[child_body_id] = (
			(requested_aggregate_by_body_id[child_body_id] as Vector3) + child_impulse
		)
		requested_population_residual += parent_impulse + child_impulse
	if requested_population_residual != Vector3.ZERO:
		return _failure("QSDK_R24D103_POPULATION_REQUEST_RESIDUAL_INVALID")

	var target_limit := float(expected_target["projection_target_limit_rad_s"])
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])
	var source_by_body_id: Dictionary = {}
	var inertia_by_body_id: Dictionary = {}
	var interval_by_body_id: Dictionary = {}
	var feasible_lower := 0.0
	var feasible_upper := 1.0
	var continuous_target_feasible := true
	var source_inside_target_count := 0
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		if (
			not source_angular_velocity_by_body_id.has(body_id)
			or not inverse_inertia_tensor_by_body_id.has(body_id)
		):
			return _failure("QSDK_R24D103_POPULATION_BODY_SOURCE_MISSING:%s" % body_id)
		var source_value: Variant = source_angular_velocity_by_body_id[body_id]
		var inertia_value: Variant = inverse_inertia_tensor_by_body_id[body_id]
		if not (source_value is Vector3) or not (inertia_value is Basis):
			return _failure("QSDK_R24D103_POPULATION_BODY_SOURCE_TYPE_INVALID:%s" % body_id)
		var source: Vector3 = source_value
		var inverse_inertia: Basis = inertia_value
		var source_target_relation := angular_velocity_component_norm_limit_relation_v1(
			source, target_limit
		)
		var source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
			source, outer_guard_limit
		)
		if (
			not source.is_finite()
			or not _basis_is_finite_v1(inverse_inertia)
			or inverse_inertia.determinant() <= 0.0
			or not bool(source_target_relation.get("ok", false))
			or not bool(source_outer_relation.get("ok", false))
			or not bool(source_outer_relation.get("inside_or_on_limit", false))
		):
			return _failure("QSDK_R24D103_POPULATION_BODY_SOURCE_INVALID:%s" % body_id)
		source_by_body_id[body_id] = source
		inertia_by_body_id[body_id] = inverse_inertia
		source_inside_target_count += int(bool(source_target_relation["inside_or_on_limit"]))
		var requested_aggregate: Vector3 = requested_aggregate_by_body_id[body_id]
		var full_scale_delta := inverse_inertia * requested_aggregate
		var interval := _angular_guard_scale_interval_component_norm_v1(
			source,
			full_scale_delta,
			target_limit,
		)
		interval_by_body_id[body_id] = interval
		if bool(interval.get("ok", false)):
			feasible_lower = maxf(feasible_lower, float(interval["minimum_scale"]))
			feasible_upper = minf(feasible_upper, float(interval["maximum_scale"]))
		else:
			continuous_target_feasible = false
	if feasible_lower > feasible_upper:
		continuous_target_feasible = false

	var applied_scale := 0.0
	var scale_refinement_count := 0
	var representational_fallback := false
	var outer_hold := false
	var application_projection: Dictionary = {}
	if continuous_target_feasible:
		applied_scale = _binary32_floor_v1(clampf(feasible_upper, 0.0, 1.0))
		application_projection = _order_neutral_population_application_projection_v1(
			ordered_requests,
			source_by_body_id,
			inertia_by_body_id,
			requested_aggregate_by_body_id,
			interval_by_body_id,
			applied_scale,
			target_limit,
			outer_guard_limit,
		)
		while (
			(
				not bool(
					application_projection.get("all_predicted_inside_projection_target", false)
				)
				or applied_scale < feasible_lower
			)
			and applied_scale > 0.0
			and scale_refinement_count < NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
		):
			var scale_bits := _binary32_bits_v1(applied_scale)
			applied_scale = _binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
			scale_refinement_count += 1
			application_projection = _order_neutral_population_application_projection_v1(
				ordered_requests,
				source_by_body_id,
				inertia_by_body_id,
				requested_aggregate_by_body_id,
				interval_by_body_id,
				applied_scale,
				target_limit,
				outer_guard_limit,
			)
		if (
			not bool(application_projection.get("all_predicted_inside_projection_target", false))
			or applied_scale < feasible_lower
		):
			representational_fallback = true
			applied_scale = 0.0
	else:
		outer_hold = true
	if outer_hold or representational_fallback:
		application_projection = _order_neutral_population_application_projection_v1(
			ordered_requests,
			source_by_body_id,
			inertia_by_body_id,
			requested_aggregate_by_body_id,
			interval_by_body_id,
			0.0,
			target_limit,
			outer_guard_limit,
		)
	if not bool(application_projection.get("all_predicted_inside_outer_guard", false)):
		return _failure("QSDK_R24D103_POPULATION_OUTER_GUARD_INVALID")
	if (
		continuous_target_feasible
		and not representational_fallback
		and not bool(application_projection.get("all_predicted_inside_projection_target", false))
	):
		return _failure("QSDK_R24D103_POPULATION_TARGET_REFINEMENT_INVALID")

	return {
		"schema_version": ORDER_NEUTRAL_POPULATION_GUARD_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"allocation_rule_id":
		"canonical_actuator_identity_order_neutral_whole_population_uniform_scale_v1",
		"body_application_rule_id": "one_validated_aggregate_torque_impulse_per_nonzero_body_v1",
		"attribution_rule_id": "canonical_equal_and_opposite_joint_pair_times_common_scale_v1",
		"source_semantic_step": source_semantic_step,
		"inner_projection_target": expected_target.duplicate(true),
		"projection_target_limit_rad_s": target_limit,
		"outer_guard_limit_rad_s": outer_guard_limit,
		"ordered_actuator_ids": ORDERED_ACTUATOR_IDS.duplicate(),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"actuator_count": ORDERED_ACTUATOR_IDS.size(),
		"body_count": ORDERED_BODY_IDS.size(),
		"continuous_projection_target_feasible": continuous_target_feasible,
		"common_scale_feasible_lower": feasible_lower,
		"common_scale_feasible_upper": feasible_upper,
		"common_applied_scale": applied_scale,
		"common_applied_scale_binary32_hex": "0x%08x" % _binary32_bits_v1(applied_scale),
		"scale_refinement_count": scale_refinement_count,
		"population_guard_engaged": applied_scale < 1.0,
		"outer_guard_zero_impulse_hold": outer_hold,
		"representational_zero_impulse_fallback": representational_fallback,
		"zero_impulse_fallback_reason":
		(
			"population_binary32_scale_refinement_exhausted"
			if representational_fallback
			else (
				"population_projection_target_infeasible_source_inside_outer_guard"
				if outer_hold
				else null
			)
		),
		"source_inside_projection_target_count": source_inside_target_count,
		"all_source_inside_outer_guard": true,
		"ordered_actuator_attributions": application_projection["ordered_actuator_attributions"],
		"ordered_body_projections": application_projection["ordered_body_projections"],
		"requested_population_pairing_residual_world_nms":
		_vector_json(requested_population_residual),
		"applied_population_pairing_residual_world_nms":
		application_projection["applied_population_pairing_residual_world_nms"],
		"nonzero_body_impulse_count": int(application_projection["nonzero_body_impulse_count"]),
		"all_predicted_inside_projection_target":
		bool(application_projection["all_predicted_inside_projection_target"]),
		"all_predicted_inside_outer_guard": true,
		"input_iteration_order_has_action_authority": false,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _order_neutral_population_application_projection_v1(
	ordered_requests: Array,
	source_by_body_id: Dictionary,
	inertia_by_body_id: Dictionary,
	requested_aggregate_by_body_id: Dictionary,
	interval_by_body_id: Dictionary,
	applied_scale: float,
	target_limit: float,
	outer_guard_limit: float,
) -> Dictionary:
	var applied_aggregate_by_body_id: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		applied_aggregate_by_body_id[String(body_id_value)] = Vector3.ZERO
	var ordered_attributions: Array = []
	var applied_population_residual := Vector3.ZERO
	for request_value in ordered_requests:
		var request: Dictionary = request_value
		var parent_body_id := String(request["parent_body_id"])
		var child_body_id := String(request["child_body_id"])
		var requested_parent: Vector3 = request["requested_parent_impulse_world_nms"]
		var requested_child: Vector3 = request["requested_child_impulse_world_nms"]
		var applied_child := requested_child * applied_scale
		var applied_parent := -applied_child
		applied_aggregate_by_body_id[parent_body_id] = (
			(applied_aggregate_by_body_id[parent_body_id] as Vector3) + applied_parent
		)
		applied_aggregate_by_body_id[child_body_id] = (
			(applied_aggregate_by_body_id[child_body_id] as Vector3) + applied_child
		)
		applied_population_residual += applied_parent + applied_child
		(
			ordered_attributions
			. append(
				{
					"actuator_index": int(request["actuator_index"]),
					"actuator_id": String(request["actuator_id"]),
					"joint_id": String(request["joint_id"]),
					"parent_body_id": parent_body_id,
					"child_body_id": child_body_id,
					"requested_parent_impulse_world_nms": _vector_json(requested_parent),
					"requested_child_impulse_world_nms": _vector_json(requested_child),
					"attributed_applied_parent_impulse_world_nms": _vector_json(applied_parent),
					"attributed_applied_child_impulse_world_nms": _vector_json(applied_child),
					"attributed_applied_pairing_residual_world_nms":
					_vector_json(applied_parent + applied_child),
					"common_applied_scale": applied_scale,
					"common_applied_scale_binary32_hex":
					"0x%08x" % _binary32_bits_v1(applied_scale),
					"equal_and_opposite_pair": true,
				}
			)
		)
	var ordered_body_projections: Array = []
	var all_target := true
	var all_outer := true
	var nonzero_body_count := 0
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var source: Vector3 = source_by_body_id[body_id]
		var inverse_inertia: Basis = inertia_by_body_id[body_id]
		var requested_aggregate: Vector3 = requested_aggregate_by_body_id[body_id]
		var applied_aggregate: Vector3 = applied_aggregate_by_body_id[body_id]
		var predicted := source + inverse_inertia * applied_aggregate
		var source_target_relation := angular_velocity_component_norm_limit_relation_v1(
			source, target_limit
		)
		var source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
			source, outer_guard_limit
		)
		var predicted_target_relation := angular_velocity_component_norm_limit_relation_v1(
			predicted, target_limit
		)
		var predicted_outer_relation := angular_velocity_component_norm_limit_relation_v1(
			predicted, outer_guard_limit
		)
		all_target = (
			all_target and bool(predicted_target_relation.get("inside_or_on_limit", false))
		)
		all_outer = (all_outer and bool(predicted_outer_relation.get("inside_or_on_limit", false)))
		nonzero_body_count += int(applied_aggregate != Vector3.ZERO)
		(
			ordered_body_projections
			. append(
				{
					"body_id": body_id,
					"source_angular_velocity_world_rad_s": _vector_json(source),
					"inverse_inertia_tensor_world_kg_inv_m2": _basis_json_v1(inverse_inertia),
					"requested_aggregate_impulse_world_nms": _vector_json(requested_aggregate),
					"full_scale_delta_angular_velocity_world_rad_s":
					_vector_json(inverse_inertia * requested_aggregate),
					"feasible_scale_interval":
					(interval_by_body_id[body_id] as Dictionary).duplicate(true),
					"applied_aggregate_impulse_world_nms": _vector_json(applied_aggregate),
					"predicted_angular_velocity_world_rad_s": _vector_json(predicted),
					"source_projection_target_relation": source_target_relation,
					"source_outer_guard_relation": source_outer_relation,
					"predicted_projection_target_relation": predicted_target_relation,
					"predicted_outer_guard_relation": predicted_outer_relation,
					"nonzero_body_impulse": applied_aggregate != Vector3.ZERO,
				}
			)
		)
	return {
		"ordered_actuator_attributions": ordered_attributions,
		"ordered_body_projections": ordered_body_projections,
		"applied_population_pairing_residual_world_nms": _vector_json(applied_population_residual),
		"nonzero_body_impulse_count": nonzero_body_count,
		"all_predicted_inside_projection_target": all_target,
		"all_predicted_inside_outer_guard": all_outer,
	}


static func validate_order_neutral_population_guard_projection_v1(
	population_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = population_projection.get("inner_projection_target")
	var attribution_values: Variant = population_projection.get("ordered_actuator_attributions")
	var body_values: Variant = population_projection.get("ordered_body_projections")
	if (
		not (target_value is Dictionary)
		or not (attribution_values is Array)
		or not (body_values is Array)
	):
		return _failure("QSDK_R24D103_POPULATION_RECEIPT_SOURCE_MISSING")
	var requests: Array = []
	for attribution_value in attribution_values:
		if not (attribution_value is Dictionary):
			return _failure("QSDK_R24D103_POPULATION_RECEIPT_ATTRIBUTION_INVALID")
		var attribution: Dictionary = attribution_value
		(
			requests
			. append(
				{
					"actuator_index": int(attribution.get("actuator_index", -1)),
					"actuator_id": String(attribution.get("actuator_id", "")),
					"joint_id": String(attribution.get("joint_id", "")),
					"parent_body_id": String(attribution.get("parent_body_id", "")),
					"child_body_id": String(attribution.get("child_body_id", "")),
					"requested_parent_impulse_world_nms":
					_vec3(attribution.get("requested_parent_impulse_world_nms")),
					"requested_child_impulse_world_nms":
					_vec3(attribution.get("requested_child_impulse_world_nms")),
				}
			)
		)
	var source_by_body_id: Dictionary = {}
	var inertia_by_body_id: Dictionary = {}
	for body_value in body_values:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D103_POPULATION_RECEIPT_BODY_INVALID")
		var body: Dictionary = body_value
		var body_id := String(body.get("body_id", ""))
		if body_id.is_empty() or source_by_body_id.has(body_id):
			return _failure("QSDK_R24D103_POPULATION_RECEIPT_BODY_ID_INVALID")
		source_by_body_id[body_id] = _vec3(body.get("source_angular_velocity_world_rad_s"))
		inertia_by_body_id[body_id] = _basis_from_json_v1(
			body.get("inverse_inertia_tensor_world_kg_inv_m2")
		)
	var expected := order_neutral_population_guard_projection_v1(
		requests,
		source_by_body_id,
		inertia_by_body_id,
		int(population_projection.get("source_semantic_step", -1)),
		target_value,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(population_projection, expected)
	):
		return _failure("QSDK_R24D103_POPULATION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d103_order_neutral_population_guard_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R107 composes one source-derived joint-target cap with the frozen R103 body
## guard. The complete original eight-actuator population is canonicalized and
## aggregated before any decision. A nonzero aggregate joint delta must point
## toward that joint's frozen controller target; otherwise the whole population
## holds. The binary32-floored minimum nonovershooting scale is applied before
## R103, whose unchanged body guard remains final native-safety authority.
static func joint_target_monotone_population_guard_projection_v1(
	predecessor_projection_values: Array,
	source_angular_velocity_by_body_id: Dictionary,
	inverse_inertia_tensor_by_body_id: Dictionary,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
) -> Dictionary:
	if (
		source_semantic_step < 1
		or not (inner_projection_target_value is Dictionary)
		or predecessor_projection_values.size() != ORDERED_ACTUATOR_IDS.size()
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_BINDING_INVALID")
	var predecessor_by_index: Dictionary = {}
	for predecessor_value in predecessor_projection_values:
		if not (predecessor_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_PREDECESSOR_INVALID")
		var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
			predecessor_value
		)
		if not bool(predecessor_validation.get("ok", false)):
			return _failure(
				"QSDK_R24D107_TARGET_MONOTONE_PREDECESSOR_VALIDATION_FAILED",
				predecessor_validation,
			)
		var predecessor: Dictionary = predecessor_validation["projection"]
		var actuator_index := int(predecessor.get("actuator_index", -1))
		if (
			actuator_index < 0
			or actuator_index >= ORDERED_ACTUATOR_IDS.size()
			or predecessor_by_index.has(actuator_index)
			or int(predecessor.get("source_semantic_step", -1)) != source_semantic_step
		):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_PREDECESSOR_BINDING_INVALID")
		predecessor_by_index[actuator_index] = predecessor
	if predecessor_by_index.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D107_TARGET_MONOTONE_PREDECESSOR_POPULATION_INCOMPLETE")

	var ordered_predecessors: Array = []
	var original_requests: Array = []
	for actuator_index in range(ORDERED_ACTUATOR_IDS.size()):
		var predecessor: Dictionary = predecessor_by_index[actuator_index]
		ordered_predecessors.append(predecessor)
		(
			original_requests
			. append(
				{
					"actuator_index": actuator_index,
					"actuator_id": String(predecessor["actuator_id"]),
					"joint_id": String(predecessor["joint_id"]),
					"parent_body_id": String(predecessor["parent_body_id"]),
					"child_body_id": String(predecessor["child_body_id"]),
					"requested_parent_impulse_world_nms":
					_vec3(predecessor["parent_angular_impulse_world_nms"]),
					"requested_child_impulse_world_nms":
					_vec3(predecessor["child_angular_impulse_world_nms"]),
				}
			)
		)
	var original_population := order_neutral_population_guard_projection_v1(
		original_requests,
		source_angular_velocity_by_body_id,
		inverse_inertia_tensor_by_body_id,
		source_semantic_step,
		inner_projection_target_value,
	)
	if not bool(original_population.get("ok", false)):
		return _failure(
			"QSDK_R24D107_TARGET_MONOTONE_ORIGINAL_POPULATION_INVALID",
			original_population,
		)
	var original_body_by_id: Dictionary = {}
	for body_value in original_population["ordered_body_projections"]:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_ORIGINAL_BODY_INVALID")
		var body: Dictionary = body_value
		original_body_by_id[String(body.get("body_id", ""))] = body
	if original_body_by_id.size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D107_TARGET_MONOTONE_ORIGINAL_BODY_POPULATION_INVALID")

	var base_joint_projections: Array = []
	var continuous_target_common_scale := 1.0
	var nonhelpful_projection_count := 0
	var neutral_projection_count := 0
	var helpful_projection_count := 0
	for actuator_index in range(ORDERED_ACTUATOR_IDS.size()):
		var predecessor: Dictionary = ordered_predecessors[actuator_index]
		var parent_body_id := String(predecessor["parent_body_id"])
		var child_body_id := String(predecessor["child_body_id"])
		var parent_body: Dictionary = original_body_by_id[parent_body_id]
		var child_body: Dictionary = original_body_by_id[child_body_id]
		var axis_world := _vec3(predecessor["axis_world"])
		var source_relative_velocity := float(
			predecessor["measured_pre_step_relative_velocity_rad_s"]
		)
		var target_velocity := float(predecessor["canonical_target_velocity_rad_s"])
		var reconstructed_source_relative_velocity := (
			(
				_vec3(child_body["source_angular_velocity_world_rad_s"])
				- _vec3(parent_body["source_angular_velocity_world_rad_s"])
			)
			. dot(axis_world)
		)
		var full_scale_relative_velocity_delta := (
			(
				_vec3(child_body["full_scale_delta_angular_velocity_world_rad_s"])
				- _vec3(parent_body["full_scale_delta_angular_velocity_world_rad_s"])
			)
			. dot(axis_world)
		)
		var target_error := target_velocity - source_relative_velocity
		var helpful := target_error * full_scale_relative_velocity_delta > 0.0
		var neutral := full_scale_relative_velocity_delta == 0.0
		var continuous_cap := 0.0
		if helpful:
			continuous_cap = minf(
				1.0,
				absf(target_error / full_scale_relative_velocity_delta),
			)
			helpful_projection_count += 1
		elif neutral:
			continuous_cap = 1.0
			neutral_projection_count += 1
		else:
			nonhelpful_projection_count += 1
		if (
			not axis_world.is_finite()
			or not is_finite(source_relative_velocity)
			or not is_finite(target_velocity)
			or not is_finite(reconstructed_source_relative_velocity)
			or not is_finite(full_scale_relative_velocity_delta)
			or not is_finite(target_error)
			or not is_finite(continuous_cap)
			or continuous_cap < 0.0
			or continuous_cap > 1.0
		):
			return _failure(
				"QSDK_R24D107_TARGET_MONOTONE_JOINT_SOURCE_INVALID:%d" % actuator_index
			)
		continuous_target_common_scale = minf(
			continuous_target_common_scale,
			continuous_cap,
		)
		(
			base_joint_projections
			. append(
				{
					"actuator_index": actuator_index,
					"actuator_id": String(predecessor["actuator_id"]),
					"joint_id": String(predecessor["joint_id"]),
					"parent_body_id": parent_body_id,
					"child_body_id": child_body_id,
					"source_semantic_step": source_semantic_step,
					"axis_world": predecessor["axis_world"],
					"canonical_target_velocity_rad_s": target_velocity,
					"measured_pre_step_relative_velocity_rad_s": source_relative_velocity,
					"reconstructed_source_relative_velocity_rad_s":
					reconstructed_source_relative_velocity,
					"source_reconstruction_residual_rad_s":
					reconstructed_source_relative_velocity - source_relative_velocity,
					"source_target_error_rad_s": target_error,
					"full_scale_relative_velocity_delta_rad_s":
					full_scale_relative_velocity_delta,
					"full_scale_delta_helpful": helpful,
					"full_scale_delta_neutral": neutral,
					"continuous_nonovershooting_scale_cap": continuous_cap,
					"predecessor_projection": predecessor.duplicate(true),
				}
			)
		)

	var target_common_pre_scale := _binary32_floor_v1(
		clampf(continuous_target_common_scale, 0.0, 1.0)
	)
	var target_scale_refinement_count := 0
	var target_representational_zero_hold := false
	var application_projection := _joint_target_monotone_population_application_projection_v1(
		original_requests,
		base_joint_projections,
		source_angular_velocity_by_body_id,
		inverse_inertia_tensor_by_body_id,
		source_semantic_step,
		inner_projection_target_value,
		target_common_pre_scale,
	)
	if not bool(application_projection.get("ok", false)):
		return _failure(
			"QSDK_R24D107_TARGET_MONOTONE_APPLICATION_INVALID",
			application_projection,
		)
	while (
		not bool(application_projection.get("all_joint_target_errors_nonincreasing", false))
		or int(application_projection.get("joint_target_crossing_count", -1)) != 0
	):
		if (
			target_common_pre_scale <= 0.0
			or target_scale_refinement_count
			>= NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
		):
			target_common_pre_scale = 0.0
			target_representational_zero_hold = true
			application_projection = _joint_target_monotone_population_application_projection_v1(
				original_requests,
				base_joint_projections,
				source_angular_velocity_by_body_id,
				inverse_inertia_tensor_by_body_id,
				source_semantic_step,
				inner_projection_target_value,
				0.0,
			)
			break
		var scale_bits := _binary32_bits_v1(target_common_pre_scale)
		target_common_pre_scale = (
			_binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
		)
		target_scale_refinement_count += 1
		application_projection = _joint_target_monotone_population_application_projection_v1(
			original_requests,
			base_joint_projections,
			source_angular_velocity_by_body_id,
			inverse_inertia_tensor_by_body_id,
			source_semantic_step,
			inner_projection_target_value,
			target_common_pre_scale,
		)
		if not bool(application_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D107_TARGET_MONOTONE_REFINEMENT_APPLICATION_INVALID",
				application_projection,
			)
	if (
		not bool(application_projection.get("ok", false))
		or not bool(application_projection.get("all_joint_target_errors_nonincreasing", false))
		or int(application_projection.get("joint_target_crossing_count", -1)) != 0
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_TERMINAL_INVALID")
	var body_guard_population: Dictionary = application_projection["body_guard_population_projection"]
	var body_guard_common_scale := float(body_guard_population["common_applied_scale"])
	var nominal_composed_common_scale := target_common_pre_scale * body_guard_common_scale
	return {
		"schema_version": JOINT_TARGET_MONOTONE_POPULATION_GUARD_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"allocation_rule_id":
		"canonical_joint_identity_order_neutral_whole_population_target_monotone_pre_scale_then_r103_body_guard_v1",
		"target_monotone_rule_id":
		"binary32_floor_minimum_first_nonovershooting_joint_target_scale_with_population_hold_v1",
		"body_application_rule_id": "one_validated_aggregate_torque_impulse_per_nonzero_body_v1",
		"source_semantic_step": source_semantic_step,
		"inner_projection_target": (inner_projection_target_value as Dictionary).duplicate(true),
		"ordered_actuator_ids": ORDERED_ACTUATOR_IDS.duplicate(),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"actuator_count": ORDERED_ACTUATOR_IDS.size(),
		"body_count": ORDERED_BODY_IDS.size(),
		"continuous_target_common_scale": continuous_target_common_scale,
		"target_common_pre_scale": target_common_pre_scale,
		"target_common_pre_scale_binary32_hex":
		"0x%08x" % _binary32_bits_v1(target_common_pre_scale),
		"target_scale_refinement_count": target_scale_refinement_count,
		"target_guard_engaged": target_common_pre_scale < 1.0,
		"population_zero_hold_for_nonhelpful_joint_delta": nonhelpful_projection_count > 0,
		"target_representational_zero_hold": target_representational_zero_hold,
		"helpful_joint_projection_count": helpful_projection_count,
		"neutral_joint_projection_count": neutral_projection_count,
		"nonhelpful_joint_projection_count": nonhelpful_projection_count,
		"body_guard_common_applied_scale": body_guard_common_scale,
		"nominal_composed_common_scale": nominal_composed_common_scale,
		"ordered_joint_target_projections":
		application_projection["ordered_joint_target_projections"],
		"body_guard_population_projection": body_guard_population,
		"nonzero_body_impulse_count": int(body_guard_population["nonzero_body_impulse_count"]),
		"all_joint_target_errors_nonincreasing": true,
		"joint_target_crossing_count": 0,
		"all_predicted_inside_outer_guard":
		bool(body_guard_population["all_predicted_inside_outer_guard"]),
		"input_iteration_order_has_action_authority": false,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _joint_target_monotone_population_application_projection_v1(
	original_requests: Array,
	base_joint_projections: Array,
	source_angular_velocity_by_body_id: Dictionary,
	inverse_inertia_tensor_by_body_id: Dictionary,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
	target_common_pre_scale: float,
) -> Dictionary:
	if (
		not is_finite(target_common_pre_scale)
		or target_common_pre_scale < 0.0
		or target_common_pre_scale > 1.0
		or original_requests.size() != ORDERED_ACTUATOR_IDS.size()
		or base_joint_projections.size() != ORDERED_ACTUATOR_IDS.size()
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_APPLICATION_BINDING_INVALID")
	var scaled_requests: Array = []
	for request_value in original_requests:
		if not (request_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_APPLICATION_REQUEST_INVALID")
		var request: Dictionary = request_value
		var original_child_value: Variant = request.get("requested_child_impulse_world_nms")
		if not (original_child_value is Vector3):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_APPLICATION_IMPULSE_INVALID")
		var scaled_child := (original_child_value as Vector3) * target_common_pre_scale
		(
			scaled_requests
			. append(
				{
					"actuator_index": int(request["actuator_index"]),
					"actuator_id": String(request["actuator_id"]),
					"joint_id": String(request["joint_id"]),
					"parent_body_id": String(request["parent_body_id"]),
					"child_body_id": String(request["child_body_id"]),
					"requested_parent_impulse_world_nms": -scaled_child,
					"requested_child_impulse_world_nms": scaled_child,
				}
			)
		)
	var body_guard_population := order_neutral_population_guard_projection_v1(
		scaled_requests,
		source_angular_velocity_by_body_id,
		inverse_inertia_tensor_by_body_id,
		source_semantic_step,
		inner_projection_target_value,
	)
	if not bool(body_guard_population.get("ok", false)):
		return _failure(
			"QSDK_R24D107_TARGET_MONOTONE_BODY_GUARD_PROJECTION_INVALID",
			body_guard_population,
		)
	var body_guard_validation := validate_order_neutral_population_guard_projection_v1(
		body_guard_population
	)
	if not bool(body_guard_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D107_TARGET_MONOTONE_BODY_GUARD_INVALID",
			body_guard_validation,
		)
	body_guard_population = body_guard_validation["projection"]
	var final_body_by_id: Dictionary = {}
	for body_value in body_guard_population["ordered_body_projections"]:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_FINAL_BODY_INVALID")
		var body: Dictionary = body_value
		final_body_by_id[String(body.get("body_id", ""))] = body
	if final_body_by_id.size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D107_TARGET_MONOTONE_FINAL_BODY_POPULATION_INVALID")
	var body_guard_common_scale := float(body_guard_population["common_applied_scale"])
	var ordered_joint_target_projections: Array = []
	var all_nonincreasing := true
	var crossing_count := 0
	for actuator_index in range(base_joint_projections.size()):
		var base_value: Variant = base_joint_projections[actuator_index]
		if not (base_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_BASE_JOINT_INVALID")
		var base: Dictionary = base_value
		var parent_body: Dictionary = final_body_by_id[String(base["parent_body_id"])]
		var child_body: Dictionary = final_body_by_id[String(base["child_body_id"])]
		var parent_delta := (
			_vec3(parent_body["predicted_angular_velocity_world_rad_s"])
			- _vec3(parent_body["source_angular_velocity_world_rad_s"])
		)
		var child_delta := (
			_vec3(child_body["predicted_angular_velocity_world_rad_s"])
			- _vec3(child_body["source_angular_velocity_world_rad_s"])
		)
		var axis_world := _vec3(base["axis_world"])
		var applied_relative_velocity_delta := (child_delta - parent_delta).dot(axis_world)
		var source_relative_velocity := float(base["measured_pre_step_relative_velocity_rad_s"])
		var target_velocity := float(base["canonical_target_velocity_rad_s"])
		var predicted_relative_velocity := source_relative_velocity + applied_relative_velocity_delta
		var source_error := target_velocity - source_relative_velocity
		var predicted_error := target_velocity - predicted_relative_velocity
		var nonincreasing := absf(predicted_error) <= absf(source_error)
		var crossed := source_error * predicted_error < 0.0
		if (
			not is_finite(applied_relative_velocity_delta)
			or not is_finite(predicted_relative_velocity)
			or not is_finite(predicted_error)
		):
			return _failure(
				"QSDK_R24D107_TARGET_MONOTONE_FINAL_JOINT_INVALID:%d" % actuator_index
			)
		all_nonincreasing = all_nonincreasing and nonincreasing
		crossing_count += int(crossed)
		var joint_projection := base.duplicate(true)
		joint_projection["target_common_pre_scale"] = target_common_pre_scale
		joint_projection["target_common_pre_scale_binary32_hex"] = (
			"0x%08x" % _binary32_bits_v1(target_common_pre_scale)
		)
		joint_projection["body_guard_common_applied_scale"] = body_guard_common_scale
		joint_projection["applied_relative_velocity_delta_rad_s"] = (
			applied_relative_velocity_delta
		)
		joint_projection["predicted_relative_velocity_rad_s"] = predicted_relative_velocity
		joint_projection["predicted_target_error_rad_s"] = predicted_error
		joint_projection["absolute_target_error_nonincreasing"] = nonincreasing
		joint_projection["target_crossed"] = crossed
		ordered_joint_target_projections.append(joint_projection)
	return {
		"ok": true,
		"target_common_pre_scale": target_common_pre_scale,
		"body_guard_population_projection": body_guard_population,
		"ordered_joint_target_projections": ordered_joint_target_projections,
		"all_joint_target_errors_nonincreasing": all_nonincreasing,
		"joint_target_crossing_count": crossing_count,
	}


static func validate_joint_target_monotone_population_guard_projection_v1(
	population_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = population_projection.get("inner_projection_target")
	var joint_values: Variant = population_projection.get("ordered_joint_target_projections")
	var body_guard_value: Variant = population_projection.get("body_guard_population_projection")
	if (
		not (target_value is Dictionary)
		or not (joint_values is Array)
		or not (body_guard_value is Dictionary)
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_SOURCE_MISSING")
	var predecessors: Array = []
	for joint_value in joint_values:
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_JOINT_INVALID")
		var predecessor_value: Variant = (joint_value as Dictionary).get("predecessor_projection")
		if not (predecessor_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_PREDECESSOR_MISSING")
		predecessors.append(predecessor_value)
	var body_guard: Dictionary = body_guard_value
	var body_values: Variant = body_guard.get("ordered_body_projections")
	if not (body_values is Array):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_BODY_SOURCE_MISSING")
	var source_by_body_id: Dictionary = {}
	var inertia_by_body_id: Dictionary = {}
	for body_value in body_values:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_BODY_INVALID")
		var body: Dictionary = body_value
		var body_id := String(body.get("body_id", ""))
		if body_id.is_empty() or source_by_body_id.has(body_id):
			return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_BODY_ID_INVALID")
		source_by_body_id[body_id] = _vec3(body.get("source_angular_velocity_world_rad_s"))
		inertia_by_body_id[body_id] = _basis_from_json_v1(
			body.get("inverse_inertia_tensor_world_kg_inv_m2")
		)
	var expected := joint_target_monotone_population_guard_projection_v1(
		predecessors,
		source_by_body_id,
		inertia_by_body_id,
		int(population_projection.get("source_semantic_step", -1)),
		target_value,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(population_projection, expected)
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d107_joint_target_monotone_population_guard_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R109 replaces the fixed R87 impulse direction with one deterministic coupled
## joint-space solve. The portable controller targets, published S169 caps,
## canonical actuator identities, R103 body guard, aggregate body application,
## and native outer-guard readback authority remain unchanged.
static func joint_space_effective_inertia_population_guard_projection_v1(
	predecessor_projection_values: Array,
	source_angular_velocity_by_body_id: Dictionary,
	inverse_inertia_tensor_by_body_id: Dictionary,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
) -> Dictionary:
	if (
		source_semantic_step < 1
		or not (inner_projection_target_value is Dictionary)
		or predecessor_projection_values.size() != ORDERED_ACTUATOR_IDS.size()
		or source_angular_velocity_by_body_id.size() != ORDERED_BODY_IDS.size()
		or inverse_inertia_tensor_by_body_id.size() != ORDERED_BODY_IDS.size()
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_BINDING_INVALID")
	var inner_projection_target: Dictionary = inner_projection_target_value
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		inner_projection_target.get("outer_guard_limit_projection")
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(inner_projection_target, expected_target)
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_TARGET_INVALID")

	var source_by_body_id: Dictionary = {}
	var inertia_by_body_id: Dictionary = {}
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var source_value: Variant = source_angular_velocity_by_body_id.get(body_id)
		var inertia_value: Variant = inverse_inertia_tensor_by_body_id.get(body_id)
		if not (source_value is Vector3) or not (inertia_value is Basis):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_BODY_SOURCE_MISSING:%s" % body_id)
		var source: Vector3 = source_value
		var inverse_inertia: Basis = inertia_value
		var outer_relation := angular_velocity_component_norm_limit_relation_v1(
			source, outer_guard_limit
		)
		if (
			not source.is_finite()
			or not _basis_is_finite_v1(inverse_inertia)
			or inverse_inertia.determinant() <= 0.0
			or not bool(outer_relation.get("ok", false))
			or not bool(outer_relation.get("inside_or_on_limit", false))
		):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_BODY_SOURCE_INVALID:%s" % body_id)
		source_by_body_id[body_id] = source
		inertia_by_body_id[body_id] = inverse_inertia

	var predecessor_by_index: Dictionary = {}
	for predecessor_value in predecessor_projection_values:
		if not (predecessor_value is Dictionary):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_PREDECESSOR_INVALID")
		var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
			predecessor_value
		)
		if not bool(predecessor_validation.get("ok", false)):
			return _failure(
				"QSDK_R24D109_EFFECTIVE_INERTIA_PREDECESSOR_VALIDATION_FAILED",
				predecessor_validation,
			)
		var predecessor: Dictionary = predecessor_validation["projection"]
		var actuator_index := int(predecessor.get("actuator_index", -1))
		if (
			actuator_index < 0
			or actuator_index >= ORDERED_ACTUATOR_IDS.size()
			or predecessor_by_index.has(actuator_index)
			or int(predecessor.get("source_semantic_step", -1)) != source_semantic_step
			or int(predecessor.get("maximum_representation_projection_iterations", -1))
			!= FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS
		):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_PREDECESSOR_BINDING_INVALID")
		predecessor_by_index[actuator_index] = predecessor
	if predecessor_by_index.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_PREDECESSOR_POPULATION_INCOMPLETE")

	var ordered_predecessors: Array = []
	var base_joint_projections: Array = []
	var source_target_error: Array = []
	for actuator_index in range(ORDERED_ACTUATOR_IDS.size()):
		var predecessor: Dictionary = predecessor_by_index[actuator_index]
		var parent_body_id := String(predecessor["parent_body_id"])
		var child_body_id := String(predecessor["child_body_id"])
		var axis_world := _vec3(predecessor["axis_world"])
		if (
			parent_body_id != String(ORDERED_PARENT_BODY_IDS[actuator_index])
			or child_body_id != String(ORDERED_CHILD_BODY_IDS[actuator_index])
			or not axis_world.is_finite()
		):
			return _failure(
				"QSDK_R24D109_EFFECTIVE_INERTIA_JOINT_BINDING_INVALID:%d" % actuator_index
			)
		var reconstructed_source_relative_velocity := _relative_axis_velocity_float64_v1(
			source_by_body_id[child_body_id],
			source_by_body_id[parent_body_id],
			axis_world,
		)
		var measured_source_relative_velocity := float(
			predecessor["measured_pre_step_relative_velocity_rad_s"]
		)
		var target_velocity := float(predecessor["canonical_target_velocity_rad_s"])
		var target_error := target_velocity - reconstructed_source_relative_velocity
		if (
			not is_finite(reconstructed_source_relative_velocity)
			or not is_finite(measured_source_relative_velocity)
			or not is_finite(target_velocity)
			or not is_finite(target_error)
		):
			return _failure(
				"QSDK_R24D109_EFFECTIVE_INERTIA_JOINT_SOURCE_INVALID:%d" % actuator_index
			)
		ordered_predecessors.append(predecessor)
		source_target_error.append(target_error)
		base_joint_projections.append(
			{
				"actuator_index": actuator_index,
				"actuator_id": String(predecessor["actuator_id"]),
				"joint_id": String(predecessor["joint_id"]),
				"parent_body_id": parent_body_id,
				"child_body_id": child_body_id,
				"source_semantic_step": source_semantic_step,
				"axis_world": predecessor["axis_world"],
				"canonical_target_velocity_rad_s": target_velocity,
				"measured_pre_step_relative_velocity_rad_s": measured_source_relative_velocity,
				"reconstructed_source_relative_velocity_rad_s":
				reconstructed_source_relative_velocity,
				"source_reconstruction_residual_rad_s":
				reconstructed_source_relative_velocity - measured_source_relative_velocity,
				"source_target_error_rad_s": target_error,
				"published_maximum_outer_step_impulse_nms":
				float(predecessor["published_maximum_outer_step_impulse_nms"]),
				"predecessor_projection": predecessor.duplicate(true),
			}
		)

	var response_matrix := _joint_space_effective_inertia_response_matrix_v1(
		base_joint_projections,
		inertia_by_body_id,
	)
	if not bool(response_matrix.get("ok", false)):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RESPONSE_INVALID", response_matrix)
	var raw_matrix: Array = response_matrix["response_matrix"]
	var symmetric_matrix: Array = response_matrix["symmetric_response_matrix"]
	var solve := _deterministic_cholesky_solve_v1(symmetric_matrix, source_target_error)
	if not bool(solve.get("ok", false)):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_CHOLESKY_INVALID", solve)
	var solved_impulses: Array = solve["solution"]
	var projected_error := _dense_matrix_vector_product_v1(symmetric_matrix, solved_impulses)
	if projected_error.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_SOLVE_PROJECTION_INVALID")
	var maximum_solve_residual := 0.0
	var continuous_cap_scale := 1.0
	var maximum_solution_to_cap_ratio := 0.0
	for actuator_index in range(ORDERED_ACTUATOR_IDS.size()):
		var solved_impulse := float(solved_impulses[actuator_index])
		var cap := float(
			(ordered_predecessors[actuator_index] as Dictionary)[
				"published_maximum_outer_step_impulse_nms"
			]
		)
		var ratio := absf(solved_impulse) / cap
		if (
			not is_finite(solved_impulse)
			or not is_finite(cap)
			or cap <= 0.0
			or not is_finite(ratio)
		):
			return _failure(
				"QSDK_R24D109_EFFECTIVE_INERTIA_SOLUTION_INVALID:%d" % actuator_index
			)
		maximum_solve_residual = maxf(
			maximum_solve_residual,
			absf(float(projected_error[actuator_index]) - float(source_target_error[actuator_index])),
		)
		maximum_solution_to_cap_ratio = maxf(maximum_solution_to_cap_ratio, ratio)
		if solved_impulse != 0.0:
			continuous_cap_scale = minf(continuous_cap_scale, cap / absf(solved_impulse))
	continuous_cap_scale = clampf(continuous_cap_scale, 0.0, 1.0)
	var cap_common_scale := _binary32_floor_v1(continuous_cap_scale)

	# Project the unscaled solve once through the unchanged R103 body guard to
	# obtain its independent full-solution scale. This is a pure calculation;
	# only the final re-projected body plan can reach the route's native writes.
	var unscaled_requests := _joint_space_effective_inertia_requests_v1(
		base_joint_projections,
		solved_impulses,
		1.0,
		false,
	)
	if not bool(unscaled_requests.get("ok", false)):
		return _failure(
			"QSDK_R24D109_EFFECTIVE_INERTIA_UNSCALED_REQUEST_INVALID", unscaled_requests
		)
	var unscaled_body_guard := order_neutral_population_guard_projection_v1(
		unscaled_requests["requests"],
		source_by_body_id,
		inertia_by_body_id,
		source_semantic_step,
		expected_target,
	)
	if not bool(unscaled_body_guard.get("ok", false)):
		return _failure(
			"QSDK_R24D109_EFFECTIVE_INERTIA_UNSCALED_BODY_GUARD_INVALID",
			unscaled_body_guard,
		)
	var unscaled_body_guard_validation := validate_order_neutral_population_guard_projection_v1(
		unscaled_body_guard
	)
	if not bool(unscaled_body_guard_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D109_EFFECTIVE_INERTIA_UNSCALED_BODY_GUARD_VALIDATION_FAILED",
			unscaled_body_guard_validation,
		)
	unscaled_body_guard = unscaled_body_guard_validation["projection"]
	var body_guard_candidate_scale := float(unscaled_body_guard["common_applied_scale"])
	var joint_space_common_pre_scale := _binary32_floor_v1(
		minf(cap_common_scale, body_guard_candidate_scale)
	)
	var representation_refinement_count := 0
	var representation_zero_hold := false
	var application_projection := _joint_space_effective_inertia_application_projection_v1(
		base_joint_projections,
		solved_impulses,
		source_by_body_id,
		inertia_by_body_id,
		source_semantic_step,
		expected_target,
		joint_space_common_pre_scale,
	)
	if not bool(application_projection.get("ok", false)):
		return _failure(
			"QSDK_R24D109_EFFECTIVE_INERTIA_APPLICATION_INVALID", application_projection
		)
	while (
		not bool(application_projection.get("all_joint_target_errors_nonincreasing", false))
		or int(application_projection.get("joint_target_crossing_count", -1)) != 0
	):
		if (
			joint_space_common_pre_scale <= 0.0
			or representation_refinement_count
			>= FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS
		):
			joint_space_common_pre_scale = 0.0
			representation_zero_hold = true
			application_projection = _joint_space_effective_inertia_application_projection_v1(
				base_joint_projections,
				solved_impulses,
				source_by_body_id,
				inertia_by_body_id,
				source_semantic_step,
				expected_target,
				0.0,
			)
			break
		var scale_bits := _binary32_bits_v1(joint_space_common_pre_scale)
		joint_space_common_pre_scale = (
			_binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
		)
		representation_refinement_count += 1
		application_projection = _joint_space_effective_inertia_application_projection_v1(
			base_joint_projections,
			solved_impulses,
			source_by_body_id,
			inertia_by_body_id,
			source_semantic_step,
			expected_target,
			joint_space_common_pre_scale,
		)
		if not bool(application_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D109_EFFECTIVE_INERTIA_REFINEMENT_APPLICATION_INVALID",
				application_projection,
			)
	if (
		not bool(application_projection.get("ok", false))
		or not bool(application_projection.get("all_joint_target_errors_nonincreasing", false))
		or int(application_projection.get("joint_target_crossing_count", -1)) != 0
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_TERMINAL_INVALID")
	var body_guard_population: Dictionary = application_projection[
		"body_guard_population_projection"
	]
	var body_guard_common_scale := float(body_guard_population["common_applied_scale"])
	var nominal_composed_common_scale := (
		joint_space_common_pre_scale * body_guard_common_scale
	)
	return {
		"schema_version": JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARD_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"allocation_rule_id":
		"canonical_joint_identity_order_neutral_coupled_effective_inverse_inertia_solve_then_r103_body_guard_v1",
		"response_matrix_rule_id":
		"symmetric_average_eight_joint_effective_inverse_inertia_response_v1",
		"solve_rule_id": "deterministic_cholesky_exact_joint_velocity_error_impulse_v1",
		"representation_rule_id":
		"canonical_order_binary32_body_aggregate_with_at_most_existing_sixteen_downward_common_scale_refinements_v1",
		"body_application_rule_id": "one_validated_aggregate_torque_impulse_per_nonzero_body_v1",
		"source_semantic_step": source_semantic_step,
		"inner_projection_target": expected_target.duplicate(true),
		"ordered_actuator_ids": ORDERED_ACTUATOR_IDS.duplicate(),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"actuator_count": ORDERED_ACTUATOR_IDS.size(),
		"body_count": ORDERED_BODY_IDS.size(),
		"response_matrix": raw_matrix.duplicate(true),
		"symmetric_response_matrix": symmetric_matrix.duplicate(true),
		"response_matrix_symmetry_maximum_absolute_residual":
		float(response_matrix["symmetry_maximum_absolute_residual"]),
		"cholesky_lower_factor": (solve["lower_factor"] as Array).duplicate(true),
		"cholesky_pivots": (solve["pivots"] as Array).duplicate(),
		"minimum_cholesky_pivot": float(solve["minimum_pivot"]),
		"solve_right_hand_side_rad_s": source_target_error.duplicate(),
		"solved_signed_joint_impulses_nms": solved_impulses.duplicate(),
		"solve_projected_right_hand_side_rad_s": projected_error.duplicate(),
		"maximum_solve_residual_rad_s": maximum_solve_residual,
		"maximum_solution_to_published_cap_ratio": maximum_solution_to_cap_ratio,
		"continuous_cap_common_scale": continuous_cap_scale,
		"cap_common_scale": cap_common_scale,
		"cap_common_scale_binary32_hex": "0x%08x" % _binary32_bits_v1(cap_common_scale),
		"body_guard_candidate_common_scale": body_guard_candidate_scale,
		"joint_space_common_pre_scale": joint_space_common_pre_scale,
		"joint_space_common_pre_scale_binary32_hex":
		"0x%08x" % _binary32_bits_v1(joint_space_common_pre_scale),
		"representation_refinement_count": representation_refinement_count,
		"maximum_representation_refinement_count":
		FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS,
		"representation_zero_hold": representation_zero_hold,
		"body_guard_common_applied_scale": body_guard_common_scale,
		"nominal_composed_common_scale": nominal_composed_common_scale,
		"solver_guard_engaged": nominal_composed_common_scale < 1.0,
		"ordered_joint_solve_projections":
		application_projection["ordered_joint_solve_projections"],
		"body_guard_population_projection": body_guard_population,
		"nonzero_body_impulse_count": int(body_guard_population["nonzero_body_impulse_count"]),
		"all_joint_target_errors_nonincreasing": true,
		"joint_target_crossing_count": 0,
		"all_predicted_inside_outer_guard":
		bool(body_guard_population["all_predicted_inside_outer_guard"]),
		"input_iteration_order_has_action_authority": false,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"outer_guard_changed": false,
		"controller_target_changed": false,
		"published_actuator_caps_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _joint_space_effective_inertia_response_matrix_v1(
	ordered_joint_projections: Array,
	inverse_inertia_tensor_by_body_id: Dictionary,
) -> Dictionary:
	if ordered_joint_projections.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D109_RESPONSE_JOINT_CARDINALITY_INVALID")
	var size := ordered_joint_projections.size()
	var response_matrix: Array = []
	for _row_index in range(size):
		var row_values: Array = []
		for _column_index in range(size):
			row_values.append(0.0)
		response_matrix.append(row_values)
	for column in range(size):
		var source_joint_value: Variant = ordered_joint_projections[column]
		if not (source_joint_value is Dictionary):
			return _failure("QSDK_R24D109_RESPONSE_SOURCE_JOINT_INVALID:%d" % column)
		var source_joint: Dictionary = source_joint_value
		var source_axis := _vec3(source_joint.get("axis_world"))
		var source_parent_id := String(source_joint.get("parent_body_id", ""))
		var source_child_id := String(source_joint.get("child_body_id", ""))
		if (
			not source_axis.is_finite()
			or not inverse_inertia_tensor_by_body_id.has(source_parent_id)
			or not inverse_inertia_tensor_by_body_id.has(source_child_id)
		):
			return _failure("QSDK_R24D109_RESPONSE_SOURCE_BINDING_INVALID:%d" % column)
		var body_delta_by_id: Dictionary = {}
		for body_id_value in ORDERED_BODY_IDS:
			body_delta_by_id[String(body_id_value)] = [0.0, 0.0, 0.0]
		body_delta_by_id[source_parent_id] = _basis_vector_components_float64_v1(
			inverse_inertia_tensor_by_body_id[source_parent_id], -source_axis
		)
		body_delta_by_id[source_child_id] = _basis_vector_components_float64_v1(
			inverse_inertia_tensor_by_body_id[source_child_id], source_axis
		)
		for row in range(size):
			var observed_joint_value: Variant = ordered_joint_projections[row]
			if not (observed_joint_value is Dictionary):
				return _failure("QSDK_R24D109_RESPONSE_OBSERVED_JOINT_INVALID:%d" % row)
			var observed_joint: Dictionary = observed_joint_value
			var observed_axis := _vec3(observed_joint.get("axis_world"))
			var observed_parent_id := String(observed_joint.get("parent_body_id", ""))
			var observed_child_id := String(observed_joint.get("child_body_id", ""))
			if (
				not observed_axis.is_finite()
				or not body_delta_by_id.has(observed_parent_id)
				or not body_delta_by_id.has(observed_child_id)
			):
				return _failure("QSDK_R24D109_RESPONSE_OBSERVED_BINDING_INVALID:%d" % row)
			var child_delta: Array = body_delta_by_id[observed_child_id]
			var parent_delta: Array = body_delta_by_id[observed_parent_id]
			var response_value := (
				(float(child_delta[0]) - float(parent_delta[0])) * float(observed_axis.x)
				+ (float(child_delta[1]) - float(parent_delta[1])) * float(observed_axis.y)
				+ (float(child_delta[2]) - float(parent_delta[2])) * float(observed_axis.z)
			)
			if not is_finite(response_value):
				return _failure("QSDK_R24D109_RESPONSE_NONFINITE:%d:%d" % [row, column])
			(response_matrix[row] as Array)[column] = response_value
	var symmetric_matrix: Array = []
	var maximum_symmetry_residual := 0.0
	for row in range(size):
		var symmetric_row: Array = []
		for column in range(size):
			var forward := float((response_matrix[row] as Array)[column])
			var reciprocal := float((response_matrix[column] as Array)[row])
			maximum_symmetry_residual = maxf(
				maximum_symmetry_residual, absf(forward - reciprocal)
			)
			symmetric_row.append(0.5 * (forward + reciprocal))
		symmetric_matrix.append(symmetric_row)
	return {
		"schema_version": "sporespore_qsdk_r24d109_joint_space_response_matrix_v1",
		"ok": true,
		"response_matrix": response_matrix,
		"symmetric_response_matrix": symmetric_matrix,
		"symmetry_maximum_absolute_residual": maximum_symmetry_residual,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _deterministic_cholesky_solve_v1(matrix: Array, right_hand_side: Array) -> Dictionary:
	var size := matrix.size()
	if size != ORDERED_ACTUATOR_IDS.size() or right_hand_side.size() != size:
		return _failure("QSDK_R24D109_CHOLESKY_SHAPE_INVALID")
	var lower: Array = []
	for row in range(size):
		var matrix_row_value: Variant = matrix[row]
		if not (matrix_row_value is Array) or (matrix_row_value as Array).size() != size:
			return _failure("QSDK_R24D109_CHOLESKY_ROW_SHAPE_INVALID:%d" % row)
		var lower_row: Array = []
		for _column in range(size):
			lower_row.append(0.0)
		lower.append(lower_row)
	var pivots: Array = []
	var minimum_pivot := INF
	for row in range(size):
		for column in range(row + 1):
			var residual := float((matrix[row] as Array)[column])
			for inner in range(column):
				residual -= float((lower[row] as Array)[inner]) * float(
					(lower[column] as Array)[inner]
				)
			if row == column:
				if not is_finite(residual) or residual <= 0.0:
					return _failure("QSDK_R24D109_CHOLESKY_NONPOSITIVE_PIVOT:%d" % row)
				pivots.append(residual)
				minimum_pivot = minf(minimum_pivot, residual)
				(lower[row] as Array)[column] = sqrt(residual)
			else:
				var diagonal := float((lower[column] as Array)[column])
				var value := residual / diagonal
				if not is_finite(value):
					return _failure("QSDK_R24D109_CHOLESKY_FACTOR_NONFINITE:%d:%d" % [row, column])
				(lower[row] as Array)[column] = value
	var forward: Array = []
	for row in range(size):
		var right_value := float(right_hand_side[row])
		if not is_finite(right_value):
			return _failure("QSDK_R24D109_CHOLESKY_RIGHT_NONFINITE:%d" % row)
		for column in range(row):
			right_value -= float((lower[row] as Array)[column]) * float(forward[column])
		var forward_value := right_value / float((lower[row] as Array)[row])
		if not is_finite(forward_value):
			return _failure("QSDK_R24D109_CHOLESKY_FORWARD_NONFINITE:%d" % row)
		forward.append(forward_value)
	var solution: Array = []
	for _index in range(size):
		solution.append(0.0)
	for reverse_index in range(size):
		var row := size - 1 - reverse_index
		var forward_value := float(forward[row])
		for column in range(row + 1, size):
			forward_value -= float((lower[column] as Array)[row]) * float(solution[column])
		var solution_value := forward_value / float((lower[row] as Array)[row])
		if not is_finite(solution_value):
			return _failure("QSDK_R24D109_CHOLESKY_SOLUTION_NONFINITE:%d" % row)
		solution[row] = solution_value
	return {
		"schema_version": "sporespore_qsdk_r24d109_deterministic_cholesky_solve_v1",
		"ok": true,
		"lower_factor": lower,
		"pivots": pivots,
		"minimum_pivot": minimum_pivot,
		"solution": solution,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _dense_matrix_vector_product_v1(matrix: Array, value: Array) -> Array:
	if matrix.size() != value.size():
		return []
	var result: Array = []
	for row in range(matrix.size()):
		var row_value: Variant = matrix[row]
		if not (row_value is Array) or (row_value as Array).size() != value.size():
			return []
		var total := 0.0
		for column in range(value.size()):
			total += float((row_value as Array)[column]) * float(value[column])
		if not is_finite(total):
			return []
		result.append(total)
	return result


static func _joint_space_effective_inertia_requests_v1(
	base_joint_projections: Array,
	solved_impulses: Array,
	common_scale: float,
	represent_binary32: bool,
) -> Dictionary:
	if (
		base_joint_projections.size() != ORDERED_ACTUATOR_IDS.size()
		or solved_impulses.size() != ORDERED_ACTUATOR_IDS.size()
		or not is_finite(common_scale)
		or common_scale < 0.0
		or common_scale > 1.0
	):
		return _failure("QSDK_R24D109_REQUEST_BINDING_INVALID")
	var requests: Array = []
	var represented_signed_impulses: Array = []
	for actuator_index in range(ORDERED_ACTUATOR_IDS.size()):
		var joint_value: Variant = base_joint_projections[actuator_index]
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D109_REQUEST_JOINT_INVALID:%d" % actuator_index)
		var joint: Dictionary = joint_value
		var axis_world := _vec3(joint.get("axis_world"))
		var signed_impulse := float(solved_impulses[actuator_index]) * common_scale
		if represent_binary32:
			signed_impulse = _binary32_v1(signed_impulse)
		var child_impulse := (
			_binary32_vector_scale_v1(axis_world, signed_impulse)
			if represent_binary32
			else axis_world * signed_impulse
		)
		if not axis_world.is_finite() or not is_finite(signed_impulse) or not child_impulse.is_finite():
			return _failure("QSDK_R24D109_REQUEST_IMPULSE_INVALID:%d" % actuator_index)
		represented_signed_impulses.append(signed_impulse)
		requests.append(
			{
				"actuator_index": actuator_index,
				"actuator_id": String(joint["actuator_id"]),
				"joint_id": String(joint["joint_id"]),
				"parent_body_id": String(joint["parent_body_id"]),
				"child_body_id": String(joint["child_body_id"]),
				"requested_parent_impulse_world_nms": -child_impulse,
				"requested_child_impulse_world_nms": child_impulse,
			}
		)
	return {
		"schema_version": "sporespore_qsdk_r24d109_joint_space_request_population_v1",
		"ok": true,
		"requests": requests,
		"represented_signed_impulses_nms": represented_signed_impulses,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _joint_space_effective_inertia_application_projection_v1(
	base_joint_projections: Array,
	solved_impulses: Array,
	source_angular_velocity_by_body_id: Dictionary,
	inverse_inertia_tensor_by_body_id: Dictionary,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
	joint_space_common_pre_scale: float,
) -> Dictionary:
	var request_projection := _joint_space_effective_inertia_requests_v1(
		base_joint_projections,
		solved_impulses,
		joint_space_common_pre_scale,
		true,
	)
	if not bool(request_projection.get("ok", false)):
		return _failure("QSDK_R24D109_APPLICATION_REQUEST_INVALID", request_projection)
	var body_guard_population := order_neutral_population_guard_projection_v1(
		request_projection["requests"],
		source_angular_velocity_by_body_id,
		inverse_inertia_tensor_by_body_id,
		source_semantic_step,
		inner_projection_target_value,
	)
	if not bool(body_guard_population.get("ok", false)):
		return _failure("QSDK_R24D109_APPLICATION_BODY_GUARD_INVALID", body_guard_population)
	var body_guard_validation := validate_order_neutral_population_guard_projection_v1(
		body_guard_population
	)
	if not bool(body_guard_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D109_APPLICATION_BODY_GUARD_VALIDATION_FAILED", body_guard_validation
		)
	body_guard_population = body_guard_validation["projection"]
	var final_body_by_id: Dictionary = {}
	for body_value in body_guard_population["ordered_body_projections"]:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D109_APPLICATION_BODY_INVALID")
		var body: Dictionary = body_value
		final_body_by_id[String(body.get("body_id", ""))] = body
	if final_body_by_id.size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D109_APPLICATION_BODY_POPULATION_INVALID")
	var represented_signed_impulses: Array = request_projection["represented_signed_impulses_nms"]
	var body_guard_common_scale := float(body_guard_population["common_applied_scale"])
	var ordered_joint_solve_projections: Array = []
	var all_nonincreasing := true
	var crossing_count := 0
	for actuator_index in range(base_joint_projections.size()):
		var base_value: Variant = base_joint_projections[actuator_index]
		if not (base_value is Dictionary):
			return _failure("QSDK_R24D109_APPLICATION_JOINT_INVALID:%d" % actuator_index)
		var base: Dictionary = base_value
		var parent_body: Dictionary = final_body_by_id[String(base["parent_body_id"])]
		var child_body: Dictionary = final_body_by_id[String(base["child_body_id"])]
		var axis_world := _vec3(base["axis_world"])
		var predicted_relative_velocity := _relative_axis_velocity_float64_v1(
			_vec3(child_body["predicted_angular_velocity_world_rad_s"]),
			_vec3(parent_body["predicted_angular_velocity_world_rad_s"]),
			axis_world,
		)
		var source_relative_velocity := float(
			base["reconstructed_source_relative_velocity_rad_s"]
		)
		var target_velocity := float(base["canonical_target_velocity_rad_s"])
		var source_error := target_velocity - source_relative_velocity
		var predicted_error := target_velocity - predicted_relative_velocity
		var applied_relative_velocity_delta := (
			predicted_relative_velocity - source_relative_velocity
		)
		var nonincreasing := absf(predicted_error) <= absf(source_error)
		var crossed := source_error * predicted_error < 0.0
		if (
			not is_finite(predicted_relative_velocity)
			or not is_finite(predicted_error)
			or not is_finite(applied_relative_velocity_delta)
		):
			return _failure("QSDK_R24D109_APPLICATION_TARGET_INVALID:%d" % actuator_index)
		all_nonincreasing = all_nonincreasing and nonincreasing
		crossing_count += int(crossed)
		var joint_projection := base.duplicate(true)
		joint_projection["solved_signed_joint_impulse_nms"] = float(
			solved_impulses[actuator_index]
		)
		joint_projection["joint_space_common_pre_scale"] = joint_space_common_pre_scale
		joint_projection["joint_space_common_pre_scale_binary32_hex"] = (
			"0x%08x" % _binary32_bits_v1(joint_space_common_pre_scale)
		)
		joint_projection["represented_requested_signed_joint_impulse_nms"] = float(
			represented_signed_impulses[actuator_index]
		)
		joint_projection["body_guard_common_applied_scale"] = body_guard_common_scale
		joint_projection["applied_relative_velocity_delta_rad_s"] = (
			applied_relative_velocity_delta
		)
		joint_projection["predicted_relative_velocity_rad_s"] = predicted_relative_velocity
		joint_projection["predicted_target_error_rad_s"] = predicted_error
		joint_projection["absolute_target_error_nonincreasing"] = nonincreasing
		joint_projection["target_crossed"] = crossed
		ordered_joint_solve_projections.append(joint_projection)
	return {
		"ok": true,
		"joint_space_common_pre_scale": joint_space_common_pre_scale,
		"body_guard_population_projection": body_guard_population,
		"ordered_joint_solve_projections": ordered_joint_solve_projections,
		"all_joint_target_errors_nonincreasing": all_nonincreasing,
		"joint_target_crossing_count": crossing_count,
	}


static func validate_joint_space_effective_inertia_population_guard_projection_v1(
	population_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = population_projection.get("inner_projection_target")
	var joint_values: Variant = population_projection.get("ordered_joint_solve_projections")
	var body_guard_value: Variant = population_projection.get("body_guard_population_projection")
	if (
		not (target_value is Dictionary)
		or not (joint_values is Array)
		or not (body_guard_value is Dictionary)
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_SOURCE_MISSING")
	var predecessors: Array = []
	for joint_value in joint_values:
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_JOINT_INVALID")
		var predecessor_value: Variant = (joint_value as Dictionary).get("predecessor_projection")
		if not (predecessor_value is Dictionary):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_PREDECESSOR_MISSING")
		predecessors.append(predecessor_value)
	var body_guard: Dictionary = body_guard_value
	var body_values: Variant = body_guard.get("ordered_body_projections")
	if not (body_values is Array):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_BODY_SOURCE_MISSING")
	var source_by_body_id: Dictionary = {}
	var inertia_by_body_id: Dictionary = {}
	for body_value in body_values:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_BODY_INVALID")
		var body: Dictionary = body_value
		var body_id := String(body.get("body_id", ""))
		if body_id.is_empty() or source_by_body_id.has(body_id):
			return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_BODY_ID_INVALID")
		source_by_body_id[body_id] = _vec3(body.get("source_angular_velocity_world_rad_s"))
		inertia_by_body_id[body_id] = _basis_from_json_v1(
			body.get("inverse_inertia_tensor_world_kg_inv_m2")
		)
	var expected := joint_space_effective_inertia_population_guard_projection_v1(
		predecessors,
		source_by_body_id,
		inertia_by_body_id,
		int(population_projection.get("source_semantic_step", -1)),
		target_value,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(population_projection, expected)
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guard_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _basis_vector_components_float64_v1(value: Basis, vector: Vector3) -> Array:
	return [
		float(value.x.x) * float(vector.x)
		+ float(value.y.x) * float(vector.y)
		+ float(value.z.x) * float(vector.z),
		float(value.x.y) * float(vector.x)
		+ float(value.y.y) * float(vector.y)
		+ float(value.z.y) * float(vector.z),
		float(value.x.z) * float(vector.x)
		+ float(value.y.z) * float(vector.y)
		+ float(value.z.z) * float(vector.z),
	]


static func _relative_axis_velocity_float64_v1(
	child_angular_velocity: Vector3,
	parent_angular_velocity: Vector3,
	axis_world: Vector3,
) -> float:
	return (
		(float(child_angular_velocity.x) - float(parent_angular_velocity.x)) * float(axis_world.x)
		+ (float(child_angular_velocity.y) - float(parent_angular_velocity.y)) * float(axis_world.y)
		+ (float(child_angular_velocity.z) - float(parent_angular_velocity.z)) * float(axis_world.z)
	)


static func _binary32_multiply_v1(left: float, right: float) -> float:
	return _binary32_v1(_binary32_v1(left) * _binary32_v1(right))


static func _binary32_vector_scale_v1(value: Vector3, scalar: float) -> Vector3:
	return Vector3(
		_binary32_multiply_v1(float(value.x), scalar),
		_binary32_multiply_v1(float(value.y), scalar),
		_binary32_multiply_v1(float(value.z), scalar),
	)


## Replays the finite R99 representable-scale refinement without mutating the
## frozen R99 projection or any physics state. The complete terminal predicate
## population is retained so a successor can distinguish arithmetic exhaustion
## from invalid input and prove whether a zero-impulse safety fallback is valid.
static func component_norm_guard_pair_refinement_diagnostic_v1(
	guard_limit: float,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	if (
		not is_finite(guard_limit)
		or guard_limit <= 0.0
		or not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not _basis_is_finite_v1(parent_inverse_inertia_tensor_world_kg_inv_m2)
		or not _basis_is_finite_v1(child_inverse_inertia_tensor_world_kg_inv_m2)
		or parent_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or child_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or not requested_parent_impulse_world_nms.is_finite()
		or not requested_child_impulse_world_nms.is_finite()
		or requested_parent_impulse_world_nms + requested_child_impulse_world_nms
		!= Vector3.ZERO
	):
		return _failure("QSDK_R24D100_REFINEMENT_DIAGNOSTIC_INPUT_INVALID")
	var parent_full_delta := (
		parent_inverse_inertia_tensor_world_kg_inv_m2
		* requested_parent_impulse_world_nms
	)
	var child_full_delta := (
		child_inverse_inertia_tensor_world_kg_inv_m2
		* requested_child_impulse_world_nms
	)
	var parent_interval := _angular_guard_scale_interval_component_norm_v1(
		parent_angular_velocity_world_rad_s,
		parent_full_delta,
		guard_limit,
	)
	var child_interval := _angular_guard_scale_interval_component_norm_v1(
		child_angular_velocity_world_rad_s,
		child_full_delta,
		guard_limit,
	)
	if not bool(parent_interval.get("ok", false)) or not bool(child_interval.get("ok", false)):
		return _failure(
			"QSDK_R24D100_REFINEMENT_DIAGNOSTIC_INTERVAL_INVALID",
			{"parent_interval": parent_interval, "child_interval": child_interval},
		)
	var feasible_lower := maxf(
		float(parent_interval["minimum_scale"]),
		float(child_interval["minimum_scale"]),
	)
	var feasible_upper := minf(
		float(parent_interval["maximum_scale"]),
		float(child_interval["maximum_scale"]),
	)
	if feasible_lower > feasible_upper:
		return _failure(
			"QSDK_R24D100_REFINEMENT_DIAGNOSTIC_PAIR_INTERVAL_EMPTY",
			{"feasible_lower": feasible_lower, "feasible_upper": feasible_upper},
		)
	var applied_scale := _binary32_floor_v1(clampf(feasible_upper, 0.0, 1.0))
	var initial_scale := applied_scale
	var refinement_count := 0
	var applied_child_impulse := requested_child_impulse_world_nms * applied_scale
	var applied_parent_impulse := -applied_child_impulse
	var predicted_parent := (
		parent_angular_velocity_world_rad_s
		+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
	)
	var predicted_child := (
		child_angular_velocity_world_rad_s
		+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
	)
	var predicted_parent_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, guard_limit
	)
	var predicted_child_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, guard_limit
	)
	while (
		(
			not bool(predicted_parent_relation.get("inside_or_on_limit", false))
			or not bool(predicted_child_relation.get("inside_or_on_limit", false))
		)
		and applied_scale > 0.0
		and refinement_count < NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
	):
		var scale_bits := _binary32_bits_v1(applied_scale)
		applied_scale = _binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
		applied_child_impulse = requested_child_impulse_world_nms * applied_scale
		applied_parent_impulse = -applied_child_impulse
		predicted_parent = (
			parent_angular_velocity_world_rad_s
			+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
		)
		predicted_child = (
			child_angular_velocity_world_rad_s
			+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
		)
		predicted_parent_relation = angular_velocity_component_norm_limit_relation_v1(
			predicted_parent, guard_limit
		)
		predicted_child_relation = angular_velocity_component_norm_limit_relation_v1(
			predicted_child, guard_limit
		)
		refinement_count += 1
	var terminal_predicates := {
		"parent_finite": predicted_parent.is_finite(),
		"child_finite": predicted_child.is_finite(),
		"parent_relation_ok": bool(predicted_parent_relation.get("ok", false)),
		"child_relation_ok": bool(predicted_child_relation.get("ok", false)),
		"scale_at_or_above_feasible_lower": applied_scale >= feasible_lower,
		"scale_at_or_below_one": applied_scale <= 1.0,
		"parent_inside_or_on_limit": bool(
			predicted_parent_relation.get("inside_or_on_limit", false)
		),
		"child_inside_or_on_limit": bool(
			predicted_child_relation.get("inside_or_on_limit", false)
		),
		"pairing_residual_zero": (
			applied_parent_impulse + applied_child_impulse == Vector3.ZERO
		),
	}
	var failed_terminal_predicates: Array = []
	for predicate_name in terminal_predicates:
		if not bool(terminal_predicates[predicate_name]):
			failed_terminal_predicates.append(String(predicate_name))
	var zero_parent_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, guard_limit
	)
	var zero_child_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, guard_limit
	)
	var zero_impulse_fallback_safe := (
		bool(zero_parent_relation.get("inside_or_on_limit", false))
		and bool(zero_child_relation.get("inside_or_on_limit", false))
	)
	return {
		"schema_version": COMPONENT_NORM_GUARD_REFINEMENT_DIAGNOSTIC_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"guard_limit_rad_s": guard_limit,
		"parent_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			parent_full_delta
		),
		"child_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			child_full_delta
		),
		"parent_feasible_scale_interval": parent_interval,
		"child_feasible_scale_interval": child_interval,
		"feasible_scale_lower": feasible_lower,
		"feasible_scale_upper": feasible_upper,
		"initial_scale": initial_scale,
		"initial_scale_binary32_hex": "0x%08x" % _binary32_bits_v1(initial_scale),
		"terminal_scale": applied_scale,
		"terminal_scale_binary32_hex": "0x%08x" % _binary32_bits_v1(applied_scale),
		"scale_refinement_limit": (
			NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
		),
		"scale_refinement_count": refinement_count,
		"scale_refinement_limit_exhausted": (
			refinement_count == NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
		),
		"terminal_predicted_parent_angular_velocity_world_rad_s": _vector_json(
			predicted_parent
		),
		"terminal_predicted_child_angular_velocity_world_rad_s": _vector_json(
			predicted_child
		),
		"terminal_parent_relation": predicted_parent_relation,
		"terminal_child_relation": predicted_child_relation,
		"terminal_predicates": terminal_predicates,
		"failed_terminal_predicates": failed_terminal_predicates,
		"terminal_projection_valid": failed_terminal_predicates.is_empty(),
		"zero_scale_parent_relation": zero_parent_relation,
		"zero_scale_child_relation": zero_child_relation,
		"zero_impulse_fallback_safe": zero_impulse_fallback_safe,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Versioned R99 successor to the R94 pair solver. Limits and impulses are
## unchanged; only the numerical relation used by interval, refinement, and
## final validation is replaced by the public component-norm primitive above.
static func native_angular_velocity_guard_pair_projection_v2(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	guard_projection_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	if (
		actuator_index < 0
		or actuator_index >= ORDERED_ACTUATOR_IDS.size()
		or actuator_id != String(ORDERED_ACTUATOR_IDS[actuator_index])
		or joint_id != String(ORDERED_JOINT_IDS[actuator_index])
		or parent_body_id != String(ORDERED_PARENT_BODY_IDS[actuator_index])
		or child_body_id != String(ORDERED_CHILD_BODY_IDS[actuator_index])
		or parent_body_id == child_body_id
		or source_semantic_step < 1
	):
		return _failure("QSDK_R24D99_GUARD_BINDING_INVALID:%d" % actuator_index)
	if not (guard_projection_value is Dictionary):
		return _failure("QSDK_R24D99_GUARD_LIMIT_PROJECTION_MISSING")
	var guard_projection: Dictionary = guard_projection_value
	var guard_limit := float(guard_projection.get("guard_limit_rad_s", NAN))
	var effective_limit := float(
		guard_projection.get("effective_max_angular_velocity_rad_s", NAN)
	)
	if (
		String(guard_projection.get("schema_version", ""))
		!= NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA
		or not bool(guard_projection.get("ok", false))
		or not bool(guard_projection.get("source_measurement", false))
		or not is_finite(guard_limit)
		or not is_finite(effective_limit)
		or guard_limit <= 0.0
		or guard_limit >= effective_limit
	):
		return _failure("QSDK_R24D99_GUARD_LIMIT_PROJECTION_INVALID")
	if (
		not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not _basis_is_finite_v1(parent_inverse_inertia_tensor_world_kg_inv_m2)
		or not _basis_is_finite_v1(child_inverse_inertia_tensor_world_kg_inv_m2)
		or parent_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or child_inverse_inertia_tensor_world_kg_inv_m2.determinant() <= 0.0
		or not requested_parent_impulse_world_nms.is_finite()
		or not requested_child_impulse_world_nms.is_finite()
		or requested_parent_impulse_world_nms + requested_child_impulse_world_nms
		!= Vector3.ZERO
	):
		return _failure("QSDK_R24D99_GUARD_SOURCE_INVALID:%d" % actuator_index)
	var parent_source_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, guard_limit
	)
	var child_source_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, guard_limit
	)
	var parent_effective_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, effective_limit
	)
	var child_effective_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, effective_limit
	)
	if (
		not bool(parent_source_relation.get("ok", false))
		or not bool(child_source_relation.get("ok", false))
		or not bool(parent_effective_relation.get("ok", false))
		or not bool(child_effective_relation.get("ok", false))
		or not bool(parent_effective_relation["inside_or_on_limit"])
		or not bool(child_effective_relation["inside_or_on_limit"])
	):
		return _failure("QSDK_R24D99_GUARD_SOURCE_LIMIT_INVALID:%d" % actuator_index)

	var parent_full_delta := (
		parent_inverse_inertia_tensor_world_kg_inv_m2
		* requested_parent_impulse_world_nms
	)
	var child_full_delta := (
		child_inverse_inertia_tensor_world_kg_inv_m2
		* requested_child_impulse_world_nms
	)
	if not parent_full_delta.is_finite() or not child_full_delta.is_finite():
		return _failure("QSDK_R24D99_GUARD_DELTA_INVALID:%d" % actuator_index)
	var parent_interval := _angular_guard_scale_interval_component_norm_v1(
		parent_angular_velocity_world_rad_s,
		parent_full_delta,
		guard_limit,
	)
	var child_interval := _angular_guard_scale_interval_component_norm_v1(
		child_angular_velocity_world_rad_s,
		child_full_delta,
		guard_limit,
	)
	if not bool(parent_interval.get("ok", false)) or not bool(child_interval.get("ok", false)):
		return _failure(
			"QSDK_R24D99_GUARD_NO_FEASIBLE_BODY_SCALE:%d" % actuator_index,
			{"parent_interval": parent_interval, "child_interval": child_interval},
		)
	var feasible_lower := maxf(
		float(parent_interval["minimum_scale"]),
		float(child_interval["minimum_scale"]),
	)
	var feasible_upper := minf(
		float(parent_interval["maximum_scale"]),
		float(child_interval["maximum_scale"]),
	)
	if feasible_lower > feasible_upper:
		return _failure(
			"QSDK_R24D99_GUARD_NO_FEASIBLE_PAIR_SCALE:%d" % actuator_index,
			{"feasible_lower": feasible_lower, "feasible_upper": feasible_upper},
		)
	var applied_scale := _binary32_floor_v1(clampf(feasible_upper, 0.0, 1.0))
	var refinement_count := 0
	var applied_child_impulse := requested_child_impulse_world_nms * applied_scale
	var applied_parent_impulse := -applied_child_impulse
	var predicted_parent := (
		parent_angular_velocity_world_rad_s
		+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
	)
	var predicted_child := (
		child_angular_velocity_world_rad_s
		+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
	)
	var predicted_parent_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, guard_limit
	)
	var predicted_child_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, guard_limit
	)
	while (
		(
			not bool(predicted_parent_relation.get("inside_or_on_limit", false))
			or not bool(predicted_child_relation.get("inside_or_on_limit", false))
		)
		and applied_scale > 0.0
		and refinement_count < NATIVE_ANGULAR_VELOCITY_GUARD_MAXIMUM_SCALE_REFINEMENTS
	):
		var scale_bits := _binary32_bits_v1(applied_scale)
		applied_scale = _binary32_from_bits_v1(scale_bits - 1) if scale_bits > 0 else 0.0
		applied_child_impulse = requested_child_impulse_world_nms * applied_scale
		applied_parent_impulse = -applied_child_impulse
		predicted_parent = (
			parent_angular_velocity_world_rad_s
			+ parent_inverse_inertia_tensor_world_kg_inv_m2 * applied_parent_impulse
		)
		predicted_child = (
			child_angular_velocity_world_rad_s
			+ child_inverse_inertia_tensor_world_kg_inv_m2 * applied_child_impulse
		)
		predicted_parent_relation = angular_velocity_component_norm_limit_relation_v1(
			predicted_parent, guard_limit
		)
		predicted_child_relation = angular_velocity_component_norm_limit_relation_v1(
			predicted_child, guard_limit
		)
		refinement_count += 1
	if (
		not predicted_parent.is_finite()
		or not predicted_child.is_finite()
		or not bool(predicted_parent_relation.get("ok", false))
		or not bool(predicted_child_relation.get("ok", false))
		or applied_scale < feasible_lower
		or applied_scale > 1.0
		or not bool(predicted_parent_relation["inside_or_on_limit"])
		or not bool(predicted_child_relation["inside_or_on_limit"])
		or applied_parent_impulse + applied_child_impulse != Vector3.ZERO
	):
		return _failure("QSDK_R24D99_GUARD_REFINEMENT_FAILED:%d" % actuator_index)
	return {
		"schema_version": COMPONENT_NORM_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"actuator_index": actuator_index,
		"actuator_id": actuator_id,
		"joint_id": joint_id,
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": source_semantic_step,
		"guard_limit_projection": guard_projection.duplicate(true),
		"effective_max_angular_velocity_rad_s": effective_limit,
		"guard_limit_rad_s": guard_limit,
		"parent_source_angular_velocity_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s
		),
		"child_source_angular_velocity_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s
		),
		"parent_source_angular_speed_rad_s": float(
			parent_source_relation["component_norm_rad_s"]
		),
		"child_source_angular_speed_rad_s": float(
			child_source_relation["component_norm_rad_s"]
		),
		"parent_source_guard_relation": parent_source_relation,
		"child_source_guard_relation": child_source_relation,
		"parent_source_effective_limit_relation": parent_effective_relation,
		"child_source_effective_limit_relation": child_effective_relation,
		"parent_inverse_inertia_tensor_world_kg_inv_m2": _basis_json_v1(
			parent_inverse_inertia_tensor_world_kg_inv_m2
		),
		"child_inverse_inertia_tensor_world_kg_inv_m2": _basis_json_v1(
			child_inverse_inertia_tensor_world_kg_inv_m2
		),
		"requested_parent_impulse_world_nms": _vector_json(
			requested_parent_impulse_world_nms
		),
		"requested_child_impulse_world_nms": _vector_json(
			requested_child_impulse_world_nms
		),
		"applied_parent_impulse_world_nms": _vector_json(applied_parent_impulse),
		"applied_child_impulse_world_nms": _vector_json(applied_child_impulse),
		"applied_pairing_residual_world_nms": _vector_json(
			applied_parent_impulse + applied_child_impulse
		),
		"parent_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			parent_full_delta
		),
		"child_full_scale_delta_angular_velocity_world_rad_s": _vector_json(
			child_full_delta
		),
		"parent_feasible_scale_interval": parent_interval,
		"child_feasible_scale_interval": child_interval,
		"feasible_scale_lower": feasible_lower,
		"feasible_scale_upper": feasible_upper,
		"applied_scale": applied_scale,
		"scale_binary32_hex": "0x%08x" % _binary32_bits_v1(applied_scale),
		"guard_engaged": applied_scale < 1.0,
		"scale_refinement_count": refinement_count,
		"predicted_parent_angular_velocity_world_rad_s": _vector_json(predicted_parent),
		"predicted_child_angular_velocity_world_rad_s": _vector_json(predicted_child),
		"predicted_parent_angular_speed_rad_s": float(
			predicted_parent_relation["component_norm_rad_s"]
		),
		"predicted_child_angular_speed_rad_s": float(
			predicted_child_relation["component_norm_rad_s"]
		),
		"predicted_parent_guard_relation": predicted_parent_relation,
		"predicted_child_guard_relation": predicted_child_relation,
		"both_predicted_inside_guard": true,
		"legacy_predicate_disagreement_observed": (
			bool(parent_source_relation["legacy_predicates_disagree"])
			or bool(child_source_relation["legacy_predicates_disagree"])
			or bool(predicted_parent_relation["legacy_predicates_disagree"])
			or bool(predicted_child_relation["legacy_predicates_disagree"])
		),
		"source_measurement": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R100 preserves every R99 input and successful projection. Only the exact
## terminal case in which the 64-ULP refinement exhausts with component-norm
## failures alone may select a zero-impulse hold, and only when the unmodified
## source pair is independently proven inside the same guard.
static func native_angular_velocity_guard_pair_projection_v3(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	guard_projection_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	var predecessor := native_angular_velocity_guard_pair_projection_v2(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		guard_projection_value,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	if bool(predecessor.get("ok", false)):
		var unchanged: Dictionary = predecessor.duplicate(true)
		unchanged["schema_version"] = (
			REFINEMENT_SAFE_COMPONENT_NORM_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
		)
		unchanged["r99_projection_succeeded"] = true
		unchanged["representational_zero_impulse_fallback"] = false
		unchanged["representational_fallback_reason"] = null
		unchanged["r99_predecessor_projection_failure"] = null
		unchanged["refinement_diagnostic"] = null
		return unchanged
	if (
		String(predecessor.get("failure_code", ""))
		!= "QSDK_R24D99_GUARD_REFINEMENT_FAILED:%d" % actuator_index
	):
		return predecessor
	if not (guard_projection_value is Dictionary):
		return _failure(
			"QSDK_R24D100_REFINEMENT_FAILURE_GUARD_MISSING:%d" % actuator_index,
			{"r99_predecessor_projection_failure": predecessor},
		)
	var guard_projection: Dictionary = guard_projection_value
	var diagnostic := component_norm_guard_pair_refinement_diagnostic_v1(
		float(guard_projection.get("guard_limit_rad_s", NAN)),
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	if not bool(diagnostic.get("ok", false)):
		return _failure(
			"QSDK_R24D100_REFINEMENT_DIAGNOSTIC_FAILED:%d" % actuator_index,
			{
				"r99_predecessor_projection_failure": predecessor,
				"refinement_diagnostic": diagnostic,
			},
		)
	var failed_predicates_value: Variant = diagnostic.get("failed_terminal_predicates")
	if not (failed_predicates_value is Array):
		return _failure(
			"QSDK_R24D100_REFINEMENT_DIAGNOSTIC_PREDICATES_INVALID:%d" % actuator_index,
			{"refinement_diagnostic": diagnostic},
		)
	var failed_predicates: Array = failed_predicates_value
	var component_norm_failures_only := not failed_predicates.is_empty()
	for predicate_value in failed_predicates:
		if String(predicate_value) not in [
			"parent_inside_or_on_limit",
			"child_inside_or_on_limit",
		]:
			component_norm_failures_only = false
	if (
		not component_norm_failures_only
		or bool(diagnostic.get("terminal_projection_valid", true))
		or not bool(diagnostic.get("scale_refinement_limit_exhausted", false))
		or not bool(diagnostic.get("zero_impulse_fallback_safe", false))
	):
		return _failure(
			"QSDK_R24D100_REFINEMENT_ZERO_IMPULSE_FALLBACK_UNSAFE:%d" % actuator_index,
			{
				"r99_predecessor_projection_failure": predecessor,
				"refinement_diagnostic": diagnostic,
			},
		)
	var zero_hold := native_angular_velocity_guard_pair_projection_v2(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		guard_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		Vector3.ZERO,
		Vector3.ZERO,
	)
	if not bool(zero_hold.get("ok", false)):
		return _failure(
			"QSDK_R24D100_REFINEMENT_ZERO_IMPULSE_PROJECTION_FAILED:%d" % actuator_index,
			{
				"r99_predecessor_projection_failure": predecessor,
				"refinement_diagnostic": diagnostic,
				"zero_impulse_projection_failure": zero_hold,
			},
		)
	var result: Dictionary = zero_hold.duplicate(true)
	result["schema_version"] = (
		REFINEMENT_SAFE_COMPONENT_NORM_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
	)
	result["requested_parent_impulse_world_nms"] = _vector_json(
		requested_parent_impulse_world_nms
	)
	result["requested_child_impulse_world_nms"] = _vector_json(
		requested_child_impulse_world_nms
	)
	result["parent_full_scale_delta_angular_velocity_world_rad_s"] = diagnostic[
		"parent_full_scale_delta_angular_velocity_world_rad_s"
	]
	result["child_full_scale_delta_angular_velocity_world_rad_s"] = diagnostic[
		"child_full_scale_delta_angular_velocity_world_rad_s"
	]
	result["parent_feasible_scale_interval"] = diagnostic[
		"parent_feasible_scale_interval"
	]
	result["child_feasible_scale_interval"] = diagnostic[
		"child_feasible_scale_interval"
	]
	result["feasible_scale_lower"] = float(diagnostic["feasible_scale_lower"])
	result["feasible_scale_upper"] = float(diagnostic["feasible_scale_upper"])
	result["applied_scale"] = 0.0
	result["scale_binary32_hex"] = "0x00000000"
	result["guard_engaged"] = true
	result["scale_refinement_count"] = int(diagnostic["scale_refinement_count"])
	result["r99_projection_succeeded"] = false
	result["representational_zero_impulse_fallback"] = true
	result["representational_fallback_reason"] = (
		"r99_binary32_scale_refinement_exhausted_component_norm_only"
	)
	result["r99_predecessor_projection_failure"] = predecessor.duplicate(true)
	result["refinement_diagnostic"] = diagnostic.duplicate(true)
	return result


## R99 preserves both frozen R96 boundaries while using the R99 component-norm
## relation for target solving, outer-hold classification, and final checks.
static func nested_native_angular_velocity_guard_pair_projection_v2(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	if not (inner_projection_target_value is Dictionary):
		return _failure("QSDK_R24D99_NESTED_PAIR_TARGET_MISSING")
	var inner_projection_target: Dictionary = inner_projection_target_value
	var outer_guard_value: Variant = inner_projection_target.get(
		"outer_guard_limit_projection"
	)
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(inner_projection_target, expected_target)
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_TARGET_INVALID")
	var outer_guard: Dictionary = expected_target["outer_guard_limit_projection"]
	var target_limit := float(expected_target["projection_target_limit_rad_s"])
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])
	var target_solver_projection: Dictionary = outer_guard.duplicate(true)
	target_solver_projection["guard_limit_rad_s"] = target_limit
	target_solver_projection["guard_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	var base := native_angular_velocity_guard_pair_projection_v2(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		target_solver_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	var parent_source_target_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, target_limit
	)
	var child_source_target_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, target_limit
	)
	var parent_source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, outer_guard_limit
	)
	var child_source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, outer_guard_limit
	)
	if (
		not bool(parent_source_target_relation.get("ok", false))
		or not bool(child_source_target_relation.get("ok", false))
		or not bool(parent_source_outer_relation.get("ok", false))
		or not bool(child_source_outer_relation.get("ok", false))
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_SOURCE_RELATION_INVALID")
	if not bool(base.get("ok", false)):
		var predecessor_failure_code := String(base.get("failure_code", ""))
		var outer_hold_allowed := (
			predecessor_failure_code.begins_with(
				"QSDK_R24D99_GUARD_NO_FEASIBLE_"
			)
			and bool(parent_source_outer_relation["inside_or_on_limit"])
			and bool(child_source_outer_relation["inside_or_on_limit"])
			and (
				bool(parent_source_target_relation["outside_limit"])
				or bool(child_source_target_relation["outside_limit"])
			)
		)
		if not outer_hold_allowed:
			return _failure(
				"QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED",
				{"predecessor_projection_failure": base},
			)
		base = native_angular_velocity_guard_pair_projection_v2(
			actuator_index,
			actuator_id,
			joint_id,
			parent_body_id,
			child_body_id,
			source_semantic_step,
			outer_guard,
			parent_angular_velocity_world_rad_s,
			child_angular_velocity_world_rad_s,
			parent_inverse_inertia_tensor_world_kg_inv_m2,
			child_inverse_inertia_tensor_world_kg_inv_m2,
			Vector3.ZERO,
			Vector3.ZERO,
		)
		if not bool(base.get("ok", false)):
			return _failure("QSDK_R24D99_NESTED_PAIR_OUTER_HOLD_FAILED", base)
		base["requested_parent_impulse_world_nms"] = _vector_json(
			requested_parent_impulse_world_nms
		)
		base["requested_child_impulse_world_nms"] = _vector_json(
			requested_child_impulse_world_nms
		)
		base["parent_full_scale_delta_angular_velocity_world_rad_s"] = _vector_json(
			parent_inverse_inertia_tensor_world_kg_inv_m2
			* requested_parent_impulse_world_nms
		)
		base["child_full_scale_delta_angular_velocity_world_rad_s"] = _vector_json(
			child_inverse_inertia_tensor_world_kg_inv_m2
			* requested_child_impulse_world_nms
		)
		base["applied_scale"] = 0.0
		base["scale_binary32_hex"] = "0x00000000"
		base["guard_engaged"] = true
		base["feasible_scale_lower"] = 0.0
		base["feasible_scale_upper"] = 0.0
		base["projection_target_feasible"] = false
		base["outer_guard_zero_impulse_hold"] = true
		base["outer_guard_hold_reason"] = (
			"source_inside_outer_guard_but_outside_inner_target_component_norm"
		)
	var result: Dictionary = base.duplicate(true)
	var predicted_parent := _vec3(
		result.get("predicted_parent_angular_velocity_world_rad_s")
	)
	var predicted_child := _vec3(
		result.get("predicted_child_angular_velocity_world_rad_s")
	)
	var predicted_parent_target_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, target_limit
	)
	var predicted_child_target_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, target_limit
	)
	var predicted_parent_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, outer_guard_limit
	)
	var predicted_child_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, outer_guard_limit
	)
	if (
		not bool(predicted_parent_target_relation.get("ok", false))
		or not bool(predicted_child_target_relation.get("ok", false))
		or not bool(predicted_parent_outer_relation.get("ok", false))
		or not bool(predicted_child_outer_relation.get("ok", false))
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_PREDICTED_RELATION_INVALID")
	var outer_hold := bool(result.get("outer_guard_zero_impulse_hold", false))
	if (
		(
			bool(predicted_parent_target_relation["outside_limit"])
			or bool(predicted_child_target_relation["outside_limit"])
		)
		and not outer_hold
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_TARGET_EXCEEDED")
	for obsolete_relation_key in [
		"parent_source_guard_relation",
		"child_source_guard_relation",
		"predicted_parent_guard_relation",
		"predicted_child_guard_relation",
	]:
		result.erase(obsolete_relation_key)
	result["schema_version"] = (
		COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
	)
	result["guard_limit_projection"] = outer_guard.duplicate(true)
	result["inner_projection_target"] = expected_target.duplicate(true)
	result["guard_limit_rad_s"] = outer_guard_limit
	result["projection_target_limit_rad_s"] = target_limit
	result["projection_target_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	result["parent_source_projection_target_relation"] = (
		parent_source_target_relation
	)
	result["child_source_projection_target_relation"] = child_source_target_relation
	result["parent_source_outer_guard_relation"] = parent_source_outer_relation
	result["child_source_outer_guard_relation"] = child_source_outer_relation
	result["predicted_parent_projection_target_relation"] = (
		predicted_parent_target_relation
	)
	result["predicted_child_projection_target_relation"] = (
		predicted_child_target_relation
	)
	result["predicted_parent_outer_guard_relation"] = predicted_parent_outer_relation
	result["predicted_child_outer_guard_relation"] = predicted_child_outer_relation
	result["both_predicted_inside_guard"] = (
		bool(predicted_parent_outer_relation["inside_or_on_limit"])
		and bool(predicted_child_outer_relation["inside_or_on_limit"])
	)
	result["both_predicted_inside_projection_target"] = (
		bool(predicted_parent_target_relation["inside_or_on_limit"])
		and bool(predicted_child_target_relation["inside_or_on_limit"])
	)
	result["projection_target_feasible"] = not outer_hold
	result["outer_guard_zero_impulse_hold"] = outer_hold
	result["projection_target_separated_from_native_readback_guard"] = true
	result["component_norm_numeric_predicate_required"] = true
	result["outer_guard_changed"] = false
	result["r24d95_observation_selected_margin"] = false
	return result


## R100 delegates every successful nested projection to frozen R99. Its sole
## new path is the refinement-only zero-impulse fallback proven by the v3 pair
## solver; target and outer-guard boundaries remain the frozen R96 values.
static func nested_native_angular_velocity_guard_pair_projection_v3(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	inner_projection_target_value: Variant,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	parent_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	child_inverse_inertia_tensor_world_kg_inv_m2: Basis,
	requested_parent_impulse_world_nms: Vector3,
	requested_child_impulse_world_nms: Vector3,
) -> Dictionary:
	var predecessor := nested_native_angular_velocity_guard_pair_projection_v2(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		inner_projection_target_value,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	if bool(predecessor.get("ok", false)):
		var unchanged: Dictionary = predecessor.duplicate(true)
		unchanged["schema_version"] = (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
		)
		unchanged["r99_projection_succeeded"] = true
		unchanged["representational_zero_impulse_fallback"] = false
		unchanged["representational_fallback_reason"] = null
		unchanged["r99_predecessor_projection_failure"] = null
		unchanged["refinement_diagnostic"] = null
		return unchanged
	var predecessor_detail_value: Variant = predecessor.get("detail")
	var pair_failure: Dictionary = {}
	if predecessor_detail_value is Dictionary:
		var pair_failure_value: Variant = (predecessor_detail_value as Dictionary).get(
			"predecessor_projection_failure"
		)
		if pair_failure_value is Dictionary:
			pair_failure = pair_failure_value
	if (
		String(predecessor.get("failure_code", ""))
		!= "QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED"
		or String(pair_failure.get("failure_code", ""))
		!= "QSDK_R24D99_GUARD_REFINEMENT_FAILED:%d" % actuator_index
	):
		return predecessor
	if not (inner_projection_target_value is Dictionary):
		return _failure("QSDK_R24D100_NESTED_PAIR_TARGET_MISSING")
	var inner_projection_target: Dictionary = inner_projection_target_value
	var outer_guard_value: Variant = inner_projection_target.get(
		"outer_guard_limit_projection"
	)
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(inner_projection_target, expected_target)
	):
		return _failure("QSDK_R24D100_NESTED_PAIR_TARGET_INVALID")
	var outer_guard: Dictionary = expected_target["outer_guard_limit_projection"]
	var target_limit := float(expected_target["projection_target_limit_rad_s"])
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])
	var target_solver_projection: Dictionary = outer_guard.duplicate(true)
	target_solver_projection["guard_limit_rad_s"] = target_limit
	target_solver_projection["guard_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	var base := native_angular_velocity_guard_pair_projection_v3(
		actuator_index,
		actuator_id,
		joint_id,
		parent_body_id,
		child_body_id,
		source_semantic_step,
		target_solver_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		parent_inverse_inertia_tensor_world_kg_inv_m2,
		child_inverse_inertia_tensor_world_kg_inv_m2,
		requested_parent_impulse_world_nms,
		requested_child_impulse_world_nms,
	)
	var parent_source_target_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, target_limit
	)
	var child_source_target_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, target_limit
	)
	var parent_source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, outer_guard_limit
	)
	var child_source_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, outer_guard_limit
	)
	if (
		not bool(parent_source_target_relation.get("ok", false))
		or not bool(child_source_target_relation.get("ok", false))
		or not bool(parent_source_outer_relation.get("ok", false))
		or not bool(child_source_outer_relation.get("ok", false))
	):
		return _failure("QSDK_R24D100_NESTED_PAIR_SOURCE_RELATION_INVALID")
	if not bool(base.get("ok", false)):
		return _failure(
			"QSDK_R24D100_NESTED_PAIR_TARGET_PROJECTION_FAILED",
			{"predecessor_projection_failure": base},
		)
	return _finalize_refinement_safe_component_norm_nested_pair_v1(
		base,
		expected_target,
		parent_source_target_relation,
		child_source_target_relation,
		parent_source_outer_relation,
		child_source_outer_relation,
	)


static func _finalize_refinement_safe_component_norm_nested_pair_v1(
	base: Dictionary,
	expected_target: Dictionary,
	parent_source_target_relation: Dictionary,
	child_source_target_relation: Dictionary,
	parent_source_outer_relation: Dictionary,
	child_source_outer_relation: Dictionary,
) -> Dictionary:
	var target_limit := float(expected_target["projection_target_limit_rad_s"])
	var outer_guard_limit := float(expected_target["outer_guard_limit_rad_s"])
	var predicted_parent := _vec3(
		base.get("predicted_parent_angular_velocity_world_rad_s")
	)
	var predicted_child := _vec3(
		base.get("predicted_child_angular_velocity_world_rad_s")
	)
	var predicted_parent_target_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, target_limit
	)
	var predicted_child_target_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, target_limit
	)
	var predicted_parent_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_parent, outer_guard_limit
	)
	var predicted_child_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		predicted_child, outer_guard_limit
	)
	if (
		not bool(predicted_parent_target_relation.get("ok", false))
		or not bool(predicted_child_target_relation.get("ok", false))
		or not bool(predicted_parent_outer_relation.get("ok", false))
		or not bool(predicted_child_outer_relation.get("ok", false))
		or not bool(predicted_parent_outer_relation["inside_or_on_limit"])
		or not bool(predicted_child_outer_relation["inside_or_on_limit"])
		or (
			bool(predicted_parent_target_relation["outside_limit"])
			or bool(predicted_child_target_relation["outside_limit"])
		)
	):
		return _failure("QSDK_R24D100_NESTED_PAIR_PREDICTED_RELATION_INVALID")
	var result: Dictionary = base.duplicate(true)
	for obsolete_relation_key in [
		"parent_source_guard_relation",
		"child_source_guard_relation",
		"predicted_parent_guard_relation",
		"predicted_child_guard_relation",
	]:
		result.erase(obsolete_relation_key)
	result["schema_version"] = (
		REFINEMENT_SAFE_COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
	)
	result["guard_limit_projection"] = (
		expected_target["outer_guard_limit_projection"] as Dictionary
	).duplicate(true)
	result["inner_projection_target"] = expected_target.duplicate(true)
	result["guard_limit_rad_s"] = outer_guard_limit
	result["projection_target_limit_rad_s"] = target_limit
	result["projection_target_limit_binary32_hex"] = String(
		expected_target["projection_target_limit_binary32_hex"]
	)
	result["parent_source_projection_target_relation"] = parent_source_target_relation
	result["child_source_projection_target_relation"] = child_source_target_relation
	result["parent_source_outer_guard_relation"] = parent_source_outer_relation
	result["child_source_outer_guard_relation"] = child_source_outer_relation
	result["predicted_parent_projection_target_relation"] = (
		predicted_parent_target_relation
	)
	result["predicted_child_projection_target_relation"] = predicted_child_target_relation
	result["predicted_parent_outer_guard_relation"] = predicted_parent_outer_relation
	result["predicted_child_outer_guard_relation"] = predicted_child_outer_relation
	result["both_predicted_inside_guard"] = true
	result["both_predicted_inside_projection_target"] = (
		bool(predicted_parent_target_relation["inside_or_on_limit"])
		and bool(predicted_child_target_relation["inside_or_on_limit"])
	)
	result["projection_target_feasible"] = true
	result["outer_guard_zero_impulse_hold"] = false
	result["projection_target_separated_from_native_readback_guard"] = true
	result["component_norm_numeric_predicate_required"] = true
	result["outer_guard_changed"] = false
	result["r24d95_observation_selected_margin"] = false
	return result


static func _basis_is_finite_v1(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


static func _basis_json_v1(value: Basis) -> Dictionary:
	return {
		"x": _vector_json(value.x),
		"y": _vector_json(value.y),
		"z": _vector_json(value.z),
	}


static func _basis_from_json_v1(value: Variant) -> Basis:
	if not (value is Dictionary):
		return Basis(
			Vector3(NAN, NAN, NAN),
			Vector3(NAN, NAN, NAN),
			Vector3(NAN, NAN, NAN),
		)
	var source: Dictionary = value
	return Basis(
		_vec3(source.get("x")),
		_vec3(source.get("y")),
		_vec3(source.get("z")),
	)


## Compile the exact recovery receipt into a JSON-safe native initializer plan.
## No Node, RID, model, or world is created here.
static func compile_blueprint_v1(sdk: Object, context: Dictionary) -> Dictionary:
	if sdk == null or not bool(context.get("ok", false)):
		return _failure("QSDK_R24D57_WORLD_CONTEXT_INVALID")
	var compiled_value: Variant = context.get("compiled_recovery_morphology")
	var profile_value: Variant = context.get("actuator_profile_resolution")
	if not (compiled_value is Dictionary) or not (profile_value is Dictionary):
		return _failure("QSDK_R24D57_WORLD_COMPILED_INPUT_MISSING")
	var compiled: Dictionary = compiled_value
	var profile_receipt: Dictionary = profile_value
	if (
		String(compiled.get("support_status", "")) != "supported_exact"
		or String(compiled.get("recovery_morphology_id", "")) != RECOVERY_MORPHOLOGY_ID
		or String(compiled.get("descriptor_sha256", "")) != RECOVERY_DESCRIPTOR_SHA256
		or String(compiled.get("recovery_morphology_spec_sha256", ""))
		!= RECOVERY_MORPHOLOGY_SPEC_SHA256
		or String(profile_receipt.get("support_status", "")) != "supported_exact"
		or String(profile_receipt.get("profile_sha256", "")) != ACTUATOR_PROFILE_SHA256
	):
		return _failure("QSDK_R24D57_WORLD_EXACT_IDENTITY_INVALID")

	var morphology_value: Variant = compiled.get("morphology")
	if not (morphology_value is Dictionary):
		return _failure("QSDK_R24D57_WORLD_MORPHOLOGY_MISSING")
	var morphology: Dictionary = morphology_value
	var spec_value: Variant = morphology.get("morphology_spec")
	if not (spec_value is Dictionary):
		return _failure("QSDK_R24D57_WORLD_SPEC_MISSING")
	var spec: Dictionary = spec_value
	if (
		not _ordered_strings_equal(morphology.get("ordered_body_ids"), ORDERED_BODY_IDS)
		or not _ordered_strings_equal(morphology.get("ordered_joint_ids"), ORDERED_JOINT_IDS)
		or not _ordered_strings_equal(morphology.get("ordered_actuator_ids"), ORDERED_ACTUATOR_IDS)
		or not _ordered_strings_equal(
			morphology.get("ordered_contact_site_ids"), ORDERED_CONTACT_SITE_IDS
		)
	):
		return _failure("QSDK_R24D57_WORLD_TOPOLOGY_ORDER_INVALID")
	var body_values: Variant = spec.get("bodies")
	var joint_values: Variant = spec.get("joints")
	var actuator_values: Variant = spec.get("actuators")
	var contact_values: Variant = spec.get("contact_sites")
	var limb_values: Variant = spec.get("limbs")
	if (
		not (body_values is Array)
		or not (joint_values is Array)
		or not (actuator_values is Array)
		or not (contact_values is Array)
		or not (limb_values is Array)
		or (body_values as Array).size() != 9
		or (joint_values as Array).size() != 8
		or (actuator_values as Array).size() != 8
		or (contact_values as Array).size() != 4
		or (limb_values as Array).size() != 4
	):
		return _failure("QSDK_R24D57_WORLD_TOPOLOGY_CARDINALITY_INVALID")

	var body_by_id: Dictionary = {}
	for body_value in body_values:
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D57_WORLD_BODY_RECORD_INVALID")
		var body: Dictionary = body_value
		var body_id := String(body.get("body_id", ""))
		if body_id.is_empty() or body_by_id.has(body_id):
			return _failure("QSDK_R24D57_WORLD_BODY_ID_INVALID")
		body_by_id[body_id] = body.duplicate(true)

	var contact_by_body_id: Dictionary = {}
	var contact_by_id: Dictionary = {}
	for contact_value in contact_values:
		if not (contact_value is Dictionary):
			return _failure("QSDK_R24D57_WORLD_CONTACT_RECORD_INVALID")
		var contact: Dictionary = contact_value
		var contact_id := String(contact.get("contact_site_id", ""))
		var contact_body_id := String(contact.get("body_id", ""))
		if (
			contact_id.is_empty()
			or contact_body_id.is_empty()
			or contact_by_id.has(contact_id)
			or contact_by_body_id.has(contact_body_id)
		):
			return _failure("QSDK_R24D57_WORLD_CONTACT_ID_INVALID")
		contact_by_id[contact_id] = contact.duplicate(true)
		contact_by_body_id[contact_body_id] = contact.duplicate(true)

	var profile_value_inner: Variant = profile_receipt.get("profile")
	if not (profile_value_inner is Dictionary):
		return _failure("QSDK_R24D57_WORLD_PROFILE_MISSING")
	var ordered_caps_value: Variant = (profile_value_inner as Dictionary).get("ordered_caps")
	if not (ordered_caps_value is Array) or (ordered_caps_value as Array).size() != 8:
		return _failure("QSDK_R24D57_WORLD_CAPS_INVALID")
	var cap_by_actuator_id: Dictionary = {}
	for index in range(8):
		var cap_value: Variant = (ordered_caps_value as Array)[index]
		if not (cap_value is Dictionary):
			return _failure("QSDK_R24D57_WORLD_CAP_RECORD_INVALID")
		var cap: Dictionary = cap_value
		if (
			String(cap.get("actuator_id", "")) != ORDERED_ACTUATOR_IDS[index]
			or String(cap.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or not is_finite(float(cap.get("maximum_outer_step_impulse_nms", NAN)))
			or float(cap.get("maximum_outer_step_impulse_nms", NAN)) <= 0.0
		):
			return _failure("QSDK_R24D57_WORLD_CAP_IDENTITY_INVALID:%d" % index)
		cap_by_actuator_id[ORDERED_ACTUATOR_IDS[index]] = cap.duplicate(true)

	var descriptor: Dictionary = compiled["descriptor"]
	var prone_pose: Dictionary = descriptor["canonical_prone_pose"]
	var joint_angles := {
		"front_left_hip": float(prone_pose["front_hip_angle_rad"]),
		"front_left_knee": float(prone_pose["front_knee_angle_rad"]),
		"front_right_hip": float(prone_pose["front_hip_angle_rad"]),
		"front_right_knee": float(prone_pose["front_knee_angle_rad"]),
		"rear_left_hip": float(prone_pose["rear_hip_angle_rad"]),
		"rear_left_knee": float(prone_pose["rear_knee_angle_rad"]),
		"rear_right_hip": float(prone_pose["rear_hip_angle_rad"]),
		"rear_right_knee": float(prone_pose["rear_knee_angle_rad"]),
	}
	var torso_collision: Dictionary = body_by_id["torso"]["collision"]
	var torso_size := _vec3(torso_collision.get("size_m"))
	if not torso_size.is_finite() or torso_size.y <= 0.0:
		return _failure("QSDK_R24D57_WORLD_TORSO_GEOMETRY_INVALID")
	var positions := {"torso": Vector3(0.0, torso_size.y * 0.5, 0.0)}
	var bases := {"torso": Basis.IDENTITY}
	var joint_by_id: Dictionary = {}
	for joint_value in joint_values:
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D57_WORLD_JOINT_RECORD_INVALID")
		var joint: Dictionary = joint_value
		var joint_id := String(joint.get("joint_id", ""))
		var parent_id := String(joint.get("parent_body_id", ""))
		var child_id := String(joint.get("child_body_id", ""))
		if (
			joint_by_id.has(joint_id)
			or not positions.has(parent_id)
			or not bases.has(parent_id)
			or not body_by_id.has(child_id)
			or not joint_angles.has(joint_id)
		):
			return _failure("QSDK_R24D57_WORLD_JOINT_GRAPH_INVALID:%s" % joint_id)
		var angle := float(joint_angles[joint_id])
		if (
			not is_finite(angle)
			or angle < float(joint.get("lower_limit_rad", NAN))
			or angle > float(joint.get("upper_limit_rad", NAN))
			or _vec3(joint.get("axis_parent_unit")) != Vector3.BACK
		):
			return _failure("QSDK_R24D57_WORLD_JOINT_AUTHORITY_INVALID:%s" % joint_id)
		var parent_basis: Basis = bases[parent_id]
		var child_basis := (parent_basis * Basis(Vector3.BACK, angle)).orthonormalized()
		var child_position := (
			(positions[parent_id] as Vector3)
			+ parent_basis * _vec3(joint.get("anchor_parent_m"))
			- child_basis * _vec3(joint.get("anchor_child_m"))
		)
		if not child_position.is_finite():
			return _failure("QSDK_R24D57_WORLD_CHILD_POSE_NONFINITE:%s" % child_id)
		positions[child_id] = child_position
		bases[child_id] = child_basis
		joint_by_id[joint_id] = joint.duplicate(true)

	if positions.size() != 9 or bases.size() != 9 or joint_by_id.size() != 8:
		return _failure("QSDK_R24D57_WORLD_POSE_INCOMPLETE")
	var ordered_body_poses: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var basis: Basis = bases[body_id]
		ordered_body_poses.append(
			{
				"body_id": body_id,
				"translation_m": _vector_json(positions[body_id]),
				"orientation_xyzw": _quaternion_json(basis.get_rotation_quaternion()),
				"rotation_about_z_rad": _signed_basis_angle_z(basis),
				"linear_velocity_m_s": _vector_json(Vector3.ZERO),
				"angular_velocity_rad_s": _vector_json(Vector3.ZERO),
			}
		)
	var ordered_joint_positions: Array = []
	for joint_id_value in ORDERED_JOINT_IDS:
		ordered_joint_positions.append(float(joint_angles[String(joint_id_value)]))
	var initializer_manifest := {
		"schema_version": "sporespore_godot_recovery_initializer_manifest_v1",
		"route_id": WORLD_ROUTE_ID,
		"portable_route_id": ROUTE_ID,
		"initializer_id": "exact_s169_ventral_prone_nominal_v1",
		"recovery_morphology_id": RECOVERY_MORPHOLOGY_ID,
		"recovery_descriptor_sha256": RECOVERY_DESCRIPTOR_SHA256,
		"recovery_morphology_spec_sha256": RECOVERY_MORPHOLOGY_SPEC_SHA256,
		"reference_pose_rule_id": String(
			(compiled["prone_geometry"] as Dictionary)["reference_pose_rule_id"]
		),
		"ordered_body_poses": ordered_body_poses,
		"ordered_joint_ids": ORDERED_JOINT_IDS.duplicate(),
		"ordered_joint_positions_rad": ordered_joint_positions,
		"direct_body_initialization_write_count": 9,
		"writes_completed_before_first_solver_step": true,
		"post_initialization_root_pose_write_count": 0,
		"post_initialization_root_velocity_write_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var initializer_sha256 := _sha256(sdk, initializer_manifest)
	if initializer_sha256.is_empty():
		return _failure("QSDK_R24D57_WORLD_INITIALIZER_DIGEST_FAILED")
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_recovery_world_blueprint_v1",
		"ok": true,
		"world_route_id": WORLD_ROUTE_ID,
		"spec": spec.duplicate(true),
		"body_by_id": body_by_id,
		"joint_by_id": joint_by_id,
		"contact_by_id": contact_by_id,
		"contact_by_body_id": contact_by_body_id,
		"cap_by_actuator_id": cap_by_actuator_id,
		"positions": positions,
		"bases": bases,
		"initializer_manifest": initializer_manifest,
		"initializer_manifest_sha256": initializer_sha256,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Project the exact S169 published cap into the greatest binary32 host value
## that cannot exceed it. Godot/Jolt stores this hinge parameter as binary32;
## the portable cap and validator remain unchanged binary64 values.
static func strict_host_impulse_cap_projection_v1(
	actuator_id: String,
	published_cap_nms: float,
) -> Dictionary:
	var actuator_index := ORDERED_ACTUATOR_IDS.find(actuator_id)
	if (
		actuator_index < 0
		or not is_finite(published_cap_nms)
		or published_cap_nms <= 0.0
		or published_cap_nms != float(ORDERED_PUBLISHED_CAPS_NMS[actuator_index])
	):
		return _failure("QSDK_R24D68_HOST_CAP_PROJECTION_INPUT_INVALID:%s" % actuator_id)
	var nearest_binary32 := float(PackedFloat32Array([published_cap_nms])[0])
	var expected_nearest := float(
		PackedFloat32Array([
			float(ORDERED_NEAREST_BINARY32_CAPS_NMS[actuator_index])
		])[0]
	)
	var configured_host_cap := float(
		PackedFloat32Array([
			float(ORDERED_STRICT_HOST_CAPS_NMS[actuator_index])
		])[0]
	)
	var configured_round_trip := float(PackedFloat32Array([configured_host_cap])[0])
	var nearest_rounds_above_published := nearest_binary32 > published_cap_nms
	if (
		nearest_binary32 != expected_nearest
		or configured_round_trip != configured_host_cap
		or configured_host_cap > published_cap_nms
		or nearest_rounds_above_published != (configured_host_cap != nearest_binary32)
	):
		return _failure(
			"QSDK_R24D68_HOST_CAP_PROJECTION_IDENTITY_INVALID:%s" % actuator_id,
			{
				"actuator_index": actuator_index,
				"published_cap_nms": published_cap_nms,
				"nearest_binary32_cap_nms": nearest_binary32,
				"expected_nearest_binary32_cap_nms": expected_nearest,
				"configured_host_cap_nms": configured_host_cap,
				"configured_round_trip_nms": configured_round_trip,
				"nearest_rounds_above_published": nearest_rounds_above_published,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d68_godot_strict_host_impulse_cap_projection_v1",
		"ok": true,
		"projection_id": STRICT_HOST_IMPULSE_CAP_PROJECTION_ID,
		"scope": "exact_s169_published_actuator_profile_only",
		"actuator_id": actuator_id,
		"actuator_index": actuator_index,
		"published_maximum_outer_step_impulse_nms": published_cap_nms,
		"nearest_binary32_cap_nms": nearest_binary32,
		"nearest_binary32_minus_published_nms": nearest_binary32 - published_cap_nms,
		"nearest_binary32_rounds_above_published": nearest_rounds_above_published,
		"configured_host_maximum_impulse_nms": configured_host_cap,
		"configured_host_cap_binary32_hex": String(
			ORDERED_STRICT_HOST_CAPS_BINARY32_HEX[actuator_index]
		),
		"published_minus_configured_host_cap_nms": (
			published_cap_nms - configured_host_cap
		),
		"binary32_floor_guard_applied": nearest_rounds_above_published,
		"configured_host_cap_not_above_published": configured_host_cap <= published_cap_nms,
		"published_cap_changed": false,
		"measurement_clamped": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Invert the complete frozen Godot/Jolt numeric path, not merely the public
## host field. Godot converts the binary32 host impulse to a binary32 torque by
## division through the nominal 120 Hz step; Jolt reconstructs the effective
## binary32 impulse with its native binary32 solver step. The selected host
## input is safe and its immediately adjacent binary32 value is not, proving
## maximality for the exact S169 profile without an empirical margin.
static func _binary32_bits_v1(value: float) -> int:
	return int(PackedFloat32Array([value]).to_byte_array().decode_u32(0))


static func _binary32_from_bits_v1(bits: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, bits)
	return float(bytes.decode_float(0))


static func _binary32_v1(value: float) -> float:
	return float(PackedFloat32Array([value])[0])


static func _binary32_floor_v1(value: float) -> float:
	var nearest := _binary32_v1(value)
	if nearest <= value:
		return 0.0 if nearest == 0.0 else nearest
	var bits := _binary32_bits_v1(nearest)
	bits += 1 if nearest < 0.0 else -1
	var projected := _binary32_from_bits_v1(bits)
	return 0.0 if projected == 0.0 else projected


static func _binary32_ceil_v1(value: float) -> float:
	var nearest := _binary32_v1(value)
	if nearest >= value:
		return 0.0 if nearest == 0.0 else nearest
	var bits := _binary32_bits_v1(nearest)
	bits += -1 if nearest < 0.0 else 1
	var projected := _binary32_from_bits_v1(bits)
	return 0.0 if projected == 0.0 else projected


## Project a canonical absolute joint interval into Godot's construction-relative
## hinge frame. The route's canonical-positive velocity is host-negative, so
## h = -(q - q0). Each endpoint is projected outward to binary32; the host
## representation can therefore widen, but never silently shrink, the
## canonical interval. This is a representation rule, not an empirical margin.
static func godot_initial_relative_joint_limit_projection_v1(
	joint_id: String,
	q0_rad: float,
	canonical_lower_rad: float,
	canonical_upper_rad: float,
	host_velocity_sign: float,
) -> Dictionary:
	if (
		ORDERED_JOINT_IDS.find(joint_id) < 0
		or not is_finite(q0_rad)
		or not is_finite(canonical_lower_rad)
		or not is_finite(canonical_upper_rad)
		or not is_finite(host_velocity_sign)
		or host_velocity_sign != CANONICAL_TO_GODOT_HOST_JOINT_SIGN
		or canonical_lower_rad > canonical_upper_rad
	):
		return _failure(
			"QSDK_R24D83_JOINT_LIMIT_PROJECTION_INPUT_INVALID:%s" % joint_id
		)
	var q0_binary32_lower := _binary32_floor_v1(canonical_lower_rad)
	var q0_binary32_upper := _binary32_ceil_v1(canonical_upper_rad)
	if (
		q0_rad < q0_binary32_lower
		or q0_rad > q0_binary32_upper
		or _binary32_v1(q0_rad) != q0_rad
	):
		return _failure(
			"QSDK_R24D83_JOINT_LIMIT_PROJECTION_Q0_INVALID:%s" % joint_id
		)
	var first_host_endpoint := host_velocity_sign * (canonical_lower_rad - q0_rad)
	var second_host_endpoint := host_velocity_sign * (canonical_upper_rad - q0_rad)
	var required_host_lower := minf(first_host_endpoint, second_host_endpoint)
	var required_host_upper := maxf(first_host_endpoint, second_host_endpoint)
	var projected_host_lower := _binary32_floor_v1(required_host_lower)
	var projected_host_upper := _binary32_ceil_v1(required_host_upper)
	var first_realizable_canonical := (
		q0_rad + projected_host_lower / host_velocity_sign
	)
	var second_realizable_canonical := (
		q0_rad + projected_host_upper / host_velocity_sign
	)
	var realizable_canonical_lower := minf(
		first_realizable_canonical, second_realizable_canonical
	)
	var realizable_canonical_upper := maxf(
		first_realizable_canonical, second_realizable_canonical
	)
	if (
		not is_finite(projected_host_lower)
		or not is_finite(projected_host_upper)
		or projected_host_lower > required_host_lower
		or projected_host_upper < required_host_upper
		or projected_host_lower > projected_host_upper
		or realizable_canonical_lower > canonical_lower_rad
		or realizable_canonical_upper < canonical_upper_rad
		or _binary32_v1(projected_host_lower) != projected_host_lower
		or _binary32_v1(projected_host_upper) != projected_host_upper
	):
		return _failure(
			"QSDK_R24D83_JOINT_LIMIT_PROJECTION_IDENTITY_INVALID:%s" % joint_id
		)
	return {
		"schema_version": GODOT_INITIAL_RELATIVE_JOINT_LIMIT_PROJECTION_SCHEMA,
		"ok": true,
		"projection_id": GODOT_INITIAL_RELATIVE_JOINT_LIMIT_PROJECTION_ID,
		"joint_id": joint_id,
		"q0_rad": q0_rad,
		"q0_binary32_lower_admissible_rad": q0_binary32_lower,
		"q0_binary32_upper_admissible_rad": q0_binary32_upper,
		"q0_is_exact_binary32": true,
		"canonical_lower_rad": canonical_lower_rad,
		"canonical_upper_rad": canonical_upper_rad,
		"canonical_to_host_velocity_sign": host_velocity_sign,
		"host_relative_angle_equation": "h = sign * (q - q0)",
		"required_host_lower_rad": required_host_lower,
		"required_host_upper_rad": required_host_upper,
		"projected_host_lower_rad": projected_host_lower,
		"projected_host_upper_rad": projected_host_upper,
		"projected_host_lower_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(projected_host_lower)
		),
		"projected_host_upper_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(projected_host_upper)
		),
		"realizable_canonical_lower_rad": realizable_canonical_lower,
		"realizable_canonical_upper_rad": realizable_canonical_upper,
		"lower_projection_outward_or_exact": (
			projected_host_lower <= required_host_lower
		),
		"upper_projection_outward_or_exact": (
			projected_host_upper >= required_host_upper
		),
		"canonical_interval_not_shrunk": (
			realizable_canonical_lower <= canonical_lower_rad
			and realizable_canonical_upper >= canonical_upper_rad
		),
		"canonical_limits_changed": false,
		"empirical_margin_added": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_godot_initial_relative_joint_limit_readback_v1(
	projection: Dictionary,
	host_lower_readback_rad: float,
	host_upper_readback_rad: float,
) -> Dictionary:
	var expected := godot_initial_relative_joint_limit_projection_v1(
		String(projection.get("joint_id", "")),
		float(projection.get("q0_rad", NAN)),
		float(projection.get("canonical_lower_rad", NAN)),
		float(projection.get("canonical_upper_rad", NAN)),
		float(projection.get("canonical_to_host_velocity_sign", NAN)),
	)
	if not bool(expected.get("ok", false)):
		return _failure("QSDK_R24D83_JOINT_LIMIT_READBACK_PROJECTION_INVALID")
	for field in [
		"schema_version",
		"projection_id",
		"required_host_lower_rad",
		"required_host_upper_rad",
		"projected_host_lower_rad",
		"projected_host_upper_rad",
		"projected_host_lower_binary32_hex",
		"projected_host_upper_binary32_hex",
		"realizable_canonical_lower_rad",
		"realizable_canonical_upper_rad",
		"canonical_interval_not_shrunk",
	]:
		if projection.get(field) != expected.get(field):
			return _failure(
				"QSDK_R24D83_JOINT_LIMIT_READBACK_RECEIPT_INVALID:%s"
				% String(projection.get("joint_id", ""))
			)
	if (
		not is_finite(host_lower_readback_rad)
		or not is_finite(host_upper_readback_rad)
		or host_lower_readback_rad != float(expected["projected_host_lower_rad"])
		or host_upper_readback_rad != float(expected["projected_host_upper_rad"])
	):
		return _failure(
			"QSDK_R24D83_JOINT_LIMIT_PROPERTY_READBACK_INVALID:%s"
			% String(projection.get("joint_id", ""))
		)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d83_godot_joint_limit_property_readback_v1"
		),
		"ok": true,
		"joint_id": String(expected["joint_id"]),
		"projected_host_lower_rad": float(expected["projected_host_lower_rad"]),
		"projected_host_upper_rad": float(expected["projected_host_upper_rad"]),
		"host_lower_readback_rad": host_lower_readback_rad,
		"host_upper_readback_rad": host_upper_readback_rad,
		"exact_projected_property_readback": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func godot_recovery_collision_filter_projection_v1() -> Dictionary:
	return validate_godot_recovery_collision_filter_readback_v1(
		RECOVERY_FLOOR_COLLISION_LAYER,
		RECOVERY_FLOOR_COLLISION_MASK,
		RECOVERY_ROBOT_COLLISION_LAYER,
		RECOVERY_ROBOT_COLLISION_MASK,
		RECOVERY_ROBOT_COLLISION_LAYER,
		RECOVERY_ROBOT_COLLISION_MASK,
	)


static func validate_godot_recovery_collision_filter_readback_v1(
	floor_layer: int,
	floor_mask: int,
	first_robot_layer: int,
	first_robot_mask: int,
	second_robot_layer: int,
	second_robot_mask: int,
) -> Dictionary:
	var exact_readback := (
		floor_layer == RECOVERY_FLOOR_COLLISION_LAYER
		and floor_mask == RECOVERY_FLOOR_COLLISION_MASK
		and first_robot_layer == RECOVERY_ROBOT_COLLISION_LAYER
		and first_robot_mask == RECOVERY_ROBOT_COLLISION_MASK
		and second_robot_layer == RECOVERY_ROBOT_COLLISION_LAYER
		and second_robot_mask == RECOVERY_ROBOT_COLLISION_MASK
	)
	var robot_floor_interacts := bool(
		(first_robot_mask & floor_layer) != 0
		or (floor_mask & first_robot_layer) != 0
	)
	var robot_robot_interacts := bool(
		(first_robot_mask & second_robot_layer) != 0
		or (second_robot_mask & first_robot_layer) != 0
	)
	if not exact_readback or not robot_floor_interacts or robot_robot_interacts:
		return _failure("QSDK_R24D83_COLLISION_FILTER_READBACK_INVALID")
	return {
		"schema_version": GODOT_RECOVERY_COLLISION_FILTER_SCHEMA,
		"ok": true,
		"floor": {"layer": floor_layer, "mask": floor_mask},
		"robot": {"layer": first_robot_layer, "mask": first_robot_mask},
		"robot_floor_collision_enabled": robot_floor_interacts,
		"robot_robot_collision_enabled": robot_robot_interacts,
		"exact_property_readback": true,
		"collision_exception_count": 0,
		"contact_relabel_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func native_effective_impulse_limit_projection_v1(
	actuator_id: String,
	published_cap_nms: float,
) -> Dictionary:
	var actuator_index := ORDERED_ACTUATOR_IDS.find(actuator_id)
	if (
		actuator_index < 0
		or not is_finite(published_cap_nms)
		or published_cap_nms <= 0.0
		or published_cap_nms != float(ORDERED_PUBLISHED_CAPS_NMS[actuator_index])
	):
		return _failure(
			"QSDK_R24D69_NATIVE_EFFECTIVE_LIMIT_PROJECTION_INPUT_INVALID:%s"
			% actuator_id
		)

	var native_solver_step := _binary32_v1(OUTER_STEP_DURATION_S)
	var nearest_host_cap := _binary32_v1(published_cap_nms)
	var nearest_host_bits := _binary32_bits_v1(nearest_host_cap)
	var configured_host_cap := NAN
	var configured_host_bits := -1
	var projected_native_torque_limit := NAN
	var projected_native_effective_limit := NAN
	var downward_binary32_step_count := -1
	for decrement in range(4):
		var candidate_bits := nearest_host_bits - decrement
		if candidate_bits <= 0:
			break
		var candidate_host_cap := _binary32_from_bits_v1(candidate_bits)
		var candidate_torque := _binary32_v1(
			candidate_host_cap / OUTER_STEP_DURATION_S
		)
		var candidate_effective := _binary32_v1(
			candidate_torque * native_solver_step
		)
		if candidate_effective <= published_cap_nms:
			configured_host_cap = candidate_host_cap
			configured_host_bits = candidate_bits
			projected_native_torque_limit = candidate_torque
			projected_native_effective_limit = candidate_effective
			downward_binary32_step_count = decrement
			break
	if downward_binary32_step_count < 0:
		return _failure(
			"QSDK_R24D69_NATIVE_EFFECTIVE_LIMIT_PROJECTION_SEARCH_EXHAUSTED:%s"
			% actuator_id,
			{
				"actuator_index": actuator_index,
				"published_cap_nms": published_cap_nms,
				"nearest_host_cap_nms": nearest_host_cap,
				"maximum_downward_binary32_step_count": 3,
			},
		)

	var next_host_bits := configured_host_bits + 1
	var next_binary32_host_cap := _binary32_from_bits_v1(next_host_bits)
	var next_projected_native_torque_limit := _binary32_v1(
		next_binary32_host_cap / OUTER_STEP_DURATION_S
	)
	var next_projected_native_effective_limit := _binary32_v1(
		next_projected_native_torque_limit * native_solver_step
	)
	if (
		configured_host_cap >= next_binary32_host_cap
		or projected_native_effective_limit > published_cap_nms
		or next_projected_native_effective_limit <= published_cap_nms
	):
		return _failure(
			"QSDK_R24D69_NATIVE_EFFECTIVE_LIMIT_PROJECTION_MAXIMALITY_INVALID:%s"
			% actuator_id,
			{
				"actuator_index": actuator_index,
				"published_cap_nms": published_cap_nms,
				"configured_host_cap_nms": configured_host_cap,
				"projected_native_torque_limit_nm": projected_native_torque_limit,
				"native_solver_step_s": native_solver_step,
				"projected_native_effective_limit_nms": (
					projected_native_effective_limit
				),
				"next_binary32_host_cap_nms": next_binary32_host_cap,
				"next_projected_native_effective_limit_nms": (
					next_projected_native_effective_limit
				),
			},
		)
	return {
		"schema_version": NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_SCHEMA,
		"ok": true,
		"projection_id": NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID,
		"scope": "exact_s169_published_actuator_profile_at_120_hz_only",
		"actuator_id": actuator_id,
		"actuator_index": actuator_index,
		"published_maximum_outer_step_impulse_nms": published_cap_nms,
		"nearest_binary32_host_maximum_impulse_nms": nearest_host_cap,
		"nearest_binary32_host_cap_binary32_hex": "0x%08x" % nearest_host_bits,
		"configured_host_maximum_impulse_nms": configured_host_cap,
		"configured_host_cap_binary32_hex": "0x%08x" % configured_host_bits,
		"nearest_to_configured_downward_binary32_step_count": (
			downward_binary32_step_count
		),
		"projected_native_maximum_torque_limit_nm": projected_native_torque_limit,
		"projected_native_torque_limit_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(projected_native_torque_limit)
		),
		"native_solver_step_s": native_solver_step,
		"native_solver_step_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(native_solver_step)
		),
		"projected_native_effective_impulse_limit_nms": (
			projected_native_effective_limit
		),
		"projected_native_effective_limit_binary32_hex": (
			"0x%08x" % _binary32_bits_v1(projected_native_effective_limit)
		),
		"native_effective_limit_not_above_published": (
			projected_native_effective_limit <= published_cap_nms
		),
		"next_binary32_host_maximum_impulse_nms": next_binary32_host_cap,
		"next_binary32_host_cap_binary32_hex": "0x%08x" % next_host_bits,
		"next_projected_native_maximum_torque_limit_nm": (
			next_projected_native_torque_limit
		),
		"next_projected_native_effective_impulse_limit_nms": (
			next_projected_native_effective_limit
		),
		"next_native_effective_limit_above_published": (
			next_projected_native_effective_limit > published_cap_nms
		),
		"configured_to_next_binary32_ulp_distance": 1,
		"selection_rule": (
			"greatest_binary32_host_input_whose_complete_native_effective_"
			+ "impulse_projection_is_not_above_the_unchanged_published_cap"
		),
		"nominal_host_conversion_step_s": OUTER_STEP_DURATION_S,
		"published_cap_changed": false,
		"empirical_margin_added": false,
		"measurement_clamped": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure R87 projection of one portable velocity command into one paired,
## time-scaled Godot torque impulse. The function owns no Node, RID, model,
## world, or solver step, so the complete mapping and its mutation controls can
## execute before physics. The vector actually passed to Godot determines the
## retained signed impulse; a representation that would exceed the unchanged
## published scalar cap is refused rather than silently reduced or rethresholded.
static func force_based_joint_impulse_projection_v1(
	actuator_index: int,
	actuator_id: String,
	joint_id: String,
	parent_body_id: String,
	child_body_id: String,
	source_semantic_step: int,
	source_measurement: bool,
	axis_parent_local: Vector3,
	axis_world: Vector3,
	canonical_target_velocity_rad_s: float,
	maximum_target_speed_rad_s: float,
	measured_relative_velocity_rad_s: float,
	maximum_outer_step_impulse_nms: float,
) -> Dictionary:
	if (
		actuator_index < 0
		or actuator_index >= ORDERED_ACTUATOR_IDS.size()
		or actuator_id != String(ORDERED_ACTUATOR_IDS[actuator_index])
		or joint_id != String(ORDERED_JOINT_IDS[actuator_index])
		or parent_body_id != String(ORDERED_PARENT_BODY_IDS[actuator_index])
		or child_body_id != String(ORDERED_CHILD_BODY_IDS[actuator_index])
		or parent_body_id == child_body_id
	):
		return _failure("QSDK_R24D87_FORCE_BASED_BINDING_INVALID:%d" % actuator_index)
	if (
		source_semantic_step < 1
		or not source_measurement
		or axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not axis_world.is_finite()
		or axis_world == Vector3.ZERO
		or absf(axis_world.length_squared() - 1.0)
		> FORCE_BASED_AXIS_UNIT_LENGTH_SQUARED_TOLERANCE
	):
		return _failure("QSDK_R24D87_FORCE_BASED_SOURCE_INVALID:%d" % actuator_index)
	if (
		not is_finite(canonical_target_velocity_rad_s)
		or not is_finite(maximum_target_speed_rad_s)
		or maximum_target_speed_rad_s <= 0.0
		or absf(canonical_target_velocity_rad_s) > maximum_target_speed_rad_s
		or not is_finite(measured_relative_velocity_rad_s)
		or not is_finite(maximum_outer_step_impulse_nms)
		or maximum_outer_step_impulse_nms
		!= float(ORDERED_PUBLISHED_CAPS_NMS[actuator_index])
	):
		return _failure("QSDK_R24D87_FORCE_BASED_COMMAND_INVALID:%d" % actuator_index)

	var velocity_error_rad_s := (
		canonical_target_velocity_rad_s - measured_relative_velocity_rad_s
	)
	var requested_signed_torque_nm := (
		FORCE_BASED_VELOCITY_ERROR_GAIN_NM_S_PER_RAD * velocity_error_rad_s
	)
	var requested_signed_impulse_nms := (
		requested_signed_torque_nm * OUTER_STEP_DURATION_S
	)
	var clamped_signed_impulse_nms := clampf(
		requested_signed_impulse_nms,
		-maximum_outer_step_impulse_nms,
		maximum_outer_step_impulse_nms,
	)
	var applied_input_signed_impulse_nms := clamped_signed_impulse_nms
	var child_impulse_world_nms := axis_world * applied_input_signed_impulse_nms
	var representation_projection_iteration_count := 0
	while (
		child_impulse_world_nms.length() > maximum_outer_step_impulse_nms
		and representation_projection_iteration_count
		< FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS
	):
		var current_input_magnitude := absf(applied_input_signed_impulse_nms)
		var current_vector_magnitude := child_impulse_world_nms.length()
		var projected_input_magnitude := _binary32_floor_v1(
			current_input_magnitude
			* maximum_outer_step_impulse_nms
			/ current_vector_magnitude
		)
		if projected_input_magnitude >= current_input_magnitude:
			var current_bits := _binary32_bits_v1(current_input_magnitude)
			projected_input_magnitude = (
				_binary32_from_bits_v1(current_bits - 1)
				if current_bits > 0
				else 0.0
			)
		applied_input_signed_impulse_nms = (
			-projected_input_magnitude
			if clamped_signed_impulse_nms < 0.0
			else projected_input_magnitude
		)
		child_impulse_world_nms = axis_world * applied_input_signed_impulse_nms
		representation_projection_iteration_count += 1
	var parent_impulse_world_nms := -child_impulse_world_nms
	var applied_magnitude_nms := child_impulse_world_nms.length()
	var applied_signed_impulse_nms := (
		-applied_magnitude_nms
		if clamped_signed_impulse_nms < 0.0
		else applied_magnitude_nms
	)
	var pairing_residual_world_nms := (
		child_impulse_world_nms + parent_impulse_world_nms
	)
	if (
		not is_finite(velocity_error_rad_s)
		or not is_finite(requested_signed_torque_nm)
		or not is_finite(requested_signed_impulse_nms)
		or not child_impulse_world_nms.is_finite()
		or not parent_impulse_world_nms.is_finite()
		or representation_projection_iteration_count
		>= FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS
		and applied_magnitude_nms > maximum_outer_step_impulse_nms
		or pairing_residual_world_nms != Vector3.ZERO
		or absf(applied_signed_impulse_nms) > maximum_outer_step_impulse_nms
	):
		return _failure("QSDK_R24D87_FORCE_BASED_PROJECTION_INVALID:%d" % actuator_index)
	return {
		"schema_version": "sporespore_qsdk_r24d87_force_based_joint_impulse_projection_v1",
		"ok": true,
		"actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": actuator_index,
		"actuator_id": actuator_id,
		"joint_id": joint_id,
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": source_semantic_step,
		"application_semantic_step": source_semantic_step + 1,
		"source_measurement": true,
		"axis_parent_local": _vector_json(axis_parent_local),
		"axis_world": _vector_json(axis_world),
		"axis_world_length_squared": axis_world.length_squared(),
		"axis_unit_length_squared_tolerance": (
			FORCE_BASED_AXIS_UNIT_LENGTH_SQUARED_TOLERANCE
		),
		"canonical_target_velocity_rad_s": canonical_target_velocity_rad_s,
		"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
		"measured_pre_step_relative_velocity_rad_s": (
			measured_relative_velocity_rad_s
		),
		"velocity_error_rad_s": velocity_error_rad_s,
		"velocity_error_gain_nm_s_per_rad": (
			FORCE_BASED_VELOCITY_ERROR_GAIN_NM_S_PER_RAD
		),
		"outer_step_duration_s": OUTER_STEP_DURATION_S,
		"requested_signed_torque_nm": requested_signed_torque_nm,
		"requested_signed_impulse_nms": requested_signed_impulse_nms,
		"clamped_signed_impulse_nms": clamped_signed_impulse_nms,
		"applied_input_signed_impulse_nms": applied_input_signed_impulse_nms,
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"published_maximum_outer_step_impulse_nms": (
			maximum_outer_step_impulse_nms
		),
		"impulse_saturated": (
			requested_signed_impulse_nms != clamped_signed_impulse_nms
		),
		"representation_projection_applied": (
			representation_projection_iteration_count > 0
		),
		"representation_projection_iteration_count": (
			representation_projection_iteration_count
		),
		"maximum_representation_projection_iterations": (
			FORCE_BASED_MAXIMUM_REPRESENTATION_PROJECTION_ITERATIONS
		),
		"representation_selection_rule": (
			"first_deterministic_binary32_downward_scalar_projection_whose_actual_"
			+ "magnitude_is_not_above_the_unchanged_published_cap"
		),
		"child_angular_impulse_world_nms": _vector_json(child_impulse_world_nms),
		"parent_angular_impulse_world_nms": _vector_json(parent_impulse_world_nms),
		"pairing_residual_world_nms": _vector_json(pairing_residual_world_nms),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Recompute the complete projection from its declared sources and require an
## exact tree match. This makes retained application receipts self-validating:
## changing either side of the impulse pair, its sign/cap/source identity, or
## any derived scalar cannot survive into application or post-step work.
static func validate_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
) -> Dictionary:
	var axis_parent_local := _vec3(
		application_projection.get("axis_parent_local")
	)
	var axis_world := _vec3(application_projection.get("axis_world"))
	var expected := force_based_joint_impulse_projection_v1(
		int(application_projection.get("actuator_index", -1)),
		String(application_projection.get("actuator_id", "")),
		String(application_projection.get("joint_id", "")),
		String(application_projection.get("parent_body_id", "")),
		String(application_projection.get("child_body_id", "")),
		int(application_projection.get("source_semantic_step", -1)),
		bool(application_projection.get("source_measurement", false)),
		axis_parent_local,
		axis_world,
		float(application_projection.get("canonical_target_velocity_rad_s", NAN)),
		float(application_projection.get("maximum_target_speed_rad_s", NAN)),
		float(
			application_projection.get(
				"measured_pre_step_relative_velocity_rad_s", NAN
			)
		),
		float(
			application_projection.get(
				"published_maximum_outer_step_impulse_nms", NAN
			)
		),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D87_FORCE_BASED_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d87_force_based_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Reconstruct the complete R94 guard pair from its retained native-limit,
## velocity, inverse-inertia, and impulse sources. This is the reusable mutation
## control for both zero-world qualification and the physical application path.
static func validate_native_angular_velocity_guard_pair_projection_v1(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var guard_value: Variant = guard_pair_projection.get("guard_limit_projection")
	if not (guard_value is Dictionary):
		return _failure("QSDK_R24D94_GUARD_PAIR_RECEIPT_LIMIT_MISSING")
	var guard: Dictionary = guard_value
	var runtime_value: Variant = guard.get("runtime_limit_projection")
	var expected_guard := native_angular_velocity_guard_limit_projection_v1(runtime_value)
	if (
		not bool(expected_guard.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard, expected_guard)
	):
		return _failure("QSDK_R24D94_GUARD_PAIR_RECEIPT_LIMIT_INVALID")
	var expected := native_angular_velocity_guard_pair_projection_v1(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		expected_guard,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D94_GUARD_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d94_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Reconstruct the complete R96 nested pair from its immutable outer guard,
## source-derived inner target, native source state, and requested impulse pair.
static func validate_nested_native_angular_velocity_guard_pair_projection_v1(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = guard_pair_projection.get("inner_projection_target")
	if not (target_value is Dictionary):
		return _failure("QSDK_R24D96_NESTED_PAIR_RECEIPT_TARGET_MISSING")
	var target: Dictionary = target_value
	var outer_guard_value: Variant = target.get("outer_guard_limit_projection")
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(target, expected_target)
	):
		return _failure("QSDK_R24D96_NESTED_PAIR_RECEIPT_TARGET_INVALID")
	var expected := nested_native_angular_velocity_guard_pair_projection_v1(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		expected_target,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D96_NESTED_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d96_nested_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Bind the immutable R87 command/cap projection to the distinct R94 native
## body-health projection. R87 remains nested and exactly valid; only the
## applied equal-and-opposite pair and its work identity are versioned forward.
static func guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D94_GUARDED_PREDECESSOR_INVALID", predecessor_validation
		)
	var guard_validation := validate_native_angular_velocity_guard_pair_projection_v1(
		guard_pair_projection
	)
	if not bool(guard_validation.get("ok", false)):
		return _failure("QSDK_R24D94_GUARDED_PAIR_INVALID", guard_validation)
	var predecessor: Dictionary = predecessor_validation["projection"]
	var guard_pair: Dictionary = guard_validation["projection"]
	var predecessor_parent_impulse := _vec3(
		predecessor.get("parent_angular_impulse_world_nms")
	)
	var predecessor_child_impulse := _vec3(
		predecessor.get("child_angular_impulse_world_nms")
	)
	if (
		int(guard_pair.get("actuator_index", -1))
		!= int(predecessor.get("actuator_index", -2))
		or String(guard_pair.get("actuator_id", ""))
		!= String(predecessor.get("actuator_id", ""))
		or String(guard_pair.get("joint_id", ""))
		!= String(predecessor.get("joint_id", ""))
		or String(guard_pair.get("parent_body_id", ""))
		!= String(predecessor.get("parent_body_id", ""))
		or String(guard_pair.get("child_body_id", ""))
		!= String(predecessor.get("child_body_id", ""))
		or int(guard_pair.get("source_semantic_step", -1))
		!= int(predecessor.get("source_semantic_step", -2))
		or _vec3(guard_pair.get("requested_parent_impulse_world_nms"))
		!= predecessor_parent_impulse
		or _vec3(guard_pair.get("requested_child_impulse_world_nms"))
		!= predecessor_child_impulse
	):
		return _failure("QSDK_R24D94_GUARDED_BINDING_INVALID")
	var applied_parent_impulse := _vec3(
		guard_pair.get("applied_parent_impulse_world_nms")
	)
	var applied_child_impulse := _vec3(
		guard_pair.get("applied_child_impulse_world_nms")
	)
	var predecessor_signed_impulse := float(
		predecessor.get("applied_signed_joint_impulse_nms", NAN)
	)
	var applied_magnitude := applied_child_impulse.length()
	var applied_signed_impulse := (
		-applied_magnitude if predecessor_signed_impulse < 0.0 else applied_magnitude
	)
	var published_cap := float(
		predecessor.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not applied_parent_impulse.is_finite()
		or not applied_child_impulse.is_finite()
		or not is_finite(predecessor_signed_impulse)
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or applied_parent_impulse + applied_child_impulse != Vector3.ZERO
		or absf(applied_signed_impulse) > published_cap
	):
		return _failure("QSDK_R24D94_GUARDED_APPLIED_IMPULSE_INVALID")
	return {
		"schema_version": GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA,
		"ok": true,
		"actuator_mapping_id": GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": int(predecessor["actuator_index"]),
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(
			predecessor["canonical_target_velocity_rad_s"]
		),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s": float(
			predecessor["measured_pre_step_relative_velocity_rad_s"]
		),
		"requested_signed_impulse_nms": float(
			predecessor["requested_signed_impulse_nms"]
		),
		"predecessor_applied_signed_joint_impulse_nms": predecessor_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": bool(guard_pair["guard_engaged"]),
		"impulse_saturated": (
			bool(predecessor["impulse_saturated"]) or bool(guard_pair["guard_engaged"])
		),
		"angular_velocity_guard_limit_rad_s": float(guard_pair["guard_limit_rad_s"]),
		"angular_velocity_guard_applied_scale": float(guard_pair["applied_scale"]),
		"child_angular_impulse_world_nms": _vector_json(applied_child_impulse),
		"parent_angular_impulse_world_nms": _vector_json(applied_parent_impulse),
		"pairing_residual_world_nms": _vector_json(
			applied_parent_impulse + applied_child_impulse
		),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"native_angular_velocity_guard_projection": guard_pair.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	var guard_value: Variant = application_projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (predecessor_value is Dictionary) or not (guard_value is Dictionary):
		return _failure("QSDK_R24D94_GUARDED_PROJECTION_SOURCE_MISSING")
	var expected := guarded_force_based_joint_impulse_projection_v1(
		predecessor_value, guard_value
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D94_GUARDED_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d94_guarded_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Bind the unchanged R87 command/cap projection to R96's nested prediction
## target. The outer native readback guard remains the exact R94/R95 guard.
static func nested_guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	nested_guard_pair_projection: Dictionary,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D96_NESTED_GUARDED_PREDECESSOR_INVALID",
			predecessor_validation,
		)
	var guard_validation := (
		validate_nested_native_angular_velocity_guard_pair_projection_v1(
			nested_guard_pair_projection
		)
	)
	if not bool(guard_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D96_NESTED_GUARDED_PAIR_INVALID", guard_validation
		)
	var predecessor: Dictionary = predecessor_validation["projection"]
	var guard_pair: Dictionary = guard_validation["projection"]
	var predecessor_parent_impulse := _vec3(
		predecessor.get("parent_angular_impulse_world_nms")
	)
	var predecessor_child_impulse := _vec3(
		predecessor.get("child_angular_impulse_world_nms")
	)
	if (
		int(guard_pair.get("actuator_index", -1))
		!= int(predecessor.get("actuator_index", -2))
		or String(guard_pair.get("actuator_id", ""))
		!= String(predecessor.get("actuator_id", ""))
		or String(guard_pair.get("joint_id", ""))
		!= String(predecessor.get("joint_id", ""))
		or String(guard_pair.get("parent_body_id", ""))
		!= String(predecessor.get("parent_body_id", ""))
		or String(guard_pair.get("child_body_id", ""))
		!= String(predecessor.get("child_body_id", ""))
		or int(guard_pair.get("source_semantic_step", -1))
		!= int(predecessor.get("source_semantic_step", -2))
		or _vec3(guard_pair.get("requested_parent_impulse_world_nms"))
		!= predecessor_parent_impulse
		or _vec3(guard_pair.get("requested_child_impulse_world_nms"))
		!= predecessor_child_impulse
	):
		return _failure("QSDK_R24D96_NESTED_GUARDED_BINDING_INVALID")
	var applied_parent_impulse := _vec3(
		guard_pair.get("applied_parent_impulse_world_nms")
	)
	var applied_child_impulse := _vec3(
		guard_pair.get("applied_child_impulse_world_nms")
	)
	var predecessor_signed_impulse := float(
		predecessor.get("applied_signed_joint_impulse_nms", NAN)
	)
	var applied_magnitude := applied_child_impulse.length()
	var applied_signed_impulse := (
		-applied_magnitude if predecessor_signed_impulse < 0.0 else applied_magnitude
	)
	var published_cap := float(
		predecessor.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not applied_parent_impulse.is_finite()
		or not applied_child_impulse.is_finite()
		or not is_finite(predecessor_signed_impulse)
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or applied_parent_impulse + applied_child_impulse != Vector3.ZERO
		or absf(applied_signed_impulse) > published_cap
	):
		return _failure("QSDK_R24D96_NESTED_GUARDED_APPLIED_IMPULSE_INVALID")
	return {
		"schema_version": NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA,
		"ok": true,
		"actuator_mapping_id": NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": int(predecessor["actuator_index"]),
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(
			predecessor["canonical_target_velocity_rad_s"]
		),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s": float(
			predecessor["measured_pre_step_relative_velocity_rad_s"]
		),
		"requested_signed_impulse_nms": float(
			predecessor["requested_signed_impulse_nms"]
		),
		"predecessor_applied_signed_joint_impulse_nms": predecessor_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": bool(guard_pair["guard_engaged"]),
		"native_angular_velocity_projection_target_engaged": bool(
			guard_pair["guard_engaged"]
		),
		"impulse_saturated": (
			bool(predecessor["impulse_saturated"]) or bool(guard_pair["guard_engaged"])
		),
		"angular_velocity_guard_limit_rad_s": float(guard_pair["guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s": float(
			guard_pair["projection_target_limit_rad_s"]
		),
		"projection_target_separated_from_native_readback_guard": true,
		"child_angular_impulse_world_nms": _vector_json(applied_child_impulse),
		"parent_angular_impulse_world_nms": _vector_json(applied_parent_impulse),
		"pairing_residual_world_nms": _vector_json(
			applied_parent_impulse + applied_child_impulse
		),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"native_angular_velocity_guard_projection": guard_pair.duplicate(true),
		"native_angular_velocity_inner_projection_target": (
			(guard_pair["inner_projection_target"] as Dictionary).duplicate(true)
		),
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_nested_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	var guard_value: Variant = application_projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (predecessor_value is Dictionary) or not (guard_value is Dictionary):
		return _failure("QSDK_R24D96_NESTED_GUARDED_PROJECTION_SOURCE_MISSING")
	var expected := nested_guarded_force_based_joint_impulse_projection_v1(
		predecessor_value, guard_value
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D96_NESTED_GUARDED_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d96_nested_guarded_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Resolve the applied-scale receipt without assuming that the R94 and R96
## projection schemas store it at the same path. This is a pure R97 integration
## projection: it changes no impulse, guard, target, threshold, or physics state.
static func guarded_force_based_applied_scale_projection_v1(
	application_projection: Dictionary,
	nested_projection_required: bool,
) -> Dictionary:
	var validation := (
		validate_nested_guarded_force_based_joint_impulse_projection_v1(
			application_projection
		)
		if nested_projection_required
		else validate_guarded_force_based_joint_impulse_projection_v1(
			application_projection
		)
	)
	if not bool(validation.get("ok", false)):
		return _failure("QSDK_R24D97_APPLIED_SCALE_PROJECTION_INVALID", validation)
	var projection: Dictionary = validation["projection"]
	var scale_path := "angular_velocity_guard_applied_scale"
	var scale_value: Variant = projection.get(scale_path)
	if nested_projection_required:
		var guard_value: Variant = projection.get(
			"native_angular_velocity_guard_projection"
		)
		if not (guard_value is Dictionary):
			return _failure("QSDK_R24D97_NESTED_APPLIED_SCALE_SOURCE_MISSING")
		scale_path = "native_angular_velocity_guard_projection.applied_scale"
		scale_value = (guard_value as Dictionary).get("applied_scale")
	var applied_scale := (
		float(scale_value) if scale_value is float or scale_value is int else NAN
	)
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D97_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version": GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"nested_projection_required": nested_projection_required,
		"source_path": scale_path,
		"applied_scale": applied_scale,
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Bind the unchanged R87 command/cap projection to the R99 component-norm
## nested pair. This is a new mapping identity; the R96 receipt stays frozen.
static func component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	nested_guard_pair_projection: Dictionary,
) -> Dictionary:
	return _component_norm_nested_guarded_force_based_joint_impulse_projection_common_v1(
		predecessor_projection,
		nested_guard_pair_projection,
		false,
	)


static func refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
	predecessor_projection: Dictionary,
	nested_guard_pair_projection: Dictionary,
) -> Dictionary:
	return _component_norm_nested_guarded_force_based_joint_impulse_projection_common_v1(
		predecessor_projection,
		nested_guard_pair_projection,
		true,
	)


static func _component_norm_nested_guarded_force_based_joint_impulse_projection_common_v1(
	predecessor_projection: Dictionary,
	nested_guard_pair_projection: Dictionary,
	refinement_safe_guard_required: bool,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D99_NESTED_GUARDED_PREDECESSOR_INVALID",
			predecessor_validation,
		)
	var guard_validation := (
		validate_nested_native_angular_velocity_guard_pair_projection_v3(
			nested_guard_pair_projection
		)
		if refinement_safe_guard_required
		else validate_nested_native_angular_velocity_guard_pair_projection_v2(
			nested_guard_pair_projection
		)
	)
	if not bool(guard_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D99_NESTED_GUARDED_PAIR_INVALID", guard_validation
		)
	var predecessor: Dictionary = predecessor_validation["projection"]
	var guard_pair: Dictionary = guard_validation["projection"]
	var predecessor_parent_impulse := _vec3(
		predecessor.get("parent_angular_impulse_world_nms")
	)
	var predecessor_child_impulse := _vec3(
		predecessor.get("child_angular_impulse_world_nms")
	)
	if (
		int(guard_pair.get("actuator_index", -1))
		!= int(predecessor.get("actuator_index", -2))
		or String(guard_pair.get("actuator_id", ""))
		!= String(predecessor.get("actuator_id", ""))
		or String(guard_pair.get("joint_id", ""))
		!= String(predecessor.get("joint_id", ""))
		or String(guard_pair.get("parent_body_id", ""))
		!= String(predecessor.get("parent_body_id", ""))
		or String(guard_pair.get("child_body_id", ""))
		!= String(predecessor.get("child_body_id", ""))
		or int(guard_pair.get("source_semantic_step", -1))
		!= int(predecessor.get("source_semantic_step", -2))
		or _vec3(guard_pair.get("requested_parent_impulse_world_nms"))
		!= predecessor_parent_impulse
		or _vec3(guard_pair.get("requested_child_impulse_world_nms"))
		!= predecessor_child_impulse
	):
		return _failure("QSDK_R24D99_NESTED_GUARDED_BINDING_INVALID")
	var applied_parent_impulse := _vec3(
		guard_pair.get("applied_parent_impulse_world_nms")
	)
	var applied_child_impulse := _vec3(
		guard_pair.get("applied_child_impulse_world_nms")
	)
	var predecessor_signed_impulse := float(
		predecessor.get("applied_signed_joint_impulse_nms", NAN)
	)
	var applied_magnitude_squared := _component_dot_float64_v1(
		applied_child_impulse, applied_child_impulse
	)
	var applied_magnitude := sqrt(applied_magnitude_squared)
	var applied_signed_impulse := (
		-applied_magnitude if predecessor_signed_impulse < 0.0 else applied_magnitude
	)
	var published_cap := float(
		predecessor.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not applied_parent_impulse.is_finite()
		or not applied_child_impulse.is_finite()
		or not is_finite(predecessor_signed_impulse)
		or not is_finite(applied_magnitude_squared)
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or applied_parent_impulse + applied_child_impulse != Vector3.ZERO
		or absf(applied_signed_impulse) > published_cap
	):
		return _failure("QSDK_R24D99_NESTED_GUARDED_APPLIED_IMPULSE_INVALID")
	return {
		"schema_version": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
		),
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"actuator_mapping_id": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		),
		"work_mapping_id": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		),
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": int(predecessor["actuator_index"]),
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(
			predecessor["canonical_target_velocity_rad_s"]
		),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s": float(
			predecessor["measured_pre_step_relative_velocity_rad_s"]
		),
		"requested_signed_impulse_nms": float(
			predecessor["requested_signed_impulse_nms"]
		),
		"predecessor_applied_signed_joint_impulse_nms": predecessor_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": bool(guard_pair["guard_engaged"]),
		"native_angular_velocity_projection_target_engaged": bool(
			guard_pair["guard_engaged"]
		),
		"impulse_saturated": (
			bool(predecessor["impulse_saturated"]) or bool(guard_pair["guard_engaged"])
		),
		"angular_velocity_guard_limit_rad_s": float(guard_pair["guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s": float(
			guard_pair["projection_target_limit_rad_s"]
		),
		"projection_target_separated_from_native_readback_guard": true,
		"component_norm_numeric_predicate_required": true,
		"child_angular_impulse_world_nms": _vector_json(applied_child_impulse),
		"parent_angular_impulse_world_nms": _vector_json(applied_parent_impulse),
		"pairing_residual_world_nms": _vector_json(
			applied_parent_impulse + applied_child_impulse
		),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"native_angular_velocity_guard_projection": guard_pair.duplicate(true),
		"native_angular_velocity_inner_projection_target": (
			(guard_pair["inner_projection_target"] as Dictionary).duplicate(true)
		),
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	var guard_value: Variant = application_projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (predecessor_value is Dictionary) or not (guard_value is Dictionary):
		return _failure("QSDK_R24D99_NESTED_GUARDED_PROJECTION_SOURCE_MISSING")
	var expected := component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
		predecessor_value, guard_value
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D99_NESTED_GUARDED_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d99_component_norm_nested_guarded_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
	application_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	var guard_value: Variant = application_projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (predecessor_value is Dictionary) or not (guard_value is Dictionary):
		return _failure("QSDK_R24D100_NESTED_GUARDED_PROJECTION_SOURCE_MISSING")
	var expected := (
		refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
			predecessor_value,
			guard_value,
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D100_NESTED_GUARDED_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_guarded_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Bind one frozen R87 request to its R103 population attribution. The complete
## population receipt remains application-level authority; this compact joint
## view carries only the exact attributed pair needed by work and telemetry.
static func order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	population_projection: Dictionary,
	actuator_index: int,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	var population_validation := validate_order_neutral_population_guard_projection_v1(
		population_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure("QSDK_R24D103_JOINT_PREDECESSOR_INVALID", predecessor_validation)
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D103_JOINT_POPULATION_INVALID", population_validation)
	if actuator_index < 0 or actuator_index >= ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D103_JOINT_INDEX_INVALID")
	var predecessor: Dictionary = predecessor_validation["projection"]
	var population: Dictionary = population_validation["projection"]
	var attributions: Array = population["ordered_actuator_attributions"]
	var attribution_value: Variant = attributions[actuator_index]
	if not (attribution_value is Dictionary):
		return _failure("QSDK_R24D103_JOINT_ATTRIBUTION_INVALID")
	var attribution: Dictionary = attribution_value
	var predecessor_parent := _vec3(predecessor.get("parent_angular_impulse_world_nms"))
	var predecessor_child := _vec3(predecessor.get("child_angular_impulse_world_nms"))
	var attributed_parent := _vec3(attribution.get("attributed_applied_parent_impulse_world_nms"))
	var attributed_child := _vec3(attribution.get("attributed_applied_child_impulse_world_nms"))
	if (
		int(predecessor.get("actuator_index", -1)) != actuator_index
		or int(attribution.get("actuator_index", -1)) != actuator_index
		or String(attribution.get("actuator_id", "")) != String(predecessor.get("actuator_id", ""))
		or String(attribution.get("joint_id", "")) != String(predecessor.get("joint_id", ""))
		or (
			String(attribution.get("parent_body_id", ""))
			!= String(predecessor.get("parent_body_id", ""))
		)
		or (
			String(attribution.get("child_body_id", ""))
			!= String(predecessor.get("child_body_id", ""))
		)
		or (
			int(population.get("source_semantic_step", -1))
			!= int(predecessor.get("source_semantic_step", -2))
		)
		or _vec3(attribution.get("requested_parent_impulse_world_nms")) != predecessor_parent
		or _vec3(attribution.get("requested_child_impulse_world_nms")) != predecessor_child
	):
		return _failure("QSDK_R24D103_JOINT_ATTRIBUTION_BINDING_INVALID")
	var applied_magnitude_squared := _component_dot_float64_v1(attributed_child, attributed_child)
	var applied_magnitude := sqrt(applied_magnitude_squared)
	var predecessor_signed_impulse := float(
		predecessor.get("applied_signed_joint_impulse_nms", NAN)
	)
	var applied_signed_impulse := (
		-applied_magnitude if predecessor_signed_impulse < 0.0 else applied_magnitude
	)
	var published_cap := float(predecessor.get("published_maximum_outer_step_impulse_nms", NAN))
	var common_scale := float(population.get("common_applied_scale", NAN))
	if (
		not attributed_parent.is_finite()
		or not attributed_child.is_finite()
		or attributed_parent + attributed_child != Vector3.ZERO
		or not is_finite(applied_magnitude_squared)
		or not is_finite(predecessor_signed_impulse)
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or not is_finite(common_scale)
		or common_scale < 0.0
		or common_scale > 1.0
		or absf(applied_signed_impulse) > published_cap
	):
		return _failure("QSDK_R24D103_JOINT_ATTRIBUTED_IMPULSE_INVALID")
	return {
		"schema_version":
		ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"actuator_mapping_id": ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": actuator_index,
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(predecessor["canonical_target_velocity_rad_s"]),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s":
		float(predecessor["measured_pre_step_relative_velocity_rad_s"]),
		"requested_signed_impulse_nms": float(predecessor["requested_signed_impulse_nms"]),
		"predecessor_applied_signed_joint_impulse_nms": predecessor_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": common_scale < 1.0,
		"native_angular_velocity_projection_target_engaged": common_scale < 1.0,
		"impulse_saturated": bool(predecessor["impulse_saturated"]) or common_scale < 1.0,
		"angular_velocity_guard_limit_rad_s": float(population["outer_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(population["projection_target_limit_rad_s"]),
		"common_applied_scale": common_scale,
		"common_applied_scale_binary32_hex":
		String(population["common_applied_scale_binary32_hex"]),
		"population_guard_projection_schema": ORDER_NEUTRAL_POPULATION_GUARD_PROJECTION_SCHEMA,
		"population_projection_target_feasible":
		bool(population["continuous_projection_target_feasible"]),
		"population_outer_guard_zero_impulse_hold":
		bool(population["outer_guard_zero_impulse_hold"]),
		"population_representational_zero_impulse_fallback":
		bool(population["representational_zero_impulse_fallback"]),
		"projection_target_separated_from_native_readback_guard": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"child_angular_impulse_world_nms": _vector_json(attributed_child),
		"parent_angular_impulse_world_nms": _vector_json(attributed_parent),
		"pairing_residual_world_nms": _vector_json(attributed_parent + attributed_child),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"population_attribution": attribution.duplicate(true),
		"native_angular_velocity_inner_projection_target":
		(population["inner_projection_target"] as Dictionary).duplicate(true),
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	if not (predecessor_value is Dictionary):
		return _failure("QSDK_R24D103_JOINT_PROJECTION_SOURCE_MISSING")
	var expected := order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
		predecessor_value,
		population_projection,
		int(application_projection.get("actuator_index", -1)),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D103_JOINT_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d103_order_neutral_population_guarded_joint_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Bind one frozen R87 request to the final attribution produced by the R107
## target pre-scale followed by the unchanged R103 body guard.
static func joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	population_projection: Dictionary,
	actuator_index: int,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	var population_validation := validate_joint_target_monotone_population_guard_projection_v1(
		population_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure("QSDK_R24D107_JOINT_PREDECESSOR_INVALID", predecessor_validation)
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D107_JOINT_POPULATION_INVALID", population_validation)
	if actuator_index < 0 or actuator_index >= ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D107_JOINT_INDEX_INVALID")
	var predecessor: Dictionary = predecessor_validation["projection"]
	var population: Dictionary = population_validation["projection"]
	var joint_target_values: Array = population["ordered_joint_target_projections"]
	var joint_target_value: Variant = joint_target_values[actuator_index]
	var body_guard: Dictionary = population["body_guard_population_projection"]
	var attribution_values: Array = body_guard["ordered_actuator_attributions"]
	var attribution_value: Variant = attribution_values[actuator_index]
	if not (joint_target_value is Dictionary) or not (attribution_value is Dictionary):
		return _failure("QSDK_R24D107_JOINT_ATTRIBUTION_INVALID")
	var joint_target: Dictionary = joint_target_value
	var attribution: Dictionary = attribution_value
	var target_pre_scale := float(population.get("target_common_pre_scale", NAN))
	var body_guard_scale := float(population.get("body_guard_common_applied_scale", NAN))
	var nominal_composed_scale := float(population.get("nominal_composed_common_scale", NAN))
	var predecessor_parent := _vec3(predecessor.get("parent_angular_impulse_world_nms"))
	var predecessor_child := _vec3(predecessor.get("child_angular_impulse_world_nms"))
	var scaled_requested_child := predecessor_child * target_pre_scale
	var scaled_requested_parent := -scaled_requested_child
	var attributed_parent := _vec3(
		attribution.get("attributed_applied_parent_impulse_world_nms")
	)
	var attributed_child := _vec3(
		attribution.get("attributed_applied_child_impulse_world_nms")
	)
	if (
		int(predecessor.get("actuator_index", -1)) != actuator_index
		or int(joint_target.get("actuator_index", -1)) != actuator_index
		or int(attribution.get("actuator_index", -1)) != actuator_index
		or not _exact_variant_tree_equal_v1(
			joint_target.get("predecessor_projection"), predecessor
		)
		or String(joint_target.get("actuator_id", "")) != String(predecessor.get("actuator_id", ""))
		or String(joint_target.get("joint_id", "")) != String(predecessor.get("joint_id", ""))
		or String(attribution.get("actuator_id", "")) != String(predecessor.get("actuator_id", ""))
		or String(attribution.get("joint_id", "")) != String(predecessor.get("joint_id", ""))
		or String(attribution.get("parent_body_id", "")) != String(predecessor.get("parent_body_id", ""))
		or String(attribution.get("child_body_id", "")) != String(predecessor.get("child_body_id", ""))
		or int(population.get("source_semantic_step", -1))
		!= int(predecessor.get("source_semantic_step", -2))
		or _vec3(attribution.get("requested_parent_impulse_world_nms"))
		!= scaled_requested_parent
		or _vec3(attribution.get("requested_child_impulse_world_nms"))
		!= scaled_requested_child
	):
		return _failure("QSDK_R24D107_JOINT_ATTRIBUTION_BINDING_INVALID")
	var applied_magnitude_squared := _component_dot_float64_v1(
		attributed_child, attributed_child
	)
	var applied_magnitude := sqrt(applied_magnitude_squared)
	var predecessor_signed_impulse := float(
		predecessor.get("applied_signed_joint_impulse_nms", NAN)
	)
	var applied_signed_impulse := (
		-applied_magnitude if predecessor_signed_impulse < 0.0 else applied_magnitude
	)
	var published_cap := float(
		predecessor.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not predecessor_parent.is_finite()
		or not predecessor_child.is_finite()
		or not attributed_parent.is_finite()
		or not attributed_child.is_finite()
		or attributed_parent + attributed_child != Vector3.ZERO
		or not is_finite(applied_magnitude_squared)
		or not is_finite(predecessor_signed_impulse)
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or not is_finite(target_pre_scale)
		or target_pre_scale < 0.0
		or target_pre_scale > 1.0
		or not is_finite(body_guard_scale)
		or body_guard_scale < 0.0
		or body_guard_scale > 1.0
		or not is_finite(nominal_composed_scale)
		or nominal_composed_scale < 0.0
		or nominal_composed_scale > 1.0
		or absf(applied_signed_impulse) > published_cap
		or not bool(joint_target.get("absolute_target_error_nonincreasing", false))
		or bool(joint_target.get("target_crossed", true))
	):
		return _failure("QSDK_R24D107_JOINT_ATTRIBUTED_IMPULSE_INVALID")
	var guard_engaged := target_pre_scale < 1.0 or body_guard_scale < 1.0
	return {
		"schema_version":
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"actuator_mapping_id":
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": actuator_index,
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(predecessor["canonical_target_velocity_rad_s"]),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s":
		float(predecessor["measured_pre_step_relative_velocity_rad_s"]),
		"requested_signed_impulse_nms": float(predecessor["requested_signed_impulse_nms"]),
		"predecessor_applied_signed_joint_impulse_nms": predecessor_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": guard_engaged,
		"native_angular_velocity_projection_target_engaged": guard_engaged,
		"joint_target_monotone_guard_engaged": target_pre_scale < 1.0,
		"impulse_saturated": bool(predecessor["impulse_saturated"]) or guard_engaged,
		"angular_velocity_guard_limit_rad_s": float(body_guard["outer_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(body_guard["projection_target_limit_rad_s"]),
		"target_common_pre_scale": target_pre_scale,
		"target_common_pre_scale_binary32_hex":
		String(population["target_common_pre_scale_binary32_hex"]),
		"body_guard_common_applied_scale": body_guard_scale,
		"body_guard_common_applied_scale_binary32_hex":
		String(body_guard["common_applied_scale_binary32_hex"]),
		"nominal_composed_common_scale": nominal_composed_scale,
		"population_zero_hold_for_nonhelpful_joint_delta":
		bool(population["population_zero_hold_for_nonhelpful_joint_delta"]),
		"absolute_target_error_nonincreasing": true,
		"target_crossed": false,
		"joint_target_monotone_population_projection_schema":
		JOINT_TARGET_MONOTONE_POPULATION_GUARD_PROJECTION_SCHEMA,
		"body_guard_population_projection_schema": ORDER_NEUTRAL_POPULATION_GUARD_PROJECTION_SCHEMA,
		"projection_target_separated_from_native_readback_guard": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_target_monotone_population_projection_required": true,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"child_angular_impulse_world_nms": _vector_json(attributed_child),
		"parent_angular_impulse_world_nms": _vector_json(attributed_parent),
		"pairing_residual_world_nms": _vector_json(attributed_parent + attributed_child),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"joint_target_projection": joint_target.duplicate(true),
		"population_attribution": attribution.duplicate(true),
		"native_angular_velocity_inner_projection_target":
		(body_guard["inner_projection_target"] as Dictionary).duplicate(true),
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	if not (predecessor_value is Dictionary):
		return _failure("QSDK_R24D107_JOINT_PROJECTION_SOURCE_MISSING")
	var expected := (
		joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
			predecessor_value,
			population_projection,
			int(application_projection.get("actuator_index", -1)),
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D107_JOINT_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d107_joint_target_monotone_population_guarded_joint_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
	predecessor_projection: Dictionary,
	population_projection: Dictionary,
	actuator_index: int,
) -> Dictionary:
	var predecessor_validation := validate_force_based_joint_impulse_projection_v1(
		predecessor_projection
	)
	var population_validation := validate_joint_space_effective_inertia_population_guard_projection_v1(
		population_projection
	)
	if not bool(predecessor_validation.get("ok", false)):
		return _failure("QSDK_R24D109_JOINT_PREDECESSOR_INVALID", predecessor_validation)
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D109_JOINT_POPULATION_INVALID", population_validation)
	if actuator_index < 0 or actuator_index >= ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D109_JOINT_INDEX_INVALID")
	var predecessor: Dictionary = predecessor_validation["projection"]
	var population: Dictionary = population_validation["projection"]
	var joint_values: Array = population["ordered_joint_solve_projections"]
	var joint_value: Variant = joint_values[actuator_index]
	var body_guard: Dictionary = population["body_guard_population_projection"]
	var attribution_values: Array = body_guard["ordered_actuator_attributions"]
	var attribution_value: Variant = attribution_values[actuator_index]
	if not (joint_value is Dictionary) or not (attribution_value is Dictionary):
		return _failure("QSDK_R24D109_JOINT_ATTRIBUTION_INVALID")
	var joint: Dictionary = joint_value
	var attribution: Dictionary = attribution_value
	var common_pre_scale := float(population.get("joint_space_common_pre_scale", NAN))
	var body_guard_scale := float(population.get("body_guard_common_applied_scale", NAN))
	var nominal_composed_scale := float(population.get("nominal_composed_common_scale", NAN))
	var axis_world := _vec3(predecessor.get("axis_world"))
	var solved_signed_impulse := float(joint.get("solved_signed_joint_impulse_nms", NAN))
	var represented_requested_signed_impulse := float(
		joint.get("represented_requested_signed_joint_impulse_nms", NAN)
	)
	var expected_requested_child := _binary32_vector_scale_v1(
		axis_world, represented_requested_signed_impulse
	)
	var attributed_parent := _vec3(
		attribution.get("attributed_applied_parent_impulse_world_nms")
	)
	var attributed_child := _vec3(
		attribution.get("attributed_applied_child_impulse_world_nms")
	)
	var applied_signed_impulse := _component_dot_float64_v1(attributed_child, axis_world)
	var published_cap := float(
		predecessor.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		int(predecessor.get("actuator_index", -1)) != actuator_index
		or int(joint.get("actuator_index", -1)) != actuator_index
		or int(attribution.get("actuator_index", -1)) != actuator_index
		or not _exact_variant_tree_equal_v1(joint.get("predecessor_projection"), predecessor)
		or String(joint.get("actuator_id", "")) != String(predecessor.get("actuator_id", ""))
		or String(joint.get("joint_id", "")) != String(predecessor.get("joint_id", ""))
		or String(attribution.get("actuator_id", "")) != String(predecessor.get("actuator_id", ""))
		or String(attribution.get("joint_id", "")) != String(predecessor.get("joint_id", ""))
		or String(attribution.get("parent_body_id", "")) != String(predecessor.get("parent_body_id", ""))
		or String(attribution.get("child_body_id", "")) != String(predecessor.get("child_body_id", ""))
		or int(population.get("source_semantic_step", -1))
		!= int(predecessor.get("source_semantic_step", -2))
		or _vec3(attribution.get("requested_parent_impulse_world_nms"))
		!= -expected_requested_child
		or _vec3(attribution.get("requested_child_impulse_world_nms"))
		!= expected_requested_child
	):
		return _failure("QSDK_R24D109_JOINT_ATTRIBUTION_BINDING_INVALID")
	if (
		not axis_world.is_finite()
		or not is_finite(solved_signed_impulse)
		or not is_finite(represented_requested_signed_impulse)
		or not attributed_parent.is_finite()
		or not attributed_child.is_finite()
		or attributed_parent + attributed_child != Vector3.ZERO
		or not is_finite(applied_signed_impulse)
		or not is_finite(published_cap)
		or published_cap <= 0.0
		or absf(applied_signed_impulse) > published_cap
		or not is_finite(common_pre_scale)
		or common_pre_scale < 0.0
		or common_pre_scale > 1.0
		or not is_finite(body_guard_scale)
		or body_guard_scale < 0.0
		or body_guard_scale > 1.0
		or not is_finite(nominal_composed_scale)
		or nominal_composed_scale < 0.0
		or nominal_composed_scale > 1.0
		or not bool(joint.get("absolute_target_error_nonincreasing", false))
		or bool(joint.get("target_crossed", true))
	):
		return _failure("QSDK_R24D109_JOINT_ATTRIBUTED_IMPULSE_INVALID")
	var guard_engaged := nominal_composed_scale < 1.0
	return {
		"schema_version":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"actuator_mapping_id":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_index": actuator_index,
		"actuator_id": String(predecessor["actuator_id"]),
		"joint_id": String(predecessor["joint_id"]),
		"parent_body_id": String(predecessor["parent_body_id"]),
		"child_body_id": String(predecessor["child_body_id"]),
		"source_semantic_step": int(predecessor["source_semantic_step"]),
		"application_semantic_step": int(predecessor["application_semantic_step"]),
		"source_measurement": true,
		"axis_parent_local": predecessor["axis_parent_local"],
		"axis_world": predecessor["axis_world"],
		"canonical_target_velocity_rad_s": float(predecessor["canonical_target_velocity_rad_s"]),
		"maximum_target_speed_rad_s": float(predecessor["maximum_target_speed_rad_s"]),
		"measured_pre_step_relative_velocity_rad_s":
		float(predecessor["measured_pre_step_relative_velocity_rad_s"]),
		"requested_signed_impulse_nms": float(predecessor["requested_signed_impulse_nms"]),
		"predecessor_applied_signed_joint_impulse_nms":
		float(predecessor["applied_signed_joint_impulse_nms"]),
		"solved_signed_joint_impulse_nms": solved_signed_impulse,
		"represented_requested_signed_joint_impulse_nms":
		represented_requested_signed_impulse,
		"applied_signed_joint_impulse_nms": applied_signed_impulse,
		"published_maximum_outer_step_impulse_nms": published_cap,
		"predecessor_impulse_saturated": bool(predecessor["impulse_saturated"]),
		"native_angular_velocity_guard_engaged": guard_engaged,
		"native_angular_velocity_projection_target_engaged": guard_engaged,
		"joint_space_effective_inertia_guard_engaged": guard_engaged,
		"impulse_saturated": bool(predecessor["impulse_saturated"]) or guard_engaged,
		"angular_velocity_guard_limit_rad_s": float(body_guard["outer_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(body_guard["projection_target_limit_rad_s"]),
		"joint_space_common_pre_scale": common_pre_scale,
		"joint_space_common_pre_scale_binary32_hex":
		String(population["joint_space_common_pre_scale_binary32_hex"]),
		"body_guard_common_applied_scale": body_guard_scale,
		"body_guard_common_applied_scale_binary32_hex":
		String(body_guard["common_applied_scale_binary32_hex"]),
		"nominal_composed_common_scale": nominal_composed_scale,
		"representation_refinement_count": int(population["representation_refinement_count"]),
		"absolute_target_error_nonincreasing": true,
		"target_crossed": false,
		"joint_space_effective_inertia_population_projection_schema":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARD_PROJECTION_SCHEMA,
		"body_guard_population_projection_schema": ORDER_NEUTRAL_POPULATION_GUARD_PROJECTION_SCHEMA,
		"projection_target_separated_from_native_readback_guard": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_space_effective_inertia_population_projection_required": true,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"child_angular_impulse_world_nms": _vector_json(attributed_child),
		"parent_angular_impulse_world_nms": _vector_json(attributed_parent),
		"pairing_residual_world_nms": _vector_json(attributed_parent + attributed_child),
		"equal_and_opposite_pair": true,
		"hard_constraint_velocity_motor_enabled": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"predecessor_projection": predecessor.duplicate(true),
		"joint_space_solve_projection": joint.duplicate(true),
		"population_attribution": attribution.duplicate(true),
		"native_angular_velocity_inner_projection_target":
		(body_guard["inner_projection_target"] as Dictionary).duplicate(true),
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var predecessor_value: Variant = application_projection.get("predecessor_projection")
	if not (predecessor_value is Dictionary):
		return _failure("QSDK_R24D109_JOINT_PROJECTION_SOURCE_MISSING")
	var expected := (
		joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
			predecessor_value,
			population_projection,
			int(application_projection.get("actuator_index", -1)),
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(application_projection, expected)
	):
		return _failure("QSDK_R24D109_JOINT_PROJECTION_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_guarded_joint_projection_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_space_effective_inertia_population_guarded_force_based_applied_scale_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var validation := validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	if not bool(validation.get("ok", false)):
		return _failure("QSDK_R24D109_APPLIED_SCALE_PROJECTION_INVALID", validation)
	var projection: Dictionary = validation["projection"]
	var applied_scale := float(projection.get("nominal_composed_common_scale", NAN))
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D109_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"nested_projection_required": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_space_effective_inertia_population_projection_required": true,
		"source_path": "joint_space_common_pre_scale*body_guard_common_applied_scale",
		"applied_scale": applied_scale,
		"joint_space_common_pre_scale": float(projection["joint_space_common_pre_scale"]),
		"body_guard_common_applied_scale":
		float(projection["body_guard_common_applied_scale"]),
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_target_monotone_population_guarded_force_based_applied_scale_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var validation := (
		validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
			application_projection,
			population_projection,
		)
	)
	if not bool(validation.get("ok", false)):
		return _failure("QSDK_R24D107_APPLIED_SCALE_PROJECTION_INVALID", validation)
	var projection: Dictionary = validation["projection"]
	var applied_scale := float(projection.get("nominal_composed_common_scale", NAN))
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D107_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version":
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"nested_projection_required": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_target_monotone_population_projection_required": true,
		"source_path": "target_common_pre_scale*body_guard_common_applied_scale",
		"applied_scale": applied_scale,
		"target_common_pre_scale": float(projection["target_common_pre_scale"]),
		"body_guard_common_applied_scale":
		float(projection["body_guard_common_applied_scale"]),
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func order_neutral_population_guarded_force_based_applied_scale_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
) -> Dictionary:
	var validation := validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	if not bool(validation.get("ok", false)):
		return _failure("QSDK_R24D103_APPLIED_SCALE_PROJECTION_INVALID", validation)
	var projection: Dictionary = validation["projection"]
	var applied_scale := float(projection.get("common_applied_scale", NAN))
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D103_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version":
		ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"nested_projection_required": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"source_path": "common_applied_scale",
		"applied_scale": applied_scale,
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func component_norm_guarded_force_based_applied_scale_projection_v1(
	application_projection: Dictionary,
) -> Dictionary:
	var validation := (
		validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
			application_projection
		)
	)
	if not bool(validation.get("ok", false)):
		return _failure(
			"QSDK_R24D99_APPLIED_SCALE_PROJECTION_INVALID", validation
		)
	var projection: Dictionary = validation["projection"]
	var guard_value: Variant = projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (guard_value is Dictionary):
		return _failure("QSDK_R24D99_APPLIED_SCALE_SOURCE_MISSING")
	var scale_path := "native_angular_velocity_guard_projection.applied_scale"
	var scale_value: Variant = (guard_value as Dictionary).get("applied_scale")
	var applied_scale := (
		float(scale_value) if scale_value is float or scale_value is int else NAN
	)
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D99_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version": COMPONENT_NORM_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"nested_projection_required": true,
		"component_norm_numeric_predicate_required": true,
		"source_path": scale_path,
		"applied_scale": applied_scale,
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func refinement_safe_component_norm_guarded_force_based_applied_scale_projection_v2(
	application_projection: Dictionary,
) -> Dictionary:
	var validation := (
		validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
			application_projection
		)
	)
	if not bool(validation.get("ok", false)):
		return _failure(
			"QSDK_R24D100_APPLIED_SCALE_PROJECTION_INVALID", validation
		)
	var projection: Dictionary = validation["projection"]
	var guard_value: Variant = projection.get(
		"native_angular_velocity_guard_projection"
	)
	if not (guard_value is Dictionary):
		return _failure("QSDK_R24D100_APPLIED_SCALE_SOURCE_MISSING")
	var scale_path := "native_angular_velocity_guard_projection.applied_scale"
	var scale_value: Variant = (guard_value as Dictionary).get("applied_scale")
	var applied_scale := (
		float(scale_value) if scale_value is float or scale_value is int else NAN
	)
	if not is_finite(applied_scale) or applied_scale < 0.0 or applied_scale > 1.0:
		return _failure("QSDK_R24D100_APPLIED_SCALE_VALUE_INVALID")
	return {
		"schema_version": REFINEMENT_SAFE_COMPONENT_NORM_GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"nested_projection_required": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"source_path": scale_path,
		"applied_scale": applied_scale,
		"actuator_mapping_id": String(projection["actuator_mapping_id"]),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Reconstruct the complete R99 outer-guard pair from retained sources. This
## validator is for direct outer-guard projections; nested target projections
## use the distinct validator below.
static func validate_native_angular_velocity_guard_pair_projection_v2(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var guard_value: Variant = guard_pair_projection.get("guard_limit_projection")
	if not (guard_value is Dictionary):
		return _failure("QSDK_R24D99_GUARD_PAIR_RECEIPT_LIMIT_MISSING")
	var guard: Dictionary = guard_value
	var runtime_value: Variant = guard.get("runtime_limit_projection")
	var expected_guard := native_angular_velocity_guard_limit_projection_v1(runtime_value)
	if (
		not bool(expected_guard.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard, expected_guard)
	):
		return _failure("QSDK_R24D99_GUARD_PAIR_RECEIPT_LIMIT_INVALID")
	var expected := native_angular_velocity_guard_pair_projection_v2(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		expected_guard,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D99_GUARD_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d99_component_norm_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_native_angular_velocity_guard_pair_projection_v3(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var guard_value: Variant = guard_pair_projection.get("guard_limit_projection")
	if not (guard_value is Dictionary):
		return _failure("QSDK_R24D100_GUARD_PAIR_RECEIPT_LIMIT_MISSING")
	var guard: Dictionary = guard_value
	var runtime_value: Variant = guard.get("runtime_limit_projection")
	var expected_guard := native_angular_velocity_guard_limit_projection_v1(runtime_value)
	var canonical_outer_guard := (
		bool(expected_guard.get("ok", false))
		and _exact_variant_tree_equal_v1(guard, expected_guard)
	)
	var canonical_inner_target_guard := false
	if bool(expected_guard.get("ok", false)):
		var expected_target := native_angular_velocity_inner_projection_target_v1(
			expected_guard
		)
		if bool(expected_target.get("ok", false)):
			var expected_target_solver: Dictionary = expected_guard.duplicate(true)
			expected_target_solver["guard_limit_rad_s"] = float(
				expected_target["projection_target_limit_rad_s"]
			)
			expected_target_solver["guard_limit_binary32_hex"] = String(
				expected_target["projection_target_limit_binary32_hex"]
			)
			canonical_inner_target_guard = _exact_variant_tree_equal_v1(
				guard, expected_target_solver
			)
	if (
		not bool(expected_guard.get("ok", false))
		or not (canonical_outer_guard or canonical_inner_target_guard)
		or String(guard.get("schema_version", ""))
		!= NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA
		or not bool(guard.get("ok", false))
	):
		return _failure("QSDK_R24D100_GUARD_PAIR_RECEIPT_LIMIT_INVALID")
	var expected := native_angular_velocity_guard_pair_projection_v3(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		guard,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D100_GUARD_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d100_refinement_safe_component_norm_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_nested_native_angular_velocity_guard_pair_projection_v2(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = guard_pair_projection.get("inner_projection_target")
	if not (target_value is Dictionary):
		return _failure("QSDK_R24D99_NESTED_PAIR_RECEIPT_TARGET_MISSING")
	var target: Dictionary = target_value
	var outer_guard_value: Variant = target.get("outer_guard_limit_projection")
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(target, expected_target)
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_RECEIPT_TARGET_INVALID")
	var expected := nested_native_angular_velocity_guard_pair_projection_v2(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		expected_target,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D99_NESTED_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d99_component_norm_nested_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_nested_native_angular_velocity_guard_pair_projection_v3(
	guard_pair_projection: Dictionary,
) -> Dictionary:
	var target_value: Variant = guard_pair_projection.get("inner_projection_target")
	if not (target_value is Dictionary):
		return _failure("QSDK_R24D100_NESTED_PAIR_RECEIPT_TARGET_MISSING")
	var target: Dictionary = target_value
	var outer_guard_value: Variant = target.get("outer_guard_limit_projection")
	var expected_target := native_angular_velocity_inner_projection_target_v1(
		outer_guard_value
	)
	if (
		not bool(expected_target.get("ok", false))
		or not _exact_variant_tree_equal_v1(target, expected_target)
	):
		return _failure("QSDK_R24D100_NESTED_PAIR_RECEIPT_TARGET_INVALID")
	var expected := nested_native_angular_velocity_guard_pair_projection_v3(
		int(guard_pair_projection.get("actuator_index", -1)),
		String(guard_pair_projection.get("actuator_id", "")),
		String(guard_pair_projection.get("joint_id", "")),
		String(guard_pair_projection.get("parent_body_id", "")),
		String(guard_pair_projection.get("child_body_id", "")),
		int(guard_pair_projection.get("source_semantic_step", -1)),
		expected_target,
		_vec3(guard_pair_projection.get("parent_source_angular_velocity_world_rad_s")),
		_vec3(guard_pair_projection.get("child_source_angular_velocity_world_rad_s")),
		_basis_from_json_v1(
			guard_pair_projection.get("parent_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_basis_from_json_v1(
			guard_pair_projection.get("child_inverse_inertia_tensor_world_kg_inv_m2")
		),
		_vec3(guard_pair_projection.get("requested_parent_impulse_world_nms")),
		_vec3(guard_pair_projection.get("requested_child_impulse_world_nms")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(guard_pair_projection, expected)
	):
		return _failure("QSDK_R24D100_NESTED_PAIR_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_guard_pair_validation_v1",
		"ok": true,
		"projection": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Compile and validate the immediate PhysicsServer readback for one completed
## equal-and-opposite pair. Prediction residuals are retained diagnostically;
## health authority is the exact native readback staying inside the guard.
static func native_angular_velocity_guard_readback_receipt_v1(
	guarded_projection: Dictionary,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
) -> Dictionary:
	var guarded_validation := validate_guarded_force_based_joint_impulse_projection_v1(
		guarded_projection
	)
	if not bool(guarded_validation.get("ok", false)):
		return _failure("QSDK_R24D94_GUARD_READBACK_PROJECTION_INVALID")
	var projection: Dictionary = guarded_validation["projection"]
	var guard_limit := float(projection.get("angular_velocity_guard_limit_rad_s", NAN))
	var guard_pair: Dictionary = projection["native_angular_velocity_guard_projection"]
	var predicted_parent := _vec3(
		guard_pair.get("predicted_parent_angular_velocity_world_rad_s")
	)
	var predicted_child := _vec3(
		guard_pair.get("predicted_child_angular_velocity_world_rad_s")
	)
	var parent_speed := parent_angular_velocity_world_rad_s.length()
	var child_speed := child_angular_velocity_world_rad_s.length()
	if (
		not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not predicted_parent.is_finite()
		or not predicted_child.is_finite()
		or not is_finite(guard_limit)
		or not is_finite(parent_speed)
		or not is_finite(child_speed)
		or parent_speed > guard_limit
		or child_speed > guard_limit
	):
		return _failure("QSDK_R24D94_GUARD_READBACK_LIMIT_INVALID")
	return {
		"schema_version": NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA,
		"ok": true,
		"actuator_index": int(projection["actuator_index"]),
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"parent_body_id": String(projection["parent_body_id"]),
		"child_body_id": String(projection["child_body_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"application_semantic_step": int(projection["application_semantic_step"]),
		"parent_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"child_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"parent_angular_velocity_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s
		),
		"child_angular_velocity_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s
		),
		"parent_angular_speed_rad_s": parent_speed,
		"child_angular_speed_rad_s": child_speed,
		"predicted_parent_angular_velocity_world_rad_s": _vector_json(predicted_parent),
		"predicted_child_angular_velocity_world_rad_s": _vector_json(predicted_child),
		"parent_prediction_residual_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s - predicted_parent
		),
		"child_prediction_residual_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s - predicted_child
		),
		"guard_limit_rad_s": guard_limit,
		"both_readbacks_inside_guard": true,
		"readback_count": 2,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_native_angular_velocity_guard_readback_receipt_v1(
	guarded_projection: Dictionary,
	readback_receipt: Dictionary,
) -> Dictionary:
	var expected := native_angular_velocity_guard_readback_receipt_v1(
		guarded_projection,
		_vec3(readback_receipt.get("parent_angular_velocity_world_rad_s")),
		_vec3(readback_receipt.get("child_angular_velocity_world_rad_s")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(readback_receipt, expected)
	):
		return _failure("QSDK_R24D94_GUARD_READBACK_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d94_guard_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R96 native readback authority remains the frozen outer guard. Whether the
## engine readback also remains inside the inner mathematical target is retained
## as a diagnostic and cannot invalidate an otherwise healthy native readback.
static func nested_native_angular_velocity_guard_readback_receipt_v1(
	nested_guarded_projection: Dictionary,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
) -> Dictionary:
	var guarded_validation := (
		validate_nested_guarded_force_based_joint_impulse_projection_v1(
			nested_guarded_projection
		)
	)
	if not bool(guarded_validation.get("ok", false)):
		return _failure("QSDK_R24D96_NESTED_GUARD_READBACK_PROJECTION_INVALID")
	var projection: Dictionary = guarded_validation["projection"]
	var guard_limit := float(projection.get("angular_velocity_guard_limit_rad_s", NAN))
	var target_limit := float(
		projection.get("angular_velocity_projection_target_limit_rad_s", NAN)
	)
	var guard_pair: Dictionary = projection["native_angular_velocity_guard_projection"]
	var predicted_parent := _vec3(
		guard_pair.get("predicted_parent_angular_velocity_world_rad_s")
	)
	var predicted_child := _vec3(
		guard_pair.get("predicted_child_angular_velocity_world_rad_s")
	)
	var parent_speed := parent_angular_velocity_world_rad_s.length()
	var child_speed := child_angular_velocity_world_rad_s.length()
	if (
		not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not predicted_parent.is_finite()
		or not predicted_child.is_finite()
		or not is_finite(guard_limit)
		or not is_finite(target_limit)
		or target_limit <= 0.0
		or target_limit >= guard_limit
		or not is_finite(parent_speed)
		or not is_finite(child_speed)
		or parent_speed > guard_limit
		or child_speed > guard_limit
	):
		return _failure("QSDK_R24D96_NESTED_GUARD_READBACK_LIMIT_INVALID")
	return {
		"schema_version": NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA,
		"ok": true,
		"actuator_index": int(projection["actuator_index"]),
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"parent_body_id": String(projection["parent_body_id"]),
		"child_body_id": String(projection["child_body_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"application_semantic_step": int(projection["application_semantic_step"]),
		"parent_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"child_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"parent_angular_velocity_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s
		),
		"child_angular_velocity_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s
		),
		"parent_angular_speed_rad_s": parent_speed,
		"child_angular_speed_rad_s": child_speed,
		"predicted_parent_angular_velocity_world_rad_s": _vector_json(predicted_parent),
		"predicted_child_angular_velocity_world_rad_s": _vector_json(predicted_child),
		"parent_prediction_residual_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s - predicted_parent
		),
		"child_prediction_residual_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s - predicted_child
		),
		"projection_target_limit_rad_s": target_limit,
		"guard_limit_rad_s": guard_limit,
		"both_readbacks_inside_projection_target": (
			parent_speed <= target_limit and child_speed <= target_limit
		),
		"both_readbacks_inside_guard": true,
		"readback_authority": "frozen_outer_native_guard",
		"inner_target_is_prediction_only": true,
		"outer_guard_changed": false,
		"readback_count": 2,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_nested_native_angular_velocity_guard_readback_receipt_v1(
	nested_guarded_projection: Dictionary,
	readback_receipt: Dictionary,
) -> Dictionary:
	var expected := nested_native_angular_velocity_guard_readback_receipt_v1(
		nested_guarded_projection,
		_vec3(readback_receipt.get("parent_angular_velocity_world_rad_s")),
		_vec3(readback_receipt.get("child_angular_velocity_world_rad_s")),
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(readback_receipt, expected)
	):
		return _failure("QSDK_R24D96_NESTED_GUARD_READBACK_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d96_nested_guard_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R99 immediate native readback authority remains the frozen outer guard, but
## both outer and inner diagnostics use the same component-norm relation as the
## pair solver. No legacy Vector3 norm predicate can accept or reject a write.
static func component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
	nested_guarded_projection: Dictionary,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
) -> Dictionary:
	return _component_norm_nested_native_angular_velocity_guard_readback_receipt_common_v1(
		nested_guarded_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		false,
	)


static func refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
	nested_guarded_projection: Dictionary,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
) -> Dictionary:
	return _component_norm_nested_native_angular_velocity_guard_readback_receipt_common_v1(
		nested_guarded_projection,
		parent_angular_velocity_world_rad_s,
		child_angular_velocity_world_rad_s,
		true,
	)


static func _component_norm_nested_native_angular_velocity_guard_readback_receipt_common_v1(
	nested_guarded_projection: Dictionary,
	parent_angular_velocity_world_rad_s: Vector3,
	child_angular_velocity_world_rad_s: Vector3,
	refinement_safe_guard_required: bool,
) -> Dictionary:
	var guarded_validation := (
		validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
			nested_guarded_projection
		)
		if refinement_safe_guard_required
		else validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
			nested_guarded_projection
		)
	)
	if not bool(guarded_validation.get("ok", false)):
		return _failure("QSDK_R24D99_NESTED_GUARD_READBACK_PROJECTION_INVALID")
	var projection: Dictionary = guarded_validation["projection"]
	var guard_limit := float(projection.get("angular_velocity_guard_limit_rad_s", NAN))
	var target_limit := float(
		projection.get("angular_velocity_projection_target_limit_rad_s", NAN)
	)
	var guard_pair: Dictionary = projection["native_angular_velocity_guard_projection"]
	var predicted_parent := _vec3(
		guard_pair.get("predicted_parent_angular_velocity_world_rad_s")
	)
	var predicted_child := _vec3(
		guard_pair.get("predicted_child_angular_velocity_world_rad_s")
	)
	var parent_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, guard_limit
	)
	var child_outer_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, guard_limit
	)
	var parent_target_relation := angular_velocity_component_norm_limit_relation_v1(
		parent_angular_velocity_world_rad_s, target_limit
	)
	var child_target_relation := angular_velocity_component_norm_limit_relation_v1(
		child_angular_velocity_world_rad_s, target_limit
	)
	if (
		not parent_angular_velocity_world_rad_s.is_finite()
		or not child_angular_velocity_world_rad_s.is_finite()
		or not predicted_parent.is_finite()
		or not predicted_child.is_finite()
		or not is_finite(guard_limit)
		or not is_finite(target_limit)
		or target_limit <= 0.0
		or target_limit >= guard_limit
		or not bool(parent_outer_relation.get("ok", false))
		or not bool(child_outer_relation.get("ok", false))
		or not bool(parent_target_relation.get("ok", false))
		or not bool(child_target_relation.get("ok", false))
		or not bool(parent_outer_relation["inside_or_on_limit"])
		or not bool(child_outer_relation["inside_or_on_limit"])
	):
		return _failure("QSDK_R24D99_NESTED_GUARD_READBACK_LIMIT_INVALID")
	return {
		"schema_version": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA
		),
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"actuator_index": int(projection["actuator_index"]),
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"parent_body_id": String(projection["parent_body_id"]),
		"child_body_id": String(projection["child_body_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"application_semantic_step": int(projection["application_semantic_step"]),
		"parent_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"child_api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
		"parent_angular_velocity_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s
		),
		"child_angular_velocity_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s
		),
		"parent_angular_speed_rad_s": float(parent_outer_relation["component_norm_rad_s"]),
		"child_angular_speed_rad_s": float(child_outer_relation["component_norm_rad_s"]),
		"parent_outer_guard_relation": parent_outer_relation,
		"child_outer_guard_relation": child_outer_relation,
		"parent_projection_target_relation": parent_target_relation,
		"child_projection_target_relation": child_target_relation,
		"predicted_parent_angular_velocity_world_rad_s": _vector_json(predicted_parent),
		"predicted_child_angular_velocity_world_rad_s": _vector_json(predicted_child),
		"parent_prediction_residual_world_rad_s": _vector_json(
			parent_angular_velocity_world_rad_s - predicted_parent
		),
		"child_prediction_residual_world_rad_s": _vector_json(
			child_angular_velocity_world_rad_s - predicted_child
		),
		"projection_target_limit_rad_s": target_limit,
		"guard_limit_rad_s": guard_limit,
		"both_readbacks_inside_projection_target": (
			bool(parent_target_relation["inside_or_on_limit"])
			and bool(child_target_relation["inside_or_on_limit"])
		),
		"both_readbacks_inside_guard": true,
		"readback_authority": "frozen_outer_native_guard_component_norm_relation",
		"inner_target_is_prediction_only": true,
		"outer_guard_changed": false,
		"readback_count": 2,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
	nested_guarded_projection: Dictionary,
	readback_receipt: Dictionary,
) -> Dictionary:
	var expected := (
		component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
			nested_guarded_projection,
			_vec3(readback_receipt.get("parent_angular_velocity_world_rad_s")),
			_vec3(readback_receipt.get("child_angular_velocity_world_rad_s")),
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(readback_receipt, expected)
	):
		return _failure("QSDK_R24D99_NESTED_GUARD_READBACK_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d99_component_norm_nested_guard_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
	nested_guarded_projection: Dictionary,
	readback_receipt: Dictionary,
) -> Dictionary:
	var expected := (
		refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
			nested_guarded_projection,
			_vec3(readback_receipt.get("parent_angular_velocity_world_rad_s")),
			_vec3(readback_receipt.get("child_angular_velocity_world_rad_s")),
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(readback_receipt, expected)
	):
		return _failure("QSDK_R24D100_NESTED_GUARD_READBACK_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d100_refinement_safe_component_norm_nested_guard_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Retain one native readback for each body after the complete R103 aggregate
## write population. The unchanged outer guard remains action authority; the
## inner target remains a prediction diagnostic.
static func order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
	population_projection: Dictionary,
	post_angular_velocity_by_body_id: Dictionary,
) -> Dictionary:
	var population_validation := validate_order_neutral_population_guard_projection_v1(
		population_projection
	)
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D103_POPULATION_READBACK_PROJECTION_INVALID")
	if post_angular_velocity_by_body_id.size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D103_POPULATION_READBACK_CARDINALITY_INVALID")
	var population: Dictionary = population_validation["projection"]
	var body_projection_values: Array = population["ordered_body_projections"]
	var guard_limit := float(population["outer_guard_limit_rad_s"])
	var target_limit := float(population["projection_target_limit_rad_s"])
	var ordered_readbacks: Array = []
	var inside_target_count := 0
	for index in range(ORDERED_BODY_IDS.size()):
		var body_id := String(ORDERED_BODY_IDS[index])
		if not post_angular_velocity_by_body_id.has(body_id):
			return _failure("QSDK_R24D103_POPULATION_READBACK_BODY_MISSING:%s" % body_id)
		var post_value: Variant = post_angular_velocity_by_body_id[body_id]
		var body_projection_value: Variant = body_projection_values[index]
		if not (post_value is Vector3) or not (body_projection_value is Dictionary):
			return _failure("QSDK_R24D103_POPULATION_READBACK_BODY_INVALID:%s" % body_id)
		var post: Vector3 = post_value
		var body_projection: Dictionary = body_projection_value
		var predicted := _vec3(body_projection.get("predicted_angular_velocity_world_rad_s"))
		var outer_relation := angular_velocity_component_norm_limit_relation_v1(post, guard_limit)
		var target_relation := angular_velocity_component_norm_limit_relation_v1(post, target_limit)
		if (
			String(body_projection.get("body_id", "")) != body_id
			or not post.is_finite()
			or not predicted.is_finite()
			or not bool(outer_relation.get("ok", false))
			or not bool(target_relation.get("ok", false))
			or not bool(outer_relation.get("inside_or_on_limit", false))
		):
			return _failure("QSDK_R24D103_POPULATION_READBACK_LIMIT_INVALID:%s" % body_id)
		inside_target_count += int(bool(target_relation["inside_or_on_limit"]))
		(
			ordered_readbacks
			. append(
				{
					"body_id": body_id,
					"api": "PhysicsServer3D.body_get_state/BODY_STATE_ANGULAR_VELOCITY",
					"angular_velocity_world_rad_s": _vector_json(post),
					"angular_speed_rad_s": float(outer_relation["component_norm_rad_s"]),
					"outer_guard_relation": outer_relation,
					"projection_target_relation": target_relation,
					"predicted_angular_velocity_world_rad_s": _vector_json(predicted),
					"prediction_residual_world_rad_s": _vector_json(post - predicted),
					"source_measurement": true,
				}
			)
		)
	return {
		"schema_version": ORDER_NEUTRAL_POPULATION_NATIVE_ANGULAR_VELOCITY_GUARD_READBACK_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"source_semantic_step": int(population["source_semantic_step"]),
		"application_semantic_step": int(population["source_semantic_step"]) + 1,
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_body_readbacks": ordered_readbacks,
		"readback_count": ORDERED_BODY_IDS.size(),
		"projection_target_limit_rad_s": target_limit,
		"guard_limit_rad_s": guard_limit,
		"inside_projection_target_count": inside_target_count,
		"all_readbacks_inside_projection_target": inside_target_count == ORDERED_BODY_IDS.size(),
		"all_readbacks_inside_guard": true,
		"readback_authority": "frozen_outer_native_guard_component_norm_relation",
		"inner_target_is_prediction_only": true,
		"population_readback_shared_by_all_actuator_attributions": true,
		"immediate_after_complete_aggregate_body_application": true,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"outer_guard_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
	population_projection: Dictionary,
	readback_receipt: Dictionary,
) -> Dictionary:
	var readback_values: Variant = readback_receipt.get("ordered_body_readbacks")
	if not (readback_values is Array):
		return _failure("QSDK_R24D103_POPULATION_READBACK_RECEIPT_SOURCE_MISSING")
	var post_by_body_id: Dictionary = {}
	for readback_value in readback_values:
		if not (readback_value is Dictionary):
			return _failure("QSDK_R24D103_POPULATION_READBACK_RECEIPT_BODY_INVALID")
		var readback: Dictionary = readback_value
		var body_id := String(readback.get("body_id", ""))
		if body_id.is_empty() or post_by_body_id.has(body_id):
			return _failure("QSDK_R24D103_POPULATION_READBACK_RECEIPT_BODY_ID_INVALID")
		post_by_body_id[body_id] = _vec3(readback.get("angular_velocity_world_rad_s"))
	var expected := order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
		population_projection,
		post_by_body_id,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(readback_receipt, expected)
	):
		return _failure("QSDK_R24D103_POPULATION_READBACK_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d103_order_neutral_population_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func order_neutral_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
) -> Dictionary:
	var application_validation := validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	var readback_validation := validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
		population_projection,
		population_readback_receipt,
	)
	if not bool(application_validation.get("ok", false)):
		return _failure("QSDK_R24D103_JOINT_READBACK_APPLICATION_INVALID")
	if not bool(readback_validation.get("ok", false)):
		return _failure("QSDK_R24D103_JOINT_READBACK_POPULATION_INVALID")
	var application: Dictionary = application_validation["projection"]
	var population_readback: Dictionary = readback_validation["receipt"]
	var parent_body_id := String(application["parent_body_id"])
	var child_body_id := String(application["child_body_id"])
	var parent_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", parent_body_id
	)
	var child_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", child_body_id
	)
	if parent_readback.is_empty() or child_readback.is_empty():
		return _failure("QSDK_R24D103_JOINT_READBACK_BODY_MISSING")
	return {
		"schema_version": ORDER_NEUTRAL_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"actuator_index": int(application["actuator_index"]),
		"actuator_id": String(application["actuator_id"]),
		"joint_id": String(application["joint_id"]),
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": int(application["source_semantic_step"]),
		"application_semantic_step": int(application["application_semantic_step"]),
		"parent_angular_velocity_world_rad_s": parent_readback["angular_velocity_world_rad_s"],
		"child_angular_velocity_world_rad_s": child_readback["angular_velocity_world_rad_s"],
		"parent_angular_speed_rad_s": float(parent_readback["angular_speed_rad_s"]),
		"child_angular_speed_rad_s": float(child_readback["angular_speed_rad_s"]),
		"parent_outer_guard_relation": parent_readback["outer_guard_relation"],
		"child_outer_guard_relation": child_readback["outer_guard_relation"],
		"parent_projection_target_relation": parent_readback["projection_target_relation"],
		"child_projection_target_relation": child_readback["projection_target_relation"],
		"predicted_parent_angular_velocity_world_rad_s":
		parent_readback["predicted_angular_velocity_world_rad_s"],
		"predicted_child_angular_velocity_world_rad_s":
		child_readback["predicted_angular_velocity_world_rad_s"],
		"parent_prediction_residual_world_rad_s":
		parent_readback["prediction_residual_world_rad_s"],
		"child_prediction_residual_world_rad_s": child_readback["prediction_residual_world_rad_s"],
		"projection_target_limit_rad_s":
		float(population_readback["projection_target_limit_rad_s"]),
		"guard_limit_rad_s": float(population_readback["guard_limit_rad_s"]),
		"both_readbacks_inside_projection_target":
		(
			bool(
				(parent_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
			and bool(
				(child_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
		),
		"both_readbacks_inside_guard": true,
		"shared_population_readback": true,
		"attributed_native_readback_count": 0,
		"population_native_readback_count": ORDERED_BODY_IDS.size(),
		"readback_authority": "frozen_outer_native_guard_component_norm_relation",
		"inner_target_is_prediction_only": true,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_order_neutral_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
	joint_readback_receipt: Dictionary,
) -> Dictionary:
	var expected := order_neutral_population_joint_angular_velocity_readback_receipt_v1(
		application_projection,
		population_projection,
		population_readback_receipt,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(joint_readback_receipt, expected)
	):
		return _failure("QSDK_R24D103_JOINT_READBACK_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d103_order_neutral_population_joint_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
) -> Dictionary:
	var application_validation := (
		validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
			application_projection,
			population_projection,
		)
	)
	var population_validation := validate_joint_target_monotone_population_guard_projection_v1(
		population_projection
	)
	if not bool(application_validation.get("ok", false)):
		return _failure("QSDK_R24D107_JOINT_READBACK_APPLICATION_INVALID")
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D107_JOINT_READBACK_POPULATION_INVALID")
	var population: Dictionary = population_validation["projection"]
	var body_guard: Dictionary = population["body_guard_population_projection"]
	var readback_validation := (
		validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			body_guard,
			population_readback_receipt,
		)
	)
	if not bool(readback_validation.get("ok", false)):
		return _failure("QSDK_R24D107_JOINT_READBACK_BODY_POPULATION_INVALID")
	var application: Dictionary = application_validation["projection"]
	var population_readback: Dictionary = readback_validation["receipt"]
	var parent_body_id := String(application["parent_body_id"])
	var child_body_id := String(application["child_body_id"])
	var parent_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", parent_body_id
	)
	var child_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", child_body_id
	)
	if parent_readback.is_empty() or child_readback.is_empty():
		return _failure("QSDK_R24D107_JOINT_READBACK_BODY_MISSING")
	return {
		"schema_version":
		JOINT_TARGET_MONOTONE_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"actuator_index": int(application["actuator_index"]),
		"actuator_id": String(application["actuator_id"]),
		"joint_id": String(application["joint_id"]),
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": int(application["source_semantic_step"]),
		"application_semantic_step": int(application["application_semantic_step"]),
		"parent_angular_velocity_world_rad_s": parent_readback["angular_velocity_world_rad_s"],
		"child_angular_velocity_world_rad_s": child_readback["angular_velocity_world_rad_s"],
		"parent_angular_speed_rad_s": float(parent_readback["angular_speed_rad_s"]),
		"child_angular_speed_rad_s": float(child_readback["angular_speed_rad_s"]),
		"parent_outer_guard_relation": parent_readback["outer_guard_relation"],
		"child_outer_guard_relation": child_readback["outer_guard_relation"],
		"parent_projection_target_relation": parent_readback["projection_target_relation"],
		"child_projection_target_relation": child_readback["projection_target_relation"],
		"predicted_parent_angular_velocity_world_rad_s":
		parent_readback["predicted_angular_velocity_world_rad_s"],
		"predicted_child_angular_velocity_world_rad_s":
		child_readback["predicted_angular_velocity_world_rad_s"],
		"parent_prediction_residual_world_rad_s":
		parent_readback["prediction_residual_world_rad_s"],
		"child_prediction_residual_world_rad_s":
		child_readback["prediction_residual_world_rad_s"],
		"projection_target_limit_rad_s":
		float(population_readback["projection_target_limit_rad_s"]),
		"guard_limit_rad_s": float(population_readback["guard_limit_rad_s"]),
		"both_readbacks_inside_projection_target":
		(
			bool(
				(parent_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
			and bool(
				(child_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
		),
		"both_readbacks_inside_guard": true,
		"shared_population_readback": true,
		"attributed_native_readback_count": 0,
		"population_native_readback_count": ORDERED_BODY_IDS.size(),
		"readback_authority": "frozen_outer_native_guard_component_norm_relation",
		"joint_target_monotone_projection_is_prewrite_action_authority": true,
		"inner_target_is_prediction_only": true,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
	joint_readback_receipt: Dictionary,
) -> Dictionary:
	var expected := (
		joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
			application_projection,
			population_projection,
			population_readback_receipt,
		)
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(joint_readback_receipt, expected)
	):
		return _failure("QSDK_R24D107_JOINT_READBACK_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d107_joint_target_monotone_population_joint_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
) -> Dictionary:
	var application_validation := validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	var population_validation := validate_joint_space_effective_inertia_population_guard_projection_v1(
		population_projection
	)
	if not bool(application_validation.get("ok", false)):
		return _failure("QSDK_R24D109_JOINT_READBACK_APPLICATION_INVALID")
	if not bool(population_validation.get("ok", false)):
		return _failure("QSDK_R24D109_JOINT_READBACK_POPULATION_INVALID")
	var population: Dictionary = population_validation["projection"]
	var body_guard: Dictionary = population["body_guard_population_projection"]
	var readback_validation := validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
		body_guard,
		population_readback_receipt,
	)
	if not bool(readback_validation.get("ok", false)):
		return _failure("QSDK_R24D109_JOINT_READBACK_BODY_POPULATION_INVALID")
	var application: Dictionary = application_validation["projection"]
	var population_readback: Dictionary = readback_validation["receipt"]
	var parent_body_id := String(application["parent_body_id"])
	var child_body_id := String(application["child_body_id"])
	var parent_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", parent_body_id
	)
	var child_readback := _dictionary_row_by_id_v1(
		population_readback["ordered_body_readbacks"], "body_id", child_body_id
	)
	if parent_readback.is_empty() or child_readback.is_empty():
		return _failure("QSDK_R24D109_JOINT_READBACK_BODY_MISSING")
	return {
		"schema_version":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_JOINT_ANGULAR_VELOCITY_READBACK_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"actuator_index": int(application["actuator_index"]),
		"actuator_id": String(application["actuator_id"]),
		"joint_id": String(application["joint_id"]),
		"parent_body_id": parent_body_id,
		"child_body_id": child_body_id,
		"source_semantic_step": int(application["source_semantic_step"]),
		"application_semantic_step": int(application["application_semantic_step"]),
		"parent_angular_velocity_world_rad_s": parent_readback["angular_velocity_world_rad_s"],
		"child_angular_velocity_world_rad_s": child_readback["angular_velocity_world_rad_s"],
		"parent_angular_speed_rad_s": float(parent_readback["angular_speed_rad_s"]),
		"child_angular_speed_rad_s": float(child_readback["angular_speed_rad_s"]),
		"parent_outer_guard_relation": parent_readback["outer_guard_relation"],
		"child_outer_guard_relation": child_readback["outer_guard_relation"],
		"parent_projection_target_relation": parent_readback["projection_target_relation"],
		"child_projection_target_relation": child_readback["projection_target_relation"],
		"predicted_parent_angular_velocity_world_rad_s":
		parent_readback["predicted_angular_velocity_world_rad_s"],
		"predicted_child_angular_velocity_world_rad_s":
		child_readback["predicted_angular_velocity_world_rad_s"],
		"parent_prediction_residual_world_rad_s":
		parent_readback["prediction_residual_world_rad_s"],
		"child_prediction_residual_world_rad_s":
		child_readback["prediction_residual_world_rad_s"],
		"projection_target_limit_rad_s":
		float(population_readback["projection_target_limit_rad_s"]),
		"guard_limit_rad_s": float(population_readback["guard_limit_rad_s"]),
		"both_readbacks_inside_projection_target":
		(
			bool(
				(parent_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
			and bool(
				(child_readback["projection_target_relation"] as Dictionary)["inside_or_on_limit"]
			)
		),
		"both_readbacks_inside_guard": true,
		"shared_population_readback": true,
		"attributed_native_readback_count": 0,
		"population_native_readback_count": ORDERED_BODY_IDS.size(),
		"readback_authority": "frozen_outer_native_guard_component_norm_relation",
		"joint_space_effective_inertia_projection_is_prewrite_action_authority": true,
		"inner_target_is_prediction_only": true,
		"immediate_before_solver_step": true,
		"source_measurement": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	population_readback_receipt: Dictionary,
	joint_readback_receipt: Dictionary,
) -> Dictionary:
	var expected := joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
		application_projection,
		population_projection,
		population_readback_receipt,
	)
	if (
		not bool(expected.get("ok", false))
		or not _exact_variant_tree_equal_v1(joint_readback_receipt, expected)
	):
		return _failure("QSDK_R24D109_JOINT_READBACK_RECEIPT_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d109_joint_space_effective_inertia_population_joint_readback_validation_v1",
		"ok": true,
		"receipt": expected.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _dictionary_row_by_id_v1(
	values: Array,
	key: String,
	wanted: String,
) -> Dictionary:
	for value in values:
		if value is Dictionary and String((value as Dictionary).get(key, "")) == wanted:
			return (value as Dictionary).duplicate(true)
	return {}


## Bind one completed step's source-measured relative velocity to the exact
## impulse input above. Work is J * mean(qdot_pre, qdot_post); no mechanical-
## energy residual or unmeasured constraint/passive term participates.
static func force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := (
		validate_force_based_joint_impulse_projection_v1(application_projection)
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D87_FORCE_BASED_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var validated_projection: Dictionary = projection_validation["projection"]
	if (
		String(validated_projection.get("schema_version", ""))
		!= "sporespore_qsdk_r24d87_force_based_joint_impulse_projection_v1"
		or not bool(validated_projection.get("ok", false))
		or String(validated_projection.get("actuator_mapping_id", ""))
		!= FORCE_BASED_ACTUATOR_MAPPING_ID
		or post_semantic_step
		!= int(validated_projection.get("application_semantic_step", -1))
		or not bool(validated_projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
	):
		return _failure("QSDK_R24D87_FORCE_BASED_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		validated_projection.get(
			"measured_pre_step_relative_velocity_rad_s", NAN
		)
	)
	var applied_signed_impulse_nms := float(
		validated_projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		validated_projection.get(
			"published_maximum_outer_step_impulse_nms", NAN
		)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
		or bool(
			validated_projection.get(
				"mechanical_energy_residual_used_as_work_source", true
			)
		)
	):
		return _failure("QSDK_R24D87_FORCE_BASED_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := 0.5 * (
		pre_relative_velocity_rad_s + post_relative_velocity_rad_s
	)
	var net_work_j := (
		applied_signed_impulse_nms * centered_relative_velocity_rad_s
	)
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D87_FORCE_BASED_WORK_NONFINITE")
	return {
		"schema_version": "sporespore_qsdk_r24d87_force_based_joint_work_projection_v1",
		"ok": true,
		"work_mapping_id": FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id": FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(validated_projection["actuator_id"]),
		"joint_id": String(validated_projection["joint_id"]),
		"source_semantic_step": int(validated_projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R94 uses the same centered pre/post source-measured work equation as R87,
## but binds it to the velocity-guarded impulse actually written to the bodies.
static func guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := (
		validate_guarded_force_based_joint_impulse_projection_v1(application_projection)
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D94_GUARDED_WORK_APPLICATION_INVALID", projection_validation
		)
	var validated_projection: Dictionary = projection_validation["projection"]
	if (
		String(validated_projection.get("schema_version", ""))
		!= GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
		or String(validated_projection.get("actuator_mapping_id", ""))
		!= GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		or String(validated_projection.get("work_mapping_id", ""))
		!= GUARDED_FORCE_BASED_WORK_MAPPING_ID
		or post_semantic_step
		!= int(validated_projection.get("application_semantic_step", -1))
		or not bool(validated_projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
	):
		return _failure("QSDK_R24D94_GUARDED_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		validated_projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(
		validated_projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		validated_projection.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
		or bool(
			validated_projection.get(
				"mechanical_energy_residual_used_as_work_source", true
			)
		)
	):
		return _failure("QSDK_R24D94_GUARDED_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := 0.5 * (
		pre_relative_velocity_rad_s + post_relative_velocity_rad_s
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D94_GUARDED_WORK_NONFINITE")
	return {
		"schema_version": GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA,
		"ok": true,
		"work_mapping_id": GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id": GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(validated_projection["actuator_id"]),
		"joint_id": String(validated_projection["joint_id"]),
		"source_semantic_step": int(validated_projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged": bool(
			validated_projection["native_angular_velocity_guard_engaged"]
		),
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R96 keeps the R87/R94 centered source-measured work equation and binds it to
## the impulse selected by the nested projection target.
static func nested_guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := (
		validate_nested_guarded_force_based_joint_impulse_projection_v1(
			application_projection
		)
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D96_NESTED_GUARDED_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var validated_projection: Dictionary = projection_validation["projection"]
	if (
		String(validated_projection.get("schema_version", ""))
		!= NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
		or String(validated_projection.get("actuator_mapping_id", ""))
		!= NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		or String(validated_projection.get("work_mapping_id", ""))
		!= NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		or post_semantic_step
		!= int(validated_projection.get("application_semantic_step", -1))
		or not bool(validated_projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
	):
		return _failure("QSDK_R24D96_NESTED_GUARDED_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		validated_projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(
		validated_projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		validated_projection.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
		or bool(
			validated_projection.get(
				"mechanical_energy_residual_used_as_work_source", true
			)
		)
	):
		return _failure("QSDK_R24D96_NESTED_GUARDED_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := 0.5 * (
		pre_relative_velocity_rad_s + post_relative_velocity_rad_s
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D96_NESTED_GUARDED_WORK_NONFINITE")
	return {
		"schema_version": NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA,
		"ok": true,
		"work_mapping_id": NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id": NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(validated_projection["actuator_id"]),
		"joint_id": String(validated_projection["joint_id"]),
		"source_semantic_step": int(validated_projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged": bool(
			validated_projection["native_angular_velocity_guard_engaged"]
		),
		"native_angular_velocity_projection_target_engaged": bool(
			validated_projection["native_angular_velocity_projection_target_engaged"]
		),
		"angular_velocity_guard_limit_rad_s": float(
			validated_projection["angular_velocity_guard_limit_rad_s"]
		),
		"angular_velocity_projection_target_limit_rad_s": float(
			validated_projection["angular_velocity_projection_target_limit_rad_s"]
		),
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R99 keeps the centered R87/R96 work equation and binds it to the distinct
## component-norm actuator mapping. The numerical guard fix does not invent a
## new work source or alter the published cap.
static func component_norm_nested_guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	return _component_norm_nested_guarded_force_based_joint_work_projection_common_v1(
		application_projection,
		post_semantic_step,
		post_source_measurement,
		post_axis_parent_local,
		post_relative_velocity_rad_s,
		false,
	)


static func refinement_safe_component_norm_nested_guarded_force_based_joint_work_projection_v2(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	return _component_norm_nested_guarded_force_based_joint_work_projection_common_v1(
		application_projection,
		post_semantic_step,
		post_source_measurement,
		post_axis_parent_local,
		post_relative_velocity_rad_s,
		true,
	)


static func _component_norm_nested_guarded_force_based_joint_work_projection_common_v1(
	application_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
	refinement_safe_guard_required: bool,
) -> Dictionary:
	var projection_validation := (
		validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
			application_projection
		)
		if refinement_safe_guard_required
		else validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
			application_projection
		)
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D99_NESTED_GUARDED_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var validated_projection: Dictionary = projection_validation["projection"]
	if (
		String(validated_projection.get("schema_version", ""))
		!= (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_IMPULSE_PROJECTION_SCHEMA
		)
		or String(validated_projection.get("actuator_mapping_id", ""))
		!= (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		or String(validated_projection.get("work_mapping_id", ""))
		!= (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		or String(validated_projection.get("numeric_predicate_id", ""))
		!= COMPONENT_NORM_NUMERIC_PREDICATE_ID
		or not bool(
			validated_projection.get("component_norm_numeric_predicate_required", false)
		)
		or post_semantic_step
		!= int(validated_projection.get("application_semantic_step", -1))
		or not bool(validated_projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
	):
		return _failure("QSDK_R24D99_NESTED_GUARDED_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		validated_projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(
		validated_projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		validated_projection.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
		or bool(
			validated_projection.get(
				"mechanical_energy_residual_used_as_work_source", true
			)
		)
	):
		return _failure("QSDK_R24D99_NESTED_GUARDED_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := 0.5 * (
		pre_relative_velocity_rad_s + post_relative_velocity_rad_s
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D99_NESTED_GUARDED_WORK_NONFINITE")
	return {
		"schema_version": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA
		),
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"work_mapping_id": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		),
		"actuator_mapping_id": (
			REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			if refinement_safe_guard_required
			else COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		),
		"actuator_id": String(validated_projection["actuator_id"]),
		"joint_id": String(validated_projection["joint_id"]),
		"source_semantic_step": int(validated_projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged": bool(
			validated_projection["native_angular_velocity_guard_engaged"]
		),
		"native_angular_velocity_projection_target_engaged": bool(
			validated_projection["native_angular_velocity_projection_target_engaged"]
		),
		"angular_velocity_guard_limit_rad_s": float(
			validated_projection["angular_velocity_guard_limit_rad_s"]
		),
		"angular_velocity_projection_target_limit_rad_s": float(
			validated_projection["angular_velocity_projection_target_limit_rad_s"]
		),
		"component_norm_numeric_predicate_required": true,
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R103 retains the centered R87 work equation and changes only where the
## applied joint impulse is attributed: the validated common-scale population.
static func order_neutral_population_guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D103_POPULATION_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var projection: Dictionary = projection_validation["projection"]
	if (
		post_semantic_step != int(projection.get("application_semantic_step", -1))
		or not bool(projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
		or bool(projection.get("mechanical_energy_residual_used_as_work_source", true))
	):
		return _failure("QSDK_R24D103_POPULATION_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(projection.get("applied_signed_joint_impulse_nms", NAN))
	var published_cap_nms := float(projection.get("published_maximum_outer_step_impulse_nms", NAN))
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
	):
		return _failure("QSDK_R24D103_POPULATION_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := (
		0.5 * (pre_relative_velocity_rad_s + post_relative_velocity_rad_s)
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D103_POPULATION_WORK_NONFINITE")
	return {
		"schema_version": ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"work_mapping_id": ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id": ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"common_applied_scale": float(projection["common_applied_scale"]),
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged":
		bool(projection["native_angular_velocity_guard_engaged"]),
		"native_angular_velocity_projection_target_engaged":
		bool(projection["native_angular_velocity_projection_target_engaged"]),
		"angular_velocity_guard_limit_rad_s":
		float(projection["angular_velocity_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(projection["angular_velocity_projection_target_limit_rad_s"]),
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R107 retains the centered R87 work equation and binds it to the final
## attribution selected by the target pre-scale plus R103 body guard.
static func joint_target_monotone_population_guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := (
		validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
			application_projection,
			population_projection,
		)
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D107_POPULATION_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var projection: Dictionary = projection_validation["projection"]
	if (
		post_semantic_step != int(projection.get("application_semantic_step", -1))
		or not bool(projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
		or bool(projection.get("mechanical_energy_residual_used_as_work_source", true))
	):
		return _failure("QSDK_R24D107_POPULATION_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(
		projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		projection.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
	):
		return _failure("QSDK_R24D107_POPULATION_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := (
		0.5 * (pre_relative_velocity_rad_s + post_relative_velocity_rad_s)
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D107_POPULATION_WORK_NONFINITE")
	return {
		"schema_version":
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"work_mapping_id": JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id":
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"target_common_pre_scale": float(projection["target_common_pre_scale"]),
		"body_guard_common_applied_scale":
		float(projection["body_guard_common_applied_scale"]),
		"nominal_composed_common_scale":
		float(projection["nominal_composed_common_scale"]),
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged":
		bool(projection["native_angular_velocity_guard_engaged"]),
		"native_angular_velocity_projection_target_engaged":
		bool(projection["native_angular_velocity_projection_target_engaged"]),
		"joint_target_monotone_guard_engaged":
		bool(projection["joint_target_monotone_guard_engaged"]),
		"angular_velocity_guard_limit_rad_s":
		float(projection["angular_velocity_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(projection["angular_velocity_projection_target_limit_rad_s"]),
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_target_monotone_population_projection_required": true,
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func joint_space_effective_inertia_population_guarded_force_based_joint_work_projection_v1(
	application_projection: Dictionary,
	population_projection: Dictionary,
	post_semantic_step: int,
	post_source_measurement: bool,
	post_axis_parent_local: Vector3,
	post_relative_velocity_rad_s: float,
) -> Dictionary:
	var projection_validation := validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
		application_projection,
		population_projection,
	)
	if not bool(projection_validation.get("ok", false)):
		return _failure(
			"QSDK_R24D109_POPULATION_WORK_APPLICATION_INVALID",
			projection_validation,
		)
	var projection: Dictionary = projection_validation["projection"]
	if (
		post_semantic_step != int(projection.get("application_semantic_step", -1))
		or not bool(projection.get("source_measurement", false))
		or not post_source_measurement
		or post_axis_parent_local != FORCE_BASED_AXIS_PARENT_LOCAL
		or not is_finite(post_relative_velocity_rad_s)
		or bool(projection.get("mechanical_energy_residual_used_as_work_source", true))
	):
		return _failure("QSDK_R24D109_POPULATION_WORK_SOURCE_INVALID")
	var pre_relative_velocity_rad_s := float(
		projection.get("measured_pre_step_relative_velocity_rad_s", NAN)
	)
	var applied_signed_impulse_nms := float(
		projection.get("applied_signed_joint_impulse_nms", NAN)
	)
	var published_cap_nms := float(
		projection.get("published_maximum_outer_step_impulse_nms", NAN)
	)
	if (
		not is_finite(pre_relative_velocity_rad_s)
		or not is_finite(applied_signed_impulse_nms)
		or not is_finite(published_cap_nms)
		or absf(applied_signed_impulse_nms) > published_cap_nms
	):
		return _failure("QSDK_R24D109_POPULATION_WORK_APPLICATION_INVALID")
	var centered_relative_velocity_rad_s := (
		0.5 * (pre_relative_velocity_rad_s + post_relative_velocity_rad_s)
	)
	var net_work_j := applied_signed_impulse_nms * centered_relative_velocity_rad_s
	if not is_finite(centered_relative_velocity_rad_s) or not is_finite(net_work_j):
		return _failure("QSDK_R24D109_POPULATION_WORK_NONFINITE")
	return {
		"schema_version":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_JOINT_WORK_PROJECTION_SCHEMA,
		"ok": true,
		"numeric_predicate_id": COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"work_mapping_id":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"actuator_mapping_id":
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"actuator_id": String(projection["actuator_id"]),
		"joint_id": String(projection["joint_id"]),
		"source_semantic_step": int(projection["source_semantic_step"]),
		"post_semantic_step": post_semantic_step,
		"joint_space_common_pre_scale": float(projection["joint_space_common_pre_scale"]),
		"body_guard_common_applied_scale":
		float(projection["body_guard_common_applied_scale"]),
		"nominal_composed_common_scale":
		float(projection["nominal_composed_common_scale"]),
		"solved_signed_joint_impulse_nms":
		float(projection["solved_signed_joint_impulse_nms"]),
		"applied_signed_joint_impulse_nms": applied_signed_impulse_nms,
		"pre_relative_velocity_rad_s": pre_relative_velocity_rad_s,
		"post_relative_velocity_rad_s": post_relative_velocity_rad_s,
		"centered_relative_velocity_rad_s": centered_relative_velocity_rad_s,
		"net_motor_work_j": net_work_j,
		"positive_motor_work_j": maxf(net_work_j, 0.0),
		"absorbed_motor_work_j": maxf(-net_work_j, 0.0),
		"native_angular_velocity_guard_engaged":
		bool(projection["native_angular_velocity_guard_engaged"]),
		"native_angular_velocity_projection_target_engaged":
		bool(projection["native_angular_velocity_projection_target_engaged"]),
		"joint_space_effective_inertia_guard_engaged":
		bool(projection["joint_space_effective_inertia_guard_engaged"]),
		"angular_velocity_guard_limit_rad_s":
		float(projection["angular_velocity_guard_limit_rad_s"]),
		"angular_velocity_projection_target_limit_rad_s":
		float(projection["angular_velocity_projection_target_limit_rad_s"]),
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"joint_space_effective_inertia_population_projection_required": true,
		"pre_source_measurement": true,
		"post_source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## The same floor constructor is used by the native route and detached source
## binding checks. A detached floor allocates body/shape resources, not a world.
static func create_floor_v1() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "r24d57_recovery_floor"
	floor.set_meta("lab_body_id", "floor")
	floor.collision_layer = RECOVERY_FLOOR_COLLISION_LAYER
	floor.collision_mask = RECOVERY_FLOOR_COLLISION_MASK
	floor.position = Vector3(0.0, -0.05, 0.0)
	floor.physics_material_override = _material()
	var floor_shape_node := CollisionShape3D.new()
	floor_shape_node.name = "floor_shape"
	floor_shape_node.set_meta("lab_shape_id", "floor")
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 0.1, 20.0)
	floor_shape.margin = COLLISION_MARGIN_M
	floor_shape_node.shape = floor_shape
	floor.add_child(floor_shape_node)
	return floor


## Build exactly one isolated native world while the caller keeps physics
## inactive.  The one process-frame yield resolves NodePaths but cannot take a
## solver step because this function explicitly deactivates PhysicsServer3D.
static func build_world_v1(tree: SceneTree, sdk: Object, context: Dictionary) -> Dictionary:
	var finite: Script = load("res://sdk/adapters/godot/gdscript/r10dh_campaign_context_v1.gd")
	if finite.selected() and not finite.take_world_permission():
		return _failure("R10DH_WORLD_PERMISSION_REFUSED")
	var discovery: Script = load("res://sdk/discovery/recovery_discovery_context_v1.gd")
	if discovery.selected() and not discovery.take_world_permission():
		return _failure("DISCOVERY_WORLD_PERMISSION_REFUSED")
	# A diagnostic image binding is enough for pure context/replay interfaces,
	# never permission to inherit a predecessor's physical construction gate.
	var runtime_profile: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	if runtime_profile.r10dg_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10dg_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10DG_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ap_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ap_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AP_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10am_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10am_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AM_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10aj_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10aj_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AJ_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ai_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ai_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AI_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ag_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ag_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AG_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10af_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10af_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AF_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ae_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ae_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AE_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ad_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ad_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AD_NATIVE_WORLD_QUALIFICATION_PENDING")
	if runtime_profile.r10ac_diagnostic_runtime_selected_v1():
		var diagnostic_guard: Script = load("res://sdk/adapters/godot/gdscript/r10ac_native_world_guard_v1.gd")
		if not diagnostic_guard.take_world_permission_v1():
			return _failure("R10AC_NATIVE_WORLD_QUALIFICATION_PENDING")
	if tree == null:
		return _failure("QSDK_R24D57_WORLD_TREE_MISSING")
	var blueprint := compile_blueprint_v1(sdk, context)
	if not bool(blueprint.get("ok", false)):
		return blueprint
	var initializer_projection := native_initializer_projection_contract_v2(
		sdk, blueprint
	)
	if not bool(initializer_projection.get("ok", false)):
		return _failure(
			"QSDK_R24D83_WORLD_INITIALIZER_PROJECTION_INVALID",
			{"projection": initializer_projection},
		)
	var complete_energy_profile := bool(
		context.get("complete_energy_profile_selected", false)
	)
	var solver_coupled_complete_energy_profile := bool(
		context.get("solver_coupled_complete_energy_profile_selected", false)
	)
	var discrete_staging_complete_energy_profile := bool(
		context.get("discrete_staging_complete_energy_profile_selected", false)
	)
	var rotation_aware_energy_ledger_profile := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	var contiguous_boundary_transport_profile := bool(
		context.get("contiguous_boundary_transport_profile_selected", false)
	)
	if solver_coupled_complete_energy_profile and not complete_energy_profile:
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_PROFILE_REQUIRED")
	if (
		discrete_staging_complete_energy_profile
		and (
			not solver_coupled_complete_energy_profile
			or String(context.get("energy_route_id", ""))
			!= R148_COMPLETE_ENERGY_ROUTE_ID
		)
	):
		return _failure("QSDK_R24D149_DISCRETE_STAGING_PROFILE_INVALID")
	if (
		rotation_aware_energy_ledger_profile
		and (
			not complete_energy_profile
			or not solver_coupled_complete_energy_profile
			or not discrete_staging_complete_energy_profile
			or not RotationAwareEnergyLedgerScript.context_authority_exact_v1(context)
		)
	):
		return _failure("QSDK_R24D162_RECOVERY_LEDGER_PROFILE_INVALID")
	if (
		contiguous_boundary_transport_profile
		and (
			not rotation_aware_energy_ledger_profile
			or String(context.get("contiguous_boundary_transport_design_id", ""))
			!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
			or String(context.get("contiguous_boundary_transport_profile_id", ""))
			!= ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
		)
	):
		return _failure("QSDK_R24D168_BOUNDARY_TRANSPORT_PROFILE_INVALID")
	if (
		rotation_aware_energy_ledger_profile
		and not bool(context.get("physical_world_construction_authorized", false))
	):
		return _failure("QSDK_R24D162_PHYSICAL_WORLD_CONSTRUCTION_BLOCKED")
	PhysicsServer3D.set_active(false)
	var viewport := SubViewport.new()
	viewport.name = "R24D57GodotRecoveryViewport"
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "R24D57GodotRecoveryWorld"
	viewport.add_child(world)

	var floor := create_floor_v1()
	world.add_child(floor)

	var body_nodes: Dictionary = {}
	var ordered_body_nodes: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body_spec: Dictionary = blueprint["body_by_id"][body_id]
		var body := SemanticContactRigidBodyScript.new() as RigidBody3D
		body.name = "r24d57_%s" % body_id
		body.set_meta("lab_body_id", body_id)
		body.mass = float(body_spec["mass_kg"])
		body.inertia = _vec3(body_spec["inertia_diagonal_kg_m2"])
		body.position = blueprint["positions"][body_id]
		body.basis = blueprint["bases"][body_id]
		body.gravity_scale = 1.0
		body.constant_force = Vector3.ZERO
		body.constant_torque = Vector3.ZERO
		body.custom_integrator = false
		body.axis_lock_linear_x = false
		body.axis_lock_linear_y = false
		body.axis_lock_linear_z = false
		body.freeze = true
		body.can_sleep = false
		body.continuous_cd = not complete_energy_profile
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.collision_layer = RECOVERY_ROBOT_COLLISION_LAYER
		body.collision_mask = RECOVERY_ROBOT_COLLISION_MASK
		body.contact_monitor = true
		body.max_contacts_reported = 64
		body.physics_material_override = _material()
		var shape_result := _body_shape(body_spec, body_id)
		if not bool(shape_result.get("ok", false)):
			viewport.queue_free()
			return _failure(
				"QSDK_R24D57_WORLD_BODY_SHAPE_INVALID:%s" % body_id,
				{"world_attempt_count": 1},
			)
		body.add_child(shape_result["shape_node"])
		world.add_child(body)
		body_nodes[body_id] = body
		ordered_body_nodes.append(body)
	var collision_filter_readback := validate_godot_recovery_collision_filter_readback_v1(
		int(floor.collision_layer),
		int(floor.collision_mask),
		int((ordered_body_nodes[0] as RigidBody3D).collision_layer),
		int((ordered_body_nodes[0] as RigidBody3D).collision_mask),
		int((ordered_body_nodes[1] as RigidBody3D).collision_layer),
		int((ordered_body_nodes[1] as RigidBody3D).collision_mask),
	)
	if not bool(collision_filter_readback.get("ok", false)):
		viewport.queue_free()
		return _failure(
			"QSDK_R24D83_WORLD_COLLISION_FILTER_READBACK_INVALID",
			{
				"readback": collision_filter_readback,
				"model_construction_attempt_count": 1,
				"native_scene_node_construction_attempted": true,
				"world_attempt_count": 1,
			},
		)

	var joint_nodes: Dictionary = {}
	var joint_by_actuator_id: Dictionary = {}
	var host_cap_projection_by_actuator_id: Dictionary = {}
	var host_limit_projection_by_joint_id: Dictionary = {}
	var ordered_joint_nodes: Array = []
	var initializer_projection_rows: Array = initializer_projection[
		"ordered_joint_projections"
	]
	for index in range(8):
		var joint_id := String(ORDERED_JOINT_IDS[index])
		var actuator_id := String(ORDERED_ACTUATOR_IDS[index])
		var joint_spec: Dictionary = blueprint["joint_by_id"][joint_id]
		var initializer_row: Dictionary = initializer_projection_rows[index]
		if String(initializer_row.get("joint_id", "")) != joint_id:
			viewport.queue_free()
			return _failure(
				"QSDK_R24D83_WORLD_INITIALIZER_PROJECTION_ORDER_INVALID:%s"
				% joint_id,
				{
					"model_construction_attempt_count": 1,
					"native_scene_node_construction_attempted": true,
					"world_attempt_count": 1,
				},
			)
		var host_limit_projection := godot_initial_relative_joint_limit_projection_v1(
			joint_id,
			float(initializer_row["native_projected_joint_angle_rad"]),
			float(joint_spec["lower_limit_rad"]),
			float(joint_spec["upper_limit_rad"]),
			CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
		)
		if not bool(host_limit_projection.get("ok", false)):
			viewport.queue_free()
			return _failure(
				"QSDK_R24D83_WORLD_JOINT_LIMIT_PROJECTION_INVALID:%s" % joint_id,
				{
					"projection": host_limit_projection,
					"model_construction_attempt_count": 1,
					"native_scene_node_construction_attempted": true,
					"world_attempt_count": 1,
				},
			)
		var published_cap := float(
			(blueprint["cap_by_actuator_id"][actuator_id] as Dictionary)[
				"maximum_outer_step_impulse_nms"
			]
		)
		var host_cap_projection := native_effective_impulse_limit_projection_v1(
			actuator_id,
			published_cap,
		)
		if not bool(host_cap_projection.get("ok", false)):
			viewport.queue_free()
			return _failure(
				"QSDK_R24D69_WORLD_NATIVE_EFFECTIVE_LIMIT_PROJECTION_INVALID:%s"
				% actuator_id,
				{
					"projection": host_cap_projection,
					"model_construction_attempt_count": 1,
					"native_scene_node_construction_attempted": true,
					"world_attempt_count": 1,
				},
			)
		var parent_id := String(joint_spec["parent_body_id"])
		var child_id := String(joint_spec["child_body_id"])
		var parent: RigidBody3D = body_nodes[parent_id]
		var pivot_world := parent.position + parent.basis * _vec3(joint_spec["anchor_parent_m"])
		var joint := HingeJoint3D.new()
		joint.name = "r24d57_%s" % joint_id
		joint.set_meta("lab_joint_id", joint_id)
		joint.set_meta("sporespore_actuator_id", actuator_id)
		joint.position = pivot_world
		joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
		joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		joint.set_param(
			HingeJoint3D.PARAM_LIMIT_LOWER,
			float(host_limit_projection["projected_host_lower_rad"]),
		)
		joint.set_param(
			HingeJoint3D.PARAM_LIMIT_UPPER,
			float(host_limit_projection["projected_host_upper_rad"]),
		)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
			float(host_cap_projection["configured_host_maximum_impulse_nms"]),
		)
		var host_cap_readback := float(
			joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
		)
		if (
			host_cap_readback
			!= float(host_cap_projection["configured_host_maximum_impulse_nms"])
			or host_cap_readback > published_cap
			or not bool(
				host_cap_projection.get(
					"native_effective_limit_not_above_published",
					false,
				)
			)
		):
			viewport.queue_free()
			return _failure(
				"QSDK_R24D69_WORLD_NATIVE_EFFECTIVE_LIMIT_READBACK_INVALID:%s"
				% actuator_id,
				{
					"projection": host_cap_projection,
					"host_cap_readback_nms": host_cap_readback,
					"model_construction_attempt_count": 1,
					"native_scene_node_construction_attempted": true,
					"world_attempt_count": 1,
				},
			)
		host_cap_projection = host_cap_projection.duplicate(true)
		host_cap_projection["host_cap_readback_nms"] = host_cap_readback
		host_cap_projection_by_actuator_id[actuator_id] = host_cap_projection
		var host_limit_readback := validate_godot_initial_relative_joint_limit_readback_v1(
			host_limit_projection,
			float(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER)),
			float(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER)),
		)
		if not bool(host_limit_readback.get("ok", false)):
			viewport.queue_free()
			return _failure(
				"QSDK_R24D83_WORLD_JOINT_LIMIT_READBACK_INVALID:%s" % joint_id,
				{
					"projection": host_limit_projection,
					"readback": host_limit_readback,
					"model_construction_attempt_count": 1,
					"native_scene_node_construction_attempted": true,
					"world_attempt_count": 1,
				},
			)
		host_limit_projection = host_limit_projection.duplicate(true)
		host_limit_projection["property_readback"] = host_limit_readback
		host_limit_projection_by_joint_id[joint_id] = host_limit_projection
		world.add_child(joint)
		joint.node_a = joint.get_path_to(parent)
		joint.node_b = joint.get_path_to(body_nodes[child_id])
		joint_nodes[joint_id] = joint
		joint_by_actuator_id[actuator_id] = joint
		ordered_joint_nodes.append(joint)

	await tree.process_frame
	var joint_states: Dictionary = {}
	for joint_id_value in ORDERED_JOINT_IDS:
		var joint_id := String(joint_id_value)
		var joint_spec: Dictionary = blueprint["joint_by_id"][joint_id]
		var parent: RigidBody3D = body_nodes[String(joint_spec["parent_body_id"])]
		var child: RigidBody3D = body_nodes[String(joint_spec["child_body_id"])]
		joint_states[joint_id] = {
			"joint_id": joint_id,
			"parent": parent,
			"child": child,
			"joint": joint_nodes[joint_id],
			"anchor_parent_local": _vec3(joint_spec["anchor_parent_m"]),
			"anchor_child_local": _vec3(joint_spec["anchor_child_m"]),
			"axis_parent_local": Vector3.BACK,
		}
	var initializer_readback := _initializer_readback_v1(
		sdk, blueprint, body_nodes, joint_states
	)
	if not bool(initializer_readback.get("ok", false)):
		viewport.queue_free()
		return _failure(
			"QSDK_R24D57_WORLD_INITIALIZER_READBACK_INVALID",
			{
				"model_construction_attempt_count": 1,
				"native_scene_node_construction_attempted": true,
				"world_attempt_count": 1,
				"readback": initializer_readback,
			},
		)
	for body_value in ordered_body_nodes:
		var body: RigidBody3D = body_value
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = false
		body.sleeping = false
	var model := {
		"schema_version": "sporespore_qsdk_r24d57_godot_recovery_native_world_v1",
		"ok": true,
		"world_route_id": (
			R148_COMPLETE_ENERGY_WORLD_ROUTE_ID
			if discrete_staging_complete_energy_profile
			else R144_COMPLETE_ENERGY_WORLD_ROUTE_ID
			if solver_coupled_complete_energy_profile
			else WORLD_ROUTE_ID
		),
		"viewport": viewport,
		"cleanup_node": viewport,
		"world": world,
		"floor": floor,
		"blueprint": blueprint,
		"body_nodes": body_nodes,
		"ordered_body_nodes": ordered_body_nodes,
		"joint_nodes": joint_nodes,
		"joint_states": joint_states,
		"joint_by_actuator_id": joint_by_actuator_id,
		"host_cap_projection_by_actuator_id": host_cap_projection_by_actuator_id,
		"host_limit_projection_by_joint_id": host_limit_projection_by_joint_id,
		"collision_filter_readback": collision_filter_readback,
		"ordered_joint_nodes": ordered_joint_nodes,
		"initializer_readback": initializer_readback,
		"task_origin_world_m": (body_nodes["torso"] as RigidBody3D).position,
		"initial_mechanical_energy_j": null,
		"cumulative_applied_actuator_work_j": 0.0,
		"host_step_count": 0,
		"last_native_space_step_sequence": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"model_construction_attempt_count": 1,
		"native_scene_node_construction_attempted": true,
		"model_construction_count": 1,
		"world_attempt_count": 1,
		"world_build_count": 1,
		"solver_step_count": 0,
		"physics_server_active": false,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if complete_energy_profile:
		model["complete_energy_profile_selected"] = true
		model["continuous_collision_detection_permitted"] = false
		model["cumulative_signed_constraint_exchange_j"] = 0.0
		model["cumulative_passive_dissipation_j"] = 0.0
		if solver_coupled_complete_energy_profile:
			model["solver_coupled_complete_energy_profile_selected"] = true
			model["energy_route_id"] = String(context.get("energy_route_id", ""))
			model["energy_mapping_profile_id"] = String(
				context.get("energy_mapping_profile_id", "")
			)
			if discrete_staging_complete_energy_profile:
				model["discrete_staging_complete_energy_profile_selected"] = true
				if rotation_aware_energy_ledger_profile:
					model["rotation_aware_energy_ledger_profile_selected"] = true
					model["recovery_energy_ledger_profile_id"] = (
						R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
					)
					if contiguous_boundary_transport_profile:
						model["contiguous_boundary_transport_profile_selected"] = true
						model["contiguous_boundary_transport_design_id"] = (
							ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
						)
						model["contiguous_boundary_transport_profile_id"] = (
							ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
						)
	return model


## Pure bootstrap-arm projection shared by the zero-world contract and the
## physical initializer. An actuation-free bootstrap is not automatically the
## matched-zero control: the candidate arm keeps candidate identity even when
## its first command contains no active motor intent.
static func native_bootstrap_arm_identity_v1(arm_kind: String) -> Dictionary:
	if arm_kind != "candidate_command" and arm_kind != "matched_zero_command":
		return _failure("QSDK_R24D62_BOOTSTRAP_ARM_KIND_INVALID")
	var matched_zero := arm_kind == "matched_zero_command"
	return {
		"schema_version": "sporespore_qsdk_r24d62_godot_bootstrap_arm_identity_v1",
		"ok": true,
		"arm_kind": arm_kind,
		"zero_command": matched_zero,
		"no_actuation_requested": true,
		"command_schema_version": (
			"sporespore_qsdk_r24d62_godot_initializer_matched_zero_v1"
			if matched_zero
			else "sporespore_qsdk_r24d62_godot_initializer_candidate_bootstrap_v1"
		),
		"command_id": (
			"r24d62_godot_initializer_matched_zero_step_1"
			if matched_zero
			else "r24d62_godot_initializer_candidate_bootstrap_step_1"
		),
		"controller_owner": "none" if matched_zero else "recovery",
		"recovery_controller_id": null if matched_zero else RECOVERY_CONTROLLER_ID,
		"stance_controller_id": null,
		"handoff_event_count": 0,
		"fallback_controller_active": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R113 preserves the historical bootstrap command while binding the initial
## candidate observation to the distinct mirrored-knee controller identity.
static func native_bootstrap_arm_identity_v2(
	arm_kind: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V2_ID:
		return _failure("QSDK_R24D113_BOOTSTRAP_CONTROLLER_ID_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	if arm_kind == "candidate_command":
		identity["recovery_controller_id"] = recovery_controller_id
	return identity


## R117 retains the exact bootstrap command and changes only the bound
## candidate controller identity from V2 to the speed-ceiling V3 successor.
static func native_bootstrap_arm_identity_v3(
	arm_kind: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V3_ID:
		return _failure("QSDK_R24D117_BOOTSTRAP_CONTROLLER_ID_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	if arm_kind == "candidate_command":
		identity["recovery_controller_id"] = recovery_controller_id
	return identity


## R120 retains the exact bootstrap command and changes only the bound
## candidate controller identity from V3 to the raise-body-speed V4 successor.
static func native_bootstrap_arm_identity_v4(
	arm_kind: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V4_ID:
		return _failure("QSDK_R24D120_BOOTSTRAP_CONTROLLER_ID_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	if arm_kind == "candidate_command":
		identity["recovery_controller_id"] = recovery_controller_id
	return identity


## R123 retains the exact bootstrap command and changes only the bound
## candidate controller identity from V4 to the 22 rad/s V5 successor.
static func native_bootstrap_arm_identity_v5(
	arm_kind: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V5_ID:
		return _failure("QSDK_R24D123_BOOTSTRAP_CONTROLLER_ID_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	if arm_kind == "candidate_command":
		identity["recovery_controller_id"] = recovery_controller_id
	return identity


## R127 retains the exact V5 bootstrap command while binding the candidate to
## the V6 identity whose Godot route selects the solver-coupled motor.
static func native_bootstrap_arm_identity_v6(
	arm_kind: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D127_BOOTSTRAP_CONTROLLER_ID_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	if arm_kind == "candidate_command":
		identity["recovery_controller_id"] = recovery_controller_id
	return identity


## Disable every motor and bind the first completed native sample to the arm
## supplied by the pure projection above. No absent command is synthesized.
static func _initial_bootstrap_application_v2(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
) -> Dictionary:
	return _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, "establish_distal_support"
	)


static func _initial_bootstrap_application_for_phase_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	if not bool(model.get("ok", false)) or int(model.get("host_step_count", -1)) != 0:
		return _failure("QSDK_R24D57_WORLD_INITIAL_APPLICATION_STATE_INVALID")
	if phase not in ["confirm_prone", "establish_distal_support"]:
		return _failure("QSDK_R24D65_WORLD_INITIAL_PHASE_INVALID")
	var identity := native_bootstrap_arm_identity_v1(arm_kind)
	if not bool(identity.get("ok", false)):
		return identity
	var ordered_intents: Array = []
	for index in range(8):
		var joint: HingeJoint3D = model["joint_nodes"][ORDERED_JOINT_IDS[index]]
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		if (
			joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
			or float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)) != 0.0
		):
			return _failure("QSDK_R24D57_WORLD_INITIAL_MOTOR_DISABLE_FAILED:%d" % index)
		ordered_intents.append(
			{
				"actuator_id": String(ORDERED_ACTUATOR_IDS[index]),
				"joint_id": String(ORDERED_JOINT_IDS[index]),
				"motor_enabled": false,
				"host_target_velocity_rad_s": 0.0,
			}
		)
	var command_record := {
		"schema_version": String(identity["command_schema_version"]),
		"command_id": String(identity["command_id"]),
		"arm_kind": String(identity["arm_kind"]),
		"semantic_step": 1,
		"no_actuation_requested": true,
		"ordered_intents": ordered_intents,
	}
	var command_sha256 := _sha256(sdk, command_record)
	if command_sha256.is_empty():
		return _failure("QSDK_R24D57_WORLD_INITIAL_COMMAND_DIGEST_FAILED")
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_application_intent_v1",
		"ok": true,
		"semantic_step": 1,
		"source_control_semantic_step": 0,
		"phase": phase,
		"command_id": String(command_record["command_id"]),
		"command_sha256": command_sha256,
		"arm_kind": String(identity["arm_kind"]),
		"zero_command": bool(identity["zero_command"]),
		"no_actuation_requested": true,
		"motor_enabled_count": 0,
		"ordered_intents": ordered_intents,
		"controller_owner": String(identity["controller_owner"]),
		"recovery_controller_id": identity["recovery_controller_id"],
		"stance_controller_id": identity["stance_controller_id"],
		"handoff_event_count": int(identity["handoff_event_count"]),
		"fallback_controller_active": bool(identity["fallback_controller_active"]),
		"adapter_side_discrete_staging_event_count": 0,
	}


static func initial_candidate_application_v1(
	sdk: Object,
	model: Dictionary,
) -> Dictionary:
	return _initial_bootstrap_application_v2(sdk, model, "candidate_command")


static func initial_zero_application_v1(sdk: Object, model: Dictionary) -> Dictionary:
	return _initial_bootstrap_application_v2(sdk, model, "matched_zero_command")


## R65 behavior work starts from the supervisor's actual initial phase rather
## than the historical route-ghost phase. The older wrappers above remain
## exact so their retained integration evidence keeps its original semantics.
static func initial_behavior_application_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	return _initial_bootstrap_application_for_phase_v1(sdk, model, arm_kind, phase)


static func initial_behavior_application_v2(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var identity := native_bootstrap_arm_identity_v2(arm_kind, recovery_controller_id)
	if not bool(identity.get("ok", false)):
		return identity
	var application := _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, phase
	)
	if not bool(application.get("ok", false)):
		return application
	application["recovery_controller_id"] = identity["recovery_controller_id"]
	return application


static func initial_behavior_application_v3(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var identity := native_bootstrap_arm_identity_v3(arm_kind, recovery_controller_id)
	if not bool(identity.get("ok", false)):
		return identity
	var application := _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, phase
	)
	if not bool(application.get("ok", false)):
		return application
	application["recovery_controller_id"] = identity["recovery_controller_id"]
	return application


static func initial_behavior_application_v4(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var identity := native_bootstrap_arm_identity_v4(arm_kind, recovery_controller_id)
	if not bool(identity.get("ok", false)):
		return identity
	var application := _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, phase
	)
	if not bool(application.get("ok", false)):
		return application
	application["recovery_controller_id"] = identity["recovery_controller_id"]
	return application


static func initial_behavior_application_v5(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var identity := native_bootstrap_arm_identity_v5(arm_kind, recovery_controller_id)
	if not bool(identity.get("ok", false)):
		return identity
	var application := _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, phase
	)
	if not bool(application.get("ok", false)):
		return application
	application["recovery_controller_id"] = identity["recovery_controller_id"]
	return application


static func initial_behavior_application_v6(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var identity := native_bootstrap_arm_identity_v6(arm_kind, recovery_controller_id)
	if not bool(identity.get("ok", false)):
		return identity
	var application := _initial_bootstrap_application_for_phase_v1(
		sdk, model, arm_kind, phase
	)
	if not bool(application.get("ok", false)):
		return application
	application["recovery_controller_id"] = identity["recovery_controller_id"]
	return application


## Project telemetry values into JSON-safe evidence without losing finite
## binary64 values or the class/sign of a non-finite value. The instrumented
## binding publishes a flat dictionary; unexpected variants remain explicit.
static func _telemetry_evidence_value_v1(value: Variant) -> Variant:
	if value is float:
		var number := float(value)
		if is_finite(number):
			return number
		return {
			"schema_version": "sporespore_qsdk_r24d63_nonfinite_telemetry_value_v1",
			"classification": (
				"nan"
				if number != number
				else ("negative_infinity" if number < 0.0 else "positive_infinity")
			),
			"variant_type": "float",
		}
	if value == null or value is bool or value is int or value is String:
		return value
	return {
		"schema_version": "sporespore_qsdk_r24d63_non_json_telemetry_value_v1",
		"variant_type": type_string(typeof(value)),
		"display_value": str(value),
	}


static func _telemetry_evidence_snapshot_v1(telemetry: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for key_value in telemetry:
		var key := String(key_value)
		snapshot[key] = _telemetry_evidence_value_v1(telemetry[key_value])
	return snapshot


## Reproduce one IEEE-754 binary32 subtraction from the exact binary64
## representations Godot exposes for two native float members.
static func _native_float32_subtract_v1(left: float, right: float) -> float:
	var operands := PackedFloat32Array([left, right])
	var result := PackedFloat32Array([float(operands[0]) - float(operands[1])])
	return float(result[0])


## Preserve the two native float32 work measurements and their raw native net,
## then derive the public net from the exact binary64 Variant components the
## consumer checks. Missing/non-finite inputs pass through to the unchanged R63
## validator; a finite raw net that is not the exact native float32 subtraction
## is refused rather than hidden by projection.
static func native_motor_work_projection_v1(
	telemetry_value: Variant,
	actuator_id: String,
) -> Dictionary:
	var passthrough := {
		"schema_version": "sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_v1",
		"ok": true,
		"actuator_id": actuator_id,
		"projection_applied": false,
		"source_float32_identity_checked": false,
		"telemetry": telemetry_value,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not (telemetry_value is Dictionary):
		return passthrough
	var telemetry: Dictionary = telemetry_value
	var positive_work := float(telemetry.get("positive_motor_work_j", NAN))
	var absorbed_work := float(telemetry.get("absorbed_motor_work_j", NAN))
	var native_net_work := float(telemetry.get("net_motor_work_j", NAN))
	if (
		not is_finite(positive_work)
		or not is_finite(absorbed_work)
		or not is_finite(native_net_work)
	):
		return passthrough
	var expected_native_net := _native_float32_subtract_v1(
		positive_work,
		absorbed_work,
	)
	var projected_net := positive_work - absorbed_work
	if native_net_work != expected_native_net:
		return _failure(
			"QSDK_R24D64_WORLD_NATIVE_NET_WORK_FLOAT32_IDENTITY_INVALID:%s" % actuator_id,
			{
				"schema_version": "sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_failure_v1",
				"actuator_id": actuator_id,
				"positive_motor_work_j": positive_work,
				"absorbed_motor_work_j": absorbed_work,
				"native_net_motor_work_j": native_net_work,
				"expected_native_float32_net_motor_work_j": expected_native_net,
				"projected_binary64_net_motor_work_j": projected_net,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
		)
	var projected_telemetry := telemetry.duplicate(true)
	projected_telemetry["native_net_motor_work_j"] = native_net_work
	projected_telemetry["net_motor_work_j"] = projected_net
	projected_telemetry["net_motor_work_projection_delta_j"] = (
		native_net_work - projected_net
	)
	projected_telemetry["net_motor_work_projection_schema"] = (
		"sporespore_qsdk_r24d64_native_float32_to_binary64_net_work_projection_v1"
	)
	return {
		"schema_version": "sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_v1",
		"ok": true,
		"actuator_id": actuator_id,
		"projection_applied": true,
		"source_float32_identity_checked": true,
		"positive_motor_work_j": positive_work,
		"absorbed_motor_work_j": absorbed_work,
		"native_net_motor_work_j": native_net_work,
		"expected_native_float32_net_motor_work_j": expected_native_net,
		"projected_binary64_net_motor_work_j": projected_net,
		"net_motor_work_projection_delta_j": native_net_work - projected_net,
		"telemetry": projected_telemetry,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Preserve the legacy failure code consumed by the shared route while adding
## the exact ordered failed predicate, native values, and validation inputs.
## This is evidence projection only: it changes no predicate or tolerance.
static func _native_motor_telemetry_failure_v1(
	legacy_failure_code: String,
	telemetry_value: Variant,
	actuator_id: String,
	maximum_outer_step_impulse_nms: float,
	zero_command: bool,
	prior_actuator_space_step_sequence: int,
	prior_solver_step_s: float,
	ordered_invariant_ids: Array[String],
	invariant_results: Dictionary,
	parsed_values: Dictionary = {},
) -> Dictionary:
	var failed_invariant_ids: Array[String] = []
	for invariant_id in ordered_invariant_ids:
		if not bool(invariant_results.get(invariant_id, false)):
			failed_invariant_ids.append(invariant_id)
	var telemetry_evidence: Variant = _telemetry_evidence_value_v1(telemetry_value)
	if telemetry_value is Dictionary:
		telemetry_evidence = _telemetry_evidence_snapshot_v1(telemetry_value)
	var parsed_evidence: Dictionary = {}
	for key_value in parsed_values:
		var key := String(key_value)
		parsed_evidence[key] = _telemetry_evidence_value_v1(parsed_values[key_value])
	return _failure(
		legacy_failure_code,
		{
			"schema_version": "sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1",
			"actuator_id": actuator_id,
			"legacy_failure_code": legacy_failure_code,
			"first_failed_invariant_id": (
				failed_invariant_ids[0] if not failed_invariant_ids.is_empty() else ""
			),
			"failed_invariant_ids": failed_invariant_ids,
			"failed_invariant_count": failed_invariant_ids.size(),
			"ordered_invariant_ids": ordered_invariant_ids.duplicate(),
			"invariant_results": invariant_results.duplicate(true),
			"validation_inputs": {
				"maximum_outer_step_impulse_nms": _telemetry_evidence_value_v1(
					maximum_outer_step_impulse_nms
				),
				"telemetry_impulse_tolerance_nms": TELEMETRY_IMPULSE_TOLERANCE_NMS,
				"net_work_identity_tolerance_j": TELEMETRY_NET_WORK_IDENTITY_TOLERANCE_J,
				"zero_command": zero_command,
				"prior_actuator_space_step_sequence": prior_actuator_space_step_sequence,
				"prior_solver_step_s": _telemetry_evidence_value_v1(prior_solver_step_s),
			},
			"telemetry_variant_type": type_string(typeof(telemetry_value)),
			"telemetry": telemetry_evidence,
			"parsed_values": parsed_evidence,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	)


## Validate one binding-shaped native motor-telemetry dictionary without a
## Node, RID, model, world, or solver step. The physical sampler calls this
## same function, so zero-world controls exercise the actual in-run invariant.
static func native_motor_telemetry_contract_v1(
	telemetry_value: Variant,
	actuator_id: String,
	maximum_outer_step_impulse_nms: float,
	zero_command: bool,
	prior_actuator_space_step_sequence: int,
	prior_solver_step_s: float,
) -> Dictionary:
	if not (telemetry_value is Dictionary):
		return _native_motor_telemetry_failure_v1(
			"QSDK_R24D57_WORLD_TELEMETRY_MISSING:%s" % actuator_id,
			telemetry_value,
			actuator_id,
			maximum_outer_step_impulse_nms,
			zero_command,
			prior_actuator_space_step_sequence,
			prior_solver_step_s,
			["telemetry_dictionary"],
			{"telemetry_dictionary": false},
		)
	var telemetry: Dictionary = telemetry_value
	var read_sequence := int(telemetry.get("read_space_step_sequence", -1))
	var capture_sequence := int(telemetry.get("capture_space_step_sequence", -1))
	var current_step_s := float(telemetry.get("solver_step_s", NAN))
	var signed_impulse := float(telemetry.get("signed_motor_impulse_nms", NAN))
	var positive_work := float(telemetry.get("positive_motor_work_j", NAN))
	var absorbed_work := float(telemetry.get("absorbed_motor_work_j", NAN))
	var net_work := float(telemetry.get("net_motor_work_j", NAN))
	var primary_invariant_ids: Array[String] = [
		"telemetry_schema_exact",
		"captured_during_active_step",
		"snapshot_is_current_space_step",
		"read_space_step_sequence_positive",
		"capture_matches_read_space_step_sequence",
		"actuator_population_space_step_sequence_consistent",
		"solver_step_finite",
		"solver_step_positive",
		"actuator_population_solver_step_consistent",
		"signed_motor_impulse_finite",
		"positive_motor_work_finite",
		"absorbed_motor_work_finite",
		"net_motor_work_finite",
		"positive_motor_work_nonnegative",
		"absorbed_motor_work_nonnegative",
		"net_motor_work_identity",
		"signed_motor_impulse_within_outer_step_cap",
	]
	var zero_command_invariant_ids: Array[String] = [
		"zero_command_signed_motor_impulse_zero",
		"zero_command_positive_motor_work_zero",
		"zero_command_absorbed_motor_work_zero",
	]
	var invariant_results := {
		"telemetry_schema_exact": (
			String(telemetry.get("schema", ""))
			== "sporespore.godot_jolt_hinge_motor_telemetry.v2"
		),
		"captured_during_active_step": bool(
			telemetry.get("captured_during_active_step", false)
		),
		"snapshot_is_current_space_step": bool(
			telemetry.get("snapshot_is_current_space_step", false)
		),
		"read_space_step_sequence_positive": read_sequence >= 1,
		"capture_matches_read_space_step_sequence": capture_sequence == read_sequence,
		"actuator_population_space_step_sequence_consistent": (
			prior_actuator_space_step_sequence < 0
			or read_sequence == prior_actuator_space_step_sequence
		),
		"solver_step_finite": is_finite(current_step_s),
		"solver_step_positive": current_step_s > 0.0,
		"actuator_population_solver_step_consistent": (
			not is_finite(prior_solver_step_s) or current_step_s == prior_solver_step_s
		),
		"signed_motor_impulse_finite": is_finite(signed_impulse),
		"positive_motor_work_finite": is_finite(positive_work),
		"absorbed_motor_work_finite": is_finite(absorbed_work),
		"net_motor_work_finite": is_finite(net_work),
		"positive_motor_work_nonnegative": positive_work >= 0.0,
		"absorbed_motor_work_nonnegative": absorbed_work >= 0.0,
		"net_motor_work_identity": (
			absf(net_work - (positive_work - absorbed_work))
			<= TELEMETRY_NET_WORK_IDENTITY_TOLERANCE_J
		),
		"signed_motor_impulse_within_outer_step_cap": (
			absf(signed_impulse)
			<= maximum_outer_step_impulse_nms + TELEMETRY_IMPULSE_TOLERANCE_NMS
		),
		"zero_command_signed_motor_impulse_zero": (
			not zero_command or signed_impulse == 0.0
		),
		"zero_command_positive_motor_work_zero": (
			not zero_command or positive_work == 0.0
		),
		"zero_command_absorbed_motor_work_zero": (
			not zero_command or absorbed_work == 0.0
		),
	}
	var all_invariant_ids := primary_invariant_ids.duplicate()
	all_invariant_ids.append_array(zero_command_invariant_ids)
	var parsed_values := {
		"read_space_step_sequence": read_sequence,
		"capture_space_step_sequence": capture_sequence,
		"solver_step_s": current_step_s,
		"signed_motor_impulse_nms": signed_impulse,
		"positive_motor_work_j": positive_work,
		"absorbed_motor_work_j": absorbed_work,
		"net_motor_work_j": net_work,
	}
	for invariant_id in primary_invariant_ids:
		if not bool(invariant_results[invariant_id]):
			return _native_motor_telemetry_failure_v1(
				"QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s" % actuator_id,
				telemetry_value,
				actuator_id,
				maximum_outer_step_impulse_nms,
				zero_command,
				prior_actuator_space_step_sequence,
				prior_solver_step_s,
				all_invariant_ids,
				invariant_results,
				parsed_values,
			)
	for invariant_id in zero_command_invariant_ids:
		if not bool(invariant_results[invariant_id]):
			return _native_motor_telemetry_failure_v1(
				"QSDK_R24D57_WORLD_ZERO_COMMAND_TELEMETRY_NONZERO:%s" % actuator_id,
				telemetry_value,
				actuator_id,
				maximum_outer_step_impulse_nms,
				zero_command,
				prior_actuator_space_step_sequence,
				prior_solver_step_s,
				all_invariant_ids,
				invariant_results,
				parsed_values,
			)
	return {
		"schema_version": "sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1",
		"ok": true,
		"actuator_id": actuator_id,
		"read_space_step_sequence": read_sequence,
		"capture_space_step_sequence": capture_sequence,
		"solver_step_s": current_step_s,
		"signed_motor_impulse_nms": signed_impulse,
		"positive_motor_work_j": positive_work,
		"absorbed_motor_work_j": absorbed_work,
		"net_motor_work_j": net_work,
		"telemetry": telemetry.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R68 preserves the historical V1 contract as an inner compatibility check,
## but makes the published portable budget predicate strict and identical to
## the core: abs(measured impulse) <= published cap, with zero tolerance.
static func native_motor_telemetry_contract_v2(
	telemetry_value: Variant,
	actuator_id: String,
	maximum_outer_step_impulse_nms: float,
	zero_command: bool,
	prior_actuator_space_step_sequence: int,
	prior_solver_step_s: float,
) -> Dictionary:
	var budget_identity := strict_host_impulse_cap_projection_v1(
		actuator_id,
		maximum_outer_step_impulse_nms,
	)
	if not bool(budget_identity.get("ok", false)):
		return _failure(
			"QSDK_R24D68_WORLD_STRICT_ACTUATOR_BUDGET_IDENTITY_INVALID:%s" % actuator_id,
			{
				"schema_version": STRICT_MOTOR_TELEMETRY_CONTRACT_SCHEMA,
				"actuator_id": actuator_id,
				"budget_identity": budget_identity,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physics_state_modified": false,
			},
		)
	var legacy_contract := native_motor_telemetry_contract_v1(
		telemetry_value,
		actuator_id,
		maximum_outer_step_impulse_nms,
		zero_command,
		prior_actuator_space_step_sequence,
		prior_solver_step_s,
	)
	var signed_impulse := NAN
	if telemetry_value is Dictionary:
		signed_impulse = float(
			(telemetry_value as Dictionary).get("signed_motor_impulse_nms", NAN)
		)
	var signed_impulse_finite := is_finite(signed_impulse)
	var published_cap_finite := is_finite(maximum_outer_step_impulse_nms)
	var absolute_impulse := absf(signed_impulse) if signed_impulse_finite else NAN
	var strict_budget_accepted := (
		signed_impulse_finite
		and published_cap_finite
		and maximum_outer_step_impulse_nms > 0.0
		and absolute_impulse <= maximum_outer_step_impulse_nms
	)
	var decision_agreement := strict_actuator_budget_decision_agreement_v1(
		strict_budget_accepted,
		strict_budget_accepted,
	)
	if not bool(decision_agreement.get("ok", false)):
		return decision_agreement
	var legacy_budget_accepted := (
		signed_impulse_finite
		and published_cap_finite
		and maximum_outer_step_impulse_nms > 0.0
		and absolute_impulse
		<= maximum_outer_step_impulse_nms + TELEMETRY_IMPULSE_TOLERANCE_NMS
	)
	var signed_budget_boundary := NAN
	var signed_boundary_delta := NAN
	var absolute_budget_delta := NAN
	if signed_impulse_finite and published_cap_finite:
		signed_budget_boundary = (
			-maximum_outer_step_impulse_nms
			if signed_impulse < 0.0
			else maximum_outer_step_impulse_nms
		)
		signed_boundary_delta = signed_impulse - signed_budget_boundary
		absolute_budget_delta = absolute_impulse - maximum_outer_step_impulse_nms
	var diagnostic := {
		"schema_version": STRICT_ACTUATOR_BUDGET_DIAGNOSTIC_SCHEMA,
		"actuator_id": actuator_id,
		"predicate_id": "absolute_measured_impulse_not_above_published_cap_v1",
		"predicate": "abs(signed_motor_impulse_nms) <= published_maximum_outer_step_impulse_nms",
		"effective_tolerance_nms": 0.0,
		"signed_motor_impulse_nms": _telemetry_evidence_value_v1(signed_impulse),
		"absolute_motor_impulse_nms": _telemetry_evidence_value_v1(absolute_impulse),
		"published_maximum_outer_step_impulse_nms": _telemetry_evidence_value_v1(
			maximum_outer_step_impulse_nms
		),
		"signed_budget_boundary_nms": _telemetry_evidence_value_v1(
			signed_budget_boundary
		),
		"signed_boundary_delta_nms": _telemetry_evidence_value_v1(
			signed_boundary_delta
		),
		"absolute_budget_delta_nms": _telemetry_evidence_value_v1(
			absolute_budget_delta
		),
		"legacy_v1_budget_tolerance_nms": TELEMETRY_IMPULSE_TOLERANCE_NMS,
		"legacy_v1_budget_predicate_decision": legacy_budget_accepted,
		"legacy_v1_contract_decision": bool(legacy_contract.get("ok", false)),
		"native_v2_strict_budget_decision": strict_budget_accepted,
		"projected_core_strict_budget_decision": strict_budget_accepted,
		"native_core_budget_decisions_agree": true,
		"decision_agreement_receipt": decision_agreement,
		"raw_measurement_modified": false,
		"published_cap_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not strict_budget_accepted:
		return _failure(
			"QSDK_R24D68_WORLD_STRICT_ACTUATOR_BUDGET_EXCEEDED:%s" % actuator_id,
			{
				"schema_version": STRICT_MOTOR_TELEMETRY_CONTRACT_SCHEMA,
				"actuator_id": actuator_id,
				"strict_actuator_budget_diagnostic": diagnostic,
				"legacy_v1_contract": legacy_contract,
				"telemetry": (
					_telemetry_evidence_snapshot_v1(telemetry_value)
					if telemetry_value is Dictionary
					else _telemetry_evidence_value_v1(telemetry_value)
				),
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
		)
	if not bool(legacy_contract.get("ok", false)):
		var legacy_failure := legacy_contract.duplicate(true)
		legacy_failure["telemetry_contract_schema_version"] = (
			STRICT_MOTOR_TELEMETRY_CONTRACT_SCHEMA
		)
		legacy_failure["strict_actuator_budget_diagnostic"] = diagnostic
		return legacy_failure
	var accepted := legacy_contract.duplicate(true)
	accepted["schema_version"] = STRICT_MOTOR_TELEMETRY_CONTRACT_SCHEMA
	accepted["legacy_contract_schema_version"] = String(
		legacy_contract.get("schema_version", "")
	)
	accepted["strict_actuator_budget_diagnostic"] = diagnostic
	return accepted


## Pure R136 consumer for the finalized native solver-exchange snapshot. The
## production sampler and zero-world mutations call this same function; a
## missing, stale, unsupported, nonfinite, or incomplete snapshot is never
## projected as zero constraint work.
static func native_solver_energy_exchange_contract_v1(
	telemetry_value: Variant,
	expected_space_step_sequence: int,
	uniform_gravity_world_m_s2: Vector3,
) -> Dictionary:
	if not (telemetry_value is Dictionary):
		return _failure("QSDK_R24D136_SOLVER_ENERGY_TELEMETRY_NOT_DICTIONARY")
	var telemetry: Dictionary = telemetry_value
	var required_numeric := [
		"joint_velocity_constraint_exchange_j",
		"contact_velocity_constraint_exchange_j",
		"position_constraint_kinetic_exchange_j",
	]
	var required_integer := [
		"telemetry_sequence",
		"capture_space_step_sequence",
		"read_space_step_sequence",
		"collision_step_count",
		"constrained_island_count",
		"velocity_measured_island_count",
		"position_measured_island_count",
		"joint_velocity_phase_count",
		"contact_velocity_phase_count",
		"position_constraint_phase_count",
		"dynamic_body_observation_count",
		"invalid_body_measurement_count",
		"large_island_velocity_batch_count",
		"large_island_position_batch_count",
		"ccd_active_body_count",
		"active_soft_body_count",
		"update_error_bits",
	]
	var required_boolean := [
		"captured_during_active_step",
		"snapshot_is_current_space_step",
		"complete",
		"source_measurement",
		"mechanical_energy_residual_used_as_work_source",
	]
	for key in required_numeric:
		if not telemetry.has(key) or typeof(telemetry[key]) not in [TYPE_FLOAT, TYPE_INT]:
			return _failure("QSDK_R24D136_SOLVER_ENERGY_NUMERIC_FIELD_INVALID:%s" % key)
	for key in required_integer:
		if not telemetry.has(key) or typeof(telemetry[key]) != TYPE_INT:
			return _failure("QSDK_R24D136_SOLVER_ENERGY_INTEGER_FIELD_INVALID:%s" % key)
	for key in required_boolean:
		if not telemetry.has(key) or typeof(telemetry[key]) != TYPE_BOOL:
			return _failure("QSDK_R24D136_SOLVER_ENERGY_BOOLEAN_FIELD_INVALID:%s" % key)
	var displacement_value: Variant = telemetry.get(
		"position_constraint_mass_weighted_displacement_kg_m"
	)
	if not (displacement_value is Vector3):
		return _failure("QSDK_R24D136_SOLVER_ENERGY_DISPLACEMENT_INVALID")
	var displacement: Vector3 = displacement_value
	var joint_exchange := float(telemetry["joint_velocity_constraint_exchange_j"])
	var contact_exchange := float(telemetry["contact_velocity_constraint_exchange_j"])
	var position_kinetic_exchange := float(
		telemetry["position_constraint_kinetic_exchange_j"]
	)
	var position_potential_exchange := -uniform_gravity_world_m_s2.dot(displacement)
	var step_constraint_exchange := (
		joint_exchange
		+ contact_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var checks := {
		"schema_exact": (
			String(telemetry.get("schema", ""))
			== "sporespore.godot_jolt_solver_energy_exchange_telemetry.v1"
		),
		"profile_exact": (
			String(telemetry.get("profile_id", ""))
			== "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v1"
		),
		"expected_sequence_positive": expected_space_step_sequence > 0,
		"telemetry_sequence_positive": int(telemetry["telemetry_sequence"]) > 0,
		"capture_sequence_exact": (
			int(telemetry["capture_space_step_sequence"])
			== expected_space_step_sequence
		),
		"read_sequence_exact": (
			int(telemetry["read_space_step_sequence"])
			== expected_space_step_sequence
		),
		"captured_during_active_step": bool(
			telemetry.get("captured_during_active_step", false)
		),
		"snapshot_current": bool(
			telemetry.get("snapshot_is_current_space_step", false)
		),
		"collision_step_exact": int(telemetry["collision_step_count"]) == 1,
		"constrained_island_present": int(telemetry["constrained_island_count"]) > 0,
		"velocity_coverage_complete": (
			int(telemetry["velocity_measured_island_count"])
			== int(telemetry["constrained_island_count"])
		),
		"position_coverage_complete": (
			int(telemetry["position_measured_island_count"])
			== int(telemetry["constrained_island_count"])
		),
		"joint_velocity_phase_present": int(telemetry["joint_velocity_phase_count"]) > 0,
		"contact_velocity_phase_nonnegative": (
			int(telemetry["contact_velocity_phase_count"]) >= 0
		),
		"position_phase_present": int(telemetry["position_constraint_phase_count"]) > 0,
		"dynamic_body_observation_present": (
			int(telemetry["dynamic_body_observation_count"]) > 0
		),
		"invalid_body_measurement_zero": int(telemetry["invalid_body_measurement_count"]) == 0,
		"large_island_velocity_zero": int(telemetry["large_island_velocity_batch_count"]) == 0,
		"large_island_position_zero": int(telemetry["large_island_position_batch_count"]) == 0,
		"ccd_active_body_zero": int(telemetry["ccd_active_body_count"]) == 0,
		"active_soft_body_zero": int(telemetry["active_soft_body_count"]) == 0,
		"update_error_zero": int(telemetry["update_error_bits"]) == 0,
		"gravity_finite": uniform_gravity_world_m_s2.is_finite(),
		"joint_exchange_finite": is_finite(joint_exchange),
		"contact_exchange_finite": is_finite(contact_exchange),
		"position_kinetic_exchange_finite": is_finite(position_kinetic_exchange),
		"position_displacement_finite": displacement.is_finite(),
		"position_potential_exchange_finite": is_finite(position_potential_exchange),
		"step_constraint_exchange_finite": is_finite(step_constraint_exchange),
		"native_complete": bool(telemetry.get("complete", false)),
		"source_measurement": bool(telemetry.get("source_measurement", false)),
		"residual_not_used": not bool(
			telemetry.get("mechanical_energy_residual_used_as_work_source", true)
		),
	}
	for invariant_id in checks:
		if not bool(checks[invariant_id]):
			return _failure(
				"QSDK_R24D136_SOLVER_ENERGY_TELEMETRY_INCOMPLETE:%s" % invariant_id,
				{"ordered_checks": checks, "telemetry": telemetry.duplicate(true)},
			)
	return {
		"schema_version": "sporespore_qsdk_r24d136_godot_solver_energy_exchange_contract_v1",
		"ok": true,
		"expected_space_step_sequence": expected_space_step_sequence,
		"telemetry_sequence": int(telemetry["telemetry_sequence"]),
		"capture_space_step_sequence": int(telemetry["capture_space_step_sequence"]),
		"read_space_step_sequence": int(telemetry["read_space_step_sequence"]),
		"joint_velocity_constraint_exchange_j": joint_exchange,
		"contact_velocity_constraint_exchange_j": contact_exchange,
		"position_constraint_kinetic_exchange_j": position_kinetic_exchange,
		"position_constraint_mass_weighted_displacement_kg_m": _vector_json(displacement),
		"uniform_gravity_world_m_s2": _vector_json(uniform_gravity_world_m_s2),
		"position_constraint_potential_exchange_j": position_potential_exchange,
		"step_signed_constraint_exchange_j": step_constraint_exchange,
		"ordered_checks": checks,
		"check_count": checks.size(),
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Versioned production selector. Historical contexts remain on the exact v1
## consumer. Only an explicit, internally consistent R162 authority may select
## the qualified v2 consumer; partial or crossed R162 fields fail closed rather
## than silently falling back to the legacy measurement.
static func native_solver_energy_exchange_for_recovery_route_v2(
	context: Dictionary,
	telemetry_value: Variant,
	expected_space_step_sequence: int,
	uniform_gravity_world_m_s2: Vector3,
) -> Dictionary:
	var selected := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	if selected:
		return RotationAwareEnergyLedgerScript.native_solver_energy_exchange_contract_v1(
			context,
			telemetry_value,
			expected_space_step_sequence,
			uniform_gravity_world_m_s2,
		)
	for key in [
		"recovery_energy_ledger_profile_id",
		"solver_energy_consumer_contract_schema_version",
		"solver_energy_telemetry_schema_version",
		"solver_energy_telemetry_profile_id",
		"r24d161_diagnosis_raw_sha256",
	]:
		if context.has(key):
			return _failure("QSDK_R24D162_RECOVERY_LEDGER_AUTHORITY_CROSSED:%s" % key)
	return native_solver_energy_exchange_contract_v1(
		telemetry_value,
		expected_space_step_sequence,
		uniform_gravity_world_m_s2,
	)


## Common R136 adapter-side disjointness contract. Production supplies exact
## node/property readbacks; zero-world controls supply the same shaped record.
static func complete_energy_partition_inputs_contract_v1(value: Dictionary) -> Dictionary:
	if (
		typeof(value.get("semantic_step")) != TYPE_INT
		or int(value["semantic_step"]) <= 0
		or typeof(value.get("no_actuation_requested")) != TYPE_BOOL
		or typeof(value.get("step_actuator_work_j")) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(value.get("external_intervention_event_count")) != TYPE_INT
		or typeof(value.get("step_signed_external_work_j")) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(value.get("adapter_side_discrete_staging_event_count")) != TYPE_INT
		or typeof(value.get("step_signed_discrete_staging_exchange_j"))
		not in [TYPE_FLOAT, TYPE_INT]
	):
		return _failure("QSDK_R24D136_ENERGY_PARTITION_SCALAR_IDENTITY_INVALID")
	var bodies_value: Variant = value.get("ordered_body_readbacks")
	var joints_value: Variant = value.get("ordered_joint_readbacks")
	if not (bodies_value is Array) or (bodies_value as Array).size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D136_ENERGY_BODY_READBACK_POPULATION_INVALID")
	if not (joints_value is Array) or (joints_value as Array).size() != ORDERED_JOINT_IDS.size():
		return _failure("QSDK_R24D136_ENERGY_JOINT_READBACK_POPULATION_INVALID")
	var bodies: Array = bodies_value
	var joints: Array = joints_value
	var uniform_gravity := Vector3(NAN, NAN, NAN)
	for index in range(bodies.size()):
		var body_value: Variant = bodies[index]
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D136_ENERGY_BODY_READBACK_INVALID:%d" % index)
		var body: Dictionary = body_value
		var gravity_value: Variant = body.get("total_gravity_world_m_s2")
		if not (gravity_value is Vector3):
			return _failure("QSDK_R24D136_ENERGY_BODY_GRAVITY_INVALID:%d" % index)
		var gravity: Vector3 = gravity_value
		if (
			String(body.get("body_id", "")) != ORDERED_BODY_IDS[index]
			or not gravity.is_finite()
			or (index > 0 and gravity != uniform_gravity)
			or int(body.get("linear_damp_mode", -1)) != int(RigidBody3D.DAMP_MODE_REPLACE)
			or int(body.get("angular_damp_mode", -1)) != int(RigidBody3D.DAMP_MODE_REPLACE)
			or typeof(body.get("linear_damp")) not in [TYPE_FLOAT, TYPE_INT]
			or typeof(body.get("angular_damp")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(body.get("linear_damp", NAN)))
			or not is_finite(float(body.get("angular_damp", NAN)))
			or float(body.get("linear_damp", NAN)) != 0.0
			or float(body.get("angular_damp", NAN)) != 0.0
			or bool(body.get("continuous_cd", true))
		):
			return _failure("QSDK_R24D136_ENERGY_BODY_PARTITION_INVALID:%d" % index)
		if index == 0:
			uniform_gravity = gravity
	for index in range(joints.size()):
		var joint_value: Variant = joints[index]
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D136_ENERGY_JOINT_READBACK_INVALID:%d" % index)
		var joint: Dictionary = joint_value
		if (
			String(joint.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or bool(joint.get("motor_enabled", true))
		):
			return _failure("QSDK_R24D136_ENERGY_NATIVE_MOTOR_NOT_DISABLED:%d" % index)
	var step_actuator_work := float(value.get("step_actuator_work_j", NAN))
	var no_actuation_requested := bool(value.get("no_actuation_requested", false))
	var actuator_mapping_id := String(value.get("actuator_mapping_id", ""))
	var work_mapping_id := String(value.get("work_mapping_id", ""))
	var actuation_partition_valid := is_finite(step_actuator_work)
	if no_actuation_requested:
		actuation_partition_valid = (
			actuation_partition_valid
			and step_actuator_work == 0.0
			and actuator_mapping_id.is_empty()
			and work_mapping_id.is_empty()
		)
	else:
		actuation_partition_valid = (
			actuation_partition_valid
			and actuator_mapping_id
			== JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			and work_mapping_id
			== JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	if not actuation_partition_valid:
		return _failure("QSDK_R24D136_ACTUATOR_CONSTRAINT_PARTITION_NOT_DISJOINT")
	if (
		int(value.get("external_intervention_event_count", -1)) != 0
		or float(value.get("step_signed_external_work_j", NAN)) != 0.0
		or int(value.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or float(value.get("step_signed_discrete_staging_exchange_j", NAN)) != 0.0
	):
		return _failure("QSDK_R24D136_EXTERNAL_OR_STAGING_PARTITION_NOT_ZERO")
	return {
		"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_partition_inputs_contract_v1",
		"ok": true,
		"semantic_step": int(value.get("semantic_step", -1)),
		"ordered_body_count": bodies.size(),
		"ordered_joint_count": joints.size(),
		"uniform_gravity_world_m_s2": _vector_json(uniform_gravity),
		"no_actuation_requested": no_actuation_requested,
		"actuator_mapping_id": actuator_mapping_id,
		"work_mapping_id": work_mapping_id,
		"step_actuator_work_j": step_actuator_work,
		"native_joint_motor_enabled_count": 0,
		"continuous_collision_detection_enabled_count": 0,
		"nonzero_or_nonreplace_damping_body_count": 0,
		"external_intervention_event_count": 0,
		"step_signed_external_work_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"step_signed_discrete_staging_exchange_j": 0.0,
		"step_passive_dissipation_j": 0.0,
		"constraint_exchange_partition_disjoint": true,
		"passive_dissipation_partition_complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R144 keeps R136's world configuration requirements but admits the exact
## solver-coupled realization selected by R143. Active steps require all eight
## native motors; no-actuation steps require none. No intermediate population,
## alternate mapping, implicit work source, external event, or staging event is
## accepted.
static func solver_coupled_complete_energy_partition_inputs_contract_v1(
	value: Dictionary,
) -> Dictionary:
	if (
		typeof(value.get("semantic_step")) != TYPE_INT
		or int(value["semantic_step"]) <= 0
		or typeof(value.get("no_actuation_requested")) != TYPE_BOOL
		or typeof(value.get("step_actuator_work_j")) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(value.get("external_intervention_event_count")) != TYPE_INT
		or typeof(value.get("step_signed_external_work_j")) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(value.get("adapter_side_discrete_staging_event_count")) != TYPE_INT
		or typeof(value.get("step_signed_discrete_staging_exchange_j"))
		not in [TYPE_FLOAT, TYPE_INT]
	):
		return _failure("QSDK_R24D144_ENERGY_PARTITION_SCALAR_IDENTITY_INVALID")
	var bodies_value: Variant = value.get("ordered_body_readbacks")
	var joints_value: Variant = value.get("ordered_joint_readbacks")
	if not (bodies_value is Array) or (bodies_value as Array).size() != ORDERED_BODY_IDS.size():
		return _failure("QSDK_R24D144_ENERGY_BODY_READBACK_POPULATION_INVALID")
	if not (joints_value is Array) or (joints_value as Array).size() != ORDERED_JOINT_IDS.size():
		return _failure("QSDK_R24D144_ENERGY_JOINT_READBACK_POPULATION_INVALID")
	var bodies: Array = bodies_value
	var joints: Array = joints_value
	var uniform_gravity := Vector3(NAN, NAN, NAN)
	for index in range(bodies.size()):
		var body_value: Variant = bodies[index]
		if not (body_value is Dictionary):
			return _failure("QSDK_R24D144_ENERGY_BODY_READBACK_INVALID:%d" % index)
		var body: Dictionary = body_value
		var gravity_value: Variant = body.get("total_gravity_world_m_s2")
		if not (gravity_value is Vector3):
			return _failure("QSDK_R24D144_ENERGY_BODY_GRAVITY_INVALID:%d" % index)
		var gravity: Vector3 = gravity_value
		if (
			String(body.get("body_id", "")) != ORDERED_BODY_IDS[index]
			or not gravity.is_finite()
			or (index > 0 and gravity != uniform_gravity)
			or int(body.get("linear_damp_mode", -1)) != int(RigidBody3D.DAMP_MODE_REPLACE)
			or int(body.get("angular_damp_mode", -1)) != int(RigidBody3D.DAMP_MODE_REPLACE)
			or typeof(body.get("linear_damp")) not in [TYPE_FLOAT, TYPE_INT]
			or typeof(body.get("angular_damp")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(body.get("linear_damp", NAN)))
			or not is_finite(float(body.get("angular_damp", NAN)))
			or float(body.get("linear_damp", NAN)) != 0.0
			or float(body.get("angular_damp", NAN)) != 0.0
			or bool(body.get("continuous_cd", true))
		):
			return _failure("QSDK_R24D144_ENERGY_BODY_PARTITION_INVALID:%d" % index)
		if index == 0:
			uniform_gravity = gravity
	var motor_enabled_count := 0
	for index in range(joints.size()):
		var joint_value: Variant = joints[index]
		if not (joint_value is Dictionary):
			return _failure("QSDK_R24D144_ENERGY_JOINT_READBACK_INVALID:%d" % index)
		var joint: Dictionary = joint_value
		if (
			String(joint.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or typeof(joint.get("motor_enabled")) != TYPE_BOOL
		):
			return _failure("QSDK_R24D144_ENERGY_JOINT_IDENTITY_INVALID:%d" % index)
		motor_enabled_count += int(bool(joint["motor_enabled"]))
	var step_actuator_work := float(value.get("step_actuator_work_j", NAN))
	var no_actuation_requested := bool(value.get("no_actuation_requested", false))
	var actuator_mapping_id := String(value.get("actuator_mapping_id", ""))
	var work_mapping_id := String(value.get("work_mapping_id", ""))
	var expected_motor_enabled_count := 0 if no_actuation_requested else ORDERED_JOINT_IDS.size()
	var actuation_partition_valid := (
		is_finite(step_actuator_work)
		and motor_enabled_count == expected_motor_enabled_count
	)
	if no_actuation_requested:
		actuation_partition_valid = (
			actuation_partition_valid
			and step_actuator_work == 0.0
			and actuator_mapping_id.is_empty()
			and work_mapping_id.is_empty()
		)
	else:
		actuation_partition_valid = (
			actuation_partition_valid
			and actuator_mapping_id == R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
			and work_mapping_id == R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
		)
	if not actuation_partition_valid:
		return _failure("QSDK_R24D144_ACTUATOR_CONFIGURATION_PARTITION_INVALID")
	if (
		int(value.get("external_intervention_event_count", -1)) != 0
		or float(value.get("step_signed_external_work_j", NAN)) != 0.0
		or int(value.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or float(value.get("step_signed_discrete_staging_exchange_j", NAN)) != 0.0
	):
		return _failure("QSDK_R24D144_EXTERNAL_OR_STAGING_PARTITION_NOT_ZERO")
	return {
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_inputs_contract_v1",
		"ok": true,
		"semantic_step": int(value["semantic_step"]),
		"ordered_body_count": bodies.size(),
		"ordered_joint_count": joints.size(),
		"uniform_gravity_world_m_s2": _vector_json(uniform_gravity),
		"no_actuation_requested": no_actuation_requested,
		"actuator_mapping_id": actuator_mapping_id,
		"work_mapping_id": work_mapping_id,
		"step_actuator_work_j": step_actuator_work,
		"native_joint_motor_enabled_count": motor_enabled_count,
		"expected_native_joint_motor_enabled_count": expected_motor_enabled_count,
		"continuous_collision_detection_enabled_count": 0,
		"nonzero_or_nonreplace_damping_body_count": 0,
		"external_intervention_event_count": 0,
		"step_signed_external_work_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"step_signed_discrete_staging_exchange_j": 0.0,
		"step_passive_dissipation_j": 0.0,
		"actuator_configuration_partition_compatible": true,
		"passive_dissipation_partition_complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## The declaration is data so zero-world mutation controls can prove that the
## production partition rejects overlap, omission, and double-counting rules.
## It is not a tunable runtime option: production always supplies this exact
## value from the same source module.
static func solver_coupled_complete_energy_partition_declaration_v1() -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_declaration_v1",
		"partition_rule_id": R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID,
		"actuator_mapping_id": R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID,
		"work_mapping_id": R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID,
		"joint_velocity_exchange_includes_native_motor_work": true,
		"subtract_native_motor_work_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"whole_step_mechanical_residual_used_as_work_source": false,
		"numerical_bound_kind": "deterministic_ieee754_binary32_forward_error_bound",
		"numerical_term_count": R144_PARTITION_NUMERICAL_TERM_COUNT,
		"native_float32_epsilon": NATIVE_FLOAT32_EPSILON,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Partition the exact current-step native motor population out of the native
## whole-joint velocity exchange. Every motor row and the solver receipt must
## name the same finalized space step. The reconstruction check uses the same
## declared IEEE-754 binary32 forward-error bound as the qualified Rapier
## precedent; it selects no empirical locomotion threshold or margin.
static func solver_coupled_complete_energy_partition_contract_v1(
	solver_receipt: Dictionary,
	ordered_motor_receipts: Array,
	step_actuator_work_j: float,
	expected_space_step_sequence: int,
	declaration: Dictionary,
) -> Dictionary:
	var expected_declaration := solver_coupled_complete_energy_partition_declaration_v1()
	if not _exact_variant_tree_equal_v1(declaration, expected_declaration):
		return _failure("QSDK_R24D144_PARTITION_DECLARATION_INVALID")
	if (
		String(solver_receipt.get("schema_version", ""))
		!= "sporespore_qsdk_r24d136_godot_solver_energy_exchange_contract_v1"
		or not bool(solver_receipt.get("ok", false))
		or expected_space_step_sequence <= 0
		or int(solver_receipt.get("expected_space_step_sequence", -1))
		!= expected_space_step_sequence
		or int(solver_receipt.get("capture_space_step_sequence", -1))
		!= expected_space_step_sequence
		or int(solver_receipt.get("read_space_step_sequence", -1))
		!= expected_space_step_sequence
		or not bool(solver_receipt.get("source_measurement", false))
		or bool(solver_receipt.get("mechanical_energy_residual_used_as_work_source", true))
	):
		return _failure("QSDK_R24D144_SOLVER_RECEIPT_IDENTITY_INVALID")
	if ordered_motor_receipts.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D144_MOTOR_RECEIPT_POPULATION_INVALID")
	var motor_work_sum := 0.0
	var motor_absolute_work_sum := 0.0
	for index in range(ordered_motor_receipts.size()):
		var row_value: Variant = ordered_motor_receipts[index]
		if not (row_value is Dictionary):
			return _failure("QSDK_R24D144_MOTOR_RECEIPT_INVALID:%d" % index)
		var row: Dictionary = row_value
		if (
			String(row.get("actuator_id", "")) != ORDERED_ACTUATOR_IDS[index]
			or String(row.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or String(row.get("actuator_mapping_id", ""))
			!= R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
			or String(row.get("work_mapping_id", ""))
			!= R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
			or int(row.get("capture_space_step_sequence", -1))
			!= expected_space_step_sequence
			or int(row.get("read_space_step_sequence", -1))
			!= expected_space_step_sequence
			or typeof(row.get("net_motor_work_j")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(row.get("net_motor_work_j", NAN)))
			or not bool(row.get("source_measurement", false))
			or bool(row.get("mechanical_energy_residual_used_as_work_source", true))
		):
			return _failure("QSDK_R24D144_MOTOR_RECEIPT_IDENTITY_INVALID:%d" % index)
		var motor_work := float(row["net_motor_work_j"])
		motor_work_sum += motor_work
		motor_absolute_work_sum += absf(motor_work)
	if not is_finite(step_actuator_work_j) or motor_work_sum != step_actuator_work_j:
		return _failure("QSDK_R24D144_MOTOR_WORK_AGGREGATE_INVALID")
	var required_fields := [
		"joint_velocity_constraint_exchange_j",
		"contact_velocity_constraint_exchange_j",
		"position_constraint_kinetic_exchange_j",
		"position_constraint_potential_exchange_j",
		"step_signed_constraint_exchange_j",
	]
	for key in required_fields:
		if (
			typeof(solver_receipt.get(key)) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(solver_receipt.get(key, NAN)))
		):
			return _failure("QSDK_R24D144_SOLVER_COMPONENT_NONFINITE:%s" % key)
	var joint_exchange := float(solver_receipt["joint_velocity_constraint_exchange_j"])
	var contact_exchange := float(solver_receipt["contact_velocity_constraint_exchange_j"])
	var position_kinetic_exchange := float(
		solver_receipt["position_constraint_kinetic_exchange_j"]
	)
	var position_potential_exchange := float(
		solver_receipt["position_constraint_potential_exchange_j"]
	)
	var raw_solver_exchange := float(solver_receipt["step_signed_constraint_exchange_j"])
	var nonmotor_joint_exchange := joint_exchange - motor_work_sum
	var signed_constraint_exchange := (
		nonmotor_joint_exchange
		+ contact_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var raw_component_reconstruction := (
		joint_exchange
		+ contact_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var partition_reconstruction := motor_work_sum + signed_constraint_exchange
	var absolute_term_sum := (
		motor_absolute_work_sum
		+ absf(joint_exchange)
		+ absf(contact_exchange)
		+ absf(position_kinetic_exchange)
		+ absf(position_potential_exchange)
	)
	var n := float(R144_PARTITION_NUMERICAL_TERM_COUNT)
	var denominator := 1.0 - n * NATIVE_FLOAT32_EPSILON
	if denominator <= 0.0:
		return _failure("QSDK_R24D144_NUMERICAL_BOUND_DOMAIN_INVALID")
	var gamma_n := n * NATIVE_FLOAT32_EPSILON / denominator
	var consistency_bound := (
		(2.0 * gamma_n + NATIVE_FLOAT32_EPSILON) * maxf(absolute_term_sum, 1.0)
	)
	var raw_component_delta := raw_component_reconstruction - raw_solver_exchange
	var partition_reconstruction_delta := partition_reconstruction - raw_solver_exchange
	if (
		not is_finite(nonmotor_joint_exchange)
		or not is_finite(signed_constraint_exchange)
		or not is_finite(consistency_bound)
		or absf(raw_component_delta) > consistency_bound
		or absf(partition_reconstruction_delta) > consistency_bound
	):
		return _failure(
			"QSDK_R24D144_CONSTRAINT_PARTITION_RECONSTRUCTION_INVALID",
			{
				"raw_component_delta_j": raw_component_delta,
				"partition_reconstruction_delta_j": partition_reconstruction_delta,
				"numerical_consistency_bound_j": consistency_bound,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1",
		"ok": true,
		"partition_rule_id": R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID,
		"expected_space_step_sequence": expected_space_step_sequence,
		"motor_receipt_count": ordered_motor_receipts.size(),
		"step_actuator_work_j": motor_work_sum,
		"motor_absolute_work_sum_j": motor_absolute_work_sum,
		"raw_joint_velocity_constraint_exchange_j": joint_exchange,
		"nonmotor_joint_constraint_exchange_j": nonmotor_joint_exchange,
		"contact_velocity_constraint_exchange_j": contact_exchange,
		"position_constraint_kinetic_exchange_j": position_kinetic_exchange,
		"position_constraint_potential_exchange_j": position_potential_exchange,
		"raw_step_signed_solver_exchange_j": raw_solver_exchange,
		"step_signed_constraint_exchange_j": signed_constraint_exchange,
		"raw_component_reconstruction_delta_j": raw_component_delta,
		"partition_reconstruction_delta_j": partition_reconstruction_delta,
		"numerical_bound_kind": "deterministic_ieee754_binary32_forward_error_bound",
		"numerical_term_count": R144_PARTITION_NUMERICAL_TERM_COUNT,
		"native_float32_epsilon": NATIVE_FLOAT32_EPSILON,
		"numerical_consistency_bound_j": consistency_bound,
		"joint_velocity_exchange_includes_native_motor_work": true,
		"native_motor_work_subtracted_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"constraint_exchange_partition_disjoint": true,
		"component_partition_complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func solver_coupled_complete_energy_partition_for_recovery_route_v2(
	context: Dictionary,
	solver_receipt: Dictionary,
	ordered_motor_receipts: Array,
	step_actuator_work_j: float,
	expected_space_step_sequence: int,
) -> Dictionary:
	var selected := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	if selected:
		return (
			RotationAwareEnergyLedgerScript
			. solver_coupled_complete_energy_partition_contract_v1(
				context,
				solver_receipt,
				ordered_motor_receipts,
				step_actuator_work_j,
				expected_space_step_sequence,
				RotationAwareEnergyLedgerScript.partition_declaration_v1(),
			)
		)
	for key in [
		"recovery_energy_ledger_profile_id",
		"solver_energy_consumer_contract_schema_version",
		"solver_energy_telemetry_schema_version",
		"solver_energy_telemetry_profile_id",
		"r24d161_diagnosis_raw_sha256",
	]:
		if context.has(key):
			return _failure("QSDK_R24D162_RECOVERY_LEDGER_AUTHORITY_CROSSED:%s" % key)
	return solver_coupled_complete_energy_partition_contract_v1(
		solver_receipt,
		ordered_motor_receipts,
		step_actuator_work_j,
		expected_space_step_sequence,
		solver_coupled_complete_energy_partition_declaration_v1(),
	)


## Fail closed if independently observed native/core budget decisions differ.
## The zero-world mutation gate calls this seam with an inverted decision; the
## production V2 telemetry contract records the unmodified agreement receipt.
static func strict_actuator_budget_decision_agreement_v1(
	native_v2_decision: bool,
	projected_core_decision: bool,
) -> Dictionary:
	if native_v2_decision != projected_core_decision:
		return _failure(
			"QSDK_R24D68_STRICT_ACTUATOR_BUDGET_DECISION_DISAGREEMENT",
			{
				"native_v2_strict_budget_decision": native_v2_decision,
				"projected_core_strict_budget_decision": projected_core_decision,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d68_strict_actuator_budget_decision_agreement_v1",
		"ok": true,
		"native_v2_strict_budget_decision": native_v2_decision,
		"projected_core_strict_budget_decision": projected_core_decision,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Project point-level native contact identities into one stable, unique
## provenance identity per engine shape pair. Point samples and their impulses
## remain untouched; only the portable provenance list is deduplicated.
static func native_contact_identity_projection_v1(raw_contact_ids: Array) -> Dictionary:
	var engine_contact_ids: Array[String] = []
	var seen: Dictionary = {}
	for contact_id_value in raw_contact_ids:
		if typeof(contact_id_value) != TYPE_STRING:
			return _failure("QSDK_R24D61_CONTACT_ID_TYPE_INVALID")
		var contact_id := String(contact_id_value)
		if contact_id.strip_edges().is_empty():
			return _failure("QSDK_R24D61_CONTACT_ID_EMPTY")
		if seen.has(contact_id):
			continue
		seen[contact_id] = true
		engine_contact_ids.append(contact_id)
	return {
		"schema_version": "sporespore_qsdk_r24d61_godot_contact_identity_projection_v1",
		"ok": true,
		"raw_contact_point_identity_count": raw_contact_ids.size(),
		"unique_shape_pair_identity_count": engine_contact_ids.size(),
		"duplicate_shape_pair_identity_count": (
			raw_contact_ids.size() - engine_contact_ids.size()
		),
		"engine_contact_ids": engine_contact_ids,
		"stable_first_observation_order_preserved": true,
		"point_samples_modified": false,
		"impulse_aggregation_modified": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Losslessly encode one native engine identity into the portable protocol's
## lowercase/digit/underscore grammar. The UTF-8 hex payload is injective, so
## the portable identity contains the complete raw identity rather than a hash.
static func portable_contact_identity_v1(raw_contact_id: String) -> Dictionary:
	if raw_contact_id.strip_edges().is_empty():
		return _contact_identity_projection_failure_v2(
			"QSDK_R24D67_CONTACT_ID_EMPTY"
		)
	var raw_utf8 := raw_contact_id.to_utf8_buffer()
	var hex_parts := PackedStringArray()
	for byte_value in raw_utf8:
		hex_parts.append("%02x" % int(byte_value))
	var raw_utf8_hex := "".join(hex_parts)
	var portable_id := "godot_contact_%s" % raw_utf8_hex
	if raw_utf8_hex.is_empty() or not portable_identity_grammar_valid_v1(portable_id):
		return _contact_identity_projection_failure_v2(
			"QSDK_R24D67_PORTABLE_CONTACT_ID_ENCODING_INVALID",
			{
				"raw_engine_contact_id": raw_contact_id,
				"raw_utf8_hex": raw_utf8_hex,
				"portable_engine_contact_id": portable_id,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d67_godot_portable_contact_identity_v1",
		"ok": true,
		"support_status": "supported_exact",
		"method_id": "godot_utf8_hex_portable_contact_identity_v1",
		"raw_engine_contact_id": raw_contact_id,
		"raw_utf8_byte_length": raw_utf8.size(),
		"raw_utf8_hex": raw_utf8_hex,
		"portable_engine_contact_id": portable_id,
		"portable_identity_grammar_valid": true,
		"lossless_raw_identity_embedded": true,
		"hash_or_truncation_used": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R67 production projection. R61 remains immutable for its historical tests;
## the live sampler uses this successor to deduplicate raw shape-pair identities
## and publish their collision-free lossless portable encodings.
static func native_contact_identity_projection_v2(raw_contact_ids: Array) -> Dictionary:
	var engine_contact_ids: Array[String] = []
	var raw_to_portable_identity_pairs: Array = []
	var raw_seen: Dictionary = {}
	var portable_owner: Dictionary = {}
	for contact_id_value in raw_contact_ids:
		if typeof(contact_id_value) != TYPE_STRING:
			return _contact_identity_projection_failure_v2(
				"QSDK_R24D67_CONTACT_ID_TYPE_INVALID"
			)
		var raw_contact_id := String(contact_id_value)
		if raw_contact_id.strip_edges().is_empty():
			return _contact_identity_projection_failure_v2(
				"QSDK_R24D67_CONTACT_ID_EMPTY"
			)
		if raw_seen.has(raw_contact_id):
			continue
		raw_seen[raw_contact_id] = true
		var encoding := portable_contact_identity_v1(raw_contact_id)
		if not bool(encoding.get("ok", false)):
			return _contact_identity_projection_failure_v2(
				"QSDK_R24D67_CONTACT_ID_ENCODING_FAILED",
				{"encoding": encoding},
			)
		var portable_id := String(encoding["portable_engine_contact_id"])
		if portable_owner.has(portable_id):
			return _contact_identity_projection_failure_v2(
				"QSDK_R24D67_PORTABLE_CONTACT_ID_COLLISION",
				{
					"portable_engine_contact_id": portable_id,
					"first_raw_engine_contact_id": String(portable_owner[portable_id]),
					"second_raw_engine_contact_id": raw_contact_id,
				},
			)
		portable_owner[portable_id] = raw_contact_id
		engine_contact_ids.append(portable_id)
		raw_to_portable_identity_pairs.append(
			{
				"raw_engine_contact_id": raw_contact_id,
				"raw_utf8_hex": String(encoding["raw_utf8_hex"]),
				"portable_engine_contact_id": portable_id,
				"lossless_raw_identity_embedded": true,
			}
		)
	return {
		"schema_version": "sporespore_qsdk_r24d67_godot_contact_identity_projection_v2",
		"ok": true,
		"support_status": "supported_exact",
		"method_id": "godot_utf8_hex_portable_contact_identity_v1",
		"raw_contact_point_identity_count": raw_contact_ids.size(),
		"unique_raw_shape_pair_identity_count": raw_seen.size(),
		"duplicate_raw_shape_pair_identity_count": (
			raw_contact_ids.size() - raw_seen.size()
		),
		"portable_engine_contact_identity_count": engine_contact_ids.size(),
		"portable_identity_collision_count": 0,
		"engine_contact_ids": engine_contact_ids,
		"raw_to_portable_identity_pairs": raw_to_portable_identity_pairs,
		"stable_first_observation_order_preserved": true,
		"lossless_raw_identity_embedded": true,
		"hash_or_truncation_used": false,
		"point_samples_modified": false,
		"impulse_aggregation_modified": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func portable_identity_grammar_valid_v1(value: String) -> bool:
	if value.is_empty():
		return false
	var first := value.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in range(1, value.length()):
		var character := value.unicode_at(index)
		var lowercase := character >= 97 and character <= 122
		var digit := character >= 48 and character <= 57
		if not lowercase and not digit and character != 95:
			return false
	return true


static func _contact_identity_projection_failure_v2(
	code: String,
	detail: Dictionary = {},
) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d67_godot_contact_identity_projection_v2",
		"ok": false,
		"support_status": "invalid_engine_contact_identity",
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Initialize the R168 transport exactly once after world construction has
## completed and while PhysicsServer3D is still inactive. The nine property
## reads are the only sequence-zero source. This function exists on the live
## route, but R168's zero-world qualification never calls it.
static func initialize_contiguous_boundary_transport_v1(
	sdk: Object,
	model: Dictionary,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
) -> Dictionary:
	if (
		sdk == null
		or not bool(model.get("ok", false))
		or not bool(model.get("contiguous_boundary_transport_profile_selected", false))
		or String(model.get("contiguous_boundary_transport_design_id", ""))
		!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		or String(model.get("contiguous_boundary_transport_profile_id", ""))
		!= ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
		or attempt_id.is_empty()
		or arm_id.is_empty()
		or model_instance_id.is_empty()
		or bool(model.get("physics_server_active", true))
		or model.has("contiguous_boundary_transport_state")
	):
		return _failure("QSDK_R24D168_BOUNDARY_TRANSPORT_INITIALIZATION_INVALID")
	var body_nodes_value: Variant = model.get("body_nodes")
	if not (body_nodes_value is Dictionary):
		return _failure("QSDK_R24D168_INITIALIZER_BODY_POPULATION_MISSING")
	var body_nodes: Dictionary = body_nodes_value
	var ordered_samples: Array = []
	for index in range(ORDERED_BODY_IDS.size()):
		var body_id := String(ORDERED_BODY_IDS[index])
		var body_value: Variant = body_nodes.get(body_id)
		if not (body_value is RigidBody3D):
			return _failure("QSDK_R24D168_INITIALIZER_BODY_MISSING:%s" % body_id)
		var body: RigidBody3D = body_value
		ordered_samples.append(
			{
				"body_id": body_id,
				"body_index": index,
				"boundary_sequence": 0,
				"position_world_m": body.global_transform.origin,
				"linear_velocity_world_m_s": body.linear_velocity,
				"mass_kg": body.mass,
			}
		)
	var boundary_receipt := (
		ContiguousBoundaryTransportScript
		. build_initializer_boundary_v1(
			sdk,
			attempt_id,
			arm_id,
			model_instance_id,
			"initializer:%s:%s:%s:0" % [attempt_id, arm_id, model_instance_id],
			ordered_samples,
		)
	)
	if not bool(boundary_receipt.get("ok", false)):
		return boundary_receipt
	var initialization := (
		ContiguousBoundaryTransportScript
		. initialize_boundary_transport_state_v1(
			sdk, boundary_receipt["boundary"]
		)
	)
	if not bool(initialization.get("ok", false)):
		return initialization
	model["contiguous_boundary_transport_state"] = (
		(initialization["state"] as Dictionary).duplicate(true)
	)
	model["contiguous_boundary_transport_initialized"] = true
	var initializer_receipt := {
		"schema_version": "sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1",
		"gate_id": "QSDK-R24D168",
		"ok": true,
		"transport_design_id": ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID,
		"transport_profile_id": ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID,
		"initializer_boundary_sequence": 0,
		"state_revision": 0,
		"native_readback_count": ORDERED_BODY_IDS.size(),
		"physics_active_during_readback": false,
		"source_measurement": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	model["boundary_transport_initializer_receipt"] = initializer_receipt.duplicate(true)
	if not contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
		sdk,
		model,
		initializer_receipt,
		attempt_id,
		arm_id,
		model_instance_id,
	):
		model.erase("boundary_transport_initializer_receipt")
		model.erase("contiguous_boundary_transport_initialized")
		model.erase("contiguous_boundary_transport_state")
		return _failure(
			"QSDK_R24D171_BOUNDARY_TRANSPORT_INITIALIZER_RECEIPT_RETENTION_INVALID"
		)
	return initializer_receipt


## R171 closes the retention seam exposed by R170. The receipt remains an
## R168 measurement because neither its source nor its schema changed; this
## predicate proves that the exact returned receipt and its sequence-zero
## identity were retained in the model before physics activation.
static func contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
	sdk: Object,
	model: Dictionary,
	initializer_receipt: Dictionary,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
) -> bool:
	if (
		sdk == null
		or attempt_id.is_empty()
		or arm_id.is_empty()
		or model_instance_id.is_empty()
		or bool(model.get("physics_server_active", true))
		or not bool(model.get("contiguous_boundary_transport_initialized", false))
		or initializer_receipt.size() != 17
		or (
			String(initializer_receipt.get("schema_version", ""))
			!= "sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1"
		)
		or String(initializer_receipt.get("gate_id", "")) != "QSDK-R24D168"
		or not bool(initializer_receipt.get("ok", false))
		or (
			String(initializer_receipt.get("transport_design_id", ""))
			!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		)
		or (
			String(initializer_receipt.get("transport_profile_id", ""))
			!= ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
		)
		or int(initializer_receipt.get("initializer_boundary_sequence", -1)) != 0
		or int(initializer_receipt.get("state_revision", -1)) != 0
		or int(initializer_receipt.get("native_readback_count", -1)) != ORDERED_BODY_IDS.size()
		or bool(initializer_receipt.get("physics_active_during_readback", true))
		or not bool(initializer_receipt.get("source_measurement", false))
		or int(initializer_receipt.get("model_construction_count", -1)) != 0
		or int(initializer_receipt.get("world_attempt_count", -1)) != 0
		or int(initializer_receipt.get("world_build_count", -1)) != 0
		or int(initializer_receipt.get("solver_step_count", -1)) != 0
		or bool(initializer_receipt.get("physics_state_modified", true))
		or bool(initializer_receipt.get("physical_acceptance_authority", true))
		or bool(initializer_receipt.get("release_authority", true))
	):
		return false
	var retained_value: Variant = model.get("boundary_transport_initializer_receipt")
	var state_value: Variant = model.get("contiguous_boundary_transport_state")
	if not (retained_value is Dictionary) or not (state_value is Dictionary):
		return false
	var retained: Dictionary = retained_value
	var state: Dictionary = state_value
	if retained != initializer_receipt:
		return false
	if (
		String(state.get("schema_version", ""))
		!= ContiguousBoundaryTransportScript.STATE_SCHEMA
		or (
			String(state.get("transport_design_id", ""))
			!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		)
		or String(state.get("attempt_id", "")) != attempt_id
		or String(state.get("arm_id", "")) != arm_id
		or String(state.get("model_instance_id", "")) != model_instance_id
		or state.get("ordered_body_ids", []) != ORDERED_BODY_IDS
		or int(state.get("cached_boundary_sequence", -1)) != 0
		or int(state.get("accepted_pair_count", -1)) != 0
		or int(state.get("state_revision", -1)) != 0
	):
		return false
	var cached_value: Variant = state.get("cached_completed_boundary")
	if not (cached_value is Dictionary):
		return false
	var cached: Dictionary = cached_value
	return (
		String(cached.get("schema_version", ""))
		== ContiguousBoundaryTransportScript.BOUNDARY_SCHEMA
		and (
			String(cached.get("transport_design_id", ""))
			== ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		)
		and String(cached.get("attempt_id", "")) == attempt_id
		and String(cached.get("arm_id", "")) == arm_id
		and String(cached.get("model_instance_id", "")) == model_instance_id
		and int(cached.get("boundary_sequence", -1)) == 0
		and (
			String(cached.get("source_kind", ""))
			== ContiguousBoundaryTransportScript.INITIALIZER_SOURCE_KIND
		)
		and not bool(cached.get("physics_active", true))
		and bool(cached.get("source_measurement", false))
	)


## Assemble one completed callback boundary and ask the pure transport for a
## contiguous pair. The returned successor state is deliberately pending; the
## caller must not install it until every downstream R148 operation succeeds.
static func _capture_contiguous_boundary_transport_v1(
	sdk: Object,
	model: Dictionary,
	callback_snapshots: Dictionary,
	semantic_step: int,
) -> Dictionary:
	var state_value: Variant = model.get("contiguous_boundary_transport_state")
	if (
		not bool(model.get("contiguous_boundary_transport_initialized", false))
		or not (state_value is Dictionary)
	):
		return _failure("QSDK_R24D168_BOUNDARY_TRANSPORT_STATE_MISSING")
	var state: Dictionary = state_value
	var ordered_samples: Array = []
	for index in range(ORDERED_BODY_IDS.size()):
		var body_id := String(ORDERED_BODY_IDS[index])
		var snapshot_value: Variant = callback_snapshots.get(body_id)
		if not (snapshot_value is Dictionary):
			return _failure("QSDK_R24D168_COMPLETED_BOUNDARY_BODY_MISSING:%s" % body_id)
		var snapshot: Dictionary = snapshot_value
		var transform_value: Variant = snapshot.get("transform")
		if not (transform_value is Transform3D):
			return _failure("QSDK_R24D168_COMPLETED_BOUNDARY_TRANSFORM_INVALID:%s" % body_id)
		var transform: Transform3D = transform_value
		ordered_samples.append(
			{
				"body_id": body_id,
				"body_index": index,
				"boundary_sequence": semantic_step,
				"position_world_m": transform.origin,
				"linear_velocity_world_m_s": snapshot.get("linear_velocity_world_m_s"),
				"mass_kg": snapshot.get("mass_kg"),
				"callback_sequence": snapshot.get("callback_sequence"),
				"total_gravity_world_m_s2": snapshot.get("total_gravity_world_m_s2"),
				"solver_step_s": snapshot.get("solver_step_s"),
			}
		)
	var boundary_receipt := (
		ContiguousBoundaryTransportScript
		. build_completed_step_boundary_v1(
			sdk,
			String(state.get("attempt_id", "")),
			String(state.get("arm_id", "")),
			String(state.get("model_instance_id", "")),
			semantic_step,
			"completed:%s:%s:%s:%d"
			% [
				String(state.get("attempt_id", "")),
				String(state.get("arm_id", "")),
				String(state.get("model_instance_id", "")),
				semantic_step,
			],
			ordered_samples,
		)
	)
	if not bool(boundary_receipt.get("ok", false)):
		return boundary_receipt
	var advance := (
		ContiguousBoundaryTransportScript
		. advance_boundary_transport_state_v1(
			sdk,
			state,
			boundary_receipt["boundary"],
		)
	)
	if not bool(advance.get("ok", false)):
		return advance
	var pair: Dictionary = advance["pair"]
	return {
		"schema_version": "sporespore_qsdk_r24d168_godot_jolt_contiguous_body_boundary_capture_v1",
		"gate_id": "QSDK-R24D168",
		"ok": true,
		"semantic_step": int(pair["semantic_step"]),
		"previous_sequence": int(pair["previous_sequence"]),
		"body_count": (pair["ordered_body_boundaries"] as Array).size(),
		"ordered_body_ids": (pair["ordered_body_ids"] as Array).duplicate(),
		"ordered_body_boundaries": (pair["ordered_body_boundaries"] as Array).duplicate(true),
		"pre_boundary_source_kind": String(pair["pre_source_kind"]),
		"post_boundary_source_kind": String(pair["post_source_kind"]),
		"pre_source_event_id": String(pair["pre_source_event_id"]),
		"post_source_event_id": String(pair["post_source_event_id"]),
		"transport_design_id": ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID,
		"transport_profile_id": ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID,
		"transport_state_after": (advance["state_after"] as Dictionary).duplicate(true),
		"transport_state_revision_before": int(state["state_revision"]),
		"transport_state_revision_after": int((advance["state_after"] as Dictionary)["state_revision"]),
		"cache_advance_count_pending_commit": 1,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"controller_or_behavior_result_used_as_input": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure R149 boundary-row projector shared by the live sampler and zero-world
## controls. The callback snapshot is the source-measured boundary before the
## named solve; the synchronized RigidBody3D readback is the boundary after it.
## Neither side accepts an energy residual, threshold, or behavior result.
static func discrete_staging_body_boundary_projection_v1(
	pre_callback_snapshots: Dictionary,
	post_solver_readbacks: Dictionary,
	semantic_step: int,
) -> Dictionary:
	if semantic_step < 1:
		return _failure("QSDK_R24D149_BOUNDARY_SEQUENCE_INVALID")
	var ordered_body_boundaries: Array = []
	var ordered_post_solver_readbacks: Array = []
	for index in range(ORDERED_BODY_IDS.size()):
		var body_id := String(ORDERED_BODY_IDS[index])
		var pre_value: Variant = pre_callback_snapshots.get(body_id)
		var post_value: Variant = post_solver_readbacks.get(body_id)
		if not (pre_value is Dictionary) or not (post_value is Dictionary):
			return _failure("QSDK_R24D149_BOUNDARY_BODY_MISSING:%s" % body_id)
		var pre: Dictionary = pre_value
		var post: Dictionary = post_value
		var pre_transform_value: Variant = pre.get("transform")
		var pre_velocity_value: Variant = pre.get("linear_velocity_world_m_s")
		var gravity_value: Variant = pre.get("total_gravity_world_m_s2")
		var post_position_value: Variant = post.get("position_world_m")
		var post_velocity_value: Variant = post.get("linear_velocity_world_m_s")
		if (
			String(post.get("body_id", "")) != body_id
			or typeof(pre.get("callback_sequence")) != TYPE_INT
			or int(pre.get("callback_sequence", -1)) != semantic_step
			or typeof(post.get("boundary_sequence")) != TYPE_INT
			or int(post.get("boundary_sequence", -1)) != semantic_step
			or not bool(pre.get("source_measurement", false))
			or not bool(post.get("source_measurement", false))
			or not (pre_transform_value is Transform3D)
			or not (pre_velocity_value is Vector3)
			or not (gravity_value is Vector3)
			or not (post_position_value is Vector3)
			or not (post_velocity_value is Vector3)
			or typeof(pre.get("mass_kg")) not in [TYPE_FLOAT, TYPE_INT]
			or typeof(post.get("mass_kg")) not in [TYPE_FLOAT, TYPE_INT]
		):
			return _failure("QSDK_R24D149_BOUNDARY_BODY_INVALID:%s" % body_id)
		var pre_transform: Transform3D = pre_transform_value
		var pre_velocity: Vector3 = pre_velocity_value
		var gravity: Vector3 = gravity_value
		var post_position: Vector3 = post_position_value
		var post_velocity: Vector3 = post_velocity_value
		var mass_kg := float(pre["mass_kg"])
		if (
			not pre_transform.origin.is_finite()
			or not pre_velocity.is_finite()
			or not gravity.is_finite()
			or not post_position.is_finite()
			or not post_velocity.is_finite()
			or not is_finite(mass_kg)
			or mass_kg <= 0.0
			or float(post["mass_kg"]) != mass_kg
		):
			return _failure("QSDK_R24D149_BOUNDARY_BODY_NONFINITE:%s" % body_id)
		for required_true_key in [
			"body_dynamic",
			"translation_dofs_unlocked",
			"gravity_scale_one",
			"constant_force_zero",
			"constant_torque_zero",
			"linear_damping_zero",
			"angular_damping_zero",
			"custom_integrator_disabled",
			"sleeping_disabled",
			"continuous_collision_detection_disabled",
		]:
			if (
				typeof(post.get(required_true_key)) != TYPE_BOOL
				or not bool(post[required_true_key])
			):
				return _failure(
					"QSDK_R24D149_FORCE_PATH_READBACK_INVALID:%s:%s"
					% [body_id, required_true_key]
				)
		ordered_body_boundaries.append(
			{
				"body_id": body_id,
				"body_index": index,
				"pre_boundary_sequence": semantic_step - 1,
				"post_boundary_sequence": semantic_step,
				"pre_callback_sequence": semantic_step,
				"mass_kg": mass_kg,
				"pre_position_world_m": pre_transform.origin,
				"post_position_world_m": post_position,
				"pre_linear_velocity_world_m_s": pre_velocity,
				"post_linear_velocity_world_m_s": post_velocity,
				"total_gravity_world_m_s2": gravity,
				"pre_source_measurement": true,
				"post_source_measurement": true,
			}
		)
		ordered_post_solver_readbacks.append(post.duplicate(true))
	return {
		"schema_version": (
			"sporespore_qsdk_r24d149_godot_jolt_discrete_staging_body_boundary_capture_v1"
		),
		"ok": true,
		"semantic_step": semantic_step,
		"previous_sequence": semantic_step - 1,
		"body_count": ordered_body_boundaries.size(),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_body_boundaries": ordered_body_boundaries,
		"ordered_post_solver_readbacks": ordered_post_solver_readbacks,
		"pre_boundary_source_kind": "physics_direct_body_state_callback_before_native_solve",
		"post_boundary_source_kind": "synchronized_rigid_body_property_readback_after_native_solve",
		"force_path_readback_complete": true,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"controller_or_behavior_result_used_as_input": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _capture_discrete_staging_body_boundaries_v1(
	model: Dictionary,
	pre_callback_snapshots: Dictionary,
	semantic_step: int,
) -> Dictionary:
	var post_solver_readbacks: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body: RigidBody3D = model["body_nodes"][body_id]
		post_solver_readbacks[body_id] = {
			"body_id": body_id,
			"boundary_sequence": semantic_step,
			"position_world_m": body.global_transform.origin,
			"linear_velocity_world_m_s": body.linear_velocity,
			"mass_kg": body.mass,
			"body_dynamic": not body.freeze,
			"translation_dofs_unlocked": (
				not body.axis_lock_linear_x
				and not body.axis_lock_linear_y
				and not body.axis_lock_linear_z
			),
			"gravity_scale_one": body.gravity_scale == 1.0,
			"constant_force_zero": body.constant_force == Vector3.ZERO,
			"constant_torque_zero": body.constant_torque == Vector3.ZERO,
			"linear_damping_zero": body.linear_damp == 0.0,
			"angular_damping_zero": body.angular_damp == 0.0,
			"custom_integrator_disabled": not body.custom_integrator,
			"sleeping_disabled": not body.can_sleep and not body.sleeping,
			"continuous_collision_detection_disabled": not body.continuous_cd,
			"source_measurement": true,
		}
	return discrete_staging_body_boundary_projection_v1(
		pre_callback_snapshots,
		post_solver_readbacks,
		semantic_step,
	)


## Pure route-aware application proof shared by zero-world qualification and
## the real sampler. R148 remains an outer observation identity; R144 remains
## the exact native solver, motor-work, and constraint-exchange predecessor.
static func solver_coupled_complete_energy_application_provenance_v2(
	application_intent: Dictionary,
	semantic_step: int,
	route_aware_application_provenance: bool,
) -> Dictionary:
	var failure_code := (
		"QSDK_R24D152_ROUTE_AWARE_APPLICATION_PROVENANCE_INVALID"
		if route_aware_application_provenance
		else "QSDK_R24D144_WORLD_APPLICATION_PROVENANCE_INVALID"
	)
	var bootstrap_application := bool(
		application_intent.get("bootstrap_application", false)
	)
	var application_mutation_semantics_id := String(
		application_intent.get("application_mutation_semantics_id", "")
	)
	if (
		String(application_intent.get("partition_rule_id", ""))
		!= R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
		or String(application_intent.get("actuation_realization_id", ""))
		!= R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		or not bool(application_intent.get("native_contact_solver_coupled", false))
		or bool(application_intent.get("native_joint_motors_disabled", true))
		!= bool(application_intent.get("no_actuation_requested", false))
		or int(application_intent.get("pre_solver_direct_body_impulse_write_count", -1))
		!= 0
		or (
			bootstrap_application
			and (
				semantic_step != 1
				or not bool(application_intent.get("no_actuation_requested", false))
				or not application_mutation_semantics_id.is_empty()
			)
		)
		or (
			not bootstrap_application
			and application_mutation_semantics_id
			!= R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		)
	):
		return _failure(failure_code)
	if route_aware_application_provenance:
		if (
			String(application_intent.get("energy_route_id", ""))
			!= R148_COMPLETE_ENERGY_ROUTE_ID
			or String(application_intent.get("energy_mapping_profile_id", ""))
			!= R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			or String(application_intent.get("predecessor_complete_energy_route_id", ""))
			!= R144_COMPLETE_ENERGY_ROUTE_ID
			or not bool(
				application_intent.get(
					"discrete_staging_complete_energy_profile_selected",
					false,
				)
			)
			or String(application_intent.get("complete_energy_authority_profile_id", ""))
			!= R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			or String(application_intent.get("application_provenance_profile_id", ""))
			!= R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		):
			return _failure(failure_code)
	else:
		if (
			String(application_intent.get("energy_route_id", ""))
			!= R144_COMPLETE_ENERGY_ROUTE_ID
			or String(application_intent.get("energy_mapping_profile_id", ""))
			!= R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		):
			return _failure(failure_code)
	var route_id := (
		R148_COMPLETE_ENERGY_ROUTE_ID
		if route_aware_application_provenance
		else R144_COMPLETE_ENERGY_ROUTE_ID
	)
	var world_route_id := (
		R148_COMPLETE_ENERGY_WORLD_ROUTE_ID
		if route_aware_application_provenance
		else R144_COMPLETE_ENERGY_WORLD_ROUTE_ID
	)
	var mapping_profile_id := (
		R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		if route_aware_application_provenance
		else R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d152_godot_route_aware_application_provenance_projection_v1",
		"ok": true,
		"semantic_step": semantic_step,
		"route_id": route_id,
		"world_route_id": world_route_id,
		"energy_mapping_profile_id": mapping_profile_id,
		"predecessor_complete_energy_route_id": (
			R144_COMPLETE_ENERGY_ROUTE_ID
			if route_aware_application_provenance
			else null
		),
		"predecessor_complete_energy_mapping_profile_id": (
			R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			if route_aware_application_provenance
			else null
		),
		"native_application_receipt_schema": (
			"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_application_receipt_v1"
			if route_aware_application_provenance
			else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_application_receipt_v1"
		),
		"native_source_trace_schema": (
			"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_source_trace_v1"
			if route_aware_application_provenance
			else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_source_trace_v1"
		),
		"bootstrap_application": bootstrap_application,
		"application_mutation_semantics_id": application_mutation_semantics_id,
		"route_aware_application_provenance_selected": (
			route_aware_application_provenance
		),
		"application_provenance_profile_id": (
			R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
			if route_aware_application_provenance
			else null
		),
		"complete_energy_authority_profile_id": (
			R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			if route_aware_application_provenance
			else null
		),
		"partition_rule_id": R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## The same pure observation builder is used by native sampling and source-only
## compiled-collector tests. A legacy application cannot opt in with one field.
static func controller_ownership_observation_v1(sdk: Object, application: Dictionary) -> Dictionary:
	var canonical_owner := String(application["controller_owner"])
	var selected_id := ""
	for registered_id in [CanonicalOwnershipL15.RECOVERY_CONTROLLER_ID,
		CanonicalOwnershipL15.REARWARD_CONTROLLER_ID, CanonicalOwnershipL15.RATE_LIMITED_CONTROLLER_ID]:
		if application.get("schema_version") == CanonicalOwnershipL15.profile_v1(registered_id)["application_schema"]:
			selected_id = registered_id
			break
	var candidate_id: Variant = application.get("recovery_controller_id")
	if (candidate_id is String and CanonicalOwnershipL15.candidate_id_valid_v1(candidate_id)
		and application.get("schema_version") == CanonicalOwnershipL15.profile_v1(candidate_id)["application_schema"]):
		selected_id = candidate_id
	if selected_id != "":
		var validated := CanonicalOwnershipL15.validate_v1(sdk, application, null, selected_id)
		if validated.get("ok") != true:
			return validated
		canonical_owner = validated["canonical_controller_owner"]
	elif (
		application.has("canonical_controller_owner")
		or application.has("canonical_ownership_mapping")
		or application.has("canonical_ownership_mapping_sha256")
	):
		return _failure("QSDK_R10F_L15_CANONICAL_OWNER_LEGACY_DOWNGRADE")
	return {
		"ok": true,
		"observation":
		{
			"owner": canonical_owner,
			"recovery_controller_id": application["recovery_controller_id"],
			"stance_controller_id": application["stance_controller_id"],
			"handoff_event_count": int(application["handoff_event_count"]),
			"fallback_controller_active": bool(application["fallback_controller_active"]),
			"source_measurement": true,
		},
	}


## Measure one already-completed native solver step.  Every portable source is
## derived from direct-state/contact callbacks, native motor telemetry, or an
## explicit append-only route receipt supplied by the caller.
static func sample_native_step_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	semantic_step: int,
	phase: String,
) -> Dictionary:
	# Resolve the original measurement's task before any native read or hash.
	var source_task := TaskSource.select_v1(sdk, model, application_intent, semantic_step)
	if source_task.get("ok") != true: return source_task
	var complete_energy_profile := bool(
		context.get("complete_energy_profile_selected", false)
	)
	var solver_coupled_complete_energy_profile := bool(
		context.get("solver_coupled_complete_energy_profile_selected", false)
	)
	var discrete_staging_complete_energy_profile := bool(
		context.get("discrete_staging_complete_energy_profile_selected", false)
	)
	var rotation_aware_energy_ledger_profile := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	var contiguous_boundary_transport_profile := bool(
		context.get("contiguous_boundary_transport_profile_selected", false)
	)
	var route_aware_application_provenance := bool(
		context.get("route_aware_application_provenance_selected", false)
	)
	var expected_model_staging_event_count := (
		int(model.get("host_step_count", -1))
		if discrete_staging_complete_energy_profile
		else 0
	)
	if (
		sdk == null
		or not bool(context.get("ok", false))
		or not bool(model.get("ok", false))
		or (
			complete_energy_profile
			and not bool(model.get("complete_energy_profile_selected", false))
		)
		or (
			solver_coupled_complete_energy_profile
			and (
				not complete_energy_profile
				or not bool(
					model.get("solver_coupled_complete_energy_profile_selected", false)
				)
				or String(model.get("energy_route_id", ""))
				!= String(context.get("energy_route_id", ""))
				or String(model.get("energy_mapping_profile_id", ""))
				!= String(context.get("energy_mapping_profile_id", ""))
			)
		)
		or not bool(application_intent.get("ok", false))
		or semantic_step != int(model.get("host_step_count", -1)) + 1
		or semantic_step != int(application_intent.get("semantic_step", -1))
		or phase != String(application_intent.get("phase", ""))
		or int(model.get("adapter_side_discrete_staging_event_count", -1))
		!= expected_model_staging_event_count
		or int(application_intent.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or (
			discrete_staging_complete_energy_profile
			and (
				not solver_coupled_complete_energy_profile
				or not bool(
					model.get("discrete_staging_complete_energy_profile_selected", false)
				)
				or String(context.get("energy_route_id", ""))
				!= R148_COMPLETE_ENERGY_ROUTE_ID
			)
		)
		or (
			route_aware_application_provenance
			and (
				not discrete_staging_complete_energy_profile
				or String(context.get("application_provenance_profile_id", ""))
				!= R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
			)
		)
		or (
			rotation_aware_energy_ledger_profile
			and (
				not RotationAwareEnergyLedgerScript.context_authority_exact_v1(context)
				or not bool(
					model.get("rotation_aware_energy_ledger_profile_selected", false)
				)
				or String(model.get("recovery_energy_ledger_profile_id", ""))
				!= R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			)
		)
		or (
			contiguous_boundary_transport_profile
			and (
				not discrete_staging_complete_energy_profile
				or String(context.get("contiguous_boundary_transport_design_id", ""))
				!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
				or String(context.get("contiguous_boundary_transport_profile_id", ""))
				!= ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
				or not bool(model.get("contiguous_boundary_transport_profile_selected", false))
				or not bool(model.get("contiguous_boundary_transport_initialized", false))
				or not bool(model.get("physics_server_active", false))
			)
		)
	):
		return _failure("QSDK_R24D57_WORLD_SAMPLE_IDENTITY_INVALID")
	var application_provenance: Dictionary = {}
	if solver_coupled_complete_energy_profile:
		application_provenance = solver_coupled_complete_energy_application_provenance_v2(
			application_intent,
			semantic_step,
			route_aware_application_provenance,
		)
		if not bool(application_provenance.get("ok", false)):
			return application_provenance

	var snapshots: Dictionary = {}
	var callback_sequence := -1
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body: RigidBody3D = model["body_nodes"][body_id]
		var snapshot_value: Variant = body.get("latest_direct_state_snapshot")
		if not (snapshot_value is Dictionary):
			return _failure("QSDK_R24D57_WORLD_DIRECT_STATE_MISSING:%s" % body_id)
		var snapshot: Dictionary = snapshot_value
		var sequence := int(snapshot.get("callback_sequence", -1))
		if (
			sequence < 1
			or (callback_sequence >= 0 and sequence != callback_sequence)
			or not bool(snapshot.get("source_measurement", false))
			or not (snapshot.get("transform") is Transform3D)
			or not (snapshot.get("linear_velocity_world_m_s") is Vector3)
			or not (snapshot.get("angular_velocity_world_rad_s") is Vector3)
			or not (snapshot.get("total_gravity_world_m_s2") is Vector3)
			or not (snapshot.get("inverse_inertia_tensor_world_kg_inv_m2") is Basis)
		):
			return _failure("QSDK_R24D57_WORLD_DIRECT_STATE_INVALID:%s" % body_id)
		callback_sequence = sequence
		snapshots[body_id] = snapshot
	if callback_sequence != semantic_step:
		return _failure("QSDK_R24D57_WORLD_CALLBACK_SEQUENCE_INVALID")
	var discrete_staging_boundary_capture: Dictionary = {}
	if discrete_staging_complete_energy_profile:
		discrete_staging_boundary_capture = (
			_capture_contiguous_boundary_transport_v1(
				sdk, model, snapshots, semantic_step
			)
			if contiguous_boundary_transport_profile
			else _capture_discrete_staging_body_boundaries_v1(
				model, snapshots, semantic_step
			)
		)
		if not bool(discrete_staging_boundary_capture.get("ok", false)):
			return discrete_staging_boundary_capture
	var angular_velocity_runtime_projection := (
		jolt_angular_velocity_limit_runtime_projection_v1()
	)
	if not bool(angular_velocity_runtime_projection.get("ok", false)):
		return angular_velocity_runtime_projection
	var ordered_body_angular_velocity_measurements: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var snapshot: Dictionary = snapshots[body_id]
		ordered_body_angular_velocity_measurements.append(
			{
				"body_id": body_id,
				"callback_sequence": int(snapshot["callback_sequence"]),
				"angular_velocity_world_rad_s": snapshot[
					"angular_velocity_world_rad_s"
				],
				"source_measurement": bool(snapshot["source_measurement"]),
			}
		)
	var native_engine_health_receipt := body_angular_velocity_limit_receipt_v1(
		angular_velocity_runtime_projection,
		ordered_body_angular_velocity_measurements,
		semantic_step,
	)
	if not bool(native_engine_health_receipt.get("ok", false)):
		return native_engine_health_receipt
	var native_engine_health_receipt_sha256 := _sha256(
		sdk, native_engine_health_receipt
	)
	if native_engine_health_receipt_sha256.is_empty():
		return _failure("QSDK_R24D93_NATIVE_ENGINE_HEALTH_DIGEST_FAILED")

	var telemetry_by_actuator_id: Dictionary = {}
	var native_space_step_sequence := -1
	var solver_step_s := NAN
	var ordered_applied_impulses: Array = []
	var ordered_telemetry_receipts: Array = []
	var step_actuator_work_j := 0.0
	var observed_guard_engagement_count := 0
	var observed_guard_minimum_applied_scale := 1.0
	var observed_guard_post_application_readback_count := 0
	var actuator_mapping_id := String(application_intent.get("actuator_mapping_id", ""))
	var legacy_force_based_active := actuator_mapping_id == FORCE_BASED_ACTUATOR_MAPPING_ID
	var r94_guarded_force_based_active := (
		actuator_mapping_id == GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var r96_nested_guarded_force_based_active := (
		actuator_mapping_id == NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var component_norm_nested_guarded_force_based_active := (
		actuator_mapping_id
		== COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var refinement_safe_component_norm_nested_guarded_force_based_active := (
		actuator_mapping_id
		== REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var order_neutral_population_guarded_force_based_active := (
		actuator_mapping_id == ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var joint_target_monotone_population_guarded_force_based_active := (
		actuator_mapping_id
		== JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var joint_space_effective_inertia_population_guarded_force_based_active := (
		actuator_mapping_id
		== JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var solver_coupled_complete_energy_active := (
		solver_coupled_complete_energy_profile
		and actuator_mapping_id == R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
	)
	var aggregate_population_guarded_force_based_active := (
		order_neutral_population_guarded_force_based_active
		or joint_target_monotone_population_guarded_force_based_active
		or joint_space_effective_inertia_population_guarded_force_based_active
	)
	component_norm_nested_guarded_force_based_active = (
		component_norm_nested_guarded_force_based_active
		or refinement_safe_component_norm_nested_guarded_force_based_active
		or aggregate_population_guarded_force_based_active
	)
	var refinement_safe_guard_required := (
		refinement_safe_component_norm_nested_guarded_force_based_active
		or aggregate_population_guarded_force_based_active
	)
	var nested_guarded_force_based_active := (
		r96_nested_guarded_force_based_active
		or component_norm_nested_guarded_force_based_active
	)
	var guarded_force_based_active := (
		r94_guarded_force_based_active or nested_guarded_force_based_active
	)
	var force_based_active := legacy_force_based_active or guarded_force_based_active
	var selected_force_based_actuator_mapping_id := (
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if joint_space_effective_inertia_population_guarded_force_based_active
		else
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if joint_target_monotone_population_guarded_force_based_active
		else
		ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if order_neutral_population_guarded_force_based_active
		else
		REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if refinement_safe_component_norm_nested_guarded_force_based_active
		else
		COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if component_norm_nested_guarded_force_based_active
		else
		NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if r96_nested_guarded_force_based_active
		else GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		if r94_guarded_force_based_active
		else FORCE_BASED_ACTUATOR_MAPPING_ID
	)
	var selected_force_based_work_mapping_id := (
		JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if joint_space_effective_inertia_population_guarded_force_based_active
		else
		JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if joint_target_monotone_population_guarded_force_based_active
		else
		ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if order_neutral_population_guarded_force_based_active
		else
		REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if refinement_safe_component_norm_nested_guarded_force_based_active
		else
		COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if component_norm_nested_guarded_force_based_active
		else
		NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if r96_nested_guarded_force_based_active
		else GUARDED_FORCE_BASED_WORK_MAPPING_ID
		if r94_guarded_force_based_active
		else FORCE_BASED_WORK_MAPPING_ID
	)
	if (
		not actuator_mapping_id.is_empty()
		and not force_based_active
		and not solver_coupled_complete_energy_active
	):
		return _failure("QSDK_R24D87_WORLD_ACTUATOR_MAPPING_INVALID")
	if solver_coupled_complete_energy_profile:
		var no_actuation_requested := bool(
			application_intent.get("no_actuation_requested", false)
		)
		var work_mapping_id := String(application_intent.get("work_mapping_id", ""))
		if (
			no_actuation_requested
			and (not actuator_mapping_id.is_empty() or not work_mapping_id.is_empty())
			or not no_actuation_requested
			and (
				not solver_coupled_complete_energy_active
				or work_mapping_id != R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
			)
		):
			return _failure("QSDK_R24D144_WORLD_ACTUATOR_WORK_MAPPING_INVALID")
	var force_based_intents: Array = []
	var joint_space_effective_inertia_population_projection: Dictionary = {}
	var joint_target_monotone_population_projection: Dictionary = {}
	var order_neutral_population_projection: Dictionary = {}
	var order_neutral_population_readback: Dictionary = {}
	if force_based_active:
		var intent_values: Variant = application_intent.get("ordered_intents")
		var receipt_values: Variant = application_intent.get("ordered_receipts")
		var expected_application_schema := (
			"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
			if joint_space_effective_inertia_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_command_application_receipt_v1"
			if joint_target_monotone_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_command_application_receipt_v1"
			if order_neutral_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_command_application_receipt_v1"
			if refinement_safe_component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d99_godot_component_norm_nested_guarded_force_based_command_application_receipt_v1"
			if component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d96_godot_nested_guarded_force_based_command_application_receipt_v1"
			if r96_nested_guarded_force_based_active
			else "sporespore_qsdk_r24d94_godot_guarded_force_based_command_application_receipt_v1"
			if r94_guarded_force_based_active
			else "sporespore_qsdk_r24d87_godot_force_based_command_application_receipt_v1"
		)
		var expected_body_impulse_write_count := int(
			application_intent.get("body_impulse_write_count", -1)
		)
		if not aggregate_population_guarded_force_based_active:
			expected_body_impulse_write_count = 16
		var expected_post_application_readback_count := (
			ORDERED_BODY_IDS.size() if aggregate_population_guarded_force_based_active else 16
		)
		if (
			String(application_intent.get("schema_version", ""))
			!= expected_application_schema
			or String(application_intent.get("work_mapping_id", ""))
			!= selected_force_based_work_mapping_id
			or bool(application_intent.get("zero_command", true))
			or int(application_intent.get("source_control_semantic_step", -1))
			!= semantic_step - 1
			or int(application_intent.get("motor_enabled_count", -1)) != 0
			or int(
				application_intent.get("hard_constraint_motor_disabled_count", -1)
			)
			!= 8
			or int(
				application_intent.get("hard_constraint_motor_target_write_count", -1)
			)
			!= 0
			or int(application_intent.get("host_write_count", -1))
			!= expected_body_impulse_write_count
			or int(application_intent.get("host_readback_count", -1)) != 8
			or expected_body_impulse_write_count < 0
			or (
				expected_body_impulse_write_count
				> (
					ORDERED_BODY_IDS.size()
					if aggregate_population_guarded_force_based_active
					else 16
				)
			)
			or (
				bool(application_intent.get("physics_state_modified", false))
				!= (expected_body_impulse_write_count > 0)
			)
			or not (intent_values is Array)
			or not (receipt_values is Array)
			or (intent_values as Array).size() != 8
			or not _exact_variant_tree_equal_v1(intent_values, receipt_values)
		):
			return _failure("QSDK_R24D87_WORLD_APPLICATION_RECEIPT_INVALID")
		if guarded_force_based_active:
			var guard_projection_value: Variant = application_intent.get(
				"native_angular_velocity_guard_limit_projection"
			)
			if not (guard_projection_value is Dictionary):
				return _failure("QSDK_R24D94_WORLD_GUARD_LIMIT_RECEIPT_MISSING")
			var guard_projection: Dictionary = guard_projection_value
			var expected_guard_projection := (
				native_angular_velocity_guard_limit_projection_v1(
					guard_projection.get("runtime_limit_projection")
				)
			)
			if (
				not bool(expected_guard_projection.get("ok", false))
				or not _exact_variant_tree_equal_v1(
					guard_projection, expected_guard_projection
				)
				or String(application_intent.get("predecessor_actuator_mapping_id", ""))
				!= FORCE_BASED_ACTUATOR_MAPPING_ID
				or not bool(
					application_intent.get("native_angular_velocity_guard_required", false)
				)
				or int(
					application_intent.get(
						"native_angular_velocity_guard_engagement_count", -1
					)
				)
				< 0
				or not is_finite(
					float(
						application_intent.get(
							"native_angular_velocity_guard_minimum_applied_scale", NAN
						)
					)
				)
				or float(
					application_intent.get(
						"native_angular_velocity_guard_minimum_applied_scale", NAN
					)
				)
				< 0.0
				or float(
					application_intent.get(
						"native_angular_velocity_guard_minimum_applied_scale", NAN
					)
				)
				> 1.0
				or int(
					application_intent.get(
						"native_angular_velocity_initial_readback_count", -1
					)
				)
				!= ORDERED_BODY_IDS.size()
				or int(
					application_intent.get(
						"native_angular_velocity_post_application_readback_count", -1
					)
				)
				!= expected_post_application_readback_count
				or int(
					application_intent.get(
						"native_angular_velocity_total_readback_count", -1
					)
				)
				!= ORDERED_BODY_IDS.size() + expected_post_application_readback_count
				or not bool(
					application_intent.get(
						"all_immediate_native_readbacks_inside_guard", false
					)
				)
			):
				return _failure("QSDK_R24D94_WORLD_GUARDED_APPLICATION_INVALID")
			if nested_guarded_force_based_active:
				var inner_target_value: Variant = application_intent.get(
					"native_angular_velocity_inner_projection_target"
				)
				if not (inner_target_value is Dictionary):
					return _failure("QSDK_R24D96_WORLD_INNER_TARGET_RECEIPT_MISSING")
				var expected_inner_target := (
					native_angular_velocity_inner_projection_target_v1(guard_projection)
				)
				if (
					not bool(expected_inner_target.get("ok", false))
					or not _exact_variant_tree_equal_v1(
						inner_target_value, expected_inner_target
					)
					or not bool(
						application_intent.get(
							"native_angular_velocity_nested_projection_required", false
						)
					)
					or not bool(
						application_intent.get(
							"projection_target_separated_from_native_readback_guard",
							false
						)
					)
					or component_norm_nested_guarded_force_based_active
					and (
						String(application_intent.get("numeric_predicate_id", ""))
						!= COMPONENT_NORM_NUMERIC_PREDICATE_ID
						or not bool(
							application_intent.get(
								"component_norm_numeric_predicate_required", false
							)
						)
					)
					or bool(application_intent.get("refinement_safe_guard_required", false))
					!= refinement_safe_guard_required
				):
					return _failure("QSDK_R24D96_WORLD_INNER_TARGET_RECEIPT_INVALID")
			if aggregate_population_guarded_force_based_active:
				var population_value: Variant = application_intent.get(
					(
						"joint_space_effective_inertia_population_guard_projection"
						if joint_space_effective_inertia_population_guarded_force_based_active
						else "joint_target_monotone_population_guard_projection"
						if joint_target_monotone_population_guarded_force_based_active
						else "order_neutral_population_guard_projection"
					)
				)
				var population_readback_value: Variant = application_intent.get(
					"order_neutral_population_native_angular_velocity_readback"
				)
				var body_application_values: Variant = application_intent.get(
					"ordered_body_application_receipts"
				)
				if (
					not (population_value is Dictionary)
					or not (population_readback_value is Dictionary)
					or not (body_application_values is Array)
				):
					return _failure("QSDK_R24D103_WORLD_POPULATION_RECEIPT_MISSING")
				var population_validation := (
					validate_joint_space_effective_inertia_population_guard_projection_v1(
						population_value
					)
					if joint_space_effective_inertia_population_guarded_force_based_active
					else validate_joint_target_monotone_population_guard_projection_v1(
						population_value
					)
					if joint_target_monotone_population_guarded_force_based_active
					else validate_order_neutral_population_guard_projection_v1(
						population_value
					)
				)
				if bool(population_validation.get("ok", false)):
					if joint_space_effective_inertia_population_guarded_force_based_active:
						joint_space_effective_inertia_population_projection = (
							population_validation["projection"]
						)
						order_neutral_population_projection = (
							joint_space_effective_inertia_population_projection[
								"body_guard_population_projection"
							]
						)
					elif joint_target_monotone_population_guarded_force_based_active:
						joint_target_monotone_population_projection = (
							population_validation["projection"]
						)
						order_neutral_population_projection = (
							joint_target_monotone_population_projection[
								"body_guard_population_projection"
							]
						)
					else:
						order_neutral_population_projection = population_validation["projection"]
				var population_readback_validation := validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
					order_neutral_population_projection, population_readback_value
				)
				if (
					not bool(population_validation.get("ok", false))
					or not bool(population_readback_validation.get("ok", false))
				):
					return _failure("QSDK_R24D103_WORLD_POPULATION_RECEIPT_INVALID")
				order_neutral_population_readback = population_readback_validation["receipt"]
				var population_body_projections: Array = order_neutral_population_projection["ordered_body_projections"]
				var body_application_receipts: Array = body_application_values
				var observed_body_write_count := 0
				if body_application_receipts.size() != ORDERED_BODY_IDS.size():
					return _failure("QSDK_R24D103_WORLD_BODY_APPLICATION_CARDINALITY_INVALID")
				for body_index in range(body_application_receipts.size()):
					var body_application_value: Variant = body_application_receipts[body_index]
					if not (body_application_value is Dictionary):
						return _failure("QSDK_R24D103_WORLD_BODY_APPLICATION_INVALID")
					var body_application: Dictionary = body_application_value
					var call_performed := bool(body_application.get("call_performed", false))
					if (
						int(body_application.get("body_index", -1)) != body_index
						or (
							String(body_application.get("body_id", ""))
							!= String(ORDERED_BODY_IDS[body_index])
						)
						or (
							String(body_application.get("api", ""))
							!= "RigidBody3D.apply_torque_impulse"
						)
						or bool(body_application.get("call_returned", false)) != call_performed
						or (
							int(body_application.get("body_impulse_write_count", -1))
							!= int(call_performed)
						)
						or not bool(body_application.get("canonical_body_order", false))
						or (
							call_performed
							!= bool(
								(population_body_projections[body_index] as Dictionary).get(
									"nonzero_body_impulse", false
								)
							)
						)
						or not _exact_variant_tree_equal_v1(
							body_application.get("aggregate_impulse_world_nms"),
							(population_body_projections[body_index] as Dictionary).get(
								"applied_aggregate_impulse_world_nms"
							),
						)
					):
						return _failure("QSDK_R24D103_WORLD_BODY_APPLICATION_INVALID")
					observed_body_write_count += int(call_performed)
				if (
					observed_body_write_count != expected_body_impulse_write_count
					or (
						observed_body_write_count
						!= int(
							order_neutral_population_projection.get(
								"nonzero_body_impulse_count", -1
							)
						)
					)
					or not bool(
						application_intent.get(
							"order_neutral_population_projection_required", false
						)
					)
					or bool(
						application_intent.get(
							"joint_space_effective_inertia_population_projection_required",
							false,
						)
					)
					!= joint_space_effective_inertia_population_guarded_force_based_active
					or bool(
						application_intent.get(
							"joint_target_monotone_population_projection_required", false
						)
					)
					!= joint_target_monotone_population_guarded_force_based_active
					or joint_space_effective_inertia_population_guarded_force_based_active
					and (
						float(
							application_intent.get(
								"joint_space_effective_inertia_common_pre_scale", NAN
							)
						)
						!= float(
							joint_space_effective_inertia_population_projection.get(
								"joint_space_common_pre_scale", NAN
							)
						)
						or float(
							application_intent.get("body_guard_common_applied_scale", NAN)
						)
						!= float(
							joint_space_effective_inertia_population_projection.get(
								"body_guard_common_applied_scale", NAN
							)
						)
						or int(application_intent.get("representation_refinement_count", -1))
						!= int(
							joint_space_effective_inertia_population_projection.get(
								"representation_refinement_count", -2
							)
						)
						or not bool(
							application_intent.get(
								"all_joint_target_errors_nonincreasing", false
							)
						)
						or int(application_intent.get("joint_target_crossing_count", -1)) != 0
					)
					or joint_target_monotone_population_guarded_force_based_active
					and (
						float(
							application_intent.get(
								"joint_target_monotone_common_pre_scale", NAN
							)
						)
						!= float(
							joint_target_monotone_population_projection.get(
								"target_common_pre_scale", NAN
							)
						)
						or float(
							application_intent.get("body_guard_common_applied_scale", NAN)
						)
						!= float(
							joint_target_monotone_population_projection.get(
								"body_guard_common_applied_scale", NAN
							)
						)
						or not bool(
							application_intent.get(
								"all_joint_target_errors_nonincreasing", false
							)
						)
						or int(application_intent.get("joint_target_crossing_count", -1)) != 0
					)
					or not bool(
						application_intent.get("aggregate_body_application_required", false)
					)
					or not bool(application_intent.get("per_actuator_attribution_required", false))
					or bool(
						application_intent.get("input_iteration_order_has_action_authority", true)
					)
				):
					return _failure("QSDK_R24D103_WORLD_POPULATION_APPLICATION_INVALID")
				observed_guard_post_application_readback_count = ORDERED_BODY_IDS.size()
		force_based_intents = (intent_values as Array).duplicate(true)
	for index in range(8):
		var actuator_id := String(ORDERED_ACTUATOR_IDS[index])
		var joint_id := String(ORDERED_JOINT_IDS[index])
		var joint: HingeJoint3D = model["joint_nodes"][joint_id]
		var cap := float(
			(model["blueprint"]["cap_by_actuator_id"][actuator_id] as Dictionary)[
				"maximum_outer_step_impulse_nms"
			]
		)
		var telemetry: Dictionary = {}
		var read_sequence := -1
		var capture_sequence := -1
		var current_step_s := NAN
		var signed_impulse := NAN
		var positive_work := NAN
		var absorbed_work := NAN
		var net_work := NAN
		var native_net_work := NAN
		var net_work_projection_delta := NAN
		if force_based_active:
			var intent_value: Variant = force_based_intents[index]
			if not (intent_value is Dictionary):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_INTENT_INVALID:%d" % index
				)
			var intent: Dictionary = intent_value
			var projection_candidate := intent.duplicate(true)
			var guard_readback_value: Variant = intent.get(
				"native_angular_velocity_readback"
			)
			var call_receipt_valid := (
				(
					bool(projection_candidate.get("aggregate_body_application", false))
					and bool(projection_candidate.get("joint_attribution_only", false))
					and int(
						projection_candidate.get(
							"direct_joint_body_impulse_write_count", -1
						)
					)
					== 0
					and int(projection_candidate.get("body_impulse_write_count", -1)) == 0
				)
				if aggregate_population_guarded_force_based_active
				else
				(
					String(projection_candidate.get("parent_api", ""))
					== "RigidBody3D.apply_torque_impulse"
					and String(projection_candidate.get("child_api", ""))
					== "RigidBody3D.apply_torque_impulse"
					and bool(projection_candidate.get("parent_call_returned", false))
					and bool(projection_candidate.get("child_call_returned", false))
					and int(projection_candidate.get("body_impulse_write_count", -1)) == 2
				)
			)
			if (
				not call_receipt_valid
				or guarded_force_based_active
				and not (guard_readback_value is Dictionary)
			):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_CALL_RECEIPT_INVALID:%d" % index
				)
			for receipt_key in [
				"parent_api",
				"child_api",
				"parent_call_returned",
				"child_call_returned",
				"aggregate_body_application",
				"joint_attribution_only",
				"direct_joint_body_impulse_write_count",
				"body_impulse_write_count",
				"native_angular_velocity_readback",
			]:
				projection_candidate.erase(receipt_key)
			var projection_validation := (
				validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate, joint_space_effective_inertia_population_projection
				)
				if joint_space_effective_inertia_population_guarded_force_based_active
				else
				validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate, joint_target_monotone_population_projection
				)
				if joint_target_monotone_population_guarded_force_based_active
				else
				validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate, order_neutral_population_projection
				)
				if order_neutral_population_guarded_force_based_active
				else
				validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
					projection_candidate
				)
				if refinement_safe_component_norm_nested_guarded_force_based_active
				else
				validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate
				)
				if component_norm_nested_guarded_force_based_active
				else
				validate_nested_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate
				)
				if r96_nested_guarded_force_based_active
				else validate_guarded_force_based_joint_impulse_projection_v1(
					projection_candidate
				)
				if r94_guarded_force_based_active
				else validate_force_based_joint_impulse_projection_v1(
					projection_candidate
				)
			)
			if not bool(projection_validation.get("ok", false)):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_PROJECTION_INVALID:%d" % index,
					projection_validation,
				)
			var projection: Dictionary = projection_validation["projection"]
			var guard_readback_receipt: Dictionary = {}
			var guard_applied_scale := NAN
			if guarded_force_based_active:
				var guard_readback_validation := (
					validate_joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
						projection,
						joint_space_effective_inertia_population_projection,
						order_neutral_population_readback,
						guard_readback_value,
					)
					if joint_space_effective_inertia_population_guarded_force_based_active
					else
					validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
						projection,
						joint_target_monotone_population_projection,
						order_neutral_population_readback,
						guard_readback_value,
					)
					if joint_target_monotone_population_guarded_force_based_active
					else
					validate_order_neutral_population_joint_angular_velocity_readback_receipt_v1(
						projection,
						order_neutral_population_projection,
						order_neutral_population_readback,
						guard_readback_value,
					)
					if order_neutral_population_guarded_force_based_active
					else
					validate_refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
						projection, guard_readback_value
					)
					if refinement_safe_component_norm_nested_guarded_force_based_active
					else
					validate_component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
						projection, guard_readback_value
					)
					if component_norm_nested_guarded_force_based_active
					else
					validate_nested_native_angular_velocity_guard_readback_receipt_v1(
						projection, guard_readback_value
					)
					if r96_nested_guarded_force_based_active
					else validate_native_angular_velocity_guard_readback_receipt_v1(
						projection, guard_readback_value
					)
				)
				if not bool(guard_readback_validation.get("ok", false)):
					return _failure(
						"QSDK_R24D94_WORLD_GUARD_READBACK_INVALID:%d" % index,
						guard_readback_validation,
					)
				guard_readback_receipt = guard_readback_validation["receipt"]
				var applied_scale_projection := (
					joint_space_effective_inertia_population_guarded_force_based_applied_scale_projection_v1(
						projection, joint_space_effective_inertia_population_projection
					)
					if joint_space_effective_inertia_population_guarded_force_based_active
					else
					joint_target_monotone_population_guarded_force_based_applied_scale_projection_v1(
						projection, joint_target_monotone_population_projection
					)
					if joint_target_monotone_population_guarded_force_based_active
					else
					order_neutral_population_guarded_force_based_applied_scale_projection_v1(
						projection, order_neutral_population_projection
					)
					if order_neutral_population_guarded_force_based_active
					else
					refinement_safe_component_norm_guarded_force_based_applied_scale_projection_v2(
						projection
					)
					if refinement_safe_component_norm_nested_guarded_force_based_active
					else
					component_norm_guarded_force_based_applied_scale_projection_v1(
						projection
					)
					if component_norm_nested_guarded_force_based_active
					else guarded_force_based_applied_scale_projection_v1(
						projection, nested_guarded_force_based_active
					)
				)
				if not bool(applied_scale_projection.get("ok", false)):
					return _failure(
						"QSDK_R24D97_WORLD_APPLIED_SCALE_PROJECTION_INVALID:%d" % index,
						applied_scale_projection,
					)
				guard_applied_scale = float(applied_scale_projection["applied_scale"])
				observed_guard_engagement_count += int(
					bool(projection["native_angular_velocity_guard_engaged"])
				)
				observed_guard_minimum_applied_scale = minf(
					observed_guard_minimum_applied_scale,
					guard_applied_scale,
				)
				if not aggregate_population_guarded_force_based_active:
					observed_guard_post_application_readback_count += int(
						guard_readback_receipt["readback_count"]
					)
			var state_value: Variant = model["joint_states"].get(joint_id)
			if not (state_value is Dictionary):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_JOINT_STATE_INVALID:%d" % index
				)
			var state: Dictionary = state_value
			var parent: RigidBody3D = state["parent"]
			var child: RigidBody3D = state["child"]
			if (
				int(projection.get("actuator_index", -1)) != index
				or int(projection.get("application_semantic_step", -1)) != semantic_step
				or String(projection.get("parent_body_id", ""))
				!= String(parent.get_meta("lab_body_id"))
				or String(projection.get("child_body_id", ""))
				!= String(child.get_meta("lab_body_id"))
				or state.get("axis_parent_local") != FORCE_BASED_AXIS_PARENT_LOCAL
				or joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
				or float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY))
				!= 0.0
			):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_BINDING_INVALID:%d" % index
				)
			var post_relative_velocity := _joint_rate_from_snapshots(state, snapshots)
			var work_projection := (
				joint_space_effective_inertia_population_guarded_force_based_joint_work_projection_v1(
					projection,
					joint_space_effective_inertia_population_projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if joint_space_effective_inertia_population_guarded_force_based_active
				else
				joint_target_monotone_population_guarded_force_based_joint_work_projection_v1(
					projection,
					joint_target_monotone_population_projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if joint_target_monotone_population_guarded_force_based_active
				else
				order_neutral_population_guarded_force_based_joint_work_projection_v1(
					projection,
					order_neutral_population_projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if order_neutral_population_guarded_force_based_active
				else
				refinement_safe_component_norm_nested_guarded_force_based_joint_work_projection_v2(
					projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if refinement_safe_component_norm_nested_guarded_force_based_active
				else
				component_norm_nested_guarded_force_based_joint_work_projection_v1(
					projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if component_norm_nested_guarded_force_based_active
				else
				nested_guarded_force_based_joint_work_projection_v1(
					projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if r96_nested_guarded_force_based_active
				else guarded_force_based_joint_work_projection_v1(
					projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
				if r94_guarded_force_based_active
				else force_based_joint_work_projection_v1(
					projection,
					semantic_step,
					true,
					FORCE_BASED_AXIS_PARENT_LOCAL,
					post_relative_velocity,
				)
			)
			if not bool(work_projection.get("ok", false)):
				return _failure(
					"QSDK_R24D87_WORLD_FORCE_BASED_WORK_INVALID:%d" % index,
					work_projection,
				)
			read_sequence = callback_sequence
			capture_sequence = callback_sequence
			current_step_s = OUTER_STEP_DURATION_S
			signed_impulse = float(
				work_projection["applied_signed_joint_impulse_nms"]
			)
			positive_work = float(work_projection["positive_motor_work_j"])
			absorbed_work = float(work_projection["absorbed_motor_work_j"])
			net_work = float(work_projection["net_motor_work_j"])
			native_net_work = net_work
			net_work_projection_delta = 0.0
			telemetry = {
				"schema_version": (
					"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_joint_source_v1"
					if joint_space_effective_inertia_population_guarded_force_based_active
					else
					"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_joint_source_v1"
					if joint_target_monotone_population_guarded_force_based_active
					else
					"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_joint_source_v1"
					if order_neutral_population_guarded_force_based_active
					else
					"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_joint_source_v1"
					if refinement_safe_component_norm_nested_guarded_force_based_active
					else
					"sporespore_qsdk_r24d99_godot_component_norm_nested_guarded_force_based_joint_source_v1"
					if component_norm_nested_guarded_force_based_active
					else
					"sporespore_qsdk_r24d96_godot_nested_guarded_force_based_joint_source_v1"
					if r96_nested_guarded_force_based_active
					else "sporespore_qsdk_r24d94_godot_guarded_force_based_joint_source_v1"
					if r94_guarded_force_based_active
					else "sporespore_qsdk_r24d87_godot_force_based_joint_source_v1"
				),
				"actuator_mapping_id": selected_force_based_actuator_mapping_id,
				"work_mapping_id": selected_force_based_work_mapping_id,
				"actuator_id": actuator_id,
				"joint_id": joint_id,
				"read_space_step_sequence": read_sequence,
				"capture_space_step_sequence": capture_sequence,
				"solver_step_s": current_step_s,
				"signed_motor_impulse_nms": signed_impulse,
				"applied_signed_joint_impulse_nms": signed_impulse,
				"published_maximum_outer_step_impulse_nms": cap,
				"impulse_saturated": bool(projection["impulse_saturated"]),
				"pre_relative_velocity_rad_s": float(
					work_projection["pre_relative_velocity_rad_s"]
				),
				"post_relative_velocity_rad_s": float(
					work_projection["post_relative_velocity_rad_s"]
				),
				"centered_relative_velocity_rad_s": float(
					work_projection["centered_relative_velocity_rad_s"]
				),
				"positive_motor_work_j": positive_work,
				"absorbed_motor_work_j": absorbed_work,
				"net_motor_work_j": net_work,
				"native_net_motor_work_j": native_net_work,
				"net_motor_work_projection_delta_j": 0.0,
				"net_motor_work_projection_schema": String(
					work_projection["schema_version"]
				),
				"mechanical_energy_residual_used_as_work_source": false,
				"source_measurement": true,
			}
			if guarded_force_based_active:
				telemetry["native_angular_velocity_guard_engaged"] = bool(
					projection["native_angular_velocity_guard_engaged"]
				)
				telemetry["native_angular_velocity_guard_applied_scale"] = guard_applied_scale
				telemetry["native_angular_velocity_readback"] = guard_readback_receipt
				if nested_guarded_force_based_active:
					telemetry["native_angular_velocity_projection_target_engaged"] = bool(
						projection["native_angular_velocity_projection_target_engaged"]
					)
					telemetry["angular_velocity_projection_target_limit_rad_s"] = float(
						projection["angular_velocity_projection_target_limit_rad_s"]
					)
					if component_norm_nested_guarded_force_based_active:
						telemetry["numeric_predicate_id"] = COMPONENT_NORM_NUMERIC_PREDICATE_ID
						telemetry["component_norm_numeric_predicate_required"] = true
						if refinement_safe_guard_required:
							telemetry["refinement_safe_guard_required"] = true
							if aggregate_population_guarded_force_based_active:
								telemetry["order_neutral_population_projection_required"] = true
								telemetry["aggregate_body_application_required"] = true
								telemetry["per_actuator_attribution_required"] = true
								if joint_space_effective_inertia_population_guarded_force_based_active:
									telemetry[
										"joint_space_effective_inertia_population_projection_required"
									] = true
									telemetry[
										"joint_space_effective_inertia_guard_engaged"
									] = bool(projection["joint_space_effective_inertia_guard_engaged"])
								elif joint_target_monotone_population_guarded_force_based_active:
									telemetry[
										"joint_target_monotone_population_projection_required"
									] = true
									telemetry["joint_target_monotone_guard_engaged"] = bool(
										projection["joint_target_monotone_guard_engaged"]
									)
		else:
			var telemetry_value: Variant = (
				JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
			)
			var work_projection := native_motor_work_projection_v1(
				telemetry_value,
				actuator_id,
			)
			if not bool(work_projection.get("ok", false)):
				return work_projection
			telemetry_value = work_projection["telemetry"]
			var telemetry_contract := native_motor_telemetry_contract_v2(
				telemetry_value,
				actuator_id,
				cap,
				bool(application_intent.get("zero_command", false)),
				native_space_step_sequence,
				solver_step_s,
			)
			if not bool(telemetry_contract.get("ok", false)):
				return telemetry_contract
			telemetry = telemetry_contract["telemetry"]
			read_sequence = int(telemetry_contract["read_space_step_sequence"])
			capture_sequence = int(telemetry_contract["capture_space_step_sequence"])
			current_step_s = float(telemetry_contract["solver_step_s"])
			signed_impulse = float(telemetry_contract["signed_motor_impulse_nms"])
			positive_work = float(telemetry_contract["positive_motor_work_j"])
			absorbed_work = float(telemetry_contract["absorbed_motor_work_j"])
			net_work = float(telemetry_contract["net_motor_work_j"])
			native_net_work = float(telemetry.get("native_net_motor_work_j", net_work))
			net_work_projection_delta = float(
				telemetry.get("net_motor_work_projection_delta_j", 0.0)
			)
		native_space_step_sequence = read_sequence
		solver_step_s = current_step_s
		step_actuator_work_j += net_work
		telemetry_by_actuator_id[actuator_id] = telemetry.duplicate(true)
		ordered_applied_impulses.append(
			{
				"actuator_id": actuator_id,
				"applied_angular_impulse_nms": signed_impulse,
				"host_clamped": false,
			}
		)
		var telemetry_receipt := {
			"actuator_id": actuator_id,
			"joint_id": joint_id,
			"read_space_step_sequence": read_sequence,
			"capture_space_step_sequence": capture_sequence,
			"solver_step_s": current_step_s,
			"signed_motor_impulse_nms": signed_impulse,
			"positive_motor_work_j": positive_work,
			"absorbed_motor_work_j": absorbed_work,
			"net_motor_work_j": net_work,
			"native_net_motor_work_j": native_net_work,
			"net_motor_work_projection_delta_j": net_work_projection_delta,
			"net_motor_work_projection_schema": String(
				telemetry.get("net_motor_work_projection_schema", "")
			),
		}
		if force_based_active:
			telemetry_receipt["actuator_mapping_id"] = (
				selected_force_based_actuator_mapping_id
			)
			telemetry_receipt["work_mapping_id"] = selected_force_based_work_mapping_id
			telemetry_receipt["pre_relative_velocity_rad_s"] = float(
				telemetry["pre_relative_velocity_rad_s"]
			)
			telemetry_receipt["post_relative_velocity_rad_s"] = float(
				telemetry["post_relative_velocity_rad_s"]
			)
			telemetry_receipt["centered_relative_velocity_rad_s"] = float(
				telemetry["centered_relative_velocity_rad_s"]
			)
			telemetry_receipt["impulse_saturated"] = bool(
				telemetry["impulse_saturated"]
			)
			telemetry_receipt["mechanical_energy_residual_used_as_work_source"] = false
			if guarded_force_based_active:
				telemetry_receipt["native_angular_velocity_guard_engaged"] = bool(
					telemetry["native_angular_velocity_guard_engaged"]
				)
				telemetry_receipt["native_angular_velocity_guard_applied_scale"] = float(
					telemetry["native_angular_velocity_guard_applied_scale"]
				)
				telemetry_receipt["native_angular_velocity_readback"] = telemetry[
					"native_angular_velocity_readback"
				]
				if nested_guarded_force_based_active:
					telemetry_receipt[
						"native_angular_velocity_projection_target_engaged"
					] = bool(telemetry["native_angular_velocity_projection_target_engaged"])
					telemetry_receipt[
						"angular_velocity_projection_target_limit_rad_s"
					] = float(telemetry["angular_velocity_projection_target_limit_rad_s"])
					if component_norm_nested_guarded_force_based_active:
						telemetry_receipt["numeric_predicate_id"] = (
							COMPONENT_NORM_NUMERIC_PREDICATE_ID
						)
						telemetry_receipt[
							"component_norm_numeric_predicate_required"
						] = true
						if refinement_safe_guard_required:
							telemetry_receipt["refinement_safe_guard_required"] = true
						if aggregate_population_guarded_force_based_active:
							telemetry_receipt["order_neutral_population_projection_required"] = true
							telemetry_receipt["aggregate_body_application_required"] = true
							telemetry_receipt["per_actuator_attribution_required"] = true
							if joint_space_effective_inertia_population_guarded_force_based_active:
								telemetry_receipt[
									"joint_space_effective_inertia_population_projection_required"
								] = true
								telemetry_receipt[
									"joint_space_effective_inertia_guard_engaged"
								] = bool(telemetry["joint_space_effective_inertia_guard_engaged"])
							elif joint_target_monotone_population_guarded_force_based_active:
								telemetry_receipt[
									"joint_target_monotone_population_projection_required"
								] = true
								telemetry_receipt["joint_target_monotone_guard_engaged"] = bool(
									telemetry["joint_target_monotone_guard_engaged"]
								)
		elif solver_coupled_complete_energy_profile:
			telemetry_receipt["actuator_mapping_id"] = (
				R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
			)
			telemetry_receipt["work_mapping_id"] = (
				R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
			)
			telemetry_receipt["source_measurement"] = true
			telemetry_receipt["mechanical_energy_residual_used_as_work_source"] = false
		ordered_telemetry_receipts.append(telemetry_receipt)
	if (
		guarded_force_based_active
		and (
			observed_guard_engagement_count
			!= int(application_intent["native_angular_velocity_guard_engagement_count"])
			or observed_guard_minimum_applied_scale
			!= float(
				application_intent["native_angular_velocity_guard_minimum_applied_scale"]
			)
			or observed_guard_post_application_readback_count
			!= int(
				application_intent["native_angular_velocity_post_application_readback_count"]
			)
		)
	):
		return _failure("QSDK_R24D94_WORLD_GUARD_POPULATION_RECONCILIATION_FAILED")
	if (
		native_space_step_sequence <= int(model.get("last_native_space_step_sequence", 0))
		or absf(solver_step_s - OUTER_STEP_DURATION_S) > 1.0e-9
	):
		return _failure("QSDK_R24D57_WORLD_NATIVE_STEP_SEQUENCE_INVALID")

	var complete_energy_inputs_receipt: Dictionary = {}
	var complete_energy_inputs_receipt_sha256 := ""
	var solver_energy_exchange_receipt: Dictionary = {}
	var solver_energy_exchange_receipt_sha256 := ""
	var solver_coupled_partition_receipt: Dictionary = {}
	var solver_coupled_partition_receipt_sha256 := ""
	if complete_energy_profile:
		var ordered_body_energy_readbacks: Array = []
		for body_id_value in ORDERED_BODY_IDS:
			var body_id := String(body_id_value)
			var body: RigidBody3D = model["body_nodes"][body_id]
			var snapshot: Dictionary = snapshots[body_id]
			ordered_body_energy_readbacks.append(
				{
					"body_id": body_id,
					"total_gravity_world_m_s2": snapshot["total_gravity_world_m_s2"],
					"linear_damp_mode": int(body.linear_damp_mode),
					"angular_damp_mode": int(body.angular_damp_mode),
					"linear_damp": float(body.linear_damp),
					"angular_damp": float(body.angular_damp),
					"continuous_cd": bool(body.continuous_cd),
				}
			)
		var ordered_joint_energy_readbacks: Array = []
		for joint_id_value in ORDERED_JOINT_IDS:
			var joint_id := String(joint_id_value)
			var joint: HingeJoint3D = model["joint_nodes"][joint_id]
			ordered_joint_energy_readbacks.append(
				{
					"joint_id": joint_id,
					"motor_enabled": bool(
						joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
					),
				}
			)
		var complete_energy_inputs := {
			"semantic_step": semantic_step,
			"ordered_body_readbacks": ordered_body_energy_readbacks,
			"ordered_joint_readbacks": ordered_joint_energy_readbacks,
			"no_actuation_requested": bool(
				application_intent.get("no_actuation_requested", false)
			),
			"actuator_mapping_id": actuator_mapping_id,
			"work_mapping_id": String(application_intent.get("work_mapping_id", "")),
			"step_actuator_work_j": step_actuator_work_j,
			"external_intervention_event_count": 0,
			"step_signed_external_work_j": 0.0,
			"adapter_side_discrete_staging_event_count": int(
				application_intent.get(
					"adapter_side_discrete_staging_event_count",
					-1,
				)
			),
			"step_signed_discrete_staging_exchange_j": 0.0,
		}
		complete_energy_inputs_receipt = (
			solver_coupled_complete_energy_partition_inputs_contract_v1(
				complete_energy_inputs
			)
			if solver_coupled_complete_energy_profile
			else complete_energy_partition_inputs_contract_v1(complete_energy_inputs)
		)
		if not bool(complete_energy_inputs_receipt.get("ok", false)):
			return complete_energy_inputs_receipt
		complete_energy_inputs_receipt_sha256 = _sha256(
			sdk, complete_energy_inputs_receipt
		)
		var torso: RigidBody3D = model["body_nodes"]["torso"]
		var world_3d: World3D = torso.get_world_3d()
		if world_3d == null:
			return _failure("QSDK_R24D136_SOLVER_ENERGY_SPACE_MISSING")
		var solver_energy_telemetry: Variant = ClassDB.class_call_static(
			&"JoltPhysicsServer3D",
			&"space_get_solver_energy_exchange_telemetry",
			world_3d.space,
		)
		solver_energy_exchange_receipt = native_solver_energy_exchange_for_recovery_route_v2(
			context,
			solver_energy_telemetry,
			native_space_step_sequence,
			_vec3(complete_energy_inputs_receipt["uniform_gravity_world_m_s2"]),
		)
		if not bool(solver_energy_exchange_receipt.get("ok", false)):
			return solver_energy_exchange_receipt
		solver_energy_exchange_receipt_sha256 = _sha256(
			sdk, solver_energy_exchange_receipt
		)
		if solver_coupled_complete_energy_profile:
			solver_coupled_partition_receipt = (
				solver_coupled_complete_energy_partition_for_recovery_route_v2(
					context,
					solver_energy_exchange_receipt,
					ordered_telemetry_receipts,
					step_actuator_work_j,
					native_space_step_sequence,
				)
			)
			if not bool(solver_coupled_partition_receipt.get("ok", false)):
				return solver_coupled_partition_receipt
			solver_coupled_partition_receipt_sha256 = _sha256(
				sdk, solver_coupled_partition_receipt
			)
		if (
			complete_energy_inputs_receipt_sha256.is_empty()
			or solver_energy_exchange_receipt_sha256.is_empty()
			or (
				solver_coupled_complete_energy_profile
				and solver_coupled_partition_receipt_sha256.is_empty()
			)
		):
			return _failure(
				"QSDK_R24D144_COMPLETE_ENERGY_SOURCE_DIGEST_FAILED"
				if solver_coupled_complete_energy_profile
				else "QSDK_R24D136_COMPLETE_ENERGY_SOURCE_DIGEST_FAILED"
			)

	var contact_receipt := _measure_contacts_v1(
		model,
		snapshots,
		semantic_step,
		native_space_step_sequence,
	)
	if not bool(contact_receipt.get("ok", false)):
		return contact_receipt
	var state_receipt := _measure_state_v1(context, model, snapshots, contact_receipt, semantic_step, source_task)
	if not bool(state_receipt.get("ok", false)):
		return state_receipt
	var current_mechanical_energy_j := _mechanical_energy_j(model, snapshots)
	if not is_finite(current_mechanical_energy_j):
		return _failure("QSDK_R24D57_WORLD_CURRENT_ENERGY_INVALID")
	var initial_mechanical_energy_value: Variant = model.get("initial_mechanical_energy_j")
	if initial_mechanical_energy_value == null:
		initial_mechanical_energy_value = _initial_mechanical_energy_j(model, snapshots)
		if not is_finite(float(initial_mechanical_energy_value)):
			return _failure("QSDK_R24D57_WORLD_INITIAL_ENERGY_INVALID")
		model["initial_mechanical_energy_j"] = float(initial_mechanical_energy_value)
	model["cumulative_applied_actuator_work_j"] = (
		float(model.get("cumulative_applied_actuator_work_j", 0.0)) + step_actuator_work_j
	)
	if not is_finite(float(model["cumulative_applied_actuator_work_j"])):
		return _failure("QSDK_R24D57_WORLD_CUMULATIVE_WORK_INVALID")
	if complete_energy_profile:
		var step_signed_constraint_exchange_j := float(
			(
				solver_coupled_partition_receipt
				if solver_coupled_complete_energy_profile
				else solver_energy_exchange_receipt
			)["step_signed_constraint_exchange_j"]
		)
		model["cumulative_signed_constraint_exchange_j"] = (
			float(model.get("cumulative_signed_constraint_exchange_j", NAN))
			+ step_signed_constraint_exchange_j
		)
		if not is_finite(float(model["cumulative_signed_constraint_exchange_j"])):
			return _failure("QSDK_R24D136_CUMULATIVE_CONSTRAINT_EXCHANGE_INVALID")

	var telemetry_source_receipt := {
		"schema_version": (
			"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_actuator_source_v1"
			if joint_space_effective_inertia_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_actuator_source_v1"
			if joint_target_monotone_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_actuator_source_v1"
			if order_neutral_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_actuator_source_v1"
			if refinement_safe_component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d99_godot_component_norm_nested_guarded_force_based_actuator_source_v1"
			if component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d96_godot_nested_guarded_force_based_actuator_source_v1"
			if r96_nested_guarded_force_based_active
			else "sporespore_qsdk_r24d94_godot_guarded_force_based_actuator_source_v1"
			if r94_guarded_force_based_active
			else "sporespore_qsdk_r24d87_godot_force_based_actuator_source_v1"
			if legacy_force_based_active
			else "sporespore_qsdk_r24d57_godot_motor_telemetry_source_v1"
		),
		"semantic_step": semantic_step,
		"native_space_step_sequence": native_space_step_sequence,
		"ordered_telemetry": ordered_telemetry_receipts,
		"step_net_motor_work_j": step_actuator_work_j,
		"source_measurement": true,
	}
	if solver_coupled_complete_energy_profile:
		telemetry_source_receipt["schema_version"] = (
			"sporespore_qsdk_r24d144_godot_solver_coupled_native_motor_actuator_source_v1"
		)
		telemetry_source_receipt["actuator_mapping_id"] = (
			R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
		)
		telemetry_source_receipt["work_mapping_id"] = (
			R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
		)
		telemetry_source_receipt["partition_rule_id"] = (
			R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
		)
		telemetry_source_receipt["work_equation"] = (
			"sum_of_current_step_native_hinge_motor_net_work_j"
		)
		telemetry_source_receipt["whole_joint_exchange_includes_motor_work"] = true
		telemetry_source_receipt["mechanical_energy_residual_used_as_work_source"] = false
	if force_based_active:
		telemetry_source_receipt["actuator_mapping_id"] = (
			selected_force_based_actuator_mapping_id
		)
		telemetry_source_receipt["work_mapping_id"] = selected_force_based_work_mapping_id
		telemetry_source_receipt["hard_constraint_velocity_motor_enabled_count"] = 0
		telemetry_source_receipt["body_impulse_write_count"] = int(
			application_intent.get("body_impulse_write_count", -1)
		)
		telemetry_source_receipt["work_equation"] = (
			"applied_signed_joint_impulse_times_centered_pre_post_relative_velocity"
		)
		telemetry_source_receipt["mechanical_energy_residual_used_as_work_source"] = false
		if guarded_force_based_active:
			telemetry_source_receipt["native_angular_velocity_guard_required"] = true
			telemetry_source_receipt["native_angular_velocity_guard_engagement_count"] = int(
				application_intent["native_angular_velocity_guard_engagement_count"]
			)
			telemetry_source_receipt["native_angular_velocity_guard_minimum_applied_scale"] = float(
				application_intent["native_angular_velocity_guard_minimum_applied_scale"]
			)
			telemetry_source_receipt["all_immediate_native_readbacks_inside_guard"] = true
			if nested_guarded_force_based_active:
				telemetry_source_receipt[
					"native_angular_velocity_nested_projection_required"
				] = true
				telemetry_source_receipt[
					"native_angular_velocity_inner_projection_target"
				] = application_intent[
					"native_angular_velocity_inner_projection_target"
				]
				if component_norm_nested_guarded_force_based_active:
					telemetry_source_receipt["numeric_predicate_id"] = (
						COMPONENT_NORM_NUMERIC_PREDICATE_ID
					)
					telemetry_source_receipt[
						"component_norm_numeric_predicate_required"
					] = true
					if refinement_safe_guard_required:
						telemetry_source_receipt["refinement_safe_guard_required"] = true
					if aggregate_population_guarded_force_based_active:
						telemetry_source_receipt["order_neutral_population_projection_required"] = true
						telemetry_source_receipt["aggregate_body_application_required"] = true
						telemetry_source_receipt["per_actuator_attribution_required"] = true
						telemetry_source_receipt[
							"order_neutral_population_native_angular_velocity_readback"
						] = order_neutral_population_readback
						if joint_space_effective_inertia_population_guarded_force_based_active:
							telemetry_source_receipt[
								"joint_space_effective_inertia_population_projection_required"
							] = true
							telemetry_source_receipt[
								"joint_space_effective_inertia_population_guard_projection"
							] = joint_space_effective_inertia_population_projection
							telemetry_source_receipt[
								"joint_space_effective_inertia_common_pre_scale"
							] = float(
								joint_space_effective_inertia_population_projection[
									"joint_space_common_pre_scale"
								]
							)
							telemetry_source_receipt["body_guard_common_applied_scale"] = float(
								joint_space_effective_inertia_population_projection[
									"body_guard_common_applied_scale"
								]
							)
							telemetry_source_receipt["representation_refinement_count"] = int(
								joint_space_effective_inertia_population_projection[
									"representation_refinement_count"
								]
							)
							telemetry_source_receipt["all_joint_target_errors_nonincreasing"] = true
							telemetry_source_receipt["joint_target_crossing_count"] = 0
						elif joint_target_monotone_population_guarded_force_based_active:
							telemetry_source_receipt[
								"joint_target_monotone_population_projection_required"
							] = true
							telemetry_source_receipt[
								"joint_target_monotone_population_guard_projection"
							] = joint_target_monotone_population_projection
							telemetry_source_receipt[
								"joint_target_monotone_common_pre_scale"
							] = float(
								joint_target_monotone_population_projection[
									"target_common_pre_scale"
								]
							)
							telemetry_source_receipt["body_guard_common_applied_scale"] = float(
								joint_target_monotone_population_projection[
									"body_guard_common_applied_scale"
								]
							)
							telemetry_source_receipt[
								"population_zero_hold_for_nonhelpful_joint_delta"
							] = bool(
								joint_target_monotone_population_projection[
									"population_zero_hold_for_nonhelpful_joint_delta"
								]
							)
							telemetry_source_receipt["all_joint_target_errors_nonincreasing"] = true
							telemetry_source_receipt["joint_target_crossing_count"] = 0
						else:
							telemetry_source_receipt[
								"order_neutral_population_guard_projection"
							] = order_neutral_population_projection
	var telemetry_source_sha256 := _sha256(sdk, telemetry_source_receipt)
	var direct_state_source_sha256 := _sha256(sdk, state_receipt["direct_state_source_receipt"])
	var contact_source_retention := retain_contact_source_receipt_v1(
		sdk, contact_receipt
	)
	if not bool(contact_source_retention.get("ok", false)):
		return contact_source_retention
	var contact_source_receipt: Dictionary = (
		contact_source_retention["contact_source_receipt"]
	)
	var contact_source_sha256 := String(
		contact_source_retention["contact_source_sha256"]
	)
	if (
		telemetry_source_sha256.is_empty()
		or direct_state_source_sha256.is_empty()
		or contact_source_sha256.is_empty()
	):
		return _failure("QSDK_R24D57_WORLD_SOURCE_DIGEST_FAILED")
	var application_receipt := {
		"schema_version": (
			String(application_provenance["native_application_receipt_schema"])
			if solver_coupled_complete_energy_profile
			else
			"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_native_application_receipt_v1"
			if joint_space_effective_inertia_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_native_application_receipt_v1"
			if joint_target_monotone_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_native_application_receipt_v1"
			if order_neutral_population_guarded_force_based_active
			else
			"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_native_application_receipt_v1"
			if refinement_safe_component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d99_godot_component_norm_nested_guarded_force_based_native_application_receipt_v1"
			if component_norm_nested_guarded_force_based_active
			else
			"sporespore_qsdk_r24d96_godot_nested_guarded_force_based_native_application_receipt_v1"
			if r96_nested_guarded_force_based_active
			else "sporespore_qsdk_r24d94_godot_guarded_force_based_native_application_receipt_v1"
			if r94_guarded_force_based_active
			else "sporespore_qsdk_r24d87_godot_force_based_native_application_receipt_v1"
			if legacy_force_based_active
			else "sporespore_qsdk_r24d57_godot_native_application_receipt_v1"
		),
		"route_id": (
			String(application_provenance["route_id"])
			if solver_coupled_complete_energy_profile
			else ROUTE_ID
		),
		"world_route_id": (
			String(application_provenance["world_route_id"])
			if solver_coupled_complete_energy_profile
			else WORLD_ROUTE_ID
		),
		"semantic_step": semantic_step,
		"phase": phase,
		"command_id": String(application_intent["command_id"]),
		"command_sha256": String(application_intent["command_sha256"]),
		"zero_command": bool(application_intent["zero_command"]),
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"actuator_profile_sha256": ACTUATOR_PROFILE_SHA256,
		"ordered_applied_impulses": ordered_applied_impulses,
		"telemetry_source_sha256": telemetry_source_sha256,
		"step_actuator_work_j": step_actuator_work_j,
		"host_step_before": semantic_step - 1,
		"host_step_after": semantic_step,
		"native_space_step_sequence": native_space_step_sequence,
		"adapter_side_discrete_staging_event_count": 0,
		"source_measurement": true,
	}
	if solver_coupled_complete_energy_profile:
		application_receipt["energy_mapping_profile_id"] = (
			String(application_provenance["energy_mapping_profile_id"])
		)
		application_receipt["actuation_realization_id"] = String(
			application_intent["actuation_realization_id"]
		)
		application_receipt["bootstrap_application"] = bool(
			application_provenance["bootstrap_application"]
		)
		var application_mutation_semantics_id := String(
			application_provenance["application_mutation_semantics_id"]
		)
		if not application_mutation_semantics_id.is_empty():
			application_receipt["application_mutation_semantics_id"] = (
				application_mutation_semantics_id
			)
		application_receipt["actuator_mapping_id"] = actuator_mapping_id
		application_receipt["work_mapping_id"] = String(
			application_intent.get("work_mapping_id", "")
		)
		application_receipt["partition_rule_id"] = (
			R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
		)
		application_receipt["native_joint_motor_enabled_count"] = int(
			complete_energy_inputs_receipt.get("native_joint_motor_enabled_count", -1)
		)
		application_receipt["native_contact_solver_coupled"] = true
		application_receipt["pre_solver_direct_body_impulse_write_count"] = 0
		application_receipt["body_impulse_write_count"] = 0
		application_receipt["native_motor_work_partitioned_from_whole_joint_exchange"] = true
		application_receipt["solver_coupled_partition_receipt_sha256"] = (
			solver_coupled_partition_receipt_sha256
		)
		if route_aware_application_provenance:
			application_receipt["predecessor_complete_energy_route_id"] = (
				R144_COMPLETE_ENERGY_ROUTE_ID
			)
			application_receipt["predecessor_complete_energy_mapping_profile_id"] = (
				R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			)
			application_receipt["discrete_staging_complete_energy_profile_selected"] = true
			application_receipt["complete_energy_authority_profile_id"] = (
				R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			)
			application_receipt["application_provenance_profile_id"] = (
				R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
			)
	elif force_based_active:
		application_receipt["actuator_mapping_id"] = selected_force_based_actuator_mapping_id
		application_receipt["work_mapping_id"] = selected_force_based_work_mapping_id
		application_receipt["hard_constraint_velocity_motor_enabled_count"] = 0
		application_receipt["body_impulse_write_count"] = int(
			application_intent.get("body_impulse_write_count", -1)
		)
		if guarded_force_based_active:
			application_receipt["native_angular_velocity_guard_required"] = true
			application_receipt["native_angular_velocity_guard_engagement_count"] = int(
				application_intent["native_angular_velocity_guard_engagement_count"]
			)
			application_receipt["native_angular_velocity_guard_minimum_applied_scale"] = float(
				application_intent["native_angular_velocity_guard_minimum_applied_scale"]
			)
			application_receipt["native_angular_velocity_total_readback_count"] = int(
				application_intent["native_angular_velocity_total_readback_count"]
			)
			application_receipt["all_immediate_native_readbacks_inside_guard"] = true
			if nested_guarded_force_based_active:
				application_receipt[
					"native_angular_velocity_nested_projection_required"
				] = true
				application_receipt[
					"native_angular_velocity_inner_projection_target"
				] = application_intent[
					"native_angular_velocity_inner_projection_target"
				]
				if component_norm_nested_guarded_force_based_active:
					application_receipt["numeric_predicate_id"] = (
						COMPONENT_NORM_NUMERIC_PREDICATE_ID
					)
					application_receipt[
						"component_norm_numeric_predicate_required"
					] = true
					if refinement_safe_guard_required:
						application_receipt["refinement_safe_guard_required"] = true
					if aggregate_population_guarded_force_based_active:
						application_receipt["order_neutral_population_projection_required"] = true
						application_receipt["aggregate_body_application_required"] = true
						application_receipt["per_actuator_attribution_required"] = true
						application_receipt[
							"order_neutral_population_native_angular_velocity_readback"
						] = order_neutral_population_readback
						if joint_space_effective_inertia_population_guarded_force_based_active:
							application_receipt[
								"joint_space_effective_inertia_population_projection_required"
							] = true
							application_receipt[
								"joint_space_effective_inertia_population_guard_projection"
							] = joint_space_effective_inertia_population_projection
							application_receipt[
								"joint_space_effective_inertia_common_pre_scale"
							] = float(
								joint_space_effective_inertia_population_projection[
									"joint_space_common_pre_scale"
								]
							)
							application_receipt["body_guard_common_applied_scale"] = float(
								joint_space_effective_inertia_population_projection[
									"body_guard_common_applied_scale"
								]
							)
							application_receipt["representation_refinement_count"] = int(
								joint_space_effective_inertia_population_projection[
									"representation_refinement_count"
								]
							)
							application_receipt["all_joint_target_errors_nonincreasing"] = true
							application_receipt["joint_target_crossing_count"] = 0
						elif joint_target_monotone_population_guarded_force_based_active:
							application_receipt[
								"joint_target_monotone_population_projection_required"
							] = true
							application_receipt[
								"joint_target_monotone_population_guard_projection"
							] = joint_target_monotone_population_projection
							application_receipt[
								"joint_target_monotone_common_pre_scale"
							] = float(
								joint_target_monotone_population_projection[
									"target_common_pre_scale"
								]
							)
							application_receipt["body_guard_common_applied_scale"] = float(
								joint_target_monotone_population_projection[
									"body_guard_common_applied_scale"
								]
							)
							application_receipt[
								"population_zero_hold_for_nonhelpful_joint_delta"
							] = bool(
								joint_target_monotone_population_projection[
									"population_zero_hold_for_nonhelpful_joint_delta"
								]
							)
							application_receipt["all_joint_target_errors_nonincreasing"] = true
							application_receipt["joint_target_crossing_count"] = 0
						else:
							application_receipt[
								"order_neutral_population_guard_projection"
							] = order_neutral_population_projection
	var application_sha256 := _sha256(sdk, application_receipt)
	if application_sha256.is_empty():
		return _failure("QSDK_R24D57_WORLD_APPLICATION_DIGEST_FAILED")
	var source_trace := {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_source_trace_v1",
		"semantic_step": semantic_step,
		"host_step_before": semantic_step - 1,
		"host_step_after": semantic_step,
		"direct_state_callback_sequence": callback_sequence,
		"native_space_step_sequence": native_space_step_sequence,
		"solver_step_s": solver_step_s,
		"direct_state_source_sha256": direct_state_source_sha256,
		"contact_source_sha256": contact_source_sha256,
		"telemetry_source_sha256": telemetry_source_sha256,
		"source_measurement": true,
	}
	if complete_energy_profile:
		source_trace["schema_version"] = (
			String(application_provenance["native_source_trace_schema"])
			if solver_coupled_complete_energy_profile
			else "sporespore_qsdk_r24d136_godot_complete_energy_native_source_trace_v1"
		)
		source_trace["complete_energy_inputs_receipt_sha256"] = (
			complete_energy_inputs_receipt_sha256
		)
		source_trace["solver_energy_exchange_receipt_sha256"] = (
			solver_energy_exchange_receipt_sha256
		)
		if solver_coupled_complete_energy_profile:
			source_trace["energy_route_id"] = String(application_provenance["route_id"])
			source_trace["energy_mapping_profile_id"] = (
				String(application_provenance["energy_mapping_profile_id"])
			)
			source_trace["solver_coupled_partition_receipt_sha256"] = (
				solver_coupled_partition_receipt_sha256
			)
			source_trace["partition_rule_id"] = (
				R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
			)
			if route_aware_application_provenance:
				source_trace["predecessor_complete_energy_route_id"] = (
					R144_COMPLETE_ENERGY_ROUTE_ID
				)
				source_trace["predecessor_complete_energy_mapping_profile_id"] = (
					R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
				)
				source_trace["application_provenance_profile_id"] = (
					R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
				)
				source_trace["complete_energy_authority_profile_id"] = (
					R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
				)
			if rotation_aware_energy_ledger_profile:
				source_trace["schema_version"] = (
					"sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_source_trace_v1"
				)
				source_trace["recovery_energy_ledger_profile_id"] = (
					R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				)
				source_trace["solver_energy_consumer_contract_schema_version"] = String(
					context["solver_energy_consumer_contract_schema_version"]
				)
				source_trace["solver_energy_telemetry_schema_version"] = String(
					context["solver_energy_telemetry_schema_version"]
				)
				source_trace["solver_energy_telemetry_profile_id"] = String(
					context["solver_energy_telemetry_profile_id"]
				)
				source_trace["rotation_integration_kinetic_exchange_j"] = float(
					solver_energy_exchange_receipt[
						"rotation_integration_kinetic_exchange_j"
					]
				)
				source_trace[
					"rotation_integration_exchange_included_exactly_once"
				] = true
	var source_trace_sha256 := _sha256(sdk, source_trace)
	if source_trace_sha256.is_empty():
		return _failure("QSDK_R24D57_WORLD_TRACE_DIGEST_FAILED")

	var observation_base: Dictionary = state_receipt["observation_base"]
	observation_base["applied_actuation"] = {
		"adapter_id": ADAPTER_ID,
		"adapter_receipt_sha256": application_sha256,
		"source_semantic_step": semantic_step,
		"command_id": String(application_intent["command_id"]),
		"command_sha256": String(application_intent["command_sha256"]),
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"actuator_profile_sha256": ACTUATOR_PROFILE_SHA256,
		"zero_command": bool(application_intent["zero_command"]),
		"ordered_applied_impulses": ordered_applied_impulses,
		"source_measurement": true,
	}
	observation_base["external_interventions"] = _zero_external_interventions_v1()
	var ownership_observation := controller_ownership_observation_v1(sdk, application_intent)
	if ownership_observation.get("ok") != true:
		return ownership_observation
	observation_base["controller_ownership"] = ownership_observation["observation"]
	observation_base["engine_step_identity"] = {
		"schema_version": "sporespore_recovery_engine_step_identity_v1",
		"source_kind": "native_post_step",
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": String(context["capability_sha256"]),
		"source_trace_sha256": source_trace_sha256,
		"semantic_step": semantic_step,
		"host_step_before": semantic_step - 1,
		"host_step_after": semantic_step,
		"native_solver_substep_count": 1,
		"post_step_observation": true,
		"engine_identity_exposed_to_policy": false,
	}
	var energy_source_receipt := {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_energy_source_receipt_v1",
		"semantic_step": semantic_step,
		"initial_mechanical_energy_j": float(model["initial_mechanical_energy_j"]),
		"current_mechanical_energy_j": current_mechanical_energy_j,
		"cumulative_applied_actuator_work_j": float(
			model["cumulative_applied_actuator_work_j"]
		),
		"cumulative_signed_external_work_j": 0.0,
		"cumulative_signed_constraint_exchange_j": 0.0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"unclosed_energy_residual_preserved": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"source_measurement": true,
	}
	if complete_energy_profile:
		var ledger_solver_exchange_receipt := (
			solver_coupled_partition_receipt
			if solver_coupled_complete_energy_profile
			else solver_energy_exchange_receipt
		)
		energy_source_receipt = {
			"schema_version": (
				"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_receipt_v1"
				if solver_coupled_complete_energy_profile
				else "sporespore_qsdk_r24d136_godot_complete_energy_source_receipt_v1"
			),
			"semantic_step": semantic_step,
			"initial_mechanical_energy_j": float(model["initial_mechanical_energy_j"]),
			"current_mechanical_energy_j": current_mechanical_energy_j,
			"cumulative_applied_actuator_work_j": float(
				model["cumulative_applied_actuator_work_j"]
			),
			"cumulative_signed_external_work_j": 0.0,
			"step_signed_constraint_exchange_j": float(
				ledger_solver_exchange_receipt["step_signed_constraint_exchange_j"]
			),
			"step_position_constraint_potential_exchange_j": float(
				ledger_solver_exchange_receipt[
					"position_constraint_potential_exchange_j"
				]
			),
			"cumulative_signed_constraint_exchange_j": float(
				model["cumulative_signed_constraint_exchange_j"]
			),
			"cumulative_signed_discrete_staging_exchange_j": 0.0,
			"cumulative_passive_dissipation_j": 0.0,
			"adapter_side_discrete_staging_event_count": 0,
			"solver_energy_exchange_receipt_sha256": (
				solver_energy_exchange_receipt_sha256
			),
			"world_energy_configuration_receipt_sha256": (
				complete_energy_inputs_receipt_sha256
			),
			"actuator_constraint_disjointness_receipt_sha256": (
				solver_coupled_partition_receipt_sha256
				if solver_coupled_complete_energy_profile
				else complete_energy_inputs_receipt_sha256
			),
			"constraint_exchange_partition_complete": true,
			"passive_dissipation_partition_complete": true,
			"component_partition_complete": true,
			"exact_balance_safety_authority": true,
			"unclosed_energy_residual_preserved": false,
			"mechanical_energy_residual_used_as_work_source": false,
			"residual_balancing_permitted": false,
			"source_measurement": true,
		}
		if solver_coupled_complete_energy_profile:
			energy_source_receipt["solver_coupled_partition_receipt_sha256"] = (
				solver_coupled_partition_receipt_sha256
			)
			energy_source_receipt["partition_rule_id"] = (
				R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
			)
			energy_source_receipt["raw_step_signed_solver_exchange_j"] = float(
				solver_coupled_partition_receipt["raw_step_signed_solver_exchange_j"]
			)
			energy_source_receipt["step_actuator_work_j"] = float(
				solver_coupled_partition_receipt["step_actuator_work_j"]
			)
			energy_source_receipt["native_motor_work_subtracted_exactly_once"] = true
			energy_source_receipt["motor_work_also_counted_as_constraint_exchange"] = false
			if rotation_aware_energy_ledger_profile:
				energy_source_receipt["schema_version"] = (
					"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_source_receipt_v1"
				)
				energy_source_receipt["recovery_energy_ledger_profile_id"] = (
					R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				)
				energy_source_receipt["solver_energy_consumer_contract_schema_version"] = String(
					context["solver_energy_consumer_contract_schema_version"]
				)
				energy_source_receipt["solver_energy_telemetry_schema_version"] = String(
					context["solver_energy_telemetry_schema_version"]
				)
				energy_source_receipt["solver_energy_telemetry_profile_id"] = String(
					context["solver_energy_telemetry_profile_id"]
				)
				energy_source_receipt[
					"rotation_integration_kinetic_exchange_j"
				] = float(
					solver_coupled_partition_receipt[
						"rotation_integration_kinetic_exchange_j"
					]
				)
				energy_source_receipt[
					"rotation_integration_exchange_included_exactly_once"
				] = true
	var component_receipts := {
		"schema_version": SOURCE_COMPONENT_RECEIPTS_SCHEMA,
		"semantic_step": semantic_step,
		"channel_count": 10,
		"application_receipt": application_receipt,
		"application_receipt_sha256": application_sha256,
		"direct_state_source_sha256": direct_state_source_sha256,
		"contact_source_receipt": contact_source_receipt,
		"contact_source_sha256": contact_source_sha256,
		"telemetry_source_receipt": telemetry_source_receipt,
		"telemetry_source_sha256": telemetry_source_sha256,
		"source_trace": source_trace,
		"source_measurement": true,
	}
	if complete_energy_profile:
		component_receipts["schema_version"] = (
			"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1"
			if solver_coupled_complete_energy_profile
			else "sporespore_qsdk_r24d136_godot_complete_energy_source_component_receipts_v1"
		)
		component_receipts["complete_energy_inputs_receipt"] = (
			complete_energy_inputs_receipt
		)
		component_receipts["complete_energy_inputs_receipt_sha256"] = (
			complete_energy_inputs_receipt_sha256
		)
		component_receipts["solver_energy_exchange_receipt"] = (
			solver_energy_exchange_receipt
		)
		component_receipts["solver_energy_exchange_receipt_sha256"] = (
			solver_energy_exchange_receipt_sha256
		)
		if solver_coupled_complete_energy_profile:
			component_receipts["solver_coupled_partition_receipt"] = (
				solver_coupled_partition_receipt
			)
			component_receipts["solver_coupled_partition_receipt_sha256"] = (
				solver_coupled_partition_receipt_sha256
			)
			if rotation_aware_energy_ledger_profile:
				component_receipts["schema_version"] = (
					"sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_source_component_receipts_v1"
				)
				component_receipts["recovery_energy_ledger_profile_id"] = (
					R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				)
				component_receipts[
					"rotation_integration_exchange_included_exactly_once"
				] = true
		component_receipts["component_partition_complete"] = true
		component_receipts["mechanical_energy_residual_used_as_work_source"] = false
	model["host_step_count"] = semantic_step
	model["last_native_space_step_sequence"] = native_space_step_sequence
	model["solver_step_count"] = semantic_step
	var result := {
		"schema_version": (
			"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_measurement_v1"
			if solver_coupled_complete_energy_profile
			else "sporespore_qsdk_r24d136_godot_complete_energy_native_measurement_v1"
			if complete_energy_profile
			else "sporespore_qsdk_r24d57_godot_native_measurement_v1"
		),
		"ok": true,
		"observation_base": observation_base,
		"energy_source_receipt": energy_source_receipt,
		"source_component_receipts": component_receipts,
		"native_engine_health_receipt": native_engine_health_receipt,
		"native_engine_health_receipt_sha256": native_engine_health_receipt_sha256,
		"native_runtime_observation_collection_executed": true,
		"model_construction_count": 1,
		"world_attempt_count": 1,
		"world_build_count": 1,
		"solver_step_count": semantic_step,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	# Opt-in R10H capture reuses the exact sample already hashed above. It does
	# not resample physics or alter any historical caller's receipt population.
	if model.get("development_retain_direct_state_source", false) == true:
		result["development_direct_state_source"] = state_receipt["direct_state_source_receipt"].duplicate(true)
	if discrete_staging_complete_energy_profile:
		result["schema_version"] = (
			"sporespore_qsdk_r24d149_godot_jolt_discrete_staging_native_predecessor_measurement_v1"
		)
		result["discrete_staging_boundary_capture"] = (
			discrete_staging_boundary_capture
		)
		if rotation_aware_energy_ledger_profile:
			result["schema_version"] = (
				"sporespore_qsdk_r24d162_godot_rotation_aware_recovery_energy_ledger_native_measurement_v1"
			)
			result["recovery_energy_ledger_profile_id"] = (
				R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			)
	return result


static func cleanup_world_v1(model: Dictionary) -> void:
	PhysicsServer3D.set_active(false)
	model["physics_server_active"] = false
	var cleanup_value: Variant = model.get("cleanup_node")
	if cleanup_value is Node:
		var cleanup: Node = cleanup_value
		if is_instance_valid(cleanup):
			cleanup.queue_free()


static func _initializer_readback_v1(
	sdk: Object,
	blueprint: Dictionary,
	body_nodes: Dictionary,
	joint_states: Dictionary,
) -> Dictionary:
	var projection := native_initializer_projection_contract_v2(sdk, blueprint)
	if not bool(projection.get("ok", false)):
		return _failure(
			"QSDK_R24D58_WORLD_INITIALIZER_NATIVE_PROJECTION_INVALID",
			{"projection": projection},
		)
	var ordered_body_readbacks: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body: RigidBody3D = body_nodes[body_id]
		var expected_position: Vector3 = blueprint["positions"][body_id]
		var expected_basis: Basis = blueprint["bases"][body_id]
		var q_actual := body.basis.get_rotation_quaternion().normalized()
		var q_expected := expected_basis.get_rotation_quaternion().normalized()
		var quaternion_error := minf(
			Vector4(q_actual.x, q_actual.y, q_actual.z, q_actual.w).distance_to(
				Vector4(q_expected.x, q_expected.y, q_expected.z, q_expected.w)
			),
			Vector4(q_actual.x, q_actual.y, q_actual.z, q_actual.w).distance_to(
				-Vector4(q_expected.x, q_expected.y, q_expected.z, q_expected.w)
			),
		)
		if (
			body.position.distance_to(expected_position) > INITIALIZER_READBACK_TOLERANCE
			or quaternion_error > INITIALIZER_READBACK_TOLERANCE
			or body.linear_velocity.length() > INITIALIZER_READBACK_TOLERANCE
			or body.angular_velocity.length() > INITIALIZER_READBACK_TOLERANCE
		):
			return _failure("QSDK_R24D57_WORLD_INITIALIZER_BODY_MISMATCH:%s" % body_id)
		ordered_body_readbacks.append(
			{
				"body_id": body_id,
				"translation_m": _vector_json(body.position),
				"orientation_xyzw": _quaternion_json(q_actual),
			}
		)
	var ordered_joint_positions: Array = []
	var ordered_joint_readbacks: Array = []
	var maximum_native_readback_error_rad := 0.0
	for index in range(ORDERED_JOINT_IDS.size()):
		var joint_id_value: Variant = ORDERED_JOINT_IDS[index]
		var joint_id := String(joint_id_value)
		var state: Dictionary = joint_states[joint_id]
		var angle := _joint_angle_rad(state)
		var authored := float(
			(blueprint["initializer_manifest"] as Dictionary)[
				"ordered_joint_positions_rad"
			][index]
		)
		var projected := float(
			(projection["ordered_joint_projections"] as Array)[index][
				"native_projected_joint_angle_rad"
			]
		)
		var readback_error := absf(angle - projected)
		maximum_native_readback_error_rad = maxf(
			maximum_native_readback_error_rad, readback_error
		)
		if (
			not is_finite(angle)
			or readback_error > INITIALIZER_READBACK_TOLERANCE
		):
			return _failure(
				"QSDK_R24D57_WORLD_INITIALIZER_JOINT_MISMATCH:%s" % joint_id,
				{
					"projection_profile_id": INITIALIZER_NATIVE_PROJECTION_PROFILE_ID,
					"joint_id": joint_id,
					"authored_joint_angle_rad": authored,
					"native_projected_joint_angle_rad": projected,
					"native_readback_joint_angle_rad": angle,
					"authored_to_native_projection_delta_rad": projected - authored,
					"native_projection_to_readback_error_rad": readback_error,
					"readback_tolerance_rad": INITIALIZER_READBACK_TOLERANCE,
				},
			)
		ordered_joint_positions.append(angle)
		ordered_joint_readbacks.append(
			{
				"joint_id": joint_id,
				"authored_joint_angle_rad": authored,
				"native_projected_joint_angle_rad": projected,
				"native_readback_joint_angle_rad": angle,
				"authored_to_native_projection_delta_rad": projected - authored,
				"native_projection_to_readback_error_rad": readback_error,
			}
		)
	var receipt := {
		"schema_version": "sporespore_qsdk_r24d57_godot_initializer_readback_v1",
		"initializer_manifest_sha256": String(blueprint["initializer_manifest_sha256"]),
		"native_projection_sha256": String(projection["sha256"]),
		"projection_profile_id": INITIALIZER_NATIVE_PROJECTION_PROFILE_ID,
		"readback_tolerance_rad": INITIALIZER_READBACK_TOLERANCE,
		"ordered_body_readbacks": ordered_body_readbacks,
		"ordered_joint_ids": ORDERED_JOINT_IDS.duplicate(),
		"ordered_joint_positions_rad": ordered_joint_positions,
		"ordered_joint_readbacks": ordered_joint_readbacks,
		"maximum_native_projection_to_readback_error_rad": (
			maximum_native_readback_error_rad
		),
		"body_readback_count": 9,
		"joint_readback_count": 8,
		"writes_completed_before_first_solver_step": true,
	}
	var digest := _sha256(sdk, receipt)
	if digest.is_empty():
		return _failure("QSDK_R24D57_WORLD_INITIALIZER_READBACK_DIGEST_FAILED")
	receipt["sha256"] = digest
	receipt["ok"] = true
	return receipt


## Project the immutable engine-neutral joint-angle manifest through the exact
## Godot Basis representation that constructs the native pose. This is a pure
## zero-world representation contract: no Node, RID, model, or world is made.
## The existing 1e-8 readback tolerance is unchanged; only its comparison
## target becomes the native projection rather than the pre-projection decimal.
static func native_initializer_scalar_projection_v1(
	parent_basis: Basis, authored_joint_angle_rad: float
) -> Dictionary:
	if not parent_basis.is_finite() or not is_finite(authored_joint_angle_rad):
		return _failure("QSDK_R24D58_INITIALIZER_SCALAR_PROJECTION_NONFINITE")
	var child_basis := (
		parent_basis * Basis(Vector3.BACK, authored_joint_angle_rad)
	).orthonormalized()
	var projected := _signed_relative_angle_z(parent_basis, child_basis)
	if not child_basis.is_finite() or not is_finite(projected):
		return _failure("QSDK_R24D58_INITIALIZER_SCALAR_PROJECTION_INVALID")
	return {
		"schema_version": (
			"sporespore_qsdk_r24d58_godot_initializer_scalar_projection_v1"
		),
		"ok": true,
		"projection_profile_id": INITIALIZER_NATIVE_PROJECTION_PROFILE_ID,
		"authored_joint_angle_rad": authored_joint_angle_rad,
		"native_projected_joint_angle_rad": projected,
		"authored_to_native_projection_delta_rad": (
			projected - authored_joint_angle_rad
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func native_initializer_projection_contract_v2(
	sdk: Object, blueprint: Dictionary
) -> Dictionary:
	if sdk == null or not bool(blueprint.get("ok", false)):
		return _failure("QSDK_R24D58_INITIALIZER_PROJECTION_INPUT_INVALID")
	var manifest_value: Variant = blueprint.get("initializer_manifest")
	var bases_value: Variant = blueprint.get("bases")
	var joints_value: Variant = blueprint.get("joint_by_id")
	if (
		not (manifest_value is Dictionary)
		or not (bases_value is Dictionary)
		or not (joints_value is Dictionary)
	):
		return _failure("QSDK_R24D58_INITIALIZER_PROJECTION_INPUT_MISSING")
	var manifest: Dictionary = manifest_value
	var bases: Dictionary = bases_value
	var joint_by_id: Dictionary = joints_value
	if (
		String(blueprint.get("initializer_manifest_sha256", ""))
		!= _sha256(sdk, manifest)
		or not _ordered_strings_equal(
			manifest.get("ordered_joint_ids"), ORDERED_JOINT_IDS
		)
		or not (manifest.get("ordered_joint_positions_rad") is Array)
		or (manifest["ordered_joint_positions_rad"] as Array).size() != 8
	):
		return _failure("QSDK_R24D58_INITIALIZER_PROJECTION_MANIFEST_INVALID")
	var ordered: Array = []
	for index in range(ORDERED_JOINT_IDS.size()):
		var joint_id := String(ORDERED_JOINT_IDS[index])
		var joint_value: Variant = joint_by_id.get(joint_id)
		if not (joint_value is Dictionary):
			return _failure(
				"QSDK_R24D58_INITIALIZER_PROJECTION_JOINT_MISSING:%s" % joint_id
			)
		var joint: Dictionary = joint_value
		var parent_id := String(joint.get("parent_body_id", ""))
		var child_id := String(joint.get("child_body_id", ""))
		if not bases.has(parent_id) or not bases.has(child_id):
			return _failure(
				"QSDK_R24D58_INITIALIZER_PROJECTION_BASIS_MISSING:%s" % joint_id
			)
		var parent_basis_value: Variant = bases[parent_id]
		var child_basis_value: Variant = bases[child_id]
		if not (parent_basis_value is Basis) or not (child_basis_value is Basis):
			return _failure(
				"QSDK_R24D58_INITIALIZER_PROJECTION_BASIS_INVALID:%s" % joint_id
			)
		var authored := float(manifest["ordered_joint_positions_rad"][index])
		var projected := _signed_relative_angle_z(
			parent_basis_value as Basis, child_basis_value as Basis
		)
		if not is_finite(authored) or not is_finite(projected):
			return _failure(
				"QSDK_R24D58_INITIALIZER_PROJECTION_NONFINITE:%s" % joint_id
			)
		ordered.append(
			{
				"joint_id": joint_id,
				"authored_joint_angle_rad": authored,
				"native_projected_joint_angle_rad": projected,
				"authored_to_native_projection_delta_rad": projected - authored,
			}
		)
	var receipt := {
		"schema_version": (
			"sporespore_qsdk_r24d58_godot_initializer_native_projection_v1"
		),
		"ok": true,
		"projection_profile_id": INITIALIZER_NATIVE_PROJECTION_PROFILE_ID,
		"initializer_manifest_sha256": String(
			blueprint["initializer_manifest_sha256"]
		),
		"ordered_joint_ids": ORDERED_JOINT_IDS.duplicate(),
		"ordered_joint_projections": ordered,
		"projection_count": ordered.size(),
		"authored_initializer_changed": false,
		"readback_tolerance_rad": INITIALIZER_READBACK_TOLERANCE,
		"readback_tolerance_changed_from_r24d57": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var digest := _sha256(sdk, receipt)
	if digest.is_empty():
		return _failure("QSDK_R24D58_INITIALIZER_PROJECTION_DIGEST_FAILED")
	receipt["sha256"] = digest
	return receipt


static func _measure_state_v1(
	context: Dictionary,
	model: Dictionary,
	snapshots: Dictionary,
	contacts: Dictionary,
	semantic_step: int,
	source_task: Dictionary = {},
) -> Dictionary:
	var torso_snapshot: Dictionary = snapshots["torso"]
	var torso_transform: Transform3D = torso_snapshot["transform"]
	var torso_linear: Vector3 = torso_snapshot["linear_velocity_world_m_s"]
	var torso_angular: Vector3 = torso_snapshot["angular_velocity_world_rad_s"]
	var ordered_joint_observations: Array = []
	for joint_id_value in ORDERED_JOINT_IDS:
		var joint_id := String(joint_id_value)
		var state: Dictionary = model["joint_states"][joint_id]
		var geometry := _joint_geometry_v1(state, snapshots)
		var angle := _joint_angle_from_snapshots(state, snapshots)
		var rate := _joint_rate_from_snapshots(state, snapshots)
		if not is_finite(angle) or not is_finite(rate) or not is_finite(float(geometry["anchor_error_m"])):
			return _failure("QSDK_R24D57_WORLD_JOINT_SAMPLE_NONFINITE:%s" % joint_id)
		ordered_joint_observations.append(
			{
				"joint_id": joint_id,
				"position_rad": angle,
				"velocity_rad_s": rate,
				"anchor_error_m": float(geometry["anchor_error_m"]),
				"validity": {"position": true, "velocity": true, "anchor_error": true},
			}
		)
	var gravity: Vector3 = torso_snapshot["total_gravity_world_m_s2"]
	var com := _center_of_mass_v1(model, snapshots)
	if not bool(com.get("ok", false)):
		return com
	var direct_state_rows: Array = []
	var orientation_by_body_id: Dictionary = {}
	var quaternion_projection_receipts: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var snapshot: Dictionary = snapshots[body_id]
		var transform: Transform3D = snapshot["transform"]
		var quaternion_projection := project_quaternion_to_unit_scalar_v1(
			transform.basis.get_rotation_quaternion()
		)
		if not bool(quaternion_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D66_WORLD_QUATERNION_PROJECTION_REFUSED:%s" % body_id,
				quaternion_projection,
			)
		orientation_by_body_id[body_id] = (
			quaternion_projection["orientation_xyzw"] as Dictionary
		).duplicate(true)
		var retained_projection := quaternion_projection.duplicate(true)
		retained_projection["body_id"] = body_id
		quaternion_projection_receipts.append(retained_projection)
		direct_state_rows.append(
			{
				"body_id": body_id,
				"callback_sequence": int(snapshot["callback_sequence"]),
				"position_world_m": _vector_json(transform.origin),
				"orientation_xyzw": (
					orientation_by_body_id[body_id] as Dictionary
				).duplicate(true),
				"linear_velocity_world_m_s": _vector_json(
					snapshot["linear_velocity_world_m_s"]
				),
				"angular_velocity_world_rad_s": _vector_json(
					snapshot["angular_velocity_world_rad_s"]
				),
				"mass_kg": float(snapshot["mass_kg"]),
			}
		)
	var direct_state_source := {
		"schema_version": "sporespore_qsdk_r24d57_godot_direct_state_source_v1",
		"semantic_step": semantic_step,
		"ordered_body_states": direct_state_rows,
		"gravity_world_m_s2": _vector_json(gravity),
		"source_measurement": true,
	}
	var observation_base := {
		"task_id": source_task.get("task_id", TASK_ID),
		"semantics_id": source_task.get("semantics_id", SEMANTICS_ID),
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"semantic_step": semantic_step,
		"outer_step_duration_s": OUTER_STEP_DURATION_S,
		"state": {
			"schema_version": "sporespore_state_frame_v1",
			"semantic_step": semantic_step,
			"sample_time_s": float(semantic_step) * OUTER_STEP_DURATION_S,
			"base_pose_world": {
				"position_m": _vector_json(torso_transform.origin),
				"orientation_xyzw": (
					orientation_by_body_id["torso"] as Dictionary
				).duplicate(true),
			},
			"base_twist_world": {
				"linear_velocity_m_s": _vector_json(torso_linear),
				"angular_velocity_rad_s": _vector_json(torso_angular),
			},
			"ordered_joint_observations": ordered_joint_observations,
			"ordered_contact_observations": contacts["ordered_contact_observations"],
			"previous_applied_actuation": null,
			"gravity_world_m_s2": _vector_json(gravity),
			"task_frame": {
				"origin_world_m": _vector_json(model["task_origin_world_m"]),
				"forward_axis_world_unit": _vector_json(Vector3.RIGHT),
				"lateral_axis_world_unit": _vector_json(Vector3.BACK),
				"up_axis_world_unit": _vector_json(Vector3.UP),
				"reference_yaw_rad": 0.0,
			},
			"adapter_capability_sha256": String(context["capability_sha256"]),
		},
		"center_of_mass": {
			"position_world_m": com["position_world_m"],
			"linear_velocity_world_m_s": com["linear_velocity_world_m_s"],
			"source_measurement": true,
		},
		"ordered_foot_bearing_observations": contacts[
			"ordered_foot_bearing_observations"
		],
		"ordered_body_clearance_observations": contacts[
			"ordered_body_clearance_observations"
		],
	}
	return {
		"ok": true,
		"observation_base": observation_base,
		"direct_state_source_receipt": direct_state_source,
		"quaternion_projection_receipts": quaternion_projection_receipts,
	}


## Validate the exact post-solve contact snapshot before any generic Godot
## contact sample is consumed. This pure function is shared by the physical
## sampler and the R71 zero-world mutation population.
static func native_solved_contact_telemetry_contract_v1(
	telemetry_value: Variant,
	expected_space_step_sequence: int,
) -> Dictionary:
	if not (telemetry_value is Dictionary):
		return _failure(
			"QSDK_R24D71_WORLD_SOLVED_CONTACT_TELEMETRY_MISSING",
			{
				"schema_version": SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA,
				"expected_space_step_sequence": expected_space_step_sequence,
				"telemetry_variant_type": type_string(typeof(telemetry_value)),
			},
		)
	var telemetry: Dictionary = telemetry_value
	var capture_sequence := int(telemetry.get("capture_space_step_sequence", -1))
	var read_sequence := int(telemetry.get("read_space_step_sequence", -1))
	var reported_manifold_count := int(telemetry.get("reported_manifold_count", -1))
	var reported_point_count := int(telemetry.get("reported_contact_point_count", -1))
	var exact_manifold_count := int(telemetry.get("exact_manifold_count", -1))
	var exact_point_count := int(telemetry.get("exact_contact_point_count", -1))
	var missing_manifold_count := int(telemetry.get("missing_manifold_count", -1))
	var ccd_only_manifold_count := int(telemetry.get("ccd_only_manifold_count", -1))
	var point_count_mismatch_count := int(telemetry.get("point_count_mismatch_count", -1))
	var nonfinite_impulse_count := int(telemetry.get("nonfinite_impulse_count", -1))
	var all_fields_present := telemetry.size() == SOLVED_CONTACT_TELEMETRY_FIELDS.size()
	for field_name in SOLVED_CONTACT_TELEMETRY_FIELDS:
		all_fields_present = all_fields_present and telemetry.has(field_name)
	var sequence_and_count_types_exact := true
	for field_name in [
		"capture_space_step_sequence",
		"read_space_step_sequence",
		"reported_manifold_count",
		"reported_contact_point_count",
		"exact_manifold_count",
		"exact_contact_point_count",
		"missing_manifold_count",
		"ccd_only_manifold_count",
		"point_count_mismatch_count",
		"nonfinite_impulse_count",
	]:
		sequence_and_count_types_exact = (
			sequence_and_count_types_exact
			and typeof(telemetry.get(field_name)) == TYPE_INT
		)
	var boolean_types_exact := true
	for field_name in [
		"captured_during_active_step",
		"snapshot_is_current_space_step",
		"complete",
	]:
		boolean_types_exact = (
			boolean_types_exact
			and typeof(telemetry.get(field_name)) == TYPE_BOOL
		)
	var ordered_invariant_ids: Array[String] = [
		"field_population_exact",
		"schema_exact",
		"profile_exact",
		"sequence_and_count_types_exact",
		"boolean_types_exact",
		"expected_space_step_sequence_positive",
		"capture_matches_expected_space_step_sequence",
		"read_matches_expected_space_step_sequence",
		"captured_during_active_step",
		"snapshot_is_current_space_step",
		"counts_nonnegative",
		"reported_exact_manifold_population_equal",
		"reported_exact_contact_point_population_equal",
		"missing_manifold_population_zero",
		"ccd_only_manifold_population_zero",
		"point_count_mismatch_population_zero",
		"nonfinite_impulse_population_zero",
		"native_completeness_true",
	]
	var invariant_results := {
		"field_population_exact": all_fields_present,
		"schema_exact": String(telemetry.get("schema", "")) == SOLVED_CONTACT_TELEMETRY_SCHEMA,
		"profile_exact": String(telemetry.get("profile_id", "")) == SOLVED_CONTACT_TELEMETRY_PROFILE_ID,
		"sequence_and_count_types_exact": sequence_and_count_types_exact,
		"boolean_types_exact": boolean_types_exact,
		"expected_space_step_sequence_positive": expected_space_step_sequence >= 1,
		"capture_matches_expected_space_step_sequence": capture_sequence == expected_space_step_sequence,
		"read_matches_expected_space_step_sequence": read_sequence == expected_space_step_sequence,
		"captured_during_active_step": bool(telemetry.get("captured_during_active_step", false)),
		"snapshot_is_current_space_step": bool(telemetry.get("snapshot_is_current_space_step", false)),
		"counts_nonnegative": (
			reported_manifold_count >= 0
			and reported_point_count >= 0
			and exact_manifold_count >= 0
			and exact_point_count >= 0
			and missing_manifold_count >= 0
			and ccd_only_manifold_count >= 0
			and point_count_mismatch_count >= 0
			and nonfinite_impulse_count >= 0
		),
		"reported_exact_manifold_population_equal": reported_manifold_count == exact_manifold_count,
		"reported_exact_contact_point_population_equal": reported_point_count == exact_point_count,
		"missing_manifold_population_zero": missing_manifold_count == 0,
		"ccd_only_manifold_population_zero": ccd_only_manifold_count == 0,
		"point_count_mismatch_population_zero": point_count_mismatch_count == 0,
		"nonfinite_impulse_population_zero": nonfinite_impulse_count == 0,
		"native_completeness_true": bool(telemetry.get("complete", false)),
	}
	for invariant_id in ordered_invariant_ids:
		if not bool(invariant_results[invariant_id]):
			return _failure(
				"QSDK_R24D71_WORLD_SOLVED_CONTACT_TELEMETRY_INVALID",
				{
					"schema_version": SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA,
					"first_failed_invariant_id": invariant_id,
					"ordered_invariant_ids": ordered_invariant_ids,
					"invariant_results": invariant_results,
					"expected_space_step_sequence": expected_space_step_sequence,
					"telemetry": telemetry.duplicate(true),
				},
			)
	return {
		"schema_version": SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA,
		"ok": true,
		"expected_space_step_sequence": expected_space_step_sequence,
		"reported_manifold_count": reported_manifold_count,
		"reported_contact_point_count": reported_point_count,
		"exact_manifold_count": exact_manifold_count,
		"exact_contact_point_count": exact_point_count,
		"telemetry": telemetry.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Retain the exact object whose digest already identifies the contact source.
## This is pure data work: the physical route and zero-world worker call the
## same function, and no model, world, RID, or step is constructed here.
static func retain_contact_source_receipt_v1(
	sdk: Object,
	contact_receipt_value: Variant,
) -> Dictionary:
	if not (contact_receipt_value is Dictionary):
		return _contact_source_retention_failure("contact_receipt_dictionary")
	var contact_receipt: Dictionary = contact_receipt_value
	var source_value: Variant = contact_receipt.get("source_receipt")
	if not (source_value is Dictionary):
		return _contact_source_retention_failure("source_receipt_dictionary")
	var source_receipt: Dictionary = source_value
	if String(source_receipt.get("schema_version", "")) not in [SOLVED_CONTACT_SOURCE_SCHEMA, DetectionFrameContacts.SOURCE_SCHEMA]:
		return _contact_source_retention_failure("source_schema_exact")
	if source_receipt.schema_version == DetectionFrameContacts.SOURCE_SCHEMA:
		var frame: Variant = source_receipt.get("contact_detection_frame")
		if not frame is Dictionary or frame.get("schema_version") != DetectionFrameContacts.FRAME_SCHEMA or frame.get("profile_id") != DetectionFrameContacts.PROFILE or frame.get("classification_scope") != "distal_foot_cap_only" or frame.get("native_space_step_sequence") != source_receipt.get("native_space_step_sequence"):
			return _contact_source_retention_failure("detection_frame_binding_exact")
	var contract_value: Variant = source_receipt.get("solved_contact_telemetry_contract")
	if not (contract_value is Dictionary):
		return _contact_source_retention_failure("solved_contract_dictionary")
	var solved_contract: Dictionary = contract_value
	if (
		String(solved_contract.get("schema_version", ""))
		!= SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA
	):
		return _contact_source_retention_failure("solved_contract_schema_exact")
	if not bool(solved_contract.get("ok", false)):
		return _contact_source_retention_failure("solved_contract_ok_true")
	if typeof(solved_contract.get("exact_contact_point_count")) != TYPE_INT:
		return _contact_source_retention_failure("exact_contact_point_count_int")
	var exact_contact_point_count := int(solved_contract["exact_contact_point_count"])
	if exact_contact_point_count < 0:
		return _contact_source_retention_failure("exact_contact_point_count_nonnegative")
	var retained_source_receipt := source_receipt.duplicate(true)
	var contact_source_sha256 := _sha256(sdk, retained_source_receipt)
	if contact_source_sha256.is_empty():
		return _contact_source_retention_failure("canonical_source_digest_valid")
	return {
		"schema_version": CONTACT_SOURCE_RETENTION_SCHEMA,
		"ok": true,
		"contact_source_receipt": retained_source_receipt,
		"contact_source_sha256": contact_source_sha256,
		"exact_contact_point_count": exact_contact_point_count,
	}


static func _contact_source_retention_failure(first_failed_invariant_id: String) -> Dictionary:
	return _failure(
		"QSDK_R24D75_WORLD_CONTACT_SOURCE_RETENTION_INVALID",
		{
			"schema_version": CONTACT_SOURCE_RETENTION_SCHEMA,
			"first_failed_invariant_id": first_failed_invariant_id,
		},
	)


static func _measure_contacts_v1(
	model: Dictionary,
	snapshots: Dictionary,
	semantic_step: int,
	native_space_step_sequence: int,
) -> Dictionary:
	var frame_selection := DetectionFrameContacts.selection_v1(model)
	if frame_selection.get("ok") != true:
		return frame_selection
	var detection_frame_selected: bool = frame_selection.selected
	var prepared_frame: Dictionary = {}
	var torso: RigidBody3D = model["body_nodes"]["torso"]
	var world_3d: World3D = torso.get_world_3d()
	if world_3d == null:
		return _failure("QSDK_R24D71_WORLD_SOLVED_CONTACT_SPACE_MISSING")
	var solved_contact_telemetry: Variant = (
		JoltPhysicsServer3D.space_get_solved_contact_telemetry(world_3d.space)
	)
	var solved_contact_contract := native_solved_contact_telemetry_contract_v1(
		solved_contact_telemetry,
		native_space_step_sequence,
	)
	if not bool(solved_contact_contract.get("ok", false)):
		return solved_contact_contract
	if detection_frame_selected:
		if not ClassDB.class_has_method(&"JoltPhysicsServer3D", &"space_get_contact_frames"):
			return _failure("R10AF_CONTACT_FRAME_NATIVE_METHOD_MISSING")
		var instances := {}
		var samples := {}
		for body_id in ORDERED_BODY_IDS:
			var source_body: RigidBody3D = model["body_nodes"][body_id]
			instances[body_id] = source_body.get_instance_id()
			samples[body_id] = source_body.get("latest_semantic_contact_samples")
		var frame_snapshot: Variant = ClassDB.class_call_static(&"JoltPhysicsServer3D", &"space_get_contact_frames", world_3d.space)
		prepared_frame = DetectionFrameContacts.prepare_v1(frame_snapshot, native_space_step_sequence,
			instances, model["floor"].get_instance_id(), samples)
		if prepared_frame.get("ok") != true:
			return prepared_frame
		if prepared_frame.native_point_count != solved_contact_contract.exact_contact_point_count:
			return _failure("R10AF_CONTACT_FRAME_SOLVED_POINT_COUNT")
	var foot_impulses: Dictionary = {}
	var foot_ids: Dictionary = {}
	for contact_id_value in ORDERED_CONTACT_SITE_IDS:
		foot_impulses[String(contact_id_value)] = 0.0
		foot_ids[String(contact_id_value)] = []
	var nonfoot_impulses: Dictionary = {}
	var nonfoot_ids: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		nonfoot_impulses[String(body_id_value)] = 0.0
		nonfoot_ids[String(body_id_value)] = []
	var torso_ventral_contact := false
	var ordered_contact_samples: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body: RigidBody3D = model["body_nodes"][body_id]
		var samples_value: Variant = body.get("latest_semantic_contact_samples")
		if not (samples_value is Array):
			return _failure("QSDK_R24D57_WORLD_CONTACT_SAMPLES_MISSING:%s" % body_id)
		var body_transform: Transform3D = (snapshots[body_id] as Dictionary)["transform"]
		for sample_index in range(samples_value.size()):
			var sample_value: Variant = samples_value[sample_index]
			if not (sample_value is Dictionary):
				return _failure("QSDK_R24D57_WORLD_CONTACT_SAMPLE_INVALID:%s" % body_id)
			var sample: Dictionary = sample_value
			if String(sample.get("counterparty_id", "")) != "floor":
				continue
			var point_value: Variant = sample.get("local_position_world_m")
			var normal_value: Variant = sample.get("local_normal_world_unit")
			var impulse_value: Variant = sample.get("raw_impulse_world_nms")
			if (
				not (point_value is Vector3)
				or not (normal_value is Vector3)
				or not (impulse_value is Vector3)
			):
				return _failure("QSDK_R24D57_WORLD_CONTACT_VECTOR_INVALID:%s" % body_id)
			var point_world: Vector3 = point_value
			var normal_world: Vector3 = normal_value
			var raw_impulse: Vector3 = impulse_value
			if (
				not point_world.is_finite()
				or not normal_world.is_finite()
				or not raw_impulse.is_finite()
				or normal_world.length_squared() <= 0.0
			):
				return _failure("QSDK_R24D57_WORLD_CONTACT_NONFINITE:%s" % body_id)
			var normal_impulse := absf(raw_impulse.dot(normal_world.normalized()))
			if normal_impulse == 0.0:
				continue
			var local_point := body_transform.affine_inverse() * point_world
			var engine_contact_id := String(sample.get("engine_contact_id", ""))
			if engine_contact_id.is_empty():
				return _failure("QSDK_R24D57_WORLD_CONTACT_ID_MISSING:%s" % body_id)
			var foot_site_value: Variant = model["blueprint"]["contact_by_body_id"].get(body_id)
			var classified_as_foot := false
			var frame_classification := {}
			if detection_frame_selected:
				frame_classification = DetectionFrameContacts.classify_v1(body_id, local_point, foot_site_value,
					prepared_frame.matches_by_body[body_id][sample_index])
				if frame_classification.get("ok") != true:
					return frame_classification
				classified_as_foot = frame_classification.classified_as_foot
			elif foot_site_value is Dictionary:
				var site: Dictionary = foot_site_value
				var site_center := _vec3(site["local_center_m"])
				classified_as_foot = local_point.y <= site_center.y + CONTACT_CLASSIFICATION_TOLERANCE_M
			if classified_as_foot:
				var site_id := String(foot_site_value["contact_site_id"])
				foot_impulses[site_id] = float(foot_impulses[site_id]) + normal_impulse
				(foot_ids[site_id] as Array).append(engine_contact_id)
			if not classified_as_foot:
				nonfoot_impulses[body_id] = float(nonfoot_impulses[body_id]) + normal_impulse
				(nonfoot_ids[body_id] as Array).append(engine_contact_id)
				if body_id == "torso":
					var torso_size := _vec3(
						(model["blueprint"]["body_by_id"]["torso"]["collision"] as Dictionary)[
							"size_m"
						]
					)
					torso_ventral_contact = torso_ventral_contact or (
						local_point.y <= -0.5 * torso_size.y + CONTACT_CLASSIFICATION_TOLERANCE_M
					)
			ordered_contact_samples.append(
				{
					"body_id": body_id,
					"engine_contact_id": engine_contact_id,
					"position_world_m": _vector_json(point_world),
					"position_body_local_m": _vector_json(local_point),
					"normal_impulse_ns": normal_impulse,
					"classified_as_foot": classified_as_foot,
				}
			)
			if detection_frame_selected:
				for field in ["classification_position_body_local_m", "detection_position_body_local_m", "native_point_index", "native_side"]:
					ordered_contact_samples[-1][field] = frame_classification[field]

	var ordered_contact_identity_projections: Array = []
	var ordered_contacts: Array = []
	var ordered_foot_bearings: Array = []
	for contact_id_value in ORDERED_CONTACT_SITE_IDS:
		var contact_id := String(contact_id_value)
		var raw_ids: Array = foot_ids[contact_id]
		var identity_projection := native_contact_identity_projection_v2(raw_ids)
		if not bool(identity_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D61_WORLD_FOOT_CONTACT_ID_PROJECTION_FAILED:%s:%s"
				% [contact_id, String(identity_projection.get("failure_code", "unknown"))]
			)
		var ids: Array = identity_projection["engine_contact_ids"]
		var impulse := float(foot_impulses[contact_id])
		var present := not ids.is_empty()
		ordered_contact_identity_projections.append(
			{
				"bucket_kind": "foot_site",
				"bucket_id": contact_id,
				"projection": identity_projection,
			}
		)
		ordered_contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": present,
				"bears_support": present and impulse > 0.0,
				"normal_load_n": null,
				"provenance": {
					"adapter_id": ADAPTER_ID,
					"engine_contact_ids": ids.duplicate(),
					"aggregation_rule_id": ("godot_jolt_detection_frame_distal_capsule_lower_cap_contact_v1" if detection_frame_selected else "godot_jolt_exact_post_solve_distal_capsule_lower_cap_contact_v1"),
					"quality": "qualified_bearing",
					"impulse_source_profile_id": SOLVED_CONTACT_TELEMETRY_PROFILE_ID,
					"impulse_source_kind": "native_post_solve_contact_constraint_lambda",
				},
			}
		)
		ordered_foot_bearings.append(
			{
				"contact_site_id": contact_id,
				"bearing_normal_impulse_ns": impulse,
				"ordinary_unilateral_contact": present,
				"source_measurement": true,
			}
		)
	var ordered_clearances: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var raw_ids: Array = nonfoot_ids[body_id]
		var identity_projection := native_contact_identity_projection_v2(raw_ids)
		if not bool(identity_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D61_WORLD_BODY_CONTACT_ID_PROJECTION_FAILED:%s:%s"
				% [body_id, String(identity_projection.get("failure_code", "unknown"))]
			)
		var ids: Array = identity_projection["engine_contact_ids"]
		var clearance := _body_nonfoot_clearance_m(model, snapshots, body_id)
		if not is_finite(clearance):
			return _failure("QSDK_R24D57_WORLD_CLEARANCE_NONFINITE:%s" % body_id)
		ordered_contact_identity_projections.append(
			{
				"bucket_kind": "body_nonfoot",
				"bucket_id": body_id,
				"projection": identity_projection,
			}
		)
		ordered_clearances.append(
			{
				"adapter_id": ADAPTER_ID,
				"body_id": body_id,
				"nonfoot_contact_present": not ids.is_empty(),
				"ventral_surface_contact": body_id == "torso" and torso_ventral_contact,
				"accumulated_nonfoot_normal_impulse_ns": float(nonfoot_impulses[body_id]),
				"minimum_nonfoot_clearance_m": clearance,
				"engine_contact_ids": ids.duplicate(),
				"classification_rule_id": ("godot_jolt_detection_frame_foot_cap_excluded_callback_clearance_v1" if detection_frame_selected else "godot_jolt_contact_and_foot_cap_excluded_clearance_v1"),
				"foot_site_contacts_excluded": true,
				"source_measurement": true,
			}
		)
	var source_receipt := {
		"schema_version": DetectionFrameContacts.SOURCE_SCHEMA if detection_frame_selected else SOLVED_CONTACT_SOURCE_SCHEMA,
		"semantic_step": semantic_step,
		"native_space_step_sequence": native_space_step_sequence,
		"solved_contact_telemetry_contract": solved_contact_contract,
		"ordered_contact_samples": ordered_contact_samples,
		"ordered_contact_identity_projections": ordered_contact_identity_projections,
		"source_measurement": true,
	}
	if detection_frame_selected:
		source_receipt["contact_detection_frame"] = prepared_frame.frame_binding
	return {
		"ok": true,
		"ordered_contact_observations": ordered_contacts,
		"ordered_foot_bearing_observations": ordered_foot_bearings,
		"ordered_body_clearance_observations": ordered_clearances,
		"source_receipt": source_receipt,
	}


static func _body_nonfoot_clearance_m(
	model: Dictionary,
	snapshots: Dictionary,
	body_id: String,
) -> float:
	var body_spec: Dictionary = model["blueprint"]["body_by_id"][body_id]
	var collision: Dictionary = body_spec["collision"]
	var transform: Transform3D = (snapshots[body_id] as Dictionary)["transform"]
	var kind := String(collision.get("kind", ""))
	if kind == "box":
		var size := _vec3(collision["size_m"])
		var half := size * 0.5
		return (
			transform.origin.y
			- absf(transform.basis.x.y) * half.x
			- absf(transform.basis.y.y) * half.y
			- absf(transform.basis.z.y) * half.z
		)
	if kind != "capsule":
		return NAN
	var radius := float(collision["radius_m"])
	var length := float(collision["length_m"])
	var axis_world := (transform.basis * Vector3.UP).normalized()
	var contact_value: Variant = model["blueprint"]["contact_by_body_id"].get(body_id)
	if contact_value is Dictionary:
		var site: Dictionary = contact_value
		var lower_center := transform * _vec3(site["local_center_m"])
		var upper_center := lower_center + axis_world * length
		var radial_vertical := radius * sqrt(maxf(0.0, 1.0 - axis_world.y * axis_world.y))
		var lower_seam_y := lower_center.y - radial_vertical
		var upper_cap_y := upper_center.y - radius
		return minf(lower_seam_y, upper_cap_y)
	var lower_cap_center := transform.origin - axis_world * (0.5 * length)
	var upper_cap_center := transform.origin + axis_world * (0.5 * length)
	return minf(lower_cap_center.y, upper_cap_center.y) - radius


static func _mechanical_energy_j(model: Dictionary, snapshots: Dictionary) -> float:
	var total := 0.0
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var snapshot: Dictionary = snapshots[body_id]
		var transform: Transform3D = snapshot["transform"]
		var linear: Vector3 = snapshot["linear_velocity_world_m_s"]
		var angular: Vector3 = snapshot["angular_velocity_world_rad_s"]
		var gravity: Vector3 = snapshot["total_gravity_world_m_s2"]
		var inverse_inertia: Basis = snapshot["inverse_inertia_tensor_world_kg_inv_m2"]
		var mass := float(snapshot["mass_kg"])
		if (
			not transform.origin.is_finite()
			or not linear.is_finite()
			or not angular.is_finite()
			or not gravity.is_finite()
			or not is_finite(mass)
			or mass <= 0.0
			or absf(inverse_inertia.determinant()) <= 1.0e-18
		):
			return NAN
		var inertia_world := inverse_inertia.inverse()
		var translational := 0.5 * mass * linear.length_squared()
		var rotational := 0.5 * angular.dot(inertia_world * angular)
		var potential := -mass * gravity.dot(transform.origin)
		total += translational + rotational + potential
	return total if is_finite(total) else NAN


static func _initial_mechanical_energy_j(model: Dictionary, snapshots: Dictionary) -> float:
	var gravity: Vector3 = (snapshots["torso"] as Dictionary)["total_gravity_world_m_s2"]
	var total := 0.0
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body_spec: Dictionary = model["blueprint"]["body_by_id"][body_id]
		var mass := float(body_spec["mass_kg"])
		var initial_position: Vector3 = model["blueprint"]["positions"][body_id]
		total += -mass * gravity.dot(initial_position)
	return total if is_finite(total) else NAN


static func _center_of_mass_v1(model: Dictionary, snapshots: Dictionary) -> Dictionary:
	var total_mass := 0.0
	var weighted_position := Vector3.ZERO
	var weighted_velocity := Vector3.ZERO
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var snapshot: Dictionary = snapshots[body_id]
		var mass := float(snapshot["mass_kg"])
		var transform: Transform3D = snapshot["transform"]
		var velocity: Vector3 = snapshot["linear_velocity_world_m_s"]
		if not is_finite(mass) or mass <= 0.0 or not transform.origin.is_finite() or not velocity.is_finite():
			return _failure("QSDK_R24D57_WORLD_COM_BODY_INVALID:%s" % body_id)
		total_mass += mass
		weighted_position += transform.origin * mass
		weighted_velocity += velocity * mass
	if not is_finite(total_mass) or total_mass <= 0.0:
		return _failure("QSDK_R24D57_WORLD_COM_MASS_INVALID")
	return {
		"ok": true,
		"position_world_m": _vector_json(weighted_position / total_mass),
		"linear_velocity_world_m_s": _vector_json(weighted_velocity / total_mass),
	}


static func _joint_angle_rad(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	return _signed_relative_angle_z(parent.basis, child.basis)


static func _joint_angle_from_snapshots(state: Dictionary, snapshots: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_id := String(parent.get_meta("lab_body_id"))
	var child_id := String(child.get_meta("lab_body_id"))
	var parent_transform: Transform3D = (snapshots[parent_id] as Dictionary)["transform"]
	var child_transform: Transform3D = (snapshots[child_id] as Dictionary)["transform"]
	return _signed_relative_angle_z(parent_transform.basis, child_transform.basis)


static func _signed_relative_angle_z(parent_basis: Basis, child_basis: Basis) -> float:
	var relative := (parent_basis.inverse() * child_basis).orthonormalized()
	return _signed_basis_angle_z(relative)


static func _signed_basis_angle_z(basis: Basis) -> float:
	var rotation := basis.get_rotation_quaternion().normalized()
	var angle := rotation.get_angle()
	if angle <= 1.0e-12:
		return 0.0
	return angle * signf(rotation.get_axis().dot(Vector3.BACK))


static func _joint_rate_from_snapshots(state: Dictionary, snapshots: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_id := String(parent.get_meta("lab_body_id"))
	var child_id := String(child.get_meta("lab_body_id"))
	var parent_snapshot: Dictionary = snapshots[parent_id]
	var child_snapshot: Dictionary = snapshots[child_id]
	var parent_transform: Transform3D = parent_snapshot["transform"]
	var axis_world := (parent_transform.basis * Vector3.BACK).normalized()
	return (
		(child_snapshot["angular_velocity_world_rad_s"] as Vector3)
		- (parent_snapshot["angular_velocity_world_rad_s"] as Vector3)
	).dot(axis_world)


static func _joint_geometry_v1(
	state: Dictionary,
	snapshots: Dictionary,
) -> Dictionary:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_id := String(parent.get_meta("lab_body_id"))
	var child_id := String(child.get_meta("lab_body_id"))
	var parent_transform: Transform3D = (snapshots[parent_id] as Dictionary)["transform"]
	var child_transform: Transform3D = (snapshots[child_id] as Dictionary)["transform"]
	var parent_anchor := parent_transform * (state["anchor_parent_local"] as Vector3)
	var child_anchor := child_transform * (state["anchor_child_local"] as Vector3)
	return {"anchor_error_m": parent_anchor.distance_to(child_anchor)}


static func _body_shape(body_spec: Dictionary, body_id: String) -> Dictionary:
	var collision_value: Variant = body_spec.get("collision")
	if not (collision_value is Dictionary):
		return {"ok": false}
	var collision: Dictionary = collision_value
	var shape_node := CollisionShape3D.new()
	shape_node.name = "%s_collision" % body_id
	shape_node.set_meta("lab_shape_id", body_id)
	var kind := String(collision.get("kind", ""))
	if kind == "box":
		var shape := BoxShape3D.new()
		shape.size = _vec3(collision.get("size_m"))
		shape.margin = COLLISION_MARGIN_M
		if not shape.size.is_finite() or shape.size.x <= 0.0 or shape.size.y <= 0.0 or shape.size.z <= 0.0:
			return {"ok": false}
		shape_node.shape = shape
	elif kind == "capsule":
		var radius := float(collision.get("radius_m", NAN))
		var segment_length := float(collision.get("length_m", NAN))
		if not is_finite(radius) or radius <= 0.0 or not is_finite(segment_length) or segment_length <= 0.0:
			return {"ok": false}
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		# Godot's capsule height is end-to-end; the engine-neutral length is
		# the cylindrical-axis distance used by Rapier capsule_y(length/2).
		shape.height = segment_length + 2.0 * radius
		shape.margin = COLLISION_MARGIN_M
		shape_node.shape = shape
	else:
		return {"ok": false}
	return {"ok": true, "shape_node": shape_node}


static func _material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 1.8
	material.rough = true
	material.bounce = 0.0
	material.absorbent = true
	return material


static func _zero_external_interventions_v1() -> Dictionary:
	return {
		"root_force_application_count": 0,
		"root_torque_application_count": 0,
		"root_impulse_application_count": 0,
		"root_pose_write_count": 0,
		"root_velocity_write_count": 0,
		"pin_or_guide_constraint_count": 0,
		"hidden_body_actuation_count": 0,
		"pose_teleport_count": 0,
		"collision_disable_count": 0,
		"contact_relabel_count": 0,
		"gravity_mutation_count": 0,
		"time_scale_mutation_count": 0,
		"engine_specific_policy_branch_count": 0,
	}


static func _ordered_strings_equal(value: Variant, expected: Array) -> bool:
	if not (value is Array) or (value as Array).size() != expected.size():
		return false
	for index in range(expected.size()):
		if String((value as Array)[index]) != String(expected[index]):
			return false
	return true


static func _vec3(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


static func _exact_variant_tree_equal_v1(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key in left_dictionary:
			if (
				not right_dictionary.has(key)
				or not _exact_variant_tree_equal_v1(
					left_dictionary[key], right_dictionary[key]
				)
			):
				return false
		return true
	if left is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _exact_variant_tree_equal_v1(left_array[index], right_array[index]):
				return false
		return true
	return left == right


static func _vector_json(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func project_quaternion_to_unit_scalar_v1(value: Quaternion) -> Dictionary:
	var source: Array = [
		float(value.x),
		float(value.y),
		float(value.z),
		float(value.w),
	]
	if not source.all(func(component: Variant) -> bool: return is_finite(float(component))):
		return _quaternion_projection_failure("nonfinite_source_component", source, null)
	var source_norm_squared := 0.0
	for component in source:
		source_norm_squared += float(component) * float(component)
	if not is_finite(source_norm_squared) or source_norm_squared <= 0.0:
		return _quaternion_projection_failure(
			"nonpositive_source_norm_squared", source, source_norm_squared
		)
	var source_norm := sqrt(source_norm_squared)
	if not is_finite(source_norm) or source_norm <= 0.0:
		return _quaternion_projection_failure(
			"invalid_source_norm", source, source_norm_squared
		)
	var projected: Array = []
	for component in source:
		projected.append(float(component) / source_norm)
	var reconstructed_component_index := 0
	for index in range(1, projected.size()):
		if absf(float(projected[index])) > absf(
			float(projected[reconstructed_component_index])
		):
			reconstructed_component_index = index
	var other_component_norm_squared := 0.0
	for index in range(projected.size()):
		if index != reconstructed_component_index:
			other_component_norm_squared += float(projected[index]) * float(projected[index])
	var reconstructed_squared := 1.0 - other_component_norm_squared
	if (
		not is_finite(reconstructed_squared)
		or reconstructed_squared < -CORE_QUATERNION_NORM_SQUARED_TOLERANCE
	):
		return _quaternion_projection_failure(
			"largest_component_reconstruction_invalid", source, source_norm_squared
		)
	var sign_value := (
		-1.0 if float(source[reconstructed_component_index]) < 0.0 else 1.0
	)
	projected[reconstructed_component_index] = sign_value * sqrt(
		maxf(0.0, reconstructed_squared)
	)
	var projected_norm_squared := 0.0
	for component in projected:
		projected_norm_squared += float(component) * float(component)
	var projected_unit_delta := absf(projected_norm_squared - 1.0)
	if (
		not is_finite(projected_norm_squared)
		or projected_unit_delta > CORE_QUATERNION_NORM_SQUARED_TOLERANCE
	):
		return _quaternion_projection_failure(
			"projected_norm_outside_core_contract", source, source_norm_squared
		)
	var orientation := _orientation_components_json(projected)
	return {
		"schema_version": QUATERNION_PROJECTION_SCHEMA,
		"ok": true,
		"support_status": "supported_exact",
		"refusal_reason": null,
		"projection_method_id": (
			"godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
		),
		"source_orientation_xyzw": _orientation_components_json(source),
		"source_norm_squared": source_norm_squared,
		"source_unit_delta": absf(source_norm_squared - 1.0),
		"orientation_xyzw": orientation,
		"projected_norm_squared": projected_norm_squared,
		"projected_unit_delta": projected_unit_delta,
		"reconstructed_component_index": reconstructed_component_index,
		"core_norm_squared_tolerance": CORE_QUATERNION_NORM_SQUARED_TOLERANCE,
		"within_core_unit_contract": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func diagnose_orientation_xyzw_v1(value: Variant) -> Dictionary:
	var source: Array = [null, null, null, null]
	if value is Dictionary:
		var orientation: Dictionary = value
		source = [
			orientation.get("x"),
			orientation.get("y"),
			orientation.get("z"),
			orientation.get("w"),
		]
	var finite_components := source.all(
		func(component: Variant) -> bool:
			return component != null and is_finite(float(component))
	)
	var norm_squared: Variant = null
	var unit_delta: Variant = null
	if finite_components:
		var numeric_norm_squared := 0.0
		for component in source:
			numeric_norm_squared += float(component) * float(component)
		norm_squared = numeric_norm_squared
		unit_delta = absf(numeric_norm_squared - 1.0)
	return {
		"schema_version": QUATERNION_DIAGNOSTIC_SCHEMA,
		"ok": finite_components,
		"source_orientation_xyzw": _orientation_components_json(source),
		"norm_squared": norm_squared,
		"unit_delta": unit_delta,
		"core_norm_squared_tolerance": CORE_QUATERNION_NORM_SQUARED_TOLERANCE,
		"within_core_unit_contract": (
			finite_components
			and float(unit_delta) <= CORE_QUATERNION_NORM_SQUARED_TOLERANCE
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _quaternion_json(value: Quaternion) -> Dictionary:
	var projection := project_quaternion_to_unit_scalar_v1(value)
	return (projection.get("orientation_xyzw", {}) as Dictionary).duplicate(true)


static func _quaternion_projection_failure(
	reason: String,
	source_components: Array,
	source_norm_squared: Variant,
) -> Dictionary:
	var source_unit_delta: Variant = null
	if source_norm_squared != null and is_finite(float(source_norm_squared)):
		source_unit_delta = absf(float(source_norm_squared) - 1.0)
	return {
		"schema_version": QUATERNION_PROJECTION_SCHEMA,
		"ok": false,
		"support_status": "invalid_quaternion_projection",
		"refusal_reason": reason,
		"projection_method_id": (
			"godot_real_t_to_float64_largest_component_unit_reconstruction_v1"
		),
		"source_orientation_xyzw": _orientation_components_json(source_components),
		"source_norm_squared": source_norm_squared,
		"source_unit_delta": source_unit_delta,
		"orientation_xyzw": null,
		"projected_norm_squared": null,
		"projected_unit_delta": null,
		"reconstructed_component_index": null,
		"core_norm_squared_tolerance": CORE_QUATERNION_NORM_SQUARED_TOLERANCE,
		"within_core_unit_contract": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _orientation_components_json(components: Array) -> Dictionary:
	var values: Array = []
	for component in components:
		values.append(
			float(component)
			if component != null and is_finite(float(component))
			else null
		)
	while values.size() < 4:
		values.append(null)
	return {"x": values[0], "y": values[1], "z": values[2], "w": values[3]}


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	var digest := String(receipt.get("sha256", ""))
	return digest if digest.begins_with("sha256:") and digest.length() == 71 else ""


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_recovery_native_world_failure_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": int(detail.get("model_construction_count", 0)),
		"world_attempt_count": int(detail.get("world_attempt_count", 0)),
		"world_build_count": int(detail.get("world_build_count", 0)),
		"solver_step_count": int(detail.get("solver_step_count", 0)),
		"physics_state_modified": bool(detail.get("physics_state_modified", false)),
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
