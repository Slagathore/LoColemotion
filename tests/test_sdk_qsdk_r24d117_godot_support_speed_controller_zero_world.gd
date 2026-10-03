extends SceneTree
# gdlint: disable=max-line-length

## Compact R117 controller-speed and production-route proof. R113 is reused as
## the historical V1/V2 regression. This test uses native-shaped observations
## and uninserted hinge objects only: no model, world, or solver step exists.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const HistoricalControllerTest := preload(
	"res://tests/test_sdk_qsdk_r24d113_godot_mirrored_front_knee_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D117_SUPPORT_SPEED_ZERO_WORLD "
const SUPPORT_TARGETS := [0.60, -1.05, 0.60, -1.05, -0.60, 1.05, -0.60, 1.05]
const HISTORICAL_COMMAND_SHA256 := (
	"sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
)
const SUCCESSOR_COMMAND_SHA256 := (
	"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
)
const HISTORICAL_PROFILE_SHA256 := (
	"sha256:79bbc8be5aa6102f78e457731c3ef43f144c9f52ffac39aeda3a0475dc89d2f4"
)
const SUCCESSOR_PROFILE_SHA256 := (
	"sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
)


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var historical_regression := HistoricalControllerTest._evaluate()
	if not bool(historical_regression.get("ok", false)):
		return _failure("QSDK_R24D117_HISTORICAL_REGRESSION_FAILED", historical_regression)
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D117_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D117_EXTENSION_INSTANTIATION_FAILED")

	var historical_context := RouteScript.prepare_context_v2(
		sdk, RouteScript.RECOVERY_CONTROLLER_V2_ID
	)
	var successor_context := RouteScript.prepare_context_v3(
		sdk, RouteScript.RECOVERY_CONTROLLER_V3_ID
	)
	if (
		not bool(historical_context.get("ok", false))
		or not bool(successor_context.get("ok", false))
	):
		return _failure(
			"QSDK_R24D117_CONTEXT_FAILED",
			{"historical": historical_context, "successor": successor_context},
		)

	var historical_bound := RouteScript.zero_world_fixture_v2(sdk, historical_context)
	var successor_bound := RouteScript.zero_world_fixture_v3(sdk, successor_context)
	if (
		not bool(historical_bound.get("ok", false))
		or not bool(successor_bound.get("ok", false))
	):
		return _failure(
			"QSDK_R24D117_FIXTURE_FAILED",
			{"historical": historical_bound, "successor": successor_bound},
		)

	var historical_route := RouteScript.collect_and_plan_v1(
		sdk, historical_context, historical_bound, "establish_distal_support", 0
	)
	var successor_route := RouteScript.collect_and_plan_v1(
		sdk, successor_context, successor_bound, "establish_distal_support", 0
	)
	if (
		not bool(historical_route.get("ok", false))
		or not bool(successor_route.get("ok", false))
	):
		return _failure(
			"QSDK_R24D117_CONTROL_ROUTE_FAILED",
			{"historical": historical_route, "successor": successor_route},
		)

	var historical_control: Dictionary = historical_route["control_receipt"]
	var successor_control: Dictionary = successor_route["control_receipt"]
	var historical_commands: Array = historical_control["ordered_commands"]
	var successor_commands: Array = successor_control["ordered_commands"]
	var historical_targets := _command_values(historical_commands, "target_position_rad")
	var successor_targets := _command_values(successor_commands, "target_position_rad")
	var historical_speeds := _command_values(
		historical_commands, "maximum_target_speed_rad_s"
	)
	var successor_speeds := _command_values(
		successor_commands, "maximum_target_speed_rad_s"
	)
	var changed_speed_indices: Array = []
	var non_speed_command_fields_identical := historical_commands.size() == 8
	for index in range(mini(historical_commands.size(), successor_commands.size())):
		var historical_command: Dictionary = historical_commands[index]
		var successor_command: Dictionary = successor_commands[index]
		if float(historical_command.get("maximum_target_speed_rad_s", NAN)) != float(
			successor_command.get("maximum_target_speed_rad_s", NAN)
		):
			changed_speed_indices.append(index)
		var historical_non_speed := historical_command.duplicate(true)
		var successor_non_speed := successor_command.duplicate(true)
		historical_non_speed.erase("maximum_target_speed_rad_s")
		successor_non_speed.erase("maximum_target_speed_rad_s")
		non_speed_command_fields_identical = (
			non_speed_command_fields_identical
			and JsonTransportScript.stringify(historical_non_speed)
			== JsonTransportScript.stringify(successor_non_speed)
		)

	var v3_with_v2_observation := RouteScript.collect_and_plan_v1(
		sdk, successor_context, historical_bound, "establish_distal_support", 0
	)
	var v2_with_v3_observation := RouteScript.collect_and_plan_v1(
		sdk, historical_context, successor_bound, "establish_distal_support", 0
	)
	var cross_version_observation_refusal_count := (
		int(_is_ownership_mismatch_refusal(v3_with_v2_observation))
		+ int(_is_ownership_mismatch_refusal(v2_with_v3_observation))
	)
	var invalid_context := RouteScript.prepare_context_v3(sdk, "unregistered_controller")

	var surface := RouteScript.zero_world_command_surface_v1(successor_context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D117_COMMAND_SURFACE_FAILED", surface)
	var zero_world_joint_nodes := {}
	for command_value in successor_commands:
		var command: Dictionary = command_value
		zero_world_joint_nodes[String(command["joint_id"])] = surface[
			"joint_by_actuator_id"
		][String(command["actuator_id"])]
	var bootstrap_model := {
		"ok": true,
		"host_step_count": 0,
		"joint_nodes": zero_world_joint_nodes,
	}
	var bootstrap_application := RouteScript.initial_behavior_application_v3(
		sdk,
		bootstrap_model,
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V3_ID,
	)
	var unknown_bootstrap_application := RouteScript.initial_behavior_application_v3(
		sdk,
		bootstrap_model,
		"candidate_command",
		"confirm_prone",
		"unregistered_controller",
	)
	var application := RouteScript.apply_behavior_control_v1(
		sdk,
		successor_control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	var unknown_control := successor_control.duplicate(true)
	unknown_control["controller_id"] = "unregistered_controller"
	var unknown_application := RouteScript.apply_behavior_control_v1(
		sdk,
		unknown_control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	var unregistered_controller_refusal_count := (
		int(
			String(invalid_context.get("failure_code", ""))
			== "QSDK_R24D117_CONTROLLER_ID_INVALID"
		)
		+ int(
			String(unknown_bootstrap_application.get("failure_code", ""))
			== "QSDK_R24D117_INITIAL_CONTROLLER_ID_INVALID"
		)
		+ int(
			String(unknown_application.get("failure_code", ""))
			== "QSDK_R24D65_ACTIVE_CONTROL_OWNER_INVALID"
		)
	)

	var exact := (
		String(historical_control.get("controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V2_ID
		and String(successor_control.get("controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V3_ID
		and String(historical_control.get("command_sha256", ""))
		== HISTORICAL_COMMAND_SHA256
		and String(successor_control.get("command_sha256", ""))
		== SUCCESSOR_COMMAND_SHA256
		and String(historical_control.get("controller_profile_sha256", ""))
		== HISTORICAL_PROFILE_SHA256
		and String(successor_control.get("controller_profile_sha256", ""))
		== SUCCESSOR_PROFILE_SHA256
		and historical_targets == SUPPORT_TARGETS
		and successor_targets == SUPPORT_TARGETS
		and historical_speeds == [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
		and successor_speeds == [8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0]
		and changed_speed_indices == [0, 1, 2, 3, 4, 5, 6, 7]
		and non_speed_command_fields_identical
		and cross_version_observation_refusal_count == 2
		and unregistered_controller_refusal_count == 3
		and bool(bootstrap_application.get("ok", false))
		and String(bootstrap_application.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V3_ID
		and int(bootstrap_application.get("motor_enabled_count", -1)) == 0
		and bool(application.get("ok", false))
		and String(application.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V3_ID
		and int(application.get("validated_command_count", -1)) == 8
		and int(application.get("host_write_count", -1)) == 8
	)
	return {
		"schema_version": "sporespore_qsdk_r24d117_godot_support_speed_controller_zero_world_v1",
		"gate_id": "QSDK-R24D117",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_versioned_controller_speed_implementation",
			"question_class": "development",
		},
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D117_ZERO_WORLD_CONJUNCTION_INVALID",
		"historical_controller_id": String(historical_control.get("controller_id", "")),
		"successor_controller_id": String(successor_control.get("controller_id", "")),
		"historical_controller_profile_sha256": String(
			historical_control.get("controller_profile_sha256", "")
		),
		"successor_controller_profile_sha256": String(
			successor_control.get("controller_profile_sha256", "")
		),
		"historical_command_sha256": String(historical_control.get("command_sha256", "")),
		"successor_command_sha256": String(successor_control.get("command_sha256", "")),
		"historical_targets_rad": historical_targets,
		"successor_targets_rad": successor_targets,
		"historical_maximum_target_speeds_rad_s": historical_speeds,
		"successor_maximum_target_speeds_rad_s": successor_speeds,
		"changed_speed_indices": changed_speed_indices,
		"changed_speed_count": changed_speed_indices.size(),
		"non_speed_command_fields_identical": non_speed_command_fields_identical,
		"cross_version_observation_refusal_count": cross_version_observation_refusal_count,
		"unregistered_controller_refusal_count": unregistered_controller_refusal_count,
		"historical_v1_v2_regression_passed": bool(historical_regression.get("ok", false)),
		"zero_world_bootstrap_application_passed": bool(
			bootstrap_application.get("ok", false)
		),
		"zero_world_application_passed": bool(application.get("ok", false)),
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


static func _is_ownership_mismatch_refusal(value: Dictionary) -> bool:
	var detail_value: Variant = value.get("detail")
	if not (detail_value is Dictionary):
		return false
	var detail: Dictionary = detail_value
	return (
		String(value.get("failure_code", "")) == "QSDK_R24D57_CONTROL_REFUSED"
		and String(detail.get("support_status", "")) == "invalid_observation"
		and String(detail.get("refusal_reason", ""))
		== "recovery_controller_ownership_mismatch"
		and (detail.get("ordered_commands") is Array)
		and (detail["ordered_commands"] as Array).is_empty()
	)


static func _command_values(commands: Array, field: String) -> Array:
	var values: Array = []
	for command_value in commands:
		var command: Dictionary = command_value
		values.append(float(command.get(field, NAN)))
	return values


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d117_godot_support_speed_controller_zero_world_v1",
		"gate_id": "QSDK-R24D117",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
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
