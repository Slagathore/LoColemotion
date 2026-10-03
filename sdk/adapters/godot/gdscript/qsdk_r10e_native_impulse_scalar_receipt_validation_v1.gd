class_name QsdkR10eNativeImpulseScalarReceiptValidationV1
extends RefCounted
# gdlint: disable=max-line-length

## Scalar-only validator for the forward-versioned QSDK-R10E impulse receipt.
##
## Values cross the observer boundary as exported scalar arrays. This source
## deliberately performs no Vector3 construction, so two separately rounded
## binary32 paths are never compared after another host-vector normalization.

const RECEIPT_SCHEMA := "sporespore_qsdk_r10e_native_impulse_application_receipt_v1"
const IMPULSE_COMPOSITION_NUMERIC_PRECISION := "godot_real_t_binary32"
const PROFILE_ID := "lateral_impulse_v1"
const TARGET_BODY_ID := "torso"
const APPLICATION_METHOD := "RigidBody3D.apply_central_impulse"
const PUSH_MARKER_SEMANTIC_STEP := 900
const EXPECTED_IMPULSE_MAGNITUDE_N_S := 0.25
const BINARY64_MACHINE_EPSILON := 2.220446049250313e-16
const BINARY64_OPERATION_EVENT_BUDGET := 32.0
const HOST_REAL_UNIT_NORM_ALLOWANCE := 1.9073486328125e-6
const WORLD_IMPULSE_MAGNITUDE_ALLOWANCE_N_S := 4.76837158203125e-7
const OBSERVED_DELTA_MAGNITUDE_LINK_ALLOWANCE_M_S := 1.0e-9
const EXPECTED_KEYS := [
	"application_count",
	"application_method",
	"controller_command",
	"effect_sampled",
	"impulse_composition_numeric_precision",
	"impulse_task_n_s",
	"impulse_world_n_s",
	"initial_task_frame_forward_axis_world_host_real",
	"initial_task_frame_lateral_axis_world_host_real",
	"observed_next_tick_velocity_delta_magnitude_m_s",
	"observed_next_tick_velocity_delta_world_m_s",
	"profile_id",
	"schema_version",
	"step_from_sdk_start",
	"target_body_id",
	"tick",
]


static func validate_push_receipt(
	receipt: Dictionary,
	external_push_application_count: int,
	marker_forward_axis_world_unit_value: Variant,
	marker_lateral_axis_world_unit_value: Variant,
) -> Dictionary:
	if not _has_exact_keys(receipt, EXPECTED_KEYS):
		return _failure("QSDK_R10E_PUSH_RECEIPT_KEY_SET_MISMATCH")
	if (
		typeof(receipt["application_count"]) != TYPE_INT
		or typeof(receipt["application_method"]) != TYPE_STRING
		or typeof(receipt["controller_command"]) != TYPE_BOOL
		or typeof(receipt["effect_sampled"]) != TYPE_BOOL
		or typeof(receipt["impulse_composition_numeric_precision"]) != TYPE_STRING
		or typeof(receipt["profile_id"]) != TYPE_STRING
		or typeof(receipt["schema_version"]) != TYPE_STRING
		or typeof(receipt["step_from_sdk_start"]) != TYPE_INT
		or typeof(receipt["target_body_id"]) != TYPE_STRING
		or typeof(receipt["tick"]) != TYPE_INT
	):
		return _failure("QSDK_R10E_PUSH_RECEIPT_STATIC_FIELD_TYPE_INVALID")
	for vector_field_value in [
		"impulse_task_n_s",
		"impulse_world_n_s",
		"initial_task_frame_forward_axis_world_host_real",
		"initial_task_frame_lateral_axis_world_host_real",
		"observed_next_tick_velocity_delta_world_m_s",
	]:
		if typeof(receipt[String(vector_field_value)]) != TYPE_ARRAY:
			return _failure("QSDK_R10E_PUSH_RECEIPT_SCALAR_ARRAY_REQUIRED")
	if (
		typeof(marker_forward_axis_world_unit_value) != TYPE_ARRAY
		or typeof(marker_lateral_axis_world_unit_value) != TYPE_ARRAY
	):
		return _failure("QSDK_R10E_PUSH_RECEIPT_MARKER_SCALAR_ARRAY_REQUIRED")

	var task_impulse := _finite_components(receipt["impulse_task_n_s"], 3)
	var world_impulse := _finite_components(receipt["impulse_world_n_s"], 3)
	var raw_forward := _finite_components(
		receipt["initial_task_frame_forward_axis_world_host_real"],
		3,
	)
	var raw_lateral := _finite_components(
		receipt["initial_task_frame_lateral_axis_world_host_real"],
		3,
	)
	var observed_delta := _finite_components(
		receipt["observed_next_tick_velocity_delta_world_m_s"],
		3,
	)
	var marker_forward := _finite_components(marker_forward_axis_world_unit_value, 3)
	var marker_lateral := _finite_components(marker_lateral_axis_world_unit_value, 3)
	if (
		task_impulse.size() != 3
		or world_impulse.size() != 3
		or raw_forward.size() != 3
		or raw_lateral.size() != 3
		or observed_delta.size() != 3
		or marker_forward.size() != 3
		or marker_lateral.size() != 3
	):
		return _failure("QSDK_R10E_PUSH_RECEIPT_NONFINITE_OR_WRONG_SHAPE")
	var effect_magnitude_value: Variant = receipt["observed_next_tick_velocity_delta_magnitude_m_s"]
	if not _is_numeric_scalar(effect_magnitude_value):
		return _failure("QSDK_R10E_PUSH_RECEIPT_EFFECT_MAGNITUDE_INVALID")
	var effect_magnitude := float(effect_magnitude_value)
	if not is_finite(effect_magnitude) or effect_magnitude < 0.0:
		return _failure("QSDK_R10E_PUSH_RECEIPT_EFFECT_MAGNITUDE_INVALID")

	var raw_forward_norm := _norm(raw_forward)
	var raw_lateral_norm := _norm(raw_lateral)
	var world_impulse_magnitude := _norm(world_impulse)
	var observed_delta_magnitude := _norm(observed_delta)
	var normalized_raw_forward := _normalize(raw_forward)
	var normalized_raw_lateral := _normalize(raw_lateral)
	if normalized_raw_forward.is_empty() or normalized_raw_lateral.is_empty():
		return _failure("QSDK_R10E_PUSH_RECEIPT_RAW_AXIS_NORMALIZATION_REFUSED")
	var recomputed_world_impulse := [0.0, 0.0, 0.0]
	for component_index in range(3):
		var world_up_component := 1.0 if component_index == 1 else 0.0
		recomputed_world_impulse[component_index] = (
			float(raw_forward[component_index]) * float(task_impulse[0])
			+ world_up_component * float(task_impulse[1])
			+ float(raw_lateral[component_index]) * float(task_impulse[2])
		)

	var predicates := {
		"external_push_application_count_exact": external_push_application_count == 1,
		"receipt_schema_exact": String(receipt["schema_version"]) == RECEIPT_SCHEMA,
		"profile_id_exact": String(receipt["profile_id"]) == PROFILE_ID,
		"target_body_exact": String(receipt["target_body_id"]) == TARGET_BODY_ID,
		"application_method_exact": String(receipt["application_method"]) == APPLICATION_METHOD,
		"application_semantic_step_exact":
		int(receipt["step_from_sdk_start"]) == PUSH_MARKER_SEMANTIC_STEP,
		"application_tick_nonnegative": int(receipt["tick"]) >= 0,
		"application_count_exact": int(receipt["application_count"]) == 1,
		"not_a_controller_command": not bool(receipt["controller_command"]),
		"native_effect_sampled": bool(receipt["effect_sampled"]),
		"impulse_composition_numeric_precision_exact":
		(
			String(receipt["impulse_composition_numeric_precision"])
			== IMPULSE_COMPOSITION_NUMERIC_PRECISION
		),
		"task_impulse_exact":
		(
			float(task_impulse[0]) == 0.0
			and float(task_impulse[1]) == 0.0
			and float(task_impulse[2]) == EXPECTED_IMPULSE_MAGNITUDE_N_S
		),
		"raw_forward_axis_unit_within_operation_allowance":
		absf(raw_forward_norm - 1.0) <= HOST_REAL_UNIT_NORM_ALLOWANCE,
		"raw_lateral_axis_unit_within_operation_allowance":
		absf(raw_lateral_norm - 1.0) <= HOST_REAL_UNIT_NORM_ALLOWANCE,
		"raw_task_axes_orthogonal_within_operation_allowance":
		absf(_dot(raw_forward, raw_lateral)) <= HOST_REAL_UNIT_NORM_ALLOWANCE,
		"raw_forward_axis_links_to_trace_in_binary64_scalar_space":
		_all_components_within_binary64_transport_allowance(
			normalized_raw_forward,
			marker_forward,
		),
		"raw_lateral_axis_links_to_trace_in_binary64_scalar_space":
		_all_components_within_binary64_transport_allowance(
			normalized_raw_lateral,
			marker_lateral,
		),
		"world_impulse_links_to_raw_host_axes_in_binary64_scalar_space":
		_all_components_within_binary64_transport_allowance(
			world_impulse,
			recomputed_world_impulse,
		),
		"world_impulse_magnitude_within_operation_allowance":
		(
			absf(world_impulse_magnitude - EXPECTED_IMPULSE_MAGNITUDE_N_S)
			<= WORLD_IMPULSE_MAGNITUDE_ALLOWANCE_N_S
		),
		"observed_delta_vector_links_to_stored_magnitude":
		(
			absf(observed_delta_magnitude - effect_magnitude)
			<= OBSERVED_DELTA_MAGNITUDE_LINK_ALLOWANCE_M_S
		),
	}
	var failed_predicates: Array[String] = []
	for predicate_value in predicates.keys():
		var predicate := String(predicate_value)
		if not bool(predicates[predicate]):
			failed_predicates.append(predicate)
	if not failed_predicates.is_empty():
		var failure := _failure("QSDK_R10E_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH")
		failure["predicates"] = predicates
		failure["failed_predicates"] = failed_predicates
		failure["allowance_receipt"] = _allowance_receipt()
		return failure
	return {
		"ok": true,
		"failure_code": "",
		"predicates": predicates,
		"failed_predicates": [],
		"predicate_count": predicates.size(),
		"allowance_receipt": _allowance_receipt(),
		"raw_forward_axis_norm": raw_forward_norm,
		"raw_lateral_axis_norm": raw_lateral_norm,
		"raw_task_axes_absolute_dot": absf(_dot(raw_forward, raw_lateral)),
		"world_impulse_magnitude_n_s": world_impulse_magnitude,
		"observed_delta_magnitude_m_s": observed_delta_magnitude,
		"stored_observed_delta_magnitude_m_s": effect_magnitude,
		"receipt":
		{
			"application_count": 1,
			"profile_id": PROFILE_ID,
			"step_from_sdk_start": PUSH_MARKER_SEMANTIC_STEP,
			"effect_sampled": true,
			"effect_magnitude_m_s": effect_magnitude,
			"observed_velocity_delta_world_m_s": observed_delta.duplicate(),
		},
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func binary64_transport_allowance(actual: float, expected: float) -> float:
	return (
		BINARY64_OPERATION_EVENT_BUDGET
		* BINARY64_MACHINE_EPSILON
		* maxf(1.0, maxf(absf(actual), absf(expected)))
	)


static func _allowance_receipt() -> Dictionary:
	return {
		"binary64_transport_comparison_formula":
		"32 * 2^-52 * max(1.0, abs(actual), abs(recomputed_expected))",
		"binary64_machine_epsilon": BINARY64_MACHINE_EPSILON,
		"binary64_rounded_arithmetic_event_budget": int(BINARY64_OPERATION_EVENT_BUDGET),
		"host_real_unit_norm_allowance": HOST_REAL_UNIT_NORM_ALLOWANCE,
		"host_real_unit_norm_allowance_formula": "16 * 2^-23",
		"world_impulse_magnitude_allowance_n_s": WORLD_IMPULSE_MAGNITUDE_ALLOWANCE_N_S,
		"world_impulse_magnitude_allowance_formula": "16 * 2^-23 * 0.25",
		"observed_r10d_outcome_used_to_select_allowances": false,
		"behavior_threshold_changed": false,
	}


static func _all_components_within_binary64_transport_allowance(
	actual: Array,
	expected: Array,
) -> bool:
	if actual.size() != 3 or expected.size() != 3:
		return false
	for component_index in range(3):
		var actual_component := float(actual[component_index])
		var expected_component := float(expected[component_index])
		if (
			absf(actual_component - expected_component)
			> binary64_transport_allowance(actual_component, expected_component)
		):
			return false
	return true


static func _finite_components(value: Variant, expected_count: int) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != expected_count:
		return []
	var result: Array = []
	for component_value in value:
		if not _is_numeric_scalar(component_value):
			return []
		var component := float(component_value)
		if not is_finite(component):
			return []
		result.append(component)
	return result


static func _norm(values: Array) -> float:
	return sqrt(_dot(values, values))


static func _dot(left: Array, right: Array) -> float:
	return (
		float(left[0]) * float(right[0])
		+ float(left[1]) * float(right[1])
		+ float(left[2]) * float(right[2])
	)


static func _normalize(values: Array) -> Array:
	var length := _norm(values)
	if not is_finite(length) or length <= 0.0:
		return []
	return [
		float(values[0]) / length,
		float(values[1]) / length,
		float(values[2]) / length,
	]


static func _is_numeric_scalar(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _has_exact_keys(values: Dictionary, expected_keys: Array) -> bool:
	if values.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not values.has(String(key_value)):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
