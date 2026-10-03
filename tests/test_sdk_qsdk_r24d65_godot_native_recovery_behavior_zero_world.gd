extends SceneTree
# gdlint: disable=max-line-length

## Compact zero-world exercise of the R65-only behavior composition: both arm
## initializers, true confirm-prone no-actuation, matched-zero no-actuation,
## recovery-owned active transport, stance-owned active transport, initial
## state hashing, and focused identity mutations. No Node enters a SceneTree.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_ZERO_WORLD "


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D65_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D65_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D65_ZERO_WORLD_CONTEXT_FAILED", context)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	if (
		not bool(blueprint.get("ok", false))
		or int(blueprint.get("model_construction_count", -1)) != 0
		or int(blueprint.get("world_attempt_count", -1)) != 0
		or int(blueprint.get("world_build_count", -1)) != 0
		or int(blueprint.get("solver_step_count", -1)) != 0
	):
		return _failure("QSDK_R24D65_ZERO_WORLD_BLUEPRINT_INVALID", blueprint)
	var candidate_initialization := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	var zero_initialization := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "matched_zero_command"
	)
	if (
		not bool(candidate_initialization.get("ok", false))
		or not bool(zero_initialization.get("ok", false))
		or String(candidate_initialization["memory"].get("phase", "")) != "confirm_prone"
		or String(zero_initialization["memory"].get("phase", "")) != "confirm_prone"
	):
		return _failure(
			"QSDK_R24D65_ZERO_WORLD_INITIALIZATION_INVALID",
			{"candidate": candidate_initialization, "matched_zero": zero_initialization},
		)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D65_ZERO_WORLD_FIXTURE_INVALID", fixture)
	var initial_state_sha256 := RouteScript.initial_state_sha256_v1(
		sdk, fixture["observation_v3"]
	)
	if not _valid_sha256(initial_state_sha256):
		return _failure("QSDK_R24D65_ZERO_WORLD_INITIAL_STATE_SHA_INVALID")
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D65_ZERO_WORLD_COMMAND_SURFACE_INVALID", surface)
	var positions: Dictionary = surface["position_by_joint_id"]
	var candidate_no_actuation := _no_actuation_control("candidate_command")
	var candidate_application := RouteScript.apply_behavior_control_v1(
		sdk,
		candidate_no_actuation,
		surface["joint_by_actuator_id"],
		positions,
		true,
	)
	var zero_no_actuation := _no_actuation_control("matched_zero_command")
	var zero_application := RouteScript.apply_behavior_control_v1(
		sdk,
		zero_no_actuation,
		surface["joint_by_actuator_id"],
		positions,
		true,
	)
	var recovery_route := RouteScript.collect_and_plan_v1(
		sdk, context, fixture, "establish_distal_support", 0
	)
	if not bool(recovery_route.get("ok", false)):
		RouteScript.free_zero_world_command_surface_v1(surface)
		return _failure("QSDK_R24D65_ZERO_WORLD_RECOVERY_CONTROL_INVALID", recovery_route)
	var recovery_control: Dictionary = recovery_route["control_receipt"]
	var recovery_application := RouteScript.apply_behavior_control_v1(
		sdk,
		recovery_control,
		surface["joint_by_actuator_id"],
		positions,
		true,
	)
	var stance_control := recovery_control.duplicate(true)
	stance_control["controller_id"] = RouteScript.STANCE_CONTROLLER_ID
	stance_control["owner"] = "stance"
	stance_control["phase"] = "stance_dwell"
	stance_control["recovery_controller_active"] = false
	stance_control["stance_handoff_requested"] = false
	var stance_application := RouteScript.apply_behavior_control_v1(
		sdk,
		stance_control,
		surface["joint_by_actuator_id"],
		positions,
		true,
	)
	var positive_controls := [
		bool(candidate_application.get("ok", false))
		and not bool(candidate_application.get("zero_command", true))
		and int(candidate_application.get("motor_enabled_count", -1)) == 0
		and String(candidate_application.get("controller_owner", "")) == "recovery",
		bool(zero_application.get("ok", false))
		and bool(zero_application.get("zero_command", false))
		and int(zero_application.get("motor_enabled_count", -1)) == 0
		and String(zero_application.get("controller_owner", "invalid")) == "none",
		bool(recovery_application.get("ok", false))
		and int(recovery_application.get("motor_enabled_count", -1)) == 8
		and String(recovery_application.get("controller_owner", "")) == "recovery",
		bool(stance_application.get("ok", false))
		and int(stance_application.get("motor_enabled_count", -1)) == 8
		and String(stance_application.get("controller_owner", "")) == "stance"
		and String(stance_application.get("stance_controller_id", ""))
		== RouteScript.STANCE_CONTROLLER_ID
		and int(stance_application.get("handoff_event_count", -1)) == 1,
	]
	var mutations: Array = []
	var active_zero := recovery_control.duplicate(true)
	active_zero["matched_zero_command"] = true
	mutations.append(
		_mutation(
			"matched_zero_active_control",
			RouteScript.apply_behavior_control_v1(
				sdk, active_zero, surface["joint_by_actuator_id"], positions, true
			),
		)
	)
	var no_actuation_with_digest := candidate_no_actuation.duplicate(true)
	no_actuation_with_digest["command_sha256"] = initial_state_sha256
	mutations.append(
		_mutation(
			"no_actuation_command_digest_present",
			RouteScript.apply_behavior_control_v1(
				sdk,
				no_actuation_with_digest,
				surface["joint_by_actuator_id"],
				positions,
				true,
			),
		)
	)
	var stance_overlap := stance_control.duplicate(true)
	stance_overlap["recovery_controller_active"] = true
	mutations.append(
		_mutation(
			"stance_recovery_owner_overlap",
			RouteScript.apply_behavior_control_v1(
				sdk, stance_overlap, surface["joint_by_actuator_id"], positions, true
			),
		)
	)
	var wrong_owner := recovery_control.duplicate(true)
	wrong_owner["owner"] = "none"
	mutations.append(
		_mutation(
			"active_control_owner_none",
			RouteScript.apply_behavior_control_v1(
				sdk, wrong_owner, surface["joint_by_actuator_id"], positions, true
			),
		)
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	var mutation_rejections := 0
	for mutation in mutations:
		if bool(mutation.get("rejected", false)):
			mutation_rejections += 1
	var ok := (
		positive_controls.all(func(value: Variant) -> bool: return bool(value))
		and mutation_rejections == mutations.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d65_godot_native_recovery_behavior_zero_world_v1",
		"gate_id": "QSDK-R24D65",
		"ok": ok,
		"candidate_initialization": candidate_initialization,
		"matched_zero_initialization": zero_initialization,
		"initial_state_sha256": initial_state_sha256,
		"candidate_no_actuation_application": candidate_application,
		"matched_zero_no_actuation_application": zero_application,
		"recovery_active_application": recovery_application,
		"stance_active_application": stance_application,
		"positive_control_count": positive_controls.size(),
		"positive_controls_passed": positive_controls.count(true),
		"mutation_rejections": mutations,
		"mutation_rejection_count": mutation_rejections,
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _no_actuation_control(arm_kind: String) -> Dictionary:
	var matched_zero := arm_kind == "matched_zero_command"
	return {
		"schema_version": "sporespore_recovery_control_receipt_v1",
		"support_status": "supported_exact",
		"refusal_reason": null,
		"controller_id": RouteScript.RECOVERY_CONTROLLER_ID,
		"controller_profile_sha256": (
			"sha256:0000000000000000000000000000000000000000000000000000000000000000"
		),
		"observation_sha256": null,
		"semantic_step": 1,
		"phase": "confirm_prone",
		"phase_step": 1,
		"owner": "none" if matched_zero else "recovery",
		"recovery_controller_active": not matched_zero,
		"stance_handoff_requested": false,
		"matched_zero_command": matched_zero,
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


static func _mutation(mutation_id: String, result: Dictionary) -> Dictionary:
	return {
		"mutation_id": mutation_id,
		"rejected": not bool(result.get("ok", false)),
		"failure_code": result.get("failure_code"),
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d65_godot_native_recovery_behavior_zero_world_v1",
		"gate_id": "QSDK-R24D65",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _valid_sha256(value: String) -> bool:
	return (
		value.length() == 71
		and value.begins_with("sha256:")
		and value.substr(7).is_valid_hex_number(false)
	)
