extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Independent Godot/Jolt GDScript composition mirror for QSDK-R23D11.
##
## No node, PhysicsServer object, body, collider, model, or world is created.
## The frozen R23D10 temporal mirror is invoked only as a zero-world canary.

const R10Temporal := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd"
)

const CAMPAIGN_ID := (
	"QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-"
	+ "BILATERAL-TURN-DEVELOPMENT"
)
const GATE_ID := "QSDK-R23D11"
const ACTUATOR_COUNT := 8
const AVAILABLE := "available"
const OBSERVATION_UNAVAILABLE := "observation_unavailable"
const PLANNING_INFEASIBLE := "planning_infeasible"
const GLOBAL_SCALE := 0.5
const MAXIMUM_STABILITY_DELTA := 0.075
const MAXIMUM_STABILITY_SLEW := 0.010
const MAXIMUM_NEUTRAL_VELOCITY := 0.35
const MAXIMUM_COMBINED_VELOCITY := 0.425
const TAPER_DENOMINATOR := 120
const TOLERANCE := 1.0e-12


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}


static func _finite_numeric(value: Variant) -> bool:
	return (
		[TYPE_FLOAT, TYPE_INT].has(typeof(value))
		and is_finite(float(value))
	)


static func _ids_valid(actuator_ids: Array) -> bool:
	if actuator_ids.size() != ACTUATOR_COUNT:
		return false
	var seen := {}
	for value in actuator_ids:
		if typeof(value) != TYPE_STRING or String(value).is_empty() or seen.has(value):
			return false
		seen[value] = true
	return true


static func _previous(
	memory: Dictionary,
	semantic_step: int,
	actuator_ids: Array,
) -> Dictionary:
	var previous_step: Variant = memory.get("previous_semantic_step")
	var previous_ids: Variant = memory.get("ordered_actuator_ids")
	var previous_values: Variant = memory.get("previous_applied_velocity_deltas")
	if previous_step == null and previous_ids == null and previous_values == null:
		return {"ok": true, "values": _repeat_value(0.0, ACTUATOR_COUNT)}
	if previous_step == null or previous_ids == null or previous_values == null:
		return _failure("R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE")
	if typeof(previous_step) != TYPE_INT or int(previous_step) >= semantic_step:
		return _failure("R23D11_PREVIOUS_STEP_NOT_PREVIOUS")
	if typeof(previous_ids) != TYPE_ARRAY or previous_ids != actuator_ids:
		return _failure("R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID")
	if typeof(previous_values) != TYPE_ARRAY or (previous_values as Array).size() != ACTUATOR_COUNT:
		return _failure("R23D11_PREVIOUS_CORRECTION_INVALID")
	for value in previous_values as Array:
		if not _finite_numeric(value):
			return _failure("R23D11_PREVIOUS_CORRECTION_INVALID")
	return {"ok": true, "values": (previous_values as Array).duplicate()}


static func compose_active_step(
	semantic_step: int,
	actuator_ids: Array,
	neutral_velocities: Array,
	raw_stability_deltas: Array,
	availability: String,
	taper_numerator: int,
	taper_denominator: int,
	memory: Dictionary = {},
) -> Dictionary:
	if semantic_step < 0:
		return _failure("R23D11_SEMANTIC_STEP_INVALID")
	if not _ids_valid(actuator_ids):
		return _failure("R23D11_ACTUATOR_ORDER_INVALID")
	if neutral_velocities.size() != ACTUATOR_COUNT:
		return _failure("R23D11_NEUTRAL_VELOCITY_INVALID")
	for value in neutral_velocities:
		if not _finite_numeric(value):
			return _failure("R23D11_NEUTRAL_VELOCITY_INVALID")
		if absf(float(value)) > MAXIMUM_NEUTRAL_VELOCITY:
			return _failure("R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND")
	if not [AVAILABLE, OBSERVATION_UNAVAILABLE, PLANNING_INFEASIBLE].has(availability):
		return _failure("R23D11_AVAILABILITY_INVALID")
	if raw_stability_deltas.size() != ACTUATOR_COUNT:
		return _failure("R23D11_STABILITY_CORRECTION_COUNT_INVALID")
	var available := availability == AVAILABLE
	for value in raw_stability_deltas:
		if available and not _finite_numeric(value):
			return _failure("R23D11_AVAILABLE_CORRECTION_INVALID")
		if not available and value != null:
			return _failure("R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE")
	if (
		taper_numerator < 1
		or taper_numerator > TAPER_DENOMINATOR
		or taper_denominator != TAPER_DENOMINATOR
	):
		return _failure("R23D11_TAPER_FRACTION_INVALID")
	var previous := _previous(memory, semantic_step, actuator_ids)
	if not bool(previous.get("ok", false)):
		return previous
	var previous_values: Array = previous["values"]
	var taper_scale := float(taper_numerator) / float(taper_denominator)
	var applied_values: Array = []
	var rows: Array = []
	for index in ACTUATOR_COUNT:
		var raw_value := 0.0 if not available else float(raw_stability_deltas[index])
		var applied := 0.0
		var scaled: Variant = null
		var magnitude := 0.0
		if available:
			scaled = raw_value * GLOBAL_SCALE
			magnitude = clampf(
				float(scaled), -MAXIMUM_STABILITY_DELTA, MAXIMUM_STABILITY_DELTA
			)
			applied = clampf(
				magnitude,
				float(previous_values[index]) - MAXIMUM_STABILITY_SLEW,
				float(previous_values[index]) + MAXIMUM_STABILITY_SLEW,
			)
		var combined := float(neutral_velocities[index]) + applied
		if absf(combined) > MAXIMUM_COMBINED_VELOCITY + TOLERANCE:
			return _failure("R23D11_COMBINED_VELOCITY_OUTSIDE_DERIVED_BOUND")
		applied_values.append(applied)
		rows.append({
			"actuator_id": String(actuator_ids[index]),
			"neutral_velocity_rad_s": float(neutral_velocities[index]),
			"raw_stability_velocity_delta_rad_s": raw_value if available else null,
			"scaled_stability_velocity_delta_rad_s": scaled,
			"magnitude_bounded_stability_velocity_delta_rad_s": magnitude,
			"applied_stability_velocity_delta_rad_s": applied,
			"combined_pre_taper_velocity_rad_s": combined,
			"final_tapered_canonical_velocity_rad_s": combined * taper_scale,
			"fallback_zeroed": not available,
		})
	return {
		"ok": true,
		"failure_code": "",
		"memory": {
			"previous_semantic_step": semantic_step,
			"ordered_actuator_ids": actuator_ids.duplicate(),
			"previous_applied_velocity_deltas": applied_values,
		},
		"receipt": {
			"schema_version": "sporespore_qsdk_r23d11_godot_jolt_composition_receipt_v1",
			"semantic_step": semantic_step,
			"availability": availability,
			"ordered_actuator_composition": rows,
			"fallback_applied": not available,
			"host_mapping_applied": false,
			"model_construction_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		},
	}


static func compose_passive_step(actuator_ids: Array) -> Dictionary:
	if not _ids_valid(actuator_ids):
		return _failure("R23D11_ACTUATOR_ORDER_INVALID")
	var commands: Array = []
	for actuator_id in actuator_ids:
		commands.append({
			"actuator_id": String(actuator_id),
			"canonical_velocity_rad_s": 0.0,
		})
	return {
		"ok": true,
		"ordered_actuator_commands": commands,
		"neutral_composition_invoked": false,
		"stability_composition_invoked": false,
		"native_actuation_application_count": 0,
		"physical_acceptance_authority": false,
	}


static func _repeat_value(value: Variant, count: int) -> Array:
	var result: Array = []
	for _index in count:
		result.append(value)
	return result


static func _ids() -> Array:
	var result: Array = []
	for index in ACTUATOR_COUNT:
		result.append("actuator_%d" % index)
	return result


static func _call(changes: Dictionary = {}) -> Dictionary:
	var values := {
		"semantic_step": 0,
		"actuator_ids": _ids(),
		"neutral_velocities": _repeat_value(0.1, ACTUATOR_COUNT),
		"raw_stability_deltas": _repeat_value(1.0, ACTUATOR_COUNT),
		"availability": AVAILABLE,
		"taper_numerator": 120,
		"taper_denominator": 120,
		"memory": {},
	}
	for key_value in changes:
		values[key_value] = changes[key_value]
	return compose_active_step(
		int(values["semantic_step"]),
		values["actuator_ids"] as Array,
		values["neutral_velocities"] as Array,
		values["raw_stability_deltas"] as Array,
		String(values["availability"]),
		int(values["taper_numerator"]),
		int(values["taper_denominator"]),
		values["memory"] as Dictionary,
	)


static func _failed(result: Dictionary, code: String) -> bool:
	return not bool(result.get("ok", false)) and String(result.get("failure_code", "")) == code


static func run_zero_world_preflight() -> Dictionary:
	var first := _call()
	if not bool(first.get("ok", false)):
		return first
	var second := _call({"semantic_step": 1, "memory": first["memory"]})
	var fallback := _call({
		"semantic_step": 2,
		"memory": second.get("memory", {}),
		"availability": OBSERVATION_UNAVAILABLE,
		"raw_stability_deltas": _repeat_value(null, ACTUATOR_COUNT),
	})
	var half := _call({
		"raw_stability_deltas": _repeat_value(0.02, ACTUATOR_COUNT),
		"taper_numerator": 60,
	})
	var mirrored := _call({
		"neutral_velocities": _repeat_value(-0.1, ACTUATOR_COUNT),
		"raw_stability_deltas": _repeat_value(-1.0, ACTUATOR_COUNT),
	})
	var passive := compose_passive_step(_ids())
	var temporal := R10Temporal.run_zero_world_preflight()
	for result in [second, fallback, half, mirrored, passive, temporal]:
		if not bool((result as Dictionary).get("ok", false)):
			return _failure("R23D11_GJT_CANARY_INPUT_FAILED")
	var first_rows: Array = (first["receipt"] as Dictionary)["ordered_actuator_composition"]
	var second_rows: Array = (second["receipt"] as Dictionary)["ordered_actuator_composition"]
	var fallback_rows: Array = (fallback["receipt"] as Dictionary)["ordered_actuator_composition"]
	var half_rows: Array = (half["receipt"] as Dictionary)["ordered_actuator_composition"]
	var mirrored_rows: Array = (mirrored["receipt"] as Dictionary)["ordered_actuator_composition"]
	for index in ACTUATOR_COUNT:
		if float((first_rows[index] as Dictionary)["applied_stability_velocity_delta_rad_s"]) != 0.01:
			return _failure("R23D11_GJT_CANARY_FIRST")
		if float((second_rows[index] as Dictionary)["applied_stability_velocity_delta_rad_s"]) != 0.02:
			return _failure("R23D11_GJT_CANARY_MEMORY")
		if not bool((fallback_rows[index] as Dictionary)["fallback_zeroed"]):
			return _failure("R23D11_GJT_CANARY_FALLBACK")
		if absf(
			float((half_rows[index] as Dictionary)["final_tapered_canonical_velocity_rad_s"])
			- float((half_rows[index] as Dictionary)["combined_pre_taper_velocity_rad_s"]) * 0.5
		) > TOLERANCE:
			return _failure("R23D11_GJT_CANARY_TAPER_ORDER")
		if absf(
			float((first_rows[index] as Dictionary)["final_tapered_canonical_velocity_rad_s"])
			+ float((mirrored_rows[index] as Dictionary)["final_tapered_canonical_velocity_rad_s"])
		) > TOLERANCE:
			return _failure("R23D11_GJT_CANARY_MIRROR")
	if int(passive["native_actuation_application_count"]) != 0:
		return _failure("R23D11_GJT_CANARY_PASSIVE")
	if (
		int(temporal.get("oracle_canary_count", -1)) != 5
		or int(temporal.get("mutation_control_count", -1)) != 16
		or int(temporal.get("world_build_count", -1)) != 0
	):
		return _failure("R23D11_GJT_CANARY_TEMPORAL")

	var actuator_ids := _ids()
	var reverse_ids := actuator_ids.duplicate()
	reverse_ids.reverse()
	var short_ids := actuator_ids.duplicate()
	short_ids.pop_back()
	var duplicate_ids := actuator_ids.duplicate()
	duplicate_ids[7] = duplicate_ids[0]
	var nan_neutral := _repeat_value(0.1, 8)
	nan_neutral[0] = NAN
	var out_of_bound := _repeat_value(0.1, 8)
	out_of_bound[0] = 0.351
	var infinite_raw := _repeat_value(1.0, 8)
	infinite_raw[0] = INF
	var nan_previous := _repeat_value(0.0, 8)
	nan_previous[0] = NAN
	var controls := [
		[_call({"actuator_ids": short_ids}), "R23D11_ACTUATOR_ORDER_INVALID"],
		[_call({"actuator_ids": duplicate_ids}), "R23D11_ACTUATOR_ORDER_INVALID"],
		[_call({"neutral_velocities": _repeat_value(0.1, 7)}), "R23D11_NEUTRAL_VELOCITY_INVALID"],
		[_call({"neutral_velocities": nan_neutral}), "R23D11_NEUTRAL_VELOCITY_INVALID"],
		[_call({"neutral_velocities": out_of_bound}), "R23D11_NEUTRAL_VELOCITY_OUTSIDE_BOUND"],
		[_call({"raw_stability_deltas": _repeat_value(1.0, 7)}), "R23D11_STABILITY_CORRECTION_COUNT_INVALID"],
		[_call({"raw_stability_deltas": infinite_raw}), "R23D11_AVAILABLE_CORRECTION_INVALID"],
		[_call({"availability": OBSERVATION_UNAVAILABLE}), "R23D11_UNAVAILABLE_CORRECTION_HAS_VALUE"],
		[_call({"availability": "arm_specific"}), "R23D11_AVAILABILITY_INVALID"],
		[_call({"semantic_step": -1}), "R23D11_SEMANTIC_STEP_INVALID"],
		[_call({"taper_numerator": 0}), "R23D11_TAPER_FRACTION_INVALID"],
		[_call({"taper_numerator": 121}), "R23D11_TAPER_FRACTION_INVALID"],
		[_call({"taper_denominator": 119}), "R23D11_TAPER_FRACTION_INVALID"],
		[_call({"semantic_step": 1, "memory": {"previous_semantic_step": 0}}), "R23D11_PREVIOUS_MEMORY_PAIR_INCOMPLETE"],
		[_call({"memory": {"previous_semantic_step": 0, "ordered_actuator_ids": actuator_ids, "previous_applied_velocity_deltas": _repeat_value(0.0, 8)}}), "R23D11_PREVIOUS_STEP_NOT_PREVIOUS"],
		[_call({"semantic_step": 1, "memory": {"previous_semantic_step": 0, "ordered_actuator_ids": reverse_ids, "previous_applied_velocity_deltas": _repeat_value(0.0, 8)}}), "R23D11_PREVIOUS_ACTUATOR_ORDER_INVALID"],
		[_call({"semantic_step": 1, "memory": {"previous_semantic_step": 0, "ordered_actuator_ids": actuator_ids, "previous_applied_velocity_deltas": _repeat_value(0.0, 7)}}), "R23D11_PREVIOUS_CORRECTION_INVALID"],
		[_call({"semantic_step": 1, "memory": {"previous_semantic_step": 0, "ordered_actuator_ids": actuator_ids, "previous_applied_velocity_deltas": nan_previous}}), "R23D11_PREVIOUS_CORRECTION_INVALID"],
	]
	for control in controls:
		if not _failed(control[0] as Dictionary, String(control[1])):
			return _failure("R23D11_GJT_MUTATION_FAILED_%s" % String(control[1]))
	return {
		"ok": true,
		"failure_code": "",
		"composition_canary_count": 7,
		"mutation_control_count": controls.size(),
		"inherited_temporal_canary_count": 5,
		"native_composition_mirror": true,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
	}


static func preflight(stage_id: String, arm_id: String) -> Dictionary:
	if (
		stage_id != "three_engine_confirmation"
		or not ["reference_zero", "positive_heading", "negative_heading"].has(arm_id)
	):
		return _failure("R23D11_GJT_CELL_IDENTITY_INVALID")
	var result := run_zero_world_preflight()
	if not bool(result.get("ok", false)):
		return result
	result["schema_version"] = "sporespore_qsdk_r23d11_godot_jolt_composition_preflight_v1"
	result["campaign_id"] = CAMPAIGN_ID
	result["gate_id"] = GATE_ID
	result["engine_id"] = "godot_jolt"
	result["stage_id"] = stage_id
	result["arm_id"] = arm_id
	result["physical_worker_implemented"] = false
	return result
