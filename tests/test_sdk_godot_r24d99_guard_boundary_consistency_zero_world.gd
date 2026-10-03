extends SceneTree
# gdlint: disable=max-line-length

## R99 pure-data development worker for the exact boundary predicate that
## separated R98's interval solver from its outer-hold fallback. It creates no
## Node, RID, model, world, native write, or solver step.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D99_GUARD_BOUNDARY_CONSISTENCY_ZERO_WORLD "


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
	var source := Vector3(limit, 0.0, 0.0)
	var speed := source.length()
	var squared_speed := source.length_squared()
	var squared_limit := limit * limit
	var component_squared_speed := (
		float(source.x) * float(source.x)
		+ float(source.y) * float(source.y)
		+ float(source.z) * float(source.z)
	)
	var component_speed := sqrt(component_squared_speed)
	var component_relation := (
		WorldScript.angular_velocity_component_norm_limit_relation_v1(
			source, limit
		)
	)
	var requested_parent_impulse := Vector3(0.125, 0.0, 0.0)
	var requested_child_impulse := -requested_parent_impulse
	var legacy_nested := WorldScript.nested_native_angular_velocity_guard_pair_projection_v1(
		0,
		String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
		String(WorldScript.ORDERED_JOINT_IDS[0]),
		String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
		String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
		1,
		target,
		source,
		Vector3.ZERO,
		Basis.IDENTITY,
		Basis.IDENTITY,
		requested_parent_impulse,
		requested_child_impulse,
	)
	var corrected_nested := (
		WorldScript.nested_native_angular_velocity_guard_pair_projection_v2(
			0,
			String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
			String(WorldScript.ORDERED_JOINT_IDS[0]),
			String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
			String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
			1,
			target,
			source,
			Vector3.ZERO,
			Basis.IDENTITY,
			Basis.IDENTITY,
			requested_parent_impulse,
			requested_child_impulse,
		)
	)
	var corrected_validation := (
		WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v2(
			corrected_nested
		)
	)
	var mutated_corrected: Dictionary = corrected_nested.duplicate(true)
	mutated_corrected["applied_scale"] = 1.0
	var mutation_validation := (
		WorldScript.validate_nested_native_angular_velocity_guard_pair_projection_v2(
			mutated_corrected
		)
	)
	var outside_source := Vector3(float(outer["guard_limit_rad_s"]) + 0.01, 0.0, 0.0)
	var outside_projection := (
		WorldScript.nested_native_angular_velocity_guard_pair_projection_v2(
			0,
			String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
			String(WorldScript.ORDERED_JOINT_IDS[0]),
			String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
			String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
			1,
			target,
			outside_source,
			Vector3.ZERO,
			Basis.IDENTITY,
			Basis.IDENTITY,
			requested_parent_impulse,
			requested_child_impulse,
		)
	)
	var mismatched_pair := (
		WorldScript.nested_native_angular_velocity_guard_pair_projection_v2(
			0,
			String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
			String(WorldScript.ORDERED_JOINT_IDS[0]),
			String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
			String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
			1,
			target,
			Vector3.ZERO,
			Vector3.ZERO,
			Basis.IDENTITY,
			Basis.IDENTITY,
			requested_parent_impulse,
			requested_parent_impulse,
		)
	)
	var predecessor := WorldScript.force_based_joint_impulse_projection_v1(
		0,
		String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
		String(WorldScript.ORDERED_JOINT_IDS[0]),
		String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
		String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
		1,
		true,
		Vector3.BACK,
		Vector3.RIGHT,
		-1.0,
		2.0,
		0.0,
		float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[0]),
	)
	var mapped_guard: Dictionary = {}
	var mapped_projection: Dictionary = {}
	var mapped_validation: Dictionary = {}
	var applied_scale_projection: Dictionary = {}
	var readback: Dictionary = {}
	var readback_validation: Dictionary = {}
	var work_projection: Dictionary = {}
	if bool(predecessor.get("ok", false)):
		mapped_guard = (
			WorldScript.nested_native_angular_velocity_guard_pair_projection_v2(
				0,
				String(WorldScript.ORDERED_ACTUATOR_IDS[0]),
				String(WorldScript.ORDERED_JOINT_IDS[0]),
				String(WorldScript.ORDERED_PARENT_BODY_IDS[0]),
				String(WorldScript.ORDERED_CHILD_BODY_IDS[0]),
				1,
				target,
				source,
				Vector3.ZERO,
				Basis.IDENTITY,
				Basis.IDENTITY,
				_vec3(predecessor.get("parent_angular_impulse_world_nms")),
				_vec3(predecessor.get("child_angular_impulse_world_nms")),
			)
		)
	if bool(mapped_guard.get("ok", false)):
		mapped_projection = (
			WorldScript.component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
				predecessor, mapped_guard
			)
		)
	if bool(mapped_projection.get("ok", false)):
		mapped_validation = (
			WorldScript.validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
				mapped_projection
			)
		)
		applied_scale_projection = (
			WorldScript.component_norm_guarded_force_based_applied_scale_projection_v1(
				mapped_projection
			)
		)
		readback = (
			WorldScript.component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
				mapped_projection,
				_vec3(mapped_guard.get("predicted_parent_angular_velocity_world_rad_s")),
				_vec3(mapped_guard.get("predicted_child_angular_velocity_world_rad_s")),
			)
		)
	if bool(readback.get("ok", false)):
		readback_validation = (
			WorldScript.validate_component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
				mapped_projection, readback
			)
		)
	if bool(mapped_projection.get("ok", false)):
		work_projection = (
			WorldScript.component_norm_nested_guarded_force_based_joint_work_projection_v1(
				mapped_projection,
				2,
				true,
				Vector3.BACK,
				0.0,
			)
		)
	var production_receipt := _component_norm_active_receipt()
	var production_dispatch_accepted := (
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED,
			production_receipt,
			false,
		)
	)
	var production_mapping_selected := (
		BehaviorWorker.actuator_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED
		)
		== WorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		and BehaviorWorker.work_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED
		)
		== WorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	)
	var mutated_production := production_receipt.duplicate(true)
	mutated_production["component_norm_numeric_predicate_required"] = false
	var production_mutation_rejected := not (
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED,
			mutated_production,
			false,
		)
	)
	var expected_disagreement := (
		speed <= limit
		and squared_speed > squared_limit
		and component_squared_speed <= squared_limit
		and component_speed <= limit
		and bool(component_relation.get("ok", false))
		and bool(component_relation.get("inside_or_on_limit", false))
		and bool(component_relation.get("exact_component_boundary", false))
		and bool(component_relation.get("legacy_predicates_disagree", false))
		and not bool(legacy_nested.get("ok", false))
		and String(legacy_nested.get("failure_code", ""))
		== "QSDK_R24D96_NESTED_PAIR_TARGET_PROJECTION_FAILED"
		and bool(corrected_nested.get("ok", false))
		and float(corrected_nested.get("applied_scale", NAN)) == 0.0
		and bool(corrected_nested.get("both_predicted_inside_projection_target", false))
		and not bool(corrected_nested.get("outer_guard_zero_impulse_hold", true))
		and bool(corrected_nested.get("component_norm_numeric_predicate_required", false))
		and bool(corrected_validation.get("ok", false))
		and not bool(mutation_validation.get("ok", false))
		and not bool(outside_projection.get("ok", false))
		and not bool(mismatched_pair.get("ok", false))
		and bool(predecessor.get("ok", false))
		and bool(mapped_guard.get("ok", false))
		and bool(mapped_projection.get("ok", false))
		and bool(mapped_validation.get("ok", false))
		and bool(applied_scale_projection.get("ok", false))
		and bool(readback.get("ok", false))
		and bool(readback_validation.get("ok", false))
		and bool(work_projection.get("ok", false))
		and production_dispatch_accepted
		and production_mapping_selected
		and production_mutation_rejected
	)
	return {
		"schema_version": "sporespore_godot_r24d99_guard_boundary_development_probe_v1",
		"gate_id": "QSDK-R24D99",
		"ok": expected_disagreement,
		"failure_code": "" if expected_disagreement else "BOUNDARY_WITNESS_NOT_REPRODUCED",
		"projection_target_limit_rad_s": limit,
		"source_vector": {"x": source.x, "y": source.y, "z": source.z},
		"length_rad_s": speed,
		"length_squared_rad2_s2": squared_speed,
		"limit_squared_rad2_s2": squared_limit,
		"component_squared_rad2_s2": component_squared_speed,
		"component_norm_rad_s": component_speed,
		"legacy_length_predicate_inside": speed <= limit,
		"legacy_squared_predicate_inside": squared_speed <= squared_limit,
		"legacy_predicates_disagree": (speed <= limit) != (squared_speed <= squared_limit),
		"component_squared_predicate_inside": component_squared_speed <= squared_limit,
		"component_norm_predicate_inside": component_speed <= limit,
		"component_norm_relation_summary": {
			"schema_version": String(component_relation.get("schema_version", "")),
			"numeric_predicate_id": String(
				component_relation.get("numeric_predicate_id", "")
			),
			"component_squared_norm_rad2_s2": float(
				component_relation.get("component_squared_norm_rad2_s2", NAN)
			),
			"limit_squared_rad2_s2": float(
				component_relation.get("limit_squared_rad2_s2", NAN)
			),
			"inside_or_on_limit": bool(
				component_relation.get("inside_or_on_limit", false)
			),
			"exact_component_boundary": bool(
				component_relation.get("exact_component_boundary", false)
			),
			"legacy_predicates_disagree": bool(
				component_relation.get("legacy_predicates_disagree", false)
			),
		},
		"legacy_nested_projection_ok": bool(legacy_nested.get("ok", false)),
		"legacy_nested_projection_failure_code": String(
			legacy_nested.get("failure_code", "")
		),
		"corrected_nested_projection_summary": {
			"schema_version": String(corrected_nested.get("schema_version", "")),
			"numeric_predicate_id": String(
				corrected_nested.get("numeric_predicate_id", "")
			),
			"applied_scale": float(corrected_nested.get("applied_scale", NAN)),
			"feasible_scale_lower": float(
				corrected_nested.get("feasible_scale_lower", NAN)
			),
			"feasible_scale_upper": float(
				corrected_nested.get("feasible_scale_upper", NAN)
			),
			"both_predicted_inside_projection_target": bool(
				corrected_nested.get("both_predicted_inside_projection_target", false)
			),
			"outer_guard_zero_impulse_hold": bool(
				corrected_nested.get("outer_guard_zero_impulse_hold", true)
			),
		},
		"corrected_nested_projection_validation_passed": bool(
			corrected_validation.get("ok", false)
		),
		"mutated_receipt_rejected": not bool(mutation_validation.get("ok", false)),
		"source_above_outer_guard_rejected": not bool(
			outside_projection.get("ok", false)
		),
		"mismatched_impulse_pair_rejected": not bool(mismatched_pair.get("ok", false)),
		"mapped_projection_validation_passed": bool(mapped_validation.get("ok", false)),
		"applied_scale_projection_passed": bool(
			applied_scale_projection.get("ok", false)
		),
		"native_readback_validation_passed": bool(
			readback_validation.get("ok", false)
		),
		"centered_work_projection_passed": bool(work_projection.get("ok", false)),
		"production_dispatch_accepted": production_dispatch_accepted,
		"production_mapping_selected": production_mapping_selected,
		"production_mutation_rejected": production_mutation_rejected,
		"positive_case_count": 8,
		"forced_failure_case_count": 5,
		"outer_guard_exceedance_established": false,
		"diagnosis": "mixed_vector_length_and_length_squared_numeric_predicates",
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


static func _component_norm_active_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": (
			WorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		),
		"work_mapping_id": (
			WorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
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


static func _vec3(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source_value: Dictionary = value
	return Vector3(
		float(source_value.get("x", NAN)),
		float(source_value.get("y", NAN)),
		float(source_value.get("z", NAN)),
	)
