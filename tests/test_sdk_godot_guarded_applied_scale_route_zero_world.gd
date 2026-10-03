extends SceneTree
# gdlint: disable=max-line-length

## R97 pure-data coverage for the exact route/world field-path mismatch retained
## by R96. It exercises both frozen receipt shapes through the shared resolver;
## no Node, RID, model, world, native write, or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const R96WorkerScript := preload(
	"res://tests/test_sdk_godot_jolt_nested_native_angular_velocity_guard_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_GUARDED_APPLIED_SCALE_ROUTE_ZERO_WORLD "
const LEGACY_SCALE_PATH := "angular_velocity_guard_applied_scale"
const NESTED_SCALE_PATH := "native_angular_velocity_guard_projection.applied_scale"


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var predecessor_regression := R96WorkerScript._run()
	if (
		not bool(predecessor_regression.get("ok", false))
		or int(predecessor_regression.get("positive_case_count", -1)) != 5
		or int(predecessor_regression.get("forced_failure_case_count", -1)) != 7
	):
		return _failure("R96_PREDECESSOR_REGRESSION_INVALID", predecessor_regression)

	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	var outer_guard := WorldScript.native_angular_velocity_guard_limit_projection_v1(runtime)
	var inner_target := WorldScript.native_angular_velocity_inner_projection_target_v1(outer_guard)
	if (
		not bool(runtime.get("ok", false))
		or not bool(outer_guard.get("ok", false))
		or not bool(inner_target.get("ok", false))
	):
		return _failure("GUARD_SOURCE_INVALID", inner_target)

	var predecessor := (
		WorldScript
		. force_based_joint_impulse_projection_v1(
			0,
			"front_left_hip_motor",
			"front_left_hip",
			"torso",
			"front_left_upper",
			1,
			true,
			Vector3.BACK,
			Vector3.RIGHT,
			1.0,
			2.0,
			0.0,
			float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[0]),
		)
	)
	if not bool(predecessor.get("ok", false)):
		return _failure("PREDECESSOR_PROJECTION_INVALID", predecessor)
	var parent_impulse := _vec3(predecessor.get("parent_angular_impulse_world_nms"))
	var child_impulse := _vec3(predecessor.get("child_angular_impulse_world_nms"))
	var identity := Basis.IDENTITY

	var legacy_pair := (
		WorldScript
		. native_angular_velocity_guard_pair_projection_v1(
			0,
			"front_left_hip_motor",
			"front_left_hip",
			"torso",
			"front_left_upper",
			1,
			outer_guard,
			Vector3.ZERO,
			Vector3.ZERO,
			identity,
			identity,
			parent_impulse,
			child_impulse,
		)
	)
	var legacy_projection := WorldScript.guarded_force_based_joint_impulse_projection_v1(
		predecessor, legacy_pair
	)
	var legacy_scale := WorldScript.guarded_force_based_applied_scale_projection_v1(
		legacy_projection, false
	)

	var nested_pair := (
		WorldScript
		. nested_native_angular_velocity_guard_pair_projection_v1(
			0,
			"front_left_hip_motor",
			"front_left_hip",
			"torso",
			"front_left_upper",
			1,
			inner_target,
			Vector3.ZERO,
			Vector3.ZERO,
			identity,
			identity,
			parent_impulse,
			child_impulse,
		)
	)
	var nested_projection := WorldScript.nested_guarded_force_based_joint_impulse_projection_v1(
		predecessor, nested_pair
	)
	var nested_scale := WorldScript.guarded_force_based_applied_scale_projection_v1(
		nested_projection, true
	)
	if (
		not _scale_positive(legacy_scale, LEGACY_SCALE_PATH)
		or not _scale_positive(nested_scale, NESTED_SCALE_PATH)
		or (
			float(legacy_scale.get("applied_scale", NAN))
			!= float(legacy_pair.get("applied_scale", NAN))
		)
		or (
			float(nested_scale.get("applied_scale", NAN))
			!= float(nested_pair.get("applied_scale", NAN))
		)
		or nested_projection.has("angular_velocity_guard_applied_scale")
	):
		return _failure("APPLIED_SCALE_POSITIVE_INVALID", nested_scale)

	var rejected: Array = []
	_record_rejection(
		WorldScript.guarded_force_based_applied_scale_projection_v1(legacy_projection, true),
		rejected,
	)
	_record_rejection(
		WorldScript.guarded_force_based_applied_scale_projection_v1(nested_projection, false),
		rejected,
	)
	var mutated_nested := nested_projection.duplicate(true)
	(mutated_nested["native_angular_velocity_guard_projection"] as Dictionary)["applied_scale"] = 2.0
	_record_rejection(
		WorldScript.guarded_force_based_applied_scale_projection_v1(mutated_nested, true),
		rejected,
	)
	_record_rejection(
		WorldScript.guarded_force_based_applied_scale_projection_v1({}, false),
		rejected,
	)
	if rejected.size() != 4:
		return _failure("FORCED_FAILURE_POPULATION_INVALID", {"rejected": rejected})

	return {
		"schema_version": "sporespore_godot_guarded_applied_scale_route_zero_world_v1",
		"gate_id": "QSDK-R24D97",
		"ok": true,
		"predecessor_gate_id": "QSDK-R24D96",
		"r96_predecessor_regression_passed": true,
		"positive_case_count": 2,
		"forced_failure_case_count": 4,
		"ordered_rejected_failure_codes": rejected,
		"legacy_scale_path": LEGACY_SCALE_PATH,
		"nested_scale_path": NESTED_SCALE_PATH,
		"legacy_applied_scale": float(legacy_scale["applied_scale"]),
		"nested_applied_scale": float(nested_scale["applied_scale"]),
		"route_and_world_use_shared_resolver_required": true,
		"guard_or_projection_target_changed": false,
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


static func _scale_positive(receipt: Dictionary, expected_path: String) -> bool:
	return (
		bool(receipt.get("ok", false))
		and (
			String(receipt.get("schema_version", ""))
			== WorldScript.GUARDED_FORCE_BASED_APPLIED_SCALE_PROJECTION_SCHEMA
		)
		and String(receipt.get("source_path", "")) == expected_path
		and is_finite(float(receipt.get("applied_scale", NAN)))
		and float(receipt.get("applied_scale", NAN)) >= 0.0
		and float(receipt.get("applied_scale", NAN)) <= 1.0
	)


static func _record_rejection(receipt: Dictionary, rejected: Array) -> void:
	var code := String(receipt.get("failure_code", ""))
	if (
		not bool(receipt.get("ok", true))
		and code.begins_with("QSDK_R24D97_APPLIED_SCALE_PROJECTION_INVALID")
	):
		rejected.append(code)


static func _vec3(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_guarded_applied_scale_route_zero_world_failure_v1",
		"gate_id": "QSDK-R24D97",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
