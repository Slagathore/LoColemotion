extends SceneTree
# gdlint: disable=max-line-length

## R100 deterministic zero-world search for the representable refinement seam
## consumed by R99. No Node, RID, model, world, write, or solver step is made.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D100_GUARD_REFINEMENT_DIAGNOSTIC_ZERO_WORLD "
const SEARCH_SEED := 100_099_003
const MAXIMUM_CASE_COUNT := 50_000


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	var outer := WorldScript.native_angular_velocity_guard_limit_projection_v1(runtime)
	var target := WorldScript.native_angular_velocity_inner_projection_target_v1(outer)
	if not bool(target.get("ok", false)):
		return {"ok": false, "failure_code": "TARGET_INVALID", "detail": target}
	var limit := float(target["projection_target_limit_rad_s"])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEARCH_SEED
	for case_index in range(MAXIMUM_CASE_COUNT):
		var direction := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
		)
		var delta_direction := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
		)
		if direction.length_squared() == 0.0 or delta_direction.length_squared() == 0.0:
			continue
		direction = direction.normalized()
		delta_direction = delta_direction.normalized()
		if direction.dot(delta_direction) < 0.0:
			delta_direction = -delta_direction
		var radial_gap_fraction := pow(10.0, rng.randf_range(-7.0, -1.0))
		var source := direction * (limit * (1.0 - radial_gap_fraction))
		var delta_magnitude := pow(10.0, rng.randf_range(-2.0, 2.0))
		var requested_parent_impulse := delta_direction * delta_magnitude
		var requested_child_impulse := -requested_parent_impulse
		var projection := (
			WorldScript.nested_native_angular_velocity_guard_pair_projection_v2(
				3,
				String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
				String(WorldScript.ORDERED_JOINT_IDS[3]),
				String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
				String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
				case_index + 1,
				target,
				source,
				-source,
				Basis.IDENTITY,
				Basis.IDENTITY,
				requested_parent_impulse,
				requested_child_impulse,
			)
		)
		var predecessor: Dictionary = {}
		var detail_value: Variant = projection.get("detail")
		if detail_value is Dictionary:
			var predecessor_value: Variant = (detail_value as Dictionary).get(
				"predecessor_projection_failure"
			)
			if predecessor_value is Dictionary:
				predecessor = predecessor_value
		if (
			not bool(projection.get("ok", false))
			and String(projection.get("failure_code", ""))
			== "QSDK_R24D99_NESTED_PAIR_TARGET_PROJECTION_FAILED"
			and String(predecessor.get("failure_code", ""))
			== "QSDK_R24D99_GUARD_REFINEMENT_FAILED:3"
		):
			var terminal_diagnosis := (
				WorldScript.component_norm_guard_pair_refinement_diagnostic_v1(
					limit,
					source,
					-source,
					Basis.IDENTITY,
					Basis.IDENTITY,
					requested_parent_impulse,
					requested_child_impulse,
				)
			)
			if not bool(terminal_diagnosis.get("ok", false)):
				return terminal_diagnosis
			var failed_predicates: Array = terminal_diagnosis.get(
				"failed_terminal_predicates", []
			)
			failed_predicates.sort()
			if (
				failed_predicates != [
					"child_inside_or_on_limit",
					"parent_inside_or_on_limit",
				]
				or not bool(terminal_diagnosis["scale_refinement_limit_exhausted"])
				or int(terminal_diagnosis["scale_refinement_count"]) != 64
				or bool(terminal_diagnosis["terminal_projection_valid"])
				or not bool(terminal_diagnosis["zero_impulse_fallback_safe"])
			):
				return {
					"ok": false,
					"failure_code": "R100_REFINEMENT_COUNTEREXAMPLE_NOT_DISCRIMINATING",
					"terminal_diagnosis": terminal_diagnosis,
				}
			return {
				"schema_version": "sporespore_qsdk_r24d100_guard_refinement_diagnostic_zero_world_v1",
				"gate_id": "QSDK-R24D100",
				"ok": true,
				"question_class": "development",
				"counterexample_found": true,
				"case_index": case_index,
				"searched_case_count": case_index + 1,
				"search_seed": SEARCH_SEED,
				"source_angular_velocity_world_rad_s": _vec(source),
				"requested_parent_impulse_world_nms": _vec(requested_parent_impulse),
				"requested_child_impulse_world_nms": _vec(requested_child_impulse),
				"predecessor_failure": predecessor,
				"terminal_diagnosis": terminal_diagnosis,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"body_impulse_write_count": 0,
				"solver_step_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
				"release_authority": false,
			}
	return {
		"schema_version": "sporespore_qsdk_r24d100_guard_refinement_diagnostic_zero_world_v1",
		"gate_id": "QSDK-R24D100",
		"ok": false,
		"failure_code": "R99_REFINEMENT_COUNTEREXAMPLE_NOT_FOUND",
		"searched_case_count": MAXIMUM_CASE_COUNT,
		"search_seed": SEARCH_SEED,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _vec(value: Vector3) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y), "z": float(value.z)}
