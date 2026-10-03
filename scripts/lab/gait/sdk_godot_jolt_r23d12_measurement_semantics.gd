extends RefCounted

## Independent Godot/Jolt GDScript diagnostic-semantics mirror for R23D12.
## This source contains no world, controller, selector, or outcome logic and
## does not preload the Python stage-zero reference oracle.

const GATE_ID := "QSDK-R23D12"
const CAMPAIGN_ID := (
	"QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-" +
	"BILATERAL-TURN-DEVELOPMENT"
)
const ENGINE_ID := "godot_jolt"

const ACTIVE_CONTROL := "active_control"
const PASSIVE_OBSERVATION := "passive_observation"
const PLANNER_AVAILABLE := "available"
const PLANNER_OBSERVATION_UNAVAILABLE := "observation_unavailable"
const PLANNER_INFEASIBLE := "planning_infeasible"
const PLANNER_VALUES := [
	PLANNER_AVAILABLE,
	PLANNER_OBSERVATION_UNAVAILABLE,
	PLANNER_INFEASIBLE,
]
const MARGIN_MEASURED := "measured"
const MARGIN_UNAVAILABLE := "measurement_unavailable"
const MARGIN_VALUES := [MARGIN_MEASURED, MARGIN_UNAVAILABLE]
const ACTUATOR_COUNT := 8

const EXPECTED_MUTATION_CODES := [
	"R23D12_PHASE_CLASS_INVALID",
	"R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
	"R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID",
	"R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL",
	"R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID",
	"R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
	"R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
	"R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE",
	"R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE",
	"R23D12_STABILITY_DELTA_VECTOR_INVALID",
	"R23D12_STABILITY_DELTA_VECTOR_INVALID",
	"R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
	"R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
	"R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO",
]


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}


static func _finite_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return (
		(value_type == TYPE_INT or value_type == TYPE_FLOAT) and
		is_finite(float(value))
	)


static func validate_diagnostic_semantics(value: Dictionary) -> Dictionary:
	var phase_class := String(value.get("phase_class", ""))
	if not [ACTIVE_CONTROL, PASSIVE_OBSERVATION].has(phase_class):
		return _failure("R23D12_PHASE_CLASS_INVALID")

	var planner: Variant = value.get("stability_planning_availability", null)
	if phase_class == ACTIVE_CONTROL:
		if not PLANNER_VALUES.has(planner):
			return _failure("R23D12_ACTIVE_PLANNER_AVAILABILITY_INVALID")
	elif planner != null:
		return _failure("R23D12_PASSIVE_PLANNER_AVAILABILITY_MUST_BE_NULL")

	var margin_availability := String(
		value.get("minimum_dynamic_support_margin_availability", "")
	)
	if not MARGIN_VALUES.has(margin_availability):
		return _failure("R23D12_SUPPORT_MARGIN_AVAILABILITY_INVALID")

	var margin: Variant = value.get("minimum_dynamic_support_margin_m", null)
	var normalized_margin: Variant = null
	if margin_availability == MARGIN_MEASURED:
		if not _finite_number(margin):
			return _failure("R23D12_MEASURED_SUPPORT_MARGIN_NOT_FINITE")
		normalized_margin = float(margin)
	elif margin != null:
		return _failure("R23D12_UNAVAILABLE_SUPPORT_MARGIN_HAS_VALUE")

	var raw_deltas: Variant = value.get(
		"ordered_applied_stability_velocity_deltas_rad_s", null
	)
	if typeof(raw_deltas) != TYPE_ARRAY or raw_deltas.size() != ACTUATOR_COUNT:
		return _failure("R23D12_STABILITY_DELTA_VECTOR_INVALID")
	var deltas: Array[float] = []
	for item: Variant in raw_deltas:
		if not _finite_number(item):
			return _failure("R23D12_STABILITY_DELTA_VECTOR_INVALID")
		deltas.append(float(item))

	var exact_zero_required: bool = (
		phase_class == PASSIVE_OBSERVATION or planner != PLANNER_AVAILABLE
	)
	if exact_zero_required:
		for item in deltas:
			if item != 0.0:
				return _failure("R23D12_REQUIRED_STABILITY_FALLBACK_NOT_EXACT_ZERO")

	return {
		"ok": true,
		"phase_class": phase_class,
		"stability_planning_availability": planner,
		"minimum_dynamic_support_margin_availability": margin_availability,
		"minimum_dynamic_support_margin_m": normalized_margin,
		"ordered_applied_stability_velocity_deltas_rad_s": deltas,
		"stability_fallback_exact_zero_required": exact_zero_required,
	}


static func _zeros() -> Array:
	var values: Array = []
	values.resize(ACTUATOR_COUNT)
	values.fill(0.0)
	return values


static func _small() -> Array:
	var values: Array = []
	values.resize(ACTUATOR_COUNT)
	values.fill(0.01)
	return values


static func _row(
	phase_class: String,
	planner: Variant,
	margin_availability: String,
	margin: Variant,
	deltas: Array
) -> Dictionary:
	return {
		"phase_class": phase_class,
		"stability_planning_availability": planner,
		"minimum_dynamic_support_margin_availability": margin_availability,
		"minimum_dynamic_support_margin_m": margin,
		"ordered_applied_stability_velocity_deltas_rad_s": deltas.duplicate(),
	}


static func _valid_canaries() -> Array:
	var zeros := _zeros()
	var small := _small()
	return [
		_row(ACTIVE_CONTROL, PLANNER_AVAILABLE, MARGIN_MEASURED, 0.05, small),
		_row(ACTIVE_CONTROL, PLANNER_AVAILABLE, MARGIN_UNAVAILABLE, null, small),
		_row(
			ACTIVE_CONTROL,
			PLANNER_OBSERVATION_UNAVAILABLE,
			MARGIN_MEASURED,
			-0.01,
			zeros
		),
		_row(
			ACTIVE_CONTROL,
			PLANNER_OBSERVATION_UNAVAILABLE,
			MARGIN_UNAVAILABLE,
			null,
			zeros
		),
		_row(ACTIVE_CONTROL, PLANNER_INFEASIBLE, MARGIN_MEASURED, 0.0, zeros),
		_row(PASSIVE_OBSERVATION, null, MARGIN_MEASURED, 0.02, zeros),
		_row(PASSIVE_OBSERVATION, null, MARGIN_UNAVAILABLE, null, zeros),
	]


static func _cross_product_inputs() -> Array:
	var rows: Array = []
	for planner in PLANNER_VALUES:
		for margin_pair in [
			[MARGIN_MEASURED, 0.03],
			[MARGIN_UNAVAILABLE, null],
		]:
			rows.append(_row(
				ACTIVE_CONTROL,
				planner,
				String(margin_pair[0]),
				margin_pair[1],
				_small() if planner == PLANNER_AVAILABLE else _zeros()
			))
	return rows


static func _mutations() -> Array:
	var baseline: Dictionary = _valid_canaries()[0]
	var rows: Array = []
	var row := baseline.duplicate(true)
	row["phase_class"] = "terminal"
	rows.append(row)
	row = baseline.duplicate(true)
	row["stability_planning_availability"] = null
	rows.append(row)
	row = baseline.duplicate(true)
	row["stability_planning_availability"] = "arm_specific"
	rows.append(row)
	row = baseline.duplicate(true)
	row["phase_class"] = PASSIVE_OBSERVATION
	row["stability_planning_availability"] = PLANNER_AVAILABLE
	rows.append(row)
	row = baseline.duplicate(true)
	row["minimum_dynamic_support_margin_availability"] = "estimated"
	rows.append(row)
	row = baseline.duplicate(true)
	row["minimum_dynamic_support_margin_m"] = null
	rows.append(row)
	row = baseline.duplicate(true)
	row["minimum_dynamic_support_margin_m"] = true
	rows.append(row)
	row = baseline.duplicate(true)
	row["minimum_dynamic_support_margin_m"] = NAN
	rows.append(row)
	row = baseline.duplicate(true)
	row["minimum_dynamic_support_margin_availability"] = MARGIN_UNAVAILABLE
	row["minimum_dynamic_support_margin_m"] = 0.01
	rows.append(row)
	row = baseline.duplicate(true)
	row["ordered_applied_stability_velocity_deltas_rad_s"] = _zeros().slice(0, 7)
	rows.append(row)
	row = baseline.duplicate(true)
	var invalid_deltas := _zeros()
	invalid_deltas[7] = INF
	row["ordered_applied_stability_velocity_deltas_rad_s"] = invalid_deltas
	rows.append(row)
	row = baseline.duplicate(true)
	row["stability_planning_availability"] = PLANNER_OBSERVATION_UNAVAILABLE
	rows.append(row)
	row = baseline.duplicate(true)
	row["stability_planning_availability"] = PLANNER_INFEASIBLE
	rows.append(row)
	row = baseline.duplicate(true)
	row["phase_class"] = PASSIVE_OBSERVATION
	row["stability_planning_availability"] = null
	rows.append(row)
	return rows


static func _receipt_vector(receipt: Dictionary) -> String:
	var planner: Variant = receipt["stability_planning_availability"]
	var planner_text := "null" if planner == null else String(planner)
	var margin: Variant = receipt["minimum_dynamic_support_margin_m"]
	var margin_text := "null" if margin == null else "%.6f" % float(margin)
	var delta_parts := PackedStringArray()
	for item in receipt["ordered_applied_stability_velocity_deltas_rad_s"]:
		delta_parts.append("%.6f" % float(item))
	var zero_text := (
		"true" if bool(receipt["stability_fallback_exact_zero_required"]) else "false"
	)
	return "%s|%s|%s|%s|%s|%s" % [
		String(receipt["phase_class"]),
		planner_text,
		String(receipt["minimum_dynamic_support_margin_availability"]),
		margin_text,
		",".join(delta_parts),
		zero_text,
	]


static func preflight() -> Dictionary:
	var valid_receipts: Array = []
	for row in _valid_canaries():
		var receipt := validate_diagnostic_semantics(row)
		if not bool(receipt.get("ok", false)):
			return _failure(String(receipt.get("failure_code", "R23D12_VALID_CANARY_FAILED")))
		valid_receipts.append(receipt)

	var cross_receipts: Array = []
	for row in _cross_product_inputs():
		var receipt := validate_diagnostic_semantics(row)
		if not bool(receipt.get("ok", false)):
			return _failure(String(receipt.get("failure_code", "R23D12_CROSS_PRODUCT_FAILED")))
		cross_receipts.append(receipt)

	var mutation_codes: Array[String] = []
	for row in _mutations():
		var receipt := validate_diagnostic_semantics(row)
		if bool(receipt.get("ok", false)):
			return _failure("R23D12_MUTATION_UNEXPECTEDLY_ACCEPTED")
		mutation_codes.append(String(receipt.get("failure_code", "")))
	if mutation_codes != EXPECTED_MUTATION_CODES:
		return _failure("R23D12_MUTATION_FAILURE_CODES_CHANGED")

	var critical: Dictionary = valid_receipts[2]
	var critical_passed: bool = (
		critical["stability_planning_availability"] == PLANNER_OBSERVATION_UNAVAILABLE and
		critical["minimum_dynamic_support_margin_availability"] == MARGIN_MEASURED and
		float(critical["minimum_dynamic_support_margin_m"]) == -0.01 and
		bool(critical["stability_fallback_exact_zero_required"])
	)
	if not critical_passed:
		return _failure("R23D12_CRITICAL_FAILURE_SHAPE_NOT_ACCEPTED")

	var valid_vectors := PackedStringArray()
	for receipt in valid_receipts:
		valid_vectors.append(_receipt_vector(receipt))
	var cross_vectors := PackedStringArray()
	for receipt in cross_receipts:
		cross_vectors.append(_receipt_vector(receipt))
	return {
		"ok": true,
		"schema_version": "sporespore_qsdk_r23d12_native_semantics_preflight_v1",
		"gate_id": GATE_ID,
		"campaign_id": CAMPAIGN_ID,
		"engine_id": ENGINE_ID,
		"language": "gdscript",
		"valid_canary_count": valid_receipts.size(),
		"active_cross_product_count": cross_receipts.size(),
		"mutation_control_count": mutation_codes.size(),
		"critical_r23d11_failure_shape_passed": critical_passed,
		"valid_canary_vector": "\n".join(valid_vectors),
		"active_cross_product_vector": "\n".join(cross_vectors),
		"mutation_failure_codes": mutation_codes,
		"planner_and_support_margin_availability_are_independent": true,
		"reference_oracle_imported": false,
		"physical_worker_implemented": false,
		"physical_execution_authorized": false,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
