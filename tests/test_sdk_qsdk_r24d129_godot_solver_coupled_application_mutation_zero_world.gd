extends SceneTree
# gdlint: disable=max-line-length

## R129 exercises the exact production solver-coupled producer and consumer on
## uninserted HingeJoint3D objects. It preserves the complete R127 regression,
## reproduces R128's retained Boolean mismatch, proves the corrected active and
## matched-zero semantics, and mutation-tests the new mapping without a model,
## world, solver step, seed, or physical rehearsal.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const R127Test := preload(
	"res://tests/test_sdk_qsdk_r24d127_godot_solver_coupled_controller_zero_world.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D129_SOLVER_COUPLED_APPLICATION_MUTATION_ZERO_WORLD "


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var inherited := R127Test._evaluate()
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D129_EXTENSION_UNAVAILABLE", inherited)
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D129_EXTENSION_INSTANTIATION_FAILED", inherited)
	var context := RouteScript.prepare_context_v6(sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID)
	var bound := RouteScript.zero_world_fixture_v6(sdk, context)
	var active_route := RouteScript.collect_and_plan_v1(
		sdk,
		context,
		bound,
		"raise_body",
		0,
	)
	if (
		not bool(context.get("ok", false))
		or not bool(bound.get("ok", false))
		or not bool(active_route.get("ok", false))
	):
		return _failure(
			"QSDK_R24D129_ACTIVE_CONTROL_CONSTRUCTION_FAILED",
			{"inherited": inherited, "context": context, "bound": bound, "route": active_route},
		)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D129_ZERO_WORLD_SURFACE_FAILED", surface)
	var active_control: Dictionary = active_route["control_receipt"]
	var predecessor_active := (
		RouteScript
		. apply_behavior_control_solver_coupled_native_constraint_motor_v10(
			sdk,
			active_control,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	var corrected_active := (
		RouteScript
		. apply_behavior_control_solver_coupled_native_constraint_motor_v11(
			sdk,
			active_control,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	var corrected_matched_zero := (
		RouteScript
		. apply_behavior_control_solver_coupled_native_constraint_motor_v11(
			sdk,
			_matched_zero_control_v6(),
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
	)
	RouteScript.free_zero_world_command_surface_v1(surface)

	var mutated_semantics := corrected_active.duplicate(true)
	mutated_semantics["application_mutation_semantics_id"] = "mutated_semantics"
	var mutated_active_physics := corrected_active.duplicate(true)
	mutated_active_physics["physics_state_modified"] = false
	var mutated_zero_physics := corrected_matched_zero.duplicate(true)
	mutated_zero_physics["physics_state_modified"] = true
	var mutated_pre_solver_body := corrected_active.duplicate(true)
	mutated_pre_solver_body["pre_solver_rigid_body_state_modified"] = true

	var positive_checks := {
		"r127_complete_regression_passes": bool(inherited.get("ok", false)),
		"r128_mismatch_reproduced_exactly": (
			bool(predecessor_active.get("ok", false))
			and int(predecessor_active.get("motor_enabled_count", -1)) == 8
			and int(predecessor_active.get("solver_coupled_motor_target_write_count", -1)) == 8
			and not bool(predecessor_active.get("physics_state_modified", true))
		),
		"corrected_active_receipt_exact": _active_receipt_exact(corrected_active),
		"production_consumer_accepts_corrected_active": (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				corrected_active,
				false,
			)
		),
		"corrected_matched_zero_receipt_exact": _matched_zero_receipt_exact(
			corrected_matched_zero
		),
		"production_consumer_accepts_corrected_matched_zero": (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				corrected_matched_zero,
				true,
			)
		),
	}
	var forced_failure_checks := {
		"r128_predecessor_receipt_rejected": not (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				predecessor_active,
				false,
			)
		),
		"mutated_semantics_rejected": not (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				mutated_semantics,
				false,
			)
		),
		"active_false_mutation_rejected": not (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				mutated_active_physics,
				false,
			)
		),
		"matched_zero_true_mutation_rejected": not (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				mutated_zero_physics,
				true,
			)
		),
		"pre_solver_body_mutation_rejected": not (
			BehaviorWorker.solver_coupled_application_receipt_valid_v2(
				mutated_pre_solver_body,
				false,
			)
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world_v1",
		"gate_id": "QSDK-R24D129",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_solver_coupled_application_mutation_semantics_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D129_ZERO_WORLD_CONJUNCTION_INVALID",
		"application_mutation_semantics_id": (
			RouteScript.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		),
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"predecessor_active_physics_state_modified": bool(
			predecessor_active.get("physics_state_modified", true)
		),
		"corrected_active_physics_state_modified": bool(
			corrected_active.get("physics_state_modified", false)
		),
		"corrected_matched_zero_physics_state_modified": bool(
			corrected_matched_zero.get("physics_state_modified", true)
		),
		"active_host_constraint_configuration_write_count": int(
			corrected_active.get("host_constraint_configuration_write_count", -1)
		),
		"pre_solver_rigid_body_state_modified": bool(
			corrected_active.get("pre_solver_rigid_body_state_modified", true)
		),
		"solver_state_advanced": bool(corrected_active.get("solver_state_advanced", true)),
		"r127_regression_receipt": inherited,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_world_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _active_receipt_exact(receipt: Dictionary) -> bool:
	return (
		bool(receipt.get("ok", false))
		and String(receipt.get("application_mutation_semantics_id", ""))
		== RouteScript.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		and int(receipt.get("motor_enabled_count", -1)) == 8
		and int(receipt.get("solver_coupled_motor_target_write_count", -1)) == 8
		and int(receipt.get("host_constraint_configuration_write_count", -1)) == 8
		and bool(receipt.get("active_constraint_motor_configuration_modified", false))
		and bool(receipt.get("physics_state_modified", false))
		and not bool(receipt.get("pre_solver_rigid_body_state_modified", true))
		and not bool(receipt.get("solver_state_advanced", true))
		and String(receipt.get("physics_state_mutation_scope", ""))
		== "constraint_motor_configuration_pre_solver"
	)


static func _matched_zero_receipt_exact(receipt: Dictionary) -> bool:
	return (
		bool(receipt.get("ok", false))
		and String(receipt.get("application_mutation_semantics_id", ""))
		== RouteScript.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		and int(receipt.get("motor_enabled_count", -1)) == 0
		and int(receipt.get("solver_coupled_motor_target_write_count", -1)) == 0
		and int(receipt.get("host_constraint_configuration_write_count", -1)) == 8
		and not bool(receipt.get("active_constraint_motor_configuration_modified", true))
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("pre_solver_rigid_body_state_modified", true))
		and not bool(receipt.get("solver_state_advanced", true))
		and String(receipt.get("physics_state_mutation_scope", "")) == "none"
	)


static func _matched_zero_control_v6() -> Dictionary:
	return {
		"schema_version": "sporespore_recovery_control_receipt_v1",
		"support_status": "supported_exact",
		"refusal_reason": null,
		"controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
		"controller_profile_sha256": "sha256:a764ea9f96bc9dbb00d594d87603aa87a95bf7a43c03085520952138f3989d33",
		"observation_sha256": null,
		"semantic_step": 1,
		"phase": "confirm_prone",
		"phase_step": 1,
		"owner": "none",
		"recovery_controller_active": false,
		"stance_handoff_requested": false,
		"matched_zero_command": true,
		"no_actuation_requested": true,
		"ordered_commands": [],
		"command_sha256": null,
		"controller_implemented": true,
		"deterministic": true,
		"engine_identity_input_count": 0,
		"engine_specific_policy_branch_count": 0,
		"fallback_controller_active": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world_v1",
		"gate_id": "QSDK-R24D129",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 6,
		"forced_failure_case_count": 5,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_world_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
