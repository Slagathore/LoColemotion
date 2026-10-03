extends SceneTree
# gdlint: disable=max-line-length

## Compact R103 pure-population proof. No Node, RID, model, world, native
## write, readback, or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const RouteGhostWorker := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D103_ORDER_NEUTRAL_POPULATION_ZERO_WORLD "


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
	var target_limit := float(target["projection_target_limit_rad_s"])
	var outer_limit := float(target["outer_guard_limit_rad_s"])
	var predecessors := _force_predecessors()
	var requests := _requests_from_predecessors(predecessors)
	var sources := _sources(Vector3(target_limit * 0.99, 0.0, 0.0))
	var inertias := _inertias(10.0)
	var projection := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			requests,
			sources,
			inertias,
			17,
			target,
		)
	)
	var validation := WorldScript.validate_order_neutral_population_guard_projection_v1(projection)
	var reversed_requests := requests.duplicate(true)
	reversed_requests.reverse()
	var reversed_projection := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			reversed_requests,
			sources,
			inertias,
			17,
			target,
		)
	)
	var reconstruction_passed := _attribution_reconstructs_bodies(projection)

	var scale_mutation: Dictionary = projection.duplicate(true)
	scale_mutation["common_applied_scale"] = 1.0
	var scale_mutation_validation := (
		WorldScript.validate_order_neutral_population_guard_projection_v1(scale_mutation)
	)
	var body_mutation: Dictionary = projection.duplicate(true)
	var mutated_bodies: Array = body_mutation["ordered_body_projections"]
	var first_body: Dictionary = mutated_bodies[0]
	var mutated_impulse: Dictionary = first_body["applied_aggregate_impulse_world_nms"]
	mutated_impulse["x"] = float(mutated_impulse["x"]) + 0.001
	var body_mutation_validation := (
		WorldScript.validate_order_neutral_population_guard_projection_v1(body_mutation)
	)
	var duplicate_requests := requests.duplicate(true)
	duplicate_requests[7] = (duplicate_requests[0] as Dictionary).duplicate(true)
	var duplicate_refusal := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			duplicate_requests,
			sources,
			inertias,
			17,
			target,
		)
	)
	var non_pairing_requests := requests.duplicate(true)
	var non_pairing: Dictionary = non_pairing_requests[3]
	non_pairing["requested_parent_impulse_world_nms"] = (non_pairing["requested_child_impulse_world_nms"])
	var non_pairing_refusal := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			non_pairing_requests,
			sources,
			inertias,
			17,
			target,
		)
	)

	var hold_sources := _sources(Vector3.ZERO)
	hold_sources[String(WorldScript.ORDERED_BODY_IDS[8])] = Vector3(
		0.5 * (target_limit + outer_limit), 0.0, 0.0
	)
	var hold_projection := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			_requests(0.0),
			hold_sources,
			inertias,
			18,
			target,
		)
	)
	var hold_validation := WorldScript.validate_order_neutral_population_guard_projection_v1(
		hold_projection
	)
	var invalid_sources := _sources(Vector3.ZERO)
	invalid_sources[String(WorldScript.ORDERED_BODY_IDS[8])] = Vector3(
		outer_limit * 1.001, 0.0, 0.0
	)
	var outer_refusal := (
		WorldScript
		. order_neutral_population_guard_projection_v1(
			_requests(0.0),
			invalid_sources,
			inertias,
			19,
			target,
		)
	)

	var common_scale := float(projection.get("common_applied_scale", NAN))
	var mapped_projections: Array = []
	var all_mapping_projections_passed := predecessors.size() == 8
	var all_mapping_validations_passed := predecessors.size() == 8
	var all_scale_projections_passed := predecessors.size() == 8
	for index in range(predecessors.size()):
		var predecessor: Dictionary = predecessors[index]
		var mapped := (
			WorldScript
			. order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
				predecessor,
				projection,
				index,
			)
		)
		var mapped_validation := (
			WorldScript
			. validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
				mapped,
				projection,
			)
		)
		var scale_projection := (
			WorldScript
			. order_neutral_population_guarded_force_based_applied_scale_projection_v1(
				mapped,
				projection,
			)
		)
		all_mapping_projections_passed = (
			all_mapping_projections_passed and bool(mapped.get("ok", false))
		)
		all_mapping_validations_passed = (
			all_mapping_validations_passed and bool(mapped_validation.get("ok", false))
		)
		all_scale_projections_passed = (
			all_scale_projections_passed
			and bool(scale_projection.get("ok", false))
			and float(scale_projection.get("applied_scale", NAN)) == common_scale
		)
		mapped_projections.append(mapped)
	var mapped_mutation: Dictionary = (mapped_projections[0] as Dictionary).duplicate(true)
	mapped_mutation["common_applied_scale"] = 1.0
	var mapped_mutation_validation := (
		WorldScript
		. validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
			mapped_mutation,
			projection,
		)
	)

	var predicted_post: Dictionary = {}
	for body_value in projection["ordered_body_projections"]:
		var body: Dictionary = body_value
		predicted_post[String(body["body_id"])] = _read_vec(
			body["predicted_angular_velocity_world_rad_s"]
		)
	var population_readback := (
		WorldScript
		. order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			projection,
			predicted_post,
		)
	)
	var population_readback_validation := (
		WorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			projection,
			population_readback,
		)
	)
	var all_joint_readbacks_passed := true
	var all_work_projections_passed := true
	var joint_readbacks: Array = []
	for index in range(mapped_projections.size()):
		var mapped: Dictionary = mapped_projections[index]
		var joint_readback := (
			WorldScript
			. order_neutral_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				projection,
				population_readback,
			)
		)
		var joint_readback_validation := (
			WorldScript
			. validate_order_neutral_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				projection,
				population_readback,
				joint_readback,
			)
		)
		var work_projection := (
			WorldScript
			. order_neutral_population_guarded_force_based_joint_work_projection_v1(
				mapped,
				projection,
				18,
				true,
				Vector3.BACK,
				0.0,
			)
		)
		all_joint_readbacks_passed = (
			all_joint_readbacks_passed
			and bool(joint_readback.get("ok", false))
			and bool(joint_readback_validation.get("ok", false))
		)
		all_work_projections_passed = (
			all_work_projections_passed and bool(work_projection.get("ok", false))
		)
		joint_readbacks.append(joint_readback)
	var readback_mutation: Dictionary = population_readback.duplicate(true)
	var mutated_readbacks: Array = readback_mutation["ordered_body_readbacks"]
	var first_readback: Dictionary = mutated_readbacks[0]
	var mutated_velocity: Dictionary = first_readback["angular_velocity_world_rad_s"]
	mutated_velocity["x"] = outer_limit * 2.0
	var readback_mutation_validation := (
		WorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			projection,
			readback_mutation,
		)
	)

	var order_neutral := (
		JsonTransportScript.stringify(projection)
		== JsonTransportScript.stringify(reversed_projection)
	)
	var production_receipt := _production_receipt(
		projection,
		population_readback,
		mapped_projections,
		joint_readbacks,
		outer,
		target,
	)
	var production_dispatch_accepted := (
		BehaviorWorker
		. behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
			production_receipt,
			false,
		)
	)
	var production_mapping_selected := (
		(
			BehaviorWorker.actuator_mapping_id_for_mode_v1(
				BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED
			)
			== WorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		and (
			BehaviorWorker.work_mapping_id_for_mode_v1(
				BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED
			)
			== WorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	)
	var mutated_production := production_receipt.duplicate(true)
	var mutated_body_receipts: Array = mutated_production["ordered_body_application_receipts"]
	var mutated_body_receipt: Dictionary = mutated_body_receipts[0]
	var mutated_aggregate: Dictionary = mutated_body_receipt["aggregate_impulse_world_nms"]
	mutated_aggregate["x"] = float(mutated_aggregate["x"]) + 0.001
	var production_mutation_rejected := not (
		BehaviorWorker
		. behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
			mutated_production,
			false,
		)
	)
	var route_ghost_receipt_validation_passed := (
		RouteGhostWorker.validate_order_neutral_population_route_application_v1(
			production_receipt
		)
	)
	var route_ghost_mutation: Dictionary = production_receipt.duplicate(true)
	route_ghost_mutation["body_impulse_write_count"] = 8
	var route_ghost_mutation_rejected := not (
		RouteGhostWorker.validate_order_neutral_population_route_application_v1(
			route_ghost_mutation
		)
	)
	if (
		not bool(projection.get("ok", false))
		or not bool(validation.get("ok", false))
		or not is_finite(common_scale)
		or common_scale <= 0.0
		or common_scale >= 1.0
		or int(projection.get("actuator_count", -1)) != 8
		or int(projection.get("body_count", -1)) != 9
		or int(projection.get("nonzero_body_impulse_count", -1)) != 9
		or not bool(projection.get("all_predicted_inside_projection_target", false))
		or not bool(projection.get("all_predicted_inside_outer_guard", false))
		or not order_neutral
		or not reconstruction_passed
		or bool(scale_mutation_validation.get("ok", true))
		or bool(body_mutation_validation.get("ok", true))
		or bool(duplicate_refusal.get("ok", true))
		or bool(non_pairing_refusal.get("ok", true))
		or not bool(hold_projection.get("ok", false))
		or not bool(hold_projection.get("outer_guard_zero_impulse_hold", false))
		or bool(hold_projection.get("representational_zero_impulse_fallback", true))
		or float(hold_projection.get("common_applied_scale", NAN)) != 0.0
		or bool(hold_projection.get("all_predicted_inside_projection_target", true))
		or not bool(hold_projection.get("all_predicted_inside_outer_guard", false))
		or not bool(hold_validation.get("ok", false))
		or bool(outer_refusal.get("ok", true))
		or not all_mapping_projections_passed
		or not all_mapping_validations_passed
		or not all_scale_projections_passed
		or bool(mapped_mutation_validation.get("ok", true))
		or not bool(population_readback.get("ok", false))
		or not bool(population_readback_validation.get("ok", false))
		or not all_joint_readbacks_passed
		or not all_work_projections_passed
		or bool(readback_mutation_validation.get("ok", true))
		or not production_dispatch_accepted
		or not production_mapping_selected
		or not production_mutation_rejected
		or not route_ghost_receipt_validation_passed
		or not route_ghost_mutation_rejected
	):
		return {
			"ok": false,
			"failure_code": "R103_POPULATION_CONTROL_FAILED",
			"projection": projection,
			"validation": validation,
			"reversed_projection": reversed_projection,
			"order_neutral": order_neutral,
			"reconstruction_passed": reconstruction_passed,
			"scale_mutation_validation": scale_mutation_validation,
			"body_mutation_validation": body_mutation_validation,
			"duplicate_refusal": duplicate_refusal,
			"non_pairing_refusal": non_pairing_refusal,
			"hold_projection": hold_projection,
			"hold_validation": hold_validation,
			"outer_refusal": outer_refusal,
			"predecessors": predecessors,
			"mapped_projections": mapped_projections,
			"mapped_mutation_validation": mapped_mutation_validation,
			"population_readback": population_readback,
			"population_readback_validation": population_readback_validation,
			"readback_mutation_validation": readback_mutation_validation,
			"all_mapping_projections_passed": all_mapping_projections_passed,
			"all_mapping_validations_passed": all_mapping_validations_passed,
			"all_scale_projections_passed": all_scale_projections_passed,
			"all_joint_readbacks_passed": all_joint_readbacks_passed,
			"all_work_projections_passed": all_work_projections_passed,
			"production_receipt": production_receipt,
			"production_dispatch_accepted": production_dispatch_accepted,
			"production_mapping_selected": production_mapping_selected,
			"production_mutation_rejected": production_mutation_rejected,
			"route_ghost_receipt_validation_passed": route_ghost_receipt_validation_passed,
			"route_ghost_mutation_rejected": route_ghost_mutation_rejected,
		}
	return {
		"schema_version": "sporespore_qsdk_r24d103_order_neutral_population_zero_world_v1",
		"gate_id": "QSDK-R24D103",
		"ok": true,
		"question_class": "development",
		"common_applied_scale": common_scale,
		"actuator_count": 8,
		"body_count": 9,
		"nonzero_body_impulse_count": 9,
		"order_permutation_exact": true,
		"body_attribution_reconstruction_passed": true,
		"all_predicted_inside_projection_target": true,
		"outer_hold_control_passed": true,
		"production_mapping_projection_passed": true,
		"production_mapping_validation_passed": true,
		"applied_scale_projection_passed": true,
		"population_readback_projection_passed": true,
		"population_readback_validation_passed": true,
		"joint_readback_projection_passed": true,
		"centered_work_projection_passed": true,
		"production_dispatch_accepted": true,
		"production_mapping_selected": true,
		"production_mutation_rejected": true,
		"route_ghost_receipt_validation_passed": true,
		"route_ghost_mutation_rejected": true,
		"positive_case_count": 17,
		"forced_failure_case_count": 8,
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


static func _production_receipt(
	population: Dictionary,
	population_readback: Dictionary,
	mapped_projections: Array,
	joint_readbacks: Array,
	outer_guard: Dictionary,
	inner_target: Dictionary,
) -> Dictionary:
	var ordered_receipts: Array = []
	for index in range(mapped_projections.size()):
		var receipt: Dictionary = (mapped_projections[index] as Dictionary).duplicate(true)
		receipt["aggregate_body_application"] = true
		receipt["joint_attribution_only"] = true
		receipt["direct_joint_body_impulse_write_count"] = 0
		receipt["body_impulse_write_count"] = 0
		receipt["native_angular_velocity_readback"] = joint_readbacks[index]
		ordered_receipts.append(receipt)
	var body_receipts: Array = []
	for body_index in range(WorldScript.ORDERED_BODY_IDS.size()):
		var body_projection: Dictionary = population["ordered_body_projections"][body_index]
		var nonzero := bool(body_projection["nonzero_body_impulse"])
		(
			body_receipts
			. append(
				{
					"body_index": body_index,
					"body_id": String(body_projection["body_id"]),
					"api": "RigidBody3D.apply_torque_impulse",
					"aggregate_impulse_world_nms":
					body_projection["applied_aggregate_impulse_world_nms"],
					"call_performed": nonzero,
					"call_returned": nonzero,
					"body_impulse_write_count": int(nonzero),
					"canonical_body_order": true,
				}
			)
		)
	var body_write_count := int(population["nonzero_body_impulse_count"])
	var common_scale := float(population["common_applied_scale"])
	return {
		"schema_version":
		"sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_command_application_receipt_v1",
		"ok": true,
		"route_id": WorldScript.ROUTE_ID,
		"actuator_mapping_id":
		WorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": WorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": WorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"semantic_step": 18,
		"source_control_semantic_step": 17,
		"phase": "raise_trunk",
		"command_id": "r24d103_godot_order_neutral_population_guarded_force_based_command_step_18",
		"command_sha256": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
		"zero_command": false,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"ordered_intents": ordered_receipts.duplicate(true),
		"validated_command_count": 8,
		"host_write_count": body_write_count,
		"host_readback_count": 8,
		"body_impulse_write_count": body_write_count,
		"ordered_receipts": ordered_receipts,
		"ordered_body_application_receipts": body_receipts,
		"order_neutral_population_guard_projection": population,
		"order_neutral_population_native_angular_velocity_readback": population_readback,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_guard_limit_projection": outer_guard,
		"native_angular_velocity_guard_engagement_count":
		8 if bool(population["population_guard_engaged"]) else 0,
		"native_angular_velocity_guard_minimum_applied_scale": common_scale,
		"native_angular_velocity_initial_readback_count": 9,
		"native_angular_velocity_post_application_readback_count": 9,
		"native_angular_velocity_total_readback_count": 18,
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
		"physics_state_modified": body_write_count > 0,
	}


static func _requests(multiplier: float) -> Array:
	var result: Array = []
	for index in range(WorldScript.ORDERED_ACTUATOR_IDS.size()):
		var child_impulse := (
			Vector3.RIGHT * (float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[index]) * multiplier)
		)
		(
			result
			. append(
				{
					"actuator_index": index,
					"actuator_id": String(WorldScript.ORDERED_ACTUATOR_IDS[index]),
					"joint_id": String(WorldScript.ORDERED_JOINT_IDS[index]),
					"parent_body_id": String(WorldScript.ORDERED_PARENT_BODY_IDS[index]),
					"child_body_id": String(WorldScript.ORDERED_CHILD_BODY_IDS[index]),
					"requested_parent_impulse_world_nms": -child_impulse,
					"requested_child_impulse_world_nms": child_impulse,
				}
			)
		)
	return result


static func _force_predecessors() -> Array:
	var result: Array = []
	for index in range(WorldScript.ORDERED_ACTUATOR_IDS.size()):
		var predecessor := (
			WorldScript
			. force_based_joint_impulse_projection_v1(
				index,
				String(WorldScript.ORDERED_ACTUATOR_IDS[index]),
				String(WorldScript.ORDERED_JOINT_IDS[index]),
				String(WorldScript.ORDERED_PARENT_BODY_IDS[index]),
				String(WorldScript.ORDERED_CHILD_BODY_IDS[index]),
				17,
				true,
				Vector3.BACK,
				Vector3.RIGHT,
				1.0,
				1.0,
				-100.0,
				float(WorldScript.ORDERED_PUBLISHED_CAPS_NMS[index]),
			)
		)
		if not bool(predecessor.get("ok", false)):
			return []
		result.append(predecessor)
	return result


static func _requests_from_predecessors(predecessors: Array) -> Array:
	var result: Array = []
	for predecessor_value in predecessors:
		if not (predecessor_value is Dictionary):
			return []
		var predecessor: Dictionary = predecessor_value
		(
			result
			. append(
				{
					"actuator_index": int(predecessor["actuator_index"]),
					"actuator_id": String(predecessor["actuator_id"]),
					"joint_id": String(predecessor["joint_id"]),
					"parent_body_id": String(predecessor["parent_body_id"]),
					"child_body_id": String(predecessor["child_body_id"]),
					"requested_parent_impulse_world_nms":
					_read_vec(predecessor["parent_angular_impulse_world_nms"]),
					"requested_child_impulse_world_nms":
					_read_vec(predecessor["child_angular_impulse_world_nms"]),
				}
			)
		)
	return result


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


static func _attribution_reconstructs_bodies(projection: Dictionary) -> bool:
	var reconstructed: Dictionary = {}
	for body_id_value in WorldScript.ORDERED_BODY_IDS:
		reconstructed[String(body_id_value)] = Vector3.ZERO
	for attribution_value in projection.get("ordered_actuator_attributions", []):
		var attribution: Dictionary = attribution_value
		var parent_id := String(attribution["parent_body_id"])
		var child_id := String(attribution["child_body_id"])
		reconstructed[parent_id] = (
			(reconstructed[parent_id] as Vector3)
			+ _read_vec(attribution["attributed_applied_parent_impulse_world_nms"])
		)
		reconstructed[child_id] = (
			(reconstructed[child_id] as Vector3)
			+ _read_vec(attribution["attributed_applied_child_impulse_world_nms"])
		)
	for body_value in projection.get("ordered_body_projections", []):
		var body: Dictionary = body_value
		if (
			reconstructed.get(String(body["body_id"]), Vector3(NAN, NAN, NAN))
			!= _read_vec(body["applied_aggregate_impulse_world_nms"])
		):
			return false
	return true


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
