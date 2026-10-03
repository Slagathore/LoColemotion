extends SceneTree
# gdlint: disable=max-line-length

## Compact R96 pure-data coverage for the nested projection target. The frozen
## R94 worker is executed as the predecessor regression; no Node, RID, model,
## world, native body write, or solver step is created here.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const R94WorkerScript := preload(
	"res://tests/test_sdk_godot_jolt_native_angular_velocity_guard_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_JOLT_NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_ZERO_WORLD "
const EXPECTED_OUTER_GUARD_LIMIT_RAD_S := 47.11813735961914
const EXPECTED_OUTER_GUARD_BINARY32_HEX := "0x423c78f9"
const EXPECTED_INNER_TARGET_LIMIT_RAD_S := 47.11238479614258
const EXPECTED_INNER_TARGET_BINARY32_HEX := "0x423c7315"


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var predecessor_regression := R94WorkerScript._run()
	if (
		not bool(predecessor_regression.get("ok", false))
		or int(predecessor_regression.get("positive_case_count", -1)) != 5
		or int(predecessor_regression.get("forced_failure_case_count", -1)) != 13
	):
		return _failure("R94_PREDECESSOR_REGRESSION_INVALID", predecessor_regression)
	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	var outer_guard := WorldScript.native_angular_velocity_guard_limit_projection_v1(runtime)
	var inner_target := WorldScript.native_angular_velocity_inner_projection_target_v1(outer_guard)
	if not _inner_target_valid(outer_guard, inner_target):
		return _failure("INNER_TARGET_POSITIVE_INVALID", inner_target)
	var target_limit := float(inner_target["projection_target_limit_rad_s"])
	var outer_limit := float(inner_target["outer_guard_limit_rad_s"])
	var identity := Basis.IDENTITY
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
			Vector3(-2.0 * target_limit, 0.0, 0.0),
			Vector3(2.0 * target_limit, 0.0, 0.0),
		)
	)
	var nested_pair_validation := (
		WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v1(nested_pair)
	)
	if (
		not bool(nested_pair.get("ok", false))
		or not bool(nested_pair_validation.get("ok", false))
		or (
			String(nested_pair.get("schema_version", ""))
			!= WorldScript.NESTED_NATIVE_ANGULAR_VELOCITY_GUARD_PAIR_PROJECTION_SCHEMA
		)
		or not bool(nested_pair.get("guard_engaged", false))
		or not bool(nested_pair.get("both_predicted_inside_projection_target", false))
		or not bool(nested_pair.get("both_predicted_inside_guard", false))
		or float(nested_pair.get("guard_limit_rad_s", NAN)) != outer_limit
		or float(nested_pair.get("projection_target_limit_rad_s", NAN)) != target_limit
	):
		return _failure("NESTED_PAIR_POSITIVE_INVALID", nested_pair)
	var source_between_target_and_guard := target_limit + 0.5 * (outer_limit - target_limit)
	var outer_hold_pair := (
		WorldScript
		. nested_native_angular_velocity_guard_pair_projection_v1(
			0,
			"front_left_hip_motor",
			"front_left_hip",
			"torso",
			"front_left_upper",
			1,
			inner_target,
			Vector3(source_between_target_and_guard, 0.0, 0.0),
			Vector3.ZERO,
			identity,
			identity,
			Vector3(1.0, 0.0, 0.0),
			Vector3(-1.0, 0.0, 0.0),
		)
	)
	var outer_hold_validation := (
		WorldScript
		. validate_nested_native_angular_velocity_guard_pair_projection_v1(outer_hold_pair)
	)
	if (
		not bool(outer_hold_pair.get("ok", false))
		or not bool(outer_hold_validation.get("ok", false))
		or not bool(outer_hold_pair.get("outer_guard_zero_impulse_hold", false))
		or bool(outer_hold_pair.get("projection_target_feasible", true))
		or float(outer_hold_pair.get("applied_scale", NAN)) != 0.0
		or bool(outer_hold_pair.get("both_predicted_inside_projection_target", true))
		or not bool(outer_hold_pair.get("both_predicted_inside_guard", false))
	):
		return _failure("OUTER_GUARD_HOLD_POSITIVE_INVALID", outer_hold_pair)

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
	var predecessor_pair := (
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
			_vec3(predecessor["parent_angular_impulse_world_nms"]),
			_vec3(predecessor["child_angular_impulse_world_nms"]),
		)
	)
	var nested_projection := WorldScript.nested_guarded_force_based_joint_impulse_projection_v1(
		predecessor, predecessor_pair
	)
	var nested_projection_validation := (
		WorldScript
		. validate_nested_guarded_force_based_joint_impulse_projection_v1(nested_projection)
	)
	var nested_work := (
		WorldScript
		. nested_guarded_force_based_joint_work_projection_v1(
			nested_projection,
			2,
			true,
			Vector3.BACK,
			0.5,
		)
	)
	var diagnostic_speed := target_limit + 0.5 * (outer_limit - target_limit)
	var nested_readback := (
		WorldScript
		. nested_native_angular_velocity_guard_readback_receipt_v1(
			nested_projection,
			Vector3(diagnostic_speed, 0.0, 0.0),
			Vector3.ZERO,
		)
	)
	var nested_readback_validation := (
		WorldScript
		. validate_nested_native_angular_velocity_guard_readback_receipt_v1(
			nested_projection, nested_readback
		)
	)
	if (
		not bool(nested_projection.get("ok", false))
		or not bool(nested_projection_validation.get("ok", false))
		or not bool(nested_work.get("ok", false))
		or not bool(nested_readback.get("ok", false))
		or not bool(nested_readback_validation.get("ok", false))
		or (
			String(nested_projection.get("actuator_mapping_id", ""))
			!= WorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		or (
			String(nested_work.get("work_mapping_id", ""))
			!= WorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		or bool(nested_readback.get("both_readbacks_inside_projection_target", true))
		or not bool(nested_readback.get("both_readbacks_inside_guard", false))
		or String(nested_readback.get("readback_authority", "")) != "frozen_outer_native_guard"
	):
		return _failure("NESTED_MAPPING_OR_READBACK_POSITIVE_INVALID", nested_projection)

	var rejected: Array = []
	var mutated_outer := outer_guard.duplicate(true)
	mutated_outer["guard_limit_rad_s"] = target_limit
	_record_rejection(
		WorldScript.native_angular_velocity_inner_projection_target_v1(mutated_outer),
		"QSDK_R24D96_INNER_TARGET_OUTER_GUARD_INVALID",
		rejected,
	)
	var mutated_target := inner_target.duplicate(true)
	mutated_target["projection_target_limit_rad_s"] = target_limit - 1.0
	_record_rejection(
		(
			WorldScript
			. nested_native_angular_velocity_guard_pair_projection_v1(
				0,
				"front_left_hip_motor",
				"front_left_hip",
				"torso",
				"front_left_upper",
				1,
				mutated_target,
				Vector3.ZERO,
				Vector3.ZERO,
				identity,
				identity,
				Vector3(-1.0, 0.0, 0.0),
				Vector3(1.0, 0.0, 0.0),
			)
		),
		"QSDK_R24D96_NESTED_PAIR_TARGET_INVALID",
		rejected,
	)
	var mutated_pair := predecessor_pair.duplicate(true)
	mutated_pair["applied_scale"] = 0.5
	_record_rejection(
		WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v1(mutated_pair),
		"QSDK_R24D96_NESTED_PAIR_RECEIPT_INVALID",
		rejected,
	)
	var mutated_projection := nested_projection.duplicate(true)
	mutated_projection["angular_velocity_projection_target_limit_rad_s"] = outer_limit
	_record_rejection(
		WorldScript.validate_nested_guarded_force_based_joint_impulse_projection_v1(
			mutated_projection
		),
		"QSDK_R24D96_NESTED_GUARDED_PROJECTION_RECEIPT_INVALID",
		rejected,
	)
	_record_rejection(
		(
			WorldScript
			. nested_native_angular_velocity_guard_readback_receipt_v1(
				nested_projection,
				Vector3(outer_limit * 1.01, 0.0, 0.0),
				Vector3.ZERO,
			)
		),
		"QSDK_R24D96_NESTED_GUARD_READBACK_LIMIT_INVALID",
		rejected,
	)
	var mutated_readback := nested_readback.duplicate(true)
	mutated_readback["readback_authority"] = "inner_target"
	_record_rejection(
		WorldScript.validate_nested_native_angular_velocity_guard_readback_receipt_v1(
			nested_projection, mutated_readback
		),
		"QSDK_R24D96_NESTED_GUARD_READBACK_RECEIPT_INVALID",
		rejected,
	)
	_record_rejection(
		(
			WorldScript
			. nested_guarded_force_based_joint_work_projection_v1(
				nested_projection,
				3,
				true,
				Vector3.BACK,
				0.5,
			)
		),
		"QSDK_R24D96_NESTED_GUARDED_WORK_SOURCE_INVALID",
		rejected,
	)
	return {
		"schema_version":
		"sporespore_godot_jolt_nested_native_angular_velocity_guard_zero_world_v1",
		"gate_id": "QSDK-R24D96",
		"ok": rejected.size() == 7,
		"predecessor_gate_id": "QSDK-R24D94",
		"predecessor_regression_passed": true,
		"outer_guard_limit_projection": outer_guard,
		"inner_projection_target": inner_target,
		"outer_guard_limit_rad_s": outer_limit,
		"projection_target_limit_rad_s": target_limit,
		"outer_to_target_headroom_rad_s": outer_limit - target_limit,
		"outer_guard_unchanged": true,
		"r24d95_observation_selected_margin": false,
		"nested_pair_projection_passed": true,
		"nested_mapping_and_centered_work_passed": true,
		"readback_between_inner_target_and_outer_guard_passed": true,
		"positive_case_count": 5,
		"forced_failure_case_count": rejected.size(),
		"ordered_rejected_failure_codes": rejected,
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


static func _inner_target_valid(outer_guard: Dictionary, inner_target: Dictionary) -> bool:
	return (
		bool(outer_guard.get("ok", false))
		and bool(inner_target.get("ok", false))
		and float(outer_guard.get("guard_limit_rad_s", NAN)) == EXPECTED_OUTER_GUARD_LIMIT_RAD_S
		and (
			String(outer_guard.get("guard_limit_binary32_hex", ""))
			== EXPECTED_OUTER_GUARD_BINARY32_HEX
		)
		and (
			float(inner_target.get("outer_guard_limit_rad_s", NAN))
			== EXPECTED_OUTER_GUARD_LIMIT_RAD_S
		)
		and (
			float(inner_target.get("projection_target_limit_rad_s", NAN))
			== EXPECTED_INNER_TARGET_LIMIT_RAD_S
		)
		and (
			String(inner_target.get("projection_target_limit_binary32_hex", ""))
			== EXPECTED_INNER_TARGET_BINARY32_HEX
		)
		and (
			float(inner_target.get("absolute_outer_to_target_headroom_rad_s", NAN))
			== EXPECTED_OUTER_GUARD_LIMIT_RAD_S - EXPECTED_INNER_TARGET_LIMIT_RAD_S
		)
		and not bool(inner_target.get("outer_guard_changed", true))
		and not bool(inner_target.get("engine_limit_changed", true))
		and not bool(inner_target.get("behavior_threshold_changed", true))
		and not bool(inner_target.get("empirical_margin", true))
		and not bool(inner_target.get("r24d95_observation_selected_margin", true))
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
		"schema_version":
		"sporespore_godot_jolt_nested_native_angular_velocity_guard_zero_world_failure_v1",
		"gate_id": "QSDK-R24D96",
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
