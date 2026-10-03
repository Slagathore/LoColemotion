extends SceneTree
# gdlint: disable=max-line-length

## Pure R66 controls for the Godot real_t -> canonical scalar quaternion seam.
## The exact production projector and portable collection validator run, but no
## Node, RID, model, world, or solver step is created.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
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
const MARKER := "QSDK_R24D66_GODOT_QUATERNION_PROJECTION_ZERO_WORLD "
const CORE_REFUSAL := (
	"state_frame_invalid:FRAME_INVALID:"
	+ "state.base_pose_world.orientation_xyzw_quaternion_not_unit"
)
const CORE_TOLERANCE := 1.0e-9


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D66_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D66_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D66_ZERO_WORLD_CONTEXT_FAILED", context)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D66_ZERO_WORLD_FIXTURE_FAILED", fixture)

	var source_quaternions := [
		Quaternion.IDENTITY,
		Quaternion(Vector3.RIGHT, 0.1),
		Quaternion(Vector3.UP, 0.73),
		Quaternion(Vector3(1.0, 2.0, 3.0).normalized(), 0.73),
	]
	var projection_receipts: Array = []
	var projected_acceptance_count := 0
	var raw_core_refusal_count := 0
	for quaternion_value in source_quaternions:
		var quaternion: Quaternion = quaternion_value
		var projection := WorldScript.project_quaternion_to_unit_scalar_v1(quaternion)
		projection_receipts.append(projection)
		if not _projection_valid(projection):
			continue
		var projected_bound := _rebind_orientation(
			sdk, fixture, projection["orientation_xyzw"]
		)
		var projected_collection := RecoveryRuntimeScript.collect_native_v3(
			sdk,
			RouteScript.collection_request_v1(
				context,
				projected_bound,
				"candidate_command",
				"confirm_prone",
			),
		)
		projected_acceptance_count += int(_collection_supported(projected_collection))

		var raw_bound := _rebind_orientation(sdk, fixture, _quaternion_components(quaternion))
		var raw_collection := RecoveryRuntimeScript.collect_native_v3(
			sdk,
			RouteScript.collection_request_v1(
				context,
				raw_bound,
				"candidate_command",
				"confirm_prone",
			),
		)
		raw_core_refusal_count += int(_is_quaternion_refusal(raw_collection))

	var zero_projection := WorldScript.project_quaternion_to_unit_scalar_v1(
		Quaternion(0.0, 0.0, 0.0, 0.0)
	)
	var zero_projection_refused := (
		not bool(zero_projection.get("ok", true))
		and String(zero_projection.get("refusal_reason", ""))
		== "nonpositive_source_norm_squared"
		and float(zero_projection.get("source_norm_squared", NAN)) == 0.0
		and zero_projection.get("orientation_xyzw") == null
		and int(zero_projection.get("model_construction_count", -1)) == 0
		and int(zero_projection.get("world_attempt_count", -1)) == 0
		and int(zero_projection.get("world_build_count", -1)) == 0
		and int(zero_projection.get("solver_step_count", -1)) == 0
		and not bool(zero_projection.get("physics_state_modified", true))
	)

	var tampered_orientation := (
		projection_receipts[0]["orientation_xyzw"] as Dictionary
	).duplicate(true)
	tampered_orientation["x"] = 0.001
	var tampered_bound := _rebind_orientation(sdk, fixture, tampered_orientation)
	var initialization := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	var route_refusal := RouteScript.advance_behavior_v4(
		sdk,
		context,
		tampered_bound,
		initialization.get("memory", {}),
		"candidate_command",
		"confirm_prone",
	)
	var route_detail_value: Variant = route_refusal.get("detail")
	var route_detail: Dictionary = (
		route_detail_value if route_detail_value is Dictionary else {}
	)
	var diagnostic_value: Variant = route_detail.get("base_orientation_diagnostic")
	var diagnostic: Dictionary = diagnostic_value if diagnostic_value is Dictionary else {}
	var expected_norm_squared := 0.0
	for key in ["x", "y", "z", "w"]:
		expected_norm_squared += float(tampered_orientation[key]) * float(tampered_orientation[key])
	var expected_delta := absf(expected_norm_squared - 1.0)
	var diagnostic_complete: bool = (
		not bool(route_refusal.get("ok", true))
		and String(route_refusal.get("failure_code", ""))
		== "QSDK_R24D65_BEHAVIOR_COLLECTION_REFUSED"
		and String(route_detail.get("refusal_reason", "")) == CORE_REFUSAL
		and bool(diagnostic.get("ok", false))
		and diagnostic.get("source_orientation_xyzw") == tampered_orientation
		and float(diagnostic.get("norm_squared", NAN)) == expected_norm_squared
		and float(diagnostic.get("unit_delta", NAN)) == expected_delta
		and float(diagnostic.get("core_norm_squared_tolerance", NAN)) == CORE_TOLERANCE
		and not bool(diagnostic.get("within_core_unit_contract", true))
		and int(diagnostic.get("model_construction_count", -1)) == 0
		and int(diagnostic.get("world_attempt_count", -1)) == 0
		and int(diagnostic.get("world_build_count", -1)) == 0
		and int(diagnostic.get("solver_step_count", -1)) == 0
		and not bool(diagnostic.get("physics_state_modified", true))
	)

	var ok: bool = (
		projection_receipts.size() == source_quaternions.size()
		and projection_receipts.all(
			func(value: Variant) -> bool: return value is Dictionary and _projection_valid(value)
		)
		and projected_acceptance_count == source_quaternions.size()
		and raw_core_refusal_count >= 1
		and zero_projection_refused
		and diagnostic_complete
	)
	return {
		"schema_version": "sporespore_qsdk_r24d66_godot_quaternion_projection_zero_world_v1",
		"gate_id": "QSDK-R24D66",
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D66_QUATERNION_PROJECTION_INVALID",
		"projection_case_count": source_quaternions.size(),
		"projection_receipts": projection_receipts,
		"projected_core_acceptance_count": projected_acceptance_count,
		"raw_core_refusal_count": raw_core_refusal_count,
		"zero_projection_refusal_count": int(zero_projection_refused),
		"zero_projection_refusal": zero_projection,
		"diagnostic_retention_count": int(diagnostic_complete),
		"diagnostic_retention_receipt": diagnostic,
		"core_norm_squared_tolerance": CORE_TOLERANCE,
		"threshold_changed": false,
		"controller_changed": false,
		"evaluator_changed": false,
		"native_physics_changed": false,
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


static func _projection_valid(projection: Dictionary) -> bool:
	return (
		bool(projection.get("ok", false))
		and String(projection.get("schema_version", ""))
		== "sporespore_qsdk_r24d66_godot_quaternion_scalar_projection_v1"
		and bool(projection.get("within_core_unit_contract", false))
		and float(projection.get("projected_unit_delta", INF)) <= CORE_TOLERANCE
		and int(projection.get("model_construction_count", -1)) == 0
		and int(projection.get("world_attempt_count", -1)) == 0
		and int(projection.get("world_build_count", -1)) == 0
		and int(projection.get("solver_step_count", -1)) == 0
		and not bool(projection.get("physics_state_modified", true))
	)


static func _collection_supported(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "supported_exact"
		and collection.get("refusal_reason", "unexpected") == null
		and bool(collection.get("supplied_native_post_step_observation_validated", false))
		and int(collection.get("model_construction_count", -1)) == 0
		and int(collection.get("world_attempt_count", -1)) == 0
		and int(collection.get("world_build_count", -1)) == 0
		and int(collection.get("solver_step_count", -1)) == 0
		and not bool(collection.get("physics_state_modified", true))
	)


static func _is_quaternion_refusal(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "invalid_observation"
		and String(collection.get("refusal_reason", "")) == CORE_REFUSAL
		and int(collection.get("model_construction_count", -1)) == 0
		and int(collection.get("world_attempt_count", -1)) == 0
		and int(collection.get("world_build_count", -1)) == 0
		and int(collection.get("solver_step_count", -1)) == 0
		and not bool(collection.get("physics_state_modified", true))
	)


static func _rebind_orientation(
	sdk: Object,
	fixture: Dictionary,
	orientation: Dictionary,
) -> Dictionary:
	var observation: Dictionary = (fixture["observation_v2"] as Dictionary).duplicate(true)
	observation["state"]["base_pose_world"]["orientation_xyzw"] = orientation.duplicate(true)
	var observation_base := observation.duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	var binding: Dictionary = (fixture["source_binding"] as Dictionary).duplicate(true)
	binding["observation_base_sha256"] = _sha256(sdk, observation_base)
	binding["ledger_sha256"] = _sha256(sdk, observation["energy_balance"])
	binding["portable_observation_sha256"] = _sha256(sdk, observation)
	binding.erase("source_chain_sha256")
	binding["source_chain_sha256"] = _sha256(sdk, binding)
	return {
		"observation_v2": observation,
		"observation_v3": (fixture["observation_v3"] as Dictionary).duplicate(true),
		"source_binding": binding,
	}


static func _quaternion_components(value: Quaternion) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y), "z": float(value.z), "w": float(value.w)}


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	return String(receipt.get("sha256", ""))


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d66_godot_quaternion_projection_zero_world_v1",
		"gate_id": "QSDK-R24D66",
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
