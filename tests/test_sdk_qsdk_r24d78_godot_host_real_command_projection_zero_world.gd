extends SceneTree
# gdlint: disable=max-line-length

## Focused zero-world proof that the production recovery command path projects
## non-binary32-exact velocities before the Godot host write, retains the
## projection, and receives an exact projected readback. No Node enters a tree.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D78_GODOT_HOST_REAL_COMMAND_PROJECTION_ZERO_WORLD "
const OUTER_STEP_DURATION_S := 1.0 / 120.0


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D78_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D78_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D78_ZERO_WORLD_CONTEXT_FAILED", context)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D78_ZERO_WORLD_FIXTURE_FAILED", fixture)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D78_ZERO_WORLD_COMMAND_SURFACE_FAILED", surface)
	var recovery_route := RouteScript.collect_and_plan_v1(
		sdk,
		context,
		fixture,
		"establish_distal_support",
		0,
	)
	if not bool(recovery_route.get("ok", false)):
		RouteScript.free_zero_world_command_surface_v1(surface)
		return _failure("QSDK_R24D78_ZERO_WORLD_RECOVERY_CONTROL_FAILED", recovery_route)
	var recovery_control: Dictionary = recovery_route["control_receipt"]
	var commands_value: Variant = recovery_control.get("ordered_commands")
	if not (commands_value is Array) or (commands_value as Array).size() != 8:
		RouteScript.free_zero_world_command_surface_v1(surface)
		return _failure("QSDK_R24D78_ZERO_WORLD_COMMANDS_INVALID")
	var commands: Array = commands_value
	var positions: Dictionary = surface["position_by_joint_id"]
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		var maximum_speed := float(command["maximum_target_speed_rad_s"])
		var requested_velocity := maximum_speed * (0.21 + 0.031 * float(index))
		positions[String(command["joint_id"])] = (
			float(command["target_position_rad"])
			- requested_velocity * OUTER_STEP_DURATION_S
		)
	var application := RouteScript.apply_behavior_control_v1(
		sdk,
		recovery_control,
		surface["joint_by_actuator_id"],
		positions,
		true,
	)
	if not bool(application.get("ok", false)):
		RouteScript.free_zero_world_command_surface_v1(surface)
		return _failure("QSDK_R24D78_ZERO_WORLD_APPLICATION_FAILED", application)
	var ordered_receipts_value: Variant = application.get("ordered_receipts")
	if not (ordered_receipts_value is Array) or (ordered_receipts_value as Array).size() != 8:
		RouteScript.free_zero_world_command_surface_v1(surface)
		return _failure("QSDK_R24D78_ZERO_WORLD_APPLICATION_RECEIPTS_INVALID")
	var ordered_receipts: Array = ordered_receipts_value
	var non_exact_projection_count := 0
	var exact_readback_count := 0
	for receipt_value in ordered_receipts:
		if not (receipt_value is Dictionary):
			RouteScript.free_zero_world_command_surface_v1(surface)
			return _failure("QSDK_R24D78_ZERO_WORLD_APPLICATION_RECEIPT_INVALID")
		var receipt: Dictionary = receipt_value
		var projection: Dictionary = receipt.get("host_real_command_projection", {})
		var readback: Dictionary = receipt.get("host_real_command_readback", {})
		if (
			not bool(projection.get("ok", false))
			or String(projection.get("host_real_format", ""))
			!= "ieee_754_binary32"
			or not bool(
				projection.get("projected_command_within_published_speed", false)
			)
			or float(projection.get("absolute_quantization_error_rad_s", INF))
			> float(projection.get("maximum_quantization_error_bound_rad_s", -INF))
			or not bool(readback.get("ok", false))
		):
			RouteScript.free_zero_world_command_surface_v1(surface)
			return _failure(
				"QSDK_R24D78_ZERO_WORLD_PROJECTION_RECEIPT_INVALID",
				receipt,
			)
		if float(projection["absolute_quantization_error_rad_s"]) > 0.0:
			non_exact_projection_count += 1
		if (
			bool(readback.get("exact_projected_readback", false))
			and float(readback.get("host_readback_error_rad_s", INF)) == 0.0
		):
			exact_readback_count += 1
	var direct_projection := RouteScript.godot_host_real_command_projection_v1(
		0.123456789,
		1.0,
	)
	var mutations := [
		_mutation(
			"command_above_published_speed",
			RouteScript.godot_host_real_command_projection_v1(1.0001, 1.0),
		),
		_mutation(
			"projection_receipt_tamper",
			_validate_tampered_projection(direct_projection),
		),
		_mutation(
			"host_readback_mismatch",
			RouteScript.validate_godot_host_real_command_readback_v1(
				direct_projection,
				float(direct_projection.get("godot_projected_target_velocity_rad_s", 0.0))
				+ 0.01,
			),
		),
	]
	RouteScript.free_zero_world_command_surface_v1(surface)
	var mutation_rejection_count := 0
	for mutation in mutations:
		if bool(mutation.get("rejected", false)):
			mutation_rejection_count += 1
	var ok := (
		bool(direct_projection.get("ok", false))
		and float(direct_projection.get("absolute_quantization_error_rad_s", 0.0))
		> 0.0
		and non_exact_projection_count > 0
		and exact_readback_count == 8
		and mutation_rejection_count == mutations.size()
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d78_godot_host_real_command_projection_zero_world_v1"
		),
		"gate_id": "QSDK-R24D78",
		"ok": ok,
		"actual_production_application_count": 1,
		"validated_command_count": int(application.get("validated_command_count", -1)),
		"host_write_count": int(application.get("host_write_count", -1)),
		"host_readback_count": int(application.get("host_readback_count", -1)),
		"non_binary32_exact_projection_count": non_exact_projection_count,
		"exact_projected_readback_count": exact_readback_count,
		"direct_projection": direct_projection,
		"mutation_rejections": mutations,
		"mutation_rejection_count": mutation_rejection_count,
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


static func _validate_tampered_projection(projection: Dictionary) -> Dictionary:
	var tampered := projection.duplicate(true)
	tampered["godot_projected_target_velocity_rad_s"] = (
		float(tampered.get("godot_projected_target_velocity_rad_s", 0.0)) + 0.01
	)
	return RouteScript.validate_godot_host_real_command_readback_v1(
		tampered,
		float(tampered["godot_projected_target_velocity_rad_s"]),
	)


static func _mutation(mutation_id: String, result: Dictionary) -> Dictionary:
	return {
		"mutation_id": mutation_id,
		"rejected": not bool(result.get("ok", false)),
		"failure_code": result.get("failure_code"),
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d78_godot_host_real_command_projection_zero_world_v1"
		),
		"gate_id": "QSDK-R24D78",
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
