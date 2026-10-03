extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Production Godot/Jolt actuation bridge for prospective QSDK-R23D11.
##
## The live adapter supplies the preexisting BW13P-A planning result.  This
## bridge reads the planner's raw canonical velocity deltas, independently
## composes them with the neutral joint target through the frozen R23D11
## mirror, tapers the complete sum, and performs exactly one host mapping and
## one hinge-motor write per ordered actuator.  The adapter's already-bounded
## contribution is deliberately not applied here.

const NeutralStance := preload("res://scripts/lab/gait/sdk_godot_jolt_neutral_stance.gd")
const R10Actuation := preload("res://scripts/lab/gait/sdk_godot_jolt_quiescent_taper_actuation.gd")
const Composition := preload("res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd")

const POLICY_ID := "sporespore_support_centroid_assisted_quiescent_taper_v1"
const STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const RECEIPT_SCHEMA := "sporespore_qsdk_r23d11_godot_jolt_stability_assisted_actuation_receipt_v1"
const ACTUATOR_COUNT := 8
const SCALE_DENOMINATOR := 120
const HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE := -1.0
const TOLERANCE := 1.0e-12

var _composition_memory: Dictionary = {}
var _velocity_scale_numerator := SCALE_DENOMINATOR


func reset() -> void:
	_composition_memory = {}
	_velocity_scale_numerator = SCALE_DENOMINATOR


func set_velocity_scale(numerator: int, denominator: int) -> Dictionary:
	if numerator < 1 or numerator > SCALE_DENOMINATOR or denominator != SCALE_DENOMINATOR:
		return _failure("R23D11_GJT_TAPER_SCALE_INVALID")
	_velocity_scale_numerator = numerator
	return {
		"ok": true,
		"failure_code": "",
		"velocity_scale_numerator": numerator,
		"velocity_scale_denominator": denominator,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func compose_and_apply(
	step_result: Dictionary,
	compiled_morphology: Dictionary,
	_limbs: Array,
	_contacts_by_limb: Dictionary,
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var semantic_step := int(step_result.get("semantic_step", -1))
	var morphology: Dictionary = (
		compiled_morphology
		. get(
			"morphology",
			compiled_morphology,
		)
	)
	var actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var actuators: Array = (
		(morphology.get("morphology_spec", {}) as Dictionary)
		. get(
			"actuators",
			[],
		)
	)
	if (
		semantic_step < 0
		or actuator_ids.size() != ACTUATOR_COUNT
		or actuators.size() != ACTUATOR_COUNT
	):
		return _failure("R23D11_GJT_ACTUATION_IDENTITY_INVALID")
	var measurements_result := (
		R10Actuation
		. measurements_from_live_joints(
			compiled_morphology,
			joint_state_by_joint_id,
		)
	)
	if not bool(measurements_result.get("ok", false)):
		return measurements_result
	var measurements: Dictionary = measurements_result["measurements"]
	var neutral_velocities: Array = []
	var ordered_joint_ids: Array = []
	var maximum_position_error := 0.0
	for index in ACTUATOR_COUNT:
		var actuator_value: Variant = actuators[index]
		if typeof(actuator_value) != TYPE_DICTIONARY:
			return _failure("R23D11_GJT_ACTUATOR_TYPE_INVALID")
		var actuator: Dictionary = actuator_value
		var actuator_id := String(actuator.get("actuator_id", ""))
		var joint_id := String(actuator.get("joint_id", ""))
		if (
			actuator_id != String(actuator_ids[index])
			or joint_id.is_empty()
			or not measurements.has(joint_id)
		):
			return _failure("R23D11_GJT_ACTUATOR_ORDER_INVALID:%s" % actuator_id)
		var measurement: Dictionary = measurements[joint_id]
		var equation := (
			NeutralStance
			. bounded_neutral_velocity(
				float(measurement.get("position_rad", NAN)),
				float(measurement.get("velocity_rad_s", NAN)),
			)
		)
		if not bool(equation.get("ok", false)):
			return equation
		neutral_velocities.append(float(equation["bounded_velocity_rad_s"]))
		ordered_joint_ids.append(joint_id)
		maximum_position_error = maxf(
			maximum_position_error,
			absf(float(equation["position_error_rad"])),
		)
	var planner := planner_projection(step_result, actuator_ids)
	if not bool(planner.get("ok", false)):
		return planner
	var composed := (
		Composition
		. compose_active_step(
			semantic_step,
			actuator_ids,
			neutral_velocities,
			planner["raw_stability_velocity_deltas_rad_s"],
			String(planner["availability"]),
			_velocity_scale_numerator,
			SCALE_DENOMINATOR,
			_composition_memory,
		)
	)
	if not bool(composed.get("ok", false)):
		return composed
	var composition_receipt: Dictionary = composed["receipt"]
	var rows: Array = composition_receipt.get("ordered_actuator_composition", [])
	if rows.size() != ACTUATOR_COUNT:
		return _failure("R23D11_GJT_COMPOSITION_CARDINALITY_INVALID")
	var pending: Array[Dictionary] = []
	var maximum_speed := 0.0
	for index in ACTUATOR_COUNT:
		var row_value: Variant = rows[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			return _failure("R23D11_GJT_COMPOSITION_ROW_INVALID")
		var row: Dictionary = row_value
		var measurement: Dictionary = measurements[String(ordered_joint_ids[index])]
		var legacy_joint_id := String(measurement.get("legacy_joint_id", ""))
		var state: Dictionary = joint_state_by_joint_id.get(legacy_joint_id, {})
		var joint: HingeJoint3D = state.get("joint")
		var canonical_velocity := float(row.get("final_tapered_canonical_velocity_rad_s", NAN))
		var host_velocity := HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * canonical_velocity
		if (
			joint == null
			or String(row.get("actuator_id", "")) != String(actuator_ids[index])
			or not is_finite(canonical_velocity)
			or absf(canonical_velocity) > Composition.MAXIMUM_COMBINED_VELOCITY + TOLERANCE
		):
			return _failure("R23D11_GJT_HOST_MAPPING_INVALID:%s" % actuator_ids[index])
		(
			pending
			. append(
				{
					"actuator_id": String(actuator_ids[index]),
					"joint_id": String(ordered_joint_ids[index]),
					"legacy_joint_id": legacy_joint_id,
					"joint": joint,
					"canonical_target_velocity_rad_s": canonical_velocity,
					"host_target_velocity_rad_s": host_velocity,
				}
			)
		)
		maximum_speed = maxf(maximum_speed, absf(canonical_velocity))
	for application in pending:
		var joint: HingeJoint3D = application["joint"]
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
				float(application["host_target_velocity_rad_s"]),
			)
		)
	_composition_memory = (composed["memory"] as Dictionary).duplicate(true)
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"semantic_step": semantic_step,
		"policy_id": POLICY_ID,
		"stability_policy_id": STABILITY_POLICY_ID,
		"availability": String(planner["availability"]),
		"velocity_scale_numerator": _velocity_scale_numerator,
		"velocity_scale_denominator": SCALE_DENOMINATOR,
		"ordered_actuator_ids": actuator_ids.duplicate(),
		"ordered_joint_ids": ordered_joint_ids,
		"composition_receipt": composition_receipt.duplicate(true),
		"ordered_host_commands": _host_command_projection(pending),
		"canonical_velocity_composed_once": true,
		"complete_combined_canonical_velocity_tapered_before_host_mapping": true,
		"host_mapping_applied_once": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var validation := validate_receipt(receipt, semantic_step)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"ok": true,
		"failure_code": "",
		"semantic_step": semantic_step,
		"applied_command_count": pending.size(),
		"neutral_target_activation_count": ACTUATOR_COUNT,
		"maximum_absolute_joint_position_error_rad": maximum_position_error,
		"maximum_absolute_joint_velocity_rad_s": maximum_speed,
		"ordered_applied_stability_velocity_deltas_rad_s":
		_applied_stability_projection(composition_receipt),
		"receipt": receipt,
		"actuation_authority": true,
		"physical_acceptance_authority": false,
	}


static func planner_projection(step_result: Dictionary, actuator_ids: Array) -> Dictionary:
	var contribution: Dictionary = step_result.get("stability_contribution_shadow", {})
	var influence: Dictionary = contribution.get("influence_receipt", {})
	var availability := _normalize_availability(String(influence.get("availability", "")))
	if (
		not bool(contribution.get("ok", false))
		or String(contribution.get("stability_policy_id", "")) != STABILITY_POLICY_ID
		or int(influence.get("semantic_step", -1)) != int(step_result.get("semantic_step", -2))
		or (
			float(influence.get("global_requested_correction_scale", NAN))
			!= Composition.GLOBAL_SCALE
		)
		or not bool(influence.get("global_scale_applied_before_magnitude_and_slew", false))
		or not (
			[
				Composition.AVAILABLE,
				Composition.OBSERVATION_UNAVAILABLE,
				Composition.PLANNING_INFEASIBLE,
			]
			. has(availability)
		)
	):
		return _failure("R23D11_GJT_PLANNER_RECEIPT_INVALID")
	var corrections: Array = influence.get("ordered_applied_corrections", [])
	if corrections.size() != ACTUATOR_COUNT or actuator_ids.size() != ACTUATOR_COUNT:
		return _failure("R23D11_GJT_PLANNER_CARDINALITY_INVALID")
	var raw: Array = []
	for index in ACTUATOR_COUNT:
		var correction_value: Variant = corrections[index]
		if typeof(correction_value) != TYPE_DICTIONARY:
			return _failure("R23D11_GJT_PLANNER_CORRECTION_INVALID")
		var correction: Dictionary = correction_value
		var raw_value: Variant = correction.get("raw_requested_velocity_delta_rad_s")
		if (
			String(correction.get("actuator_id", "")) != String(actuator_ids[index])
			or (availability == Composition.AVAILABLE and not _finite_numeric(raw_value))
			or (availability != Composition.AVAILABLE and raw_value != null)
		):
			return _failure("R23D11_GJT_PLANNER_CORRECTION_INVALID:%s" % actuator_ids[index])
		raw.append(float(raw_value) if availability == Composition.AVAILABLE else null)
	return {
		"ok": true,
		"failure_code": "",
		"availability": availability,
		"raw_stability_velocity_deltas_rad_s": raw,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func validate_receipt(receipt: Dictionary, expected_semantic_step: int) -> Dictionary:
	var ids: Array = receipt.get("ordered_actuator_ids", [])
	var joints: Array = receipt.get("ordered_joint_ids", [])
	var composition_receipt: Dictionary = receipt.get("composition_receipt", {})
	var rows: Array = composition_receipt.get("ordered_actuator_composition", [])
	var host_commands: Array = receipt.get("ordered_host_commands", [])
	if (
		String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA
		or String(receipt.get("policy_id", "")) != POLICY_ID
		or String(receipt.get("stability_policy_id", "")) != STABILITY_POLICY_ID
		or int(receipt.get("semantic_step", -1)) != expected_semantic_step
		or int(composition_receipt.get("semantic_step", -1)) != expected_semantic_step
		or ids.size() != ACTUATOR_COUNT
		or joints.size() != ACTUATOR_COUNT
		or rows.size() != ACTUATOR_COUNT
		or host_commands.size() != ACTUATOR_COUNT
		or not bool(receipt.get("canonical_velocity_composed_once", false))
		or not bool(
			(
				receipt
				. get(
					"complete_combined_canonical_velocity_tapered_before_host_mapping",
					false,
				)
			)
		)
		or not bool(receipt.get("host_mapping_applied_once", false))
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("physical_acceptance_authority", true))
	):
		return _failure("R23D11_GJT_ACTUATION_RECEIPT_IDENTITY_INVALID")
	for index in ACTUATOR_COUNT:
		var row: Dictionary = rows[index]
		var host: Dictionary = host_commands[index]
		var final_velocity := float(row.get("final_tapered_canonical_velocity_rad_s", NAN))
		if (
			String(row.get("actuator_id", "")) != String(ids[index])
			or String(host.get("actuator_id", "")) != String(ids[index])
			or String(host.get("joint_id", "")) != String(joints[index])
			or not is_finite(final_velocity)
			or (
				absf(float(host.get("canonical_target_velocity_rad_s", NAN)) - final_velocity)
				> TOLERANCE
			)
			or (
				absf(
					(
						float(host.get("host_target_velocity_rad_s", NAN))
						- HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * final_velocity
					)
				)
				> TOLERANCE
			)
		):
			return _failure("R23D11_GJT_ACTUATION_RECEIPT_EQUATION:%d" % index)
	return {
		"ok": true,
		"failure_code": "",
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func run_zero_world_preflight() -> Dictionary:
	var actuator_ids: Array = []
	var joint_ids: Array = []
	var corrections: Array = []
	for index in ACTUATOR_COUNT:
		actuator_ids.append("actuator_%d" % index)
		joint_ids.append("joint_%d" % index)
		(
			corrections
			. append(
				{
					"actuator_id": "actuator_%d" % index,
					"raw_requested_velocity_delta_rad_s": 0.04,
				}
			)
		)
	var step_result := {
		"semantic_step": 10,
		"stability_contribution_shadow":
		{
			"ok": true,
			"stability_policy_id": STABILITY_POLICY_ID,
			"influence_receipt":
			{
				"semantic_step": 10,
				"availability": Composition.AVAILABLE,
				"global_requested_correction_scale": Composition.GLOBAL_SCALE,
				"global_scale_applied_before_magnitude_and_slew": true,
				"ordered_applied_corrections": corrections,
			},
		},
	}
	var planner := planner_projection(step_result, actuator_ids)
	if not bool(planner.get("ok", false)):
		return planner
	var composed := (
		Composition
		. compose_active_step(
			10,
			actuator_ids,
			_repeat_value(0.1, ACTUATOR_COUNT),
			planner["raw_stability_velocity_deltas_rad_s"],
			String(planner["availability"]),
			120,
			120,
			{},
		)
	)
	if not bool(composed.get("ok", false)):
		return composed
	var host_commands: Array = []
	var rows: Array = composed["receipt"]["ordered_actuator_composition"]
	for index in ACTUATOR_COUNT:
		var final_velocity := float(rows[index]["final_tapered_canonical_velocity_rad_s"])
		(
			host_commands
			. append(
				{
					"actuator_id": actuator_ids[index],
					"joint_id": joint_ids[index],
					"legacy_joint_id": joint_ids[index],
					"canonical_target_velocity_rad_s": final_velocity,
					"host_target_velocity_rad_s":
					HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE * final_velocity,
				}
			)
		)
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"semantic_step": 10,
		"policy_id": POLICY_ID,
		"stability_policy_id": STABILITY_POLICY_ID,
		"availability": Composition.AVAILABLE,
		"velocity_scale_numerator": 120,
		"velocity_scale_denominator": 120,
		"ordered_actuator_ids": actuator_ids,
		"ordered_joint_ids": joint_ids,
		"composition_receipt": composed["receipt"],
		"ordered_host_commands": host_commands,
		"canonical_velocity_composed_once": true,
		"complete_combined_canonical_velocity_tapered_before_host_mapping": true,
		"host_mapping_applied_once": true,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	var valid := validate_receipt(receipt, 10)
	if not bool(valid.get("ok", false)):
		return valid
	var mutation := receipt.duplicate(true)
	mutation["ordered_host_commands"][0]["host_target_velocity_rad_s"] *= -1.0
	if bool(validate_receipt(mutation, 10).get("ok", false)):
		return _failure("R23D11_GJT_HOST_SIGN_MUTATION_ACCEPTED")
	var unavailable := step_result.duplicate(true)
	unavailable["stability_contribution_shadow"]["influence_receipt"]["availability"] = (
		Composition.OBSERVATION_UNAVAILABLE
	)
	for correction in unavailable["stability_contribution_shadow"]["influence_receipt"]["ordered_applied_corrections"]:
		correction["raw_requested_velocity_delta_rad_s"] = null
	var unavailable_projection := planner_projection(unavailable, actuator_ids)
	if (
		not bool(unavailable_projection.get("ok", false))
		or not (unavailable_projection["raw_stability_velocity_deltas_rad_s"] as Array).all(
			func(value: Variant) -> bool: return value == null
		)
	):
		return _failure("R23D11_GJT_UNAVAILABLE_PROJECTION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"actuation_bridge_canary_count": 3,
		"host_mapping_mutation_control_count": 1,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


static func _repeat_value(value: Variant, count: int) -> Array:
	var result: Array = []
	for _index in count:
		result.append(value)
	return result


static func _host_command_projection(pending: Array[Dictionary]) -> Array:
	var result: Array = []
	for application in pending:
		(
			result
			. append(
				{
					"actuator_id": String(application["actuator_id"]),
					"joint_id": String(application["joint_id"]),
					"legacy_joint_id": String(application["legacy_joint_id"]),
					"canonical_target_velocity_rad_s":
					float(application["canonical_target_velocity_rad_s"]),
					"host_target_velocity_rad_s": float(application["host_target_velocity_rad_s"]),
				}
			)
		)
	return result


static func _applied_stability_projection(composition_receipt: Dictionary) -> Array:
	var result: Array = []
	for row_value in composition_receipt.get("ordered_actuator_composition", []):
		var row: Dictionary = row_value
		result.append(float(row["applied_stability_velocity_delta_rad_s"]))
	return result


static func _normalize_availability(value: String) -> String:
	return Composition.PLANNING_INFEASIBLE if value == "upstream_infeasible" else value


static func _finite_numeric(value: Variant) -> bool:
	return [TYPE_FLOAT, TYPE_INT].has(typeof(value)) and is_finite(float(value))


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"applied_command_count": 0,
		"world_build_count": 0,
		"model_construction_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
