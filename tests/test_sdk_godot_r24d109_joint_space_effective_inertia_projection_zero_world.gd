extends SceneTree
# gdlint: disable=max-line-length

## Compact R109 coupled-solve and mutation proof. No Node, RID, model, world,
## native readback, body write, or solver step is created.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const R107Test := preload(
	"res://tests/test_sdk_godot_r24d107_joint_target_monotone_population_projection_zero_world.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const RouteGhostWorker := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_R24D109_JOINT_SPACE_EFFECTIVE_INERTIA_ZERO_WORLD "


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
	var sources := R107Test._sources(Vector3.ZERO)
	var inertias := R107Test._inertias(10.0)
	var predecessors := R107Test._uniform_predecessors(1.0, 0.0)
	var positive := (
		WorldScript
		. joint_space_effective_inertia_population_guard_projection_v1(
			predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var validation := (
		WorldScript.validate_joint_space_effective_inertia_population_guard_projection_v1(
			positive
		)
	)
	var reversed_predecessors := predecessors.duplicate(true)
	reversed_predecessors.reverse()
	var reversed := (
		WorldScript
		. joint_space_effective_inertia_population_guard_projection_v1(
			reversed_predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var order_neutral := JsonTransportScript.stringify(positive) == JsonTransportScript.stringify(reversed)
	var matrix_mutation: Dictionary = positive.duplicate(true)
	var symmetric_matrix: Array = matrix_mutation["symmetric_response_matrix"]
	var first_row: Array = symmetric_matrix[0]
	first_row[0] = float(first_row[0]) + 0.001
	var matrix_mutation_validation := (
		WorldScript.validate_joint_space_effective_inertia_population_guard_projection_v1(
			matrix_mutation
		)
	)
	var duplicate_predecessors := predecessors.duplicate(true)
	duplicate_predecessors[7] = (duplicate_predecessors[0] as Dictionary).duplicate(true)
	var duplicate_refusal := (
		WorldScript
		. joint_space_effective_inertia_population_guard_projection_v1(
			duplicate_predecessors,
			sources,
			inertias,
			17,
			target,
		)
	)
	var indefinite_inertias := R107Test._inertias(10.0)
	indefinite_inertias[String(WorldScript.ORDERED_BODY_IDS[0])] = Basis(
		Vector3(-10.0, 0.0, 0.0),
		Vector3(0.0, -10.0, 0.0),
		Vector3(0.0, 0.0, 10.0),
	)
	var indefinite_refusal := (
		WorldScript
		. joint_space_effective_inertia_population_guard_projection_v1(
			predecessors,
			sources,
			indefinite_inertias,
			17,
			target,
		)
	)
	var cap_limited := (
		WorldScript
		. joint_space_effective_inertia_population_guard_projection_v1(
			predecessors,
			sources,
			R107Test._inertias(0.001),
			17,
			target,
		)
	)
	var mapped_projections: Array = []
	var mapped_valid := true
	var applied_scales_valid := true
	for actuator_index in range(predecessors.size()):
		var mapped := (
			WorldScript
			. joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
				predecessors[actuator_index],
				positive,
				actuator_index,
			)
		)
		var mapped_validation := (
			WorldScript
			. validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
				mapped,
				positive,
			)
		)
		var applied_scale := (
			WorldScript
			. joint_space_effective_inertia_population_guarded_force_based_applied_scale_projection_v1(
				mapped,
				positive,
			)
		)
		mapped_valid = (
			mapped_valid
			and bool(mapped.get("ok", false))
			and bool(mapped_validation.get("ok", false))
		)
		applied_scales_valid = (
			applied_scales_valid
			and bool(applied_scale.get("ok", false))
			and float(applied_scale.get("applied_scale", NAN))
			== float(positive.get("nominal_composed_common_scale", NAN))
		)
		mapped_projections.append(mapped)
	var mapped_mutation: Dictionary = (mapped_projections[0] as Dictionary).duplicate(true)
	mapped_mutation["solved_signed_joint_impulse_nms"] = (
		float(mapped_mutation["solved_signed_joint_impulse_nms"]) + 0.001
	)
	var mapped_mutation_validation := (
		WorldScript
		. validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
			mapped_mutation,
			positive,
		)
	)
	var body_guard: Dictionary = positive["body_guard_population_projection"]
	var predicted_post_by_body_id: Dictionary = {}
	for body_value in body_guard["ordered_body_projections"]:
		var body: Dictionary = body_value
		predicted_post_by_body_id[String(body["body_id"])] = R107Test._read_vec(
			body["predicted_angular_velocity_world_rad_s"]
		)
	var population_readback := (
		WorldScript
		. order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			body_guard,
			predicted_post_by_body_id,
		)
	)
	var population_readback_validation := (
		WorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			body_guard,
			population_readback,
		)
	)
	var joint_readbacks: Array = []
	var joint_readbacks_valid := true
	var work_projections_valid := true
	for actuator_index in range(mapped_projections.size()):
		var mapped: Dictionary = mapped_projections[actuator_index]
		var joint_readback := (
			WorldScript
			. joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				positive,
				population_readback,
			)
		)
		var joint_readback_validation := (
			WorldScript
			. validate_joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
				mapped,
				positive,
				population_readback,
				joint_readback,
			)
		)
		var joint_projection: Dictionary = positive["ordered_joint_solve_projections"][
			actuator_index
		]
		var work_projection := (
			WorldScript
			. joint_space_effective_inertia_population_guarded_force_based_joint_work_projection_v1(
				mapped,
				positive,
				18,
				true,
				Vector3.BACK,
				float(joint_projection["predicted_relative_velocity_rad_s"]),
			)
		)
		joint_readbacks_valid = (
			joint_readbacks_valid
			and bool(joint_readback.get("ok", false))
			and bool(joint_readback_validation.get("ok", false))
		)
		work_projections_valid = work_projections_valid and bool(work_projection.get("ok", false))
		joint_readbacks.append(joint_readback)
	var production_receipt := _production_application_receipt(
		positive,
		mapped_projections,
		population_readback,
		joint_readbacks,
		outer,
		target,
	)
	var production_receipt_valid := BehaviorWorker.behavior_application_receipt_valid_v2(
		BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
		production_receipt,
		false,
	)
	var route_ghost_receipt_valid := (
		RouteGhostWorker
		. validate_joint_space_effective_inertia_population_route_application_v1(
			production_receipt
		)
	)
	var production_mode_mappings_valid := (
		BehaviorWorker.actuator_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
		)
		== WorldScript.JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		and BehaviorWorker.work_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
		)
		== WorldScript.JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	)
	var production_mutation: Dictionary = production_receipt.duplicate(true)
	production_mutation["representation_refinement_count"] = (
		int(production_mutation["representation_refinement_count"]) + 1
	)
	var production_mutation_rejected := not BehaviorWorker.behavior_application_receipt_valid_v2(
		BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
		production_mutation,
		false,
	)
	var legacy_regression := R107Test._run()
	if (
		not bool(positive.get("ok", false))
		or not bool(validation.get("ok", false))
		or not order_neutral
		or not bool(positive.get("all_joint_target_errors_nonincreasing", false))
		or int(positive.get("joint_target_crossing_count", -1)) != 0
		or float(positive.get("minimum_cholesky_pivot", NAN)) <= 0.0
		or float(positive.get("maximum_solve_residual_rad_s", INF)) > 1.0e-12
		or bool(matrix_mutation_validation.get("ok", true))
		or bool(duplicate_refusal.get("ok", true))
		or bool(indefinite_refusal.get("ok", true))
		or not bool(cap_limited.get("ok", false))
		or float(cap_limited.get("cap_common_scale", NAN)) >= 1.0
		or not mapped_valid
		or not applied_scales_valid
		or bool(mapped_mutation_validation.get("ok", true))
		or not bool(population_readback.get("ok", false))
		or not bool(population_readback_validation.get("ok", false))
		or not joint_readbacks_valid
		or not work_projections_valid
		or not production_receipt_valid
		or not route_ghost_receipt_valid
		or not production_mode_mappings_valid
		or not production_mutation_rejected
		or not bool(legacy_regression.get("ok", false))
	):
		return {
			"ok": false,
			"failure_code": "R109_COUPLED_SOLVE_FAILED",
			"positive": positive,
			"validation": validation,
			"reversed": reversed,
			"order_neutral": order_neutral,
			"matrix_mutation_validation": matrix_mutation_validation,
			"duplicate_refusal": duplicate_refusal,
			"indefinite_refusal": indefinite_refusal,
			"cap_limited": cap_limited,
			"mapped_valid": mapped_valid,
			"applied_scales_valid": applied_scales_valid,
			"mapped_mutation_validation": mapped_mutation_validation,
			"population_readback": population_readback,
			"population_readback_validation": population_readback_validation,
			"joint_readbacks_valid": joint_readbacks_valid,
			"work_projections_valid": work_projections_valid,
			"production_receipt": production_receipt,
			"production_receipt_valid": production_receipt_valid,
			"route_ghost_receipt_valid": route_ghost_receipt_valid,
			"production_mode_mappings_valid": production_mode_mappings_valid,
			"production_mutation_rejected": production_mutation_rejected,
			"legacy_regression": legacy_regression,
		}
	return {
		"schema_version":
		"sporespore_qsdk_r24d109_joint_space_effective_inertia_zero_world_v1",
		"gate_id": "QSDK-R24D109",
		"ok": true,
		"question_class": "development",
		"positive_case_count": 2,
		"forced_failure_case_count": 5,
		"minimum_cholesky_pivot": float(positive["minimum_cholesky_pivot"]),
		"maximum_solve_residual_rad_s": float(positive["maximum_solve_residual_rad_s"]),
		"cap_limited_common_scale": float(cap_limited["cap_common_scale"]),
		"representation_refinement_count": int(positive["representation_refinement_count"]),
		"input_order_neutral": true,
		"projection_mutation_rejected": true,
		"duplicate_identity_rejected": true,
		"nonpositive_cholesky_pivot_rejected": true,
		"joint_mapping_and_validation_passed": true,
		"applied_scale_projection_passed": true,
		"population_and_joint_readback_passed": true,
		"centered_work_projection_passed": true,
		"production_application_receipt_passed": true,
		"route_ghost_receipt_validation_passed": true,
		"production_mode_mapping_passed": true,
		"production_receipt_mutation_rejected": true,
		"r107_regression_passed": true,
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
				"aggregate_impulse_world_nms":
				body_projection["applied_aggregate_impulse_world_nms"],
			}
		)
	var population_guard_engaged := (
		bool(population["solver_guard_engaged"])
		or bool(body_guard["population_guard_engaged"])
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1",
		"ok": true,
		"actuator_mapping_id":
		WorldScript.JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id":
		WorldScript.JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"predecessor_actuator_mapping_id": WorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"semantic_step": 18,
		"source_control_semantic_step": 17,
		"phase": "recover",
		"command_id":
		"r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_step_18",
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
		"native_angular_velocity_guard_minimum_applied_scale":
		float(population["nominal_composed_common_scale"]),
		"native_angular_velocity_initial_readback_count": WorldScript.ORDERED_BODY_IDS.size(),
		"native_angular_velocity_post_application_readback_count":
		WorldScript.ORDERED_BODY_IDS.size(),
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
		"joint_space_effective_inertia_population_guard_projection": population,
		"joint_space_effective_inertia_population_projection_required": true,
		"joint_space_effective_inertia_common_pre_scale":
		float(population["joint_space_common_pre_scale"]),
		"body_guard_common_applied_scale":
		float(population["body_guard_common_applied_scale"]),
		"representation_refinement_count": int(population["representation_refinement_count"]),
		"all_joint_target_errors_nonincreasing": true,
		"joint_target_crossing_count": 0,
	}


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
