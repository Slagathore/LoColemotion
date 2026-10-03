extends RefCounted
# gdlint: disable=max-line-length

## Profile-scoped Godot 4.7/Jolt recovery-observation capability mapping.
##
## The historical stock mapping remains authoritative for every runtime except
## the exact selected instrumented binary pair. The current R71 successor adds
## exact post-solve contact snapshots to the retained motor-telemetry profile.
## Its channels are enabled only when both sibling executables match their
## retained byte identities and both native APIs are registered. No caller
## label, environment variable, configured limit, or missing value can promote
## the mapping. The filename is retained as a stable import path; profile IDs
## carry the actual native instrumentation version.

const StockCapabilityScript := preload("res://sdk/adapters/godot/gdscript/recovery_capability.gd")

const PROFILE_RECEIPT_SCHEMA_VERSION := "sporespore_godot_jolt_recovery_capability_profile_receipt_v1"
const INSTRUMENTED_PROFILE_ID := "godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3"
const COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID := "godot_4_7_jolt_sporespore_motor_solved_contact_and_solver_energy_telemetry_v4"
const SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d144_solver_coupled_complete_energy_capability_v1"
)
const SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID := (
	"godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1"
)
const DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_energy_capability_v1"
)
const DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1"
)
const ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_motor_solved_contact_and_solver_energy_telemetry_v6"
)
const ROTATION_AWARE_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d162_rotation_aware_discrete_staging_complete_energy_capability_v1"
)
const ROTATION_AWARE_COMPLETE_ENERGY_MAPPING_PROFILE_ID := (
	"godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
)
const FALLBACK_PROFILE_ID := "godot_4_7_jolt_stock_or_unqualified_v1"
const TELEMETRY_CLASS_NAME := &"JoltPhysicsServer3D"
const TELEMETRY_METHOD_NAME := &"hinge_joint_get_motor_telemetry"
const SOLVED_CONTACT_METHOD_NAME := &"space_get_solved_contact_telemetry"
const SOLVER_ENERGY_EXCHANGE_METHOD_NAME := &"space_get_solver_energy_exchange_telemetry"
const EXPECTED_CONSOLE_RAW_SHA256 := "19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
const EXPECTED_CONSOLE_BYTE_LENGTH := 293376
const EXPECTED_ENGINE_RAW_SHA256 := "b20323fd08a7b483e0dc59890ad381fe9d623c26ce1bcf63a5f7eb1f97ec9125"
const EXPECTED_ENGINE_BYTE_LENGTH := 188835328
# R140 admits the exact R138-qualified v5 binary pair. The v5 source changes
# only the position-job access grant needed by the already-versioned v4
# telemetry semantics, so the telemetry profile ID above deliberately remains
# v4 while these executable identities advance.
const COMPLETE_ENERGY_EXPECTED_CONSOLE_RAW_SHA256 := "8e07937dcbccf5f71356df5ac487616eb1f66025d37d73d770f82ffa47a578a0"
const COMPLETE_ENERGY_EXPECTED_CONSOLE_BYTE_LENGTH := 293376
const COMPLETE_ENERGY_EXPECTED_ENGINE_RAW_SHA256 := "fc8f7d0bece7c1d90d16ceb28d6f4ee8b3cd43facafa3494d51c8753a3bdd72b"
const COMPLETE_ENERGY_EXPECTED_ENGINE_BYTE_LENGTH := 188854272
const ROTATION_AWARE_EXPECTED_CONSOLE_RAW_SHA256 := (
	"2027bcd4adfce5cdecafa5b02392f859b1c61b0895d4f4588b4edf6eb91e2f9c"
)
const ROTATION_AWARE_EXPECTED_CONSOLE_BYTE_LENGTH := 293376
const ROTATION_AWARE_EXPECTED_ENGINE_RAW_SHA256 := (
	"1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b"
)
const ROTATION_AWARE_EXPECTED_ENGINE_BYTE_LENGTH := 188855808
const PROMOTED_CHANNEL_INDEXES := [3, 4, 5, 8]
const PROMOTED_SOURCE_RECORDS := {
	"ordered_foot_bearing_contact_observations":
	{
		"sources":
		[
			"PhysicsDirectBodyState3D.get_contact_local_position",
			"PhysicsDirectBodyState3D.get_contact_local_normal",
			"PhysicsDirectBodyState3D.get_contact_local_shape",
			"PhysicsDirectBodyState3D.get_contact_impulse.native_post_solve_constraint_lambda",
			"JoltPhysicsServer3D.space_get_solved_contact_telemetry.complete",
			"JoltPhysicsServer3D.space_get_solved_contact_telemetry.snapshot_is_current_space_step",
		],
		"mapping": "godot_jolt_exact_post_solve_ordinary_unilateral_foot_normal_impulse_sum_v1",
	},
	"classified_nonfoot_contact_observations":
	{
		"sources":
		[
			"PhysicsDirectBodyState3D.get_contact_local_position",
			"PhysicsDirectBodyState3D.get_contact_local_shape",
			"PhysicsDirectBodyState3D.get_contact_impulse.native_post_solve_constraint_lambda",
			"JoltPhysicsServer3D.space_get_solved_contact_telemetry.complete",
			"PhysicsDirectSpaceState3D.cast_motion",
		],
		"mapping": "godot_jolt_exact_post_solve_shape_identity_nonfoot_classification_v1",
	},
	"applied_actuation_receipts":
	{
		"sources":
		[
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.telemetry_sequence",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.capture_space_step_sequence",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.read_space_step_sequence",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.captured_during_active_step",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.snapshot_is_current_space_step",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.solver_step_s",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.target_angular_velocity_rad_s",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.min_torque_limit_nm",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.max_torque_limit_nm",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.signed_motor_impulse_nms",
		],
		"mapping": "godot_jolt_active_step_snapshot_v2_applied_actuation_receipt_projection_v1",
	},
	"energy_balance_ledger":
	{
		"sources":
		[
			"PhysicsDirectBodyState3D_state_energy_terms",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.positive_motor_work_j",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.absorbed_motor_work_j",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.net_motor_work_j",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.solver_step_s",
			"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.snapshot_is_current_space_step",
		],
		"mapping": "godot_jolt_active_step_snapshot_v2_energy_balance_ledger_projection_v1",
	},
}
const COMPLETE_ENERGY_BALANCE_SOURCE_RECORD := {
	"sources":
	[
		"PhysicsDirectBodyState3D_state_energy_terms",
		"sporespore_force_based_applied_actuation_receipt_v1.step_actuator_work_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.joint_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.contact_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_kinetic_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_mass_weighted_displacement_kg_m",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.complete",
		"PhysicsDirectBodyState3D.total_gravity",
		"RigidBody3D.linear_damp",
		"RigidBody3D.angular_damp",
		"sporespore_zero_external_intervention_ledger_v1",
		"sporespore_zero_discrete_staging_receipt_v1",
	],
	"mapping": "godot_jolt_r24d136_complete_solver_energy_partition_projection_v1",
}
const SOLVER_COUPLED_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD := {
	"sources":
	[
		"PhysicsDirectBodyState3D_state_energy_terms",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.positive_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.absorbed_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.net_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.capture_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.read_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.snapshot_is_current_space_step",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.joint_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.contact_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_kinetic_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_mass_weighted_displacement_kg_m",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.complete",
		"PhysicsDirectBodyState3D.total_gravity",
		"RigidBody3D.linear_damp",
		"RigidBody3D.angular_damp",
		"sporespore_zero_external_intervention_ledger_v1",
		"sporespore_zero_discrete_staging_receipt_v1",
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1",
		"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1",
	],
	"mapping": SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
}
const DISCRETE_STAGING_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD := {
	"sources":
	[
		"PhysicsDirectBodyState3D_state_energy_terms",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.positive_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.absorbed_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.net_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.capture_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.read_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.snapshot_is_current_space_step",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.joint_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.contact_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_kinetic_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_mass_weighted_displacement_kg_m",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.complete",
		"PhysicsDirectBodyState3D.pre_step_body_boundary",
		"PhysicsDirectBodyState3D.post_step_body_boundary",
		"PhysicsDirectBodyState3D.total_gravity",
		"RigidBody3D.linear_damp",
		"RigidBody3D.angular_damp",
		"sporespore_zero_external_intervention_ledger_v1",
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1",
		"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1",
		"sporespore_qsdk_r24d148_godot_jolt_gravity_force_integration_contract_v1",
		"godot_jolt_gravity_force_and_position_staging_exchange_v1",
	],
	"mapping": DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
}
const ROTATION_AWARE_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD := {
	"sources":
	[
		"PhysicsDirectBodyState3D_state_energy_terms",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.positive_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.absorbed_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.net_motor_work_j",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.capture_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.read_space_step_sequence",
		"JoltPhysicsServer3D.hinge_joint_get_motor_telemetry.snapshot_is_current_space_step",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.joint_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.contact_velocity_constraint_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.rotation_integration_kinetic_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_kinetic_exchange_j",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.position_constraint_mass_weighted_displacement_kg_m",
		"JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry.complete",
		"PhysicsDirectBodyState3D.pre_step_body_boundary",
		"PhysicsDirectBodyState3D.post_step_body_boundary",
		"PhysicsDirectBodyState3D.total_gravity",
		"RigidBody3D.linear_damp",
		"RigidBody3D.angular_damp",
		"sporespore_zero_external_intervention_ledger_v1",
		"sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2",
		"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_partition_contract_v1",
		"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1",
		"sporespore_qsdk_r24d148_godot_jolt_gravity_force_integration_contract_v1",
		"godot_jolt_gravity_force_and_position_staging_exchange_v1",
	],
	"mapping": ROTATION_AWARE_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
}
const ENERGY_BALANCE_CHANNEL_INDEX := 8

static var _runtime_identity_cache: Dictionary = {}
static var _complete_energy_runtime_identity_cache: Dictionary = {}
static var _rotation_aware_complete_energy_runtime_identity_cache: Dictionary = {}
static var _r10dg_diagnostic_runtime_identity: Dictionary = {}

static func r10dg_diagnostic_runtime_selected_v1() -> bool:
	return not _r10dg_diagnostic_runtime_identity.is_empty()


static func select_r10dg_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10DG_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10dg_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10dg_diagnostic_runtime_identity.is_empty() and _r10dg_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10DG_NATIVE_RUNTIME_RESELECTION"}
	_r10dg_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ap_diagnostic_runtime_identity: Dictionary = {}

static func r10ap_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ap_diagnostic_runtime_identity.is_empty()


static func select_r10ap_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AP_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ap_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ap_diagnostic_runtime_identity.is_empty() and _r10ap_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AP_NATIVE_RUNTIME_RESELECTION"}
	_r10ap_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10am_diagnostic_runtime_identity: Dictionary = {}

static func r10am_diagnostic_runtime_selected_v1() -> bool:
	return not _r10am_diagnostic_runtime_identity.is_empty()


static func select_r10am_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AM_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10am_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10am_diagnostic_runtime_identity.is_empty() and _r10am_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AM_NATIVE_RUNTIME_RESELECTION"}
	_r10am_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10aj_diagnostic_runtime_identity: Dictionary = {}

static func r10aj_diagnostic_runtime_selected_v1() -> bool:
	return not _r10aj_diagnostic_runtime_identity.is_empty()


static func select_r10aj_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AJ_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10aj_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10aj_diagnostic_runtime_identity.is_empty() and _r10aj_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AJ_NATIVE_RUNTIME_RESELECTION"}
	_r10aj_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ai_diagnostic_runtime_identity: Dictionary = {}

static func r10ai_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ai_diagnostic_runtime_identity.is_empty()


static func select_r10ai_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AI_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ai_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ai_diagnostic_runtime_identity.is_empty() and _r10ai_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AI_NATIVE_RUNTIME_RESELECTION"}
	_r10ai_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ag_diagnostic_runtime_identity: Dictionary = {}

static func r10ag_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ag_diagnostic_runtime_identity.is_empty()


static func select_r10ag_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AG_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ag_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ag_diagnostic_runtime_identity.is_empty() and _r10ag_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AG_NATIVE_RUNTIME_RESELECTION"}
	_r10ag_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10af_diagnostic_runtime_identity: Dictionary = {}

static func r10af_diagnostic_runtime_selected_v1() -> bool:
	return not _r10af_diagnostic_runtime_identity.is_empty()


static func select_r10af_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AF_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10af_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10af_diagnostic_runtime_identity.is_empty() and _r10af_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AF_NATIVE_RUNTIME_RESELECTION"}
	_r10af_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ae_diagnostic_runtime_identity: Dictionary = {}

static func r10ae_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ae_diagnostic_runtime_identity.is_empty()


static func select_r10ae_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AE_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ae_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ae_diagnostic_runtime_identity.is_empty() and _r10ae_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AE_NATIVE_RUNTIME_RESELECTION"}
	_r10ae_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ad_diagnostic_runtime_identity: Dictionary = {}

static func r10ad_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ad_diagnostic_runtime_identity.is_empty()


static func select_r10ad_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10ac_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AD_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ad_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ad_diagnostic_runtime_identity.is_empty() and _r10ad_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AD_NATIVE_RUNTIME_RESELECTION"}
	_r10ad_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static var _r10ac_diagnostic_runtime_identity: Dictionary = {}

static func r10ac_diagnostic_runtime_selected_v1() -> bool:
	return not _r10ac_diagnostic_runtime_identity.is_empty()


static func select_r10ac_diagnostic_runtime_v1(declaration: Dictionary, reference: Dictionary) -> Dictionary:
	# Explicit process-local selection only. Default profile discovery never
	# admits a v7 executable as the historically qualified v6 binary pair.
	if not _r10dg_diagnostic_runtime_identity.is_empty() or not _r10ap_diagnostic_runtime_identity.is_empty() or not _r10am_diagnostic_runtime_identity.is_empty() or not _r10aj_diagnostic_runtime_identity.is_empty() or not _r10ai_diagnostic_runtime_identity.is_empty() or not _r10ag_diagnostic_runtime_identity.is_empty() or not _r10ad_diagnostic_runtime_identity.is_empty() or not _r10ae_diagnostic_runtime_identity.is_empty() or not _r10af_diagnostic_runtime_identity.is_empty():
		return {"ok": false, "failure_code": "R10AC_NATIVE_RUNTIME_CROSSED_SELECTION"}
	var binder: Script = load("res://sdk/adapters/godot/gdscript/r10ac_native_runtime_v1.gd")
	var current: Script = load("res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd")
	var result: Dictionary = binder.bind_v1(declaration, reference, current)
	if result.get("ok") != true: return result
	if not _r10ac_diagnostic_runtime_identity.is_empty() and _r10ac_diagnostic_runtime_identity != result.runtime_identity:
		return {"ok": false, "failure_code": "R10AC_NATIVE_RUNTIME_RESELECTION"}
	_r10ac_diagnostic_runtime_identity = result.runtime_identity.duplicate(true)
	return result


static func _runtime_identity_for_profile_v1(
	profile_id: String,
	expected_console_raw_sha256: String,
	expected_console_byte_length: int,
	expected_engine_raw_sha256: String,
	expected_engine_byte_length: int,
	require_solver_energy_exchange: bool,
) -> Dictionary:
	var executable_path := _normalized_path(OS.get_executable_path())
	var pair_paths := _resolve_binary_pair_paths(executable_path)
	var console := _file_identity(String(pair_paths["console_path"]))
	var engine := _file_identity(String(pair_paths["engine_path"]))
	var motor_telemetry_api_reachable := (
		ClassDB.class_exists(TELEMETRY_CLASS_NAME)
		and ClassDB.class_has_method(TELEMETRY_CLASS_NAME, TELEMETRY_METHOD_NAME)
	)
	var solved_contact_api_reachable := (
		ClassDB.class_exists(TELEMETRY_CLASS_NAME)
		and ClassDB.class_has_method(TELEMETRY_CLASS_NAME, SOLVED_CONTACT_METHOD_NAME)
	)
	var solver_energy_exchange_api_reachable := (
		ClassDB.class_exists(TELEMETRY_CLASS_NAME)
		and ClassDB.class_has_method(TELEMETRY_CLASS_NAME, SOLVER_ENERGY_EXCHANGE_METHOD_NAME)
	)
	var telemetry_api_reachable := (
		motor_telemetry_api_reachable
		and solved_contact_api_reachable
		and (not require_solver_energy_exchange or solver_energy_exchange_api_reachable)
	)
	var executable_is_pair_member := (
		executable_path == String(console.get("path", ""))
		or executable_path == String(engine.get("path", ""))
	)
	var exact_pair := (
		executable_is_pair_member
		and bool(console.get("exists", false))
		and String(console.get("raw_sha256", "")) == expected_console_raw_sha256
		and int(console.get("byte_length", -1)) == expected_console_byte_length
		and bool(engine.get("exists", false))
		and String(engine.get("raw_sha256", "")) == expected_engine_raw_sha256
		and int(engine.get("byte_length", -1)) == expected_engine_byte_length
	)
	var selected := exact_pair and telemetry_api_reachable
	return {
		"schema_version": "sporespore_godot_jolt_runtime_identity_v1",
		"runtime_api_version": String(Engine.get_version_info().get("string", "")),
		"running_executable_path": executable_path,
		"running_executable_is_pair_member": executable_is_pair_member,
		"console_binary": console,
		"engine_binary": engine,
		"exact_binary_pair_match": exact_pair,
		"telemetry_class_registered": ClassDB.class_exists(TELEMETRY_CLASS_NAME),
		"telemetry_method_registered": telemetry_api_reachable,
		"motor_telemetry_method_registered": motor_telemetry_api_reachable,
		"solved_contact_telemetry_method_registered": solved_contact_api_reachable,
		"solver_energy_exchange_telemetry_method_registered": solver_energy_exchange_api_reachable,
		"solver_energy_exchange_telemetry_required": require_solver_energy_exchange,
		"instrumented_profile_selected": selected,
		"complete_energy_profile_selected": selected and require_solver_energy_exchange,
		"selected_profile_id": profile_id if selected else FALLBACK_PROFILE_ID,
		"selection_reason":
		(
			"exact_binary_pair_and_native_motor_solved_contact_and_solver_energy_telemetry_apis"
			if selected and require_solver_energy_exchange
			else (
				"exact_binary_pair_and_native_motor_and_solved_contact_telemetry_apis"
				if selected
				else "runtime_identity_or_required_native_telemetry_api_not_qualified"
			)
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
	}


static func runtime_identity_v1() -> Dictionary:
	if _runtime_identity_cache.is_empty():
		_runtime_identity_cache = _runtime_identity_for_profile_v1(
			INSTRUMENTED_PROFILE_ID,
			EXPECTED_CONSOLE_RAW_SHA256,
			EXPECTED_CONSOLE_BYTE_LENGTH,
			EXPECTED_ENGINE_RAW_SHA256,
			EXPECTED_ENGINE_BYTE_LENGTH,
			false,
		)
	return _runtime_identity_cache.duplicate(true)


static func complete_energy_runtime_identity_v1() -> Dictionary:
	if _complete_energy_runtime_identity_cache.is_empty():
		_complete_energy_runtime_identity_cache = _runtime_identity_for_profile_v1(
			COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
			COMPLETE_ENERGY_EXPECTED_CONSOLE_RAW_SHA256,
			COMPLETE_ENERGY_EXPECTED_CONSOLE_BYTE_LENGTH,
			COMPLETE_ENERGY_EXPECTED_ENGINE_RAW_SHA256,
			COMPLETE_ENERGY_EXPECTED_ENGINE_BYTE_LENGTH,
			true,
		)
	return _complete_energy_runtime_identity_cache.duplicate(true)


static func rotation_aware_complete_energy_runtime_identity_v1() -> Dictionary:
	var finite: Script = load("res://sdk/adapters/godot/gdscript/r10dh_campaign_context_v1.gd")
	if finite.selected():
		return finite.runtime_identity.duplicate(true)
	var discovery: Script = load("res://sdk/discovery/recovery_discovery_context_v1.gd")
	if discovery.selected():
		return discovery.runtime_identity.duplicate(true)
	if not _r10dg_diagnostic_runtime_identity.is_empty():
		return _r10dg_diagnostic_runtime_identity.duplicate(true)
	if not _r10ap_diagnostic_runtime_identity.is_empty():
		return _r10ap_diagnostic_runtime_identity.duplicate(true)
	if not _r10am_diagnostic_runtime_identity.is_empty():
		return _r10am_diagnostic_runtime_identity.duplicate(true)
	if not _r10aj_diagnostic_runtime_identity.is_empty():
		return _r10aj_diagnostic_runtime_identity.duplicate(true)
	if not _r10ai_diagnostic_runtime_identity.is_empty():
		return _r10ai_diagnostic_runtime_identity.duplicate(true)
	if not _r10ag_diagnostic_runtime_identity.is_empty():
		return _r10ag_diagnostic_runtime_identity.duplicate(true)
	if not _r10af_diagnostic_runtime_identity.is_empty():
		return _r10af_diagnostic_runtime_identity.duplicate(true)
	if not _r10ae_diagnostic_runtime_identity.is_empty():
		return _r10ae_diagnostic_runtime_identity.duplicate(true)
	if not _r10ad_diagnostic_runtime_identity.is_empty():
		return _r10ad_diagnostic_runtime_identity.duplicate(true)
	if not _r10ac_diagnostic_runtime_identity.is_empty():
		return _r10ac_diagnostic_runtime_identity.duplicate(true)
	if _rotation_aware_complete_energy_runtime_identity_cache.is_empty():
		_rotation_aware_complete_energy_runtime_identity_cache = _runtime_identity_for_profile_v1(
			ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
			ROTATION_AWARE_EXPECTED_CONSOLE_RAW_SHA256,
			ROTATION_AWARE_EXPECTED_CONSOLE_BYTE_LENGTH,
			ROTATION_AWARE_EXPECTED_ENGINE_RAW_SHA256,
			ROTATION_AWARE_EXPECTED_ENGINE_BYTE_LENGTH,
			true,
		)
	return _rotation_aware_complete_energy_runtime_identity_cache.duplicate(true)


static func _capability_for_runtime_v1(
	runtime: Dictionary,
	complete_energy_profile: bool,
) -> Dictionary:
	var capability: Dictionary = StockCapabilityScript.capability_v1()
	if not bool(runtime.get("instrumented_profile_selected", false)):
		return capability
	for index in PROMOTED_CHANNEL_INDEXES:
		var channel: Dictionary = capability["ordered_channels"][index]
		var channel_id := String(channel["channel"])
		var promoted: Dictionary = (
			COMPLETE_ENERGY_BALANCE_SOURCE_RECORD
			if complete_energy_profile and channel_id == "energy_balance_ledger"
			else PROMOTED_SOURCE_RECORDS[channel_id]
		)
		channel["support"] = "supported_measured"
		channel["host_source_ids"] = (promoted["sources"] as Array).duplicate()
		channel["mapping_rule_id"] = String(promoted["mapping"])
		channel["source_measurement_only"] = true
		channel["synthesized_when_missing"] = false
	return capability


static func capability_v1() -> Dictionary:
	return _capability_for_runtime_v1(runtime_identity_v1(), false)


static func complete_energy_capability_v1() -> Dictionary:
	return _capability_for_runtime_v1(complete_energy_runtime_identity_v1(), true)


## R144 changes only the complete-energy channel's source/mapping declaration.
## Runtime binaries and every other measured channel remain the exact R136
## qualified population; callers cannot select this variant by relabelling a
## stock or incomplete capability.
static func solver_coupled_complete_energy_capability_v1() -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var capability := complete_energy_capability_v1()
	if not bool(runtime.get("instrumented_profile_selected", false)):
		return capability
	var channels_value: Variant = capability.get("ordered_channels")
	if not (channels_value is Array):
		return {}
	var channels: Array = channels_value
	if channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size():
		return {}
	var channel_value: Variant = channels[ENERGY_BALANCE_CHANNEL_INDEX]
	if not (channel_value is Dictionary):
		return {}
	var channel: Dictionary = channel_value
	if String(channel.get("channel", "")) != "energy_balance_ledger":
		return {}
	channel["host_source_ids"] = (
		SOLVER_COUPLED_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD["sources"] as Array
	).duplicate()
	channel["mapping_rule_id"] = String(
		SOLVER_COUPLED_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD["mapping"]
	)
	return capability


## R148 keeps the exact R144 binary/API population and changes only the energy
## channel declaration from structural-zero staging to the independently
## measured pre/post-boundary observer. No additional native API is claimed.
static func discrete_staging_complete_energy_capability_v1() -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var capability := solver_coupled_complete_energy_capability_v1()
	if not bool(runtime.get("instrumented_profile_selected", false)):
		return capability
	var channels_value: Variant = capability.get("ordered_channels")
	if not (channels_value is Array):
		return {}
	var channels: Array = channels_value
	if channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size():
		return {}
	var channel_value: Variant = channels[ENERGY_BALANCE_CHANNEL_INDEX]
	if not (channel_value is Dictionary):
		return {}
	var channel: Dictionary = channel_value
	if String(channel.get("channel", "")) != "energy_balance_ledger":
		return {}
	channel["host_source_ids"] = (
		DISCRETE_STAGING_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD["sources"] as Array
	).duplicate()
	channel["mapping_rule_id"] = String(
		DISCRETE_STAGING_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD["mapping"]
	)
	return capability


static func _energy_capability_for_runtime_and_record_v1(
	runtime: Dictionary,
	energy_record: Dictionary,
) -> Dictionary:
	var capability := _capability_for_runtime_v1(runtime, true)
	if not bool(runtime.get("instrumented_profile_selected", false)):
		return capability
	var channels_value: Variant = capability.get("ordered_channels")
	if not (channels_value is Array):
		return {}
	var channels: Array = channels_value
	if channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size():
		return {}
	var channel_value: Variant = channels[ENERGY_BALANCE_CHANNEL_INDEX]
	if not (channel_value is Dictionary):
		return {}
	var channel: Dictionary = channel_value
	if String(channel.get("channel", "")) != "energy_balance_ledger":
		return {}
	channel["host_source_ids"] = (energy_record["sources"] as Array).duplicate()
	channel["mapping_rule_id"] = String(energy_record["mapping"])
	return capability


static func rotation_aware_complete_energy_capability_v1() -> Dictionary:
	return _energy_capability_for_runtime_and_record_v1(
		rotation_aware_complete_energy_runtime_identity_v1(),
		ROTATION_AWARE_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD,
	)


static func _rotation_aware_predecessor_capability_v1() -> Dictionary:
	return _energy_capability_for_runtime_and_record_v1(
		rotation_aware_complete_energy_runtime_identity_v1(),
		DISCRETE_STAGING_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD,
	)


static func _validate_capability_for_runtime_v1(
	capability: Dictionary,
	runtime: Dictionary,
	profile_id: String,
	complete_energy_profile: bool,
) -> Dictionary:
	if not bool(runtime.get("instrumented_profile_selected", false)):
		var fallback: Dictionary = StockCapabilityScript.validate_capability_v1(capability)
		fallback["runtime_profile_id"] = FALLBACK_PROFILE_ID
		fallback["instrumented_profile_selected"] = false
		fallback["exact_binary_pair_match"] = bool(runtime.get("exact_binary_pair_match", false))
		fallback["telemetry_method_registered"] = bool(
			runtime.get("telemetry_method_registered", false)
		)
		fallback["motor_telemetry_method_registered"] = bool(
			runtime.get("motor_telemetry_method_registered", false)
		)
		fallback["solved_contact_telemetry_method_registered"] = bool(
			runtime.get("solved_contact_telemetry_method_registered", false)
		)
		fallback["solver_energy_exchange_telemetry_method_registered"] = bool(
			runtime.get("solver_energy_exchange_telemetry_method_registered", false)
		)
		fallback["complete_energy_profile_selected"] = false
		return fallback

	var failure_code := ""
	if (
		String(capability.get("schema_version", ""))
		!= StockCapabilityScript.CAPABILITY_SCHEMA_VERSION
	):
		failure_code = "CAPABILITY_SCHEMA_INVALID"
	elif String(capability.get("adapter_id", "")) != StockCapabilityScript.ADAPTER_ID:
		failure_code = "ADAPTER_ID_INVALID"
	elif String(capability.get("engine", "")) != StockCapabilityScript.ENGINE_ID:
		failure_code = "ENGINE_ID_INVALID"
	elif String(capability.get("engine_version", "")) != StockCapabilityScript.ENGINE_VERSION:
		failure_code = "ENGINE_VERSION_INVALID"
	elif String(capability.get("mapping_id", "")) != StockCapabilityScript.MAPPING_ID:
		failure_code = "MAPPING_ID_INVALID"
	elif not bool(capability.get("native_engine", false)):
		failure_code = "NATIVE_ENGINE_INVALID"
	elif (
		bool(capability.get("host_pose_label_used_for_success", true))
		or bool(capability.get("fallback_control_permitted", true))
		or bool(capability.get("engine_identity_exposed_to_policy", true))
		or int(capability.get("model_construction_count", -1)) != 0
		or int(capability.get("world_attempt_count", -1)) != 0
		or int(capability.get("world_build_count", -1)) != 0
		or int(capability.get("solver_step_count", -1)) != 0
		or bool(capability.get("physics_state_modified", true))
		or bool(capability.get("physical_acceptance_authority", true))
		or bool(capability.get("release_authority", true))
	):
		failure_code = "SIDE_EFFECT_OR_AUTHORITY_BOUNDARY_INVALID"
	var channels_value: Variant = capability.get("ordered_channels")
	if failure_code.is_empty() and not (channels_value is Array):
		failure_code = "CHANNELS_INVALID"
	var channels: Array = [] if not (channels_value is Array) else channels_value
	if failure_code.is_empty() and channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size():
		failure_code = "CHANNEL_COUNT_INVALID"
	var stock_channels: Array = StockCapabilityScript.capability_v1()["ordered_channels"]
	if failure_code.is_empty():
		for index in range(channels.size()):
			var item_value: Variant = channels[index]
			if not (item_value is Dictionary):
				failure_code = "CHANNEL_RECORD_INVALID"
				break
			var item: Dictionary = item_value
			var channel_id := String(StockCapabilityScript.ORDERED_CHANNELS[index])
			var sources_value: Variant = item.get("host_source_ids")
			if (
				String(item.get("channel", "")) != channel_id
				or String(item.get("support", "")) != "supported_measured"
				or not bool(item.get("source_measurement_only", false))
				or bool(item.get("synthesized_when_missing", true))
				or not (sources_value is Array)
				or (sources_value as Array).is_empty()
				or String(item.get("mapping_rule_id", "")).is_empty()
			):
				failure_code = "CHANNEL_MAPPING_INVALID_%s" % channel_id
				break
			if index in PROMOTED_CHANNEL_INDEXES:
				var promoted: Dictionary = (
					COMPLETE_ENERGY_BALANCE_SOURCE_RECORD
					if complete_energy_profile and channel_id == "energy_balance_ledger"
					else PROMOTED_SOURCE_RECORDS[channel_id]
				)
				if (
					(sources_value as Array) != promoted["sources"]
					or String(item.get("mapping_rule_id", "")) != String(promoted["mapping"])
				):
					failure_code = "PROFILE_SOURCE_MAPPING_INVALID_%s" % channel_id
					break
			elif item != stock_channels[index]:
				failure_code = "STOCK_CHANNEL_DRIFT_%s" % channel_id
				break
	return {
		"ok": failure_code.is_empty(),
		"failure_code": failure_code,
		"runtime_profile_id": profile_id,
		"instrumented_profile_selected": true,
		"complete_energy_profile_selected": complete_energy_profile,
		"exact_binary_pair_match": bool(runtime.get("exact_binary_pair_match", false)),
		"telemetry_method_registered": bool(runtime.get("telemetry_method_registered", false)),
		"motor_telemetry_method_registered":
		bool(runtime.get("motor_telemetry_method_registered", false)),
		"solved_contact_telemetry_method_registered":
		bool(runtime.get("solved_contact_telemetry_method_registered", false)),
		"solver_energy_exchange_telemetry_method_registered":
		bool(runtime.get("solver_energy_exchange_telemetry_method_registered", false)),
		"required_channel_count": StockCapabilityScript.ORDERED_CHANNELS.size(),
		"supported_channel_count": StockCapabilityScript.ORDERED_CHANNELS.size(),
		"unsupported_channel_count": 0,
		"unsupported_channels": [],
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_capability_v1(capability: Dictionary) -> Dictionary:
	return _validate_capability_for_runtime_v1(
		capability,
		runtime_identity_v1(),
		INSTRUMENTED_PROFILE_ID,
		false,
	)


static func validate_complete_energy_capability_v1(capability: Dictionary) -> Dictionary:
	return _validate_capability_for_runtime_v1(
		capability,
		complete_energy_runtime_identity_v1(),
		COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		true,
	)


## Exact additive R144 validator. It first requires the complete v5 binary/API
## runtime, then proves that precisely one R136 capability channel changed and
## that the changed channel is the declared solver-coupled energy mapping.
static func validate_solver_coupled_complete_energy_capability_v1(
	capability: Dictionary,
) -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var expected := solver_coupled_complete_energy_capability_v1()
	var predecessor := complete_energy_capability_v1()
	var failure_code := ""
	var changed_channel_count := 0
	var changed_channel_ids: Array = []
	if not bool(runtime.get("instrumented_profile_selected", false)):
		failure_code = "EXACT_COMPLETE_ENERGY_RUNTIME_REQUIRED"
	elif capability != expected:
		failure_code = "SOLVER_COUPLED_CAPABILITY_VARIANT_INVALID"
	else:
		var channels_value: Variant = capability.get("ordered_channels")
		var predecessor_channels_value: Variant = predecessor.get("ordered_channels")
		if not (channels_value is Array) or not (predecessor_channels_value is Array):
			failure_code = "CHANNELS_INVALID"
		else:
			var channels: Array = channels_value
			var predecessor_channels: Array = predecessor_channels_value
			if (
				channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size()
				or predecessor_channels.size() != channels.size()
			):
				failure_code = "CHANNEL_COUNT_INVALID"
			else:
				for index in range(channels.size()):
					if channels[index] != predecessor_channels[index]:
						changed_channel_count += 1
						changed_channel_ids.append(
							String((channels[index] as Dictionary).get("channel", ""))
						)
				if (
					changed_channel_count != 1
					or changed_channel_ids != ["energy_balance_ledger"]
				):
					failure_code = "CAPABILITY_VARIANT_SCOPE_INVALID"
	var selected := failure_code.is_empty()
	return {
		"ok": selected,
		"failure_code": failure_code,
		"runtime_profile_id": COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID,
		"adapter_energy_mapping_profile_id": (
			SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
		"instrumented_profile_selected": bool(
			runtime.get("instrumented_profile_selected", false)
		),
		"complete_energy_profile_selected": bool(
			runtime.get("complete_energy_profile_selected", false)
		),
		"solver_coupled_complete_energy_profile_selected": selected,
		"exact_binary_pair_match": bool(runtime.get("exact_binary_pair_match", false)),
		"telemetry_method_registered": bool(runtime.get("telemetry_method_registered", false)),
		"motor_telemetry_method_registered": bool(
			runtime.get("motor_telemetry_method_registered", false)
		),
		"solved_contact_telemetry_method_registered": bool(
			runtime.get("solved_contact_telemetry_method_registered", false)
		),
		"solver_energy_exchange_telemetry_method_registered": bool(
			runtime.get("solver_energy_exchange_telemetry_method_registered", false)
		),
		"required_channel_count": StockCapabilityScript.ORDERED_CHANNELS.size(),
		"supported_channel_count": (
			StockCapabilityScript.ORDERED_CHANNELS.size() if selected else 0
		),
		"unsupported_channel_count": 0 if selected else StockCapabilityScript.ORDERED_CHANNELS.size(),
		"unsupported_channels": [] if selected else StockCapabilityScript.ORDERED_CHANNELS.duplicate(),
		"changed_channel_count": changed_channel_count,
		"changed_channel_ids": changed_channel_ids,
		"predecessor_complete_energy_capability_preserved": selected,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Exact additive R148 validator. Its comparison parent is R144, so an R136
## capability relabel cannot masquerade as a measured-staging successor.
static func validate_discrete_staging_complete_energy_capability_v1(
	capability: Dictionary,
) -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var expected := discrete_staging_complete_energy_capability_v1()
	var predecessor := solver_coupled_complete_energy_capability_v1()
	var failure_code := ""
	var changed_channel_count := 0
	var changed_channel_ids: Array = []
	if not bool(runtime.get("instrumented_profile_selected", false)):
		failure_code = "EXACT_COMPLETE_ENERGY_RUNTIME_REQUIRED"
	elif capability != expected:
		failure_code = "DISCRETE_STAGING_CAPABILITY_VARIANT_INVALID"
	else:
		var channels_value: Variant = capability.get("ordered_channels")
		var predecessor_channels_value: Variant = predecessor.get("ordered_channels")
		if not (channels_value is Array) or not (predecessor_channels_value is Array):
			failure_code = "CHANNELS_INVALID"
		else:
			var channels: Array = channels_value
			var predecessor_channels: Array = predecessor_channels_value
			if (
				channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size()
				or predecessor_channels.size() != channels.size()
			):
				failure_code = "CHANNEL_COUNT_INVALID"
			else:
				for index in range(channels.size()):
					if channels[index] != predecessor_channels[index]:
						changed_channel_count += 1
						changed_channel_ids.append(
							String((channels[index] as Dictionary).get("channel", ""))
						)
				if (
					changed_channel_count != 1
					or changed_channel_ids != ["energy_balance_ledger"]
				):
					failure_code = "CAPABILITY_VARIANT_SCOPE_INVALID"
	var selected := failure_code.is_empty()
	return {
		"ok": selected,
		"failure_code": failure_code,
		"runtime_profile_id": COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID,
		"adapter_energy_mapping_profile_id": (
			DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
		"instrumented_profile_selected": bool(
			runtime.get("instrumented_profile_selected", false)
		),
		"complete_energy_profile_selected": bool(
			runtime.get("complete_energy_profile_selected", false)
		),
		"solver_coupled_complete_energy_profile_selected": selected,
		"discrete_staging_complete_energy_profile_selected": selected,
		"exact_binary_pair_match": bool(runtime.get("exact_binary_pair_match", false)),
		"telemetry_method_registered": bool(runtime.get("telemetry_method_registered", false)),
		"motor_telemetry_method_registered": bool(
			runtime.get("motor_telemetry_method_registered", false)
		),
		"solved_contact_telemetry_method_registered": bool(
			runtime.get("solved_contact_telemetry_method_registered", false)
		),
		"solver_energy_exchange_telemetry_method_registered": bool(
			runtime.get("solver_energy_exchange_telemetry_method_registered", false)
		),
		"required_channel_count": StockCapabilityScript.ORDERED_CHANNELS.size(),
		"supported_channel_count": (
			StockCapabilityScript.ORDERED_CHANNELS.size() if selected else 0
		),
		"unsupported_channel_count": (
			0 if selected else StockCapabilityScript.ORDERED_CHANNELS.size()
		),
		"unsupported_channels": (
			[] if selected else StockCapabilityScript.ORDERED_CHANNELS.duplicate()
		),
		"changed_channel_count": changed_channel_count,
		"changed_channel_ids": changed_channel_ids,
		"predecessor_solver_coupled_capability_preserved": selected,
		"native_engine_binary_changed": false,
		"native_telemetry_api_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func validate_rotation_aware_complete_energy_capability_v1(
	capability: Dictionary,
) -> Dictionary:
	var runtime := rotation_aware_complete_energy_runtime_identity_v1()
	var expected := rotation_aware_complete_energy_capability_v1()
	var predecessor := _rotation_aware_predecessor_capability_v1()
	var failure_code := ""
	var changed_channel_count := 0
	var changed_channel_ids: Array = []
	if not bool(runtime.get("instrumented_profile_selected", false)):
		failure_code = "EXACT_ROTATION_AWARE_COMPLETE_ENERGY_RUNTIME_REQUIRED"
	elif capability != expected:
		failure_code = "ROTATION_AWARE_CAPABILITY_VARIANT_INVALID"
	else:
		var channels_value: Variant = capability.get("ordered_channels")
		var predecessor_channels_value: Variant = predecessor.get("ordered_channels")
		if not (channels_value is Array) or not (predecessor_channels_value is Array):
			failure_code = "CHANNELS_INVALID"
		else:
			var channels: Array = channels_value
			var predecessor_channels: Array = predecessor_channels_value
			if (
				channels.size() != StockCapabilityScript.ORDERED_CHANNELS.size()
				or predecessor_channels.size() != channels.size()
			):
				failure_code = "CHANNEL_COUNT_INVALID"
			else:
				for index in range(channels.size()):
					if channels[index] != predecessor_channels[index]:
						changed_channel_count += 1
						changed_channel_ids.append(
							String((channels[index] as Dictionary).get("channel", ""))
						)
				if (
					changed_channel_count != 1
					or changed_channel_ids != ["energy_balance_ledger"]
				):
					failure_code = "CAPABILITY_VARIANT_SCOPE_INVALID"
	var selected := failure_code.is_empty()
	return {
		"ok": selected,
		"failure_code": failure_code,
		"runtime_profile_id": ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": ROTATION_AWARE_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID,
		"adapter_energy_mapping_profile_id": (
			ROTATION_AWARE_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
		"predecessor_adapter_energy_mapping_profile_id": (
			DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
		"instrumented_profile_selected": bool(
			runtime.get("instrumented_profile_selected", false)
		),
		"complete_energy_profile_selected": bool(
			runtime.get("complete_energy_profile_selected", false)
		),
		"solver_coupled_complete_energy_profile_selected": selected,
		"discrete_staging_complete_energy_profile_selected": selected,
		"rotation_aware_energy_ledger_profile_selected": selected,
		"exact_binary_pair_match": bool(runtime.get("exact_binary_pair_match", false)),
		"telemetry_method_registered": bool(runtime.get("telemetry_method_registered", false)),
		"motor_telemetry_method_registered": bool(
			runtime.get("motor_telemetry_method_registered", false)
		),
		"solved_contact_telemetry_method_registered": bool(
			runtime.get("solved_contact_telemetry_method_registered", false)
		),
		"solver_energy_exchange_telemetry_method_registered": bool(
			runtime.get("solver_energy_exchange_telemetry_method_registered", false)
		),
		"required_channel_count": StockCapabilityScript.ORDERED_CHANNELS.size(),
		"supported_channel_count": (
			StockCapabilityScript.ORDERED_CHANNELS.size() if selected else 0
		),
		"unsupported_channel_count": (
			0 if selected else StockCapabilityScript.ORDERED_CHANNELS.size()
		),
		"unsupported_channels": (
			[] if selected else StockCapabilityScript.ORDERED_CHANNELS.duplicate()
		),
		"changed_channel_count": changed_channel_count,
		"changed_channel_ids": changed_channel_ids,
		"predecessor_discrete_staging_capability_semantics_preserved": selected,
		"native_engine_binary_changed": true,
		"native_telemetry_profile_changed": true,
		"portable_policy_changed": false,
		"behavior_threshold_changed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _profile_receipt_for_runtime_v1(
	runtime: Dictionary,
	capability: Dictionary,
	validation: Dictionary,
) -> Dictionary:
	return {
		"schema_version": PROFILE_RECEIPT_SCHEMA_VERSION,
		"profile_id": String(runtime.get("selected_profile_id", FALLBACK_PROFILE_ID)),
		"instrumented_profile_selected": bool(runtime.get("instrumented_profile_selected", false)),
		"runtime_identity": runtime,
		"capability": capability,
		"validation": validation,
		"stock_mapping_path": "res://sdk/adapters/godot/gdscript/recovery_capability.gd",
		"stock_mapping_rewritten": false,
		"numerical_accuracy_accepted": false,
		"native_observation_collection_executed": false,
		"controller_implemented": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func profile_receipt_v1() -> Dictionary:
	var runtime := runtime_identity_v1()
	var capability := capability_v1()
	return _profile_receipt_for_runtime_v1(
		runtime,
		capability,
		validate_capability_v1(capability),
	)


static func complete_energy_profile_receipt_v1() -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var capability := complete_energy_capability_v1()
	return _profile_receipt_for_runtime_v1(
		runtime,
		capability,
		validate_complete_energy_capability_v1(capability),
	)


static func solver_coupled_complete_energy_profile_receipt_v1() -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var capability := solver_coupled_complete_energy_capability_v1()
	var receipt := _profile_receipt_for_runtime_v1(
		runtime,
		capability,
		validate_solver_coupled_complete_energy_capability_v1(capability),
	)
	receipt["capability_variant_id"] = SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	receipt["adapter_energy_mapping_profile_id"] = (
		SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	receipt["telemetry_profile_changed"] = false
	receipt["runtime_binary_pair_changed"] = false
	receipt["changed_capability_channel_ids"] = ["energy_balance_ledger"]
	return receipt


static func discrete_staging_complete_energy_profile_receipt_v1() -> Dictionary:
	var runtime := complete_energy_runtime_identity_v1()
	var capability := discrete_staging_complete_energy_capability_v1()
	var receipt := _profile_receipt_for_runtime_v1(
		runtime,
		capability,
		validate_discrete_staging_complete_energy_capability_v1(capability),
	)
	receipt["capability_variant_id"] = (
		DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	)
	receipt["adapter_energy_mapping_profile_id"] = (
		DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	receipt["telemetry_profile_changed"] = false
	receipt["runtime_binary_pair_changed"] = false
	receipt["changed_capability_channel_ids"] = ["energy_balance_ledger"]
	return receipt


static func rotation_aware_complete_energy_profile_receipt_v1() -> Dictionary:
	var runtime := rotation_aware_complete_energy_runtime_identity_v1()
	var capability := rotation_aware_complete_energy_capability_v1()
	var receipt := _profile_receipt_for_runtime_v1(
		runtime,
		capability,
		validate_rotation_aware_complete_energy_capability_v1(capability),
	)
	receipt["capability_variant_id"] = (
		ROTATION_AWARE_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	)
	receipt["adapter_energy_mapping_profile_id"] = (
		ROTATION_AWARE_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	receipt["predecessor_adapter_energy_mapping_profile_id"] = (
		DISCRETE_STAGING_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	receipt["rotation_aware_energy_ledger_profile_selected"] = true
	receipt["telemetry_profile_changed"] = true
	receipt["runtime_binary_pair_changed"] = true
	receipt["changed_capability_channel_ids"] = ["energy_balance_ledger"]
	return receipt


static func _resolve_binary_pair_paths(executable_path: String) -> Dictionary:
	var lower := executable_path.to_lower()
	var console_path := ""
	var engine_path := ""
	var console_suffix := ".console.exe"
	var executable_suffix := ".exe"
	if lower.ends_with(console_suffix):
		console_path = executable_path
		engine_path = (
			executable_path.left(executable_path.length() - console_suffix.length())
			+ executable_suffix
		)
	elif lower.ends_with(executable_suffix):
		engine_path = executable_path
		console_path = (
			executable_path.left(executable_path.length() - executable_suffix.length())
			+ console_suffix
		)
	return {
		"console_path": console_path,
		"engine_path": engine_path,
	}


static func _file_identity(path: String) -> Dictionary:
	var exists := not path.is_empty() and FileAccess.file_exists(path)
	var byte_length := -1
	var raw_sha256 := ""
	if exists:
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle != null:
			byte_length = handle.get_length()
			handle.close()
			raw_sha256 = FileAccess.get_sha256(path).to_lower()
	return {
		"path": path,
		"exists": exists,
		"raw_sha256": raw_sha256,
		"byte_length": byte_length,
	}


static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/")
