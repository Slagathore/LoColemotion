extends SceneTree
# gdlint: disable=max-line-length

## Compact R94 pure-data coverage for the source-measured paired body impulse
## guard. No Node, RID, model, world, or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_JOLT_NATIVE_ANGULAR_VELOCITY_GUARD_ZERO_WORLD "


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	var guard := WorldScript.native_angular_velocity_guard_limit_projection_v1(runtime)
	if not _guard_valid(runtime, guard):
		return _failure("GUARD_LIMIT_INVALID", guard)
	var limit := float(guard["guard_limit_rad_s"])
	var identity := Basis.IDENTITY
	var ordinary := WorldScript.native_angular_velocity_guard_pair_projection_v1(
		0,
		"front_left_hip_motor",
		"front_left_hip",
		"torso",
		"front_left_upper",
		1,
		guard,
		Vector3.ZERO,
		Vector3.ZERO,
		identity,
		identity,
		Vector3(-1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
	)
	var saturated := WorldScript.native_angular_velocity_guard_pair_projection_v1(
		0,
		"front_left_hip_motor",
		"front_left_hip",
		"torso",
		"front_left_upper",
		1,
		guard,
		Vector3.ZERO,
		Vector3.ZERO,
		identity,
		identity,
		Vector3(-2.0 * limit, 0.0, 0.0),
		Vector3(2.0 * limit, 0.0, 0.0),
	)
	var braking := WorldScript.native_angular_velocity_guard_pair_projection_v1(
		0,
		"front_left_hip_motor",
		"front_left_hip",
		"torso",
		"front_left_upper",
		1,
		guard,
		Vector3(limit * 1.00001, 0.0, 0.0),
		Vector3.ZERO,
		identity,
		identity,
		Vector3(-1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
	)
	if not _pair_valid(ordinary, false) or not _pair_valid(saturated, true):
		return _failure("PAIR_POSITIVE_INVALID")
	if (
		not _pair_valid(braking, false)
		or float(braking["parent_source_angular_speed_rad_s"]) <= limit
		or float(braking["predicted_parent_angular_speed_rad_s"]) > limit
	):
		return _failure("BRAKING_POSITIVE_INVALID", braking)
	var predecessor := WorldScript.force_based_joint_impulse_projection_v1(
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
	var predecessor_parent_impulse := _vec3(
		predecessor.get("parent_angular_impulse_world_nms")
	)
	var predecessor_child_impulse := _vec3(
		predecessor.get("child_angular_impulse_world_nms")
	)
	var predecessor_guard := WorldScript.native_angular_velocity_guard_pair_projection_v1(
		0,
		"front_left_hip_motor",
		"front_left_hip",
		"torso",
		"front_left_upper",
		1,
		guard,
		Vector3.ZERO,
		Vector3.ZERO,
		identity,
		identity,
		predecessor_parent_impulse,
		predecessor_child_impulse,
	)
	var guarded := WorldScript.guarded_force_based_joint_impulse_projection_v1(
		predecessor, predecessor_guard
	)
	var guarded_validation := (
		WorldScript.validate_guarded_force_based_joint_impulse_projection_v1(guarded)
	)
	var guarded_work := WorldScript.guarded_force_based_joint_work_projection_v1(
		guarded,
		2,
		true,
		Vector3.BACK,
		0.5,
	)
	var guarded_readback := WorldScript.native_angular_velocity_guard_readback_receipt_v1(
		guarded,
		_vec3(predecessor_guard["predicted_parent_angular_velocity_world_rad_s"]),
		_vec3(predecessor_guard["predicted_child_angular_velocity_world_rad_s"]),
	)
	var guarded_readback_validation := (
		WorldScript.validate_native_angular_velocity_guard_readback_receipt_v1(
			guarded, guarded_readback
		)
	)
	if (
		not bool(guarded.get("ok", false))
		or not bool(guarded_validation.get("ok", false))
		or not bool(guarded_work.get("ok", false))
		or not bool(guarded_readback.get("ok", false))
		or not bool(guarded_readback_validation.get("ok", false))
		or String(guarded.get("actuator_mapping_id", ""))
		!= WorldScript.GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		or String(guarded_work.get("work_mapping_id", ""))
		!= WorldScript.GUARDED_FORCE_BASED_WORK_MAPPING_ID
		or float(guarded.get("applied_signed_joint_impulse_nms", NAN))
		!= float(predecessor.get("applied_signed_joint_impulse_nms", NAN))
	):
		return _failure("GUARDED_MAPPING_POSITIVE_INVALID", guarded)

	var rejected: Array = []
	var bad_guard := guard.duplicate(true)
	bad_guard["schema_version"] = "mutated"
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, bad_guard, Vector3.ZERO, Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_LIMIT_PROJECTION_INVALID",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "wrong", "front_left_hip", "torso", "front_left_upper",
			1, guard, Vector3.ZERO, Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_BINDING_INVALID:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, guard, Vector3(INF, 0.0, 0.0), Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_SOURCE_INVALID:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, guard, Vector3.ZERO, Vector3.ZERO,
			Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_SOURCE_INVALID:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, guard, Vector3.ZERO, Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_SOURCE_INVALID:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, guard,
			Vector3(float(runtime["effective_max_angular_velocity_rad_s"]) * 1.01, 0.0, 0.0),
			Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_SOURCE_LIMIT_INVALID:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			1, guard, Vector3(limit * 1.00001, 0.0, 0.0), Vector3.ZERO,
			identity, identity,
			Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_NO_FEASIBLE_BODY_SCALE:",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_pair_projection_v1(
			0, "front_left_hip_motor", "front_left_hip", "torso", "front_left_upper",
			0, guard, Vector3.ZERO, Vector3.ZERO, identity, identity,
			Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		),
		"QSDK_R24D94_GUARD_BINDING_INVALID:",
		rejected,
	)
	var mutated_pair := predecessor_guard.duplicate(true)
	mutated_pair["applied_scale"] = 0.5
	_record_rejection(
		WorldScript.validate_native_angular_velocity_guard_pair_projection_v1(mutated_pair),
		"QSDK_R24D94_GUARD_PAIR_RECEIPT_INVALID",
		rejected,
	)
	var mutated_guarded := guarded.duplicate(true)
	mutated_guarded["applied_signed_joint_impulse_nms"] = 999.0
	_record_rejection(
		WorldScript.validate_guarded_force_based_joint_impulse_projection_v1(
			mutated_guarded
		),
		"QSDK_R24D94_GUARDED_PROJECTION_RECEIPT_INVALID",
		rejected,
	)
	_record_rejection(
		WorldScript.guarded_force_based_joint_work_projection_v1(
			guarded,
			3,
			true,
			Vector3.BACK,
			0.5,
		),
		"QSDK_R24D94_GUARDED_WORK_SOURCE_INVALID",
		rejected,
	)
	var mutated_readback := guarded_readback.duplicate(true)
	mutated_readback["parent_angular_speed_rad_s"] = 999.0
	_record_rejection(
		WorldScript.validate_native_angular_velocity_guard_readback_receipt_v1(
			guarded, mutated_readback
		),
		"QSDK_R24D94_GUARD_READBACK_RECEIPT_INVALID",
		rejected,
	)
	_record_rejection(
		WorldScript.native_angular_velocity_guard_readback_receipt_v1(
			guarded,
			Vector3(limit * 1.01, 0.0, 0.0),
			Vector3.ZERO,
		),
		"QSDK_R24D94_GUARD_READBACK_LIMIT_INVALID",
		rejected,
	)
	return {
		"schema_version": "sporespore_godot_jolt_native_angular_velocity_guard_zero_world_v1",
		"gate_id": "QSDK-R24D94",
		"ok": rejected.size() == 13,
		"runtime_projection": runtime,
		"guard_limit_projection": guard,
		"positive_case_count": 5,
		"forced_failure_case_count": rejected.size(),
		"ordered_rejected_failure_codes": rejected,
		"ordinary_full_scale_passed": true,
		"saturation_guard_engaged": true,
		"above_guard_braking_path_passed": true,
		"guarded_mapping_and_centered_work_passed": true,
		"immediate_native_readback_receipt_passed": true,
		"equal_and_opposite_pairing_preserved": true,
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


static func _guard_valid(runtime: Dictionary, guard: Dictionary) -> bool:
	return (
		bool(runtime.get("ok", false))
		and bool(guard.get("ok", false))
		and String(guard.get("schema_version", ""))
		== WorldScript.NATIVE_ANGULAR_VELOCITY_GUARD_LIMIT_PROJECTION_SCHEMA
		and float(guard.get("guard_limit_rad_s", NAN)) > 0.0
		and float(guard.get("guard_limit_rad_s", NAN))
		< float(runtime.get("effective_max_angular_velocity_rad_s", NAN))
		and not bool(guard.get("engine_limit_changed", true))
		and not bool(guard.get("behavior_threshold_changed", true))
		and not bool(guard.get("empirical_margin", true))
	)


static func _pair_valid(receipt: Dictionary, expect_guard: bool) -> bool:
	return (
		bool(receipt.get("ok", false))
		and String(receipt.get("schema_version", ""))
		== WorldScript.NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
		and bool(receipt.get("guard_engaged", not expect_guard)) == expect_guard
		and bool(receipt.get("both_predicted_inside_guard", false))
		and float(receipt.get("applied_scale", NAN)) > 0.0
		and float(receipt.get("applied_scale", NAN)) <= 1.0
	)


static func _vec3(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


static func _record_rejection(
	receipt: Dictionary,
	expected_prefix: String,
	rejected: Array,
) -> void:
	var code := String(receipt.get("failure_code", ""))
	if not bool(receipt.get("ok", true)) and code.begins_with(expected_prefix):
		rejected.append(code)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_jolt_native_angular_velocity_guard_zero_world_failure_v1",
		"gate_id": "QSDK-R24D94",
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
