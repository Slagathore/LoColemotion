extends SceneTree
# gdlint: disable=max-line-length

## Compact R120 controller identity, command-ramp, route, refusal, and mutation
## proof. R117 is reused as the complete historical V1-V3 regression. Native-
## shaped observations and uninserted hinges are used; no model, world, or
## solver step exists.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const HistoricalControllerTest := preload(
	"res://tests/test_sdk_qsdk_r24d117_godot_support_speed_controller_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D120_RAISE_BODY_SPEED_ZERO_WORLD "
const SUPPORT_TARGETS := [0.60, -1.05, 0.60, -1.05, -0.60, 1.05, -0.60, 1.05]
const HALF_RAMP_TARGETS := [0.30, -0.525, 0.30, -0.525, -0.30, 0.525, -0.30, 0.525]
const STANCE_TARGETS := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const HISTORICAL_PROFILE_SHA256 := (
	"sha256:cfb1e98b75af5e72e9ee5775eec4b675b65704fd36a032a7514930059f7b548f"
)
const SUCCESSOR_PROFILE_SHA256 := (
	"sha256:2e9f4f5720aec96b28552a04c8f1b6bbfeb3b01eaceac76834b450cb0d9b4900"
)
const SUPPORT_COMMAND_SHA256 := (
	"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4"
)
const HISTORICAL_RAISE_COMMAND_SHA256 := [
	"sha256:c9b643dc31923b9c59389d21a3750e2cd6c800002b9b30faf7631d47823a4b2d",
	"sha256:32727a1340c791d9c2224c633908018ce113ddef686f0dc755a894b9d168f38f",
	"sha256:c37b949e24558a92b1656b7b773d63e294152264b35c9f7623674a1eb202e545",
]
const SUCCESSOR_RAISE_COMMAND_SHA256 := [
	"sha256:0df94734d9a92f80ac9fb3dbc9fca291596ecec7a608926115c14aade09209c4",
	"sha256:fd799c70aa596c6f1ce9e8edfa31ed381ff2cb598b820fad9926ce22749b7f2a",
	"sha256:9282c43fdecacd25f8524775ce87f87297fa3d1f2ba99d7e9d8fc3e5ab450022",
]


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var historical_regression := HistoricalControllerTest._evaluate()
	if not bool(historical_regression.get("ok", false)):
		return _failure("QSDK_R24D120_HISTORICAL_REGRESSION_FAILED", historical_regression)
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D120_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D120_EXTENSION_INSTANTIATION_FAILED")

	var historical_context := RouteScript.prepare_context_v3(
		sdk, RouteScript.RECOVERY_CONTROLLER_V3_ID
	)
	var successor_context := RouteScript.prepare_context_v4(
		sdk, RouteScript.RECOVERY_CONTROLLER_V4_ID
	)
	if (
		not bool(historical_context.get("ok", false))
		or not bool(successor_context.get("ok", false))
	):
		return _failure(
			"QSDK_R24D120_CONTEXT_FAILED",
			{"historical": historical_context, "successor": successor_context},
		)

	var historical_bound := RouteScript.zero_world_fixture_v3(sdk, historical_context)
	var successor_bound := RouteScript.zero_world_fixture_v4(sdk, successor_context)
	if (
		not bool(historical_bound.get("ok", false))
		or not bool(successor_bound.get("ok", false))
	):
		return _failure(
			"QSDK_R24D120_FIXTURE_FAILED",
			{"historical": historical_bound, "successor": successor_bound},
		)

	var historical_support_route := RouteScript.collect_and_plan_v1(
		sdk, historical_context, historical_bound, "establish_distal_support", 0
	)
	var successor_support_route := RouteScript.collect_and_plan_v1(
		sdk, successor_context, successor_bound, "establish_distal_support", 0
	)
	if (
		not bool(historical_support_route.get("ok", false))
		or not bool(successor_support_route.get("ok", false))
	):
		return _failure(
			"QSDK_R24D120_SUPPORT_ROUTE_FAILED",
			{"historical": historical_support_route, "successor": successor_support_route},
		)
	var historical_support: Dictionary = historical_support_route["control_receipt"]
	var successor_support: Dictionary = successor_support_route["control_receipt"]

	var phase_steps := [0, 180, 360]
	var expected_targets := [SUPPORT_TARGETS, HALF_RAMP_TARGETS, STANCE_TARGETS]
	var historical_raise_controls: Array = []
	var successor_raise_controls: Array = []
	var historical_raise_hashes: Array = []
	var successor_raise_hashes: Array = []
	var observed_raise_targets: Array = []
	var changed_speed_count := 0
	var non_speed_command_fields_identical := true
	for phase_index in range(phase_steps.size()):
		var phase_step: int = phase_steps[phase_index]
		var historical_route := RouteScript.collect_and_plan_v1(
			sdk, historical_context, historical_bound, "raise_body", phase_step
		)
		var successor_route := RouteScript.collect_and_plan_v1(
			sdk, successor_context, successor_bound, "raise_body", phase_step
		)
		if (
			not bool(historical_route.get("ok", false))
			or not bool(successor_route.get("ok", false))
		):
			return _failure(
				"QSDK_R24D120_RAISE_ROUTE_FAILED",
				{
					"phase_step": phase_step,
					"historical": historical_route,
					"successor": successor_route,
				},
			)
		var historical_control: Dictionary = historical_route["control_receipt"]
		var successor_control: Dictionary = successor_route["control_receipt"]
		var historical_commands: Array = historical_control["ordered_commands"]
		var successor_commands: Array = successor_control["ordered_commands"]
		historical_raise_controls.append(historical_control)
		successor_raise_controls.append(successor_control)
		historical_raise_hashes.append(String(historical_control.get("command_sha256", "")))
		successor_raise_hashes.append(String(successor_control.get("command_sha256", "")))
		var targets := _command_values(successor_commands, "target_position_rad")
		observed_raise_targets.append(targets)
		non_speed_command_fields_identical = (
			non_speed_command_fields_identical
			and historical_commands.size() == 8
			and successor_commands.size() == 8
			and targets == expected_targets[phase_index]
		)
		for command_index in range(mini(historical_commands.size(), successor_commands.size())):
			var historical_command: Dictionary = historical_commands[command_index]
			var successor_command: Dictionary = successor_commands[command_index]
			if float(historical_command.get("maximum_target_speed_rad_s", NAN)) != float(
				successor_command.get("maximum_target_speed_rad_s", NAN)
			):
				changed_speed_count += 1
			var historical_non_speed := historical_command.duplicate(true)
			var successor_non_speed := successor_command.duplicate(true)
			historical_non_speed.erase("maximum_target_speed_rad_s")
			successor_non_speed.erase("maximum_target_speed_rad_s")
			non_speed_command_fields_identical = (
				non_speed_command_fields_identical
				and JsonTransportScript.stringify(historical_non_speed)
				== JsonTransportScript.stringify(successor_non_speed)
			)

	var v4_with_v3_observation := RouteScript.collect_and_plan_v1(
		sdk, successor_context, historical_bound, "raise_body", 0
	)
	var v3_with_v4_observation := RouteScript.collect_and_plan_v1(
		sdk, historical_context, successor_bound, "raise_body", 0
	)
	var cross_version_observation_refusal_count := (
		int(_is_ownership_mismatch_refusal(v4_with_v3_observation))
		+ int(_is_ownership_mismatch_refusal(v3_with_v4_observation))
	)
	var invalid_context := RouteScript.prepare_context_v4(sdk, "unregistered_controller")

	var surface := RouteScript.zero_world_command_surface_v1(successor_context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D120_COMMAND_SURFACE_FAILED", surface)
	var successor_raise_zero: Dictionary = successor_raise_controls[0]
	var successor_commands: Array = successor_raise_zero["ordered_commands"]
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
	var bootstrap_application := RouteScript.initial_behavior_application_v4(
		sdk,
		bootstrap_model,
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V4_ID,
	)
	var unknown_bootstrap_application := RouteScript.initial_behavior_application_v4(
		sdk,
		bootstrap_model,
		"candidate_command",
		"confirm_prone",
		"unregistered_controller",
	)
	var application := RouteScript.apply_behavior_control_v1(
		sdk,
		successor_raise_zero,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	var target_mutation := successor_raise_zero.duplicate(true)
	(target_mutation["ordered_commands"] as Array)[0]["target_position_rad"] = 0.59
	var target_mutation_application := RouteScript.apply_behavior_control_v1(
		sdk,
		target_mutation,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	var speed_mutation := successor_raise_zero.duplicate(true)
	(speed_mutation["ordered_commands"] as Array)[0]["maximum_target_speed_rad_s"] = 0.75
	var speed_mutation_application := RouteScript.apply_behavior_control_v1(
		sdk,
		speed_mutation,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	var unknown_control := successor_raise_zero.duplicate(true)
	unknown_control["controller_id"] = "unregistered_controller"
	var unknown_application := RouteScript.apply_behavior_control_v1(
		sdk,
		unknown_control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	var command_mutation_refusal_count := (
		int(
			String(target_mutation_application.get("failure_code", ""))
			== "QSDK_R24D57_COMMAND_DIGEST_INVALID"
		)
		+ int(
			String(speed_mutation_application.get("failure_code", ""))
			== "QSDK_R24D57_COMMAND_DIGEST_INVALID"
		)
	)
	var unregistered_controller_refusal_count := (
		int(
			String(invalid_context.get("failure_code", ""))
			== "QSDK_R24D120_CONTROLLER_ID_INVALID"
		)
		+ int(
			String(unknown_bootstrap_application.get("failure_code", ""))
			== "QSDK_R24D120_INITIAL_CONTROLLER_ID_INVALID"
		)
		+ int(
			String(unknown_application.get("failure_code", ""))
			== "QSDK_R24D65_ACTIVE_CONTROL_OWNER_INVALID"
		)
	)

	var support_commands_preserved := (
		String(historical_support.get("command_sha256", "")) == SUPPORT_COMMAND_SHA256
		and String(successor_support.get("command_sha256", "")) == SUPPORT_COMMAND_SHA256
		and JsonTransportScript.stringify(historical_support["ordered_commands"])
		== JsonTransportScript.stringify(successor_support["ordered_commands"])
	)
	var exact := (
		String(historical_support.get("controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V3_ID
		and String(successor_support.get("controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V4_ID
		and String(historical_support.get("controller_profile_sha256", ""))
		== HISTORICAL_PROFILE_SHA256
		and String(successor_support.get("controller_profile_sha256", ""))
		== SUCCESSOR_PROFILE_SHA256
		and support_commands_preserved
		and historical_raise_hashes == HISTORICAL_RAISE_COMMAND_SHA256
		and successor_raise_hashes == SUCCESSOR_RAISE_COMMAND_SHA256
		and observed_raise_targets == expected_targets
		and changed_speed_count == 24
		and non_speed_command_fields_identical
		and _all_speeds(historical_raise_controls, 0.75)
		and _all_speeds(successor_raise_controls, 8.0)
		and cross_version_observation_refusal_count == 2
		and command_mutation_refusal_count == 2
		and unregistered_controller_refusal_count == 3
		and bool(bootstrap_application.get("ok", false))
		and String(bootstrap_application.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V4_ID
		and int(bootstrap_application.get("motor_enabled_count", -1)) == 0
		and bool(application.get("ok", false))
		and String(application.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V4_ID
		and int(application.get("validated_command_count", -1)) == 8
		and int(application.get("host_write_count", -1)) == 8
	)
	return {
		"schema_version": "sporespore_qsdk_r24d120_godot_raise_body_speed_controller_zero_world_v1",
		"gate_id": "QSDK-R24D120",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_versioned_raise_body_speed_implementation",
			"question_class": "development",
		},
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D120_ZERO_WORLD_CONJUNCTION_INVALID",
		"historical_controller_id": String(historical_support.get("controller_id", "")),
		"successor_controller_id": String(successor_support.get("controller_id", "")),
		"historical_controller_profile_sha256": String(
			historical_support.get("controller_profile_sha256", "")
		),
		"successor_controller_profile_sha256": String(
			successor_support.get("controller_profile_sha256", "")
		),
		"support_command_sha256": String(successor_support.get("command_sha256", "")),
		"support_commands_preserved": support_commands_preserved,
		"raise_body_phase_steps": phase_steps,
		"historical_raise_body_command_sha256": historical_raise_hashes,
		"successor_raise_body_command_sha256": successor_raise_hashes,
		"observed_raise_body_targets_rad": observed_raise_targets,
		"changed_speed_count": changed_speed_count,
		"non_speed_command_fields_identical": non_speed_command_fields_identical,
		"cross_version_observation_refusal_count": cross_version_observation_refusal_count,
		"command_mutation_refusal_count": command_mutation_refusal_count,
		"unregistered_controller_refusal_count": unregistered_controller_refusal_count,
		"historical_v1_v3_regression_passed": bool(historical_regression.get("ok", false)),
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


static func _all_speeds(controls: Array, expected_speed: float) -> bool:
	for control_value in controls:
		var control: Dictionary = control_value
		if _command_values(control["ordered_commands"], "maximum_target_speed_rad_s") != [
			expected_speed,
			expected_speed,
			expected_speed,
			expected_speed,
			expected_speed,
			expected_speed,
			expected_speed,
			expected_speed,
		]:
			return false
	return true


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
		"schema_version": "sporespore_qsdk_r24d120_godot_raise_body_speed_controller_zero_world_v1",
		"gate_id": "QSDK-R24D120",
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
