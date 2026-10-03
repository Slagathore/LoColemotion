extends SceneTree
# gdlint: disable=max-line-length

## Zero-world route qualification for the exact instrumented Godot/Jolt
## recovery surface. The native-shaped observation fixture is synthetic, while
## the pure native-world blueprint proves the exact production topology and
## initializer without constructing a Node, RID, model, or world.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var expected_profile := _expected_profile()
	if expected_profile not in ["instrumented", "stock"]:
		return _failure("QSDK_R24D57_EXPECTED_PROFILE_INVALID")
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D57_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D57_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_context_v1(sdk)
	if expected_profile == "stock":
		var stock_exact := (
			not bool(context.get("ok", false))
			and String(context.get("failure_code", ""))
			== "QSDK_R24D57_EXACT_INSTRUMENTED_PROFILE_REQUIRED"
		)
		return {
			"schema_version": "sporespore_qsdk_r24d57_godot_native_recovery_route_zero_world_v1",
			"gate_id": "QSDK-R24D57",
			"ok": stock_exact,
			"failure_code": "" if stock_exact else "QSDK_R24D57_STOCK_ROUTE_NOT_REFUSED",
			"expected_profile": expected_profile,
			"instrumented_profile_selected": false,
			"stock_runtime_route_refusal_count": int(stock_exact),
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
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D57_CONTEXT_FAILED", context)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	if not bool(blueprint.get("ok", false)):
		return _failure("QSDK_R24D57_WORLD_BLUEPRINT_FAILED", blueprint)

	var bound := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D57_FIXTURE_FAILED", bound)
	var route := RouteScript.collect_and_plan_v1(
		sdk, context, bound, "establish_distal_support", 0
	)
	if not bool(route.get("ok", false)):
		return _failure("QSDK_R24D57_COLLECTION_OR_CONTROL_FAILED", route)
	var supervisor := RouteScript.initialize_and_step_v4(sdk, context, bound)
	if not bool(supervisor.get("ok", false)):
		return _failure("QSDK_R24D57_SUPERVISOR_FAILED", supervisor)

	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D57_COMMAND_SURFACE_FAILED", surface)
	var control: Dictionary = route["control_receipt"]
	var mutation_results := _mutations(sdk, context, bound, control, surface)
	var mutation_rejection_count := 0
	for rejected in mutation_results.values():
		mutation_rejection_count += int(bool(rejected))
	var application := RouteScript.apply_control_v1(
		sdk,
		control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	if not bool(application.get("ok", false)):
		return _failure("QSDK_R24D57_COMMAND_APPLICATION_FAILED", application)

	var collection: Dictionary = route["collection_receipt"]
	var step: Dictionary = supervisor["step_receipt"]
	var source_binding: Dictionary = bound["source_binding"]
	var exact := (
		String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d57_godot_recovery_route_context_v1"
		and String(blueprint.get("schema_version", ""))
		== "sporespore_qsdk_r24d57_godot_recovery_world_blueprint_v1"
		and String(blueprint.get("world_route_id", ""))
		== "sporespore_qsdk_r24d57_godot_jolt_recovery_native_world_v1"
		and String(blueprint.get("initializer_manifest_sha256", "")).begins_with("sha256:")
		and int((blueprint.get("body_by_id", {}) as Dictionary).size()) == 9
		and int((blueprint.get("joint_by_id", {}) as Dictionary).size()) == 8
		and int((blueprint.get("contact_by_id", {}) as Dictionary).size()) == 4
		and int(blueprint.get("model_construction_count", -1)) == 0
		and int(blueprint.get("world_build_count", -1)) == 0
		and String(source_binding.get("source_route_id", "")) == RouteScript.ROUTE_ID
		and String(source_binding.get("mapping_profile_id", ""))
		== RouteScript.ENERGY_MAPPING_PROFILE_ID
		and String(collection.get("support_status", "")) == "supported_exact"
		and bool(collection.get("supplied_native_post_step_observation_validated", false))
		and String(control.get("support_status", "")) == "supported_exact"
		and int((control.get("ordered_commands", []) as Array).size()) == 8
		and String(step.get("support_status", "")) == "supported_exact"
		and int(application.get("validated_command_count", -1)) == 8
		and int(application.get("host_write_count", -1)) == 8
		and int(application.get("adapter_side_discrete_staging_event_count", -1)) == 0
		and int(bound.get("adapter_side_discrete_staging_event_count", -1)) == 0
		and int(bound.get("missing_measurement_synthesis_count", -1)) == 0
		and mutation_rejection_count == mutation_results.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_recovery_route_zero_world_v1",
		"gate_id": "QSDK-R24D57",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D57_ZERO_WORLD_CONJUNCTION_INVALID",
		"expected_profile": expected_profile,
		"instrumented_profile_selected": true,
		"route_id": RouteScript.ROUTE_ID,
		"mapping_profile_id": RouteScript.ENERGY_MAPPING_PROFILE_ID,
		"native_world_blueprint_count": 1,
		"native_world_blueprint_body_count": (
			blueprint.get("body_by_id", {}) as Dictionary
		).size(),
		"native_world_blueprint_joint_count": (
			blueprint.get("joint_by_id", {}) as Dictionary
		).size(),
		"native_world_blueprint_contact_site_count": (
			blueprint.get("contact_by_id", {}) as Dictionary
		).size(),
		"native_world_initializer_manifest_sha256": String(
			blueprint.get("initializer_manifest_sha256", "")
		),
		"collection_support_status": String(collection.get("support_status", "")),
		"source_bound_observation_validated": bool(
			collection.get("supplied_native_post_step_observation_validated", false)
		),
		"control_support_status": String(control.get("support_status", "")),
		"ordered_command_count": (control.get("ordered_commands", []) as Array).size(),
		"step_v4_support_status": String(step.get("support_status", "")),
		"validated_command_count": int(application.get("validated_command_count", -1)),
		"host_write_count": int(application.get("host_write_count", -1)),
		"host_readback_count": int(application.get("host_readback_count", -1)),
		"adapter_side_discrete_staging_event_count": int(
			bound.get("adapter_side_discrete_staging_event_count", -1)
		),
		"missing_measurement_synthesis_count": int(
			bound.get("missing_measurement_synthesis_count", -1)
		),
		"mutation_ids": mutation_results.keys(),
		"mutation_rejection_count": mutation_rejection_count,
		"forced_failure_route_control_count": 1,
		"synthetic_native_shape_fixture_count": 1,
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


static func _mutations(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	control: Dictionary,
	surface: Dictionary,
) -> Dictionary:
	var wrong_route := RouteScript.collection_request_v1(
		context, bound, "candidate_command", "establish_distal_support"
	)
	(wrong_route["observation_source_binding"] as Dictionary)["source_route_id"] = "wrong_route"
	var wrong_route_receipt := RecoveryRuntimeScript.collect_native_v3(sdk, wrong_route)

	var wrong_mapping := RouteScript.collection_request_v1(
		context, bound, "candidate_command", "establish_distal_support"
	)
	(wrong_mapping["observation_source_binding"] as Dictionary)["mapping_profile_id"] = "wrong_mapping"
	var wrong_mapping_receipt := RecoveryRuntimeScript.collect_native_v3(sdk, wrong_mapping)

	var missing_staging := RouteScript.compose_observations_v1(
		sdk,
		context,
		{},
		{
			"schema_version": "missing_staging",
			"semantic_step": 1,
			"initial_mechanical_energy_j": 0.0,
			"current_mechanical_energy_j": 0.0,
			"cumulative_applied_actuator_work_j": 0.0,
			"cumulative_signed_external_work_j": 0.0,
			"cumulative_signed_constraint_exchange_j": 0.0,
			"cumulative_signed_discrete_staging_exchange_j": 0.0,
			"cumulative_passive_dissipation_j": 0.0,
			"source_measurement": true,
		},
		{"source_measurement": true},
	)
	var nonzero_staging := RouteScript.compose_observations_v1(
		sdk,
		context,
		{},
		{
			"schema_version": "nonzero_staging",
			"semantic_step": 1,
			"initial_mechanical_energy_j": 0.0,
			"current_mechanical_energy_j": 0.0,
			"cumulative_applied_actuator_work_j": 0.0,
			"cumulative_signed_external_work_j": 0.0,
			"cumulative_signed_constraint_exchange_j": 0.0,
			"cumulative_signed_discrete_staging_exchange_j": 0.0,
			"cumulative_passive_dissipation_j": 0.0,
			"adapter_side_discrete_staging_event_count": 1,
			"source_measurement": true,
		},
		{"source_measurement": true},
	)

	var swapped_control := control.duplicate(true)
	var commands: Array = swapped_control["ordered_commands"]
	var first: Variant = commands[0]
	commands[0] = commands[1]
	commands[1] = first
	var swapped_result := RouteScript.apply_control_v1(
		sdk,
		swapped_control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	var missing_joint_map: Dictionary = (
		surface["joint_by_actuator_id"] as Dictionary
	).duplicate()
	missing_joint_map.erase(RouteScript.ORDERED_ACTUATOR_IDS[0])
	var missing_joint_result := RouteScript.apply_control_v1(
		sdk,
		control,
		missing_joint_map,
		surface["position_by_joint_id"],
		true,
	)
	return {
		"wrong_route": String(wrong_route_receipt.get("support_status", ""))
		!= "supported_exact",
		"wrong_mapping": String(wrong_mapping_receipt.get("support_status", ""))
		!= "supported_exact",
		"missing_staging_measurement": not bool(missing_staging.get("ok", false)),
		"nonzero_staging_event": not bool(nonzero_staging.get("ok", false)),
		"swapped_command_order": not bool(swapped_result.get("ok", false)),
		"missing_host_joint": not bool(missing_joint_result.get("ok", false)),
	}


static func _expected_profile() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--expected_profile="):
			return String(argument).trim_prefix("--expected_profile=")
	return ""


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_recovery_route_zero_world_v1",
		"gate_id": "QSDK-R24D57",
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
