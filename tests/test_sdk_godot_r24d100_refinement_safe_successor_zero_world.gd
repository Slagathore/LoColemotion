extends SceneTree
# gdlint: disable=max-line-length

## R100 zero-world proof for the versioned refinement-safe production mapping.
## No Node, RID, model, world, write, or solver step is made.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D100_REFINEMENT_SAFE_SUCCESSOR_ZERO_WORLD "
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
	var target_solver: Dictionary = outer.duplicate(true)
	target_solver["guard_limit_rad_s"] = limit
	target_solver["guard_limit_binary32_hex"] = String(
		target["projection_target_limit_binary32_hex"]
	)
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
			var failed_predicates: Array = (
				terminal_diagnosis.get("failed_terminal_predicates", []) as Array
			).duplicate()
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
			var successor := WorldScript.native_angular_velocity_guard_pair_projection_v3(
				3,
				String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
				String(WorldScript.ORDERED_JOINT_IDS[3]),
				String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
				String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
				case_index + 1,
				target_solver,
				source,
				-source,
				Basis.IDENTITY,
				Basis.IDENTITY,
				requested_parent_impulse,
				requested_child_impulse,
			)
			var successor_validation := (
				WorldScript.validate_native_angular_velocity_guard_pair_projection_v3(
					successor
				)
			)
			var mutated_successor: Dictionary = successor.duplicate(true)
			mutated_successor["representational_zero_impulse_fallback"] = false
			var mutation_validation := (
				WorldScript.validate_native_angular_velocity_guard_pair_projection_v3(
					mutated_successor
				)
			)
			var mutated_diagnostic_successor: Dictionary = successor.duplicate(true)
			var mutated_diagnostic_value: Variant = mutated_diagnostic_successor.get(
				"refinement_diagnostic"
			)
			if mutated_diagnostic_value is Dictionary:
				var mutated_diagnostic: Dictionary = (
					mutated_diagnostic_value as Dictionary
				).duplicate(true)
				mutated_diagnostic["terminal_scale"] = 0.0
				mutated_diagnostic_successor["refinement_diagnostic"] = mutated_diagnostic
			var diagnostic_mutation_validation := (
				WorldScript.validate_native_angular_velocity_guard_pair_projection_v3(
					mutated_diagnostic_successor
				)
			)
			var non_pairing_failure := (
				WorldScript.native_angular_velocity_guard_pair_projection_v3(
					3,
					String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
					String(WorldScript.ORDERED_JOINT_IDS[3]),
					String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
					String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
					case_index + 1,
					target_solver,
					source,
					-source,
					Basis.IDENTITY,
					Basis.IDENTITY,
					requested_parent_impulse,
					requested_parent_impulse,
				)
			)
			var ordinary_parent_impulse := Vector3(0.01, 0.0, 0.0)
			var ordinary_successor := (
				WorldScript.native_angular_velocity_guard_pair_projection_v3(
					3,
					String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
					String(WorldScript.ORDERED_JOINT_IDS[3]),
					String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
					String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
					case_index + 2,
					target_solver,
					Vector3.ZERO,
					Vector3.ZERO,
					Basis.IDENTITY,
					Basis.IDENTITY,
					ordinary_parent_impulse,
					-ordinary_parent_impulse,
				)
			)
			var nested_successor := (
				WorldScript.nested_native_angular_velocity_guard_pair_projection_v3(
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
			var nested_validation := (
				WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v3(
					nested_successor
				)
			)
			var mutated_nested: Dictionary = nested_successor.duplicate(true)
			mutated_nested["representational_fallback_reason"] = null
			var nested_mutation_validation := (
				WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v3(
					mutated_nested
				)
			)
			var ordinary_nested := (
				WorldScript.nested_native_angular_velocity_guard_pair_projection_v3(
					3,
					String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
					String(WorldScript.ORDERED_JOINT_IDS[3]),
					String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
					String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
					case_index + 2,
					target,
					Vector3.ZERO,
					Vector3.ZERO,
					Basis.IDENTITY,
					Basis.IDENTITY,
					ordinary_parent_impulse,
					-ordinary_parent_impulse,
				)
			)
			var signed_velocity_target := (
				-delta_magnitude
				/ (
					WorldScript.FORCE_BASED_VELOCITY_ERROR_GAIN_NM_S_PER_RAD
					* WorldScript.OUTER_STEP_DURATION_S
				)
			)
			var force_predecessor := WorldScript.force_based_joint_impulse_projection_v1(
				3,
				String(WorldScript.ORDERED_ACTUATOR_IDS[3]),
				String(WorldScript.ORDERED_JOINT_IDS[3]),
				String(WorldScript.ORDERED_PARENT_BODY_IDS[3]),
				String(WorldScript.ORDERED_CHILD_BODY_IDS[3]),
				case_index + 1,
				true,
				Vector3.BACK,
				delta_direction,
				signed_velocity_target,
				maxf(absf(signed_velocity_target), 1.0),
				0.0,
				float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[3]),
			)
			var predecessor_pair_exact: bool = (
				_read_vec(force_predecessor.get("parent_angular_impulse_world_nms"))
				== requested_parent_impulse
				and _read_vec(force_predecessor.get("child_angular_impulse_world_nms"))
				== requested_child_impulse
			)
			var mapped_successor: Dictionary = {}
			var mapped_validation: Dictionary = {}
			var scale_projection: Dictionary = {}
			var native_readback: Dictionary = {}
			var readback_validation: Dictionary = {}
			var work_projection: Dictionary = {}
			if bool(force_predecessor.get("ok", false)) and predecessor_pair_exact:
				mapped_successor = (
					WorldScript.refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
						force_predecessor,
						nested_successor,
					)
				)
			if bool(mapped_successor.get("ok", false)):
				mapped_validation = (
					WorldScript.validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
						mapped_successor
					)
				)
				scale_projection = (
					WorldScript.refinement_safe_component_norm_guarded_force_based_applied_scale_projection_v2(
						mapped_successor
					)
				)
				native_readback = (
					WorldScript.refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
						mapped_successor,
						_read_vec(
							nested_successor.get(
								"predicted_parent_angular_velocity_world_rad_s"
							)
						),
						_read_vec(
							nested_successor.get(
								"predicted_child_angular_velocity_world_rad_s"
							)
						),
					)
				)
				work_projection = (
					WorldScript.refinement_safe_component_norm_nested_guarded_force_based_joint_work_projection_v2(
						mapped_successor,
						case_index + 2,
						true,
						Vector3.BACK,
						0.0,
					)
				)
			if bool(native_readback.get("ok", false)):
				readback_validation = (
					WorldScript.validate_refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
						mapped_successor,
						native_readback,
					)
				)
			var production_receipt := _refinement_safe_active_receipt()
			var production_dispatch_accepted := (
				BehaviorWorker.behavior_application_receipt_valid_v2(
					BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED,
					production_receipt,
					false,
				)
			)
			var production_mapping_selected := (
				BehaviorWorker.actuator_mapping_id_for_mode_v1(
					BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED
				)
				== WorldScript.REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				and BehaviorWorker.work_mapping_id_for_mode_v1(
					BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED
				)
				== WorldScript.REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
			var mutated_production := production_receipt.duplicate(true)
			mutated_production["refinement_safe_guard_required"] = false
			var production_mutation_rejected := not (
				BehaviorWorker.behavior_application_receipt_valid_v2(
					BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED,
					mutated_production,
					false,
				)
			)
			if (
				not bool(successor.get("ok", false))
				or not bool(successor.get("representational_zero_impulse_fallback", false))
				or bool(successor.get("r99_projection_succeeded", true))
				or float(successor.get("applied_scale", NAN)) != 0.0
				or JsonTransportScript.stringify(successor.get("refinement_diagnostic"))
				!= JsonTransportScript.stringify(terminal_diagnosis)
				or not bool(successor_validation.get("ok", false))
				or bool(mutation_validation.get("ok", true))
				or bool(diagnostic_mutation_validation.get("ok", true))
				or bool(non_pairing_failure.get("ok", true))
				or String(non_pairing_failure.get("failure_code", ""))
				!= "QSDK_R24D99_GUARD_SOURCE_INVALID:3"
				or not bool(ordinary_successor.get("ok", false))
				or bool(
					ordinary_successor.get("representational_zero_impulse_fallback", true)
				)
				or not bool(ordinary_successor.get("r99_projection_succeeded", false))
				or not bool(nested_successor.get("ok", false))
				or not bool(
					nested_successor.get("representational_zero_impulse_fallback", false)
				)
				or bool(nested_successor.get("r99_projection_succeeded", true))
				or bool(nested_successor.get("outer_guard_zero_impulse_hold", true))
				or not bool(nested_validation.get("ok", false))
				or bool(nested_mutation_validation.get("ok", true))
				or not bool(ordinary_nested.get("ok", false))
				or bool(
					ordinary_nested.get("representational_zero_impulse_fallback", true)
				)
				or not bool(ordinary_nested.get("r99_projection_succeeded", false))
				or not bool(force_predecessor.get("ok", false))
				or not predecessor_pair_exact
				or not bool(mapped_successor.get("ok", false))
				or not bool(mapped_validation.get("ok", false))
				or not bool(scale_projection.get("ok", false))
				or float(scale_projection.get("applied_scale", NAN)) != 0.0
				or not bool(native_readback.get("ok", false))
				or not bool(readback_validation.get("ok", false))
				or not bool(work_projection.get("ok", false))
				or not production_dispatch_accepted
				or not production_mapping_selected
				or not production_mutation_rejected
			):
				return {
					"ok": false,
					"failure_code": "R100_REFINEMENT_SUCCESSOR_CONTROL_FAILED",
					"successor": successor,
					"successor_validation": successor_validation,
					"mutation_validation": mutation_validation,
					"diagnostic_mutation_validation": diagnostic_mutation_validation,
					"non_pairing_failure": non_pairing_failure,
					"ordinary_successor": ordinary_successor,
					"nested_successor": nested_successor,
					"nested_validation": nested_validation,
					"nested_mutation_validation": nested_mutation_validation,
					"ordinary_nested": ordinary_nested,
					"force_predecessor": force_predecessor,
					"predecessor_pair_exact": predecessor_pair_exact,
					"mapped_successor": mapped_successor,
					"mapped_validation": mapped_validation,
					"scale_projection": scale_projection,
					"native_readback": native_readback,
					"readback_validation": readback_validation,
					"work_projection": work_projection,
					"production_receipt": production_receipt,
					"production_dispatch_accepted": production_dispatch_accepted,
					"production_mapping_selected": production_mapping_selected,
					"production_mutation_rejected": production_mutation_rejected,
				}
			return {
				"schema_version": "sporespore_qsdk_r24d100_refinement_safe_successor_zero_world_v1",
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
				"successor_fallback_projection_passed": true,
				"successor_fallback_validation_passed": true,
				"successor_mutation_rejected": true,
				"diagnostic_retention_passed": true,
				"diagnostic_mutation_rejected": true,
				"non_refinement_failure_preserved": true,
				"ordinary_r99_projection_preserved": true,
				"nested_fallback_projection_passed": true,
				"nested_fallback_validation_passed": true,
				"nested_mutation_rejected": true,
				"ordinary_r99_nested_projection_preserved": true,
				"production_mapping_projection_passed": true,
				"production_mapping_validation_passed": true,
				"applied_scale_projection_passed": true,
				"native_readback_projection_passed": true,
				"native_readback_validation_passed": true,
				"centered_work_projection_passed": true,
				"production_dispatch_accepted": true,
				"production_mapping_selected": true,
				"production_mutation_rejected": true,
				"positive_case_count": 12,
				"forced_failure_case_count": 5,
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"body_impulse_write_count": 0,
				"solver_step_count": 0,
				"physics_state_modified": false,
				"physical_question_opened": false,
				"prone_to_standing_claimed": false,
				"physical_acceptance_authority": false,
				"release_authority": false,
			}
	return {
		"schema_version": "sporespore_qsdk_r24d100_refinement_safe_successor_zero_world_v1",
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
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _vec(value: Vector3) -> Dictionary:
	return {"x": float(value.x), "y": float(value.y), "z": float(value.z)}


static func _read_vec(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var item: Dictionary = value
	return Vector3(
		float(item.get("x", NAN)),
		float(item.get("y", NAN)),
		float(item.get("z", NAN)),
	)


static func _refinement_safe_active_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": (
			WorldScript.REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		),
		"work_mapping_id": (
			WorldScript.REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		),
		"validated_command_count": 8,
		"host_write_count": 16,
		"host_readback_count": 8,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"body_impulse_write_count": 16,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_nested_projection_required": true,
		"projection_target_separated_from_native_readback_guard": true,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"numeric_predicate_id": WorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"all_immediate_native_readbacks_inside_guard": true,
		"native_angular_velocity_guard_limit_projection": {"ok": true},
		"native_angular_velocity_inner_projection_target": {"ok": true},
		"native_angular_velocity_initial_readback_count": 9,
		"native_angular_velocity_post_application_readback_count": 16,
		"native_angular_velocity_total_readback_count": 25,
		"native_angular_velocity_guard_engagement_count": 1,
		"native_angular_velocity_guard_minimum_applied_scale": 0.0,
		"physics_state_modified": true,
	}
