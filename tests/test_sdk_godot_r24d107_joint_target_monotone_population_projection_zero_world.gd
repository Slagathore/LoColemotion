extends SceneTree
# gdlint: disable=max-line-length

## Compact R107 pure-projection and mutation proof. No Node, RID, model, world,
## native readback, body write, or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const LegacyPopulationTest := preload(
	"res://tests/test_sdk_godot_r24d103_order_neutral_population_projection_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D107_JOINT_TARGET_MONOTONE_POPULATION_ZERO_WORLD "


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var runtime := WorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	var outer := WorldScript.native_angular_velocity_guard_limit_projection_v1(runtime)
	var target := WorldScript.native_angular_velocity_inner_projection_target_v1(outer)
	if not bool(target.get("ok", false)):
		return _failure("TARGET_INVALID", target)
	var sources := _sources(Vector3.ZERO)
	var inertias := _inertias(10.0)
	var positive_predecessors := _balanced_predecessors(1.0, 0.0)
	var positive := (
		WorldScript
		. joint_target_monotone_population_guard_projection_v1(
			positive_predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var positive_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(positive)
	)
	var reversed_predecessors := positive_predecessors.duplicate(true)
	reversed_predecessors.reverse()
	var reversed := (
		WorldScript
		. joint_target_monotone_population_guard_projection_v1(
			reversed_predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var order_neutral := (
		JsonTransportScript.stringify(positive) == JsonTransportScript.stringify(reversed)
	)

	var nonhelpful_predecessors := _neutral_predecessors()
	nonhelpful_predecessors[0] = _predecessor(0, 0.001, 0.0)
	nonhelpful_predecessors[1] = _predecessor(1, 1.0, -100.0)
	var nonhelpful := (
		WorldScript
		. joint_target_monotone_population_guard_projection_v1(
			nonhelpful_predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var nonhelpful_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(nonhelpful)
	)
	var neutral := (
		WorldScript
		. joint_target_monotone_population_guard_projection_v1(
			_neutral_predecessors(),
			sources,
			inertias,
			17,
			target,
		)
	)
	var neutral_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(neutral)
	)
	if not bool(positive.get("ok", false)):
		return _failure("POSITIVE_PROJECTION_INVALID", positive)
	if not bool(nonhelpful.get("ok", false)):
		return _failure("NONHELPFUL_PROJECTION_INVALID", nonhelpful)
	if not bool(neutral.get("ok", false)):
		return _failure("NEUTRAL_PROJECTION_INVALID", neutral)

	var scale_mutation: Dictionary = positive.duplicate(true)
	scale_mutation["target_common_pre_scale"] = 1.0
	var scale_mutation_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(scale_mutation)
	)
	var target_mutation: Dictionary = positive.duplicate(true)
	var target_joint_rows: Array = target_mutation["ordered_joint_target_projections"]
	var target_joint_row: Dictionary = target_joint_rows[0]
	target_joint_row["canonical_target_velocity_rad_s"] = 0.5
	var target_mutation_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(target_mutation)
	)
	var body_mutation: Dictionary = positive.duplicate(true)
	var body_guard: Dictionary = body_mutation["body_guard_population_projection"]
	var body_rows: Array = body_guard["ordered_body_projections"]
	var body_row: Dictionary = body_rows[0]
	var applied_impulse: Dictionary = body_row["applied_aggregate_impulse_world_nms"]
	applied_impulse["x"] = float(applied_impulse["x"]) + 0.001
	var body_mutation_validation := (
		WorldScript.validate_joint_target_monotone_population_guard_projection_v1(body_mutation)
	)
	var duplicate_predecessors := positive_predecessors.duplicate(true)
	duplicate_predecessors[7] = (duplicate_predecessors[0] as Dictionary).duplicate(true)
	var duplicate_refusal := (
		WorldScript
		. joint_target_monotone_population_guard_projection_v1(
			duplicate_predecessors,
			sources,
			inertias,
			20,
			target,
		)
	)
	var mapped_projections: Array = []
	var all_mapping_projections_passed := true
	var all_mapping_validations_passed := true
	var all_applied_scale_projections_passed := true
	for actuator_index in range(positive_predecessors.size()):
		var mapped := (
			WorldScript
			. joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
				positive_predecessors[actuator_index],
				positive,
				actuator_index,
			)
		)
		var mapped_validation := (
			WorldScript
			. validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
				mapped,
				positive,
			)
		)
		var applied_scale_projection := (
			WorldScript
			. joint_target_monotone_population_guarded_force_based_applied_scale_projection_v1(
				mapped,
				positive,
			)
		)
		all_mapping_projections_passed = (
			all_mapping_projections_passed and bool(mapped.get("ok", false))
		)
		all_mapping_validations_passed = (
			all_mapping_validations_passed and bool(mapped_validation.get("ok", false))
		)
		all_applied_scale_projections_passed = (
			all_applied_scale_projections_passed
			and bool(applied_scale_projection.get("ok", false))
			and float(applied_scale_projection.get("applied_scale", NAN))
			== float(positive.get("nominal_composed_common_scale", NAN))
		)
		mapped_projections.append(mapped)
	var mapped_mutation: Dictionary = (mapped_projections[0] as Dictionary).duplicate(true)
	mapped_mutation["target_common_pre_scale"] = 1.0
	var mapped_mutation_validation := (
		WorldScript
		. validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
			mapped_mutation,
			positive,
		)
	)
	var positive_body_guard_projection: Dictionary = positive["body_guard_population_projection"]
	var predicted_post_by_body_id: Dictionary = {}
	for body_value in positive_body_guard_projection["ordered_body_projections"]:
		var body: Dictionary = body_value
		predicted_post_by_body_id[String(body["body_id"])] = _read_vec(
			body["predicted_angular_velocity_world_rad_s"]
		)
	var population_readback := (
		WorldScript
		. order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			positive_body_guard_projection,
			predicted_post_by_body_id,
		)
	)
	var population_readback_validation := (
		WorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			positive_body_guard_projection,
			population_readback,
		)
	)
	var all_joint_readback_projections_passed := true
	var all_joint_readback_validations_passed := true
	var all_work_projections_passed := true
	var joint_readbacks: Array = []
	for actuator_index in range(mapped_projections.size()):
		var mapped: Dictionary = mapped_projections[actuator_index]
		var joint_readback := (
			WorldScript
			. joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				positive,
				population_readback,
			)
		)
		var joint_readback_validation := (
			WorldScript
			. validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				positive,
				population_readback,
				joint_readback,
			)
		)
		var work_projection := (
			WorldScript
			. joint_target_monotone_population_guarded_force_based_joint_work_projection_v1(
				mapped,
				positive,
				18,
				true,
				Vector3.BACK,
				0.0,
			)
		)
		all_joint_readback_projections_passed = (
			all_joint_readback_projections_passed and bool(joint_readback.get("ok", false))
		)
		all_joint_readback_validations_passed = (
			all_joint_readback_validations_passed
			and bool(joint_readback_validation.get("ok", false))
		)
		all_work_projections_passed = (
			all_work_projections_passed and bool(work_projection.get("ok", false))
		)
		joint_readbacks.append(joint_readback)
	var joint_readback_mutation: Dictionary = (joint_readbacks[0] as Dictionary).duplicate(true)
	joint_readback_mutation["joint_target_monotone_projection_is_prewrite_action_authority"] = false
	var joint_readback_mutation_validation := (
		WorldScript
		. validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
			mapped_projections[0],
			positive,
			population_readback,
			joint_readback_mutation,
		)
	)
	var production_application_receipt := _production_application_receipt(
		positive,
		mapped_projections,
		population_readback,
		joint_readbacks,
		outer,
		target,
	)
	var production_application_receipt_valid := (
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED,
			production_application_receipt,
			false,
		)
	)
	var production_mode_mappings_valid := (
		BehaviorWorker.actuator_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED
		)
		== WorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		and BehaviorWorker.work_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED
		)
		== WorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	)
	var production_scale_mutation: Dictionary = production_application_receipt.duplicate(true)
	production_scale_mutation["joint_target_monotone_common_pre_scale"] = 1.0
	var production_scale_mutation_rejected := not BehaviorWorker.behavior_application_receipt_valid_v2(
		BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED,
		production_scale_mutation,
		false,
	)
	var production_body_mutation: Dictionary = production_application_receipt.duplicate(true)
	var mutated_body_receipts: Array = production_body_mutation[
		"ordered_body_application_receipts"
	]
	var mutated_body_receipt: Dictionary = mutated_body_receipts[0]
	var mutated_body_impulse: Dictionary = mutated_body_receipt[
		"aggregate_impulse_world_nms"
	]
	mutated_body_impulse["x"] = float(mutated_body_impulse["x"]) + 0.001
	var production_body_mutation_rejected := not BehaviorWorker.behavior_application_receipt_valid_v2(
		BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED,
		production_body_mutation,
		false,
	)
	var legacy_regression := LegacyPopulationTest._run()

	var positive_scale := float(positive.get("target_common_pre_scale", NAN))
	var positive_body_guard_value: Variant = positive.get("body_guard_population_projection")
	var positive_body_guard: Dictionary = (
		positive_body_guard_value if positive_body_guard_value is Dictionary else {}
	)
	var nonhelpful_body_guard_value: Variant = nonhelpful.get("body_guard_population_projection")
	var nonhelpful_body_guard: Dictionary = (
		nonhelpful_body_guard_value if nonhelpful_body_guard_value is Dictionary else {}
	)
	if (
		not bool(positive.get("ok", false))
		or not bool(positive_validation.get("ok", false))
		or not is_finite(positive_scale)
		or positive_scale <= 0.0
		or positive_scale >= 1.0
		or not bool(positive.get("all_joint_target_errors_nonincreasing", false))
		or int(positive.get("joint_target_crossing_count", -1)) != 0
		or int(positive.get("helpful_joint_projection_count", -1)) != 8
		or int(positive.get("nonhelpful_joint_projection_count", -1)) != 0
		or not bool(positive_body_guard.get("ok", false))
		or not bool(positive_body_guard.get("all_predicted_inside_outer_guard", false))
		or not order_neutral
		or not bool(nonhelpful.get("ok", false))
		or not bool(nonhelpful_validation.get("ok", false))
		or not bool(nonhelpful.get("population_zero_hold_for_nonhelpful_joint_delta", false))
		or int(nonhelpful.get("nonhelpful_joint_projection_count", 0)) < 1
		or float(nonhelpful.get("target_common_pre_scale", NAN)) != 0.0
		or int(nonhelpful.get("nonzero_body_impulse_count", -1)) != 0
		or int(nonhelpful_body_guard.get("nonzero_body_impulse_count", -1)) != 0
		or not bool(nonhelpful.get("all_joint_target_errors_nonincreasing", false))
		or int(nonhelpful.get("joint_target_crossing_count", -1)) != 0
		or not bool(neutral.get("ok", false))
		or not bool(neutral_validation.get("ok", false))
		or float(neutral.get("target_common_pre_scale", NAN)) != 1.0
		or int(neutral.get("neutral_joint_projection_count", -1)) != 8
		or int(neutral.get("nonzero_body_impulse_count", -1)) != 0
		or bool(scale_mutation_validation.get("ok", true))
		or bool(target_mutation_validation.get("ok", true))
		or bool(body_mutation_validation.get("ok", true))
		or bool(duplicate_refusal.get("ok", true))
		or not all_mapping_projections_passed
		or not all_mapping_validations_passed
		or not all_applied_scale_projections_passed
		or bool(mapped_mutation_validation.get("ok", true))
		or not bool(population_readback.get("ok", false))
		or not bool(population_readback_validation.get("ok", false))
		or not all_joint_readback_projections_passed
		or not all_joint_readback_validations_passed
		or not all_work_projections_passed
		or bool(joint_readback_mutation_validation.get("ok", true))
		or not production_application_receipt_valid
		or not production_mode_mappings_valid
		or not production_scale_mutation_rejected
		or not production_body_mutation_rejected
		or not bool(legacy_regression.get("ok", false))
	):
		return {
			"ok": false,
			"failure_code": "R107_TARGET_MONOTONE_CONTROL_FAILED",
			"positive": positive,
			"positive_validation": positive_validation,
			"reversed": reversed,
			"order_neutral": order_neutral,
			"nonhelpful": nonhelpful,
			"nonhelpful_validation": nonhelpful_validation,
			"neutral": neutral,
			"neutral_validation": neutral_validation,
			"scale_mutation_validation": scale_mutation_validation,
			"target_mutation_validation": target_mutation_validation,
			"body_mutation_validation": body_mutation_validation,
			"duplicate_refusal": duplicate_refusal,
			"all_mapping_projections_passed": all_mapping_projections_passed,
			"all_mapping_validations_passed": all_mapping_validations_passed,
			"all_applied_scale_projections_passed":
			all_applied_scale_projections_passed,
			"mapped_mutation_validation": mapped_mutation_validation,
			"population_readback": population_readback,
			"population_readback_validation": population_readback_validation,
			"all_joint_readback_projections_passed":
			all_joint_readback_projections_passed,
			"all_joint_readback_validations_passed":
			all_joint_readback_validations_passed,
			"all_work_projections_passed": all_work_projections_passed,
			"joint_readback_mutation_validation": joint_readback_mutation_validation,
			"production_application_receipt": production_application_receipt,
			"production_application_receipt_valid": production_application_receipt_valid,
			"production_mode_mappings_valid": production_mode_mappings_valid,
			"production_scale_mutation_rejected": production_scale_mutation_rejected,
			"production_body_mutation_rejected": production_body_mutation_rejected,
			"legacy_regression": legacy_regression,
		}
	return {
		"schema_version":
		"sporespore_qsdk_r24d107_joint_target_monotone_population_zero_world_v1",
		"gate_id": "QSDK-R24D107",
		"ok": true,
		"question_class": "development",
		"positive_target_common_pre_scale": positive_scale,
		"positive_body_guard_common_scale":
		float(positive.get("body_guard_common_applied_scale", NAN)),
		"positive_composed_nominal_scale":
		float(positive.get("nominal_composed_common_scale", NAN)),
		"positive_case_count": 48,
		"forced_failure_case_count": 8,
		"order_permutation_exact": true,
		"all_positive_joint_target_errors_nonincreasing": true,
		"positive_joint_target_crossing_count": 0,
		"population_nonhelpful_zero_hold_passed": true,
		"population_neutral_full_scale_passed": true,
		"projection_mutations_rejected": true,
		"joint_mapping_projection_passed": true,
		"joint_mapping_validation_passed": true,
		"applied_scale_projection_passed": true,
		"population_readback_projection_passed": true,
		"population_readback_validation_passed": true,
		"joint_readback_projection_passed": true,
		"joint_readback_validation_passed": true,
		"centered_work_projection_passed": true,
		"production_application_receipt_passed": true,
		"production_mode_mapping_passed": true,
		"production_receipt_mutations_rejected": true,
		"r103_legacy_regression_passed": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _production_application_receipt(
	population: Dictionary,
	mapped_projections: Array,
	population_readback: Dictionary,
	joint_readbacks: Array,
	guard_limit: Dictionary,
	inner_target: Dictionary,
) -> Dictionary:
	var ordered_receipts: Array = []
	for actuator_index in range(mapped_projections.size()):
		var receipt: Dictionary = (mapped_projections[actuator_index] as Dictionary).duplicate(true)
		receipt["aggregate_body_application"] = true
		receipt["joint_attribution_only"] = true
		receipt["direct_joint_body_impulse_write_count"] = 0
		receipt["body_impulse_write_count"] = 0
		receipt["native_angular_velocity_readback"] = joint_readbacks[actuator_index]
		ordered_receipts.append(receipt)

	var body_guard: Dictionary = population["body_guard_population_projection"]
	var body_projections: Array = body_guard["ordered_body_projections"]
	var ordered_body_receipts: Array = []
	var body_write_count := 0
	for body_index in range(body_projections.size()):
		var body_projection: Dictionary = body_projections[body_index]
		var call_performed := bool(body_projection["nonzero_body_impulse"])
		body_write_count += int(call_performed)
		ordered_body_receipts.append(
			{
				"body_index": body_index,
				"body_id": String(WorldScript.ORDERED_BODY_IDS[body_index]),
				"api": "RigidBody3D.apply_torque_impulse",
				"call_performed": call_performed,
				"call_returned": call_performed,
				"body_impulse_write_count": int(call_performed),
				"canonical_body_order": true,
				"aggregate_impulse_world_nms": body_projection[
					"applied_aggregate_impulse_world_nms"
				],
			}
		)
	var population_guard_engaged := (
		bool(population["target_guard_engaged"])
		or bool(body_guard["population_guard_engaged"])
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_command_application_receipt_v1",
		"ok": true,
		"actuator_mapping_id":
		WorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id":
		WorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": WorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"semantic_step": 18,
		"source_control_semantic_step": 17,
		"phase": "recover",
		"command_id":
		"r24d107_godot_joint_target_monotone_population_guarded_force_based_command_step_18",
		"command_sha256": "synthetic-zero-world-command-sha256",
		"zero_command": false,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"ordered_intents": ordered_receipts.duplicate(true),
		"validated_command_count": WorldScript.ORDERED_ACTUATOR_IDS.size(),
		"host_write_count": body_write_count,
		"host_readback_count": WorldScript.ORDERED_ACTUATOR_IDS.size(),
		"body_impulse_write_count": body_write_count,
		"ordered_receipts": ordered_receipts,
		"ordered_body_application_receipts": ordered_body_receipts,
		"order_neutral_population_native_angular_velocity_readback": population_readback,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_guard_limit_projection": guard_limit,
		"native_angular_velocity_guard_engagement_count":
		WorldScript.ORDERED_ACTUATOR_IDS.size() if population_guard_engaged else 0,
		"native_angular_velocity_guard_minimum_applied_scale": float(
			population["nominal_composed_common_scale"]
		),
		"native_angular_velocity_initial_readback_count": WorldScript.ORDERED_BODY_IDS.size(),
		"native_angular_velocity_post_application_readback_count": WorldScript.ORDERED_BODY_IDS.size(),
		"native_angular_velocity_total_readback_count": 2 * WorldScript.ORDERED_BODY_IDS.size(),
		"all_immediate_native_readbacks_inside_guard": true,
		"native_angular_velocity_inner_projection_target": inner_target,
		"native_angular_velocity_nested_projection_required": true,
		"projection_target_separated_from_native_readback_guard": true,
		"numeric_predicate_id": WorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"input_iteration_order_has_action_authority": false,
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"physics_state_modified": body_write_count > 0,
		"joint_target_monotone_population_guard_projection": population,
		"joint_target_monotone_population_projection_required": true,
		"joint_target_monotone_common_pre_scale": float(population["target_common_pre_scale"]),
		"body_guard_common_applied_scale": float(population["body_guard_common_applied_scale"]),
		"population_zero_hold_for_nonhelpful_joint_delta": bool(
			population["population_zero_hold_for_nonhelpful_joint_delta"]
		),
		"all_joint_target_errors_nonincreasing": true,
		"joint_target_crossing_count": 0,
	}


static func _uniform_predecessors(target_velocity: float, measured_velocity: float) -> Array:
	var result: Array = []
	for actuator_index in range(WorldScript.ORDERED_ACTUATOR_IDS.size()):
		result.append(_predecessor(actuator_index, target_velocity, measured_velocity))
	return result


static func _balanced_predecessors(target_velocity: float, measured_velocity: float) -> Array:
	# Hip impulses cancel at the shared torso, while each knee axis is orthogonal
	# to its hip. Every aggregate relative delta therefore points toward the
	# controller target without relying on a measured campaign trace.
	var axes := [
		Vector3.RIGHT,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.BACK,
		Vector3.UP,
		Vector3.BACK,
		Vector3.DOWN,
		Vector3.BACK,
	]
	var result: Array = []
	for actuator_index in range(WorldScript.ORDERED_ACTUATOR_IDS.size()):
		result.append(
			_predecessor(
				actuator_index,
				target_velocity,
				measured_velocity,
				axes[actuator_index],
			)
		)
	return result


static func _neutral_predecessors() -> Array:
	return _uniform_predecessors(0.0, 0.0)


static func _predecessor(
	actuator_index: int,
	target_velocity: float,
	measured_velocity: float,
	axis_world: Vector3 = Vector3.RIGHT,
) -> Dictionary:
	return (
		WorldScript
		. force_based_joint_impulse_projection_v1(
			actuator_index,
			String(WorldScript.ORDERED_ACTUATOR_IDS[actuator_index]),
			String(WorldScript.ORDERED_JOINT_IDS[actuator_index]),
			String(WorldScript.ORDERED_PARENT_BODY_IDS[actuator_index]),
			String(WorldScript.ORDERED_CHILD_BODY_IDS[actuator_index]),
			17 if actuator_index >= 0 else -1,
			true,
			Vector3.BACK,
			axis_world,
			target_velocity,
			1.0,
			measured_velocity,
			float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[actuator_index]),
		)
	)


static func _sources(value: Vector3) -> Dictionary:
	var result: Dictionary = {}
	for body_id_value in WorldScript.ORDERED_BODY_IDS:
		result[String(body_id_value)] = value
	return result


static func _inertias(diagonal: float) -> Dictionary:
	var tensor := Basis(
		Vector3(diagonal, 0.0, 0.0),
		Vector3(0.0, diagonal, 0.0),
		Vector3(0.0, 0.0, diagonal),
	)
	var result: Dictionary = {}
	for body_id_value in WorldScript.ORDERED_BODY_IDS:
		result[String(body_id_value)] = tensor
	return result


static func _read_vec(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var item: Dictionary = value
	return Vector3(
		float(item.get("x", NAN)),
		float(item.get("y", NAN)),
		float(item.get("z", NAN)),
	)


static func _failure(code: String, detail: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
