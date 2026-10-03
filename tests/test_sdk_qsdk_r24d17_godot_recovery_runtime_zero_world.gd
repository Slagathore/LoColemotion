extends SceneTree
# gdlint: disable=max-line-length

const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D17_GODOT_RECOVERY_RUNTIME_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D17_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D17_GODOT_EXTENSION_INSTANTIATION_FAILED")
	var surface := RecoveryRuntimeScript.zero_world_surface_receipt_v1(sdk)
	var invalid_collection := RecoveryRuntimeScript.collect_native_v1(sdk, {})
	var invalid_control := RecoveryRuntimeScript.plan_control_v1(sdk, {})
	var exact := (
		bool(surface.get("ok", false))
		and String(invalid_collection.get("failure_code", ""))
		== "COLLECTION_REQUEST_SCHEMA_INVALID"
		and String(invalid_control.get("failure_code", ""))
		== "CONTROL_REQUEST_SCHEMA_INVALID"
		and int(surface.get("model_construction_count", -1)) == 0
		and int(surface.get("world_attempt_count", -1)) == 0
		and int(surface.get("world_build_count", -1)) == 0
		and int(surface.get("solver_step_count", -1)) == 0
		and not bool(surface.get("physics_state_modified", true))
		and not bool(surface.get("prone_to_standing_claimed", true))
		and not bool(surface.get("physical_acceptance_authority", true))
		and not bool(surface.get("release_authority", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d17_godot_recovery_runtime_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D17_GODOT_RUNTIME_SURFACE_INVALID",
		"profile_schema_valid": bool(surface.get("profile_schema_valid", false)),
		"local_mutation_count": 2,
		"local_mutation_rejection_count": (
			int(not bool(invalid_collection.get("ok", true)))
			+ int(not bool(invalid_control.get("ok", true)))
		),
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d17_godot_recovery_runtime_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
